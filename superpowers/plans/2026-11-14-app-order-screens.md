# App order screens (part 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Đơn bán (create shipment on GHTK/GHN or Tự gửi, Sửa mã) and Đơn COD follow the part 4 mockups `ship-order` (v24) and `cod-order` (v25), replacing the interim layouts, on the fake data.

**Architecture:** The view models of part 1 already hold the form, the carrier preview, the edit and the report; this plan changes their few gaps (services per carrier, the manual carrier's default, the payout account) and redraws the two screens. The domain gains one service table per linked carrier so GHN stops quoting GHTK's services.

**Tech Stack:** Kotlin, Jetpack Compose (Material 3 Expressive), Hilt, Robolectric screen tests, Truth. Mockups in Python builders under `app/.superdesign/tools/`.

**Spec:** `docs/superpowers/specs/2026-11-12-order-flow-sync-design.md` (§ App › Screens), `docs/superpowers/specs/2026-11-13-carrier-integration-design.md` (§ App), `docs/superpowers/specs/2026-11-13-support-tickets-design.md` (§ App, the report on Đơn COD). Mockups: `app/.superdesign/mockups/ship-order.html`, `cod-order.html`; `app/.superdesign/design-system.md` § Đơn COD, § Đơn bán. Open a mockup in a browser with its hash (`#self`, `#ghn`, `#unlinked`, `#pickup`, `#manual`, `#edit`, `#completed`, `#failed`, `#cancelled`; for Đơn COD `#pending`, `#reported`, `#completed`, `#failed`, `#cancelled`).

## Global Constraints

- Work in the worktree `~/shopnexus/app-wt/order-screens` on branch `feat/order-screens`. Never run git in `~/shopnexus/app` (another session's branch).
- Gradle: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew …` from the worktree. Run only touched modules. Never `./gradlew --stop` (other sessions share the daemon); after the last task, kill only daemons this run started, if any can be told apart, else leave them.
- Copy is Vietnamese with diacritics, the mockups' words exactly. No timer text ("3 ngày", "còn … giờ") anywhere on either screen.
- No pack photo, no fee field, no "Khác", no separate send step (order-flow spec).
- Colours only from `MaterialTheme.colorScheme`; type only from `MaterialTheme.typography`.
- Commits: no `Co-Authored-By` trailer. Commit messages and code comments through `python3 ~/.claude/skills/humanizing-writing/ai-tells.py FILE` (fix every hit by rewriting).
- `ShipCarrier` keeps its five values; only GHTK and GHN can be linked (carrier spec).

## Review Focus

1. A seller with GHN linked and a saved `service = "express"` (from a GHTK draft) switches to the GHN tab: the form must fall back to GHN's one service and send `standard`, never `express`. Test: Task 2 `ShipOrderViewModelTest.ghnSendsItsOwnService`.
2. A saved `mode = LINKED` with no carrier linked any more (unlinked after the draft): the form must open on "Tự gửi" or the unlinked card, never on linked fields with no tab. Test: Task 4 `ShipOrderViewModelTest.aLinkedDraftWithNoAccountOpensManual`.
3. A failed order that has a not-received ticket: "Mua lại" must still show; the report bar must not hide it. Test: Task 3 `CodOrderScreenTest.aFailedOrderWithATicketStillBuysAgain`.
4. "Tự gửi" opened with nothing picked: the first linked carrier is the chip, so typing a code reads it at once. Test: Task 4 `ShipOrderViewModelTest.manualStartsOnTheFirstLinkedCarrier`.
5. Sửa mã sheet dismissed by drag or Back while a save is in flight: the sheet stays (dismissible false) and the save's result closes it. Test: Task 4 `ShipOrderScreenTest.theEditSheetStaysWhileSaving`.

---

### Task 1: Mockup matches what the server returns

The server's `Shipment` has no service, weight or pickup method, so the read-only waybill cannot show "Giao nhanh · 2 kg / Lấy tại nhà · Kho Bình Thạnh". GHN's one service adds 4.000 ₫ per extra kg, as `waybillFee` does for every service but `express`.

**Files:**
- Modify: `app/.superdesign/tools/build_ship_order.py`
- Modify: `app/.superdesign/design-system.md` (§ Đơn bán)
- Regenerate: `app/.superdesign/mockups/ship-order.html`
- Modify: `app/.superdesign/resume.json` (`/cod/ship` version and fingerprints)

- [ ] **Step 1: Edit the builder.** In `SERVICES`, GHN's tuple becomes `("ghn", "Giao chuẩn", "2–3 ngày", 25_000, 4_000, "GHN")`. In `waybill()`, delete the line `{row("local-shipping-outline-rounded", "Giao nhanh · 2 kg", "Lấy tại nhà · Kho Bình Thạnh", attrs=' data-via="linked"')}`.
- [ ] **Step 2: Edit design-system.md.** In § Đơn bán, "GHN one service, Giao chuẩn" becomes "GHN one service, Giao chuẩn, 25.000 ₫ and 4.000 ₫ per extra kg"; "for a linked waybill the service, weight and pickup, " is deleted from the after-creation paragraph.
- [ ] **Step 3: Build and check.**

```bash
cd app/.superdesign/tools && python3 build_ship_order.py > ../mockups/ship-order.html && timeout 400 node check_mockups.mjs ship-order
```
Expected: `{"screen":"ship-order",…,"checks":"passed"}`.

- [ ] **Step 4: Import into the draft and confirm.**

```bash
export PATH=$HOME/.bun/bin:$PATH
superdesign import-design-draft --into 0e8819a9-29ee-4cfd-bcfe-06f9911e4333 --html-file app/.superdesign/mockups/ship-order.html --generated-by claude-opus-5-5 --user-request "App: màn tạo vận đơn (GHTK và tự gửi), sửa mã và Đơn COD làm lại theo mockup Superdesign (phần 4 của spec luồng đơn)"
superdesign get-design --draft-id 0e8819a9-29ee-4cfd-bcfe-06f9911e4333 --json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('currentVersion'), 'Giao nhanh · 2 kg' in d['htmlContent'])"
```
Expected: a version above 24, then `False`. Record that version and the four fingerprints (sha256 of each context file) in `resume.json` under `/cod/ship`, writing to a temp file and renaming.

- [ ] **Step 5: Commit** `design: Đơn bán's waybill shows what the server returns; GHN's per-kg step`.

### Task 2: Services per linked carrier

**Files:**
- Modify: `core/domain/src/main/kotlin/vn/shopnexus/core/domain/Handover.kt`
- Modify: `core/domain/src/main/kotlin/vn/shopnexus/core/domain/DealRules.kt:250`
- Modify: `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/FakeCarrier.kt:45`
- Modify: `core/domain/src/test/kotlin/vn/shopnexus/core/domain/OrderFixtures.kt:117`
- Modify: `feature/orders/src/main/kotlin/vn/shopnexus/feature/orders/ship/ShipOrderViewModel.kt:211`
- Test: `core/domain/src/test/kotlin/vn/shopnexus/core/domain/OrdersTest.kt`, `core/domain/src/test/kotlin/vn/shopnexus/core/domain/DealRulesTest.kt`, `feature/orders/src/test/kotlin/vn/shopnexus/feature/orders/ship/ShipOrderViewModelTest.kt`

**Interfaces:**
- Produces: `val GHN_SERVICES: List<Carrier>`; `fun servicesOf(carrier: ShipCarrier): List<Carrier>` (GHTK → `GHTK_SERVICES`, GHN → `GHN_SERVICES`, others → empty).

- [ ] **Step 1: Failing tests.** In `OrdersTest`:

```kotlin
    /** GHN takes one service on the server (`service_type_id` 2), sent as `standard`. */
    @Test
    fun eachLinkedCarrierHasItsOwnServices() {
        assertThat(servicesOf(ShipCarrier.GHTK).map { it.id }).containsExactly("express", "standard").inOrder()
        assertThat(servicesOf(ShipCarrier.GHN).map { it.id }).containsExactly("standard")
        assertThat(servicesOf(ShipCarrier.SPX)).isEmpty()
        val ghn = servicesOf(ShipCarrier.GHN).single()
        assertThat(ghn.name to ghn.days).isEqualTo("Giao chuẩn" to "2–3 ngày")
        assertThat(waybillFee(ghn, 2_000)).isEqualTo(Vnd(25_000))
        assertThat(waybillFee(ghn, 4_000)).isEqualTo(Vnd(33_000))
    }
```

In `DealRulesTest`, next to the existing linked-shipment tests (use the file's own helpers for a pending deal and an `EngineContext` with `linked = setOf(ShipCarrier.GHTK, ShipCarrier.GHN)`; read the file for their names first):

```kotlin
    @Test
    fun aGhnShipmentTakesOnlyGhnsService() {
        val ctx = EngineContext(carrier = TestCarrier(), linked = setOf(ShipCarrier.GHTK, ShipCarrier.GHN))
        assertThrows(IllegalArgumentException::class.java) {
            DealRules.apply(pendingView(), DealCommand.CreateShipment(NewShipment.Linked(ShipCarrier.GHN, "express", 2_000, Pickup.HOME)), now, ctx)
        }
        val shipped = DealRules.apply(pendingView(), DealCommand.CreateShipment(NewShipment.Linked(ShipCarrier.GHN, "standard", 2_000, Pickup.HOME)), now, ctx)
        assertThat(shipped.currentOrder!!.shipment!!.fee).isEqualTo(Vnd(25_000))
    }
```

In `ShipOrderViewModelTest` (Review Focus 1), with the test's existing setup plus a GHN account (`CarrierAccount(CarrierBrand.GHN, "885412", "Khánh Linh")`), a `SavedStateHandle(mapOf("create.service" to "express"))`, then `onEvent(ShipOrderEvent.LinkedCarrier(ShipCarrier.GHN))`:

```kotlin
        val form = vm.state.value.form!!
        assertThat(form.services.map { it.service.id }).containsExactly("standard")
        assertThat(form.service).isEqualTo("standard")
        vm.onEvent(ShipOrderEvent.Create)
        advanceUntilIdle()
        assertThat(currentShipment()!!.fee).isEqualTo(Vnd(25_000))
```
(name it `ghnSendsItsOwnService`; `currentShipment()` is whatever the file uses to read the deal's shipment; if none, read `deals.deal(id).first()!!.deal.currentOrder!!.shipment`).

- [ ] **Step 2: Run, expect failures.**

```bash
./gradlew :core:domain:testDebugUnitTest --tests '*OrdersTest*' --tests '*DealRulesTest*' :feature:orders:testDebugUnitTest --tests '*ShipOrderViewModelTest*'
```
(`:core:domain` may be a JVM module: use `:core:domain:test` if `testDebugUnitTest` does not exist.) Expected: unresolved `servicesOf`.

- [ ] **Step 3: Implement.** In `Handover.kt` after `GHTK_SERVICES`:

```kotlin
/** GHN's one service on a linked account; the server sends GHN `service_type_id` 2 whatever the app names, so it is `standard`. */
val GHN_SERVICES = listOf(Carrier("standard", "Giao chuẩn", "2–3 ngày", Vnd(25_000)))

/** The services a linked shipment at [carrier] offers; a carrier that cannot be linked offers none. */
fun servicesOf(carrier: ShipCarrier): List<Carrier> = when (carrier) {
    ShipCarrier.GHTK -> GHTK_SERVICES
    ShipCarrier.GHN -> GHN_SERVICES
    else -> emptyList()
}
```
(import `vn.shopnexus.core.model.ShipCarrier`). `DealRules.kt:250` becomes `require(servicesOf(new.carrier).any { it.id == new.service }) { "No service ${new.service} at ${new.carrier.label}" }`. `FakeCarrier.create`: `val fee = servicesOf(carrier).firstOrNull { it.id == service }?.let { waybillFee(it, weightGrams) }`. `OrderFixtures.TestCarrier.create`: `waybillFee(servicesOf(carrier).first { it.id == service }, weightGrams)`. `ShipOrderViewModel.shipmentForm`: `val services = servicesOf(linkedCarrier ?: ShipCarrier.GHTK).map { ServiceQuote(it, grams?.let { g -> waybillFee(it, g) } ?: it.fee) }` (the chosen one already falls back to `services.first()`). Fix the KDoc on `ServiceQuote` ("A linked carrier's service…") and on `DealRules.kt:28`.

- [ ] **Step 4: Run, expect pass** (same command).
- [ ] **Step 5: Commit** `fix(domain): GHN quotes its own service, sent as standard`.

### Task 3: Đơn COD after the mockup

**Files:**
- Modify: `core/ui/src/main/kotlin/vn/shopnexus/core/ui/deal/` (the file with `fun CarrierEvents`), `core/ui/src/main/res/values/strings.xml`
- Modify: `feature/orders/src/main/kotlin/vn/shopnexus/feature/orders/cod/CodOrderScreen.kt`
- Modify: `feature/orders/src/main/res/values/strings.xml`
- Test: `core/ui/src/test/kotlin/vn/shopnexus/core/ui/deal/DealPiecesTest.kt`, `feature/orders/src/test/kotlin/vn/shopnexus/feature/orders/cod/CodOrderScreenTest.kt`

**Interfaces:**
- Produces: `fun CarrierEvents(carrier: ShipCarrier, events: List<CarrierEvent>, now: Instant, zone: ZoneId, modifier: Modifier = Modifier)`, title "%1$s báo" (`deal_ui_carrier_says`), newest first, the newest dot `primary` and the rest `outlineVariant`. Task 4 calls it.
- Produces: `internal fun SectionTitle(text: String)` in `OrderParts.kt`, the `titleSmall` `primary` heading at 32 dp start inset that "Giao đến" already uses (lift it out of `GroupedList(title = …)` callers only where a heading stands over a non-grouped card). Task 4 calls it.

What changes, against the mockup `cod-order`:
1. Order of blocks: hero; the state's card (cancel sentence when pending; Tin ghi and the refuse sentence when shipped; stars when completed and unrated); the four steps; "Vận đơn" (title) over the existing `ShipmentCode` card when the order has a shipment (shipped, completed, failed); `CarrierEvents` while shipped or completed with events; "Giao đến"; item and seller; "Tiền" unless cancelled; the order number.
2. Failed hero line: `Symbol.Storefront` · "Tin đã mở bán lại" (`orders_fact_relisted`), not the code.
3. Bar: pending "Hủy đơn" (tonal); shipped the report text button ("Báo chưa nhận hàng" or "Xem yêu cầu") and "Đã nhận hàng" (filled, `Symbol.PackageTwo`); failed (`canBuyAgain`) a 48 dp tonal chat icon button and "Mua lại" (filled, `Symbol.ShoppingBag`), checked before the report branch; completed by the system within the report window: the report text button alone; else none. `Bar` gains `onChat: () -> Unit`, wired to `onNavigate(ChatRoute(view.deal.id.value))`.

- [ ] **Step 1: Failing tests.** `DealPiecesTest.carrierEventsComeOldestFirst` becomes:

```kotlin
    @Test
    fun carrierEventsComeNewestFirstUnderTheCarriersName() {
        val events = listOf(CarrierEvent("Shipper đang giao", now.minusSeconds(60)), CarrierEvent("Đã lấy hàng tại Quận 10", now.minusSeconds(7200)))
        compose.setContent { ShopNexusTheme { CarrierEvents(ShipCarrier.GHTK, events, now, VN_ZONE) } }
        val tops = listOf("Shipper đang giao", "Đã lấy hàng tại Quận 10").map { compose.onNodeWithText(it).fetchSemanticsNode().boundsInRoot.top }
        assertThat(tops[0]).isLessThan(tops[1])
        compose.onNodeWithText("GHTK báo").assertExists()
    }
```

In `CodOrderScreenTest` add:

```kotlin
    @Test
    fun theWaybillHasItsTitleAndTheCarrierSpeaksUnderIt() {
        show(state(at(OrderJump.SHIPPED)))
        seen("Vận đơn")
        compose.onNodeWithText("GHTK báo").performScrollTo().assertExists()
        gone("Bên vận chuyển báo")
    }

    @Test
    fun aFailedOrderSaysTheListingIsOnSaleAndBuysAgainBesideChat() {
        show(state(at(OrderJump.FAILED)))
        seen("Giao không thành")
        seen("Tin đã mở bán lại")
        compose.onNodeWithContentDescription("Nhắn Hoàng Nam").assertExists()
        compose.onNodeWithText("Mua lại").performClick()
        assertThat(events).contains(CodOrderEvent.BuyAgain)
    }

    /** Review Focus 3: a ticket on the failed order never hides "Mua lại". */
    @Test
    fun aFailedOrderWithATicketStillBuysAgain() {
        show(state(at(OrderJump.FAILED)).copy(report = TicketId("t-nam")))
        compose.onNodeWithText("Mua lại").assertExists()
        gone("Xem yêu cầu")
    }

    @Test
    fun aCompletedOrderKeepsTheCarriersReports() {
        show(state(at(OrderJump.COMPLETED)))
        compose.onNodeWithText("GHTK báo").performScrollTo().assertExists()
    }
```
(the chat button's content description is `deal_ui_message` "Nhắn %1$s" from `core/ui`; check the seller's name in the `d-nam` fixture and use it.) Update `aFailedOrderIsBoughtAgain` if it asserts the old hero line.

- [ ] **Step 2: Run, expect failures.**

```bash
./gradlew :core:ui:testDebugUnitTest --tests '*DealPiecesTest*' :feature:orders:testDebugUnitTest --tests '*CodOrderScreenTest*'
```

- [ ] **Step 3: Implement `CarrierEvents`.** Add `<string name="deal_ui_carrier_says">%1$s báo</string>` to `core/ui` strings and delete `deal_ui_carrier` once nothing reads it. The body:

```kotlin
/** What [carrier] reported about the parcel, newest first under "<carrier> báo"; the newest behind a primary dot, the older behind outlineVariant. */
@Composable
fun CarrierEvents(carrier: ShipCarrier, events: List<CarrierEvent>, now: Instant, zone: ZoneId, modifier: Modifier = Modifier) {
    val c = MaterialTheme.colorScheme
    val today = now.atZone(zone).toLocalDate()
    Column(modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            stringResource(R.string.deal_ui_carrier_says, carrier.label),
            style = MaterialTheme.typography.titleSmall,
            color = c.primary,
            modifier = Modifier.semantics { heading() },
        )
        events.sortedByDescending { it.at }.forEachIndexed { i, event ->
            val time = event.at.atZone(zone)
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(8.dp).background(if (i == 0) c.primary else c.outlineVariant, CircleShape))
                Text(event.text, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
                Text((if (time.toLocalDate() == today) HOUR else DAY_HOUR).format(time), style = MaterialTheme.typography.bodySmall, color = c.onSurfaceVariant)
            }
        }
    }
}
```

- [ ] **Step 4: Implement the screen.** In `CodOrderScreen.kt`:
  - `Body`: after `OrderTimeline(…)`:

```kotlin
    if (shipment != null) {
        SectionTitle(stringResource(R.string.orders_waybill))
        ShipmentCode(shipment, copy, card.padding(vertical = 8.dp))
    }
    shipment?.events?.takeIf { it.isNotEmpty() && order.status in setOf(OrderStatus.SHIPPED, OrderStatus.COMPLETED) }
        ?.let { CarrierEvents(shipment.carrier, it, state.now, VN_ZONE, card.padding(16.dp)) }
