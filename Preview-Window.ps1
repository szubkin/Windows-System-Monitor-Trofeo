function New-TrofeoPreview {
    $form=New-Object Windows.Forms.Form
    $form.Text='Trofeo — предпросмотр и подключение'
    $form.ClientSize=New-Object Drawing.Size(1000,430)
    $form.MinimumSize=New-Object Drawing.Size(720,390)
    $form.StartPosition='CenterScreen'
    $form.Icon=New-Object Drawing.Icon((Join-Path $PSScriptRoot 'assets\trofeo-app.ico'))
    $picture=New-Object Windows.Forms.PictureBox
    $picture.Dock='Fill';$picture.SizeMode='Zoom';$picture.BackColor=[Drawing.Color]::FromArgb(9,15,23)
    $info=New-Object Windows.Forms.TextBox
    $info.Dock='Bottom';$info.Height=170;$info.Multiline=$true;$info.ReadOnly=$true
    $info.Font=New-Object Drawing.Font('Segoe UI',10);$info.ScrollBars='Vertical'
    $form.Controls.Add($picture);$form.Controls.Add($info)
    $timer=New-Object Windows.Forms.Timer;$timer.Interval=1000
    $ctx=@{Stamp='';Pid=0;Picture=$picture;Info=$info;Timer=$timer;Root=$PSScriptRoot}
    $update={
        try {
            $folder=Join-Path $ctx.Root 'logs'
            New-Item -ItemType Directory -Force -Path $folder | Out-Null
            [IO.File]::WriteAllText((Join-Path $folder 'preview-request'),'open')
            $record=Get-Content -LiteralPath (Join-Path $folder 'monitor-status.json') -Raw -ErrorAction Stop | ConvertFrom-Json
            $ids=@(Get-Process WindowsSystemMonitorTrofeo -ErrorAction SilentlyContinue | Where-Object {$_.SessionId -eq (Get-Process -Id $PID).SessionId} | ForEach-Object {$_.Id})
            if($ctx.Pid -ne $record.pid) {
                $ctx.Pid=$record.pid;$ctx.Stamp=''
                if($ctx.Picture.Image){$ctx.Picture.Image.Dispose();$ctx.Picture.Image=$null}
            }
            $state=Resolve-TrayState $record $ids $false $false ([DateTime]::UtcNow)
            $label=@{running='Подключён, кадры передаются';waiting='Ожидание подключения';stopped='Остановлен';error='Ошибка'}[$state]
            $uptime=[TimeSpan]::FromSeconds([double]$record.uptimeSeconds)
            $rate=if($state -eq 'running'){'{0:F1}' -f [double]$record.fps}else{'—'}
            $errorTime=if($record.lastErrorUtc){([DateTime]$record.lastErrorUtc).ToLocalTime().ToString('dd.MM.yyyy HH:mm:ss')}else{'—'}
            $frameTime=if($record.previewUtc){([DateTime]$record.previewUtc).ToLocalTime().ToString('dd.MM.yyyy HH:mm:ss')}else{'ещё нет'}
            $last=if($record.lastError){"$($record.lastError) [$errorTime]"}else{'нет'}
            $ctx.Info.Text="Состояние: $label`r`nВремя работы процесса: $($uptime.ToString('d\.hh\:mm\:ss'))   FPS: $rate   Кадров: $($record.frames)   Переподключений: $($record.reconnects)`r`nПоследняя ошибка: $last`r`nПоследний кадр: $frameTime. Обновление предпросмотра раз в секунду."
            if($record.previewUtc -and $ctx.Stamp -ne [string]$record.previewUtc -and $record.previewFile -match '^monitor-preview-\d+\.jpg$') {
                $bytes=[IO.File]::ReadAllBytes((Join-Path $folder $record.previewFile))
                $stream=New-Object IO.MemoryStream(,$bytes)
                $source=$null
                try {
                    $source=[Drawing.Image]::FromStream($stream)
                    $bmp=New-Object Drawing.Bitmap($source)
                    if($record.rotation -eq 180){$bmp.RotateFlip([Drawing.RotateFlipType]::Rotate180FlipNone)}
                    $old=$ctx.Picture.Image;$ctx.Picture.Image=$bmp;if($old){$old.Dispose()}
                    $ctx.Stamp=[string]$record.previewUtc
                } finally {if($source){$source.Dispose()};$stream.Dispose()}
            }
        } catch { $ctx.Info.Text='Нет свежих данных монитора. Запустите монитор из меню трея.' }
    }.GetNewClosure()
    $timer.add_Tick($update)
    $form.add_Shown({& $update;$ctx.Timer.Start()}.GetNewClosure())
    $form.add_FormClosed({
        $ctx.Timer.Stop();$ctx.Timer.Dispose()
        if($ctx.Picture.Image){$ctx.Picture.Image.Dispose();$ctx.Picture.Image=$null}
    }.GetNewClosure())
    return $form
}
