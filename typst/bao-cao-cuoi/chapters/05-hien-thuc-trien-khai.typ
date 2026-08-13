#import "../../common/tokens.typ": *

= HIỆN THỰC VÀ TRIỂN KHAI

== Hiện thực dịch vụ nền

Các dịch vụ được tổ chức theo cùng một cấu trúc thư mục và cơ chế công bố hợp đồng API, qua đó bảo đảm tính nhất quán và thuận tiện trong quá trình phát triển, bảo trì hệ thống. Việc cô lập dữ liệu (data isolation) được thực hiện theo mô hình Database-per-service, trong đó mỗi dịch vụ quản lý độc lập dữ liệu thuộc phạm vi nghiệp vụ của mình.

Các quyết định thiết kế và kỹ thuật hiện thực chính cho từng miền nghiệp vụ được trình bày như sau:

=== Dịch vụ Tài khoản, Định danh và Xác thực (Account Service)

Aggregate root của dịch vụ là `Account`, bao gồm thông tin định danh (email, số điện thoại, tên đăng nhập), hồ sơ hiển thị và danh sách liên kết nhà cung cấp OAuth. Hệ thống có bốn vai trò: `user`, `moderator`, `admin` và `support`. Không có vai trò `seller` riêng, một tài khoản có thể vừa mua vừa bán, quyết định này nhằm giảm ma sát gia nhập nền tảng.

Thao tác lưu trữ được định nghĩa qua interface `Repository` trong gói `port`, tách biệt khỏi bộ điều hợp PostgreSQL và Redis. Tách biệt này cho phép kiểm thử toàn bộ tầng dịch vụ qua kho giả lập mà không cần cơ sở dữ liệu thực.

Mỗi thao tác thay đổi trạng thái trên aggregate như đổi email, cấp vai trò, tạm khóa, liên kết hay hủy liên kết OAuth hay ghi một sự kiện có kiểu tĩnh vào danh sách nội bộ. Khi `Repository.Save` thực thi, các sự kiện này được ghi vào bảng `audit_log` trong cùng giao dịch cơ sở dữ liệu, bảo đảm nhật ký kiểm toán khớp với trạng thái bản ghi.

Dịch vụ tài khoản đăng ký nhận sự kiện `OrderPlaced` và `OrderSettled` từ dịch vụ đơn hàng, sau đó tạo thông báo trong hộp thư thời gian thực cho cả người mua lẫn người bán. Dịch vụ đơn hàng không cần biết ai nhận thông báo hay bằng cơ chế nào.


=== Dịch vụ Danh mục và Tìm kiếm (Catalog Service)

Aggregate root của dịch vụ là `Listing`, một tin đăng bán hàng do một người bán tạo ra, gồm thông tin mô tả, tập biến thể kèm số lượng tồn và danh sách thẻ. Dịch vụ quản lý tồn kho trực tiếp thay vì tách thành một dịch vụ riêng, nhằm tránh giao dịch phân tán khi đặt giữ hàng.

Tin đăng hỗ trợ hai chế độ giá: cố định (`fixed`) và thương lượng (`negotiable`). Mọi tin đăng mới công bố và mọi bản sửa đổi đều chuyển về trạng thái `pending` chờ kiểm duyệt trước khi hiển thị công khai, trạng thái `active` và trạng thái bị gỡ bởi điều phối viên (`hidden`) được phân biệt với trạng thái người bán tự ẩn.

Tìm kiếm hoạt động theo cơ chế hybrid search: một tiến trình nền quét các bản ghi có cờ thay đổi, gọi mô hình sinh vector embedding rồi xóa cờ trong cùng giao dịch. Khi bản ghi chưa có vector, truy vấn fallback về lexical match, bảo đảm tính sẵn sàng ngay cả khi module AI gặp sự cố.

=== Dịch vụ Đơn hàng và Thương lượng (Order Service)

Đơn hàng không được tạo từ yêu cầu trực tiếp của người mua, mà từ sự kiện xác nhận thanh toán thành công phát ra bởi dịch vụ tài chính. Thiết kế này loại bỏ bài toán đồng bộ trạng thái giữa phiên thanh toán và đơn hàng: đơn chỉ tồn tại khi tiền đã vào ký quỹ.

