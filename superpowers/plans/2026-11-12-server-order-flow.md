# Order flow on the server: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A COD order on the server runs `pending` → `shipped` → `completed` or `failed` (or `cancelled`), with a shipment that is `linked` (made at GHTK) or `manual` (typed and read from the carrier), closed by the buyer's confirmation or by the system after the carrier's report, with a fake carrier and a dev endpoint that moves its shipments on the dev and test stacks and no carrier (`CARRIER=none`) in production.

**Architecture:** Module `deal` keeps the `Deal` aggregate and its latest `Order`; `Shipment` replaces `Waybill`. A new provider `internal/provider/carrier` (`Client{Create, Lookup, Cancel}`, with `Fake` for dev and test and `None` for production) makes and reads shipments. The seller's shipment and the buyer's confirmation change the listing, so they run as Restate flows (`DealShip`, `DealConfirm`); the three timeouts are delayed Restate sends to `OrderTimers`, and every carrier report enters through one Restate service, `ShipmentUpdates`. Each system flow reads the deal, decides between steps, saves, and reads again when its save loses a race. Migration 0040 renames the stored values.

**Tech Stack:** Go 1.27, Restate Go SDK v1.1.0 (`restate.WithDelay`), pgx v5, Postgres 18, kin-openapi request validation, Helm (infra values only).

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-12-order-flow-sync-design.md` (sections "Decisions", "Server", "Order of work" step 1, "Testing" for the server). The "App" section is another plan's; this plan only keeps its names.

## Global Constraints

- Repos: `~/shopnexus/server` (Go module `github.com/shopnexus/server`), the umbrella `~/shopnexus` (`docker-compose.yml`, `infra/`, `checklist.md`) and `~/shopnexus/docs` (this plan and the spec). Work on branch `feat/order-flow` in each repo touched, never on `main`. Other sessions commit to server `main`, so create the server branch in a git worktree (superpowers:using-git-worktrees, under `server/.worktrees/order-flow`) and rebase on `main` before the final review.
- Read `server/CLAUDE.md` and `server/ARCHITECTURE.md` (sections Use cases, HTTP handlers, Durable flows, Events, Deal, Notifications, Testing, Restate in practice) before the first server task.
- Decisions copied from the spec and the brief, not to be reopened:
  - Order status `pending | shipped | completed | failed | cancelled`. `pending` → `shipped` → `completed` or `failed`; `pending` → `cancelled`; `shipped` → `cancelled` only by the pickup timeout.
  - `Shipment` replaces `Waybill`: `mode linked | manual`, `carrier ghtk | ghn | spx | jt | viettel_post` (no `other`, no `carrier_name`), `tracking_code` 1 to 50 characters, `fee *int64` from the carrier (never typed, null while unknown), `status pending_pickup | in_transit | delivered | failed`, `delivered_at`. `Waybill`, `NewWaybill`, `SourceSelf`, `CarrierOther`, `MaxFee` and `maxCarrierName` go.
  - Cancel reasons `buyer | seller | seller_timeout | pickup_timeout | shipped_to_another | listing_closed` (`sent_to_another` is renamed). `cancelled_by buyer | seller | system`.
  - Deal states stay `negotiating`, `agreed`, `sold`. Deal moves: `delivered` becomes `completed`, `returned` becomes `failed`, `shipment_updated` is added.
  - Endpoints: `POST /v1/deals/{id}/cod` and `POST /v1/deals/{id}/cancel` unchanged; `GET /v1/shipments/lookup?carrier=&code=` (404 `shipment_not_found`; 422 `invalid_shipment`); `POST /v1/orders/{order_id}/shipment` idempotent (404; 409 `move_not_allowed`, `listing_unavailable`; 422 `invalid_shipment`, `shipment_not_found`) taking `{mode: "manual", carrier, tracking_code}` or `{mode: "linked", service, weight_grams, pickup}` with `pickup` `home | post_office`; `PUT /v1/orders/{order_id}/shipment {carrier, tracking_code}` not idempotent (404; 409 `move_not_allowed`; 422 `invalid_shipment`, `shipment_not_found`); `POST /v1/orders/{order_id}/confirm` idempotent (404; 409 `move_not_allowed`); `GET /v1/me/orders` unchanged; `POST /v1/dev/shipments/{code}/status {status}` for anyone, registered only with `CARRIER=fake` (404 `shipment_not_found`; 422 `invalid_status`), which only the dev and test stacks run (decided 2026-11-12, after the spec). `/v1/orders/{order_id}/ship`, `/deliver` and `/return` go.
  - Carrier provider `internal/provider/carrier` with `Client{Create, Lookup}` (this plan adds `Cancel`, see Deviations). The fake finds every code except those that start with `NOTFOUND` and creates codes `GHTK-<number>`.
  - `CARRIER` is `fake` or `none`. Local development, the test stack, every hand-built test config and the dev cluster stack run `fake`; the production cluster stack runs `none`. With `none` the dev endpoint is not registered, and `GET /v1/shipments/lookup`, `POST /v1/orders/{order_id}/shipment` and `PUT /v1/orders/{order_id}/shipment` answer 503 `carrier_unavailable` (`apperr.KindUnavailable`, the kind of `search_unavailable` and `source_unavailable`). `none` is `carrier.None`, a `carrier.Client` whose `Create` and `Lookup` return `carrier.ErrUnavailable`; the use cases map that error as they map `carrier.ErrNotFound`, and no use case checks which carrier it has. Confirm, cancel, the COD request, the timers and `ShipmentUpdated` work the same with `none`.
  - Timers are Restate sends with `WithDelay`; each reads the order when it fires and does nothing when the order moved on: `pending` 3 days → `cancelled` (`seller_timeout`); shipment still `pending_pickup` 3 days after `shipped` → `cancelled` (`pickup_timeout`, a linked one cancelled at the carrier too, listing released); shipment `delivered` → 3 days → `completed` (deal `sold`, listing `sold`). A shipment update to `failed` fails the order at once: deal `negotiating` without its agreed price, listing released. A signal for a closed order changes nothing. One entry point, `ShipmentUpdated(code, status)`, which the dev endpoint calls.
  - The buyer may confirm at any time the order is `shipped`. Part 1 does not check that the seller linked a GHTK account. No support tickets. No reputation on the server. At most 3 open (`pending` or `shipped`) orders per buyer, recipient rules and reviews unchanged.
- Shape rules: the request validator (`httpx.ValidateRequests`) answers `invalid_request` 400 for a body that matches no branch of the shipment's `oneOf` (its `mode` picks the branch), an unknown field, a missing field or a wrong type. Every other rule of a shipment (carrier, code length, service, weight, pickup, a parcel the carrier reports failed) is the domain's 422 `invalid_shipment` with fields, as the waybill's rules were; the status of the dev endpoint is the domain's 422 `invalid_status`.
- Every route in `api/openapi.yaml` has a handler and the reverse (`internal/app/routes_test.go`); every documented status of every operation is observed by `e2e/` (`e2e/main_test.go`); e2e validates every response against the spec. The e2e suite shares one database, and one carrier report moves every order with its code, so every e2e shipment takes a fresh tracking code (`trackingCode()` in Task 8). The shared e2e server runs `CARRIER=fake`; the 503 `carrier_unavailable` statuses are observed from a second server with `CARRIER=none` on a database of its own (`TestNoCarrier`, Task 8), as `TestReadyzDown` builds one.
- Use cases, Restate handlers and HTTP handlers read top to bottom; no single-use helpers. Helpers with several callers: `loadStep`, `systemLoadStep`, `saveStep`, `reserveStep`, `releaseStep`, `sellStep`, `orderDeal`, `Deal.complete`, `Deal.cancelOrder`, `Deal.Shippable`, `domain.Tracking`.
- Durable flows: a step only reads or writes; every decision is taken between steps on journaled values. A system flow (`OrderTimers`, `ShipmentUpdates`) whose save loses a race (`domain.ErrChanged` as data) loads again in a new step and decides again. A timer never compares clocks: it names its order and acts only when the deal's open order is that order in the state the timer is for.
- Waits: `domain.OrderWaits` (3 days each) in production; tests build a second service with short waits. `service.New` panics on a zero wait, since a zero wait would cancel every order the moment it is requested.
- Configuration has no defaults. This plan adds `CARRIER`, `fake` or `none`. `fake` is set in `server/.env.example`, in the hand-built configs of `internal/platform/config/config_test.go`, `internal/app/app_test.go`, `e2e/main_test.go` and `e2e/system_test.go`, in the umbrella's `docker-compose.yml` (`x-server-env`) and in `infra/stack/values-dev.yaml`; `none` in `infra/stack/values-prod.yaml`. `infra/stack/values.yaml` sets no carrier, so a stack values file that forgets it fails to render (`required`). A missing or other value stops the process with its name (`config.Load` with `oneOf`; `app.New` refuses another value in a hand-built config), and `app.New` refuses `APP_ENV=prod` with `CARRIER=fake`, as it refuses the log email sender, since anyone could then move shipments.
- A manual shipment's carrier and code are checked and read from the carrier before the order is looked up, in `CreateShipment` and in `EditShipment`, so a stack without a carrier refuses before it reads any order, and the 422s and the 503 answer the same for any order ID.
- Migrations: the last is `0039_listing_reads.sql`. This plan adds `0040_order_flow.sql` (Task 4). If the number is taken when the work starts, take the next free one and say so in the commit. Unlike `0037_upload_origin.sql` and `0039_listing_reads.sql`, 0040 renames values the release before writes and drops two columns it reads, so that release's order reads and writes fail for the minutes a deploy rolls out. That is accepted because the spec's part 1 does not wire the app to the server; the migration's header says so.
- Events: the order's changes ride on `deal.moved` as moves (see Deviations).
- Commits: no `Co-Authored-By` trailer in any shopnexus repo. Prefixes as in `git log`: `feat(deal): …`, `feat(carrier): …`, `feat(notification): …`, `refactor(deal): …`, `docs: …` in server; `build: …` in the umbrella; `spec(orders): …`/`plan(orders): …` in docs.
- Prose in code comments, `ARCHITECTURE.md`, `.env.example` comments and commit messages goes through the `humanizing-writing` skill's checker: `python3 ~/.claude/skills/humanizing-writing/ai-tells.py FILE`.
- Server tests: `make test` once (starts the test stack, runs everything and `golangci-lint run`); then `go test ./internal/<module>/...`, `go test ./migrations/` and `go test ./e2e/ -run <Name>` while working. Long output goes to `tmp/` in the worktree, never `/tmp`. Do not poll processes in loops.
- The build is red between tasks. Task 1 changes `api/`, so `internal/app`'s `TestRoutesMatchSpec` and `e2e` fail until Task 8. Task 3 changes the domain, so `internal/deal/repository` builds again in Task 4, `internal/deal/service`, `internal/trust` and `internal/notification` in Task 5, and `internal/deal/handler`, `internal/app` and `e2e` in Task 8. Each task runs exactly the packages it names; `go build ./...` and `make test` pass again at the end of Task 8.

## Review Focus

1. Two orders shipped under one tracking code (two items in one parcel, or a seller who types one code for two orders): one carrier report must move both, and a failed report must fail both and release both listings. Task 6 `TestOneParcelTwoOrders`.
2. A carrier report that arrives while the buyer confirms receipt, so the report's save loses the race: the report must read the deal again and leave the completed order alone, not retry its stale save forever or answer an error. Task 6 `TestShipmentUpdateLosesToAConfirm`.
3. A pending order cancelled and asked for again within 3 days: the first order's seller timer fires on the deal whose open order is now the second one, and must leave it pending; the second order's own timer still cancels it. Task 6 `TestTimersLeaveAnOrderThatMovedOn`.
4. A seller who types the code of a parcel the carrier already reports delivered (it arrived before the seller typed it): the order ships with the shipment `delivered` and the auto-complete is scheduled at once, or the order would wait for a buyer who may never confirm. Task 6 `TestShipADeliveredParcelCompletes`.
5. In production (`CARRIER=none`) a seller asks for a linked shipment: `DealShip` has already reserved the listing when GHTK's `Create` fails, and the flow must release it and answer 503 `carrier_unavailable`, not retry the carrier forever with the listing held and other buyers' orders blocked. A buyer's confirmation, a cancel and a COD request must still work there. Task 5 `TestNoCarrier`.

## Deviations from the spec

Task 10 records these in the spec and in `ARCHITECTURE.md`:

- No new event kinds. The spec lists `order.requested`, `order.shipped`, `order.completed`, `order.failed`, `order.cancelled` and `shipment.updated`; the server announces order changes as moves (`cod_requested`, `shipped`, `shipment_updated`, `completed`, `failed`, `order_cancelled`) on the existing `deal.moved`, whose only subscriber, notification, reads moves. New kinds would have no subscriber.
- `carrier.Client` has a third method, `Cancel(ctx, carrier, code)`, for the pickup timeout of a linked shipment and for a linked shipment whose order's save lost a race. The fake and `None` cancel nothing.
- The spec says nothing about production. The fake carrier and its dev endpoint run on the dev and test stacks only; production runs `CARRIER=none`, where the lookup and both shipment endpoints answer 503 `carrier_unavailable`, a status the spec's API table does not list, until part 2 brings GHTK. `app.New` refuses `APP_ENV=prod` with `CARRIER=fake`.
- The order routes keep the path parameter name `order_id` (`/v1/orders/{order_id}/shipment`, `/confirm`), as `/v1/orders/{order_id}/review` and the routes they replace; the URLs are the spec's.
- The migration leaves `orders_shipped_per_listing`: its predicate `status = 'shipped'` already reads the new names. It recreates `orders_open_per_deal` on `pending` and `shipped`.
- An order shipped on carrier `other` (development data only; the app was never wired) loses its shipment in the migration: `other` has no place in the new carrier CHECK and its name column goes. The order keeps its status and `shipped_at`; only the buyer's confirmation closes it.
- The migration also renames the stored notifications of types `delivered` and `returned` to `completed` and `failed` and the reason `sent_to_another` in their params, adds CHECK `orders_shipment_check` (a shipment's mode, carrier, code and status are set together; `delivered_at` only on a delivered one) and index `orders_tracking_code` for `ShipmentUpdated`. `GET /v1/notifications` names the types `completed` and `failed` instead of `delivered` and `returned`.

## File map

server (`~/shopnexus/server`):

| File | Responsibility | Task |
|---|---|---|
| `api/openapi.yaml`, `api/paths/deal.yaml`, `api/schemas/deal.yaml`, `api/schemas/notification.yaml`, `api/paths/trust.yaml`, `api/paths/account.yaml` | the contract | 1 |
| `internal/provider/carrier/carrier.go`, `fake.go`, `fake_test.go`, `none.go`, `none_test.go` | `Client`, `Parcel`, `Fake`, `None` | 2 |
| `internal/deal/domain/order.go`, `order_test.go`, `deal.go`, `errors.go`, `erasure.go`, `turn_test.go`, `erasure_test.go` | statuses, `Shipment`, the moves | 3 |
| `migrations/0040_order_flow.sql`, `migrations/order_flow_test.go` | the new names on stored rows, the shipment columns | 4 |
| `internal/deal/repository/deal_pg.go`, `repository.go`, `erasure_pg.go`, `deal_pg_test.go`, `pairs_pg_test.go`, `erasure_pg_test.go` | shipment columns, `OrdersWithCode` | 4 |
| `internal/deal/service/service.go`, `views.go`, `order_flow.go`, `order_ship_durable.go`, `order_confirm_durable.go` (was `order_finish_durable.go`), `order_shipment_create.go`, `order_shipment_edit.go`, `order_confirm.go`, `shipment_lookup.go` (these four replace `order_ship.go`), `order_request.go`, `listing_changed.go` | the seller's and the buyer's moves | 5, 6 |
| `internal/deal/service/helpers_test.go`, `flow_test.go`, `order_test.go`, `pairs_test.go`, `account_deleted_test.go` | service tests | 5, 6 |
| `internal/deal/service/order_timers_durable.go`, `shipment_updated_durable.go`, `shipment_updated.go`, `order_timers_test.go`, `shipment_updated_test.go` | the system's moves | 6 |
| `internal/trust/service/review.go`, `helpers_test.go`, `review_test.go` | reviewable statuses | 5, 6 |
| `internal/notification/worker/worker.go`, `internal/notification/domain/notice.go`, `notice_test.go` | the shipment's code; notices of the new moves | 5, 7 |
| `internal/platform/config/config.go`, `config_test.go`, `.env.example` | `CARRIER` | 8 |
| `internal/deal/handler/handler.go`, `order.go`, `shipment.go`, `internal/deal/deal.go`, `internal/app/app.go`, `internal/app/app_test.go` | routes, wiring | 8 |
| `e2e/main_test.go`, `e2e/system_test.go`, `e2e/order_test.go`, `e2e/no_carrier_test.go`, `e2e/deal_test.go`, `e2e/review_test.go`, `e2e/erasure_test.go` | end to end, a second server with `CARRIER=none` | 8 |
| `ARCHITECTURE.md` | decisions | 10 |

umbrella (`~/shopnexus`) and docs (`~/shopnexus/docs`):

| File | Responsibility | Task |
|---|---|---|
| `docker-compose.yml`, `infra/stack/values.yaml`, `infra/stack/values-dev.yaml`, `infra/stack/values-prod.yaml`, `infra/stack/templates/_server-env.tpl`, `infra/stack/tests/server_env_test.yaml`, `infra/check.sh` | `CARRIER`: `fake` in compose and dev, `none` in prod | 9 |
| `checklist.md`, `docs/superpowers/specs/2026-11-12-order-flow-sync-design.md` | the ticks and the deviations | 10 |

## Task order and interfaces

Tasks 1 and 2 are independent of each other. Task 3 needs nothing. Task 4 needs 3. Task 5 needs 2, 3 and 4. Task 6 needs 5. Task 7 needs 5. Task 8 needs 1, 6 and 7. Task 9 is independent of the server code but ships with Task 8's release. Task 10 comes last.

Names later tasks rely on:

- `carrier.Carrier`, `carrier.Status` with `StatusPendingPickup`, `StatusInTransit`, `StatusDelivered`, `StatusFailed`; `carrier.ErrNotFound`; `carrier.Recipient{Name, Phone, Street, CommuneCode string}`; `carrier.CreateInput{OrderID uuid.UUID; Recipient Recipient; COD int64; WeightGrams int; Service, Pickup string}`; `carrier.Created{TrackingCode string; Fee int64}`; `carrier.Parcel{RecipientName, District string; COD int64; Status Status; Fee *int64}`; `carrier.Client` with `Create(ctx, in CreateInput) (Created, error)`, `Lookup(ctx, c Carrier, code string) (Parcel, error)`, `Cancel(ctx, c Carrier, code string) error`; `carrier.Fake{}`; `carrier.None{}` and `carrier.ErrUnavailable` (`Create` and `Lookup` of `None`).
- `domain.OrderPending`, `OrderShipped`, `OrderCompleted`, `OrderFailed`, `OrderCancelled`; `domain.CancelByBuyer`, `CancelBySeller`, `CancelSellerTimeout`, `CancelPickupTimeout`, `CancelShippedToAnother`, `CancelListingClosed`; `domain.CarrierGHTK`, `CarrierGHN`, `CarrierSPX`, `CarrierJT`, `CarrierViettelPost`; `domain.ShipmentMode` with `ModeLinked`, `ModeManual`; `domain.ShipmentStatus` with `ShipmentPendingPickup`, `ShipmentInTransit`, `ShipmentDelivered`, `ShipmentFailed`; `domain.Shipment{Mode; Carrier; TrackingCode string; Fee *int64; Status; DeliveredAt *time.Time}`; `domain.LinkedService` (`ServiceStandard`, `ServiceExpress`), `domain.Pickup` (`PickupHome`, `PickupPostOffice`), `domain.LinkedDraft{Service; WeightGrams int; Pickup}`, `domain.MaxWeight = 20_000`; `domain.Waits{Seller, Pickup, Complete time.Duration}`, `domain.OrderWaits`; `Order.Shipment *Shipment`.
- `domain.Tracking(carrier, code string) (Carrier, string, error)`, `domain.NewLinkedDraft(service string, weightGrams int, pickup string) (LinkedDraft, error)`, `domain.ParseShipmentStatus(s string) (ShipmentStatus, error)`.
- `domain.MoveShipmentUpdated`, `MoveCompleted`, `MoveFailed` (`MoveDelivered`, `MoveReturned` go).
- `(*Deal)` moves: `Shippable(by Party, order uuid.UUID, l Listing) error`, `Ship(by Party, order uuid.UUID, s Shipment, l Listing, now time.Time) error`, `EditShipment(by Party, order uuid.UUID, s Shipment, now time.Time) error`, `ConfirmReceipt(by Party, order uuid.UUID, now time.Time) error`, `ShipmentUpdated(order uuid.UUID, status ShipmentStatus, now time.Time) (bool, error)`, `SellerTimeout(order uuid.UUID, now time.Time) error`, `PickupTimeout(order uuid.UUID, now time.Time) error`, `AutoComplete(order uuid.UUID, now time.Time) error` (`Deliver`, `Return` go).
- `domain.ErrInvalidShipment` (422 `invalid_shipment`), `domain.ErrShipmentUnknown` (422 `shipment_not_found`), `domain.ErrShipmentNotFound` (404 `shipment_not_found`), `domain.ErrInvalidStatus` (422 `invalid_status`), `domain.ErrCarrierUnavailable` (503 `carrier_unavailable`); `ErrInvalidWaybill` goes. The two `shipment_not_found` errors share a code, so `errors.Is` cannot tell them apart; tests check `apperr.From(err).Kind`.
- `repository.Deals.OrdersWithCode(ctx, code string) ([]OrderRow, error)`.
- `service.Deps.Carrier carrier.Client` (Task 5), `service.Deps.Waits domain.Waits` (Task 6).
- `service.ShipmentInput{Mode, Carrier, TrackingCode, Service string; WeightGrams int; Pickup string}`, `service.ShipmentPreview`, `service.FlowInput{Caller, DealID, OrderID uuid.UUID; Manual *domain.Shipment; Linked *domain.LinkedDraft}`, `service.OrderRef{DealID, OrderID uuid.UUID}`, `service.ShipmentSignal{TrackingCode string; Status domain.ShipmentStatus}`, `service.ShipmentResult`.
- `service.Service`: `CreateShipment(ctx, caller, order uuid.UUID, idempotencyKey string, in ShipmentInput) (DealView, error)`, `EditShipment(ctx, caller, order uuid.UUID, carrierCode, trackingCode string) (DealView, error)`, `ConfirmReceipt(ctx, caller, order uuid.UUID, idempotencyKey string) (DealView, error)`, `LookupShipment(ctx, carrierCode, trackingCode string) (ShipmentPreview, error)` (Task 5); `ShipmentUpdated(ctx, trackingCode, status string) error` (Task 6). `Ship`, `Deliver`, `Return` and `WaybillInput` go.
- Restate services: `DealShip.Run`, `DealConfirm.Run` (was `DealFinish`), `OrderTimers.SellerTimeout`, `.PickupTimeout`, `.AutoComplete` (each `(restate.Context, OrderRef) error`), `ShipmentUpdates.Run(restate.Context, ShipmentSignal) (ShipmentResult, error)`.
- `service.OrderView.Shipment *domain.Shipment` (replaces `Waybill`).
- `deal.Settings{Carrier carrier.Client; FakeCarrier bool}`, `deal.Mount(d, s Settings, accounts, catalog)`; `(*handler.Handler).Register(r, protect, fakeCarrier bool)`; handlers `CreateShipment`, `EditShipment`, `ConfirmReceipt`, `LookupShipment`, `SetShipmentStatus`.
- `config.Config.Carrier string` (`CARRIER`: `fake` or `none`).
- Notification: `domain.TypeCompleted = "completed"`, `domain.TypeFailed = "failed"` (`TypeDelivered`, `TypeReturned` go).
- Test helpers: deal service `e.pending` (was `e.requested`), `e.shipped`, `manual(code)`, `linked`, `e.timed`; repository `pendingDeal` (was `requestedDeal`); trust `e.pending` (was `e.requested`); e2e `pendingOrder` (was `requestedOrder`), `shippedOrder`, `trackingCode`, `shipmentBody`, `setShipmentStatus`, and the package variable `serverConfig` (the shared server's `config.Config`, for a second server).

---

### Task 1: The contract

The design starts in `api/`. This task changes only the spec; the routes and handlers follow in Task 8, so `TestRoutesMatchSpec` and e2e fail until then.

**Files:**
- Modify: `api/openapi.yaml:94-99` (the three order routes)
- Modify: `api/paths/deal.yaml` (`dealCancel` and `dealCod` texts; `orderShip`, `orderDeliver`, `orderReturn` replaced)
- Modify: `api/schemas/deal.yaml` (`DealStatus`, `DealSummary`, `Move`, `WaybillDraft`, `Recipient`, `Waybill`, `OrderStatus`, `Order`, `OrderItem`)
- Modify: `api/schemas/notification.yaml:23-25`, `api/paths/trust.yaml:6`, `api/paths/account.yaml:78`

**Interfaces:**
- Consumes: nothing.
- Produces: 503 `carrier_unavailable` on `createShipment`, `editShipment` and `lookupShipment`; operations `createShipment`, `editShipment` (`/v1/orders/{order_id}/shipment`), `confirmReceipt` (`/v1/orders/{order_id}/confirm`), `lookupShipment` (`/v1/shipments/lookup`), `setShipmentStatus` (`/v1/dev/shipments/{code}/status`); schemas `Carrier`, `ShipmentDraft`, `ManualShipmentDraft`, `LinkedShipmentDraft`, `TrackingCode`, `ShipmentStatus`, `Shipment`, `ShipmentPreview`, `ShipmentStatusChange`, `CancelReason`.

- [ ] **Step 1: The routes**

In `api/openapi.yaml`, replace

```yaml
  /v1/orders/{order_id}/ship:
    $ref: "paths/deal.yaml#/orderShip"
  /v1/orders/{order_id}/deliver:
    $ref: "paths/deal.yaml#/orderDeliver"
  /v1/orders/{order_id}/return:
    $ref: "paths/deal.yaml#/orderReturn"
  /v1/me/orders:
    $ref: "paths/deal.yaml#/myOrders"
```

with

```yaml
  /v1/orders/{order_id}/shipment:
    $ref: "paths/deal.yaml#/orderShipment"
  /v1/orders/{order_id}/confirm:
    $ref: "paths/deal.yaml#/orderConfirm"
  /v1/me/orders:
    $ref: "paths/deal.yaml#/myOrders"
  /v1/shipments/lookup:
    $ref: "paths/deal.yaml#/shipmentLookup"
  /v1/dev/shipments/{code}/status:
    $ref: "paths/deal.yaml#/devShipmentStatus"
```

- [ ] **Step 2: The operations**

In `api/paths/deal.yaml`:

`dealCancel`'s summary becomes `Drop the agreed price, and a pending order with it; the deal negotiates again.`

`dealCod`'s description becomes:

```yaml
    description: |
      The buyer of an agreed deal with no open order, on a listing on sale,
      with fewer than 3 open orders, to one of the buyer's addresses. The
      order keeps a copy of the address as its recipient. It starts
      pending; either side may cancel it until the seller creates the
      shipment, and it is cancelled with seller_timeout when the seller has
      created none 3 days later.
```

Replace the blocks `orderShip:`, `orderDeliver:` and `orderReturn:` (everything from the line `orderShip:` to the line before `myOrders:`) with:

```yaml
orderShipment:
  post:
    operationId: createShipment
    summary: Create the shipment of a pending order.
    description: |
      The seller, in one commit. manual: the seller made the shipment on
      the carrier's own app and types its code; the server reads it from
      the carrier. linked: the server makes it on the seller's GHTK
      account. The order is shipped, the listing is reserved for it, and
      other buyers' pending orders on the listing are cancelled with
      shipped_to_another. A parcel the carrier reports delivered ships
      delivered. Checks, in order: the shipment's fields, for a manual one
      the carrier's answer, then the order is the caller's, the order's
      state, the listing, and for a linked one GHTK's answer. A stack
      without a carrier (CARRIER=none, production for now) answers 503
      carrier_unavailable.
    tags: [deal]
    security:
      - bearerAuth: []
    parameters:
      - name: order_id
        in: path
        required: true
        schema:
          type: string
          format: uuid
      - $ref: "../parameters/common.yaml#/IdempotencyKey"
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/deal.yaml#/ShipmentDraft"
    responses:
      "200":
        description: The order's deal.
        content:
          application/json:
            schema:
              $ref: "../schemas/deal.yaml#/Deal"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "No such order of the caller's (order_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "409":
        description: "The order is not the deal's pending one, or the caller is the buyer (move_not_allowed); the listing is not on sale (listing_unavailable); or the deal changed meanwhile (deal_changed)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: "The shipment breaks a rule, the carrier's report of a failed parcel included (invalid_shipment, with fields), or the carrier does not know the tracking code (shipment_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "503":
        description: "The stack has no carrier, CARRIER=none (carrier_unavailable)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
  put:
    operationId: editShipment
    summary: Correct the carrier and tracking code of a manual shipment.
    description: |
      The seller, while the shipment is pending_pickup or in_transit. The
      server reads the new code from the carrier as on creation and takes
      its status. Checks, in order: the carrier and the code, the
      carrier's answer, then the order is the caller's and its state.
    tags: [deal]
    security:
      - bearerAuth: []
    parameters:
      - name: order_id
        in: path
        required: true
        schema:
          type: string
          format: uuid
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/deal.yaml#/TrackingCode"
    responses:
      "200":
        description: The order's deal.
        content:
          application/json:
            schema:
              $ref: "../schemas/deal.yaml#/Deal"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "No such order of the caller's (order_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "409":
        description: "The order is not shipped, its shipment is linked or no longer pending_pickup or in_transit, or the caller is the buyer (move_not_allowed); or the deal changed meanwhile (deal_changed)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: "The carrier or the code breaks a rule, the carrier's report of a failed parcel included (invalid_shipment, with fields), or the carrier does not know the tracking code (shipment_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "503":
        description: "The stack has no carrier, CARRIER=none (carrier_unavailable)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
orderConfirm:
  post:
    operationId: confirmReceipt
    summary: Confirm receipt of a shipped order.
    description: |
      The buyer, at any time while the order is shipped, whatever the
      carrier reports. The order is completed, the deal sold and the
      listing sold.
    tags: [deal]
    security:
      - bearerAuth: []
    parameters:
      - name: order_id
        in: path
        required: true
        schema:
          type: string
          format: uuid
      - $ref: "../parameters/common.yaml#/IdempotencyKey"
    responses:
      "200":
        description: The order's deal.
        content:
          application/json:
            schema:
              $ref: "../schemas/deal.yaml#/Deal"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "No such order of the caller's (order_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "409":
        description: "The order is not the deal's shipped one, or the caller is the seller (move_not_allowed); or the deal changed meanwhile (deal_changed)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
shipmentLookup:
  get:
    operationId: lookupShipment
    summary: Read a shipment from its carrier, for the seller's preview.
    description: |
      Before the seller confirms a manual shipment or a corrected code.
      The app warns, and does not block, when cod_amount differs from the
      agreed price.
    tags: [deal]
    security:
      - bearerAuth: []
    parameters:
      - name: carrier
        in: query
        required: true
        description: ghtk, ghn, spx, jt or viettel_post; another value is 422 invalid_shipment.
        schema:
          type: string
      - name: code
        in: query
        required: true
        description: The tracking code, 1 to 50 characters once trimmed.
        schema:
          type: string
    responses:
      "200":
        description: The shipment as its carrier reads it.
        content:
          application/json:
            schema:
              $ref: "../schemas/deal.yaml#/ShipmentPreview"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "The carrier does not know the tracking code (shipment_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: "The carrier or the code breaks a rule (invalid_shipment, with fields)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "503":
        description: "The stack has no carrier, CARRIER=none (carrier_unavailable)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
devShipmentStatus:
  post:
    operationId: setShipmentStatus
    summary: Set the status of every shipment with a tracking code, as its carrier would.
    description: |
      Served only with CARRIER=fake, which the dev and test stacks run, to
      anyone, since the fake carrier's shipments move only through it.
      Production runs CARRIER=none and does not serve it. It calls the entry point the real
      carriers' reports will use. A closed order changes nothing.
      delivered completes the order 3 days later unless the buyer
      confirms first; failed fails it at once and releases the listing.
    tags: [deal]
    parameters:
      - name: code
        in: path
        required: true
        schema:
          type: string
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/deal.yaml#/ShipmentStatusChange"
    responses:
      "204":
        description: Taken, whether or not an order changed.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "404":
        description: "No order has a shipment with the tracking code (shipment_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: "The status is not pending_pickup, in_transit, delivered or failed (invalid_status)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

- [ ] **Step 3: The schemas**

In `api/schemas/deal.yaml`:

`DealStatus`'s description ends `sold: the deal's order was completed; the deal takes no move.`

`DealSummary.your_turn`'s description becomes:

```yaml
      description: |
        The caller has to act: the deal is negotiating and the open price is
        the other side's; or the caller is the buyer of an agreed deal
        without a pending or shipped order, on a listing still active; or
        the caller is the seller and the deal's newest order is pending.
