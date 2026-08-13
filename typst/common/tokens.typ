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

// Nhãn cỡ nhỏ trên cạnh sơ đồ. Đặt ở đây thay vì trong một chương vì cả sơ đồ
// lớp, sơ đồ kiến trúc và sơ đồ phụ thuộc đều cần đúng một cỡ chữ nhãn.
#let rel(t) = text(size: 6.6pt, t)

// ---- Băng tầng cho sơ đồ kiến trúc luận lý ------------------
// Một tầng là MỘT nút fletcher rộng cố định, bên trong xếp các con nêm thành
// lưới. Làm vậy thay vì mỗi thành phần một nút để các tầng thẳng hàng tuyệt
// đối, không tầng nào tự co giãn theo số thành phần của nó.
#let chip(b) = box(
  fill: white, stroke: 0.7pt + blue-s, radius: 3pt,
  inset: (x: 5pt, y: 3.5pt), text(size: 7.6pt, b),
)
#let band(p, ten, chips, cot: auto, ghi: none, rong: 140mm, nen: soft, ..a) = node(
  p,
  stack(
    spacing: 5.5pt,
    text(size: 9.5pt, weight: 700, ten),
    grid(
      columns: if cot == auto { chips.len() } else { cot },
      column-gutter: 5pt, row-gutter: 4pt,
      ..chips.map(chip),
    ),
    ..if ghi == none { () } else {
      (text(size: 7.2pt, fill: muted, ghi),)
    },
  ),
  width: rong, fill: nen, stroke: 1pt + ink, corner-radius: 5pt, inset: 8pt, ..a,
)

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

// Nhãn thông điệp: nền trắng để không dính vào đường sinh nét đứt,
  // cỡ chữ theo tỉ lệ cỡ nền của sơ đồ nên chỉ cần một chỗ để phóng to.
  #let lbl(body) = box(fill: white, inset: (x: 3.5pt, y: 2pt), text(size: 0.7em, body))
  #let msg(a, b, y, l)  = edge((a, y), (b, y), "-|>", lbl(l))
  #let rmsg(a, b, y, l) = edge((a, y), (b, y), "-|>", stroke: (dash: "dashed"), lbl(l))
  #let step(a, y, l)    = ng((a, y), text(size: 0.7em, l))
  #let durable(a, y, l) = nt((a, y), text(size: 0.7em, l))

// ---- Sơ đồ xoay ngang, chiếm trọn một trang ---------------
  // Cạnh dài của trang thành BỀ NGANG của sơ đồ.
  // goc: 90deg xoay theo chiều kim đồng hồ; -90deg lật chiều đọc.
  #let fig-xoay(cap, goc: 90deg, chua: 10mm, co: 13pt, ..diag) = page(margin: 16mm, layout(sz => {
    let ngang = sz.height - chua   // bề ngang sơ đồ, nằm theo chiều dọc trang
    let cao   = sz.width  - chua   // bề cao sơ đồ, nằm theo chiều ngang trang
    let vien  = 16pt               // inset 7pt × 2 + viền

    // (1) Đo sơ đồ ở kích thước TỰ NHIÊN. Không bọc trong block có width:
    //     block width cố định làm `measure` trả về đúng width đó và che mất
    //     phần nội dung tràn ra ngoài — chính là lỗi tràn dọc sau khi xoay.
    let than = {
      set text(size: co)      // thay cho 10.5pt
      diagram(
        node-stroke: 1pt, node-corner-radius: 4pt, node-inset: 8pt,
        edge-stroke: 1.1pt + muted, mark-scale: 80%,
        ..diag,
      )
    }
    let m1 = measure(than)
    let s1 = calc.min((ngang - vien) / m1.width, (cao - vien) / m1.height, 1.28)

    // (2) Lắp thành figure bề ngang cố định rồi đo lại: nội dung đã nằm gọn
    //     trong khối nên số đo trung thực, tính cả chú thích hình.
    let hinh = figure(
      block(width: ngang, radius: 8pt, fill: soft, stroke: 1pt + hairline, inset: 7pt,
        align(center, box(scale(x: s1 * 100%, y: s1 * 100%, reflow: true, than)))),
      caption: cap, kind: image,
    )
    let khung = box(width: ngang, hinh)
    let s2 = calc.min(cao / measure(khung).height, 1.0)

    block(width: 100%, height: ngang * s2, spacing: 0pt,
      place(center + horizon, rotate(goc, reflow: false,
        box(scale(x: s2 * 100%, y: s2 * 100%, reflow: true, khung)))))
  }))

