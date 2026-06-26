#import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge
#import fletcher.shapes: pill

= QUẢN LÝ GIAO DỊCH VỚI SAGA

== Vấn đề: giao dịch vượt ranh giới dịch vụ

Một thao tác như *đặt hàng* phải thay đổi dữ liệu ở nhiều dịch vụ độc lập: trừ tồn
kho (`inventory`), trừ ví người mua (`account`), tạo phiên thanh toán và đơn hàng
(`order`). Mỗi dịch vụ sở hữu schema riêng, *không* chia sẻ giao dịch cơ sở dữ
liệu. Vì vậy không thể dùng một giao dịch ACID duy nhất bao trùm tất cả.

#table(
  columns: (auto, 1fr),
  table.header([Cách tiếp cận], [Đánh giá]),
  [*Two-Phase Commit* (2PC)], [Khóa tài nguyên ở mọi dịch vụ đến khi commit toàn cục; chậm, dễ nghẽn, một node treo làm kẹt cả giao dịch. Không phù hợp luồng dài (chờ thanh toán/giao hàng có thể kéo dài nhiều ngày).],
  [*Saga*], [Chia giao dịch lớn thành chuỗi bước cục bộ, mỗi bước có một *hành động bù trừ* (compensating action). Nếu một bước thất bại, chạy ngược các bù trừ đã đăng ký để đưa hệ thống về trạng thái nhất quán. Không khóa toàn cục.],
)

Hệ thống chọn *Saga theo kiểu điều phối* (orchestration-based saga): một workflow
trung tâm gọi lần lượt các bước và tự giữ danh sách bù trừ — khác với *choreography*
(các dịch vụ tự phản ứng sự kiện của nhau, khó lần vết).

== Hiện thực: ngăn xếp bù trừ

Saga trong dự án là một cấu trúc nhỏ, giữ một *ngăn xếp* các bước bù trừ và chạy
chúng theo thứ tự *LIFO* (vào sau — ra trước) khi thất bại.

```go
// Saga gom các compensator theo thứ tự đăng ký và chạy LIFO khi lỗi.
type Saga struct {
    ctx          context.Context
    compensators []step
}

// Defer thêm một compensator. Gọi TRƯỚC khi thực hiện hành động mà nó bù trừ.
func (s *Saga) Defer(name string, fn func(context.Context) error) {
    s.compensators = append(s.compensators, step{name: name, fn: fn})
}

// Compensate chạy mọi compensator theo LIFO, trả về lỗi đầu tiên (nếu có).
func (s *Saga) Compensate() error {
    for len(s.compensators) > 0 {
        i := len(s.compensators) - 1
        c := s.compensators[i]
        if err := c.fn(s.ctx); err != nil {
            return fmt.Errorf("saga compensate %s: %w", c.name, err)
        }
        // Chỉ pop khi thành công — giữ bước lỗi ở cuối để thử lại.
        s.compensators = s.compensators[:i]
    }
    return nil
}

// Clear xoá toàn bộ compensator đang chờ. Gọi trên nhánh thành công.
func (s *Saga) Clear() { s.compensators = nil }
```

=== Vì sao bù trừ chạy theo thứ tự LIFO?

Các bước thường *phụ thuộc* nhau theo thứ tự: bước sau dựng trên kết quả bước trước.
Khi quay lui, phải tháo theo chiều ngược lại để mỗi bù trừ thấy đúng trạng thái mà
nó kỳ vọng — giống tháo một chồng đĩa.

#diag(
  caption: [Saga: đăng ký compensator xuôi chiều, chạy bù trừ ngược chiều (LIFO)],
  diagram(
    spacing: (30mm, 9mm),
    node-stroke: 0.7pt,
    node-corner-radius: 3pt,
    node((0, 0), [B1: nhả giỏ hàng], fill: c-soft, width: 40mm),
    node((0, 1), [B2: nhả kho], fill: c-soft, width: 40mm),
    node((0, 2), [B3: hoàn ví], fill: c-soft, width: 40mm),
    edge((0, 0), (0, 1), "->"),
    edge((0, 1), (0, 2), "->"),
    node((0, -0.8), text(weight: "bold")[Đăng ký (Defer) xuôi]),
    node((1, -0.8), text(weight: "bold")[Bù trừ (Compensate) ngược]),
    node((1, 0), [hoàn ví], fill: c-mid, width: 40mm),
    node((1, 1), [nhả kho], fill: c-mid, width: 40mm),
    node((1, 2), [nhả giỏ hàng], fill: c-mid, width: 40mm),
    edge((1, 0), (1, 1), "->"),
    edge((1, 1), (1, 2), "->"),
  ),
)

=== Decorator `Wrap`: tự động bù trừ khi lỗi terminal

`Wrap` bọc một hàm nghiệp vụ, gắn thêm hành vi *bù trừ tự động* khi gặp *lỗi
terminal* (lỗi không thể tự khỏi bằng thử lại):

```go
func (s *Saga) Wrap(fn func() error) error {
    if err := fn(); err != nil {
        if restate.IsTerminalError(err) {
            if cErr := s.Compensate(); cErr != nil {
                return fmt.Errorf("workflow error: %w; compensate error: %w", err, cErr)
            }
        }
        return err
    }
    return nil
}
```

Phân biệt *lỗi terminal* và *lỗi tạm thời* là then chốt:

#table(
  columns: (auto, 1fr),
  table.header([Loại lỗi], [Xử lý]),
  [Tạm thời (mạng chập chờn, DB nghẽn)], [*Không* bù trừ. Restate thử lại workflow; bước đã xong phát lại từ journal → tự khỏi.],
  [Terminal (hết hàng, sai dữ liệu, từ chối)], [Chạy `Compensate()` để quay lui, rồi trả lỗi cho người gọi.],
)

