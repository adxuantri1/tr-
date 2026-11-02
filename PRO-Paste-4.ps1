
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