// ============================================================
//  BÁO CÁO THỰC TẬP TỐT NGHIỆP — LẦN 1
//  Gộp toàn bộ 7 tuần: Phân tích yêu cầu → Thiết kế hệ thống → Kế hoạch triển khai
//  Đề tài: ShopNexus — Nền tảng TMĐT C2C trên kiến trúc hướng dịch vụ
//  Biên dịch (trong typst/baocao12/): typst compile bao-cao-lan-1.typ bao-cao-lan-1.pdf
// ============================================================
#import "style-report.typ": *
#show: report
#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, left: 3cm, right: 2cm))

// ============================================================
//  TRANG BÌA (bìa xanh nước biển)
// ============================================================
#block(width: 100%, height: 100%, stroke: 1.5pt + navy, inset: (x: 22pt, y: 26pt))[
  #align(center)[
    #text(size: 11pt, weight: 700, fill: navy)[BỘ KHOA HỌC VÀ CÔNG NGHỆ] \
    #text(size: 11pt, weight: 700, fill: navy)[HỌC VIỆN CÔNG NGHỆ BƯU CHÍNH VIỄN THÔNG] \
    #text(size: 10.5pt, weight: 700, fill: navy)[CƠ SỞ TẠI THÀNH PHỐ HỒ CHÍ MINH] \
    #text(size: 10.5pt, weight: 700, fill: navy)[KHOA CÔNG NGHỆ THÔNG TIN 2]

    #v(0.2cm)
    #line(length: 30%, stroke: 1pt + navy)
    #v(0.8cm)

    #image("Logo_PTIT_University.png", width: 3.2cm)

    #v(0.9cm)
    #text(size: 19pt, weight: 800, fill: navy)[BÁO CÁO THỰC TẬP TỐT NGHIỆP] \
    #v(0.15cm)
    #text(size: 12.5pt, weight: 700)[(BÁO CÁO LẦN 1 — PHÂN TÍCH, THIẾT KẾ HỆ THỐNG & KẾ HOẠCH TRIỂN KHAI)]

    #v(1cm)
    #text(size: 12pt, weight: 700)[ĐỀ TÀI:] \
    #v(0.2cm)
    #text(size: 15pt, weight: 800, fill: navy)[ShopNexus — Nền tảng Thương mại Điện tử C2C \ trên kiến trúc hướng dịch vụ (Microservices)]
  ]

  #v(1.6cm)
  #align(center, block(width: 88%)[
    #set text(size: 11pt)
    #grid(
      columns: (auto, 1fr),
      row-gutter: 10pt, column-gutter: 15pt,
      text(weight: 700)[Giảng viên hướng dẫn:], [Th.S Nguyễn Đức Thịnh],
      text(weight: 700)[Lớp:], [D22CQCNPM01-N],
      text(weight: 700)[Nhóm sinh viên thực hiện:], [
        1. Đậu Văn Đăng Khoa — N22DCCN040 \
        2. Hồ Công Toản — N22DCCN086 \
        3. Nguyễn Tấn Khoa — N22DCCN042
      ],
    )
  ])

  #v(1fr)
  #align(center)[#text(size: 11pt, weight: 700)[TP. HỒ CHÍ MINH — NĂM 2026]]
]
#pagebreak()

