// ============================================================
// theme.typ — cấu hình toàn cục cho báo cáo
// Font, trang, heading, code block (codly), và các helper diagram.
// ============================================================

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
  set page(
    paper: "a4",
    margin: (top: 2.5cm, bottom: 2.5cm, left: 3cm, right: 2.5cm),
    numbering: "1",
    number-align: center,
  )
  set text(font: font-body, size: 12pt, lang: "vi", region: "vn", hyphenate: false)
  set par(justify: true, leading: 0.78em, first-line-indent: (amount: 1.2em, all: false))
  set list(indent: 1em, spacing: 0.7em)
  set enum(indent: 1em, spacing: 0.7em)

  // --- Heading ---------------------------------------------
  set heading(numbering: (..nums) => {
    let n = nums.pos()
    if n.len() == 1 {
      numbering("I.", n.at(0))
    } else {
      numbering("1.1.1.", ..n)
    }
  })
  show heading: set text(font: font-head, fill: c-primary)
  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    align(center)[
      #block(above: 0.4em, below: 0.9em)[
        #set text(size: 18pt, weight: "bold")
        #it
      ]
    ]
  }
  show heading.where(level: 2): set text(size: 14pt)
  show heading.where(level: 3): set text(size: 12.5pt)
  show heading.where(level: 2): set block(above: 1.1em, below: 0.6em)
  show heading.where(level: 3): set block(above: 0.9em, below: 0.5em)

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
