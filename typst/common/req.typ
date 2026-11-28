// ============================================================
//  req.typ: mã yêu cầu đọc từ registry/requirements.yaml.
//  Bảng ca sử dụng, yêu cầu chức năng, quy tắc nghiệp vụ, yêu cầu phi
//  chức năng và bảng đặc tả ca đều sinh từ file đó. Mã sai làm báo cáo
//  dừng biên dịch. Chương nào dùng thì import thêm:
//    #import "../../common/req.typ": *
// ============================================================
#import "tokens.typ": ucspec, headfill

// Chữ trong registry có chỗ giữ như {catalog.MaxOnSale}: giá trị lấy từ
// code của server, `make trace` ghi vào registry/trace.json. Thiếu giá trị
// thì dừng biên dịch, để báo cáo không bao giờ in chỗ giữ.
#let _values = json("/registry/trace.json").at("values", default: (:))
#let _placeholder = regex("\\{([a-z][a-z0-9/]*)\\.([A-Za-z_][\\w.()\\[\\]]*)(?:\\|([\\w%]+))?\\}")
#let _fill(v, lang: "vi") = {
  if type(v) == str {
    v.replace(_placeholder, m => {
      let key = m.text.slice(1, -1)
      let val = _values.at(key, default: none)
      if val == none { panic("{" + key + "} không có giá trị trong registry/trace.json; chạy make trace") }
      val.at(lang)
    })
  } else if type(v) == array {
    v.map(x => _fill(x, lang: lang))
  } else if type(v) == dictionary {
    let out = (:)
    for (k, x) in v { out.insert(k, _fill(x, lang: if k == "en" { "en" } else { lang })) }
    out
  } else { v }
}

#let req = _fill(yaml("/registry/requirements.yaml"))

#let _items = (req.uc + req.fr + req.br + req.nfr + req.adr)
#let _by-id = _items.fold((:), (acc, it) => { acc.insert(it.id, it); acc })

// Một mục theo mã; mã không có trong registry làm dừng biên dịch.
#let req-item(id) = {
  let it = _by-id.at(id, default: none)
  if it == none { panic("mã " + id + " không có trong registry/requirements.yaml") }
  it
}

#let _title(it) = {
  let s = it.at("short", default: it.title)
  s.at("vi", default: it.title.vi)
}

// "UC-DEAL-02 · Trả giá", dùng cho nhãn sơ đồ và văn xuôi.
#let uc(id) = [#id · #_title(req-item(id))]

#let _actor(key) = req.actors.at(key).vi
#let _lower(s) = lower(s.first()) + s.slice(s.first().len())

// Mã không xuống dòng ở dấu gạch ngang; cột mã co theo mã dài nhất.
#let _id(id) = box(id)

// Mục đã bỏ (status: retired) không lên bảng.
#let _live(xs) = xs.filter(x => x.at("status", default: "") != "retired")

#let _band(n, body) = table.cell(colspan: n, fill: rgb("#F7F7F7"))[*#body*]

// Bảng danh mục ca sử dụng, chia theo nhóm.
#let uc-table(caption: [Danh mục ca sử dụng của hệ thống]) = {
  let rows = ()
  let letters = "ABCDEFGHIJ"
  let i = 0
  for (key, name) in req.groups {
    let ucs = req.uc.filter(u => u.id.split("-").at(1) == key and u.at("status", default: "") != "retired")
    if ucs.len() == 0 { continue }
    let band = if key == "SHR" { name.vi } else { letters.at(i) + ". " + name.vi }
    if key != "SHR" { i += 1 }
    rows.push(_band(3, band))
    for u in ucs {
      let who = u.actors.map(_actor).join(", ")
      let note = u.at("actorsNote", default: none)
      if note != none { who += "; " + note }
      rows += (_id(u.id), [#u.title.vi], [#who])
    }
  }
  figure(
    kind: table,
    caption: caption,
    table(
      columns: (auto, 1fr, 4.2cm),
      inset: (x: 6pt, y: 2.6pt),
      align: (left + horizon, left + horizon, left + horizon),
      table.header([Mã], [Tên ca sử dụng], [Tác nhân chính]),
      ..rows,
    ),
  )
}

// Cột UC liên quan: một khoảng ghi sẵn (ucText) hoặc danh sách mã.
#let _ucs(f) = {
  let span = f.at("ucText", default: none)
  if span != none { span.split(" – ").map(_id).join([ – ]) } else { f.uc.map(_id).join([, ]) }
}

