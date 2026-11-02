
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