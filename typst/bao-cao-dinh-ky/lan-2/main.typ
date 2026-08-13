// ============================================================
//  BÁO CÁO ĐỊNH KỲ THỰC TẬP TỐT NGHIỆP ĐẠI HỌC — LẦN 2
//  Giai đoạn: Thiết kế chi tiết & Lập kế hoạch triển khai (Tuần 5–7)
//  Biên dịch: make dinh-ky-2   (Makefile ở thư mục typst/)
// ============================================================
#import "../../common/style-quyen.typ": *

#show: quyen.with(
  tieu-de: ("BÁO CÁO ĐỊNH KỲ", "THỰC TẬP TỐT NGHIỆP ĐẠI HỌC"),
  chay: "Báo cáo Định kỳ TTTN Đại học",
  thoi-diem: "năm 2026",
)

// ---- Mục lục ----------------------------------------------
// (Số trang La Mã của phần phụ do template `quyen` đặt sẵn)
#muc-luc()
#pagebreak()

// ---- Lời cảm ơn -------------------------------------------
#sechead([LỜI CẢM ƠN], outlined: false)

Chúng em xin chân thành cảm ơn Ban Giám hiệu Học viện Công nghệ Bưu chính Viễn thông Cơ sở tại TP. Hồ Chí Minh cùng quý Thầy, Cô trong Khoa Công nghệ Thông tin đã tạo điều kiện thuận lợi và trang bị những kiến thức nền tảng quý báu cho chúng em trong suốt quá trình học tập và nghiên cứu.

Đặc biệt, chúng em xin gửi lời cảm ơn sâu sắc nhất đến thầy *ThS. Nguyễn Đức Thịnh*, người đã tận tình hướng dẫn, định hướng chuyên môn và đóng góp những ý kiến vô cùng quý báu giúp nhóm hoàn thành báo cáo định kỳ thực tập tốt nghiệp này.

Mặc dù đã có nhiều cố gắng, song do giới hạn về mặt thời gian và kinh nghiệm, báo cáo không tránh khỏi những thiếu sót. Chúng em rất mong nhận được sự góp ý chân thành từ quý Thầy, Cô để đề tài ngày càng hoàn thiện hơn.

#v(1.5cm)
#align(right, block(width: 45%, align(center)[
  *Sinh viên thực hiện* \
  #v(0.5em)
  Đậu Văn Đăng Khoa \
  Hồ Công Toản \
  Nguyễn Tấn Khoa
]))
#pagebreak()

// ---- Danh mục ký hiệu, chữ viết tắt -----------------------
#sechead([DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT], outlined: false)

#table(
  columns: (auto, 1.5fr, 2fr),
  align: (left, left, left),
  table.header([*Viết tắt*], [*Cụm từ đầy đủ*], [*Ý nghĩa*]),
  [ACID], [Atomicity – Consistency – Isolation – Durability], [Bốn tính chất của giao dịch CSDL tin cậy],
  [ADR], [Architectural Decision Record], [Bản ghi quyết định kiến trúc],
  [ANN], [Approximate Nearest Neighbor], [Tìm láng giềng gần đúng (cho tìm kiếm vector)],
  [API], [Application Programming Interface], [Giao diện lập trình ứng dụng],
  [BR], [Business Rule], [Quy tắc nghiệp vụ (đánh mã BR-xxx)],
  [C2C], [Consumer to Consumer], [Giao dịch giữa các cá nhân người dùng],
  [CRUD], [Create – Read – Update – Delete], [Bốn thao tác dữ liệu cơ bản],
  [CSDL], [—], [Cơ sở dữ liệu],
  [DDL], [Data Definition Language], [Ngôn ngữ định nghĩa dữ liệu (SQL tạo bảng/chỉ mục)],
  [DTO], [Data Transfer Object], [Đối tượng truyền dữ liệu request/response],
  [ERD], [Entity–Relationship Diagram], [Sơ đồ thực thể – quan hệ],
  [Escrow], [—], [Cơ chế thanh toán tạm giữ (trung gian) bảo vệ giao dịch],
  [FR], [Functional Requirement], [Yêu cầu chức năng],
  [HNSW], [Hierarchical Navigable Small World], [Cấu trúc chỉ mục cho tìm kiếm ANN],
  [HPA], [Horizontal Pod Autoscaler], [Tự động co giãn số pod trên Kubernetes],
  [JWT], [JSON Web Token], [Chuẩn token xác thực người dùng],
  [MoSCoW], [Must – Should – Could – Won't], [Thang phân loại mức ưu tiên yêu cầu],
  [NFR], [Non-Functional Requirement], [Yêu cầu phi chức năng],
  [ORM], [Object-Relational Mapping], [Ánh xạ đối tượng – quan hệ],
  [OWASP], [Open Web Application Security Project], [Tổ chức chuẩn hóa các rủi ro bảo mật ứng dụng web],
  [PII], [Personally Identifiable Information], [Thông tin định danh cá nhân],
  [RBAC], [Role-Based Access Control], [Kiểm soát truy cập theo vai trò],
  [REQ], [Requirement], [Yêu cầu chức năng (đánh mã REQ-xxx)],
  [RPC], [Remote Procedure Call], [Lời gọi thủ tục từ xa giữa các dịch vụ],
  [RPO], [Recovery Point Objective], [Mục tiêu điểm phục hồi (lượng dữ liệu tối đa có thể mất)],
  [RTO], [Recovery Time Objective], [Mục tiêu thời gian phục hồi sau sự cố],
  [SKU], [Stock Keeping Unit], [Đơn vị lưu kho — biến thể sản phẩm cụ thể],
  [SLA], [Service Level Agreement], [Cam kết mức dịch vụ của bên thứ ba],
  [SPU], [Standard Product Unit], [Đơn vị sản phẩm chuẩn — bài đăng gốc chứa nhiều SKU],
  [SSE], [Server-Sent Events], [Kênh đẩy sự kiện thời gian thực từ máy chủ],
  [TLS], [Transport Layer Security], [Mã hóa dữ liệu trên đường truyền],
  [UC], [Use Case], [Ca sử dụng (đánh mã UC-xxx)],
  [UML], [Unified Modeling Language], [Ngôn ngữ mô hình hóa thống nhất],
  [k3s], [—], [Bản phân phối Kubernetes nhẹ (single-node) cho demo],
)
#pagebreak()

