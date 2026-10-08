function New-TrofeoSettingsForm {
    param([switch]$TestMode, [scriptblock]$OnApplied, [switch]$TestPreview)
    $path=Join-Path $PSScriptRoot 'trofeo-settings.json'
    $data=Read-TrofeoSettings $path
    $editState=@{Loading=$false;ApplyingProfile=$false}
    $form=New-Object Windows.Forms.Form
    $form.Tag=$editState
    $form.Text=(Get-TrofeoText 'Trofeo — настройки, предпросмотр и подключение' $data.Language)
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
    Label (Get-TrofeoText 'Частота обновления, FPS' $data.Language) 24
    $fps=Numeric 20 1 10 $data.Fps
    Label (Get-TrofeoText 'Поворот экрана' $data.Language) 64
    $rotation=Combo 60
    foreach($item in @(@{Label=(Get-TrofeoText 'Автоматически' $data.Language);Value=-1},@{Label='0°';Value=0},@{Label='180°';Value=180})) {
        $index=$rotation.Items.Add([pscustomobject]$item)
        if($item.Value -eq $data.Rotation){$rotation.SelectedIndex=$index}
    }
    Label (Get-TrofeoText 'Сетевой адаптер' $data.Language) 104
    $network=Combo 100
    [void]$network.Items.Add([pscustomobject]@{Label=(Get-TrofeoText 'Все активные адаптеры' $data.Language);Value=''})
    foreach($adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object { $_.NetworkInterfaceType -ne 'Loopback' }) {
        [void]$network.Items.Add([pscustomobject]@{Label=$adapter.Name;Value=$adapter.Id})
    }
    $network.SelectedIndex=0
    for($i=0;$i -lt $network.Items.Count;$i++){if($network.Items[$i].Value -eq $data.NetworkId){$network.SelectedIndex=$i}}
    if($data.NetworkId -and $network.SelectedIndex -eq 0){$network.SelectedIndex=$network.Items.Add([pscustomobject]@{Label=(Get-TrofeoText 'Недоступный адаптер (сохранён)' $data.Language);Value=$data.NetworkId})}
    Label (Get-TrofeoText 'Диск' $data.Language) 144
    $drive=Combo 140
    [void]$drive.Items.Add([pscustomobject]@{Label=(Get-TrofeoText 'Системный диск' $data.Language);Value=''})
    foreach($d in [IO.DriveInfo]::GetDrives() | Where-Object {$_.DriveType -eq 'Fixed'}) {
        [void]$drive.Items.Add([pscustomobject]@{Label=$d.Name;Value=$d.Name})
    }
    $drive.SelectedIndex=0
    for($i=0;$i -lt $drive.Items.Count;$i++){if($drive.Items[$i].Value -eq $data.Drive){$drive.SelectedIndex=$i}}
    if($data.Drive -and $drive.SelectedIndex -eq 0){$drive.SelectedIndex=$drive.Items.Add([pscustomobject]@{Label=$data.Drive+(Get-TrofeoText ' (недоступен)' $data.Language);Value=$data.Drive})}
    $cpu=New-Object Windows.Forms.CheckBox
    $cpu.Text=(Get-TrofeoText 'Датчики температуры и частоты CPU' $data.Language);$cpu.Checked=$data.CpuSensors
    $cpu.Location=New-Object Drawing.Point(20,182);$cpu.Size=New-Object Drawing.Size(470,26);$form.Controls.Add($cpu)
    $autoCheck=New-Object Windows.Forms.CheckBox
    $autoCheck.Text=(Get-TrofeoText 'Запускать при входе в Windows' $data.Language)
    $autoCheck.Location=New-Object Drawing.Point(20,214);$autoCheck.Size=New-Object Drawing.Size(470,26)
    $task=Get-ScheduledTask -TaskName 'Windows System Monitor Trofeo' -ErrorAction SilentlyContinue
    $autoCheck.Checked=($null -ne $task -and $task.State -ne 'Disabled')
    $applyState=@{Auto=$autoCheck.Checked};$form.Controls.Add($autoCheck)
    Label (Get-TrofeoText 'Хранить логи, дней' $data.Language) 260
    $days=Numeric 256 1 365 $data.LogDays
    Label (Get-TrofeoText 'Лимит старых логов, МиБ' $data.Language) 300
    $size=Numeric 296 20 2000 $data.LogMaxMiB
    Label (Get-TrofeoText 'CPU: жёлтый от, °C' $data.Language) 340
    $cpuYellow=Numeric 336 1 129 $data.CpuYellow
    Label (Get-TrofeoText 'CPU: красный от, °C' $data.Language) 380
    $cpuRed=Numeric 376 2 130 $data.CpuRed
    Label (Get-TrofeoText 'GPU: жёлтый от, °C' $data.Language) 420
    $gpuYellow=Numeric 416 1 129 $data.GpuYellow
    Label (Get-TrofeoText 'GPU: красный от, °C' $data.Language) 460
    $gpuRed=Numeric 456 2 130 $data.GpuRed
    $note=New-Object Windows.Forms.Label
    $note.Text=(Get-TrofeoText 'Текущий и последний запуск сохраняются. Изменения перезапустят работающий монитор.' $data.Language)
    $note.Location=New-Object Drawing.Point(20,498);$note.Size=New-Object Drawing.Size(480,45);$form.Controls.Add($note)
    $save=New-Object Windows.Forms.Button
    $save.Text=(Get-TrofeoText 'Применить' $data.Language);$save.Location=New-Object Drawing.Point(260,601);$save.Size=New-Object Drawing.Size(115,30);$form.Controls.Add($save)
    $cancel=New-Object Windows.Forms.Button
    $cancel.Text=(Get-TrofeoText 'Закрыть' $data.Language);$cancel.Location=New-Object Drawing.Point(385,601);$cancel.Size=New-Object Drawing.Size(115,30)
    $cancel.DialogResult='Cancel';$form.Controls.Add($cancel);$form.CancelButton=$cancel
    $cancel.add_Click({$form.Close()}.GetNewClosure())
    . (Join-Path $PSScriptRoot 'Ui-Theme.ps1')
    $body=New-Object Windows.Forms.Panel;$body.Name='AllSettings';$body.AutoScroll=$true
    $general=New-Object Windows.Forms.Panel;$general.Name='GeneralSettings';$general.Size=New-Object Drawing.Size(540,530)
    $screen=New-Object Windows.Forms.Panel;$screen.Name='ScreenSettings';$screen.Location=New-Object Drawing.Point(540,0);$screen.Size=New-Object Drawing.Size(580,530)
    foreach($control in @($form.Controls)){if($control -ne $note -and $control -ne $save -and $control -ne $cancel){$general.Controls.Add($control)}}
    $body.Controls.Add($general);$body.Controls.Add($screen);$form.Controls.Add($body)
    # Make room for the language selector at the top of the general settings.
    foreach($control in $general.Controls){$control.Top+=40}
    $general.Height=570
    $languageLabel=New-Object Windows.Forms.Label;$languageLabel.Text=(Get-TrofeoText 'Язык интерфейса' $data.Language);$languageLabel.Location=New-Object Drawing.Point(20,24);$languageLabel.Size=New-Object Drawing.Size(220,26);$general.Controls.Add($languageLabel)
    $language=New-Object Windows.Forms.ComboBox;$language.Name='Language';$language.DisplayMember='Label';$language.DropDownStyle='DropDownList'
    $language.Location=New-Object Drawing.Point(240,20);$language.Size=New-Object Drawing.Size(260,26)
    [void]$language.Items.Add([pscustomobject]@{Label='Русский';Value='ru'});[void]$language.Items.Add([pscustomobject]@{Label='English';Value='en'})
    $language.SelectedIndex=if($data.Language -eq 'en'){1}else{0};$general.Controls.Add($language)
    $language.add_SelectedIndexChanged({
        if($language.SelectedItem -and !$editState.Loading){$data.Language=[string]$language.SelectedItem.Value;Update-TrofeoFormLanguage $form $data.Language}
    }.GetNewClosure())
    $save.Size=New-Object Drawing.Size(108,32);$cancel.Size=New-Object Drawing.Size(108,32)
    function ScreenLabel($text,$y,$width=220){
        $label=New-Object Windows.Forms.Label;$label.Text=$text
        $label.Location=New-Object Drawing.Point(20,$y);$label.Size=New-Object Drawing.Size($width,26);$screen.Controls.Add($label)
    }
    ScreenLabel (Get-TrofeoText 'Показывать блоки (минимум один)' $data.Language) 18 550
    $blockChecks=@{}
    $blockNames=@{CPU='CPU';GPU='GPU';MEMORY=(Get-TrofeoText 'Память' $data.Language);NETWORK=(Get-TrofeoText 'Сеть' $data.Language);DISK=(Get-TrofeoText 'Диск' $data.Language)}
    $blockIndex=0
    foreach($key in @('CPU','GPU','MEMORY','NETWORK','DISK')){
        $check=New-Object Windows.Forms.CheckBox;$check.Text=$blockNames[$key];$check.Name='Block'+$key
        $check.Location=New-Object Drawing.Point((20+$blockIndex*112),52);$check.Size=New-Object Drawing.Size(110,28)
        $check.Checked=$key -in $data.DisplayBlocks.Split(',');$screen.Controls.Add($check);$blockChecks[$key]=$check;$blockIndex++
    }
    ScreenLabel (Get-TrofeoText 'Размер текста' $data.Language) 98
    $textSize=New-Object Windows.Forms.ComboBox;$textSize.Name='TextPercent'
    $textSize.Location=New-Object Drawing.Point(260,94);$textSize.Size=New-Object Drawing.Size(310,26)
    $textSize.DropDownStyle='DropDownList';$textSize.DisplayMember='Label'
    foreach($percent in @(90,100,110)){[void]$textSize.Items.Add([pscustomobject]@{Label=("$percent %");Value=$percent})}
    if($data.TextPercent -notin @(90,100,110)){[void]$textSize.Items.Add([pscustomobject]@{Label=("$($data.TextPercent) %");Value=$data.TextPercent})}
    $screen.Controls.Add($textSize)
    ScreenLabel (Get-TrofeoText 'Цвет акцента' $data.Language) 146
    $colorButton=New-Object Windows.Forms.Button;$colorButton.Name='AccentColor';$colorButton.Text='';$colorButton.Tag=$data.AccentColor;$colorButton.AccessibleName=(Get-TrofeoText 'Выбрать цвет акцента' $data.Language)
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
    ScreenLabel (Get-TrofeoText 'Главный показатель CPU' $data.Language) 194
    $cpuMetric=MetricCombo 'CpuMetric' 190 @(@{Label=(Get-TrofeoText 'Загрузка, %' $data.Language);Value='load'},@{Label=(Get-TrofeoText 'Температура, °C' $data.Language);Value='temperature'},@{Label=(Get-TrofeoText 'Частота, ГГц' $data.Language);Value='clock'})
    ScreenLabel (Get-TrofeoText 'Главный показатель GPU' $data.Language) 242
    $gpuMetric=MetricCombo 'GpuMetric' 238 @(@{Label=(Get-TrofeoText 'Загрузка, %' $data.Language);Value='load'},@{Label=(Get-TrofeoText 'Температура, °C' $data.Language);Value='temperature'},@{Label=(Get-TrofeoText 'Видеопамять, ГиБ' $data.Language);Value='vram'})
    foreach($control in @($screen.Controls)){if($control.Top -ge 94){$control.Top+=96}}
    $screen.Height=710
    ScreenLabel (Get-TrofeoText 'Готовый профиль' $data.Language) 98
    $profiles=MetricCombo 'AppearanceProfile' 94 @(@{Label=(Get-TrofeoText 'Пользовательский' $data.Language);Value='custom'},@{Label=(Get-TrofeoText 'Компактный' $data.Language);Value='compact'},@{Label=(Get-TrofeoText 'Крупные температуры' $data.Language);Value='temperatures'},@{Label=(Get-TrofeoText 'Подробные графики' $data.Language);Value='graphs'})
    $profiles.SelectedIndex=0
    ScreenLabel (Get-TrofeoText 'Оформление монитора' $data.Language) 146
    $theme=MetricCombo 'Theme' 140 @(@{Label=(Get-TrofeoText 'Тёмное' $data.Language);Value='dark'},@{Label=(Get-TrofeoText 'Светлое' $data.Language);Value='light'})
    foreach($main in @($cpuMetric,$gpuMetric)){
        [void]$main.Items.Add([pscustomobject]@{Label=(Get-TrofeoText 'Мощность, Вт' $data.Language);Value='power'})
        [void]$main.Items.Add([pscustomobject]@{Label=(Get-TrofeoText 'Вентилятор' $data.Language);Value='fan'})
    }
    $autoMetric=@(@{Label=(Get-TrofeoText 'Автоматически' $data.Language);Value='auto'},@{Label=(Get-TrofeoText 'Не показывать' $data.Language);Value='none'})
    $cpuSecondaryItems=$autoMetric+@($cpuMetric.Items | ForEach-Object {@{Label=$_.Label;Value=$_.Value}})
    $gpuSecondaryItems=$autoMetric+@($gpuMetric.Items | ForEach-Object {@{Label=$_.Label;Value=$_.Value}})
    ScreenLabel (Get-TrofeoText 'CPU: слева / справа' $data.Language) 382
    $cpuLeft=MetricCombo 'CpuSecondaryLeft' 378 $cpuSecondaryItems;$cpuLeft.Width=150
    $cpuRight=MetricCombo 'CpuSecondaryRight' 378 $cpuSecondaryItems;$cpuRight.Left=420;$cpuRight.Width=150
    ScreenLabel (Get-TrofeoText 'GPU: слева / справа' $data.Language) 430
    $gpuLeft=MetricCombo 'GpuSecondaryLeft' 426 $gpuSecondaryItems;$gpuLeft.Width=150
    $gpuRight=MetricCombo 'GpuSecondaryRight' 426 $gpuSecondaryItems;$gpuRight.Left=420;$gpuRight.Width=150
    $graphs=New-Object Windows.Forms.CheckBox;$graphs.Name='ShowGraphs';$graphs.Text=(Get-TrofeoText 'Показывать графики загрузки и сети' $data.Language)
    $graphs.Location=New-Object Drawing.Point(20,480);$graphs.Size=New-Object Drawing.Size(550,28);$graphs.Checked=$data.ShowGraphs;$screen.Controls.Add($graphs)
    $names=New-Object Windows.Forms.CheckBox;$names.Name='ShowDeviceNames';$names.Text=(Get-TrofeoText 'Показывать подписи оборудования и адаптера' $data.Language)
    $names.Location=New-Object Drawing.Point(20,520);$names.Size=New-Object Drawing.Size(550,28);$names.Checked=$data.ShowDeviceNames;$screen.Controls.Add($names)
    ScreenLabel (Get-TrofeoText 'Скрытые блоки освобождают место: видимые имеют равную ширину.' $data.Language) 578 550
    $hint=New-Object Windows.Forms.Label;$hint.Text=(Get-TrofeoText 'Температура, мощность и вентиляторы доступны только при поддержке оборудования. «—» означает отсутствие данных. Скорость GPU может отображаться в процентах, если обороты недоступны.' $data.Language)
    $hint.Location=New-Object Drawing.Point(20,622);$hint.Size=New-Object Drawing.Size(550,78);$screen.Controls.Add($hint)
    foreach($pair in @(@{Control=$textSize;Value=$data.TextPercent},@{Control=$cpuMetric;Value=$data.CpuMetric},@{Control=$gpuMetric;Value=$data.GpuMetric},@{Control=$theme;Value=$data.Theme},@{Control=$cpuLeft;Value=$data.CpuSecondaryLeft},@{Control=$cpuRight;Value=$data.CpuSecondaryRight},@{Control=$gpuLeft;Value=$data.GpuSecondaryLeft},@{Control=$gpuRight;Value=$data.GpuSecondaryRight})){
        for($i=0;$i -lt $pair.Control.Items.Count;$i++){if($pair.Control.Items[$i].Value -eq $pair.Value){$pair.Control.SelectedIndex=$i}}
    }
    $collect={
            param([switch]$ForProfile)
            if($editState.Loading){return}
            $data.Theme=[string]$theme.SelectedItem.Value
            $data.CpuSecondaryLeft=[string]$cpuLeft.SelectedItem.Value;$data.CpuSecondaryRight=[string]$cpuRight.SelectedItem.Value
            $data.GpuSecondaryLeft=[string]$gpuLeft.SelectedItem.Value;$data.GpuSecondaryRight=[string]$gpuRight.SelectedItem.Value
            $data.Language=[string]$language.SelectedItem.Value
            $data.Fps=[int]$fps.Value;$data.Rotation=[int]$rotation.SelectedItem.Value
            $data.NetworkId=[string]$network.SelectedItem.Value;$data.Drive=[string]$drive.SelectedItem.Value
            $data.CpuSensors=$cpu.Checked;$data.LogDays=[int]$days.Value;$data.LogMaxMiB=[int]$size.Value
            $data.CpuYellow=[int]$cpuYellow.Value;$data.CpuRed=[int]$cpuRed.Value
            $data.GpuYellow=[int]$gpuYellow.Value;$data.GpuRed=[int]$gpuRed.Value
            if($data.CpuYellow -ge $data.CpuRed -or $data.GpuYellow -ge $data.GpuRed){throw (Get-TrofeoText 'Красный порог должен быть выше жёлтого.' $data.Language)}
            $data.DisplayBlocks=(@('CPU','GPU','MEMORY','NETWORK','DISK') | Where-Object {$blockChecks[$_].Checked}) -join ','
            if(!$data.DisplayBlocks -and !$ForProfile){throw (Get-TrofeoText 'Выберите хотя бы один блок экрана.' $data.Language)}
            $data.TextPercent=[int]$textSize.SelectedItem.Value;$data.AccentColor=[string]$colorButton.Tag
            $data.CpuMetric=[string]$cpuMetric.SelectedItem.Value;$data.GpuMetric=[string]$gpuMetric.SelectedItem.Value
            $data.ShowGraphs=$graphs.Checked;$data.ShowDeviceNames=$names.Checked
            if(!$ForProfile){Assert-TrofeoSettings $data}

    }.GetNewClosure()
    $load={
        param($incoming)
        Assert-TrofeoSettings $incoming
        $editState.Loading=$true
        try {
        foreach($property in (New-TrofeoDefaults).PSObject.Properties) { $data.($property.Name)=$incoming.($property.Name) }
        $fps.Value=$data.Fps;$cpu.Checked=$data.CpuSensors;$days.Value=$data.LogDays;$size.Value=$data.LogMaxMiB
        $cpuYellow.Value=$data.CpuYellow;$cpuRed.Value=$data.CpuRed;$gpuYellow.Value=$data.GpuYellow;$gpuRed.Value=$data.GpuRed
        foreach($pair in @(@{Control=$rotation;Value=$data.Rotation},@{Control=$network;Value=$data.NetworkId},@{Control=$drive;Value=$data.Drive})) {
            $found=-1
            for($i=0;$i -lt $pair.Control.Items.Count;$i++){if($pair.Control.Items[$i].Value -eq $pair.Value){$found=$i;break}}
            if($found -lt 0){$found=$pair.Control.Items.Add([pscustomobject]@{Label=([string]$pair.Value+(Get-TrofeoText ' (недоступен)' $data.Language));Value=$pair.Value})}
            $pair.Control.SelectedIndex=$found
        }
        foreach($key in $blockChecks.Keys){$blockChecks[$key].Checked=$key -in $data.DisplayBlocks.Split(',')}
        $colorButton.Tag=$data.AccentColor;$colorButton.Invalidate();$graphs.Checked=$data.ShowGraphs;$names.Checked=$data.ShowDeviceNames
        if($data.TextPercent -notin @($textSize.Items | ForEach-Object {$_.Value})){[void]$textSize.Items.Add([pscustomobject]@{Label=("$($data.TextPercent) %");Value=$data.TextPercent})}
        foreach($pair in @(@{Control=$textSize;Value=$data.TextPercent},@{Control=$cpuMetric;Value=$data.CpuMetric},@{Control=$gpuMetric;Value=$data.GpuMetric},@{Control=$theme;Value=$data.Theme},@{Control=$cpuLeft;Value=$data.CpuSecondaryLeft},@{Control=$cpuRight;Value=$data.CpuSecondaryRight},@{Control=$gpuLeft;Value=$data.GpuSecondaryLeft},@{Control=$gpuRight;Value=$data.GpuSecondaryRight})){
            for($i=0;$i -lt $pair.Control.Items.Count;$i++){if($pair.Control.Items[$i].Value -eq $pair.Value){$pair.Control.SelectedIndex=$i}}
        }
        $language.SelectedIndex=if($data.Language -eq 'en'){1}else{0}
        $profiles.SelectedIndex=0
        }finally{$editState.Loading=$false}
        Update-TrofeoFormLanguage $form $data.Language
        $note.Text=(Get-TrofeoText 'Значения загружены. Нажмите «Применить», чтобы сохранить. Автозапуск не изменён.' $data.Language)
    }.GetNewClosure()
    $profiles.add_SelectedIndexChanged({
        if($editState.Loading -or $editState.ApplyingProfile -or !$profiles.SelectedItem -or $profiles.SelectedItem.Value -eq 'custom'){return}
        $selected=$profiles.SelectedIndex
        $id=[string]$profiles.SelectedItem.Value
        $editState.ApplyingProfile=$true
        try{& $collect -ForProfile;& $load (New-TrofeoProfile $data $id);$profiles.SelectedIndex=$selected}catch{if($TestMode){throw};[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,$form.Text)}finally{$editState.ApplyingProfile=$false}
    }.GetNewClosure())
    $markCustom={if(!$editState.Loading -and !$editState.ApplyingProfile){$profiles.SelectedIndex=0}}.GetNewClosure()
    foreach($control in @($theme,$textSize,$cpuMetric,$gpuMetric,$cpuLeft,$cpuRight,$gpuLeft,$gpuRight)){$control.add_SelectedIndexChanged($markCustom)}
    foreach($control in @($graphs,$names)+@($blockChecks.Values)){$control.add_CheckedChanged($markCustom)}
    $colorButton.add_Click($markCustom)
    $export=New-Object Windows.Forms.Button
    $export.Text=(Get-TrofeoText 'Экспорт...' $data.Language);$export.Location=New-Object Drawing.Point(20,674);$export.Size=New-Object Drawing.Size(108,32);$form.Controls.Add($export)
    $import=New-Object Windows.Forms.Button
    $import.Text=(Get-TrofeoText 'Импорт...' $data.Language);$import.Location=New-Object Drawing.Point(138,674);$import.Size=New-Object Drawing.Size(108,32);$form.Controls.Add($import)
    $reset=New-Object Windows.Forms.Button
    $reset.Text=(Get-TrofeoText 'По умолчанию' $data.Language);$reset.Location=New-Object Drawing.Point(256,674);$reset.Size=New-Object Drawing.Size(108,32);$form.Controls.Add($reset)
    $reset.add_Click({& $load (New-TrofeoDefaults)}.GetNewClosure())
    $import.add_Click({
        $dialog=New-Object Windows.Forms.OpenFileDialog
        $dialog.Filter=(Get-TrofeoText 'Настройки JSON (*.json)|*.json' $data.Language);$dialog.CheckFileExists=$true
        try {
            if($dialog.ShowDialog() -eq 'OK') { & $load (Import-TrofeoSettings $dialog.FileName) }
        } catch {if($TestMode){throw};[void][Windows.Forms.MessageBox]::Show((Get-TrofeoText $_.Exception.Message $data.Language),(Get-TrofeoText 'Не удалось импортировать' $data.Language))}
        finally {$dialog.Dispose()}
    }.GetNewClosure())
    $export.add_Click({
        $dialog=New-Object Windows.Forms.SaveFileDialog
        $dialog.Filter=(Get-TrofeoText 'Настройки JSON (*.json)|*.json' $data.Language);$dialog.DefaultExt='json';$dialog.FileName='Trofeo-settings.json';$dialog.OverwritePrompt=$true
        try {
            & $collect
            if($dialog.ShowDialog() -eq 'OK') {
                if([IO.Path]::GetFullPath($dialog.FileName) -eq [IO.Path]::GetFullPath($path)){throw (Get-TrofeoText 'Выберите отдельный файл для экспорта.' $data.Language)}
                Save-TrofeoSettings $data $dialog.FileName
                $note.Text=(Get-TrofeoText 'Настройки экспортированы. Автозапуск Windows в файл не включён.' $data.Language)
            }
        } catch {if($TestMode){throw};[void][Windows.Forms.MessageBox]::Show((Get-TrofeoText $_.Exception.Message $data.Language),(Get-TrofeoText 'Не удалось экспортировать' $data.Language))}
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
            $note.Text=(Get-TrofeoText 'Настройки сохранены. Окно можно оставить открытым или нажать «Закрыть».' $data.Language)
            if($OnApplied){& $OnApplied}
        } catch { if($TestMode){throw}; [void][Windows.Forms.MessageBox]::Show((Get-TrofeoText $_.Exception.Message $data.Language),(Get-TrofeoText 'Не удалось сохранить настройки' $data.Language)) }
    }.GetNewClosure())
