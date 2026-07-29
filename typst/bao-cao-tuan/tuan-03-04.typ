#import "../common/style-a4.typ": *
#show: a4.with(
  tieu-de: "BÁO CÁO TIẾN ĐỘ HÀNG TUẦN",
  phu-de: "TUẦN 3 & TUẦN 4",
  chay: "Báo cáo tiến độ Tuần 3 & 4",
)

= BÁO CÁO TIẾN ĐỘ TUẦN 3: HOÀN THÀNH YÊU CẦU

== Yêu Cầu Chức Năng (DOC 3.1-A)

=== Trích xuất yêu cầu từ trường hợp sử dụng
Mỗi yêu cầu chức năng (Functional Requirement) được thiết kế theo cấu trúc nguyên tử: *“Hệ thống phải [hành động] [đối tượng] [điều kiện]”*, đảm bảo tính rõ ràng và có thể kiểm chứng. Dưới đây là danh sách các yêu cầu được trích xuất từ 13 trường hợp sử dụng cốt lõi của hệ thống ShopNexus C2C:

*UC-001: Đăng ký tài khoản*
- *REQ-001:* Hệ thống phải hiển thị biểu mẫu đăng ký dành riêng cho khách hàng (User) khi được yêu cầu.
- *REQ-002:* Hệ thống phải xác thực định dạng địa chỉ Email đăng ký của người dùng.
- *REQ-003:* Hệ thống phải từ chối đăng ký và báo lỗi nếu Email nhập vào đã tồn tại trong cơ sở dữ liệu.
- *REQ-004:* Hệ thống phải mã hoá mật khẩu của người dùng bằng thuật toán BCrypt trước khi lưu vào cơ sở dữ liệu.
- *REQ-005:* Hệ thống phải khởi tạo tài khoản mới ở trạng thái hoạt động với vai trò mặc định là `User`.

*UC-002: Đăng nhập*
- *REQ-006:* Hệ thống phải xác thực thông tin Email và Mật khẩu của tài khoản khi người dùng thực hiện đăng nhập.
- *REQ-007:* Hệ thống phải điều hướng người dùng có vai trò `User` về giao diện sàn C2C sau khi đăng nhập thành công.
- *REQ-008:* Hệ thống phải điều hướng nhân viên có vai trò `Moderator` về giao diện quản lý khiếu nại tranh chấp sau khi đăng nhập thành công.
- *REQ-009:* Hệ thống phải điều hướng người quản trị có vai trò `Admin` về giao diện quản trị hệ thống sau khi đăng nhập thành công.

*UC-003: Đăng bán sản phẩm (C2C)*
- *REQ-010:* Hệ thống phải cho phép User tải lên tối thiểu 1 hình ảnh và nhập tên sản phẩm, giá bán, tình trạng, danh mục và mô tả sản phẩm.
- *REQ-011:* Hệ thống phải bắt buộc User lựa chọn một trong hai chế độ đặt giá: "Giá cố định" hoặc "Giá thương lượng".
- *REQ-012:* Hệ thống phải kiểm tra và từ chối đăng bài bán nếu thiếu thông tin bắt buộc hoặc giá bán nhỏ hơn hoặc bằng 0.

*UC-004: Nhắn tin trực tuyến (Chat)*
- *REQ-013:* Hệ thống phải thiết lập kết nối thời gian thực (SSE/HTTP streamable) giữa hai User trong khung chat.
- *REQ-014:* Hệ thống phải cho phép User gửi tin nhắn văn bản, hình ảnh và video thực tế của sản phẩm qua giao diện chat.
- *REQ-015:* Hệ thống phải hỗ trợ User bán tạo và gửi "Offer Card" (Thẻ Đề xuất giá) ghi rõ mức giá đề xuất mới và lý do giảm giá cụ thể trong khung chat.
- *REQ-016:* Hệ thống phải tự động tạo đơn hàng tạm thời và cập nhật giá mới khi User mua nhấn nút "Chấp nhận" trên Offer Card.

*UC-005: Đặt hàng & Thanh toán Escrow*
- *REQ-017:* Hệ thống phải tích hợp API của đối tác vận chuyển để tính phí vận chuyển động dựa trên địa chỉ giao nhận của User mua.
- *REQ-018:* Hệ thống phải kết nối với cổng thanh toán (SePay/Stripe) để tạo mã giao dịch và kiểm tra trạng thái thanh toán trực tuyến.
- *REQ-019:* Hệ thống phải tự động khóa số tiền thanh toán của User mua trong ví tạm giữ Escrow của hệ thống sau khi giao dịch thành công.
- *REQ-020:* Hệ thống phải tự động hủy đơn đặt hàng nếu User mua không hoàn tất thanh toán trực tuyến trong vòng 24 giờ kể từ khi tạo đơn.

*UC-006: Yêu cầu Trả hàng / Hoàn tiền*
- *REQ-021:* Hệ thống phải cho phép User mua gửi yêu cầu hoàn tiền trong vòng tối đa 3 ngày (72 giờ) kể từ khi đơn hàng giao thành công.
- *REQ-022:* Hệ thống phải bắt buộc User mua tải lên video mở hộp và hình ảnh bằng chứng khi gửi yêu cầu hoàn tiền.
- *REQ-023:* Hệ thống phải tạm khóa bộ đếm ngược Escrow của đơn hàng và chuyển trạng thái đơn hàng sang "Yêu cầu Trả hàng".

*UC-007: Khiếu nại và Tranh chấp & UC-008: Phân xử tranh chấp*
- *REQ-024:* Hệ thống phải cho phép User bán bấm "Từ chối trả hàng" để chuyển đơn hàng sang trạng thái "Đang tranh chấp" trong vòng 48 giờ kể từ khi có khiếu nại.
- *REQ-025:* Hệ thống phải hiển thị toàn bộ hồ sơ tranh chấp (bao gồm video/hình ảnh mở hộp của Buyer và đóng gói của Seller) cho Moderator.
- *REQ-026:* Hệ thống phải tự động giải phóng dòng tiền từ ví Escrow (hoàn trả cho Buyer hoặc giải ngân cho Seller) dựa trên phán quyết của Moderator.

*UC-009: Đánh giá & Phản hồi*
- *REQ-027:* Hệ thống phải cho phép User mua đánh giá sao và viết phản hồi cho User bán sau khi đơn hàng được hoàn tất.

*UC-010: Cấp phát tài khoản Moderator*
- *REQ-028:* Hệ thống phải cho phép duy nhất Admin tối cao tạo tài khoản Moderator bằng cách nhập Email và thông tin nhân sự.
- *REQ-029:* Hệ thống phải tự động gửi mật khẩu tạm thời ngẫu nhiên và liên kết kích hoạt tài khoản qua Email cho Moderator mới.

*UC-011: Tìm kiếm & Duyệt sản phẩm*
- *REQ-030:* Hệ thống phải cho phép User tìm kiếm sản phẩm bằng từ khóa ngôn ngữ tự nhiên và trả về kết quả xếp hạng theo độ liên quan.
- *REQ-031:* Hệ thống phải cho phép lọc kết quả theo danh mục, khoảng giá, tình trạng sản phẩm và sắp xếp theo mới nhất / giá / độ phổ biến.
- *REQ-032:* Hệ thống phải hiển thị danh sách "Gợi ý cho bạn" dựa trên lịch sử tương tác của User.

*UC-012: Người bán xử lý đơn hàng đến*
- *REQ-033:* Hệ thống phải hiển thị cho User bán danh sách các mục chờ (pending item) mà người mua đã đặt, kèm thông tin sản phẩm và địa chỉ giao.
- *REQ-034:* Hệ thống phải cho phép User bán xem trước phí vận chuyển (quote) rồi *xác nhận* để tạo đơn hàng + vận đơn, hoặc *từ chối* để giải phóng tồn kho đã giữ.
- *REQ-035:* Hệ thống phải tự động giải phóng tồn kho đã reserve nếu User bán không xác nhận mục chờ trong thời hạn quy định.

*UC-013: Ví điện tử & Rút tiền*
- *REQ-036:* Hệ thống phải hiển thị số dư ví của User gồm *số dư khả dụng* và *số dư đang tạm giữ (Escrow)*, kèm lịch sử biến động số dư (income history).
- *REQ-037:* Hệ thống phải cho phép User bán gửi yêu cầu rút phần *số dư khả dụng* về tài khoản ngân hàng đã đăng ký; không cho phép rút phần đang tạm giữ trong Escrow.
- *REQ-038:* Hệ thống phải ghi log bất biến (append-only) mọi yêu cầu rút tiền và chỉ trừ số dư khả dụng *sau khi* lệnh chi được xác nhận thành công.

=== Ma trận CRUD
Ma trận dưới đây xác định các yêu cầu chức năng bao phủ toàn bộ các thao tác Create, Read, Update, Delete đối với các thực thể cốt lõi trong hệ thống ShopNexus C2C:

