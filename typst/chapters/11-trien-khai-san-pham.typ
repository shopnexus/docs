#import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge
#import fletcher.shapes: pill

= PHÁT TRIỂN VÀ TRIỂN KHAI TRÊN MÔI TRƯỜNG SẢN PHẨM

== Yêu cầu production-ready

Một dịch vụ "chạy được trên máy mình" chưa đủ để lên sản phẩm. Lý thuyết
microservice yêu cầu dịch vụ đạt các thuộc tính *production-ready*: quan sát được,
tự phục hồi, cấu hình ngoài hóa, kiểm tra sức khỏe. ShopNexus đáp ứng các yêu cầu
này như sau:

#table(
  columns: (auto, 1fr),
  table.header([Yêu cầu], [Hiện thực]),
  [Health check], [Endpoint `GET /health` trả trạng thái; dùng cho liveness/readiness của Kubernetes.],
  [Đo lường (metrics)], [Endpoint `GET /metrics` phơi bày chỉ số Prometheus (`http_requests_total`, `http_request_duration_seconds`, `handler_invocations_total`, ...).],
  [Nhật ký có cấu trúc], [`slog`; mỗi dịch vụ gắn thuộc tính `module` → log tự mang ngữ cảnh, dễ lọc/truy vết.],
  [Tự phục hồi], [Durable execution + retry policy (1s→30s, 10 lần) + saga; lỗi tạm thời tự khỏi, luồng dài sống qua khởi động lại.],
  [Cấu hình ngoài hóa], [Cấu hình qua file/biến môi trường; nhà cung cấp thanh toán/vận chuyển cắm-được qua registry `option`.],
  [Truy vết thống nhất], [Mọi lời gọi có entry trong journal → một dòng truy vết cho toàn luồng nghiệp vụ, không cần ghép log rải rác.],
)

== Quan sát được (Observability)

Quan sát được là điều kiện sống còn của hệ nhiều dịch vụ. ShopNexus tích hợp
*Prometheus + Grafana*: middleware đo lường (Chương 3, mẫu Chain of Responsibility)
ghi mọi request theo *mẫu route* (không phải path thô, tránh bùng nổ nhãn); một
helper `TrackHandler` bọc mỗi handler nghiệp vụ để đếm số lần gọi và độ trễ theo
dịch vụ + kết quả. Kết hợp với journal của Restate, vận hành viên có cả ba "trụ
cột" quan sát: *metrics* (Prometheus), *logs* (slog có cấu trúc), và *trace* (journal
xuyên suốt luồng).

== Mẫu triển khai dịch vụ

ShopNexus dùng mẫu *Service-as-Container* (mỗi dịch vụ/hệ thống là một container),
đóng gói khác nhau theo môi trường:

#table(
  columns: (auto, 1fr),
  table.header([Môi trường], [Đóng gói]),
  [Phát triển (dev)], [`docker-compose.yml` — server, PostgreSQL, Redis, Restate, MinIO, Prometheus, Grafana trên một máy.],
  [Sản phẩm (prod)], [Kubernetes — `server-deployment` + `server-service`, `postgres-deployment`, `redis-deployment`, kèm `PersistentVolumeClaim`; Restate chạy *cụm 3 node* (replication = 2) để bền vững.],
)

#diag(
  caption: [Deployment (dev) — các thành phần hạ tầng và cổng],
  diagram(
    spacing: (8mm, 10mm),
    node-stroke: 0.7pt,
    node-corner-radius: 4pt,
    node((1, 0), text(fill: white)[ShopNexus Server \ Go · Echo · :8080], fill: c-primary, stroke: none, width: 50mm),
    node((0, 1), [Restate \ ingress :8080 \ admin :9070], fill: c-soft, width: 34mm),
    node((1, 1), [PostgreSQL 18 \ :5433], shape: pill, fill: c-soft, width: 32mm),
    node((2, 1), [Redis 8 \ (cache + lock)], shape: pill, fill: c-mid, width: 32mm),
    node((0, 2), [pgvector \ (vector search)], fill: white, width: 34mm),
    node((1, 2), [MinIO \ (S3 object store)], shape: pill, fill: white, width: 32mm),
    node((2, 2), [Prometheus :9090 \ + Grafana :3001], fill: white, width: 34mm),
    edge((1, 0), (0, 1), "<->", [durable RPC]),
    edge((1, 0), (1, 1), "->", [SQL]),
    edge((1, 0), (2, 1), "->", [cache/lock]),
    edge((1, 0), (0, 2), "->"),
    edge((1, 0), (1, 2), "->"),
    edge((1, 0), (2, 2), "-->", [/metrics], label-pos: 0.8, label-side: left),
  ),
)

