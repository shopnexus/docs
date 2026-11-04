#import "../../../common/tokens.typ": *

= TỔNG QUAN TIẾN ĐỘ

== Mục tiêu giai đoạn 2

ShopNexus là sàn giao dịch hàng đã qua sử dụng giữa các cá nhân, dựa trên hai ràng buộc gốc: sàn không giữ tiền của ai (BR-01) và sàn không phân xử từng vụ việc. Đường giao dịch duy nhất là COD đồng kiểm (BR-08): người mua xem hàng tại cửa rồi mới trả tiền cho shipper, tiền thu hộ về thẳng tài khoản của người bán. Người dùng có vấn đề bị chế tài bằng cách mất quyền, không phải mất tiền (BR-15).

Giai đoạn 2 (tuần 5–8) đưa các phần còn ở mức thiết kế trong định kỳ 1 thành chức năng chạy được: kết nối GHTK và GHN để tạo vận đơn và nhận trạng thái do hãng báo về (REQ-15, REQ-16), tìm hàng bằng câu nói tự nhiên với AI agent (REQ-10), đánh giá, ghi nhận sự cố, điểm uy tín và chế tài tự động (REQ-17 đến REQ-19), và nối ứng dụng di động với dữ liệu thật. Xác minh danh tính, thông báo, gói người bán và đánh giá định lượng AI agent để lại cho giai đoạn 3.

== Điều chỉnh so với định kỳ 1

Bảng 1.1 liệt kê các điều chỉnh chính so với thiết kế đã trình bày ở định kỳ 1.

#figure(
  kind: table,
  caption: [Các điều chỉnh thiết kế so với báo cáo định kỳ 1],
  table(
    columns: (1.1fr, 1.5fr, 1.9fr, 1.8fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([*Hạng mục*], [*Định kỳ 1*], [*Định kỳ 2*], [*Lý do*]),
    [Tạo đơn COD], [Người bán tự gửi rồi nhập mã vận đơn, phí bằng tay], [Hệ thống tạo vận đơn trên tài khoản hãng của người bán; tự gửi vẫn giữ cho hãng khác], [Đơn ghi tay không có dữ kiện khách quan để tính chế tài],
    [Các bước của đơn], [Đã yêu cầu → đang giao → đã giao hoặc đã hoàn], [Thêm bước đã tạo vận đơn; hủy được ở hai bước đầu], [Vận đơn đã tạo nhưng hãng chưa lấy hàng vẫn hủy được (BR-10)],
    [Vận chuyển], [Mã vận đơn ghi kèm đơn hàng], [Phân hệ vận chuyển riêng quản lý liên kết hãng, vận đơn và lịch sử trạng thái], [Phần giao dịch không phụ thuộc cách làm việc của từng hãng],
    [Hạn mức đơn COD mở], [Cố định 3 đơn], [Theo bậc uy tín: 2 / 5 / 10 / 20 (BR-09)], [Người mua mới chịu hạn mức thấp, người mua tốt không bị giới hạn vô lý],
    [Ứng dụng di động], [Dữ liệu giả lập], [Dữ liệu thật, cập nhật trạng thái tức thời], [Kiểm thử luồng thật tới hãng vận chuyển],
  ),
)

Điều chỉnh lớn nhất là cách tạo đơn COD. Khi vận đơn được tạo trên tài khoản hãng của chính người bán, các mốc lấy hàng, giao thành công và hoàn hàng đều do hãng báo về, nên chế tài ở BR-15 có dữ liệu khách quan để tính. Đơn tự gửi không có dữ kiện này nên không tính vào tỉ lệ từ chối nhận.

Hình 1.1 là các trạng thái của đơn COD sau điều chỉnh. Khi đơn sang đã tạo vận đơn, tin đăng chuyển sang đang giữ chỗ và các yêu cầu COD khác trên cùng tin tự hủy (BR-07). Từ lúc đang giao, đơn không hủy được. Khi đơn đã giao, tin chuyển sang đã bán; khi đơn đã hoàn hoặc đã hủy, tin trở về đang bán. Trạng thái không nhận được chỉ dùng cho đơn tự gửi.

#fig(
  [Sơ đồ trạng thái đơn COD sau điều chỉnh ở giai đoạn 2],
  spacing: (34mm, 13mm),
  nt((0, 0), [Bắt đầu]),
  np((0, 1), [Đã yêu cầu]),
  np((0, 2), [Đã tạo vận đơn]),
  np((0, 3), [Đang giao]),
  ng((-1, 4), [Đã giao]),
  ng((0, 4), [Đã hoàn]),
  ng((1, 4), [Không nhận được]),
  ng((1.4, 1.5), [Đã hủy]),
  edge((0, 0), (0, 1), "-|>", label-side: left, text(size: 7.5pt)[người mua gửi yêu cầu COD]),
  edge((0, 1), (0, 2), "-|>", label-side: left, text(size: 7.5pt)[người bán tạo vận đơn\ (qua hãng hoặc tự gửi)]),
  edge((0, 2), (0, 3), "-|>", label-side: left, text(size: 7.5pt)[hãng báo đã lấy hàng\ (tự gửi: người bán báo đã gửi)]),
  edge((0, 3), (-1, 4), "-|>", label-side: right, text(size: 7.5pt)[giao thành công]),
  edge((0, 3), (0, 4), "-|>", label-side: left, label-pos: 0.45, text(size: 7.5pt)[từ chối nhận]),
  edge((0, 3), (1, 4), "-|>", label-side: left, text(size: 7.5pt)[chỉ đơn tự gửi]),
  edge((0, 1), (1.4, 1.5), "-|>", label-side: left, text(size: 7.5pt)[hủy]),
  edge((0, 2), (1.4, 1.5), "-|>", label-side: right, text(size: 7.5pt)[hủy trước khi lấy hàng]),
)