#table(
  columns: (1.6fr, 1.15fr, 1fr, 1.35fr, 0.9fr),
  align: (center, center, center, center, center),
  [Thực Thể], [Create (Tạo)], [Read (Đọc)], [Update (Cập Nhật)], [Delete (Xóa)],
  [Account (Tài khoản)], [REQ-001, REQ-005], [REQ-006], [REQ-029 (Đổi MK)], [N/A (Chỉ Khóa)],
  [Product (Sản phẩm)], [REQ-010, REQ-011], [REQ-012], [REQ-012], [REQ-012],
  [Order (Đơn hàng)], [REQ-016], [REQ-017], [REQ-019 (Khóa Escrow)], [REQ-020 (Hủy đơn)],
  [Chat / Offer Card], [REQ-013, REQ-015], [REQ-014], [REQ-016 (Chấp nhận)], [N/A],
  [Dispute / Refund], [REQ-021, REQ-022], [REQ-025], [REQ-024, REQ-026], [N/A],
  [Moderator Account], [REQ-028], [REQ-008], [REQ-029], [N/A (Chỉ Khóa)],
  [Pending / Xử lý đơn (Seller)], [REQ-033 (checkout)], [REQ-033], [REQ-034 (Xác nhận)], [REQ-035 (Từ chối)],
  [Ví (Wallet)], [REQ-001 (khởi tạo)], [REQ-036], [REQ-037, REQ-038 (Rút)], [N/A],
  [Tìm kiếm / Gợi ý], [Tự động (embedding)], [REQ-030, REQ-031, REQ-032], [REQ-032 (re-embed)], [N/A],
)

=== Ma Trận Truy Xuất Nguồn Gốc (Traceability Matrix)
Ma trận truy xuất nguồn gốc giúp theo dõi mối quan hệ giữa Yêu cầu chức năng, Use Case nguồn và thực thể CSDL bị ảnh hưởng:

#table(
  columns: (1fr, 1.4fr, 1.9fr),
  align: (center, center, left),
  [ID Yêu Cầu], [Trường Hợp Sử Dụng Nguồn], [Thực Thể Ảnh Hưởng],
  [REQ-001 - REQ-005], [UC-001: Đăng ký tài khoản], [Account, Wallet],
  [REQ-006 - REQ-009], [UC-002: Đăng nhập], [Account],
  [REQ-010 - REQ-012], [UC-003: Đăng bán sản phẩm C2C], [Product, Category],
  [REQ-013 - REQ-016], [UC-004: Nhắn tin trực tuyến], [ChatMessage, OfferCard, Order],
  [REQ-017 - REQ-020], [UC-005: Đặt hàng & Thanh toán], [Order, EscrowWallet, PaymentSession],
  [REQ-021 - REQ-023], [UC-006: Yêu cầu Trả hàng], [Order, RefundRequest, Transport],
  [REQ-024], [UC-007: Khiếu nại và Tranh chấp], [Order, DisputeCase],
  [REQ-025 - REQ-026], [UC-008: Phân xử tranh chấp], [DisputeCase, WalletTransaction],
  [REQ-027], [UC-009: Đánh giá & Phản hồi], [ProductReview],
  [REQ-028 - REQ-029], [UC-010: Cấp phát tài khoản], [Account, AuditLog],
  [REQ-030 - REQ-032], [UC-011: Tìm kiếm & Duyệt], [ProductEmbedding (catalog), Interaction (analytic)],
  [REQ-033 - REQ-035], [UC-012: Người bán xử lý đơn], [Item, Order (order), Stock (inventory)],
  [REQ-036 - REQ-038], [UC-013: Ví & Rút tiền], [Profile.internal_balance, IncomeHistory, Transaction],
)

== Yêu Cầu Phi Chức Năng (DOC 3.2-A)

Các thuộc tính chất lượng và ràng buộc kỹ thuật của hệ thống ShopNexus C2C được mô tả bằng các yêu cầu phi chức năng (Non-Functional Requirements, NFR) đo lường được dưới đây:

=== Hiệu năng (Performance)
- *NFR-001:* API gọi dịch vụ bên thứ ba (cổng thanh toán, đối tác vận chuyển) phải có timeout và cơ chế retry trước khi báo lỗi cho người dùng.

=== Bảo mật (Security)

*a) Xác thực & Quản lý phiên*
- *NFR-002:* Mật khẩu tài khoản người dùng phải được băm bằng thuật toán Bcrypt trước khi lưu vào cơ sở dữ liệu; hệ thống không bao giờ lưu trữ hoặc log mật khẩu dạng plaintext.
- *NFR-003:* Access token (JWT) phải có thời gian sống ngắn (tối đa 15-30 phút), ký bằng thuật toán HMAC-SHA256 (HS256) hoặc RSA (RS256); kèm Refresh token có thời gian sống dài hơn (tối đa 7 ngày), lưu dưới dạng hash trong CSDL và có thể thu hồi (revoke) khi cần.
- *NFR-004:* Hệ thống phải khóa tạm thời tài khoản (account lockout) sau tối đa 5 lần đăng nhập sai liên tiếp trong 15 phút, kèm cơ chế rate-limit theo IP để chống tấn công brute-force.

*b) Kiểm soát truy cập*
- *NFR-005:* Áp dụng kiểm soát truy cập dựa trên vai trò (RBAC) ở tầng API Gateway/Ingress: mọi endpoint quản trị và phân xử tranh chấp chỉ chấp nhận token có claim vai trò `Moderator` tương ứng.
- *NFR-006:* Áp dụng kiểm soát truy cập cấp đối tượng (Object-level Authorization): người dùng chỉ được đọc/sửa tài nguyên thuộc sở hữu của mình (VD: đơn hàng, ví, bài đăng); mọi request phải được xác minh quyền sở hữu ở tầng service, không chỉ dựa vào role.

*c) Chống tấn công tầng ứng dụng*
- *NFR-007:* Toàn bộ input từ người dùng phải được validate và sanitize ở tầng API để chống SQL Injection, XSS và Command Injection; sử dụng prepared statement/ORM cho mọi truy vấn CSDL, không nối chuỗi SQL thủ công.
- *NFR-008:* Áp dụng rate-limiting theo IP/tài khoản cho các API nhạy cảm (đăng ký, đăng nhập, tạo Offer Card, gửi yêu cầu Refund) để chống tấn công DoS/spam ở tầng ứng dụng.

*d) Kiểm toán & Bảo mật dòng tiền*
- *NFR-009:* Mọi thao tác làm thay đổi số dư ví (khóa Escrow, giải ngân, hoàn tiền) phải được ghi log bất biến (append-only audit log) kèm timestamp, actor thực hiện và trạng thái trước/sau, phục vụ đối soát và điều tra khi có tranh chấp.
- *NFR-010:* Các thao tác nhạy cảm của Admin/Moderator (cấp phát tài khoản, phán quyết tranh chấp, gỡ bài đăng) phải được ghi log riêng và không thể chỉnh sửa/xóa sau khi đã tạo.

=== Khả năng sử dụng (Usability)
- *NFR-011:* Giao diện Web phải responsive, hiển thị đúng bố cục trên độ phân giải từ 360px (mobile) đến 1920px (desktop), theo nguyên tắc mobile-first.
- *NFR-012:* Giao diện phải tuân thủ nguyên tắc accessibility cơ bản (WCAG 2.1 mức A tối thiểu): độ tương phản màu chữ/nền đạt chuẩn, mọi hình ảnh có alt-text, có thể thao tác bằng bàn phím cho các luồng chính.
- *NFR-013:* Mọi thao tác quan trọng có thể gây hậu quả không thể hoàn tác (xác nhận nhận hàng, chấp nhận Offer Card, xác nhận thanh toán) phải có bước xác nhận rõ ràng (confirmation dialog) kèm cảnh báo nội dung tương ứng.

=== Ràng buộc (Constraints)
- *NFR-014:* Việc tính phí và theo dõi vận chuyển phụ thuộc vào API của đối tác vận chuyển bên thứ ba (GHN/GHTK); độ chính xác và thời gian phản hồi bị giới hạn bởi SLA của đối tác, không hoàn toàn nằm trong tầm kiểm soát của hệ thống.
- *NFR-015:* Việc xác nhận giao dịch thanh toán phụ thuộc vào cơ chế IPN/webhook của cổng thanh toán bên thứ ba (SePay/Stripe); hệ thống phải xử lý được các trường hợp webhook đến trễ hoặc không đến (cần cơ chế đối soát/polling dự phòng).
- *NFR-016:* Hệ thống phải tuân thủ quy định pháp luật Việt Nam hiện hành về giao dịch thương mại điện tử và bảo vệ dữ liệu cá nhân (VD: Nghị định 13/2023/NĐ-CP) đối với thông tin định danh, số điện thoại, địa chỉ giao hàng thu thập từ người dùng.

== Mô Phỏng UI (DOC 3.3-A & DOC 3.3-B)

