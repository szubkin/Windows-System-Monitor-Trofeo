param([string]$Destination='C:\Windows System Monitor Trofeo')
$ErrorActionPreference='Stop'
if (!(Test-Path -LiteralPath (Join-Path $Destination 'artifacts\v0.0.14\WindowsSystemMonitorTrofeo.exe'))) { throw 'v0.0.14 required' }
if (Get-Process WindowsSystemMonitorTrofeo -ErrorAction SilentlyContinue) { throw 'Stop the monitor before applying this repair.' }
# Close only the stuck launcher and tray belonging to this installation.
$targets=@((Join-Path $Destination 'Start-Trofeo.ps1'),(Join-Path $Destination 'Trofeo-Tray.ps1'))
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | ForEach-Object {
    $process=$_
    if ($process.ProcessId -ne $PID -and $process.CommandLine) {
        foreach($target in $targets) {
            if ($process.CommandLine.IndexOf(('"' + $target + '"'),[StringComparison]::OrdinalIgnoreCase) -ge 0) {
                Stop-Process -Id $process.ProcessId -ErrorAction Stop
                break
            }
        }
    }
}
$backup=Join-Path $Destination ('backups\launcher-fix-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup | Out-Null
foreach($name in @('Start-Trofeo.ps1','Trofeo-Tray.ps1')) {
    Copy-Item -LiteralPath (Join-Path $Destination $name) -Destination $backup
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $Destination $name) -Force
}
Write-Host 'Launcher fixed. Reopen Trofeo Monitor.'
