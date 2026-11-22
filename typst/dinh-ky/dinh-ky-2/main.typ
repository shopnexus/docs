// ============================================================
//  BÁO CÁO ĐỊNH KỲ 1 — ĐỒ ÁN TỐT NGHIỆP ĐẠI HỌC
//  Giai đoạn 1 (tuần 1–4), nộp Tháng 10/2026.
//  Mô hình: Chuẩn quyển báo cáo PTIT (Phụ lục 3, QĐ 449/QĐ-HV)
//  Biên dịch: make dinh-ky   (Makefile ở thư mục typst/)
// ============================================================
#import "../../common/style-quyen.typ": *

#show: quyen.with(
  tieu-de: ("BÁO CÁO ĐỊNH KỲ 2", "ĐỒ ÁN TỐT NGHIỆP", "ĐẠI HỌC"),
  chay: "Đồ án tốt nghiệp Đại học",
  thoi-diem: "Tháng 11/2026",
)


#set page(numbering: "i")
#counter(page).update(1)

#sechead([LỜI CẢM ƠN], outlined: false)

Trong suốt quá trình nghiên cứu và thực hiện đồ án, nhóm chúng em đã nhận được sự quan tâm, hướng dẫn và giúp đỡ tận tình từ quý thầy cô thuộc Khoa Công nghệ thông tin 2, Học viện Công nghệ Bưu chính Viễn thông – Cơ sở tại TP. Hồ Chí Minh.

Trước hết, nhóm chúng em xin chân thành cảm ơn Học viện đã tạo điều kiện thuận lợi về cơ sở vật chất, môi trường học tập và nghiên cứu, giúp nhóm có thể vận dụng những kiến thức đã học vào quá trình thực hiện đồ án. Đồng thời, nhóm chúng em xin gửi lời cảm ơn sâu sắc đến quý thầy cô Khoa Công nghệ thông tin 2 đã tận tình giảng dạy, truyền đạt kiến thức chuyên môn và hỗ trợ nhóm trong suốt quá trình học tập.

Đặc biệt, nhóm chúng em xin bày tỏ lòng biết ơn chân thành đến thầy Nguyễn Đức Thịnh, giảng viên Học viện Công nghệ Bưu chính Viễn thông – Cơ sở tại TP. Hồ Chí Minh, đã tận tình hướng dẫn, định hướng và đóng góp những ý kiến quý báu, giúp nhóm từng bước hoàn thiện đồ án.

Mặc dù đã nỗ lực thực hiện đồ án với tinh thần nghiêm túc và trách nhiệm, nhưng do thời gian thực hiện có hạn và kiến thức, kinh nghiệm thực tiễn còn hạn chế, đồ án khó tránh khỏi những thiếu sót. Nhóm chúng em kính mong nhận được những ý kiến nhận xét và góp ý từ quý thầy cô để có thể bổ sung, khắc phục những hạn chế và hoàn thiện hơn trong quá trình học tập, nghiên cứu sau này.

Nhóm chúng em xin chân thành cảm ơn!


#v(0.5cm)

#align(right)[
  #block(width: 45%)[
    #align(center)[
      #v(0.5em)

      #text(style: "italic")[
        TPHCM, ngày …… tháng …… năm ……
      ]

      #text(weight: "bold")[
        ĐẠI DIỆN NHÓM SINH VIÊN
      ]

      #text(style: "italic")[
        (Ký và ghi rõ họ tên)
      ]
    ]
  ]
]

#pagebreak()

#sechead([LỜI CAM ĐOAN], outlined: false)

Chúng em xin cam đoan rằng đây là đồ án do nhóm sinh viên thực hiện, có sự hỗ trợ từ tập thể giáo viên hướng dẫn. Các nội dung nghiên cứu và kết quả trong đề tài này là trung thực và do các thành viên trong nhóm thực hiện. Những số liệu trong các bảng biểu phục vụ cho việc phân tích, nhận xét, đánh giá được các thành viên trong nhóm thu thập từ các nguồn khác nhau có ghi trong phần tài liệu tham khảo hoặc lấy từ thực nghiệp.

