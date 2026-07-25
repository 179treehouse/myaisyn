# myaisyn - ScriptsToFolder

A fork of [UniversalSynSaveInstance](https://github.com/luau/UniversalSynSaveInstance) that saves decompiled scripts to a **folder structure** instead of an XML place file.

Instead of getting a `.rbxlx` file you open in Roblox Studio, you get a folder with all the scripts organized by their Roblox hierarchy — ready to browse, edit, or use in your own projects.

---

## Quick Start

### 1. Load the script in your executor

```lua
local scriptsToFolder = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/179treehouse/myaisyn/main/scripts_to_folder.lua", true)
)()
```

### 2. Run it

```lua
scriptsToFolder()
```

That's it. It will scan the game, decompile all scripts, and save them to a folder named `scripts_<PlaceId>_<PlaceName>/` in your executor's workspace.

---

## Example Script

Copy and paste this into your executor:

```lua
-- Load ScriptsToFolder
local scriptsToFolder = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/179treehouse/myaisyn/main/scripts_to_folder.lua", true)
)()

-- Run with default settings
scriptsToFolder()
```

---

## Options

You can pass a table of options to customize behavior:

```lua
scriptsToFolder({
    mode = "optimized",       -- "optimized" (default), "full", or "scripts"
    DecompileTimeout = 15,    -- Max seconds per script decompile (default: 10)
    SaveBytecode = true,      -- Also save raw bytecode as comments (default: false)
    FilePath = "my_scripts",  -- Custom output folder name (default: auto-generated)
    SafeMode = false,         -- Disable SafeMode kick (default: true)
    ShowStatus = true,        -- Show progress on screen (default: true)
    IgnoreList = { "CoreGui" }, -- Instances/classes to skip
})
```

### Mode Options

| Mode | What it saves |
|------|---------------|
| `"optimized"` (default) | Standard services: Workspace, Players, Lighting, ReplicatedStorage, StarterGui, StarterPlayer, etc. |
| `"full"` | Everything under game |
| `"scripts"` | Only containers that directly hold scripts (minimal) |

---

## Output Structure

Scripts are saved with special extensions so you know what type they are:

```
scripts_123456789_MyGame/
├── README.txt
├── Workspace/
│   ├── Part/
│   │   └── ScriptName.server.lua      -- Script (runs on server)
│   └── Folder/
│       └── MyModule.module.lua        -- ModuleScript
├── ReplicatedStorage/
│   └── SharedModule.module.lua
├── StarterGui/
│   └── ScreenGui/
│       └── LocalScriptName.client.lua -- LocalScript (runs on client)
└── ...
```

Each script file has a header showing its original path and class:

```lua
-- Saved by ScriptsToFolder (based on UniversalSynSaveInstance)
-- Original Path: Workspace.Folder.ScriptName
-- Class: Script

-- (decompiled code here)
```

---

## Advanced Usage

### Save only specific instances

```lua
scriptsToFolder({
    Object = game.Workspace,  -- Only save scripts under Workspace
    mode = "full"
})
```

### Save with extra instances

```lua
scriptsToFolder({
    ExtraInstances = { game.Workspace.Part.Script },
    mode = "invalidmode"
})
```

### Save bytecode alongside decompiled source

```lua
scriptsToFolder({
    SaveBytecode = true,
    DecompileTimeout = 30
})
```

---

## Full Fork Version

There's also a full fork at `saveinstance_folder.lua` that adds `ScriptsToFolder` as an option to the original UniversalSynSaveInstance. This preserves all original features (NilInstances, IsolatePlayers, etc.) but is much larger (~4600 lines).

```lua
local synsaveinstance = loadstring(
    game:HttpGet("https://raw.githubusercontent.com/179treehouse/myaisyn/main/saveinstance_folder.lua", true)
)()

-- Save scripts to folder
synsaveinstance({ ScriptsToFolder = true, SafeMode = true })

-- Or save as normal XML place file (original behavior)
synsaveinstance({ SafeMode = true })
```

---

## Notes

- **Server Scripts** are impossible to save due to Roblox's FilteringEnabled. They will show a comment explaining this.
- Your executor needs to support `writefile`, `makefolder`, `delfolder`, and `isfile`.
- The decompiler used is your executor's built-in `decompile()` function.
- Scripts are cached by bytecode to avoid re-decompiling duplicates.