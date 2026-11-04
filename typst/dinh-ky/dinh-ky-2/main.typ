// ============================================================
//  BÁO CÁO ĐỊNH KỲ 2 — ĐỒ ÁN TỐT NGHIỆP ĐẠI HỌC
//  Giai đoạn 2: tuần 5–8. Chuẩn quyển báo cáo PTIT.
// ============================================================
#import "../../common/style-quyen.typ": *
#import "../../common/info.typ" as info

#show: quyen.with(
  tieu-de: ("BÁO CÁO ĐỊNH KỲ 2", "ĐỒ ÁN TỐT NGHIỆP", "ĐẠI HỌC"),
  chay: "Đồ án tốt nghiệp Đại học",
  thoi-diem: "Tháng 11/2026",
)

#set page(numbering: "i")
#counter(page).update(1)

#sechead([LỜI CẢM ƠN], outlined: false)

Chúng em xin chân thành cảm ơn quý Thầy, Cô Khoa Công nghệ Thông tin, Học viện Công nghệ Bưu chính Viễn thông Cơ sở tại TP. Hồ Chí Minh, và thầy ThS. Nguyễn Đức Thịnh đã theo dõi tiến độ và góp ý cho nhóm sau báo cáo định kỳ 1.

Báo cáo khó tránh khỏi thiếu sót, chúng em mong nhận được ý kiến của quý Thầy, Cô để hoàn thiện đồ án ở giai đoạn cuối.

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
  inset: (x: 8pt, y: 4pt),
  columns: (auto, 1.5fr, 2fr),
  align: (left, left, left),
  table.header([*Viết tắt*], [*Cụm từ đầy đủ*], [*Ý nghĩa*]),
  [AI], [Artificial Intelligence], [Trí tuệ nhân tạo],
  [BR], [Business Rule], [Quy tắc nghiệp vụ (mã BR-xx)],
  [C2C], [Consumer to Consumer], [Giao dịch giữa các cá nhân],
  [CCCD], [], [Căn cước công dân],
  [COD], [Cash on Delivery], [Thanh toán khi nhận hàng],
  [GHN], [], [Công ty Giao Hàng Nhanh],
  [GHTK], [], [Công ty Giao Hàng Tiết Kiệm],
  [LLM], [Large Language Model], [Mô hình ngôn ngữ lớn],
  [MRR], [Mean Reciprocal Rank], [Trung bình nghịch đảo thứ hạng],
  [nDCG], [Normalized Discounted Cumulative Gain], [Độ đo chất lượng xếp hạng có chuẩn hóa],
  [NFR], [Non-Functional Requirement], [Yêu cầu phi chức năng (mã NFR-xx)],
  [REQ], [Requirement], [Yêu cầu chức năng (mã REQ-xx)],
  [TC], [Test Case], [Ca kiểm thử (mã TC-xx)],
  [UC], [Use Case], [Ca sử dụng (mã UC-xx)],
)

#pagebreak()

#danh-muc-bang()
#danh-muc-hinh()
#pagebreak()

#sechead([KẾ HOẠCH THỰC HIỆN CÔNG VIỆC NHÓM], outlined: false)

#v(0.5cm)
#table(
  columns: (0.9cm, 1fr, 3.1cm, 1.8cm, 2.8cm),
  inset: 7pt,
  align: (center, left, left, center, center),
  table.header([*STT*], [*Nội dung công việc*], [*Người thực hiện*], [*Thời gian*], [*Mức độ hoàn thành*]),
  [1], [Rà soát góp ý định kỳ 1, điều chỉnh đơn COD và hạn mức theo bậc], [Cả nhóm], [Tuần 5], [Hoàn thành],
  [2], [Liên kết tài khoản GHTK/GHN, báo phí, tạo và hủy vận đơn], [Đậu Văn Đăng Khoa], [Tuần 5–6], [Hoàn thành],
  [3], [Nhận trạng thái vận đơn do hãng báo về, quy đổi trạng thái], [Đậu Văn Đăng Khoa], [Tuần 6–7], [Hoàn thành],
  [4], [Chỉ mục và tìm kiếm lai cho tin đăng], [Hồ Công Toản], [Tuần 5–6], [Hoàn thành],
  [5], [AI agent tìm kiếm bằng câu tự nhiên], [Hồ Công Toản], [Tuần 6–8], [Hoàn thành],
  [6], [Đánh giá, ghi nhận sự cố, điểm uy tín và chế tài tự động], [Hồ Công Toản], [Tuần 7–8], [Hoàn thành],
  [7], [Nối ứng dụng di động với dịch vụ nền], [Nguyễn Tấn Khoa], [Tuần 5–7], [Hoàn thành],
  [8], [Màn hình tạo đơn, chọn hãng, hồ sơ uy tín], [Nguyễn Tấn Khoa], [Tuần 7–8], [Hoàn thành],
  [9], [Kiểm thử các kịch bản nghiệp vụ], [Cả nhóm], [Tuần 8], [Đang thực hiện],
  [10], [Viết báo cáo định kỳ 2], [Cả nhóm], [Tuần 8], [Hoàn thành],
)

// ============================================================
//  RUỘT — đánh số trang Ả Rập
// ============================================================
#set page(numbering: "1")
#counter(page).update(1)

#pagebreak()
#sechead([MỞ ĐẦU])

Giai đoạn 1 của đồ án "#info.de-tai" đã xây dựng mô hình nghiệp vụ, các chức năng đăng tin, thương lượng, đơn COD tự gửi và nguyên mẫu ứng dụng di động. Giai đoạn 2 (tuần 5–8) kết nối GHTK và GHN, thêm tìm kiếm bằng AI agent, phần uy tín và chế tài, và đưa ứng dụng chạy trên dữ liệu thật.

Chương 1 tóm tắt mục tiêu và các điều chỉnh so với định kỳ 1. Chương 2 trình bày thiết kế và các chức năng đã hiện thực. Chương 3 nêu các kịch bản kiểm thử. Phần kết luận nêu kết quả, khó khăn và kế hoạch giai đoạn 3.

#include "chapters/01-tong-quan-tien-do.typ"
#include "chapters/02-thiet-ke-hien-thuc.typ"
#include "chapters/03-kiem-thu.typ"
#include "chapters/04-ket-luan.typ"

#pagebreak()
#sechead([DANH MỤC TÀI LIỆU THAM KHẢO])

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
  [Helland P., Idempotence Is Not a Medical Condition, ACM Queue, vol. 10, no. 4, pp. 30–46 (2012).],
  [Yao S., Zhao J., Yu D., Du N., Shafran I., Narasimhan K., Cao Y., ReAct: Synergizing Reasoning and Acting in Language Models, International Conference on Learning Representations (ICLR), Kigali, Rwanda (2023).],
)

#nhom-tltk[Website]
#enum(
  numbering: n => "[" + str(n) + "]",
  start: 8,
  [Android Developers, Guide to app architecture, https:\/\/developer.android.com/topic/architecture.],
  [Giao Hàng Nhanh, GHN Developer API Documentation, https:\/\/api.ghn.vn.],
  [Giao Hàng Tiết Kiệm, GHTK OpenAPI Documentation, https:\/\/docs.giaohangtietkiem.vn.],
  [pgvector: Open-Source Vector Similarity Search for PostgreSQL, https:\/\/github.com/pgvector/pgvector.],
  [Restate Documentation: Durable Execution Engine, https:\/\/docs.restate.dev.],
)
