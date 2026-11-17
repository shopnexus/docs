# App wiring, Phase 9: selling

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`. Starting points: app main `61914292`, server main `648786db` (read from `server-wt/api-runtime`; the `server` checkout is used by another session). Phase 8 plan `2026-11-16-app-wire-orders.md` shows the patterns. Live sell path is fully fake today (`LiveDataModule.kt:59-61`, `FixtureOrders.kt:36-47`).

## Goal

Wire posting a listing from photos, video or a Chợ Tốt link (AI listing reads), the price guide, server drafts, posting (processing → active), editing and reposting, and Tin của bạn (hide, mark sold, price, delete) to the server. Live never shows fixture listings, drafts or plans.

## Product decisions — 2026-11-16

1. View counts: the server counts views and returns them; Tin của bạn keeps "Lượt xem" and the weekly figures.
2. The price judgment on the seller's own listings ("Cao hơn 12% · Giảm còn …") is hidden in live. The price step of posting/editing keeps the price guide.
3. "Bán cho ai?" is removed from mark-sold in both flavors. Marking sold takes no buyer; reviews come only from real COD orders. Sold cards show no buyer, stars or "Chờ đánh giá".
4. Paste a Chợ Tốt link is built in Phase 9, mockup first.
- Defaults (no question): Gói người bán entries hidden in live (cap is the server's fixed number); boosts stay hidden; "buyers usually offer x% lower", price factors and "photos buyers view" exist only in mockups and stay out; take-script prompts stay on the phone but move off fixtures; processing and rejected listing cards get a mockup (processing reads like "Vừa đăng"; rejected shows a short error row with Sửa tin; the server's English reason is not shown).

## Global constraints

- Topic worktrees; keep main's uncommitted `run.sh`/`gradle.properties`; merge locally after checks; no push.
- Server spec-first per `ARCHITECTURE.md`; no authorization relaxation; one read path per view.
- DTOs stay in network/net; fakes follow contract changes; demo flavor keeps fakes.
- Tests: JVM domain/data/VM, a few callback tests, five walks, no visual Robolectric. Live checks via `run_live.py` (see memory `live-dev-verification`).
- Transcripts, tokens and credentials never in journals, logs or committed files.

## Backend additions (server branch `feat/sell-screens`)

- `GET /v1/screens/my-listings` replaces `GET /v1/me/listings` (its only caller is the app): on-sale and hidden/processing/rejected listings with status, views (total and 7 days), askers (count and the few people shown with their line), saves, the order row of a listing with an open order, the week totals, and the sold pane (paged) without buyer or stars. Fixed-count composition like `screens/orders`.
- View counting: a signed-in viewer other than the owner opening a listing counts once per listing per viewer per day; guests are not counted (no stable identity, no fingerprinting). Stored per day for the 7-day figure.
- Repost: a way to start a new listing from an old listing's photos (copy them into new waiting uploads owned by the seller), so "Đăng lại" does not hit `invalid_upload`.
- Cap wording in `catalog.yaml` includes reserved listings, as the code counts them.

## App slices

1. Mockups: Chợ Tốt link entry and preview; processing and rejected cards; mark-sold without "Bán cho ai?"; COD gate with 2 steps; remove eKYC remnants from the draft card and design-system. Approval before UI code.
2. `feat/wire-sell-data`: UUIDv7 draft ids, extra specs passed through (no silent loss on PUT), category helpers in core:domain, ListingInput mapping and PostProblem mapping (price ceiling), NetSell/NetPricing/NetMyListings/server draft store, listing-read push handling (GET on each `listing_read`, stop at done/failed, reread on reset), frame identity by uploadId, keyed create/update with the shared journal, reconcile hide/sold/delete on lost answers. Bindings unchanged except Pricing if safe.
3. `feat/wire-sell`: switch Sell and MyListings bindings together; actions by listing status; hide price judgment and plan entries in live; remove "Bán cho ai?" in both flavors; link entry per approved mockup.

## Review focus

- [ ] No live surface opens a fixture listing, draft or order id.
- [ ] One key per exact body for listing reads, create and update; new key after a refusal; lost answers reconciled for keyless moves.
- [ ] PUT never drops specs or photos the app did not show.
- [ ] Draft limit, 30-day expiry and `try_again` handled; drafts deleted after posting.
- [ ] Reads stop at done/failed, survive reconnect, and never match frames by presigned URL.
- [ ] Account switch isolates drafts, uploads, journals and reads.
- [ ] View counts exclude the owner and dedupe per viewer per day.

## Verification

Server: touched packages `-p 4`, full e2e with declared-response coverage, lint, sqlfluff for migrations, coordinated test stack. App: mapper/MockEngine/VM tests, callback tests, five walks, lint/detekt/spotless, both APKs. Live: env-gated `LiveSellFlowTest` (u-kiet posts, waits for active, hides/unhides, edits price, marks sold/unmarks, deletes in `finally`; u-linh gets 404 on u-kiet's draft/read/processing listing; price guide shape only). Listing reads depend on external AI and Chợ Tốt in dev; gate them behind `SHOPNEXUS_LIVE_AI=1` and accept `unavailable`.