== Nạp compensator *trước khi* hành động thành công

Một sai lầm tinh tế: đăng ký compensator *sau* khi hành động xuôi commit. Nếu hành
động xuôi đã ghi thành công (đã trừ tiền) nhưng lỗi xảy ra trước khi compensator
được ghi vào journal, khi saga rollback sẽ không có thông tin để hoàn tác. Vì vậy
compensator phải được đăng ký *trước*:

```go
// Đăng ký bù trừ trước (giả định hàm đã hỗ trợ release idempotency)
r.saga.Defer("credit_internal_wallet", func(ctx restate.Context) error {
    return r.account.Call().WalletCredit(ctx, accountbiz.WalletCreditParams{
        AccountID: input.Account.ID,
        Amount:    r.internalWalletAmount,
        Type:      "Refund",
        Reference: fmt.Sprintf("tx:%s", walletTxID),
    })
})

// Sau đó mới thực hiện hành động xuôi
if _, err := r.account.Call().WalletDebit(ctx, accountbiz.WalletDebitParams{
    AccountID: input.Account.ID,
    Amount:    r.internalWalletAmount,
    Reference: fmt.Sprintf("tx:%s", walletTxID),
}); err != nil {
    return fmt.Errorf("debit internal wallet: %w", err)
}
```

Compensator phải *idempotent* hoặc kiểm tra sự tồn tại của giao dịch tương ứng, để
nếu debit không thực sự commit nhưng saga vẫn kích hoạt bù trừ, lệnh credit không
cộng tiền ngoài ý muốn.

== Ví dụ thực tế: Saga của luồng Checkout

Workflow checkout đăng ký *năm* compensator theo thứ tự, và khi lỗi terminal sẽ
chạy bù trừ ngược lại:

#table(
  columns: (auto, 1fr, 1fr),
  table.header([Thứ tự nạp], [Hành động xuôi], [Bù trừ]),
  [1], [Phát hành URL thanh toán (nạp đầu, chạy *cuối*)], [Mở khoá / từ chối URL đang chờ],
  [2], [Xoá item khỏi giỏ hàng], [Khôi phục item vào giỏ],
  [3], [Giữ chỗ tồn kho], [Nhả tồn kho],
  [4], [Tạo phiên + giao dịch ví + order item (cùng 1 tx)], [Đánh dấu phiên & giao dịch *thất bại*],
  [5], [Trừ ví nội bộ người mua], [Hoàn ví đúng số tiền],
)

#diag(
  caption: [Sequence — luồng Checkout điều phối bởi CheckoutWorkflow, có nhánh bù trừ saga],
  diagram(
    spacing: (19mm, 10mm),
    node-stroke: 0.6pt,
    node((0, 0), [Buyer], fill: c-soft),
    node((1, 0), text(fill: white)[Order WF], fill: c-primary, stroke: none),
    node((2, 0), [Account / \ Catalog], fill: white),
    node((3, 0), [Inventory], fill: white),
    node((4, 0), [Payment \ Gateway], fill: white),
    edge((0, 0), (0, 8), stroke: (dash: "dashed", paint: c-line)),
    edge((1, 0), (1, 8), stroke: (dash: "dashed", paint: c-line)),
    edge((2, 0), (2, 8), stroke: (dash: "dashed", paint: c-line)),
    edge((3, 0), (3, 8), stroke: (dash: "dashed", paint: c-line)),
    edge((4, 0), (4, 8), stroke: (dash: "dashed", paint: c-line)),
    edge((0, 1), (1, 1), "->", [1. checkout(items)]),
    edge((1, 2), (2, 2), "->", [2. lấy profile + SKU/SPU]),
    edge((2, 2.7), (1, 2.7), "-->", [dữ liệu + tỉ giá]),
    edge((1, 3.5), (2, 3.5), "->", [3. tính giá khuyến mãi]),
    edge((1, 4.3), (3, 4.3), "->", [4. ReserveInventory]),
    edge((3, 5), (1, 5), "-->", [serial_ids]),
    edge((1, 5.8), (4, 5.8), "->", [5. Charge(session)]),
    edge((4, 6.5), (0, 6.5), "->", [6. redirect/QR]),
    edge((4, 7.3), (1, 7.3), "->", [7. webhook: paid]),
    edge((1, 8), (0, 8), "-->", [8. order_ids]),
  ),
)

Khi `pay()` (chờ cổng thanh toán) trả lỗi terminal, saga chạy: hoàn ví → đánh dấu
phiên thất bại → nhả kho → khôi phục giỏ → từ chối URL. Trạng thái trở về *đúng như
trước khi đặt hàng*. Trên nhánh thành công, `saga.Clear()` xoá toàn bộ compensator.

== Lý do chọn Saga

- *Phù hợp luồng dài.* Escrow giữ tiền tới 14 ngày, chờ giao trả tới 14 ngày —
  không thể giữ khoá 2PC suốt thời gian đó. Saga chỉ giữ *danh sách bù trừ*, nhẹ.
- *Tách rời dịch vụ.* Mỗi bù trừ là một lời gọi liên dịch vụ bình thường; không
  dịch vụ nào phải biết chi tiết giao dịch của dịch vụ khác.
- *Đọc tuyến tính.* Logic xuôi và bù trừ nằm cạnh nhau trong cùng một workflow.
- *Phục hồi sạch sau sự cố.* Nhờ journal nối tiếp tiến trình và bù trừ quay lui khi
  lỗi terminal, một đơn hàng dở dang hoặc được hoàn tất, hoặc được quay lui hoàn
  toàn — không kẹt nửa chừng.