// ============================================================
//  BÌA ĐỆM
// ============================================================
#align(center)[
  #text(size: 10.5pt, weight: 700)[HỌC VIỆN CÔNG NGHỆ BƯU CHÍNH VIỄN THÔNG — CƠ SỞ TP. HỒ CHÍ MINH] \
  #text(size: 10.5pt, weight: 700)[KHOA CÔNG NGHỆ THÔNG TIN 2]
  #v(1.4cm)
  #text(size: 18pt, weight: 800)[BÁO CÁO THỰC TẬP TỐT NGHIỆP] \
  #v(0.2cm)
  #text(size: 12pt, weight: 700)[Báo cáo lần 1 — Phân tích, thiết kế hệ thống & kế hoạch triển khai]
  #v(0.8cm)
  #text(size: 14pt, weight: 800, fill: navy)[Đề tài: ShopNexus — Nền tảng TMĐT C2C \ trên kiến trúc hướng dịch vụ]
  #v(1.4cm)
]
#align(center, block(width: 80%)[
  #set text(size: 11.5pt)
  #grid(columns: (auto, 1fr), row-gutter: 10pt, column-gutter: 14pt,
    text(weight: 700)[Giảng viên hướng dẫn:], [Th.S Nguyễn Đức Thịnh],
    text(weight: 700)[Lớp:], [D22CQCNPM01-N],
    text(weight: 700)[Sinh viên thực hiện:], [
      Đậu Văn Đăng Khoa (N22DCCN040), Hồ Công Toản (N22DCCN086),
      Nguyễn Tấn Khoa (N22DCCN042)
    ],
  )
])
#v(1fr)
#align(center)[#text(size: 11pt, weight: 700)[TP. HỒ CHÍ MINH — NĂM 2026]]
#pagebreak()

// ============================================================
//  ĐÁNH SỐ i, ii… + HEADER/FOOTER (từ Mục lục trở đi)
// ============================================================
#set page(
  numbering: "i",
  header: {
    set text(size: 8.5pt, fill: muted)
    grid(columns: (1fr, auto), align: (left, right),
      [Báo cáo TTTN Đại học], running-right)
    v(-6pt)
    line(length: 100%, stroke: 0.5pt + hairline)
  },
  footer: context {
    set text(size: 8.5pt, fill: muted)
    line(length: 100%, stroke: 0.5pt + hairline)
    v(2pt)
    grid(columns: (1fr, auto), align: (left, right),
      [Nhóm_ShopNexus], counter(page).display())
  },
)
#counter(page).update(1)

// ---- MỤC LỤC ----
#sechead([MỤC LỤC], outlined: false)
#{
  show outline.entry.where(level: 1): it => { v(6pt, weak: true); strong(it) }
  outline(title: none, indent: auto, depth: 3)
}
#pagebreak()

// ---- LỜI CẢM ƠN ----
#sechead([LỜI CẢM ƠN], outlined: false)
Lời đầu tiên, nhóm thực hiện đề tài xin gửi lời cảm ơn chân thành và sâu sắc nhất
đến Th.S Nguyễn Đức Thịnh — giảng viên trực tiếp hướng dẫn. Thầy đã tận tình định
hướng phạm vi đề tài, gợi ý phương pháp phân tích – thiết kế theo hướng dịch vụ và
đưa ra những góp ý quý báu trong suốt kỳ thực tập tốt nghiệp.

Nhóm cũng xin trân trọng cảm ơn quý thầy cô Khoa Công nghệ Thông tin 2 — Học viện
Công nghệ Bưu chính Viễn thông, Cơ sở tại Thành phố Hồ Chí Minh — đã trang bị cho
chúng em nền tảng kiến thức về công nghệ phần mềm, cơ sở dữ liệu, bảo mật và kiến
trúc hệ thống, làm cơ sở để nhóm hoàn thành báo cáo này.

Do kiến thức và kinh nghiệm thực tiễn còn hạn chế, báo cáo không tránh khỏi những
thiếu sót. Nhóm rất mong nhận được sự chỉ bảo, góp ý thêm của quý thầy cô để đề tài
được hoàn thiện hơn khi bước vào giai đoạn hiện thực hóa.

#v(0.6cm)
#align(right)[_TP. Hồ Chí Minh, năm 2026_ \ #text(weight: 700)[Nhóm sinh viên thực hiện]]
#pagebreak()

