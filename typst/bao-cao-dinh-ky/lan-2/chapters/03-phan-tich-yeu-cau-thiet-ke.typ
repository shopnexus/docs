#import "../../../common/tokens.typ": *

= PHÂN TÍCH YÊU CẦU VÀ THIẾT KẾ HỆ THỐNG

== Phân tích và so sánh các công trình liên quan

=== Tổng quan thị trường thương mại điện tử C2C tại Việt Nam
Thị trường mua bán đồ cũ, hàng thanh lý và đồ thủ công cá nhân (C2C - Consumer-to-Consumer) tại Việt Nam đang phát triển mạnh mẽ nhờ sự gia tăng của xu hướng tiêu dùng bền vững và nhu cầu tối ưu tài chính cá nhân. Tuy nhiên, hoạt động giao dịch giữa các cá nhân không chuyên hiện nay vẫn phân mảnh trên nhiều nền tảng với những hạn chế lớn về an toàn tài chính, cơ chế giải quyết tranh chấp và công nghệ hỗ trợ tìm kiếm.

Việc nghiên cứu, đánh giá các mô hình giao dịch tiêu biểu hiện có (như Chợ Tốt, Facebook Marketplace và Shopee/Lazada) đóng vai trò nền tảng để xác định đúng "vùng trống" của thị trường, từ đó kiến trúc nền tảng một cách tối ưu nhất.

=== Phân tích các mô hình sàn giao dịch tiêu biểu
- *Chợ Tốt (chotot.com) - Mô hình sàn rao vặt (Classified Ads):*
  - *Ưu điểm:* Là nền tảng rao vặt đồ cũ lớn nhất Việt Nam với lưu lượng người dùng khổng lồ. Quy trình đăng tin bán rất nhanh chóng, giao diện đơn giản, phân loại tốt theo khu vực địa lý giúp người mua/bán dễ dàng kết nối trong bán kính gần.
  - *Hạn chế:* Bản chất của Chợ Tốt chủ yếu chỉ là bảng tin kết nối người mua và người bán tự liên hệ với nhau (qua số điện thoại hoặc khung chat đơn giản). Nền tảng thiếu một cơ chế bảo lãnh tài chính tạm giữ (Escrow) tích hợp sâu cho các giao dịch từ xa; hầu hết người mua phải thanh toán chuyển khoản trước (dễ bị lừa đảo lừa cọc) hoặc hẹn gặp mặt trực tiếp/ship COD tự phát (dễ gặp rủi ro "boom hàng", tốn phí vận chuyển). Khi sản phẩm nhận được không đúng mô tả hoặc hư hỏng, người mua hoàn toàn không có công cụ pháp lý hay đội ngũ điều phối viên nội bộ nào của sàn đứng ra phân xử và bảo vệ dòng tiền.
- *Facebook Marketplace & Các hội nhóm xã hội (Social C2C):*
  - *Ưu điểm:* Tận dụng mạng lưới xã hội khổng lồ có sẵn, tốc độ tương tác cực nhanh qua Messenger, thao tác đăng bán tiện lợi không tốn phí sàn.
  - *Hạn chế:* Hoàn toàn thiếu các chuẩn mực của một nền tảng TMĐT chuyên nghiệp: không có hệ thống quản lý đơn hàng, không có tích hợp cổng thanh toán an toàn, không có cơ chế giữ cọc hay chính sách hoàn tiền. Các hành vi gian lận, tài khoản ảo (clone) lừa đảo chuyển khoản diễn ra rất phổ biến mà không có cơ chế kiểm duyệt hay hạn chế.
- *Shopee / Lazada — Mô hình B2C bán chuyên (Managed Marketplace):*
  - *Ưu điểm:* Hệ sinh thái logistics, cổng thanh toán và chính sách bảo vệ người mua cực kỳ hoàn thiện (như Shopee Đảm Bảo).
  - *Hạn chế:* Được thiết kế tối ưu cho mô hình B2C hoặc nhà bán hàng chuyên nghiệp. Quy trình đăng ký gian hàng và đăng bán sản phẩm rất rườm rà (đòi hỏi cấu hình mã SKU, thông tin doanh nghiệp/thuế, thiết lập kho hàng chuyên sâu), kèm theo mức phí sàn và phí hoa hồng cao (thường từ 8% - 15%). Mô hình này không hề phù hợp cho một cá nhân thông thường chỉ muốn thanh lý nhanh 1–2 món đồ cũ cá nhân. Bên cạnh đó, cơ chế trả giá thường bị ràng buộc bởi các mã giảm giá/voucher cố định, thiếu sự linh hoạt thương lượng giá trực tiếp từng đơn hàng trong khung chat giữa hai cá nhân.

== Phân tích tác nhân và sơ đồ ngữ cảnh hệ thống

=== Phân tích các vai trò người dùng (Persona)
Hệ thống ShopNexus được thiết kế phục vụ cho ba nhóm đối tác nhân chính, với các mục tiêu nghiệp vụ, đặc tính hành vi và ranh giới phân quyền rõ rệt:
- *Người dùng phổ thông (User):* Là tác nhân có mật độ truy cập cao nhất, đóng vai trò kép vừa là người mua vừa là người bán cá nhân. Họ tương tác với hệ thống để đăng tải sản phẩm thanh lý, tìm kiếm món đồ phù hợp, trao đổi thương lượng giá trực tiếp qua chat, đặt hàng thanh toán an toàn qua cơ chế bảo lãnh tài chính tạm giữ (Escrow), và gửi khiếu nại hoàn tiền khi xảy ra sự cố.
- *Điều phối viên (Moderator):* Là đội ngũ nhân sự nội bộ chịu trách nhiệm duy trì tính công bằng và an toàn giao dịch trên toàn sàn. Moderator không tham gia trực tiếp vào việc mua bán mà thực hiện các nghiệp vụ: kiểm duyệt bài đăng vi phạm, thẩm định hồ sơ khiếu nại hoàn tiền mà hai bên không tự giải quyết được, phân xử tranh chấp dựa trên chứng cứ đa phương tiện (video mở hộp, ảnh chụp kiện hàng), và hỗ trợ chăm sóc khách hàng.
- *Quản trị viên tối cao (Super Admin):* Là tài khoản quản trị viên cấp cao nhất được cấu hình định danh duy nhất từ hệ thống. Super Admin toàn quyền thiết lập các tham số hệ thống (thời gian giữ Escrow tối đa, tỷ lệ phí sàn, ngưỡng cảnh báo tự động), quản lý vòng đời tài khoản Moderator (tạo mới, khóa, phân quyền), và theo dõi báo cáo đối soát dòng tiền tổng thể của sàn.

=== Các hệ thống ngoại vi và đối tác tích hợp
Để bảo đảm tính trọn vẹn của quy trình thương mại điện tử C2C, hệ thống thiết lập tích hợp liên thông với các đối tác hạ tầng công nghệ ngoại vi:
- *Cổng thanh toán ngoại vi (SePay / Stripe):* Tiếp nhận yêu cầu khởi tạo link thanh toán, xử lý giao dịch nạp tiền/thanh toán chuyển khoản ngân hàng từ người mua, và gửi phản hồi trạng thái giao dịch qua webhook bảo mật về sàn.
- *Đối tác Vận chuyển (GHN / GHTK):* Tiếp nhận thông tin địa chỉ lấy hàng và giao hàng để tính toán phí ship động (real-time quotation), khởi tạo mã vận đơn (shipping order), và liên tục đẩy sự kiện hành trình giao nhận về hệ thống để kích hoạt các mốc nghiệp vụ.
- *Hệ thống sự kiện thời gian thực (NATS JetStream & SSE):* Trục thông điệp NATS đóng vai trò là nền tảng xử lý sự kiện bất đồng bộ nội bộ, kết hợp với giao thức Server-Sent Events (SSE) để điều hướng tin nhắn chat, trạng thái đơn hàng và các phán quyết tranh chấp đến thiết bị di động/trình duyệt của người dùng với độ trễ dưới mili giây.

=== Sơ đồ ngữ cảnh hệ thống (System Context Diagram)
Sơ đồ ngữ cảnh mô tả ranh giới nghiệp vụ của nền tảng ShopNexus C2C và các dòng thông tin liên tác với môi trường bên ngoài.

#fig(
  [Sơ đồ ngữ cảnh hệ thống ShopNexus C2C (System Context Diagram)],
  spacing: (30mm, 18mm),

  // Tác nhân người dùng (hàng trên)
  nt((0, 0), [*Người dùng (User)*\ Mua / Bán C2C]),
  nt((1, 0), [*Điều phối viên*\ (Moderator — Phân xử)]),
  nt((2, 0), [*Quản trị viên*\ (Admin — Đối soát)]),

  // Hệ thống trung tâm
  ncore((1, 1), [HỆ THỐNG SHOPNEXUS C2C\ \ Sàn giao dịch · Ví Escrow\ Chat realtime · Restate Engine], width: 58mm),

  // Hệ thống ngoại vi (hàng dưới)
  ng((0, 2), [*Cổng thanh toán*\ (SePay / Stripe)]),
  ng((1, 2), [*Đối tác vận chuyển*\ (GHN / GHTK)]),
  ng((2, 2), [*Hạ tầng sự kiện*\ (NATS JetStream / SSE)]),

  edge((0, 0), (1, 1), "<|-|>", text(size: 8pt)[Đăng bán, chat, Escrow], label-pos: 0.5, label-side: right),
  edge((1, 0), (1, 1), "<|-|>", text(size: 8pt)[Thẩm định, phán quyết], label-pos: 0.42, label-side: left),
  edge((2, 0), (1, 1), "<|-|>", text(size: 8pt)[Cấu hình, đối soát], label-pos: 0.35, label-side: left),

  edge((1, 1), (0, 2), "<|-|>", text(size: 8pt)[Thanh toán, webhook], label-pos: 0.6, label-side: right),
  edge((1, 1), (1, 2), "<|-|>", text(size: 8pt)[Phí ship, hành trình], label-pos: 0.55, label-side: left),
  edge((1, 1), (2, 2), "<|-|>", text(size: 8pt)[Sự kiện, SSE realtime], label-pos: 0.5, label-side: left),
)

== Đặc tả ca sử dụng (Use Cases) và quy tắc nghiệp vụ (Business Rules)

=== Danh mục ca sử dụng (Use Case Portfolio)
Toàn bộ nghiệp vụ của sàn thương mại điện tử C2C được phân rã thành *17 ca sử dụng* được đánh mã thống nhất `UC-001` … `UC-017`, kèm *hai ca sử dụng con dùng chung* (`UC-S1`, `UC-S2`) được nhiều ca sử dụng khác gọi tới theo quan hệ «include». Mỗi ca sử dụng biểu diễn một *mục tiêu hoàn chỉnh* của tác nhân (không phải một bước thao tác đơn lẻ), là cơ sở để trích xuất các yêu cầu chức năng ở mục 3.5.

#figure(
  caption: [Danh mục ca sử dụng hệ thống ShopNexus C2C (Use Case Catalog)],
  table(
    columns: (0.62fr, 1.55fr, 1.15fr, 2.5fr, 0.62fr),
    align: (center + horizon, left + horizon, left + horizon, left + horizon, center + horizon),
    table.header([Mã], [Tên ca sử dụng], [Tác nhân chính], [Mô tả ngắn gọn], [Ưu tiên]),

    table.cell(colspan: 5, align: left)[*Nhóm A — Định danh và phân quyền*],
    [UC-001], [Đăng ký tài khoản], [User], [Người dùng tự tạo tài khoản công khai với vai trò `User`, đồng thời khởi tạo ví điện tử nội bộ.], [Cao],
    [UC-002], [Đăng nhập], [User, Moderator, Admin], [Xác thực tài khoản, phát hành cặp Access/Refresh Token và điều hướng theo vai trò.], [Cao],
    [UC-010], [Cấp phát tài khoản Moderator], [Admin], [Admin tạo tài khoản Moderator, gửi mật khẩu tạm thời qua email; Moderator không được tự đăng ký.], [Cao],

    table.cell(colspan: 5, align: left)[*Nhóm B — Đăng bán và khám phá sản phẩm*],
    [UC-003], [Đăng bán sản phẩm C2C], [User (người bán)], [Đăng tải sản phẩm cá nhân, chọn chế độ giá (cố định/thương lượng) và phương án phân bổ phí vận chuyển.], [Cao],
    [UC-011], [Tìm kiếm và duyệt sản phẩm], [User (người mua)], [Truy vấn sản phẩm bằng từ khóa ngôn ngữ tự nhiên kết hợp bộ lọc, nhận danh sách gợi ý cá nhân hóa.], [Cao],
    [UC-004], [Nhắn tin và thương lượng giá], [User], [Trò chuyện thời gian thực, gửi ảnh/video thực tế và thương lượng giá qua Thẻ đề xuất giá (Offer Card).], [Cao],

    table.cell(colspan: 5, align: left)[*Nhóm C — Giao dịch và dòng tiền tạm giữ*],
    [UC-005], [Đặt hàng và thanh toán Escrow], [User (người mua)], [Chốt địa chỉ, tính phí vận chuyển động, thanh toán qua cổng ngân hàng; tiền được khóa trong ví tạm giữ.], [Cao],
    [UC-012], [Người bán xử lý mục chờ], [User (người bán)], [Xem các mục chờ đã được thanh toán, xác nhận để tạo đơn hàng + vận đơn hoặc từ chối để giải phóng tồn kho.], [Cao],
    [UC-014], [Xác nhận nhận hàng], [User (người mua)], [Xác nhận đã nhận hàng kèm bằng chứng ảnh/video mở hộp, kích hoạt bộ đếm ngược 72 giờ trước khi giải ngân.], [Cao],
    [UC-013], [Ví điện tử và rút tiền], [User], [Theo dõi số dư khả dụng và số dư tạm giữ, gửi yêu cầu rút phần khả dụng về tài khoản ngân hàng.], [Cao],

    table.cell(colspan: 5, align: left)[*Nhóm D — Khiếu nại, tranh chấp và hậu giao dịch*],
    [UC-006], [Yêu cầu trả hàng / hoàn tiền], [User (người mua)], [Khiếu nại hàng lỗi hoặc sai mô tả kèm bằng chứng trong thời hạn 72 giờ, tạm dừng bộ đếm giải ngân.], [Cao],
    [UC-007], [Khiếu nại và tranh chấp], [User (người bán)], [Người bán từ chối hoàn tiền kèm bằng chứng đối chứng; hồ sơ được nâng cấp thành vụ tranh chấp.], [Cao],
    [UC-008], [Phân xử tranh chấp], [Moderator], [Thẩm định bằng chứng hai phía và ra phán quyết hoàn tiền cho người mua hoặc giải ngân cho người bán.], [Cao],
    [UC-009], [Đánh giá và phản hồi], [User], [Đánh giá sao, viết nhận xét sau khi đơn hàng hoàn thành; hệ thống cập nhật điểm uy tín.], [T. bình],

    table.cell(colspan: 5, align: left)[*Nhóm E — Kiểm duyệt nội dung và quản trị sàn*],
    [UC-016], [Báo cáo bài đăng vi phạm], [User], [Báo cáo bài đăng nghi vấn (hàng cấm, lừa đảo, sai mô tả) kèm lý do; báo cáo vượt ngưỡng sẽ vào hàng đợi kiểm duyệt.], [T. bình],
    [UC-015], [Kiểm duyệt bài đăng khả nghi], [Moderator], [Thẩm định bài đăng bị bộ lọc tự động gắn cờ hoặc bị người dùng báo cáo, quyết định gỡ bài hoặc khôi phục.], [Cao],
    [UC-017], [Cấu hình tham số sàn và đối soát], [Admin], [Thiết lập thời hạn Escrow, tỷ lệ phí sàn, ngưỡng cảnh báo; đối soát bảng cân đối dòng tiền toàn hệ thống.], [Cao],

    table.cell(colspan: 5, align: left)[*Nhóm F — Ca sử dụng con dùng chung («include»)*],
    [UC-S1], [Tải lên bằng chứng đa phương tiện], [User], [Tải lên video mở hộp / ảnh chứng minh vào lưu trữ đối tượng, gắn với đơn hàng hoặc hồ sơ khiếu nại.], [Cao],
    [UC-S2], [Ghi nhật ký kiểm toán], [(Hệ thống)], [Ghi bản ghi chỉ-thêm-mới cho mọi quyết định nghiệp vụ và biến động dòng tiền phục vụ đối soát.], [Cao],
  )
)

#note[*Quy ước đánh mã.* Bộ mã `UC-001` … `UC-013` được giữ nguyên từ giai đoạn phân tích ở báo cáo lần 1 nhằm bảo toàn tính truy vết của các yêu cầu chức năng `REQ-001` … `REQ-038` đã ban hành. Bốn ca sử dụng phát sinh trong giai đoạn hai (xác nhận nhận hàng, kiểm duyệt bài đăng, báo cáo bài đăng, cấu hình – đối soát) được *bổ sung tiếp nối* thành `UC-014` … `UC-017` thay vì đánh số lại toàn bộ danh mục; vì vậy thứ tự mã không phản ánh thứ tự thời gian của luồng nghiệp vụ, thứ tự này được thể hiện ở các sơ đồ hoạt động và sơ đồ trình tự tại mục 3.4.]

=== Sơ đồ ca sử dụng (Use Case Diagram)
Do số lượng ca sử dụng vượt ngưỡng đọc hiểu của một sơ đồ đơn, danh mục được tách thành hai sơ đồ theo phân hệ nghiệp vụ. Ký hiệu sử dụng trong cả hai sơ đồ: hình tròn là *tác nhân*, hình viên thuốc là *ca sử dụng*, khung nét đứt là *ranh giới hệ thống*; đường liền là quan hệ *liên kết* (association) giữa tác nhân và ca sử dụng, đường nét đứt kèm nhãn thể hiện quan hệ «include» (bao hàm), «extend» (mở rộng) hoặc «trigger» (kích hoạt).

#fig(
  [Sơ đồ ca sử dụng phân hệ Giao dịch C2C (UC-001 … UC-014)],
  spacing: (33mm, 11mm),
  node(enclose: (<a1>, <a2>, <a3>, <a4>, <a5>, <a6>, <a7>, <a8>, <a9>, <a10>, <as1>),
    inset: 15pt, stroke: (paint: ink, dash: "dashed", thickness: 0.9pt),
    fill: none, corner-radius: 8pt),
  node((2, -1.15), text(size: 9pt, weight: 700)[Ranh giới hệ thống — Phân hệ Giao dịch C2C],
    fill: white, stroke: none),

  nt((2, -0.4), [UC-001 · Đăng ký tài khoản], name: <a1>),
  nt((2, 0.4), [UC-002 · Đăng nhập], name: <a2>),
  nt((2, 1.2), [UC-011 · Tìm kiếm & duyệt sản phẩm], name: <a3>),
  nt((2, 2.0), [UC-003 · Đăng bán sản phẩm C2C], name: <a4>),
  nt((2, 2.8), [UC-004 · Nhắn tin & thương lượng giá], name: <a5>),
  nt((2, 3.6), [UC-005 · Đặt hàng & thanh toán Escrow], name: <a6>),
  nt((2, 4.4), [UC-012 · Người bán xử lý mục chờ], name: <a7>),
  nt((2, 5.2), [UC-014 · Xác nhận nhận hàng], name: <a8>),
  nt((2, 6.0), [UC-009 · Đánh giá & phản hồi], name: <a9>),
  nt((2, 6.8), [UC-013 · Ví điện tử & rút tiền], name: <a10>),
  nt((3.1, 5.7), text(size: 8pt)[UC-S1 · Tải lên\ bằng chứng], name: <as1>),

  nact((0, 3.2), [Người dùng\ (User)]),
  nact((4.25, 3.9), text(size: 7pt)[Cổng thanh toán\ (SePay/Stripe)]),
  nact((4.25, 5.1), text(size: 7pt)[Đối tác vận chuyển\ (GHN/GHTK)]),

  edge((0, 3.2), <a1>, stroke: 0.7pt + blue-s),
  edge((0, 3.2), <a2>, stroke: 0.7pt + blue-s),
  edge((0, 3.2), <a3>, stroke: 0.7pt + blue-s),
  edge((0, 3.2), <a4>, stroke: 0.7pt + blue-s),
  edge((0, 3.2), <a5>, stroke: 0.7pt + blue-s),
  edge((0, 3.2), <a6>, stroke: 0.7pt + blue-s),
  edge((0, 3.2), <a7>, stroke: 0.7pt + blue-s),
  edge((0, 3.2), <a8>, stroke: 0.7pt + blue-s),
  edge((0, 3.2), <a9>, stroke: 0.7pt + blue-s),
  edge((0, 3.2), <a10>, stroke: 0.7pt + blue-s),

  edge((4.25, 3.9), <a6>, stroke: 0.7pt + teal),
  edge((4.25, 3.9), <a10>, stroke: 0.7pt + teal),
  edge((4.25, 5.1), <a7>, stroke: 0.7pt + teal),
  edge((4.25, 5.1), <a8>, stroke: 0.7pt + teal),

  edge(<a8>, <as1>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<a5>, <a6>, "-|>", stroke: (dash: "dashed"), label-side: right,
    text(size: 7pt)[«trigger» chấp nhận Offer Card]),
  edge(<a6>, <a7>, "-|>", stroke: (dash: "dashed"), label-side: right,
    text(size: 7pt)[«trigger» sinh mục chờ]),
)

#fig(
  [Sơ đồ ca sử dụng phân hệ Khiếu nại — Kiểm duyệt — Quản trị (UC-006 … UC-017)],
  spacing: (34mm, 12mm),
  node(enclose: (<b1>, <b2>, <b3>, <b4>, <b5>, <b6>, <b7>, <bs1>, <bs2>),
    inset: 15pt, stroke: (paint: ink, dash: "dashed", thickness: 0.9pt),
    fill: none, corner-radius: 8pt),
  node((2, -1.0), text(size: 9pt, weight: 700)[Ranh giới hệ thống — Phân hệ Khiếu nại & Quản trị],
    fill: white, stroke: none),

  nt((2, -0.25), [UC-006 · Yêu cầu trả hàng / hoàn tiền], name: <b1>),
  nt((2, 0.75), [UC-007 · Khiếu nại và tranh chấp], name: <b2>),
  nt((2, 1.75), [UC-008 · Phân xử tranh chấp], name: <b3>),
  nt((2, 2.75), [UC-016 · Báo cáo bài đăng vi phạm], name: <b4>),
  nt((2, 3.75), [UC-015 · Kiểm duyệt bài đăng khả nghi], name: <b5>),
  nt((2, 4.75), [UC-010 · Cấp phát tài khoản Moderator], name: <b6>),
  nt((2, 5.75), [UC-017 · Cấu hình tham số & đối soát], name: <b7>),
  nt((3.15, 0.25), text(size: 8pt)[UC-S1 · Tải lên\ bằng chứng], name: <bs1>),
  nt((3.15, 3.9), text(size: 8pt)[UC-S2 · Ghi nhật ký\ kiểm toán], name: <bs2>),

  nact((0, 1.4), [Người dùng\ (User)]),
  nact((4.35, 2.6), [Điều phối viên\ (Moderator)]),
  nact((4.35, 5.3), [Quản trị viên\ (Admin)]),

  edge((0, 1.4), <b1>, stroke: 0.7pt + blue-s),
  edge((0, 1.4), <b2>, stroke: 0.7pt + blue-s),
  edge((0, 1.4), <b4>, stroke: 0.7pt + blue-s),
  edge((4.35, 2.6), <b3>, stroke: 0.7pt + teal),
  edge((4.35, 2.6), <b5>, stroke: 0.7pt + teal),
  edge((4.35, 5.3), <b6>, stroke: 0.7pt + red),
  edge((4.35, 5.3), <b7>, stroke: 0.7pt + red),

  edge(<b2>, <b1>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«extend»]),
  edge(<b1>, <bs1>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<b2>, <bs1>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<b3>, <bs2>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<b5>, <bs2>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<b7>, <bs2>, "-|>", stroke: (dash: "dashed"), text(size: 7pt)[«include»]),
  edge(<b4>, <b5>, "-|>", stroke: (dash: "dashed"), label-side: left,
    text(size: 7pt)[«trigger» vượt ngưỡng báo cáo]),
)

=== Đặc tả chi tiết các ca sử dụng trọng yếu
Mười ca sử dụng có độ phức tạp hoặc mức rủi ro nghiệp vụ cao nhất — tập trung ở luồng dòng tiền tạm giữ, khiếu nại và kiểm duyệt — được đặc tả đầy đủ theo mẫu *fully dressed* của UML: tác nhân, điều kiện trước, luồng chính, luồng thay thế, luồng ngoại lệ, điều kiện sau, quy tắc nghiệp vụ và yêu cầu chức năng liên quan. Các ca sử dụng còn lại (UC-001, UC-002, UC-009, UC-010, UC-011, UC-016, UC-017) có luồng tuyến tính đơn giản nên chỉ giữ ở mức mô tả ngắn trong danh mục ca sử dụng tại mục 3.3.1.

