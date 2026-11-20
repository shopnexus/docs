#import "../../../common/tokens.typ": *

#sechead([KẾT LUẬN, KIẾN NGHỊ])
#set heading(numbering: none)

== Kết quả giai đoạn 2

Luồng mua bán chạy trọn trên dữ liệu thật, từ lúc người bán quay video món đồ tới lúc hai bên đánh giá nhau. Người bán đăng tin với AI điền giúp và gợi ý giá, liên kết tài khoản GHTK hoặc GHN của mình và tạo vận đơn ngay trong ứng dụng. Người mua tìm hàng bằng câu nói tự nhiên hoặc bằng ảnh, theo dõi tìm kiếm và giá, trò chuyện có cảnh báo lừa đảo, và xem hàng tại cửa trước khi trả tiền. Đơn COD đi theo trạng thái do hãng báo về, có thời hạn tự động ở từng bước.

Ứng dụng Android đã bỏ hẳn dữ liệu giả lập. Website có đủ các chức năng chính cho người mua và người bán. Nhân viên có trang điều hành để trả lời phiếu hỗ trợ, với trợ lý AI tra cứu và soạn đề xuất. Mô hình nghiệp vụ gọn hơn định kỳ 1: bỏ điểm và bậc uy tín, xác minh danh tính, ghi nhận sự cố và bước khai vết, trong khi hai ràng buộc gốc giữ nguyên.

== Khó khăn

Mỗi lần rút gọn mô hình nghiệp vụ, nhóm phải sửa cùng lúc ứng dụng, dịch vụ nền và tài liệu đặc tả, nên tuần 6 và tuần 7 dành nhiều thời gian cho việc đồng bộ. Tài liệu GHN không nêu cách đăng ký nhận trạng thái tự động, nên đơn GHN dựa vào lượt hỏi lại mỗi 2 giờ. Thời gian trả lời và chi phí của mô hình ngôn ngữ lớn dao động, nhóm phải đặt hạn mức theo ngày cho từng chức năng dùng AI.

== Kế hoạch giai đoạn 3

Giai đoạn 3 (tuần 9–12) gồm các việc sau:

- đẩy tin và gói người bán, nguồn doanh thu của sàn (đã có thiết kế, đang ẩn trong ứng dụng);
- xử lý báo cáo vi phạm và kiểm duyệt tin đăng trên trang điều hành, hoàn thiện phần tổng hợp của trợ lý AI;
- đo chất lượng tìm kiếm trên bộ câu tìm đã gán nhãn;
- xét ngưỡng chế tài từ số đơn giao không thành khi có dữ liệu giao dịch thật;
- kiểm thử toàn hệ thống, triển khai và viết báo cáo cuối.