```

`Move.kind`'s enum becomes `offer, counter, accept, decline, withdraw, cancel, price_changed, offers_closed, listing_closed, cod_requested, shipped, shipment_updated, completed, failed, order_cancelled` (one per line, as now), and `Move.amount`'s description ends `the order's price on cod_requested, the carrier's fee on shipped when it gave one.`

Replace `WaybillDraft:` (the whole block) with:

```yaml
Carrier:
  type: string
  enum: [ghtk, ghn, spx, jt, viettel_post]
  description: The carriers ShopNexus can read; there is no other.
ShipmentDraft:
  description: A manual shipment the seller made on a carrier's own app, or a linked one to make on the seller's GHTK account.
  oneOf:
    - $ref: "#/ManualShipmentDraft"
    - $ref: "#/LinkedShipmentDraft"
ManualShipmentDraft:
  type: object
  additionalProperties: false
  required: [mode, carrier, tracking_code]
  properties:
    mode:
      type: string
      enum: [manual]
    carrier:
      type: string
      description: ghtk, ghn, spx, jt or viettel_post; another value is 422 invalid_shipment.
    tracking_code:
      type: string
      description: 1 to 50 characters once trimmed. A code the carrier does not know is 422 shipment_not_found.
LinkedShipmentDraft:
  type: object
  additionalProperties: false
  required: [mode, service, weight_grams, pickup]
  properties:
    mode:
      type: string
      enum: [linked]
    service:
      type: string
      description: standard or express.
    weight_grams:
      type: integer
      description: The parcel's weight, 1 to 20,000 grams.
    pickup:
      type: string
      description: home (GHTK picks the parcel up from the seller) or post_office (the seller brings it to one).
TrackingCode:
  type: object
  additionalProperties: false
  required: [carrier, tracking_code]
  description: A manual shipment's corrected carrier and code.
  properties:
    carrier:
      type: string
      description: ghtk, ghn, spx, jt or viettel_post; another value is 422 invalid_shipment.
    tracking_code:
      type: string
      description: 1 to 50 characters once trimmed.
ShipmentStatus:
  type: string
  enum: [pending_pickup, in_transit, delivered, failed]
  description: Where the parcel is, as its carrier reports it.
ShipmentPreview:
  type: object
  additionalProperties: false
  required: [carrier, tracking_code, recipient_name, district, cod_amount, status]
  description: A shipment as its carrier reads it, before the seller confirms it.
  properties:
    carrier:
      $ref: "#/Carrier"
    tracking_code:
      type: string
    recipient_name:
      type: string
      description: As the carrier masks it.
    district:
      type: string
    cod_amount:
      type: integer
      format: int64
      description: What the carrier collects at the door, in đồng.
    status:
      $ref: "#/ShipmentStatus"
    fee:
      type: integer
      format: int64
      description: The carrier's fee in đồng; absent while the carrier has none.
ShipmentStatusChange:
  type: object
  additionalProperties: false
  required: [status]
  properties:
    status:
      type: string
      description: pending_pickup, in_transit, delivered or failed; another value is 422 invalid_status.
```

`Recipient.phone`'s and `Recipient.street`'s descriptions end `Absent for the seller on a cancelled order.`

Replace `Waybill:` (the whole block) with:

```yaml
Shipment:
  type: object
  additionalProperties: false
  required: [mode, carrier, tracking_code, status]
  description: The parcel of a shipped order.
  properties:
    mode:
      type: string
      enum: [linked, manual]
      description: linked is made on the seller's GHTK account; manual, on a carrier's own app and typed by the seller.
    carrier:
      $ref: "#/Carrier"
    tracking_code:
      type: string
    fee:
      type: integer
      format: int64
      description: The carrier's fee in đồng; absent while the carrier has none.
    status:
      $ref: "#/ShipmentStatus"
    delivered_at:
      type: string
      format: date-time
      description: When the carrier reported the parcel delivered; present while status is delivered.
CancelReason:
  type: string
  enum: [buyer, seller, seller_timeout, pickup_timeout, shipped_to_another, listing_closed]
  description: |
    buyer and seller: that side cancelled a pending order. seller_timeout:
    the seller created no shipment within 3 days. pickup_timeout: the
    carrier had not picked the parcel up 3 days after the shipment.
    shipped_to_another: the seller shipped the listing to another buyer.
    listing_closed: the listing was hidden, sold off the app or deleted.
```

`OrderStatus` becomes:

```yaml
OrderStatus:
  type: string
  enum: [pending, shipped, completed, failed, cancelled]
  description: |
    pending: the buyer asked for COD; either side may cancel. shipped: the
    seller created the shipment; the listing is reserved. completed: the
    buyer confirmed receipt, or 3 days passed after the carrier reported
    the parcel delivered. failed: the carrier reported the delivery
    failed; the deal negotiates again. cancelled: before the shipment, or
    by the pickup timeout.
```

In both `Order` and `OrderItem`: the property `waybill: {$ref: "#/Waybill"}` becomes

```yaml
    shipment:
      $ref: "#/Shipment"
```

and `cancel_reason` (with its enum and description) becomes

```yaml
    cancel_reason:
      $ref: "#/CancelReason"
```

In `api/schemas/notification.yaml`, `Notification.type`'s enum becomes `[offer, counter, agreed, declined, agreement_cancelled, offer_voided, cod_requested, shipped, completed, failed, order_cancelled, listing_live, listing_rejected, followed_listing, review, suspended, unsuspended, watch_matched, price_dropped]` (wrapped as now).

In `api/paths/trust.yaml:6`: `The order is shipped, completed or failed.` In `api/paths/account.yaml:78`: `An order of the caller is pending or shipped (orders_open)`.

- [ ] **Step 4: Check the spec**

Run: `go test ./api/ && grep -rn "Waybill\|waybill\|orderShip\|orderDeliver\|orderReturn\|requested, shipped\|sent_to_another\|delivered, returned" api/`
Expected: `ok  github.com/shopnexus/server/api`; the grep prints nothing.

- [ ] **Step 5: Commit**

```bash
git add api
git commit -m "feat(deal): the order flow's contract in api/"
```

### Task 2: The carrier provider, its fake and none

**Files:**
- Create: `internal/provider/carrier/carrier.go`, `internal/provider/carrier/fake.go`, `internal/provider/carrier/none.go`
- Test: `internal/provider/carrier/fake_test.go`, `internal/provider/carrier/none_test.go`

**Interfaces:**
- Consumes: nothing.
- Produces: everything under "carrier" in "Task order and interfaces".

The fake reads every known code as the same parcel: recipient `Ng*** V** A`, district `Quận 1, TP. Hồ Chí Minh`, COD 1,500,000 đ (the test listings' price, so a preview in a test does not warn), status `pending_pickup`, fee 22,000 đ. A created code is `GHTK-` and a number taken from the order ID's last four bytes, so a retried `Create` gets the same code.

`None` is production's carrier until part 2: `Create` and `Lookup` return `ErrUnavailable`, and `Cancel` returns nil, since `None` never made a shipment to call off (a pickup timeout or a lost race of a stack that switched from `fake` must not retry forever).

- [ ] **Step 1: Write the failing test**

`internal/provider/carrier/fake_test.go`:

```go
package carrier_test

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"testing"
	"uuid"

	"github.com/shopnexus/server/internal/provider/carrier"
)

func TestFakeReadsEveryCodeButNotFound(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	f := carrier.Fake{}
	p, err := f.Lookup(ctx, "spx", "SPXVN0123")
	if err != nil || p.Status != carrier.StatusPendingPickup || p.Fee == nil || *p.Fee != 22_000 || p.COD != 1_500_000 ||
		p.RecipientName == "" || p.District == "" {
		t.Fatalf("%+v %v", p, err)
	}
	for _, code := range []string{"NOTFOUND", "NOTFOUND-42"} {
		if _, err = f.Lookup(ctx, "ghn", code); !errors.Is(err, carrier.ErrNotFound) {
			t.Errorf("%s: %v", code, err)
		}
	}
	if _, err = f.Lookup(ctx, "ghn", "notfound"); err != nil {
		t.Errorf("a lower-case code is another code: %v", err)
	}
}

func TestFakeMakesOneCodePerOrder(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	f := carrier.Fake{}
	in := carrier.CreateInput{OrderID: uuid.NewV7(), COD: 1_500_000, WeightGrams: 800, Service: "standard", Pickup: "home"}
	a, err := f.Create(ctx, in)
	if err != nil || !strings.HasPrefix(a.TrackingCode, "GHTK-") || a.Fee != 22_000 {
		t.Fatalf("%+v %v", a, err)
	}
	if _, err = strconv.ParseUint(strings.TrimPrefix(a.TrackingCode, "GHTK-"), 10, 64); err != nil {
		t.Fatalf("%s is not GHTK- and a number", a.TrackingCode)
	}
	if b, _ := f.Create(ctx, in); b != a {
		t.Fatalf("a retry made %+v after %+v", b, a)
	}
	in.OrderID = uuid.NewV7()
	if c, _ := f.Create(ctx, in); c.TrackingCode == a.TrackingCode {
		t.Fatalf("two orders got %s", a.TrackingCode)
	}
	if err = f.Cancel(ctx, "ghtk", a.TrackingCode); err != nil {
		t.Fatal(err)
	}
}
```

`internal/provider/carrier/none_test.go`:

```go
package carrier_test

import (
	"context"
	"errors"
	"testing"
	"uuid"

	"github.com/shopnexus/server/internal/provider/carrier"
)

func TestNoneMakesAndReadsNothing(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	n := carrier.None{}
	if _, err := n.Create(ctx, carrier.CreateInput{OrderID: uuid.NewV7()}); !errors.Is(err, carrier.ErrUnavailable) {
		t.Errorf("create: %v", err)
	}
	if _, err := n.Lookup(ctx, "spx", "SPX1"); !errors.Is(err, carrier.ErrUnavailable) {
		t.Errorf("lookup: %v", err)
	}
	if err := n.Cancel(ctx, "ghtk", "GHTK-1"); err != nil {
		t.Errorf("cancel: %v", err)
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/provider/carrier/`
Expected: FAIL, `no non-test Go files` or `undefined: carrier.Fake` and `undefined: carrier.None`.

- [ ] **Step 3: Write the client's types**

`internal/provider/carrier/carrier.go`:

```go
// Package carrier makes and reads shipments at the carriers ShopNexus can
// read: GHTK, GHN, SPX, J&T and Viettel Post. Fake stands in for all of
// them until the real clients come.
package carrier

import (
	"context"
	"errors"
	"uuid"
)

// Carrier is a carrier's code: ghtk, ghn, spx, jt or viettel_post.
type Carrier string

// Status is where a parcel is, in ShopNexus's words.
type Status string

const (
	StatusPendingPickup Status = "pending_pickup"
	StatusInTransit     Status = "in_transit"
	StatusDelivered     Status = "delivered"
	StatusFailed        Status = "failed"
)

var (
	// ErrNotFound is a tracking code the carrier does not know.
	ErrNotFound = errors.New("carrier: no such shipment")
	// ErrUnavailable is a stack without a carrier, CARRIER=none: nothing
	// makes or reads shipments there.
	ErrUnavailable = errors.New("carrier: no carrier in this stack")
)

// Recipient is where a parcel goes. Phone is in the +84 form.
type Recipient struct {
	Name        string
	Phone       string
	Street      string
	CommuneCode string
}

// CreateInput is a shipment to make on the seller's linked GHTK account.
// OrderID is the order's ID, so a retried Create makes no second shipment.
type CreateInput struct {
	OrderID   uuid.UUID
	Recipient Recipient
	// COD is what the carrier collects at the door, in đồng.
	COD         int64
	WeightGrams int
	Service     string // standard or express
	Pickup      string // home or post_office
}

// Created is a new shipment's tracking code and fee, in đồng.
type Created struct {
	TrackingCode string `json:"tracking_code"`
	Fee          int64  `json:"fee"`
}

// Parcel is what a carrier tells of a shipment: the recipient's name as it
// masks it, the district, the COD amount, the status, and the fee, nil
// while it has none.
type Parcel struct {
	RecipientName string
	District      string
	COD           int64
	Status        Status
	Fee           *int64
}

// Client makes, reads and calls off shipments.
type Client interface {
	// Create makes a shipment on the seller's linked account: its tracking
	// code and fee.
	Create(ctx context.Context, in CreateInput) (Created, error)
	// Lookup reads a shipment by carrier and code; ErrNotFound when the
	// carrier does not know it.
	Lookup(ctx context.Context, c Carrier, code string) (Parcel, error)
	// Cancel calls off a shipment the carrier has not picked up; a second
	// call changes nothing.
	Cancel(ctx context.Context, c Carrier, code string) error
}
```

- [ ] **Step 4: Write the fake and none**

`internal/provider/carrier/fake.go`:

```go
package carrier

import (
	"context"
	"encoding/binary"
	"strconv"
	"strings"
)

// fakeFee is what the fake charges for any parcel, in đồng.
const fakeFee = 22_000

// Fake knows every tracking code but those that start with NOTFOUND, and
// reads each as the same parcel waiting for pickup. It makes GHTK-<number>
// codes and calls nothing off. With CARRIER=fake the dev endpoint moves
// its shipments.
type Fake struct{}

var _ Client = Fake{}

// Create makes the code from the order ID's last four bytes, which are
// random, so a retry gets the same code and two orders almost never share
// one.
func (Fake) Create(_ context.Context, in CreateInput) (Created, error) {
	n := binary.BigEndian.Uint32(in.OrderID[12:16])
	return Created{TrackingCode: "GHTK-" + strconv.FormatUint(uint64(n), 10), Fee: fakeFee}, nil
}

func (Fake) Lookup(_ context.Context, _ Carrier, code string) (Parcel, error) {
	if strings.HasPrefix(code, "NOTFOUND") {
		return Parcel{}, ErrNotFound
	}
	return Parcel{
		RecipientName: "Ng*** V** A", District: "Quận 1, TP. Hồ Chí Minh", COD: 1_500_000,
		Status: StatusPendingPickup, Fee: new(int64(fakeFee)),
	}, nil
}

func (Fake) Cancel(context.Context, Carrier, string) error { return nil }
```

`internal/provider/carrier/none.go`:

```go
package carrier

import "context"

// None is the carrier of a stack without one, CARRIER=none: production
// until a real carrier's client comes. It makes and reads nothing, and it
// calls nothing off, since it never made a shipment.
type None struct{}

var _ Client = None{}

func (None) Create(context.Context, CreateInput) (Created, error) { return Created{}, ErrUnavailable }

func (None) Lookup(context.Context, Carrier, string) (Parcel, error) { return Parcel{}, ErrUnavailable }

func (None) Cancel(context.Context, Carrier, string) error { return nil }
```

- [ ] **Step 5: Run the tests and the linter**

Run: `go test ./internal/provider/carrier/ && golangci-lint run ./internal/provider/carrier/`
Expected: `ok`, then `0 issues.`

- [ ] **Step 6: Commit**

```bash
git add internal/provider/carrier
git commit -m "feat(carrier): a carrier client, its fake and none"
```

### Task 3: The order and its shipment in the domain

**Files:**
- Modify: `internal/deal/domain/order.go` (rewritten whole), `internal/deal/domain/deal.go`, `internal/deal/domain/errors.go`, `internal/deal/domain/erasure.go`
- Test: `internal/deal/domain/order_test.go` (rewritten whole), `internal/deal/domain/turn_test.go`, `internal/deal/domain/erasure_test.go`

**Interfaces:**
- Consumes: nothing new.
- Produces: everything under "domain" in "Task order and interfaces".

- [ ] **Step 1: Write the failing domain tests**

Replace `internal/deal/domain/order_test.go` with:

```go
package domain_test

import (
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/platform/apperr"
)

var (
	reserved = domain.Listing{Price: 1_500_000, AllowOffers: true, Status: domain.ListingReserved, ReservedFor: uuid.NewV7()}
	hidden   = domain.Listing{Price: 1_500_000, AllowOffers: true, Status: domain.ListingHidden}
	paused   = domain.Listing{Price: 1_500_000, AllowOffers: true, Status: domain.ListingPaused}
	gone     = domain.Listing{Price: 1_500_000, AllowOffers: true, Status: domain.ListingGone}
)

var recipient = domain.Recipient{Name: "Hân", Phone: "+84912345678", Street: "12 Lý Thường Kiệt", CommuneCode: "00004"}

// later is a moment after now, for moves that must not take now's time.
var later = now.Add(time.Hour)

// manual is a manual shipment as its carrier reads it: waiting for pickup,
// with a fee.
func manual() domain.Shipment {
	return domain.Shipment{
		Mode: domain.ModeManual, Carrier: domain.CarrierSPX, TrackingCode: "SPXVN0123456789",
		Fee: new(int64(22_000)), Status: domain.ShipmentPendingPickup,
	}
}

// agreed is a deal agreed at the listed price.
func agreed(t *testing.T) domain.Deal {
	t.Helper()
	d := newDeal()
	must(t, d.Accept(domain.Buyer, 1_500_000, onSale, now))
	return d
}

// pending is an agreed deal whose buyer asked for COD.
func pending(t *testing.T) domain.Deal {
	t.Helper()
	d := agreed(t)
	must(t, d.RequestCod(domain.Buyer, recipient, onSale, now))
	return d
}

// shipped is a pending deal the seller shipped manually.
func shipped(t *testing.T) domain.Deal {
	t.Helper()
	d := pending(t)
	must(t, d.Ship(domain.Seller, d.Order().ID, manual(), onSale, now))
	return d
}

// reported is a shipped deal whose carrier reported status.
func reported(t *testing.T, status domain.ShipmentStatus) domain.Deal {
	t.Helper()
	d := shipped(t)
	if _, err := d.ShipmentUpdated(d.Order().ID, status, now); err != nil {
		t.Fatal(err)
	}
	return d
}

// field returns the problem err reports for name.
func field(err error, name string) string {
	if e, ok := errors.AsType[*apperr.Error](err); ok {
		return e.Fields[name]
	}
	return ""
}

// last is the newest pending move.
func last(d *domain.Deal) domain.Move {
	p := d.Pending()
	return p[len(p)-1]
}

func TestTracking(t *testing.T) {
	t.Parallel()
	for _, c := range []domain.Carrier{domain.CarrierGHTK, domain.CarrierGHN, domain.CarrierSPX, domain.CarrierJT, domain.CarrierViettelPost} {
		got, code, err := domain.Tracking(string(c), "  X1 ")
		if err != nil || got != c || code != "X1" {
			t.Errorf("%s: %s %q %v", c, got, code, err)
		}
	}
	if _, code, err := domain.Tracking("ghn", strings.Repeat("ạ", 50)); err != nil || code == "" {
		t.Errorf("50 characters: %v", err)
	}
	for _, c := range []struct{ carrier, code, field string }{
		{"other", "X1", "carrier"},
		{"pigeon", "X1", "carrier"},
		{"ghn", "", "tracking_code"},
		{"ghn", "   ", "tracking_code"},
		{"ghn", strings.Repeat("x", 51), "tracking_code"},
	} {
		if _, _, err := domain.Tracking(c.carrier, c.code); !errors.Is(err, domain.ErrInvalidShipment) || field(err, c.field) == "" {
			t.Errorf("%+v: %v", c, err)
		}
	}
}

func TestNewLinkedDraft(t *testing.T) {
	t.Parallel()
	for _, c := range []struct {
		service string
		weight  int
		pickup  string
	}{{"standard", 800, "home"}, {"express", 20_000, "post_office"}, {"standard", 1, "home"}} {
		got, err := domain.NewLinkedDraft(c.service, c.weight, c.pickup)
		if err != nil || string(got.Service) != c.service || got.WeightGrams != c.weight || string(got.Pickup) != c.pickup {
			t.Errorf("%+v: %+v %v", c, got, err)
		}
	}
	for _, c := range []struct {
		service string
		weight  int
		pickup  string
		field   string
	}{
		{"road", 800, "home", "service"},
		{"standard", 0, "home", "weight_grams"},
		{"standard", 20_001, "home", "weight_grams"},
		{"standard", 800, "door", "pickup"},
	} {
		if _, err := domain.NewLinkedDraft(c.service, c.weight, c.pickup); !errors.Is(err, domain.ErrInvalidShipment) || field(err, c.field) == "" {
			t.Errorf("%+v: %v", c, err)
		}
	}
}

func TestParseShipmentStatus(t *testing.T) {
	t.Parallel()
	for _, s := range []string{"pending_pickup", "in_transit", "delivered", "failed"} {
		if got, err := domain.ParseShipmentStatus(s); err != nil || string(got) != s {
			t.Errorf("%s: %v", s, err)
		}
	}
	for _, s := range []string{"returned", "", "Delivered"} {
		if _, err := domain.ParseShipmentStatus(s); !errors.Is(err, domain.ErrInvalidStatus) {
			t.Errorf("%q: %v", s, err)
		}
	}
}

func TestOrderLifecycle(t *testing.T) {
	t.Parallel()
	d := agreed(t)
	if err := d.RequestCod(domain.Seller, recipient, onSale, now); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("seller requests: %v", err)
	}
	must(t, d.RequestCod(domain.Buyer, recipient, onSale, now))
	o := d.Order()
	if o == nil || o.Status != domain.OrderPending || o.Price != 1_500_000 || !o.Open() || o.Shipment != nil {
		t.Fatalf("%+v", o)
	}
	if err := d.RequestCod(domain.Buyer, recipient, onSale, now); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("second request: %v", err)
	}
	if err := d.Ship(domain.Buyer, o.ID, manual(), onSale, now); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("buyer ships: %v", err)
	}
	if err := d.Ship(domain.Seller, o.ID, manual(), reserved, now); !errors.Is(err, domain.ErrListingUnavailable) {
		t.Fatalf("ship a reserved listing: %v", err)
	}
	failed := manual()
	failed.Status = domain.ShipmentFailed
	if err := d.Ship(domain.Seller, o.ID, failed, onSale, now); !errors.Is(err, domain.ErrInvalidShipment) || field(err, "tracking_code") == "" {
		t.Fatalf("ship a failed parcel: %v", err)
	}
	if err := d.ConfirmReceipt(domain.Buyer, o.ID, now); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("confirm a pending order: %v", err)
	}
	must(t, d.Ship(domain.Seller, o.ID, manual(), onSale, now))
	if o = d.Order(); o.Status != domain.OrderShipped || o.Shipment == nil || o.Shipment.TrackingCode != "SPXVN0123456789" ||
		o.Shipment.DeliveredAt != nil || o.ShippedAt == nil {
		t.Fatalf("%+v", o)
	}
	if m := last(&d); m.Kind != domain.MoveShipped || m.By != domain.Seller || m.Amount != 22_000 {
		t.Fatalf("%+v", m)
	}
	for _, by := range []domain.Party{domain.Buyer, domain.Seller} {
		if err := d.Cancel(by, now); !errors.Is(err, domain.ErrMoveNotAllowed) {
			t.Fatalf("%s cancels a shipped order: %v", by, err)
		}
	}
	if err := d.ConfirmReceipt(domain.Seller, o.ID, now); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("seller confirms: %v", err)
	}
	must(t, d.ConfirmReceipt(domain.Buyer, o.ID, later))
	if o = d.Order(); o.Status != domain.OrderCompleted || o.ClosedAt == nil || !o.ClosedAt.Equal(later) ||
		d.Status() != domain.StatusSold || o.Open() {
		t.Fatalf("%+v %s", o, d.Status())
	}
	if m := last(&d); m.Kind != domain.MoveCompleted || m.By != domain.Buyer {
		t.Fatalf("%+v", m)
	}
	for name, move := range map[string]func() error{
		"offer":   func() error { return d.Offer(domain.Buyer, 1_000_000, onSale, now) },
		"accept":  func() error { return d.Accept(domain.Buyer, 1_500_000, onSale, now) },
		"cancel":  func() error { return d.Cancel(domain.Buyer, now) },
		"request": func() error { return d.RequestCod(domain.Buyer, recipient, onSale, now) },
		"confirm": func() error { return d.ConfirmReceipt(domain.Buyer, o.ID, now) },
	} {
		if err := move(); !errors.Is(err, domain.ErrMoveNotAllowed) {
			t.Errorf("%s after completion: %v", name, err)
		}
	}
}

func TestShipTakesTheCarriersWord(t *testing.T) {
	t.Parallel()
	d := pending(t)
	s := manual()
	s.Fee = nil
	must(t, d.Ship(domain.Seller, d.Order().ID, s, onSale, now))
	if d.Order().Shipment.Fee != nil || last(&d).Amount != 0 {
		t.Fatalf("a shipment without a fee: %+v %+v", d.Order().Shipment, last(&d))
	}
	d = pending(t)
	s = manual()
	s.Status, s.DeliveredAt = domain.ShipmentDelivered, &later
	must(t, d.Ship(domain.Seller, d.Order().ID, s, onSale, now))
	if sh := d.Order().Shipment; sh.Status != domain.ShipmentDelivered || sh.DeliveredAt == nil || !sh.DeliveredAt.Equal(now) {
		t.Fatalf("a delivered parcel: %+v", sh)
	}
}

func TestShippable(t *testing.T) {
	t.Parallel()
	d := pending(t)
	id := d.Order().ID
	if err := d.Shippable(domain.Seller, id, onSale); err != nil {
		t.Fatalf("the seller: %v", err)
	}
	for name, c := range map[string]struct {
		by    domain.Party
		order uuid.UUID
		l     domain.Listing
		want  error
	}{
		"the buyer":       {domain.Buyer, id, onSale, domain.ErrMoveNotAllowed},
		"another order":   {domain.Seller, uuid.NewV7(), onSale, domain.ErrMoveNotAllowed},
		"a reserved one":  {domain.Seller, id, reserved, domain.ErrListingUnavailable},
		"a hidden one":    {domain.Seller, id, hidden, domain.ErrListingUnavailable},
		"a paused one":    {domain.Seller, id, paused, domain.ErrListingUnavailable},
		"a listing gone":  {domain.Seller, id, gone, domain.ErrListingUnavailable},
	} {
		if err := d.Shippable(c.by, c.order, c.l); !errors.Is(err, c.want) {
			t.Errorf("%s: %v", name, err)
		}
	}
	s := shipped(t)
	if err := s.Shippable(domain.Seller, s.Order().ID, onSale); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("a shipped order: %v", err)
	}
}

func TestEditShipment(t *testing.T) {
	t.Parallel()
	edited := domain.Shipment{
		Mode: domain.ModeLinked, Carrier: domain.CarrierGHN, TrackingCode: "GHN0042",
		Fee: new(int64(30_000)), Status: domain.ShipmentInTransit,
	}
	for _, status := range []domain.ShipmentStatus{domain.ShipmentPendingPickup, domain.ShipmentInTransit} {
		d := shipped(t)
		if status != domain.ShipmentPendingPickup {
			d = reported(t, status)
		}
		must(t, d.EditShipment(domain.Seller, d.Order().ID, edited, later))
		sh := d.Order().Shipment
		if sh.Mode != domain.ModeManual || sh.Carrier != domain.CarrierGHN || sh.TrackingCode != "GHN0042" ||
			*sh.Fee != 30_000 || sh.Status != domain.ShipmentInTransit || sh.DeliveredAt != nil {
			t.Errorf("from %s: %+v", status, sh)
		}
		if m := last(&d); m.Kind != domain.MoveShipmentUpdated || m.By != domain.Seller {
			t.Errorf("from %s: %+v", status, m)
		}
	}
	d := shipped(t)
	delivered := edited
	delivered.Status = domain.ShipmentDelivered
	must(t, d.EditShipment(domain.Seller, d.Order().ID, delivered, later))
	if sh := d.Order().Shipment; sh.DeliveredAt == nil || !sh.DeliveredAt.Equal(later) {
		t.Fatalf("edited to a delivered parcel: %+v", sh)
	}
	d = shipped(t)
	failed := edited
	failed.Status = domain.ShipmentFailed
	if err := d.EditShipment(domain.Seller, d.Order().ID, failed, later); !errors.Is(err, domain.ErrInvalidShipment) ||
		d.Order().Shipment.TrackingCode != "SPXVN0123456789" {
		t.Fatalf("edited to a failed parcel: %v %+v", err, d.Order().Shipment)
	}
	linked := pending(t)
	l := manual()
	l.Mode, l.Carrier = domain.ModeLinked, domain.CarrierGHTK
	must(t, linked.Ship(domain.Seller, linked.Order().ID, l, onSale, now))
	for name, c := range map[string]struct {
		d     domain.Deal
		by    domain.Party
		order func(domain.Deal) uuid.UUID
	}{
		"the buyer":         {shipped(t), domain.Buyer, func(d domain.Deal) uuid.UUID { return d.Order().ID }},
		"another order":     {shipped(t), domain.Seller, func(domain.Deal) uuid.UUID { return uuid.NewV7() }},
		"a linked shipment": {linked, domain.Seller, func(d domain.Deal) uuid.UUID { return d.Order().ID }},
		"a delivered one":   {reported(t, domain.ShipmentDelivered), domain.Seller, func(d domain.Deal) uuid.UUID { return d.Order().ID }},
		"a pending order":   {pending(t), domain.Seller, func(d domain.Deal) uuid.UUID { return d.Order().ID }},
	} {
		if err := c.d.EditShipment(c.by, c.order(c.d), edited, later); !errors.Is(err, domain.ErrMoveNotAllowed) {
			t.Errorf("%s: %v", name, err)
		}
	}
}

func TestConfirmReceiptWhateverTheCarrierSays(t *testing.T) {
	t.Parallel()
	for _, status := range []domain.ShipmentStatus{domain.ShipmentPendingPickup, domain.ShipmentInTransit, domain.ShipmentDelivered} {
		d := shipped(t)
		if status != domain.ShipmentPendingPickup {
			d = reported(t, status)
		}
		if err := d.ConfirmReceipt(domain.Buyer, d.Order().ID, later); err != nil || d.Order().Status != domain.OrderCompleted {
			t.Errorf("%s: %v %+v", status, err, d.Order())
		}
	}
}

func TestShipmentUpdated(t *testing.T) {
	t.Parallel()
	d := shipped(t)
	id := d.Order().ID
	changed, err := d.ShipmentUpdated(id, domain.ShipmentInTransit, now)
	if err != nil || !changed || d.Order().Shipment.Status != domain.ShipmentInTransit {
		t.Fatalf("in transit: %v %v %+v", changed, err, d.Order().Shipment)
	}
	if m := last(&d); m.Kind != domain.MoveShipmentUpdated || m.By != domain.System {
		t.Fatalf("%+v", m)
	}
	moves := len(d.Pending())
	if changed, err = d.ShipmentUpdated(id, domain.ShipmentInTransit, later); err != nil || changed || len(d.Pending()) != moves {
		t.Fatalf("the same status again: %v %v", changed, err)
	}
	must(t, func() error { _, e := d.ShipmentUpdated(id, domain.ShipmentDelivered, later); return e }())
	if sh := d.Order().Shipment; sh.DeliveredAt == nil || !sh.DeliveredAt.Equal(later) || d.Order().Status != domain.OrderShipped {
		t.Fatalf("delivered: %+v %+v", sh, d.Order())
	}
	must(t, func() error { _, e := d.ShipmentUpdated(id, domain.ShipmentInTransit, later); return e }())
	if d.Order().Shipment.DeliveredAt != nil {
		t.Fatal("a parcel back in transit kept its delivery time")
	}
	must(t, func() error { _, e := d.ShipmentUpdated(id, domain.ShipmentFailed, later); return e }())
	o := d.Order()
	if o.Status != domain.OrderFailed || o.ClosedAt == nil || o.Shipment.Status != domain.ShipmentFailed ||
		d.Status() != domain.StatusNegotiating || d.AgreedPrice() != 0 || d.AgreedAt() != nil {
		t.Fatalf("failed: %+v %+v", o, d.State())
	}
	if m := last(&d); m.Kind != domain.MoveFailed || m.By != domain.System {
		t.Fatalf("%+v", m)
	}
	if _, err = d.ShipmentUpdated(id, domain.ShipmentDelivered, later); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("a report for a closed order: %v", err)
	}
	p := pending(t)
	if _, err = p.ShipmentUpdated(p.Order().ID, domain.ShipmentInTransit, now); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("a pending order: %v", err)
	}
	s := shipped(t)
	if _, err = s.ShipmentUpdated(uuid.NewV7(), domain.ShipmentInTransit, now); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("another order: %v", err)
	}
}

