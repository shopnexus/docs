#import "../../common/tokens.typ": *

== Các yếu tố dẫn dắt kiến trúc

Không phải yêu cầu nào cũng có ý nghĩa kiến trúc. Phần lớn trong số 46 yêu cầu chức năng
đã ban hành ở Chương 3 đều có thể hiện thực bằng một biểu mẫu, một câu truy vấn và một
màn hình, và chúng chỉ được quyết định ở bước thiết kế chi tiết. Mục này tách ra nhóm nhỏ
các yêu cầu và ràng buộc thực sự *định hình* cấu trúc hệ thống: những yêu cầu mà nếu chọn
sai kiểu kiến trúc thì không thể sửa bằng cách viết thêm mã, mà phải làm lại từ đầu. Mỗi
yếu tố dẫn dắt được đánh mã `AD-01` … `AD-10` và mọi quyết định kiến trúc ở các mục sau
đều truy ngược về ít nhất một mã trong bảng này.

=== Yêu cầu chức năng có ý nghĩa kiến trúc

Đặc thù của một sàn giao dịch giữa người dùng với người dùng là *tiền của người mua không
đi thẳng tới người bán*. Nền tảng đứng giữa, giữ tiền cho tới khi hàng đã tới nơi, và phải
trả lời được câu hỏi "tiền đang ở đâu" tại mọi thời điểm, kể cả khi tiến trình vừa bị khởi
động lại giữa chừng. Đây là nguồn gốc của phần lớn các yếu tố dẫn dắt bên dưới: nghiệp vụ
trọng tâm không phải là một thao tác ghi dữ liệu ngắn, mà là một chuỗi trạng thái kéo dài
nhiều ngày, trải qua nhiều miền nghiệp vụ và phụ thuộc vào các hệ thống bên ngoài không do
nhóm kiểm soát.

#figure(
  caption: [Các yêu cầu chức năng có ý nghĩa kiến trúc (Architecturally Significant Requirements)],
  table(
    columns: (0.5fr, 1.5fr, 0.95fr, 2.5fr),
    align: (center + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Mã], [Yêu cầu dẫn dắt], [Nguồn], [Ý nghĩa kiến trúc]),

    [AD-01], [Giữ tiền tạm giữ và giải ngân theo phán quyết], [REQ-26, REQ-32, REQ-36],
    [Một lần chuyển tiền phải là nguyên tử trên sổ cái, nhưng lại được kích hoạt từ ba miền khác nhau (đơn hàng, thanh toán, khiếu nại). Buộc dồn toàn bộ nguyên hàm về tiền vào một miền duy nhất và cấm mọi miền khác ghi vào sổ cái.],

    [AD-02], [Các chuyển trạng thái theo thời hạn], [REQ-21, REQ-24, REQ-29, REQ-32, REQ-35],
    [Năm loại hẹn giờ dài (hết hạn thanh toán, hết hạn đề nghị giá, hết hạn xác nhận đơn, giải ngân sau khi nhận hàng, hết hạn hoàn tiền) kéo dài từ 30 phút đến nhiều ngày. Không thể giữ trong bộ nhớ tiến trình; đòi hỏi một cơ chế hẹn giờ bền và một mạng lưới dự phòng khi cơ chế đó không sẵn sàng.],

    [AD-03], [Tích hợp nhiều nhà cung cấp cùng loại], [REQ-23, REQ-25, REQ-43, NFR-28],
    [Thanh toán và vận chuyển đều có nhiều đối tác, và một bản ghi đã phát sinh sẽ ghi nhớ tên đối tác đã phục vụ nó *vĩnh viễn*. Kiến trúc phải cho phép nhiều đối tác cùng loại hoạt động đồng thời chứ không chỉ chọn một tại thời điểm triển khai.],

    [AD-04], [Tìm kiếm bằng ngôn ngữ tự nhiên trên dữ liệu do người dùng tự đặt tên], [REQ-14, REQ-15, REQ-16],
    [Tiêu đề bài đăng trên sàn C2C không theo chuẩn nào, khiến so khớp từ khoá thuần kém hiệu quả. Cần chỉ mục vector đặt cạnh dữ liệu quan hệ để lọc thuộc tính và xếp hạng ngữ nghĩa cùng một truy vấn, kèm một tiến trình sinh vector tách rời khỏi đường phục vụ yêu cầu.],

    [AD-05], [Truyền tin và thông báo thời gian thực], [REQ-18, NFR-08],
    [Hội thoại, thông báo và biến động đơn hàng phải tới thiết bị trong vòng một giây. Đòi hỏi một kênh đẩy hai chiều và một cơ chế phát tán để nhiều bản sao của cổng vào cùng phục vụ được một người dùng đang mở nhiều thiết bị.],

    [AD-06], [Bằng chứng đa phương tiện bắt buộc], [REQ-31, REQ-33, REQ-44],
    [Video mở hộp và ảnh minh chứng là tệp lớn, không thể đi qua thân yêu cầu JSON. Buộc tách đường tải tệp khỏi đường nghiệp vụ, và buộc mỗi miền tự quản tài nguyên do mình tiếp nhận.],

    [AD-07], [Một cửa tiếp nhận cho mọi khiếu nại], [REQ-34, REQ-36, REQ-37],
    [Báo cáo vi phạm, khiếu nại hoàn tiền, sự cố đơn hàng và yêu cầu hỗ trợ vốn là *một* hành vi: người dùng gửi một việc và có người trả lời. Gộp chúng về một vòng đời duy nhất, đồng thời đòi hỏi kênh trao đổi ẩn danh phía nhân viên hỗ trợ.],

    [AD-08], [Nhật ký kiểm toán bất biến], [REQ-45, NFR-21],
    [Mọi thay đổi có hệ quả tài chính hoặc hành chính phải để lại vết không sửa được, ghi *trong cùng giao dịch* với thay đổi. Quyết định cách các thực thể được ghi xuống, chứ không phải là một tính năng bổ sung.],

    [AD-09], [Ba giao diện khách trên một hợp đồng], [REQ-01…46, NFR-30],
    [Web, ứng dụng di động và bảng điều khiển quản trị cùng gọi một tập giao diện lập trình. Đòi hỏi đặc tả là tài sản trung tâm, sinh ra được mã máy khách và bộ giả lập, chứ không phải tài liệu viết sau khi lập trình.],

    [AD-10], [Khối lượng mục tiêu ở quy mô trình diễn], [NFR-05, NFR-07],
    [500 người dùng đồng thời, 5.000 đơn mỗi ngày trên hạ tầng một cụm nhỏ. Đây là con số *thấp*, và điều đó cũng dẫn dắt kiến trúc: nó loại bỏ mọi phương án đánh đổi độ phức tạp vận hành để lấy khả năng mở rộng mà giai đoạn này chưa cần tới.],
  )
)

=== Thuộc tính chất lượng chi phối lựa chọn

Bộ yêu cầu phi chức năng ở Chương 3 gồm bốn nhóm, nhưng chỉ một phần trong đó thực sự ép
buộc kiến trúc. Bảng dưới đây rút ra những thuộc tính chất lượng có sức nặng lớn nhất, kèm
mục tiêu định lượng và cách chúng được thoả mãn. Cần nói rõ ngay từ đầu rằng các mục tiêu
hiệu năng ở đây là *mục tiêu thiết kế*, tức là những gì kiến trúc được dựng để đạt tới, chứ
chưa phải kết quả. Chương 6 sẽ đối chiếu từng mục tiêu ấy với một phép đo thực nghiệm mà
nhóm tự thiết kế và thực hiện trên hệ thống đang chạy.

#figure(
  caption: [Thuộc tính chất lượng chi phối kiến trúc, mục tiêu định lượng và cơ chế đáp ứng],
  table(
    columns: (1fr, 0.8fr, 1.5fr, 2.3fr),
    align: (left + horizon, center + horizon, left + horizon, left + horizon),
    table.header([Thuộc tính], [Ưu tiên], [Mục tiêu định lượng], [Cơ chế kiến trúc đáp ứng]),

    [Tính nhất quán của dòng tiền], [Tới hạn], [NFR-20, NFR-21: không mất mát và không nhân đôi số dư trong mọi kịch bản lỗi],
    [Toàn bộ nguyên hàm về tiền nằm trong một miền và một lược đồ, nên một lần giữ tiền là một giao dịch cục bộ chứ không phải giao dịch phân tán. Sổ cái chỉ ghi thêm; điều chỉnh thực hiện bằng bút toán đảo ứng.],

    [Khả năng tự phục hồi của luồng dài], [Tới hạn], [NFR-19: hoàn tất đúng một lần sau sự cố sập tiến trình],
    [Mỗi chuyển trạng thái theo thời hạn là một phương thức dịch vụ *lũy đẳng*; nó được gọi bởi hai nguồn độc lập (bộ thực thi bền và bộ quét định kỳ) nhưng chỉ có một định nghĩa duy nhất về "đã đến hạn".],

    [Cách ly dữ liệu giữa các miền], [Tới hạn], [NFR-25: không dịch vụ nào đọc lược đồ của dịch vụ khác],
    [Mỗi dịch vụ một lược đồ Postgres riêng với chuỗi kết nối riêng và đường tìm kiếm riêng; không có khoá ngoại xuyên lược đồ, mọi tham chiếu chéo là tham chiếu luận lý giải quyết qua hợp đồng đã công bố.],

    [Bảo mật phiên và thu hồi tức thời], [Tới hạn], [NFR-10, NFR-11, NFR-13],
    [Thẻ truy cập sống 15 phút nhưng *phiên* mới là nguồn sự thật: mỗi yêu cầu đã xác thực đều tra phiên trong bộ nhớ khoá–giá trị, nên khoá tài khoản hay đổi mật khẩu có hiệu lực ngay với thẻ đang lưu hành. Thu hồi toàn bộ phiên của một tài khoản là một phép tăng số kỷ nguyên, chi phí hằng số.],

    [Khả năng kiểm toán], [Tới hạn], [REQ-45: một bản ghi kiểm toán chỉ-thêm-mới cho mỗi quyết định nghiệp vụ và mỗi biến động tiền],
    [Sự kiện miền do chính thao tác nghiệp vụ ghi nhận được chuyển thành bản ghi kiểm toán trong *cùng giao dịch* với thay đổi. Phép thử của thiết kế: gỡ bỏ toàn bộ lời ghi nhận thì dữ liệu vẫn đúng, chỉ mất dấu vết.],

    [Độ trễ đọc], [Cao], [NFR-01, NFR-02, NFR-04: p95 của mỗi đường đọc gắn với một mức đồng thời cụ thể],
    [Đường đọc gọi thẳng dịch vụ chủ quản, không đi qua lớp thực thi bền. Bộ nhớ đệm chỉ đặt ở nơi tính toán đắt và kết quả ổn định (vector của câu truy vấn tìm kiếm).],

    [Độ trễ đẩy thời gian thực], [Cao], [NFR-08: dưới 1 giây kể từ khi sự kiện được ghi bền],
    [Kênh WebSocket kèm trục phát tán, để một sự kiện phát sinh ở bản sao này vẫn tới được thiết bị đang nối vào bản sao khác.],

    [Khả năng bảo trì và mở rộng theo miền], [Cao], [NFR-31],
    [Mọi dịch vụ có cùng một hình dạng thư mục và cùng một chiều phụ thuộc, nên quy tắc nghiệp vụ kiểm thử được mà không cần cơ sở dữ liệu.],

    [Khả năng chịu tải], [T. bình], [NFR-05, NFR-07: tối thiểu 50 phiên đồng thời trên một nút, thông lượng không giảm so với mức 10 luồng],
    [Cổng vào không lưu trạng thái nên nhân bản được theo chiều ngang; trạng thái phiên và trạng thái kênh thời gian thực đều nằm ngoài tiến trình.],

    [Khả dụng], [T. bình], [NFR-23: 99,5% theo tháng],
    [Quan trắc bốn tín hiệu ghi thẳng vào cơ sở dữ liệu chuỗi thời gian; phát mẫu đo là *nỗ lực tốt nhất*, không bao giờ chặn hay làm hỏng một yêu cầu nghiệp vụ.],
  )
)

Hai cặp thuộc tính xung đột nhau và cách giải quyết đã được ghi nhận ngay từ khâu thiết kế.
Thứ nhất là *tính nhất quán mạnh của dòng tiền* xung đột với *cách ly dữ liệu theo miền*:
nếu tách tiền ra khỏi đơn hàng theo đúng tinh thần mỗi miền một lược đồ thì một lần giữ tiền
sẽ trở thành giao dịch phân tán qua hai cơ sở dữ liệu. Cách giải quyết là *dịch chuyển đường
biên* thay vì dựng cơ chế bù trừ: mọi nguyên hàm về tiền, kể cả ví và tài khoản ngân hàng
của người bán, được đưa hết về miền tài chính, để một lần chuyển escrow luôn là một giao
dịch cục bộ. Thứ hai là *độ tin cậy của các hẹn giờ dài* xung đột với *độ đơn giản vận hành*:
một bộ thực thi bền là thành phần hạ tầng nữa phải cài đặt, giám sát và nâng cấp. Cách giải
quyết là làm cho nó *tuỳ chọn* — mỗi chuyển trạng thái theo thời hạn được định nghĩa một lần
duy nhất dưới dạng phương thức lũy đẳng, và một cấu hình không bật bộ thực thi bền vẫn là một
triển khai hợp lệ, khi đó bộ quét định kỳ là đồng hồ duy nhất.

=== Ràng buộc và xếp hạng các yếu tố dẫn dắt

#figure(
  caption: [Danh mục ràng buộc của dự án],
  table(
    columns: (1.7fr, 0.8fr, 0.7fr, 2.1fr),
    align: (left + horizon, center + horizon, center + horizon, left + horizon),
    table.header([Ràng buộc], [Loại], [Độ cứng], [Ảnh hưởng tới kiến trúc]),
    [Nhóm ba thành viên, thời lượng thực tập 14 tuần], [Nguồn lực], [Cứng], [Loại bỏ mọi phương án đòi hỏi nhiều nhóm vận hành song song; ép chọn một mô hình mã nguồn thống nhất, một hình dạng thư mục lặp lại được.],
    [Hạ tầng tự quản trên một cụm nhỏ, không có ngân sách dịch vụ đám mây quản trị], [Kỹ thuật], [Cứng], [Loại bỏ các dịch vụ tìm kiếm, hàng đợi và kho vector quản trị; ép dồn nhiều năng lực về một hệ quản trị cơ sở dữ liệu duy nhất.],
    [Nền tảng không tự vận hành hạ tầng thanh toán], [Pháp lý], [Cứng], [Mọi dòng tiền vào ra phải qua cổng thanh toán bên thứ ba; nền tảng chỉ ghi nhận và đối soát, và phải chịu được webhook đến trễ, trùng hoặc không đến.],
    [Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân], [Pháp lý], [Cứng], [Dữ liệu định danh, số điện thoại, địa chỉ và tài khoản ngân hàng chỉ trả về cho chính chủ; nhân viên hỗ trợ phải ẩn danh ở mọi hình chiếu của tin nhắn.],
    [Chưa ký được hợp đồng với hãng vận chuyển thật], [Nghiệp vụ], [Cứng], [Đường vận chuyển hiện chỉ có bộ giả lập; kiến trúc phải cho phép thay đối tác mà không sửa mã nghiệp vụ và không làm hỏng các đơn đã phát sinh.],
    [Kinh nghiệm vận hành Kubernetes của nhóm còn hạn chế], [Nguồn lực], [Mềm], [Ưu tiên một ảnh chứa duy nhất, một tệp cấu hình duy nhất, triển khai theo mô hình GitOps tự đồng bộ thay vì kịch bản triển khai thủ công.],
    [Ưu tiên phần mềm nguồn mở, tránh phụ thuộc dịch vụ trả phí], [Tổ chức], [Mềm], [Chọn Grafana–Loki thay vì nền tảng quan trắc thương mại; chọn mô hình nhúng tự vận hành thay vì dịch vụ nhúng tính phí theo lượt gọi.],
  )
)

