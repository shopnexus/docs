#import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line, font-head
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge
#import fletcher.shapes: pill

= KHÁI NIỆM VÀ KIẾN TRÚC HƯỚNG DỊCH VỤ

== Các khái niệm cơ bản về hướng dịch vụ

*Dịch vụ* (service) là một đơn vị logic nghiệp vụ tự chứa, phơi bày năng lực của
mình qua một *hợp đồng* (contract) công khai và che giấu hoàn toàn chi tiết hiện
thực bên trong. Bên gọi (consumer) chỉ cần biết hợp đồng — đầu vào, đầu ra, ngữ
nghĩa thao tác — mà không cần biết dịch vụ được viết bằng ngôn ngữ gì, dùng cơ sở
dữ liệu nào, hay chạy ở đâu.

*Hướng dịch vụ* (service-orientation) là một tập nguyên lý thiết kế nhằm tạo ra
các dịch vụ có chất lượng cao. Theo Thomas Erl, tám nguyên lý cốt lõi gồm: hợp
đồng dịch vụ chuẩn hóa, lỏng lẻo ràng buộc (loose coupling), trừu tượng hóa, tái
sử dụng, tự trị (autonomy), phi trạng thái (statelessness), khả năng khám phá
(discoverability) và khả năng kết hợp (composability). Bảng dưới đối chiếu các
nguyên lý đó với cách ShopNexus hiện thực:

#table(
  columns: (1fr, 3fr),
  table.header([Nguyên lý hướng dịch vụ], [Hiện thực trong ShopNexus]),
  [Hợp đồng chuẩn hóa (Standardized Contract)], [Mỗi dịch vụ phơi bày một interface Go tường minh (ví dụ `OrderBiz`); API ngoài chuẩn hóa qua REST `/api/v1/...` với envelope phản hồi thống nhất.],
  [Lỏng lẻo ràng buộc (Loose Coupling)], [Dịch vụ A không gọi trực tiếp B; mọi lời gọi đi qua proxy + Restate ingress. Mỗi dịch vụ sở hữu schema PostgreSQL riêng, *không* khóa ngoại xuyên dịch vụ.],
  [Trừu tượng hóa (Abstraction)], [Bên gọi chỉ thấy interface; chi tiết truy vấn, cổng thanh toán, lưu trữ đều bị che.],
  [Tái sử dụng (Reusability)], [Dịch vụ `inventory`, `account`, `catalog` được nhiều luồng (checkout, hoàn tiền, dashboard) dùng lại.],
  [Tự trị (Autonomy)], [Mỗi module kiểm soát dữ liệu và logic của riêng nó; có thể "nhấc" thành deployment riêng mà không sửa code.],
  [Phi trạng thái (Statelessness)], [Handler dịch vụ không giữ trạng thái phiên; trạng thái dài hạn được durable hóa trong journal của Restate.],
  [Khả năng khám phá (Discoverability)], [Dịch vụ tự đăng ký (auto-register) với Restate runtime; runtime định tuyến theo *tên dịch vụ*.],
  [Khả năng kết hợp (Composability)], [Workflow checkout/fulfillment kết hợp nhiều dịch vụ thành một tiến trình nghiệp vụ lớn (service composition).],
)

== Đặc trưng và kiến trúc phần mềm hướng dịch vụ

Kiến trúc hướng dịch vụ (SOA) tổ chức hệ thống thành ba vai trò kinh điển: *nhà
cung cấp dịch vụ* (provider), *bên tiêu thụ dịch vụ* (consumer) và *cơ chế định
tuyến/đăng ký* trung gian. Trong các SOA truyền thống, vai trò trung gian là một
*Enterprise Service Bus* (ESB) hoặc registry UDDI. Trong ShopNexus, vai trò này do
*Restate ingress* đảm nhiệm: nó là điểm hội tụ mọi lời gọi, lo định tuyến theo tên
dịch vụ, bảo đảm bền vững (durable), thử lại (retry) và quan sát (observability).

#diag(
  caption: [Ba vai trò SOA và vai trò trung gian do Restate ingress đảm nhiệm trong ShopNexus],
  diagram(
    spacing: (10mm, 15mm),
    node-stroke: 0.7pt,
    node-corner-radius: 4pt,
    node((0, 0), [Consumer], fill: c-soft, width: 28mm),
    node((2, 0), text(fill: white)[Restate Ingress], fill: c-primary, stroke: none, width: 36mm, inset: 8pt),
    node((4, 0), [Provider], fill: c-soft, width: 34mm),  
    edge((0, 0), (2, 0), "->", [1. call]),
    edge((2, 0), (4, 0), "->", [2. định tuyến], bend: 25deg),
    edge((4, 0), (2, 0), "-->", [3. kết quả], bend: 25deg),
  ),
)