#ucspec("UC-003", "Đăng bán sản phẩm C2C",
  [Tác nhân chính], [User (vai người bán)],
  [Tác nhân phụ], [Bộ lọc nội dung tự động (nội bộ); dịch vụ `analytic` sinh vector nhúng],
  [Mô tả], [Người bán đăng tải một sản phẩm cá nhân lên sàn, thiết lập chế độ giá và phương án phân bổ phí vận chuyển. Bài đăng chỉ hiển thị công khai sau khi vượt qua bước quét nội dung tự động.],
  [Điều kiện trước], [Người bán đã đăng nhập (UC-002) và đã xác thực thông tin cá nhân cơ bản.],
  [Luồng chính], [
    1. Người bán chọn chức năng "Đăng bán sản phẩm".
    2. Hệ thống hiển thị biểu mẫu: hình ảnh, tên, mô tả, tình trạng, danh mục ba cấp.
    3. Người bán tải lên tối thiểu một hình ảnh và điền các trường bắt buộc.
    4. Người bán chọn chế độ giá: *Giá cố định* hoặc *Giá thương lượng*.
    5. Người bán chọn phương án phí vận chuyển: *người mua trả* (cộng vào hóa đơn khi thanh toán) hoặc *người bán trả* (trừ vào số tiền thực nhận khi giải ngân).
    6. Người bán xác nhận đăng bài.
    7. Hệ thống chạy bộ lọc tự động theo từ khóa và đặc trưng hình ảnh để phát hiện dấu hiệu hàng cấm.
    8. Không phát hiện dấu hiệu vi phạm: hệ thống lưu bài đăng ở trạng thái `Active`, sinh vector nhúng bge-m3 và đưa vào chỉ mục tìm kiếm.
  ],
  [Luồng thay thế], [
    *[7a] Bộ lọc phát hiện dấu hiệu khả nghi:* hệ thống lưu bài đăng ở trạng thái `Chờ kiểm duyệt` (không hiển thị công khai), tạo yêu cầu kiểm duyệt và chuyển sang UC-015.

    *[4a] Chế độ Giá thương lượng:* hệ thống khóa nút "Mua ngay" trên trang chi tiết, người mua buộc phải thương lượng qua UC-004 (BR-015).
  ],
  [Luồng ngoại lệ], [
    *[3a] Thiếu trường bắt buộc hoặc giá nhỏ hơn hoặc bằng 0:* hệ thống từ chối lưu, hiển thị lỗi kiểm tra dữ liệu tại từng trường (REQ-012).

    *[3b] Tải ảnh thất bại (quá dung lượng, sai định dạng):* hệ thống báo lỗi và giữ nguyên dữ liệu đã nhập trong biểu mẫu.
  ],
  [Điều kiện sau], [Bài đăng tồn tại ở trạng thái `Active` (đã lên chỉ mục tìm kiếm) hoặc `Chờ kiểm duyệt` (đang trong hàng đợi của Moderator).],
  [Quy tắc nghiệp vụ], [BR-012, BR-014, BR-015, BR-017],
  [Yêu cầu liên quan], [REQ-010, REQ-011, REQ-012],
  [Yêu cầu đặc biệt], [Bước quét tự động phải hoàn tất trong vòng 3 giây; nếu bộ lọc quá tải, bài đăng được xếp mặc định vào trạng thái `Chờ kiểm duyệt` (nguyên tắc an toàn trước).],
  [Tần suất sử dụng], [Cao — ước tính vài trăm lượt mỗi ngày ở giai đoạn đầu vận hành.],
)

#ucspec("UC-004", "Nhắn tin và thương lượng giá qua Offer Card",
  [Tác nhân chính], [User (người mua và người bán)],
  [Tác nhân phụ], [Hạ tầng đẩy sự kiện thời gian thực (NATS JetStream / SSE)],
  [Mô tả], [Hai người dùng trao đổi trực tiếp về sản phẩm và thống nhất mức giá cho sản phẩm ở chế độ *Giá thương lượng*. Sự đồng thuận được vật chất hóa bằng một Thẻ đề xuất giá (Offer Card) có hiệu lực xác định.],
  [Điều kiện trước], [Cả hai bên đã đăng nhập; sản phẩm đang ở trạng thái `Active`.],
  [Luồng chính], [
    1. Người mua mở trang chi tiết một sản phẩm Giá thương lượng và chọn "Thương lượng".
    2. Hệ thống khởi tạo (hoặc mở lại) hội thoại gắn với định danh sản phẩm và thiết lập kênh thời gian thực cho hai bên.
    3. Hai bên trao đổi tin nhắn, ảnh và video thực tế của sản phẩm.
    4. Người mua nhấn "Yêu cầu đề xuất giá".
    5. Người bán chọn "Tạo Offer Card", nhập đơn giá mới và lý do giảm giá cụ thể.
    6. Hệ thống phát hành Offer Card vào hội thoại ở trạng thái `Chờ duyệt`, đặt hạn hiệu lực 24 giờ.
    7. Người mua nhấn "Chấp nhận".
    8. Hệ thống chuyển Offer Card sang `Đã chấp nhận`, sinh mục chờ (mục hàng chưa thanh toán) với đúng đơn giá đã thỏa thuận và điều hướng người mua sang UC-005.
  ],
  [Luồng thay thế], [
    *[7a] Người mua nhấn "Từ chối":* Offer Card chuyển sang `Đã từ chối`; hai bên có thể tiếp tục thương lượng và phát hành thẻ mới.

    *[7b] Quá 24 giờ không phản hồi:* hệ thống tự động chuyển thẻ sang `Hết hiệu lực` (BR-021).

    *[6a] Người bán sửa giá gốc hoặc sản phẩm đã bán cho người khác:* thẻ bị thu hồi (`Revoked`) ngay lập tức.
  ],
  [Luồng ngoại lệ], [
    *[2a] Mất kết nối thời gian thực:* giao diện chuyển sang chế độ tải lại định kỳ và hiển thị trạng thái "đang kết nối lại"; tin nhắn đã gửi không bị mất do được ghi bền trước khi phát tán.

    *[5a] Đơn giá đề xuất nhỏ hơn hoặc bằng 0 hoặc thiếu lý do:* hệ thống từ chối phát hành thẻ (BR-016).
  ],
  [Điều kiện sau], [Toàn bộ hội thoại và vòng đời Offer Card được lưu bền; nếu thẻ được chấp nhận, tồn tại một mục chờ mang đơn giá đã thương lượng.],
  [Quy tắc nghiệp vụ], [BR-015, BR-016, BR-021],
  [Yêu cầu liên quan], [REQ-013, REQ-014, REQ-015, REQ-016],
  [Yêu cầu đặc biệt], [Độ trễ đẩy tin nhắn tới thiết bị đối phương dưới 1 giây trong điều kiện mạng bình thường (NFR-019).],
  [Tần suất sử dụng], [Rất cao — là kênh tương tác chính trước mỗi giao dịch thương lượng.],
)

#ucspec("UC-005", "Đặt hàng và thanh toán tạm giữ (Escrow)",
  [Tác nhân chính], [User (vai người mua)],
  [Tác nhân phụ], [Cổng thanh toán (SePay/Stripe), đối tác vận chuyển (GHN/GHTK), dịch vụ `inventory`],
  [Mô tả], [Người mua hoàn tất đặt hàng và thanh toán trực tuyến. Tiền không chuyển trực tiếp cho người bán mà bị khóa trong ví tạm giữ của sàn cho đến khi điều kiện giải ngân được thỏa mãn.],
  [Điều kiện trước], [Người mua đã đăng nhập; sản phẩm ở trạng thái `Active`; nếu là sản phẩm Giá thương lượng thì đã có Offer Card `Đã chấp nhận` (UC-004).],
  [Luồng chính], [
    1. Người mua chọn "Mua ngay" (giá cố định) hoặc đến từ Offer Card đã chấp nhận (giá thương lượng).
    2. Hệ thống hiển thị trang đặt hàng, yêu cầu chọn hoặc nhập địa chỉ giao nhận.
    3. Hệ thống gọi API đối tác vận chuyển để lấy báo giá phí ship động và tính tổng tiền phải trả, có cộng phí ship nếu người bán chọn phương án "người mua trả" (BR-012).
    4. Hệ thống yêu cầu dịch vụ `inventory` giữ chỗ tồn kho theo serial/SKU.
    5. Người mua xác nhận và được chuyển sang cổng thanh toán để chuyển khoản hoặc quét mã QR.
    6. Cổng thanh toán gửi webhook xác nhận giao dịch thành công về hệ thống.
    7. Luồng bền (durable) trên Restate ghi nhật ký, khóa số tiền vào ví tạm giữ và tạo mục chờ ở trạng thái `Đã thanh toán`.
    8. Hệ thống phát sự kiện thông báo mục chờ mới cho người bán (chuyển sang UC-012).
  ],
  [Luồng thay thế], [
    *[3a] Đối tác vận chuyển không phản hồi:* hệ thống dùng bảng phí ship mặc định theo khu vực và ghi cảnh báo vận hành.

    *[5a] Người mua chọn thanh toán bằng số dư ví khả dụng:* bỏ qua bước gọi cổng thanh toán, ghi bút toán chuyển nội bộ từ ví khả dụng sang ví tạm giữ.
  ],
  [Luồng ngoại lệ], [
    *[6a] Thanh toán thất bại hoặc bị hủy giữa chừng:* mục chờ giữ trạng thái `Chờ thanh toán` trong 24 giờ; quá hạn hệ thống tự hủy và giải phóng tồn kho đã giữ (REQ-020).

    *[6b] Webhook đến trễ hoặc không đến:* tác vụ đối soát định kỳ chủ động truy vấn trạng thái giao dịch tại cổng thanh toán để đóng luồng (NFR-015).

    *[7a] Dịch vụ bị khởi động lại giữa luồng:* Restate phục hồi từ bước cuối đã ghi nhật ký, không khóa tiền hai lần (NFR-017).
  ],
  [Điều kiện sau], [Số tiền của người mua bị khóa an toàn trong ví tạm giữ; tồn kho đã được giữ chỗ; người bán đã nhận thông báo.],
  [Quy tắc nghiệp vụ], [BR-003, BR-012, BR-014, BR-015, BR-022],
  [Yêu cầu liên quan], [REQ-017, REQ-018, REQ-019, REQ-020, REQ-033],
  [Yêu cầu đặc biệt], [Thao tác khởi tạo thanh toán phải bảo đảm tính lũy đẳng (idempotency) theo khóa giao dịch để tránh trừ tiền hai lần khi người dùng bấm lặp.],
  [Tần suất sử dụng], [Rất cao — là ca sử dụng sinh doanh thu chính của hệ thống.],
)

#ucspec("UC-012", "Người bán xử lý mục chờ",
  [Tác nhân chính], [User (vai người bán)],
  [Tác nhân phụ], [Đối tác vận chuyển (GHN/GHTK), dịch vụ `inventory`],
  [Mô tả], [Người bán xem các mục hàng đã được người mua thanh toán, xác nhận để hệ thống tạo đơn hàng chính thức kèm vận đơn, hoặc từ chối để giải phóng tồn kho và hoàn tiền.],
  [Điều kiện trước], [Tồn tại tối thiểu một mục chờ ở trạng thái `Đã thanh toán` thuộc về người bán.],
  [Luồng chính], [
    1. Người bán mở danh sách "Mục chờ xử lý".
    2. Hệ thống hiển thị từng mục kèm sản phẩm, số lượng, địa chỉ giao và báo giá phí vận chuyển.
    3. Người bán chọn các mục cần gộp vào một đơn và xem trước phí vận chuyển.
    4. Người bán nhấn "Xác nhận".
    5. Hệ thống tạo đơn hàng chính thức, gọi API đối tác vận chuyển sinh mã vận đơn và thu phí xác nhận theo phương án phân bổ phí ship.
    6. Hệ thống chuyển đơn sang trạng thái `Đang giao` và thông báo mã vận đơn cho người mua.
  ],
  [Luồng thay thế], [
    *[4a] Người bán nhấn "Từ chối":* hệ thống giải phóng tồn kho đã giữ, hoàn 100% tiền tạm giữ cho người mua và đóng mục chờ.
  ],
  [Luồng ngoại lệ], [
    *[4b] Người bán không xử lý trong thời hạn quy định:* hệ thống tự động từ chối mục chờ, giải phóng tồn kho và hoàn tiền cho người mua (REQ-035, BR-024).

    *[5a] Gọi API tạo vận đơn thất bại:* hệ thống thử lại theo cơ chế lùi thời gian; nếu vẫn thất bại, đơn giữ trạng thái `Chờ tạo vận đơn` và sinh cảnh báo vận hành (NFR-001).
  ],
  [Điều kiện sau], [Tồn tại đơn hàng chính thức ở trạng thái `Đang giao` kèm mã vận đơn, hoặc mục chờ đã bị từ chối và tiền đã hoàn.],
  [Quy tắc nghiệp vụ], [BR-011, BR-012, BR-024],
  [Yêu cầu liên quan], [REQ-033, REQ-034, REQ-035],
  [Yêu cầu đặc biệt], [Việc giải phóng tồn kho và hoàn tiền phải nằm trong cùng một luồng bền để không xảy ra trạng thái "đã hoàn tiền nhưng tồn kho vẫn bị giữ".],
  [Tần suất sử dụng], [Rất cao — mỗi giao dịch đều đi qua ca sử dụng này.],
)

#ucspec("UC-014", "Xác nhận nhận hàng",
  [Tác nhân chính], [User (vai người mua)],
  [Tác nhân phụ], [Đối tác vận chuyển (cập nhật hành trình), lưu trữ đối tượng (bằng chứng)],
  [Mô tả], [Sau khi nhận hàng vật lý, người mua chủ động xác nhận trên hệ thống kèm bằng chứng ảnh/video mở hộp. Hành động này là mốc khởi động bộ đếm ngược 72 giờ trước khi tiền được giải ngân cho người bán.],
  [Điều kiện trước], [Đơn hàng ở trạng thái `Đang giao` hoặc `Đã giao`; tiền vẫn đang bị khóa trong ví tạm giữ.],
  [Luồng chính], [
    1. Người mua mở chi tiết đơn hàng và chọn "Xác nhận đã nhận hàng".
    2. Hệ thống yêu cầu tải lên tối thiểu một video mở hộp liền mạch hoặc ảnh sản phẩm thực tế (bao hàm UC-S1).
    3. Người mua tải bằng chứng và xác nhận.
    4. Hệ thống lưu bằng chứng, chuyển đơn sang trạng thái `Đã nhận hàng — chờ đối chiếu` và khởi động bộ đếm bền 72 giờ trên Restate.
    5. Hệ thống thông báo cho người bán về mốc giải ngân dự kiến.
    6. Hết 72 giờ mà không có yêu cầu hoàn tiền, hệ thống tự động giải ngân: chuyển tiền từ ví tạm giữ sang ví khả dụng của người bán sau khi trừ phí sàn và phí ship (nếu người bán chịu phí).
  ],
  [Luồng thay thế], [
    *[1a] Người mua không xác nhận sau khi vận chuyển báo "Đã giao":* hệ thống nhắc qua thông báo sau 2 ngày; nếu sau 7 ngày vẫn không phản hồi, hệ thống tự động xác nhận thay người mua và bắt đầu đếm ngược, tránh treo dòng tiền vô thời hạn (BR-025).

    *[6a] Có yêu cầu hoàn tiền trong thời hạn:* bộ đếm bị tạm dừng, luồng chuyển sang UC-006.
  ],
  [Luồng ngoại lệ], [
    *[3a] Tải bằng chứng thất bại:* hệ thống không cho hoàn tất bước xác nhận, giữ nguyên trạng thái đơn.

    *[4a] Hệ thống khởi động lại trong lúc đếm ngược:* bộ đếm là bộ định thời bền của Restate nên được phục hồi cùng luồng, không bị mất mốc thời gian (NFR-017).
  ],
  [Điều kiện sau], [Bằng chứng nhận hàng được lưu trữ bất biến; bộ đếm 72 giờ đang chạy hoặc dòng tiền đã được giải ngân.],
  [Quy tắc nghiệp vụ], [BR-004, BR-005, BR-006, BR-011, BR-012, BR-025],
  [Yêu cầu liên quan], [REQ-039, REQ-040, REQ-041],
  [Yêu cầu đặc biệt], [Bằng chứng phải được lưu kèm dấu thời gian và mã băm nội dung để bảo đảm giá trị đối chứng khi phát sinh tranh chấp.],
  [Tần suất sử dụng], [Rất cao — mỗi đơn hàng giao thành công đều đi qua ca sử dụng này.],
)

#ucspec("UC-006", "Yêu cầu trả hàng / hoàn tiền",
  [Tác nhân chính], [User (vai người mua)],
  [Tác nhân phụ], [User (vai người bán) — bên phản hồi; đối tác vận chuyển (chặng trả hàng)],
  [Mô tả], [Người mua khiếu nại hàng lỗi hoặc không đúng mô tả trong thời hạn 72 giờ kể từ khi xác nhận nhận hàng, kèm bằng chứng bắt buộc; dòng tiền tạm giữ bị khóa cứng trong suốt quá trình xử lý.],
  [Điều kiện trước], [Đơn hàng ở trạng thái `Đã nhận hàng — chờ đối chiếu` và bộ đếm 72 giờ chưa hết hạn.],
  [Luồng chính], [
    1. Người mua mở đơn hàng và chọn "Trả hàng / Hoàn tiền".
    2. Hệ thống hiển thị biểu mẫu chọn lý do (hàng lỗi, không đúng mô tả, thiếu phụ kiện…) và bắt buộc tải lên video mở hộp cùng ảnh minh chứng (bao hàm UC-S1).
    3. Người mua gửi yêu cầu.
    4. Hệ thống tạm dừng bộ đếm giải ngân, khóa cứng tiền tạm giữ và chuyển đơn sang trạng thái `Yêu cầu trả hàng`.
    5. Hệ thống thông báo cho người bán, ấn định thời hạn phản hồi 48 giờ.
    6. Người bán chọn "Đồng ý hoàn tiền".
    7. Hệ thống phát hành mã vận đơn trả hàng cho người mua.
    8. Người bán nhận hàng trả về và xác nhận nguyên vẹn; hệ thống hoàn 100% tiền tạm giữ về ví khả dụng của người mua bằng một bút toán đảo ứng.
  ],
  [Luồng thay thế], [
    *[6a] Người bán chọn "Từ chối hoàn tiền":* luồng mở rộng sang UC-007 (tranh chấp).

    *[6b] Người bán không phản hồi trong 48 giờ:* hệ thống coi như đồng ý và tự động hoàn 100% tiền cho người mua (BR-007).
  ],
  [Luồng ngoại lệ], [
    *[2a] Hồ sơ thiếu video mở hộp với lý do "hàng lỗi/không đúng mô tả":* hệ thống từ chối tiếp nhận yêu cầu (BR-006).

    *[8a] Hàng trả về không khớp hoặc hư hỏng thêm:* người bán được quyền chuyển hồ sơ sang tranh chấp trước khi hoàn tiền.
  ],
  [Điều kiện sau], [Tiền tạm giữ đã hoàn cho người mua, hoặc hồ sơ đã được nâng cấp thành vụ tranh chấp đang chờ phân xử.],
  [Quy tắc nghiệp vụ], [BR-005, BR-006, BR-007, BR-008, BR-013],
  [Yêu cầu liên quan], [REQ-021, REQ-022, REQ-023],
  [Yêu cầu đặc biệt], [Thời hạn 48 giờ của người bán được hiện thực bằng bộ định thời bền, không phụ thuộc tiến trình nền có thể bị mất khi khởi động lại.],
  [Tần suất sử dụng], [Trung bình — kỳ vọng dưới 5% tổng số đơn hàng.],
)

#ucspec("UC-007", "Khiếu nại và tranh chấp",
  [Tác nhân chính], [User (vai người bán)],
  [Tác nhân phụ], [User (vai người mua), Moderator (bên tiếp nhận hồ sơ)],
  [Mô tả], [Khi người bán từ chối yêu cầu hoàn tiền kèm bằng chứng đối chứng, hệ thống mở một vụ tranh chấp, khóa cứng dòng tiền và chuyển hồ sơ vào hàng đợi phân xử nội bộ.],
  [Điều kiện trước], [Tồn tại một yêu cầu hoàn tiền (UC-006) đang trong thời hạn phản hồi 48 giờ của người bán.],
  [Luồng chính], [
    1. Người bán mở yêu cầu hoàn tiền và chọn "Từ chối hoàn tiền".
    2. Hệ thống bắt buộc nhập lý do và tải lên bằng chứng đối chứng: ảnh/video đóng gói, tình trạng hàng trước khi gửi (bao hàm UC-S1).
    3. Người bán gửi phản hồi.
    4. Hệ thống tạo hồ sơ tranh chấp, chuyển đơn sang trạng thái `Đang tranh chấp` và giữ nguyên khóa cứng trên tiền tạm giữ.
    5. Hệ thống thông báo cho cả hai bên và đưa hồ sơ vào hàng đợi của Moderator.
    6. Người mua được quyền bổ sung bằng chứng trong thời hạn quy định trước khi Moderator ra phán quyết.
  ],
  [Luồng thay thế], [
    *[6a] Hai bên tự thỏa thuận rút khiếu nại:* người mua chủ động hủy yêu cầu, hồ sơ tranh chấp được đóng và bộ đếm giải ngân chạy tiếp.
  ],
  [Luồng ngoại lệ], [
    *[2a] Người bán không cung cấp được bằng chứng đối chứng:* hệ thống không cho phép từ chối, hồ sơ mặc định chuyển sang hoàn tiền cho người mua (BR-006, BR-009).
  ],
  [Điều kiện sau], [Hồ sơ tranh chấp tồn tại ở trạng thái `Chờ phân xử`, dòng tiền bị khóa cứng, mọi bộ đếm tự động bị vô hiệu hóa.],
  [Quy tắc nghiệp vụ], [BR-006, BR-008, BR-009, BR-013],
  [Yêu cầu liên quan], [REQ-024, REQ-025],
  [Yêu cầu đặc biệt], [Toàn bộ bằng chứng của hai phía phải hiển thị song song, không cho phép sửa hoặc xóa sau khi đã gửi.],
  [Tần suất sử dụng], [Thấp — chỉ phát sinh khi hai bên không tự thống nhất được.],
)

#ucspec("UC-008", "Phân xử tranh chấp",
  [Tác nhân chính], [Moderator],
  [Tác nhân phụ], [User (người mua và người bán), dịch vụ ví/Escrow],
  [Mô tả], [Điều phối viên thẩm định bằng chứng của hai phía và ra phán quyết cuối cùng về dòng tiền: hoàn tiền cho người mua hoặc giải ngân cho người bán.],
  [Điều kiện trước], [Tồn tại hồ sơ tranh chấp ở trạng thái `Chờ phân xử`; Moderator đã đăng nhập vào phân hệ quản lý.],
  [Luồng chính], [
    1. Moderator mở hàng đợi "Tranh chấp cần xử lý" và chọn một hồ sơ.
    2. Hệ thống hiển thị toàn bộ ngữ cảnh: thông tin đơn hàng, lịch sử hội thoại liên quan, bằng chứng mở hộp của người mua và bằng chứng đóng gói của người bán.
    3. Moderator đối soát tính xác thực và tính liền mạch của bằng chứng hai phía.
    4. Moderator nhập lập luận phán quyết và chọn một trong hai phương án:
       - *Phương án A — Hoàn tiền cho người mua:* hệ thống giải phóng ví tạm giữ theo chiều hoàn tiền.
       - *Phương án B — Giải ngân cho người bán:* hệ thống chuyển tiền tạm giữ sang ví khả dụng của người bán sau khi trừ các loại phí.
    5. Hệ thống thực thi lệnh chuyển tiền ngay lập tức, bỏ qua mọi bộ đếm tự động còn lại.
    6. Hệ thống ghi nhật ký kiểm toán bất biến (bao hàm UC-S2) và thông báo kết quả kèm lý do cho cả hai bên.
  ],
  [Luồng thay thế], [
    *[4a] Bằng chứng chưa đủ cơ sở:* Moderator yêu cầu một hoặc cả hai bên bổ sung bằng chứng, hồ sơ chuyển sang `Chờ bổ sung` kèm thời hạn.

    *[4b] Phán quyết hoàn tiền một phần:* hệ thống ghi hai bút toán tương ứng phần hoàn cho người mua và phần giải ngân cho người bán.
  ],
  [Luồng ngoại lệ], [
    *[5a] Lỗi trong lúc thực thi chuyển tiền:* luồng bền tự phục hồi và thực hiện lại đúng một lần; trạng thái hồ sơ không chuyển sang `Đã đóng` cho tới khi bút toán hoàn tất.
  ],
  [Điều kiện sau], [Dòng tiền được giải quyết dứt điểm, hồ sơ tranh chấp `Đã đóng`, nhật ký kiểm toán ghi đầy đủ danh tính người phán quyết và thời điểm.],
  [Quy tắc nghiệp vụ], [BR-009, BR-013, BR-019],
  [Yêu cầu liên quan], [REQ-025, REQ-026],
  [Yêu cầu đặc biệt], [Chỉ token có vai trò `Moderator` được gọi các endpoint phân xử; mọi truy cập hồ sơ đều để lại dấu vết kiểm toán (NFR-005, NFR-010).],
  [Tần suất sử dụng], [Thấp — nhưng là ca sử dụng có mức rủi ro tài chính và uy tín cao nhất.],
)

#ucspec("UC-013", "Ví điện tử và rút tiền",
  [Tác nhân chính], [User],
  [Tác nhân phụ], [Cổng thanh toán / hệ thống chi hộ ngân hàng],
  [Mô tả], [Người dùng theo dõi hai loại số dư (khả dụng và tạm giữ), xem lịch sử biến động và gửi yêu cầu rút phần số dư khả dụng về tài khoản ngân hàng đã đăng ký.],
  [Điều kiện trước], [Người dùng đã đăng nhập và đã liên kết tối thiểu một tài khoản ngân hàng.],
  [Luồng chính], [
    1. Người dùng mở trang "Ví của tôi".
    2. Hệ thống hiển thị số dư khả dụng, số dư đang tạm giữ và lịch sử biến động số dư.
    3. Người dùng chọn "Rút tiền", nhập số tiền và chọn tài khoản ngân hàng đích.
    4. Hệ thống kiểm tra số tiền yêu cầu không vượt quá số dư khả dụng.
    5. Hệ thống ghi yêu cầu rút tiền vào nhật ký bất biến ở trạng thái `Đang xử lý`.
    6. Lệnh chi được xác nhận thành công; hệ thống trừ số dư khả dụng và đóng yêu cầu ở trạng thái `Hoàn tất`.
  ],
  [Luồng thay thế], [
    *[4a] Số tiền vượt số dư khả dụng:* hệ thống từ chối và nêu rõ phần số dư đang bị tạm giữ không thể rút (BR-023).
  ],
  [Luồng ngoại lệ], [
    *[6a] Lệnh chi thất bại:* hệ thống không trừ số dư, chuyển yêu cầu sang `Thất bại` kèm lý do và giữ nguyên nhật ký của lần thử.
  ],
  [Điều kiện sau], [Số dư khả dụng chỉ bị trừ sau khi lệnh chi được xác nhận thành công; mọi biến động đều có bút toán đối ứng.],
  [Quy tắc nghiệp vụ], [BR-013, BR-023],
  [Yêu cầu liên quan], [REQ-036, REQ-037, REQ-038],
  [Yêu cầu đặc biệt], [Không bao giờ trừ số dư trước khi có xác nhận từ bên chi trả (nguyên tắc chỉ ghi giảm sau xác nhận).],
  [Tần suất sử dụng], [Trung bình — theo chu kỳ rút tiền của người bán.],
)