#figure(
  caption: [Ma trận xếp hạng các yếu tố dẫn dắt kiến trúc],
  table(
    columns: (0.5fr, 2.1fr, 0.8fr, 2.1fr),
    align: (center + horizon, left + horizon, center + horizon, left + horizon),
    table.header([Mã], [Yếu tố dẫn dắt], [Mức], [Rủi ro nếu không đáp ứng]),
    [AD-01], [Nguyên tử của dòng tiền tạm giữ], [Tới hạn], [Sai lệch số dư không thể đối soát; mất niềm tin vào toàn bộ sàn.],
    [AD-02], [Chuyển trạng thái theo thời hạn], [Tới hạn], [Tiền treo vô thời hạn, đơn hàng kẹt, phải can thiệp thủ công từng bản ghi.],
    [AD-08], [Kiểm toán bất biến], [Tới hạn], [Không chứng minh được ai làm gì khi có khiếu nại; vi phạm yêu cầu pháp lý.],
    [AD-07], [Một cửa tiếp nhận khiếu nại], [Tới hạn], [Cùng một sự vụ tồn tại ở ba nơi với ba trạng thái khác nhau; người dùng không biết hỏi ở đâu.],
    [AD-03], [Nhiều nhà cung cấp cùng loại], [Quan trọng], [Đổi đối tác trở thành sửa mã và di trú dữ liệu; các bản ghi cũ mất khả năng phân giải.],
    [AD-09], [Một hợp đồng cho ba giao diện khách], [Quan trọng], [Ba máy khách lệch nhau, lỗi tích hợp phát hiện muộn ở khâu kiểm thử.],
    [AD-05], [Thời gian thực], [Quan trọng], [Thương lượng giá mất tính tương tác; trải nghiệm rơi về mức làm mới thủ công.],
    [AD-04], [Tìm kiếm ngữ nghĩa], [Quan trọng], [Hàng hoá đăng đúng nhưng không ai tìm thấy — chức năng cốt lõi của sàn suy giảm.],
    [AD-06], [Bằng chứng đa phương tiện], [Mong muốn], [Phán quyết khiếu nại thiếu căn cứ; nhưng có thể thay thế tạm bằng liên kết ngoài.],
    [AD-10], [Khối lượng ở quy mô trình diễn], [Mong muốn], [Rủi ro thấp ở giai đoạn này; đáng chú ý ở chiều ngược lại là nguy cơ thiết kế thừa.],
  )
)

#note[*Giả định và câu hỏi còn mở.* Các mục tiêu hiệu năng nêu trên là mục tiêu thiết kế; Chương 6 đối chiếu chúng với số đo thực nghiệm và cho thấy phần lớn đã đạt, riêng yêu cầu về thông lượng khi tăng mức đồng thời thì chưa. Bên cạnh đó, con số 500 người dùng đồng thời là ước lượng của nhóm cho một bản trình diễn, không phải kết quả khảo sát thị trường; nếu quy mô thực tế lớn hơn một bậc, quyết định gom bảy lược đồ vào một cụm cơ sở dữ liệu sẽ phải xem lại — và kiến trúc đã được chuẩn bị sẵn cho việc đó bằng cách cấp cho mỗi dịch vụ một chuỗi kết nối riêng ngay từ đầu.]

== Lựa chọn công nghệ

Mỗi lựa chọn dưới đây đều truy về ít nhất một yếu tố dẫn dắt ở mục trước. Nguyên tắc xuyên
suốt là *chọn ít công nghệ nhất có thể*: mỗi thành phần hạ tầng thêm vào là một thứ nữa phải
cài đặt, giám sát, nâng cấp và giải thích cho người tiếp nhận bàn giao, mà nhóm chỉ có ba
người và mười bốn tuần (ràng buộc nguồn lực). Vì vậy, khi một hệ quản trị cơ sở dữ liệu quan
hệ có thể đảm nhiệm thêm vai trò của một kho vector hay một cơ sở dữ liệu chuỗi thời gian với
chất lượng chấp nhận được, nhóm chọn dồn về nó thay vì dựng thêm một hệ riêng.

#fig(
  [Chồng công nghệ của hệ thống ShopNexus theo tầng],
  spacing: (34mm, 12mm),
  np((0, 0), [*Tầng trình diễn*\ Next.js 16 · React 19 · Tailwind 4\ Flutter 3 · Dart 3 · Riverpod]),
  np((0, 1), [*Tầng cổng vào*\ Go 1.27 · thư viện chuẩn `net/http`\ JWT · WebSocket · OpenAPI]),
  np((0, 2), [*Tầng nghiệp vụ*\ Bảy dịch vụ miền · Uber fx\ Restate (thực thi bền, tuỳ chọn)]),
  np((0, 3), [*Tầng dữ liệu*\ PostgreSQL 18 · TimescaleDB\ pgvector · PostGIS · `pg_trgm`\ Redis 7 · kho đối tượng]),
  np((0, 4), [*Tầng hạ tầng*\ Docker · Kubernetes · Argo CD\ NATS JetStream · Grafana · Loki · Alloy]),
  edge((0, 0), (0, 1), "-|>", text(size: 8pt)[HTTPS · JSON]),
  edge((0, 1), (0, 2), "-|>", text(size: 8pt)[gọi nội tiến trình theo hợp đồng]),
  edge((0, 2), (0, 3), "-|>", text(size: 8pt)[pgx · SQL viết tay]),
  edge((0, 2), (0, 4), "-|>", stroke: (dash: "dashed"), text(size: 8pt)[sự kiện · mẫu đo]),
  nr((1.15, 1), text(size: 7.5pt)[Đặc tả OpenAPI và AsyncAPI\ là hợp đồng: sinh mã máy khách\ cho web và di động, sinh bộ giả lập]),
  edge((0, 1), (1.15, 1), stroke: (dash: "dashed")),
  nr((1.15, 3), text(size: 7.5pt)[Mỗi dịch vụ một lược đồ,\ một chuỗi kết nối riêng —\ tách được sang cụm khác\ mà không sửa câu lệnh nào]),
  edge((0, 3), (1.15, 3), stroke: (dash: "dashed")),
)

=== Ngôn ngữ và khung nền

Phía máy chủ chọn *Go 1.27*. Ba lý do dẫn từ các yếu tố dẫn dắt. Thứ nhất, mô hình đồng thời
của Go phù hợp trực tiếp với AD-05 và AD-02: một kênh WebSocket cho mỗi thiết bị và một vòng
lặp quét theo chu kỳ là những thứ viết ra tự nhiên trong Go mà không cần khung nền bất đồng bộ
riêng. Thứ hai, ảnh chứa của một chương trình Go biên dịch tĩnh chạy được trên ảnh nền tối
giản không chứa hệ điều hành, hợp với ràng buộc hạ tầng nhỏ và kinh nghiệm vận hành còn hạn
chế. Thứ ba, phiên bản 1.27 đưa `encoding/json/v2` vào thư viện chuẩn, và điều này không phải
tiểu tiết: ở phiên bản cũ, một danh sách rỗng được tuần tự hoá thành `null`, khiến "không có
kết quả nào" và "trường chưa được nạp" trở thành cùng một giá trị trên đường truyền, và mọi
máy khách phải tự phòng vệ. Đặc tả của hệ thống cam kết rằng một trường luôn có mặt với giá trị
rỗng của nó, và cam kết đó chỉ phát biểu được nhờ phiên bản mới.

Hệ thống *không dùng khung nền web*: bộ định tuyến là `net/http` của thư viện chuẩn, vốn từ
Go 1.22 đã hỗ trợ so khớp phương thức và tham số đường dẫn. Quyết định này là một hệ quả trực
tiếp của AD-09: khi đặc tả OpenAPI là hợp đồng và có kiểm thử đối chiếu bảo đảm mọi đường dẫn
trong đặc tả đều có tuyến thật, thì lợi ích còn lại của một khung nền chỉ là cú pháp. Truy cập
cơ sở dữ liệu dùng trình điều khiển `pgx` với *câu lệnh SQL viết tay và tham số đặt tên*; nhóm
không dùng ORM và cũng không dùng công cụ sinh mã truy vấn, bởi phần lớn câu lệnh trong hệ
thống này là ghi có điều kiện bảo vệ — cập nhật kèm mệnh đề kiểm tra trạng thái hiện tại rồi
đối chiếu số dòng bị ảnh hưởng — mà một lớp trừu tượng ở giữa sẽ che mất.

Phía máy khách web chọn *Next.js 16 với React 19*, chủ yếu vì khả năng kết xuất phía máy chủ
cho các trang bài đăng cần được máy tìm kiếm lập chỉ mục, và vì mã máy khách gọi API được sinh
tự động từ đặc tả nên phần lớn công việc còn lại là dựng giao diện. Ứng dụng di động chọn
*Flutter* để một mã nguồn phục vụ cả hai nền tảng, tương thích với ràng buộc nhóm ba người.

#figure(
  caption: [Ma trận đánh giá lựa chọn ngôn ngữ cho tầng máy chủ],
  table(
    columns: (1.35fr, 0.75fr, 0.75fr, 0.85fr, 2.1fr),
    align: (left + horizon, center + horizon, center + horizon, center + horizon, left + horizon),
    table.header([Tiêu chí (từ yếu tố dẫn dắt)], [Go], [Java\ (Spring)], [Node.js\ (NestJS)], [Nhận xét]),
    [Đồng thời cho kênh thời gian thực (AD-05)], [Tốt], [Khá], [Khá], [Go xử lý hàng nghìn kết nối bằng cơ chế đồng thời sẵn có; Node phù hợp nhưng chia sẻ trạng thái khó hơn; Java cần thư viện phản ứng.],
    [Tài nguyên và thời gian khởi động (ràng buộc hạ tầng)], [Tốt], [Yếu], [Khá], [Ảnh chứa Go dưới ngưỡng vài chục megabyte, khởi động dưới một giây, hợp với cụm nhỏ.],
    [Độ an toàn kiểu ở tầng nghiệp vụ (AD-01, AD-08)], [Khá], [Tốt], [Khá], [Java mạnh nhất, nhưng khoảng cách bị thu hẹp khi Go dùng kiểu định danh riêng cho từng loại khoá.],
    [Hệ sinh thái thư viện cần dùng], [Khá], [Tốt], [Tốt], [Go đủ dùng cho tất cả các tích hợp của đề tài; thiếu sót lớn nhất là công cụ phân tích tĩnh chưa theo kịp phiên bản mới.],
    [Năng lực sẵn có của nhóm], [Tốt], [Khá], [Khá], [Nhóm đã dùng Go ở giai đoạn trước của đề tài; chi phí chuyển đổi bằng không.],
    [*Kết luận*], [*Chọn*], [Loại], [Loại], [Go thắng ở ba tiêu chí gắn với các yếu tố dẫn dắt tới hạn, hoà ở phần còn lại.],
  )
)

=== Lưu trữ dữ liệu

Cơ sở dữ liệu chính là *PostgreSQL 18*, và lựa chọn đáng chú ý không nằm ở bản thân
PostgreSQL mà ở việc dồn thêm ba vai trò vào nó thay vì dựng ba hệ riêng. *pgvector* giữ chỉ
mục vector cho tìm kiếm ngữ nghĩa (AD-04), với vector dày 1.024 chiều kèm vector thưa và chỉ
mục dạng đồ thị phân cấp; nhờ nằm cùng cơ sở dữ liệu, một truy vấn tìm kiếm có thể lọc theo
danh mục, khoảng giá và tình trạng rồi xếp hạng theo khoảng cách ngữ nghĩa trong *một* câu
lệnh, thay vì lấy top-K từ một kho vector rồi lọc lại ở tầng ứng dụng và phát hiện ra không
còn đủ kết quả. *TimescaleDB* biến sáu bảng có đặc tính chuỗi thời gian — tin nhắn, thông báo
và bốn bảng tín hiệu quan trắc — thành siêu bảng chia mảnh theo thời gian, kèm chính sách nén
và chính sách xoá theo tuổi, nhờ đó dữ liệu vận hành không cần một hệ thống riêng và cũng
không phình vô hạn. *PostGIS* phục vụ lọc bài đăng theo khoảng cách địa lý, còn `pg_trgm`
cùng một hàm khử dấu tiếng Việt là phương án dự phòng khi chưa có vector: nếu tiến trình sinh
vector không chạy, tìm kiếm vẫn hoạt động ở mức so khớp chuỗi con, chỉ kém chính xác hơn.

*Redis 7* giữ ba loại dữ liệu có chung một đặc điểm: chúng phải biến mất theo thời gian. Đó là
bản ghi phiên đăng nhập, các bí mật dùng một lần (mã xác minh thư điện tử, mã đặt lại mật
khẩu, mã xác minh số điện thoại) và các khoá hạn chế tần suất gửi. Đặt chúng vào bảng cơ sở dữ
liệu sẽ kéo theo một tiến trình dọn dẹp, trong khi bản chất của chúng chính là một thời hạn
sống. Redis đồng thời đảm nhiệm vai trò trục sự kiện miền qua cấu trúc dòng, được trình bày ở
ADR-03.

Tệp và ảnh do người dùng tải lên (AD-06) không đi qua thân yêu cầu: máy khách xin một liên kết
đã ký, tải thẳng lên kho đối tượng, rồi xác nhận lại với dịch vụ chủ quản. Điều cần nhấn mạnh là
mỗi bản ghi tài nguyên *ghi nhớ kho đã lưu nó*, nên cấu hình chỉ chọn nơi ghi tiếp theo chứ
không chọn nơi đọc — mọi kho từng dùng đều còn đọc được.

#figure(
  caption: [Ma trận đánh giá phương án lưu trữ chỉ mục tìm kiếm ngữ nghĩa],
  table(
    columns: (1.3fr, 0.9fr, 0.95fr, 0.9fr, 1.9fr),
    align: (left + horizon, center + horizon, center + horizon, center + horizon, left + horizon),
    table.header([Tiêu chí], [pgvector\ trong Postgres], [Milvus /\ Weaviate], [Elasticsearch], [Nhận xét]),
    [Lọc thuộc tính kèm xếp hạng trong một truy vấn (NFR-03)], [Đạt], [Không], [Một phần], [Kho vector riêng buộc lọc lại ở tầng ứng dụng, gây thiếu kết quả sau khi lọc.],
    [Số thành phần hạ tầng phải vận hành], [0 thêm], [+1], [+1], [Ràng buộc nguồn lực loại bỏ mọi phương án làm tăng bề mặt vận hành mà không bắt buộc.],
    [Tìm kiếm lai đặc–thưa], [Đạt], [Đạt], [Đạt], [Cả ba đều làm được; pgvector hỗ trợ kiểu vector thưa ngay trong cột.],
    [Khả năng chịu quy mô rất lớn], [Trung bình], [Tốt], [Tốt], [Điểm yếu duy nhất của pgvector, nhưng không chạm tới ở quy mô AD-10.],
    [Phương án dự phòng khi thiếu vector], [Đạt], [Không], [Đạt], [`pg_trgm` cùng khử dấu cho phép tìm kiếm hoạt động ngay cả khi chưa sinh vector.],
    [*Kết luận*], [*Chọn*], [Loại], [Loại], [Xem ADR-04.],
  )
)

=== Hạ tầng và các thành phần hỗ trợ

