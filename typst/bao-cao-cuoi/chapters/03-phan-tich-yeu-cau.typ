#import "../../common/tokens.typ": *

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

Hình 3.1 đặt ShopNexus ở giữa và chỉ vẽ những gì đi qua đường biên của nó. Ở mức ngữ cảnh, không có đường tiền nào đi qua hệ thống: tiền hàng và phí ship đi từ người mua sang shipper tại cửa, từ shipper về hãng, rồi từ hãng vào tài khoản ngân hàng người bán đã khai với hãng; ShopNexus chỉ nhận về trạng thái vận đơn. Đây là ràng buộc BR-01 nhìn từ ngoài vào: hệ thống không có ví, không có số dư và không nối tới cổng thanh toán nào.

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

Bảng 3.1 liệt kê 27 ca sử dụng nghiệp vụ chia thành sáu nhóm, cộng hai ca dùng chung UC-S1 và UC-S2 được các ca khác gọi qua quan hệ «include». Mỗi ca ứng với một mục tiêu trọn vẹn của tác nhân. Vì một tài khoản vừa mua vừa bán, cột tác nhân ghi Người mua hoặc Người bán theo vai mà tài khoản đóng trong ca đó, không phải theo loại tài khoản.

#figure(
  kind: table,
  caption: [Danh mục ca sử dụng của hệ thống ShopNexus],
  table(
    columns: (1.6cm, 1fr, 4.4cm),
    inset: (x: 6pt, y: 2.6pt),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Mã], [Tên ca sử dụng], [Tác nhân chính]),
    table.cell(colspan: 3, fill: rgb("#F7F7F7"))[*A. Tài khoản và định danh*],
    [UC-01], [Đăng nhập bằng mã OTP (lần đầu tự tạo tài khoản)], [Người dùng],
    [UC-02], [Quản lý phiên đăng nhập trên các thiết bị], [Người dùng],
    [UC-03], [Xác minh danh tính điện tử (CCCD gắn chip và khuôn mặt)], [Người dùng],
    [UC-04], [Thiết lập giao COD (địa chỉ lấy hàng, liên kết GHTK/GHN, khai tài khoản nhận tiền)], [Người bán],
    [UC-05], [Chặn người dùng khác], [Người dùng],
    table.cell(colspan: 3, fill: rgb("#F7F7F7"))[*B. Đăng bán*],
    [UC-06], [Đăng tin với AI điền giúp (từ ảnh hoặc video)], [Người bán],
    [UC-07], [Quản lý tin đăng (sửa, đổi giá, ẩn/hiện, đánh dấu đã bán, xóa)], [Người bán],
    [UC-08], [Đẩy tin và đăng ký gói người bán], [Người bán],
    table.cell(colspan: 3, fill: rgb("#F7F7F7"))[*C. Khám phá*],
    [UC-09], [Tìm kiếm bằng ngôn ngữ tự nhiên với AI agent], [Người mua, Khách],
    [UC-10], [Duyệt danh mục và lọc kết quả], [Người mua, Khách],
    [UC-11], [Lưu tin, theo dõi tìm kiếm và nhận cảnh báo giảm giá], [Người mua],
    [UC-12], [Xem hồ sơ người bán (bậc, đánh giá, ghi nhận công khai)], [Người mua],
    table.cell(colspan: 3, fill: rgb("#F7F7F7"))[*D. Trao đổi và giao dịch*],
    [UC-13], [Nhắn tin theo tin đăng], [Người dùng],
    [UC-14], [Thương lượng giá], [Người mua, Người bán],
    [UC-15], [Yêu cầu giao COD], [Người mua],
    [UC-16], [Tạo đơn gửi hàng (vận đơn GHTK/GHN hoặc tự gửi)], [Người bán],
    [UC-17], [Theo dõi đơn và nhận hàng đồng kiểm (nhận hoặc từ chối tại cửa)], [Người mua; hãng vận chuyển báo trạng thái],
    [UC-18], [Hủy đơn trước khi lấy hàng], [Người mua, Người bán],
    table.cell(colspan: 3, fill: rgb("#F7F7F7"))[*E. Hậu giao dịch và uy tín*],
    [UC-19], [Đánh giá người bán], [Người mua],
    [UC-20], [Mở ghi nhận sự cố], [Người mua],
    [UC-21], [Trả lời ghi nhận sự cố (tự hoàn hoặc từ chối)], [Người bán],
    [UC-22], [Xem điểm uy tín và quyền hiện có], [Người dùng],
    table.cell(colspan: 3, fill: rgb("#F7F7F7"))[*F. Vận hành*],
    [UC-23], [Báo cáo vi phạm (hàng cấm, hàng giả, lừa đảo, khác)], [Người dùng],
    [UC-24], [Xử lý báo cáo vi phạm và tạm khóa tài khoản], [Điều phối viên],
    [UC-25], [Duyệt thủ công hồ sơ eKYC], [Điều phối viên],
    [UC-26], [Quản lý tài khoản điều phối viên], [Quản trị viên],
    [UC-27], [Tra cứu nhật ký kiểm toán], [Quản trị viên],
    table.cell(colspan: 3, fill: rgb("#F7F7F7"))[*Ca dùng chung («include»)*],
    [UC-S1], [Tải ảnh lên (kiểm tra, chuẩn hóa và lưu ảnh)], [Ca con],
    [UC-S2], [Ghi nhật ký kiểm toán], [Ca con],
  ),
)

