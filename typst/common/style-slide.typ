// ============================================================
//  style-slide.typ — template SLIDE THUYẾT TRÌNH (Touying)
//  Dùng cho buổi bảo vệ báo cáo cuối. Nền trắng, nhấn navy, logo PTIT.
//
//  Vì sao nền trắng: tệp logo của Học viện đã có sẵn viền đỏ và nền trắng
//  nướng trong ảnh, nên đặt nó lên bất kỳ nền màu nào cũng thành một ô trắng
//  dán đè. Navy do đó chỉ làm màu nhấn (tiêu đề, gạch chân, thanh tiến độ).
//
//  Dùng: #import "../common/style-slide.typ": *
//        #show: slide-ptit.with(chu-de: "…")
//        #bia-slide()
//        = Tên phần     -> một slide phân đoạn
//        == Tên slide   -> một slide nội dung
// ============================================================
#import "@preview/touying:0.6.1": *
#import "tokens.typ": *
#import "info.typ" as info

// ---- Bảng màu -----------------------------------------------
// navy lấy từ tokens.typ để slide và bìa quyển cùng một màu.
#let nav      = navy
#let nav-nhat = rgb("#5C7AA8")
#let nav-nen  = rgb("#EEF2F8")
#let do-ptit  = rgb("#C8102E")   // đỏ trong logo, chỉ dùng nhỏ giọt để nhấn

// Chữ không chân cho slide. DejaVu Sans đứng đầu vì nó là họ chữ không chân duy
// nhất chắc chắn phủ đủ dấu tiếng Việt trên máy dựng; Nimbus Sans là dự phòng.
// Không liệt kê TeX Gyre Heros ở đây: máy nào thiếu nó thì Typst cảnh báo
// "unknown font family" ở mọi lần dựng, mà bản dựng phải sạch cảnh báo.
#let font-slide = ("DejaVu Sans", "Nimbus Sans")

#let logo-box(cao) = box(baseline: 25%, image("assets/logo-ptit.png", height: cao))

// ---- Lề trang -----------------------------------------------
// Đặt thành hằng số vì header và footer phải tự cộng lại lề ngang: Touying pad
// ÂM chúng đúng bằng `margin.x` (_get-negative-pad trong core.typ) để theme nào
// muốn vẽ dải màu tràn viền thì vẽ được. Không cộng trả thì tiêu đề, logo và
// dòng chân trang nằm sát mép giấy trong khi thân slide vẫn thụt vào.
// Dùng đơn vị tuyệt đối, không dùng em: lề trang và pad bên trong header phân
// giải em theo hai cỡ chữ khác nhau thì hai mép lại lệch nhau vài điểm.
// `le-tren` phải chứa được CẢ header, vì Typst đặt header bên trong lề trên chứ
// không phải bên trên nó: khoảng trắng thật phía trên tiêu đề chỉ bằng
//     le-tren − header-ascent − chiều cao header (logo 0.9cm + vạch kẻ ≈ 10.5mm).
// Để 22mm thì tiêu đề chỉ cách mép giấy 3mm; 28mm mới ra được ~13mm.
#let le-ngang = 21mm
#let le-tren = 28mm
#let le-duoi = 16mm
#let cao-logo-header = 0.9cm

// Ép tiêu đề slide nằm gọn MỘT dòng, co chữ lại nếu dài quá.
// Header canh đáy, nên một tiêu đề tràn xuống dòng thứ hai sẽ nở ngược lên trên
// và ăn hết khoảng trắng của lề trên — nhìn ra đúng cảnh "chữ dính sát mép".
// Khoá chiều cao header lại thì lề trên của mọi slide bằng nhau, khỏi phải canh
// độ dài từng tiêu đề bằng tay.
#let mot-dong(body) = layout(sz => {
  let m = measure(body)   // đo ở vùng vô hạn nên ra bề ngang khi chưa ngắt dòng
  let s = if m.width > 0pt { calc.min(sz.width / m.width, 1.0) } else { 1.0 }
  box(width: sz.width, scale(x: s * 100%, y: s * 100%, reflow: true, box(body)))
})

