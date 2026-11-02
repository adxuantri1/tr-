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
function AppReport {
    $before=@{}; $watch=[Diagnostics.Stopwatch]::StartNew()
    Get-Process | ForEach-Object { try { $before[$_.Id]=@($_.StartTime.Ticks,$_.TotalProcessorTime.TotalMilliseconds,$watch.Elapsed.TotalMilliseconds) } catch {} }
    Start-Sleep -Seconds 2
    $cores=[Environment]::ProcessorCount
    $rows=@(Get-Process | ForEach-Object {
        try {
            $old=$before[$_.Id]
            if ($null -ne $old -and $old[0] -eq $_.StartTime.Ticks) {
                $elapsed=$watch.Elapsed.TotalMilliseconds-$old[2]
                $cpu=[math]::Max(0,[math]::Min(100,100*($_.TotalProcessorTime.TotalMilliseconds-$old[1])/($elapsed*$cores)))
                [pscustomobject]@{App=$_.ProcessName; PID=$_.Id; CPU_pct=[math]::Round($cpu,1); RAM_MB=[math]::Round($_.WorkingSet64/1MB)}
            }
        } catch {}
    })
    'TOP CPU: two-second sample, normalized across logical processors (not FPS)'
    $rows | Sort-Object CPU_pct -Descending | Select-Object -First 12 | Format-Table -AutoSize | Out-String
    'TOP RAM: working set, not proof of a memory leak'
    $rows | Sort-Object RAM_MB -Descending | Select-Object -First 12 | Format-Table -AutoSize | Out-String
    'No applications were closed. Review unused apps manually.'
}
function HealthReport {
    foreach ($class in @('Win32_Processor','Win32_VideoController','Win32_OperatingSystem','Win32_ComputerSystem','Win32_LogicalDisk')) {
        try {
            switch ($class) {
                'Win32_Processor' { Get-CimInstance $class | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors | Format-Table | Out-String }
                'Win32_VideoController' { Get-CimInstance $class | Select-Object Name,DriverVersion | Format-Table | Out-String }
                'Win32_OperatingSystem' { Get-CimInstance $class | Select-Object Caption,@{N='FreeRAM_MB';E={[math]::Round($_.FreePhysicalMemory/1KB)}},@{N='TotalRAM_MB';E={[math]::Round($_.TotalVisibleMemorySize/1KB)}} | Format-Table | Out-String }
                'Win32_ComputerSystem' { Get-CimInstance $class | Select-Object AutomaticManagedPagefile | Format-Table | Out-String }
                'Win32_LogicalDisk' { Get-CimInstance $class -Filter 'DriveType=3' | Select-Object DeviceID,@{N='FreeGB';E={[math]::Round($_.FreeSpace/1GB,1)}} | Format-Table | Out-String }
            }
        } catch { 'Unavailable: '+$class+' - '+$_.Exception.Message }
    }
    AppReport
}
function LoadReport {
    $samples=@(for ($i=0;$i -lt 20;$i++) {
        if ($i) { Start-Sleep -Seconds 1 }
        $cpu=Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
        $os=Get-CimInstance Win32_OperatingSystem
        [pscustomobject]@{Time=[DateTime]::Now; CPU=[double]$cpu.PercentProcessorTime; FreeRAM_MB=[math]::Round($os.FreePhysicalMemory/1KB)}
    })
    '20 CPU/RAM samples. Short spikes may be missed; NOT a game FPS/temperature/GPU measurement.'
    $samples | Format-Table -AutoSize | Out-String
    'CPU: '+(($samples | Measure-Object CPU -Average -Maximum) | Out-String)
    'Minimum free RAM MB: '+($samples | Measure-Object FreeRAM_MB -Minimum).Minimum
    'CPU near 95-100% or low free RAM are clues, not a confirmed bottleneck. Close the tool for normal play.'
}
function NetworkReport {
    $targets=@('1.1.1.1')
    try { $r=Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' | Where-Object {$_.NextHop -ne '0.0.0.0'} | Sort-Object RouteMetric | Select-Object -First 1; if ($r) { $targets=@($r.NextHop)+$targets } } catch { 'Gateway unavailable; public target only.' }
    $p=New-Object Net.NetworkInformation.Ping
    try {
        foreach ($target in $targets) {
            $ok=@(for ($i=0;$i -lt 8;$i++) { if ($i) { Start-Sleep -Milliseconds 250 }; try { $r=$p.Send([string]$target,800); if ($r.Status -eq 'Success') { [double]$r.RoundtripTime } } catch {} })
            "Target: $target; replies: $($ok.Count)/8; no-reply: $([math]::Round(100*(8-$ok.Count)/8,1))%"
            if ($ok.Count) { $ok | Measure-Object -Average -Minimum -Maximum | Out-String } else { 'No ICMP replies; filtering is possible.' }
        }
    } finally { $p.Dispose() }
    'ICMP only. Public target is Cloudflare, NOT Riot. No-replies do not prove game packet loss. No network settings changed.'
}
