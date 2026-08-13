#import "../../common/tokens.typ": *

== Các yếu tố dẫn dắt kiến trúc

Không phải yêu cầu nào cũng có ý nghĩa kiến trúc: phần lớn trong số các yêu cầu chức năng ở Chương 3 đều hiện thực được bằng một biểu mẫu, một câu truy vấn và một màn hình. Mục này tách ra nhóm nhỏ các
yêu cầu thực sự định hình cấu trúc hệ thống. Đặc thù của một sàn giao dịch giữa người dùng với người dùng là tiền của người mua không đi thẳng tới người bán: nền tảng đứng giữa và phải trả lời được câu hỏi "tiền đang ở đâu" tại mọi thời điểm. Mỗi yếu tố dẫn dắt được đánh mã `AD-01` … `AD-09`, và mọi quyết định ở các mục
sau đều truy ngược về ít nhất một mã trong số đó.

#figure(
  caption: [Các yêu cầu chức năng có ý nghĩa kiến trúc (Architecturally Significant Requirements)],
  table(
    columns: (0.5fr, 1.5fr, 0.95fr, 2.5fr),
    align: (center + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Mã], [Yêu cầu dẫn dắt], [Nguồn], [Ý nghĩa kiến trúc]),

    [AD-01], [Giữ tiền ký quỹ và giải ngân theo phán quyết], [REQ-26, REQ-32, REQ-36],
    [Giao dịch tài chính đòi hỏi tính nguyên tử trên sổ cái nhưng lại bị kích hoạt từ 3 miền rời rạc (đơn hàng, thanh toán, khiếu nại). Điều này buộc kiến trúc phải cô lập toàn bộ nghiệp vụ tiền tệ vào một dịch vụ duy nhất và tước quyền ghi sổ cái của mọi dịch vụ khác.],

    [AD-02], [Các chuyển trạng thái theo thời hạn], [REQ-21, REQ-24, REQ-29, REQ-32, REQ-35],
    [5 loại hẹn giờ dài (hết hạn thanh toán, xác nhận đơn, hoàn tiền) có vòng đời từ vài chục phút đến nhiều ngày. Quãng thời gian này vượt quá giới hạn an toàn của bộ nhớ tiến trình, đòi hỏi một cơ chế thực thi bền (durable execution) để máy trạng thái không bị mất dữ liệu khi tái khởi động.],

    [AD-03], [Tích hợp nhiều nhà cung cấp cùng loại], [REQ-23, REQ-25, REQ-43, NFR-15],
    [Dịch vụ thanh toán và vận chuyển vận hành qua nhiều đối tác; mỗi bản ghi giao dịch phải lưu vết cố định đối tác cung cấp dịch vụ. Kiến trúc phải thiết lập cơ chế sổ đăng ký (registry) để duy trì hoạt động song song của nhiều đối tác tại thời điểm chạy, thay vì định tuyến tĩnh ở cấp độ cấu hình.],

    [AD-04], [Tìm kiếm bằng ngôn ngữ tự nhiên trên dữ liệu do người dùng tự đặt tên], [REQ-14, REQ-15, REQ-16],
    [Dữ liệu đăng bán cá nhân thiếu chuẩn mực từ vựng, làm suy giảm hiệu quả của đối sánh toàn văn (full-text). Bắt buộc tích hợp chỉ mục vector kề sát dữ liệu quan hệ để thực thi truy vấn lai (hybrid search), đồng thời tách biệt tiến trình sinh vector sang một luồng phi đồng bộ.],

    [AD-05], [Truyền tin và thông báo thời gian thực], [REQ-18],
    [Trạng thái hội thoại và biến động đơn hàng phải đến thiết bị đích dưới một giây. Đòi hỏi duy trì kênh kết nối liên tục hai chiều (WebSocket) kết hợp cơ chế phát tán thông điệp (pub/sub), nhằm đồng bộ trạng thái trên mọi thiết bị đang mở của cùng một người dùng.],

    [AD-06], [Bằng chứng đa phương tiện bắt buộc], [REQ-31, REQ-33, REQ-44],
    [Tệp phương tiện (video mở hộp, ảnh minh chứng) có dung lượng vượt quá khả năng xử lý của thân yêu cầu JSON. Buộc tách rời hoàn toàn đường tải tệp khỏi luồng nghiệp vụ API, và giao quyền quản lý vòng đời tài nguyên cho từng miền sở hữu.],

    [AD-07], [Một cửa tiếp nhận cho mọi khiếu nại], [REQ-34, REQ-36, REQ-37],
    [Báo cáo vi phạm, hồ sơ hoàn tiền và yêu cầu hỗ trợ có chung bản chất: một bên gửi yêu cầu và một bên phân xử. Điều này định hướng việc gộp chúng thành một vòng đời phiếu (ticket) duy nhất, có tích hợp cơ chế ẩn danh nhằm bảo vệ điều phối viên.],

    [AD-08], [Nhật ký kiểm toán bất biến], [REQ-45, NFR-19],
    [Mọi thay đổi mang hệ quả tài chính hoặc hành chính bắt buộc để lại lưu vết bất biến. Nhật ký kiểm toán phải là một phần cốt lõi nằm chung giao dịch cơ sở dữ liệu với thao tác nghiệp vụ, không phải là một chức năng ghi ghép thêm ở tầng ứng dụng.],

    [AD-09], [2 giao diện khách trên một hợp đồng], [REQ-01…46, NFR-17],
    [Hai nền tảng máy khách (Web, Mobile) cùng chia sẻ một tập giao diện lập trình. Bản đặc tả API phải trở thành tài sản trung tâm (API-First), được dùng để sinh mã máy khách và máy chủ giả lập, thay vì chỉ là tài liệu mô tả hậu lập trình.],
  )
)


