#import "../../../common/tokens.typ": *

= PHÂN TÍCH YÊU CẦU

#let elabel(body) = box(fill: white, inset: (x: 2pt, y: 1pt), text(size: 7.5pt, body))
#show table.cell: set text(size: 10pt)

== Tác nhân và ngữ cảnh hệ thống

Hệ thống có bốn nhóm tác nhân người. Khách chỉ xem tin và tìm kiếm. Người dùng là một tài khoản vừa mua vừa bán. Điều phối viên và quản trị viên là tài khoản nhân viên, tách khỏi tài khoản khách hàng. Hệ thống ngoài gồm GHTK và GHN, nhà cung cấp SMS và email, mô hình ngôn ngữ lớn, dịch vụ đẩy thông báo và dịch vụ đối sánh khuôn mặt cho eKYC. Hình 2.1 không có cổng thanh toán nào: tiền hàng đi từ người mua qua shipper về tài khoản người bán, không qua ShopNexus.

#fig(
  [Sơ đồ ngữ cảnh hệ thống],
  spacing: (30mm, 10mm),
  nt((0, 0), [Khách]),
  nt((0, 1), [Người dùng\ (mua và bán)]),
  nt((0, 2), [Điều phối viên]),
  nt((0, 3), [Quản trị viên]),
  ncore((1, 1.5), [ShopNexus]),
  ng((2, 0), [GHTK, GHN]),
  ng((2, 0.75), [SMS, email]),
  ng((2, 1.5), [Mô hình\ ngôn ngữ lớn]),
  ng((2, 2.25), [Dịch vụ đẩy\ thông báo]),
  ng((2, 3), [Đối sánh\ khuôn mặt eKYC]),
  nr((1, 3.1), [Tác nhân thời gian:\ chế tài, hạn 3 ngày]),
  edge((0, 0), (1, 1.5), "-|>", elabel[xem, tìm kiếm], label-side: center, label-pos: 0.4),
  edge((0, 1), (1, 1.5), "<|-|>", elabel[đăng tin, nhắn tin,\ thương lượng, đơn COD], label-side: center, label-pos: 0.45),
  edge((0, 2), (1, 1.5), "<|-|>", elabel[xử lý báo cáo,\ duyệt eKYC], label-side: center, label-pos: 0.45),
  edge((0, 3), (1, 1.5), "<|-|>", elabel[quản lý nhân viên,\ nhật ký kiểm toán], label-side: center, label-pos: 0.4),
  edge((1, 1.5), (2, 0), "<|-|>", elabel[vận đơn, phí,\ trạng thái giao], label-side: center, label-pos: 0.6),
  edge((1, 1.5), (2, 0.75), "-|>", elabel[mã OTP], label-side: center, label-pos: 0.6),
  edge((1, 1.5), (2, 1.5), "<|-|>", elabel[điền tin, tìm kiếm], label-side: center, label-pos: 0.55),
  edge((1, 1.5), (2, 2.25), "-|>", elabel[thông báo], label-side: center, label-pos: 0.6),
  edge((1, 1.5), (2, 3), "<|-|>", elabel[ảnh chân dung], label-side: center, label-pos: 0.6),
  edge((1, 3.1), (1, 1.5), "-|>"),
)

== Ca sử dụng

Nhóm xác định 27 ca sử dụng chia thành sáu nhóm, cùng hai ca dùng chung là tải ảnh lên và ghi nhật ký kiểm toán (Bảng 2.1). Mã ca được giữ cố định trong mọi tài liệu của đồ án.

#figure(
  kind: table,
  caption: [Danh mục ca sử dụng theo nhóm],
  table(
    columns: (1.1fr, 3.6fr),
    inset: (x: 6pt, y: 4pt),
    align: (left + top, left + top),
    table.header([Nhóm], [Ca sử dụng]),
    [Tài khoản và định danh], [UC-01 Đăng nhập bằng OTP; UC-02 Quản lý phiên; UC-03 Xác minh danh tính; UC-04 Thiết lập giao COD; UC-05 Chặn người dùng],
    [Đăng bán], [UC-06 Đăng tin với AI điền giúp; UC-07 Quản lý tin đăng; UC-08 Đẩy tin, gói người bán],
    [Khám phá], [UC-09 Tìm kiếm với AI agent; UC-10 Duyệt danh mục, lọc; UC-11 Lưu tin, theo dõi giảm giá; UC-12 Xem hồ sơ người bán],
    [Trao đổi và giao dịch], [UC-13 Nhắn tin; UC-14 Thương lượng giá; UC-15 Yêu cầu giao COD; UC-16 Tạo đơn gửi hàng; UC-17 Nhận hàng đồng kiểm; UC-18 Hủy đơn trước khi lấy hàng],
    [Hậu giao dịch và uy tín], [UC-19 Đánh giá người bán; UC-20 Mở ghi nhận sự cố; UC-21 Trả lời ghi nhận sự cố; UC-22 Xem điểm uy tín và quyền],
    [Vận hành], [UC-23 Báo cáo vi phạm; UC-24 Xử lý báo cáo, tạm khóa; UC-25 Duyệt tay hồ sơ eKYC; UC-26 Quản lý điều phối viên; UC-27 Tra cứu nhật ký kiểm toán],
  ),
)