// ---- DANH MỤC KÝ HIỆU, CHỮ VIẾT TẮT ----
#sechead([DANH MỤC KÝ HIỆU, CHỮ VIẾT TẮT], outlined: false)
#table(
  columns: (auto, 1.5fr, 2fr),
  align: (left, left, left),
  [Viết tắt], [Cụm từ đầy đủ], [Ý nghĩa],
  [ACID], [Atomicity – Consistency – Isolation – Durability], [Bốn tính chất của giao dịch CSDL tin cậy],
  [ADR], [Architectural Decision Record], [Bản ghi quyết định kiến trúc],
  [ANN], [Approximate Nearest Neighbor], [Tìm láng giềng gần đúng (tìm kiếm vector)],
  [API], [Application Programming Interface], [Giao diện lập trình ứng dụng],
  [B2C], [Business to Consumer], [Doanh nghiệp bán cho người tiêu dùng],
  [C2C], [Consumer to Consumer], [Giao dịch giữa các cá nhân người dùng],
  [CQRS], [Command Query Responsibility Segregation], [Tách trách nhiệm lệnh ghi và truy vấn đọc],
  [CRUD], [Create – Read – Update – Delete], [Bốn thao tác dữ liệu cơ bản],
  [CSDL], [—], [Cơ sở dữ liệu],
  [CSKH], [—], [Chăm sóc khách hàng],
  [DDD], [Domain-Driven Design], [Thiết kế hướng miền nghiệp vụ],
  [DDL], [Data Definition Language], [Ngôn ngữ định nghĩa dữ liệu (SQL tạo bảng/chỉ mục)],
  [DTO], [Data Transfer Object], [Đối tượng truyền dữ liệu request/response],
  [ERD], [Entity Relationship Diagram], [Sơ đồ thực thể – liên kết],
  [Escrow], [—], [Cơ chế thanh toán tạm giữ (trung gian) bảo vệ giao dịch],
  [GHN / GHTK], [Giao Hàng Nhanh / Giao Hàng Tiết Kiệm], [Đối tác vận chuyển bên thứ ba],
  [HNSW], [Hierarchical Navigable Small World], [Cấu trúc chỉ mục cho tìm kiếm ANN],
  [HPA], [Horizontal Pod Autoscaler], [Tự động co giãn số pod trên Kubernetes],
  [JWT], [JSON Web Token], [Chuẩn token xác thực người dùng],
  [NFR], [Non-Functional Requirement], [Yêu cầu phi chức năng],
  [ORM], [Object-Relational Mapping], [Ánh xạ đối tượng – quan hệ],
  [PII], [Personally Identifiable Information], [Thông tin định danh cá nhân],
  [RBAC], [Role-Based Access Control], [Kiểm soát truy cập theo vai trò],
  [REQ], [Requirement], [Yêu cầu chức năng (đánh mã)],
  [RPC], [Remote Procedure Call], [Lời gọi thủ tục từ xa giữa các dịch vụ],
  [SLA], [Service Level Agreement], [Cam kết mức dịch vụ của bên thứ ba],
  [SOA], [Service-Oriented Architecture], [Kiến trúc hướng dịch vụ],
  [SePay / VNPay], [—], [Cổng thanh toán trực tuyến],
  [SKU / SPU], [Stock Keeping Unit / Standard Product Unit], [Đơn vị hàng lưu kho / đơn vị sản phẩm chuẩn],
  [SSE], [Server-Sent Events], [Kênh đẩy sự kiện thời gian thực từ máy chủ],
  [SSR / SSG], [Server-Side / Static Site Generation], [Kết xuất trang phía máy chủ / dựng tĩnh],
  [TLS], [Transport Layer Security], [Mã hóa dữ liệu trên đường truyền],
  [TMĐT], [—], [Thương mại điện tử],
  [UC], [Use Case], [Trường hợp sử dụng],
  [WCAG], [Web Content Accessibility Guidelines], [Hướng dẫn khả năng tiếp cận nội dung web],
  [k3s], [—], [Bản phân phối Kubernetes nhẹ (single-node) cho demo],
)
#pagebreak()

// ---- DANH MỤC CÁC BẢNG ----
#sechead([DANH MỤC CÁC BẢNG], outlined: false)
#outline(target: figure.where(kind: table), title: none)
#pagebreak()

