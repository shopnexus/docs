# app: Gần bạn as a tab — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Home's feed becomes tabs (Dành cho bạn · Gần bạn · Mới nhất) with recent-search chips, a "Vì bạn đã xem gần đây" rail, the carousel only when signed out, card places beyond 10 km, and every "quanh bạn" pitch gone from the app's copy.

**Architecture:** `HomeFeed` gains `signedIn`, `newest`, `viewed` and `recent`, and loses `interests`; the fake builds the three feeds from the pool (Dành cho bạn nationwide, Gần bạn within the radius, Mới nhất by date). `ListingSummary` gains `place`; one formatter (`whereLabel`) says the distance under 10 km and the place beyond. Home's list is rebuilt around a tab row whose Gần bạn tab carries the area chip and the radius sheet. Copy changes are string edits with their tests.

**Tech Stack:** Kotlin, Jetpack Compose (Material 3 Expressive), Hilt, kotlinx.serialization, coroutines, Robolectric, Truth, Turbine.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-14-nearby-as-a-tab-design.md`. Designs: Superdesign drafts "Home · Khám phá" (7cdedb6f, v27) and "Home · Chưa đăng nhập" (96819cec), built by `app/.superdesign/tools/build_home.py`.

Repo `~/shopnexus/app`, branch `feat/nearby-tab`. `export JAVA_HOME=$HOME/.local/opt/jdk-21`. Tests: `./gradlew --console=plain :<module>:testDebugUnitTest` (no `-q` in `task-done`). Static: `./gradlew -q spotlessApply`, `detekt` (7 findings on base are known), `:<module>:lintDebug`. Stop Gradle and Kotlin daemons after the work. Commits carry no `Co-Authored-By`.

## Global Constraints

- No screen says "quanh bạn", "gần bạn" as a pitch, or "N … ở gần"; "Gần bạn" survives only as the tab's name and the "Gần bạn nhất" sort.
- A card's place: `distanceKm < 10` → "4,2 km"; otherwise `place` when the listing has one, else the distance.
- Nearness never filters Dành cho bạn or Mới nhất; only the Gần bạn tab keeps the radius.
- The carousel shows only when signed out; recent searches and the viewed rail only when signed in.
- The debug panel's long press moves to the bell.
- UI shows results, never AI narration.

## Review Focus

- A signed-out viewer: carousel, categories, tabs; no recent chips, no rail; the bell still opens Thông báo (which asks to sign in).
- Switching tabs keeps each tab's scroll and does not reload the feed; pull to refresh puts the new listings at the top of the tab that is open and says "Có N tin mới".
- A viewer with no recent searches and no viewed history: no empty chip row and no rail.
- A far listing opened from Dành cho bạn shows its detail (the pool has it), and Saved/compare sheets show its place, not "640,0 km".
- Font scale 1.3: the tab row and the chip row do not clip.

---

### Task 1: The card's place

**Files:** `core/model/.../Listing.kt` (`ListingSummary.place: String? = null`), `core/designsystem/.../component/Price.kt` (`whereLabel`), `core/designsystem/.../component/ListingCard.kt:165`, `core/ui/.../Sheets.kt:82`, `feature/discover/.../detail/DetailSections.kt`, `feature/saved/.../SavedScreen.kt`, `feature/saved/.../CompareSheet.kt`. Test: `core/designsystem/src/test/.../WhereLabelTest.kt`.

- [ ] Write `WhereLabelTest`: `whereText(9.9, "Đà Nẵng") == "9,9 km"`, `whereText(10.0, "Đà Nẵng") == "Đà Nẵng"`, `whereText(640.0, null) == "640,0 km"`, `whereText(0.6, null) == "0,6 km"`. Run → compile error.
- [ ] Add `const val NEAR_KM = 10.0`, the pure `fun whereText(km: Double, place: String?): String` (uses the same `"%.1f"` with a comma and " km"), and `@Composable fun whereLabel(listing: ListingSummary): String` in `Price.kt`; keep `distanceLabel` for the places that mean the distance itself (the Khoảng cách filter).
- [ ] Replace `distanceLabel(listing.distanceKm)` with `whereLabel(listing)` wherever it labels a listing (the five files above). Run the module tests of `core:designsystem`, `core:ui`, `feature:discover`, `feature:saved` → PASS.
- [ ] Commit `feat(ui): a card says the distance under 10 km and the seller's place beyond`.

