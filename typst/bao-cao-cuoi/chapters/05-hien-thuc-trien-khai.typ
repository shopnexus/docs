#import "../../common/tokens.typ": *

= HIỆN THỰC VÀ TRIỂN KHAI

Chương 4 đã cố định các quyết định kiến trúc: phân rã hệ thống thành bảy dịch vụ nghiệp vụ, mỗi dịch vụ sở hữu riêng vùng dữ liệu của mình và chỉ được gọi tới qua một hợp đồng đã công bố. Chương 5 trình bày kết quả biến những quyết định đó thành phần mềm chạy được: môi trường và công nghệ đã dùng, bộ tiêu chuẩn phát triển ràng buộc mã nguồn của cả ba kho, kết quả hiện thực từng dịch vụ nền, hai ứng dụng khách (web và di động), các seam tích hợp với nhà cung cấp bên ngoài, và cuối cùng là dây chuyền tích hợp — triển khai liên tục. Mọi số liệu trong chương được đo trực tiếp trên ba kho mã tại thời điểm chốt báo cáo, và những hạng mục còn dở dang được nêu đúng hiện trạng thay vì được làm tròn theo hướng có lợi.

== Môi trường và công nghệ hiện thực

=== Nền tảng công nghệ đã lựa chọn

Hệ thống được hiện thực bằng ba ngôn ngữ cho ba thành phần có yêu cầu khác hẳn nhau. Dịch vụ nền viết bằng Go, chọn vì mô hình đồng thời nhẹ phù hợp với một cổng dịch vụ phải giữ đồng thời nhiều kết nối WebSocket và nhiều tiến trình nền, vì khả năng biên dịch tĩnh cho ra một tệp nhị phân duy nhất không phụ thuộc thư viện hệ thống, và vì thư viện chuẩn của phiên bản 1.27 đã đưa `encoding/json/v2` vào lõi — điều này quyết định trực tiếp tới quy ước tuần tự hoá dữ liệu được trình bày ở mục sau. Ứng dụng web viết bằng Next.js với React, dùng App Router — kiến trúc này cho phép kết xuất một phần giao diện ở phía máy chủ, tuy trong phạm vi khảo sát phục vụ báo cáo chưa đối chiếu được từng trang cụ thể đang dùng cơ chế đó. Ứng dụng di động viết bằng Flutter, cho phép một cơ sở mã chạy trên cả Android và iOS.

Toàn bộ lớp lưu trữ và hạ tầng chạy nền được đóng gói bằng Docker Compose và mô tả trong kho dịch vụ nền, nên một lập trình viên mới chỉ cần một lệnh là có đủ cơ sở dữ liệu, bộ nhớ đệm, bus sự kiện và hệ quan trắc.

#figure(
  kind: table,
  caption: [Nền tảng và phiên bản công nghệ đã dùng trong hiện thực],
  table(
    columns: (1.05fr, 0.95fr, 1.6fr),
    align: (left + top, left + top, left + top),
    table.header([Thành phần], [Phiên bản], [Vai trò trong hệ thống]),
    [Go], [1.27], [Ngôn ngữ của toàn bộ dịch vụ nền và sáu tệp nhị phân công cụ],
    [Next.js / React], [16.3.0 / 19.2.8], [Ứng dụng web người dùng và giao diện quản trị],
    [TypeScript], [5.9], [Ngôn ngữ của kho web, bật chế độ kiểm tra kiểu chặt],
    [Tailwind CSS], [4.3], [Hệ thống lớp tiện ích dựng giao diện web],
    [Flutter / Dart], [3.38 / 3.11], [Ứng dụng di động đa nền tảng],
    [PostgreSQL + TimescaleDB], [18 (`timescaledb-ha`)], [Cơ sở dữ liệu chính, kèm bảng siêu dữ liệu chuỗi thời gian],
    [Phần mở rộng Postgres], [pgvector, pg\_trgm, PostGIS, timescaledb\_toolkit], [Tìm kiếm ngữ nghĩa, tìm gần đúng, dữ liệu địa lý, phân vị xấp xỉ],
    [Redis], [7], [Bộ nhớ đệm, kho phiên đăng nhập, bus sự kiện nghiệp vụ (Redis Streams)],
    [NATS JetStream], [2.10], [Bus đo lường và kênh phát tán thông điệp thời gian thực],
    [Restate], [1.7], [Thời gian chạy thực thi bền vững cho các chuyển trạng thái có hẹn giờ],
    [Grafana / Loki / Alloy], [11.3 / 3.3 / 1.5], [Bảng điều khiển quan trắc, kho nhật ký và bộ thu nhật ký],
    [Prism], [5], [Máy chủ giả lập toàn bộ hợp đồng API phục vụ phát triển song song],
    [Ảnh nền thời gian chạy], [`distroless/static-debian12`], [Ảnh chứa tối giản, chạy bằng người dùng không đặc quyền],
  ),
)

=== Thư viện chính của từng thành phần

Danh mục phụ thuộc trực tiếp của dịch vụ nền được giữ ở mức mười bốn thư viện. Con số này là một quyết định chứ không phải ngẫu nhiên: hệ thống không dùng khung ORM và không dùng bộ sinh mã truy vấn, mọi câu lệnh SQL đều viết tay và tham số hoá, nên lớp truy cập dữ liệu chỉ cần một trình điều khiển. Tương tự, không có khung web nào được đưa vào — bộ định tuyến của thư viện chuẩn đã đủ cho một cổng dịch vụ REST.

#figure(
  kind: table,
  caption: [Thư viện chính của dịch vụ nền (Go)],
  table(
    columns: (1.15fr, 0.5fr, 1.65fr),
    align: (left + top, left + top, left + top),
    table.header([Thư viện], [Phiên bản], [Mục đích sử dụng]),
    [`jackc/pgx`], [v5.10], [Trình điều khiển và bể kết nối PostgreSQL, tham số hoá theo tên],
    [`uber-go/fx`], [v1.24], [Tiêm phụ thuộc, ghép các dịch vụ vào cổng tại một điểm hợp thành duy nhất],
    [`restatedev/sdk-go`], [v1.0], [Đăng ký và điều khiển các luồng nghiệp vụ có hẹn giờ],
    [`redis/rueidis`], [v1.0], [Bộ nhớ đệm, kho phiên và bus sự kiện nghiệp vụ],
    [`nats-io/nats.go`], [v1.52], [Bus đo lường và phát tán sự kiện thời gian thực tới các cổng WebSocket],
    [`coder/websocket`], [v1.8], [Kênh thời gian thực cho tin nhắn, thông báo và cập nhật đơn hàng],
    [`go-playground/validator`], [v10.30], [Kiểm tra hợp lệ dữ liệu đầu vào và tài liệu cấu hình],
    [`golang-jwt/jwt`], [v5.3], [Phát hành và thẩm định vé truy cập ngắn hạn],
    [`coreos/go-oidc`], [v3.20], [Thẩm định vé định danh của nhà cung cấp đăng nhập liên kết],
    [`stripe/stripe-go`], [v82.5], [Kênh thanh toán quốc tế],
    [`golang.org/x/crypto`], [v0.54], [Băm mật khẩu và ký thông điệp],
    [`golang.org/x/text`], [v0.40], [Chuẩn hoá và so sánh chuỗi tiếng Việt],
    [`gopkg.in/yaml.v3`], [v3.0], [Đọc tài liệu cấu hình],
    [`google/uuid`], [v1.6], [Sinh mã định danh yêu cầu và khoá tạm thời],
  ),
)

Ở phía web, điểm đáng chú ý nhất không phải là danh sách thư viện mà là việc lớp gọi API không được viết tay. Bộ sinh `@hey-api/openapi-ts` đọc thẳng tệp đặc tả OpenAPI của kho dịch vụ nền và sinh ra toàn bộ kiểu dữ liệu, hàm gọi và các bộ mô tả truy vấn cho React Query; một tập lệnh nhỏ khác sinh kiểu cho các thông điệp thời gian thực từ đặc tả AsyncAPI. Nhờ vậy, một trường bị đổi tên trong hợp đồng sẽ trở thành lỗi biên dịch ở kho web thay vì một giá trị rỗng phát hiện được lúc chạy.

#figure(
  kind: table,
  caption: [Thư viện chính của ứng dụng web],
  table(
    columns: (1.1fr, 0.45fr, 1.75fr),
    align: (left + top, left + top, left + top),
    table.header([Thư viện], [Phiên bản], [Mục đích sử dụng]),
    [`next`], [16.3.0], [Khung ứng dụng, định tuyến theo thư mục, kết xuất phía máy chủ],
    [`react` / `react-dom`], [19.2.8], [Thư viện giao diện],
    [`@tanstack/react-query`], [5.101], [Lấy dữ liệu, bộ nhớ đệm phía trình duyệt, truy vấn phân trang vô hạn],
    [`zustand`], [5.0], [Kho trạng thái phía trình duyệt cho phiên đăng nhập và giỏ hàng],
    [`tailwindcss`], [4.3], [Hệ thống lớp tiện ích dựng giao diện],
    [`lucide-react`], [1.28], [Bộ biểu tượng],
    [`react-hot-toast`], [2.6], [Thông báo nổi phản hồi thao tác],
    [`@hey-api/openapi-ts`], [0.99], [Sinh lớp gọi API và kiểu dữ liệu từ đặc tả OpenAPI],
  ),
)

Ứng dụng di động áp dụng cùng nguyên tắc: lớp gọi API được sinh từ chính tệp đặc tả OpenAPI bằng `openapi-generator`, còn các lớp mô hình bất biến và bộ tuần tự hoá được sinh bằng `build_runner`. Phần lập trình viên viết tay chỉ còn là màn hình, luồng điều hướng và các quy tắc hiển thị.

#figure(
  kind: table,
  caption: [Thư viện chính của ứng dụng di động],
  table(
    columns: (1.1fr, 0.45fr, 1.75fr),
    align: (left + top, left + top, left + top),
    table.header([Thư viện], [Phiên bản], [Mục đích sử dụng]),
    [`flutter_riverpod`], [3.0.3], [Quản lý trạng thái và tiêm phụ thuộc],
    [`dio` + `retrofit`], [5.11 / 4.9], [Máy khách HTTP kèm bộ chặn xác thực và làm mới vé truy cập],
    [`go_router`], [14.8], [Định tuyến khai báo, hỗ trợ liên kết sâu],
    [`freezed` + `json_serializable`], [3.2 / 4.9], [Mô hình bất biến và tuần tự hoá JSON],
    [`hive`], [2.2], [Lưu trữ cục bộ vé truy cập và dữ liệu đệm],
    [`web_socket_channel`], [2.4], [Kênh thời gian thực],
    [`webview_flutter`], [4.14], [Hiển thị trang thanh toán do cổng thanh toán lưu trữ],
    [`cached_network_image` / `image_picker`], [3.4 / 1.2], [Hiển thị và chọn ảnh sản phẩm, ảnh bằng chứng khiếu nại],
    [`fl_chart`], [0.66], [Biểu đồ trong bảng điều khiển người bán],
    [`intl`], [0.19], [Định dạng tiền tệ và ngày giờ theo `vi_VN`],
  ),
)

=== Môi trường phát triển và ba chế độ chạy

Tệp Docker Compose của kho dịch vụ nền không chỉ mô tả một môi trường mà mô tả nhiều hồ sơ chạy khác nhau, tương ứng với các giai đoạn công việc khác nhau của lập trình viên. Khi không bật hồ sơ nào, Compose chỉ dựng hạ tầng — cơ sở dữ liệu, Redis, NATS và bộ ba quan trắc — còn cổng dịch vụ được chạy trực tiếp trên máy chủ phát triển; đây là vòng lặp nhanh nhất vì tận dụng bộ nhớ đệm biên dịch cục bộ. Hồ sơ phát triển bổ sung một cổng dịch vụ chạy trong chứa với cơ chế nạp lại nóng, dùng khi cần kiểm chứng đường đi của nhật ký qua bộ thu tới kho nhật ký. Hồ sơ ứng dụng dựng đúng ảnh phát hành, không nạp lại nóng, dùng cho lần kiểm tra cuối trước khi đẩy mã. Hai hồ sơ sau cùng chiếm một cổng mạng nên là hai lựa chọn thay thế nhau. Ngoài ra còn hồ sơ chạy tiến trình sinh vector ngữ nghĩa, hồ sơ dựng máy chủ giả lập toàn bộ hợp đồng API, và hồ sơ nạp thời gian chạy thực thi bền vững.

#figure(
  kind: table,
  caption: [Các hồ sơ chạy của môi trường phát triển],
  table(
    columns: (0.55fr, 1.3fr, 1.6fr),
    align: (left + top, left + top, left + top),
    table.header([Hồ sơ], [Dịch vụ được dựng thêm], [Dùng khi nào]),
    [(mặc định)], [Cơ sở dữ liệu, Redis, NATS, Grafana, Loki, Alloy], [Lặp mã Go thông thường, cổng dịch vụ chạy trên máy chủ phát triển],
    [`dev`], [Tiến trình di trú, cổng dịch vụ nạp lại nóng], [Cần nhật ký chảy qua bộ thu tới kho nhật ký],
    [`app`], [Tiến trình di trú, cổng dịch vụ từ ảnh phát hành], [Kiểm tra cuối trước khi đẩy mã lên nhánh chính],
    [`embed`], [Tiến trình sinh vector ngữ nghĩa], [Rút hàng đợi dữ liệu cần lập chỉ mục lại],
    [`mock`], [Bộ sinh đặc tả rút gọn và máy chủ giả lập Prism], [Viết ứng dụng khách khi điểm cuối chưa hiện thực xong],
    [`restate`], [Thời gian chạy thực thi bền vững], [Kiểm chứng các chuyển trạng thái có hẹn giờ],
  ),
)

Cấu hình của dịch vụ nền là một tài liệu YAML duy nhất, không có biến môi trường cho bất kỳ giá trị nghiệp vụ nào, không có giá trị mặc định và không có tệp `.env`. Mọi trường đều bắt buộc, một khoá lạ cũng làm chương trình dừng, và một giá trị sai định dạng gây lỗi ngay lúc khởi động kèm đúng đường dẫn cần sửa trong tài liệu. Biến môi trường duy nhất còn lại chỉ quyết định tệp cấu hình nằm ở đâu. Quyết định này đánh đổi sự tiện lợi lấy tính xác định: một triển khai thiếu cấu hình sẽ hỏng ngay khi khởi động thay vì âm thầm chạy bằng một giá trị mặc định sai.

== Tiêu chuẩn phát triển và tổ chức mã nguồn

=== Quy ước đặt tên và tổ chức gói

Mỗi ngôn ngữ được dùng đúng theo quy ước bản địa của nó thay vì áp một quy ước chung lên cả ba kho. Bảng sau tóm tắt các quy ước đã thống nhất, mỗi quy ước kèm một ví dụ lấy từ chính mã nguồn để quy ước không bị hiểu theo hai cách.

#figure(
  kind: table,
  caption: [Quy ước đặt tên theo từng thành phần, kèm ví dụ lấy từ mã nguồn],
  table(
    columns: (0.55fr, 1.15fr, 1.15fr, 1.12fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Đối tượng], [Dịch vụ nền (Go)], [Ứng dụng web (TypeScript)], [Ứng dụng di động (Dart)]),
    [Gói / thư mục], [một từ, chữ thường, không gạch nối — `finance`], [chữ thường, gạch nối — `admin-config`], [chữ thường, gạch dưới — `help_center`],
    [Tệp], [chữ thường, gạch dưới — `bank_account.go`], [gạch nối cho tệp thường (`admin-suspension.ts`), chữ hoa đầu từ cho thành phần React (`OrderActions.tsx`)], [chữ thường, gạch dưới — `cart_screen.dart`],
    [Kiểu dữ liệu], [chữ hoa đầu từ — `PaymentSession`], [chữ hoa đầu từ — `OrderSummary`], [chữ hoa đầu từ — `RefundRequest`],
    [Hàm và biến], [chữ thường đầu từ (`newRepo`); xuất khẩu bằng cách viết hoa chữ cái đầu (`HoldEscrow`)], [chữ thường đầu từ — `formatPrice`], [chữ thường đầu từ — `loadOrders`],
    [Hằng số], [chữ hoa đầu từ, đặt cạnh nơi công bố nó — `RoleAdmin`], [chữ hoa toàn bộ, gạch dưới — `MAX_UPLOAD_SIZE`], [chữ thường đầu từ — `defaultPageSize`],
    [Định danh SQL], [chữ thường, gạch dưới, số ít, luôn đặt trong dấu nháy kép ở tệp di trú — `"payment_session"`, `"created_at"`], [—], [—],
    [Giá trị liệt kê], [chữ thường, gạch nối — `awaiting-buyer-action`], [chữ thường, gạch nối — cùng chuỗi nhận từ hợp đồng], [chữ thường, gạch nối — cùng chuỗi nhận từ hợp đồng],
    [Tệp kiểm thử], [`*_test.go` đặt cạnh tệp được kiểm thử — `account_test.go`], [Chưa có quy ước, vì kho này chưa có tệp kiểm thử nào], [`*_test.dart` trong thư mục kiểm thử — `rate_order_test.dart`],
  ),
)

