// ============================================================
//  BÁO CÁO THỰC TẬP TỐT NGHIỆP — BẢN CUỐI
//  Biên dịch: make cuoi   (Makefile ở thư mục typst/)
//
//  KHUNG SƯỜN — nội dung các chương đang chờ viết.
//  Nguồn tham chiếu: spec/source-of-truth.typ, bao-cao-dinh-ky/, bao-cao-tuan/
// ============================================================
#import "../common/style-quyen.typ": *

#show: quyen.with(
  tieu-de: ("BÁO CÁO", "THỰC TẬP TỐT NGHIỆP ĐẠI HỌC"),
  chay: "Báo cáo Thực tập tốt nghiệp",
  thoi-diem: "Tháng 08 năm 2026",
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
  columns: (auto, 1.5fr, 2fr),
  align: (left, left, left),
  table.header([*Viết tắt*], [*Cụm từ đầy đủ*], [*Ý nghĩa*]),
  [Access token], [—], [Vé truy cập ngắn hạn, đính kèm mỗi lời gọi API để chứng minh danh tính],
  [ANN], [Approximate Nearest Neighbor], [Tìm láng giềng gần đúng (cho tìm kiếm vector)],
  [API], [Application Programming Interface], [Giao diện lập trình ứng dụng],
  [BR], [Business Rule], [Quy tắc nghiệp vụ (đánh mã BR-xxx)],
  [C2C], [Consumer to Consumer], [Giao dịch giữa các cá nhân người dùng],
  [CI/CD], [Continuous Integration / Continuous Deployment], [Tích hợp và triển khai liên tục],
  [CSDL], [—], [Cơ sở dữ liệu],
  [Durable execution], [—], [Thực thi bền: nền tảng bảo đảm một lời gọi chạy tới cùng dù tiến trình gặp sự cố],
  [Durable workflow], [—], [Quy trình bền: quy trình nhiều bước chạy trên nền tảng durable execution],
  [Embedding], [—], [Véc-tơ nhúng biểu diễn ngữ nghĩa của văn bản, dùng cho tìm kiếm ngữ nghĩa],
  [ERD], [Entity–Relationship Diagram], [Sơ đồ thực thể – quan hệ],
  [Ký quỹ], [—], [Cơ chế ký quỹ (trung gian) bảo vệ giao dịch],
  [Guarded write], [—], [Lượt ghi có bảo vệ, nêu đích danh trạng thái nguồn nên một lượt đọc cũ luôn thua],
  [Idempotency key], [—], [Khóa lũy đẳng: định danh do bên gọi đặt để một thao tác chỉ có hiệu lực một lần],
  [Idempotent], [—], [Lũy đẳng: gọi nhiều lần cho cùng kết quả như gọi một lần],
  [JWT], [JSON Web Token], [Chuẩn token xác thực người dùng],
  [NFR], [Non-Functional Requirement], [Yêu cầu phi chức năng],
  [RBAC], [Role-Based Access Control], [Kiểm soát truy cập theo vai trò],
  [REQ], [Requirement], [Yêu cầu chức năng (đánh mã REQ-xxx)],
  [RPC], [Remote Procedure Call], [Lời gọi thủ tục từ xa giữa các dịch vụ],
  [SSE], [Server-Sent Events], [Kênh đẩy sự kiện thời gian thực từ máy chủ],
  [TLS], [Transport Layer Security], [Mã hóa dữ liệu trên đường truyền],
  [UC], [Use Case], [Ca sử dụng (đánh mã UC-xxx)],
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

