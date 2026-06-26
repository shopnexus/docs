// ============================================================
// Báo cáo môn PHÁT TRIỂN PHẦN MỀM HƯỚNG DỊCH VỤ (INT1448)
// Đề tài: ShopNexus — sàn TMĐT phát triển theo kiến trúc hướng dịch vụ
// Biên dịch: typst compile main.typ main.pdf
// ============================================================
#import "lib/theme.typ": *
#import "lib/cover.typ": cover-page
#import "lib/front.typ": loi-cam-on, bang-phan-cong

// --- Trang bìa ---------------------------------------------
#cover-page(logo: image("assets/PTIT.png"))

// --- Áp dụng theme cho phần còn lại -------------------------
#show: report-theme

// --- Front matter (đánh số La Mã) ---------------------------
#set page(numbering: "i")
#counter(page).update(1)

#loi-cam-on
#pagebreak()

#bang-phan-cong((
  ("Đậu Văn Đăng Khoa", "Thiết kế kiến trúc hướng dịch vụ tổng thể, hợp đồng dịch vụ & điều phối Restate, triển khai"),
  ("Nguyễn Tấn Khoa", "Phân tích & mô hình hóa dịch vụ, thiết kế API và giao tiếp liên dịch vụ."),
  ("Hồ Công Toản", "Saga/giao dịch phân tán, truy vấn tổng hợp liên module (API Composition)."),
))

#pagebreak()

// --- Mục lục ------------------------------------------------
#show outline.entry.where(level: 1): it => {
  v(0.6em, weak: true)
  strong(it)
}
#outline(title: [MỤC LỤC], indent: auto, depth: 3)
#pagebreak()

#outline(title: [DANH MỤC HÌNH], target: figure.where(kind: "diagram"))

// --- Nội dung chính (đánh số Ả Rập) -------------------------
#pagebreak()
#set page(numbering: "1")
#counter(page).update(1)

#include "chapters/01-gioi-thieu.typ"
#include "chapters/02-khai-niem-kien-truc-soa.typ"
#include "chapters/03-lop-dich-vu-mau-thiet-ke.typ"
#include "chapters/04-phan-tich-mo-hinh-hoa.typ"
#include "chapters/05-thiet-ke-api-hop-dong.typ"
#include "chapters/06-giao-tiep-lien-dich-vu.typ"
#include "chapters/07-saga.typ"
#include "chapters/08-logic-nghiep-vu-ddd.typ"
#include "chapters/09-truy-van-cqrs.typ"
#include "chapters/10-api-ben-ngoai.typ"
#include "chapters/11-trien-khai-san-pham.typ"
#include "chapters/12-ket-luan.typ"
#include "chapters/13-tai-lieu-tham-khao.typ"
