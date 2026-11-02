# PC Tuner Pro

Bản nâng cấp cho Windows 10/11, dùng PowerShell 5.1 có sẵn. Không có cam kết tăng hiệu năng 100 lần và không tự ép xung CPU/GPU.

## Chạy khi tải artifact bị lỗi

Bảy phần dưới đây là mã thường, không phải dữ liệu nén. Mỗi phần chỉ dưới 90 dòng, dưới 8.000 ký tự, để tránh chép một vùng mã quá dài như các gói trước.

Có thể tải ZIP từ GitHub và mở **START-PRO.cmd** trước. Cách chép bảy phần dưới đây chỉ cần khi không tải được file.

1. Mở một cửa sổ Windows PowerShell mới bằng tài khoản dùng máy hằng ngày, không cần administrator.
2. Mở [phần 1](PRO-Paste-1.ps1), bấm vào vùng mã, Ctrl+A, Ctrl+C; dán toàn bộ vào PowerShell rồi Enter. Đợi hết lỗi (nếu có) trước khi sang phần tiếp theo.
3. Mở [phần 2](PRO-Paste-2.ps1), bấm vào vùng mã, Ctrl+A, Ctrl+C; dán toàn bộ vào PowerShell rồi Enter. Đợi hết lỗi (nếu có) trước khi sang phần tiếp theo.
4. Mở [phần 3](PRO-Paste-3.ps1), bấm vào vùng mã, Ctrl+A, Ctrl+C; dán toàn bộ vào PowerShell rồi Enter. Đợi hết lỗi (nếu có) trước khi sang phần tiếp theo.
5. Mở [phần 4](PRO-Paste-4.ps1), bấm vào vùng mã, Ctrl+A, Ctrl+C; dán toàn bộ vào PowerShell rồi Enter. Đợi hết lỗi (nếu có) trước khi sang phần tiếp theo.
6. Mở [phần 5](PRO-Paste-5.ps1), bấm vào vùng mã, Ctrl+A, Ctrl+C; dán toàn bộ vào PowerShell rồi Enter. Đợi hết lỗi (nếu có) trước khi sang phần tiếp theo.
7. Mở [phần 6](PRO-Paste-6.ps1), bấm vào vùng mã, Ctrl+A, Ctrl+C; dán toàn bộ vào PowerShell rồi Enter. Đợi hết lỗi (nếu có) trước khi sang phần tiếp theo.
8. Mở [phần 7](PRO-Paste-7.ps1), bấm vào vùng mã, Ctrl+A, Ctrl+C; dán toàn bộ vào PowerShell rồi Enter. Đợi hết lỗi (nếu có) trước khi sang phần tiếp theo.

Sau khi mở được giao diện, nhấn **Lưu ứng dụng** để lưu thư mục có `START.cmd` lên Desktop cho lần dùng sau. Không cần chép lại bảy phần ở mỗi lần mở.

Sáu phần đầu khai báo chức năng, chưa chỉnh Windows. Phần cuối mở giao diện; thay đổi chỉ diễn ra khi bạn chọn nút và xác nhận. Nếu PowerShell còn ở dấu `>>` sau khi dán đầy đủ một phần, nhấn Enter thêm một lần. Nếu báo lỗi đỏ, dừng và gửi lỗi; không tự thêm dấu ngoặc.

File [PC-Tuner-Pro.ps1](PC-Tuner-Pro.ps1) là bản một file tương đương, dành cho khi chức năng lưu file của ứng dụng hoạt động trở lại. Bảy phần chép khớp chính xác file này.

## Các nút

