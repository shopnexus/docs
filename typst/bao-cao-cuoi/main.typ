// ============================================================
//  BÁO CÁO THỰC TẬP TỐT NGHIỆP — BẢN CUỐI
//  Biên dịch: make cuoi   (Makefile ở thư mục typst/)
//
//  KHUNG SƯỜN — nội dung các chương đang chờ viết.
//  Nguồn tham chiếu: spec/source-of-truth.typ, bao-cao-dinh-ky/, bao-cao-tuan/
// ============================================================
#import "../common/style-quyen.typ": *

#show: quyen.with(
  tieu-de: ("BÁO CÁO THỰC TẬP", "TỐT NGHIỆP ĐẠI HỌC"),
  chay: "Báo cáo TTTN Đại học",
  thoi-diem: "Tháng 08/2026",
)

#set page(numbering: "i")
#counter(page).update(1)

#muc-luc()
#pagebreak()

#sechead([LỜI CẢM ƠN], outlined: false)

Chúng em xin chân thành cảm ơn Ban Giám hiệu Học viện Công nghệ Bưu chính Viễn thông Cơ sở tại TP. Hồ Chí Minh cùng quý Thầy, Cô trong Khoa Công nghệ Thông tin đã tạo điều kiện thuận lợi và trang bị những kiến thức nền tảng quý báu cho chúng em trong suốt quá trình học tập và nghiên cứu.

Đặc biệt, chúng em xin gửi lời cảm ơn sâu sắc nhất đến thầy ThS. Nguyễn Đức Thịnh, người đã tận tình hướng dẫn, định hướng chuyên môn và đóng góp những ý kiến vô cùng quý báu trong suốt kỳ thực tập, giúp nhóm hoàn thành báo cáo thực tập tốt nghiệp này.

Mặc dù đã có nhiều cố gắng, song do giới hạn về mặt thời gian và kinh nghiệm, báo cáo không tránh khỏi những thiếu sót. Chúng em rất mong nhận được sự góp ý chân thành từ quý Thầy, Cô để đề tài ngày càng hoàn thiện hơn.

#v(1.5cm)
#align(right, block(width: 45%, align(center)[
  *Sinh viên thực hiện* \
  #v(0.5em)
  Đậu Văn Đăng Khoa \
  Hồ Công Toản \
  Nguyễn Tấn Khoa
]))

#pagebreak()

#sechead([DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT], outlined: false)

#table(
  inset: (x: 8pt, y: 4pt),
  columns: (auto, 1.5fr, 2fr),
  align: (left, left, left),
  table.header([*Viết tắt*], [*Cụm từ đầy đủ*], [*Ý nghĩa*]),
  [ANN], [Approximate Nearest Neighbor], [Tìm láng giềng gần đúng (cho tìm kiếm vector)],
  [API], [Application Programming Interface], [Giao diện lập trình ứng dụng],
  [AD], [Architectural Driver], [Yêu cầu có ý nghĩa kiến trúc (đánh mã AD-xx)],
  [BR], [Business Rule], [Quy tắc nghiệp vụ (đánh mã BR-xxx)],
  [B2C], [Business to Consumer], [Giao dịch giữa doanh nghiệp và người tiêu dùng],
  [C2C], [Consumer to Consumer], [Giao dịch giữa các cá nhân người dùng],
  [CI/CD], [Continuous Integration / Continuous Deployment], [Tích hợp và triển khai liên tục],
  [CSDL], [], [Cơ sở dữ liệu],
  [Durable execution], [], [Thực thi bền: nền tảng bảo đảm một lời gọi chạy tới cùng dù tiến trình gặp sự cố],
  [Durable workflow], [], [Quy trình bền: quy trình nhiều bước chạy trên nền tảng durable execution],
  [Embedding], [], [Vector nhúng biểu diễn ngữ nghĩa của văn bản, dùng cho tìm kiếm ngữ nghĩa],
  [ERD], [Entity–Relationship Diagram], [Sơ đồ thực thể – quan hệ],
  [Ký quỹ], [], [Cơ chế ký quỹ (trung gian) bảo vệ giao dịch],
  [Guarded write], [], [Lượt ghi có bảo vệ, nêu đích danh trạng thái nguồn nên một lượt đọc cũ luôn thua],
  [Idempotency key], [], [Khóa lũy đẳng: định danh do bên gọi đặt để một thao tác chỉ có hiệu lực một lần],
  [Idempotent], [], [Lũy đẳng: gọi nhiều lần cho cùng kết quả như gọi một lần],
  [JWT], [JSON Web Token], [Chuẩn token xác thực người dùng],
  [NFR], [Non-Functional Requirement], [Yêu cầu phi chức năng],
  [RBAC], [Role-Based Access Control], [Kiểm soát truy cập theo vai trò],
  [REQ], [Requirement], [Yêu cầu chức năng (đánh mã REQ-xxx)],
  [SOA], [Service-Oriented Architecture], [Kiến trúc hướng dịch vụ],
  [TC], [Test Case], [Ca kiểm thử (đánh mã TC-xx)],
  [TMĐT], [], [Thương mại điện tử],
  [RPC], [Remote Procedure Call], [Lời gọi thủ tục từ xa giữa các dịch vụ],
  [TLS], [Transport Layer Security], [Mã hóa dữ liệu trên đường truyền],
  [UC], [Use Case], [Ca sử dụng (đánh mã UC-xx)],
  [UML], [Unified Modeling Language], [Ngôn ngữ mô hình hóa thống nhất],
)