Hệ thống dùng *hai* trục thông điệp với hai mục đích khác hẳn nhau, và đây là điểm dễ nhầm
nhất trong toàn bộ kiến trúc. Sự kiện miền — những sự việc đã xảy ra trong nghiệp vụ như một
phiên thanh toán đã hoàn tất hay một đơn hàng đã tất toán — đi trên *dòng Redis*, vì Redis đã
có mặt trong hệ thống cho phiên đăng nhập, và mô hình nhóm người tiêu thụ của nó đủ cho nhu
cầu "mỗi nhóm dịch vụ nhận đúng một lần". Mẫu đo quan trắc và tín hiệu phát tán thời gian thực
đi trên *NATS JetStream*, vì chúng có đặc tính hoàn toàn khác: lưu lượng lớn, mất một phần
chấp nhận được ở đầu phát nhưng phải bền một khi đã vào hàng đợi, và tiêu thụ theo lô lớn.
Trong đồ thị phụ thuộc, hai trục này được phân biệt *bằng kiểu dữ liệu* chứ không bằng tên,
để việc nối nhầm trở thành lỗi biên dịch chứ không phải một sự cố lặng lẽ lúc chạy.

*Restate* là bộ thực thi bền giữ các hẹn giờ dài (AD-02). Điều quan trọng là nó *không* nằm
trên đường đi của yêu cầu HTTP: không có yêu cầu nào của người dùng đi qua Restate. Mỗi dịch
vụ chủ động gửi một lượt chạy tới nó sau khi đã ghi bền bản ghi, và lời gọi ấy là *nỗ lực tốt
nhất* — bản ghi đã nằm trong cơ sở dữ liệu rồi, nên một bộ thực thi bền không sẵn sàng chỉ làm
đồng hồ chạy chậm hơn chứ không làm hỏng yêu cầu. Cấu hình cho phép tắt hẳn Restate; khi đó bộ
quét định kỳ là đồng hồ duy nhất, và đó vẫn là một triển khai hợp lệ.

Xác thực dùng *thẻ JWT* thời hạn 15 phút mang theo định danh tài khoản và định danh phiên, kết
hợp *bản ghi phiên* trong Redis với thời hạn 30 ngày. Thẻ ngắn hạn một mình không đủ vì NFR-10
và NFR-11 đòi hỏi thu hồi có hiệu lực ngay; bản ghi phiên một mình cũng không đủ vì mỗi yêu
cầu sẽ phải tra cứu đầy đủ. Cặp này cho phép thẻ tự mang thông tin nhưng phiên vẫn là nguồn sự
thật.

Quan trắc gồm hai đường tách biệt. Bốn tín hiệu số — nhịp và độ trễ yêu cầu vào, nhịp và độ trễ
lời gọi ra nhà cung cấp, số đo thời gian chạy và bản sao sự kiện nghiệp vụ — được ghi thành các
siêu bảng và đọc trực tiếp bởi *Grafana*, không qua Prometheus. Nhật ký ứng dụng ghi dạng JSON
ra đầu ra chuẩn, được *Alloy* thu và chuyển vào *Loki*, rồi cùng hiển thị trên Grafana. Phân
tích hành vi người dùng nằm ngoài phạm vi máy chủ, thu ở phía máy khách bằng một hệ thống riêng.

Về triển khai, mã nguồn được đóng thành ảnh chứa nhiều giai đoạn với ảnh phát hành dựa trên
nền tối giản không chứa hệ điều hành, đẩy lên kho ảnh của GitHub bằng GitHub Actions, và
*Argo CD* kéo về theo mô hình GitOps với chế độ tự đồng bộ và tự chữa lành. Việc áp migration
là một công việc riêng chạy như móc đồng bộ trước khi các bản sao ứng dụng được thay thế —
ứng dụng *không bao giờ* tự áp migration lúc khởi động.

#figure(
  caption: [Truy vết công nghệ tới yếu tố dẫn dắt hoặc ràng buộc],
  table(
    columns: (1.25fr, 0.9fr, 2.6fr),
    align: (left + horizon, center + horizon, left + horizon),
    table.header([Công nghệ], [Dẫn dắt bởi], [Vai trò trong kiến trúc]),
    [Go 1.27, `net/http`], [AD-05, AD-09, ràng buộc hạ tầng], [Cổng vào và toàn bộ tầng nghiệp vụ; ảnh chứa tĩnh, khởi động nhanh.],
    [Uber fx], [AD-10, ràng buộc nguồn lực], [Ghép nối các dịch vụ theo kiểu giao diện; thêm một dịch vụ là thêm một khai báo.],
    [PostgreSQL 18], [AD-01, AD-08, NFR-21], [Kho dữ liệu chính; giao dịch cục bộ cho dòng tiền và nhật ký kiểm toán.],
    [TimescaleDB], [AD-05, NFR-23], [Siêu bảng cho tin nhắn, thông báo và bốn tín hiệu quan trắc; nén và xoá theo tuổi.],
    [pgvector], [AD-04, NFR-03], [Chỉ mục vector đặt cạnh dữ liệu quan hệ, lọc và xếp hạng trong một truy vấn.],
    [PostGIS, `pg_trgm`], [AD-04, REQ-14, REQ-15], [Lọc theo khoảng cách địa lý; tìm kiếm chuỗi con khử dấu làm phương án dự phòng.],
    [Redis 7], [NFR-01, NFR-10, NFR-16], [Phiên đăng nhập, bí mật dùng một lần, hạn chế tần suất, bộ nhớ đệm, trục sự kiện miền.],
    [NATS JetStream], [AD-05, NFR-23], [Trục mẫu đo quan trắc và phát tán thời gian thực giữa các bản sao cổng vào.],
    [Restate], [AD-02, NFR-19], [Bộ thực thi bền giữ hẹn giờ dài; tuỳ chọn, có bộ quét định kỳ làm mạng lưới dự phòng.],
    [WebSocket], [AD-05, NFR-08], [Kênh đẩy hai chiều tới trình duyệt và ứng dụng di động.],
    [JWT kèm bản ghi phiên], [NFR-10, NFR-11, NFR-13], [Xác thực không lưu trạng thái nhưng thu hồi có hiệu lực ngay.],
    [Grafana, Loki, Alloy], [NFR-23, AD-08], [Bảng điều khiển vận hành và tra cứu nhật ký tập trung.],
    [Docker, Kubernetes, Argo CD], [Ràng buộc vận hành], [Đóng gói bất biến và triển khai khai báo tự đồng bộ.],
    [OpenAPI, AsyncAPI], [AD-09], [Hợp đồng sinh ra mã máy khách cho web và di động, và một bộ giả lập đầy đủ.],
  )
)

#figure(
  caption: [Rủi ro công nghệ và biện pháp giảm thiểu],
  table(
    columns: (1.5fr, 0.7fr, 2.6fr),
    align: (left + horizon, center + horizon, left + horizon),
    table.header([Rủi ro], [Mức], [Biện pháp đã áp dụng hoặc dự kiến]),
    [Go 1.27 còn ở bản phát hành thử; công cụ phân tích tĩnh chưa hỗ trợ], [Cao], [Ghi nhận công khai là khoảng trống đã biết; công cụ kiểm tra tĩnh của chính bộ công cụ Go vẫn chạy và không phát sinh cảnh báo. Khi công cụ phân tích bắt kịp, bổ sung vào quy trình tích hợp liên tục.],
    [Chưa tích hợp hãng vận chuyển thật], [Cao], [Đường vận chuyển được thiết kế như một sổ đăng ký nhiều nhà cung cấp; bộ giả lập hiện thực đầy đủ mười một kịch bản lỗi để mã nghiệp vụ được kiểm chứng trước khi có đối tác thật.],
    [Phụ thuộc một cụm cơ sở dữ liệu duy nhất], [T. bình], [Mỗi dịch vụ đã có chuỗi kết nối riêng ngay từ đầu; tách sang cụm khác là đổi một giá trị cấu hình, không sửa câu lệnh nào vì mọi câu lệnh đều không ghi tên lược đồ.],
    [Mô hình nhúng vector do một dịch vụ ngoài cung cấp, có thể đổi số chiều], [T. bình], [Số chiều là giá trị cấu hình bắt buộc và được đối chiếu với mọi câu trả lời; sai số chiều bị từ chối ngay thay vì âm thầm hỏng dữ liệu.],
    [Restate là hạ tầng mới với nhóm], [Thấp], [Bộ quét định kỳ luôn bật và là mạng lưới dự phòng; cấu hình tắt hẳn Restate vẫn là triển khai hợp lệ.],
    [Khoá cho phép sinh định danh mờ là vĩnh viễn], [T. bình], [Được ghi rõ trong ADR-05: đổi khoá làm vô hiệu mọi định danh đã phát hành ra ngoài, nên khoá phải được sao lưu như một bí mật cấp hệ thống.],
  )
)

== Kiến trúc tổng thể hệ thống

=== Kiểu kiến trúc và các phương án đã cân nhắc

Hệ thống được tổ chức theo *kiến trúc microservices phân rã theo miền nghiệp vụ*, gồm bảy dịch
vụ: `account`, `catalog`, `order`, `finance`, `chat`, `trust` và `observability`. Ba tính chất
định nghĩa kiểu kiến trúc này trong ShopNexus, và cả ba đều được cưỡng chế bằng cơ chế chứ
không chỉ bằng quy ước.

Thứ nhất, *mỗi dịch vụ sở hữu dữ liệu của mình một cách tuyệt đối*. Mỗi dịch vụ có một lược đồ
cơ sở dữ liệu riêng mang đúng tên nó, một chuỗi kết nối riêng và một nhóm kết nối riêng có
đường tìm kiếm cố định về lược đồ ấy. Hệ quả kỹ thuật là mọi câu lệnh SQL trong hệ thống —
cả câu lệnh định nghĩa lẫn câu lệnh truy vấn — đều *không ghi tên lược đồ*, nên một dịch vụ
không có cách nào chạm tới bảng của dịch vụ khác dù có muốn: câu lệnh sẽ không phân giải được.
Không tồn tại khoá ngoại xuyên lược đồ.

Thứ hai, *dịch vụ chỉ giao tiếp qua hợp đồng đã công bố*. Mỗi dịch vụ xuất bản một gói hợp đồng
gồm giao diện dịch vụ và các đối tượng truyền dữ liệu, và gói đó bị ràng buộc chỉ được nhập
những thành phần thuộc thư viện chuẩn. Một dịch vụ muốn dùng dịch vụ khác thì phụ thuộc vào
*giao diện* ấy, không bao giờ phụ thuộc vào gói hiện thực. Đây là điều làm cho một dịch vụ có
thể được thay bằng lời gọi mạng mà bên gọi không phải sửa dòng nào.

Thứ ba, *phần việc bất đồng bộ đi qua trục sự kiện* dưới dạng những sự việc đã xảy ra, không
phải mệnh lệnh. Một sự kiện mô tả điều đã thành sự thật trong miền phát ra nó; bên nhận tự
quyết định làm gì. Nhờ vậy, thêm một bên nhận mới không cần bên phát biết tới sự tồn tại của nó.

Bảy dịch vụ hiện được đóng gói và phát hành cùng nhau như một đơn vị triển khai, tương đương
mô hình nhiều dịch vụ trên một tiến trình. Đây là một *quyết định về ranh giới triển khai, không
phải về ranh giới kiến trúc*, và nó xuất phát trực tiếp từ AD-10 cùng ràng buộc nguồn lực: ở quy
mô 500 người dùng đồng thời, chi phí vận hành bảy tiến trình, bảy đường mạng nội bộ và bảy vòng
đời phát hành lớn hơn nhiều so với lợi ích thu được. Điều quan trọng là kiến trúc đã trả trước
toàn bộ chi phí để tách: dữ liệu đã cách ly, hợp đồng đã công bố, phụ thuộc đã một chiều, và
giao tiếp bất đồng bộ đã đi qua trục sự kiện. Việc tách một dịch vụ ra tiến trình riêng là thay
phần hiện thực của giao diện bằng một máy khách gọi mạng, và trỏ chuỗi kết nối của nó sang cụm
cơ sở dữ liệu khác.

Về quy mô, bản thiết kế này được hiện thực thành khoảng *160.700 dòng mã viết tay* trên ba kho mã:
dịch vụ nền, ứng dụng web và ứng dụng di động — chi tiết phân bổ trình bày ở Chương 5. Con số ấy
nêu ở đây vì nó là căn cứ cho nhận định phía trên: một khối mã cỡ này đã đủ lớn để ranh giới giữa
các miền phải được cưỡng chế bằng cơ chế, nhưng chưa đủ lớn để chi phí vận hành bảy tiến trình
riêng biệt trở nên xứng đáng.

#figure(
  caption: [Các kiểu kiến trúc đã cân nhắc và lý do lựa chọn],
  table(
    columns: (1.2fr, 2.2fr, 2.2fr, 0.7fr),
    align: (left + horizon, left + horizon, left + horizon, center + horizon),
    table.header([Phương án], [Ưu điểm], [Nhược điểm với đề tài này], [Kết quả]),
    [Khối đơn phân lớp ba tầng], [Đơn giản nhất; một cơ sở dữ liệu, một mô hình giao dịch.], [Không có ranh giới cưỡng chế được: một câu truy vấn nối bảng của hai miền là hợp lệ về mặt kỹ thuật, và sau vài tháng thì mọi thứ dính vào nhau. Không đáp ứng NFR-25.], [Loại],
    [Microservices phân rã theo miền], [Ranh giới dữ liệu và hợp đồng cưỡng chế được; tách tiến trình về sau không phải viết lại.], [Chi phí ban đầu cao hơn: phải nghĩ trước về quyền sở hữu dữ liệu và về tham chiếu chéo.], [*Chọn*],
    [Microservices tách tiến trình ngay từ đầu], [Mở rộng và phát hành độc lập từng dịch vụ.], [Bảy tiến trình, bảy đường mạng, bảy vòng đời phát hành cho nhóm ba người; giao dịch phân tán cho dòng tiền. Vượt xa nhu cầu ở AD-10.], [Hoãn],
    [Hướng sự kiện thuần tuý], [Tách rời tối đa; dễ thêm bên tiêu thụ.], [Đường đọc trở nên phức tạp; nhất quán cuối cùng không chấp nhận được cho số dư ví (NFR-21).], [Loại một phần],
    [Hàm không máy chủ], [Không phải vận hành máy chủ; tính tiền theo lượt gọi.], [Kết nối WebSocket dài và luồng nghiệp vụ kéo dài nhiều ngày không hợp mô hình; ràng buộc hạ tầng tự quản loại bỏ phương án này.], [Loại],
  )
)

=== Kiến trúc luận lý

#fig(
  [Kiến trúc luận lý hệ thống ShopNexus],
  spacing: (32mm, 11mm),
  np((0, 3), [*Ứng dụng khách*\ Web (Next.js)\ Di động (Flutter)\ Bảng quản trị]),
  edge((0, 3), (1.25, 3), "-|>", text(size: 8pt)[HTTPS · JSON]),
  ncore((1.25, 3), [*Cổng vào HTTP*\ `/api/v1`]),
  nr((1.25, 1.3), text(size: 7.5pt)[Lớp cắt ngang\ CORS · xác thực phiên\ định danh yêu cầu\ nhật ký · mẫu đo]),
  edge((1.25, 3), (1.25, 1.3), stroke: (dash: "dashed")),

  edge((1.25, 3), (2.85, 0), "-|>"),
  edge((1.25, 3), (2.85, 1), "-|>"),
  edge((1.25, 3), (2.85, 2), "-|>"),
  edge((1.25, 3), (2.85, 3), "-|>"),
  edge((1.25, 3), (2.85, 4), "-|>"),
  edge((1.25, 3), (2.85, 5), "-|>"),

  np((2.85, 0), [`account`\ định danh · phiên · liên hệ\ hồ sơ định danh · thông báo]),
  np((2.85, 1), [`catalog`\ danh mục · bài đăng · biến thể\ tồn kho · tìm kiếm]),
  np((2.85, 2), [`chat`\ hội thoại · tin nhắn\ luồng phiếu hỗ trợ]),
  np((2.85, 3), [`order`\ giỏ · đề nghị giá · đơn hàng\ vận chuyển · hoàn tiền]),
  np((2.85, 4), [`finance`\ phiên thanh toán · sổ cái\ ví · rút tiền]),
  np((2.85, 5), [`trust`\ đánh giá · uy tín · phiếu hỗ trợ]),
  np((2.85, 6.2), [`observability`\ bốn tín hiệu vận hành]),

  edge((2.85, 0), (4.5, 2), "-|>"),
  edge((2.85, 1), (4.5, 2), "-|>"),
  edge((2.85, 2), (4.5, 2), "-|>"),
  edge((2.85, 3), (4.5, 2), "-|>"),
  edge((2.85, 4), (4.5, 2), "-|>"),
  edge((2.85, 5), (4.5, 2), "-|>"),
  edge((2.85, 6.2), (4.5, 2), "-|>"),

  ng((4.5, 2), [*PostgreSQL 18*\ bảy lược đồ tách biệt\ TimescaleDB · pgvector\ PostGIS · `pg_trgm`]),
  ng((4.5, 4.2), [*Redis 7*\ phiên · bộ nhớ đệm\ bí mật dùng một lần]),
  edge((1.25, 3), (4.5, 4.2), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[tra phiên]),
  ng((4.5, 5.8), [*Kho đối tượng*\ ảnh và video minh chứng]),
  edge((2.85, 1), (4.5, 5.8), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[liên kết đã ký]),

  ng((0, 6.2), [*Nhà cung cấp bên ngoài*\ cổng thanh toán · hãng vận chuyển\ eKYC · SMS · thư điện tử\ OIDC · mô hình nhúng · LLM]),
  edge((2.85, 4), (0, 6.2), "<->", text(size: 7pt)[HTTPS]),
  edge((2.85, 3), (0, 6.2), "<->"),
  edge((2.85, 0), (0, 6.2), "<->"),
)

