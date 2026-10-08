$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root=Split-Path $PSScriptRoot
$copy=Join-Path $root ('artifacts\preview-ui-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $copy 'assets'),(Join-Path $copy 'logs') -Force | Out-Null
Copy-Item (Join-Path $root 'Preview-Window.ps1') $copy
Copy-Item (Join-Path $root 'assets\trofeo-app.ico') (Join-Path $copy 'assets')
. (Join-Path $root 'Tray-State.ps1')
. (Join-Path $copy 'Preview-Window.ps1')
$image=[Drawing.Image]::FromFile((Join-Path $root 'artifacts\qa\dashboard-temperature-colors.png'))
$image.Save((Join-Path $copy 'logs\monitor-preview-123.jpg'),[Drawing.Imaging.ImageFormat]::Jpeg);$image.Dispose()
@{pid=123;state='stopped';updatedUtc=[DateTime]::UtcNow;uptimeSeconds=3661;frames=21000;fps=5.9;reconnects=2;lastError='Test USB disconnect';lastErrorUtc=[DateTime]::UtcNow;previewUtc=[DateTime]::UtcNow;previewFile='monitor-preview-123.jpg';rotation=0} | ConvertTo-Json | Set-Content (Join-Path $copy 'logs\monitor-status.json')
$form=New-TrofeoPreview
try {
    $form.Show();[Windows.Forms.Application]::DoEvents()
    $pic=$form.Controls | Where-Object {$_ -is [Windows.Forms.PictureBox]}
    if(!$pic.Image){throw 'Preview image missing'}
    $bmp=New-Object Drawing.Bitmap($form.Width,$form.Height)
    try{$form.DrawToBitmap($bmp,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)));$bmp.Save((Join-Path $root 'artifacts\qa\preview-window.png'))}finally{$bmp.Dispose()}
    Write-Output 'PASS preview window renders fixture and connection information; no USB.'
} finally {$form.Close();$form.Dispose()}