Ở cấp tổ chức, mỗi dịch vụ nền là một hình lục giác thực dụng với năm lớp cố định: lớp miền chứa thực thể, quy tắc nghiệp vụ thuần và toàn bộ lỗi của dịch vụ; lớp hợp đồng công bố giao diện dịch vụ và các đối tượng truyền dữ liệu; lớp cổng khai báo giao diện kho dữ liệu; lớp bộ điều hợp hiện thực kho dữ liệu bằng SQL viết tay; và tệp dịch vụ điều phối miền với kho dữ liệu. Chiều phụ thuộc là một chiều nghiêm ngặt, từ bộ điều hợp qua cổng tới miền. Lớp miền không được phép nhập bất kỳ thư viện hạ tầng nào, và lớp hợp đồng chỉ nhập đúng gói ngữ cảnh của thư viện chuẩn — chính ràng buộc này khiến một dịch vụ khác có thể phụ thuộc vào hợp đồng mà không kéo theo trình điều khiển cơ sở dữ liệu.

#fig(
  [Lát cắt các lớp của một dịch vụ nền và chiều phụ thuộc],
  spacing: (34mm, 13mm),
  np((0, 0), [Cổng HTTP\ (bộ xử lý)]),
  np((1, 0), [Hợp đồng công bố\ (giao diện + DTO)]),
  np((2, 0), [Dịch vụ\ (điều phối)]),
  np((3, 0), [Miền\ (thực thể, quy tắc, lỗi)]),
  np((2, 1), [Cổng kho dữ liệu\ (giao diện)]),
  np((1, 1), [Bộ điều hợp PostgreSQL\ (SQL viết tay)]),
  ng((0, 1), [Lược đồ riêng\ của dịch vụ]),
  edge((0, 0), (1, 0), "-|>"),
  edge((1, 0), (2, 0), "-|>"),
  edge((2, 0), (3, 0), "-|>"),
  edge((2, 0), (2, 1), "-|>"),
  edge((1, 1), (2, 1), "-|>", text(size: 8pt)[hiện thực]),
  edge((1, 1), (0, 1), "-|>"),
  edge((1, 1), (3, 0), "-|>", text(size: 8pt)[dùng kiểu miền], bend: -25deg),
)

Ứng dụng web tổ chức theo App Router: mỗi thư mục dưới `app` là một tuyến đường, các thành phần dùng lại nằm trong thư mục thành phần được chia theo miền chức năng, còn lớp gọi API được sinh tự động nằm tách riêng và có đưa vào quản lý phiên bản để một lần dựng ảnh không cần chạy lại bộ sinh. Ứng dụng di động tổ chức theo tính năng: mười một thư mục tính năng, mỗi thư mục tự chứa lớp dữ liệu và lớp trình bày của mình, phần dùng chung nằm trong thư mục lõi gồm mạng, định tuyến, lưu trữ, thời gian thực và chủ đề giao diện.

=== Định dạng mã và công cụ kiểm tra tĩnh

Việc định dạng mã không được để cho con người quyết định. Mã Go được `gofmt` định dạng bắt buộc, dùng ký tự tab, không giới hạn cứng độ dài dòng nhưng dấu ngoặc nhọn đặt cùng dòng theo đúng ngữ pháp ngôn ngữ. Mã TypeScript dùng thụt lề bằng tab và tuân theo bộ quy tắc của khung Next.js. Mã Dart theo định dạng chuẩn của công cụ `dart format`. Thứ tự khối nhập trong mã Go là thư viện chuẩn, thư viện bên thứ ba rồi gói nội bộ; trong mã Dart, mọi khối nhập bắt buộc dùng đường dẫn theo gói và một khối nhập tương đối bị coi là lỗi biên dịch chứ không phải cảnh báo, vì một thư viện được nạp qua hai đường dẫn khác nhau sẽ tạo ra hai bản sao kiểu dữ liệu không so sánh bằng nhau lúc chạy.

#figure(
  kind: table,
  caption: [Công cụ kiểm tra tĩnh và hiện trạng vận hành],
  table(
    columns: (0.65fr, 1.1fr, 1.05fr, 1.2fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Kho], [Công cụ], [Tệp cấu hình], [Hiện trạng]),
    [server], [`gofmt`, `go vet`], [—], [Chạy được, không còn cảnh báo nào],
    [server], [`golangci-lint`], [`.golangci.yml`], [*Chưa chạy được*: bản phát hành của công cụ được dựng bằng Go 1.26, thấp hơn phiên bản đích 1.27. Khoảng trống này được ghi rõ ngay trong tệp cấu hình],
    [website], [`eslint`], [`eslint.config.mjs`], [Chạy được nhưng phải gọi thủ công; đợt khảo sát này không ghi nhận kết quả chạy nào],
    [website], [`tsc --noEmit`], [`tsconfig.json`], [Chạy được nhưng phải gọi thủ công; đợt khảo sát này không ghi nhận kết quả chạy nào],
    [app], [`flutter analyze`], [`analysis_options.yaml`], [Chạy tự động trong dây chuyền tích hợp liên tục],
  ),
)

Cần nói rõ hiện trạng thay vì mô tả một quy trình lý tưởng: bộ kiểm tra tĩnh đầy đủ của Go được cấu hình sẵn với năm nhóm quy tắc và ba ngoại lệ có lập luận, nhưng chưa thể chạy vì công cụ chưa hỗ trợ phiên bản ngôn ngữ đang dùng, nên cổng chất lượng tĩnh thực tế của kho dịch vụ nền hiện chỉ là `go vet`. Hai công cụ của kho web tuy chạy được nhưng chưa được gắn vào dây chuyền tự động, nghĩa là chúng phụ thuộc vào kỷ luật của người phát triển; và vì không có bước tự động nào lưu lại kết quả, đợt khảo sát phục vụ báo cáo này không thu được bằng chứng nào cho thấy hai công cụ ấy đang chạy sạch — chỉ biết rằng chúng chạy được. Chỉ kho ứng dụng di động có kiểm tra tĩnh bắt buộc trên mỗi lần đẩy mã.

Cũng cần ghi nhận một biện pháp bù rẻ nhất mà dự án chưa dùng: móc chạy trước khi ghi nhận thay đổi ở máy phát triển. Một móc như vậy chạy được bộ định dạng và bộ kiểm tra tĩnh ngay tại chỗ, không phụ thuộc vào dây chuyền tự động, nên nó đúng là thứ nên có ở một dự án mà hai trong ba kho không chạy kiểm tra nào lúc tích hợp. Cả ba kho hiện chưa cài móc nào, và việc bổ sung được xếp vào phần hướng khắc phục ở Chương 6 cùng với việc đưa bước kiểm thử vào dây chuyền.

=== Quy ước bình luận và tài liệu

Bình luận trong toàn bộ dự án viết bằng tiếng Anh và tuân theo một nguyên tắc duy nhất: bình luận nói *vì sao*, còn chữ ký hàm đã nói *cái gì*. Mọi bình luận chỉ diễn đạt lại điều mã nguồn đã thể hiện đều bị loại bỏ trong khâu rà soát; những gì được giữ lại là bất biến cần bảo toàn, sự cố mà một đoạn mã đang phòng ngừa, và lý do của một quyết định trái trực giác. Ở cấp cao hơn, mỗi kho có một tệp hướng dẫn duy nhất đặt tại thư mục gốc, ghi lại các quy ước đã chốt dưới dạng các gạch đầu dòng ngắn; khi một chủ đề vượt quá khuôn khổ một gạch đầu dòng, nó được tách thành tài liệu riêng và được liên kết từ tệp gốc. Một hệ quả của nguyên tắc ấy cần được nói rõ vì nó là chỗ dự án cố ý lệch khỏi chuẩn viết tài liệu thông dụng: dự án *không* bắt buộc mỗi ký hiệu xuất khẩu phải có một khối bình luận tài liệu. Lập luận là một bình luận bắt buộc trên mọi ký hiệu sẽ sinh ra hàng loạt câu chép lại chính chữ ký hàm, và những câu ấy vừa không mang thông tin vừa che lấp số ít bình luận thật sự cần đọc; bù lại, hợp đồng công bố của mỗi dịch vụ được mô tả đầy đủ trong đặc tả API chứ không trong bình luận mã. Đây là một lệch chuẩn có chủ ý chứ không phải một tiêu chí bị bỏ sót, và cái giá của nó là người đọc mã phải dựa vào tên và vào đặc tả thay vì vào bình luận.

Hợp đồng API không được viết tay ở một chỗ và hiện thực ở chỗ khác: đặc tả OpenAPI được biên soạn thành từng mảnh, mỗi mảnh ứng với một khối tổng hợp nghiệp vụ và nằm ngay trong thư mục hợp đồng của dịch vụ sở hữu nó, rồi được một công cụ hợp nhất thành một tệp đặc tả duy nhất.

=== Chuẩn chất lượng, bảo mật và hiệu năng

Về chất lượng, cần phân biệt giữa mục tiêu và thứ cưỡng chế được. Chiến lược kiểm thử trình bày ở Chương 6 có đặt mục tiêu độ phủ mã tám mươi phần trăm cho mức đơn vị, nhưng đó là mục tiêu do phương pháp luận đề ra chứ không phải kết quả đã đạt được: tới thời điểm chốt báo cáo, độ phủ mã *chưa được đo ở bất kỳ kho nào trong ba kho*, và cũng chưa có bước nào trong dây chuyền tự động đo nó, nên hiện chưa có ngưỡng độ phủ hay ngưỡng độ phức tạp chu trình nào được cưỡng chế trên mã nguồn. Riêng ngưỡng độ phức tạp chu trình và ngưỡng độ dài hàm còn là một lệch chuẩn có chủ ý so với các bộ tiêu chuẩn viết mã thông dụng, chứ không chỉ là chuyện thiếu công cụ: một hàm dịch vụ điều phối bảy bước nghiệp vụ tuần tự có độ phức tạp cao theo phép đếm nhánh nhưng lại dễ đọc hơn hẳn ba hàm nhỏ chỉ tồn tại để hạ con số đó, nên nhóm chọn ràng buộc bằng chiều phụ thuộc và bằng danh mục rà soát thay vì bằng một ngưỡng số. Thay vào đó, chất lượng đang được ràng buộc bằng những quy tắc có thể kiểm tra được bằng phép thử. Đáng kể nhất là ba quy tắc: một đối tượng truyền dữ liệu không bao giờ được phép bỏ qua trường có giá trị rỗng khi tuần tự hoá — một danh sách rỗng phải hiện ra là mảng rỗng chứ không phải giá trị vắng mặt — và có hẳn một phép thử duyệt cây cú pháp của các gói hợp đồng để chỉ đích danh trường vi phạm; mọi đường dẫn trong đặc tả API phải có tuyến đường thật tương ứng trong bộ định tuyến; và mọi lỗi được truyền lên phải được bọc lại kèm mô tả thao tác đã thất bại thay vì trả về nguyên trạng.

Về bảo mật, bốn quy tắc được áp dụng không ngoại lệ, và một hạng mục thứ năm phải được ghi nhận là còn thiếu. Thứ nhất, không có bí mật nào nằm trong mã nguồn: mọi thông tin xác thực đều nằm trong tài liệu cấu hình vốn bị loại khỏi quản lý phiên bản, và bản mẫu được commit chỉ chứa hình dạng chứ không chứa giá trị. Thứ hai, mọi câu lệnh SQL đều tham số hoá theo tên; không có một chỗ nào nối chuỗi để dựng câu truy vấn, kể cả với các lệnh cập nhật có điều kiện — chúng được viết thành câu lệnh hằng dùng biểu thức điều kiện thay vì ghép chuỗi. Thứ ba, mọi dữ liệu đầu vào đều đi qua bộ kiểm tra hợp lệ khai báo bằng thẻ trên đối tượng truyền dữ liệu trước khi tới lớp dịch vụ. Thứ tư, mã định danh trên đường truyền là mã đục: khoá chính trong cơ sở dữ liệu là số nguyên tuần tự, nhưng khi ra tới hợp đồng nó được hoán vị bằng một phép mã hoá có khoá và mã hoá lại theo bảng chữ cái Base32 kèm tiền tố phân loại, nên một khách hàng không thể suy ra số lượng bản ghi hay dò tuần tự các bản ghi lân cận. Hạng mục còn thiếu là làm sạch dữ liệu xuất ra và phòng chống chèn mã kịch bản phía trình duyệt: đây là một sàn nơi người dùng tự nhập tiêu đề tin đăng, mô tả sản phẩm và nội dung tin nhắn, tức là nơi rủi ro ấy có thật, nhưng bộ tiêu chuẩn hiện chỉ dựa vào cơ chế thoát chuỗi mặc định của thư viện giao diện chứ chưa có một quy tắc thành văn nào và cũng chưa có công cụ nào cưỡng chế nó.

Về hiệu năng, quy tắc quan trọng nhất là mọi danh sách đều phân trang theo con trỏ chứ không theo số trang, và toàn bộ ba kho dùng chung một định dạng con trỏ. Truy vấn được viết tay nên tránh được truy vấn lồng lặp lại; các phép đếm và điểm đánh giá trung bình được tính sẵn và lưu vào cột đệm thay vì tính lại khi đọc. Bộ nhớ đệm chỉ được đặt ở những chỗ có lý do rõ ràng: vector của câu truy vấn tìm kiếm và mã xác thực dùng một lần. Với dữ liệu chuỗi thời gian — thông báo, tin nhắn và bốn tín hiệu đo lường — bảng được khai báo là bảng siêu dữ liệu chia mảnh theo thời gian, kèm chính sách nén và chính sách xoá dữ liệu quá hạn.

Cuối cùng, quy trình rà soát mã dựa trên một danh mục kiểm tra ngắn: chiều phụ thuộc có bị vi phạm không; lỗi có được bọc kèm mô tả thao tác không; ghi dữ liệu có được bảo vệ bằng cơ chế phiên bản hoặc điều kiện trạng thái không; đối tượng truyền dữ liệu có bỏ sót trường rỗng không; câu lệnh SQL có tham số hoá không; và một hằng số dùng chung giữa hai gói có được công bố bởi đúng bên sở hữu nó không.

=== Quy mô mã nguồn

#figure(
  kind: table,
  caption: [Quy mô mã nguồn của ba kho tại thời điểm chốt báo cáo],
  table(
    columns: (1.25fr, 0.75fr, 0.7fr, 0.9fr),
    align: (left + top, right + top, right + top, left + top),
    table.header([Thành phần], [Số tệp], [Số dòng], [Ghi chú]),
    [Dịch vụ nền — mã Go (không kể kiểm thử)], [268], [48 627], [Viết tay],
    [Dịch vụ nền — mã kiểm thử Go], [107], [30 482], [Viết tay],
    [Dịch vụ nền — tệp di trú SQL], [22], [2 314], [Viết tay],
    [Dịch vụ nền — đặc tả OpenAPI hợp nhất], [1], [11 366], [Sinh từ 36 mảnh],
    [Dịch vụ nền — đặc tả AsyncAPI hợp nhất], [1], [599], [Sinh từ 4 mảnh],
    [Ứng dụng web — mã viết tay], [375], [34 109], [TypeScript, TSX],
    [Ứng dụng web — lớp gọi API sinh tự động], [18], [17 987], [Từ đặc tả OpenAPI],
    [Ứng dụng di động — mã viết tay], [162], [41 394], [Dart],
    [Ứng dụng di động — mã sinh tự động], [561], [53 654], [Client API và mã của `build_runner`],
    [Ứng dụng di động — mã kiểm thử], [44], [6 092], [Viết tay],
    [*Tổng mã nguồn viết tay ba kho*], [*956*], [*160 704*], [Không kể mã sinh tự động và không kể tệp di trú SQL],
  ),
)

