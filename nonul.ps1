# nonul — replace folder "Delete" in Windows Explorer context menu, handles folders containing nul files
# Usage: .\nonul.ps1 [-Install] [-Uninstall] (defaults to Install)

[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install')]
    [switch]$Install,

    [Parameter(ParameterSetName = 'Uninstall')]
    [switch]$Uninstall
)

try {

    # Install: write VBS helper script and override folder shell\delete
    function Install-Nonul {
        $nonulDirectory = Join-Path $env:LOCALAPPDATA "nonul"
        $registryPath = "Software\Classes\Directory"

        # Folder delete handler: recursively remove nul files, then send folder to recycle bin
        $vbsContent = @'
Dim folderPath, escapedPath, command
folderPath = WScript.Arguments(0)
escapedPath = Replace(folderPath, "'", "''")
command = "powershell.exe -NoProfile -WindowStyle Hidden -Command ""Add-Type -AssemblyName Microsoft.VisualBasic;Get-ChildItem -LiteralPath '" & escapedPath & "' -Recurse -Force -Filter 'nul' -File -ErrorAction SilentlyContinue|ForEach-Object{[System.IO.File]::Delete('\\?\'+$_.FullName)};[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory('" & escapedPath & "','OnlyErrorDialogs','SendToRecycleBin')"""
CreateObject("WScript.Shell").Run command, 0, False
'@

        Write-Host ""
        Write-Host "=== nonul install started ===" -ForegroundColor Cyan
        Write-Host ""

        # Create helper script directory
        if (-not (Test-Path $nonulDirectory)) {
            New-Item -Path $nonulDirectory -ItemType Directory -Force | Out-Null
        }

        # Write VBS helper script
        $vbsFilePath = Join-Path $nonulDirectory "delete-directory.vbs"
        Write-Host "Write helper script: $vbsFilePath"
        [System.IO.File]::WriteAllText($vbsFilePath, $vbsContent)

        # Create shell\delete key with display name and icon
        Write-Host "Override delete menu: HKCU\$registryPath\shell\delete"
        $deleteKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("$registryPath\shell\delete")
        $deleteKey.SetValue("", "删除(&D)")
        $deleteKey.SetValue("Icon", "shell32.dll,-240")
        $deleteKey.Close()

        # Create command subkey pointing to VBS helper script
        $commandKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("$registryPath\shell\delete\command")
        $commandKey.SetValue("", "wscript.exe `"$vbsFilePath`" `"%1`"")
        $commandKey.Close()

        Write-Host ""
        Write-Host "=== nonul install completed ===" -ForegroundColor Green
        Write-Host "Folder right-click 'Delete' has been replaced." -ForegroundColor Green
    }

    # Uninstall: remove shell\delete key and VBS helper script, restore native delete
    function Uninstall-Nonul {
        $nonulDirectory = Join-Path $env:LOCALAPPDATA "nonul"
        $registryPath = "Software\Classes\Directory"

        Write-Host ""
        Write-Host "=== nonul uninstall started ===" -ForegroundColor Cyan
        Write-Host ""

        # Restore native delete
        $shellKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("$registryPath\shell", $true)
        if ($shellKey -and ($shellKey.GetSubKeyNames() -contains "delete")) {
            Write-Host "Restore native delete menu: HKCU\$registryPath\shell\delete"
            $shellKey.DeleteSubKeyTree("delete")
        }
        if ($shellKey) { $shellKey.Close() }

        # Clean up helper script directory
        if (Test-Path $nonulDirectory) {
            Write-Host "Clean helper script: $nonulDirectory"
            Remove-Item -Path $nonulDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host ""
        Write-Host "=== nonul uninstall completed ===" -ForegroundColor Green
        Write-Host "Folder right-click 'Delete' has been restored to system default." -ForegroundColor Green
    }

    # Entry point: no args or -Install runs install, -Uninstall runs uninstall
    if ($Uninstall) {
        Uninstall-Nonul
    } else {
        Install-Nonul
    }

} catch {
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
}