#danh-muc-bang()
#pagebreak()

#danh-muc-hinh()
#pagebreak()

// ---- Kế hoạch thực hiện công việc nhóm --------------------
#sechead([KẾ HOẠCH THỰC HIỆN CÔNG VIỆC NHÓM], outlined: false)

#v(0.5cm)
#table(
  columns: (1.2cm, 1fr, 4cm, 3cm, 2.2cm),
  inset: 7pt,
  align: (center, left, left, center, center),
  table.header([*STT*], [*Nội dung công việc*], [*Người thực hiện*], [*Thời gian*], [*Mức độ*]),
  [1], [Khảo sát bối cảnh, xác định bài toán niềm tin C2C & viết Chương 1], [Cả nhóm], [Tuần 1], [100%],
  [2], [Phân tích các mô hình sàn TMĐT tiêu biểu (Shopee, Chợ Tốt) & rút ra yêu cầu], [Nguyễn Tấn Khoa, Hồ Công Toản], [Tuần 1], [100%],
  [3], [Nghiên cứu kiến trúc SOA, Microservices & triết lý Database-per-service], [Đậu Văn Đăng Khoa, Hồ Công Toản], [Tuần 1 - Tuần 2], [90%],
  [4], [Nghiên cứu Thực thi Bền vững (Durable Execution) với Restate & Saga Pattern], [Đậu Văn Đăng Khoa], [Tuần 1 - 2], [100%],
  [5], [Nghiên cứu Tìm kiếm ngữ nghĩa Hybrid (pgvector + bge-m3) & Gợi ý đa sở thích], [Đậu Văn Đăng Khoa, Hồ Công Toản], [Tuần 2 - Tuần 3], [100%],
  [6], [Phân tích tác nhân, xây dựng Sơ đồ Ngữ cảnh (System Context) & Persona], [Nguyễn Tấn Khoa], [Tuần 3], [100%],
  [7], [Phân rã nghiệp vụ, thiết kế Sơ đồ Use Case tổng quát & danh mục 17 ca sử dụng], [Cả nhóm], [Tuần 3], [100%],
  [8], [Đặc tả chi tiết (fully dressed) 10 ca sử dụng trọng yếu & chuẩn hóa 25 Quy tắc nghiệp vụ], [Nguyễn Tấn Khoa, Hồ Công Toản], [Tuần 3], [100%],
  [9], [Ban hành 51 Yêu cầu chức năng, 29 Yêu cầu phi chức năng định lượng, ma trận CRUD & truy xuất nguồn gốc], [Cả nhóm], [Tuần 3 - Tuần 4], [95%],
  [10], [Mô hình hóa quy trình: 5 sơ đồ hoạt động, sơ đồ trạng thái đơn hàng & 3 sơ đồ trình tự luồng bền], [Đậu Văn Đăng Khoa, Nguyễn Tấn Khoa], [Tuần 4], [100%],
  [11], [Phân rã Subdomains (DDD) & Thiết kế Kiến trúc Durable Microservices tổng thể], [Cả nhóm], [Tuần 4], [90%],
  [12], [Thiết kế luồng định tuyến CQRS (Restate Ingress vs HTTP/2) & Event Bus NATS], [Đậu Văn Đăng Khoa], [Tuần 4], [100%],
  [13], [Thiết kế thành phần phân lớp, sơ đồ lớp cụm Order & ma trận trách nhiệm], [Hồ Công Toản, Đậu Văn Đăng Khoa], [Tuần 4], [100%],
  [14], [Thiết kế danh mục API (gRPC-Gateway, Restate RPC, SSE Realtime) & 4 ADR kiến trúc], [Nguyễn Tấn Khoa, Đậu Văn Đăng Khoa], [Tuần 4], [100%],
  [15], [Thiết kế mô hình dữ liệu ý niệm, ERD & nguyên lý tham chiếu chéo không khóa ngoại], [Cả nhóm], [Tuần 4], [100%],
  [16], [Đặc tả cơ sở dữ liệu vật lý cho 9 lược đồ PostgreSQL], [Cả nhóm], [Tuần 4], [95%],
  [17], [Tổng hợp, hoàn thiện Báo cáo định kỳ lần 2], [Cả nhóm], [Tuần 4], [100%],
)

