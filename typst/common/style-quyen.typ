// ============================================================
//  style-quyen.typ — template QUYỂN BÁO CÁO nộp trường
//  Quy chuẩn: Quyết định 922-210313 (QĐ 923/QĐ-HV)
//  Dùng cho báo cáo định kỳ và báo cáo cuối.
//
//  Dùng: #import "../../common/style-quyen.typ": *
//        #show: quyen.with(tieu-de: ("BÁO CÁO ĐỊNH KỲ", "THỰC TẬP TỐT NGHIỆP ĐẠI HỌC"),
//                          chay: "Báo cáo Định kỳ TTTN Đại học")
//        ... front matter ...
//        #ruot()            <- chuyển sang đánh số trang Ả Rập
// ============================================================
#import "tokens.typ": *
#import "info.typ" as info

// ---- Header động: "CHƯƠNG n: Tên chương" ------------------
#let tieu-de-chay = context {
  let trang = here().page()
  let sau = query(selector(heading.where(level: 1)).after(here()))
  let el = if sau.len() > 0 and sau.first().location().page() == trang {
    sau.first()
  } else {
    let truoc = query(selector(heading.where(level: 1)).before(here()))
    if truoc.len() > 0 { truoc.last() } else { none }
  }
  if el == none {
    []
  } else if el.numbering == none {
    text(weight: "regular", el.body)
  } else {
    let n = counter(heading).at(el.location()).first()
    text(weight: "regular")[CHƯƠNG #n: #el.body]
  }
}

// ---- Trang bìa --------------------------------------------
// `tieu-de`: mảng các dòng tiêu đề lớn, ví dụ ("BÁO CÁO ĐỊNH KỲ", "THỰC TẬP TỐT NGHIỆP ĐẠI HỌC")
#let bia(tieu-de: (), thoi-diem: "") = {
  set page(
    paper: "a4",
    margin: (top: 1.5cm, bottom: 1.5cm, left: 2.5cm, right: 1.5cm),
    numbering: none, header: none, footer: none,
  )
  set align(center)

  // Khung viền kép chuẩn quyển báo cáo
  block(width: 100%, height: 100%, stroke: 2pt + black, inset: 4pt)[
    #block(
      width: 100%, height: 100%, stroke: 0.8pt + black,
      inset: (top: 1.2cm, bottom: 1.2cm, left: 1.0cm, right: 1.0cm),
    )[
      #text(size: 13pt, weight: "bold")[#info.bo] \
      #v(0.2em)
      #text(size: 13pt, weight: "bold")[#info.truong] \
      #v(0.2em)
      #text(size: 13pt, weight: "bold")[#info.co-so]
      #v(0.3cm)
      #line(length: 40%, stroke: 0.8pt + black)

      #v(0.5cm)
      #image("assets/logo-ptit.png", width: 3.2cm)

      #v(0.7cm)
      #for dong in tieu-de [
        #text(size: 21pt, weight: "bold")[#dong] \
        #v(0.3em)
      ]

      #v(0.4cm)
      #block(width: 92%)[
        #set par(justify: false, leading: 0.65em)
        #text(size: 14.5pt, weight: "bold")[Đề tài: “#info.de-tai-hoa”]
      ]

      #v(0.6cm)
      #align(left)[
        #block(width: 100%, inset: (left: 0.5cm))[
          #set text(size: 12.5pt, weight: "bold")
          #grid(
            columns: (4.6cm, 4.5cm, auto),
            row-gutter: 7pt, column-gutter: 4pt, align: (left, left, left),
            [Giảng viên hướng dẫn :], [#info.gvhd], [],
            ..info.sinh-vien.enumerate().map(((i, sv)) => (
              if i == 0 { [Sinh viên thực hiện :] } else { [] },
              [#sv.at(0)], [#sv.at(1)],
            )).flatten(),
            [Lớp :], [#info.lop], [],
            [Ngành :], [#info.nganh], [],
          )
        ]
      ]

      #v(1fr)
      #text(size: 12.5pt, weight: "bold")[#info.dia-diem, #thoi-diem]
    ]
  ]
}