// Thực thể ERD (ký hiệu chân quạ): #nent((0,0), <e-order>, [ORDER])
#let nent(p, nm, title) = node(p, text(weight: 700, size: 8.5pt, title),
                               shape: pill, fill: blue-l, stroke: 1pt + blue-s, name: nm)

// ---- Vùng ngữ cảnh cho BẢN ĐỒ NGỮ CẢNH GIỚI HẠN ----------
// Mỗi vùng là một ngữ cảnh giới hạn: ngăn trên ghi tên ngữ cảnh, ngăn dưới liệt kê
// các aggregate mà nó làm chủ. Aggregate là cụm dữ liệu phải nhất quán với nhau trong
// cùng một giao dịch, nên ranh giới aggregate cũng chính là ranh giới nhất quán mạnh.
#let nvung(p, nm, ten, ..agg) = node(
  p,
  align(left, stack(
    dir: ttb, spacing: 3.4pt,
    text(weight: 700, size: 8.2pt, ten),
    line(length: 100%, stroke: 0.5pt + hairline),
    ..agg.pos().map(a => text(size: 7pt, a)),
  )),
  shape: rect, fill: blue-l, stroke: (paint: ink, thickness: 1pt, dash: "dashed"),
  inset: 6pt, corner-radius: 4pt, name: nm,
)

// ---- Ô bảng cho SƠ ĐỒ CƠ SỞ DỮ LIỆU (database diagram) ----
// Khác `nent` của sơ đồ ERD: ô hình chữ nhật chia 2 ngăn, ngăn trên là tên bảng,
// ngăn dưới liệt kê khoá chính, khoá ngoại kèm hành vi tham chiếu và ràng buộc duy
// nhất. Đây là thứ phân biệt sơ đồ cơ sở dữ liệu với sơ đồ thực thể quan hệ: ERD nói
// hệ thống có những khái niệm gì, còn sơ đồ này nói chúng được lưu ra sao.
#let nbang(p, nm, ten, ..dong) = node(
  p,
  align(left, stack(
    dir: ttb, spacing: 3.2pt,
    text(weight: 700, size: 7.6pt, raw(ten)),
    line(length: 100%, stroke: 0.5pt + hairline),
    ..dong.pos().map(d => text(size: 6.4pt, d)),
  )),
  shape: rect, fill: white, stroke: 0.9pt + blue-s, inset: 4.5pt, name: nm,
)

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

// ---- Khung tổ hợp (combined fragment) của sơ đồ trình tự ---
// UML dùng khung này để thể hiện nhánh có điều kiện: `alt` cho hai nhánh loại trừ
// nhau, `opt` cho nhánh có thể không chạy, `loop` cho vòng lặp. Nhãn loại khung nằm
// ở góc trên bên trái, điều kiện của mỗi nhánh đặt trong ngoặc vuông.
//   khung  bao quanh vùng từ đường sinh a tới b, giữa hai mốc y1 và y2
//   dkien  ghi điều kiện của một nhánh, đặt ngay dưới mép trên hoặc dưới vạch ngăn
//   ngan   vạch nét đứt ngăn hai nhánh của khung alt
#let khung(loai, a, b, y1, y2) = (
  node(enclose: ((a, y1), (b, y2)), inset: 13pt, stroke: 0.7pt + muted,
       fill: none, corner-radius: 0pt),
  node((a, y1), box(fill: white, inset: (x: 3pt, y: 1pt),
       text(size: 6.5pt, weight: 700, loai)), stroke: none, fill: none),
)
#let dkien(a, y, dk) = node((a, y), box(fill: white, inset: (x: 2.5pt, y: 1pt),
  text(size: 6.5pt, style: "normal")[\[#dk\]]), stroke: none, fill: none)
#let ngan(a, b, y) = edge((a, y), (b, y), "-",
  stroke: (paint: muted, dash: "dashed", thickness: 0.6pt))

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
      table.header([Mã ca sử dụng], [#ma: #ten]),
      ..cells,
    ),
  )
}