=== Danh sách màn hình chính
Để hỗ trợ toàn bộ các luồng nghiệp vụ C2C an toàn, hệ thống ShopNexus thiết kế 10 giao diện màn hình chính:
1. *Screen-01: Giao diện Đăng nhập & Đăng ký* (Xác thực người dùng).
2. *Screen-02: Trang chi tiết sản phẩm C2C* (Hỗ trợ nút phân luồng "Mua ngay" hoặc "Mua ngay / Thương lượng").
3. *Screen-03: Khung Chat & Đàm phán giá* (Tích hợp Offer Card trực quan và lý do giảm giá).
4. *Screen-04: Trang xác nhận Đặt hàng & Thanh toán Escrow* (Tích hợp API phí ship động).
5. *Screen-05: Trang gửi yêu cầu Trả hàng / Hoàn tiền* (Yêu cầu tải lên video mở hộp).
6. *Screen-06: Bảng điều khiển phân xử tranh chấp của Moderator* (Thẩm định bằng chứng và ra phán quyết).
7. *Screen-07: Giao diện quản lý cấp phát tài khoản Moderator của Admin* (Tạo tài khoản không qua đăng ký công khai).
8. *Screen-08: Trang kết quả tìm kiếm & bộ lọc* (Tìm kiếm hybrid bge-m3, lọc danh mục/giá/tình trạng).
9. *Screen-09: Bảng điều khiển Người bán* (Danh sách mục chờ xác nhận + listing đang bán).
10. *Screen-10: Ví điện tử & Rút tiền* (Số dư khả dụng / tạm giữ Escrow và yêu cầu rút tiền).

=== Bản vẽ Wireframe UI
#pagebreak()
#grid(
  columns: (1fr, 1fr),
  column-gutter: 15pt,
  row-gutter: 15pt,

  wireframe("Screen-01: Đăng nhập & Đăng ký")[
    #v(5pt)
    #align(center)[
      #block(width: 85%)[
        [ LOGO SHOPNEXUS ] \
        #v(10pt)
        #rect(width: 100%, height: 16pt, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 8pt)[Tab: Đăng nhập | Tab: Đăng ký (User)]))
        #v(8pt)
        #grid(
          columns: (50pt, 1fr),
          row-gutter: 8pt,
          [Email:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink),
          [Mật khẩu:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink),
        )
        #v(10pt)
        #grid(
          columns: (1fr, 1fr),
          column-gutter: 10pt,
          rect(width: 100%, height: 15pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 8pt)[Đăng nhập])),
          rect(width: 100%, height: 15pt, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 8pt)[Quên mật khẩu]))
        )
      ]
    ]
  ],
  wireframe("Screen-02: Chi tiết sản phẩm C2C")[
    #v(3pt)
    #grid(
      columns: (1fr, 1.2fr),
      column-gutter: 8pt,
      rect(width: 100%, height: 60pt, stroke: 0.5pt + ink, align(center + horizon, text(size: 7.5pt)[Ảnh thực tế sản phẩm])),
      stack(spacing: 4pt,
        text(weight: 700, size: 9pt)[iPhone 13 Pro Max cũ],
        text(fill: red, weight: 700, size: 8.5pt)[Giá: 12.500.000 đ],
        text(size: 7.5pt)[Chế độ: Thương lượng (~)],
        text(size: 7pt, fill: muted)[Mô tả: Máy đẹp 98%, pin 85%, giao dịch trực tiếp hoặc COD tạm giữ Escrow.],
      )
    )
    #v(8pt)
    #grid(
      columns: (1fr, 1.2fr),
      column-gutter: 10pt,
      rect(width: 100%, height: 18pt, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 7.5pt)[Chat với Người bán])),
      rect(width: 100%, height: 18pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 7.5pt, weight: 700)[Mua ngay / Thương lượng]))
    )
  ],

  wireframe("Screen-03: Khung Chat & Offer Card")[
    #rect(width: 100%, height: 15pt, fill: headfill, align(center + horizon, text(size: 8pt, weight: 700)[Chat: Nguyễn Văn A (Seller)]) )
    #v(4pt)
    #rect(width: 80%, height: 25pt, stroke: 0.5pt + ink, radius: 4pt, inset: 4pt, align(left)[
      #text(size: 7pt)[Buyer: Chào bạn, máy pin còn bao nhiêu phần trăm vậy?]
    ])
    #v(4pt)
    // Offer Card
    #align(right)[
      #block(width: 85%, stroke: 1pt + ink, fill: headfill, inset: 5pt, radius: 4pt)[
        #align(center)[#text(size: 7.5pt, weight: 700)[OFFER CARD (ĐỀ XUẤT GIÁ)]]
        #line(length: 100%, stroke: 0.3pt + hairline)
        #align(left)[
          #text(size: 7pt)[- Giá cũ: 12.500.000 đ] \
          #text(size: 7pt)[- Giá mới đề xuất: *12.200.000 đ*] \
          #text(size: 7pt)[- Lý do: Bớt 300k hỗ trợ phí ship & mua phụ kiện]
        ]
        #v(3pt)
        #grid(
          columns: (1fr, 1fr),
          column-gutter: 5pt,
          rect(width: 100%, height: 12pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 6.5pt)[Chấp nhận])),
          rect(width: 100%, height: 12pt, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 6.5pt)[Từ chối]))
        )
      ]
    ]
    #v(4pt)
    #grid(
      columns: (1fr, 45pt),
      column-gutter: 5pt,
      rect(width: 100%, height: 15pt, stroke: 0.5pt + ink, align(left + horizon, text(size: 7pt, fill: muted)[ Nhập tin nhắn...])),
      rect(width: 100%, height: 15pt, fill: ink, align(center + horizon, text(fill: white, size: 7pt)[Gửi]))
    )
  ],

  wireframe("Screen-04: Đặt hàng & Thanh toán Escrow")[
    #v(3pt)
    #text(weight: 700, size: 9pt)[THÔNG TIN ĐƠN HÀNG \#1092]
    #line(length: 100%, stroke: 0.5pt + hairline)
    #grid(
      columns: (50pt, 1fr),
      row-gutter: 6pt,
      [Sản phẩm:], [iPhone 13 Pro Max (Thương lượng)],
      [Giá hàng:], [12.200.000 đ],
      [Địa chỉ:], [97 Man Thiện, Quận 9, TP. HCM],
      [Phí ship:], [35.000 đ (Tính tự động qua GHN API)],
      [Tổng thanh toán:], text(fill: red, weight: 700)[12.235.000 đ],
    )
    #line(length: 100%, stroke: 0.5pt + hairline)
    #text(size: 7.5pt, style: "italic", fill: muted)[*Lưu ý:* Tiền của bạn sẽ được khóa an toàn trong ví Escrow trung gian trong 3 ngày để bảo vệ quyền lợi của bạn.]
    #v(4pt)
    #rect(width: 100%, height: 18pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 8pt, weight: 700)[Thanh toán tạm giữ (SePay/Stripe)]))
  ],

  wireframe("Screen-05: Yêu cầu Trả hàng / Hoàn tiền")[
    #v(3pt)
    #text(weight: 700, size: 9pt)[GỬI KHIẾU NẠI TRẢ HÀNG / HOÀN TIỀN]
    #v(5pt)
    #grid(
      columns: (50pt, 1fr),
      row-gutter: 8pt,
      [Lý do khiếu nại:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink, align(left + horizon, text(size: 7pt)[ Hàng lỗi, không đúng mô tả])),
      [Mô tả chi tiết:], rect(width: 100%, height: 25pt, stroke: 0.5pt + ink, align(left, text(size: 7pt)[ Máy bị sọc màn hình khi nhận, không giống ảnh])),
    )
    #v(6pt)
    #rect(width: 100%, height: 35pt, stroke: (paint: ink, dash: "dashed"), align(center + horizon)[
      #text(size: 7.5pt, weight: 700)[+ Tải lên Video mở hộp & ảnh lỗi (Bắt buộc)] \
      #text(size: 6.5pt, fill: muted)[(Định dạng MP4, JPG, PNG tối đa 50MB)]
    ])
    #v(6pt)
    #rect(width: 100%, height: 18pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 8pt)[Xác nhận gửi yêu cầu hoàn tiền]))
  ],

  wireframe("Screen-06: Bảng điều khiển tranh chấp (Mod)")[
    #rect(width: 100%, height: 15pt, fill: headfill, align(center + horizon, text(size: 8pt, weight: 700)[PHÂN HỆ ĐIỀU PHỐI VIÊN (MODERATOR)]) )
    #v(4pt)
    #text(weight: 700, size: 8.5pt)[Vụ tranh chấp \#DS-8821 (Đơn hàng \#1092)]
    #grid(
      columns: (1fr, 1fr),
      column-gutter: 8pt,
      rect(width: 100%, height: 45pt, stroke: 0.5pt + ink, inset: 3pt, align(left)[
        #text(size: 6.5pt, weight: 700)[Bằng chứng Buyer:] \
        #text(size: 6.5pt)[- Video: [unboxing.mp4]] \
        #text(size: 6.5pt)[- Lý do: Màn hình bị sọc]
      ]),
      rect(width: 100%, height: 45pt, stroke: 0.5pt + ink, inset: 3pt, align(left)[
        #text(size: 6.5pt, weight: 700)[Bằng chứng Seller:] \
        #text(size: 6.5pt)[- Video: [packaging.mp4]] \
        #text(size: 6.5pt)[- Lý do: Đóng gói máy nguyên vẹn]
      ])
    )
    #v(5pt)
    #grid(
      columns: (1fr, 1fr),
      column-gutter: 8pt,
      rect(width: 100%, height: 15pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 7pt)[Hoàn tiền cho Buyer])),
      rect(width: 100%, height: 15pt, fill: headfill, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 7pt)[Giải ngân cho Seller]))
    )
  ],

  wireframe("Screen-07: Admin cấp phát tài khoản Mod")[
    #rect(width: 100%, height: 15pt, fill: headfill, align(center + horizon, text(size: 8pt, weight: 700)[PHÂN HỆ QUẢN TRỊ VIÊN TỐI CAO (ADMIN)]) )
    #v(5pt)
    #text(weight: 700, size: 8.5pt)[CẤP PHÁT TÀI KHOẢN MODERATOR MỚI]
    #v(5pt)
    #grid(
      columns: (50pt, 1fr),
      row-gutter: 8pt,
      [Họ và tên:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink),
      [Email:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink),
      [Số ĐT:], rect(width: 100%, height: 12pt, stroke: 0.5pt + ink),
    )
    #v(8pt)
    #rect(width: 100%, height: 18pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 8pt, weight: 700)[Cấp phát & Gửi Email kích hoạt]))
  ],

  wireframe("Screen-08: Kết quả tìm kiếm & bộ lọc")[
    #rect(width: 100%, height: 15pt, stroke: 0.5pt + ink, radius: 2pt, align(left + horizon, text(size: 7.5pt, fill: muted)[ Tìm: iphone 13 pro max cũ ...]))
    #v(5pt)
    #grid(
      columns: (0.9fr, 1.6fr),
      column-gutter: 8pt,
      stack(spacing: 5pt,
        text(size: 7pt, weight: 700)[Bộ lọc],
        text(size: 6.5pt)[[ ] Danh mục: Điện thoại],
        text(size: 6.5pt)[[ ] Giá: 5–15 triệu],
        text(size: 6.5pt)[[ ] Tình trạng: Đã dùng],
        text(size: 6.5pt, fill: muted)[Sắp xếp: Liên quan (v)],
      ),
      stack(spacing: 5pt,
        rect(width: 100%, height: 20pt, stroke: 0.5pt + ink, inset: 3pt, align(horizon, text(size: 6.5pt)[[ảnh] iPhone 13 Pro Max, 12.500.000đ · ~thương lượng])),
        rect(width: 100%, height: 20pt, stroke: 0.5pt + ink, inset: 3pt, align(horizon, text(size: 6.5pt)[[ảnh] iPhone 13 Pro, 9.800.000đ · giá cố định])),
        rect(width: 100%, height: 20pt, stroke: 0.5pt + ink, inset: 3pt, align(horizon, text(size: 6.5pt)[[ảnh] iPhone 13, 7.200.000đ · giá cố định])),
      )
    )
    #v(4pt)
    #text(size: 6.5pt, style: "italic", fill: muted)[Xếp hạng theo độ liên quan (bge-m3 hybrid: dense + sparse).]
  ],

  wireframe("Screen-09: Bảng điều khiển Người bán")[
    #rect(width: 100%, height: 15pt, fill: headfill, align(center + horizon, text(size: 8pt, weight: 700)[NGƯỜI BÁN, ĐƠN ĐẾN CHỜ XÁC NHẬN]))
    #v(4pt)
    #rect(width: 100%, height: 34pt, stroke: 0.5pt + ink, inset: 4pt, align(left)[
      #text(size: 6.5pt, weight: 700)[Mục chờ \#PI-3310] \
      #text(size: 6.5pt)[iPhone 13 Pro Max ×1 → 97 Man Thiện, Q9] \
      #text(size: 6.5pt, fill: muted)[Phí ship (quote GHN): 35.000đ · Tổng: 12.235.000đ]
    ])
    #v(5pt)
    #grid(
      columns: (1fr, 1fr),
      column-gutter: 8pt,
      rect(width: 100%, height: 15pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 7pt)[Xác nhận & Tạo đơn])),
      rect(width: 100%, height: 15pt, stroke: 0.5pt + ink, radius: 2pt, align(center + horizon, text(size: 7pt)[Từ chối (nhả kho)]))
    )
    #v(4pt)
    #text(size: 6.5pt, fill: muted)[Listing đang bán: 4 · Đã bán: 12 · Đánh giá: 4.8/5]
  ],

  wireframe("Screen-10: Ví điện tử & Rút tiền")[
    #v(3pt)
    #grid(
      columns: (1fr, 1fr),
      column-gutter: 8pt,
      rect(width: 100%, height: 30pt, stroke: 0.5pt + ink, inset: 4pt, align(left)[
        #text(size: 6.5pt, fill: muted)[Số dư khả dụng] \
        #text(size: 10pt, weight: 700)[8.450.000 đ]
      ]),
      rect(width: 100%, height: 30pt, stroke: (paint: ink, dash: "dashed"), inset: 4pt, align(left)[
        #text(size: 6.5pt, fill: muted)[Đang tạm giữ (Escrow)] \
        #text(size: 10pt, weight: 700)[12.235.000 đ]
      ])
    )
    #v(5pt)
    #text(size: 6.5pt, weight: 700)[Lịch sử gần đây]
    #text(size: 6.5pt)[+ Giải ngân đơn \#1080 · − Rút về Vietcombank (VCB)]
    #v(5pt)
    #rect(width: 100%, height: 18pt, fill: ink, radius: 2pt, align(center + horizon, text(fill: white, size: 8pt, weight: 700)[Yêu cầu rút (chỉ số dư khả dụng)]))
  ]
)