== Kiến trúc tổng thể hệ thống

=== Kiểu kiến trúc và ranh giới triển khai


Hệ thống được tổ chức theo Kiến trúc phân rã theo nhóm nghiệp vụ, chia thành 7 dịch vụ: `account`, `catalog`, `order`, `finance`, `chat`, `trust` và `observability`. Ranh giới giữa các dịch vụ này được cưỡng chế bằng cơ chế kỹ thuật thay vì chỉ là quy ước lỏng lẻo trên mã nguồn, thể hiện qua 3 nguyên tắc cốt lõi:

- *Sở hữu dữ liệu độc quyền:* Mỗi dịch vụ làm chủ một lược đồ (schema) riêng. Bể kết nối (connection pool) bị ép buộc phải khóa đường dẫn tìm kiếm (search path) vào đúng lược đồ đó, cắt đứt hoàn toàn nguy cơ truy vấn chéo (ADR-01).
- *Giao tiếp qua hợp đồng công bố:* Các dịch vụ chỉ gọi nhau qua tập giao diện (interface) công bố sẵn. Gói hợp đồng này không chứa logic và chỉ phụ thuộc thư viện chuẩn, đảm bảo rằng nếu cần tách một dịch vụ ra máy chủ khác, thao tác duy nhất là thay thế bản hiện thực bằng một máy khách gọi mạng mà bên gọi không phải sửa dòng mã nào.
- *Tương tác bất đồng bộ qua trục sự kiện (Event bus):* Các luồng chạy nền giao tiếp với nhau bằng mạng lưới Pub/Sub. Thông điệp truyền đi luôn mang ý nghĩa "sự việc đã hoàn tất" (domain event), tuyệt đối không mang tính mệnh lệnh (command).

