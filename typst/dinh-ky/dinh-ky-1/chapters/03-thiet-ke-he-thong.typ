#import "../../../common/tokens.typ": *

= THIẾT KẾ HỆ THỐNG

#let elabel(body) = box(fill: white, inset: (x: 2pt, y: 1pt), text(size: 7.5pt, body))
#show table.cell: set text(size: 10pt)

== Kiến trúc tổng thể

Hệ thống được chia thành 12 phân hệ theo ranh giới nghiệp vụ (Bảng 3.1). Mỗi phân hệ tự quản lý dữ liệu của mình và chỉ làm việc với phân hệ khác qua giao diện đã công bố, nên một quy tắc nghiệp vụ chỉ được hiện thực ở một chỗ. Ví dụ hạn mức đơn COD chỉ phân hệ giao dịch kiểm.

#figure(
  kind: table,
  caption: [Các phân hệ và tình trạng ở giai đoạn 1],
  table(
    columns: (1fr, 3fr, 1.1fr),
    inset: (x: 6pt, y: 3.6pt),
    align: (left + top, left + top, center + top),
    table.header([Phân hệ], [Chức năng], [Giai đoạn 1]),
    [Xác thực], [Gửi và kiểm mã OTP, quản lý phiên đăng nhập], [Đã làm],
    [Tài khoản], [Hồ sơ, tạm khóa, chặn người dùng khác], [Đã làm],
    [Nhân viên], [Tài khoản nhân viên, đăng nhập hai lớp, nhật ký thao tác], [Đã làm],
    [Ảnh], [Nhận ảnh tải lên, chuẩn hóa, xóa thông tin vị trí], [Đã làm],
    [Tin đăng], [Đăng, sửa, ẩn tin; danh mục; địa giới hành chính], [Đã làm],
    [Giao dịch], [Thương lượng giá, yêu cầu COD, đơn gửi hàng], [Đã làm, đơn tự gửi],
    [Trò chuyện], [Hội thoại theo tin đăng, báo tin mới tức thời], [Đã làm],
    [Vận chuyển], [Liên kết tài khoản GHTK, GHN của người bán, báo phí, tạo và hủy vận đơn, nhận trạng thái], [Giai đoạn 2],
    [Khám phá], [Tìm kiếm theo ngữ nghĩa và từ khóa, AI agent, lưu tin], [Giai đoạn 2],
    [Uy tín], [Đánh giá, ghi nhận sự cố, điểm uy tín, quyền, báo cáo vi phạm], [Giai đoạn 2],
    [eKYC], [Xác minh danh tính điện tử], [Giai đoạn 3],
    [Thông báo], [Thông báo trong ứng dụng và đẩy về điện thoại], [Giai đoạn 3],
  ),
)

Hình 3.1 trình bày kiến trúc theo tầng. Ứng dụng di động và bảng điều khiển nhân viên đi qua một cổng vào chung, nơi kiểm yêu cầu, xác thực người gọi và chặn yêu cầu gửi lặp. Tầng nền tảng lo phần dùng chung: chuyển sự kiện giữa các phân hệ và điều phối quy trình nhiều bước, để quy trình bị ngắt giữa chừng thì chạy tiếp đúng chỗ, không mất đơn và không tạo trùng vận đơn. Khi phát triển, cả 12 phân hệ chạy chung một chương trình; khi triển khai, từng nhóm phân hệ có thể tách ra chạy riêng mà không sửa nghiệp vụ.

