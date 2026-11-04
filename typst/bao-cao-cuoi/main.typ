// ============================================================
//  ĐỒ ÁN TỐT NGHIỆP ĐẠI HỌC — BÁO CÁO CUỐI (Tháng 12/2026)
//  Đề tài đọc từ common/info.typ. Thứ tự phần đầu theo hướng dẫn
//  ĐATN (QĐ 449/QĐ-HV): phê duyệt, giao nhiệm vụ, lời cảm ơn,
//  lời cam đoan, mục lục, chữ viết tắt, danh mục bảng và hình;
//  sau đó mở đầu, bảng phân công, 7 chương và tài liệu tham khảo.
//  Biên dịch: make cuoi   (Makefile ở thư mục typst/)
// ============================================================
#import "../common/style-quyen.typ": *
#import "../common/info.typ" as info

#show: quyen.with(
  tieu-de: ("ĐỒ ÁN", "TỐT NGHIỆP ĐẠI HỌC"),
  chay: "Đồ án tốt nghiệp Đại học",
  thoi-diem: "Tháng 12/2026",
)

// Khối ký tên canh phải dùng chung cho lời cảm ơn và lời cam đoan
#let ky-nhom = {
  v(1cm)
  align(right, block(width: 55%, align(center)[
    #emph[TP.HCM, ngày … tháng 12 năm 2026] \
    #strong[ĐẠI DIỆN NHÓM SINH VIÊN] \
    #emph[(Ký và ghi rõ họ tên)]
  ]))
}

#set page(numbering: "i")
#counter(page).update(1)

// ---------------- PHÊ DUYỆT ----------------
#sechead([PHÊ DUYỆT], outlined: false)

#align(center)[Đồ án tốt nghiệp với đề tài “#info.de-tai” do nhóm #info.ma-nhom, lớp #info.lop thực hiện, đã được giáo viên hướng dẫn xem xét và đồng ý cho bảo vệ trước hội đồng.]

#v(0.6cm)
#set par(first-line-indent: 0pt)
Nhận xét của giáo viên hướng dẫn:

#for _ in range(8) [#box(width: 1fr, repeat[.]) \ ]

Điểm đánh giá: #box(width: 4cm, repeat[.]) (bằng chữ: #box(width: 1fr, repeat[.]))

#v(1cm)
#align(right, block(width: 55%, align(center)[
  #emph[TP.HCM, ngày … tháng 12 năm 2026] \
  #strong[GIÁO VIÊN HƯỚNG DẪN] \
  #emph[(Ký và ghi rõ họ tên)] \
  #v(2cm)
  #info.gvhd
]))
#set par(first-line-indent: (amount: 1cm, all: true))

#pagebreak()

// ---------------- GIAO NHIỆM VỤ ----------------
#sechead([GIAO NHIỆM VỤ ĐỀ TÀI], outlined: false)

