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
function ConfirmAction([string]$Text) {
    $dialog=New-Object Windows.Forms.Form; $dialog.Text='Xác nhận thay đổi'; $dialog.Width=620; $dialog.Height=260; $dialog.StartPosition='CenterParent'; $dialog.FormBorderStyle='FixedDialog'; $dialog.MaximizeBox=$false; $dialog.MinimizeBox=$false
    $message=New-Object Windows.Forms.Label; $message.SetBounds(20,20,560,140); $message.Text=$Text; $dialog.Controls.Add($message)
    $yes=New-Object Windows.Forms.Button; $yes.Text='Đồng ý'; $yes.SetBounds(320,170,120,35); $yes.DialogResult='Yes'; $dialog.Controls.Add($yes)
    $cancel=New-Object Windows.Forms.Button; $cancel.Text='Hủy'; $cancel.SetBounds(460,170,120,35); $cancel.DialogResult='Cancel'; $dialog.Controls.Add($cancel)
    $dialog.AcceptButton=$cancel; $dialog.CancelButton=$cancel; $dialog.ActiveControl=$cancel
    try { return $dialog.ShowDialog($script:Form) -eq 'Yes' } finally { $dialog.Dispose() }
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
    $names=@('UserID','Power','Active','Plan','ReadValue','WriteValue','Tune','ReadStartup','StartupEntries','StartupChange','ExportProText','InstallPro','AppReport','HealthReport','LoadReport','NetworkReport','ConfirmAction','StartupWindow','StartReport','Start-Pro')
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
function StartReport($Task) {
    if ($null -ne $script:Job) { return }
    $defs=@('Power','Active','AppReport','HealthReport','LoadReport','NetworkReport') | ForEach-Object { 'function '+$_+' {'+(Get-Command $_).Definition+'}' }
    $lib='$ErrorActionPreference="Stop";'+($defs -join "`n")
    $script:Output.Text='Đang xử lý… Việc đo dùng một ít CPU. Đóng công cụ khi chơi bình thường.'
    foreach ($b in $script:Buttons) { $b.Enabled=$false }
    try {
        $script:Job=Start-Job -ArgumentList $lib,$Task -ScriptBlock {
            param($Lib,$Task)
            . ([scriptblock]::Create($Lib))
            if ($Task -notin @('HealthReport','LoadReport','NetworkReport')) { throw 'Loại báo cáo không được hỗ trợ.' }; & $Task
        }
        $script:Timer.Start()
    } catch { foreach ($b in $script:Buttons) { $b.Enabled=$true }; throw }
}
function Start-Pro {
    if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'Ứng dụng chỉ chạy trên Windows.' }
    Add-Type -AssemblyName System.Windows.Forms
    $root=Join-Path $env:LOCALAPPDATA 'PCTuner'; $script:Backup=Join-Path $root 'backup.json'; $script:StartupFile=Join-Path $root 'startup-backup.json'
    $old=Join-Path $env:LOCALAPPDATA 'ValorantPCToolkit\backup.json'; if (Test-Path -LiteralPath $old) { $script:Backup=$old }
    $script:Job=$null; $script:Buttons=@()
    $script:Form=New-Object Windows.Forms.Form; $script:Form.Text='PC Tuner Pro — Tiếng Việt'; $script:Form.Width=960; $script:Form.Height=700; $script:Form.StartPosition='CenterScreen'; $script:Form.MinimumSize=[Drawing.Size]::new(800,550)
    $layout=New-Object Windows.Forms.TableLayoutPanel; $layout.Dock='Fill'; $layout.RowCount=2; $layout.ColumnCount=1
    [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',110)); [void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100)); $script:Form.Controls.Add($layout)
    $top=New-Object Windows.Forms.FlowLayoutPanel; $top.Dock='Fill'; $top.AutoScroll=$true; $layout.Controls.Add($top,0,0)
    $script:Output=New-Object Windows.Forms.RichTextBox; $script:Output.Dock='Fill'; $script:Output.ReadOnly=$true; $script:Output.Font=New-Object Drawing.Font('Consolas',10)
    $script:Output.Text="PC TUNER PRO — TIẾNG VIỆT`r`nKhông bảo đảm tăng FPS.`r`n`r`nKiểm tra máy: cấu hình, ứng dụng dùng CPU/RAM và dung lượng ổ đĩa.`r`nĐo CPU/RAM: lấy 20 mẫu khi tái hiện cú khựng; xong thì đóng công cụ.`r`nKiểm tra mạng: ping gateway và Cloudflare, không phải server game.`r`nDùng hằng ngày: giảm hiệu ứng trong suốt và hoạt ảnh thanh tác vụ.`r`nChơi game: thêm tắt Game DVR, chọn Hiệu năng cao nếu có; có thể tăng nhiệt và điện năng.`r`nHoàn tác thiết lập: khôi phục bản sao lưu gốc.`r`nỨng dụng khởi động: tự chọn mục để sao lưu và tắt ở lần đăng nhập sau.`r`nHoàn tác khởi động: khôi phục lựa chọn; dừng nếu có xung đột.`r`n`r`nĐóng game trước khi chỉnh. Đăng xuất/đăng nhập lại sau khi áp dụng hoặc hoàn tác.`r`nThư mục sao lưu: $root`r`nLưu ứng dụng: tạo thư mục dùng lại trên Desktop.`r`nBáo cáo được giữ trên máy, chỉ chia sẻ khi bạn chủ động gửi."
    $layout.Controls.Add($script:Output,0,1)
    $labels=@{Scan='Kiểm tra máy'; 'CPU/RAM 20s'='Đo CPU/RAM (20 giây)'; Network='Kiểm tra mạng'; Daily='Dùng hằng ngày'; Gaming='Chơi game'; 'Undo settings'='Hoàn tác thiết lập'; 'Startup apps'='Ứng dụng khởi động'; 'Undo startup'='Hoàn tác khởi động'; 'Save report'='Lưu báo cáo'; 'Keep app'='Lưu ứng dụng'}
    foreach ($name in @('Scan','CPU/RAM 20s','Network','Daily','Gaming','Undo settings','Startup apps','Undo startup','Save report','Keep app')) {
        $b=New-Object Windows.Forms.Button; $b.Text=$labels[$name]; $b.Tag=$name; $b.Width=170; $b.Height=40; $script:Buttons+=,$b
        $b.Add_Click({
            try {
                switch ($this.Tag) {
                    'Scan' { StartReport 'HealthReport' }
                    'CPU/RAM 20s' { StartReport 'LoadReport' }
                    'Network' { StartReport 'NetworkReport' }
                    'Startup apps' { StartupWindow }
                    'Undo startup' {
                        if ((ConfirmAction 'Khôi phục các mục khởi động đã sao lưu? Công cụ sẽ dừng nếu có mục mới bị xung đột.')) { $script:Output.Text=StartupChange $true @() $script:StartupFile }
                    }
                    'Keep app' { $script:Output.Text=InstallPro }
                    'Save report' {
                        $save=New-Object Windows.Forms.SaveFileDialog; $save.Filter='Tệp văn bản (*.txt)|*.txt'; $save.FileName='Bao-cao-PC.txt'
                        try { if ($save.ShowDialog() -eq 'OK') { [IO.File]::WriteAllText($save.FileName,$script:Output.Text,[Text.UTF8Encoding]::new($true)) } } finally { $save.Dispose() }
                    }
                    default {
                        $mode=$this.Tag; if ($mode -eq 'Undo settings') { $mode='Restore' }
                        $text=switch ($mode) {
                            'Daily' { 'Giảm hiệu ứng trong suốt và hoạt ảnh thanh tác vụ. Giữ chế độ nguồn điện và Game DVR. Đóng game trước. Sao lưu rồi áp dụng?' }
                            'Gaming' { 'Giảm hiệu ứng, tắt Game DVR, chọn Hiệu năng cao nếu có; có thể tăng nhiệt và điện năng. Đóng game trước. Sao lưu rồi áp dụng?' }
                            'Restore' { 'Đóng game trước. Khôi phục các thiết lập ban đầu từ bản sao lưu?' }
                        }
                        if ((ConfirmAction $text)) { $script:Output.Text=Tune $mode $script:Backup }
                    }
                }
            } catch { [void][Windows.Forms.MessageBox]::Show($_.Exception.Message+"`r`nGiữ các bản sao lưu. Nếu thay đổi bị dở dang, dùng nút Hoàn tác tương ứng.",'PC Tuner — Thông báo') }
        }); $top.Controls.Add($b)
    }
    $script:Timer=New-Object Windows.Forms.Timer; $script:Timer.Interval=300
    $script:Timer.Add_Tick({
        if ($null -eq $script:Job -or $script:Job.State -in @('Running','NotStarted')) { return }
        $script:Timer.Stop()
        try {
            $result=Receive-Job $script:Job -ErrorAction Stop | Out-String -Width 150
            if ($script:Job.State -ne 'Completed') { throw 'Báo cáo chưa hoàn tất.' }; $script:Output.Text=$result
        } catch { $script:Output.Text='Báo cáo chưa hoàn tất: '+$_.Exception.Message }
        finally { Remove-Job $script:Job -Force; $script:Job=$null; foreach ($b in $script:Buttons) { $b.Enabled=$true } }
    })
    $script:Form.Add_FormClosing({ param($s,$e) if ($null -ne $script:Job) { $e.Cancel=$true; [void][Windows.Forms.MessageBox]::Show('Hãy chờ báo cáo hoàn tất rồi đóng cửa sổ. Công cụ không cài theo dõi thường trực.') } })
    try { [void]$script:Form.ShowDialog() } finally { $script:Timer.Dispose(); $script:Form.Dispose() }
}
Start-Pro