Hàng tổng chỉ cộng mã nguồn của ba ngôn ngữ lập trình; nếu tính thêm 22 tệp di trú với 2 314 dòng SQL thì con số là 978 tệp và 163 018 dòng. Tỉ lệ mã sinh tự động khá lớn — hơn bảy mươi nghìn dòng trên hai kho ứng dụng khách — và đó là hệ quả trực tiếp của việc lấy đặc tả API làm nguồn sự thật duy nhất. Đáng lưu ý là ở kho dịch vụ nền không có một dòng mã Go nào được sinh tự động: thứ được sinh ra ở đây là hai tệp đặc tả, đi theo chiều ngược lại so với hai kho khách.

== Hiện thực dịch vụ nền

=== Bố cục chung và cách cô lập dữ liệu

Bảy dịch vụ nghiệp vụ được hiện thực với cùng một bố cục thư mục, cùng một cách khai báo phụ thuộc và cùng một cách công bố hợp đồng. Sự đồng nhất này không phải là trang trí: nó cho phép một người đọc mã của dịch vụ thứ bảy mà không phải học lại cách tổ chức, và cho phép thêm dịch vụ mới bằng một quy trình lặp lại được gồm năm bước — tạo cây thư mục chuẩn, khai báo chuỗi kết nối riêng, đăng ký dịch vụ tại điểm hợp thành và tại tiến trình di trú, thêm bộ xử lý cùng tuyến đường ở cổng, và bổ sung mảnh đặc tả API.

Cô lập dữ liệu được thực thi bằng lược đồ Postgres: mỗi dịch vụ có một lược đồ mang đúng tên nó, và bể kết nối của dịch vụ đặt đường tìm kiếm về lược đồ đó. Hệ quả là toàn bộ SQL — cả câu lệnh định nghĩa lẫn câu lệnh truy vấn — đều viết không kèm tên lược đồ, nên không tồn tại một câu lệnh nào đọc chéo sang bảng của dịch vụ khác; một truy vấn như vậy sẽ hỏng ngay lúc chạy chứ không âm thầm thành công. Chỉ tiến trình di trú biết tên lược đồ, vì nó phải tạo lược đồ trước khi áp các tệp di trú. Nhờ ràng buộc này, việc tách một dịch vụ sang cơ sở dữ liệu riêng về sau chỉ là đổi chuỗi kết nối của nó, không phải viết lại truy vấn.

Ba bảng mà dịch vụ nào cũng cần — nhật ký kiểm toán, tài nguyên tệp tải lên và tuỳ chọn cấu hình — được định nghĩa một lần trong bộ dùng chung và được tiến trình di trú áp vào từng lược đồ trước các tệp riêng của dịch vụ. Cách làm này giữ được cả hai điều tưởng như mâu thuẫn: văn bản định nghĩa chỉ tồn tại một bản, còn dữ liệu vẫn nằm trong lược đồ của dịch vụ sở hữu nó và đi theo dịch vụ đó nếu sau này tách cơ sở dữ liệu. Trước khi có bộ dùng chung, bảy bản sao chép tay của bảng nhật ký kiểm toán đã tồn tại và bốn trong số đó đã lệch nhau.

#figure(
  kind: table,
  caption: [Tổng hợp quy mô hiện thực của bảy dịch vụ nền],
  table(
    columns: (0.85fr, 0.42fr, 0.44fr, 0.4fr, 0.42fr, 0.55fr, 0.62fr),
    align: (left + top, right + top, right + top, right + top, right + top, right + top, left + top),
    table.header([Dịch vụ], [Tệp Go], [Dòng mã], [Bảng], [Kiểu liệt kê], [Đường dẫn / Thao tác], [Đặc thù]),
    [account], [37], [6 264], [8], [9], [41 / 47], [Bảng siêu dữ liệu thông báo],
    [catalog], [34], [5 940], [12], [3], [17 / 25], [Vector ngữ nghĩa, dữ liệu địa lý],
    [order], [28], [7 939], [7], [3], [30 / 38], [Bốn luồng thực thi bền vững],
    [finance], [21], [3 832], [6], [5], [20 / 25], [Bên phát hành sự kiện thanh toán],
    [chat], [13], [1 967], [2], [2], [8 / 11], [Bảng siêu dữ liệu tin nhắn],
    [trust], [19], [3 816], [7], [7], [16 / 22], [Bốn bộ thu sự kiện],
    [observability], [10], [580], [4], [0], [0 / 0], [Bốn bảng siêu dữ liệu, hai khung nhìn tổng hợp],
    [(bộ dùng chung)], [14], [1 328], [3], [0], [3 / 3], [Nhân bản vào sáu lược đồ],
  ),
)

Tổng cộng hợp đồng API công bố 135 đường dẫn và 171 thao tác, trong đó 27 đường dẫn thuộc khu vực quản trị, cùng 235 lược đồ dữ liệu; kênh thời gian thực công bố một kênh với tám loại thông điệp. Bảy lược đồ Postgres chứa 46 bảng riêng của các dịch vụ, cộng thêm ba bảng dùng chung được nhân vào sáu lược đồ.

=== Dịch vụ quản lý tài khoản

Dịch vụ tài khoản là dịch vụ có bề mặt API rộng nhất với 47 thao tác trên 41 đường dẫn, phản ánh việc nó gánh cả định danh, xác thực, hồ sơ, liên hệ, thiết bị, thông báo và xác minh danh tính. Điểm hiện thực đáng chú ý nhất là mô hình phiên đăng nhập. Vé truy cập là một chuỗi JWT sống mười lăm phút, mang cả danh tính tài khoản lẫn mã phiên; nhưng bản thân phiên là một khoá trong Redis với thời hạn ba mươi ngày, và bộ lọc xác thực tra khoá đó trên *mọi* yêu cầu đã đăng nhập. Chính lần tra cứu ấy làm cho thao tác đăng xuất, đổi mật khẩu hay khoá tài khoản có hiệu lực tức thì đối với một vé đã phát ra ngoài — điều mà một chuỗi JWT đơn thuần không làm được. Việc thu hồi toàn bộ phiên của một tài khoản được hiện thực bằng cách tăng một số kỷ nguyên gắn với tài khoản chứ không duyệt danh sách phiên, nên chi phí không phụ thuộc số phiên đang mở.

Một quyết định hiện thực khác đáng ghi nhận là cách xác định khối tổng hợp. Chỉ tài khoản cùng với các định danh đăng nhập liên kết của nó tạo thành một khối tổng hợp, vì quy tắc "luôn còn ít nhất một cách đăng nhập" trải trên cả hai; các bảng khác tuy đều mang mã tài khoản nhưng là khối tổng hợp riêng, để một thao tác đổi tên hiển thị không phải nạp toàn bộ sổ địa chỉ và danh sách thiết bị. Mọi lệnh ghi đi theo trình tự nạp — sửa trong bộ nhớ — lưu, và lệnh lưu ghi kèm điều kiện số phiên bản, nên một lần đọc cũ sẽ thua thay vì ghi đè lên thứ nó chưa từng thấy.

Bàn hỗ trợ khách hàng được nhận diện bằng *vai trò* chứ không bằng tên đăng nhập, sau khi nhận ra rằng tên đăng nhập là thứ người dùng có thể tự đăng ký; một tài khoản mang vai trò hỗ trợ được cấp bởi tệp di trú và được bảo vệ bằng chỉ mục duy nhất bộ phận.

=== Dịch vụ danh mục sản phẩm

Dịch vụ danh mục quản lý mười hai bảng, bao trùm cây danh mục, tin đăng, biến thể, nhãn, ảnh, tồn kho và ba bảng vector ngữ nghĩa. Cần nói rõ rằng tồn kho *nằm trong* dịch vụ này chứ không phải một dịch vụ riêng: số lượng còn lại là một thuộc tính của thứ đang được bán, và tách nó ra sẽ tạo ra một giao dịch phân tán cho mỗi lần đặt giữ hàng mà không đổi lại được lợi ích nào. Vòng đời tồn kho gồm đặt giữ, chốt và trả lại, được viết dưới dạng cập nhật có điều kiện trên trạng thái.

Tìm kiếm được hiện thực theo hướng lai. Mỗi tin đăng, mỗi danh mục và mỗi nhãn mang một cột đánh dấu thời điểm dữ liệu mô tả của nó thay đổi; một tiến trình riêng biệt rút các hàng còn dấu, gọi mô hình sinh vector và ghi vector kèm việc xoá dấu trong cùng một giao dịch. Danh sách công việc như vậy là một *thuộc tính của dữ liệu* chứ không phải một thông điệp có thể mất: một hàng bị sửa trong lúc triển khai vẫn còn dấu sau khi triển khai xong, và một lượt chạy lặp lại sẽ không tìm thấy gì. Việc xoá dấu được ràng buộc bằng đúng giá trị đã đọc, nên một hàng bị đánh dấu lại trong lúc mô hình đang xử lý sẽ ở lại hàng đợi thay vì bị tuyên bố là đã mới. Khi một tin đăng chưa có vector, truy vấn lùi về tìm gần đúng theo chuỗi ký tự, nên việc không chạy tiến trình sinh vector vẫn là một cấu hình triển khai hợp lệ.

Dịch vụ này cũng chứa chức năng gợi ý điền biểu mẫu đăng bán bằng mô hình ngôn ngữ. Ranh giới của chức năng được đặt rất rõ: nó đọc ảnh người bán vừa tải lên cùng lời mô tả (gõ tay hoặc ghi âm rồi chuyển thành văn bản ở phía máy chủ) và trả về một biểu mẫu đã điền sẵn, nhưng *không ghi gì cả* — không tin đăng, không bản nháp, không một bản ghi nào cho một lần thử bị bỏ dở. Trường nào mô hình không đủ căn cứ thì để trống thay vì đoán, và giá chỉ được điền khi người bán đã nói ra một con số.

=== Dịch vụ đơn hàng

Dịch vụ đơn hàng là dịch vụ lớn nhất về khối lượng mã với gần tám nghìn dòng, và cũng là nơi tập trung các quy tắc nghiệp vụ tinh vi nhất. Nguyên tắc chi phối toàn bộ hiện thực là: *người bán không duyệt đơn, dòng tiền tạo ra đơn*. Không có tuyến đường nào biến các mặt hàng đã thanh toán thành đơn hàng; chính bộ thu sự kiện thanh toán thành công làm việc đó. Đây là lý do trường mã đơn trên dòng hàng cho phép rỗng, và chỉ mục các dòng hàng chưa gắn đơn là một danh sách cần thử lại chứ không phải một hộp thư chờ duyệt.

Thứ hai, quyền mua được giành *trước* khi tiền được động tới. Bản nháp thanh toán được đánh dấu đã tiêu, còn một đề nghị giá đã được chấp thuận chuyển sang trạng thái đã thanh toán, cả hai đều bằng cập nhật có điều kiện, trước khi bất kỳ phiên thanh toán nào được mở. Nếu giành quyền sau khi mở phiên, một cú nhấp đúp sẽ mở hai phiên và khoản tiền thứ hai là khoản mà cơ chế ký quỹ không thể hạch toán được. Điều gì thất bại sau khi đã giành quyền thì trả quyền lại, để người mua thử lại chứ không phải thương lượng lại.

Thương lượng giá được hiện thực bằng cách chia đôi: hàng dữ liệu chứa điều khoản, trạng thái và hạn hiệu lực nằm ở dịch vụ đơn hàng, còn cuộc hội thoại nằm ở dịch vụ trò chuyện và chỉ mang mã đề nghị trong siêu dữ liệu của một tin nhắn hệ thống. Nếu sao chép giá vào nội dung tin nhắn, một lần trả giá tiếp theo sẽ để lại trong cuộc trò chuyện một mức giá không còn hiệu lực. Việc một bên chấp thuận điều khoản chưa phải là bán được hàng: nó đóng băng giá trong ba mươi phút và người mua vẫn phải chọn hãng vận chuyển rồi thanh toán, chính khoảng tách đó khiến việc người bán chấp thuận trở nên an toàn vì chưa có đồng tiền nào bị động tới.

Cước vận chuyển luôn do người mua trả và luôn được *báo giá* chứ không do khách hàng gửi lên: một điểm cuối riêng hỏi giá của mọi hãng đang bật cho một bản nháp hoặc một đề nghị đã chấp thuận. Khoản cước là một chân riêng trong bút toán ký quỹ, không bao giờ chảy vào ví người bán, vì đó là tiền của hãng vận chuyển. Sau khi tiền đã chuyển, hệ thống gọi hãng vận chuyển để đặt vận đơn và lưu mã tham chiếu của hãng; một lần gọi thất bại được coi là việc cần thử lại chứ không phải lý do từ chối đơn, và chính mã tham chiếu đó là dấu ngăn không cho một lần thử lại đặt ra hai vận đơn cho cùng một lần bán.

Về mặt thời gian, dịch vụ này hiện thực bốn luồng thực thi bền vững cho bốn chuyển trạng thái có hẹn giờ, đồng thời giữ một tiến trình quét định kỳ gọi *chính những phương thức đó*. Hai bộ dẫn động, một định nghĩa: cách này khiến việc bật hay tắt thời gian chạy bền vững chỉ là một lựa chọn cấu hình, và khi nó bật thì tiến trình quét chạy không tìm thấy gì nên không tốn kém.

=== Dịch vụ tài chính

Dịch vụ tài chính sở hữu toàn bộ các nguyên thể tiền tệ: phiên thanh toán, sổ cái giao dịch, ví, tài khoản ngân hàng, thông tin thuế và lệnh rút tiền. Việc gom chúng vào một dịch vụ là điều kiện để các bút toán ký quỹ diễn ra nguyên tử; nếu ví nằm ở một dịch vụ và sổ cái ở dịch vụ khác thì mỗi lần giữ tiền sẽ trở thành một giao dịch phân tán.

Luồng chính bắt đầu bằng việc mở một phiên thanh toán, chuyển người trả tiền sang kênh thanh toán đã chọn, rồi chờ thông báo bất đồng bộ từ kênh đó. Một nguyên tắc được tuân thủ tuyệt đối: trang mà người trả tiền được chuyển về *không phải là bằng chứng*. Cả hai kênh thanh toán đã có máy khách đều nhận một địa chỉ trả về và đều trỏ mọi kết cục — thành công, lỗi hay huỷ — về cùng một trang, vì nơi người dùng dừng chân là điều bất kỳ ai cũng có thể giả mạo. Chỉ lời gọi ngược mới quyết toán một chân thanh toán, và một lần quyết toán thất bại trả về mã lỗi máy chủ để nhà cung cấp gửi lại, bởi đó là cơ hội duy nhất để biết sự việc đã xảy ra.

Ký quỹ được hiện thực thành ba thao tác: giữ, giải toả và hoàn. Thao tác giữ chỉ giữ phần tiền hàng, còn phần cước là chân thứ ba trong cùng một bút toán. Cước chỉ quay lại người mua khi kiện hàng chưa từng rời đi; một quyết định hoàn tiền không trả lại cước, vì chặng vận chuyển đã diễn ra thì đã được mua thật, và ai chịu chặng gửi trả là việc của phán quyết.

=== Dịch vụ trò chuyện

