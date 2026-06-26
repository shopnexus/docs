#import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line, font-head
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge
#import fletcher.shapes: diamond, pill, ellipse

// Nút trạng thái: pill bo tròn; final = trạng thái kết thúc (viền đôi).
#let state(p, body, final: false) = node(
  p, body,
  shape: pill,
  inset: 7pt,
  fill: if final { c-soft } else { white },
  stroke: 0.8pt + c-primary,
  extrude: if final { (0, 3.5) } else { (0,) },
)

= PHÂN TÍCH VÀ MÔ HÌNH HÓA DỊCH VỤ

== Tác nhân và nhu cầu

Hệ thống dùng *mô hình tài khoản hợp nhất*: không có bảng riêng cho khách
hàng/người bán; `buyer_id` và `seller_id` đều là khóa ngoại trỏ tới
`account.account`. Cùng một tài khoản có thể đóng cả hai vai.

#table(
  columns: (auto, 1fr),
  table.header([Tác nhân], [Cần gì ở hệ thống]),
  [*Người mua* (Buyer)], [Duyệt & tìm sản phẩm, thêm giỏ hàng, đặt hàng, thanh toán đa cổng, theo dõi đơn, yêu cầu hoàn tiền, nhắn tin người bán.],
  [*Người bán* (Seller)], [Đăng & quản lý sản phẩm, nhập kho, xác nhận đơn hàng, báo giá vận chuyển, duyệt/khiếu nại yêu cầu hoàn tiền, nhận chi trả (payout).],
  [*Quản trị viên* (Admin)], [Phân xử tranh chấp hoàn tiền, cấu hình hệ thống, các thao tác vận hành thủ công.],
  [*Hệ thống ngoài*], [Cổng thanh toán (VNPay, SePay, thẻ) và đơn vị vận chuyển (GHTK) gọi *webhook* để cập nhật kết quả thanh toán / giao vận.],
)

== Biểu đồ use case tổng quát

#diag(
  caption: [Biểu đồ use case tổng quát — tác nhân và các chức năng chính],
  diagram(
    spacing: (10mm, 7mm),
    node-stroke: 0.7pt,
    node((0, 3), [*Người mua*], shape: pill, fill: c-soft, width: 26mm),
    node((0, 7), [*Người bán*], shape: pill, fill: c-soft, width: 26mm),
    node((6, 5), [*Quản trị*], shape: pill, fill: c-soft, width: 24mm),
    node((3, 0.5), [Đăng ký / Đăng nhập], shape: ellipse, fill: white),
    node((3, 1.6), [Duyệt & tìm sản phẩm], shape: ellipse, fill: white),
    node((3, 2.7), [Quản lý giỏ hàng], shape: ellipse, fill: white),
    node((3, 3.8), [Đặt hàng (checkout)], shape: ellipse, fill: white),
    node((3, 4.9), [Thanh toán], shape: ellipse, fill: white),
    node((3, 6.0), [Yêu cầu hoàn tiền], shape: ellipse, fill: white),
    node((3, 7.1), [Nhắn tin], shape: ellipse, fill: white),
    node((3, 8.2), [Quản lý sản phẩm / kho], shape: ellipse, fill: white),
    node((3, 9.3), [Xác nhận / Giao đơn], shape: ellipse, fill: white),
    node((3, 10.4), [Phân xử tranh chấp], shape: ellipse, fill: white),
    edge((0, 3), (3, 0.5)), edge((0, 3), (3, 1.6)), edge((0, 3), (3, 2.7)),
    edge((0, 3), (3, 3.8)), edge((0, 3), (3, 4.9)), edge((0, 3), (3, 6.0)),
    edge((0, 3), (3, 7.1)),
    edge((0, 7), (3, 0.5)), edge((0, 7), (3, 7.1)), edge((0, 7), (3, 8.2)),
    edge((0, 7), (3, 9.3)), edge((0, 7), (3, 6.0)),
    edge((6, 5), (3, 10.4)),
  ),
)

== Phân rã dịch vụ theo miền con (Decompose by Subdomain)

Câu hỏi trung tâm của phân tích hướng dịch vụ là: *chia hệ thống thành những dịch
vụ nào?* ShopNexus áp dụng chiến lược *phân rã theo miền con nghiệp vụ*
(decompose by subdomain) của DDD — mỗi miền con (bounded context) trở thành một
dịch vụ, sở hữu dữ liệu và logic của riêng nó. Tiêu chí phân rã:

- *Gắn kết cao trong dịch vụ (high cohesion).* Mọi thứ liên quan tới đơn hàng
  (giỏ, checkout, thanh toán, hoàn tiền) nằm trong `order`.
- *Ràng buộc lỏng giữa các dịch vụ (loose coupling).* Mỗi dịch vụ một schema, không
  khóa ngoại xuyên dịch vụ; tham chiếu chéo (`account_id`, `sku_id`) chỉ là giá trị.