### Task 2: The fake's three feeds, recent searches and viewed rail

**Files:** `core/model/.../Home.kt` (`HomeFeed`), `core/model/.../Home.kt` (`ViewedRail`), `core/data/.../Repositories.kt` (`SearchRepository.forget`), `core/data/.../fake/Fixtures.kt` (`home()`), `.../fake/Seeds.kt` (`HomeSeed`), `.../fake/FakeHomeRepository.kt`, `.../fake/FakeSearchRepository.kt`, `resources/fixtures/home.json`, `resources/fixtures/pool.json`. Tests: `core/data/src/test/.../FakeHomeRepositoryTest.kt` (new), `FixturesTest`.

- [ ] Model: `HomeFeed(district, searchHints, hero, categories, nearby, forYou, newest, viewed: ViewedRail?, recent: List<RecentChip>, signedIn: Boolean, unreadNotifications)`; `ViewedRail(label: String, categoryKey: String, listings: List<ListingSummary>)`; `RecentChip(query: String, newCount: Int = 0)`. `interests` goes.
- [ ] Pool: five far listings (`p-far-iphone15` Hà Nội 1140 km, `p-far-a7` Đà Nẵng 610 km, `p-far-xm4` Cần Thơ 140 km, `p-far-r1` Củ Chi 28 km, `p-far-armchair` Huế 640 km), each with `place`, kinds whose searches no test counts (camera, headphones, motorbike, furniture, phone). Seed `home.json`: `forYou` mixes them in (positions 1, 4, 6, 8, 9 as in the design), `newest` (six ids), `viewed` ("Xe đạp", `vehicles`, four bike ids).
- [ ] Test `FakeHomeRepositoryTest`: signed in, `forYou` holds the far listings although the radius is 10 km, `nearby` holds only `distanceKm <= radius`, `recent` lists the history with the followed search's count, `viewed` is present, `signedIn` is true; signed out, `recent` is empty, `viewed` is null, `signedIn` false; `refresh()` puts the fresh listings at the top of `forYou`, `nearby` and `newest`. Run → FAIL.
- [ ] Implement in `FakeHomeRepository.feed()`: filter only `nearby` by the radius; `recent` from the world's search history (first 6), the count from the matching followed search's `newCount`; `viewed` and `recent` only when `s.session == SIGNED_IN`. `SearchRepository.forget(query)` and its fake (drops one history entry). Run → PASS.
- [ ] Fix `FixturesTest`/`Stage*` tests that count the pool or the home seed. Commit `feat(data): Home's three feeds, recent searches and the viewed rail in the fake`.

### Task 3: Home in tabs

**Files:** `feature/discover/.../home/HomeScreen.kt`, `HomeTop.kt` (`LocationRow` → `BellButton`; `RecentChips`; `ViewedRail`; `FeedTabs`; `AreaChip`), `HomeViewModel.kt`, `res/values/strings.xml`. Tests: `HomeScreenTest`, `HomeViewModelTest`.

- [ ] Tests first:
  - Screen: the signed-in feed shows "Dành cho bạn", "Gần bạn", "Mới nhất" tabs and no carousel; tapping "Gần bạn" shows "Bình Thạnh · 10 km", whose tap opens the radius sheet and a pick sends `HomeEvent.Radius`; a signed-out feed shows the carousel and no "Vì bạn đã xem gần đây"; a recent chip opens `SearchResultsRoute(query)` and its ✕ sends `HomeEvent.ForgetSearch(query)`; the rail's ✕ sends `HomeEvent.HideViewed`; the rail title opens `CategoryRoute`; the bell opens Thông báo. Drop the interest tests and the area-chip-at-top tests.
  - ViewModel: `loadsTheFeed` checks the three feeds; `hidingTheRailOffersUndo`; `forgettingASearchCallsTheRepository`; `refreshAnnouncesTheNewListingsOnce` expects "Có 2 tin mới".
  Run → FAIL.
