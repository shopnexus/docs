// ============================================================
//  BÁO CÁO ĐỊNH KỲ 1 — ĐỒ ÁN TỐT NGHIỆP ĐẠI HỌC
//  Giai đoạn 1 (tuần 1–4), nộp Tháng 10/2026.
//  Mô hình: Chuẩn quyển báo cáo PTIT (Phụ lục 3, QĐ 449/QĐ-HV)
//  Biên dịch: make dinh-ky   (Makefile ở thư mục typst/)
// ============================================================
#import "../../common/style-quyen.typ": *

#show: quyen.with(
  tieu-de: ("BÁO CÁO ĐỊNH KỲ 1", "ĐỒ ÁN TỐT NGHIỆP", "ĐẠI HỌC"),
  chay: "Đồ án tốt nghiệp Đại học",
  thoi-diem: "Tháng 10/2026",
)

#set page(numbering: "i")
#counter(page).update(1)

#sechead([LỜI CẢM ƠN], outlined: false)

Chúng em xin chân thành cảm ơn Ban Giám hiệu Học viện Công nghệ Bưu chính Viễn thông Cơ sở tại TP. Hồ Chí Minh và quý Thầy, Cô Khoa Công nghệ Thông tin đã trang bị cho chúng em kiến thức nền tảng trong quá trình học tập.

Chúng em xin cảm ơn thầy ThS. Nguyễn Đức Thịnh đã tận tình hướng dẫn và góp ý cho nhóm trong giai đoạn đầu của đề tài. Báo cáo chắc chắn còn thiếu sót, chúng em mong nhận được góp ý của quý Thầy, Cô.

#v(1.5cm)
#align(right, block(width: 45%, align(center)[
  *Sinh viên thực hiện* \
  #v(0.5em)
  Đậu Văn Đăng Khoa \
  Hồ Công Toản \
  Nguyễn Tấn Khoa
]))

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
#danh-muc-hinh()
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
  [5], [Phân hệ thương lượng giá và đơn COD tự gửi], [Đậu Văn Đăng Khoa], [Tuần 3–4], [Hoàn thành],
  [6], [Phân hệ ảnh và tin đăng (danh mục, địa giới)], [Hồ Công Toản], [Tuần 2–4], [Hoàn thành],
  [7], [Phân hệ trò chuyện thời gian thực], [Đậu Văn Đăng Khoa, Nguyễn Tấn Khoa], [Tuần 3–4], [Hoàn thành],
  [8], [Thiết kế tìm kiếm theo ngữ nghĩa và AI agent hỗ trợ người mua], [Hồ Công Toản], [Tuần 3–4], [Hoàn thành thiết kế],
  [9], [Nguyên mẫu ứng dụng Android trên dữ liệu giả lập], [Nguyễn Tấn Khoa], [Tuần 1–4], [Hoàn thành nguyên mẫu],
  [10], [Kiểm thử trọn quy trình các phân hệ đã làm; viết báo cáo định kỳ 1], [Cả nhóm], [Tuần 4], [Hoàn thành],
)

// ============================================================
//  RUỘT — đánh số trang Ả Rập
// ============================================================
#set page(numbering: "1")
#counter(page).update(1)

#pagebreak()
#sechead([MỞ ĐẦU])

Mua bán đồ cũ giữa các cá nhân ở Việt Nam chủ yếu diễn ra qua tin rao vặt và hội nhóm mạng xã hội. Hai người lạ phải chọn giữa chuyển khoản trước, rủi ro cho người mua, và giao hàng thu tiền hộ, rủi ro cho người bán. Các sàn lớn xử lý bằng cách giữ tiền và phân xử khiếu nại, cách làm tốn kém và nặng nề với người chỉ bán một món đồ.

Đề tài xây dựng ShopNexus, sàn C2C cho hàng đã qua sử dụng với hai ràng buộc: sàn không giữ tiền và không phân xử từng vụ việc. Giao dịch duy nhất là COD đồng kiểm, rủi ro được kiểm soát bằng quyền dựa trên thống kê hành vi. Báo cáo định kỳ 1 trình bày kết quả tuần 1 đến tuần 4: mô hình nghiệp vụ, phân tích yêu cầu, thiết kế hệ thống, nguyên mẫu ứng dụng Android và bảy phân hệ nền đầu tiên. Kết nối với hãng vận chuyển, tìm kiếm, AI agent và uy tín thuộc giai đoạn 2.

// ---- Các chương (template tự ngắt trang trước mỗi chương) --
#include "chapters/01-tong-quan.typ"
#include "chapters/02-phan-tich-yeu-cau.typ"
#include "chapters/03-thiet-ke-he-thong.typ"
#include "chapters/04-ket-luan.typ"

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