Hình 3.2 chỉ vẽ lõi giao dịch, gồm nhóm D và E (UC-13 đến UC-22), vì đây là phần duy nhất có ba tác nhân cùng tham gia một chuỗi ca nối tiếp và có quan hệ «include», «extend» thật giữa các ca. Các nhóm A, B, C, F chủ yếu là một tác nhân nối với một ca, Bảng 3.1 đã thể hiện đủ; vẽ cả 29 ca trên một hình chỉ làm rối đường nối. UC-20 «include» UC-S1 vì ghi nhận sự cố luôn kèm ảnh. UC-20 «extend» UC-17 tại điểm mở rộng "sau khi nhận hàng", chỉ khi người mua phát hiện sự cố. UC-14 «extend» UC-13 vì thương lượng diễn ra trong cuộc trò chuyện theo tin đăng và chỉ có khi tin cho phép trả giá.

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
    let uc(p, nm, b) = nt(p, b, name: nm, width: 76mm, inset: 5.5pt)
    (
      uc((1, 0), <u13>, [UC-13 · Nhắn tin theo tin đăng]),
      uc((1, 2), <u14>, [UC-14 · Thương lượng giá]),
      uc((1, 3), <u15>, [UC-15 · Yêu cầu giao COD]),
      uc((1, 4), <u16>, [UC-16 · Tạo đơn gửi hàng]),
      uc((1, 5), <u18>, [UC-18 · Hủy đơn trước khi lấy hàng]),
      uc((1, 6), <u17>, [UC-17 · Theo dõi đơn, nhận hàng đồng kiểm]),
      uc((1, 8), <u20>, [UC-20 · Mở ghi nhận sự cố]),
      uc((1, 10), <us1>, [UC-S1 · Tải ảnh lên]),
      uc((1, 11), <u21>, [UC-21 · Trả lời ghi nhận sự cố]),
      uc((1, 12), <u19>, [UC-19 · Đánh giá người bán]),
      uc((1, 13), <u22>, [UC-22 · Xem điểm uy tín và quyền]),
    )
  },

  nact((-0.2, 6.5), text(size: 9pt)[Người mua], name: <mua>),
  nact((2.2, 9), text(size: 9pt)[Người bán], name: <ban>),
  nact((2.8, 4.5), text(size: 8pt)[Hãng vận\ chuyển], name: <hang>),

  ..{
    let noi(a, u, ben) = edge(a, (rel: (ben * 38mm, 0mm), to: u), snap-to: (auto, none),
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

Ba ca được đặc tả đầy đủ là ba ca mang nghiệp vụ riêng của đề tài: đăng tin với AI điền giúp (Bảng 3.2), tìm kiếm bằng AI agent (Bảng 3.3) và nhận hàng đồng kiểm (Bảng 3.4). Bảng 3.4 gộp phần theo dõi đơn và phần nhận hàng của UC-17, coi UC-16 là tiền điều kiện.

#ucspec("UC-06", "Đăng tin với AI điền giúp",
  [Tác nhân chính], [Người bán; tác nhân phụ: dịch vụ AI (LLM).],
  [Tiền điều kiện], [Đã đăng nhập.],
  [Hậu điều kiện], [Tin được lưu ở trạng thái đang xử lý; khi mọi ảnh xử lý xong, tin chuyển sang đang bán và bắt đầu xuất hiện trong kết quả tìm kiếm.],
  [Luồng chính], buoc(
    [Người bán chụp hoặc chọn từ thư viện 1–10 ảnh, hoặc quay video; ảnh được tải lên qua UC-S1.],
    [Hệ thống gửi ảnh cho LLM; mô hình trả về tiêu đề, danh mục, tình trạng theo thang Mới/Như mới/Đã dùng và thông số.],
    [Người bán sửa biểu mẫu, nhập giá, xác nhận phường/xã rồi bấm Đăng.],
    [Hệ thống kiểm quyền đăng và trần số tin của người bán (BR-04), kể cả khi người bán gửi nhiều tin cùng lúc; kiểm giới hạn từng mục (BR-05).],
    [Hệ thống lưu tin ở trạng thái đang xử lý, chuẩn hóa ảnh và xóa thông tin vị trí chụp trong ảnh; xong thì tin chuyển sang đang bán, ứng dụng báo "Đã đăng tin".],
  ),
  [Luồng thay thế / ngoại lệ], nhanh(
    [2a], [Mô hình không trả kết quả: người bán tự điền biểu mẫu, tiếp tục bước 3.],
    [4a], [Chưa xác minh danh tính hoặc đang bị tạm khóa: từ chối đăng, ứng dụng dẫn sang UC-03.],
    [4b], [Đã đạt trần số tin theo bậc (5/20/20/20): từ chối, báo số tin tối đa.],
    [5a], [Có ảnh lỗi: tin chuyển sang bị từ chối kèm lý do; sửa tin hoặc thêm ảnh đưa tin về đang xử lý.],
  ),
  [Quy tắc liên quan], [BR-02, BR-04, BR-05.],
)

#ucspec("UC-09", "Tìm kiếm bằng ngôn ngữ tự nhiên với AI agent",
  [Tác nhân chính], [Người mua hoặc Khách; tác nhân phụ: dịch vụ AI (LLM và mô hình hiểu nghĩa văn bản).],
  [Tiền điều kiện], [Không bắt buộc đăng nhập; nếu đã đăng nhập, agent đọc thêm sở thích, đơn gần đây và phường/xã của người dùng.],
  [Hậu điều kiện], [Người dùng nhận danh sách tin, chip ràng buộc sửa được và một câu diễn giải; các ràng buộc đã chốt được nhớ trong phiên tìm kiếm. Không dữ liệu nghiệp vụ nào bị thay đổi.],
  [Luồng chính], buoc(
    [Người dùng gõ hoặc nói một câu nhu cầu; nếu đang trong một phiên tìm kiếm, câu mới được nối vào phiên đó.],
    [Hệ thống bắt đầu lượt tìm, nạp các ràng buộc đã chốt của phiên.],
    [Agent lập kế hoạch và dùng các công cụ chỉ đọc: tra danh mục, xác định vị trí, đọc sở thích, tìm tin; tối đa 4 vòng. Nếu máy chủ gặp sự cố giữa chừng, lượt tìm chạy tiếp từ bước đã xong.],
    [Lệnh tìm tin luôn giữ câu gốc của người dùng cùng bộ lọc agent điền; tìm kiếm lai hợp nhất ba danh sách xếp hạng (mục 2.4) rồi xếp lại theo khoảng cách và bậc người bán.],
    [Hệ thống trả tin, chip và câu diễn giải, lưu ràng buộc vào phiên.],
    [Người dùng sửa hoặc xóa chip; hệ thống chạy lại tìm kiếm lai mà không gọi LLM.],
  ),
  [Luồng thay thế / ngoại lệ], nhanh(
    [3a], [Quá 8 giây hoặc một công cụ lỗi: rơi về tìm kiếm lai thuần với truy vấn gốc.],
    [5a], [Không có tin phù hợp: trả kết quả rỗng kèm chip để người dùng nới ràng buộc.],
    [6a], [Người dùng gửi câu tiếp theo: lặp lại từ bước 1, ràng buộc cũ được kế thừa.],
  ),
  [Quy tắc liên quan], [BR-18; tin đang giữ chỗ, đã bán, đang ẩn hoặc đã xóa không có trong kết quả.],
)

