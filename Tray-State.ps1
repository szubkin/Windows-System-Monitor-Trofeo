function Resolve-TrayState($record, [int[]]$processIds, [bool]$launching, [bool]$failed, [DateTime]$now) {
    if ($processIds.Count -gt 0) {
        if ($record -and $processIds -contains [int]$record.pid) {
            if ($record.state -eq 'running') {
                try { if (($now - ([DateTime]$record.updatedUtc).ToUniversalTime()).TotalSeconds -le 5) { return 'running' } } catch {}
                return 'waiting'
            }
            if ($record.state -eq 'error') { return 'error' }
        }
        return 'waiting'
    }
    if ($launching) { return 'waiting' }
    if ($failed -or ($record -and $record.state -eq 'error')) { return 'error' }
    return 'stopped'
}