#pagebreak()

#danh-muc-bang()
#pagebreak()

#danh-muc-hinh()
#pagebreak()

#sechead([KẾ HOẠCH THỰC HIỆN CÔNG VIỆC NHÓM], outlined: false)

#v(0.5cm)
#table(
  columns: (0.9cm, 1fr, 3.1cm, 2.0cm, 2.8cm),
  inset: 7pt,
  align: (center, left, left, center, center),
  table.header([*STT*], [*Nội dung công việc*], [*Người thực hiện*], [*Thời gian*], [*Mức độ hoàn thành*]),
  [1], [Khảo sát bối cảnh, xác định bài toán niềm tin trong thương mại điện tử C2C], [Cả nhóm], [Tuần 1], [Hoàn thành],
  [2], [Phân tích các mô hình sàn giao dịch tiêu biểu và rút ra yêu cầu cho đề tài], [Nguyễn Tấn Khoa, Hồ Công Toản], [Tuần 1], [Hoàn thành],
  [3], [Nghiên cứu kiến trúc hướng dịch vụ, mô hình vi dịch vụ và triết lý mỗi dịch vụ một cơ sở dữ liệu], [Đậu Văn Đăng Khoa, Hồ Công Toản], [Tuần 1], [Hoàn thành],
  [4], [Nghiên cứu durable execution và các mẫu giao dịch phân tán], [Đậu Văn Đăng Khoa], [Tuần 1], [Hoàn thành],
  [5], [Nghiên cứu tìm kiếm ngữ nghĩa và hệ gợi ý đa sở thích], [Đậu Văn Đăng Khoa, Hồ Công Toản], [Tuần 1 – 2], [Hoàn thành],
  [6], [Phân tích tác nhân, chân dung người dùng và sơ đồ ngữ cảnh hệ thống], [Nguyễn Tấn Khoa], [Tuần 2], [Hoàn thành],
  [7], [Xây dựng danh mục ca sử dụng và đặc tả chi tiết các ca trọng yếu], [Cả nhóm], [Tuần 2], [Hoàn thành],
  [8], [Chuẩn hóa bộ quy tắc nghiệp vụ ràng buộc nền tảng], [Nguyễn Tấn Khoa, Hồ Công Toản], [Tuần 2], [Hoàn thành],
  [9], [Ban hành bộ yêu cầu chức năng và phi chức năng], [Cả nhóm], [Tuần 2], [Hoàn thành],
  [10], [Mô hình hóa quy trình bằng sơ đồ hoạt động, sơ đồ trạng thái và sơ đồ trình tự], [Đậu Văn Đăng Khoa, Nguyễn Tấn Khoa], [Tuần 2], [Hoàn thành],
  [11], [Phân rã miền nghiệp vụ và thiết kế kiến trúc tổng thể], [Cả nhóm], [Tuần 2], [Hoàn thành],
  [12], [Thiết kế luồng giao tiếp liên dịch vụ và trục sự kiện bất đồng bộ], [Đậu Văn Đăng Khoa], [Tuần 2 – 3], [Hoàn thành],
  [13], [Thiết kế thành phần phân lớp và sơ đồ lớp], [Hồ Công Toản, Đậu Văn Đăng Khoa], [Tuần 3], [Hoàn thành],
  [14], [Thiết kế danh mục giao diện lập trình], [Nguyễn Tấn Khoa, Đậu Văn Đăng Khoa], [Tuần 3], [Hoàn thành],
  [15], [Thiết kế cơ sở dữ liệu vật lý cho 7 lược đồ], [Cả nhóm], [Tuần 3], [Hoàn thành],
  [16], [Thiết kế bảo mật và chiến lược xử lý lỗi], [Đậu Văn Đăng Khoa], [Tuần 3], [Hoàn thành],
  [17], [Hiện thực dịch vụ tài khoản, danh mục sản phẩm và tìm kiếm], [Đậu Văn Đăng Khoa, Hồ Công Toản], [Tuần 3 – 4], [Hoàn thành],
  [18], [Hiện thực dịch vụ đơn hàng, tài chính và luồng ký quỹ], [Đậu Văn Đăng Khoa], [Tuần 4 – 5], [Hoàn thành],
  [19], [Hiện thực dịch vụ hội thoại, tín nhiệm và quan trắc vận hành], [Đậu Văn Đăng Khoa, Hồ Công Toản], [Tuần 4 – 5], [Hoàn thành cơ bản],
  [20], [Hiện thực ứng dụng web], [Đậu Văn Đăng Khoa, Hồ Công Toản], [Tuần 4 – 5], [Hoàn thành],
  [21], [Hiện thực ứng dụng di động], [Nguyễn Tấn Khoa], [Tuần 4 – 6], [Hoàn thành],
  [22], [Tích hợp các nhà cung cấp bên ngoài và bộ giả lập tương ứng], [Đậu Văn Đăng Khoa], [Tuần 5], [Hoàn thành cơ bản],
  [23], [Xây dựng quy trình tích hợp liên tục và mô hình triển khai bằng container], [Đậu Văn Đăng Khoa], [Tuần 5], [Hoàn thành cơ bản],
  [24], [Kiểm thử và đánh giá mức độ đáp ứng bộ yêu cầu đã đặt ra], [Cả nhóm], [Tuần 5 – 6], [Hoàn thành cơ bản],
  [25], [Tổng hợp và hoàn thiện báo cáo thực tập tốt nghiệp], [Cả nhóm], [Tuần 6], [Hoàn thành],
)

