// ============================================================
// theme.typ — cấu hình toàn cục cho báo cáo
// Font, trang, heading, code block (codly), và các helper diagram.
// ============================================================
#import "@preview/fletcher:0.5.2" as fletcher: diagram, node, edge

#import "@preview/codly:1.3.0": *

// --- Thang xám (academic, không màu mè) --------------------
#let c-primary = rgb("#1a1a1a") // mực đen — heading, nhấn mạnh
#let c-accent = rgb("#444444") // xám đậm
#let c-soft = rgb("#f0f0f0") // nền xám nhạt
#let c-mid = rgb("#dddddd") // xám trung
#let c-line = rgb("#999999") // đường kẻ
#let c-ok = rgb("#444444")
#let c-warn = rgb("#444444")

// --- Font ---------------------------------------------------
#let font-body = "TeX Gyre Termes" // serif kiểu Times, phủ tiếng Việt
#let font-head = "TeX Gyre Heros" // sans kiểu Helvetica
#let font-mono = "DejaVu Sans Mono"

// ============================================================
// Hàm áp dụng theme cho toàn tài liệu.
// Dùng: #show: report-theme
// ============================================================
#let report-theme(body) = {
  let running-chapter = context {
    let pg = here().page()
    let hs = query(heading.where(level: 1))
    let cur = none
    for h in hs { if h.location().page() <= pg { cur = h } }
    if cur == none {
      []
    } else if cur.numbering == none {
      text(weight: "regular", cur.body)
    } else {
      let n = counter(heading).at(cur.location()).first()
      text(weight: "regular", [Chương ] + numbering("1", n) + [: ] + text(weight: "regular", cur.body))
    }
  }

  set page(
    paper: "a4",
    margin: (top: 2.5cm, bottom: 2.5cm, left: 3cm, right: 2.5cm),
    numbering: "1",
    header: {
      show text: set text(weight: "regular")
      show strong: set text(weight: "regular")
      set text(font: font-body, size: 9.5pt, fill: c-accent, weight: "regular")
      grid(
        columns: (1fr, auto),
        align: (left, right),
        [Báo cáo TTTN Đại học], text(weight: "regular", running-chapter)
      )
      v(-6pt)
      line(length: 100%, stroke: 0.5pt + c-line)
    },
    footer: context {
      set text(font: font-body, size: 9.5pt, fill: c-accent)
      line(length: 100%, stroke: 0.5pt + c-line)
      v(4pt)
      grid(
        columns: (1fr, auto),
        align: (left, right),
        [Nhóm thực hiện: C22], counter(page).display()
      )
    },
  )
  set text(font: font-body, size: 12pt, lang: "vi", region: "vn", hyphenate: false)
  set par(justify: true, leading: 0.78em, first-line-indent: (amount: 1.2em, all: false))
  set list(indent: 1em, spacing: 0.7em)
  set enum(indent: 1em, spacing: 0.7em)

  // --- Heading ---------------------------------------------
    set heading(numbering: (..nums) => {
      let n = nums.pos()
      if n.len() == 1 {
        "CHƯƠNG " + numbering("1.", n.at(0))
      } else {
        numbering("1.1.1.", ..n)
      }
    })
  show heading: set text(font: font-head, fill: c-primary)
  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    align(center)[
      #block(above: 0.4em, below: 0.9em)[
        #set text(size: 14pt, weight: "bold")
        #it
      ]
    ]
  }
  show heading.where(level: 2): set text(size: 12pt)
  show heading.where(level: 3): set text(size: 12pt)
  show heading.where(level: 2): set block(above: 1em, below: 1em)
  show heading.where(level: 3): set block(above: 1em, below: 1em)

  // --- Liên kết & figure -----------------------------------
  show link: set text(fill: c-primary)
  set figure(gap: 0.9em)
  show figure.caption: set text(size: 10.5pt, style: "italic")
  set figure(numbering: "1")

  // --- Bảng -------------------------------------------------
  set table(
    stroke: 0.6pt + c-line,
    inset: 7pt,
    fill: (_, y) => if y == 0 { c-soft } else { none },
  )
  show table.cell.where(y: 0): set text(fill: black, weight: "bold", font: font-head, size: 10.5pt)
  show table: set par(justify: false, first-line-indent: 0pt)

  // --- Code block (codly) ----------------------------------
  show: codly-init.with()
  codly(
    zebra-fill: none,
    fill: c-soft,
    inset: (x: 0.5em, y: 0.32em),
    radius: 4pt,
    stroke: 0.6pt + c-line,
    number-format: n => text(fill: gray, size: 8pt, str(n)),
  )
  show raw: set text(font: font-mono, size: 9.7pt)

  body
}

// ============================================================
// Helpers
// ============================================================

// Bao một diagram fletcher trong figure có caption.
#let diag(content, caption: none, label: none) = figure(
  align(center, content),
  caption: caption,
  kind: "diagram",
  supplement: [Hình],
)