func TestSellerTimeout(t *testing.T) {
	t.Parallel()
	d := pending(t)
	must(t, d.SellerTimeout(d.Order().ID, later))
	o := d.Order()
	if o.Status != domain.OrderCancelled || o.CancelledBy != domain.System || o.CancelReason != domain.CancelSellerTimeout ||
		d.Status() != domain.StatusNegotiating || last(&d).Kind != domain.MoveOrderCancelled {
		t.Fatalf("%+v %s", o, d.Status())
	}
	cancelled := pending(t)
	must(t, cancelled.Cancel(domain.Buyer, now))
	other := pending(t)
	for name, c := range map[string]struct {
		d     domain.Deal
		order uuid.UUID
	}{
		"a shipped order":   {shipped(t), uuid.UUID{}},
		"a cancelled order": {cancelled, cancelled.Order().ID},
		"another order":     {other, uuid.NewV7()},
	} {
		if c.order == (uuid.UUID{}) {
			c.order = c.d.Order().ID
		}
		if err := c.d.SellerTimeout(c.order, later); !errors.Is(err, domain.ErrMoveNotAllowed) {
			t.Errorf("%s: %v", name, err)
		}
	}
}

func TestPickupTimeout(t *testing.T) {
	t.Parallel()
	d := shipped(t)
	must(t, d.PickupTimeout(d.Order().ID, later))
	o := d.Order()
	if o.Status != domain.OrderCancelled || o.CancelledBy != domain.System || o.CancelReason != domain.CancelPickupTimeout ||
		o.ClosedAt == nil || o.Shipment == nil || d.Status() != domain.StatusNegotiating || d.AgreedPrice() != 0 {
		t.Fatalf("%+v %s", o, d.Status())
	}
	completed := shipped(t)
	must(t, completed.ConfirmReceipt(domain.Buyer, completed.Order().ID, now))
	for name, d := range map[string]domain.Deal{
		"in transit":  reported(t, domain.ShipmentInTransit),
		"delivered":   reported(t, domain.ShipmentDelivered),
		"pending":     pending(t),
		"completed":   completed,
	} {
		if err := d.PickupTimeout(d.Order().ID, later); !errors.Is(err, domain.ErrMoveNotAllowed) {
			t.Errorf("%s: %v", name, err)
		}
	}
}

func TestAutoComplete(t *testing.T) {
	t.Parallel()
	d := reported(t, domain.ShipmentDelivered)
	must(t, d.AutoComplete(d.Order().ID, later))
	if o := d.Order(); o.Status != domain.OrderCompleted || d.Status() != domain.StatusSold || last(&d).By != domain.System ||
		last(&d).Kind != domain.MoveCompleted {
		t.Fatalf("%+v %s", o, d.Status())
	}
	confirmed := reported(t, domain.ShipmentDelivered)
	must(t, confirmed.ConfirmReceipt(domain.Buyer, confirmed.Order().ID, now))
	for name, d := range map[string]domain.Deal{
		"waiting for pickup": shipped(t),
		"in transit":         reported(t, domain.ShipmentInTransit),
		"confirmed":          confirmed,
	} {
		if err := d.AutoComplete(d.Order().ID, later); !errors.Is(err, domain.ErrMoveNotAllowed) {
			t.Errorf("%s: %v", name, err)
		}
	}
}

func TestFailedNegotiatesAgain(t *testing.T) {
	t.Parallel()
	d := reported(t, domain.ShipmentFailed)
	first := d.Order().ID
	must(t, d.Accept(domain.Buyer, 1_500_000, onSale, now))
	must(t, d.RequestCod(domain.Buyer, recipient, onSale, now))
	if d.Order().ID == first || d.Order().Status != domain.OrderPending {
		t.Fatalf("%+v", d.Order())
	}
	if err := d.Ship(domain.Seller, first, manual(), onSale, now); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("ship the failed order: %v", err)
	}
	must(t, d.Ship(domain.Seller, d.Order().ID, manual(), onSale, now))
	if _, err := d.ShipmentUpdated(first, domain.ShipmentDelivered, now); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("a report for the failed order: %v", err)
	}
	if err := d.ConfirmReceipt(domain.Buyer, first, now); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("confirm the failed order: %v", err)
	}
	if d.Order().Status != domain.OrderShipped || d.Order().Shipment.Status != domain.ShipmentPendingPickup {
		t.Fatalf("the second order moved: %+v", d.Order())
	}
}

func TestCancelAPendingOrder(t *testing.T) {
	t.Parallel()
	for _, c := range []struct {
		by     domain.Party
		reason domain.CancelReason
	}{{domain.Buyer, domain.CancelByBuyer}, {domain.Seller, domain.CancelBySeller}} {
		d := pending(t)
		must(t, d.Cancel(c.by, now))
		o := d.Order()
		if o.Status != domain.OrderCancelled || o.CancelledBy != c.by || o.CancelReason != c.reason ||
			d.Status() != domain.StatusNegotiating || last(&d).Kind != domain.MoveOrderCancelled {
			t.Errorf("%s: %+v %s %v", c.by, o, d.Status(), kinds(&d))
		}
	}
	d := agreed(t)
	must(t, d.Cancel(domain.Buyer, now))
	if k := kinds(&d); k[len(k)-1] != domain.MoveCancel {
		t.Fatalf("%v", k)
	}
}

func TestRequestNeedsAnActiveListing(t *testing.T) {
	t.Parallel()
	for name, l := range map[string]domain.Listing{"reserved": reserved, "hidden": hidden, "paused": paused} {
		d := agreed(t)
		if err := d.RequestCod(domain.Buyer, recipient, l, now); !errors.Is(err, domain.ErrListingUnavailable) {
			t.Errorf("%s: %v", name, err)
		}
	}
}

func TestListingChangedCancelsPendingOrders(t *testing.T) {
	t.Parallel()
	d := pending(t)
	own := domain.Listing{Price: 1_500_000, AllowOffers: true, Status: domain.ListingReserved, ReservedFor: d.Order().ID}
	if d.ListingChanged(own, now) {
		t.Fatal("a listing reserved for this order cancelled it")
	}
	cheaper := domain.Listing{Price: 1_400_000, AllowOffers: true, Status: domain.ListingActive}
	if d.ListingChanged(cheaper, now) || d.Order().Status != domain.OrderPending {
		t.Fatal("a price change cancelled the order")
	}
	for _, c := range []struct {
		l      domain.Listing
		reason domain.CancelReason
	}{{reserved, domain.CancelShippedToAnother}, {hidden, domain.CancelListingClosed}, {gone, domain.CancelListingClosed}} {
		d := pending(t)
		if !d.ListingChanged(c.l, now) {
			t.Fatalf("%s: unchanged", c.l.Status)
		}
		if o := d.Order(); o.Status != domain.OrderCancelled || o.CancelledBy != domain.System || o.CancelReason != c.reason ||
			d.Status() != domain.StatusNegotiating {
			t.Errorf("%s: %+v %s", c.l.Status, o, d.Status())
		}
	}
	s := shipped(t)
	for _, l := range []domain.Listing{reserved, hidden, gone, onSale} {
		if s.ListingChanged(l, now) {
			t.Errorf("a shipped order changed on %s", l.Status)
		}
	}
}

func TestRecipientFor(t *testing.T) {
	t.Parallel()
	d := pending(t)
	must(t, d.Cancel(domain.Buyer, now))
	o := d.Order()
	if r := o.RecipientFor(domain.Seller); r.Phone != "" || r.Street != "" || r.Name != "Hân" || r.CommuneCode != "00004" {
		t.Fatalf("seller reads a cancelled order: %+v", r)
	}
	if r := o.RecipientFor(domain.Buyer); r.Phone == "" || r.Street == "" {
		t.Fatalf("buyer: %+v", r)
	}
	s := shipped(t)
	if r := s.Order().RecipientFor(domain.Seller); r.Phone == "" || r.Street == "" {
		t.Fatalf("seller reads a shipped order: %+v", r)
	}
}

func TestReservedListingTakesNoPrice(t *testing.T) {
	t.Parallel()
	d := newDeal()
	must(t, d.Offer(domain.Buyer, 1_000_000, onSale, now))
	if err := d.Offer(domain.Seller, 1_200_000, reserved, now); !errors.Is(err, domain.ErrListingUnavailable) {
		t.Fatalf("counter: %v", err)
	}
	if err := d.Accept(domain.Seller, 1_000_000, reserved, now); !errors.Is(err, domain.ErrListingUnavailable) {
		t.Fatalf("accept: %v", err)
	}
	if d.ListingChanged(reserved, now) || d.OpenFor(reserved) == nil {
		t.Fatal("a reservation dropped the open price")
	}
}

// A flow journals a deal as JSON and the next step reads it back whole.
func TestShippedDealRoundTripsThroughJSON(t *testing.T) {
	t.Parallel()
	d := reported(t, domain.ShipmentDelivered)
	b, err := json.Marshal(d.State())
	if err != nil {
		t.Fatal(err)
	}
	var st domain.DealState
	if err = json.Unmarshal(b, &st); err != nil {
		t.Fatal(err)
	}
	back := domain.RestoreDeal(st)
	sh := back.Order().Shipment
	if sh == nil || sh.Mode != domain.ModeManual || *sh.Fee != 22_000 || sh.DeliveredAt == nil || !sh.DeliveredAt.Equal(now) {
		t.Fatalf("%s", b)
	}
}
```

In `internal/deal/domain/turn_test.go`, the cases from `"a requested order"` to the end of the list become:

```go
		{"a pending order", pending, onSale, false, true, true},
		{"a shipped order", shipped, reserved, false, false, true},
		{"a cancelled order", func(t *testing.T) domain.Deal {
			t.Helper()
			d := pending(t)
			must(t, d.Cancel(domain.Buyer, now))
			return d
		}, onSale, false, false, true},
		{"agreed again after a failed delivery", func(t *testing.T) domain.Deal {
			t.Helper()
			d := reported(t, domain.ShipmentFailed)
			must(t, d.Accept(domain.Buyer, 1_500_000, onSale, now))
			return d
		}, onSale, true, false, true},
		{"sold", func(t *testing.T) domain.Deal {
			t.Helper()
			d := shipped(t)
			must(t, d.ConfirmReceipt(domain.Buyer, d.Order().ID, now))
			return d
		}, gone, false, false, false},
```

In `internal/deal/domain/erasure_test.go`: `req := requested(t)` becomes `req := pending(t)` and the message `"requested: %+v"` becomes `"pending: %+v"`.

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/deal/domain/`
Expected: FAIL to build: `undefined: domain.ModeManual`, `undefined: domain.Tracking` and the other new names.

- [ ] **Step 3: Write the order**

Replace `internal/deal/domain/order.go` with:

```go
package domain

import (
	"slices"
	"strings"
	"time"
	"unicode/utf8"
	"uuid"
)

const (
	// MaxOpenOrders is how many orders a buyer may have pending or shipped
	// at once.
	MaxOpenOrders = 3
	// MaxWeight is the heaviest parcel a linked shipment takes, in grams.
	MaxWeight       = 20_000
	maxTrackingCode = 50
)

type OrderStatus string

const (
	OrderPending   OrderStatus = "pending"
	OrderShipped   OrderStatus = "shipped"
	OrderCompleted OrderStatus = "completed"
	OrderFailed    OrderStatus = "failed"
	OrderCancelled OrderStatus = "cancelled"
)

// CancelReason is why an order was cancelled.
type CancelReason string

const (
	CancelByBuyer  CancelReason = "buyer"
	CancelBySeller CancelReason = "seller"
	// CancelSellerTimeout is a pending order whose seller made no shipment
	// within Waits.Seller.
	CancelSellerTimeout CancelReason = "seller_timeout"
	// CancelPickupTimeout is a shipped order whose parcel the carrier had
	// not picked up Waits.Pickup after the shipment.
	CancelPickupTimeout CancelReason = "pickup_timeout"
	// CancelShippedToAnother is a pending order whose listing the seller
	// shipped to another buyer.
	CancelShippedToAnother CancelReason = "shipped_to_another"
	// CancelListingClosed is a pending order whose listing was hidden, sold
	// off the app or deleted.
	CancelListingClosed CancelReason = "listing_closed"
)

// Carrier is a carrier ShopNexus reads shipments from.
type Carrier string

const (
	CarrierGHTK        Carrier = "ghtk"
	CarrierGHN         Carrier = "ghn"
	CarrierSPX         Carrier = "spx"
	CarrierJT          Carrier = "jt"
	CarrierViettelPost Carrier = "viettel_post"
)

var carriers = []Carrier{CarrierGHTK, CarrierGHN, CarrierSPX, CarrierJT, CarrierViettelPost}

// ShipmentMode says who made the shipment: the server on the seller's
// linked GHTK account, or the seller on a carrier's own app.
type ShipmentMode string

const (
	ModeLinked ShipmentMode = "linked"
	ModeManual ShipmentMode = "manual"
)

// ShipmentStatus is where the parcel is, as its carrier reports it.
type ShipmentStatus string

const (
	ShipmentPendingPickup ShipmentStatus = "pending_pickup"
	ShipmentInTransit     ShipmentStatus = "in_transit"
	ShipmentDelivered     ShipmentStatus = "delivered"
	ShipmentFailed        ShipmentStatus = "failed"
)

// Shipment is the parcel of a shipped order. Fee is the carrier's, nil
// while it has none; DeliveredAt is set while the status is delivered.
type Shipment struct {
	Mode         ShipmentMode   `json:"mode"`
	Carrier      Carrier        `json:"carrier"`
	TrackingCode string         `json:"tracking_code"`
	Fee          *int64         `json:"fee,omitempty"`
	Status       ShipmentStatus `json:"status"`
	DeliveredAt  *time.Time     `json:"delivered_at,omitempty"`
}

// LinkedService is the GHTK service a linked shipment goes by.
type LinkedService string

const (
	ServiceStandard LinkedService = "standard"
	ServiceExpress  LinkedService = "express"
)

// Pickup is where GHTK takes a linked shipment's parcel: from the seller's
// home, or at a post office the seller brings it to.
type Pickup string

const (
	PickupHome       Pickup = "home"
	PickupPostOffice Pickup = "post_office"
)

// LinkedDraft is what the seller picks for a linked shipment; the server
// makes the shipment at GHTK.
type LinkedDraft struct {
	Service     LinkedService `json:"service"`
	WeightGrams int           `json:"weight_grams"`
	Pickup      Pickup        `json:"pickup"`
}

// Waits are how long the system waits before it moves an order on.
type Waits struct {
	// Seller is how long a pending order waits for its shipment.
	Seller time.Duration
	// Pickup is how long a shipment waits for the carrier's pickup.
	Pickup time.Duration
	// Complete is how long a delivered parcel waits for the buyer's word.
	Complete time.Duration
}

// OrderWaits are the waits of every order: 3 days each.
var OrderWaits = Waits{Seller: 72 * time.Hour, Pickup: 72 * time.Hour, Complete: 72 * time.Hour}

// Recipient is where the parcel goes. Phone is in the +84 form.
type Recipient struct {
	Name        string `json:"name"`
	Phone       string `json:"phone"`
	Street      string `json:"street"`
	CommuneCode string `json:"commune_code"`
}

// Order is a buyer's request for cash on delivery at the agreed price, and
// what became of it. Code is set by the store.
type Order struct {
	ID           uuid.UUID    `json:"id"`
	Code         string       `json:"code"`
	Status       OrderStatus  `json:"status"`
	Price        int64        `json:"price"`
	Recipient    Recipient    `json:"recipient"`
	Shipment     *Shipment    `json:"shipment,omitempty"`
	CancelledBy  Party        `json:"cancelled_by,omitempty"`
	CancelReason CancelReason `json:"cancel_reason,omitempty"`
	RequestedAt  time.Time    `json:"requested_at"`
	ShippedAt    *time.Time   `json:"shipped_at,omitempty"`
	ClosedAt     *time.Time   `json:"closed_at,omitempty"`
}

// Tracking checks a carrier and a tracking code as the seller typed them:
// a carrier ShopNexus reads, and 1 to 50 characters once trimmed. It
// returns the code trimmed.
func Tracking(carrier, code string) (Carrier, string, error) {
	e := ErrInvalidShipment
	c, code := Carrier(carrier), strings.TrimSpace(code)
	if !slices.Contains(carriers, c) {
		e = e.WithField("carrier", "ghtk, ghn, spx, jt or viettel_post")
	}
	if n := utf8.RuneCountInString(code); n < 1 || n > maxTrackingCode {
		e = e.WithField("tracking_code", "1 to 50 characters")
	}
	if len(e.Fields) > 0 {
		return "", "", e
	}
	return c, code, nil
}

// NewLinkedDraft checks what the seller picked for a linked shipment.
func NewLinkedDraft(service string, weightGrams int, pickup string) (LinkedDraft, error) {
	e := ErrInvalidShipment
	s, p := LinkedService(service), Pickup(pickup)
	if s != ServiceStandard && s != ServiceExpress {
		e = e.WithField("service", "standard or express")
	}
	if weightGrams < 1 || weightGrams > MaxWeight {
		e = e.WithField("weight_grams", "1 to 20,000 grams")
	}
	if p != PickupHome && p != PickupPostOffice {
		e = e.WithField("pickup", "home or post_office")
	}
	if len(e.Fields) > 0 {
		return LinkedDraft{}, e
	}
	return LinkedDraft{Service: s, WeightGrams: weightGrams, Pickup: p}, nil
}

// ParseShipmentStatus reads a status a carrier, or the dev endpoint,
// reports.
func ParseShipmentStatus(s string) (ShipmentStatus, error) {
	st := ShipmentStatus(s)
	switch st {
	case ShipmentPendingPickup, ShipmentInTransit, ShipmentDelivered, ShipmentFailed:
		return st, nil
	}
	return "", ErrInvalidStatus
}

// Open reports whether the order is pending or shipped.
func (o Order) Open() bool { return o.Status == OrderPending || o.Status == OrderShipped }

// RecipientFor is the recipient as viewer may read it: the seller of a
// cancelled order keeps only the name and the commune.
func (o Order) RecipientFor(viewer Party) Recipient {
	r := o.Recipient
	if viewer == Seller && o.Status == OrderCancelled {
		r.Phone, r.Street = "", ""
	}
	return r
}
```

- [ ] **Step 4: The errors**

In `internal/deal/domain/errors.go`, `ErrOrdersOpen`'s message becomes `"an order of the account is pending or shipped"`, delete `ErrInvalidWaybill`, and add to the block:

```go
	ErrInvalidShipment = apperr.New(apperr.KindInvalid, "invalid_shipment", "the shipment breaks a rule; see fields")
	// ErrShipmentUnknown is a tracking code the carrier does not know, on a
	// shipment being created or corrected.
	ErrShipmentUnknown = apperr.New(apperr.KindInvalid, "shipment_not_found", "the carrier does not know the tracking code")
	// ErrShipmentNotFound is a tracking code nothing knows: the carrier, on
	// a lookup, or every order, on a carrier's report.
	ErrShipmentNotFound = apperr.New(apperr.KindNotFound, "shipment_not_found", "no such shipment")
	ErrInvalidStatus    = apperr.New(apperr.KindInvalid, "invalid_status", "the status is not pending_pickup, in_transit, delivered or failed")
	// ErrCarrierUnavailable is a stack without a carrier (CARRIER=none):
	// no shipment can be made, read or corrected there.
	ErrCarrierUnavailable = apperr.New(apperr.KindUnavailable, "carrier_unavailable", "no carrier makes or reads shipments here")
	// errFailedParcel is a parcel the carrier reports failed, which no
	// order ships on.
	errFailedParcel = ErrInvalidShipment.WithField("tracking_code", "the carrier reports this parcel failed")
```

- [ ] **Step 5: The moves**

In `internal/deal/domain/deal.go`:

The comment of `StatusSold` becomes `// StatusSold is a deal whose order was completed; it takes no move.`

The move kinds from `MoveCodRequested` to `MoveOrderCancelled` become:

```go
	MoveCodRequested    MoveKind = "cod_requested"
	MoveShipped         MoveKind = "shipped"
	MoveShipmentUpdated MoveKind = "shipment_updated"
	MoveCompleted       MoveKind = "completed"
	MoveFailed          MoveKind = "failed"
	MoveOrderCancelled  MoveKind = "order_cancelled"
```

The comment of `Move` ends `on cod_requested the price, on shipped the carrier's fee when it gave one.`

`Cancel` becomes:

```go
// Cancel drops the agreed price, and a pending order with it; the deal
// negotiates again. A shipped order cannot be cancelled.
func (d *Deal) Cancel(by Party, now time.Time) error {
	if d.status != StatusAgreed {
		return ErrMoveNotAllowed
	}
	if o := d.openOrder(); o != nil {
		if o.Status != OrderPending {
			return ErrMoveNotAllowed
		}
		reason := CancelByBuyer
		if by == Seller {
			reason = CancelBySeller
		}
		d.cancelOrder(by, reason, now)
		return nil
	}
	d.reopen()
	d.record(MoveCancel, by, 0, now)
	return nil
}
```

In `RequestCod`, `Status: OrderRequested` becomes `Status: OrderPending`.

Replace `Ship`, `Deliver` and `Return` (from the comment `// Ship records the waybill` to the end of `Return`) with:

```go
// Shippable reports whether by may ship order on l now: the seller, on the
// deal's pending order, with the listing on sale. DealShip asks before it
// holds the listing, and Ship asks again.
func (d *Deal) Shippable(by Party, order uuid.UUID, l Listing) error {
	o := d.openOrder()
	if by != Seller || o == nil || o.ID != order || o.Status != OrderPending {
		return ErrMoveNotAllowed
	}
	if l.Status != ListingActive {
		return ErrListingUnavailable
	}
	return nil
}

// Ship records s, the pending order's shipment as its carrier reads it or
// as GHTK made it: the order is shipped. A parcel the carrier already
// reports delivered is delivered at now; one it reports failed is
// ErrInvalidShipment.
func (d *Deal) Ship(by Party, order uuid.UUID, s Shipment, l Listing, now time.Time) error {
	if err := d.Shippable(by, order, l); err != nil {
		return err
	}
	if s.Status == ShipmentFailed {
		return errFailedParcel
	}
	s.DeliveredAt = nil
	if s.Status == ShipmentDelivered {
		s.DeliveredAt = &now
	}
	o := d.order
	o.Status, o.Shipment, o.ShippedAt = OrderShipped, &s, &now
	var fee int64
	if s.Fee != nil {
		fee = *s.Fee
	}
	d.record(MoveShipped, by, fee, now)
	return nil
}

// EditShipment puts s, the seller's corrected carrier and code as the
// carrier reads them, on order's manual shipment: the seller's, on the
// shipped order, while the parcel waits for pickup or is in transit. A
// parcel the carrier reports delivered is delivered at now; one it reports
// failed is ErrInvalidShipment and changes nothing.
func (d *Deal) EditShipment(by Party, order uuid.UUID, s Shipment, now time.Time) error {
	o := d.openOrder()
	if by != Seller || o == nil || o.ID != order || o.Status != OrderShipped || o.Shipment == nil ||
		o.Shipment.Mode != ModeManual ||
		(o.Shipment.Status != ShipmentPendingPickup && o.Shipment.Status != ShipmentInTransit) {
		return ErrMoveNotAllowed
	}
	if s.Status == ShipmentFailed {
		return errFailedParcel
	}
	s.Mode, s.DeliveredAt = ModeManual, nil
	if s.Status == ShipmentDelivered {
		s.DeliveredAt = &now
	}
	d.order.Shipment = &s
	d.record(MoveShipmentUpdated, by, 0, now)
	return nil
}

// ConfirmReceipt ends the shipped order completed on the buyer's word, at
// any time while it is shipped, whatever the carrier reports.
func (d *Deal) ConfirmReceipt(by Party, order uuid.UUID, now time.Time) error {
	o := d.openOrder()
	if by != Buyer || o == nil || o.ID != order || o.Status != OrderShipped {
		return ErrMoveNotAllowed
	}
	d.complete(by, now)
	return nil
}

// ShipmentUpdated sets the shipped order's shipment status as its carrier
// reports it and reports whether anything changed. delivered sets
// DeliveredAt and leaving it clears it. failed fails the order at once: the
// deal negotiates again without its agreed price. An order that is not the
// deal's shipped one, or one without a shipment, is ErrMoveNotAllowed: a
// late report changes nothing.
func (d *Deal) ShipmentUpdated(order uuid.UUID, status ShipmentStatus, now time.Time) (bool, error) {
	o := d.openOrder()
	if o == nil || o.ID != order || o.Status != OrderShipped || o.Shipment == nil {
		return false, ErrMoveNotAllowed
	}
	if o.Shipment.Status == status {
		return false, nil
	}
	s := *o.Shipment
	s.Status, s.DeliveredAt = status, nil
	if status == ShipmentDelivered {
		s.DeliveredAt = &now
	}
	o.Shipment = &s
	if status == ShipmentFailed {
		o.Status, o.ClosedAt = OrderFailed, &now
		d.reopen()
		d.record(MoveFailed, System, 0, now)
		return true, nil
	}
	d.record(MoveShipmentUpdated, System, 0, now)
	return true, nil
}

// SellerTimeout cancels order when it is still the deal's pending order;
// anything else is ErrMoveNotAllowed and the timer leaves the deal alone.
func (d *Deal) SellerTimeout(order uuid.UUID, now time.Time) error {
	o := d.openOrder()
	if o == nil || o.ID != order || o.Status != OrderPending {
		return ErrMoveNotAllowed
	}
	d.cancelOrder(System, CancelSellerTimeout, now)
	return nil
}

// PickupTimeout cancels order when it is shipped and its parcel still
// waits for pickup; anything else is ErrMoveNotAllowed.
func (d *Deal) PickupTimeout(order uuid.UUID, now time.Time) error {
	o := d.openOrder()
	if o == nil || o.ID != order || o.Status != OrderShipped || o.Shipment == nil ||
		o.Shipment.Status != ShipmentPendingPickup {
		return ErrMoveNotAllowed
	}
	d.cancelOrder(System, CancelPickupTimeout, now)
	return nil
}

// AutoComplete ends order completed when it is shipped and its carrier
// reports it delivered; anything else is ErrMoveNotAllowed.
func (d *Deal) AutoComplete(order uuid.UUID, now time.Time) error {
	o := d.openOrder()
	if o == nil || o.ID != order || o.Status != OrderShipped || o.Shipment == nil ||
		o.Shipment.Status != ShipmentDelivered {
		return ErrMoveNotAllowed
	}
	d.complete(System, now)
	return nil
}
```

In `ListingChanged`: the comment's second sentence becomes `A pending order ends when the listing is hidden, gone or reserved for another order; a shipped one stays.`, `if o.Status != OrderRequested` becomes `if o.Status != OrderPending`, and `CancelSentToAnother` becomes `CancelShippedToAnother`.

`TurnOf` becomes:

```go
// TurnOf reports whether by has to act: the deal negotiates and the open
// price l still stands behind is the other side's, or the deal is agreed
// and waits for the buyer's COD request on a listing still on sale or, on
// a pending order, for the seller's shipment. Nobody's turn comes while an
// order is shipped: the carrier moves it.
func (d *Deal) TurnOf(by Party, l Listing) bool {
	switch d.status {
	case StatusNegotiating:
		open := d.live(l)
		return open != nil && open.By != by
	case StatusAgreed:
		o := d.openOrder()
		if by == Seller {
			return o != nil && o.Status == OrderPending
		}
		return o == nil && l.Status == ListingActive
	case StatusSold:
		return false
	}
	return false
}
```

`openOrder`'s comment becomes `// openOrder is the deal's order while pending or shipped, nil otherwise.` Replace `cancelOrder` with:

```go
// cancelOrder ends the open order and drops the agreement.
func (d *Deal) cancelOrder(by Party, reason CancelReason, now time.Time) {
	d.order.Status, d.order.CancelledBy, d.order.CancelReason, d.order.ClosedAt = OrderCancelled, by, reason, &now
	d.reopen()
	d.record(MoveOrderCancelled, by, 0, now)
}

// complete ends the shipped order completed; the deal is sold.
func (d *Deal) complete(by Party, now time.Time) {
	d.order.Status, d.order.ClosedAt, d.status = OrderCompleted, &now, StatusSold
	d.record(MoveCompleted, by, 0, now)
}
```

In `internal/deal/domain/erasure.go`: the comment says `a pending order is cancelled` instead of `a requested order is cancelled`, and `o.Status != OrderRequested` becomes `o.Status != OrderPending`.

- [ ] **Step 6: Run the domain tests and the linter**

Run: `golangci-lint fmt ./internal/deal/domain/ && go test ./internal/deal/domain/ && golangci-lint run ./internal/deal/domain/`
Expected: `ok`, then `0 issues.` Nothing else in `internal/deal` builds now; Tasks 4 and 5 bring it back.

- [ ] **Step 7: Commit**

```bash
git add internal/deal/domain
git commit -m "feat(deal): orders pending to completed or failed, with a shipment"
```

### Task 4: Migration 0040 and the shipment in the store

The migration and the store land together: every test database is migrated to the newest file, so the store of today could not write to it.

**Files:**
- Create: `migrations/0040_order_flow.sql`
- Test: `migrations/order_flow_test.go`
- Modify: `internal/deal/repository/deal_pg.go`, `internal/deal/repository/repository.go`, `internal/deal/repository/erasure_pg.go`
- Test: `internal/deal/repository/deal_pg_test.go`, `internal/deal/repository/pairs_pg_test.go`, `internal/deal/repository/erasure_pg_test.go`

**Interfaces:**
- Consumes: Task 3's `domain.Shipment`, statuses and moves.
- Produces: columns `orders.shipment_mode`, `shipment_status`, `delivered_at`; `repository.Deals.OrdersWithCode(ctx, code string) ([]OrderRow, error)`; test helper `pendingDeal` (was `requestedDeal`).

- [ ] **Step 1: Write the failing migration tests**

`migrations/order_flow_test.go`:

```go
package migrations_test

import (
	"context"
	"slices"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"

	"github.com/shopnexus/server/internal/account/accounttest"
	"github.com/shopnexus/server/internal/catalog/catalogtest"
	"github.com/shopnexus/server/internal/platform/postgres"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server/migrations"
)

