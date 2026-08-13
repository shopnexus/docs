#import "../../common/tokens.typ": *

= HIỆN THỰC VÀ TRIỂN KHAI

== Hiện thực dịch vụ nền

Các dịch vụ dùng chung một bố cục thư mục và một cách công bố hợp đồng API, giúp đảm bảo tính nhất quán và giảm chi phí bảo trì hệ thống. Tính cô lập dữ liệu (data isolation) được thực thi triệt để thông qua mô hình Database-per-service.

Dưới đây là các quyết định và kỹ thuật hiện thực chi tiết nhằm giải quyết bài toán cốt lõi tại từng miền nghiệp vụ:

=== Quản lý Định danh và Phiên truy cập (Account Service)
Điểm nhấn kỹ thuật của dịch vụ này nằm ở mô hình quản lý phiên (session) lai. Access token là một JSON Web Token (JWT) không trạng thái (stateless) có vòng đời 15 phút, trong khi phiên đăng nhập thực tế là một bản ghi mang trạng thái (stateful) lưu trữ tại Redis tồn tại 30 ngày. Bộ lọc xác thực tra cứu phiên trên mọi yêu cầu API; cơ chế này đảm bảo các thao tác đăng xuất, đổi mật khẩu hay khoá tài khoản lập tức có hiệu lực ngay cả khi JWT ở phía máy khách chưa hết hạn. Bài toán thu hồi toàn bộ phiên của một tài khoản được giải quyết với độ phức tạp thời gian $O(1)$ bằng cách tăng giá trị vòng đời (kỷ nguyên - session epoch), khiến chi phí tính toán hoàn toàn không phụ thuộc vào số lượng thiết bị đang đăng nhập.

=== Xử lý Tìm kiếm và Quản lý Tồn kho (Catalog Service)
Dịch vụ danh mục được thiết kế để trực tiếp quản lý trạng thái tồn kho (inventory) thay vì tách thành dịch vụ độc lập, nhằm loại bỏ các giao dịch phân tán (distributed transaction) tốn kém khi đặt giữ hàng. Đối với bài toán tìm kiếm, hệ thống áp dụng cơ chế Tìm kiếm lai (Hybrid Search): một tiến trình nền (background worker) sẽ quét các bản ghi có đánh dấu thay đổi, gọi mô hình sinh vector embedding và xoá cờ cập nhật trong cùng một giao dịch nguyên tử. Trong trường hợp bản ghi mới chưa kịp sinh vector, truy vấn sẽ tự động thoái lui (fallback) về chế độ lexical match truyền thống, đảm bảo tính sẵn sàng cao ngay cả khi module AI gặp sự cố.

=== Máy trạng thái Đơn hàng và Durable execution (Order Service)
Mang khối lượng mã nguồn lớn nhất, dịch vụ đơn hàng được thiết kế theo Kiến trúc Hướng sự kiện (Event-Driven Architecture). Đơn hàng không được sinh ra từ nút bấm "Đặt hàng" của người mua, mà ra đời từ luồng sự kiện xác nhận giao dịch thanh toán thành công, giúp loại bỏ bài toán đồng bộ trạng thái thanh toán và đơn hàng. Để quản lý vòng đời giao dịch dài hạn (chẳng hạn giới hạn 48 giờ chờ xác nhận), hệ thống không sử dụng bộ định thời định kỳ (cron job) truyền thống mà tích hợp Restate để cung cấp cơ chế durable execution. Luồng thời gian chạy này đảm bảo các tiến trình đếm ngược có khả năng chịu lỗi (fault-tolerant) và tự động phục hồi đúng trạng thái trước đó nếu máy chủ khởi động lại.

=== Quản lý Dòng tiền và Ký quỹ (Finance Service)
Dịch vụ tài chính đóng vai trò làm sổ cái (ledger) nội bộ, lưu trữ toàn bộ nguyên thể tiền tệ để đảm bảo các bút toán ký quỹ luôn tuân thủ nguyên tắc ACID. Trong quy trình thanh toán trực tuyến, nguyên tắc bất biến được áp dụng: trang đích mà người dùng được chuyển hướng về sau khi thanh toán không bao giờ được coi là bằng chứng xác nhận. Việc quyết toán chỉ được thực thi thông qua lời gọi ngược (webhook) từ máy chủ của cổng thanh toán. Mọi thao tác cập nhật số dư từ webhook đều được thiết kế idempotent, cho phép nhà cung cấp phát lại thông báo nhiều lần trong trường hợp nghẽn mạng mà không gây ra hiện tượng nhân đôi số dư.