Bảy dịch vụ không đối xứng nhau về vai trò. `account` là dịch vụ *nền*: nó không phụ thuộc vào
dịch vụ nào khác, và sáu dịch vụ còn lại đều cần nó để biết người gọi là ai. `order` là dịch vụ
*điều phối*: nó là nơi duy nhất phụ thuộc vào bốn dịch vụ khác, vì một giao dịch mua bán chạm
tới bài đăng, tới người mua, tới tiền và tới hội thoại. `observability` là dịch vụ *bị động*: nó
không công bố hợp đồng nào và không ai gọi nó — nó được dẫn động bởi lớp cắt ngang ở cổng vào,
bởi bộ lấy mẫu và bởi trục sự kiện.

#figure(
  caption: [Quyền sở hữu dữ liệu và quy mô của từng dịch vụ],
  table(
    columns: (0.8fr, 2.4fr, 0.55fr, 0.6fr, 0.75fr),
    align: (left + horizon, left + horizon, center + horizon, center + horizon, center + horizon),
    table.header([Dịch vụ], [Dữ liệu sở hữu độc quyền], [Bảng], [Đường dẫn API], [Thao tác]),
    [`account`], [Tài khoản, danh tính liên kết, thiết bị, địa chỉ liên hệ, thông báo và tuỳ chọn nhận thông báo, quan hệ theo dõi, hồ sơ định danh.], [8], [41], [47],
    [`catalog`], [Danh mục, bài đăng, biến thể, thẻ, tồn kho và biến động tồn kho, yêu thích, ba bảng vector nhúng, quan tâm của người dùng.], [12], [17], [25],
    [`order`], [Giỏ hàng, đơn nháp, đề nghị giá, đơn hàng, dòng hàng, chặng vận chuyển, hồ sơ hoàn tiền.], [7], [30], [38],
    [`finance`], [Phiên thanh toán, giao dịch sổ cái, ví, biến động ví, tài khoản ngân hàng, thông tin thuế.], [6], [20], [25],
    [`chat`], [Hội thoại và tin nhắn.], [2], [8], [11],
    [`trust`], [Đánh giá giao dịch, nhận xét sản phẩm và phản hồi, bình chọn, điểm uy tín, phiếu hỗ trợ.], [7], [16], [22],
    [`observability`], [Bốn bảng tín hiệu vận hành và hai khung nhìn tổng hợp liên tục.], [4], [0], [0],
    [*Cộng bảng nghiệp vụ*], [], [*46*], [*132*], [*168*],
    [Dùng chung], [Nhật ký kiểm toán, tài nguyên tải lên, tuỳ chọn nhà cung cấp — định nghĩa một lần, tồn tại một bản trong *mỗi* lược đồ trừ `observability`.], [3×6\ = 18], [3], [3],
    [*Tổng*], [], [*64*], [*135*], [*171*],
  )
)

Cách phát biểu chính xác về quy mô mô hình dữ liệu là: *46 bảng nghiệp vụ trên bảy lược đồ, cộng
ba bảng dùng chung nhân thành 18 hiện thân, tổng cộng 64 bảng vật lý mang dữ liệu*. Ngoài số này
mỗi lược đồ còn một bảng ghi vết migration và miền quan trắc còn hai khung nhìn tổng hợp liên tục,
nhưng chúng không thuộc mô hình dữ liệu nghiệp vụ.

Hai hàng cuối của bảng cần một lời giải thích, vì chúng là một điểm thiết kế chứ không phải một
chi tiết kế toán. Ba bảng dùng chung — nhật ký kiểm toán, tài nguyên tải lên và tuỳ chọn nhà
cung cấp — có *văn bản định nghĩa duy nhất một bản*, nhưng được áp vào lược đồ của từng dịch vụ,
nên trong cơ sở dữ liệu tồn tại sáu bản sao độc lập. Lý do là hai điều kiện phải đồng thời đúng:
nhật ký kiểm toán phải nằm cùng giao dịch với thay đổi mà nó ghi lại (AD-08), và mỗi dịch vụ
phải mang được dữ liệu của mình sang cụm khác (NFR-25). Một bảng kiểm toán dùng chung đặt ở
lược đồ thứ tám sẽ phá vỡ cả hai. Ở giai đoạn trước của đề tài, bảy dịch vụ mỗi dịch vụ tự chép
tay một bảng kiểm toán và bốn trong số đó đã trôi lệch định nghĩa; việc đưa văn bản về một chỗ
mà vẫn giữ bảng ở từng lược đồ giải quyết đúng vấn đề ấy.

=== Trục sự kiện, thực thi bền và kênh thời gian thực

#fig(
  [Ba cơ chế bất đồng bộ: trục sự kiện miền, trục quan trắc và bộ hẹn giờ bền],
  spacing: (36mm, 15mm),
  np((0, 0), [Bên phát sự kiện\ `finance` · `order` · `trust` · `chat`]),
  edge((0, 0), (1, 0), "-|>", text(size: 7.5pt)[sự việc đã xảy ra]),
  ncore((1, 0), [*Dòng Redis*\ trục sự kiện miền]),
  edge((1, 0), (2, 0), "-|>", text(size: 7.5pt)[nhóm tiêu thụ]),
  np((2, 0), [Bên nhận sự kiện\ `order` · `trust` · `account`\ `observability`]),

  np((0, 1), [Bộ thu mẫu đo\ lớp cắt ngang · bộ lấy mẫu\ bộ quan sát lời gọi ra]),
  edge((0, 1), (1, 1), "-|>", text(size: 7.5pt)[nỗ lực tốt nhất]),
  ncore((1, 1), [*NATS JetStream*\ mẫu đo · phát tán thời gian thực]),
  edge((1, 1), (2, 1), "-|>", text(size: 7.5pt)[theo lô]),
  np((2, 1), [Bộ ghi siêu bảng quan trắc\ Trạm WebSocket → thiết bị]),

  np((0, 2), [Bộ quét định kỳ\ (luôn bật)]),
  edge((0, 2), (1, 2), "-|>"),
  ncore((1, 2), [*Một định nghĩa duy nhất*\ của "đã đến hạn":\ phương thức dịch vụ lũy đẳng]),
  edge((2, 2), (1, 2), "-|>"),
  np((2, 2), [Restate\ luồng bền · hẹn giờ\ (tuỳ chọn, tắt được)]),
)

Sơ đồ trên diễn đạt một nguyên tắc đã được nêu ở mục thuộc tính chất lượng: *hai nguồn dẫn động,
một định nghĩa*. Mọi khoảng chờ trong nghiệp vụ — phiên thanh toán chưa trả tiền hết hạn, cửa sổ
giữ tiền đóng lại, hạn xử lý hoàn tiền trôi qua, đánh giá mù đến lúc công bố — đều được viết
đúng một lần dưới dạng một phương thức dịch vụ *lũy đẳng*, nghĩa là gọi nó nhiều lần cho cùng
một bản ghi cũng chỉ có tác dụng như gọi một lần. Restate gọi phương thức ấy *đúng lúc*; bộ quét
định kỳ gọi cùng phương thức ấy *theo chu kỳ*. Không bên nào là một định nghĩa thứ hai về "đến
hạn", và đó là lý do việc bật cả hai không gây tác hại: khi Restate hoạt động bình thường, bộ
quét chạy và không tìm thấy gì.

=== Mẫu giao tiếp

#figure(
  caption: [Các mẫu giao tiếp giữa thành phần],
  table(
    columns: (1.15fr, 1.15fr, 0.85fr, 0.6fr, 1.9fr),
    align: (left + horizon, left + horizon, left + horizon, center + horizon, left + horizon),
    table.header([Từ], [Tới], [Giao thức], [Kiểu], [Mục đích]),
    [Ứng dụng khách], [Cổng vào], [HTTPS/JSON], [Đồng bộ], [Toàn bộ thao tác đọc và ghi nghiệp vụ.],
    [Ứng dụng khách], [Cổng vào], [WebSocket], [Bất đồng bộ], [Nhận tin nhắn, thông báo, biến động đề nghị giá và đơn hàng.],
    [Ứng dụng khách], [Kho đối tượng], [HTTPS đã ký], [Đồng bộ], [Tải tệp lên và tải xuống, không đi qua thân yêu cầu nghiệp vụ.],
    [Cổng vào], [Dịch vụ miền], [Gọi theo hợp đồng], [Đồng bộ], [Bộ xử lý tuyến gọi giao diện dịch vụ đã công bố.],
    [Dịch vụ miền], [Dịch vụ miền], [Gọi theo hợp đồng], [Đồng bộ], [Đọc dữ liệu thuộc miền khác; luôn qua giao diện, không bao giờ qua cơ sở dữ liệu.],
    [Dịch vụ miền], [Dòng Redis], [Dòng, nhóm tiêu thụ], [Bất đồng bộ], [Phát sự việc đã xảy ra; bên nhận tự quyết định hành động.],
    [Lớp cắt ngang], [NATS JetStream], [Chủ đề, nỗ lực tốt nhất], [Bất đồng bộ], [Đẩy mẫu đo quan trắc; không bao giờ chặn yêu cầu.],
    [Cổng vào], [NATS JetStream], [Chủ đề], [Bất đồng bộ], [Phát tán sự kiện thời gian thực giữa các bản sao cổng vào.],
    [Dịch vụ miền], [Restate], [HTTP], [Bất đồng bộ], [Gửi một lượt chạy giữ hẹn giờ; nỗ lực tốt nhất, hỏng không ảnh hưởng yêu cầu.],
    [Restate], [Dịch vụ miền], [HTTP], [Đồng bộ], [Gọi lại phương thức lũy đẳng khi hẹn giờ đến hạn.],
    [Dịch vụ miền], [Nhà cung cấp ngoài], [HTTPS], [Đồng bộ], [Báo giá vận chuyển, khởi tạo thanh toán, xác minh danh tính, gửi thư và tin nhắn.],
    [Nhà cung cấp ngoài], [Cổng vào], [HTTPS webhook], [Bất đồng bộ], [Báo kết quả thanh toán và mốc hành trình vận chuyển.],
    [Dịch vụ miền], [PostgreSQL], [Nhóm kết nối pgx], [Đồng bộ], [Đọc ghi trong lược đồ của chính mình; không có đường nào tới lược đồ khác.],
  )
)

Một quy tắc cần nhấn mạnh vì nó đi ngược trực giác thông thường: *đường phản hồi của nhà cung
cấp là webhook, không phải trang mà người dùng được chuyển tới*. Cả hai cổng thanh toán đang
tích hợp đều nhận một địa chỉ quay về và đều trỏ *mọi* kết cục — thành công, thất bại, huỷ bỏ —
về cùng một trang. Nơi người trả tiền dừng chân là một khẳng định mà bất kỳ ai cũng có thể giả
mạo; chỉ lời gọi lại từ phía nhà cung cấp mới quyết toán được một khoản. Hệ quả thiết kế: nếu
xử lý một lời gọi lại thất bại, hệ thống trả về mã lỗi máy chủ để nhà cung cấp *thử lại*, bởi
lời gọi ấy là thứ duy nhất còn kể lại được sự việc.

#figure(
  caption: [Các điểm tích hợp với hệ thống bên ngoài],
  table(
    columns: (0.85fr, 1.35fr, 1.05fr, 2.1fr),
    align: (left + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Đường tích hợp], [Đối tác hiện có], [Cách chọn], [Ghi chú kiến trúc]),
    [Thanh toán], [SePay, Stripe, bộ giả lập], [Sổ đăng ký theo hàng dữ liệu], [Nhiều đường tiền hoạt động đồng thời; một giao dịch đã quyết toán ghi nhớ vĩnh viễn đối tác đã phục vụ nó.],
    [Vận chuyển], [Chỉ có bộ giả lập], [Sổ đăng ký theo hàng dữ liệu], [Chưa có đối tác thật; bộ giả lập hiện thực mười một kịch bản lỗi, kể cả mốc hành trình đến sai thứ tự và trạng thái nền tảng không mô hình hoá.],
    [Kho đối tượng], [Hệ tệp cục bộ, nguồn ngoài chỉ đọc], [Cấu hình chọn *nơi ghi*], [Mỗi tài nguyên ghi nhớ kho đã lưu nó, nên mọi kho từng dùng đều còn đọc được.],
    [Thư điện tử], [SMTP, bộ giả lập], [Bộ chọn cấu hình], [Vô hướng nhà cung cấp; dùng thư viện chuẩn.],
    [Tin nhắn SMS], [eSMS.vn, bộ giả lập], [Bộ chọn cấu hình], [Mẫu tin nhắn được kiểm chứng ngay lúc khởi động: dựng thử một mã xác minh và bắt buộc mã ấy phải xuất hiện trong kết quả.],
    [Đăng nhập liên kết], [OIDC (Google, Apple), bộ giả lập], [Bộ chọn cấu hình], [Xác minh thẻ định danh do nhà cung cấp phát hành.],
    [Xác minh danh tính], [FPT.AI eKYC, bộ giả lập], [Bộ chọn cấu hình], [Che giấu khác biệt giữa nhà cung cấp trả kết quả ngay và nhà cung cấp chạy luồng riêng.],
    [Mô hình nhúng vector], [Dịch vụ tự vận hành, bộ giả lập], [Bộ chọn cấu hình], [Số chiều được đối chiếu với mọi câu trả lời; sai số chiều bị từ chối.],
    [Mô hình ngôn ngữ lớn], [Máy chủ uỷ nhiệm, bộ giả lập], [Bộ chọn cấu hình], [Dùng cho gợi ý điền biểu mẫu đăng bán và chuyển giọng nói thành văn bản.],
  )
)

Ba đường tích hợp đầu bảng khác về bản chất với sáu đường còn lại, và khác biệt ấy là một quyết
định kiến trúc được ghi ở ADR-06. Sáu đường sau chọn *một* nhà cung cấp tại thời điểm triển khai:
hệ thống chỉ gửi thư qua một máy chủ, chỉ xác minh danh tính bằng một dịch vụ. Ba đường đầu thì
không thể, vì một bản ghi đã phát sinh *ghi nhớ* tên đối tác đã phục vụ nó — một giao dịch đã
quyết toán và một kiện hàng đã gửi giữ tên ấy vĩnh viễn. Nếu chọn bằng một biến cấu hình, thì
đổi cấu hình sẽ khiến các bản ghi cũ không còn phân giải được.

