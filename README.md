![Blender -> Roblox Auto-Exporter: a Blender scene on the left, the same objects in Roblox Studio on the right](docs/header.webp)

# Blender → Roblox Auto-Exporter

**Save in Blender. See the change in Roblox Studio.**

## The problem

When you make a 3D model in Blender and want it in Roblox, you have to do the same chores every time you change it:

1. Export the model as a file.
2. Upload it to Roblox.
3. Put it back into your game.

If you upload it again, Roblox treats it as a brand new item. Your game fills up with old versions, and the copies you already placed in your game **don't change** when you fix the original.

## What this does

You change your model in Blender and press **Save**. The tool does the chores for you:

- It exports only the models you actually changed.
- It updates the **same** Roblox item instead of making a new one each time.
- It replaces the copies already in your game with the new version, in the same spot, with the same rotation.

You choose which models go to Roblox by putting them in a Blender collection (a folder in Blender's Outliner list) named `Export`. Everything else in your Blender file is left alone.

## What you need

- **Blender** (tested on 5.2.1) and **Roblox Studio**. Tested on Windows only.
- **For the automatic upload:** an AI assistant that can talk to Roblox Studio, such as Claude. Studio has a built-in feature for this called an *MCP server*. It's what lets the assistant upload for you, so **you never have to create or copy a secret password (API key)**.
- **No assistant?** The Blender part still works by itself. Every time you save, it makes up-to-date model files that you can upload yourself.

## What's in the box

| File | What it's for |
|---|---|
| `rbx_export.py` | Runs inside Blender. Every time you save, it exports the models in your `Export` collection that you changed. |
| `rbx_watch.ps1` | Watches the export folder and says "this file changed", so the assistant knows when to upload. |
| `rbx_swap.luau` | Runs inside Roblox Studio. Replaces the old copies in your game with the new version. |
| `rbx_assets.template.json` | A list that remembers which model is which Roblox item. Copy it to `rbx_assets.json` and fill it in. |
| `config.example.json` | Where your export folder is. Copy it and edit the paths. |

## Setup (about 10 minutes)

**1. Turn on Studio's assistant connection**
In Roblox Studio, open **Assistant**, click the **…** menu, choose **Manage MCP Servers**, and turn on **Enable Studio as MCP server**. Then connect your assistant. ([Roblox's instructions](https://create.roblox.com/docs/en-us/studio/mcp.md))

**2. Give it permission to upload**
Open **Assistant Settings → MCP Permissions**.
- Allow **Publish & manage assets**.
- Under **Open Cloud upload directories**, add the folder where your model files will go (for example `D:/RobloxExports`). The assistant can only upload files from folders you list here.

**3. Tell the tool where your folder is**
Copy `config.example.json` to a new file at `~/.rbx_pipeline/config.json` (on Windows, `~` means your user folder, like `C:\Users\YourName`). Open it and change the paths to your own.

**4. Install the Blender script**
Copy `rbx_export.py` into Blender's startup scripts folder, for example:
`%APPDATA%\Blender Foundation\Blender\<your Blender version>\scripts\startup\`
Then **close and reopen Blender**. Blender only loads startup scripts when it opens.

**5. Pick which models to send**
In your Blender file, make a collection named `Export` and put your models inside. You can also make folders inside `Export`. **Every model inside becomes its own Roblox item.**

## How to use it

**The first time you send a model:**
Upload its file once. (Ask your assistant to do it, or upload it yourself with the [Assets API](https://create.roblox.com/docs/en-us/cloud/guides/usage-assets.md).) Roblox gives you an **asset ID**, which is just the item's number. Write it down in `rbx_assets.json` and in the list at the top of `rbx_swap.luau`.

**Every time after that:**
1. Change your model in Blender.
2. Press **Ctrl+S**. The changed models are exported.
3. Your assistant sends the new file to the **same** Roblox item and runs `rbx_swap.luau`. If you use `rbx_watch.ps1`, the assistant can do this on its own when a file changes.

**To make a model in your game "swappable":**
Models that you dragged in with the item's name are found automatically. For anything else, add a tag called `RBXAsset` and a number attribute `rbxAssetId` (set to the asset ID).

## Things to know

- **A model's name in Blender is its identity.** If you rename it, Roblox sees a new model and makes a new item.
- **Uploads can't be undone.** Roblox doesn't let this tool delete items or old versions, and every update adds a version.
- **Only `.fbx` files can be updated** (up to 20 MB). These Roblox upload features are still in beta, so they may change.
- **Old copies don't update on their own.** A model already in your game keeps pointing at the version it was made from. That's why the swap step exists.
- **Check Roblox's size limits** for how many triangles one mesh can have before you upload ([limits](https://create.roblox.com/docs/art/modeling/specifications.md)).
- **Deleting a model in Blender doesn't delete its exported file.** You'd clean those up yourself.
- **Back up your Blender files.** If you also connect an AI assistant to Blender itself (the Blender Lab MCP add-on), it can run code inside Blender without any safety checks.

## Running the export by hand

You normally don't need this, because saving does it. To export from a command line instead, run this (add `--force` to export everything, even unchanged models):

```
blender -b file.blend --python rbx_export.py -- --run
```

## License

MIT. See `LICENSE`.
