$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root=Split-Path $PSScriptRoot;$copy=Join-Path $root 'artifacts\setup-check-020'
. (Join-Path $copy 'Settings-Core.ps1')
. (Join-Path $copy 'Settings-Tools.ps1')
$form=New-Object Windows.Forms.Form;$form.ClientSize=New-Object Drawing.Size(300,180)
$panel=New-Object Windows.Forms.Panel;$panel.Dock='Fill';$form.Controls.Add($panel)
$viewer=@{Path=''}
Add-TrofeoSettingsTools $form $panel (New-TrofeoDefaults) $copy -ReportViewer {param($file)$viewer.Path=$file}.GetNewClosure()
function Pump([scriptblock]$Condition){
    $deadline=[DateTime]::UtcNow.AddSeconds(20)
    while([DateTime]::UtcNow -lt $deadline){[Windows.Forms.Application]::DoEvents();if(& $Condition){return};Start-Sleep -Milliseconds 50}
    throw 'Tool did not finish within deadline'
}
try{
    $form.Show();$diag=$panel.Controls | Where-Object {$_.Name -eq 'Diagnostics'}
    $diag.PerformClick();Pump {$diag.Enabled}
    if(!$viewer.Path -or !(Test-Path $viewer.Path) -or !(Get-Content $viewer.Path -Raw).Contains('WINUSB')){throw 'Diagnostic report missing USB discovery'}
    Write-Host 'PASS diagnostics button creates compact report and returns to ready state'
    $update=$panel.Controls | Where-Object {$_.Name -eq 'Updates'}
    $update.PerformClick();Pump {$update.Enabled}
    $label=$panel.Controls | Where-Object {$_ -is [Windows.Forms.Label]}
    Write-Host ('Update result: '+$label.Text)
    if($label.Text -notlike 'Установлена*'){throw 'Live GitHub update check failed'}
    Write-Host 'PASS manual GitHub check completes asynchronously'
}finally{$form.Close();$form.Dispose()}