=== Kiến trúc triển khai

#fig(
  [Kiến trúc triển khai và đường phát hành],
  spacing: (33mm, 13mm),
  nact((0, 1), [Người\ dùng]),
  edge((0, 1), (1, 1), "-|>", text(size: 7.5pt)[HTTPS]),
  ng((1, 1), [Ingress\ chấm dứt TLS]),
  edge((1, 1), (2, 0.3), "-|>"),
  edge((1, 1), (2, 1.7), "-|>"),
  np((2, 0.3), [`gateway`\ nhiều bản sao\ không lưu trạng thái]),
  np((2, 1.7), [`website`\ Next.js dựng sẵn]),
  edge((2, 0.3), (3, 0), "-|>"),
  edge((2, 0.3), (3, 1), "-|>"),
  edge((2, 0.3), (3, 2), "-|>"),
  ng((3, 0), [PostgreSQL\ + TimescaleDB]),
  ng((3, 1), [Redis]),
  ng((3, 2), [NATS JetStream]),
  nr((2, 3), text(size: 7.5pt)[Công việc áp migration\ chạy như móc đồng bộ,\ trước khi thay bản sao ứng dụng]),
  edge((2, 3), (3, 0), "-|>", stroke: (dash: "dashed")),
  np((0, 3), [GitHub Actions\ dựng ảnh · kiểm tra đặc tả]),
  edge((0, 3), (1, 3), "-|>", text(size: 7.5pt)[đẩy ảnh]),
  ng((1, 3), [Kho ảnh chứa]),
  edge((1, 3), (1, 4), "-|>"),
  ncore((1, 4), [Argo CD\ GitOps · tự đồng bộ · tự chữa lành]),
  edge((1, 4), (2, 3), "-|>", stroke: (dash: "dashed")),
  edge((1, 4), (2, 0.3), "-|>", stroke: (dash: "dashed"), text(size: 7.5pt)[áp trạng thái mong muốn]),
)

Quy trình phát hành có ba tính chất đáng nêu. *Ảnh phát hành được chỉ định tường minh* trong
cấu hình dựng chứ không dựa vào quy ước "giai đoạn cuối thắng" — nếu về sau có ai thêm một giai
đoạn phát triển vào cuối tệp dựng, ảnh phát hành sẽ không vì thế mà mang theo cả bộ công cụ biên
dịch. *Việc áp migration là một công việc riêng*, chạy như móc đồng bộ ở đợt trước đợt thay thế
bản sao ứng dụng, và ứng dụng không bao giờ tự migrate lúc khởi động; nhờ vậy một bản sao khởi
động lại vì lý do bất kỳ không thể vô tình thay đổi lược đồ. *Quy trình tích hợp liên tục không
triển khai* — nó chỉ dựng và đẩy ảnh, còn Argo CD kéo về theo mô hình GitOps, nên trạng thái
thật của cụm luôn là thứ được mô tả trong kho mã.

Cần ghi nhận trung thực một khoảng trống: cổng kiểm tra tự động duy nhất hiện có ở phía máy chủ
là *kiểm tra đặc tả OpenAPI không lệch* so với mã nguồn. Quy trình tích hợp liên tục chưa chạy
bộ kiểm thử; việc chạy kiểm thử và phân tích tĩnh hiện làm thủ công. Chương 6 trình bày chi tiết
hiện trạng này.

== Các bản ghi quyết định kiến trúc

Mục này ghi lại tám quyết định có ảnh hưởng vượt ra ngoài một tính năng đơn lẻ, theo mẫu bản ghi
quyết định kiến trúc: bối cảnh, các phương án đã cân nhắc, quyết định, và hệ quả — bao gồm cả hệ
quả tiêu cực đã chấp nhận. Bốn bản ghi đầu là phiên bản đã hiệu chỉnh của bốn quyết định đã công
bố ở báo cáo định kỳ; bốn bản ghi sau ghi nhận những quyết định phát sinh trong quá trình hiện
thực mà báo cáo trước chưa nêu.

#figure(
  caption: [Tổng hợp các bản ghi quyết định kiến trúc],
  table(
    columns: (0.5fr, 2.6fr, 0.85fr, 1.4fr),
    align: (center + horizon, left + horizon, center + horizon, left + horizon),
    table.header([Mã], [Quyết định], [Trạng thái], [Dẫn dắt bởi]),
    [ADR-01], [Phân rã theo miền, mỗi dịch vụ một lược đồ riêng], [Chấp nhận], [AD-01, NFR-25],
    [ADR-02], [Thực thi bền tuỳ chọn kèm bộ quét định kỳ luôn bật], [Hiệu chỉnh], [AD-02, NFR-19],
    [ADR-03], [Hai trục thông điệp phân biệt theo mục đích], [Hiệu chỉnh], [AD-05, NFR-08],
    [ADR-04], [Tìm kiếm ngữ nghĩa trong cơ sở dữ liệu quan hệ, hàng đợi theo trạng thái], [Hiệu chỉnh], [AD-04, NFR-03],
    [ADR-05], [Định danh mờ trên đường truyền], [Chấp nhận], [NFR-12, NFR-14],
    [ADR-06], [Chọn nhà cung cấp theo hàng dữ liệu, không theo biến cấu hình], [Chấp nhận], [AD-03],
    [ADR-07], [Cấu hình là một tài liệu duy nhất, mọi trường bắt buộc], [Chấp nhận], [Ràng buộc vận hành],
    [ADR-08], [Đơn hàng sinh ra từ việc trả tiền, không từ phê duyệt của người bán], [Chấp nhận], [AD-01, REQ-26…29],
  )
)

=== ADR-01: Phân rã theo miền, mỗi dịch vụ sở hữu một lược đồ riêng

*Bối cảnh.* Nghiệp vụ của sàn chạm tới bảy nhóm dữ liệu khác nhau về nhịp thay đổi, về mức nhạy
cảm và về người chịu trách nhiệm. Nếu tất cả nằm chung một lược đồ, không có gì ngăn một câu
truy vấn nối bảng đơn hàng với bảng tài khoản và bảng bài đăng, và sau vài tháng thì việc tách
bất kỳ phần nào ra cũng trở thành viết lại. NFR-25 phát biểu điều này thành một yêu cầu nghiệm
thu được.

*Phương án đã cân nhắc.* Một là dùng chung một lược đồ và chỉ tách theo gói mã nguồn, dựa vào
kỷ luật của người viết; rẻ nhất nhưng không cưỡng chế được. Hai là bảy cơ sở dữ liệu vật lý
riêng ngay từ đầu; cưỡng chế mạnh nhất nhưng tốn bảy lần chi phí vận hành, sao lưu và giám sát,
vượt ràng buộc nguồn lực. Ba là bảy lược đồ trong một cụm, mỗi lược đồ một chuỗi kết nối riêng.

*Quyết định.* Chọn phương án ba. Mỗi dịch vụ nhận một chuỗi kết nối riêng, và nhóm kết nối của
nó đặt đường tìm kiếm cố định về lược đồ của chính nó. Hệ quả kỹ thuật quan trọng nhất là *mọi
câu lệnh SQL đều không ghi tên lược đồ*: một câu lệnh cố chạm tới bảng của dịch vụ khác sẽ không
phân giải được tên. Không có khoá ngoại xuyên lược đồ; tham chiếu chéo là tham chiếu luận lý,
giải quyết qua hợp đồng đã công bố.

*Hệ quả.* Tích cực: việc tách một dịch vụ sang cụm cơ sở dữ liệu khác chỉ là đổi một giá trị
cấu hình; và một truy vấn nặng ở dịch vụ này không thể khoá bảng của dịch vụ khác. Tiêu cực đã
chấp nhận: những dữ liệu cần đọc chéo phải được *sao chép có chủ đích* thay vì nối bảng — điểm
đánh giá trung bình của một bài đăng được miền uy tín tính rồi đẩy sang miền danh mục, vì hai
bảng nằm ở hai lược đồ và không thể nối. Đây là chi phí trực tiếp của quyết định này và được
chấp nhận có ý thức.

=== ADR-02: Thực thi bền là tuỳ chọn, bộ quét định kỳ luôn bật

*Bối cảnh.* Hệ thống có năm loại hẹn giờ dài (AD-02), và một hẹn giờ giữ trong bộ nhớ tiến trình
sẽ biến mất sau mỗi lần phát hành. Báo cáo định kỳ trước đã chọn Restate cho việc này, nhưng mô
tả nó như *trung tâm điều phối bắt buộc* mà mọi thao tác ghi phải đi qua. Quá trình hiện thực cho
thấy mô tả ấy vừa không đúng vừa không nên: đặt một hạ tầng bên ngoài trên đường đi của mọi yêu
cầu ghi nghĩa là nó sập thì sàn ngừng bán hàng.

*Phương án đã cân nhắc.* Một là tự viết máy trạng thái kiểu Saga kèm mã bù trừ; đúng về lý thuyết
nhưng lượng mã xử lý ngoại lệ lớn và khó kiểm thử. Hai là chỉ dùng bộ quét định kỳ trên cơ sở dữ
liệu; đơn giản nhất nhưng độ trễ bằng chu kỳ quét, và một chu kỳ đủ ngắn thì tốn tài nguyên. Ba
là dùng Restate làm cổng vào bắt buộc. Bốn là dùng Restate như một *nguồn dẫn động*, không phải
cổng vào.

*Quyết định.* Chọn phương án bốn. Mỗi chuyển trạng thái theo thời hạn được viết đúng một lần
dưới dạng một phương thức dịch vụ lũy đẳng. Restate được gọi *sau khi* bản ghi đã được ghi bền,
và lời gọi ấy là nỗ lực tốt nhất. Bộ quét định kỳ gọi cùng những phương thức ấy theo chu kỳ và
*luôn bật*. Cấu hình cho phép tắt hẳn Restate, khi đó bộ quét là đồng hồ duy nhất, và đó là một
triển khai được hỗ trợ chứ không phải chế độ suy giảm.

*Hệ quả.* Tích cực: không yêu cầu người dùng nào phụ thuộc vào một hạ tầng bên ngoài; và vì hai
nguồn dẫn động chia sẻ một định nghĩa duy nhất về "đến hạn", bật cả hai không gây trùng lặp
tác dụng. Tiêu cực: mỗi phương thức như vậy *phải* lũy đẳng, đây là một ràng buộc thật lên cách
viết mã và là nguồn lỗi nếu bị vi phạm; hệ thống chống lại bằng cách để chính câu lệnh ghi mang
điều kiện bảo vệ trạng thái, thay vì kiểm tra rồi mới ghi.

=== ADR-03: Hai trục thông điệp, phân biệt theo mục đích

*Bối cảnh.* Báo cáo định kỳ trước công bố NATS JetStream là trục sự kiện cho mọi giao tiếp bất
đồng bộ, kèm mẫu hộp thư đi ghi sự kiện vào một bảng trong cùng giao dịch. Khi hiện thực, hai
loại lưu lượng bất đồng bộ bộc lộ đặc tính rất khác nhau. Sự kiện miền thì thưa, quan trọng từng
thông điệp, và bên nhận là các nhóm dịch vụ nghiệp vụ. Mẫu đo quan trắc thì dày đặc, mất một
phần chấp nhận được, và tiêu thụ theo lô lớn để ghi vào siêu bảng.

*Phương án đã cân nhắc.* Một là dùng một trục cho cả hai; đơn giản về mặt vận hành nhưng buộc
phải cấu hình theo loại lưu lượng khắt khe hơn, khiến mẫu đo trở nên đắt. Hai là dùng hai trục.
Ba là giữ mẫu hộp thư đi cho sự kiện miền.

*Quyết định.* Dùng hai trục. Sự kiện miền đi trên *dòng Redis* với mô hình nhóm tiêu thụ, vì
Redis đã có mặt cho phiên đăng nhập nên không thêm thành phần hạ tầng nào. Mẫu đo quan trắc và
tín hiệu phát tán thời gian thực đi trên *NATS JetStream*. Trong đồ thị phụ thuộc, hai trục được
phân biệt bằng *kiểu dữ liệu*, để nối nhầm là lỗi biên dịch. Không hiện thực mẫu hộp thư đi:
vai trò "ghi cùng giao dịch với thay đổi" đã do *nhật ký kiểm toán* đảm nhiệm (AD-08), và thêm
một bảng hộp thư nữa là ghi hai lần cùng một sự thật.

*Hệ quả.* Tích cực: mỗi trục được cấu hình đúng theo đặc tính lưu lượng của nó; và mẫu đo không
bao giờ làm chậm hay làm hỏng một yêu cầu nghiệp vụ, vì phát mẫu là nỗ lực tốt nhất và mẫu không
gửi được thì chỉ bị đếm. Tiêu cực: có hai hạ tầng thông điệp phải hiểu và giám sát thay vì một;
và vì không có hộp thư đi, một sự kiện miền có thể mất nếu Redis không sẵn sàng đúng lúc phát —
hệ thống chấp nhận điều này vì mọi bên nhận đều có đường phục hồi độc lập (bộ quét định kỳ, hoặc
sửa chữa lúc đọc).

=== ADR-04: Tìm kiếm ngữ nghĩa trong cơ sở dữ liệu quan hệ, hàng đợi là trạng thái của dữ liệu

*Bối cảnh.* AD-04 đòi hỏi tìm kiếm ngôn ngữ tự nhiên trên dữ liệu do người bán tự đặt tên. Báo
cáo định kỳ trước đã chọn đúng công nghệ (chỉ mục vector đặt trong PostgreSQL, mô hình nhúng đa
ngôn ngữ) nhưng đặt sai chỗ — gán cho một dịch vụ phân tích không tồn tại — và mô tả sai cơ chế
cập nhật, cho rằng vector được sinh khi nhận sự kiện từ trục thông điệp.

*Phương án đã cân nhắc.* Về nơi đặt: một dịch vụ phân tích riêng, hay chính miền danh mục. Về cơ
chế cập nhật: sinh vector đồng bộ ngay trong lời gọi ghi bài đăng; hoặc sinh khi nhận sự kiện;
hoặc đánh dấu bản ghi là *đã cũ* và để một tiến trình riêng rút cạn dấu ấy.

*Quyết định.* Chỉ mục vector đặt trong *miền danh mục*, nơi sở hữu bài đăng, vì một chỉ mục tìm
kiếm bài đăng là dữ liệu dẫn xuất của bài đăng chứ không phải của một miền khác. Cơ chế cập nhật
là *hàng đợi bằng trạng thái*: mỗi bảng có chỉ mục mang một cột đánh dấu thời điểm nội dung thay
đổi, và một chương trình riêng rút cạn dấu ấy rồi xoá dấu bằng câu lệnh có điều kiện bảo vệ đúng
giá trị đã đọc. Sinh vector *không* chạy trong tiến trình phục vụ yêu cầu.

*Hệ quả.* Tích cực: hàng đợi là một thuộc tính của dữ liệu chứ không phải một thông điệp có thể
mất, nên một bản ghi bị sửa trong lúc đang phát hành vẫn còn dấu sau đó, và một lượt chạy đã hoàn
tất sẽ không tìm thấy gì; việc *không* chạy tiến trình sinh vector vẫn là một triển khai được hỗ
trợ, khi đó tìm kiếm lùi về so khớp chuỗi con khử dấu. Tiêu cực: có thêm một chương trình phải
vận hành; và chỉ mục có độ trễ so với dữ liệu gốc, nên một bài đăng vừa sửa tên có thể còn được
tìm thấy theo tên cũ trong khoảng thời gian giữa hai lượt chạy.

=== ADR-05: Định danh mờ trên đường truyền

