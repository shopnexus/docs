#import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge
#import fletcher.shapes: pill

= THIẾT KẾ VÀ PHÁT TRIỂN LOGIC NGHIỆP VỤ

Chương này trình bày cách tổ chức logic nghiệp vụ theo *Domain-Driven Design* (DDD),
cách dùng *sự kiện miền* (domain event) để tách rời các dịch vụ, và cách nền tảng
*durable execution* của Restate mang lại tinh thần *event sourcing* cho các luồng
nghiệp vụ dài.

== Thiết kế logic nghiệp vụ với DDD

=== Bounded context và aggregate

Mỗi dịch vụ trong ShopNexus là một *bounded context* (ngữ cảnh giới hạn) — một mô
hình miền nhất quán, có ngôn ngữ chung riêng. Bên trong mỗi context, dữ liệu được
gom thành các *aggregate* (tổ hợp), là *ranh giới nhất quán giao dịch*: mọi thay
đổi trong một aggregate phải được commit trong cùng một giao dịch cơ sở dữ liệu.

#table(
  columns: (auto, 1fr, 1fr),
  table.header([Aggregate], [Gốc tổ hợp (root)], [Bất biến (invariant) được bảo vệ]),
  [Đơn hàng], [`order` ← `item`], [Item thuộc đúng một order; tổng tiền order = tổng item.],
  [Phiên thanh toán], [`payment_session` ← `transaction`], [Sổ giao dịch append-only; tổng có dấu = số dư phiên.],
  [Tồn kho], [`stock` ← `serial`, `stock_history`], [Tổng `change` trong history = tồn hiện tại; không bán vượt.],
  [Ví], [`wallet` ← bút toán giao dịch ví], [Số dư = tổng bút toán; không âm trừ khi cho phép.],
)

Nguyên tắc DDD then chốt được tuân thủ: *một giao dịch chỉ chạm một aggregate*. Khi
nghiệp vụ cần thay đổi nhiều aggregate ở nhiều dịch vụ (ví dụ checkout chạm cả tồn
kho, ví và đơn hàng), hệ thống *không* mở một giao dịch lớn mà dùng *Saga* (Chương
7) để phối hợp nhiều giao dịch cục bộ — đúng khuyến nghị của Richardson cho
microservice.

=== Logic nghiệp vụ tập trung ở tầng `biz`

Toàn bộ quy tắc nghiệp vụ nằm ở tầng `biz` của mỗi dịch vụ; tầng giao vận chỉ
chuyển đổi request/response, tầng `repo` chỉ truy cập dữ liệu. Cách phân tách này
giữ cho logic miền *thuần khiết*, dễ kiểm thử và không lệ thuộc khung giao vận.

== Phát triển logic với sự kiện miền (event-driven)

Một số tác động nghiệp vụ *không* nằm trên đường tới hạn và nên xảy ra *bất đồng
bộ* sau khi nghiệp vụ chính hoàn tất. ShopNexus phát *sự kiện miền* qua một event
bus nội bộ; các dịch vụ quan tâm tự đăng ký tiêu thụ — đây là kiểu *ghi nhận rồi
phát tán* (record-then-fan-out):

```go
b.storage.Querier().
    CreateBatchInteraction(rctx, args).
    QueryRow(func(_ int, ai analyticdb.AnalyticInteraction, err error) {
        if err == nil {
            event := analyticmodel.Interaction{ /* ... */ }
            // Publish lên topic; observer tự tiêu thụ độc lập.
            if pubErr := bus.Publish(rctx, b.bus, analyticmodel.TopicInteractionCreated, event); pubErr != nil {
                b.logger.Error("publish interaction event", "error", pubErr)
            }
        }
    })
```

Một sự kiện `TopicInteractionCreated` được phát ra, hai dịch vụ tiêu thụ độc lập:
worker tính điểm phổ biến (`analytic.popularity`) và worker cập nhật tìm kiếm của
catalog (`catalog.search`). Bên phát *không biết* ai đang nghe; thêm một bên tiêu
thụ mới chỉ là `Subscribe` thêm một worker — đúng nguyên lý lỏng lẻo ràng buộc.

== Durable execution: tinh thần event sourcing cho luồng dài

*Event sourcing* lưu trạng thái dưới dạng *chuỗi sự kiện* để có thể tái dựng và
phục hồi. Restate mang lại tinh thần tương tự ở mức *thực thi*: nó ghi *nhật ký*
(journal) mọi hiệu ứng phụ của một workflow; khi tiến trình sập và khởi động lại,
nó *phát lại* (replay) workflow từ journal — bước đã hoàn tất trả kết quả từ nhật
ký thay vì chạy lại. Nhờ đó luồng nghiệp vụ được viết *tuyến tính như mã đồng bộ
bình thường* nhưng vẫn sống sót qua sự cố.

#table(
  columns: (auto, 1fr),
  table.header([Nguyên thủy Restate], [Vai trò]),
  [`restate.Run` / `RunVoid`], [Bọc một side-effect (ghi DB, gọi cổng) thành *bước có nhật ký*; phát lại bỏ qua thân hàm và trả kết quả đã ghi.],
  [`restate.UUID(ctx)`], [Sinh UUID *ổn định*: lần đầu tạo mới, mọi lần phát lại trả đúng UUID đó → ID nhất quán cho bản ghi tạo trong workflow.],
  [`restate.Promise[T]`], [*Durable Promise* — điểm chờ durable, định danh bằng chuỗi; bên ngoài (webhook, quyết định người bán) `Resolve` để đánh thức.],
  [`restate.After`], [Hẹn giờ durable (durable timer) — thay cho cron/`sleep`; sống sót qua khởi động lại.],
  [`restate.Set` / `Get`], [Đọc/ghi trạng thái durable của workflow theo khoá.],
  [`restate.Key(ctx)`], [Khoá định danh workflow (= session ID / order ID), gom mọi lời gọi cùng một đơn về một thực thể durable.],
)

Một bước durable điển hình — kết quả được ghi journal để phát lại nối tiếp:

```go
txID, err := restate.Run(ctx, func(rctx restate.RunContext) (uuid.UUID, error) {
    id := uuid.New()
    if err := b.storage.Querier().CreateTransaction(rctx, /* ... */); err != nil {
        return uuid.Nil, err
    }
    return id, nil
})
```

== Sổ cái append-only: sự kiện tài chính bất biến

Tinh thần event sourcing còn thể hiện ở *mô hình dữ liệu*: bảng `order.transaction`
là một *sổ cái chỉ-ghi-thêm* (append-only ledger). Mỗi biến động tiền là một bút
toán có dấu (dương = nạp/hoàn, âm = trừ); *không bao giờ sửa hay xóa* bút toán cũ.
Số dư của một phiên là *tổng* các bút toán — y hệt cách event sourcing tái dựng
trạng thái từ chuỗi sự kiện. Mô hình này cho hai lợi ích quan trọng với hệ TMĐT:
*kiểm toán được* (mọi đồng tiền có vết) và *idempotent* (bút toán trùng `reference`
bị chặn, an toàn khi saga thử lại).