// ============================================================
//  RUỘT — đánh số trang Ả Rập
// ============================================================
#set page(numbering: "1")
#counter(page).update(1)

#pagebreak()
#sechead([MỞ ĐẦU])

*Bối cảnh và mục đích.* Báo cáo lần 1 đã hoàn thành giai đoạn phân tích yêu cầu và
định nghĩa kiến trúc cho hệ thống ShopNexus — nền tảng TMĐT C2C an toàn trên kiến
trúc *Durable Microservices*. Báo cáo lần 2 tiếp nối bằng việc cụ thể hóa kiến trúc
tổng thể đó thành các bản thiết kế mà lập trình viên có thể trực tiếp hiện thực hóa,
đồng thời lập kế hoạch triển khai chi tiết cho giai đoạn viết mã.

*Tình hình.* Toàn bộ thiết kế trong báo cáo này kế thừa và bám sát các quyết định
kiến trúc đã chốt ở báo cáo lần 1: kiến trúc hướng dịch vụ với Restate cho luồng ghi
bền (durable), mô hình Database-per-service trên PostgreSQL, tìm kiếm ngữ nghĩa bằng
pgvector + bge-m3 và giao tiếp bất đồng bộ qua NATS JetStream.

*Phạm vi.* Báo cáo lần 2 giới hạn ở *giai đoạn thiết kế chi tiết và lập kế hoạch
triển khai*: thiết kế thành phần, API, cơ sở dữ liệu vật lý, bảo mật (thiết kế cấp
cao); sơ đồ lớp, sơ đồ trình tự, giao diện độ trung thực cao, tập lệnh DDL (thiết kế
chi tiết); cùng thuật toán, xử lý lỗi, chiến lược kiểm thử, tiêu chuẩn phát triển và
kế hoạch triển khai. Việc viết mã và vận hành thực tế nằm ngoài phạm vi báo cáo này.

*Phương pháp.* Áp dụng mô hình hóa hướng đối tượng bằng *UML* cho toàn bộ chuỗi phân
tích – thiết kế: sơ đồ ca sử dụng kèm đặc tả *fully dressed*, sơ đồ hoạt động, sơ đồ
trạng thái, sơ đồ trình tự, sơ đồ lớp và sơ đồ thực thể – quan hệ. Yêu cầu được đặc
tả theo cấu trúc nguyên tử "Hệ thống phải…" kèm tiêu chí chấp nhận *Given – When –
Then*, kiểm chứng độ đầy đủ bằng ma trận CRUD và bảo đảm tính truy vết bằng ma trận
truy xuất nguồn gốc. Phần thiết kế áp dụng kiến trúc phân lớp (presentation –
business – data access), đặc tả API và lược đồ CSDL vật lý, thiết kế thuật toán bằng
mã giả và lập kế hoạch theo tác vụ – lịch biểu – đăng ký rủi ro.

