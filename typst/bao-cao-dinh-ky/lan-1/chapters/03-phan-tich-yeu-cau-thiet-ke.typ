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

#figure(
  caption: [Sơ đồ Ngữ cảnh Hệ thống ShopNexus C2C (System Context Diagram)],
  block(
    width: 100%,
    align(center, layout(sz => {
      let body = {
        set text(size: 8.5pt)
        diagram(
          spacing: (16mm, 14mm),
          node-stroke: 1pt + black,
          edge-stroke: 0.8pt + black,
          
          // Tác nhân bên trong (hàng trên y = 0)
          node((0, 0), align(center)[*Người dùng (User)*\ (Mua / Bán C2C)], shape: pill, fill: rgb("#e1f5fe"), stroke: 1pt + rgb("#0288d1"), inset: 6pt),
          node((1, 0), align(center)[*Điều phối viên*\ (Moderator - Phân xử)], shape: pill, fill: rgb("#fff9c4"), stroke: 1pt + rgb("#fbc02d"), inset: 6pt),
          node((2, 0), align(center)[*Quản trị viên*\ (Admin - Đối soát)], shape: pill, fill: rgb("#ffe0b2"), stroke: 1pt + rgb("#f57c00"), inset: 6pt),

          // Hệ thống trung tâm (hàng giữa y = 1)
          node((1, 1), align(center)[*HỆ THỐNG *\ \ (Sàn TMĐT C2C, Ví Escrow,\ Chat Realtime, Restate Engine)], width: 48mm, fill: rgb("#e8f5e9"), stroke: 1.5pt + rgb("#2e7d32"), corner-radius: 6pt, inset: 8pt),

          // Hệ thống bên ngoài (hàng dưới y = 2)
          node((0, 2), align(center)[*Cổng thanh toán*\ (SePay)], fill: rgb("#f3e5f5"), stroke: 1pt + rgb("#7b1fa2"), corner-radius: 4pt, inset: 6pt),
          node((1, 2), align(center)[*Đối tác vận chuyển*\ (GHN / GHTK)], fill: rgb("#f3e5f5"), stroke: 1pt + rgb("#7b1fa2"), corner-radius: 4pt, inset: 6pt),
          node((2, 2), align(center)[*Hệ thống sự kiện*\ (NATS / SSE)], fill: rgb("#f3e5f5"), stroke: 1pt + rgb("#7b1fa2"), corner-radius: 4pt, inset: 6pt),

          // Các đường kết nối (edges)
          edge((0, 0), (1, 1), "<|-|>", label: text(size: 8pt)[Đăng ký, Chat, Escrow], label-pos: 0.5, label-side: right),
          edge((1, 0), (1, 1), "<|-|>", label: text(size: 8pt)[Thẩm định, Phân xử], label-pos: 0.4, label-side: left),
          edge((2, 0), (1, 1), "<|-|>", label: text(size: 8pt)[Cấu hình, Đối soát], label-pos: 0.35, label-side: left),

          edge((1, 1), (0, 2), "<|-|>", label: text(size: 8pt)[Thanh toán, Webhook], label-pos: 0.65, label-side: right),
          edge((1, 1), (1, 2), "<|-|>", label: text(size: 8pt)[Phí ship, Hành trình], label-pos: 0.6, label-side: left),
          edge((1, 1), (2, 2), "<|-|>", label: text(size: 8pt)[Sự kiện, SSE Realtime], label-pos: 0.55, label-side: left),
        )
      }
      let m = measure(body)
      let s = if m.width > 0pt and m.width > sz.width { sz.width / m.width } else { 1.0 }
      box(scale(x: s * 100%, y: s * 100%, reflow: true, body))
    }))
  )
)

== Đặc tả ca sử dụng (Use Cases) và quy tắc nghiệp vụ (Business Rules)

=== Danh mục Ca sử dụng (Use Case Portfolio)
Toàn bộ nghiệp vụ sàn TMĐT C2C được phân rã và chuẩn hóa thành 13 ca sử dụng cốt lõi, được chia theo các miền phụ trách nghiệp vụ và thể hiện trực quan qua Sơ đồ Ca sử dụng:

