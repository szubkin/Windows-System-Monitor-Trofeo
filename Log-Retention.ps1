function Clear-TrofeoLogs([string]$ProjectRoot,[int]$Days=30,[int]$MaxMiB=200,[int[]]$ActiveIds=@()) {
    if($Days -lt 1 -or $Days -gt 365 -or $MaxMiB -lt 20 -or $MaxMiB -gt 2000) { throw 'Invalid retention limit.' }
    $root=[IO.Path]::GetFullPath((Join-Path $ProjectRoot 'logs')).TrimEnd('\')
    if(!(Test-Path -LiteralPath $root)) { return }
    if((Get-Item -LiteralPath $root).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Log root is a link; cleanup skipped.' }
    $groups=@()
    foreach($dir in Get-ChildItem -LiteralPath $root -Directory) {
        if($dir.Name -notmatch '^daily-\d{8}-\d{6}-\d+-\d+$' -or ($dir.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
        $full=[IO.Path]::GetFullPath($dir.FullName)
        if([IO.Path]::GetDirectoryName($full) -ne $root) { throw 'Log path escaped root.' }
        $files=@(Get-ChildItem -LiteralPath $full -File | Where-Object { !($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -and ($_.Name -like 'trofeo-*' -or $_.Name -eq 'stability-result.txt') })
        $size=($files | Measure-Object Length -Sum).Sum
        $newest=($files | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1).LastWriteTimeUtc
        if(!$newest) { $newest=$dir.LastWriteTimeUtc }
        $owner=[int]($dir.Name.Split('-')[-1])
        $groups+= [pscustomobject]@{Path=$full;Files=$files;Size=[long]$size;Time=$newest;Active=($ActiveIds -contains $owner)}
    }
    $groups=@($groups | Sort-Object Time -Descending)
    $total=[long](($groups | Measure-Object Size -Sum).Sum)
    $latest=if($groups.Count){$groups[0].Path}else{''}
    foreach($group in ($groups | Sort-Object Time)) {
        if($group.Active -or $group.Path -eq $latest) { continue }
        if($group.Time -ge [DateTime]::UtcNow.AddDays(-$Days) -and $total -le $MaxMiB*1MB) { continue }
        foreach($file in $group.Files) {
            $target=[IO.Path]::GetFullPath($file.FullName)
            if([IO.Path]::GetDirectoryName($target) -ne $group.Path -or !$target.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe cleanup target.' }
            if((Get-Item -LiteralPath $group.Path).Attributes -band [IO.FileAttributes]::ReparsePoint) { break }
            try { Remove-Item -LiteralPath $target -ErrorAction Stop; $total-=$file.Length } catch {}
        }
        # Non-recursive removal only: unknown files and subdirectories are preserved.
        if(@(Get-ChildItem -LiteralPath $group.Path -Force).Count -eq 0) { Remove-Item -LiteralPath $group.Path -ErrorAction SilentlyContinue }
    }
}
