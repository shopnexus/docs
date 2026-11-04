# Mockup fidelity pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close the differences between app2 and its mockups that the COD-only review left, and bring the mockups that still show the old model in line with the app.

**Architecture:** Each task reads the named mockup builder (`app2/.superdesign/tools/`), changes the shared component or screen, pins copy and structure with Compose semantics tests where they can fail, and re-records the goldens after looking at every compare image.

**Tech Stack:** Kotlin, Jetpack Compose, Material 3 Expressive, Robolectric, Roborazzi; Python mockup builders, Superdesign CLI.

**Spec:** the mockups are the spec: `app2/.superdesign/tools/build_*.py`, `common.py`, `order_kit.py` (state at `app2` main `9523994`), and `specs/2026-10-17-app2-cod-only-design.md` where they disagree.

## Global Constraints

- Gate: `timeout 1500 tmp/gate.sh tmp/work/<log>` (lint, unit tests, `verifyRoborazziDebug`), green after every task.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; messages pass `ai-tells.py --stats` with 0 hits.
- Scratch in `app2/tmp`; never `sh -c`; branch `mockup-fidelity`, fast-forward into `main` at the end.
- A behaviour the spec gives (one-line finished console, "Mẹo kiểm {noun}", "Rút ghi nhận", "Xem đơn" in Chat) wins over a mockup that leaves it out.

## Review Focus

1. Shared components (Timeline, CarrierEvents, RatingRow/stars) change on every page that uses them: Đơn COD, Đơn bán, Chat, Đơn hàng, Điểm uy tín.
2. Large text (font 1.3) with the new trailing times and amounts: no clipped text.
3. Dark and dynamic variants of every changed golden.
4. Copy that moves between title and supporting lines keeps its TalkBack meaning.
5. Mockup edits keep `check_mockups.mjs` green and are published to the same drafts.

---

### Task 1: Order pages follow order_kit

**Files:** `core/designsystem/.../component/Timeline.kt` (the time trails the label on the same row, `bodySmall` onSurfaceVariant), `core/ui/.../deal/CarrierEvents.kt` (title and icon in primary, a primary 8 dp dot per event, oldest first), `feature/orders/.../cod/CodOrderScreen.kt` (money rows carry the amount in the title: "Đã trả phí ship 22.000 ₫", "Trả khi nhận 3.800.000 ₫"; the seller's stats read "4,7 ★ · 12 đã bán"; the refused page's REFUSED_STAT sentence sits in a surfaceContainer card; the placed page shows the HANDOVER sentence in a card without the "Hạn gửi hàng" heading; the buyer's timeline keeps "Gửi hàng" current while the parcel travels), the same rows on `ship/ShipOrderScreen.kt` where `build_ship_order.py` draws them. Tests: `DealPiecesTest.carrierEventsComeOldestFirst`, `CodOrderScreenTest`, `ShipOrderScreenTest`, goldens `order-cod-*`, `order-ship-*`, `deal-pieces-*`, `order-components-*`.

### Task 2: Given ratings are filled stars

**Files:** the Đơn COD reviewed hero and line, Chat's "{n} sao cho …" event line, the rules sheet's star rows, wherever a given rating is drawn with `Symbol.Star` outline (`filled = true`). Tests: one semantics or pixel-share test per place where it can fail; goldens.

### Task 3: Chat details

**Files:** `feature/deal/.../chat/{Console,Composer,Thread}.kt` against `build_chat.py`: the fold chevron points down while the console is open, the disabled send button is transparent, "Trả giá" and "Đồng ý" carry their icons, the counter's hours sit at the right, price pills read the full amount ("5.100.000 ₫"), every amount carries "₫". Tests: `ChatScreenTest`, `ChatSidesTest`, goldens `chat-*`.

### Task 4: Đơn hàng rows

**Files:** `feature/orders/.../list/OrdersScreen.kt` against `build_orders.py:86-93`: price trailing the title, one-line title, "·" before COD. Tests: `OrdersScreenTest`, goldens `orders-*`.

### Task 5: Đăng tin, Chào mừng, Listing detail, Giao COD

**Files:** Đăng tin section titles at the mockup's large onSurface size (`build_sell.py:245`), the COD_SELLER note icon on Đăng tin and Kiểm tra tin (bank, `build_sell.py:250`), Chào mừng's tagline without "!" (`build_welcome.py:47`), Listing detail's top (`build_detail.py:112-140`), Giao COD's item card (`build_cod_checkout.py`). Tests and goldens per screen.

### Task 6: Mockups that still show the old model

**Files:** `build_rep.py` (no cancel rules; the history's cancelled order becomes "Minh Thư đánh giá 2 sao −15"), `build_tasks.py:104` (bio hint "Bạn bán gì, ở khu nào"), `design-system.md` (finished steps keep their icon; the Chat console after the handshake is COD). Run `check_mockups.mjs`, publish the changed drafts with `tools/publish.py`, look at the published drafts.