Vòng đời đơn hàng được quản lý bằng Restate thay vì cron job. Mỗi đơn hàng là một workflow instance với các promise tương ứng từng mốc: người bán xác nhận (`confirmed`), người mua xác nhận nhận hàng (`received`), hồ sơ hoàn tiền (`refund-raised`) và kết quả phân xử (`refund-resolved`). Restate ghi journal từng bước và từng bộ đếm thời gian, nên khi máy chủ khởi động lại, workflow tiếp tục từ vị trí đã dừng mà không tính lại đồng hồ.

Khi người bán không xác nhận đơn trong 48 giờ, hệ thống leo thang thông báo cho bộ phận vận hành nhưng giữ nguyên trạng thái đơn, nền tảng không tự hủy đơn cũng không gửi hàng thay người bán.

=== Dịch vụ Tài chính và Ký quỹ (Finance Service)

Dịch vụ đóng vai trò sổ cái nội bộ. Mỗi biến động tài chính được ghi là một `Movement` có trường `Seq` (thứ tự trong ví), `Kind` (loại bút toán) và `IdempotencyKey` (khóa lũy đẳng). Hai khoản tiền hàng và phí vận chuyển được tách thành hai chặng riêng ngay khi vào ký quỹ, do có quy tắc hoàn trả khác nhau: tiền hàng có thể được hoàn theo kết quả giao dịch, còn phí vận chuyển đã phát sinh không thuộc phạm vi hoàn trả.

Kết quả thanh toán chỉ được ghi nhận từ webhook của nhà cung cấp, không từ trang đích mà người dùng được chuyển hướng về. Mọi thao tác ghi số dư từ webhook đều idempotent thông qua `IdempotencyKey`: nếu nhà cung cấp gửi lại thông báo do nghẽn mạng, bút toán trùng thua vào ràng buộc duy nhất ở cơ sở dữ liệu thay vì sinh ra số dư kép.

=== Dịch vụ Trò chuyện và Tín nhiệm (Chat & Trust Services)

Dịch vụ trò chuyện quản lý hai loại luồng: hội thoại mua bán trực tiếp giữa hai tài khoản và luồng tin nhắn của phiếu hỗ trợ. Thông báo realtime được đẩy qua fanout với nguyên tắc best-effort: lỗi gửi realtime không làm thất bại lệnh ghi, và phía client đồng bộ lại khi kết nối trở lại.

Dịch vụ tín nhiệm quản lý phiếu hỗ trợ, đánh giá sản phẩm và phản hồi của người bán. Phiếu hỗ trợ dùng chung một luồng tin nhắn với dịch vụ trò chuyện, nhưng danh tính của điều phối viên xử lý phiếu được ẩn danh hóa ở mọi hình chiếu dữ liệu, bao gồm cả dòng tin nhắn xem trước trong danh sách hộp thư.

=== Quan trắc vận hành (Observability)

Dịch vụ thu thập bốn loại tín hiệu vận hành: lưu lượng HTTP vào (`http_requests`), lời gọi ra nhà cung cấp bên ngoài (`provider_calls`), sự kiện nghiệp vụ từ event bus (`business_events`) và số đo thời gian chạy Go (`runtime_metrics`). Mỗi tín hiệu được publish lên JetStream thông qua một `Sink` riêng; một writer tiêu thụ các topic này theo batch và ghi vào TimescaleDB.

Thiết kế tách đường ghi telemetry khỏi đường xử lý yêu cầu: `Sink.publish` dùng `context.Background` thay vì context của request, nên một request bị hủy vẫn ghi lại được chính nó. Lỗi gửi lên bus không làm thất bại lệnh ghi mà chỉ tăng bộ đếm mẫu bị mất (`dropped`), được báo cáo định kỳ cùng với chu kỳ lấy mẫu runtime.

#pagebreak()
== Hiện thực ứng dụng web

Ứng dụng web được phát triển dựa trên kiến trúc App Router của Next.js. Hệ thống định tuyến được chia thành 4 phân hệ chính: vùng công khai, vùng xác thực, vùng người dùng đã đăng nhập và vùng quản trị. Cơ chế bảo vệ tuyến đường (route guard) được thực thi qua Middleware nhằm tối ưu trải nghiệm điều hướng, trong khi hàng rào bảo mật (security boundary) thực sự vẫn do các dịch vụ nền kiểm soát thông qua xác thực token trên từng yêu cầu API.