- *Tự trị dữ liệu.* Một dịch vụ chỉ ghi vào schema của chính nó; muốn dữ liệu của
  dịch vụ khác phải *gọi qua hợp đồng*, không truy vấn trực tiếp.

== Biểu đồ phụ thuộc dịch vụ

Quan hệ phụ thuộc giữa các dịch vụ được thiết kế *một chiều* tối đa có thể, lấy
`order` làm dịch vụ điều phối trung tâm:

#diag(
  caption: [Đồ thị phụ thuộc giữa các dịch vụ (order là dịch vụ điều phối trung tâm)],
  diagram(
    spacing: (15mm, 12mm),
    node-stroke: 0.7pt,
    node-corner-radius: 4pt,
    node((1, 0), text(fill: white)[`order`], fill: c-primary, stroke: none, width: 26mm),
    node((0, 1), [`account`], fill: c-soft),
    node((1, 1), [`catalog`], fill: c-soft),
    node((2, 1), [`inventory`], fill: c-soft),
    node((0, 2), [`promotion`], fill: white),
    node((1, 2), [`common`], fill: white),
    node((2, 2), [`analytic`], fill: white),
    node((3, 1), [`chat`], fill: white),
    edge((1, 0), (0, 1), "->"),
    edge((1, 0), (1, 1), "->"),
    edge((1, 0), (2, 1), "->"),
    edge((1, 0), (0, 2), "->"),
    edge((1, 0), (1, 2), "->"),
    edge((1, 0), (2, 2), "->"),
    edge((1, 1), (2, 2), "-->", [tìm kiếm]),
  ),
)

== Mô hình hóa hành vi: máy trạng thái

Nhiều thực thể trong hệ thống được mô hình hóa bằng máy trạng thái hữu hạn — một
công cụ mô hình hóa dịch vụ quan trọng, làm rõ các chuyển trạng thái hợp lệ và là
xương sống cho thiết kế workflow ở các chương sau.

#diag(
  caption: [Máy trạng thái — phiên thanh toán (`order.payment_session`)],
  diagram(
    spacing: (22mm, 13mm),
    edge((-0.55, 1), (0, 1), "->"),
    state((0, 1), [Pending]),
    state((1, 1), [Processing]),
    state((2, 0), [Success], final: true),
    state((2, 1), [Failed], final: true),
    state((2, 2), [Cancelled], final: true),
    edge((0, 1), (1, 1), "->", [charge], label-fill: white),
    edge((1, 1), (2, 0), "->", [ok], bend: 18deg, label-fill: white),
    edge((1, 1), (2, 1), "->", [lỗi], label-fill: white),
    edge((1, 1), (2, 2), "->", [hủy], bend: -18deg, label-fill: white),
  ),
)

#diag(
  caption: [Máy trạng thái — yêu cầu hoàn tiền (`order.refund`)],
  diagram(
    spacing: (34mm, 15mm),
    edge((1, -0.55), (1, 0), "->"),
    state((1, 0), [Shipping]),
    state((1, 1), [Awaiting \ Review]),
    state((1, 2), [Disputed]),
    state((0, 3), [Accepted], final: true),
    state((2, 3), [Rejected], final: true),
    edge((1, 0), (1, 1), "->", [đã giao trả], label-fill: white),
    edge((1, 1), (1, 2), "->", [tranh chấp], label-fill: white),
    edge((1, 2), (0, 3), "->", [buyer thắng], label-fill: white),
    edge((1, 2), (2, 3), "->", [seller thắng], label-fill: white),
  ),
)

== Mô hình dữ liệu phân tán (ER) tóm tắt

Mỗi dịch vụ sở hữu schema riêng; *không có khóa ngoại xuyên dịch vụ*. Bảng dưới tóm
tắt thực thể chính của các dịch vụ cốt lõi:

#table(
  columns: (1fr, 2fr),
  table.header([Dịch vụ / Bảng chính], [Quan hệ & ghi chú]),
  [`account`: account, profile, contact, wallet], [profile 1–1 account; contact/wallet n–1 account; ví mặc định duy nhất qua *partial unique index*.],
  [`catalog`: product_spu, product_sku, category, comment], [sku n–1 spu; spu n–1 category (phân cấp qua `parent_id`); comment đa hình (review/threading).],
  [`order`: order, item, payment_session, transaction, refund], [item n–1 order (order_id NULL tới khi seller xác nhận); transaction n–1 session (sổ cái append-only, amount có dấu); refund n–1 order.],
  [`inventory`: stock, serial, stock_history], [serial/history n–1 stock; tham chiếu đa hình (`ref_type` = ProductSku \| Promotion); tổng `change` = tồn hiện tại.],
  [`promotion`: promotion, ref, schedule], [ref/schedule n–1 promotion; ref đa hình (Spu \| Sku \| Category); data đặc thù loại lưu JSONB.],
)
