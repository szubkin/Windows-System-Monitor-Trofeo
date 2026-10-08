$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
. (Join-Path $root 'Settings-Core.ps1')
. (Join-Path $root 'Settings-Tools.ps1')
function Check($condition,$name){if(!$condition){throw $name};Write-Host "PASS $name"}
$original=New-TrofeoDefaults;$original.Fps=4;$original.Language='en';$original.NetworkId='adapter-test'
foreach($id in @('compact','temperatures','graphs')){
    $profile=New-TrofeoProfile $original $id
    Check ($profile.Fps -eq 4 -and $profile.Language -eq 'en' -and $profile.NetworkId -eq 'adapter-test') 'preset preserves runtime choices'
    Check ($original.DisplayBlocks -eq 'CPU,GPU,MEMORY,NETWORK,DISK') 'preset does not mutate original settings'
}
$original.Theme='light';$original.CpuSecondaryLeft='power';$original.GpuSecondaryRight='fan'
Assert-TrofeoSettings $original
$arguments=@(Get-TrofeoArguments $original 'Monitor' $root $root)
Check ($arguments -contains '--theme' -and $arguments -contains 'light' -and $arguments -contains '--gpu-secondary-right' -and $arguments -contains 'fan') 'theme and sensors forwarded to process'
foreach($tag in @('v0.1.0','v0.2.0','v0.3.0')){
    $release=Resolve-TrofeoUpdate @{tag_name=$tag;html_url='https://github.com/szubkin/Windows-System-Monitor-Trofeo/releases/tag/'+$tag} ([version]'0.2.0')
    Check ($release.Newer -eq ($tag -eq 'v0.3.0')) 'only newer stable release offered'
}
foreach($bad in @(@{tag_name='vbad';html_url='https://github.com/'},@{tag_name='v0.3.0';prerelease=$true;html_url='https://github.com/'},@{tag_name='v0.3.0';html_url='https://evil.example/release'})){
    $rejected=$false;try{Resolve-TrofeoUpdate $bad ([version]'0.2.0')}catch{$rejected=$true}
    Check $rejected 'untrusted or prerelease response rejected'
}
Check ((Get-TrofeoText 'Светлое' 'en') -eq 'Light') 'new appearance translated'