#ucspec("UC-015", "Kiểm duyệt bài đăng khả nghi",
  [Tác nhân chính], [Moderator],
  [Tác nhân phụ], [User (chủ bài đăng), bộ lọc nội dung tự động],
  [Mô tả], [Điều phối viên thẩm định các bài đăng bị bộ lọc tự động gắn cờ hoặc bị người dùng báo cáo vượt ngưỡng, quyết định gỡ bài kèm chế tài hoặc khôi phục hiển thị công khai.],
  [Điều kiện trước], [Tồn tại tối thiểu một bài đăng ở trạng thái `Chờ kiểm duyệt` hoặc `Bị báo cáo`.],
  [Luồng chính], [
    1. Moderator mở hàng đợi "Bài đăng cần kiểm duyệt".
    2. Hệ thống hiển thị nội dung bài đăng, hình ảnh, lý do bị gắn cờ và toàn bộ báo cáo của người dùng.
    3. Moderator đối chiếu với danh mục hàng hóa bị cấm của nền tảng.
    4. Moderator ra quyết định:
       - *Phương án A — Vi phạm:* gỡ bài đăng, đồng thời cảnh cáo hoặc khóa tài khoản người đăng tùy mức độ.
       - *Phương án B — Không vi phạm:* khôi phục bài đăng về trạng thái `Active`.
    5. Hệ thống ghi nhật ký kiểm duyệt bất biến (bao hàm UC-S2) và thông báo kết quả kèm lý do cho người đăng.
  ],
  [Luồng thay thế], [
    *[4c] Nội dung cần xác minh thêm:* Moderator yêu cầu người bán cung cấp giấy tờ chứng minh nguồn gốc hàng hóa, bài đăng giữ trạng thái `Chờ kiểm duyệt`.
  ],
  [Luồng ngoại lệ], [
    *[4d] Bài đăng đã bị chính người bán xóa trước khi kiểm duyệt:* hệ thống đóng yêu cầu kiểm duyệt, vẫn lưu nhật ký phục vụ theo dõi hành vi tái phạm.
  ],
  [Điều kiện sau], [Bài đăng ở trạng thái `Đã gỡ` hoặc `Active`; nhật ký kiểm duyệt được lưu bất biến phục vụ đối soát.],
  [Quy tắc nghiệp vụ], [BR-017, BR-018, BR-019],
  [Yêu cầu liên quan], [REQ-042, REQ-043, REQ-044],
  [Yêu cầu đặc biệt], [Hệ thống chỉ dừng ở mức gỡ bài và khóa tài khoản; việc chuyển thông tin cho cơ quan chức năng không thuộc phạm vi tự động hóa.],
  [Tần suất sử dụng], [Trung bình — phụ thuộc lưu lượng bài đăng mới và số lượt báo cáo.],
)

=== Bộ quy tắc nghiệp vụ ràng buộc hệ thống (Business Rules)
Bộ quy tắc nghiệp vụ là các ràng buộc bất biến mà mọi ca sử dụng, yêu cầu chức năng và thiết kế kỹ thuật phải tuân thủ. Bộ quy tắc dưới đây gồm *25 quy tắc* đã được chuẩn hóa và loại bỏ trùng lặp, trong đó `BR-021` … `BR-025` là các quy tắc bổ sung ở giai đoạn thiết kế chi tiết nhằm chốt các ngưỡng thời gian còn để mở ở báo cáo lần 1.

*a) Định danh và phân quyền*
- *BR-001:* Hệ thống chỉ có ba vai trò: `Admin` (duy nhất một tài khoản, cấu hình sẵn), `Moderator` (do Admin cấp phát, không tự đăng ký) và `User` (đăng ký công khai).
- *BR-002:* Tài khoản `User` sau khi đăng ký có đầy đủ cả hai năng lực mua và bán, không cần đăng ký gian hàng riêng.
- *BR-010:* Chỉ duy nhất Admin được phép cấp phát hoặc khóa tài khoản Moderator.
- *BR-020:* Mật khẩu của mọi tài khoản bắt buộc được băm một chiều bằng thuật toán bảo mật cao trước khi lưu trữ, không lưu dạng nguyên bản trong bất kỳ hoàn cảnh nào.

*b) Dòng tiền tạm giữ và giải ngân*
- *BR-003:* Tiền thanh toán đơn hàng C2C bắt buộc phải đi vào ví tạm giữ (Escrow) của sàn trước khi được giải ngân cho người bán.
- *BR-004:* Bộ đếm ngược tạm giữ 72 giờ chỉ bắt đầu chạy từ thời điểm *người mua chủ động xác nhận đã nhận hàng* (UC-014), không dựa hoàn toàn vào trạng thái API của đối tác vận chuyển.
- *BR-005:* Hết 72 giờ mà người mua không gửi yêu cầu hoàn tiền hoặc tranh chấp, hệ thống tự động giải ngân cho người bán.
- *BR-011:* Hệ thống trích phí sàn (Transaction Fee) từ số tiền giải ngân cho người bán theo tỷ lệ do Admin cấu hình (UC-017).
- *BR-012:* Phí vận chuyển được phân bổ theo lựa chọn của người bán tại thời điểm đăng bán: *người mua trả* thì phí được cộng vào hóa đơn khi thanh toán; *người bán trả* thì phí bị trừ vào số tiền thực nhận khi giải ngân.
- *BR-013:* Mọi biến động số dư khả dụng và số dư tạm giữ bắt buộc được ghi bút toán đầy đủ trong sổ giao dịch ví, phục vụ đối soát độc lập.
- *BR-022:* Đơn hàng ở trạng thái chờ thanh toán quá 24 giờ sẽ bị tự động hủy, tồn kho đã giữ chỗ được giải phóng.
- *BR-023:* Người dùng chỉ được rút phần *số dư khả dụng*; phần số dư đang bị tạm giữ trong Escrow không thể rút, và số dư chỉ bị ghi giảm sau khi lệnh chi được xác nhận thành công.
- *BR-025:* Nếu người mua không chủ động xác nhận nhận hàng, hệ thống nhắc nhở sau *2 ngày* kể từ khi đối tác vận chuyển báo "Đã giao" và *tự động xác nhận thay* sau *7 ngày*, sau đó khởi động bộ đếm 72 giờ như bình thường để dòng tiền không bị treo vô thời hạn.

*c) Thương lượng giá và đặt hàng*
- *BR-014:* Với sản phẩm giá cố định, người mua được thanh toán trực tiếp từ trang chi tiết sản phẩm.
- *BR-015:* Với sản phẩm giá thương lượng, người mua bắt buộc phải thương lượng qua hội thoại và nhận Offer Card từ người bán trước khi thanh toán.
- *BR-016:* Offer Card phải hiển thị rõ đơn giá đề xuất mới và lý do cụ thể; đơn hàng chỉ được sinh sau khi người mua bấm "Chấp nhận".
- *BR-021:* Offer Card có hiệu lực tối đa 24 giờ kể từ khi phát hành; thẻ bị thu hồi ngay lập tức nếu người bán sửa giá gốc hoặc sản phẩm đã được người khác mua.
- *BR-024:* Người bán phải xử lý mục chờ (xác nhận hoặc từ chối) trong thời hạn 48 giờ; quá hạn hệ thống tự động từ chối, giải phóng tồn kho và hoàn tiền cho người mua.

*d) Khiếu nại, tranh chấp và bằng chứng*
- *BR-006:* Người mua bắt buộc cung cấp video mở hộp liền mạch hoặc ảnh sản phẩm thực tế cả khi xác nhận nhận hàng (UC-014) và khi yêu cầu hoàn tiền (UC-006); hồ sơ thiếu bằng chứng bị từ chối tiếp nhận.
- *BR-007:* Khi người mua yêu cầu hoàn tiền, người bán có 48 giờ để phản hồi; nếu đồng ý hoặc không phản hồi, hệ thống tự động hoàn 100% tiền tạm giữ cho người mua.
- *BR-008:* Nếu người bán từ chối hoàn tiền kèm bằng chứng đối chứng, hồ sơ chuyển sang trạng thái `Đang tranh chấp` và được giao cho Moderator.
- *BR-009:* Moderator phán quyết theo nguyên tắc *bên nào cung cấp bằng chứng xác thực và thuyết phục hơn sẽ được giải quyết có lợi*; phán quyết của Moderator là quyết định cuối cùng và được thực thi ngay lập tức, bỏ qua mọi bộ đếm tự động còn lại.

*e) Kiểm duyệt nội dung*
- *BR-017:* Mọi bài đăng mới đều phải qua bước quét tự động (từ khóa và đặc trưng hình ảnh) để phát hiện dấu hiệu hàng cấm trước khi hiển thị công khai.
- *BR-018:* Một bài đăng nhận từ *5 lượt báo cáo* của các người dùng độc lập (khác tài khoản và khác địa chỉ IP) sẽ tự động chuyển sang trạng thái `Chờ kiểm duyệt` và vào hàng đợi của Moderator.
- *BR-019:* Moderator có quyền gỡ bài đăng, cảnh cáo hoặc khóa tài khoản người bán vi phạm chính sách hàng cấm; mọi quyết định đều được ghi nhật ký bất biến.

#note[*Các ngưỡng thời gian được chốt ở giai đoạn hai.* Ba tham số còn để mở ở báo cáo lần 1 nay được ấn định: (i) nhắc nhở xác nhận nhận hàng sau *2 ngày* và tự động xác nhận sau *7 ngày* kể từ khi đối tác vận chuyển báo "Đã giao" (BR-025, UC-014); (ii) ngưỡng báo cáo tự động đưa bài đăng vào hàng đợi kiểm duyệt là *5 lượt* từ người dùng độc lập (BR-018); (iii) thời hạn người bán xử lý mục chờ là *48 giờ* (BR-024). Các giá trị này đều được đưa vào bảng tham số cấu hình do Admin quản lý (UC-017) để có thể điều chỉnh khi vận hành thực tế mà không phải sửa mã nguồn.]

== Mô hình hóa quy trình nghiệp vụ (Process Modeling)
Các ca sử dụng ở mục 3.3 mô tả *mục tiêu* của tác nhân; mục này mô hình hóa *trình tự thực thi* của những quy trình đó dưới ba góc nhìn bổ trợ nhau: sơ đồ hoạt động (luồng điều khiển và các điểm quyết định), sơ đồ trạng thái (vòng đời của đơn hàng) và sơ đồ trình tự (thứ tự trao đổi thông điệp giữa các thành phần, kèm điểm phục hồi của luồng bền).

=== Sơ đồ hoạt động: Đăng bán sản phẩm và quét nội dung tự động

#note[Quy trình thể hiện cơ chế "an toàn trước" của khâu đăng bán: mọi bài đăng đều đi qua bộ lọc tự động, và bài đăng có dấu hiệu khả nghi bị giữ lại ở trạng thái chờ kiểm duyệt thay vì hiển thị công khai ngay (BR-017).]

#fig(
  [Sơ đồ hoạt động quy trình đăng bán sản phẩm C2C (UC-003)],
  spacing: (24mm, 10mm),
  nt((0, 0), [Bắt đầu]),
  edge((0, 0), (0, 1), "-|>"),
  np((0, 1), [Người bán nhập thông tin sản phẩm và tải ảnh]),
  edge((0, 1), (0, 2), "-|>"),
  nd((0, 2), [Dữ liệu hợp lệ?]),
  edge((0, 2), (1.4, 2), "-|>", text(size: 8pt)[Không]),
  nr((1.4, 2), [Báo lỗi từng trường, giữ dữ liệu đã nhập]),
  edge((1.4, 2), (0, 1), "-|>", bend: 35deg),
  edge((0, 2), (0, 3), "-|>", text(size: 8pt)[Có]),
  np((0, 3), [Chọn chế độ giá & phương án phí vận chuyển]),
  edge((0, 3), (0, 4), "-|>"),
  np((0, 4), [Bộ lọc tự động quét từ khóa và hình ảnh]),
  edge((0, 4), (0, 5), "-|>"),
  nd((0, 5), [Có dấu hiệu hàng cấm?]),
  edge((0, 5), (1.4, 6), "-|>", text(size: 8pt)[Có], label-side: right),
  np((1.4, 6), [Lưu trạng thái "Chờ kiểm duyệt" & tạo yêu cầu cho Moderator]),
  edge((0, 5), (-1.4, 6), "-|>", text(size: 8pt)[Không], label-side: left),
  ng((-1.4, 6), [Lưu trạng thái "Active" & sinh vector nhúng lên chỉ mục]),
  edge((1.4, 6), (0, 7), "-|>"),
  edge((-1.4, 6), (0, 7), "-|>"),
  nt((0, 7), [Kết thúc]),
)

=== Sơ đồ hoạt động: Thương lượng giá qua Offer Card

#fig(
  [Sơ đồ hoạt động quy trình thương lượng giá qua Offer Card (UC-004)],
  spacing: (22mm, 10mm),
  nt((0, 0), [Bắt đầu]),
  edge((0, 0), (0, 1), "-|>"),
  np((0, 1), [Người mua chọn "Thương lượng" trên sản phẩm giá thương lượng]),
  edge((0, 1), (0, 2), "-|>"),
  np((0, 2), [Hệ thống mở hội thoại gắn với sản phẩm]),
  edge((0, 2), (0, 3), "-|>"),
  np((0, 3), [Hai bên trao đổi tin nhắn, ảnh và video thực tế]),
  edge((0, 3), (0, 4), "-|>"),
  np((0, 4), [Người bán phát hành Offer Card (giá mới + lý do), hiệu lực 24 giờ]),
  edge((0, 4), (0, 5), "-|>"),
  nd((0, 5), [Người mua phản hồi?]),
  edge((0, 5), (1.5, 5), "-|>", text(size: 8pt)[Từ chối], label-side: right),
  nr((1.5, 5), [Thẻ "Đã từ chối", tiếp tục thương lượng]),
  edge((1.5, 5), (0, 4), "-|>", bend: 40deg),
  edge((0, 5), (-1.5, 6), "-|>", text(size: 8pt)[Quá 24 giờ], label-side: left),
  nr((-1.5, 6), [Thẻ "Hết hiệu lực" (BR-021)]),
  edge((0, 5), (0, 6), "-|>", text(size: 8pt)[Chấp nhận]),
  ng((0, 6), [Sinh mục chờ với đơn giá đã thỏa thuận]),
  edge((0, 6), (0, 7), "-|>"),
  nt((0, 7), [Chuyển sang UC-005]),
  edge((-1.5, 6), (0, 7), "-|>"),
)

=== Sơ đồ hoạt động: Thanh toán tạm giữ Escrow

#note[Quy trình cho thấy toàn bộ vòng đời dòng tiền: khóa vào ví tạm giữ khi thanh toán, mốc xác nhận nhận hàng của người mua kích hoạt bộ đếm 72 giờ, và chỉ giải ngân khi hết thời hạn mà không có khiếu nại.]

#fig(
  [Sơ đồ hoạt động quy trình thanh toán tạm giữ và giải ngân (UC-005, UC-012, UC-014)],
  spacing: (23mm, 8.5mm),
  nt((0, 0), [Bắt đầu]),
  edge((0, 0), (0, 1), "-|>"),
  nd((0, 1), [Chế độ giá?]),
  edge((0, 1), (-1.4, 2), "-|>", text(size: 8pt)[Cố định], label-side: left),
  np((-1.4, 2), [Bấm "Mua ngay" tại trang sản phẩm]),
  edge((0, 1), (1.4, 2), "-|>", text(size: 8pt)[Thương lượng], label-side: right),
  np((1.4, 2), [Chấp nhận Offer Card trong hội thoại]),
  np((0, 3), [Chốt địa chỉ, tính phí ship động, giữ chỗ tồn kho]),
  edge((-1.4, 2), (0, 3), "-|>"),
  edge((1.4, 2), (0, 3), "-|>"),
  edge((0, 3), (0, 4), "-|>"),
  nd((0, 4), [Thanh toán thành công?]),
  edge((0, 4), (1.5, 4), "-|>", text(size: 8pt)[Không / quá 24 giờ]),
  nr((1.5, 4), [Hủy đơn, giải phóng tồn kho (BR-022)]),
  edge((0, 4), (0, 5), "-|>", text(size: 8pt)[Có]),
  np((0, 5), [Khóa tiền vào ví tạm giữ (Escrow)]),
  edge((0, 5), (0, 6), "-|>"),
  nd((0, 6), [Người bán xác nhận mục chờ?]),
  edge((0, 6), (1.5, 6), "-|>", text(size: 8pt)[Từ chối / quá hạn]),
  nr((1.5, 6), [Hoàn 100% cho người mua (BR-024)]),
  edge((0, 6), (0, 7), "-|>", text(size: 8pt)[Xác nhận]),
  np((0, 7), [Tạo vận đơn, giao hàng]),
  edge((0, 7), (0, 8), "-|>"),
  np((0, 8), [Người mua xác nhận nhận hàng kèm bằng chứng → đếm ngược 72 giờ]),
  edge((0, 8), (0, 9), "-|>"),
  nd((0, 9), [Có khiếu nại trong 72 giờ?]),
  edge((0, 9), (-1.5, 10), "-|>", text(size: 8pt)[Có], label-side: left),
  np((-1.5, 10), [Chuyển quy trình hoàn tiền / tranh chấp]),
  edge((0, 9), (1.5, 10), "-|>", text(size: 8pt)[Không], label-side: right),
  ng((1.5, 10), [Giải ngân cho người bán (trừ phí sàn, phí ship)]),
  nt((0, 11), [Kết thúc]),
  edge((-1.5, 10), (0, 11), "-|>"),
  edge((1.5, 10), (0, 11), "-|>"),
  edge((1.5, 4), (0, 11), "-|>", bend: -45deg),
  edge((1.5, 6), (0, 11), "-|>", bend: -40deg),
)

=== Sơ đồ hoạt động: Trả hàng, hoàn tiền và tranh chấp

#note[Quy trình thể hiện điểm khác biệt cốt lõi của ShopNexus so với các sàn rao vặt: khi phát sinh khiếu nại, dòng tiền bị khóa cứng ngay và nếu hai bên không tự thống nhất được thì Điều phối viên đứng ra phân xử dựa trên bằng chứng.]

#fig(
  [Sơ đồ hoạt động quy trình trả hàng, hoàn tiền và tranh chấp (UC-006 → UC-008)],
  spacing: (24mm, 10mm),
  nt((0, 0), [Bắt đầu]),
  edge((0, 0), (0, 1), "-|>"),
  np((0, 1), [Người mua gửi yêu cầu hoàn tiền kèm video mở hộp]),
  edge((0, 1), (0, 2), "-|>"),
  nd((0, 2), [Đủ bằng chứng bắt buộc?]),
  edge((0, 2), (1.5, 2), "-|>", text(size: 8pt)[Không]),
  nr((1.5, 2), [Từ chối tiếp nhận hồ sơ (BR-006)]),
  edge((0, 2), (0, 3), "-|>", text(size: 8pt)[Có]),
  np((0, 3), [Tạm dừng bộ đếm, khóa cứng tiền tạm giữ]),
  edge((0, 3), (0, 4), "-|>"),
  nd((0, 4), [Người bán phản hồi trong 48 giờ?]),
  edge((0, 4), (-1.5, 5), "-|>", text(size: 8pt)[Đồng ý / im lặng], label-side: left),
  ng((-1.5, 5), [Hoàn 100% tiền cho người mua (BR-007)]),
  edge((0, 4), (0, 5), "-|>", text(size: 8pt)[Từ chối + bằng chứng]),
  np((0, 5), [Mở hồ sơ tranh chấp, đưa vào hàng đợi Moderator]),
  edge((0, 5), (0, 6), "-|>"),
  np((0, 6), [Moderator đối soát bằng chứng hai phía]),
  edge((0, 6), (0, 7), "-|>"),
  nd((0, 7), [Phán quyết?]),
  edge((0, 7), (-1.5, 8), "-|>", text(size: 8pt)[Người mua thắng], label-side: left),
  ng((-1.5, 8), [Hoàn tiền cho người mua]),
  edge((0, 7), (1.5, 8), "-|>", text(size: 8pt)[Người bán thắng], label-side: right),
  ng((1.5, 8), [Giải ngân cho người bán]),
  nt((0, 9), [Kết thúc — ghi nhật ký kiểm toán]),
  edge((-1.5, 5), (0, 9), "-|>", bend: 40deg),
  edge((-1.5, 8), (0, 9), "-|>"),
  edge((1.5, 8), (0, 9), "-|>"),
  edge((1.5, 2), (0, 9), "-|>", bend: -50deg),
)

=== Sơ đồ hoạt động: Kiểm duyệt bài đăng khả nghi

#fig(
  [Sơ đồ hoạt động quy trình báo cáo và kiểm duyệt bài đăng (UC-016, UC-015)],
  spacing: (24mm, 10mm),
  nt((0, 0), [Bắt đầu]),
  edge((0, 0), (0, 1), "-|>"),
  nd((0, 1), [Nguồn gắn cờ?]),
  edge((0, 1), (-1.5, 2), "-|>", text(size: 8pt)[Bộ lọc tự động], label-side: left),
  np((-1.5, 2), [Bài đăng mới bị nghi vấn hàng cấm]),
  edge((0, 1), (1.5, 2), "-|>", text(size: 8pt)[Người dùng báo cáo], label-side: right),
  np((1.5, 2), [Ghi nhận báo cáo kèm lý do]),
  edge((1.5, 2), (1.5, 3), "-|>"),
  nd((1.5, 3), [Đủ 5 lượt báo cáo độc lập?]),
  edge((1.5, 3), (2.9, 3), "-|>", text(size: 8pt)[Chưa]),
  nr((2.9, 3), [Giữ bài đăng, tiếp tục theo dõi]),
  np((0, 4), [Chuyển trạng thái "Chờ kiểm duyệt", vào hàng đợi Moderator]),
  edge((-1.5, 2), (0, 4), "-|>"),
  edge((1.5, 3), (0, 4), "-|>", text(size: 8pt)[Đủ (BR-018)]),
  edge((0, 4), (0, 5), "-|>"),
  np((0, 5), [Moderator đối chiếu danh mục hàng hóa bị cấm]),
  edge((0, 5), (0, 6), "-|>"),
  nd((0, 6), [Có vi phạm?]),
  edge((0, 6), (-1.5, 7), "-|>", text(size: 8pt)[Có], label-side: left),
  ng((-1.5, 7), [Gỡ bài, cảnh cáo hoặc khóa tài khoản]),
  edge((0, 6), (1.5, 7), "-|>", text(size: 8pt)[Không], label-side: right),
  ng((1.5, 7), [Khôi phục bài đăng về "Active"]),
  nt((0, 8), [Kết thúc — ghi nhật ký kiểm duyệt]),
  edge((-1.5, 7), (0, 8), "-|>"),
  edge((1.5, 7), (0, 8), "-|>"),
  edge((2.9, 3), (0, 8), "-|>", bend: -55deg),
)

=== Sơ đồ trạng thái vòng đời đơn hàng (Order State Machine)
Đơn hàng là thực thể có vòng đời phức tạp nhất trong hệ thống, chịu tác động của cả hành vi người dùng, webhook bên thứ ba và các bộ định thời bền. Sơ đồ trạng thái dưới đây là *hợp đồng* mà tầng nghiệp vụ và tầng dữ liệu phải tuân thủ: mọi phép chuyển trạng thái không xuất hiện trên sơ đồ đều bị tầng nghiệp vụ từ chối.

#fig(
  [Sơ đồ trạng thái vòng đời đơn hàng (Order State Machine)],
  spacing: (26mm, 11mm),
  nt((0, 0), [Khởi tạo]),
  edge((0, 0), (0, 1), "-|>", text(size: 7.5pt)[checkout]),
  np((0, 1), [CHỜ THANH TOÁN\ `PENDING_PAYMENT`]),
  edge((0, 1), (1.6, 1), "-|>", text(size: 7.5pt)[quá 24 giờ]),
  ng((1.6, 1), [ĐÃ HỦY\ `CANCELED`]),
  edge((0, 1), (0, 2), "-|>", text(size: 7.5pt)[webhook thanh toán OK]),
  np((0, 2), [ĐÃ THANH TOÁN — TẠM GIỮ\ `PAID_ESCROW`]),
  edge((0, 2), (1.6, 2), "-|>", text(size: 7.5pt)[người bán từ chối / quá 48 giờ]),
  ng((1.6, 2), [ĐÃ HOÀN TIỀN\ `REFUNDED`]),
  edge((0, 2), (0, 3), "-|>", text(size: 7.5pt)[người bán xác nhận, tạo vận đơn]),
  np((0, 3), [ĐANG GIAO\ `SHIPPING`]),
  edge((0, 3), (0, 4), "-|>", text(size: 7.5pt)[người mua xác nhận nhận hàng + bằng chứng]),
  np((0, 4), [CHỜ ĐỐI CHIẾU (72 GIỜ)\ `AWAITING_SETTLEMENT`]),
  edge((0, 4), (-1.7, 5), "-|>", text(size: 7.5pt)[yêu cầu hoàn tiền], label-side: left),
  np((-1.7, 5), [YÊU CẦU TRẢ HÀNG\ `REFUND_REQUESTED`]),
  edge((0, 4), (0, 6), "-|>", text(size: 7.5pt)[hết 72 giờ, không khiếu nại]),
  edge((-1.7, 5), (-1.7, 6), "-|>", text(size: 7.5pt)[người bán từ chối], label-side: left),
  np((-1.7, 6), [ĐANG TRANH CHẤP\ `DISPUTED`]),
  edge((-1.7, 5), (1.6, 2), "-|>", stroke: (dash: "dashed"), text(size: 7.5pt)[đồng ý / im lặng 48 giờ]),
  edge((-1.7, 6), (1.6, 2), "-|>", stroke: (dash: "dashed"), bend: -18deg, text(size: 7.5pt)[phán quyết: người mua thắng]),
  edge((-1.7, 6), (0, 6), "-|>", text(size: 7.5pt)[phán quyết: người bán thắng]),
  ng((0, 6), [HOÀN THÀNH — ĐÃ GIẢI NGÂN\ `COMPLETED`]),
  edge((0, 6), (0, 7), "-|>", text(size: 7.5pt)[đánh giá (UC-009)]),
  nt((0, 7), [Kết thúc]),
)

