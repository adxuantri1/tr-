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
    $names=@('UserID','Power','Active','Plan','ReadValue','WriteValue','Tune','ReadStartup','StartupEntries','StartupChange','ExportProText','ProLauncherText','InstallPro','AppReport','HealthReport','LoadReport','NetworkReport','DashboardData','DarkTitle','UiFont','UiLabel','UiPanel','UiButton','SetUiStatus','ShowUiResult','UpdateBackupState','UpdateDashboard','ShowPage','ConfirmAction','StartupWindow','Invoke-ProAction','StartReport','NewMetricCard','OverviewPage','ProfilesPage','StartupPage','DiagnosticsPage','BuildSidebar','Start-Pro')
    $defs=$names | ForEach-Object { 'function '+$_+' {'+(Get-Command $_ -CommandType Function).Definition+'}' }
    return $head+"`n"+($defs -join "`n")+"`nStart-Pro`n"
}
function ProLauncherText {
    $lines=@('@echo off','setlocal','cd /d "%~dp0"','if not exist "%~dp0PC-Tuner-Pro.ps1" (','echo Khong thay PC-Tuner-Pro.ps1. Hay giai nen toan bo goi vao cung thu muc.','pause >nul','exit /b 1',')','"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0PC-Tuner-Pro.ps1"','set "PC_TUNER_EXIT=%ERRORLEVEL%"','if not "%PC_TUNER_EXIT%"=="0" (','echo Khong mo duoc ung dung. Xem loi phia tren.','echo Nhan phim bat ky de dong.','pause >nul',')','exit /b %PC_TUNER_EXIT%')
    return ($lines -join "`r`n")+"`r`n"
}
function InstallPro([string]$desktop = [Environment]::GetFolderPath('Desktop')) {
    if (-not $desktop) { throw 'Không tìm thấy thư mục Desktop.' }
    $folder=Join-Path $desktop ('PC-Tuner-Pro-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    $null=New-Item -ItemType Directory -Path $folder
    [IO.File]::WriteAllText((Join-Path $folder 'PC-Tuner-Pro.ps1'),(ExportProText),[Text.UTF8Encoding]::new($true))
    [IO.File]::WriteAllText((Join-Path $folder 'START.cmd'),(ProLauncherText),[Text.Encoding]::ASCII)
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