#figure(
  caption: [Sơ đồ Use Case tổng quan hệ thống ShopNexus C2C],
  block(
    width: 100%,
    align(center, layout(sz => {
      let body = {
        set text(size: 8.5pt)
        diagram(
          spacing: (28mm, 12mm),
          node(enclose: (<u1>, <u1b>, <u2>, <u3>, <u4>, <u5>, <u6>, <u7>, <u8>, <u9>), inset: 15pt,
            stroke: (paint: blue, dash: "dashed", thickness: 1pt), fill: none, corner-radius: 8pt),
          node((2, -0.9), text(size: 9pt, fill: blue, weight: 700)[Ranh giới hệ thống ShopNexus C2C],
            fill: white, stroke: none),
          np((2, -0.15), [UC-001 · Đăng ký tài khoản], name: <u1>),
          np((2, 0.65), [UC-002 · Đăng nhập], name: <u1b>),
          np((2, 1.5), [UC-010 · Cấp phát tài khoản Moderator], name: <u9>),
          np((2, 2.3), [UC-003 · Đăng bán sản phẩm C2C], name: <u2>),
          np((2, 3.3), [UC-004 · Nhắn tin trực tuyến (Chat)], name: <u3>),
          np((2, 4.3), [UC-005 · Đặt hàng & Thanh toán Escrow], name: <u4>),
          np((2, 5.3), [UC-006 · Yêu cầu Trả hàng / Hoàn tiền], name: <u5>),
          np((2, 6.3), [UC-007 · Khiếu nại và Tranh chấp], name: <u6>),
          np((2, 7.3), [UC-008 · Phân xử tranh chấp], name: <u7>),
          np((2, 8.3), [UC-009 · Đánh giá & Phản hồi], name: <u8>),

          nact((0, 2.5), [Người dùng\ (User)]),
          nact((4, 5.5), [Điều phối viên\ (Moderator)]),
          nact((4, 1.5), [Quản trị viên\ (Admin)]),

          // User edges — chỉ User mới có thể Đăng ký; cả 3 vai trò đều Đăng nhập
          edge((0, 2.5), <u1>, stroke: 0.7pt + blue-s),
          edge((0, 2.5), <u1b>, stroke: 0.7pt + blue-s),
          edge((0, 2.5), <u2>, stroke: 0.7pt + blue-s),
          edge((0, 2.5), <u3>, stroke: 0.7pt + blue-s),
          edge((0, 2.5), <u4>, stroke: 0.7pt + blue-s),
          edge((0, 2.5), <u5>, stroke: 0.7pt + blue-s),
          edge((0, 2.5), <u6>, stroke: 0.7pt + blue-s),
          edge((0, 2.5), <u8>, stroke: 0.7pt + blue-s),

          // Moderator edges — chỉ Đăng nhập, không Đăng ký
          edge((4, 5.5), <u1b>, stroke: 0.7pt + teal),
          edge((4, 5.5), <u7>, stroke: 0.7pt + teal),

          // Admin edges — chỉ Đăng nhập, không Đăng ký
          edge((4, 1.5), <u1b>, stroke: 0.7pt + red),
          edge((4, 1.5), <u9>, stroke: 0.7pt + red),
        )
      }
      let m = measure(body)
      let s = if m.width > 0pt and m.width > sz.width { sz.width / m.width } else { 1.0 }
      box(scale(x: s * 100%, y: s * 100%, reflow: true, body))
    }))
  )
)

