#import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line, font-head
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge

= LỚP DỊCH VỤ VÀ CÁC MẪU THIẾT KẾ

== Khái niệm lớp dịch vụ, dịch vụ và vi dịch vụ

Trong kiến trúc hướng dịch vụ, các dịch vụ thường được tổ chức thành các *lớp dịch
vụ* (service layers) theo mức độ trừu tượng nghiệp vụ. Cách phân lớp kinh điển của
Erl gồm ba loại; ShopNexus ánh xạ rõ ràng sang ba loại này:

#table(
  columns: (1fr, 2fr, 2fr),
  table.header([Lớp dịch vụ], [Vai trò], [Trong ShopNexus]),
  [*Task service* (dịch vụ tác vụ)], [Đóng gói logic của một tiến trình nghiệp vụ cụ thể, thường điều phối nhiều dịch vụ khác.], [`CheckoutWorkflow`, `FulfillmentWorkflow` — điều phối checkout và xác nhận đơn.],
  [*Entity service* (dịch vụ thực thể)], [Quản lý một thực thể nghiệp vụ và logic quanh nó, tái sử dụng cao.], [`account`, `catalog`, `order`, `inventory`, `promotion`, `chat`.],
  [*Utility service* (dịch vụ tiện ích)], [Cung cấp năng lực kỹ thuật dùng chung, không gắn nghiệp vụ.], [`common` (lưu trữ tệp, geocoding, tỉ giá, SSE), `analytic` (ghi nhận tương tác).],
)

*Dịch vụ và vi dịch vụ.* Trong ShopNexus, ranh giới giữa "dịch vụ" và "vi dịch vụ"
là một *quyết định triển khai*, không phải quyết định mã nguồn. Toàn bộ hệ thống
gồm *8 module nghiệp vụ*, mỗi module là một "lát cắt dọc" (vertical slice) độc lập,
sở hữu schema PostgreSQL riêng và có thể chạy chung một tiến trình (monolith) hoặc
tách thành deployment riêng (microservice):

#table(
  columns: (auto, 1fr),
  table.header([Module / Dịch vụ], [Trách nhiệm]),
  [`account`], [Xác thực (JWT), hồ sơ, địa chỉ liên hệ, ví/phương thức thanh toán, yêu thích, thông báo.],
  [`catalog`], [Sản phẩm (SPU/SKU), danh mục, thẻ (tag), bình luận/đánh giá, tìm kiếm lai (vector + từ khóa).],
  [`order`], [Giỏ hàng, checkout, xác nhận của người bán, thanh toán, hoàn tiền, khiếu nại — *dịch vụ điều phối trung tâm*.],
  [`inventory`], [Quản lý tồn kho, giữ chỗ/giải phóng, truy vết serial, lịch sử kiểm toán.],
  [`promotion`], [Giảm giá, giảm phí ship, lịch chạy, xếp chồng khuyến mãi theo nhóm.],
  [`analytic`], [Ghi nhận tương tác người dùng, tính điểm phổ biến có trọng số.],
  [`chat`], [Hội thoại, tin nhắn, trạng thái đã đọc giữa người mua và người bán.],
  [`common`], [Quản lý tài nguyên/tệp, lưu trữ đối tượng, registry tùy chọn dịch vụ, geocoding, tỉ giá, SSE.],
)

== Phân tầng bên trong một dịch vụ

Mỗi dịch vụ được phân tầng rõ ràng (ánh xạ tinh thần MVC) để tách biệt mối quan tâm
giữa giao vận, điều phối, logic và dữ liệu:

#table(
  columns: (auto, auto, 1fr),
  table.header([Tầng], [Vai trò], [Chức năng]),
  [Transport (Echo)], [Presentation], [Handler HTTP — nhận request, trả response REST `/api/v1/...`.],
  [Restate ingress], [Dispatcher], [Định tuyến lời gọi tới đúng dịch vụ + phương thức, bảo đảm bền vững & thử lại.],
  [Logic nghiệp vụ (`biz`)], [Domain Logic], [Toàn bộ logic, workflow; mọi method nhận `restate.Context`.],
  [Truy cập dữ liệu (`repo`/`db`)], [Data Access], [Truy vấn type-safe sinh tự động (SQLC), gói trong repository chung.],
  [Mô hình miền (`model`)], [Domain Model / DTO], [Cấu trúc dữ liệu miền, sentinel error.],
)

Nguyên tắc cốt lõi (sẽ trở lại ở Chương 6): *dịch vụ A không bao giờ gọi trực tiếp
dịch vụ B*. Cả request từ bên ngoài lẫn lời gọi liên dịch vụ đều "hội tụ" qua proxy
và Restate ingress, nên bền vững, thử lại và quan sát được áp dụng *đồng nhất*.

== Các mẫu thiết kế

