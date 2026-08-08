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
  thoi-diem: "năm 2026",
)

// ---- Phiếu giao đề cương ----------------------------------
#phieu-giao-de-cuong(
  thoi-diem: "năm 2026",
  moc: (
    ("Khảo sát hiện trạng, xác định tầm nhìn và phạm vi đề tài", "Tuần 1-2", "Tài liệu tầm nhìn, phạm vi"),
    ("Phân tích yêu cầu, đặc tả use case và quy tắc nghiệp vụ", "Tuần 3", "Đặc tả yêu cầu"),
    ("Định nghĩa kiến trúc hệ thống và mô hình dữ liệu", "Tuần 4", "Tài liệu kiến trúc, ERD"),
    ("Thiết kế cấp cao và thiết kế chi tiết", "Tuần 5-6", "Hồ sơ thiết kế"),
    ("Hiện thực hóa, kiểm thử và triển khai", "Tuần 7-14", "Mã nguồn, báo cáo kiểm thử"),
  ),
)
#pagebreak()

#muc-luc()
#pagebreak()

#sechead([LỜI CẢM ƠN], outlined: false)

Chúng em xin chân thành cảm ơn Ban Giám hiệu Học viện Công nghệ Bưu chính Viễn thông Cơ sở tại TP. Hồ Chí Minh cùng quý Thầy, Cô trong Khoa Công nghệ Thông tin đã tạo điều kiện thuận lợi và trang bị những kiến thức nền tảng quý báu cho chúng em trong suốt quá trình học tập và nghiên cứu.

Đặc biệt, chúng em xin gửi lời cảm ơn sâu sắc nhất đến thầy *ThS. Nguyễn Đức Thịnh*, người đã tận tình hướng dẫn, định hướng chuyên môn và đóng góp những ý kiến vô cùng quý báu trong suốt kỳ thực tập, giúp nhóm hoàn thành báo cáo thực tập tốt nghiệp này.

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
  [ACID], [Atomicity – Consistency – Isolation – Durability], [Bốn tính chất của giao dịch CSDL tin cậy],
  [ADR], [Architectural Decision Record], [Bản ghi quyết định kiến trúc],
  [ANN], [Approximate Nearest Neighbor], [Tìm láng giềng gần đúng (cho tìm kiếm vector)],
  [API], [Application Programming Interface], [Giao diện lập trình ứng dụng],
  [BR], [Business Rule], [Quy tắc nghiệp vụ (đánh mã BR-xxx)],
  [C2C], [Consumer to Consumer], [Giao dịch giữa các cá nhân người dùng],
  [CI/CD], [Continuous Integration / Continuous Deployment], [Tích hợp và triển khai liên tục],
  [CRUD], [Create – Read – Update – Delete], [Bốn thao tác dữ liệu cơ bản],
  [CSDL], [—], [Cơ sở dữ liệu],
  [DDD], [Domain-Driven Design], [Thiết kế hướng miền nghiệp vụ],
  [DDL], [Data Definition Language], [Ngôn ngữ định nghĩa dữ liệu (SQL tạo bảng/chỉ mục)],
  [DTO], [Data Transfer Object], [Đối tượng truyền dữ liệu request/response],
  [eKYC], [electronic Know Your Customer], [Xác minh danh tính khách hàng bằng phương tiện điện tử],
  [ERD], [Entity–Relationship Diagram], [Sơ đồ thực thể – quan hệ],
  [Escrow], [—], [Cơ chế thanh toán tạm giữ (trung gian) bảo vệ giao dịch],
  [FR], [Functional Requirement], [Yêu cầu chức năng],
  [HNSW], [Hierarchical Navigable Small World], [Cấu trúc chỉ mục cho tìm kiếm ANN],
  [HPA], [Horizontal Pod Autoscaler], [Tự động co giãn số pod trên Kubernetes],
  [JWT], [JSON Web Token], [Chuẩn token xác thực người dùng],
  [LOC], [Lines of Code], [Số dòng mã nguồn],
  [MoSCoW], [Must – Should – Could – Won't], [Thang phân loại mức ưu tiên yêu cầu],
  [NFR], [Non-Functional Requirement], [Yêu cầu phi chức năng],
  [ORM], [Object-Relational Mapping], [Ánh xạ đối tượng – quan hệ],
  [OWASP], [Open Web Application Security Project], [Tổ chức chuẩn hóa các rủi ro bảo mật ứng dụng web],
  [PII], [Personally Identifiable Information], [Thông tin định danh cá nhân],
  [RBAC], [Role-Based Access Control], [Kiểm soát truy cập theo vai trò],
  [REQ], [Requirement], [Yêu cầu chức năng (đánh mã REQ-xxx)],
  [RPC], [Remote Procedure Call], [Lời gọi thủ tục từ xa giữa các dịch vụ],
  [RPO], [Recovery Point Objective], [Mục tiêu điểm phục hồi (lượng dữ liệu tối đa có thể mất)],
  [RTO], [Recovery Time Objective], [Mục tiêu thời gian phục hồi sau sự cố],
  [SKU], [Stock Keeping Unit], [Đơn vị lưu kho — biến thể sản phẩm cụ thể],
  [SLA], [Service Level Agreement], [Cam kết mức dịch vụ của bên thứ ba],
  [SPU], [Standard Product Unit], [Đơn vị sản phẩm chuẩn — bài đăng gốc chứa nhiều SKU],
  [SSE], [Server-Sent Events], [Kênh đẩy sự kiện thời gian thực từ máy chủ],
  [TLS], [Transport Layer Security], [Mã hóa dữ liệu trên đường truyền],
  [UC], [Use Case], [Ca sử dụng (đánh mã UC-xxx)],
  [UML], [Unified Modeling Language], [Ngôn ngữ mô hình hóa thống nhất],
  [WCAG], [Web Content Accessibility Guidelines], [Hướng dẫn khả năng tiếp cận nội dung web],
  [k3s], [—], [Bản phân phối Kubernetes nhẹ (single-node) cho demo],
)

