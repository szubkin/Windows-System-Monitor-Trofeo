$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root=Split-Path $PSScriptRoot
. (Join-Path $root 'Ui-Theme.ps1')
$form=New-Object Windows.Forms.Form;$form.Show()
$menu=New-Object Windows.Forms.ContextMenuStrip
[TrofeoUi.DarkTheme]::Menu($menu)
$item=$menu.Items.Add('v0.0.19 — Работает');$item.Enabled=$false
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
foreach($label in @('Запустить','Остановить','Перезапустить','Автозапуск при входе','Предпросмотр и статус...','Настройки...','Открыть логи','Выход')){[void]$menu.Items.Add($label)}
$menu.Items[5].Checked=$true
try{
    $menu.Show($form,(New-Object Drawing.Point(10,10)));[Windows.Forms.Application]::DoEvents()
    $bmp=New-Object Drawing.Bitmap($menu.Width,$menu.Height)
    try{$menu.DrawToBitmap($bmp,(New-Object Drawing.Rectangle(0,0,$menu.Width,$menu.Height)));$bmp.Save((Join-Path $root 'artifacts\qa\dark-tray-menu.png'))}finally{$bmp.Dispose()}
    Write-Output 'Dark tray menu rendered.'
}finally{$menu.Close();$menu.Dispose();$form.Close();$form.Dispose()}
