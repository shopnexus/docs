// ============================================================
//  style-a4.typ — template TÀI LIỆU A4 (báo cáo tuần, tài liệu nền tảng)
//  Khác với style-quyen.typ: không theo quy chuẩn quyển nộp trường,
//  dùng font sans cho tiêu đề, bố cục gọn để đọc/in nhanh.
//
//  Dùng: #import "../common/style-a4.typ": *
//        #show: a4.with(
//          tieu-de: "BÁO CÁO TIẾN ĐỘ HÀNG TUẦN",
//          phu-de: "TUẦN 1 & TUẦN 2",
//          chay: "Báo cáo tiến độ Tuần 1 & 2",
//        )
// ============================================================
#import "tokens.typ": *
#import "info.typ" as info

// ---- Trang bìa --------------------------------------------
#let bia(tieu-de, phu-de, de-tai) = block(
  width: 100%, height: 100%, stroke: 1.5pt + ink, inset: (x: 20pt, y: 25pt),
)[
  #align(center)[
    #text(size: 11pt, weight: 700)[#info.bo] \
    #text(size: 11pt, weight: 700)[#info.truong] \
    #text(size: 10.5pt, weight: 700)[#info.co-so] \
    #text(size: 10.5pt, weight: 700)[#info.khoa]

    #v(0.2cm)
    #line(length: 30%, stroke: 1pt + ink)
    #v(0.8cm)

    #image("assets/logo-ptit-university.png", width: 3.2cm)

    #v(1cm)
    #text(size: 18pt, weight: 800)[#tieu-de] \
    #text(size: 13pt, weight: 700)[(#phu-de)]

    #v(1.2cm)
    #text(size: 12pt, weight: 700)[ĐỀ TÀI THỰC TẬP:] \
    #v(0.2cm)
    #text(size: 14pt, weight: 800)[#de-tai]
  ]

  #v(2cm)
  #align(center, block(width: 85%)[
    #set text(size: 10.5pt)
    #grid(
      columns: (auto, 1fr), row-gutter: 9pt, column-gutter: 15pt,
      text(weight: 700)[Giảng viên hướng dẫn:], [#info.gvhd],
      text(weight: 700)[Lớp:], [#info.lop],
      text(weight: 700)[Sinh viên thực hiện:], [
        #for (i, sv) in info.sinh-vien.enumerate() [
          #(i + 1). #sv.at(0) — #sv.at(1) #linebreak()
        ]
      ],
    )
  ])

  #v(2cm)
  #align(center)[
    #text(size: 10.5pt, weight: 700)[#info.dia-diem, NĂM #info.nam]
  ]
]

// ---- Template ---------------------------------------------
#let a4(
  tieu-de: "BÁO CÁO TIẾN ĐỘ HÀNG TUẦN",
  phu-de: "",
  chay: "",
  de-tai: info.de-tai-ngan,
  doc,
) = {
  // Chữ & đoạn văn
  set text(font: font-body, size: 11pt, fill: ink, lang: "vi")
  show raw: set text(font: font-mono)
  show raw.where(block: true): it => block(
    width: 100%, fill: rgb("#F6F6F6"), stroke: 0.5pt + hairline,
    inset: (x: 9pt, y: 8pt), radius: 3pt, text(size: 8.5pt, it),
  )
  set par(justify: true, leading: 0.72em, spacing: 1.05em)

  // Tiêu đề & hình/bảng
  set heading(numbering: "1.1.")
  set figure(supplement: [Hình])
  show figure.where(kind: table): set figure(supplement: [Bảng])
  show figure.caption: set text(size: 9pt, fill: muted)

  // Bảng: header xám nhạt, kẻ mảnh, không căn đều chữ bên trong
  set table(inset: (x: 8pt, y: 6pt), stroke: 0.5pt + hairline,
    fill: (x, y) => if y == 0 { headfill } else { white })
  show table: it => { set par(justify: false); it }
  show table.cell.where(y: 0): set text(weight: 700)

  show heading.where(level: 1): it => {
    set text(size: 14pt, weight: 800, font: font-head)
    block(above: 1.8em, below: 0.35em, it.body)
    line(length: 100%, stroke: 1.2pt + ink)
    v(0.55em)
  }
  show heading.where(level: 2): it => block(above: 1.4em, below: 0.55em, {
    set text(size: 12.5pt, weight: 700, font: font-head)
    grid(columns: (auto, 1fr), column-gutter: 8pt,
      counter(heading).display(), it.body)
  })
  show heading.where(level: 3): it => block(above: 1em, below: 0.4em, {
    set text(size: 11pt, weight: 700, style: "italic", font: font-head)
    grid(columns: (auto, 1fr), column-gutter: 6pt,
      counter(heading).display(), it.body)
  })

  set page(paper: "a4", margin: (top: 2.4cm, bottom: 2.2cm, x: 2cm))

  bia(tieu-de, phu-de, de-tai)
  pagebreak()

  // Header / footer cho phần ruột
  set page(
    header: {
      set text(size: 8pt, fill: muted)
      grid(columns: (1fr, auto), align: (left, right),
        [#info.truong-thuong, #info.co-so-ngan],
        [#chay])
      v(-7pt)
      line(length: 100%, stroke: 0.5pt + hairline)
    },
    footer: context {
      set text(size: 8pt, fill: muted)
      line(length: 100%, stroke: 0.5pt + hairline)
      v(2pt)
      grid(columns: (1fr, auto), align: (left, right),
        [Nhóm #info.nhom],
        [Trang #counter(page).get().first() / #counter(page).final().first()])
    },
  )
  counter(page).update(1)

  // Mục lục
  {
    show outline.entry.where(level: 1): it => { v(6pt, weak: true); strong(it) }
    set text(size: 10.5pt)
    block(text(size: 15pt, weight: 800, fill: blue)[Mục lục])
    v(4pt)
    outline(title: none, indent: auto, depth: 3)
  }
  pagebreak()

  doc
}