#pagebreak()

#danh-muc-bang()
#pagebreak()

#danh-muc-hinh()
#pagebreak()

#sechead([KẾ HOẠCH THỰC HIỆN CÔNG VIỆC NHÓM], outlined: false)

#v(0.5cm)
#table(
  columns: (1.1cm, 1fr, 3.6cm, 2.6cm, 1.9cm),
  inset: 7pt,
  align: (center, left, left, center, center),
  table.header([*STT*], [*Nội dung công việc*], [*Người thực hiện*], [*Thời gian*], [*Mức độ*]),
  [1], [Khảo sát bối cảnh, xác định bài toán niềm tin trong thương mại điện tử C2C], [Cả nhóm], [Tuần 1], [100%],
  [2], [Phân tích các mô hình sàn giao dịch tiêu biểu và rút ra yêu cầu cho đề tài], [Nguyễn Tấn Khoa, Hồ Công Toản], [Tuần 1], [100%],
  [3], [Nghiên cứu kiến trúc hướng dịch vụ, mô hình vi dịch vụ và triết lý mỗi dịch vụ một cơ sở dữ liệu], [Đậu Văn Đăng Khoa, Hồ Công Toản], [Tuần 1 – 2], [100%],
  [4], [Nghiên cứu thực thi bền vững và các mẫu giao dịch phân tán], [Đậu Văn Đăng Khoa], [Tuần 1 – 2], [100%],
  [5], [Nghiên cứu tìm kiếm ngữ nghĩa và hệ gợi ý đa sở thích], [Đậu Văn Đăng Khoa, Hồ Công Toản], [Tuần 2 – 3], [100%],
  [6], [Phân tích tác nhân, chân dung người dùng và sơ đồ ngữ cảnh hệ thống], [Nguyễn Tấn Khoa], [Tuần 3], [100%],
  [7], [Xây dựng danh mục ca sử dụng và đặc tả chi tiết các ca trọng yếu], [Cả nhóm], [Tuần 3], [100%],
  [8], [Chuẩn hóa bộ quy tắc nghiệp vụ ràng buộc nền tảng], [Nguyễn Tấn Khoa, Hồ Công Toản], [Tuần 3], [100%],
  [9], [Ban hành bộ yêu cầu chức năng và phi chức năng, ma trận CRUD và ma trận truy xuất nguồn gốc], [Cả nhóm], [Tuần 3 – 4], [100%],
  [10], [Mô hình hóa quy trình bằng sơ đồ hoạt động, sơ đồ trạng thái và sơ đồ trình tự], [Đậu Văn Đăng Khoa, Nguyễn Tấn Khoa], [Tuần 4], [100%],
  [11], [Phân rã miền nghiệp vụ và thiết kế kiến trúc tổng thể], [Cả nhóm], [Tuần 4], [100%],
  [12], [Thiết kế luồng giao tiếp liên dịch vụ và trục sự kiện bất đồng bộ], [Đậu Văn Đăng Khoa], [Tuần 4 – 5], [100%],
  [13], [Thiết kế thành phần phân lớp, sơ đồ lớp và ma trận trách nhiệm], [Hồ Công Toản, Đậu Văn Đăng Khoa], [Tuần 5], [100%],
  [14], [Thiết kế danh mục giao diện lập trình và các bản ghi quyết định kiến trúc], [Nguyễn Tấn Khoa, Đậu Văn Đăng Khoa], [Tuần 5], [100%],
  [15], [Thiết kế mô hình dữ liệu ý niệm và cơ sở dữ liệu vật lý cho bảy lược đồ], [Cả nhóm], [Tuần 5 – 6], [100%],
  [16], [Thiết kế bảo mật, đặc tả thuật toán nghiệp vụ và chiến lược xử lý lỗi], [Đậu Văn Đăng Khoa], [Tuần 6], [100%],
  [17], [Hiện thực dịch vụ tài khoản, danh mục sản phẩm và tìm kiếm], [Đậu Văn Đăng Khoa, Hồ Công Toản], [Tuần 7 – 9], [100%],
  [18], [Hiện thực dịch vụ đơn hàng, tài chính và luồng thanh toán tạm giữ], [Đậu Văn Đăng Khoa], [Tuần 8 – 11], [100%],
  [19], [Hiện thực dịch vụ hội thoại, tín nhiệm và quan trắc vận hành], [Hồ Công Toản], [Tuần 9 – 11], [100%],
  [20], [Hiện thực ứng dụng web], [Nguyễn Tấn Khoa, Hồ Công Toản], [Tuần 9 – 12], [100%],
  [21], [Hiện thực ứng dụng di động], [Nguyễn Tấn Khoa], [Tuần 10 – 13], [100%],
  [22], [Tích hợp các nhà cung cấp bên ngoài và bộ giả lập tương ứng], [Đậu Văn Đăng Khoa], [Tuần 11 – 12], [100%],
  [23], [Xây dựng quy trình tích hợp liên tục và mô hình triển khai bằng container], [Đậu Văn Đăng Khoa], [Tuần 12], [100%],
  [24], [Kiểm thử tự động, đo hiệu năng và đánh giá đáp ứng yêu cầu phi chức năng], [Cả nhóm], [Tuần 13 – 14], [100%],
  [25], [Tổng hợp và hoàn thiện báo cáo thực tập tốt nghiệp], [Cả nhóm], [Tuần 14], [100%],
)

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
thiết kế kiến trúc và thiết kế chi tiết, hiện thực hóa cả ba thành phần gồm dịch vụ
nền, ứng dụng web và ứng dụng di động, rồi kiểm thử và đo đạc trên sản phẩm đã chạy
được. Những nội dung nằm ngoài phạm vi gồm vận hành thương mại thực tế, tích hợp với
các đối tác vận chuyển và thanh toán ở môi trường sản xuất, cùng các nghĩa vụ pháp lý
và thuế phát sinh khi nền tảng đi vào hoạt động.