Các hình ảnh minh hoạ giao diện dưới đây được trích xuất trực tiếp từ môi trường chạy thử của ứng dụng:
#figure(
  assets("web/web-01-tim-kiem.png", width: 86%),
  caption: [Trang kết quả tìm kiếm với từ khoá tiếng Việt không dấu "ao thun nam"; rail bộ lọc bên trái cố định trên khung nhìn desktop, dải "cách khớp" cho chọn giữa khớp từ khoá, khớp ngữ nghĩa hay kết hợp cả 2],
)

Trang tìm kiếm (Hình 5.1) thể hiện kết quả truy vấn. Bộ lọc cho phép tinh chỉnh theo danh mục, nhãn dán, khoảng cách địa lý, giá và tình trạng sản phẩm.

#figure(
  assets("web/web-04-thanh-toan.png", height: 17cm),
  caption: [Trang thanh toán sau khi địa chỉ nhận đã được chọn sẵn: danh sách phương án vận chuyển kèm cước, danh sách kênh thanh toán, bảng tổng tiền tách bạch tiền hàng với cước. Mọi mục mang tiền tố "Mock" là kịch bản của bản giả lập, không phải hãng vận chuyển hay kênh thanh toán thật],
)

Trang thanh toán (Hình 5.2) hỗ trợ hai luồng nghiệp vụ: mua giá niêm yết và đàm phán thành công. Biểu phí vận chuyển và tổng tiền được máy chủ tính toán động dựa trên địa chỉ mặc định. Để phục vụ kiểm thử, môi trường hiện tại tích hợp các kịch bản giả lập (Mock) bên cạnh hai cổng thanh toán thực tế là SePay và Stripe, đảm bảo khả năng mô phỏng toàn diện luồng giao dịch.

#figure(
  assets("web/web-05-theo-doi-don.png", width: 90%),
  caption: [Chi tiết một đơn ở trạng thái đã giao và đang chờ người mua xác nhận: dải tiến trình 4 chặng, thông tin vận đơn, bảng tách tiền hàng với cước, hai lối đi tiếp là xác nhận đã nhận hàng hoặc mở yêu cầu hoàn tiền],
)

Trang chi tiết đơn hàng (Hình 5.3), dải tiến trình giao hàng phản ánh trạng thái vận đơn theo thời gian thực. Trạng thái đã giao vẫn được xếp vào nhóm đang xử lý do khoản tiền tiếp tục được giữ trong Ký quỹ cho đến khi người mua xác nhận nhận hàng hoặc hết thời hạn bảo lưu. Thời gian đếm ngược của Ký quỹ hiện chỉ được hiển thị trên giao diện người bán.

#figure(
  assets("web/web-06-hoan-tien.png", width: 90%),
  caption: [Chi tiết một yêu cầu hoàn tiền đang chờ người bán xem xét, nhìn từ tài khoản người bán: trạng thái vụ việc, thời hạn phản hồi còn lại, lý do và ảnh bằng chứng người mua đính kèm, cùng hai lối đi tiếp là chấp nhận hoàn tiền hoặc đưa vụ việc lên bộ phận vận hành],
)

Giao diện khiếu nại được thiết kế hướng hành động (action-oriented), hiển thị rõ chủ thể chịu trách nhiệm xử lý bước tiếp theo thay vì chỉ thể hiện trạng thái thụ động. Quản lý phân quyền nút thao tác linh hoạt theo vai trò và vòng đời vụ việc, ví dụ quyền nâng cấp thành phiếu hỗ trợ chỉ được kích hoạt cho người bán trong thời hạn phản hồi.


== Hiện thực ứng dụng di động

Ứng dụng di động được tổ chức theo kiến trúc hướng tính năng (Feature-Driven Architecture) với 11 module nghiệp vụ độc lập. Mỗi module đóng gói các thành phần giao diện và truy cập dữ liệu liên quan, thay vì phân tách toàn hệ thống theo các tầng kỹ thuật, qua đó tăng tính cô lập và thuận tiện trong bảo trì. Với các phân hệ có quy tắc nghiệp vụ phức tạp, như quy trình hoàn tiền, hệ thống bổ sung lớp miền (domain layer) để quản lý riêng các ràng buộc và trạng thái xử lý.

