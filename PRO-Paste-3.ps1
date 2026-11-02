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
function StartupWindow {
    $entries=@(StartupEntries)
    if (-not $entries.Count) { throw 'Không tìm thấy mục khởi động phù hợp của tài khoản hiện tại.' }
    $d=New-Object Windows.Forms.Form; $d.Text='Ứng dụng khởi động — tài khoản hiện tại'; $d.Width=800; $d.Height=420; $d.StartPosition='CenterScreen'
    $label=New-Object Windows.Forms.Label; $label.SetBounds(15,10,750,55)
    $label.Text='Chỉ chọn ứng dụng bạn biết và không cần khi đăng nhập. Một số tên driver, bảo mật và Riot được ẩn. Không đóng ứng dụng đang chạy; không sửa thư mục Startup, dịch vụ hay tác vụ định kỳ.'
    $d.Controls.Add($label)
    $list=New-Object Windows.Forms.CheckedListBox; $list.SetBounds(15,70,750,240); $list.HorizontalScrollbar=$true
    foreach ($entry in $entries) { [void]$list.Items.Add($entry.Name+' | '+$entry.Value) }; $d.Controls.Add($list)
    $apply=New-Object Windows.Forms.Button; $apply.Text='Sao lưu và tắt mục đã chọn'; $apply.SetBounds(15,320,300,40); $apply.DialogResult='OK'; $d.Controls.Add($apply)
    try {
        if ($d.ShowDialog() -eq 'OK') {
            $selected=@($list.CheckedIndices | ForEach-Object { $entries[[int]$_] })
            if (-not $selected.Count) { return }
            if ((ConfirmAction "Sao lưu rồi tắt $($selected.Count) ứng dụng khởi động đã chọn?")) { $script:Output.Text=StartupChange $false $selected $script:StartupFile }
        }
    } finally { $d.Dispose() }
}
