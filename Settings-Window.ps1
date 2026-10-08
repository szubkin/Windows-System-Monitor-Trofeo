function New-TrofeoSettingsForm {
    param([switch]$TestMode, [scriptblock]$OnApplied, [switch]$TestPreview)
    $path=Join-Path $PSScriptRoot 'trofeo-settings.json'
    $data=Read-TrofeoSettings $path
    $form=New-Object Windows.Forms.Form
    $form.Text='Trofeo — настройки, предпросмотр и подключение'
    $form.ClientSize=New-Object Drawing.Size(1180,920)
    $form.StartPosition='CenterScreen'
    $form.FormBorderStyle='Sizable'
    $form.MinimumSize=New-Object Drawing.Size(850,650)
    $form.MaximizeBox=$true; $form.MinimizeBox=$false
    $form.Font=New-Object Drawing.Font('Segoe UI',10)
    $form.Icon=New-Object Drawing.Icon((Join-Path $PSScriptRoot 'assets\trofeo-app.ico'))
    function Label($text,$y) {
        $label=New-Object Windows.Forms.Label
        $label.Text=$text; $label.Location=New-Object Drawing.Point(20,$y)
        $label.Size=New-Object Drawing.Size(220,26);$form.Controls.Add($label)
    }
    function Combo($y) {
        $c=New-Object Windows.Forms.ComboBox
        $c.Location=New-Object Drawing.Point(240,$y);$c.Size=New-Object Drawing.Size(260,26)
        $c.DropDownStyle='DropDownList';$c.DisplayMember='Label';$form.Controls.Add($c)
        return $c
    }
    function Numeric($y,$min,$max,$value) {
        $n=New-Object Windows.Forms.NumericUpDown
        $n.Location=New-Object Drawing.Point(240,$y);$n.Size=New-Object Drawing.Size(120,26)
        $n.Minimum=$min;$n.Maximum=$max;$n.Value=$value;$form.Controls.Add($n)
        return $n
    }
    Label 'Частота обновления, FPS' 24
    $fps=Numeric 20 1 10 $data.Fps
    Label 'Поворот экрана' 64
    $rotation=Combo 60
    foreach($item in @(@{Label='Автоматически';Value=-1},@{Label='0°';Value=0},@{Label='180°';Value=180})) {
        $index=$rotation.Items.Add([pscustomobject]$item)
        if($item.Value -eq $data.Rotation){$rotation.SelectedIndex=$index}
    }
    Label 'Сетевой адаптер' 104
    $network=Combo 100
    [void]$network.Items.Add([pscustomobject]@{Label='Все активные адаптеры';Value=''})
    foreach($adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object { $_.NetworkInterfaceType -ne 'Loopback' }) {
        [void]$network.Items.Add([pscustomobject]@{Label=$adapter.Name;Value=$adapter.Id})
    }
    $network.SelectedIndex=0
    for($i=0;$i -lt $network.Items.Count;$i++){if($network.Items[$i].Value -eq $data.NetworkId){$network.SelectedIndex=$i}}
    if($data.NetworkId -and $network.SelectedIndex -eq 0){$network.SelectedIndex=$network.Items.Add([pscustomobject]@{Label='Недоступный адаптер (сохранён)';Value=$data.NetworkId})}
    Label 'Диск' 144
    $drive=Combo 140
    [void]$drive.Items.Add([pscustomobject]@{Label='Системный диск';Value=''})
    foreach($d in [IO.DriveInfo]::GetDrives() | Where-Object {$_.DriveType -eq 'Fixed'}) {
        [void]$drive.Items.Add([pscustomobject]@{Label=$d.Name;Value=$d.Name})
    }
    $drive.SelectedIndex=0
    for($i=0;$i -lt $drive.Items.Count;$i++){if($drive.Items[$i].Value -eq $data.Drive){$drive.SelectedIndex=$i}}
    if($data.Drive -and $drive.SelectedIndex -eq 0){$drive.SelectedIndex=$drive.Items.Add([pscustomobject]@{Label=$data.Drive+' (недоступен)';Value=$data.Drive})}
    $cpu=New-Object Windows.Forms.CheckBox
    $cpu.Text='Датчики температуры и частоты CPU';$cpu.Checked=$data.CpuSensors
    $cpu.Location=New-Object Drawing.Point(20,182);$cpu.Size=New-Object Drawing.Size(470,26);$form.Controls.Add($cpu)
    $autoCheck=New-Object Windows.Forms.CheckBox
    $autoCheck.Text='Запускать при входе в Windows'
    $autoCheck.Location=New-Object Drawing.Point(20,214);$autoCheck.Size=New-Object Drawing.Size(470,26)
    $task=Get-ScheduledTask -TaskName 'Windows System Monitor Trofeo' -ErrorAction SilentlyContinue
    $autoCheck.Checked=($null -ne $task -and $task.State -ne 'Disabled')
    $applyState=@{Auto=$autoCheck.Checked};$form.Controls.Add($autoCheck)
    Label 'Хранить логи, дней' 260
    $days=Numeric 256 1 365 $data.LogDays
    Label 'Лимит старых логов, МиБ' 300
    $size=Numeric 296 20 2000 $data.LogMaxMiB
    Label 'CPU: жёлтый от, °C' 340
    $cpuYellow=Numeric 336 1 129 $data.CpuYellow
    Label 'CPU: красный от, °C' 380
    $cpuRed=Numeric 376 2 130 $data.CpuRed
    Label 'GPU: жёлтый от, °C' 420
    $gpuYellow=Numeric 416 1 129 $data.GpuYellow
    Label 'GPU: красный от, °C' 460
    $gpuRed=Numeric 456 2 130 $data.GpuRed
    $note=New-Object Windows.Forms.Label
    $note.Text='Текущий и последний запуск сохраняются. Изменения перезапустят работающий монитор.'
    $note.Location=New-Object Drawing.Point(20,498);$note.Size=New-Object Drawing.Size(480,45);$form.Controls.Add($note)
    $save=New-Object Windows.Forms.Button
    $save.Text='Применить';$save.Location=New-Object Drawing.Point(260,601);$save.Size=New-Object Drawing.Size(115,30);$form.Controls.Add($save)
    $cancel=New-Object Windows.Forms.Button
    $cancel.Text='Закрыть';$cancel.Location=New-Object Drawing.Point(385,601);$cancel.Size=New-Object Drawing.Size(115,30)
    $cancel.DialogResult='Cancel';$form.Controls.Add($cancel);$form.CancelButton=$cancel
    $cancel.add_Click({$form.Close()}.GetNewClosure())
    . (Join-Path $PSScriptRoot 'Ui-Theme.ps1')
    $body=New-Object Windows.Forms.Panel;$body.Name='AllSettings';$body.AutoScroll=$true
    $general=New-Object Windows.Forms.Panel;$general.Name='GeneralSettings';$general.Size=New-Object Drawing.Size(540,530)
    $screen=New-Object Windows.Forms.Panel;$screen.Name='ScreenSettings';$screen.Location=New-Object Drawing.Point(540,0);$screen.Size=New-Object Drawing.Size(580,530)
    foreach($control in @($form.Controls)){if($control -ne $note -and $control -ne $save -and $control -ne $cancel){$general.Controls.Add($control)}}
    $body.Controls.Add($general);$body.Controls.Add($screen);$form.Controls.Add($body)
    $save.Size=New-Object Drawing.Size(108,32);$cancel.Size=New-Object Drawing.Size(108,32)
    function ScreenLabel($text,$y,$width=220){
        $label=New-Object Windows.Forms.Label;$label.Text=$text
        $label.Location=New-Object Drawing.Point(20,$y);$label.Size=New-Object Drawing.Size($width,26);$screen.Controls.Add($label)
    }
    ScreenLabel 'Показывать блоки (минимум один)' 18 550
    $blockChecks=@{}
    $blockNames=@{CPU='CPU';GPU='GPU';MEMORY='Память';NETWORK='Сеть';DISK='Диск'}
    $blockIndex=0
    foreach($key in @('CPU','GPU','MEMORY','NETWORK','DISK')){
        $check=New-Object Windows.Forms.CheckBox;$check.Text=$blockNames[$key];$check.Name='Block'+$key
        $check.Location=New-Object Drawing.Point((20+$blockIndex*112),52);$check.Size=New-Object Drawing.Size(110,28)
        $check.Checked=$key -in $data.DisplayBlocks.Split(',');$screen.Controls.Add($check);$blockChecks[$key]=$check;$blockIndex++
    }
    ScreenLabel 'Размер текста' 98
    $textSize=New-Object Windows.Forms.ComboBox;$textSize.Name='TextPercent'
    $textSize.Location=New-Object Drawing.Point(260,94);$textSize.Size=New-Object Drawing.Size(310,26)
    $textSize.DropDownStyle='DropDownList';$textSize.DisplayMember='Label'
    foreach($percent in @(90,100,110)){[void]$textSize.Items.Add([pscustomobject]@{Label=("$percent %");Value=$percent})}
    if($data.TextPercent -notin @(90,100,110)){[void]$textSize.Items.Add([pscustomobject]@{Label=("$($data.TextPercent) %");Value=$data.TextPercent})}
    $screen.Controls.Add($textSize)
    ScreenLabel 'Цвет акцента' 146
    $colorButton=New-Object Windows.Forms.Button;$colorButton.Name='AccentColor';$colorButton.Text='';$colorButton.Tag=$data.AccentColor;$colorButton.AccessibleName='Выбрать цвет акцента'
    $colorButton.Location=New-Object Drawing.Point(260,140);$colorButton.Size=New-Object Drawing.Size(310,30);$screen.Controls.Add($colorButton)
    $colorButton.add_Paint({
        param($sender,$event)
        $brush=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml([string]$sender.Tag))
        try{$event.Graphics.FillRectangle($brush,6,6,($sender.ClientSize.Width-12),($sender.ClientSize.Height-12))}finally{$brush.Dispose()}
    }.GetNewClosure())
    $colorButton.add_Click({
        $dialog=New-Object Windows.Forms.ColorDialog;$dialog.FullOpen=$true;$dialog.Color=[Drawing.ColorTranslator]::FromHtml([string]$colorButton.Tag)
        try{if($dialog.ShowDialog() -eq 'OK'){$hex='#{0:X2}{1:X2}{2:X2}' -f $dialog.Color.R,$dialog.Color.G,$dialog.Color.B;$colorButton.Tag=$hex;$colorButton.Invalidate()}}finally{$dialog.Dispose()}
    }.GetNewClosure())
    function MetricCombo($name,$y,$items){
        $combo=New-Object Windows.Forms.ComboBox;$combo.Name=$name;$combo.DisplayMember='Label';$combo.DropDownStyle='DropDownList'
        $combo.Location=New-Object Drawing.Point(260,$y);$combo.Size=New-Object Drawing.Size(310,26)
        foreach($item in $items){[void]$combo.Items.Add([pscustomobject]$item)}
        $screen.Controls.Add($combo);return $combo
    }
    ScreenLabel 'Главный показатель CPU' 194
    $cpuMetric=MetricCombo 'CpuMetric' 190 @(@{Label='Загрузка, %';Value='load'},@{Label='Температура, °C';Value='temperature'},@{Label='Частота, ГГц';Value='clock'})
    ScreenLabel 'Главный показатель GPU' 242
    $gpuMetric=MetricCombo 'GpuMetric' 238 @(@{Label='Загрузка, %';Value='load'},@{Label='Температура, °C';Value='temperature'},@{Label='Видеопамять, ГиБ';Value='vram'})
    $graphs=New-Object Windows.Forms.CheckBox;$graphs.Name='ShowGraphs';$graphs.Text='Показывать графики загрузки и сети'
    $graphs.Location=New-Object Drawing.Point(20,288);$graphs.Size=New-Object Drawing.Size(550,28);$graphs.Checked=$data.ShowGraphs;$screen.Controls.Add($graphs)
    $names=New-Object Windows.Forms.CheckBox;$names.Name='ShowDeviceNames';$names.Text='Показывать подписи оборудования и адаптера'
    $names.Location=New-Object Drawing.Point(20,328);$names.Size=New-Object Drawing.Size(550,28);$names.Checked=$data.ShowDeviceNames;$screen.Controls.Add($names)
    ScreenLabel 'Скрытые блоки освобождают место: видимые имеют равную ширину.' 386 550
    $hint=New-Object Windows.Forms.Label;$hint.Text='Температура и частота CPU требуют включённых датчиков CPU. Если показание недоступно, отображается «—». Цветовые пороги температуры сохраняются.'
    $hint.Location=New-Object Drawing.Point(20,430);$hint.Size=New-Object Drawing.Size(550,78);$screen.Controls.Add($hint)
    foreach($pair in @(@{Control=$textSize;Value=$data.TextPercent},@{Control=$cpuMetric;Value=$data.CpuMetric},@{Control=$gpuMetric;Value=$data.GpuMetric})){
        for($i=0;$i -lt $pair.Control.Items.Count;$i++){if($pair.Control.Items[$i].Value -eq $pair.Value){$pair.Control.SelectedIndex=$i}}
    }
    $collect={
            $data.Fps=[int]$fps.Value;$data.Rotation=[int]$rotation.SelectedItem.Value
            $data.NetworkId=[string]$network.SelectedItem.Value;$data.Drive=[string]$drive.SelectedItem.Value
            $data.CpuSensors=$cpu.Checked;$data.LogDays=[int]$days.Value;$data.LogMaxMiB=[int]$size.Value
            $data.CpuYellow=[int]$cpuYellow.Value;$data.CpuRed=[int]$cpuRed.Value
            $data.GpuYellow=[int]$gpuYellow.Value;$data.GpuRed=[int]$gpuRed.Value
            if($data.CpuYellow -ge $data.CpuRed -or $data.GpuYellow -ge $data.GpuRed){throw 'Красный порог должен быть выше жёлтого.'}
            $data.DisplayBlocks=(@('CPU','GPU','MEMORY','NETWORK','DISK') | Where-Object {$blockChecks[$_].Checked}) -join ','
            if(!$data.DisplayBlocks){throw 'Выберите хотя бы один блок экрана.'}
            $data.TextPercent=[int]$textSize.SelectedItem.Value;$data.AccentColor=[string]$colorButton.Tag
            $data.CpuMetric=[string]$cpuMetric.SelectedItem.Value;$data.GpuMetric=[string]$gpuMetric.SelectedItem.Value
            $data.ShowGraphs=$graphs.Checked;$data.ShowDeviceNames=$names.Checked
            Assert-TrofeoSettings $data

    }.GetNewClosure()
    $load={
        param($incoming)
        Assert-TrofeoSettings $incoming
        foreach($property in (New-TrofeoDefaults).PSObject.Properties) { $data.($property.Name)=$incoming.($property.Name) }
        $fps.Value=$data.Fps;$cpu.Checked=$data.CpuSensors;$days.Value=$data.LogDays;$size.Value=$data.LogMaxMiB
        $cpuYellow.Value=$data.CpuYellow;$cpuRed.Value=$data.CpuRed;$gpuYellow.Value=$data.GpuYellow;$gpuRed.Value=$data.GpuRed
        foreach($pair in @(@{Control=$rotation;Value=$data.Rotation},@{Control=$network;Value=$data.NetworkId},@{Control=$drive;Value=$data.Drive})) {
            $found=-1
            for($i=0;$i -lt $pair.Control.Items.Count;$i++){if($pair.Control.Items[$i].Value -eq $pair.Value){$found=$i;break}}
            if($found -lt 0){$found=$pair.Control.Items.Add([pscustomobject]@{Label=([string]$pair.Value+' (недоступен)');Value=$pair.Value})}
            $pair.Control.SelectedIndex=$found
        }
        foreach($key in $blockChecks.Keys){$blockChecks[$key].Checked=$key -in $data.DisplayBlocks.Split(',')}
        $colorButton.Tag=$data.AccentColor;$colorButton.Invalidate();$graphs.Checked=$data.ShowGraphs;$names.Checked=$data.ShowDeviceNames
        if($data.TextPercent -notin @($textSize.Items | ForEach-Object {$_.Value})){[void]$textSize.Items.Add([pscustomobject]@{Label=("$($data.TextPercent) %");Value=$data.TextPercent})}
        foreach($pair in @(@{Control=$textSize;Value=$data.TextPercent},@{Control=$cpuMetric;Value=$data.CpuMetric},@{Control=$gpuMetric;Value=$data.GpuMetric})){
            for($i=0;$i -lt $pair.Control.Items.Count;$i++){if($pair.Control.Items[$i].Value -eq $pair.Value){$pair.Control.SelectedIndex=$i}}
        }
        $note.Text='Значения загружены. Нажмите «Применить», чтобы сохранить. Автозапуск не изменён.'
    }.GetNewClosure()
    $export=New-Object Windows.Forms.Button
    $export.Text='Экспорт...';$export.Location=New-Object Drawing.Point(20,674);$export.Size=New-Object Drawing.Size(108,32);$form.Controls.Add($export)
    $import=New-Object Windows.Forms.Button
    $import.Text='Импорт...';$import.Location=New-Object Drawing.Point(138,674);$import.Size=New-Object Drawing.Size(108,32);$form.Controls.Add($import)
    $reset=New-Object Windows.Forms.Button
    $reset.Text='По умолчанию';$reset.Location=New-Object Drawing.Point(256,674);$reset.Size=New-Object Drawing.Size(108,32);$form.Controls.Add($reset)
    $reset.add_Click({& $load (New-TrofeoDefaults)}.GetNewClosure())
    $import.add_Click({
        $dialog=New-Object Windows.Forms.OpenFileDialog
        $dialog.Filter='Настройки JSON (*.json)|*.json';$dialog.CheckFileExists=$true
        try {
            if($dialog.ShowDialog() -eq 'OK') { & $load (Import-TrofeoSettings $dialog.FileName) }
        } catch {if($TestMode){throw};[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Не удалось импортировать')}
        finally {$dialog.Dispose()}
    }.GetNewClosure())
    $export.add_Click({
        $dialog=New-Object Windows.Forms.SaveFileDialog
        $dialog.Filter='Настройки JSON (*.json)|*.json';$dialog.DefaultExt='json';$dialog.FileName='Trofeo-settings.json';$dialog.OverwritePrompt=$true
        try {
            & $collect
            if($dialog.ShowDialog() -eq 'OK') {
                if([IO.Path]::GetFullPath($dialog.FileName) -eq [IO.Path]::GetFullPath($path)){throw 'Выберите отдельный файл для экспорта.'}
                Save-TrofeoSettings $data $dialog.FileName
                $note.Text='Настройки экспортированы. Автозапуск Windows в файл не включён.'
            }
        } catch {if($TestMode){throw};[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Не удалось экспортировать')}
        finally {$dialog.Dispose()}
    }.GetNewClosure())
    $save.add_Click({
        try {
            & $collect
            $old=[IO.File]::ReadAllText($path)
            Save-TrofeoSettings $data $path
            try {
                if($autoCheck.Checked -ne $applyState.Auto){if($autoCheck.Checked){Set-Autostart 'Enable'}else{Set-Autostart 'Disable'}}
            } catch {
                [IO.File]::WriteAllText($path,$old)
                throw
            }
            $applyState.Auto=$autoCheck.Checked
            $note.Text='Настройки сохранены. Окно можно оставить открытым или нажать «Закрыть».'
            if($OnApplied){& $OnApplied}
        } catch { if($TestMode){throw}; [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Не удалось сохранить настройки') }
    }.GetNewClosure())
. (Join-Path $PSScriptRoot 'Ui-Theme.ps1')
    $picture=New-Object Windows.Forms.PictureBox;$picture.Name='SettingsPreview';$picture.SizeMode='Zoom'
    $picture.Location=New-Object Drawing.Point(650,62);$picture.Size=New-Object Drawing.Size(510,230);$picture.BackColor=[Drawing.Color]::FromArgb(9,15,23);$form.Controls.Add($picture)
    $connectionInfo=New-Object Windows.Forms.TextBox;$connectionInfo.Name='ConnectionStatus';$connectionInfo.Multiline=$true;$connectionInfo.ReadOnly=$true;$connectionInfo.ScrollBars='None'
    $connectionInfo.Location=New-Object Drawing.Point(650,314);$connectionInfo.Size=New-Object Drawing.Size(510,350);$connectionInfo.Text='Состояние подключения появится после запуска монитора.';$form.Controls.Add($connectionInfo)
    [TrofeoUi.DarkTheme]::Apply($form)
    $connectionInfo.ForeColor=[Drawing.Color]::FromArgb(190,198,206)
    $picture.BackColor=[Drawing.Color]::FromArgb(9,15,23)
    if(!$TestMode -or $TestPreview){
        . (Join-Path $PSScriptRoot 'Settings-Preview.ps1')
        . (Join-Path $PSScriptRoot 'Tray-State.ps1')
        $previewRoot=$PSScriptRoot
        $form.add_Shown({
            . (Join-Path $previewRoot 'Settings-Preview.ps1')
            try{[void](Start-TrofeoSettingsPreview $form $picture $connectionInfo $collect $data $previewRoot)}
            catch{$connectionInfo.Text='Не удалось открыть предпросмотр: '+$_.Exception.Message}
        }.GetNewClosure())
    }
    $layout={
        $unit=$save.Width/108.0
        $margin=[int](20*$unit);$spacing=[int](16*$unit)
        $width=$form.ClientSize.Width-2*$margin

        $buttonY=$form.ClientSize.Height-[int](48*$unit)
        $note.Location=New-Object Drawing.Point($margin,($buttonY-[int](28*$unit)));$note.Size=New-Object Drawing.Size($width,([int](24*$unit)))
        $connectionInfo.Location=New-Object Drawing.Point($margin,($note.Top-[int](142*$unit)));$connectionInfo.Size=New-Object Drawing.Size($width,([int](132*$unit)))
        $maxHeight=[Math]::Max(60,($connectionInfo.Top-$margin-2*$spacing-[int](80*$unit)))
        $previewWidth=[int][Math]::Min($width,($maxHeight*1920.0/462))
        $picture.Location=New-Object Drawing.Point(($margin+[int](($width-$previewWidth)/2)),$margin)
        $picture.Size=New-Object Drawing.Size($previewWidth,([int][Math]::Round($previewWidth*462.0/1920)))
        $body.Location=New-Object Drawing.Point($margin,($picture.Bottom+$spacing))
        $body.Size=New-Object Drawing.Size($width,([Math]::Max(60,($connectionInfo.Top-$spacing-$body.Top))))
        $export.Location=New-Object Drawing.Point($margin,$buttonY)
        $import.Location=New-Object Drawing.Point(($export.Right+[int](10*$unit)),$buttonY)
        $reset.Location=New-Object Drawing.Point(($import.Right+[int](10*$unit)),$buttonY)
        $cancel.Location=New-Object Drawing.Point(($form.ClientSize.Width-$margin-$cancel.Width),$buttonY)
        $save.Location=New-Object Drawing.Point(($cancel.Left-[int](10*$unit)-$save.Width),$buttonY)
    }.GetNewClosure()
    & $layout
    $form.add_Resize($layout)
    $form.add_Shown({
        $area=[Windows.Forms.Screen]::FromControl($form).WorkingArea
        if($form.Width -gt $area.Width -or $form.Height -gt $area.Height){
            $form.Size=New-Object Drawing.Size(([Math]::Min($form.Width,$area.Width-20)),([Math]::Min($form.Height,$area.Height-30)))
            $form.Location=New-Object Drawing.Point(($area.X+[int](($area.Width-$form.Width)/2)),($area.Y+[int](($area.Height-$form.Height)/2)))
        }
        & $layout
    }.GetNewClosure())
    return $form
}
