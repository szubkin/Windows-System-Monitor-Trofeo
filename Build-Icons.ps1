$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$out=Join-Path $PSScriptRoot 'assets'
function Save-Ico($path,$render) {
    $sizes=@(16,20,24,32,48,64,128,256)
    $images=@()
    foreach($size in $sizes) {
        $bmp=& $render $size
        $stream=New-Object IO.MemoryStream
        $bmp.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
        $images+=,@{Size=$size;Bytes=$stream.ToArray()}
        $stream.Dispose(); $bmp.Dispose()
    }
    $file=[IO.File]::Create($path); $w=New-Object IO.BinaryWriter($file)
    try {
        $w.Write([uint16]0);$w.Write([uint16]1);$w.Write([uint16]$sizes.Count)
        $offset=6+16*$sizes.Count
        foreach($entry in $images) {
            $side=if($entry.Size -eq 256){0}else{$entry.Size}
            $w.Write([byte]$side);$w.Write([byte]$side);$w.Write([byte]0);$w.Write([byte]0)
            $w.Write([uint16]1);$w.Write([uint16]32);$w.Write([uint32]$entry.Bytes.Length);$w.Write([uint32]$offset)
            $offset+=$entry.Bytes.Length
        }
        foreach($entry in $images){$w.Write([byte[]]$entry.Bytes)}
    } finally {$w.Dispose()}
}
$source=[Drawing.Image]::FromFile((Join-Path $out 'trofeo-icon-opaque-center.png'))
try {
    Save-Ico (Join-Path $out 'trofeo-app.ico') {
        param($size)
        $bmp=New-Object Drawing.Bitmap($size,$size)
        $g=[Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($source,0,0,$size,$size);$g.Dispose()
        return $bmp
    }
} finally {$source.Dispose()}
$colors=@{running='#44E2C6';waiting='#F5C542';stopped='#929AA5';error='#F05A64'}
foreach($state in $colors.Keys) {
    $color=[Drawing.ColorTranslator]::FromHtml($colors[$state])
    Save-Ico (Join-Path $out ("tray-$state.ico")) {
        param($size)
        $bmp=New-Object Drawing.Bitmap($size,$size)
        $g=[Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.ScaleTransform($size/32.0,$size/32.0)
        $path=New-Object Drawing.Drawing2D.GraphicsPath
        $path.AddArc(1,1,8,8,180,90);$path.AddArc(23,1,8,8,270,90)
        $path.AddArc(23,23,8,8,0,90);$path.AddArc(1,23,8,8,90,90);$path.CloseFigure()
        $brush=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#090F17'))
        $g.FillPath($brush,$path)
        $pen=New-Object Drawing.Pen($color,3.3)
        $pen.StartCap=$pen.EndCap=[Drawing.Drawing2D.LineCap]::Round
        $pen.LineJoin=[Drawing.Drawing2D.LineJoin]::Round
        $points=[Drawing.PointF[]]@((New-Object Drawing.PointF(5,16)),(New-Object Drawing.PointF(11,16)),(New-Object Drawing.PointF(14,8)),(New-Object Drawing.PointF(19,24)),(New-Object Drawing.PointF(22,16)),(New-Object Drawing.PointF(27,16)))
        $g.DrawLines($pen,$points)
        $pen.Dispose();$brush.Dispose();$path.Dispose();$g.Dispose()
        return $bmp
    }
}
Write-Output 'Created application icon and four tray icons, 16–256px.'
