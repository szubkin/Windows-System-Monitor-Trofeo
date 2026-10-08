param([string]$Destination = 'C:\Windows System Monitor Trofeo', [switch]$DesktopShortcut)
$ErrorActionPreference = 'Stop'
$destinationRoot = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
$sourceRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
if ($destinationRoot -eq $sourceRoot) { throw 'Source and destination must differ.' }
if (!(Test-Path -LiteralPath (Join-Path $destinationRoot 'WindowsSystemMonitorTrofeo.sln'))) { throw 'Existing Trofeo v0.0.16 project not found.' }
if (Test-Path -LiteralPath (Join-Path $destinationRoot 'artifacts\v0.0.17')) { throw 'v0.0.17 already exists. Nothing changed.' }
$baseline = Get-Content -LiteralPath (Join-Path $sourceRoot 'baseline-v0.0.16.json') -Raw | ConvertFrom-Json
foreach ($entry in $baseline.PSObject.Properties) {
    $target = Join-Path $destinationRoot $entry.Name
    if (!(Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target).Hash -ne $entry.Value) {
        throw "Existing source changed: $($entry.Name). Nothing changed; merge required."
    }
}
$files = @('WindowsSystemMonitorTrofeo.sln', 'NuGet.Config', '.gitignore', 'build.ps1', 'README.md', 'VALIDATION.md', 'PROTOCOL.md', 'THIRD-PARTY-NOTICES.md', 'Start-Trofeo.ps1', 'StabilityResult.ps1', 'Manage-Autostart.ps1', 'Preview-Window.ps1', 'Settings-Core.ps1', 'Settings-Window.ps1', 'Log-Retention.ps1', 'Build-Icons.ps1', 'Tray-State.ps1', 'Trofeo-Tray.ps1', 'Trofeo-Hidden.vbs')
foreach ($folder in @('src', 'tests', 'packages', 'assets', 'artifacts\v0.0.17')) {
    $files += Get-ChildItem -LiteralPath (Join-Path $sourceRoot $folder) -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\(bin|obj|logs)\\' } |
        ForEach-Object { $_.FullName.Substring($sourceRoot.Length + 1) }
}
foreach ($relative in $files) {
    $target = Join-Path $destinationRoot $relative
    if (($relative -like 'src\*' -or $relative -like 'tests\*') -and (Test-Path -LiteralPath $target) -and
        !($baseline.PSObject.Properties.Name -contains $relative)) { throw "New source collision: $relative" }
}
$backup = Join-Path $destinationRoot ('backups\before-v0.0.17-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
# Back up every existing affected file before copying the update.
foreach ($relative in $files) {
    $target = Join-Path $destinationRoot $relative
    if (Test-Path -LiteralPath $target) {
        $saved = Join-Path $backup $relative
        New-Item -ItemType Directory -Force -Path (Split-Path $saved) | Out-Null
        Copy-Item -LiteralPath $target -Destination $saved
    }
}
foreach ($relative in $files) {
    $source = Join-Path $sourceRoot $relative
    $target = Join-Path $destinationRoot $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
    if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) { throw "Copy verification failed: $relative. Backup: $backup" }
}
Write-Host "Installed v0.0.17: $destinationRoot"
Write-Host "Previous sources: $backup"
Write-Host 'artifacts\v0.0.16 and existing logs preserved. Driver unchanged.'





# Keep user settings when installing later releases.
$settingsPath = Join-Path $destinationRoot 'trofeo-settings.json'
if (!(Test-Path -LiteralPath $settingsPath)) { Copy-Item -LiteralPath (Join-Path $sourceRoot 'trofeo-settings.json') -Destination $settingsPath }
$shell = New-Object -ComObject WScript.Shell
$shortcutFolders = @($destinationRoot)
if ($DesktopShortcut) { $shortcutFolders += [Environment]::GetFolderPath('Desktop') }
foreach ($folder in $shortcutFolders) {
    foreach ($mode in @('Monitor','Stability')) {
        $name = if ($mode -eq 'Monitor') { 'Trofeo Monitor.lnk' } else { 'Trofeo Stability Test.lnk' }
        $shortcut = $shell.CreateShortcut((Join-Path $folder $name))
        $shortcut.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$destinationRoot\Start-Trofeo.ps1`" -Mode $mode"
        if ($mode -eq 'Monitor' -and (Test-Path -LiteralPath (Join-Path $destinationRoot 'Trofeo-Hidden.vbs'))) {
            $shortcut.TargetPath = "$env:SystemRoot\System32\wscript.exe"
            $shortcut.Arguments = '"' + (Join-Path $destinationRoot 'Trofeo-Hidden.vbs') + '" start'
        }
        $shortcut.IconLocation = (Join-Path $destinationRoot 'assets\trofeo-app.ico') + ',0'
        $shortcut.WorkingDirectory = $destinationRoot
        $shortcut.Description = "Trofeo $mode; requests administrator access for CPU sensors"
        $shortcut.Save()
    }
}
Write-Host 'Ready: Trofeo Monitor.lnk and Trofeo Stability Test.lnk. Settings: trofeo-settings.json'



