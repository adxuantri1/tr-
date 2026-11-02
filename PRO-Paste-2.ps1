function ReadStartup($Name) {
    $path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $k=Get-Item -LiteralPath $path
    try {
        if ($k.GetValueNames() -notcontains $Name) { return $null }
        $kind=$k.GetValueKind($Name).ToString()
        if ($kind -notin @('String','ExpandString')) { throw 'Unsupported startup entry type.' }
        [pscustomobject]@{Name=$Name; Kind=$kind; Value=$k.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
    } finally { $k.Close() }
}
function StartupEntries {
    $path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    if (Test-Path -LiteralPath $path) {
        $k=Get-Item -LiteralPath $path
        try { $names=@($k.GetValueNames()) } finally { $k.Close() }
        foreach ($name in $names) { if ($name -and $name -notmatch 'Riot|Vanguard|Security|Defender|NVIDIA|Realtek|Intel') { ReadStartup $name } }
    }
}
function StartupChange($Undo,$Entries,$File) {
    $path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $null=New-Item -ItemType Directory -Path (Split-Path -Parent $File) -Force
    $lock=[IO.File]::Open(($File+'.lock'),'OpenOrCreate','ReadWrite','None')
    try {
        if ($Undo) {
            if (-not (Test-Path -LiteralPath $File)) { throw 'No startup backup found.' }
            $s=Get-Content -LiteralPath $File -Raw | ConvertFrom-Json
            if ($s.Version -ne 1 -or $s.User -ne (UserID) -or @($s.Items).Count -lt 1 -or @($s.Items).Count -gt 1000) { throw 'Invalid startup backup.' }
        } else {
            if (Test-Path -LiteralPath $File) { throw 'Restore previous startup backup first.' }
            if (@($Entries).Count -eq 0) { throw 'Select at least one startup app.' }
            $s=[pscustomobject]@{Version=1; User=(UserID); Items=@($Entries)}
        }
        $names=@{}
        foreach ($v in $s.Items) {
            if ($v.Name -isnot [string] -or -not $v.Name -or $v.Kind -notin @('String','ExpandString') -or $v.Value -isnot [string] -or $names.ContainsKey($v.Name)) { throw 'Invalid or duplicate startup entry.' }
            $names[$v.Name]=$true
            $current=ReadStartup $v.Name
            if ($null -ne $current -and ($current.Kind -ne $v.Kind -or $current.Value -cne $v.Value)) { throw 'Startup entry changed. Refresh or resolve the conflict before continuing.' }
            if (-not $Undo -and ($null -eq $current -or $v.Name -match 'Riot|Vanguard|Security|Defender|NVIDIA|Realtek|Intel')) { throw 'Missing or protected startup entry. Refresh the list.' }
        }
        if (-not $Undo) { $s | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $File -Encoding UTF8; $null=Get-Content -LiteralPath $File -Raw | ConvertFrom-Json }
        foreach ($v in $s.Items) {
            if ($Undo) {
                if (-not (Test-Path -LiteralPath $path)) { $null=New-Item -Path $path }
                $null=New-ItemProperty -LiteralPath $path -Name $v.Name -PropertyType $v.Kind -Value $v.Value -Force
                $a=ReadStartup $v.Name
                if ($null -eq $a -or $a.Kind -ne $v.Kind -or $a.Value -cne $v.Value) { throw 'Startup restore verification failed.' }
            } else {
                $now=ReadStartup $v.Name
                if ($null -eq $now -or $now.Kind -ne $v.Kind -or $now.Value -cne $v.Value) { throw 'Startup changed during save. Backup kept.' }
                Remove-ItemProperty -LiteralPath $path -Name $v.Name
                if ($null -ne (ReadStartup $v.Name)) { throw 'Startup disable verification failed.' }
            }
        }
        if ($Undo) { Move-Item -LiteralPath $File -Destination ($File+'.restored-'+[guid]::NewGuid().ToString('N')) }
        return 'Startup settings saved. Changes affect NEXT sign-in; running apps are not closed.'
    } finally { $lock.Dispose() }
}
function ExportProText {
    $items=$script:Targets | ForEach-Object { "@('"+$_[0].Replace("'","''")+"','"+$_[1].Replace("'","''")+"')" }
    $head='$ErrorActionPreference="Stop";$script:High="'+$script:High+'";$script:Targets=@('+($items -join ',')+');'
    $names=@('UserID','Power','Active','Plan','ReadValue','WriteValue','Tune','ReadStartup','StartupEntries','StartupChange','ExportProText','InstallPro','AppReport','HealthReport','LoadReport','NetworkReport','StartupWindow','StartReport','Start-Pro')
    $defs=$names | ForEach-Object { 'function '+$_+' {'+(Get-Command $_ -CommandType Function).Definition+'}' }
    return $head+"`n"+($defs -join "`n")+"`nStart-Pro`n"
}
function InstallPro([string]$desktop = [Environment]::GetFolderPath('Desktop')) {
    if (-not $desktop) { throw 'Desktop not found.' }
    $folder=Join-Path $desktop ('PC-Tuner-Pro-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    $null=New-Item -ItemType Directory -Path $folder
    [IO.File]::WriteAllText((Join-Path $folder 'PC-Tuner-Pro.ps1'),(ExportProText),[Text.UTF8Encoding]::new($true))
    $cmd=@('@echo off','powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0PC-Tuner-Pro.ps1"','pause') -join "`r`n"
    [IO.File]::WriteAllText((Join-Path $folder 'START.cmd'),$cmd,[Text.Encoding]::ASCII)
    return "App saved: $folder`r`nNext time, open START.cmd in that folder. No auto-start or permanent execution-policy change was added."
}