#fig(
  [Kiến trúc tổng thể theo tầng],
  spacing: (0mm, 5mm),
  band((0, 0), "NGƯỜI DÙNG VÀ NHÂN VIÊN", (
    [Ứng dụng di động cho người mua, người bán], [Bảng điều khiển nhân viên],
  ), rong: 150mm, name: <t-app>),
  band((0, 1), "CỔNG VÀO", (
    [Kiểm yêu cầu theo đặc tả], [Xác thực người dùng, nhân viên], [Chống gửi lặp], [Báo tin mới tức thời],
  ), rong: 150mm, name: <t-gw>),
  band((0, 2), [PHÂN HỆ NGHIỆP VỤ], (
    [Xác thực], [Tài khoản], [Nhân viên], [Ảnh], [Tin đăng], [Giao dịch], [Trò chuyện],
    [Vận chuyển], [Khám phá], [Uy tín], [eKYC], [Thông báo],
  ), cot: 7, rong: 150mm, nen: headfill,
    ghi: [Hàng trên: đã hiện thực ở giai đoạn 1. Hàng dưới: giai đoạn 2 và 3.],
    name: <t-svc>),
  band((0, 3), "NỀN TẢNG DÙNG CHUNG", (
    [Chuyển sự kiện giữa phân hệ], [Điều phối quy trình nhiều bước], [Mô hình lỗi chung], [Quan trắc], [Công cụ kiểm thử],
  ), rong: 150mm, name: <t-plat>),
  band((0, 4), "HẠ TẦNG", (
    [Cơ sở dữ liệu có tìm kiếm vector], [Nền tảng điều phối quy trình], [Kho ảnh], [Bộ quan trắc],
  ), rong: 150mm, name: <t-infra>),
  band((0, 5), "HỆ THỐNG NGOÀI", (
    [SMS, email], [GHTK, GHN], [Mô hình ngôn ngữ lớn], [Đẩy thông báo], [Đối sánh khuôn mặt],
  ), rong: 150mm, name: <t-ext>),
  edge(<t-app>, <t-gw>, "-|>", rel[HTTPS]),
  edge(<t-gw>, <t-svc>, "-|>"),
  edge(<t-svc>, <t-plat>, "-|>"),
  edge(<t-plat>, <t-infra>, "-|>"),
  edge(<t-infra>, <t-ext>, "<|-|>", stroke: (dash: "dashed")),
)

== Luồng tiền và hàng của đơn COD đồng kiểm

Hình 3.2 cho thấy tiền và hàng đi giữa ba bên của một đơn COD đồng kiểm. Người mua chỉ trả tiền cho shipper sau khi xem hàng, hãng chuyển tiền thu hộ về tài khoản người bán, còn sàn chỉ ghi nhận trạng thái đơn để cập nhật tin đăng và uy tín (BR-08). Người mua từ chối nhận thì không mất gì, hàng quay về và phí hai chiều tính vào tài khoản hãng của người bán (BR-11).

#fig(
  [Luồng tiền và hàng của một đơn COD đồng kiểm],
  spacing: (42mm, 10mm),
  nt((0, 0), [Người bán]),
  ng((1, 0), [Hãng vận chuyển\ (shipper)]),
  nt((2, 0), [Người mua]),
  nr((1, 1.25), text(size: 9pt)[ShopNexus: cập nhật đơn, tin đăng\ và uy tín; không giữ, không hoàn tiền]),
  edge((0, 0), (1, 0), "-|>", bend: 28deg, elabel[1\. gửi hàng]),
  edge((1, 0), (2, 0), "-|>", bend: 28deg, elabel[2\. mang hàng tới,\ cho xem trước]),
  edge((2, 0), (1, 0), "-|>", bend: 28deg, stroke: (dash: "dashed"), elabel[3\. nhận: trả tiền hàng,\ phí ship; từ chối: không trả]),
  edge((1, 0), (0, 0), "-|>", bend: 28deg, stroke: (dash: "dashed"), elabel[4\. chuyển tiền thu hộ, hoặc\ trả hàng về và tính phí]),
  edge((1, 0), (1, 1.25), "-|>", stroke: (dash: "dotted"), elabel[trạng thái vận đơn], label-side: left, label-pos: 0.45),
)

Ở giai đoạn 1 chưa có kết nối với GHTK và GHN. Đơn COD là đơn tự gửi: người bán mang hàng ra hãng, nhập tên hãng, mã vận đơn và phí ship vào ứng dụng, người mua tự báo đã nhận hay không nhận. Đường trạng thái vận đơn ở Hình 3.2 sẽ có khi phân hệ vận chuyển được làm ở giai đoạn 2.

== Mô hình dữ liệu giai đoạn 1

Hình 3.3 là sơ đồ thực thể quan hệ của các phân hệ đã hiện thực, gom theo phân hệ sở hữu. Thông tin đăng nhập tách khỏi hồ sơ tài khoản; mỗi số điện thoại hoặc email chỉ thuộc một người. Mỗi người mua chỉ có một cuộc thương lượng trên một tin; một thương lượng có thể có nhiều đơn theo thời gian nhưng mỗi lúc chỉ mở một đơn. Liên kết giữa hai phân hệ khác nhau chỉ là mã tham chiếu.

