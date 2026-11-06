![Blender -> Roblox Auto-Exporter: a Blender scene on the left, the same objects in Roblox Studio on the right](docs/header.webp)

# Blender → Roblox Auto-Exporter

**Save in Blender. See the change in Roblox Studio.**

Updating a model in Roblox is a pain. Every change means exporting, uploading, and putting it back in your game by hand. And the copies already in your game don't update.

## What it does

You change a model in Blender and press **Save**. The tool updates that model in Roblox, and in your game, for you.

## What you need

- Blender and Roblox Studio (tested on Blender 5.2.1, Windows).
- An AI assistant that can control Roblox Studio, like Claude. It does the uploading, so you never handle any passwords or keys.

## Set it up

1. **In Roblox Studio**, open **Assistant → … → Manage MCP Servers** and turn on **Enable Studio as MCP server**. Connect your assistant. ([Roblox's guide](https://create.roblox.com/docs/en-us/studio/mcp.md))
2. **Still in Studio**, open **Assistant Settings → MCP Permissions**. Allow **Publish & manage assets**, and add a folder for your exported models (for example `D:/RobloxExports`).
3. **Copy `config.example.json`** to `~/.rbx_pipeline/config.json` and change the folder paths to yours. (`~` is your user folder, like `C:\Users\YourName`.)
4. **Copy `rbx_export.py`** into Blender's startup scripts folder, then restart Blender:
   `%APPDATA%\Blender Foundation\Blender\<your version>\scripts\startup\`
5. **In Blender**, make a collection called `Export` and put the models you want in Roblox inside it.

## Use it

1. Change a model in Blender.
2. Press **Ctrl+S**.
3. Ask your assistant to push the change to Roblox.

The first time you send a model, the assistant uploads it and Roblox gives it a number (its asset ID). The tool remembers that number, so later updates go to the same item.

## Good to know

- **Don't rename models.** A new name means a new item in Roblox.
- **Uploads can't be deleted** by this tool, and every update adds a version.

More detail (file list, limits, running by hand) is in [docs/DETAILS.md](docs/DETAILS.md).

## License

MIT. See `LICENSE`.