// ---- DANH MỤC CÁC HÌNH ----
#sechead([DANH MỤC CÁC HÌNH], outlined: false)
#outline(target: figure.where(kind: image), title: none)
#pagebreak()

// ---- KẾ HOẠCH THỰC HIỆN CÔNG VIỆC NHÓM ----
#sechead([KẾ HOẠCH THỰC HIỆN CÔNG VIỆC NHÓM], outlined: false)
Toàn bộ quá trình thực tập (7 tuần) đi qua ba giai đoạn: phân tích yêu cầu, thiết kế
hệ thống và lập kế hoạch triển khai. Phân công cụ thể như sau:

#table(
  columns: (auto, 2.2fr, 1.3fr, 1fr, auto),
  align: (center, left, left, center, center),
  [TT], [Nội dung công việc], [Người thực hiện], [Thời gian], [Mức độ HT],
  [1], [Khảo sát mô hình C2C, xác định tầm nhìn, mục tiêu, phạm vi; xây dựng persona, bên liên quan và sơ đồ ngữ cảnh.], [Cả nhóm], [Tuần 1], [100%],
  [2], [Mô hình hóa 13 trường hợp sử dụng, các quy trình nghiệp vụ và mô hình dữ liệu ý niệm (ERD, thực thể – quan hệ, quy tắc nghiệp vụ).], [Đăng Khoa, Toản], [Tuần 2], [100%],
  [3], [Trích xuất yêu cầu chức năng (38 REQ), ma trận CRUD và ma trận truy xuất nguồn gốc.], [Đậu Văn Đăng Khoa], [Tuần 3], [100%],
  [4], [Đặc tả yêu cầu phi chức năng (16 NFR) và mô phỏng giao diện (wireframe 10 màn hình, luồng điều hướng).], [Nguyễn Tấn Khoa], [Tuần 3], [100%],
  [5], [Trích xuất thuộc tính chất lượng, ràng buộc; lựa chọn stack công nghệ, phân tích rủi ro.], [Hồ Công Toản], [Tuần 4], [100%],
  [6], [Thiết kế kiến trúc hệ thống (Durable Microservices), sơ đồ tuần tự và bản ghi quyết định kiến trúc (ADR).], [Đậu Văn Đăng Khoa], [Tuần 4], [100%],
  [7], [Thiết kế thành phần phân lớp, thiết kế API và kiến trúc dữ liệu vật lý (ERD vật lý, đặc tả bảng, chỉ mục).], [Cả nhóm], [Tuần 5], [100%],
  [8], [Thiết kế bảo mật (xác thực JWT, RBAC, bảo vệ dữ liệu, audit log).], [Nguyễn Tấn Khoa], [Tuần 5], [100%],
  [9], [Thiết kế lớp, sơ đồ trình tự, giao diện độ trung thực cao và tập lệnh DDL.], [Đăng Khoa, Tấn Khoa], [Tuần 6], [100%],
  [10], [Thiết kế thuật toán nghiệp vụ, chiến lược xử lý lỗi và kiểm thử.], [Hồ Công Toản], [Tuần 7], [100%],
  [11], [Tiêu chuẩn phát triển và lập kế hoạch triển khai (tác vụ, lịch biểu 8 tuần, đăng ký rủi ro).], [Đậu Văn Đăng Khoa], [Tuần 7], [100%],
  [12], [Tổng hợp, biên tập và hoàn thiện báo cáo.], [Cả nhóm], [Tuần 7], [100%],
)
#pagebreak()

// ============================================================
//  ĐÁNH SỐ 1, 2, 3… (từ Mở đầu)
// ============================================================
#set page(numbering: "1")
#counter(page).update(1)

// ---- MỞ ĐẦU ----
#sechead([MỞ ĐẦU], outlined: true)

