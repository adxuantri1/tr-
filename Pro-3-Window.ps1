function ConfirmAction([string]$Text) {
    $dialog=New-Object Windows.Forms.Form; $dialog.Text='Xác nhận thay đổi'; $dialog.Width=620; $dialog.Height=260; $dialog.StartPosition='CenterParent'; $dialog.FormBorderStyle='FixedDialog'; $dialog.MaximizeBox=$false; $dialog.MinimizeBox=$false
    $message=New-Object Windows.Forms.Label; $message.SetBounds(20,20,560,140); $message.Text=$Text; $dialog.Controls.Add($message)
    $yes=New-Object Windows.Forms.Button; $yes.Text='Đồng ý'; $yes.SetBounds(320,170,120,35); $yes.DialogResult='Yes'; $dialog.Controls.Add($yes)
    $cancel=New-Object Windows.Forms.Button; $cancel.Text='Hủy'; $cancel.SetBounds(460,170,120,35); $cancel.DialogResult='Cancel'; $dialog.Controls.Add($cancel)
    $dialog.AcceptButton=$cancel; $dialog.CancelButton=$cancel; $dialog.ActiveControl=$cancel
    try { return $dialog.ShowDialog($script:Form) -eq 'Yes' } finally { $dialog.Dispose() }
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
