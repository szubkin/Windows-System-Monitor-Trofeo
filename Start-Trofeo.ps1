param([ValidateSet('Monitor','Stability')][string]$Mode = 'Monitor', [switch]$Background)
$ErrorActionPreference = 'Stop'
try {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        # This is the interactive console the user launches and uses to stop the monitor.
        $child = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Verb RunAs -WindowStyle Normal -PassThru -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode $Mode"
        exit $child.ExitCode
    }
    . (Join-Path $PSScriptRoot 'Settings-Core.ps1')
    $settings = Read-TrofeoSettings (Join-Path $PSScriptRoot 'trofeo-settings.json')
    . (Join-Path $PSScriptRoot 'Log-Retention.ps1')
    try { Clear-TrofeoLogs $PSScriptRoot $settings.LogDays $settings.LogMaxMiB @((Get-Process).Id) } catch { Write-Warning $_.Exception.Message }
    $exe = Join-Path $PSScriptRoot 'artifacts\v0.1.7\WindowsSystemMonitorTrofeo.exe'
    if (!(Test-Path -LiteralPath $exe)) { throw 'v0.1.7 executable is missing. Run Trofeo-Setup-0.1.7.exe first.' }
    $runFolder = Join-Path $PSScriptRoot ('logs\daily-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + $PID)
    $launchArgs = @(Get-TrofeoArguments $settings $Mode $runFolder $PSScriptRoot)
    if (!$Background) { $Host.UI.RawUI.WindowTitle = "Trofeo - $Mode - Ctrl+C to stop" }
    Write-Host 'Close TRCC. Recovery enabled in Monitor mode. Stop with Ctrl+C, not the window close button.'
    Write-Host "Mode: $Mode. Results: $runFolder"
    & $exe @launchArgs
    $exitCode = $LASTEXITCODE
    $resultFile = Get-ChildItem -LiteralPath $runFolder -Filter '*-summary.json' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Mode -eq 'Stability' -and $resultFile) {
        $result = Get-Content -LiteralPath $resultFile.FullName -Raw | ConvertFrom-Json
        . (Join-Path $PSScriptRoot 'StabilityResult.ps1')
        $passed = Test-TrofeoStability $result $exitCode $settings.StabilitySeconds $settings.Fps $settings.CpuSensors
        $verdict = if ($passed) { 'PASS: duration, USB transfers, frame gaps and sensor availability meet the test criteria.' } else { 'NOT CONFIRMED: inspect summary for cancellation, errors, frame gaps, low FPS or missing sensors.' }
        $verdict | Set-Content -LiteralPath (Join-Path $runFolder 'stability-result.txt')
        Write-Host $verdict
        if (!$passed -and $exitCode -eq 0) { $exitCode = 8 }
    }
    elseif ($Mode -eq 'Stability') { Write-Host 'NOT CONFIRMED: no completed session report.' }
    Write-Host "Exit code: $exitCode. Logs: $runFolder"
    if (!$Background) { Read-Host 'Press Enter to close' | Out-Null }
    exit $exitCode
}
catch {
    Write-Host "Trofeo launch failed: $($_.Exception.Message)" -ForegroundColor Red
    if (!$Background) { Read-Host 'Press Enter to close' | Out-Null }
    exit 1
}



