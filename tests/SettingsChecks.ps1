$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
. (Join-Path $root 'Settings-Core.ps1')
. (Join-Path $root 'Log-Retention.ps1')
function Check($test,$message){if(!$test){throw $message};Write-Output "PASS $message"}
$data=Read-TrofeoSettings (Join-Path $root 'trofeo-settings.json')
Check ($data.Rotation -eq -1 -and $data.LogDays -eq 30) 'old settings get defaults'
$testRoot=Join-Path $root ('artifacts\settings-test-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$path=Join-Path $testRoot 'settings.json'
Save-TrofeoSettings $data $path
$data.Drive='D:\';$data.NetworkId='test-adapter';$data.Rotation=180
Save-TrofeoSettings $data $path
$loaded=Read-TrofeoSettings $path
Check ($loaded.Drive -eq 'D:\' -and $loaded.Rotation -eq 180 -and (Test-Path ($path+'.bak'))) 'atomic save and backup'
$launch=@(Get-TrofeoArguments $loaded 'Monitor' (Join-Path $testRoot 'run') $testRoot)
Check ($launch -contains 'D:\' -and $launch -contains 'test-adapter' -and $launch -contains '180' -and $launch -contains (Join-Path $testRoot 'logs\monitor-status.json')) 'launch settings and full status path'
$loaded.Fps=99
$rejected=$false
try {Save-TrofeoSettings $loaded $path}catch{$rejected=$true}
Check ($rejected -and (Read-TrofeoSettings $path).Fps -ne 99) 'invalid settings never saved'
$logs=Join-Path $testRoot 'logs'
foreach($id in @(10,20,30)){
    $dir=Join-Path $logs "daily-20260101-120000-000-$id"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $file=Join-Path $dir 'trofeo-test.log'
    [IO.File]::WriteAllText($file,'test')
    (Get-Item $file).LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-40+$id/10)
}
$unknown=Join-Path $logs 'personal.txt';[IO.File]::WriteAllText($unknown,'preserve')
Clear-TrofeoLogs $testRoot 30 200 @(20)
Check (!(Test-Path (Join-Path $logs 'daily-20260101-120000-000-10'))) 'old inactive logs removed'
Check ((Test-Path (Join-Path $logs 'daily-20260101-120000-000-20\trofeo-test.log')) -and (Test-Path (Join-Path $logs 'daily-20260101-120000-000-30\trofeo-test.log')) -and (Test-Path $unknown)) 'active latest and unknown files preserved'
# New but oversized inactive logs must also be removed by the size limit.
$dir=Join-Path $logs 'daily-20260102-120000-000-40';New-Item -ItemType Directory -Path $dir | Out-Null
$file=Join-Path $dir 'trofeo-large.bin';$stream=[IO.File]::Create($file);$stream.SetLength(21MB);$stream.Dispose()
(Get-Item $file).LastWriteTimeUtc=[DateTime]::UtcNow.AddDays(-1)
(Get-Item (Join-Path $logs 'daily-20260101-120000-000-30\trofeo-test.log')).LastWriteTimeUtc=[DateTime]::UtcNow
Clear-TrofeoLogs $testRoot 365 20 @(20)
Check (!(Test-Path $file)) 'size cap removes oldest eligible files'

$data=Read-TrofeoSettings (Join-Path $root 'trofeo-settings.json')
Check ($data.CpuYellow -eq 75 -and $data.GpuRed -eq 85) 'temperature defaults for old configuration'
$data.CpuYellow=68;$data.CpuRed=88;$data.GpuYellow=65;$data.GpuRed=82
Save-TrofeoSettings $data $path
$again=Read-TrofeoSettings $path
$arguments=@(Get-TrofeoArguments $again 'Monitor' $testRoot $root)
Check ($again.CpuYellow -eq 68 -and $again.GpuRed -eq 82 -and $arguments -contains '--cpu-yellow' -and $arguments -contains '82') 'threshold round trip and CLI forwarding'
$data.GpuRed=60;$rejected=$false
try{Save-TrofeoSettings $data $path}catch{$rejected=$true}
Check ($rejected -and (Read-TrofeoSettings $path).GpuRed -eq 82) 'bad threshold order does not overwrite configuration'

$defaults=New-TrofeoDefaults
Save-TrofeoSettings $defaults $path
$imported=Import-TrofeoSettings $path
Check ($imported.Fps -eq 6 -and $imported.CpuYellow -eq 75) 'export import defaults'
[IO.File]::WriteAllText($path,'{"Fps":999}')
$rejected=$false;try{Import-TrofeoSettings $path}catch{$rejected=$true}
Check $rejected 'partial invalid import rejected'
[IO.File]::WriteAllText($path,('x'*65537))
$rejected=$false;try{Import-TrofeoSettings $path}catch{$rejected=$true}
Check $rejected 'oversized import rejected'