#v(0.2cm)
#text(size: 11pt)[
  *Mức độ hoàn thành.* #emph[Hoàn thành] — hạng mục đã xong và có sản phẩm hoặc hồ sơ
  kèm theo trong quyển. #emph[Hoàn thành cơ bản] — phần lõi đã xong và chạy được, nhưng
  còn hạn chế đã nêu đích danh ở mục 5.6 và 6.6: tích hợp nhà cung cấp thật chỉ dừng ở bộ
  giả lập, dây chuyền tích hợp liên tục chưa chạy kiểm thử, nhóm kiểm thử tầng truy cập dữ
  liệu chưa vào được dây chuyền, và hạ tầng quan trắc chưa có dữ liệu vận hành thật.
]

// ============================================================
//  RUỘT — đánh số trang Ả Rập
// ============================================================
#set page(numbering: "1")
#counter(page).update(1)

#pagebreak()
#sechead([MỞ ĐẦU])

*Bối cảnh và tính cấp thiết.* Thương mại điện tử giữa các cá nhân đã trở thành một
kênh giao dịch quen thuộc tại Việt Nam, nhưng vẫn vận hành trên một nền tảng niềm tin
mong manh. Người mua chuyển tiền cho một người lạ mà không có gì bảo đảm hàng sẽ tới;
người bán gửi hàng đi mà không có gì bảo đảm sẽ được nhận tiền; và khi hai bên bất
đồng thì không có bên thứ ba nào nắm đủ bằng chứng để phân xử. Thanh toán khi nhận
hàng thường được xem là giải pháp, nhưng nó chỉ dịch chuyển rủi ro sang người bán chứ
không loại bỏ rủi ro. Bài toán trung tâm của đề tài, vì vậy, không phải là dựng thêm
một nơi để đăng tin, mà là dựng một cơ chế khiến hai người xa lạ có thể giao dịch mà
không cần tin nhau.

*Mục tiêu.* Đề tài xây dựng ShopNexus, một nền tảng thương mại điện tử giữa các cá
nhân trên kiến trúc vi dịch vụ, trong đó tiền của người mua được giữ lại ở tài khoản
trung gian cho tới khi hàng đã tới tay và thời hạn khiếu nại đã trôi qua. Xoay quanh
cơ chế đó là một tập năng lực hỗ trợ: thương lượng giá ngay trong cuộc trò chuyện của
hai bên, xác minh danh tính điện tử trước khi được bán hàng hay rút tiền, đánh giá hai
chiều theo cơ chế ẩn để không ai trả đũa được ai, một quy trình khiếu nại thống nhất
do bộ phận vận hành phân xử, và tìm kiếm kết hợp giữa từ khóa với ngữ nghĩa để món
hàng cũ được mô tả bằng lời lẽ dân dã vẫn tìm ra được.

*Phạm vi.* Báo cáo bao trùm trọn vòng đời phát triển của hệ thống: phân tích yêu cầu,
thiết kế kiến trúc và thiết kế chi tiết, hiện thực hóa cả 3 thành phần gồm dịch vụ
nền, ứng dụng web và ứng dụng di động, rồi kiểm thử trên sản phẩm đã chạy
được. Những nội dung nằm ngoài phạm vi gồm vận hành thương mại thực tế, tích hợp với
các đối tác vận chuyển và thanh toán ở môi trường sản xuất, cùng các nghĩa vụ pháp lý
và thuế phát sinh khi nền tảng đi vào hoạt động.

*Phương pháp.* Phần phân tích và thiết kế áp dụng mô hình hóa hướng đối tượng bằng ngôn
ngữ mô hình hóa thống nhất, với sơ đồ ca sử dụng kèm đặc tả đầy đủ, sơ đồ hoạt động, sơ
đồ trạng thái, sơ đồ trình tự, sơ đồ lớp và sơ đồ thực thể quan hệ. Yêu cầu được đặc tả
dưới dạng nguyên tử kèm tiêu chí chấp nhận. Phần hiện thực tuân theo thiết kế
hướng miền nghiệp vụ, trong đó mỗi dịch vụ sở hữu dữ liệu của riêng mình và chỉ giao
tiếp với dịch vụ khác qua hợp đồng đã công bố. Phần đánh giá dựa trên bộ kiểm thử tự
động của hệ thống.

