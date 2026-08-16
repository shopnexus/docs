#import "../../common/tokens.typ": *

== Các yếu tố dẫn dắt kiến trúc
#figure(
  caption: [Các yêu cầu chức năng có ý nghĩa kiến trúc],
  table(
    columns: (0.5fr, 1.5fr, 0.95fr, 2.5fr),
    align: (center + horizon, left + horizon, left + horizon, left + horizon),
    table.header([Mã], [Yêu cầu dẫn dắt], [Nguồn], [Ý nghĩa kiến trúc]),

    [AD-01], [Giữ tiền ký quỹ và giải ngân theo phán quyết], [REQ-27, REQ-33, REQ-37],
    [Giao dịch tài chính đòi hỏi tính nguyên tử trên sổ cái nhưng lại bị kích hoạt từ 3 miền rời rạc (đơn hàng, thanh toán, khiếu nại). Điều này buộc kiến trúc phải cô lập toàn bộ nghiệp vụ tiền tệ vào một dịch vụ duy nhất và tước quyền ghi sổ cái của mọi dịch vụ khác.],

    [AD-02], [Các chuyển trạng thái theo thời hạn], [REQ-21, REQ-25, REQ-30, REQ-33, REQ-36],
    [5 loại hẹn giờ dài (hết hạn thanh toán, xác nhận đơn, hoàn tiền) có vòng đời từ vài chục phút đến nhiều ngày. Quãng thời gian này vượt quá giới hạn an toàn của bộ nhớ tiến trình, đòi hỏi một cơ chế thực thi bền (durable execution) để máy trạng thái không bị mất dữ liệu khi tái khởi động.],

    [AD-03], [Tích hợp nhiều nhà cung cấp cùng loại], [REQ-24, REQ-26, REQ-43, NFR-15],
    [Dịch vụ thanh toán và vận chuyển vận hành qua nhiều đối tác; mỗi bản ghi giao dịch phải lưu vết cố định đối tác cung cấp dịch vụ. Kiến trúc phải thiết lập cơ chế sổ đăng ký (registry) để duy trì hoạt động song song của nhiều đối tác tại thời điểm chạy, thay vì định tuyến tĩnh ở cấp độ cấu hình.],

    [AD-04], [Tìm kiếm bằng ngôn ngữ tự nhiên trên dữ liệu do người dùng tự đặt tên], [REQ-14, REQ-15, REQ-16],
    [Dữ liệu đăng bán cá nhân thiếu chuẩn mực từ vựng, làm suy giảm hiệu quả của đối sánh toàn văn (full-text). Bắt buộc tích hợp chỉ mục vector kề sát dữ liệu quan hệ để thực thi truy vấn lai (hybrid search), đồng thời tách biệt tiến trình sinh vector sang một luồng phi đồng bộ.],

    [AD-05], [Truyền tin và thông báo thời gian thực], [REQ-18],
    [Trạng thái hội thoại và biến động đơn hàng phải đến thiết bị đích dưới một giây. Đòi hỏi duy trì kênh kết nối liên tục hai chiều (WebSocket) kết hợp cơ chế phát tán thông điệp (pub/sub), nhằm đồng bộ trạng thái trên mọi thiết bị đang mở của cùng một người dùng.],

    [AD-06], [Bằng chứng đa phương tiện bắt buộc], [REQ-32, REQ-34, REQ-44],
    [Tệp phương tiện (video mở hộp, ảnh minh chứng) có dung lượng vượt quá khả năng xử lý của thân yêu cầu JSON. Buộc tách rời hoàn toàn đường tải tệp khỏi luồng nghiệp vụ API, và giao quyền quản lý vòng đời tài nguyên cho từng miền sở hữu.],

    [AD-07], [Một cửa tiếp nhận cho mọi khiếu nại], [REQ-35, REQ-37, REQ-38],
    [Báo cáo vi phạm, hồ sơ hoàn tiền và yêu cầu hỗ trợ có chung bản chất: một bên gửi yêu cầu và một bên phân xử. Điều này định hướng việc gộp chúng thành một vòng đời phiếu (ticket) duy nhất, có tích hợp cơ chế ẩn danh nhằm bảo vệ điều phối viên.],

    [AD-08], [Nhật ký kiểm toán bất biến], [REQ-45, NFR-19],
    [Mọi thay đổi mang hệ quả tài chính hoặc hành chính bắt buộc để lại lưu vết bất biến. Nhật ký kiểm toán phải là một phần cốt lõi nằm chung giao dịch cơ sở dữ liệu với thao tác nghiệp vụ, không phải là một chức năng ghi ghép thêm ở tầng ứng dụng.],

    [AD-09], [2 giao diện khách trên một hợp đồng], [REQ-01…50, NFR-17],
    [Hai nền tảng máy khách (Web, Mobile) cùng chia sẻ một tập giao diện lập trình. Bản đặc tả API phải trở thành tài sản trung tâm (API-First), được dùng để sinh mã máy khách và máy chủ giả lập, thay vì chỉ là tài liệu mô tả hậu lập trình.],
  )
)


