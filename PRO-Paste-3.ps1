
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