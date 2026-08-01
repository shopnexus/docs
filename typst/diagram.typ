// ============================================================
//  diagram.typ — SƠ ĐỒ KIẾN TRÚC & SƠ ĐỒ LỚP hệ thống ShopNexus
//
//  Nguồn đối chiếu (source of truth): kho `shopnexus/server`
//    · internal/module/<m>/migrations/*.sql   — lược đồ CSDL từng module
//    · internal/module/<m>/domain/*.go        — thực thể + quy tắc nghiệp vụ
//    · internal/module/<m>/api/api.go         — giao diện Service công bố
//    · internal/module/<m>/port/port.go       — giao diện Repository
//    · internal/{gateway,infra,provider}/     — tầng vận chuyển & hạ tầng
//
//  Tài liệu này KHÔNG lấy lược đồ từ Báo cáo định kỳ lần 2: bản trong báo cáo
//  đó mô tả 7 vi dịch vụ (account/catalog/chat/order/inventory/analytic/common)
//  còn mã nguồn hiện tại là *modular monolith* 7 module + 1 module quan trắc,
//  kho hàng đã nhập vào `catalog`, tiền tệ tách ra `finance`, đánh giá/uy tín
//  tách ra `trust`, và phân tích số liệu sản phẩm chuyển ra ngoài backend.
//
//  Biên dịch:
//    cd typst && typst compile --root . --font-path common/fonts \
//                              diagram.typ out/diagram.pdf
// ============================================================
#import "common/style-a4.typ": *

#show: a4.with(
  tieu-de: "SƠ ĐỒ KIẾN TRÚC VÀ SƠ ĐỒ LỚP",
  phu-de: "Đối chiếu mã nguồn shopnexus/server",
  chay: "Sơ đồ kiến trúc & sơ đồ lớp ShopNexus",
)

// ------------------------------------------------------------
//  Hộp lớp UML cho fletcher (cục bộ cho tệp này; không phải design token
//  nên không đưa vào common/tokens.typ).
//
//  Dùng:  #cls((0, 1), "Account", stereo: "aggregate root",
//               attrs: ("- id: int64", "- status: Status"),
//               ops:   ("+ Validate() error",),
//               name: <acc>)
//
//  Ngăn 1: tên lớp (kèm stereotype tùy chọn) — Ngăn 2: thuộc tính —
//  Ngăn 3: phương thức. Ba ngăn phân cách bằng nét mảnh, đúng quy ước UML.
// ------------------------------------------------------------
#let cls(p, ten, attrs: (), ops: (), stereo: none, ..a) = {
  let dau = if stereo == none {
    align(center, text(size: 8.4pt, weight: 700, ten))
  } else {
    align(center, stack(
      spacing: 1.5pt,
      text(size: 6.4pt, style: "italic", fill: muted, "«" + stereo + "»"),
      text(size: 8.4pt, weight: 700, ten),
    ))
  }
  let o = (dau,)
  if attrs.len() > 0 {
    o.push(stack(spacing: 2.4pt, ..attrs.map(x => text(size: 6.8pt, raw(x)))))
  }
  if ops.len() > 0 {
    o.push(stack(spacing: 2.4pt, ..ops.map(x => text(size: 6.8pt, raw(x)))))
  }
  node(
    p,
    table(
      columns: 1,
      inset: (x: 6pt, y: 4pt),
      align: left,
      fill: none,
      stroke: (x, y) => (top: if y == 0 { 0pt } else { 0.5pt + hairline }),
      ..o,
    ),
    shape: rect, fill: white, stroke: 0.9pt + ink, inset: 0pt, ..a,
  )
}

// Nhãn quan hệ cỡ nhỏ, dùng lặp lại trên các cạnh sơ đồ lớp
#let rel(t) = text(size: 6.6pt, t)

#note[
  *Phạm vi.* Tài liệu gồm hai phần: (1) sơ đồ kiến trúc hệ thống — khung triển
  khai, khung phân lớp bên trong một module và luồng sự kiện – quan trắc;
  (2) sơ đồ lớp *chia theo từng module*, vì toàn hệ thống có 47 bảng nghiệp vụ nên
  một sơ đồ lớp duy nhất sẽ không đọc được. Mỗi sơ đồ lớp đi kèm một bảng đối
  chiếu *lớp miền ↔ bảng CSDL ↔ trách nhiệm* để truy vết được từ bản vẽ xuống
  tập lệnh DDL.
]

= Sơ đồ kiến trúc hệ thống (System Architecture)

== Quyết định kiến trúc nền tảng

ShopNexus được hiện thực theo mô hình *modular monolith* — một tiến trình Go
duy nhất (`cmd/gateway`) chứa bảy module nghiệp vụ tự chứa cùng một module quan
trắc. Mỗi module là một *hexagon thực dụng*: nó sở hữu riêng một lược đồ
(schema) PostgreSQL và được cấp một chuỗi kết nối riêng, nhờ đó có thể tách ra
cơ sở dữ liệu riêng — và sau đó là tiến trình riêng — mà không phải sửa lại mô
hình dữ liệu. Đây là điểm khác biệt căn bản so với bản thiết kế trong Báo cáo
định kỳ lần 2: hệ thống giữ nguyên *ranh giới* của kiến trúc vi dịch vụ nhưng
lùi lại một bước về *đơn vị triển khai*, để tránh trả giá vận hành cho bảy tiến
trình khi lưu lượng chưa đòi hỏi.

Bốn hệ quả trực tiếp của quyết định này, và chúng chi phối mọi sơ đồ phía sau:

- *Không có khóa ngoại xuyên module.* `order.item` giữ `listing_id` như một số
  nguyên trần, `trust.review` giữ `seller_id` tương tự. Quan hệ liên module trên
  sơ đồ lớp vì vậy được vẽ bằng *nét đứt* và ghi chú `cross-ref`, còn quan hệ
  nội module vẽ nét liền vì có ràng buộc khóa ngoại thật.
- *Phụ thuộc một chiều `adapter → port → domain`.* Gói `domain` không nhập khẩu
  pgx/http/fx; gói `api` chỉ nhập khẩu `context`. Module khác phụ thuộc vào
  `api.Service` chứ không vào lớp hiện thực.
- *Dữ liệu phi chuẩn hóa là có chủ đích.* `catalog.listing.cached_rating`,
  `cached_review_count` và `cached_sold` là bản sao được duy trì chủ động, vì
  `trust` và `catalog` nằm ở hai lược đồ khác nhau nên không thể `JOIN`.
- *Thực thi bền vẫn giữ nguyên.* Ba luồng tiền của module `order` chạy trên
  *Restate* (`OrderCheckout`, `OrderLifecycle`, `OrderRefund`), đúng như quyết
  định kiến trúc đã chốt ở báo cáo lần 1.

== Kiến trúc triển khai tổng thể