// ---- Phiếu giao đề cương (dùng lại giữa các quyển) --------
#let phieu-giao-de-cuong(moc: (), thoi-diem: "") = {
  align(center)[
    #text(size: 12pt, weight: "bold")[#info.truong] \
    #text(size: 12pt, weight: "bold")[#info.co-so] \
    #v(0.1cm)
    #line(length: 35%, stroke: 0.8pt + black)
    #v(0.3cm)
    #text(size: 14pt, weight: "bold")[PHIẾU GIAO ĐỀ CƯƠNG THỰC TẬP TỐT NGHIỆP]
  ]

  v(0.3cm)
  table(
    columns: (3.2cm, 1fr, 2.0cm, 1fr),
    stroke: 0.5pt + black, inset: 5pt, align: (left, left, left, left),
    [*Mã nhóm*], [#info.nhom], [*Lớp*], [#info.lop],
    [*GV hướng dẫn*], table.cell(colspan: 3)[#info.gvhd],
    ..info.sinh-vien.enumerate().map(((i, sv)) => (
      [*Sinh viên #(i + 1)*], [#sv.at(0)], [*MSSV*], [#sv.at(1)],
    )).flatten(),
  )

  v(0.2cm)
  text(weight: "bold")[1. TÊN ĐỀ TÀI]
  align(center, text(weight: "bold")[#info.de-tai])

  v(0.2cm)
  text(weight: "bold")[2. MỤC TIÊU VÀ NỘI DUNG NGHIÊN CỨU]
  parbreak()
  text(weight: "bold")[3. YÊU CẦU THỰC HIỆN]
  parbreak()
  text(weight: "bold")[4. SẢN PHẨM/KẾT QUẢ DỰ KIẾN]
  parbreak()
  text(weight: "bold")[5. KẾ HOẠCH VÀ MỐC THỜI GIAN]

  v(0.1cm)
  table(
    columns: (1cm, 1fr, 2.8cm, 1fr),
    stroke: 0.5pt + black, inset: 5pt, align: (center, left, center, left),
    table.header([*TT*], [*Nội dung/Mốc công việc*], [*Thời gian*], [*Kết quả cần đạt*]),
    ..moc.enumerate().map(((i, m)) => ([#(i + 1)], m.at(0), m.at(1), m.at(2))).flatten(),
  )

  v(0.4cm)
  align(right, text(style: "italic")[#info.dia-diem, #thoi-diem])

  v(0.2cm)
  grid(
    columns: (1fr, 1fr, 1fr), align: center,
    ..(([ĐẠI DIỆN NHÓM], [SINH VIÊN]), ([GIẢNG VIÊN], [HƯỚNG DẪN]), ([BỘ MÔN/KHOA], [DUYỆT]))
      .map(((a, b)) => [
        #text(weight: "bold")[#a] \
        #text(weight: "bold")[#b] \
        #v(0.1em)
        #text(size: 9pt, style: "italic")[(Ký và ghi rõ họ tên)]
      ]),
  )
}

// ---- Template ---------------------------------------------
#let quyen(tieu-de: (), chay: "", thoi-diem: "", doc) = {
  set text(font: font-quyen, size: 12pt, fill: ink, lang: "vi")
  show raw: set text(font: font-mono)
  show raw.where(block: true): it => block(
    width: 100%, fill: rgb("#F6F6F6"), stroke: 0.5pt + hairline,
    inset: (x: 9pt, y: 8pt), radius: 3pt, text(size: 8.5pt, it),
  )
  set par(justify: true, spacing: 9pt, leading: 0.7em)
  show table.cell: set par(justify: false)

  // Đánh số: CHƯƠNG n / n.m / n.m.k
  set heading(numbering: (..n) => {
    let p = n.pos()
    if p.len() == 1 { [CHƯƠNG #p.at(0): ] } else { [#p.map(str).join(".") ] }
  })

  set figure(supplement: [Hình])
  show figure.where(kind: table): set figure(supplement: [Bảng])
  show figure: set block(breakable: true)
  show figure.caption: set text(size: 10pt, fill: muted)

  set table(inset: (x: 8pt, y: 6pt), stroke: 0.5pt + hairline,
    fill: (x, y) => if y == 0 { headfill } else { white })
  show table: it => { set text(size: 11pt); it }
  show table.cell.where(y: 0): set text(weight: "bold")

  show heading.where(level: 1): it => {
    if it.numbering != none { pagebreak(weak: true) }
    block(width: 100%, above: 1.8em, below: 1.2em, align(center,
      text(size: 14pt, weight: "bold")[
        #if it.numbering != none [#context counter(heading).display(it.numbering)]#it.body
      ]))
  }
  show heading.where(level: 2): it => block(width: 100%, above: 1.2em, below: 0.8em,
    text(size: 13pt, weight: "bold")[
      #if it.numbering != none [#context counter(heading).display(it.numbering)]#it.body
    ])
  show heading.where(level: 3): it => block(width: 100%, above: 1em, below: 0.6em,
    text(size: 12pt, weight: "bold", style: "italic")[
      #if it.numbering != none [#context counter(heading).display(it.numbering)]#it.body
    ])
  show heading.where(level: 4): it => block(width: 100%, above: 0.9em, below: 0.5em,
    text(size: 12pt, weight: "bold")[#it.body])

  bia(tieu-de: tieu-de, thoi-diem: thoi-diem)
  pagebreak()

  // Phần phụ: có header/footer, chưa đánh số trang
  set page(
    paper: "a4",
    margin: (top: 2.0cm, bottom: 2.0cm, left: 3.0cm, right: 2.0cm),
    numbering: none,
    header: context block(width: 100%, inset: (bottom: 2pt))[
      #set text(font: font-quyen, size: 10pt, weight: "regular")
      #grid(
        columns: (1fr, auto),
        align(left, text(style: "italic")[#chay]),
        align(right, tieu-de-chay),
      )
      #v(3pt)
      #line(length: 100%, stroke: 0.5pt + black)
    ],
    footer: context block(width: 100%, inset: (top: 2pt))[
      #line(length: 100%, stroke: 0.5pt + black)
      #v(3pt)
      #grid(
        columns: (1fr, 1fr),
        align(left, text(font: font-quyen, size: 10pt, style: "italic")[Nhóm #info.nhom]),
        align(right, text(font: font-quyen, size: 10pt, weight: "bold")[
          #if page.numbering != none [#counter(page).display(page.numbering)]
        ]),
      )
    ],
  )

  doc
}

// Mục lục + các danh mục chuẩn của quyển
#let muc-luc() = {
  show outline.entry: set text(size: 12pt, weight: "regular")
  show outline.entry.where(level: 1): it => { v(0.8em, weak: true); strong(it) }
  outline(title: text(size: 14pt, weight: "bold")[MỤC LỤC], indent: 1.5em, depth: 3)
}
#let danh-muc-bang() = outline(
  title: text(size: 14pt, weight: "bold")[DANH MỤC CÁC BẢNG],
  target: figure.where(kind: table), indent: 1.5em,
)
#let danh-muc-hinh() = outline(
  title: text(size: 14pt, weight: "bold")[DANH MỤC CÁC HÌNH VẼ],
  target: figure.where(kind: image), indent: 1.5em,
)
