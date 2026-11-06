-- Run via Studio MCP execute_luau (Edit datamodel) after each push.
-- Source of ASSETS is your rbx_assets.json (paste the current map below).
--
-- 1. ENROL: any untagged Model in Workspace named "<Asset>" or "<Asset> <n>" (how Studio
--    names a dragged-in copy) is tagged "RBXAsset" with attribute rbxAssetId.
-- 2. SWAP: every tagged model is replaced by the latest version of its asset, keeping name,
--    pivot, per-part Anchored, attributes and parent.
--
-- EXPECT_NEW lists asset IDs you just uploaded a new version of. For those, the script keeps
-- retrying (every POLL seconds, up to TIMEOUT seconds) until Roblox finishes processing and the
-- new mesh shows up, so no separate "is the upload done?" check is needed.
local ASSETS = {
	-- ObjectName = assetId (from your rbx_assets.json), e.g.
	-- Crate = 1234567890,
}
local EXPECT_NEW = {
	-- [1234567890] = true,
}
local TIMEOUT = 45
local POLL = 1.5

local CS = game:GetService("CollectionService")
local IS = game:GetService("InsertService")
local TAG = "RBXAsset"
local out = {}

local function sigOf(model)
	local t = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("MeshPart") then table.insert(t, d.MeshId) end
	end
	table.sort(t)
	return table.concat(t, "|")
end

-- 1. enrol
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and not CS:HasTag(d, TAG) then
		for name, id in pairs(ASSETS) do
			if d.Name == name or d.Name:match("^" .. name:gsub("%p", "%%%0") .. " %d+$") then
				table.insert(out, "enrolled " .. d:GetFullName())
				CS:AddTag(d, TAG)
				d:SetAttribute("rbxAssetId", id)
			end
		end
	end
end

-- 2. swap, one asset at a time
local groups = {}
for _, inst in ipairs(CS:GetTagged(TAG)) do
	local id = inst:GetAttribute("rbxAssetId")
	if id and inst:IsDescendantOf(workspace) then
		groups[id] = groups[id] or {}
		table.insert(groups[id], inst)
	end
end

for id, list in pairs(groups) do
	local baseline = list[1]:GetAttribute("rbxMeshSig") or sigOf(list[1])
	local fresh, sig, lastErr
	local t0 = os.clock()
	repeat
		local ok, res = pcall(function() return IS:LoadAsset(id) end)
		if ok then
			local m = res:GetChildren()[1]
			m.Parent = nil
			res:Destroy()
			local s = sigOf(m)
			if not EXPECT_NEW[id] or s ~= baseline then
				fresh, sig = m, s
				break
			end
			m:Destroy()
		else
			lastErr = res
		end
		task.wait(POLL)
	until os.clock() - t0 > TIMEOUT

	if not fresh then
		table.insert(out, string.format("asset %d: no new version after %ds%s (not swapped)", id, TIMEOUT, lastErr and (": " .. tostring(lastErr)) or ""))
	else
		for i, inst in ipairs(list) do
			local model = (i == 1) and fresh or fresh:Clone()
			local anchored = {}
			for _, d in ipairs(inst:GetDescendants()) do
				if d:IsA("BasePart") then anchored[d.Name] = d.Anchored end
			end
			local oldmp = inst:FindFirstChildWhichIsA("MeshPart", true)
			local oldsize = oldmp and string.format("%.1f,%.1f,%.1f", oldmp.Size.X, oldmp.Size.Y, oldmp.Size.Z) or "?"
			model.Name = inst.Name
			model:PivotTo(inst:GetPivot())
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") and anchored[d.Name] ~= nil then d.Anchored = anchored[d.Name] end
			end
			for k, v in pairs(inst:GetAttributes()) do model:SetAttribute(k, v) end
			model:SetAttribute("rbxMeshSig", sig)
			CS:AddTag(model, TAG)
			model.Parent = inst.Parent
			inst:Destroy()
			local mp = model:FindFirstChildWhichIsA("MeshPart", true)
			table.insert(out, string.format("%s: %s -> %s", model.Name, oldsize, mp and string.format("%.1f,%.1f,%.1f", mp.Size.X, mp.Size.Y, mp.Size.Z) or "?"))
		end
	end
end
return #out > 0 and table.concat(out, "\n") or "nothing to enrol or swap"