#pagebreak()
=== Sơ đồ luồng điều hướng (DOC 3.3-B)
Sơ đồ dưới đây biểu diễn luồng di chuyển của người dùng qua các giao diện màn hình chính từ bước đăng nhập, phân luồng mua sản phẩm cố định hay thương lượng, cho đến thanh toán Escrow, hoàn tiền và phân xử tranh chấp:

#fig(
  [Sơ đồ luồng điều hướng màn hình hệ thống ShopNexus C2C (Navigation Flow Diagram)],
  spacing: (40mm, 9mm),
  // main spine đi dọc trên cột x = 0; các nhánh rẽ sang phải (x = 2)
  nt((0, 0), [Login / Register\ (Screen-01)]),
  np((2, 0), [Admin Provisioning\ (Screen-07)]),
  edge((2, 0), (0, 0), "-|>", stroke: (paint: ink, thickness: 1pt, dash: "dashed"), text(size: 7.5pt)[Tạo & Email mật khẩu]),

  edge((0, 0), (0, 1), "-|>"),
  np((0, 1), [Trang chủ / Sản phẩm]),
  edge((0, 1), (0, 2), "-|>"),
  np((0, 2), [Chi tiết sản phẩm\ (Screen-02)]),

  edge((0, 2), (0, 3), "-|>", text(size: 8pt)[Giá cố định]),
  edge((0, 2), (2, 3), "-|>", text(size: 8pt)[Giá thương lượng]),
  np((2, 3), [Khung Chat & Offer Card\ (Screen-03)]),
  edge((2, 3), (0, 3), "-|>", text(size: 8pt)[Chấp nhận Offer]),

  np((0, 3), [Xác nhận & Thanh toán\ (Screen-04)]),
  edge((0, 3), (0, 4), "-|>", text(size: 8pt)[Thành công]),
  ng((0, 4), [Ví Escrow khóa tiền]),
  edge((0, 4), (0, 5), "-|>"),
  np((0, 5), [Đơn hàng đã giao]),
  edge((0, 5), (0, 6), "-|>"),

  nd((0, 6), [Hết 3 ngày?]),
  edge((0, 6), (2, 6), "-|>", text(size: 8pt)[Có]),
  ng((2, 6), [Giải ngân Seller]),
  edge((0, 6), (0, 7), "-|>", text(size: 8pt)[Khiếu nại]),
  np((0, 7), [Yêu cầu Trả hàng\ (Screen-05)]),
  edge((0, 7), (0, 8), "-|>"),

  nd((0, 8), [Seller đồng ý?]),
  edge((0, 8), (2, 8), "-|>", text(size: 8pt)[Có]),
  ng((2, 8), [Hoàn tiền Buyer]),
  edge((0, 8), (0, 9), "-|>", text(size: 8pt)[Không]),
  np((0, 9), [Tranh chấp (Dispute)]),
  edge((0, 9), (0, 10), "-|>"),
  np((0, 10), [Moderator phân xử\ (Screen-06)]),
  edge((0, 10), (2, 10), "-|>"),
  ng((2, 10), [Quyết định cuối cùng]),
)

