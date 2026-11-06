# More details

## What's in the box

| File | What it's for |
|---|---|
| `rbx_export.py` | Runs inside Blender. Every time you save, it exports the models in your `Export` collection that you changed. Adds a **Roblox** tab in the sidebar (press N) with a **Push to Roblox** button and a list of models waiting to be pushed, and shows a message in the status bar after each save. To force-export every model, use the manual command below with `--force`. |
| `rbx_watch.ps1` | Watches the export folder so the assistant knows when to upload. Default mode (`-Mode push`) reacts to the **Push to Roblox** button. `-Mode fbx` reacts to every changed FBX instead. |
| `rbx_swap.luau` | Runs inside Roblox Studio. Replaces the old copies in your game with the new version. |
| `rbx_assets.template.json` | A list that remembers which model is which Roblox item. Copy it to `rbx_assets.json` and fill it in. |
| `config.example.json` | Where your export folder is. |

## How updates work

- **First time:** upload the model's file once (your assistant can do it, or use the [Assets API](https://create.roblox.com/docs/en-us/cloud/guides/usage-assets.md)). Roblox returns an **asset ID**. Write it in `rbx_assets.json` and in the list at the top of `rbx_swap.luau`.
- **After that:** save in Blender, click **Push to Roblox**, then the assistant sends the new file to the same asset ID and runs `rbx_swap.luau` in Studio.
- **How the button talks to the assistant:** the button writes `.push_request.json` (the list of models waiting to be pushed) into your export folder. `rbx_watch.ps1 -Dir <export folder>`, started by the assistant, notices it. When the assistant finishes, it writes `.push_done.json` with the results, and the Blender panel shows them. The waiting list lives in `<signature file>.pending.json`.
- **If nothing is watching:** the button still writes the request, and the panel keeps saying "Waiting for the assistant". Tell the assistant "push" and it will read the request.
- **Limit:** the watcher only runs while your assistant's session is open, and the assistant's watch tool needs to be restarted every 30 minutes (Claude Code's limit).
- **Making a model swappable:** models in your game named after the item are found automatically. For any other model, add a tag `RBXAsset` and an attribute `rbxAssetId` set to the asset ID.

## Limits and warnings

- A model's name in Blender is its identity. Renaming it creates a new Roblox item.
- Uploads can't be deleted through Open Cloud, and every update adds a version.
- Only `.fbx` files can be updated, up to 20 MB. These Roblox features are in beta and may change.
- Copies already in your game keep pointing at the version they were made from. That's why the swap step exists.
- Check Roblox's [mesh limits](https://create.roblox.com/docs/art/modeling/specifications.md) before uploading.
- Deleting a model in Blender doesn't delete its exported file.
- Back up your Blender files. If you also connect an AI assistant to Blender itself (the Blender Lab MCP add-on), it can run code in Blender without safety checks.

## Running the export by hand

You normally don't need this, because saving does it. Add `--force` to export everything, even unchanged models:

```
blender -b file.blend --python rbx_export.py -- --run
```

## Tested on

Blender 5.2.1 LTS, Windows 11, Roblox Studio with the Studio MCP server on. Not tested elsewhere.