// ---- Slide nội dung -----------------------------------------
// Mặc định canh giữa theo chiều dọc: lượng chữ mỗi slide chênh nhau nhiều, canh
// trên sẽ để lại một khoảng trống lớn dưới đáy ở phần lớn slide.
#let slide(
  config: (:),
  repeat: auto,
  setting: body => body,
  composer: auto,
  can-le: horizon,
  ..bodies,
) = touying-slide-wrapper(self => {
  let header(self) = {
    // `bottom` chứ không phải `top`: vùng header trải suốt dải lề trên, canh trên
    // là ghim tiêu đề vào mép giấy và nới `le-tren` chỉ kéo dài vùng đó ra chứ
    // không đẩy chữ xuống. Canh dưới thì header nằm ngay trên thân slide, cách
    // đúng `header-ascent`, còn khoảng trắng phía trên tự dôi ra.
    set std.align(bottom)
    pad(x: le-ngang, block(width: 100%, {
      grid(
        columns: (1fr, auto),
        align: (left + horizon, right + horizon),
        column-gutter: 18pt,
        mot-dong(text(size: 1.02em, weight: 700, fill: nav,
                      utils.display-current-heading(level: 2, style: auto))),
        logo-box(cao-logo-header),
      )
      v(3pt)
      line(length: 100%, stroke: 1.1pt + nav)
    }))
  }
  let footer(self) = {
    set std.align(bottom)
    block(width: 100%, {
      pad(x: le-ngang, grid(
        columns: (1fr, auto),
        align: (left + horizon, right + horizon),
        text(size: 0.42em, fill: muted, info.de-tai-ngan),
        text(size: 0.42em, fill: muted,
             context utils.slide-counter.display() + " / " + utils.last-slide-number),
      ))
      v(3pt)
      // Thanh tiến độ cố ý để tràn hết bề ngang: nó là vạch chỉ mức, không phải
      // chữ, nên chạm mép giấy lại đọc ra ý "đi hết trang" rõ hơn.
      components.progress-bar(height: 2.5pt, nav, nav-nen)
    })
  }
  let self = utils.merge-dicts(self, config-page(header: header, footer: footer))
  let new-setting = body => {
    show: std.align.with(can-le)
    show: setting
    body
  }
  touying-slide(
    self: self, config: config, repeat: repeat,
    setting: new-setting, composer: composer, ..bodies,
  )
})

// ---- Slide bìa ----------------------------------------------
#let bia-slide(config: (:)) = touying-slide-wrapper(self => {
  let self = utils.merge-dicts(
    self, config,
    config-common(freeze-slide-counter: true),
    config-page(header: none, footer: none, margin: (x: 2.2cm, y: 1.05cm)),
  )
  let than = {
    set std.align(center)
    set par(justify: false, leading: 0.55em)

    text(size: 0.5em, weight: 700, info.bo)
    linebreak()
    text(size: 0.56em, weight: 700, fill: nav, info.truong)
    linebreak()
    text(size: 0.5em, weight: 700, fill: nav, info.co-so)

    v(0.24cm)
    image("assets/logo-ptit.png", height: 2.1cm)
    v(0.3cm)

    text(size: 0.62em, weight: 700, fill: muted, tracking: 1.6pt)[
      BÁO CÁO THỰC TẬP TỐT NGHIỆP ĐẠI HỌC
    ]
    v(0.14cm)
    line(length: 34%, stroke: 1.4pt + do-ptit)
    v(0.24cm)

    block(width: 88%, text(size: 1.02em, weight: 700, fill: nav, info.de-tai))

    v(1fr)
    block(width: 82%, grid(
      columns: (1fr, 1.15fr),
      align: (left + top, left + top),
      column-gutter: 1.2cm,
      {
        text(size: 0.46em, fill: muted)[Giảng viên hướng dẫn]
        linebreak()
        text(size: 0.54em, weight: 700, info.gvhd)
      },
      {
        text(size: 0.46em, fill: muted)[Nhóm #info.nhom · Lớp #info.lop]
        linebreak()
        for sv in info.sinh-vien {
          text(size: 0.54em, weight: 700, sv.at(0))
          text(size: 0.46em, fill: muted, [ · #sv.at(1)])
          linebreak()
        }
      },
    ))
  }
  touying-slide(self: self, than)
})

// ---- Slide phân đoạn ----------------------------------------
// Số phần đếm bằng bộ đếm riêng chứ không đọc `counter(heading)`: tiêu đề trong
// slide không đánh số nên bộ đếm tiêu đề đứng yên ở 0.
#let dem-phan = counter("phan-slide")

#let phan-slide(config: (:), level: 1, numbered: true, body) = touying-slide-wrapper(self => {
  let self = utils.merge-dicts(
    self, config,
    config-page(header: none, footer: none),
  )
  let than = {
    set std.align(horizon)
    dem-phan.step()
    block(width: 100%, {
      grid(
        columns: (auto, 1fr, auto),
        align: (left + horizon, left + horizon, right + horizon),
        column-gutter: 16pt,
        text(size: 2.6em, weight: 700, fill: nav-nen, context dem-phan.display()),
        {
          text(size: 1.3em, weight: 700, fill: nav,
               utils.display-current-heading(level: level, numbered: false))
          v(6pt)
          line(length: 100%, stroke: 1.4pt + do-ptit)
        },
        logo-box(1.5cm),
      )
      body
    })
  }
  touying-slide(self: self, than)
})

