#import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line, font-head
#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge
#import fletcher.shapes: pill

= GIAO TIẾP GIỮA CÁC DỊCH VỤ

== Vấn đề IPC trong kiến trúc hướng dịch vụ

Khi hệ thống bị chia thành nhiều dịch vụ, lời gọi hàm in-process trở thành *giao
tiếp liên tiến trình* (Inter-Process Communication — IPC) qua mạng. IPC kéo theo
ba thách thức kinh điển: mạng *không tin cậy* (gọi có thể lỗi/giật), bên kia *có
thể không sẵn sàng*, và *khó quan sát* xuyên ranh giới. Lý thuyết microservice
phân loại IPC theo hai trục: *đồng bộ vs bất đồng bộ*, và *một-một vs một-nhiều*.

ShopNexus chọn một kiến trúc giao tiếp thống nhất: *mọi* lời gọi — từ client bên
ngoài lẫn giữa các dịch vụ — đều đi qua một *proxy* và *Restate ingress*, thay vì
mỗi dịch vụ tự mở kết nối trực tiếp tới dịch vụ khác.

== Cơ chế: proxy interface + Restate ingress

Mỗi dịch vụ phụ thuộc dịch vụ khác dưới dạng *interface* (hợp đồng), và một *proxy*
sinh tự động (`genrestate`) hiện thực interface đó bằng cách *chuyển tiếp lời gọi
qua HTTP tới Restate ingress*. Nhờ vậy nơi gọi đọc như một lời gọi hàm bình thường,
được kiểm tra kiểu đầy đủ:

```go
// Dịch vụ "order" gọi sang "inventory" qua proxy interface (b.inventory)
results, err := b.inventory.Call().ReserveInventory(ctx, inventorybiz.ReserveInventoryParams{
    Items: items,
})
```

#diag(
  caption: [Mọi lời gọi (ngoài và liên dịch vụ) đều hội tụ qua proxy → Restate ingress → dịch vụ đích],
  diagram(
    spacing: (7mm, 11mm),
    node-stroke: 0.7pt,
    node-corner-radius: 4pt,
    node((0, 0), [Client \ (Web / Mobile)], fill: c-soft, width: 33mm),
    node((2, 0), [Proxy interface], fill: c-mid, width: 36mm),
    edge((0, 0), (2, 0), "->", [HTTP], label-pos: 0.5),
    node((2, 1), text(fill: white)[Restate Ingress \ điều phối · retry · journal], fill: c-primary, stroke: none, width: 46mm, inset: 8pt),
    edge((2, 0), (2, 1), "->", [route]),
    node((0, 2.4), [`order`], fill: white),
    node((1, 2.4), [`catalog`], fill: white),
    node((2, 2.4), [`account`], fill: white),
    node((3, 2.4), [`inventory`], fill: white),
    node((1, 3.2), [`promotion`], fill: white),
    node((2, 3.2), [`analytic`], fill: white),
    node((3, 3.2), [`common`], fill: white),
    node((0, 3.2), [`chat`], fill: white),
    edge((2, 1), (0, 2.4), "->"),
    edge((2, 1), (1, 2.4), "->"),
    edge((2, 1), (2, 2.4), "->"),
    edge((2, 1), (3, 2.4), "->"),
    node((1.5, 4.4), [PostgreSQL — 8 schema (1 schema / dịch vụ)], shape: pill, fill: c-soft, width: 82mm),
  ),
)

*Hai tầng tách rời, giữ tách bạch có chủ đích:*

- *Tách rời thời gian chạy (runtime).* Lời gọi luôn đi qua Restate, nên *nơi* dịch
  vụ đích chạy là không quan trọng — đây là *vị trí trong suốt* (location
  transparency): gọi theo tên, runtime tự định tuyến, cùng binary hay deployment
  riêng, một hay N bản sao sau cân bằng tải — nơi gọi không đổi.
