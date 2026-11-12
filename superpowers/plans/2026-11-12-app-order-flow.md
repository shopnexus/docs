# App order flow: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app's model, rules and fakes follow the server's order flow (deal `NEGOTIATING | AGREED | SOLD`, a list of orders `PENDING → SHIPPED → COMPLETED | FAILED`, `CANCELLED`, shipments `LINKED | MANUAL` read from a fake carrier, the 3-day timers), records and refunds leave the app, and every screen that reads orders compiles and speaks the new flow: Chat, Tin nhắn, Tôi and Điểm uy tín, the tier sheet, Đơn hàng, and an interim Đơn COD and Đơn bán that the part 4 mockups replace later.

**Architecture:** `:core:model` mirrors the server (`Deal.status`, `Deal.orders`, `Order`, `Shipment`, `Parcel`) and loses `CodRequest`, `CodShipment`, `CodStatus`, `DealStage`, `DealEnd`, `RefusalReason`, `ShipMethod`, `IncidentRecord`, `RecordStatus`, `TimeWindow`, `PublicProfile` and `ThreadItem.Record`. `:core:domain` holds the six commands in `DealRules`, the system's moves in `OrderMoves.kt` (shipment updated, the two timeouts, auto-complete, shipped to another), and reads the four-step bar, rows and tags from the deal and its current order; the 15-value `OrderStatus` goes. `:core:data` adds `FakeCarrier` (the domain's `CarrierClient`), plays the carrier's steps in the simulator, runs the 3-day timers in `OrderTimers` from the world's own timestamps, and jumps seeded orders to the six states. Screens choose words from the role, `Order.status` and `Shipment.status`. Tasks go bottom-up by module; between Task 1 and Task 9 the app does not assemble, and each task is green on the tests of the modules it touches.

**Tech Stack:** Kotlin 2.4.21, AGP 9.4.1, Compose (material3 1.5.0-beta01), Navigation 3, Hilt, kotlinx.serialization, kotlinx-coroutines-test, Robolectric, Turbine, Truth.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-12-order-flow-sync-design.md`, section "App", limited to step 2 of "Order of work". The server half is planned separately; the app stays on fake data.

**Ruling on this plan's form:** as in the app plans since stage 2 (`2026-11-11-app-listing-reads.md`), the plan fixes the contract in full code: the model, the rules and moves, the fake carrier, the simulator steps and timers, the jumps, the fixtures' conversion, the order copy and the view-model states, each rule with its test by name and assertion, and the copy word for word. Screen code is given as the composables that change, written against today's layouts. Existing tests that read removed types are listed by file with what each becomes. Cost if wrong: screen code and ported tests are reviewed only at their task's gate and the final review.

**Interim parts:** Task 8's Đơn COD (`cod/`) and Đơn bán (`ship/`), with `OrderHero.kt` and `OrderParts.kt`, are interim. They keep today's layouts (hero, four-step timeline, carrier events, code row, item and person, money, order number) where those still apply, drop what the spec deletes, and wire the new commands, so the app runs end to end on the new model. Part 4's mockups (create shipment in both modes, edit tracking code, the buyer's order screen in five states) replace their layouts in a later plan. Everything else in this plan is final for part 1.

## Global Constraints

- Stage 1 to 5's constraints hold: minSdk 31, compileSdk 37, targetSdk 36, JVM 21; features never depend on features; `:core:model` and `:core:domain` are JVM; colours only through the theme and the type scale; Vietnamese strings in each module's `strings.xml`, one value per name across modules; money as `Vnd`.
- **Where to work.** The main checkout `~/shopnexus/app` belongs to another session: it holds uncommitted work on hidden boosts (`core/domain/.../Selling.kt`, `Standing.kt`, `core/model/.../Plans.kt`, untracked `Features.kt`, `account.json`, `Stage4FixturesTest.kt`, `SellingTest.kt`, `StandingTest.kt`, `feature/listings/.../MyListings*`, `PlansScreen.kt`, `PlansTest.kt`). Never commit, stash, switch branches, revert or format in the main checkout. Before Task 1, run `git -C ~/shopnexus/app status --short` and `git -C ~/shopnexus/app diff -- core/domain core/model` and read them. Then: `git -C ~/shopnexus/app worktree add ~/shopnexus/app/.worktrees/order-flow -b feat/order-flow HEAD` and `cp ~/shopnexus/app/local.properties ~/shopnexus/app/.worktrees/order-flow/`. All work and commits happen in the worktree. If the boosts work is committed by the time you start, branch from that commit instead of `HEAD`.
- **Fitting the other work.** This plan's edits to `Selling.kt` and `Standing.kt` replace only `askerLine`, `openOrder`, `orderNote`, `soldBy`, `figures90` and `dueOrder` and their imports; it does not touch `shownFeatures`, `tierPerks` or anything that reads `Features`. `account.json` is not edited (its `codRefused90` keeps its name). When `feat/order-flow` merges after the boosts work, the only expected conflicts are the import blocks of `Selling.kt`, `Standing.kt`, `SellingTest.kt` and `StandingTest.kt`: keep both sides' imports and drop the ones this plan removes.
- **Gradle.** No java on PATH: every Gradle command starts with `. ~/.local/share/shopnexus/android-env.sh &&` (it sets `JAVA_HOME=$HOME/.local/opt/jdk-21` and `ANDROID_HOME`). Run from the worktree root. Test only the modules a task touches (`./gradlew :core:model:test`, `:core:domain:test`, `:core:data:testDebugUnitTest`, `:core:ui:testDebugUnitTest`, `:feature:<name>:testDebugUnitTest`, `:app:testDebugUnitTest`), never the whole build; Task 9 runs `check` on the touched modules only. Run long Gradle commands with `run_in_background` and wait for the completion notice; never poll with `pgrep` or `sleep` loops.
- **After Gradle work** (end of every task, and before any long idle): `./gradlew --stop`, then `pgrep -fa '[G]radleDaemon|[K]otlinCompileDaemon'`; kill any PID it prints with `kill <pid>`; run the `pgrep` once more and expect no output.
- `./gradlew :<module>:spotlessApply` on each touched module before each commit; `check` fails on files ktlint would change.
- `warningsAsErrors = true` in Lint: a string no code reads fails `lintDebug`. Each UI task ends by running `python3 tmp/unused_strings.py <module>/src/main/res/values/strings.xml` from the worktree root (Task 5 Step 1 writes it) and deleting what it prints.
- Commits: no `Co-Authored-By` trailer; prefixes as in `git log` (`feat(model): …`, `feat(domain): …`, `feat(data): …`, `feat(ui): …`, `feat(deal): …`, `feat(orders): …`). Commit with `git commit -m "…" -- <paths>` or after `git add <paths>`; never `git add -A`. Code comments and commit messages go through `python3 ~/.claude/skills/humanizing-writing/ai-tells.py FILE` (write the message to `tmp/msg.txt` and check it before committing).
- **The model mirrors the server:** `Deal.status` `NEGOTIATING | AGREED | SOLD`; `Deal.orders` oldest first, the last is the current one; `Order.status` `PENDING | SHIPPED | COMPLETED | FAILED | CANCELLED`; `cancelledBy`; `cancelReason` `BUYER | SELLER | SELLER_TIMEOUT | PICKUP_TIMEOUT | SHIPPED_TO_ANOTHER | LISTING_CLOSED`; `Shipment { mode LINKED | MANUAL, carrier GHTK | GHN | SPX | JT | VIETTEL_POST, trackingCode, fee?, status PENDING_PICKUP | IN_TRANSIT | DELIVERED | FAILED, events }`. The four-step bar is computed from the deal and its current order.
- **Commands:** `RequestCod` (buyer, deal `AGREED`), `CancelOrder` (either side, order `PENDING`), `CreateShipment` (seller, order `PENDING`; manual: carrier and code; linked: service, weight, pickup `HOME | POST_OFFICE`), `EditTrackingCode` (seller, `MANUAL`, shipment `PENDING_PICKUP | IN_TRANSIT`), `ConfirmReceived` (buyer, order `SHIPPED`, any shipment status), `Rate` (buyer, order `COMPLETED`). `CreateWaybill`, `RecordSelfShipment`, `ShipParcel`, `CancelCod`, `ReportNotReceived`, `OpenRecord`, `RefundRecord`, `DeclineRecord`, `ConfirmRefund` and `WithdrawRecord` go.
- **Failed and cancelled:** a failed delivery fails the order, sends the deal back to `NEGOTIATING` without its agreed price and puts the listing back on sale; the buyer sees "Giao không thành" and "Mua lại", which works like "Mua giá này". A cancelled pending order sends the deal back to `NEGOTIATING` without its price, as the server's `Cancel` does.
- **Names shared with the server plan** (`2026-11-12-server2-order-flow.md`): the linked services are `standard` (Tiết kiệm) and `express` (Giao nhanh), the ids of `GHTK_SERVICES`; a linked shipment weighs 1 to 20 000 g (`MAX_WEIGHT_GRAMS`); pickup `HOME | POST_OFFICE`; a manual code the carrier reports `FAILED` is refused when creating and when editing; a code the carrier already reports `DELIVERED` ships as delivered (`deliveredAt` set), which starts the 3-day auto-complete; one carrier report moves every open order shipped with that code. The account fixture's old `fast`/`save` service list stays in `account.json` (not this plan's file) and nothing reads it for shipments.
- **Fake carrier:** codes starting with `NOTFOUND` (any case) are not found; linked shipments get `GHTK-<n>`; a code that is not found cannot be confirmed; a COD amount different from the agreed price warns and does not block.
- **Simulator:** `PENDING_PICKUP → IN_TRANSIT` (with the warehouse event) `→ DELIVERED`, then `COMPLETED` 3 days later; `PENDING` 3 days → `CANCELLED` `SELLER_TIMEOUT`; `PENDING_PICKUP` 3 days after shipped → `CANCELLED` `PICKUP_TIMEOUT`. `DebugControls` jumps seeded orders to `PENDING`, `SHIPPED`, `DELIVERED`, `COMPLETED`, `FAILED`, `CANCELLED`; failure comes only from there.
- **Screens:** no text anywhere counts down an order's timer. No refund state. No "Báo chưa nhận hàng" button. The buyer sees "Chờ người bán tạo đơn" while `PENDING` and "Chờ giao hàng" through the whole of `SHIPPED`, with "Đã nhận hàng" behind a confirmation dialog. Screens show results, never narration of what a model or the app is doing.
- **Copy, word for word** (new or changed; Vietnamese, in the module named):
  - `:core:designsystem` phase labels: `phase_negotiate` "Thương lượng", `phase_ship` "Tạo đơn", `phase_receive` "Nhận hàng", `phase_rate` "Đánh giá".
  - `:core:ui` order lines: `deal_ui_line_requested` "Chờ người bán tạo đơn"; `deal_ui_line_to_create` "%1$s chờ bạn tạo đơn" (unchanged); `deal_ui_line_shipping` "Chờ giao hàng"; `deal_ui_line_pickup` "Chờ %1$s lấy hàng"; `deal_ui_line_shipping_seller` "Đang giao cho %1$s" (unchanged); `deal_ui_line_delivered_seller` "Đã giao cho %1$s"; `deal_ui_line_received_buyer` "Đã nhận hàng · %1$s"; `deal_ui_line_reviewed` "%1$d sao cho %2$s" (unchanged); `deal_ui_line_reviewed_seller` "%1$s đã nhận hàng · %2$s" (unchanged); `deal_ui_line_failed` "Giao không thành"; `deal_ui_line_cancelled` "Đã hủy đơn" (unchanged).
  - `:feature:orders` (interim screens): heroes "Chờ người bán tạo đơn" (`orders_hero_wait_seller`), "Chờ giao hàng" (`orders_hero_wait_delivery`), "Đã nhận hàng" (`orders_hero_got_it`), "Giao không thành" (`orders_hero_failed`), "Đã hủy đơn" (`orders_hero_cancelled`, unchanged); seller heroes "Tạo đơn cho %1$s" (unchanged), "Chờ %1$s lấy hàng" (`orders_hero_pickup`), "Đang giao cho %1$s" (unchanged), "Đã giao cho %1$s" (`orders_hero_delivered_to`), "%1$s đã nhận hàng" (unchanged); fact "Tin đã mở bán lại" (`orders_fact_relisted`); cancel reasons "Bạn hủy" / "%1$s hủy" (unchanged), "Người bán chưa tạo đơn" (`orders_reason_seller_timeout`), "Hãng chưa lấy hàng" (`orders_reason_pickup_timeout`), "Người bán đã gửi cho người khác" (`orders_reason_shipped_to_another`), "Tin đã đóng" (`orders_reason_listing_closed`); buttons "Hủy đơn", "Đã nhận hàng", "Mua lại" (`orders_buy_again`), "Tạo đơn", "Xác nhận" (`orders_confirm_code`), "Sửa mã" (`orders_edit_code`), "Lưu mã" (`orders_save_code`); create shipment: "GHTK · %1$s" (`orders_linked_tab`), "Tự gửi" (`orders_manual_tab`) over "GHN, SPX, J&T, Viettel Post" (`orders_manual_tab_sub`), "Lấy tại nhà" (`orders_pickup_home`), "Gửi tại bưu cục" (`orders_pickup_post_office`), "Phí ship" with the fee or "Hãng báo sau" (`orders_fee_later`), "Liên kết GHTK để tạo đơn ngay trong app" (`orders_link_ghtk`), "Mã vận đơn" (unchanged); timeline steps "Chốt %1$s, chọn COD" (unchanged), "Tạo đơn" (`orders_phase_create`), "Nhận hàng" (`orders_phase_receive`, was "Xem và nhận"), "Đánh giá" (unchanged); "Đơn đã tạo, không hủy được nữa" (`orders_cancel_too_late`, was "Hàng đã được lấy, không hủy được nữa"); preview: "%1$s · %2$s · COD %3$s" (`orders_preview`), "%1$s không có mã này" (`orders_code_not_found`), "%1$s báo mã này giao không thành" (`orders_code_failed`), "COD trên đơn %1$s, khác giá đã chốt %2$s" (`orders_cod_mismatch`); dialog "Đã nhận hàng?" / "Đơn hoàn tất và %1$s được báo. Không đổi lại được." (unchanged); snackbars "%1$s đã gửi hàng qua %2$s" (`orders_shipped_via`), "Đã tạo đơn GHTK" (`orders_created_linked`), "Đã báo %1$s mã vận đơn" (`orders_told_code`), "Đã sửa mã vận đơn" (`orders_code_edited`).
  - `:feature:me`: `me_rep_failed` "Giao không thành", value "%1$d/%2$d đơn" (`me_rep_cod_refused_value`, unchanged).
  - `:feature:seller`: `fact_cod` "%1$d/%2$d đơn COD giao không thành".
  - Thread lines the rules and the simulator write: "Đã chọn giao COD", "%1$s đã chọn giao COD", "Bạn đã hủy đơn", "Đã tạo đơn GHTK · %code", "Đã gửi qua %carrier · %code", "%seller đã gửi hàng qua GHTK · %code", "Đã sửa mã vận đơn · %carrier %code", "Giao không thành", "Đơn tự hủy vì người bán chưa tạo đơn", "Đơn tự hủy vì hãng chưa lấy hàng", "Đơn đã hủy vì người bán gửi cho người khác".
- Scratch files and logs under `~/shopnexus/app/.worktrees/order-flow/tmp/` (ignored by the repo's `/*`).

## Review Focus

1. **A carrier signal after the order closed.** The buyer taps "Đã nhận hàng" while the parcel is still `IN_TRANSIT`; the simulator's `DELIVERED` step lands 3 s later. The order stays `COMPLETED`, the deal `SOLD`, the thread gains no line, and no auto-complete timer is set. Task 2 `OrderMovesTest.aLateSignalOnAClosedOrderChangesNothing`; Task 3 `SimulatorOrderTest.anEarlyReceiptDropsTheCarriersLaterSteps`.
2. **A timer that fires after its order moved on.** The seller cancels a pending order and the buyer requests COD again a day later; the first order's 3-day seller timeout fires while the second waits. The second order stays `PENDING` until its own 3 days. Task 4 `OrderTimersTest.aTimerForAnOlderOrderLeavesTheNewOneAlone`.
3. **A code typed loosely, or a lookup that comes back late.** " notfound12 " is trimmed and not found (any case); while the seller types "SPXVN1" then "SPXVN12", the answer for "SPXVN1" that lands after the newer one never replaces it, and "Xác nhận" reads the newest preview. Task 3 `FakeCarrierTest.notFoundIsAnyCaseAfterTrimming`; Task 8 `ShipOrderViewModelTest.aLateLookupNeverReplacesTheNewerCode`.
4. **Bought again after a failure.** The failed deal negotiates with no price; "Mua lại" agrees at the listed price, the next request makes a second order with a new id, Đơn hàng shows two rows (Giao không thành, Chờ người bán tạo đơn), and the first row opens the failed order with no action. Task 2 `DealRulesTest.aFailedDealIsBoughtAgainWithASecondOrder`; Task 8 `OrdersViewModelTest.aFailedThenReboughtDealShowsTwoRows` and `CodOrderViewModelTest.anOlderOrderOpensWithNoAction`.
5. **Shipped to another buyer.** The person creates a shipment for one buyer while a second buyer's order on the same listing is `PENDING`: the second order is `CANCELLED` `SHIPPED_TO_ANOTHER`, its deal negotiates again without a price, and the person's own purchases are untouched. Task 3 `FakeDealRepositoryTest.aShipmentCancelsTheOtherPendingOrdersOnItsListing`.

## Deviations from the spec

- **`Order.id: OrderId` and `OrderRoute.orderId`.** The spec's app `Order` lists no id. One row per order needs a key and a page to open, so the app's order gets the server's id (`"<dealId>-o<n>"` in the fakes) and `OrderRoute` an optional `orderId`; without it the page shows the current order. `RecordId` goes, `OrderId` takes its place in `Ids.kt`.
- **`Order.cancelledBy: Party?`.** The server's `cancelled_by` is `buyer | seller | system`; the app uses its `Party` with null for the system, so "Bạn hủy" compares sides as today.
- **`Shipment.deliveredAt`.** The spec's app list omits it; the server has it. The auto-complete timer counts its 3 days from it.
- **The lookup is given the order.** `CarrierClient.lookup(carrier, code, order)` and `DealRepository.lookupShipment(dealId, carrier, code)`: the fake answers with that order's recipient (masked) and price, as if the seller had typed them on the carrier's app. A real client in part 2 reads only the carrier and the code. The app's fake also knows a second prefix, `WRONGCOD` (found, COD 100.000 ₫ above the price), so the mismatch warning can be seen; the server's fake has only `NOTFOUND`.
- **The simulated buyer confirms receipt.** When the person sells, the simulated buyer taps "Đã nhận hàng" 4 s after the carrier's `DELIVERED` and rates 5 stars 4 s later, as the sell walks need an end. The 3-day auto-complete runs as well and finds nothing to do. When the person buys, only their tap or the timer completes the order.
- **Milestones stay in the model.** `ThreadItem.Milestone` and `MilestoneKind` are kept; Chat draws both as event lines (the spec: "the two milestone drawings become event lines"). The seeded threads keep their milestone items.
- **The fake carrier remembers what it reported.** `FakeCarrier.report(code, status)` records each carrier step the simulator plays, and a later lookup of that code reads it, as the server's dev endpoint sets a code's status. It is how a typed code can come back `DELIVERED` or `FAILED` in the app.
- **Timers read the world.** `OrderTimers` watches the world and sets each order's timer from its own `requestedAt`, `shippedAt` or `deliveredAt`, rather than one timer per command, so seeded orders and debug jumps get theirs too. Each reads the order when it fires and does nothing when that order moved on.
- **`Parcel` lives in `:core:model`, `CarrierClient` in `:core:domain`.** The rules check a manual code against the carrier inside `CreateShipment` and `EditTrackingCode`; the screens read the same `Parcel` for the preview.

## Rulings on what the spec leaves open

- "No timer text anywhere" covers the order's timers (seller timeout, pickup timeout, auto-complete). The seller's counter-offer expiry ("Hết hạn sau … giờ") and the time a request came in ("Chờ từ 09:12", Tôi's "chờ từ 09:12") are not timers and stay.
- The seller's words through `SHIPPED`: "Chờ GHTK lấy hàng" (`PENDING_PICKUP`, the carrier's label), "Đang giao cho …" (`IN_TRANSIT`), "Đã giao cho …" (`DELIVERED`).
- "Mua lại" sends `AcceptCounter` (the seller's open counter if there is one, else the listed price, as "Mua giá này") and opens Giao COD.
- Điểm uy tín's 90-day row reads the account's figures, renamed `Figures90(codFailed, codOrders)`; the seed field `codRefused90` keeps its name. The user ruled on 2026-11-12 that failed deliveries take no rights away either: `rightsFor` grants the tier's caps and nothing lowers them (Task 7b). `Stats90`, `codBlockedUntil`, `lastRefusalAt` and `MIN_ORDERS_FOR_SANCTIONS` go.
- `SellerFacts.codRefused` becomes `codFailed` and the tier sheet says "giao không thành"; `records` and `recordsSelfRefunded` go.
- `InboxTag.AwaitingShipment` ("Chờ gửi") goes: creating the shipment is the one step.
- The money note under a pending buyer order stays `MoneyKey.CANCEL`, under a shipped one `MoneyKey.REFUSE` (COD inspection at the door).

## File map

| File | Responsibility | Task |
|---|---|---|
| `core/model/.../Deal.kt` | `DealStatus`, `OrderStatus`, `CancelReason`, `ShipmentMode`, `ShipCarrier`, `ShipmentStatus`, `Shipment`, `Order`, `Parcel`, `Deal.status/orders/currentOrder/openOrder` | 1 |
| `core/model/.../Commands.kt` | the six order commands, `NewShipment`, `Pickup` | 1 |
| `core/model/.../Thread.kt`, `Ids.kt`, `People.kt`, `Sellers.kt`, `Account.kt`, `OrderDraft.kt`, `Inbox.kt` | `Record` item, `RecordId`, `PublicProfile`, record facts and figures, `AwaitingShipment` go; `OrderId`, `Figures90(codFailed, codOrders)`, the new form draft | 1 |
| `core/model/src/test/.../DealJsonTest.kt`, `SerializationTest.kt`, `AccountJsonTest.kt` | round trips | 1 |
| `core/domain/.../Orders.kt` | roles, `phaseOf`, `canCancel`, `canEditTrackingCode`, `OrderRow`/`orderRows`, `inboxTag`, `openCodOrders`, `codSlots`, `nextOrderId` | 2 |
| `core/domain/.../OrderMoves.kt` (new) | `ORDER_WAIT`, `withOrder`, `shipmentUpdated`, `completed`, `cancelled`, `sellerTimedOut`, `pickupTimedOut`, `autoCompleted`, `shippedToAnother` | 2 |
| `core/domain/.../DealRules.kt` | `CarrierClient`, `CreatedShipment`, `ShipmentNotFound`, `EngineContext`, the commands | 2 |
| `core/domain/.../DealConsole.kt`, `Selling.kt`, `Standing.kt`, `Handover.kt` | console states, order notes, sales, due order, `GHTK_SERVICES` | 2 |
| `core/domain/src/test/...` | `OrderFixtures`, `DealRulesTest`, `OrderMovesTest` (new), `OrdersTest`, console, selling and standing tests; `CodFlowTest`, `OrderStatusTest` deleted | 2 |
| `core/data/.../fake/FakeCarrier.kt` (new) | the fake carrier | 3 |
| `core/data/.../Repositories.kt`, `fake/FakeDealRepository.kt`, `FakeDealEngine.kt` | `lookupShipment`, shipped-to-another, the address of one request, receipt points | 3 |
| `core/data/.../fake/Simulator.kt`, `SimulatorSteps.kt` | the seller's shipment, the carrier's steps, the simulated buyer | 3 |
| `core/data/.../fake/OrderJumps.kt`, `DebugControls.kt` | `OrderJump`, `orderAt`, `ConsoleTarget` | 3 |
| `core/data/.../fake/Seeds.kt`, `FakeWorld.kt`, `FakeListingRepository.kt`, `FakeMyListingsRepository.kt`, `FakeInboxRepository.kt`, `AccountFakes.kt` | record replies go; readers of the new model | 3 |
| `core/data/src/main/resources/fixtures/deals.json`, `sellers.json`, `notifications.json` | converted by `tmp/convert_fixtures.py` | 3 |
| `core/data/src/test/.../fake/*` | `FakeCarrierTest`, `SimulatorOrderTest`, `OrderJumpsTest` (new); the rest ported | 3 |
| `core/data/.../fake/OrderTimers.kt` (new), `Simulator.kt` | the three 3-day timers | 4 |
| `core/data/src/test/.../fake/OrderTimersTest.kt` (new) | the timers | 4 |
| `core/navigation/.../Routes.kt` | `OrderRoute.orderId` | 5 |
| `core/designsystem/src/main/res/values/strings.xml`, its tests | the four phase labels | 5 |
| `core/ui/.../deal/OrderCopy.kt`; `RecordCard.kt`, `RecordSheet.kt`, `RecordDrafts.kt`, `Drafts.kt` deleted; strings; `DealPiecesTest.kt` | order lines and actions; records out | 5 |
| `tmp/unused_strings.py` (scratch) | lists strings no code reads | 5 |
| `feature/deal/.../chat/*`, strings, tests | console, composer, thread, view model | 6 |
| `feature/inbox/.../InboxScreen.kt`, strings, `InboxScreenTest.kt` | `AwaitingShipment` out | 6 |
| `feature/me/.../rep/ReputationScreen.kt`, strings, test; `feature/seller/.../profile/TierSheet.kt`, strings, test | 90-day row, tier facts | 7 |
| `feature/discover/src/test/.../ListingDetailViewModelTest.kt`, `feature/notifications/src/test/.../NotificationsViewModelTest.kt` | ported | 7 |
| `feature/orders/.../OrderRouter.kt`, `OrderCancel.kt`, `OrderHero.kt`, `OrderParts.kt`; `SellerParts.kt`, `ship/RefundSheet.kt`, `ship/ShippingCodeSheet.kt` deleted | shared parts | 8 |
| `feature/orders/.../list/*` | one row per order | 8 |
| `feature/orders/.../cod/*` | interim Đơn COD | 8 |
| `feature/orders/.../ship/*` | interim Đơn bán | 8 |
| `feature/orders/.../checkout/CodCheckoutViewModel.kt` | "requested" from the open order | 8 |
| `feature/orders/src/main/res/values/strings.xml`, tests | copy, ported tests | 8 |
| `app/src/debug/.../DebugHost.kt`, its strings; `app/src/test/.../SliceTest.kt`, `DealsWalkTest.kt`, `SellWalkTest.kt`; `app/src/testDebug/.../DebugPanelTest.kt`; `README.md` | debug panel, walks, gate | 9 |

## Task order and interfaces

1 → 2 → 3 → 4 → 5 → 6 → 7 → 7b → 8 → 9. Each task needs the ones before it. Tasks 6, 7 and 8 touch different modules and can run in any order after 5; 7b comes after 7 and before 8, since 8 rewrites `CodCheckoutViewModel` callers.

Names later tasks rely on:

- Task 1, `vn.shopnexus.core.model`: `enum class DealStatus { NEGOTIATING, AGREED, SOLD }`; `enum class OrderStatus { PENDING, SHIPPED, COMPLETED, FAILED, CANCELLED }`; `enum class CancelReason { BUYER, SELLER, SELLER_TIMEOUT, PICKUP_TIMEOUT, SHIPPED_TO_ANOTHER, LISTING_CLOSED }`; `enum class ShipmentMode { LINKED, MANUAL }`; `enum class ShipCarrier(val label: String) { GHTK, GHN, SPX, JT, VIETTEL_POST }`; `enum class ShipmentStatus { PENDING_PICKUP, IN_TRANSIT, DELIVERED, FAILED }`; `data class Shipment(mode, carrier, trackingCode: String, fee: Vnd? = null, status = PENDING_PICKUP, events: List<CarrierEvent> = emptyList(), deliveredAt: Moment? = null)`; `data class Order(id: OrderId, status, recipient: DeliveryAddress, price: Vnd, requestedAt: Moment, shipment: Shipment? = null, cancelledBy: Party? = null, cancelReason: CancelReason? = null, shippedAt: Moment? = null, closedAt: Moment? = null) { val open: Boolean }`; `data class Parcel(recipient: String, district: String, cod: Vnd, status: ShipmentStatus, fee: Vnd?)`; `Deal(…, status: DealStatus, …, orders: List<Order> = emptyList(), …)` with `currentOrder: Order?` and `openOrder: Order?`; `@JvmInline value class OrderId(val value: String)`; `enum class Pickup { HOME, POST_OFFICE }`; `sealed interface NewShipment { Manual(carrier: ShipCarrier, trackingCode: String); Linked(service: String, weightGrams: Int, pickup: Pickup) }`; `DealCommand.CancelOrder`, `CreateShipment(shipment: NewShipment)`, `EditTrackingCode(carrier: ShipCarrier, trackingCode: String)`, `ConfirmReceived`; `Figures90(codFailed: Int, codOrders: Int)`; `SellerFacts(dealsDone, cancelled, codFailed, codOrders, idChip, replyTime)`; `OrderDraft(mode: ShipmentMode? = null, weight: String? = null, service: String? = null, pickup: Pickup? = null, carrier: ShipCarrier? = null, trackingCode: String = "")`.
- Task 2, `vn.shopnexus.core.domain`: `fun isOrder(deal: Deal): Boolean`; `fun canCancel(deal: Deal): Boolean`; `fun canEditTrackingCode(order: Order): Boolean`; `fun phaseOf(deal: Deal): Int`; `fun phaseOf(order: Order, rating: Int?): Int`; `data class OrderRow(val view: DealView, val order: Order)`; `fun orderRows(views: List<DealView>, side: Party): List<OrderRow>`; `fun Deal.nextOrderId(): OrderId`; `val ORDER_WAIT: Duration`; `fun Deal.withOrder(order: Order): Deal`; `fun Deal.shipmentUpdated(status: ShipmentStatus, now: Instant, events: List<CarrierEvent> = emptyList()): Deal`; `fun Deal.completed(now: Instant): Deal`; `fun Deal.cancelled(by: Party?, reason: CancelReason, now: Instant, line: String): Deal`; `fun Deal.sellerTimedOut(order: OrderId, now: Instant): Deal`; `fun Deal.pickupTimedOut(order: OrderId, now: Instant): Deal`; `fun Deal.autoCompleted(order: OrderId, now: Instant): Deal`; `fun Deal.shippedToAnother(now: Instant): Deal`; `interface CarrierClient { fun create(service: String, weightGrams: Int, pickup: Pickup, cod: Vnd): CreatedShipment; fun lookup(carrier: ShipCarrier, code: String, order: Order): Parcel? }`; `data class CreatedShipment(val trackingCode: String, val fee: Vnd?)`; `class ShipmentNotFound`; `EngineContext(account, openCod, rights, carrier: CarrierClient? = null)`; `ConsoleState.OrderStep(order: Order, price: Vnd)` (`ConsoleState.Ended` goes); `val GHTK_SERVICES: List<Carrier>` (ids `express`, `standard`); `const val MAX_WEIGHT_GRAMS = 20_000`; `const val TRACKING_CODE_MAX = 50`; `CodAccount` keeps only `address`. `orderStatus`, `phaseFor`, `activeRecord`, `refundOptions`, `recordDaysLeft`, `figures90`, `shippingCode`, `SELF_CARRIER` go.
- Task 3, `vn.shopnexus.core.data`: `DealRepository.lookupShipment(id: DealId, carrier: ShipCarrier, code: String): Result<Parcel?>`; `class FakeCarrier : CarrierClient` (`@Singleton`, `@Inject constructor()`); `enum class OrderJump { PENDING, SHIPPED, DELIVERED, COMPLETED, FAILED, CANCELLED }`; `fun orderAt(start: DealView, jump: OrderJump, now: Instant, zone: ZoneId): DealView`; `val ORDER_JUMPS: Map<DealId, List<OrderJump>>`; `enum class ConsoleTarget { COUNTERED, WAITING, AGREED, PENDING, SHIPPED, RECEIVED, DONE }`; `DebugControls.jumpOrder(id: DealId, jump: OrderJump)`; `FakeCarrier.report(code: String, status: ShipmentStatus)`; `internal fun WorldState.carrierReported(code: String, status: ShipmentStatus, now: Instant, events: List<CarrierEvent>, carrier: FakeCarrier): WorldState`; `interface DealEngine { …; val carrier: CarrierClient }` with `FakeDealEngine(override val carrier: FakeCarrier = FakeCarrier())` (`FakeDealRepository`'s constructor is unchanged and reads `engine.carrier`); `Simulator(world, clock, scope, zone, pace, carrier: FakeCarrier = FakeCarrier())`.
- Task 4: `internal class OrderTimers(world: FakeWorld, clock: Clock, scope: CoroutineScope, pace: Pace)` with `fun start()` and `fun stop()`; `Simulator.stopAll()` stops them and they start again on the next world change.
- Task 7b: `fun rightsFor(tier: Tier): Rights`; `data class Rights(val codOpenCap: Int, val listingCap: Int)`; `fun codSlots(rights: Rights, openCod: Int): CodSlots`.
- Task 5: `OrderRoute(dealId: String, sent: Boolean = false, orderId: String? = null)`; `@Composable fun orderLine(view: DealView, order: Order, now: Instant, zone: ZoneId): OrderLine`; `@Composable fun orderAction(view: DealView, order: Order): OrderAction?`; `fun DealView.order(id: String?): Order?` (in `OrderCopy.kt`).

---
### Task 1: The model mirrors the server

**Files:**
- Modify: `core/model/src/main/kotlin/vn/shopnexus/core/model/Deal.kt` (whole file), `Commands.kt` (whole file), `Thread.kt` (whole file), `Ids.kt`, `People.kt`, `Sellers.kt`, `Account.kt`, `OrderDraft.kt` (whole file), `Inbox.kt`
- Test: `core/model/src/test/kotlin/vn/shopnexus/core/model/DealJsonTest.kt` (whole file), `SerializationTest.kt`, `AccountJsonTest.kt`

**Interfaces:**
- Consumes: nothing new.
- Produces: the Task 1 names in "Task order and interfaces".

- [ ] **Step 0: The worktree**

Run the "Where to work" steps of the Global Constraints. Expected: `git -C ~/shopnexus/app/.worktrees/order-flow branch --show-current` prints `feat/order-flow`.

- [ ] **Step 1: Write the failing round trips**

Replace `core/model/src/test/kotlin/vn/shopnexus/core/model/DealJsonTest.kt` with:

```kotlin
package vn.shopnexus.core.model

import com.google.common.truth.Truth.assertThat
import java.time.Instant
import org.junit.Test

class DealJsonTest {
    private val at = Instant.parse("2026-10-15T08:10:00Z")
    private val home = DeliveryAddress("Khánh Linh", "09•• ••• 812", "12 Nguyễn Gia Trí, Phường 25, Bình Thạnh")

    private fun deal() = Deal(
        id = DealId("d-nam"), listingId = ListingId("p-iphonex"),
        buyerId = UserId("u-linh"), sellerId = UserId("u-nam"),
        listedPrice = Vnd(3_900_000), status = DealStatus.AGREED,
        agreedPrice = Vnd(3_800_000), agreedAt = at, code = "SN-31204",
    )

    private fun view(deal: Deal) = DealView(
        deal = deal,
        listing = ListingSummary(ListingId("p-iphonex"), "https://x/i.jpg", Vnd(3_900_000), "iPhone X 64GB, pin 86%", Condition.USED, 0.6),
        counterpart = SellerSummary(UserId("u-nam"), "Hoàng Nam", null, true, Tier.TRUSTED, 4.7, 12, 12, "15 phút", 2023),
        me = Me(UserId("u-linh"), "Khánh Linh", null, "Bình Thạnh"),
    )

    private fun order(status: OrderStatus, shipment: Shipment? = null) =
        Order(OrderId("d-nam-o1"), status, home, Vnd(3_800_000), at, shipment = shipment)

    @Test
    fun aShippedOrderRoundTripsWithItsShipment() {
        val shipment = Shipment(
            ShipmentMode.MANUAL, ShipCarrier.SPX, "SPXVN031245678", fee = Vnd(22_000),
            status = ShipmentStatus.IN_TRANSIT, events = listOf(CarrierEvent("Đến kho Bình Thạnh", at)),
        )
        val shipped = view(deal().copy(orders = listOf(order(OrderStatus.SHIPPED, shipment).copy(shippedAt = at))))
        val text = ShopNexusJson.encodeToString(DealView.serializer(), shipped)
        assertThat(text).contains("\"status\":\"AGREED\"")
        assertThat(text).contains("\"carrier\":\"SPX\"")
        assertThat(text).contains("\"status\":\"IN_TRANSIT\"")
        assertThat(ShopNexusJson.decodeFromString(DealView.serializer(), text)).isEqualTo(shipped)
    }

    @Test
    fun theLastOrderIsTheCurrentOneAndOnlyAPendingOrShippedOneIsOpen() {
        val failed = order(OrderStatus.FAILED)
        val again = order(OrderStatus.PENDING).copy(id = OrderId("d-nam-o2"))
        assertThat(deal().currentOrder).isNull()
        assertThat(deal().copy(orders = listOf(failed)).openOrder).isNull()
        assertThat(deal().copy(orders = listOf(failed, again)).currentOrder).isEqualTo(again)
        assertThat(deal().copy(orders = listOf(failed, again)).openOrder).isEqualTo(again)
        assertThat(OrderStatus.entries.filter { order(it).open }).containsExactly(OrderStatus.PENDING, OrderStatus.SHIPPED)
    }

    @Test
    fun aCancelledOrderKeepsWhoAndWhy() {
        val cancelled = order(OrderStatus.CANCELLED).copy(cancelledBy = null, cancelReason = CancelReason.SELLER_TIMEOUT, closedAt = at)
        val text = ShopNexusJson.encodeToString(Order.serializer(), cancelled)
        assertThat(text).contains("\"cancelReason\":\"SELLER_TIMEOUT\"")
        assertThat(ShopNexusJson.decodeFromString(Order.serializer(), text)).isEqualTo(cancelled)
    }

    @Test
    fun theCarriersNameWhatScreensShow() {
        assertThat(ShipCarrier.entries.map { it.label }).containsExactly("GHTK", "GHN", "SPX", "J&T", "Viettel Post").inOrder()
        assertThat(ShopNexusJson.encodeToString(ShipCarrier.serializer(), ShipCarrier.JT)).isEqualTo("\"JT\"")
    }

    /** A deal carries the model's general tips, a tip's way to check is optional, and the view carries the listing's claims. */
    @Test
    fun aDealReadsItsTips() {
        val withTips = view(
            deal().copy(
                tips = listOf(
                    CheckTip("k0", "Face ID mở được máy", "familiar_face_and_zone"),
                    CheckTip("k3", "IMEI trùng hộp", "pin", "Bấm *#06# rồi so với hộp"),
                ),
            ),
        )
            .copy(claims = listOf(Claim("battery_full_alt", "Pin 86%", "Cài đặt › Pin › Tình trạng pin và sạc")))
        val text = ShopNexusJson.encodeToString(DealView.serializer(), withTips)
        assertThat(text).doesNotContain("checked")
        val read = ShopNexusJson.decodeFromString(DealView.serializer(), text)
        assertThat(read).isEqualTo(withTips)
        assertThat(read.deal.tips.first().how).isNull()
    }

    @Test
    fun tagsTargetsAndCommandsCarryTheirKind() {
        assertThat(ShopNexusJson.encodeToString(InboxTag.serializer(), InboxTag.Counter(Vnd(10_600_000))))
            .isEqualTo("{\"type\":\"counter\",\"amount\":10600000}")
        assertThat(ShopNexusJson.encodeToString(InboxTag.serializer(), InboxTag.AwaitingCreation)).isEqualTo("{\"type\":\"toCreate\"}")
        assertThat(ShopNexusJson.encodeToString(NotificationTarget.serializer(), NotificationTarget.Order(DealId("d-huy"))))
            .isEqualTo("{\"type\":\"order\",\"dealId\":\"d-huy\"}")
        assertThat(ShopNexusJson.decodeFromString(DealCommand.serializer(), "{\"type\":\"withdrawOffer\"}")).isEqualTo(DealCommand.WithdrawOffer)
        val commands = listOf(
            DealCommand.RequestCod to "{\"type\":\"requestCod\"}",
            DealCommand.CancelOrder to "{\"type\":\"cancelOrder\"}",
            DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.SPX, "SPXVN1")) to
                "{\"type\":\"createShipment\",\"shipment\":{\"type\":\"manual\",\"carrier\":\"SPX\",\"trackingCode\":\"SPXVN1\"}}",
            DealCommand.CreateShipment(NewShipment.Linked("express", 2_000, Pickup.POST_OFFICE)) to
                "{\"type\":\"createShipment\",\"shipment\":{\"type\":\"linked\",\"service\":\"express\",\"weightGrams\":2000,\"pickup\":\"POST_OFFICE\"}}",
            DealCommand.EditTrackingCode(ShipCarrier.GHN, "GHN123") to "{\"type\":\"editTrackingCode\",\"carrier\":\"GHN\",\"trackingCode\":\"GHN123\"}",
            DealCommand.ConfirmReceived to "{\"type\":\"confirmReceived\"}",
            DealCommand.Rate(5) to "{\"type\":\"rate\",\"stars\":5}",
        )
        for ((command, json) in commands) {
            assertThat(ShopNexusJson.encodeToString(DealCommand.serializer(), command)).isEqualTo(json)
            assertThat(ShopNexusJson.decodeFromString(DealCommand.serializer(), json)).isEqualTo(command)
        }
    }

    @Test
    fun anInboxAndACheckoutRoundTrip() {
        val row = InboxRow(
            DealId("d-24h"),
            Party.BUYER,
            view(deal()).counterpart,
            view(deal()).listing,
            LastMessage("Bạn chuyển cọc 500k qua số tài khoản này để mình giữ máy nhé.", photos = 0, mine = false, at = at),
            unread = 1,
            tag = InboxTag.Scam,
            warning = ScamWarning(listOf(WarningSignal("account_balance", "Đòi chuyển cọc ngoài app"))),
        )
        val inbox = Inbox(listOf(row), unread = 1)
        assertThat(ShopNexusJson.decodeFromString(Inbox.serializer(), ShopNexusJson.encodeToString(Inbox.serializer(), inbox))).isEqualTo(inbox)
        val checkout = CodCheckout(view(deal()), home, ShipEstimate(Vnd(16_000), Vnd(30_000)), openCod = 0, codCap = 5, codBlockedUntil = null)
        assertThat(
            ShopNexusJson.decodeFromString(CodCheckout.serializer(), ShopNexusJson.encodeToString(CodCheckout.serializer(), checkout)),
        ).isEqualTo(checkout)
    }

    @Test
    fun aParcelAndAFormDraftRoundTrip() {
        val parcel = Parcel("Đ••• H•••", "Phú Nhuận", Vnd(350_000), ShipmentStatus.PENDING_PICKUP, Vnd(22_000))
        assertThat(ShopNexusJson.decodeFromString(Parcel.serializer(), ShopNexusJson.encodeToString(Parcel.serializer(), parcel))).isEqualTo(parcel)
        val draft = OrderDraft(mode = ShipmentMode.MANUAL, carrier = ShipCarrier.JT, trackingCode = "JT0001")
        assertThat(ShopNexusJson.decodeFromString(OrderDraft.serializer(), ShopNexusJson.encodeToString(OrderDraft.serializer(), draft))).isEqualTo(draft)
    }
}
```

In `SerializationTest.dealRoundTripsWithEveryThreadItem`: `stage = DealStage.NEGOTIATE` becomes `status = DealStatus.NEGOTIATING`; delete the `records = …` line and the `ThreadItem.Record(RecordId("r1"), at),` item. In `AccountJsonTest.theReputationRoundTrips`: `Figures90(codRefused = 0, codOrders = 3, recordsDeclined = 0, recordsUnanswered = 0)` becomes `Figures90(codFailed = 0, codOrders = 3)`.

- [ ] **Step 2: Run them to see them fail**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:model:test`
Expected: compilation fails (`DealStatus`, `Order`, `Shipment`, `NewShipment` unresolved).

- [ ] **Step 3: `Deal.kt`**

Replace `core/model/src/main/kotlin/vn/shopnexus/core/model/Deal.kt` with:

```kotlin
package vn.shopnexus.core.model

import kotlinx.serialization.Serializable

@Serializable enum class Party { BUYER, SELLER }

@Serializable enum class OfferStatus { OPEN, ACCEPTED, WITHDRAWN, SUPERSEDED }

@Serializable
data class Offer(val by: Party, val amount: Vnd, val at: Moment, val status: OfferStatus)

/** A general tip the model gives for checking this kind of item, with how to check it where that helps; the seller did not promise it. `icon` is a Material Symbols name. */
@Serializable
data class CheckTip(val id: String, val text: String, val icon: String, val how: String? = null)

/**
 * A deal as the server has it: NEGOTIATING, AGREED on a price, SOLD once its order completes. A failed or cancelled
 * order sends it back to NEGOTIATING without its price.
 */
@Serializable enum class DealStatus { NEGOTIATING, AGREED, SOLD }

/** PENDING until the seller creates the shipment, then SHIPPED until it COMPLETED or FAILED; CANCELLED while pending, or when nobody picked it up. */
@Serializable enum class OrderStatus { PENDING, SHIPPED, COMPLETED, FAILED, CANCELLED }

@Serializable enum class CancelReason { BUYER, SELLER, SELLER_TIMEOUT, PICKUP_TIMEOUT, SHIPPED_TO_ANOTHER, LISTING_CLOSED }

/** LINKED: created on the seller's linked GHTK account. MANUAL: sent on the carrier's own app, with its tracking code typed here. */
@Serializable enum class ShipmentMode { LINKED, MANUAL }

/** The carriers ShopNexus can read a shipment from; [label] is the name screens show. */
@Serializable
enum class ShipCarrier(val label: String) {
    GHTK("GHTK"),
    GHN("GHN"),
    SPX("SPX"),
    JT("J&T"),
    VIETTEL_POST("Viettel Post"),
}

@Serializable enum class ShipmentStatus { PENDING_PICKUP, IN_TRANSIT, DELIVERED, FAILED }

@Serializable
data class CarrierEvent(val text: String, val at: Moment)

/** A service on the seller's linked GHTK account (`express`, `standard`) and its base fee. */
@Serializable data class Carrier(val id: String, val name: String, val days: String, val fee: Vnd)

/** [phone] is masked ("09•• ••• 812"). */
@Serializable data class DeliveryAddress(val name: String, val phone: String, val line: String)

/** The parcel as the carrier reports it. [fee] is the carrier's, null while it has not said; nobody types it. */
@Serializable
data class Shipment(
    val mode: ShipmentMode,
    val carrier: ShipCarrier,
    val trackingCode: String,
    val fee: Vnd? = null,
    val status: ShipmentStatus = ShipmentStatus.PENDING_PICKUP,
    val events: List<CarrierEvent> = emptyList(),
    val deliveredAt: Moment? = null,
)

/**
 * The buyer's COD request at the agreed [price] to [recipient], and what came of it. [cancelledBy] is null when the
 * system cancelled it (a timeout, a parcel shipped to another buyer).
 */
@Serializable
data class Order(
    val id: OrderId,
    val status: OrderStatus,
    val recipient: DeliveryAddress,
    val price: Vnd,
    val requestedAt: Moment,
    val shipment: Shipment? = null,
    val cancelledBy: Party? = null,
    val cancelReason: CancelReason? = null,
    val shippedAt: Moment? = null,
    val closedAt: Moment? = null,
) {
    /** Pending or shipped: the order still holds the buyer's COD slot and the deal's agreement. */
    val open: Boolean get() = status == OrderStatus.PENDING || status == OrderStatus.SHIPPED
}

/** What a carrier says about a tracking code before the seller confirms it: the recipient's name masked, the district, the COD amount. */
@Serializable data class Parcel(val recipient: String, val district: String, val cod: Vnd, val status: ShipmentStatus, val fee: Vnd?)

@Serializable
data class Deal(
    val id: DealId,
    val listingId: ListingId,
    val buyerId: UserId,
    val sellerId: UserId,
    val listedPrice: Vnd,
    val status: DealStatus,
    val offers: List<Offer> = emptyList(),
    val agreedPrice: Vnd? = null,
    val tips: List<CheckTip> = emptyList(),
    val rating: Int? = null,
    val thread: List<ThreadItem> = emptyList(),
    /** Oldest first; the last is the current one. A deal bought again after a failure has two. */
    val orders: List<Order> = emptyList(),
    /** The model's judgment of the seller's counter ("Rẻ hơn 15%"). */
    val priceInsight: PriceInsight? = null,
    /** When the seller's open counter stops binding. */
    val counterExpiresAt: Moment? = null,
    /** The order number, given when the price is first agreed ("SN-24817"). */
    val code: String? = null,
    val agreedAt: Moment? = null,
    val ratedAt: Moment? = null,
) {
    val openCounter: Offer? get() = offers.lastOrNull { it.by == Party.SELLER && it.status == OfferStatus.OPEN }
    val openOffer: Offer? get() = offers.lastOrNull { it.by == Party.BUYER && it.status == OfferStatus.OPEN }
    val currentOrder: Order? get() = orders.lastOrNull()

    /** The current order while it is pending or shipped; null before the request and once it closed. */
    val openOrder: Order? get() = currentOrder?.takeIf { it.open }
}

/** Everything Chat and the order pages show about one deal, in one read. */
@Serializable
data class DealView(
    val deal: Deal,
    val listing: ListingSummary,
    val counterpart: SellerSummary,
    val me: Me,
    /** Whether the other person has a Người bán page; buyers who never sold have none. */
    val counterpartSells: Boolean = true,
    /** What the item is, for the words about it ("Kiểm xe", "Máy có vấn đề?"). */
    val kind: ListingKind = ListingKind.OTHER,
    /** The other person's district, where the deal knows it; the simulated buyer's COD address uses it. */
    val counterpartArea: String? = null,
    /** What the seller's listing says about the item, for the look at the door. */
    val claims: List<Claim> = emptyList(),
)
```

- [ ] **Step 4: `Commands.kt`**

Replace `core/model/src/main/kotlin/vn/shopnexus/core/model/Commands.kt` with:

```kotlin
package vn.shopnexus.core.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** Where the carrier takes a linked shipment from: the seller's pickup address, or a post office the seller brings it to. */
@Serializable enum class Pickup { HOME, POST_OFFICE }

/** The shipment the seller creates: on the linked GHTK account, or one already sent on a carrier's own app. */
@Serializable
sealed interface NewShipment {
    @Serializable
    @SerialName("manual")
    data class Manual(val carrier: ShipCarrier, val trackingCode: String) : NewShipment

    @Serializable
    @SerialName("linked")
    data class Linked(val service: String, val weightGrams: Int, val pickup: Pickup) : NewShipment
}

/**
 * What the signed-in person can do to a deal; the engine reads their side from `me`. Each command returns the updated
 * Deal. A seller's [SendOffer] is a counter to the buyer's open offer and a seller's [AcceptCounter] accepts that offer.
 */
@Serializable
sealed interface DealCommand {
    @Serializable
    @SerialName("sendText")
    data class SendText(val text: String) : DealCommand

    @Serializable
    @SerialName("sendOffer")
    data class SendOffer(val amount: Vnd, val note: String?) : DealCommand

    /** The buyer accepts the seller's open counter, or the listed price when there is none; the seller accepts the buyer's open offer. */
    @Serializable
    @SerialName("acceptCounter")
    data object AcceptCounter : DealCommand

    @Serializable
    @SerialName("withdrawOffer")
    data object WithdrawOffer : DealCommand

    @Serializable
    @SerialName("rate")
    data class Rate(val stars: Int) : DealCommand

    @Serializable
    @SerialName("sendPhotos")
    data class SendPhotos(val urls: List<String>) : DealCommand

    /** The buyer chooses COD to the address on their account; it takes one COD slot until the order closes. */
    @Serializable
    @SerialName("requestCod")
    data object RequestCod : DealCommand

    /** Either side cancels the order while the seller has not created its shipment. */
    @Serializable
    @SerialName("cancelOrder")
    data object CancelOrder : DealCommand

    @Serializable
    @SerialName("createShipment")
    data class CreateShipment(val shipment: NewShipment) : DealCommand

    /** The seller corrects a manual shipment's carrier and code while the carrier has not delivered it. */
    @Serializable
    @SerialName("editTrackingCode")
    data class EditTrackingCode(val carrier: ShipCarrier, val trackingCode: String) : DealCommand

    /** The buyer has the parcel, whatever the carrier reports so far. */
    @Serializable
    @SerialName("confirmReceived")
    data object ConfirmReceived : DealCommand
}
```

- [ ] **Step 5: `Thread.kt`, `Ids.kt`, `People.kt`, `Sellers.kt`, `Account.kt`, `OrderDraft.kt`, `Inbox.kt`**

`Thread.kt`: delete the `Record` item (the last four lines of the sealed interface) and change the `MilestoneKind` line to:

```kotlin
/** AGREED: the price is agreed. HANDED_OVER: the order completed, by the buyer's word or the system's. Chat draws both as event lines. */
@Serializable enum class MilestoneKind { AGREED, HANDED_OVER }
```

`Ids.kt`: replace the `RecordId` class with

```kotlin
@JvmInline @Serializable
value class OrderId(val value: String)
```

`People.kt`: delete `PublicProfile` and its doc comment.

`Sellers.kt`: replace `SellerFacts` with

```kotlin
/** The public numbers behind a seller's tier, over the last 12 months; the tier sheet lists them. */
@Serializable
data class SellerFacts(
    val dealsDone: Int,
    val cancelled: Int,
    val codFailed: Int,
    val codOrders: Int,
    val idChip: Boolean,
    val replyTime: String,
)
```

`Account.kt`: replace `Figures90` and the `DueOrder` doc with

```kotlin
/** The last 90 days as a buyer: COD deliveries that failed, of COD orders. No points are taken for them; sellers judge for themselves. */
@Serializable data class Figures90(val codFailed: Int, val codOrders: Int)
```

```kotlin
/** Tôi's due row: the sale whose order has waited longest for its shipment; [detail] goes under [line]. */
```

`OrderDraft.kt`: replace the file with

```kotlin
package vn.shopnexus.core.model

import kotlinx.serialization.Serializable

/**
 * Đơn bán's "Tạo đơn" as the seller left it, kept per order so a trip to Chat and back, or a closed app, finds it as it
 * was: the tab, the GHTK service, weight and pickup, or the carrier and code typed.
 */
@Serializable
data class OrderDraft(
    val mode: ShipmentMode? = null,
    val weight: String? = null,
    val service: String? = null,
    val pickup: Pickup? = null,
    val carrier: ShipCarrier? = null,
    val trackingCode: String = "",
)
```

`Inbox.kt`: delete `InboxTag.AwaitingShipment` (`@Serializable @SerialName("toShip") data object AwaitingShipment : InboxTag`) and change `AwaitingCreation`'s doc to `/** The buyer chose COD and the seller has not created the shipment. */`.

Then `grep -rn "TimeWindow\|CodShipment\|CodRequest\|CodStatus\|DealStage\|DealEnd\|RefusalReason\|ShipMethod\|IncidentRecord\|RecordStatus\|RecordId\|PublicProfile" core/model/src` prints nothing.

- [ ] **Step 6: Run the model's tests**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:model:test`
Expected: BUILD SUCCESSFUL; `DealJsonTest` 8 tests pass, the rest unchanged.

- [ ] **Step 7: Commit**

```bash
./gradlew :core:model:spotlessApply
git add core/model
git commit -m "feat(model): deals hold orders and shipments as the server does; records go" -- core/model
```

Then stop the daemons as the Global Constraints say.

### Task 2: The rules, the system's moves and the reading of orders

**Files:**
- Modify: `core/domain/src/main/kotlin/vn/shopnexus/core/domain/Orders.kt` (whole file), `DealRules.kt` (whole file), `DealConsole.kt`, `Selling.kt` (four functions and imports), `Standing.kt` (two functions and imports), `Handover.kt`
- Create: `core/domain/src/main/kotlin/vn/shopnexus/core/domain/OrderMoves.kt`
- Test: `core/domain/src/test/kotlin/vn/shopnexus/core/domain/OrderFixtures.kt` (whole file), `DealRulesTest.kt` (whole file), `OrdersTest.kt` (whole file), `OrderMovesTest.kt` (new); ported: `DealConsoleTest.kt`, `DealConsoleRolesTest.kt`, `SellerConsoleTest.kt`, `SellingTest.kt`, `StandingTest.kt`; deleted: `CodFlowTest.kt`, `OrderStatusTest.kt`

**Interfaces:**
- Consumes: Task 1's model.
- Produces: the Task 2 names in "Task order and interfaces". Signatures kept for callers: `inboxTag(deal, me, warning, now)`, `openCodOrders(deals, me, now)`, `orderNote(view, now, zone)`, `dueOrder(views, me, now, zone)`, `DealConsole.state(deal, me, draft, now)` (their `now` and `zone` are read where noted and otherwise carry `@Suppress("UnusedParameter")` as `orderStatus` did).

- [ ] **Step 1: The fixtures and a carrier for the rules**

Replace `core/domain/src/test/kotlin/vn/shopnexus/core/domain/OrderFixtures.kt` with:

```kotlin
package vn.shopnexus.core.domain

import java.time.Duration
import java.time.Instant
import vn.shopnexus.core.model.Condition
import vn.shopnexus.core.model.Deal
import vn.shopnexus.core.model.DealId
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.DealView
import vn.shopnexus.core.model.DeliveryAddress
import vn.shopnexus.core.model.ListingId
import vn.shopnexus.core.model.ListingSummary
import vn.shopnexus.core.model.Me
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Parcel
import vn.shopnexus.core.model.Party
import vn.shopnexus.core.model.Pickup
import vn.shopnexus.core.model.SellerSummary
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.Shipment
import vn.shopnexus.core.model.ShipmentMode
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.ThreadItem
import vn.shopnexus.core.model.Tier
import vn.shopnexus.core.model.UserId
import vn.shopnexus.core.model.Vnd

/** Deals built inline for the order rules; Khánh Linh (`u-linh`) is the signed-in person. */
internal object OrderFixtures {
    val ME = UserId("u-linh")
    val NOW: Instant = Instant.parse("2026-10-15T08:10:00Z")
    val home = DeliveryAddress("Khánh Linh", "09•• ••• 812", "12 Nguyễn Gia Trí")
    private val other = UserId("u-other")

    /** A deal with no order: a talk, an agreed price the buyer has not chosen COD for, or a sale marked some other way. */
    fun deal(id: String = "d-1", selling: Boolean = false, price: Long = 2_300_000, status: DealStatus = DealStatus.AGREED) = Deal(
        id = DealId(id),
        listingId = ListingId("l-$id"),
        buyerId = if (selling) other else ME,
        sellerId = if (selling) ME else other,
        listedPrice = Vnd(price),
        status = status,
        agreedPrice = if (status == DealStatus.NEGOTIATING) null else Vnd(price),
    )

    fun shipment(status: ShipmentStatus = ShipmentStatus.PENDING_PICKUP, mode: ShipmentMode = ShipmentMode.LINKED) = Shipment(
        mode = mode,
        carrier = if (mode == ShipmentMode.LINKED) ShipCarrier.GHTK else ShipCarrier.SPX,
        trackingCode = if (mode == ShipmentMode.LINKED) "GHTK-100001" else "SPXVN1",
        fee = Vnd(22_000),
        status = status,
        deliveredAt = NOW.takeIf { status == ShipmentStatus.DELIVERED },
    )

    /**
     * A deal at 3,8 tr with one order in [status], requested at [requestedAt]. A shipped, completed or failed order carries
     * [shipment]; a closed one closed at [NOW]. The deal stands where that order leaves it.
     */
    fun orderDeal(
        status: OrderStatus,
        selling: Boolean = false,
        shipment: Shipment = shipment(),
        requestedAt: Instant = NOW.minus(Duration.ofHours(2)),
        id: String = "d-1",
    ): Deal {
        val dealStatus = when (status) {
            OrderStatus.PENDING, OrderStatus.SHIPPED -> DealStatus.AGREED
            OrderStatus.COMPLETED -> DealStatus.SOLD
            OrderStatus.FAILED, OrderStatus.CANCELLED -> DealStatus.NEGOTIATING
        }
        val sent = status != OrderStatus.PENDING && status != OrderStatus.CANCELLED
        val order = Order(
            id = OrderId("$id-o1"),
            status = status,
            recipient = home,
            price = Vnd(3_800_000),
            requestedAt = requestedAt,
            shipment = shipment.takeIf { sent },
            shippedAt = requestedAt.plus(Duration.ofMinutes(1)).takeIf { sent },
            closedAt = NOW.takeIf { !(status == OrderStatus.PENDING || status == OrderStatus.SHIPPED) },
        )
        return deal(id = id, selling = selling, price = 3_800_000, status = dealStatus).copy(orders = listOf(order))
    }

    /** The buyer chose COD and the seller has not created the shipment. */
    fun requestDeal(selling: Boolean = false, at: Instant = NOW.minus(Duration.ofHours(1)), id: String = "d-1") =
        orderDeal(OrderStatus.PENDING, selling, requestedAt = at, id = id)

    /** A completed order the buyer has not rated. */
    fun doneDeal(selling: Boolean = false, id: String = "d-1") = orderDeal(OrderStatus.COMPLETED, selling, shipment(ShipmentStatus.DELIVERED), id = id)

    fun view(deal: Deal, lastAt: Instant = NOW) = DealView(
        deal = deal.copy(thread = listOf(ThreadItem.Text(Party.SELLER, "Chào", lastAt))),
        listing = ListingSummary(deal.listingId, "u", deal.listedPrice, "Món", Condition.USED, 1.0),
        counterpart = SellerSummary(other, "Người kia", null, false, Tier.NEW, 0.0, 0, 0, "", 2026),
        me = Me(ME, "Khánh Linh", null, "Bình Thạnh"),
    )

    val account = object : CodAccount {
        override val address = home
    }

    /** What a command needs: the buyer's account, a slot, and [carrier]. */
    fun context(carrier: TestCarrier = TestCarrier(), openCod: Int = 0) = EngineContext(account = account, openCod = openCod, carrier = carrier)
}

/**
 * A carrier for the rules: GHTK-100001 and on for linked shipments; every code found but NOTFOUND…, at the order's price,
 * fee 25.000 ₫, waiting for its pickup, except a code starting with DELIVERED or FAILED, which the carrier reports so.
 */
internal class TestCarrier : CarrierClient {
    private var made = 0

    override fun create(service: String, weightGrams: Int, pickup: Pickup, cod: Vnd) =
        CreatedShipment("GHTK-${100_001 + made++}", waybillFee(GHTK_SERVICES.first { it.id == service }, weightGrams))

    override fun lookup(carrier: ShipCarrier, code: String, order: Order): Parcel? {
        if (code.startsWith("NOTFOUND", ignoreCase = true)) return null
        val status = when {
            code.startsWith("DELIVERED") -> ShipmentStatus.DELIVERED
            code.startsWith("FAILED") -> ShipmentStatus.FAILED
            else -> ShipmentStatus.PENDING_PICKUP
        }
        return Parcel("K••• L•••", "Bình Thạnh", order.price, status, Vnd(25_000))
    }
}
```

- [ ] **Step 2: Write the failing rule tests**

Replace `core/domain/src/test/kotlin/vn/shopnexus/core/domain/DealRulesTest.kt` with:

```kotlin
package vn.shopnexus.core.domain

import com.google.common.truth.Truth.assertThat
import org.junit.Assert.assertThrows
import org.junit.Test
import vn.shopnexus.core.domain.OrderFixtures.NOW
import vn.shopnexus.core.domain.OrderFixtures.context
import vn.shopnexus.core.domain.OrderFixtures.deal
import vn.shopnexus.core.domain.OrderFixtures.doneDeal
import vn.shopnexus.core.domain.OrderFixtures.home
import vn.shopnexus.core.domain.OrderFixtures.orderDeal
import vn.shopnexus.core.domain.OrderFixtures.requestDeal
import vn.shopnexus.core.domain.OrderFixtures.shipment
import vn.shopnexus.core.domain.OrderFixtures.view
import vn.shopnexus.core.model.CancelReason
import vn.shopnexus.core.model.DealCommand
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.MilestoneKind
import vn.shopnexus.core.model.NewShipment
import vn.shopnexus.core.model.OfferStatus
import vn.shopnexus.core.model.OrderId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Party
import vn.shopnexus.core.model.Pickup
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.ShipmentMode
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.ThreadItem
import vn.shopnexus.core.model.Vnd

/** The rules on deals built inline; the fixture-backed walks are in core:data's FakeDealEngine tests. */
class DealRulesTest {
    private fun apply(deal: vn.shopnexus.core.model.Deal, command: DealCommand, ctx: EngineContext = context()) =
        DealRules.apply(view(deal), command, NOW, ctx)

    @Test
    fun aBuyerOfferInRangeOpensAndOneOutsideIsRefused() {
        val talk = deal(status = DealStatus.NEGOTIATING, price = 2_000_000)
        val offered = apply(talk, DealCommand.SendOffer(Vnd(1_800_000), null))
        assertThat(offered.openOffer?.amount).isEqualTo(Vnd(1_800_000))
        assertThat(offered.offers.single().status).isEqualTo(OfferStatus.OPEN)
        assertThrows(IllegalArgumentException::class.java) { apply(talk, DealCommand.SendOffer(Vnd(2_100_000), null)) }
    }

    @Test
    fun requestingCodMakesAPendingOrderAtTheAgreedPrice() {
        val requested = apply(deal(price = 3_800_000), DealCommand.RequestCod)
        val order = requested.orders.single()
        assertThat(order.id).isEqualTo(OrderId("d-1-o1"))
        assertThat(order.status).isEqualTo(OrderStatus.PENDING)
        assertThat(order.recipient).isEqualTo(home)
        assertThat(order.price).isEqualTo(Vnd(3_800_000))
        assertThat(order.requestedAt).isEqualTo(NOW)
        assertThat(requested.status).isEqualTo(DealStatus.AGREED)
        assertThat(requested.thread.last()).isEqualTo(ThreadItem.Event("local_shipping", "Đã chọn giao COD", NOW))
    }

    @Test
    fun onlyTheBuyerRequestsCodWhileAgreedWithNoOpenOrderAndASlot() {
        assertThrows(IllegalStateException::class.java) { apply(deal(selling = true), DealCommand.RequestCod) }
        assertThrows(IllegalStateException::class.java) { apply(deal(status = DealStatus.NEGOTIATING), DealCommand.RequestCod) }
        assertThrows(IllegalStateException::class.java) { apply(requestDeal(), DealCommand.RequestCod) }
        assertThrows(IllegalStateException::class.java) { apply(deal(), DealCommand.RequestCod, context(openCod = 5)) }
    }

    @Test
    fun eitherSideCancelsAPendingOrderAndTheDealNegotiatesAgainWithoutItsPrice() {
        for ((selling, side) in listOf(false to Party.BUYER, true to Party.SELLER)) {
            val cancelled = apply(requestDeal(selling = selling), DealCommand.CancelOrder)
            val order = cancelled.orders.single()
            assertThat(order.status).isEqualTo(OrderStatus.CANCELLED)
            assertThat(order.cancelledBy).isEqualTo(side)
            assertThat(order.cancelReason).isEqualTo(if (selling) CancelReason.SELLER else CancelReason.BUYER)
            assertThat(order.closedAt).isEqualTo(NOW)
            assertThat(cancelled.status).isEqualTo(DealStatus.NEGOTIATING)
            assertThat(cancelled.agreedPrice).isNull()
            assertThat(cancelled.agreedAt).isNull()
            assertThat(cancelled.thread.last()).isEqualTo(ThreadItem.Event("cancel", "Bạn đã hủy đơn", NOW))
        }
        assertThrows(IllegalStateException::class.java) { apply(orderDeal(OrderStatus.SHIPPED), DealCommand.CancelOrder) }
        assertThrows(IllegalStateException::class.java) { apply(deal(), DealCommand.CancelOrder) }
    }

    @Test
    fun theSellerCreatesALinkedShipmentWithTheCarriersCodeAndFee() {
        val shipped = apply(requestDeal(selling = true), DealCommand.CreateShipment(NewShipment.Linked("express", 3_500, Pickup.HOME)))
        val order = shipped.orders.single()
        assertThat(order.status).isEqualTo(OrderStatus.SHIPPED)
        assertThat(order.shippedAt).isEqualTo(NOW)
        val shipment = order.shipment!!
        assertThat(shipment.mode).isEqualTo(ShipmentMode.LINKED)
        assertThat(shipment.carrier).isEqualTo(ShipCarrier.GHTK)
        assertThat(shipment.trackingCode).isEqualTo("GHTK-100001")
        assertThat(shipment.fee).isEqualTo(Vnd(32_000))
        assertThat(shipment.status).isEqualTo(ShipmentStatus.PENDING_PICKUP)
        assertThat(shipped.thread.last()).isEqualTo(ThreadItem.Event("local_shipping", "Đã tạo đơn GHTK · GHTK-100001", NOW))
        assertThrows(IllegalArgumentException::class.java) {
            apply(requestDeal(selling = true), DealCommand.CreateShipment(NewShipment.Linked("rocket", 2_000, Pickup.HOME)))
        }
        for (grams in listOf(0, MAX_WEIGHT_GRAMS + 1)) {
            assertThrows(IllegalArgumentException::class.java) {
                apply(requestDeal(selling = true), DealCommand.CreateShipment(NewShipment.Linked("standard", grams, Pickup.POST_OFFICE)))
            }
        }
        val heaviest = apply(requestDeal(selling = true), DealCommand.CreateShipment(NewShipment.Linked("standard", MAX_WEIGHT_GRAMS, Pickup.POST_OFFICE)))
        assertThat(heaviest.currentOrder!!.status).isEqualTo(OrderStatus.SHIPPED)
    }

    /** A code the carrier already reports failed is refused, on creation and on an edit. */
    @Test
    fun aCodeTheCarrierReportsFailedIsRefused() {
        assertThrows(IllegalArgumentException::class.java) {
            apply(requestDeal(selling = true), DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.GHN, "FAILED1")))
        }
        val manual = orderDeal(OrderStatus.SHIPPED, selling = true, shipment(mode = ShipmentMode.MANUAL))
        assertThrows(IllegalArgumentException::class.java) { apply(manual, DealCommand.EditTrackingCode(ShipCarrier.GHN, "FAILED1")) }
    }

    /** A code the carrier already reports delivered ships as delivered, which starts the 3-day wait for the buyer's word. */
    @Test
    fun aDeliveredCodeShipsAsDelivered() {
        val shipped = apply(requestDeal(selling = true), DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.JT, "DELIVERED1")))
        val shipment = shipped.currentOrder!!.shipment!!
        assertThat(shipment.status).isEqualTo(ShipmentStatus.DELIVERED)
        assertThat(shipment.deliveredAt).isEqualTo(NOW)
        assertThat(shipped.currentOrder!!.status).isEqualTo(OrderStatus.SHIPPED)
    }

    @Test
    fun aManualCodeIsReadFromTheCarrierAndOneItDoesNotKnowIsRefused() {
        val shipped = apply(requestDeal(selling = true), DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.SPX, "  SPXVN1 ")))
        val shipment = shipped.orders.single().shipment!!
        assertThat(shipment.mode).isEqualTo(ShipmentMode.MANUAL)
        assertThat(shipment.trackingCode).isEqualTo("SPXVN1")
        assertThat(shipment.fee).isEqualTo(Vnd(25_000))
        assertThat(shipped.thread.last()).isEqualTo(ThreadItem.Event("local_shipping", "Đã gửi qua SPX · SPXVN1", NOW))
        assertThrows(ShipmentNotFound::class.java) {
            apply(requestDeal(selling = true), DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.SPX, "notfound9")))
        }
        assertThrows(IllegalArgumentException::class.java) {
            apply(requestDeal(selling = true), DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.SPX, "  ")))
        }
        assertThrows(IllegalArgumentException::class.java) {
            apply(requestDeal(selling = true), DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.SPX, "S".repeat(51))))
        }
    }

    @Test
    fun onlyTheSellerCreatesAndOnlyForAPendingOrder() {
        val manual = DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.JT, "JT1"))
        assertThrows(IllegalStateException::class.java) { apply(requestDeal(), manual) }
        assertThrows(IllegalStateException::class.java) { apply(orderDeal(OrderStatus.SHIPPED, selling = true), manual) }
        assertThrows(IllegalStateException::class.java) { apply(deal(selling = true), manual) }
    }

    @Test
    fun aManualCodeIsEditedUntilTheCarrierDeliversIt() {
        val edit = DealCommand.EditTrackingCode(ShipCarrier.GHN, " GHN9 ")
        for (status in listOf(ShipmentStatus.PENDING_PICKUP, ShipmentStatus.IN_TRANSIT)) {
            val edited = apply(orderDeal(OrderStatus.SHIPPED, selling = true, shipment(status, ShipmentMode.MANUAL)), edit)
            val shipment = edited.orders.single().shipment!!
            assertThat(shipment.carrier).isEqualTo(ShipCarrier.GHN)
            assertThat(shipment.trackingCode).isEqualTo("GHN9")
            assertThat(shipment.fee).isEqualTo(Vnd(25_000))
            assertThat(edited.thread.last()).isEqualTo(ThreadItem.Event("edit", "Đã sửa mã vận đơn · GHN GHN9", NOW))
        }
        val manual = orderDeal(OrderStatus.SHIPPED, selling = true, shipment(mode = ShipmentMode.MANUAL))
        assertThrows(IllegalStateException::class.java) {
            apply(orderDeal(OrderStatus.SHIPPED, selling = true, shipment(ShipmentStatus.DELIVERED, ShipmentMode.MANUAL)), edit)
        }
        assertThrows(IllegalStateException::class.java) { apply(orderDeal(OrderStatus.SHIPPED, selling = true), edit) }
        assertThrows(IllegalStateException::class.java) { apply(manual.copy(buyerId = manual.sellerId, sellerId = deal().sellerId), edit) }
        assertThrows(ShipmentNotFound::class.java) { apply(manual, DealCommand.EditTrackingCode(ShipCarrier.GHN, "NOTFOUND")) }
    }

    @Test
    fun theBuyerConfirmsReceiptWhateverTheCarrierSaysSoFar() {
        for (status in listOf(ShipmentStatus.PENDING_PICKUP, ShipmentStatus.IN_TRANSIT, ShipmentStatus.DELIVERED)) {
            val received = apply(orderDeal(OrderStatus.SHIPPED, shipment = shipment(status)), DealCommand.ConfirmReceived)
            assertThat(received.orders.single().status).isEqualTo(OrderStatus.COMPLETED)
            assertThat(received.orders.single().closedAt).isEqualTo(NOW)
            assertThat(received.status).isEqualTo(DealStatus.SOLD)
            assertThat(received.thread.last()).isEqualTo(ThreadItem.Milestone(MilestoneKind.HANDED_OVER, NOW))
        }
        assertThrows(IllegalStateException::class.java) { apply(orderDeal(OrderStatus.SHIPPED, selling = true), DealCommand.ConfirmReceived) }
        assertThrows(IllegalStateException::class.java) { apply(requestDeal(), DealCommand.ConfirmReceived) }
    }

    @Test
    fun aCompletedOrderIsRatedOnce() {
        val rated = apply(doneDeal(), DealCommand.Rate(5))
        assertThat(rated.rating).isEqualTo(5)
        assertThat(rated.ratedAt).isEqualTo(NOW)
        assertThat(rated.thread.last()).isEqualTo(ThreadItem.Event("star", "5 sao cho Người kia", NOW))
        assertThrows(IllegalStateException::class.java) { apply(rated, DealCommand.Rate(4)) }
        assertThrows(IllegalStateException::class.java) { apply(orderDeal(OrderStatus.SHIPPED), DealCommand.Rate(5)) }
        assertThrows(IllegalArgumentException::class.java) { apply(doneDeal(), DealCommand.Rate(0)) }
    }

    @Test
    fun aFailedDealIsBoughtAgainWithASecondOrder() {
        val failed = orderDeal(OrderStatus.FAILED)
        val again = apply(failed, DealCommand.AcceptCounter)
        assertThat(again.status).isEqualTo(DealStatus.AGREED)
        assertThat(again.agreedPrice).isEqualTo(failed.listedPrice)
        val requested = apply(again, DealCommand.RequestCod)
        assertThat(requested.orders.map { it.status }).containsExactly(OrderStatus.FAILED, OrderStatus.PENDING).inOrder()
        assertThat(requested.orders.last().id).isEqualTo(OrderId("d-1-o2"))
        assertThat(requested.currentOrder).isEqualTo(requested.orders.last())
    }
}
```

Create `core/domain/src/test/kotlin/vn/shopnexus/core/domain/OrderMovesTest.kt`:

```kotlin
package vn.shopnexus.core.domain

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import vn.shopnexus.core.domain.OrderFixtures.NOW
import vn.shopnexus.core.domain.OrderFixtures.doneDeal
import vn.shopnexus.core.domain.OrderFixtures.orderDeal
import vn.shopnexus.core.domain.OrderFixtures.requestDeal
import vn.shopnexus.core.domain.OrderFixtures.shipment
import vn.shopnexus.core.model.CancelReason
import vn.shopnexus.core.model.CarrierEvent
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.OrderId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.ThreadItem

class OrderMovesTest {
    private val first = OrderId("d-1-o1")

    @Test
    fun aShipmentMovesWithTheCarriersReports() {
        val event = CarrierEvent("Đến kho Bình Thạnh", NOW)
        val moving = orderDeal(OrderStatus.SHIPPED).shipmentUpdated(ShipmentStatus.IN_TRANSIT, NOW, listOf(event))
        assertThat(moving.currentOrder!!.shipment!!.status).isEqualTo(ShipmentStatus.IN_TRANSIT)
        assertThat(moving.currentOrder!!.shipment!!.events).containsExactly(event)
        val delivered = moving.shipmentUpdated(ShipmentStatus.DELIVERED, NOW.plusSeconds(60))
        assertThat(delivered.currentOrder!!.status).isEqualTo(OrderStatus.SHIPPED)
        assertThat(delivered.currentOrder!!.shipment!!.deliveredAt).isEqualTo(NOW.plusSeconds(60))
        assertThat(delivered.status).isEqualTo(DealStatus.AGREED)
    }

    @Test
    fun aFailedDeliveryFailsTheOrderAndReopensTheDeal() {
        val failed = orderDeal(OrderStatus.SHIPPED, shipment = shipment(ShipmentStatus.IN_TRANSIT)).shipmentUpdated(ShipmentStatus.FAILED, NOW)
        val order = failed.currentOrder!!
        assertThat(order.status).isEqualTo(OrderStatus.FAILED)
        assertThat(order.closedAt).isEqualTo(NOW)
        assertThat(order.shipment!!.status).isEqualTo(ShipmentStatus.FAILED)
        assertThat(failed.status).isEqualTo(DealStatus.NEGOTIATING)
        assertThat(failed.agreedPrice).isNull()
        assertThat(failed.agreedAt).isNull()
        assertThat(failed.thread.last()).isEqualTo(ThreadItem.Event("undo", "Giao không thành", NOW))
    }

    @Test
    fun aLateSignalOnAClosedOrderChangesNothing() {
        for (closed in listOf(doneDeal(), orderDeal(OrderStatus.FAILED), orderDeal(OrderStatus.CANCELLED))) {
            for (status in ShipmentStatus.entries) assertThat(closed.shipmentUpdated(status, NOW)).isEqualTo(closed)
        }
    }

    @Test
    fun theSellerTimeoutCancelsOnlyTheOrderItWasSetFor() {
        val timedOut = requestDeal().sellerTimedOut(first, NOW)
        val order = timedOut.currentOrder!!
        assertThat(order.status).isEqualTo(OrderStatus.CANCELLED)
        assertThat(order.cancelledBy).isNull()
        assertThat(order.cancelReason).isEqualTo(CancelReason.SELLER_TIMEOUT)
        assertThat(timedOut.status).isEqualTo(DealStatus.NEGOTIATING)
        assertThat(timedOut.agreedPrice).isNull()
        assertThat(timedOut.thread.last()).isEqualTo(ThreadItem.Event("cancel", "Đơn tự hủy vì người bán chưa tạo đơn", NOW))
        assertThat(requestDeal().sellerTimedOut(OrderId("d-1-o0"), NOW)).isEqualTo(requestDeal())
        assertThat(orderDeal(OrderStatus.SHIPPED).sellerTimedOut(first, NOW)).isEqualTo(orderDeal(OrderStatus.SHIPPED))
    }

    @Test
    fun thePickupTimeoutCancelsAShipmentNobodyPickedUp() {
        val waiting = orderDeal(OrderStatus.SHIPPED)
        val timedOut = waiting.pickupTimedOut(first, NOW)
        assertThat(timedOut.currentOrder!!.status).isEqualTo(OrderStatus.CANCELLED)
        assertThat(timedOut.currentOrder!!.cancelReason).isEqualTo(CancelReason.PICKUP_TIMEOUT)
        assertThat(timedOut.status).isEqualTo(DealStatus.NEGOTIATING)
        assertThat(timedOut.thread.last()).isEqualTo(ThreadItem.Event("cancel", "Đơn tự hủy vì hãng chưa lấy hàng", NOW))
        val moving = orderDeal(OrderStatus.SHIPPED, shipment = shipment(ShipmentStatus.IN_TRANSIT))
        assertThat(moving.pickupTimedOut(first, NOW)).isEqualTo(moving)
    }

    @Test
    fun autoCompleteNeedsADeliveredShipmentStillOpen() {
        val delivered = orderDeal(OrderStatus.SHIPPED, shipment = shipment(ShipmentStatus.DELIVERED))
        val completed = delivered.autoCompleted(first, NOW)
        assertThat(completed.currentOrder!!.status).isEqualTo(OrderStatus.COMPLETED)
        assertThat(completed.status).isEqualTo(DealStatus.SOLD)
        val moving = orderDeal(OrderStatus.SHIPPED, shipment = shipment(ShipmentStatus.IN_TRANSIT))
        assertThat(moving.autoCompleted(first, NOW)).isEqualTo(moving)
        assertThat(doneDeal().autoCompleted(first, NOW)).isEqualTo(doneDeal())
    }

    @Test
    fun aShipmentToAnotherBuyerCancelsAPendingOrder() {
        val cancelled = requestDeal(selling = true).shippedToAnother(NOW)
        assertThat(cancelled.currentOrder!!.cancelReason).isEqualTo(CancelReason.SHIPPED_TO_ANOTHER)
        assertThat(cancelled.status).isEqualTo(DealStatus.NEGOTIATING)
        assertThat(cancelled.thread.last()).isEqualTo(ThreadItem.Event("cancel", "Đơn đã hủy vì người bán gửi cho người khác", NOW))
        assertThat(orderDeal(OrderStatus.SHIPPED).shippedToAnother(NOW)).isEqualTo(orderDeal(OrderStatus.SHIPPED))
    }
}
```

Replace `core/domain/src/test/kotlin/vn/shopnexus/core/domain/OrdersTest.kt` with:

```kotlin
package vn.shopnexus.core.domain

import com.google.common.truth.Truth.assertThat
import java.time.Duration
import org.junit.Test
import vn.shopnexus.core.domain.OrderFixtures.ME
import vn.shopnexus.core.domain.OrderFixtures.NOW
import vn.shopnexus.core.domain.OrderFixtures.deal
import vn.shopnexus.core.domain.OrderFixtures.doneDeal
import vn.shopnexus.core.domain.OrderFixtures.orderDeal
import vn.shopnexus.core.domain.OrderFixtures.requestDeal
import vn.shopnexus.core.domain.OrderFixtures.shipment
import vn.shopnexus.core.domain.OrderFixtures.view
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.InboxTag
import vn.shopnexus.core.model.Offer
import vn.shopnexus.core.model.OfferStatus
import vn.shopnexus.core.model.OrderId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Party
import vn.shopnexus.core.model.ScamWarning
import vn.shopnexus.core.model.ShipmentMode
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.Tier
import vn.shopnexus.core.model.Vnd
import vn.shopnexus.core.model.WarningSignal

class OrdersTest {
    @Test
    fun theFourStepsFollowTheDealAndItsCurrentOrder() {
        assertThat(phaseOf(deal(status = DealStatus.NEGOTIATING))).isEqualTo(0)
        assertThat(phaseOf(deal())).isEqualTo(1)
        assertThat(phaseOf(requestDeal())).isEqualTo(1)
        assertThat(phaseOf(orderDeal(OrderStatus.SHIPPED))).isEqualTo(2)
        assertThat(phaseOf(doneDeal())).isEqualTo(3)
        assertThat(phaseOf(doneDeal().copy(rating = 5))).isEqualTo(4)
        // A failed or cancelled order sends the deal back to the price talk.
        assertThat(phaseOf(orderDeal(OrderStatus.FAILED))).isEqualTo(0)
        assertThat(phaseOf(orderDeal(OrderStatus.CANCELLED))).isEqualTo(0)
    }

    @Test
    fun anOrdersOwnStepsStopWhereItStopped() {
        fun phase(status: OrderStatus, rating: Int? = null) = phaseOf(orderDeal(status).currentOrder!!, rating)
        assertThat(phase(OrderStatus.PENDING)).isEqualTo(1)
        assertThat(phase(OrderStatus.CANCELLED)).isEqualTo(1)
        assertThat(phase(OrderStatus.SHIPPED)).isEqualTo(2)
        assertThat(phase(OrderStatus.FAILED)).isEqualTo(2)
        assertThat(phase(OrderStatus.COMPLETED)).isEqualTo(3)
        assertThat(phase(OrderStatus.COMPLETED, rating = 4)).isEqualTo(4)
    }

    @Test
    fun inboxTagsFollowTheDealAndItsOrder() {
        val counter = deal(status = DealStatus.NEGOTIATING).copy(offers = listOf(Offer(Party.SELLER, Vnd(10_600_000), NOW, OfferStatus.OPEN)))
        val warning = ScamWarning(listOf(WarningSignal("account_balance", "Đòi chuyển cọc ngoài app")))
        assertThat(inboxTag(counter, ME, null, NOW)).isEqualTo(InboxTag.Counter(Vnd(10_600_000)))
        assertThat(inboxTag(deal(status = DealStatus.NEGOTIATING), ME, warning, NOW)).isEqualTo(InboxTag.Scam)
        assertThat(inboxTag(deal(selling = true, status = DealStatus.NEGOTIATING), ME, null, NOW)).isNull()
        assertThat(inboxTag(requestDeal(selling = true), ME, null, NOW)).isEqualTo(InboxTag.AwaitingCreation)
        assertThat(inboxTag(orderDeal(OrderStatus.SHIPPED, selling = true), ME, null, NOW)).isEqualTo(InboxTag.Agreed(Vnd(3_800_000)))
        assertThat(inboxTag(requestDeal(), ME, null, NOW)).isEqualTo(InboxTag.Agreed(Vnd(3_800_000)))
        assertThat(inboxTag(doneDeal(selling = true), ME, null, NOW)).isEqualTo(InboxTag.Sold(Vnd(3_800_000)))
        assertThat(inboxTag(doneDeal(), ME, null, NOW)).isNull()
        assertThat(inboxTag(orderDeal(OrderStatus.FAILED), ME, null, NOW)).isNull()
    }

    @Test
    fun openCodOrdersCountPendingAndShippedOnesAsBuyer() {
        val deals = listOf(
            requestDeal(id = "a"),
            orderDeal(OrderStatus.SHIPPED, id = "b"),
            doneDeal(id = "c"),
            orderDeal(OrderStatus.FAILED, id = "d"),
            orderDeal(OrderStatus.CANCELLED, id = "e"),
            requestDeal(selling = true, id = "f"),
            deal(id = "g"),
        )
        assertThat(openCodOrders(deals, ME, NOW)).isEqualTo(2)
    }

    @Test
    fun codSlotsCountThisOrderAgainstTheCap() {
        val rights = rightsFor(Tier.TRUSTED, Stats90(0, 0, null), NOW)
        assertThat(codSlots(rights, 0, NOW)).isEqualTo(CodSlots(after = 1, cap = 5, fits = true))
        assertThat(codSlots(rights, 4, NOW)).isEqualTo(CodSlots(after = 5, cap = 5, fits = true))
        assertThat(codSlots(rights, 5, NOW)).isEqualTo(CodSlots(after = 6, cap = 5, fits = false))
        val blocked = rights.copy(codBlockedUntil = NOW.plus(Duration.ofDays(1)))
        assertThat(codSlots(blocked, 0, NOW).fits).isFalse()
        assertThat(codSlots(blocked, 0, NOW.plus(Duration.ofDays(1))).fits).isTrue()
    }

    /** A deal that failed and was bought again has two rows; the newer order comes first. */
    @Test
    fun orderRowsHoldOneRowPerOrderNewestFirst() {
        val failed = orderDeal(OrderStatus.FAILED, requestedAt = NOW.minus(Duration.ofDays(4)), id = "again")
        val first = failed.currentOrder!!.copy(closedAt = NOW.minus(Duration.ofDays(3)))
        val second = first.copy(id = OrderId("again-o2"), status = OrderStatus.PENDING, shipment = null, shippedAt = null, closedAt = null, requestedAt = NOW)
        val again = view(failed.copy(status = DealStatus.AGREED, agreedPrice = Vnd(3_800_000), orders = listOf(first, second)), NOW)
        val older = view(orderDeal(OrderStatus.SHIPPED, requestedAt = NOW.minus(Duration.ofDays(2)), id = "old"), NOW.minus(Duration.ofDays(2)))
        val selling = view(requestDeal(selling = true, id = "sell"), NOW)
        val talking = view(deal(id = "talk", status = DealStatus.NEGOTIATING), NOW)
        val rows = orderRows(listOf(older, talking, selling, again), Party.BUYER)
        assertThat(rows.map { it.order.id.value }).containsExactly("again-o2", "old-o1", "again-o1").inOrder()
        assertThat(orderRows(listOf(older, talking, selling, again), Party.SELLER).map { it.order.id.value }).containsExactly("sell-o1")
    }

    @Test
    fun aDealIsAnOrderOnceCodIsRequestedWhateverCameOfIt() {
        assertThat(isOrder(deal())).isFalse()
        assertThat(isOrder(requestDeal())).isTrue()
        assertThat(isOrder(orderDeal(OrderStatus.FAILED))).isTrue()
    }

    /** GHTK's fee: the service's up to 2 kg, then 5.000 ₫ (Giao nhanh) or 4.000 ₫ (Tiết kiệm) per started kilo. */
    @Test
    fun aLinkedShipmentsFeeGrowsPerStartedKilo() {
        val (express, standard) = GHTK_SERVICES
        assertThat(express.id to standard.id).isEqualTo("express" to "standard")
        assertThat(waybillFee(express, 500)).isEqualTo(Vnd(22_000))
        assertThat(waybillFee(express, 2_000)).isEqualTo(Vnd(22_000))
        assertThat(waybillFee(express, 2_001)).isEqualTo(Vnd(27_000))
        assertThat(waybillFee(express, 4_000)).isEqualTo(Vnd(32_000))
        assertThat(waybillFee(standard, 4_000)).isEqualTo(Vnd(24_000))
    }

    @Test
    fun cancellingAndEditingFollowTheOrder() {
        assertThat(canCancel(requestDeal())).isTrue()
        assertThat(canCancel(orderDeal(OrderStatus.SHIPPED))).isFalse()
        assertThat(canCancel(deal())).isFalse()
        fun manual(status: ShipmentStatus) = orderDeal(OrderStatus.SHIPPED, shipment = shipment(status, ShipmentMode.MANUAL)).currentOrder!!
        assertThat(canEditTrackingCode(manual(ShipmentStatus.PENDING_PICKUP))).isTrue()
        assertThat(canEditTrackingCode(manual(ShipmentStatus.IN_TRANSIT))).isTrue()
        assertThat(canEditTrackingCode(manual(ShipmentStatus.DELIVERED))).isFalse()
        assertThat(canEditTrackingCode(orderDeal(OrderStatus.SHIPPED).currentOrder!!)).isFalse()
    }
}
```

Delete `core/domain/src/test/kotlin/vn/shopnexus/core/domain/CodFlowTest.kt` and `OrderStatusTest.kt` (`git rm`): every rule they held is above or gone with the spec.

- [ ] **Step 3: Port the console, selling and standing tests**

Mechanical rules for the three console tests, `SellingTest` and `StandingTest`:
- `deal(…, stage = DealStage.NEGOTIATE)` → `deal(…, status = DealStatus.NEGOTIATING)`; `stage = DealStage.ARRANGE` or `HANDOVER` on a deal with no order → `status = DealStatus.AGREED`; `countered.copy(stage = …)` in `DealConsoleTest` likewise (`DealStage.RATE` → `status = DealStatus.SOLD` plus `orders = OrderFixtures.doneDeal().orders`).
- `codDeal(CodStatus.PLACED | SHIPPING | AT_DOOR, …, placedAt = x)` → `orderDeal(OrderStatus.SHIPPED, …, requestedAt = x)`; `CodStatus.RECEIVED` → `orderDeal(OrderStatus.COMPLETED, …, shipment = shipment(ShipmentStatus.DELIVERED))` or `doneDeal(…)`; `CodStatus.REFUSED` → `orderDeal(OrderStatus.FAILED, …)`; `.copy(handedOverAt = NOW)` is dropped (a completed fixture closed at `NOW`); `.copy(stage = DealStage.DONE, rating = 5)` → `.copy(rating = 5)`.
- Imports: `CodStatus`, `DealStage`, `DealEnd`, `RecordStatus`, `OrderFixtures.codDeal`, `OrderFixtures.record` out; `DealStatus`, `OrderStatus`, `ShipmentStatus`, `OrderFixtures.orderDeal`, `OrderFixtures.shipment` in as needed. `DealConsole.state(…)` keeps its four arguments.

Tests whose meaning changes, with their new bodies:

`DealConsoleTest`: delete `aRecordReplacesTheStars`; `ratingBecomesACommand` becomes

```kotlin
    @Test
    fun ratingBecomesACommand() {
        val received = countered.copy(status = DealStatus.SOLD, agreedPrice = Vnd(10_600_000), orders = OrderFixtures.doneDeal().orders)
        assertThat(DealConsole.state(received, me, idle, t)).isEqualTo(ConsoleState.Received)
        assertThat(DealConsole.reduce(received, idle, ConsoleEvent.Rate(5)).command).isEqualTo(DealCommand.Rate(5))
        assertThat(DealConsole.state(received.copy(rating = 5), me, idle, t)).isEqualTo(ConsoleState.Done(5))
    }
```

`DealConsoleRolesTest`: `theBuyerFollowsTheParcelUntilItIsReceived`, `theSellerShipsAndThenIsDone` and `aParcelWaitingLongStaysAnOrderForBothSides` become

```kotlin
    @Test
    fun theBuyerFollowsTheOrderUntilItIsReceived() {
        val price = Vnd(3_800_000)
        val pending = requestDeal()
        assertThat(state(pending)).isEqualTo(ConsoleState.OrderStep(pending.currentOrder!!, price))
        val shipped = orderDeal(OrderStatus.SHIPPED)
        assertThat(state(shipped)).isEqualTo(ConsoleState.OrderStep(shipped.currentOrder!!, price))
        assertThat(state(doneDeal())).isEqualTo(ConsoleState.Received)
        // A failed delivery: the deal talks price again, from the listed price.
        assertThat(state(orderDeal(OrderStatus.FAILED))).isEqualTo(ConsoleState.Countered(Vnd(3_800_000), null, null, listed = true))
    }

    @Test
    fun theSellerCreatesTheShipmentAndThenIsDone() {
        val price = Vnd(3_800_000)
        val pending = requestDeal(selling = true)
        assertThat(state(pending)).isEqualTo(ConsoleState.OrderStep(pending.currentOrder!!, price))
        val shipped = orderDeal(OrderStatus.SHIPPED, selling = true, shipment = shipment(ShipmentStatus.DELIVERED))
        assertThat(state(shipped)).isEqualTo(ConsoleState.OrderStep(shipped.currentOrder!!, price))
        assertThat(state(doneDeal(selling = true))).isEqualTo(ConsoleState.Done(0))
        assertThat(state(orderDeal(OrderStatus.CANCELLED, selling = true))).isEqualTo(ConsoleState.Selling(Vnd(3_800_000)))
    }
```

and `aRatedSaleIsDone` keeps its body.

`SellerConsoleTest`: delete `aRecordAfterTheRatingAsksTheSellerToAnswer`; `theSellerWaitsForTheBuyersCod` uses `deal(selling = true)`.

`SellingTest`: `askersSayWhatTheyDid`, `orderNotesSpeakOnlyOfCod`, `anOpenOrderIsOneBeforeItsHandOver`, `aHandedOverDealSellsTheListing` become

```kotlin
    @Test
    fun askersSayWhatTheyDid() {
        val asking = deal(selling = true, status = DealStatus.NEGOTIATING)
        val offered = asking.copy(offers = listOf(Offer(Party.BUYER, Vnd(1_800_000), NOW, OfferStatus.OPEN)))
        assertThat(askerLine(view(offered), NOW, zone)).isEqualTo("Trả giá 1,8 tr")
        assertThat(askerLine(view(orderDeal(OrderStatus.SHIPPED, selling = true, requestedAt = NOW.minus(day))), NOW, zone)).isEqualTo("Chọn COD hôm qua")
        assertThat(askerLine(view(requestDeal(selling = true, at = NOW.minusSeconds(60))), NOW, zone)).isEqualTo("Chọn COD hôm nay")
        // A closed order is no longer what the asker did; the deal talks price again.
        assertThat(askerLine(view(orderDeal(OrderStatus.FAILED, selling = true)), NOW, zone)).isEqualTo("Hỏi hôm nay")
        assertThat(askerLine(view(asking), NOW, zone)).isEqualTo("Hỏi hôm nay")
        assertThat(askerLine(view(asking, NOW.minus(Duration.ofDays(3))), NOW, zone)).isEqualTo("Hỏi thứ Hai")
    }

    @Test
    fun orderNotesSpeakOnlyOfCod() {
        val toCreate = orderNote(view(requestDeal(selling = true)), NOW, zone)!!
        assertThat(toCreate.icon).isEqualTo("receipt_long")
        assertThat(toCreate.text).isEqualTo("Đơn COD · chờ bạn tạo đơn")
        assertThat(orderNote(view(orderDeal(OrderStatus.SHIPPED, selling = true)), NOW, zone)!!.text).isEqualTo("Đơn COD · đang giao")
        assertThat(orderNote(view(deal(selling = true)), NOW, zone)).isNull()
        assertThat(orderNote(view(doneDeal(selling = true)), NOW, zone)).isNull()
        assertThat(orderNote(view(orderDeal(OrderStatus.FAILED, selling = true)), NOW, zone)).isNull()
    }

    @Test
    fun anOpenOrderIsPendingOrShipped() {
        val listing = ListingId("l-d-1")
        assertThat(openOrder(listOf(view(requestDeal(selling = true))), listing, NOW)).isNotNull()
        assertThat(openOrder(listOf(view(orderDeal(OrderStatus.SHIPPED, selling = true))), listing, NOW)).isNotNull()
        assertThat(openOrder(listOf(view(doneDeal(selling = true))), listing, NOW)).isNull()
        assertThat(openOrder(listOf(view(orderDeal(OrderStatus.CANCELLED, selling = true))), listing, NOW)).isNull()
        assertThat(openOrder(listOf(view(orderDeal(OrderStatus.FAILED, selling = true))), listing, NOW)).isNull()
        assertThat(openOrder(listOf(view(deal(selling = true, status = DealStatus.NEGOTIATING))), listing, NOW)).isNull()
        assertThat(openOrder(listOf(view(requestDeal(selling = true))), ListingId("other"), NOW)).isNull()
    }

    @Test
    fun aCompletedOrderSellsTheListingAndAFailedOneDoesNot() {
        val listing = own("l-d-1", sale = Sale(UserId("u-trang"), NOW.minus(day), 5))
        val sold = doneDeal(selling = true)
        assertThat(soldBy(listing, listOf(view(sold)))).isEqualTo(Sale(sold.buyerId, NOW, null, DealId("d-1"), sold.agreedPrice))
        // A sale through a deal is at the price the two agreed, not the listed one.
        assertThat(soldBy(listing, listOf(view(sold.copy(agreedPrice = Vnd(2_000_000)))))!!.price).isEqualTo(Vnd(2_000_000))
        assertThat(soldBy(listing, listOf(view(sold.copy(rating = 5))))!!.stars).isEqualTo(5)
        assertThat(soldBy(listing, emptyList())).isEqualTo(Sale(UserId("u-trang"), NOW.minus(day), 5))
        assertThat(soldBy(own("l-d-1"), listOf(view(orderDeal(OrderStatus.FAILED, selling = true))))).isNull()
        assertThat(soldBy(own("l-d-1"), listOf(view(orderDeal(OrderStatus.SHIPPED, selling = true))))).isNull()
    }
```

and in `theWeekSumsListingsOnSale` the views become `view(deal(id = "a", selling = true, status = DealStatus.NEGOTIATING), NOW)`, `view(orderDeal(OrderStatus.SHIPPED, selling = true, id = "b"), NOW.minus(day))`, `view(deal(id = "a2", selling = true, status = DealStatus.NEGOTIATING).copy(listingId = ListingId("l-a")), NOW.minus(Duration.ofDays(8)))`, `view(doneDeal(selling = true, id = "c").copy(listingId = ListingId("l-c")), NOW)`; the expected `WeekStats(55, 2, 3)` stays.

`StandingTest`: delete `theFiguresCountTheSellersRecords` and `selfShippedOrdersStayOutOfTheRecordFigures`; `theDueOrderIsARequestToCreate` becomes

```kotlin
    @Test
    fun theDueOrderIsTheOldestOrderWaitingForItsShipment() {
        val older = view(requestDeal(selling = true, at = NOW.minus(Duration.ofHours(22)), id = "d-cod"))
        val newer = view(requestDeal(selling = true, at = NOW.minus(Duration.ofHours(1)), id = "d-new"))
        val shipped = view(orderDeal(OrderStatus.SHIPPED, selling = true, id = "d-shipped"))
        val agreed = view(deal("d-agreed", selling = true))
        val due = dueOrder(listOf(agreed, shipped, newer, older), OrderFixtures.ME, NOW, VN_ZONE)!!
        assertThat(due.dealId).isEqualTo(DealId("d-cod"))
        assertThat(due.icon).isEqualTo("receipt_long")
        assertThat(due.line).isEqualTo("Tạo đơn cho Người kia")
        assertThat(due.detail).isEqualTo("Món · chờ từ 17:10")
        // An agreed sale waits for the buyer, a shipped one for the carrier; nothing is due from the seller.
        assertThat(dueOrder(listOf(agreed, shipped), OrderFixtures.ME, NOW, VN_ZONE)).isNull()
        assertThat(dueOrder(listOf(view(requestDeal(id = "d-buy"))), OrderFixtures.ME, NOW, VN_ZONE)).isNull()
    }
```

- [ ] **Step 4: Run them to see them fail**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:domain:test`
Expected: compilation fails (`DealStatus` unknown to `DealRules.kt`, `orderDeal`, `shipmentUpdated`, `CarrierClient` unresolved).

- [ ] **Step 5: `Orders.kt`**

Replace `core/domain/src/main/kotlin/vn/shopnexus/core/domain/Orders.kt` with:

```kotlin
package vn.shopnexus.core.domain

import java.time.Instant
import vn.shopnexus.core.model.Deal
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.DealView
import vn.shopnexus.core.model.InboxTag
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Party
import vn.shopnexus.core.model.ScamWarning
import vn.shopnexus.core.model.ShipmentMode
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.UserId

fun roleOf(deal: Deal, me: UserId): Party = if (deal.sellerId == me) Party.SELLER else Party.BUYER

/** A deal is an order once the buyer has requested COD on it, whatever came of the request. */
fun isOrder(deal: Deal): Boolean = deal.orders.isNotEmpty()

/** Either side may cancel while the seller has not created the shipment. */
fun canCancel(deal: Deal): Boolean = deal.openOrder?.status == OrderStatus.PENDING

/** A manual shipment's code can be corrected until the carrier delivers it. */
fun canEditTrackingCode(order: Order): Boolean {
    val shipment = order.shipment ?: return false
    return order.status == OrderStatus.SHIPPED && shipment.mode == ShipmentMode.MANUAL &&
        (shipment.status == ShipmentStatus.PENDING_PICKUP || shipment.status == ShipmentStatus.IN_TRANSIT)
}

/** The id the next order on [this] deal takes: "d-huy-o2" for its second. */
fun Deal.nextOrderId(): OrderId = OrderId("${id.value}-o${orders.size + 1}")

private const val PHASE_CREATE = 1
private const val PHASE_RECEIVE = 2
private const val PHASE_RATE = 3
private const val PHASE_DONE = 4

/**
 * The four steps (Thương lượng, Tạo đơn, Nhận hàng, Đánh giá) for the deal as it stands: 0 to 3 is the step in progress,
 * 4 means all four are done. A deal whose order failed or was cancelled talks price again, so it is back on the first.
 */
fun phaseOf(deal: Deal): Int = when (deal.status) {
    DealStatus.NEGOTIATING -> 0
    DealStatus.AGREED -> if (deal.openOrder?.status == OrderStatus.SHIPPED) PHASE_RECEIVE else PHASE_CREATE
    DealStatus.SOLD -> if (deal.rating == null) PHASE_RATE else PHASE_DONE
}

/** The same steps for one order, where it stopped: a cancelled order on Tạo đơn, a failed one on Nhận hàng. */
fun phaseOf(order: Order, rating: Int?): Int = when (order.status) {
    OrderStatus.PENDING, OrderStatus.CANCELLED -> PHASE_CREATE
    OrderStatus.SHIPPED, OrderStatus.FAILED -> PHASE_RECEIVE
    OrderStatus.COMPLETED -> if (rating == null) PHASE_RATE else PHASE_DONE
}

/** One row of Đơn hàng: an order and the deal it belongs to. */
data class OrderRow(val view: DealView, val order: Order)

/** The newest thing that happened to the order; the current one also moves with its chat. */
private fun OrderRow.lastActivity(): Instant {
    val current = view.deal.currentOrder?.id == order.id
    return listOfNotNull(
        order.requestedAt,
        order.shippedAt,
        order.closedAt,
        order.shipment?.events?.maxOfOrNull { it.at },
        view.deal.thread.maxOfOrNull { it.at }.takeIf { current },
        view.deal.ratedAt.takeIf { current },
    ).max()
}

/** The orders on one side of Đơn hàng, one row each, newest activity first. */
fun orderRows(views: List<DealView>, side: Party): List<OrderRow> = views
    .filter { roleOf(it.deal, it.me.id) == side }
    .flatMap { view -> view.deal.orders.map { OrderRow(view, it) } }
    .sortedByDescending { it.lastActivity() }

/** The status tag of a conversation in Tin nhắn; [now] is kept for callers and changes nothing, since no tag tells time. */
@Suppress("UnusedParameter")
fun inboxTag(deal: Deal, me: UserId, warning: ScamWarning?, now: Instant): InboxTag? {
    if (warning != null) return InboxTag.Scam
    val agreed = deal.agreedPrice
    val selling = roleOf(deal, me) == Party.SELLER
    return when (deal.status) {
        DealStatus.NEGOTIATING -> deal.openCounter?.let { InboxTag.Counter(it.amount) }
        DealStatus.AGREED ->
            if (selling && deal.openOrder?.status == OrderStatus.PENDING) InboxTag.AwaitingCreation else agreed?.let { InboxTag.Agreed(it) }
        DealStatus.SOLD -> if (selling) agreed?.let { InboxTag.Sold(it) } else null
    }
}

/**
 * The COD orders the person is waiting for as a buyer: pending or shipped. A request counts from the moment it is sent,
 * and a closed one stops counting; the count does not read [now].
 */
@Suppress("UnusedParameter")
fun openCodOrders(deals: List<Deal>, me: UserId, now: Instant): Int = deals.count { roleOf(it, me) == Party.BUYER && it.openOrder != null }

/** "COD của bạn: 1/5 đơn đang mở sau đơn này": the count with this order, the cap, and whether it fits. */
data class CodSlots(val after: Int, val cap: Int, val fits: Boolean)

fun codSlots(rights: Rights, openCod: Int, now: Instant): CodSlots {
    val after = openCod + 1
    val blocked = rights.codBlockedUntil?.let { now.isBefore(it) } ?: false
    return CodSlots(after, rights.codOpenCap, after <= rights.codOpenCap && !blocked)
}
```

- [ ] **Step 6: `OrderMoves.kt`**

Create `core/domain/src/main/kotlin/vn/shopnexus/core/domain/OrderMoves.kt`:

```kotlin
package vn.shopnexus.core.domain

import java.time.Duration
import java.time.Instant
import vn.shopnexus.core.model.CancelReason
import vn.shopnexus.core.model.CarrierEvent
import vn.shopnexus.core.model.Deal
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.MilestoneKind
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Party
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.ThreadItem

// What the system does to an order, beside the people's commands in DealRules: the carrier's reports, the timers and
// another buyer's shipment. Each reads the order as it is and leaves a closed one alone.

/** How long a pending order waits for its shipment, a shipment for its pickup, and a delivered parcel for the buyer's word. */
val ORDER_WAIT: Duration = Duration.ofDays(3)

/** [this] deal with [order] in place of its current order. */
fun Deal.withOrder(order: Order): Deal = copy(orders = orders.dropLast(1) + order)

/** The deal after its agreement is dropped: it talks price again, as after the server's `reopen`. */
private fun Deal.reopened(): Deal = copy(status = DealStatus.NEGOTIATING, agreedPrice = null, agreedAt = null)

/**
 * The carrier reports [status] for the current order's shipment, with [events]. DELIVERED sets `deliveredAt`; FAILED
 * fails the order at once and the deal talks price again. A report for a closed order changes nothing.
 */
fun Deal.shipmentUpdated(status: ShipmentStatus, now: Instant, events: List<CarrierEvent> = emptyList()): Deal {
    val order = openOrder?.takeIf { it.status == OrderStatus.SHIPPED } ?: return this
    val shipment = checkNotNull(order.shipment) { "A shipped order has a shipment" }
    val moved = shipment.copy(
        status = status,
        events = shipment.events + events,
        deliveredAt = if (status == ShipmentStatus.DELIVERED) now else shipment.deliveredAt,
    )
    if (status != ShipmentStatus.FAILED) return withOrder(order.copy(shipment = moved))
    return withOrder(order.copy(status = OrderStatus.FAILED, shipment = moved, closedAt = now)).reopened()
        .copy(thread = thread + ThreadItem.Event("undo", "Giao không thành", now))
}

/** The buyer has the parcel, by their word or the system's: the order completes and the deal is sold. */
fun Deal.completed(now: Instant): Deal {
    val order = checkNotNull(openOrder?.takeIf { it.status == OrderStatus.SHIPPED }) { "No shipped order to complete" }
    return withOrder(order.copy(status = OrderStatus.COMPLETED, closedAt = now))
        .copy(status = DealStatus.SOLD, thread = thread + ThreadItem.Milestone(MilestoneKind.HANDED_OVER, now))
}

/** The open order ends [by] a side (null: the system) for [reason]; the deal talks price again and the thread says [line]. */
fun Deal.cancelled(by: Party?, reason: CancelReason, now: Instant, line: String): Deal {
    val order = checkNotNull(openOrder) { "No open order to cancel" }
    return withOrder(order.copy(status = OrderStatus.CANCELLED, cancelledBy = by, cancelReason = reason, closedAt = now)).reopened()
        .copy(thread = thread + ThreadItem.Event("cancel", line, now))
}

/** [order] waited 3 days for its shipment. Nothing happens if it is not the open order, or not pending any more. */
fun Deal.sellerTimedOut(order: OrderId, now: Instant): Deal {
    if (openOrder?.takeIf { it.id == order }?.status != OrderStatus.PENDING) return this
    return cancelled(null, CancelReason.SELLER_TIMEOUT, now, "Đơn tự hủy vì người bán chưa tạo đơn")
}

/** [order]'s shipment waited 3 days for its pickup; a linked one is cancelled at the carrier too (part 2). */
fun Deal.pickupTimedOut(order: OrderId, now: Instant): Deal {
    val open = openOrder?.takeIf { it.id == order && it.status == OrderStatus.SHIPPED } ?: return this
    if (open.shipment?.status != ShipmentStatus.PENDING_PICKUP) return this
    return cancelled(null, CancelReason.PICKUP_TIMEOUT, now, "Đơn tự hủy vì hãng chưa lấy hàng")
}

/** 3 days after the carrier delivered [order] and the buyer said nothing, it completes. */
fun Deal.autoCompleted(order: OrderId, now: Instant): Deal {
    val open = openOrder?.takeIf { it.id == order && it.status == OrderStatus.SHIPPED } ?: return this
    if (open.shipment?.status != ShipmentStatus.DELIVERED) return this
    return completed(now)
}

/** The seller created a shipment for another buyer of the same listing: this deal's pending order is cancelled. */
fun Deal.shippedToAnother(now: Instant): Deal {
    if (openOrder?.status != OrderStatus.PENDING) return this
    return cancelled(null, CancelReason.SHIPPED_TO_ANOTHER, now, "Đơn đã hủy vì người bán gửi cho người khác")
}
```

- [ ] **Step 7: `DealRules.kt`**

Replace `core/domain/src/main/kotlin/vn/shopnexus/core/domain/DealRules.kt` with:

```kotlin
package vn.shopnexus.core.domain

import java.time.Instant
import kotlin.math.absoluteValue
import vn.shopnexus.core.model.CancelReason
import vn.shopnexus.core.model.Deal
import vn.shopnexus.core.model.DealCommand
import vn.shopnexus.core.model.DealId
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.DealView
import vn.shopnexus.core.model.DeliveryAddress
import vn.shopnexus.core.model.MilestoneKind
import vn.shopnexus.core.model.NewShipment
import vn.shopnexus.core.model.Offer
import vn.shopnexus.core.model.OfferStatus
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Parcel
import vn.shopnexus.core.model.Party
import vn.shopnexus.core.model.Pickup
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.Shipment
import vn.shopnexus.core.model.ShipmentMode
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.ThreadItem
import vn.shopnexus.core.model.Vnd

/** What COD reads from the signed-in person's account: where a buyer's parcel goes. The GHTK services are [GHTK_SERVICES]. */
interface CodAccount {
    val address: DeliveryAddress
}

/** A shipment the carrier created on the seller's linked account: its tracking code and the fee it charges. */
data class CreatedShipment(val trackingCode: String, val fee: Vnd?)

/** The carriers ShopNexus reads, as the server's carrier provider has them. */
interface CarrierClient {
    /** Creates a shipment on the seller's linked GHTK account for [cod] at the door. */
    fun create(service: String, weightGrams: Int, pickup: Pickup, cod: Vnd): CreatedShipment

    /**
     * What [carrier] knows of [code]; null when it does not know it. [order] is the order the seller ships, which the
     * fake answers with; a real client reads only the carrier and the code.
     */
    fun lookup(carrier: ShipCarrier, code: String, order: Order): Parcel?
}

/** The carrier does not know the tracking code, so it cannot be confirmed. */
class ShipmentNotFound(carrier: ShipCarrier, code: String) : IllegalArgumentException("${carrier.label} does not know $code")

/** What a command needs beyond the deal: the account, how many COD orders the buyer has open, the buyer's rights, the carrier. */
data class EngineContext(
    val account: CodAccount? = null,
    val openCod: Int = 0,
    val rights: Rights = Rights(codOpenCap = 5, listingCap = 20, codBlockedUntil = null),
    val carrier: CarrierClient? = null,
)

/** A tracking code is 1 to 50 characters, as the server stores it. */
const val TRACKING_CODE_MAX = 50

private const val ORDER_CODE_MIN = 10_000
private const val ORDER_CODE_SPAN = 90_000
private const val MESSAGE_MAX = 1_000
private const val MESSAGE_PHOTOS_MAX = 4
private const val STARS_MAX = 5

/** The order number a deal gets at agreement: "SN-" and five digits from its id. */
fun orderCode(id: DealId): String = "SN-%05d".format(id.value.hashCode().absoluteValue % ORDER_CODE_SPAN + ORDER_CODE_MIN)

/** The agreed price, its time and the order number, with [accepted] marked and every other open offer superseded. */
fun Deal.agreed(price: Vnd, accepted: Offer?, now: Instant): Deal = copy(
    status = DealStatus.AGREED,
    agreedPrice = price,
    agreedAt = now,
    code = code ?: orderCode(id),
    offers = offers.map {
        when {
            it == accepted -> it.copy(status = OfferStatus.ACCEPTED)
            it.status == OfferStatus.OPEN -> it.copy(status = OfferStatus.SUPERSEDED)
            else -> it
        }
    },
)

/**
 * What the backend does with a command: who may send it in which state, the offer ranges, the COD slot check and the
 * deal after it. The buyer requests COD; the seller creates the shipment, on the linked GHTK account or with a code
 * from a carrier's own app; either side cancels while it is pending; the buyer confirms receipt and rates.
 */
object DealRules {
    /** Applies one command to a deal; wrong amounts, commands out of order and commands from the wrong side throw. */
    fun apply(view: DealView, command: DealCommand, now: Instant, context: EngineContext = EngineContext()): Deal {
        val turn = Turn(view, command, now, context)
        return when (command) {
            is DealCommand.SendText -> turn.sendText(command)
            is DealCommand.SendPhotos -> turn.sendPhotos(command)
            is DealCommand.SendOffer -> if (turn.me == Party.SELLER) turn.counter(command) else turn.offer(command)
            DealCommand.AcceptCounter -> if (turn.me == Party.SELLER) turn.acceptOffer() else turn.acceptCounter()
            DealCommand.WithdrawOffer -> turn.withdrawOffer()
            is DealCommand.Rate -> turn.rate(command)
            DealCommand.RequestCod -> turn.requestCod()
            DealCommand.CancelOrder -> turn.cancelOrder()
            is DealCommand.CreateShipment -> turn.createShipment(command)
            is DealCommand.EditTrackingCode -> turn.editTrackingCode(command)
            DealCommand.ConfirmReceived -> turn.confirmReceived()
        }
    }

    /** One command from one side: the deal before it, who sent it, and the deal after each kind of command. */
    private class Turn(val view: DealView, val command: DealCommand, val now: Instant, val context: EngineContext) {
        val deal = view.deal
        val me = roleOf(deal, view.me.id)

        private fun buyer() = check(me == Party.BUYER) { "Only the buyer can $command" }

        private fun seller() = check(me == Party.SELLER) { "Only the seller can $command" }

        private fun carrier(): CarrierClient = checkNotNull(context.carrier) { "No carrier" }

        fun sendText(command: DealCommand.SendText): Deal {
            require(command.text.isNotBlank() && command.text.length <= MESSAGE_MAX) { "A message is 1 to 1000 characters" }
            return deal.copy(thread = deal.thread + ThreadItem.Text(me, command.text.trim(), now))
        }

        fun sendPhotos(command: DealCommand.SendPhotos): Deal {
            require(command.urls.size in 1..MESSAGE_PHOTOS_MAX) { "One to four photos" }
            return deal.copy(thread = deal.thread + ThreadItem.Photos(me, command.urls, now))
        }

        /** The seller's counter to the open offer. */
        fun counter(command: DealCommand.SendOffer): Deal {
            check(deal.status == DealStatus.NEGOTIATING) { "No counter can be made now" }
            val offer = checkNotNull(deal.openOffer) { "No offer to counter" }
            require(counterRange(offer.amount, deal.listedPrice).check(command.amount) is OfferCheck.Ok) {
                "Counter ${command.amount} is outside the range"
            }
            return deal.copy(
                offers = deal.offers.map { if (it == offer) it.copy(status = OfferStatus.SUPERSEDED) else it } +
                    Offer(Party.SELLER, command.amount, now, OfferStatus.OPEN),
                thread = deal.thread + ThreadItem.PriceMove(Party.SELLER, command.amount, false, now) +
                    listOfNotNull(command.note?.let { ThreadItem.Text(Party.SELLER, it, now) }),
            )
        }

        /** The buyer's offer, inside the range the listed price and any open counter allow. */
        fun offer(command: DealCommand.SendOffer): Deal {
            check(deal.status == DealStatus.NEGOTIATING && deal.openOffer == null) { "No offer can be made now" }
            val range = offerRange(deal.listedPrice, deal.openCounter?.amount)
            require(range.check(command.amount) is OfferCheck.Ok) { "Offer ${command.amount} is outside $range" }
            return deal.copy(
                offers = deal.offers + Offer(Party.BUYER, command.amount, now, OfferStatus.OPEN),
                thread = deal.thread + ThreadItem.PriceMove(Party.BUYER, command.amount, false, now) +
                    listOfNotNull(command.note?.let { ThreadItem.Text(Party.BUYER, it, now) }),
            )
        }

        /** The seller takes the buyer's open offer. */
        fun acceptOffer(): Deal {
            check(deal.status == DealStatus.NEGOTIATING) { "Nothing to accept" }
            val offer = checkNotNull(deal.openOffer) { "No offer to accept" }
            return deal.agreed(offer.amount, offer, now).copy(
                thread = deal.thread + ThreadItem.PriceMove(Party.SELLER, offer.amount, true, now) + ThreadItem.Milestone(MilestoneKind.AGREED, now),
            )
        }

        /** The buyer takes the seller's open counter, or the listed price when there is none ("Mua giá này", "Mua lại"). */
        fun acceptCounter(): Deal {
            check(deal.status == DealStatus.NEGOTIATING) { "Nothing to accept" }
            val counter = deal.openCounter
            val price = counter?.amount ?: deal.listedPrice
            return deal.agreed(price, counter, now).copy(
                thread = deal.thread + ThreadItem.PriceMove(Party.BUYER, price, true, now) + ThreadItem.Milestone(MilestoneKind.AGREED, now),
            )
        }

        fun withdrawOffer(): Deal {
            buyer()
            val open = checkNotNull(deal.openOffer) { "No offer to withdraw" }
            return deal.copy(
                offers = deal.offers.map { if (it == open) it.copy(status = OfferStatus.WITHDRAWN) else it },
                thread = deal.thread + ThreadItem.Event("undo", "Bạn đã rút đề nghị", now),
            )
        }

        fun rate(command: DealCommand.Rate): Deal {
            buyer()
            check(deal.status == DealStatus.SOLD && deal.currentOrder?.status == OrderStatus.COMPLETED && deal.rating == null) { "Nothing to rate" }
            require(command.stars in 1..STARS_MAX) { "Stars must be 1 to 5" }
            return deal.copy(
                rating = command.stars,
                ratedAt = now,
                thread = deal.thread + ThreadItem.Event("star", "${command.stars} sao cho ${view.counterpart.name}", now),
            )
        }

        /** The buyer chooses COD; the order holds a COD slot from now on. */
        fun requestCod(): Deal {
            buyer()
            val price = checkNotNull(deal.agreedPrice) { "No agreed price" }
            // Above 5 triệu COD stays open; Chat only suggests meeting to look first.
            check(deal.status == DealStatus.AGREED && deal.openOrder == null) { "COD cannot be requested now" }
            val account = checkNotNull(context.account) { "No account to deliver to" }
            check(codSlots(context.rights, context.openCod, now).fits) { "No COD slot left" }
            val order = Order(deal.nextOrderId(), OrderStatus.PENDING, account.address, price, now)
            return deal.copy(orders = deal.orders + order, thread = deal.thread + ThreadItem.Event("local_shipping", "Đã chọn giao COD", now))
        }

        fun cancelOrder(): Deal {
            check(canCancel(deal)) { "The order cannot be cancelled now" }
            return deal.cancelled(me, if (me == Party.BUYER) CancelReason.BUYER else CancelReason.SELLER, now, "Bạn đã hủy đơn")
        }

        /** A typed code, trimmed, and what the carrier knows of it; a code it does not know throws [ShipmentNotFound]. */
        private fun read(carrier: ShipCarrier, typed: String, order: Order): Pair<String, Parcel> {
            val code = typed.trim()
            require(code.length in 1..TRACKING_CODE_MAX) { "A tracking code is 1 to 50 characters" }
            val parcel = carrier().lookup(carrier, code, order) ?: throw ShipmentNotFound(carrier, code)
            require(parcel.status != ShipmentStatus.FAILED) { "${carrier.label} reports $code failed" }
            return code to parcel
        }

        /** The seller's one step: a shipment on the linked GHTK account, or the code of one sent on a carrier's own app. */
        fun createShipment(command: DealCommand.CreateShipment): Deal {
            seller()
            val order = checkNotNull(deal.openOrder?.takeIf { it.status == OrderStatus.PENDING }) { "No order waits for its shipment" }
            val shipment = when (val new = command.shipment) {
                is NewShipment.Manual -> {
                    val (code, parcel) = read(new.carrier, new.trackingCode, order)
                    // A parcel already delivered ships as delivered, which starts the 3-day wait for the buyer's word.
                    Shipment(ShipmentMode.MANUAL, new.carrier, code, parcel.fee, parcel.status, deliveredAt = now.takeIf { parcel.status == ShipmentStatus.DELIVERED })
                }
                is NewShipment.Linked -> {
                    require(new.weightGrams in 1..MAX_WEIGHT_GRAMS) { "A parcel weighs 1 to 20 000 g" }
                    require(GHTK_SERVICES.any { it.id == new.service }) { "No service ${new.service}" }
                    val created = carrier().create(new.service, new.weightGrams, new.pickup, order.price)
                    Shipment(ShipmentMode.LINKED, ShipCarrier.GHTK, created.trackingCode, created.fee)
                }
            }
            val line = when (shipment.mode) {
                ShipmentMode.LINKED -> "Đã tạo đơn GHTK · ${shipment.trackingCode}"
                ShipmentMode.MANUAL -> "Đã gửi qua ${shipment.carrier.label} · ${shipment.trackingCode}"
            }
            return deal.withOrder(order.copy(status = OrderStatus.SHIPPED, shipment = shipment, shippedAt = now))
                .copy(thread = deal.thread + ThreadItem.Event("local_shipping", line, now))
        }

        fun editTrackingCode(command: DealCommand.EditTrackingCode): Deal {
            seller()
            val order = checkNotNull(deal.openOrder?.takeIf(::canEditTrackingCode)) { "The tracking code cannot be edited now" }
            val (code, parcel) = read(command.carrier, command.trackingCode, order)
            val shipment = checkNotNull(order.shipment).copy(
                carrier = command.carrier,
                trackingCode = code,
                fee = parcel.fee,
                status = parcel.status,
                deliveredAt = now.takeIf { parcel.status == ShipmentStatus.DELIVERED },
            )
            return deal.withOrder(order.copy(shipment = shipment))
                .copy(thread = deal.thread + ThreadItem.Event("edit", "Đã sửa mã vận đơn · ${command.carrier.label} $code", now))
        }

        fun confirmReceived(): Deal {
            buyer()
            check(deal.openOrder?.status == OrderStatus.SHIPPED) { "Nothing has been shipped to confirm" }
            return deal.completed(now)
        }
    }
}
```

- [ ] **Step 8: `DealConsole.kt`**

In `core/domain/src/main/kotlin/vn/shopnexus/core/domain/DealConsole.kt`:
- imports: drop `CodStatus`, `DealStage`; add `vn.shopnexus.core.model.DealStatus` and `vn.shopnexus.core.model.Order`.
- `ConsoleState.OrderStep` becomes `data class OrderStep(val order: Order, val price: Vnd) : ConsoleState` with the doc `/** The buyer's or the seller's open order, pending or shipped. */`; `ConsoleState.Received`'s doc `/** A completed order the buyer has not rated. */`; delete `ConsoleState.Ended`.
- delete `codChosen()` and `order(…)`; replace `state` and `sellerState` with:

```kotlin
    /** The console for [me]'s side of [deal]. [now] is kept for callers; nothing in the console tells time. */
    @Suppress("UnusedParameter")
    fun state(deal: Deal, me: UserId, draft: ConsoleDraft, now: Instant): ConsoleState {
        val price = deal.agreedPrice ?: deal.counterOrListed()
        if (roleOf(deal, me) == Party.SELLER) return sellerState(deal, draft, price)
        return when (deal.status) {
            DealStatus.NEGOTIATING -> negotiating(deal, draft)
            DealStatus.AGREED -> deal.openOrder?.let { ConsoleState.OrderStep(it, price) } ?: ConsoleState.Agreed(price, suggestsMeeting(price))
            DealStatus.SOLD -> deal.rating?.let { ConsoleState.Done(it) } ?: ConsoleState.Received
        }
    }

    private fun sellerState(deal: Deal, draft: ConsoleDraft, price: Vnd): ConsoleState = when (deal.status) {
        DealStatus.NEGOTIATING -> {
            val offer = deal.openOffer
            val counter = deal.openCounter
            when {
                offer != null && draft.editing -> counterRange(offer.amount, deal.listedPrice).let {
                    ConsoleState.Countering(draft.amount, it, it.check(draft.amount), offer.amount)
                }
                offer != null -> ConsoleState.OfferIn(offer.amount, deal.listedPrice)
                counter != null -> ConsoleState.CounterOut(counter.amount)
                else -> ConsoleState.Selling(deal.listedPrice)
            }
        }
        DealStatus.AGREED -> deal.openOrder?.let { ConsoleState.OrderStep(it, price) } ?: ConsoleState.AwaitingCod(price)
        DealStatus.SOLD -> ConsoleState.Done(deal.rating ?: 0)
    }
```

- [ ] **Step 9: `Selling.kt`, `Standing.kt`, `Handover.kt`**

`Selling.kt` (leave `shownFeatures` and every other function as they are): imports drop `CodStatus` and `DealStage`, add `vn.shopnexus.core.model.DealStatus` and `vn.shopnexus.core.model.OrderStatus`; replace `askerLine`'s COD line, `openOrder`, `orderNote` and `soldBy` with:

```kotlin
/** What someone with a deal on my listing did: an open offer, chose COD, else when they first asked. */
fun askerLine(view: DealView, now: Instant, zone: ZoneId): String {
    val deal = view.deal
    deal.openOffer?.let { return "Trả giá ${it.amount.short()}" }
    deal.openOrder?.let { return "Chọn COD ${lower(dayLabel(it.requestedAt, now, zone))}" }
    val first = deal.thread.firstOrNull()?.at ?: now
    return "Hỏi ${lower(dayLabel(first, now, zone))}"
}

/** The deal on [listing] with an order still open, pending or shipped. [now] changes nothing; no order expires here. */
@Suppress("UnusedParameter")
fun openOrder(views: List<DealView>, listing: ListingId, now: Instant): DealView? =
    views.firstOrNull { it.deal.listingId == listing && it.deal.openOrder != null }

/** The order row on a seller's card; null for a state no card shows. [now] and [zone] are kept for callers; no row tells a time. */
@Suppress("UnusedParameter")
fun orderNote(view: DealView, now: Instant, zone: ZoneId): OrderNote? {
    val id = view.deal.id
    return when (view.deal.openOrder?.status) {
        OrderStatus.PENDING -> OrderNote(id, "receipt_long", "Đơn COD · chờ bạn tạo đơn")
        OrderStatus.SHIPPED -> OrderNote(id, "local_shipping", "Đơn COD · đang giao")
        else -> null
    }
}

/** A listing is sold by the deal whose order completed, or by a sale marked by hand. A failed delivery sells nothing. */
fun soldBy(own: OwnListing, views: List<DealView>): Sale? {
    val sold = views.firstOrNull { view ->
        val deal = view.deal
        deal.listingId == own.listing.id && deal.sellerId == own.listing.sellerId && deal.status == DealStatus.SOLD
    }?.deal
    val at = sold?.currentOrder?.closedAt ?: return own.sale
    return Sale(sold.buyerId, at, sold.rating, sold.id, sold.agreedPrice)
}
```

`Standing.kt` (leave `tierPerks` and the rest as they are): imports drop `DealStage`, `Figures90`, `RecordStatus`, add `vn.shopnexus.core.model.OrderStatus`; delete `WINDOW_90`, `figures90` and `REPLY_WINDOW` (keep `HOUR`); replace `dueOrder` with:

```kotlin
/**
 * Tôi's due row: of the person's sales, the order that has waited longest for its shipment; null when none waits.
 * [now] is kept for callers; the row says when the request came, not how long is left.
 */
@Suppress("UnusedParameter")
fun dueOrder(views: List<DealView>, me: UserId, now: Instant, zone: ZoneId): DueOrder? = views
    .filter { it.deal.sellerId == me }
    .mapNotNull { view -> view.deal.openOrder?.takeIf { it.status == OrderStatus.PENDING }?.let { view to it } }
    .minByOrNull { (_, order) -> order.requestedAt }
    ?.let { (view, order) ->
        DueOrder(
            view.deal.id,
            "receipt_long",
            "Tạo đơn cho ${view.counterpart.name}",
            "${shortTitle(view.listing.title)} · chờ từ ${HOUR.format(order.requestedAt.atZone(zone))}",
        )
    }
```

(`HOUR` stays as it is in the file. Drop the `java.time.Duration` import if nothing else in the file reads it.)

`Handover.kt`: delete `SELF_CARRIER` and its doc; `FAST_SERVICE` becomes `"express"`; add after `SHIP_ESTIMATE`:

```kotlin
/** The services a linked GHTK account offers, by the server's names: `express` (Giao nhanh) and `standard` (Tiết kiệm). */
val GHTK_SERVICES = listOf(
    Carrier("express", "Giao nhanh", "1–2 ngày", Vnd(22_000)),
    Carrier("standard", "Tiết kiệm", "2–4 ngày", Vnd(16_000)),
)

/** The heaviest parcel a linked shipment takes, as the server's `MaxWeight`. */
const val MAX_WEIGHT_GRAMS = 20_000
```

Then `grep -rn "DealStage\|CodStatus\|OrderStatus\.\(REQUESTED\|TO_CREATE\|PLACED\|TO_SHIP\|SHIPPING\|AT_DOOR\|RECEIVED\|REVIEWED\|REFUSED\|RECORD\)\|activeRecord\|refundOptions\|recordDaysLeft\|figures90\|shippingCode\|SELF_CARRIER\|orderStatus(" core/domain/src` prints nothing.

- [ ] **Step 10: Run the domain's tests**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:domain:test`
Expected: BUILD SUCCESSFUL; `DealRulesTest` 13, `OrderMovesTest` 7 and `OrdersTest` 9 tests pass, with the ported ones.

- [ ] **Step 11: Commit**

```bash
./gradlew :core:domain:spotlessApply
git add core/domain
git commit -m "feat(domain): the six order commands, the system's moves and the four steps from the current order"
```

Then stop the daemons.

### Task 3: The fake carrier, the seeded orders, the repository and the simulator's steps

**Files:**
- Create: `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/FakeCarrier.kt`, `tmp/convert_fixtures.py` (scratch)
- Modify: `core/data/src/main/kotlin/vn/shopnexus/core/data/Repositories.kt`, `fake/FakeDealEngine.kt` (whole file), `fake/FakeDealRepository.kt`, `fake/Simulator.kt`, `fake/SimulatorSteps.kt`, `fake/OrderJumps.kt` (whole file), `fake/DebugControls.kt`, `fake/Seeds.kt`, `fake/FakeWorld.kt`, `fake/FakeListingRepository.kt`, `fake/FakeMyListingsRepository.kt`, `fake/AccountFakes.kt`; `core/data/src/main/resources/fixtures/deals.json`, `sellers.json`, `notifications.json` (by the script)
- Test: `core/data/src/test/kotlin/vn/shopnexus/core/data/fake/FakeCarrierTest.kt`, `SimulatorOrderTest.kt`, `OrderJumpsTest.kt` (whole file); ported: `DealFixturesTest.kt`, `FakeDealRepositoryTest.kt`, `FakeDealEngineTest.kt`, `FakeDealEngineStage3Test.kt`, `DebugControlsTest.kt`, `SimulatorTest.kt`, `SimulatorStage3Test.kt`, `SimulatorStage4Test.kt`, `FakeMyListingsRepositoryTest.kt`, `FakeInboxRepositoryTest.kt`, `FixturesTest.kt`; deleted: `SimulatorCodTest.kt`

**Interfaces:**
- Consumes: Tasks 1 and 2 (`CarrierClient`, `CreatedShipment`, `GHTK_SERVICES`, `waybillFee`, the moves in `OrderMoves.kt`, `nextOrderId`).
- Produces: `DealRepository.lookupShipment(id: DealId, carrier: ShipCarrier, code: String): Result<Parcel?>`; `class FakeCarrier : CarrierClient`; `interface DealEngine { fun apply(…); val carrier: CarrierClient }` with `FakeDealEngine(override val carrier: FakeCarrier = FakeCarrier())`; `Simulator(world, clock, scope, zone, pace, carrier: FakeCarrier = FakeCarrier())`; `OrderJump`, `orderAt(start, jump, now, zone)`, `ORDER_JUMPS`; `ConsoleTarget { COUNTERED, WAITING, AGREED, PENDING, SHIPPED, RECEIVED, DONE }`; `DebugControls.jumpOrder(id: DealId, jump: OrderJump)`. `FakeDealRepository`'s constructor does not change, so every `FakeDealRepository(…) { _, _ -> }` in the tests keeps building.

- [ ] **Step 1: Convert the fixtures**

Write `tmp/convert_fixtures.py` in the worktree:

```python
#!/usr/bin/env python3
"""Rewrites the seeded deals, sellers and notices for the order flow: deal status, orders and shipments, no records."""
import json
import re
import sys
from pathlib import Path

FIXTURES = Path(sys.argv[1]) / "core/data/src/main/resources/fixtures"
STATUS = {"NEGOTIATE": "NEGOTIATING", "ARRANGE": "AGREED", "HANDOVER": "AGREED", "RATE": "SOLD", "DONE": "SOLD"}
CARRIERS = {"GHTK": "GHTK", "GHN": "GHN", "SPX": "SPX", "J&T": "JT", "Viettel Post": "VIETTEL_POST"}
SHIPMENT = {"PLACED": "PENDING_PICKUP", "SHIPPING": "IN_TRANSIT", "AT_DOOR": "IN_TRANSIT", "RECEIVED": "DELIVERED"}
GONE = {"cod", "codRequest", "records", "handedOverAt", "end", "endedBy"}
# Thread lines that named a typed fee or a waybill's service, by their start, and what the new flow writes instead.
LINES = {
    "Ngọc Hân tự gửi qua SPX": "Ngọc Hân đã gửi qua SPX · SPXVN031245678",
    "Đã tạo đơn GHTK · Giao nhanh": "Đã tạo đơn GHTK · GHTK-66021185",
    "Quốc Bảo đã tạo đơn GHTK · Giao nhanh": "Quốc Bảo đã gửi hàng qua GHTK · GHTK-55210948",
}


def requested_at(deal, request, cod):
    if request:
        return request["at"]
    chosen = [i["at"] for i in deal.get("thread", []) if i.get("type") == "event" and i["text"].endswith("chọn giao COD")]
    return chosen[0] if chosen else cod["placedAt"]


def order_of(deal, request, cod):
    order = {
        "id": f"{deal['id']}-o1",
        "status": "PENDING",
        "recipient": (request or cod)["to"],
        "price": deal["agreedPrice"],
        "requestedAt": requested_at(deal, request, cod),
    }
    if cod is None:
        return order
    status = SHIPMENT[cod["status"]]
    manual = cod.get("selfShipped", False)
    events = list(cod.get("events", []))
    shipment = {
        "mode": "MANUAL" if manual else "LINKED",
        "carrier": CARRIERS[cod["carrier"]["name"]] if manual else "GHTK",
        "trackingCode": cod["code"] if manual else "GHTK-" + re.sub(r"\D", "", cod["code"]),
        "fee": cod["carrier"]["fee"],
        "status": status,
    }
    if status == "DELIVERED":
        events.append({"text": "Đã giao hàng", "at": cod["receivedAt"]})
        shipment["deliveredAt"] = cod["receivedAt"]
    if events:
        shipment["events"] = events
    order["status"] = "COMPLETED" if status == "DELIVERED" else "SHIPPED"
    order["shipment"] = shipment
    order["shippedAt"] = cod["placedAt"]
    if status == "DELIVERED":
        order["closedAt"] = cod["receivedAt"]
    return order


def convert(deal):
    request, cod = deal.get("codRequest"), deal.get("cod")
    out = {}
    for key, value in deal.items():
        if key == "stage":
            out["status"] = STATUS[value]
        elif key == "thread":
            out["thread"] = [line(i) for i in value]
        elif key not in GONE:
            out[key] = value
    if request or cod:
        out["orders"] = [order_of(deal, request, cod)]
    return out


def line(item):
    if item.get("type") == "event":
        for start, text in LINES.items():
            if item["text"].startswith(start):
                return {**item, "text": text}
    return item


def write(name, data):
    (FIXTURES / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


deals = json.loads((FIXTURES / "deals.json").read_text(encoding="utf-8"))
for seed in deals:
    seed.pop("recordReply", None)
    seed["view"]["deal"] = convert(seed["view"]["deal"])
write("deals.json", deals)

sellers = json.loads((FIXTURES / "sellers.json").read_text(encoding="utf-8"))
for seller in sellers:
    facts = seller["facts"]
    seller["facts"] = {("codFailed" if k == "codRefused" else k): v for k, v in facts.items() if k not in ("records", "recordsSelfRefunded")}
write("sellers.json", sellers)

notices = json.loads((FIXTURES / "notifications.json").read_text(encoding="utf-8"))
for notice in notices:
    if notice["id"] == "placed-han":
        notice["text"] = "Ngọc Hân đã gửi Xe đạp fixed gear qua SPX"
write("notifications.json", notices)
```

Run: `python3 tmp/convert_fixtures.py .` from the worktree root, then `git diff --stat core/data/src/main/resources/fixtures`.
Expected: three files changed; `grep -c '"stage"\|"cod"\|"codRequest"\|"records"\|recordReply' core/data/src/main/resources/fixtures/deals.json` prints `0`; `python3 -c "import json;[print(s['view']['deal']['id'], s['view']['deal']['status'], [o['status'] for o in s['view']['deal'].get('orders', [])]) for s in json.load(open('core/data/src/main/resources/fixtures/deals.json'))]"` prints

```
d-kiet NEGOTIATING []
d-24h NEGOTIATING []
d-quang NEGOTIATING []
d-huy AGREED ['PENDING']
d-nam AGREED []
d-han AGREED ['SHIPPED']
d-bao SOLD ['COMPLETED']
d-xm4 SOLD ['COMPLETED']
```

Open `deals.json` and read the four orders once: d-han's shipment is `MANUAL`, `SPX`, `SPXVN031245678`, `PENDING_PICKUP`; d-bao's `LINKED`, `GHTK-66021185`, `DELIVERED`; d-xm4's `GHTK-55210948`, requested `2026-10-10T12:57:00Z`. The JSON keeps two-space indentation; key order inside unchanged objects is kept.

- [ ] **Step 2: Write the failing fake tests**

Create `core/data/src/test/kotlin/vn/shopnexus/core/data/fake/FakeCarrierTest.kt`:

```kotlin
package vn.shopnexus.core.data.fake

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import vn.shopnexus.core.domain.CreatedShipment
import vn.shopnexus.core.model.DeliveryAddress
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Parcel
import vn.shopnexus.core.model.Pickup
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.Vnd

class FakeCarrierTest {
    private val order = Order(
        OrderId("d-huy-o1"), OrderStatus.PENDING, DeliveryAddress("Đức Huy", "09•• ••• 547", "12 Phan Xích Long, Phú Nhuận"), Vnd(350_000), Fixtures.NOW,
    )

    @Test
    fun linkedShipmentsGetGhtkCodesInTurnAndTheServicesFee() {
        val carrier = FakeCarrier()
        assertThat(carrier.create("express", 2_000, Pickup.HOME, Vnd(350_000))).isEqualTo(CreatedShipment("GHTK-100001", Vnd(22_000)))
        assertThat(carrier.create("standard", 3_000, Pickup.POST_OFFICE, Vnd(350_000))).isEqualTo(CreatedShipment("GHTK-100002", Vnd(20_000)))
    }

    @Test
    fun aKnownCodeReadsTheOrdersRecipientMaskedAndItsPrice() {
        assertThat(FakeCarrier().lookup(ShipCarrier.SPX, "SPXVN1", order))
            .isEqualTo(Parcel("Đ••• H•••", "Phú Nhuận", Vnd(350_000), ShipmentStatus.PENDING_PICKUP, Vnd(22_000)))
    }

    @Test
    fun notFoundIsAnyCaseAfterTrimming() {
        for (code in listOf("NOTFOUND", " notfound12 ", "NotFound-SPX", "   ")) {
            assertThat(FakeCarrier().lookup(ShipCarrier.GHN, code, order)).isNull()
        }
        assertThat(FakeCarrier().lookup(ShipCarrier.GHN, "XNOTFOUND", order)).isNotNull()
    }

    @Test
    fun aWrongCodCodeIsFoundAboveTheAgreedPrice() {
        assertThat(FakeCarrier().lookup(ShipCarrier.JT, "wrongcod7", order)!!.cod).isEqualTo(Vnd(450_000))
    }

    /** What the carrier reported for a code is what a later lookup of it reads, as the server's dev endpoint sets it. */
    @Test
    fun aReportedCodeReadsItsStatus() {
        val carrier = FakeCarrier()
        carrier.report(" SPXVN1 ", ShipmentStatus.DELIVERED)
        assertThat(carrier.lookup(ShipCarrier.SPX, "SPXVN1", order)!!.status).isEqualTo(ShipmentStatus.DELIVERED)
        assertThat(carrier.lookup(ShipCarrier.SPX, "SPXVN2", order)!!.status).isEqualTo(ShipmentStatus.PENDING_PICKUP)
    }
}
```

Create `core/data/src/test/kotlin/vn/shopnexus/core/data/fake/SimulatorOrderTest.kt`:

```kotlin
package vn.shopnexus.core.data.fake

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test
import vn.shopnexus.core.domain.ReputationEvent
import vn.shopnexus.core.domain.VN_ZONE
import vn.shopnexus.core.model.DealCommand
import vn.shopnexus.core.model.DealId
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.MilestoneKind
import vn.shopnexus.core.model.NewShipment
import vn.shopnexus.core.model.NotificationTarget
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Pickup
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.ShipmentMode
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.ThreadItem
import vn.shopnexus.core.model.Vnd
import vn.shopnexus.core.testing.SchedulerClock

/** The carrier's steps in the simulator: Hoàng Nam ships what Khánh Linh buys, and Đức Huy receives what she ships. */
class SimulatorOrderTest {
    private val nam = DealId("d-nam")
    private val huy = DealId("d-huy")

    private fun TestScope.setup(): Pair<FakeWorld, FakeDealRepository> {
        val world = FakeWorld()
        val clock = SchedulerClock(testScheduler)
        val simulator = Simulator(world, clock, backgroundScope, VN_ZONE, Pace(), FakeCarrier())
        return world to FakeDealRepository(world, FailurePolicy(latencyMillis = 0), FakeDealEngine(FakeCarrier()), clock, simulator)
    }

    private fun TestScope.after(millis: Long) {
        advanceTimeBy(millis)
        runCurrent()
    }

    @Test
    fun theSellerShipsOnGhtkThreeSecondsAfterTheRequest() = runTest {
        val (world, deals) = setup()
        fun deal() = world.value.deals.getValue(nam).deal
        deals.send(nam, DealCommand.RequestCod).getOrThrow()
        after(2_999)
        assertThat(deal().currentOrder!!.status).isEqualTo(OrderStatus.PENDING)
        after(1)
        val order = deal().currentOrder!!
        assertThat(order.status).isEqualTo(OrderStatus.SHIPPED)
        assertThat(order.shipment!!.mode).isEqualTo(ShipmentMode.LINKED)
        assertThat(order.shipment!!.trackingCode).isEqualTo("GHTK-100001")
        assertThat(order.shipment!!.fee).isEqualTo(Vnd(22_000))
        assertThat(deal().thread.last()).isEqualTo(ThreadItem.Event("local_shipping", "Hoàng Nam đã gửi hàng qua GHTK · GHTK-100001", order.shippedAt!!))
        val notice = world.value.notifications.first()
        assertThat(notice.text).isEqualTo("Hoàng Nam đã gửi iPhone X qua GHTK")
        assertThat(notice.target).isEqualTo(NotificationTarget.Order(nam))
    }

    @Test
    fun theCarrierPicksUpThenDeliversAndTheOrderWaitsForTheBuyersWord() = runTest {
        val (world, deals) = setup()
        fun deal() = world.value.deals.getValue(nam).deal
        deals.send(nam, DealCommand.RequestCod).getOrThrow()
        after(6_500)
        val moving = deal().currentOrder!!.shipment!!
        assertThat(moving.status).isEqualTo(ShipmentStatus.IN_TRANSIT)
        assertThat(moving.events.map { it.text }.last()).isEqualTo("Đến kho Bình Thạnh")
        assertThat(moving.events.first().text).startsWith("Đã lấy hàng tại ")
        after(3_500)
        val delivered = deal().currentOrder!!
        assertThat(delivered.shipment!!.status).isEqualTo(ShipmentStatus.DELIVERED)
        assertThat(delivered.shipment!!.deliveredAt).isNotNull()
        assertThat(delivered.status).isEqualTo(OrderStatus.SHIPPED)
        assertThat(deal().status).isEqualTo(DealStatus.AGREED)
        assertThat(world.value.notifications.first().text).isEqualTo("Đã giao iPhone X")
    }

    /** A receipt before the carrier's last reports: the reports that land later change nothing. */
    @Test
    fun anEarlyReceiptDropsTheCarriersLaterSteps() = runTest {
        val (world, deals) = setup()
        fun deal() = world.value.deals.getValue(nam).deal
        deals.send(nam, DealCommand.RequestCod).getOrThrow()
        after(3_000)
        deals.send(nam, DealCommand.ConfirmReceived).getOrThrow()
        val received = deal()
        after(10_000)
        assertThat(deal()).isEqualTo(received)
        assertThat(deal().currentOrder!!.status).isEqualTo(OrderStatus.COMPLETED)
        assertThat(deal().currentOrder!!.shipment!!.status).isEqualTo(ShipmentStatus.PENDING_PICKUP)
        assertThat(deal().status).isEqualTo(DealStatus.SOLD)
        assertThat(deal().thread.last()).isInstanceOf(ThreadItem.Milestone::class.java)
        assertThat(world.value.reputation.map { it.event }).contains(ReputationEvent.DEAL)
    }

    @Test
    fun aCancelledRequestGetsNoShipment() = runTest {
        val (world, deals) = setup()
        deals.send(nam, DealCommand.RequestCod).getOrThrow()
        after(1_000)
        deals.send(nam, DealCommand.CancelOrder).getOrThrow()
        after(10_000)
        val deal = world.value.deals.getValue(nam).deal
        assertThat(deal.currentOrder!!.status).isEqualTo(OrderStatus.CANCELLED)
        assertThat(deal.currentOrder!!.shipment).isNull()
        assertThat(deal.status).isEqualTo(DealStatus.NEGOTIATING)
    }

    /** Khánh Linh ships Đức Huy's stool on GHTK: the carrier delivers it, Đức Huy says he has it and rates five stars. */
    @Test
    fun theBuyerOfThePersonsShipmentConfirmsAndRates() = runTest {
        val (world, deals) = setup()
        fun deal() = world.value.deals.getValue(huy).deal
        deals.send(huy, DealCommand.CreateShipment(NewShipment.Linked("express", 2_000, Pickup.HOME))).getOrThrow()
        after(1_600)
        assertThat(deal().currentOrder!!.shipment!!.status).isEqualTo(ShipmentStatus.IN_TRANSIT)
        after(1_600)
        assertThat(deal().currentOrder!!.shipment!!.status).isEqualTo(ShipmentStatus.DELIVERED)
        after(4_000)
        assertThat(deal().currentOrder!!.status).isEqualTo(OrderStatus.COMPLETED)
        assertThat(deal().status).isEqualTo(DealStatus.SOLD)
        assertThat(deal().thread.last()).isEqualTo(ThreadItem.Milestone(MilestoneKind.HANDED_OVER, deal().currentOrder!!.closedAt!!))
        after(4_000)
        assertThat(deal().rating).isEqualTo(5)
        assertThat(world.value.reputation.map { it.event }).containsAtLeast(ReputationEvent.DEAL, ReputationEvent.RATED_5).inOrder()
    }

    /** Khánh Linh ships the stool with the code Ngọc Hân's bike already carries: the carrier's pickup moves both orders. */
    @Test
    fun oneReportMovesEveryOrderWithItsCode() = runTest {
        val (world, deals) = setup()
        val han = DealId("d-han")
        val code = world.value.deals.getValue(han).deal.currentOrder!!.shipment!!.trackingCode
        deals.send(huy, DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.SPX, code))).getOrThrow()
        after(1_600)
        assertThat(world.value.deals.getValue(huy).deal.currentOrder!!.shipment!!.status).isEqualTo(ShipmentStatus.IN_TRANSIT)
        assertThat(world.value.deals.getValue(han).deal.currentOrder!!.shipment!!.status).isEqualTo(ShipmentStatus.IN_TRANSIT)
    }

    @Test
    fun aManualShipmentMovesTheSameWay() = runTest {
        val (world, deals) = setup()
        deals.send(huy, DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.SPX, "SPXVN9"))).getOrThrow()
        after(3_200)
        val shipment = world.value.deals.getValue(huy).deal.currentOrder!!.shipment!!
        assertThat(shipment.mode).isEqualTo(ShipmentMode.MANUAL)
        assertThat(shipment.status).isEqualTo(ShipmentStatus.DELIVERED)
    }
}
```

Replace `core/data/src/test/kotlin/vn/shopnexus/core/data/fake/OrderJumpsTest.kt` with:

```kotlin
package vn.shopnexus.core.data.fake

import com.google.common.truth.Truth.assertThat
import java.time.Duration
import kotlinx.coroutines.test.runTest
import org.junit.Test
import vn.shopnexus.core.domain.VN_ZONE
import vn.shopnexus.core.model.DealCommand
import vn.shopnexus.core.model.DealId
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.ListingId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.ShipmentMode
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.ThreadItem
import vn.shopnexus.core.testing.SchedulerClock

class OrderJumpsTest {
    private val now = Fixtures.NOW

    @Test
    fun everyJumpLandsOnItsStateWithItsThreadInOrder() {
        val expected = mapOf(
            OrderJump.PENDING to Triple(OrderStatus.PENDING, null, DealStatus.AGREED),
            OrderJump.SHIPPED to Triple(OrderStatus.SHIPPED, ShipmentStatus.PENDING_PICKUP, DealStatus.AGREED),
            OrderJump.DELIVERED to Triple(OrderStatus.SHIPPED, ShipmentStatus.DELIVERED, DealStatus.AGREED),
            OrderJump.COMPLETED to Triple(OrderStatus.COMPLETED, ShipmentStatus.DELIVERED, DealStatus.SOLD),
            OrderJump.FAILED to Triple(OrderStatus.FAILED, ShipmentStatus.FAILED, DealStatus.NEGOTIATING),
            OrderJump.CANCELLED to Triple(OrderStatus.CANCELLED, null, DealStatus.NEGOTIATING),
        )
        assertThat(ORDER_JUMPS.keys.map { it.value }).containsExactly("d-nam", "d-huy", "d-han", "d-bao")
        ORDER_JUMPS.forEach { (id, jumps) ->
            assertThat(jumps).containsExactlyElementsIn(OrderJump.entries)
            jumps.forEach { jump ->
                val deal = orderAt(Fixtures.deal(id.value), jump, now, VN_ZONE).deal
                val (order, shipment, status) = expected.getValue(jump)
                assertThat(deal.orders).hasSize(1)
                assertThat(deal.currentOrder!!.status).isEqualTo(order)
                assertThat(deal.currentOrder!!.shipment?.status).isEqualTo(shipment)
                assertThat(deal.status).isEqualTo(status)
                assertThat(deal.thread.zipWithNext().all { (a, b) -> a.at <= b.at }).isTrue()
            }
        }
    }

    @Test
    fun aJumpLeavesTheThreadsEvents() {
        val shipped = orderAt(Fixtures.deal("d-nam"), OrderJump.SHIPPED, now, VN_ZONE).deal
        val events = shipped.thread.filterIsInstance<ThreadItem.Event>().map { it.text }
        assertThat(events.last()).startsWith("Hoàng Nam đã gửi hàng qua GHTK · GHTK-")
        assertThat(events).contains("Đã chọn giao COD")
        val failed = orderAt(Fixtures.deal("d-nam"), OrderJump.FAILED, now, VN_ZONE).deal
        assertThat(failed.thread.filterIsInstance<ThreadItem.Event>().last().text).isEqualTo("Giao không thành")
        val selling = orderAt(Fixtures.deal("d-huy"), OrderJump.SHIPPED, now, VN_ZONE).deal
        assertThat(selling.thread.filterIsInstance<ThreadItem.Event>().last().text).startsWith("Đã tạo đơn GHTK · GHTK-")
    }

    /** Ngọc Hân's bike keeps its SPX code through every jump; Hoàng Nam's phone gets a GHTK one. */
    @Test
    fun aSeededShipmentKeepsItsModeAndCode() {
        val bike = orderAt(Fixtures.deal("d-han"), OrderJump.DELIVERED, now, VN_ZONE).deal.currentOrder!!.shipment!!
        assertThat(bike.mode).isEqualTo(ShipmentMode.MANUAL)
        assertThat(bike.carrier).isEqualTo(ShipCarrier.SPX)
        assertThat(bike.trackingCode).isEqualTo("SPXVN031245678")
        val phone = orderAt(Fixtures.deal("d-nam"), OrderJump.SHIPPED, now, VN_ZONE).deal.currentOrder!!.shipment!!
        assertThat(phone.mode).isEqualTo(ShipmentMode.LINKED)
        assertThat(phone.trackingCode).startsWith("GHTK-")
    }

    /** A jump dates the request 40 minutes back, so a timer set from it still has days to run. */
    @Test
    fun aJumpedOrderIsRequestedMinutesAgo() {
        val shelf = orderAt(Fixtures.deal("d-bao"), OrderJump.PENDING, now, VN_ZONE).deal.currentOrder!!
        assertThat(shelf.requestedAt).isEqualTo(now.minus(Duration.ofMinutes(40)))
        assertThat(shelf.recipient.name).isEqualTo("Gia Bảo")
    }

    @Test
    fun aFailedJumpPutsTheListingBackOnSale() {
        val world = FakeWorld()
        val controls = DebugControls(
            world,
            Simulator(world, fixtureClock(), kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Unconfined), VN_ZONE, Pace()),
            FailurePolicy(),
            fixtureClock(),
            VN_ZONE,
        )
        assertThat(world.value.isReserved(ListingId("my-stool"), now)).isTrue()
        controls.jumpOrder(DealId("d-huy"), OrderJump.FAILED)
        assertThat(world.value.deals.getValue(DealId("d-huy")).deal.status).isEqualTo(DealStatus.NEGOTIATING)
        assertThat(world.value.isReserved(ListingId("my-stool"), now)).isFalse()
    }

    /** A jump while the carrier is on its way stops the pending reports. */
    @Test
    fun aJumpStopsTheCarrier() = runTest {
        val world = FakeWorld()
        val clock = SchedulerClock(testScheduler)
        val simulator = Simulator(world, clock, backgroundScope, VN_ZONE, Pace())
        val deals = FakeDealRepository(world, FailurePolicy(latencyMillis = 0), FakeDealEngine(), clock, simulator)
        val controls = DebugControls(world, simulator, FailurePolicy(), clock, VN_ZONE)
        val nam = DealId("d-nam")
        deals.send(nam, DealCommand.RequestCod).getOrThrow()
        testScheduler.advanceTimeBy(1_000)
        testScheduler.runCurrent()
        controls.jumpOrder(nam, OrderJump.PENDING)
        testScheduler.advanceTimeBy(20_000)
        testScheduler.runCurrent()
        assertThat(world.value.deals.getValue(nam).deal.currentOrder!!.status).isEqualTo(OrderStatus.PENDING)
    }
}
```

- [ ] **Step 3: Port the other fake tests**

Delete `SimulatorCodTest.kt` (its walk is `SimulatorOrderTest` now). In the rest, the mechanical rules: `deal.stage` → `deal.status` (`NEGOTIATE` → `NEGOTIATING`, `ARRANGE`/`HANDOVER` → `AGREED`, `RATE`/`DONE` → `SOLD`); `deal.codRequest` → `deal.currentOrder` (its `to` → `recipient`, `at` → `requestedAt`); `deal.cod` → `deal.currentOrder?.shipment`; `orderStatus(deal, me, now)` → `deal.currentOrder?.status` (and `?.shipment?.status` where the old status was `AT_DOOR`/`SHIPPING`); `orderAt(view, OrderStatus.X, …)` → `orderAt(view, OrderJump.Y, …)` with `REQUESTED`/`TO_CREATE` → `PENDING`, `PLACED`/`TO_SHIP`/`SHIPPING`/`AT_DOOR` → `SHIPPED`, `RECEIVED` → `COMPLETED`, `REVIEWED` → `COMPLETED` plus `.let { it.copy(deal = it.deal.copy(rating = 5, ratedAt = now)) }`, `REFUSED` → `FAILED`, `CANCELLED` → `CANCELLED`; `DealCommand.CancelCod` → `CancelOrder`; `DealCommand.CreateWaybill(id, grams)` → `CreateShipment(NewShipment.Linked(id, grams, Pickup.HOME))`; `DealCommand.RecordSelfShipment(name, code, fee)` → `CreateShipment(NewShipment.Manual(<carrier>, code))`; `DealConsole.state(…)` keeps its arguments. Then, by file:

| File | Test | Becomes |
|---|---|---|
| `DealFixturesTest` | `everyOrderGoesByCod` | every seeded order has a recipient and the deal's agreed price: `seeds.flatMap { it.view.deal.orders.map { o -> it.view.deal to o } }.forEach { (d, o) -> assertThat(o.price).isEqualTo(d.agreedPrice ?: o.price) }` |
| | `theSeededOrdersStandWhereTheMockupsShowThem` | the body below |
| | `theStoolWaitsForItsOrder` | d-huy: `currentOrder!!.status == PENDING`, recipient `Đức Huy`, `inboxTag` `AwaitingCreation` |
| | `theBikeIsSelfShippedThroughSpx` | rename `theBikeIsShippedThroughSpxWithItsCode`: shipment `MANUAL`, `SPX`, `SPXVN031245678`, fee `22.000 ₫`, `PENDING_PICKUP` |
| | `noFixtureHasADeadlineOrPlacesCod` | keep; its JSON scan also asserts no `"stage"` and no `"records"` |
| | `theNoticesNameTheRequestAndTheSelfShippedOrder` | `placed-han` reads "Ngọc Hân đã gửi Xe đạp fixed gear qua SPX" |
| | `theRecordRepliesBelongToTuanKietAndNgocHan` | delete |
| `FakeDealRepositoryTest` | `aCarrierStepDuringACommandIsKept` | jump d-nam to `OrderJump.SHIPPED`; the interfering step sets `v.deal.shipmentUpdated(ShipmentStatus.IN_TRANSIT, Fixtures.NOW)`; the kept state asserts `currentOrder!!.shipment!!.status == IN_TRANSIT` |
| | `requestingCodMakesAnOrderAndCancellingFreesTheSlot` | `CancelOrder`; asserts `currentOrder!!.status == CANCELLED` and the open count back to its start |
| | `theSellersWaybillUsesHerCarrierAccount` | delete; add `aShipmentCancelsTheOtherPendingOrdersOnItsListing`, `aLookupReadsTheOpenOrder` and `receiptEarnsTheBuyerDealsPoints` (below) |
| | `noCancelAfterPickup` | rename `aShippedOrderCannotBeCancelled`: d-nam jumped to `SHIPPED`; `CancelOrder` fails and the deal is unchanged |
| | `aSelfRefundEarnsItsPoints` | delete |
| | `aPickedAddressGoesWithOneRequest` | asserts `currentOrder!!.recipient` instead of `codRequest!!.to` |
| | `anOrderDraftIsKeptByOrder` | `OrderDraft(trackingCode = "SPXVN1")`, asserts `.trackingCode` |
| `FakeDealEngineTest` | `acceptingTheCounterAgreesThePriceAndDrawsTheMilestone`, `codCanBeRequestedRightAfterTheHandshake`, `commandsOutOfOrderAreRefused` | port by the rules above (status `AGREED`, `currentOrder`) |
| `FakeDealEngineStage3Test` | `atDoor` helper, `theCarrierSettlesTheDoor`, `theSellerShipsWithNoDeadline`, `theSellerRefundsWithinThePriceOrDeclines`, `theBuyerWithdrawsAnOpenOrDeclinedRecord`, `aSecondRecordWaitsUntilTheFirstIsWithdrawn`, `aPlacedParcelCarriesItsCarrierFeeForTheReturnLeg` | delete |
| | `orderAndShippingCodesAreStable` | keep the `orderCode` half, drop `shippingCode` |
| | `requestingCodHoldsTheAddressAndCreatingTheWaybillChargesByWeight` | rename `requestingCodHoldsTheAddressAndALinkedShipmentChargesByWeight`: `CreateShipment(Linked("express", 3_500, HOME))` gives fee `32.000 ₫` and a `GHTK-` code |
| | `codIsRefusedWithoutASlotTwiceOrForAnUnknownService`, `ratingRecordsWhen`, `eachSideDoesOnlyItsOwnSteps` | port by the rules above; `eachSideDoesOnlyItsOwnSteps` checks a buyer's `CreateShipment` and a seller's `ConfirmReceived` and `RequestCod` throw |
| `DebugControlsTest` | `theChipsWalkTheDealByCod` | the body below |
| `SimulatorTest` | `aRecordIsRefundedAfterTwoPointTwoSeconds` | delete |
| `SimulatorStage3Test` | `aCreatedOrderIsPickedUpThenReachesTheDoorWithANotification`, `withdrawingARecordStopsTheAnswer`, `ngocHanDeclinesARecordAndHoangNamDoesNotAnswer`, `aReplyToAWithdrawnRecordIsDropped` | delete (the first is `SimulatorOrderTest` now) |
| | `aShippedStoolIsReceivedAfterThreePointTwoSeconds` | rename `aShippedStoolIsDeliveredAfterThreePointTwoSeconds`: after `CreateShipment(Linked("express", 2_000, HOME))`, shipment `DELIVERED` at 3 200 ms |
| | `aNewDealIsAgreedAndAskedForCod`, `speedDividesTheCarriersTimings` | port by the rules above |
| `SimulatorStage4Test` | `theSellersWaybillThenTheCarriersSteps` | `CreateShipment(Linked("express", 2_000, HOME))`, then `IN_TRANSIT`, `DELIVERED` |
| | `aShippedParcelIsReceivedAndRatedFiveStars` | `COMPLETED` at delivered + 4 000 ms, five stars 4 000 ms later |
| | `aSelfShippedParcelIsConfirmedByTheBuyer` | rename `aManualShipmentIsConfirmedByTheBuyer`: `CreateShipment(Manual(SPX, "SPXVN9"))`, `COMPLETED` at 7 200 ms |
| | the rest | port by the rules above |
| `FakeMyListingsRepositoryTest` | `aReservedListingRefusesSaleBoostAndDelete` | d-huy's `PENDING` order reserves `my-stool` |
| | `aHandedOverDealSellsTheListing` | rename `aCompletedOrderSellsTheListing`: jump d-huy to `COMPLETED`; the sold card's date is the order's `closedAt` |
| `FakeInboxRepositoryTest`, `FixturesTest`, `DealConsistencyTest`, `AccountFakesTest` | every test | port by the rules above |

`DealFixturesTest.theSeededOrdersStandWhereTheMockupsShowThem`:

```kotlin
    @Test
    fun theSeededOrdersStandWhereTheMockupsShowThem() {
        val deals = Fixtures.deals().associate { it.view.deal.id.value to it.view.deal }
        fun order(id: String) = deals.getValue(id).currentOrder
        assertThat(deals.getValue("d-nam").status).isEqualTo(DealStatus.AGREED)
        assertThat(order("d-nam")).isNull()
        assertThat(order("d-huy")!!.status).isEqualTo(OrderStatus.PENDING)
        assertThat(order("d-han")!!.status).isEqualTo(OrderStatus.SHIPPED)
        assertThat(order("d-han")!!.shipment!!.status).isEqualTo(ShipmentStatus.PENDING_PICKUP)
        assertThat(order("d-bao")!!.status).isEqualTo(OrderStatus.COMPLETED)
        assertThat(deals.getValue("d-bao").rating).isEqualTo(5)
        assertThat(order("d-xm4")!!.status).isEqualTo(OrderStatus.COMPLETED)
        assertThat(deals.getValue("d-xm4").rating).isNull()
        assertThat(deals.values.flatMap { it.orders }.map { it.id.value }).containsExactly("d-huy-o1", "d-han-o1", "d-bao-o1", "d-xm4-o1")
    }
```

`FakeDealRepositoryTest`, three new tests (the file's `repository()` is `FakeDealRepository(world, failures, FakeDealEngine(), SchedulerClock(testScheduler)) { _, _ -> }`):

```kotlin
    @Test
    fun aShipmentCancelsTheOtherPendingOrdersOnItsListing() = runTest {
        val huy = DealId("d-huy")
        val second = DealId("d-huy-2")
        world.update { w ->
            val v = w.deals.getValue(huy)
            val other = v.copy(deal = v.deal.copy(id = second, buyerId = UserId("u-bao"), orders = v.deal.orders.map { it.copy(id = OrderId("d-huy-2-o1")) }))
            w.copy(deals = w.deals + (second to other))
        }
        val nam = world.value.deals.getValue(DealId("d-nam"))
        repository().send(huy, DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.SPX, "SPXVN1"))).getOrThrow()
        assertThat(world.value.deals.getValue(huy).deal.currentOrder!!.status).isEqualTo(OrderStatus.SHIPPED)
        val cancelled = world.value.deals.getValue(second).deal
        assertThat(cancelled.currentOrder!!.status).isEqualTo(OrderStatus.CANCELLED)
        assertThat(cancelled.currentOrder!!.cancelReason).isEqualTo(CancelReason.SHIPPED_TO_ANOTHER)
        assertThat(cancelled.status).isEqualTo(DealStatus.NEGOTIATING)
        assertThat(cancelled.agreedPrice).isNull()
        // The person's own purchases are not on her listing.
        assertThat(world.value.deals.getValue(DealId("d-nam"))).isEqualTo(nam)
    }

    @Test
    fun aLookupReadsTheOpenOrder() = runTest {
        val deals = repository()
        val parcel = deals.lookupShipment(DealId("d-huy"), ShipCarrier.GHN, "GHN1").getOrThrow()!!
        assertThat(parcel.recipient).isEqualTo("Đ••• H•••")
        assertThat(parcel.cod).isEqualTo(Vnd(350_000))
        assertThat(deals.lookupShipment(DealId("d-huy"), ShipCarrier.GHN, "NOTFOUND1").getOrThrow()).isNull()
        assertThat(deals.lookupShipment(DealId("d-nam"), ShipCarrier.GHN, "GHN1").isFailure).isTrue()
    }

    @Test
    fun receiptEarnsTheBuyerDealsPoints() = runTest {
        val han = DealId("d-han")
        repository().send(han, DealCommand.ConfirmReceived).getOrThrow()
        assertThat(world.value.deals.getValue(han).deal.status).isEqualTo(DealStatus.SOLD)
        assertThat(world.value.reputation.last().event).isEqualTo(ReputationEvent.DEAL)
        assertThat(world.value.reputation.last().text).isEqualTo("Mua Xe đạp fixed gear")
    }
```

(`shortTitle("Xe đạp fixed gear khung thép, vừa thay lốp")` is "Xe đạp fixed gear"; check it against `shortTitle` once and use what it returns.)

`DebugControlsTest.theChipsWalkTheDealByCod`:

```kotlin
    @Test
    fun theChipsWalkTheDealByCod() = runTest {
        val world = FakeWorld()
        val clock = SchedulerClock(testScheduler)
        val controls = DebugControls(world, Simulator(world, clock, backgroundScope, VN_ZONE, Pace()), FailurePolicy(), clock, VN_ZONE)
        val price = Vnd(5_100_000)
        controls.jump(ConsoleTarget.COUNTERED)
        assertThat(state(world)::class).isEqualTo(ConsoleState.Countered::class)
        controls.jump(ConsoleTarget.WAITING)
        assertThat(state(world)::class).isEqualTo(ConsoleState.Waiting::class)
        controls.jump(ConsoleTarget.AGREED)
        assertThat(state(world)).isEqualTo(ConsoleState.Agreed(price, suggestMeeting = true))
        controls.jump(ConsoleTarget.PENDING)
        assertThat(state(world)).isEqualTo(ConsoleState.OrderStep(deal(world).currentOrder!!, price))
        assertThat(deal(world).currentOrder!!.status).isEqualTo(OrderStatus.PENDING)
        controls.jump(ConsoleTarget.SHIPPED)
        assertThat(deal(world).currentOrder!!.shipment!!.mode).isEqualTo(ShipmentMode.LINKED)
        assertThat(state(world)).isEqualTo(ConsoleState.OrderStep(deal(world).currentOrder!!, price))
        controls.jump(ConsoleTarget.RECEIVED)
        assertThat(state(world)).isEqualTo(ConsoleState.Received)
        controls.jump(ConsoleTarget.DONE)
        assertThat(state(world)).isEqualTo(ConsoleState.Done(5))
        assertThat(deal(world).thread.last()).isEqualTo(ThreadItem.Event("star", "5 sao cho Tuấn Kiệt", Fixtures.NOW))
    }

    private fun deal(world: FakeWorld) = world.value.deals.getValue(DealId("d-kiet")).deal
```

- [ ] **Step 4: Run them to see them fail**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:data:testDebugUnitTest`
Expected: compilation fails (`FakeCarrier`, `OrderJump`, `lookupShipment` unresolved, and the old main code against the new model).

- [ ] **Step 5: `FakeCarrier.kt`**

Create `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/FakeCarrier.kt`:

```kotlin
package vn.shopnexus.core.data.fake

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import javax.inject.Inject
import javax.inject.Singleton
import vn.shopnexus.core.domain.CarrierClient
import vn.shopnexus.core.domain.CreatedShipment
import vn.shopnexus.core.domain.GHTK_SERVICES
import vn.shopnexus.core.domain.waybillFee
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.Parcel
import vn.shopnexus.core.model.Pickup
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.Vnd

/** A code the fake carrier does not know: any that starts with this, in any case, as on the server. */
internal const val NOT_FOUND_PREFIX = "NOTFOUND"

/** A code the fake carrier knows with a COD amount 100.000 ₫ above the order's price, so the warning can be seen. */
internal const val WRONG_COD_PREFIX = "WRONGCOD"

private val WRONG_COD_EXTRA = Vnd(100_000)
private val READ_FEE = Vnd(22_000)
private const val FIRST_CODE = 100_001

/**
 * The carrier as the server's fake client plays it: GHTK-100001 and on for shipments created on the linked account,
 * and every typed code found but those starting with NOTFOUND. A found code reads the order it is typed for, as if the
 * seller had typed that recipient and price on the carrier's app, and the status the simulator last reported for it.
 */
@Singleton
class FakeCarrier @Inject constructor() : CarrierClient {
    private val serial = AtomicInteger(FIRST_CODE)
    private val reported = ConcurrentHashMap<String, ShipmentStatus>()

    /** The carrier reports [status] for [code]; the simulator's steps call it, as the server's dev endpoint does. */
    fun report(code: String, status: ShipmentStatus) {
        reported[code.trim()] = status
    }

    override fun create(service: String, weightGrams: Int, pickup: Pickup, cod: Vnd): CreatedShipment {
        val fee = GHTK_SERVICES.firstOrNull { it.id == service }?.let { waybillFee(it, weightGrams) }
        return CreatedShipment("GHTK-${serial.getAndIncrement()}", fee)
    }

    override fun lookup(carrier: ShipCarrier, code: String, order: Order): Parcel? {
        val typed = code.trim()
        if (typed.isEmpty() || typed.startsWith(NOT_FOUND_PREFIX, ignoreCase = true)) return null
        val cod = if (typed.startsWith(WRONG_COD_PREFIX, ignoreCase = true)) order.price + WRONG_COD_EXTRA else order.price
        val district = order.recipient.line.substringAfterLast(", ").trim()
        return Parcel(masked(order.recipient.name), district, cod, reported[typed] ?: ShipmentStatus.PENDING_PICKUP, READ_FEE)
    }
}

/** A name as a carrier shows it to the sender: "Đức Huy" is "Đ••• H•••". */
internal fun masked(name: String): String = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ") { "${it.first()}•••" }
```

- [ ] **Step 6: The repository and the engine**

`Repositories.kt`, in `DealRepository` after `send`:

```kotlin
    /**
     * What [carrier] knows of [code] for the open order of [id], before the seller confirms it: the masked recipient,
     * the district and the COD amount; null when the carrier does not know the code.
     */
    suspend fun lookupShipment(id: DealId, carrier: ShipCarrier, code: String): Result<Parcel?>
```

and the `orderDraft` doc becomes `/** Đơn bán's half-filled "Tạo đơn" for [id], kept so leaving the page loses nothing; null if none. */`; `orders()`'s doc `/** Every deal with at least one order, on either side; Đơn hàng splits them into one row per order. */`. Imports gain `vn.shopnexus.core.model.Parcel` and `vn.shopnexus.core.model.ShipCarrier`.

Replace `fake/FakeDealEngine.kt` with:

```kotlin
package vn.shopnexus.core.data.fake

import java.time.Instant
import javax.inject.Inject
import vn.shopnexus.core.domain.CarrierClient
import vn.shopnexus.core.domain.DealRules
import vn.shopnexus.core.domain.EngineContext
import vn.shopnexus.core.model.Deal
import vn.shopnexus.core.model.DealCommand
import vn.shopnexus.core.model.DealView

/** Applies one command to a deal as the backend would; wrong amounts, commands out of order and commands from the wrong side throw. */
interface DealEngine {
    fun apply(view: DealView, command: DealCommand, now: Instant, context: EngineContext = EngineContext()): Deal

    /** The carrier the backend creates and reads shipments with. */
    val carrier: CarrierClient get() = FakeCarrier()
}

/** The fake backend: [DealRules] applies the command, with [carrier] for shipments. */
class FakeDealEngine @Inject constructor(override val carrier: FakeCarrier = FakeCarrier()) : DealEngine {
    override fun apply(view: DealView, command: DealCommand, now: Instant, context: EngineContext): Deal = DealRules.apply(view, command, now, context)
}
```

In `fake/FakeDealRepository.kt`:
- imports: drop `DealStage`, `VN_ZONE`, `isOrder` stays; add `vn.shopnexus.core.domain.shippedToAnother`, `vn.shopnexus.core.domain.shortTitle`, `vn.shopnexus.core.domain.withOrder`, `vn.shopnexus.core.model.DealStatus`, `vn.shopnexus.core.model.OrderStatus`, `vn.shopnexus.core.model.Parcel`, `vn.shopnexus.core.model.ShipCarrier`.
- `openDealAsBuyer`'s filter: `roleOf(d, me) == Party.BUYER && d.status != DealStatus.SOLD && match(d)`; its doc `/** A deal the person is still in as the buyer: not sold. A failed or cancelled order leaves the deal open to buy again. */`.
- delete `withCarrierQuote`.
- `newDeal`: `status = DealStatus.NEGOTIATING` in place of `stage = DealStage.NEGOTIATE`.
- replace `send` with:

```kotlin
    override suspend fun send(id: DealId, command: DealCommand): Result<Deal> {
        val result = failures.run {
            val now = clock.instant()
            // Applied inside the update: a simulator step landing meanwhile is retried against, never overwritten.
            world.modify { s ->
                val view = s.deals[id] ?: throw DataError.NotFound("deal $id")
                val account = s.account
                val context = EngineContext(
                    account = account,
                    openCod = openCodOrders(s.deals.values.map { it.deal }, view.me.id, now),
                    rights = if (account != null) s.liveRights(now) else EngineContext().rights,
                    carrier = engine.carrier,
                )
                val applied = engine.apply(view, command, now, context)
                // An address picked on Giao COD goes with this request alone; the default stays.
                val picked = s.checkoutAddress
                val deal = if (command == DealCommand.RequestCod && picked != null) {
                    applied.withOrder(checkNotNull(applied.currentOrder).copy(recipient = picked))
                } else {
                    applied
                }
                val others = if (command is DealCommand.CreateShipment) s.shippedToOthers(view.deal, now) else emptyMap()
                // The buyer's word earns DEAL's points, as the carrier's report used to.
                val received = ScoredEvent(ReputationEvent.DEAL, now, "Mua ${shortTitle(view.listing.title)}").takeIf { command == DealCommand.ConfirmReceived }
                s.copy(
                    deals = s.deals + others + (id to view.copy(deal = deal)),
                    checkoutAddress = s.checkoutAddress.takeIf { command != DealCommand.RequestCod },
                    checkoutAddressId = s.checkoutAddressId.takeIf { command != DealCommand.RequestCod },
                    reputation = s.reputation + listOfNotNull(received),
                ) to deal
            }
        }
        if (result.isSuccess) counterpart.onCommand(id, command)
        return result
    }

    override suspend fun lookupShipment(id: DealId, carrier: ShipCarrier, code: String): Result<Parcel?> = failures.run {
        val order = world.value.deals[id]?.deal?.openOrder ?: throw DataError.NotFound("open order on $id")
        engine.carrier.lookup(carrier, code, order)
    }
```

and add, after `openDealAsBuyer`:

```kotlin
/** The other buyers' pending orders on the listing [shipped] belongs to, each cancelled: the seller sent the item to someone else. */
private fun WorldState.shippedToOthers(shipped: Deal, now: Instant): Map<DealId, DealView> = deals.values
    .filter { v ->
        v.deal.id != shipped.id && v.deal.listingId == shipped.listingId && v.deal.sellerId == shipped.sellerId &&
            v.deal.openOrder?.status == OrderStatus.PENDING
    }
    .associate { it.deal.id to it.copy(deal = it.deal.shippedToAnother(now)) }
```

`fake/Seeds.kt`: `AccountSeed`'s `override val carriers` becomes `val carriers` (the account fixture keeps its list; `CodAccount` no longer has it, and shipments use `GHTK_SERVICES`); delete `DealSeed.recordReply` and `RecordReply`; `DealSeed`'s doc `/** A seeded deal with its conversation's state. */`. `fake/FakeWorld.kt`: delete `recordReplies` and its line in `initial()`.

`fake/FakeListingRepository.kt`: the deal filter is `v.deal.listingId == id && v.deal.buyerId == s.me?.id` (a deal no longer ends); drop the `DealStage` import and change the comment to `// The person's own deal on this listing, finished or not.`. `fake/FakeMyListingsRepository.kt`: `val people = on.sortedByDescending { … }` (drop the `ENDED` filter and the import). `fake/AccountFakes.kt`: `figures = Figures90(codFailed = a.codRefused90, codOrders = a.codOrders90)`, import `vn.shopnexus.core.model.Figures90`, drop `figures90`.

- [ ] **Step 7: The simulator's steps**

`fake/Simulator.kt`:
- constructor gains `private val carrier: FakeCarrier = FakeCarrier(),` last.
- delete `DOOR_MILLIS`, `SELF_RECEIPT_MILLIS`, `selfShippedSteps`; `CARRIER_STEP_MILLIS`'s doc `/** The carrier picks a parcel up, then delivers it, each this long after the step before. */`; `WAREHOUSE_STEP_MILLIS`'s doc `/** A parcel the person shipped reaches the warehouse near the buyer, then the buyer, each this long after the step before. */`; `RATE_MILLIS`'s doc `/** A simulated buyer says the parcel came this long after it is delivered, and rates this long after that. */`.
- `onCommand`'s `when` becomes:

```kotlin
        when (command) {
            is DealCommand.SendOffer -> reply(id, OFFER_REPLY_MILLIS) { view, now -> acceptOffer(view, command.amount, now) }
            is DealCommand.SendText -> answer(id, command.text)
            DealCommand.AcceptCounter -> reply(id, AGREED_REPLY_MILLIS) { view, now -> afterAgreement(view, now) }
            DealCommand.WithdrawOffer -> stop(id)
            // The seller ships on GHTK and the carrier delivers; the buyer's word, or 3 days, completes the order. A step
            // that lands after the buyer said so finds the order closed and changes nothing.
            DealCommand.RequestCod -> run(
                id,
                listOf(
                    Step(CREATE_MILLIS, false) { s, view, now -> s.sellerCreates(view, now, carrier) },
                    Step(CARRIER_STEP_MILLIS, false) { s, view, now -> s.pickedUp(view, now, carrier) },
                    Step(CARRIER_STEP_MILLIS, false) { s, view, now -> s.delivered(view, now, carrier) },
                ),
            )
            // A cancelled order needs no more steps; the pending ones and their typing dots stop.
            DealCommand.CancelOrder -> stop(id)
            else -> Unit
        }
```

- `onSellerCommand`'s `ShipParcel` and `CancelCod` branches become

```kotlin
            is DealCommand.CreateShipment -> run(id, carrierSteps)
            DealCommand.CancelOrder -> stop(id)
```

  and its doc `/** The person sells: the simulated buyer answers counters, chooses COD after agreement, says the parcel came and rates. */`.
- `carrierSteps` becomes

```kotlin
    /** The person's shipment, linked or manual: picked up, delivered, the buyer says it came, then the stars. */
    private val carrierSteps = listOf(
        Step(WAREHOUSE_STEP_MILLIS, false) { s, view, now -> s.pickedUp(view, now, carrier) },
        Step(WAREHOUSE_STEP_MILLIS, false) { s, view, now -> s.delivered(view, now, carrier) },
        Step(RATE_MILLIS, false, WorldState::buyerConfirms),
        Step(RATE_MILLIS, false, WorldState::buyerRates),
    )
```

- delete the `WithdrawRecord` and `OpenRecord` branches of `onCommand`.

`fake/SimulatorSteps.kt`: delete `sellerCreates`, `SELLER_SERVICE`, `SELLER_GRAMS`, `PICKUP_WINDOW`, `POST_OFFICE_KM`, `pickupWindow`, `buyerRates`, `refund`, `decline`, `district`, `pickUp`, `atDoor`, `warehouse`, `delivered`, `bought`, `sold` and `buyerGoesOn`, and add in their place:

```kotlin
/** Once the price is agreed the buyer chooses COD, above 5 triệu too; the person creates the shipment on Đơn bán. */
internal fun WorldState.buyerGoesOn(view: DealView, now: Instant): WorldState {
    val deal = view.deal
    val price = deal.agreedPrice ?: return this
    if (deal.status != DealStatus.AGREED || deal.openOrder != null) return this
    val buyer = view.counterpart.name
    val order = Order(deal.nextOrderId(), OrderStatus.PENDING, DeliveryAddress(buyer, "09•• ••• 345", view.counterpartArea ?: VY_AREA), price, now)
    val next = deal.copy(
        orders = deal.orders + order,
        thread = deal.thread + ThreadItem.Text(Party.BUYER, "Ok bạn, mình chọn COD nhé.", now) +
            ThreadItem.Event("local_shipping", "$buyer đã chọn giao COD", now),
    )
    return withDeal(deal.id, view.copy(deal = next))
}

/** The service, weight and pickup the simulated seller creates every shipment with: Giao nhanh, 2 kg, from home. */
private const val SELLER_SERVICE = "express"
private const val SELLER_GRAMS = 2_000

/** The simulated seller ships the person's order on GHTK, and the person is told. A request cancelled meanwhile gets nothing. */
internal fun WorldState.sellerCreates(view: DealView, now: Instant, carrier: CarrierClient): WorldState {
    val deal = view.deal
    val order = deal.openOrder?.takeIf { it.status == OrderStatus.PENDING } ?: return this
    val created = carrier.create(SELLER_SERVICE, SELLER_GRAMS, Pickup.HOME, order.price)
    val seller = view.counterpart.name
    val shipment = Shipment(ShipmentMode.LINKED, ShipCarrier.GHTK, created.trackingCode, created.fee)
    val next = deal.withOrder(order.copy(status = OrderStatus.SHIPPED, shipment = shipment, shippedAt = now))
        .copy(thread = deal.thread + ThreadItem.Event("local_shipping", "$seller đã gửi hàng qua GHTK · ${created.trackingCode}", now))
    val notice = Notification(
        id = "shipped-${deal.id.value}",
        kind = NotificationKind.DEAL,
        icon = "local_shipping",
        tone = Tone.TRUST,
        text = "$seller đã gửi ${shortTitle(view.listing.title)} qua GHTK",
        at = now,
        unread = true,
        target = NotificationTarget.Order(deal.id),
    )
    return copy(deals = deals + (deal.id to view.copy(deal = next)), notifications = listOf(notice) + notifications.filterNot { it.id == notice.id })
}

/** Where a side of the deal lives: the signed-in person's district, a seller's, or the order's recipient. */
private fun WorldState.district(view: DealView, party: Party): String {
    val id = if (party == Party.SELLER) view.deal.sellerId else view.deal.buyerId
    return me?.takeIf { it.id == id }?.district ?: sellers[id]?.district ?: view.deal.currentOrder?.recipient?.line.orEmpty()
}

/**
 * The carrier reports [status] for [code]: every open order shipped with that code moves, as the server's
 * `ShipmentUpdated` does, and [carrier] remembers it for the next lookup. A closed order changes nothing.
 */
internal fun WorldState.carrierReported(code: String, status: ShipmentStatus, now: Instant, events: List<CarrierEvent>, carrier: FakeCarrier): WorldState {
    carrier.report(code, status)
    return copy(
        deals = deals.mapValues { (_, v) ->
            if (v.deal.openOrder?.shipment?.trackingCode == code) v.copy(deal = v.deal.shipmentUpdated(status, now, events)) else v
        },
    )
}

/** The carrier picks the parcel up and brings it to the warehouse near the buyer. A cancel or a receipt that landed first stays. */
internal fun WorldState.pickedUp(view: DealView, now: Instant, carrier: FakeCarrier): WorldState {
    val shipment = view.deal.openOrder?.shipment?.takeIf { it.status == ShipmentStatus.PENDING_PICKUP } ?: return this
    val events = listOf(
        CarrierEvent("Đã lấy hàng tại ${district(view, Party.SELLER)}", now),
        CarrierEvent("Đến kho ${district(view, Party.BUYER)}", now),
    )
    return carrierReported(shipment.trackingCode, ShipmentStatus.IN_TRANSIT, now, events, carrier)
}

/** The carrier delivers the parcel; the person, when they bought it, is told so they can say it came. */
internal fun WorldState.delivered(view: DealView, now: Instant, carrier: FakeCarrier): WorldState {
    val deal = view.deal
    val shipment = deal.openOrder?.shipment?.takeIf { it.status == ShipmentStatus.IN_TRANSIT } ?: return this
    val moved = carrierReported(shipment.trackingCode, ShipmentStatus.DELIVERED, now, listOf(CarrierEvent("Đã giao hàng", now)), carrier)
    val notice = Notification(
        id = "delivered-${deal.id.value}",
        kind = NotificationKind.DEAL,
        icon = "package_2",
        tone = Tone.TRUST,
        text = "Đã giao ${shortTitle(view.listing.title)}",
        at = now,
        unread = true,
        target = NotificationTarget.Order(deal.id),
    ).takeIf { deal.buyerId == me?.id }
    return moved.copy(notifications = listOfNotNull(notice) + notifications.filterNot { it.id == notice?.id })
}

/** The simulated buyer says the person's parcel came; the sale earns the person DEAL's points. */
internal fun WorldState.buyerConfirms(view: DealView, now: Instant): WorldState {
    val deal = view.deal
    if (deal.openOrder?.status != OrderStatus.SHIPPED) return this
    return copy(
        deals = deals + (deal.id to view.copy(deal = deal.completed(now))),
        reputation = reputation + ScoredEvent(ReputationEvent.DEAL, now, "Bán ${shortTitle(view.listing.title)}"),
    )
}

/** The buyer rates the person five stars after a completed order. */
internal fun WorldState.buyerRates(view: DealView, now: Instant): WorldState {
    val deal = view.deal
    if (deal.status != DealStatus.SOLD || deal.rating != null) return this
    val next = deal.copy(
        rating = 5,
        ratedAt = now,
        thread = deal.thread + ThreadItem.Event("star", "${view.counterpart.name} đánh giá bạn 5 sao", now),
    )
    return copy(
        deals = deals + (deal.id to view.copy(deal = next)),
        reputation = reputation + ScoredEvent(ReputationEvent.RATED_5, now, "${view.counterpart.name} đánh giá 5 sao"),
    )
}
```

and in the same file: `asking` builds `status = DealStatus.NEGOTIATING`; `offering`, `acceptCounter` test `deal.status != DealStatus.NEGOTIATING`; `afterAgreement` tests `deal.status != DealStatus.AGREED || deal.openOrder != null`. Imports: drop `TimeWindow`, `CodRequest`, `CodShipment`, `CodStatus`, `DealStage`, `RecordStatus`, `MilestoneKind` stays, `shippingCode`, `waybillFee`, `todayAt`, `Duration`, `ChronoUnit`, `ZoneId`, `full`; add `CarrierClient`, `completed`, `nextOrderId`, `shipmentUpdated`, `withOrder` (from `vn.shopnexus.core.domain`; `FakeCarrier` is in the same package), `DealStatus`, `Order`, `OrderStatus`, `Pickup`, `ShipCarrier`, `Shipment`, `ShipmentMode`, `ShipmentStatus`.

- [ ] **Step 8: The jumps and the debug controls**

Replace `fake/OrderJumps.kt` with:

```kotlin
package vn.shopnexus.core.data.fake

import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import kotlin.math.absoluteValue
import vn.shopnexus.core.domain.cancelled
import vn.shopnexus.core.domain.completed
import vn.shopnexus.core.domain.nextOrderId
import vn.shopnexus.core.domain.shipmentUpdated
import vn.shopnexus.core.domain.withOrder
import vn.shopnexus.core.model.CancelReason
import vn.shopnexus.core.model.CarrierEvent
import vn.shopnexus.core.model.Deal
import vn.shopnexus.core.model.DealId
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.DealView
import vn.shopnexus.core.model.DeliveryAddress
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Party
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.Shipment
import vn.shopnexus.core.model.ShipmentMode
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.ThreadItem
import vn.shopnexus.core.model.UserId
import vn.shopnexus.core.model.Vnd

/** The states the debug panel jumps a seeded order to. A failed delivery comes only from here. */
enum class OrderJump { PENDING, SHIPPED, DELIVERED, COMPLETED, FAILED, CANCELLED }

/** The seeded orders the debug panel jumps, each to every state. */
val ORDER_JUMPS: Map<DealId, List<OrderJump>> = listOf("d-nam", "d-huy", "d-han", "d-bao").associate { DealId(it) to OrderJump.entries }

/** How long before now a jump's request, its shipment, the pickup and the warehouse were. */
private val REQUESTED_AGO = Duration.ofMinutes(40)
private val SHIPPED_AGO = Duration.ofMinutes(30)
private val PICKED_UP_AGO = Duration.ofMinutes(20)
private val WAREHOUSE_AGO = Duration.ofMinutes(10)

private const val JUMP_CODE_MIN = 100_000
private const val JUMP_CODE_SPAN = 900_000

/** The GHTK code a jump gives an order seeded without a shipment, stable per deal. */
private fun jumpCode(id: DealId) = "GHTK-${id.value.hashCode().absoluteValue % JUMP_CODE_SPAN + JUMP_CODE_MIN}"

/** Where a side of the deal lives: the signed-in person's district, a seller's, or the order's recipient. */
private fun districtOf(view: DealView, person: UserId): String = when (person) {
    view.me.id -> view.me.district
    view.deal.sellerId -> Fixtures.sellers().firstOrNull { it.seller.id == person }?.district.orEmpty()
    else -> view.deal.currentOrder?.recipient?.line.orEmpty()
}

/** The seeded deal moved to [jump], with the thread items and carrier events a real walk would have left, timed just before [now]. */
@Suppress("UnusedParameter")
fun orderAt(start: DealView, jump: OrderJump, now: Instant, zone: ZoneId): DealView {
    val selling = start.deal.sellerId == start.me.id
    val pending = pending(start, now)
    val shipped by lazy { shipped(start, pending, now) }
    val moving by lazy { inTransit(start, shipped, now) }
    val delivered by lazy { moving.shipmentUpdated(ShipmentStatus.DELIVERED, now, listOf(CarrierEvent("Đã giao hàng", now))) }
    val next = when (jump) {
        OrderJump.PENDING -> pending
        OrderJump.SHIPPED -> shipped
        OrderJump.DELIVERED -> delivered
        OrderJump.COMPLETED -> delivered.completed(now)
        OrderJump.FAILED -> moving.shipmentUpdated(ShipmentStatus.FAILED, now, listOf(CarrierEvent("Giao không thành", now)))
        OrderJump.CANCELLED ->
            pending.cancelled(if (selling) Party.SELLER else Party.BUYER, if (selling) CancelReason.SELLER else CancelReason.BUYER, now, "Bạn đã hủy đơn")
    }
    return start.copy(deal = next)
}

/** The seeded deal back at its agreement: no order, the thread up to its first request, the price it agreed. */
private fun agreedAt(start: DealView): Deal {
    val deal = start.deal
    val first = deal.orders.firstOrNull()
    val price = checkNotNull(deal.agreedPrice ?: first?.price) { "A seeded order deal has a price" }
    return deal.copy(
        status = DealStatus.AGREED,
        agreedPrice = price,
        orders = emptyList(),
        rating = null,
        ratedAt = null,
        thread = first?.let { f -> deal.thread.filter { it.at < f.requestedAt } } ?: deal.thread,
    )
}

/** The buyer's request, made [REQUESTED_AGO]: to the seeded recipient, the buyer's district, or the account's address. */
private fun pending(start: DealView, now: Instant): Deal {
    val base = agreedAt(start)
    val selling = start.deal.sellerId == start.me.id
    val at = now.minus(REQUESTED_AGO)
    val recipient = start.deal.orders.firstOrNull()?.recipient
        ?: if (selling) DeliveryAddress(start.counterpart.name, "09•• ••• 345", start.counterpartArea.orEmpty()) else Fixtures.account().address
    val line = if (selling) "${start.counterpart.name} đã chọn giao COD" else "Đã chọn giao COD"
    val order = Order(base.nextOrderId(), OrderStatus.PENDING, recipient, checkNotNull(base.agreedPrice), at)
    return base.copy(orders = listOf(order), thread = base.thread + ThreadItem.Event("local_shipping", line, at))
}

/** The shipment, made [SHIPPED_AGO]: the seeded one waiting for its pickup, or a GHTK one on the seller's account. */
private fun shipped(start: DealView, pending: Deal, now: Instant): Deal {
    val selling = start.deal.sellerId == start.me.id
    val at = now.minus(SHIPPED_AGO)
    val shipment = start.deal.orders.firstOrNull()?.shipment?.copy(status = ShipmentStatus.PENDING_PICKUP, events = emptyList(), deliveredAt = null)
        ?: Shipment(ShipmentMode.LINKED, ShipCarrier.GHTK, jumpCode(start.deal.id), Vnd(22_000))
    val person = start.counterpart.name
    val code = shipment.trackingCode
    val line = when {
        shipment.mode == ShipmentMode.MANUAL && selling -> "Đã gửi qua ${shipment.carrier.label} · $code"
        shipment.mode == ShipmentMode.MANUAL -> "$person đã gửi qua ${shipment.carrier.label} · $code"
        selling -> "Đã tạo đơn GHTK · $code"
        else -> "$person đã gửi hàng qua GHTK · $code"
    }
    val order = checkNotNull(pending.currentOrder).copy(status = OrderStatus.SHIPPED, shipment = shipment, shippedAt = at)
    return pending.withOrder(order).copy(thread = pending.thread + ThreadItem.Event("local_shipping", line, at))
}

/** The shipment picked up [PICKED_UP_AGO] and at the buyer's warehouse [WAREHOUSE_AGO]. */
private fun inTransit(start: DealView, shipped: Deal, now: Instant): Deal = shipped.shipmentUpdated(
    ShipmentStatus.IN_TRANSIT,
    now,
    listOf(
        CarrierEvent("Đã lấy hàng tại ${districtOf(start, start.deal.sellerId)}", now.minus(PICKED_UP_AGO)),
        CarrierEvent("Đến kho ${districtOf(start, start.deal.buyerId)}", now.minus(WAREHOUSE_AGO)),
    ),
)
```

In `fake/DebugControls.kt`:
- imports: drop `vn.shopnexus.core.domain.OrderStatus`.
- `ConsoleTarget` and its doc become

```kotlin
/**
 * The console states the panel can jump Tuấn Kiệt's iPhone to, by COD: PENDING is the request before Tuấn Kiệt creates
 * the shipment, SHIPPED after it, RECEIVED the completed order before the stars. Offering is the buyer's own draft, so it
 * is not one of them.
 */
enum class ConsoleTarget { COUNTERED, WAITING, AGREED, PENDING, SHIPPED, RECEIVED, DONE }
```

- `dealAt` becomes (an order's jump agrees 50 minutes back, after the fixture's last message at 07:10, so the request 40 minutes back follows it in the thread):

```kotlin
/** How long before now a console jump past the handshake agreed the price. */
private val AGREED_AGO = Duration.ofMinutes(50)

/** The fixture deal moved to [target], with the thread items and carrier events a real walk would have left. */
internal fun dealAt(start: DealView, target: ConsoleTarget, now: Instant, zone: ZoneId): Deal {
    val deal = start.deal
    if (target == ConsoleTarget.COUNTERED) return deal
    val counter = checkNotNull(deal.openCounter) { "The fixture deal starts with a counter" }
    if (target == ConsoleTarget.WAITING) {
        val offer = Vnd(counter.amount.amount - 100_000)
        return deal.copy(
            offers = deal.offers + Offer(Party.BUYER, offer, now, OfferStatus.OPEN),
            thread = deal.thread + ThreadItem.PriceMove(Party.BUYER, offer, accepted = false, at = now),
        )
    }
    val at = if (target == ConsoleTarget.AGREED) now else now.minus(AGREED_AGO)
    val agreed = deal.agreed(counter.amount, counter, at).copy(
        thread = deal.thread + ThreadItem.PriceMove(Party.BUYER, counter.amount, accepted = true, at = at) + ThreadItem.Milestone(MilestoneKind.AGREED, at),
    )
    val jump = when (target) {
        ConsoleTarget.AGREED -> return agreed
        ConsoleTarget.PENDING -> OrderJump.PENDING
        ConsoleTarget.SHIPPED -> OrderJump.SHIPPED
        else -> OrderJump.COMPLETED
    }
    val moved = orderAt(start.copy(deal = agreed), jump, now, zone).deal
    // A rating leaves the line Rate leaves.
    if (target != ConsoleTarget.DONE) return moved
    return moved.copy(rating = 5, ratedAt = now, thread = moved.thread + ThreadItem.Event("star", "5 sao cho ${start.counterpart.name}", now))
}
```

  (`java.time.Duration` joins the imports.)
- `jumpOrder` becomes

```kotlin
    /** Moves a seeded order to [jump] (`ORDER_JUMPS` lists them), as a real walk would have left it. */
    fun jumpOrder(id: DealId, jump: OrderJump) {
        simulator.stop(id)
        val start = FakeWorld.initial().deals.getValue(id)
        world.update { s -> s.copy(deals = s.deals + (id to orderAt(start, jump, clock.instant(), zone))) }
    }
```

Then `grep -rn "DealStage\|CodStatus\|CodShipment\|CodRequest\|RecordStatus\|RecordReply\|recordReplies\|\.cod\b\|codRequest\|OrderStatus\.\(REQUESTED\|TO_CREATE\|PLACED\|TO_SHIP\|SHIPPING\|AT_DOOR\|RECEIVED\|REVIEWED\|REFUSED\|RECORD\)" core/data/src` prints nothing.

- [ ] **Step 9: Run the data tests**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:data:testDebugUnitTest`
Expected: BUILD SUCCESSFUL; `FakeCarrierTest` 5, `SimulatorOrderTest` 7, `OrderJumpsTest` 6 pass, with the ported tests.

- [ ] **Step 10: Commit**

```bash
./gradlew :core:data:spotlessApply
git add core/data
git commit -m "feat(data): a fake carrier, seeded orders and shipments, and the carrier's steps in the simulator"
```

Then stop the daemons.

### Task 4: The 3-day timers

**Files:**
- Create: `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/OrderTimers.kt`
- Modify: `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/Simulator.kt`
- Test: `core/data/src/test/kotlin/vn/shopnexus/core/data/fake/OrderTimersTest.kt`

**Interfaces:**
- Consumes: Task 2's `ORDER_WAIT`, `sellerTimedOut`, `pickupTimedOut`, `autoCompleted`; Task 3's `Simulator`, `withDeal`.
- Produces: `internal class OrderTimers(world: FakeWorld, clock: Clock, scope: CoroutineScope, pace: Pace)` with `start()` and `stop()`. The simulator starts it when it is built and `stopAll()` stops it; nothing else calls it.

- [ ] **Step 1: Write the failing timer tests**

Create `core/data/src/test/kotlin/vn/shopnexus/core/data/fake/OrderTimersTest.kt`:

```kotlin
package vn.shopnexus.core.data.fake

import com.google.common.truth.Truth.assertThat
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test
import vn.shopnexus.core.domain.ORDER_WAIT
import vn.shopnexus.core.domain.ReputationEvent
import vn.shopnexus.core.domain.VN_ZONE
import vn.shopnexus.core.model.CancelReason
import vn.shopnexus.core.model.DealCommand
import vn.shopnexus.core.model.DealId
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.ListingId
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.Vnd
import vn.shopnexus.core.testing.SchedulerClock

/** The server's three timers as the simulator plays them, on virtual time from the fixture moment. */
class OrderTimersTest {
    private val huy = DealId("d-huy")
    private val han = DealId("d-han")
    private val nam = DealId("d-nam")

    private class Setup(val world: FakeWorld, val deals: FakeDealRepository, val controls: DebugControls, val clock: SchedulerClock)

    private fun TestScope.setup(): Setup {
        val world = FakeWorld()
        val clock = SchedulerClock(testScheduler)
        val simulator = Simulator(world, clock, backgroundScope, VN_ZONE, Pace())
        val deals = FakeDealRepository(world, FailurePolicy(latencyMillis = 0), FakeDealEngine(), clock, simulator)
        return Setup(world, deals, DebugControls(world, simulator, FailurePolicy(), clock, VN_ZONE), clock)
    }

    private fun TestScope.after(millis: Long) {
        advanceTimeBy(millis)
        runCurrent()
    }

    /** Milliseconds from the fixture moment until 3 days after [from]. */
    private fun until(from: Instant) = Duration.between(Fixtures.NOW, from.plus(ORDER_WAIT)).toMillis()

    /** Đức Huy asked for COD at 02:12; Khánh Linh never creates the shipment. */
    @Test
    fun aPendingSaleIsCancelledThreeDaysAfterItsRequest() = runTest {
        val s = setup()
        fun deal() = s.world.value.deals.getValue(huy).deal
        val due = until(deal().currentOrder!!.requestedAt)
        after(due - 1)
        assertThat(deal().currentOrder!!.status).isEqualTo(OrderStatus.PENDING)
        after(1)
        val order = deal().currentOrder!!
        assertThat(order.status).isEqualTo(OrderStatus.CANCELLED)
        assertThat(order.cancelReason).isEqualTo(CancelReason.SELLER_TIMEOUT)
        assertThat(order.cancelledBy).isNull()
        assertThat(deal().status).isEqualTo(DealStatus.NEGOTIATING)
        assertThat(s.world.value.isReserved(ListingId("my-stool"), s.clock.instant())).isFalse()
    }

    /** Ngọc Hân sent the bike on SPX at 12:45 on the 14th; the carrier never picks it up. */
    @Test
    fun aShipmentNobodyPickedUpIsCancelledThreeDaysAfterItShipped() = runTest {
        val s = setup()
        fun deal() = s.world.value.deals.getValue(han).deal
        val due = until(deal().currentOrder!!.shippedAt!!)
        after(due - 1)
        assertThat(deal().currentOrder!!.status).isEqualTo(OrderStatus.SHIPPED)
        after(1)
        assertThat(deal().currentOrder!!.status).isEqualTo(OrderStatus.CANCELLED)
        assertThat(deal().currentOrder!!.cancelReason).isEqualTo(CancelReason.PICKUP_TIMEOUT)
        assertThat(deal().status).isEqualTo(DealStatus.NEGOTIATING)
    }

    /**
     * Khánh Linh buys Hoàng Nam's iPhone; it is delivered 10 s later and she says nothing. Its seller timeout and its
     * pickup timeout fire on an order that moved on and change nothing; it completes 3 days after delivery.
     */
    @Test
    fun aDeliveredOrderCompletesThreeDaysLater() = runTest {
        val s = setup()
        fun deal() = s.world.value.deals.getValue(nam).deal
        s.deals.send(nam, DealCommand.RequestCod).getOrThrow()
        after(10_000)
        val delivered = deal().currentOrder!!.shipment!!
        assertThat(delivered.status).isEqualTo(ShipmentStatus.DELIVERED)
        val due = until(delivered.deliveredAt!!)
        after(due - 10_000 - 1)
        assertThat(deal().currentOrder!!.status).isEqualTo(OrderStatus.SHIPPED)
        after(1)
        assertThat(deal().currentOrder!!.status).isEqualTo(OrderStatus.COMPLETED)
        assertThat(deal().status).isEqualTo(DealStatus.SOLD)
        assertThat(s.world.value.reputation.last().event).isEqualTo(ReputationEvent.DEAL)
        assertThat(s.world.value.reputation.last().text).isEqualTo("Mua iPhone X")
    }

    /** Khánh Linh cancels Đức Huy's order; a day later he asks again. The first timer fires while the second order waits. */
    @Test
    fun aTimerForAnOlderOrderLeavesTheNewOneAlone() = runTest {
        val s = setup()
        fun deal() = s.world.value.deals.getValue(huy).deal
        val firstDue = until(deal().currentOrder!!.requestedAt)
        s.deals.send(huy, DealCommand.CancelOrder).getOrThrow()
        after(Duration.ofDays(1).toMillis())
        val again = Order(OrderId("d-huy-o2"), OrderStatus.PENDING, deal().currentOrder!!.recipient, Vnd(350_000), s.clock.instant())
        s.world.update { w ->
            val v = w.deals.getValue(huy)
            w.copy(deals = w.deals + (huy to v.copy(deal = v.deal.copy(status = DealStatus.AGREED, agreedPrice = Vnd(350_000), orders = v.deal.orders + again))))
        }
        after(firstDue - Duration.ofDays(1).toMillis() + 1)
        assertThat(deal().currentOrder!!.id).isEqualTo(OrderId("d-huy-o2"))
        assertThat(deal().currentOrder!!.status).isEqualTo(OrderStatus.PENDING)
        after(until(again.requestedAt) - firstDue)
        assertThat(deal().currentOrder!!.status).isEqualTo(OrderStatus.CANCELLED)
        assertThat(deal().orders.map { it.cancelReason }).containsExactly(CancelReason.SELLER, CancelReason.SELLER_TIMEOUT).inOrder()
    }

    /** The debug panel's reset drops the timers and sets them again from the seeds. */
    @Test
    fun aResetSetsTheTimersAgainFromTheSeeds() = runTest {
        val s = setup()
        s.deals.send(huy, DealCommand.CancelOrder).getOrThrow()
        after(1_000)
        s.controls.reset()
        assertThat(s.world.value.deals.getValue(huy).deal.currentOrder!!.status).isEqualTo(OrderStatus.PENDING)
        after(until(s.world.value.deals.getValue(huy).deal.currentOrder!!.requestedAt))
        assertThat(s.world.value.deals.getValue(huy).deal.currentOrder!!.cancelReason).isEqualTo(CancelReason.SELLER_TIMEOUT)
    }
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:data:testDebugUnitTest --tests '*OrderTimersTest*'`
Expected: the five tests FAIL (the orders stay as they were after 3 days).

- [ ] **Step 3: `OrderTimers.kt`**

Create `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/OrderTimers.kt`:

```kotlin
package vn.shopnexus.core.data.fake

import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import vn.shopnexus.core.domain.ORDER_WAIT
import vn.shopnexus.core.domain.ReputationEvent
import vn.shopnexus.core.domain.ScoredEvent
import vn.shopnexus.core.domain.autoCompleted
import vn.shopnexus.core.domain.pickupTimedOut
import vn.shopnexus.core.domain.sellerTimedOut
import vn.shopnexus.core.domain.shortTitle
import vn.shopnexus.core.model.Deal
import vn.shopnexus.core.model.DealId
import vn.shopnexus.core.model.DealView
import vn.shopnexus.core.model.OrderId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.ShipmentStatus

/**
 * The server's durable work on orders, played on the world: a pending order is cancelled 3 days after its request, a
 * shipment nobody picked up 3 days after it shipped, and a delivered parcel completes 3 days after delivery. Each timer
 * is set once per order and kind, from that order's own time, so seeded orders and debug jumps get theirs; it reads the
 * order when it fires and changes nothing when the order moved on.
 */
internal class OrderTimers(
    private val world: FakeWorld,
    private val clock: Clock,
    private val scope: CoroutineScope,
    private val pace: Pace,
) {
    private val set = ConcurrentHashMap<String, Job>()

    /** Raised by [stop]; a timer set before it writes nothing. */
    private val epoch = AtomicLong()

    @Volatile private var watching: Job? = null

    fun start() {
        if (watching != null) return
        watching = scope.launch { world.flow.collect(::schedule) }
    }

    /** Drops every timer, for the debug panel's reset, and sets them again from the world as it is now. */
    fun stop() {
        epoch.incrementAndGet()
        set.values.forEach { it.cancel() }
        set.clear()
        schedule(world.value)
    }

    private fun schedule(state: WorldState) {
        for (view in state.deals.values) {
            val order = view.deal.openOrder ?: continue
            val shipment = order.shipment
            val id = view.deal.id
            when {
                order.status == OrderStatus.PENDING -> timer(id, order.id, "seller", order.requestedAt) { d, now -> d.sellerTimedOut(order.id, now) }
                shipment?.status == ShipmentStatus.PENDING_PICKUP ->
                    timer(id, order.id, "pickup", order.shippedAt ?: order.requestedAt) { d, now -> d.pickupTimedOut(order.id, now) }
                shipment?.status == ShipmentStatus.DELIVERED ->
                    timer(id, order.id, "complete", shipment.deliveredAt ?: clock.instant()) { d, now -> d.autoCompleted(order.id, now) }
            }
        }
    }

    private fun timer(id: DealId, order: OrderId, kind: String, from: Instant, move: (Deal, Instant) -> Deal) {
        val key = "$kind-${order.value}"
        if (set.containsKey(key)) return
        val started = epoch.get()
        val left = Duration.between(clock.instant(), from.plus(ORDER_WAIT)).toMillis().coerceAtLeast(0)
        val job = scope.launch(start = CoroutineStart.LAZY) {
            delay(pace.of(left))
            world.update { s ->
                val view = s.deals[id]
                if (epoch.get() != started || view == null) return@update s
                val now = clock.instant()
                val next = move(view.deal, now)
                if (next == view.deal) s else s.withDeal(id, view.copy(deal = next)).scored(view, next, now)
            }
        }
        // Started only once it is in the map, so a second world change in between never sets the same timer twice.
        if (set.putIfAbsent(key, job) == null) job.start() else job.cancel()
    }
}

/** An order the timer completed earns the person DEAL's points, as the buyer's word does. */
private fun WorldState.scored(before: DealView, after: Deal, now: Instant): WorldState {
    if (after.currentOrder?.status != OrderStatus.COMPLETED || before.deal.currentOrder?.status == OrderStatus.COMPLETED) return this
    val word = if (after.buyerId == me?.id) "Mua" else "Bán"
    return copy(reputation = reputation + ScoredEvent(ReputationEvent.DEAL, now, "$word ${shortTitle(before.listing.title)}"))
}
```

- [ ] **Step 4: The simulator runs them**

In `Simulator.kt`, after the `epoch` declaration:

```kotlin
    /** The 3-day timers, which run for as long as the simulator does. */
    private val timers = OrderTimers(world, clock, scope, pace).also { it.start() }
```

and `stopAll()` gains `timers.stop()` as its last line; its doc becomes `/** Cancels every pending step and timer, for the debug panel's reset; a step already running writes nothing after this. */`.

- [ ] **Step 5: Run the data tests**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:data:testDebugUnitTest`
Expected: BUILD SUCCESSFUL; `OrderTimersTest` 5 tests pass and Task 3's tests still pass (their waits are seconds; no timer is due).

- [ ] **Step 6: Commit**

```bash
./gradlew :core:data:spotlessApply
git add core/data
git commit -m "feat(data): the seller, pickup and receipt timers run three days from each order's own time"
```

Then stop the daemons.

### Task 5: Order copy and the four steps; records leave `:core:ui`

**Files:**
- Create: `tmp/unused_strings.py` (scratch)
- Modify: `core/navigation/src/main/kotlin/vn/shopnexus/core/navigation/Routes.kt`; `core/designsystem/src/main/res/values/strings.xml`; `core/ui/src/main/kotlin/vn/shopnexus/core/ui/deal/OrderCopy.kt` (whole file); `core/ui/src/main/res/values/strings.xml`
- Delete: `core/ui/src/main/kotlin/vn/shopnexus/core/ui/deal/RecordCard.kt`, `RecordSheet.kt`, `RecordDrafts.kt`, `Drafts.kt`
- Test: `core/ui/src/test/kotlin/vn/shopnexus/core/ui/deal/DealPiecesTest.kt`; `core/designsystem/src/test/kotlin/vn/shopnexus/core/designsystem/DealComponentsTest.kt`, `StepIconsTest.kt`, `OrderComponentsTest.kt` (labels)

**Interfaces:**
- Consumes: Tasks 1–3 (`Order`, `ShipmentStatus`, `orderAt`, `OrderJump`, `shipmentUpdated`).
- Produces: `OrderRoute(dealId: String, sent: Boolean = false, orderId: String? = null)`; `fun DealView.order(id: String?): Order?`; `@Composable fun orderLine(view: DealView, order: Order, now: Instant, zone: ZoneId): OrderLine`; `@Composable fun orderAction(view: DealView, order: Order): OrderAction?`; `itemRoute(view)` unchanged. `RecordCard`, `RecordSheet`, `RecordDraft`, `RecordDrafts` are gone.

- [ ] **Step 1: The unused-strings check**

Write `tmp/unused_strings.py`:

```python
#!/usr/bin/env python3
"""Prints the names in one strings.xml that no Kotlin or XML source outside the tests reads."""
import os
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
strings = (root / sys.argv[1]).resolve()
names = re.findall(r'<string name="([^"]+)"', strings.read_text(encoding="utf-8"))
SKIP = {"build", "tmp", "test", "testDebug", "androidTest"}
texts = []
for folder, subfolders, files in os.walk(root):
    subfolders[:] = [d for d in subfolders if d not in SKIP and not d.startswith(".")]
    if "/src/" not in folder:
        continue
    for name in files:
        if name.endswith((".kt", ".xml")) and name != "strings.xml":
            texts.append(Path(folder, name).read_text(encoding="utf-8"))
text = "\n".join(texts)
for name in names:
    if not re.search(rf"string\.{re.escape(name)}\b|@string/{re.escape(name)}\b", text):
        print(name)
```

Run: `python3 tmp/unused_strings.py core/ui/src/main/res/values/strings.xml` from the worktree root. Expected now: no output (nothing is unused yet).

- [ ] **Step 2: Write the failing tests**

In `DealPiecesTest.kt`, replace the helpers `at`, `requested`, `selfShipped`, `cancelled`, `notReceived`, `read` and the tests `linesReadAsTheOrdersTableSays`, `theLineReadsTheActiveRecord`, `iconsKeepTheirMeaning`, `actionsOpenTheOrderOrTheChat` with the code below; delete `aRecordNeedsAPhotoAndText`, `aRecordAsksForNoAccountAndQuotesNothing` and every other test that builds a `RecordSheet` or a `RecordDraft`. Imports: drop `OrderStatus`, `orderStatus`, `Carrier`, `CodRequest`, `CodStatus`, `DealEnd`, `DealStage`, `Party`, `Vnd` if unused, `RecordDraft`; add `vn.shopnexus.core.data.fake.OrderJump`, `vn.shopnexus.core.domain.shipmentUpdated`, `vn.shopnexus.core.model.ShipmentStatus`.

```kotlin
    private fun at(id: String, jump: OrderJump? = null): DealView = Fixtures.deal(id).let { if (jump == null) it else orderAt(it, jump, now, VN_ZONE) }

    /** [v] with its shipment where the carrier says it is. */
    private fun carrier(v: DealView, status: ShipmentStatus): DealView = v.copy(deal = v.deal.shipmentUpdated(status, now))

    /** Reads [orderLine] and [orderAction] for each view's current order inside one composition. */
    private fun read(views: List<DealView>): List<Pair<OrderLine, OrderAction?>> {
        val out = mutableListOf<Pair<OrderLine, OrderAction?>>()
        compose.setContent {
            ShopNexusTheme {
                views.forEach { v ->
                    val order = v.deal.currentOrder!!
                    out += orderLine(v, order, now, VN_ZONE) to orderAction(v, order)
                }
            }
        }
        compose.waitForIdle()
        return out
    }

    /** The buyer reads two words through the whole order; the seller follows the carrier. No line tells a timer. */
    @Test
    fun linesReadAsTheOrdersTableSays() {
        val cases = listOf(
            at("d-nam", OrderJump.PENDING) to "Chờ người bán tạo đơn",
            at("d-huy") to "Đức Huy chờ bạn tạo đơn",
            at("d-han") to "Chờ giao hàng",
            carrier(at("d-han"), ShipmentStatus.IN_TRANSIT) to "Chờ giao hàng",
            at("d-nam", OrderJump.DELIVERED) to "Chờ giao hàng",
            at("d-huy", OrderJump.SHIPPED) to "Chờ GHTK lấy hàng",
            carrier(at("d-huy", OrderJump.SHIPPED), ShipmentStatus.IN_TRANSIT) to "Đang giao cho Đức Huy",
            at("d-huy", OrderJump.DELIVERED) to "Đã giao cho Đức Huy",
            at("d-xm4") to "Đã nhận hàng · Thứ Hai",
            at("d-nam", OrderJump.COMPLETED).let { it.copy(deal = it.deal.copy(rating = 5)) } to "5 sao cho Hoàng Nam",
            at("d-bao") to "Gia Bảo đã nhận hàng · Thứ Hai",
            at("d-nam", OrderJump.FAILED) to "Giao không thành",
            at("d-huy", OrderJump.FAILED) to "Giao không thành",
            at("d-nam", OrderJump.CANCELLED) to "Đã hủy đơn",
        )
        val lines = read(cases.map { it.first }).map { it.first.text }
        assertThat(lines).containsExactlyElementsIn(cases.map { it.second }).inOrder()
    }

    @Test
    fun iconsKeepTheirMeaning() {
        val icons = read(
            listOf(
                at("d-nam", OrderJump.PENDING),
                at("d-huy"),
                at("d-han"),
                at("d-huy", OrderJump.SHIPPED),
                at("d-huy", OrderJump.DELIVERED),
                at("d-xm4"),
                at("d-nam", OrderJump.FAILED),
                at("d-nam", OrderJump.CANCELLED),
                at("d-bao"),
            ),
        ).map { it.first.icon }
        assertThat(icons).containsExactly(
            Symbol.HourglassTop,
            Symbol.ReceiptLong,
            Symbol.LocalShipping,
            Symbol.ScheduleSend,
            Symbol.Check,
            Symbol.PackageTwo,
            Symbol.Undo,
            Symbol.Cancel,
            Symbol.Handshake,
        ).inOrder()
    }

    @Test
    fun actionsOpenTheirOrder() {
        val actions = read(listOf(at("d-huy"), at("d-han"), at("d-nam", OrderJump.PENDING), at("d-xm4"), at("d-nam", OrderJump.FAILED))).map { it.second }
        assertThat(actions[0]).isEqualTo(OrderAction(Symbol.ReceiptLong, "Tạo đơn", OrderRoute("d-huy", orderId = "d-huy-o1")))
        assertThat(actions[1]).isEqualTo(OrderAction(Symbol.ReceiptLong, "Xem đơn", OrderRoute("d-han", orderId = "d-han-o1")))
        assertThat(actions[2]).isEqualTo(OrderAction(Symbol.ReceiptLong, "Xem đơn", OrderRoute("d-nam", orderId = "d-nam-o1")))
        assertThat(actions[3]).isNull()
        assertThat(actions[4]).isEqualTo(OrderAction(Symbol.ReceiptLong, "Xem đơn", OrderRoute("d-nam", orderId = "d-nam-o1")))
    }

    @Test
    fun anOrderIsFoundByItsIdOrIsTheCurrentOne() {
        val bike = at("d-han")
        assertThat(bike.order("d-han-o1")).isEqualTo(bike.deal.currentOrder)
        assertThat(bike.order(null)).isEqualTo(bike.deal.currentOrder)
        assertThat(bike.order("d-han-o9")).isEqualTo(bike.deal.currentOrder)
        assertThat(at("d-nam").order(null)).isNull()
    }
```

In the three designsystem tests, change the phase labels the assertions read: `sed -i 's/Tạo đơn, gửi hàng/Tạo đơn/g; s/Xem và nhận/Nhận hàng/g' core/designsystem/src/test/kotlin/vn/shopnexus/core/designsystem/DealComponentsTest.kt core/designsystem/src/test/kotlin/vn/shopnexus/core/designsystem/StepIconsTest.kt core/designsystem/src/test/kotlin/vn/shopnexus/core/designsystem/OrderComponentsTest.kt`, then read the three diffs: each changed line must be a phase label.

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:ui:testDebugUnitTest :core:designsystem:testDebugUnitTest`
Expected: `:core:ui` does not compile (`orderLine(view, order, …)`, `DealView.order` unresolved); `:core:designsystem` fails on the labels.

- [ ] **Step 3: The route, the labels and the copy**

`Routes.kt`:

```kotlin
/**
 * One order; its screen depends on which side the person is. [orderId] picks one of the deal's orders (Đơn hàng's rows);
 * null shows the current one. [sent] marks the order opened by "Gửi yêu cầu COD", which says the request went out.
 */
@Serializable data class OrderRoute(val dealId: String, val sent: Boolean = false, val orderId: String? = null) : NavKey
```

`core/designsystem/src/main/res/values/strings.xml`: `phase_ship` → `Tạo đơn`, `phase_receive` → `Nhận hàng` (`phase_negotiate` and `phase_rate` stay).

Replace `core/ui/src/main/kotlin/vn/shopnexus/core/ui/deal/OrderCopy.kt` with:

```kotlin
package vn.shopnexus.core.ui.deal

import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import androidx.navigation3.runtime.NavKey
import java.time.Instant
import java.time.ZoneId
import vn.shopnexus.core.designsystem.icon.Symbol
import vn.shopnexus.core.domain.dayLabel
import vn.shopnexus.core.domain.roleOf
import vn.shopnexus.core.model.DealView
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Party
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.navigation.ListingRoute
import vn.shopnexus.core.navigation.MyListingsRoute
import vn.shopnexus.core.navigation.OrderRoute
import vn.shopnexus.core.ui.R

/** An order's one line of icon and short text, on Đơn hàng and in Chat's console. */
data class OrderLine(val icon: Symbol, val text: String)

/** An order's one link, its icon and where it goes. */
data class OrderAction(val icon: Symbol, val label: String, val route: NavKey)

private fun DealView.selling() = roleOf(deal, me.id) == Party.SELLER

/** The order [id] names, or the current one when [id] is null or names none of the deal's. */
fun DealView.order(id: String?): Order? = deal.orders.firstOrNull { it.id.value == id } ?: deal.currentOrder

/**
 * [order]'s line for this side. The buyer reads "Chờ người bán tạo đơn" while it is pending and "Chờ giao hàng" through
 * the whole of shipped, whatever the carrier reports; the seller follows the carrier.
 */
@Composable
fun orderLine(view: DealView, order: Order, now: Instant, zone: ZoneId): OrderLine {
    val person = view.counterpart.name
    val selling = view.selling()
    val rating = view.deal.rating
    fun day(at: Instant?) = at?.let { dayLabel(it, now, zone) }.orEmpty()
    return when (order.status) {
        OrderStatus.PENDING ->
            if (selling) {
                OrderLine(Symbol.ReceiptLong, stringResource(R.string.deal_ui_line_to_create, person))
            } else {
                OrderLine(Symbol.HourglassTop, stringResource(R.string.deal_ui_line_requested))
            }
        OrderStatus.SHIPPED -> if (selling) sellerShipping(order, person) else OrderLine(Symbol.LocalShipping, stringResource(R.string.deal_ui_line_shipping))
        OrderStatus.COMPLETED -> when {
            selling -> OrderLine(Symbol.Handshake, stringResource(R.string.deal_ui_line_reviewed_seller, person, day(order.closedAt)))
            rating != null -> OrderLine(Symbol.Star, stringResource(R.string.deal_ui_line_reviewed, rating, person))
            else -> OrderLine(Symbol.PackageTwo, stringResource(R.string.deal_ui_line_received_buyer, day(order.closedAt)))
        }
        OrderStatus.FAILED -> OrderLine(Symbol.Undo, stringResource(R.string.deal_ui_line_failed))
        OrderStatus.CANCELLED -> OrderLine(Symbol.Cancel, stringResource(R.string.deal_ui_line_cancelled))
    }
}

/** The seller's line while the parcel travels: waiting for the carrier's pickup, on its way, delivered. */
@Composable
private fun sellerShipping(order: Order, person: String): OrderLine = when (order.shipment?.status) {
    ShipmentStatus.IN_TRANSIT -> OrderLine(Symbol.LocalShipping, stringResource(R.string.deal_ui_line_shipping_seller, person))
    ShipmentStatus.DELIVERED -> OrderLine(Symbol.Check, stringResource(R.string.deal_ui_line_delivered_seller, person))
    else -> OrderLine(Symbol.ScheduleSend, stringResource(R.string.deal_ui_line_pickup, (order.shipment?.carrier ?: ShipCarrier.GHTK).label))
}

/** The order's link: "Tạo đơn" on a seller's pending order, "Xem đơn" on the rest, none on a completed one (its row shows the stars). */
@Composable
fun orderAction(view: DealView, order: Order): OrderAction? {
    val route = OrderRoute(view.deal.id.value, orderId = order.id.value)
    return when {
        order.status == OrderStatus.COMPLETED -> null
        order.status == OrderStatus.PENDING && view.selling() -> OrderAction(Symbol.ReceiptLong, stringResource(R.string.deal_ui_action_create), route)
        else -> OrderAction(Symbol.ReceiptLong, stringResource(R.string.deal_ui_action_view), route)
    }
}

/** A pool listing opens Listing detail; one of the person's own listings opens Tin của bạn. */
fun itemRoute(view: DealView): NavKey = if (view.selling()) MyListingsRoute() else ListingRoute(view.deal.listingId.value)
```

`core/ui/src/main/res/values/strings.xml`: set `deal_ui_line_requested` to `Chờ người bán tạo đơn`, `deal_ui_line_shipping` to `Chờ giao hàng`, `deal_ui_line_received_buyer` to `Đã nhận hàng · %1$s`; add after `deal_ui_line_shipping_seller`:

```xml
    <string name="deal_ui_line_pickup">Chờ %1$s lấy hàng</string>
    <string name="deal_ui_line_delivered_seller">Đã giao cho %1$s</string>
    <string name="deal_ui_line_failed">Giao không thành</string>
```

- [ ] **Step 4: Records go**

`git rm core/ui/src/main/kotlin/vn/shopnexus/core/ui/deal/RecordCard.kt core/ui/src/main/kotlin/vn/shopnexus/core/ui/deal/RecordSheet.kt core/ui/src/main/kotlin/vn/shopnexus/core/ui/deal/RecordDrafts.kt core/ui/src/main/kotlin/vn/shopnexus/core/ui/deal/Drafts.kt`. Then `python3 tmp/unused_strings.py core/ui/src/main/res/values/strings.xml` and delete every name it prints from `core/ui/src/main/res/values/strings.xml`; expected among them: the `deal_ui_record_*` strings, `deal_ui_line_placed`, `deal_ui_line_placed_self`, `deal_ui_line_to_ship`, `deal_ui_line_shipping_eta`, `deal_ui_line_at_door`, `deal_ui_line_received_seller`, `deal_ui_line_not_received_buyer`, `deal_ui_line_not_received_seller`, `deal_ui_line_refused_buyer`, `deal_ui_line_refused_seller`, `deal_ui_line_record_buyer`, `deal_ui_line_record_seller`, `deal_ui_line_refunded_buyer`, `deal_ui_line_refunded_seller`, `deal_ui_line_settled`, `deal_ui_line_declined_buyer`, `deal_ui_line_declined_seller`, `deal_ui_line_shipping_self_buyer`, `deal_ui_line_shipping_self_seller`, `deal_ui_action_ship`, `deal_ui_action_door`, `deal_ui_action_reply`, `deal_ui_action_received`. Run the script once more; expected: no output. Do the same for `core/designsystem/src/main/res/values/strings.xml`; expected: no output.

- [ ] **Step 5: Run the tests**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:navigation:test :core:designsystem:testDebugUnitTest :core:ui:testDebugUnitTest :core:ui:lintDebug`
Expected: BUILD SUCCESSFUL. (`:core:navigation` is a JVM or Android module; if `:core:navigation:test` is not a task, run `:core:navigation:testDebugUnitTest`.)

- [ ] **Step 6: Commit**

```bash
./gradlew :core:navigation:spotlessApply :core:designsystem:spotlessApply :core:ui:spotlessApply
git add core/navigation core/designsystem core/ui
git commit -m "feat(ui): order lines read the order and its shipment; the four steps are Tạo đơn and Nhận hàng; records go"
```

Then stop the daemons.

### Task 6: Chat and Tin nhắn on the new model

**Files:**
- Modify: `feature/deal/src/main/kotlin/vn/shopnexus/feature/deal/chat/ChatUiState.kt`, `ChatViewModel.kt`, `ChatScreen.kt`, `Console.kt`, `Composer.kt`, `Thread.kt`, `feature/deal/src/main/res/values/strings.xml`; `feature/inbox/src/main/kotlin/vn/shopnexus/feature/inbox/InboxScreen.kt`, `feature/inbox/src/main/res/values/strings.xml`
- Test: `feature/deal/src/test/kotlin/vn/shopnexus/feature/deal/chat/ChatScreenTest.kt`, `ChatSidesTest.kt`, `ChatViewModelTest.kt`, `SellerChatTest.kt`; `feature/inbox/src/test/kotlin/vn/shopnexus/feature/inbox/InboxScreenTest.kt`

**Interfaces:**
- Consumes: Task 2's `ConsoleState.OrderStep(order, price)`, `phaseOf(deal)`, `isOrder`; Task 3's `OrderJump`, `orderAt`; Task 5's `orderLine(view, order, now, zone)`, `orderAction(view, order)`.
- Produces: `ChatUiState` without `record`, `orderStatus` and `recordActive`; `ChatLocal` without `record`; `ChatEvent` without `OpenRecord`, `CloseRecord`, `RecordPhoto`, `RecordText`, `SendRecord`, `ConfirmRefund`; `ConsoleActions(onEvent, onNavigate, onRules)`; `ThreadActions` without `onConfirmRefund`.

- [ ] **Step 1: Write the failing tests**

`ChatScreenTest`:
- the helper `state(stage: DealStage = DealStage.NEGOTIATE, …)` becomes `state(status: DealStatus = DealStatus.NEGOTIATING, …)` with `val deal = edit(view.deal.copy(status = status))`; every `state(DealStage.ARRANGE, …)` becomes `state(DealStatus.AGREED, …)`; every `state(DealStage.DONE, edit = { agreed(it).copy(rating = 5) })` becomes `state(DealStatus.SOLD, edit = { agreed(it).copy(rating = 5, orders = Fixtures.deal("d-bao").deal.orders) })`; `orderAt(Fixtures.deal("d-nam"), OrderStatus.RECEIVED, now, VN_ZONE)` becomes `orderAt(Fixtures.deal("d-nam"), OrderJump.COMPLETED, now, VN_ZONE)`.
- delete `anOpenRecordHidesTheProblemButton`, `theAgreedMilestoneNamesTheNextStep`, `theRecordCannotBeSentWithoutAPhoto`, `aRefundIsConfirmedAfterAsking` and the test at the `RecordStatus.REFUNDED` record near line 534.
- `theAgreedMilestoneShrinksOnceTheDealMovesOn` becomes, with a new test after it:

```kotlin
    /** The price moment is one event line from the start, with no drawing and no next-step sentence. */
    @Test
    fun theAgreedMilestoneIsAnEventLine() {
        show(state(DealStatus.AGREED, edit = agreed))
        compose.onNodeWithText("Chốt 5,1 tr").assertExists()
        compose.onNodeWithText("Chọn giao COD hoặc hẹn xem máy.").assertDoesNotExist()
        compose.onNodeWithText("Chờ Tuấn Kiệt chọn COD.").assertDoesNotExist()
    }

    /** The hand-over is one event line that opens the order. */
    @Test
    fun theHandOverIsAnEventLineThatOpensTheOrder() {
        val received = orderAt(Fixtures.deal("d-nam"), OrderJump.COMPLETED, now, VN_ZONE)
        show(chatUiState(ChatContent.Ready(received), idle, ChatLocal(), typing = false, now))
        compose.onNodeWithText("Đã nhận iPhone X · trả 3.822.000 ₫").performScrollTo().performClick()
        assertThat(pushed).containsExactly(OrderRoute("d-nam"))
        compose.onNodeWithText("Đã trả 3.822.000 ₫ cho shipper").assertDoesNotExist()
    }
```

`ChatSidesTest`:
- `aRequestToCreateLeadsToTheOrder` expects `OrderRoute("d-huy", orderId = "d-huy-o1")`.
- `aParcelToSendLeadsToTheOrder`, `aRecordedOrderAsksForNoStars`, `anEndedDealLinksToItsOrder`, `aCancelledOrderLinksToItsOrder` are deleted.
- `aSentRequestWaitsForTheSeller` jumps `OrderJump.PENDING`, reads "Chờ người bán tạo đơn", and expects `OrderRoute("d-nam", orderId = "d-nam-o1")`.
- `theReceivedMilestoneSaysWhatArrived`, `theSellersReceivedMilestoneNamesTheBuyer` and `aTravellingParcelKeepsTheBuyerOnTheShipStep` become:

```kotlin
    /** The buyer's hand-over line says what arrived and what they paid the shipper, with no wish. */
    @Test
    fun theReceivedMilestoneSaysWhatArrived() {
        val xm4 = deal("d-xm4")
        show(xm4)
        val paid = checkNotNull(xm4.deal.agreedPrice) + checkNotNull(xm4.deal.currentOrder!!.shipment!!.fee)
        compose.onNodeWithText("Đã nhận Tai nghe chống ồn Sony WH-1000XM4 · trả ${paid.full()}").assertExists()
        compose.onNodeWithText("Chúc bạn", substring = true).assertDoesNotExist()
    }

    /** The seller's hand-over line names the buyer, with no slogan and no payout promise. */
    @Test
    fun theSellersReceivedMilestoneNamesTheBuyer() {
        val bao = deal("d-bao")
        show(bao.copy(deal = bao.deal.copy(rating = null)))
        compose.onNodeWithText("Gia Bảo đã nhận hàng").assertExists()
        compose.onNodeWithText("Tiền về tài khoản trong 1–2 ngày").assertDoesNotExist()
    }

    /** Once the seller has created the shipment the buyer is on "Nhận hàng" and reads "Chờ giao hàng", whatever the carrier says. */
    @Test
    fun aShippedOrderPutsTheBuyerOnNhanHang() {
        show(orderAt(deal("d-nam"), OrderJump.SHIPPED, now, VN_ZONE))
        compose.onNodeWithContentDescription("Bước 3/4 · Nhận hàng").assertExists()
        compose.onNodeWithText("Chờ giao hàng").assertExists()
    }

    /** A failed delivery: the thread says so, and the console talks price again with "Mua giá này". */
    @Test
    fun aFailedDeliveryTalksPriceAgain() {
        show(orderAt(deal("d-nam"), OrderJump.FAILED, now, VN_ZONE))
        compose.onNodeWithText("Giao không thành").assertExists()
        compose.onNodeWithText("Mua giá này").assertExists()
        compose.onNodeWithText("Xem đơn").assertDoesNotExist()
    }
```

- every other `orderAt(…, OrderStatus.X, …)` and `DealStage` use is ported by the Task 3 rules; every "Tạo đơn, gửi hàng" in an assertion becomes "Tạo đơn" and "Xem và nhận" becomes "Nhận hàng".

`ChatViewModelTest`: delete `theRecordIsRefundedAndConfirmed`; in `aRequestWaitsForTheSellerToCreateTheOrder` and `anAgreementAboveTheLineSuggestsMeetingAndGoesOnByCod`, read `deal.currentOrder` (status `PENDING`) for `deal.codRequest` and `ConsoleState.OrderStep` by its `order.status`. `SellerChatTest`: port by the Task 3 rules (`theSellersMilestoneWaitsForTheBuyer` asserts the event line "Chốt …" exists and "Chờ … chọn COD." does not).

`InboxScreenTest` (line 85): the row built with `InboxTag.AwaitingShipment` uses `InboxTag.AwaitingCreation`; delete the assertion on "Chờ gửi".

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :feature:deal:testDebugUnitTest :feature:inbox:testDebugUnitTest`
Expected: compilation fails in `:feature:deal` main (`ConsoleState.Ended`, `OrderStatus`, `RecordDraft` unresolved).

- [ ] **Step 2: The state and the view model**

`ChatUiState.kt`: drop the imports `OrderStatus`, `activeRecord`, `orderStatus`, `phaseFor`, `phaseOf` stays, `RecordDraft`; add `vn.shopnexus.core.domain.phaseOf` if it is not there. In `ChatUiState` delete `record`, `orderStatus` and `recordActive` (and their docs); in `ChatLocal` delete `record` and its mention in the doc (`/** What only this screen knows: a command in flight, the composer and the messages on their way. */`). In `chatUiState`: the early return is `ChatUiState(content = content, composer = local.composer, report = report)`; `phase = phaseOf(deal)`; delete the `record =`, `orderStatus =` and `recordActive =` lines.

`ChatViewModel.kt`: delete the six record and refund events from `ChatEvent`, the `records` field, their `onEvent` branches and the `RecordId`/`RecordDrafts` imports; the combine becomes

```kotlin
            combine(local, side, reports.state) { l, sd, rp -> Triple(l, sd, rp) },
```

- [ ] **Step 3: The screen, the console and the composer**

`ChatScreen.kt`: delete the `state.record?.let { RecordSheet(…) }` block and the `RecordSheet` import; the `ThreadActions(…)` call loses `onConfirmRefund = …`; `ConsoleActions(onEvent = onEvent, onNavigate = onNavigate, onRules = { rules = true })`.

`Console.kt`:
- `internal class ConsoleActions(val onEvent: (ChatEvent) -> Unit, val onNavigate: (NavKey) -> Unit = {}, val onRules: () -> Unit = {})`.
- `DealConsoleCard`'s comment over `if (console is ConsoleState.Done) return` becomes `// A finished deal has no card: the stars are an event line in the thread, and the hand-over line opens the order.`
- `figureOf` loses `is ConsoleState.Ended -> s.price`.
- in `ConsoleBody`, the `ConsoleState.Received` branch loses its `ProblemButton` line; the `OrderStep` branch becomes

```kotlin
        is ConsoleState.OrderStep -> {
            val line = orderLine(view, s.order, state.now, VN_ZONE)
            FigureRow(null, s.price, icon = Symbol.LocalShipping, order = true)
            IconLine(line.icon, line.text, Modifier.padding(top = 4.dp))
            orderAction(view, s.order)?.let { action ->
                ActionRow {
                    Button(onClick = { a.onNavigate(action.route) }, modifier = Modifier.weight(1f).heightIn(min = 48.dp)) {
                        SymbolIcon(action.icon, contentDescription = null, size = 20.dp)
                        Spacer(Modifier.width(8.dp))
                        Text(action.label, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
        }
```

  and the `ConsoleState.Ended` branch is deleted.
- delete `ProblemButton`; drop the imports `OrderStatus` and `OrderRoute` if nothing else in the file reads them.

`Composer.kt`: replace `quickReplies`, `buyerReplies` and `SHIPPING` with

```kotlin
/**
 * Replies that fit the side and the moment. A buyer asks to see the item first, for more photos, or about tonight while
 * the price is open; once agreed, where to meet; then asks for the order, for the parcel, and thanks at the end. A seller
 * answers, says the item is still there while the price is open, and promises the order while the buyer chooses COD or
 * waits for it.
 */
@Composable
internal fun quickReplies(mine: Party, noun: String, console: ConsoleState?): List<String> {
    val ok = stringResource(R.string.reply_ok)
    val thanks = stringResource(R.string.reply_thanks)
    if (mine != Party.SELLER) return buyerReplies(noun, console, ok, thanks)
    return when {
        console is ConsoleState.AwaitingCod || console.pending() -> listOf(ok, stringResource(R.string.reply_create_now), thanks)
        console is ConsoleState.Selling || console is ConsoleState.OfferIn || console is ConsoleState.Countering || console is ConsoleState.CounterOut ->
            listOf(ok, stringResource(R.string.reply_still_have), thanks)
        else -> listOf(ok, thanks)
    }
}

@Composable
private fun buyerReplies(noun: String, console: ConsoleState?, ok: String, thanks: String): List<String> = when {
    console is ConsoleState.Agreed -> listOf(stringResource(R.string.reply_where_meet), stringResource(R.string.reply_choose_cod), thanks)
    console.pending() -> listOf(stringResource(R.string.reply_please_create), ok, thanks)
    // Shipped: asking when it goes and for its code fits.
    console is ConsoleState.OrderStep -> listOf(stringResource(R.string.reply_when_ship), stringResource(R.string.reply_tracking), thanks)
    console == ConsoleState.Received || console is ConsoleState.Done ->
        listOf(stringResource(R.string.reply_got_it), stringResource(R.string.reply_all_good), thanks)
    else -> listOf(
        stringResource(R.string.reply_see_first, noun),
        stringResource(R.string.reply_more_photos),
        stringResource(R.string.reply_tonight),
    )
}

/** An order waiting for the seller to create its shipment. */
private fun ConsoleState?.pending(): Boolean = this is ConsoleState.OrderStep && order.status == OrderStatus.PENDING
```

with `import vn.shopnexus.core.model.OrderStatus` in place of the domain's.

- [ ] **Step 4: The thread**

`Thread.kt`:
- `ThreadActions` loses `onConfirmRefund` and the `RecordId` import; its `pending` doc becomes `/** A deal command is on its way. */` (drop `pending` if nothing reads it after this step).
- the `ThreadItem.Record` branch is deleted; the milestone branch becomes `is ThreadItem.Milestone -> MilestoneItem(item, view, mine, actions.onOrder)`.
- replace `MilestoneItem`, `agreedIsCurrent`, `handedIsCurrent`, `paid` and `ChatRecord` with

```kotlin
/**
 * A milestone is one event line, as any other step: the price agreed (the accepted amount, which a failed order's deal
 * no longer holds as its price), and the hand-over, which opens the order.
 */
@Composable
private fun MilestoneItem(item: ThreadItem.Milestone, view: DealView, mine: Party, onOrder: () -> Unit) {
    when (item.kind) {
        MilestoneKind.AGREED -> EventLine("handshake", stringResource(R.string.milestone_agreed, agreedAmount(view.deal, item).brief()))
        MilestoneKind.HANDED_OVER -> {
            val text = if (mine == Party.SELLER) {
                stringResource(R.string.milestone_handed_seller_title, view.counterpart.name)
            } else {
                stringResource(R.string.milestone_handed_event, shortTitle(view.listing.title), paid(view).full())
            }
            EventLine("package_2", text, onClick = onOrder.takeIf { isOrder(view.deal) })
        }
    }
}

/** The amount accepted at [milestone]: the last accepted price move at or before it, else the deal's price. */
private fun agreedAmount(deal: Deal, milestone: ThreadItem.Milestone): Vnd =
    deal.thread.lastOrNull { it is ThreadItem.PriceMove && it.accepted && it.at <= milestone.at }?.let { (it as ThreadItem.PriceMove).amount }
        ?: deal.agreedPrice ?: deal.listedPrice

/** What the buyer paid the shipper: the order's price and the carrier's fee, when the carrier gave one. */
private fun paid(view: DealView): Vnd {
    val order = view.deal.currentOrder ?: return view.deal.agreedPrice ?: view.deal.listedPrice
    return order.price + (order.shipment?.fee ?: Vnd.ZERO)
}
```

- drop the imports `Milestone` (designsystem), `Art` if nothing else in the file draws one, `activeRecord`, `DealStage`, `IncidentRecord`, `RecordId`, `RecordStatus`, `RecordCard`, `ShopNexusDialog` and `FilledTonalButton` if unused; the `animate` parameter of `MilestoneItem` is gone (keep `firstCount` only if another line still reads it).

- [ ] **Step 5: Tin nhắn**

`InboxScreen.kt`: delete the `InboxTag.AwaitingShipment -> …` branch. Run `python3 tmp/unused_strings.py feature/inbox/src/main/res/values/strings.xml` and delete what it prints (`inbox_to_ship`).

- [ ] **Step 6: Strings, then run the tests**

Run `python3 tmp/unused_strings.py feature/deal/src/main/res/values/strings.xml` and delete every name it prints (expected: `problem`, the `record_*` and `refund_confirm_*` strings, `milestone_agreed_line`, `milestone_agreed_seller`, `milestone_handed`, `milestone_handed_paid`, `milestone_handed_payout`, `reply_ship_today`); run it again and expect no output.

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :feature:deal:testDebugUnitTest :feature:inbox:testDebugUnitTest :feature:deal:lintDebug :feature:inbox:lintDebug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 7: Commit**

```bash
./gradlew :feature:deal:spotlessApply :feature:inbox:spotlessApply
git add feature/deal feature/inbox
git commit -m "feat(deal): Chat reads the deal's orders; milestones are event lines and records leave the thread"
```

Then stop the daemons.

### Task 7: Điểm uy tín, the tier sheet and the other readers

**Files:**
- Modify: `feature/me/src/main/kotlin/vn/shopnexus/feature/me/rep/ReputationScreen.kt`, `feature/me/src/main/res/values/strings.xml`; `feature/seller/src/main/kotlin/vn/shopnexus/feature/seller/profile/TierSheet.kt`, `feature/seller/src/main/res/values/strings.xml`
- Test: `feature/me/src/test/kotlin/vn/shopnexus/feature/me/rep/ReputationScreenTest.kt`; `feature/seller/src/test/kotlin/vn/shopnexus/feature/seller/profile/SellerScreenTest.kt`; `feature/discover/src/test/kotlin/vn/shopnexus/feature/discover/detail/ListingDetailViewModelTest.kt`; `feature/notifications/src/test/kotlin/vn/shopnexus/feature/notifications/list/NotificationsViewModelTest.kt`; any other test in `feature/me` that builds a `Figures90`

**Interfaces:**
- Consumes: Task 1's `Figures90(codFailed, codOrders)` and `SellerFacts` without records; Task 2's `dueOrder` (Tôi's due row keeps its shape); Task 3's notices (`delivered-<deal>`).
- Produces: nothing new.

- [ ] **Step 1: Write the failing tests**

`ReputationScreenTest.theRightsTheFiguresAndTheLadder`: `"Từ chối nhận COD"` becomes `"Giao không thành"`; add `compose.onNodeWithText("Ghi nhận bạn từ chối").assertDoesNotExist()` and `compose.onNodeWithText("Ghi nhận chưa trả lời").assertDoesNotExist()`. Wherever a test in `feature/me` builds `Figures90(…)`, it becomes `Figures90(codFailed = …, codOrders = …)`.

`SellerScreenTest` (line 144): the expected tier facts read `"0/9 đơn COD giao không thành"`, and `"1 ghi nhận sự cố · đã tự hoàn"` leaves the list; add `compose.onNodeWithText("ghi nhận sự cố", substring = true).assertDoesNotExist()` after the sheet opens.

`ListingDetailViewModelTest.anAgreedDealOpensTheChatInsteadOfANewOffer`: `stage = DealStage.ARRANGE` becomes `status = DealStatus.AGREED` (imports follow).

`NotificationsViewModelTest.theDoorNotificationOpensItsOrder` becomes

```kotlin
    /** The simulator posts "Đã giao …" when Hoàng Nam's parcel is delivered; it opens that order. */
    @Test
    fun theDeliveredNotificationOpensItsOrder() = runTest {
        val clock = SchedulerClock(testScheduler)
        val deals = FakeDealRepository(world, failures, FakeDealEngine(), clock, Simulator(world, clock, backgroundScope, VN_ZONE, Pace()))
        deals.send(DealId("d-nam"), DealCommand.RequestCod).getOrThrow()
        testScheduler.advanceTimeBy(10_100)
        runCurrent()
        val vm = viewModel()
        runCurrent()
        vm.navigation.test {
            vm.onEvent(NotificationsEvent.Open(vm.find("delivered-d-nam")))
            assertThat(awaitItem()).isEqualTo(OrderRoute("d-nam"))
        }
    }
```

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :feature:me:testDebugUnitTest :feature:seller:testDebugUnitTest :feature:discover:testDebugUnitTest :feature:notifications:testDebugUnitTest`
Expected: `:feature:me` and `:feature:seller` fail to compile (`codRefused`, `recordsDeclined`, `records` unresolved); the other two pass once their test files compile.

- [ ] **Step 2: The 90-day row and the tier facts**

`ReputationScreen.kt`, `Figures`: the rows become one row

```kotlin
    val rows = listOf(
        Triple(Symbol.Undo, R.string.me_rep_failed, stringResource(R.string.me_rep_cod_refused_value, f.codFailed, f.codOrders)),
    )
```

`feature/me/src/main/res/values/strings.xml`: rename `me_rep_cod_refused` to `me_rep_failed` with the value `Giao không thành`; delete `me_rep_declined` and `me_rep_unanswered`. If the screen's doc comment names records, it says "the 90-day figure" instead.

`TierSheet.kt`, `tierFacts`: the COD line reads `f.codFailed` (`stringResource(R.string.fact_cod, f.codFailed, f.codOrders)`) and the `Symbol.Report to when { … }` records entry is deleted. `feature/seller/src/main/res/values/strings.xml`: `fact_cod` becomes `%1$d/%2$d đơn COD giao không thành`; delete `fact_records_refunded`, `fact_records`, `fact_no_records`.

- [ ] **Step 3: Strings, then run the tests**

Run `python3 tmp/unused_strings.py feature/me/src/main/res/values/strings.xml` and `python3 tmp/unused_strings.py feature/seller/src/main/res/values/strings.xml`; expected: no output.

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :feature:me:testDebugUnitTest :feature:seller:testDebugUnitTest :feature:discover:testDebugUnitTest :feature:notifications:testDebugUnitTest :feature:me:lintDebug :feature:seller:lintDebug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**

```bash
./gradlew :feature:me:spotlessApply :feature:seller:spotlessApply :feature:discover:spotlessApply :feature:notifications:spotlessApply
git add feature/me feature/seller feature/discover feature/notifications
git commit -m "feat(me): the 90-day figure counts failed deliveries and the tier sheet drops records"
```

Then stop the daemons.

### Task 7b: COD rights follow the tier alone

The user ruled on 2026-11-12: a failed delivery is counted and shown, and takes nothing away. Today `rightsFor` lowers the COD cap at a 20 % refusal rate and blocks COD at 35 %. After this task the tier alone sets the caps.

**Files:**
- Modify: `core/domain/src/main/kotlin/vn/shopnexus/core/domain/Rights.kt` (whole file), `core/domain/src/main/kotlin/vn/shopnexus/core/domain/Orders.kt` (`codSlots`), `core/domain/src/main/kotlin/vn/shopnexus/core/domain/DealRules.kt` (`EngineContext.rights` default), `core/model/src/main/kotlin/vn/shopnexus/core/model/People.kt` (`MyReputation`), `core/model/src/main/kotlin/vn/shopnexus/core/model/Checkout.kt` (`CodCheckout`), `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/FakeDealRepository.kt`, `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/AccountFakes.kt`, `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/Seeds.kt` (`lastRefusalAt` goes), `feature/orders/src/main/kotlin/vn/shopnexus/feature/orders/checkout/CodCheckoutViewModel.kt`, and every other reader `grep -rn "codBlockedUntil\|lastRefusalAt\|Stats90\|MIN_ORDERS_FOR_SANCTIONS" core feature app` finds at the start of the task (fixture JSON included, except `account.json`'s `codRefused90`, which stays).
- Test: `core/domain/src/test/kotlin/vn/shopnexus/core/domain/RightsTest.kt` (whole file), `OrdersTest.kt` (the `codSlots` test), `core/model/src/test/kotlin/vn/shopnexus/core/model/DealJsonTest.kt`, `core/data/src/test/kotlin/vn/shopnexus/core/data/fake/FakeDealEngineTest.kt`, `FakeDealEngineStage3Test.kt`.

**Interfaces:**
- Consumes: Task 7's `Figures90(codFailed, codOrders)`.
- Produces: `fun rightsFor(tier: Tier): Rights`; `data class Rights(val codOpenCap: Int, val listingCap: Int)`; `fun codSlots(rights: Rights, openCod: Int): CodSlots`; `CodCheckout` and `MyReputation` without `codBlockedUntil`.

- [ ] **Step 1: Write the failing test**

Replace `core/domain/src/test/kotlin/vn/shopnexus/core/domain/RightsTest.kt` with:

```kotlin
package vn.shopnexus.core.domain

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import vn.shopnexus.core.model.Tier

class RightsTest {
    @Test
    fun tiersGrantCodOrdersAndListings() {
        assertThat(rightsFor(Tier.NEW)).isEqualTo(Rights(codOpenCap = 2, listingCap = 5))
        assertThat(rightsFor(Tier.TRUSTED)).isEqualTo(Rights(codOpenCap = 5, listingCap = 20))
        assertThat(rightsFor(Tier.REPUTABLE)).isEqualTo(Rights(codOpenCap = 10, listingCap = 20))
        assertThat(rightsFor(Tier.TOP)).isEqualTo(Rights(codOpenCap = 20, listingCap = 20))
    }

    @Test
    fun slotsFitUpToTheCap() {
        val rights = rightsFor(Tier.TRUSTED)
        assertThat(codSlots(rights, openCod = 4)).isEqualTo(CodSlots(after = 5, cap = 5, fits = true))
        assertThat(codSlots(rights, openCod = 5)).isEqualTo(CodSlots(after = 6, cap = 5, fits = false))
    }
}
```

In `OrdersTest.kt`, delete the test that builds `rights.copy(codBlockedUntil = …)` (Task 2 ported it as the blocked case of `codSlots`); the slot cases now live in `RightsTest`.

- [ ] **Step 2: Run it to verify it fails**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:domain:testDebugUnitTest --tests 'vn.shopnexus.core.domain.RightsTest'`
Expected: compilation FAILS: `rightsFor` takes three arguments, `Rights` takes three.

- [ ] **Step 3: Write the implementation**

Replace `core/domain/src/main/kotlin/vn/shopnexus/core/domain/Rights.kt` with:

```kotlin
package vn.shopnexus.core.domain

import vn.shopnexus.core.model.Tier

/** How many COD orders a person may have open as a buyer, and how many listings on sale. */
data class Rights(val codOpenCap: Int, val listingCap: Int)

private val COD_CAP = mapOf(Tier.NEW to 2, Tier.TRUSTED to 5, Tier.REPUTABLE to 10, Tier.TOP to 20)
private val LISTING_CAP = mapOf(Tier.NEW to 5, Tier.TRUSTED to 20, Tier.REPUTABLE to 20, Tier.TOP to 20)

/**
 * The tier's caps. Failed deliveries are counted on Điểm uy tín for sellers to read and lower nothing: COD inspection
 * lets a buyer refuse a parcel that is not as described, and a failure does not say why.
 */
fun rightsFor(tier: Tier): Rights = Rights(COD_CAP.getValue(tier), LISTING_CAP.getValue(tier))
```

In `Orders.kt`, `codSlots` loses `now` and the block:

```kotlin
fun codSlots(rights: Rights, openCod: Int): CodSlots {
    val after = openCod + 1
    return CodSlots(after, rights.codOpenCap, after <= rights.codOpenCap)
}
```

Then, at each reader the grep finds:
- `DealRules.kt`: `val rights: Rights = Rights(codOpenCap = 5, listingCap = 20),`.
- `People.kt`: delete `val codBlockedUntil: Moment?,` from `MyReputation`. `Checkout.kt`: delete it from `CodCheckout`.
- `FakeDealRepository.kt`: `internal fun AccountSeed.rights() = rightsFor(tierFor(score))`; in `checkout`, delete `codBlockedUntil = rights.codBlockedUntil,`; drop the `Stats90` import and the `now` argument at every `rights(now)` call.
- `AccountFakes.kt`: `internal fun WorldState.liveRights(now: Instant): Rights = account?.let { rightsFor(tierFor(liveScore(now))) } ?: Rights(0, 0)`, with its KDoc "The rights the live score's tier grants."; drop the `Stats90` import; delete `codBlockedUntil = …` where `MyReputation` is built.
- `Seeds.kt`: delete `val lastRefusalAt: Moment? = null,`, and the key from any fixture JSON that sets it.
- `CodCheckoutViewModel.kt`: `private fun CodCheckout.slots() = codSlots(Rights(codCap, 0), openCod)` and its callers drop `now`.
- Tests: `DealJsonTest.kt`'s `CodCheckout(…)` drops `codBlockedUntil = null`; `FakeDealEngineTest.kt` and `FakeDealEngineStage3Test.kt` build `Rights(codOpenCap = 5, listingCap = 20)`.

Finish with `grep -rn "codBlockedUntil\|lastRefusalAt\|Stats90\|MIN_ORDERS_FOR_SANCTIONS" core feature app`; expected: no output.

- [ ] **Step 4: Run the tests**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:model:testDebugUnitTest :core:domain:testDebugUnitTest :core:data:testDebugUnitTest :feature:orders:testDebugUnitTest :feature:me:testDebugUnitTest`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 5: Commit**

```bash
./gradlew :core:model:spotlessApply :core:domain:spotlessApply :core:data:spotlessApply :feature:orders:spotlessApply :feature:me:spotlessApply
git add core feature
git commit -m "feat(domain): COD rights follow the tier alone"
```

Then stop the daemons.

### Task 8: Đơn hàng, and the interim Đơn COD and Đơn bán

Everything in `cod/`, `ship/`, `OrderHero.kt` and `OrderParts.kt` this task writes is **interim**: it keeps today's layout pieces (hero, four-step timeline, carrier events, code row with "Tra mã", the item and the person, the money, the order number), drops what the spec deletes (the packing photo, the fee field, "Khác" and its typed name, the separate "Gửi hàng" step with its QR sheet and pickup windows, records, refunds, "Báo chưa nhận hàng"), and wires the new commands. Part 4's mockups replace the two pages' layouts in a later plan; their view models' events and states are what that plan builds on. Đơn hàng (`list/`) and the router are final.

**Files:**
- Modify: `feature/orders/src/main/kotlin/vn/shopnexus/feature/orders/OrderCancel.kt`, `OrderHero.kt` (whole file), `OrderParts.kt`, `list/OrdersViewModel.kt`, `list/OrdersScreen.kt`, `checkout/CodCheckoutViewModel.kt`, `cod/CodOrderViewModel.kt` (whole file), `cod/CodOrderScreen.kt` (whole file), `ship/ShipOrderViewModel.kt` (whole file), `ship/ShipOrderScreen.kt` (whole file), `feature/orders/src/main/res/values/strings.xml`
- Delete: `SellerParts.kt`, `ship/RefundSheet.kt`, `ship/ShippingCodeSheet.kt`
- Test: `cod/CodOrderViewModelTest.kt` and `ship/ShipOrderViewModelTest.kt` (whole files), `OrderArtTest.kt` (whole file); ported: `cod/CodOrderScreenTest.kt`, `ship/ShipOrderScreenTest.kt`, `list/OrdersViewModelTest.kt`, `list/OrdersScreenTest.kt`, `OrderRouterTest.kt`, `checkout/CodCheckoutViewModelTest.kt`, `checkout/CodCheckoutScreenTest.kt`

**Interfaces:**
- Consumes: Task 1's model; Task 2's `canCancel(deal)`, `canEditTrackingCode`, `phaseOf(order, rating)`, `orderRows`, `GHTK_SERVICES`, `waybillFee`; Task 3's `DealRepository.lookupShipment`, `OrderJump`, `orderAt`; Task 5's `OrderRoute.orderId`, `DealView.order(id)`, `orderLine`, `orderAction`.
- Produces (for the part 4 plan): `CodOrderUiState(content, order, current, canBuyAgain, pending, cancelling, confirming, now)`, `CodOrderEvent { AskCancel, KeepOrder, Cancel, AskReceived, CloseAsk, ConfirmReceived, Rate, BuyAgain, Retry }`, `CodOrderViewModel.navigation: Flow<NavKey>`; `ShipOrderUiState(content, order, current, pending, form, cancelling, now)`, `ShipmentForm`, `CodePreview { Empty, Reading, Found(parcel, codMismatch), NotFound, Failed }`, `ShipOrderEvent { Mode, Weight, Service, PickupAt, PickCarrier, TrackingCode, Create, EditCode, CloseEdit, SaveCode, AskCancel, KeepOrder, Cancel, Retry }`; `data class OrderItem(val view: DealView, val order: Order)`.

- [ ] **Step 1: Write the failing view-model tests**

Replace `feature/orders/src/test/kotlin/vn/shopnexus/feature/orders/cod/CodOrderViewModelTest.kt` with:

```kotlin
package vn.shopnexus.feature.orders.cod

import androidx.lifecycle.SavedStateHandle
import app.cash.turbine.test
import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Rule
import org.junit.Test
import vn.shopnexus.core.data.DealRepository
import vn.shopnexus.core.data.fake.CounterpartListener
import vn.shopnexus.core.data.fake.FailurePolicy
import vn.shopnexus.core.data.fake.FakeDealEngine
import vn.shopnexus.core.data.fake.FakeDealRepository
import vn.shopnexus.core.data.fake.FakeWorld
import vn.shopnexus.core.data.fake.Fixtures
import vn.shopnexus.core.data.fake.OrderJump
import vn.shopnexus.core.data.fake.Pace
import vn.shopnexus.core.data.fake.Simulator
import vn.shopnexus.core.data.fake.orderAt
import vn.shopnexus.core.designsystem.component.UiMessage
import vn.shopnexus.core.domain.VN_ZONE
import vn.shopnexus.core.model.DealCommand
import vn.shopnexus.core.model.DealId
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.OrderId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.navigation.CodCheckoutRoute
import vn.shopnexus.core.navigation.OrderRoute
import vn.shopnexus.core.testing.MainDispatcherRule
import vn.shopnexus.core.testing.SchedulerClock
import vn.shopnexus.feature.orders.R

@OptIn(ExperimentalCoroutinesApi::class)
class CodOrderViewModelTest {
    @get:Rule val main = MainDispatcherRule()
    private val world = FakeWorld()
    private val failures = FailurePolicy(latencyMillis = 0)
    private val saved = SavedStateHandle()
    private val nam = DealId("d-nam")
    private val sent = mutableListOf<DealCommand>()

    private fun TestScope.repository(simulated: Boolean = false): DealRepository {
        val clock = SchedulerClock(testScheduler)
        val listener: CounterpartListener = if (simulated) Simulator(world, clock, backgroundScope, VN_ZONE, Pace()) else CounterpartListener { _, _ -> }
        val fake = FakeDealRepository(world, failures, FakeDealEngine(), clock, listener)
        return object : DealRepository by fake {
            override suspend fun send(id: DealId, command: DealCommand) = fake.send(id, command).also { sent += command }
        }
    }

    private fun TestScope.viewModel(deals: DealRepository = repository(), handle: SavedStateHandle = saved, orderId: String? = null): CodOrderViewModel {
        val clock = SchedulerClock(testScheduler)
        return CodOrderViewModel(OrderRoute(nam.value, orderId = orderId), deals, clock, handle).also { vm -> backgroundScope.launch { vm.state.collect {} } }
    }

    private fun jump(to: OrderJump) = world.update { s -> s.copy(deals = s.deals + (nam to orderAt(Fixtures.deal(nam.value), to, Fixtures.NOW, VN_ZONE))) }

    private fun deal() = world.value.deals.getValue(nam).deal

    private fun SavedStateHandle.copy() = SavedStateHandle(keys().associateWith { get<Any>(it) })

    /** Hoàng Nam ships 3 s after the request; the open page says so. */
    @Test
    fun theSellersShipmentArrivesWhileOpen() = runTest {
        val deals = repository(simulated = true)
        deals.send(nam, DealCommand.RequestCod).getOrThrow()
        val vm = viewModel(deals)
        runCurrent()
        assertThat(vm.state.value.order!!.status).isEqualTo(OrderStatus.PENDING)
        vm.messages.test {
            testScheduler.advanceTimeBy(3_100)
            runCurrent()
            assertThat(awaitItem()).isEqualTo(UiMessage(R.string.orders_shipped_via, listOf("Hoàng Nam", "GHTK")))
        }
        assertThat(vm.state.value.order!!.status).isEqualTo(OrderStatus.SHIPPED)
    }

    @Test
    fun cancellingAPendingOrderEndsItAndTheDealTalksPriceAgain() = runTest {
        val deals = repository()
        deals.send(nam, DealCommand.RequestCod).getOrThrow()
        val vm = viewModel(deals)
        runCurrent()
        vm.onEvent(CodOrderEvent.AskCancel)
        assertThat(vm.state.value.cancelling).isTrue()
        vm.onEvent(CodOrderEvent.Cancel)
        runCurrent()
        assertThat(sent).containsExactly(DealCommand.RequestCod, DealCommand.CancelOrder).inOrder()
        assertThat(vm.state.value.order!!.status).isEqualTo(OrderStatus.CANCELLED)
        assertThat(vm.state.value.cancelling).isFalse()
        assertThat(deal().status).isEqualTo(DealStatus.NEGOTIATING)
    }

    @Test
    fun theCancelDialogSurvivesRecreation() = runTest {
        jump(OrderJump.PENDING)
        val first = viewModel()
        runCurrent()
        first.onEvent(CodOrderEvent.AskCancel)
        val second = viewModel(handle = saved.copy())
        runCurrent()
        assertThat(second.state.value.cancelling).isTrue()
    }

    /** The seller ships while the dialog is open: "Hủy đơn" says it is too late instead of failing. */
    @Test
    fun aCancelAfterTheShipmentIsRefused() = runTest {
        jump(OrderJump.PENDING)
        val vm = viewModel()
        runCurrent()
        vm.onEvent(CodOrderEvent.AskCancel)
        jump(OrderJump.SHIPPED)
        runCurrent()
        vm.messages.test {
            vm.onEvent(CodOrderEvent.Cancel)
            runCurrent()
            assertThat(awaitItem()).isEqualTo(UiMessage(R.string.orders_cancel_created, listOf("Hoàng Nam")))
        }
        assertThat(sent).isEmpty()
    }

    @Test
    fun receiptIsConfirmedAfterTheDialogWhateverTheCarrierSays() = runTest {
        jump(OrderJump.SHIPPED)
        val vm = viewModel()
        runCurrent()
        vm.onEvent(CodOrderEvent.AskReceived)
        assertThat(vm.state.value.confirming).isTrue()
        vm.onEvent(CodOrderEvent.ConfirmReceived)
        runCurrent()
        assertThat(sent).containsExactly(DealCommand.ConfirmReceived)
        assertThat(vm.state.value.order!!.status).isEqualTo(OrderStatus.COMPLETED)
        assertThat(vm.state.value.confirming).isFalse()
    }

    @Test
    fun aCompletedOrderIsRated() = runTest {
        jump(OrderJump.COMPLETED)
        val vm = viewModel()
        runCurrent()
        vm.onEvent(CodOrderEvent.Rate(5))
        runCurrent()
        assertThat(sent).containsExactly(DealCommand.Rate(5))
        assertThat(deal().rating).isEqualTo(5)
    }

    /** "Mua lại" agrees at the listed price, as "Mua giá này" does, and opens Giao COD. */
    @Test
    fun aFailedOrderIsBoughtAgainThroughGiaoCod() = runTest {
        jump(OrderJump.FAILED)
        val vm = viewModel()
        runCurrent()
        assertThat(vm.state.value.canBuyAgain).isTrue()
        vm.navigation.test {
            vm.onEvent(CodOrderEvent.BuyAgain)
            runCurrent()
            assertThat(awaitItem()).isEqualTo(CodCheckoutRoute(nam.value))
        }
        assertThat(sent).containsExactly(DealCommand.AcceptCounter)
        assertThat(deal().status).isEqualTo(DealStatus.AGREED)
        assertThat(deal().agreedPrice).isEqualTo(deal().listedPrice)
        assertThat(vm.state.value.canBuyAgain).isFalse()
    }

    /** After "Mua lại" and a new request, the failed order's row opens it read-only, and the current order is the new one. */
    @Test
    fun anOlderOrderOpensWithNoAction() = runTest {
        jump(OrderJump.FAILED)
        val deals = repository()
        deals.send(nam, DealCommand.AcceptCounter).getOrThrow()
        deals.send(nam, DealCommand.RequestCod).getOrThrow()
        val older = viewModel(deals, orderId = "d-nam-o1")
        val newer = viewModel(deals, handle = SavedStateHandle())
        runCurrent()
        assertThat(older.state.value.order!!.status).isEqualTo(OrderStatus.FAILED)
        assertThat(older.state.value.current).isFalse()
        assertThat(older.state.value.canBuyAgain).isFalse()
        older.onEvent(CodOrderEvent.AskCancel)
        assertThat(older.state.value.cancelling).isFalse()
        assertThat(newer.state.value.order!!.id).isEqualTo(OrderId("d-nam-o2"))
        assertThat(newer.state.value.order!!.status).isEqualTo(OrderStatus.PENDING)
        assertThat(newer.state.value.current).isTrue()
    }
}
```

Replace `feature/orders/src/test/kotlin/vn/shopnexus/feature/orders/ship/ShipOrderViewModelTest.kt` with:

```kotlin
package vn.shopnexus.feature.orders.ship

import androidx.lifecycle.SavedStateHandle
import app.cash.turbine.test
import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Rule
import org.junit.Test
import vn.shopnexus.core.data.DealRepository
import vn.shopnexus.core.data.fake.FailurePolicy
import vn.shopnexus.core.data.fake.FakeCodSetupRepository
import vn.shopnexus.core.data.fake.FakeDealEngine
import vn.shopnexus.core.data.fake.FakeDealRepository
import vn.shopnexus.core.data.fake.FakeWorld
import vn.shopnexus.core.data.fake.Fixtures
import vn.shopnexus.core.data.fake.OrderJump
import vn.shopnexus.core.data.fake.Pace
import vn.shopnexus.core.data.fake.orderAt
import vn.shopnexus.core.designsystem.component.UiMessage
import vn.shopnexus.core.domain.VN_ZONE
import vn.shopnexus.core.model.CodSetup
import vn.shopnexus.core.model.DealCommand
import vn.shopnexus.core.model.DealId
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.NewShipment
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Parcel
import vn.shopnexus.core.model.Pickup
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.ShipmentMode
import vn.shopnexus.core.model.Vnd
import vn.shopnexus.core.navigation.OrderRoute
import vn.shopnexus.core.testing.MainDispatcherRule
import vn.shopnexus.core.testing.SchedulerClock
import vn.shopnexus.feature.orders.R

@OptIn(ExperimentalCoroutinesApi::class)
class ShipOrderViewModelTest {
    @get:Rule val main = MainDispatcherRule()
    private val world = FakeWorld()
    private val failures = FailurePolicy(latencyMillis = 0)
    private val saved = SavedStateHandle()
    private val huy = DealId("d-huy")
    private val sent = mutableListOf<DealCommand>()

    /** [slow] delays a code's lookup by its value in ms, as a carrier that answers out of order. */
    private fun TestScope.viewModel(
        handle: SavedStateHandle = saved,
        slow: Map<String, Long> = emptyMap(),
        linked: Boolean = true,
        orderId: String? = null,
    ): ShipOrderViewModel {
        val clock = SchedulerClock(testScheduler)
        val fake = FakeDealRepository(world, failures, FakeDealEngine(), clock) { _, _ -> }
        val deals = object : DealRepository by fake {
            override suspend fun send(id: DealId, command: DealCommand) = fake.send(id, command).also { sent += command }

            override suspend fun lookupShipment(id: DealId, carrier: ShipCarrier, code: String): Result<Parcel?> {
                delay(slow[code] ?: 0)
                return fake.lookupShipment(id, carrier, code)
            }
        }
        if (!linked) world.update { s -> s.copy(account = s.account?.copy(codSetup = CodSetup())) }
        val setup = FakeCodSetupRepository(world, failures, Pace())
        return ShipOrderViewModel(OrderRoute(huy.value, orderId = orderId), deals, setup, clock, handle).also { vm ->
            backgroundScope.launch { vm.state.collect {} }
        }
    }

    private fun SavedStateHandle.copy() = SavedStateHandle(keys().associateWith { get<Any>(it) })

    private fun ShipOrderViewModel.form() = state.value.form!!

    private fun TestScope.read() {
        advanceTimeBy(LOOKUP_DELAY_MILLIS + 50)
        runCurrent()
    }

    private fun ShipOrderViewModel.manual(carrier: ShipCarrier, code: String) {
        onEvent(ShipOrderEvent.Mode(ShipmentMode.MANUAL))
        onEvent(ShipOrderEvent.PickCarrier(carrier))
        onEvent(ShipOrderEvent.TrackingCode(code))
    }

    /** GHTK prices the shipment from the weight: Tiết kiệm for 2,5 kg is 16.000 ₫ and 4.000 ₫ for the started kilo past 2 kg. */
    @Test
    fun aLinkedShipmentSendsTheServiceWeightAndPickup() = runTest {
        val vm = viewModel()
        runCurrent()
        assertThat(vm.form().mode).isEqualTo(ShipmentMode.LINKED)
        assertThat(vm.form().account!!.code).isEqualTo("S55163")
        vm.onEvent(ShipOrderEvent.Weight("2,5"))
        vm.onEvent(ShipOrderEvent.Service("standard"))
        vm.onEvent(ShipOrderEvent.PickupAt(Pickup.POST_OFFICE))
        assertThat(vm.form().services.first { it.service.id == "standard" }.fee).isEqualTo(Vnd(20_000))
        vm.messages.test {
            vm.onEvent(ShipOrderEvent.Create)
            runCurrent()
            assertThat(awaitItem()).isEqualTo(UiMessage(R.string.orders_created_linked))
        }
        assertThat(sent).containsExactly(DealCommand.CreateShipment(NewShipment.Linked("standard", 2_500, Pickup.POST_OFFICE)))
        assertThat(vm.state.value.order!!.status).isEqualTo(OrderStatus.SHIPPED)
        assertThat(vm.state.value.form).isNull()
    }

    @Test
    fun withoutGhtkOnlyTheManualWayIsOffered() = runTest {
        val vm = viewModel(linked = false)
        runCurrent()
        assertThat(vm.form().mode).isEqualTo(ShipmentMode.MANUAL)
        assertThat(vm.form().account).isNull()
        vm.onEvent(ShipOrderEvent.Mode(ShipmentMode.LINKED))
        assertThat(vm.form().canSubmit).isFalse()
    }

    @Test
    fun aManualCodeIsConfirmedOnlyOnceTheCarrierKnowsIt() = runTest {
        val vm = viewModel()
        runCurrent()
        vm.manual(ShipCarrier.SPX, "NOTFOUND1")
        assertThat(vm.form().preview).isEqualTo(CodePreview.Reading)
        vm.read()
        assertThat(vm.form().preview).isEqualTo(CodePreview.NotFound)
        assertThat(vm.form().canSubmit).isFalse()
        vm.onEvent(ShipOrderEvent.Create)
        runCurrent()
        assertThat(sent).isEmpty()
        vm.onEvent(ShipOrderEvent.TrackingCode("SPXVN1"))
        vm.read()
        val found = vm.form().preview as CodePreview.Found
        assertThat(found.parcel.recipient).isEqualTo("Đ••• H•••")
        assertThat(found.codMismatch).isFalse()
        vm.messages.test {
            vm.onEvent(ShipOrderEvent.Create)
            runCurrent()
            assertThat(awaitItem()).isEqualTo(UiMessage(R.string.orders_told_code, listOf("Đức Huy")))
        }
        assertThat(sent).containsExactly(DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.SPX, "SPXVN1")))
    }

    @Test
    fun aDifferentCodWarnsAndDoesNotBlock() = runTest {
        val vm = viewModel()
        runCurrent()
        vm.manual(ShipCarrier.JT, "WRONGCOD1")
        vm.read()
        assertThat((vm.form().preview as CodePreview.Found).codMismatch).isTrue()
        assertThat(vm.form().canSubmit).isTrue()
    }

    /** The answer for an older code lands after the newer one's: it never replaces it, and "Xác nhận" sends the newer code. */
    @Test
    fun aLateLookupNeverReplacesTheNewerCode() = runTest {
        val vm = viewModel(slow = mapOf("NOTFOUND1" to 2_000L))
        runCurrent()
        vm.manual(ShipCarrier.SPX, "NOTFOUND1")
        vm.read()
        vm.onEvent(ShipOrderEvent.TrackingCode("SPXVN12"))
        vm.read()
        assertThat(vm.form().preview).isInstanceOf(CodePreview.Found::class.java)
        advanceTimeBy(3_000)
        runCurrent()
        assertThat(vm.form().trackingCode).isEqualTo("SPXVN12")
        assertThat(vm.form().preview).isInstanceOf(CodePreview.Found::class.java)
        vm.onEvent(ShipOrderEvent.Create)
        runCurrent()
        assertThat(sent).containsExactly(DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.SPX, "SPXVN12")))
    }

    @Test
    fun aManualCodeIsEditedWhileTheParcelTravels() = runTest {
        val vm = viewModel()
        runCurrent()
        vm.manual(ShipCarrier.SPX, "SPXVN1")
        vm.read()
        vm.onEvent(ShipOrderEvent.Create)
        runCurrent()
        assertThat(vm.state.value.form).isNull()
        vm.onEvent(ShipOrderEvent.EditCode)
        assertThat(vm.form().editing).isTrue()
        assertThat(vm.form().carrier).isEqualTo(ShipCarrier.SPX)
        assertThat(vm.form().trackingCode).isEqualTo("SPXVN1")
        vm.onEvent(ShipOrderEvent.TrackingCode("SPXVN2"))
        vm.read()
        vm.messages.test {
            vm.onEvent(ShipOrderEvent.SaveCode)
            runCurrent()
            assertThat(awaitItem()).isEqualTo(UiMessage(R.string.orders_code_edited))
        }
        assertThat(sent.last()).isEqualTo(DealCommand.EditTrackingCode(ShipCarrier.SPX, "SPXVN2"))
        assertThat(vm.state.value.form).isNull()
        assertThat(vm.state.value.order!!.shipment!!.trackingCode).isEqualTo("SPXVN2")
    }

    @Test
    fun aLinkedShipmentHasNoCodeToEdit() = runTest {
        world.update { s -> s.copy(deals = s.deals + (huy to orderAt(Fixtures.deal(huy.value), OrderJump.SHIPPED, Fixtures.NOW, VN_ZONE))) }
        val vm = viewModel()
        runCurrent()
        vm.onEvent(ShipOrderEvent.EditCode)
        assertThat(vm.state.value.form).isNull()
    }

    @Test
    fun cancellingThePendingOrderEndsIt() = runTest {
        val vm = viewModel()
        runCurrent()
        vm.onEvent(ShipOrderEvent.AskCancel)
        assertThat(vm.state.value.cancelling).isTrue()
        vm.onEvent(ShipOrderEvent.Cancel)
        runCurrent()
        assertThat(sent).containsExactly(DealCommand.CancelOrder)
        assertThat(world.value.deals.getValue(huy).deal.status).isEqualTo(DealStatus.NEGOTIATING)
    }

    @Test
    fun aCancelAfterTheShipmentIsRefused() = runTest {
        val vm = viewModel()
        runCurrent()
        vm.onEvent(ShipOrderEvent.AskCancel)
        world.update { s -> s.copy(deals = s.deals + (huy to orderAt(Fixtures.deal(huy.value), OrderJump.SHIPPED, Fixtures.NOW, VN_ZONE))) }
        runCurrent()
        vm.messages.test {
            vm.onEvent(ShipOrderEvent.Cancel)
            runCurrent()
            assertThat(awaitItem()).isEqualTo(UiMessage(R.string.orders_cancel_too_late))
        }
        assertThat(sent).isEmpty()
    }

    @Test
    fun theFormSurvivesRecreationAndComesBackFromItsDraft() = runTest {
        val first = viewModel()
        runCurrent()
        first.manual(ShipCarrier.JT, "JT9")
        val recreated = viewModel(handle = saved.copy())
        runCurrent()
        assertThat(recreated.form().mode).isEqualTo(ShipmentMode.MANUAL)
        assertThat(recreated.form().carrier).isEqualTo(ShipCarrier.JT)
        assertThat(recreated.form().trackingCode).isEqualTo("JT9")
        // A trip to Chat pops the page; the draft kept with the order brings the form back.
        val fresh = viewModel(handle = SavedStateHandle())
        runCurrent()
        assertThat(fresh.form().trackingCode).isEqualTo("JT9")
    }

    @Test
    fun aCancelledOrderOpensWithNoForm() = runTest {
        val vm0 = viewModel()
        runCurrent()
        vm0.onEvent(ShipOrderEvent.AskCancel)
        vm0.onEvent(ShipOrderEvent.Cancel)
        runCurrent()
        val older = viewModel(handle = SavedStateHandle(), orderId = "d-huy-o1")
        runCurrent()
        assertThat(older.state.value.order!!.status).isEqualTo(OrderStatus.CANCELLED)
        assertThat(older.state.value.form).isNull()
    }
}
```

Replace `feature/orders/src/test/kotlin/vn/shopnexus/feature/orders/OrderArtTest.kt` with:

```kotlin
package vn.shopnexus.feature.orders

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import vn.shopnexus.core.data.fake.Fixtures
import vn.shopnexus.core.designsystem.component.Art
import vn.shopnexus.core.model.OrderStatus

class OrderArtTest {
    private fun order(status: OrderStatus) = Fixtures.deal("d-han").deal.currentOrder!!.copy(status = status)

    @Test
    fun eachOrderStateHasItsDrawing() {
        assertThat(orderArt(order(OrderStatus.PENDING), selling = false)).isEqualTo(Art.Orders)
        assertThat(orderArt(order(OrderStatus.SHIPPED), selling = false)).isEqualTo(Art.CodPlaced)
        assertThat(orderArt(order(OrderStatus.COMPLETED), selling = true)).isEqualTo(Art.Received)
        assertThat(orderArt(order(OrderStatus.COMPLETED), selling = false)).isEqualTo(Art.Received)
        assertThat(orderArt(order(OrderStatus.FAILED), selling = false)).isEqualTo(Art.Offline)
        assertThat(orderArt(order(OrderStatus.CANCELLED), selling = true)).isEqualTo(Art.Offline)
    }
}
```

In `list/OrdersViewModelTest.kt`: `aWaitingRequestNeverLapses` reads `.order.status` (`OrderStatus.PENDING`) in place of `.status` (`TO_CREATE`), and its 49 hours stay; `ratingFinishesTheOrder` asserts `deal.rating`; `ids()` stays (`rows.map { it.view.deal.id.value }`). Add:

```kotlin
    @Test
    fun aFailedThenReboughtDealShowsTwoRows() = runTest {
        val nam = DealId("d-nam")
        world.update { s ->
            val failed = orderAt(s.deals.getValue(nam), OrderJump.FAILED, Fixtures.NOW, VN_ZONE)
            val again = failed.deal.currentOrder!!.copy(
                id = OrderId("d-nam-o2"), status = OrderStatus.PENDING, shipment = null, shippedAt = null, closedAt = null, requestedAt = Fixtures.NOW,
            )
            val rebought = failed.deal.copy(status = DealStatus.AGREED, agreedPrice = failed.deal.listedPrice, orders = failed.deal.orders + again)
            s.copy(deals = s.deals + (nam to failed.copy(deal = rebought)))
        }
        val vm = viewModel()
        runCurrent()
        val rows = (vm.state.value.content as OrdersContent.Ready).rows.filter { it.view.deal.id == nam }
        assertThat(rows.map { it.order.id.value }).containsExactly("d-nam-o2", "d-nam-o1").inOrder()
        assertThat(rows.map { it.order.status }).containsExactly(OrderStatus.PENDING, OrderStatus.FAILED).inOrder()
        assertThat(vm.state.value.buyCount).isEqualTo(4)
    }
```

(`buyCount` counts rows: d-han, d-xm4 and d-nam's two. Imports: `OrderJump`, `orderAt`, `Fixtures`, `VN_ZONE`, `DealId`, `DealStatus`, `OrderId`, `OrderStatus`.)

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :feature:orders:testDebugUnitTest`
Expected: compilation fails (main code against the old model; `CodePreview`, `ShipmentForm`, `orders_shipped_via` unresolved).

- [ ] **Step 2: Shared parts**

`OrderCancel.kt`: imports drop `CodStatus`, add `vn.shopnexus.core.model.OrderStatus`; `!canCancel(view.deal, me)` becomes `!canCancel(view.deal)` and `!canCancel(latest, me)` becomes `!canCancel(latest)`; `DealCommand.CancelCod` becomes `DealCommand.CancelOrder`; the class doc's second sentence becomes "Either side may cancel while the seller has not created the shipment, whether the page saw the shipment before the tap or it landed first; either way the snackbar says why, not that sending failed."; `tooLate` becomes

```kotlin
/** Why "Hủy đơn" came too late: the seller shipped the order the buyer wanted to cancel, or the order is no longer pending. */
internal fun tooLate(deal: Deal, me: Party, seller: String): UiMessage = if (me == Party.BUYER && deal.currentOrder?.status == OrderStatus.SHIPPED) {
    UiMessage(R.string.orders_cancel_created, listOf(seller))
} else {
    UiMessage(R.string.orders_cancel_too_late)
}
```

Replace `OrderHero.kt` with:

```kotlin
package vn.shopnexus.feature.orders

import androidx.compose.foundation.layout.RowScope
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.graphics.shapes.RoundedPolygon
import vn.shopnexus.core.designsystem.component.Art
import vn.shopnexus.core.designsystem.component.BarButton
import vn.shopnexus.core.designsystem.component.MilestoneTone
import vn.shopnexus.core.designsystem.component.StatusHero
import vn.shopnexus.core.designsystem.icon.Symbol
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderStatus

/** One row of an order page's status table: the shape, fill and icon, the title, the facts and the feeling line. */
internal class Hero(
    val shape: RoundedPolygon,
    val tone: MilestoneTone,
    val icon: Symbol,
    val title: String,
    val facts: List<Pair<Symbol, String>>,
    val feeling: String? = null,
)

@Composable
internal fun HeroBlock(hero: Hero, art: Art? = null) = StatusHero(hero.shape, hero.tone, hero.icon, hero.title, hero.facts, feeling = hero.feeling, art = art)

/**
 * The assistant's drawing for an order, the same on both sides until part 4 draws them: the order while it waits for its
 * shipment, the van on the way, the opened box, the sad one when it failed or was cancelled.
 */
@Suppress("UnusedParameter")
internal fun orderArt(order: Order, selling: Boolean): Art = when (order.status) {
    OrderStatus.PENDING -> Art.Orders
    OrderStatus.SHIPPED -> Art.CodPlaced
    OrderStatus.COMPLETED -> Art.Received
    OrderStatus.FAILED, OrderStatus.CANCELLED -> Art.Offline
}

/** A bar's main action: the core 48 dp [BarButton], filled; [busy] puts a spinner in the icon's place while its command runs. */
@Composable
internal fun RowScope.PrimaryAction(icon: Symbol, label: String, enabled: Boolean, busy: Boolean = false, onClick: () -> Unit) =
    BarButton(icon, label, onClick, Modifier.weight(1f), enabled = enabled, busy = busy)

/** A bar's quieter action: the same button, tonal. */
@Composable
internal fun RowScope.TonalAction(icon: Symbol, label: String, enabled: Boolean, busy: Boolean = false, onClick: () -> Unit) =
    BarButton(icon, label, onClick, Modifier.weight(1f), enabled = enabled, busy = busy, tonal = true)
```

`OrderParts.kt`: delete `agoLabel` and its two constants, and replace `cancelledBy` with the three parts both pages share:

```kotlin
/** Why the order was cancelled: "Bạn hủy", "Hoàng Nam hủy", or the system's reason. */
@Composable
internal fun cancelReason(view: DealView, order: Order): String = when (order.cancelReason) {
    CancelReason.SELLER_TIMEOUT -> stringResource(R.string.orders_reason_seller_timeout)
    CancelReason.PICKUP_TIMEOUT -> stringResource(R.string.orders_reason_pickup_timeout)
    CancelReason.SHIPPED_TO_ANOTHER -> stringResource(R.string.orders_reason_shipped_to_another)
    CancelReason.LISTING_CLOSED -> stringResource(R.string.orders_reason_listing_closed)
    CancelReason.BUYER, CancelReason.SELLER, null ->
        if (order.cancelledBy == roleOf(view.deal, view.me.id)) {
            stringResource(R.string.orders_cancelled_by_me)
        } else {
            stringResource(R.string.orders_cancelled_by, view.counterpart.name)
        }
}

/** The four steps for [order], each with its time once it happened: the request at the agreed price, the shipment, the receipt, the stars. */
@Composable
internal fun OrderTimeline(view: DealView, order: Order, now: Instant) {
    val completed = order.status == OrderStatus.COMPLETED
    fun at(t: Instant?) = t?.let { momentLabel(it, now, VN_ZONE) }
    val phases = listOf(
        TimelinePhase(stringResource(R.string.orders_phase_cod_agreed, order.price.full()), at(order.requestedAt), Symbol.Sell),
        TimelinePhase(stringResource(R.string.orders_phase_create), at(order.shippedAt), Symbol.LocalShipping),
        TimelinePhase(stringResource(R.string.orders_phase_receive), at(order.closedAt.takeIf { completed }), Symbol.PackageTwo),
        TimelinePhase(stringResource(R.string.orders_phase_rate), at(view.deal.ratedAt.takeIf { completed }), Symbol.Star),
    )
    Timeline(phases, phaseOf(order, view.deal.rating), Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
}

/** The shipment's carrier and code, to copy and follow on the carrier's site. */
@Composable
internal fun ShipmentCode(shipment: Shipment, onCopy: (String) -> Unit, modifier: Modifier = Modifier) {
    val carrier = shipment.carrier.label
    CodeLine(Symbol.ReceiptLong, stringResource(R.string.orders_waybill_code, carrier), shipment.trackingCode, onCopy, modifier, trackUrl = trackingUrl(carrier, shipment.trackingCode))
}
```

(imports: `vn.shopnexus.core.designsystem.component.Timeline`, `TimelinePhase`, `vn.shopnexus.core.domain.VN_ZONE`, `momentLabel`, `phaseOf`, `vn.shopnexus.core.model.CancelReason`, `Order`, `OrderStatus`, `Shipment`, `full`, `vn.shopnexus.core.ui.deal.trackingUrl`; `java.time.Duration` goes with `agoLabel`.)

`git rm feature/orders/src/main/kotlin/vn/shopnexus/feature/orders/SellerParts.kt feature/orders/src/main/kotlin/vn/shopnexus/feature/orders/ship/RefundSheet.kt feature/orders/src/main/kotlin/vn/shopnexus/feature/orders/ship/ShippingCodeSheet.kt`.

`checkout/CodCheckoutViewModel.kt`: `Deal.requested()` becomes

```kotlin
/** The buyer has an order pending or shipped on this deal; Giao COD then opens it instead of a second request. */
private fun Deal.requested() = openOrder != null
```

- [ ] **Step 3: Đơn hàng, one row per order**

`list/OrdersViewModel.kt`: imports drop `vn.shopnexus.core.domain.OrderStatus` and `orderStatus`, add `vn.shopnexus.core.model.Order`; then

```kotlin
/** A row of Đơn hàng: one order and its deal. A deal that failed and was bought again has two. */
data class OrderItem(val view: DealView, val order: Order)

/** The orders on [side], newest first, one row each. [now] is kept for callers; no row reads the time to exist. */
@Suppress("UnusedParameter")
internal fun orderItems(views: List<DealView>, side: Party, now: Instant): List<OrderItem> = orderRows(views, side).map { OrderItem(it.view, it.order) }
```

`list/OrdersScreen.kt`:
- imports drop `vn.shopnexus.core.domain.OrderStatus` and `phaseFor`, add `vn.shopnexus.core.domain.phaseOf`, `vn.shopnexus.core.model.Order`, `vn.shopnexus.core.model.OrderStatus`.
- the `items(…)` key is `it.order.id.value`, and the block call is `OrderBlock(row.view, row.order, state.now, state.rating[row.view.deal.id], onEvent, onNavigate, place)`.
- `OrderBlock`'s `status: OrderStatus` parameter becomes `order: Order`; inside it: `val open = OrderRoute(deal.id.value, orderId = order.id.value)`, `val price = order.price`, `PhaseStepper(phaseOf(order, deal.rating), Modifier.padding(top = 16.dp), small = true)`, `val line = orderLine(view, order, now, VN_ZONE)`, and the end becomes

```kotlin
        // The buyer rates a completed order in place; the seller's pending order carries "Tạo đơn". Every other row opens its page.
        val rates = !selling && order.status == OrderStatus.COMPLETED && deal.rating == null
        val action = orderAction(view, order).takeIf { selling && order.status == OrderStatus.PENDING }
```

  with the `when { rates -> …; action != null -> … }` below unchanged.
- delete `OrderStatus.waitsOnMe` and its doc.

- [ ] **Step 4: The interim Đơn COD**

Replace `cod/CodOrderViewModel.kt` with:

```kotlin
package vn.shopnexus.feature.orders.cod

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.navigation3.runtime.NavKey
import dagger.assisted.Assisted
import dagger.assisted.AssistedFactory
import dagger.assisted.AssistedInject
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.Clock
import java.time.Instant
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import vn.shopnexus.core.data.DealRepository
import vn.shopnexus.core.data.minutes
import vn.shopnexus.core.designsystem.component.UiMessage
import vn.shopnexus.core.model.DealCommand
import vn.shopnexus.core.model.DealId
import vn.shopnexus.core.model.DealStatus
import vn.shopnexus.core.model.DealView
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderId
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.navigation.CodCheckoutRoute
import vn.shopnexus.core.navigation.OrderRoute
import vn.shopnexus.core.ui.deal.DealDispatcher
import vn.shopnexus.core.ui.deal.order
import vn.shopnexus.feature.orders.OrderCanceller
import vn.shopnexus.feature.orders.R

sealed interface CodOrderContent {
    data object Loading : CodOrderContent
    data object Failed : CodOrderContent
    data object Missing : CodOrderContent
    data class Ready(val view: DealView) : CodOrderContent
}

/** Đơn COD, the buyer's order. The layout is interim; part 4's mockup redraws it on these fields. */
data class CodOrderUiState(
    val content: CodOrderContent = CodOrderContent.Loading,
    /** The order the page shows: the route's, or the deal's current one. */
    val order: Order? = null,
    /** [order] is the deal's current one; an older order only reads, with no action. */
    val current: Boolean = true,
    /** "Mua lại": the current order failed and the deal talks price again. */
    val canBuyAgain: Boolean = false,
    val pending: Boolean = false,
    /** "Hủy đơn?" is open. */
    val cancelling: Boolean = false,
    /** "Đã nhận hàng?" is open. */
    val confirming: Boolean = false,
    /** The timeline's moments read against this time. */
    val now: Instant = Instant.EPOCH,
)

/** What only this page knows: a command in flight and the two dialogs. */
data class CodOrderLocal(val pending: Boolean = false, val cancelAsked: Boolean = false, val confirmAsked: Boolean = false)

/** While pending the buyer can cancel; once shipped, they say it came (asked first); a failed order is bought again. */
sealed interface CodOrderEvent {
    data object AskCancel : CodOrderEvent
    data object KeepOrder : CodOrderEvent
    data object Cancel : CodOrderEvent
    data object AskReceived : CodOrderEvent
    data object CloseAsk : CodOrderEvent
    data object ConfirmReceived : CodOrderEvent
    data class Rate(val stars: Int) : CodOrderEvent
    data object BuyAgain : CodOrderEvent
    data object Retry : CodOrderEvent
}

/** Pure, so screenshot tests build every state from the fixtures without a ViewModel. */
internal fun codOrderUiState(content: CodOrderContent, local: CodOrderLocal, now: Instant, orderId: String? = null): CodOrderUiState {
    val view = (content as? CodOrderContent.Ready)?.view ?: return CodOrderUiState(content = content, now = now)
    val order = view.order(orderId)
    val current = order != null && order.id == view.deal.currentOrder?.id
    return CodOrderUiState(
        content = content,
        order = order,
        current = current,
        canBuyAgain = current && order?.status == OrderStatus.FAILED && view.deal.status == DealStatus.NEGOTIATING,
        pending = local.pending,
        // The cancel dialog may outlive the seller's shipment; "Hủy đơn" then says it is too late.
        cancelling = local.cancelAsked && current && order?.open == true,
        confirming = local.confirmAsked && current && order?.status == OrderStatus.SHIPPED,
        now = now,
    )
}

private const val CANCEL = "cancel.open"
private const val CONFIRM = "confirm.open"

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel(assistedFactory = CodOrderViewModel.Factory::class)
class CodOrderViewModel @AssistedInject constructor(
    @Assisted private val route: OrderRoute,
    private val deals: DealRepository,
    private val clock: Clock,
    private val saved: SavedStateHandle,
) : ViewModel() {
    @AssistedFactory
    interface Factory {
        fun create(route: OrderRoute): CodOrderViewModel
    }

    private val id = DealId(route.dealId)
    private val attempt = MutableStateFlow(0)
    private val local = MutableStateFlow(CodOrderLocal(cancelAsked = saved[CANCEL] ?: false, confirmAsked = saved[CONFIRM] ?: false))
    private val outbox = Channel<UiMessage>(Channel.BUFFERED)
    val messages: Flow<UiMessage> = outbox.receiveAsFlow()
    private val routes = Channel<NavKey>(Channel.BUFFERED)

    /** Where "Mua lại" goes once the price is agreed again: Giao COD. */
    val navigation: Flow<NavKey> = routes.receiveAsFlow()

    /** One command at a time; the bar's buttons stay disabled while [CodOrderLocal.pending] is set. */
    private val dispatch = DealDispatcher(viewModelScope, deals, id, outbox, { local.value.pending }) { c -> local.update { it.copy(pending = c != null) } }
    private val cancel = OrderCanceller(viewModelScope, deals, id, outbox, { local.value.pending }) { busy -> local.update { it.copy(pending = busy) } }

    private val content: StateFlow<CodOrderContent> = attempt.flatMapLatest {
        deals.deal(id)
            .map<DealView?, CodOrderContent> { it?.let(CodOrderContent::Ready) ?: CodOrderContent.Missing }
            .onStart { emit(CodOrderContent.Loading) }
            .catch { emit(CodOrderContent.Failed) }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, CodOrderContent.Loading)

    // The order last seen while the screen watched; the first one after a new subscription is not announced.
    private var seen: Pair<OrderId, OrderStatus>? = null

    val state: StateFlow<CodOrderUiState> = combine(content, local, clock.minutes()) { c, l, _ -> codOrderUiState(c, l, clock.instant(), route.orderId) }
        .onStart { seen = null }
        .onEach(::announce)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CodOrderUiState())

    /** The seller's shipment reaches an open page as a snackbar. */
    private suspend fun announce(state: CodOrderUiState) {
        val order = state.order ?: return
        val before = seen
        seen = order.id to order.status
        if (before == null || before.first != order.id || before.second == order.status) return
        val person = view()?.counterpart?.name ?: return
        val shipment = order.shipment
        if (before.second == OrderStatus.PENDING && order.status == OrderStatus.SHIPPED && shipment != null) {
            outbox.send(UiMessage(R.string.orders_shipped_via, listOf(person, shipment.carrier.label)))
        }
    }

    fun onEvent(event: CodOrderEvent) {
        when (event) {
            CodOrderEvent.AskCancel -> setCancel(true)
            CodOrderEvent.KeepOrder -> setCancel(false)
            CodOrderEvent.Cancel -> {
                setCancel(false)
                cancel(view())
            }
            CodOrderEvent.AskReceived -> setConfirm(true)
            CodOrderEvent.CloseAsk -> setConfirm(false)
            CodOrderEvent.ConfirmReceived -> {
                setConfirm(false)
                dispatch(DealCommand.ConfirmReceived)
            }
            is CodOrderEvent.Rate -> dispatch(DealCommand.Rate(event.stars))
            CodOrderEvent.BuyAgain ->
                if (state.value.canBuyAgain) dispatch(DealCommand.AcceptCounter, onSuccess = { routes.trySend(CodCheckoutRoute(id.value)) })
            CodOrderEvent.Retry -> attempt.update { it + 1 }
        }
    }

    private fun view(): DealView? = (content.value as? CodOrderContent.Ready)?.view

    private fun setConfirm(open: Boolean) {
        local.update { it.copy(confirmAsked = open) }
        saved[CONFIRM] = open
    }

    private fun setCancel(open: Boolean) {
        local.update { it.copy(cancelAsked = open) }
        saved[CANCEL] = open
    }
}
```

Replace `cod/CodOrderScreen.kt` with:

```kotlin
package vn.shopnexus.feature.orders.cod

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.MaterialShapes
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation3.runtime.NavKey
import java.time.Instant
import vn.shopnexus.core.designsystem.component.DockedActionBar
import vn.shopnexus.core.designsystem.component.ErrorState
import vn.shopnexus.core.designsystem.component.GroupItem
import vn.shopnexus.core.designsystem.component.GroupedList
import vn.shopnexus.core.designsystem.component.ListGhost
import vn.shopnexus.core.designsystem.component.MessageEffect
import vn.shopnexus.core.designsystem.component.MessageHost
import vn.shopnexus.core.designsystem.component.MilestoneTone
import vn.shopnexus.core.designsystem.component.MoneyNote
import vn.shopnexus.core.designsystem.component.PageLoad
import vn.shopnexus.core.designsystem.component.ShopNexusTopBar
import vn.shopnexus.core.designsystem.icon.Symbol
import vn.shopnexus.core.designsystem.theme.Corners
import vn.shopnexus.core.domain.MoneyStep
import vn.shopnexus.core.domain.SHIP_ESTIMATE
import vn.shopnexus.core.domain.VN_ZONE
import vn.shopnexus.core.domain.moneyNotes
import vn.shopnexus.core.model.DealView
import vn.shopnexus.core.model.DeliveryAddress
import vn.shopnexus.core.model.MoneyKey
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Vnd
import vn.shopnexus.core.model.digits
import vn.shopnexus.core.model.full
import vn.shopnexus.core.navigation.ChatRoute
import vn.shopnexus.core.navigation.Navigator
import vn.shopnexus.core.navigation.OrderRoute
import vn.shopnexus.core.navigation.SellerRoute
import vn.shopnexus.core.ui.deal.CarrierEvents
import vn.shopnexus.core.ui.deal.ClaimsRow
import vn.shopnexus.core.ui.deal.ClaimsSheet
import vn.shopnexus.core.ui.deal.ItemRow
import vn.shopnexus.core.ui.deal.PersonRow
import vn.shopnexus.core.ui.deal.RatingRow
import vn.shopnexus.core.ui.deal.itemNoun
import vn.shopnexus.core.ui.deal.itemRoute
import vn.shopnexus.core.ui.rememberCopy
import vn.shopnexus.feature.orders.AddressLine
import vn.shopnexus.feature.orders.CancelDialog
import vn.shopnexus.feature.orders.ConfirmDialog
import vn.shopnexus.feature.orders.Hero
import vn.shopnexus.feature.orders.HeroBlock
import vn.shopnexus.feature.orders.MoneyRow
import vn.shopnexus.feature.orders.OrderCodeRow
import vn.shopnexus.feature.orders.OrderMissing
import vn.shopnexus.feature.orders.OrderTimeline
import vn.shopnexus.feature.orders.PrimaryAction
import vn.shopnexus.feature.orders.R
import vn.shopnexus.feature.orders.ShipmentCode
import vn.shopnexus.feature.orders.TonalAction
import vn.shopnexus.feature.orders.cancelReason
import vn.shopnexus.feature.orders.clockLabel
import vn.shopnexus.feature.orders.decimal
import vn.shopnexus.feature.orders.fromOrder
import vn.shopnexus.feature.orders.orderArt

@Composable
internal fun CodOrderEntry(
    route: OrderRoute,
    navigator: Navigator,
    viewModel: CodOrderViewModel = hiltViewModel<CodOrderViewModel, CodOrderViewModel.Factory>(creationCallback = { it.create(route) }),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    MessageEffect(viewModel.messages, snackbar)
    LaunchedEffect(viewModel) { viewModel.navigation.collect { navigator.push(it) } }
    // Opened by "Gửi yêu cầu COD": one snackbar says it went out, once, even if the page comes back.
    var told by rememberSaveable { mutableStateOf(!route.sent) }
    val seller = (state.content as? CodOrderContent.Ready)?.view?.counterpart?.name
    val sent = seller?.let { stringResource(R.string.orders_sent_snack, it) }
    LaunchedEffect(sent) {
        if (!told && sent != null) {
            told = true
            snackbar.showSnackbar(sent)
        }
    }
    CodOrderScreen(state, viewModel::onEvent, navigator::fromOrder, navigator::back, snackbar)
}

/** Đơn COD, the buyer's order (interim): the hero, the door's notes, the four steps, the carrier, the item, the seller and the money. */
@Composable
fun CodOrderScreen(
    state: CodOrderUiState,
    onEvent: (CodOrderEvent) -> Unit,
    onNavigate: (NavKey) -> Unit,
    onBack: () -> Unit,
    snackbar: SnackbarHostState,
    modifier: Modifier = Modifier,
) {
    val scroll = rememberScrollState()
    var claims by rememberSaveable { mutableStateOf(false) }
    val copy = rememberCopy(snackbar)
    val view = (state.content as? CodOrderContent.Ready)?.view
    Scaffold(
        modifier = modifier,
        snackbarHost = { MessageHost(snackbar) },
        topBar = { ShopNexusTopBar(title = { Text(stringResource(R.string.orders_cod_title)) }, onBack = onBack) },
        bottomBar = { Bar(state, onEvent) },
    ) { padding ->
        PageLoad(state.content, loading = { it == CodOrderContent.Loading }, ghost = { ListGhost(Modifier.padding(padding)) }) { content ->
            when (content) {
                CodOrderContent.Loading -> Unit
                CodOrderContent.Failed -> ErrorState(stringResource(R.string.orders_failed), { onEvent(CodOrderEvent.Retry) }, Modifier.padding(padding))
                CodOrderContent.Missing -> OrderMissing(onBack, Modifier.padding(padding))
                is CodOrderContent.Ready -> Column(Modifier.padding(padding).fillMaxSize().verticalScroll(scroll).padding(bottom = 24.dp)) {
                    Body(content.view, state, onEvent, onNavigate, copy, onClaims = { claims = true })
                }
            }
        }
    }
    if (view == null) return
    val person = view.counterpart.name
    if (state.cancelling) CancelDialog(person, onCancel = { onEvent(CodOrderEvent.Cancel) }, onKeep = { onEvent(CodOrderEvent.KeepOrder) })
    if (claims) ClaimsSheet(person, view.claims, view.deal.tips, itemNoun(view.kind), onDismiss = { claims = false })
    if (state.confirming) {
        ConfirmDialog(
            stringResource(R.string.orders_received_title),
            stringResource(R.string.orders_received_text, person),
            stringResource(R.string.orders_received),
            { onEvent(CodOrderEvent.ConfirmReceived) },
            { onEvent(CodOrderEvent.CloseAsk) },
            Symbol.Check,
        )
    }
}

@Composable
private fun ColumnScope.Body(
    view: DealView,
    state: CodOrderUiState,
    onEvent: (CodOrderEvent) -> Unit,
    onNavigate: (NavKey) -> Unit,
    copy: (String) -> Unit,
    onClaims: () -> Unit,
) {
    val c = MaterialTheme.colorScheme
    val order = state.order ?: return
    val deal = view.deal
    val shipment = order.shipment
    val card = Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth().clip(Corners.ExtraLarge).background(c.surfaceContainer)
    HeroBlock(codHero(view, order, state.now), orderArt(order, selling = false))
    when (order.status) {
        // Until the seller creates the shipment the buyer can cancel; after it, what is left is refusing the parcel at the door.
        OrderStatus.PENDING -> MoneyNote(MoneyKey.CANCEL, card.padding(16.dp))
        OrderStatus.SHIPPED -> Column(card.padding(8.dp)) {
            ClaimsRow(view.claims, itemNoun(view.kind), onOpen = onClaims)
            Column(Modifier.padding(start = 8.dp, end = 8.dp, top = 4.dp, bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                moneyNotes(MoneyStep.COD_DOOR, order.price).forEach { MoneyNote(it) }
            }
        }
        OrderStatus.COMPLETED -> if (state.current) {
            RatingRow(
                view.counterpart.name,
                deal.rating,
                { onEvent(CodOrderEvent.Rate(it)) },
                Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = 8.dp),
                enabled = deal.rating == null,
                showLabel = false,
                busy = state.pending,
            )
        }
        OrderStatus.FAILED, OrderStatus.CANCELLED -> Unit
    }
    OrderTimeline(view, order, state.now)
    // What the carrier reports, while the parcel is on its way.
    shipment?.events?.takeIf { it.isNotEmpty() && order.status == OrderStatus.SHIPPED }?.let { CarrierEvents(it, state.now, VN_ZONE, card.padding(16.dp)) }
    if (shipment != null) ShipmentCode(shipment, copy, card.padding(vertical = 8.dp))
    DeliverTo(order.recipient, copy)
    val rated = view.counterpart.ratingCount > 0
    val seller = if (rated) {
        stringResource(R.string.orders_seller_detail, decimal(view.counterpart.rating), view.counterpart.sold)
    } else {
        stringResource(R.string.orders_seller_unrated, view.counterpart.sold)
    }
    // TalkBack says "sao" where the line shows the star.
    val sellerSpoken = if (rated) stringResource(R.string.orders_seller_detail_spoken, decimal(view.counterpart.rating), view.counterpart.sold) else null
    GroupedList(Modifier.padding(horizontal = 16.dp).padding(top = 16.dp)) {
        row("item") { GroupItem { ItemRow(view.listing, order.price, onClick = { onNavigate(itemRoute(view)) }) } }
        row("person") {
            GroupItem {
                PersonRow(
                    view.counterpart,
                    seller,
                    onChat = { onNavigate(ChatRoute(deal.id.value)) },
                    detailSpoken = sellerSpoken,
                    onOpen = { onNavigate(SellerRoute(view.counterpart.id.value)) },
                )
            }
        }
    }
    if (order.status != OrderStatus.CANCELLED) Money(order)
    OrderCodeRow(view, copy)
}

/** "Giao đến": the address and phone the order carries. */
@Composable
private fun DeliverTo(to: DeliveryAddress, copy: (String) -> Unit) {
    GroupedList(Modifier.padding(horizontal = 16.dp).padding(top = 16.dp), title = stringResource(R.string.orders_deliver_to)) {
        row("to") { GroupItem { AddressLine(to, copy) } }
    }
}

/** What the buyer paid the shipper, or will: the price and the carrier's fee once it said one. */
private fun paid(order: Order): Vnd = order.price + (order.shipment?.fee ?: Vnd.ZERO)

/**
 * "Tiền": before the shipment, the price plus shipping and the usual range of the fee; after it, what the shipper takes
 * and the carrier's fee, or that the carrier says it later.
 */
@Composable
private fun ColumnScope.Money(order: Order) {
    val shipment = order.shipment
    GroupedList(Modifier.padding(horizontal = 16.dp).padding(top = 24.dp), title = stringResource(R.string.orders_money)) {
        if (shipment == null) {
            row("goods") {
                GroupItem {
                    MoneyRow(
                        Symbol.Payments,
                        stringResource(R.string.orders_pay_on_receipt_amount, stringResource(R.string.orders_price_plus_shipping, order.price.full())),
                        stringResource(R.string.orders_pay_on_receipt_detail),
                        null,
                    )
                }
            }
            row("shipping") {
                GroupItem {
                    MoneyRow(
                        Symbol.LocalShipping,
                        stringResource(R.string.orders_shipping_estimate, stringResource(R.string.orders_fee_range, SHIP_ESTIMATE.low.digits(), SHIP_ESTIMATE.high.full())),
                        stringResource(R.string.orders_fee_estimate_detail),
                        null,
                    )
                }
            }
        } else {
            row("goods") {
                GroupItem {
                    MoneyRow(
                        Symbol.Payments,
                        stringResource(R.string.orders_pay_on_receipt_amount, paid(order).full()),
                        stringResource(R.string.orders_goods_to_shipper, order.price.full()),
                        null,
                    )
                }
            }
            row("shipping") {
                GroupItem {
                    val fee = shipment.fee?.let { stringResource(R.string.orders_includes_shipping, it.full()) } ?: stringResource(R.string.orders_fee_later)
                    MoneyRow(Symbol.LocalShipping, fee, shipment.carrier.label, null)
                }
            }
        }
    }
    Column(Modifier.padding(horizontal = 24.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        moneyNotes(MoneyStep.COD_MONEY, order.price).forEach { MoneyNote(it) }
    }
}

/** The buyer's five states, in the spec's words; the facts under them say what the order holds. */
@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
private fun codHero(view: DealView, order: Order, now: Instant): Hero {
    val code = order.shipment?.let { Symbol.ReceiptLong to "${it.carrier.label} · ${it.trackingCode}" }
    val rating = view.deal.rating
    return when (order.status) {
        OrderStatus.PENDING -> Hero(
            MaterialShapes.Cookie9Sided,
            MilestoneTone.TRUST,
            Symbol.HourglassTop,
            stringResource(R.string.orders_hero_wait_seller),
            listOf(Symbol.Schedule to stringResource(R.string.orders_hero_requested_at, clockLabel(order.requestedAt, now, VN_ZONE))),
        )
        OrderStatus.SHIPPED -> Hero(MaterialShapes.Cookie9Sided, MilestoneTone.TRUST, Symbol.LocalShipping, stringResource(R.string.orders_hero_wait_delivery), listOfNotNull(code))
        OrderStatus.COMPLETED -> if (rating != null) {
            Hero(
                MaterialShapes.Flower,
                MilestoneTone.CALM,
                Symbol.Star,
                stringResource(R.string.orders_hero_got_it),
                listOf(Symbol.Star to stringResource(R.string.orders_hero_rated, rating, view.counterpart.name)),
            )
        } else {
            Hero(
                MaterialShapes.SoftBurst,
                MilestoneTone.TRUST,
                Symbol.Check,
                stringResource(R.string.orders_hero_got_it),
                listOf(Symbol.Payments to stringResource(R.string.orders_hero_paid_shipper, paid(order).full())),
            )
        }
        OrderStatus.FAILED -> Hero(MaterialShapes.Gem, MilestoneTone.NEUTRAL, Symbol.Undo, stringResource(R.string.orders_hero_failed), listOfNotNull(code))
        OrderStatus.CANCELLED -> Hero(
            MaterialShapes.Circle,
            MilestoneTone.NEUTRAL,
            Symbol.Cancel,
            stringResource(R.string.orders_hero_cancelled),
            listOf(Symbol.Person to cancelReason(view, order)),
        )
    }
}

/** "Hủy đơn" while pending, "Đã nhận hàng" once shipped, "Mua lại" after a failure; nothing on an older order. */
@Composable
private fun Bar(state: CodOrderUiState, onEvent: (CodOrderEvent) -> Unit) {
    val order = state.order ?: return
    if (!state.current) return
    val busy = state.pending
    when {
        order.status == OrderStatus.PENDING -> DockedActionBar {
            TonalAction(Symbol.Cancel, stringResource(R.string.orders_cancel), !busy) { onEvent(CodOrderEvent.AskCancel) }
        }
        order.status == OrderStatus.SHIPPED -> DockedActionBar {
            PrimaryAction(Symbol.Check, stringResource(R.string.orders_received), enabled = true, busy = busy) { onEvent(CodOrderEvent.AskReceived) }
        }
        state.canBuyAgain -> DockedActionBar {
            PrimaryAction(Symbol.Replay, stringResource(R.string.orders_buy_again), enabled = true, busy = busy) { onEvent(CodOrderEvent.BuyAgain) }
        }
    }
}
```

- [ ] **Step 5: The interim Đơn bán**

Replace `ship/ShipOrderViewModel.kt` with:

```kotlin
package vn.shopnexus.feature.orders.ship

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.assisted.Assisted
import dagger.assisted.AssistedFactory
import dagger.assisted.AssistedInject
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.Clock
import java.time.Instant
import kotlin.math.roundToInt
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import vn.shopnexus.core.data.CodSetupRepository
import vn.shopnexus.core.data.DealRepository
import vn.shopnexus.core.data.minutes
import vn.shopnexus.core.designsystem.component.UiMessage
import vn.shopnexus.core.domain.GHTK_SERVICES
import vn.shopnexus.core.domain.MAX_WEIGHT_GRAMS
import vn.shopnexus.core.domain.TRACKING_CODE_MAX
import vn.shopnexus.core.domain.canEditTrackingCode
import vn.shopnexus.core.domain.waybillFee
import vn.shopnexus.core.model.Carrier
import vn.shopnexus.core.model.CarrierAccount
import vn.shopnexus.core.model.CarrierBrand
import vn.shopnexus.core.model.DealCommand
import vn.shopnexus.core.model.DealId
import vn.shopnexus.core.model.DealView
import vn.shopnexus.core.model.NewShipment
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderDraft
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Parcel
import vn.shopnexus.core.model.Pickup
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.ShipmentMode
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.Vnd
import vn.shopnexus.core.navigation.OrderRoute
import vn.shopnexus.core.ui.deal.DealDispatcher
import vn.shopnexus.core.ui.deal.order
import vn.shopnexus.feature.orders.OrderCanceller
import vn.shopnexus.feature.orders.R

sealed interface ShipOrderContent {
    data object Loading : ShipOrderContent
    data object Failed : ShipOrderContent
    data object Missing : ShipOrderContent
    data class Ready(val view: DealView) : ShipOrderContent
}

/** A GHTK service and the fee the carrier charges for the weight typed; the seller reads it and never types one. */
data class ServiceQuote(val service: Carrier, val fee: Vnd)

/** What the carrier says about the typed code. */
sealed interface CodePreview {
    data object Empty : CodePreview
    data object Reading : CodePreview

    /** Found; [codMismatch] when its COD amount is not the agreed price, which warns and does not block. */
    data class Found(val parcel: Parcel, val codMismatch: Boolean) : CodePreview
    data object NotFound : CodePreview
    data object Failed : CodePreview
}

/**
 * "Tạo đơn", one screen and one commit: the linked GHTK way with its service, weight and pickup, or the code of a
 * parcel sent on a carrier's own app with what the carrier says about it. [editing] is "Sửa mã" on a manual shipment.
 */
data class ShipmentForm(
    val editing: Boolean,
    /** The seller's linked GHTK account; null shows only the manual way and a line to link one. */
    val account: CarrierAccount?,
    val mode: ShipmentMode,
    val weight: String,
    val service: String,
    val services: List<ServiceQuote>,
    val pickup: Pickup,
    val carrier: ShipCarrier?,
    val trackingCode: String,
    val preview: CodePreview,
    val canSubmit: Boolean,
)

/** Đơn bán, the seller's order. The layout is interim; part 4's mockups redraw it on these fields. */
data class ShipOrderUiState(
    val content: ShipOrderContent = ShipOrderContent.Loading,
    val order: Order? = null,
    /** [order] is the deal's current one; an older order only reads. */
    val current: Boolean = true,
    val pending: Boolean = false,
    /** The form while the order waits for its shipment, or while a manual code is edited; null otherwise. */
    val form: ShipmentForm? = null,
    /** "Hủy đơn?" is open. */
    val cancelling: Boolean = false,
    val now: Instant = Instant.EPOCH,
)

/** What only this page knows: a command in flight, the form, the carrier's answer, and the open dialog. */
data class ShipOrderLocal(
    val pending: Boolean = false,
    val mode: ShipmentMode? = null,
    val weight: String = DEFAULT_WEIGHT,
    val service: String = DEFAULT_SERVICE,
    val pickup: Pickup = Pickup.HOME,
    val carrier: ShipCarrier? = null,
    val trackingCode: String = "",
    val preview: CodePreview = CodePreview.Empty,
    /** The carrier and code [preview] answers, so an answer for an older code is never shown for a newer one. */
    val previewFor: Pair<ShipCarrier, String>? = null,
    val editing: Boolean = false,
    val cancelAsked: Boolean = false,
) {
    /** What outlives the page: the form, kept with the order. */
    fun draft() = OrderDraft(mode, weight, service, pickup, carrier, trackingCode)
}

sealed interface ShipOrderEvent {
    data class Mode(val mode: ShipmentMode) : ShipOrderEvent
    data class Weight(val kg: String) : ShipOrderEvent
    data class Service(val id: String) : ShipOrderEvent
    data class PickupAt(val pickup: Pickup) : ShipOrderEvent
    data class PickCarrier(val carrier: ShipCarrier) : ShipOrderEvent
    data class TrackingCode(val code: String) : ShipOrderEvent
    data object Create : ShipOrderEvent
    data object EditCode : ShipOrderEvent
    data object CloseEdit : ShipOrderEvent
    data object SaveCode : ShipOrderEvent
    data object AskCancel : ShipOrderEvent
    data object KeepOrder : ShipOrderEvent
    data object Cancel : ShipOrderEvent
    data object Retry : ShipOrderEvent
}

private const val DEFAULT_WEIGHT = "2"
private const val DEFAULT_SERVICE = "express"
private const val GRAMS_PER_KG = 1_000

/** How long the page waits after the last keystroke before it asks the carrier about the code. */
internal const val LOOKUP_DELAY_MILLIS = 400L

/** "2", "2,5" or "2.5" kg in grams, from 1 g to 20 kg; null for anything else. */
internal fun gramsOf(kg: String): Int? =
    kg.trim().replace(',', '.').toDoubleOrNull()?.let { (it * GRAMS_PER_KG).roundToInt() }?.takeIf { it in 1..MAX_WEIGHT_GRAMS }

private fun shipmentForm(local: ShipOrderLocal, account: CarrierAccount?, editing: Boolean): ShipmentForm {
    val ghtk = account?.takeIf { it.brand == CarrierBrand.GHTK }
    val mode = if (editing) ShipmentMode.MANUAL else local.mode ?: if (ghtk != null) ShipmentMode.LINKED else ShipmentMode.MANUAL
    val grams = gramsOf(local.weight)
    val services = GHTK_SERVICES.map { ServiceQuote(it, grams?.let { g -> waybillFee(it, g) } ?: it.fee) }
    val chosen = services.firstOrNull { it.service.id == local.service } ?: services.first()
    val typed = local.carrier?.let { it to local.trackingCode.trim() }
    val found = (local.preview as? CodePreview.Found)?.takeIf { local.previewFor == typed }
    return ShipmentForm(
        editing = editing,
        account = ghtk,
        mode = mode,
        weight = local.weight,
        service = chosen.service.id,
        services = services,
        pickup = local.pickup,
        carrier = local.carrier,
        trackingCode = local.trackingCode,
        preview = local.preview,
        canSubmit = when (mode) {
            ShipmentMode.LINKED -> ghtk != null && grams != null
            // A code the carrier does not know, or reports failed, cannot be confirmed; a different COD only warns.
            ShipmentMode.MANUAL -> found != null && found.parcel.status != ShipmentStatus.FAILED
        },
    )
}

/** Pure, so screenshot tests build every state from the fixtures without a ViewModel. */
internal fun shipOrderUiState(content: ShipOrderContent, local: ShipOrderLocal, now: Instant, account: CarrierAccount?, orderId: String? = null): ShipOrderUiState {
    val view = (content as? ShipOrderContent.Ready)?.view ?: return ShipOrderUiState(content = content, now = now)
    val order = view.order(orderId)
    val current = order != null && order.id == view.deal.currentOrder?.id
    val form = when {
        order == null || !current -> null
        order.status == OrderStatus.PENDING -> shipmentForm(local, account, editing = false)
        local.editing && canEditTrackingCode(order) -> shipmentForm(local, account, editing = true)
        else -> null
    }
    return ShipOrderUiState(
        content = content,
        order = order,
        current = current,
        pending = local.pending,
        form = form,
        // The dialog may outlive the shipment; "Hủy đơn" then says it is too late.
        cancelling = local.cancelAsked && current && order?.open == true,
        now = now,
    )
}

private const val MODE = "create.mode"
private const val WEIGHT = "create.weight"
private const val SERVICE = "create.service"
private const val PICKUP = "create.pickup"
private const val CARRIER = "create.carrier"
private const val TRACKING = "create.tracking"
private const val EDITING = "edit.open"
private const val CANCEL = "cancel.open"

@OptIn(ExperimentalCoroutinesApi::class)
@HiltViewModel(assistedFactory = ShipOrderViewModel.Factory::class)
class ShipOrderViewModel @AssistedInject constructor(
    @Assisted private val route: OrderRoute,
    private val deals: DealRepository,
    setup: CodSetupRepository,
    private val clock: Clock,
    private val saved: SavedStateHandle,
) : ViewModel() {
    @AssistedFactory
    interface Factory {
        fun create(route: OrderRoute): ShipOrderViewModel
    }

    private val id = DealId(route.dealId)
    private val attempt = MutableStateFlow(0)

    // The form comes back from the page's saved state, else from the order's draft: a trip to Chat pops the page.
    private val kept = deals.orderDraft(id) ?: OrderDraft()
    private val local = MutableStateFlow(
        ShipOrderLocal(
            mode = saved.get<String>(MODE)?.let(ShipmentMode::valueOf) ?: kept.mode,
            weight = saved[WEIGHT] ?: kept.weight ?: DEFAULT_WEIGHT,
            service = saved[SERVICE] ?: kept.service ?: DEFAULT_SERVICE,
            pickup = saved.get<String>(PICKUP)?.let(Pickup::valueOf) ?: kept.pickup ?: Pickup.HOME,
            carrier = saved.get<String>(CARRIER)?.let(ShipCarrier::valueOf) ?: kept.carrier,
            trackingCode = saved[TRACKING] ?: kept.trackingCode,
            editing = saved[EDITING] ?: false,
            cancelAsked = saved[CANCEL] ?: false,
        ),
    )

    /** The seller's linked carrier account; null while unknown or unlinked. */
    private val account: StateFlow<CarrierAccount?> = setup.setup().map { it.account }.catch { emit(null) }
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)
    private val outbox = Channel<UiMessage>(Channel.BUFFERED)
    val messages: Flow<UiMessage> = outbox.receiveAsFlow()

    /** One command at a time; the bar's buttons stay disabled while [ShipOrderLocal.pending] is set. */
    private val dispatch = DealDispatcher(viewModelScope, deals, id, outbox, { local.value.pending }) { c -> local.update { it.copy(pending = c != null) } }
    private val cancel = OrderCanceller(viewModelScope, deals, id, outbox, { local.value.pending }) { busy -> local.update { it.copy(pending = busy) } }

    private val content: StateFlow<ShipOrderContent> = attempt.flatMapLatest {
        deals.deal(id)
            .map<DealView?, ShipOrderContent> { it?.let(ShipOrderContent::Ready) ?: ShipOrderContent.Missing }
            .onStart { emit(ShipOrderContent.Loading) }
            .catch { emit(ShipOrderContent.Failed) }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, ShipOrderContent.Loading)

    val state: StateFlow<ShipOrderUiState> = combine(content, local, account, clock.minutes()) { c, l, a, _ ->
        shipOrderUiState(c, l, clock.instant(), a, route.orderId)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ShipOrderUiState())

    private var reading: Job? = null

    init {
        // A restored code is read again: the carrier may have moved it meanwhile.
        if (local.value.carrier != null && local.value.trackingCode.isNotBlank()) lookup()
    }

    fun onEvent(event: ShipOrderEvent) {
        when (event) {
            is ShipOrderEvent.Mode -> form(MODE, event.mode.name) { it.copy(mode = event.mode) }
            is ShipOrderEvent.Weight -> form(WEIGHT, event.kg) { it.copy(weight = event.kg) }
            is ShipOrderEvent.Service -> form(SERVICE, event.id) { it.copy(service = event.id) }
            is ShipOrderEvent.PickupAt -> form(PICKUP, event.pickup.name) { it.copy(pickup = event.pickup) }
            is ShipOrderEvent.PickCarrier -> {
                form(CARRIER, event.carrier.name) { it.copy(carrier = event.carrier) }
                lookup()
            }
            is ShipOrderEvent.TrackingCode -> {
                val code = event.code.take(TRACKING_CODE_MAX)
                form(TRACKING, code) { it.copy(trackingCode = code) }
                lookup()
            }
            ShipOrderEvent.Create -> create()
            ShipOrderEvent.EditCode -> editCode()
            ShipOrderEvent.CloseEdit -> setEditing(false)
            ShipOrderEvent.SaveCode -> saveCode()
            ShipOrderEvent.AskCancel -> setCancel(true)
            ShipOrderEvent.KeepOrder -> setCancel(false)
            ShipOrderEvent.Cancel -> {
                setCancel(false)
                cancel(view())
            }
            ShipOrderEvent.Retry -> attempt.update { it + 1 }
        }
    }

    private fun form(key: String, value: String, change: (ShipOrderLocal) -> ShipOrderLocal) {
        local.update(change)
        saved[key] = value
        deals.saveOrderDraft(id, local.value.draft())
    }

    /** Asks the carrier about the typed code once typing pauses; an answer for an older code is dropped. */
    private fun lookup() {
        reading?.cancel()
        val carrier = local.value.carrier
        val code = local.value.trackingCode.trim()
        if (carrier == null || code.isEmpty()) {
            local.update { it.copy(preview = CodePreview.Empty, previewFor = null) }
            return
        }
        val asked = carrier to code
        local.update { it.copy(preview = CodePreview.Reading, previewFor = asked) }
        reading = viewModelScope.launch {
            delay(LOOKUP_DELAY_MILLIS)
            val price = view()?.deal?.openOrder?.price
            val preview = deals.lookupShipment(id, carrier, code).fold(
                onSuccess = { parcel -> parcel?.let { CodePreview.Found(it, price != null && it.cod != price) } ?: CodePreview.NotFound },
                onFailure = { CodePreview.Failed },
            )
            local.update { if (it.previewFor == asked) it.copy(preview = preview) else it }
        }
    }

    /** "Tạo đơn" on the linked account, or "Xác nhận" for a code the carrier knows. */
    private fun create() {
        val form = state.value.form?.takeIf { it.canSubmit && !it.editing } ?: return
        val person = view()?.counterpart?.name ?: return
        when (form.mode) {
            ShipmentMode.LINKED -> {
                val grams = gramsOf(form.weight) ?: return
                dispatch(
                    DealCommand.CreateShipment(NewShipment.Linked(form.service, grams, form.pickup)),
                    success = UiMessage(R.string.orders_created_linked),
                    onSuccess = ::forget,
                )
            }
            ShipmentMode.MANUAL -> {
                val carrier = form.carrier ?: return
                dispatch(
                    DealCommand.CreateShipment(NewShipment.Manual(carrier, form.trackingCode.trim())),
                    success = UiMessage(R.string.orders_told_code, listOf(person)),
                    onSuccess = ::forget,
                )
            }
        }
    }

    /** The order has its shipment: the half-filled form is not kept any more. */
    private fun forget() = deals.saveOrderDraft(id, null)

    /** "Sửa mã": the form opens on the shipment's carrier and code, and reads them again. */
    private fun editCode() {
        val shipment = view()?.deal?.openOrder?.takeIf(::canEditTrackingCode)?.shipment ?: return
        local.update { it.copy(editing = true, carrier = shipment.carrier, trackingCode = shipment.trackingCode) }
        saved[EDITING] = true
        saved[CARRIER] = shipment.carrier.name
        saved[TRACKING] = shipment.trackingCode
        lookup()
    }

    private fun saveCode() {
        val form = state.value.form?.takeIf { it.canSubmit && it.editing } ?: return
        val carrier = form.carrier ?: return
        dispatch(
            DealCommand.EditTrackingCode(carrier, form.trackingCode.trim()),
            success = UiMessage(R.string.orders_code_edited),
            onSuccess = { setEditing(false) },
        )
    }

    private fun view(): DealView? = (content.value as? ShipOrderContent.Ready)?.view

    private fun setEditing(open: Boolean) {
        local.update { it.copy(editing = open) }
        saved[EDITING] = open
    }

    private fun setCancel(open: Boolean) {
        local.update { it.copy(cancelAsked = open) }
        saved[CANCEL] = open
    }
}
```

Replace `ship/ShipOrderScreen.kt` with:

```kotlin
package vn.shopnexus.feature.orders.ship

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.MaterialShapes
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation3.runtime.NavKey
import java.time.Instant
import vn.shopnexus.core.designsystem.R as DesignR
import vn.shopnexus.core.designsystem.component.DockedActionBar
import vn.shopnexus.core.designsystem.component.ErrorState
import vn.shopnexus.core.designsystem.component.FilledField
import vn.shopnexus.core.designsystem.component.FilterPill
import vn.shopnexus.core.designsystem.component.GroupItem
import vn.shopnexus.core.designsystem.component.GroupedList
import vn.shopnexus.core.designsystem.component.ListGhost
import vn.shopnexus.core.designsystem.component.MessageEffect
import vn.shopnexus.core.designsystem.component.MessageHost
import vn.shopnexus.core.designsystem.component.MilestoneTone
import vn.shopnexus.core.designsystem.component.MoneyNote
import vn.shopnexus.core.designsystem.component.PageLoad
import vn.shopnexus.core.designsystem.component.ShopNexusTopBar
import vn.shopnexus.core.designsystem.icon.Symbol
import vn.shopnexus.core.designsystem.icon.SymbolIcon
import vn.shopnexus.core.designsystem.theme.Corners
import vn.shopnexus.core.domain.MoneyStep
import vn.shopnexus.core.domain.VN_ZONE
import vn.shopnexus.core.domain.canEditTrackingCode
import vn.shopnexus.core.domain.moneyNotes
import vn.shopnexus.core.model.CodSetupOrigin
import vn.shopnexus.core.model.DealView
import vn.shopnexus.core.model.Order
import vn.shopnexus.core.model.OrderStatus
import vn.shopnexus.core.model.Pickup
import vn.shopnexus.core.model.ShipCarrier
import vn.shopnexus.core.model.ShipmentMode
import vn.shopnexus.core.model.ShipmentStatus
import vn.shopnexus.core.model.Vnd
import vn.shopnexus.core.model.full
import vn.shopnexus.core.navigation.ChatRoute
import vn.shopnexus.core.navigation.CodSetupRoute
import vn.shopnexus.core.navigation.Navigator
import vn.shopnexus.core.navigation.OrderRoute
import vn.shopnexus.core.ui.R as UiR
import vn.shopnexus.core.ui.deal.CarrierEvents
import vn.shopnexus.core.ui.deal.ItemRow
import vn.shopnexus.core.ui.deal.PersonRow
import vn.shopnexus.core.ui.deal.itemRoute
import vn.shopnexus.core.ui.rememberCopy
import vn.shopnexus.feature.orders.AddressLine
import vn.shopnexus.feature.orders.CancelDialog
import vn.shopnexus.feature.orders.Hero
import vn.shopnexus.feature.orders.HeroBlock
import vn.shopnexus.feature.orders.MoneyRow
import vn.shopnexus.feature.orders.OrderCodeRow
import vn.shopnexus.feature.orders.OrderMissing
import vn.shopnexus.feature.orders.PrimaryAction
import vn.shopnexus.feature.orders.R
import vn.shopnexus.feature.orders.ShipmentCode
import vn.shopnexus.feature.orders.TonalAction
import vn.shopnexus.feature.orders.cancelReason
import vn.shopnexus.feature.orders.clockLabel
import vn.shopnexus.feature.orders.fromOrder
import vn.shopnexus.feature.orders.orderArt

@Composable
internal fun ShipOrderEntry(
    route: OrderRoute,
    navigator: Navigator,
    viewModel: ShipOrderViewModel = hiltViewModel<ShipOrderViewModel, ShipOrderViewModel.Factory>(creationCallback = { it.create(route) }),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    MessageEffect(viewModel.messages, snackbar)
    ShipOrderScreen(state, viewModel::onEvent, navigator::fromOrder, navigator::back, snackbar)
}

/** Đơn bán, the seller's order (interim): the hero, "Tạo đơn" while it waits, the carrier, the item, the buyer, the money and the codes. */
@Composable
fun ShipOrderScreen(
    state: ShipOrderUiState,
    onEvent: (ShipOrderEvent) -> Unit,
    onNavigate: (NavKey) -> Unit,
    onBack: () -> Unit,
    snackbar: SnackbarHostState,
    modifier: Modifier = Modifier,
) {
    val copy = rememberCopy(snackbar)
    val view = (state.content as? ShipOrderContent.Ready)?.view
    Scaffold(
        modifier = modifier,
        snackbarHost = { MessageHost(snackbar) },
        topBar = {
            ShopNexusTopBar(title = { Text(stringResource(R.string.orders_ship_title)) }, onBack = onBack, actions = {
                // "Hủy đơn" while the order waits for its shipment, as the mockup's top bar has it.
                if (state.current && state.order?.status == OrderStatus.PENDING) {
                    TextButton(onClick = { onEvent(ShipOrderEvent.AskCancel) }) { Text(stringResource(R.string.orders_cancel)) }
                }
            })
        },
        bottomBar = { if (view != null) Bar(state, view.counterpart.name, onEvent) { onNavigate(ChatRoute(view.deal.id.value)) } },
    ) { padding ->
        PageLoad(state.content, loading = { it == ShipOrderContent.Loading }, ghost = { ListGhost(Modifier.padding(padding)) }) { content ->
            when (content) {
                ShipOrderContent.Loading -> Unit
                ShipOrderContent.Failed -> ErrorState(stringResource(R.string.orders_failed), { onEvent(ShipOrderEvent.Retry) }, Modifier.padding(padding))
                ShipOrderContent.Missing -> OrderMissing(onBack, Modifier.padding(padding))
                // The keyboard lifts the form: what the bar already pads is not padded twice.
                is ShipOrderContent.Ready -> Column(
                    Modifier.padding(padding).consumeWindowInsets(padding).imePadding().fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 24.dp),
                ) {
                    Body(content.view, state, onEvent, onNavigate, copy)
                }
            }
        }
    }
    if (view != null && state.cancelling) {
        CancelDialog(view.counterpart.name, onCancel = { onEvent(ShipOrderEvent.Cancel) }, onKeep = { onEvent(ShipOrderEvent.KeepOrder) })
    }
}

@Composable
private fun ColumnScope.Body(view: DealView, state: ShipOrderUiState, onEvent: (ShipOrderEvent) -> Unit, onNavigate: (NavKey) -> Unit, copy: (String) -> Unit) {
    val c = MaterialTheme.colorScheme
    val order = state.order ?: return
    val shipment = order.shipment
    val form = state.form
    val card = Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth().clip(Corners.ExtraLarge).background(c.surfaceContainer)
    HeroBlock(shipHero(view, order, state.now), orderArt(order, selling = true))
    when {
        form == null -> Unit
        form.editing -> Column(card.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(stringResource(R.string.orders_edit_code), style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
            ManualFields(form, order.price, onEvent)
        }
        else -> CreateShipment(order, form, state.pending, copy, onEvent, onNavigate)
    }
    shipment?.events?.takeIf { it.isNotEmpty() && order.status == OrderStatus.SHIPPED }?.let { CarrierEvents(it, state.now, VN_ZONE, card.padding(16.dp)) }
    if (shipment != null && form?.editing != true) {
        Column(card.padding(vertical = 8.dp)) {
            ShipmentCode(shipment, copy)
            if (state.current && canEditTrackingCode(order)) {
                TextButton(onClick = { onEvent(ShipOrderEvent.EditCode) }, modifier = Modifier.padding(start = 8.dp)) {
                    Text(stringResource(R.string.orders_edit_code))
                }
            }
        }
    }
    val group = Modifier.padding(horizontal = 16.dp)
    GroupedList(group.padding(top = 16.dp)) {
        row("item") { GroupItem { ItemRow(view.listing, order.price, onClick = { onNavigate(itemRoute(view)) }) } }
        // A buyer has no Người bán page, so the whole row opens the thread with them.
        row("person") {
            GroupItem {
                PersonRow(
                    view.counterpart,
                    stringResource(R.string.orders_buyer_detail, order.recipient.line),
                    onChat = { onNavigate(ChatRoute(view.deal.id.value)) },
                    onOpen = { onNavigate(ChatRoute(view.deal.id.value)) },
                )
            }
        }
    }
    Money(order, form)
    OrderCodeRow(view, copy)
}

/** "Tạo đơn": where it goes, then the linked GHTK way or the manual one; without GHTK, a line to link it. */
@Composable
private fun ColumnScope.CreateShipment(
    order: Order,
    form: ShipmentForm,
    busy: Boolean,
    copy: (String) -> Unit,
    onEvent: (ShipOrderEvent) -> Unit,
    onNavigate: (NavKey) -> Unit,
) {
    val c = MaterialTheme.colorScheme
    val group = Modifier.padding(horizontal = 16.dp)
    val card = group.padding(top = 12.dp).fillMaxWidth().clip(Corners.ExtraLarge).background(c.surfaceContainer)
    GroupedList(group.padding(top = 8.dp), title = stringResource(R.string.orders_deliver_to)) {
        row("address") { GroupItem { AddressLine(order.recipient, copy) } }
    }
    Text(
        stringResource(R.string.orders_carrier_title),
        style = MaterialTheme.typography.titleSmall,
        color = c.primary,
        modifier = Modifier.padding(start = 32.dp, end = 32.dp, top = 24.dp).semantics { heading() },
    )
    Column(group.padding(top = 8.dp).fillMaxWidth().clip(Corners.ExtraLarge).background(c.surfaceContainer).padding(vertical = 8.dp).selectableGroup()) {
        form.account?.let { account ->
            Choice(stringResource(R.string.orders_linked_tab, account.code), stringResource(R.string.orders_your_account), form.mode == ShipmentMode.LINKED, !busy) {
                onEvent(ShipOrderEvent.Mode(ShipmentMode.LINKED))
            }
        }
        Choice(stringResource(R.string.orders_manual_tab), stringResource(R.string.orders_manual_tab_sub), form.mode == ShipmentMode.MANUAL, !busy) {
            onEvent(ShipOrderEvent.Mode(ShipmentMode.MANUAL))
        }
    }
    if (form.account == null) {
        TextButton(onClick = { onNavigate(CodSetupRoute(CodSetupOrigin.TASKS.name)) }, modifier = Modifier.padding(start = 24.dp, top = 4.dp)) {
            Text(stringResource(R.string.orders_link_ghtk))
        }
    }
    when (form.mode) {
        ShipmentMode.LINKED -> Column(card.padding(16.dp)) { LinkedFields(form, busy, onEvent) }
        ShipmentMode.MANUAL -> Column(card.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) { ManualFields(form, order.price, onEvent) }
    }
}

/** GHTK's service with the fee it charges for the weight (read, never typed), the weight, and where the carrier takes it. */
@Composable
private fun LinkedFields(form: ShipmentForm, busy: Boolean, onEvent: (ShipOrderEvent) -> Unit) {
    FilledField(
        form.weight,
        { onEvent(ShipOrderEvent.Weight(it)) },
        stringResource(R.string.orders_weight),
        keyboard = KeyboardOptions(keyboardType = KeyboardType.Decimal),
    )
    Column(Modifier.padding(top = 8.dp).selectableGroup()) {
        form.services.forEach { quote ->
            Choice(quote.service.name, quote.service.days, quote.service.id == form.service, !busy, quote.fee.full(), inset = false) {
                onEvent(ShipOrderEvent.Service(quote.service.id))
            }
        }
    }
    Column(Modifier.padding(top = 8.dp).selectableGroup()) {
        listOf(Pickup.HOME to R.string.orders_pickup_home, Pickup.POST_OFFICE to R.string.orders_pickup_post_office).forEach { (pickup, label) ->
            Choice(stringResource(label), null, form.pickup == pickup, !busy, inset = false) { onEvent(ShipOrderEvent.PickupAt(pickup)) }
        }
    }
}

/** The five carriers ShopNexus reads, the code, and what the carrier says about it. */
@Composable
private fun ManualFields(form: ShipmentForm, price: Vnd, onEvent: (ShipOrderEvent) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.selectableGroup()) {
        ShipCarrier.entries.forEach { carrier -> FilterPill(carrier.label, form.carrier == carrier, { onEvent(ShipOrderEvent.PickCarrier(carrier)) }) }
    }
    FilledField(form.trackingCode, { onEvent(ShipOrderEvent.TrackingCode(it)) }, stringResource(R.string.orders_tracking_code))
    Preview(form, price)
}

/** The carrier's answer: a spinner while it reads, the masked recipient, district and COD, or why the code cannot go. */
@Composable
private fun Preview(form: ShipmentForm, price: Vnd) {
    val c = MaterialTheme.colorScheme
    val small = MaterialTheme.typography.bodyMedium
    val carrier = form.carrier?.label.orEmpty()
    when (val p = form.preview) {
        CodePreview.Empty -> Unit
        CodePreview.Reading -> CircularProgressIndicator(Modifier.size(20.dp).testTag("code-reading"), strokeWidth = 2.dp)
        is CodePreview.Found -> Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(stringResource(R.string.orders_preview, p.parcel.recipient, p.parcel.district, p.parcel.cod.full()), style = small)
            if (p.parcel.status == ShipmentStatus.FAILED) Text(stringResource(R.string.orders_code_failed, carrier), style = small, color = c.error)
            if (p.codMismatch) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    SymbolIcon(Symbol.Error, contentDescription = null, size = 18.dp, tint = c.tertiary)
                    Text(stringResource(R.string.orders_cod_mismatch, p.parcel.cod.full(), price.full()), style = small, color = c.onSurfaceVariant)
                }
            }
        }
        CodePreview.NotFound -> Text(stringResource(R.string.orders_code_not_found, carrier), style = small, color = c.error)
        CodePreview.Failed -> Text(stringResource(DesignR.string.load_failed), style = small, color = c.error)
    }
}

/** A radio row with an optional supporting line and, for a service, the carrier's fee at the end. */
@Composable
private fun Choice(label: String, detail: String?, selected: Boolean, enabled: Boolean, fee: String? = null, inset: Boolean = true, onClick: () -> Unit) {
    val c = MaterialTheme.colorScheme
    Row(
        Modifier.fillMaxWidth().heightIn(min = 56.dp).selectable(selected, enabled = enabled, role = Role.RadioButton, onClick = onClick)
            .padding(horizontal = if (inset) 16.dp else 0.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        RadioButton(selected = selected, onClick = null)
        Column(Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyLarge)
            detail?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = c.onSurfaceVariant) }
        }
        fee?.let { Text(it, style = MaterialTheme.typography.titleSmall) }
    }
}

/** "Tiền": the COD goods, the shipping the buyer pays (the carrier's fee, or that it says it later), and the payout account for a GHTK shipment. */
@Composable
private fun ColumnScope.Money(order: Order, form: ShipmentForm?) {
    val linked = form?.takeIf { it.mode == ShipmentMode.LINKED && !it.editing }
    val fee = order.shipment?.fee ?: linked?.let { f -> f.services.first { it.service.id == f.service }.fee }
    GroupedList(Modifier.padding(horizontal = 16.dp).padding(top = 24.dp), title = stringResource(R.string.orders_money)) {
        row("goods") { GroupItem { MoneyRow(Symbol.Payments, stringResource(R.string.orders_cod_goods), null, order.price.full()) } }
        row("shipping") {
            GroupItem { MoneyRow(Symbol.LocalShipping, stringResource(R.string.orders_buyer_paid_shipping), null, fee?.full() ?: stringResource(R.string.orders_fee_later)) }
        }
        linked?.account?.let { account ->
            row("payout") {
                GroupItem {
                    MoneyRow(
                        Symbol.AccountBalance,
                        stringResource(R.string.orders_payout_bank, account.brand.name),
                        stringResource(R.string.orders_payout_account, account.brand.name, account.code),
                        null,
                    )
                }
            }
        }
    }
    Column(Modifier.padding(horizontal = 24.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        moneyNotes(MoneyStep.SELL_MONEY, order.price).forEach { MoneyNote(it) }
    }
}

/** The seller's words: create for the buyer, then follow the carrier, then the result. */
@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
private fun shipHero(view: DealView, order: Order, now: Instant): Hero {
    val person = view.counterpart.name
    val shipment = order.shipment
    val code = shipment?.let { Symbol.ReceiptLong to "${it.carrier.label} · ${it.trackingCode}" }
    return when (order.status) {
        OrderStatus.PENDING -> Hero(
            MaterialShapes.Cookie9Sided,
            MilestoneTone.TRUST,
            Symbol.ReceiptLong,
            stringResource(R.string.orders_hero_create_for, person),
            listOf(Symbol.Schedule to stringResource(R.string.orders_hero_waiting_since, clockLabel(order.requestedAt, now, VN_ZONE))),
        )
        OrderStatus.SHIPPED -> when (shipment?.status) {
            ShipmentStatus.IN_TRANSIT -> Hero(MaterialShapes.Cookie9Sided, MilestoneTone.TRUST, Symbol.LocalShipping, stringResource(R.string.orders_hero_shipping_to, person), listOfNotNull(code))
            ShipmentStatus.DELIVERED -> Hero(MaterialShapes.SoftBurst, MilestoneTone.TRUST, Symbol.Check, stringResource(R.string.orders_hero_delivered_to, person), listOfNotNull(code))
            else -> Hero(
                MaterialShapes.Cookie9Sided,
                MilestoneTone.TRUST,
                Symbol.ScheduleSend,
                stringResource(R.string.orders_hero_pickup, (shipment?.carrier ?: ShipCarrier.GHTK).label),
                listOfNotNull(code),
            )
        }
        OrderStatus.COMPLETED -> Hero(
            MaterialShapes.SoftBurst,
            MilestoneTone.TRUST,
            Symbol.Check,
            stringResource(R.string.orders_hero_delivered, person),
            listOf(Symbol.AccountBalance to stringResource(R.string.orders_hero_payout)),
        )
        OrderStatus.FAILED -> Hero(MaterialShapes.Gem, MilestoneTone.NEUTRAL, Symbol.Undo, stringResource(R.string.orders_hero_failed), listOf(Symbol.Storefront to stringResource(R.string.orders_fact_relisted)))
        OrderStatus.CANCELLED -> Hero(MaterialShapes.Circle, MilestoneTone.NEUTRAL, Symbol.Cancel, stringResource(R.string.orders_hero_cancelled), listOf(Symbol.Person to cancelReason(view, order)))
    }
}

/** "Tạo đơn" or "Xác nhận" with a message button while the order waits; "Quay lại" and "Lưu mã" while a code is edited. */
@Composable
private fun Bar(state: ShipOrderUiState, buyer: String, onEvent: (ShipOrderEvent) -> Unit, onChat: () -> Unit) {
    val form = state.form ?: return
    val busy = state.pending
    if (form.editing) {
        DockedActionBar {
            TonalAction(Symbol.Undo, stringResource(R.string.orders_go_back), !busy) { onEvent(ShipOrderEvent.CloseEdit) }
            PrimaryAction(Symbol.Check, stringResource(R.string.orders_save_code), form.canSubmit, busy) { onEvent(ShipOrderEvent.SaveCode) }
        }
        return
    }
    DockedActionBar {
        FilledTonalIconButton(onClick = onChat, modifier = Modifier.size(48.dp)) { SymbolIcon(Symbol.Chat, stringResource(UiR.string.deal_ui_message, buyer)) }
        val label = if (form.mode == ShipmentMode.LINKED) R.string.orders_create else R.string.orders_confirm_code
        PrimaryAction(Symbol.ReceiptLong, stringResource(label), form.canSubmit, busy) { onEvent(ShipOrderEvent.Create) }
    }
}
```

- [ ] **Step 6: The strings**

In `feature/orders/src/main/res/values/strings.xml`: `orders_phase_receive` becomes `Nhận hàng`; `orders_cancel_too_late` becomes `Đơn đã tạo, không hủy được nữa`; add

```xml
    <string name="orders_phase_create">Tạo đơn</string>
    <string name="orders_hero_wait_seller">Chờ người bán tạo đơn</string>
    <string name="orders_hero_wait_delivery">Chờ giao hàng</string>
    <string name="orders_hero_got_it">Đã nhận hàng</string>
    <string name="orders_hero_failed">Giao không thành</string>
    <string name="orders_hero_pickup">Chờ %1$s lấy hàng</string>
    <string name="orders_hero_delivered_to">Đã giao cho %1$s</string>
    <string name="orders_fact_relisted">Tin đã mở bán lại</string>
    <string name="orders_reason_seller_timeout">Người bán chưa tạo đơn</string>
    <string name="orders_reason_pickup_timeout">Hãng chưa lấy hàng</string>
    <string name="orders_reason_shipped_to_another">Người bán đã gửi cho người khác</string>
    <string name="orders_reason_listing_closed">Tin đã đóng</string>
    <string name="orders_buy_again">Mua lại</string>
    <string name="orders_confirm_code">Xác nhận</string>
    <string name="orders_edit_code">Sửa mã</string>
    <string name="orders_save_code">Lưu mã</string>
    <string name="orders_linked_tab">GHTK · %1$s</string>
    <string name="orders_manual_tab">Tự gửi</string>
    <string name="orders_manual_tab_sub">GHN, SPX, J&amp;T, Viettel Post</string>
    <string name="orders_pickup_home">Lấy tại nhà</string>
    <string name="orders_pickup_post_office">Gửi tại bưu cục</string>
    <string name="orders_fee_later">Hãng báo sau</string>
    <string name="orders_link_ghtk">Liên kết GHTK để tạo đơn ngay trong app</string>
    <string name="orders_preview">%1$s · %2$s · COD %3$s</string>
    <string name="orders_code_not_found">%1$s không có mã này</string>
    <string name="orders_code_failed">%1$s báo mã này giao không thành</string>
    <string name="orders_cod_mismatch">COD trên đơn %1$s, khác giá đã chốt %2$s</string>
    <string name="orders_shipped_via">%1$s đã gửi hàng qua %2$s</string>
    <string name="orders_created_linked">Đã tạo đơn GHTK</string>
    <string name="orders_told_code">Đã báo %1$s mã vận đơn</string>
    <string name="orders_code_edited">Đã sửa mã vận đơn</string>
```

Then `python3 tmp/unused_strings.py feature/orders/src/main/res/values/strings.xml` and delete every name it prints (the record, refund, decline, photo, step, method, QR, pickup-window, "Khác", typed-fee, eta, door, refusal, `orders_ago_*` and self-shipped strings among them); run it again and expect no output.

- [ ] **Step 7: Port the screen and list tests**

Rules for `cod/CodOrderScreenTest.kt`, `ship/ShipOrderScreenTest.kt`, `list/OrdersScreenTest.kt`, `OrderRouterTest.kt`, `checkout/*Test.kt`: `at(status: OrderStatus)` becomes `at(jump: OrderJump) = orderAt(<deal>, jump, now, VN_ZONE)` with the Task 3 mapping; `checkout.view.deal.codRequest != null` becomes `checkout.view.deal.openOrder != null`; "Tạo đơn, gửi hàng" in an expected label becomes "Tạo đơn" and "Xem và nhận" becomes "Nhận hàng"; `OrderRoute(id)` built by a row or an action is `OrderRoute(id, orderId = "<id>-o1")`. In `ShipOrderScreenTest`, `state(view, local)` keeps its shape and `account` stays `Fixtures.account().codSetup.account`; the `self`/`selfSent` vals become one `manual` val:

```kotlin
    /** Khánh Linh sent the stool on SPX's own app and typed its code. */
    private val manual = huy.copy(
        deal = DealRules.apply(huy, DealCommand.CreateShipment(NewShipment.Manual(ShipCarrier.SPX, "SPXVN031245678")), now, EngineContext(carrier = FakeCarrier())),
    )
```

Delete the tests about what this task removed: in `CodOrderScreenTest` `aRecordMarksEveryStepDone`, `aSelfShippedOrderShowsItsCode`, `aSelfShippedParcelOnItsWayAsksTheBuyer`, `receivingOverARecordSaysItIsWithdrawn`, `aRefundWithoutAnAmountReadsPlainly`, `aParcelNotReceivedCanStillArriveAndBeRated`, `aRatedMissingParcelStillArrivesAndKeepsItsCode`, `aParcelNotReceivedCanBeRecorded`, `aRefusedParcelGoesBack`, `theRecordSheetHoldsNoNoteAndNoAccount`, `theRecordSheetQuotesNoMark`, `aRecordWaitsForTheSeller`, `anUnknownCarrierHasNoLookUp`; in `ShipOrderScreenTest` `anotherCarrierNeedsAllThree`, `anotherCarrierWithAllThreeCreates`, `aSelfShippedParcelHasTwoSteps`, `aSelfShippedParcelSentWaitsForTheBuyer`, `aNewStatusScrollsBackToTheHero`, `toShipShowsTheThreeStepsAndWaitsForThePhoto`, `aPhotoChecksTheFirstStepAndAllowsSending`, `theCameraHandsBackThePhoto`, `noCameraAppSaysSoInTheSnackbar`, `theCodeOpensAsAQrSheet`, `theWayToSendIsChosen`, `aShippingParcelShowsWhenItArrives`, `aRefusedParcelComesBack`, `anOpenRecordShowsTheIncidentAndBothAnswers`, `theRefundSheetOffersThreeAmounts`, `aRefundOnItsWayShowsProgress`, `aRefundedRecordThanksTheSeller`, `decliningAsksFirst`, `aDeclinedRecordStaysOnTheProfile`, `largeTextDoesNotClipTheStepsToShip`, `largeTextDoesNotClipTheRecord`, `aStepToDoIsGreyUntilDone`, `theWaysToSendKeepTheirRoomAtLargeText`, `anOtherCarrierAsksForItsName`, `aSkippedNameSaysSoOnceTheRestIsTyped`, `theRefundSheetAsksForTheAccountInChat`, and the `clearFileProviderCache` setup with the camera; in `OrdersScreenTest` `theDoorOffersALook`, `aRecordOnASoldOrderAsksForAnAnswer`, `aSelfShippedParcelAsksTheBuyer`. Port the rest by the rules (`everyStatusCanFollowAnyOther` walks `OrderJump.entries`; the large-text and grouping tests run on `at(OrderJump.SHIPPED)` and `at(OrderJump.COMPLETED)`).

Add to `CodOrderScreenTest` (the file's `show`, `seen`, `gone`, `events` stay; `state(view)` is `codOrderUiState(CodOrderContent.Ready(view), local, now)`):

```kotlin
    @Test
    fun aPendingOrderWaitsForTheSellerAndCanBeCancelled() {
        show(state(at(OrderJump.PENDING)))
        seen("Chờ người bán tạo đơn")
        compose.onNodeWithText("Hủy đơn").performClick()
        assertThat(events).containsExactly(CodOrderEvent.AskCancel)
    }

    /** Through the whole of shipped the buyer reads "Chờ giao hàng", whatever the carrier says, and can say it came. */
    @Test
    fun aDeliveredParcelStillReadsChoGiaoHang() {
        show(state(at(OrderJump.DELIVERED)))
        seen("Chờ giao hàng")
        gone("Đã giao")
        compose.onNodeWithText("Đã nhận hàng").performClick()
        assertThat(events).containsExactly(CodOrderEvent.AskReceived)
    }

    @Test
    fun receiptIsAskedFirst() {
        show(state(at(OrderJump.SHIPPED), CodOrderLocal(confirmAsked = true)))
        seen("Đã nhận hàng?")
        compose.onNode(hasText("Đã nhận hàng") and hasAnyAncestor(isDialog())).performClick()
        assertThat(events).containsExactly(CodOrderEvent.ConfirmReceived)
    }

    @Test
    fun aCompletedOrderAsksForStarsAndOffersNoRecord() {
        show(state(at(OrderJump.COMPLETED)))
        seen("Đã nhận hàng")
        compose.onNodeWithContentDescription("5 sao").assertExists()
        gone("có vấn đề?")
        gone("ghi nhận")
        gone("tiền hoàn")
        gone("Hủy đơn")
    }

    @Test
    fun aFailedOrderIsBoughtAgain() {
        show(state(at(OrderJump.FAILED)))
        seen("Giao không thành")
        compose.onNodeWithText("Mua lại").performClick()
        assertThat(events).containsExactly(CodOrderEvent.BuyAgain)
    }

    @Test
    fun aCancelledOrderSaysWhoWithNoAction() {
        show(state(at(OrderJump.CANCELLED)))
        seen("Đã hủy đơn")
        seen("Bạn hủy")
        gone("Mua lại")
        gone("Hủy đơn")
    }

    /** No line counts down the order's 3 days, in any state. */
    @Test
    fun noTimerTextOnAPendingOrder() {
        show(state(at(OrderJump.PENDING)))
        gone("Tự hủy")
        gone("ngày nữa")
        gone("hết hạn")
        gone("tự hoàn tất")
    }
```

Add to `ShipOrderScreenTest` (`toShip` becomes `private val pending = huy`, the seeded request; `pushed` records `onNavigate`):

```kotlin
    @Test
    fun aPendingOrderOffersGhtkAndTheManualWayAndNothingTheSpecDropped() {
        show(state(pending))
        seen("GHTK · S55163")
        seen("Tự gửi")
        gone("Khác")
        gone("Phí ship (₫)")
        gone("Chụp hàng")
        gone("Xác nhận gửi")
        compose.onNodeWithText("Tạo đơn").assertIsEnabled()
    }

    @Test
    fun withoutGhtkTheManualWayLinksToTheSetup() {
        show(shipOrderUiState(ShipOrderContent.Ready(pending), ShipOrderLocal(), now, account = null))
        listOf("GHTK", "GHN", "SPX", "J&T", "Viettel Post").forEach { seen(it) }
        compose.onNodeWithText("Liên kết GHTK để tạo đơn ngay trong app").performClick()
        assertThat(pushed).containsExactly(CodSetupRoute("TASKS"))
    }

    @Test
    fun thePreviewSaysWhatTheCarrierKnowsAndADifferentCodWarns() {
        val parcel = Parcel("Đ••• H•••", "Phú Nhuận", Vnd(450_000), ShipmentStatus.PENDING_PICKUP, Vnd(22_000))
        val local = ShipOrderLocal(
            mode = ShipmentMode.MANUAL, carrier = ShipCarrier.SPX, trackingCode = "SPXVN1",
            preview = CodePreview.Found(parcel, codMismatch = true), previewFor = ShipCarrier.SPX to "SPXVN1",
        )
        show(state(pending, local))
        seen("Đ••• H••• · Phú Nhuận · COD 450.000 ₫")
        seen("COD trên đơn 450.000 ₫, khác giá đã chốt 350.000 ₫")
        compose.onNodeWithText("Xác nhận").performClick()
        assertThat(events).containsExactly(ShipOrderEvent.Create)
    }

    @Test
    fun aCodeTheCarrierDoesNotKnowCannotBeConfirmed() {
        val local = ShipOrderLocal(
            mode = ShipmentMode.MANUAL, carrier = ShipCarrier.SPX, trackingCode = "NOTFOUND1",
            preview = CodePreview.NotFound, previewFor = ShipCarrier.SPX to "NOTFOUND1",
        )
        show(state(pending, local))
        seen("SPX không có mã này")
        compose.onNodeWithText("Xác nhận").assertIsNotEnabled()
    }

    @Test
    fun aManualShipmentOffersSuaMaAndALinkedOneDoesNot() {
        show(state(manual))
        compose.onNodeWithText("Sửa mã").performClick()
        assertThat(events).containsExactly(ShipOrderEvent.EditCode)
    }

    @Test
    fun aLinkedShipmentHasNoSuaMa() {
        show(state(at(OrderJump.SHIPPED)))
        seen("Chờ GHTK lấy hàng")
        gone("Sửa mã")
    }

    @Test
    fun aFailedOrderPutsTheListingBackOnSale() {
        show(state(at(OrderJump.FAILED)))
        seen("Giao không thành")
        seen("Tin đã mở bán lại")
    }
```

(imports: `OrderJump`, `FakeCarrier`, `EngineContext`, `NewShipment`, `Parcel`, `ShipCarrier`, `ShipmentMode`, `ShipmentStatus`, `CodSetupRoute`, `hasAnyAncestor`, `isDialog`, `assertIsEnabled`, `assertIsNotEnabled`.)

- [ ] **Step 8: Run the module's tests and lint**

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :feature:orders:testDebugUnitTest :feature:orders:lintDebug :feature:orders:detekt`
Expected: BUILD SUCCESSFUL; `CodOrderViewModelTest` 8, `ShipOrderViewModelTest` 11 and `OrderArtTest` 1 tests pass with the ported ones.

- [ ] **Step 9: Commit**

```bash
./gradlew :feature:orders:spotlessApply
git add feature/orders
git commit -m "feat(orders): one row per order, and interim Đơn COD and Đơn bán on the new order flow"
```

Then stop the daemons.

### Task 9: The debug panel, the walks and the gate

**Files:**
- Modify: `app/src/debug/kotlin/vn/shopnexus/app2/DebugHost.kt`, `app/src/debug/res/values/strings.xml`, `README.md`
- Test: `app/src/testDebug/kotlin/vn/shopnexus/app2/DebugPanelTest.kt`, `app/src/test/kotlin/vn/shopnexus/app2/SliceTest.kt`, `DealsWalkTest.kt`, `SellWalkTest.kt`

**Interfaces:**
- Consumes: Task 3's `ConsoleTarget`, `ORDER_JUMPS`, `OrderJump`, `DebugControls.jumpOrder(id, jump)`; every screen from Tasks 5–8.
- Produces: nothing new; the app assembles and every touched module's `check` passes.

- [ ] **Step 1: Write the failing tests**

`DebugPanelTest.aLongPressOpensThePanelAndAJumpMovesTheDeal` becomes

```kotlin
    @Test
    fun aLongPressOpensThePanelAndAJumpMovesTheDeal() {
        compose.setContent { ShopNexusTheme { DebugHost { Box { Text("Tuấn Kiệt", Modifier.debugTrigger()) } } } }
        compose.onNodeWithText("Tuấn Kiệt").performTouchInput { longClick() }
        compose.onNodeWithText("Đã gửi hàng").performClick()
        val deal = world.value.deals.getValue(DealId("d-kiet")).deal
        assertThat(deal.status).isEqualTo(DealStatus.AGREED)
        assertThat(deal.currentOrder!!.status).isEqualTo(OrderStatus.SHIPPED)
    }
```

(imports: `DealStatus`, `OrderStatus` from `vn.shopnexus.core.model`; `DealStage` out.)

The walks read the order instead of the 15 statuses: in `DealsWalkTest` and `SellWalkTest`, `status(id)` becomes `private fun status(id: String) = world.value.deals.getValue(DealId(id)).deal.currentOrder?.status` (in `SellWalkTest`, of a `DealId`), and `vn.shopnexus.core.domain.OrderStatus` imports become `vn.shopnexus.core.model.OrderStatus`.

`SliceTest`, from "Gửi yêu cầu COD" on:

```kotlin
        compose.onNodeWithText("Gửi yêu cầu COD").performClick()
        waitFor("Đơn COD")
        assertThat(world.value.deals.getValue(DealId("d-kiet")).deal.currentOrder).isNotNull()

        // Tuấn Kiệt ships on GHTK 1,5 s after the request; the buyer waits for the parcel, with the listing's claims for the door.
        waitFor("Chờ giao hàng")
        waitFor("Tin ghi", 10_000)
        compose.onNodeWithText("Pin 88% · Máy zin, chưa sửa · Bản VN/A").assertExists()
        // The carrier delivers; the buyer says it came, asked first, and the page asks for the stars.
        compose.waitUntil(10_000) {
            world.value.deals.getValue(DealId("d-kiet")).deal.currentOrder?.shipment?.status == ShipmentStatus.DELIVERED
        }
        compose.onNodeWithText("Đã nhận hàng").performClick()
        compose.onNode(hasText("Đã nhận hàng") and hasAnyAncestor(isDialog())).performClick()
        waitForDescription("5 sao", 10_000)
        compose.onNodeWithContentDescription("5 sao").performClick()
        compose.onNodeWithText("Gửi đánh giá").performScrollTo().performClick()
        compose.waitUntil(5_000) { world.value.deals.getValue(DealId("d-kiet")).deal.rating == 5 }

        val deal = world.value.deals.getValue(DealId("d-kiet")).deal
        assertThat(deal.agreedPrice).isEqualTo(Vnd(5_000_000))
        assertThat(deal.currentOrder!!.status).isEqualTo(OrderStatus.COMPLETED)
        assertThat(deal.thread.last()).isEqualTo(ThreadItem.Event("star", "5 sao cho Tuấn Kiệt", deal.ratedAt!!))
        scenario.close()
```

`DealsWalkTest`, the COD walk from "Đã gửi yêu cầu COD cho Hoàng Nam" to the stars:

```kotlin
        waitFor("Đã gửi yêu cầu COD cho Hoàng Nam")
        // Hoàng Nam ships, the carrier picks it up and delivers it: 1 s at ten times the pace. The buyer then says it came.
        waitFor("Tin ghi", 10_000)
        compose.onNodeWithText("Pin 86% · Bản quốc tế, đã mở mạng").assertExists()
        compose.waitUntil(10_000) { world.value.deals.getValue(DealId("d-nam")).deal.currentOrder?.shipment?.status == ShipmentStatus.DELIVERED }
        compose.onNodeWithText("Đã nhận hàng").performClick()
        compose.onNode(hasText("Đã nhận hàng") and hasAnyAncestor(isDialog())).performClick()
        compose.waitUntil(10_000) { compose.onAllNodes(hasContentDescription("5 sao")).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithContentDescription("5 sao").performClick()
        compose.onNodeWithText("Gửi đánh giá").performScrollTo().performClick()
        waitFor("5 sao cho Hoàng Nam")
        assertThat(status("d-nam")).isEqualTo(OrderStatus.COMPLETED)
        assertThat(world.value.deals.getValue(DealId("d-nam")).deal.currentOrder!!.shipment!!.carrier).isEqualTo(ShipCarrier.GHTK)
```

(the rest of the walk, from "Giao COD replaced itself", is unchanged.) `shipWalk` becomes

```kotlin
    /** Tôi → Đơn bán → the stool's "Tạo đơn" → "Tạo đơn" on GHTK → delivered and confirmed → Tin nhắn's Đức Huy row loses "Chờ tạo đơn". */
    @Test
    fun shipWalk() {
        val scenario = ActivityScenario.launch(MainActivity::class.java)
        waitFor("Gần bạn")
        tab("Tin nhắn")
        waitForTag("inbox-row-d-huy")
        compose.onNode(hasText("Chờ tạo đơn") and hasAnyAncestor(hasTestTag("inbox-row-d-huy"))).assertExists()

        tab("Tôi")
        waitFor("Đơn bán")
        compose.onNodeWithText("Đơn bán").performClick()
        waitFor("Tạo đơn")
        compose.onNodeWithText("Tạo đơn").performClick()
        // The form starts on the GHTK account with Giao nhanh for 2 kg from home, so "Tạo đơn" is ready.
        waitFor("Tạo đơn cho Đức Huy")
        compose.onNode(hasText("Tạo đơn") and hasClickAction()).performClick()
        waitFor("Chờ GHTK lấy hàng")
        assertThat(status("d-huy")).isEqualTo(OrderStatus.SHIPPED)
        compose.onNodeWithText("Chụp hàng", substring = true).assertDoesNotExist()
        waitFor("Đức Huy đã nhận hàng", 10_000)
        assertThat(status("d-huy")).isEqualTo(OrderStatus.COMPLETED)

        // Đơn bán and Đơn hàng have no navigation bar; back to Tôi first.
        compose.onNodeWithContentDescription("Quay lại").performClick()
        waitFor("Bán · 2")
        compose.onNodeWithContentDescription("Quay lại").performClick()
        waitFor("Đơn bán")
        tab("Tin nhắn")
        waitForTag("inbox-row-d-huy")
        compose.onNode(hasText("Chờ tạo đơn") and hasAnyAncestor(hasTestTag("inbox-row-d-huy"))).assertDoesNotExist()
        scenario.close()
    }
```

(the camera permission grant and `answer(…)` go if nothing else in the file uses them.)

`SellWalkTest.codSaleWalk`, from the first `button("Tạo đơn")`:

```kotlin
        button("Tạo đơn").performClick()
        waitFor("Tạo đơn cho Thảo Vy")
        button("Tạo đơn").performClick()
        waitFor("Chờ GHTK lấy hàng")
        waitFor("Thảo Vy đã nhận hàng", 15_000)
        compose.waitUntil(10_000) { world.value.deals.getValue(deal).deal.rating == 5 }
```

and `aboveTheLineSaleWalk`'s three assertions become

```kotlin
        // Only her request so far: the person creates the shipment, and nothing runs out meanwhile.
        assertThat(world.value.deals.getValue(deal).deal.currentOrder!!.status).isEqualTo(OrderStatus.PENDING)
        assertThat(world.value.deals.getValue(deal).deal.currentOrder!!.shipment).isNull()
        assertThat(status(deal)).isEqualTo(OrderStatus.PENDING)
```

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :app:testDebugUnitTest` (in the background; wait for the notice).
Expected: compilation fails in `DebugHost.kt` (`ConsoleTarget.REQUESTED`, `jumpOrder(id, status)` with an `OrderStatus`).

- [ ] **Step 2: The debug panel**

`DebugHost.kt`: the targets become

```kotlin
    val targets = listOf(
        ConsoleTarget.COUNTERED to R.string.debug_countered,
        ConsoleTarget.WAITING to R.string.debug_waiting,
        ConsoleTarget.AGREED to R.string.debug_agreed,
        ConsoleTarget.PENDING to R.string.debug_pending,
        ConsoleTarget.SHIPPED to R.string.debug_shipped,
        ConsoleTarget.RECEIVED to R.string.debug_received,
        ConsoleTarget.DONE to R.string.debug_done,
    )
```

and the order rows read `ORDER_JUMPS.forEach { (id, jumps) -> … jumps.forEach { jump -> AssistChip(onClick = { controls.jumpOrder(id, jump); onDismiss() }, label = { Text(jump.name) }) } }` (the comment above them says "the jump names"). `app/src/debug/res/values/strings.xml`: `debug_requested` becomes `debug_pending` with `Đã chọn COD`, `debug_placed` becomes `debug_shipped` with `Đã gửi hàng`, `debug_at_door` is deleted. Run `python3 tmp/unused_strings.py app/src/debug/res/values/strings.xml`; expected: no output.

- [ ] **Step 3: README**

`README.md`, "Fake data": replace "A placed COD parcel is picked up after 3.5 s and reaches the door 3.5 s later, and the shipper reports it taken 6 s after that. Tuấn Kiệt refunds an incident record after 2.2 s." with

> Tuấn Kiệt ships a COD order on GHTK 3 s after the request; the carrier picks it up 3.5 s later and delivers it 3.5 s after that, and the order completes when the buyer says it came, or 3 days after delivery. An order with no shipment after 3 days is cancelled, and so is a shipment nobody picked up in 3 days. The fake carrier finds every tracking code except those starting with NOTFOUND; one starting with WRONGCOD carries a COD amount 100.000 ₫ above the price.

and "It jumps the deal to any console state" stays; add after it "and each seeded order to pending, shipped, delivered, completed, failed or cancelled". Run the README paragraph through `python3 ~/.claude/skills/humanizing-writing/ai-tells.py README.md` (the `humanizing-writing` skill) and fix what it flags in the new sentences.

- [ ] **Step 4: The gate**

Run, in the background, and wait for the notice:

```bash
. ~/.local/share/shopnexus/android-env.sh && timeout 2400 ./gradlew :app:assembleDebug \
  :core:model:check :core:domain:check :core:data:check :core:navigation:check :core:designsystem:check :core:ui:check \
  :feature:deal:check :feature:inbox:check :feature:me:check :feature:seller:check :feature:discover:check \
  :feature:notifications:check :feature:orders:check :app:check > tmp/gate-order-flow.log 2>&1; tail -5 tmp/gate-order-flow.log
```

Expected: `BUILD SUCCESSFUL`. A failure in a module this plan did not touch is not this plan's to fix; say so and stop. Then `grep -rn "DealStage\|CodStatus\|CodShipment\|CodRequest\|IncidentRecord\|RecordStatus\|RecordId\|ThreadItem.Record\|RecordCard\|RecordSheet\|ShipParcel\|CreateWaybill\|RecordSelfShipment\|CancelCod\|refundOptions\|orderStatus(" --include='*.kt' core feature app` prints nothing.

If a phone or emulator is attached (`adb devices`), `./run.sh` and walk: Khám phá → the iPhone 13 Pro → "Đồng ý" on Tuấn Kiệt's counter → Giao COD → Đơn COD ("Chờ người bán tạo đơn", then "Chờ giao hàng") → "Đã nhận hàng" → the stars; Tôi → Đơn bán → the stool → "Tự gửi" → SPX → "NOTFOUND1" (refused) → "WRONGCOD1" (the warning) → "Xác nhận" → "Sửa mã"; the debug panel's d-nam `FAILED` → Đơn COD "Giao không thành" → "Mua lại" → Giao COD. Screenshots to `tmp/order-flow/`. With no device, say the walk is left for the user.

- [ ] **Step 5: Commit**

```bash
./gradlew :app:spotlessApply
git add app README.md
git commit -m "feat(app): the debug panel jumps orders to the new states, and the walks follow the order flow"
```

Stop the daemons and check `ps` for leftover shells from this session before reporting. Then follow superpowers:finishing-a-development-branch; the merge into `main` after the boosts work expects only the import-block conflicts the Global Constraints name.

---
## Self-review

- **Spec coverage ("App", step 2).** Model mirrors the server, the removed types go, the four-step bar is computed (Task 1; `phaseOf` in Task 2). The six commands and the removed ten (Tasks 1, 2). Fake carrier with `NOTFOUND` and `GHTK-<n>` (Task 3). Simulator `PENDING_PICKUP → IN_TRANSIT` (warehouse event) `→ DELIVERED` (Task 3), completed 3 days later and both 3-day timeouts (Task 4). `DebugControls` jumps to the six states, failure only there (Task 3, panel in Task 9). Failed delivery: order `FAILED`, deal `NEGOTIATING` without its price, listing back on sale (Task 2 `shipmentUpdated`, Task 3 `aFailedJumpPutsTheListingBackOnSale`), "Giao không thành" and "Mua lại" (Task 8). Buyer words "Chờ người bán tạo đơn" and "Chờ giao hàng" through all of shipped, "Đã nhận hàng" behind a dialog (Tasks 5, 8). No timer text (Tasks 5, 8 tests), no refund state and no "Báo chưa nhận hàng" (Tasks 1, 5, 6, 8). Chat: milestones as event lines, record card and item gone, console and composer on the new model (Task 6). Standing and Tôi: failed deliveries against orders, no record figures, `dueOrder` only orders waiting for their shipment, tier sheet without records (Tasks 2, 7). Orders list one row per order (Tasks 2, 8). Interim adaptation of `feature/orders` with the spec's deletions and the new commands, marked interim (Task 8). Server-plan names: `express | standard`, 1 to 20 000 g, `HOME | POST_OFFICE`, a `FAILED` code refused, a `DELIVERED` code ships delivered, one report moves every order with the code (Tasks 2, 3).
- **Placeholders.** No "TBD", "TODO" or "similar to Task N". Ported tests are named one by one with what each becomes; mechanical renames are given as rules with their mapping.
- **Type consistency.** `orderAt(start, jump: OrderJump, now, zone)` everywhere after Task 3; `ConsoleState.OrderStep(order, price)` in Tasks 2, 3, 6; `canCancel(deal)` in Tasks 2, 8; `phaseOf(deal)` (Chat) and `phaseOf(order, rating)` (list, timeline); `orderLine(view, order, now, zone)` and `orderAction(view, order)` in Tasks 5, 6, 8; `OrderRoute(dealId, sent, orderId)` in Tasks 5, 8; `DealEngine.carrier` read by `FakeDealRepository` (Task 3) and nowhere else; `GHTK_SERVICES` ids `express`/`standard` in Tasks 2, 3, 8; `LOOKUP_DELAY_MILLIS` defined in Task 8's view model and read by its test.
- **Review Focus.** Each of the five lines has its test in the task that owns the code: Task 2 `OrderMovesTest.aLateSignalOnAClosedOrderChangesNothing` and Task 3 `SimulatorOrderTest.anEarlyReceiptDropsTheCarriersLaterSteps`; Task 4 `OrderTimersTest.aTimerForAnOlderOrderLeavesTheNewOneAlone`; Task 3 `FakeCarrierTest.notFoundIsAnyCaseAfterTrimming` and Task 8 `ShipOrderViewModelTest.aLateLookupNeverReplacesTheNewerCode`; Task 2 `DealRulesTest.aFailedDealIsBoughtAgainWithASecondOrder` and Task 8 `OrdersViewModelTest.aFailedThenReboughtDealShowsTwoRows`, `CodOrderViewModelTest.anOlderOrderOpensWithNoAction`; Task 3 `FakeDealRepositoryTest.aShipmentCancelsTheOtherPendingOrdersOnItsListing`.

## Execution handoff

Recommended: subagent-driven, one fresh implementer and reviewer per task. The nine tasks go bottom-up through modules whose interfaces each later task compiles against, and the app does not assemble until Task 9, so a mistake in Tasks 1 to 3 is cheapest caught at that task's own gate.