- **Scan:** đọc cấu hình, driver, pagefile, dung lượng trống; lấy hai mẫu CPU của từng tiến trình cách nhau khoảng hai giây, xếp hạng CPU và RAM. CPU được chuẩn hóa theo số bộ xử lý logic; không phải FPS hoặc CPU lifetime. Không đóng ứng dụng.
- **CPU/RAM 20s:** lấy 20 mẫu để tìm dấu hiệu CPU đầy tải hoặc RAM trống thấp. Mẫu cách nhau ít nhất một giây nên có thể bỏ lỡ cú giật ngắn. Không đo FPS, nhiệt độ hoặc GPU load. Chỉ chạy khi chẩn đoán, đóng công cụ khi chơi bình thường.
- **Network:** gửi 8 ping ICMP đến gateway IPv4 tìm được và 1.1.1.1. Không đo đường tới Riot hoặc server game. Thiếu phản hồi có thể do lọc ICMP, không chứng minh game mất gói. Gateway có RouteMetric thấp nhất có thể khác tuyến game nếu dùng nhiều adapter/VPN.
- **Daily:** tắt trong suốt và hoạt ảnh taskbar của người dùng hiện tại. Giữ nguyên power plan và Game DVR. Đây là tùy chỉnh giao diện desktop, không bảo đảm tăng FPS.
- **Gaming:** thêm tắt thiết lập ghi hình Game DVR, chọn High performance nếu đã có sẵn. Có thể tăng nhiệt và điện năng.
- **Undo settings:** phục hồi chính xác snapshot thiết lập. Tương thích bản sao cũ của PC Tuner/Valorant Toolkit; muốn đổi chế độ phải hoàn tác bản đang dùng trước.
- **Startup apps:** liệt kê các mục Run của người dùng hiện tại, hiển thị tên và lệnh. Chỉ chọn ứng dụng bạn nhận ra và không cần khi đăng nhập. Các tên liên quan Riot, Vanguard, bảo mật và một số driver được ẩn. Không phải danh sách đầy đủ mọi cơ chế khởi động; không sửa startup folder, services hoặc scheduled tasks.
- **Undo startup:** khôi phục đúng chuỗi và kiểu registry đã lưu, kể cả biến `%LOCALAPPDATA%` chưa mở rộng. Nếu mục đã được sửa bởi ứng dụng khác, dừng để không ghi đè thay đổi mới. Giữ bản sao để xử lý xung đột và thử lại.
- **Keep app:** lưu app một file và launcher lên một thư mục mới trên Desktop, không ghi đè thư mục có sẵn. Không tạo tác vụ khởi động hoặc đổi ExecutionPolicy vĩnh viễn.
- **Save report:** lưu nội dung đang hiển thị ra `.txt` ở nơi bạn chọn; có thể chứa tên ứng dụng/thiết bị. Không tự gửi báo cáo ra ngoài.

Tắt startup chỉ tác động đăng nhập lần sau, không tự đóng ứng dụng đang chạy. Công cụ không tự chọn hoặc tắt hàng loạt các mục. Một bản sao startup chứa lựa chọn hiện tại; cần hoàn tác trước khi tạo lựa chọn mới. Các hộp thoại xác nhận mặc định ở No.

## Bản sao và lỗi giữa chừng

Thiết lập được lưu ở `%LOCALAPPDATA%\PCTuner\backup.json`; startup ở `startup-backup.json` cùng thư mục. Nếu có snapshot cũ ở `%LOCALAPPDATA%\ValorantPCToolkit\backup.json`, dùng bản đó để hoàn tác trước. Không xóa các thư mục này khi chưa hoàn tác.

Cả hai thao tác dùng khóa file để tránh sửa đồng thời. Nếu có lỗi sau khi sửa một phần, snapshot được giữ; dùng nút Undo tương ứng. Snapshot chỉ được lưu trữ sang tên khác sau khi khôi phục và kiểm tra thành công. Tệp `.lock` còn trên đĩa là bình thường, không có nghĩa khóa vẫn đang được giữ.

Đo CPU/RAM/mạng chạy trong tiến trình riêng để cửa sổ không bị khóa. Chờ báo cáo xong rồi đóng cửa sổ; không có tác vụ theo dõi hoặc tự khởi động được cài vào Windows.

## Kiểm tra đã chạy

