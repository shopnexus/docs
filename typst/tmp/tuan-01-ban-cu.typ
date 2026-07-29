// ============================================================
// Báo cáo tuần 1 — Thực tập tốt nghiệp
// Đề tài: ShopNexus — sàn TMĐT theo kiến trúc hướng dịch vụ
// Biên dịch (chạy trong typst/): typst compile --root . weekly/tuan-01.typ weekly/tuan-01.pdf
// ============================================================
#import "../lib/theme.typ": report-theme, c-primary, c-soft, c-line

#show: report-theme
#set page(numbering: "1")

// --- Tiêu đề -----------------------------------------------
#align(center)[
  #text(size: 16pt, weight: "bold", font: "TeX Gyre Heros")[
    BÁO CÁO TUẦN 1
  ]
  #v(0.2em)
  #text(size: 11pt, fill: c-primary)[Thực tập tốt nghiệp — Đề tài ShopNexus]
]
#v(0.8em)

// --- Thông tin chung ---------------------------------------
#table(
  columns: (auto, 1fr),
  [Tuần], [1 (22/06/2026 – 28/06/2026)],
  [Nhóm sinh viên], [Đậu Văn Đăng Khoa, Nguyễn Tấn Khoa, Hồ Công Toản],
  [Giảng viên hướng dẫn], [ThS. Nguyễn Đức Thịnh],
  [Đề tài], [Nền tảng TMĐT trên kiến trúc hướng dịch vụ (microservices)],
)

// --- 1. Mục tiêu tuần --------------------------------------
== Mục tiêu tuần
Bám giai đoạn *tìm hiểu* theo định hướng của giảng viên:
- Tìm hiểu kiến trúc microservice / hướng dịch vụ và khác biệt so với kiến trúc khối (monolith).
- Khảo sát nghiệp vụ thương mại điện tử: vai trò quản trị viên, người bán, người mua.
- Tìm hiểu và lựa chọn công nghệ cho frontend, backend, cơ sở dữ liệu.
- Khởi tạo kho mã và dựng khung tài liệu báo cáo.

// --- 2. Công việc đã thực hiện -----------------------------
== Công việc đã thực hiện
#table(
  columns: (auto, 1fr, auto),
  table.header([Ngày], [Nội dung công việc], [Người thực hiện]),
  [22/06], [Họp nhóm, nhận đề tài, thống nhất phạm vi và phân công vai trò.], [Cả nhóm],
  [23/06], [Nghiên cứu kiến trúc microservice/SOA, so sánh với monolith (ưu/nhược, ranh giới dịch vụ).], [Đăng Khoa],
  [24/06], [Khảo sát nghiệp vụ TMĐT; xác định tác nhân và nhóm chức năng theo 3 vai trò.], [Tấn Khoa],
  [25/06], [So sánh & chọn công nghệ backend: Go, Restate (điều phối/saga), Echo, PostgreSQL.], [Đăng Khoa, Toản],
  [26/06], [Chọn công nghệ frontend (Next.js) và hướng tìm kiếm theo vector (embedding BGE-M3).], [Tấn Khoa],
  [27/06], [Khởi tạo kho `docs`, dựng khung báo cáo bằng Typst (theme, chương, mục lục).], [Đăng Khoa],
  [27/06], [Tổng hợp kết quả tuần, rà soát định hướng và viết báo cáo tuần 1.], [Cả nhóm],
)

// --- 3. Kết quả đạt được -----------------------------------
== Kết quả đạt được
- Nắm được nguyên lý kiến trúc hướng dịch vụ: mỗi dịch vụ sở hữu dữ liệu riêng, giao tiếp qua hợp đồng, triển khai và mở rộng độc lập.
- Lập bản đồ nghiệp vụ TMĐT: quản trị viên (quản lý tài khoản, nền tảng); người bán (quản lý cửa hàng, đăng bán, khuyến mãi); người mua (tìm kiếm, giỏ hàng, mua, đánh giá).
- Chốt sơ bộ ngăn xếp công nghệ: *Go* cho dịch vụ backend, *Restate* cho điều phối workflow/saga, *Echo* cho transport, *PostgreSQL* cho lưu trữ, *Next.js* cho frontend, *BGE-M3* cho tìm kiếm ngữ nghĩa.
- Khởi tạo kho tài liệu và khung báo cáo Typst, sẵn sàng cho giai đoạn phân tích – thiết kế.

// --- 4. Khó khăn & hướng xử lý -----------------------------
== Khó khăn và hướng xử lý
- Các khái niệm saga, CQRS, DDD còn mới → phân công đọc tài liệu chuyên sâu (Richardson, Erl) và trình bày lại trong nhóm.
- Nhiều lựa chọn công nghệ tương đương → lập tiêu chí so sánh (độ phù hợp với SOA, hệ sinh thái, kinh nghiệm nhóm) để quyết định.

// --- 5. Kế hoạch tuần sau ----------------------------------
== Kế hoạch tuần sau
Chuyển sang giai đoạn *phân tích và thiết kế hệ thống*:
- Phân tích yêu cầu, xây dựng sơ đồ use case cho 3 vai trò.
- Mô hình hóa quy trình nghiệp vụ chính (đăng bán, đặt hàng, thanh toán).
- Thiết kế mô hình dữ liệu (ERD ý niệm) cho các module cốt lõi.

// --- 6. Nhận xét của GVHD (để trống) -----------------------
== Nhận xét của giảng viên hướng dẫn
#v(3cm)
