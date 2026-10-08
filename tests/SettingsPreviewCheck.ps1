$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root=Split-Path $PSScriptRoot
$copy=Join-Path $root 'artifacts\setup-check-020'
$logs=Join-Path $copy 'logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
# Fresh mock telemetry, not a USB monitor process.
$snapshot=@{Cpu=75;MemoryPercent=50;UsedGiB=16;TotalGiB=32;ReceiveBytes=1048576;SendBytes=2097152;DiskUsedPercent=40;DiskFreeGiB=200;DiskName='C:\';Hardware=@{GpuName='Preview Test GPU';GpuLoad=98;GpuTemperature=72;VramUsedMiB=6900;VramTotalMiB=8192;CpuTemperature=65;CpuClockMHz=4200;CpuSensor='CPU Package';Status=''}}
$record=@{state='running';pid=$PID;updatedUtc=[DateTime]::UtcNow.ToString("o");uptimeSeconds=10;fps=6;frames=60;reconnects=0;lastError=$null;lastErrorUtc=$null;previewUtc=[DateTime]::UtcNow.ToString("o");snapshot=$snapshot}
$record | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $logs 'monitor-status.json') -Encoding UTF8
. (Join-Path $copy 'Settings-Core.ps1')
. (Join-Path $copy 'Settings-Window.ps1')
Save-TrofeoSettings (New-TrofeoDefaults) (Join-Path $copy 'trofeo-settings.json')
$applied=@{Count=0}
$form=New-TrofeoSettingsForm -TestMode -TestPreview -OnApplied {$applied.Count++}.GetNewClosure()
function PumpUntil([scriptblock]$Condition){
    $deadline=[DateTime]::UtcNow.AddSeconds(8)
    while([DateTime]::UtcNow -lt $deadline){[Windows.Forms.Application]::DoEvents();if(& $Condition){return};Start-Sleep -Milliseconds 50}
    throw ('Preview operation timed out: '+($form.Controls | Where-Object {$_.Name -eq 'ConnectionStatus'}).Text)
}
try{
    $form.Show()
    $picture=$form.Controls | Where-Object {$_.Name -eq 'SettingsPreview'}
    PumpUntil {$null -ne $picture.Image}
    $privateFolder=Get-ChildItem $logs -Directory -Filter 'settings-preview-*' | Sort-Object CreationTime -Descending | Select-Object -First 1
    $jpeg=Join-Path $privateFolder.FullName 'preview.jpg'
    $liveSettings=Join-Path $copy 'trofeo-settings.json'
    $before=(Get-FileHash $liveSettings).Hash
    $imageBefore=(Get-FileHash $jpeg).Hash
    $draftBefore=[IO.File]::ReadAllText((Join-Path $privateFolder.FullName 'draft.json'))
    $body=$form.Controls | Where-Object {$_.Name -eq 'AllSettings'}
    $screen=$body.Controls | Where-Object {$_.Name -eq 'ScreenSettings'}
    $cpuMetric=$screen.Controls | Where-Object {$_.Name -eq 'CpuMetric'}
    $cpuMetric.SelectedIndex=1
    PumpUntil {([IO.File]::ReadAllText((Join-Path $privateFolder.FullName 'draft.json')) -ne $draftBefore)}
    PumpUntil {((Get-Content (Join-Path $privateFolder.FullName 'rendered-draft.json') -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json).CpuMetric -eq 'temperature')}
    $renderedStamp=(Get-Item $jpeg).LastWriteTimeUtc.Ticks
    PumpUntil {$picture.Tag -ge $renderedStamp}
    $language=$body.Controls | Where-Object {$_.Name -eq 'GeneralSettings'} | ForEach-Object {$_.Controls | Where-Object {$_.Name -eq 'Language'}}
    $theme=$screen.Controls | Where-Object {$_.Name -eq 'Theme'}
    $theme.SelectedIndex=1
    ($screen.Controls | Where-Object {$_.Name -eq 'GpuSecondaryRight'}).SelectedIndex=6
    PumpUntil {((Get-Content (Join-Path $privateFolder.FullName 'rendered-draft.json') -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json).Theme -eq 'light')}
    $language.SelectedIndex=1
    PumpUntil {((Get-Content (Join-Path $privateFolder.FullName 'rendered-draft.json') -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json).Language -eq 'en')}
    PumpUntil {($form.Controls | Where-Object {$_.Name -eq 'ConnectionStatus'}).Text.StartsWith('Status:')}
    if((Get-FileHash $liveSettings).Hash -ne $before){throw 'Draft leaked into applied settings'}
    $apply=$form.Controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.Text -eq 'Apply'}
    $apply.PerformClick()
    if($applied.Count -ne 1 -or (Read-TrofeoSettings $liveSettings).CpuMetric -ne 'temperature' -or (Read-TrofeoSettings $liveSettings).Language -ne 'en' -or (Read-TrofeoSettings $liveSettings).Theme -ne 'light' -or (Read-TrofeoSettings $liveSettings).GpuSecondaryRight -ne 'fan' -or !$form.Visible){throw 'Apply failed or closed window'}
    $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
    try{$form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bitmap.Save((Join-Path $root 'artifacts\qa\settings-integrated-preview.png'))}finally{$bitmap.Dispose()}
    $workers=@(Get-Process TrofeoPreviewRenderer -ErrorAction SilentlyContinue | Where-Object {$_.Path -and $_.Path.StartsWith($copy)})
    if($workers.Count -ne 1){throw 'Preview process must be separate and singular'}
    $worker=$workers[0]
    $form.Close()
    PumpUntil {$worker.HasExited}
    Write-Output 'PASS: live draft preview, unchanged applied file before Apply, Apply callback, separate renderer and clean shutdown.'
}finally{if(!$form.IsDisposed){$form.Close()};$form.Dispose()}