#pagebreak()

// ============================================================
= BÁO CÁO TIẾN ĐỘ TUẦN 4: ĐỊNH NGHĨA KIẾN TRÚC

== Trích Xuất Các Yếu Tố Kiến Trúc (DOC 4.1-A)

Kiến trúc của hệ thống ShopNexus C2C được định hình trực tiếp bởi các thuộc tính chất lượng (Quality Attributes) trọng yếu và các ràng buộc (Constraints) được trích xuất dưới đây:

=== Các thuộc tính chất lượng quan trọng (Quality Attributes)

- *Tính đúng đắn & khả năng phục hồi của luồng tài chính dài hạn (Durability & Reliability):*
  Các luồng nghiệp vụ Escrow (khóa tiền → đếm ngược 3 ngày → giải ngân/hoàn tiền/dispute)
  kéo dài qua nhiều bước và nhiều ngày, có thể bị gián đoạn bởi crash service, restart
  pod, hoặc lỗi mạng giữa chừng. Kiến trúc phải đảm bảo trạng thái không bị mất và
  không xử lý trùng lặp khi phục hồi sau lỗi.

- *Bảo mật dòng tiền & khả năng đối soát (Escrow Security & Auditability):*
  Dòng tiền tạm giữ là cốt lõi xây dựng lòng tin trên sàn. Mọi biến động số dư ví
  Escrow/ví khả dụng phải được ghi log bất biến (audit trail), có thể truy vết đầy đủ
  ai/khi nào/thay đổi gì, phục vụ đối soát và xử lý tranh chấp. *(Liên hệ: NFR-009, NFR-010)*

- *Khả năng mở rộng độc lập theo dịch vụ (Independent Scalability):*
  Lượng truy cập dao động mạnh theo giờ cao điểm đặc
  biệt ở Chat Service (realtime) và Catalog Service (đọc nhiều). Kiến trúc phải cho
  phép scale từng service độc lập mà không cần nhân bản toàn hệ thống.

- *Tính độc lập & cô lập lỗi giữa các dịch vụ (Modularity & Fault Isolation):*
  Các nghiệp vụ Thanh toán/Escrow (order), Nhắn tin (chat), Quản lý sản phẩm & Tìm kiếm
  (catalog), Tồn kho (inventory) và Phân tích hành vi (analytic) có logic nghiệp vụ và chu
  kỳ thay đổi khác nhau. Việc tách module giúp lỗi ở một service (VD: Chat) không lan sang
  luồng đặt hàng/thanh toán. Lưu ý: *kiểm duyệt và phân xử tranh chấp không phải một service
  riêng* mà là hành động của vai trò Moderator/Admin thao tác trên hồ sơ tranh chấp trong
  module `order` (`order.refund_dispute`) và trên listing trong module `catalog`.

- *Tính nhất quán dữ liệu (Data Consistency):*
  Dùng mô hình CSDL riêng theo từng service để tối ưu hiệu năng, nhưng vẫn phải đảm
  bảo tính nhất quán cuối cùng (eventual consistency) khi trạng thái đơn hàng chuyển
  đổi (VD: Đã giao → Tranh chấp → Hoàn tiền), không để tiền và trạng thái đơn hàng
  lệch pha nhau.

- *Khả năng quan sát hệ thống (Observability):*
  Với kiến trúc phân tán nhiều service giao tiếp qua Ingress và message bus, cần khả
  năng theo dõi end-to-end một giao dịch (trace) đi qua các service để debug và phục
  vụ đối soát khi có khiếu nại. *(Liên hệ: NFR-009)*

=== Các ràng buộc chính (Key Constraints)

- *Ràng buộc tích hợp bên thứ ba (Third-party Integration Constraints):* Hệ thống
  bắt buộc phải tích hợp với cổng thanh toán SePay/Stripe và đối tác vận chuyển
  GHN/GHTK theo yêu cầu nghiệp vụ; kiến trúc phải chấp nhận các giới hạn về API,
  độ trễ phản hồi và cơ chế xác nhận (IPN/webhook) do các bên thứ ba này quy định,
  không thể tự thay đổi.
- *Ràng buộc nguồn lực (Resource Constraints):* Dự án được phát triển và hoàn thiện
  bởi nhóm 3 sinh viên trong thời gian thực tập 8 tuần. Kiến trúc thiết kế phải
  cân bằng giữa tính hiện đại và tính khả thi trong thực thi thực tế.
- *Ràng buộc kỹ năng (Skill Constraints):* Nhóm cần thời gian làm quen với công
  nghệ mới lựa chọn để triển khai, ít tài liệu/cộng đồng tiếng
  Việt hỗ trợ, cần cân nhắc rủi ro tiến độ khi áp dụng công nghệ chưa quen thuộc
  cho toàn bộ hệ thống thay vì chỉ các luồng thực sự cần thiết.
#pagebreak()


== Chọn Stack Công Nghệ (DOC 4.2-A)

Dựa trên các yếu tố kiến trúc và ràng buộc đã trích xuất ở DOC 4.1-A, nhóm chốt stack công nghệ chi tiết cho hệ thống ShopNexus C2C như sau:

=== Tổng quan công nghệ
#table(
  columns: (1.15fr, 1.35fr, 1.1fr, 2.4fr),
  align: (center, center, center, left),
  [Tầng / Lớp], [Công Nghệ], [Phiên Bản], [Mục Đích Sử Dụng],
  [Frontend Web], [Next.js, TypeScript], [14.x / React 18], [Xây dựng giao diện web cho User, Moderator, Admin, hỗ trợ SSR/SSG cho trang sản phẩm.],
  [Frontend Mobile], [Flutter, Dart], [3.x], [Ứng dụng di động cho User: mua/bán, chat, thanh toán, dùng chung API backend với Web.],
  [Backend Services], [Go], [1.22+], [Phát triển các dịch vụ nghiệp vụ cốt lõi, tận dụng concurrency mạnh và hiệu năng cao của Go.],
  [Database (Relational)], [PostgreSQL], [16.x], [Lưu trữ dữ liệu có tính toàn vẹn cao (Account, Order, Payment/Escrow, Refund, Dispute), tách schema theo từng service.],
  [Tìm kiếm ngữ nghĩa (Vector)], [pgvector + bge-m3], [pgvector 0.7 / bge-m3], [Tìm kiếm sản phẩm hybrid (dense + sparse) ngay trong PostgreSQL; embedding văn bản sinh bằng model bge-m3, không cần vận hành vector DB riêng.],
  [In-Memory Caching], [Redis], [7.x], [Lưu trữ phiên đăng nhập, bộ đệm dữ liệu truy vấn nóng (sản phẩm hot, trạng thái chat).],
  [Event Bus], [NATS JetStream], [2.10.x], [Giao tiếp bất đồng bộ nhẹ giữa các service (sự kiện đơn hàng, thanh toán, thông báo), đủ persistence/replay mà không nặng như Kafka.],
  [Containerization & Orchestration], [Docker, Kubernetes (k8s)], [N/A], [Đóng gói và điều phối triển khai toàn bộ hệ thống, tự động scale và health-check từng service.],
)

=== Lý giải lựa chọn stack công nghệ

Mỗi công nghệ trong stack đều có lựa chọn thay thế phổ biến hơn. Thay vì so sánh từng tiêu chí một, phần này tập trung nêu *lý do chính* khiến nhóm chọn từng công nghệ cho bối cảnh dự án (nhóm 3 người, 8 tuần, luồng tài chính Escrow dài hạn).

*Go cho Backend.* Lý do quyết định là sự kết hợp Go + Restate. Nhóm cần durable execution cho luồng Escrow/Dispute kéo dài nhiều ngày, mà SDK Go của Restate là SDK trưởng thành và được ưu tiên bảo trì nhất; khi đã chọn Restate làm nền tảng, Go là ngôn ngữ khai thác SDK đó tốt nhất. Ngoài ra Go biên dịch ra binary tĩnh nhỏ (~10-30MB RAM mỗi service), khởi động nhanh và có mô hình goroutine nhẹ, rất hợp khi Kubernetes scale-out thêm pod. So với NestJS (Node.js) hay Spring Boot (Java), Go có ít thư viện dựng sẵn hơn (không có ORM kiểu Hibernate hay DI container như Spring), nên nhóm chấp nhận viết thêm code ở lớp truy cập dữ liệu (SQLC + pgx). Đây là đánh đổi có chủ ý để đổi lấy binary gọn và tích hợp Restate mượt.

