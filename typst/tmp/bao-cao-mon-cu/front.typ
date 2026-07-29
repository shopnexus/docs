// ============================================================
// front.typ — LỜI CẢM ƠN và BẢNG PHÂN CÔNG
// ============================================================
#import "theme.typ": font-head, c-primary, c-soft

#let front-heading(title) = {
  set align(center)
  v(0.5cm)
  text(font: font-head, size: 14pt, weight: "bold", fill: c-primary)[#upper(title)]
  v(0.2cm)
  set align(left)
}

#let loi-cam-doan = {
  front-heading("Lời cam đoan")
  [
    Chúng tôi xin cam đoan rằng đồ án này là công trình nghiên cứu và thực hiện thực tế của nhóm sinh viên dưới sự hướng dẫn trực tiếp của ThS. Nguyễn Đức Thịnh.

    Các số liệu, kết quả phân tích, thiết kế kiến trúc và mô hình hóa nghiệp vụ trình bày trong báo cáo là trung thực, độc lập và chưa từng được công bố trong bất kỳ công trình nào khác. Các tài liệu tham khảo, mã nguồn hay công cụ hỗ trợ được sử dụng trong đề tài đều được trích dẫn nguồn gốc rõ ràng theo đúng quy định.

    Nếu phát hiện có bất kỳ sự gian lận hay sao chép trái phép nào, chúng em xin hoàn toàn chịu trách nhiệm trước Hội đồng đánh giá và Khoa Công nghệ Thông tin 2 - Học viện Công nghệ Bưu chính Viễn thông Cơ sở tại TP. Hồ Chí Minh.

    #v(0.8cm)
    #align(right)[
      _TP. Hồ Chí Minh, tháng 7 năm 2026_ \
      #v(0.2cm)
      #text(weight: "bold")[Nhóm sinh viên thực hiện] \
      #v(0.1cm)
      Đậu Văn Đăng Khoa \
      Hồ Công Toản \
      Nguyễn Tấn Khoa
    ]
    #v(0.6cm)
  ]
}

#let loi-cam-on = {
  front-heading("Lời cảm ơn")
  [
    Trước hết, chúng tôi xin bày tỏ lòng biết ơn sâu sắc đến giảng viên hướng dẫn, Ths Nguyễn Đức Thịnh, vì sự chỉ dẫn tận tình, sự hỗ trợ liên tục và sự kiên nhẫn trong suốt quá trình thực hiện đồ án thực tập này. Kiến thức chuyên môn sâu rộng cùng những góp ý quý báu của thầy là nguồn động lực lớn giúp nhóm hoàn thành nghiên cứu.
    
    Chúng tôi cũng xin chân thành cảm ơn Khoa Công nghệ thông tin 2 - Học viện Công nghệ Bưu chính Viễn thông cơ sở tại TP. Hồ Chí Minh, đã tạo điều kiện về môi trường học thuật chuyên nghiệp và các nguồn lực cần thiết để chúng tôi thực hiện đề tài này.
    
    Chúng tôi xin gửi lời cảm ơn chân thành đến các bạn cùng nhóm và những người bạn đồng hành đã luôn động viên, hỗ trợ trong những giai đoạn khó khăn. Sự tin tưởng và khích lệ đó là động lực quan trọng để chúng tôi vượt qua thử thách và hoàn thành dự án.
    
    Cuối cùng, mặc dù đã nỗ lực hết sức để đảm bảo chất lượng báo cáo, những thiếu sót là điều khó tránh khỏi. Chúng tôi rất mong nhận được các ý kiến đóng góp từ quý thầy cô và bạn đọc để tiếp tục hoàn thiện hơn trong các công việc sau này.
    #v(0.6cm)
  ]
}

// #let bang-phan-cong(thanhvien-cong-viec) = {
//   front-heading("Bảng phân công")
//   table(
//     columns: (auto, 1.4fr, 2.2fr),
//     align: (center + horizon, left + horizon, left + horizon),
//     table.header([STT], [Thành viên], [Công việc phụ trách]),
//     ..thanhvien-cong-viec.enumerate().map(((i, r)) => (
//       [#(i + 1)], [#r.at(0)], [#r.at(1)],
//     )).flatten(),
//   )
// }