// null is s, or NULL for the empty string.
func null(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func str(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

const insertDeal = `INSERT INTO deals (id, listing_id, buyer_id, seller_id, status, listed_price, write_id, created_at, updated_at)
VALUES (@deal, @listing, @buyer, @seller, 'negotiating', 1500000, @deal, now(), now())`

// The orders, moves and notices of the release before arrive under the
// new names: requested is pending, delivered completed, returned failed, a
// waybill a manual shipment, and a waybill of carrier other no shipment.
func TestOrderFlowRenamesTheOldOrders(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.Empty(t)
	if _, err := postgres.Migrate(ctx, db, before(t, "0040_order_flow.sql")); err != nil {
		t.Fatal(err)
	}
	// 0040 leaves accounts and listings as 0039 has them, so today's helpers fit.
	seller, buyer := accounttest.New(t, db), accounttest.New(t, db)
	olds := map[string]struct{ status, carrier, carrierName, reason string }{
		"requested": {status: "requested"},
		"shipped":   {status: "shipped", carrier: "spx"},
		"other":     {status: "shipped", carrier: "other", carrierName: "Ahamove"},
		"delivered": {status: "delivered", carrier: "ghn"},
		"returned":  {status: "returned", carrier: "jt"},
		"cancelled": {status: "cancelled", reason: "sent_to_another"},
	}
	orders, deals := map[string]uuid.UUID{}, map[string]uuid.UUID{}
	for name, o := range olds {
		orders[name], deals[name] = uuid.NewV7(), uuid.NewV7()
		a := pgx.NamedArgs{
			"deal": deals[name], "order": orders[name], "listing": catalogtest.Listing(t, db, seller), "buyer": buyer,
			"seller": seller, "status": o.status, "source": nil, "carrier": null(o.carrier), "carrier_name": null(o.carrierName),
			"code": nil, "fee": nil, "by": nil, "reason": null(o.reason), "shipped_at": nil, "closed_at": nil,
		}
		if o.carrier != "" {
			a["source"], a["code"], a["fee"], a["shipped_at"] = "self", "CODE-"+name, 22_000, time.Date(2026, 11, 1, 9, 0, 0, 0, time.UTC)
		}
		if o.status != "requested" && o.status != "shipped" {
			a["closed_at"] = time.Date(2026, 11, 2, 9, 0, 0, 0, time.UTC)
		}
		if o.reason != "" {
			a["by"] = "system"
		}
		for _, q := range []string{insertDeal, `INSERT INTO orders (id, deal_id, listing_id, buyer_id, seller_id, status, price,
    recipient_name, recipient_phone, recipient_street, recipient_commune, waybill_source, carrier, carrier_name, tracking_code,
    fee, cancelled_by, cancel_reason, requested_at, shipped_at, closed_at)
VALUES (@order, @deal, @listing, @buyer, @seller, @status, 1500000, 'Hân', '+84912345678', '12 Lý Thường Kiệt', '00004',
    @source, @carrier, @carrier_name, @code, @fee, @by, @reason, '2026-10-31T09:00:00Z', @shipped_at, @closed_at)`} {
			if _, err := db.Exec(ctx, q, a); err != nil {
				t.Fatalf("%s: %v", name, err)
			}
		}
	}
	args := pgx.NamedArgs{"deal": deals["delivered"], "buyer": buyer}
	for _, q := range []string{
		`INSERT INTO deal_moves (id, deal_id, kind, by_party, moved_at)
		 VALUES (gen_random_uuid(), @deal, 'delivered', 'seller', now()), (gen_random_uuid(), @deal, 'returned', 'seller', now())`,
		`INSERT INTO notifications (id, account_id, notice_type, params, event_id, created_at, bumped_at)
		 VALUES (gen_random_uuid(), @buyer, 'delivered', '{"title": "Xe đạp", "seller": "Nam"}', gen_random_uuid(), now(), now()),
		        (gen_random_uuid(), @buyer, 'returned', '{"title": "Xe đạp"}', gen_random_uuid(), now(), now()),
		        (gen_random_uuid(), @buyer, 'order_cancelled', '{"reason": "sent_to_another"}', gen_random_uuid(), now(), now())`,
	} {
		if _, err := db.Exec(ctx, q, args); err != nil {
			t.Fatalf("%s: %v", q, err)
		}
	}
	if _, err := postgres.Migrate(ctx, db, migrations.FS); err != nil {
		t.Fatalf("0040 on a database with orders: %v", err)
	}

	type order struct {
		status                          string
		mode, carrier, code, ship, why  *string
		fee                             *int64
		deliveredAt, closedAt           *time.Time
	}
	read := func(name string) order {
		var o order
		if err := db.QueryRow(ctx, `SELECT status, shipment_mode, carrier, tracking_code, shipment_status, cancel_reason, fee,
       delivered_at, closed_at FROM orders WHERE id = @id`, pgx.NamedArgs{"id": orders[name]}).
			Scan(&o.status, &o.mode, &o.carrier, &o.code, &o.ship, &o.why, &o.fee, &o.deliveredAt, &o.closedAt); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		return o
	}
	for name, want := range map[string]struct{ status, mode, carrier, ship, why string }{
		"requested": {"pending", "", "", "", ""},
		"shipped":   {"shipped", "manual", "spx", "in_transit", ""},
		"other":     {"shipped", "", "", "", ""},
		"delivered": {"completed", "manual", "ghn", "delivered", ""},
		"returned":  {"failed", "manual", "jt", "failed", ""},
		"cancelled": {"cancelled", "", "", "", "shipped_to_another"},
	} {
		o := read(name)
		if o.status != want.status || str(o.mode) != want.mode || str(o.carrier) != want.carrier || str(o.ship) != want.ship ||
			str(o.why) != want.why {
			t.Errorf("%s: %s %s %s %s %s", name, o.status, str(o.mode), str(o.carrier), str(o.ship), str(o.why))
		}
	}
	if o := read("shipped"); str(o.code) != "CODE-shipped" || o.fee == nil || *o.fee != 22_000 || o.deliveredAt != nil {
		t.Errorf("shipped: %s %v %v", str(o.code), o.fee, o.deliveredAt)
	}
	if o := read("delivered"); o.deliveredAt == nil || !o.deliveredAt.Equal(*o.closedAt) {
		t.Errorf("delivered at %v, closed at %v", o.deliveredAt, o.closedAt)
	}
	if o := read("other"); o.code != nil || o.fee != nil {
		t.Errorf("carrier other kept %s %v", str(o.code), o.fee)
	}

	var kinds []string
	if err := db.QueryRow(ctx, `SELECT array_agg(kind ORDER BY kind) FROM deal_moves WHERE deal_id = @deal`, args).
		Scan(&kinds); err != nil || !slices.Equal(kinds, []string{"completed", "failed"}) {
		t.Errorf("moves %v: %v", kinds, err)
	}
	var notices []string
	if err := db.QueryRow(ctx, `SELECT array_agg(notice_type || ':' || coalesce(params ->> 'reason', '') ORDER BY notice_type)
FROM notifications WHERE account_id = @buyer`, args).Scan(&notices); err != nil ||
		!slices.Equal(notices, []string{"completed:", "failed:", "order_cancelled:shipped_to_another"}) {
		t.Errorf("notices %v: %v", notices, err)
	}
	var gone int
	if err := db.QueryRow(ctx, `SELECT count(*) FROM information_schema.columns
WHERE table_name = 'orders' AND column_name IN ('waybill_source', 'carrier_name')`).Scan(&gone); err != nil || gone != 0 {
		t.Errorf("%d old columns: %v", gone, err)
	}
}

// The checks keep the old names and a half shipment out, and a deal has
// one open order.
func TestOrderFlowChecks(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	seller, buyer := accounttest.New(t, db), accounttest.New(t, db)
	a := pgx.NamedArgs{"deal": uuid.NewV7(), "listing": catalogtest.Listing(t, db, seller), "buyer": buyer, "seller": seller}
	if _, err := db.Exec(ctx, insertDeal, a); err != nil {
		t.Fatal(err)
	}
	insert := func(status, mode, carrier, ship, reason string, delivered bool) error {
		b := pgx.NamedArgs{
			"status": status, "mode": null(mode), "carrier": null(carrier), "code": nil, "ship": null(ship),
			"delivered_at": nil, "by": nil, "reason": null(reason),
		}
		for k, v := range a {
			b[k] = v
		}
		if carrier != "" {
			b["code"] = "CODE1"
		}
		if delivered {
			b["delivered_at"] = time.Now()
		}
		if reason != "" {
			b["by"] = "system"
		}
		_, err := db.Exec(ctx, `INSERT INTO orders (id, deal_id, listing_id, buyer_id, seller_id, status, price, recipient_name,
    recipient_phone, recipient_street, recipient_commune, shipment_mode, carrier, tracking_code, shipment_status, delivered_at,
    cancelled_by, cancel_reason, requested_at)
VALUES (gen_random_uuid(), @deal, @listing, @buyer, @seller, @status, 1500000, 'Hân', '+84912345678', '1 Lê Lợi', '00004',
    @mode, @carrier, @code, @ship, @delivered_at, @by, @reason, now())`, b)
		return err
	}
	if err := insert("cancelled", "linked", "ghtk", "pending_pickup", "pickup_timeout", false); err != nil {
		t.Fatalf("a cancelled linked shipment: %v", err)
	}
	if err := insert("failed", "manual", "ghn", "failed", "", false); err != nil {
		t.Fatalf("a failed shipment: %v", err)
	}
	for name, err := range map[string]error{
		"status requested":         insert("requested", "", "", "", "", false),
		"carrier other":            insert("cancelled", "manual", "other", "in_transit", "buyer", false),
		"a carrier without a mode": insert("cancelled", "", "ghn", "in_transit", "buyer", false),
		"a mode without a status":  insert("cancelled", "manual", "ghn", "", "buyer", false),
		"delivered_at in transit":  insert("cancelled", "manual", "ghn", "in_transit", "buyer", true),
		"reason sent_to_another":   insert("cancelled", "", "", "", "sent_to_another", false),
	} {
		if err == nil {
			t.Errorf("%s was stored", name)
		}
	}
	if err := insert("pending", "", "", "", "", false); err != nil {
		t.Fatal(err)
	}
	if err := insert("shipped", "manual", "spx", "in_transit", "", false); err == nil {
		t.Fatal("a deal took a second open order")
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./migrations/ -run 'TestOrderFlow'`
Expected: FAIL: with no 0040 the orders keep their old columns: `requested: ERROR: column "shipment_mode" does not exist`.

- [ ] **Step 3: Write the migration**

`migrations/0040_order_flow.sql`:

```sql
-- The order flow of 2026-11-12: an order is pending, shipped, completed,
-- failed or cancelled, and a shipment replaces the waybill. A shipment is
-- linked (the server made it on the seller's GHTK account) or manual (the
-- seller typed the code of a shipment made on a carrier's own app), and
-- keeps the status its carrier reports. Spec:
-- ~/shopnexus/docs/superpowers/specs/2026-11-12-order-flow-sync-design.md.
--
-- This migration renames values the release before writes and drops two
-- columns it reads, so that release's order reads and writes fail while a
-- deploy rolls out. Part 1 of the spec does not wire the app to the
-- server, so no one calls them then.

ALTER TABLE orders DROP CONSTRAINT orders_status_check;
ALTER TABLE orders DROP CONSTRAINT orders_carrier_check;
ALTER TABLE orders DROP CONSTRAINT orders_cancel_reason_check;
DROP INDEX orders_open_per_deal;

ALTER TABLE orders
    ADD COLUMN shipment_mode text,
    ADD COLUMN shipment_status text,
    ADD COLUMN delivered_at timestamptz;

-- A waybill of a carrier ShopNexus cannot read keeps no shipment. Only
-- development data has one, and the buyer's confirmation still closes it.
UPDATE orders SET carrier = NULL, tracking_code = NULL, fee = NULL WHERE carrier = 'other';
UPDATE orders SET status = CASE status
    WHEN 'requested' THEN 'pending' WHEN 'delivered' THEN 'completed' WHEN 'returned' THEN 'failed' ELSE status END;
-- Every other waybill was typed by its seller: a manual shipment, with the
-- carrier already holding the parcel, or the way the order ended.
UPDATE orders SET shipment_mode = 'manual', shipment_status = CASE status
    WHEN 'completed' THEN 'delivered' WHEN 'failed' THEN 'failed' ELSE 'in_transit' END
WHERE carrier IS NOT NULL;
UPDATE orders SET delivered_at = closed_at WHERE shipment_status = 'delivered';
UPDATE orders SET cancel_reason = 'shipped_to_another' WHERE cancel_reason = 'sent_to_another';

ALTER TABLE orders DROP COLUMN waybill_source, DROP COLUMN carrier_name;
ALTER TABLE orders
    ADD CONSTRAINT orders_status_check CHECK (status IN ('pending', 'shipped', 'completed', 'failed', 'cancelled')),
    ADD CONSTRAINT orders_carrier_check CHECK (carrier IN ('ghtk', 'ghn', 'spx', 'jt', 'viettel_post')),
    ADD CONSTRAINT orders_shipment_mode_check CHECK (shipment_mode IN ('linked', 'manual')),
    ADD CONSTRAINT orders_shipment_status_check
        CHECK (shipment_status IN ('pending_pickup', 'in_transit', 'delivered', 'failed')),
    ADD CONSTRAINT orders_cancel_reason_check CHECK (cancel_reason IN (
        'buyer', 'seller', 'seller_timeout', 'pickup_timeout', 'shipped_to_another', 'listing_closed'
    )),
    -- A shipment has its mode, carrier, code and status together; only a
    -- delivered one has a delivery time.
    ADD CONSTRAINT orders_shipment_check CHECK (
        (shipment_mode IS NULL) = (carrier IS NULL)
        AND (shipment_mode IS NULL) = (tracking_code IS NULL)
        AND (shipment_mode IS NULL) = (shipment_status IS NULL)
        AND (delivered_at IS NULL OR shipment_status = 'delivered')
    );

CREATE UNIQUE INDEX orders_open_per_deal ON orders (deal_id) WHERE status IN ('pending', 'shipped');
-- A carrier's report names a tracking code; ShipmentUpdates finds its orders here.
CREATE INDEX orders_tracking_code ON orders (tracking_code) WHERE tracking_code IS NOT NULL;

ALTER TABLE deal_moves DROP CONSTRAINT deal_moves_kind_check;
UPDATE deal_moves SET kind = CASE kind WHEN 'delivered' THEN 'completed' ELSE 'failed' END
WHERE kind IN ('delivered', 'returned');
ALTER TABLE deal_moves ADD CONSTRAINT deal_moves_kind_check CHECK (kind IN (
    'offer', 'counter', 'accept', 'decline', 'withdraw', 'cancel', 'price_changed', 'offers_closed',
    'listing_closed', 'cod_requested', 'shipped', 'shipment_updated', 'completed', 'failed', 'order_cancelled'
));

-- Stored notices take the new types, whose texts read the same params.
UPDATE notifications SET notice_type = CASE notice_type WHEN 'delivered' THEN 'completed' ELSE 'failed' END
WHERE notice_type IN ('delivered', 'returned');
UPDATE notifications SET params = jsonb_set(params, '{reason}', '"shipped_to_another"')
WHERE params ->> 'reason' = 'sent_to_another';
```

- [ ] **Step 4: Run the migration tests**

Run: `go test ./migrations/`
Expected: PASS, the earlier migration tests included.

- [ ] **Step 5: Write the failing store tests**

In `internal/deal/repository/*_test.go`, rename the helper `requestedDeal` to `pendingDeal` (its comment: `pendingDeal stores a deal on a new listing of seller's, agreed and with a pending order.`) and every call to it:

```bash
sed -i 's/requestedDeal/pendingDeal/g' internal/deal/repository/*_test.go
```

then fix the helper's comment by hand. In `deal_pg_test.go`, `TestOrderRoundTrip` from `o := got.Order()` to its end becomes:

```go
	o := got.Order()
	if o == nil || o.Status != domain.OrderPending || !strings.HasPrefix(o.Code, "SN-") || o.Recipient.Name != "Hân" ||
		o.Price != 1_500_000 || o.RequestedAt.IsZero() || o.Shipment != nil {
		t.Fatalf("%+v", o)
	}
	sent := domain.Shipment{Mode: domain.ModeManual, Carrier: domain.CarrierGHN, TrackingCode: "GHN1", Status: domain.ShipmentPendingPickup}
	if err = got.Ship(domain.Seller, o.ID, sent, onSale, now); err != nil {
		t.Fatal(err)
	}
	if err = s.Save(ctx, &got, uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	if got, err = s.Get(ctx, d.ID()); err != nil || got.Order().Shipment == nil || *got.Order().Shipment != sent ||
		got.Order().ShippedAt == nil || got.Order().Code != o.Code {
		t.Fatalf("%+v %v", got.Order(), err)
	}
	for _, c := range []struct {
		account uuid.UUID
		as      domain.Party
	}{{buyer, domain.Buyer}, {seller, domain.Seller}} {
		rows, listErr := s.ListOrders(ctx, c.account, c.as, page.Request{})
		if listErr != nil || len(rows) != 1 || rows[0].DealID != d.ID() || rows[0].ListingID != d.ListingID() ||
			rows[0].Order.Status != domain.OrderShipped || rows[0].Order.Shipment == nil {
			t.Fatalf("%s: %+v %v", c.as, rows, listErr)
		}
	}
	if _, err = got.ShipmentUpdated(o.ID, domain.ShipmentDelivered, now); err != nil {
		t.Fatal(err)
	}
	if err = s.Save(ctx, &got, uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	if got, err = s.Get(ctx, d.ID()); err != nil || got.Order().Shipment.Status != domain.ShipmentDelivered ||
		got.Order().Shipment.DeliveredAt == nil || !got.Order().Shipment.DeliveredAt.Equal(now) || got.Order().Shipment.Fee != nil {
		t.Fatalf("%+v %v", got.Order().Shipment, err)
	}
	if err = got.ConfirmReceipt(domain.Buyer, o.ID, now); err != nil {
		t.Fatal(err)
	}
	if err = s.Save(ctx, &got, uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	if got, err = s.Get(ctx, d.ID()); err != nil || got.Status() != domain.StatusSold || got.AgreedPrice() != 1_500_000 ||
		got.Order().Status != domain.OrderCompleted {
		t.Fatalf("%+v %v", got.State(), err)
	}
}
```

In `TestOneShippedOrderPerListing`, the waybill becomes a shipment:

```go
	sent := domain.Shipment{Mode: domain.ModeManual, Carrier: domain.CarrierGHN, TrackingCode: "GHN1", Fee: new(int64(20_000)), Status: domain.ShipmentPendingPickup}
```

(delete the `w, err := domain.NewWaybill(...)` lines and their check; declare `var err error` before the loop) and `d.Ship(domain.Seller, d.Order().ID, w, onSale, now)` becomes `d.Ship(domain.Seller, d.Order().ID, sent, onSale, now)`. In `TestOrderByID`, `domain.OrderRequested` becomes `domain.OrderPending`.

Add to `deal_pg_test.go`:

```go
func TestOrdersWithCode(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewDeals(db)
	ctx := context.Background()
	seller := accounttest.New(t, db)
	ship := func(code string) domain.Deal {
		t.Helper()
		d := pendingDeal(t, db, s, accounttest.New(t, db), seller)
		sent := domain.Shipment{Mode: domain.ModeManual, Carrier: domain.CarrierSPX, TrackingCode: code, Status: domain.ShipmentPendingPickup}
		if err := d.Ship(domain.Seller, d.Order().ID, sent, onSale, now); err != nil {
			t.Fatal(err)
		}
		if err := s.Save(ctx, &d, uuid.NewV7()); err != nil {
			t.Fatal(err)
		}
		return d
	}
	// Two items in one parcel: two orders, one code.
	a, b := ship("SPX-ONE"), ship("SPX-ONE")
	ship("SPX-TWO")
	pendingDeal(t, db, s, accounttest.New(t, db), seller)
	rows, err := s.OrdersWithCode(ctx, "SPX-ONE")
	if err != nil || len(rows) != 2 || rows[0].DealID != a.ID() || rows[1].DealID != b.ID() ||
		rows[0].Order.Shipment == nil || rows[0].Order.Shipment.TrackingCode != "SPX-ONE" {
		t.Fatalf("%+v %v", rows, err)
	}
	if rows, err = s.OrdersWithCode(ctx, "SPX-NONE"); err != nil || len(rows) != 0 {
		t.Fatalf("an unknown code: %+v %v", rows, err)
	}
}
```

In `pairs_pg_test.go`, `soldDeal` becomes:

```go
// soldDeal stores a deal on a new listing of seller's whose order was
// completed.
func soldDeal(t *testing.T, db *pgxpool.Pool, s repository.Deals, buyer, seller uuid.UUID) domain.Deal {
	t.Helper()
	d := pendingDeal(t, db, s, buyer, seller)
	sent := domain.Shipment{Mode: domain.ModeManual, Carrier: domain.CarrierSPX, TrackingCode: "SPX1", Status: domain.ShipmentPendingPickup}
	if err := d.Ship(domain.Seller, d.Order().ID, sent, onSale, now); err != nil {
		t.Fatal(err)
	}
	if err := d.ConfirmReceipt(domain.Buyer, d.Order().ID, now); err != nil {
		t.Fatal(err)
	}
	if err := s.Save(context.Background(), &d, uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	return d
}
```

and `o.Status != domain.OrderDelivered` becomes `o.Status != domain.OrderCompleted`.

- [ ] **Step 6: Run them to see them fail**

Run: `go test ./internal/deal/repository/`
Expected: FAIL to build: `s.OrdersWithCode undefined`, and the store still names `o.waybill_source`.

- [ ] **Step 7: The store**

In `internal/deal/repository/repository.go`, the comments of `Save` and `OpenOrders` say `pending` where they say `requested`, and the interface gains, after `Order`:

```go
	// OrdersWithCode returns the orders, in any status, whose shipment has
	// the tracking code, oldest first.
	OrdersWithCode(ctx context.Context, code string) ([]OrderRow, error)
```

In `internal/deal/repository/deal_pg.go`:

```go
const orderColumns = `o.id, o.code, o.status, o.price, o.recipient_name, o.recipient_phone, o.recipient_street,
       o.recipient_commune, o.shipment_mode, o.carrier, o.tracking_code, o.fee, o.shipment_status, o.delivered_at,
       o.cancelled_by, o.cancel_reason, o.requested_at, o.shipped_at, o.closed_at`
```

`orderScan`, `dest` and `order` become:

```go
// orderScan holds an order's nullable columns while a row is scanned.
type orderScan struct {
	id                             *uuid.UUID
	code, status                   *string
	price                          *int64
	name, phone, street, commune   *string
	mode, carrier, tracking, state *string
	fee                            *int64
	deliveredAt                    *time.Time
	cancelledBy, cancelReason      *string
	requestedAt                    *time.Time
	shippedAt, closedAt            *time.Time
}

func (o *orderScan) dest() []any {
	return []any{
		&o.id, &o.code, &o.status, &o.price, &o.name, &o.phone, &o.street, &o.commune, &o.mode, &o.carrier, &o.tracking,
		&o.fee, &o.state, &o.deliveredAt, &o.cancelledBy, &o.cancelReason, &o.requestedAt, &o.shippedAt, &o.closedAt,
	}
}

// order is the scanned order, nil when the row had none.
func (o *orderScan) order() *domain.Order {
	if o.id == nil {
		return nil
	}
	out := &domain.Order{
		ID: *o.id, Code: *o.code, Status: domain.OrderStatus(*o.status), Price: *o.price,
		Recipient:   domain.Recipient{Name: *o.name, Phone: *o.phone, Street: *o.street, CommuneCode: *o.commune},
		RequestedAt: *o.requestedAt, ShippedAt: o.shippedAt, ClosedAt: o.closedAt,
	}
	if o.mode != nil {
		out.Shipment = &domain.Shipment{
			Mode: domain.ShipmentMode(*o.mode), Carrier: domain.Carrier(*o.carrier), TrackingCode: *o.tracking,
			Fee: o.fee, Status: domain.ShipmentStatus(*o.state), DeliveredAt: o.deliveredAt,
		}
	}
	if o.cancelledBy != nil {
		out.CancelledBy, out.CancelReason = domain.Party(*o.cancelledBy), domain.CancelReason(*o.cancelReason)
	}
	return out
}
```

`countOpenOrders` reads `status IN ('pending', 'shipped')`. `upsertOrder` becomes:

```go
const upsertOrder = `
INSERT INTO orders (id, deal_id, listing_id, buyer_id, seller_id, status, price, recipient_name, recipient_phone,
                    recipient_street, recipient_commune, shipment_mode, carrier, tracking_code, fee, shipment_status,
                    delivered_at, cancelled_by, cancel_reason, requested_at, shipped_at, closed_at)
VALUES (@id, @deal_id, @listing_id, @buyer_id, @seller_id, @status, @price, @recipient_name, @recipient_phone,
        @recipient_street, @recipient_commune, @shipment_mode, @carrier, @tracking_code, @fee, @shipment_status,
        @delivered_at, @cancelled_by, @cancel_reason, @requested_at, @shipped_at, @closed_at)
ON CONFLICT (id) DO UPDATE
SET status = excluded.status, shipment_mode = excluded.shipment_mode, carrier = excluded.carrier,
    tracking_code = excluded.tracking_code, fee = excluded.fee, shipment_status = excluded.shipment_status,
    delivered_at = excluded.delivered_at, cancelled_by = excluded.cancelled_by, cancel_reason = excluded.cancel_reason,
    shipped_at = excluded.shipped_at, closed_at = excluded.closed_at`
```

`orderArgs` becomes:

```go
// orderArgs are the order's columns as named arguments, NULL where it has
// nothing.
func orderArgs(st domain.DealState, o domain.Order) pgx.StrictNamedArgs {
	a := pgx.StrictNamedArgs{
		"id": o.ID, "deal_id": st.ID, "listing_id": st.ListingID, "buyer_id": st.BuyerID, "seller_id": st.SellerID,
		"status": o.Status, "price": o.Price, "recipient_name": o.Recipient.Name,
		"recipient_phone": o.Recipient.Phone, "recipient_street": o.Recipient.Street,
		"recipient_commune": o.Recipient.CommuneCode, "shipment_mode": nil, "carrier": nil, "tracking_code": nil,
		"fee": nil, "shipment_status": nil, "delivered_at": nil, "cancelled_by": nil, "cancel_reason": nil,
		"requested_at": o.RequestedAt, "shipped_at": o.ShippedAt, "closed_at": o.ClosedAt,
	}
	if s := o.Shipment; s != nil {
		a["shipment_mode"], a["carrier"], a["tracking_code"] = s.Mode, s.Carrier, s.TrackingCode
		a["fee"], a["shipment_status"], a["delivered_at"] = s.Fee, s.Status, s.DeliveredAt
	}
	if o.CancelledBy != "" {
		a["cancelled_by"], a["cancel_reason"] = o.CancelledBy, o.CancelReason
	}
	return a
}
```

In `Save`, `if o.Status == domain.OrderRequested {` becomes `if o.Status == domain.OrderPending {`. Add after `Order`:

```go
func (s pgDeals) OrdersWithCode(ctx context.Context, code string) ([]OrderRow, error) {
	rows, err := s.db.Query(ctx, selectOrder+`WHERE o.tracking_code = @code ORDER BY o.id`, pgx.StrictNamedArgs{"code": code})
	if err != nil {
		return nil, fmt.Errorf("select orders: %w", err)
	}
	out, err := pgx.CollectRows(rows, scanOrder)
	if err != nil {
		return nil, fmt.Errorf("read orders: %w", err)
	}
	return out, nil
}
```

In `internal/deal/repository/erasure_pg.go`, `status IN ('requested', 'shipped')` becomes `status IN ('pending', 'shipped')`.

- [ ] **Step 8: Run the store tests and the linter**

Run: `golangci-lint fmt ./internal/deal/repository/ ./migrations/ && go test ./internal/deal/repository/ ./migrations/ && golangci-lint run ./internal/deal/repository/ ./migrations/`
Expected: `ok` twice, then `0 issues.`

- [ ] **Step 9: Commit**

```bash
git add migrations internal/deal/repository
git commit -m "feat(deal): migration 0040 and the shipment in the store"
```

### Task 5: Sellers create shipments and buyers confirm receipt

`/ship`, `/deliver` and `/return` were three use cases; this task replaces them with `CreateShipment`, `EditShipment`, `ConfirmReceipt` and `LookupShipment`, and `DealFinish` with `DealConfirm`. The timers land in Task 6.

**Files:**
- Delete: `internal/deal/service/order_ship.go`, `internal/deal/service/order_finish_durable.go`
- Create: `internal/deal/service/order_shipment_create.go`, `order_shipment_edit.go`, `order_confirm.go`, `shipment_lookup.go`, `order_confirm_durable.go`
- Modify: `internal/deal/service/service.go`, `order_flow.go`, `order_ship_durable.go`, `views.go`
- Test: `internal/deal/service/helpers_test.go`, `flow_test.go` (rewritten whole), `no_carrier_test.go`, `order_test.go`, `pairs_test.go`, `account_deleted_test.go`
- Modify: `internal/trust/service/review.go`, `internal/notification/worker/worker.go`
- Test: `internal/trust/service/helpers_test.go`, `internal/trust/service/review_test.go`

**Interfaces:**
- Consumes: `carrier.Client`, `carrier.Fake` (Task 2); the domain of Task 3; the store of Task 4.
- Produces: `service.Deps.Carrier`; `service.ShipmentInput`, `ShipmentPreview`, `FlowInput` with `Manual` and `Linked`; `Service.CreateShipment`, `EditShipment`, `ConfirmReceipt`, `LookupShipment`, each mapping `carrier.ErrUnavailable` to `domain.ErrCarrierUnavailable`; `DealShip`, `DealConfirm`; `OrderView.Shipment`; test helpers `e.pending`, `e.shipped`, `e.noCarrier`, `manual`, `linked`, `countingCarrier`.

- [ ] **Step 1: Write the failing service tests**

In `internal/deal/service/helpers_test.go`, `newEnv`'s deps gain the fake carrier (import `github.com/shopnexus/server/internal/provider/carrier`):

```go
	deps := service.Deps{Deals: repo, Accounts: accounts, Catalog: c, Carrier: carrier.Fake{}, Ingress: in, Now: time.Now}
```

In `internal/deal/service/order_test.go`: the helper `requested` becomes `pending` (comment `// pending agrees buyer's deal on listing and asks for COD.`), every `e.requested(` becomes `e.pending(` here and in `pairs_test.go` and `account_deleted_test.go` (`sed -i 's/e\.requested(/e.pending(/g' internal/deal/service/*_test.go`), and every `domain.OrderRequested` becomes `domain.OrderPending` in `order_test.go` and `pairs_test.go`. In `pairs_test.go` the comments `a requested order the seller has to ship` and `The seller of the requested order has to ship it.` say `a pending order` and `pending order`. `TestCancelARequestedOrder` is renamed `TestCancelAPendingOrder`. `TestShipCancelsOtherRequests` becomes:

```go
func TestShipCancelsOtherPendingOrders(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, one, two := e.person(t), e.person(t), e.person(t)
	listing := catalogtest.Listing(t, e.db, seller)
	first, second := e.pending(t, one, listing), e.pending(t, two, listing)
	must(t)(e.deals.CreateShipment(ctx, seller, first.Order.ID, key(), manual("SPXVN0123")))
	if v := e.get(t, two, second.ID); v.Order.Status != domain.OrderCancelled || v.Order.CancelReason != domain.CancelShippedToAnother ||
		v.Status != domain.StatusNegotiating {
		t.Fatalf("other buyer: %+v %s", v.Order, v.Status)
	}
	if v := e.get(t, one, first.ID); v.Order.Status != domain.OrderShipped {
		t.Fatalf("first buyer: %+v", v.Order)
	}
}
```

Replace `internal/deal/service/flow_test.go` with:

```go
package service_test

import (
	"context"
	"errors"
	"strings"
	"sync/atomic"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server/internal/catalog/catalogtest"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/deal/repository"
	"github.com/shopnexus/server/internal/deal/service"
	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/platform/events"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server/internal/provider/carrier"
)

// manual is a shipment the seller made on SPX's own app, under a code the
// fake carrier knows.
func manual(code string) service.ShipmentInput {
	return service.ShipmentInput{Mode: "manual", Carrier: "spx", TrackingCode: code}
}

// linked is a shipment to make on the seller's GHTK account.
var linked = service.ShipmentInput{Mode: "linked", Service: "standard", WeightGrams: 800, Pickup: "home"}

func key() string { return uuid.NewV7().String() }

// summary reads listing through catalog.
func (e env) summary(t *testing.T, listing uuid.UUID) (catalogdomain.Status, uuid.UUID) {
	t.Helper()
	l, _, err := e.catalog.Summary(context.Background(), listing)
	if err != nil {
		t.Fatal(err)
	}
	return l.Status, l.ReservedFor
}

func count(kinds []string, kind string) int {
	n := 0
	for _, k := range kinds {
		if k == kind {
			n++
		}
	}
	return n
}

// shipped is a pending order of buyer's on listing, shipped by its seller
// under code with the fake carrier.
func (e env) shipped(t *testing.T, buyer, seller, listing uuid.UUID, code string) service.DealView {
	t.Helper()
	v := e.pending(t, buyer, listing)
	s, err := e.deals.CreateShipment(context.Background(), seller, v.Order.ID, key(), manual(code))
	if err != nil {
		t.Fatal(err)
	}
	return s
}

// countingCarrier is the fake carrier, counting the shipments it calls off.
type countingCarrier struct {
	carrier.Fake

	cancels *atomic.Int32
}

func (c countingCarrier) Cancel(ctx context.Context, cr carrier.Carrier, code string) error {
	c.cancels.Add(1)
	return c.Fake.Cancel(ctx, cr, code)
}

func TestShipThenConfirm(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	listing := catalogtest.Listing(t, e.db, seller)
	v := e.pending(t, buyer, listing)
	k := key()
	for range 2 {
		s, err := e.deals.CreateShipment(ctx, seller, v.Order.ID, k, manual(" SPXVN0123 "))
		if err != nil || s.Order.Status != domain.OrderShipped || s.Order.Shipment == nil || s.Order.ShippedAt == nil {
			t.Fatalf("ship: %+v %v", s.Order, err)
		}
		sh := s.Order.Shipment
		if sh.Mode != domain.ModeManual || sh.Carrier != domain.CarrierSPX || sh.TrackingCode != "SPXVN0123" ||
			sh.Fee == nil || *sh.Fee != 22_000 || sh.Status != domain.ShipmentPendingPickup || sh.DeliveredAt != nil {
			t.Fatalf("shipment: %+v", sh)
		}
	}
	if st, held := e.summary(t, listing); st != catalogdomain.StatusReserved || held != v.Order.ID {
		t.Fatalf("listing %s for %s", st, held)
	}
	if n := count(pgtest.EventKinds(t, e.db, listing), "listing.reserved"); n != 1 {
		t.Fatalf("listing.reserved %d times", n)
	}
	if n := countMoves(moveKinds(e.get(t, buyer, v.ID)), domain.MoveShipped); n != 1 {
		t.Fatalf("shipped %d times", n)
	}
	c, err := e.deals.ConfirmReceipt(ctx, buyer, v.Order.ID, key())
	if err != nil || c.Status != domain.StatusSold || c.Order.Status != domain.OrderCompleted || c.Order.ClosedAt == nil {
		t.Fatalf("confirm: %+v %v", c, err)
	}
	if m := c.Moves[len(c.Moves)-1]; m.Kind != domain.MoveCompleted || m.By != domain.Buyer {
		t.Fatalf("%+v", m)
	}
	if st, _ := e.summary(t, listing); st != catalogdomain.StatusSold {
		t.Fatalf("listing %s", st)
	}
}

func TestConfirmTwice(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	listing := catalogtest.Listing(t, e.db, seller)
	v := e.shipped(t, buyer, seller, listing, "SPXVN0123")
	k := key()
	for range 2 {
		c, err := e.deals.ConfirmReceipt(ctx, buyer, v.Order.ID, k)
		if err != nil || c.Order.Status != domain.OrderCompleted {
			t.Fatalf("confirm with one key: %+v %v", c.Order, err)
		}
	}
	if _, err := e.deals.ConfirmReceipt(ctx, buyer, v.Order.ID, key()); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("confirm a completed order: %v", err)
	}
	if n := count(pgtest.EventKinds(t, e.db, listing), "listing.sold"); n != 1 {
		t.Fatalf("listing.sold %d times", n)
	}
	if n := countMoves(moveKinds(e.get(t, seller, v.ID)), domain.MoveCompleted); n != 1 {
		t.Fatalf("completed %d times", n)
	}
}

func TestLinkedShipment(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	v := e.pending(t, buyer, catalogtest.Listing(t, e.db, seller))
	s, err := e.deals.CreateShipment(ctx, seller, v.Order.ID, key(), linked)
	if err != nil || s.Order.Status != domain.OrderShipped {
		t.Fatalf("%+v %v", s.Order, err)
	}
	if sh := s.Order.Shipment; sh.Mode != domain.ModeLinked || sh.Carrier != domain.CarrierGHTK ||
		!strings.HasPrefix(sh.TrackingCode, "GHTK-") || sh.Fee == nil || *sh.Fee != 22_000 || sh.Status != domain.ShipmentPendingPickup {
		t.Fatalf("%+v", sh)
	}
	if _, err = e.deals.EditShipment(ctx, seller, v.Order.ID, "spx", "SPX1"); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("edit a linked shipment: %v", err)
	}
}

func TestEditShipment(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer, stranger := e.person(t), e.person(t), e.person(t)
	v := e.shipped(t, buyer, seller, catalogtest.Listing(t, e.db, seller), "SPXVN0123")
	got, err := e.deals.EditShipment(ctx, seller, v.Order.ID, "ghn", " GHN0042 ")
	if err != nil {
		t.Fatal(err)
	}
	if sh := got.Order.Shipment; sh.Mode != domain.ModeManual || sh.Carrier != domain.CarrierGHN || sh.TrackingCode != "GHN0042" ||
		sh.Status != domain.ShipmentPendingPickup || got.Order.Status != domain.OrderShipped {
		t.Fatalf("%+v", got.Order)
	}
	if m := got.Moves[len(got.Moves)-1]; m.Kind != domain.MoveShipmentUpdated || m.By != domain.Seller {
		t.Fatalf("%+v", m)
	}
	if _, err = e.deals.EditShipment(ctx, buyer, v.Order.ID, "ghn", "GHN1"); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Errorf("the buyer edits: %v", err)
	}
	if _, err = e.deals.EditShipment(ctx, stranger, v.Order.ID, "ghn", "GHN1"); !errors.Is(err, domain.ErrOrderNotFound) {
		t.Errorf("a stranger edits: %v", err)
	}
	if _, err = e.deals.EditShipment(ctx, seller, v.Order.ID, "ghn", "NOTFOUND1"); !errors.Is(err, domain.ErrShipmentUnknown) ||
		apperr.From(err).Kind != apperr.KindInvalid {
		t.Errorf("a code the carrier does not know: %v", err)
	}
	if _, err = e.deals.EditShipment(ctx, seller, v.Order.ID, "other", "X1"); !errors.Is(err, domain.ErrInvalidShipment) {
		t.Errorf("carrier other: %v", err)
	}
	if got = e.get(t, buyer, v.ID); got.Order.Shipment.TrackingCode != "GHN0042" {
		t.Fatalf("a refused edit changed the shipment: %+v", got.Order.Shipment)
	}
}

func TestLookupShipment(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	p, err := e.deals.LookupShipment(ctx, "spx", " SPX1 ")
	if err != nil || p.Carrier != domain.CarrierSPX || p.TrackingCode != "SPX1" || p.CODAmount != 1_500_000 ||
		p.Status != domain.ShipmentPendingPickup || p.Fee == nil || p.RecipientName == "" || p.District == "" {
		t.Fatalf("%+v %v", p, err)
	}
	if _, err = e.deals.LookupShipment(ctx, "spx", "NOTFOUND"); !errors.Is(err, domain.ErrShipmentNotFound) ||
		apperr.From(err).Kind != apperr.KindNotFound {
		t.Errorf("an unknown code: %v", err)
	}
	if _, err = e.deals.LookupShipment(ctx, "other", "X1"); !errors.Is(err, domain.ErrInvalidShipment) {
		t.Errorf("carrier other: %v", err)
	}
}

func TestShipRefusesAHiddenListing(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	listing := catalogtest.Listing(t, e.db, seller)
	v := e.pending(t, buyer, listing)
	if _, err := e.catalog.Hide(ctx, seller, listing); err != nil {
		t.Fatal(err)
	}
	for _, in := range []service.ShipmentInput{manual("SPX1"), linked} {
		if _, err := e.deals.CreateShipment(ctx, seller, v.Order.ID, key(), in); !errors.Is(err, domain.ErrListingUnavailable) {
			t.Fatalf("%s: %v", in.Mode, err)
		}
	}
	if got := e.get(t, buyer, v.ID); got.Order.Status != domain.OrderPending {
		t.Fatalf("%+v", got.Order)
	}
}

// cancelFirst is a store where the buyer cancels just before the seller's
// shipment is saved, so the shipment's save conflicts.
type cancelFirst struct {
	repository.Deals

	fired *atomic.Bool
}

func (c cancelFirst) Save(ctx context.Context, d *domain.Deal, writeID uuid.UUID, evs ...events.Event) error {
	if o := d.Order(); o != nil && o.Status == domain.OrderShipped && c.fired.CompareAndSwap(false, true) {
		cur, err := c.Deals.Get(ctx, d.ID())
		if err != nil {
			return err
		}
		if err = cur.Cancel(domain.Buyer, time.Now()); err != nil {
			return err
		}
		if err = c.Deals.Save(ctx, &cur, uuid.NewV7()); err != nil {
			return err
		}
	}
	return c.Deals.Save(ctx, d, writeID, evs...)
}

func TestShipLosesToACancel(t *testing.T) {
	t.Parallel()
	for _, in := range []service.ShipmentInput{manual("SPX1"), linked} {
		e := newEnv(t)
		ctx := context.Background()
		seller, buyer := e.person(t), e.person(t)
		listing := catalogtest.Listing(t, e.db, seller)
		v := e.pending(t, buyer, listing)
		cancels := &atomic.Int32{}
		deps := e.deps
		deps.Deals = cancelFirst{Deals: e.repo, fired: &atomic.Bool{}}
		deps.Carrier = countingCarrier{cancels: cancels}
		if _, err := start(t, deps).CreateShipment(ctx, seller, v.Order.ID, key(), in); !errors.Is(err, domain.ErrChanged) {
			t.Fatalf("%s: %v", in.Mode, err)
		}
		if got := e.get(t, buyer, v.ID); got.Order.Status != domain.OrderCancelled || got.Order.CancelReason != domain.CancelByBuyer {
			t.Fatalf("%s: %+v", in.Mode, got.Order)
		}
		if st, _ := e.summary(t, listing); st != catalogdomain.StatusActive {
			t.Fatalf("%s: listing %s", in.Mode, st)
		}
		if k := pgtest.EventKinds(t, e.db, listing); count(k, "listing.reserved") != 1 || k[len(k)-1] != "listing.released" {
			t.Fatalf("%s: events %v", in.Mode, k)
		}
		// The GHTK shipment the order did not take is called off; a manual
		// one is the seller's own.
		if want := map[string]int32{"manual": 0, "linked": 1}[in.Mode]; cancels.Load() != want {
			t.Fatalf("%s: %d cancels at the carrier", in.Mode, cancels.Load())
		}
	}
}

func TestShipRefusals(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer, stranger := e.person(t), e.person(t), e.person(t)
	v := e.pending(t, buyer, catalogtest.Listing(t, e.db, seller))
	for name, c := range map[string]struct {
		caller uuid.UUID
		in     service.ShipmentInput
		want   error
	}{
		"the buyer ships":           {buyer, manual("SPX1"), domain.ErrMoveNotAllowed},
		"a stranger ships":          {stranger, manual("SPX1"), domain.ErrOrderNotFound},
		"carrier other":             {seller, service.ShipmentInput{Mode: "manual", Carrier: "other", TrackingCode: "X1"}, domain.ErrInvalidShipment},
		"a code of spaces":          {seller, manual("   "), domain.ErrInvalidShipment},
		"a code the carrier lacks":  {seller, manual("NOTFOUND-7"), domain.ErrShipmentUnknown},
		"a parcel of 0 grams":       {seller, service.ShipmentInput{Mode: "linked", Service: "standard", Pickup: "home"}, domain.ErrInvalidShipment},
		"a pickup at the door":      {seller, service.ShipmentInput{Mode: "linked", Service: "standard", WeightGrams: 800, Pickup: "door"}, domain.ErrInvalidShipment},
	} {
		if _, err := e.deals.CreateShipment(ctx, c.caller, v.Order.ID, key(), c.in); !errors.Is(err, c.want) {
			t.Errorf("%s: %v", name, err)
		}
	}
	if _, err := e.deals.ConfirmReceipt(ctx, buyer, v.Order.ID, key()); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Errorf("confirm a pending order: %v", err)
	}
	must(t)(e.deals.CreateShipment(ctx, seller, v.Order.ID, key(), manual("SPX1")))
	if _, err := e.deals.ConfirmReceipt(ctx, seller, v.Order.ID, key()); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Errorf("the seller confirms: %v", err)
	}
	if _, err := e.deals.ConfirmReceipt(ctx, stranger, v.Order.ID, key()); !errors.Is(err, domain.ErrOrderNotFound) {
		t.Errorf("a stranger confirms: %v", err)
	}
	if _, err := e.deals.CreateShipment(ctx, seller, v.Order.ID, key(), manual("SPX2")); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Errorf("ship a shipped order: %v", err)
	}
}

// shipFirst is a store where another try ships the order just before this
// one's save, as a second tap with a key of its own would.
type shipFirst struct {
	repository.Deals

	fired *atomic.Bool
}

func (c shipFirst) Save(ctx context.Context, d *domain.Deal, writeID uuid.UUID, evs ...events.Event) error {
	if o := d.Order(); o != nil && o.Status == domain.OrderShipped && c.fired.CompareAndSwap(false, true) {
		cur, err := c.Deals.Get(ctx, d.ID())
		if err != nil {
			return err
		}
		listing := domain.Listing{Price: 1_500_000, AllowOffers: true, Status: domain.ListingActive}
		if err = cur.Ship(domain.Seller, cur.Order().ID, *o.Shipment, listing, time.Now()); err != nil {
			return err
		}
		if err = c.Deals.Save(ctx, &cur, uuid.NewV7()); err != nil {
			return err
		}
	}
	return c.Deals.Save(ctx, d, writeID, evs...)
}

func TestShipTwiceKeepsTheListing(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	listing := catalogtest.Listing(t, e.db, seller)
	v := e.pending(t, buyer, listing)
	deps := e.deps
	deps.Deals = shipFirst{Deals: e.repo, fired: &atomic.Bool{}}
	s, err := start(t, deps).CreateShipment(ctx, seller, v.Order.ID, key(), manual("SPX1"))
	if err != nil || s.Order.Status != domain.OrderShipped {
		t.Fatalf("ship: %+v %v", s.Order, err)
	}
	if st, held := e.summary(t, listing); st != catalogdomain.StatusReserved || held != v.Order.ID {
		t.Fatalf("listing %s for %s", st, held)
	}
}
```

`internal/deal/service/no_carrier_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"testing"
	"uuid"

	"github.com/shopnexus/server/internal/catalog/catalogtest"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/deal/service"
	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/provider/carrier"
)

// noCarrier serves a second deal service on e's database with
// carrier.None, production's carrier.
func (e env) noCarrier(t *testing.T) *service.Deals {
	t.Helper()
	deps := e.deps
	deps.Carrier = carrier.None{}
	return start(t, deps)
}

// Without a carrier no shipment is made, read or corrected, and a linked
// one gives the listing back; the moves that need no carrier work as ever.
func TestNoCarrier(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	none := e.noCarrier(t)
	seller, buyer := e.person(t), e.person(t)
	listing := catalogtest.Listing(t, e.db, seller)
	v := e.pending(t, buyer, listing)
	unavailable := func(name string, err error) {
		t.Helper()
		if !errors.Is(err, domain.ErrCarrierUnavailable) || apperr.From(err).Kind != apperr.KindUnavailable {
			t.Errorf("%s: %v", name, err)
		}
	}
	_, err := none.LookupShipment(ctx, "spx", "SPX1")
	unavailable("a lookup", err)
	_, err = none.CreateShipment(ctx, seller, v.Order.ID, key(), manual("SPX1"))
	unavailable("a manual shipment", err)
	_, err = none.CreateShipment(ctx, seller, uuid.NewV7(), key(), manual("SPX1"))
	unavailable("a manual shipment of an unknown order", err)
	_, err = none.CreateShipment(ctx, seller, v.Order.ID, key(), linked)
	unavailable("a linked shipment", err)
	if st, held := e.summary(t, listing); st != catalogdomain.StatusActive || held != (uuid.UUID{}) {
		t.Fatalf("the linked shipment kept the listing: %s for %s", st, held)
	}
	if got := e.get(t, buyer, v.ID); got.Order.Status != domain.OrderPending {
		t.Fatalf("a refused shipment moved the order: %+v", got.Order)
	}

	// An order the fake shipped is corrected nowhere, and confirmed as ever.
	shipped := e.shipped(t, buyer, seller, catalogtest.Listing(t, e.db, seller), "SPXNONE1")
	_, err = none.EditShipment(ctx, seller, shipped.Order.ID, "ghn", "GHN1")
	unavailable("a correction", err)
	if c, confirmErr := none.ConfirmReceipt(ctx, buyer, shipped.Order.ID, key()); confirmErr != nil || c.Order.Status != domain.OrderCompleted {
		t.Fatalf("confirm: %+v %v", c.Order, confirmErr)
	}
	if c, cancelErr := none.Cancel(ctx, buyer, v.ID); cancelErr != nil || c.Order.Status != domain.OrderCancelled {
		t.Fatalf("cancel: %+v %v", c.Order, cancelErr)
	}
	must(t)(none.Accept(ctx, buyer, v.ID, 1_500_000))
	if r, codErr := none.RequestCod(ctx, buyer, v.ID, e.address(t, buyer)); codErr != nil || r.Order.Status != domain.OrderPending {
		t.Fatalf("COD: %+v %v", r.Order, codErr)
	}
}
```

In `internal/trust/service/helpers_test.go`: the deps of `dealsvc.New` gain `Carrier: carrier.Fake{}` (import `github.com/shopnexus/server/internal/provider/carrier`); the helper `requested` becomes `pending` with every call (`sed -i 's/e\.requested(/e.pending(/g' internal/trust/service/*_test.go`), its comment saying `asks for COD` as now; and `shipped` becomes:

```go
// shipped is a pending order the seller shipped under SPX1 with the fake
// carrier.
func (e env) shipped(t *testing.T, buyer, seller uuid.UUID) (deal, order uuid.UUID) {
	t.Helper()
	deal, order = e.pending(t, buyer, seller)
	if _, err := e.deals.CreateShipment(context.Background(), seller, order, uuid.NewV7().String(), dealsvc.ShipmentInput{
		Mode: "manual", Carrier: "spx", TrackingCode: "SPX1",
	}); err != nil {
		t.Fatal(err)
	}
	return deal, order
}
```

In `internal/trust/service/review_test.go`, `TestReturnedOrderIsReviewed` becomes:

```go
func TestCompletedOrderIsReviewed(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	_, order := e.shipped(t, buyer, seller)
	if _, err := e.deals.ConfirmReceipt(ctx, buyer, order, uuid.NewV7().String()); err != nil {
		t.Fatal(err)
	}
	if _, err := e.trust.PutReview(ctx, buyer, order, 5, "Đúng mô tả"); err != nil {
		t.Fatal(err)
	}
}
```

and its `"requested: %v"` message says `"pending: %v"`.

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/deal/service/ ./internal/trust/service/`
Expected: FAIL to build: `e.deals.CreateShipment undefined`, `unknown field Carrier in struct literal of type service.Deps`.

- [ ] **Step 3: The service's contract**

In `internal/deal/service/service.go`: the package comment's first sentence ends `the two sides move until they agree a price, the seller ships and the order closes, and the deals follow their listings' changes.` In `Service`, replace the comment and the three lines of `Ship`, `Deliver` and `Return` with:

```go
	// CreateShipment ships a pending order: a manual shipment, read from its
	// carrier, or a linked one, made at GHTK. It holds the listing and
	// returns the order's deal. A repeated idempotencyKey of the same caller
	// runs nothing more.
	CreateShipment(ctx context.Context, caller, order uuid.UUID, idempotencyKey string, in ShipmentInput) (DealView, error)
	// EditShipment puts the seller's corrected carrier and code, read again
	// from the carrier, on a manual shipment and returns the order's deal.
	EditShipment(ctx context.Context, caller, order uuid.UUID, carrierCode, trackingCode string) (DealView, error)
	// ConfirmReceipt completes a shipped order on its buyer's word, sells
	// the listing and returns the order's deal. A repeated idempotencyKey
	// of the same caller runs nothing more.
	ConfirmReceipt(ctx context.Context, caller, order uuid.UUID, idempotencyKey string) (DealView, error)
	// LookupShipment reads a shipment from its carrier, for the seller's
	// preview of a manual shipment.
	LookupShipment(ctx context.Context, carrierCode, trackingCode string) (ShipmentPreview, error)
```

and `OpenOrders`' comment says `that is pending or shipped`. `Deps`, `Deals`, `New` and `Durable` become (import `github.com/shopnexus/server/internal/provider/carrier`):

```go
// Deps is what New builds Deals from.
type Deps struct {
	Deals    repository.Deals
	Accounts accountsvc.Service
	Catalog  catalogsvc.Service
	// Carrier makes and reads shipments.
	Carrier carrier.Client
	// Ingress and Prefix reach this process's Restate services.
	Ingress *ingress.Client
	Prefix  string
	Now     func() time.Time
}

// Deals implements Service in this process.
type Deals struct {
	deals    repository.Deals
	accounts accountsvc.Service
	catalog  catalogsvc.Service
	carrier  carrier.Client
	prefix   string
	now      func() time.Time
	ship     restatex.Caller[FlowInput, FlowResult]
	confirm  restatex.Caller[FlowInput, FlowResult]
}

var _ Service = (*Deals)(nil)

func New(d Deps) *Deals {
	return &Deals{
		deals: d.Deals, accounts: d.Accounts, catalog: d.Catalog, carrier: d.Carrier, prefix: d.Prefix, now: d.Now,
		ship:    restatex.Caller[FlowInput, FlowResult]{Ingress: d.Ingress, Service: d.Prefix + dealShip, Handler: "Run"},
		confirm: restatex.Caller[FlowInput, FlowResult]{Ingress: d.Ingress, Service: d.Prefix + dealConfirm, Handler: "Run"},
	}
}

// Durable returns module deal's Restate services, for Mount to bind.
func (s *Deals) Durable() []restate.ServiceDefinition {
	return []restate.ServiceDefinition{
		restate.Reflect(DealShip{Deals: s}), restate.Reflect(DealConfirm{Deals: s}),
	}
}
```

In `internal/deal/service/views.go`, `OrderView`'s field `Waybill *domain.Waybill` becomes `Shipment *domain.Shipment \`json:"shipment,omitempty"\`` and `orderView` sets `Shipment: o.Shipment` instead of `Waybill: o.Waybill`.

- [ ] **Step 4: The flow's input and the order lookup**

In `internal/deal/service/order_flow.go`, replace `FlowInput` and delete `WaybillInput`:

```go
// FlowInput names the order a flow moves, its deal and the caller. A
// shipment carries either its manual shipment, read from the carrier, or
// what the seller picked for a linked one.
type FlowInput struct {
	Caller  uuid.UUID           `json:"caller"`
	DealID  uuid.UUID           `json:"deal_id"`
	OrderID uuid.UUID           `json:"order_id"`
	Manual  *domain.Shipment    `json:"manual,omitempty"`
	Linked  *domain.LinkedDraft `json:"linked,omitempty"`
}
```

Move `orderDeal` from `order_ship.go` to the end of `order_flow.go` unchanged (add `context` to that file's imports; `errors`, `fmt` and `repository` are there already), then delete `order_ship.go` and `order_finish_durable.go`:

```bash
git rm internal/deal/service/order_ship.go internal/deal/service/order_finish_durable.go
```

- [ ] **Step 5: `DealShip`**

Replace the body of `internal/deal/service/order_ship_durable.go` from the type comment down with (imports: `errors`, `fmt`, `restate`, `domain`, `apperr`, `restatex`, `carrier`):

```go
// madeShipment is what the step that makes a linked shipment journals:
// GHTK's answer, or the refusal of a stack without a carrier.
type madeShipment struct {
	Created carrier.Created `json:"created"`
	Refused *apperr.Error   `json:"refused,omitempty"`
}

// DealShip ships a pending order. A manual shipment is checked whole
// before anything is held; a linked one is made at GHTK once the listing
// is held, and a stack without a carrier gives the listing back. It gives the listing back, and calls off a GHTK shipment the
// order did not take, when the order's save loses to anything but another
// shipment of the same order. Once shipped, it cancels the listing's other
// pending orders.
type DealShip struct{ Deals *Deals }

func (s DealShip) ServiceName() string { return s.Deals.prefix + dealShip }

func (s DealShip) Run(ctx restate.Context, in FlowInput) (FlowResult, error) {
	at, err := restatex.Now(ctx, s.Deals.now)
	if err != nil {
		return FlowResult{}, err
	}
	m, err := loadStep(ctx, s.Deals, in.Caller, in.DealID)
	if err != nil || m.Refused != nil {
		return FlowResult{Refused: m.Refused}, err
	}
	d := domain.RestoreDeal(m.Deal)
	if in.Manual != nil {
		err = d.Ship(m.By, in.OrderID, *in.Manual, facts(m.Listing), at)
	} else {
		err = d.Shippable(m.By, in.OrderID, facts(m.Listing))
	}
	if err != nil {
		return FlowResult{Refused: apperr.From(err)}, nil
	}
	refused, err := reserveStep(ctx, s.Deals.catalog, m.Listing.ID, in.OrderID)
	if err != nil || refused != nil {
		return FlowResult{Refused: refused}, err
	}
	if in.Linked != nil {
		o := d.Order()
		made, createErr := restate.Run(ctx, func(rc restate.RunContext) (madeShipment, error) {
			c, stepErr := s.Deals.carrier.Create(rc, carrier.CreateInput{
				OrderID: o.ID, COD: o.Price, WeightGrams: in.Linked.WeightGrams,
				Service: string(in.Linked.Service), Pickup: string(in.Linked.Pickup),
				Recipient: carrier.Recipient{
					Name: o.Recipient.Name, Phone: o.Recipient.Phone, Street: o.Recipient.Street,
					CommuneCode: o.Recipient.CommuneCode,
				},
			})
			if errors.Is(stepErr, carrier.ErrUnavailable) {
				return madeShipment{Refused: domain.ErrCarrierUnavailable}, nil
			}
			if stepErr != nil {
				return madeShipment{}, fmt.Errorf("create: %w", stepErr)
			}
			return madeShipment{Created: c}, nil
		})
		if createErr != nil {
			return FlowResult{}, fmt.Errorf("create the shipment at GHTK: %w", createErr)
		}
		// A stack without a carrier makes no shipment: the listing goes back.
		if made.Refused != nil {
			if err = releaseStep(ctx, s.Deals.catalog, m.Listing.ID, in.OrderID); err != nil {
				return FlowResult{}, err
			}
			return FlowResult{Refused: made.Refused}, nil
		}
		created := made.Created
		// Shippable passed on this deal and listing, and a new shipment
		// waits for pickup, so Ship takes it.
		if err = d.Ship(m.By, in.OrderID, domain.Shipment{
			Mode: domain.ModeLinked, Carrier: domain.CarrierGHTK, TrackingCode: created.TrackingCode,
			Fee: &created.Fee, Status: domain.ShipmentPendingPickup,
		}, facts(m.Listing), at); err != nil {
			return FlowResult{}, fmt.Errorf("ship the order: %w", err)
		}
	}
	refused, err = saveStep(ctx, s.Deals.deals, &d, restatex.NewID(ctx, at), restatex.NewID(ctx, at), at)
	if err != nil {
		return FlowResult{}, err
	}
	if refused == nil {
		// The listing's other pending orders end with shipped_to_another.
		if err = restate.RunVoid(ctx, func(rc restate.RunContext) error {
			return s.Deals.ListingChanged(rc, m.Listing.ID)
		}); err != nil {
			return FlowResult{}, fmt.Errorf("cancel the other orders: %w", err)
		}
		return FlowResult{}, nil
	}
	// The save lost a race. Another try that shipped this order keeps the
	// listing; anything else, a cancel above all, gives it back.
	cur, err := restate.Run(ctx, func(rc restate.RunContext) (domain.Order, error) {
		got, stepErr := s.Deals.deals.Get(rc, in.DealID)
		if stepErr != nil {
			return domain.Order{}, fmt.Errorf("read the deal: %w", stepErr)
		}
		if o := got.Order(); o != nil {
			return *o, nil
		}
		return domain.Order{}, nil
	})
	if err != nil {
		return FlowResult{}, fmt.Errorf("check the order: %w", err)
	}
	mine := d.Order().Shipment
	shipped := cur.ID == in.OrderID && cur.Status == domain.OrderShipped
	if mine.Mode == domain.ModeLinked && (!shipped || cur.Shipment == nil || cur.Shipment.TrackingCode != mine.TrackingCode) {
		if err = restate.RunVoid(ctx, func(rc restate.RunContext) error {
			return s.Deals.carrier.Cancel(rc, carrier.Carrier(mine.Carrier), mine.TrackingCode)
		}); err != nil {
			return FlowResult{}, fmt.Errorf("call off the shipment at GHTK: %w", err)
		}
	}
	if shipped {
		return FlowResult{}, nil
	}
	if err = releaseStep(ctx, s.Deals.catalog, m.Listing.ID, in.OrderID); err != nil {
		return FlowResult{}, err
	}
	return FlowResult{Refused: refused}, nil
}
```

- [ ] **Step 6: `DealConfirm`**

`internal/deal/service/order_confirm_durable.go`:

```go
package service

import (
	restate "github.com/restatedev/sdk-go"

	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/platform/restatex"
)

// dealConfirm is the DealConfirm service's name without the prefix.
const dealConfirm = "DealConfirm"

// DealConfirm completes a shipped order on its buyer's word and marks the
// listing sold. Restate retries the listing step until it is done.
type DealConfirm struct{ Deals *Deals }

func (s DealConfirm) ServiceName() string { return s.Deals.prefix + dealConfirm }

func (s DealConfirm) Run(ctx restate.Context, in FlowInput) (FlowResult, error) {
	at, err := restatex.Now(ctx, s.Deals.now)
	if err != nil {
		return FlowResult{}, err
	}
	m, err := loadStep(ctx, s.Deals, in.Caller, in.DealID)
	if err != nil || m.Refused != nil {
		return FlowResult{Refused: m.Refused}, err
	}
	d := domain.RestoreDeal(m.Deal)
	if err = d.ConfirmReceipt(m.By, in.OrderID, at); err != nil {
		return FlowResult{Refused: apperr.From(err)}, nil
	}
	refused, err := saveStep(ctx, s.Deals.deals, &d, restatex.NewID(ctx, at), restatex.NewID(ctx, at), at)
	if err != nil || refused != nil {
		return FlowResult{Refused: refused}, err
	}
	return FlowResult{}, sellStep(ctx, s.Deals.catalog, m.Listing.ID, in.OrderID)
}
```

- [ ] **Step 7: The four use cases**

`internal/deal/service/order_shipment_create.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"uuid"

	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/provider/carrier"
)

// ShipmentInput is a shipment as the seller sends it: Mode manual with the
// carrier and the code, or linked with the service, the weight and the
// pickup.
type ShipmentInput struct {
	Mode         string
	Carrier      string
	TrackingCode string
	Service      string
	WeightGrams  int
	Pickup       string
}

// CreateShipment checks the shipment and reads a manual one from its
// carrier, then finds the caller's order, runs DealShip once per caller and
// idempotencyKey, and reads the order's deal. A code the carrier does not
// know is domain.ErrShipmentUnknown; a stack without a carrier is
// domain.ErrCarrierUnavailable, for any order.
func (s *Deals) CreateShipment(ctx context.Context, caller, order uuid.UUID, idempotencyKey string, in ShipmentInput) (DealView, error) {
	flow := FlowInput{Caller: caller, OrderID: order}
	if in.Mode == string(domain.ModeLinked) {
		linked, draftErr := domain.NewLinkedDraft(in.Service, in.WeightGrams, in.Pickup)
		if draftErr != nil {
			return DealView{}, draftErr
		}
		flow.Linked = &linked
	} else {
		c, code, trackErr := domain.Tracking(in.Carrier, in.TrackingCode)
		if trackErr != nil {
			return DealView{}, trackErr
		}
		p, readErr := s.carrier.Lookup(ctx, carrier.Carrier(c), code)
		switch {
		case errors.Is(readErr, carrier.ErrNotFound):
			return DealView{}, domain.ErrShipmentUnknown
		case errors.Is(readErr, carrier.ErrUnavailable):
			return DealView{}, domain.ErrCarrierUnavailable
		case readErr != nil:
			return DealView{}, fmt.Errorf("read the shipment from %s: %w", c, readErr)
		}
		flow.Manual = &domain.Shipment{
			Mode: domain.ModeManual, Carrier: c, TrackingCode: code, Fee: p.Fee, Status: domain.ShipmentStatus(p.Status),
		}
	}
	deal, err := s.orderDeal(ctx, caller, order)
	if err != nil {
		return DealView{}, err
	}
	flow.DealID = deal
	if _, err = s.ship.Call(ctx, caller.String()+"/"+idempotencyKey, flow); err != nil {
		return DealView{}, err
	}
	return s.Get(ctx, caller, deal)
}
```

`internal/deal/service/order_shipment_edit.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"uuid"

	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/provider/carrier"
)

// EditShipment checks the corrected carrier and code and reads them from
// the carrier, then finds the caller's order and puts them on its manual
// shipment. A code the carrier does not know is domain.ErrShipmentUnknown;
// a stack without a carrier is domain.ErrCarrierUnavailable, for any
// order; a deal the other side moved meanwhile is domain.ErrChanged.
func (s *Deals) EditShipment(ctx context.Context, caller, order uuid.UUID, carrierCode, trackingCode string) (DealView, error) {
	c, code, err := domain.Tracking(carrierCode, trackingCode)
	if err != nil {
		return DealView{}, err
	}
	p, err := s.carrier.Lookup(ctx, carrier.Carrier(c), code)
	switch {
	case errors.Is(err, carrier.ErrNotFound):
		return DealView{}, domain.ErrShipmentUnknown
	case errors.Is(err, carrier.ErrUnavailable):
		return DealView{}, domain.ErrCarrierUnavailable
	case err != nil:
		return DealView{}, fmt.Errorf("read the shipment from %s: %w", c, err)
	}
	deal, err := s.orderDeal(ctx, caller, order)
	if err != nil {
		return DealView{}, err
	}
	m, err := s.load(ctx, caller, deal, false)
	if err != nil {
		return DealView{}, err
	}
	if err = m.deal.EditShipment(m.by, order, domain.Shipment{
		Mode: domain.ModeManual, Carrier: c, TrackingCode: code, Fee: p.Fee, Status: domain.ShipmentStatus(p.Status),
	}, m.now); err != nil {
		return DealView{}, err
	}
	return s.save(ctx, caller, m)
}
```

`internal/deal/service/order_confirm.go`:

```go
package service

import (
	"context"
	"uuid"
)

// ConfirmReceipt finds the caller's order, runs DealConfirm on it once per
// caller and idempotencyKey, then reads the order's deal.
func (s *Deals) ConfirmReceipt(ctx context.Context, caller, order uuid.UUID, idempotencyKey string) (DealView, error) {
	deal, err := s.orderDeal(ctx, caller, order)
	if err != nil {
		return DealView{}, err
	}
	in := FlowInput{Caller: caller, DealID: deal, OrderID: order}
	if _, err = s.confirm.Call(ctx, caller.String()+"/"+idempotencyKey, in); err != nil {
		return DealView{}, err
	}
	return s.Get(ctx, caller, deal)
}
```

`internal/deal/service/shipment_lookup.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"

	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/provider/carrier"
)

// ShipmentPreview is the ShipmentPreview schema in api/schemas/deal.yaml.
type ShipmentPreview struct {
	Carrier       domain.Carrier        `json:"carrier"`
	TrackingCode  string                `json:"tracking_code"`
	RecipientName string                `json:"recipient_name"`
	District      string                `json:"district"`
	CODAmount     int64                 `json:"cod_amount"`
	Status        domain.ShipmentStatus `json:"status"`
	Fee           *int64                `json:"fee,omitempty"`
}

// LookupShipment checks the carrier and the code and reads the shipment
// from the carrier. A code the carrier does not know is
// domain.ErrShipmentNotFound; a stack without a carrier is
// domain.ErrCarrierUnavailable.
func (s *Deals) LookupShipment(ctx context.Context, carrierCode, trackingCode string) (ShipmentPreview, error) {
	c, code, err := domain.Tracking(carrierCode, trackingCode)
	if err != nil {
		return ShipmentPreview{}, err
	}
	p, err := s.carrier.Lookup(ctx, carrier.Carrier(c), code)
	switch {
	case errors.Is(err, carrier.ErrNotFound):
		return ShipmentPreview{}, domain.ErrShipmentNotFound
	case errors.Is(err, carrier.ErrUnavailable):
		return ShipmentPreview{}, domain.ErrCarrierUnavailable
	case err != nil:
		return ShipmentPreview{}, fmt.Errorf("read the shipment from %s: %w", c, err)
	}
	return ShipmentPreview{
		Carrier: c, TrackingCode: code, RecipientName: p.RecipientName, District: p.District, CODAmount: p.COD,
		Status: domain.ShipmentStatus(p.Status), Fee: p.Fee,
	}, nil
}
```

- [ ] **Step 8: Trust and notification read the shipment**

In `internal/trust/service/review.go`:

```go
// reviewable are the order statuses a review may be given in: the parcel
// went to the carrier.
var reviewable = []dealdomain.OrderStatus{dealdomain.OrderShipped, dealdomain.OrderCompleted, dealdomain.OrderFailed}
```

In `internal/notification/worker/worker.go`, inside `DealMoved`'s step, the waybill block becomes:

```go
		if o := facts.Order; o != nil {
			out.CancelReason = string(o.CancelReason)
			if o.Shipment != nil {
				out.Carrier, out.TrackingCode = string(o.Shipment.Carrier), o.Shipment.TrackingCode
			}
		}
```

- [ ] **Step 9: Run the tests and the linter**

Run: `golangci-lint fmt ./internal/deal/service/ ./internal/trust/... ./internal/notification/... && go test ./internal/deal/domain/ ./internal/deal/repository/ ./internal/deal/service/ ./internal/deal/worker/ ./internal/trust/... ./internal/notification/... ./internal/erasure/... ./internal/screen/... > tmp/task5.log 2>&1; tail -30 tmp/task5.log`
Expected: every package `ok`. Then `golangci-lint run ./internal/deal/domain/ ./internal/deal/repository/ ./internal/deal/service/ ./internal/deal/worker/ ./internal/trust/... ./internal/notification/...`: `0 issues.` (`internal/deal/handler`, `internal/app` and `e2e` still do not build.)

- [ ] **Step 10: Commit**

```bash
git add -A internal/deal/service internal/trust internal/notification/worker
git commit -m "feat(deal): sellers create shipments, buyers confirm receipt"
```

### Task 6: The system moves orders on

The three waits and the carrier's reports. Every system flow here reads the deal, decides between steps, saves, and reads again when its save loses a race.

**Files:**
- Create: `internal/deal/service/order_timers_durable.go`, `shipment_updated_durable.go`, `shipment_updated.go`
- Modify: `internal/deal/service/service.go`, `order_flow.go`, `order_request.go`, `order_ship_durable.go`, `order_shipment_edit.go`
- Test: `internal/deal/service/helpers_test.go`, `order_timers_test.go`, `shipment_updated_test.go`, `flow_test.go`
- Test: `internal/trust/service/helpers_test.go`, `internal/trust/service/review_test.go`

**Interfaces:**
- Consumes: Task 5's `DealShip`, `EditShipment`, `RequestCod`, `loadStep`'s `loaded`, `saveStep`, `releaseStep`, `sellStep`.
- Produces: `service.Deps.Waits`; `service.OrderRef`; `OrderTimers` with `SellerTimeout`, `PickupTimeout`, `AutoComplete`; `ShipmentSignal`, `ShipmentResult`, `ShipmentUpdates.Run`; `Service.ShipmentUpdated(ctx, trackingCode, status string) error`; `systemLoadStep`; test helper `e.timed(t, w domain.Waits, c carrier.Client) (*service.Deals, func(handler string, ref service.OrderRef))`.

- [ ] **Step 1: Write the failing tests**

In `internal/deal/service/helpers_test.go`, `newEnv`'s deps gain `Waits: domain.OrderWaits`:

```go
	deps := service.Deps{
		Deals: repo, Accounts: accounts, Catalog: c, Carrier: carrier.Fake{}, Waits: domain.OrderWaits, Ingress: in, Now: time.Now,
	}
```

`internal/deal/service/order_timers_test.go`:

```go
package service_test

import (
	"context"
	"fmt"
	"sync/atomic"
	"testing"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"
	"github.com/restatedev/sdk-go/ingress"

	"github.com/shopnexus/server/internal/catalog/catalogtest"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/deal/service"
	"github.com/shopnexus/server/internal/platform/restatex/restatetest"
	"github.com/shopnexus/server/internal/platform/testenv"
	"github.com/shopnexus/server/internal/provider/carrier"
)

// timed serves a second deal service on e's database with the waits w and
// the carrier c, and returns it with fire, which runs one of its
// OrderTimers handlers now, as Restate does when a wait ends.
func (e env) timed(t *testing.T, w domain.Waits, c carrier.Client) (*service.Deals, func(handler string, ref service.OrderRef)) {
	t.Helper()
	deps := e.deps
	deps.Waits, deps.Carrier, deps.Prefix = w, c, restatetest.Prefix()
	d := service.New(deps)
	in := restatetest.Start(t, d.Durable()...)
	return d, func(handler string, ref service.OrderRef) {
		t.Helper()
		if _, err := ingress.Service[service.OrderRef, restate.Void](in, deps.Prefix+"OrderTimers", handler).
			Request(context.Background(), ref); err != nil {
			t.Fatalf("%s: %v", handler, err)
		}
	}
}

// soon is domain.OrderWaits changed by set, for a test that waits for
// one timer.
func soon(set func(*domain.Waits)) domain.Waits {
	w := domain.OrderWaits
	set(&w)
	return w
}

// deliveredCarrier is the fake carrier reading every parcel delivered, as
// a carrier does for a code the seller typed after the parcel arrived.
type deliveredCarrier struct{ carrier.Fake }

func (deliveredCarrier) Lookup(ctx context.Context, c carrier.Carrier, code string) (carrier.Parcel, error) {
	p, err := carrier.Fake{}.Lookup(ctx, c, code)
	p.Status = carrier.StatusDelivered
	return p, err
}

// until reads deal id as viewer until its order has status.
func (e env) until(t *testing.T, viewer, id uuid.UUID, status domain.OrderStatus) service.DealView {
	t.Helper()
	var v service.DealView
	testenv.Eventually(t, 15*time.Second, func() error {
		if v = e.get(t, viewer, id); v.Order.Status != status {
			return fmt.Errorf("order %s, want %s", v.Order.Status, status)
		}
		return nil
	})
	return v
}

func TestSellerTimeoutCancels(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	deals, _ := e.timed(t, soon(func(w *domain.Waits) { w.Seller = time.Second }), carrier.Fake{})
	seller, buyer := e.person(t), e.person(t)
	v := e.agreed(t, buyer, catalogtest.Listing(t, e.db, seller))
	if _, err := deals.RequestCod(context.Background(), buyer, v.ID, e.address(t, buyer)); err != nil {
		t.Fatal(err)
	}
	got := e.until(t, seller, v.ID, domain.OrderCancelled)
	if got.Order.CancelledBy != domain.System || got.Order.CancelReason != domain.CancelSellerTimeout ||
		got.Status != domain.StatusNegotiating || got.AgreedPrice != nil {
		t.Fatalf("%+v", got)
	}
}

func TestPickupTimeoutCancels(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	cancels := &atomic.Int32{}
	deals, _ := e.timed(t, soon(func(w *domain.Waits) { w.Pickup = time.Second }), countingCarrier{cancels: cancels})
	seller, buyer := e.person(t), e.person(t)
	listing := catalogtest.Listing(t, e.db, seller)
	v := e.pending(t, buyer, listing)
	if _, err := deals.CreateShipment(context.Background(), seller, v.Order.ID, key(), linked); err != nil {
		t.Fatal(err)
	}
	got := e.until(t, buyer, v.ID, domain.OrderCancelled)
	if got.Order.CancelledBy != domain.System || got.Order.CancelReason != domain.CancelPickupTimeout ||
		got.Order.Shipment == nil || got.Order.Shipment.Mode != domain.ModeLinked || got.Status != domain.StatusNegotiating {
		t.Fatalf("%+v", got)
	}
	testenv.Eventually(t, 15*time.Second, func() error {
		if st, _ := e.summary(t, listing); st != catalogdomain.StatusActive {
			return fmt.Errorf("listing %s", st)
		}
		return nil
	})
	if cancels.Load() != 1 {
		t.Fatalf("%d cancels at GHTK", cancels.Load())
	}
}

func TestAutoCompletes(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	deals, _ := e.timed(t, soon(func(w *domain.Waits) { w.Complete = time.Second }), carrier.Fake{})
	seller, buyer := e.person(t), e.person(t)
	listing := catalogtest.Listing(t, e.db, seller)
	v := e.pending(t, buyer, listing)
	if _, err := deals.CreateShipment(ctx, seller, v.Order.ID, key(), manual("SPXAUTO1")); err != nil {
		t.Fatal(err)
	}
	if err := deals.ShipmentUpdated(ctx, "SPXAUTO1", "delivered"); err != nil {
		t.Fatal(err)
	}
	if got := e.get(t, buyer, v.ID); got.Order.Status != domain.OrderShipped || got.Order.Shipment.Status != domain.ShipmentDelivered ||
		got.Order.Shipment.DeliveredAt == nil {
		t.Fatalf("delivered: %+v", got.Order)
	}
	got := e.until(t, seller, v.ID, domain.OrderCompleted)
	if m := got.Moves[len(got.Moves)-1]; m.Kind != domain.MoveCompleted || m.By != domain.System || got.Status != domain.StatusSold {
		t.Fatalf("%+v %s", m, got.Status)
	}
	testenv.Eventually(t, 15*time.Second, func() error {
		if st, _ := e.summary(t, listing); st != catalogdomain.StatusSold {
			return fmt.Errorf("listing %s", st)
		}
		return nil
	})
}

func TestShipADeliveredParcelCompletes(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	deals, _ := e.timed(t, soon(func(w *domain.Waits) { w.Complete = time.Second }), deliveredCarrier{})
	seller, buyer := e.person(t), e.person(t)
	v := e.pending(t, buyer, catalogtest.Listing(t, e.db, seller))
	s, err := deals.CreateShipment(context.Background(), seller, v.Order.ID, key(), manual("SPXLATE1"))
	if err != nil || s.Order.Shipment.Status != domain.ShipmentDelivered || s.Order.Shipment.DeliveredAt == nil {
		t.Fatalf("%+v %v", s.Order, err)
	}
	e.until(t, buyer, v.ID, domain.OrderCompleted)
}

func TestTimersLeaveAnOrderThatMovedOn(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	deals, fire := e.timed(t, domain.OrderWaits, carrier.Fake{})
	seller, buyer := e.person(t), e.person(t)
	ref := func(v service.DealView) service.OrderRef { return service.OrderRef{DealID: v.ID, OrderID: v.Order.ID} }
	unchanged := func(name string, v service.DealView) {
		t.Helper()
		got := e.get(t, buyer, v.ID)
		if got.Order.ID != v.Order.ID || got.Order.Status != v.Order.Status || len(got.Moves) != len(v.Moves) {
			t.Errorf("%s moved: %+v", name, got.Order)
		}
	}

	shipped := e.shipped(t, buyer, seller, catalogtest.Listing(t, e.db, seller), "SPXMOVED1")
	fire("SellerTimeout", ref(shipped))
	fire("AutoComplete", ref(shipped))
	unchanged("a shipment waiting for pickup", shipped)

	if err := deals.ShipmentUpdated(ctx, "SPXMOVED1", "in_transit"); err != nil {
		t.Fatal(err)
	}
	transit := e.get(t, buyer, shipped.ID)
	fire("PickupTimeout", ref(transit))
	fire("AutoComplete", ref(transit))
	unchanged("a parcel in transit", transit)

	if err := deals.ShipmentUpdated(ctx, "SPXMOVED1", "delivered"); err != nil {
		t.Fatal(err)
	}
	must(t)(e.deals.ConfirmReceipt(ctx, buyer, shipped.Order.ID, key()))
	confirmed := e.get(t, buyer, shipped.ID)
	fire("AutoComplete", ref(confirmed))
	fire("PickupTimeout", ref(confirmed))
	unchanged("a confirmed order", confirmed)

	// The deal's first order was cancelled and the buyer asked again: the
	// first order's timer leaves the second alone, and the second's own
	// timer cancels it.
	first := e.pending(t, buyer, catalogtest.Listing(t, e.db, seller))
	must(t)(e.deals.Cancel(ctx, buyer, first.ID))
	must(t)(e.deals.Accept(ctx, buyer, first.ID, 1_500_000))
	second, err := e.deals.RequestCod(ctx, buyer, first.ID, e.address(t, buyer))
	if err != nil {
		t.Fatal(err)
	}
	fire("SellerTimeout", ref(first))
	unchanged("an order asked for again", second)
	fire("SellerTimeout", ref(second))
	if got := e.get(t, buyer, second.ID); got.Order.Status != domain.OrderCancelled || got.Order.CancelReason != domain.CancelSellerTimeout {
		t.Fatalf("the second order's own timer: %+v", got.Order)
	}
}

// Production runs without a carrier (CARRIER=none): the timers and the
// carrier's entry point need none.
func TestTimersWorkWithoutACarrier(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	deals, _ := e.timed(t, soon(func(w *domain.Waits) { w.Seller = time.Second }), carrier.None{})
	seller, buyer := e.person(t), e.person(t)
	v := e.agreed(t, buyer, catalogtest.Listing(t, e.db, seller))
	if _, err := deals.RequestCod(ctx, buyer, v.ID, e.address(t, buyer)); err != nil {
		t.Fatal(err)
	}
	if got := e.until(t, buyer, v.ID, domain.OrderCancelled); got.Order.CancelReason != domain.CancelSellerTimeout {
		t.Fatalf("%+v", got.Order)
	}
	shipped := e.shipped(t, buyer, seller, catalogtest.Listing(t, e.db, seller), "SPXNONE2")
	if err := deals.ShipmentUpdated(ctx, "SPXNONE2", "failed"); err != nil {
		t.Fatal(err)
	}
	if got := e.get(t, buyer, shipped.ID); got.Order.Status != domain.OrderFailed {
		t.Fatalf("%+v", got.Order)
	}
}

func TestNewRefusesAZeroWait(t *testing.T) {
	t.Parallel()
	defer func() {
		if recover() == nil {
			t.Fatal("New took a zero wait")
		}
	}()
	service.New(service.Deps{Waits: domain.Waits{Seller: time.Hour, Complete: time.Hour}})
}
```


`internal/deal/service/shipment_updated_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server/internal/catalog/catalogtest"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/deal/repository"
	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/platform/events"
)

func TestShipmentUpdated(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	listing := catalogtest.Listing(t, e.db, seller)
	v := e.shipped(t, buyer, seller, listing, "SPXREPORT1")

	if err := e.deals.ShipmentUpdated(ctx, "SPXREPORT1", "in_transit"); err != nil {
		t.Fatal(err)
	}
	got := e.get(t, buyer, v.ID)
	if got.Order.Shipment.Status != domain.ShipmentInTransit || got.Order.Status != domain.OrderShipped {
		t.Fatalf("in transit: %+v", got.Order)
	}
	if m := got.Moves[len(got.Moves)-1]; m.Kind != domain.MoveShipmentUpdated || m.By != domain.System {
		t.Fatalf("%+v", m)
	}
	if err := e.deals.ShipmentUpdated(ctx, "SPXREPORT1", "in_transit"); err != nil {
		t.Fatal(err)
	}
	if n := countMoves(moveKinds(e.get(t, buyer, v.ID)), domain.MoveShipmentUpdated); n != 1 {
		t.Fatalf("the same report twice made %d moves", n)
	}

	if err := e.deals.ShipmentUpdated(ctx, "SPXREPORT1", "failed"); err != nil {
		t.Fatal(err)
	}
	got = e.get(t, buyer, v.ID)
	if got.Order.Status != domain.OrderFailed || got.Order.ClosedAt == nil || got.Status != domain.StatusNegotiating ||
		got.AgreedPrice != nil || got.Moves[len(got.Moves)-1].Kind != domain.MoveFailed {
		t.Fatalf("failed: %+v", got)
	}
	if st, held := e.summary(t, listing); st != catalogdomain.StatusActive || held != (uuid.UUID{}) {
		t.Fatalf("listing %s for %s", st, held)
	}
	moves := len(got.Moves)
	if err := e.deals.ShipmentUpdated(ctx, "SPXREPORT1", "delivered"); err != nil {
		t.Fatalf("a late report: %v", err)
	}
	if got = e.get(t, buyer, v.ID); got.Order.Status != domain.OrderFailed || len(got.Moves) != moves {
		t.Fatalf("a late report moved the order: %+v", got.Order)
	}

	err := e.deals.ShipmentUpdated(ctx, "SPXNOBODY", "delivered")
	if !errors.Is(err, domain.ErrShipmentNotFound) || apperr.From(err).Kind != apperr.KindNotFound {
		t.Fatalf("an unknown code: %v", err)
	}
	if err = e.deals.ShipmentUpdated(ctx, "SPXREPORT1", "returned"); !errors.Is(err, domain.ErrInvalidStatus) {
		t.Fatalf("an unknown status: %v", err)
	}
	// Mua lại: the buyer agrees again and asks for COD on the same deal.
	must(t)(e.deals.Accept(ctx, buyer, v.ID, 1_500_000))
	again, err := e.deals.RequestCod(ctx, buyer, v.ID, e.address(t, buyer))
	if err != nil || again.Order.Status != domain.OrderPending || again.Order.ID == v.Order.ID {
		t.Fatalf("buy again: %+v %v", again.Order, err)
	}
}

func TestOneParcelTwoOrders(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	first, second := catalogtest.Listing(t, e.db, seller), catalogtest.Listing(t, e.db, seller)
	a := e.shipped(t, buyer, seller, first, "SPXPARCEL1")
	b := e.shipped(t, buyer, seller, second, "SPXPARCEL1")
	if err := e.deals.ShipmentUpdated(ctx, "SPXPARCEL1", "failed"); err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct {
		deal    uuid.UUID
		listing uuid.UUID
	}{{a.ID, first}, {b.ID, second}} {
		if got := e.get(t, buyer, c.deal); got.Order.Status != domain.OrderFailed {
			t.Errorf("%s: %+v", c.deal, got.Order)
		}
		if st, _ := e.summary(t, c.listing); st != catalogdomain.StatusActive {
			t.Errorf("listing %s", st)
		}
	}
}

// confirmFirst is a store where the buyer confirms receipt just before the
// system saves a carrier's report, so the report's save conflicts.
type confirmFirst struct {
	repository.Deals

	fired *atomic.Bool
}

func (c confirmFirst) Save(ctx context.Context, d *domain.Deal, writeID uuid.UUID, evs ...events.Event) error {
	if o := d.Order(); o != nil && o.Status == domain.OrderShipped && o.Shipment.Status == domain.ShipmentInTransit &&
		c.fired.CompareAndSwap(false, true) {
		cur, err := c.Deals.Get(ctx, d.ID())
		if err != nil {
			return err
		}
		if err = cur.ConfirmReceipt(domain.Buyer, cur.Order().ID, time.Now()); err != nil {
			return err
		}
		if err = c.Deals.Save(ctx, &cur, uuid.NewV7()); err != nil {
			return err
		}
	}
	return c.Deals.Save(ctx, d, writeID, evs...)
}

func TestShipmentUpdateLosesToAConfirm(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	seller, buyer := e.person(t), e.person(t)
	v := e.shipped(t, buyer, seller, catalogtest.Listing(t, e.db, seller), "SPXRACE1")
	deps := e.deps
	deps.Deals = confirmFirst{Deals: e.repo, fired: &atomic.Bool{}}
	if err := start(t, deps).ShipmentUpdated(context.Background(), "SPXRACE1", "in_transit"); err != nil {
		t.Fatalf("the report: %v", err)
	}
	got := e.get(t, buyer, v.ID)
	if got.Order.Status != domain.OrderCompleted || got.Order.Shipment.Status != domain.ShipmentPendingPickup ||
		countMoves(moveKinds(got), domain.MoveShipmentUpdated) != 0 {
		t.Fatalf("%+v", got.Order)
	}
}
```

In `internal/deal/service/flow_test.go`, add:

```go
func TestConfirmRefusesAFailedOrder(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	listing := catalogtest.Listing(t, e.db, seller)
	first := e.shipped(t, buyer, seller, listing, "SPXFIRST1")
	if err := e.deals.ShipmentUpdated(ctx, "SPXFIRST1", "failed"); err != nil {
		t.Fatal(err)
	}
	must(t)(e.deals.Accept(ctx, buyer, first.ID, 1_500_000))
	second, err := e.deals.RequestCod(ctx, buyer, first.ID, e.address(t, buyer))
	if err != nil || second.Order.ID == first.Order.ID {
		t.Fatalf("second order: %+v %v", second.Order, err)
	}
	must(t)(e.deals.CreateShipment(ctx, seller, second.Order.ID, key(), manual("SPXSECOND1")))
	if _, err = e.deals.ConfirmReceipt(ctx, buyer, first.Order.ID, key()); !errors.Is(err, domain.ErrMoveNotAllowed) {
		t.Fatalf("confirm the failed order: %v", err)
	}
	if v := e.get(t, buyer, first.ID); v.Order.ID != second.Order.ID || v.Order.Status != domain.OrderShipped || v.Status != domain.StatusAgreed {
		t.Fatalf("the second order moved: %+v %s", v.Order, v.Status)
	}
	if st, held := e.summary(t, listing); st != catalogdomain.StatusReserved || held != second.Order.ID {
		t.Fatalf("listing %s for %s", st, held)
	}
}
```

In `internal/trust/service/helpers_test.go`, the deps of `dealsvc.New` gain `Waits: dealdomain.OrderWaits` (import `dealdomain "github.com/shopnexus/server/internal/deal/domain"`). In `internal/trust/service/review_test.go`, add:

```go
func TestFailedOrderIsReviewed(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	_, order := e.shipped(t, buyer, seller)
	if err := e.deals.ShipmentUpdated(ctx, "SPX1", "failed"); err != nil {
		t.Fatal(err)
	}
	if _, err := e.trust.PutReview(ctx, buyer, order, 1, "Không đúng mô tả"); err != nil {
		t.Fatal(err)
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/deal/service/ ./internal/trust/service/`
Expected: FAIL to build: `unknown field Waits in struct literal of type service.Deps`, `e.deals.ShipmentUpdated undefined`, `undefined: service.OrderRef`.

- [ ] **Step 3: The service's waits and the new entry point**

In `internal/deal/service/service.go`, `Service` gains after `LookupShipment`:

```go
	// ShipmentUpdated sets the status of every shipped order whose
	// shipment has trackingCode, as its carrier reports it. A closed order
	// changes nothing; no order with the code is domain.ErrShipmentNotFound.
	ShipmentUpdated(ctx context.Context, trackingCode, status string) error
```

`Deps` gains after `Carrier`:

```go
	// Waits are how long the system waits before it moves an order on:
	// domain.OrderWaits outside tests. New refuses a zero wait.
	Waits domain.Waits
```

`Deals`, `New` and `Durable` become:

```go
// Deals implements Service in this process.
type Deals struct {
	deals    repository.Deals
	accounts accountsvc.Service
	catalog  catalogsvc.Service
	carrier  carrier.Client
	waits    domain.Waits
	ingress  *ingress.Client
	prefix   string
	now      func() time.Time
	ship     restatex.Caller[FlowInput, FlowResult]
	confirm  restatex.Caller[FlowInput, FlowResult]
	shipment restatex.Caller[ShipmentSignal, ShipmentResult]
}

var _ Service = (*Deals)(nil)

// New builds Deals. A zero wait would move every order on the moment it
// is made, so New panics on one.
func New(d Deps) *Deals {
	if d.Waits.Seller <= 0 || d.Waits.Pickup <= 0 || d.Waits.Complete <= 0 {
		panic("deal: Deps.Waits needs every wait; pass domain.OrderWaits")
	}
	return &Deals{
		deals: d.Deals, accounts: d.Accounts, catalog: d.Catalog, carrier: d.Carrier, waits: d.Waits, ingress: d.Ingress,
		prefix: d.Prefix, now: d.Now,
		ship:    restatex.Caller[FlowInput, FlowResult]{Ingress: d.Ingress, Service: d.Prefix + dealShip, Handler: "Run"},
		confirm: restatex.Caller[FlowInput, FlowResult]{Ingress: d.Ingress, Service: d.Prefix + dealConfirm, Handler: "Run"},
		shipment: restatex.Caller[ShipmentSignal, ShipmentResult]{
			Ingress: d.Ingress, Service: d.Prefix + shipmentUpdates, Handler: "Run",
		},
	}
}

// Durable returns module deal's Restate services, for Mount to bind.
func (s *Deals) Durable() []restate.ServiceDefinition {
	return []restate.ServiceDefinition{
		restate.Reflect(DealShip{Deals: s}), restate.Reflect(DealConfirm{Deals: s}),
		restate.Reflect(OrderTimers{Deals: s}), restate.Reflect(ShipmentUpdates{Deals: s}),
	}
}
```

- [ ] **Step 4: The system's load step**

Add to `internal/deal/service/order_flow.go`:

```go
// systemLoadStep reads a deal and its listing for a move of the system's
// in one journaled step.
func systemLoadStep(ctx restate.Context, s *Deals, id uuid.UUID) (loaded, error) {
	out, err := restate.Run(ctx, func(rc restate.RunContext) (loaded, error) {
		d, stepErr := s.deals.Get(rc, id)
		if stepErr != nil {
			return loaded{}, fmt.Errorf("get deal: %w", stepErr)
		}
		l, stepErr := s.listing(rc, d.ListingID())
		if stepErr != nil {
			return loaded{}, stepErr
		}
		return loaded{Deal: d.State(), By: domain.System, Listing: l}, nil
	})
	if err != nil {
		return loaded{}, fmt.Errorf("load the deal: %w", err)
	}
	return out, nil
}
```

- [ ] **Step 5: `OrderTimers`**

`internal/deal/service/order_timers_durable.go`:

```go
package service

import (
	"fmt"
	"uuid"

	restate "github.com/restatedev/sdk-go"

	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/platform/restatex"
	"github.com/shopnexus/server/internal/provider/carrier"
)

// orderTimers is the OrderTimers service's name without the prefix.
const orderTimers = "OrderTimers"

// OrderRef names the order a timer is for and its deal. Restate keeps it
// as the timer's input for the whole wait, so its JSON stays the same
// across releases.
type OrderRef struct {
	DealID  uuid.UUID `json:"deal_id"`
	OrderID uuid.UUID `json:"order_id"`
}

// OrderTimers moves an order on once a wait ends. Each handler is called
// by a send with a delay: it reads the deal when it fires, does nothing
// when the order moved on, and never compares clocks. A save that loses a
// race reads the deal again.
type OrderTimers struct{ Deals *Deals }

func (s OrderTimers) ServiceName() string { return s.Deals.prefix + orderTimers }

// SellerTimeout cancels a pending order whose seller made no shipment
// within Waits.Seller. A pending order holds no listing.
func (s OrderTimers) SellerTimeout(ctx restate.Context, ref OrderRef) error {
	at, err := restatex.Now(ctx, s.Deals.now)
	if err != nil {
		return err
	}
	for {
		m, loadErr := systemLoadStep(ctx, s.Deals, ref.DealID)
		if loadErr != nil {
			return loadErr
		}
		d := domain.RestoreDeal(m.Deal)
		if d.SellerTimeout(ref.OrderID, at) != nil {
			return nil // the order moved on
		}
		refused, saveErr := saveStep(ctx, s.Deals.deals, &d, restatex.NewID(ctx, at), restatex.NewID(ctx, at), at)
		if saveErr != nil {
			return saveErr
		}
		if refused == nil {
			return nil
		}
	}
}

// PickupTimeout cancels a shipped order whose parcel the carrier had not
// picked up Waits.Pickup after the shipment, calls a linked shipment off at
// GHTK and gives the listing back.
func (s OrderTimers) PickupTimeout(ctx restate.Context, ref OrderRef) error {
	at, err := restatex.Now(ctx, s.Deals.now)
	if err != nil {
		return err
	}
	for {
		m, loadErr := systemLoadStep(ctx, s.Deals, ref.DealID)
		if loadErr != nil {
			return loadErr
		}
		d := domain.RestoreDeal(m.Deal)
		if d.PickupTimeout(ref.OrderID, at) != nil {
			return nil // the order moved on
		}
		refused, saveErr := saveStep(ctx, s.Deals.deals, &d, restatex.NewID(ctx, at), restatex.NewID(ctx, at), at)
		if saveErr != nil {
			return saveErr
		}
		if refused != nil {
			continue
		}
		if sh := d.Order().Shipment; sh.Mode == domain.ModeLinked {
			if err = restate.RunVoid(ctx, func(rc restate.RunContext) error {
				return s.Deals.carrier.Cancel(rc, carrier.Carrier(sh.Carrier), sh.TrackingCode)
			}); err != nil {
				return fmt.Errorf("call off the shipment at GHTK: %w", err)
			}
		}
		return releaseStep(ctx, s.Deals.catalog, m.Listing.ID, ref.OrderID)
	}
}

// AutoComplete completes a shipped order Waits.Complete after its carrier
// reported the parcel delivered, unless the buyer confirmed first, and
// marks the listing sold.
func (s OrderTimers) AutoComplete(ctx restate.Context, ref OrderRef) error {
	at, err := restatex.Now(ctx, s.Deals.now)
	if err != nil {
		return err
	}
	for {
		m, loadErr := systemLoadStep(ctx, s.Deals, ref.DealID)
		if loadErr != nil {
			return loadErr
		}
		d := domain.RestoreDeal(m.Deal)
		if d.AutoComplete(ref.OrderID, at) != nil {
			return nil // the order moved on
		}
		refused, saveErr := saveStep(ctx, s.Deals.deals, &d, restatex.NewID(ctx, at), restatex.NewID(ctx, at), at)
		if saveErr != nil {
			return saveErr
		}
		if refused == nil {
			return sellStep(ctx, s.Deals.catalog, m.Listing.ID, ref.OrderID)
		}
	}
}
```

- [ ] **Step 6: `ShipmentUpdates` and its use case**

`internal/deal/service/shipment_updated_durable.go`:

```go
package service

import (
	"fmt"

	restate "github.com/restatedev/sdk-go"

	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/platform/restatex"
)

// shipmentUpdates is the ShipmentUpdates service's name without the prefix.
const shipmentUpdates = "ShipmentUpdates"

// ShipmentSignal is a carrier's word on a shipment: its tracking code and
// its new status.
type ShipmentSignal struct {
	TrackingCode string                `json:"tracking_code"`
	Status       domain.ShipmentStatus `json:"status"`
}

// ShipmentResult carries ShipmentUpdates' refusal, or none.
type ShipmentResult struct {
	Refused *apperr.Error `json:"refused,omitempty"`
}

func (r ShipmentResult) Refusal() *apperr.Error { return r.Refused }

// ShipmentUpdates is the one entry point of a carrier's word on a
// shipment: the dev endpoint calls it, and the carriers' webhooks and
// polling will. It moves every shipped order whose shipment has the code,
// two items in one parcel included, and changes nothing on a closed order.
// A failure releases the listing; a delivery schedules the completion.
type ShipmentUpdates struct{ Deals *Deals }

func (s ShipmentUpdates) ServiceName() string { return s.Deals.prefix + shipmentUpdates }

func (s ShipmentUpdates) Run(ctx restate.Context, in ShipmentSignal) (ShipmentResult, error) {
	at, err := restatex.Now(ctx, s.Deals.now)
	if err != nil {
		return ShipmentResult{}, err
	}
	refs, err := restate.Run(ctx, func(rc restate.RunContext) ([]OrderRef, error) {
		rows, stepErr := s.Deals.deals.OrdersWithCode(rc, in.TrackingCode)
		if stepErr != nil {
			return nil, fmt.Errorf("find the orders: %w", stepErr)
		}
		out := make([]OrderRef, 0, len(rows))
		for _, r := range rows {
			out = append(out, OrderRef{DealID: r.DealID, OrderID: r.Order.ID})
		}
		return out, nil
	})
	if err != nil {
		return ShipmentResult{}, fmt.Errorf("find the shipment's orders: %w", err)
	}
	if len(refs) == 0 {
		return ShipmentResult{Refused: domain.ErrShipmentNotFound}, nil
	}
	for _, ref := range refs {
		for {
			m, loadErr := systemLoadStep(ctx, s.Deals, ref.DealID)
			if loadErr != nil {
				return ShipmentResult{}, loadErr
			}
			d := domain.RestoreDeal(m.Deal)
			changed, moveErr := d.ShipmentUpdated(ref.OrderID, in.Status, at)
			if moveErr != nil || !changed {
				break // a closed order, or nothing new
			}
			refused, saveErr := saveStep(ctx, s.Deals.deals, &d, restatex.NewID(ctx, at), restatex.NewID(ctx, at), at)
			if saveErr != nil {
				return ShipmentResult{}, saveErr
			}
			if refused != nil {
				continue // the deal moved meanwhile: read it again
			}
			if d.Order().Status == domain.OrderFailed {
				if err = releaseStep(ctx, s.Deals.catalog, m.Listing.ID, ref.OrderID); err != nil {
					return ShipmentResult{}, err
				}
			} else if in.Status == domain.ShipmentDelivered {
				restate.ServiceSend(ctx, s.Deals.prefix+orderTimers, "AutoComplete").
					Send(ref, restate.WithDelay(s.Deals.waits.Complete))
			}
			break
		}
	}
	return ShipmentResult{}, nil
}
```

`internal/deal/service/shipment_updated.go`:

```go
package service

import (
	"context"
	"uuid"

	"github.com/shopnexus/server/internal/deal/domain"
)

// ShipmentUpdated checks status and runs ShipmentUpdates for trackingCode.
// A report is not idempotent, so each call takes a key of its own; the same
// status twice changes nothing the second time.
func (s *Deals) ShipmentUpdated(ctx context.Context, trackingCode, status string) error {
	st, err := domain.ParseShipmentStatus(status)
	if err != nil {
		return err
	}
	in := ShipmentSignal{TrackingCode: trackingCode, Status: st}
	if _, err = s.shipment.Call(ctx, uuid.NewV7().String(), in); err != nil {
		return err
	}
	return nil
}
```

- [ ] **Step 7: The sends of the seller's timeout, the pickup timeout and the completion**

In `internal/deal/service/order_request.go` (imports `restate "github.com/restatedev/sdk-go"` and `"github.com/restatedev/sdk-go/ingress"`), between the domain move and `return s.save(ctx, caller, m)`:

```go
	// The timer goes before the save: one that finds no pending order, as
	// after a refused save, does nothing.
	ref := OrderRef{DealID: id, OrderID: m.deal.Order().ID}
	if _, err = ingress.ServiceSend[OrderRef](s.ingress, s.prefix+orderTimers, "SellerTimeout").
		Send(ctx, ref, restate.WithDelay(s.waits.Seller), restate.WithIdempotencyKey(ref.OrderID.String())); err != nil {
		return DealView{}, fmt.Errorf("schedule the seller's timeout: %w", err)
	}
```

and its comment gains `It schedules the order's seller timeout first, so it needs Restate.`

In `internal/deal/service/order_ship_durable.go`, in the branch `if refused == nil {`, between the `ListingChanged` step and `return FlowResult{}, nil`:

```go
		ref := OrderRef{DealID: in.DealID, OrderID: in.OrderID}
		restate.ServiceSend(ctx, s.Deals.prefix+orderTimers, "PickupTimeout").
			Send(ref, restate.WithDelay(s.Deals.waits.Pickup))
		if d.Order().Shipment.Status == domain.ShipmentDelivered {
			restate.ServiceSend(ctx, s.Deals.prefix+orderTimers, "AutoComplete").
				Send(ref, restate.WithDelay(s.Deals.waits.Complete))
		}
```

and the type comment gains the sentence `It schedules the pickup timeout, and the completion of a parcel already delivered.`

In `internal/deal/service/order_shipment_edit.go` (same two imports), between the `EditShipment` move and `return s.save(ctx, caller, m)`:

```go
	if m.deal.Order().Shipment.Status == domain.ShipmentDelivered {
		// The completion goes before the save; one that finds the parcel
		// not delivered, as after a refused save, does nothing.
		if _, err = ingress.ServiceSend[OrderRef](s.ingress, s.prefix+orderTimers, "AutoComplete").
			Send(ctx, OrderRef{DealID: deal, OrderID: order}, restate.WithDelay(s.waits.Complete)); err != nil {
			return DealView{}, fmt.Errorf("schedule the completion: %w", err)
		}
	}
```

- [ ] **Step 8: Run the tests and the linter**

Run: `golangci-lint fmt ./internal/deal/service/ ./internal/trust/... && go test ./internal/deal/service/ ./internal/deal/worker/ ./internal/trust/... ./internal/notification/... ./internal/erasure/... ./internal/screen/... > tmp/task6.log 2>&1; tail -30 tmp/task6.log`
Expected: every package `ok`; the timer tests take a few seconds each. Then `golangci-lint run ./internal/deal/service/ ./internal/trust/...`: `0 issues.`

- [ ] **Step 9: Commit**

```bash
git add internal/deal/service internal/trust/service
git commit -m "feat(deal): timeouts, auto-complete and the carrier's reports"
```

### Task 7: Notices of the new moves

**Files:**
- Modify: `internal/notification/domain/notice.go`, `internal/notification/worker/worker.go` (comment only)
- Test: `internal/notification/domain/notice_test.go`

**Interfaces:**
- Consumes: the move kinds `completed`, `failed`, `shipment_updated` and the cancel reasons of Task 3, as strings (`domain.Move.Kind`, `DealFacts.CancelReason`).
- Produces: `domain.TypeCompleted = "completed"`, `domain.TypeFailed = "failed"`; `TypeDelivered` and `TypeReturned` go. Migration 0040 (Task 4) already renamed the stored notices.

Who hears what: the buyer's confirmation tells the seller; the system's completion tells the buyer and asks for a review, as the seller's "delivered" did; a failed delivery tells both sides; a carrier's status report tells no one (the buyer sees "Chờ giao hàng" whatever it says); the two timeouts tell the buyer, as every system move does.

- [ ] **Step 1: Write the failing tests**

In `internal/notification/domain/notice_test.go`, `TestFromMoves`' cases from `"delivered"` to `"sent to another"` become:

```go
		"completed by the buyer":      {domain.Move{Kind: "completed", By: "buyer"}, "", seller, domain.TypeCompleted},
		"completed by the system":     {domain.Move{Kind: "completed", By: "system"}, "", buyer, domain.TypeCompleted},
		"the buyer cancels an order":  {domain.Move{Kind: "order_cancelled", By: "buyer"}, "buyer", seller, domain.TypeOrderCancelled},
		"the seller cancels an order": {domain.Move{Kind: "order_cancelled", By: "seller"}, "seller", buyer, domain.TypeOrderCancelled},
		"shipped to another":          {domain.Move{Kind: "order_cancelled", By: "system"}, "shipped_to_another", buyer, domain.TypeOrderCancelled},
		"the seller's timeout":        {domain.Move{Kind: "order_cancelled", By: "system"}, "seller_timeout", buyer, domain.TypeOrderCancelled},
		"the pickup timeout":          {domain.Move{Kind: "order_cancelled", By: "system"}, "pickup_timeout", buyer, domain.TypeOrderCancelled},
```

and after the loop, before the withdrawal check:

```go
	failed := domain.FromMoves(facts(domain.Move{Kind: "failed", By: "system"}), at)
	if len(failed) != 2 || failed[0].Recipient != seller || failed[1].Recipient != buyer ||
		failed[0].Type != domain.TypeFailed || failed[1].Type != domain.TypeFailed {
		t.Errorf("a failed delivery: %+v", failed)
	}
	if got := domain.FromMoves(facts(domain.Move{Kind: "shipment_updated", By: "system"}), at); len(got) != 0 {
		t.Errorf("a carrier's report notifies: %+v", got)
	}
```

In `TestText`, the message `"an offer stores the waybill: %+v"` becomes `"an offer stores the shipment: %+v"`, and add before the map:

```go
	cancelled := func(reason string) domain.Notice {
		f := facts(domain.Move{Kind: "order_cancelled", By: "system"})
		f.CancelReason = reason
		return domain.FromMoves(f, at)[0]
	}
```

and to the map:

```go
		"Đức Huy đã nhận Xe đạp Asama": domain.FromMoves(facts(domain.Move{Kind: "completed", By: "buyer"}), at)[0],
		"Xe đạp Asama đã giao. Đánh giá Hoàng Nam": domain.FromMoves(
			facts(domain.Move{Kind: "completed", By: "system"}), at)[0],
		"Xe đạp Asama giao không thành":                         domain.FromMoves(facts(domain.Move{Kind: "failed", By: "system"}), at)[0],
		"Xe đạp Asama đã gửi cho người khác, đơn của bạn đã huỷ": cancelled("shipped_to_another"),
		"Người bán chưa gửi Xe đạp Asama, đơn của bạn đã huỷ":    cancelled("seller_timeout"),
		"Hãng vận chuyển chưa lấy Xe đạp Asama, đơn đã huỷ":      cancelled("pickup_timeout"),
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/notification/domain/`
Expected: FAIL to build: `undefined: domain.TypeCompleted`.

- [ ] **Step 3: The types and texts**

In `internal/notification/domain/notice.go`: the constants `TypeDelivered` and `TypeReturned` become

```go
	TypeCompleted          Type = "completed"
	TypeFailed             Type = "failed"
```

`Params.Carrier`'s comment becomes `// Carrier is a carrier code (a notice from before 2026-11-12 may hold the name a seller typed for another carrier, which reads as itself); Code is the tracking code.` and `DealFacts`' comment on `Carrier, TrackingCode` becomes `// Carrier and TrackingCode are the latest order's shipment.`

In `FromMoves`, the cases from `case "delivered":` to `case "returned":` and their bodies become:

```go
		case "completed":
			// The buyer's confirmation tells the seller; the system's
			// completion asks the buyer for a review.
			t = TypeCompleted
			if m.By == "system" {
				p.Seller = f.SellerName
			}
		case "failed":
			// A failed delivery tells the seller too: the parcel comes back.
			t = TypeFailed
			out = append(out, Notice{Recipient: f.SellerID, Type: t, CollapseKey: "deal:" + f.DealID.String(), Params: p, At: at})
```

In `types`, the entries `TypeDelivered`, `TypeReturned` and `TypeOrderCancelled` become:

```go
	TypeCompleted: {orders, func(p Params) string {
		if p.Seller != "" {
			return p.Title + " đã giao. Đánh giá " + p.Seller
		}
		return p.Actor + " đã nhận " + p.Title
	}},
	TypeFailed: {orders, func(p Params) string { return p.Title + " giao không thành" }},
	TypeOrderCancelled: {orders, func(p Params) string {
		switch p.Reason {
		case "shipped_to_another":
			return p.Title + " đã gửi cho người khác, đơn của bạn đã huỷ"
		case "listing_closed":
			return p.Title + " không còn bán, đơn của bạn đã huỷ"
		case "seller_timeout":
			return "Người bán chưa gửi " + p.Title + ", đơn của bạn đã huỷ"
		case "pickup_timeout":
			return "Hãng vận chuyển chưa lấy " + p.Title + ", đơn đã huỷ"
		default:
			return p.Actor + " huỷ đơn " + p.Title
		}
	}},
```

The comment above `carrierLabels` becomes `// carrierLabels name the carriers by their codes; an older notice may store a label, which reads as itself.`

- [ ] **Step 4: Run the tests and the linter**

Run: `golangci-lint fmt ./internal/notification/... && go test ./internal/notification/... && golangci-lint run ./internal/notification/...`
Expected: `ok` for each package, then `0 issues.`

- [ ] **Step 5: Commit**

```bash
git add internal/notification
git commit -m "feat(notification): notices of completed and failed orders"
```

### Task 8: The endpoints, `CARRIER` and the dev endpoint

This task brings the whole server back to green: `go build ./...`, the route test and e2e.

**Files:**
- Modify: `internal/platform/config/config.go`, `internal/platform/config/config_test.go`, `.env.example`
- Modify: `internal/deal/handler/handler.go`, `internal/deal/handler/order.go`, `internal/deal/deal.go`, `internal/app/app.go`
- Create: `internal/deal/handler/shipment.go`
- Test: `internal/app/app_test.go`, `e2e/main_test.go`, `e2e/system_test.go`, `e2e/order_test.go` (rewritten whole), `e2e/no_carrier_test.go`, `e2e/deal_test.go`, `e2e/review_test.go`, `e2e/erasure_test.go`

**Interfaces:**
- Consumes: Task 1's operations; Task 6's `Service`; `carrier.Fake` and `carrier.None` (Task 2).
- Produces: `config.Config.Carrier`; `deal.Settings{Carrier carrier.Client; FakeCarrier bool}`; `(*Handler).Register(r, protect, fakeCarrier bool)`; handlers `CreateShipment`, `EditShipment`, `ConfirmReceipt`, `LookupShipment`, `SetShipmentStatus`; e2e helpers `pendingOrder`, `shippedOrder`, `trackingCode`, `shipmentBody`, `linkedBody`, `editShipment`, `setShipmentStatus`, and `serverConfig`.

- [ ] **Step 1: Write the failing config and app tests**

In `internal/platform/config/config_test.go`: `required()` gains `"CARRIER": "fake",`; `TestLoadAllSet`'s `want` gains `Carrier: "fake",`; add:

```go
func TestLoadCarrier(t *testing.T) {
	t.Parallel()
	env := required()
	env["CARRIER"] = "ghtk"
	if _, err := Load(lookup(env)); err == nil || !strings.Contains(err.Error(), "CARRIER") {
		t.Fatalf("a carrier with no client yet: %v", err)
	}
	env["CARRIER"] = "none"
	if cfg, err := Load(lookup(env)); err != nil || cfg.Carrier != "none" {
		t.Fatalf("no carrier: %q %v", cfg.Carrier, err)
	}
}
```

In `internal/app/app_test.go`, `testConfig` gains `Carrier: "fake",` and add:

```go
func TestNewRefusesAnUnknownCarrier(t *testing.T) {
	t.Parallel()
	cfg := testConfig(t)
	cfg.Carrier = "pigeon"
	if _, err := New(context.Background(), cfg, discard()); err == nil || !strings.Contains(err.Error(), "CARRIER") {
		t.Fatalf("err %v", err)
	}
}

// With the fake carrier anyone may move shipments through the dev
// endpoint, so production refuses it.
func TestNewRefusesTheFakeCarrierInProd(t *testing.T) {
	t.Parallel()
	cfg := testConfig(t)
	cfg.Env, cfg.Email.Sender, cfg.Email.ResendAPIKey = "prod", "resend", "re_test"
	_, err := New(context.Background(), cfg, discard(), WithPushSender(quietPush{}))
	if err == nil || !strings.Contains(err.Error(), "CARRIER") {
		t.Fatalf("err %v", err)
	}
}

// Without a carrier the dev endpoint is not served; the shipment routes are.
func TestNoCarrierServesNoDevEndpoint(t *testing.T) {
	t.Parallel()
	cfg := testConfig(t)
	cfg.Carrier = "none"
	a, err := New(context.Background(), cfg, discard())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { a.Close(context.Background()) })
	routes := a.Routes()
	if slices.Contains(routes, httpx.Route{Method: "POST", Path: "/v1/dev/shipments/{code}/status"}) ||
		!slices.Contains(routes, httpx.Route{Method: "GET", Path: "/v1/shipments/lookup"}) {
		t.Fatalf("routes %v", routes)
	}
}
```

(`app_test.go` imports `slices` and `github.com/shopnexus/server/internal/platform/httpx` for it.)

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/platform/config/`
Expected: FAIL to build: `unknown field Carrier in struct literal of type Config`.

- [ ] **Step 3: `CARRIER`**

In `internal/platform/config/config.go`, `Config` gains after `Google GoogleConfig`:

```go
	// Carrier is CARRIER, where shipments are made and read. fake (dev and
	// test) knows every tracking code but those that start with NOTFOUND,
	// and with it the server serves the dev endpoint that moves its
	// shipments; APP_ENV=prod refuses it. none (production until a real
	// carrier comes) makes and reads no shipment.
	Carrier string
```

and `Load`'s `cfg` gains `Carrier: oneOf("CARRIER", "fake", "none"),` after `Google`.

In `.env.example`, after `TRUST_CALL_TIMEOUT=20s`:

```
# Where shipments are made and read (module deal; see ARCHITECTURE.md,
# Deal): fake or none. fake knows every tracking code but those that start
# with NOTFOUND, and with it the server serves
# POST /v1/dev/shipments/{code}/status, which moves its shipments.
# none makes and reads no shipment; production runs it, and APP_ENV=prod
# refuses fake.
CARRIER=fake
```

Run: `make env && go test ./internal/platform/config/`
Expected: `.env` gains `CARRIER=fake`; `ok`.

- [ ] **Step 4: The handlers**

`internal/deal/handler/order.go` keeps `codRequest`, `RequestCod` and `ListOrders`; replace `shipRequest`, `finishRequest`, `Ship`, `Deliver` and `Return` with:

```go
// shipmentRequest is ShipmentDraft: the request validator lets through
// the fields of one mode only.
type shipmentRequest struct {
	OrderID        uuid.UUID `json:"-"                 path:"order_id"`
	IdempotencyKey string    `header:"Idempotency-Key" json:"-"`
	Mode           string    `json:"mode"`
	Carrier        string    `json:"carrier"`
	TrackingCode   string    `json:"tracking_code"`
	Service        string    `json:"service"`
	WeightGrams    int       `json:"weight_grams"`
	Pickup         string    `json:"pickup"`
}

type trackingRequest struct {
	OrderID      uuid.UUID `json:"-"             path:"order_id"`
	Carrier      string    `json:"carrier"`
	TrackingCode string    `json:"tracking_code"`
}

type confirmRequest struct {
	OrderID        uuid.UUID `json:"-"                 path:"order_id"`
	IdempotencyKey string    `header:"Idempotency-Key" json:"-"`
}

// CreateShipment serves POST /v1/orders/{order_id}/shipment.
func (h *Handler) CreateShipment(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in shipmentRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	v, err := h.svc.CreateShipment(r.Context(), p.AccountID, in.OrderID, in.IdempotencyKey, service.ShipmentInput{
		Mode: in.Mode, Carrier: in.Carrier, TrackingCode: in.TrackingCode,
		Service: in.Service, WeightGrams: in.WeightGrams, Pickup: in.Pickup,
	})
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, v)
}

// EditShipment serves PUT /v1/orders/{order_id}/shipment.
func (h *Handler) EditShipment(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in trackingRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	v, err := h.svc.EditShipment(r.Context(), p.AccountID, in.OrderID, in.Carrier, in.TrackingCode)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, v)
}

// ConfirmReceipt serves POST /v1/orders/{order_id}/confirm.
func (h *Handler) ConfirmReceipt(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in confirmRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	v, err := h.svc.ConfirmReceipt(r.Context(), p.AccountID, in.OrderID, in.IdempotencyKey)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, v)
}
```

`internal/deal/handler/shipment.go`:

```go
package handler

import (
	"net/http"

	"github.com/shopnexus/server/internal/platform/httpx"
)

type lookupRequest struct {
	Carrier string `json:"-" query:"carrier"`
	Code    string `json:"-" query:"code"`
}

type shipmentStatusRequest struct {
	Code   string `json:"-"      path:"code"`
	Status string `json:"status"`
}

// LookupShipment serves GET /v1/shipments/lookup.
func (h *Handler) LookupShipment(w http.ResponseWriter, r *http.Request) {
	if _, ok := httpx.Caller(w, r, h.log); !ok {
		return
	}
	var in lookupRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	v, err := h.svc.LookupShipment(r.Context(), in.Carrier, in.Code)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, v)
}

// SetShipmentStatus serves POST /v1/dev/shipments/{code}/status, which
// Register adds only for the fake carrier.
func (h *Handler) SetShipmentStatus(w http.ResponseWriter, r *http.Request) {
	var in shipmentStatusRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.ShipmentUpdated(r.Context(), in.Code, in.Status); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

In `internal/deal/handler/handler.go`, `Register` becomes:

```go
// Register adds the deal endpoints, all behind protect. With the fake
// carrier it also adds the dev endpoint that moves the fake's shipments,
// open to anyone.
func (h *Handler) Register(r *httpx.Router, protect func(http.Handler) http.Handler, fakeCarrier bool) {
	r.Handle("POST /v1/deals", protect(http.HandlerFunc(h.Open)))
	r.Handle("GET /v1/deals/{id}", protect(http.HandlerFunc(h.Get)))
	r.Handle("POST /v1/deals/{id}/offer", protect(http.HandlerFunc(h.Offer)))
	r.Handle("POST /v1/deals/{id}/accept", protect(http.HandlerFunc(h.Accept)))
	r.Handle("POST /v1/deals/{id}/decline", protect(http.HandlerFunc(h.Decline)))
	r.Handle("POST /v1/deals/{id}/withdraw", protect(http.HandlerFunc(h.Withdraw)))
	r.Handle("POST /v1/deals/{id}/cancel", protect(http.HandlerFunc(h.Cancel)))
	r.Handle("GET /v1/me/deals", protect(http.HandlerFunc(h.ListMine)))
	r.Handle("POST /v1/deals/{id}/cod", protect(http.HandlerFunc(h.RequestCod)))
	r.Handle("POST /v1/orders/{order_id}/shipment", protect(http.HandlerFunc(h.CreateShipment)))
	r.Handle("PUT /v1/orders/{order_id}/shipment", protect(http.HandlerFunc(h.EditShipment)))
	r.Handle("POST /v1/orders/{order_id}/confirm", protect(http.HandlerFunc(h.ConfirmReceipt)))
	r.Handle("GET /v1/me/orders", protect(http.HandlerFunc(h.ListOrders)))
	r.Handle("GET /v1/shipments/lookup", protect(http.HandlerFunc(h.LookupShipment)))
	if fakeCarrier {
		r.Handle("POST /v1/dev/shipments/{code}/status", http.HandlerFunc(h.SetShipmentStatus))
	}
}
```

- [ ] **Step 5: The wiring**

`internal/deal/deal.go` becomes (imports gain `"github.com/shopnexus/server/internal/deal/domain"` and `"github.com/shopnexus/server/internal/provider/carrier"`):

```go
// Settings is what deal needs beyond the shared dependencies: the carrier
// shipments are made and read at, and whether it is the fake, whose
// shipments the dev endpoint moves.
type Settings struct {
	Carrier     carrier.Client
	FakeCarrier bool
}

// Mount registers the deal endpoints, subscribes the listing watch to the
// listing events and the account watch to account.deleted, and returns
// deal's Restate services and the Service other modules read deals
// through.
func Mount(d module.Deps, s Settings, accounts accountsvc.Service, catalog catalogsvc.Service) module.Mounted[service.Service] {
	svc := service.New(service.Deps{
		Deals: repository.NewDeals(d.Pool), Accounts: accounts, Catalog: catalog, Carrier: s.Carrier,
		Waits: domain.OrderWaits, Ingress: d.Ingress, Prefix: d.ServicePrefix, Now: d.Now,
	})
	handler.New(svc, d.Log).Register(d.Router, d.Protect, s.FakeCarrier)
	watch := worker.ListingWatch{Prefix: d.ServicePrefix, Deals: svc}
	for _, k := range []events.Kind{events.ListingUpdated, events.ListingHidden, events.ListingSold, events.ListingDeleted} {
		d.Events.Subscribe(k, watch.ServiceName(), "Changed")
	}
	accountWatch := worker.AccountWatch{Prefix: d.ServicePrefix, Deals: svc}
	d.Events.Subscribe(events.AccountDeleted, accountWatch.ServiceName(), "Deleted")
	return module.Mounted[service.Service]{
		Services: append(svc.Durable(), restate.Reflect(watch), restate.Reflect(accountWatch)), Service: svc,
	}
}
```

In `internal/app/app.go` (import `"github.com/shopnexus/server/internal/provider/carrier"`), after the mailer's `switch` in `New`:

```go
	var shipper carrier.Client
	switch {
	case cfg.Carrier == "fake" && cfg.Env == config.EnvProd:
		return nil, errors.New("APP_ENV=prod with CARRIER=fake; anyone could move shipments through the dev endpoint")
	case cfg.Carrier == "fake":
		shipper = carrier.Fake{}
	case cfg.Carrier == "none":
		shipper = carrier.None{}
	default:
		return nil, fmt.Errorf("CARRIER=%q: want fake or none", cfg.Carrier)
	}
```

`mountModules` takes `shipper carrier.Client` after `mailer email.Sender` (and the call in `New` passes it), and its deal line becomes:

```go
	dealm := deal.Mount(d, deal.Settings{Carrier: shipper, FakeCarrier: cfg.Carrier == "fake"}, accounts, catalogm.Service)
```

Run: `go build ./... && go test ./internal/app/ ./internal/platform/config/`
Expected: builds; `ok` twice, `TestRoutesMatchSpec`, `TestNewRefusesAnUnknownCarrier`, `TestNewRefusesTheFakeCarrierInProd` and `TestNoCarrierServesNoDevEndpoint` included.

- [ ] **Step 6: e2e**

In `e2e/main_test.go`, `cfg` gains `Carrier: "fake",` after `Google`, the `var` block gains `serverConfig config.Config // the shared server's configuration, for a test that starts a second server`, and `setup` sets `serverConfig = cfg` right after building `cfg`. In `e2e/system_test.go`, `TestReadyzDown`'s hand-built `cfg` gains `Carrier: "fake",` (app.New now refuses an empty one).

`e2e/no_carrier_test.go`:

```go
package e2e

import (
	"context"
	"net/http/httptest"
	"testing"
	"uuid"

	"github.com/shopnexus/server/internal/app"
	consoledomain "github.com/shopnexus/server/internal/console/domain"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server/internal/platform/restatex/restatetest"
)

// A stack without a carrier, as production runs, answers 503
// carrier_unavailable on the lookup and on both shipment endpoints, for any
// order. The second server has a database of its own, so its event bus
// drains no one else's events; the shared server's access token holds there,
// since both sign with the same keys.
func TestNoCarrier(t *testing.T) {
	t.Parallel()
	cfg := serverConfig
	cfg.DatabaseURL, cfg.Restate, cfg.Carrier = pgtest.New(t).Config().ConnString(), restatetest.Config(t), "none"
	a, err := app.New(context.Background(), cfg, discard,
		app.WithPushSender(phones), app.WithEmailSender(mails), app.WithPasswordHasher(consoledomain.Fast))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = a.Close(context.Background()) })
	srv := httptest.NewServer(a.Handler)
	t.Cleanup(srv.Close)
	me, _ := newAccount(t)
	auth, order := bearer(me.AccessToken), uuid.NewV7().String()
	check(t, "a lookup", callAt(t, srv.URL, "GET", "/v1/shipments/lookup?carrier=spx&code=SPX1", nil, auth),
		503, "carrier_unavailable")
	check(t, "a shipment", callAt(t, srv.URL, "POST", "/v1/orders/"+order+"/shipment", shipmentBody("SPX1"), auth, newKey()),
		503, "carrier_unavailable")
	check(t, "a correction", callAt(t, srv.URL, "PUT", "/v1/orders/"+order+"/shipment",
		map[string]any{"carrier": "spx", "tracking_code": "SPX1"}, auth), 503, "carrier_unavailable")
}
``` In `e2e/deal_test.go`, `dealView.Order` gains:

```go
		Shipment *struct {
			Mode         string `json:"mode"`
			Carrier      string `json:"carrier"`
			TrackingCode string `json:"tracking_code"`
			Fee          *int64 `json:"fee"`
			Status       string `json:"status"`
			DeliveredAt  string `json:"delivered_at"`
		} `json:"shipment"`
```

In `e2e/review_test.go`, `e2e/erasure_test.go` and wherever else it appears: `requestedOrder(` becomes `pendingOrder(` (`grep -rln requestedOrder e2e | xargs sed -i 's/requestedOrder(/pendingOrder(/g'`).

Replace `e2e/order_test.go` with:

```go
package e2e

import (
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server/internal/platform/testenv"
)

// codBody asks for COD to address.
func codBody(address string) map[string]any { return map[string]any{"address_id": address} }

// trackingCode is an SPX code no other test ships under: the e2e tests
// share one database, and a carrier's report moves every order with its
// code.
func trackingCode() string { return "SPX" + strings.ReplaceAll(uuid.NewV7().String(), "-", "") }

// shipmentBody is a manual SPX shipment under code.
func shipmentBody(code string) map[string]any {
	return map[string]any{"mode": "manual", "carrier": "spx", "tracking_code": code}
}

var linkedBody = map[string]any{"mode": "linked", "service": "standard", "weight_grams": 800, "pickup": "home"}

// shipmentPreview is the ShipmentPreview schema.
type shipmentPreview struct {
	Carrier       string `json:"carrier"`
	TrackingCode  string `json:"tracking_code"`
	RecipientName string `json:"recipient_name"`
	District      string `json:"district"`
	CODAmount     int64  `json:"cod_amount"`
	Status        string `json:"status"`
	Fee           *int64 `json:"fee"`
}

// pendingOrder opens buyer's deal on listing, agrees the listed price and
// asks for COD to buyer's default address.
func pendingOrder(t *testing.T, buyer, listing string) dealView {
	t.Helper()
	d := openDeal(t, buyer, listing, http.StatusCreated)
	moved(t, buyer, d.ID, "accept", map[string]any{"price": 1_500_000})
	return moved(t, buyer, d.ID, "cod", codBody(deliveryAddress(t, buyer)))
}

// orderCall posts to /v1/orders/{id}/{action} as token, signed out when it
// is empty, with the fresh Idempotency-Key the order steps need.
func orderCall(t *testing.T, token, id, action string, body any) Response {
	t.Helper()
	return call(t, "POST", "/v1/orders/"+id+"/"+action, body, bearer(token), newKey())
}

// orderMoved posts an order step that must succeed and returns the deal.
func orderMoved(t *testing.T, token, id, action string, body any) dealView {
	t.Helper()
	return expect[dealView](t, orderCall(t, token, id, action, body), http.StatusOK)
}

// shippedOrder is pendingOrder shipped by the seller with token under a
// fresh code.
func shippedOrder(t *testing.T, seller, buyer, listing string) dealView {
	t.Helper()
	return orderMoved(t, seller, pendingOrder(t, buyer, listing).Order.ID, "shipment", shipmentBody(trackingCode()))
}

// editShipment puts a corrected carrier and code on order id as token.
func editShipment(t *testing.T, token, id string, body any) Response {
	t.Helper()
	return call(t, "PUT", "/v1/orders/"+id+"/shipment", body, bearer(token))
}

// setShipmentStatus reports status for code through the fake carrier's
// dev endpoint, as its carrier would.
func setShipmentStatus(t *testing.T, code, status string) Response {
	t.Helper()
	return call(t, "POST", "/v1/dev/shipments/"+code+"/status", map[string]any{"status": status})
}

func listingStatus(t *testing.T, token, id string) string {
	t.Helper()
	return expect[listing](t, call(t, "GET", "/v1/listings/"+id, nil, bearer(token)), http.StatusOK).Status
}

func TestOrderShipConfirm(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	one, _ := newAccount(t)
	two, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	first := pendingOrder(t, one.AccessToken, l.ID)
	second := pendingOrder(t, two.AccessToken, l.ID)
	if first.Order == nil || first.Order.Status != "pending" || first.Order.Code == "" || first.Order.Shipment != nil {
		t.Fatalf("%+v", first.Order)
	}

	code := trackingCode()
	shipped := orderMoved(t, seller.AccessToken, first.Order.ID, "shipment", shipmentBody(" "+code+" "))
	if sh := shipped.Order.Shipment; shipped.Order.Status != "shipped" || sh == nil || sh.Mode != "manual" || sh.Carrier != "spx" ||
		sh.TrackingCode != code || sh.Status != "pending_pickup" || sh.Fee == nil || *sh.Fee != 22_000 {
		t.Fatalf("ship: %+v", shipped.Order)
	}
	if st := listingStatus(t, "", l.ID); st != "reserved" {
		t.Fatalf("a stranger reads the listing: %s", st)
	}
	expectStatus(t, call(t, "POST", "/v1/listings/"+l.ID+"/hide", nil, bearer(seller.AccessToken)), http.StatusConflict)
	var got dealView
	testenv.Eventually(t, 10*time.Second, func() error {
		if got = getDeal(t, two.AccessToken, second.ID); got.Order.Status != "cancelled" {
			return fmt.Errorf("the other order stayed %s", got.Order.Status)
		}
		return nil
	})
	if got.Order.CancelReason != "shipped_to_another" || got.Status != "negotiating" {
		t.Fatalf("%+v", got)
	}
	if r := getDeal(t, seller.AccessToken, second.ID).Order.Recipient; r.Phone != "" || r.Street != "" {
		t.Fatalf("the seller reads a cancelled order: %+v", r)
	}

	if got = orderMoved(t, one.AccessToken, first.Order.ID, "confirm", nil); got.Status != "sold" || got.Order.Status != "completed" {
		t.Fatalf("confirm: %+v", got)
	}
	if st := listingStatus(t, seller.AccessToken, l.ID); st != "sold" {
		t.Fatalf("listing %s", st)
	}
	type orderRow struct {
		DealID string `json:"deal_id"`
	}
	selling := expect[page[orderRow]](t, call(t, "GET", "/v1/me/orders?role=selling", nil, bearer(seller.AccessToken)), http.StatusOK)
	if len(selling.Items) != 2 {
		t.Fatalf("orders: %+v", selling)
	}
	buying := expect[page[orderRow]](t, call(t, "GET", "/v1/me/orders?role=buying", nil, bearer(one.AccessToken)), http.StatusOK)
	if len(buying.Items) != 1 || buying.Items[0].DealID != first.ID {
		t.Fatalf("buyer's orders: %+v", buying)
	}
}

// The carrier reports the parcel in transit, then delivered: the order
// stays shipped until the buyer confirms (or 3 days pass).
func TestOrderDelivered(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	code := trackingCode()
	d := orderMoved(t, seller.AccessToken, pendingOrder(t, buyer.AccessToken, activeListing(t, seller.AccessToken, nil).ID).Order.ID,
		"shipment", shipmentBody(code))
	expectStatus(t, setShipmentStatus(t, code, "in_transit"), http.StatusNoContent)
	if got := getDeal(t, buyer.AccessToken, d.ID); got.Order.Status != "shipped" || got.Order.Shipment.Status != "in_transit" {
		t.Fatalf("in transit: %+v", got.Order)
	}
	expectStatus(t, setShipmentStatus(t, code, "delivered"), http.StatusNoContent)
	got := getDeal(t, buyer.AccessToken, d.ID)
	if got.Order.Status != "shipped" || got.Order.Shipment.Status != "delivered" || got.Order.Shipment.DeliveredAt == "" {
		t.Fatalf("delivered: %+v", got.Order)
	}
	if got = orderMoved(t, buyer.AccessToken, d.Order.ID, "confirm", nil); got.Status != "sold" || got.Order.Status != "completed" {
		t.Fatalf("confirm: %+v", got)
	}
}

// The carrier reports the delivery failed: the order fails at once, the
// listing is back on sale, a late report changes nothing, and the buyer
// may buy again.
func TestOrderFailed(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	code := trackingCode()
	d := orderMoved(t, seller.AccessToken, pendingOrder(t, buyer.AccessToken, l.ID).Order.ID, "shipment", shipmentBody(code))
	expectStatus(t, setShipmentStatus(t, code, "failed"), http.StatusNoContent)
	got := getDeal(t, buyer.AccessToken, d.ID)
	if got.Order.Status != "failed" || got.Status != "negotiating" || got.AgreedPrice != 0 {
		t.Fatalf("failed: %+v", got)
	}
	if st := listingStatus(t, seller.AccessToken, l.ID); st != "active" {
		t.Fatalf("listing %s", st)
	}
	expectStatus(t, setShipmentStatus(t, code, "delivered"), http.StatusNoContent)
	if got = getDeal(t, buyer.AccessToken, d.ID); got.Order.Status != "failed" {
		t.Fatalf("a late report: %+v", got.Order)
	}
	moved(t, buyer.AccessToken, d.ID, "accept", map[string]any{"price": 1_500_000})
	again := moved(t, buyer.AccessToken, d.ID, "cod", codBody(deliveryAddress(t, buyer.AccessToken)))
	if again.Order.Status != "pending" || again.Order.ID == d.Order.ID {
		t.Fatalf("buy again: %+v", again.Order)
	}
}

func TestOrderLinked(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	d := orderMoved(t, seller.AccessToken, pendingOrder(t, buyer.AccessToken, activeListing(t, seller.AccessToken, nil).ID).Order.ID,
		"shipment", linkedBody)
	if sh := d.Order.Shipment; sh.Mode != "linked" || sh.Carrier != "ghtk" || !strings.HasPrefix(sh.TrackingCode, "GHTK-") ||
		sh.Status != "pending_pickup" {
		t.Fatalf("%+v", sh)
	}
	check(t, "edit a linked shipment", editShipment(t, seller.AccessToken, d.Order.ID,
		map[string]any{"carrier": "spx", "tracking_code": "SPX1"}), 409, "move_not_allowed")
}

func TestOrderEditShipment(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	stranger, _ := newAccount(t)
	d := shippedOrder(t, seller.AccessToken, buyer.AccessToken, activeListing(t, seller.AccessToken, nil).ID)
	o := d.Order.ID
	ghn := map[string]any{"carrier": "ghn", "tracking_code": "GHN0042"}
	got := expect[dealView](t, editShipment(t, seller.AccessToken, o, ghn), http.StatusOK)
	if sh := got.Order.Shipment; sh.Carrier != "ghn" || sh.TrackingCode != "GHN0042" || sh.Mode != "manual" {
		t.Fatalf("%+v", sh)
	}
	check(t, "edit signed out", editShipment(t, "", o, ghn), 401, "unauthenticated")
	check(t, "edit a bad id", editShipment(t, seller.AccessToken, "not-a-uuid", ghn), 400, "")
	check(t, "edit without a code", editShipment(t, seller.AccessToken, o, map[string]any{"carrier": "ghn"}), 400, "")
	check(t, "edit as a stranger", editShipment(t, stranger.AccessToken, o, ghn), 404, "order_not_found")
	check(t, "edit as the buyer", editShipment(t, buyer.AccessToken, o, ghn), 409, "move_not_allowed")
	check(t, "edit to carrier other", editShipment(t, seller.AccessToken, o, map[string]any{"carrier": "other", "tracking_code": "X1"}),
		422, "invalid_shipment")
	check(t, "edit to an unknown code", editShipment(t, seller.AccessToken, o, map[string]any{"carrier": "ghn", "tracking_code": "NOTFOUND1"}),
		422, "shipment_not_found")
}

func TestShipmentLookup(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	auth := bearer(seller.AccessToken)
	p := expect[shipmentPreview](t, call(t, "GET", "/v1/shipments/lookup?carrier=spx&code=SPX1", nil, auth), http.StatusOK)
	if p.Carrier != "spx" || p.TrackingCode != "SPX1" || p.CODAmount != 1_500_000 || p.Status != "pending_pickup" || p.Fee == nil ||
		p.RecipientName == "" {
		t.Fatalf("%+v", p)
	}
	check(t, "lookup signed out", call(t, "GET", "/v1/shipments/lookup?carrier=spx&code=SPX1", nil), 401, "unauthenticated")
	check(t, "lookup without a code", call(t, "GET", "/v1/shipments/lookup?carrier=spx", nil, auth), 400, "")
	check(t, "lookup carrier other", call(t, "GET", "/v1/shipments/lookup?carrier=other&code=X1", nil, auth), 422, "invalid_shipment")
	check(t, "lookup an unknown code", call(t, "GET", "/v1/shipments/lookup?carrier=spx&code=NOTFOUND1", nil, auth),
		404, "shipment_not_found")
}

func TestDevShipmentStatus(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	check(t, "a code no order has", setShipmentStatus(t, trackingCode(), "delivered"), 404, "shipment_not_found")
	code := trackingCode()
	orderMoved(t, seller.AccessToken, pendingOrder(t, buyer.AccessToken, activeListing(t, seller.AccessToken, nil).ID).Order.ID,
		"shipment", shipmentBody(code))
	check(t, "an unknown status", setShipmentStatus(t, code, "returned"), 422, "invalid_status")
	check(t, "no status", call(t, "POST", "/v1/dev/shipments/"+code+"/status", map[string]any{}), 400, "")
}

func TestOrderEarlierRefused(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	code := trackingCode()
	first := orderMoved(t, seller.AccessToken, pendingOrder(t, buyer.AccessToken, l.ID).Order.ID, "shipment", shipmentBody(code))
	expectStatus(t, setShipmentStatus(t, code, "failed"), http.StatusNoContent)
	moved(t, buyer.AccessToken, first.ID, "accept", map[string]any{"price": 1_500_000})
	second := moved(t, buyer.AccessToken, first.ID, "cod", codBody(deliveryAddress(t, buyer.AccessToken)))
	orderMoved(t, seller.AccessToken, second.Order.ID, "shipment", shipmentBody(trackingCode()))
	check(t, "confirm the failed order", orderCall(t, buyer.AccessToken, first.Order.ID, "confirm", nil), 409, "move_not_allowed")
	check(t, "ship the failed order", orderCall(t, seller.AccessToken, first.Order.ID, "shipment", shipmentBody(trackingCode())),
		409, "move_not_allowed")
	if got := getDeal(t, buyer.AccessToken, first.ID); got.Order.ID != second.Order.ID || got.Order.Status != "shipped" {
		t.Fatalf("the second order moved: %+v", got.Order)
	}
}

func TestOrderRefusals(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	stranger, _ := newAccount(t)
	d := pendingOrder(t, buyer.AccessToken, activeListing(t, seller.AccessToken, nil).ID)

	home := deliveryAddress(t, buyer.AccessToken)
	open := openDeal(t, buyer.AccessToken, activeListing(t, seller.AccessToken, nil).ID, http.StatusCreated)
	check(t, "cod signed out", dealCall(t, "", open.ID, "cod", codBody(home)), 401, "unauthenticated")
	check(t, "cod a bad id", dealCall(t, buyer.AccessToken, "not-a-uuid", "cod", codBody(home)), 400, "")
	check(t, "cod a bad address id", dealCall(t, buyer.AccessToken, open.ID, "cod", codBody("not-a-uuid")), 400, "")
	check(t, "cod as a stranger", dealCall(t, stranger.AccessToken, open.ID, "cod", codBody(home)), 404, "deal_not_found")
	check(t, "cod not agreed", dealCall(t, buyer.AccessToken, open.ID, "cod", codBody(home)), 409, "move_not_allowed")
	moved(t, buyer.AccessToken, open.ID, "accept", map[string]any{"price": 1_500_000})
	check(t, "cod to someone else's address", dealCall(t, buyer.AccessToken, open.ID, "cod", codBody(newAddress(t, stranger.AccessToken).ID)),
		404, "address_not_found")
	gone := newAddress(t, buyer.AccessToken).ID
	expectStatus(t, call(t, "DELETE", "/v1/addresses/"+gone, nil, bearer(buyer.AccessToken)), http.StatusNoContent)
	check(t, "cod to a deleted address", dealCall(t, buyer.AccessToken, open.ID, "cod", codBody(gone)), 404, "address_not_found")
	late, _ := newAccount(t)
	ld := openDeal(t, late.AccessToken, activeListing(t, seller.AccessToken, nil).ID, http.StatusCreated)
	moved(t, late.AccessToken, ld.ID, "accept", map[string]any{"price": 1_500_000})
	lateHome := deliveryAddress(t, late.AccessToken)
	suspend(t, late.Account.ID)
	check(t, "cod suspended", dealCall(t, late.AccessToken, ld.ID, "cod", codBody(lateHome)), 403, "account_suspended")
	for range 2 {
		pendingOrder(t, buyer.AccessToken, activeListing(t, seller.AccessToken, nil).ID)
	}
	check(t, "a fourth order", dealCall(t, buyer.AccessToken, open.ID, "cod", codBody(home)), 409, "cod_limit_reached")

	o := d.Order.ID
	body := shipmentBody(trackingCode())
	check(t, "ship signed out", orderCall(t, "", o, "shipment", body), 401, "unauthenticated")
	check(t, "ship without a key", call(t, "POST", "/v1/orders/"+o+"/shipment", body, bearer(seller.AccessToken)), 400, "")
	check(t, "ship in no mode", orderCall(t, seller.AccessToken, o, "shipment", map[string]any{"mode": "pigeon"}), 400, "")
	check(t, "ship as a stranger", orderCall(t, stranger.AccessToken, o, "shipment", body), 404, "order_not_found")
	check(t, "ship a deal's id", orderCall(t, seller.AccessToken, d.ID, "shipment", body), 404, "order_not_found")
	check(t, "buyer ships", orderCall(t, buyer.AccessToken, o, "shipment", body), 409, "move_not_allowed")
	check(t, "ship on carrier other", orderCall(t, seller.AccessToken, o, "shipment",
		map[string]any{"mode": "manual", "carrier": "other", "tracking_code": "X1"}), 422, "invalid_shipment")
	check(t, "ship an unknown code", orderCall(t, seller.AccessToken, o, "shipment", shipmentBody("NOTFOUND1")), 422, "shipment_not_found")
	check(t, "ship 0 grams", orderCall(t, seller.AccessToken, o, "shipment",
		map[string]any{"mode": "linked", "service": "standard", "weight_grams": 0, "pickup": "home"}), 422, "invalid_shipment")

	check(t, "confirm signed out", orderCall(t, "", o, "confirm", nil), 401, "unauthenticated")
	check(t, "confirm a bad id", orderCall(t, buyer.AccessToken, "not-a-uuid", "confirm", nil), 400, "")
	check(t, "confirm as a stranger", orderCall(t, stranger.AccessToken, o, "confirm", nil), 404, "order_not_found")
	check(t, "confirm a pending order", orderCall(t, buyer.AccessToken, o, "confirm", nil), 409, "move_not_allowed")

	check(t, "orders signed out", call(t, "GET", "/v1/me/orders?role=buying", nil), 401, "unauthenticated")
	check(t, "orders a bad role", call(t, "GET", "/v1/me/orders?role=bogus", nil, bearer(buyer.AccessToken)), 400, "")
}
```

- [ ] **Step 7: Run everything**

Run: `golangci-lint fmt ./... && make test > tmp/task8.log 2>&1; tail -40 tmp/task8.log`
Expected: PASS, the status-coverage check of `e2e/main_test.go` included (no `declared responses no test observed` lines; the three 503s come from `TestNoCarrier`), and `golangci-lint` clean. Then `grep -rn "Waybill\|waybill\|requestedOrder\|OrderRequested\|OrderDelivered\|OrderReturned\|sent_to_another\|/deliver\|/return\b" --include=*.go --include=*.yaml . | grep -v '^./migrations/'` prints nothing (the migrations and their tests keep the old names on purpose).

- [ ] **Step 8: Commit**

```bash
git add -A .env.example internal e2e
git commit -m "feat(deal): shipment and confirm endpoints, CARRIER and the dev endpoint"
```

### Task 9: `CARRIER` in every stack

The server of Task 8 stops without `CARRIER`, so this lands in the umbrella before the server's release reaches a stack. The chart has one stack values file per cluster stack (`infra/stack/values-dev.yaml`, `values-prod.yaml`), so each sets its own carrier and `values.yaml` sets none: a stack file that forgets it fails to render on `required`.

**Files (umbrella `~/shopnexus`):**
- Modify: `docker-compose.yml` (`x-server-env`), `infra/stack/values.yaml` (a comment under `server:`), `infra/stack/values-dev.yaml`, `infra/stack/values-prod.yaml`, `infra/stack/templates/_server-env.tpl`, `infra/stack/tests/server_env_test.yaml`, `infra/check.sh`

**Interfaces:**
- Consumes: the variable `CARRIER` of Task 8.
- Produces: `CARRIER=fake` in the compose stacks and the dev cluster stack, `CARRIER=none` in the production cluster stack.

- [ ] **Step 1: Write the failing chart tests**

In `infra/stack/tests/server_env_test.yaml`, the list of `exists` gains `- exists: { path: data.CARRIER }` after `data.TRUST_CALL_TIMEOUT`, and add after the scam check's test:

```yaml
  # Production has no carrier until GHTK's client comes; the dev stack runs
  # the fake, whose dev endpoint moves its shipments.
  - it: runs production without a carrier
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - equal: { path: data.CARRIER, value: none }
  - it: runs the dev stack on the fake carrier
    documentIndex: 0
    values: [../values-dev.yaml, values-test.yaml]
    asserts:
      - equal: { path: data.CARRIER, value: fake }
```

Run: `cd ~/shopnexus/infra && ./check.sh`
Expected: FAIL: the two new tests and the `exists` check find no `data.CARRIER`.

- [ ] **Step 2: Set the variable**

`infra/stack/values.yaml`, under `server:` after the `trust:` block, a comment only:

```yaml
  # carrier: where the server makes and reads shipments, set per stack:
  # fake in values-dev.yaml (with it the server serves
  # POST /v1/dev/shipments/{code}/status to anyone), none in
  # values-prod.yaml. The server refuses fake with APP_ENV=prod.
```

`infra/stack/values-dev.yaml`, under `server:`: `carrier: fake`. `infra/stack/values-prod.yaml`, under `server:`: `carrier: none`.

`infra/stack/templates/_server-env.tpl`, after `TRUST_CALL_TIMEOUT`:

```
CARRIER: {{ required "server.carrier is required: fake or none, in the stack's values file" .Values.server.carrier | quote }}
```

`docker-compose.yml`, in `x-server-env` after `TRUST_CALL_TIMEOUT: 20s` (both local stacks run `APP_ENV=dev`):

```yaml
  # Shipments (module deal): the fake carrier, as the dev cluster stack
  # runs it. With it the server serves the dev endpoint that moves its
  # shipments.
  CARRIER: fake
```

`infra/check.sh`, after the `compose TRUST_CALL_TIMEOUT` line:

```bash
eq "$(yq '.x-server-env.CARRIER' ../docker-compose.yml)" "$(yq '.server.carrier' stack/values-dev.yaml)" "compose CARRIER"
```

- [ ] **Step 3: The configuration's hash**

Run: `cd ~/shopnexus/infra && ./check.sh`
Expected: FAIL only in `carries the hash of the configuration`, which prints the new `checksum/env` of the prod data (now with `CARRIER: none`). Put that value in both `value:` lines of the two checksum tests (`carries the hash…` and `rolls the server…`), then run `./check.sh` again.
Expected: `all checks passed`.

- [ ] **Step 4: Commit**

```bash
cd ~/shopnexus && git add docker-compose.yml infra && git commit -m "build: CARRIER, fake on dev and none in production"
```

### Task 10: Docs and the definition-of-done run

**Files:**
- Modify: `server/ARCHITECTURE.md` (section Deal, from the paragraph `Orders, cash on delivery, live in module \`deal\`` to the end of the section)
- Modify: `~/shopnexus/checklist.md:29-32`
- Modify: `~/shopnexus/docs/superpowers/specs/2026-11-12-order-flow-sync-design.md`

- [ ] **Step 1: `ARCHITECTURE.md`**

In section Deal, the bullet `A deal is \`negotiating\` or \`agreed\`.` says `A deal is \`negotiating\`, \`agreed\` or \`sold\`.` Replace everything from the paragraph `Orders, cash on delivery, live in module \`deal\`` to the bullet that ends `a missing address answers before \`move_not_allowed\`.` with:

```markdown
Orders, cash on delivery, live in module `deal` (spec:
`~/shopnexus/docs/superpowers/specs/2026-10-26-server-order-design.md`;
the flow was redesigned on 2026-11-12, spec
`~/shopnexus/docs/superpowers/specs/2026-11-12-order-flow-sync-design.md`,
plan `~/shopnexus/docs/superpowers/plans/2026-11-12-server-order-flow.md`).

- An order is `pending` → `shipped` → `completed` or `failed`, or
  `pending` → `cancelled`; a shipped order is cancelled only by the pickup
  timeout. Either side cancels a pending order with the deal's `cancel`,
  which needs no Restate. A completed order makes the deal `sold`; a
  failure or a cancel makes it negotiate again without its agreed price.
- The seller ships with a shipment, which replaced the waybill on
  2026-11-12. `linked`: the server makes it on the seller's GHTK account
  (service `standard` or `express`, 1 to 20,000 g, pickup at `home` or at a
  `post_office`); part 1 does not check that the seller linked an account.
  `manual`: the seller made it on a carrier's own app and types the code;
  the server reads it from the carrier, and a code the carrier does not
  know is 422 `shipment_not_found`. The carriers are `ghtk`, `ghn`, `spx`,
  `jt` and `viettel_post`, the ones ShopNexus can read; there is no
  "other". The fee is the carrier's, null while it has none. The
  shipment's status is the carrier's: `pending_pickup`, `in_transit`,
  `delivered`, `failed`. A parcel the carrier already reports failed is
  refused (`invalid_shipment`); one it reports delivered ships delivered.
- Who closes an order: the buyer with `confirm`, at any time while it is
  shipped, or the system 3 days after the carrier reports it delivered.
  The carrier's `failed` fails it at once and releases the listing. After
  the shipment the seller's only move is correcting a manual shipment's
  carrier and code while it is `pending_pickup` or `in_transit`.
- `POST /v1/orders/{order_id}/shipment` takes `{mode: manual, carrier,
  tracking_code}` or `{mode: linked, service, weight_grams, pickup}`; its
  `mode` picks a branch of a `oneOf`, and every other rule is the domain's
  422 `invalid_shipment` with fields. `PUT` on the same path corrects a
  manual shipment; `POST /v1/orders/{order_id}/confirm` is the buyer's;
  `GET /v1/shipments/lookup?carrier=&code=` is the seller's preview. The
  order moves take the order's ID (decided 2026-11-10), and the domain
  move refuses an order that is not the deal's open one with
  `move_not_allowed`. An unknown order, or one the caller is neither side
  of, is `order_not_found` 404. `POST /v1/deals/{id}/cod` stays on the
  deal: it creates the order. `/ship`, `/deliver` and `/return` are gone.
- The `Deal` aggregate holds its latest order; `orders` keeps the earlier
  ones (migration 0011, with an index on `(deal_id, id)` for the latest
  order every deal read joins). `Deals.Save` writes deal, order, moves and
  `deal.moved` in one transaction. Each order step is a move:
  `cod_requested`, `shipped`, `shipment_updated` (a carrier's report or
  the seller's corrected code), `completed`, `failed`, `order_cancelled`;
  cancel reasons are `buyer`, `seller`, `seller_timeout`, `pickup_timeout`,
  `shipped_to_another` and `listing_closed`. Order changes have no event
  kind of their own: they ride on `deal.moved` as these moves, which
  notification reads. The order's code `SN-100001` comes from the sequence
  `order_codes`, so a use case reads the deal back after its save.
- A buyer has at most 3 orders pending or shipped; `Save` counts them
  under `pg_advisory_xact_lock` on the buyer and refuses the fourth with
  `cod_limit_reached`.
- A suspended account cannot ask for COD; a shipment, a corrected code, a
  confirmation and a cancel finish or take back an order already under
  way, and refuse no one for a suspension.
- The shipment and the confirmation change the listing, so they run as
  Restate flows, `DealShip` and `DealConfirm`, with the invocation key
  `<caller id>/<Idempotency-Key>`. `DealShip` checks a manual shipment
  whole, or a linked one's order and listing, reserves the listing, makes
  a linked shipment at GHTK, then saves. When that save loses a race it
  releases the listing and calls off a GHTK shipment the order did not
  take. `DealConfirm` saves, then sells the listing.
- A flow journals the deal it loaded and replays the domain move, which
  mints new move IDs. `Save` therefore treats a row that already has the
  write ID as an earlier try that committed and writes nothing more, where
  catalog's `Save` accepts either write ID.
- `DealShip` keeps the listing when its save loses to another try that
  shipped the same order (a second tap with a key of its own), and
  releases it otherwise. Once shipped, it calls `ListingChanged`, which
  cancels the listing's other pending orders with `shipped_to_another`.
  `ListingChanged` reads a listing reserved for an order that is not
  shipped yet as paused, so a shipment that loses to a cancel ends no
  other buyer's order. The deal worker cancels pending orders whose
  listing is hidden, sold off the app or deleted (`listing_closed`).
- The timers are delayed Restate sends to `OrderTimers`:
  `SellerTimeout` 3 days after the COD request, `PickupTimeout` 3 days
  after the shipment, `AutoComplete` 3 days after a delivered report. Each
  names its order, reads the deal when it fires, does nothing when that
  order moved on, and never compares clocks; a save that loses a race
  reads again. A pickup timeout calls a linked shipment off at GHTK and
  releases the listing. The waits are `domain.OrderWaits`; tests pass
  short ones, and `service.New` refuses a zero wait. `RequestCod` sends
  its timer before its save, so a COD request needs Restate.
- `ShipmentUpdates.Run(tracking code, status)` is the one entry point of
  a carrier's report: the dev endpoint calls it now, the carriers'
  webhooks or polling will. It moves every shipped order whose shipment has
  the code (two items in one parcel), changes nothing on a closed order,
  and answers `shipment_not_found` 404 when no order has the code.
- The carrier is `provider/carrier.Client` (`Create`, `Lookup`, and
  `Cancel`, which the spec did not name), picked by `CARRIER`: `fake` or
  `none` (decided 2026-11-12). `fake` runs locally, in the tests and on
  the dev cluster stack: every code but those that start with `NOTFOUND`
  is found, as the same parcel waiting for pickup (COD 1,500,000 đ, fee
  22,000 đ); a linked code is `GHTK-` and a number from the order ID;
  nothing is called off. With `fake` the server serves
  `POST /v1/dev/shipments/{code}/status {status}` to anyone, and
  `APP_ENV=prod` refuses it. `none` runs on the production stack until
  part 2 brings GHTK: `carrier.None` returns `carrier.ErrUnavailable`, the
  dev endpoint is not registered, and the lookup and both shipment
  endpoints answer 503 `carrier_unavailable`; a linked shipment gives back
  the listing it held. Confirmations, cancels, COD requests, the timers and
  `ShipmentUpdates` need no carrier. A manual shipment's carrier and code
  are checked and read before the order is looked up, so a stack without
  a carrier refuses before it reads an order. The chart sets the carrier
  in each stack's values file and none in `values.yaml`.
- The buyer always reads the recipient in full; the seller reads it in
  full except on a cancelled order, which keeps only the name and the
  commune.
- `POST /v1/deals/{id}/cod` takes an `address_id` from the buyer's address
  book, never a free-form recipient, so the app sends only addresses the
  book checked (decided 2026-10-27). The order copies the address, so
  editing or deleting it later leaves the order as it was. Someone else's
  address is `address_not_found`. The request reads the deal (party,
  suspension), then the address, then applies the move's rules, so a
  missing address answers before `move_not_allowed`.
- Migration 0040 renamed the order statuses, cancel reasons, moves and
  stored notices, gave every waybill a manual shipment (`in_transit`, or
  the order's end), dropped `waybill_source` and `carrier_name`, and
  dropped the shipment of the rows on carrier `other` (development data
  only). Unlike the migrations before it, it broke the release before's
  order reads and writes while it rolled out; that was accepted because
  the app was not wired to the server yet.
```

In section Notifications, if a bullet lists notice types, `delivered` and `returned` become `completed` and `failed`. Run the writing checker: `python3 ~/.claude/skills/humanizing-writing/ai-tells.py ARCHITECTURE.md` and fix what it reports in the new text.

- [ ] **Step 2: The checklist**

In `~/shopnexus/checklist.md`, line 29 becomes `- [x] Luồng đơn COD mới: chờ tạo đơn → đã gửi → hoàn tất hoặc giao không thành; người bán tạo vận đơn (\`POST /v1/orders/{order_id}/shipment\`, tự gửi hoặc qua GHTK) và sửa mã (\`PUT\`), người mua xác nhận đã nhận (\`POST /v1/orders/{order_id}/confirm\`), xem trước mã (\`GET /v1/shipments/lookup\`); tự huỷ sau 3 ngày chưa tạo đơn hoặc chưa lấy hàng, tự hoàn tất 3 ngày sau khi hãng báo đã giao; hãng giả \`CARRIER=fake\` trên dev, chưa có hãng (\`CARRIER=none\`) trên production (app chưa nối)`; line 30 becomes `- [ ] Người mua báo chưa nhận được hàng: phiếu hỗ trợ (phần 3 của spec luồng đơn); xác nhận đã nhận đã có (\`/confirm\`)`; line 32 becomes `- [ ] Tạo vận đơn thật qua GHTK, nhận trạng thái từ hãng (webhook hoặc hỏi định kỳ), liên kết tài khoản GHTK của người bán (phần 2). Bản dev dùng hãng giả (\`CARRIER=fake\`, có \`POST /v1/dev/shipments/{code}/status\`); bản production chạy \`CARRIER=none\`, tra cứu và tạo, sửa vận đơn trả 503 \`carrier_unavailable\``.

- [ ] **Step 3: The spec**

Under the spec's `Status:` line, add a list `Changed while planning (plan \`2026-11-12-server-order-flow.md\`):` with the seven items of "Deviations from the spec" above, and a list `Settled while planning, where the spec is silent:` with:
- The linked shipment's `service` is `standard` or `express`, `weight_grams` 1 to 20,000.
- A parcel the carrier already reports failed is refused at creation and at a corrected code (`invalid_shipment`); one it reports delivered ships delivered and schedules the auto-complete.
- The seller's turn (`your_turn`) is only a pending order; nobody's turn comes while an order is shipped.
- The seller reads a cancelled order's recipient as name and commune only, the pickup timeout's included.
- The dev endpoint answers 204, also when every order with the code is closed; 404 only when no order has it.
- `carrier_unavailable` is 503 (`apperr.KindUnavailable`, as `search_unavailable` and `source_unavailable`): the stack lacks a service the request needs, and no change to the request or the order would help.
- A manual shipment's carrier and code are checked and read from the carrier before the order is looked up, so the 422s and the 503 answer the same for any order ID.
- The fake reads every known code as one parcel waiting for pickup: COD 1,500,000 đ, fee 22,000 đ.
- Migration 0040 breaks the release before during its rollout (see the plan's Global Constraints).

- [ ] **Step 4: Definition of done**

Run, in the server worktree after `git rebase main`:

```bash
make test > tmp/done.log 2>&1; tail -20 tmp/done.log
grep -rn "Waybill\|waybill\|OrderRequested\|OrderDelivered\|OrderReturned\|sent_to_another\|DealFinish" --include=*.go --include=*.yaml --include=*.md . | grep -v '^./migrations/'
cd ~/shopnexus/infra && ./check.sh
```

Expected: `make test` passes (every package, e2e with its status coverage, `golangci-lint` clean); the grep prints nothing; `all checks passed`.

- [ ] **Step 5: Commit**

```bash
cd ~/shopnexus/server && git add ARCHITECTURE.md && git commit -m "docs: the order flow in ARCHITECTURE.md"
cd ~/shopnexus && git add checklist.md && git commit -m "build: checklist ticks the order flow"
cd ~/shopnexus/docs && git add superpowers/specs/2026-11-12-order-flow-sync-design.md && git commit -m "spec(orders): the order flow as planned"
```

---

## Self-review

- Spec coverage: order states and transitions (Task 3); shipment fields, modes, carriers, fee from the carrier (3, 5); `sent_to_another` renamed and the removed names (3, 8's grep); deal moves `completed`, `failed`, `shipment_updated` (3, 4); the move table: request COD (unchanged, timer in 6), cancel (3), create shipment with the listing reserved and other pending orders cancelled (5), edit tracking code (3, 5), confirm receipt (3, 5), shipment updated (3, 6), seller timeout, pickup timeout, auto-complete (3, 6); a failure's deal and listing (3, 6); closed orders ignore signals (3, 6); carrier provider, the fake and `None` (2); production without a carrier, the 503 and the missing dev route (2, 5, 6, 8, 9); API table, `oneOf` body and pickup values, removed routes (1, 8); durable work with `WithDelay` and the one entry point (6); migration bullets (4); events (deviation, recorded); unchanged limits (3, 4 keep `MaxOpenOrders` and `countOpenOrders`); reviews (5 keeps shipped, completed and failed reviewable; 6 tests a failed order). Testing section: domain tests for every move from each side and state (3), service tests for the timeouts and auto-complete with a timer that fires after the order moved on (6), one e2e test for the delivered branch (`TestOrderDelivered`) and one for the failed branch (`TestOrderFailed`) through the dev endpoint (8). `ARCHITECTURE.md` and `make test` (10).
- Placeholders: none. The one value the plan cannot know, the chart's new `checksum/env`, comes from `./check.sh` in Task 9 Step 3.
- Types: `ShipmentInput`, `FlowInput.Manual`/`Linked`, `OrderRef`, `ShipmentSignal` and `ShipmentResult` are defined in the task that first uses them and used with the same fields after. `Deps.Carrier` arrives in Task 5 and `Deps.Waits` in Task 6, and every `service.Deps` literal (deal and trust test helpers, `deal.Mount`) is changed in the task that adds the field; `deal.Mount` sets both in Task 8, where it is first built again. `Register` gains `fakeCarrier` in Task 8 with its only caller. `carrier.ErrUnavailable` (Task 2) becomes `domain.ErrCarrierUnavailable` (Task 3) in the three use cases and in `DealShip`'s `madeShipment` step (Task 5); `Deal.Editable` is gone, its check inlined in `EditShipment`, since the service no longer asks it before the carrier. Every hand-built `config.Config` that reaches `app.New` (`app_test.go`, `e2e/main_test.go`, `e2e/system_test.go`) gains `Carrier` in Task 8. The two `shipment_not_found` errors share a code, so the tests that tell them apart compare `apperr.From(err).Kind`.
- Review Focus items have tests: 1 `TestOneParcelTwoOrders` (6), with `TestOrdersWithCode` (4) under it; 2 `TestShipmentUpdateLosesToAConfirm` (6); 3 `TestTimersLeaveAnOrderThatMovedOn` (6); 4 `TestShipADeliveredParcelCompletes` (6), with `TestShipTakesTheCarriersWord` (3); 5 `TestNoCarrier` (5), with `TestTimersWorkWithoutACarrier` (6) and the e2e `TestNoCarrier` and `TestNoCarrierServesNoDevEndpoint` (8). `TestConfirmTwice` (5) still pins a repeated confirmation.