*Lý do chọn đề tài.* Thị trường giao dịch trực tuyến giữa các cá nhân (C2C) — mua
bán đồ cũ, thanh lý, hàng thủ công — đang phát triển mạnh tại Việt Nam, nhưng vướng
rào cản lớn nhất là *thiếu lòng tin* giữa hai bên: người mua sợ chuyển tiền trước
mà không nhận được hàng đúng mô tả, người bán sợ bị "boom hàng" hoặc khiếu nại gian
lận. Đề tài *ShopNexus* được chọn nhằm xây dựng một nền tảng TMĐT chuyên biệt cho mô
hình C2C an toàn, giải quyết bài toán lòng tin bằng cơ chế thanh toán tạm giữ
(Escrow), nhắn tin – thương lượng tích hợp và quy trình xử lý tranh chấp minh bạch.

*Mục đích nghiên cứu.* Vận dụng quy trình phát triển phần mềm hướng dịch vụ để phân
tích, thiết kế hoàn chỉnh một hệ thống TMĐT C2C theo kiến trúc microservices — từ
khảo sát nghiệp vụ, đặc tả yêu cầu, định nghĩa kiến trúc, thiết kế cấp cao và chi
tiết, cho đến lập kế hoạch triển khai — tạo bộ hồ sơ thiết kế sẵn sàng cho giai đoạn
hiện thực hóa.

*Tình hình nghiên cứu.* Các sàn TMĐT hiện có chủ yếu phục vụ mô hình B2C hoặc C2C
quy mô lớn, ít nền tảng đặt trọng tâm vào cơ chế bảo vệ giao dịch cá nhân (Escrow +
tranh chấp có chứng cứ số). Về kỹ thuật, kiến trúc hướng dịch vụ, mô hình
Database-per-service và các nền tảng thực thi bền (durable execution) đang được ứng
dụng ngày càng rộng cho các luồng nghiệp vụ tài chính dài hạn.

*Phạm vi nghiên cứu.* Báo cáo bao trùm trọn vẹn *giai đoạn phân tích và thiết kế* của
hệ thống: xác định tầm nhìn, người dùng, bối cảnh; mô hình hóa use case và quy trình;
đặc tả yêu cầu chức năng, phi chức năng và mô phỏng giao diện; định nghĩa kiến trúc;
thiết kế cấp cao và chi tiết (thành phần, API, CSDL vật lý, bảo mật, lớp, trình tự,
UI, DDL); cùng kế hoạch triển khai. Việc viết mã và vận hành thực tế nằm ngoài phạm
vi báo cáo.

*Phương pháp nghiên cứu.* Kết hợp nghiên cứu tài liệu về kiến trúc hướng dịch vụ với
phương pháp phân tích – thiết kế hướng đối tượng (use case, ERD, sơ đồ hoạt động, sơ
đồ tuần tự, sơ đồ lớp); áp dụng tư duy ra quyết định kiến trúc có ghi nhận (ADR),
thiết kế thuật toán bằng mã giả và lập kế hoạch theo tác vụ – lịch biểu – rủi ro.

*Kết cấu của báo cáo.* Ngoài phần Mở đầu và Kết luận, nội dung gồm bảy chương:
- *Chương 1:* Khảo sát hiện trạng và xác định tầm nhìn dự án.
- *Chương 2:* Phân tích yêu cầu và thiết kế sơ bộ hệ thống.
- *Chương 3:* Đặc tả yêu cầu và mô phỏng giao diện.
- *Chương 4:* Thiết kế kiến trúc hệ thống.
- *Chương 5:* Thiết kế cấp cao.
- *Chương 6:* Thiết kế chi tiết.
- *Chương 7:* Lập kế hoạch triển khai.

// ============================================================
//  NỘI DUNG CÁC CHƯƠNG (Tuần 1–7)
// ============================================================
#include "body-lan-1.typ"

// ============================================================
//  KẾT LUẬN VÀ KIẾN NGHỊ
// ============================================================
#sechead([KẾT LUẬN VÀ KIẾN NGHỊ], outlined: true)