== Một-binary hay nhiều deployment: chọn lúc triển khai

Vì các dịch vụ tách schema và chỉ gọi nhau qua ingress, *cấu trúc triển khai là một
lựa chọn cấu hình, không phải tái cấu trúc*. Toàn hệ có thể chạy trong *một tiến
trình* (kiểu monolith, đơn giản vận hành) hoặc *tách dịch vụ tải cao* (catalog,
order) thành deployment riêng để mở rộng độc lập — nhờ *vị trí trong suốt*, nơi gọi
không hề đổi.

#diag(
  caption: [Lộ trình mở rộng: từ một tiến trình tới tách dịch vụ thành deployment riêng],
  diagram(
    spacing: (30mm, 11mm),
    node-stroke: 0.7pt,
    node-corner-radius: 4pt,
    node((0, 0), [Một tiến trình: \ 8 dịch vụ + ingress], fill: c-soft, width: 46mm),
    node((1, 0), [Tách `order`, `catalog` \ thành deployment riêng], fill: c-mid, width: 50mm),
    edge((0, 0), (1, 0), "->", [đổi cấu hình \ (không refactor)], label-fill: white),
  ),
)

== Quản lý phiên bản dịch vụ

Phiên bản hóa giữ cho hệ thống tiến hóa mà không phá vỡ client đang dùng. ShopNexus
áp dụng phiên bản ở hai mức:

#table(
  columns: (auto, 1fr),
  table.header([Mức], [Cách làm]),
  [Hợp đồng REST ngoài], [Phiên bản qua URI (`/api/v1/...`); thay đổi phá vỡ đi vào `/api/v2` chạy song song, client cũ không bị ảnh hưởng.],
  [Đăng ký dịch vụ với runtime], [Mỗi dịch vụ *tự đăng ký* (auto-register) với Restate admin khi khởi động; Restate quản lý phiên bản deployment của endpoint, cho phép triển khai phiên bản mới và rút phiên bản cũ một cách có kiểm soát.],
  [Hợp đồng nội bộ (interface)], [Đổi chữ ký hàm bị trình biên dịch bắt ngay trong monorepo → "vỡ" được phát hiện lúc build, không phải lúc chạy.],
)

Đoạn dưới minh họa các dịch vụ được đăng ký kèm chính sách thử lại khi khởi động —
mỗi `Bind` là một dịch vụ mà runtime sẽ định tuyến và quản lý phiên bản:

```go
srv := server.NewRestate().
    Bind(restate.Reflect(accountbiz.NewAccountService(accountBiz), retryPolicy)).
    Bind(restate.Reflect(catalogbiz.NewCatalogService(catalogBiz), retryPolicy)).
    Bind(restate.Reflect(orderbiz.NewOrderService(orderBiz), retryPolicy)).
    // ... đủ 8 dịch vụ ...
    Bind(restate.Reflect(checkoutWf, retryPolicy)).
    Bind(restate.Reflect(fulfillmentWf, retryPolicy))
```

== Tự động hóa: sinh mã giữ chất lượng

Để giảm lỗi tay và giữ hợp đồng nhất quán, dự án sinh tự động ba lớp mã:

#table(
  columns: (auto, 1fr),
  table.header([Công cụ], [Sinh ra]),
  [SQLC], [Truy vấn type-safe từ SQL thuần (`Querier` mỗi dịch vụ).],
  [pgtempl], [Mẫu truy vấn + danh sách/phân trang (offset + cursor).],
  [genrestate], [Proxy client Restate hiện thực interface dịch vụ — biến lời gọi liên dịch vụ thành lời gọi durable qua ingress.],
)

Quy ước *không sửa tay tệp sinh tự động*: muốn đổi thì sửa bộ sinh, giữ mã sinh
luôn nhất quán với nguồn (SQL, định nghĩa interface).