Phần này liệt kê các mẫu thiết kế *thực sự xuất hiện* trong mã nguồn, kèm trích dẫn
nguyên văn. Các mẫu được nhóm theo hai loại: mẫu GoF (cấp lớp/đối tượng) và mẫu
kiến trúc hướng dịch vụ (cấp hệ thống).

=== Factory Method — chọn nhà cung cấp dịch vụ ngoài

Module `order` định tuyến một cấu hình `Option` tới đúng constructor của nhà cung
cấp thanh toán:

```go
// paymentFactory định tuyến một Option tới constructor của provider tương ứng.
func (b *Base) paymentFactory(cfg sharedmodel.Option) payment.Client {
    switch cfg.Provider {
    case "vnpay":
        return vnpay.NewClient(cfg)
    case "sepay":
        return sepay.NewClient(cfg)
    case "card":
        return card.NewClient(cfg)
    default:
        b.Logger.Warn("unknown payment provider", "provider", cfg.Provider, "id", cfg.ID)
        return nil
    }
}
```

*Lý do chọn:* thêm cổng thanh toán mới chỉ cần thêm một nhánh `case` + một
constructor, *không đụng* logic checkout. Mẫu tương tự dùng cho vận chuyển
(`transportFactory`).

=== Strategy — họ thuật toán sau một hợp đồng chung

Mỗi nhà cung cấp thanh toán là một *chiến lược* hiện thực interface `payment.Client`:

```go
type Client interface {
    Config() sharedmodel.Option
    Charge(ctx context.Context, params ChargeParams) (ChargeResult, error)
    Refund(ctx context.Context, params RefundParams) (RefundResult, error)
    Tokenize(ctx context.Context, params TokenizeParams) (TokenizeResult, error)
    WireWebhooks(e *echo.Echo, deliver NotificationHandler, registered map[string]struct{}) string
}
```

Strategy + Factory phối hợp: Factory chọn chiến lược theo cấu hình, Strategy định
nghĩa hợp đồng. Các chiến lược tương tự còn có ở vận chuyển, LLM, geocoding, cache.

=== Facade — một mặt tiền cho cả dịch vụ

`OrderHandler` là *mặt tiền* duy nhất của dịch vụ order. Nó nhúng các handler con
theo từng nghiệp vụ và nâng (promote) toàn bộ method của chúng lên một service
Restate "Order" duy nhất:

```go
type OrderHandler struct {
    *base.Base                       // phụ thuộc dùng chung: cfg, logger, DB, client liên-dịch-vụ
    *buyerorder.BuyerHandler         // đặt hàng phía người mua
    *sellerorder.SellerHandler       // xác nhận đơn phía người bán
    *cart.CartHandler                // giỏ hàng
    *orderpayment.PaymentHandler     // thanh toán
    *refund.RefundHandler            // hoàn tiền
    *dispute.DisputeHandler          // tranh chấp
    *ordertransport.TransportHandler // vận chuyển
    *review.ReviewHandler            // đánh giá
    *dashboard.DashboardHandler      // thống kê
}
```

*Lý do chọn:* một dịch vụ "Order" duy nhất che chín nghiệp vụ con; nơi gọi chỉ thấy
một hợp đồng gọn gàng (`OrderBiz`).

=== Chain of Responsibility — middleware giao vận

Echo dựng chuỗi middleware CORS → Metrics → handler; mỗi mắt xích nhận `next` và
chủ động gọi nó. Mẫu này tách các mối quan tâm cắt ngang (CORS, đo lường, xác thực)
khỏi handler nghiệp vụ.

=== Observer — event bus tách rời ghi nhận và xử lý

Khi ghi nhận tương tác người dùng, `analytic` phát tán (fan-out) sự kiện qua một
event bus nội bộ; các observer (tính điểm phổ biến, cập nhật tìm kiếm của catalog)
tự đăng ký và tiêu thụ độc lập. Mẫu này là nền tảng cho phần CQRS ở Chương 9.

=== Các mẫu kiến trúc hướng dịch vụ

#table(
  columns: (auto, 2fr),
  table.header([Mẫu], [Vai trò trong hệ thống]),
  [*Proxy*], [Client sinh tự động hiện thực interface dịch vụ, chuyển lời gọi qua Restate ingress (Chương 6).],
  [*Saga / Orchestration*], [Giao dịch phân tán nhiều bước với bù trừ khi lỗi (Chương 7).],
  [*Repository*], [Bọc truy vấn type-safe + ranh giới giao dịch qua `Storage[T]` generic.],
  [*Dependency Injection*], [Uber `fx` dựng đồ thị phụ thuộc & quản lý vòng đời dịch vụ.],
  [*API Composition / CQRS*], [Tổng hợp dữ liệu từ nhiều dịch vụ và mô hình đọc (Chương 9).],
  [*Decorator*], [`Saga.Wrap` bọc hàm nghiệp vụ để gắn hành vi bù trừ tự động.],
)
