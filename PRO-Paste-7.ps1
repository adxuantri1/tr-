
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