Trong giai đoạn hiện tại, cả 7 dịch vụ được đóng gói và phát hành chung thành một đơn vị triển khai duy nhất.
=== Kiến trúc luận lý
#fig(
  [Kiến trúc luận lý: 7 tầng và chiều phụ thuộc một chiều],
  spacing: (0mm, 6mm),

  band((0, 0), "CLIENT", (
    [Ứng dụng web · Next.js], [Ứng dụng di động · Flutter], [Bảng quản trị],
  ), rong: 150mm, name: <l-client>),

  band((0, 1), "CỔNG VÀO HTTP", (
    [Router], [Nhóm bộ xử lý tuyến], [Middleware],
    [WebSocket hub], [Bộ phục vụ đối tượng], [Response envelope],
  ), cot: 3, rong: 150mm,
    ghi: [Bộ xử lý tuyến: đọc yêu cầu, gọi hợp đồng, ghi kết quả. Tầng này không chứa một quy tắc nghiệp vụ nào.],
    name: <l-gw>),

  band((0, 2), "HỢP ĐỒNG CÔNG BỐ", (
    [account], [catalog], [order], [finance], [trust], [chat], [observability],
  ), cot: 7, rong: 150mm,
    ghi: [Giao diện dịch vụ và đối tượng truyền dữ liệu kèm nhãn kiểm tra hợp lệ. Đây
          là thứ duy nhất một dịch vụ khác được phép biết.],
    name: <l-api>),

  band((0, 3), "NGHIỆP VỤ", (
    [account], [catalog], [order], [finance], [trust], [chat], [observability],
  ), cot: 7, rong: 150mm, nen: headfill,
    ghi: [Mỗi dịch vụ gồm đúng 2 phần: lớp dịch vụ điều phối quy tắc với kho dữ
          liệu, kiểm vai người gọi và phát sự kiện; lớp quy tắc giữ thực thể, bất
          biến và toàn bộ lỗi có mã. Lớp quy tắc không biết cơ sở dữ liệu tồn tại, nên
          kiểm thử được mà không cần cơ sở dữ liệu.],
    name: <l-biz>),

  band((0, 4), "TRUY CẬP DỮ LIỆU", (
    [Cổng kho dữ liệu], [Bộ điều hợp PostgreSQL],
  ), rong: 150mm,
    ghi: [Nhật ký kiểm toán ghi trong cùng giao dịch với thay đổi mà nó ghi lại.],
    name: <l-data>),

  band((0, 5), "LƯU TRỮ VÀ HẠ TẦNG", (
    [Restate], [PostgreSQL], [Redis], [NATS JetStream], [Object Storage],
  ), rong: 150mm,
    ghi: [Mỗi dịch vụ đặt đường tìm kiếm cố định về lược đồ của chính nó, nên một câu
          lệnh cố chạm bảng của dịch vụ khác sẽ không phân giải được tên.],
    name: <l-infra>),

  band((0, 6), "CÁC DỊCH VỤ KHÁC", (
    [Cronjob], [Bộ sinh embedding],
    [Sổ đăng ký nhà cung cấp]
  ), cot: 3, rong: 150mm,
    name: <l-off>),

  edge(<l-client>, <l-gw>, "-|>", rel[HTTP/2 · WebSocket]),
  edge(<l-gw>, <l-api>, "-|>", rel[]),
  edge(<l-api>, <l-biz>, "-|>", rel[]),
  edge(<l-biz>, <l-data>, "-|>", rel[]),
  edge(<l-data>, <l-infra>, "-|>", rel[]),
  
)


  
7 dịch vụ không đối xứng nhau về vai trò. `account` là dịch vụ nền: nó không nhập gói hợp đồng
của bất kỳ dịch vụ nào khác, và mối liên hệ duy nhất của nó với phần còn lại là việc lắng nghe hai
sự kiện của dịch vụ đơn hàng, một quan hệ ở tầng sự kiện chứ không phải một lời gọi. Còn
`observability` đứng hẳn ngoài đồ thị vì nó không có gói hợp đồng để ai gọi tới. 2 dịch vụ mang
vai điều phối, mỗi dịch vụ phụ thuộc đúng 4 dịch vụ khác: `order` và `trust`, trong đó `trust`
nằm trên `order` vì nó gọi sang để leo thang một yêu cầu hoàn tiền. Đồ thị phụ thuộc
không có chu trình ở tầng gọi theo hợp đồng, nên chiều phụ thuộc kiểm tra được lúc biên dịch; hai
cặp quan hệ trông giống chu trình nhưng không phải, vì chiều ngược lại luôn là sự kiện: dịch vụ
tài chính không ra lệnh tạo đơn, nó chỉ thông báo rằng tiền đã về.

