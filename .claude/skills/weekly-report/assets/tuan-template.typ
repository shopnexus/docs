// ============================================================
// Báo cáo tuần {{N}} — Thực tập tốt nghiệp
// Đề tài: ShopNexus — sàn TMĐT theo kiến trúc hướng dịch vụ
// Biên dịch (chạy trong typst/): typst compile --root . weekly/tuan-{{NN}}.typ weekly/tuan-{{NN}}.pdf
// ============================================================
#import "../lib/theme.typ": report-theme, c-primary, c-soft, c-line

#show: report-theme
#set page(numbering: "1")

// --- Tiêu đề -----------------------------------------------
#align(center)[
  #text(size: 16pt, weight: "bold", font: "TeX Gyre Heros")[
    BÁO CÁO TUẦN {{N}}
  ]
  #v(0.2em)
  #text(size: 11pt, fill: c-primary)[Thực tập tốt nghiệp — Đề tài ShopNexus]
]
#v(0.8em)

// --- Thông tin chung ---------------------------------------
#table(
  columns: (auto, 1fr),
  [Tuần], [{{N}} ({{TỪ_NGÀY}} – {{ĐẾN_NGÀY}})],
  [Sinh viên], [{{SINH_VIÊN}}],
  [Giảng viên hướng dẫn], [{{GVHD}}],
)

// --- 1. Mục tiêu tuần --------------------------------------
== Mục tiêu tuần
// Bám theo yêu cầu/định hướng của thầy (manual/teacher_messages.txt).
- {{MỤC_TIÊU_1}}
- {{MỤC_TIÊU_2}}

// --- 2. Công việc đã thực hiện -----------------------------
== Công việc đã thực hiện
// Tổng hợp từ git log + mô tả tay. Mỗi dòng: việc làm → kết quả.
#table(
  columns: (auto, 1fr, auto),
  table.header([Ngày], [Nội dung công việc], [Người thực hiện]),
  [{{NGÀY}}], [{{NỘI_DUNG}}], [{{NGƯỜI}}],
)

// --- 3. Kết quả đạt được -----------------------------------
== Kết quả đạt được
- {{KẾT_QUẢ_1}}

// --- 4. Khó khăn & hướng xử lý -----------------------------
== Khó khăn và hướng xử lý
- {{KHÓ_KHĂN_1}}

// --- 5. Kế hoạch tuần sau ----------------------------------
== Kế hoạch tuần sau
- {{KẾ_HOẠCH_1}}

// --- 6. Nhận xét của GVHD (để trống) -----------------------
== Nhận xét của giảng viên hướng dẫn
#v(3cm)
