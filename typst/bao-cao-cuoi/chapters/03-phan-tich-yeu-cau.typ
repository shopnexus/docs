#import "../../common/tokens.typ": *
#import "../../common/req.typ": *

= PHÂN TÍCH YÊU CẦU

// Các bước của luồng trong bảng đặc tả: cột số thứ tự canh sát, nội dung thụt treo.
#let buoc(..xs) = grid(
  columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
  ..xs.pos().enumerate().map(((i, x)) => ([#(i + 1).], x)).flatten(),
)
#let nhanh(..xs) = grid(
  columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
  ..xs.pos().chunks(2).map(((m, x)) => ([#m.], x)).flatten(),
)
#let elabel(body) = box(fill: white, inset: (x: 2pt, y: 1pt), text(size: 8pt, body))
#let lane-v = (paint: luma(60%), thickness: 0.6pt, dash: "dashed")
#let lane-h = (paint: luma(75%), thickness: 0.5pt)

== Tác nhân và ngữ cảnh hệ thống

ShopNexus có bốn loại tác nhân người. Khách là người chưa đăng nhập, chỉ xem và tìm kiếm; mọi thao tác thay đổi dữ liệu đều đòi đăng nhập. Người dùng sở hữu một tài khoản vừa mua vừa bán, hệ thống không có vai trò người bán riêng; tùy ngữ cảnh, người dùng được gọi là Người mua hoặc Người bán. Điều phối viên và Quản trị viên là tài khoản nhân viên, tách khỏi tài khoản khách hàng, đăng nhập bằng email, mật khẩu và mã xác thực hai lớp bắt buộc. Quản trị viên làm được mọi việc của điều phối viên; quản trị viên đầu tiên do người vận hành hệ thống tạo trực tiếp trên máy chủ, không tạo được qua ứng dụng.

Phía hệ thống ngoài có năm nhóm: GHTK và GHN tạo, hủy vận đơn, báo phí và báo trạng thái giao hàng [14], [15]; nhà cung cấp SMS và email gửi mã OTP; dịch vụ AI gồm mô hình ngôn ngữ lớn (LLM) và mô hình hiểu nghĩa văn bản dùng cho tìm kiếm; dịch vụ đẩy thông báo tới điện thoại; dịch vụ đối sánh khuôn mặt eKYC. Ngoài ra còn hai tác nhân thời gian bên trong hệ thống: bộ chế tài tự động và hạn 3 ngày của ghi nhận sự cố.

Hình 3.1 đặt ShopNexus ở giữa và chỉ vẽ những gì đi qua đường biên của nó. Ở mức ngữ cảnh, không có đường tiền nào đi qua hệ thống: tiền hàng và phí ship đi từ người mua sang shipper tại cửa, từ shipper về hãng, rồi từ hãng vào tài khoản ngân hàng người bán đã khai với hãng; ShopNexus chỉ nhận về trạng thái vận đơn. Đây là ràng buộc BR-DEAL-01 nhìn từ ngoài vào: hệ thống không có ví, không có số dư và không nối tới cổng thanh toán nào.

#fig(
  [Sơ đồ ngữ cảnh hệ thống ShopNexus],
  spacing: (30mm, 7.5mm),

  node(enclose: ((1, 0), (1, 4)), align(center + horizon, stack(spacing: 6pt,
      text(size: 13pt, weight: 700)[ShopNexus],
      text(size: 8pt)[ứng dụng di động\ cho người dùng;\ trang quản lý\ cho nhân viên])),
    fill: rgb("#E4E4E4"), stroke: 1pt + ink, corner-radius: 5pt, width: 40mm, name: <sys>),

  nt((0, 0), [Khách]),
  nt((0, 1.33), [Người dùng\ (mua và bán)]),
  nt((0, 2.67), [Điều phối viên]),
  nt((0, 4), [Quản trị viên]),

  np((2, 0), [GHTK / GHN]),
  np((2, 1), [SMS / email]),
  np((2, 2), [Dịch vụ AI\ (LLM, hiểu nghĩa)]),
  np((2, 3), [Dịch vụ đẩy\ thông báo]),
  np((2, 4), [Đối sánh\ khuôn mặt eKYC]),

  edge((0, 0), (1, 0), "-|>", snap-to: (auto, <sys>), elabel[xem, tìm kiếm]),
  edge((0, 1.33), (1, 1.33), "<|-|>", snap-to: (auto, <sys>),
    elabel[tin đăng, tin nhắn, thương lượng,\ yêu cầu COD, đánh giá, ghi nhận]),
  edge((0, 2.67), (1, 2.67), "<|-|>", snap-to: (auto, <sys>),
    elabel[báo cáo vi phạm,\ hồ sơ eKYC, tạm khóa]),
  edge((0, 4), (1, 4), "<|-|>", snap-to: (auto, <sys>),
    elabel[tài khoản nhân viên,\ nhật ký kiểm toán]),

  edge((1, 0), (2, 0), "<|-|>", snap-to: (<sys>, auto),
    elabel[tạo/hủy vận đơn, phí;\ trạng thái giao hàng]),
  edge((1, 1), (2, 1), "-|>", snap-to: (<sys>, auto), elabel[mã OTP]),
  edge((1, 2), (2, 2), "<|-|>", snap-to: (<sys>, auto),
    elabel[ảnh, câu tìm kiếm;\ gợi ý điền tin, kết quả]),
  edge((1, 3), (2, 3), "-|>", snap-to: (<sys>, auto), elabel[thông báo đẩy]),
  edge((1, 4), (2, 4), "<|-|>", snap-to: (<sys>, auto),
    elabel[ảnh chân dung;\ điểm khớp]),

  // Đường tiền: nằm hẳn ngoài đường biên hệ thống
  nr((0, 5.4), [Người mua]),
  nr((0.67, 5.4), [Shipper]),
  nr((1.33, 5.4), [Hãng vận chuyển]),
  nr((2, 5.4), [Người bán]),
  edge((0, 5.4), (0.67, 5.4), "-|>", stroke: (dash: "dashed")),
  edge((0.67, 5.4), (1.33, 5.4), "-|>", stroke: (dash: "dashed")),
  edge((1.33, 5.4), (2, 5.4), "-|>", stroke: (dash: "dashed")),
  node((1, 6.1), text(size: 8pt)[Đường tiền hàng và phí ship (COD): đi ngoài hệ thống, không qua ShopNexus],
    stroke: none, fill: none),
)

== Ca sử dụng

Bảng 3.1 liệt kê 27 ca sử dụng nghiệp vụ chia thành sáu nhóm, cộng hai ca dùng chung UC-SHR-01 và UC-SHR-02 được các ca khác gọi qua quan hệ «include». Mỗi ca ứng với một mục tiêu trọn vẹn của tác nhân. Vì một tài khoản vừa mua vừa bán, cột tác nhân ghi Người mua hoặc Người bán theo vai mà tài khoản đóng trong ca đó, không phải theo loại tài khoản.

#uc-table()

Hình 3.2 chỉ vẽ lõi giao dịch, gồm nhóm D và E (UC-DEAL-01 đến UC-TRS-04), vì đây là phần duy nhất có ba tác nhân cùng tham gia một chuỗi ca nối tiếp và có quan hệ «include», «extend» thật giữa các ca. Các nhóm A, B, C, F chủ yếu là một tác nhân nối với một ca, Bảng 3.1 đã thể hiện đủ; vẽ cả 29 ca trên một hình chỉ làm rối đường nối. UC-TRS-02 «include» UC-SHR-01 vì ghi nhận sự cố luôn kèm ảnh. UC-TRS-02 «extend» UC-DEAL-05 tại điểm mở rộng "sau khi nhận hàng", chỉ khi người mua phát hiện sự cố. UC-DEAL-02 «extend» UC-DEAL-01 vì thương lượng diễn ra trong cuộc trò chuyện theo tin đăng và chỉ có khi tin cho phép trả giá.

#fig(
  [Sơ đồ ca sử dụng lõi giao dịch (nhóm D và E)],
  spacing: (22mm, 2.6mm),
  node(enclose: (<u13>, <u14>, <u15>, <u16>, <u17>, <u18>, <u19>, <u20>, <u21>, <u22>, <us1>),
    inset: 10pt, stroke: (paint: ink, dash: "dashed", thickness: 0.9pt),
    fill: none, corner-radius: 8pt, name: <bien>),
  node((1, -1.6), text(size: 9pt, weight: 700)[ShopNexus: trao đổi, giao dịch, hậu giao dịch],
    fill: soft, stroke: none, inset: 3pt),

  // Mọi ca cùng một bề rộng; đường nối tác nhân dừng ở đầu mút trái hoặc phải
  // của ca nên không cắt qua ca khác.
  ..{
    let ca(p, nm, id) = nt(p, uc(id), name: nm, width: 86mm, inset: 5.5pt)
    (
      ca((1, 0), <u13>, "UC-DEAL-01"),
      ca((1, 2), <u14>, "UC-DEAL-02"),
      ca((1, 3), <u15>, "UC-DEAL-03"),
      ca((1, 4), <u16>, "UC-DEAL-04"),
      ca((1, 5), <u18>, "UC-DEAL-06"),
      ca((1, 6), <u17>, "UC-DEAL-05"),
      ca((1, 8), <u20>, "UC-TRS-02"),
      ca((1, 10), <us1>, "UC-SHR-01"),
      ca((1, 11), <u21>, "UC-TRS-03"),
      ca((1, 12), <u19>, "UC-TRS-01"),
      ca((1, 13), <u22>, "UC-TRS-04"),
    )
  },

  nact((-0.2, 6.5), text(size: 9pt)[Người mua], name: <mua>),
  nact((2.2, 9), text(size: 9pt)[Người bán], name: <ban>),
  nact((2.8, 4.5), text(size: 8pt)[Hãng vận\ chuyển], name: <hang>),

  ..{
    let noi(a, u, ben) = edge(a, (rel: (ben * 43mm, 0mm), to: u), snap-to: (auto, none),
      stroke: 0.7pt + blue-s)
    (
      ..(<u13>, <u14>, <u15>, <u17>, <u18>, <u19>, <u20>, <u22>).map(u => noi(<mua>, u, -1)),
      ..(<u13>, <u14>, <u16>, <u18>, <u21>, <u22>).map(u => noi(<ban>, u, 1)),
      ..(<u16>, <u17>, <u18>).map(u => noi(<hang>, u, 1)),
    )
  },

  edge(<u14>, <u13>, "-|>", stroke: (dash: "dashed"), label-side: right, elabel[«extend»]),
  edge(<u20>, <u17>, "-|>", stroke: (dash: "dashed"), label-side: right, elabel[«extend»]),
  edge(<u20>, <us1>, "-|>", stroke: (dash: "dashed"), label-side: left, elabel[«include»]),
)

== Đặc tả ca sử dụng trọng yếu

Ba ca được đặc tả đầy đủ là ba ca mang nghiệp vụ riêng của đề tài: đăng tin với AI điền giúp (Bảng 3.2), tìm kiếm bằng AI agent (Bảng 3.3) và nhận hàng đồng kiểm (Bảng 3.4). Bảng 3.4 gộp phần theo dõi đơn và phần nhận hàng của UC-DEAL-05, coi UC-DEAL-04 là tiền điều kiện.

#ucspec-of("UC-LST-01")

#ucspec-of("UC-DSC-01")

#ucspec-of("UC-DEAL-05")

== Quy tắc nghiệp vụ

Bảng 3.5 gom #req.br.len() quy tắc nghiệp vụ. Chúng suy ra từ hai ràng buộc gốc: sàn không giữ tiền (BR-DEAL-01) và sàn không phán xử từng vụ việc (BR-TRS-01, BR-MOD-01). Vì không giữ tiền, sàn không có khoản nào để hoàn, nên "hoàn tiền" trở thành từ chối nhận tại cửa (BR-DEAL-08). Vì không phán xử, tin đăng không có phần khai vết và người mua tự xem tình trạng hàng tại cửa (BR-LST-01, BR-DEAL-02); sàn dựa vào ghi nhận công khai (BR-TRS-01) và chế tài theo thống kê (BR-TRS-02); điều phối viên chỉ xử lý vài nhóm việc không tăng theo số đơn (BR-MOD-01).

#br-table()

== Mô hình hóa quy trình

Hình 3.3 mô tả quy trình giao dịch từ lúc chốt giá đến khi đơn kết thúc, theo bốn làn Người mua, Người bán, Hệ thống và Hãng vận chuyển. Quy trình có bốn điểm quyết định. Thứ nhất, hệ thống đếm số đơn COD đang mở của người mua và từ chối nếu vượt hạn mức theo bậc (BR-DEAL-06); hai yêu cầu gửi cùng lúc cũng không vượt được hạn mức. Món trên 5.000.000 đ chỉ nhận thêm lời gợi ý hẹn gặp xem hàng trước (BR-DEAL-10). Thứ hai, người bán chọn gửi qua hãng đã liên kết, khi đó hệ thống tạo vận đơn trên tài khoản hãng của người bán, hoặc tự gửi qua hãng khác và nhập mã vận đơn. Thứ ba, trước khi hãng lấy hàng, một bên còn hủy được đơn (BR-DEAL-07). Thứ tư, tại cửa người mua xem hàng rồi nhận hoặc từ chối. Việc trả tiền diễn ra giữa người mua và shipper, hệ thống chỉ biết kết quả qua báo cáo của hãng.

#fig(
  [Sơ đồ hoạt động quy trình giao dịch COD đồng kiểm],
  spacing: (10mm, 3.2mm), node-inset: 4pt,

  edge((0.5, -0.5), (0.5, 17.5), stroke: lane-v),
  edge((1.5, -0.5), (1.5, 17.5), stroke: lane-v),
  edge((2.5, -0.5), (2.5, 17.5), stroke: lane-v),
  edge((-0.55, 0.5), (3.55, 0.5), stroke: lane-h),

  ncore((0, 0), [NGƯỜI MUA]),
  ncore((1, 0), [NGƯỜI BÁN]),
  ncore((2, 0), [HỆ THỐNG]),
  ncore((3, 0), [HÃNG VẬN CHUYỂN]),

  // Mọi nút hành động cùng một bề rộng để bốn làn rộng bằng nhau; mỗi dòng
  // ngắt tay để không dòng nào bị dàn đều chữ. Dưới mỗi nút quyết định chừa
  // khoảng trống để nhãn nhánh dọc không đè lên đỉnh hình thoi.
  ..{
    let w = 40mm
    let s(b) = text(size: 9.5pt, b)
    let quyet(p, b) = nd(p, text(size: 9pt, b), inset: 6.5pt)
    (
      nt((0, 1), s[Hai bên đã chốt giá]),
      np((0, 2), s[Chọn giao COD,\ nhập người nhận,\ xem phí ship], width: w),
      quyet((2, 3), [Vượt hạn\ mức COD?]),
      nr((0, 3), s[Nhận báo vượt hạn mức], width: w),
      nt((0, 5), s[Kết thúc]),
      np((2, 5), s[Lưu đơn đã yêu cầu,\ báo người bán], width: w),
      quyet((1, 6), [Hãng liên kết\ hay tự gửi?]),
      np((2, 6), s[Tạo vận đơn trên tài\ khoản hãng của người bán], width: w),
      np((3, 6), s[Tạo vận đơn,\ báo phí thật], width: w),
      np((1, 8), s[Nhập tên hãng,\ mã vận đơn, phí], width: w),
      ng((2, 8), s[Đơn đã tạo vận đơn, tin\ đang giữ chỗ, hủy các\ yêu cầu COD khác], width: w),
      quyet((2, 10), [Hủy trước\ khi lấy hàng?]),
      np((3, 10), s[Lấy hàng,\ đơn đang giao], width: w),
      ng((2, 12), s[Đơn đã hủy, hủy vận\ đơn, tin về đang bán], width: w),
      nt((1, 12), s[Kết thúc]),
      np((3, 13), s[Giao tới cửa,\ người mua mở xem], width: w),
      quyet((0, 14), [Nhận hay\ từ chối?]),
      np((3, 14), s[Hoàn hàng về người bán,\ tính phí hai chiều], width: w),
      nr((0, 16), s[Trả tiền hàng và phí\ ship cho shipper], width: w),
      ng((2, 16), s[Đơn đã hoàn, tin về đang\ bán, thương lượng về\ đang thương lượng], width: w),
      nt((1, 16), s[Kết thúc]),
      ng((2, 17), s[Đơn đã giao, tin và\ thương lượng đã bán], width: w),
      nt((3, 17), s[Kết thúc]),
    )
  },

  edge((0, 1), (0, 2), "-|>"),
  edge((0, 2), (2, 2), (2, 3), "-|>", corner-radius: 4pt),
  edge((2, 3), (0, 3), "-|>", label-side: right, label-pos: 0.3, elabel[Có]),
  edge((0, 3), (0, 5), "-|>"),
  edge((2, 3), (2, 5), "-|>", label-side: left, label-sep: 5pt, elabel[Không]),
  edge((2, 5), (1, 6), "-|>"),
  edge((1, 6), (2, 6), "-|>"),
  edge((2, 6), (3, 6), "<|-|>"),
  edge((1, 6), (1, 8), "-|>", label-side: right, label-sep: 5pt, elabel[Tự gửi]),
  edge((2, 6), (2, 8), "-|>"),
  edge((1, 8), (2, 8), "-|>"),
  edge((2, 8), (2, 10), "-|>"),
  edge((2, 10), (2, 12), "-|>", label-side: right, label-sep: 5pt, elabel[Có]),
  edge((2, 12), (1, 12), "-|>"),
  edge((2, 10), (3, 10), "-|>", label-side: left, label-pos: 0.4, elabel[Không]),
  edge((3, 10), (3, 13), "-|>"),
  edge((3, 13), (0, 13), (0, 14), "-|>", corner-radius: 4pt),
  edge((0, 14), (0, 16), "-|>", label-side: right, label-sep: 5pt, elabel[Nhận]),
  edge((0, 14), (3, 14), "-|>", label-side: left, label-pos: 0.3, elabel[Từ chối]),
  edge((3, 14), (3, 16), (2, 16), "-|>", corner-radius: 4pt, label-pos: 0.75, label-side: right,
    elabel[hãng báo hoàn]),
  edge((2, 16), (1, 16), "-|>"),
  edge((0, 16), (0, 17), (2, 17), "-|>", corner-radius: 4pt, label-pos: 0.6, label-side: left,
    elabel[hãng báo giao xong]),
  edge((2, 17), (3, 17), "-|>"),
)

Hình 3.4 là sơ đồ trạng thái của đơn COD, mỗi cạnh ghi sự kiện làm đơn đổi trạng thái. Đơn mang mã SN kèm số thứ tự từ 100001, bắt đầu ở trạng thái đã yêu cầu khi người mua gửi yêu cầu kèm người nhận (tên ≤ 50 ký tự, số di động Việt Nam, địa chỉ ≤ 200 ký tự, phường/xã). Bốn trạng thái nền xám là trạng thái cuối; từ đang giao trở đi đơn không hủy được. Mỗi lần đơn đổi trạng thái, tin đăng và thương lượng liên quan đổi theo: khi đơn đã tạo vận đơn, tin chuyển sang đang giữ chỗ và các yêu cầu COD khác trên tin bị hủy; khi đơn đã giao, tin và thương lượng chuyển sang đã bán; khi đơn đã hoàn hoặc đã hủy, tin về đang bán và thương lượng về đang thương lượng. Hệ thống ghi thay đổi của đơn cùng lúc với thông báo cho các phân hệ liên quan, nên không có trường hợp đơn đã đổi mà tin đăng, uy tín hay thông báo không được cập nhật. Tin đăng có vòng đời riêng: từ đang xử lý sang đang bán hoặc bị từ chối tùy kết quả xử lý ảnh; đang bán và đang ẩn chuyển qua lại và cùng sang được đã bán khi người bán đánh dấu; đang bán sang đang giữ chỗ khi người bán tạo đơn, rồi sang đã bán hoặc về đang bán theo kết quả đơn; mọi trạng thái sang được đã xóa, trừ việc tin đang giữ chỗ không sửa, ẩn hay xóa được.

#fig(
  [Sơ đồ trạng thái của đơn COD],
  spacing: (30mm, 9mm),

  node((0, 0), [], shape: circle, radius: 5pt, fill: ink, stroke: none),
  np((1, 0), [Đã yêu cầu]),
  np((2, 0), [Đã tạo vận đơn]),
  np((2, 1.6), [Đang giao]),
  ng((1, 3.2), [Đã giao]),
  ng((2, 3.2), [Đã hoàn]),
  ng((3, 3.2), [Không nhận được]),
  ng((1.5, -1.7), [Đã hủy\ #text(size: 8pt)[lý do: người mua hủy, người bán hủy,\ đã gửi cho người khác, tin đã đóng]]),

  edge((0, 0), (1, 0), "-|>", label-side: right, elabel[người mua gửi\ yêu cầu COD]),
  edge((1, 0), (2, 0), "-|>", label-side: right, elabel[người bán tạo vận đơn\ hoặc nhập vận đơn tự gửi]),
  edge((2, 0), (2, 1.6), "-|>", label-side: left, elabel[hãng báo đã lấy hàng /\ người bán báo đã gửi (tự gửi)]),
  edge((2, 1.6), (1, 1.6), (1, 3.2), "-|>", corner-radius: 4pt, label-pos: 0.3, label-side: left,
    elabel[hãng báo giao thành công /\ người mua báo đã nhận]),
  edge((2, 1.6), (2, 3.2), "-|>", label-side: left, elabel[hãng báo\ từ chối nhận]),
  edge((2, 1.6), (3, 1.6), (3, 3.2), "-|>", corner-radius: 4pt, label-pos: 0.3, label-side: right,
    elabel[người mua báo không\ nhận được (tự gửi)]),
  edge((1, 0), (1.5, -1.7), "-|>", label-side: left, label-pos: 0.4, elabel[một bên hủy]),
  edge((2, 0), (1.5, -1.7), "-|>", label-side: right, label-pos: 0.3, elabel[một bên hủy trước\ khi hãng lấy hàng]),
)

== Yêu cầu chức năng và phi chức năng

Bảng 3.6 liệt kê 22 yêu cầu chức năng rút ra từ các ca sử dụng và quy tắc ở trên. Cột phân hệ ghi phân hệ nghiệp vụ chịu trách nhiệm, là căn cứ phân rã kiến trúc ở chương 4.

#fr-table()

Bảng 3.7 liệt kê 11 yêu cầu phi chức năng, mỗi yêu cầu viết thành một tiêu chí kiểm chứng được bằng kiểm thử hoặc số đo; chương 6 đối chiếu kết quả kiểm thử với từng mã.

#nfr-table()