Dịch vụ trò chuyện chỉ có hai bảng nhưng phải phục vụ ba loại nhu cầu: hội thoại trực tiếp giữa người mua và người bán, luồng đàm phán giá, và luồng phiếu hỗ trợ. Tin nhắn được lưu trong một bảng siêu dữ liệu chia mảnh theo thời gian, thích hợp với dữ liệu chỉ ghi thêm và đọc theo cửa sổ thời gian gần.

Điểm hiện thực khó nhất là việc nhân viên hỗ trợ phải ẩn danh với người dùng nhưng vẫn phải là người gửi thật của lời họ viết. Một hàm trợ giúp duy nhất quyết định điều này: ở những chỗ giá trị phụ thuộc vào người xem — đối phương trong hội thoại, dấu đã đọc, số tin chưa đọc — nhân viên được tính là *quầy hỗ trợ*, nhờ đó dấu đã đọc được dùng chung và người tiếp theo trực ca kế thừa được ngữ cảnh; còn người gửi tin nhắn thì không bao giờ bị ánh xạ, vì làm vậy sẽ xoá tên chính người dùng khỏi những dòng họ tự viết. Việc ẩn danh phải được áp ở *mọi* hình chiếu của một tin nhắn, không chỉ trong luồng hội thoại: một lỗi từng để lộ mã tài khoản nhân viên qua trường tin nhắn cuối trên danh sách hộp thư, mà mã đó chỉ cần một lời gọi công khai là ra tên người.

Người dùng không thể nhắn tin thẳng cho quầy hỗ trợ — mã tài khoản của quầy là công khai vì nó là đối phương của mọi phiếu — vì một hội thoại trực tiếp là hội thoại không điều phối viên nào đọc được; thay vào đó, việc liên hệ hỗ trợ luôn bắt đầu bằng một phiếu.

=== Dịch vụ tín nhiệm

Dịch vụ tín nhiệm gộp bốn nhóm chức năng vào bảy bảng: đánh giá sản phẩm cùng phần trả lời và bình chọn hữu ích, phản hồi giao dịch hai chiều, điểm uy tín, và phiếu hỗ trợ.

Phản hồi giao dịch được hiện thực theo cơ chế *mù*: một bản đánh giá không hiển thị cho tới khi cả hai bên đã gửi hoặc hết cửa sổ chờ, để một lời đánh giá không thể mang tính trả đũa; và chiều của phản hồi được suy ra từ việc người gọi đứng ở phía nào của đơn hàng chứ không bao giờ do khách hàng gửi lên. Việc công bố chính là việc cộng điểm vào bảng uy tín, thực hiện trong cùng một giao dịch, nên một bản đánh giá đã nhìn thấy được luôn là một bản đã được tính, và điều kiện "chưa công bố" là thứ ngăn nó bị tính lần thứ hai. Điểm phản hồi giao dịch và điểm đánh giá sản phẩm được đếm trên hai cặp cột riêng, vì một đơn hàng có thể sinh ra cả hai và cộng chung sẽ tính đơn đó hai lần. Một tài khoản chưa ai đánh giá trả về các số không, không phải lỗi không tìm thấy.

Đáng chú ý nhất trong dịch vụ này là quyết định gộp: *mọi* việc người dùng phản ánh đều là một phiếu, và một bảng duy nhất chứa tất cả. Báo cáo vi phạm, khiếu nại hoàn tiền, sự cố đơn hàng, trục trặc thanh toán và đề xuất tính năng khác nhau đúng một trường phân loại — trường đó quyết định phiếu có gắn với một đối tượng nào không và lý do nào được phép chọn. Không có bảng báo cáo riêng và không có bảng tranh chấp riêng: trước đây bảy trạng thái trải trên ba bảng thực chất là một vòng đời viết ba lần, và người dùng muốn hỏi "yêu cầu của tôi đang ở đâu" phải tìm ở ba nơi.

Vì hàng dữ liệu phiếu và hàng dữ liệu hội thoại nằm ở hai lược đồ khác nhau, phiếu được ghi trước còn luồng hội thoại được mở theo kiểu nỗ lực tối đa và tự sửa khi đọc: một sự cố ở dịch vụ trò chuyện để lại một phiếu câm chứ không làm mất lời phản ánh, và lần đọc phiếu kế tiếp sẽ mở luồng. Khi một phán quyết hoàn tiền được ban hành ở dịch vụ đơn hàng, dịch vụ tín nhiệm nhận sự kiện và đóng *mọi* phiếu đang mở về đúng đối tượng đó, bởi cả hai bên đều có quyền khiếu nại và một tra cứu chỉ trả về một hàng sẽ để lại phiếu còn lại mở vĩnh viễn.

=== Dịch vụ quan trắc

Dịch vụ quan trắc là dịch vụ nhỏ nhất — mười tệp, khoảng năm trăm tám mươi dòng — và là dịch vụ duy nhất không có lớp hợp đồng, vì không thành phần nào gọi tới nó; nó được dẫn động bởi bộ lọc trung gian, bộ lấy mẫu và bus sự kiện.

Kiến trúc của nó gồm hai chặng. Chặng một, bộ thu phát mỗi mẫu đo lên NATS JetStream; việc phát là bất đồng bộ và nỗ lực tối đa, không bao giờ chặn hay làm hỏng một yêu cầu người dùng, và một mẫu không tới được bus thì được đếm chứ không thử lại. Chặng hai, bộ ghi tiêu thụ từng chủ đề theo lô kèm thời gian gom, rồi nạp cả lô vào bảng siêu dữ liệu bằng lệnh sao chép hàng loạt. Khi mẫu đã vào được hàng đợi bền thì nó không mất nữa: một lần ghi hỏng sẽ từ chối cả lô và lô đó được gửi lại. Hai bus cùng tồn tại trong đồ thị phụ thuộc và được phân biệt bằng *kiểu*, không bằng tên.

Bốn tín hiệu được thu thập: nhịp và độ trễ của yêu cầu vào, nhịp và độ trễ của lời gọi ra tới nhà cung cấp bên ngoài, các chỉ số thời gian chạy của tiến trình, và bản sao các sự kiện nghiệp vụ. Mỗi hàng mang mã bản thể chạy để nhiều bản sao không bị gộp thành một chuỗi vô nghĩa. Hai khung nhìn tổng hợp liên tục giữ một cấu trúc phác thảo phân vị, nhờ đó phân vị 95 được đọc bằng hàm xấp xỉ chứ không bao giờ bằng cách lấy trung bình của các phân vị 95. Nhật ký đi theo một đường riêng: ứng dụng ghi JSON ra luồng chuẩn, bộ thu gom vào kho nhật ký và cùng một Grafana đọc cả hai nguồn. Hệ thống không dùng Prometheus, và phân tích hành vi người dùng nằm ngoài dịch vụ nền.

#fig(
  [Hai chặng của đường đi một mẫu đo lường],
  spacing: (30mm, 12mm),
  np((0, 0), [Bộ lọc trung gian\ (yêu cầu vào)]),
  np((0, 1), [Bộ quan sát\ lời gọi ra]),
  np((0, 2), [Bộ lấy mẫu\ thời gian chạy]),
  np((0, 3), [Bộ sao chép\ sự kiện nghiệp vụ]),
  ncore((1, 1.5), [Bộ thu\ (đóng dấu bản thể)]),
  nt((2, 1.5), [NATS JetStream]),
  np((3, 1.5), [Bộ ghi theo lô]),
  ng((4, 1.5), [Bảng siêu dữ liệu\ TimescaleDB]),
  ng((4, 0.3), [Grafana]),
  edge((0, 0), (1, 1.5), "-|>"),
  edge((0, 1), (1, 1.5), "-|>"),
  edge((0, 2), (1, 1.5), "-|>"),
  edge((0, 3), (1, 1.5), "-|>"),
  edge((1, 1.5), (2, 1.5), "-|>", text(size: 8pt)[nỗ lực tối đa]),
  edge((2, 1.5), (3, 1.5), "-|>", text(size: 8pt)[theo lô]),
  edge((3, 1.5), (4, 1.5), "-|>", text(size: 8pt)[sao chép hàng loạt]),
  edge((4, 1.5), (4, 0.3), "-|>", text(size: 8pt)[đọc thẳng bảng]),
)

== Hiện thực ứng dụng web

=== Cấu trúc tuyến đường và phân vùng chức năng

Ứng dụng web được dựng trên App Router của Next.js với 52 trang, sáu bố cục lồng nhau và 58 thành phần giao diện dùng lại. Các tuyến đường được chia thành bốn vùng rõ rệt. Vùng công khai gồm trang chủ, tìm kiếm, chi tiết sản phẩm, trang gian hàng của người bán và các trang nội dung tĩnh về điều khoản, quyền riêng tư và trợ giúp. Vùng xác thực gồm đăng nhập, đăng ký, quên mật khẩu, đặt lại mật khẩu và xác minh thư điện tử, được gom vào một nhóm tuyến đường có bố cục riêng. Vùng người dùng đã đăng nhập gồm giỏ hàng, thanh toán, đơn hàng, khiếu nại hoàn tiền, hộp thư trò chuyện, thông báo, phiếu hỗ trợ và bảng điều khiển cá nhân với mười ba trang con trải từ hồ sơ, bảo mật, xác minh danh tính, ví tiền, sổ địa chỉ, danh sách yêu thích, danh sách theo dõi, cho tới quản lý sản phẩm đang bán. Vùng quản trị gồm mười một mục nghiệp vụ dành cho điều phối viên và quản trị viên, cộng một trang chỉ mục dẫn vào chúng: duyệt tin đăng, quản lý tài khoản và điều phối viên, danh mục, nhãn, phiếu hỗ trợ, phiên thanh toán, lệnh rút tiền, hồ sơ xác minh danh tính và bảng tuỳ chọn cấu hình.

Việc bảo vệ tuyến đường được thực hiện ở hai lớp. Lớp ngoài cùng là một tầng trung gian chạy trước khi kết xuất, chuyển hướng người chưa đăng nhập ra trang đăng nhập kèm địa chỉ quay lại, và ngược lại đẩy người đã đăng nhập ra khỏi các trang chỉ dành cho khách. Lớp này chỉ nhìn sự hiện diện của vé truy cập nên nó là tiện ích trải nghiệm chứ không phải hàng rào an ninh; quyền thật sự vẫn do dịch vụ nền kiểm tra trên từng lời gọi, và mọi kiểm tra vai trò đều nằm ở lớp dịch vụ chứ không ở bộ xử lý.

=== Lớp gọi API và trạng thái

Toàn bộ lớp gọi API được sinh từ đặc tả OpenAPI, kèm sẵn các bộ mô tả truy vấn, truy vấn phân trang vô hạn và các bộ mô tả thao tác ghi cho React Query. Một tệp cấu hình thời gian chạy nhỏ được cắm vào bộ sinh để xử lý ba việc mà bộ sinh không biết: gắn vé truy cập, tự động làm mới khi gặp mã lỗi xác thực rồi phát lại lời gọi, và bóc phong bì lỗi chuẩn của hệ thống thành đối tượng lỗi có mã.

Trạng thái được chia làm hai loại theo đúng bản chất. Dữ liệu máy chủ do React Query quản lý, với các khoá truy vấn được sinh sẵn và một lớp trợ giúp làm mất hiệu lực bộ nhớ đệm sau mỗi thao tác ghi. Trạng thái thuần khách — phiên đăng nhập và giỏ hàng — do hai kho Zustand nhỏ giữ. Kênh thời gian thực được bọc thành một nhà cung cấp ngữ cảnh đặt ở gốc cây thành phần: nó mở một kết nối WebSocket duy nhất cho cả phiên làm việc, phân phối tám loại thông điệp tới các bộ xử lý tương ứng, và mỗi bộ xử lý làm mất hiệu lực đúng những truy vấn bị ảnh hưởng. Nhờ đó một tin nhắn mới hay một cập nhật trạng thái đơn hàng làm giao diện tự cập nhật mà không cần hỏi lại toàn bộ.

Ứng dụng được đóng gói ở chế độ độc lập, nghĩa là bản dựng phát ra một máy chủ tự chứa chỉ kèm những phụ thuộc thực sự được dùng, nên ảnh chứa thời gian chạy không cần cài lại thư viện.

=== Giao diện các luồng nghiệp vụ chính

Giao diện của hệ thống được xây dựng bám theo một bộ thiết kế đặt tên là "Human Commerce", lấy màu chủ đạo là sắc lam lục trên nền trắng ngà, bo góc mềm và lưới bốn điểm ảnh. Hình sau là bản thiết kế giao diện của trang chủ được dùng làm chuẩn tham chiếu trong quá trình hiện thực; đây là *bản thiết kế*, không phải ảnh chụp sản phẩm đã chạy.

#figure(
  mockup("home", width: 84%),
  caption: [Bản thiết kế giao diện trang chủ (mockup thiết kế, không phải ảnh chụp sản phẩm)],
)

Các hình tiếp theo là những màn hình cần được ghi lại từ sản phẩm đã chạy để minh chứng kết quả hiện thực. Ba điều kiện sau áp cho *mọi* chỗ chờ ảnh chụp trong chương này, cả phần web lẫn phần di động. Thứ nhất, ảnh phải được chụp trên môi trường phát triển nạp bằng bộ dữ liệu mồi của đề tài, không phải trên dữ liệu người dùng thật. Thứ hai, mọi thông tin có thể nhận dạng cá nhân xuất hiện trong khung hình — họ tên, số điện thoại, địa chỉ nhận hàng, thư điện tử, ảnh giấy tờ tuỳ thân — phải được che trước khi đưa vào báo cáo, kể cả khi đó là dữ liệu mồi, để một quy ước duy nhất được áp cho mọi hình. Thứ ba, ảnh web chụp ở chiều rộng khung nhìn tối thiểu 1440 điểm ảnh và ảnh di động ở độ phân giải gốc của thiết bị, vì một ảnh bị thu nhỏ tới mức không đọc được chữ thì không chứng minh được điều gì.

#anh-cho(
  [Trang kết quả tìm kiếm với bộ lọc nhiều chiều],
  [Chụp trang kết quả tìm kiếm sau khi gõ một từ khoá tiếng Việt không dấu hoặc viết tắt, mở sẵn panel bộ lọc để thấy khoảng giá, tình trạng sản phẩm, khu vực và điểm uy tín người bán.],
)

#anh-cho(
  [Trang chi tiết sản phẩm với hai chế độ giá],
  [Chụp trang chi tiết một tin đăng ở chế độ giá thương lượng, thấy rõ giá niêm yết, nút mua ngay và nút mở thương lượng, kèm khối điểm uy tín và số lượt đánh giá của người bán.],
)

#anh-cho(
  [Luồng thương lượng giá trong hộp thư trò chuyện],
  [Chụp hộp thư trò chuyện ở trạng thái đang có một đề nghị giá còn hiệu lực, đăng nhập bằng tài khoản người mua, thấy rõ thẻ đề nghị giá kèm hạn hiệu lực và các nút trả giá / chấp thuận.],
)

#anh-cho(
  [Trang thanh toán với báo giá vận chuyển do bản giả lập cung cấp],
  [Chụp trang thanh toán sau khi đã chọn địa chỉ nhận hàng, thấy rõ danh sách các phương án vận chuyển kèm cước và thời gian dự kiến, phần tách bạch tiền hàng và cước, cùng danh sách kênh thanh toán. Vì chưa có hãng vận chuyển thật nào được hiện thực, các phương án hiện ra trong ảnh là ba mức dịch vụ của bản giả lập; chú thích hình phải nói rõ điều đó thay vì để người đọc hiểu là báo giá của hãng thật.],
)

#anh-cho(
  [Màn hình theo dõi đơn hàng của người mua],
  [Chụp trang chi tiết một đơn ở trạng thái đang giao, đăng nhập bằng tài khoản người mua, thấy rõ dải tiến trình vận chuyển, đồng hồ đếm ngược thời hạn ký quỹ và nút xác nhận đã nhận hàng.],
)

#anh-cho(
  [Luồng khiếu nại hoàn tiền kèm bằng chứng],
  [Chụp trang chi tiết một yêu cầu hoàn tiền đã đính kèm ảnh hoặc video bằng chứng, thấy rõ trạng thái yêu cầu, thời hạn phản hồi của người bán và nút chuyển thành phiếu hỗ trợ.],
)

