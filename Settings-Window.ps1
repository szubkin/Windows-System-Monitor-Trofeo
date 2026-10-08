function New-TrofeoSettingsForm {
    param([switch]$TestMode)
    $path=Join-Path $PSScriptRoot 'trofeo-settings.json'
    $data=Read-TrofeoSettings $path
    $form=New-Object Windows.Forms.Form
    $form.Text='Настройки Trofeo'
    $form.ClientSize=New-Object Drawing.Size(520,650)
    $form.StartPosition='CenterScreen'
    $form.FormBorderStyle='FixedDialog'
    $form.MaximizeBox=$false; $form.MinimizeBox=$false
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
    $originalAuto=$autoCheck.Checked;$form.Controls.Add($autoCheck)
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
    $cancel.Text='Отмена';$cancel.Location=New-Object Drawing.Point(385,601);$cancel.Size=New-Object Drawing.Size(115,30)
    $cancel.DialogResult='Cancel';$form.Controls.Add($cancel);$form.CancelButton=$cancel
    $collect={
            $data.Fps=[int]$fps.Value;$data.Rotation=[int]$rotation.SelectedItem.Value
            $data.NetworkId=[string]$network.SelectedItem.Value;$data.Drive=[string]$drive.SelectedItem.Value
            $data.CpuSensors=$cpu.Checked;$data.LogDays=[int]$days.Value;$data.LogMaxMiB=[int]$size.Value
            $data.CpuYellow=[int]$cpuYellow.Value;$data.CpuRed=[int]$cpuRed.Value
            $data.GpuYellow=[int]$gpuYellow.Value;$data.GpuRed=[int]$gpuRed.Value
            if($data.CpuYellow -ge $data.CpuRed -or $data.GpuYellow -ge $data.GpuRed){throw 'Красный порог должен быть выше жёлтого.'}
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
        $note.Text='Значения загружены. Нажмите «Применить», чтобы сохранить. Автозапуск не изменён.'
    }.GetNewClosure()
    $export=New-Object Windows.Forms.Button
    $export.Text='Экспорт...';$export.Location=New-Object Drawing.Point(20,548);$export.Size=New-Object Drawing.Size(145,30);$form.Controls.Add($export)
    $import=New-Object Windows.Forms.Button
    $import.Text='Импорт...';$import.Location=New-Object Drawing.Point(180,548);$import.Size=New-Object Drawing.Size(145,30);$form.Controls.Add($import)
    $reset=New-Object Windows.Forms.Button
    $reset.Text='По умолчанию';$reset.Location=New-Object Drawing.Point(340,548);$reset.Size=New-Object Drawing.Size(160,30);$form.Controls.Add($reset)
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
                if($autoCheck.Checked -ne $originalAuto){if($autoCheck.Checked){Set-Autostart 'Enable'}else{Set-Autostart 'Disable'}}
            } catch {
                [IO.File]::WriteAllText($path,$old)
                throw
            }
            $form.DialogResult='OK';$form.Close()
        } catch { if($TestMode){throw}; [void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'Не удалось сохранить настройки') }
    }.GetNewClosure())
. (Join-Path $PSScriptRoot 'Ui-Theme.ps1')
    [TrofeoUi.DarkTheme]::Apply($form)
    return $form
}