```
  replacing the two lines that drew events and the code. Add `<string name="orders_waybill">Vận đơn</string>`.
  - `codHero` FAILED: `Hero(MaterialShapes.Gem, MilestoneTone.NEUTRAL, Symbol.Undo, stringResource(R.string.orders_hero_failed), listOf(Symbol.Storefront to stringResource(R.string.orders_fact_relisted)))`.
  - `Bar(state, onEvent, onChat)`:

```kotlin
@Composable
private fun Bar(state: CodOrderUiState, onEvent: (CodOrderEvent) -> Unit, onChat: () -> Unit, seller: String) {
    val order = state.order ?: return
    if (!state.current) return
    val busy = state.pending
    when {
        order.status == OrderStatus.PENDING -> DockedActionBar {
            TonalAction(Symbol.Cancel, stringResource(R.string.orders_cancel), !busy) { onEvent(CodOrderEvent.AskCancel) }
        }
        order.status == OrderStatus.SHIPPED -> DockedActionBar(verticalAlignment = Alignment.CenterVertically) {
            ReportAction(state, onEvent)
            PrimaryAction(Symbol.PackageTwo, stringResource(R.string.orders_received), enabled = true, busy = busy) { onEvent(CodOrderEvent.AskReceived) }
        }
        // A failed order is bought again; a ticket from its parcel lives in Hỗ trợ and never takes this place.
        state.canBuyAgain -> DockedActionBar {
            FilledTonalIconButton(onClick = onChat, modifier = Modifier.size(48.dp)) { SymbolIcon(Symbol.Chat, stringResource(UiR.string.deal_ui_message, seller)) }
            PrimaryAction(Symbol.ShoppingBag, stringResource(R.string.orders_buy_again), enabled = true, busy = busy) { onEvent(CodOrderEvent.BuyAgain) }
        }
        state.report != null || state.mayReport -> DockedActionBar(verticalAlignment = Alignment.CenterVertically) { ReportAction(state, onEvent) }
    }
}
```
  and the scaffold's `bottomBar = { Bar(state, onEvent, { view?.let { onNavigate(ChatRoute(it.deal.id.value)) } }, view?.counterpart?.name.orEmpty()) }`.
  - Move the private "Giao đến" title into `SectionTitle` in `OrderParts.kt`:

```kotlin
/** A titleSmall heading in primary over a card that is not a grouped list, inset as GroupedList's titles are. */
@Composable
internal fun SectionTitle(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 32.dp, end = 32.dp, top = 24.dp).semantics { heading() },
    )
}
```
  (match the start inset to `GroupedList`'s title by reading `GroupedList.kt`; use that value if it differs.)

- [ ] **Step 5: Run, expect pass**; then the whole `:feature:orders:testDebugUnitTest` and `:core:ui:testDebugUnitTest`.
- [ ] **Step 6: Commit** `feat(orders): Đơn COD after the part 4 mockup`.

### Task 4: Đơn bán after the mockup

**Files:**
- Modify: `feature/orders/src/main/kotlin/vn/shopnexus/feature/orders/ship/ShipOrderViewModel.kt`
- Modify: `feature/orders/src/main/kotlin/vn/shopnexus/feature/orders/ship/ShipOrderScreen.kt`
- Modify: `feature/orders/src/main/res/values/strings.xml`
- Test: `feature/orders/src/test/kotlin/vn/shopnexus/feature/orders/ship/ShipOrderViewModelTest.kt`, `ShipOrderScreenTest.kt`

**Interfaces:**
- Consumes: `servicesOf` (Task 2), `CarrierEvents(carrier, …)`, `SectionTitle` (Task 3).
- Produces: `ShipOrderUiState.payout: CarrierAccount?` — the account the COD goes to: the shipment's carrier's account once shipped, else the linked tab's account, else the chosen manual chip's account.

View model changes:
1. `shipmentForm`: the mode falls back when the saved one cannot be used — `val mode = if (editing) ShipmentMode.MANUAL else local.mode?.takeIf { it == ShipmentMode.MANUAL || account != null } ?: if (account != null) ShipmentMode.LINKED else ShipmentMode.MANUAL`.
2. The manual chip defaults to the first linked carrier: in `shipmentForm`, `val carrier = local.carrier?.takeIf { it in carriers } ?: carriers.firstOrNull()`, used for `carrier`, `canSubmit` and `confirmable`; in the view model, `lookup()` reads `state.value.form?.carrier ?: local.value.carrier` instead of `local.value.carrier`, and `onEvent(Mode(MANUAL))` calls `lookup()` after the update.
3. `payout`: in `shipOrderUiState`, `val brand = order?.shipment?.carrier ?: form?.let { if (it.mode == ShipmentMode.LINKED) it.linkedCarrier else it.carrier }`; `payout = setup.accounts.firstOrNull { it.brand.name == brand?.name }`.

Screen, against the mockup `ship-order`:
1. Pending, a carrier linked: hero; "Giao đến" grouped address; "Gửi bằng" (`SectionTitle`) over `ToggleGroup` with one option per `form.carriers` (label `carrier.label`, no icon) then "Tự gửi" (`orders_manual_tab`), label "Gửi bằng"; selected index = position of `linkedCarrier` while `mode == LINKED`, else the last; under it a `bodySmall` `onSurfaceVariant` line at 32 dp: linked "Tạo vận đơn trên tài khoản %1$s %2$s của bạn" (`orders_linked_line`, brand and code), manual "Đã tạo đơn trong app của hãng? Nhập mã vận đơn" (`orders_manual_line`).
2. Linked card (surfaceContainer, 28 dp): `FilledField` "Khối lượng" with `suffix = "kg"`; "Dịch vụ" (`titleSmall` onSurface) and the service `Choice` rows with the fee; "Cách lấy hàng" with "Lấy tại nhà" / "Shipper tới lấy" and "Gửi tại bưu cục" / "Bạn mang ra bưu cục gần nhất"; "Lấy hàng tại" ("Gửi từ" when `pickup == POST_OFFICE`), then `bodySmall` "Kho trên %1$s" over the points and "Địa chỉ của bạn" over the addresses, an empty group hidden.
3. Manual card: `FilterPill` per linked carrier; `FilledField` "Mã vận đơn" with `error = "%1$s không có mã này"` when `NotFound`; under it the preview: `Reading` a 18 dp progress and "Đang hỏi %1$s…"; `Found` a `surfaceContainerHigh` 16 dp card titled "%1$s báo" with three icon rows (`Symbol.Person` "recipient · district", `Symbol.Payments` "COD …", `Symbol.LocalShipping` "<status> · phí ship <fee>", or the status alone with no fee), then the failed line in `error` or the mismatch line with a `tertiary` `Symbol.Error`; `Failed` the load-failed line. Under the card, text buttons: `CarrierAskButton` and, while a linkable carrier (GHTK, GHN) is missing from `form.carriers`, "Liên kết %1$s" (`orders_link_brand`) to `CodSetupRoute(CodSetupOrigin.TASKS.name)`.
4. Pending, nothing linked: in place of 1–3 a card "Chưa liên kết hãng vận chuyển" (`titleSmall`), "Liên kết GHTK hoặc GHN để tạo đơn và để ShopNexus đọc được mã vận đơn." (`bodyMedium` onSurfaceVariant), and a tonal "Liên kết hãng" button with `Symbol.Link` to `CodSetupRoute(CodSetupOrigin.TASKS.name)`. No bottom bar.
5. After creation: "Vận đơn" grouped list — a row with `Symbol.ReceiptLong`, title "%1$s · %2$s" (carrier label, code), supporting "Tạo trên tài khoản %1$s" (account code) for linked or "Tự gửi · nhập từ app %1$s" for manual, and a 48 dp copy icon button ("Sao chép mã vận đơn") that copies the code; while `canEditTrackingCode(order)` and current, a second row `Symbol.Edit` "Nhập nhầm mã? Sửa được tới khi hãng giao xong" with a "Sửa mã" text button sending `EditCode`. Then `CarrierEvents(shipment.carrier, …)` while shipped with events.
6. Then item and buyer, "Tiền" (the payout row from `state.payout`: "Tiền COD về tài khoản %1$s" over "%1$s %2$s · đứng tên bạn"; no row when null; the fee row reads the shipment's fee, else the linked quote, else the manual preview's fee, else "Hãng báo sau"), money notes, the order number.
7. Sửa mã: `FullWidthSheet(title = "Sửa mã vận đơn", dismissible = !state.pending, onDismiss = { onEvent(CloseEdit) })` holding the manual fields and a full-width filled "Lưu mã" (`Symbol.Check`, enabled by `form.canSubmit`, busy by `state.pending`) sending `SaveCode`. The bottom bar shows nothing while editing.
8. Bar: pending with a carrier linked — chat icon button and "Tạo đơn" (`Symbol.ReceiptLong`) or "Xác nhận" (`Symbol.Check`) for manual; otherwise none.

Strings to add (`feature/orders`): `orders_send_with` "Gửi bằng", `orders_linked_line` "Tạo vận đơn trên tài khoản %1$s %2$s của bạn", `orders_manual_line` "Đã tạo đơn trong app của hãng? Nhập mã vận đơn", `orders_weight` becomes "Khối lượng", `orders_kg` "kg", `orders_service` "Dịch vụ", `orders_pickup_how` "Cách lấy hàng", `orders_pickup_home_sub` "Shipper tới lấy", `orders_pickup_post_office_sub` "Bạn mang ra bưu cục gần nhất", `orders_pickup_at` "Lấy hàng tại", `orders_send_from` "Gửi từ", `orders_carrier_reading` "Đang hỏi %1$s…", `orders_preview_person` "%1$s · %2$s", `orders_preview_cod` "COD %1$s", `orders_preview_status_fee` "%1$s · phí ship %2$s", `orders_parcel_pending` "Chờ lấy hàng", `orders_parcel_in_transit` "Đang giao", `orders_parcel_delivered` "Đã giao", `orders_parcel_failed` "Giao không thành", `orders_link_brand` "Liên kết %1$s", `orders_unlinked_title` "Chưa liên kết hãng vận chuyển", `orders_unlinked_text` "Liên kết GHTK hoặc GHN để tạo đơn và để ShopNexus đọc được mã vận đơn.", `orders_link_any` "Liên kết hãng", `orders_carrier_code` "%1$s · %2$s", `orders_made_on_account` "Tạo trên tài khoản %1$s", `orders_typed_from_app` "Tự gửi · nhập từ app %1$s", `orders_edit_hint` "Nhập nhầm mã? Sửa được tới khi hãng giao xong", `orders_edit_title` "Sửa mã vận đơn", `orders_payout_to` "Tiền COD về tài khoản %1$s", `orders_copy_waybill` "Sao chép mã vận đơn". Delete what nothing reads afterwards: `orders_carrier_title`, `orders_your_account`, `orders_linked_tab`, `orders_manual_tab_sub`, `orders_link_carrier`, `orders_payout_bank`, `orders_preview` (lint's `UnusedResources` finds the rest).

- [ ] **Step 1: Failing view-model tests** in `ShipOrderViewModelTest` (use the file's own builders for the view model, setup and deal; read its first 95 lines):

```kotlin
    /** Review Focus 2. */
    @Test
    fun aLinkedDraftWithNoAccountOpensManual() = runTest {
        val vm = viewModel(accounts = emptyList(), saved = SavedStateHandle(mapOf("create.mode" to "LINKED")))
        advanceUntilIdle()
        assertThat(vm.state.value.form!!.mode).isEqualTo(ShipmentMode.MANUAL)
    }

    /** Review Focus 4. */
    @Test
    fun manualStartsOnTheFirstLinkedCarrier() = runTest {
        val vm = viewModel()
        advanceUntilIdle()
        vm.onEvent(ShipOrderEvent.Mode(ShipmentMode.MANUAL))
        vm.onEvent(ShipOrderEvent.TrackingCode("S1.A1.1"))
        advanceTimeBy(LOOKUP_DELAY_MILLIS + 1)
        advanceUntilIdle()
        val form = vm.state.value.form!!
        assertThat(form.carrier).isEqualTo(ShipCarrier.GHTK)
        assertThat(form.preview).isInstanceOf(CodePreview.Found::class.java)
        assertThat(form.canSubmit).isTrue()
    }

    @Test
    fun theCodGoesToTheShipmentsAccount() = runTest {
        val vm = viewModel()
        advanceUntilIdle()
        assertThat(vm.state.value.payout?.code).isEqualTo("S55163")
        vm.onEvent(ShipOrderEvent.Create)
        advanceUntilIdle()
        assertThat(vm.state.value.payout?.brand).isEqualTo(CarrierBrand.GHTK)
    }
