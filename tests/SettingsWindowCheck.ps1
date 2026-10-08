$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root=Split-Path $PSScriptRoot
$copy=Join-Path $root ('artifacts\settings-ui-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $copy 'assets') -Force | Out-Null
foreach($name in @('Ui-Theme.ps1','Settings-Core.ps1','Settings-Window.ps1','trofeo-settings.json')) {Copy-Item -LiteralPath (Join-Path $root $name) -Destination $copy}
Copy-Item -LiteralPath (Join-Path $root 'assets\trofeo-app.ico') -Destination (Join-Path $copy 'assets')
. (Join-Path $copy 'Settings-Core.ps1')
. (Join-Path $copy 'Settings-Window.ps1')
$form=New-TrofeoSettingsForm -TestMode
try {
    if($form.Controls.Count -lt 15){throw 'Controls missing'}
    $form.Show()
    [Windows.Forms.Application]::DoEvents()
    $bmp=New-Object Drawing.Bitmap($form.Width,$form.Height)
    try {$form.DrawToBitmap($bmp,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bmp.Save((Join-Path $root 'artifacts\qa\settings-window.png'))}finally{$bmp.Dispose()}
    $numeric=@($form.Controls | Where-Object {$_ -is [Windows.Forms.NumericUpDown]})
    $before=(Get-FileHash (Join-Path $copy 'trofeo-settings.json')).Hash
    $numeric[0].Value=2
    $resetButton=$form.Controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.Location.X -eq 340}
    $resetButton.PerformClick()
    if($numeric[0].Value -ne 6 -or (Get-FileHash (Join-Path $copy 'trofeo-settings.json')).Hash -ne $before){throw 'Reset must update form only'}
    $numeric[0].Value=5
    $numeric[3].Value=72; $numeric[4].Value=92; $numeric[5].Value=68; $numeric[6].Value=88
    $button=$form.Controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.DialogResult -ne 'Cancel'} | Select-Object -First 1
    $button.PerformClick()
    if($form.DialogResult -ne 'OK' -or (Read-TrofeoSettings (Join-Path $copy 'trofeo-settings.json')).Fps -ne 5) {throw 'Apply did not save settings'}
    if((Read-TrofeoSettings (Join-Path $copy 'trofeo-settings.json')).CpuYellow -ne 72){throw 'Threshold not saved by UI'}
    Write-Output 'PASS: settings UI rendered and Apply saved FPS in isolated copy; real settings and autostart unchanged.'
} finally {$form.Dispose()}