*Next.js cho Frontend Web.* Trang danh mục và chi tiết sản phẩm cần SEO để bot tìm kiếm index được, nên phải render phía server. Một SPA thuần (React + Vite) chỉ render phía client, bot sẽ thấy HTML trống và mất khả năng index; đây là lý do loại SPA thuần. Next.js có sẵn SSR/SSG, file-based routing và tự code-split theo route, lại dựa trên React mà nhóm đã quen, nên chi phí học chỉ là App Router chứ không phải một framework hoàn toàn mới. Nuxt (Vue) cũng có SSR nhưng hệ sinh thái UI nhỏ hơn và nhóm chưa quen Vue.

*Flutter cho Mobile.* Với 3 người trong 8 tuần, nhóm không thể duy trì hai codebase native (Swift + Kotlin), nên cần giải pháp một codebase. Flutter biên dịch ra mã native, tự vẽ UI qua Skia nên hiệu năng gần native và giao diện nhất quán trên cả iOS lẫn Android, ít gặp lỗi cầu nối (bridge) như React Native. Đánh đổi là phải học Dart, nhưng cú pháp Dart gần Java/Kotlin nên thời gian làm quen ngắn.

*PostgreSQL làm CSDL chính.* Order/Escrow/Wallet có quan hệ chặt và yêu cầu ACID thực sự, nên nhóm loại MongoDB (document-native, yếu về JOIN quan hệ và transaction đa bảng). PostgreSQL có ACID đầy đủ, transaction đa bảng mạnh, đồng thời hỗ trợ JSONB cho các trường cần schema linh hoạt (thuộc tính sản phẩm, dữ liệu khuyến mãi) nên không cần thêm một CSDL document riêng. Các tính năng như partial unique index và row-level locking cũng cần thiết cho Escrow và phương thức thanh toán.

*pgvector + bge-m3 cho tìm kiếm.* Hệ thống không phải sàn search-heavy: lượng truy vấn tìm kiếm không đủ lớn để bù chi phí vận hành một vector DB riêng như Milvus (thêm service, thêm pipeline đồng bộ dữ liệu, thêm điểm lỗi). pgvector giữ toàn bộ vector ngay trong PostgreSQL, dùng chung transaction/backup và cho phép lọc theo danh mục/giá/tồn kho trong cùng một truy vấn. Model bge-m3 sinh đồng thời vector dense và sparse nên một model duy nhất phủ cả tìm kiếm ngữ nghĩa lẫn từ khóa. Đánh đổi: khi dataset lên tới hàng chục triệu vector, ANN thuần của pgvector sẽ chậm hơn Milvus, nhưng ở quy mô dự án đây là đánh đổi hợp lý để bớt một hệ thống phải vận hành.

*NATS JetStream làm Event Bus.* Event bus của hệ thống chủ yếu để fan-out thông báo và đồng bộ trạng thái giữa vài service, không phải hệ event-streaming khối lượng lớn. Vì vậy Kafka (nặng, chạy trên JVM, cấu hình partition/retention phức tạp) là chi phí không tương xứng, còn RabbitMQ thì không replay được message sau khi đã ACK. NATS JetStream chỉ là một binary Go nhẹ, latency thấp, nhưng vẫn có persistence và replay theo stream khi một consumer khởi động lại. Riêng bộ đếm ngược Escrow 3 ngày không giao cho message broker mà giao cho durable timer của Restate.

*Redis cho caching/session.* Redis được chọn thay vì Memcached vì hỗ trợ nhiều kiểu dữ liệu (Sorted Set cho feed xếp hạng, Pub/Sub cho thông báo SSE, String cho session token) trong khi Memcached chỉ có key-value. Redis cũng có tùy chọn persistence (AOF/RDB) giảm mất session khi restart. Không dùng in-process cache vì nó không chia sẻ được giữa nhiều pod khi Kubernetes scale-out.

*Kubernetes cho triển khai.* Docker Compose đủ cho môi trường dev local nhưng không đáp ứng production vì thiếu auto-scaling, self-healing và rolling update. Kubernetes giải quyết cả ba qua HPA, liveness/readiness probe và rolling deployment. Đánh đổi là Kubernetes phức tạp hơn đáng kể; nhóm chấp nhận thời gian cấu hình để có hạ tầng ổn định cho bản demo cuối thực tập (và dùng k3s nhẹ cho môi trường demo, xem rủi ro R-01).

=== Rủi ro công nghệ và giải pháp giảm thiểu

Bảng dưới đây liệt kê các rủi ro kỹ thuật đã được nhận diện từ stack công nghệ đã chọn, đánh giá mức độ xác suất và tác động, kèm giải pháp giảm thiểu cụ thể. Các rủi ro được sắp xếp theo thứ tự ưu tiên xử lý (cao → thấp).

#table(
  columns: (0.4fr, 1.6fr, 0.5fr, 0.5fr, 2fr),
  align: (center, left, center, center, left),
  [*ID*], [*Rủi ro*], [*Xác suất*], [*Tác động*], [*Giải pháp giảm thiểu*],
  [R-01],
  [*Kubernetes, chi phí vận hành vượt dự kiến:* Kubernetes yêu cầu cấu hình không nhỏ (networking, probe, HPA, secret). Vận hành cụm k8s có thể chiếm 20-30% thời gian DevOps của nhóm, ít thời gian cho nghiệp vụ.],
  [Trung bình], [Cao],
  [Dùng *k3s* (Kubernetes nhẹ, single-node) thay vì k8s full cluster trong môi trường demo. Ưu tiên Docker Compose cho môi trường dev, chỉ dùng k3s cho staging/demo cuối. Event bus dùng *NATS JetStream* (một binary Go, cấu hình tối thiểu) nên gần như không thêm gánh nặng vận hành so với Kafka.],

  [R-02],
  [*Tích hợp bên thứ ba (SePay/Stripe, GHN/GHTK) không ổn định:* Cổng thanh toán và đối tác vận chuyển có thể trả lỗi hoặc timeout, webhook IPN đến trễ hoặc không đến. Nhóm không kiểm soát được SLA của bên thứ ba nên lỗi ngoài ý muốn có thể phá vỡ luồng checkout hoặc Escrow.],
  [Trung bình], [Cao],
  [Triển khai *Circuit Breaker* (timeout + retry có giới hạn) cho mọi lời gọi ra ngoài. Xây dựng *mock server* cho SePay/GHN ngay từ đầu để toàn bộ luồng có thể kiểm thử không phụ thuộc bên thứ ba. Cơ chế *polling dự phòng* để đối soát trạng thái giao dịch nếu webhook không đến (NFR-015).],
  [R-03],
  [*Dữ liệu không nhất quán giữa service trong kiến trúc distributed:* Khi gọi chéo qua Restate (VD: Order Service → Account Service để cập nhật ví), nếu bước thứ hai thất bại sau khi bước đầu đã commit, dữ liệu có thể lệch nhau, tuy nhiên Restate đã xử lý phần lớn thông qua journal replay.],
  [Thấp], [Cao],
  [Restate tự động đảm bảo idempotency và retry cho mọi bước trong durable handler; đây là lý do chính chọn Restate thay vì tự xây Saga. Thêm vào đó, áp dụng *append-only audit log* cho mọi biến động ví (NFR-009) để có thể phát hiện và đối soát thủ công nếu có drift dữ liệu bất thường.],
)
#pagebreak()

== Xác Định Kiến Trúc Hệ Thống (DOC 4.3-A & DOC 4.3-B)

=== Sơ đồ kiến trúc hệ thống
Sơ đồ dưới đây thể hiện kiến trúc Durable Microservices trên nền Restate của hệ thống ShopNexus C2C. Các yêu cầu *mutation* (đặt hàng, gửi Offer, thanh toán, phán quyết tranh chấp) đi qua Restate Ingress (Proxy) để được journal hóa, idempotent và phục hồi được sau lỗi. Ngược lại, các yêu cầu *query* (xem sản phẩm, tìm kiếm, lịch sử đơn) gọi thẳng service qua HTTP/2 RPC, bỏ qua Ingress, vì mỗi hop qua Ingress tốn thêm ~50ms (kể cả trên localhost), không đáng cho luồng đọc nhiều:

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


=== Mô tả thành phần hệ thống
Dưới đây là chi tiết trách nhiệm và công nghệ của từng thành phần trong sơ đồ kiến trúc:

