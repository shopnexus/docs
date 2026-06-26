#import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge
#import fletcher.shapes: pill

= TRIỂN KHAI TRUY VẤN TRONG MICROSERVICE

== Vấn đề truy vấn dữ liệu phân tán

Khi mỗi dịch vụ sở hữu schema riêng và *không có khóa ngoại xuyên dịch vụ*, một
truy vấn cần dữ liệu từ nhiều dịch vụ *không thể* thực hiện bằng một câu `JOIN` SQL
duy nhất. Ví dụ: bảng điều khiển (dashboard) của người bán cần *doanh thu/số đơn*
(thuộc dịch vụ `order`) lẫn *thống kê gian hàng/sản phẩm* (thuộc dịch vụ
`catalog`). Lý thuyết microservice đưa ra hai mẫu giải quyết, và ShopNexus dùng
*cả hai*: *API Composition* và *CQRS*.

== Mẫu API Composition

*API Composition* gom dữ liệu bằng cách *gọi từng dịch vụ rồi ghép kết quả ở tầng
ứng dụng*. ShopNexus dùng mẫu này cho bảng điều khiển người bán: thống kê đơn được
đọc *cục bộ*, còn thống kê gian hàng được lấy từ dịch vụ `catalog` (phụ thuộc một
chiều):

```go
// DashboardHandler sở hữu bảng điều khiển người bán được tổng hợp: thống kê đơn
// đọc cục bộ, thống kê gian hàng đến từ dịch vụ catalog (phụ thuộc xuôi).
type DashboardHandler struct {
    *base.Base
    catalog catalogbiz.CatalogBizClient
}

type DashboardBiz interface {
    GetSellerOrderStats(ctx context.Context, params GetSellerOrderStatsParams) (SellerOrderStats, error)
    GetSellerOrderTimeSeries(ctx context.Context, params GetSellerOrderTimeSeriesParams) ([]SellerOrderTimeSeriesPoint, error)
    GetSellerPendingActions(ctx context.Context, params GetSellerPendingActionsParams) (SellerPendingActions, error)
    GetSellerTopProducts(ctx context.Context, params GetSellerTopProductsParams) ([]SellerTopProduct, error)
    GetSellerDashboard(ctx context.Context, params GetSellerDashboardParams) (SellerDashboard, error)
}
```

`GetSellerDashboard` là *composer*: nó gọi nhiều nguồn (thống kê đơn cục bộ + gian
hàng qua `catalog`) rồi ghép thành một DTO trả về client trong một lời gọi.

#diag(
  caption: [API Composition — dashboard ghép dữ liệu từ order (cục bộ) và catalog (qua hợp đồng)],
  diagram(
    spacing: (22mm, 12mm),
    node-stroke: 0.7pt,
    node-corner-radius: 4pt,
    node((0, 1), [Client], fill: c-soft, width: 26mm),
    node((1, 1), text(fill: white)[`GetSellerDashboard` \ (Composer)], fill: c-primary, stroke: none, width: 42mm),
    node((2, 0), [order \ (thống kê đơn)], fill: white, width: 40mm),
    node((2, 2), [catalog \ (thống kê gian hàng)], fill: white, width: 40mm),
    edge((0, 1), (1, 1), "->", [1. request], bend: 20deg),
    edge((1, 1), (2, 0), "->", [2a. đọc local]),
    edge((1, 1), (2, 2), "->", [2b. gọi hợp đồng]),
    edge((1, 1), (0, 1), "-->", [3. DTO ghép], bend: 20deg),
  ),
)

*Ưu / nhược.* API Composition đơn giản, dữ liệu luôn *tươi* (đọc tại thời điểm
hỏi), phù hợp truy vấn không quá nặng. Nhược điểm: chi phí *fan-out* nhiều lời gọi
và khó cho truy vấn lọc/sắp xếp xuyên dịch vụ trên tập lớn — khi đó dùng CQRS.

== Mẫu CQRS với mô hình đọc cập nhật theo sự kiện