#ucspec("UC-17", "Theo dõi đơn và nhận hàng đồng kiểm",
  [Tác nhân chính], [Người mua; tác nhân phụ: hãng vận chuyển (GHTK/GHN).],
  [Tiền điều kiện], [UC-16 đã hoàn tất: đơn ở trạng thái đã tạo vận đơn, vận đơn GHTK/GHN nằm trên tài khoản người bán (đơn tự gửi xem 4b); người mua đã thấy phí ship thật.],
  [Hậu điều kiện], [Nhận: đơn đã giao, tin và thương lượng đã bán, mở UC-19, UC-20. Từ chối: đơn đã hoàn, tin về đang bán, thương lượng về đang thương lượng. Phân hệ uy tín cập nhật điểm và tỉ lệ từ chối nhận.],
  [Luồng chính], buoc(
    [Hãng lấy hàng và báo trạng thái về hệ thống; đơn chuyển sang đang giao; ứng dụng cập nhật màn hình đơn ngay và gửi thông báo đẩy.],
    [Khi shipper tới cửa, ứng dụng hiện tờ "Tin ghi" (tình trạng và các thông tin người bán ghi trong tin) và cảnh báo rằng sau khi trả tiền sàn không có cơ chế đòi lại.],
    [Người mua xem hàng, đối chiếu với tin ghi, đồng ý nhận và trả tiền hàng cùng phí ship chiều đi cho shipper.],
    [Hãng báo giao thành công; hệ thống chuyển đơn sang đã giao, đánh dấu tin đã bán và đóng thương lượng.],
  ),
  [Luồng thay thế / ngoại lệ], nhanh(
    [1a], [Trước khi hãng lấy hàng, một bên hủy đơn (UC-18): hệ thống hủy vận đơn trên tài khoản hãng của người bán, đơn chuyển sang đã hủy.],
    [3a], [Hàng không khớp tin ghi: người mua từ chối nhận, không trả đồng nào; hãng hoàn hàng, báo đã hoàn, tính phí hai chiều vào tài khoản người bán.],
    [4a], [Hãng báo lặp cùng một trạng thái của cùng một vận đơn: hệ thống chỉ ghi nhận lần đầu, đơn không đổi trạng thái hai lần.],
    [4b], [Đơn tự gửi: người bán báo đã gửi, người mua báo đã nhận (đơn đã giao) hoặc không nhận được; đơn không tính vào tỉ lệ chế tài.],
    [4c], [Sau khi nhận, người mua phát hiện sự cố mà lúc xem tại cửa không thấy: người mua mở UC-20.],
  ),
  [Quy tắc liên quan], [BR-03, BR-08, BR-10, BR-11, BR-12, BR-15.],
)

