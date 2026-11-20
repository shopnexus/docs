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
  [C2C], [Consumer to Consumer], [Giao dịch giữa các cá nhân],
  [CCCD], [], [Căn cước công dân],
  [COD], [Cash on Delivery], [Giao hàng thu tiền hộ],
  [eKYC], [Electronic Know Your Customer], [Xác minh danh tính điện tử],
  [GHN], [], [Công ty Giao Hàng Nhanh],
  [GHTK], [], [Công ty Giao Hàng Tiết Kiệm],
  [OTP], [One-Time Password], [Mã dùng một lần],
  [TC], [Test Case], [Kịch bản kiểm thử (mã TC-xx)],
  [UC], [Use Case], [Ca sử dụng (mã UC-xx)],
)

#pagebreak()

#danh-muc-bang()
#v(1em)
#danh-muc-hinh()
#pagebreak()

#sechead([KẾ HOẠCH THỰC HIỆN CÔNG VIỆC NHÓM], outlined: false)

#v(0.5cm)
#table(
  columns: (0.9cm, 1fr, 3.1cm, 1.8cm, 2.8cm),
  inset: 7pt,
  align: (center, left, left, center, center),
  table.header([*STT*], [*Nội dung công việc*], [*Người thực hiện*], [*Thời gian*], [*Mức độ hoàn thành*]),
  [1], [Rà soát mô hình nghiệp vụ sau định kỳ 1, rút gọn luồng đơn COD và phần uy tín], [Cả nhóm], [Tuần 5], [Hoàn thành],
  [2], [Môi trường chạy thử và môi trường chính thức trên cụm máy chủ của nhóm], [Đậu Văn Đăng Khoa], [Tuần 5–6], [Hoàn thành],
  [3], [Đăng nhập bằng số điện thoại, email, Google; quản lý thiết bị, xóa tài khoản], [Đậu Văn Đăng Khoa], [Tuần 5–6], [Hoàn thành],
  [4], [Đơn COD qua GHTK, GHN: liên kết tài khoản hãng, tạo vận đơn, nhận trạng thái], [Đậu Văn Đăng Khoa], [Tuần 6–7], [Hoàn thành trên môi trường thử của hãng],
  [5], [Tìm kiếm bằng câu tự nhiên, tìm bằng ảnh, tin tương tự, theo dõi tìm kiếm, báo giảm giá], [Hồ Công Toản], [Tuần 5–7], [Hoàn thành],
  [6], [AI điền tin từ video, ảnh, link Chợ Tốt; gợi ý giá khi đăng tin], [Hồ Công Toản], [Tuần 6–7], [Hoàn thành],
  [7], [Cảnh báo lừa đảo trong trò chuyện, báo cáo vi phạm, đánh giá hai chiều, thông báo], [Hồ Công Toản], [Tuần 6–8], [Hoàn thành],
  [8], [Nối ứng dụng Android với dịch vụ nền, bỏ dữ liệu giả lập], [Nguyễn Tấn Khoa], [Tuần 6–8], [Hoàn thành],
  [9], [Website cho người mua và người bán], [Nguyễn Tấn Khoa], [Tuần 7–8], [Hoàn thành],
  [10], [Phiếu hỗ trợ và trang điều hành cho nhân viên, có trợ lý AI], [Đậu Văn Đăng Khoa, Hồ Công Toản], [Tuần 7–8], [Đang thực hiện],
  [11], [Kiểm thử các kịch bản nghiệp vụ], [Cả nhóm], [Tuần 8], [Đang thực hiện],
  [12], [Viết báo cáo định kỳ 2], [Cả nhóm], [Tuần 8], [Hoàn thành],
)

// ============================================================
//  RUỘT — đánh số trang Ả Rập
// ============================================================
#set page(numbering: "1")
#counter(page).update(1)

#pagebreak()
#sechead([MỞ ĐẦU])

Giai đoạn 1 của đồ án "#info.de-tai" đã xây dựng mô hình nghiệp vụ, đặc tả yêu cầu, nguyên mẫu ứng dụng Android trên dữ liệu giả lập và bảy phân hệ nền đầu tiên. Đơn COD khi đó do người bán tự gửi rồi nhập mã vận đơn bằng tay.

Giai đoạn 2 (tuần 5–8) đưa sản phẩm sang chạy trên dữ liệu thật. Người bán tạo vận đơn GHTK, GHN ngay trong ứng dụng, người mua tìm hàng bằng câu nói tự nhiên, AI điền giúp tin đăng và cảnh báo lừa đảo trong trò chuyện. Ngoài ứng dụng Android, nhóm làm thêm website cho người mua và người bán, và trang điều hành cho nhân viên vận hành. Trong giai đoạn này nhóm cũng rút gọn một số phần của mô hình nghiệp vụ sau khi thử với luồng thật.

Chương 1 so sánh kết quả với kế hoạch và nêu các điều chỉnh mô hình. Chương 2 trình bày các chức năng đã làm theo thứ tự một giao dịch, từ đăng tin tới đánh giá, rồi tới phần của nhân viên. Chương 3 nêu cách kiểm thử và các kịch bản chính. Phần kết luận nêu kết quả, khó khăn và kế hoạch giai đoạn 3.

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
  [Chen J., Xiao S., Zhang P., Luo K., Lian D., Liu Z., M3-Embedding: Multi-Linguality, Multi-Functionality, Multi-Granularity Text Embeddings Through Self-Knowledge Distillation, Findings of the Association for Computational Linguistics: ACL 2024, pp. 2318–2335, Bangkok, Thailand (2024).],
  [Cormack G. V., Clarke C. L. A., Büttcher S., Reciprocal Rank Fusion Outperforms Condorcet and Individual Rank Learning Methods, Proceedings of the 32nd International ACM SIGIR Conference, pp. 758–759, Boston, USA (2009).],
  [Tschannen M., Gritsenko A., Wang X., et al., SigLIP 2: Multilingual Vision-Language Encoders with Improved Semantic Understanding, Localization, and Dense Features, arXiv:2502.14786 (2025).],
  [Yao S., Zhao J., Yu D., Du N., Shafran I., Narasimhan K., Cao Y., ReAct: Synergizing Reasoning and Acting in Language Models, International Conference on Learning Representations (ICLR), Kigali, Rwanda (2023).],
)

#nhom-tltk[Website]
#enum(
  numbering: n => "[" + str(n) + "]",
  start: 7,
  [Android Developers, Guide to app architecture, https:\/\/developer.android.com/topic/architecture.],
  [Giao Hàng Nhanh, GHN Developer API Documentation, https:\/\/api.ghn.vn.],
  [Giao Hàng Tiết Kiệm, GHTK OpenAPI Documentation, https:\/\/docs.giaohangtietkiem.vn.],
)