// ---- Slide kết ----------------------------------------------
#let ket-slide(config: (:), body) = touying-slide-wrapper(self => {
  let self = utils.merge-dicts(
    self, config,
    config-common(freeze-slide-counter: true),
    config-page(header: none, footer: none),
  )
  touying-slide(self: self, std.align(center + horizon, {
    image("assets/logo-ptit.png", height: 2.2cm)
    v(0.4cm)
    text(size: 1.5em, weight: 700, fill: nav, body)
  }))
})

// ---- Helper trình bày nội dung ------------------------------

// Hai (hoặc n) cột cạnh nhau. `ti` là tỉ lệ bề ngang.
#let cot(..noi-dung, ti: none) = {
  let b = noi-dung.pos()
  grid(
    columns: if ti == none { (1fr,) * b.len() } else { ti },
    column-gutter: 14pt,
    align: top,
    ..b,
  )
}

// Thẻ có tiêu đề: dùng cho các cụm ý ngang hàng nhau.
#let the(ten, body, mau: nav) = block(
  width: 100%, inset: (x: 9pt, y: 7pt), radius: 3pt,
  fill: nav-nen, stroke: (left: 2.5pt + mau),
  {
    text(size: 0.76em, weight: 700, fill: mau, ten)
    linebreak()
    text(size: 0.7em, body)
  },
)

// Dòng ghi chú nhỏ cuối slide.
#let ghi(body) = text(size: 0.58em, fill: muted, style: "italic", body)

// ---- Sơ đồ trên slide ---------------------------------------
// Sơ đồ chiếu lên máy chiếu cần ít nút hơn và nét dày hơn sơ đồ in trong quyển,
// nên không dùng lại `fig`/`np`/`nt` của tokens.typ: những helper đó đi kèm
// chú thích hình và bảng xám của bản in.
// Co sơ đồ cho vừa bề ngang chỗ chứa. Chỉ thu nhỏ, không phóng to: sơ đồ vẽ vừa
// rồi mà bị kéo giãn thì nét và cỡ chữ lệch hẳn so với các slide khác. Không có
// nó thì một nhãn dài làm sơ đồ tràn ra ngoài cột và bị cắt mất.
#let vua-be(body) = layout(sz => {
  let m = measure(body)
  let s = if m.width > 0pt { calc.min(sz.width / m.width, 1.0) } else { 1.0 }
  box(scale(x: s * 100%, y: s * 100%, reflow: true, body))
})

