$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$payload=Join-Path $root ('artifacts\setup-payload-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $payload | Out-Null
$files=@('Ui-Theme.ps1','Start-Trofeo.ps1','StabilityResult.ps1','Manage-Autostart.ps1','Preview-Window.ps1','Settings-Core.ps1','Settings-Window.ps1','Settings-Preview.ps1','Log-Retention.ps1','Tray-State.ps1','Trofeo-Tray.ps1','Trofeo-Hidden.vbs','trofeo-settings.json','THIRD-PARTY-NOTICES.md','README.md')
foreach($name in $files){Copy-Item -LiteralPath (Join-Path $root $name) -Destination $payload}
New-Item -ItemType Directory -Path (Join-Path $payload 'assets'),(Join-Path $payload 'artifacts\v0.1.7') -Force | Out-Null
Get-ChildItem (Join-Path $root 'assets') -Filter '*.ico' | Copy-Item -Destination (Join-Path $payload 'assets')
Get-ChildItem (Join-Path $root 'artifacts\portable-v0.1.7') | Where-Object {$_.Name -ne 'logs'} | Copy-Item -Destination (Join-Path $payload 'artifacts\v0.1.7') -Recurse
Copy-Item -LiteralPath (Join-Path $payload 'artifacts\v0.1.7\WindowsSystemMonitorTrofeo.exe') -Destination (Join-Path $payload 'artifacts\v0.1.7\TrofeoPreviewRenderer.exe')
$runtime=Get-Content (Join-Path $payload 'artifacts\v0.1.7\WindowsSystemMonitorTrofeo.runtimeconfig.json') -Raw | ConvertFrom-Json
if(!$runtime.runtimeOptions.includedFrameworks){throw 'Self-contained payload required'}
if(!(Test-Path (Join-Path $payload 'artifacts\v0.1.7\coreclr.dll'))){throw 'Bundled runtime missing'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=Join-Path $payload 'payload.zip'
$archive=Join-Path $root ('artifacts\payload-'+[Guid]::NewGuid().ToString('N')+'.zip')
[IO.Compression.ZipFile]::CreateFromDirectory($payload,$archive,[IO.Compression.CompressionLevel]::Optimal,$false)
$out=Join-Path $root 'artifacts\Trofeo-Setup-0.1.7.exe'
& "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /platform:x64 /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:Microsoft.CSharp.dll /r:System.Management.dll ("/win32icon:"+(Join-Path $root 'assets\trofeo-app.ico')) ("/resource:"+$archive+",payload.zip") ("/out:"+$out) (Join-Path $PSScriptRoot 'Setup.cs')
if($LASTEXITCODE -ne 0){throw 'Setup compilation failed'}
Get-Item $out | Select-Object FullName,Length