#anh-mobile(
  [Trang chủ và trung tâm tài khoản],
  ("mobile-01-trang-chu.png", "mobile-02-trung-tam-tai-khoan.png"),
  nhan: (
    "bảng tin gợi ý và thanh điều hướng dưới cùng",
    "trung tâm tài khoản: lối vào kênh người bán, đơn hàng và ví",
  ),
)

Giao diện trang chủ (Hình 5.5) hiển thị bảng tin gợi ý sản phẩm. Trung tâm tài khoản đóng vai trò cổng điều hướng chính đến các phân hệ quản lý đơn hàng, ví tiền và kênh người bán.

#anh-mobile(
  [Giao diện đăng bán sản phẩm],
  ("mobile-03-dang-ban-tren.png", "mobile-04-dang-ban-duoi.png"),
  nhan: (
    "phần đầu biểu mẫu, kèm lối nhờ mô hình ngôn ngữ điền giúp",
    "phần dưới của cùng biểu mẫu",
  ),
)

Biểu mẫu đăng bán (Hình 5.6) hỗ trợ tự động điền thông tin thông qua tích hợp mô hình ngôn ngữ lớn. Hệ thống tự động trích xuất các thuộc tính cốt lõi của sản phẩm từ văn bản mô tả, giúp giảm thao tác nhập liệu thủ công cho người bán.

#anh-mobile(
  [Giao diện thanh toán trên ứng dụng di động],
  ("mobile-11-checkout-van-chuyen.png", "mobile-12-checkout-thanh-toan.png",
   "mobile-13-checkout-tong-tien.png"),
  nhan: (
    "chọn đơn vị vận chuyển",
    "chọn kênh thanh toán",
    "bảng tổng tiền tách tiền hàng với cước",
  ),
  cao: 8.6cm,
)

Màn hình thanh toán (Hình 5.7) cung cấp tùy chọn đơn vị vận chuyển và kênh thanh toán. Tương tự ứng dụng web, phí vận chuyển được tính toán động, và máy khách di động nhúng WebView để bảo đảm an toàn cho dữ liệu thanh toán thay vì xử lý trực tiếp.




== Tích hợp nhà cung cấp bên ngoài

Toàn bộ logic giao tiếp với bên thứ ba được cô lập tại một phân hệ tích hợp độc lập nhằm tuân thủ nguyên lý đảo ngược phụ thuộc (Dependency Inversion). Phân hệ này định nghĩa 8 cổng giao tiếp (port), mỗi cổng cung cấp một giao diện (interface) hẹp và các bộ điều hợp (adapter) tương ứng. Thiết kế này bảo đảm mã nghiệp vụ không bị ràng buộc vào công nghệ hay đặc tả API của nhà cung cấp cụ thể.

Việc lựa chọn nhà cung cấp được nạp động ở thời điểm khởi động thông qua tệp cấu hình hoặc sổ đăng ký (registry). Trừ dịch vụ lưu trữ ghi trực tiếp xuống hệ tệp cục bộ, 7 phân hệ còn lại đều cung cấp sẵn bộ điều hợp giả lập (Mock) để phục vụ kiểm thử và môi trường phát triển nội bộ.

#figure(
  kind: table,
  caption: [Danh mục các phân hệ tích hợp bên ngoài],
  table(
    columns: (1fr, 1.8fr),
    align: (left + top, left + top),

    table.header(
      [Phân hệ],
      [Thành phần tích hợp],
    ),

    [Sinh vector], [Mô hình embedding bge-m3 self-host],
    [Xác minh danh tính], [Bản giả lập],
    [Mô hình ngôn ngữ], [Proxy LiteLLM],
    [Thông báo], [SMTP (Email)],
    [Đăng nhập liên kết], [OIDC (Google)],
    [Thanh toán], [SePay.vn, Stripe môi trường Sandbox],
    [Lưu trữ tệp], [MinIO Object Storage],
    [Vận chuyển], [GHTK, GHN],
  ),
)

Các bộ điều hợp được lập trình bám sát tài liệu API của đối tác, bao gồm cơ chế mã hóa, chữ ký số và xử lý lỗi. Hệ thống có các ca kiểm thử tự động cho phân hệ tích hợp. Do giới hạn của môi trường triển khai, các kết nối như bên vận chuyển được kiểm định thông qua máy chủ HTTP giả lập nội bộ (mock server) hoặc phát lại lời gọi ngược (webhook replay) thay vì kết nối trực tiếp đến API của nhà cung cấp.