== Kiến trúc tổng thể hệ thống

=== Kiểu kiến trúc và ranh giới triển khai


Hệ thống được tổ chức theo Kiến trúc phân rã theo nhóm nghiệp vụ, chia thành 7 dịch vụ: `account`, `catalog`, `order`, `finance`, `chat`, `trust` và `observability`. Ranh giới giữa các dịch vụ này được cưỡng chế bằng cơ chế kỹ thuật thay vì chỉ là quy ước lỏng lẻo trên mã nguồn. Trong giai đoạn hiện tại, cả 7 dịch vụ được đóng gói và phát hành chung thành một đơn vị triển khai duy nhất.
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

=== Cơ chế bất đồng bộ và tích hợp bên ngoài

Trục sự kiện trên NATS JetStream được sử dụng để phân phối các sự kiện nghiệp vụ đã phát sinh tới các nhóm consumer theo mô hình pull. Bên cạnh đó, JetStream còn tiếp nhận bốn luồng số liệu vận hành, trong khi các tín hiệu thời gian thực giữa các bản sao của cổng vào được truyền qua cơ chế publish–subscribe thông thường do không cần lưu giữ khi không có máy khách kết nối. Hai loại thông điệp được phân biệt bằng kiểu dữ liệu nhằm hạn chế lỗi kết nối sai luồng ngay từ thời điểm biên dịch.

Đối với các khoảng chờ dài hạn, hệ thống áp dụng nguyên tắc hai nguồn kích hoạt, một định nghĩa xử lý: mỗi tác vụ hết hạn chỉ được hiện thực một lần dưới dạng phương thức idempotent và có thể được kích hoạt bởi cả Restate lẫn bộ quét định kỳ.

=== Kiến trúc triển khai

#figure(
  image("../../common/assets/system-diagram-3x-sharp.png", width: 90%),
  caption: [Kiến trúc triển khai],
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
đối tượng truyền dữ liệu luôn gửi giá trị rỗng của nó, không bao giờ bỏ khoá đi, được cưỡng chế
bằng một kiểm thử duyệt cây cú pháp của các gói hợp đồng; nó tồn tại vì một sự cố thật, khi một
trường tham chiếu bị bỏ qua lúc rỗng đã biến mất khỏi gần như mọi tin nhắn và khiến mã máy khách
sinh từ đặc tả không giải mã được luồng hội thoại nào.


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
    [POST], [`/tickets`], [Mở phiếu hỗ trợ: báo cáo vi phạm, khiếu nại, sự cố, đề xuất.], [Người dùng],
    [GET], [`/options`], [Lựa chọn của một hạng mục (đường tiền, hãng vận chuyển) mà bản dựng phục vụ được.], [Theo hạng mục],
    [POST], [`/ws/tickets`], [Xin vé một lần để mở kênh thời gian thực.], [Người dùng],
  )
)