=== Cơ chế bất đồng bộ và tích hợp bên ngoài

3 cơ chế bất đồng bộ chạy song song và không được lẫn vào nhau. Trục sự kiện trên NATS JetStream chuyển
những sự việc đã xảy ra tới các nhóm tiêu thụ tương ứng, với mô hình nhóm người tiêu thụ đủ cho
nhu cầu "mỗi nhóm dịch vụ nhận đúng một lần";
7 loại sự kiện chạy trên trục này, phục vụ 5 nhóm tiêu thụ. Cùng nền tảng ấy còn mang những gì không
phải sự kiện nghiệp vụ: 4 luồng số đo vận hành đi qua JetStream, và tín hiệu đẩy thời gian thực
phát tán giữa các bản sao cổng vào đi qua công bố–đăng ký thường, vì một tín hiệu đẩy mà không máy
khách nào đang mở kết nối để nhận thì không đáng được lưu lại. Hai luồng được phân biệt bằng
kiểu dữ liệu chứ không bằng tên, để việc nối nhầm thành lỗi biên dịch. Cơ chế thứ ba là các hẹn giờ
dài, với nguyên tắc 2 nguồn dẫn động, một định nghĩa: mọi khoảng chờ đều được viết đúng
một lần dưới dạng một phương thức idempotent mà cả Restate lẫn bộ quét định kỳ cùng gọi.

=== Kiến trúc triển khai

#figure(
  image("../../common/assets/system-diagram-3x-sharp.png", width: 100%),
  caption: [Kiến trúc triển khai],
)

== Thành phần và trách nhiệm

7 dịch vụ có cùng một hình dạng, và sự lặp lại này là một quyết định thiết kế: với nhóm 3
người, việc một người mở mã của dịch vụ mình chưa từng làm và biết ngay mọi thứ nằm ở đâu có giá trị
lớn hơn việc tối ưu từng dịch vụ theo đặc thù riêng. Mỗi dịch vụ có 4 phần cố định: gói hợp đồng
công bố, là thứ duy nhất các dịch vụ khác được phép biết; lớp dịch vụ, nơi duy nhất biết cả quy tắc
lẫn kho dữ liệu; lớp quy tắc giữ thực thể, bất biến và toàn bộ lỗi có mã; và bộ điều hợp PostgreSQL
hiện thực giao diện kho dữ liệu bằng SQL viết tay. Chiều phụ thuộc là một chiều, nhờ đó quy tắc
nghiệp vụ kiểm thử được mà không cần cơ sở dữ liệu.