=== Trò chuyện và Quản lý Tín nhiệm (Chat & Trust Services)
Dịch vụ trò chuyện chịu trách nhiệm quản lý cả hội thoại mua bán cá nhân lẫn các luồng tin nhắn của phiếu hỗ trợ khiếu nại. Thách thức lớn nhất tại đây là cơ chế ẩn danh (anonymization) cho điều phối viên; hệ thống phải che dấu danh tính nhân viên ở mọi hình chiếu dữ liệu (bao gồm cả dòng tin nhắn xem trước trong danh sách hộp thư) nhằm bảo vệ an toàn cho Moderator.
== Hiện thực ứng dụng web

Ứng dụng web được phát triển dựa trên kiến trúc App Router của Next.js. Hệ thống định tuyến được chia thành 4 phân hệ chính: vùng công khai, vùng xác thực, vùng người dùng đã đăng nhập và vùng quản trị. Cơ chế bảo vệ tuyến đường (route guard) được thực thi qua Middleware nhằm tối ưu trải nghiệm điều hướng, trong khi hàng rào bảo mật (security boundary) thực sự vẫn do các dịch vụ nền kiểm soát thông qua xác thực token trên từng yêu cầu API.


Các hình ảnh minh hoạ giao diện dưới đây được trích xuất trực tiếp từ môi trường chạy thử của ứng dụng:
Trang tìm kiếm phản ánh trực quan cơ chế truy vấn lai (hybrid search). Bộ lọc đa chiều bao gồm: danh mục, nhãn dán, khu vực (tỉnh/phường kèm bán kính), khoảng giá và tình trạng sản phẩm.
#figure(
  assets("web/web-01-tim-kiem.png", width: 92%),
  caption: [Trang kết quả tìm kiếm với từ khoá tiếng Việt không dấu "ao thun nam"; rail bộ lọc bên trái cố định trên khung nhìn desktop, dải "cách khớp" cho chọn giữa khớp từ khoá, khớp ngữ nghĩa hay kết hợp cả 2],
)

#figure(
  assets("web/web-04-thanh-toan.png", height: 17cm),
  caption: [Trang thanh toán sau khi địa chỉ nhận đã được chọn sẵn: danh sách phương án vận chuyển kèm cước, danh sách kênh thanh toán, bảng tổng tiền tách bạch tiền hàng với cước. Mọi mục mang tiền tố "Mock" là kịch bản của bản giả lập, không phải hãng vận chuyển hay kênh thanh toán thật],
)

Trang thanh toán hợp nhất 2 luồng nghiệp vụ: mua giá niêm yết và đàm phán thành công. Biểu phí vận chuyển và tổng tiền được máy chủ tính toán động dựa trên địa chỉ mặc định. Để phục vụ kiểm thử, môi trường hiện tại tích hợp các kịch bản giả lập (Mock) bên cạnh hai cổng thanh toán thực tế là SePay và Stripe, đảm bảo khả năng mô phỏng toàn diện luồng giao dịch.

#figure(
  assets("web/web-05-theo-doi-don.png", width: 90%),
  caption: [Chi tiết một đơn ở trạng thái đã giao và đang chờ người mua xác nhận: dải tiến trình 4 chặng, thông tin vận đơn, bảng tách tiền hàng với cước, hai lối đi tiếp là xác nhận đã nhận hàng hoặc mở yêu cầu hoàn tiền],
)

Dải tiến trình giao hàng phản ánh trạng thái vận đơn thực tế theo thời gian thực. Trạng thái "đã giao" được phân loại vào nhóm xử lý thay vì hoàn tất, bởi dòng tiền vẫn nằm trong sổ cái Ký quỹ cho đến khi người mua xác nhận hoặc hết thời hạn bảo lưu. Việc đếm ngược thời hạn Ký quỹ hiện tại chỉ khả dụng trên giao diện của người bán.

#figure(
  assets("web/web-06-hoan-tien.png", width: 90%),
  caption: [Chi tiết một yêu cầu hoàn tiền đang chờ người bán xem xét, nhìn từ tài khoản người bán: trạng thái vụ việc, thời hạn phản hồi còn lại, lý do và ảnh bằng chứng người mua đính kèm, cùng hai lối đi tiếp là chấp nhận hoàn tiền hoặc đưa vụ việc lên bộ phận vận hành],
)