- [ ] `HomeUiState` loses `interests`, gains `tab: FeedTab` (saved), `viewedHidden: Boolean`. Events: `SelectTab(FeedTab)`, `ForgetSearch(String)`, `HideViewed`, `ShowViewed` (undo); `RemoveInterest` goes.
- [ ] `HomeFeedList`: items `search` (search pill + bell; the bell's long press is `LocalDebugTrigger`), `recent` (signed in and non-empty), `hero` (signed out), `categories`, `viewed` (signed in, present, not hidden), then `stickyHeader(key = "tabs")` (Compose foundation 1.12's `LazyGridScope.stickyHeader`) with a `PrimaryTabRow` on a surface background, then for NEARBY the `area` chip item, then the open tab's cards. One grid; switching tabs swaps its cards and keeps the scroll above the tabs where it is.
- [ ] Strings: `nearby` → "Gần bạn" (tab), `for_you` → "Dành cho bạn", add `newest` "Mới nhất", `viewed_because` "Vì bạn đã xem gần đây", `viewed_hide` "Ẩn mục này", `viewed_hidden` "Đã ẩn mục này", `recent_searches` "Tìm gần đây", `forget_search` "Xoá %1$s", `new_in_search` "%1$d tin mới"; `radius_done` "Tab Gần bạn hiện tin trong %1$d km"; `home_fresh` "Có %1$d tin mới"; `home_no_fresh` "Chưa có tin mới"; drop `interests`, `remove_interest`, `interest_removed`, `area` if unused.
- [ ] Hero fixture: first slide "Đồ cũ từ khắp nơi, giao tận cửa" · "Xem tin mới", query "" → `heroRoute` opens `SearchResultsRoute("")` (relevance, not nearest).
- [ ] Run `:feature:discover:testDebugUnitTest` → PASS. Commit `feat(discover): Home's feed in tabs, Gần bạn one of them; the carousel only when signed out`.

### Task 4: Copy that sold nearness

**Files:** `feature/catalog`, `feature/search`, `core/ui`, `feature/inbox`, `feature/orders`, `feature/auth`, `feature/listings`, `feature/me`, `feature/sell` strings (the spec's Copy table), and the tests that quote them.

- [ ] Grep the tests for each old string; change them to the new copy first; run → FAIL.
- [ ] Change the strings: `popular` "Phổ biến"; `around_km` and `nearest_line` removed with their call sites (the sort chip says "Gần bạn nhất" when chosen); `empty_nearby` "Chưa có tin trong %d km." shown only with the distance filter, else "Chưa có tin phù hợp."; search `all_listings` "Tất cả tin", `around` removed with its call site; core/ui `similar_empty` "Chưa có tin phù hợp"; inbox/orders `*_explore` "Khám phá tin đang bán"; auth `auth_tagline` "Đồ cũ giá tốt, xem hàng rồi mới trả", `auth_area_line` "Dùng để tính khoảng cách và phí ship. Người khác chỉ thấy quận, không thấy địa chỉ."; listings `listings_boost_line` "Lên đầu Dành cho bạn và kết quả tìm kiếm"; me `me_perk_priority` "Tin được ưu tiên hiển thị"; sell `preview_near_you` "Dành cho bạn", `preview_near_line` "Trang chủ của người mua". Run each touched module's tests → PASS.
- [ ] Grep `quanh bạn|gần bạn` across `res/values` once more: only "Gần bạn" (tab) and "Gần bạn nhất" (sort) remain. Commit `copy: nearness stops being the pitch`.

### Task 5: On the phone

- [ ] `./gradlew -q spotlessCheck detekt` (7 known), `:feature:discover:lintDebug`.
- [ ] `./run.sh` with the Pixel 9 connected (`adb devices` lists it): it builds the debug app, installs and opens it. Walk Home signed in (tabs, Gần bạn chip, rail ✕, chip ✕) and record what the screen shows.
- [ ] Stop the daemons.
