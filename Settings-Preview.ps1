function Start-TrofeoSettingsPreview($Form,$Picture,$Info,[scriptblock]$Collect,$Data,[string]$Root) {
    $folder=Join-Path $Root ('logs\settings-preview-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $renderer=Join-Path $Root 'artifacts\v0.2.0\TrofeoPreviewRenderer.exe'
    $ctx=@{Folder=$folder;Root=$Root;Picture=$Picture;Info=$Info;Json='';DraftError='';Stamp='';Worker=$null;Timer=(New-Object Windows.Forms.Timer)}
    $draft={
        if($Form.Tag -and $Form.Tag.Loading){return}
        try {
            & $Collect
            $json=$Data | ConvertTo-Json
            if($json -ne $ctx.Json){
                $file=Join-Path $ctx.Folder 'draft.json'
                [IO.File]::WriteAllText($file,$json,(New-Object Text.UTF8Encoding($false)))
                $ctx.Json=$json
            }
            $ctx.DraftError=''
        } catch { $ctx.DraftError=$_.Exception.Message }
    }.GetNewClosure()
    & $draft
    $ctx.Worker=Start-Process -FilePath $renderer -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $folder 'worker-error.txt') -RedirectStandardOutput (Join-Path $folder 'worker-output.txt') -ArgumentList @('--settings-preview-worker',('"'+$folder+'"'),('"'+(Join-Path $Root 'logs\monitor-status.json')+'"'),"$PID")
    $refresh={
        & $draft
        try {
            [IO.File]::WriteAllText((Join-Path $ctx.Root 'logs\preview-request'),'open')
            $record=Get-Content -LiteralPath (Join-Path $ctx.Root 'logs\monitor-status.json') -Raw -ErrorAction Stop | ConvertFrom-Json
            $ids=@(Get-Process WindowsSystemMonitorTrofeo -ErrorAction SilentlyContinue | Where-Object {$_.SessionId -eq (Get-Process -Id $PID).SessionId} | ForEach-Object {$_.Id})
. (Join-Path $ctx.Root 'Tray-State.ps1')
            $state=Resolve-TrayState $record $ids $false $false ([DateTime]::UtcNow)
            $label=@{running=(Get-TrofeoText 'Подключён, кадры передаются' $Data.Language);waiting=(Get-TrofeoText 'Ожидание подключения USB' $Data.Language);stopped=(Get-TrofeoText 'Остановлен' $Data.Language);error=(Get-TrofeoText 'Ошибка' $Data.Language)}[$state]
            $uptime=[TimeSpan]::FromSeconds([double]$record.uptimeSeconds)
            $rate=if($state -eq 'running'){([double]$record.fps).ToString('F1',[Globalization.CultureInfo]::GetCultureInfo($(if($Data.Language -eq 'en'){'en-US'}else{'ru-RU'})))}else{'—'}
            $last=if($record.lastError){$when=([DateTime]$record.lastErrorUtc).ToLocalTime().ToString('dd.MM.yyyy HH:mm:ss');"$($record.lastError) [$when]"}else{(Get-TrofeoText 'нет' $Data.Language)}
            $frame=if($record.previewUtc){([DateTime]$record.previewUtc).ToLocalTime().ToString('HH:mm:ss')}else{(Get-TrofeoText 'ещё нет' $Data.Language)}
            $ctx.Info.Text=@(((Get-TrofeoText 'Состояние: {0}   |   Время работы: {1}' $Data.Language) -f $label,$uptime),((Get-TrofeoText 'FPS: {0}   |   Кадров: {1}   |   Переподключений: {2}   |   Последний кадр: {3}' $Data.Language) -f $rate,$record.frames,$record.reconnects,$frame),((Get-TrofeoText 'Последняя ошибка: {0}' $Data.Language) -f $last),(Get-TrofeoText 'Предпросмотр показывает черновик. На Trofeo изменения попадут после «Применить».' $Data.Language)) -join [Environment]::NewLine
            if($state -ne 'running'){$ctx.Info.AppendText([Environment]::NewLine+(Get-TrofeoText 'Показания недоступны, пока монитор не передаёт данные.' $Data.Language))}
        } catch {$ctx.Info.Text=(Get-TrofeoText 'Монитор остановлен или ещё нет данных подключения. Предпросмотр оформления доступен без USB.' $Data.Language)}
        if($ctx.DraftError){$ctx.Info.AppendText([Environment]::NewLine+(Get-TrofeoText 'Изменения не показаны: ' $Data.Language)+$ctx.DraftError)}
        if($ctx.Worker.HasExited){$ctx.Info.AppendText([Environment]::NewLine+(Get-TrofeoText 'Не удалось запустить предпросмотр. Закройте и откройте настройки.' $Data.Language))}
        try {
            $file=Join-Path $ctx.Folder 'preview.jpg'
            $stamp=(Get-Item -LiteralPath $file -ErrorAction Stop).LastWriteTimeUtc.Ticks
            if($stamp -ne $ctx.Stamp){
                $stream=New-Object IO.MemoryStream(,[IO.File]::ReadAllBytes($file))
                $source=$null
                try{$source=[Drawing.Image]::FromStream($stream);$bmp=New-Object Drawing.Bitmap($source);$old=$ctx.Picture.Image;$ctx.Picture.Image=$bmp;if($old){$old.Dispose()};$ctx.Stamp=$stamp;$ctx.Picture.Tag=$stamp}
                finally{if($source){$source.Dispose()};$stream.Dispose()}
            }
            if($ctx.Worker.HasExited){$ctx.Info.AppendText([Environment]::NewLine+(Get-TrofeoText 'Предпросмотр завершился. Закройте и откройте настройки.' $Data.Language))}
            $errorFile=Join-Path $ctx.Folder 'error.txt'
            if(Test-Path $errorFile){$errorText=[IO.File]::ReadAllText($errorFile);if($errorText){$ctx.Info.AppendText([Environment]::NewLine+(Get-TrofeoText 'Предпросмотр: ' $Data.Language)+$errorText)}}
        } catch { }
    }.GetNewClosure()
    function Watch-TrofeoDraft($control,[scriptblock]$action){
        if($control -is [Windows.Forms.ComboBox]){$control.add_SelectedIndexChanged($action)}
        elseif($control -is [Windows.Forms.CheckBox]){$control.add_CheckedChanged($action)}
        elseif($control -is [Windows.Forms.NumericUpDown]){$control.add_ValueChanged($action)}
        elseif($control.Name -eq 'AccentColor'){$control.add_Click($action)}
        foreach($child in $control.Controls){Watch-TrofeoDraft $child $action}
    }
    Watch-TrofeoDraft $Form $draft
    $ctx.Timer.Interval=500;$ctx.Timer.add_Tick($refresh);$ctx.Timer.Start()
    $Form.add_FormClosed({
        $ctx.Timer.Stop();$ctx.Timer.Dispose()
        [IO.File]::WriteAllText((Join-Path $ctx.Folder 'stop'),'stop')
        if($ctx.Picture.Image){$ctx.Picture.Image.Dispose();$ctx.Picture.Image=$null}
        if($ctx.Worker){$ctx.Worker.Dispose()}
    }.GetNewClosure())
    return $ctx
}