Giao diện khiếu nại được thiết kế hướng hành động (action-oriented), hiển thị rõ chủ thể chịu trách nhiệm xử lý bước tiếp theo thay vì chỉ thể hiện trạng thái thụ động. Quản lý phân quyền nút thao tác linh hoạt theo vai trò và vòng đời vụ việc, ví dụ quyền nâng cấp thành phiếu hỗ trợ chỉ được kích hoạt cho người bán trong thời hạn phản hồi.


== Hiện thực ứng dụng di động

Ứng dụng di động được thiết kế theo Kiến trúc Hướng tính năng (Feature-Driven Architecture), phân chia thành 11 module nghiệp vụ độc lập. Thay vì phân mảnh theo tầng kỹ thuật (technical layers), mỗi module tự đóng gói lớp trình bày (presentation layer) và lớp dữ liệu (data layer), giúp tăng tính liền mạch và dễ bảo trì. Các phân hệ chứa quy tắc nghiệp vụ phức tạp, điển hình như quy trình hồ sơ hoàn tiền, được bổ sung thêm lớp miền (domain layer) nhằm quản lý độc lập các ràng buộc về thời hạn xử lý.

Hạ tầng kỹ thuật nền tảng được tập trung tại module lõi (core). Lớp giao tiếp mạng sử dụng máy khách HTTP tích hợp sẵn bộ đánh chặn (interceptor), tự động đính kèm và làm mới access token mà không can thiệp vào mã nghiệp vụ. Trạng thái phiên và dữ liệu đệm được quản lý qua kho lưu trữ cục bộ, song song với một bộ định tuyến (router) điều phối 40 tuyến đường phân cấp. Đối với nghiệp vụ thanh toán, hệ thống áp dụng cơ chế nhúng khung duyệt web (WebView) mở trực tiếp trang thanh toán an toàn. Cách tiếp cận này tuân thủ nguyên tắc bảo mật từ dịch vụ tài chính: máy khách chỉ chuyển hướng luồng thao tác và lắng nghe trạng thái phiên giao dịch từ máy chủ thông qua giao thức thời gian thực, tuyệt đối không sử dụng hành vi quay về ứng dụng (deep link return) làm bằng chứng xác nhận thanh toán.


#anh-mobile(
  [Trang chủ và trung tâm tài khoản trên ứng dụng di động],
  ("mobile-01-trang-chu.png", "mobile-02-trung-tam-tai-khoan.png"),
  nhan: (
    "bảng tin gợi ý và thanh điều hướng dưới cùng",
    "trung tâm tài khoản: lối vào kênh người bán, đơn hàng và ví",
  ),
)

#anh-mobile(
  [Luồng đăng bán sản phẩm với gợi ý điền biểu mẫu],
  ("mobile-03-dang-ban-tren.png", "mobile-04-dang-ban-duoi.png"),
  nhan: (
    "phần đầu biểu mẫu, kèm lối nhờ mô hình ngôn ngữ điền giúp",
    "phần dưới của cùng biểu mẫu",
  ),
)



#anh-mobile(
  [Màn hình thanh toán trên di động, 3 đoạn cuộn của cùng một màn hình],
  ("mobile-11-checkout-van-chuyen.png", "mobile-12-checkout-thanh-toan.png",
   "mobile-13-checkout-tong-tien.png"),
  nhan: (
    "chọn đơn vị vận chuyển",
    "chọn kênh thanh toán",
    "bảng tổng tiền tách tiền hàng với cước",
  ),
  cao: 8.6cm,
)




== Tích hợp các nhà cung cấp bên ngoài

Toàn bộ logic giao tiếp với các dịch vụ bên thứ ba (Third-party services) được cô lập vào một phân hệ tích hợp độc lập. Phân hệ này được tổ chức thành 8 đường nối (seam) kiến trúc, mỗi seam là một gói mã riêng định nghĩa một giao diện (interface) hẹp kèm theo các bản hiện thực (implementation) tương ứng; riêng seam thông báo gộp hai kênh gửi thư và gửi tin nhắn sau cùng một giao diện, mỗi kênh có bộ chọn nhà cung cấp của riêng nó. Bảy trong 8 seam có sẵn một bản hiện thực giả lập (Mock) phục vụ kiểm thử và chạy thử cục bộ; riêng seam lưu trữ tệp không có bản giả lập riêng vì bản hiện thực ghi thẳng xuống hệ tệp cục bộ đã đảm nhiệm đúng vai trò đó.

