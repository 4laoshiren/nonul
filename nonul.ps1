# nonul — 替换 Windows 资源管理器右键菜单中文件夹的「删除」，能处理含 nul 文件的文件夹
# 用法：.\nonul.ps1 [-Install] [-Uninstall]（无参数默认安装）

[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install')]
    [switch]$Install,

    [Parameter(ParameterSetName = 'Uninstall')]
    [switch]$Uninstall
)

try {

    # 安装：写入 VBS 辅助脚本并覆盖文件夹的 shell\delete
    function Install-Nonul {
        $nonulDirectory = Join-Path $env:LOCALAPPDATA "nonul"
        $registryPath = "Software\Classes\Directory"

        # 文件夹删除处理器：先递归删 nul 文件，再把文件夹送回收站
        $vbsContent = @'
Dim folderPath, escapedPath, command
folderPath = WScript.Arguments(0)
escapedPath = Replace(folderPath, "'", "''")
command = "powershell.exe -NoProfile -WindowStyle Hidden -Command ""Add-Type -AssemblyName Microsoft.VisualBasic;Get-ChildItem -LiteralPath '" & escapedPath & "' -Recurse -Force -Filter 'nul' -File -ErrorAction SilentlyContinue|ForEach-Object{[System.IO.File]::Delete('\\?\'+$_.FullName)};[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory('" & escapedPath & "','OnlyErrorDialogs','SendToRecycleBin')"""
CreateObject("WScript.Shell").Run command, 0, False
'@

        Write-Host ""
        Write-Host "=== nonul 安装开始 ===" -ForegroundColor Cyan
        Write-Host ""

        # 创建辅助脚本目录
        if (-not (Test-Path $nonulDirectory)) {
            New-Item -Path $nonulDirectory -ItemType Directory -Force | Out-Null
        }

        # 写入 VBS 辅助脚本
        $vbsFilePath = Join-Path $nonulDirectory "delete-directory.vbs"
        Write-Host "写入辅助脚本: $vbsFilePath"
        [System.IO.File]::WriteAllText($vbsFilePath, $vbsContent)

        # 创建 shell\delete 键，设置显示名称和图标
        Write-Host "覆盖删除菜单: HKCU\$registryPath\shell\delete"
        $deleteKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("$registryPath\shell\delete")
        $deleteKey.SetValue("", "删除(&D)")
        $deleteKey.SetValue("Icon", "shell32.dll,-240")
        $deleteKey.Close()

        # 创建 command 子项，指向 VBS 辅助脚本
        $commandKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("$registryPath\shell\delete\command")
        $commandKey.SetValue("", "wscript.exe `"$vbsFilePath`" `"%1`"")
        $commandKey.Close()

        Write-Host ""
        Write-Host "=== nonul 安装完成 ===" -ForegroundColor Green
        Write-Host "文件夹右键「删除」已替换，现在可以删除含 nul 文件的文件夹了。" -ForegroundColor Green
    }

    # 卸载：删除 shell\delete 键和 VBS 辅助脚本，恢复原生删除
    function Uninstall-Nonul {
        $nonulDirectory = Join-Path $env:LOCALAPPDATA "nonul"
        $registryPath = "Software\Classes\Directory"

        Write-Host ""
        Write-Host "=== nonul 卸载开始 ===" -ForegroundColor Cyan
        Write-Host ""

        # 恢复原生删除
        $shellKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("$registryPath\shell", $true)
        if ($shellKey -and ($shellKey.GetSubKeyNames() -contains "delete")) {
            Write-Host "恢复原生删除菜单: HKCU\$registryPath\shell\delete"
            $shellKey.DeleteSubKeyTree("delete")
        }
        if ($shellKey) { $shellKey.Close() }

        # 清理辅助脚本目录
        if (Test-Path $nonulDirectory) {
            Write-Host "清理辅助脚本: $nonulDirectory"
            Remove-Item -Path $nonulDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host ""
        Write-Host "=== nonul 卸载完成 ===" -ForegroundColor Green
        Write-Host "文件夹右键「删除」已恢复为系统默认。" -ForegroundColor Green
    }

    # 主入口：无参数或 -Install 执行安装，-Uninstall 执行卸载
    if ($Uninstall) {
        Uninstall-Nonul
    } else {
        Install-Nonul
    }

} catch {
    Write-Host ""
    Write-Host "出错了: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