Các đặc trưng quan trọng của kiến trúc này trong ShopNexus:

- *Vị trí trong suốt (location transparency).* Bên gọi chỉ nêu tên dịch vụ; runtime
  định tuyến tới bản thể đang chạy — cùng tiến trình hay deployment riêng, một hay
  N bản sao sau cân bằng tải, nơi gọi không đổi.
- *Giao tiếp qua hợp đồng.* Không dịch vụ nào chạm dữ liệu nội bộ của dịch vụ khác.
- *Bền vững theo mặc định.* Mọi lời gọi đều được ghi journal, áp dụng đồng nhất
  retry và quan sát.

== Các giai đoạn vòng đời dự án phần mềm hướng dịch vụ

Dự án ShopNexus đi qua các giai đoạn điển hình của vòng đời phần mềm hướng dịch vụ,
ánh xạ trực tiếp tới các chương của báo cáo:

#table(
  columns: (auto, 1fr, auto),
  table.header([Giai đoạn], [Nội dung], [Chương]),
  [Phân tích dịch vụ], [Xác định miền con, ứng viên dịch vụ, ranh giới và quan hệ.], [4],
  [Mô hình hóa & thiết kế dịch vụ], [Thiết kế hợp đồng, API, phân tầng nội bộ mỗi dịch vụ.], [3, 5],
  [Phát triển dịch vụ], [Hiện thực logic nghiệp vụ, giao tiếp, giao dịch.], [6, 7, 8],
  [Kiểm thử & tích hợp], [Truy vấn tổng hợp, kiểm thử luồng đầu-cuối.], [9],
  [Triển khai & vận hành], [Đóng gói, phiên bản hóa, giám sát.], [10, 11],
)

== So sánh ba cách tiếp cận: SOAP, REST và Microservice

Học phần tập trung vào ba cách tiếp cận hướng dịch vụ. Bảng dưới so sánh để làm rõ
lựa chọn của ShopNexus:

#table(
  columns: (auto, 1fr, 1fr, 1fr),
  table.header([Tiêu chí], [SOAP], [REST], [Microservice]),
  [Bản chất], [Giao thức nhắn tin dựa trên XML, độc lập giao vận.], [Phong cách kiến trúc trên HTTP, dùng tài nguyên (resource).], [Phong cách kiến trúc: hệ gồm nhiều dịch vụ nhỏ, triển khai độc lập.],
  [Hợp đồng], [WSDL (máy đọc, chặt chẽ).], [OpenAPI / quy ước (linh hoạt).], [Hợp đồng theo từng dịch vụ; có thể REST/gRPC/messaging.],
  [Định dạng], [XML (nặng).], [Thường JSON (nhẹ).], [Tùy dịch vụ.],
  [Ưu điểm], [Chuẩn WS-\* (bảo mật, giao dịch), mạnh cho B2B doanh nghiệp.], [Đơn giản, phổ biến web/mobile, caching tốt.], [Mở rộng & triển khai độc lập theo từng dịch vụ.],
  [Nhược điểm], [Cồng kềnh, khó dùng cho web/mobile hiện đại.], [Thiếu chuẩn hóa chặt như WS-\*.], [Độ phức tạp vận hành & nhất quán phân tán.],
)

*Lựa chọn của ShopNexus.* Hệ thống *không dùng SOAP* vì client chủ yếu là web và
mobile — nơi JSON/REST nhẹ và dễ dùng hơn nhiều so với XML/WSDL; các tính năng
WS-\* (giao dịch phân tán, bảo mật mức thông điệp) được thay bằng cơ chế phù hợp
hơn (Saga cho giao dịch, JWT cho xác thực). Hệ thống *kết hợp REST + Microservice*:
phơi bày *REST* cho client bên ngoài, đồng thời tổ chức backend thành các *dịch vụ*
(microservice) có khả năng triển khai độc lập. Điểm khác biệt của ShopNexus so với
microservice "sách giáo khoa" là nó sống trong một *monorepo*, giữ trải nghiệm phát
triển kiểu monolith (lời gọi liên dịch vụ vẫn *type-safe*, "ctrl+click" tới đúng
handler) trong khi *hình dạng dịch vụ* — tách schema, gọi qua ingress — vẫn nguyên
vẹn, nên việc tách một dịch vụ ra deployment riêng chỉ là thay đổi cấu hình.
