param([ValidateSet('Enable','Disable','Stop','Status')][string]$Action = 'Status')
$ErrorActionPreference = 'Stop'
$name = 'Windows System Monitor Trofeo'
if ($Action -eq 'Stop') {
    $signal = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::ManualReset, 'Local\TrofeoStop')
    try { [void]$signal.Set() } finally { $signal.Dispose() }
    Write-Host 'Stop requested. Wait for the current USB operation to finish.'
    exit
}
if ($Action -eq 'Status') { Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue | Select-Object TaskName,State; exit }
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run this command from an administrator PowerShell.' }
if ($Action -eq 'Disable') { Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue; Write-Host 'Autostart removed. Use -Action Stop to stop the current monitor.'; exit }
$exe = Join-Path $PSScriptRoot 'artifacts\v0.0.19\WindowsSystemMonitorTrofeo.exe'
if (!(Test-Path -LiteralPath $exe)) { throw 'Install v0.0.19 first.' }
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$taskAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSScriptRoot\Trofeo-Tray.ps1`"" -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$trigger.Delay = 'PT20S'
$taskPrincipal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $name -Action $taskAction -Trigger $trigger -Principal $taskPrincipal -Settings $settings -Description 'Trofeo monitor at user logon; waits for USB and reconnects.' -Force | Out-Null
Write-Host 'Autostart enabled for the current user, 20 seconds after sign-in. No password stored.'