// ============================================================
//  RUỘT — đánh số trang Ả Rập
// ============================================================
#set page(numbering: "1")
#counter(page).update(1)

#pagebreak()
#sechead([MỞ ĐẦU])


Hiện nay, thương mại điện tử giữa các cá nhân đã trở thành một kênh giao dịch quen thuộc tại Việt Nam nhưng vẫn đang vận hành trên một nền tảng niềm tin mong manh. Người mua chuyển tiền đi mà không có gì bảo đảm hàng sẽ tới; người bán gửi hàng đi mà không chắc sẽ nhận được tiền; và khi bất đồng xảy ra thì không có bên thứ ba nào đứng ra xử lý. Thanh toán khi nhận hàng thường được xem là giải pháp, nhưng thực chất chỉ chuyển rủi ro sang người bán.

Từ thực tế đó, bài toán trung tâm của đề tài không phải là dựng thêm một nơi để đăng tin rao vặt, mà là xây dựng một cơ chế khép kín giúp hai người xa lạ có thể giao dịch an toàn mà không cần phải tin tưởng nhau từ trước. Để làm được điều này, đề tài hướng tới xây dựng một nền tảng với cốt lõi là cơ chế thanh toán tạm giữ: tiền của người mua được hệ thống giữ lại ở tài khoản trung gian, và chỉ được giải ngân cho người bán khi hàng đã tới tay đồng thời thời hạn khiếu nại đã trôi qua.