*Kết cấu của báo cáo.* Ngoài phần Mở đầu và Kết luận, nội dung gồm ba chương:
- *Chương 1:* Tổng quan.
- *Chương 2:* Cơ sở lý thuyết.
- *Chương 3:* Phân tích yêu cầu và thiết kế hệ thống.

// ---- Các chương (Tuần 1-4) --------------------------------
#include "chapters/01-tong-quan.typ"
#include "chapters/02-co-so-ly-thuyet.typ"
#include "chapters/03-phan-tich-yeu-cau-thiet-ke.typ"

#pagebreak()
// #sechead([KẾT LUẬN VÀ KIẾN NGHỊ])

// *Kết quả đạt được.* Kết thúc giai đoạn hai, nhóm đã hoàn tất toàn bộ hồ sơ phân tích
// và thiết kế của hệ thống ShopNexus. Về *phân tích yêu cầu*: danh mục 17 ca sử dụng
// kèm đặc tả đầy đủ cho 10 ca sử dụng trọng yếu, bộ 25 quy tắc nghiệp vụ đã chuẩn hóa,
// 51 yêu cầu chức năng và 29 yêu cầu phi chức năng định lượng kèm phương pháp kiểm
// chứng, được kiểm tra độ đầy đủ bằng ma trận CRUD và ma trận truy xuất nguồn gốc. Về
// *mô hình hóa*: năm sơ đồ hoạt động, sơ đồ trạng thái vòng đời đơn hàng, ba sơ đồ
// trình tự cho các luồng bền và hai lát cắt sơ đồ thực thể ý niệm. Về *thiết kế*: thành
// phần phân lớp và ma trận trách nhiệm, sơ đồ lớp cụm Order, đặc tả API (khoảng 23
// endpoint, phân loại mutation/query), kiến trúc dữ liệu vật lý với lược đồ – ràng buộc
// – chỉ mục, và thiết kế bảo mật (xác thực JWT, RBAC kèm kiểm tra quyền sở hữu, nhật ký
// kiểm toán). Cuối cùng, nhóm đặc tả ba thuật toán nghiệp vụ cốt lõi, chiến lược xử lý
// lỗi, kế hoạch kiểm thử, tiêu chuẩn phát triển và lịch triển khai tám tuần kèm đăng ký
// rủi ro.

// *Đánh giá.* Cùng với báo cáo lần 1, bộ tài liệu thiết kế đã bao phủ trọn vẹn vòng
// đời phân tích – thiết kế của hệ thống, đảm bảo tính truy vết từ yêu cầu đến thành
// phần, lớp, bảng dữ liệu và endpoint. Đây là cơ sở đầy đủ để bước sang giai đoạn hiện
// thực hóa.

// *Hạn chế.* Các thiết kế mới ở dạng bản vẽ và mã giả, chưa được kiểm chứng qua hiện
// thực đầy đủ; hiệu năng và tính đúng đắn của luồng Escrow durable cần được xác nhận
// bằng nguyên mẫu và kiểm thử thực tế.

// *Kiến nghị và hướng phát triển.* Nhóm kiến nghị triển khai theo lịch biểu tám tuần
// đã đề xuất, ưu tiên dựng sớm nguyên mẫu luồng Escrow trên Restate và bộ mock cho cổng
// thanh toán/vận chuyển để giảm rủi ro tích hợp bên thứ ba; đồng thời bám sát tiêu chuẩn
// phát triển và chiến lược kiểm thử đã đặt ra nhằm đảm bảo chất lượng khi hiện thực hóa
// hệ thống ShopNexus.

// #pagebreak()
#sechead([DANH MỤC TÀI LIỆU THAM KHẢO])

*Tiếng Việt*
+ Quốc hội – Chính phủ nước CHXHCN Việt Nam, _Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân_, Hà Nội, 2023.

*Tiếng Anh*
+ Chris Richardson, _Microservices Patterns: With Examples in Java_, Manning Publications, 2018.
+ Sam Newman, _Building Microservices: Designing Fine-Grained Systems_, 2nd ed., O'Reilly Media, 2021.
+ Robert C. Martin, _Clean Architecture: A Craftsman's Guide to Software Structure and Design_, Prentice Hall, 2017.
+ Alan Beaulieu, _Learning SQL_, 3rd ed., O'Reilly Media, 2020.

*Website tham khảo*
+ Restate — Durable Execution for microservices: #link("https://restate.dev/")[https://restate.dev/].
+ pgvector — Open-source vector similarity search for Postgres: #link("https://github.com/pgvector/pgvector")[github.com/pgvector/pgvector].
