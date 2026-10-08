$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $env:DOTNET_CLI_HOME = Join-Path $PSScriptRoot '.build-home'
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
    $env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
    dotnet build WindowsSystemMonitorTrofeo.sln -c Release -p:UseSharedCompilation=false
    if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
    dotnet run --project tests/ProtocolTests -c Release -p:UseSharedCompilation=false
    if ($LASTEXITCODE -ne 0) { throw 'Protocol checks failed' }
    & (Join-Path $PSScriptRoot 'tests\LauncherChecks.ps1')
    & (Join-Path $PSScriptRoot 'tests\TrayStateChecks.ps1')
    & (Join-Path $PSScriptRoot 'tests\SettingsChecks.ps1')
    $publishRoot = Join-Path $PSScriptRoot (".build-home\publish-" + [Guid]::NewGuid().ToString("N"))
    dotnet publish src/WindowsSystemMonitorTrofeo -c Release --no-self-contained -o $publishRoot -p:UseSharedCompilation=false
    if ($LASTEXITCODE -ne 0) { throw 'Publish failed' }
    & (Join-Path $publishRoot 'WindowsSystemMonitorTrofeo.exe') --check-runtime
    if ($LASTEXITCODE -ne 0) { throw 'Published runtime check failed' }
    $releaseRoot = Join-Path $PSScriptRoot 'artifacts\v0.1.7'
    New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
    Get-ChildItem -LiteralPath $publishRoot | Where-Object { $_.Name -ne 'logs' } | Copy-Item -Destination $releaseRoot -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $releaseRoot 'WindowsSystemMonitorTrofeo.exe') -Destination (Join-Path $releaseRoot 'TrofeoPreviewRenderer.exe')
    & (Join-Path $releaseRoot 'WindowsSystemMonitorTrofeo.exe') --check-runtime
    if ($LASTEXITCODE -ne 0) { throw 'Release runtime check failed' }
} finally { Pop-Location }