=== Sơ đồ trình tự: Đặt hàng và khóa tiền tạm giữ

#note[Mỗi bước ghi (mutation) trong sơ đồ đều được Restate ghi nhật ký thực thi. Khi dịch vụ bị sập hoặc khởi động lại, luồng tiếp tục đúng từ bước dừng gần nhất mà không xử lý trùng — đây là cơ sở kỹ thuật cho NFR-017.]

#fig(
  [Sơ đồ trình tự đặt hàng và khóa tiền tạm giữ (UC-005, luồng bền trên Restate)],
  spacing: (30mm, 8mm),
  np((0, 0), [Người mua]),
  ncore((1, 0), [Order Service\ (Restate)]),
  np((2, 0), [Inventory\ Service]),
  np((3, 0), [Cổng thanh toán]),
  np((4, 0), [Người bán]),
  ..lifelines(5, y1: 11),
  msg(0, 1, 1, [1. Checkout (SKU, địa chỉ giao)]),
  msg(1, 3, 2, [2. Lấy báo giá phí vận chuyển]),
  msg(1, 2, 3, [3. Reserve tồn kho theo serial]),
  rmsg(2, 1, 4, [4. Danh sách serial đã giữ chỗ]),
  msg(1, 3, 5, [5. Tạo phiên thanh toán (idempotency key)]),
  rmsg(3, 1, 6, [6. Webhook xác nhận thanh toán thành công]),
  step(1, 7, [execution: khóa tiền vào ví tạm giữ]),
  step(1, 8.3, [ghi bút toán sổ cái (append-only)]),
  msg(1, 4, 9.6, [7. Phát sự kiện "có mục chờ mới" qua NATS]),
  rmsg(1, 0, 10.6, [8. Trả kết quả: đơn ở trạng thái PAID\_ESCROW]),
)

#note[Ba pha thực thi theo quy ước *decision → execution → tail*: pha *decision* chỉ đọc và kiểm tra (thất bại sớm, chưa ghi bền); pha *execution* thực hiện các thao tác ghi bền (giữ tồn kho, khóa tiền tạm giữ, ghi sổ cái); pha *tail* phát tán thông báo sau khi đã ghi bền. Bù trừ (compensation): nếu thanh toán thất bại hoặc quá hạn, bước giữ chỗ tồn kho được giải phóng tự động, không để tồn kho bị treo.]

=== Sơ đồ trình tự: Xác nhận nhận hàng, đếm ngược 72 giờ và giải ngân

#fig(
  [Sơ đồ trình tự xác nhận nhận hàng và tự động giải ngân (UC-014)],
  spacing: (30mm, 8mm),
  np((0, 0), [Người mua]),
  ncore((1, 0), [Order Service\ (Restate)]),
  np((2, 0), [Lưu trữ\ bằng chứng]),
  np((3, 0), [Account /\ Ví Escrow]),
  np((4, 0), [Người bán]),
  ..lifelines(5, y1: 11.4),
  msg(0, 1, 1, [1. ConfirmReceived (đơn hàng, tệp bằng chứng)]),
  msg(1, 2, 2, [2. Lưu video/ảnh mở hộp + dấu thời gian]),
  rmsg(2, 1, 3, [3. Mã tài nguyên bằng chứng]),
  step(1, 4, [execution: chuyển trạng thái AWAITING\_SETTLEMENT]),
  durable(1, 5.3, [Restate durable timer: đếm ngược 72 giờ]),
  msg(1, 4, 6.6, [4. Thông báo mốc giải ngân dự kiến]),
  durable(1, 7.7, [Hết hạn, không có yêu cầu hoàn tiền]),
  msg(1, 3, 9.0, [5. Giải ngân: tạm giữ → khả dụng, trừ phí sàn & phí ship]),
  rmsg(3, 1, 10.0, [6. Bút toán thành công]),
  msg(1, 4, 11.0, [7. Thông báo đã nhận tiền]),
)

=== Sơ đồ trình tự: Hoàn tiền và tranh chấp

#fig(
  [Sơ đồ trình tự hoàn tiền và tranh chấp (UC-006 → UC-008, luồng bền theo khóa hồ sơ)],
  spacing: (30mm, 8mm),
  np((0, 0), [Người mua]),
  ncore((1, 0), [Order Service\ (Restate)]),
  np((2, 0), [Người bán]),
  np((3, 0), [Moderator]),
  np((4, 0), [Ví Escrow]),
  ..lifelines(5, y1: 12.2),
  msg(0, 1, 1, [1. CreateRefund (lý do, video mở hộp, vận đơn trả)]),
  durable(1, 2, [RefundWorkflow bắt đầu (khóa = mã hồ sơ hoàn tiền)]),
  step(1, 3.3, [tạm dừng bộ đếm, khóa cứng tiền tạm giữ]),
  msg(1, 2, 4.6, [2. Chờ người bán phản hồi (bộ định thời 48 giờ)]),
  msg(2, 1, 5.6, [3a. Đồng ý hoàn tiền / im lặng quá hạn]),
  rmsg(1, 4, 6.6, [4a. Hoàn tiền người mua (bút toán đảo ứng)]),
  msg(2, 1, 7.6, [3b. Từ chối + bằng chứng đóng gói]),
  msg(1, 3, 8.6, [4b. Đưa hồ sơ vào hàng đợi phân xử]),
  msg(3, 1, 9.6, [5b. Phán quyết: người mua thắng / người bán thắng]),
  rmsg(1, 4, 10.6, [6b. Hoàn tiền hoặc giải ngân theo phán quyết]),
  step(1, 11.8, [ghi nhật ký kiểm toán bất biến]),
)

== Phân tích yêu cầu chức năng và phi chức năng

=== Nguyên tắc đặc tả yêu cầu
Mỗi yêu cầu chức năng (Functional Requirement) được viết theo cấu trúc nguyên tử *"Hệ thống phải + [hành động] + [đối tượng] + [điều kiện/tiêu chí]"*, bảo đảm bốn tính chất: *rõ nghĩa* (chỉ một cách hiểu), *có thể kiểm chứng* (gắn được tiêu chí chấp nhận), *nguyên tử* (một hành vi, không dùng liên từ "và/hoặc" để gộp) và *độc lập với thiết kế* (nói *cái gì*, không nói *bằng cách nào*). Các yêu cầu được trích xuất hệ thống từ luồng chính, luồng thay thế và luồng ngoại lệ của từng ca sử dụng ở mục 3.3, nhờ đó mỗi yêu cầu đều truy vết được về ca sử dụng nguồn.

=== Danh mục yêu cầu chức năng
Tổng cộng *51 yêu cầu chức năng* được ban hành, đánh mã duy nhất `REQ-001` … `REQ-051` và trình bày theo nhóm phân hệ nghiệp vụ. Mức ưu tiên áp dụng thang MoSCoW đơn giản hóa: *Cao* (bắt buộc cho bản demo cuối kỳ), *T. bình* (nên có), *Thấp* (có thể lùi sau).

#figure(
  caption: [Danh mục yêu cầu chức năng hệ thống ShopNexus C2C (REQ-001 … REQ-051)],
  table(
    columns: (0.62fr, 4.2fr, 0.78fr, 0.6fr),
    align: (center + horizon, left + horizon, center + horizon, center + horizon),
    table.header([Mã], [Phát biểu yêu cầu — "Hệ thống phải…"], [UC nguồn], [Ư. tiên]),

    table.cell(colspan: 4, align: left)[*Nhóm 1 — Định danh, xác thực và phân quyền*],
    [REQ-001], [hiển thị biểu mẫu đăng ký dành riêng cho người dùng cuối khi được yêu cầu.], [UC-001], [Cao],
    [REQ-002], [xác thực định dạng địa chỉ thư điện tử đăng ký.], [UC-001], [Cao],
    [REQ-003], [từ chối đăng ký và báo lỗi nếu địa chỉ thư điện tử đã tồn tại.], [UC-001], [Cao],
    [REQ-004], [băm mật khẩu người dùng bằng thuật toán bảo mật cao trước khi lưu vào cơ sở dữ liệu.], [UC-001], [Cao],
    [REQ-005], [khởi tạo tài khoản mới ở trạng thái hoạt động với vai trò mặc định `User` kèm ví điện tử nội bộ.], [UC-001], [Cao],
    [REQ-006], [xác thực cặp thư điện tử và mật khẩu khi người dùng đăng nhập.], [UC-002], [Cao],
    [REQ-007], [điều hướng tài khoản vai trò `User` về giao diện sàn C2C sau khi đăng nhập thành công.], [UC-002], [Cao],
    [REQ-008], [điều hướng tài khoản vai trò `Moderator` về phân hệ xử lý khiếu nại và kiểm duyệt.], [UC-002], [Cao],
    [REQ-009], [điều hướng tài khoản vai trò `Admin` về phân hệ quản trị hệ thống.], [UC-002], [Cao],

    table.cell(colspan: 4, align: left)[*Nhóm 2 — Đăng bán sản phẩm*],
    [REQ-010], [cho phép người bán tải lên tối thiểu một hình ảnh và nhập tên, giá, tình trạng, danh mục, mô tả sản phẩm.], [UC-003], [Cao],
    [REQ-011], [bắt buộc người bán chọn một trong hai chế độ giá: cố định hoặc thương lượng.], [UC-003], [Cao],
    [REQ-012], [từ chối đăng bài nếu thiếu trường bắt buộc hoặc giá bán nhỏ hơn hoặc bằng 0.], [UC-003], [Cao],

    table.cell(colspan: 4, align: left)[*Nhóm 3 — Nhắn tin và thương lượng giá*],
    [REQ-013], [thiết lập kênh truyền tin thời gian thực giữa hai người dùng trong một hội thoại.], [UC-004], [Cao],
    [REQ-014], [cho phép gửi tin nhắn văn bản, hình ảnh và video thực tế của sản phẩm trong hội thoại.], [UC-004], [Cao],
    [REQ-015], [cho phép người bán phát hành Offer Card ghi rõ đơn giá đề xuất mới và lý do giảm giá cụ thể.], [UC-004], [Cao],
    [REQ-016], [sinh mục chờ với đơn giá đã thỏa thuận khi người mua chấp nhận Offer Card.], [UC-004], [Cao],

    table.cell(colspan: 4, align: left)[*Nhóm 4 — Đặt hàng, thanh toán và dòng tiền tạm giữ*],
    [REQ-017], [gọi API đối tác vận chuyển để tính phí vận chuyển động theo địa chỉ giao nhận.], [UC-005], [Cao],
    [REQ-018], [kết nối cổng thanh toán để tạo phiên giao dịch và kiểm tra trạng thái thanh toán trực tuyến.], [UC-005], [Cao],
    [REQ-019], [khóa số tiền thanh toán của người mua vào ví tạm giữ ngay khi giao dịch được xác nhận thành công.], [UC-005], [Cao],
    [REQ-020], [tự động hủy đơn và giải phóng tồn kho nếu người mua không hoàn tất thanh toán trong 24 giờ.], [UC-005], [Cao],

    table.cell(colspan: 4, align: left)[*Nhóm 5 — Trả hàng, hoàn tiền và tranh chấp*],
    [REQ-021], [cho phép người mua gửi yêu cầu hoàn tiền trong vòng 72 giờ kể từ khi xác nhận nhận hàng.], [UC-006], [Cao],
    [REQ-022], [bắt buộc người mua tải lên video mở hộp và ảnh minh chứng khi gửi yêu cầu hoàn tiền.], [UC-006], [Cao],
    [REQ-023], [tạm dừng bộ đếm giải ngân và chuyển đơn sang trạng thái "Yêu cầu trả hàng" khi tiếp nhận khiếu nại.], [UC-006], [Cao],
    [REQ-024], [cho phép người bán từ chối hoàn tiền kèm bằng chứng đối chứng trong vòng 48 giờ, tạo hồ sơ tranh chấp.], [UC-007], [Cao],
    [REQ-025], [hiển thị song song toàn bộ hồ sơ tranh chấp và bằng chứng hai phía cho Moderator.], [UC-007, UC-008], [Cao],
    [REQ-026], [giải phóng dòng tiền tạm giữ theo đúng phán quyết của Moderator ngay khi phán quyết được ban hành.], [UC-008], [Cao],

    table.cell(colspan: 4, align: left)[*Nhóm 6 — Đánh giá và uy tín*],
    [REQ-027], [cho phép người mua đánh giá sao và viết nhận xét cho người bán sau khi đơn hàng hoàn thành.], [UC-009], [T. bình],
    [REQ-050], [cho phép người bán phản hồi công khai một lần đối với mỗi đánh giá nhận được.], [UC-009], [Thấp],
    [REQ-051], [cập nhật điểm uy tín của người bán theo tỷ lệ giao hàng thành công và số lượt khiếu nại hợp lệ.], [UC-009], [T. bình],

    table.cell(colspan: 4, align: left)[*Nhóm 7 — Quản trị nhân sự điều phối*],
    [REQ-028], [cho phép duy nhất Admin tạo tài khoản Moderator bằng thông tin nhân sự và thư điện tử.], [UC-010], [Cao],
    [REQ-029], [gửi mật khẩu tạm thời ngẫu nhiên kèm liên kết kích hoạt qua thư điện tử cho Moderator mới.], [UC-010], [Cao],

    table.cell(colspan: 4, align: left)[*Nhóm 8 — Tìm kiếm, duyệt và gợi ý*],
    [REQ-030], [cho phép tìm kiếm sản phẩm bằng từ khóa ngôn ngữ tự nhiên và trả kết quả xếp hạng theo độ liên quan.], [UC-011], [Cao],
    [REQ-031], [cho phép lọc kết quả theo danh mục, khoảng giá, tình trạng và sắp xếp theo mới nhất / giá / độ phổ biến.], [UC-011], [Cao],
    [REQ-032], [hiển thị danh sách gợi ý cá nhân hóa dựa trên lịch sử tương tác của người dùng.], [UC-011], [T. bình],

    table.cell(colspan: 4, align: left)[*Nhóm 9 — Xử lý mục chờ và tồn kho*],
    [REQ-033], [hiển thị cho người bán danh sách mục chờ đã thanh toán kèm thông tin sản phẩm và địa chỉ giao.], [UC-012], [Cao],
    [REQ-034], [cho phép người bán xem trước phí vận chuyển rồi xác nhận để tạo đơn hàng và vận đơn, hoặc từ chối để giải phóng tồn kho.], [UC-012], [Cao],
    [REQ-035], [tự động giải phóng tồn kho đã giữ chỗ nếu người bán không xử lý mục chờ trong 48 giờ.], [UC-012], [Cao],

    table.cell(colspan: 4, align: left)[*Nhóm 10 — Ví điện tử và rút tiền*],
    [REQ-036], [hiển thị số dư khả dụng, số dư đang tạm giữ và lịch sử biến động số dư của người dùng.], [UC-013], [Cao],
    [REQ-037], [cho phép người bán yêu cầu rút phần số dư khả dụng về tài khoản ngân hàng đã đăng ký.], [UC-013], [Cao],
    [REQ-038], [ghi nhật ký chỉ-thêm-mới mọi yêu cầu rút tiền và chỉ ghi giảm số dư sau khi lệnh chi được xác nhận thành công.], [UC-013], [Cao],

    table.cell(colspan: 4, align: left)[*Nhóm 11 — Xác nhận nhận hàng và giải ngân tự động*],
    [REQ-039], [bắt buộc người mua tải lên tối thiểu một video mở hộp hoặc ảnh sản phẩm thực tế khi xác nhận nhận hàng.], [UC-014], [Cao],
    [REQ-040], [khởi động bộ đếm ngược bền 72 giờ kể từ thời điểm người mua xác nhận nhận hàng.], [UC-014], [Cao],
    [REQ-041], [tự động giải ngân cho người bán khi hết 72 giờ mà không có yêu cầu hoàn tiền, sau khi trừ phí sàn và phí vận chuyển theo phương án phân bổ.], [UC-014], [Cao],

    table.cell(colspan: 4, align: left)[*Nhóm 12 — Kiểm duyệt nội dung*],
    [REQ-042], [quét tự động từ khóa và đặc trưng hình ảnh của mọi bài đăng mới trước khi cho hiển thị công khai.], [UC-015], [Cao],
    [REQ-043], [đưa bài đăng có dấu hiệu vi phạm vào trạng thái "Chờ kiểm duyệt" và tạo yêu cầu xử lý cho Moderator.], [UC-015], [Cao],
    [REQ-044], [cho phép Moderator gỡ bài đăng, cảnh cáo hoặc khóa tài khoản người đăng, kèm ghi nhật ký quyết định.], [UC-015], [Cao],
    [REQ-045], [cho phép người dùng báo cáo một bài đăng kèm lý do phân loại và mô tả tự do.], [UC-016], [T. bình],
    [REQ-046], [tự động chuyển bài đăng sang hàng đợi kiểm duyệt khi nhận đủ 5 lượt báo cáo từ người dùng độc lập.], [UC-016], [T. bình],

    table.cell(colspan: 4, align: left)[*Nhóm 13 — Cấu hình tham số và đối soát*],
    [REQ-047], [cho phép Admin cấu hình các tham số vận hành: thời hạn tạm giữ, tỷ lệ phí sàn, ngưỡng báo cáo, thời hạn xử lý mục chờ.], [UC-017], [Cao],
    [REQ-048], [hiển thị bảng đối soát tổng số dư tạm giữ toàn hệ thống và đối chiếu với tổng bút toán sổ cái.], [UC-017], [Cao],
    [REQ-049], [ghi nhật ký kiểm toán bất biến cho mọi thay đổi tham số hệ thống kèm danh tính người thực hiện.], [UC-017], [Cao],
  )
)

=== Tiêu chí chấp nhận của các yêu cầu trọng yếu
Các yêu cầu có rủi ro nghiệp vụ cao được gắn tiêu chí chấp nhận theo cấu trúc *Given — When — Then* (Bối cảnh — Hành động — Kết quả mong đợi), bao gồm cả trường hợp thuận lợi và trường hợp lỗi, làm đầu vào trực tiếp cho kịch bản kiểm thử.

#figure(
  caption: [Tiêu chí chấp nhận (Given–When–Then) của các yêu cầu chức năng trọng yếu],
  table(
    columns: (0.62fr, 2.1fr, 2.1fr, 2.1fr),
    align: (center + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Mã], [Bối cảnh (Given)], [Hành động (When)], [Kết quả mong đợi (Then)]),
    [REQ-012], [Người bán đang ở biểu mẫu đăng bán, chưa nhập giá], [Bấm "Đăng bài" với giá bằng 0], [Hệ thống từ chối lưu, hiển thị lỗi tại trường giá, dữ liệu đã nhập được giữ nguyên],
    [REQ-016], [Offer Card còn hiệu lực, sản phẩm vẫn `Active`], [Người mua bấm "Chấp nhận"], [Mục chờ được sinh với đúng đơn giá trên thẻ; thẻ chuyển `Đã chấp nhận` và không thể dùng lại],
    [REQ-016], [Offer Card đã phát hành quá 24 giờ], [Người mua bấm "Chấp nhận"], [Hệ thống từ chối, thông báo thẻ đã hết hiệu lực, không sinh mục chờ],
    [REQ-019], [Người mua đã hoàn tất chuyển khoản tại cổng thanh toán], [Cổng thanh toán gửi webhook thành công], [Số tiền được ghi vào ví tạm giữ, đơn chuyển `PAID_ESCROW`, sổ cái có bút toán tương ứng],
    [REQ-019], [Webhook thanh toán bị gửi trùng hai lần cùng mã giao dịch], [Hệ thống nhận webhook lần thứ hai], [Không phát sinh bút toán mới, số dư tạm giữ không bị tăng gấp đôi],
    [REQ-020], [Đơn ở trạng thái `PENDING_PAYMENT` được tạo cách đây 24 giờ], [Bộ định thời hết hạn], [Đơn chuyển `CANCELED`, tồn kho đã giữ chỗ được giải phóng, người mua nhận thông báo],
    [REQ-022], [Người mua chọn lý do "hàng không đúng mô tả"], [Gửi yêu cầu hoàn tiền không kèm video mở hộp], [Hệ thống từ chối tiếp nhận, nêu rõ bằng chứng bắt buộc theo BR-006],
    [REQ-026], [Hồ sơ tranh chấp đang `Chờ phân xử`, bộ đếm 72 giờ đã hết], [Moderator ban hành phán quyết người mua thắng], [Tiền tạm giữ hoàn về ví người mua ngay, bộ đếm tự động bị vô hiệu, nhật ký kiểm toán được ghi],
    [REQ-035], [Mục chờ đã thanh toán, người bán không xử lý sau 48 giờ], [Bộ định thời hết hạn], [Tồn kho được giải phóng, người mua được hoàn 100% tiền tạm giữ, mục chờ đóng],
    [REQ-037], [Ví có 500.000 đồng khả dụng và 2.000.000 đồng đang tạm giữ], [Người bán yêu cầu rút 1.000.000 đồng], [Hệ thống từ chối, thông báo vượt số dư khả dụng, nêu rõ phần đang tạm giữ không thể rút],
    [REQ-040], [Người mua vừa xác nhận nhận hàng kèm bằng chứng], [Dịch vụ `order` bị khởi động lại sau 10 giờ], [Bộ đếm bền được phục hồi, tiếp tục đếm phần thời gian còn lại, không đặt lại về 72 giờ],
    [REQ-041], [Đơn ở `AWAITING_SETTLEMENT` suốt 72 giờ, không có khiếu nại], [Bộ đếm bền hết hạn], [Tiền chuyển từ ví tạm giữ sang ví khả dụng của người bán, đã trừ phí sàn và phí ship theo BR-012],
    [REQ-046], [Bài đăng đã nhận 4 lượt báo cáo từ 4 tài khoản khác nhau], [Tài khoản thứ năm (khác IP) gửi báo cáo], [Bài đăng chuyển `Chờ kiểm duyệt`, ẩn khỏi kết quả tìm kiếm, xuất hiện trong hàng đợi Moderator],
  )
)

=== Ma trận CRUD kiểm tra độ đầy đủ của yêu cầu
Ma trận đối chiếu các thực thể dữ liệu cốt lõi với bốn thao tác Create – Read – Update – Delete nhằm phát hiện khoảng trống yêu cầu (thực thể có thao tác tạo nhưng không có thao tác đọc, hoặc ngược lại). Ký hiệu `—` thể hiện khoảng trống *có chủ ý*, kèm lý do ở cột ghi chú.

#figure(
  caption: [Ma trận CRUD đối chiếu thực thể dữ liệu với các yêu cầu chức năng],
  table(
    columns: (1.25fr, 1.05fr, 1.1fr, 1.2fr, 0.95fr, 1.5fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Thực thể], [Create], [Read], [Update], [Delete], [Ghi chú khoảng trống]),
    [Account / Profile], [REQ-001, REQ-005], [REQ-006, REQ-036], [REQ-029], [—], [Không xóa vật lý, chỉ khóa tài khoản để bảo toàn dấu vết giao dịch.],
    [Listing (bài đăng)], [REQ-010, REQ-011], [REQ-030, REQ-031], [REQ-043, REQ-044], [REQ-044], [Gỡ bài là chuyển trạng thái, dữ liệu vẫn lưu phục vụ kiểm toán.],
    [Chat / Offer Card], [REQ-013, REQ-015], [REQ-014], [REQ-016], [—], [Tin nhắn và vòng đời thẻ là bằng chứng, không cho xóa.],
    [Mục chờ / Đơn hàng], [REQ-016, REQ-019], [REQ-033], [REQ-034, REQ-040, REQ-041], [REQ-020, REQ-035], [Hủy đơn là chuyển trạng thái `CANCELED`.],
    [Bằng chứng đa phương tiện], [REQ-022, REQ-039], [REQ-025], [—], [—], [Bất biến sau khi tải lên để giữ giá trị đối chứng.],
    [Hồ sơ hoàn tiền / tranh chấp], [REQ-021, REQ-024], [REQ-025], [REQ-023, REQ-026], [—], [Hồ sơ chỉ đóng, không xóa.],
    [Ví / Bút toán sổ cái], [REQ-005, REQ-037], [REQ-036, REQ-048], [REQ-019, REQ-038, REQ-041], [—], [Sổ cái chỉ-thêm-mới; điều chỉnh bằng bút toán đảo ứng.],
    [Tồn kho (serial/SKU)], [REQ-010], [REQ-033], [REQ-019, REQ-035], [—], [Giữ chỗ và giải phóng đều là cập nhật trạng thái.],
    [Đánh giá / Uy tín], [REQ-027, REQ-050], [REQ-030, REQ-031], [REQ-051], [—], [Gỡ đánh giá vi phạm thuộc quyền Admin, ngoài phạm vi tự phục vụ.],
    [Báo cáo bài đăng], [REQ-045], [REQ-044], [REQ-046], [—], [Báo cáo là bằng chứng hành vi, không cho người dùng thu hồi.],
    [Tham số hệ thống], [REQ-047], [REQ-047], [REQ-047], [—], [Tham số chỉ được sửa, không xóa; mọi thay đổi ghi nhật ký (REQ-049).],
    [Nhật ký kiểm toán], [REQ-049], [REQ-048], [—], [—], [Chỉ-thêm-mới theo NFR-009, NFR-010.],
    [Chỉ mục vector tìm kiếm], [REQ-042 (tự động)], [REQ-030], [REQ-032], [—], [Sinh và cập nhật tự động qua sự kiện, không phải thao tác người dùng.],
  )
)

=== Ma trận truy xuất nguồn gốc yêu cầu
Ma trận dưới đây liên kết ba tầng tài liệu: ca sử dụng nguồn → yêu cầu chức năng → thực thể dữ liệu và dịch vụ chủ quản, cho phép kiểm tra tác động hai chiều khi có thay đổi phạm vi.

