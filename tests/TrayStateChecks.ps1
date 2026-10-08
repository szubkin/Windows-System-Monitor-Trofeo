$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\Tray-State.ps1')
$now=[DateTime]::UtcNow
function Check($condition,$name) { if (!$condition) { throw $name }; Write-Output "PASS $name" }
$r=[pscustomobject]@{pid=123;state='running';updatedUtc=$now.ToString('o')}
Check ((Resolve-TrayState $r @(123) $false $false $now) -eq 'running') 'fresh acknowledged frames'
Check ((Resolve-TrayState $r @(124) $false $false $now) -eq 'waiting') 'old process ignored'
Check ((Resolve-TrayState $r @(123) $false $false $now.AddSeconds(6)) -eq 'waiting') 'stale running state not green'
$r.state='waiting'
Check ((Resolve-TrayState $r @(123) $false $false $now) -eq 'waiting') 'USB reconnect waiting'
Check ((Resolve-TrayState $null @() $false $false $now) -eq 'stopped') 'stopped grey'
Check ((Resolve-TrayState $null @() $false $true $now) -eq 'error') 'child failure red'
$r.state='error'
Check ((Resolve-TrayState $r @() $false $false $now) -eq 'error') 'terminal error preserved'
Check ((Resolve-TrayState $r @() $true $false $now) -eq 'waiting') 'new launch supersedes old error'
