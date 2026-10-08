function Test-TrofeoStability {
    param($Report, [int]$ExitCode, [int]$Seconds, [int]$Fps, [bool]$CpuSensors)
    return ($ExitCode -eq 0 -and $Report.outcome -eq 'completed' -and
        $Report.elapsedSeconds -ge $Seconds -and $Report.averageFps -ge ($Fps * 0.8) -and
        $Report.metrics.GapsOver2Seconds -eq 0 -and $Report.metrics.SensorChecks -ge ($Seconds * 0.8) -and
        $Report.metrics.MissingGpuTemperature -eq 0 -and
        (!$CpuSensors -or $Report.metrics.MissingCpuTemperature -eq 0))
}
