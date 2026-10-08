param([string]$Destination = 'C:\Windows System Monitor Trofeo', [switch]$NoDesktop)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath (Join-Path $Destination 'artifacts\v0.0.10\WindowsSystemMonitorTrofeo.exe'))) { throw 'Install v0.0.10 first.' }
$launcher = Get-Content -LiteralPath (Join-Path $Destination 'Start-Trofeo.ps1') -Raw
if ($launcher -notmatch '\[switch\]\$Background') { throw 'Launcher must support -Background.' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Trofeo-Hidden.vbs') -Destination $Destination -Force
$folders = @($Destination)
if (!$NoDesktop) { $folders += [Environment]::GetFolderPath('Desktop') }
$shell = New-Object -ComObject WScript.Shell
foreach ($folder in $folders) {
    foreach ($mode in @('start','stop')) {
        $name = if ($mode -eq 'start') { 'Trofeo Monitor.lnk' } else { 'Trofeo Stop.lnk' }
        $path = Join-Path $folder $name
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination ($path + '.before-hidden-' + (Get-Date -Format 'yyyyMMddHHmmssfff')) }
        $link = $shell.CreateShortcut($path)
        $link.TargetPath = "$env:SystemRoot\System32\wscript.exe"
        $link.Arguments = '"' + (Join-Path $Destination 'Trofeo-Hidden.vbs') + '" ' + $mode
        $link.WorkingDirectory = $Destination
        $link.IconLocation = "$Destination\artifacts\v0.0.10\WindowsSystemMonitorTrofeo.exe,0"
        $link.Description = "Trofeo $mode without console (administrator approval may appear)"
        $link.Save()
    }
}
Write-Host 'Ready: Trofeo Monitor starts hidden; Trofeo Stop requests graceful shutdown.'