Các ca sử dụng cốt lõi chi tiết theo từng miền phụ trách nghiệp vụ bao gồm:
- *UC-001: Đăng ký & Quản lý tài khoản và ví điện tử:* Người dùng đăng ký tài khoản mới bằng email/sự kiện mạng xã hội, kích hoạt ví điện tử nội bộ để chuẩn bị cho các giao dịch Escrow.
- *UC-002: Đăng bán sản phẩm C2C:* Người bán tải lên hình ảnh, mô tả, chọn danh mục và cấu hình hình thức bán: *Giá cố định* (niêm yết cứng) hoặc *Giá thương lượng* (cho phép trả giá).
- *UC-003: Tìm kiếm Hybrid và Lọc sản phẩm:* Người mua truy vấn sản phẩm bằng từ khóa tự nhiên kết hợp bộ lọc khoảng giá, khu vực và đánh giá uy tín.
- *UC-004: Trò chuyện & Thương lượng giá (Offer Card):* Hai bên chat realtime. Người bán phát hành Thẻ đề xuất giá (Offer Card) với mức giá thỏa thuận đặc biệt; người mua chấp nhận thẻ để chốt deal.
- *UC-005: Khởi tạo Đơn hàng & Thanh toán tạm giữ (Escrow):* Người mua chọn đơn vị vận chuyển, thanh toán qua cổng ngân hàng. Dòng tiền được chuyển vào trạng thái Khóa tạm giữ (Escrow Held).
- *UC-006: Xác nhận giao hàng & Bộ đếm thời gian 3 ngày:* Nhận webhook giao hàng thành công từ đối tác vận chuyển, hệ thống kích hoạt đếm ngược 72 giờ. Nếu không có khiếu nại, tự động giải ngân cho người bán.
- *UC-007: Yêu cầu Trả hàng / Hoàn tiền (Refund):* Trong hạn 3 ngày, người mua mở khiếu nại kèm minh chứng lỗi/hỏng. Người bán có 48 giờ để chấp nhận hoàn tiền hoặc phản bác.
- *UC-008: Chuyển giao Khiếu nại thành Tranh chấp (Dispute):* Khi người bán phản bác khiếu nại của người mua, hệ thống tự động khóa đơn hàng và nâng cấp thành vụ tranh chấp cần sự can thiệp nội bộ.
- *UC-009: Phân xử Tranh chấp bởi Moderator:* Điều phối viên kiểm tra đối chiếu bằng chứng video/ảnh từ hai phía, ra quyết định cuối cùng: hoàn tiền cho mua hoặc giải ngân cho bán.
- *UC-010: Cấu hình Tham số sàn & Đối soát (Admin):* Quản trị viên thay đổi các mức phí sàn, kiểm tra bảng cân đối kế toán ví Escrow toàn hệ thống.
- *UC-011: Quản lý Nhân sự Điều phối viên:* Admin tạo mới, khóa, phân công nhiệm vụ và giám sát KPI giải quyết tranh chấp của Moderator.
- *UC-012: Kiểm duyệt Bài đăng C2C vi phạm:* Moderator xử lý bài viết có từ khóa cấm, hàng giả, hàng nhái được phát hiện qua hệ thống cờ cảnh báo.
- *UC-013: Báo cáo vi phạm và Gắn cờ tự động:* Người dùng báo cáo người bán lừa đảo; hệ thống tự động khóa tạm thời khi sản phẩm nhận đủ số lượng cờ vi phạm tối đa.

=== Đặc tả các ca sử dụng trọng yếu
Các luồng tác vụ trọng yếu mang tính quyết định đến độ tin cậy của sàn được thiết kế ràng buộc kỹ lưỡng:
- *Luồng Thanh toán và Bảo lãnh tài chính (Escrow 72h - UC-005 & UC-006):* Khi người mua hoàn tất chuyển khoản, số tiền thanh toán không được chuyển trực tiếp cho người bán mà được chuyển vào trạng thái *Khóa tạm giữ (Frozen/Escrow Balance)* tại ví trung gian (`account`). Ngay sau khi webhook từ đối tác vận chuyển xác nhận kiện hàng đã giao thành công, bộ đếm thời gian bền vững của Restate được kích hoạt đếm ngược chính xác 72 giờ (3 ngày). Nếu hết thời hạn này mà người mua không gửi bất kỳ khiếu nại nào, Restate Ingress tự động phát lệnh giải ngân, chuyển tiền từ ví Escrow sang ví khả dụng của người bán.
- *Luồng Trò chuyện và Đàm phán giá (Offer Card - UC-004):* Với các mặt hàng niêm yết ở chế độ *Giá thương lượng*, người mua và người bán đàm phán trực tiếp trong phòng chat. Khi đạt thỏa thuận, người bán phát hành một *Offer Card* chứa đơn giá mới gắn liền với định danh sản phẩm (`spu_id`/`sku_id`) và lý do giảm giá. Người mua bấm nút "Chấp nhận Offer", hệ thống tự động sinh đơn hàng chờ thanh toán với đúng đơn giá đã thỏa thuận.
- *Luồng Khiếu nại và Phân xử (Dispute & Video Evidence - UC-007, UC-008, UC-009):* Khi nhận hàng vi phạm mô tả hoặc hỏng hóc, người mua gửi khiếu nại Refund đính kèm bằng chứng video mở hộp. Nếu người bán từ chối hoàn tiền trong hạn 48 giờ, đơn hàng được leo thang thành vụ tranh chấp (Dispute Case). Moderator xem xét chuỗi bằng chứng không thể chối cãi từ hai bên trên cổng Console và bấm phán quyết giải ngân hoặc hoàn tiền. Quyết định này có hiệu lực thực thi lập tức, bỏ qua mọi bộ đếm giờ tự động còn lại.