*Bối cảnh.* Mọi khoá thay thế trong cơ sở dữ liệu là số nguyên tăng dần. Nếu số ấy xuất hiện
nguyên vẹn trên giao diện lập trình, hai điều bất lợi xảy ra: nó tiết lộ quy mô và tốc độ tăng
trưởng của nền tảng, và nó mời gọi việc dò tuần tự tài nguyên của người khác — một dạng tấn công
mà NFR-14 phải chặn ở tầng nghiệp vụ, nhưng không có lý do gì để làm cho nó dễ dàng.

*Phương án đã cân nhắc.* Một là dùng khoá dạng định danh toàn cầu ngẫu nhiên trong cơ sở dữ liệu;
giải quyết được việc dò nhưng đánh đổi bằng chỉ mục lớn hơn và cục bộ hoá kém. Hai là thêm một
cột "mã hiển thị" bên cạnh khoá số; tốn một cột, một chỉ mục và một lần tra cứu cho mỗi lần đọc.
Ba là giữ khoá số trong cơ sở dữ liệu và *biến đổi thuận nghịch* nó ở biên của đối tượng truyền
dữ liệu.

*Quyết định.* Chọn phương án ba. Miền, cổng dữ liệu và bộ điều hợp làm việc với số nguyên; trường
định danh trong đối tượng truyền dữ liệu là một kiểu riêng, tuần tự hoá thành một chuỗi có tiền
tố theo loại thực thể, sinh bằng một hoán vị có khoá trên toàn dải số nguyên rồi mã hoá cơ số 32.
Việc chuyển đổi chỉ xảy ra đúng ở biên.

*Hệ quả.* Tích cực: không tốn cột nào, không tốn lần tra cứu nào, và tiền tố giúp một định danh
gửi nhầm loại bị từ chối ngay thay vì trỏ vào bản ghi khác. Tiêu cực đã chấp nhận: tiền tố và
khoá sinh mã là *vĩnh viễn* — đổi chúng làm vô hiệu mọi định danh đã phát hành ra bên ngoài, nên
khoá phải được sao lưu và bảo vệ như một bí mật cấp hệ thống.

=== ADR-06: Chọn nhà cung cấp theo hàng dữ liệu, không theo biến cấu hình

*Bối cảnh.* AD-03 nêu rằng một giao dịch đã quyết toán và một kiện hàng đã gửi *ghi nhớ* tên đối
tác đã phục vụ nó, vĩnh viễn. Nếu việc chọn đối tác là một giá trị cấu hình toàn hệ thống, thì
việc chuyển hãng vận chuyển sẽ đồng thời thay đổi cách phân giải của mọi đơn hàng cũ và đòi hỏi
khởi động lại toàn bộ.

*Phương án đã cân nhắc.* Một là một bộ chọn cấu hình cho mỗi loại, giống như thư điện tử và tin
nhắn. Hai là một sổ đăng ký giữ *mọi* hiện thực có trong bản dựng, phân giải theo tên mà hàng dữ
liệu ghi lại.

*Quyết định.* Với thanh toán và vận chuyển, dùng sổ đăng ký. Danh sách cấu hình liệt kê những
hiện thực cần *đăng ký*, không phải hiện thực được *chọn*; nhờ đó nhiều đường tiền có thể cùng
hoạt động, và việc chuyển một hãng vận chuyển sang đối tác khác là một thao tác sửa dữ liệu trong
bảng tuỳ chọn, giữ nguyên tên định danh và mọi đơn hàng trỏ tới nó. Mỗi hiện thực tự *khai báo*
những hàng nó phục vụ, và hệ thống đối chiếu lại danh sách ấy lúc khởi động. Một tên mà không
hiện thực nào đăng ký sẽ bị *từ chối*, không bao giờ được thay thế bằng một đối tác khác.

*Hệ quả.* Tích cực: bộ giả lập nằm ngoài danh sách đăng ký của môi trường thật thì không hàng dữ
liệu nào gọi tới được, nên tồn tại của nó vô hại; và danh sách người mua nhìn thấy khi thanh
toán tự động loại bỏ những lựa chọn mà bản dựng hiện tại không phục vụ. Tiêu cực: có thêm một
lớp phân giải theo tên, và một cấu hình sai sẽ biểu hiện thành lỗi lúc chạy thay vì lỗi lúc khởi
động — hệ thống bù lại bằng việc đối chiếu danh sách tuỳ chọn ngay khi khởi động.

=== ADR-07: Cấu hình là một tài liệu duy nhất, mọi trường bắt buộc

*Bối cảnh.* Ở giai đoạn trước, cấu hình nằm rải trong biến môi trường kèm giá trị mặc định. Điều
này gây ra một lớp sự cố đặc trưng: một biến bị gõ sai tên thì hệ thống lặng lẽ dùng giá trị mặc
định và *chạy*, nhưng chạy sai — nghĩ rằng mình đang gửi thư thật trong khi không gửi gì cả.

*Phương án đã cân nhắc.* Một là giữ biến môi trường nhưng bắt buộc mọi biến. Hai là một tài liệu
cấu hình duy nhất, kiểm tra hợp lệ khi nạp.

*Quyết định.* Toàn bộ cấu hình là *một tài liệu duy nhất*. Không có biến môi trường cho bất kỳ
giá trị nào, không có mặc định. Mọi trường đều bắt buộc; một khoá lạ cũng làm việc nạp thất bại;
một giá trị sai định dạng làm hệ thống dừng ngay lúc khởi động và *nêu đúng đường dẫn cần sửa*
trong tài liệu. Biến môi trường duy nhất còn lại chỉ quyết định tài liệu ấy nằm ở đâu.

*Hệ quả.* Tích cực: một triển khai cấu hình sai thì không khởi động được, thay vì khởi động rồi
hỏng âm thầm; và toàn bộ cấu hình của hệ thống đọc được trong một tệp. Tiêu cực: mỗi lần thêm một
trường là một thay đổi bắt buộc ở mọi môi trường, không có đường lùi êm ái bằng giá trị mặc định.
Đây là đánh đổi có chủ ý — sự bất tiện xảy ra lúc triển khai, là nơi rẻ nhất để phát hiện lỗi.

=== ADR-08: Đơn hàng sinh ra từ việc trả tiền, không từ phê duyệt của người bán

*Bối cảnh.* Thiết kế ở báo cáo định kỳ trước đặt một bước *người bán xác nhận mục chờ* giữa việc
người mua trả tiền và việc đơn hàng ra đời, kèm một khoản phí xác nhận thu của người bán. Khi
dựng luồng đầy đủ, bước này bộc lộ ba vấn đề: nó tạo ra một trạng thái trong đó tiền đã bị thu
nhưng đơn hàng chưa tồn tại và không ai chịu trách nhiệm; nó cho phép người bán từ chối *sau khi*
đã nhận tiền của người mua; và nó buộc phải thiết kế một loại phiên thanh toán thứ ba chỉ để thu
phí của người bán.

*Phương án đã cân nhắc.* Một là giữ nguyên bước phê duyệt. Hai là bỏ bước phê duyệt và cho đơn
hàng ra đời ngay khi phiên thanh toán hoàn tất, do chính lời gọi lại từ cổng thanh toán tạo ra.

*Quyết định.* Chọn phương án hai. Mọi bài đăng đều mua được ngay từ trang của nó: người mua chốt
một đơn nháp đã đóng băng giá người bán đưa ra, trả tiền hàng cộng phí vận chuyển đã báo giá, và
đơn hàng cùng chặng vận chuyển ra đời ngay khi phiên thanh toán ấy hoàn tất. Chế độ giá thương
lượng *thêm* một đường đi chứ không thay thế đường cũ: người mua vẫn có thể mở một thương lượng,
hai bên đổi điều khoản, và việc đồng ý sẽ đóng băng điều khoản cho đúng quy trình thanh toán ấy.
Người mua luôn trả phí vận chuyển, nên người bán không bao giờ bị thu tiền và không cần loại
phiên thanh toán thứ ba.

Cần phân biệt rõ hai bước dễ bị nhầm là một. Bước *đã bị loại bỏ* là việc người bán duyệt trước
khi đơn hàng tồn tại: trong phương án một, người mua gửi yêu cầu mua rồi chờ, chưa có gì được
giữ và chưa có gì được ghi nhận cho tới khi người bán đồng ý. Bước *vẫn còn* là việc người bán
xác nhận sau khi đơn hàng đã tồn tại và tiền đã nằm trong tài khoản tạm giữ: đơn ra đời ở trạng
thái chờ xác nhận, người bán có bốn mươi tám giờ để chấp nhận, và việc chấp nhận ấy chỉ mở khoá
cho bước đặt vận đơn chứ không quyết định đơn hàng có tồn tại hay không. Người bán cũng có thể
từ chối kèm lý do, và khi ấy đơn bị huỷ với tiền trả lại nguyên vẹn cho người mua. Nếu hết hạn
mà không có phản hồi, hệ thống không tự huỷ đơn và cũng không tự gửi hàng thay người bán; nó
chuyển việc cho bộ phận vận hành đi giục.

Sự phân biệt này chính là điều làm cho quyết định trên an toàn. Người bán vẫn giữ được quyền
không bán, còn người mua thì không bao giờ rơi vào cảnh đã trả tiền cho một đơn hàng không tồn
tại trong hệ thống.

*Hệ quả.* Tích cực: không tồn tại trạng thái "đã thu tiền nhưng chưa có đơn"; và vì đơn hàng do
lời gọi lại tạo ra, một lời gọi lại bị giao hai lần không thể sinh ra hai đơn — ràng buộc duy
nhất trên nguồn gốc của đơn hàng chặn điều đó ở tầng cơ sở dữ liệu. Tiêu cực: tiền của người mua
bị giữ trong suốt cửa sổ xác nhận kể cả khi người bán rốt cuộc từ chối, nên phải có đường hoàn
tiền mạnh hơn để bù lại, và điều đó làm tăng độ phức tạp của miền hoàn tiền. Ngoài ra một đơn
hàng bị bỏ mặc sẽ đọng lại chờ bộ phận vận hành thay vì tự đóng, tức là chuyển một phần chi phí
sang con người. Đây là đánh đổi có chủ ý, vì rủi ro của việc giữ tiền người mua trong một đơn
hàng không tồn tại lớn hơn nhiều.

== Sơ đồ thành phần và ma trận trách nhiệm

=== Phân rã bên trong một dịch vụ

Bảy dịch vụ có *cùng một hình dạng*, và sự lặp lại này là một quyết định thiết kế chứ không phải
sự trùng hợp: với nhóm ba người, việc một người mở mã của dịch vụ mình chưa từng làm và biết ngay
mọi thứ nằm ở đâu có giá trị lớn hơn việc tối ưu từng dịch vụ theo đặc thù riêng. Mỗi dịch vụ là
một *lục giác thực dụng* gồm năm thành phần cố định và hai thành phần tuỳ chọn.

#fig(
  [Phân rã thành phần bên trong một dịch vụ điển hình],
  spacing: (34mm, 13mm),
  np((0, 0), [Bộ xử lý tuyến\ (thuộc cổng vào)]),
  edge((0, 0), (1, 0), "-|>", text(size: 7.5pt)[gọi]),
  ncore((1, 0), [*Hợp đồng công bố*\ giao diện dịch vụ + DTO\ chỉ phụ thuộc thư viện chuẩn]),
  edge((2, 0), (1, 0), "-|>", stroke: (dash: "dashed"), text(size: 7.5pt)[dịch vụ khác\ phụ thuộc vào đây]),
  np((2, 0), [Dịch vụ miền khác]),
  edge((1, 0), (1, 1), "-|>", text(size: 7.5pt)[hiện thực]),
  np((1, 1), [*Dịch vụ nghiệp vụ*\ điều phối miền và kho dữ liệu\ nơi duy nhất biết cả hai]),
  edge((1, 1), (0, 1.6), "-|>", text(size: 7.5pt)[dùng]),
  np((0, 1.6), [*Miền*\ thực thể · bất biến\ toàn bộ lỗi của dịch vụ]),
  edge((1, 1), (2, 1.6), "-|>", text(size: 7.5pt)[dùng]),
  np((2, 1.6), [*Cổng kho dữ liệu*\ giao diện mà bộ điều hợp\ phải thoả mãn]),
  edge((2, 1.6), (2, 2.6), "-|>", stroke: (dash: "dashed"), text(size: 7.5pt)[hiện thực]),
  np((2, 2.6), [*Bộ điều hợp PostgreSQL*\ pgx · SQL viết tay\ tham số đặt tên]),
  edge((2, 2.6), (2, 3.6), "-|>", text(size: 7.5pt)[SQL không ghi tên lược đồ]),
  ng((2, 3.6), [Lược đồ riêng của dịch vụ]),
  nr((0, 2.6), text(size: 7.5pt)[Thành phần tuỳ chọn:\ luồng bền (`order`, `trust`)\ bộ nhận sự kiện\ tệp migration nhúng sẵn]),
  edge((1, 1), (0, 2.6), stroke: (dash: "dashed")),
)

Chiều phụ thuộc là *một chiều và không có ngoại lệ*: bộ điều hợp phụ thuộc cổng dữ liệu, cổng dữ
liệu phụ thuộc miền, miền không phụ thuộc gì ngoài thư viện chuẩn và hai gói tiện ích dùng chung.
Miền *không bao giờ* biết tới trình điều khiển cơ sở dữ liệu, giao thức HTTP hay khung nền ghép
nối phụ thuộc — đó chính là điều cho phép kiểm thử quy tắc nghiệp vụ mà không cần cơ sở dữ liệu,
và là cách NFR-31 được đáp ứng ở phần lớn bộ kiểm thử.

=== Danh mục thành phần