== Quy trình tích hợp và triển khai liên tục (CI/CD)

Hệ thống CI/CD được thiết lập nhằm tự động hóa quy trình kiểm định và đóng gói mã nguồn dịch vụ nền. Các luồng công việc (workflows) được cấu hình chạy độc lập dựa trên các sự kiện vòng đời của mã nguồn.

#figure(
  kind: table,
  caption: [Các luồng công việc tích hợp liên tục của kho dịch vụ nền],
  table(
    columns: (1.1fr, 1fr, 1.8fr),
    align: (left + top, left + top, left + top),
    table.header([Luồng công việc], [Điều kiện kích hoạt], [Quy trình thực thi]),
    [Đóng gói và Phát hành (Build & Push)], [Mã được gộp vào nhánh chính], [Biên dịch mã nguồn, đóng gói thành ảnh chứa (container image), gán nhãn định danh và đẩy lên kho lưu trữ ảnh (Container Registry).],
    [Kiểm định đặc tả API (API Spec Check)], [Mở yêu cầu gộp (Pull Request)], [Tự động sinh tài liệu OpenAPI từ mã nguồn và so sánh với tệp đặc tả đã cam kết; sai lệch sẽ đánh dấu lỗi tiến trình.],
  ),
)

== Kết quả hiện thực

Quá trình hiện thực hoá hệ thống đã hoàn thiện các hạng mục kỹ thuật cốt lõi. Tuy nhiên, trong khuôn khổ đồ án, hệ thống vẫn tồn tại 5 hạn chế kỹ thuật chưa được giải quyết triệt để:
+ *Tích hợp bên thứ ba:* 5 seam có máy khách của nhà cung cấp thật đều mới chỉ dừng ở mức đã viết xong và kiểm thử bằng máy chủ HTTP giả dựng ngay trong ca kiểm thử; chưa có lời gọi nào chạm tới môi trường Sandbox hay Production của đối tác, nên cũng chưa có đối soát giao dịch thật. 3 seam còn lại thì chưa có cả bản hiện thực của một nhà cung cấp thật: xác minh danh tính và vận chuyển mới chỉ có bản giả lập, lưu trữ tệp mới chỉ ghi xuống hệ tệp cục bộ.
+ *Tự động hóa CI/CD:* Chuỗi tích hợp liên tục của kho mã nguồn máy chủ (server) hiện chưa bao gồm bước chạy kiểm thử tự động, buộc phải kiểm định thủ công trước khi phát hành; kho này mới có cổng chống lệch đặc tả API và bước dựng ảnh chứa.
+ *Kiểm thử tầng truy cập dữ liệu:* Các bài kiểm thử cần một cơ sở dữ liệu thật được tách sau một nhãn biên dịch riêng nên không nằm trong bộ kiểm thử mặc định. Vì không có dây chuyền nào chạy chúng, một phần đã lệch khỏi mã miền tới mức không còn biên dịch được.
+ *Quản trị cơ sở dữ liệu:* Các tập lệnh di trú (migration) chỉ hỗ trợ chiều tiến (up/forward). Hệ thống thiếu các tệp lùi (down/rollback) và chưa có quy trình kiểm thử khôi phục dữ liệu (disaster recovery).
+ *Bằng chứng vận hành:* Hệ thống mới chỉ được dựng và chạy trong môi trường phát triển đóng gói bằng Docker Compose. Chưa có lần vận hành nào trên môi trường thật với người dùng thật, nên chưa thu được số liệu tải, thời gian hoạt động hay nhật ký sự cố để dẫn ra trong báo cáo.



== Tổ chức công việc và quản lý rủi ro
=== Chiến lược tổ chức và phân rã công việc

- *Phân rã theo khối nghiệp vụ (Business Capability):* Công việc được chia theo khối tổng hợp (VD: Tài khoản, Đơn hàng) thay vì cắt ngang theo tầng kỹ thuật. Một hạng mục công việc bao trọn từ thực thể CSDL, API đến kiểm thử đơn vị, đảm bảo mỗi khối khi hoàn thành đều là một đơn vị bàn giao có khả năng hoạt động độc lập (Deliverable Increment).
- *Phát triển xoay quanh luồng tiền (Money-driven Sequence):* Do quyết định kiến trúc "dòng tiền tạo ra đơn hàng", trình tự phát triển bắt buộc bám sát luồng thanh toán. Nền tảng lõi được dựng trước, tiếp nối bởi Tài khoản, Danh mục, Đơn hàng và Tài chính. Bộ giả lập thanh toán được triển khai sớm nhất để khơi thông luồng kiểm thử toàn trình (End-to-End).