#figure(
  caption: [Danh mục các thành phần kiến trúc, trách nhiệm và phụ thuộc],
  table(
    columns: (1.35fr, 0.7fr, 2.2fr, 1.25fr),
    align: (left + horizon, center + horizon, left + horizon, left + horizon),
    table.header([Thành phần], [Tầng], [Trách nhiệm], [Phụ thuộc]),

    [Router, 7 nhóm bộ xử lý tuyến, middleware, WebSocket hub và bộ phục vụ đối tượng], [Cổng vào], [Đăng ký từng tuyến bằng tay, đọc yêu cầu, gọi hợp đồng, ghi kết quả, không chứa quy tắc nghiệp vụ; CORS, tra bản ghi phiên ở mọi yêu cầu đã xác thực, gắn định danh yêu cầu; giữ kết nối theo tài khoản và đẩy sự kiện; uỷ quyền tệp bằng chữ ký trên URL.], [Hợp đồng của 7 dịch vụ, kho phiên Redis, trục NATS, kho đối tượng],
    [Hợp đồng công bố (7)], [Nghiệp vụ], [Giao diện dịch vụ và đối tượng truyền dữ liệu kèm nhãn kiểm tra hợp lệ; thứ duy nhất dịch vụ khác được phép biết.], [(không)],
    [Lớp dịch vụ (7), lớp quy tắc (7), durable workflow (quy trình bền) và bộ nhận sự kiện], [Nghiệp vụ], [Dịch vụ điều phối quy tắc với kho dữ liệu, kiểm tra vai trò người gọi, phát sự kiện; lớp quy tắc giữ thực thể, bất biến và toàn bộ lỗi có mã; durable workflow giữ hẹn giờ và gọi lại phương thức idempotent khi đến hạn.], [Cổng dữ liệu, hợp đồng của dịch vụ khác, bộ durable execution, trục sự kiện],
    [Cổng kho dữ liệu (7), bộ điều hợp PostgreSQL (7) và kho dùng chung], [Truy cập dữ liệu], [SQL viết tay với tham số đặt tên; guarded write; ghi nhật ký kiểm toán cùng giao dịch.], [Lớp quy tắc, nhóm kết nối pgx],
    [Bộ ghép nối phụ thuộc, sổ đăng ký nhà cung cấp, bộ quét định kỳ, bộ sinh embedding và bộ áp migration], [Hạ tầng], [Dựng đồ thị thành phần theo kiểu giao diện; phân giải hiện thực theo tên mà hàng dữ liệu ghi lại; gọi các phương thức idempotent theo chu kỳ; rút cạn dấu "đã cũ" trên 3 bảng nguồn của chỉ mục vector; tạo lược đồ rồi áp migration.], [Mọi thành phần, các gói tích hợp, mô hình embedding],
  )
)

== Thiết kế giao diện lập trình ứng dụng

=== Nguyên tắc, phiên bản và xác thực

Giao diện lập trình của hệ thống là hợp đồng công khai duy nhất của
hệ thống: cả 3 giao diện khách đều gọi cùng tập đường dẫn này, và mã máy khách của web lẫn di động
đều sinh tự động từ đặc tả (AD-09). Mọi tuyến nằm dưới tiền tố kể cả tuyến nhận lời gọi
lại từ nhà cung cấp, bởi một đường dẫn đứng cạnh tiền tố là một đường dẫn nữa mà mọi máy chủ uỷ
nhiệm phía trước phải được cấu hình riêng. Xác thực dùng thẻ JWT sống 15 phút, nhưng phiên mới là
nguồn sự thật và được tra ở mọi yêu cầu đã xác thực, nên đăng xuất hay khoá tài khoản có hiệu lực
ngay với thẻ còn hạn; việc kiểm tra vai trò nằm ở tầng dịch vụ chứ không ở cổng vào (NFR-05), vì
vai trò là một cột trong bảng tài khoản do dịch vụ tài khoản sở hữu. Mọi định danh trên đường truyền đều ở dạng mờ, ví dụ `lst_2h9qk4mfx7bd3`.

=== Response envelope, phân trang và lỗi

Mọi thân phản hồi JSON đều có đúng một trong 2 khoá gốc `data` và `error`, kèm khoá `meta` bên
cạnh `data` cho các phản hồi có phân trang; việc không trả dữ liệu trần ở gốc là để một giao dịch có
trường `error` của riêng nó không bị nhầm với một lỗi cổng vào. Một nguyên tắc quan trọng khác là
*đối tượng truyền dữ liệu luôn gửi giá trị rỗng của nó, không bao giờ bỏ khoá đi*, được cưỡng chế
bằng một kiểm thử duyệt cây cú pháp của các gói hợp đồng; nó tồn tại vì một sự cố thật, khi một
trường tham chiếu bị bỏ qua lúc rỗng đã biến mất khỏi gần như mọi tin nhắn và khiến mã máy khách
sinh từ đặc tả không giải mã được luồng hội thoại nào.