Nếu bị phát hiện có bất kỳ sự gian lận nào các thành viên trong nhóm xin hoàn toàn chịu trách nhiệm.




#v(0.5cm)

#align(right)[
  #block(width: 45%)[
    #align(center)[
      #v(0.5em)

      #text(style: "italic")[
        TPHCM, ngày …… tháng …… năm ……
      ]

      #text(weight: "bold")[
        ĐẠI DIỆN NHÓM SINH VIÊN
      ]

      #text(style: "italic")[
        (Ký và ghi rõ họ tên)
      ]
    ]
  ]
]

#pagebreak()

#muc-luc()
#pagebreak()

#sechead([DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT], outlined: false)

#table(
  inset: (x: 8pt, y: 3.6pt),
  columns: (auto, 1.6fr, 2fr),
  align: (left, left, left),
  table.header([*Viết tắt*], [*Cụm từ đầy đủ*], [*Ý nghĩa*]),
  [AI], [Artificial Intelligence], [Trí tuệ nhân tạo],
  [BR], [Business Rule], [Quy tắc nghiệp vụ (đánh mã BR-xx)],
  [C2C], [Consumer to Consumer], [Giao dịch giữa các cá nhân],
  [COD], [Cash on Delivery], [Giao hàng thu tiền hộ],
  [eKYC], [Electronic Know Your Customer], [Xác minh danh tính điện tử],
  [GHN], [], [Công ty Giao Hàng Nhanh],
  [GHTK], [], [Công ty Giao Hàng Tiết Kiệm],
  [NFR], [Non-Functional Requirement], [Yêu cầu phi chức năng (đánh mã NFR-xx)],
  [OTP], [One-Time Password], [Mã dùng một lần],
  [REQ], [Requirement], [Yêu cầu chức năng (đánh mã REQ-xx)],
  [SMS], [Short Message Service], [Tin nhắn ngắn],
  [UC], [Use Case], [Ca sử dụng (đánh mã UC-xx)],
  [UML], [Unified Modeling Language], [Ngôn ngữ mô hình hóa thống nhất],
)

#pagebreak()

#danh-muc-bang()
#v(1em)
#pagebreak()

#danh-muc-hinh()
#pagebreak()

#sechead([MỞ ĐẦU])

Ở Việt Nam, giao dịch đồ cũ giữa các cá nhân hiện chủ yếu diễn ra qua tin rao vặt và các hội nhóm mạng xã hội. Hai bên vốn không quen biết nhau nên phải chọn giữa hai cách thanh toán đều có rủi ro: chuyển khoản trước, người mua có thể mất tiền; hoặc giao hàng thu tiền hộ (COD), người bán có thể bị từ chối nhận hàng. Các sàn thương mại điện tử lớn xử lý vấn đề này bằng cách giữ tiền trung gian và phân xử khiếu nại. Cách làm đó đòi hỏi chi phí vận hành cao và quy trình nặng nề, không phù hợp với người chỉ cần bán một vài món đồ.

Xuất phát từ thực tiễn này, nhóm chúng em thực hiện đề tài “Xây dựng hệ thống thương mại điện tử theo kiến trúc microservice, có tích hợp AI agent hỗ trợ người dùng tìm kiếm” là một hệ thống C2C dành cho các món hàng cũ/đã qua sử dụng. Hệ thống được thiết kế theo hai ràng buộc: hệ thống không giữ tiền của người dùng và không phân xử từng vụ việc. Hình thức giao dịch duy nhất là COD đồng kiểm, trong đó người mua được kiểm tra hàng cùng shipper trước khi thanh toán. Rủi ro sẽ được kiểm soát dựa trên thống kê hành vi của người dùng.

