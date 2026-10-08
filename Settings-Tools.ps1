function Resolve-TrofeoUpdate($Release,[version]$Current) {
    if($Release.draft -or $Release.prerelease -or [string]$Release.tag_name -notmatch '^v?(\d+\.\d+\.\d+)$'){throw 'Некорректная версия GitHub.'}
    $version=[version]$Matches[1]
    $uri=$null
    if(![Uri]::TryCreate([string]$Release.html_url,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.Host -ne 'github.com' -or !$uri.AbsolutePath.StartsWith('/szubkin/Windows-System-Monitor-Trofeo/releases/')){throw 'Некорректная ссылка GitHub.'}
    [pscustomobject]@{Newer=($version -gt $Current);Version=$version.ToString();Url=$uri.AbsoluteUri}
}
function Add-TrofeoSettingsTools($Form,$Panel,$Data,$Root,[switch]$TestMode,[scriptblock]$ReportViewer={param($file)[void][Diagnostics.Process]::Start('notepad.exe',('"'+$file+'"'))}) {
    $diagnostics=New-Object Windows.Forms.Button;$diagnostics.Text=Get-TrofeoText 'Диагностика' $Data.Language;$diagnostics.Name='Diagnostics';$diagnostics.SetBounds(0,0,170,32);$Panel.Controls.Add($diagnostics)
    $updates=New-Object Windows.Forms.Button;$updates.Text=Get-TrofeoText 'Обновления' $Data.Language;$updates.Name='Updates';$updates.SetBounds(0,40,170,32);$Panel.Controls.Add($updates)
    $message=New-Object Windows.Forms.Label;$message.SetBounds(0,80,170,48);$Panel.Controls.Add($message)
    if($TestMode){return}
    Add-Type -AssemblyName System.Net.Http
    $state=@{Task=$null;Client=$null;Process=$null;Output='';Deadline=[DateTime]::MinValue;Language=$Data.Language}
    $timer=New-Object Windows.Forms.Timer;$timer.Interval=150
    $updates.add_Click({
        try {
            $state.Language=$Data.Language;$updates.Enabled=$false;$message.Text=Get-TrofeoText 'Проверяем…' $state.Language
            [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
            $state.Client=New-Object Net.Http.HttpClient;$state.Client.Timeout=[TimeSpan]::FromSeconds(10)
            $state.Client.DefaultRequestHeaders.UserAgent.ParseAdd('Trofeo/0.2.0')
            $state.Task=$state.Client.GetStringAsync('https://api.github.com/repos/szubkin/Windows-System-Monitor-Trofeo/releases/latest')
            $timer.Start()
        }catch{$updates.Enabled=$true;$message.Text=Get-TrofeoText 'Ошибка проверки обновлений.' $Data.Language}
    }.GetNewClosure())
    $diagnostics.add_Click({
        try {
            $diagnostics.Enabled=$false;$message.Text=Get-TrofeoText 'Создаём отчёт…' $Data.Language
            $folder=Join-Path $Root 'logs\diagnostics';[void][IO.Directory]::CreateDirectory($folder)
            $state.Output=Join-Path $folder ('trofeo-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss-fff')+'.txt')
            $start=New-Object Diagnostics.ProcessStartInfo
            $start.FileName=Join-Path $Root 'artifacts\v0.2.0\TrofeoPreviewRenderer.exe'
            $start.Arguments='--diagnostics "'+$state.Output+'" --status-file "'+(Join-Path $Root 'logs\monitor-status.json')+'" --language '+$Data.Language
            $start.UseShellExecute=$false;$start.CreateNoWindow=$true
            $state.Process=[Diagnostics.Process]::Start($start);$state.Deadline=[DateTime]::UtcNow.AddSeconds(15)
            $timer.Start()
        }catch{$diagnostics.Enabled=$true;$message.Text=Get-TrofeoText 'Не удалось создать отчёт.' $Data.Language}
    }.GetNewClosure())
    $timer.add_Tick({
        if($state.Task -and $state.Task.IsCompleted){
            try{
                $json=$state.Task.GetAwaiter().GetResult()
                if($json.Length -gt 65536){throw 'Response too large'}
                $release=Resolve-TrofeoUpdate ($json | ConvertFrom-Json) ([version]'0.2.0')
                if($release.Newer){
                    $text=(Get-TrofeoText 'Доступна версия {0}. Открыть GitHub?' $state.Language) -f $release.Version
                    if([Windows.Forms.MessageBox]::Show($Form,$text,(Get-TrofeoText 'Обновления' $state.Language),'YesNo','Information') -eq 'Yes'){[void][Diagnostics.Process]::Start($release.Url)}
                    $message.Text=$text
                }else{$message.Text=(Get-TrofeoText 'Установлена {0}; GitHub: {1}.' $state.Language) -f '0.2.0',$release.Version}
            }catch{$message.Text=Get-TrofeoText 'Ошибка проверки обновлений.' $state.Language}
            finally{$state.Task=$null;$state.Client.Dispose();$state.Client=$null;$updates.Enabled=$true}
        }
        if($state.Process){
            if($state.Process.HasExited){
                if($state.Process.ExitCode -eq 0 -and [IO.File]::Exists($state.Output)){
                    $message.Text=Get-TrofeoText 'Отчёт сохранён.' $Data.Language
                    try{& $ReportViewer $state.Output}catch{$message.Text=(Get-TrofeoText 'Отчёт сохранён: {0}' $Data.Language) -f $state.Output}
                }else{$message.Text=Get-TrofeoText 'Не удалось создать отчёт.' $Data.Language}
                $state.Process.Dispose();$state.Process=$null;$diagnostics.Enabled=$true
            }elseif([DateTime]::UtcNow -gt $state.Deadline){
                $state.Process.Kill();$state.Process.Dispose();$state.Process=$null;$diagnostics.Enabled=$true;$message.Text=Get-TrofeoText 'Не удалось создать отчёт.' $Data.Language
            }
        }
        if(!$state.Task -and !$state.Process){$timer.Stop()}
    }.GetNewClosure())
    $Form.add_FormClosed({
        $timer.Stop();$timer.Dispose()
        if($state.Client){$state.Client.CancelPendingRequests();$state.Client.Dispose()}
        if($state.Process){$state.Process.Dispose()}
    }.GetNewClosure())
}