Lỗi được chuẩn hoá thành một tập mã ổn định, ánh xạ sang mã HTTP ở đúng một nơi: 400 cho dữ liệu đầu
vào sai hoặc định danh mờ không giải mã được, 401 cho thiếu thẻ hay phiên đã bị thu hồi, 403 cho
người gọi không đủ quyền, 404 cho cả tài nguyên mà người gọi không được phép biết là nó tồn tại, 409
cho xung đột trạng thái, 422 cho yêu cầu bị một quy tắc nghiệp vụ từ chối, 429 cho quá tần suất và
502 cho hỏng hóc của nhà cung cấp bên ngoài; phản hồi 204 không
mang response envelope rỗng, và 501 được dành cho tuyến đã khai báo trong đặc tả nhưng chưa hiện thực. Mọi
thân lỗi gồm mã lỗi, thông điệp, định danh yêu cầu và danh sách trường vi phạm, trong đó định danh
yêu cầu cũng đặt ở tiêu đề của mọi phản hồi để người dùng báo lỗi luôn có một mã đối chiếu.

=== Đặc tả các endpoint tiêu biểu

Bảng dưới đây trích 17 đường dẫn tiêu biểu, xếp theo các nhóm nghiệp vụ; đặc tả đầy đủ nằm
trong tài liệu OpenAPI sinh ra từ mã nguồn, phục vụ tại `/api/v1/openapi.yaml`.

#figure(
  caption: [Đặc tả các endpoint tiêu biểu của giao diện lập trình hệ thống],
  table(
    columns: (0.5fr, 1.85fr, 2.25fr, 0.95fr),
    align: (center + horizon, left + horizon, left + horizon, center + horizon),
    table.header([PT], [Đường dẫn], [Mô tả nghiệp vụ], [Quyền]),

    [POST], [`/login`], [Đăng nhập; trả access token và refresh token.], [Công khai],
    [GET], [`/listings`], [Duyệt và tìm kiếm, lọc theo danh mục, giá, tình trạng, vị trí, xếp hạng ngữ nghĩa.], [Công khai],
    [POST], [`/listings`], [Đăng bán; đường duy nhất làm một tin đăng ra đời.], [Người dùng],
    [POST], [`/listings/suggestions`], [Gợi ý điền biểu mẫu đăng bán từ ảnh và lời mô tả; không ghi gì.], [Người dùng],
    [POST], [`/conversations/{id}/messages`], [Gửi tin nhắn văn bản hoặc đính kèm.], [Bên tham gia],
    [POST], [`/offers/{id}/acceptance`], [Chấp nhận điều khoản đang trên bàn; đóng băng giá 30 phút, chưa thu tiền.], [Bên đối diện],
    [POST], [`/shipping-quotes`], [Báo giá của mọi hãng đang bật cho một đơn nháp hoặc thương lượng đã đồng ý.], [Người mua],
    [POST], [`/drafts/{id}/checkout`], [Chốt đơn nháp và mở phiên thanh toán gồm tiền hàng cộng phí vận chuyển.], [Người mua],
    [POST], [`/orders/{id}/confirmation`], [Người bán xác nhận đơn và khởi tạo chặng vận chuyển.], [Người bán],
    [POST], [`/orders/{id}/refunds`], [Mở hồ sơ hoàn tiền kèm bằng chứng.], [Người mua],
    [POST], [`/admin/refunds/{id}/verdict`], [Phán quyết hồ sơ hoàn tiền, đóng mọi phiếu hỗ trợ liên quan.], [Điều phối viên],
    [POST], [`/payment-sessions/{id}/payments`], [Khởi tạo một lượt trả tiền trên một đường tiền cụ thể.], [Người trả tiền],
    [GET], [`/wallets`], [Số dư khả dụng và số dư tạm giữ theo từng loại tiền.], [Chủ sở hữu],
    [POST], [`/orders/{orderID}/feedback`], [Đánh giá giao dịch mù hai chiều, chiều suy ra từ vai trò người gọi.], [Bên liên quan],
    [POST], [`/tickets`], [Mở phiếu hỗ trợ: báo cáo vi phạm, khiếu nại, sự cố, đề xuất.], [Người dùng],
    [GET], [`/options`], [Lựa chọn của một hạng mục (đường tiền, hãng vận chuyển) mà bản dựng phục vụ được.], [Theo hạng mục],
    [POST], [`/ws/tickets`], [Xin vé một lần để mở kênh thời gian thực.], [Người dùng],
  )
)