#figure(
  caption: [Ma trận truy xuất nguồn gốc: Ca sử dụng — Yêu cầu — Thực thể — Dịch vụ],
  table(
    columns: (1.35fr, 1.25fr, 2.1fr, 0.95fr),
    align: (left + horizon, left + horizon, left + horizon, center + horizon),
    table.header([Ca sử dụng nguồn], [Yêu cầu], [Thực thể dữ liệu bị ảnh hưởng], [Dịch vụ]),
    [UC-001 Đăng ký tài khoản], [REQ-001…005], [`account`, `profile`, `wallet`], [`account`],
    [UC-002 Đăng nhập], [REQ-006…009], [`account`, `device` (refresh token)], [`account`],
    [UC-003 Đăng bán sản phẩm], [REQ-010…012], [`product_spu`, `product_sku`, `category`, `resource`], [`catalog`],
    [UC-004 Nhắn tin & thương lượng], [REQ-013…016], [`conversation`, `message`, `offer`, `cart_item`], [`chat`],
    [UC-005 Đặt hàng & Escrow], [REQ-017…020], [`draft_order`, `item`, `payment_session`, `transaction`, `stock`], [`order`],
    [UC-006 Yêu cầu hoàn tiền], [REQ-021…023], [`refund`, `transport`, `resource`], [`order`],
    [UC-007 Khiếu nại & tranh chấp], [REQ-024, REQ-025], [`refund_dispute`, `resource`], [`order`],
    [UC-008 Phân xử tranh chấp], [REQ-025, REQ-026], [`refund_dispute`, `wallet_transaction`, `audit_log`], [`order`, `account`],
    [UC-009 Đánh giá & phản hồi], [REQ-027, REQ-050, REQ-051], [`review`, `review_reply`, `reputation`], [`analytic`],
    [UC-010 Cấp phát Moderator], [REQ-028, REQ-029], [`account`, `audit_log`], [`account`],
    [UC-011 Tìm kiếm & duyệt], [REQ-030…032], [`product_embedding`, `interaction`], [`analytic`, `catalog`],
    [UC-012 Xử lý mục chờ], [REQ-033…035], [`item`, `order`, `transport`, `stock`], [`order`, `inventory`],
    [UC-013 Ví & rút tiền], [REQ-036…038], [`wallet`, `wallet_transaction`, `bank_account`], [`account`],
    [UC-014 Xác nhận nhận hàng], [REQ-039…041], [`order`, `resource`, `wallet_transaction`], [`order`, `account`],
    [UC-015 Kiểm duyệt bài đăng], [REQ-042…044], [`product_spu`, `report`, `audit_log`], [`catalog`],
    [UC-016 Báo cáo bài đăng], [REQ-045, REQ-046], [`report`], [`catalog`],
    [UC-017 Cấu hình & đối soát], [REQ-047…049], [`option`, `audit_log`, `wallet`], [`common`, `account`],
  )
)

#figure(
  caption: [Thống kê độ bao phủ của bộ yêu cầu chức năng],
  table(
    columns: (2.2fr, 1fr, 2.4fr),
    align: (left + horizon, center + horizon, left + horizon),
    table.header([Chỉ số], [Giá trị], [Ghi chú]),
    [Tổng số yêu cầu chức năng], [51], [`REQ-001` … `REQ-051`, mã duy nhất, không trùng lặp.],
    [Số yêu cầu ưu tiên Cao], [45], [Bắt buộc hoàn thành cho bản demo cuối kỳ.],
    [Số yêu cầu ưu tiên Trung bình], [5], [Nên có, có thể rút gọn phạm vi nếu thiếu thời gian.],
    [Số yêu cầu ưu tiên Thấp], [1], [Phản hồi đánh giá của người bán (REQ-050).],
    [Số ca sử dụng được bao phủ], [17 / 17], [Mỗi ca sử dụng có tối thiểu hai yêu cầu dẫn xuất.],
    [Số thực thể dữ liệu được bao phủ], [13 / 13], [Theo ma trận CRUD, không còn thực thể thiếu thao tác đọc hoặc tạo.],
    [Số yêu cầu có tiêu chí chấp nhận chi tiết], [13], [Tập trung vào các yêu cầu thuộc luồng dòng tiền và kiểm duyệt.],
  )
)

=== Phân bổ yêu cầu chức năng theo bảy vi dịch vụ
Bộ yêu cầu chức năng được ánh xạ về dịch vụ chủ quản, làm cơ sở cho việc phân rã kiến trúc ở mục 3.6:
- *Dịch vụ `account` (Tài khoản & Ví) — REQ-001…009, REQ-036…038:* quản lý định danh, đăng nhập bằng cặp Access/Refresh Token, phân quyền theo vai trò; quản lý ví với hai loại số dư *khả dụng* và *tạm giữ*, ghi bút toán sổ cái chỉ-thêm-mới.
- *Dịch vụ `catalog` (Danh mục & Bài đăng) — REQ-010…012, REQ-042…046:* quản lý bài đăng C2C với danh mục ba cấp, hai chế độ giá, phương án phân bổ phí ship; quét nội dung tự động, hàng đợi kiểm duyệt và tiếp nhận báo cáo vi phạm.
- *Dịch vụ `chat` (Hội thoại & Thương lượng) — REQ-013…016:* duy trì kênh thời gian thực, lưu trữ hội thoại; xử lý vòng đời Offer Card (phát hành, chấp nhận, từ chối, hết hiệu lực, thu hồi).
- *Dịch vụ `order` (Đơn hàng & Escrow) — REQ-017…026, REQ-033…035, REQ-039…041:* điều phối vòng đời đơn hàng theo sơ đồ trạng thái tại mục 3.4.6; hiện thực các luồng bền khóa tiền tạm giữ, đếm ngược 72 giờ, hoàn tiền và tranh chấp.
- *Dịch vụ `inventory` (Tồn kho) — REQ-019, REQ-033…035:* kiểm soát tồn kho theo serial/SKU, giữ chỗ khi khởi tạo thanh toán và giải phóng khi hủy đơn hoặc người bán từ chối.
- *Dịch vụ `analytic` (Tìm kiếm & Uy tín) — REQ-030…032, REQ-051:* duy trì chỉ mục vector trên pgvector, cung cấp tìm kiếm kết hợp ngữ nghĩa – từ khóa, tính điểm uy tín và sinh gợi ý cá nhân hóa.
- *Dịch vụ `common` (Cổng vào & Hạ tầng dùng chung) — REQ-047…049 và toàn bộ lớp cắt ngang:* định tuyến lưu lượng, xác thực token tập trung, quản lý tham số hệ thống, lưu trữ tài nguyên đa phương tiện và đẩy sự kiện thời gian thực về thiết bị người dùng.

=== Yêu cầu phi chức năng (Non-Functional Requirements)
Bộ yêu cầu phi chức năng gồm *29 yêu cầu* được đánh mã `NFR-001` … `NFR-029`, phân theo bốn nhóm thuộc tính chất lượng. Mỗi yêu cầu đều kèm *tiêu chí định lượng* và *phương pháp kiểm chứng* để có thể nghiệm thu khách quan, thay cho các phát biểu định tính như "nhanh" hay "an toàn".

#figure(
  caption: [Đặc tả yêu cầu phi chức năng — nhóm Hiệu năng và Khả năng chịu tải],
  table(
    columns: (0.6fr, 3.5fr, 1.5fr, 0.6fr),
    align: (center + horizon, left + horizon, left + horizon, center + horizon),
    table.header([Mã], [Phát biểu và tiêu chí định lượng], [Cách kiểm chứng], [Ư. tiên]),
    [NFR-018], [Thời gian phản hồi ở phân vị 95 (p95) của các API đọc dữ liệu và tìm kiếm sản phẩm không vượt quá 150 ms, đo tại tầng cổng vào, chưa tính độ trễ mạng người dùng cuối.], [Kiểm thử tải bằng k6, báo cáo phân vị p50/p95/p99], [Cao],
    [NFR-019], [Độ trễ đẩy tin nhắn hội thoại và thông báo trạng thái đơn hàng tới thiết bị người dùng không vượt quá 1 giây kể từ khi sự kiện được ghi bền.], [Đo mốc thời gian hai đầu trên kênh sự kiện], [Cao],
    [NFR-020], [Thời gian phản hồi p95 của các API ghi đi qua Restate (đặt hàng, thanh toán, khiếu nại) không vượt quá 300 ms ở mức tải 500 người dùng đồng thời.], [Kiểm thử tải với kịch bản đặt hàng đồng thời], [Cao],
    [NFR-021], [Hệ thống phục vụ tối thiểu 500 người dùng đồng thời và 5.000 đơn hàng mỗi ngày trên hạ tầng demo một nút, không xuất hiện lỗi máy chủ nội bộ.], [Kiểm thử tải kéo dài 30 phút], [T. bình],
    [NFR-022], [Truy vấn tìm kiếm kết hợp trên chỉ mục vector phải trả kết quả trong một truy vấn cơ sở dữ liệu duy nhất, không thực hiện lọc lại ở tầng ứng dụng.], [Rà soát kế hoạch thực thi truy vấn], [T. bình],
    [NFR-001], [Mọi lời gọi API tới dịch vụ bên thứ ba (cổng thanh toán, đối tác vận chuyển) phải có thời hạn chờ tối đa 5 giây và cơ chế thử lại lùi thời gian tối đa 3 lần trước khi báo lỗi cho người dùng.], [Kiểm thử tích hợp với bộ giả lập lỗi], [Cao],
  )
)

#figure(
  caption: [Đặc tả yêu cầu phi chức năng — nhóm Bảo mật và Kiểm toán],
  table(
    columns: (0.6fr, 3.5fr, 1.5fr, 0.6fr),
    align: (center + horizon, left + horizon, left + horizon, center + horizon),
    table.header([Mã], [Phát biểu và tiêu chí định lượng], [Cách kiểm chứng], [Ư. tiên]),
    [NFR-002], [Mật khẩu phải được băm bằng Argon2id hoặc bcrypt với hệ số công việc từ 12 trở lên; hệ thống không bao giờ lưu hoặc ghi log mật khẩu dạng nguyên bản.], [Rà soát mã nguồn và kiểm tra bản ghi log], [Cao],
    [NFR-003], [Access token có thời gian sống tối đa 30 phút, Refresh token tối đa 7 ngày, lưu dưới dạng băm trong cơ sở dữ liệu và có thể thu hồi.], [Kiểm thử vòng đời token], [Cao],
    [NFR-004], [Tài khoản bị khóa tạm thời sau 5 lần đăng nhập sai liên tiếp trong 15 phút, kèm giới hạn tần suất theo địa chỉ IP.], [Kiểm thử chống dò mật khẩu], [Cao],
    [NFR-005], [Áp dụng kiểm soát truy cập theo vai trò tại tầng cổng vào: mọi endpoint phân xử và quản trị chỉ chấp nhận token có vai trò tương ứng.], [Kiểm thử phân quyền chéo vai trò], [Cao],
    [NFR-006], [Áp dụng kiểm soát truy cập cấp đối tượng: người dùng chỉ đọc hoặc sửa được tài nguyên thuộc sở hữu của mình, xác minh quyền sở hữu ở tầng nghiệp vụ chứ không chỉ dựa vào vai trò.], [Kiểm thử truy cập tài nguyên của người khác], [Cao],
    [NFR-007], [Toàn bộ dữ liệu nhập từ người dùng phải được kiểm tra và làm sạch ở tầng API; mọi truy vấn dùng câu lệnh tham số hóa, không nối chuỗi SQL thủ công.], [Rà soát mã nguồn, quét lỗ hổng tự động], [Cao],
    [NFR-008], [Áp dụng giới hạn tần suất theo IP và theo tài khoản cho các endpoint nhạy cảm: đăng ký, đăng nhập, phát hành Offer Card, gửi yêu cầu hoàn tiền, báo cáo bài đăng.], [Kiểm thử vượt ngưỡng tần suất], [Cao],
    [NFR-009], [Mọi thao tác làm thay đổi số dư ví phải ghi bản ghi kiểm toán chỉ-thêm-mới kèm dấu thời gian, danh tính người thực hiện và trạng thái trước/sau.], [Đối chiếu bút toán với nhật ký kiểm toán], [Cao],
    [NFR-010], [Các thao tác nhạy cảm của Admin và Moderator (cấp phát tài khoản, phán quyết, gỡ bài, đổi tham số) phải ghi nhật ký riêng và không thể chỉnh sửa hoặc xóa sau khi tạo.], [Kiểm thử thử sửa/xóa bản ghi kiểm toán], [Cao],
    [NFR-023], [Toàn bộ giao tiếp giữa thiết bị người dùng và hệ thống phải được mã hóa bằng TLS phiên bản 1.2 trở lên; không phục vụ nội dung qua kênh không mã hóa.], [Quét cấu hình TLS], [Cao],
    [NFR-024], [Thông tin định danh cá nhân (số điện thoại, địa chỉ giao hàng, số tài khoản ngân hàng) chỉ được trả về cho chính chủ sở hữu hoặc cho Moderator trong phạm vi một hồ sơ tranh chấp đang mở.], [Kiểm thử che dữ liệu theo vai trò], [Cao],
  )
)

#figure(
  caption: [Đặc tả yêu cầu phi chức năng — nhóm Tin cậy, Khả dụng và Bền vững dữ liệu],
  table(
    columns: (0.6fr, 3.5fr, 1.5fr, 0.6fr),
    align: (center + horizon, left + horizon, left + horizon, center + horizon),
    table.header([Mã], [Phát biểu và tiêu chí định lượng], [Cách kiểm chứng], [Ư. tiên]),
    [NFR-017], [Các luồng nghiệp vụ tài chính dài hạn (khóa tạm giữ, đếm ngược 72 giờ, hoàn tiền, tranh chấp) phải tự phục hồi và hoàn tất chính xác đúng một lần sau sự cố sập tiến trình hoặc mất kết nối.], [Kiểm thử tiêm lỗi: dừng tiến trình giữa luồng], [Cao],
    [NFR-025], [Mọi biến động dòng tiền trong ví tạm giữ phải tuân thủ bốn tính chất ACID; không được phép xảy ra mất mát hoặc nhân đôi số dư trong bất kỳ tình huống lỗi nào.], [Kiểm thử đối soát tổng số dư sau kịch bản lỗi], [Cao],
    [NFR-026], [Mức khả dụng mục tiêu của toàn hệ thống đạt tối thiểu 99,5% theo tháng, tương đương thời gian gián đoạn không quá khoảng 3,6 giờ mỗi tháng.], [Theo dõi thời gian hoạt động qua giám sát], [T. bình],
    [NFR-027], [Cơ sở dữ liệu được sao lưu tự động hằng ngày; mục tiêu thời gian phục hồi (RTO) không quá 4 giờ và mục tiêu điểm phục hồi (RPO) không quá 24 giờ.], [Diễn tập phục hồi từ bản sao lưu], [T. bình],
    [NFR-028], [Không dịch vụ nào được truy cập trực tiếp lược đồ cơ sở dữ liệu của dịch vụ khác; mọi tham chiếu chéo là tham chiếu logic được giải quyết qua lời gọi dịch vụ.], [Rà soát mã nguồn và quyền cơ sở dữ liệu], [Cao],
  )
)

#figure(
  caption: [Đặc tả yêu cầu phi chức năng — nhóm Khả năng sử dụng, Bảo trì và Ràng buộc],
  table(
    columns: (0.6fr, 3.5fr, 1.5fr, 0.6fr),
    align: (center + horizon, left + horizon, left + horizon, center + horizon),
    table.header([Mã], [Phát biểu và tiêu chí định lượng], [Cách kiểm chứng], [Ư. tiên]),
    [NFR-011], [Giao diện web hiển thị đúng bố cục trên dải độ phân giải từ 360 px đến 1920 px theo nguyên tắc thiết kế ưu tiên thiết bị di động.], [Kiểm thử giao diện đa kích thước màn hình], [Cao],
    [NFR-012], [Giao diện tuân thủ tối thiểu mức A của WCAG 2.1: đạt chuẩn tương phản màu, mọi hình ảnh có văn bản thay thế, các luồng chính thao tác được bằng bàn phím.], [Quét kiểm tra khả năng tiếp cận], [T. bình],
    [NFR-013], [Mọi thao tác không thể hoàn tác (xác nhận nhận hàng, chấp nhận Offer Card, xác nhận thanh toán, phán quyết tranh chấp) phải có bước xác nhận rõ ràng kèm cảnh báo hệ quả.], [Rà soát luồng giao diện], [Cao],
    [NFR-029], [Mã nguồn tầng nghiệp vụ phải đạt tối thiểu 70% độ phủ kiểm thử đơn vị ở các gói xử lý dòng tiền; mọi thay đổi phải qua kiểm thử tự động trước khi hợp nhất.], [Báo cáo độ phủ trong quy trình tích hợp liên tục], [T. bình],
    [NFR-014], [Việc tính phí và theo dõi vận chuyển phụ thuộc API đối tác bên thứ ba; độ chính xác và thời gian phản hồi bị giới hạn bởi cam kết dịch vụ của đối tác, hệ thống phải có phương án dự phòng bằng bảng phí mặc định.], [Kiểm thử với bộ giả lập đối tác], [Cao],
    [NFR-015], [Xác nhận thanh toán phụ thuộc webhook của cổng thanh toán; hệ thống phải xử lý được trường hợp webhook đến trễ, đến trùng hoặc không đến bằng cơ chế đối soát chủ động.], [Kiểm thử webhook trễ và trùng lặp], [Cao],
    [NFR-016], [Hệ thống phải tuân thủ pháp luật Việt Nam về thương mại điện tử và bảo vệ dữ liệu cá nhân (Nghị định 13/2023/NĐ-CP) đối với thông tin định danh, số điện thoại và địa chỉ thu thập từ người dùng.], [Rà soát đối chiếu quy định], [Cao],
  )
)

#figure(
  caption: [Truy xuất yêu cầu phi chức năng tới quyết định kiến trúc và cơ chế hiện thực],
  table(
    columns: (1.15fr, 1.5fr, 2.6fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Yêu cầu], [Quyết định kiến trúc], [Cơ chế hiện thực tương ứng]),
    [NFR-017, NFR-025], [ADR-01 (Restate)], [Luồng bền có ghi nhật ký thực thi, bộ định thời bền, bảo đảm thực thi đúng một lần.],
    [NFR-018, NFR-020], [ADR-01 (tách luồng đọc/ghi)], [Truy vấn đọc gọi trực tiếp dịch vụ qua HTTP/2, không đi qua cổng bền để tránh chi phí phụ trội.],
    [NFR-028], [ADR-02 (Database-per-service)], [Mỗi dịch vụ một lược đồ riêng, không khai báo khóa ngoại xuyên lược đồ, tham chiếu logic giải quyết qua RPC.],
    [NFR-019], [ADR-03 (NATS JetStream)], [Trục sự kiện bất đồng bộ kết hợp kênh đẩy sự kiện tới trình duyệt và ứng dụng di động.],
    [NFR-022], [ADR-04 (pgvector + bge-m3)], [Chỉ mục vector nằm cùng cơ sở dữ liệu quan hệ, cho phép lọc thuộc tính và xếp hạng trong một truy vấn duy nhất.],
    [NFR-009, NFR-010], [Thiết kế kiến trúc & CSDL (mục 3.6, 3.9)], [Bảng nhật ký kiểm toán chỉ-thêm-mới ở từng lược đồ, không cấp quyền cập nhật hay xóa cho tài khoản ứng dụng.],
    [NFR-015, NFR-014], [ADR-01, thiết kế xử lý lỗi], [Đối soát chủ động theo chu kỳ, khóa lũy đẳng cho webhook, phương án dự phòng khi đối tác không phản hồi.],
  )
)

#note[*Quy ước mã hiệu.* Bộ mã `NFR-001` … `NFR-016` được giữ nguyên từ giai đoạn phân tích ở báo cáo lần 1 để bảo toàn các tham chiếu đã ban hành. Bốn phát biểu định tính về hiệu năng, tính bền vững, bảo mật đường truyền và kiểm toán nêu ở báo cáo lần 1 nay được *phát biểu lại theo hướng định lượng* kèm phương pháp kiểm chứng và đánh mã tiếp từ `NFR-017` trở đi, nhờ đó mỗi yêu cầu phi chức năng đều có thể nghiệm thu bằng một phép đo cụ thể.]

== Thiết kế kiến trúc tổng thể hệ thống (System Architecture)

=== Phân rã vi dịch vụ theo mô hình hướng miền (DDD Subdomains)
Hệ thống ShopNexus được phân rã thành các dịch vụ vi mô tự chứa dựa trên các miền con (Subdomains) đã được xác định trong quá trình phân tích Domain-Driven Design. Kiến trúc tổng thể và các dòng tương tác liên dịch vụ được mô tả trực quan qua Sơ đồ Kiến trúc Microservices:

