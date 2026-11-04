#import "../../../common/tokens.typ": *

#pagebreak(weak: true)
#sechead([KẾT LUẬN, KIẾN NGHỊ])
#set heading(numbering: none)

== Kết quả giai đoạn 1

Nhóm đã hoàn thành phần phân tích và thiết kế: mô hình nghiệp vụ với hai ràng buộc gốc và chín nguyên tắc, danh mục ca sử dụng, quy tắc nghiệp vụ, yêu cầu chức năng và phi chức năng, kiến trúc 12 phân hệ, mô hình dữ liệu và thiết kế sơ bộ AI agent tìm kiếm.

Về ứng dụng, nhóm đã dựng nguyên mẫu Android cho toàn bộ màn hình, từ đăng tin, trò chuyện, thương lượng tới đơn COD và uy tín, chạy trên dữ liệu giả lập; mỗi màn hình có kiểm thử giao diện. Về dịch vụ nền, bảy phân hệ đã hoàn thành: xác thực, tài khoản, nhân viên, ảnh, tin đăng, trò chuyện và giao dịch. Thương lượng chạy đầy đủ theo BR-06. Đơn COD mới là đơn tự gửi, người bán nhập mã vận đơn bằng tay. Kết nối GHTK, GHN để tạo vận đơn và nhận trạng thái chưa được làm; tìm kiếm, uy tín, xác minh danh tính và thông báo cũng chưa hiện thực. Các phân hệ đã làm đều có kiểm thử tự động, gồm cả kiểm thử trọn quy trình nghiệp vụ.

== Khó khăn và vấn đề còn mở

Khó khăn lớn nhất nằm ở mô hình nghiệp vụ: mỗi quy tắc phải suy ra được từ hai ràng buộc gốc, nên đổi một quy tắc là phải rà lại ca sử dụng, yêu cầu và vòng đời đơn liên quan. Một số câu hỏi về hãng vận chuyển cần đối chiếu với tài liệu GHTK, GHN [14], [15] trước khi tích hợp: chế độ người nhận trả phí ship có áp dụng cho mọi tuyến không, phí khi hủy vận đơn trước lúc lấy hàng, và cách tính phí chiều về. Các ngưỡng chế tài ở BR-15 là giá trị ban đầu, cần thống nhất với giảng viên hướng dẫn.

== Kế hoạch giai đoạn 2

Giai đoạn 2 (tuần 5 đến tuần 8) gồm bốn việc. Thứ nhất, phân hệ vận chuyển: liên kết tài khoản GHTK, GHN của người bán, báo phí, tạo và hủy vận đơn trong ứng dụng, nhận trạng thái từ hãng. Thứ hai, phân hệ khám phá: tìm kiếm, AI agent theo thiết kế ở Chương 3 và lưu tin. Thứ ba, phân hệ uy tín: đánh giá, ghi nhận sự cố, điểm uy tín, quyền và chế tài. Thứ tư, nối ứng dụng Android với dịch vụ nền thay cho dữ liệu giả lập. Xác minh danh tính, thông báo, gói người bán, kiểm thử toàn hệ thống và triển khai thuộc giai đoạn 3.
