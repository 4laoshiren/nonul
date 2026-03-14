# nonul

[中文版](README_zh-CN.md)

Replaces the **folder** "Delete" option in the Windows Explorer context menu. You still see the same "Delete", but this version can handle folders containing `nul` files.

## TL;DR

Once installed, right-click "Delete" on any folder will work even if it contains `nul` files — no more hassle when deleting Claude Code projects on Windows.

## Demo

**Before:**

![before](former.gif)

**After:**

![after](after.gif)

## Usage

Pick either method. Takes effect immediately after installation — the "Delete" option in your Windows Explorer context menu will be able to delete folders containing `nul` files.

<sub>Although the project provides a reliable uninstall command, you can always back up your current registry before installing: Registry Editor → File → Export</sub>

### irm (no tools required)

Install:

```powershell
irm https://raw.githubusercontent.com/4laoshiren/nonul/main/nonul.ps1 | iex
```

Uninstall:

```powershell
irm https://raw.githubusercontent.com/4laoshiren/nonul/main/nonul.ps1 -OutFile nonul.ps1; .\nonul.ps1 -Uninstall
```

### Scoop

Install:

```powershell
scoop bucket add nonul https://github.com/4laoshiren/nonul
scoop install nonul
```

Uninstall:

```powershell
scoop uninstall nonul
```

## Why do I need this?

`nul` is a Windows reserved device name. If a folder contains a file named `nul`, the entire folder becomes undeletable — Explorer throws an error, and `rd /s` fails too.

Claude Code on Windows creates undeletable `nul` files in the working directory. This is a known and widely reported bug. After using Claude Code for a while, `nul` files accumulate across your project directories, making entire project folders impossible to delete.

Related issues:
[#4928](https://github.com/anthropics/claude-code/issues/4928)
[#5449](https://github.com/anthropics/claude-code/issues/5449)
[#10543](https://github.com/anthropics/claude-code/issues/10543)
[#10552](https://github.com/anthropics/claude-code/issues/10552)
[#15398](https://github.com/anthropics/claude-code/issues/15398)
[#16642](https://github.com/anthropics/claude-code/issues/16642)
[#17783](https://github.com/anthropics/claude-code/issues/17783)
[#17886](https://github.com/anthropics/claude-code/issues/17886)
[#23942](https://github.com/anthropics/claude-code/issues/23942)
[microsoft/vscode#290986](https://github.com/microsoft/vscode/issues/290986)

Currently the only way to delete these files is via command line: `[System.IO.File]::Delete('\\?\full\path')`, which is far from intuitive — deleting a project should be as simple as right-click Delete.

## What does this project do?

> In short: it creates a `delete` key under the folder's shell registry entry. When this key exists, it overrides the native right-click Delete for folders. The custom logic calls `wscript.exe` to clean up `nul` files before deleting the folder.

In detail:

On install:

1. Generates a helper script `delete-directory.vbs` under `%LOCALAPPDATA%\nonul\`
2. Creates the registry key `HKCU\Software\Classes\Directory\shell\delete` with:
   - Default value: `Delete(&D)` (display name, same as native)
   - `Icon`: `shell32.dll,-240` (delete icon, same as native)
3. Creates the subkey `HKCU\Software\Classes\Directory\shell\delete\command` with:
   - Default value: `wscript.exe "%LOCALAPPDATA%\nonul\delete-directory.vbs" "%1"`

When a user right-clicks Delete on a folder, Windows prioritizes the `HKCU` `shell\delete` key over the native behavior. The call chain is:

```
wscript.exe (windowless launcher) → VBS script → powershell.exe (silently runs the actual delete logic)
```

On uninstall:

1. Removes the registry key `HKCU\Software\Classes\Directory\shell\delete` (restores native Delete)
2. Removes the `%LOCALAPPDATA%\nonul\` directory (cleans up the helper script)

## Why only folders, not individual files?

As a project that modifies the registry, the scope should be as minimal as possible. The typical scenario requiring `nul` file cleanup is deleting an entire project folder. Since `nul` files don't actually affect your project's functionality, there's no real need to delete them individually.

## How does it work?

After installation, the right-click "Delete" for folders is replaced with the nonul version:

```
Right-click Delete on a folder
  → Recursively find all files named nul (case-insensitive)
  → Delete each one using the \\?\ prefix path
  → Send the folder to the Recycle Bin
```

For folders that don't contain `nul` files, it behaves identically to the native Delete.

## License

MIT