*Kết quả đạt được.* Qua kỳ thực tập, nhóm đã hoàn thành trọn vẹn giai đoạn phân tích
và thiết kế cho hệ thống ShopNexus. Về phân tích: xác định rõ tầm nhìn, phạm vi và ba
nhóm người dùng (User, Moderator, Admin); mô hình hóa 13 trường hợp sử dụng cùng các
quy trình nghiệp vụ trọng yếu (Escrow, hoàn tiền – tranh chấp, thương lượng qua Offer
Card); trích xuất 38 yêu cầu chức năng và 16 yêu cầu phi chức năng; mô phỏng 10 màn
hình giao diện. Về thiết kế: định nghĩa kiến trúc *Durable Microservices* trên nền
Restate với mô hình Database-per-service (kèm bốn ADR); hoàn thiện thiết kế cấp cao
(thành phần, API, CSDL vật lý, bảo mật) và chi tiết (sơ đồ lớp, sơ đồ trình tự, giao
diện độ trung thực cao, tập lệnh DDL). Về triển khai: đặc tả ba thuật toán nghiệp vụ
cốt lõi, chiến lược xử lý lỗi và kiểm thử, tiêu chuẩn phát triển và lịch triển khai
tám tuần kèm đăng ký rủi ro.

*Đánh giá.* Bộ tài liệu bám sát phương pháp phát triển phần mềm hướng dịch vụ, bảo
đảm tính nhất quán và truy vết được từ yêu cầu → use case → thực thể dữ liệu → thành
phần → lớp, bảng và endpoint. Đây là cơ sở đầy đủ để bước sang giai đoạn hiện thực
hóa.

*Hạn chế.* Các thiết kế mới ở dạng bản vẽ và mã giả, chưa được kiểm chứng qua hiện
thực đầy đủ; hiệu năng và tính đúng đắn của luồng Escrow durable cần được xác nhận
bằng nguyên mẫu và kiểm thử thực tế; một số công nghệ (Restate, bge-m3) còn mới với
nhóm.

*Kiến nghị và hướng phát triển.* Nhóm kiến nghị triển khai theo lịch biểu tám tuần đã
đề xuất, ưu tiên dựng sớm nguyên mẫu luồng Escrow trên Restate và bộ mock cho cổng
thanh toán/vận chuyển để giảm rủi ro tích hợp bên thứ ba; đồng thời bám sát tiêu chuẩn
phát triển và chiến lược kiểm thử đã đặt ra nhằm đảm bảo chất lượng khi hiện thực hóa
hệ thống ShopNexus.

// ============================================================
//  TÀI LIỆU THAM KHẢO
// ============================================================
#sechead([TÀI LIỆU THAM KHẢO], outlined: true)

*Tiếng Việt*
+ Quốc hội – Chính phủ nước CHXHCN Việt Nam, _Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân_, Hà Nội, 2023.

*Tiếng Anh*
+ Chris Richardson, _Microservices Patterns: With Examples in Java_, Manning Publications, 2018.
+ Sam Newman, _Building Microservices: Designing Fine-Grained Systems_, 2nd ed., O'Reilly Media, 2021.
+ Eric Evans, _Domain-Driven Design: Tackling Complexity in the Heart of Software_, Addison-Wesley, 2003.
+ Robert C. Martin, _Clean Architecture: A Craftsman's Guide to Software Structure and Design_, Prentice Hall, 2017.
+ Martin Fowler, _Patterns of Enterprise Application Architecture_, Addison-Wesley, 2002.

*Website tham khảo*
+ Restate — Durable Execution for microservices: #link("https://restate.dev/")[https://restate.dev/].
+ BAAI, _BGE-M3 Embedding Model_: #link("https://huggingface.co/BAAI/bge-m3")[huggingface.co/BAAI/bge-m3].
+ pgvector — Open-source vector similarity search for Postgres: #link("https://github.com/pgvector/pgvector")[github.com/pgvector/pgvector].
+ Web Content Accessibility Guidelines (WCAG) 2.1, W3C: #link("https://www.w3.org/TR/WCAG21/")[w3.org/TR/WCAG21].