#figure(
  caption: [Danh mục các thành phần kiến trúc, trách nhiệm và phụ thuộc],
  table(
    columns: (1.25fr, 0.75fr, 2.15fr, 1.35fr),
    align: (left + horizon, center + horizon, left + horizon, left + horizon),
    table.header([Thành phần], [Tầng], [Trách nhiệm], [Phụ thuộc]),

    [Bộ định tuyến], [Cổng vào], [Đăng ký từng tuyến bằng tay; một kiểm thử đối chiếu bảo đảm mọi đường dẫn trong đặc tả đều có tuyến thật.], [Toàn bộ bộ xử lý tuyến],
    [Lớp xác thực phiên], [Cổng vào], [Giải mã thẻ, tra bản ghi phiên ở mọi yêu cầu đã xác thực, đặt định danh người gọi vào ngữ cảnh yêu cầu.], [Kho phiên (Redis)],
    [Lớp CORS], [Cổng vào], [Trả lời yêu cầu tiền kiểm của trình duyệt ở lớp ngoài cùng, trước khi định tuyến.], [Danh sách nguồn cho phép],
    [Lớp nhật ký và mẫu đo], [Cổng vào], [Gắn định danh yêu cầu, ghi nhật ký JSON, phát mẫu đo nhịp và độ trễ.], [Bộ thu mẫu đo],
    [Bộ xử lý tuyến (7 nhóm)], [Cổng vào], [Đọc yêu cầu, điền phần chỉ cổng vào biết (người gọi, phân trang), gọi hợp đồng, ghi kết quả. Không chứa quy tắc nghiệp vụ.], [Hợp đồng của dịch vụ tương ứng],
    [Trạm WebSocket], [Cổng vào], [Giữ kết nối theo tài khoản, giới hạn số kết nối mỗi tài khoản, đẩy sự kiện tới thiết bị.], [Trục phát tán NATS],
    [Bộ phục vụ đối tượng], [Cổng vào], [Nhận và trả tệp cho kho lưu trữ cục bộ; uỷ quyền bằng chữ ký trên URL chứ không bằng thẻ.], [Kho đối tượng],

    [Hợp đồng công bố (7)], [Nghiệp vụ], [Giao diện dịch vụ và đối tượng truyền dữ liệu kèm nhãn kiểm tra hợp lệ; là thứ duy nhất dịch vụ khác được phép biết.], [(không)],
    [Dịch vụ nghiệp vụ (7)], [Nghiệp vụ], [Điều phối miền và kho dữ liệu; kiểm tra vai trò người gọi; phát sự kiện; gửi lượt chạy tới bộ thực thi bền.], [Miền, cổng dữ liệu, hợp đồng của dịch vụ khác],
    [Miền (7)], [Nghiệp vụ], [Thực thể, bất biến, chuyển trạng thái hợp lệ và toàn bộ lỗi có mã của dịch vụ.], [(chỉ thư viện chuẩn)],
    [Luồng bền], [Nghiệp vụ], [Giữ bốn loại hẹn giờ của miền đơn hàng; gọi lại phương thức lũy đẳng khi đến hạn. Miền uy tín không khai báo luồng bền theo từng thực thể mà chỉ đăng ký một vòng quét định kỳ.], [Bộ thực thi bền],
    [Bộ nhận sự kiện], [Nghiệp vụ], [Đăng ký nhóm tiêu thụ trên trục sự kiện miền và chuyển thành lời gọi dịch vụ.], [Trục sự kiện],

    [Cổng kho dữ liệu (7)], [Truy cập dữ liệu], [Giao diện mô tả những gì miền cần đọc và ghi, do miền định nghĩa chứ không do cơ sở dữ liệu.], [Miền],
    [Bộ điều hợp PostgreSQL (7)], [Truy cập dữ liệu], [Câu lệnh SQL viết tay với tham số đặt tên; ghi có điều kiện bảo vệ; ghi nhật ký kiểm toán cùng giao dịch.], [Nhóm kết nối pgx],
    [Kho tài nguyên và tuỳ chọn dùng chung], [Truy cập dữ liệu], [Ba bảng dùng chung, dựng trên nhóm kết nối của chính dịch vụ gọi.], [Nhóm kết nối pgx],

    [Bộ ghép nối phụ thuộc], [Hạ tầng], [Dựng đồ thị thành phần theo kiểu giao diện; đăng ký vòng đời đóng mở tài nguyên.], [Mọi thành phần],
    [Sổ đăng ký nhà cung cấp], [Hạ tầng], [Phân giải một hiện thực theo tên mà hàng dữ liệu ghi lại; từ chối tên không ai đăng ký.], [Các gói tích hợp],
    [Bộ quét định kỳ], [Hạ tầng], [Gọi các phương thức lũy đẳng theo chu kỳ, làm mạng lưới dự phòng cho bộ thực thi bền.], [Dịch vụ nghiệp vụ],
    [Bộ thu mẫu đo], [Hạ tầng], [Đóng dấu định danh bản sao, phát mẫu theo lối nỗ lực tốt nhất, đếm mẫu bị rơi.], [Trục NATS],
    [Bộ sinh vector nhúng], [Hạ tầng], [Chương trình riêng, rút cạn dấu "đã cũ" trên ba bảng có chỉ mục; không chạy trong tiến trình phục vụ yêu cầu.], [Mô hình nhúng, miền danh mục],
    [Bộ áp migration], [Hạ tầng], [Chương trình riêng; tạo lược đồ, áp phần dùng chung rồi áp phần riêng của từng dịch vụ.], [Tệp migration nhúng sẵn],
  )
)

=== Đồ thị phụ thuộc giữa các dịch vụ

#fig(
  [Đồ thị phụ thuộc giữa các dịch vụ: nét liền là gọi theo hợp đồng, nét đứt là sự kiện],
  spacing: (30mm, 15mm),
  np((1, 0), [`order`]),
  np((0, 1), [`catalog`]),
  np((1, 1), [`chat`]),
  np((2, 1), [`finance`]),
  np((0, 2), [`trust`]),
  ncore((1, 2), [`account`]),
  np((2, 2), [`observability`]),
  edge((1, 0), (0, 1), "-|>"),
  edge((1, 0), (1, 1), "-|>"),
  edge((1, 0), (2, 1), "-|>"),
  edge((1, 0), (1, 2), "-|>"),
  edge((0, 1), (1, 2), "-|>"),
  edge((1, 1), (1, 2), "-|>"),
  edge((2, 1), (1, 2), "-|>"),
  edge((0, 2), (1, 2), "-|>"),
  edge((0, 2), (0, 1), "-|>"),
  edge((0, 2), (1, 1), "-|>"),
  edge((0, 2), (1, 0), "-|>"),
  edge((2, 1), (1, 0), "-|>", stroke: (dash: "dashed"), bend: 25deg, text(size: 7pt)[phiên đã trả / đã huỷ]),
  edge((1, 0), (0, 2), "-|>", stroke: (dash: "dashed"), bend: 25deg, text(size: 7pt)[đơn đã tất toán,\ phán quyết hoàn tiền]),
  edge((1, 0), (2, 2), "-|>", stroke: (dash: "dashed"), text(size: 7pt)[bản sao sự kiện]),
)

Đồ thị không có chu trình ở tầng gọi theo hợp đồng, và đây là điều kiện để chiều phụ thuộc kiểm
tra được lúc biên dịch. Hai cặp quan hệ *trông giống* chu trình nhưng không phải: miền đơn hàng
phụ thuộc hợp đồng của miền tài chính để mở phiên thanh toán, còn miền tài chính báo lại kết quả
bằng *sự kiện*, không bằng lời gọi ngược; tương tự, miền uy tín phụ thuộc hợp đồng của miền đơn
hàng để đọc dữ liệu đơn, còn miền đơn hàng thông báo cho nó bằng sự kiện. Việc chọn sự kiện cho
chiều ngược lại không phải để tránh chu trình một cách hình thức, mà vì chiều ấy đúng là một *sự
việc đã xảy ra*: miền tài chính không ra lệnh cho miền đơn hàng tạo đơn, nó chỉ thông báo rằng
tiền đã về.

=== Ma trận trách nhiệm

#figure(
  caption: [Ma trận trách nhiệm: dịch vụ đối chiếu với nhóm yêu cầu chức năng],
  table(
    columns: (0.95fr, 0.5fr, 0.5fr, 0.6fr, 0.6fr, 0.55fr, 0.6fr, 0.5fr, 0.55fr),
    align: (left + horizon, center + horizon, center + horizon, center + horizon, center + horizon, center + horizon, center + horizon, center + horizon, center + horizon),
    table.header(
      [Dịch vụ], [Định danh\ & phiên], [Bài đăng\ & tìm kiếm], [Hội thoại\ & giá], [Đơn &\ vận chuyển], [Thanh toán\ & ví], [Hoàn tiền\ & hỗ trợ], [Đánh giá\ & uy tín], [Quản trị\ & kiểm toán],
    ),
    [`account`], [C], [], [], [], [], [H], [], [C],
    [`catalog`], [], [C], [], [H], [], [], [H], [C],
    [`chat`], [], [], [C], [], [], [H], [], [H],
    [`order`], [], [H], [C], [C], [H], [C], [H], [C],
    [`finance`], [], [], [], [H], [C], [H], [], [C],
    [`trust`], [], [H], [], [], [], [C], [C], [C],
    [`observability`], [], [], [], [], [], [], [], [H],
    [Cổng vào], [H], [H], [H], [H], [H], [H], [H], [H],
  )
)

#note[*Ký hiệu.* `C` — chịu trách nhiệm chính, sở hữu dữ liệu và quy tắc của nhóm yêu cầu đó. `H` — vai trò hỗ trợ, đóng góp dữ liệu hoặc một bước trong luồng nhưng không sở hữu quyết định. Ô trống nghĩa là dịch vụ không tham gia. Mỗi nhóm yêu cầu có đúng một hoặc hai dịch vụ giữ vai trò chính, nên không có nhóm nào bị bỏ rơi và cũng không có nhóm nào do cả bảy dịch vụ cùng quyết định. Phân bổ tải yêu cầu giữa các dịch vụ vẫn lệch: miền đơn hàng giữ vai trò chính ở gần ba mươi phần trăm tổng số yêu cầu, cao hơn hẳn phần còn lại. Đây là hệ quả trực tiếp của việc luồng tiền và luồng giao nhận đều hội tụ về đó, và là ứng viên đầu tiên để tách nhỏ nếu miền này tiếp tục phình ra.]

#figure(
  caption: [Ánh xạ yêu cầu chức năng tới dịch vụ chủ quản],
  table(
    columns: (0.75fr, 1.85fr, 2.6fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Dịch vụ], [Yêu cầu chức năng], [Ghi chú về phạm vi]),
    [`account`], [REQ-01…08, REQ-42, REQ-50], [Định danh, phiên, phân quyền, địa chỉ liên hệ, thiết bị, thông báo, hồ sơ xác minh danh tính và cấp phát tài khoản kiểm duyệt viên.],
    [`catalog`], [REQ-09…17, REQ-47], [Bài đăng, biến thể, danh mục, tồn kho, tìm kiếm và gợi ý, hàng đợi kiểm duyệt bài đăng.],
    [`chat`], [REQ-18, REQ-37], [Hội thoại một luồng cho mỗi cặp tài khoản, tin nhắn, luồng trao đổi của phiếu hỗ trợ với nhân viên ẩn danh.],
    [`order`], [REQ-19…24, REQ-26…36, REQ-43, REQ-48], [Đơn nháp, thương lượng giá, báo giá vận chuyển, đơn hàng, chặng vận chuyển, hồ sơ hoàn tiền, các hẹn giờ dài.],
    [`finance`], [REQ-25, REQ-26, REQ-32, REQ-40, REQ-41, REQ-43, REQ-49], [Phiên thanh toán, sổ cái, giữ và giải phóng tiền tạm giữ, ví, rút tiền, đối soát.],
    [`trust`], [REQ-29, REQ-36…39], [Đánh giá giao dịch hai chiều mù, nhận xét sản phẩm, điểm uy tín, phiếu hỗ trợ cho mọi loại khiếu nại.],
    [`observability`], [REQ-46], [Bốn tín hiệu vận hành thu thập theo cách không chặn và không làm hỏng yêu cầu đang phục vụ; đây cũng là hệ đo dùng để nghiệm thu các yêu cầu phi chức năng.],
    [Dùng chung], [REQ-05, REQ-44, REQ-45], [Kiểm tra vai trò ở tầng dịch vụ, đường tải tệp có chữ ký, và nhật ký kiểm toán bất biến hiện diện trong mọi lược đồ.],
  )
)

Ba thành phần được đánh dấu là *phức tạp cao* và cần chú ý đặc biệt ở bước thiết kế chi tiết. Miền
đơn hàng lớn nhất về khối lượng mã và ôm nhiều yêu cầu nhất, vì nó là nơi hội tụ của thương lượng
giá, thanh toán, vận chuyển và hoàn tiền; nó cũng là dịch vụ duy nhất phụ thuộc bốn dịch vụ khác.
Miền tài chính tuy nhỏ hơn nhưng có mật độ bất biến cao nhất, vì mọi sai sót ở đây đều là sai lệch
tiền. Lớp xác thực phiên ở cổng vào tuy chỉ là một thành phần cắt ngang nhưng nằm trên đường đi của
mọi yêu cầu đã xác thực, nên vừa là điểm chịu tải nặng nhất vừa là điểm mà một lỗi phân quyền sẽ
lan ra toàn hệ thống.

== Thiết kế giao diện lập trình ứng dụng

=== Nguyên tắc, phiên bản và xác thực

Giao diện lập trình của ShopNexus là một giao diện *REST trên HTTPS với thân JSON mã hoá UTF-8*,
gồm *135 đường dẫn, 171 thao tác và 235 lược đồ dữ liệu*, hợp nhất từ 36 mảnh đặc tả đặt rải trong
bảy dịch vụ; 27 đường dẫn trong số đó thuộc bề mặt quản trị và kiểm duyệt. Con số này cho thấy mức
độ mở rộng phạm vi so với 24 đường dẫn phác thảo ở giai đoạn phân tích ban đầu — bản phác thảo ấy
đã lỗi thời hoàn toàn và không còn được dùng làm tham chiếu. Đây
là *hợp đồng công khai duy nhất* của hệ thống: cả ba giao diện khách — web, ứng dụng di động và
bảng điều khiển quản trị — đều gọi cùng tập đường dẫn này, và mã máy khách của cả web lẫn di động
đều được *sinh tự động* từ đặc tả chứ không viết tay (AD-09).

Phiên bản được đặt trong đường dẫn: mọi tuyến nằm dưới tiền tố `/api/v1`, kể cả các tuyến nhận
lời gọi lại từ nhà cung cấp. Việc đặt lời gọi lại *cùng* dưới tiền tố phiên bản là có chủ ý — một
đường dẫn đứng cạnh tiền tố là một đường dẫn nữa mà mọi máy chủ uỷ nhiệm phía trước phải được cấu
hình riêng, và máy chủ đứng trước nền tảng này thì không. Một kiểm thử đối chiếu bảo đảm tiền tố
khai báo trong đặc tả và tiền tố mà bộ định tuyến gắn kết luôn khớp nhau.

Xác thực dùng thẻ mang theo trong tiêu đề `Authorization: Bearer <thẻ>`. Thẻ là JWT sống 15 phút,
mang định danh tài khoản và định danh phiên; bản thân *phiên* mới là nguồn sự thật và được tra ở
mọi yêu cầu đã xác thực, nên đăng xuất, đổi mật khẩu hoặc khoá tài khoản có hiệu lực ngay với thẻ
còn hạn. Thẻ làm mới là một khoá thứ hai trỏ tới cùng phiên và được luân chuyển mỗi lần đổi. Việc
kiểm tra *vai trò* không nằm ở tầng cổng vào mà ở tầng dịch vụ, vì vai trò là một cột trong bảng
tài khoản: một bộ xử lý tuyến muốn biết vai trò thì cũng phải hỏi chính dịch vụ ấy. Nhờ vậy các
tuyến quản trị mỏng đúng như mọi tuyến khác.

Mọi định danh trên đường truyền đều ở dạng *mờ* theo ADR-05, ví dụ `lst_2h9qk4mfx7bd3`, với tiền
tố cho biết loại thực thể. Một định danh gửi sai loại bị từ chối ngay ở khâu phân giải thay vì
trỏ nhầm vào một bản ghi khác.

=== Phong bì phản hồi và phân trang

Mọi thân phản hồi JSON đều có *đúng một* trong hai khoá gốc `data` và `error`, không bao giờ có cả
hai, kèm khoá `meta` bên cạnh `data` cho các phản hồi có phân trang. Lý do không trả dữ liệu trần
ở gốc là để tránh nhập nhằng giữa trường của phong bì và trường của chính dữ liệu — và điều này
không phải giả định: một giao dịch có trường `error` ghi thông báo lỗi từ cổng thanh toán, nên
một phản hồi thành công và một lỗi cổng vào sẽ có cùng hình dạng đối với mẫu kiểm tra phổ biến
nhất ở phía máy khách. Một tầng lồng khiến va chạm ấy trở thành không thể thay vì chỉ khó xảy ra.

Một nguyên tắc quan trọng khác: *đối tượng truyền dữ liệu luôn gửi giá trị rỗng của nó, không bao
giờ bỏ khoá đi*. Một danh sách rỗng là `[]`, một đối tượng rỗng là `{}`, một số chưa đặt là `0`,
một con trỏ vắng là `null`. Nguyên tắc này được cưỡng chế bằng một kiểm thử duyệt cây cú pháp của
các gói hợp đồng và báo lỗi kèm đúng tên trường vi phạm. Nó tồn tại vì một sự cố thật: một trường
tham chiếu bị bỏ qua khi rỗng đã biến mất khỏi gần như mọi tin nhắn, và mã máy khách sinh từ đặc
tả — vốn khai báo trường ấy là bắt buộc nên không chấp nhận giá trị vắng — đã không giải mã được
bất kỳ luồng hội thoại nào.

