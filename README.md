# PC Tuner Pro 2.0

Công cụ giao diện tiếng Việt để tối ưu và chẩn đoán Windows 10/11 cho máy dùng hằng ngày và chơi game. Dùng Windows PowerShell 5.1 / Windows Forms có sẵn, không cần administrator. Cấu hình tham khảo: Pentium G3260, RAM 8 GB, GT 630, SSD.

## Giao diện 2.0

Nền tối xanh đen, điểm nhấn xanh ngọc và thanh điều hướng gồm **Tổng quan**, **Tối ưu Windows**, **Khởi động**, **Chẩn đoán**. Bốn thẻ CPU, RAM, GPU và ổ Windows lấy dữ liệu thật sau lần quét, có mốc thời gian; không giả làm dữ liệu trực tiếp. Khi chưa đọc được một chỉ số, thẻ ghi rõ thay vì hiện số 0 hoặc trạng thái khỏe.

Cửa sổ tự quét một lần khi mở, chạy tác vụ trong tiến trình riêng, có thanh tiến trình và trạng thái sao lưu. Không cài vòng theo dõi thường trực. Khung kết quả giữ được báo cáo dài, có cuộn ngang và lưu ra tệp. Các hộp xác nhận và danh sách khởi động dùng cùng tông màu.

## Chạy trên PC

1. Tải ZIP của nhánh này trên GitHub bằng **Code → Download ZIP**, rồi giải nén toàn bộ.
2. Mở **START-PRO.cmd** trong thư mục đã giải nén.
3. Chọn **Kiểm tra máy** để kiểm tra máy. Đóng game/FurMark trước khi áp dụng thiết lập.
4. **Dùng hằng ngày** giảm hiệu ứng trong suốt và hoạt ảnh taskbar. **Chơi game** thêm tắt Game DVR và chọn High performance nếu đã có sẵn; có thể tăng điện năng và nhiệt độ.
5. Muốn hoàn tác, chọn **Hoàn tác thiết lập**. Đăng xuất/đăng nhập lại Windows sau khi áp dụng hoặc hoàn tác.
6. **Ứng dụng khởi động** cho bạn chọn ứng dụng Run của tài khoản hiện tại để sao lưu và tắt ở lần đăng nhập sau; không tự đóng ứng dụng. **Hoàn tác khởi động** khôi phục lựa chọn đã lưu, dừng nếu có thay đổi mới bị xung đột.
7. **Lưu ứng dụng** lưu một thư mục riêng lên Desktop, có `START.cmd` để mở ở những lần sau. Không tạo tự khởi động.

Chọn chế độ khác sau khi đã hoàn tác snapshot đang dùng. Không xóa `%LOCALAPPDATA%\PCTuner` trước khi hoàn tác. Công cụ dùng được snapshot cũ của Valorant Toolkit nếu còn trong `%LOCALAPPDATA%\ValorantPCToolkit`.

Launcher chỉ đặt ExecutionPolicy Bypass cho tiến trình đang chạy, không thay chính sách Windows vĩnh viễn. Với máy do tổ chức quản lý, cần tuân thủ chính sách quản trị hiện có. Công cụ không tải thêm phần mềm, không yêu cầu mật khẩu hoặc token.

## Chẩn đoán

- **Scan:** cấu hình, driver, RAM, pagefile, dung lượng trống, hai mẫu CPU của tiến trình và danh sách RAM; cập nhật bốn thẻ ở trang Tổng quan. CPU chuẩn hóa theo số bộ xử lý logic; không phải FPS.
- **CPU/RAM 20s:** 20 mẫu, có thể bỏ lỡ cú giật ngắn; không đo FPS, nhiệt độ hoặc GPU load. Chỉ chạy khi tìm lỗi, đóng công cụ khi chơi bình thường.
- **Network:** ping gateway tìm được và Cloudflare `1.1.1.1`, không đo đường tới server game. ICMP có thể bị lọc; thiếu phản hồi không chứng minh game mất gói. Không thay DNS, TCP hoặc firewall.
- **Save report:** lưu nội dung hiện tại ra `.txt`, có thể chứa tên ứng dụng/thiết bị. Không tự gửi báo cáo đi.

Không có cam kết tăng FPS hoặc hết giật. Công cụ không tự ép xung, sửa BIOS, tắt bảo mật, thay driver, xóa dữ liệu hoặc can thiệp Vanguard. Hiệu ứng desktop có thể nhẹ hơn nhưng không bảo đảm tăng tốc game. Ngưỡng ép xung ổn định phải thử trên phần cứng thực tế.

Xem [hướng dẫn chi tiết](PRO-HUONG-DAN.md), gồm cách chép các phần nhỏ khi giao diện chat không tải được file. `PC-Tuner-Pro.ps1` là ứng dụng một file; ba module `Pro-*.ps1` và bảy phần `PRO-Paste-*.ps1` là các bản nguồn tương đương phục vụ kiểm tra/chuyển file.

## Kiểm tra

Chạy mỗi lệnh trong một tiến trình PowerShell riêng:

```powershell
pwsh -NoProfile -File tests/Pro.Core.Tests.ps1
pwsh -NoProfile -File tests/Pro.Tests.ps1
pwsh -NoProfile -File tests/Pro.Background.Tests.ps1
pwsh -NoProfile -File tests/Pro.Export.Tests.ps1
pwsh -NoProfile -File tests/Pro.Vietnamese.Tests.ps1
pwsh -NoProfile -File tests/Pro.Dashboard.Tests.ps1
```

Đã chạy trên PowerShell 7.4.13/Linux: 16 assertion cho core, 33 assertion cho startup/ghép bản, một job nền thực tế đọc CPU/RAM tiến trình và hoàn thành cập nhật dashboard, và kiểm tra Keep app ghi đúng script/launcher/BOM UTF-8. Registry và powercfg được mô phỏng; chưa kiểm tra Windows Forms, WMI/registry trên Windows hoặc FPS game thực tế. Không suy diễn kết quả mô phỏng thành cải thiện trên PC người dùng.

Bản tiếng Việt đã kiểm tra nhãn của 10 nút, chín luồng thao tác có thể mô phỏng, hộp xác nhận Đồng ý/Hủy và BOM UTF-8 cho Windows PowerShell 5.1. Chức năng và định dạng snapshot giữ nguyên, dùng tiếp được bản sao lưu cũ. Hộp chọn file và lỗi hệ thống có thể theo ngôn ngữ Windows.

Bản 2.0 có thêm 13 kiểm tra dữ liệu snapshot và chuyển trang, bao gồm dữ liệu 0 hợp lệ, giá trị ngoài phạm vi, mất nguồn dữ liệu và xóa thông tin cũ khi lần quét mới thất bại. Luồng hoàn thành job được chạy với điều khiển mô phỏng. Chưa dựng hoặc quan sát trực tiếp giao diện WinForms trên Windows trong môi trường Linux này.
