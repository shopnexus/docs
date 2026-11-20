#import "../../../common/tokens.typ": *

#show table.cell: set text(size: 10pt)

= TỔNG QUAN TIẾN ĐỘ

== Mục tiêu giai đoạn 2

Hệ thống là sàn mua bán đồ đã qua sử dụng giữa các cá nhân. Hai ràng buộc gốc từ định kỳ 1 giữ nguyên: sàn không giữ tiền của ai và sàn không phân xử từng vụ việc. Đường giao dịch trong ứng dụng vẫn là COD đồng kiểm: người mua xem hàng khi shipper giao tới rồi mới trả tiền, tiền thu hộ đi thẳng từ hãng vận chuyển về tài khoản của người bán.

Kế hoạch giai đoạn 2 trong báo cáo định kỳ 1 gồm bốn việc. Bảng 1.1 đối chiếu từng việc với kết quả cuối tuần 8.

#figure(
  kind: table,
  caption: [Kết quả giai đoạn 2 so với kế hoạch ở định kỳ 1],
  table(
    columns: (1.3fr, 2fr, 2.2fr),
    align: (left + top, left + top, left + top),
    table.header([*Việc*], [*Kế hoạch*], [*Kết quả*]),
    [Vận chuyển], [Liên kết tài khoản GHTK, GHN của người bán; báo phí, tạo và hủy vận đơn; nhận trạng thái từ hãng], [Đã làm đủ theo tài liệu API của hai hãng, kiểm thử với hãng giả lập],
    [Khám phá], [Tìm kiếm, AI agent tìm hàng, lưu tin], [Tìm bằng câu tự nhiên, bằng ảnh, tin tương tự, lưu tin, báo giảm giá, theo dõi tìm kiếm, theo dõi người bán],
    [Uy tín], [Đánh giá, ghi nhận sự cố, điểm uy tín, quyền và chế tài], [Đánh giá hai chiều, trang Uy tín bằng số liệu thật, cảnh báo lừa đảo, báo cáo vi phạm, phiếu hỗ trợ. Điểm, bậc và ghi nhận sự cố được bỏ (mục 1.2)],
    [Nối ứng dụng], [Ứng dụng Android dùng dữ liệu thật], [Hoàn thành ngày 17/11/2026, bản phát hành không còn dữ liệu giả lập],
    [Làm thêm], [], [Website cho người mua và người bán; trang điều hành cho nhân viên có trợ lý AI; AI điền tin đăng và gợi ý giá; thông báo đẩy],
  ),
)

== Điều chỉnh mô hình nghiệp vụ

Khi nối ứng dụng với dịch vụ nền, nhóm đi lại từng luồng trên dữ liệu thật và thấy một số phần của mô hình ở định kỳ 1 đòi người dùng làm thêm bước mà không giảm được rủi ro. Bảng 1.2 liệt kê các điều chỉnh.