```
(adapt `viewModel(...)` to the file's helper; if it takes no `accounts`/`saved`, add those parameters to it.)

- [ ] **Step 2: Failing screen tests** in `ShipOrderScreenTest`. Replace `aPendingOrderOffersGhtkAndTheManualWayAndNothingTheSpecDropped`, `withNoCarrierLinkedTheFormLinksToTheSetup`, `eachLinkedAccountIsAWayToShip`, `thePreviewSaysWhatTheCarrierKnowsAndADifferentCodWarns` with:

```kotlin
    @Test
    fun aPendingOrderOffersATabPerAccountAndTuGuiAndNothingTheSpecDropped() {
        show(state(pending))
        seen("Gửi bằng")
        seen("GHTK")
        seen("Tự gửi")
        seen("Tạo vận đơn trên tài khoản GHTK S55163 của bạn")
        seen("Kho trên GHTK")
        seen("Địa chỉ của bạn")
        listOf("Khác", "Phí ship (₫)", "Chụp hàng", "Xác nhận gửi").forEach(::gone)
        compose.onNodeWithText("Tạo đơn").assertIsEnabled()
    }

    @Test
    fun withNoCarrierLinkedTheCardLinksToTheSetup() {
        show(state(pending, with = ShipSetup()))
        seen("Chưa liên kết hãng vận chuyển")
        gone("Gửi bằng")
        compose.onNodeWithText("Tạo đơn").assertDoesNotExist()
        compose.onNodeWithText("Liên kết hãng").performScrollTo().performClick()
        assertThat(pushed).containsExactly(CodSetupRoute("TASKS"))
    }

    @Test
    fun eachLinkedAccountIsATab() {
        val ghn = CarrierAccount(CarrierBrand.GHN, "885412", "Khánh Linh")
        show(state(pending, with = setup.copy(accounts = setup.accounts + ghn)))
        compose.onNodeWithText("GHN").performClick()
        compose.onNodeWithText("Tự gửi").performClick()
        assertThat(events).containsExactly(ShipOrderEvent.LinkedCarrier(ShipCarrier.GHN), ShipOrderEvent.Mode(ShipmentMode.MANUAL)).inOrder()
        gone("Liên kết GHN")
    }

    @Test
    fun thePreviewSaysWhatTheCarrierKnowsAndADifferentCodWarns() {
        val parcel = Parcel("Đ••• H•••", "Phú Nhuận", Vnd(450_000), ShipmentStatus.PENDING_PICKUP, Vnd(22_000))
        val local = ShipOrderLocal(
            mode = ShipmentMode.MANUAL,
            carrier = ShipCarrier.GHTK,
            trackingCode = "S1.A1",
            preview = CodePreview.Found(parcel, codMismatch = true),
            previewFor = ShipCarrier.GHTK to "S1.A1",
        )
        show(state(pending, local))
        seen("GHTK báo")
        seen("Đ••• H••• · Phú Nhuận")
        seen("COD 450.000 ₫")
        seen("Chờ lấy hàng · phí ship 22.000 ₫")
        seen("COD trên đơn 450.000 ₫, khác giá đã chốt 350.000 ₫")
        seen("Liên kết GHN")
        compose.onNodeWithText("Xác nhận").performClick()
        assertThat(events).containsExactly(ShipOrderEvent.Create)
    }

    @Test
    fun theWaybillNamesItsAccountAndCopies() {
        show(state(at(OrderJump.SHIPPED)))
        seen("Vận đơn")
        seen("Tạo trên tài khoản S55163")
        compose.onNodeWithContentDescription("Sao chép mã vận đơn").assertExists()
        seen("Tiền COD về tài khoản GHTK")
    }

    @Test
    fun suaMaOpensASheetThatSaves() {
        show(state(manual, ShipOrderLocal(editing = true, carrier = ShipCarrier.GHTK, trackingCode = "S1.A1.031245678")))
        seen("Sửa mã vận đơn")
        compose.onNode(hasText("Lưu mã") and hasClickAction()).assertExists()
        compose.onNodeWithText("Tạo đơn").assertDoesNotExist()
    }

    /** Review Focus 5. */
    @Test
    fun theEditSheetStaysWhileSaving() {
        show(state(manual, ShipOrderLocal(editing = true, pending = true, carrier = ShipCarrier.GHTK, trackingCode = "S1.A1.031245678")))
        compose.onNodeWithContentDescription("Đóng").assertIsNotEnabled()
    }
