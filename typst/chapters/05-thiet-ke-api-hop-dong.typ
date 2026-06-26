#import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line

= THIẾT KẾ API VÀ HỢP ĐỒNG DỊCH VỤ

Một dịch vụ chỉ hữu ích khi có *hợp đồng* (contract) rõ ràng. ShopNexus có *hai
loại hợp đồng* ở hai mức khác nhau: (1) *hợp đồng REST* hướng ra ngoài cho client,
và (2) *hợp đồng dịch vụ* (interface Go) hướng vào trong cho lời gọi liên dịch vụ.

== Hợp đồng dịch vụ: interface là nguồn sự thật

Thay vì mô tả hợp đồng bằng WSDL (như SOAP) hay file `.proto` (như gRPC), ShopNexus
dùng chính *interface Go* làm hợp đồng dịch vụ. Mỗi dịch vụ phơi bày một interface
duy nhất gom mọi năng lực của nó:

```go
//go:generate go run shopnexus-server/cmd/genrestate -interface OrderBiz -service Order
type OrderBiz interface {
    buyerorder.BuyerOrderBiz
    sellerorder.SellerOrderBiz
    cart.CartBiz
    orderpayment.PaymentBiz
    refund.RefundBiz
    dispute.DisputeBiz
    ordertransport.TransportBiz
    review.ReviewBiz
    dashboard.DashboardBiz

    InferCurrency(ctx context.Context, accountID uuid.UUID) (string, error)
    GetOptions(ctx context.Context, params GetOptionsParams) ([]sharedmodel.Option, error)
}
```

Interface này vừa là *hợp đồng* (bên gọi lập trình theo nó) vừa là *đầu vào sinh
mã*: chỉ thị `//go:generate` chạy công cụ `genrestate` để sinh proxy giao tiếp qua
Restate (Chương 6). Ưu điểm so với hợp đồng dạng chuỗi (WSDL/proto):

#table(
  columns: (auto, 1fr),
  table.header([Tiêu chí], [Hợp đồng interface trong ShopNexus]),
  [Kiểm tra tại biên dịch], [Sai chữ ký hàm xuyên ranh giới dịch vụ bị *trình biên dịch bắt ngay*, không "proto drift".],
  [Điều hướng IDE], [`ctrl+click` nhảy thẳng tới hiện thực; "find references" thấy mọi nơi gọi.],
  [Một nguồn sự thật], [Không phải đồng bộ tay giữa file hợp đồng và code hiện thực.],
  [Sinh mã], [Proxy client/sender/future được sinh tự động từ interface.],
)

*Đánh đổi.* Hợp đồng interface gắn với một ngôn ngữ (Go) — phù hợp hệ thống đồng
nhất ngôn ngữ trong monorepo. Nếu cần liên thông đa ngôn ngữ thực sự (yêu cầu kinh
điển của SOAP/gRPC), sẽ cần phơi bày thêm một hợp đồng trung lập ngôn ngữ; đây là
giới hạn đã được ghi nhận (xem Kết luận).

== Hợp đồng REST cho client bên ngoài

Với client (web, mobile), ShopNexus phơi bày *API REST* dưới tiền tố phiên bản
`/api/v1/...`, nhóm theo tài nguyên. Ví dụ dịch vụ order đăng ký nhóm route:

```go
g := e.Group("/api/v1/order")
// ...
buyerRefund := g.Group("/buyer/refund")
refund := g.Group("/refunds/:id")
```

Mỗi endpoint tuân theo một khuôn mẫu nhất quán: *bind → validate → lấy claims →
gọi biz → trả envelope*. Ví dụ endpoint cập nhật giỏ hàng:

```go
type UpdateCartRequest struct {
    SkuID         uuid.UUID  `json:"sku_id"         validate:"required"`
    Quantity      null.Int64 `json:"quantity"       validate:"omitnil"`
    DeltaQuantity null.Int64 `json:"delta_quantity" validate:"omitnil"`
}

func (h *Handler) UpdateCart(c echo.Context) error {
    var req UpdateCartRequest
    if err := c.Bind(&req); err != nil {
        return response.FromError(c.Response().Writer, http.StatusBadRequest, err)
    }
    if err := c.Validate(&req); err != nil {
        return response.FromError(c.Response().Writer, http.StatusBadRequest, err)
    }
    claims, err := authclaims.GetClaims(c.Request())
    if err != nil {
        return response.FromError(c.Response().Writer, http.StatusUnauthorized, err)
    }
    if err = h.biz.Call().UpdateCart(c.Request().Context(), orderbiz.UpdateCartParams{
        Account:       claims.Account,
        SkuID:         req.SkuID,
        Quantity:      req.Quantity,
        DeltaQuantity: req.DeltaQuantity,
    }); err != nil {
        return response.FromError(c.Response().Writer, http.StatusInternalServerError, err)
    }
    return response.FromMessage(c.Response().Writer, http.StatusOK, "Update cart successfully")
}
```

== Các nguyên tắc thiết kế API REST áp dụng

#table(
  columns: (auto, 1fr),
  table.header([Nguyên tắc], [Hiện thực]),
  [Định hướng tài nguyên], [URL là danh từ tài nguyên (`/order`, `/refunds/:id`), động từ HTTP biểu thị thao tác.],
  [Phiên bản hóa qua URI], [Tiền tố `/api/v1` cô lập thay đổi phá vỡ; có thể chạy song song `v2` về sau.],
  [Hợp đồng đầu vào tường minh], [Mỗi request là một struct có thẻ `validate`; kiểm tra trước khi vào logic.],
  [Envelope phản hồi thống nhất], [`response.FromDTO` / `FromError` / `FromMessage` / `FromPaginate` chuẩn hóa body trả về.],
  [Phi trạng thái + JWT], [Mỗi request mang JWT; danh tính lấy từ `claims`, không có phiên phía máy chủ.],
)

== Thiết kế cho bất đồng bộ: bắc cầu submit → đồng bộ

Một số thao tác (xác nhận đơn của người bán, checkout) khởi chạy một *workflow*
bất đồng bộ nhưng client cần một phản hồi *đồng bộ* (URL thanh toán để chuyển
hướng). API được thiết kế để *bắc cầu*: submit workflow rồi gắn vào handler chia
sẻ `GetPaymentURL` của nó để trả về URL ngay trong một phản hồi HTTP:

```go
// ConfirmSellerPendingResponse là envelope đồng bộ trả về bởi /seller/pending/confirm.
// SessionID đồng thời là workflow ID và RefID của cổng thanh toán.
type ConfirmSellerPendingResponse struct {
    ConfirmSessionID string `json:"confirm_session_id"`
    PaymentURL       string `json:"payment_url"` // rỗng nếu chỉ thanh toán bằng ví
}
```

Đây là một mẫu thiết kế API quan trọng cho hệ hướng dịch vụ: *che giấu* bản chất
bất đồng bộ/durable của xử lý phía sau sau một hợp đồng REST đồng bộ, quen thuộc
với client.