Bảng 2.2 đặc tả UC-15, ca nối khâu thương lượng với khâu giao hàng. Ở giai đoạn 1, sau bước này người bán tạo đơn tự gửi và nhập mã vận đơn bằng tay.

#ucspec("UC-15", "Yêu cầu giao COD",
  [Tác nhân chính], [Người mua],
  [Tiền điều kiện], [Thương lượng đã chốt giá, chưa có đơn đang mở; số đơn COD đang mở của người mua còn dưới hạn mức theo bậc (BR-09).],
  [Luồng chính], [
    1. Người mua chọn "Chọn giao COD" trên thẻ đã chốt. \
    2. Ứng dụng hiển thị giá chốt, cảnh báo rằng đã trả tiền cho shipper thì không đòi lại qua sàn (BR-12), và biểu mẫu người nhận. \
    3. Người mua nhập tên, số di động, địa chỉ, phường/xã rồi bấm "Gửi yêu cầu COD". \
    4. Hệ thống kiểm lại hạn mức, tạo đơn ở trạng thái đã yêu cầu và báo cho người bán. \
    5. Người bán thấy yêu cầu trong cuộc trò chuyện và chuyển sang UC-16.
  ],
  [Luồng thay thế], [
    2a. Giá chốt trên 5.000.000 đ: ứng dụng gợi ý hẹn gặp xem hàng trước, vẫn cho chọn COD (BR-13). \
    3a. Người mua bấm gửi nhiều lần: hệ thống chỉ tạo một đơn.
  ],
  [Ngoại lệ], [Vượt hạn mức: từ chối và cho biết hạn mức hiện tại. Thông tin sai: báo lỗi ở từng trường. Tin đã gửi cho người khác hoặc bị đóng: yêu cầu bị hủy kèm lý do.],
  [Hậu điều kiện], [Có một đơn ở trạng thái đã yêu cầu; người mua hủy được cho tới khi hãng lấy hàng (BR-10).],
)

== Quy tắc nghiệp vụ

Bảng 2.3 tóm tắt 21 quy tắc nghiệp vụ. Các quy tắc được tham chiếu bằng mã trong ca sử dụng, yêu cầu và ca kiểm thử.

#figure(
  kind: table,
  caption: [Danh mục quy tắc nghiệp vụ],
  table(
    columns: (0.5fr, 4fr),
    inset: (x: 6pt, y: 3.4pt),
    align: (center + top, left + top),
    table.header([Mã], [Nội dung]),
    [BR-01], [Sàn không giữ tiền: không ví, không cọc, không thu hộ, không hoàn tiền qua sàn.],
    [BR-02], [Tình trạng theo thang Mới / Như mới / Đã dùng; mỗi vết khai kèm ảnh chụp trong ứng dụng; vết AI phát hiện phải được khai hoặc bác bỏ trước khi đăng.],
    [BR-03], [Vết đã khai không là căn cứ khiếu nại; vết không khai mà hàng có thì là lỗi người bán.],
    [BR-04], [Chỉ tài khoản đã xác minh danh tính, không bị khóa mới được đăng tin; số tin đang bán tối đa theo bậc.],
    [BR-05], [Giới hạn tin đăng: tiêu đề, giá, mô tả, 1–10 ảnh; vị trí chỉ lưu tới phường/xã.],
    [BR-06], [Thương lượng: giá trả từ nửa giá niêm yết trở lên; mỗi lúc chỉ một giá đang mở; chỉ chấp nhận được đúng giá đã thấy.],
    [BR-07], [Chốt giá không giữ hàng; khi người bán gửi cho một người, các yêu cầu COD khác trên tin tự hủy.],
    [BR-08], [COD đồng kiểm là đường giao dịch duy nhất; người nhận trả phí ship; người mua trả tiền sau khi xem hàng.],
    [BR-09], [Số đơn COD đang mở của người mua không vượt hạn mức theo bậc (2/5/10/20).],
    [BR-10], [Chỉ hủy được đơn trước khi hãng lấy hàng; vận đơn đã tạo được hủy cùng đơn.],
    [BR-11], [Từ chối nhận: người mua không mất tiền, phí hai chiều tính vào tài khoản hãng của người bán, tin mở bán lại.],
    [BR-12], [Đã trả tiền cho shipper thì không đòi lại qua sàn; ứng dụng cảnh báo trước.],
    [BR-13], [Món trên 5.000.000 đ: gợi ý hẹn gặp xem hàng trước, vẫn cho chọn COD.],
    [BR-14], [Ghi nhận sự cố không được phân xử; người bán trả lời trong 3 ngày; bị từ chối hoặc quá hạn thì hiện công khai.],
    [BR-15], [Chế tài tự động theo tỉ lệ từ chối nhận (ngưỡng 20% và 35%, tối thiểu 5 đơn trong 90 ngày); đơn tự gửi không tính.],
    [BR-16], [Điểm uy tín 0–1000 theo bảng sự kiện; quyền COD và bậc không mua được.],
    [BR-17], [Mỗi đơn được đánh giá một lần, 1–5 sao; sửa hoặc xóa được trong 7 ngày.],
    [BR-18], [AI agent chỉ đọc: không đặt hàng, không thương lượng; ràng buộc agent đặt ra hiện thành nhãn người dùng sửa được.],
    [BR-19], [Điều phối viên chỉ xử lý hàng cấm, hàng giả, lừa đảo có tổ chức, yêu cầu của cơ quan có thẩm quyền và hồ sơ eKYC duyệt tay.],
    [BR-20], [Chặn có hiệu lực hai chiều: không nhắn tin, không thương lượng với nhau.],
    [BR-21], [Không luồng nào tiết lộ một số điện thoại hay email đã có tài khoản hay chưa.],
  ),
)