#fig(
  [Sơ đồ thực thể quan hệ các phân hệ của giai đoạn 1],
  spacing: (12mm, 12mm),
  edge-stroke: 1pt + blue-s,
  label-wrapper: wlabel,

  nent((0, 0), <e-id>, [ĐỊNH DANH]),
  nent((0, 1), <e-cr>, [ĐĂNG NHẬP]),
  nent((0, 2), <e-se>, [PHIÊN]),
  nent((1, 1.5), <e-ac>, [TÀI KHOẢN]),
  nent((2, -0.6), <e-ca>, [DANH MỤC]),
  nent((2, 0.4), <e-li>, [TIN ĐĂNG]),
  nent((3, 0.4), <e-co>, [PHƯỜNG XÃ]),
  nent((4, 0.4), <e-pr>, [TỈNH THÀNH]),
  nent((2.7, 1.6), <e-de>, [THƯƠNG LƯỢNG]),
  nent((3.9, 1.6), <e-dm>, [NƯỚC TRẢ GIÁ]),
  nent((3.3, 2.6), <e-or>, [ĐƠN HÀNG]),
  nent((1, 3), <e-cv>, [HỘI THOẠI]),
  nent((2, 3), <e-ms>, [TIN NHẮN]),

  ngroup((<e-id>, <e-cr>, <e-se>)),
  gtitle((0, -0.5), [xác thực]),
  ngroup((<e-ac>,)),
  gtitle((1.3, 1.98), [tài khoản]),
  ngroup((<e-li>, <e-ca>, <e-co>, <e-pr>)),
  gtitle((3.5, -0.6), [tin đăng]),
  ngroup((<e-de>, <e-dm>, <e-or>)),
  gtitle((4.15, 2.6), [giao dịch]),
  ngroup((<e-cv>, <e-ms>)),
  gtitle((1.5, 3.5), [trò chuyện]),

  edge(<e-ac>, <e-cr>, "1-1", [có]),
  edge(<e-cr>, <e-id>, "1-n", [gồm]),
  edge(<e-ac>, <e-se>, "1-n", [mở]),
  edge(<e-ac>, <e-ac>, "n-n", bend: 130deg, loop-angle: 120deg, [chặn]),
  edge(<e-ac>, <e-li>, "1-n", [đăng bán], label-pos: 0.68),
  edge(<e-ca>, <e-li>, "1-n", [phân loại]),
  edge(<e-co>, <e-li>, "1-n", [đặt tại]),
  edge(<e-pr>, <e-co>, "1-n", [gồm]),
  edge(<e-li>, <e-de>, "1-n", [được thương lượng]),
  edge(<e-ac>, <e-de>, "1-n", [mua]),
  edge(<e-de>, <e-dm>, "1-n", [ghi]),
  edge(<e-de>, <e-or>, "1-n", [lên đơn]),
  edge(<e-ac>, <e-cv>, "n-n", [tham gia]),
  edge(<e-cv>, <e-ms>, "1-n", [chứa]),
)

== Thiết kế sơ bộ tìm kiếm và AI agent

Tìm kiếm và AI agent thuộc phân hệ khám phá, sẽ hiện thực ở giai đoạn 2. Mỗi lượt tìm chạy song song theo nghĩa của câu và theo từ khóa tiếng Việt, rồi gộp các danh sách kết quả theo thứ hạng [5] và ưu tiên nhẹ tin ở gần, của người bán có bậc cao. AI agent là một mô hình ngôn ngữ lớn được trao bộ công cụ chỉ đọc [12]: agent tách câu nói của người mua thành các bộ lọc như giá tối đa, khu vực, danh mục, rồi gọi tìm kiếm. Mỗi ràng buộc agent suy ra hiện thành nhãn để người mua sửa (BR-18). Agent được tối đa 4 vòng gọi công cụ; quá 8 giây hoặc gặp lỗi thì hệ thống tìm kiếm thường với câu gốc, nên người mua luôn nhận được kết quả.