*CQRS* (Command Query Responsibility Segregation) tách *đường ghi* khỏi *đường
đọc*: dữ liệu được ghi ở dịch vụ chủ, đồng thời được *sao chép phi chuẩn hóa* sang
một *mô hình đọc* (read model / materialized view) tối ưu cho truy vấn, cập nhật
*bất đồng bộ qua sự kiện*. ShopNexus áp dụng CQRS cho hai mô hình đọc:

#table(
  columns: (1fr, 2fr, 2fr),
  table.header([Mô hình đọc], [Cập nhật bởi], [Phục vụ truy vấn]),
  [product popularity], [worker `analytic.popularity` (subscribe `TopicInteractionCreated`)], [Xếp hạng sản phẩm phổ biến theo điểm có trọng số.],
  [Chỉ mục tìm kiếm của `catalog`], [worker `catalog.search` (subscribe batch `TopicInteractionCreated`)], [Tìm kiếm lai (vector + từ khóa) có yếu tố độ phổ biến.],
)

Cụ thể, mỗi tương tác người dùng (xem, thêm giỏ, mua, đánh giá) sinh một sự kiện;
dịch vụ `analytic` tiêu thụ và cộng dồn điểm phổ biến theo *trọng số cấu hình được*
(mua > thêm giỏ > xem; trả hàng có thể âm), còn `catalog` cập nhật chỉ mục tìm
kiếm. Đường đọc (tìm kiếm, gợi ý) vì thế *không* phải truy vấn nóng vào dịch vụ
`order`/`analytic` mỗi lần — nó đọc thẳng mô hình đã được vật chất hóa.

#diag(
  caption: [CQRS — ghi tách đọc; sự kiện cập nhật mô hình đọc bất đồng bộ],
  diagram(
    spacing: (5mm, 9mm),
    node-stroke: 0.7pt,
    node-corner-radius: 4pt,
    node((0, 0), [Hành vi người dùng \ (command/ghi)], fill: c-soft, width: 38mm),
    node((1, 0), [`analytic` \ ghi tương tác], fill: white, width: 30mm),
    edge((0, 0), (1, 0), "->"),
    node((1, 1), text(fill: white)[Event bus \ `TopicInteractionCreated`], fill: c-primary, stroke: none, width: 56mm),
    edge((1, 0), (1, 1), "->", [publish]),
    node((0, 2), [worker `analytic.popularity` \ → product_popularity], fill: c-mid, width: 44mm),
    node((2, 2), [worker `catalog.search` \ → chỉ mục tìm kiếm], fill: c-mid, width: 44mm),
    edge((1, 1), (0, 2), "->", [subscribe]),
    edge((1, 1), (2, 2), "->", [subscribe]),
    node((1, 3), [Truy vấn đọc: tìm kiếm / gợi ý / xếp hạng], shape: pill, fill: c-soft, width: 70mm),
    edge((0, 2), (1, 3), "-->"),
    edge((2, 2), (1, 3), "-->"),
  ),
)

*Đánh đổi của CQRS.* Mô hình đọc *nhất quán cuối* (eventually consistent) — có độ
trễ nhỏ giữa lúc ghi và lúc mô hình đọc phản ánh. Với gợi ý/xếp hạng, độ trễ này
chấp nhận được; với dữ liệu cần *đọc-sau-ghi* tức thì (số dư ví, tồn kho) hệ thống
*không* dùng CQRS mà đọc trực tiếp đường ghi.

== Tổng kết lựa chọn

#table(
  columns: (auto, 1fr),
  table.header([Tình huống truy vấn], [Mẫu chọn]),
  [Ghép vài nguồn, cần dữ liệu tươi, tập nhỏ (dashboard)], [API Composition],
  [Tìm kiếm/gợi ý/xếp hạng trên tập lớn, chịu được trễ nhỏ], [CQRS (mô hình đọc cập nhật theo sự kiện)],
  [Đọc-sau-ghi tức thì (ví, tồn kho)], [Đọc trực tiếp đường ghi của dịch vụ chủ],
)
