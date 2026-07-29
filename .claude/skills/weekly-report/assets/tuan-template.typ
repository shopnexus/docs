// ============================================================
// Báo cáo tiến độ {{KỲ_NGẮN}} — Thực tập tốt nghiệp, đề tài ShopNexus
// Biên dịch (chạy trong typst/): make tuan
// ============================================================
#import "../common/style-a4.typ": *
#show: a4.with(
  tieu-de: "BÁO CÁO TIẾN ĐỘ HÀNG TUẦN",
  phu-de: "{{KỲ_HOA}}",          // ví dụ: TUẦN 8 & TUẦN 9
  chay: "Báo cáo tiến độ {{KỲ_NGẮN}}",  // ví dụ: Tuần 8 & 9
)

= BÁO CÁO TIẾN ĐỘ TUẦN {{N}}: {{TIÊU_ĐỀ_TUẦN}}

// --- Thông tin chung ---------------------------------------
#table(
  columns: (auto, 1fr),
  [Tuần], [{{N}} ({{TỪ_NGÀY}} – {{ĐẾN_NGÀY}})],
  [Nhóm sinh viên], [Đậu Văn Đăng Khoa, Hồ Công Toản, Nguyễn Tấn Khoa],
  [Giảng viên hướng dẫn], [ThS. Nguyễn Đức Thịnh],
)

== Mục tiêu tuần
// Bám theo yêu cầu/định hướng của thầy (manual/teacher_messages.txt).
- {{MỤC_TIÊU_1}}
- {{MỤC_TIÊU_2}}

== Công việc đã thực hiện
// Tổng hợp từ git log + mô tả tay. Mỗi dòng: việc làm → kết quả.
#table(
  columns: (auto, 1fr, auto),
  table.header([Ngày], [Nội dung công việc], [Người thực hiện]),
  [{{NGÀY}}], [{{NỘI_DUNG}}], [{{NGƯỜI}}],
)

== Kết quả đạt được
- {{KẾT_QUẢ_1}}

== Khó khăn và hướng xử lý
- {{KHÓ_KHĂN_1}}

== Kế hoạch tuần sau
- {{KẾ_HOẠCH_1}}

== Nhận xét của giảng viên hướng dẫn
#v(3cm)
