
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