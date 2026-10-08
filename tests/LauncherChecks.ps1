$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\StabilityResult.ps1')
$report = [pscustomobject]@{ outcome='completed'; elapsedSeconds=1800.1; averageFps=5.75; metrics=[pscustomobject]@{ GapsOver2Seconds=0; SensorChecks=1700; MissingGpuTemperature=0; MissingCpuTemperature=0 } }
function Expect([bool]$value,[string]$label) { if (!$value) { throw $label }; Write-Host "PASS $label" }
Expect (Test-TrofeoStability $report 0 1800 6 $true) 'complete stable report accepted'
$report.outcome='cancelled'
Expect (!(Test-TrofeoStability $report 0 1800 6 $true)) 'cancelled test not passed'
$report.outcome='completed'; $report.metrics.GapsOver2Seconds=1
Expect (!(Test-TrofeoStability $report 0 1800 6 $true)) 'long frame interruption not passed'
$report.metrics.GapsOver2Seconds=0; $report.metrics.MissingCpuTemperature=1
Expect (!(Test-TrofeoStability $report 0 1800 6 $true)) 'CPU sensor dropout not passed'
$report.metrics.MissingCpuTemperature=0; $report.averageFps=2.5
Expect (!(Test-TrofeoStability $report 0 1800 6 $true)) 'low frame rate not passed'
$report.averageFps=5.75
Expect (!(Test-TrofeoStability $report 6 1800 6 $true)) 'USB failure exit not passed'
Write-Host '6 launcher report checks passed; no hardware accessed.'
