#import "../../common/tokens.typ": *

#pagebreak(weak: true)
#sechead([KẾT LUẬN, KIẾN NGHỊ])
#set heading(numbering: none)

== Kết quả đạt được

Đồ án đã đề xuất và hiện thực một mô hình C2C cho hàng đã qua sử dụng dựa trên hai ràng buộc: hệ thống không giữ tiền và không phán xử. Giao dịch duy nhất trong ứng dụng là COD đồng kiểm qua tài khoản GHTK hoặc GHN của người bán, nên người mua chỉ trả tiền sau khi đã xem hàng tại cửa, còn người bán nhận tiền thu hộ thẳng từ hãng. Trạng thái đơn do hãng vận chuyển báo về, các thời hạn chạy tự động, và uy tín của mỗi người là các số liệu quan sát được, công khai cho người sau đọc. Bài toán niềm tin giữa hai người lạ được giải bằng quy tắc và dữ kiện, không cần một bộ phận xử lý khiếu nại lớn dần theo số đơn.

Về sản phẩm, nhóm hoàn thành dịch vụ nền chia theo phân hệ nghiệp vụ, ứng dụng Android và website cho người mua, người bán, và trang điều hành cho nhân viên. Người dùng đi trọn được quy trình từ đăng nhập bằng số điện thoại, email hoặc Google, đăng tin với AI điền giúp từ video, ảnh hoặc link, tìm hàng bằng câu tự nhiên hoặc bằng ảnh, trò chuyện có cảnh báo lừa đảo, trả giá, đặt COD và tạo vận đơn, đến nhận hoặc từ chối hàng và đánh giá nhau. Nhân viên trả lời phiếu hỗ trợ với một trợ lý AI chỉ đọc. Các quy trình nhiều bước như tạo vận đơn hay nhận cập nhật từ hãng được thiết kế để không mất đơn và không tạo trùng vận đơn khi có sự cố máy chủ, và mỗi quy trình nghiệp vụ chính đều được kiểm thử theo kịch bản, kể cả các tình huống sự cố và thao tác đồng thời.

== Hạn chế

Chỉ hai hãng được kết nối, nên người bán quen dùng hãng khác phải chuyển sang GHTK hoặc GHN hay xin thêm hãng. Chế tài tự động theo tỉ lệ giao không thành chưa được áp dụng: hệ thống mới hiện số liệu công khai và giới hạn chung 3 đơn COD đang mở. Đẩy tin và gói người bán, nguồn doanh thu của mô hình, đã có thiết kế nhưng chưa phát hành. Bộ mẫu đánh giá tìm kiếm còn nhỏ và chưa đo độ chính xác. Mỗi lượt dùng mô hình ngôn ngữ lớn (LLM) tốn chi phí, nên các chức năng AI phải chạy trong hạn mức theo ngày. Ứng dụng mới có trên Android, chưa có cho iOS.

== Kiến nghị và hướng phát triển

Hướng phát triển đầu tiên là phát hành đẩy tin và gói người bán. Khi có dữ liệu giao dịch thật, nhóm đề xuất đặt ngưỡng chế tài theo tỉ lệ giao không thành, và kết nối thêm các hãng có API cho tài khoản người bán như SPX. Về tìm kiếm, bộ câu đánh giá cần mở rộng và thêm độ đo độ chính xác để chỉnh trọng số và ngưỡng. Kết quả của bộ phát hiện lừa đảo đã lưu có thể dùng để huấn luyện một mô hình riêng, rẻ và nhanh hơn mô hình ngôn ngữ. Về lâu dài, thanh toán tạm giữ qua một đơn vị có giấy phép có thể được thêm cho nhóm hàng giá cao như một đường giao dịch thứ hai bên cạnh COD đồng kiểm.
