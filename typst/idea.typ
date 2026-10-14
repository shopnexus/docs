// ============================================================
//  idea.typ — bản gọn của đề xuất đề tài, để đọc và chia sẻ nhanh.
//  Không bìa, không mục lục, không header trường: vào thẳng tiêu đề.
//  Chữ và sơ đồ lấy từ common/tokens.typ nên giống hệt bản nộp;
//  nội dung dùng chung de-xuat-noi-dung.typ nên hai bản không lệch nhau.
//
//  Build:
//    typst compile --root . --font-path common/fonts idea.typ out/idea.pdf
// ============================================================
#import "common/tokens.typ": *

#set page(paper: "a4", margin: (top: 2cm, bottom: 2cm, x: 2cm))

// Chữ & đoạn văn — cùng nấc với style-a4.typ
#set text(font: font-body, size: 11pt, fill: ink, lang: "vi")
#set par(justify: true, leading: 0.72em, spacing: 1.05em)
#set block(spacing: 1.7em)

#show raw: set text(font: font-mono)
#show raw.where(block: true): it => block(
  width: 100%, fill: rgb("#F6F6F6"), stroke: 0.5pt + hairline,
  inset: (x: 9pt, y: 8pt), radius: 3pt, text(size: 8.5pt, it),
)

// Tiêu đề & hình/bảng
#set heading(numbering: "1.1.")
#set figure(supplement: [Hình])
#show figure.where(kind: table): set figure(supplement: [Bảng])
#show figure.caption: set text(size: 9pt, fill: muted)

#set table(inset: (x: 8pt, y: 6pt), stroke: 0.5pt + hairline,
  fill: (x, y) => if y == 0 { headfill } else { white })
#show table: it => { set par(justify: false); it }
#show table.cell.where(y: 0): set text(weight: 700)

// Bản gọn chảy liên tục: tiêu đề cấp 1 không ngắt trang, có số mục như bản nộp.
#show heading.where(level: 1): it => {
  set text(size: 14pt, weight: 800, font: font-head)
  block(above: 1.8em, below: 0.35em,
    grid(columns: (auto, 1fr), column-gutter: 9pt,
      counter(heading).display(), it.body))
  line(length: 100%, stroke: 1.2pt + ink)
  v(0.55em)
}
#show heading.where(level: 2): it => block(above: 1.4em, below: 0.55em, {
  set text(size: 12.5pt, weight: 700, font: font-head)
  grid(columns: (auto, 1fr), column-gutter: 8pt,
    counter(heading).display(), it.body)
})
#show heading.where(level: 3): it => block(above: 1em, below: 0.4em, {
  set text(size: 11pt, weight: 700, style: "italic", font: font-head)
  grid(columns: (auto, 1fr), column-gutter: 6pt,
    counter(heading).display(), it.body)
})

// ---- Đầu trang: chỉ tên đề tài ------------------------------
#block(above: 0pt, below: 0.9em, {
  set text(font: font-head, size: 19pt, weight: 800, fill: ink)
  set par(justify: false, leading: 0.5em)
  [Agent hỗ trợ tìm kiếm và gợi ý sản phẩm \ trên sàn thương mại điện tử C2C]
})
#line(length: 100%, stroke: 1.2pt + ink)

#include "de-xuat-noi-dung.typ"