*Phương pháp.* Phần phân tích và thiết kế áp dụng mô hình hóa hướng đối tượng bằng ngôn
ngữ mô hình hóa thống nhất, với sơ đồ ca sử dụng kèm đặc tả đầy đủ, sơ đồ hoạt động, sơ
đồ trạng thái, sơ đồ trình tự, sơ đồ lớp và sơ đồ thực thể quan hệ. Yêu cầu được đặc tả
dưới dạng nguyên tử kèm tiêu chí chấp nhận, kiểm tra độ đầy đủ bằng ma trận CRUD và bảo
đảm tính truy vết bằng ma trận truy xuất nguồn gốc. Phần hiện thực tuân theo thiết kế
hướng miền nghiệp vụ, trong đó mỗi dịch vụ sở hữu dữ liệu của riêng mình và chỉ giao
tiếp với dịch vụ khác qua hợp đồng đã công bố. Phần đánh giá dựa trên kiểm thử tự động
và trên một phép đo hiệu năng thực nghiệm do nhóm tự thiết kế và thực hiện.

*Kết cấu của báo cáo.* Ngoài phần Mở đầu và Kết luận, nội dung gồm sáu chương: Chương 1
trình bày tổng quan về bài toán và phạm vi đề tài; Chương 2 hệ thống hóa cơ sở lý
thuyết; Chương 3 phân tích yêu cầu; Chương 4 thiết kế hệ thống; Chương 5 trình bày kết
quả hiện thực và triển khai; Chương 6 trình bày kiểm thử, đo đạc và đánh giá.