#let sodo(co: 1em, ..d) = std.align(center, vua-be({
  set text(size: co)
  diagram(
    node-stroke: 1pt, node-corner-radius: 3pt, node-inset: 7pt,
    edge-stroke: 1.05pt + nav-nhat, mark-scale: 70%,
    ..d,
  )
}))
// Nút thường / nút nhấn / nút quyết định / nhãn trên cạnh
#let o(p, b, ..a) = node(p, text(size: 0.62em, b), fill: white,
                         stroke: 1pt + nav-nhat, ..a)
#let on(p, b, ..a) = node(p, text(size: 0.62em, weight: 700, fill: nav, b),
                          fill: nav-nen, stroke: 1.2pt + nav, ..a)
#let oq(p, b, ..a) = node(p, text(size: 0.56em, b), shape: diamond,
                          fill: white, stroke: 1pt + nav-nhat, ..a)
// Nhãn trên cạnh: có nền trắng để không dính vào đường sinh hay vào nút bên dưới.
#let nhan(b) = box(fill: white, inset: (x: 2.5pt, y: 1pt),
                   text(size: 0.52em, fill: muted, b))

// Vùng ngữ cảnh giới hạn: ngăn trên là tên ngữ cảnh, ngăn dưới là các aggregate nó
// làm chủ. Viền NÉT ĐỨT là ước lệ của thiết kế theo miền cho ranh giới ngữ cảnh —
// nó là ranh giới của một mô hình nhất quán, không phải một khối triển khai, nên
// vẽ khác hẳn nút quy trình (`o`, `on`) có viền liền.
// Bản trong quyển (`nvung` của tokens.typ) liệt kê đủ mọi aggregate; bản này cỡ chữ
// tính theo em để `vua-be` co được, và chỉ nên nạp aggregate chính.
#let ovung(p, nm, ten, ..agg) = node(
  p,
  align(left, stack(
    dir: ttb, spacing: 3pt,
    text(size: 0.6em, weight: 700, fill: nav, ten),
    line(length: 100%, stroke: 0.5pt + nav-nhat),
    ..agg.pos().map(a => text(size: 0.5em, a)),
  )),
  shape: rect, fill: nav-nen, inset: 6pt, corner-radius: 3pt, name: nm,
  stroke: (paint: nav, thickness: 0.9pt, dash: "dashed"),
)

// Hình người que kiểu sơ đồ ca sử dụng. Vẽ tay bằng `place` chứ không dùng ảnh:
// nó phải đổi màu và đổi cỡ theo thẻ chứa nó, mà vẫn in đen trắng được.
// Gọi qua `std.` vì tệp này nạp `*` từ touying và fletcher, hai gói đó có hàm
// trùng tên với `line` và `circle` của Typst.
#let nguoi-que(cao: 12.5mm, mau: nav) = {
  let d = cao
  let net = 1.2pt + mau
  std.box(width: d * 0.62, height: d, {
    std.place(top + left, dx: d * 0.17, std.circle(radius: d * 0.14, stroke: net))
    std.place(top + left, std.line(start: (d * 0.31, d * 0.30), end: (d * 0.31, d * 0.62), stroke: net))
    std.place(top + left, std.line(start: (d * 0.06, d * 0.40), end: (d * 0.56, d * 0.40), stroke: net))
    std.place(top + left, std.line(start: (d * 0.31, d * 0.62), end: (d * 0.08, d * 0.92), stroke: net))
    std.place(top + left, std.line(start: (d * 0.31, d * 0.62), end: (d * 0.54, d * 0.92), stroke: net))
  })
}

