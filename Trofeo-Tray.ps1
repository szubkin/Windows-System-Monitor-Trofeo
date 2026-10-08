param([switch]$SelfTest)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'Tray-State.ps1')
. (Join-Path $PSScriptRoot 'Preview-Window.ps1')
. (Join-Path $PSScriptRoot 'Settings-Core.ps1')
. (Join-Path $PSScriptRoot 'Settings-Window.ps1')
. (Join-Path $PSScriptRoot 'Log-Retention.ps1')
$script:nextCleanup = [DateTime]::MinValue
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:pending = ''
$script:exitRequested = $null
$script:child = $null
$script:deadline = [DateTime]::MinValue
$script:sessionId = (Get-Process -Id $PID).SessionId
function Get-Monitors {
    @(Get-Process WindowsSystemMonitorTrofeo -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $script:sessionId })
}
function Show-Failure($message) {
    $icon.ShowBalloonTip(6000, 'Trofeo', $message, [System.Windows.Forms.ToolTipIcon]::Warning)
    $logFolder = Join-Path $PSScriptRoot 'logs'
    New-Item -ItemType Directory -Force -Path $logFolder | Out-Null
    Add-Content -LiteralPath (Join-Path $logFolder 'tray.log') -Value ("{0:o} {1}" -f [DateTimeOffset]::Now,$message)
}
function Start-Monitor {
    if (@(Get-Monitors).Count -gt 0 -or ($script:child -and !$script:child.HasExited)) { return }
    $script:child = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -PassThru -ArgumentList "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSScriptRoot\Start-Trofeo.ps1`" -Background"
}
function Request-Stop([string]$next) {
    $script:pending = $next
    $script:deadline = [DateTime]::UtcNow.AddSeconds(45)
    $signal = New-Object System.Threading.EventWaitHandle($false,[System.Threading.EventResetMode]::ManualReset,'Local\TrofeoStop')
    try { [void]$signal.Set() } finally { $signal.Dispose() }
}
function Set-Autostart([string]$action) {
    $p = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -Wait -PassThru -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\Manage-Autostart.ps1`" -Action $action"
    if ($p.ExitCode -ne 0) { throw "Autostart operation failed ($($p.ExitCode))." }
}
$icon = New-Object System.Windows.Forms.NotifyIcon
$stateIcons = @{}
foreach ($name in @('running','waiting','stopped','error')) {
    $stateIcons[$name] = New-Object System.Drawing.Icon((Join-Path $PSScriptRoot "assets\tray-$name.ico"),([System.Drawing.Size]::new(16,16)))
}
$icon.Icon = $stateIcons.stopped
$icon.Text = 'Trofeo'
. (Join-Path $PSScriptRoot 'Ui-Theme.ps1')
$menu = New-Object System.Windows.Forms.ContextMenuStrip
[TrofeoUi.DarkTheme]::Menu($menu)
$status = $menu.Items.Add('Trofeo v0.1.7')
$status.Enabled = $false
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$start = $menu.Items.Add('Запустить')
$stop = $menu.Items.Add('Остановить')
$restart = $menu.Items.Add('Перезапустить')
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$auto = $menu.Items.Add('Автозапуск при входе')
$settingsItem = $menu.Items.Add('Настройки и предпросмотр...')
$settingsItem.add_Click({
    if ($script:pending) { return }
    $dialog=$null
    try {
        $dialog=New-TrofeoSettingsForm -OnApplied {
            $script:nextCleanup=[DateTime]::MinValue
            if(!$script:pending -and (@(Get-Monitors).Count -gt 0 -or ($script:child -and !$script:child.HasExited))) { Request-Stop 'restart' }
        }
        [void]$dialog.ShowDialog()
    } catch { Show-Failure $_.Exception.Message }
    finally { if($dialog){$dialog.Dispose()};$timer.Start() }
})
$logs = $menu.Items.Add('Открыть логи')
$quit = $menu.Items.Add('Выход')
$icon.ContextMenuStrip = $menu
$start.add_Click({ try { Start-Monitor } catch { Show-Failure $_.Exception.Message } })
$stop.add_Click({ try { Request-Stop 'stop' } catch { Show-Failure $_.Exception.Message } })
$restart.add_Click({ try { Request-Stop 'restart' } catch { Show-Failure $_.Exception.Message } })
$quit.add_Click({ try { Request-Stop 'exit' } catch { Show-Failure $_.Exception.Message } })
$logs.add_Click({ try { $folder=Join-Path $PSScriptRoot 'logs'; New-Item -ItemType Directory -Force -Path $folder | Out-Null; Start-Process explorer.exe -ArgumentList ('"' + $folder + '"') } catch { Show-Failure $_.Exception.Message } })
$auto.add_Click({ try { if ($auto.Checked) { Set-Autostart 'Disable' } else { Set-Autostart 'Enable' }; $auto.Checked = !$auto.Checked } catch { Show-Failure $_.Exception.Message } })
$menu.add_Opening({
    try { $task=Get-ScheduledTask -TaskName 'Windows System Monitor Trofeo' -ErrorAction SilentlyContinue; $auto.Checked=($null -ne $task -and $task.State -ne 'Disabled') } catch { $auto.Checked=$false }
})
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$tick = {
    try {
        if($script:exitRequested -and $script:exitRequested.WaitOne(0) -and $script:pending -ne 'exit'){Request-Stop 'exit'}
        if(!$SelfTest -and [DateTime]::UtcNow -ge $script:nextCleanup) {
            $script:nextCleanup=[DateTime]::UtcNow.AddHours(1)
            try {
                $retention=Read-TrofeoSettings (Join-Path $PSScriptRoot 'trofeo-settings.json')
                Clear-TrofeoLogs $PSScriptRoot $retention.LogDays $retention.LogMaxMiB @((Get-Process).Id)
            } catch { Show-Failure $_.Exception.Message }
        }
        $running = @(Get-Monitors).Count -gt 0
        $launching = $script:child -and !$script:child.HasExited
        if ($script:pending) {
            if (!$running -and !$launching) {
                $next = $script:pending
                $script:pending = ''
                if ($next -eq 'exit') { [System.Windows.Forms.Application]::Exit(); return }
                if ($next -eq 'restart') { Start-Monitor }
            } elseif ([DateTime]::UtcNow -gt $script:deadline) {
                $script:pending = ''
                Show-Failure 'Монитор не завершился за 45 секунд. Повторный запуск отменён; проверьте логи.'
            } else {
                # Repeat the signal in case Stop was clicked while the child was still starting.
                $signal = New-Object System.Threading.EventWaitHandle($false,[System.Threading.EventResetMode]::ManualReset,'Local\TrofeoStop')
                try { [void]$signal.Set() } finally { $signal.Dispose() }
            }
        }
        $record = $null
        if (!$SelfTest) {
            try { $record = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'logs\monitor-status.json') -Raw -ErrorAction Stop | ConvertFrom-Json } catch {}
        }
        $failed = $script:child -and $script:child.HasExited -and $script:child.ExitCode -ne 0
        $state = Resolve-TrayState $record @((Get-Monitors) | ForEach-Object { $_.Id }) ([bool]$launching) ([bool]$failed) ([DateTime]::UtcNow)
        $text = @{running='Работает';waiting='Ожидает USB';stopped='Остановлен';error='Ошибка'}[$state]
        if ($script:pending) { $text='Остановка...' }
        $icon.Icon = $stateIcons[$state]
        $icon.Text = 'Trofeo: ' + $text
        $status.Text = 'v0.1.7 — ' + $text
        $start.Enabled = !$running -and !$launching -and !$script:pending
        $stop.Enabled = ($running -or $launching) -and !$script:pending
        $restart.Enabled = !$script:pending
    } catch { $timer.Stop(); Show-Failure $_.Exception.Message }
}
$timer.add_Tick($tick)
if ($SelfTest) {
    if ($menu.Items.Count -ne 10 -or $icon.Text -ne 'Trofeo') { throw 'Tray construction failed' }
    $script:fakeRunning = $true
    $script:starts = 0
    function Get-Monitors { if ($script:fakeRunning) { @([pscustomobject]@{ Id=123 }) } else { @() } }
    function Start-Process { $script:starts++; [pscustomobject]@{ HasExited=$false } }
    Start-Monitor
    if ($script:starts -ne 0) { throw 'Duplicate monitor allowed' }
    $script:fakeRunning=$false
    Start-Monitor
    Start-Monitor
    if ($script:starts -ne 1) { throw 'Starting child not protected' }
    $script:child=[pscustomobject]@{ HasExited=$true }
    $script:pending='restart'
    & $tick
    if ($script:starts -ne 2 -or $script:pending) { throw 'Restart failed' }
    $script:child=[pscustomobject]@{ HasExited=$true }
    $script:pending='stop'
    & $tick
    if ($script:starts -ne 2 -or $script:pending -or !$start.Enabled) { throw 'Stop restarted monitor' }
    $timer.Dispose(); $icon.Dispose(); $menu.Dispose(); foreach ($item in $stateIcons.Values) { $item.Dispose() }
    Write-Output 'PASS: tray and menu created without launching monitor or changing autostart.'
    exit
}
$script:exitRequested = New-Object System.Threading.EventWaitHandle($false,[System.Threading.EventResetMode]::ManualReset,'Local\TrofeoExit')
$mutex = New-Object System.Threading.Mutex($false,'Local\TrofeoTray')
$owned = $false
try {
    try { $owned=$mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owned=$true }
    if (!$owned) { exit }
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Launch using the Trofeo Monitor shortcut.' }
    $icon.Visible=$true
    Start-Monitor
    $timer.Start()
    [System.Windows.Forms.Application]::Run()
} catch { [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Trofeo') }
finally {
    if($script:previewWindow -and !$script:previewWindow.IsDisposed){$script:previewWindow.Close();$script:previewWindow.Dispose()}
    $timer.Stop(); $timer.Dispose(); $icon.Visible=$false; $icon.Dispose(); $menu.Dispose(); foreach ($item in $stateIcons.Values) { $item.Dispose() }
    if ($owned) { $mutex.ReleaseMutex() }
    $mutex.Dispose();$script:exitRequested.Dispose()
}
