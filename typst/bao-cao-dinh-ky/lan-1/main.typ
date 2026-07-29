// ============================================================
//  BÁO CÁO ĐỊNH KỲ THỰC TẬP TỐT NGHIỆP ĐẠI HỌC — LẦN 1
//  Biên dịch: make dinh-ky-1   (Makefile ở thư mục typst/)
// ============================================================
#import "../../common/style-quyen.typ": *

#show: quyen.with(
  tieu-de: ("BÁO CÁO ĐỊNH KỲ", "THỰC TẬP TỐT NGHIỆP ĐẠI HỌC"),
  chay: "Báo cáo Định kỳ TTTN Đại học",
  thoi-diem: "tháng 7 năm 2026",
)

// ---- Phiếu giao đề cương ----------------------------------
#phieu-giao-de-cuong(
  thoi-diem: "tháng 07 năm 2026",
  moc: (
    ("", "Tuần 1", ""),
    ("", "Tuần 1-2", ""),
    ("", "Tuần 2-3", ""),
    ("", "Tuần 3-4", ""),
    ("", "Giai đoạn tiếp theo", ""),
  ),
)
#pagebreak()

// ---- Mục lục ----------------------------------------------
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

#v(0.5cm)
#table(
  columns: (2.5cm, 4.5cm, 1fr),
  inset: 8pt,
  align: (left, left, left),
  table.header([*Ký hiệu*], [*Chữ viết tắt đầy đủ*], [*Diễn giải nghĩa tiếng Việt*]),
  [C2C], [Consumer-to-Consumer], [Mô hình thương mại điện tử giữa các cá nhân],
  [SOA], [Service-Oriented Architecture], [Kiến trúc hướng dịch vụ],
  [TMĐT], [Thương mại điện tử], [Hoạt động mua bán hàng hóa trực tuyến],
  [COD], [Cash on Delivery], [Hình thức giao hàng thu tiền tận nơi],
  [Escrow], [Escrow Payment], [Cơ chế thanh toán tạm giữ trung gian],
  [gRPC], [gRPC Remote Procedure Call], [Giao thức truyền thông hiệu năng cao],
  [JWT], [JSON Web Token], [Mã xác thực phân quyền chuẩn JSON],
  [API], [Application Programming Interface], [Giao diện lập trình ứng dụng],
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
  [7], [Phân rã nghiệp vụ, thiết kế Sơ đồ Use Case tổng quát & 13 ca sử dụng cốt lõi], [Cả nhóm], [Tuần 3], [100%],
  [8], [Xây dựng bộ Quy tắc nghiệp vụ (Business Rules) & Đặc tả Yêu cầu NFR/FR theo 7 service], [Cả nhóm], [Tuần 3], [90%],
  [9], [Phân rã Subdomains (DDD) & Thiết kế Kiến trúc Durable Microservices tổng thể], [Cả nhóm], [Tuần 4], [90%],
  [10], [Thiết kế luồng định tuyến CQRS (Restate Ingress vs HTTP/2) & Event Bus NATS], [Đậu Văn Đăng Khoa], [Tuần 4], [100%],
  [11], [Thiết kế danh mục API (gRPC-Gateway, Restate RPC, SSE Realtime) & 4 ADR kiến trúc], [Nguyễn Tấn Khoa, Đậu Văn Đăng Khoa], [Tuần 4], [100%],
  [12], [Thiết kế mô hình dữ liệu ý niệm, ERD & nguyên lý tham chiếu chéo không khóa ngoại], [Cả nhóm], [Tuần 4], [100%],
  [13], [Tổng hợp, hoàn thiện Báo cáo định kỳ lần 1], [Cả nhóm], [Tuần 4], [100%],
)

// ============================================================
//  RUỘT — đánh số trang Ả Rập
// ============================================================
#set page(numbering: "1")
#counter(page).update(1)

#pagebreak()
#sechead([MỞ ĐẦU])

Thương mại điện tử giữa các cá nhân (C2C) tại Việt Nam đang phát triển mạnh mẽ nhưng đối mặt với rào cản lớn về niềm tin giữa người mua và người bán cá nhân. Để khắc phục các hạn chế này, báo cáo trình bày nghiên cứu và thiết kế hệ thống ShopNexus trên nền tảng kiến trúc Microservices bền vững (Durable Microservices).

Phần Mở đầu khái quát bối cảnh thực tiễn, tính cấp thiết của đề tài, các mục tiêu nghiên cứu cụ thể, phạm vi thực hiện cùng phương pháp tiếp cận công nghệ nhằm xây dựng một sàn giao dịch C2C an toàn và hiện đại.

// ---- Các chương (template tự ngắt trang trước mỗi chương) --
#include "chapters/01-tong-quan.typ"
#include "chapters/02-co-so-ly-thuyet.typ"
#include "chapters/03-phan-tich-yeu-cau-thiet-ke.typ"

#pagebreak()
#sechead([KẾT LUẬN VÀ KIẾN NGHỊ])

#v(1cm)
== Kết luận
Báo cáo định kỳ thực tập tốt nghiệp lần 1 đã hoàn thành cơ bản các nội dung nghiên cứu lý thuyết, phân tích yêu cầu nghiệp vụ và thiết kế kiến trúc hệ thống ShopNexus. Các kết quả đạt được bao gồm:
1. Thiết lập thành công mô hình nghiệp vụ Escrow Payment và quy trình xử lý tranh chấp Refund/Dispute minh bạch.
2. Thiết kế kiến trúc Microservices với cơ chế Durable Execution (Restate) bảo đảm tính toàn vẹn dữ liệu.
3. Hoàn thiện mô hình Tìm kiếm Ngữ nghĩa Lai kết hợp pgvector và mô hình nhúng bge-m3.

#v(1cm)
== Kiến nghị & Hướng phát triển
Trong giai đoạn tiếp theo của đợt Thực tập tốt nghiệp, nhóm sẽ tập trung hiện thực hóa mã nguồn (Implementation), triển khai thực tế hệ thống trên môi trường Docker/Kubernetes và tiến hành thử nghiệm đo lường hiệu năng thực tế.

#pagebreak()
#sechead([DANH MỤC TÀI LIỆU THAM KHẢO]) <tai-lieu>

#bibliography("../../common/refs.bib", title: none, full: true, style: "ieee")

#pagebreak()
#sechead([PHỤ LỤC])

#v(3cm)
