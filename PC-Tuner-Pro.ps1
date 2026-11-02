# PC Tuner Lite: Windows PowerShell 5.1, no downloads, no admin required.
$ErrorActionPreference = 'Stop'
$script:High = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$script:Targets = @(
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize','EnableTransparency'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced','TaskbarAnimations'),
    @('HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR','AppCaptureEnabled'),
    @('HKCU:\System\GameConfigStore','GameDVR_Enabled')
)
function UserID { [Security.Principal.WindowsIdentity]::GetCurrent().User.Value }
function Power($Verb,$Guid) {
    $r = if ($Guid) { & powercfg.exe $Verb $Guid 2>&1 } else { & powercfg.exe $Verb 2>&1 }
    if ($LASTEXITCODE -ne 0) { throw "powercfg failed: $r" }; return ($r -join "`n")
}
function Active {
    $r = Power '/getactivescheme'; if ($r -notmatch '[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}') { throw 'Cannot read power plan.' }; $Matches[0]
}
function Plan($Guid) { $null = Power '/setactive' $Guid; if ((Active) -ne $Guid) { throw 'Power plan not applied.' } }
function ReadValue($Path,$Name) {
    $exists=$false; $value=$null
    if (Test-Path -LiteralPath $Path) {
        $k=Get-Item -LiteralPath $Path
        try { $exists=$k.GetValueNames() -contains $Name; if ($exists) { if ($k.GetValueKind($Name).ToString() -ne 'DWord') { throw 'Unexpected registry type.' }; $value=$k.GetValue($Name) } } finally { $k.Close() }
    }
    [pscustomobject]@{Path=$Path; Name=$Name; Exists=$exists; Value=$value}
}
function WriteValue($S,$Undo) {
    if ($Undo -and -not $S.Exists) {
        if ((ReadValue $S.Path $S.Name).Exists) { Remove-ItemProperty -LiteralPath $S.Path -Name $S.Name }
    } else {
        if (-not (Test-Path -LiteralPath $S.Path)) { $null=New-Item -Path $S.Path }
        $v=0; if ($Undo) { $v=$S.Value }
        $null=New-ItemProperty -LiteralPath $S.Path -Name $S.Name -PropertyType DWord -Value $v -Force
    }
    $a=ReadValue $S.Path $S.Name
    if ($Undo -and -not $S.Exists) { if ($a.Exists) { throw 'Restore verification failed.' } }
    elseif (-not $a.Exists -or $a.Value -ne $v) { throw 'Setting verification failed.' }
}
function Tune($Mode,$Backup) {
    if (@(Get-Process -Name 'VALORANT','VALORANT-Win64-Shipping' -ErrorAction SilentlyContinue).Count) { throw 'Close Valorant first; close other games too.' }
    $null=New-Item -ItemType Directory -Path (Split-Path -Parent $Backup) -Force
    $lock=[IO.File]::Open(($Backup+'.lock'),'OpenOrCreate','ReadWrite','None')
    try {
        if ($Mode -eq 'Restore') {
            if (-not (Test-Path -LiteralPath $Backup)) { throw 'No backup found.' }
            $s=Get-Content -LiteralPath $Backup -Raw | ConvertFrom-Json
            if ($s.Version -notin @(1,2) -or $s.User -ne (UserID)) { throw 'Backup user/version mismatch.' }
            $expected=@($script:Targets)
            if ($s.Version -eq 1) { $expected=@($script:Targets[2],$script:Targets[3]) }
            elseif ($s.Profile -eq 'Daily') { $expected=@($script:Targets[0],$script:Targets[1]) }
            elseif ($s.Profile -eq 'Gaming') { $expected=@($script:Targets[2],$script:Targets[3],$script:Targets[0],$script:Targets[1]) }
            else { throw 'Invalid backup profile.' }
            if ($s.ChangePower -isnot [bool] -or $s.PowerPlan -notmatch '^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$' -or @($s.Settings).Count -ne $expected.Count) { throw 'Invalid backup.' }
            if ($s.Version -eq 2 -and $s.Profile -eq 'Daily' -and $s.ChangePower) { throw 'Invalid Daily backup.' }
            for ($i=0; $i -lt $expected.Count; $i++) {
                $v=$s.Settings[$i]
                if ($v.Path -ne $expected[$i][0] -or $v.Name -ne $expected[$i][1] -or $v.Exists -isnot [bool]) { throw 'Unexpected backup target.' }
                if ($v.Exists -and ($null -eq $v.Value -or $v.Value -isnot [ValueType] -or $v.Value -lt [int]::MinValue -or $v.Value -gt [uint32]::MaxValue -or [math]::Truncate([double]$v.Value) -ne $v.Value)) { throw 'Invalid backup value.' }
            }
            foreach ($v in $s.Settings) { WriteValue $v $true }; if ($s.ChangePower) { Plan $s.PowerPlan }
            Move-Item -LiteralPath $Backup -Destination ($Backup+'.restored-'+[guid]::NewGuid().ToString('N'))
            return 'Restored. Sign out and sign in to Windows.'
        }
        if ($Mode -notin @('Daily','Gaming')) { throw 'Unknown profile.' }
        if (Test-Path -LiteralPath $Backup) { throw 'Backup exists. Restore before applying another profile.' }
        $chosen=@($script:Targets[0],$script:Targets[1]); $change=$false
        if ($Mode -eq 'Gaming') { $chosen=@($script:Targets[2],$script:Targets[3],$script:Targets[0],$script:Targets[1]); $change=(Power '/list') -match $script:High }
        $s=[pscustomobject]@{Version=2; Profile=$Mode; User=(UserID); PowerPlan=(Active); ChangePower=[bool]$change; Settings=@($chosen | ForEach-Object { ReadValue $_[0] $_[1] })}
        $s | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Backup -Encoding UTF8
        $null=Get-Content -LiteralPath $Backup -Raw | ConvertFrom-Json
        if ($change) { Plan $script:High }; foreach ($v in $s.Settings) { WriteValue $v $false }
        return 'Applied. Sign out and sign in to Windows. Keep the backup to restore.'
    } finally { $lock.Dispose() }
}
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
function StartupWindow {
    $entries=@(StartupEntries)
    if (-not $entries.Count) { throw 'No eligible current-user Run entries found.' }
    $d=New-Object Windows.Forms.Form; $d.Text='Startup apps - current user only'; $d.Width=800; $d.Height=420; $d.StartPosition='CenterScreen'
    $label=New-Object Windows.Forms.Label; $label.SetBounds(15,10,750,55)
    $label.Text='Select ONLY apps you recognize and do not need at sign-in. Drivers/security/Riot names are hidden. Running apps are NOT closed. Startup folder, services and scheduled tasks are not edited.'
    $d.Controls.Add($label)
    $list=New-Object Windows.Forms.CheckedListBox; $list.SetBounds(15,70,750,240); $list.HorizontalScrollbar=$true
    foreach ($entry in $entries) { [void]$list.Items.Add($entry.Name+' | '+$entry.Value) }; $d.Controls.Add($list)
    $apply=New-Object Windows.Forms.Button; $apply.Text='Back up and disable selected'; $apply.SetBounds(15,320,300,40); $apply.DialogResult='OK'; $d.Controls.Add($apply)
    try {
        if ($d.ShowDialog() -eq 'OK') {
            $selected=@($list.CheckedIndices | ForEach-Object { $entries[[int]$_] })
            if (-not $selected.Count) { return }
            if ([Windows.Forms.MessageBox]::Show("Disable $($selected.Count) selected startup app(s) after backup?",'Confirm','YesNo','Question','Button2') -eq 'Yes') { $script:Output.Text=StartupChange $false $selected $script:StartupFile }
        }
    } finally { $d.Dispose() }
}
function StartReport($Task) {
    if ($null -ne $script:Job) { return }
    $defs=@('Power','Active','AppReport','HealthReport','LoadReport','NetworkReport') | ForEach-Object { 'function '+$_+' {'+(Get-Command $_).Definition+'}' }
    $lib='$ErrorActionPreference="Stop";'+($defs -join "`n")
    $script:Output.Text='Working... Sampling has a small CPU cost. Close this tool for normal play.'
    foreach ($b in $script:Buttons) { $b.Enabled=$false }
    try {
        $script:Job=Start-Job -ArgumentList $lib,$Task -ScriptBlock {
            param($Lib,$Task)
            . ([scriptblock]::Create($Lib))
            if ($Task -notin @('HealthReport','LoadReport','NetworkReport')) { throw 'Unknown report.' }; & $Task
        }
        $script:Timer.Start()
    } catch { foreach ($b in $script:Buttons) { $b.Enabled=$true }; throw }
}
function Start-Pro {
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Windows only.' }
    Add-Type -AssemblyName System.Windows.Forms
    $root=Join-Path $env:LOCALAPPDATA 'PCTuner'; $script:Backup=Join-Path $root 'backup.json'; $script:StartupFile=Join-Path $root 'startup-backup.json'
    $old=Join-Path $env:LOCALAPPDATA 'ValorantPCToolkit\backup.json'; if (Test-Path -LiteralPath $old) { $script:Backup=$old }
    $script:Job=$null; $script:Buttons=@()
    $script:Form=New-Object Windows.Forms.Form; $script:Form.Text='PC Tuner Pro'; $script:Form.Width=960; $script:Form.Height=700; $script:Form.StartPosition='CenterScreen'; $script:Form.MinimumSize=[Drawing.Size]::new(800,550)
    $layout=New-Object Windows.Forms.TableLayoutPanel; $layout.Dock='Fill'; $layout.RowCount=2; $layout.ColumnCount=1
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',110)); [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); $script:Form.Controls.Add($layout)
    $top=New-Object Windows.Forms.FlowLayoutPanel; $top.Dock='Fill'; $top.AutoScroll=$true; $layout.Controls.Add($top,0,0)
    $script:Output=New-Object Windows.Forms.RichTextBox; $script:Output.Dock='Fill'; $script:Output.ReadOnly=$true; $script:Output.Font=New-Object Drawing.Font('Consolas',10)
    $script:Output.Text="PC TUNER PRO - no promised FPS boost`r`n`r`nScan: hardware, CPU/RAM apps and disk space.`r`nCPU/RAM 20s: sample while reproducing a stutter, then close this tool.`r`nNetwork: gateway + Cloudflare ICMP, NOT your game server.`r`nDaily: reduce desktop transparency/animations.`r`nGaming: also disable Game DVR + existing High performance (more heat/power).`r`nUndo settings: restore the original snapshot.`r`nStartup: select known apps, back up and disable their next-login launch.`r`nUndo startup: restore that selection; stops on conflicting changes.`r`n`r`nClose games before tuning. Sign out/in after applying/undoing settings.`r`nBackups: $root`r`nKeep app: save a reusable app folder to Desktop.`r`nReports stay local unless you share them."
    $layout.Controls.Add($script:Output,0,1)
    foreach ($name in @('Scan','CPU/RAM 20s','Network','Daily','Gaming','Undo settings','Startup apps','Undo startup','Save report','Keep app')) {
        $b=New-Object Windows.Forms.Button; $b.Text=$name; $b.Width=170; $b.Height=40; $script:Buttons+=,$b
        $b.Add_Click({
            try {
                switch ($this.Text) {
                    'Scan' { StartReport 'HealthReport' }
                    'CPU/RAM 20s' { StartReport 'LoadReport' }
                    'Network' { StartReport 'NetworkReport' }
                    'Startup apps' { StartupWindow }
                    'Undo startup' {
                        if ([Windows.Forms.MessageBox]::Show('Restore saved startup entries? Conflicting newer entries will not be overwritten.','Confirm','YesNo','Question','Button2') -eq 'Yes') { $script:Output.Text=StartupChange $true @() $script:StartupFile }
                    }
                    'Keep app' { $script:Output.Text=InstallPro }
                    'Save report' {
                        $save=New-Object Windows.Forms.SaveFileDialog; $save.Filter='Text (*.txt)|*.txt'; $save.FileName='PC-report.txt'
                        try { if ($save.ShowDialog() -eq 'OK') { [IO.File]::WriteAllText($save.FileName,$script:Output.Text,[Text.UTF8Encoding]::new($true)) } } finally { $save.Dispose() }
                    }
                    default {
                        $mode=$this.Text; if ($mode -eq 'Undo settings') { $mode='Restore' }
                        $text="Run $mode? Close games first. Daily reduces desktop effects. Gaming also disables Game DVR and selects existing High performance (more heat/power). Restore uses the original backup."
                        if ([Windows.Forms.MessageBox]::Show($text,'Confirm','YesNo','Question','Button2') -eq 'Yes') { $script:Output.Text=Tune $mode $script:Backup }
                    }
                }
            } catch { [void][Windows.Forms.MessageBox]::Show($_.Exception.Message+"`r`nKeep backups. Use the matching Undo button if an operation was partial.",'PC Tuner') }
        }); $top.Controls.Add($b)
    }
    $script:Timer=New-Object Windows.Forms.Timer; $script:Timer.Interval=300
    $script:Timer.Add_Tick({
        if ($null -eq $script:Job -or $script:Job.State -in @('Running','NotStarted')) { return }
        $script:Timer.Stop()
        try {
            $result=Receive-Job $script:Job -ErrorAction Stop | Out-String -Width 150
            if ($script:Job.State -ne 'Completed') { throw 'Report did not complete.' }; $script:Output.Text=$result
        } catch { $script:Output.Text='Report incomplete: '+$_.Exception.Message }
        finally { Remove-Job $script:Job -Force; $script:Job=$null; foreach ($b in $script:Buttons) { $b.Enabled=$true } }
    })
    $script:Form.Add_FormClosing({ param($s,$e) if ($null -ne $script:Job) { $e.Cancel=$true; [void][Windows.Forms.MessageBox]::Show('Wait for the report to finish, then close. No permanent monitoring is installed.') } })
    try { [void]$script:Form.ShowDialog() } finally { $script:Timer.Dispose(); $script:Form.Dispose() }
}
Start-Pro