Về mặt nghiên cứu, nhóm tập trung tìm hiểu ba nội dung: các quy trình nghiệp vụ của một trang thương mại điện tử, kỹ thuật lập trình theo kiến trúc microservice, và ứng dụng trợ lý AI để nâng cao trải nghiệm người dùng trên hệ thống. Về mặt thực hiện, nhóm phân tích và thiết kế hệ thống, xây dựng các tính năng ở phía giao diện người dùng, xây dựng phần backend theo mô hình microservice, đồng thời phân tích cụ thể vai trò của trợ lý AI.

Đối tượng nghiên cứu của đề tài là hệ thống giao dịch hàng đã qua sử dụng giữa cá nhân với cá nhân, vận hành theo hình thức COD đồng kiểm và được xây dựng trên kiến trúc microservice. Phạm vi nghiên cứu tập trung vào mô hình nghiệp vụ, thiết kế hệ thống, các phân hệ nền của backend, ứng dụng Android và nguyên lý hoạt động của trợ lý AI.

#pagebreak()

#sechead([KẾ HOẠCH THỰC HIỆN CÔNG VIỆC NHÓM], outlined: false)
#table(
  inset: (x: 6pt, y: 5pt),
  columns: (0.9cm, 1fr, 3.2cm, 2.1cm, 2.6cm),
  table.header([*STT*], [*Nội dung công việc*], [*Người thực hiện*], [*Thời gian*], [*Mức độ hoàn thành*]),
  [1], [Khảo sát Chợ Tốt, Facebook Marketplace, Shopee; xây dựng mô hình nghiệp vụ], [Cả nhóm], [Tuần 1], [Hoàn thành],
  [2], [Đặc tả ca sử dụng, quy tắc nghiệp vụ, yêu cầu chức năng và phi chức năng], [Cả nhóm], [Tuần 1–2], [Hoàn thành],
  [3], [Thiết kế kiến trúc 12 phân hệ, mô hình dữ liệu; nền tảng dùng chung và công cụ kiểm thử], [Đậu Văn Đăng Khoa], [Tuần 2–3], [Hoàn thành],
  [4], [Phân hệ đăng nhập, tài khoản, nhân viên], [Đậu Văn Đăng Khoa], [Tuần 2–3], [Hoàn thành],
  [5], [Phân hệ trả giá và đơn COD tự gửi], [Đậu Văn Đăng Khoa], [Tuần 3–4], [Hoàn thành],
  [6], [Phân hệ ảnh và tin đăng (danh mục, địa giới)], [Hồ Công Toản], [Tuần 2–4], [Hoàn thành],
  [7], [Phân hệ trò chuyện thời gian thực], [Đậu Văn Đăng Khoa, Nguyễn Tấn Khoa], [Tuần 3–4], [Hoàn thành],
  [8], [Thiết kế tìm kiếm theo ngữ nghĩa và trợ lý AI hỗ trợ người mua], [Hồ Công Toản], [Tuần 3–4], [Hoàn thành thiết kế],
  [9], [Nguyên mẫu ứng dụng Android trên dữ liệu giả lập], [Nguyễn Tấn Khoa], [Tuần 1–4], [Hoàn thành nguyên mẫu],
  [10], [Kiểm thử trọn quy trình các phân hệ đã làm; viết báo cáo định kỳ 1], [Cả nhóm], [Tuần 4], [Hoàn thành],
)

// ============================================================
//  RUỘT — đánh số trang Ả Rập
// ============================================================
#set page(numbering: "1")
#counter(page).update(1)

// ---- Các chương (template tự ngắt trang trước mỗi chương) --
#include "chapters/01-gioi-thieu-de-tai.typ"
#include "chapters/02-khao-sat-va-co-so-ly-thuyet.typ"
#include "chapters/03-phan-tich-va-thiet-ke-he-thong.typ"
#include "chapters/04-hien-thuc-va-trien-khai-he-thong.typ"
#include "chapters/05-kiem-thu-danh-gia.typ"

#pagebreak()
#sechead([DANH MỤC TÀI LIỆU THAM KHẢO])