- *Tách rời thời gian biên dịch (compile-time).* Để một dịch vụ deploy mà không cần
  biên dịch code của dịch vụ khác, proxy client cần nằm ở gói `contract` chỉ-có-kiểu;
  hiện proxy vẫn nằm trong `biz` của từng dịch vụ (giới hạn đã ghi nhận).

#grid(
  columns: (1fr),
  figure(image("../assets/flow1.jpg"), caption: [Proxy interface mô phỏng chữ ký của dịch vụ]),
  figure(image("../assets/flow2.jpg"), caption: [Lời gọi liên dịch vụ đi cùng một đường qua Restate ingress]),
)

== Các mẫu giao tiếp: đồng bộ, một chiều và song song

`genrestate` sinh ra ba "mặt" cho mỗi hợp đồng dịch vụ, phủ ba mẫu IPC phổ biến:

#table(
  columns: (auto, auto, 1fr),
  table.header([Mẫu IPC], [API sinh ra], [Khi nào dùng]),
  [Yêu cầu–phản hồi (đồng bộ)], [`Call()`], [Cần kết quả ngay: giữ chỗ kho rồi dùng `serial_ids`.],
  [Một chiều (bất đồng bộ)], [`Send()`], [Bắn-và-quên: ghi nhận tương tác, gửi thông báo — không chặn đường tới hạn.],
  [Tương lai (song song / đua)], [`Future()`], [Phát nhiều lời gọi song song trong một handler rồi gom kết quả.],
)

Vì *mọi* lời gọi đều qua ingress, các thuộc tính bền vững áp dụng *đồng nhất* cho
cả ba mẫu — khác với hệ thống thông thường phải tự cài retry/queue riêng cho từng
loại.

== Durable execution thay cho message queue

Trên thực tế, Restate ingress đóng vai trò *hàng đợi thông điệp* giữa các dịch vụ,
nhưng *không cần* hạ tầng queue/DLQ riêng:

#table(
  columns: (1fr, 2fr),
  table.header([Vấn đề IPC], [Cách Restate xử lý]),
  [Lỗi tạm thời (mạng, DB nghẽn)], [Tự động thử lại với backoff theo cấu hình (khởi đầu 1s, tối đa 30s, tới 10 lần) — *không cần message queue hay DLQ*.],
  [Crash giữa chừng], [Phát lại (replay) từ *journal*; bước đã ghi nhật ký được nối tiếp → tiến trình tiếp tục từ chỗ dừng.],
  [Luồng dài (chờ thanh toán/giao hàng)], [Workflow + Durable Promise giữ trạng thái durable xuyên suốt, sống qua khởi động lại.],
  [Khó quan sát], [Mọi lời gọi có entry trong journal → truy vết thống nhất.],
)

Chính sách thử lại được khai báo tập trung khi đăng ký dịch vụ với runtime:

```go
retryPolicy := restate.WithInvocationRetryPolicy(
    restate.WithInitialInterval(time.Second),
    restate.WithMaxInterval(30*time.Second),
    restate.WithMaxAttempts(10),
    restate.PauseOnMaxAttempts())

srv := server.NewRestate().
    Bind(restate.Reflect(accountbiz.NewAccountService(accountBiz), retryPolicy)).
    Bind(restate.Reflect(orderbiz.NewOrderService(orderBiz), retryPolicy)).
    // ... 8 dịch vụ + 2 workflow ...
    Bind(restate.Reflect(checkoutWf, retryPolicy))
```

== Vì sao chọn điều phối tập trung (orchestration)

ShopNexus chọn *orchestration over choreography*: một workflow trung tâm gọi lần
lượt các dịch vụ, thay vì các dịch vụ tự phản ứng sự kiện của nhau (choreography).
Luồng nghiệp vụ chạy *tuyến tính từ trên xuống*, dễ debug và dễ kiểm thử hơn nhiều
so với việc lần theo các sự kiện rải rác qua nhiều handler. Đây cũng là nền tảng
cho mẫu Saga ở Chương 7.
