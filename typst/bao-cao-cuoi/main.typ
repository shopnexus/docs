// ============================================================
//  BÁO CÁO THỰC TẬP TỐT NGHIỆP — BẢN CUỐI
//  Biên dịch: make cuoi   (Makefile ở thư mục typst/)
//
//  KHUNG SƯỜN — nội dung các chương đang chờ viết.
//  Nguồn tham chiếu: spec/source-of-truth.typ, bao-cao-dinh-ky/, bao-cao-tuan/
// ============================================================
#import "../common/style-quyen.typ": *

#show: quyen.with(
  tieu-de: ("BÁO CÁO", "THỰC TẬP TỐT NGHIỆP ĐẠI HỌC"),
  chay: "Báo cáo Thực tập tốt nghiệp",
  thoi-diem: "năm 2026",
)

// ---- Phiếu giao đề cương ----------------------------------
#phieu-giao-de-cuong(
  thoi-diem: "năm 2026",
  moc: (
    ("Khảo sát hiện trạng, xác định tầm nhìn và phạm vi đề tài", "Tuần 1-2", "Tài liệu tầm nhìn, phạm vi"),
    ("Phân tích yêu cầu, đặc tả use case và quy tắc nghiệp vụ", "Tuần 3", "Đặc tả yêu cầu"),
    ("Định nghĩa kiến trúc hệ thống và mô hình dữ liệu", "Tuần 4", "Tài liệu kiến trúc, ERD"),
    ("Thiết kế cấp cao và thiết kế chi tiết", "Tuần 5-6", "Hồ sơ thiết kế"),
    ("Hiện thực hóa, kiểm thử và triển khai", "Tuần 7-14", "Mã nguồn, báo cáo kiểm thử"),
  ),
)
#pagebreak()

#muc-luc()
#pagebreak()

#sechead([LỜI CẢM ƠN], outlined: false)

// TODO: viết lời cảm ơn bản cuối.

#pagebreak()

#sechead([DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT], outlined: false)

// TODO: hợp nhất danh mục viết tắt của báo cáo định kỳ lần 1 và lần 2.

#pagebreak()

#danh-muc-bang()
#pagebreak()

#danh-muc-hinh()
#pagebreak()

#sechead([KẾ HOẠCH THỰC HIỆN CÔNG VIỆC NHÓM], outlined: false)

// TODO: bảng phân công cho toàn bộ kỳ thực tập.

// ============================================================
//  RUỘT — đánh số trang Ả Rập
// ============================================================
#set page(numbering: "1")
#counter(page).update(1)

#pagebreak()
#sechead([MỞ ĐẦU])

// TODO: bối cảnh, tính cấp thiết, mục tiêu, phạm vi, phương pháp, kết cấu báo cáo.

// ---- Các chương (template tự ngắt trang trước mỗi chương) --
#include "chapters/01-tong-quan.typ"
#include "chapters/02-co-so-ly-thuyet.typ"
#include "chapters/03-phan-tich-yeu-cau.typ"
#include "chapters/04-thiet-ke-he-thong.typ"
#include "chapters/05-hien-thuc-trien-khai.typ"
#include "chapters/06-kiem-thu-danh-gia.typ"

#pagebreak()
#sechead([KẾT LUẬN VÀ KIẾN NGHỊ])

// TODO: kết quả đạt được, đánh giá, hạn chế, hướng phát triển.

#pagebreak()
#sechead([DANH MỤC TÀI LIỆU THAM KHẢO])

#bibliography("../common/refs.bib", title: none, full: true, style: "ieee")

#pagebreak()
#sechead([PHỤ LỤC])
