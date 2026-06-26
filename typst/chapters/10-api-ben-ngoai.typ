#import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge
#import fletcher.shapes: pill

= GIAO TIẾP API BÊN NGOÀI

Chương trước bàn về giao tiếp *bên trong* (giữa các dịch vụ). Chương này bàn về
giao tiếp *bên ngoài*: làm thế nào client (web, mobile) và hệ thống thứ ba (cổng
thanh toán, vận chuyển) nói chuyện với hệ thống dịch vụ. Lý thuyết microservice đưa
ra ba mẫu chính cho biên ngoài: *API Gateway*, *Backend-for-Frontend (BFF)* và
*GraphQL*.

== Mẫu API Gateway

*API Gateway* là *điểm vào duy nhất* cho mọi request từ ngoài, đảm nhiệm các mối
quan tâm cắt ngang: định tuyến, CORS, xác thực, đo lường, giới hạn tần suất. Trong
ShopNexus, vai trò gateway được hiện thực bằng một *Echo server* với chuỗi
middleware dùng chung cho toàn bộ route, cùng các endpoint vận hành:

```go
func NewEcho() *echo.Echo {
    e := echo.New()
    e.Use(middleware.CORS())
    e.Use(metrics.EchoMiddleware())
    return e
}

func SetupEcho(params RouteParams) {
    params.Echo.Validator = customVal
    params.Echo.Binder = binder.NewCustomBinder()
    // Endpoint đo lường (không cần auth)
    params.Echo.GET("/metrics", echo.WrapHandler(promhttp.Handler()))
    // Health check
    params.Echo.GET("/health", func(c echo.Context) error {
        return c.JSON(200, map[string]string{"status": "ok"})
    })
}
```

Tầng gateway cũng là nơi *xác thực tập trung*: mỗi request mang JWT, danh tính được
trích ra thành `claims` và truyền xuống các dịch vụ — bản thân dịch vụ không lặp
lại logic đăng nhập. Cùng với *proxy interface* (Chương 6), bộ đôi gateway + ingress
cho phép client gọi một API REST thống nhất mà không cần biết phía sau là một hay
nhiều dịch vụ.

#diag(
  caption: [API Gateway: điểm vào duy nhất, gom các mối quan tâm cắt ngang trước khi tới dịch vụ],
  diagram(
    spacing: (14mm, 9mm),
    node-stroke: 0.7pt,
    node-corner-radius: 4pt,
    node((0, 1), [Web], fill: c-soft, width: 20mm),
    node((0, 2), [Mobile], fill: c-soft, width: 20mm),
    node((1.4, 1.5), text(fill: white)[API Gateway (Echo) \ CORS · JWT · Metrics · \ Validate · Route], fill: c-primary, stroke: none, width: 48mm, inset: 7pt),
    edge((0, 1), (1.4, 1.5), "->"),
    edge((0, 2), (1.4, 1.5), "->"),
    node((3, 1.5), [Restate Ingress \ → dịch vụ], fill: c-mid, width: 34mm),
    edge((1.4, 1.5), (3, 1.5), "->"),
  ),
)

== Mẫu Backend-for-Frontend (BFF)

*BFF* là biến thể của gateway: *mỗi loại client có một backend riêng* được "đo ni
đóng giày" cho nhu cầu của nó, thay vì một API tổng dùng chung. ShopNexus thể hiện
tinh thần BFF theo hai cách:

- *Endpoint tổng hợp theo màn hình.* `GetSellerDashboard` (Chương 9) gói nhiều lời
  gọi thành một response vừa khít một màn hình — client mobile chỉ gọi *một* lần
  thay vì fan-out nhiều request yếu (giảm chatty API, tiết kiệm pin/mạng).
- *Bắc cầu bất đồng bộ → đồng bộ.* Endpoint checkout/confirm submit một workflow
  durable nhưng trả ngay `payment_url` để app mobile chuyển hướng — giấu sự phức
  tạp durable sau một hợp đồng đồng bộ hợp khẩu vị client (Chương 5).

Ứng dụng khách là *app Android* gọi REST qua *Retrofit* (parse JSON, callback bất
đồng bộ) và tải ảnh qua *Glide*. App này chính là phần "frontend" mà BFF phục vụ:
nó chỉ thấy API REST `/api/v1/...` ổn định, hoàn toàn không biết phía sau là hệ
nhiều dịch vụ điều phối bởi Restate.

== GraphQL — và lý do chưa dùng

*GraphQL* cho phép client tự khai báo *chính xác* trường dữ liệu cần, gom nhiều
nguồn vào một truy vấn — rất mạnh khi client đa dạng và mô hình dữ liệu phức tạp.
ShopNexus *chưa* dùng GraphQL, vì:

#table(
  columns: (auto, 1fr),
  table.header([Cân nhắc], [Đánh giá]),
  [Số loại client], [Hiện chỉ web + một app mobile; chưa đủ đa dạng để GraphQL "hời" hơn REST.],
  [Đã có composer], [Nhu cầu "một request, nhiều nguồn" đã được API Composition (dashboard) phục vụ.],
  [Chi phí], [GraphQL thêm tầng schema, resolver, lo N+1 và phân quyền theo field — chi phí chưa tương xứng lợi ích ở quy mô hiện tại.],
)

Hệ thống *để ngỏ* GraphQL như một hướng mở rộng nếu sau này có nhiều loại client
với nhu cầu dữ liệu khác nhau rõ rệt.

== Webhook: hệ thống ngoài gọi vào

Chiều ngược lại của API ngoài là *webhook* — hệ thống thứ ba chủ động gọi vào để
báo kết quả. Cổng thanh toán (VNPay/SePay/thẻ) và đơn vị vận chuyển (GHTK) đăng ký
các route webhook, ví dụ:

```go
// POST /api/v1/transport/webhook/ghtk  — GHTK báo cập nhật trạng thái giao vận
e.POST("/api/v1/transport/webhook/ghtk", func(ec echo.Context) error { /* ... */ })
```

Webhook là điểm nối với *Durable Promise* (Chương 8): một workflow checkout đang
*chờ* kết quả thanh toán sẽ được webhook `Resolve` để đánh thức và đi tiếp — biến
một sự kiện ngoài bất định thời điểm thành một điểm chờ durable, an toàn qua khởi
động lại.