```
Keep `aManualShipmentOffersSuaMaAndALinkedOneDoesNot` (its "Sửa mã" now sits in the second waybill row) and `aLinkedShipmentHasNoSuaMa`. `aCodeTheCarrierDoesNotKnowCannotBeConfirmed` keeps its assertions (the error line is the field's).

- [ ] **Step 3: Run, expect failures.** `./gradlew :feature:orders:testDebugUnitTest --tests '*ShipOrder*'`
- [ ] **Step 4: Implement** the three view-model changes and the screen above. Keep `Choice` and `PickupGroup`; `LinkedFields` takes the new headings; `ManualFields` becomes a `@Composable private fun ColumnScope.ManualFields(form: ShipmentForm, price: Vnd, onEvent: (ShipOrderEvent) -> Unit)` used by both the card and the sheet; `Preview` draws the new card. Delete the inline editing card in `Body` and the editing branch of `Bar`.
- [ ] **Step 5: Run, expect pass**; then `./gradlew :feature:orders:check` (tests, lint, detekt, spotless) and fix what it reports in files this task touched.
- [ ] **Step 6: Commit** `feat(orders): Đơn bán after the part 4 mockup`.

### Task 5: Walks, gate and the checklist

**Files:**
- Modify (only if they fail): `app/src/test/kotlin/dev/shopnexus/app/SellWalkTest.kt`, `DealsWalkTest.kt`, `SliceTest.kt`
- Modify: `~/shopnexus/checklist.md` (the part 4 line and the GHN line)

- [ ] **Step 1: Gate**, in the background:

```bash
. ~/.local/share/shopnexus/android-env.sh && timeout 2700 ./gradlew --continue :app:assembleDebug :core:domain:check :core:data:check :core:ui:check :feature:orders:check :feature:deal:check :feature:support:check :app:testDebugUnitTest > /tmp/claude-1000/gate-order-screens.log 2>&1; grep -E "FAILED|BUILD" /tmp/claude-1000/gate-order-screens.log
```
Expected: `BUILD SUCCESSFUL`, or failures only in tests that read the old copy (fix those: the walks' `shipWalk` and `codSaleWalk` click "Tạo đơn" and wait for "Chờ GHTK lấy hàng", which still hold). The 3 `:feature:me` failures on `main` are not this plan's.
- [ ] **Step 2: Checklist.** In `~/shopnexus/checklist.md`, the line "App: màn tạo vận đơn …" becomes `[x]` with "theo mockup `ship-order` và `cod-order` (14/11/2026)"; the GHN services line becomes `[x]`. Run the prose checker on the changed lines.
- [ ] **Step 3: Commit** in the worktree `test: walks on the part 4 order screens` if Step 1 changed tests; the checklist is in the root repo and stays uncommitted for the user.