#let fr-table(caption: [Danh mục yêu cầu chức năng]) = figure(
  kind: table,
  caption: caption,
  table(
    columns: (auto, 1fr, 2.4cm, 3.4cm),
    inset: (x: 6pt, y: 3pt),
    align: (left + top, left + top, left + top, left + top),
    table.header([Mã], [Yêu cầu], [Phân hệ], [UC liên quan]),
    .._live(req.fr).map(f => (
      _id(f.id), [#f.text.vi], [#f.module],
      _ucs(f),
    )).flatten(),
  ),
)

#let br-table(caption: [Danh mục quy tắc nghiệp vụ]) = figure(
  kind: table,
  caption: caption,
  table(
    columns: (auto, 1fr),
    inset: (x: 6pt, y: 3.2pt),
    align: (left + top, left + top),
    table.header([Mã], [Nội dung]),
    .._live(req.br).map(b => (_id(b.id), [#b.text.vi])).flatten(),
  ),
)

#let nfr-table(caption: [Danh mục yêu cầu phi chức năng]) = figure(
  kind: table,
  caption: caption,
  table(
    columns: (auto, 3.2cm, 1fr),
    inset: (x: 6pt, y: 3pt),
    align: (left + top, left + top, left + top),
    table.header([Mã], [Thuộc tính], [Tiêu chí kiểm chứng]),
    .._live(req.nfr).map(n => (_id(n.id), [#n.attr], [#n.text.vi])).flatten(),
  ),
)

#let _grid(rows) = grid(
  columns: (auto, 1fr), column-gutter: 4pt, row-gutter: 5pt,
  ..rows.flatten(),
)

#let _flows(flows) = _grid(flows.pairs().map(((fid, f)) => {
  let at = f.at("at", default: none)
  let text = if f.text.ends-with(".") { f.text } else { f.text + "." }
  let body = if at != none { [Ở bước #at: #text] } else { [#text] }
  ([#fid.], body)
}))

// Bảng đặc tả một ca sử dụng, sinh từ registry.
#let ucspec-of(id) = {
  let u = req-item(id)
  let who = u.actors.map(_actor).join(" hoặc ")
  let sec = u.at("secondary", default: ())
  if sec.len() > 0 { who += "; tác nhân phụ: " + sec.map(k => _lower(_actor(k))).join(", ") }
  let rows = (
    [Tác nhân chính], [#who.],
    [Tiền điều kiện], [#u.at("pre", default: "Không có.")],
    [Hậu điều kiện], [#u.at("post", default: "")],
    [Luồng chính], _grid(u.main.pairs().map(((n, s)) => ([#n.], [#s]))),
  )
  let alt = u.at("alt", default: (:))
  let exc = u.at("exc", default: (:))
  if alt.len() > 0 { rows += ([Luồng thay thế], _flows(alt)) }
  if exc.len() > 0 { rows += ([Luồng ngoại lệ], _flows(exc)) }
  let rules = u.at("br", default: ())
  let notes = u.at("notes", default: none)
  if rules.len() > 0 or notes != none {
    let parts = ()
    if rules.len() > 0 { parts.push(rules.join(", ")) }
    if notes != none { parts.push(_lower(notes)) }
    let line = parts.join("; ")
    if not line.ends-with(".") { line += "." }
    rows += ([Quy tắc liên quan], [#line])
  }
  ucspec(u.id, u.title.vi, ..rows)
}