== Quy tắc nghiệp vụ

Bảng 3.5 gom 21 quy tắc nghiệp vụ. Chúng suy ra từ hai ràng buộc gốc: sàn không giữ tiền (BR-01) và sàn không phán xử từng vụ việc (BR-14, BR-19). Vì không giữ tiền, sàn không có khoản nào để hoàn, nên "hoàn tiền" trở thành từ chối nhận tại cửa (BR-11). Vì không phán xử, tin đăng không có phần khai vết và người mua tự xem tình trạng hàng tại cửa (BR-02, BR-03); sàn dựa vào ghi nhận công khai (BR-14) và chế tài theo thống kê (BR-15); điều phối viên chỉ xử lý vài nhóm việc không tăng theo số đơn (BR-19).

#figure(
  kind: table,
  caption: [Danh mục quy tắc nghiệp vụ],
  table(
    columns: (1.5cm, 1fr),
    inset: (x: 6pt, y: 3.2pt),
    align: (left + top, left + top),
    table.header([Mã], [Nội dung]),
    [BR-01], [Sàn không giữ tiền: không ví, không cọc, không thu hộ, không hoàn tiền qua sàn.],
    [BR-02], [Tin đăng gồm tình trạng hàng theo thang Mới / Như mới / Đã dùng, các thông tin người bán ghi trong tin và ảnh; tin không có phần khai vết, AI không chỉ ra vết nào.],
    [BR-03], [Người mua tự xem tình trạng hàng khi đồng kiểm tại cửa, đối chiếu với tin ghi rồi nhận hoặc từ chối.],
    [BR-04], [Chỉ tài khoản đã xác minh danh tính, không bị tạm khóa mới được đăng tin; số tin đang bán tối đa theo bậc là 5/20/20/20.],
    [BR-05], [Tiêu đề 1–70 ký tự; giá nguyên đồng từ 10.000 đến 1.000.000.000; mô tả ≤ 1.500 ký tự; 1–10 ảnh, ảnh đầu là ảnh bìa; ≤ 20 thông số; vị trí lưu theo phường/xã (tọa độ tâm xã), không lưu GPS của người bán.],
    [BR-06], [Giá thương lượng là bội số 1.000 đ; giá trả ≥ nửa giá niêm yết (làm tròn lên 1.000) và thấp hơn giá niêm yết hoặc phản giá; phản giá cao hơn giá trả và thấp hơn giá niêm yết; mỗi thời điểm chỉ một giá đang mở, giá mở không hết hạn; chấp nhận phải đúng giá mà người chấp nhận đang thấy, nếu giá vừa bị đổi thì lượt chấp nhận bị từ chối và ứng dụng báo giá đã thay đổi.],
    [BR-07], [Chốt giá không giữ hàng; nhiều người mua có thể cùng chốt một tin; khi người bán gửi hàng cho một người, các yêu cầu COD khác trên tin tự hủy với lý do "đã gửi cho người khác".],
    [BR-08], [COD đồng kiểm là đường giao dịch duy nhất trong ứng dụng; vận đơn đặt người nhận trả phí ship; người mua chỉ trả tiền sau khi xem hàng.],
    [BR-09], [Số đơn COD đang mở của một người mua không vượt hạn mức theo bậc 2/5/10/20.],
    [BR-10], [Chỉ hủy được đơn trước khi hãng lấy hàng; vận đơn GHTK/GHN được hệ thống hủy luôn trên tài khoản hãng của người bán.],
    [BR-11], [Từ chối nhận tại cửa: người mua không mất tiền; phí hai chiều do hãng tính vào tài khoản người bán; tin đăng mở bán lại.],
    [BR-12], [Sau khi người mua đã trả tiền cho shipper, sàn không có cơ chế đòi lại; ứng dụng hiển thị cảnh báo này trước thời điểm trả tiền.],
    [BR-13], [Món giá trên 5.000.000 đ: ứng dụng gợi ý hẹn gặp xem hàng trước, vẫn cho chọn COD.],
    [BR-14], [Ghi nhận sự cố không được phân xử; người bán trả lời trong 3 ngày bằng tự hoàn hoặc từ chối; ghi nhận bị từ chối hoặc quá hạn hiển thị công khai trên hồ sơ người bán.],
    [BR-15], [Chế tài tự động chỉ xét khi có ≥ 5 đơn COD trong 90 ngày; tỉ lệ từ chối nhận ≥ 20% thì giới hạn còn 1 đơn COD mở, ≥ 35% thì mất quyền COD 30 ngày; mỗi 30 ngày không có lần từ chối nào hồi lại một nấc; đơn tự gửi không tính vào tỉ lệ.],
    [BR-16], [Điểm uy tín 0–1000 tính theo bảng sự kiện; quyền COD và bậc uy tín không mua được bằng gói trả phí.],
    [BR-17], [Mỗi đơn được đánh giá một lần (1–5 sao, ≤ 500 ký tự) sau khi đơn đã gửi; sửa hoặc xóa được trong 7 ngày.],
    [BR-18], [AI agent chỉ đọc: không đặt hàng, không thương lượng, không thanh toán; mọi ràng buộc agent đặt ra hiện thành chip người dùng sửa được.],
    [BR-19], [Điều phối viên chỉ xử lý hàng cấm, hàng giả bị báo cáo, lừa đảo có tổ chức, yêu cầu của cơ quan có thẩm quyền và hồ sơ eKYC duyệt tay; giá và tình trạng hàng là việc giữa hai bên.],
    [BR-20], [Chặn có hiệu lực hai chiều: hai bên không nhắn tin, không mở thương lượng trên tin của nhau.],
    [BR-21], [Không luồng nào tiết lộ một số điện thoại hoặc email đã có tài khoản hay chưa; khi người dùng mở nội dung không thuộc quyền xem của mình, hệ thống trả lời như thể nội dung đó không tồn tại.],
  ),
)