// ---- Các chương (template tự ngắt trang trước mỗi chương) --
#include "chapters/01-tong-quan.typ"
#include "chapters/02-co-so-ly-thuyet.typ"
#include "chapters/03-phan-tich-yeu-cau.typ"
#include "chapters/04-thiet-ke-he-thong.typ"
#include "chapters/05-hien-thuc-trien-khai.typ"
#include "chapters/06-kiem-thu-danh-gia.typ"

#pagebreak()
#sechead([KẾT LUẬN VÀ KIẾN NGHỊ])

*Kết quả đạt được.* Kỳ thực tập đã đưa hệ thống đi trọn chặng đường từ một phát biểu
bài toán tới một hệ thống chạy được. Về phân tích và thiết kế, nhóm hoàn tất
bộ hồ sơ gồm danh mục ca sử dụng kèm đặc tả chi tiết cho các ca trọng yếu, bộ quy tắc
nghiệp vụ, bộ yêu cầu chức năng và phi chức năng có tiêu chí kiểm chứng, các mô hình quy
trình và trạng thái, kiến trúc tổng thể, và thiết kế
cơ sở dữ liệu vật lý cho 7 lược đồ với 46 bảng nghiệp vụ. Về hiện thực, hệ
thống gồm 3 thành phần với khoảng 160.000 dòng mã viết tay, phục vụ 135 đường dẫn và 171 thao tác trên giao diện lập trình,
cùng 2 ứng dụng khách cho web và di động. Về kiểm chứng, bộ kiểm thử tự động của dịch
vụ nền chạy xanh hoàn toàn với 616 hàm kiểm thử, bao phủ các quy tắc nghiệp
vụ cốt lõi của luồng tiền và luồng đơn hàng.

*Đánh giá.* Đóng góp có giá trị nhất của đề tài không nằm ở số lượng chức năng mà ở chỗ
cơ chế bảo vệ giao dịch được thiết kế thành thuộc tính của hệ thống chứ không phải một
chính sách nằm ngoài phần mềm. Tiền của người mua được giữ ở tài khoản ký quỹ bởi
chính luồng thanh toán, đơn hàng ra đời từ việc tiền đã về chứ không từ thao tác của ai,
quy trình khiếu nại được hợp nhất về một dạng phiếu duy nhất, và đánh giá hai chiều được
giữ kín cho tới khi cả hai bên đã gửi. Mỗi lựa chọn ấy loại bỏ một khoảng trống mà ở đó
một bên có thể gây thiệt hại cho bên kia.

*Hạn chế.* Hệ thống chưa được tích hợp với một hãng vận chuyển thật nào, nên toàn bộ
luồng giao nhận hiện chỉ chạy trên bộ giả lập. Độ phủ kiểm thử chưa được đo, một nửa số
gói của dịch vụ nền chưa có kiểm thử. Nhóm
kiểm thử tầng truy cập dữ liệu đã viết nhưng chưa được đưa vào quy trình tích hợp liên
tục. Việc đo hiệu năng dưới tải nằm ngoài phạm vi đề tài. Sau cùng, hạ
tầng quan trắc đã dựng đầy đủ nhưng chưa có dữ liệu vận hành thực tế để đánh giá độ sẵn
sàng.

