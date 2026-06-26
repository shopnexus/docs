// ============================================================
// slides.typ — Slide thuyết trình môn Phát triển phần mềm hướng dịch vụ
// Đề tài: ShopNexus — sàn TMĐT theo kiến trúc hướng dịch vụ (INT1448)
// Biên dịch: typst compile slides.typ slides.pdf
// ============================================================
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge
#import fletcher.shapes: pill, diamond, ellipse

// --- Bảng màu (đồng bộ với báo cáo) -------------------------
#let c-primary = rgb("#1a1a1a")
#let c-accent = rgb("#b3122b") // đỏ PTIT cho điểm nhấn slide
#let c-soft = rgb("#f0f0f0")
#let c-mid = rgb("#dddddd")
#let c-line = rgb("#999999")

#let font-body = "TeX Gyre Heros" // sans cho slide (dễ đọc khi chiếu)
#let font-mono = "DejaVu Sans Mono"

// --- Cấu hình trang 16:9 ------------------------------------
#set page(
  paper: "presentation-16-9",
  margin: (top: 1.5cm, bottom: 1.1cm, x: 1.6cm),
  fill: white,
)
#set text(font: font-body, size: 16pt, lang: "vi", fill: c-primary)
#set par(leading: 0.62em)
#show raw: set text(font: font-mono, size: 11.5pt)

// --- Danh sách: bullet vuông nhỏ màu accent -----------------
#set list(marker: text(fill: c-accent)[▪], spacing: 0.6em, indent: 0.4em)
#set enum(spacing: 0.6em, indent: 0.4em)

// --- Hàm slide thường ---------------------------------------
#let slide(title, body) = {
  pagebreak(weak: true)
  // Thanh tiêu đề
  block(width: 100%, inset: (bottom: 5pt))[
    #text(size: 23pt, weight: "bold", fill: c-primary)[#title]
    #v(-3pt)
    #line(length: 100%, stroke: 2pt + c-accent)
  ]
  v(6pt)
  set text(size: 16pt)
  body
}

// --- Hàm slide phân mục (section divider) -------------------
#let section-slide(no, title) = {
  pagebreak(weak: true)
  set page(fill: c-primary)
  set align(horizon)
  block(width: 100%, inset: (x: 1cm))[
    #text(size: 22pt, fill: c-accent, weight: "bold")[PHẦN #no]
    #v(4pt)
    #text(size: 40pt, fill: white, weight: "bold")[#title]
  ]
}