== Mô hình hóa quy trình

Hình 3.3 mô tả quy trình giao dịch từ lúc chốt giá đến khi đơn kết thúc, theo bốn làn Người mua, Người bán, Hệ thống và Hãng vận chuyển. Quy trình có bốn điểm quyết định. Thứ nhất, hệ thống đếm số đơn COD đang mở của người mua và từ chối nếu vượt hạn mức theo bậc (BR-09); hai yêu cầu gửi cùng lúc cũng không vượt được hạn mức. Món trên 5.000.000 đ chỉ nhận thêm lời gợi ý hẹn gặp xem hàng trước (BR-13). Thứ hai, người bán chọn gửi qua hãng đã liên kết, khi đó hệ thống tạo vận đơn trên tài khoản hãng của người bán, hoặc tự gửi qua hãng khác và nhập mã vận đơn. Thứ ba, trước khi hãng lấy hàng, một bên còn hủy được đơn (BR-10). Thứ tư, tại cửa người mua xem hàng rồi nhận hoặc từ chối. Việc trả tiền diễn ra giữa người mua và shipper, hệ thống chỉ biết kết quả qua báo cáo của hãng.

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

#figure(
  kind: table,
  caption: [Danh mục yêu cầu chức năng],
  table(
    columns: (1.6cm, 1fr, 2.4cm, 3.5cm),
    inset: (x: 6pt, y: 3pt),
    align: (left + top, left + top, left + top, left + top),
    table.header([Mã], [Yêu cầu], [Phân hệ], [UC liên quan]),
    [REQ-01], [Đăng nhập bằng OTP qua SMS/email, tự tạo tài khoản ở lần đầu], [Xác thực], [UC-01],
    [REQ-02], [Liệt kê phiên, đăng xuất một thiết bị hoặc mọi thiết bị], [Xác thực], [UC-02],
    [REQ-03], [Sửa tên hiển thị; chặn và bỏ chặn người dùng], [Tài khoản], [UC-05],
    [REQ-04], [eKYC: chụp hai mặt CCCD, đọc chip NFC, quét khuôn mặt; chuyển duyệt tay khi không đọc được chip], [Định danh], [UC-03, UC-25],
    [REQ-05], [Thiết lập giao COD: địa chỉ lấy hàng, liên kết GHTK/GHN, khai đã có tài khoản nhận tiền tại hãng], [Vận chuyển], [UC-04],
    [REQ-06], [Tải ảnh lên, chuẩn hóa ảnh, xóa thông tin vị trí chụp], [Hình ảnh], [UC-S1],
    [REQ-07], [Đăng tin từ ảnh hoặc video với AI điền giúp], [Tin đăng], [UC-06],
    [REQ-08], [Quản lý tin: sửa, đổi giá, ẩn/hiện, đánh dấu đã bán, xóa], [Tin đăng], [UC-07],
    [REQ-09], [Đẩy tin và gói người bán], [Tin đăng], [UC-08],
    [REQ-10], [Tìm kiếm bằng câu tự nhiên qua AI agent, trả chip ràng buộc sửa được và câu diễn giải], [Khám phá], [UC-09],
    [REQ-11], [Tìm theo bộ lọc, duyệt danh mục, xem tin tương tự], [Khám phá], [UC-10],
    [REQ-12], [Lưu tin, so sánh tin đã lưu, theo dõi tìm kiếm, cảnh báo giảm giá], [Khám phá], [UC-11],
    [REQ-13], [Nhắn tin văn bản và ảnh, đánh dấu đã đọc, lưu trữ hội thoại, cập nhật thời gian thực], [Trò chuyện], [UC-13],
    [REQ-14], [Thương lượng giá theo BR-06], [Giao dịch], [UC-14],
    [REQ-15], [Yêu cầu COD; tạo đơn gửi qua GHTK/GHN hoặc tự gửi; hủy trước khi lấy hàng], [Giao dịch, Vận chuyển], [UC-15, UC-16, UC-18],
    [REQ-16], [Nhận trạng thái vận đơn từ hãng và cập nhật đơn, thương lượng, tin đăng], [Vận chuyển, Giao dịch], [UC-17],
    [REQ-17], [Đánh giá người bán sau đơn], [Uy tín], [UC-19],
    [REQ-18], [Ghi nhận sự cố kèm nhận xét trung lập của AI], [Uy tín], [UC-20, UC-21],
    [REQ-19], [Tính điểm uy tín, bậc, quyền và chế tài tự động], [Uy tín], [UC-12, UC-22],
    [REQ-20], [Báo cáo vi phạm; điều phối viên xử lý và tạm khóa tài khoản], [Uy tín, Nhân viên], [UC-23, UC-24],
    [REQ-21], [Thông báo trong ứng dụng và đẩy tới điện thoại], [Thông báo], [UC-14 – UC-21],
    [REQ-22], [Quản lý nhân viên, đăng nhập có mã xác thực hai lớp, nhật ký kiểm toán], [Nhân viên], [UC-26, UC-27, UC-S2],
  ),
)

