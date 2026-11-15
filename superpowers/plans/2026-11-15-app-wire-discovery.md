# App wiring, Phase 5: discovery — Implementation Plan

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`. Gap analysis done 2026-11-15 (repository → server table, model deviations, missing server support). Server: `/v1/screens/home`, `/v1/screens/listing/{id}`, `/v1/screens/seller/{id}`, `/v1/search` (+ history, watches), `/v1/saved`, `/v1/hidden`, `/v1/categories`, `/v1/follows`, `/v1/blocks`, `/v1/reports`. No new screens; the existing mockups stand.
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** the live flavor's Khám phá, Danh mục, Tìm kiếm, Chi tiết tin, Người bán and Đã lưu read the server; demo keeps its fakes on the same contract.

## Global Constraints

Roadmap rules 1–6. Each sub-step is its own branch in its own worktree (`app-wt/<topic>`, `server-wt/<topic>`), reviewed (`/code-review`, `/simplify`) and merged into local main before the next depends on it. Commits without Co-Authored-By; prose through `humanizing-writing`.

## Rulings (product owner, 2026-11-15)

- Dành cho bạn stays in live with the fake feed until the server ranks listings per person; the checklist records it.
- The server adds, spec-first: `getHomeScreen` without a position (empty nearby) and with `radius_km`; `SearchItem.category_code` and `seller_id`; `SavedListing.listing` `category_code`, `condition`, `commune`; counts on `HomeCategory.children`; `distance_km` on the listing and seller screens when `near_commune` is sent.
- Hoàn tác after deleting or clearing search history delays the DELETE until the snackbar ends (no server restore).
- Photo search asks a guest to sign in (`requiresAccount`).
- Decided in the analysis: `remember()` is a no-op live (the server records searches); a restored watch gets a new id; `SellerProfile.phoneVerified` goes; `dealId` on the seller page stays null until Phase 7; Danh mục reads one page of 100; the app never sends lat/lng, only `near_commune` from `AreaRepository`; fixed editorial content (needs, hero, hints, icons) moves to one static source both flavors read; data-derived extras with no server source (insight, viewed, picks, praise, estimate) are null live and their sections hide.

## Sub-steps

1. `chore/fixture-time` (app): `Fixtures.read` shifts every ISO instant by `now − Fixtures.NOW`; code uses of `NOW` follow; both flavors bind `Clock.system(VN_ZONE)`; tests keep `fixtureClock()`. Gate: the three walks.
2. `feat/discovery-fields` (server): the five additions above, with e2e coverage, ARCHITECTURE.md. Then re-sync `codegen.yaml`.
3. `feat/wire-discovery-contract` (app): model and contract deviations (district → commune, `distanceKm: Int?`, chip ids and 8 kinds, `SearchQuery.photo/like`, `RecentSearch.id`, `SavedSearch` filters, review `at: Moment`, seller profile fields, paging flags), fakes/fixtures, the static editorial source, features updated; no network code.
4. `feat/wire-browse` (app): shared `CategoryTree`, `DiscoveryChanges`, mappers, query encoding (the generated client does not URL-encode `q`); `NetHomeRepository`, `NetCatalogRepository`, `NetSearchRepository` (results with paging, history, watches, photo search through `MediaUploader`).
5. `feat/wire-listing-seller` (app): `NetListingRepository` (detail, owner fallback, save, alert, hide, report, similar), `NetSellerRepository` (profile, load more, follow, block, report).
6. `feat/wire-saved` (app): `NetSavedRepository` (saves, watches mute/unmute, price cuts via notification settings), `priceAlerts`.

Each app step: MockEngine tests per Net repository, mapper tests from e2e-shaped JSON, `check` of touched modules, the walks on demo, `assembleLiveDebug`, then the emulator against the local server.
