// ============================================================
// cover.typ — Trang bìa
// Môn: Phát triển phần mềm hướng dịch vụ (INT1448) — PTIT.
// Sửa các biến bên dưới nếu cần.
// ============================================================
#import "theme.typ": font-head, font-body, c-primary

#let cover-page(
  bo: "BỘ KHOA HỌC VÀ CÔNG NGHỆ",
  truong: "HỌC VIỆN CÔNG NGHỆ BƯU CHÍNH VIỄN THÔNG",
  loai: "BÁO CÁO ĐỒ ÁN MÔN HỌC",
  mon: "Phát triển phần mềm hướng dịch vụ",
  mamon: "INT1448",
  detai: "ỨNG DỤNG THƯƠNG MẠI ĐIỆN TỬ \nPHÁT TRIỂN THEO KIẾN TRÚC MICROSERVICE",
  gvhd: "Nguyễn Minh Tâm",
  thanhvien: (
    ("Đậu Văn Đăng Khoa", "N22DCCN040"),
    ("Nguyễn Tấn Khoa", "N22DCCN042"),
    ("Hồ Công Toản", "N22DCCN086"),
  ),
  noinop: "TP. HCM",
  thang: "6",
  nam: "2026",
  logo: none,
) = {
  set page(numbering: none, margin: (top: 1cm, bottom: 1cm, x: 1.2cm))
  set text(font: font-body, lang: "vi")
  set align(center)

  // --- Khung ---
  block(
    width: 100%,
    height: 100%,
    stroke: 2pt + black,
    inset: 3pt,
  )[
    #block(
      width: 100%,
      height: 100%,
      stroke: 0.8pt + black,
      inset: (top: 1cm, bottom: 1cm, x: 1.2cm),
    )[
    // --- Header: Bộ + Trường ---
    #v(0.3cm)
    #block(spacing: 0.4em)[
      #text(font: font-head, size: 13pt, weight: "bold")[#bo] \
      #v(0.15em)
      #text(font: font-head, size: 14pt, weight: "bold")[#truong]
    ]

    #v(0.3cm)
    #line(length: 50%, stroke: 1.2pt + black)

    // --- Logo ---
    #v(0.8cm)
    #if logo != none {
      box(width: 4.5cm, logo)
      v(0.6cm)
    }

    // --- Loại báo cáo ---
    #v(0.4cm)
    #text(font: font-head, size: 14pt, weight: "bold")[#loai]

    // --- Đề tài ---
    #v(0.8cm)
    #block(width: 80%)[
      #text(font: font-head, size: 18pt, weight: "bold")[#detai]
    ]

    // --- Thông tin môn học, GVHD, nhóm, thành viên ---
    #v(1.2cm)
    #set align(center)
    #block(width: 76%)[
      #set text(size: 12.5pt)
      #set align(left)

      // Môn học
      #if mon != "" [
        #text(weight: "bold")[Môn học: #if mamon != "" [#mon (#mamon)] else [#mon]] \
      ]

      // GVHD
      #text(weight: "bold")[Giảng viên hướng dẫn: #text(weight: "bold")[#gvhd]] \

      // Nhóm
      #text(weight: "bold")[Thực hiện bởi nhóm sinh viên:]

      // Danh sách thành viên
      #v(0.3em)
      #pad(left: 2em)[
        #grid(
          columns: (1fr, auto),
          row-gutter: 0.6em,
          column-gutter: 2em,
          align: (left, left),
          ..thanhvien.map(tv => (
            text(weight: "bold")[#tv.at(0)],
            text(weight: "bold")[#tv.at(1)],
          )).flatten(),
        )
      ]
    ]

    // --- Footer ---
    #v(1fr)
    #set align(center)
    #text(size: 12pt, weight: "bold")[#upper(noinop), THÁNG #thang NĂM #nam]
    ]
  ]
}