// --- Chip nhỏ (badge) ---------------------------------------
#let chip(b) = box(
  fill: c-soft, inset: (x: 6pt, y: 3pt), radius: 3pt,
  stroke: 0.6pt + c-line,
)[#text(size: 14pt)[#b]]

// ============================================================
// SLIDE 1 — MỞ ĐẦU
// ============================================================
#set page(fill: white)
#set align(center + top)
#v(2pt)
#image("assets/PTIT.png", width: 2cm)
#v(3pt)
#text(size: 14pt, weight: "bold")[HỌC VIỆN CÔNG NGHỆ BƯU CHÍNH VIỄN THÔNG] #h(0.6em) #text(size: 12pt, fill: c-line)[· Khoa CNTT2]
#v(8pt)
#text(size: 28pt, weight: "bold", fill: c-accent)[SHOPNEXUS]
#v(1pt)
#text(size: 18pt, weight: "bold")[Ứng dụng thương mại điện tử phát triển theo kiến trúc hướng dịch vụ]
#v(5pt)
#text(size: 13pt)[Môn: *Phát triển phần mềm hướng dịch vụ* (INT1448) #h(1em) · #h(1em) GVHD: *Nguyễn Minh Tâm*]
#v(9pt)
// #table(
//   columns: (auto, auto, 1fr),
//   align: (center + horizon, left + horizon, left + horizon, center + horizon),
//   inset: (x: 10pt, y: 4pt),
//   stroke: 0.6pt + c-line,
//   fill: (_, y) => if y == 0 { c-primary } else { none },
//   table.header(
//     text(fill: white, weight: "bold", size: 13pt)[STT],
//     text(fill: white, weight: "bold", size: 13pt)[Thành viên],
//     text(fill: white, weight: "bold", size: 13pt)[Vai trò / Công việc],
//   ),
// [1], [Đậu Văn Đăng Khoa #text(size: 10pt, fill: c-line)[(N22DCCN040)]], [Thiết kế kiến trúc tổng thể, định nghĩa hợp đồng dịch vụ giữa các module, điều phối workflow với Restate],
// [2], [Nguyễn Tấn Khoa #text(size: 10pt, fill: c-line)[(N22DCCN042)]], [Phân tích nghiệp vụ và mô hình hóa dịch vụ, thiết kế API cho từng module],
// [3], [Hồ Công Toản #text(size: 10pt, fill: c-line)[(N22DCCN086)]], [Hiện thực Saga pattern cho giao dịch phân tán, tổng hợp  liên module (API Composition)],
// )
#v(80pt)

#text(size: 12pt, fill: c-line)[TP. HCM, tháng 6 năm 2026]

// ============================================================
// PHẦN 2 — BÀI TOÁN & NHU CẦU HƯỚNG DỊCH VỤ
// ============================================================
#set align(top + left)
#section-slide(1, [Bài toán & nhu cầu hướng dịch vụ])

#set page(fill: white)
#set align(top + left)
#slide([Bối cảnh & bài toán])[
  #grid(columns: (1.15fr, 1fr), column-gutter: 22pt,
    [
      *ShopNexus* là nền tảng thương mại điện tử C2C, cho phép người dùng mua sắm, đăng bán và giao dịch sản phẩm với nhau trên cùng một tài khoản.
      vừa là người bán.

      *Vòng đời nghiệp vụ phức tạp, ràng buộc tiền bạc - phải đúng tuyệt đối:*
      - Đặt hàng → xác nhận → thanh toán → giao vận → hoàn tiền.
      - Giữ tiền (escrow) 14 ngày, xử lý tranh chấp.
      - Tồn kho an toàn đồng thời, chống bán vượt.
      - Thanh toán đa cổng, tìm kiếm + gợi ý, nhắn tin, khuyến mãi.
    ],
    [
      #align(center)[
        #box(fill: c-soft, inset: 14pt, radius: 6pt, width: 100%)[
          #text(size: 15pt, weight: "bold", fill: c-accent)[Lỗi không được phép]
          #v(4pt)
          #set align(left)
          #set text(size: 15pt)
          - Trừ kho nhưng thanh toán fail
          - Hoàn tiền cộng *hai lần*
          - Bán vượt số lượng tồn
          #v(4pt)
          #text(size: 14pt, style: "italic")[→ Tính *đúng đắn* là yêu cầu phi chức năng số 1.]
        ]
      ]
    ]
  )
]

#slide([Vì sao chọn kiến trúc hướng dịch vụ?])[
  #grid(columns: (1fr, 1fr), column-gutter: 20pt,
    [
      *Nếu làm monolith truyền thống:*
      - Khó mở rộng khi tải cao.
      - Một lỗi có thể làm sập cả hệ thống.
    ],
    [
      *Làm theo hướng dịch vụ:*
      - Tách thành các service độc lập theo từng *bounded context* (account, catalog, order...).
      - Mỗi service một *DB riêng* → loose coupling.
      - Thiết kế để dịch vụ tải nặng (catalog, order) có thể scale riêng biệt, không phụ thuộc vào dịch vụ khác.
      - *Cô lập lỗi:* khi một dịch vụ gặp sự cố, các dịch vụ khác vẫn hoạt động bình thường.”
    ]
  )
  #v(6pt)
  #box(fill: c-soft, inset: 10pt, radius: 5pt, width: 100%)[
    #text(size: 16pt)[*Lựa chọn:* kiến trúc Microservice (backend), tổ chức code trong monorepo — giữ được tính module hóa của microservice mà vẫn đơn giản trong phát triển và triển khai.]
  ]
]

// ============================================================
// PHẦN 3 — KIẾN TRÚC HỆ THỐNG
// ============================================================
#section-slide(2, [Kiến trúc hệ thống SOA / Microservices])