#table(
  columns: (3.6cm, 1fr),
  fill: none,
  inset: (x: 8pt, y: 7pt),
  [*Tên đề tài*], [#info.de-tai],
  [*Nhóm*], [#info.ma-nhom: #info.sinh-vien.map(((t, m)) => [#t (#m)]).join(", ")],
  [*Lớp*], [#info.lop],
  [*Giáo viên hướng dẫn*], [#info.gvhd],
  [*Nội dung nhiệm vụ*], align(left)[
    #set enum(indent: 0pt)
    1. Khảo sát giao dịch C2C hàng đã qua sử dụng tại Việt Nam, đề xuất mô hình nghiệp vụ trong đó sàn không giữ tiền và không phán xử.
    2. Phân tích, đặc tả yêu cầu bằng UML: ca sử dụng, quy tắc nghiệp vụ, yêu cầu chức năng và phi chức năng.
    3. Thiết kế hệ thống theo các phân hệ nghiệp vụ: tài khoản và xác minh danh tính, tin đăng, tìm kiếm, thương lượng và đơn COD, vận chuyển, uy tín và chế tài, thông báo.
    4. Hiện thực dịch vụ nền và ứng dụng Android cho người mua, người bán; tích hợp hãng vận chuyển GHTK, GHN cho đơn COD đồng kiểm và AI agent hỗ trợ tìm hàng bằng câu tự nhiên.
    5. Kiểm thử trên hạ tầng thật, đánh giá kết quả và viết báo cáo.
  ],
  [*Sản phẩm*], [Hệ thống dịch vụ nền, ứng dụng Android, bộ kịch bản kiểm thử và quyển báo cáo đồ án.],
  [*Thời gian thực hiện*], [12 tuần, từ tháng 9/2026 đến tháng 12/2026.],
)

#v(0.8cm)
#grid(
  columns: (1fr, 1fr, 1fr),
  align: center,
  [*Giáo viên hướng dẫn* \ #emph[(Ký và ghi rõ họ tên)]],
  [*Trưởng bộ môn* \ #emph[(Ký và ghi rõ họ tên)]],
  [*Khoa* \ #emph[(Ký và ghi rõ họ tên)]],
)

#pagebreak()

// ---------------- LỜI CẢM ƠN ----------------
#sechead([LỜI CẢM ƠN], outlined: false)

Chúng em xin cảm ơn Ban Giám hiệu #info.truong-thuong #info.co-so-ngan và các thầy cô Khoa Công nghệ Thông tin 2 đã giảng dạy và tạo điều kiện để nhóm thực hiện đồ án tốt nghiệp này.

Chúng em xin gửi lời cảm ơn đến thầy #info.gvhd đã hướng dẫn nhóm trong suốt mười hai tuần, góp ý cho từng giai đoạn từ mô hình nghiệp vụ, kiến trúc cho đến cách kiểm thử và trình bày báo cáo.

Do thời gian và kinh nghiệm còn hạn chế, đồ án khó tránh khỏi thiếu sót. Nhóm mong nhận được ý kiến của quý thầy cô để hoàn thiện đề tài.

#ky-nhom

#pagebreak()

// ---------------- LỜI CAM ĐOAN ----------------
#sechead([LỜI CAM ĐOAN], outlined: false)

Chúng em xin cam đoan rằng đây là đồ án do nhóm sinh viên thực hiện dưới sự hướng dẫn của thầy #info.gvhd. Các nội dung, mã nguồn và kết quả trình bày trong đồ án là trung thực, do nhóm tự xây dựng và chưa từng được công bố trong bất kỳ công trình nào khác. Những tài liệu, số liệu và ý tưởng tham khảo từ các nguồn khác đều được trích dẫn và ghi rõ trong danh mục tài liệu tham khảo.

Nếu phát hiện có bất kỳ sự gian lận nào, nhóm xin hoàn toàn chịu trách nhiệm trước Hội đồng và Học viện.

#ky-nhom

#pagebreak()

#muc-luc()
#pagebreak()

// ---------------- CHỮ VIẾT TẮT ----------------
#sechead([DANH MỤC CÁC KÝ HIỆU VÀ CHỮ VIẾT TẮT], outlined: false)

#table(
  inset: (x: 7pt, y: 3.5pt),
  columns: (auto, 1.4fr, 1.6fr),
  table.header([Viết tắt], [Cụm từ đầy đủ], [Ý nghĩa]),
  [AD], [Activity Diagram], [Sơ đồ hoạt động (mã AD-xx)],
  [AI], [Artificial Intelligence], [Trí tuệ nhân tạo],
  [API], [Application Programming Interface], [Giao diện lập trình ứng dụng],
  [B2C], [Business to Consumer], [Giao dịch giữa doanh nghiệp và người tiêu dùng],
  [BR], [Business Rule], [Quy tắc nghiệp vụ (mã BR-xx)],
  [C2C], [Consumer to Consumer], [Giao dịch giữa các cá nhân],
  [CCCD], [], [Căn cước công dân],
  [COD], [Cash on Delivery], [Thanh toán khi nhận hàng],
  [CSDL], [], [Cơ sở dữ liệu],
  [eKYC], [electronic Know Your Customer], [Xác minh danh tính điện tử],
  [GHN], [Giao Hàng Nhanh], [Hãng vận chuyển],
  [GHTK], [Giao Hàng Tiết Kiệm], [Hãng vận chuyển],
  [GPS], [Global Positioning System], [Hệ thống định vị toàn cầu],
  [HNSW], [Hierarchical Navigable Small World], [Đồ thị phân tầng cho tìm lân cận gần đúng],
  [LLM], [Large Language Model], [Mô hình ngôn ngữ lớn],
  [MRR], [Mean Reciprocal Rank], [Độ đo thứ hạng trung bình của kết quả đúng đầu tiên],
  [NFC], [Near Field Communication], [Giao tiếp tầm gần, dùng đọc chip CCCD],
  [NFR], [Non-Functional Requirement], [Yêu cầu phi chức năng (mã NFR-xx)],
  [OTP], [One-Time Password], [Mã dùng một lần],
  [REQ], [Requirement], [Yêu cầu chức năng (mã REQ-xx)],
  [RRF], [Reciprocal Rank Fusion], [Hợp nhất xếp hạng theo nghịch đảo thứ hạng],
  [SDK], [Software Development Kit], [Bộ công cụ phát triển phần mềm],
  [SMS], [Short Message Service], [Tin nhắn văn bản],
  [SPX], [Shopee Express], [Hãng vận chuyển],
  [TC], [Test Case], [Ca kiểm thử (mã TC-xx)],
  [TMĐT], [], [Thương mại điện tử],
  [UC], [Use Case], [Ca sử dụng (mã UC-xx)],
  [UML], [Unified Modeling Language], [Ngôn ngữ mô hình hóa thống nhất],
)

#pagebreak()

#danh-muc-bang()
#danh-muc-hinh()

// ============================================================
//  RUỘT — đánh số trang Ả Rập
// ============================================================
#pagebreak()
#set page(numbering: "1")
#counter(page).update(1)

#sechead([MỞ ĐẦU])

Mua bán đồ cũ giữa các cá nhân đã thành thói quen của nhiều người dùng Việt Nam, nhưng giao dịch vẫn diễn ra theo cách thủ công: người mua chuyển khoản trước cho người lạ hoặc hai bên tự thỏa thuận giao nhận tiền mặt, thương lượng qua nhiều ứng dụng nhắn tin, và khi có sự cố thì không có quy tắc chung nào để dựa vào. Phần lớn rủi ro ở đây không đến từ công nghệ mà từ việc không ai biết trước hàng có đúng như mô tả và tiền có đến tay hay không. Đó là lý do nhóm chọn đề tài "#info.de-tai".

Mục đích của đồ án là xây dựng ShopNexus, một sàn C2C cho hàng đã qua sử dụng, trong đó giao dịch duy nhất trong ứng dụng là giao COD có đồng kiểm qua tài khoản GHTK hoặc GHN của chính người bán. Sàn không giữ tiền và không phán xử từng vụ việc; thay vào đó tin đăng là một tập cam kết gồm tình trạng, thông tin người bán ghi và ảnh, mọi dữ kiện giao nhận do hãng vận chuyển báo về, và uy tín cùng chế tài được tính tự động từ thống kê. Bên cạnh đó, đồ án đưa vào một AI agent giúp người mua tìm hàng bằng câu tự nhiên thay vì tự chọn hơn mười bộ lọc.

Về tình hình nghiên cứu, các sàn lớn trong nước giải quyết niềm tin bằng cách giữ tiền của người mua, điều đòi hỏi giấy phép trung gian thanh toán và một bộ phận xử lý khiếu nại có quy mô tăng theo số đơn; các nền tảng rao vặt thì chỉ kết nối thông tin và để hai bên tự lo phần còn lại. Hướng dựa vào dữ kiện do hãng vận chuyển báo về và thống kê hành vi để thay cho phân xử từng vụ chưa được các nền tảng phổ biến trong nước áp dụng cho hàng đã qua sử dụng. Ở phía tìm kiếm, việc kết hợp tìm theo ngữ nghĩa với tìm theo từ khóa [4][5] cho phép hiểu câu hỏi tự nhiên của người mua thay vì chỉ khớp chữ.

Đối tượng nghiên cứu là quy trình mua bán hàng đã qua sử dụng giữa các cá nhân, các tác nhân tham gia (người mua, người bán, hãng vận chuyển, điều phối viên, quản trị viên) và các quy tắc nghiệp vụ giúp hai bên tin nhau khi sàn không giữ tiền. Phạm vi gồm hệ thống dịch vụ nền, ứng dụng Android cho người dùng và chức năng quản lý cho điều phối viên; không gồm thanh toán tạm giữ, ứng dụng iOS hay web cho khách hàng, giao hàng quốc tế và gian hàng doanh nghiệp.

Phương pháp thực hiện gồm các bước sau. Nhóm khảo sát thói quen mua bán đồ cũ và các nền tảng đang có để rút ra những rủi ro chính của người mua và người bán. Từ đó nhóm mô hình hóa nghiệp vụ bằng UML với sơ đồ ca sử dụng, sơ đồ hoạt động và sơ đồ trạng thái, và ghi các quy tắc nghiệp vụ thành danh mục có mã. Hệ thống được chia theo phân hệ nghiệp vụ để mỗi nhóm quy tắc có một nơi chịu trách nhiệm. Công việc chia thành ba giai đoạn bốn tuần, mỗi giai đoạn kết thúc bằng một phiên bản chạy được. Cuối cùng, hệ thống được kiểm thử theo kịch bản nghiệp vụ, đi từ đăng tin đến giao nhận và đánh giá.

Ngoài phần mở đầu và kết luận, đồ án gồm sáu chương. Chương 1 trình bày bối cảnh, khảo sát và mô hình nghiệp vụ đề xuất. Chương 2 trình bày cơ sở lý thuyết và công nghệ. Chương 3 phân tích và đặc tả yêu cầu. Chương 4 trình bày thiết kế kiến trúc, dữ liệu và luồng xử lý. Chương 5 mô tả việc hiện thực và triển khai. Chương 6 trình bày kiểm thử và đánh giá.

#pagebreak()
#sechead([BẢNG PHÂN CÔNG NHIỆM VỤ NHÓM THỰC HIỆN])

#table(
  columns: (0.9cm, 1fr, 3.3cm, 1.7cm, 2.3cm),
  inset: (x: 6pt, y: 5pt),
  align: (center, left, left, center, center),
  table.header([STT], [Nội dung công việc], [Người thực hiện], [Thời gian (tuần)], [Mức độ hoàn thành]),
  [1], [Khảo sát giao dịch C2C hàng cũ, xây dựng mô hình nghiệp vụ], [Cả nhóm], [1], [Hoàn thành],
  [2], [Phân tích, đặc tả ca sử dụng, quy tắc nghiệp vụ, yêu cầu], [Cả nhóm], [1–2], [Hoàn thành],
  [3], [Thiết kế tổng thể hệ thống và chia phân hệ nghiệp vụ], [Đậu Văn Đăng Khoa], [2–3], [Hoàn thành],
  [4], [Nguyên mẫu toàn bộ màn hình ứng dụng Android, design system], [Nguyễn Tấn Khoa], [2–4], [Hoàn thành],
  [5], [Phân hệ tài khoản, đăng nhập và quản lý nhân sự điều phối], [Đậu Văn Đăng Khoa], [3–4], [Hoàn thành],
  [6], [Phân hệ tin đăng và ảnh hàng hóa], [Hồ Công Toản], [3–4], [Hoàn thành],
  [7], [Phân hệ thương lượng giá, đặt đơn COD và trò chuyện], [Đậu Văn Đăng Khoa, Nguyễn Tấn Khoa], [4–5], [Hoàn thành],
  [8], [Phân hệ thanh toán COD và kết nối hãng vận chuyển GHTK, GHN], [Đậu Văn Đăng Khoa], [5–6], [Hoàn thành],
  [9], [Phân hệ tìm kiếm, AI agent hỗ trợ tìm hàng và lưu tin], [Hồ Công Toản], [5–7], [Hoàn thành],
  [10], [Phân hệ đánh giá, ghi nhận sự cố, uy tín và chế tài], [Hồ Công Toản], [6–8], [Hoàn thành],
  [11], [Kết nối các màn hình ứng dụng Android với hệ thống], [Nguyễn Tấn Khoa], [6–8], [Hoàn thành],
  [12], [Phân hệ xác minh danh tính, thông báo và gói người bán], [Hồ Công Toản, Nguyễn Tấn Khoa], [9–10], [Hoàn thành],
  [13], [Đánh giá AI agent, kiểm thử theo kịch bản nghiệp vụ và kiểm thử giao diện], [Cả nhóm], [10–11], [Hoàn thành],
  [14], [Triển khai hệ thống], [Đậu Văn Đăng Khoa], [11–12], [Hoàn thành],
  [15], [Viết báo cáo đồ án], [Cả nhóm], [11–12], [Hoàn thành],
)

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

// Danh mục dựng THỦ CÔNG, không dùng #bibliography, vì quy cách đòi tách theo
// ngôn ngữ (Tiếng Việt / Tiếng Anh / Website), điều bibliography() của Typst
// không làm được. Số thứ tự chạy liên tục qua 3 nhóm, khớp với trích dẫn [n]
// gõ tay trong thân bài. Danh từ riêng giữ nguyên ngôn ngữ gốc.
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
  numbering: n => "[" + str(n) + "]",
  start: 3,
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
#enum(
  numbering: n => "[" + str(n) + "]",
  start: 13,
  [Android Developers, Guide to app architecture, https:\/\/developer.android.com/topic/architecture.],
  [Giao Hàng Nhanh, GHN Developer API Documentation, https:\/\/api.ghn.vn.],
  [Giao Hàng Tiết Kiệm, GHTK OpenAPI Documentation, https:\/\/docs.giaohangtietkiem.vn.],
  [OpenAPI Initiative, OpenAPI Specification v3.2.0, https:\/\/spec.openapis.org/oas/v3.2.0.],
  [pgvector: Open-Source Vector Similarity Search for PostgreSQL, https:\/\/github.com/pgvector/pgvector.],
  [Restate Documentation: Durable Execution Engine, https:\/\/docs.restate.dev.],
)