#figure(
  kind: table,
  caption: [Các điều chỉnh mô hình nghiệp vụ so với định kỳ 1],
  table(
    columns: (1.05fr, 1.5fr, 1.9fr, 1.9fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([*Hạng mục*], [*Định kỳ 1*], [*Định kỳ 2*], [*Lý do*]),
    [Uy tín], [Điểm 0–1000, bốn bậc, quyền lợi theo bậc], [Trang "Uy tín của bạn" hiện số liệu: số sao trung bình, số món đã bán, tỉ lệ trả lời trong 24 giờ, số đơn giao không thành trong 90 ngày], [Người dùng đọc và kiểm chứng được con số thật; luật cộng trừ điểm khó giải thích cho người dùng],
    [Hạn mức], [Theo bậc: 2/5/10/20 đơn COD mở, 5/20 tin đang bán], [Mọi tài khoản: 3 đơn COD mở khi mua, 20 tin đang bán], [Hết bậc nên hạn mức chung một mức],
    [Xác minh danh tính], [CCCD gắn chip và khuôn mặt], [Bỏ. Giao dịch COD cần số điện thoại đã xác minh], [Bỏ để giảm độ phức tạp. Đơn COD không trả trước: người mua chỉ trả tiền sau khi xem hàng, nên không cần mức xác minh đó; số điện thoại đã xác minh gắn mỗi tài khoản với một người],
    [Sự cố sau khi nhận], [Ghi nhận sự cố, người bán có 3 ngày để tự hoàn tiền hoặc từ chối], [Hai bên trao đổi trong trò chuyện. Người mua chưa nhận được hàng gửi phiếu "Báo chưa nhận hàng" cho bộ phận hỗ trợ], [Sàn không giữ tiền nên không có khoản hoàn nào để theo dõi],
    [Khai vết], [Mỗi vết khai kèm ảnh cận, AI chặn đăng nếu thấy vết chưa khai], [Bỏ. Tin mô tả bằng ảnh và thang tình trạng ba mức], [Mỗi người đánh giá độ mòn khác nhau nên vết đã khai không phải dữ kiện chắc chắn, còn vết do AI chỉ ra dễ thành cớ tranh chấp. Người mua đã xem hàng tại cửa trước khi trả tiền],
    [Hãng vận chuyển], [GHTK, GHN, hoặc tự gửi qua hãng bất kỳ rồi nhập mã], [Chỉ GHTK, GHN. Mã tự nhập được đọc bằng tài khoản hãng của người bán. Hãng khác xin qua phiếu "Xin thêm hãng"], [Đơn nào cũng có trạng thái do hãng báo, không còn đơn phải tin lời một bên],
    [Chế tài], [Tự động hạ quyền theo tỉ lệ từ chối nhận], [Chưa áp dụng. Số đơn giao không thành hiện công khai trên trang Uy tín], [Cần dữ liệu giao dịch thật để đặt ngưỡng],
    [Tìm kiếm], [AI agent tra cứu nhiều bước], [AI đọc câu tìm một lần, đổi thành điều kiện và chip. Agent nhiều bước chuyển sang hỗ trợ nhân viên], [Người mua cần kết quả nhanh; việc điều tra của nhân viên chờ được lâu hơn],
    [Đánh giá], [Người mua đánh giá người bán], [Hai bên đánh giá nhau, người được đánh giá trả lời một lần], [Người bán cũng chịu rủi ro với COD: người mua bỏ đơn, im lặng],
    [Đăng nhập], [Chỉ OTP số điện thoại], [Thêm email và Google. Số điện thoại chỉ bắt buộc khi giao dịch], [Người chỉ xem và tìm không phải khai số điện thoại],
    [Kênh], [Ứng dụng Android], [Thêm website cho người mua và người bán, trang điều hành cho nhân viên], [Nhiều người mua đồ cũ tìm trên máy tính; nhân viên cần nơi xử lý phiếu hỗ trợ],
    [Trang chủ], [Mở vào "Gần bạn"], [Ba tab: Gợi ý, Gần bạn, Mới nhất], [COD giao toàn quốc nên người bán bán được cho người ở tỉnh khác],
  ),
)

Với các điều chỉnh này, việc của sàn sau khi chốt giá chỉ còn ba thứ: tạo vận đơn trên tài khoản hãng của người bán, theo trạng thái hãng báo về, và cho cả hai bên thấy số liệu thật của nhau. Nhân viên vận hành nhận phiếu hỗ trợ và báo cáo vi phạm; không có quy trình phân xử khiếu nại.

== Luồng đơn COD sau điều chỉnh

Đơn COD còn bốn trạng thái chính (Hình 1.1). Người mua gửi yêu cầu COD sau khi hai bên chốt giá, đơn ở trạng thái chờ tạo đơn. Người bán có 3 ngày để tạo vận đơn, quá hạn thì đơn tự hủy. Khi người bán tạo vận đơn, đơn chuyển sang đã gửi và tin đăng được giữ cho người mua này. Nếu hãng chưa lấy hàng sau 3 ngày, đơn bị hủy và vận đơn trên tài khoản hãng bị hủy theo.

Đơn hoàn tất khi người mua bấm đã nhận hàng, hoặc 3 ngày sau khi hãng báo đã giao. Tin đăng khi đó chuyển sang đã bán. Nếu người mua từ chối nhận tại cửa hoặc hãng báo không giao được, đơn thành giao không thành, tin đăng mở bán lại, và người mua không mất tiền vì chưa trả gì.

#fig(
  [Sơ đồ trạng thái đơn COD ở giai đoạn 2],
  spacing: (34mm, 14mm),
  nt((0, 0), [Bắt đầu]),
  np((0, 1), [Chờ tạo đơn]),
  np((0, 2), [Đã gửi]),
  ng((-0.9, 3), [Hoàn tất]),
  ng((0.9, 3), [Giao không thành]),
  ng((1.6, 1.5), [Đã hủy]),
  edge((0, 0), (0, 1), "-|>", label-side: left, text(size: 7.5pt)[người mua gửi yêu cầu COD]),
  edge((0, 1), (0, 2), "-|>", label-side: left, text(size: 7.5pt)[người bán tạo vận đơn\ hoặc nhập mã]),
  edge((0, 2), (-0.9, 3), "-|>", label-side: right, text(size: 7.5pt)[người mua xác nhận,\ hoặc 3 ngày sau khi giao]),
  edge((0, 2), (0.9, 3), "-|>", label-side: right, text(size: 7.5pt)[từ chối nhận,\ không giao được]),
  edge((0, 1), (1.6, 1.5), "-|>", label-side: left, text(size: 7.5pt)[một bên hủy, hoặc\ người bán quá 3 ngày]),
  edge((0, 2), (1.6, 1.5), "-|>", label-side: right, text(size: 7.5pt)[hãng chưa lấy hàng\ sau 3 ngày]),
)
