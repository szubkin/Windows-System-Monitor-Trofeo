param([double]$Scale=1)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root=Split-Path $PSScriptRoot
$copy=Join-Path $root ('artifacts\settings-ui-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $copy 'assets') -Force | Out-Null
foreach($name in @('Localization.ps1','Ui-Theme.ps1','Settings-Core.ps1','Settings-Window.ps1','Settings-Tools.ps1','trofeo-settings.json')) {Copy-Item -LiteralPath (Join-Path $root $name) -Destination $copy}
Copy-Item -LiteralPath (Join-Path $root 'assets\trofeo-app.ico') -Destination (Join-Path $copy 'assets')
. (Join-Path $copy 'Settings-Core.ps1')
. (Join-Path $copy 'Settings-Window.ps1')
$applied=@{Count=0}
$form=New-TrofeoSettingsForm -TestMode -OnApplied {$applied.Count++}.GetNewClosure()
if($Scale -ne 1){
    $form.AutoScaleMode='None'
    $form.Font=New-Object Drawing.Font('Segoe UI',(10*$Scale))
    $form.Scale((New-Object Drawing.SizeF($Scale,$Scale)))
}
try {
    $body=$form.Controls | Where-Object {$_.Name -eq 'AllSettings'}
    $general=$body.Controls | Where-Object {$_.Name -eq 'GeneralSettings'}
    $screen=$body.Controls | Where-Object {$_.Name -eq 'ScreenSettings'}
    if(@($form.Controls | Where-Object {$_ -is [Windows.Forms.TabControl]}).Count -ne 0){throw 'Unexpected settings tabs'}
    if($general.Controls.Count -lt 15 -or $screen.Controls.Count -lt 10){throw 'Controls missing'}
    $form.Show()
    [Windows.Forms.Application]::DoEvents()
    $bmp=New-Object Drawing.Bitmap($form.Width,$form.Height)
    try {$form.DrawToBitmap($bmp,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bmp.Save((Join-Path $root 'artifacts\qa\settings-window.png'))}finally{$bmp.Dispose()}
    $picture=$form.Controls | Where-Object {$_.Name -eq 'SettingsPreview'}
    $status=$form.Controls | Where-Object {$_.Name -eq 'ConnectionStatus'}
    if([Math]::Abs($picture.Width/$picture.Height-1920.0/462) -gt 0.03 -or $picture.Bottom -gt $body.Top -or $status.Top -lt $body.Bottom){throw 'Preview proportions or status position invalid'}
    $numeric=@($general.Controls | Where-Object {$_ -is [Windows.Forms.NumericUpDown]})
    [Windows.Forms.Application]::DoEvents()
    $bmp=New-Object Drawing.Bitmap($form.Width,$form.Height)
    try{$form.DrawToBitmap($bmp,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bmp.Save((Join-Path $root ('artifacts\qa\settings-screen-'+$Scale+'.png')))}finally{$bmp.Dispose()}
    $blocks=@($screen.Controls | Where-Object {$_.Name -like 'Block*'})
    $blocks | ForEach-Object {$_.Checked=$false}
    $apply=$form.Controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.Text -eq 'Применить'}
    $invalid=$false;try{$apply.PerformClick()}catch{$invalid=$true}
    if(!$invalid){throw 'Empty block selection must be rejected'}
    $before=(Get-FileHash (Join-Path $copy 'trofeo-settings.json')).Hash
    $numeric[0].Value=2
    $resetButton=$form.Controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.Text -eq 'По умолчанию'}
    $preset=$screen.Controls | Where-Object {$_.Name -eq 'AppearanceProfile'}
    $preset.SelectedIndex=2
    if(($screen.Controls | Where-Object {$_.Name -eq 'CpuMetric'}).SelectedItem.Value -ne 'temperature' -or ($screen.Controls | Where-Object {$_.Name -eq 'CpuSecondaryRight'}).SelectedItem.Value -ne 'power'){throw 'Preset did not load coherent metric choices'}
    if((Get-FileHash (Join-Path $copy 'trofeo-settings.json')).Hash -ne $before){throw 'Preset changed saved settings before Apply'}
    $resetButton.PerformClick()
    if($numeric[0].Value -ne 6 -or (Get-FileHash (Join-Path $copy 'trofeo-settings.json')).Hash -ne $before){throw 'Reset must update form only'}
    if(@($blocks | Where-Object {$_.Checked}).Count -ne 5){throw 'Reset did not restore display blocks'}
    foreach($c in $blocks){$c.Checked=$c.Name -in @('BlockCPU','BlockGPU')}
    ($screen.Controls | Where-Object {$_.Name -eq 'CpuMetric'}).SelectedIndex=1
    ($screen.Controls | Where-Object {$_.Name -eq 'TextPercent'}).SelectedIndex=2
    $color=$screen.Controls | Where-Object {$_.Name -eq 'AccentColor'};$color.Tag='#FF8844'
    ($screen.Controls | Where-Object {$_.Name -eq 'ShowGraphs'}).Checked=$false
    $numeric[0].Value=5
    $numeric[3].Value=72; $numeric[4].Value=92; $numeric[5].Value=68; $numeric[6].Value=88
    $button=$form.Controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.DialogResult -ne 'Cancel'} | Select-Object -First 1
    $button.PerformClick()
    if(!$form.Visible -or $form.IsDisposed -or (Read-TrofeoSettings (Join-Path $copy 'trofeo-settings.json')).Fps -ne 5) {throw 'Apply did not save settings'}
    if((Read-TrofeoSettings (Join-Path $copy 'trofeo-settings.json')).CpuYellow -ne 72){throw 'Threshold not saved by UI'}
    $saved=Read-TrofeoSettings (Join-Path $copy 'trofeo-settings.json')
    if($saved.DisplayBlocks -ne 'CPU,GPU' -or $saved.CpuMetric -ne 'temperature' -or $saved.TextPercent -ne 110 -or $saved.AccentColor -ne '#FF8844' -or $saved.ShowGraphs){throw 'Display settings not saved by UI'}
    if($applied.Count -ne 1){throw 'Apply notification missing'}
    $numeric[0].Value=4
    $apply.PerformClick()
    if($applied.Count -ne 2 -or !$form.Visible -or (Read-TrofeoSettings (Join-Path $copy 'trofeo-settings.json')).Fps -ne 4){throw 'Repeated Apply failed'}
    foreach($control in @($screen.Controls | Where-Object {$_ -is [Windows.Forms.ComboBox] -or $_.Name -eq 'AccentColor'})){
        foreach($label in @($screen.Controls | Where-Object {$_ -is [Windows.Forms.Label]})){
            if($control.Bounds.IntersectsWith($label.Bounds)){throw 'Screen label overlaps an input control'}
        }
    }
    $buttons=@($form.Controls | Where-Object {$_ -is [Windows.Forms.Button]} | Sort-Object Left)
    if($buttons.Count -ne 5 -or @($buttons | Select-Object -ExpandProperty Top -Unique).Count -ne 1 -or @($buttons | Select-Object -ExpandProperty Width -Unique).Count -ne 1 -or @($buttons | Select-Object -ExpandProperty Height -Unique).Count -ne 1){throw 'Footer buttons not aligned'}
    $color.Invalidate();[Windows.Forms.Application]::DoEvents()
    $swatch=New-Object Drawing.Bitmap($color.Width,$color.Height)
    try{$color.DrawToBitmap($swatch,(New-Object Drawing.Rectangle(0,0,$color.Width,$color.Height)));if($color.Text -ne '' -or $swatch.GetPixel([int]($color.Width/2),[int]($color.Height/2)).ToArgb() -ne [Drawing.ColorTranslator]::FromHtml('#FF8844').ToArgb()){throw 'Accent swatch not painted'}}finally{$swatch.Dispose()}
    $language=$general.Controls | Where-Object {$_.Name -eq 'Language'}
    $beforeLanguage=(Get-FileHash (Join-Path $copy 'trofeo-settings.json')).Hash
    $language.SelectedIndex=1
    [Windows.Forms.Application]::DoEvents()
    if($form.Text -ne 'Trofeo — settings, preview and connection' -or $apply.Text -ne 'Apply' -or ($screen.Controls | Where-Object {$_.Name -eq 'CpuMetric'}).SelectedItem.Value -ne 'temperature'){throw 'English translation changed values or missed controls'}
    if((Get-FileHash (Join-Path $copy 'trofeo-settings.json')).Hash -ne $beforeLanguage){throw 'Draft language saved before Apply'}
    $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
    try{$form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bitmap.Save((Join-Path $root ('artifacts\qa\settings-en-'+$Scale+'.png')))}finally{$bitmap.Dispose()}
    $apply.PerformClick()
    if((Read-TrofeoSettings (Join-Path $copy 'trofeo-settings.json')).Language -ne 'en'){throw 'English selection not saved'}
    $language.SelectedIndex=0
    if($apply.Text -ne 'Применить' -or (Read-TrofeoSettings (Join-Path $copy 'trofeo-settings.json')).Language -ne 'en'){throw 'Russian switch or unsaved language isolation failed'}
    $close=$form.Controls | Where-Object {$_ -is [Windows.Forms.Button] -and $_.Text -eq 'Закрыть'}
    $close.PerformClick()
    if($form.Visible){throw 'Close did not close settings'}
    Write-Output 'PASS: settings UI rendered and Apply saved FPS in isolated copy; real settings and autostart unchanged.'
} finally {$form.Dispose()}