. (Join-Path $PSScriptRoot 'Ui-Theme.ps1')
    $picture=New-Object Windows.Forms.PictureBox;$picture.Name='SettingsPreview';$picture.SizeMode='Zoom'
    $picture.Location=New-Object Drawing.Point(650,62);$picture.Size=New-Object Drawing.Size(510,230);$picture.BackColor=[Drawing.Color]::FromArgb(9,15,23);$form.Controls.Add($picture)
    $connectionInfo=New-Object Windows.Forms.TextBox;$connectionInfo.Name='ConnectionStatus';$connectionInfo.Multiline=$true;$connectionInfo.ReadOnly=$true;$connectionInfo.ScrollBars='None'
    $connectionInfo.Location=New-Object Drawing.Point(650,314);$connectionInfo.Size=New-Object Drawing.Size(510,350);$connectionInfo.Text=(Get-TrofeoText 'Состояние подключения появится после запуска монитора.' $data.Language);$form.Controls.Add($connectionInfo)
    $toolsPanel=New-Object Windows.Forms.Panel;$toolsPanel.Name='SettingsTools';$toolsPanel.Size=New-Object Drawing.Size(170,132);$form.Controls.Add($toolsPanel)
    . (Join-Path $PSScriptRoot 'Settings-Tools.ps1')
    Add-TrofeoSettingsTools $form $toolsPanel $data $PSScriptRoot -TestMode:$TestMode
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
            catch{$connectionInfo.Text=(Get-TrofeoText 'Не удалось открыть предпросмотр: ' $data.Language)+$_.Exception.Message}
        }.GetNewClosure())
    }
    $layout={
        $unit=$save.Width/108.0
        $margin=[int](20*$unit);$spacing=[int](16*$unit)
        $width=$form.ClientSize.Width-2*$margin

        $buttonY=$form.ClientSize.Height-[int](48*$unit)
        $note.Location=New-Object Drawing.Point($margin,($buttonY-[int](28*$unit)));$note.Size=New-Object Drawing.Size($width,([int](24*$unit)))
        $connectionInfo.Location=New-Object Drawing.Point($margin,($note.Top-[int](142*$unit)));$connectionInfo.Size=New-Object Drawing.Size(($width-[int](190*$unit)),([int](132*$unit)))
        $toolsPanel.Location=New-Object Drawing.Point(($connectionInfo.Right+[int](20*$unit)),$connectionInfo.Top)
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
    Update-TrofeoFormLanguage $form $data.Language
    return $form
}
