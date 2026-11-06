-- Run via Studio MCP execute_luau (Edit datamodel) after each PATCH.
-- Source of ASSETS is your rbx_assets.json (paste the current map below).
--
-- 1. ENROL: any untagged Model in Workspace named "<Asset>" or "<Asset> <n>" (how Studio
--    names a dragged-in copy) is tagged "RBXAsset" with attribute rbxAssetId.
-- 2. SWAP: every tagged model is replaced by a fresh load of its asset, keeping name,
--    pivot, per-part Anchored, attributes and parent.
-- Set DRY_RUN = true to only list what would be enrolled/swapped.
local DRY_RUN = false
local ASSETS = {
	-- ObjectName = assetId (from your rbx_assets.json), e.g.
	-- Crate = 1234567890,
}

local CS = game:GetService("CollectionService")
local IS = game:GetService("InsertService")
local TAG = "RBXAsset"
local out = {}

-- 1. enrol
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and not CS:HasTag(d, TAG) then
		for name, id in pairs(ASSETS) do
			if d.Name == name or d.Name:match("^" .. name:gsub("%p", "%%%0") .. " %d+$") then
				table.insert(out, (DRY_RUN and "would enrol " or "enrolled ") .. d:GetFullName())
				if not DRY_RUN then
					CS:AddTag(d, TAG)
					d:SetAttribute("rbxAssetId", id)
				end
			end
		end
	end
end

-- 2. swap
for _, inst in ipairs(CS:GetTagged(TAG)) do
	local id = inst:GetAttribute("rbxAssetId")
	if id and inst:IsDescendantOf(workspace) then
		if DRY_RUN then
			table.insert(out, "would swap " .. inst:GetFullName())
		else
			local ok, fresh = pcall(function() return IS:LoadAsset(id) end)
			if not ok then
				table.insert(out, inst.Name .. ": load failed " .. tostring(fresh))
			else
				local model = fresh:GetChildren()[1]
				model.Parent = nil
				fresh:Destroy()
				local anchored = {}
				for _, d in ipairs(inst:GetDescendants()) do
					if d:IsA("BasePart") then anchored[d.Name] = d.Anchored end
				end
				local oldmp = inst:FindFirstChildWhichIsA("MeshPart", true)
				local oldsize = oldmp and tostring(oldmp.Size) or "?"
				model.Name = inst.Name
				model:PivotTo(inst:GetPivot())
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("BasePart") and anchored[d.Name] ~= nil then d.Anchored = anchored[d.Name] end
				end
				for k, v in pairs(inst:GetAttributes()) do model:SetAttribute(k, v) end
				CS:AddTag(model, TAG)
				model.Parent = inst.Parent
				inst:Destroy()
				local mp = model:FindFirstChildWhichIsA("MeshPart", true)
				table.insert(out, string.format("%s swapped: %s -> %s", model.Name, oldsize, mp and tostring(mp.Size) or "?"))
			end
		end
	end
end
return #out > 0 and table.concat(out, "\n") or "nothing to enrol or swap"