#fig(
  [Sơ đồ kiến trúc triển khai hệ thống ShopNexus (Deployment / Container View)],
  spacing: (17mm, 10mm),

  // ---- Tầng khách ----
  np((0, 0), [Website người dùng\ #text(size: 7pt)[Next.js]]),
  np((0, 1), [Ứng dụng di động\ #text(size: 7pt)[Flutter]]),
  np((0, 2), [Bảng điều khiển\ Quản trị / Kiểm duyệt]),

  edge((0, 0), (1.4, 1), "-|>"),
  edge((0, 1), (1.4, 1), "-|>", text(size: 7pt)[HTTPS · JSON]),
  edge((0, 2), (1.4, 1), "-|>"),

  // ---- Cổng vào ----
  ncore((1.4, 1), [*HTTP Gateway*\ #text(size: 7pt)[`net/http` ServeMux · `/api/v1`\ handler mỏng · gwctx\ JWT · RBAC · nhật ký · telemetry]]),

  // ---- Bảy module nghiệp vụ ----
  edge((1.4, 1), (3, -1), "-|>"),
  edge((1.4, 1), (3, 0), "-|>"),
  edge((1.4, 1), (3, 1), "-|>", text(size: 7pt)[gọi `api.Service`]),
  edge((1.4, 1), (3, 2), "-|>"),
  edge((1.4, 1), (3, 3), "-|>"),
  edge((1.4, 1), (3, 4), "-|>"),

  np((3, -1), [`account`]),
  np((3, 0), [`catalog`]),
  np((3, 1), [`order` #text(size: 7pt)[(bền)]]),
  np((3, 2), [`finance`]),
  np((3, 3), [`trust`]),
  np((3, 4), [`chat`]),
  np((3, 5), [`observability`]),

  // ---- Lưu trữ ----
  edge((3, -1), (4.7, 1), "-|>"),
  edge((3, 0), (4.7, 1), "-|>"),
  edge((3, 1), (4.7, 1), "-|>"),
  edge((3, 2), (4.7, 1), "-|>", text(size: 7pt)[pgx + SQL viết tay]),
  edge((3, 3), (4.7, 1), "-|>"),
  edge((3, 4), (4.7, 1), "-|>"),
  edge((3, 5), (4.7, 4.4), "-|>"),

  ng((4.7, 1), [*PostgreSQL 18 + TimescaleDB*\ #text(size: 7pt)[một *schema* riêng mỗi module\ (DSN riêng, tách CSDL được)\ pgvector · PostGIS · pg#[\_]trgm]]),
  ng((4.7, 4.4), [*Hypertable quan trắc*\ #text(size: 7pt)[`http_requests`, `provider_calls`,\ `runtime_metrics`, `business_events`\ + continuous aggregate 1 phút]]),

  // ---- Hạ tầng ngang ----
  nt((1.4, 3), [*Restate*\ #text(size: 7pt)[thực thi bền\ 3 workflow của `order`]]),
  edge((3, 1), (1.4, 3), "<->", stroke: (dash: "dashed"), rel[RPC bền]),

  nt((1.4, 4.4), [*Redis*\ #text(size: 7pt)[Streams: sự kiện miền\ + bộ nhớ đệm]]),
  edge((3, 0), (1.4, 4.4), "<->", stroke: (dash: "dashed")),
  edge((3, 3), (1.4, 4.4), "<->", stroke: (dash: "dashed"), rel[pub/sub]),

  nt((3, 6.2), [*NATS JetStream*\ #text(size: 7pt)[kênh telemetry (at-least-once)]]),
  edge((3, 5), (3, 6.2), "<->", stroke: (dash: "dashed")),

  // ---- Bên thứ ba ----
  ng((4.7, -1), [*Nhà cung cấp ngoài*\ #text(size: 7pt)[payment · transport · KYC\ OAuth/OIDC · LLM · notify\ storage (S3/MinIO)]]),
  edge((3, 2), (4.7, -1), "<->", rel[cổng thanh toán]),
  edge((3, -1), (4.7, -1), "<->", rel[OAuth · KYC · SMS/e-mail]),

  // ---- Quan trắc ----
  ng((4.7, 6.2), [*Grafana*\ #text(size: 7pt)[← Loki ← Alloy (nhật ký)\ ← PostgreSQL (số đo)]]),
  edge((4.7, 4.4), (4.7, 6.2), "-|>", stroke: (dash: "dashed")),
  edge((3, 6.2), (4.7, 6.2), "-|>", stroke: (dash: "dashed")),
)

#note[
  *Đọc sơ đồ.* Nét liền là lời gọi đồng bộ trong tiến trình hoặc qua HTTP; nét
  đứt là kênh bất đồng bộ (hàng đợi, luồng sự kiện, RPC bền). Toàn bộ khối
  `account`…`chat` nằm *trong cùng một tiến trình* `cmd/gateway` và được lắp ráp
  bằng Uber `fx`; đường kẻ giữa chúng và Gateway là lời gọi giao diện Go, không
  phải lời gọi mạng. Ranh giới lược đồ CSDL mới là thứ giữ cho các module tách
  rời được về sau.
]

#figure(
  caption: [Phân rã module nghiệp vụ và trách nhiệm cốt lõi],
  table(
    columns: (1fr, 1fr, 2.9fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Module], [Lược đồ CSDL], [Trách nhiệm cốt lõi]),

    [`account`], [`account`],
    [Danh tính và xác thực (mật khẩu + OAuth/OIDC), RBAC ba vai trò, hồ sơ công
     khai kiêm trang cửa hàng, sổ địa chỉ, thiết bị đẩy, thông báo và tùy chọn
     kênh nhận, xác minh giấy tờ tùy thân cho chi trả, đồ thị theo dõi người bán.],

    [`catalog`], [`catalog`],
    [Bài đăng và biến thể mua được, cây danh mục, từ khóa, *tồn kho* (giữ chỗ –
     bán – hoàn), danh sách yêu thích, và trạng thái đồng bộ vector cho tìm kiếm
     lai (dense + sparse BGE-M3).],

    [`order`], [`order`],
    [Giỏ hàng, phiên mua hàng đóng băng điều khoản, thương lượng giá (offer),
     đơn hàng, vận đơn, hoàn tiền và hai vòng phân xử tranh chấp.],

    [`finance`], [`finance`],
    [Toàn bộ nguyên thủy tiền tệ đặt chung một nơi để bảo toàn tính nguyên tử:
     phiên thanh toán, sổ cái giao dịch trên kênh ngoài, ví theo cặp
     (tài khoản, tiền tệ) với số dư khả dụng/tạm giữ, sổ cái ví, tài khoản ngân
     hàng và mã số thuế.],

    [`trust`], [`trust`],
    [Đánh giá hai chiều sau giao dịch (ẩn cho tới khi công bố), nhận xét sản
     phẩm kèm phản hồi và phiếu hữu ích, tổng hợp uy tín theo vai trò, và tố cáo
     đa hình kèm quy trình xử lý của kiểm duyệt viên.],

    [`chat`], [`chat`],
    [Hội thoại 1–1 giữa hai tài khoản, tin nhắn người dùng và tin nhắn hệ thống,
     đính kèm và thẻ tham chiếu (bài đăng, đơn hàng, thẻ thương lượng giá).],

    [`observability`], [`observability`],
    [Quan trắc vận hành cắt ngang: RED vào/ra, số đo runtime Go, bản sao sự kiện
     nghiệp vụ. Không có `api/` — không module nào gọi nó.],

    [(dùng chung)], [(mọi lược đồ)],
    [DDL dùng chung được `cmd/migrate` áp vào *từng* lược đồ: `audit_log`,
     `resource`, `option`. Không phải một bảng toàn cục — nếu chung, đó sẽ là
     thứ duy nhất không thể đi theo module khi tách CSDL.],
  ),
)

== Kiến trúc phân lớp bên trong một module

Mọi module đều có cùng một hình dạng thư mục, và chiều phụ thuộc là bất biến
kiến trúc quan trọng nhất của hệ thống: mũi tên chỉ đi từ ngoài vào trong, không
bao giờ ngược lại.

#fig(
  [Kiến trúc hexagon phân lớp của một module điển hình (Component Diagram)],
  spacing: (30mm, 12mm),

  np((0, 0), [Client]),
  edge((0, 0), (1, 0), "-|>", text(size: 7.5pt)[HTTPS]),
  ncore((1, 0), [*Gateway* — `internal/gateway`\ #text(size: 7pt)[router · handler mỏng · middleware]]),
  nr((2.3, 0), text(size: 7.2pt)[Lớp cắt ngang:\ `errx` (lỗi có mã) · `httpx`\ `id` (mã hóa khóa) · `token`\ `validation` · `logger`]),

  edge((1, 0), (1, 1), "-|>", text(size: 7.5pt)[gọi giao diện]),
  np((1, 1), [*`api`* — hợp đồng công bố\ #text(size: 7pt)[`Service` interface + DTO\ chỉ nhập khẩu `context`]]),

  edge((1, 1), (1, 2), "-|>", text(size: 7.5pt)[hiện thực]),
  np((1, 2), [*`service.go`* — điều phối\ #text(size: 7pt)[nơi duy nhất ghép `domain` + `port`]]),

  edge((1, 2), (0, 2), "-|>", text(size: 7.5pt)[dùng]),
  np((0, 2), [*`domain`*\ #text(size: 7pt)[thực thể · bất biến nghiệp vụ\ toàn bộ lỗi của module\ không nhập khẩu pgx/http/fx]]),

  edge((1, 2), (1, 3), "-|>", text(size: 7.5pt)[gọi qua cổng]),
  np((1, 3), [*`port`* — `Repository` interface]),

  edge((1, 3), (1, 4), "-|>", text(size: 7.5pt)[hiện thực]),
  np((1, 4), [*`adapter/postgres`*\ #text(size: 7pt)[pgx `NamedArgs` + SQL viết tay\ không ORM, không sqlc]]),

  edge((1, 4), (2.3, 4), "-|>", text(size: 7.5pt)[SQL]),
  ng((2.3, 4), [PostgreSQL\ #text(size: 7pt)[lược đồ riêng của module]]),

  edge((1, 2), (2.3, 2), "<->", stroke: (dash: "dashed"), text(size: 7.5pt)[sự kiện · RPC]),
  ng((2.3, 2), [Module khác qua `api.Service`\ #text(size: 7pt)[hoặc `bus.Client` / Restate]]),

  edge((0, 4), (1, 4), "-|>", text(size: 7.5pt)[lắp ráp]),
  nt((0, 4), [*`fx.go`* — Uber fx\ #text(size: 7pt)[`fx.As(new(port.Repository))`\ `fx.As(new(<m>api.Service))`]]),
)

#note[
  *Bất biến.* Lớp trên gọi xuống lớp dưới, không có lời gọi ngược. `service.go`
  không bao giờ tự viết câu lệnh SQL, `adapter/postgres` không chứa quy tắc
  nghiệp vụ — nhờ đó mọi bất biến của `domain` kiểm thử đơn vị được mà không cần
  cơ sở dữ liệu. Việc lắp ráp phụ thuộc là *tự động theo kiểu giao diện*: khi
  `catalog` khai báo cần `accountapi.Service`, `fx` nối đúng lớp hiện thực mà
  `account` đã cung cấp, nên hai module không hề biết tên gói của nhau.
]

== Luồng bất đồng bộ, thực thi bền và quan trắc

Hệ thống dùng *hai* bus khác nhau, phân biệt bằng kiểu Go chứ không bằng cấu
hình: sự kiện miền đi qua giao diện `eventbus.Client` (Redis Streams), còn dữ
liệu quan trắc đi qua kiểu cụ thể `*eventbus.NATS` (JetStream). Nhầm giao diện ở
đây sẽ nối bộ ghi telemetry vào sai bus mà không hề báo lỗi.

#fig(
  [Luồng thực thi bền, sự kiện miền và đường ống quan trắc],
  spacing: (26mm, 12mm),

  // Nhánh 1 — thực thi bền
  np((0, 0), [`order` service]),
  edge((0, 0), (1.3, 0), "-|>", rel[gọi bền]),
  nt((1.3, 0), [*Restate*\ #text(size: 7pt)[nhật ký thực thi (journal)]]),
  edge((1.3, 0), (2.8, 0), "-|>"),
  np((2.8, 0), [`OrderCheckout`\ `OrderLifecycle`\ `OrderRefund`\ #text(size: 7pt)[hẹn giờ 48h/72h · thử lại]]),
  edge((2.8, 0), (0, 0), "-|>", bend: -32deg, rel[gọi ngược `api.Service`]),

  // Nhánh 2 — sự kiện miền
  np((0, 1.3), [Module phát sinh\ #text(size: 7pt)[`order.placed`, …]]),
  edge((0, 1.3), (1.3, 1.3), "-|>"),
  nt((1.3, 1.3), [*Redis Streams*\ #text(size: 7pt)[`eventbus.Client`]]),
  edge((1.3, 1.3), (2.8, 1.3), "-|>", rel[subscribe]),
  np((2.8, 1.3), [`trust` (uy tín)\ `catalog` (đồng bộ vector)\ `account` (thông báo)]),

  // Nhánh 3 — quan trắc
  np((0, 2.6), [`Sink` #text(size: 7pt)[(middleware,\ observer, sampler)]]),
  edge((0, 2.6), (1.3, 2.6), "-|>", rel[publish, best-effort]),
  nt((1.3, 2.6), [*NATS JetStream*\ #text(size: 7pt)[bền, at-least-once]]),
  edge((1.3, 2.6), (2.8, 2.6), "-|>", rel[theo lô]),
  np((2.8, 2.6), [`subscribeWriter`\ #text(size: 7pt)[`COPY` vào hypertable]]),
  edge((2.8, 2.6), (2.8, 3.6), "-|>"),
  ng((2.8, 3.6), [Grafana\ #text(size: 7pt)[đọc thẳng PostgreSQL]]),

  // Nhánh 4 — nhật ký
  np((0, 3.6), [Nhật ký ứng dụng\ #text(size: 7pt)[JSON ra stdout]]),
  edge((0, 3.6), (1.3, 3.6), "-|>"),
  nt((1.3, 3.6), [Alloy → Loki]),
  edge((1.3, 3.6), (2.8, 3.6), "-|>"),
)

#note[
  *Ba cơ chế chống trùng lặp* xuất hiện lặp lại trong các sơ đồ lớp phía sau, vì
  mọi kênh ở đây đều là *at-least-once*: khóa lũy đẳng của người gọi
  (`catalog.stock_movement.key`, `finance.wallet_transaction.idempotency_key`),
  chỉ mục duy nhất trên tham chiếu của nhà cung cấp
  (`finance.transaction.provider_ref`), và bảng ghi nhận đã-xử-lý
  (`trust.order_outcome`). Riêng bảng quan trắc *chấp nhận* trùng lặp — khử
  trùng trên đường ghi nóng đắt hơn cái giá của một mẫu bị đếm hai lần.
]

= Sơ đồ lớp theo từng module (Class Diagrams)

Hệ thống có 47 bảng nghiệp vụ (chưa kể ba bảng DDL dùng chung được áp vào mọi
lược đồ), nên sơ đồ lớp được chia theo *ranh giới module* —
cũng chính là ranh giới lược đồ CSDL. Quy ước dùng thống nhất cho cả bảy sơ đồ:

- Hộp lớp gồm ba ngăn: *tên lớp* (kèm khuôn mẫu `«…»`), *thuộc tính*, *phương
  thức*. Thuộc tính ghi `-`, phương thức công khai ghi `+`.
- *Nét liền* giữa hai lớp: quan hệ nội module, có ràng buộc khóa ngoại thật
  trong DDL. Bội số ghi ở hai đầu cạnh.
- *Nét đứt* kèm nhãn `cross-ref`: tham chiếu liên module, chỉ là số nguyên trần,
  *không* có khóa ngoại — cơ sở dữ liệu không kiểm tra hộ, tầng nghiệp vụ phải
  tự giữ.
- Khuôn mẫu `«aggregate root»` đánh dấu lớp là *gốc tập hợp*: chỉ nó được nạp và
  ghi như một khối, và bất biến nào trải rộng qua nó với lớp con thì thuộc về nó.

== Module `account` — Danh tính, hồ sơ và thông báo

Gốc tập hợp duy nhất của module là `Account` = {`Account`, `OAuthIdentity[]`}:
bất biến "phải còn ít nhất một cách đăng nhập" trải qua cả mật khẩu lẫn danh
tính liên kết, nên `OAuthIdentity` là lớp con. `Contact`, `Device` và
`IdentityDocument` *không* phải lớp con dù đều mang `account_id` — không có quy
tắc nào trải qua chúng với gốc, và gộp tất cả vào một gốc sẽ khiến một thao tác
đổi tên hiển thị phải nạp cả một hypertable.

#fig(
  [Sơ đồ lớp module `account`],
  spacing: (10mm, 7mm),

  cls((0, 0), "accountapi.Service", stereo: "interface", name: <a-svc>,
    ops: (
      "+ Register / Login / LoginOAuth",
      "+ Refresh / Logout",
      "+ GetMe / UpdateMe / UpdateProfile",
      "+ ListContacts / CreateContact / …",
      "+ RegisterDevice / ListDevices",
      "+ ListNotifications / MarkNotificationsRead",
      "+ Follow / Unfollow",
      "+ StartIdentityVerification",
      "+ AdminSuspendAccount / AdminCreateModerator",
      "  … 46 phương thức",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <a-repo>,
    ops: (
      "+ Create / Get / Save",
      "+ GetByIdentifier / GetByEmail / GetByOAuth",
      "+ SearchAccounts / FindProfile",
      "+ InsertContact / ListContacts",
      "+ UpsertDevice / ListDevices",
      "+ ListNotifications / CountUnreadNotifications",
      "+ InsertFollow / DeleteFollow",
      "+ InsertIdentityDocument / UpdateIdentityVerdict",
      "+ InsertAuditLog",
    )),
  edge(<a-svc>, <a-repo>, "-->", rel[dùng]),

  cls((1, 1), "Account", stereo: "aggregate root", name: <a-acc>,
    attrs: (
      "- id: int64",
      "- version: int64        // khóa lạc quan",
      "- status: Status        // active | suspended",
      "- role: Role            // user | moderator | admin",
      "- phone, email, username: *string",
      "- passwordHash: *string",
      "- emailVerified: bool",
      "- suspendedUntil: *time, suspensionReason: *string",
      "- name, description, gender, dateOfBirth",
      "- country, locale, timezone: string",
      "- avatarResourceID: *int64",
    ),
    ops: (
      "+ Validate() error",
      "+ HasIdentifier() / HasPassword() bool",
      "+ SignInMethods() int",
      "+ IsSuspended(now) bool",
      "+ SetEmail / ClearEmail  (…Phone, …Username)",
      "+ SetPassword / MarkEmailVerified",
      "+ Suspend(reason, until) / Reinstate()",
      "+ SetRole(role)",
      "+ Link(provider, uid) / Unlink(provider)",
      "+ Snapshot() / Events() / ClearEvents()",
    )),
  edge(<a-svc>, <a-acc>, "-->", rel[điều phối]),
  edge(<a-repo>, <a-acc>, "-->", rel[nạp / ghi]),

  cls((0, 2), "OAuthIdentity", name: <a-oauth>,
    attrs: (
      "- id, accountID: int64",
      "- provider: string     // google | facebook | …",
      "- providerUID: string  // không bao giờ là e-mail",
      "- createdAt: time",
    )),
  edge(<a-acc>, <a-oauth>, "-", rel[1 → 0..\*  «composition»]),

  cls((1, 2), "Contact", name: <a-contact>,
    attrs: (
      "- id, accountID: int64",
      "- fullName, phone: string",
      "- phoneVerified: bool",
      "- addressType: AddressType",
      "- isDefaultDelivery, isDefaultPickup: bool",
      "- country/province/district/ward (mã + tên)",
      "- providerCodes: jsonb  // mã vùng theo hãng vận chuyển",
      "- address, addressDetail: string",
      "- location: geography(Point, 4326)",
    ),
    ops: ("+ Validate() error", "+ SetPhone(phone)")),
  edge(<a-acc>, <a-contact>, "-", rel[1 → 0..\*]),

  cls((2, 2), "Device", name: <a-dev>,
    attrs: (
      "- id, accountID: int64",
      "- platform: Platform  // ios | android | web",
      "- pushToken: string   // UNIQUE toàn cục",
      "- lastSeenAt: time",
    ),
    ops: ("+ TokenSuffix() string", "+ Owns(accountID) bool")),
  edge(<a-acc>, <a-dev>, "-", rel[1 → 0..\*]),

  cls((0, 3), "IdentityDocument", name: <a-kyc>,
    attrs: (
      "- id, accountID: int64",
      "- docType: DocType",
      "- provider, providerRef: string",
      "- status: IdentityStatus",
      "- rejectionReason: *string",
      "- verifiedAt, expiresAt: *time",
    ),
    ops: (
      "+ IsLive(now) bool",
      "+ Verify(now, expiresAt)",
      "+ Reject(reason)",
      "+ Snapshot()",
    )),
  edge(<a-acc>, <a-kyc>, "-", rel[1 → 0..\*]),

  cls((1, 3), "Notification", stereo: "hypertable", name: <a-noti>,
    attrs: (
      "- id, accountID: int64",
      "- category: Category",
      "- title: string, payload: jsonb",
      "- createdAt: time  // khóa phân mảnh",
      "- readAt, scheduledAt: *time",
    )),
  edge(<a-acc>, <a-noti>, "-", rel[1 → 0..\*]),

  cls((2, 3), "Preference", name: <a-pref>,
    attrs: (
      "- accountID: int64  ⎫",
      "- category: Category ⎬ khóa chính",
      "- channel: Channel   ⎭",
      "- isEnabled: bool",
    )),
  edge(<a-acc>, <a-pref>, "-", rel[1 → 0..\*  (thưa)]),

  cls((0, 4), "Profile", stereo: "value object", name: <a-prof>,
    attrs: (
      "- name, description: string",
      "- gender: *Gender, dateOfBirth: *date",
      "- avatarResourceID: *int64",
    ),
    ops: ("+ Validate() error",)),
  edge(<a-acc>, <a-prof>, "--", rel[đọc trên chính cột của `account`]),

  cls((1, 4), "Follow", name: <a-follow>,
    attrs: ("- followerID, followeeID: int64  // khóa chính", "- createdAt: time")),
  edge(<a-acc>, <a-follow>, "-", rel[0..\* ↔ 0..\*]),

  cls((2, 4), "Event", stereo: "domain event", name: <a-evt>,
    attrs: ("- code: EventCode", "- payload: any"),
    ops: ("  EmailChanged · Suspended · Reinstated", "  RoleGranted · IdentityLinked · …")),
  edge(<a-acc>, <a-evt>, "-->", rel[phát sinh]),
)

#figure(
  caption: [Đối chiếu lớp miền – bảng CSDL – trách nhiệm, module `account`],
  table(
    columns: (1fr, 1fr, 2.4fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Lớp miền], [Bảng], [Ghi chú thiết kế]),
    [`Account`], [`account`],
    [Gộp luôn phần hiển thị (tên, mô tả, giới tính, ngày sinh, ảnh đại diện) —
     bảng `profile` 1–1 bắt buộc đã bị nhập vào đây vì hai nửa luôn được ghi
     cùng một câu lệnh. Ràng buộc `account_has_identifier` bảo đảm luôn còn ít
     nhất một định danh đăng nhập.],
    [`OAuthIdentity`], [`oauth_identity`],
    [Cố tình *không* giữ e-mail riêng: e-mail do nhà cung cấp khẳng định được
     đối chiếu với `account.email` và hợp nhất vào tài khoản đó.],
    [`Contact`], [`contact`],
    [Mã hành chính là nguồn sự thật cho API hãng vận chuyển; `location` chỉ là
     gợi ý cho chặng cuối và khuyến mãi theo bán kính.],
    [`Device`], [`device`],
    [`push_token` UNIQUE *toàn cục* chứ không theo tài khoản: token định danh
     một lần cài đặt và di chuyển giữa các tài khoản.],
    [`Notification`], [`notification`],
    [Hypertable, mảnh 7 ngày, giữ 180 ngày. Không có bảng trạng thái gửi theo
     kênh — việc phát tán là workflow bền, Restate đã giữ nhật ký đó.],
    [`Preference`], [`notification_preference`],
    [*Thưa*: chỉ tồn tại dòng khi tài khoản lệch khỏi mặc định; "không có dòng"
     nghĩa là dùng mặc định (mặc định nằm ở tầng miền).],
    [`IdentityDocument`], [`identity_document`],
    [Không lưu số giấy tờ và không lưu ảnh chụp — chỉ giữ phán quyết của nhà
     cung cấp KYC, nên rò rỉ bảng này không mạo danh được ai.],
    [`Follow`], [`follow`],
    [Cả hai phía đều là tài khoản, vì bất kỳ ai cũng có thể bán.],
  ),
)

== Module `catalog` — Bài đăng, biến thể, tồn kho và vector

`Listing` là gốc tập hợp: biến thể, ảnh, từ khóa và bản sửa chờ duyệt đều được
nạp và ghi cùng nó dưới một khóa lạc quan `version`. `Stock` cố ý *không* phải
cột của `Variant` dù quan hệ 1–1: `reserved` biến động theo từng lượt thanh toán
(nóng, tranh chấp cao) còn dòng `variant` chỉ đổi khi người bán sửa bài — gộp
lại thì mỗi lượt giữ chỗ sẽ đụng vào đúng dòng đang nuôi chỉ mục giá.

#fig(
  [Sơ đồ lớp module `catalog`],
  spacing: (10mm, 7mm),

  cls((0, 0), "catalogapi.Service", stereo: "interface", name: <c-svc>,
    ops: (
      "+ ListListings / GetListing / CreateListing",
      "+ UpdateListing / DeleteListing",
      "+ PublishListing / HideListing",
      "+ CreateVariant / UpdateVariant / DeleteVariant",
      "+ ListCategories / ListTags",
      "+ AddFavorite / RemoveFavorite",
      "+ ReserveStock / ReleaseStock",
      "+ CommitStock / UncommitStock",
      "+ AdminApproveListing / AdminTakedownListing",
      "+ SyncListingRating",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <c-repo>,
    ops: (
      "+ CreateListing / GetListing / SaveListing",
      "+ GetListingForSeller / SoftDeleteListing",
      "+ ListListings / ListModerationQueue",
      "+ SeedVectors / NearestCategories / NearestTags",
      "+ InterestVectors / FavoritedAmong",
      "+ ReserveStock / ReleaseStock",
      "+ CommitStock / UncommitStock / FindStock",
      "+ SetCachedRating",
    )),
  edge(<c-svc>, <c-repo>, "-->", rel[dùng]),

  cls((1, 1), "Listing", stereo: "aggregate root", name: <c-lst>,
    attrs: (
      "- id, version: int64",
      "- slug: string  // duy nhất toàn cục",
      "- accountID: int64   // cross-ref account",
      "- categoryID: int64",
      "- status: Status  // draft|pending|active|hidden",
      "- name, description: string",
      "- specifications: jsonb",
      "- attachments: []int64  // ảnh đầu là ảnh bìa",
      "- priceMode: PriceMode, condition: Condition",
      "- currency: string  // ISO 4217",
      "- pendingEdit: *PendingEdit",
      "- cachedRating, cachedReviewCount, cachedSold",
      "- deletedAt, embeddingStaleAt: *time",
    ),
    ops: (
      "+ Validate() error",
      "+ LiveVariants() []*Variant",
      "+ Publish() / Approve(note) / Hide()",
      "+ Takedown(reason, notifySeller)",
      "+ SubmitEdit(edit) / ApplyPendingEdit()",
      "+ AddVariant(v) / RemoveVariant(id)",
      "+ SetFeatured(id) / Featured() *Variant",
      "+ Snapshot() / Events() / ClearEvents()",
    )),
  edge(<c-svc>, <c-lst>, "-->", rel[điều phối]),
  edge(<c-repo>, <c-lst>, "-->", rel[nạp / ghi]),

  cls((0, 1), "Category", name: <c-cat>,
    attrs: (
      "- id: int64",
      "- parentID: *int64  // NULL = gốc; tự quan hệ",
      "                    // 0..1 cha → 0..* con",
      "- name: string  // UNIQUE",
      "- description: string",
      "- embeddingStaleAt: *time",
    ),
    ops: ("+ Validate() error",)),
  edge(<c-cat>, <c-lst>, "-", rel[1 → 0..\*]),

  cls((2, 1), "PendingEdit", stereo: "value object", name: <c-edit>,
    attrs: ("- (tập con các trường sửa được của Listing)",),
    ops: ("+ Fields() []string", "+ IsEmpty() bool")),
  edge(<c-lst>, <c-edit>, "-->", rel[0..1]),

  cls((1, 2), "Variant", name: <c-var>,
    attrs: (
      "- id, listingID: int64",
      "- price: int64  // đơn vị tiền nhỏ nhất",
      "- attributes: jsonb  // {size, color, …}",
      "- packageDetails: jsonb  // khối lượng, kích thước",
      "- attachments: []int64",
      "- isFeatured: bool  // ≤ 1 mỗi listing",
      "- deletedAt: *time",
    ),
    ops: ("+ Validate() error", "+ IsLive() bool")),
  edge(<c-lst>, <c-var>, "-", rel[1 → 1..\*  «composition»]),

  cls((0, 3), "Tag", name: <c-tag>,
    attrs: ("- id: string  // slug kebab-case, khóa tự nhiên", "- description: *string")),
  cls((0, 4), "ListingTag", stereo: "association", name: <c-ltag>,
    attrs: ("- listingID: int64", "- tag: string")),
  edge(<c-lst>, <c-ltag>, "-", bend: 30deg, rel[1 → 0..\*]),
  edge(<c-tag>, <c-ltag>, "-", rel[1 → 0..\*]),

  cls((2, 3), "Favorite", stereo: "wishlist", name: <c-fav>,
    attrs: (
      "- accountID: int64  // cross-ref, không FK",
      "- listingID: int64  // khóa chính là cặp",
      "- createdAt: time",
    )),
  edge(<c-lst>, <c-fav>, "-", rel[1 → 0..\*]),

  cls((1, 3), "Stock", name: <c-stk>,
    attrs: (
      "- variantID: int64  // khóa chính, không id riêng",
      "- quantity: int64",
      "- reserved: int64  // đang giữ chỗ, trả lại khi hủy",
      "- sold: int64      // chỉ tăng",
    ),
    ops: (
      "+ Available() int64",
      "+ Committed() int64",
      "+ SetQuantity(q)",
      "  CHECK reserved + sold ≤ quantity",
    )),
  edge(<c-var>, <c-stk>, "-", rel[1 → 1]),

  cls((1, 4), "StockMovement", stereo: "idempotency", name: <c-mov>,
    attrs: (
      "- key: string  // 'order:41:item:88:commit'",
      "- variantID: int64, units: int64",
    )),
  edge(<c-stk>, <c-mov>, "-->", rel[ghi cùng giao dịch]),

  cls((2, 2), "ListingEmbedding", stereo: "pgvector", name: <c-emb>,
    attrs: (
      "- listingID: int64",
      "- dense: vector(1024)      // BGE-M3, cosine",
      "- sparse: sparsevec(250048) // ≤ 1000 phần tử khác 0",
    )),
  edge(<c-lst>, <c-emb>, "-", rel[1 → 0..1]),

  cls((0, 2), "CategoryEmbedding\nTagEmbedding", stereo: "pgvector", name: <c-emb2>,
    attrs: ("- dense: vector(1024)", "- sparse: sparsevec(250048)", "- chỉ mục HNSW")),
  edge(<c-cat>, <c-emb2>, "-", rel[1 → 0..1]),

  cls((2, 4), "AccountInterest", name: <c-int>,
    attrs: (
      "- accountID: int64, slot: int16  // 1..N",
      "- dense: vector(1024)",
      "- strength: float32",
      "  ANN chạy trên listing_embedding,",
      "  không đánh chỉ mục vector ở đây",
    )),
)

#figure(
  caption: [Đối chiếu lớp miền – bảng CSDL – trách nhiệm, module `catalog`],
  table(
    columns: (1fr, 1fr, 2.4fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Lớp miền], [Bảng], [Ghi chú thiết kế]),
    [`Listing`], [`listing`],
    [Là *lời chào bán của một người bán*, không phải mục trong danh mục sản phẩm
     dùng chung: hai người bán cùng một mẫu điện thoại là hai dòng. Xóa mềm
     (`deleted_at`) vì `order.item` giữ `listing_id` không khóa ngoại và lịch sử
     đơn hàng phải luôn tra được.],
    [`Variant`], [`variant`],
    [Cờ `is_featured` đặt ở đây thay vì `listing.featured_variant_id`, nên
     "biến thể nổi bật phải thuộc chính bài đăng này" không còn là quy tắc ai đó
     phải giữ — và hai bảng hết vòng lặp tham chiếu.],
    [`Stock`], [`stock`],
    [Hai bộ đếm chứ không một: `reserved` trả lại khi hủy, `sold` không bao giờ
     giảm. Gộp một cột thì "đã bán bao nhiêu" sẽ phồng lên theo giỏ hàng bỏ dở.],
    [`StockMovement`], [`stock_movement`],
    [Sổ lũy đẳng cho `commit`/`uncommit`. `reserve`/`release` không cần vì lượt
     nhả trùng đã bị chặn bởi chính `reserved` cạn.],
    [`Category`], [`category`],
    [Cây phân cấp; xóa cha thì con được nâng lên thành gốc (`SET NULL`).],
    [`Tag`, `ListingTag`], [`tag`, `listing_tag`],
    [`tag.id` là khóa *tự nhiên* dạng slug — một trong hai ngoại lệ của quy tắc
     "mọi khóa thay thế đều là `BIGINT`".],
    [`Favorite`], [`favorite`],
    [Đặt ở `catalog` chứ không ở `account`: cả ba câu hỏi của một wishlist đều
     hỏi về `listing`, để bên kia thì cả ba thành lời gọi liên module.],
    [`ListingEmbedding`\ `CategoryEmbedding`\ `TagEmbedding`], [`*_embedding`],
    [Tìm kiếm lai: `sparse` khớp từ vựng (tích vô hướng), `dense` khớp ngữ nghĩa
     (cosine), cả hai từ BGE-M3, chỉ mục HNSW.],
    [`AccountInterest`], [`account_interest`],
    [Mỗi tài khoản vài "khe" sở thích, đọc theo khóa chính để dựng bảng tin;
     không đánh chỉ mục vector vì sẽ phải chịu ghi lại liên tục.],
  ),
)

== Module `order` — Giỏ hàng, đơn hàng, hoàn tiền và tranh chấp

Đây là module duy nhất có `port/workflows.go`: ba luồng bền chạy trên Restate.
Đơn hàng sinh ra *ngay khi tiền về* — do webhook thanh toán, không phải do ai
bấm nút; người bán không bao giờ "duyệt" một đơn hàng, vì thứ duy nhất họ có thể
từ chối là giá, và điều đó đã xảy ra ở vòng thương lượng trước khi dòng này tồn
tại.

#fig(
  [Sơ đồ lớp module `order` (phần điều phối và vòng đời đơn hàng)],
  spacing: (10mm, 7mm),

  cls((0, 0), "orderapi.Service", stereo: "interface", name: <o-svc>,
    ops: (
      "+ ListCartItems / AddCartItem / …",
      "+ CreateDraft / Checkout / CancelDraft",
      "+ CreateOffer / CounterOffer / AcceptOffer",
      "+ ListOrders / GetOrder / ConfirmReceipt",
      "+ CancelOrder / AdvanceShipment",
      "+ CreateRefund / AcceptRefund / RejectRefund",
      "+ OpenDispute / AdminRuleDispute",
      "+ SettlePaidSession   // webhook thanh toán",
      "+ ExpireDrafts / ExpireOffers / ExpireCheckouts",
      "+ ReleaseDuePayouts / AdvanceOverdueRefunds",
    )),
  cls((1, 0), "port.Workflows", stereo: "interface · Restate", name: <o-wf>,
    ops: (
      "+ StartCheckout / CheckoutPaid",
      "+ CheckoutCancelled",
      "+ StartOrder / OrderReceived",
      "+ OrderCancelled",
      "+ RefundRaised / RefundResolved",
      "+ StartRefundWindow",
      "  OrderCheckout · OrderLifecycle · OrderRefund",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <o-repo>,
    ops: (
      "+ UpsertCartItem / ListCartItems",
      "+ InsertDraft / ExpiredDrafts",
      "+ InsertOffer / FindActiveOffer / ExpiredOffers",
      "+ InsertItems / ItemsByPaymentSession",
      "+ CreateOrder / LinkItems / FindOrderByOrigin",
      "+ PayoutDue / ClaimPayout / MarkPayoutReleased",
      "+ InsertRefund / OverdueRefunds",
      "+ InsertDispute / ListOpenDisputes",
    )),
  edge(<o-svc>, <o-wf>, "-->", rel[khởi động]),
  edge(<o-svc>, <o-repo>, "-->", rel[dùng]),

  cls((0, 1), "CartItem", name: <o-cart>,
    attrs: (
      "- id, accountID: int64",
      "- listingID, variantID: int64  // cross-ref catalog",
      "- quantity: int64",
    ),
    ops: ("+ SetQuantity(q)",)),

  cls((1, 1), "Draft", stereo: "đóng băng điều khoản", name: <o-draft>,
    attrs: (
      "- id, buyerID, listingID: int64",
      "- spuSnapshot: jsonb  // giá + khối lượng lúc mở phiên",
      "- validUntil: time, cancelledAt: *time",
    ),
    ops: (
      "+ Live(now) bool",
      "+ Cancel()",
      "+ Variant(variantID) (VariantSnapshot, error)",
      "+ EncodeSnapshot() ([]byte, error)",
    )),

  cls((2, 1), "Offer", stereo: "thương lượng giá", name: <o-offer>,
    attrs: (
      "- id, listingID, variantID: int64",
      "- authorID, buyerID, sellerID: int64",
      "- status: active | accepted | cancelled",
      "- quantity, total: int64, reason: string",
      "- paymentSessionID: *int64",
      "- expiresAt: time",
    ),
    ops: (
      "+ Live(now) / Involves(accountID) bool",
      "+ Counter(actor, qty, total, reason, now, w)",
      "+ Accept(actorID, now) / Cancel(actorID)",
      "+ Expire()",
      "  UNIQUE 1 offer active / (buyer, variant)",
    )),

  cls((1, 2), "Order", stereo: "aggregate root", name: <o-ord>,
    attrs: (
      "- id: int64",
      "- draftID XOR offerID: *int64  // đúng một nguồn",
      "- buyerID, sellerID: int64",
      "- transportID: int64  // UNIQUE",
      "- address, pickupAddress: jsonb  // ảnh chụp",
      "- receivedAt: *time",
      "- receiptAttachments: []int64  // bằng chứng mở hộp",
      "- payoutReleasedAt: *time",
      "- completedAt, cancelledAt: *time",
    ),
    ops: (
      "+ State() string  // open|completed|cancelled",
      "+ Settled() bool",
      "+ ConfirmReceipt(attachments)",
      "+ PayoutDue() *time  // +72h sau khi nhận",
      "+ Complete() / MarkPayoutReleased()",
      "+ Cancel(shipped bool)",
      "+ Involves(accountID) bool",
    )),
  edge(<o-draft>, <o-ord>, "-", rel[0..1 → 0..1]),
  edge(<o-offer>, <o-ord>, "-", rel[0..1 → 0..1]),

  cls((0, 2), "Item", name: <o-item>,
    attrs: (
      "- id: int64, orderID: *int64  // NULL tới khi tiền về",
      "- draftID XOR offerID: *int64",
      "- buyerID, sellerID: int64",
      "- listingID, variantID: int64  // cross-ref catalog",
      "- quantity, totalAmount: int64",
      "- currency, transportOption: string",
      "- paymentSessionID: int64  // cross-ref finance",
      "- cancelledAt: *time, cancelledByID: *int64",
    ),
    ops: ("+ Live() bool", "+ Cancel(actorID)")),
  edge(<o-ord>, <o-item>, "-", rel[1 → 1..\*]),

  cls((2, 2), "Transport", name: <o-tr>,
    attrs: (
      "- id: int64",
      "- option: string  // slug hãng vận chuyển",
      "- status: pending → picked-up → in-transit",
      "         → delivered | returned | failed",
      "- data: jsonb  // mã vận đơn, nhãn, webhook",
    ),
    ops: (
      "+ Shipped() / Delivered() / Settled() bool",
      "+ Advance(status) error",
    )),
  edge(<o-ord>, <o-tr>, "-", rel[1 → 1]),

  cls((1, 3), "Refund", name: <o-ref>,
    attrs: (
      "- id, buyerID, orderID: int64",
      "- reason: string, attachments: []int64",
      "- status: awaiting-seller-review |",
      "          awaiting-buyer-action | disputed |",
      "          returning | returned |",
      "          accepted | rejected | cancelled",
      "- deadlineAt: *time  // ai đang giữ nhịp",
      "- sellerDecidedAt: *time, rejectionReason: *string",
      "- returnTransportID: *int64, returnedAt: *time",
      "- refundTxID: *int64  // chỉ khi 'accepted'",
    ),
    ops: (
      "+ Withdraw() / Accept() / Reject(reason)",
      "+ LapseSellerReview() / LapseBuyerAction()",
      "+ Escalate() / Rule(buyerWins)",
      "+ StartReturn(transportID) / MarkReturned()",
      "+ Settle(refundTxID) / AddAttachments(a)",
      "  48h duyệt · 72h phản hồi · 48h kháng nghị",
    )),
  edge(<o-ord>, <o-ref>, "-", rel[1 → 0..\*  (≤ 1 đang mở)]),
  edge(<o-ref>, <o-tr>, "-", rel[0..1 → 1  chặng trả hàng]),

  cls((2, 3), "Dispute", name: <o-dis>,
    attrs: (
      "- id, refundID: int64",
      "- round: int16  // 1 = người mua, 2 = người bán",
      "- openedByID: int64, reason: string",
      "- attachments: []int64",
      "- status: open | buyer-wins | seller-wins",
      "- resolvedByID, resolvedAt, resolutionNote",
    ),
    ops: ("+ Rule(moderatorID, buyerWins, note)", "  ≤ 1 vòng đang mở mỗi refund")),
  edge(<o-ref>, <o-dis>, "-", rel[1 → 0..2]),

  cls((0, 3), "Origin", stereo: "value object", name: <o-org>,
    attrs: ("- draftID: *int64", "- offerID: *int64"),
    ops: ("+ Valid() bool  // đúng một trong hai",)),
  edge(<o-ord>, <o-org>, "--", rel[dùng]),

  cls((0, 4), "(liên module)", stereo: "cross-ref", name: <o-x>,
    attrs: (
      "→ finance.payment_session  (paymentSessionID)",
      "→ finance.transaction      (refundTxID)",
      "→ catalog.listing/variant  (listingID, variantID)",
      "→ account.account          (buyerID, sellerID)",
      "→ common.resource          (attachments[])",
      "→ common.option            (transportOption)",
    )),
  edge(<o-ord>, <o-x>, "--", rel[không có khóa ngoại]),
)

#figure(
  caption: [Đối chiếu lớp miền – bảng CSDL – trách nhiệm, module `order`],
  table(
    columns: (1fr, 1fr, 2.4fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Lớp miền], [Bảng], [Ghi chú thiết kế]),
    [`CartItem`], [`cart_item`], [Giỏ phẳng, một dòng cho mỗi cặp (tài khoản, biến thể).],
    [`Draft`], [`draft_order`],
    [Đóng băng điều khoản cho bài đăng *giá cố định*, để một bài đăng đang hiện
     100k không thể tính tiền theo giá vừa sửa. Bài đăng *thương lượng* không có
     draft — chính thẻ giá được chấp nhận đóng vai trò đó.],
    [`Offer`], [`offer`],
    [Một cuộc thương lượng cho mỗi cặp (người mua, biến thể); điều khoản được
     *sửa tại chỗ* chứ không xếp chồng dòng, nên "đang đặt gì trên bàn" là một
     dòng chứ không phải một lượt quét cả luồng chat.],
    [`Order`], [`order`],
    [Không có cột `status`: vòng đời nằm ở tầng dịch vụ, còn ở đây là các *dữ
     kiện kết quả* (`received_at`, `completed_at`, `cancelled_at`,
     `payout_released_at`) — nhờ đó "đơn đang mở của tôi" là một lượt tra chỉ mục
     thay vì `JOIN` ba bảng.],
    [`Item`], [`item`],
    [Tồn tại từ lúc thanh toán, trước khi tiền về — đó là ý nghĩa của
     `order_id IS NULL`.],
    [`Transport`], [`transport`],
    [Trạng thái vận đơn theo đúng cách hãng vận chuyển báo; enum chung
     pending/success từng khiến các chặng giữa nằm kẹt trong `data`.],
    [`Refund`], [`refund`],
    [Luôn hoàn *toàn bộ* đơn, nên không có cột số tiền. Mọi trạng thái chưa kết
     thúc đều được đặt tên theo *bên đang bị chờ* và mang `deadline_at`, nhờ đó
     một tác vụ nền duy nhất đẩy được tất cả.],
    [`Dispute`], [`refund_dispute`],
    [Hai vòng và giữ cả hai: vòng 1 người mua khiếu nại, vòng 2 người bán kháng
     nghị hàng trả về. Hai dòng chứ không phải một phán quyết đổi ý.],
  ),
)

== Module `finance` — Phiên thanh toán, sổ cái và ví

Toàn bộ nguyên thủy tiền tệ nằm chung một module để các bước dịch chuyển ký quỹ
giữ được tính nguyên tử. Ranh giới quan trọng nhất trong module: *hai sổ cái, một
đường biên* — `Transaction` ghi các chặng trên *kênh ngoài* (thẻ, VNPay…) dưới
một phiên, còn tiền chỉ dịch chuyển *bên trong ví* thì chỉ ghi ở `Movement`.
Không bao giờ ghi cùng một lần dịch chuyển vào cả hai.

#fig(
  [Sơ đồ lớp module `finance`],
  spacing: (10mm, 7mm),

  cls((0, 0), "financeapi.Service", stereo: "interface", name: <f-svc>,
    ops: (
      "+ StartPayment / CancelSession",
      "+ ListSessions / GetSession",
      "+ ListWallets / GetWallet / ListWalletMovements",
      "+ CreateWithdrawal / CancelWithdrawal",
      "+ AdminApproveWithdrawal / AdminRejectWithdrawal",
      "+ ListBankAccounts / CreateBankAccount / …",
      "+ GetTaxInfo / PutTaxInfo / AdminVerifyTaxInfo",
      "+ OpenCheckout",
      "+ HoldEscrow / ReleaseEscrow / RefundEscrow",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <f-repo>,
    ops: (
      "+ NextSessionID / NextTransactionID",
      "+ InsertSession / SaveSession / ListSessions",
      "+ InsertTransaction / SaveTransaction",
      "+ FindWallet / ListWallets / ListMovements",
      "+ Move(legs)  // ghi ví + sổ cái một giao dịch",
      "+ InsertBankAccount / SoftDeleteBankAccount",
      "+ PutTaxInfo / FindTaxInfo / SaveTaxInfo",
    )),
  edge(<f-svc>, <f-repo>, "-->", rel[dùng]),

  cls((0, 1), "Session", stereo: "payment intent", name: <f-ses>,
    attrs: (
      "- id: int64  // cấp phát trước khi INSERT",
      "- kind: buyer-checkout | seller-payout |",
      "        withdrawal",
      "- status: pending | processing | success |",
      "          cancelled | failed",
      "- fromID, toID: *int64  // NULL = hệ thống",
      "- currency: string, totalAmount: int64",
      "- fxSnapshot: *jsonb  // tỉ giá đóng băng",
      "- data: jsonb, paidAt: *time, expiredAt: time",
    ),
    ops: (
      "+ Expired(now) / Settled() / RailPayable() bool",
      "+ Charge(now) / MarkPaid(now) / MarkFailed()",
      "+ ReopenForRetry(now) / Cancel()",
      "+ Involves(accountID) bool",
    )),
  edge(<f-svc>, <f-ses>, "-->", rel[điều phối]),

  cls((2, 1), "Transaction", stereo: "append-only ledger", name: <f-tx>,
    attrs: (
      "- id, sessionID: int64",
      "- status: pending → success | failed",
      "- paymentOption: string  // slug kênh thanh toán",
      "- providerRef: *string   // khóa lũy đẳng webhook",
      "- amount: int64  // dương = thu, âm = hoàn",
      "- currency: string",
      "- reversesID: *int64  // tự quan hệ: 0..1 chặng",
      "                      // gốc mà dòng này nghịch đảo",
      "- data: jsonb, settledAt, expiredAt: *time",
    ),
    ops: (
      "+ NewReversal(id, amount) (Transaction, error)",
      "+ Settle(status, providerRef, failure)",
      "  UNIQUE (paymentOption, providerRef)",
      "  UNIQUE reversesID  // 1 lần hoàn mỗi chặng",
    )),
  edge(<f-ses>, <f-tx>, "-", rel[1 → 0..\*  split-tender]),

  cls((0, 2), "Wallet", name: <f-wal>,
    attrs: (
      "- accountID: int64  ⎫ khóa chính",
      "- currency: string  ⎭ (không trộn tiền tệ)",
      "- availableBalance: int64  // tiêu / rút được",
      "- heldBalance: int64       // đang ký quỹ",
    ),
    ops: (
      "+ Total() int64",
      "+ CanSpend(amount) bool",
      "+ Apply(t Transfer, seq) (Movement, error)",
      "  mọi thay đổi: SELECT … FOR UPDATE",
    )),
  edge(<f-ses>, <f-wal>, "--", rel[hai sổ cái, một đường biên]),

  cls((1, 2), "Movement", stereo: "append-only ledger", name: <f-mov>,
    attrs: (
      "- id, accountID: int64, currency: string",
      "- seq: int64  // thứ tự tuyệt đối trong ví",
      "- kind: topup | escrow-hold | escrow-release |",
      "        payout | refund | withdrawal | fee |",
      "        adjustment",
      "- availableDelta, heldDelta: int64",
      "- availableAfter, heldAfter: int64",
      "- groupID: *int64  // các chặng cùng một lần",
      "- refType, refID  // 'order' | 'payment-session'",
      "- idempotencyKey: *string  // 'order:412:hold'",
    )),
  edge(<f-wal>, <f-mov>, "-", rel[1 → 0..\*]),

  cls((2, 2), "Transfer", stereo: "value object", name: <f-trf>,
    attrs: ("- availableDelta, heldDelta: int64", "- kind: WalletKind, ref: Ref"),
    ops: ("  Hold · Release · Credit · Debit · Adjust",)),
  edge(<f-wal>, <f-trf>, "--", rel[tham số của Apply]),

  cls((0, 3), "BankAccount", name: <f-bank>,
    attrs: (
      "- id, accountID: int64",
      "- bankCode, accountNumber, accountHolder",
      "- isDefault: bool  // ≤ 1 mỗi tài khoản",
      "- deletedAt: *time  // xóa mềm",
    ),
    ops: ("+ IsLive() bool",)),

  cls((1, 3), "TaxInfo", name: <f-tax>,
    attrs: (
      "- accountID: int64  // khóa chính",
      "- taxCode: string  // MST 10 số, hoặc 10-3",
      "- taxCodeType: individual|business|household",
      "- legalName: string",
      "- verificationStatus: pending|verified|rejected",
      "- verifiedAt: *time, verificationSource: *string",
    ),
    ops: ("+ Verify(verified bool, source string)",)),

  cls((2, 3), "Ref", stereo: "value object", name: <f-ref>,
    attrs: ("- refType: *string", "- refID: *int64"),
    ops: ("+ Type() *string", "+ ID() *int64", "  OrderRef · SessionRef")),
  edge(<f-mov>, <f-ref>, "--", rel[dùng]),

  cls((1, 4), "(liên module)", stereo: "cross-ref", name: <f-x>,
    attrs: (
      "→ account.account  (accountID, fromID, toID)",
      "→ order.order      (refID khi refType='order')",
      "→ common.option    (paymentOption)",
      "← order.item.paymentSessionID",
      "← order.refund.refundTxID",
    )),
  edge(<f-ses>, <f-x>, "--", rel[không có khóa ngoại]),
)

#figure(
  caption: [Đối chiếu lớp miền – bảng CSDL – trách nhiệm, module `finance`],
  table(
    columns: (1fr, 1fr, 2.4fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Lớp miền], [Bảng], [Ghi chú thiết kế]),
    [`Session`], [`payment_session`],
    [Khóa chính dùng `GENERATED BY DEFAULT` để ứng dụng cấp phát trước bằng
     `nextval(...)` — cần đưa mã phiên cho cổng thanh toán *trước khi* dòng tồn
     tại. Rút tiền là một phiên `kind = 'withdrawal'` chứ không phải bảng riêng.],
    [`Transaction`], [`transaction`],
    [Chỉ ghi chặng trên *kênh ngoài*. Hoàn tiền là *dòng mới* với số tiền âm và
     `reverses_id` trỏ về bản gốc, không phải sửa dòng cũ. `provider_ref` duy
     nhất chính là thứ chặn một webhook giao lại thành cú tính tiền thứ hai.],
    [`Wallet`], [`wallet`],
    [Khóa chính là cặp (tài khoản, tiền tệ) nên mở thêm một loại tiền là một
     `INSERT` chứ không phải một cuộc di trú tiền đang sống.],
    [`Movement`], [`wallet_transaction`],
    [Sổ cái chỉ-thêm-mới, mỗi dòng kèm số dư *trước và sau*. `seq` cho mỗi ví một
     thứ tự tuyệt đối mà `created_at` không cho được (dấu thời gian có thể trùng);
     nó được cấp dưới cùng một `SELECT … FOR UPDATE` với chính lần đổi số dư.],
    [`BankAccount`], [`bank_account`],
    [Xóa mềm: một lượt rút đã hoàn tất có nêu tên dòng này trong `data` của phiên,
     và đó là bằng chứng tiền thật đã đi đâu.],
    [`TaxInfo`], [`tax_info`],
    [Chỉ mục duy nhất *có điều kiện* bảo đảm một mã số thuế chỉ được xác minh cho
     đúng một tài khoản trên toàn hệ thống.],
  ),
)

== Module `trust` — Đánh giá, nhận xét, uy tín và tố cáo

Module này tách hai loại điểm số vốn hay bị gộp: `Feedback` là *giao dịch diễn
ra thế nào* (hai chiều, ẩn cho tới khi công bố), còn `Review` là *món hàng có
đúng như mô tả không* (một chiều, chỉ người mua). Một đơn hàng có thể sinh ra cả
hai, nên nếu cộng chung vào một cặp tổng thì đã đếm hai lần — vì vậy `Reputation`
giữ hai cặp tổng riêng biệt.

#fig(
  [Sơ đồ lớp module `trust`],
  spacing: (10mm, 7mm),

  cls((0, 0), "trustapi.Service", stereo: "interface", name: <t-svc>,
    ops: (
      "+ SubmitFeedback / GetOrderFeedback",
      "+ ListAccountFeedback / GetReputation",
      "+ SubmitReview / UpdateReview / DeleteReview",
      "+ ListReviews / GetReview",
      "+ SubmitReply / DeleteReply",
      "+ VoteReview / UnvoteReview",
      "+ SubmitReport / ListMyReports",
      "+ AdminClaimReport / AdminResolveReport",
      "+ RevealDueFeedback / RecordOrderOutcome",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <t-repo>,
    ops: (
      "+ InsertFeedback / OrderFeedback / ListFeedback",
      "+ DueFeedback / PublishFeedback",
      "+ FindReputation / AddOrderOutcome",
      "+ ReviewAverage",
      "+ InsertReview / ListReviews / SaveReview",
      "+ InsertReply / ListReplies",
      "+ PutVote / DeleteVote / MyVotes",
      "+ InsertReport / ListReports / SaveReport",
    )),
  edge(<t-svc>, <t-repo>, "-->", rel[dùng]),

  cls((0, 1), "Feedback", stereo: "blind until revealed", name: <t-fb>,
    attrs: (
      "- id, orderID: int64  // cross-ref order",
      "- raterID, rateeID: int64",
      "- direction: buyer-to-seller | seller-to-buyer",
      "- rating: int16  // 1..5",
      "- comment: string",
      "- publishedAt: *time  // NULL = còn ẩn",
    ),
    ops: (
      "+ Published() bool",
      "+ Publish(at)",
      "+ RevealAt() *time",
      "  UNIQUE (orderID, direction)",
    )),
  edge(<t-svc>, <t-fb>, "-->", rel[điều phối]),

  cls((1, 1), "Review", name: <t-rev>,
    attrs: (
      "- id: int64",
      "- listingID: int64  // cross-ref catalog",
      "- orderID: int64    // không mua thì không viết",
      "- authorID, sellerID: int64  // sellerID đóng băng",
      "- rating: int16  // 1..5",
      "- body: string, attachments: []int64",
      "- helpfulCount, notHelpfulCount: int64",
      "- replyCount: int64",
      "- updatedAt: *time",
    ),
    ops: (
      "+ SetRating(r) / SetBody(b)",
      "+ SetAttachments(a)",
      "+ MutableBy(accountID) bool",
      "  UNIQUE (listingID, authorID, orderID)",
    )),
  edge(<t-svc>, <t-rev>, "-->", rel[điều phối]),

  cls((2, 1), "Report", stereo: "polymorphic", name: <t-rep>,
    attrs: (
      "- id, reporterID: int64",
      "- refType: listing | account | message |",
      "           review | review-reply",
      "- refID: int64  // đích đa hình",
      "- reason: scam | counterfeit | prohibited |",
      "          harassment | spam | inappropriate | other",
      "- status: open | reviewing | actioned | dismissed",
      "- actionTaken: *ReportAction",
      "- resolvedByID: *int64, resolutionNote: *string",
    ),
    ops: (
      "+ Resolved() bool",
      "+ Claim()",
      "+ Resolve(moderatorID, status, action, note)",
      "  UNIQUE 1 tố cáo mở / (người báo, đích)",
    )),

  cls((1, 2), "ReviewReply", name: <t-rpl>,
    attrs: ("- id, reviewID: int64", "- authorID: int64", "- body: string")),
  edge(<t-rev>, <t-rpl>, "-", rel[1 → 0..\*  «composition»]),

  cls((2, 2), "ReviewVote", name: <t-vote>,
    attrs: (
      "- reviewID, accountID: int64  // khóa chính là cặp",
      "- vote: int16  // −1 hoặc 1, không có giá trị 0",
    )),
  edge(<t-rev>, <t-vote>, "-", rel[1 → 0..\*]),

  cls((0, 2), "Reputation", stereo: "aggregate", name: <t-rep2>,
    attrs: (
      "- accountID: int64, role: seller | buyer",
      "- ratingSum, ratingCount: int64        // từ Feedback",
      "- reviewRatingSum, reviewRatingCount   // từ Review",
      "- completedOrders, cancelledOrders: int64",
      "- updatedAt: time",
    ),
    ops: (
      "+ AverageRating() float64",
      "+ AverageReviewRating() float64",
      "  CHECK: chỉ 'seller' mới có điểm review",
    )),
  edge(<t-fb>, <t-rep2>, "-->", rel[cộng dồn]),
  edge(<t-rev>, <t-rep2>, "-->", rel[cộng dồn]),

  cls((0, 3), "OrderOutcome", stereo: "idempotency", name: <t-out>,
    attrs: ("- orderID: int64  // khóa chính", "- completed: bool")),
  edge(<t-rep2>, <t-out>, "--", rel[chặn đếm hai lần khi bus giao lại]),

  cls((1, 3), "(đồng bộ ngược)", stereo: "cross-module", name: <t-sync>,
    attrs: (
      "trust.review  ──▶  catalog.listing.cached_rating",
      "                    catalog.listing.cached_review_count",
      "hai lược đồ khác nhau nên không JOIN được;",
      "`catalog.SyncListingRating` ghi giá trị đã tính lại.",
    )),
  edge(<t-rev>, <t-sync>, "--", rel[đẩy sang `catalog`]),
)

#figure(
  caption: [Đối chiếu lớp miền – bảng CSDL – trách nhiệm, module `trust`],
  table(
    columns: (1fr, 1fr, 2.4fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Lớp miền], [Bảng], [Ghi chú thiết kế]),
    [`Feedback`], [`feedback`],
    [Đánh giá hai chiều cho một đơn đã hoàn tất, *ẩn* cho tới khi công bố để bên
     này không nhìn điểm bên kia rồi mới chấm.],
    [`Review`], [`review`],
    [`order_id` là `NOT NULL` có chủ đích: không mua thì không được nhận xét.
     `seller_id` được *đóng băng* từ đơn hàng lúc gửi — hỏi lại `catalog` mỗi lần
     sửa từng khiến tổng hợp phụ thuộc vào việc bài đăng còn đọc được hay không.],
    [`ReviewReply`], [`review_reply`], [Phản hồi phẳng dưới một nhận xét; không có điểm và không có đơn hàng.],
    [`ReviewVote`], [`review_vote`],
    [Không có giá trị trung lập: rút phiếu là *xóa dòng*. Một số 0 lưu lại là một
     dòng không nói gì và còn phải bị loại khỏi mọi phép đếm.],
    [`Reputation`], [`reputation`],
    [Hai cặp tổng riêng biệt; "giao hàng đúng hẹn" không phải là cùng một khẳng
     định với "món hàng đúng như mô tả".],
    [`OrderOutcome`], [`order_outcome`],
    [Bảng đã-xử-lý, ghi cùng giao dịch với lần tăng bộ đếm, nên lượt giao lại
     thứ hai là vô hiệu thay vì thành hiệu ứng thứ hai.],
    [`Report`], [`report`],
    [Đích đa hình `(ref_type, ref_id)`. Hàng đợi kiểm duyệt là chỉ mục *bộ phận*
     trên lát nóng, nên tồn đọng đã xử lý dù lớn tới đâu cũng không tốn gì.],
  ),
)

== Module `chat` — Hội thoại và tin nhắn

Module nhỏ nhất nhưng chứa một quyết định mô hình hóa đáng chú ý: *không có
trạng thái gửi/đã đọc trên từng tin nhắn*. Vì `message` là hypertable, một cờ
trên mỗi dòng sẽ khiến mọi câu hỏi về "chưa đọc" sai hình dạng — huy hiệu đếm
không có cận thời gian nên không loại được mảnh nào, và đánh dấu đã đọc sẽ
`UPDATE` mọi dòng chưa đọc, tức là làm bẩn các mảnh cũ để ghi lại một sự kiện của
*hiện tại*. Hai dấu thời gian trên `Conversation` trả lời cả ba câu hỏi.

#fig(
  [Sơ đồ lớp module `chat`],
  spacing: (12mm, 8mm),

  cls((0, 0), "chatapi.Service", stereo: "interface", name: <ch-svc>,
    ops: (
      "+ ListConversations / StartConversation",
      "+ GetConversation / GetUnreadCount",
      "+ ListMessages / SendMessage / GetMessage",
      "+ MarkConversationRead",
      "+ UpdateMessage / RedactMessage",
      "+ PostSystemMessage",
    )),
  cls((1, 0), "port.Repository", stereo: "interface", name: <ch-repo>,
    ops: (
      "+ EnsureConversation / FindConversation",
      "+ ListConversations / SaveConversation",
      "+ InsertMessage / FindMessage / FindMessageAt",
      "+ SaveMessage / ListMessages / LastMessages",
      "+ UnreadCounts / UnreadTotal",
      "+ FindResources",
    )),
  edge(<ch-svc>, <ch-repo>, "-->", rel[dùng]),

  cls((0, 1), "Conversation", stereo: "aggregate root", name: <ch-conv>,
    attrs: (
      "- id: int64",
      "- accountAID, accountBID: int64  // cross-ref",
      "                        // CHECK A < B",
      "- lastMessageAt: time  // sắp xếp hộp thư",
      "- accountAReadAt: *time",
      "- accountBReadAt: *time",
    ),
    ops: (
      "+ Involves(accountID) bool",
      "+ Counterparty(accountID) int64",
      "+ ReadMark(accountID) *time",
      "+ CounterpartyReadMark(accountID) *time",
      "+ MarkRead(accountID, at)",
      "  UNIQUE (accountAID, accountBID)",
    )),
  edge(<ch-svc>, <ch-conv>, "-->", rel[điều phối]),

  cls((1, 1), "Message", stereo: "hypertable", name: <ch-msg>,
    attrs: (
      "- id: int64, createdAt: time  // khóa (id, createdAt)",
      "- conversationID: int64",
      "- senderID: *int64  // NULL với tin hệ thống",
      "- type: user | system",
      "- body: string",
      "- attachments: []int64  // cross-ref common.resource",
      "- metadata: jsonb  // {offer_id}, listing, order…",
      "- editedAt, deletedAt: *time",
    ),
    ops: (
      "+ IsLive() bool",
      "+ Edit(senderID, body) error",
      "+ Redact(actorID, moderator bool) error",
      "  CHECK (type='system') = (senderID IS NULL)",
    )),
  edge(<ch-conv>, <ch-msg>, "-", rel[1 → 0..\*]),

  cls((0, 2), "(liên module)", stereo: "cross-ref", name: <ch-x>,
    attrs: (
      "→ account.account  (accountAID, accountBID, senderID)",
      "→ order.offer      (metadata.offer_id)",
      "→ catalog.listing / variant, order.order",
      "→ common.resource  (attachments[])",
    )),
  edge(<ch-msg>, <ch-x>, "--"),

  cls((1, 2), "Thẻ thương lượng giá", stereo: "ghi chú thiết kế", name: <ch-note>,
    attrs: (
      "Điều khoản của offer KHÔNG được sao vào message.",
      "`order.offer` là nguồn sự thật; tin nhắn chỉ nói",
      "*thẻ nào* cần vẽ — nên một lần sửa giá không thể",
      "để lại trong luồng chat một mức giá không còn hiệu lực.",
    )),
  edge(<ch-msg>, <ch-note>, "--"),
)

== Module `observability` — Quan trắc vận hành

Module này theo đúng hình dạng chuẩn nhưng *không có* thư mục `api/`: không
module nào gọi nó, nó được dẫn động bởi middleware, bộ lấy mẫu và bus. Đây là
đường ống hai chặng — `Sink` *phát* mỗi mẫu lên NATS JetStream, còn
`subscribeWriter` *tiêu thụ* theo lô và `COPY` cả lô vào hypertable.

#fig(
  [Sơ đồ lớp module `observability`],
  spacing: (12mm, 8mm),

  cls((0, 0), "Sink", stereo: "không có api.Service", name: <ob-sink>,
    attrs: (
      "- bus: *eventbus.NATS  // kiểu cụ thể, không phải interface",
      "- instance: string  // env INSTANCE_ID, đóng dấu 1 lần",
      "- dropped: atomic counter",
    ),
    ops: (
      "+ Middleware(next) http.Handler  // RED vào",
      "+ OutboundObserver() Observer     // RED ra",
      "+ SampleLoop(ctx)                 // runtime Go",
      "+ RecordHTTP / RecordProviderCall",
      "+ RecordEvent / RecordRuntime",
      "  best-effort: không bao giờ chặn request",
    )),
  cls((2, 0), "port.Repository", stereo: "interface", name: <ob-repo>,
    ops: (
      "+ InsertHTTPRequests(batch)",
      "+ InsertProviderCalls(batch)",
      "+ InsertBusinessEvents(batch)",
      "+ InsertRuntimeMetrics(batch)",
      "  hiện thực bằng COPY, ghi theo lô",
    )),
  edge(<ob-sink>, <ob-repo>, "-->", rel[qua JetStream + subscribeWriter]),

  cls((0, 1), "HTTPSample", name: <ob-http>,
    attrs: (
      "- ts: time, instance: string",
      "- method, route: string  // route = ServeMux pattern",
      "- status: int",
      "- durationMs: float64",
    )),
  cls((1, 1), "ProviderCall", name: <ob-prov>,
    attrs: (
      "- ts: time, instance, provider: string",
      "- method, path: string  // path đã templated",
      "- status: int  // 0 = không có phản hồi",
      "- durationMs: float64, failed: bool, error: string",
    )),
  cls((2, 1), "BusinessEvent", name: <ob-biz>,
    attrs: (
      "- ts: time, instance: string",
      "- topic: string  // 'order.placed', …",
      "- payload: jsonb  // chỉ id, số tiền, trạng thái",
    )),
  cls((1, 2), "RuntimeSample", name: <ob-rt>,
    attrs: (
      "- ts: time, instance: string",
      "- goroutines: int",
      "- heapAllocBytes, heapInuseBytes: int64",
      "- gcPauseMs: float64, numGC: int64",
    )),
  edge(<ob-sink>, <ob-http>, "-->"),
  edge(<ob-sink>, <ob-prov>, "-->"),
  edge(<ob-sink>, <ob-biz>, "-->"),
  edge(<ob-sink>, <ob-rt>, "-->"),

  cls((0, 2), "http_requests_1m", stereo: "continuous aggregate", name: <ob-agg>,
    attrs: (
      "- bucket: time (1 phút)",
      "- instance, route, status",
      "- calls, avgMs, maxMs",
      "- latency: UddSketch (percentile_agg)",
    ),
    ops: ("  đọc p95: approx_percentile(0.95, latency)", "  KHÔNG bao giờ lấy trung bình của p95")),
  edge(<ob-http>, <ob-agg>, "-->", rel[gộp mỗi phút]),

  cls((2, 2), "provider_calls_1m", stereo: "continuous aggregate", name: <ob-agg2>,
    attrs: (
      "- bucket, instance, provider, status",
      "- calls, failures, avgMs, maxMs",
      "- latency: UddSketch",
    )),
  edge(<ob-prov>, <ob-agg2>, "-->", rel[gộp mỗi phút]),
)

#figure(
  caption: [Chính sách vòng đời dữ liệu quan trắc],
  table(
    columns: (1.1fr, 1fr, 1fr, 1.6fr),
    align: (left + horizon, center + horizon, center + horizon, left + horizon),
    table.header([Hypertable], [Mảnh], [Giữ lại], [Ghi chú]),
    [`http_requests`], [1 ngày], [30 ngày], [Nén cột sau 7 ngày, phân đoạn theo `route`.],
    [`provider_calls`], [1 ngày], [30 ngày], [Phân đoạn theo `provider`.],
    [`business_events`], [1 ngày], [180 ngày], [Chỉ id/số tiền/trạng thái — không dữ liệu cá nhân.],
    [`runtime_metrics`], [7 ngày], [90 ngày], [Phân đoạn theo `instance`.],
    [`http_requests_1m`], [—], [365 ngày], [Bản gộp sống lâu hơn dòng thô, nhưng không vĩnh viễn.],
    [`provider_calls_1m`], [—], [365 ngày], [Không gộp theo `path` — khóa quá rộng thì bản gộp hết rẻ.],
  ),
)

== DDL dùng chung — `audit_log`, `resource`, `option`

Ba bảng này không thuộc module nào. `cmd/migrate` áp *cùng một* tập lệnh DDL vào
*từng* lược đồ, nên bảng tồn tại một lần dưới dạng văn bản và một lần trên mỗi
lược đồ. Đó là lý do chúng không được gom thành bảng toàn cục: một bảng nhật ký
kiểm toán dùng chung sẽ là thứ *duy nhất* không thể đi theo module khi module ấy
tách sang cơ sở dữ liệu riêng.

#fig(
  [Sơ đồ lớp các bảng dùng chung (áp vào mọi lược đồ module)],
  spacing: (12mm, 8mm),

  cls((0, 0), "AuditLog", stereo: "append-only", name: <k-aud>,
    attrs: (
      "- id, version: int64",
      "- tableName: string, recordID: int64",
      "- changeType: insert | update | delete",
      "- code: string  // 'listing.publish', 'account.suspend'",
      "- changedAt: time",
      "- changedBy: *int64  // NULL với tác vụ nền / webhook",
      "- diff: jsonb      // dữ kiện đã ghi nhận",
      "- snapshot: jsonb  // bản ghi sau khi đổi",
    ),
    ops: ("  UNIQUE (tableName, recordID, version)", "  không cấp quyền UPDATE/DELETE cho ứng dụng")),

  cls((1, 0), "Resource", stereo: "tệp tải lên", name: <k-res>,
    attrs: (
      "- id: int64, uploadedByID: *int64",
      "- provider: string  // s3 | minio | local",
      "- objectKey: string, mime: string, size: int64",
      "- metadata: jsonb",
      "- checksum: *string  // chỉ đọc lại từ kho, không tin client",
      "- completedAt: *time  // chưa xác nhận thì chưa gắn được",
      "- deletedAt: *time    // xóa mềm, chờ reaper dọn",
    )),

  cls((2, 0), "Option", stereo: "registry", name: <k-opt>,
    attrs: (
      "- id: string  // slug kebab-case, khóa tự nhiên",
      "- ownerID: *int64  // NULL = do hệ thống cung cấp",
      "- isEnabled: bool, priority: int",
      "- name, description: string",
      "- type: string      // payment | transport | notification",
      "- provider: string  // stripe | vnpay | ghn …",
      "- data: jsonb  // chỉ cấu hình KHÔNG bí mật",
      "- vaultSecretPath: *string  // khóa nằm ở Vault",
      "- logoResourceID: *int64",
      "- deletedAt: *time",
    )),
  edge(<k-opt>, <k-res>, "-", rel[logo]),

  cls((1, 1), "Ai tham chiếu tới đâu", stereo: "ghi chú", name: <k-note>,
    attrs: (
      "resource ← listing.attachments[], variant.attachments[]",
      "         ← message.attachments[], review.attachments[]",
      "         ← order.receiptAttachments[], refund.attachments[]",
      "         (mảng int64 nội tuyến, KHÔNG bảng nối)",
      "option   ← order.item.transportOption  (chuỗi slug)",
      "         ← finance.transaction.paymentOption",
    )),
  edge(<k-res>, <k-note>, "--"),
  edge(<k-opt>, <k-note>, "--"),
)

#note[
  *Vì sao đính kèm là mảng nội tuyến chứ không phải bảng nối.* Một bài đăng và
  ảnh của nó nằm ở hai lược đồ khác nhau; khi hai module tách sang hai cơ sở dữ
  liệu, việc ghi cả hai trong *một* giao dịch không còn khả thi. Giữ mảng
  `BIGINT[]` ngay trên dòng sở hữu khiến thao tác ấy vĩnh viễn là một lần ghi
  duy nhất. Cùng lý do đó, `listing.cached_rating` là bản sao chủ động thay vì
  một khung nhìn `JOIN` sang `trust`.
]

= Đối chiếu với Báo cáo định kỳ lần 2

Bản thiết kế ở Báo cáo định kỳ lần 2 mô tả bảy *vi dịch vụ* triển khai độc lập.
Mã nguồn hiện tại giữ nguyên ranh giới miền nhưng thay đổi bốn điểm; bảng dưới
đây ghi lại các sai khác để người đọc hai tài liệu không bị lệch.

#figure(
  caption: [Sai khác giữa thiết kế ở Báo cáo định kỳ lần 2 và mã nguồn hiện tại],
  table(
    columns: (1fr, 1.2fr, 2.2fr),
    align: (left + horizon, left + horizon, left + horizon),
    table.header([Hạng mục], [Báo cáo lần 2], [Mã nguồn hiện tại]),

    [Đơn vị triển khai],
    [7 vi dịch vụ, mỗi dịch vụ một cổng HTTP/gRPC riêng],
    [Một tiến trình `cmd/gateway`; 7 module tự chứa lắp bằng Uber `fx`. Ranh giới
     lược đồ CSDL được giữ nguyên nên vẫn tách ra được sau này.],

    [Tồn kho],
    [Vi dịch vụ `inventory` riêng, CSDL `db_inventory`],
    [Nhập vào `catalog` — hai bảng `stock` và `stock_movement`. Giữ chỗ tồn kho
     và giá cùng thuộc một biến thể nên tách ra chỉ thêm một lời gọi mạng.],

    [Tiền tệ],
    [Ví và số dư ký quỹ nằm trong `account`],
    [Tách thành module `finance` riêng, giữ *toàn bộ* nguyên thủy tiền tệ để các
     bước dịch chuyển ký quỹ nằm trong một giao dịch.],

    [Uy tín & đánh giá],
    [Thuộc vi dịch vụ `analytic`],
    [Tách thành module `trust`, kèm nhận xét sản phẩm, phản hồi và phiếu hữu ích.],

    [Phân tích số liệu],
    [Vi dịch vụ `analytic` với `pgvector`],
    [Chia đôi: vector tìm kiếm về `catalog` (`listing_embedding`, …); phân tích
     hành vi người dùng ra *ngoài* backend (Rybbit + ClickHouse); quan trắc vận
     hành thành module `observability` trên TimescaleDB.],

    [Chat & thương lượng giá],
    [Vi dịch vụ `chat` giữ cả Offer Card],
    [`chat` chỉ giữ hội thoại và tin nhắn; điều khoản thương lượng nằm ở
     `order.offer` vì chúng quyết định tiền, còn tin nhắn chỉ nói *thẻ nào* cần vẽ.],

    [Bus sự kiện],
    [NATS JetStream cho toàn bộ sự kiện],
    [Hai bus phân biệt bằng kiểu Go: Redis Streams cho sự kiện miền, NATS
     JetStream cho telemetry.],

    [Thực thi bền],
    [Restate cho luồng ghi],
    [Không đổi — `order` chạy `OrderCheckout`, `OrderLifecycle`, `OrderRefund`.],
  ),
)
