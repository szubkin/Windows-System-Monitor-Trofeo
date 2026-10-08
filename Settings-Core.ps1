function Read-TrofeoSettings([string]$Path) {
    $data=Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $defaults=@{Rotation=-1;NetworkId='';Drive='';LogDays=30;LogMaxMiB=200;CpuYellow=75;CpuRed=90;GpuYellow=70;GpuRed=85;DisplayBlocks='CPU,GPU,MEMORY,NETWORK,DISK';AccentColor='#44E2C6';TextPercent=100;CpuMetric='load';GpuMetric='load';ShowGraphs=$true;ShowDeviceNames=$true}
    foreach($key in $defaults.Keys) {
        if (!$data.PSObject.Properties[$key]) { $data | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key] }
    }
    Assert-TrofeoSettings $data
    return $data
}
function Assert-TrofeoSettings($data) {
    foreach($key in @('Fps','UsbBlockSize','BlockDelayMs','StabilitySeconds','Rotation','LogDays','LogMaxMiB','CpuYellow','CpuRed','GpuYellow','GpuRed','TextPercent')) {
        if ($data.$key -isnot [int] -and $data.$key -isnot [long]) { throw "Invalid integer: $key" }
    }
    if ($data.Fps -lt 1 -or $data.Fps -gt 10 -or $data.UsbBlockSize -notin @(2048,4096) -or $data.BlockDelayMs -lt 0 -or $data.BlockDelayMs -gt 10 -or $data.StabilitySeconds -lt 1800 -or $data.StabilitySeconds -gt 3600 -or $data.CpuSensors -isnot [bool] -or $data.Rotation -notin @(-1,0,180) -or $data.LogDays -lt 1 -or $data.LogDays -gt 365 -or $data.LogMaxMiB -lt 20 -or $data.LogMaxMiB -gt 2000) { throw 'Settings out of range.' }
    if ($data.CpuYellow -lt 1 -or $data.CpuRed -gt 130 -or $data.CpuYellow -ge $data.CpuRed -or $data.GpuYellow -lt 1 -or $data.GpuRed -gt 130 -or $data.GpuYellow -ge $data.GpuRed) { throw 'Temperature thresholds: 1 <= yellow < red <= 130.' }
    $blocks=@(([string]$data.DisplayBlocks).Split(','))
    if ($data.DisplayBlocks -isnot [string] -or $blocks.Count -lt 1 -or @($blocks | Select-Object -Unique).Count -ne $blocks.Count -or @($blocks | Where-Object {$_ -notin @('CPU','GPU','MEMORY','NETWORK','DISK')}).Count -gt 0) { throw 'Select at least one unique screen block.' }
    if ($data.AccentColor -isnot [string] -or $data.AccentColor -notmatch '^#[0-9a-fA-F]{6}$' -or $data.TextPercent -lt 90 -or $data.TextPercent -gt 110 -or $data.CpuMetric -notin @('load','temperature','clock') -or $data.GpuMetric -notin @('load','temperature','vram') -or $data.ShowGraphs -isnot [bool] -or $data.ShowDeviceNames -isnot [bool]) { throw 'Invalid screen settings.' }
    if ($data.NetworkId -isnot [string] -or $data.Drive -isnot [string] -or ($data.Drive -ne '' -and $data.Drive -notmatch '^[A-Za-z]:\\$')) { throw 'Invalid adapter or drive.' }
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
    [pscustomobject]@{Fps=6;UsbBlockSize=4096;BlockDelayMs=0;CpuSensors=$true;StabilitySeconds=1800;Rotation=-1;NetworkId='';Drive='';LogDays=30;LogMaxMiB=200;CpuYellow=75;CpuRed=90;GpuYellow=70;GpuRed=85;DisplayBlocks='CPU,GPU,MEMORY,NETWORK,DISK';AccentColor='#44E2C6';TextPercent=100;CpuMetric='load';GpuMetric='load';ShowGraphs=$true;ShowDeviceNames=$true}
}
function Import-TrofeoSettings([string]$Path) {
    if((Get-Item -LiteralPath $Path).Length -gt 64KB){throw 'Settings file exceeds 64 KB.'}
    $value=Read-TrofeoSettings $Path
    $clean=New-TrofeoDefaults
    foreach($property in $clean.PSObject.Properties){$property.Value=$value.($property.Name)}
    return $clean
}
