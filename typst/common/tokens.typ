// ============================================================
//  tokens.typ — font, bảng màu và helper sơ đồ (nguồn duy nhất)
//  Dùng chung cho cả 3 loại báo cáo: tuần, định kỳ, cuối.
// ============================================================
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import fletcher.shapes: diamond, pill, circle, hexagon

// ---- Font -------------------------------------------------
#let font-body = "TeX Gyre Termes"
#let font-head = "TeX Gyre Heros"
#let font-mono = "DejaVu Sans Mono"
// Quyển nộp trường phải dùng Times New Roman (QĐ 923/QĐ-HV).
// SVN-Times New Roman đi kèm trong common/fonts/; TeX Gyre Termes là
// bản clone cùng metric, dùng làm dự phòng.
#let font-quyen = ("SVN-Times New Roman", "TeX Gyre Termes")

// ---- Bảng màu (đơn sắc học thuật) -------------------------
// Tên gọi giữ theo màu gốc để thân báo cáo không phải sửa;
// tất cả đều ánh xạ về thang xám.
#let ink      = rgb("#1A1A1A")
#let blue     = rgb("#1A1A1A")   // nhấn mạnh   -> gần đen
#let blue-l   = rgb("#FFFFFF")   // nền process -> trắng
#let blue-s   = rgb("#4D4D4D")   // viền        -> xám
#let teal     = rgb("#4D4D4D")
#let teal-l   = rgb("#ECECEC")   // nền terminal -> xám nhạt
#let amber    = rgb("#4D4D4D")
#let amber-l  = rgb("#FFFFFF")   // nền decision -> trắng
#let green    = rgb("#4D4D4D")
#let green-l  = rgb("#ECECEC")
#let red      = rgb("#4D4D4D")
#let red-l    = rgb("#FFFFFF")
#let muted    = rgb("#666666")
#let hairline = rgb("#C9C9C9")
#let soft     = rgb("#FFFFFF")
#let headfill = rgb("#ECECEC")
#let navy     = rgb("#0B2E63")   // chỉ dùng cho bìa màu

// ---- Node sơ đồ (fletcher) --------------------------------
#let nt(p, b, ..a)    = node(p, b, shape: pill, fill: teal-l, stroke: 1pt + teal, ..a)
#let np(p, b, ..a)    = node(p, b, fill: blue-l, stroke: 1pt + blue-s, ..a)
#let nd(p, b, ..a)    = node(p, b, shape: diamond, fill: amber-l, stroke: 1pt + amber, ..a)
#let ng(p, b, ..a)    = node(p, b, fill: green-l, stroke: 1pt + green, ..a)
#let nr(p, b, ..a)    = node(p, b, fill: white,
                             stroke: (paint: ink, thickness: 0.9pt, dash: "dashed"), ..a)
#let ncore(p, b, ..a) = node(p, text(weight: 700, b), fill: rgb("#E4E4E4"),
                             stroke: 1pt + ink, corner-radius: 5pt, extrude: (0, 3), ..a)
#let nact(p, b, ..a)  = node(p, text(size: 8pt, b), shape: circle,
                             fill: teal-l, stroke: 1pt + teal, ..a)

// Co/giãn nội dung cho vừa bề ngang (chống tràn, tránh thừa lề)
#let fitw(body) = layout(sz => {
  let m = measure(body)
  let s = if m.width > 0pt { calc.min(sz.width / m.width, 1.28) } else { 1.0 }
  box(scale(x: s * 100%, y: s * 100%, reflow: true, body))
})

// Sơ đồ fletcher -> figure kind: image để vào "Danh mục các hình"
#let fig(cap, ..diag) = figure(
  block(
    width: 100%, radius: 8pt, fill: soft, stroke: 1pt + hairline, inset: 7pt,
    align(center, fitw({
      set text(size: 10.5pt)
      diagram(
        node-stroke: 1pt, node-corner-radius: 4pt, node-inset: 8pt,
        edge-stroke: 1.1pt + muted, mark-scale: 80%,
        ..diag,
      )
    })),
  ),
  caption: cap,
  kind: image,
)

// Thực thể ERD (ký hiệu chân quạ): #nent((0,0), <e-order>, [ORDER])
#let nent(p, nm, title) = node(p, text(weight: 700, size: 8.5pt, title),
                               shape: pill, fill: blue-l, stroke: 1pt + blue-s, name: nm)

// ---- Sơ đồ trình tự (sequence diagram) --------------------
// Đường sinh (lifeline) dạng nét đứt cho n đối tượng đặt ở hàng y = 0
#let lifelines(n, y0: 0.4, y1: 10) = range(n).map(i =>
  edge((i, y0), (i, y1), stroke: (paint: hairline, dash: "dashed")))
// Thông điệp gọi (liền) và thông điệp trả về (nét đứt)
#let msg(a, b, y, lbl) = edge((a, y), (b, y), "-|>", text(size: 7pt, lbl))
#let rmsg(a, b, y, lbl) = edge((a, y), (b, y), "-|>",
  stroke: (dash: "dashed"), text(size: 7pt, lbl))
// Ghi chú trên đường sinh: mốc durable (nt) hoặc bước thực thi (ng)
#let step(a, y, lbl) = ng((a, y), text(size: 7pt, lbl))
#let durable(a, y, lbl) = nt((a, y), text(size: 7pt, lbl))

// ---- Bảng đặc tả ca sử dụng (fully dressed, UML) ----------
// Dùng: #ucspec("UC-005", "Đặt hàng & Thanh toán Escrow", [Tác nhân chính], [User], ...)
#let ucspec(ma, ten, ..rows) = {
  let r = rows.pos()
  let cells = ()
  for i in range(0, r.len(), step: 2) {
    cells.push(strong(r.at(i)))
    cells.push(r.at(i + 1))
  }
  figure(
    kind: table,
    caption: [Đặc tả ca sử dụng #ma: #ten],
    table(
      columns: (0.34fr, 1fr),
      align: (left + top, left + top),
      fill: (x, y) => if y == 0 { headfill } else if x == 0 { rgb("#F7F7F7") } else { white },
      table.header([Mã ca sử dụng], [#ma — #ten]),
      ..cells,
    ),
  )
}

// Khối ghi chú: viền mảnh, chữ nghiêng
#let note(body) = block(
  width: 100%, inset: (x: 11pt, y: 8pt), radius: 0pt,
  fill: rgb("#F6F6F6"), stroke: 0.5pt + rgb("#9A9A9A"),
)[#text(size: 10pt, style: "italic", body)]

// Khung wireframe
#let wireframe(title, width: 100%, body) = block(
  width: width, stroke: 1.2pt + ink, inset: 10pt, radius: 4pt, fill: white,
  {
    set text(size: 9.5pt)   // giữ bố cục compact, không lệ thuộc cỡ chữ thân
    stack(spacing: 8pt,
      align(center, text(weight: 700, size: 10pt, title)),
      line(length: 100%, stroke: 0.5pt + hairline),
      body,
    )
  },
)

// Tiêu đề mục lớn không đánh số (front/back matter)
#let sechead(title, outlined: true) = heading(level: 1, numbering: none, outlined: outlined)[#title]

// Ảnh mockup: dùng chung đường dẫn, khỏi phải nhớ ../..
#let mockup(name, ..a) = image("assets/mockups/" + name + ".png", ..a)
