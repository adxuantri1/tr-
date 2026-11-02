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