#set page(fill: white)
#slide([Kiến trúc tổng thể])[
  #align(center)[
    #diagram(
      spacing: (16mm, 12mm),
      node-stroke: 0.8pt,
      node-corner-radius: 4pt,
      node((0, 0), [Client \ Web/Mobile], fill: c-soft, width: 34mm),
      node((1.3, 0), [API Gateway], fill: c-mid, width: 40mm),
      edge((0, 0), (1.3, 0), "->", [REST], label-fill: white, label-size: 14pt),
      node((2.7, 0), text(fill: white)[Restate Ingress], fill: c-accent, stroke: none, width: 46mm, inset: 8pt),
      edge((1.3, 0), (2.7, 0), "->"),
      node((0.6, 1.7), [`order`], fill: white),
      node((1.4, 1.7), [`catalog`], fill: white),
      node((2.2, 1.7), [`account`], fill: white),
      node((3.0, 1.7), [`inventory`], fill: white),
      node((3.8, 1.7), [`...`], fill: white),
      edge((2.7, 0), (0.6, 1.7), "->"),
      edge((2.7, 0), (1.4, 1.7), "->"),
      edge((2.7, 0), (2.2, 1.7), "->"),
      edge((2.7, 0), (3.0, 1.7), "->"),
      node((2.2, 2.7), [PostgreSQL (mỗi service 1 database)], shape: pill, fill: c-soft, width: 120mm),
    )
  ]
  #v(2pt)
  #align(center)[#text(size: 15pt, style: "italic")[Mọi inbound traffic (bao gồm external calls và internal calls giữa các service) đều hội tụ về Gateway → Restate Ingress → Service.]]
]

#slide([Database per Service — Loose coupling])[
  #grid(columns: (1fr, 1fr), column-gutter: 20pt,
    [
      *Mỗi Service sở hữu 1 db riêng:*
      - Một Service chỉ Read/Write vào schema của *chính nó*.
      - Muốn dữ liệu dịch vụ khác → *gọi qua interface*, không query trực tiếp.

      #v(4pt)
      *Hệ quả (đặc trưng hướng dịch vụ):*
      - Tự trị dữ liệu (autonomy).
      - Cô lập lỗi
    ],
    [
      #align(center)[
        #diagram(
          spacing: (10mm, 10mm),
          node-stroke: 0.7pt, node-corner-radius: 3pt,
          node((0,0), [`order`], fill: c-soft, width: 26mm),
          node((1,0), [`account`], fill: c-soft, width: 26mm),
          node((0,1), [schema \ `order`], shape: pill, fill: white, width: 26mm),
          node((1,1), [schema \ `account`], shape: pill, fill: white, width: 26mm),
          edge((0,0),(0,1),"->"), edge((1,0),(1,1),"->"),
          edge((0,0),(1,0),"-->", move(dy: -10pt)[gọi qua interface], label-size: 12pt),
        )
      ]
      #v(2pt)
      #align(center)[#text(size: 13pt, style: "italic")[order *không thể* SELECT bảng của account.]]
    ]
  )
]

#slide([Go Interface is source of truth])[
  #grid(columns: (1.1fr, 1fr), column-gutter: 18pt,
    [
      Thay vì SOAP hay gRPC, ShopNexus dùng *Go Interface* làm hợp đồng:
      ```go
      //go:generate genrestate -interface OrderBiz -service Order
      type OrderBiz interface {
        cart.CartBiz
        orderpayment.PaymentBiz
        refund.RefundBiz
        // ...
      }
      ```
      `genrestate` sinh proxy tự động từ interface.
    ],
    [
      *Ưu điểm:*
      - Sai chữ ký xuyên dịch vụ → *compiler bắt lỗi ngay*.
      - 1 source of truth, giảm bớt adapter nếu dùng grpc/SOAP.

      *Tradeoff:* hợp đồng gắn ngôn ngữ Go → phù hợp monorepo đồng nhất; đa ngôn ngữ cần thêm hợp đồng trung lập.
    ]
  )
]

// ============================================================
// PHẦN 4 — GIAO TIẾP & TÍCH HỢP
// ============================================================
#section-slide(3, [Giao tiếp & tích hợp giữa các dịch vụ])

#set page(fill: white)
#slide([Phương thức giao tiếp])[
  #text(size: 17pt)[Mọi lời gọi đi qua *Restate ingress*.]
  #v(6pt)
  #table(
    columns: (2fr, 1fr, 4fr),
    inset: (x: 9pt, y: 7pt),
    stroke: 0.6pt + c-line,
    fill: (_, y) => if y == 0 { c-primary } else { none },
    table.header(
      text(fill: white, weight: "bold")[Mẫu IPC],
      text(fill: white, weight: "bold")[API],
      text(fill: white, weight: "bold")[Dùng khi],
    ),
    [Sync], [`Call()`], [Pause và chờ kết quả, vd: giữ chỗ kho rồi mới thanh toán],
    [Best effort], [`Send()`], [Fire-And-Forget: ghi nhận tương tác, gửi thông báo, ...],
    [Future (giống Promise.allSettled)], [`Future()`], [Chạy đồng thời nhiều tác vụ khác song song rồi gom kết quả],
  )
  #v(6pt)
  #box(fill: c-soft, inset: 10pt, radius: 5pt, width: 100%)[
    #text(size: 15pt)[*Durable execution:* Restate journal lại lời gọi, lỗi tạm thời tự *retry* (1s→30s, 10 lần), crash thì *replay* lại từ journal. *Không cần MessageQueue với DLQ.*]
  ]
]

