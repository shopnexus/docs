# App wiring: one server-state layer — Implementation Plan

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`, between Phase 5 steps 5 and 6. Source: the /simplify review of `feat/wire-browse` (2026-11-15). Before it, one heart tap re-read 11–15 endpoints across the back stack, and "a shared read per account that keeps its last value" existed five times (`NetAddressRepository` shelf, `NetSearchHistory`, price alerts, `readEach`, Home's own variant) with five different retry rules.
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** one mechanism for server-backed state in `:core:data/net`, which every Net repository uses and which Phase 6's WebSocket can publish into. Writes change only what they touch; screens that are not showing do not re-read.

**Architecture:**
- `ServerChanges`: a bus of typed topics replaces the `DiscoveryChanges` counter: `Listing(id)`, `Saves`, `Alerts`, `Hidden`, `Follows`, `Blocks`, `Watches`, `History`, `Addresses`, `Account`. Local writes publish into it. Phase 6's socket will publish into it too.
- `ReadContext`: one singleton `StateFlow` of account, area commune and radius. Reads declare which parts they use instead of reading the area themselves.
- `ServerState<K, T>`: keyed by a projection of `ReadContext` plus its own key. It reads while watched, shares in `@AppScope` (`WhileSubscribed`), and merges identical reads in flight. It keeps the last value per account. Only a first read can fail the stream. It has one retry policy, re-reads on its topics, and offers `refresh()` and `put`/`apply(patch)` for pushes. It emits a stream that never ends, of `Loadable<T>(value, error, refreshing)`.
- `ListingMarks`: saved, alert and hidden per listing, and following and blocked per seller. Writes change it optimistically, reads and pushes confirm it, and failures revert it. Net repositories apply it to cards before they emit. `Pending`, `SaveToggles.seen` and the per-ViewModel overlays go away. Đã lưu (step 6) reads it.
- `CursorPager` takes an invalidation trigger only, with no `opened` hook. On a change it re-reads page one and marks later pages stale, to be read again as the person scrolls.
- Migrated onto it: Home (watches only on `Watches`; Mới nhất when its tab shows), Search results and history, the Listing detail, the Seller screen (one `ServerState` per seller screen; the profile is a map of it), price alerts, the address book, and Danh mục's counts (taken from Home's held categories).

## Rulings

- A heart, an alert, a follow or a watch change costs no re-read. Hides and blocks re-read only the lists they remove cards from.
- A screen in the back stack re-reads once when it shows again.
- The delayed DELETE queue in search history (`AccountOutbox`) waits for Phase 7, where chat's send queue needs the same thing.

## Review Focus

1. A heart tap with Home, Results, Detail and Seller open sends one write and no read → test with MockEngine request counts.
2. A push-shaped `apply(patch)` updates every screen showing that listing.
3. The first read fails the screen; a later failure keeps the content with an error → `ServerStateTest`.
4. Account switch: nothing from the last account shows.

## Tasks

1. `ServerChanges`, `ReadContext`, `Loadable`, `ServerState` + tests.
2. `ListingMarks` + tests; card overlay in the Net mappers.
3. Migrate listing, seller, search and history, home, catalog, alerts and addresses; delete `DiscoveryChanges`, `readEach`, `Pending`, and the per-repo shelves.
4. ViewModels map `Loadable`; `LiveRead`'s retry goes.
5. Gate, emulator, `/code-review`, `/simplify`, merge.
