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

// Giãn dòng của cả quyển. Phụ lục QĐ 922 đòi line spacing multiple 1,1 đến 1,2; ở cỡ
// chữ 12pt thì 0.7em ứng với khoảng 1,18. Dùng chung cho thân bài và cho mục lục để
// hai chỗ không lệch nhau khi ai đó chỉnh một bên.
#let cach-dong = 0.7em

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
    numbering: none,
    header: none,
    footer: none,
  )
  set align(center)

  // Khung viền kép chuẩn quyển báo cáo
  block(width: 100%, height: 100%, stroke: 2pt + black, inset: 4pt)[
    #block(
      width: 100%,
      height: 100%,
      stroke: 0.8pt + black,
      inset: (top: 1.2cm, bottom: 1.2cm, left: 1.0cm, right: 1.0cm),
    )[
      #text(size: 14pt, weight: "bold")[#info.bo] \
      #v(0.2em)
      #text(size: 16pt, weight: "bold")[#info.truong] \
      #v(0.2em)
      #text(size: 16pt, weight: "bold")[#info.co-so]
      #v(0.3cm)
      #line(length: 40%, stroke: 0.8pt + black)

      #v(0.5cm)
      #image("assets/logo-ptit.png", width: 3.2cm)

      #v(0.7cm)
      #for dong in tieu-de [
        #text(size: 36pt, weight: "bold")[#dong] \
        #v(0.3em)
      ]

      #v(0.8cm)
      #block(width: 92%)[
        #set par(justify: false, leading: 0.65em)
        #text(size: 16pt, weight: "bold")[Đề tài: “#info.de-tai”]
      ]

      #v(1.2cm)
      #align(left)[
        #block(width: 100%, inset: (left: 0.5cm))[
          #set text(size: 13pt, weight: "bold")
          // Tên viết hoa dài hơn tên viết thường, nếu bị ngắt dòng trong ô lưới thì
          // dòng trên còn bị dàn đều chữ. Tắt canh đều ở riêng khối này.
          #set par(justify: false)
          // Dòng nào không có MSSV thì cho ô giá trị trải hết 2 cột, nhờ vậy cột tên
          // chỉ cần vừa tên sinh viên dài nhất và cột MSSV thẳng hàng ở cả 3 dòng.
          #let rong(noi-dung) = grid.cell(colspan: 2, noi-dung)
          #grid(
            columns: (4.3cm, auto, auto),
            row-gutter: 8pt,
            column-gutter: 6pt,
            align: (left, left, left),
            [Người hướng dẫn :], rong[#info.gvhd],
            ..info
              .sinh-vien
              .enumerate()
              .map(((i, sv)) => (
                [Sinh viên #(i + 1) :], [#sv.at(0)], [MSSV: #sv.at(1)],
                [Lớp :], rong[#info.lop],
              ))
              .flatten(),
            [Ngành :], rong[#info.nganh],
          )
        ]
      ]

      #v(1fr)
      #text(size: 13pt, weight: "bold")[#info.dia-diem, #thoi-diem]
    ]
  ]
}