#anh-cho(
  [Giao diện quản trị: hàng đợi phiếu hỗ trợ],
  [Chụp trang danh sách phiếu hỗ trợ trong khu vực quản trị, đăng nhập bằng tài khoản điều phối viên, thấy rõ bộ lọc theo loại phiếu và trạng thái, cùng một phiếu khiếu nại hoàn tiền đang chờ phán quyết.],
)

== Hiện thực ứng dụng di động

=== Tổ chức theo tính năng và hạ tầng dùng chung

Ứng dụng di động được tổ chức theo tính năng thay vì theo tầng kỹ thuật: mười một thư mục tính năng, mỗi thư mục tự chứa lớp dữ liệu và lớp trình bày, và chỉ tính năng khiếu nại hoàn tiền có thêm lớp miền riêng vì nó mang quy tắc thời hạn. Cách chia này khiến việc thêm một màn hình chỉ chạm vào một thư mục. Bảng dưới đây liệt kê mười một thư mục tính năng đó cùng hai thư mục dùng chung — thư mục lõi và thư mục thành phần chia sẻ — vốn không phải tính năng nhưng vẫn thuộc phần mã viết tay.

#figure(
  kind: table,
  caption: [Quy mô mã viết tay của ứng dụng di động theo thư mục: mười một tính năng nghiệp vụ và hai thư mục dùng chung],
  table(
    columns: (1fr, 0.5fr, 0.6fr, 1.55fr),
    align: (left + top, right + top, right + top, left + top),
    table.header([Thư mục], [Số tệp], [Số dòng], [Phạm vi chức năng]),
    [account], [44], [10 433], [Hồ sơ, bảo mật, địa chỉ, thông báo, ví, thuế, tài khoản liên kết],
    [seller], [24], [8 685], [Đăng bán, quản lý tin đăng, đơn bán, doanh thu, đánh giá],
    [catalog], [13], [7 406], [Trang chủ, danh mục, tìm kiếm, chi tiết sản phẩm, yêu thích],
    [chat], [12], [2 927], [Hộp thư, luồng hội thoại, đính kèm, thẻ đề nghị giá],
    [checkout], [5], [2 157], [Chọn địa chỉ, báo giá vận chuyển, chọn kênh thanh toán],
    [core (dùng chung)], [19], [1 751], [Mạng, định tuyến, lưu trữ cục bộ, thời gian thực, chủ đề],
    [shared (dùng chung)], [9], [1 444], [Thành phần giao diện và tiện ích dùng chung],
    [auth], [7], [1 347], [Đăng ký, đăng nhập, đăng nhập liên kết, quên mật khẩu],
    [kyc], [6], [1 333], [Nộp giấy tờ và theo dõi kết quả xác minh danh tính],
    [refund], [8], [1 164], [Tạo yêu cầu hoàn tiền, đính kèm bằng chứng, theo dõi],
    [help\_center], [4], [911], [Trung tâm trợ giúp và câu hỏi thường gặp],
    [cart], [3], [873], [Giỏ hàng],
    [ticket], [6], [872], [Tạo và theo dõi phiếu hỗ trợ],
  ),
)

Hạ tầng dùng chung nằm ở thư mục lõi. Máy khách HTTP được cấu hình một lần kèm bộ chặn gắn vé truy cập và tự động làm mới khi hết hạn; kho lưu trữ cục bộ giữ vé và một phần dữ liệu đệm; bộ định tuyến khai báo bốn mươi tuyến đường phân cấp, trong đó nhánh tài khoản và nhánh người bán đều là tuyến lồng có bố cục riêng; và một máy khách thời gian thực dùng chung mở kênh WebSocket rồi phân phối sự kiện tới các nhà cung cấp trạng thái. Quản lý trạng thái và tiêm phụ thuộc dùng Riverpod với các nhà cung cấp được sinh từ chú giải, nên quan hệ phụ thuộc giữa các nhà cung cấp được kiểm tra lúc biên dịch.

Trang thanh toán do kênh thanh toán lưu trữ được mở trong một khung duyệt web nhúng, đúng với nguyên tắc đã nêu ở dịch vụ tài chính: ứng dụng chỉ đưa người dùng tới đó rồi chờ trạng thái phiên thanh toán, chứ không coi việc quay về là bằng chứng đã trả tiền.

=== Các màn hình chính

#figure(
  mockup("order-tracking", width: 52%),
  caption: [Bản thiết kế giao diện màn hình theo dõi đơn hàng trên di động (mockup thiết kế, không phải ảnh chụp sản phẩm)],
)

#anh-cho(
  [Màn hình trang chủ và điều hướng chính trên ứng dụng di động],
  [Chụp màn hình trang chủ trên thiết bị Android, đã đăng nhập, thấy rõ thanh điều hướng dưới cùng, ô tìm kiếm và lưới sản phẩm.],
  cao: 7.2cm,
)

#anh-cho(
  [Luồng đăng bán sản phẩm với gợi ý điền biểu mẫu],
  [Chụp màn hình tạo tin đăng sau khi đã tải lên ảnh và nhận gợi ý điền sẵn, thấy rõ các trường đã được điền, phần lời mô tả đã ghi âm được chuyển thành văn bản và các trường mô hình để trống vì thiếu căn cứ. Bắt buộc chụp khi hệ thống đang chạy với nhà cung cấp mô hình ngôn ngữ thật: chụp lúc đang dùng bản giả lập sẽ cho một biểu mẫu điền bằng dữ liệu dựng sẵn, và bức ảnh khi đó nói sai về chính tính năng nó minh hoạ.],
  cao: 7.2cm,
)

#anh-cho(
  [Màn hình thanh toán và chọn phương án vận chuyển do bản giả lập cung cấp, trên di động],
  [Chụp màn hình thanh toán ở bước chọn hãng vận chuyển, thấy rõ nhiều phương án kèm cước khác nhau và tổng tiền được tách thành tiền hàng và cước. Cũng như bản web, các phương án hiện ra là của bản giả lập chứ không phải của hãng thật, và chú thích hình phải ghi rõ.],
  cao: 7.2cm,
)

#anh-cho(
  [Màn hình xác minh danh tính],
  [Chụp màn hình nộp giấy tờ xác minh danh tính ở trạng thái đang chờ thẩm định, thấy rõ ảnh giấy tờ đã tải lên và trạng thái hồ sơ.],
  cao: 7.2cm,
)

#anh-cho(
  [Bảng điều khiển doanh thu của người bán trên di động],
  [Chụp màn hình doanh thu trong nhánh người bán, tài khoản đã có ít nhất vài đơn hoàn tất, thấy rõ biểu đồ và số dư ví.],
  cao: 7.2cm,
)

== Tích hợp các nhà cung cấp bên ngoài

=== Tám seam tích hợp và nguyên tắc lựa chọn

Toàn bộ phần giao tiếp với thế giới bên ngoài được gom vào một thư mục riêng gồm 31 tệp và hơn năm nghìn dòng, tổ chức thành tám seam. Mỗi seam là một giao diện hẹp cộng với một hoặc nhiều hiện thực, trong đó luôn có một hiện thực giả lập.

#figure(
  kind: table,
  caption: [Tám seam tích hợp nhà cung cấp bên ngoài],
  table(
    columns: (0.62fr, 1.15fr, 1.0fr, 0.95fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Seam], [Nhà cung cấp đã hiện thực], [Cách chọn], [Hiện trạng]),
    [Sinh vector], [Dịch vụ BGE-M3 tự vận hành; bản giả lập], [Bộ chọn trong cấu hình], [Đã viết máy khách, kiểm thử bằng máy chủ giả],
    [Xác minh danh tính], [FPT.AI eKYC; bản giả lập], [Bộ chọn trong cấu hình], [Đã viết máy khách, kiểm thử bằng máy chủ giả],
    [Mô hình ngôn ngữ], [Proxy tương thích giao diện của OpenAI; bản giả lập], [Bộ chọn trong cấu hình], [Đã viết máy khách, kiểm thử bằng máy chủ giả],
    [Thông báo], [SMTP cho thư điện tử, eSMS.vn cho tin nhắn; bản giả lập], [Hai bộ chọn riêng], [Đã viết máy khách, kiểm thử bằng máy chủ giả],
    [Đăng nhập liên kết], [Thẩm định vé định danh OIDC (Google, Apple); bản giả lập], [Bộ chọn trong cấu hình], [Đã viết máy khách, kiểm thử bằng máy chủ giả],
    [Thanh toán], [SePay.vn, Stripe; bản giả lập], [Sổ đăng ký, chọn theo hàng dữ liệu], [Đã viết máy khách, kiểm thử bằng máy chủ giả],
    [Lưu trữ tệp], [Hệ tệp cục bộ ký liên kết bằng HMAC; nguồn ngoài chỉ đọc], [Sổ đăng ký, chọn theo hàng dữ liệu], [Đã hiện thực; *không có nhà cung cấp bên ngoài* — nơi lưu là hệ tệp của chính cổng dịch vụ],
    [Vận chuyển], [*Chỉ có bản giả lập*], [Sổ đăng ký, chọn theo hàng dữ liệu], [*Chưa có hiện thực của hãng thật nào*],
  ),
)

Cột hiện trạng cần được đọc đúng mức, và mức đó thấp hơn chữ "đã tích hợp" thường được dùng. Máy khách của sáu seam đầu đã được viết theo tài liệu của nhà cung cấp, có xử lý lỗi, chữ ký và định dạng dữ liệu riêng của từng bên, và đã được kiểm chứng bằng 115 hàm kiểm thử chạy trên một *máy chủ HTTP giả dựng ngay trong ca kiểm thử*. Nhưng trong phạm vi khảo sát phục vụ báo cáo này, chưa thu thập được bằng chứng của một lời gọi thật nào tới môi trường thử nghiệm hay môi trường sản xuất của bất kỳ nhà cung cấp nào — không có nhật ký một giao dịch thử, không có mã tham chiếu do FPT.AI, eSMS.vn, SePay hay Stripe trả về, không có hiện vật nào của một lần gọi ra khỏi máy phát triển. Đây là cùng một tiêu chuẩn bằng chứng đã được áp cho phần triển khai trên cụm ở mục sau: cái gì có tệp và chạy được với bộ giả lập thì nói là đã viết xong và đã kiểm thử được, cái gì chưa từng chạm vào dịch vụ thật thì nói là chưa.

Hai seam còn lại thậm chí không nằm ở mức đó. Seam lưu trữ tệp không có nhà cung cấp bên ngoài nào: hiện thực đang chạy ghi tệp lên chính hệ tệp của cổng dịch vụ và ký liên kết tải xuống bằng HMAC, còn hiện thực thứ hai chỉ đọc từ một nguồn ngoài đã có sẵn địa chỉ; không có tích hợp kho đối tượng nào. Seam vận chuyển thì *chưa* có hiện thực của bất kỳ hãng thật nào. Giao diện, sổ đăng ký, luồng báo giá, luồng đặt vận đơn, luồng nhận cập nhật hành trình và toàn bộ quy tắc nghiệp vụ phía trên đều đã hoàn thiện và đã được kiểm chứng bằng bản giả lập, nhưng việc kết nối với GHN, GHTK hay Viettel Post vẫn là kế hoạch chứ chưa phải kết quả. Mọi phát biểu trong báo cáo về hãng vận chuyển cần được đọc theo nghĩa đó.

Cách chọn nhà cung cấp được phân làm hai nhóm theo một tiêu chí rõ ràng. Với những seam mà quá khứ không lưu lại tên nhà cung cấp, một bộ chọn duy nhất trong cấu hình quyết định — một giá trị lạ làm chương trình dừng ngay khi khởi động chứ không lùi về mặc định, bởi một triển khai tưởng rằng mình đang gửi thư thật mà thực ra thì không sẽ chỉ bị phát hiện bởi chính người dùng không nhận được thư. Ngược lại, với thanh toán, vận chuyển và lưu trữ tệp — nơi một hàng dữ liệu đã quyết toán còn ghi tên nhà cung cấp mãi mãi — cơ chế là một *sổ đăng ký*: mọi hiện thực có mặt trong tệp nhị phân đều được nạp, và tên nhà cung cấp lấy từ chính hàng dữ liệu quyết định hiện thực nào phục vụ nó. Nhờ đó hai kênh thanh toán có thể cùng hoạt động, và việc chuyển một hãng vận chuyển từ nhà cung cấp này sang nhà cung cấp khác là một thao tác quản trị chứ không phải một lần khởi động lại toàn hệ thống. Một nhà cung cấp không được nạp thì bị từ chối chứ không bao giờ được thay thế bằng nhà cung cấp khác.

Mỗi nhà cung cấp tự khai báo những hàng tuỳ chọn mà nó phục vụ, và hệ thống đối chiếu lại danh sách đó lúc khởi động; những hàng không còn hiện thực nào phục vụ sẽ biến mất khỏi danh sách người mua được chọn nhưng vẫn hiển thị trong giao diện quản trị, vì đó là nơi câu hỏi "tại sao mục này biến mất khỏi thanh toán" được trả lời.

=== Bản giả lập và các kịch bản lỗi

Hai seam quan trọng nhất — thanh toán và vận chuyển — có bản giả lập được đầu tư như một sản phẩm nhỏ, vì giá trị của một bản giả lập nằm ở các trường hợp biên mà nó tái hiện được.

#figure(
  kind: table,
  caption: [Các kịch bản của hai bản giả lập],
  table(
    columns: (0.5fr, 3.2fr),
    align: (left + top, left + top),
    table.header([Seam], [Kịch bản đã hiện thực]),
    [Thanh toán], [Thành công; bị từ chối; thành công chậm; chuyển tới trang thanh toán; báo kết quả muộn qua lời gọi ngược; báo từ chối muộn; *báo cùng một lần thành công hai lần*; *báo thành công với số tiền khác*; không kết nối được; treo ở trạng thái chờ vĩnh viễn — 10 kịch bản],
    [Vận chuyển], [Ba mức dịch vụ với cước và thời gian khác nhau; không phục vụ tuyến; báo giá chậm; báo giá được nhưng đặt vận đơn thất bại; kiện hàng đứng yên mãi; giao thất bại; *báo trùng một mốc hành trình*; *báo một mốc lùi về phía sau*; báo một trạng thái nền tảng không mô hình hoá — 11 kịch bản],
  ),
)

Mỗi kịch bản tương ứng với một quy tắc ở nơi khác trong hệ thống: quy tắc chỉ tiến không lùi của tiến trình vận đơn, quy tắc bỏ qua một từ vựng trạng thái không nhận biết thay vì đoán, quy tắc thử lại việc đặt vận đơn, quy tắc chống quyết toán hai lần. Một quy tắc không có cách nào chạm tới là một quy tắc không ai kiểm chứng. Cả hai bản giả lập đều phục vụ một trang HTML cho người vận hành: trang của kênh thanh toán quyết định một giao dịch bằng hai nút, còn bảng điều khiển của hãng vận chuyển đưa một kiện hàng đi qua từng mốc hành trình bằng một nút cho mỗi trạng thái. Đây không phải chi tiết trang trí — trước đó kịch bản "kiện hàng đứng yên" yêu cầu người kiểm thử gõ một lệnh dòng lệnh mà thực tế không ai gõ, nên kịch bản tồn tại mà không bao giờ được chạy. Cả hai trang đều không nuốt lỗi: một thao tác không ghi được sẽ trả về mã lỗi máy chủ, bởi một trang ghi nhật ký rồi trả về mã thành công trông giống hệt một trang đã làm được việc.

=== Thời hạn và quan trắc lời gọi ra

Không một máy khách HTTP nào trong hệ thống đặt thời hạn ở cấp máy khách, vì thời hạn đó bao trùm cả việc đọc thân phản hồi nên nó cắt cụt một luồng dữ liệu đang chảy. Thay vào đó, mỗi thao tác tự đặt thời hạn riêng, với độ dài là một trường cấu hình bắt buộc, bởi thời hạn hợp lý là kiến thức của nhà cung cấp chứ không của người gọi; thao tác đọc luồng có ngân sách riêng dài hơn, tính cho toàn bộ quá trình đọc. Do cơ chế ngữ cảnh luôn giữ lại thời hạn nào ngắn hơn, một ngân sách gắn với yêu cầu người dùng vẫn luôn thắng.