#fig(
  [Sơ đồ Kiến trúc Durable Microservices hệ thống ShopNexus C2C (System Architecture Diagram)],
  spacing: (24mm, 15mm),
  np((0, 3), [Client\ (Next.js Web / Flutter Mobile)]),
  edge((0, 3), (2, 3), "-|>", text(size: 8pt)[HTTPS]),
  ncore((2, 3), [Restate Ingress\ (Proxy, Mutation)]),

  edge((2, 3), (4.5, 0), "-|>"),
  edge((2, 3), (4.5, 1), "-|>"),
  edge((2, 3), (4.5, 2), "-|>"),
  edge((2, 3), (4.5, 3), "-|>"),
  edge((2, 3), (4.5, 4), "-|>"),
  edge((2, 3), (4.5, 5), "-|>"),
  edge((2, 3), (4.5, 6), "-|>"),

  // query path bỏ qua Ingress, gọi thẳng service qua HTTP/2
  edge((0, 3), (4.5, 1), "-|>", stroke: (paint: ink, thickness: 1pt, dash: "dashed"), text(size: 7pt)[Query: HTTP/2 trực tiếp]),

  np((4.5, 0), [Account\ Service]),
  np((4.5, 1), [Catalog\ Service]),
  np((4.5, 2), [Chat & Offer\ Service]),
  np((4.5, 3), [Order Service #text(size: 7pt)[(Durable)]]),
  np((4.5, 4), [Inventory\ Service]),
  np((4.5, 5), [Analytic\ Service]),
  np((4.5, 6), [Common Service #text(size: 7pt)[(SSE/Storage)]]),

  edge((4.5, 0), (7, 0), "-|>"),
  edge((4.5, 1), (7, 1), "-|>", text(size: 7pt)[bge-m3 hybrid]),
  edge((4.5, 2), (7, 2), "-|>"),
  edge((4.5, 3), (7, 3), "-|>"),
  edge((4.5, 4), (7, 4), "-|>"),
  edge((4.5, 5), (7, 5), "-|>"),
  edge((4.5, 6), (7, 6), "-|>"),

  ng((7, 0), [PostgreSQL\ (account)]),
  ng((7, 1), [PostgreSQL\ (catalog + pgvector)]),
  ng((7, 2), [PostgreSQL\ (chat)]),
  ng((7, 3), [PostgreSQL\ (order, incl. refund/dispute)]),
  ng((7, 4), [PostgreSQL\ (inventory)]),
  ng((7, 5), [PostgreSQL\ (analytic)]),
  ng((7, 6), [Redis + Object Storage]),

  // NATS JetStream event bus
  ncore((4.5, 7.5), [NATS JetStream\ (Event Bus, Async Communication)]),
  edge((4.5, 2), (4.5, 7.5), "<->"),
  edge((4.5, 3), (4.5, 7.5), "<->"),
  edge((4.5, 5), (4.5, 7.5), "<->"),
  edge((4.5, 6), (4.5, 7.5), "<->"),

  // External systems
  ng((2, 5.5), [SePay / Stripe\ Gateway]),
  edge((4.5, 3), (2, 5.5), "<->", [API Payment]),
  ng((7, 8.5), [GHN / GHTK\ API]),
  edge((4.5, 3), (7, 8.5), "<->", [Delivery tracking]),

  // Moderator/Admin console
  np((2, 0), [Moderator/Admin\ Console]),
  edge((2, 0), (2, 3), "<->", text(size: 8pt)[REST qua Ingress]),
)

Chi tiết bảng phân chia chức năng và trách nhiệm của từng microservice như sau:

#figure(
  caption: [Bảng phân rã các Microservices và Trách nhiệm nghiệp vụ trong ShopNexus],
  table(
    columns: (1.1fr, 1fr, 1.2fr, 2.7fr),
    align: (left + horizon, center + horizon, left + horizon, left + horizon),
    table.header([Tên Microservice], [Cổng HTTP/gRPC], [CSDL độc lập], [Trách nhiệm cốt lõi (Core Domain Responsibility)]),
    [`account`], [8001 / 9001], [`db_account` (PG)], [Quản lý tài khoản, xác thực JWT/RBAC, quản lý số dư ví khả dụng và số dư tạm giữ Escrow, nhật ký biến động ví.],
    [`catalog`], [8002 / 9002], [`db_catalog` (PG)], [Quản lý danh mục, thông tin bài đăng sản phẩm C2C, định giá Cố định/Thương lượng, trạng thái đăng bán.],
    [`chat`], [8003 / 9003], [`db_chat` (PG)], [Quản lý phòng chat giữa người mua/bán, tin nhắn realtime, phát hành và quản lý vòng đời Thẻ đề xuất giá (Offer Card).],
    [`order`], [8004 / 9004], [`db_order` (PG)], [Điều phối luồng đơn hàng Escrow, hẹn giờ đếm ngược 3 ngày nhận hàng, quản lý quy trình Refund và chuyển giao Dispute.],
    [`inventory`], [8005 / 9005], [`db_inventory` (PG)], [Quản lý số lượng hàng hóa thực tế, giữ chỗ tồn kho (Reservation) khi bắt đầu thanh toán và trừ kho khi giao thành công.],
    [`analytic`], [8006 / 9006], [`db_analytic` (PG + pgvector)], [Sinh và lưu trữ vector nhúng bge-m3, thực hiện truy vấn tìm kiếm Hybrid, thống kê báo cáo và tính toán điểm uy tín.],
    [`common`], [8000 / 9000], [NATS / Redis], [API Gateway điều hướng lưu lượng, xác thực token tập trung, đẩy sự kiện Server-Sent Events (SSE) về trình duyệt.],
  )
)

=== Thiết kế luồng định tuyến Lệnh/Truy vấn (Restate Ingress Proxy vs HTTP/2 Direct RPC)
Để bảo đảm tính bền vững tối đa mà không gây ảnh hưởng đến hiệu năng tổng thể, kiến trúc ShopNexus áp dụng nguyên tắc phân chia luồng định tuyến rõ rệt tại tầng Gateway:
- *Luồng ghi và biến động trạng thái (Mutation / Long-running Workflows):* Khi người dùng thực hiện các thao tác thay đổi dữ liệu nhạy cảm (như Khởi tạo đơn hàng, Bấm nút Thanh toán Escrow, Gửi khiếu nại Refund, hoặc Phân xử Dispute), API Gateway sẽ định hướng lời gọi thông qua *Restate Ingress*. Restate đứng ra làm trung gian tiếp nhận yêu cầu, tạo nhật ký thực thi (Journal Log), sau đó mới điều phối lời gọi RPC đến dịch vụ `order` hoặc `account` tương ứng. Nếu hệ thống sập giữa chừng, Restate tự động phục hồi tác vụ tại điểm dừng mà không cần client gửi lại yêu cầu.
- *Luồng đọc và truy vấn nhanh (Query / Read-Only RPC):* Khi người dùng xem danh sách sản phẩm, tìm kiếm từ khóa, xem lịch sử đơn hàng hoặc thông tin cá nhân, API Gateway hoặc các microservices nội bộ sẽ thực hiện các lời gọi *HTTP/2 RPC trực tiếp* đến dịch vụ chủ quản (`catalog`, `analytic`, `account`). Luồng này bỏ qua hoàn toàn tầng Restate Ingress, giúp rút ngắn thời gian xử lý xuống mức thấp nhất.

=== Kiến trúc luồng sự kiện bất đồng bộ và đồng bộ dữ liệu
Đối với các nghiệp vụ phối hợp hậu kỳ, ShopNexus sử dụng kiến trúc hướng sự kiện với *NATS JetStream*:
- *Transactional Outbox Pattern:* Mọi sự kiện nghiệp vụ (như `OrderPaidEvent`, `OfferAcceptedEvent`) được ghi song song vào bảng `outbox_events` trong cùng một giao dịch SQL ACID với nghiệp vụ chính, bảo đảm dữ liệu CSDL nội bộ và tin nhắn sự kiện không bao giờ bị lệch pha.
- *Đồng bộ chỉ mục tìm kiếm và thông báo thời gian thực:* Dịch vụ `analytic` lắng nghe sự kiện tạo/sửa sản phẩm từ NATS để lập tức qua mô hình `bge-m3` tạo vector nhúng và lưu vào `pgvector`. Dịch vụ `common` lắng nghe các sự kiện chat và biến động Escrow để đẩy thông báo realtime về trình duyệt qua kênh Server-Sent Events (SSE).

=== Danh mục thành phần phân lớp và ma trận trách nhiệm
Mỗi microservice trong hệ thống được tổ chức theo kiến trúc 3 lớp chuẩn mực: *Presentation* (giao diện & handler tiếp nhận request), *Business Logic* (service xử lý nghiệp vụ, validator) và *Data Access* (repository truy xuất CSDL bằng SQLC + pgx).

#fig(
  [Sơ đồ thành phần phân lớp của một microservice điển hình (Layered Component Diagram)],
  spacing: (30mm, 13mm),
  np((0, 0), [Client\ (Next.js / Flutter)]),
  edge((0, 0), (1, 0), "-|>", text(size: 7.5pt)[HTTPS]),
  ncore((1, 0), [Cổng vào\ (Gateway + Restate Ingress)]),
  nr((2.15, 0), text(size: 7.5pt)[Lớp cắt ngang:\ xác thực token, RBAC,\ nhật ký, giới hạn tần suất]),
  edge((1, 0), (1, 1), "-|>", text(size: 7.5pt)[gRPC / HTTP/2]),
  np((1, 1), [*Presentation*\ Handler · DTO · Mapper]),
  edge((1, 1), (1, 2), "-|>", text(size: 7.5pt)[gọi]),
  np((1, 2), [*Business Logic*\ Service · Validator · Workflow bền]),
  edge((1, 2), (1, 3), "-|>", text(size: 7.5pt)[gọi]),
  np((1, 3), [*Data Access*\ Repository (SQLC + pgx)]),
  edge((1, 3), (1, 4), "-|>", text(size: 7.5pt)[SQL]),
  ng((1, 4), [PostgreSQL (lược đồ riêng của dịch vụ)]),
  edge((1, 2), (2.15, 2), "<->", stroke: (dash: "dashed"), text(size: 7.5pt)[sự kiện NATS]),
  ng((2.15, 2), [Dịch vụ khác\ (qua RPC / sự kiện)]),
)

#note[Quy ước phụ thuộc *một chiều*: lớp trên gọi xuống lớp dưới, không tồn tại lời gọi ngược. Lớp Business Logic không bao giờ tự viết câu lệnh SQL, và lớp Data Access không chứa quy tắc nghiệp vụ — nhờ đó các quy tắc BR có thể được kiểm thử đơn vị độc lập với cơ sở dữ liệu (NFR-029).]

#fig(
  [Sơ đồ lớp cụm nghiệp vụ Order (Class Diagram)],
  spacing: (33mm, 16mm),
  np((0, 0), [*OrderHandler*\ + Checkout(req)\ + Pay(req)\ + ConfirmReceived(req)\ + CreateRefund(req)], shape: rect),
  np((0, 1), [*OrderService*\ + Checkout()\ + Pay()\ + ConfirmReceived()\ + CreateRefund()\ + ResolveDispute()], shape: rect),
  np((2, 1), [*OrderValidator*\ + Validate(req)\ + CheckOwnership()\ + CheckTransition()]),
  np((0, 2), [*OrderRepository*\ + Save(o)\ + FindById(id)\ + UpdateStatus()], shape: rect),
  np((2, 2), [*Order* (entity)\ - order\_id, buyer\_id, seller\_id\ - total\_amount, status\ + CanRefund()\ + CanConfirm()]),
  np((2, 0), [*EscrowWorkflow* (durable)\ + Run(order\_id)\ + timer 72h\ *RefundWorkflow* (durable)\ + Run(refund\_id)]),
  np((4, 1), [*AccountService* (RPC)\ + LockEscrow()\ + Release()\ *InventoryService* (RPC)\ + Reserve() / Release()]),
  edge((0, 0), (0, 1), "-|>", text(size: 7.5pt)[dùng]),
  edge((0, 1), (2, 1), "-|>", text(size: 7.5pt)[dùng]),
  edge((0, 1), (0, 2), "-|>", text(size: 7.5pt)[dùng]),
  edge((0, 2), (2, 2), "-|>", text(size: 7.5pt)[trả về]),
  edge((0, 1), (2, 0), "-|>", stroke: (dash: "dashed"), text(size: 7.5pt)[khởi động]),
  edge((2, 0), (4, 1), "-|>", stroke: (dash: "dashed"), text(size: 7.5pt)[gọi bền]),
  edge((0, 1), (4, 1), "-|>", stroke: (dash: "dashed"), bend: -22deg, text(size: 7.5pt)[RPC đọc]),
)

#figure(
  caption: [Đặc tả các lớp chính của cụm nghiệp vụ Order],
  table(
    columns: (1.15fr, 1.7fr, 2.35fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Lớp], [Thuộc tính chính], [Phương thức chính và trách nhiệm]),
    [`Order` (entity)], [`order_id`, `buyer_id`, `seller_id`, `total_amount`, `status`], [`CanRefund()`, `CanConfirm()`, `MarkPaid()` — chứa các bất biến trạng thái theo sơ đồ ở mục 3.4.6.],
    [`OrderService`], [`repo`, `account`, `inventory`, `catalog`], [`Checkout()`, `Pay()`, `ConfirmReceived()`, `CreateRefund()`, `ResolveDispute()` — điều phối nghiệp vụ, không truy cập cơ sở dữ liệu trực tiếp.],
    [`OrderValidator`], [(không trạng thái)], [`Validate()`, `CheckOwnership()`, `CheckTransition()` — chặn phép chuyển trạng thái không hợp lệ và truy cập vượt quyền (NFR-006).],
    [`OrderRepository`], [`db` (nhóm kết nối pgx)], [`Save()`, `FindById()`, `UpdateStatus()` — sinh mã truy vấn bằng SQLC, không chứa quy tắc nghiệp vụ.],
    [`EscrowWorkflow`], [`ctx` (ngữ cảnh Restate), `order_id`], [`Run()` — khóa tiền tạm giữ, đặt bộ định thời 72 giờ, giải ngân tự động khi hết hạn (REQ-040, REQ-041).],
    [`RefundWorkflow`], [`ctx` (ngữ cảnh Restate), `refund_id`], [`Run()` — chờ phản hồi người bán 48 giờ, chờ phán quyết Moderator, thực thi hoàn tiền hoặc giải ngân (REQ-024…026).],
  )
)

#figure(
  caption: [Danh mục các thành phần kiến trúc lõi trong hệ thống ShopNexus],
  table(
    columns: (1.7fr, 1fr, 2fr, 1fr, 1.2fr),
    align: (left + horizon, center + horizon, left + horizon, center + horizon, left + horizon),
    table.header([Thành phần], [Lớp], [Trách nhiệm cốt lõi], [REQ mapping], [Phụ thuộc]),
    [`AuthHandler`], [Presentation], [Nhận request đăng ký/đăng nhập, xác thực token, định tuyến vào service.], [REQ-001…009], [`Account Service`],
    [`OrderHandler`], [Presentation], [Nhận request đặt hàng/thanh toán/hoàn tiền, kiểm tra quyền sở hữu.], [REQ-016…026], [`Order Service`],
    [`AccountService`], [Business], [Đăng ký, đăng nhập, phân quyền, quản lý hồ sơ và số dư ví (khả dụng/Escrow).], [REQ-001…009, 036…038], [`Account Repository`],
    [`CatalogService`], [Business], [Đăng bán, cập nhật trạng thái listing, tìm kiếm hybrid, gợi ý.], [REQ-010…012, 030…032], [`Catalog Repository`],
    [`ChatOfferService`], [Business], [Tin nhắn thời gian thực, tạo/chấp nhận Offer Card, tạo đơn tạm.], [REQ-013…016], [`Chat Repository`, `Order Service`],
    [`OrderService` (Durable)], [Business], [Điều phối Checkout, cổng thanh toán, khóa/giải ngân Escrow, hồ sơ hoàn tiền & tranh chấp.], [REQ-016…026], [`Account Service`, `Catalog Service`, `Inventory Service`],
    [`InventoryService`], [Business], [Reserve/release tồn kho theo serial, audit biến động kho.], [REQ-033…035], [`Inventory Repository`],
    [`AnalyticService`], [Business], [Ghi nhận tương tác, tính điểm phổ biến, cập nhật gợi ý.], [REQ-032], [`Analytic Repository`],
    [`Validators`], [Business], [Kiểm tra dữ liệu đầu vào (giá > 0, đủ trường bắt buộc, định dạng email…).], [REQ-002…003, 012], [(không)],
    [`AccountRepository`], [Data Access], [Truy vấn/ghi bảng `account`, `profile`, `transaction` bằng SQLC + pgx.], [(không)], [PostgreSQL (`account`)],
    [`CatalogRepository`], [Data Access], [Truy vấn `product_spu/sku`, `category`; hybrid search qua pgvector.], [(không)], [PostgreSQL (`catalog`)],
    [`OrderRepository`], [Data Access], [Truy vấn/ghi `order`, `refund_request`, `dispute_case`, `payment_session`.], [(không)], [PostgreSQL (`order`)],
  )
)

#figure(
  caption: [Ma trận trách nhiệm đối chiếu thành phần Business với các nhóm Yêu cầu chức năng],
  table(
    columns: (1.8fr, 0.7fr, 0.7fr, 0.8fr, 0.9fr, 0.9fr, 0.8fr, 0.7fr),
    align: (left + horizon, center + horizon, center + horizon, center + horizon, center + horizon, center + horizon, center + horizon, center + horizon),
    table.header([Thành phần Business], [Auth], [Listing], [Chat/Offer], [Order/Escrow], [Refund/Dispute], [Search], [Ví]),
    [`AccountService`], [✓], [], [], [], [], [], [✓],
    [`CatalogService`], [], [✓], [], [], [], [✓], [],
    [`ChatOfferService`], [], [], [✓], [✓], [], [], [],
    [`OrderService`], [], [], [], [✓], [✓], [], [✓],
    [`InventoryService`], [], [], [], [✓], [], [], [],
    [`AnalyticService`], [], [], [], [], [], [✓], [],
  )
)

=== Thiết kế và Đặc tả API
Toàn bộ API của ShopNexus được chuẩn hóa theo giao thức RESTful gRPC-Gateway với định dạng JSON (UTF-8), sử dụng cơ chế xác thực không lưu trạng thái *JWT Bearer Token* trong HTTP Header (`Authorization: Bearer <access_token>`). Đường dẫn gốc (Base URL) được thiết lập là `/api`.

Các API được phân loại rõ theo 2 cơ chế chế độ luồng:
- *Loại M (Mutation - Thao tác Ghi):* Tất cả các endpoint thay đổi dữ liệu được định tuyến đi qua cổng Restate Ingress để ghi nhận nhật ký (Journal Log), bảo đảm tính tự phục hồi và thực thi đúng một lần (Idempotency).
- *Loại Q (Query - Thao tác Đọc):* Các endpoint chỉ đọc dữ liệu được định tuyến gọi thẳng trực tiếp vào Microservice chủ quản qua HTTP/2 RPC nhằm giảm thiểu độ trễ.

#figure(
  caption: [Đặc tả các endpoint REST API cốt lõi trong hệ thống ShopNexus],
  table(
    columns: (0.6fr, 2.2fr, 0.5fr, 2.2fr, 1fr),
    align: (center + horizon, left + horizon, center + horizon, left + horizon, center + horizon),
    table.header([PT], [Đường dẫn (Endpoint)], [Loại], [Mô tả nghiệp vụ], [Quyền yêu cầu]),
    [POST], [`/api/auth/register`], [M], [Đăng ký tài khoản User mới với ví điện tử đi kèm.], [Công khai],
    [POST], [`/api/auth/login`], [M], [Đăng nhập, trả về Access Token và Refresh Token.], [Công khai],
    [POST], [`/api/auth/refresh`], [M], [Cấp lại Access Token mới từ Refresh Token.], [Công khai],
    [POST], [`/api/auth/logout`], [M], [Thu hồi Refresh Token hiện tại của người dùng.], [User],
    [GET], [`/api/products`], [Q], [Danh sách/duyệt sản phẩm C2C, phân trang và bộ lọc.], [Công khai],
    [GET], [`/api/products/{id}`], [Q], [Chi tiết một sản phẩm theo định danh SPU/SKU.], [Công khai],
    [GET], [`/api/search`], [Q], [Tìm kiếm Hybrid (vector + từ vựng) kết hợp bộ lọc.], [Công khai],
    [POST], [`/api/products`], [M], [Đăng bán sản phẩm C2C mới (giá cố định / thương lượng).], [User],
    [GET], [`/api/chats/{id}/messages`], [Q], [Lịch sử tin nhắn của một phòng hội thoại.], [User],
    [POST], [`/api/chats/{id}/messages`], [M], [Gửi tin nhắn văn bản, hình ảnh hoặc video mở hộp.], [User],
    [POST], [`/api/chats/{id}/offers`], [M], [Người bán phát hành Offer Card (đơn giá mới + lý do).], [User (seller)],
    [POST], [`/api/offers/{id}/accept`], [M], [Người mua chấp nhận Offer Card, khởi tạo đơn hàng tạm.], [User (buyer)],
    [POST], [`/api/orders/checkout`], [M], [Tạo đơn chính thức từ mục chờ, báo giá ship động.], [User (buyer)],
    [POST], [`/api/orders/{id}/pay`], [M], [Khởi tạo phiên thanh toán tạm giữ Escrow qua ngân hàng.], [User (buyer)],
    [GET], [`/api/orders/{id}`], [Q], [Chi tiết thông tin và tiến trình trạng thái đơn hàng.], [Chủ sở hữu],
    [POST], [`/api/orders/{id}/confirm-received`], [M], [Xác nhận đã nhận hàng (kích hoạt đếm ngược 72 giờ).], [User (buyer)],
    [POST], [`/api/orders/{id}/refunds`], [M], [Gửi khiếu nại hoàn tiền (kèm video bằng chứng mở hộp).], [User (buyer)],
    [POST], [`/api/refunds/{id}/seller-decision`], [M], [Người bán phản hồi chấp nhận hoặc từ chối hoàn tiền.], [User (seller)],
    [POST], [`/api/disputes/{id}/resolve`], [M], [Moderator thẩm định video và ra phán quyết tranh chấp.], [Moderator],
    [POST], [`/api/seller/pending/{id}/confirm`], [M], [Người bán xác nhận mục chờ, tạo mã vận đơn gửi hàng.], [User (seller)],
    [GET], [`/api/wallet`], [Q], [Truy vấn số dư khả dụng / tạm giữ và lịch sử biến động.], [User],
    [POST], [`/api/wallet/withdrawals`], [M], [Yêu cầu rút số dư khả dụng từ ví về tài khoản ngân hàng.], [User],
    [POST], [`/api/admin/moderators`], [M], [Admin tạo mới và cấp phát tài khoản Moderator.], [Admin],
  )
)

*Quy chuẩn Mã lỗi chung:*
- `400 Bad Request`: Dữ liệu đầu vào không hợp lệ hoặc sai định dạng payload JSON.
- `401 Unauthorized`: Token JWT bị thiếu, hết hạn hoặc chữ ký không hợp lệ.
- `403 Forbidden`: Tài khoản không có quyền truy cập hoặc không là chủ sở hữu tài nguyên (`seller_id`/`buyer_id` không khớp).
- `404 Not Found`: Định danh tài nguyên sản phẩm, đơn hàng hoặc phòng chat không tồn tại.
- `409 Conflict`: Xung đột trạng thái (ví dụ: chấp nhận Offer Card đã hết hạn hoặc thanh toán đơn hàng đã bị hủy).
- `422 Unprocessable Entity`: Vi phạm ràng buộc nghiệp vụ (ví dụ: số dư ví không đủ hoặc video mở hộp bị thiếu).
- `500 Internal Server Error` / `502 Bad Gateway`: Lỗi máy chủ nội bộ hoặc sự cố kết nối với cổng thanh toán/vận chuyển bên thứ ba.

== Các bản ghi quyết định kiến trúc (Architectural Decision Records — ADRs)

=== ADR-01: Lựa chọn nền tảng Restate thay cho Saga/Orchestration thủ công
- *Bối cảnh:* Các giao dịch C2C với cơ chế giữ tiền Escrow 3 ngày, hoàn tiền và phân xử là các luồng nghiệp vụ dài hạn, kéo dài từ vài giờ đến nhiều ngày và trải rộng qua 4 module: `order`, `account`, `inventory`, `chat`.
- *Quyết định:* Áp dụng nền tảng thực thi bền vững *Restate* làm trung tâm điều phối cho toàn bộ các quy trình nghiệp vụ dài hạn thay cho việc tự xây dựng máy trạng thái Saga (Saga Choreography/Orchestration) và viết mã bù trừ thủ công.
- *Lý do & Lợi ích:* Restate cung cấp cơ chế ghi nhật ký tự động (journal-based execution) và tự động phục hồi khi máy chủ sập (auto-recovery). Nhà phát triển chỉ cần lập trình luồng logic tuyến tính thông thường; Restate sẽ đảm bảo tính chuẩn xác và thực thi đúng một lần (exact-once semantics), tiết kiệm đến 70% công sức lập trình các mã xử lý ngoại lệ và bù trừ ngược.

=== ADR-02: Áp dụng triệt để Database-per-service trên cơ sở dữ liệu PostgreSQL
- *Bối cảnh:* Cần chọn phương án tổ chức lưu trữ dữ liệu cho 7 microservices nhằm đảm bảo tính độc lập và dễ mở rộng.
- *Quyết định:* Sử dụng hệ quản trị cơ sở dữ liệu quan hệ *PostgreSQL*, trong đó mỗi microservice được cấp phát một cơ sở dữ liệu vật lý hoặc một schema logic độc lập, tuyệt đối không tạo ràng buộc khóa ngoại (Foreign Key) xuyên schema.
- *Lý do & Lợi ích:* PostgreSQL là hệ quản trị mã nguồn mở mạnh mẽ, tuân thủ ACID cao và hỗ trợ cực tốt đa định dạng (JSONB, GIS, Vector). Việc chia schema độc lập giúp cô lập lỗi: nếu module `chat` bị tải cao hoặc quá tải CSDL, các module tài chính trọng yếu như `order` hay `account` vẫn hoạt động hoàn toàn bình thường.

=== ADR-03: Sử dụng NATS JetStream cho Event Bus và Restate Timer cho đếm ngược Escrow
- *Bối cảnh:* Hệ thống cần một cơ chế truyền tải thông điệp bất đồng bộ khi các sự kiện miền xảy ra (như đặt hàng thành công, nhận hàng thành công), đồng thời cần hệ thống hẹn giờ tự động đếm ngược 72 giờ để giải ngân tiền Escrow.
- *Quyết định:* Lựa chọn *NATS JetStream* làm hệ thống hàng đợi thông điệp (Event Bus) cho giao tiếp bất đồng bộ giữa các dịch vụ. Sử dụng tính năng *Restate Awakeable / Sleep Timer* để quản lý bộ đếm ngược 72 giờ thay vì dùng Cron Job hay RabbitMQ Delayed Message.
- *Lý do & Lợi ích:* NATS JetStream siêu nhẹ, độ trễ cực thấp và khả năng duy trì tin nhắn bền vững cao. Trong khi đó, bộ đếm giờ của Restate được lưu trữ bền vững trong nhật ký; dù cụm máy chủ có bị khởi động lại trong suốt 3 ngày chờ đợi, thời gian đếm ngược vẫn tiếp tục tính chuẩn xác từ điểm dừng mà không cần quét bảng CSDL liên tục (polling).

=== ADR-04: Tích hợp tìm kiếm ngữ nghĩa Hybrid bằng pgvector và mô hình bge-m3
- *Bối cảnh:* Người dùng C2C thường đặt tên sản phẩm tự do, thiếu chuẩn mực, khiến tìm kiếm từ khóa SQL truyền thống bị kém hiệu quả. Cần một giải pháp tìm kiếm ngữ nghĩa cao cấp nhưng phải phù hợp với quy mô tài nguyên dự án.
- *Quyết định:* Tích hợp trực tiếp phần mở rộng *pgvector* ngay bên trong CSDL PostgreSQL của module `analytic`, kết hợp với mô hình nhúng *bge-m3* để thực hiện tìm kiếm lai (Hybrid Search: Dense + Sparse).
- *Lý do & Lợi ích:* Mô hình bge-m3 hỗ trợ đa ngôn ngữ cực tốt (đặc biệt là tiếng Việt), sinh ra cả vector ý nghĩa sâu (dense) và từ vựng chìa khóa (sparse) trong một bước. Tích hợp pgvector giúp loại bỏ nhu cầu vận hành các hệ CSDL vector độc lập (Milvus, Weaviate), cho phép thực hiện truy vấn khoảng cách Cosine kết hợp lọc khoảng giá, danh mục ngay trong một câu lệnh SQL hiệu năng cao.

== Thiết kế mô hình dữ liệu ý niệm và tham chiếu chéo

=== Nguyên lý xóa bỏ khóa ngoại vật lý và tham chiếu logic chéo module
Do tuân thủ mẫu thiết kế Database-per-service (ADR-02), các bảng dữ liệu giữa các microservice không có liên kết khóa ngoại (Foreign Key) vật lý trong cơ sở dữ liệu. Thay vào đó, tính liên kết của hệ thống được duy trì thông qua các *Khóa tham chiếu logic (Logical Foreign Keys)* được lưu trữ dưới dạng định danh UUID hoặc kiểu số tự nhiên (BigInt).

Khi một dịch vụ cần hiển thị thông tin chi tiết từ một dịch vụ khác (ví dụ: dịch vụ `order` cần lấy tên sản phẩm từ `catalog` và tên người bán từ `account` để hiển thị hóa đơn), nó sẽ sử dụng khóa định danh tham chiếu logic (`seller_id`, `product_id`) để gọi các API đọc đồng bộ qua giao thức HTTP/2 RPC tới dịch vụ chủ quản, hoặc trích xuất từ bản sao dữ liệu (read model) được đồng bộ qua sự kiện NATS JetStream.