Thương lượng là nghiệp vụ chính đã hiện thực trong giai đoạn 1. Hình 2.2 cho thấy chốt giá không giữ hàng (BR-07): thương lượng chỉ sang đã bán khi đơn giao thành công, còn đơn bị hủy hoặc bị từ chối nhận thì quay về đang thương lượng.

#fig(
  [Sơ đồ trạng thái của thương lượng],
  spacing: (34mm, 10mm),
  node((-0.5, 1), [], shape: circle, radius: 4pt, fill: ink, stroke: none),
  np((0, 1), [Đang thương lượng], name: <dn>),
  np((1, 1), [Đã chốt giá]),
  np((2, 1), [Đã bán]),
  node((2.4, 1), [], shape: circle, radius: 5pt, fill: ink, stroke: 2.5pt + white, outset: 1.5pt),
  edge((-0.5, 1), <dn>, "-|>"),
  edge(<dn>, <dn>, "-|>", bend: 130deg, loop-angle: 235deg, elabel[trả giá, từ chối, rút giá; giá niêm yết đổi,\ người bán tắt trả giá, tin bị đóng], label-side: left, label-sep: 2pt),
  edge((0, 1), (1, 1), "-|>", bend: 35deg, elabel[bên kia chấp nhận giá mở,\ hoặc người mua nhận giá niêm yết]),
  edge((1, 1), (0, 1), "-|>", bend: 40deg, elabel[hủy thỏa thuận; đơn bị hủy\ hoặc bị từ chối nhận], label-pos: 0.3),
  edge((1, 1), (2, 1), "-|>", elabel[đơn giao\ thành công]),
  edge((2, 1), (2.4, 1), "-|>"),
)

== Yêu cầu chức năng và phi chức năng

Yêu cầu chức năng được đánh mã REQ-01 đến REQ-22, mỗi yêu cầu gắn với phân hệ chịu trách nhiệm. Cuối giai đoạn 1 đã làm các yêu cầu về đăng nhập, phiên, tài khoản, ảnh, quản lý tin, trò chuyện, thương lượng và nhân viên. Đăng tin với AI, đơn COD và xử lý vi phạm mới làm một phần; đơn COD chỉ có hình thức tự gửi. Tìm kiếm bằng AI agent đã có thiết kế. Các yêu cầu còn lại thuộc giai đoạn 2 và 3.

Yêu cầu phi chức năng được đánh mã NFR-01 đến NFR-11 và đều kiểm được bằng kiểm thử tự động. Quan trọng nhất là: quy trình nhiều bước bị ngắt giữa chừng thì chạy tiếp, không tạo hai vận đơn hay gửi hai SMS; bấm gửi lặp chỉ cho một kết quả; hai thao tác đồng thời trên một dữ liệu chỉ một thao tác được ghi nhận; 95% lượt tìm kiếm dưới 800 ms và AI agent trả kết quả trong 8 giây; ảnh được xóa thông tin vị trí, vị trí tin chỉ tới phường/xã.
