# nonul

替换 Windows 资源管理器右键菜单中**文件夹**的「删除」。用户看到的还是一个「删除」，但这个版本能处理含 `nul` 文件的文件夹。

## 为什么需要这个？

`nul` 是 Windows 保留设备名。如果一个文件夹里有叫 `nul` 的文件，整个文件夹都删不掉——资源管理器会报错，`rd /s` 也不行。

Claude Code 在 Windows 上会在工作目录中创建无法删除的 `nul` 文件，这是一个已知且被大量报告的 bug。使用 Claude Code 一段时间后，项目目录中就会散落多个 `nul` 文件，导致整个项目文件夹无法删除。

相关 issue：
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

目前唯一的删除方式是通过命令行执行 `[System.IO.File]::Delete('\\?\完整路径')`，但这对日常使用很不直观——删除项目应当可以右键删除。

## 为什么只处理文件夹，不处理单个文件？

作为更改注册表的项目，结构应尽可能简单。常规需要删nul文件的场景就是需要删除整个项目，即整个文件夹。由于nul文件并不会对项目有实际影响，不存在必须要单独删除nul文件的场景。

## 它怎么工作？

安装后，文件夹的右键「删除」会被替换为 nonul 版本：

```
右键删除文件夹
  → 递归找出文件夹里所有叫 nul 的文件（不区分大小写）
  → 用 \\?\ 前缀路径逐个删除
  → 把文件夹送进回收站
```

对于不含 `nul` 的文件夹，和原生删除完全一致。

## 安装

三种方式任选其一，装完即生效。

### irm（无需任何工具）

```powershell
irm https://raw.githubusercontent.com/4laoshiren/nonul/main/nonul.ps1 | iex
```

### Scoop

```powershell
scoop bucket add nonul https://github.com/4laoshiren/nonul
scoop install nonul
```

### npm

```
npm install -g nonul
```

## 卸载

### irm

```powershell
irm https://raw.githubusercontent.com/4laoshiren/nonul/main/nonul.ps1 -OutFile nonul.ps1; .\nonul.ps1 -Uninstall
```

### Scoop

```powershell
scoop uninstall nonul
```

### npm

```
npm uninstall -g nonul
```

## 原理

安装时修改当前用户的注册表（`HKCU`），不需要管理员权限：

在 `HKCU\Software\Classes\Directory\shell` 下创建 `delete` 键，用自定义命令覆盖原生的文件夹删除。

命令通过 `wscript.exe` 调用 VBS 辅助脚本，VBS 静默启动 PowerShell 执行实际的删除逻辑。卸载时删除该注册表键，恢复原生删除。

## License

MIT