*Kiến nghị và hướng phát triển.* Trước mắt, nhóm kiến nghị bổ sung bước chạy kiểm thử
vào quy trình tích hợp liên tục của dịch vụ nền và cấu hình một cơ sở dữ liệu tạm cho
nhóm kiểm thử tầng truy cập dữ liệu, vì đây là hai việc rẻ nhất mà lại thu hẹp được
khoảng cách lớn nhất giữa mã đã viết và mã đã được kiểm chứng. Tiếp theo là đo hiệu năng dưới tải để
kiểm chứng các ngưỡng đã đặt ra. Về nghiệp vụ, hai hướng mở rộng tự nhiên là tích
hợp một hãng vận chuyển thật để khép kín vòng đời giao nhận, và đưa dữ liệu quan trắc đã
thu thập vào việc phát hiện hành vi bất thường, chẳng hạn tài khoản mở nhiều khiếu nại
bất thường hoặc mẫu giao dịch có dấu hiệu rửa uy tín. Về kiến trúc, ranh giới dữ liệu
giữa 7 dịch vụ đã được giữ nghiêm ngặt ngay từ đầu nên việc tách chúng thành các đơn
vị phát hành độc lập có thể thực hiện khi tải thực tế đòi hỏi, mà không phải viết lại
mô hình dữ liệu.

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
// phần website theo tên tài nguyên. Số thứ tự chạy liên tục qua cả ba nhóm để
// trích dẫn trong thân bài (dạng [n]) không bị trùng.
#let nhom-tltk(ten) = block(above: 1.1em, below: 0.5em)[#strong(ten)]

#nhom-tltk[Tiếng Việt]
#enum(
  numbering: n => "[" + str(n) + "]",
  start: 1,
  [Chính phủ nước Cộng hòa xã hội chủ nghĩa Việt Nam, Nghị định số 52/2013/NĐ-CP về thương mại điện tử, Công báo, Hà Nội (2013).],
  [Chính phủ nước Cộng hòa xã hội chủ nghĩa Việt Nam, Nghị định số 85/2021/NĐ-CP sửa đổi, bổ sung một số điều của Nghị định số 52/2013/NĐ-CP về thương mại điện tử, Công báo, Hà Nội (2021).],
)

#nhom-tltk[Tiếng Anh]
#enum(
  numbering: n => "[" + str(n + 2) + "]",
  start: 1,
  [Chen J., Xiao S., Zhang P., Luo K., Lian D., Liu Z., M3-Embedding: Multi-Linguality, Multi-Functionality, Multi-Granularity Text Embeddings Through Self-Knowledge Distillation, Findings of the Association for Computational Linguistics: ACL 2024, tr. 2318–2335, Bangkok, Thailand (2024).],
  [Garcia-Molina H., Salem K., Sagas, ACM SIGMOD Record, tập 16, số 3, tr. 249–259 (1987).],
  [Helland P., Idempotence Is Not a Medical Condition, ACM Queue, tập 10, số 4, tr. 30–46 (2012).],
  [Kleppmann M., Designing Data-Intensive Applications: The Big Ideas Behind Reliable, Scalable, and Maintainable Systems, O'Reilly Media, Sebastopol, CA, USA (2017).],
  [Li C., Liu Z., Wu M., Xu Y., Zhao H., Huang P., Zhou G., Zhu X., Gai K., Multi-Interest Network with Dynamic Routing for Recommendation at Tmall, Proc. 28th ACM Int. Conf. on Information and Knowledge Management (CIKM), tr. 2615–2623, Beijing, China (2019).],
  [Newman S., Building Microservices: Designing Fine-Grained Systems, tái bản lần 2, O'Reilly Media, Sebastopol, CA, USA (2021).],
  [Richardson C., Microservices Patterns: With Examples in Java, Manning Publications, Shelter Island, NY, USA (2019).],
  [Robertson S., Zaragoza H., The Probabilistic Relevance Framework: BM25 and Beyond, Foundations and Trends in Information Retrieval, tập 3, số 4, tr. 333–389 (2009).],
)

#nhom-tltk[Website tham khảo]
#enum(
  numbering: n => "[" + str(n + 10) + "]",
  start: 1,
  [pgvector — Open-Source Vector Similarity Search for PostgreSQL, https:\/\/github.com/pgvector/pgvector (truy cập ngày 12/08/2026).],
  [Restate Documentation — Durable Execution Engine for Microservices, https:\/\/docs.restate.dev (truy cập ngày 12/08/2026).],
)