Việc đo đạc lời gọi ra không nằm trong từng phương thức mà nằm ở lớp vận chuyển, dưới dạng một tầng bọc trên máy khách HTTP được lắp đúng một lần tại điểm hợp thành cho bảy máy khách có gọi HTTP đi ra ngoài — sáu máy khách nhà cung cấp cộng với thời gian chạy thực thi bền vững, vốn không phải một nhà cung cấp theo nghĩa của mục này nhưng cũng là một lời gọi qua mạng cần đo. Một tầng như vậy bao trùm mọi phương thức của mọi nhà cung cấp, và điểm nó trả về là lúc nhận được phần đầu phản hồi — đúng chỉ số sức khoẻ cho một luồng dữ liệu.

== Quy trình tích hợp và triển khai liên tục

=== Dây chuyền tích hợp liên tục của ba kho

Ba kho có ba mức trưởng thành khác nhau, và cần trình bày đúng như vậy.

#figure(
  kind: table,
  caption: [Các luồng công việc tích hợp liên tục của ba kho],
  table(
    columns: (0.5fr, 0.85fr, 0.85fr, 1.6fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Kho], [Luồng công việc], [Kích hoạt bởi], [Các bước thực hiện]),
    [server], [Dựng và đẩy ảnh], [Đẩy mã lên nhánh chính], [Dựng ảnh chứa chỉ định rõ tầng phát hành, đẩy lên kho ảnh kèm hai nhãn, rồi thông báo cho kho tài liệu],
    [server], [Kiểm tra đặc tả API], [Đẩy mã và mở yêu cầu gộp], [Sinh lại đặc tả rồi so sánh; khác biệt làm hỏng bản dựng],
    [website], [Dựng và đẩy ảnh], [Đẩy mã lên nhánh chính], [Chỉ dựng và đẩy ảnh chứa],
    [app], [Kiểm tra tích hợp], [Đẩy mã và mở yêu cầu gộp], [Sinh mã, *phân tích tĩnh*, *chạy kiểm thử*, dựng tệp cài đặt và lưu làm hiện vật],
    [app], [Phát hành tự động], [Gắn nhãn phiên bản], [Dựng tệp cài đặt và tạo bản phát hành kèm ghi chú tự sinh],
    [app], [Xuất bản bản web], [Đẩy mã lên nhánh chính], [Dựng bản web của ứng dụng và xuất bản lên trang tĩnh],
  ),
)

Hai điều phải nói thẳng. Thứ nhất, dây chuyền của kho dịch vụ nền *không chạy kiểm thử*: hai luồng công việc duy nhất là dựng ảnh và kiểm tra đặc tả API không bị lệch so với mã nguồn; không có bước chạy bộ kiểm thử, không có bước phân tích tĩnh và không có bước kiểm tra định dạng. Cổng tự động duy nhất mà kho này có là cổng chống lệch đặc tả. Thứ hai, dây chuyền của kho web thậm chí chỉ dựng ảnh: không phân tích tĩnh, không kiểm tra kiểu, không kiểm thử — hai công cụ kiểm tra có sẵn nhưng phải gọi thủ công. Kho ứng dụng di động là kho duy nhất thực sự chạy phân tích tĩnh và bộ kiểm thử trên mỗi lần đẩy mã. Đây là khoảng trống rõ rệt nhất của quy trình hiện tại và được ghi nhận trong phần đánh giá của Chương 6.

Việc kiểm tra đặc tả API tuy đơn giản nhưng đáng giá: nó sinh lại tệp đặc tả từ các mảnh rồi so sánh với tệp đã commit, và một khác biệt sẽ làm hỏng bản dựng. Vì hai kho khách sinh lớp gọi API từ chính tệp này, một hợp đồng bị sửa mà quên sinh lại sẽ bị chặn ngay tại yêu cầu gộp thay vì lộ ra khi ứng dụng khách không giải mã được phản hồi.

=== Đóng gói bằng ảnh chứa

Kho dịch vụ nền có một tệp Dockerfile ba tầng. Tầng dựng biên dịch tĩnh ra bốn tệp nhị phân: cổng dịch vụ, tiến trình di trú, tiến trình sinh vector và bộ sinh đặc tả rút gọn. Tầng phát triển không kế thừa tầng dựng mà cài công cụ nạp lại nóng, vì mã nguồn tới bằng cách gắn thư mục nên một lệnh sao chép sẽ bị che khuất. Tầng phát hành dựa trên ảnh nền tối giản không chứa hệ vỏ và chạy bằng người dùng không đặc quyền, chỉ sao chép bốn tệp nhị phân sang. Tiến trình nạp dữ liệu mẫu cố ý không có mặt trong ảnh phát hành vì nó cần đọc một tệp dữ liệu bốn megabyte từ đĩa. Bản dựng trong dây chuyền tự động chỉ định *tường minh* tầng phát hành thay vì dựa vào quy ước "tầng cuối thắng" — nếu dựa vào quy ước, một tầng được thêm vào sau này sẽ vô tình đưa cả bộ công cụ biên dịch vào ảnh phát hành. Ảnh của kho web cũng có ba tầng và chạy bản dựng độc lập bằng người dùng không đặc quyền.

Ở giai đoạn hiện tại, bảy dịch vụ nghiệp vụ được nạp bởi một tiến trình cổng duy nhất: điểm hợp thành gắn từng dịch vụ vào đồ thị phụ thuộc, và việc ghép nối giữa các dịch vụ diễn ra qua giao diện hợp đồng đã công bố. Ranh giới dữ liệu vẫn giữ nguyên vì mỗi dịch vụ có chuỗi kết nối và lược đồ riêng, nên việc tách một dịch vụ ra tiến trình riêng về sau không đòi hỏi viết lại truy vấn hay đổi hợp đồng.

=== Di trú cơ sở dữ liệu

Các tệp di trú được nhúng vào tệp nhị phân của từng dịch vụ và *chỉ* được áp bởi tiến trình di trú; ứng dụng không bao giờ tự di trú lúc khởi động, để một lần khởi động lại nhiều bản sao không dẫn tới nhiều tiến trình cùng sửa lược đồ. Tiến trình này nhận bảy đích, mỗi đích gồm tên, chuỗi kết nối và tập tệp di trú; tên đích đồng thời là tên lược đồ. Với mỗi đích, nó tạo lược đồ nếu chưa có, áp bộ tệp dùng chung trước rồi tới bộ tệp riêng của dịch vụ. Tệp dùng chung được đặt tên để luôn sắp trước, nhờ đó hai bộ tệp chia chung một bảng theo dõi phiên bản mà không giẫm lên nhau. Cần lưu ý rằng các tệp di trú chỉ đi theo chiều tiến, không có tệp lùi và chưa có quy trình kiểm thử khôi phục.

=== Mô hình triển khai

Kho ô dù chứa toàn bộ cấu hình triển khai dưới dạng khai báo. Mô hình được chọn là GitOps với Argo CD: một đối tượng ứng dụng theo dõi thư mục cấu hình Kubernetes trong kho, bật chế độ đồng bộ tự động kèm dọn dẹp tài nguyên thừa và tự chữa lành khi trạng thái thực tế lệch khỏi khai báo. Cấu hình được soạn bằng Kustomize gồm không gian tên, ba dịch vụ hạ tầng, ba khối triển khai ứng dụng, quy tắc định tuyến vào cụm và một tác vụ di trú. Bản đồ cấu hình được sinh từ tệp cấu hình với hậu tố băm nội dung, nên một thay đổi cấu hình tự nó kích hoạt một lần cuộn lại ứng dụng; các bí mật được tạo ngoài dây chuyền.

Tác vụ di trú được khai báo là một móc đồng bộ ở làn sóng thứ nhất, tức là chạy sau khi hạ tầng sẵn sàng và trước khi ứng dụng được cuộn ra, với giới hạn số lần thử lại và chính sách xoá tác vụ cũ trước khi tạo tác vụ mới. Nó nhận toàn bộ cấu hình giống hệt cổng dịch vụ, vì nó dùng chung một bộ nạp cấu hình.

Việc cập nhật phiên bản được giao cho bộ theo dõi ảnh của Argo CD, cấu hình theo *bản tóm tắt nội dung* thay vì theo nhãn, vì nhãn của nhánh chính là nhãn có thể bị ghi đè — theo dõi theo bản tóm tắt phát hiện được cả một lần dựng lại trên cùng nhãn. Hệ quả là dây chuyền tích hợp liên tục *không* triển khai gì cả: nó chỉ dựng và đẩy ảnh, còn Argo CD kéo về.

#fig(
  [Dây chuyền từ mã nguồn tới cụm triển khai],
  spacing: (27mm, 12mm),
  np((0, 0), [Kho mã nguồn\ (3 kho)]),
  np((1, 0), [Tích hợp liên tục\ (dựng ảnh)]),
  nt((2, 0), [Kho ảnh chứa]),
  np((3, 0), [Bộ theo dõi ảnh\ (theo bản tóm tắt)]),
  np((3, 1), [Kho cấu hình\ Kubernetes]),
  ncore((4, 0.5), [Argo CD\ (đồng bộ tự động)]),
  ng((5, 0), [Tác vụ di trú\ (làn sóng 1)]),
  ng((5, 1), [Cổng dịch vụ,\ web, tài liệu]),
  edge((0, 0), (1, 0), "-|>"),
  edge((1, 0), (2, 0), "-|>"),
  edge((2, 0), (3, 0), "-|>"),
  edge((3, 0), (4, 0.5), "-|>"),
  edge((3, 1), (4, 0.5), "-|>"),
  edge((4, 0.5), (5, 0), "-|>"),
  edge((5, 0), (5, 1), "-|>", text(size: 8pt)[xong mới cuộn]),
)

Về mức độ xác thực của phần triển khai, cần nói rõ: kho ô dù chứa đầy đủ tệp khai báo cho mô hình nêu trên, nhưng trong phạm vi khảo sát phục vụ báo cáo này chưa thu thập được bằng chứng về một cụm Kubernetes đang vận hành — không có kết xuất trạng thái cụm, không có ảnh chụp bảng điều khiển Argo CD và không có địa chỉ dịch vụ nào được kiểm chứng là đang phục vụ. Do đó phần này được trình bày như *cấu hình triển khai đã chuẩn bị*, không phải như một hệ thống đã vận hành ổn định trên môi trường sản xuất.

== Kết quả hiện thực

Tổng kết lại, kết quả hiện thực của đề tài gồm ba sản phẩm phần mềm chạy được và một bộ cấu hình triển khai.

#figure(
  kind: table,
  caption: [Tổng hợp kết quả hiện thực],
  table(
    columns: (1.35fr, 2.15fr),
    align: (left + top, left + top),
    table.header([Hạng mục], [Kết quả]),
    [Dịch vụ nền], [7 dịch vụ nghiệp vụ trên 7 lược đồ Postgres riêng; 48 627 dòng mã sản xuất và 30 482 dòng mã kiểm thử; 22 tệp di trú],
    [Hợp đồng API], [135 đường dẫn, 171 thao tác, 235 lược đồ dữ liệu, hợp nhất từ 36 mảnh đặc tả; 1 kênh thời gian thực với 8 loại thông điệp],
    [Tệp nhị phân công cụ], [6 chương trình: cổng dịch vụ, di trú, nạp dữ liệu mẫu, sinh vector, sinh đặc tả, sinh đặc tả rút gọn],
    [Ứng dụng web], [52 trang trên 4 vùng chức năng, 58 thành phần dùng lại, 34 109 dòng mã viết tay],
    [Ứng dụng di động], [11 tính năng, 40 tuyến đường, 41 394 dòng mã viết tay, 6 092 dòng mã kiểm thử],
    [Tích hợp bên ngoài], [8 seam; 6 seam đã có máy khách của nhà cung cấp bên ngoài, kiểm thử bằng máy chủ giả và chưa có bằng chứng gọi thật; seam lưu trữ dùng hệ tệp của chính cổng dịch vụ; seam vận chuyển mới có bản giả lập. 21 kịch bản, phần lớn là kịch bản hỏng, trên hai bản giả lập trọng yếu],
    [Quan trắc], [4 tín hiệu đo, 2 khung nhìn tổng hợp liên tục, 1 bảng điều khiển 6 khung hình, đường nhật ký riêng qua kho nhật ký],
    [Tích hợp liên tục], [6 luồng công việc trên 3 kho; kiểm thử tự động chỉ có ở kho ứng dụng di động],
    [Triển khai], [Ảnh chứa cho 3 thành phần, cấu hình GitOps hoàn chỉnh, chưa có bằng chứng vận hành trên cụm],
  ),
)

Bên cạnh những gì đã làm được, có sáu hạn chế cần ghi nhận đúng mức ngay tại chương này. Thứ nhất, seam vận chuyển chưa có hiện thực của hãng thật, và sáu seam còn lại tuy đã có máy khách hoàn chỉnh nhưng chưa seam nào để lại bằng chứng của một lời gọi tới dịch vụ thật, nên toàn bộ phần giao tiếp với thế giới bên ngoài hiện mới được kiểm chứng ở mức bộ giả lập. Thứ hai, bộ kiểm tra tĩnh đầy đủ của kho dịch vụ nền chưa chạy được do vênh phiên bản công cụ, khiến cổng chất lượng tĩnh thực tế mỏng hơn thiết kế. Thứ ba, kho ứng dụng web chưa có một bài kiểm thử tự động nào, dù thư viện kiểm thử đầu cuối đã được cài đặt sẵn. Thứ tư, dây chuyền tích hợp liên tục của hai kho server và website chưa chạy kiểm thử, nên chất lượng của hai kho này hiện phụ thuộc vào việc chạy công cụ thủ công. Thứ năm, các tệp di trú chỉ đi theo chiều tiến: không có tệp lùi và chưa có quy trình kiểm thử khôi phục, nên một lần di trú sai hiện chưa có đường quay lại đã được diễn tập. Thứ sáu, mô hình triển khai mới tồn tại dưới dạng cấu hình khai báo; chưa thu thập được bằng chứng nào về một cụm đang vận hành. Sáu hạn chế này được phân tích kỹ hơn cùng với kết quả kiểm thử ở Chương 6.

== Kế hoạch thực hiện và quản lý rủi ro

Mục này trình bày phần hoạch định đứng sau những kết quả vừa nêu: khối lượng công việc được phân rã thế nào, ước lượng và xếp lịch ra sao, chuỗi công việc nào không được phép chậm, và những rủi ro nào đã được nhận diện từ đầu kỳ cùng với việc chúng có thực sự xảy ra hay không. Toàn bộ kế hoạch chịu một ràng buộc cứng không thương lượng được: một nhóm ba người trong mười bốn tuần, trong đó sáu tuần đầu dành cho khảo sát, phân tích và thiết kế, còn tám tuần sau dành cho hiện thực, kiểm thử và hoàn thiện báo cáo. Vì thời gian là hằng số, mọi rủi ro trong mục cuối đều quy về một câu hỏi duy nhất: nếu điều này xảy ra thì cắt cái gì.

=== Cấu trúc phân rã công việc

Công việc được phân rã theo ba cấp. Cấp một là gói công việc, ứng với một sản phẩm bàn giao nhìn thấy được — một bộ tài liệu, một dịch vụ nghiệp vụ, một ứng dụng khách, một dây chuyền. Cấp hai là công việc thành phần, được giữ trong khoảng một đến năm ngày-người để còn ước lượng và theo dõi được; một công việc kéo dài quá năm ngày là một công việc mà tiến độ thật của nó chỉ được biết vào đúng lúc nó xong, tức là quá muộn để làm gì. Cấp ba không được lập bảng mà nằm trong hàng chờ công việc hằng tuần, bởi ở mức một lớp hay một câu truy vấn, danh sách sẽ cũ nhanh hơn tốc độ cập nhật nó.