Bảng 3.7 liệt kê 11 yêu cầu phi chức năng, mỗi yêu cầu viết thành một tiêu chí kiểm chứng được bằng kiểm thử hoặc số đo; chương 6 đối chiếu kết quả kiểm thử với từng mã.

#figure(
  kind: table,
  caption: [Danh mục yêu cầu phi chức năng],
  table(
    columns: (1.6cm, 3.4cm, 1fr),
    inset: (x: 6pt, y: 3pt),
    align: (left + top, left + top, left + top),
    table.header([Mã], [Thuộc tính], [Tiêu chí kiểm chứng]),
    [NFR-01], [Độ bền], [Máy chủ gặp sự cố giữa một quy trình nhiều bước không để lại dữ liệu dở dang; quy trình chạy tiếp từ bước đã xong và không lặp việc đã làm (không tạo hai vận đơn, không gửi hai SMS).],
    [NFR-02], [Không lặp khi gửi lại], [Một thao tác được ứng dụng gửi lại vì mạng chập chờn cho đúng kết quả của lần đầu; hãng báo trùng một trạng thái thì đơn không đổi trạng thái hai lần.],
    [NFR-03], [Nhất quán khi đồng thời], [Hai người cùng sửa một dữ liệu thì người sửa sau được báo dữ liệu đã thay đổi thay vì ghi đè; các hạn mức (số đơn COD đang mở, số tin đang bán) vẫn đúng khi nhiều yêu cầu đến cùng lúc.],
    [NFR-04], [Không mất thông báo giữa phân hệ], [Thông báo cho các phân hệ khác được ghi cùng lúc với thay đổi dữ liệu; khi phần điều phối quy trình tạm ngừng, thông báo được giữ lại và gửi sau, người dùng vẫn xem được dữ liệu và giữ được phiên đăng nhập.],
    [NFR-05], [Hiệu năng], [95% lượt xem dữ liệu trả về dưới 300 ms; 95% lượt tìm kiếm lai dưới 800 ms; AI agent trả kết quả trong 8 giây hoặc rơi về tìm kiếm lai.],
    [NFR-06], [An toàn xác thực], [Phiên đăng nhập ngắn hạn sống 15 phút và được làm mới tự động; mã làm mới bị dùng lại thì phiên bị thu hồi; có hạn mức gửi OTP; không lộ việc một số điện thoại hay email đã có tài khoản.],
    [NFR-07], [Quyền riêng tư], [Xóa thông tin vị trí chụp khỏi ảnh; vị trí tin theo xã; che số điện thoại, email trong nhật ký; mã hóa khóa kết nối tài khoản hãng vận chuyển của người bán.],
    [NFR-08], [Quan trắc], [Mọi yêu cầu được theo vết; thông báo lỗi mang mã tra cứu để đối chiếu nhật ký; có số liệu đăng nhập, gửi OTP và thông báo đã gửi giữa các phân hệ.],
    [NFR-09], [Tuân thủ hợp đồng API], [Mọi yêu cầu được kiểm theo đặc tả API; bộ kiểm thử đầu-cuối gặp đủ mọi kết quả trả về đã khai trong đặc tả.],
    [NFR-10], [Khả năng tách phân hệ], [Mỗi phân hệ chỉ cho phân hệ khác dùng qua giao diện đã công bố; tách ra chạy riêng không phải sửa nghiệp vụ.],
    [NFR-11], [Ứng dụng di động], [Chạy trên điện thoại Android 12 trở lên, có giao diện tối, cỡ chữ 130%, vùng chạm tối thiểu 48 dp.],
  ),
)