Tuy nhiên, việc chỉ giữ tiền trung gian vẫn chưa đủ để giải quyết trọn vẹn bài toán niềm tin, vì tranh chấp còn có thể phát sinh từ sai lệch thông tin sản phẩm, gian lận danh tính hay bất đồng về giá cả. Vì vậy, nền tảng được thiết kế tích hợp thêm các quy trình bảo vệ xoay quanh vòng đời giao dịch: bắt buộc xác minh danh tính trước khi được bán hàng, cho phép thương lượng giá trực tiếp ngay trong cuộc trò chuyện, và cung cấp một bộ phận đứng ra phân xử tranh chấp dựa trên bằng chứng kỹ thuật từ hai phía. Sự kết hợp này giúp triệt tiêu tối đa các kẽ hở lừa đảo, từ đấy tạo một môi trường giao dịch minh bạch, an toàn và bảo vệ toàn diện quyền lợi hợp pháp của cả người mua lẫn người bán.

Về tình hình nghiên cứu, mô hình ký quỹ đã được các sàn lớn trong nước áp dụng ở những mức độ khác nhau, song phần lớn nền tảng rao vặt C2C vẫn dừng ở vai trò kết nối thông tin và để hai bên tự chuyển tiền cho nhau. Ở khía cạnh kỹ thuật, việc giữ nhất quán cho một quy trình dài hạn trải qua nhiều dịch vụ từ lâu được giải quyết bằng mẫu thiết kế Saga, còn hướng thực thi bền (durable execution) mới xuất hiện gần đây và chưa phổ biến tại Việt Nam. Khoảng trống đó là chỗ đề tài đặt đóng góp của mình.

Về phạm vi, đề tài bao trùm trọn vòng đời một giao dịch C2C, từ đăng bán, tìm kiếm, thương lượng, thanh toán ký quỹ, giao nhận cho tới hoàn tiền và phân xử tranh chấp, hiện thực trên cả 3 thành phần gồm dịch vụ nền, ứng dụng web và ứng dụng di động. Ngoài phạm vi là gian hàng doanh nghiệp, giao dịch xuyên biên giới, gọi thoại và gọi video, cùng việc vận hành thực tế với các đối tác ở môi trường sản xuất.

Về phương pháp nghiên cứu, phần phân tích và thiết kế áp dụng mô hình hóa hướng đối tượng bằng ngôn ngữ mô hình hóa thống nhất, gồm sơ đồ ca sử dụng kèm đặc tả đầy đủ, sơ đồ hoạt động, sơ đồ trạng thái, sơ đồ trình tự, sơ đồ lớp và sơ đồ quan hệ thực thể. Phần kiến trúc áp dụng nguyên lý mỗi dịch vụ một cơ sở dữ liệu, phần hiện thực dùng nền tảng thực thi bền cho các luồng dài hạn, và kết quả được kiểm chứng bằng bộ ca kiểm thử bám theo các yêu cầu phi chức năng.

// ---- Các chương (template tự ngắt trang trước mỗi chương) --
#include "chapters/01-tong-quan.typ"
#include "chapters/02-co-so-ly-thuyet.typ"
#include "chapters/03-phan-tich-yeu-cau.typ"
#include "chapters/04-thiet-ke-he-thong.typ"
#include "chapters/05-hien-thuc-trien-khai.typ"
#include "chapters/06-kiem-thu-danh-gia.typ"
#include "chapters/07-ket-luan.typ"

#pagebreak()
#sechead([DANH MỤC TÀI LIỆU THAM KHẢO])