// Danh mục chung của cả ba báo cáo, số thứ tự cố định, tách theo ngôn ngữ
#let nhom-tltk(ten) = block(above: 0.9em, below: 0.4em)[#strong(ten)]
#set par(leading: 0.5em)
#set text(size: 11.5pt)
#let tltk(tu, ..muc) = enum(numbering: n => "[" + str(n + tu - 1) + "]", spacing: 0.6em, ..muc)

#nhom-tltk[Tiếng Việt]
#tltk(1,
  [Quốc hội nước Cộng hòa xã hội chủ nghĩa Việt Nam, Luật Bảo vệ quyền lợi người tiêu dùng số 19/2023/QH15, Công báo, Hà Nội (2023).],
  [Quốc hội nước Cộng hòa xã hội chủ nghĩa Việt Nam, Luật Thương mại điện tử số 122/2025/QH15, Công báo, Hà Nội (2025).],
)

#nhom-tltk[Tiếng Anh]
#tltk(3,
  [Burckhardt S., Gillum C., Justo D., Kallas K., McMahon C., Meiklejohn C. S., Durable Functions: Semantics for Stateful Serverless, Proceedings of the ACM on Programming Languages, vol. 5, OOPSLA, article 133, pp. 1–27 (2021).],
  [Chen J., Xiao S., Zhang P., Luo K., Lian D., Liu Z., M3-Embedding: Multi-Linguality, Multi-Functionality, Multi-Granularity Text Embeddings Through Self-Knowledge Distillation, Findings of the Association for Computational Linguistics: ACL 2024, pp. 2318–2335, Bangkok, Thailand (2024).],
  [Cormack G. V., Clarke C. L. A., Büttcher S., Reciprocal Rank Fusion Outperforms Condorcet and Individual Rank Learning Methods, Proceedings of the 32nd International ACM SIGIR Conference, pp. 758–759, Boston, USA (2009).],
  [Garcia-Molina H., Salem K., Sagas, ACM SIGMOD Record, vol. 16, no. 3, pp. 249–259 (1987).],
  [Helland P., Idempotence Is Not a Medical Condition, ACM Queue, vol. 10, no. 4, pp. 30–46 (2012).],
  [Kleppmann M., Designing Data-Intensive Applications, O'Reilly Media, Sebastopol, CA, USA (2017).],
  [Malkov Y. A., Yashunin D. A., Efficient and Robust Approximate Nearest Neighbor Search Using Hierarchical Navigable Small World Graphs, IEEE Transactions on Pattern Analysis and Machine Intelligence, vol. 42, no. 4, pp. 824–836 (2020).],
  [Newman S., Building Microservices: Designing Fine-Grained Systems, 2nd ed., O'Reilly Media, Sebastopol, CA, USA (2021).],
  [Richardson C., Microservices Patterns: With Examples in Java, Manning Publications, Shelter Island, NY, USA (2018).],
  [Yao S., Zhao J., Yu D., Du N., Shafran I., Narasimhan K., Cao Y., ReAct: Synergizing Reasoning and Acting in Language Models, International Conference on Learning Representations (ICLR), Kigali, Rwanda (2023).],
)

#nhom-tltk[Website]
#tltk(13,
  [Android Developers, Guide to app architecture, https:\/\/developer.android.com/topic/architecture.],
  [Giao Hàng Nhanh, GHN Developer API Documentation, https:\/\/api.ghn.vn.],
  [Giao Hàng Tiết Kiệm, GHTK OpenAPI Documentation, https:\/\/docs.giaohangtietkiem.vn.],
  [OpenAPI Initiative, OpenAPI Specification v3.2.0, https:\/\/spec.openapis.org/oas/v3.2.0.],
  [pgvector: Open-Source Vector Similarity Search for PostgreSQL, https:\/\/github.com/pgvector/pgvector.],
  [Restate Documentation: Durable Execution Engine, https:\/\/docs.restate.dev.],
)