// Thẻ vai trò: băng trên là hình người, tên vai trò và một câu tự giới thiệu;
// thân dưới là vài việc chính, mỗi việc một dòng. Cố ý CHỈ nhận ba việc — thẻ
// này để hội đồng nhìn một cái là nắm được vai trò, danh sách đầy đủ nằm trong
// quyển. Viền LIỀN, khác `ovung` (nét đứt) vốn là ranh giới ngữ cảnh.
// `rong` phải để dư chỗ: chữ không chân của slide rộng hơn chữ có chân của quyển.
#let the-vai(p, nm, ten, mo-ta, rong: 68mm, ..viec) = node(
  p,
  // `sodo` canh giữa cả sơ đồ nên nội dung trong thẻ cũng bị kéo vào giữa nếu
  // không canh trái lại: ba dòng việc so le nhau đọc mệt hơn hẳn khi cùng lề.
  std.align(left, block(width: 100%, {
    block(width: 100%, fill: nav-nen, inset: (x: 12pt, y: 12pt),
      radius: (top: 3.5pt),
      grid(
        columns: (auto, 1fr), column-gutter: 11pt,
        align: (left + horizon, left + horizon),
        nguoi-que(),
        {
          text(size: 0.78em, weight: 700, fill: nav, ten)
          linebreak()
          text(size: 0.48em, fill: muted, style: "italic", mo-ta)
        },
      ))
    block(width: 100%, inset: (x: 14pt, y: 18pt), stack(
      dir: ttb, spacing: 16pt,
      ..viec.pos().map(v => grid(
        columns: (auto, 1fr), column-gutter: 8pt, align: (horizon, left + top),
        text(size: 0.4em, fill: nav-nhat)[●], text(size: 0.6em, v),
      )),
    ))
  })),
  shape: rect, fill: white, inset: 0pt, corner-radius: 4pt,
  width: rong, stroke: 1pt + nav-nhat, name: nm,
)

// Cụm chữ nhấn.
#let nh(body) = text(weight: 700, fill: nav, body)

// Bảng gọn cho slide: không kẻ dọc, chỉ một vạch dưới hàng tiêu đề.
#let bang(cot-rong, ..o) = block(width: 100%, text(size: 0.66em, table(
  columns: cot-rong,
  inset: (x: 6pt, y: 5pt),
  align: left + top,
  stroke: (x, y) => if y == 1 { (top: 1pt + nav) } else { none },
  fill: (x, y) => if y == 0 { nav-nen } else { white },
  ..o,
)))

// ---- Template -----------------------------------------------
#let slide-ptit(
  ti-le: "16-9",
  co-chu: 20pt,
  ..args,
  doc,
) = {
  show: touying-slides.with(
    config-page(
      paper: "presentation-" + ti-le,
      header-ascent: 0.6em,
      footer-descent: 0.9em,
      margin: (top: le-tren, bottom: le-duoi, x: le-ngang),
    ),
    config-common(
      slide-fn: slide,
      new-section-slide-fn: phan-slide,
    ),
    config-methods(
      init: (self: none, body) => {
        set text(font: font-slide, size: co-chu, fill: ink, lang: "vi")
        set par(justify: false, leading: 0.62em, spacing: 0.85em)
        show raw: set text(font: font-mono, size: 0.82em)

        // Danh sách gạch đầu dòng: dấu đầu dòng navy, thụt vừa phải để hai cấp
        // vẫn phân biệt được ở khoảng cách chiếu.
        set list(marker: (text(fill: nav)[▪], text(fill: nav-nhat)[–]), indent: 4pt, spacing: 0.72em)
        set enum(numbering: n => text(fill: nav, weight: 700, str(n) + "."), indent: 4pt, spacing: 0.72em)

        show heading.where(level: 3): set text(size: 0.84em, fill: nav)
        show link: set text(fill: nav)
        set table(stroke: 0.6pt + hairline)

        body
      },
      // Touying mặc định cho `show strong: alert`, nên đây cũng là màu của mọi
      // cụm *in đậm*. Để navy chứ không để đỏ: đỏ dùng dày sẽ nuốt mất trọng số
      // của những chỗ thật sự cần nhấn, và chỏi với tông đã chọn cho quyển.
      alert: (self: none, it) => text(weight: 700, fill: nav, it),
    ),
    config-colors(
      primary: nav,
      secondary: nav-nhat,
      tertiary: nav-nen,
      neutral-lightest: white,
      neutral-darkest: ink,
    ),
    ..args,
  )

  doc
}