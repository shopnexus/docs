# App wiring, Phase 11: finish

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`. Starting points: app main `2c3b226b`, server main `de704aed`. Phase 10 plan `2026-11-17-app-wire-account.md` shows the patterns. Live today: every screen reads the server except Home's Dành cho bạn (`FakeBindings.ForYou`, fixture ids that 404 when tapped) and Gói người bán (`FakeBindings.Plan`, hidden in live but bound); both pull in `FakeBindings.World` (FakeWorld, Simulator, FakeDealEngine, SimulatedCamera). "Vì bạn đã xem gần đây" is absent in live. `AppScope` lives in the `core.data.fake` package and net code imports it.

## Goal

Live binds no fake and shows no fixture data. Home's Dành cho bạn and "Vì bạn đã xem gần đây" come from the server. The three end-to-end flows run by hand on the emulator against the local server. The demo flavor still works, the app README describes the flavors, and the checklist is ticked.

## Product decisions — 2026-11-17

1. Dành cho bạn: the server ranks listings per person, nationwide, from what they viewed, saved and searched, freshest first; an account with no signals, and a guest, get the newest listings nationwide. The server also returns "Vì bạn đã xem gần đây". (User chose "Server làm feed" over hiding the tab.)
- Defaults (no question): Gói người bán stays hidden in live; the demo keeps every fake; no UI change, so no mockup step.

## Global constraints

- Topic worktrees (`server-wt/<topic>`, `app-wt/<topic>`); keep main's uncommitted `run.sh`/`gradle.properties` in `~/shopnexus/app`; merge locally after checks; no push. Server main may be merged in the main checkout (user, 2026-11-17) after checking its branch, status and reflog.
- Server spec-first per `ARCHITECTURE.md`; one read path per view; screen owns no table; decisions recorded in `ARCHITECTURE.md`.
- No authorization relaxation. Tokens stay in `SessionStore` or memory.
- Tests: JVM domain/data/VM, a few callback tests, five walks, no visual Robolectric. Live checks via `run_live.py` (memory `live-dev-verification`); throwaway dev accounts only.
- Shared test stack: check `ps` for `go test` in its own command before using it; never recreate while another session runs.

## Backend changes (server branch `feat/for-you`)

- Discovery gains a for-you read for a viewer:
  - Signals from the last 30 days: listings viewed (`listing_view_marks`), saved (`saved_listings`), and searches with a category (`search_history.category`), weighted (save > search > view) per leaf category.
  - Candidates: active listings nationwide in the weighted categories, ordered by weight and freshness; never the viewer's own, hidden, or blocked sellers' listings (the exclusions search uses).
  - Fewer candidates than the page, or no signals, or no viewer: filled with the newest listings nationwide, without duplicates.
  - Cards are `SearchItem`s built as search builds them (saved marks, distances when a position is given).
- "Vì bạn đã xem gần đây": the leaf category the viewer viewed most on their latest viewing day in the last 30 days, with up to 10 active listings of that category they have not viewed (same exclusions); absent signed out, without views, or without such listings.
- `GET /v1/screens/home` adds `for_you` (one page, same item schema as `nearby`) and optional `viewed` `{category {code, display_name}, items}`. Spec first, e2e for a guest, a new account, and an account with views/saves/searches, plus the exclusions.
- The ranking rule and its weights are written in `ARCHITECTURE.md`.

## App slices

1. `feat/live-no-fakes` (independent of the server):
   - Move `AppScope` out of `core.data.fake` to a neutral package; update imports.
   - Live binds no `FakeBindings.Plan`: Gói người bán stays hidden in live and unreachable; bind a live `PlanRepository` that reads nothing and answers failure, or install the Plans entry only where plans exist. No fixture data in live.
   - README of the app: "Fake data" becomes "Flavors" (live vs demo, what each binds, how to run each).
2. `feat/wire-for-you` (after the server merge):
   - Sync the OpenAPI codegen; `NetHomeRepository` reads `for_you` and `viewed` from `GET /v1/screens/home`; remove `ForYouSource` and `FakeBindings.ForYou` from live; demo keeps its fixtures through the fake Home.
   - An ArchUnit-style JVM test: no `vn.shopnexus.core.data.fake` import and no `FakeBindings` in `app/src/live` or `core/data/.../net`.
   - `LiveDiscoveryTest` (or the closest live class) reads Home and checks `for_you` ids open as listings.

## Hand-run end-to-end flows (emulator-5554, dev server from `server-wt/api-runtime` on the merged main)

1. A seller posts a listing (video or photos), sees it in Tin của bạn; a buyer finds it.
2. The buyer offers, the seller accepts, COD order, the seller creates the shipment (fake carrier), the order moves through `/v1/dev/shipments/{code}/status` to delivered and completed; both sides see the notices.
3. Chat in real time between two accounts: the emulator account and a second account driven by the API (session helper), messages, typing, read marks, unread counts.
Screenshots of each flow's key screens go to the user. Bugs found are fixed in a `fix/<topic>` branch before the phase closes.

## Parked items (audit 2026-11-17; user picked all four groups)

Done already: FakeServer on the test clock (374a72f4), local reset on sign-out-others/delete, server refresh of a suspended account, COD checkout reads the address book, profile tasks from one source, place labels from commune, area split out of SessionStore, fixtures on the real clock. The audit also found live building FakeWorld through `MainActivity`'s `DebugControls` and `CameraStandIn`; both go in slice 1.

Joined this phase:
- A. App: a second 401 gets its own `DataError` instead of `Conflict`; Uy tín reads once when one order move publishes both topics.
- B. App: the identity sheet's code step gets "Gửi lại mã" and shares one composable with sign-in's `CodeStep`; the duplicate `auth_*`/`identity_*` strings merge.
- C. Server + app: a reauthentication endpoint that never creates an account (the app stops reading `sid` from the JWT); `is_default` in the address draft, applied in the same transaction (the app drops its second call). Server branch `feat/reauth-address`.
- D. App: the phone gate moves to the navigation layer (`requiresPhone` beside `requiresAccount`, sheet at the frame, opened on `DataError.PhoneRequired`), replacing the five per-screen gates. Server: spec cleanups (`ShipmentDraft` discriminator, `ListingReadRequest`/`CarrierLogin` in `SignInRequest` style, typed `Error.details`, tags on internal routes) so `prepare.py` drops rules 2 and 4 and the path regex.

Order: server for-you and reauth-address in parallel; app slice 1, then A+B on one branch; C's app part after its server merge; for-you wiring after its server merge; D last (server spec cleanup after the other server branches merge, then the app's codegen and phone gate).

## Review focus

- [ ] No live code path reaches a fake (Hilt graph and imports).
- [ ] For-you excludes the viewer's own, hidden and blocked listings, and never repeats an id; guests and new accounts get newest.
- [ ] `viewed` is absent rather than empty when it has nothing.
- [ ] Demo flavor unchanged in behaviour; the five walks pass.

## Verification

Server: touched packages `-p 4`, full e2e with declared-response coverage, lint. App: mapper/MockEngine/VM tests, the ArchUnit-style test, five walks, lint/detekt/spotless, both APKs. Live: `run_live.py` with every Live* class. Hand-run flows on the emulator with screenshots. Final grep: no `core.data.fake` in live sources.

## Result (2026-11-17)

Done. App main `0cfd023e`, server main `72dbe9ab`.

- Server: feat/for-you `06079390`, feat/reauth-address `788252db` (+ fix/address-callers `1705bb05`), chore/spec-cleanup `290a5400`, fix/proof-422 `72dbe9ab`.
- App: feat/live-no-fakes `764333dd`, feat/wire-for-you `47327f2c`, feat/app-fixes `d586f6e1`, feat/codegen-reauth `8e80ae61`, feat/phone-gate-nav `c6aebeaa`, fix/e2e-findings `0cfd023e`.
- Live binds no fake; `:app:verifyLiveBindsNoFake` in `check` scans liveDebug bytecode and project jars.
- Hand-run on emulator-5554 with dev account e2e.seller@devseed.test (phone +84909880001 added by a dev helper, since the emulator has neither SMS nor PNV): post, offer → COD → delivered → completed, real-time chat with typing and read marks. All passed; findings fixed in fix/e2e-findings.
- 11 live tests pass; 41 leftover `live-*@devseed.test` accounts deleted through the API.
- Decision: the add-phone sheet stays SMS-only.
- Report with screenshots: `docs/superpowers/reports/2026-11-17-phase-11.html`.