#table(
  columns: (1.4fr, 2.5fr, 1.5fr),
  align: (center, left, center),
  [Tên Thành Phần], [Trách Nhiệm / Nhiệm Vụ], [Công Nghệ Sử Dụng],
  [Restate Ingress], [Nhận yêu cầu *mutation* từ client, xác thực token, định tuyến vào durable function của service tương ứng; đảm bảo idempotency. Yêu cầu *query* gọi thẳng service qua HTTP/2, không qua Ingress.], [Restate],
  [Account Service], [Quản lý đăng ký, đăng nhập, phân quyền User/Moderator/Admin, và số dư ví (khả dụng/tạm giữ Escrow).], [Go + PostgreSQL],
  [Catalog Service], [Quản lý đăng bán, cập nhật trạng thái hiển thị sản phẩm, tìm kiếm hybrid (dense + sparse) và gợi ý.], [Go + PostgreSQL (pgvector) + bge-m3],
  [Chat Service], [Xử lý tin nhắn thời gian thực, lưu lịch sử chat, quản lý trạng thái Offer Card thương lượng giá.], [Go + PostgreSQL],
  [Order Service #text(fill: rgb("#1E3F8F"))[(Durable)]], [Xử lý đặt hàng, kết nối cổng thanh toán, khóa/giải ngân Escrow theo mốc thời gian (durable function), phân bổ phí vận chuyển buyer/seller; quản lý hồ sơ hoàn tiền & tranh chấp và ghi nhận phán quyết Moderator.], [Go + Restate + PostgreSQL + SePay/Stripe API],
  [Inventory Service], [Quản lý tồn kho theo serial, reserve/release khi checkout hoặc hủy đơn, lưu audit trail biến động kho.], [Go + PostgreSQL],
  [Analytic Service], [Ghi nhận tương tác người dùng, tính điểm phổ biến sản phẩm theo thời gian thực, cập nhật gợi ý cho Catalog.], [Go + PostgreSQL + NATS],
  [Common Service #text(fill: rgb("#1E3F8F"))[(SSE/Storage)]], [Object storage (bằng chứng ảnh/video, ảnh sản phẩm), server-sent events cho realtime chat/thông báo, geocoding, registry cấu hình service.], [Go + Redis + NATS],
)

=== Ma trận giao tiếp giữa các thành phần
Ma trận này mô tả cách các thành phần trong hệ thống trao đổi thông tin với nhau để hoàn tất các nghiệp vụ liên quan:

#table(
  columns: (1.2fr, 1.2fr, 0.9fr, 2fr),
  align: (center, center, center, left),
  [Từ Thành Phần], [Đến Thành Phần], [Giao Thức], [Mục Đích Trao Đổi],
  [Client], [Restate Ingress], [HTTPS], [Gửi yêu cầu *mutation* (ghi), đặt hàng, gửi Offer, thanh toán.],
  [Client], [Các Service], [HTTP/2 RPC], [Gửi yêu cầu *query* (đọc) trực tiếp, bỏ qua Ingress để tránh ~50ms mỗi hop.],
  [Restate Ingress], [Các Service], [Durable RPC], [Định tuyến mutation vào durable function/handler tương ứng sau khi xác thực.],
  [Order Service], [Account Service], [Durable RPC], [Kiểm tra và cập nhật số dư ví người mua/người bán khi khóa/giải ngân Escrow.],
  [Order Service], [Catalog Service], [Durable RPC], [Xác nhận thông tin sản phẩm và cấu hình phí ship (buyer/seller trả) khi checkout.],
  [Order Service], [Inventory Service], [Durable RPC], [Reserve/release tồn kho khi checkout hoặc hủy đơn.],
  [Order Service], [Common Service], [HTTP/2 RPC], [Lưu bằng chứng video/ảnh (mở hộp, đóng gói) cho hồ sơ hoàn tiền/tranh chấp.],
  [Order Service], [NATS JetStream], [Async Event], [Publish sự kiện "Đơn đã thanh toán" / "Đã nhận hàng" / "Hoàn tiền" cho các service khác.],
  [Chat Service], [NATS JetStream], [Async Event], [Publish sự kiện "Tin nhắn mới" / "Offer mới".],
  [NATS JetStream], [Common Service], [Async Event], [Nhận sự kiện đơn hàng/chat để đẩy thông báo realtime (SSE)/email.],
  [NATS JetStream], [Analytic Service], [Async Event], [Nhận sự kiện tương tác/đơn hàng để tính điểm phổ biến sản phẩm.],
  [Order Service], [SePay/Stripe Gateway], [HTTPS], [Tạo liên kết thanh toán và nhận phản hồi IPN giao dịch.],
  [Order Service], [GHN/GHTK API], [HTTPS], [Tính phí vận chuyển động và cập nhật hành trình đơn hàng.],
)

=== Mô hình dữ liệu tổng hợp & tham chiếu chéo module (Cross-module Data Model)
Theo mô hình Database-per-service (ADR-02), mỗi module sở hữu một schema PostgreSQL riêng và *không* khai báo khóa ngoại vật lý xuyên schema. Các liên kết giữa module chỉ là *tham chiếu logic* (VD: `order` lưu `buyer_id` trỏ tới `account`), được giải quyết qua RPC (query đọc thẳng HTTP/2, mutation qua Restate) chứ không bằng SQL JOIN chéo schema. Sơ đồ và bảng dưới đây tổng hợp các khóa tham chiếu chéo chính:

#fig(
  [Mô hình tham chiếu chéo module (Cross-module Logical References)],
  spacing: (32mm, 16mm),
  ncore((1.5, 1), [order]),
  np((0, 0), [account]),
  np((3, 0), [catalog]),
  np((0, 2), [inventory]),
  np((3, 2), [chat]),
  np((1.5, 2.3), [analytic]),
  np((1.5, -0.3), [common]),
  edge((1.5, 1), (0, 0), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[buyer_id / seller_id]),
  edge((1.5, 1), (3, 0), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[sku_id / spu_id]),
  edge((1.5, 1), (0, 2), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[serial_ids]),
  edge((3, 2), (0, 0), "-|>", stroke: (dash: "dashed"), bend: 20deg, text(size: 7pt)[buyer_id / seller_id]),
  edge((1.5, 2.3), (3, 0), "-|>", stroke: (dash: "dashed"), bend: -12deg, text(size: 7pt)[interaction -> spu]),
  edge((0, 0), (1.5, -0.3), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[avatar_rs_id]),
  edge((3, 0), (1.5, -0.3), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[image rs_id]),
)

#table(
  columns: (1.7fr, 1fr, 1.6fr, 1.9fr),
  align: (left, left, left, left),
  [Khóa tham chiếu], [Từ schema], [Trỏ tới (logic)], [Ghi chú],
  [account_id / buyer_id / seller_id], [order, chat, analytic], [account.account], [Không FK vật lý xuyên schema, chỉ tham chiếu logic, resolve qua RPC.],
  [sku_id / spu_id], [order], [catalog.product_sku / product_spu], [Snapshot `sku_name` được lưu tại thời điểm giao dịch, không JOIN runtime.],
  [serial_ids], [order], [inventory.serial], [Reserve khi checkout, release khi hủy/từ chối mục chờ.],
  [rs_id (avatar, ảnh SP, bằng chứng)], [account, catalog, order], [common.resource], [Trỏ tới object storage (ảnh sản phẩm, video/ảnh mở hộp).],
  [payment_option], [order], [Registry provider (SePay/Stripe)], [Là map key runtime chọn provider, không phải FK.],
)


=== Sơ đồ tuần tự các luồng nghiệp vụ durable (Sequence Diagrams)
Hai luồng tài chính dài hạn quan trọng nhất được triển khai như *durable function* trên Restate. Sơ đồ tuần tự dưới đây thể hiện thứ tự các bước và điểm phục hồi: mỗi bước ghi (mutation) đều được Restate journal hóa, nên khi service crash/restart luồng tiếp tục đúng từ bước dừng gần nhất, không xử lý trùng.

