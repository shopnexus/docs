= GIỚI THIỆU ĐỀ TÀI

== Bối cảnh và lý do chọn đề tài

Phát triển phần mềm hướng dịch vụ (Service-Oriented Software Development) là cách
tiếp cận xây dựng phần mềm như một tập hợp các *dịch vụ* (service) tự chứa, có
ranh giới rõ ràng, giao tiếp với nhau qua mạng theo những *hợp đồng* (contract)
được định nghĩa tường minh. Ba phong cách hiện thực phổ biến của tư tưởng này —
*SOAP*, *REST* và *Microservice* — đều hướng tới cùng một mục tiêu: tách hệ thống
lớn thành các đơn vị có thể phát triển, triển khai và mở rộng độc lập.

Để vận dụng trọn vẹn các khái niệm của môn học vào một sản phẩm *đủ phức tạp và
sát thực tế*, nhóm chọn xây dựng *ShopNexus* — một sàn thương mại điện tử (TMĐT)
đa người bán. Thương mại điện tử là miền bài toán giàu nghiệp vụ: vòng đời đơn
hàng dài, ràng buộc tiền bạc và tồn kho phải *đúng tuyệt đối*, nhiều tác nhân
(người mua, người bán, quản trị, hệ thống thanh toán/vận chuyển bên ngoài). Đây là
mảnh đất lý tưởng để thể hiện *vì sao* cần phân rã dịch vụ, *cách* các dịch vụ giao
tiếp, và *làm thế nào* giữ tính nhất quán khi một giao dịch trải dài nhiều dịch vụ.

== Mục tiêu của đề tài

Bám sát ba chuẩn đầu ra của học phần (CLO1 — hiểu phân tích/thiết kế dịch vụ với
SOAP/REST/Microservice; CLO2 — áp dụng phát triển phần mềm hướng dịch vụ cho một
bài toán cụ thể; CLO3 — trình bày kết quả dự án), đề tài đặt ra các mục tiêu:

+ *Phân tích và mô hình hóa dịch vụ.* Phân rã miền TMĐT thành các dịch vụ theo
  miền con (subdomain) nghiệp vụ, xác định ranh giới và trách nhiệm từng dịch vụ.

+ *Thiết kế hợp đồng và API dịch vụ.* Định nghĩa hợp đồng dịch vụ tường minh
  (interface) và API REST `/api/v1/...` cho client; phân tích lựa chọn giữa
  SOAP và REST.

+ *Hiện thực giao tiếp liên dịch vụ.* Xây dựng cơ chế giao tiếp giữa các dịch vụ
  (IPC) đồng bộ/bất đồng bộ, bền vững và quan sát được.

+ *Bảo đảm tính nhất quán phân tán.* Áp dụng mẫu *Saga* cho các giao dịch vượt
  ranh giới dịch vụ (checkout, hoàn tiền, chi trả).

+ *Thiết kế logic nghiệp vụ và truy vấn.* Vận dụng Domain-Driven Design (DDD),
  event-driven, *CQRS* và *API Composition* để xử lý ghi và đọc dữ liệu phân tán.

+ *Triển khai môi trường sản phẩm.* Đóng gói production-ready với Docker/Kubernetes,
  giám sát bằng Prometheus + Grafana, có chiến lược phiên bản hóa dịch vụ.

== Phạm vi và phương pháp

*Phạm vi.* Báo cáo mô tả đúng hệ thống thực tế trong mã nguồn `shopnexus-server`
(backend viết bằng Go, điều phối bởi nền tảng durable execution *Restate*) cùng
ứng dụng khách Android. Mọi đoạn mã trích dẫn được lấy nguyên văn từ mã nguồn, có
ghi rõ đường dẫn tệp; những phần còn hạn chế được nêu thẳng ở chương Kết luận.

*Phương pháp.* Nhóm tiến hành theo quy trình vòng đời dự án phần mềm hướng dịch vụ:

#table(
  columns: (1fr, 2fr),
  table.header([Giai đoạn], [Hoạt động]),
  [1. Phân tích yêu cầu], [Xác định tác nhân (buyer/seller/admin), use case, ràng buộc chức năng và phi chức năng (đúng đắn, đồng thời, bền vững).],
  [2. Phân tích & mô hình hóa dịch vụ], [Phân rã miền theo subdomain (DDD), xác định ranh giới dịch vụ và quan hệ phụ thuộc.],
  [3. Thiết kế hợp đồng & API], [Định nghĩa interface dịch vụ, API REST, hợp đồng giao tiếp; chọn REST thay cho SOAP và lý giải.],
  [4. Thiết kế giao tiếp & giao dịch], [Cơ chế IPC qua Restate ingress; Saga cho giao dịch phân tán.],
  [5. Hiện thực], [Lập trình Go 1.26, PostgreSQL 18, Redis, Restate; sinh mã tự động (SQLC, genrestate).],
  [6. Kiểm thử & triển khai], [Viết test, đóng gói Docker Compose / Kubernetes, giám sát Prometheus + Grafana.],
)
