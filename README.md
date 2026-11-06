![Blender -> Roblox Auto-Exporter: a Blender scene on the left, the same objects in Roblox Studio on the right](docs/header.webp)

# Blender → Roblox asset loop

## The problem

Getting a model from Blender into Roblox is slow. Every time you tweak a mesh you have to export an
FBX, open Studio's import window, upload it, and drag the result back into your scene. Each upload can
also create a brand-new asset, so your scene ends up full of old versions, and the copies you already
placed don't change when you update the original.

## What this does

Save in Blender and the change shows up in your open Roblox Studio place. Behind the scenes:

- Only the objects you actually changed are exported.
- Each one is uploaded to the **same** Roblox asset, so you keep a single asset per object instead of piling up duplicates.
- The copies already placed in your scene are swapped to the new version, keeping their position, rotation and anchoring.

You mark which objects go to Roblox by putting them in one Blender collection called `Export`. Everything else in the scene stays put.

## How it works

It's three small scripts and a naming convention, not a plugin. The upload and swap steps are done by an
AI assistant or other MCP client (for example Claude) connected to Roblox Studio's built-in MCP server.
Studio holds the upload permission, so **you never create or store an API key**. Without an MCP client,
the Blender half still works on its own: it writes up-to-date FBX files you can upload by hand.

Tested on: Blender 5.2.1 LTS, Windows 11, Roblox Studio with the Studio MCP server enabled.
Not tested elsewhere.

## Pieces

| File | Runs in | Does |
|---|---|---|
| `rbx_export.py` | Blender (startup script) | On every save, exports each mesh object in the `Export` collection to `<export_dir>/<ObjectName>.fbx`, only if its geometry, UVs, materials or transform changed. Apply Scaling = FBX Unit Scale. |
| `rbx_watch.ps1` | PowerShell | Prints `CHANGED <name>.fbx` when an FBX changes, so an MCP client can push it. |
| `rbx_swap.luau` | Studio (via `execute_luau`) | Reloads tagged models from their asset, keeping position, rotation, anchoring and attributes. Placed copies do **not** update by themselves when an asset gets a new version. |
| `rbx_assets.template.json` | — | Name → asset ID map. Copy to `rbx_assets.json`. |

## Setup

1. Studio → Assistant → **…** → Manage MCP Servers → enable *Studio as MCP server*, and connect your client
   ([docs](https://create.roblox.com/docs/en-us/studio/mcp.md)).
2. Studio → Assistant Settings → **MCP Permissions**: allow *Publish & manage assets* (`asset:read`, `asset:write`)
   and add your export folder under *Open Cloud upload directories*.
3. Copy `config.example.json` to `~/.rbx_pipeline/config.json` and edit the paths (or set `RBX_PIPELINE_CONFIG`).
4. Copy `rbx_export.py` into Blender's `scripts/startup` folder, e.g.
   `%APPDATA%\Blender Foundation\Blender\<version>\scripts\startup\`, and **restart Blender**.
5. In your .blend, make a collection named `Export`. Every mesh object in it (child collections are fine) becomes its own asset.

## Loop

1. First time per object: upload its FBX with `POST /assets/v1/assets` and record the returned asset ID in `rbx_assets.json`
   and in `ASSETS` inside `rbx_swap.luau`.
2. After that: edit in Blender, Ctrl+S. Then PATCH `/assets/v1/assets/{assetId}` with the new FBX
   ([Assets API guide](https://create.roblox.com/docs/en-us/cloud/guides/usage-assets.md)) and run `rbx_swap.luau`.
   An MCP client can do both automatically when `rbx_watch.ps1` reports a change.
3. To make a model swappable: `CollectionService:AddTag(model, "RBXAsset")` and `model:SetAttribute("rbxAssetId", id)`.
   `rbx_swap.luau` also auto-tags untagged models named `<Asset>` or `<Asset> <n>`.

## Caveats

- Object name = FBX name = asset identity. **Renaming an object makes a new asset.**
- Uploads are permanent and Open Cloud cannot delete them; every PATCH adds a revision.
- Content updates via PATCH work for `.fbx` only, 20 MB per call; the endpoints are beta.
- A placed MeshPart keeps pointing at the mesh version it was inserted with; that is why the swap step exists.
- Check Roblox's per-mesh triangle limits before uploading
  ([specs](https://create.roblox.com/docs/art/modeling/specifications.md)).
- Stale FBX files are never deleted when you delete an object.
- The unofficial Blender MCP, if you add one, runs LLM-generated code in Blender with no guards: back up your .blend files.

## Manual export

```
blender -b file.blend --python rbx_export.py -- --run [--force]
```