=== Bộ quy tắc nghiệp vụ ràng buộc hệ thống (Business Rules)
Sự vận hành chính xác của ShopNexus được ràng buộc bởi bộ quy tắc nghiệp vụ chặt chẽ:
+ *BR-001 (Quy tắc đếm ngược Escrow 72 giờ):* Dòng tiền đơn hàng bị khóa tuyệt đối trong ví trung gian. Bộ đếm 72 giờ chỉ bắt đầu chạy khi có xác nhận giao hàng thành công từ đối tác vận chuyển hoặc khi người bán tự xác nhận giao tay.
+ *BR-002 (Quy tắc hiệu lực của Thẻ Đề xuất giá — Offer Card):* Một Offer Card trong chat chỉ có hiệu lực tối đa trong vòng 24 giờ kể từ khi phát hành. Nếu một trong hai bên có hành vi chỉnh sửa giá sản phẩm gốc hoặc sản phẩm đã bị người khác mua mất, Offer Card lập tức bị vô hiệu hóa (Revoked).
+ *BR-003 (Quy tắc bắt buộc chứng cứ video mở hộp):* Mọi yêu cầu Refund/Dispute với lý do "Hàng lỗi/hỏng" hoặc "Hàng không đúng mô tả" đều bắt buộc phải đính kèm đường dẫn đến video mở hộp liền mạch, không cắt ghép. Hồ sơ thiếu video sẽ bị Moderator từ chối phân xử và xử thua mặc định.
+ *BR-004 (Quy tắc ưu tiên của Quyết định Phân xử):* Quyết định của Moderator trong Use Case UC-009 là quyết định cuối cùng và có hiệu lực thực thi ngay lập tức. Hệ thống sẽ bỏ qua mọi bộ đếm giờ tự động để thực hiện lệnh chuyển tiền theo quyết định này.
+ *BR-005 (Quy tắc cảnh báo và tự động khóa sản phẩm):* Một sản phẩm nếu nhận quá 5 lượt báo cáo vi phạm từ các người dùng độc lập (không trùng địa chỉ IP/tài khoản) sẽ lập tức bị chuyển sang trạng thái Tạm ẩn (Pending Review) để Moderator thẩm định.

== Phân tích yêu cầu chức năng và phi chức năng

