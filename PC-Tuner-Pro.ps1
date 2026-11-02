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
    if ($LASTEXITCODE -ne 0) { throw "Không thực hiện được lệnh nguồn điện: $r" }; return ($r -join "`n")
}
function Active {
    $r = Power '/getactivescheme'; if ($r -notmatch '[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}') { throw 'Không đọc được chế độ nguồn điện.' }; $Matches[0]
}
function Plan($Guid) { $null = Power '/setactive' $Guid; if ((Active) -ne $Guid) { throw 'Chưa áp dụng được chế độ nguồn điện.' } }
function ReadValue($Path,$Name) {
    $exists=$false; $value=$null
    if (Test-Path -LiteralPath $Path) {
        $k=Get-Item -LiteralPath $Path
        try { $exists=$k.GetValueNames() -contains $Name; if ($exists) { if ($k.GetValueKind($Name).ToString() -ne 'DWord') { throw 'Kiểu dữ liệu thiết lập không được hỗ trợ.' }; $value=$k.GetValue($Name) } } finally { $k.Close() }
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
    if ($Undo -and -not $S.Exists) { if ($a.Exists) { throw 'Không xác minh được kết quả hoàn tác.' } }
    elseif (-not $a.Exists -or $a.Value -ne $v) { throw 'Không xác minh được thiết lập vừa thay đổi.' }
}
function Tune($Mode,$Backup) {
    if (@(Get-Process -Name 'VALORANT','VALORANT-Win64-Shipping' -ErrorAction SilentlyContinue).Count) { throw 'Hãy đóng Valorant và các game khác trước khi tiếp tục.' }
    $null=New-Item -ItemType Directory -Path (Split-Path -Parent $Backup) -Force
    $lock=[IO.File]::Open(($Backup+'.lock'),'OpenOrCreate','ReadWrite','None')
    try {
        if ($Mode -eq 'Restore') {
            if (-not (Test-Path -LiteralPath $Backup)) { throw 'Chưa có bản sao lưu thiết lập để hoàn tác.' }
            $s=Get-Content -LiteralPath $Backup -Raw | ConvertFrom-Json
            if ($s.Version -notin @(1,2) -or $s.User -ne (UserID)) { throw 'Bản sao lưu thuộc tài khoản khác hoặc phiên bản không được hỗ trợ.' }
            $expected=@($script:Targets)
            if ($s.Version -eq 1) { $expected=@($script:Targets[2],$script:Targets[3]) }
            elseif ($s.Profile -eq 'Daily') { $expected=@($script:Targets[0],$script:Targets[1]) }
            elseif ($s.Profile -eq 'Gaming') { $expected=@($script:Targets[2],$script:Targets[3],$script:Targets[0],$script:Targets[1]) }
            else { throw 'Chế độ trong bản sao lưu không hợp lệ.' }
            if ($s.ChangePower -isnot [bool] -or $s.PowerPlan -notmatch '^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$' -or @($s.Settings).Count -ne $expected.Count) { throw 'Bản sao lưu không hợp lệ.' }
            if ($s.Version -eq 2 -and $s.Profile -eq 'Daily' -and $s.ChangePower) { throw 'Bản sao lưu chế độ hằng ngày không hợp lệ.' }
            for ($i=0; $i -lt $expected.Count; $i++) {
                $v=$s.Settings[$i]
                if ($v.Path -ne $expected[$i][0] -or $v.Name -ne $expected[$i][1] -or $v.Exists -isnot [bool]) { throw 'Bản sao lưu chứa thiết lập không được phép thay đổi.' }
                if ($v.Exists -and ($null -eq $v.Value -or $v.Value -isnot [ValueType] -or $v.Value -lt [int]::MinValue -or $v.Value -gt [uint32]::MaxValue -or [math]::Truncate([double]$v.Value) -ne $v.Value)) { throw 'Giá trị trong bản sao lưu không hợp lệ.' }
            }
            foreach ($v in $s.Settings) { WriteValue $v $true }; if ($s.ChangePower) { Plan $s.PowerPlan }
            Move-Item -LiteralPath $Backup -Destination ($Backup+'.restored-'+[guid]::NewGuid().ToString('N'))
            return 'Đã hoàn tác. Hãy đăng xuất rồi đăng nhập lại Windows.'
        }
        if ($Mode -notin @('Daily','Gaming')) { throw 'Chế độ không được hỗ trợ.' }
        if (Test-Path -LiteralPath $Backup) { throw 'Đã có bản sao lưu. Hãy hoàn tác trước khi áp dụng chế độ khác.' }
        $chosen=@($script:Targets[0],$script:Targets[1]); $change=$false
        if ($Mode -eq 'Gaming') { $chosen=@($script:Targets[2],$script:Targets[3],$script:Targets[0],$script:Targets[1]); $change=(Power '/list') -match $script:High }
        $s=[pscustomobject]@{Version=2; Profile=$Mode; User=(UserID); PowerPlan=(Active); ChangePower=[bool]$change; Settings=@($chosen | ForEach-Object { ReadValue $_[0] $_[1] })}
        $s | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Backup -Encoding UTF8
        $null=Get-Content -LiteralPath $Backup -Raw | ConvertFrom-Json
        if ($change) { Plan $script:High }; foreach ($v in $s.Settings) { WriteValue $v $false }
        return 'Đã áp dụng. Hãy đăng xuất rồi đăng nhập lại Windows. Giữ bản sao lưu để hoàn tác.'
    } finally { $lock.Dispose() }
}
function ReadStartup($Name) {
    $path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $k=Get-Item -LiteralPath $path
    try {
        if ($k.GetValueNames() -notcontains $Name) { return $null }
        $kind=$k.GetValueKind($Name).ToString()
        if ($kind -notin @('String','ExpandString')) { throw 'Kiểu dữ liệu ứng dụng khởi động không được hỗ trợ.' }
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
            if (-not (Test-Path -LiteralPath $File)) { throw 'Chưa có bản sao lưu ứng dụng khởi động.' }
            $s=Get-Content -LiteralPath $File -Raw | ConvertFrom-Json
            if ($s.Version -ne 1 -or $s.User -ne (UserID) -or @($s.Items).Count -lt 1 -or @($s.Items).Count -gt 1000) { throw 'Bản sao lưu ứng dụng khởi động không hợp lệ.' }
        } else {
            if (Test-Path -LiteralPath $File) { throw 'Hãy hoàn tác thay đổi khởi động trước khi chọn ứng dụng khác.' }
            if (@($Entries).Count -eq 0) { throw 'Hãy chọn ít nhất một ứng dụng khởi động.' }
            $s=[pscustomobject]@{Version=1; User=(UserID); Items=@($Entries)}
        }
        $names=@{}
        foreach ($v in $s.Items) {
            if ($v.Name -isnot [string] -or -not $v.Name -or $v.Kind -notin @('String','ExpandString') -or $v.Value -isnot [string] -or $names.ContainsKey($v.Name)) { throw 'Mục khởi động không hợp lệ hoặc bị trùng.' }
            $names[$v.Name]=$true
            $current=ReadStartup $v.Name
            if ($null -ne $current -and ($current.Kind -ne $v.Kind -or $current.Value -cne $v.Value)) { throw 'Mục khởi động đã thay đổi. Hãy mở lại danh sách hoặc xử lý xung đột trước khi tiếp tục.' }
            if (-not $Undo -and ($null -eq $current -or $v.Name -match 'Riot|Vanguard|Security|Defender|NVIDIA|Realtek|Intel')) { throw 'Mục khởi động đã mất hoặc được bảo vệ. Hãy mở lại danh sách.' }
        }
        if (-not $Undo) { $s | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $File -Encoding UTF8; $null=Get-Content -LiteralPath $File -Raw | ConvertFrom-Json }
        foreach ($v in $s.Items) {
            if ($Undo) {
                if (-not (Test-Path -LiteralPath $path)) { $null=New-Item -Path $path }
                $null=New-ItemProperty -LiteralPath $path -Name $v.Name -PropertyType $v.Kind -Value $v.Value -Force
                $a=ReadStartup $v.Name
                if ($null -eq $a -or $a.Kind -ne $v.Kind -or $a.Value -cne $v.Value) { throw 'Không xác minh được kết quả khôi phục ứng dụng khởi động.' }
            } else {
                $now=ReadStartup $v.Name
                if ($null -eq $now -or $now.Kind -ne $v.Kind -or $now.Value -cne $v.Value) { throw 'Mục khởi động thay đổi trong lúc lưu. Bản sao lưu vẫn được giữ.' }
                Remove-ItemProperty -LiteralPath $path -Name $v.Name
                if ($null -ne (ReadStartup $v.Name)) { throw 'Không xác minh được việc tắt ứng dụng khởi động.' }
            }
        }
        if ($Undo) { Move-Item -LiteralPath $File -Destination ($File+'.restored-'+[guid]::NewGuid().ToString('N')) }
        return 'Đã lưu thiết lập khởi động. Thay đổi có hiệu lực ở lần đăng nhập sau; ứng dụng đang chạy không bị đóng.'
    } finally { $lock.Dispose() }
}
function ExportProText {
    $items=$script:Targets | ForEach-Object { "@('"+$_[0].Replace("'","''")+"','"+$_[1].Replace("'","''")+"')" }
    $head='$ErrorActionPreference="Stop";$script:High="'+$script:High+'";$script:Targets=@('+($items -join ',')+');'
    $names=@('UserID','Power','Active','Plan','ReadValue','WriteValue','Tune','ReadStartup','StartupEntries','StartupChange','ExportProText','InstallPro','AppReport','HealthReport','LoadReport','NetworkReport','DashboardData','DarkTitle','UiFont','UiLabel','UiPanel','UiButton','SetUiStatus','ShowUiResult','UpdateBackupState','UpdateDashboard','ShowPage','ConfirmAction','StartupWindow','Invoke-ProAction','StartReport','NewMetricCard','OverviewPage','ProfilesPage','StartupPage','DiagnosticsPage','BuildSidebar','Start-Pro')
    $defs=$names | ForEach-Object { 'function '+$_+' {'+(Get-Command $_ -CommandType Function).Definition+'}' }
    return $head+"`n"+($defs -join "`n")+"`nStart-Pro`n"
}
function InstallPro([string]$desktop = [Environment]::GetFolderPath('Desktop')) {
    if (-not $desktop) { throw 'Không tìm thấy thư mục Desktop.' }
    $folder=Join-Path $desktop ('PC-Tuner-Pro-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    $null=New-Item -ItemType Directory -Path $folder
    [IO.File]::WriteAllText((Join-Path $folder 'PC-Tuner-Pro.ps1'),(ExportProText),[Text.UTF8Encoding]::new($true))
    $cmd=@('@echo off','chcp 65001 >nul','powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0PC-Tuner-Pro.ps1"','set "PC_TUNER_EXIT=%ERRORLEVEL%"','if not "%PC_TUNER_EXIT%"=="0" (','echo Không mở được ứng dụng. Xem lỗi phía trên rồi nhấn phím bất kỳ để đóng.','pause >nul',')','exit /b %PC_TUNER_EXIT%') -join "`r`n"
    [IO.File]::WriteAllText((Join-Path $folder 'START.cmd'),$cmd,[Text.UTF8Encoding]::new($false))
    return "Đã lưu ứng dụng: $folder`r`nLần sau mở START.cmd trong thư mục đó. Không tạo tự khởi động hoặc đổi chính sách chạy lệnh vĩnh viễn."
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
    'ỨNG DỤNG DÙNG NHIỀU CPU: đo trong khoảng hai giây, chuẩn hóa theo số luồng CPU; không phải FPS.'
    $rows | Sort-Object CPU_pct -Descending | Select-Object -First 12 | Format-Table @{N='Ứng dụng';E={$_.App}},PID,@{N='CPU (%)';E={$_.CPU_pct}},@{N='RAM (MB)';E={$_.RAM_MB}} -AutoSize | Out-String
    'ỨNG DỤNG DÙNG NHIỀU RAM: bộ nhớ đang chiếm dụng; chưa chứng minh rò rỉ bộ nhớ.'
    $rows | Sort-Object RAM_MB -Descending | Select-Object -First 12 | Format-Table @{N='Ứng dụng';E={$_.App}},PID,@{N='CPU (%)';E={$_.CPU_pct}},@{N='RAM (MB)';E={$_.RAM_MB}} -AutoSize | Out-String
    'Chưa đóng ứng dụng nào. Bạn có thể tự xem và đóng các ứng dụng không dùng.'
}
function HealthReport {
    foreach ($class in @('Win32_Processor','Win32_VideoController','Win32_OperatingSystem','Win32_ComputerSystem','Win32_LogicalDisk')) {
        try {
            switch ($class) {
                'Win32_Processor' { Get-CimInstance $class | Select-Object @{N='CPU';E={$_.Name}},@{N='Số nhân';E={$_.NumberOfCores}},@{N='Số luồng';E={$_.NumberOfLogicalProcessors}} | Format-Table | Out-String }
                'Win32_VideoController' { Get-CimInstance $class | Select-Object @{N='Card đồ họa';E={$_.Name}},@{N='Driver';E={$_.DriverVersion}} | Format-Table | Out-String }
                'Win32_OperatingSystem' { Get-CimInstance $class | Select-Object @{N='Windows';E={$_.Caption}},@{N='RAM trống (MB)';E={[math]::Round($_.FreePhysicalMemory/1KB)}},@{N='Tổng RAM (MB)';E={[math]::Round($_.TotalVisibleMemorySize/1KB)}} | Format-Table | Out-String }
                'Win32_ComputerSystem' { Get-CimInstance $class | Select-Object @{N='Bộ nhớ ảo tự quản lý';E={if ($null -eq $_.AutomaticManagedPagefile) {'Không rõ'} elseif ($_.AutomaticManagedPagefile) {'Bật'} else {'Tắt'}}} | Format-Table | Out-String }
                'Win32_LogicalDisk' { Get-CimInstance $class -Filter 'DriveType=3' | Select-Object @{N='Ổ đĩa';E={$_.DeviceID}},@{N='Trống (GB)';E={[math]::Round($_.FreeSpace/1GB,1)}} | Format-Table | Out-String }
            }
        } catch { 'Không đọc được: '+$class+' - '+$_.Exception.Message }
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
    '20 mẫu CPU/RAM. Có thể bỏ lỡ cú khựng ngắn; không đo FPS, nhiệt độ hay mức tải GPU.'
    $samples | Format-Table @{N='Thời gian';E={$_.Time}},@{N='CPU (%)';E={$_.CPU}},@{N='RAM trống (MB)';E={$_.FreeRAM_MB}} -AutoSize | Out-String
    $stats=$samples | Measure-Object CPU -Average -Maximum
    ('CPU trung bình: {0:N1}%; cao nhất: {1:N1}%' -f $stats.Average,$stats.Maximum)
    'RAM trống thấp nhất (MB): '+($samples | Measure-Object FreeRAM_MB -Minimum).Minimum
    'CPU gần 95–100% hoặc RAM trống thấp là dấu hiệu cần kiểm tra thêm, chưa khẳng định nguyên nhân. Đóng công cụ khi chơi bình thường.'
}
function NetworkReport {
    $targets=@('1.1.1.1')
    try { $r=Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' | Where-Object {$_.NextHop -ne '0.0.0.0'} | Sort-Object RouteMetric | Select-Object -First 1; if ($r) { $targets=@($r.NextHop)+$targets } } catch { 'Không đọc được gateway; chỉ kiểm tra địa chỉ công cộng.' }
    $p=New-Object Net.NetworkInformation.Ping
    try {
        foreach ($target in $targets) {
            $ok=@(for ($i=0;$i -lt 8;$i++) { if ($i) { Start-Sleep -Milliseconds 250 }; try { $r=$p.Send([string]$target,800); if ($r.Status -eq 'Success') { [double]$r.RoundtripTime } } catch {} })
            "Địa chỉ: $target; phản hồi: $($ok.Count)/8; không phản hồi: $([math]::Round(100*(8-$ok.Count)/8,1))%"
            if ($ok.Count) { $stats=$ok | Measure-Object -Average -Minimum -Maximum; ('Độ trễ (ms): thấp nhất {0:N1}; trung bình {1:N1}; cao nhất {2:N1}' -f $stats.Minimum,$stats.Average,$stats.Maximum) } else { 'Không có phản hồi ICMP; có thể giao thức này bị chặn.' }
        }
    } finally { $p.Dispose() }
    'Chỉ đo ICMP đến gateway và Cloudflare, không phải server game. Thiếu phản hồi chưa chứng minh game mất gói. Chưa đổi thiết lập mạng.'
}

function DashboardData([string]$Drive = $env:SystemDrive) {
    $data=[ordered]@{CapturedAt=[DateTime]::Now;CpuName=$null;CpuLoad=$null;TotalRamGB=$null;UsedRamGB=$null;GpuName=$null;GpuDriver=$null;DiskName=$null;FreeDiskGB=$null;TotalDiskGB=$null}
    try { $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1; if ($cpu) { $data.CpuName=[string]$cpu.Name } } catch {}
    try { $load=Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"; if ($null -ne $load -and $null -ne $load.PercentProcessorTime) { $value=[double]$load.PercentProcessorTime; if ($value -ge 0 -and $value -le 100) { $data.CpuLoad=$value } } } catch {}
    try {
        $os=Get-CimInstance Win32_OperatingSystem
        if ($os -and $os.TotalVisibleMemorySize -gt 0 -and $null -ne $os.FreePhysicalMemory -and $os.FreePhysicalMemory -ge 0 -and $os.FreePhysicalMemory -le $os.TotalVisibleMemorySize) { $data.TotalRamGB=[math]::Round($os.TotalVisibleMemorySize/1MB,1); $data.UsedRamGB=[math]::Round(($os.TotalVisibleMemorySize-$os.FreePhysicalMemory)/1MB,1) }
    } catch {}
    try { $gpu=@(Get-CimInstance Win32_VideoController); if ($gpu.Count) { $data.GpuName=($gpu | ForEach-Object {$_.Name}) -join ' / '; $data.GpuDriver=($gpu | ForEach-Object {$_.DriverVersion} | Select-Object -Unique) -join ' / ' } } catch {}
    try {
        $disk=Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Where-Object {$_.DeviceID -eq $Drive} | Select-Object -First 1
        if ($disk -and $disk.Size -gt 0 -and $null -ne $disk.FreeSpace -and $disk.FreeSpace -ge 0 -and $disk.FreeSpace -le $disk.Size) { $data.DiskName=$disk.DeviceID; $data.TotalDiskGB=[math]::Round($disk.Size/1GB,1); $data.FreeDiskGB=[math]::Round($disk.FreeSpace/1GB,1) }
    } catch {}
    return [pscustomobject]$data
}
function DarkTitle($Window) {
    try {
        if (-not ('PCTunerWindowTheme' -as [type])) { Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class PCTunerWindowTheme { [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size); }' }
        $enabled=1; $null=[PCTunerWindowTheme]::DwmSetWindowAttribute($Window.Handle,20,[ref]$enabled,4)
    } catch { }
}
function UiFont([float]$Size=10,[bool]$Bold=$false) {
    $key="$Size|$Bold"
    if (-not $script:UiFonts.ContainsKey($key)) { $style=[Drawing.FontStyle]::Regular; if ($Bold) { $style=[Drawing.FontStyle]::Bold }; $script:UiFonts[$key]=[Drawing.Font]::new('Segoe UI',$Size,$style) }
    return $script:UiFonts[$key]
}
function UiLabel([string]$Text,[float]$Size=10,[string]$Color='Text',[bool]$Bold=$false) {
    $c=New-Object Windows.Forms.Label; $c.Text=$Text; $c.Dock='Fill'; $c.Margin=[Windows.Forms.Padding]::new(0); $c.AutoEllipsis=$true; $c.TextAlign='MiddleLeft'; $c.ForeColor=$script:Theme[$Color]; $c.Font=UiFont $Size $Bold
    return $c
}
function UiPanel([int]$Padding=16) {
    $p=New-Object Windows.Forms.Panel; $p.Dock='Fill'; $p.BackColor=$script:Theme.Surface; $p.Padding=[Windows.Forms.Padding]::new($Padding); $p.Margin=[Windows.Forms.Padding]::new(0,0,12,12)
    $p.Add_Paint({ param($s,$e) $pen=[Drawing.Pen]::new($script:Theme.Border); try { $e.Graphics.DrawRectangle($pen,0,0,[math]::Max(0,$s.ClientSize.Width-1),[math]::Max(0,$s.ClientSize.Height-1)) } finally { $pen.Dispose() } })
    return $p
}
function UiButton([string]$Tag,[bool]$Primary=$false) {
    $b=New-Object Windows.Forms.Button; $b.Tag=$Tag; $b.Text=$script:Labels[$Tag]; $b.Dock='Fill'; $b.Width=172; $b.Height=42; $b.Margin=[Windows.Forms.Padding]::new(0,0,10,0); $b.Font=UiFont 10 $true; $b.Cursor='Hand'; $b.FlatStyle='Flat'; $b.FlatAppearance.BorderSize=1; $b.FlatAppearance.BorderColor=$script:Theme.Border; $b.UseVisualStyleBackColor=$false
    $b.BackColor=$script:Theme.Surface2; $b.ForeColor=$script:Theme.Text; $b.FlatAppearance.MouseOverBackColor=$script:Theme.Hover; $b.FlatAppearance.MouseDownBackColor=$script:Theme.Border
    if ($Primary) { $b.BackColor=$script:Theme.Accent; $b.ForeColor=$script:Theme.Background; $b.FlatAppearance.BorderSize=0; $b.FlatAppearance.MouseOverBackColor=$script:Theme.AccentHover; $b.FlatAppearance.MouseDownBackColor=$script:Theme.AccentDark }
    $b.Add_Click({ Invoke-ProAction $this.Tag }); $script:Buttons+=,$b
    return $b
}
function SetUiStatus([string]$Text,[bool]$Busy=$false) {
    $script:StatusText.Text=$Text; $script:StatusText.ForeColor=$script:Theme.Muted
    foreach ($b in $script:Buttons) { $b.Enabled=-not $Busy }
    if ($Busy) { $script:Progress.Style='Marquee'; $script:StatusText.ForeColor=$script:Theme.Blue }
    else { $script:Progress.Style='Blocks'; $script:Progress.Value=0 }
}
function ShowUiResult([string]$Text,[bool]$ErrorState=$false) {
    $script:Output.Text=$Text; $script:Output.ForeColor=$script:Theme.Text
    if ($ErrorState) { $script:Output.ForeColor=$script:Theme.Danger }
}
function UpdateBackupState {
    $script:SettingsState.Text='Thiết lập: chưa có bản sao lưu'; $script:SettingsState.ForeColor=$script:Theme.Muted
    if (Test-Path -LiteralPath $script:Backup) { $script:SettingsState.Text='Thiết lập: tìm thấy tệp sao lưu'; $script:SettingsState.ForeColor=$script:Theme.Warning }
    $script:StartupState.Text='Khởi động: chưa có bản sao lưu'; $script:StartupState.ForeColor=$script:Theme.Muted
    if (Test-Path -LiteralPath $script:StartupFile) { $script:StartupState.Text='Khởi động: tìm thấy tệp sao lưu'; $script:StartupState.ForeColor=$script:Theme.Warning }
}
function UpdateDashboard($Data) {
    if ($null -eq $Data) { return }
    $script:SnapshotTime.Text='Lần kiểm tra: '+$Data.CapturedAt.ToString('HH:mm:ss dd/MM/yyyy')+' • Dữ liệu tại thời điểm quét'
    $script:CpuValue.Text='—'; $script:CpuDetail.Text='Chưa đọc được dữ liệu CPU'
    if ($null -ne $Data.CpuLoad) { $script:CpuValue.Text=('{0:N0}%' -f $Data.CpuLoad) }
    if ($Data.CpuName) { $script:CpuDetail.Text=$Data.CpuName }
    $script:RamValue.Text='—'; $script:RamDetail.Text='Chưa đọc được dữ liệu RAM'
    if ($null -ne $Data.TotalRamGB -and $null -ne $Data.UsedRamGB) { $script:RamValue.Text=('{0:N1} / {1:N1} GB' -f $Data.UsedRamGB,$Data.TotalRamGB); $script:RamDetail.Text='RAM đã dùng / tổng RAM' }
    $script:GpuValue.Text='—'; $script:GpuDetail.Text='Chưa đọc được card đồ họa'
    if ($Data.GpuName) { $script:GpuValue.Text=$Data.GpuName; $script:GpuDetail.Text='Driver: '+$Data.GpuDriver }
    $script:DiskValue.Text='—'; $script:DiskDetail.Text='Chưa đọc được ổ Windows'
    if ($null -ne $Data.FreeDiskGB) { $script:DiskValue.Text=('{0:N1} GB trống' -f $Data.FreeDiskGB); $script:DiskDetail.Text=('Ổ {0} • Tổng {1:N1} GB' -f $Data.DiskName,$Data.TotalDiskGB) }
}
function ShowPage([string]$Name) {
    foreach ($key in $script:Pages.Keys) { $script:Pages[$key].Visible=$key -eq $Name }
    $script:Pages[$Name].BringToFront(); $script:PageTitle.Text=$script:PageNames[$Name][0]; $script:PageSubtitle.Text=$script:PageNames[$Name][1]
    foreach ($button in $script:NavButtons) { $button.BackColor=$script:Theme.Sidebar; $button.ForeColor=$script:Theme.Muted; if ($button.Tag -eq $Name) { $button.BackColor=$script:Theme.AccentDark; $button.ForeColor=$script:Theme.Accent } }
}
function ConfirmAction([string]$Text) {
    $dialog=New-Object Windows.Forms.Form; $dialog.Text='Xác nhận thay đổi'; $dialog.Width=640; $dialog.Height=290; $dialog.StartPosition='CenterParent'; $dialog.FormBorderStyle='FixedDialog'; $dialog.MaximizeBox=$false; $dialog.MinimizeBox=$false; $dialog.BackColor=$script:Theme.Background; $dialog.Font=UiFont 10
    $message=UiLabel $Text 11; $message.Dock='None'; $message.SetBounds(24,20,580,155); $dialog.Controls.Add($message)
    $yes=New-Object Windows.Forms.Button; $yes.Text='Đồng ý'; $yes.SetBounds(322,190,132,38); $yes.DialogResult='Yes'; $yes.FlatStyle='Flat'; $yes.BackColor=$script:Theme.Accent; $yes.ForeColor=$script:Theme.Background; $dialog.Controls.Add($yes)
    $cancel=New-Object Windows.Forms.Button; $cancel.Text='Hủy'; $cancel.SetBounds(468,190,132,38); $cancel.DialogResult='Cancel'; $cancel.FlatStyle='Flat'; $cancel.BackColor=$script:Theme.Surface2; $cancel.ForeColor=$script:Theme.Text; $dialog.Controls.Add($cancel)
    $dialog.AcceptButton=$cancel; $dialog.CancelButton=$cancel; $dialog.ActiveControl=$cancel
    DarkTitle $dialog
    try { return $dialog.ShowDialog($script:Form) -eq 'Yes' } finally { $dialog.Dispose() }
}
function StartupWindow {
    $entries=@(StartupEntries); if (-not $entries.Count) { throw 'Không tìm thấy mục khởi động phù hợp của tài khoản hiện tại.' }
    $d=New-Object Windows.Forms.Form; $d.Text='Ứng dụng khởi động'; $d.Size=[Drawing.Size]::new(960,540); $d.MinimumSize=[Drawing.Size]::new(760,420); $d.StartPosition='CenterParent'; $d.BackColor=$script:Theme.Background; $d.Font=UiFont 10
    $layout=New-Object Windows.Forms.TableLayoutPanel; $layout.Dock='Fill'; $layout.Padding=[Windows.Forms.Padding]::new(22); $layout.RowCount=3; $layout.ColumnCount=1
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',88)); [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',60)); $d.Controls.Add($layout)
    $label=UiLabel 'Chỉ chọn ứng dụng bạn biết và không cần khi đăng nhập. Một số tên driver, bảo mật và Riot được ẩn. Không đóng ứng dụng đang chạy; không sửa dịch vụ hoặc tác vụ định kỳ.' 11; $layout.Controls.Add($label,0,0)
    $list=New-Object Windows.Forms.CheckedListBox; $list.Dock='Fill'; $list.HorizontalScrollbar=$true; $list.CheckOnClick=$true; $list.BackColor=$script:Theme.Surface; $list.ForeColor=$script:Theme.Text; $list.BorderStyle='None'; $list.Font=UiFont 10
    foreach ($entry in $entries) { [void]$list.Items.Add($entry.Name+' | '+$entry.Value) }; $layout.Controls.Add($list,0,1)
    $bottom=New-Object Windows.Forms.FlowLayoutPanel; $bottom.Dock='Fill'; $bottom.Padding=[Windows.Forms.Padding]::new(0,14,0,0); $layout.Controls.Add($bottom,0,2)
    $apply=New-Object Windows.Forms.Button; $apply.Text='Sao lưu và tắt mục đã chọn'; $apply.Size=[Drawing.Size]::new(300,38); $apply.DialogResult='OK'; $apply.FlatStyle='Flat'; $apply.BackColor=$script:Theme.Accent; $apply.ForeColor=$script:Theme.Background; $bottom.Controls.Add($apply)
    $cancel=New-Object Windows.Forms.Button; $cancel.Text='Đóng'; $cancel.Size=[Drawing.Size]::new(100,38); $cancel.DialogResult='Cancel'; $cancel.FlatStyle='Flat'; $cancel.ForeColor=$script:Theme.Text; $bottom.Controls.Add($cancel); $d.CancelButton=$cancel
    DarkTitle $d
    try {
        if ($d.ShowDialog($script:Form) -eq 'OK') {
            $selected=@($list.CheckedIndices | ForEach-Object { $entries[[int]$_] }); if (-not $selected.Count) { return }
            if (ConfirmAction "Sao lưu rồi tắt $($selected.Count) ứng dụng khởi động đã chọn?") { ShowUiResult (StartupChange $false $selected $script:StartupFile) }
        }
    } finally { $d.Dispose() }
}
function Invoke-ProAction([string]$Tag) {
    try {
        switch ($Tag) {
            'Scan' { StartReport 'HealthReport' }
            'CPU/RAM 20s' { StartReport 'LoadReport' }
            'Network' { StartReport 'NetworkReport' }
            'Startup apps' { StartupWindow }
            'Undo startup' { if (ConfirmAction 'Khôi phục các mục khởi động đã sao lưu? Công cụ sẽ dừng nếu có mục mới bị xung đột.') { ShowUiResult (StartupChange $true @() $script:StartupFile); SetUiStatus 'Đã khôi phục lựa chọn khởi động.' } }
            'Keep app' { ShowUiResult (InstallPro); SetUiStatus 'Đã lưu ứng dụng vào một thư mục mới trên Desktop.' }
            'Save report' {
                $save=New-Object Windows.Forms.SaveFileDialog; $save.Title='Lưu báo cáo PC Tuner'; $save.Filter='Tệp văn bản (*.txt)|*.txt'; $save.FileName='Bao-cao-PC.txt'
                try { if ($save.ShowDialog($script:Form) -eq 'OK') { [IO.File]::WriteAllText($save.FileName,$script:Output.Text,[Text.UTF8Encoding]::new($true)); SetUiStatus 'Đã lưu báo cáo trên máy.' } } finally { $save.Dispose() }
            }
            default {
                $mode=$Tag; if ($mode -eq 'Undo settings') { $mode='Restore' }
                $text=switch ($mode) {
                    'Daily' { 'Giảm hiệu ứng trong suốt và hoạt ảnh thanh tác vụ. Giữ chế độ nguồn điện và Game DVR. Đóng game trước. Sao lưu rồi áp dụng?' }
                    'Gaming' { 'Giảm hiệu ứng, tắt Game DVR, chọn Hiệu năng cao nếu có; có thể tăng nhiệt và điện năng. Đóng game trước. Sao lưu rồi áp dụng?' }
                    'Restore' { 'Đóng game trước. Khôi phục các thiết lập ban đầu từ bản sao lưu?' }
                    default { throw 'Chức năng không được hỗ trợ.' }
                }
                if (ConfirmAction $text) { ShowUiResult (Tune $mode $script:Backup); SetUiStatus 'Hoàn tất. Đăng xuất và đăng nhập lại Windows để áp dụng đầy đủ.' }
            }
        }
    } catch { ShowUiResult ($_.Exception.Message+"`r`nGiữ các bản sao lưu. Nếu thay đổi bị dở dang, dùng nút Hoàn tác tương ứng.") $true; SetUiStatus 'Chưa hoàn tất — xem chi tiết ở khung kết quả.' }
    finally { UpdateBackupState }
}
function StartReport($Task) {
    if ($null -ne $script:Job) { return }
    if ($Task -notin @('HealthReport','LoadReport','NetworkReport')) { throw 'Loại báo cáo không được hỗ trợ.' }
    $defs=@('Power','Active','AppReport','HealthReport','LoadReport','NetworkReport','DashboardData') | ForEach-Object { 'function '+$_+' {'+(Get-Command $_).Definition+'}' }
    $lib='$ErrorActionPreference="Stop";'+($defs -join "`n")
    ShowUiResult 'Đang lấy dữ liệu thực tế… Tác vụ chạy riêng để bạn tiếp tục dùng cửa sổ.'; SetUiStatus 'Đang xử lý • Chỉ đo khi bạn yêu cầu.' $true
    try {
        $script:Job=Start-Job -ArgumentList $lib,$Task -ScriptBlock {
            param($Lib,$Task)
            . ([scriptblock]::Create($Lib))
            $text=& $Task | Out-String -Width 150; $data=$null
            if ($Task -eq 'HealthReport') { $data=DashboardData }
            [pscustomobject]@{Text=$text;Dashboard=$data}
        }
        $script:Timer.Start()
    } catch { SetUiStatus 'Không khởi chạy được báo cáo.'; throw }
}
function NewMetricCard($Title,[ref]$Value,[ref]$Detail,[float]$ValueSize=20) {
    $p=UiPanel 16; $layout=New-Object Windows.Forms.TableLayoutPanel; $layout.Dock='Fill'; $layout.ColumnCount=1; $layout.RowCount=3
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',24)); [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',36)); $p.Controls.Add($layout)
    $layout.Controls.Add((UiLabel $Title 9 'Muted' $true),0,0); $Value.Value=UiLabel '—' $ValueSize 'Text' $true; $layout.Controls.Add($Value.Value,0,1)
    $Detail.Value=UiLabel 'Chọn Kiểm tra máy để lấy dữ liệu' 9 'Muted'; $layout.Controls.Add($Detail.Value,0,2)
    return $p
}
function OverviewPage {
    $page=New-Object Windows.Forms.TableLayoutPanel; $page.Dock='Fill'; $page.RowCount=2; $page.ColumnCount=1; $page.Margin=[Windows.Forms.Padding]::new(0)
    [void]$page.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',136)); [void]$page.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100))
    $cards=New-Object Windows.Forms.TableLayoutPanel; $cards.Dock='Fill'; $cards.ColumnCount=4; $cards.RowCount=1; $cards.Margin=[Windows.Forms.Padding]::new(0)
    for ($i=0;$i -lt 4;$i++) { [void]$cards.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',25)) }
    $cards.Controls.Add((NewMetricCard 'CPU • TẢI LÚC QUÉT' ([ref]$script:CpuValue) ([ref]$script:CpuDetail)),0,0)
    $cards.Controls.Add((NewMetricCard 'BỘ NHỚ RAM' ([ref]$script:RamValue) ([ref]$script:RamDetail)),1,0)
    $cards.Controls.Add((NewMetricCard 'CARD ĐỒ HỌA' ([ref]$script:GpuValue) ([ref]$script:GpuDetail) 12),2,0)
    $cards.Controls.Add((NewMetricCard 'Ổ ĐĨA WINDOWS' ([ref]$script:DiskValue) ([ref]$script:DiskDetail) 17),3,0); $page.Controls.Add($cards,0,0)
    $p=UiPanel 16; $grid=New-Object Windows.Forms.TableLayoutPanel; $grid.Dock='Fill'; $grid.RowCount=3; $grid.ColumnCount=1
    [void]$grid.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',32)); [void]$grid.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); [void]$grid.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',42)); $p.Controls.Add($grid)
    $grid.Controls.Add((UiLabel 'Hiểu rõ máy trước khi tối ưu' 16 'Text' $true),0,0)
    $script:SnapshotTime=UiLabel 'Chưa có lần kiểm tra nào. Các thẻ phía trên chưa phải số liệu thực tế.' 9 'Muted'; $grid.Controls.Add($script:SnapshotTime,0,1)
    $actions=New-Object Windows.Forms.FlowLayoutPanel; $actions.Dock='Fill'; $actions.WrapContents=$false
    foreach ($tag in @('Scan','CPU/RAM 20s','Network')) { $b=UiButton $tag ($tag -eq 'Scan'); $b.Dock='None'; $actions.Controls.Add($b) }
    $grid.Controls.Add($actions,0,2); $page.Controls.Add($p,0,1)
    return $page
}
function ProfilesPage {
    $page=New-Object Windows.Forms.TableLayoutPanel; $page.Dock='Fill'; $page.RowCount=2; $page.ColumnCount=1; $page.Margin=[Windows.Forms.Padding]::new(0)
    [void]$page.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); [void]$page.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',76))
    $profiles=New-Object Windows.Forms.TableLayoutPanel; $profiles.Dock='Fill'; $profiles.ColumnCount=2; $profiles.Margin=[Windows.Forms.Padding]::new(0)
    [void]$profiles.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',50)); [void]$profiles.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',50))
    $index=0
    foreach ($tag in @('Daily','Gaming')) {
        $card=UiPanel 18; $layout=New-Object Windows.Forms.TableLayoutPanel; $layout.Dock='Fill'; $layout.RowCount=3; $layout.ColumnCount=1
        [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',36)); [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',42))
        $layout.Controls.Add((UiLabel $script:Labels[$tag] 18 'Text' $true),0,0)
        $description="Giảm hiệu ứng trong suốt và hoạt ảnh thanh tác vụ.`r`nGiữ chế độ nguồn điện và khả năng ghi hình."
        if ($tag -eq 'Gaming') { $description="Thêm tắt Game DVR và ưu tiên nguồn hiệu năng cao nếu có.`r`nCó thể tăng nhiệt và điện năng; không bảo đảm tăng FPS." }
        $layout.Controls.Add((UiLabel $description 10 'Muted'),0,1); $layout.Controls.Add((UiButton $tag ($tag -eq 'Gaming')),0,2); $card.Controls.Add($layout); $profiles.Controls.Add($card,$index,0); $index++
    }
    $page.Controls.Add($profiles,0,0)
    $restore=UiPanel 12; $row=New-Object Windows.Forms.TableLayoutPanel; $row.Dock='Fill'; $row.ColumnCount=2; [void]$row.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',100)); [void]$row.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Absolute',190))
    $row.Controls.Add((UiLabel 'Muốn đổi chế độ? Hoàn tác bản đang dùng trước.' 10 'Muted'),0,0); $row.Controls.Add((UiButton 'Undo settings'),1,0); $restore.Controls.Add($row); $page.Controls.Add($restore,0,1)
    return $page
}
function StartupPage {
    $page=New-Object Windows.Forms.TableLayoutPanel; $page.Dock='Fill'; $page.ColumnCount=2; $page.Margin=[Windows.Forms.Padding]::new(0)
    [void]$page.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',55)); [void]$page.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',45))
    $index=0
    foreach ($tag in @('Startup apps','Undo startup')) {
        $p=UiPanel 20; $grid=New-Object Windows.Forms.TableLayoutPanel; $grid.Dock='Fill'; $grid.RowCount=3; $grid.ColumnCount=1
        [void]$grid.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',64)); [void]$grid.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); [void]$grid.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',42))
        $title='Bớt ứng dụng tự mở'; $detail='Tự chọn các mục bạn nhận ra. Công cụ sao lưu trước khi tắt ở lần đăng nhập sau; không đóng ứng dụng đang chạy.'
        if ($tag -eq 'Undo startup') { $title='Khôi phục lựa chọn'; $detail='Dùng bản sao lưu để bật lại các mục đã chọn. Công cụ sẽ dừng nếu mục đó đã bị thay đổi để tránh ghi đè.' }
        $grid.Controls.Add((UiLabel $title 19 'Text' $true),0,0); $grid.Controls.Add((UiLabel $detail 11 'Muted'),0,1); $grid.Controls.Add((UiButton $tag ($tag -eq 'Startup apps')),0,2); $p.Controls.Add($grid); $page.Controls.Add($p,$index,0); $index++
    }
    return $page
}
function DiagnosticsPage {
    $page=New-Object Windows.Forms.TableLayoutPanel; $page.Dock='Fill'; $page.ColumnCount=3; $page.Margin=[Windows.Forms.Padding]::new(0)
    for ($i=0;$i -lt 3;$i++) { [void]$page.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',33.333)) }
    $titles=@('Cấu hình và ứng dụng','Theo dõi cú khựng','Kiểm tra kết nối')
    $details=@('Đọc cấu hình, driver, ổ đĩa và ứng dụng dùng nhiều CPU/RAM. Không tự đóng ứng dụng.','Lấy 20 mẫu CPU/RAM. Có thể bỏ lỡ đỉnh rất ngắn; không đo FPS hay nhiệt độ.','Ping gateway và Cloudflare. Đây không phải đường đến server game; không tự đổi thiết lập mạng.')
    $tags=@('Scan','CPU/RAM 20s','Network')
    for ($i=0;$i -lt 3;$i++) {
        $p=UiPanel 18; $grid=New-Object Windows.Forms.TableLayoutPanel; $grid.Dock='Fill'; $grid.RowCount=3; $grid.ColumnCount=1
        [void]$grid.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',64)); [void]$grid.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); [void]$grid.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',42))
        $grid.Controls.Add((UiLabel $titles[$i] 16 'Text' $true),0,0); $grid.Controls.Add((UiLabel $details[$i] 10 'Muted'),0,1); $grid.Controls.Add((UiButton $tags[$i]),0,2); $p.Controls.Add($grid); $page.Controls.Add($p,$i,0)
    }
    return $page
}
function BuildSidebar {
    $side=New-Object Windows.Forms.Panel; $side.Dock='Fill'; $side.BackColor=$script:Theme.Sidebar; $side.Padding=[Windows.Forms.Padding]::new(18,24,18,22)
    $layout=New-Object Windows.Forms.TableLayoutPanel; $layout.Dock='Fill'; $layout.ColumnCount=1; $layout.RowCount=5
    foreach ($height in @(78,26,230)) { [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',$height)) }; [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',190)); $side.Controls.Add($layout)
    $layout.Controls.Add((UiLabel "PC TUNER`r`nPRO / 2.0" 21 'Accent' $true),0,0); $layout.Controls.Add((UiLabel 'KHÔNG GIAN LÀM VIỆC' 8 'Muted' $true),0,1)
    $nav=New-Object Windows.Forms.TableLayoutPanel; $nav.Dock='Fill'; $nav.RowCount=4; $nav.ColumnCount=1
    foreach ($name in @('Overview','Profiles','Startup','Diagnostics')) {
        $b=New-Object Windows.Forms.Button; $b.Tag=$name; $b.Text=$script:PageNames[$name][0]; $b.Dock='Fill'; $b.TextAlign='MiddleLeft'; $b.Padding=[Windows.Forms.Padding]::new(12,0,0,0); $b.Font=UiFont 11 $true; $b.FlatStyle='Flat'; $b.FlatAppearance.BorderSize=0; $b.Margin=[Windows.Forms.Padding]::new(0,0,0,8); $b.Cursor='Hand'
        $b.Add_Click({ ShowPage $this.Tag }); $script:NavButtons+=,$b; $nav.Controls.Add($b)
    }
    $layout.Controls.Add($nav,0,2)
    $bottom=New-Object Windows.Forms.TableLayoutPanel; $bottom.Dock='Fill'; $bottom.RowCount=5; $bottom.ColumnCount=1
    foreach ($height in @(28,34,40,48,36)) { [void]$bottom.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',$height)) }
    $bottom.Controls.Add((UiLabel 'BẢN SAO LƯU' 8 'Muted' $true),0,0); $script:SettingsState=UiLabel '' 9 'Muted'; $bottom.Controls.Add($script:SettingsState,0,1); $script:StartupState=UiLabel '' 9 'Muted'; $bottom.Controls.Add($script:StartupState,0,2)
    $bottom.Controls.Add((UiButton 'Keep app'),0,3); $bottom.Controls.Add((UiLabel 'Chạy khi cần • Không tự khởi động' 8 'Muted'),0,4); $layout.Controls.Add($bottom,0,4)
    return $side
}
function Start-Pro {
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Ứng dụng chỉ chạy trên Windows.' }
    Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; [Windows.Forms.Application]::EnableVisualStyles()
    $script:Theme=@{Background='#0C1018';Sidebar='#111827';Surface='#182132';Surface2='#202C40';Border='#2B3951';Hover='#2A3B55';Text='#EDF4FF';Muted='#9AAEC7';Accent='#4DE1C1';AccentHover='#7DEBD4';AccentDark='#164E48';Blue='#6CA8FF';Warning='#FFD278';Danger='#FF8C9B'}
    foreach ($key in @($script:Theme.Keys)) { $script:Theme[$key]=[Drawing.ColorTranslator]::FromHtml($script:Theme[$key]) }
    $script:UiFonts=@{}; $script:Job=$null; $script:Buttons=@(); $script:NavButtons=@()
    $script:CpuValue=$null; $script:CpuDetail=$null; $script:RamValue=$null; $script:RamDetail=$null; $script:GpuValue=$null; $script:GpuDetail=$null; $script:DiskValue=$null; $script:DiskDetail=$null
    $labels=@{Scan='Kiểm tra máy'; 'CPU/RAM 20s'='Đo CPU/RAM (20 giây)'; Network='Kiểm tra mạng'; Daily='Dùng hằng ngày'; Gaming='Chơi game'; 'Undo settings'='Hoàn tác thiết lập'; 'Startup apps'='Ứng dụng khởi động'; 'Undo startup'='Hoàn tác khởi động'; 'Save report'='Lưu báo cáo'; 'Keep app'='Lưu ứng dụng'}
    $script:Labels=$labels; $script:PageNames=@{Overview=@('Tổng quan','Cấu hình và tài nguyên từ lần kiểm tra gần nhất.');Profiles=@('Tối ưu Windows','Chọn chế độ phù hợp, có sao lưu và hoàn tác.');Startup=@('Khởi động','Tự quyết định ứng dụng nào cần mở cùng Windows.');Diagnostics=@('Chẩn đoán','Đo trước khi thay đổi để tìm đúng nguyên nhân.')}
    $root=Join-Path $env:LOCALAPPDATA 'PCTuner'; $script:Backup=Join-Path $root 'backup.json'; $script:StartupFile=Join-Path $root 'startup-backup.json'; $old=Join-Path $env:LOCALAPPDATA 'ValorantPCToolkit\backup.json'; if (Test-Path -LiteralPath $old) { $script:Backup=$old }
    $script:Form=New-Object Windows.Forms.Form; $script:Form.Text='PC Tuner Pro 2.0 — Tiếng Việt'; $area=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea; $script:Form.Size=[Drawing.Size]::new([math]::Min(1280,$area.Width-32),[math]::Min(850,$area.Height-32)); $script:Form.MinimumSize=[Drawing.Size]::new([math]::Min(1000,$area.Width-32),[math]::Min(660,$area.Height-32)); $script:Form.StartPosition='CenterScreen'; $script:Form.AutoScaleMode='Dpi'; $script:Form.BackColor=$script:Theme.Background; $script:Form.Font=UiFont 10
    $shell=New-Object Windows.Forms.TableLayoutPanel; $shell.Dock='Fill'; $shell.ColumnCount=2; $shell.RowCount=1; [void]$shell.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Absolute',218)); [void]$shell.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',100)); $script:Form.Controls.Add($shell)
    $shell.Controls.Add((BuildSidebar),0,0)
    $main=New-Object Windows.Forms.TableLayoutPanel; $main.Dock='Fill'; $main.Padding=[Windows.Forms.Padding]::new(24,18,24,14); $main.ColumnCount=1; $main.RowCount=4
    [void]$main.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',76)); [void]$main.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',304)); [void]$main.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); [void]$main.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',42)); $shell.Controls.Add($main,1,0)
    $header=New-Object Windows.Forms.TableLayoutPanel; $header.Dock='Fill'; $header.RowCount=2; $header.ColumnCount=1; [void]$header.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',42)); [void]$header.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100))
    $script:PageTitle=UiLabel 'Tổng quan' 25 'Text' $true; $script:PageSubtitle=UiLabel '' 10 'Muted'; $header.Controls.Add($script:PageTitle,0,0); $header.Controls.Add($script:PageSubtitle,0,1); $main.Controls.Add($header,0,0)
    $holder=New-Object Windows.Forms.Panel; $holder.Dock='Fill'; $script:Pages=@{Overview=(OverviewPage);Profiles=(ProfilesPage);Startup=(StartupPage);Diagnostics=(DiagnosticsPage)}
    foreach ($page in $script:Pages.Values) { $holder.Controls.Add($page) }; $main.Controls.Add($holder,0,1)
    $console=UiPanel 16; $console.Margin=[Windows.Forms.Padding]::new(0); $grid=New-Object Windows.Forms.TableLayoutPanel; $grid.Dock='Fill'; $grid.RowCount=2; $grid.ColumnCount=2
    [void]$grid.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',44)); [void]$grid.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); [void]$grid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',100)); [void]$grid.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Absolute',150))
    $grid.Controls.Add((UiLabel 'KẾT QUẢ GẦN NHẤT' 9 'Muted' $true),0,0); $save=UiButton 'Save report'; $save.Margin=[Windows.Forms.Padding]::new(0,0,0,8); $grid.Controls.Add($save,1,0)
    $script:Output=New-Object Windows.Forms.RichTextBox; $script:Output.Dock='Fill'; $script:Output.ReadOnly=$true; $script:Output.BorderStyle='None'; $script:Output.BackColor=$script:Theme.Surface; $script:Output.ForeColor=$script:Theme.Text; $script:Output.Font=[Drawing.Font]::new('Consolas',10); $script:Output.DetectUrls=$false; $script:Output.WordWrap=$false; $script:Output.ScrollBars='Both'
    $script:Output.Text="Chọn Kiểm tra máy để lấy cấu hình thực tế.`r`nCác thẻ hiển thị dữ liệu của lần quét, không phải số liệu theo dõi liên tục.`r`nTối ưu không bảo đảm tăng FPS. Đóng game trước khi áp dụng thiết lập."; $grid.Controls.Add($script:Output,0,1); $grid.SetColumnSpan($script:Output,2); $console.Controls.Add($grid); $main.Controls.Add($console,0,2)
    $footer=New-Object Windows.Forms.TableLayoutPanel; $footer.Dock='Fill'; $footer.ColumnCount=2; [void]$footer.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',100)); [void]$footer.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Absolute',150))
    $script:StatusText=UiLabel 'Sẵn sàng • Không có tác vụ theo dõi thường trực.' 9 'Muted'; $footer.Controls.Add($script:StatusText,0,0); $script:Progress=New-Object Windows.Forms.ProgressBar; $script:Progress.Dock='Bottom'; $script:Progress.Height=7; $script:Progress.Margin=[Windows.Forms.Padding]::new(0,0,0,12); $footer.Controls.Add($script:Progress,1,0); $main.Controls.Add($footer,0,3)
    $script:Timer=New-Object Windows.Forms.Timer; $script:Timer.Interval=300
    $script:Timer.Add_Tick({
        if ($null -eq $script:Job -or $script:Job.State -in @('Running','NotStarted')) { return }; $script:Timer.Stop()
        try {
            $result=@(Receive-Job $script:Job -ErrorAction Stop)
            if ($script:Job.State -ne 'Completed' -or $result.Count -ne 1) { throw 'Báo cáo chưa hoàn tất.' }
            ShowUiResult $result[0].Text; UpdateDashboard $result[0].Dashboard; SetUiStatus 'Đã cập nhật kết quả • Đóng công cụ khi chơi bình thường.'
        } catch { ShowUiResult ('Báo cáo chưa hoàn tất: '+$_.Exception.Message) $true; SetUiStatus 'Không lấy đủ dữ liệu — xem chi tiết ở trên.' }
        finally { Remove-Job $script:Job -Force; $script:Job=$null; UpdateBackupState }
    })
    $script:Form.Add_FormClosing({ param($s,$e) if ($null -ne $script:Job) { $e.Cancel=$true; [void][Windows.Forms.MessageBox]::Show('Hãy chờ báo cáo hoàn tất rồi đóng. Công cụ không cài theo dõi thường trực.','PC Tuner Pro') } })
    $script:Form.Add_Shown({ DarkTitle $script:Form; try { StartReport 'HealthReport' } catch { ShowUiResult $_.Exception.Message $true; SetUiStatus 'Chưa kiểm tra được máy.' } })
    ShowPage 'Overview'; UpdateBackupState
    try { [void]$script:Form.ShowDialog() } finally { $script:Timer.Dispose(); $mono=$script:Output.Font; $script:Form.Dispose(); $mono.Dispose(); foreach ($font in $script:UiFonts.Values) { $font.Dispose() } }
}
Start-Pro
