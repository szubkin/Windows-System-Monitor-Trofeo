. (Join-Path $PSScriptRoot 'Localization.ps1')
function Read-TrofeoSettings([string]$Path) {
    $data=Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $defaults=@{Language='ru';Theme='dark';CpuSecondaryLeft='auto';CpuSecondaryRight='auto';GpuSecondaryLeft='auto';GpuSecondaryRight='auto';Rotation=-1;NetworkId='';Drive='';LogDays=30;LogMaxMiB=200;CpuYellow=75;CpuRed=90;GpuYellow=70;GpuRed=85;DisplayBlocks='CPU,GPU,MEMORY,NETWORK,DISK';AccentColor='#44E2C6';TextPercent=100;CpuMetric='load';GpuMetric='load';ShowGraphs=$true;ShowDeviceNames=$true}
    foreach($key in $defaults.Keys) {
        if (!$data.PSObject.Properties[$key]) { $data | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key] }
    }
    Assert-TrofeoSettings $data
    return $data
}
function Assert-TrofeoSettings($data) {
    if($data.Language -notin @('ru','en')){throw (Get-TrofeoText 'Недопустимый язык.' $data.Language)}
    if($data.Theme -notin @('dark','light') -or $data.CpuSecondaryLeft -notin @('auto','none','load','temperature','clock','power','fan') -or $data.CpuSecondaryRight -notin @('auto','none','load','temperature','clock','power','fan') -or $data.GpuSecondaryLeft -notin @('auto','none','load','temperature','vram','power','fan') -or $data.GpuSecondaryRight -notin @('auto','none','load','temperature','vram','power','fan')){throw (Get-TrofeoText 'Некорректные настройки экрана.' $data.Language)}
    foreach($key in @('Fps','UsbBlockSize','BlockDelayMs','StabilitySeconds','Rotation','LogDays','LogMaxMiB','CpuYellow','CpuRed','GpuYellow','GpuRed','TextPercent')) {
        if ($data.$key -isnot [int] -and $data.$key -isnot [long]) { throw ((Get-TrofeoText 'Некорректное целое число: {0}' $data.Language) -f $key) }
    }
    if ($data.Fps -lt 1 -or $data.Fps -gt 10 -or $data.UsbBlockSize -notin @(2048,4096) -or $data.BlockDelayMs -lt 0 -or $data.BlockDelayMs -gt 10 -or $data.StabilitySeconds -lt 1800 -or $data.StabilitySeconds -gt 3600 -or $data.CpuSensors -isnot [bool] -or $data.Rotation -notin @(-1,0,180) -or $data.LogDays -lt 1 -or $data.LogDays -gt 365 -or $data.LogMaxMiB -lt 20 -or $data.LogMaxMiB -gt 2000) { throw (Get-TrofeoText 'Некорректные значения настроек.' $data.Language) }
    if ($data.CpuYellow -lt 1 -or $data.CpuRed -gt 130 -or $data.CpuYellow -ge $data.CpuRed -or $data.GpuYellow -lt 1 -or $data.GpuRed -gt 130 -or $data.GpuYellow -ge $data.GpuRed) { throw (Get-TrofeoText 'Температурные пороги: 1 <= жёлтый < красный <= 130.' $data.Language) }
    $blocks=@(([string]$data.DisplayBlocks).Split(','))
    if ($data.DisplayBlocks -isnot [string] -or $blocks.Count -lt 1 -or @($blocks | Select-Object -Unique).Count -ne $blocks.Count -or @($blocks | Where-Object {$_ -notin @('CPU','GPU','MEMORY','NETWORK','DISK')}).Count -gt 0) { throw (Get-TrofeoText 'Выберите хотя бы один уникальный блок экрана.' $data.Language) }
    if ($data.AccentColor -isnot [string] -or $data.AccentColor -notmatch '^#[0-9a-fA-F]{6}$' -or $data.TextPercent -lt 90 -or $data.TextPercent -gt 110 -or $data.CpuMetric -notin @('load','temperature','clock','power','fan') -or $data.GpuMetric -notin @('load','temperature','vram','power','fan') -or $data.ShowGraphs -isnot [bool] -or $data.ShowDeviceNames -isnot [bool]) { throw (Get-TrofeoText 'Некорректные настройки экрана.' $data.Language) }
    if ($data.NetworkId -isnot [string] -or $data.Drive -isnot [string] -or ($data.Drive -ne '' -and $data.Drive -notmatch '^[A-Za-z]:\\$')) { throw (Get-TrofeoText 'Некорректный адаптер или диск.' $data.Language) }
}
function Save-TrofeoSettings($data,[string]$Path) {
    Assert-TrofeoSettings $data
    $temp=$Path+'.tmp'
    [IO.File]::WriteAllText($temp,($data | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
    if(Test-Path -LiteralPath $Path) { [IO.File]::Replace($temp,$Path,$Path+'.bak') }
    else { [IO.File]::Move($temp,$Path) }
}
function Get-TrofeoArguments($settings,[string]$mode,[string]$folder,[string]$root) {
    Assert-TrofeoSettings $settings
    $result=@('--monitor','--fps',"$($settings.Fps)",'--usb-block-size',"$($settings.UsbBlockSize)",'--block-delay-ms',"$($settings.BlockDelayMs)",'--log-dir',$folder)
    $result+=@('--cpu-yellow',"$($settings.CpuYellow)",'--cpu-red',"$($settings.CpuRed)",'--gpu-yellow',"$($settings.GpuYellow)",'--gpu-red',"$($settings.GpuRed)")
    $result+=@('--language',$settings.Language,'--theme',$settings.Theme,'--cpu-secondary-left',$settings.CpuSecondaryLeft,'--cpu-secondary-right',$settings.CpuSecondaryRight,'--gpu-secondary-left',$settings.GpuSecondaryLeft,'--gpu-secondary-right',$settings.GpuSecondaryRight)
    $result+=@('--display-blocks',$settings.DisplayBlocks,'--accent-color',$settings.AccentColor,'--text-percent',"$($settings.TextPercent)",'--cpu-metric',$settings.CpuMetric,'--gpu-metric',$settings.GpuMetric)
    if(!$settings.ShowGraphs){$result+='--hide-graphs'}
    if(!$settings.ShowDeviceNames){$result+='--hide-device-names'}
    if($settings.CpuSensors) { $result+='--cpu-sensors' }
    if($settings.Rotation -ne -1) { $result+=@('--rotation',"$($settings.Rotation)") }
    if($settings.NetworkId) { $result+=@('--network-id',$settings.NetworkId) }
    if($settings.Drive) { $result+=@('--drive',$settings.Drive) }
    if($mode -eq 'Stability') { $result+=@('--hold-seconds',"$($settings.StabilitySeconds)") }
    else { $result+=@('--continuous','--recover','--status-file',(Join-Path $root 'logs\monitor-status.json')) }
    return $result
}

function New-TrofeoDefaults {
    [pscustomobject]@{Fps=6;UsbBlockSize=4096;BlockDelayMs=0;CpuSensors=$true;StabilitySeconds=1800;Language='ru';Theme='dark';CpuSecondaryLeft='auto';CpuSecondaryRight='auto';GpuSecondaryLeft='auto';GpuSecondaryRight='auto';Rotation=-1;NetworkId='';Drive='';LogDays=30;LogMaxMiB=200;CpuYellow=75;CpuRed=90;GpuYellow=70;GpuRed=85;DisplayBlocks='CPU,GPU,MEMORY,NETWORK,DISK';AccentColor='#44E2C6';TextPercent=100;CpuMetric='load';GpuMetric='load';ShowGraphs=$true;ShowDeviceNames=$true}
}
function Import-TrofeoSettings([string]$Path) {
    if((Get-Item -LiteralPath $Path).Length -gt 64KB){throw (Get-TrofeoText 'Файл настроек превышает 64 КБ.' $data.Language)}
    $value=Read-TrofeoSettings $Path
    $clean=New-TrofeoDefaults
    foreach($property in $clean.PSObject.Properties){$property.Value=$value.($property.Name)}
    return $clean
}

function New-TrofeoProfile($Current,[string]$Profile) {
    $result=New-TrofeoDefaults
    foreach($property in $result.PSObject.Properties){$property.Value=$Current.($property.Name)}
    $result.Theme='dark';$result.AccentColor='#44E2C6';$result.ShowDeviceNames=$true
    $result.CpuSecondaryLeft='auto';$result.CpuSecondaryRight='auto';$result.GpuSecondaryLeft='auto';$result.GpuSecondaryRight='auto'
    switch($Profile){
        'compact' {$result.DisplayBlocks='CPU,GPU,MEMORY,NETWORK';$result.TextPercent=90;$result.ShowGraphs=$false;$result.CpuMetric='load';$result.GpuMetric='load'}
        'temperatures' {$result.DisplayBlocks='CPU,GPU,MEMORY';$result.TextPercent=110;$result.ShowGraphs=$false;$result.CpuMetric='temperature';$result.GpuMetric='temperature';$result.CpuSecondaryRight='power';$result.GpuSecondaryRight='power'}
        'graphs' {$result.DisplayBlocks='CPU,GPU,MEMORY,NETWORK,DISK';$result.TextPercent=100;$result.ShowGraphs=$true;$result.CpuMetric='load';$result.GpuMetric='load';$result.CpuSecondaryRight='power';$result.GpuSecondaryLeft='power';$result.GpuSecondaryRight='fan'}
        default {throw 'Unknown appearance profile'}
    }
    Assert-TrofeoSettings $result
    return $result
}