Nguyên tắc cắt đối với các dịch vụ nền là cắt theo *khối tổng hợp nghiệp vụ* chứ không theo tầng kỹ thuật. Một công việc mang tên "khối tổng hợp tài khoản" bao trọn thực thể miền, giao diện kho dữ liệu, bộ điều hợp SQL, tệp di trú, bộ xử lý HTTP, mảnh đặc tả và kiểm thử đơn vị của chính nó; nếu cắt theo tầng thì bốn công việc rời rạc sẽ cùng chờ nhau và không công việc nào một mình bàn giao được thứ gì chạy được. Hệ quả trực tiếp là kiểm thử ở mức đơn vị nằm *bên trong* công việc hiện thực chứ không phải một việc làm sau, còn kiểm thử tích hợp, đo hiệu năng và đối chiếu yêu cầu phi chức năng được tách thành gói riêng vì chúng cắt ngang nhiều dịch vụ và cần cả hệ thống đứng dậy trước đã. Ba loại công việc hay bị bỏ sót khỏi một bản phân rã đều được đưa vào bảng ở dạng gói độc lập thay vì gộp ngầm vào việc lập trình: công việc cơ sở dữ liệu, công việc hạ tầng và công việc tài liệu.

#figure(
  kind: table,
  caption: [Cấu trúc phân rã công việc của kỳ thực tập, kèm ước lượng theo ngày-người],
  table(
    columns: (0.42fr, 2.15fr, 0.44fr, 0.72fr, 0.4fr),
    align: (left + top, left + top, right + top, left + top, left + top),
    table.header([Mã], [Gói công việc và công việc thành phần], [Ngày-người], [Kỹ năng], [Tuần]),

    [*CV-1*], [*Nghiên cứu và phân tích yêu cầu*], [*20*], [Phân tích], [1–4],
    [1.1], [Khảo sát bối cảnh và phân tích các sàn giao dịch tiêu biểu], [5], [Phân tích], [1],
    [1.2], [Nghiên cứu kiến trúc dịch vụ, thực thi bền vững, tìm kiếm ngữ nghĩa], [5], [Kiến trúc], [1–3],
    [1.3], [Tác nhân, danh mục ca sử dụng và bộ quy tắc nghiệp vụ], [5], [Phân tích], [3],
    [1.4], [Ban hành bộ yêu cầu, ma trận CRUD và ma trận truy xuất], [5], [Phân tích], [3–4],

    [*CV-2*], [*Thiết kế hệ thống*], [*22*], [Kiến trúc], [4–6],
    [2.1], [Phân rã miền nghiệp vụ và kiến trúc tổng thể], [5], [Kiến trúc], [4],
    [2.2], [Giao tiếp liên dịch vụ và trục sự kiện bất đồng bộ], [4], [Kiến trúc], [4–5],
    [2.3], [Sơ đồ lớp, ma trận trách nhiệm và danh mục giao diện lập trình], [5], [Kiến trúc], [5],
    [2.4], [Mô hình dữ liệu ý niệm và vật lý cho bảy lược đồ], [5], [Dữ liệu], [5–6],
    [2.5], [Thiết kế bảo mật, thuật toán nghiệp vụ và chiến lược xử lý lỗi], [3], [Kiến trúc], [6],

    [*CV-3*], [*Nền tảng kỹ thuật dùng chung*], [*12*], [Dịch vụ nền], [7],
    [3.1], [Khung dịch vụ, điểm hợp thành phụ thuộc và tài liệu cấu hình], [4], [Dịch vụ nền], [7],
    [3.2], [Bộ dùng chung: lớp truy cập dữ liệu, nhật ký kiểm toán, tài nguyên, tuỳ chọn], [3], [Dịch vụ nền], [7],
    [3.3], [Tiến trình di trú bảy đích và bộ tệp di trú dùng chung], [2], [Dữ liệu], [7],
    [3.4], [Môi trường phát triển bằng Docker Compose với sáu hồ sơ chạy], [3], [DevOps], [7],

    [*CV-4*], [*Dịch vụ quản lý tài khoản*], [*17*], [Dịch vụ nền], [7–9],
    [4.1], [Khối tổng hợp tài khoản và cơ chế ghi có kiểm soát phiên bản], [5], [Dịch vụ nền], [7–8],
    [4.2], [Phiên đăng nhập trên bộ nhớ đệm, vé truy cập, thu hồi theo kỷ nguyên], [4], [Dịch vụ nền], [8],
    [4.3], [Liên hệ, thiết bị, thông báo và hồ sơ xác minh danh tính], [5], [Dịch vụ nền], [8–9],
    [4.4], [Bộ xử lý 41 đường dẫn, mảnh đặc tả và kiểm thử đơn vị], [3], [Dịch vụ nền], [9],

    [*CV-5*], [*Dịch vụ danh mục sản phẩm và tìm kiếm*], [*16*], [Dịch vụ nền], [7–9],
    [5.1], [Cây danh mục, tin đăng, biến thể, nhãn và vòng đời tồn kho], [5], [Dịch vụ nền], [7–8],
    [5.2], [Tìm kiếm lai: vector ngữ nghĩa và tìm gần đúng theo chuỗi ký tự], [4], [Dữ liệu], [8],
    [5.3], [Hàng đợi đánh dấu dữ liệu cũ và tiến trình sinh vector], [4], [Dịch vụ nền], [8–9],
    [5.4], [Gợi ý điền biểu mẫu đăng bán bằng mô hình ngôn ngữ], [3], [Dịch vụ nền], [9],

    [*CV-6*], [*Dịch vụ tài chính*], [*14*], [Dịch vụ nền], [8–10],
    [6.1], [Phiên thanh toán và sổ cái giao dịch], [4], [Dịch vụ nền], [8–9],
    [6.2], [Ba thao tác ký quỹ và bút toán ba chân], [4], [Dịch vụ nền], [9–10],
    [6.3], [Ví, tài khoản ngân hàng, thông tin thuế và lệnh rút tiền], [3], [Dịch vụ nền], [10],
    [6.4], [Lời gọi ngược quyết toán của hai kênh thanh toán], [3], [Dịch vụ nền], [10],

    [*CV-7*], [*Dịch vụ đơn hàng*], [*21*], [Dịch vụ nền], [8–11],
    [7.1], [Giỏ hàng, bản nháp thanh toán và cơ chế giành quyền mua], [5], [Dịch vụ nền], [8–9],
    [7.2], [Đề nghị giá, thương lượng và hạn hiệu lực của điều khoản], [4], [Dịch vụ nền], [9–10],
    [7.3], [Báo giá vận chuyển, đặt vận đơn và ghi nhận mốc hành trình], [4], [Dịch vụ nền], [10–11],
    [7.4], [Bốn luồng thực thi bền vững và tiến trình quét định kỳ], [4], [Dịch vụ nền], [11],
    [7.5], [Hoàn tiền, khiếu nại và phán quyết của điều phối viên], [4], [Dịch vụ nền], [11],

    [*CV-8*], [*Dịch vụ trò chuyện, tín nhiệm và quan trắc*], [*15*], [Dịch vụ nền], [9–11],
    [8.1], [Hội thoại, tin nhắn và kênh thời gian thực], [4], [Dịch vụ nền], [9–10],
    [8.2], [Ẩn danh quầy hỗ trợ trên mọi hình chiếu của một tin nhắn], [3], [Dịch vụ nền], [10],
    [8.3], [Đánh giá mù, điểm uy tín và bảng phiếu hỗ trợ gộp], [5], [Dịch vụ nền], [10–11],
    [8.4], [Bốn tín hiệu đo và hai khung nhìn tổng hợp liên tục], [3], [Dịch vụ nền], [11],

    [*CV-9*], [*Ứng dụng web*], [*19*], [Web], [9–12],
    [9.1], [Khung tuyến đường, bốn vùng chức năng và tầng trung gian bảo vệ], [3], [Web], [9],
    [9.2], [Sinh lớp gọi API, lớp trạng thái và kênh thời gian thực], [3], [Web], [9–10],
    [9.3], [Luồng mua hàng: tìm kiếm, chi tiết sản phẩm, giỏ hàng], [4], [Web], [10–11],
    [9.4], [Thanh toán, theo dõi đơn, hoàn tiền và hộp thư trò chuyện], [4], [Web], [11–12],
    [9.5], [Khu vực quản trị: mười một mục nghiệp vụ], [5], [Web], [11–12],

    [*CV-10*], [*Ứng dụng di động*], [*19*], [Di động], [10–13],
    [10.1], [Hạ tầng lõi: mạng, định tuyến, lưu trữ cục bộ, thời gian thực], [4], [Di động], [10],
    [10.2], [Sáu tính năng phía người mua trên bốn mươi tuyến đường], [6], [Di động], [10–12],
    [10.3], [Năm tính năng còn lại: người bán, tài khoản, xác minh, phiếu, trợ giúp], [5], [Di động], [12–13],
    [10.4], [Kiểm thử tiện ích và kiểm thử đơn vị], [4], [Di động], [13],

    [*CV-11*], [*Tích hợp nhà cung cấp bên ngoài và bản giả lập*], [*12*], [Dịch vụ nền], [9–12],
    [11.1], [Tám seam: giao diện, sổ đăng ký và bộ chọn trong cấu hình], [3], [Kiến trúc], [9],
    [11.2], [Máy khách của sáu nhà cung cấp bên ngoài], [5], [Dịch vụ nền], [11–12],
    [11.3], [Hai bản giả lập trọng yếu với 21 kịch bản và trang điều khiển], [4], [Dịch vụ nền], [9–12],

    [*CV-12*], [*Tích hợp liên tục và triển khai*], [*7*], [DevOps], [12],
    [12.1], [Sáu luồng công việc tích hợp liên tục trên ba kho], [3], [DevOps], [12],
    [12.2], [Ảnh chứa nhiều tầng cho ba thành phần], [2], [DevOps], [12],
    [12.3], [Cấu hình triển khai khai báo và mô hình GitOps], [2], [DevOps], [12],

    [*CV-13*], [*Kiểm thử và đánh giá*], [*12*], [Kiểm thử], [13–14],
    [13.1], [Bộ kiểm thử đơn vị và tích hợp của dịch vụ nền], [5], [Kiểm thử], [13],
    [13.2], [Đo hiệu năng ở hai mức đồng thời], [4], [Kiểm thử], [13–14],
    [13.3], [Đối chiếu mức đáp ứng yêu cầu phi chức năng], [3], [Kiểm thử], [14],

    [*CV-14*], [*Tổng hợp và hoàn thiện báo cáo*], [*4*], [Cả nhóm], [14],

    [], [*Tổng cộng*], [*210*], [], [],
  ),
)

Tổng ước lượng là 210 ngày-người, đúng bằng năng lực danh nghĩa của ba người trong mười bốn tuần, nghĩa là kế hoạch không có đệm ở cấp toàn dự án — điều này được ghi nhận như một rủi ro chứ không được coi là một kế hoạch chặt chẽ. Phân bổ theo giai đoạn cho thấy phân tích và thiết kế chiếm bốn mươi hai ngày-người, tức khoảng một phần năm tổng công sức, hiện thực bảy dịch vụ nền, hai ứng dụng khách và các seam tích hợp chiếm một trăm bốn mươi lăm ngày-người, phần còn lại là hai mươi ba ngày-người dành cho triển khai, kiểm thử và báo cáo. Phân bổ theo kỹ năng cho thấy công việc phía dịch vụ nền nặng hơn hai ứng dụng khách cộng lại, đúng với tỉ lệ mã nguồn đo được ở mục quy mô mã nguồn.

=== Ước lượng và lịch biểu

Ước lượng được lập bằng phương pháp tương tự đối với những công việc có tiền lệ trong chính kỳ này — một bộ điều hợp SQL thứ năm được ước lượng theo bốn bộ đã viết — và bằng ba điểm đối với những công việc không có tiền lệ, tức là ước lượng riêng cho tình huống thuận lợi, tình huống thường gặp và tình huống xấu rồi lấy trung bình có trọng số. Bốn công việc được ước lượng theo cách thứ hai vì chúng chứa phần lớn cái chưa biết của đề tài: tìm kiếm lai, thực thi bền vững có hẹn giờ, ký quỹ ba chân và lời gọi ngược của kênh thanh toán. Phần chênh giữa tình huống xấu và tình huống thường gặp được giữ lại thành một khoản đệm ở cấp gói chứ không rải vào từng công việc thành phần, vì một khoản đệm gắn liền với công việc thì bao giờ cũng bị tiêu hết. Ước lượng được xem lại vào cuối mỗi vòng lặp hai tuần, và một công việc vượt quá ước lượng của nó hơn một nửa thì được tách nhỏ chứ không được gia hạn, bởi vượt nhiều đến thế thường có nghĩa là công việc đó đang chứa một công việc khác chưa được đặt tên.

Lịch biểu chia mười bốn tuần thành bảy vòng lặp hai tuần. Ba vòng đầu là phân tích và thiết kế, kết thúc bằng hai mốc bàn giao: bộ yêu cầu chức năng và phi chức năng được ban hành ở cuối tuần thứ ba, hồ sơ thiết kế cùng mô hình dữ liệu bảy lược đồ được chốt ở cuối tuần thứ sáu. Vòng thứ tư dựng nền tảng kỹ thuật dùng chung rồi khởi động hai dịch vụ không phụ thuộc ai là tài khoản và danh mục. Vòng thứ năm là vòng nặng nhất vì luồng tiền được hiện thực ở đây, đồng thời ba dịch vụ ngoài luồng tiền được làm song song. Vòng thứ sáu khép kín luồng mua hàng trên hai ứng dụng khách và dựng dây chuyền tích hợp liên tục cùng cấu hình triển khai. Vòng cuối dành cho kiểm thử, đo hiệu năng và báo cáo. Bốn mốc bàn giao còn lại lần lượt là: bảy lược đồ đã di trú và hai dịch vụ đầu tiên phục vụ được giao diện lập trình, ở cuối tuần thứ chín; luồng tiền khép kín trên bản giả lập — thanh toán, đơn hàng ra đời, ký quỹ, đặt vận đơn — ở cuối tuần thứ mười một; hai ứng dụng khách chạy được luồng mua hàng cùng dây chuyền dựng ảnh, ở cuối tuần thứ mười hai; và báo cáo kiểm thử cùng kết quả đo hiệu năng, ở cuối tuần thứ mười bốn.

Quan hệ phụ thuộc giữa các gói phần lớn là hiển nhiên: nền tảng kỹ thuật dùng chung phải xong trước mọi dịch vụ vì cả bảy dịch vụ đều lấy bảng nhật ký kiểm toán, bảng tài nguyên và tiến trình di trú từ đó; dịch vụ tài khoản đứng trước mọi thứ cần một chủ thể; dịch vụ danh mục đứng trước dịch vụ đơn hàng vì không có tin đăng thì không có gì để mua. Một quan hệ không hiển nhiên và đã phải xử lý riêng là quan hệ giữa đơn hàng và tài chính: đơn hàng cần tài chính để mở phiên thanh toán, còn đơn hàng lại chỉ ra đời khi tài chính báo tiền đã về, nên hai gói phụ thuộc hai chiều và không gói nào xếp trước được. Cách gỡ là chốt hợp đồng giữa hai bên trước — hình dạng sự kiện thanh toán thành công và giao diện ký quỹ — rồi để hai gói chạy song song, mỗi bên dựng một bản giả lập của bên kia cho tới khi cả hai gặp nhau ở cuối tuần thứ mười.