// ---- Template ---------------------------------------------
// `cach-doan` / `cach-khoi`: hai nấc khoảng cách dọc của cả quyển, chỉnh được từ
// phía báo cáo, ví dụ `#show: quyen.with(..., cach-khoi: 14pt)`.
//   cach-doan — giữa hai đoạn văn. Phụ lục QĐ 922 bắt before/after 3pt, tức 6pt,
//               nên đừng đổi trừ khi trường ra quy định mới.
//   cach-khoi — giữa các khối không phải văn xuôi: hình, bảng, danh sách, khối mã,
//               các khối tự dựng. Để rộng hơn cach-doan cho mắt tách được khối ra
//               khỏi mạch chữ. Không đụng tới khoảng cách quanh tiêu đề (tiêu đề tự
//               khai above/below riêng) lẫn khoảng cách bên trong bảng và hình.
#let quyen(
  tieu-de: (),
  chay: "",
  thoi-diem: "",
  cach-doan: 6pt,
  cach-khoi: 12pt,
  doc,
) = {
  set text(font: font-quyen, size: 12pt, fill: ink, lang: "vi")
  show raw: set text(font: font-mono)
  show raw.where(block: true): it => block(
    width: 100%,
    fill: rgb("#F6F6F6"),
    stroke: 0.5pt + hairline,
    inset: (x: 9pt, y: 8pt),
    radius: 3pt,
    text(size: 8.5pt, it),
  )
  // Quy cách đoạn văn theo phụ lục QĐ 922: canh đều hai bên, cách đoạn
  // trước/sau 3pt (tổng 6pt), giãn dòng multiple 1,1–1,2 (leading 0.7em ứng
  // với ~1,18 ở cỡ chữ 12pt), thụt dòng đầu mỗi đoạn 1cm.
  set par(
    justify: true,
    spacing: cach-doan,
    leading: cach-dong,
    first-line-indent: (amount: 1cm, all: true),
  )
  // Thụt dòng chỉ dành cho văn xuôi thân bài: ô bảng, chú thích hình,
  // danh sách gạch đầu dòng và các mục lục đều canh sát lề.
  // Ô bảng KHÔNG canh đều: cụm chữ ngắn bị ngắt dòng (ví dụ "Đạt một phần") sẽ bị
  // kéo giãn rất xấu. Canh đều chỉ áp cho văn xuôi thân bài.
  set block(spacing: cach-khoi)
  show table.cell: set par(justify: false, first-line-indent: 0pt)
  show figure.caption: set par(first-line-indent: 0pt)
  show list: set par(first-line-indent: 0pt)
  show enum: set par(first-line-indent: 0pt)
  show terms: set par(first-line-indent: 0pt)
  show outline: set par(first-line-indent: 0pt)

  // Đánh số: CHƯƠNG n / n.m / n.m.k
  set heading(numbering: (..n) => {
    let p = n.pos()
    if p.len() == 1 { [CHƯƠNG #p.at(0): ] } else { [#p.map(str).join(".") ] }
  })

  // Dấu đầu dòng: cấp 1 dùSng gạch ngang, cấp 2 dùng dấu cộng để hai cấp phân
  // biệt được bằng mắt. Chỉ dùng tối đa 2 cấp; sâu hơn thì viết lại thành văn
  // xuôi hoặc tách mục, không lồng tiếp.
  // Thụt 1cm cho thẳng với dòng đầu của đoạn văn.
  set list(marker: ([-], [+]), indent: 1cm)
  set enum(indent: 1cm)

  // Đánh số hình/bảng theo chương: hình đầu tiên của chương 3 là "Hình 3.1".
  // Bộ đếm hình và bảng được đặt lại ở mỗi tiêu đề chương (xem show rule bên dưới).
  set figure(supplement: [Hình], numbering: n => context {
    let ch = counter(heading).get()
    if ch.len() > 0 and ch.first() > 0 { numbering("1.1", ch.first(), n) } else { numbering("1", n) }
  })
  show figure.where(kind: table): set figure(supplement: [Bảng])
  show figure: set block(breakable: true)
  show figure.caption: set text(size: 10pt, fill: muted)

  set table(inset: (x: 8pt, y: 6pt), stroke: 0.5pt + hairline, fill: (x, y) => if y == 0 { headfill } else { white })
  show table: it => {
    set text(size: 11pt)
    it
  }
  show table.cell.where(y: 0): set text(weight: "bold")

  show heading.where(level: 1): it => {
    if it.numbering != none { pagebreak(weak: true) }
    // Mỗi chương bắt đầu lại từ hình 1 và bảng 1
    counter(figure.where(kind: image)).update(0)
    counter(figure.where(kind: table)).update(0)
    // Phụ lục QĐ 922: "Đề mục của từng chương viết chữ in hoa, in đậm, khổ chữ 13 đến 15".
    // upper() để quy định BẮT BUỘC này do template bảo đảm, không phụ thuộc người viết có
    // gõ hoa hay không. Tiêu đề mục trong chương thì phụ lục chỉ đòi "cũng in đậm, khổ chữ
    // 13" — KHÔNG in hoa, nên cấp 2 giữ nguyên chữ thường.
    block(width: 100%, above: 1.8em, below: 1.2em, align(center, text(size: 14pt, weight: "bold", upper[
      #if it.numbering != none [#context counter(heading).display(it.numbering)]#it.body
    ])))
  }
  show heading.where(level: 2): it => block(width: 100%, above: 1.2em, below: 0.8em, text(size: 13pt, weight: "bold")[
    #if it.numbering != none [#context counter(heading).display(it.numbering)]#it.body
  ])
  show heading.where(level: 3): it => block(width: 100%, above: 1em, below: 0.6em, text(
    size: 12pt,
    weight: "bold",
  )[
    #if it.numbering != none [#context counter(heading).display(it.numbering)]#it.body
  ])
  show heading.where(level: 4): it => block(width: 100%, above: 0.9em, below: 0.5em, text(
    size: 12pt,
    weight: "bold",
  )[#it.body])

  bia(tieu-de: tieu-de, thoi-diem: thoi-diem)
  pagebreak()

  // Phần phụ: có header/footer, chưa đánh số trang
  set page(
    paper: "a4",
    margin: (top: 2.0cm, bottom: 2.0cm, left: 3.0cm, right: 2.0cm),
    // Phụ lục QĐ 922 quy định header/footer cách bìa 1,0cm. Trong Typst hai
    // tham số này là KHOẢNG HỞ giữa header/footer và khối thân bài, nên phải
    // lấy 2,0cm trừ đi 1,0cm và trừ tiếp chiều cao của chính dải header/footer.
    header-ascent: 0.76cm,
    footer-descent: 0.69cm,
    numbering: none,
    header: context block(width: 100%)[
      #set text(font: font-quyen, size: 10pt, weight: "regular")
      #grid(
        columns: (1fr, auto),
        align(left, [#chay]), align(right, tieu-de-chay),
      )
    ],
    footer: context block(width: 100%)[
      #grid(
        columns: (1fr, 1fr),
        align(left, text(font: font-quyen, size: 10pt)[#("Nhóm_" + info.nhom)]),
        align(right, text(font: font-quyen, size: 10pt)[
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
  // Mỗi dòng mục lục là một khối, nên `cach-khoi` của template sẽ nong chúng ra và
  // mục lục phình thêm trang. Mục lục là bảng tra cứu chứ không phải văn xuôi: các
  // dòng chỉ cách nhau đúng một nhịp giãn dòng, còn việc tách nhóm để cho v(0.8em)
  // ở đầu mỗi chương lo.
  show outline.entry: set block(spacing: cach-dong)
  show outline.entry.where(level: 1): it => {
    v(0.8em, weak: true)
    strong(it)
  }
  show outline.entry.where(level: 2): it => strong(it)
  outline(title: [MỤC LỤC], indent: 1.5em, depth: 3)
}
// Danh mục hình/bảng dựng thủ công thay vì dùng `outline`.
// Lý do: số hình đánh theo chương ("Hình 3.1") phải đọc bộ đếm chương TẠI VỊ TRÍ
// của hình. `outline` lại dựng số ở vị trí của chính nó — nằm trong phần đầu quyển,
// nơi bộ đếm chương vẫn bằng 0 — nên mọi mục sẽ mất phần số chương.
#let danh-muc-fig(title, kind, supplement) = {
  sechead(title, outlined: false)
  context {
    for f in query(figure.where(kind: kind)) {
      let loc = f.location()
      let ch = counter(heading).at(loc).first()
      let n = counter(figure.where(kind: kind)).at(loc).first()
      let so = if ch > 0 { numbering("1.1", ch, n) } else { numbering("1", n) }
      block(above: 0.75em, below: 0.75em, width: 100%)[
        #set par(first-line-indent: 0pt, justify: false)
        #link(loc)[#supplement #so #h(0.5em) #f.caption.body
          #box(width: 1fr, inset: (x: 4pt), repeat[.])
          #counter(page).at(loc).first()]
      ]
    }
  }
}
#let danh-muc-bang() = danh-muc-fig([DANH MỤC CÁC BẢNG], table, [Bảng])
#let danh-muc-hinh() = danh-muc-fig([DANH MỤC CÁC HÌNH VẼ], image, [Hình])

#let ink = rgb("#1e293b")
#let mut = rgb("#64748b")
#let line = rgb("#94a3b8")

#let f-kenh = rgb("#eef2f7")
#let f-cong = rgb("#e7eefb")
#let f-mien = rgb("#e9f4ec")
#let f-nen = rgb("#f6f1e4")
#let f-dat = rgb("#eceff3")
#let f-adp = rgb("#f9efe8")
#let f-ext = rgb("#f6eaea")

#let W = 33mm
#let H = 14mm

// hộp mô-đun: tên đậm + dòng chú thích nhỏ
#let m(pos, name, detail: none) = node(
  pos,
  align(center)[
    #text(size: 7pt, weight: "semibold", fill: ink)[#name]
    #if detail != none [ \ #text(size: 5.8pt, fill: mut)[#detail] ]
  ],
  width: W,
  height: H,
  fill: white,
  stroke: 0.6pt + line,
  corner-radius: 2pt,
)

// dải lớp + nhãn dọc ở lề trái
#let layer(y, h, fill, title) = {
  node((1.5, y), [], width: 177mm, height: h, fill: fill, stroke: none, layer: -1)
  node(
    (-0.708, y),
    rotate(-90deg, reflow: true, text(size: 7.5pt, weight: "bold", fill: mut)[#title]),
    stroke: none,
    fill: none,
    layer: -1,
  )
}
