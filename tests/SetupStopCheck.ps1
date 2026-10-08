$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$testDir=Join-Path $root ('artifacts\setup-stop-'+[Guid]::NewGuid().ToString('N'))
$other=Join-Path $testDir 'other'
New-Item -ItemType Directory -Path $other -Force | Out-Null
$sha=[Security.Cryptography.SHA256]::Create()
try{$hash=[BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($testDir))).Replace('-','')}finally{$sha.Dispose()}
$prefix='Local\TrofeoSetupTest-'+$hash+'-'
$code=@'
using System;
using System.IO;
using System.Threading;
class FakeMonitor {
    static void Main(string[] args){
        using(var stop=new EventWaitHandle(false,EventResetMode.ManualReset,args[1]+"Stop")){
            File.WriteAllText(Path.Combine(args[0],"monitor-ready"),"ready");
            stop.WaitOne();Thread.Sleep(300);
            File.WriteAllText(Path.Combine(args[0],"monitor-stopped"),"safe stop");
        }
    }
}
'@
$source=Join-Path $testDir 'FakeMonitor.cs'
[IO.File]::WriteAllText($source,$code)
$exe=Join-Path $testDir 'WindowsSystemMonitorTrofeo.exe'
& "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe ("/out:"+$exe) $source
if($LASTEXITCODE -ne 0){throw 'Mock compilation failed'}
$hostCode=@'
param([string]$Marker)
[IO.File]::WriteAllText($Marker,'ready')
while($true){Start-Sleep -Milliseconds 100}
'@
$trayScript=Join-Path $testDir 'Trofeo-Tray.ps1';$otherScript=Join-Path $other 'Trofeo-Tray.ps1'
[IO.File]::WriteAllText($trayScript,$hostCode);[IO.File]::WriteAllText($otherScript,$hostCode)
$psExe="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$monitor=$null;$tray=$null;$unrelated=$null
try{
    $monitor=Start-Process $exe -WindowStyle Hidden -PassThru -ArgumentList @(('"' + $testDir + '"'),$prefix)
    $tray=Start-Process $psExe -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$trayScript+'"'),'-Marker',('"'+(Join-Path $testDir 'tray-ready')+'"'))
    $unrelated=Start-Process $psExe -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$otherScript+'"'),'-Marker',('"'+(Join-Path $other 'tray-ready')+'"'))
    $limit=[DateTime]::UtcNow.AddSeconds(8)
    while(!(Test-Path (Join-Path $testDir 'monitor-ready')) -or !(Test-Path (Join-Path $testDir 'tray-ready')) -or !(Test-Path (Join-Path $other 'tray-ready'))){
        if([DateTime]::UtcNow -gt $limit){throw 'Mocks did not start'};Start-Sleep -Milliseconds 50
    }
    $setup=Start-Process (Join-Path $root 'artifacts\Trofeo-Setup-0.1.7.exe') -WindowStyle Hidden -PassThru -Wait -ArgumentList @('--test-stop',('"'+$testDir+'"'))
    if($setup.ExitCode -ne 0 -or !(Test-Path (Join-Path $testDir 'monitor-stopped'))){throw 'Installer did not wait for graceful monitor stop'}
    if(!$monitor.WaitForExit(1000) -or !$tray.WaitForExit(1000) -or $unrelated.HasExited){throw 'Incorrect shutdown process scope'}
    Write-Output 'PASS: installer waits for safe monitor stop, closes its legacy tray and preserves an unrelated host; mock events only, no USB.'
}finally{
    foreach($process in @($monitor,$tray,$unrelated)){if($process){if(!$process.HasExited){$process.Kill();$process.WaitForExit(2000)};$process.Dispose()}}
}