// ---- Các chương (template tự ngắt trang trước mỗi chương) --
#include "chapters/01-tong-quan.typ"
#include "chapters/02-co-so-ly-thuyet.typ"
#include "chapters/03-phan-tich-yeu-cau.typ"
#include "chapters/04-thiet-ke-he-thong.typ"
#include "chapters/05-hien-thuc-trien-khai.typ"
#include "chapters/06-kiem-thu-danh-gia.typ"

#pagebreak()
#sechead([KẾT LUẬN VÀ KIẾN NGHỊ])

*Kết quả đạt được.* Kỳ thực tập đã đưa ShopNexus đi trọn chặng đường từ một phát biểu
bài toán tới một hệ thống chạy được và đo được. Về phân tích và thiết kế, nhóm hoàn tất
bộ hồ sơ gồm danh mục ca sử dụng kèm đặc tả chi tiết cho các ca trọng yếu, bộ quy tắc
nghiệp vụ, bộ yêu cầu chức năng và phi chức năng có tiêu chí kiểm chứng, các mô hình quy
trình và trạng thái, kiến trúc tổng thể kèm các bản ghi quyết định kiến trúc, và thiết kế
cơ sở dữ liệu vật lý cho bảy lược đồ với bốn mươi sáu bảng nghiệp vụ. Về hiện thực, hệ
thống gồm ba thành phần với khoảng một trăm sáu mươi nghìn dòng mã viết tay, phục vụ một
trăm ba mươi lăm đường dẫn và một trăm bảy mươi mốt thao tác trên giao diện lập trình,
cùng hai ứng dụng khách cho web và di động. Về kiểm chứng, bộ kiểm thử tự động của dịch
vụ nền chạy xanh hoàn toàn với sáu trăm mười sáu hàm kiểm thử, và nhóm đã thực hiện một
phép đo hiệu năng thực nghiệm trên hệ thống đang chạy thay vì trích dẫn con số của người
khác.

*Đánh giá.* Đóng góp có giá trị nhất của đề tài không nằm ở số lượng chức năng mà ở chỗ
cơ chế bảo vệ giao dịch được thiết kế thành thuộc tính của hệ thống chứ không phải một
chính sách nằm ngoài phần mềm. Tiền của người mua được giữ ở tài khoản trung gian bởi
chính luồng thanh toán, đơn hàng ra đời từ việc tiền đã về chứ không từ thao tác của ai,
quy trình khiếu nại được hợp nhất về một dạng phiếu duy nhất, và đánh giá hai chiều được
giữ kín cho tới khi cả hai bên đã gửi. Mỗi lựa chọn ấy loại bỏ một khoảng trống mà ở đó
một bên có thể gây thiệt hại cho bên kia. Phép đo ở Chương 6 cũng cho thấy một kết quả
đáng chú ý về mặt kỹ thuật: nút thắt của tìm kiếm ngữ nghĩa không nằm ở việc dò vector
như thường được giả định, mà nằm ở bước sinh vector cho câu truy vấn.

*Hạn chế.* Hệ thống chưa được tích hợp với một hãng vận chuyển thật nào, nên toàn bộ
luồng giao nhận hiện chỉ chạy trên bộ giả lập. Độ phủ kiểm thử chưa được đo, một nửa số
gói của dịch vụ nền chưa có kiểm thử, và ứng dụng web chưa có kiểm thử tự động. Nhóm
kiểm thử tầng truy cập dữ liệu đã viết nhưng chưa được đưa vào quy trình tích hợp liên
tục. Phép đo hiệu năng thực hiện trên máy phát triển với tập dữ liệu nhỏ và chỉ bao phủ
đường đọc, nên chưa nói được gì về hành vi của hệ thống ở quy mô sản xuất. Sau cùng, hạ
tầng quan trắc đã dựng đầy đủ nhưng chưa có dữ liệu vận hành thực tế để đánh giá độ sẵn
sàng.