#slide([Giao tiếp bất đồng bộ qua sự kiện (event-driven)])[
  #grid(columns: (1fr, 1.05fr), column-gutter: 18pt,
    [
      Tác vụ ngoài tới hạn chạy *bất đồng bộ* qua event bus nội bộ:
      - `analytic` phát sự kiện `TopicInteractionCreated`.
      - 2 worker *tự đăng ký* tiêu thụ độc lập.
      - Bên phát *không biết* ai nghe → thêm consumer chỉ là `Subscribe`.

      #text(size: 15pt, style: "italic")[Đây là nền tảng cho CQRS (mô hình đọc cập nhật theo sự kiện).]
    ],
    [
      #align(center)[
        #diagram(
          spacing: (-20mm, 15mm),
          node-stroke: 0.7pt, node-corner-radius: 3pt,
          node((1,0), [Hành vi người dùng], fill: c-soft, width: 40mm),
          node((1,1), text(fill: white)[Event bus \ TopicInteractionCreated], fill: c-accent, stroke: none, width: 70mm),
          edge((1,0),(1,1),"->", [publish], label-size: 12pt),
          node((0,2), [`analytic.popularity` \ → điểm phổ biến], fill: c-mid, width: 62mm),
          node((2,2), [`catalog.search` \ → chỉ mục tìm kiếm], fill: c-mid, width: 42mm),
          edge((1,1),(0,2),"->"), edge((1,1),(2,2),"->"),
        )
      ]
    ]
  )
]

#slide([Saga — giao dịch phân tán])[\
  #grid(columns: (1.1fr, 1fr), column-gutter: 18pt,
    [
      Checkout thay đổi dữ liệu ở *4 dịch vụ* (`order`, `inventory`, `account`, `catalog`). Không thể dùng 1 transaction DB bao quát tất cả.

      *Saga* chia thành chuỗi bước cục bộ, mỗi bước đăng ký một *hành động bù trừ*. Lỗi → chạy bù trừ *LIFO* (vào sau ra trước).

      #v(4pt)
      #text(size: 14pt)[Cấu trúc `Saga` trong ShopNexus:]
      ```go
      saga := saga.New(ctx)
      defer func() {
          if restate.IsTerminalError(err) {
              saga.Compensate() // chạy LIFO
          }
      }()
      ```
    ],
    [
      #text(size: 15pt, weight: "bold")[Cơ chế hoạt động:]
      #v(4pt)
      - `Defer(name, fn)` — đẩy bù trừ vào ngăn xếp.
      - `Compensate()` — pop từ đỉnh, chạy ngược.
      - `Clear()` — xóa ngăn xếp khi thành công.

      #v(6pt)
      #box(fill: c-soft, inset: 8pt, radius: 4pt, width: 100%)[
        #text(size: 14pt)[*Bù trừ bền vững:* mỗi compensator bọc trong `restate.Run(...)` → đã chạy thành công thì journal ghi lại, retry sẽ *skip* bước đó. Lỗi tạm thời → Restate retry toàn workflow, bù trừ tiếp từ bước dang dở.]
      ]
    ]
  )
]