=== Sơ đồ thực thể ý niệm (Conceptual ERD)
Mô hình dữ liệu ý niệm được trình bày bằng *ký hiệu chân quạ (Crow's Foot)*, chỉ hiển thị thực thể và bản số của quan hệ, chưa đi vào kiểu dữ liệu hay chỉ mục vật lý (nội dung này thuộc mục 3.9). Do số lượng thực thể lớn, mô hình được tách thành hai lát cắt theo cụm nghiệp vụ; các thực thể xuất hiện ở cả hai lát cắt là điểm nối logic giữa hai cụm.

#fig(
  [Sơ đồ thực thể ý niệm cụm Người dùng — Bài đăng — Hội thoại (Crow's Foot)],
  spacing: (17mm, 12mm),
  edge-stroke: 1pt + blue-s,
  nent((0, 0), <c-acc>, [ACCOUNT]),
  nent((0, 1.2), <c-prof>, [PROFILE]),
  nent((0, 2.4), <c-wal>, [WALLET]),
  nent((1.6, 0), <c-cat>, [CATEGORY]),
  nent((1.6, 1.2), <c-spu>, [PRODUCT\_SPU]),
  nent((1.6, 2.4), <c-sku>, [PRODUCT\_SKU]),
  nent((1.6, 3.6), <c-stk>, [STOCK]),
  nent((3.2, 0.6), <c-conv>, [CONVERSATION]),
  nent((3.2, 1.8), <c-msg>, [MESSAGE]),
  nent((3.2, 3.0), <c-off>, [OFFER]),
  nent((3.2, 4.2), <c-res>, [RESOURCE]),
  edge(<c-prof>, <c-acc>, "1-1", text(size: 7.5pt)[hồ sơ]),
  edge(<c-wal>, <c-acc>, "1-1", text(size: 7.5pt)[ví]),
  edge(<c-spu>, <c-acc>, "n-1", text(size: 7.5pt)[người bán]),
  edge(<c-spu>, <c-cat>, "n-1", text(size: 7.5pt)[thuộc danh mục]),
  edge(<c-sku>, <c-spu>, "n-1", text(size: 7.5pt)[biến thể]),
  edge(<c-stk>, <c-sku>, "1-1", text(size: 7.5pt)[tồn kho]),
  edge(<c-conv>, <c-spu>, "n-1", text(size: 7.5pt)[ngữ cảnh sản phẩm]),
  edge(<c-conv>, <c-acc>, "n-n", text(size: 7.5pt)[hai bên tham gia], bend: 22deg),
  edge(<c-msg>, <c-conv>, "n-1", text(size: 7.5pt)[thuộc]),
  edge(<c-off>, <c-conv>, "n-1", text(size: 7.5pt)[phát hành trong]),
  edge(<c-off>, <c-sku>, "n-1", text(size: 7.5pt)[đề xuất giá cho]),
  edge(<c-res>, <c-spu>, "n-1?", text(size: 7.5pt)[ảnh sản phẩm]),
  edge(<c-res>, <c-msg>, "n-1?", text(size: 7.5pt)[tệp đính kèm]),
)

#fig(
  [Sơ đồ thực thể ý niệm cụm Đơn hàng — Dòng tiền — Khiếu nại (Crow's Foot)],
  spacing: (17mm, 12mm),
  edge-stroke: 1pt + blue-s,
  nent((0, 0), <d-cart>, [CART\_ITEM]),
  nent((0, 1.3), <d-pay>, [PAYMENT\_SESSION]),
  nent((0, 2.6), <d-tx>, [TRANSACTION]),
  nent((0, 3.9), <d-wtx>, [WALLET\_TRANSACTION]),
  nent((1.7, 0.4), <d-item>, [ITEM]),
  nent((1.7, 1.7), <d-order>, [ORDER]),
  nent((1.7, 3.0), <d-trans>, [TRANSPORT]),
  nent((3.4, 0.9), <d-rev>, [REVIEW]),
  nent((3.4, 2.1), <d-ref>, [REFUND]),
  nent((3.4, 3.3), <d-disp>, [REFUND\_DISPUTE]),
  nent((2.6, 4.5), <d-evi>, [EVIDENCE\ (RESOURCE)]),
  edge(<d-item>, <d-cart>, "1-1?", text(size: 7.5pt)[chốt từ]),
  edge(<d-item>, <d-pay>, "n-1", text(size: 7.5pt)[thanh toán trong]),
  edge(<d-tx>, <d-pay>, "n-1", text(size: 7.5pt)[bút toán của]),
  edge(<d-tx>, <d-tx>, "1-1?", text(size: 7pt)[đảo ứng], bend: 130deg),
  edge(<d-wtx>, <d-tx>, "n-1?", text(size: 7.5pt)[biến động ví]),
  edge(<d-item>, <d-order>, "n-1?", text(size: 7.5pt)[thuộc đơn]),
  edge(<d-order>, <d-trans>, "1-1", text(size: 7.5pt)[vận chuyển]),
  edge(<d-rev>, <d-order>, "n-1", text(size: 7.5pt)[đánh giá]),
  edge(<d-ref>, <d-order>, "n-1", text(size: 7.5pt)[khiếu nại]),
  edge(<d-ref>, <d-trans>, "1-1?", text(size: 7.5pt)[chặng trả hàng]),
  edge(<d-disp>, <d-ref>, "n-1", text(size: 7.5pt)[tranh chấp]),
  edge(<d-evi>, <d-order>, "n-1?", bend: 20deg, text(size: 7.5pt)[bằng chứng nhận hàng]),
  edge(<d-evi>, <d-ref>, "n-1?", text(size: 7.5pt)[bằng chứng khiếu nại]),
)

#figure(
  caption: [Danh mục quan hệ ý niệm cốt lõi và ràng buộc bản số],
  table(
    columns: (1.45fr, 1.45fr, 1.05fr, 0.95fr, 2.35fr),
    align: (left + horizon, left + horizon, left + horizon, center + horizon, left + horizon),
    table.header([Thực thể A], [Thực thể B], [Tên quan hệ], [Bản số], [Ý nghĩa nghiệp vụ và ràng buộc]),
    [PROFILE], [ACCOUNT], [Hồ sơ], [1 : 1], [Mỗi tài khoản có đúng một hồ sơ; hồ sơ chứa thông tin định danh cần bảo vệ theo NFR-024.],
    [WALLET], [ACCOUNT], [Ví], [1 : 1], [Ví lưu song song số dư khả dụng và số dư tạm giữ; không cho phép số dư âm.],
    [PRODUCT\ SKU], [PRODUCT\ SPU], [Biến thể], [N : 1], [Một bài đăng có thể có nhiều biến thể; SKU là đơn vị được đặt mua và giữ chỗ tồn kho.],
    [OFFER], [CONVER-\ SATION], [Phát hành trong], [N : 1], [Mỗi hội thoại có thể có nhiều Offer Card theo thời gian, nhưng tối đa một thẻ ở trạng thái chờ duyệt (BR-016, BR-021).],
    [ITEM], [ORDER], [Thuộc đơn], [N : 0..1], [Mục hàng tồn tại ngay khi thanh toán; `order_id` còn rỗng cho tới khi người bán xác nhận (UC-012).],
    [TRANS-\ ACTION], [PAYMENT\ SESSION], [Bút toán của], [N : 1], [Một phiên thanh toán gồm nhiều chặng chuyển tiền (ví, cổng thanh toán, chặng hoàn).],
    [TRANS-\ ACTION], [TRANS-\ ACTION], [Đảo ứng], [1 : 0..1], [Hoàn tiền không sửa bút toán gốc mà tạo bút toán mới mang dấu âm trỏ về bút toán bị đảo (BR-013).],
    [ORDER], [TRANSPORT], [Vận chuyển], [1 : 1], [Mỗi đơn gắn đúng một vận đơn giao đi; chặng trả hàng là bản ghi vận chuyển riêng của hồ sơ hoàn tiền.],
    [REFUND], [ORDER], [Khiếu nại], [N : 1], [Một đơn có thể phát sinh nhiều yêu cầu hoàn tiền theo thời gian, nhưng tối đa một yêu cầu đang mở.],
    [REFUND\ DISPUTE], [REFUND], [Tranh chấp], [N : 1], [Chỉ tồn tại tối đa một vụ tranh chấp đang mở cho mỗi yêu cầu hoàn tiền (BR-008).],
    [EVIDENCE], [ORDER /\ REFUND], [Bằng chứng], [N : 1], [Tệp bằng chứng là bất biến sau khi tải lên, gắn dấu thời gian và mã băm nội dung (BR-006).],
    [REVIEW], [ORDER], [Đánh giá], [N : 1], [Chỉ được tạo khi đơn ở trạng thái `COMPLETED`; mỗi bên đánh giá đối phương tối đa một lần.],
  )
)

=== Bảng tổng hợp các khóa tham chiếu chéo cốt lõi

#fig(
  [Mô hình tham chiếu logic chéo module (Cross-module Logical References)],
  spacing: (32mm, 16mm),
  ncore((1.5, 1), [order]),
  np((0, 0), [account]),
  np((3, 0), [catalog]),
  np((0, 2), [inventory]),
  np((3, 2), [chat]),
  np((1.5, 2.3), [analytic]),
  np((1.5, -0.3), [common]),
  edge((1.5, 1), (0, 0), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[buyer\_id / seller\_id]),
  edge((1.5, 1), (3, 0), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[sku\_id / spu\_id]),
  edge((1.5, 1), (0, 2), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[serial\_ids]),
  edge((3, 2), (0, 0), "-|>", stroke: (dash: "dashed"), bend: 20deg, text(size: 7pt)[buyer\_id / seller\_id]),
  edge((1.5, 2.3), (3, 0), "-|>", stroke: (dash: "dashed"), bend: -12deg, text(size: 7pt)[interaction → spu]),
  edge((0, 0), (1.5, -0.3), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[avatar\_rs\_id]),
  edge((3, 0), (1.5, -0.3), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[image rs\_id]),
)

#figure(
  caption: [Bảng các khóa tham chiếu logic chéo giữa các Microservices trong ShopNexus],
  table(
    columns: (1.3fr, 1.4fr, 1.3fr, 2.8fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Dịch vụ sử dụng (Consumer)], [Tên trường Khóa logic], [Dịch vụ chủ quản (Owner)], [Ý nghĩa và Cách thức xử lý đồng bộ]),
    [`order` (`db_order`)], [`buyer_id`, `seller_id`], [`account` (`db_account`)], [Lưu định danh người mua và người bán. Dùng để trích xuất tiền ví Escrow khi khởi tạo và giải ngân khi hoàn tất.],
    [`order` (`db_order`)], [`product_id`], [`catalog` (`db_catalog`)], [Lưu định danh sản phẩm được mua. Gọi RPC để lấy tên, ảnh đại diện và đơn giá tại thời điểm chốt đơn.],
    [`order` (`db_order`)], [`offer_id`], [`chat` (`db_chat`)], [Tham chiếu đến Thẻ đề xuất giá (Offer Card) nếu đơn hàng được chốt từ luồng thương lượng trong chat.],
    [`chat` (`db_chat`)], [`sender_id`, `receiver_id`], [`account` (`db_account`)], [Xác định định danh hai bên tham gia phòng trò chuyện thương lượng giá.],
    [`chat` (`db_chat`)], [`product_id`], [`catalog` (`db_catalog`)], [Gắn ngữ cảnh món hàng đang được đàm phán vào phòng chat.],
    [`inventory` (`db_inv`)], [`product_id`], [`catalog` (`db_catalog`)], [Quản lý số lượng tồn kho khả dụng và số lượng đang giữ chỗ cho sản phẩm C2C.],
    [`analytic` (`db_ana`)], [`product_id`], [`catalog` (`db_catalog`)], [Đồng bộ qua NATS JetStream để sinh vector nhúng bge-m3 phục vụ tìm kiếm Hybrid.],
  )
)



== Thiết kế cơ sở dữ liệu vật lý

Ở mức vật lý, mô hình dữ liệu ý niệm được hiện thực thành *chín lược đồ (schema) PostgreSQL độc lập*. Số lượng lược đồ nhiều hơn số vi dịch vụ vì ba nhóm dữ liệu có ranh giới nghiệp vụ rõ rệt được tách lược đồ riêng để thuận tiện cho việc phân quyền và đối soát, dù vẫn do dịch vụ chủ quản tương ứng quản lý:

#figure(
  caption: [Ánh xạ lược đồ cơ sở dữ liệu vật lý sang vi dịch vụ chủ quản],
  table(
    columns: (1fr, 1.15fr, 2.9fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Lược đồ], [Dịch vụ chủ quản], [Nhóm dữ liệu và lý do tách lược đồ]),
    [`account`], [`account`], [Định danh, thiết bị, hồ sơ, liên hệ, thông báo, theo dõi và yêu thích.],
    [`finance`], [`account`], [Ví, bút toán sổ cái, phiên thanh toán, tài khoản ngân hàng, thông tin thuế. Tách riêng để siết quyền truy cập dữ liệu tài chính và phục vụ đối soát độc lập (NFR-009).],
    [`catalog`], [`catalog`], [Bài đăng, danh mục, biến thể và tồn kho khả dụng.],
    [`chat`], [`chat`], [Hội thoại, tin nhắn và nhật ký kiểm duyệt nội dung hội thoại.],
    [`order`], [`order`], [Giỏ hàng, đơn hàng, mục hàng, vận chuyển, hoàn tiền, tranh chấp, Offer Card đã chốt.],
    [`trust`], [`analytic`], [Đánh giá, phản hồi, bình chọn hữu ích, điểm uy tín và báo cáo vi phạm. Tách riêng vì đây là dữ liệu hình thành uy tín, có yêu cầu bất biến cao hơn dữ liệu phân tích thông thường.],
    [`observability`], [`common`], [Nhật ký lời gọi HTTP, lời gọi nhà cung cấp bên thứ ba, sự kiện nghiệp vụ và số đo thời gian chạy. Tách riêng để có thể áp dụng chính sách lưu trữ ngắn hạn khác với dữ liệu nghiệp vụ.],
    [`common`], [`common`], [Tài nguyên đa phương tiện, tham số hệ thống và nhật ký kiểm toán dùng chung.],
    [`inventory`], [`inventory`], [Tồn kho theo serial và lịch sử giữ chỗ tồn kho.],
  )
)

#note[Nguyên tắc *Database-per-service* vẫn được giữ nguyên: một lược đồ chỉ có đúng một dịch vụ được phép ghi, các dịch vụ khác truy cập qua RPC hoặc sự kiện (NFR-028). Việc một dịch vụ quản lý hai lược đồ (ví dụ `account` quản lý cả `finance`) là quyết định *phân vùng theo mức độ nhạy cảm của dữ liệu*, không phải chia sẻ cơ sở dữ liệu giữa các dịch vụ.]

=== Schema `account`

*account*
#figure(kind: table, caption: [Bảng `account.account`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`status`], [`account\_status`], [No], [Mặc định: 'active'],
  [`role`], [`account\_role`], [No], [Mặc định: 'user'],
  [`phone`], [`VARCHAR(16)`], [Yes], [E.164: '+' plus up to 15 digits],
  [`email`], [`VARCHAR(255)`], [Yes], [],
  [`username`], [`VARCHAR(100)`], [Yes], [],
  [`password`], [`VARCHAR(255)`], [Yes], [],
  [`email_verified`], [`BOOLEAN`], [No], [Mặc định: Sai (false)],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`suspended_until`], [`TIMESTAMPTZ`], [Yes], [],
  [`suspension_reason`], [`TEXT`], [Yes], [],
  [`status`], [`= 'suspended'`], [Yes], [],
)
]

*Ràng buộc bảng:*
- `Ràng buộc account_pkey Khóa chính (id)`
- `Ràng buộc account_phone_key Duy nhất (phone)`
- `Ràng buộc account_email_key Duy nhất (email)`
- `Ràng buộc account_username_key Duy nhất (username)`
- `Ràng buộc account_phone_e164 Kiểm tra: (phone ~ '^\+\[1-9\]\[0-9\]{7,14}$')`
- `Ràng buộc account_email_lowercase Kiểm tra: (email = lower(email))`
- `Ràng buộc account_username_lowercase Kiểm tra: (username = lower(username))`
- `Ràng buộc account_suspension_requires_suspended Kiểm tra: ( OR (suspended_until IS NULL AND suspension_reason IS NULL) )`

*oauth_identity*
#figure(kind: table, caption: [Bảng `account.oauth_identity`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`account_id`], [`BIGINT`], [No], [],
  [`provider`], [`VARCHAR(30)`], [No], [Định dạng kebab-case: 'google', 'facebook', 'apple', 'zalo'],
  [`provider_uid`], [`VARCHAR(255)`], [No], [ID định danh cố định của nền tảng, không phải email],
  [`email`], [`VARCHAR(255)`], [Yes], [Được cung cấp bởi nền tảng; Có thể khác với email tài khoản và không có tính quyết định],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc oauth_identity_pkey Khóa chính (id)`
- `Ràng buộc oauth_identity_provider_provider_uid_key Duy nhất (provider, provider_uid)`
- `Ràng buộc oauth_identity_account_id_provider_key Duy nhất (account_id, provider)`
- `Ràng buộc oauth_identity_account_id_fkey Khóa ngoại (account_id) Khóa ngoại trỏ tới account (id) Xóa theo chuỗi (Cascade)`

*device*
#figure(kind: table, caption: [Bảng `account.device`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`account_id`], [`BIGINT`], [No], [],
  [`platform`], [`device\_platform`], [No], [],
  [`push_token`], [`TEXT`], [No], [FCM / APNs registration token],
  [`last_seen_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại | prune stale tokens by this],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc device_pkey Khóa chính (id)`
- `Ràng buộc device_push_token_key Duy nhất (push_token)`
- `Ràng buộc device_account_id_fkey Khóa ngoại (account_id) Khóa ngoại trỏ tới account (id) Xóa theo chuỗi (Cascade)`

*contact*
#figure(kind: table, caption: [Bảng `account.contact`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`account_id`], [`BIGINT`], [No], [],
  [`full_name`], [`VARCHAR(100)`], [No], [],
  [`phone`], [`VARCHAR(16)`], [No], [E.164, same normalization as account.phone],
  [`phone_verified`], [`BOOLEAN`], [No], [Mặc định: Sai (false)],
  [`address_type`], [`contact\_address\_type`], [No], [],
  [`is_default_delivery`], [`BOOLEAN`], [No], [Mặc định: Sai (false)],
  [`is_default_pickup`], [`BOOLEAN`], [No], [Mặc định: Sai (false)],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`country`], [`VARCHAR(2)`], [No], [ISO 3166-1 alpha-2],
  [`province_code`], [`VARCHAR(20)`], [No], [],
  [`province_name`], [`VARCHAR(100)`], [No], [],
  [`district_code`], [`VARCHAR(20)`], [Yes], [],
  [`district_name`], [`VARCHAR(100)`], [Yes], [],
  [`ward_code`], [`VARCHAR(20)`], [No], [],
  [`ward_name`], [`VARCHAR(100)`], [No], [],
  [`postal_code`], [`VARCHAR(20)`], [Yes], [],
  [`provider_codes`], [`JSONB`], [No], [Mặc định: '{}'],
  [`address`], [`VARCHAR(255)`], [No], [street / house number line, below ward level],
  [`address_detail`], [`VARCHAR(255)`], [Yes], [unit/floor/notes; free text, never geocoded],
  [`location`], [`geography(Point, 4326)`], [Yes], [NULL when geocoding failed; must be near the text address],
)
]

*Ràng buộc bảng:*
- `Ràng buộc contact_pkey Khóa chính (id)`
- `Ràng buộc contact_country_format Kiểm tra: (country ~ '^\[A-Z\]{2}$')`
- `Ràng buộc contact_phone_e164 Kiểm tra: (phone ~ '^\+\[1-9\]\[0-9\]{7,14}$')`
- `Ràng buộc contact_district_code_name_together Kiểm tra: ( (district_code IS NULL) = (district_name IS NULL) )`
- `Ràng buộc contact_account_id_fkey Khóa ngoại (account_id) Khóa ngoại trỏ tới account (id) Xóa theo chuỗi (Cascade)`

*profile*
#figure(kind: table, caption: [Bảng `account.profile`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [No], [],
  [`gender`], [`profile\_gender`], [Yes], [],
  [`name`], [`VARCHAR(100)`], [No], [],
  [`description`], [`TEXT`], [Yes], [],
  [`date_of_birth`], [`DATE`], [Yes], [age rules are enforced in the domain],
  [`avatar_resource_id`], [`BIGINT`], [Yes], [not Duy nhất: accounts may share a resource, e.g. a Mặc định: avatar],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`country`], [`VARCHAR(2)`], [No], [ISO 3166-1 alpha-2; picks the currency of finance.wallet],
  [`locale`], [`VARCHAR(10)`], [No], [BCP 47, e.g. 'vi-VN'; notification + UI language],
  [`timezone`], [`VARCHAR(64)`], [No], [IANA name, e.g. 'Asia/Ho\_Chi\_Minh'; renders times, schedules notifications],
)
]

*Ràng buộc bảng:*
- `Ràng buộc profile_pkey Khóa chính (id)`
- `Ràng buộc profile_country_format Kiểm tra: (country ~ '^\[A-Z\]{2}$')`
- `Ràng buộc profile_locale_format Kiểm tra: (locale ~ '^\[a-z\]{2}(-\[A-Z\]{2})?$')`
- `Ràng buộc profile_date_of_birth_sane Kiểm tra: (date_of_birth > DATE '1900-01-01')`
- `Ràng buộc profile_id_fkey Khóa ngoại (id) Khóa ngoại trỏ tới account (id) Xóa theo chuỗi (Cascade)`

*notification*
#figure(kind: table, caption: [Bảng `account.notification`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`account_id`], [`BIGINT`], [No], [],
  [`type`], [`notification\_type`], [No], [Delivery channel (e.g. 'push', 'email', 'sms')],
  [`category`], [`notification\_category`], [No], [what it is about; also the preference key],
  [`title`], [`VARCHAR(200)`], [No], [],
  [`is_read`], [`BOOLEAN`], [No], [Mặc định: Sai (false)],
  [`payload`], [`JSONB`], [No], [structured payload (deep-links, images, etc.)],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`sent_at`], [`TIMESTAMPTZ`], [Yes], [NULL until dispatched on its channel],
  [`scheduled_at`], [`TIMESTAMPTZ`], [Yes], [future dispatch time; NULL means send immediately],
  [`sent_at`], [`IS`], [No], [OR "scheduled\_at" IS],
)
]

*Ràng buộc bảng:*
- `Ràng buộc notification_pkey Khóa chính (id)`
- `Ràng buộc notification_scheduled_or_sent Kiểm tra: ( )`
- `Ràng buộc notification_account_id_fkey Khóa ngoại (account_id) Khóa ngoại trỏ tới account (id) Xóa theo chuỗi (Cascade)`

*notification_preference*
#figure(kind: table, caption: [Bảng `account.notification_preference`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`account_id`], [`BIGINT`], [No], [],
  [`category`], [`notification\_category`], [No], [],
  [`channel`], [`notification\_type`], [No], [],
  [`is_enabled`], [`BOOLEAN`], [No], [],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc notification_preference_pkey Khóa chính (account_id, category, channel)`
- `Ràng buộc notification_preference_account_id_fkey Khóa ngoại (account_id) Khóa ngoại trỏ tới account (id) Xóa theo chuỗi (Cascade)`

*favorite*
#figure(kind: table, caption: [Bảng `account.favorite`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`account_id`], [`BIGINT`], [No], [],
  [`spu_id`], [`BIGINT`], [No], [],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc favorite_pkey Khóa chính (account_id, spu_id)`
- `Ràng buộc favorite_account_id_fkey Khóa ngoại (account_id) Khóa ngoại trỏ tới account (id) Xóa theo chuỗi (Cascade)`

*follow*
#figure(kind: table, caption: [Bảng `account.follow`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`follower_id`], [`BIGINT`], [No], [the account doing the following],
  [`followee_id`], [`BIGINT`], [No], [the account (seller) being followed],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc follow_pkey Khóa chính (follower_id, followee_id)`
- `Ràng buộc follow_no_self_follow Kiểm tra: (follower_id <> followee_id)`
- `Ràng buộc follow_follower_id_fkey Khóa ngoại (follower_id) Khóa ngoại trỏ tới account (id) Xóa theo chuỗi (Cascade)`
- `Ràng buộc follow_followee_id_fkey Khóa ngoại (followee_id) Khóa ngoại trỏ tới account (id) Xóa theo chuỗi (Cascade)`

=== Schema `catalog`

*stock*
#figure(kind: table, caption: [Bảng `catalog.stock`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`sku_id`], [`BIGINT`], [No], [ID of the owning SKU],
  [`stock`], [`BIGINT`], [No], [Total quantity in stock],
  [`taken`], [`BIGINT`], [No], [Mặc định: 0 | Quantity currently reserved or sold],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc stock_pkey Khóa chính (id)`
- `Ràng buộc stock_sku_id_key Duy nhất (sku_id)`
- `Ràng buộc stock_non_negative Kiểm tra: (stock >= 0)`
- `Ràng buộc stock_taken_non_negative Kiểm tra: (taken >= 0)`
- `Ràng buộc stock_taken_within_stock Kiểm tra: (taken <= stock)`
- `Ràng buộc stock_sku_id_fkey Khóa ngoại (sku_id) Khóa ngoại trỏ tới product_sku (id) Xóa theo chuỗi (Cascade)`

=== Schema `chat`

*audit_log*
#figure(kind: table, caption: [Bảng `chat.audit_log`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`version`], [`BIGINT`], [No], [Mặc định: 1 | Incremented on each change to the same record],
  [`table_name`], [`VARCHAR(100)`], [No], [],
  [`record_id`], [`BIGINT`], [No], [],
  [`change_type`], [`VARCHAR(10)`], [No], ['insert', 'update', 'delete'],
  [`code`], [`VARCHAR(100)`], [No], [e.g. Business code 'message.redact', 'conversation.create'],
  [`changed_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`changed_by`], [`BIGINT`], [Yes], [account\_id of the user who made the change (if applicable)],
  [`diff`], [`JSONB`], [No], [JSON diff of the record's fields (for insert only, other diff = snapshot)],
  [`snapshot`], [`JSONB`], [No], [Full record values after the change],
)
]

*Ràng buộc bảng:*
- `Ràng buộc audit_log_pkey Khóa chính (id)`
- `Ràng buộc audit_log_table_name_record_id_version_key Duy nhất (table_name, record_id, version)`

*conversation*
#figure(kind: table, caption: [Bảng `chat.conversation`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`account_a_id`], [`BIGINT`], [No], [Tham chiếu chéo account.account; không dùng khóa ngoại vật lý],
  [`account_b_id`], [`BIGINT`], [No], [Tham chiếu chéo account.account; không dùng khóa ngoại vật lý],
  [`last_message_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc conversation_pkey Khóa chính (id)`
- `Ràng buộc conversation_pair_key Duy nhất (account_a_id, account_b_id)`
- `Ràng buộc conversation_pair_ordered Kiểm tra: (account_a_id < account_b_id)`

*message*
#figure(kind: table, caption: [Bảng `chat.message`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`conversation_id`], [`BIGINT`], [No], [],
  [`sender_id`], [`BIGINT`], [Yes], [the account that sent it; NULL on 'system' rows],
  [`type`], [`message\_type`], [No], [Mặc định: 'user'],
  [`body`], [`TEXT`], [No], [],
  [`status`], [`message\_status`], [No], [Mặc định: 'sent'],
  [`attachments`], [`BIGINT[]`], [No], [Mặc định: '{}'],
  [`metadata`], [`JSONB`], [No], [Mặc định: '{}' | referenced spu / sku / order ids, offer payloads],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`edited_at`], [`TIMESTAMPTZ`], [Yes], [],
  [`deleted_at`], [`TIMESTAMPTZ`], [Yes], [redaction: the sender unsending, or moderation acting on a report],
)
]

*Ràng buộc bảng:*
- `Ràng buộc message_pkey Khóa chính (id, created_at)`
- `Ràng buộc message_sender_matches_type Kiểm tra: ( (type = 'system') = (sender_id IS NULL) )`
- `Ràng buộc message_conversation_id_fkey Khóa ngoại (conversation_id) Khóa ngoại trỏ tới conversation (id) Xóa theo chuỗi (Cascade)`