#fig(
  [Luồng Đặt hàng -> Khóa Escrow -> Giải ngân (durable trên Restate)],
  spacing: (30mm, 8mm),
  np((0, 0), [Buyer]),
  ncore((1, 0), [Order Svc\ (Restate)]),
  np((2, 0), [Inventory]),
  np((3, 0), [Payment GW]),
  np((4, 0), [Seller]),
  edge((0, 0.4), (0, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((1, 0.4), (1, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((2, 0.4), (2, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((3, 0.4), (3, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((4, 0.4), (4, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((0, 1), (1, 1), "-|>", text(size: 7pt)[1. Checkout (SKU, địa chỉ)]),
  edge((1, 2), (2, 2), "-|>", text(size: 7pt)[2. Reserve tồn kho]),
  edge((2, 3), (1, 3), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[3. serial_ids đã giữ]),
  edge((1, 4), (4, 4), "-|>", text(size: 7pt)[4. Thông báo mục chờ (NATS)]),
  edge((4, 5), (1, 5), "-|>", text(size: 7pt)[5. Xác nhận + chọn ship -> tạo Order]),
  edge((0, 6), (1, 6), "-|>", text(size: 7pt)[6. PayBuyerOrders]),
  edge((1, 7), (3, 7), "-|>", text(size: 7pt)[7. Tạo phiên thanh toán]),
  edge((3, 8), (1, 8), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[8. Webhook ConfirmPayment (OK)]),
  ng((1, 9), text(size: 7pt)[execution: khóa tiền -> Escrow]),
  nt((1, 10.3), text(size: 7pt)[Restate timer: đếm ngược 3 ngày]),
  edge((1, 11.4), (4, 11.4), "-|>", text(size: 7pt)[Hết hạn, không khiếu nại -> Giải ngân Seller]),
)

#note[Ba pha theo quy ước `decision` -> `execution` -> `tail`: *decision* đọc & validate (fail-fast, chưa commit); *execution* các commit durable (reserve kho, khóa Escrow); *tail* fan-out sau commit (thông báo qua NATS). Bù trừ (compensation): nếu thanh toán thất bại/timeout, bước reserve tồn kho được release tự động qua saga, không để kho bị giữ treo.]

#fig(
  [Luồng Hoàn tiền & Tranh chấp (RefundWorkflow, durable, keyed theo refund_id)],
  spacing: (30mm, 8mm),
  np((0, 0), [Buyer]),
  ncore((1, 0), [Order Svc\ (Restate)]),
  np((2, 0), [Seller]),
  np((3, 0), [Moderator]),
  np((4, 0), [Ví / Escrow]),
  edge((0, 0.4), (0, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((1, 0.4), (1, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((2, 0.4), (2, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((3, 0.4), (3, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((4, 0.4), (4, 12), stroke: (paint: hairline, dash: "dashed")),
  edge((0, 1), (1, 1), "-|>", text(size: 7pt)[1. CreateBuyerRefund (lý do, video, vận đơn trả)]),
  nt((1, 2), text(size: 7pt)[RefundWorkflow bắt đầu (key = refund_id)]),
  nt((1, 3), text(size: 7pt)[Chờ hàng trả về (fallback 14 ngày)]),
  edge((1, 4), (2, 4), "-|>", text(size: 7pt)[2. Chờ Seller review (3 ngày, auto-accept)]),
  edge((2, 5), (1, 5), "-|>", text(size: 7pt)[3a. SellerApproveRefund]),
  edge((1, 6), (4, 6), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[4a. Hoàn tiền Buyer (reversal tx)]),
  edge((2, 7), (1, 7), "-|>", text(size: 7pt)[3b. SellerDisputeRefund]),
  edge((1, 8), (3, 8), "-|>", text(size: 7pt)[4b. Chờ Moderator phân xử]),
  edge((3, 9), (1, 9), "-|>", text(size: 7pt)[5b. Dismiss (BuyerWins) / Uphold (SellerWins)]),
  edge((1, 10.4), (4, 10.4), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[6b. Dismiss -> hoàn Buyer; Uphold -> giải ngân Seller + ship trả]),
)

=== Bản Ghi Quyết Định Kiến Trúc (Architectural Decision Records - ADR)
Nhóm đã thông qua 4 quyết định kiến trúc cốt lõi dưới đây cho dự án ShopNexus C2C:

==== ADR-01: Lựa chọn Durable Microservices trên Restate thay vì Microservices truyền thống
- *Bối cảnh:* Các luồng liên quan đến tiền (giữ tiền Escrow, hoàn tiền, tranh chấp) diễn ra qua nhiều bước và kéo dài nhiều ngày. Nếu một service bị lỗi hoặc khởi động lại giữa chừng, hệ thống dễ rơi vào trạng thái nửa vời: tiền đã trừ nhưng đơn hàng chưa cập nhật, hoặc một bước bị chạy lại hai lần. Với microservices truyền thống, nhóm phải tự viết thêm nhiều cơ chế phức tạp để chống các lỗi này, rất dễ sai với đội ngũ nhỏ.
- *Quyết định:* Dùng Restate làm nền tảng "thực thi bền" (durable execution) cho các thao tác ghi (thay đổi dữ liệu). Restate ghi lại tiến trình của từng bước, nên khi service phục hồi sau lỗi, luồng sẽ chạy tiếp đúng từ chỗ dừng thay vì làm lại từ đầu. Các thao tác chỉ đọc (xem sản phẩm, tìm kiếm) gọi thẳng service, không đi qua Restate.
- *Lý do:* Restate lo sẵn hai việc khó nhất là không chạy trùng một bước và tự khôi phục sau lỗi, nên nhóm không phải tự viết cơ chế xử lý lỗi thủ công. Điều này giảm nhiều rủi ro và khối lượng code cho nhóm 3 người trong 8 tuần. Đổi lại, mỗi lần đi qua Restate tốn thêm khoảng 50ms, nên nhóm chỉ dùng cho thao tác ghi; thao tác đọc gọi trực tiếp để giữ tốc độ.
- *Hệ quả:* Nhóm cần thời gian học Restate vì đây là công nghệ mới; đồng thời phải phân biệt rõ ngay từ khi thiết kế API đâu là thao tác ghi (đi qua Restate) và đâu là thao tác đọc (gọi thẳng service).

==== ADR-02: Áp dụng mô hình Database-per-service (schema-per-module)
- *Bối cảnh:* Tránh việc các service chia sẻ chung cơ sở dữ liệu dẫn đến phụ thuộc chặt chẽ (tight coupling) và nghẽn kết nối.
- *Quyết định:* Mỗi service sở hữu schema PostgreSQL riêng (`account`, `catalog`, `chat`, `order`...); không service nào truy cập trực tiếp CSDL của service khác, mọi tham chiếu chéo (VD: `account_id` trong schema `order`) là tham chiếu logic, không khai báo khóa ngoại vật lý xuyên schema.
- *Lý do:* Đảm bảo tính độc lập của các dịch vụ, cho phép mỗi module tiến hóa schema độc lập mà không ảnh hưởng module khác.
- *Hệ quả:* Phải gọi qua HTTP/2 (RPC) để lấy thông tin liên quan thay vì SQL JOIN chéo schema; cần đồng bộ dữ liệu tham chiếu (VD: tên sản phẩm hiển thị trong Order) bằng snapshot tại thời điểm giao dịch.

==== ADR-03: Sử dụng NATS JetStream cho giao tiếp bất đồng bộ, Restate xử lý đếm ngược Escrow
- *Bối cảnh:* Luồng thanh toán tạm giữ Escrow cần xử lý nhiều tác vụ bất đồng bộ (thông báo, cập nhật vận đơn) và cần cơ chế đếm ngược tự động giải ngân sau 3 ngày kể từ khi người mua xác nhận nhận hàng.
- *Quyết định:* Dùng NATS JetStream làm Event Bus cho giao tiếp bất đồng bộ giữa các service (thông báo, đồng bộ trạng thái); dùng cơ chế *durable timer* có sẵn của Restate (không phải Delay Message của message broker) để triển khai đếm ngược 3 ngày cho Escrow.
- *Lý do:* Hệ thống không phải sàn event-streaming khối lượng lớn, event bus chủ yếu fan-out thông báo và đồng bộ trạng thái, nên Kafka (nặng, JVM, cấu hình partition/retention phức tạp) là chi phí không tương xứng. NATS JetStream nhẹ (một binary Go), latency thấp nhưng vẫn có persistence + replay theo stream, đủ cho nhu cầu. Đếm ngược Escrow là một phần của luồng nghiệp vụ có trạng thái (stateful) nên giao cho Restate quản lý trực tiếp sẽ đảm bảo tính đúng đắn cao hơn tính năng delay của message broker.
- *Hệ quả:* Vận hành thêm NATS JetStream bên cạnh Restate, nhưng NATS rất nhẹ nên gánh nặng vận hành thấp; tách bạch rõ trách nhiệm: NATS cho "thông báo việc gì đã xảy ra", Restate cho "đảm bảo việc gì chắc chắn sẽ xảy ra đúng lúc".

==== ADR-04: Tìm kiếm ngữ nghĩa bằng pgvector + bge-m3
- *Bối cảnh:* Sàn cần tìm kiếm sản phẩm theo ngữ nghĩa lẫn từ khóa. Một vector DB chuyên biệt (Milvus) cho throughput ANN cao nhất nhưng phải vận hành như một hệ thống riêng, kèm pipeline đồng bộ dữ liệu với PostgreSQL.
- *Quyết định:* Lưu embedding ngay trong PostgreSQL qua extension *pgvector*; sinh embedding bằng model *bge-m3* (dense + sparse) và thực hiện hybrid search + rerank trong một truy vấn SQL.
- *Lý do:* Hệ thống không phải sàn search-heavy, lượng truy vấn không đủ lớn để bù chi phí vận hành một vector DB riêng. pgvector dùng chung transaction, backup và cho phép lọc scalar (danh mục, giá, tồn kho) trong cùng truy vấn, không cần round-trip re-filter. Model bge-m3 sinh cả dense lẫn sparse nên một model duy nhất phủ cả ngữ nghĩa và từ khóa.
- *Hệ quả:* Khi dataset lên tới hàng chục triệu vector, ANN thuần của pgvector sẽ chậm hơn Milvus; nhóm chấp nhận đánh đổi này ở quy mô dự án để bớt một hệ thống phải vận hành. Đổi chiều dim embedding (VD: chuyển sang model khác) là một ALTER migration + re-embed.