=== Yêu cầu chức năng phân chia theo 7 Microservices
Yêu cầu chức năng được ánh xạ chi tiết theo từng microservice chủ quản trong kiến trúc:
- *Module Account & Wallet (`account`):* Quản lý định danh cá nhân, thực hiện quy trình đăng nhập bằng JWT và Refresh Token. Quản lý số dư ví nội bộ với hai tiêu chí: *Số dư khả dụng (Available Balance)* và *Số dư đang bị khóa tạm giữ (Frozen/Escrow Balance)*.
- *Module Catalog (`catalog`):* Hỗ trợ CRUD bài đăng sản phẩm C2C, tích hợp bộ phân loại danh mục hình cây 3 cấp. Hỗ trợ thao tác cập nhật số lượng tồn kho theo nguyên lý giữ chỗ (Inventory Reservation).
- *Module Chat & Negotiation (`chat`):* Duy trì kết nối Websocket/SSE thời gian thực, lưu trữ lịch sử tin nhắn. Xử lý nghiệp vụ tạo, chấp nhận, từ chối và hết hạn Offer Card trực tiếp trong luồng hội thoại.
- *Module Order & Escrow (`order`):* Quản lý trạng thái đơn hàng (`Pending` -> `Paid` -> `Shipping` -> `Delivered` -> `Completed` / `Refunded` / `Disputed`). Tích hợp SDK Restate để duy trì luồng đếm ngược thời gian và tự động mở khóa dòng tiền an toàn.
- *Module Inventory (`inventory`):* Kiểm soát số lượng hàng hóa thực tế theo từng serial/SKU, thực hiện giữ chỗ (Reserve) khi khách hàng bắt đầu tạo phiên thanh toán và trừ kho chính thức (Release/Commit) khi giao hàng thành công.
- *Module Analytic & Search (`analytic`):* Duy trì chỉ mục Vector trên pgvector cho toàn bộ sản phẩm. Cung cấp API tìm kiếm Hybrid, đồng thời tự động cập nhật điểm uy tín người bán dựa trên tỷ lệ giao hàng thành công và số lượng khiếu nại.
- *Module Common & Gateway (`common`):* API Gateway tiếp nhận và điều hướng toàn bộ lưu lượng, xác thực chữ ký token JWT tập trung, đồng thời duy trì kết nối Server-Sent Events (SSE) để đẩy tin nhắn thông báo realtime về trình duyệt/app di động.

=== Yêu cầu phi chức năng (Non-Functional Requirements — NFR)
- *NFR-1 (Đảm bảo tính ACID và Bền vững của Giao dịch Tài chính):* Mọi biến động liên quan đến dòng tiền trong ví Escrow phải tuân thủ nghiêm ngặt chuẩn ACID. Trong trường hợp xảy ra sự cố sập nguồn hay mất kết nối mạng, các giao dịch đang thực hiện dở dang phải được Restate tự động phục hồi và hoàn tất chính xác, không được phép xảy ra tình trạng mất mát hoặc nhân đôi số dư.
- *NFR-2 (Thời gian Phản hồi và Khả năng Chịu tải):* Thời gian phản hồi 95% (p95 latency) của các API đọc dữ liệu và tìm kiếm sản phẩm phải đạt dưới 150ms. Các API khởi tạo đơn hàng và thanh toán phải phản hồi dưới 300ms trong điều kiện tải bình thường (500 người dùng đồng thời).
- *NFR-3 (Bảo mật và Xác thực):* Toàn bộ giao tiếp giữa Client và Server bắt buộc mã hóa qua TLS 1.3. Mật khẩu người dùng được băm bằng thuật toán Argon2id hoặc bcrypt (work factor >= 12). Hệ thống ngăn chặn tuyệt đối các lỗ hổng Injection, XSS và CSRF theo chuẩn OWASP Top 10.
- *NFR-4 (Kiểm toán đầy đủ — Audit Trail):* Tất cả các thao tác thay đổi trạng thái đơn hàng, dòng tiền ví Escrow, và quyết định phân xử của Moderator đều phải được ghi lại vào bảng nhật ký kiểm toán (Audit Log) theo mô hình chỉ thêm mới (Append-Only), không ai được phép sửa đổi hoặc xóa bỏ.

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

#show figure: set block(breakable: true)

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
- *Lý do & Lợi ích:* PostgreSQL là hệ quản trị mã nguồn mở mạnh mẽ, tuân thủ ACID cao và hỗ trợ cực tốt đa định dạng (JSONB, GIS, Vector). Việc chia schema độc lập giúp cô lập lỗi: nếu module `chat` bị tải cao hoặc quá tải CSDL, các module finance trọng yếu như `order` hay `account` vẫn hoạt động hoàn toàn bình thường.

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

=== Bảng tổng hợp các khóa tham chiếu chéo cốt lõi

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
