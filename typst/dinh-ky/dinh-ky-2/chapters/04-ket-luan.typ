#import "../../../common/tokens.typ": *

#sechead([KẾT LUẬN, KIẾN NGHỊ])
#set heading(numbering: none)

== Kết quả giai đoạn 2

Luồng COD đồng kiểm đã chạy trọn từ lúc chốt giá đến lúc nhận hàng với GHTK và GHN: người bán tạo vận đơn trên tài khoản hãng của mình, người mua theo dõi đơn theo dữ kiện hãng báo về, xem hàng tại cửa rồi mới trả tiền. Người dùng tìm hàng được bằng câu nói tự nhiên với AI agent chỉ đọc, có chip điều kiện sửa được và luôn có kết quả tìm kiếm lai khi agent chậm. Đánh giá, ghi nhận sự cố, điểm uy tín, bậc và chế tài tự động đã hoạt động. Ứng dụng di động chạy trên dữ liệu thật.

== Khó khăn

Hai hãng gọi tên trạng thái khác nhau và có thể báo trùng hoặc sai thứ tự, nên nhóm phải lập bảng quy đổi chung và bảo đảm mỗi dữ kiện chỉ có tác dụng một lần. Thời gian trả lời của mô hình ngôn ngữ dao động nhiều, nên nhánh rơi về tìm kiếm lai phải được kiểm như một luồng chính. Việc gán nhãn bộ câu đánh giá tốn công hơn dự kiến nên đánh giá định lượng được dời sang giai đoạn 3.

== Kế hoạch giai đoạn 3

Giai đoạn 3 (tuần 9–12) gồm các việc sau:

- xác minh danh tính điện tử bằng CCCD và thông báo trong ứng dụng;
- gói người bán và đẩy tin;
- hoàn tất gán nhãn và đánh giá định lượng AI agent;
- kiểm thử toàn hệ thống, triển khai và viết báo cáo cuối.
