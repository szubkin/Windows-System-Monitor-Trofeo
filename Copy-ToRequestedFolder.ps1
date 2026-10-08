$ErrorActionPreference = 'Stop'
$destination = 'C:\Windows System Monitor Trofeo'
if (Test-Path -LiteralPath $destination) { throw "Destination already exists: $destination. Nothing copied." }
New-Item -ItemType Directory -Path $destination | Out-Null
foreach ($name in @('src', 'tests', 'artifacts', 'logs', 'WindowsSystemMonitorTrofeo.sln', 'NuGet.Config', 'README.md', 'VALIDATION.md', 'build.ps1', '.gitignore')) {
    $source = Join-Path $PSScriptRoot $name
    if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $destination -Recurse }
}
Write-Host "Copied to $destination"
