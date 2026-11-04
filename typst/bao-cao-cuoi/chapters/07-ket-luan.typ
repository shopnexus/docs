#import "../../common/tokens.typ": *

#pagebreak(weak: true)
#sechead([KẾT LUẬN, KIẾN NGHỊ])
#set heading(numbering: none)

== Kết quả đạt được

Đồ án đã đề xuất và hiện thực một mô hình sàn C2C cho hàng đã qua sử dụng dựa trên hai ràng buộc: sàn không giữ tiền và không phán xử. Giao dịch duy nhất trong ứng dụng là COD đồng kiểm qua tài khoản GHTK hoặc GHN của người bán, nên người mua chỉ trả tiền sau khi đã xem hàng tại cửa, còn người bán nhận tiền thu hộ thẳng từ hãng. Trạng thái đơn do hãng vận chuyển báo về chứ không do một bên tự khai; sự cố sau khi nhận được ghi nhận công khai thay vì phân xử; uy tín, hạn mức COD và chế tài được tính tự động từ các sự kiện đó. Nhờ vậy bài toán niềm tin giữa hai người lạ được giải bằng quy tắc và dữ kiện quan sát được, không cần một bộ phận xử lý khiếu nại lớn dần theo số đơn.

Về sản phẩm, nhóm hoàn thành hệ thống gồm các dịch vụ nền chia theo phân hệ nghiệp vụ và ứng dụng Android cho người dùng. Người dùng đi trọn được quy trình từ đăng nhập bằng OTP, xác minh danh tính bằng CCCD gắn chip, đăng tin với AI điền giúp và khai vết có ảnh, tìm hàng bằng câu tự nhiên, thương lượng giá trong khung chat, đặt COD và tạo vận đơn, đến nhận hoặc từ chối hàng, đánh giá và ghi nhận sự cố. AI agent tìm kiếm chuyển câu hỏi của người mua thành các điều kiện lọc hiển thị rõ ràng mà người mua có thể sửa lại. Các quy trình nhiều bước như tạo vận đơn hay nhận cập nhật từ hãng được thiết kế để không mất đơn và không tạo trùng vận đơn khi có sự cố máy chủ. Mỗi quy trình nghiệp vụ chính đều được kiểm thử theo kịch bản, kể cả các tình huống sự cố và thao tác đồng thời.

== Hạn chế

Các ngưỡng chế tài (20% và 35% tỉ lệ từ chối nhận, tối thiểu 5 đơn trong 90 ngày) và bảng điểm uy tín được chọn theo lập luận, chưa được kiểm chứng với dữ liệu ở quy mô lớn. Đơn tự gửi qua hãng khác không theo dõi được nên không tham gia vào các tỉ lệ chế tài, và người bán có thể lợi dụng điều này để tránh bị thống kê. Đường giao dịch phụ thuộc vào chính sách COD của GHTK, GHN; khi hãng đổi chính sách, phần kết nối phải điều chỉnh theo. Mỗi lượt tìm bằng AI agent tốn thời gian và chi phí nên hệ thống phải giới hạn trong 4 vòng và 8 giây, câu hỏi quá phức tạp có thể nhận kết quả chưa sát. Ứng dụng mới có trên Android, chưa phục vụ người dùng iOS và web.

== Kiến nghị và hướng phát triển

Hướng phát triển đầu tiên là thêm thanh toán tạm giữ qua một đơn vị có giấy phép cho nhóm hàng giá cao, như một đường giao dịch thứ hai bên cạnh COD đồng kiểm, để người mua món hàng vài chục triệu đồng có thêm lựa chọn an toàn. Tiếp theo là kết nối thêm hãng SPX để giảm tỉ lệ đơn tự gửi không theo dõi được, và tinh chỉnh các ngưỡng chế tài, điểm uy tín bằng dữ liệu vận hành thật. Về phía người dùng, nhóm kiến nghị phát triển ứng dụng iOS và giao diện web dùng chung các quy tắc nghiệp vụ hiện có, đồng thời mở rộng AI agent sang gợi ý giá đăng tin cho người bán dựa trên các giao dịch đã chốt.