=== Schema `common`

*audit_log*
#figure(kind: table, caption: [Bảng `common.audit_log`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`version`], [`BIGINT`], [No], [Mặc định: 1 | Incremented on each change to the same record],
  [`table_name`], [`VARCHAR(100)`], [No], [],
  [`record_id`], [`TEXT`], [No], [],
  [`change_type`], [`VARCHAR(10)`], [No], ['insert', 'update', 'delete'],
  [`code`], [`VARCHAR(100)`], [No], [e.g. Business code 'option.enable', 'option.rotate-secret'],
  [`changed_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`changed_by`], [`BIGINT`], [Yes], [account\_id of the user who made the change (if applicable)],
  [`diff`], [`JSONB`], [No], [JSON diff of the record's fields (for insert only, other diff = snapshot)],
  [`snapshot`], [`JSONB`], [No], [Full record values after the change],
)
]

*Ràng buộc bảng:*
- `Ràng buộc audit_log_pkey Khóa chính (id)`
- `Ràng buộc audit_log_table_name_record_id_version_key Duy nhất (table_name, record_id, version)`

*resource*
#figure(kind: table, caption: [Bảng `common.resource`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`uploaded_by_id`], [`BIGINT`], [Yes], [Account that uploaded the file; NULL for system-generated resources],
  [`provider`], [`TEXT`], [No], [Storage backend identifier, Định dạng kebab-case (e.g. 's3', 'minio', 'local')],
  [`object_key`], [`VARCHAR(2048)`], [No], [Provider-specific path or key (up to 2048 chars for S3 compatibility)],
  [`mime`], [`VARCHAR(100)`], [No], [MIME type (e.g. 'image/jpeg', 'application/pdf')],
  [`size`], [`BIGINT`], [No], [File size in bytes],
  [`metadata`], [`JSONB`], [No], [Mặc định: '{}' | Provider-specific metadata (dimensions, duration, CDN URL, etc.)],
  [`checksum`], [`TEXT`], [Yes], [Optional content hash],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`deleted_at`], [`TIMESTAMPTZ`], [Yes], [],
)
]

*Ràng buộc bảng:*
- `Ràng buộc resource_pkey Khóa chính (id)`
- `Ràng buộc resource_provider_object_key_key Duy nhất (provider, object_key)`
- `Ràng buộc resource_provider_format Kiểm tra: (provider ~ '^\[a-z0-9\]+(-\[a-z0-9\]+)*$')`
- `Ràng buộc resource_size_non_negative Kiểm tra: (size >= 0)`

*option*
#figure(kind: table, caption: [Bảng `common.option`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`VARCHAR(100)`], [No], [Stable Định dạng kebab-case identifier (e.g. 'stripe-main', 'vnpay-qr', 'ghn-express')],
  [`owner_id`], [`BIGINT`], [Yes], [Account that created this option; NULL for system-provided options],
  [`is_enabled`], [`BOOLEAN`], [No], [],
  [`name`], [`TEXT`], [No], [],
  [`description`], [`TEXT`], [No], [],
  [`priority`], [`INTEGER`], [No], [],
  [`logo_resource_id`], [`BIGINT`], [Yes], [],
  [`data`], [`JSONB`], [No], [Mặc định: '{}'],
  [`vault_secret_path`], [`TEXT`], [Yes], [],
  [`type`], [`TEXT`], [No], [High-level grouping key, Định dạng kebab-case (e.g. 'payment', 'transport', 'notification')],
  [`provider`], [`TEXT`], [No], [Sub-grouping key, Định dạng kebab-case (e.g. 'stripe', 'vnpay', 'ghn')],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc option_pkey Khóa chính (id)`
- `Ràng buộc option_id_format Kiểm tra: (id ~ '^\[a-z0-9\]+(-\[a-z0-9\]+)*$')`
- `Ràng buộc option_type_format Kiểm tra: (type ~ '^\[a-z0-9\]+(-\[a-z0-9\]+)*$')`
- `Ràng buộc option_provider_format Kiểm tra: (provider ~ '^\[a-z0-9\]+(-\[a-z0-9\]+)*$')`
- `Ràng buộc option_logo_resource_id_fkey Khóa ngoại (logo_resource_id) Khóa ngoại trỏ tới resource (id) ON DELETE SET NULL`

=== Schema `finance`

*audit_log*
#figure(kind: table, caption: [Bảng `finance.audit_log`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`version`], [`BIGINT`], [No], [Mặc định: 1 | Incremented on each change to the same record],
  [`table_name`], [`VARCHAR(100)`], [No], [],
  [`record_id`], [`BIGINT`], [No], [],
  [`change_type`], [`VARCHAR(10)`], [No], ['insert', 'update', 'delete'],
  [`code`], [`VARCHAR(100)`], [No], [e.g. Business code 'bank\_account.remove', 'tax\_info.verify'],
  [`changed_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`changed_by`], [`BIGINT`], [Yes], [account\_id of the user who made the change (if applicable)],
  [`diff`], [`JSONB`], [No], [JSON diff of the record's fields (for insert only, other diff = snapshot)],
  [`snapshot`], [`JSONB`], [No], [Full record values after the change],
)
]

*Ràng buộc bảng:*
- `Ràng buộc audit_log_pkey Khóa chính (id)`
- `Ràng buộc audit_log_table_name_record_id_version_key Duy nhất (table_name, record_id, version)`

*payment_session*
#figure(kind: table, caption: [Bảng `finance.payment_session`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [GENERATED BY Mặc định: AS IDENTITY | BY DEFAULT: the app pre-allocates it with],
  [`kind`], [`session\_kind`], [No], [],
  [`status`], [`session\_status`], [No], [],
  [`from_id`], [`BIGINT`], [Yes], [Account initiating (buyer, seller, NULL = system)],
  [`to_id`], [`BIGINT`], [Yes], [Counterparty (buyer, seller, NULL = system)],
  [`note`], [`TEXT`], [No], [],
  [`currency`], [`VARCHAR(3)`], [No], [Buyer-facing currency; every child transaction settles via this currency],
  [`total_amount`], [`BIGINT`], [No], [Expected total in buyer-facing currency],
  [`fx_snapshot`], [`JSONB`], [Yes], [],
  [`data`], [`JSONB`], [No], [],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`paid_at`], [`TIMESTAMPTZ`], [Yes], [Set when session reaches success],
  [`expired_at`], [`TIMESTAMPTZ`], [No], [pending sessions auto-void after this timestamp],
)
]

*Ràng buộc bảng:*
- `Ràng buộc payment_session_pkey Khóa chính (id)`
- `Ràng buộc payment_session_currency_format Kiểm tra: (currency ~ '^\[A-Z\]{3}$')`
- `Ràng buộc payment_session_total_amount_positive Kiểm tra: (total_amount > 0)`

*transaction*
#figure(kind: table, caption: [Bảng `finance.transaction`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [GENERATED BY Mặc định: AS IDENTITY | pre-allocated like "payment\_session"."id"],
  [`session_id`], [`BIGINT`], [No], [],
  [`status`], [`transaction\_status`], [No], [],
  [`note`], [`TEXT`], [No], [],
  [`error`], [`TEXT`], [Yes], [],
  [`payment_option`], [`VARCHAR(100)`], [No], [Khóa ngoại trỏ tới common.option (payment],
)
]

*wallet*
#figure(kind: table, caption: [Bảng `finance.wallet`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`account_id`], [`BIGINT`], [No], [],
  [`currency`], [`VARCHAR(3)`], [No], [],
  [`available_balance`], [`BIGINT`], [No], [Mặc định: 0 | spendable / withdrawable],
  [`held_balance`], [`BIGINT`], [No], [Mặc định: 0 | locked in escrow],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc wallet_pkey Khóa chính (account_id, currency)`
- `Ràng buộc wallet_currency_format Kiểm tra: (currency ~ '^\[A-Z\]{3}$')`
- `Ràng buộc wallet_available_balance_non_negative Kiểm tra: (available_balance >= 0)`
- `Ràng buộc wallet_held_balance_non_negative Kiểm tra: (held_balance >= 0)`

*wallet_transaction*
#figure(kind: table, caption: [Bảng `finance.wallet_transaction`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`account_id`], [`BIGINT`], [No], [Tham chiếu chéo account.account; không dùng khóa ngoại vật lý],
  [`currency`], [`VARCHAR(3)`], [No], [],
  [`seq`], [`BIGINT`], [No], [per-wallet position in the ledger, starting at 1],
  [`kind`], [`wallet\_txn\_kind`], [No], [],
  [`available_delta`], [`BIGINT`], [No], [Mặc định: 0 | signed change to available balance],
  [`held_delta`], [`BIGINT`], [No], [Mặc định: 0 | signed change to held balance],
  [`available_after`], [`BIGINT`], [No], [available balance after this movement],
  [`held_after`], [`BIGINT`], [No], [held balance after this movement],
  [`group_id`], [`BIGINT`], [Yes], [],
  [`ref_type`], [`TEXT`], [Yes], [cross-module ref kind ('order', 'payment-session'],
)
]

*bank_account*
#figure(kind: table, caption: [Bảng `finance.bank_account`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`account_id`], [`BIGINT`], [No], [],
  [`bank_code`], [`VARCHAR(20)`], [No], [bank identifier (e.g. 'vcb', 'tcb')],
  [`account_number`], [`VARCHAR(50)`], [No], [],
  [`account_holder`], [`VARCHAR(100)`], [No], [],
  [`is_default`], [`BOOLEAN`], [No], [Mặc định: Sai (false)],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`deleted_at`], [`TIMESTAMPTZ`], [Yes], [],
)
]

*Ràng buộc bảng:*
- `Ràng buộc bank_account_pkey Khóa chính (id)`

*tax_info*
#figure(kind: table, caption: [Bảng `finance.tax_info`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`account_id`], [`BIGINT`], [No], [Tham chiếu chéo account.account],
  [`tax_code`], [`VARCHAR(14)`], [No], [Vietnamese MST: 10 digits, or 10-3 for a branch],
  [`tax_code_type`], [`VARCHAR(20)`], [No], ['individual' | 'business' | 'household'],
  [`legal_name`], [`TEXT`], [No], [],
  [`verification_status`], [`verification\_status`], [No], [Mặc định: 'pending'],
  [`verified_at`], [`TIMESTAMPTZ`], [Yes], [],
  [`verification_source`], [`TEXT`], [Yes], [],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc tax_info_pkey Khóa chính (account_id)`
- `Ràng buộc tax_info_tax_code_format Kiểm tra: (tax_code ~ '^\d{10}(-\d{3})?$')`

=== Schema `observability`

*http_requests*
#figure(kind: table, caption: [Bảng `observability.http_requests`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`ts`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`instance`], [`TEXT`], [No], [pod / host that served the request],
  [`method`], [`TEXT`], [No], [],
  [`route`], [`TEXT`], [No], [],
  [`status`], [`INT`], [No], [],
  [`duration_ms`], [`DOUBLE`], [No], [PRECISION],
)
]

*provider_calls*
#figure(kind: table, caption: [Bảng `observability.provider_calls`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`ts`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`instance`], [`TEXT`], [No], [pod / host that made the call],
  [`provider`], [`TEXT`], [No], ["litellm", "vnpay", …],
  [`method`], [`TEXT`], [No], [],
  [`path`], [`TEXT`], [No], [],
  [`status`], [`INT`], [No], [],
  [`duration_ms`], [`DOUBLE`], [No], [PRECISION],
  [`failed`], [`BOOLEAN`], [No], [transport error or 5xx; a 4xx is a valid answer],
  [`error`], [`TEXT`], [No], [Mặc định: ''],
)
]

*business_events*
#figure(kind: table, caption: [Bảng `observability.business_events`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`ts`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`instance`], [`TEXT`], [No], [],
  [`topic`], [`TEXT`], [No], [],
  [`payload`], [`JSONB`], [No], [],
)
]

*runtime_metrics*
#figure(kind: table, caption: [Bảng `observability.runtime_metrics`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`ts`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`instance`], [`TEXT`], [No], [],
  [`goroutines`], [`INT`], [No], [],
  [`heap_alloc_bytes`], [`BIGINT`], [No], [],
  [`heap_inuse_bytes`], [`BIGINT`], [No], [],
  [`gc_pause_ms`], [`DOUBLE`], [No], [PRECISION],
  [`num_gc`], [`BIGINT`], [No], [],
)
]

=== Schema `order`

*cart_item*
#figure(kind: table, caption: [Bảng `order.cart_item`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`account_id`], [`BIGINT`], [No], [],
  [`sku_id`], [`BIGINT`], [No], [],
  [`quantity`], [`BIGINT`], [No], [],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại | sorts the cart, and ages out stale ones],
)
]

*Ràng buộc bảng:*
- `Ràng buộc cart_item_pkey Khóa chính (id)`
- `Ràng buộc cart_item_account_id_sku_id_key Duy nhất (account_id, sku_id)`
- `Ràng buộc cart_item_quantity_positive Kiểm tra: (quantity > 0)`

*transport*
#figure(kind: table, caption: [Bảng `order.transport`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`option`], [`VARCHAR(100)`], [No], [Khóa ngoại trỏ tới common.option (transport],
)
]

*draft_order*
#figure(kind: table, caption: [Bảng `order.draft_order`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`buyer_id`], [`BIGINT`], [No], [],
  [`spu_id`], [`BIGINT`], [No], [Aggregate root id (not sku\_id)],
  [`spu_snapshot`], [`JSONB`], [No], [],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`cancelled_at`], [`TIMESTAMPTZ`], [Yes], [Set when the draft order is cancelled],
  [`valid_until`], [`TIMESTAMPTZ`], [No], [Expiration timestamp for the draft order],
)
]

*Ràng buộc bảng:*
- `Ràng buộc draft_order_pkey Khóa chính (id)`

*order*
#figure(kind: table, caption: [Bảng `order.order`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`draft_id`], [`BIGINT`], [No], [The draft order that was confirmed to create this order],
  [`buyer_id`], [`BIGINT`], [No], [],
  [`transport_id`], [`BIGINT`], [No], [],
  [`address`], [`JSONB`], [No], [],
  [`pickup_address`], [`JSONB`], [No], [Seller's collection point, snapshotted the same way],
  [`confirm_session_id`], [`BIGINT`], [Yes], [Seller confirmation shipping fee session (if seller pays the shipping)],
  [`note`], [`TEXT`], [Yes], [Seller note],
  [`seller_id`], [`BIGINT`], [No], [Denormalized from order items for easier querying;],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`completed_at`], [`TIMESTAMPTZ`], [Yes], [],
  [`cancelled_at`], [`TIMESTAMPTZ`], [Yes], [],
)
]

*Ràng buộc bảng:*
- `Ràng buộc order_pkey Khóa chính (id)`
- `Ràng buộc order_transport_id_key Duy nhất (transport_id)`
- `Ràng buộc order_draft_id_key Duy nhất (draft_id)`
- `Ràng buộc order_transport_id_fkey Khóa ngoại (transport_id) Khóa ngoại trỏ tới transport (id) ON DELETE NO ACTION`
- `Ràng buộc order_draft_id_fkey Khóa ngoại (draft_id) Khóa ngoại trỏ tới draft_order (id) ON DELETE NO ACTION`

*item*
#figure(kind: table, caption: [Bảng `order.item`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`draft_id`], [`BIGINT`], [No], [The purchase session this was Kiểm tra:ed out in],
  [`order_id`], [`BIGINT`], [Yes], [NULL until the seller confirms],
  [`buyer_id`], [`BIGINT`], [No], [],
  [`seller_id`], [`BIGINT`], [No], [Denormalized from sku->spu->seller],
  [`sku_id`], [`BIGINT`], [No], [],
  [`address`], [`JSONB`], [No], [Delivery contact snapshot, same shape as "order"."address"],
  [`note`], [`TEXT`], [Yes], [Buyer note],
  [`currency`], [`VARCHAR(3)`], [No], [Currency the SPU was originally priced in; combined with session.fx\_snapshot to replay conversion],
  [`quantity`], [`BIGINT`], [No], [],
  [`transport_option`], [`VARCHAR(100)`], [No], [Khóa ngoại trỏ tới common.option (transport],
)
]

*refund*
#figure(kind: table, caption: [Bảng `order.refund`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`buyer_id`], [`BIGINT`], [No], [buyer],
  [`order_id`], [`BIGINT`], [No], [],
  [`reason`], [`TEXT`], [No], [],
  [`attachments`], [`BIGINT[]`], [No], [Mặc định: '{}'],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`status`], [`refund\_status`], [No], [Mặc định: 'shipping'],
  [`return_transport_id`], [`BIGINT`], [No], [],
  [`received_by_seller_at`], [`TIMESTAMPTZ`], [Yes], [set when return transport hits success],
  [`review_deadline_at`], [`TIMESTAMPTZ`], [Yes], [date\_received + 3D, auto-accept timer],
  [`seller_decided_at`], [`TIMESTAMPTZ`], [Yes], [],
  [`return_to_buyer_transport_id`], [`BIGINT`], [Yes], [],
  [`rejection_reason`], [`TEXT`], [Yes], [],
  [`refund_tx_id`], [`BIGINT`], [Yes], [set only when accepted (the negative-amount reversal leg)],
)
]

*Ràng buộc bảng:*
- `Ràng buộc refund_pkey Khóa chính (id)`
- `Ràng buộc refund_return_transport_id_key Duy nhất (return_transport_id)`
- `Ràng buộc refund_return_to_buyer_transport_id_key Duy nhất (return_to_buyer_transport_id)`
- `Ràng buộc refund_order_id_fkey Khóa ngoại (order_id) Khóa ngoại trỏ tới order (id) ON DELETE NO ACTION`
- `Ràng buộc refund_return_transport_id_fkey Khóa ngoại (return_transport_id) Khóa ngoại trỏ tới transport (id) ON DELETE NO ACTION`
- `Ràng buộc refund_return_to_buyer_transport_id_fkey Khóa ngoại (return_to_buyer_transport_id) Khóa ngoại trỏ tới transport (id) ON DELETE NO ACTION`

*refund_dispute*
#figure(kind: table, caption: [Bảng `order.refund_dispute`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`refund_id`], [`BIGINT`], [No], [],
  [`account_id`], [`BIGINT`], [No], [seller (the disputer)],
  [`reason`], [`TEXT`], [No], [],
  [`attachments`], [`BIGINT[]`], [No], [Mặc định: '{}'],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`status`], [`dispute\_status`], [No], [Mặc định: 'open'],
  [`resolved_by_id`], [`BIGINT`], [Yes], [admin],
  [`resolved_at`], [`TIMESTAMPTZ`], [Yes], [],
  [`resolution_note`], [`TEXT`], [Yes], [],
)
]

*Ràng buộc bảng:*
- `Ràng buộc refund_dispute_pkey Khóa chính (id)`
- `Ràng buộc refund_dispute_refund_id_fkey Khóa ngoại (refund_id) Khóa ngoại trỏ tới refund (id) ON DELETE NO ACTION`

*offer*
#figure(kind: table, caption: [Bảng `order.offer`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`sku_id`], [`BIGINT`], [No], [Tham chiếu chéo catalog.product\_sku; không dùng khóa ngoại vật lý],
  [`author_id`], [`BIGINT`], [No], [account that created the offer (buyer or seller)],
  [`buyer_id`], [`BIGINT`], [No], [],
  [`seller_id`], [`BIGINT`], [No], [denormalized from sku -> spu -> owner],
  [`status`], [`offer\_status`], [No], [Mặc định: 'active'],
  [`quantity`], [`BIGINT`], [No], [],
  [`total`], [`BIGINT`], [No], [current proposed price (the agreed terms once accepted)],
  [`reason`], [`TEXT`], [No], [Mặc định: '' | offer-card note (e.g. discount reason)],
  [`payment_session_id`], [`BIGINT`], [Yes], [set on accept (auto-created Kiểm tra:out)],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`expires_at`], [`TIMESTAMPTZ`], [No], [],
)
]

*Ràng buộc bảng:*
- `Ràng buộc offer_pkey Khóa chính (id)`
- `Ràng buộc offer_total_positive Kiểm tra: (total > 0)`
- `Ràng buộc offer_quantity_positive Kiểm tra: (quantity > 0)`

=== Schema `trust`

*audit_log*
#figure(kind: table, caption: [Bảng `trust.audit_log`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`version`], [`BIGINT`], [No], [Mặc định: 1 | Incremented on each change to the same record],
  [`table_name`], [`VARCHAR(100)`], [No], [],
  [`record_id`], [`BIGINT`], [No], [],
  [`change_type`], [`VARCHAR(10)`], [No], ['insert', 'update', 'delete'],
  [`code`], [`VARCHAR(100)`], [No], [e.g. Business code 'review.delete', 'report.resolve'],
  [`changed_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`changed_by`], [`BIGINT`], [Yes], [account\_id of the user who made the change (if applicable)],
  [`diff`], [`JSONB`], [No], [JSON diff of the record's fields (for insert only, other diff = snapshot)],
  [`snapshot`], [`JSONB`], [No], [Full record values after the change],
)
]

*Ràng buộc bảng:*
- `Ràng buộc audit_log_pkey Khóa chính (id)`
- `Ràng buộc audit_log_table_name_record_id_version_key Duy nhất (table_name, record_id, version)`

*feedback*
#figure(kind: table, caption: [Bảng `trust.feedback`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`order_id`], [`BIGINT`], [No], [Tham chiếu chéo order.order; không dùng khóa ngoại vật lý],
  [`rater_id`], [`BIGINT`], [No], [Tài khoản thực hiện đánh giá],
  [`ratee_id`], [`BIGINT`], [No], [Tài khoản nhận đánh giá],
  [`direction`], [`feedback\_direction`], [No], [],
  [`rating`], [`SMALLINT`], [No], [],
  [`comment`], [`TEXT`], [No], [Mặc định: ''],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
  [`published_at`], [`TIMESTAMPTZ`], [Yes], [NULL = đánh giá ẩn; chỉ đánh giá đã công bố mới được hiển thị và tính toán],
)
]

*Ràng buộc bảng:*
- `Ràng buộc feedback_pkey Khóa chính (id)`
- `Ràng buộc feedback_order_direction_key Duy nhất (order_id, direction)`
- `Ràng buộc feedback_rating_range_chk Kiểm tra: (rating BETWEEN 1 AND 5)`

*review*
#figure(kind: table, caption: [Bảng `trust.review`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`spu_id`], [`BIGINT`], [No], [Tham chiếu chéo catalog.product\_spu; không dùng khóa ngoại vật lý],
  [`order_id`], [`BIGINT`], [No], [Tham chiếu chéo order.order; không dùng khóa ngoại vật lý],
  [`author_id`], [`BIGINT`], [No], [Tham chiếu chéo account.account; không dùng khóa ngoại vật lý],
  [`rating`], [`SMALLINT`], [No], [],
  [`body`], [`TEXT`], [No], [Mặc định: ''],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc review_pkey Khóa chính (id)`
- `Ràng buộc review_spu_author_order_key Duy nhất (spu_id, author_id, order_id)`
- `Ràng buộc review_rating_range_chk Kiểm tra: (rating BETWEEN 1 AND 5)`

*review_reply*
#figure(kind: table, caption: [Bảng `trust.review_reply`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`review_id`], [`BIGINT`], [No], [],
  [`author_id`], [`BIGINT`], [No], [Tham chiếu chéo account.account; không dùng khóa ngoại vật lý],
  [`body`], [`TEXT`], [No], [],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc review_reply_pkey Khóa chính (id)`
- `Ràng buộc review_reply_review_id_fkey Khóa ngoại (review_id) Khóa ngoại trỏ tới review (id) Xóa theo chuỗi (Cascade)`

*review_vote*
#figure(kind: table, caption: [Bảng `trust.review_vote`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`review_id`], [`BIGINT`], [No], [],
  [`account_id`], [`BIGINT`], [No], [Tham chiếu chéo account.account; không dùng khóa ngoại vật lý],
  [`vote`], [`SMALLINT`], [No], [-1 = downvote, 0 = neutral, 1 = upvote],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc review_vote_pkey Khóa chính (review_id, account_id)`
- `Ràng buộc review_vote_value Kiểm tra: (vote IN (-1, 0, 1))`
- `Ràng buộc review_vote_review_id_fkey Khóa ngoại (review_id) Khóa ngoại trỏ tới review (id) Xóa theo chuỗi (Cascade)`

*reputation*
#figure(kind: table, caption: [Bảng `trust.reputation`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`account_id`], [`BIGINT`], [No], [],
  [`role`], [`reputation\_role`], [No], [],
  [`rating_sum`], [`BIGINT`], [No], [Mặc định: 0],
  [`rating_count`], [`BIGINT`], [No], [Mặc định: 0],
  [`completed_orders`], [`BIGINT`], [No], [Mặc định: 0],
  [`cancelled_orders`], [`BIGINT`], [No], [Mặc định: 0],
  [`updated_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc reputation_pkey Khóa chính (account_id, role)`

*report*
#figure(kind: table, caption: [Bảng `trust.report`])[
#table(
  columns: (1fr, 1.2fr, 0.5fr, 2fr),
  align: (left, left, center, left),
  table.header([*Cột*], [*Kiểu*], [*Null*], [*Ràng buộc / Ghi chú*]),
  [`id`], [`BIGINT`], [Yes], [Tự động tăng (Identity)],
  [`reporter_id`], [`BIGINT`], [No], [],
  [`ref_type`], [`report\_ref\_type`], [No], [],
  [`ref_id`], [`BIGINT`], [No], [polymorphic target, kinded by "ref\_type"],
  [`reason`], [`report\_reason`], [No], [],
  [`detail`], [`TEXT`], [No], [Mặc định: ''],
  [`status`], [`report\_status`], [No], [Mặc định: 'open'],
  [`action_taken`], [`report\_action`], [Yes], [NULL until resolved],
  [`resolved_by_id`], [`BIGINT`], [Yes], [admin account],
  [`resolved_at`], [`TIMESTAMPTZ`], [Yes], [],
  [`resolution_note`], [`TEXT`], [Yes], [],
  [`created_at`], [`TIMESTAMPTZ`], [No], [Mặc định: Thời gian hiện tại],
)
]

*Ràng buộc bảng:*
- `Ràng buộc report_pkey Khóa chính (id)`