// Danh mục dựng THỦ CÔNG, không dùng #bibliography, vì phụ lục QĐ 922 đòi tách
// theo ngôn ngữ (Tiếng Việt / Tiếng Anh / Website) — điều mà bibliography() của
// Typst không làm được: nó chỉ sinh một danh sách phẳng theo kiểu trích dẫn.
// Dữ liệu gốc của 12 mục vẫn giữ ở refs.bib để đối chiếu.
//
// Quy cách ghi theo phụ lục:
//   tạp chí        → tác giả, tên bài, tên tạp chí, tập, số, trang, (năm)
//   sách           → tác giả, tên sách, nhà xuất bản, nơi xuất bản, (năm)
//   báo cáo KH     → tác giả, tên báo cáo, tên kỷ yếu, nơi và thời gian hội nghị
// Quy ước ngôn ngữ trong một mục: DANH TỪ RIÊNG giữ nguyên ngôn ngữ gốc — tên tác
// giả, tên bài, tên tạp chí, tên hội nghị, tên nhà xuất bản, tên thành phố và quốc
// gia. Chỉ các NHÃN cấu trúc mới viết tiếng Việt: "tập", "số", "tr.", "tái bản lần",
// "truy cập ngày". Không dịch tên hội nghị hay tên nước, vì dịch ra thì mục vừa sai
// tên gốc vừa đọc như nửa Anh nửa Việt.
// Xếp abc: hai nghị định theo tên tài liệu, phần tiếng Anh theo họ tác giả,
// phần website theo tên tài nguyên. Số thứ tự chạy liên tục qua cả 3 nhóm để
// trích dẫn trong thân bài (dạng [n]) không bị trùng.
#let nhom-tltk(ten) = block(above: 1.1em, below: 0.5em)[#strong(ten)]

#nhom-tltk[Tiếng Việt]
#enum(
  numbering: n => "[" + str(n) + "]",
  start: 1,
  [Quốc hội nước Cộng hòa xã hội chủ nghĩa Việt Nam, Luật Bảo vệ quyền lợi người tiêu dùng số 19/2023/QH15, Công báo, Hà Nội (2023).],
  [Quốc hội nước Cộng hòa xã hội chủ nghĩa Việt Nam, Luật Thương mại điện tử số 122/2025/QH15, Công báo, Hà Nội (2025).],
)

#nhom-tltk[Tiếng Anh]
#enum(
  numbering: n => "[" + str(n + 2) + "]",
  start: 1,
  [Burckhardt S., Gillum C., Justo D., Kallas K., McMahon C., Meiklejohn C. S., Durable Functions: Semantics for Stateful Serverless, Proceedings of the ACM on Programming Languages, vol. 5, OOPSLA, article 133, pp. 1–27 (2021).],
  [Chen J., Xiao S., Zhang P., Luo K., Lian D., Liu Z., M3-Embedding: Multi-Linguality, Multi-Functionality, Multi-Granularity Text Embeddings Through Self-Knowledge Distillation, Findings of the Association for Computational Linguistics: ACL 2024, pp. 2318–2335, Bangkok, Thailand (2024).],
  [Garcia-Molina H., Salem K., Sagas, ACM SIGMOD Record, vol. 16, no. 3, pp. 249–259 (1987).],
  [Helland P., Idempotence Is Not a Medical Condition, ACM Queue, vol. 10, no. 4, pp. 30–46 (2012).],
  [Kleppmann M., Designing Data-Intensive Applications: The Big Ideas Behind Reliable, Scalable, and Maintainable Systems, O'Reilly Media, Sebastopol, CA, USA (2017).],
  [Li C., Liu Z., Wu M., Xu Y., Zhao H., Huang P., Kang G., Chen Q., Li W., Lee D. L., Multi-Interest Network with Dynamic Routing for Recommendation at Tmall, Proc. 28th ACM Int. Conf. on Information and Knowledge Management (CIKM), pp. 2615–2623, Beijing, China (2019).],
  [Newman S., Building Microservices: Designing Fine-Grained Systems, 2nd ed., O'Reilly Media, Sebastopol, CA, USA (2021).],
  [Richardson C., Microservices Patterns: With Examples in Java, Manning Publications, Shelter Island, NY, USA (2018).],
)

#nhom-tltk[Website tham khảo]
#enum(
  numbering: n => "[" + str(n + 10) + "]",
  start: 1,
  [pgvector: Open-Source Vector Similarity Search for PostgreSQL, https:\/\/github.com/pgvector/pgvector.],
  [Restate Documentation: Durable Execution Engine for Microservices, https:\/\/docs.restate.dev.],
)