*Kiến nghị và hướng phát triển.* Trước mắt, nhóm kiến nghị bổ sung bước chạy kiểm thử
vào quy trình tích hợp liên tục của dịch vụ nền và cấu hình một cơ sở dữ liệu tạm cho
nhóm kiểm thử tầng truy cập dữ liệu, vì đây là hai việc rẻ nhất mà lại thu hẹp được
khoảng cách lớn nhất giữa mã đã viết và mã đã được kiểm chứng. Tiếp theo là lưu đệm vector
cho những câu truy vấn thường gặp, giải pháp mà số đo đã chỉ đích danh, và xử lý hiện
tượng dồn toa khi mục nhớ đệm hết hạn. Về nghiệp vụ, hai hướng mở rộng tự nhiên là tích
hợp một hãng vận chuyển thật để khép kín vòng đời giao nhận, và đưa dữ liệu quan trắc đã
thu thập vào việc phát hiện hành vi bất thường, chẳng hạn tài khoản mở nhiều khiếu nại
bất thường hoặc mẫu giao dịch có dấu hiệu rửa uy tín. Về kiến trúc, ranh giới dữ liệu
giữa bảy dịch vụ đã được giữ nghiêm ngặt ngay từ đầu nên việc tách chúng thành các đơn
vị phát hành độc lập có thể thực hiện khi tải thực tế đòi hỏi, mà không phải viết lại
mô hình dữ liệu.

#pagebreak()
#sechead([DANH MỤC TÀI LIỆU THAM KHẢO])

#bibliography("../common/refs.bib", title: none, full: true, style: "ieee")

#pagebreak()
#sechead([PHỤ LỤC])

#sechead([Phụ lục A. Hướng dẫn cài đặt và chạy hệ thống], outlined: false)

Hệ thống được đóng gói bằng container nên chỉ cần một máy có Docker và Docker Compose là
dựng được toàn bộ hạ tầng phụ thuộc. Trình tự tối thiểu gồm bốn bước. Trước hết, dựng hạ
tầng nền gồm cơ sở dữ liệu, bộ nhớ đệm, hệ thống thông điệp và bộ quan trắc. Tiếp theo,
tạo tệp cấu hình từ tệp mẫu đi kèm mã nguồn; toàn bộ cấu hình nằm trong một tài liệu duy
nhất và mọi trường đều bắt buộc, nên thiếu trường nào thì tiến trình dừng ngay lúc khởi
động và nói rõ đường dẫn cần sửa. Sau đó chạy chương trình áp dụng migration, vốn là một
bước tách rời và không bao giờ chạy tự động lúc khởi động dịch vụ. Cuối cùng khởi động
cổng dịch vụ.

Kho mã cung cấp sáu hồ sơ chạy khác nhau cho các nhu cầu khác nhau: chỉ hạ tầng để lập
trình viên chạy dịch vụ ngay trên máy; hồ sơ phát triển có nạp lại nóng khi sửa mã; hồ sơ
chạy đúng ảnh phát hành để kiểm tra lần cuối trước khi đẩy lên; hồ sơ mô phỏng phục vụ
toàn bộ hợp đồng giao diện lập trình từ đặc tả mà không cần cơ sở dữ liệu, dùng cho việc
viết ứng dụng khách trước khi máy chủ kịp hiện thực; và hồ sơ chạy tiến trình sinh vector
nhúng. Dữ liệu mẫu cho môi trường phát triển được nạp bằng một chương trình riêng, có cơ
chế từ chối chạy lần thứ hai để không nhân đôi dữ liệu.

#sechead([Phụ lục B. Bộ tạo tải dùng cho phép đo hiệu năng], outlined: false)

Phép đo ở Chương 6 sử dụng một bộ tạo tải do nhóm tự viết bằng Go, chỉ dùng thư viện
chuẩn. Chương trình nhận vào địa chỉ gốc của dịch vụ, một vé truy cập cho các kịch bản
cần xác thực, số luồng đồng thời và thời lượng đo. Với mỗi kịch bản, chương trình chạy
một pha khởi động rồi mới bắt đầu ghi nhận, phát yêu cầu theo mô hình vòng kín, đọc hết
thân phản hồi để tính đúng thời gian hoàn tất, và cuối cùng sắp xếp toàn bộ mẫu để tính
phân vị theo thứ hạng gần nhất. Kết quả được xuất ra cả dạng bảng để đọc trực tiếp và
dạng dữ liệu có cấu trúc để đưa vào báo cáo.

Lý do tự viết thay vì dùng công cụ có sẵn là để kiểm soát chính xác mô hình phát tải.
Nhiều công cụ phổ biến chạy theo mô hình vòng hở với tốc độ phát cố định; khi hệ thống
bắt đầu bão hòa, mô hình ấy biến độ trễ thành độ dài hàng đợi và che mất đúng cái điểm
mà phép đo muốn tìm.