- 16 kiểm tra core tối ưu/hoàn tác: registry và powercfg giả lập, file snapshot thật.
- 33 kiểm tra startup và ghép phần mềm: raw ExpandString, không sửa ứng dụng ngoài lựa chọn, chặn mục được bảo vệ, lựa chọn cũ, xung đột, thao tác dở dang, user sai, khóa file và cú pháp/độ dài bảy phần.
- Kiểm tra Keep app đã ghi script có đủ 38 hàm và bốn đích registry, parse thành công, giữ BOM UTF-8 và launcher trỏ đúng script. Không cần các file nguồn ban đầu ở lần mở sau.
- Một tiến trình nền PowerShell thật đã chạy báo cáo CPU/RAM của tiến trình trên Linux và trả về đủ hai bảng.
- Windows Forms, WMI/registry/powercfg trên Windows, giao diện tiếng Việt và hiệu năng game chưa được thử trực tiếp trên PC của bạn. Chưa có bằng chứng tăng FPS.

## Ép xung và FurMark

G3260 khóa hệ số nhân; script không mở khóa được hệ số nhân như dòng K. Không tự thay BCLK, điện áp, BIOS hay xung GPU. GT 630 cần công cụ hỗ trợ đúng biến thể card và kiểm tra ổn định thực tế; không có mức tối đa chung áp cho mọi card. Không lưu cấu hình ép xung tự động lúc khởi động khi chưa kiểm tra ổn định.

FurMark 5 FPS ở 1920×1061, GPU 100% là kết quả bài ép GPU, không đại diện FPS trong Valorant. Có thể thử 1280×720, AA Off để giảm tải; không bảo đảm đạt 10 FPS và không gọi giảm độ phân giải là tăng sức mạnh phần cứng. Dừng FurMark trước khi đo game.

## Bản tiếng Việt

Nút và thông báo riêng của ứng dụng đã được dịch. Hộp xác nhận dùng **Đồng ý / Hủy**, mặc định là Hủy. Các nhãn báo cáo cũng hiển thị bằng tiếng Việt; tên phần cứng, tên tiến trình, đường dẫn và chi tiết lỗi hệ thống giữ đúng dữ liệu Windows.

Các mã chế độ trong snapshot vẫn giữ nguyên để khôi phục được bản sao lưu của bản tiếng Anh. Tải lại ZIP và giải nén vào thư mục mới, mở START-PRO.cmd; sau đó có thể chọn **Lưu ứng dụng** để lưu bản tiếng Việt lên Desktop.

## Giao diện 2.0

Thanh trái chuyển giữa Tổng quan, Tối ưu Windows, Khởi động và Chẩn đoán. Cửa sổ dùng nền tối xanh đen và điểm nhấn xanh ngọc; danh sách khởi động và hộp xác nhận theo cùng tông màu.

Tổng quan hiển thị bốn thẻ CPU, RAM, card đồ họa và ổ Windows. Máy được quét một lần khi mở; có thể quét lại bằng nút Kiểm tra máy. Dòng thời gian ghi rõ đây là snapshot lúc quét, không phải giám sát liên tục. Số 0 hợp lệ vẫn được hiện; chỉ số lỗi hoặc không có dữ liệu ghi Chưa đọc được. GPU có thể liệt kê nhiều adapter, không đo mức sử dụng GPU hoặc khẳng định adapter nào đang chạy game.

Trạng thái sao lưu ở thanh trái chỉ báo có tệp; thao tác Hoàn tác vẫn phải kiểm tra nội dung tệp như trước. Thanh tiến trình chỉ chạy khi có tác vụ. Điều hướng vẫn dùng được trong lúc đo, các nút thao tác tạm khóa để tránh chạy chồng.

Đã chạy 13 kiểm tra snapshot/chuyển trang và chạy luồng quét nền thật với điều khiển mô phỏng. Bố cục WinForms chưa được dựng/quan sát trực tiếp trên Windows trong phiên Linux này.
