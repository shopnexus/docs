// ============================================================
// front.typ — LỜI CẢM ƠN và BẢNG PHÂN CÔNG
// ============================================================
#import "theme.typ": font-head, c-primary, c-soft

#let front-heading(title) = {
  set align(center)
  v(0.5cm)
  text(font: font-head, size: 16pt, weight: "bold", fill: c-primary)[#upper(title)]
  v(0.2cm)
  line(length: 30%, stroke: 1pt + c-primary)
  v(0.4cm)
  set align(left)
}

#let loi-cam-on = {
  front-heading("Lời cảm ơn")
  [
    Nhóm chúng em xin gửi lời cảm ơn chân thành đến giảng viên hướng dẫn đã tận
    tình truyền đạt kiến thức môn *Phát triển phần mềm hướng dịch vụ*, giúp chúng em
    có nền tảng để phân tích, thiết kế và phát triển một hệ thống phần mềm theo
    kiến trúc hướng dịch vụ rõ ràng, dễ bảo trì và mở rộng.

    Trong quá trình thực hiện đề tài *Sàn thương mại điện tử ShopNexus phát triển
    theo kiến trúc hướng dịch vụ*, nhóm đã có cơ hội vận dụng các nguyên lý hướng
    dịch vụ (SOA), các cách tiếp cận SOAP/REST/Microservice, các mẫu thiết kế dịch
    vụ và tư duy phân rã hệ thống vào một sản phẩm
    thực tế. Báo cáo này là kết quả tổng hợp quá trình tìm hiểu, thiết kế và hiện
    thực của cả nhóm.

    Do thời gian và kiến thức còn hạn chế, báo cáo không tránh khỏi thiếu sót.
    Nhóm rất mong nhận được sự góp ý của quý thầy cô để hoàn thiện hơn.

    #v(0.6cm)
  ]
}

#let bang-phan-cong(thanhvien-cong-viec) = {
  front-heading("Bảng phân công")
  table(
    columns: (auto, 1.4fr, 2.2fr),
    align: (center + horizon, left + horizon, left + horizon),
    table.header([STT], [Thành viên], [Công việc phụ trách]),
    ..thanhvien-cong-viec.enumerate().map(((i, r)) => (
      [#(i + 1)], [#r.at(0)], [#r.at(1)],
    )).flatten(),
  )
}
