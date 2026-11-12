# Design: one order flow for server and app

Date: 2026-11-12.
Status: decided in conversation, question by question and section by
section. Part 1 of 4 (see Scope). When the work lands, the server decisions
go into `server/ARCHITECTURE.md`.

Changed while planning (plan `2026-11-12-server2-order-flow.md`):

- No new event kinds. The spec lists `order.requested`, `order.shipped`, `order.completed`, `order.failed`, `order.cancelled` and `shipment.updated`; the server announces order changes as moves (`cod_requested`, `shipped`, `shipment_updated`, `completed`, `failed`, `order_cancelled`) on the existing `deal.moved`, whose only subscriber, notification, reads moves. New kinds would have no subscriber.
- `carrier.Client` has a third method, `Cancel(ctx, carrier, code)`, for the pickup timeout of a linked shipment and for a linked shipment whose order's save lost a race. The fake and `None` cancel nothing.
- The spec says nothing about production. The fake carrier and its dev endpoint run on the dev and test stacks only; production runs `CARRIER=none`, where the lookup and both shipment endpoints answer 503 `carrier_unavailable`, a status the spec's API table does not list, until part 2 brings GHTK. `app.New` refuses `APP_ENV=prod` with `CARRIER=fake`.
- The order routes keep the path parameter name `order_id` (`/v1/orders/{order_id}/shipment`, `/confirm`), as `/v1/orders/{order_id}/review` and the routes they replace; the URLs are the spec's.
- The migration leaves `orders_shipped_per_listing`: its predicate `status = 'shipped'` already reads the new names. It recreates `orders_open_per_deal` on `pending` and `shipped`.
- An order shipped on carrier `other` (development data only; the app was never wired) loses its shipment in the migration: `other` has no place in the new carrier CHECK and its name column goes. The order keeps its status and `shipped_at`; only the buyer's confirmation closes it.
- The migration also renames the stored notifications of types `delivered` and `returned` to `completed` and `failed` and the reason `sent_to_another` in their params, adds CHECK `orders_shipment_check` (a shipment's mode, carrier, code and status are set together; `delivered_at` only on a delivered one) and index `orders_tracking_code` for `ShipmentUpdated`. `GET /v1/notifications` names the types `completed` and `failed` instead of `delivered` and `returned`.

Settled while planning, where the spec is silent:

- The linked shipment's `service` is `standard` or `express`, `weight_grams` 1 to 20,000.
- A parcel the carrier already reports failed is refused at creation and at a corrected code (`invalid_shipment`); one it reports delivered ships delivered and schedules the auto-complete.
- The seller's turn (`your_turn`) is only a pending order; nobody's turn comes while an order is shipped.
- The seller reads a cancelled order's recipient as name and commune only, the pickup timeout's included.
- The dev endpoint answers 204, also when every order with the code is closed; 404 only when no order has it.
- `carrier_unavailable` is 503 (`apperr.KindUnavailable`, as `search_unavailable` and `source_unavailable`): the stack lacks a service the request needs, and no change to the request or the order would help.
- A manual shipment's carrier and code are checked and read from the carrier before the order is looked up, so the 422s and the 503 answer the same for any order ID.
- The fake reads every known code as one parcel waiting for pickup: COD 1,500,000 đ, fee 22,000 đ.
- Migration 0040 breaks the release before during its rollout (see the plan's Global Constraints).

## Scope

The app and the server describe a COD order differently. The app has 15
order states, a buyer who closes the order, incident records and refunds;
the server has 5 states and a seller who reports delivered or returned.
This design replaces both with one smaller flow and one set of names, on
the server and in the app.

The work is split in four parts, each with its own spec and plan:

1. **This spec.** The order flow on the server, with a fake carrier, and
   in the app's model, rules and fake data. App screens follow the
   mockups of part 4.
2. Real carriers: GHTK order creation, tracking lookups, webhooks or
   polling, the seller's linked GHTK account on the server.
3. Support tickets: "Báo chưa nhận hàng" on an order, a seller's request
   for a carrier that is not supported, feedback from Trợ giúp, and a
   Hỗ trợ screen in console.
4. Superdesign mockups for the new screens of parts 1 and 3.

The app stays on fake data. It is not wired to the server in part 1.

## Decisions

| Question | Decision |
|---|---|
| Order states | `pending` → `shipped` → `completed` or `failed`; `pending` → `cancelled`; `shipped` → `cancelled` only by the pickup timeout. |
| Who closes an order | The buyer confirms receipt, or the system after the carrier reports delivered. The carrier's failure fails it. The seller has no action after creating the shipment, except editing a manual tracking code. |
| Shipment modes | `linked`: created on the seller's linked GHTK account, in one screen with one commit. `manual`: the seller shipped on a carrier's own app and types the tracking code. |
| Carriers | GHTK, GHN, SPX, J&T, Viettel Post: only carriers ShopNexus can read. No "other". A seller whose carrier is missing asks for it through a support ticket (part 3). |
| Fee | Never typed. Read from the carrier; null while unknown. |
| Manual tracking code | Any text. The seller sees a preview read from the carrier before confirming. A code the carrier does not know cannot be confirmed. A COD amount different from the agreed price warns and does not block. Editable while the shipment is `pending_pickup` or `in_transit`. |
| What the buyer sees | "Chờ người bán tạo đơn" while `pending`; "Chờ giao hàng" through the whole of `shipped`, whatever the carrier reports. The buyer's order screen has its own layout; it is not the seller's preview. |
| Early receipt | "Đã nhận hàng" is open from `shipped`, behind a confirmation dialog. |
| Automatic completion | 3 days after the carrier reports delivered. Not shown to anyone. |
| Seller timeout | A `pending` order is cancelled after 3 days (`seller_timeout`). |
| Pickup timeout | A `shipped` order whose shipment is still `pending_pickup` after 3 days is cancelled (`pickup_timeout`); a `linked` one is cancelled at the carrier too. |
| Failed delivery | The order is `failed`. The deal goes back to `negotiating` and loses its agreed price. The listing is released. The buyer can tap "Mua lại", which works like Mua on the listing; either side can also send a new offer in chat. |
| Reputation on failure | No points taken. The buyer's 90-day figures count failed deliveries against orders, and sellers judge for themselves. COD inspection lets a buyer refuse a parcel that is not as described, and a failure does not say why. |
| Refunds and incident records | Gone. The app has no refund state. The two people settle it in chat. The record card leaves the chat. |
| "Báo chưa nhận hàng" | A support ticket for ShopNexus (part 3). It does not change the order and the seller does not see it. Not in part 1. |
| Late carrier signals | Ignored once the order is closed. |
| Chat mascots | The two milestone drawings (`Art.Deal`, `Art.Received`) become event lines. |
| Fake carrier on the server | A dev endpoint, present only with `CARRIER=fake`, sets a shipment's status. |

## Server

### Domain (`internal/deal/domain`)

```
Order
  status         pending | shipped | completed | failed | cancelled
  shipment       *Shipment (set from shipped on)
  cancelled_by   buyer | seller | system
  cancel_reason  buyer | seller | seller_timeout | pickup_timeout
                 | shipped_to_another | listing_closed
  requested_at, shipped_at, closed_at

Shipment (replaces Waybill)
  mode           linked | manual
  carrier        ghtk | ghn | spx | jt | viettel_post
  tracking_code  1 to 50 characters
  fee            *int64, from the carrier
  status         pending_pickup | in_transit | delivered | failed
  delivered_at
```

`sent_to_another` is renamed `shipped_to_another`. `Waybill`,
`NewWaybill`, `SourceSelf`, `CarrierOther`, `MaxFee` and
`maxCarrierName` go.

Deal states stay `negotiating`, `agreed`, `sold`. Deal moves: `delivered`
becomes `completed`, `returned` becomes `failed`, and `shipment_updated`
is added.

| Move | By | When | Result |
|---|---|---|---|
| Request COD | buyer | as today | order `pending` |
| Cancel | buyer or seller | order `pending` | order `cancelled`, deal negotiating |
| Create shipment | seller | order `pending`, listing `active` | order `shipped`, listing `reserved`, other `pending` orders on it cancelled (`shipped_to_another`) |
| Edit tracking code | seller | `manual`, shipment `pending_pickup` or `in_transit` | shipment re-read from the carrier |
| Confirm receipt | buyer | order `shipped` | order `completed`, deal `sold`, listing `sold` |
| Shipment updated | system | order `shipped` | shipment status set; see below |
| Seller timeout | system | order `pending` after 3 days | order `cancelled` (`seller_timeout`) |
| Pickup timeout | system | shipment `pending_pickup` 3 days after `shipped` | order `cancelled` (`pickup_timeout`), listing released |
| Auto-complete | system | 3 days after shipment `delivered`, order still `shipped` | order `completed`, deal `sold`, listing `sold` |

A shipment update to `delivered` sets `delivered_at` and schedules the
auto-complete. An update to `failed` fails the order at once: deal
`negotiating` without its agreed price, listing released. An update for a
closed order changes nothing.

### Carrier provider (`internal/provider/carrier`)

```go
type Client interface {
    // Create makes a shipment on the seller's linked account: its tracking code and fee.
    Create(ctx context.Context, in CreateInput) (Created, error)
    // Lookup reads a shipment by carrier and code; ErrNotFound when the carrier does not know it.
    Lookup(ctx context.Context, carrier Carrier, code string) (Parcel, error)
}
```

`Parcel` holds the recipient's name masked, the district, the COD amount,
the status and the fee.

The fake client finds every code except those that start with `NOTFOUND`,
and creates codes of the form `GHTK-` and a number. Part 2 adds the real
clients behind the same interface.

### API

| Endpoint | By | Idempotent | Errors |
|---|---|---|---|
| `POST /v1/deals/{id}/cod {recipient}` | buyer | no | unchanged |
| `POST /v1/deals/{id}/cancel` | buyer or seller | no | unchanged |
| `GET /v1/shipments/lookup?carrier=&code=` | seller | — | 404 `shipment_not_found`; 422 `invalid_shipment` |
| `POST /v1/orders/{id}/shipment` | seller | yes | 404; 409 `move_not_allowed`, `listing_unavailable`; 422 `invalid_shipment`, `shipment_not_found` |
| `PUT /v1/orders/{id}/shipment {carrier, tracking_code}` | seller | no | 404; 409 `move_not_allowed`; 422 `invalid_shipment`, `shipment_not_found` |
| `POST /v1/orders/{id}/confirm` | buyer | yes | 404; 409 `move_not_allowed` |
| `GET /v1/me/orders` | either | — | unchanged |
| `POST /v1/dev/shipments/{code}/status {status}` | anyone, only with `CARRIER=fake` | no | 404 `shipment_not_found`; 422 `invalid_status` |

`POST /v1/orders/{id}/shipment` takes `{mode: "manual", carrier,
tracking_code}` or `{mode: "linked", service, weight_grams, pickup}` with
`pickup` one of `home` or `post_office`. Part 1 does not check that the
seller linked a GHTK account; part 2 does.

`/v1/orders/{id}/ship`, `/deliver` and `/return` go.

### Durable work

The timeouts and the auto-complete are Restate sends with `WithDelay`, as
media and assist already use. Each one reads the order when it fires and
does nothing when the order moved on. The dev endpoint and, later, the
webhooks and polling call one entry point, `ShipmentUpdated(code,
status)`.

### Migration

One new migration:

- Order statuses: `requested` → `pending`, `delivered` → `completed`,
  `returned` → `failed`; new CHECK.
- Drop `waybill_source` and `carrier_name`; carrier CHECK without
  `other`.
- Add `shipment_mode`, `shipment_status`, `delivered_at`; `fee` nullable.
- Cancel reason `sent_to_another` → `shipped_to_another`, plus
  `seller_timeout` and `pickup_timeout`.
- Indexes `orders_open_per_deal` and `orders_shipped_per_listing` follow
  the new names.
- Deal move kinds follow the new names.

### Events

`order.requested`, `order.shipped`, `order.completed`, `order.failed`,
`order.cancelled`, `shipment.updated`.

### Unchanged

At most 3 open (`pending` or `shipped`) orders per buyer. Recipient data
rules. Reviews.

## App

### Model (`core/model`)

The app's model follows the server's.

```
Deal
  status     NEGOTIATING | AGREED | SOLD
  orders     List<Order>, oldest first; the last is the current one
  rating, thread, ... unchanged

Order
  status     PENDING | SHIPPED | COMPLETED | FAILED | CANCELLED
  shipment   Shipment?
  cancelledBy, cancelReason, recipient, price, requestedAt, shippedAt, closedAt

Shipment
  mode       LINKED | MANUAL
  carrier    GHTK | GHN | SPX | JT | VIETTEL_POST
  trackingCode, fee?, status (PENDING_PICKUP | IN_TRANSIT | DELIVERED | FAILED)
  events     List<CarrierEvent>
```

These go: `CodRequest`, `CodShipment`, `CodStatus`, `DealStage`,
`DealEnd`, `RefusalReason`, `ShipMethod`, `IncidentRecord`,
`RecordStatus`, `ThreadItem.Record`, and the 15-value `OrderStatus` in
`core/domain`. The four-step bar (Thương lượng, Tạo đơn, Nhận hàng, Đánh
giá) is computed from the deal and its current order. Screens pick their
words from the role, the order status and the shipment status.

### Rules (`DealRules`)

| Command | By | When |
|---|---|---|
| `RequestCod` | buyer | deal `AGREED` |
| `CancelOrder` | buyer or seller | order `PENDING` |
| `CreateShipment` (manual: carrier, code; linked: service, weight, pickup) | seller | order `PENDING` |
| `EditTrackingCode(carrier, code)` | seller | `MANUAL`, shipment `PENDING_PICKUP` or `IN_TRANSIT` |
| `ConfirmReceived` | buyer | order `SHIPPED` |
| `Rate` | buyer | order `COMPLETED` |

These go: `CreateWaybill`, `RecordSelfShipment`, `ShipParcel`,
`ReportNotReceived`, `OpenRecord`, `RefundRecord`, `DeclineRecord`,
`ConfirmRefund`, `WithdrawRecord`.

### Fake data (`core/data/fake`)

- The fake carrier follows the server's: codes starting with `NOTFOUND`
  are not found; linked shipments get `GHTK-` codes.
- The simulator moves a shipment `PENDING_PICKUP` → `IN_TRANSIT` (with a
  warehouse event) → `DELIVERED`, then completes the order 3 days later.
  The two 3-day timeouts run as on the server.
- `DebugControls` jumps to `PENDING`, `SHIPPED`, `DELIVERED`,
  `COMPLETED`, `FAILED` and `CANCELLED`. Failure comes only from there.

### Screens (built from the part 4 mockups)

Seller, create shipment, one screen and one commit:

- With GHTK linked: a GHTK tab first (service, weight, pickup at home or
  at a post office, the fee read-only, "Tạo đơn"), and a "Tự gửi" tab.
- Without: "Tự gửi" only (5 carrier chips, the code, the preview,
  "Xác nhận"), and a line that leads to the existing CodSetup flow to link
  GHTK.
- No pack photo, no fee field, no "Khác", no separate "Gửi hàng" step.
- After creation the seller's order screen is read-only, with "Sửa mã"
  on a manual shipment that can still be edited.

Buyer, order screen:

| Order | Shown |
|---|---|
| `PENDING` | Chờ người bán tạo đơn · Hủy |
| `SHIPPED` | Chờ giao hàng · carrier, code, carrier events · Đã nhận hàng (with a confirmation dialog) |
| `COMPLETED` | Đã nhận hàng · stars |
| `FAILED` | Giao không thành · Mua lại |
| `CANCELLED` | Đã hủy |

No timer text anywhere.

Orders list: one row per order, so a deal that failed and was bought again
shows two rows.

Chat: the two milestone drawings become event lines; `RecordCard` and
the record thread item go; the chat console and the composer read the new
model.

Standing and Tôi: the 90-day figures show failed deliveries against
orders and drop the two record figures; `dueOrder` keeps only orders
waiting for the seller to create a shipment; `TierSheet` drops records.

## Order of work

1. Server: domain, migration, carrier provider with the fake client,
   service, handlers, dev endpoint, durable work.
2. App: model, rules, fake data and the screens that only change wording
   or lose record parts (chat, Standing, orders list).
3. Part 4 mockups: create shipment (both modes), edit tracking code,
   buyer order screen in its five states.
4. App: the new and redesigned screens from those mockups.

## Testing

Server: domain tests for every move, from each side and in each state;
service tests for the timeouts and auto-complete, including a timer that
fires after the order moved on; one e2e test through the dev endpoint for
the delivered branch and one for the failed branch.

App: `DealRules` tests for each command from the right and the wrong
side; simulator tests for the shipment steps and the 3-day timers; the
existing screen tests of CodOrder, ShipOrder, Orders and Chat updated to
the new model.