#slide([Saga checkout — các bước bù trừ thực tế])[\
  #text(size: 15pt)[Mỗi bước *đăng ký bù trừ trước*, rồi mới thực hiện hành động:]
  #v(6pt)
  #align(center)[
    #diagram(
      spacing: (6mm, 9mm),
      node-stroke: 0.7pt,
      node-corner-radius: 3pt,
      // Forward path
      node((0, 0), [Xóa giỏ hàng], fill: c-soft, width: 30mm),
      node((1, 0), [Giữ chỗ kho], fill: c-soft, width: 30mm),
      node((2, 0), [Tạo đơn + TX], fill: c-soft, width: 30mm),
      node((3, 0), [Trừ ví], fill: c-soft, width: 28mm),
      node((4, 0), [Thanh toán], fill: c-soft, width: 32mm),
      node((5, 0), text(fill: white)[✓], fill: c-accent, stroke: none, width: 10mm),
      edge((0,0),(1,0),"->"), edge((1,0),(2,0),"->"),
      edge((2,0),(3,0),"->"), edge((3,0),(4,0),"->"),
      edge((4,0),(5,0),"->"),
      // Compensate path
      node((4, 1.3), [Hoàn ví], fill: c-mid, width: 28mm),
      node((3, 1.3), [Đánh fail session], fill: c-mid, width: 34mm),
      node((2, 1.3), [Nhả kho], fill: c-mid, width: 28mm),
      node((1, 1.3), [Khôi phục giỏ], fill: c-mid, width: 30mm),
      node((0, 1.3), [Reject URL], fill: c-mid, width: 28mm),
      edge((4,1.3),(3,1.3),"->"), edge((3,1.3),(2,1.3),"->"),
      edge((2,1.3),(1,1.3),"->"), edge((1,1.3),(0,1.3),"->"),
    )
  ]
  #v(4pt)
  #grid(columns: (1fr, 1fr), column-gutter: 20pt,
    [
      #text(size: 14pt)[
        ```go
        saga.Defer("release_inventory", ...)
        inventory.ReserveInventory(...)
        // Đăng ký bù trước, thực hiện sau
        ```
      ]
    ],
    [
      #text(size: 14pt)[Trên: *đường đi* (forward). Dưới: *đường bù trừ* (compensate, LIFO). Lỗi terminal ở bước nào → bù trừ chạy ngược từ bước ngay trước đó.]
    ]
  )
]


#slide([Tích hợp bên thứ ba])[\
  #grid(columns: (1fr, 1fr), column-gutter: 18pt,
    [
      *Tích hợp bên ngoài:*
      - Cổng thanh toán: *VNPay, SePay, Stripe* (thiết kế theo Factory + Strategy pattern, giúp mở rộng về sau).
      - Vận chuyển: *GHTK*.
      - IPN qua *webhook* → Resolve *Durable Promise* để đánh thức workflow đang chờ.

      #text(size: 15pt, style: "italic")[Không giữ transaction DB mở khi chờ thanh toán]
    ],
    [
      #align(center)[
        #diagram(
          spacing: (15mm, 8.5mm),
          node-stroke: 0.6pt,
          node((0,0), text(fill:white)[Checkout WF], fill: c-accent, stroke: none),
          node((1,0), [Payment \ Gateway], fill: c-soft),
          edge((0,0),(0,3), stroke: (dash:"dashed", paint:c-line)),
          edge((1,0),(1,3), stroke: (dash:"dashed", paint:c-line)),
          edge((0,1),(1,1),"->", [Charge(session)], label-size: 12pt),
          edge((1,2),(0,2),"->", [webhook: paid], label-size: 12pt),
          node((0,3), [Resolve Promise \ → đi tiếp], fill: c-soft, width: 36mm),
        )
      ]
      #v(2pt)
      #align(center)[#text(size: 13pt)[*Saga*: lỗi nghiệp vụ → bù trừ LIFO (hoàn ví → nhả kho → khôi phục giỏ).]]
    ]
  )
]

// ============================================================
// PHẦN 5 — DEMO
// ============================================================
// #section-slide(4, [Demo sản phẩm])


// ============================================================
// PHẦN 6 — KẾT LUẬN
// ============================================================
// #section-slide(5, [Kết luận & hướng phát triển])


// #slide([Hạn chế & hướng tối ưu])[
//   #grid(columns: (1fr, 1fr), column-gutter: 20pt,
//     [
//       *Hạn chế hiện tại:*
//       - Chưa áp dụng CQRS cho toàn bộ hệ thống, hiện tại mới chỉ cho analytic usage
//       - Chưa tích hợp WAF, đây là lổ hổng nghiệm trọng nếu sau này lên production
//       - 
//     ],
//     [
//       *Hướng phát triển:*
//       - Tách gói `contract` chỉ-có-kiểu → deploy dịch vụ thực sự độc lập.
//       - Thêm hợp đồng trung lập (OpenAPI/gRPC) cho đa ngôn ngữ.
//       - *CI/CD* + bảo mật API Gateway (rate-limit, mTLS, WAF).
//       - Tách `catalog`/`order` thành deployment riêng, đo mở rộng ngang.
//     ]
//   )
// ]

#pagebreak(weak: true)
#set page(fill: c-primary)
#set align(center + horizon)
#text(size: 44pt, weight: "bold", fill: white)[Cảm ơn Thầy & Các Bạn]