Có hai kiểu phân trang, và việc dùng kiểu nào là hệ quả của bản chất tập dữ liệu chứ không phải
sở thích. *Trang kèm giới hạn* dùng cho những tập được duyệt và cần tổng số, và là lựa chọn duy
nhất cho kết quả có xếp hạng, vì khoá sắp xếp của một truy vấn ngữ nghĩa là điểm số tính theo
từng lần hỏi chứ không phải một cột đã lưu, nên không có gì để định vị tiếp. *Con trỏ kèm giới
hạn* dùng cho các dòng chỉ nối thêm ở đầu như tin nhắn, thông báo, đơn hàng, đề nghị giá và giao
dịch; chỉ mục của chúng đều có dạng khoá chủ sở hữu kèm thời điểm giảm dần, nên phép định vị là
chính xác và không bị trôi khi có bản ghi mới chen vào giữa lúc đang lật trang.

#figure(
  caption: [Chuẩn mã lỗi và ý nghĩa],
  table(
    columns: (0.5fr, 1.35fr, 3.1fr),
    align: (center + horizon, left + horizon, left + horizon),
    table.header([Mã HTTP], [Mã lỗi ứng dụng], [Tình huống]),
    [200 / 201], [—], [Thành công; thân phản hồi mang khoá `data`.],
    [204], [—], [Thành công nhưng không có gì để trả về; cố ý *không* trả phong bì rỗng, để máy khách không bị mời đọc một giá trị không tồn tại.],
    [400], [`validation`], [Vi phạm ràng buộc dữ liệu đầu vào; thân lỗi kèm danh sách trường vi phạm.],
    [400], [`bad_request_body`], [Thân JSON sai cú pháp hoặc chứa khoá không được khai báo.],
    [400], [`invalid_id`], [Định danh mờ không giải mã được hoặc sai tiền tố loại thực thể.],
    [401], [`unauthorized`], [Thiếu thẻ xác thực.],
    [401], [`invalid_token`], [Thẻ sai chữ ký, hết hạn, hoặc phiên tương ứng đã bị thu hồi.],
    [403], [(theo miền)], [Đã xác thực nhưng không phải chủ sở hữu tài nguyên hoặc không đủ vai trò.],
    [404], [(theo miền)], [Tài nguyên không tồn tại, hoặc người gọi không được phép biết nó tồn tại.],
    [409], [(theo miền)], [Xung đột trạng thái: bản ghi đã bị thay đổi bởi một thao tác khác, hoặc chuyển trạng thái không hợp lệ.],
    [422], [(theo miền)], [Yêu cầu đúng cú pháp nhưng bị một quy tắc nghiệp vụ từ chối.],
    [500], [`internal`], [Lỗi không có mã — được ghi nhật ký đầy đủ ở phía máy chủ, còn máy khách chỉ nhận định danh yêu cầu.],
    [501], [`not_implemented`], [Tuyến đã khai báo trong đặc tả nhưng chưa hiện thực; cố ý là một mã rõ ràng thay vì một giá trị rỗng có vẻ hợp lệ.],
  )
)

Mọi thân lỗi có cùng một hình dạng gồm mã lỗi ổn định, thông điệp, *định danh yêu cầu* và danh
sách trường vi phạm. Định danh yêu cầu cũng được đặt trong tiêu đề phản hồi ở *mọi* phản hồi, kể
cả 204 và các phản hồi không phải JSON, nên người dùng báo lỗi luôn có một mã để đối chiếu với
nhật ký. Việc ánh xạ lỗi sang mã HTTP tập trung ở đúng một nơi, và lỗi của mỗi miền được khai báo
ngay trong miền ấy chứ không nằm rải trong bộ xử lý tuyến.

=== Đặc tả các endpoint tiêu biểu

Bảng dưới đây trích những đường dẫn tiêu biểu cho từng nhóm nghiệp vụ, đủ để đọc được hình dạng
chung của giao diện; đặc tả đầy đủ 135 đường dẫn nằm trong tài liệu OpenAPI sinh ra từ mã nguồn
và được phục vụ ngay tại `/api/v1/openapi.yaml`.

#figure(
  caption: [Đặc tả các endpoint tiêu biểu của giao diện lập trình ShopNexus],
  table(
    columns: (0.5fr, 1.85fr, 2.25fr, 0.95fr),
    align: (center + horizon, left + horizon, left + horizon, center + horizon),
    table.header([PT], [Đường dẫn], [Mô tả nghiệp vụ], [Quyền]),

    table.cell(colspan: 4, align: left)[*Định danh và phiên*],
    [POST], [`/register`], [Đăng ký tài khoản mới.], [Công khai],
    [POST], [`/login`], [Đăng nhập bằng định danh và mật khẩu; trả thẻ truy cập và thẻ làm mới.], [Công khai],
    [POST], [`/login/oauth`], [Đăng nhập bằng thẻ định danh của nhà cung cấp liên kết.], [Công khai],
    [POST], [`/token/refresh`], [Đổi thẻ làm mới lấy cặp thẻ mới; thẻ cũ bị luân chuyển.], [Công khai],
    [POST], [`/logout`], [Thu hồi phiên hiện tại.], [Người dùng],
    [GET], [`/me`], [Đọc hồ sơ của chính người gọi.], [Người dùng],
    [PATCH], [`/me/profile`], [Cập nhật hồ sơ; trường vắng giữ nguyên, cờ xoá dọn giá trị.], [Chủ sở hữu],
    [POST], [`/identity-documents`], [Nộp hồ sơ xác minh danh tính.], [Người dùng],

    table.cell(colspan: 4, align: left)[*Bài đăng và tìm kiếm*],
    [GET], [`/listings`], [Duyệt và tìm kiếm bài đăng; lọc theo danh mục, giá, tình trạng, vị trí; xếp hạng ngữ nghĩa.], [Công khai],
    [GET], [`/listings/{id}`], [Chi tiết một bài đăng kèm biến thể và tồn kho.], [Công khai],
    [POST], [`/listings`], [Đăng bán; đây là *đường duy nhất* làm một bài đăng ra đời.], [Người dùng],
    [POST], [`/listings/uploads`], [Xin liên kết đã ký để tải ảnh bài đăng lên kho đối tượng.], [Người dùng],
    [POST], [`/listings/suggestions`], [Gợi ý điền biểu mẫu đăng bán từ ảnh và lời mô tả; *không ghi gì*.], [Người dùng],
    [POST], [`/listings/{id}/publication`], [Chuyển bài đăng sang trạng thái hiển thị công khai.], [Chủ sở hữu],
    [POST], [`/admin/listings/{id}/takedown`], [Gỡ bài đăng vi phạm kèm lý do; ghi nhật ký kiểm toán.], [Kiểm duyệt viên],

    table.cell(colspan: 4, align: left)[*Hội thoại và thương lượng giá*],
    [GET], [`/conversations`], [Hộp thư: danh sách hội thoại kèm tin nhắn cuối và số chưa đọc.], [Người dùng],
    [GET], [`/conversations/{id}/messages`], [Lịch sử tin nhắn, phân trang theo con trỏ.], [Bên tham gia],
    [POST], [`/conversations/{id}/messages`], [Gửi tin nhắn văn bản hoặc đính kèm.], [Bên tham gia],
    [POST], [`/offers`], [Mở một thương lượng giá; cả người mua và người bán đều có thể khởi xướng.], [Người dùng],
    [POST], [`/offers/{id}/acceptance`], [Chấp nhận điều khoản đang trên bàn; *đóng băng giá 30 phút, chưa thu tiền*.], [Bên đối diện],
    [POST], [`/offers/{id}/checkout`], [Người mua mở phiên thanh toán từ điều khoản đã đồng ý.], [Người mua],

    table.cell(colspan: 4, align: left)[*Đơn hàng, vận chuyển và hoàn tiền*],
    [POST], [`/shipping-quotes`], [Báo giá vận chuyển của *mọi* hãng đang bật cho một đơn nháp hoặc một thương lượng đã đồng ý.], [Người mua],
    [POST], [`/drafts/{id}/checkout`], [Chốt đơn nháp và mở phiên thanh toán gồm tiền hàng cộng phí vận chuyển.], [Người mua],
    [GET], [`/orders`], [Danh sách đơn theo vai trò người mua hoặc người bán, phân trang theo con trỏ.], [Bên liên quan],
    [POST], [`/orders/{id}/confirmation`], [Người bán xác nhận đơn và khởi tạo chặng vận chuyển.], [Người bán],
    [POST], [`/orders/{id}/receipt`], [Người mua xác nhận đã nhận hàng kèm bằng chứng; khởi động cửa sổ giữ tiền.], [Người mua],
    [POST], [`/orders/{id}/refunds`], [Mở hồ sơ hoàn tiền kèm bằng chứng.], [Người mua],
    [POST], [`/refunds/{id}/acceptance`], [Người bán chấp nhận hoàn tiền; *không có đường từ chối*, chỉ có đường khiếu nại.], [Người bán],
    [POST], [`/admin/refunds/{id}/verdict`], [Phán quyết hồ sơ hoàn tiền đang khiếu nại; đồng thời đóng mọi phiếu hỗ trợ liên quan.], [Kiểm duyệt viên],

    table.cell(colspan: 4, align: left)[*Thanh toán và ví*],
    [POST], [`/payment-sessions/{id}/payments`], [Khởi tạo một lượt trả tiền trên một đường tiền cụ thể.], [Người trả tiền],
    [POST], [`/payment-sessions/{id}/cancellation`], [Huỷ phiên chưa trả; giải phóng các dòng hàng đã giữ.], [Người trả tiền],
    [GET], [`/wallets`], [Số dư khả dụng và số dư tạm giữ theo từng loại tiền.], [Chủ sở hữu],
    [GET], [`/wallets/{currency}/transactions`], [Lịch sử biến động ví, phân trang theo con trỏ.], [Chủ sở hữu],
    [POST], [`/withdrawals`], [Yêu cầu rút số dư khả dụng về tài khoản ngân hàng đã đăng ký.], [Người dùng],
    [POST], [`/admin/withdrawals/{id}/approval`], [Duyệt lệnh rút tiền.], [Quản trị viên],

    table.cell(colspan: 4, align: left)[*Uy tín và hỗ trợ*],
    [POST], [`/orders/{orderID}/feedback`], [Gửi đánh giá giao dịch; *mù hai chiều*, chiều đánh giá suy ra từ vai trò người gọi.], [Bên liên quan],
    [GET], [`/accounts/{accountID}/reputation`], [Điểm uy tín; tài khoản chưa ai đánh giá trả về *số không*, không phải lỗi không tìm thấy.], [Công khai],
    [POST], [`/listings/{listingID}/reviews`], [Viết nhận xét sản phẩm sau khi giao dịch hoàn tất.], [Người mua],
    [POST], [`/tickets`], [Mở phiếu hỗ trợ cho mọi loại việc: báo cáo vi phạm, khiếu nại hoàn tiền, sự cố đơn hàng, đề xuất tính năng.], [Người dùng],
    [POST], [`/admin/tickets/{id}/claim`], [Nhân viên nhận xử lý một phiếu.], [Kiểm duyệt viên],

    table.cell(colspan: 4, align: left)[*Dùng chung và thời gian thực*],
    [GET], [`/options`], [Danh sách lựa chọn của một hạng mục (đường tiền, hãng vận chuyển) mà bản dựng hiện tại phục vụ được.], [Theo hạng mục],
    [PATCH], [`/admin/options/{id}`], [Đổi nhà cung cấp phục vụ một lựa chọn; giữ nguyên tên định danh và mọi bản ghi trỏ tới nó.], [Quản trị viên],
    [POST], [`/ws/tickets`], [Xin vé một lần để mở kênh thời gian thực.], [Người dùng],
  )
)

=== Kênh thời gian thực

Bên cạnh giao diện yêu cầu–phản hồi, hệ thống có một kênh đẩy hai chiều phục vụ AD-05, được đặc
tả riêng bằng AsyncAPI với một kênh duy nhất mang tám loại thông điệp. Kênh này không dùng thẻ
truy cập trong tiêu đề, vì trình duyệt không cho đặt tiêu đề tuỳ ý khi mở kết nối; thay vào đó
máy khách xin một *vé dùng một lần* có thời hạn ngắn rồi mở kết nối với vé ấy.

#figure(
  caption: [Các loại thông điệp trên kênh thời gian thực],
  table(
    columns: (1.35fr, 1fr, 2.4fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Thông điệp], [Miền phát], [Tác dụng ở phía máy khách]),
    [Tin nhắn mới], [`chat`], [Chèn tin nhắn vào luồng đang mở và cập nhật hộp thư.],
    [Tin nhắn được sửa], [`chat`], [Cập nhật nội dung tin nhắn đã hiển thị.],
    [Tin nhắn bị thu hồi], [`chat`], [Thay nội dung bằng dấu đã thu hồi, giữ vị trí trong luồng.],
    [Hội thoại đã đọc], [`chat`], [Đồng bộ dấu đã đọc giữa các thiết bị của cùng một người.],
    [Thông báo mới], [`account`], [Tăng huy hiệu chưa đọc và hiển thị thông báo đẩy.],
    [Đề nghị giá thay đổi], [`order`], [Cập nhật điều khoản đang trên bàn trong luồng thương lượng.],
    [Đơn hàng được tạo], [`order`], [Hiện đơn mới trong danh sách của cả hai bên.],
    [Đơn hàng đã tất toán], [`order`], [Cập nhật trạng thái và mở đường gửi đánh giá.],
  )
)

=== Đặc tả là một tài sản, không phải tài liệu viết sau

Đặc tả OpenAPI của hệ thống không được viết tay thành một tệp lớn. Nó được *soạn theo mảnh*, mỗi
tổng thể nghiệp vụ một tệp nằm ngay trong dịch vụ sở hữu nó, rồi hợp nhất thành một tài liệu duy
nhất bằng một chương trình sinh mã. Cách tổ chức này có ba hệ quả thực dụng. Thứ nhất, khoá của
đường dẫn và của lược đồ nằm trong *một* không gian tên phẳng chung, nên hai dịch vụ vô tình đặt
trùng tên sẽ làm việc hợp nhất thất bại thay vì âm thầm ghi đè lên nhau. Thứ hai, quy trình tích
hợp liên tục chạy lại việc hợp nhất và so sánh với tệp đã lưu trong kho mã, nên đặc tả không thể
lệch khỏi mã nguồn. Thứ ba, ba kiểm thử đối chiếu bảo đảm mọi tham chiếu trong đặc tả phân giải
được, không có khoá thừa, và *mọi đường dẫn khai báo trong đặc tả đều có một tuyến thật* — đây là
lý do bộ định tuyến được viết tay thay vì sinh ra từ đặc tả, vì một bộ định tuyến sinh tự động sẽ
thoả mãn kiểm thử ấy theo cách xây dựng và mất khả năng phát hiện một tuyến đã công bố mà chưa ai
nối dây.

Vì đặc tả đầy đủ đến mức ấy, nó cũng *chính là* bộ giả lập: toàn bộ hợp đồng được phục vụ bởi một
máy chủ giả lập không cần cơ sở dữ liệu, kiểm tra hợp lệ thân yêu cầu và cả yêu cầu về thẻ xác
thực, nên một máy khách có thể được viết xong trước khi bộ xử lý tuyến tương ứng tồn tại. Điều
này đặt ra một yêu cầu ngược lại lên chất lượng đặc tả: một trường số không khai báo cận sẽ được
bộ giả lập trả về bằng một giá trị vô nghĩa, nên mỗi trường số đều mang cận trên và cận dưới đúng
bằng ràng buộc mà dịch vụ thực sự cưỡng chế, và mỗi trường mà máy khách hiển thị đều có ví dụ.

#anh-cho(
  [Giao diện tài liệu tương tác của đặc tả OpenAPI phục vụ tại `/api/v1/docs`],
  [Chụp trang Swagger UI đang mở tại `/api/v1/docs`, đã bung một nhóm thẻ (ví dụ `order`) để thấy danh sách thao tác, và mở rộng một thao tác kèm phần lược đồ phản hồi.],
)