#figure(
  kind: table,
  caption: [Bảng liệt kê toàn bộ nhà cung cấp bên ngoài],
  table(
    columns: (0.62fr, 1.15fr, 0.9fr, 0.95fr),
    align: (left + top, left + top, left + top, left + top),
    table.header([Seam], [Nhà cung cấp đã hiện thực], [Cách chọn], [Hiện trạng]),
    [Sinh vector], [Dịch vụ bge-m3 tự vận hành; Bản giả lập], [Bộ chọn trong tệp cấu hình], [Máy khách đã viết xong, kiểm bằng máy chủ HTTP giả; chưa gọi dịch vụ thật],
    [Xác minh danh tính], [chỉ Bản giả lập], [Bộ chọn trong tệp cấu hình], [Máy khách đã viết xong, kiểm bằng máy chủ HTTP giả; chưa gọi dịch vụ thật],
    [Mô hình ngôn ngữ], [Proxy LiteLLM theo giao diện OpenAI; Bản giả lập], [Bộ chọn trong tệp cấu hình], [Máy khách đã viết xong, kiểm bằng máy chủ HTTP giả; chưa gọi dịch vụ thật],
    [Thông báo], [SMTP (Email); Bản giả lập], [Hai bộ chọn trong tệp cấu hình], [Cả 2 máy khách đã viết xong; eSMS kiểm bằng máy chủ HTTP giả, SMTP kiểm ở mức thông điệp dựng ra; chưa gửi thư hay tin nhắn thật],
    [Đăng nhập liên kết], [Xác thực OIDC (Google, Apple); Bản giả lập], [Bộ chọn trong tệp cấu hình], [Máy khách đã viết xong, kiểm bằng máy chủ HTTP giả; chưa xác thực với nhà cung cấp thật],
    [Thanh toán], [SePay.vn, Stripe; Bản giả lập], [Sổ đăng ký (Registry)], [Cả 2 máy khách đã viết xong; Stripe kiểm bằng máy chủ HTTP giả, SePay kiểm bằng cách phát lại lời gọi ngược đã ký; chưa có giao dịch thật],
    [Lưu trữ tệp], [Hệ tệp cục bộ (HMAC); Nguồn ngoài chỉ đọc], [Bộ chọn cho nơi ghi, sổ đăng ký cho các nguồn đọc], [Lưu trữ nội bộ đã viết xong và chạy được; chưa tích hợp Object Storage đám mây],
    [Vận chuyển], [*Chỉ có Bản giả lập*], [Sổ đăng ký (Registry)], [*Kiến trúc lõi đã viết xong và chạy được với bản giả lập; chưa có bản hiện thực của hãng vận chuyển thật nào*],
  ),
)

Về trạng thái hiện thực, máy khách (client) của 5 seam đã được lập trình bám sát tài liệu API chính thức, bao gồm đầy đủ cơ chế xử lý lỗi, mã hóa chữ ký số và định dạng dữ liệu. Toàn phân hệ tích hợp hiện có 115 hàm kiểm thử đơn vị, trong đó 80 hàm thuộc 5 seam vừa nói. Phần lớn các hàm ấy dựng một máy chủ HTTP giả ngay trong ca kiểm thử để phát lại phản hồi của nhà cung cấp; hai trường hợp còn lại được kiểm theo cách khác vì bản chất giao thức: máy khách SMTP được kiểm ở mức thông điệp mà nó dựng ra, còn máy khách SePay vốn không gọi ra ngoài (nó chỉ ký một biểu mẫu chuyển hướng và xác thực lời gọi ngược) nên được kiểm bằng cách phát lại chính lời gọi ngược đó vào bộ xử lý webhook. Tuy nhiên, tính đến thời điểm báo cáo, hệ thống chưa thực hiện kết nối trực tiếp đến môi trường Sandbox hay Production của bất kỳ nhà cung cấp thực tế nào: không có nhật ký giao dịch hay mã tham chiếu nào từ eSMS.vn, SePay hay Stripe để dẫn ra ở đây.



== Quy trình tích hợp và triển khai liên tục (CI/CD)

#figure(
  kind: table,
  caption: [Các luồng công việc tích hợp liên tục của kho dịch vụ nền],
  table(
    columns: (0.9fr, 0.9fr, 1.7fr),
    align: (left + top, left + top, left + top),
    table.header([Luồng công việc], [Kích hoạt bởi], [Các bước thực hiện]),
    [Dựng và đẩy ảnh], [Đẩy mã lên nhánh chính], [Dựng ảnh chứa chỉ định rõ tầng phát hành, đẩy lên kho ảnh kèm hai nhãn, rồi thông báo cho kho tài liệu],
    [Kiểm tra đặc tả API], [Đẩy mã và mở yêu cầu gộp], [Sinh lại đặc tả rồi so sánh; khác biệt làm hỏng bản dựng],
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