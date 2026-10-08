param([string]$Destination = 'C:\Windows System Monitor Trofeo')
$ErrorActionPreference = 'Stop'
$destinationRoot = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
$sourceRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
if ($destinationRoot -eq $sourceRoot) { throw 'Source and destination must differ.' }
if (!(Test-Path -LiteralPath (Join-Path $destinationRoot 'WindowsSystemMonitorTrofeo.sln'))) { throw 'Existing Trofeo v0.0.4 project not found.' }
if (Test-Path -LiteralPath (Join-Path $destinationRoot 'artifacts\v0.0.5')) { throw 'v0.0.5 already exists. Nothing changed.' }
$baseline = Get-Content -LiteralPath (Join-Path $sourceRoot 'baseline-v0.0.4.json') -Raw | ConvertFrom-Json
foreach ($entry in $baseline.PSObject.Properties) {
    $target = Join-Path $destinationRoot $entry.Name
    if (!(Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target).Hash -ne $entry.Value) {
        throw "Existing source changed: $($entry.Name). Nothing changed; merge required."
    }
}
$files = @('WindowsSystemMonitorTrofeo.sln', 'NuGet.Config', '.gitignore', 'build.ps1', 'README.md', 'VALIDATION.md', 'PROTOCOL.md', 'THIRD-PARTY-NOTICES.md')
foreach ($folder in @('src', 'tests', 'packages', 'artifacts\v0.0.5')) {
    $files += Get-ChildItem -LiteralPath (Join-Path $sourceRoot $folder) -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\(bin|obj|logs)\\' } |
        ForEach-Object { $_.FullName.Substring($sourceRoot.Length + 1) }
}
foreach ($relative in $files) {
    $target = Join-Path $destinationRoot $relative
    if (($relative -like 'src\*' -or $relative -like 'tests\*') -and (Test-Path -LiteralPath $target) -and
        !($baseline.PSObject.Properties.Name -contains $relative)) { throw "New source collision: $relative" }
}
$backup = Join-Path $destinationRoot ('backups\before-v0.0.5-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
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
Write-Host "Installed v0.0.5: $destinationRoot"
Write-Host "Previous sources: $backup"
Write-Host 'artifacts\v0.0.4 and existing logs preserved. Driver unchanged.'