// ---- Bảng đặc tả ca kiểm thử (test case, fully dressed) ---
// Cùng khuôn với ucspec: chương kiểm thử có nhiều ca đặc tả đầy đủ nên bảng
// phải giống nhau tuyệt đối, không để mỗi ca một bề rộng cột.
#let tcspec(ma, ten, ..rows) = {
  let r = rows.pos()
  let cells = ()
  for i in range(0, r.len(), step: 2) {
    cells.push(strong(r.at(i)))
    cells.push(r.at(i + 1))
  }
  figure(
    kind: table,
    caption: [Đặc tả ca kiểm thử #ma: #ten],
    table(
      columns: (0.3fr, 1fr),
      align: (left + top, left + top),
      fill: (x, y) => if y == 0 { headfill } else if x == 0 { rgb("#F7F7F7") } else { white },
      table.header([Mã ca kiểm thử], [#ma: #ten]),
      ..cells,
    ),
  )
}

// Khối ghi chú: viền mảnh
#let note(body) = block(
  width: 100%, inset: (x: 11pt, y: 8pt), radius: 0pt,
  fill: rgb("#F6F6F6"), stroke: 0.5pt + rgb("#9A9A9A"),
)[#text(size: 10pt, body)]

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

// Ảnh trong common/assets: dùng chung đường dẫn, khỏi phải nhớ ../..
// Truyền đường dẫn tương đối tính từ thư mục assets, KÈM phần mở rộng.
#let assets(name, ..a) = image("assets/" + name, ..a)

// Dãy ảnh chụp màn hình di động. Ảnh gốc 386×813 điểm ảnh, tức rất hẹp và rất
// cao, nên một ảnh đứng riêng giữa trang A4 chỉ dùng được một phần tư bề ngang.
// Xếp chúng thành một dãy ngang, cùng chiều cao, mỗi ảnh mang một nhãn con.
#let anh-mobile(cap, tep, nhan: (), cao: 11.4cm) = figure(
  align(center, stack(
    dir: ltr, spacing: 7mm,
    ..tep.enumerate().map(((i, t)) => stack(
      spacing: 4pt,
      image("assets/mobile/" + t, height: cao),
      text(size: 8pt, fill: muted, {
        "(" + str.from-unicode(97 + i) + ")"
        if i < nhan.len() { " " + nhan.at(i) }
      }),
    )),
  )),
  caption: cap,
  kind: image,
)


// Chỗ chờ ảnh chụp màn hình sản phẩm đã chạy. Vẫn là một figure kind: image nên nó
// chiếm đúng vị trí và số hiệu hình thật, chỉ còn việc thay nội dung khối khi có ảnh.
// huong-dan mô tả cần chụp màn hình nào, ở trạng thái nào, để người chụp không phải đoán.
#let anh-cho(cap, huong-dan, cao: 5.4cm) = figure(
  block(
    width: 100%, height: cao, radius: 8pt, fill: rgb("#F2F2F2"),
    stroke: (paint: muted, thickness: 1pt, dash: "dashed"), inset: 12pt,
    align(center + horizon, {
      set text(size: 10pt, fill: rgb("#444444"))
      stack(
        spacing: 7pt,
        text(weight: 700, size: 10.5pt, [CHỖ CHỜ ẢNH CHỤP MÀN HÌNH]),
        huong-dan,
      )
    }),
  ),
  caption: cap,
  kind: image,
)

 // khung nhóm lược đồ + nhãn nhóm
  #let ngroup(members) = node(
    enclose: members, fill: none, inset: 9pt, corner-radius: 3pt,
    stroke: (paint: luma(65%), thickness: 0.6pt, dash: "dashed"),
    snap: false, layer: -1,
  )
  #let gtitle(pos, body) = node(pos, text(size: 8pt, fill: luma(45%), body), stroke: none, snap: false)
  #let wlabel = e => box(e.label, inset: .25em, radius: .2em, fill: white)