=== Quản lý rủi ro

Sổ đăng ký rủi ro (Risk Register) được thiết lập ngay từ giai đoạn thiết kế, phân bổ trách nhiệm cụ thể và rà soát định kỳ. Bảng dưới đây trình bày 7 rủi ro đã thực sự xảy ra và chiến lược ứng phó. Trạng thái cuối kỳ phản ánh trung thực mức độ ảnh hưởng và các thỏa hiệp kỹ thuật buộc phải chấp nhận để hệ thống về đích đúng tiến độ.


#figure(
  kind: table,
  caption: [Sổ đăng ký rủi ro hiện thực và trạng thái thực tế cuối kỳ],
  table(
    columns: (0.5fr, 1.3fr, 0.36fr, 1.2fr, 1.05fr),
    align: (left + top, left + top, center + top, left + top, left + top),
    table.header([Mã], [Rủi ro], [Tác động], [Biện pháp ứng phó], [Trạng thái cuối]),

    [RR-01], [Bộ phân tích tĩnh mở rộng không theo kịp phiên bản ngôn ngữ đích], [T. bình], [Giữ tệp cấu hình để chạy lại ngay khi công cụ bắt kịp; dùng công cụ tiêu chuẩn làm cổng tối thiểu], [*Đã xảy ra.* Cổng chất lượng tĩnh chỉ còn công cụ tiêu chuẩn],

    [RR-02], [Không kịp tích hợp một hãng vận chuyển thật trong kỳ], [Cao], [Đặt seam sau một sổ đăng ký để thêm hãng chỉ là thêm một hiện thực; bản giả lập đủ 11 kịch bản], [*Đã xảy ra.* Nghiệp vụ hoàn chỉnh nhưng chưa có hiện thực của hãng thật nào],

    [RR-03], [Không thu được bằng chứng của một lời gọi thật tới nhà cung cấp nào], [T. bình], [Viết máy khách theo tài liệu và kiểm chứng bằng máy chủ HTTP giả dựng ngay trong ca kiểm thử], [*Đã xảy ra.* 6 seam có máy khách của nhà cung cấp thật đều dừng ở mức kiểm thử bằng máy chủ giả, không có nhật ký giao dịch thật nào],

    [RR-04], [Kiểm thử tầng truy cập dữ liệu cần cơ sở dữ liệu thật nên không vào được dây chuyền tự động], [T. bình], [Tách bằng thẻ biên dịch để bộ kiểm thử mặc định chạy được ở mọi nơi; chạy tay trước mỗi mốc], [*Đã xảy ra, nặng hơn dự liệu.* 113 hàm kiểm thử bị bỏ qua hoàn toàn, và 17 trong số đó đã lệch khỏi mã miền tới mức không còn biên dịch được],

    [RR-05], [Dây chuyền tích hợp liên tục của kho dịch vụ nền không chạy kiểm thử], [Cao], [Ưu tiên cổng chống lệch đặc tả vì nó chặn lỗi lan sang 2 ứng dụng khách], [*Đã xảy ra.* Dây chuyền của kho dịch vụ nền chưa chạy kiểm thử tự động],

    [RR-06], [Không chứng minh được hệ thống chạy ngoài môi trường phát triển], [T. bình], [Đóng gói toàn bộ hệ thống để dựng lại bằng một câu lệnh, và phát hành ảnh chứa tối giản chạy dưới quyền non-root], [*Đã xảy ra.* Chỉ có bằng chứng chạy trên môi trường phát triển],

    [RR-07], [Một lần di trú sai không có đường quay lại đã được diễn tập], [Cao], [Chỉ áp di trú bằng một tiến trình riêng; sao lưu trước mỗi lần áp], [*Đã xảy ra một phần.* Chưa có tệp di trú lùi và chưa diễn tập khôi phục; chưa có sự cố nào],

  ),
)