#fig(
  [Đường găng của kế hoạch hiện thực, đi xuyên qua luồng tiền],
  spacing: (30mm, 13mm),
  ncore((0, 0), [Nền tảng\ dùng chung\ (T7)]),
  ncore((1, 0), [Tài khoản:\ định danh, phiên\ (T7–8)]),
  ncore((2, 0), [Danh mục:\ tin đăng, tồn kho\ (T8)]),
  ncore((3, 0), [Đơn hàng:\ giành quyền mua\ (T9)]),
  ncore((3, 1), [Tài chính:\ phiên thanh toán\ (T9–10)]),
  ncore((2, 1), [Lời gọi ngược\ quyết toán\ (T10)]),
  ncore((1, 1), [Đơn hàng ra đời\ và ký quỹ\ (T10–11)]),
  ncore((0, 1), [Báo giá và\ đặt vận đơn\ (T11)]),
  ncore((0, 2), [Giao diện thanh toán\ hai ứng dụng khách\ (T11–12)]),
  ncore((1, 2), [Kiểm thử và\ đo hiệu năng\ (T13–14)]),
  np((3, 2), [Song song, ngoài\ đường găng: trò chuyện,\ tín nhiệm, quan trắc]),
  edge((0, 0), (1, 0), "-|>"),
  edge((1, 0), (2, 0), "-|>"),
  edge((2, 0), (3, 0), "-|>"),
  edge((3, 0), (3, 1), "-|>"),
  edge((3, 1), (2, 1), "-|>"),
  edge((2, 1), (1, 1), "-|>"),
  edge((1, 1), (0, 1), "-|>"),
  edge((0, 1), (0, 2), "-|>"),
  edge((0, 2), (1, 2), "-|>"),
)

Đường găng của đề tài đi xuyên qua luồng tiền, và điều đó là hệ quả trực tiếp của một quyết định nghiệp vụ đã nêu ở mục dịch vụ đơn hàng: người bán không duyệt đơn, chính dòng tiền tạo ra đơn. Vì đơn hàng chỉ tồn tại sau khi kênh thanh toán báo về, mọi thứ đứng sau đơn hàng — ký quỹ, đặt vận đơn, theo dõi hành trình, hoàn tiền, đánh giá sau giao dịch, và cả hai màn hình thanh toán của hai ứng dụng khách — đều không thể chạy thử đầu-cuối trước khi mắt xích ấy thông. Chuỗi này dài đúng bằng phần thời gian còn lại của kỳ, nghĩa là nó gần như không có độ trễ cho phép: chậm một tuần ở bất kỳ mắt nào cũng đẩy thẳng vào hai tuần kiểm thử cuối cùng.

Hai hệ quả được rút ra ngay từ lúc lập lịch. Thứ nhất, bản giả lập của kênh thanh toán được kéo lên sớm hơn hẳn gói tích hợp nhà cung cấp mà nó vốn thuộc về, vì không có nó thì mắt xích quyết toán chỉ chạy được khi một nhà cung cấp thật sẵn sàng, mà đó lại là thứ nhóm không kiểm soát; cũng vì vậy mà bản giả lập được đầu tư tới mức có một trang điều khiển cho người vận hành thay vì chỉ trả về kết quả cố định. Thứ hai, mọi việc *không* nằm trên chuỗi ấy đều được xếp song song để lấp năng lực: ba dịch vụ trò chuyện, tín nhiệm và quan trắc không đứng giữa tiền và đơn nên chạy suốt các tuần chín tới mười một; khu vực quản trị của ứng dụng web chỉ phụ thuộc vào giao diện lập trình đã công bố nên không phải chờ luồng mua hàng; và ứng dụng di động khởi động ở tuần thứ mười trên nền lớp gọi API sinh sẵn, không chờ dịch vụ nền hoàn tất.

Đối chiếu với thực tế cuối kỳ, lịch biểu giữ được ở phần lõi nhưng lệch ở phần rìa. Luồng tiền thông đúng mốc, và đó là điều kiện đủ để hai ứng dụng khách và các dịch vụ phía sau về đích. Ngược lại, những việc được xếp ở cuối và không có ai đứng sau chờ đã bị dồn hoặc bị cắt: phép đo hiệu năng chỉ chạy được ở hai tuần cuối nên các phát hiện của nó chỉ kịp trở thành hướng khắc phục, việc bổ sung bước kiểm thử vào dây chuyền của hai kho vẫn nằm trong hàng chờ, và việc tích hợp một hãng vận chuyển thật không bao giờ được bắt đầu. Đây là dạng lệch lịch điển hình khi kế hoạch không có đệm ở cấp dự án: phần bị hy sinh không phải là phần ít quan trọng nhất mà là phần không có công việc nào phụ thuộc vào nó.

=== Sổ đăng ký rủi ro

Sổ đăng ký rủi ro được lập ở tuần thứ tư, ngay sau khi kiến trúc tổng thể chốt, và được rà soát vào cuối mỗi vòng lặp hai tuần. Mỗi rủi ro được gán cho người sở hữu gói công việc mà nó đe doạ, vì người ấy là người duy nhất phát hiện được nó đang xảy ra trước khi nó xảy ra xong. Khả năng và tác động được chấm theo ba mức, và điểm rủi ro là tích của hai đại lượng đó; những rủi ro đạt mức cao ở cả hai chiều được yêu cầu có thêm phương án dự phòng, tức một câu trả lời cho tình huống biện pháp ứng phó không hiệu quả.

Cột cuối cùng của bảng ghi trạng thái thực tế tại thời điểm chốt báo cáo, và nó là phần đáng đọc nhất: một sổ rủi ro mà cuối kỳ không rủi ro nào xảy ra là một sổ rủi ro được viết lại sau khi mọi việc đã yên.

#figure(
  kind: table,
  caption: [Sổ đăng ký rủi ro hiện thực và trạng thái thực tế cuối kỳ],
  table(
    columns: (0.46fr, 1.22fr, 0.38fr, 0.38fr, 1.45fr, 1.02fr),
    align: (left + top, left + top, left + top, left + top, left + top, left + top),
    table.header([Mã], [Rủi ro], [Khả năng], [Tác động], [Biện pháp ứng phó đã dự liệu], [Trạng thái cuối kỳ]),

    [RR-01], [Bộ công cụ phân tích tĩnh mở rộng không theo kịp phiên bản ngôn ngữ đích], [Cao], [Trung bình], [Giữ nguyên tệp cấu hình để chạy lại được ngay khi công cụ bắt kịp; dùng công cụ tiêu chuẩn đi kèm bộ dịch làm cổng tối thiểu; bù bằng danh mục rà soát mã], [*Đã xảy ra.* Cổng chất lượng tĩnh thực tế của kho dịch vụ nền hiện chỉ còn công cụ tiêu chuẩn],

    [RR-02], [Không kịp tiếp cận và tích hợp một hãng vận chuyển thật trong kỳ], [Trung bình], [Cao], [Đặt seam vận chuyển sau một sổ đăng ký để thêm hãng chỉ là thêm một hiện thực; đầu tư bản giả lập đủ mười một kịch bản để toàn bộ nghiệp vụ phía trên vẫn kiểm chứng được], [*Đã xảy ra.* Nghiệp vụ vận chuyển hoàn chỉnh nhưng chưa có hiện thực của hãng thật nào],

    [RR-03], [Không thu được bằng chứng của một lời gọi thật tới bất kỳ nhà cung cấp nào], [Trung bình], [Trung bình], [Viết máy khách theo tài liệu nhà cung cấp và kiểm chứng bằng máy chủ HTTP giả dựng ngay trong ca kiểm thử], [*Đã xảy ra.* Sáu seam dừng ở mức kiểm thử bằng máy chủ giả],

    [RR-04], [Kiểm thử tầng truy cập dữ liệu cần cơ sở dữ liệu thật nên không vào được dây chuyền tự động], [Cao], [Trung bình], [Tách nhóm này bằng thẻ biên dịch để bộ kiểm thử mặc định chạy được ở mọi nơi; chạy tay trên máy phát triển trước mỗi mốc bàn giao], [*Đã xảy ra.* 93 hàm kiểm thử hiện bị bỏ qua hoàn toàn],

    [RR-05], [Dây chuyền tích hợp liên tục của kho dịch vụ nền và kho web không chạy kiểm thử], [Cao], [Cao], [Ưu tiên cổng chống lệch đặc tả vì nó chặn được lỗi lan sang hai ứng dụng khách; xếp việc bổ sung bước kiểm thử vào hàng chờ ngay sau khi luồng tiền thông], [*Đã xảy ra.* Chỉ kho ứng dụng di động chạy kiểm thử tự động trên mỗi lần đẩy mã],

    [RR-06], [Kho ứng dụng web không kịp có bài kiểm thử tự động nào], [Trung bình], [Trung bình], [Cài sẵn thư viện kiểm thử đầu cuối để việc bắt đầu không tốn thêm bước dựng môi trường; dựa vào chế độ kiểm tra kiểu chặt làm lưới an toàn tạm thời], [*Đã xảy ra.* Kho web chưa có bài kiểm thử tự động nào],

    [RR-07], [Không dựng được cụm để chứng minh mô hình triển khai đã thiết kế], [Trung bình], [Trung bình], [Mô tả toàn bộ triển khai dưới dạng khai báo trong một kho riêng, để việc dựng cụm về sau không phải làm lại phần thiết kế], [*Đã xảy ra.* Chỉ có cấu hình khai báo, chưa có bằng chứng vận hành],

    [RR-08], [Một lần di trú sai không có đường quay lại đã được diễn tập], [Thấp], [Cao], [Chỉ áp di trú bằng một tiến trình riêng, không bao giờ áp lúc khởi động ứng dụng; sao lưu trước mỗi lần áp trên môi trường dùng chung], [*Đã xảy ra một phần.* Chưa có tệp di trú lùi và chưa diễn tập khôi phục; chưa có sự cố nào],

    [RR-09], [Đo hiệu năng dồn vào cuối kỳ, không còn thời gian sửa nếu phát hiện điểm nghẽn], [Cao], [Trung bình], [Chuẩn bị hạ tầng quan trắc ngay trong giai đoạn hiện thực để tới lúc đo chỉ còn là việc chạy], [*Đã xảy ra.* Phép đo chạy ở hai tuần cuối; các phát hiện chỉ kịp ghi thành hướng khắc phục],

    [RR-10], [Không có nghiệm thu của người dùng ngoài nhóm phát triển], [Trung bình], [Trung bình], [Dựng máy chủ giả lập toàn bộ hợp đồng từ sớm để giao diện có thể được xem thử trước khi dịch vụ nền hoàn tất], [*Đã xảy ra.* Chưa có kiểm thử chấp nhận nào với người dùng thật],

    [RR-11], [Sai sót trong luồng tiền: thanh toán hai lần, quyết toán trùng, khoản ký quỹ không hạch toán được], [Trung bình], [Rất cao], [Giành quyền mua trước khi mở phiên thanh toán; ràng buộc duy nhất ở cơ sở dữ liệu đứng sau mọi lối vào; bản giả lập tái hiện được cả báo trùng lẫn báo sai số tiền], [Không xảy ra. Các kịch bản đối kháng đều bị chặn ở mức kiểm thử thành phần],

    [RR-12], [Chuyển trạng thái có hẹn giờ phụ thuộc vào một thời gian chạy bên ngoài], [Trung bình], [Cao], [Hai bộ dẫn động cho một định nghĩa: luồng bền vững gọi đúng phương thức mà tiến trình quét định kỳ cũng gọi, nên tắt thời gian chạy vẫn là một cấu hình hợp lệ], [Không xảy ra. Hệ thống chạy được ở cả hai chế độ],

    [RR-13], [Hợp đồng giao diện lập trình lệch giữa dịch vụ nền và hai ứng dụng khách], [Cao], [Trung bình], [Sinh lớp gọi ở hai kho khách từ chính đặc tả; đặt một cổng tự động so đặc tả sinh lại với đặc tả đã lưu, khác biệt làm hỏng bản dựng], [Không xảy ra. Đây là cổng tự động duy nhất của kho dịch vụ nền và nó đã làm đúng việc],

    [RR-14], [Dịch vụ sinh vector không sẵn sàng hoặc trả về vector sai số chiều], [Trung bình], [Trung bình], [Kiểm tra số chiều của mọi câu trả lời và dừng ngay khi lệch; tìm kiếm lùi về tìm gần đúng theo chuỗi khi tin đăng chưa có vector], [Không xảy ra. Việc không chạy tiến trình sinh vector vẫn là một cấu hình triển khai hợp lệ],

    [RR-15], [Nhóm ba người, phần lớn đường găng do một người nắm], [Trung bình], [Cao], [Giữ bảy dịch vụ cùng một bố cục và cùng một cách công bố hợp đồng để người khác đọc vào không phải học lại; xếp các gói ngoài đường găng chồng tuần để còn chỗ hoán đổi], [Không xảy ra. Nhưng đây là rủi ro duy nhất không có phương án dự phòng thật sự],

  ),
)

Mười trong mười lăm rủi ro đã thành hiện thực, trong đó một ở mức một phần. Điều đáng nói không phải là con số mà là chỗ chúng dồn về: cả mười đều thuộc hai nhóm — cưỡng chế chất lượng bằng công cụ tự động, và chạm được vào dịch vụ thật bên ngoài — trong khi năm rủi ro thuộc phần nghiệp vụ lõi thì không rủi ro nào xảy ra. Cách đọc trung thực của phân bố ấy là: những gì nhóm kiểm soát được bằng thiết kế thì đã được kiểm soát, còn những gì phụ thuộc vào một bên thứ ba, một phiên bản công cụ hay một khoảng thời gian không co lại được thì phần lớn đã trượt. Nó cũng cho thấy giới hạn của chính cách ứng phó đã chọn: dựng một bản giả lập đủ tốt để nghiệp vụ vẫn kiểm chứng được là một biện pháp giảm nhẹ hiệu quả, nhưng nó giảm nhẹ *hậu quả* của việc thiếu nhà cung cấp thật chứ không thay thế được nhà cung cấp thật, và ranh giới đó phải được giữ rõ trong mọi phát biểu về kết quả của đề tài.

== Tiểu kết chương

Chương 5 đã trình bày toàn bộ quá trình biến thiết kế ở Chương 4 thành phần mềm chạy được. Về công nghệ, hệ thống được hiện thực bằng Go cho dịch vụ nền, Next.js cho ứng dụng web và Flutter cho ứng dụng di động, đặt trên nền PostgreSQL kèm TimescaleDB, Redis, NATS JetStream và Restate, với toàn bộ hạ tầng phát triển được mô tả bằng Docker Compose thành sáu hồ sơ chạy phục vụ sáu tình huống công việc khác nhau.

Về tiêu chuẩn phát triển, chương đã xác lập một bộ quy ước đặt tên theo từng ngôn ngữ, một chiều phụ thuộc nghiêm ngặt trong mỗi dịch vụ, các quy tắc chất lượng có thể kiểm tra được bằng phép thử thay vì bằng ngưỡng số không đo được, cùng bốn nguyên tắc bảo mật và một nhóm quy tắc hiệu năng xoay quanh phân trang theo con trỏ, truy vấn viết tay và dữ liệu chuỗi thời gian. Chương cũng chỉ rõ những chỗ mà bộ tiêu chuẩn ấy hiện chưa được công cụ hoá đầy đủ.

Về kết quả, bảy dịch vụ nghiệp vụ đã được hiện thực trên bảy lược đồ dữ liệu độc lập, công bố 171 thao tác API và một kênh thời gian thực; hai ứng dụng khách sinh lớp gọi API từ chính đặc tả đó nên hợp đồng luôn là nguồn sự thật duy nhất; tám seam tích hợp cô lập mọi phụ thuộc bên ngoài, trong đó sáu seam đã có máy khách viết theo tài liệu của nhà cung cấp bên ngoài và được kiểm thử bằng máy chủ giả — chưa seam nào để lại bằng chứng của một lời gọi tới dịch vụ thật — còn seam lưu trữ tệp hiện dùng chính hệ tệp của cổng dịch vụ và seam vận chuyển mới có bản giả lập; dây chuyền dựng ảnh và mô hình triển khai GitOps đã được chuẩn bị đầy đủ dưới dạng khai báo. Tổng khối lượng mã viết tay của ba kho là hơn 160 nghìn dòng.

Những kết quả này là đầu vào trực tiếp cho Chương 6, nơi trình bày chiến lược kiểm thử, kết quả chạy thực tế của các bộ kiểm thử tự động, và đánh giá mức độ đáp ứng của hệ thống so với bộ yêu cầu phi chức năng đã đặt ra ở Chương 3 — bao gồm cả việc chỉ ra những yêu cầu mà hiện trạng chưa đủ bằng chứng để kết luận.
