# Design: server2 search watches, price alerts and hidden listings

Date: 2026-11-11.
Status: decided in conversation, question by question. When the work lands,
the decisions below go into `~/shopnexus/server/ARCHITECTURE.md` (sections
Search, Discovery, Notifications, Erasure and the event list), and
`~/shopnexus/checklist.md` ticks the three items and adds a done line for
blocked sellers in search.

## Scope

Three items of `checklist.md`, section 1 ("App có, server chưa có"):

- Theo dõi từ khoá tìm kiếm + báo khi có tin mới (search watches)
- Báo giảm giá cho tin đã lưu, đặt mức giá báo (price alerts)
- Ẩn một tin khỏi feed của mình (hidden listings)

And one gap found on the way: search, the nearby feed and Home do not leave
out listings of a seller the viewer blocks or is blocked by, while the app's
fake data does (`WorldState.visible`). The exclusion that hiding adds goes
into the same query, so this design closes that gap too.

The app already has the three features on fake data
(`app/core/data/src/main/kotlin/vn/shopnexus/core/data/Repositories.kt`):

- `SearchRepository.follow(text)`, `unfollow(text)` and `restoreFollow`;
  Đã lưu lists `SavedSearch(id, query, newCount, area, alert)` with a bell.
- `ListingRepository.setPriceAlert(id, at)`, an alert when the price drops
  below `at`, which the card menu sets to the current price; and
  `SavedRepository.setPriceCutAlerts(on)`, one switch "Báo khi tin đã lưu
  giảm giá" that Cài đặt thông báo shows too.
- `ListingRepository.setHidden(id, hidden)`, "Không quan tâm" with an undo.
  A hidden listing leaves every feed and stays in Đã lưu.

This design gives them a server. It does not wire the app (the app has no
API client yet).

## Decisions

| Question | Decision |
|---|---|
| What a watch keeps | The text and the filters of the search it was made from: category, price range, conditions, offers only, the place and the radius. A new listing must match all of them. |
| Where a watch is | The commune alone. `near_commune` is kept as it is; a GPS point is turned into its nearest commune and dropped. The radius is measured from the commune's point. No point of the person reaches a row. |
| When a watch looks | A periodic sweep per watch, every 30 minutes, that tells once per sweep with the count. |
| What matches | The words, with no vectors: every word of one phrase (the query as typed, or a phrase the model read from it) is in the listing's title, description or specs. "xe đạp" does not match "xe máy". |
| Where a price alert lives | On the save. Setting an alert on a listing not saved saves it; unsaving ends the alert. The switch is a setting of the account: on, a save without its own level alerts below its saved price. |
| When an alert tells again | At each new low below the level. A price back at or above the level starts over. Level 5 tr, prices 6 → 4.8 → 4.5 → 5.5 → 4.9 tell at 4.8, 4.5 and 4.9. |
| Too many hidden listings | The 1,000 newest are kept; hiding the 1,001st shows the oldest again without an error. No list endpoint. |
| Blocked sellers in search | Left out, both ways, in the same change. |

## API

### Search watches (module `discovery`, signed in)

- `POST /v1/search/watches` → 201 `SearchWatch` for a new watch, 200 for an
  existing one. Body: `q` (1 to 200 characters, required), `category`,
  `price_min`, `price_max`, `condition[]`, `offers_only`, and the place as
  `near_commune`, or `near_lat` with `near_lng`, plus `radius_km` (1 to 200,
  needs a place).
  - One watch per `domain.HistoryKey(q)` per account. Watching the same key
    again replaces its filters, keeps its `id`, sets `new_count` to 0 and
    starts no second sweep.
  - 400 `invalid_request`, `invalid_price_range`, `invalid_position` (a
    point farther than 30 km from every commune, as for a listing),
    `position_required` (`radius_km` without a place).
  - 409 `watch_limit_reached`: the caller has 20 watches.
- `GET /v1/search/watches` → `SearchWatchList {items}`, at most 20, newest
  first, no pages.
- `POST /v1/search/watches/{id}/mute` and `/unmute` → 204. A muted watch
  still counts `new_count` and tells nothing. An unknown ID is 404
  `watch_not_found`.
- `DELETE /v1/search/watches/{id}` → 204; an unknown ID is fine. The app's
  undo posts the same text and filters again; the watch it gets has a new
  `id` and `new_count` 0.
- `SearchWatch`: `id`, `query` (as typed, trimmed), `filters` (`category`,
  `price_min`, `price_max`, `conditions`, `offers_only`, each present when
  set), `area` (`{commune_code, name}`, absent without a place),
  `radius_km`, `new_count` (0 to 99; the app shows 99 as "99+"), `alert`,
  `created_at`.
- `GET /v1/search?watch=<id>` runs the watch's text and filters from its
  commune. It goes with `cursor`, `limit`, `sort` and `off` only; any other
  parameter is 400 `search_conflict`. Another account's watch or an unknown
  one is 404 `watch_not_found`. The first page sets the watch's
  `new_count` to 0 and is kept in the search history like any `q` search.
  It runs the full hybrid search, as any `q`: the sweep's stricter match
  decides what is told and counted, the page shows what search finds.
- `SearchView` gains `watch_id`: on a signed-in search with `q` (or
  `watch`), the caller's watch of the same key, absent when there is none.
  The app shows "Đang theo dõi" from it.

### Price alerts (module `discovery`, signed in)

- `PUT /v1/saved/{listing_id}/alert {below}` → 204. `below` is a price,
  10,000 to 1,000,000,000. A listing not saved is saved first, with the
  save's checks and errors: 404 `listing_not_found`, 409 `own_listing`,
  `listing_unavailable`, `saved_limit_reached`. Setting a level clears
  `alerted_price`, so the new level tells on the next drop below it.
- `DELETE /v1/saved/{listing_id}/alert` → 204. The save stays; a listing
  not saved, or without a level, is fine.
- `SavedListing` gains `alert_below`, present when the save has its own
  level.
- `GET /v1/me/price-cut-alerts` → `{on}`, and `PUT /v1/me/price-cut-alerts
  {on}` → 204. An account that never set it reads `on: true`, as the app's
  default.

### Hidden listings (module `discovery`, signed in)

- `PUT /v1/hidden/{listing_id}` → 204. Hiding again moves the listing to
  the newest of the 1,000 kept. 404 `listing_not_found` for a listing that
  does not exist or is deleted; 409 `own_listing`.
- `DELETE /v1/hidden/{listing_id}` → 204; a listing not hidden is fine.
- Every form of `GET /v1/search` (`q`, `photo`, `like`, `watch`,
  `sort=nearby`, category browsing) and Home's nearby leave out, for a
  signed-in caller, the listings they hid and the listings of every account
  they block or that blocks them. Đã lưu, the seller page, the seller's
  listings and the listing itself are unchanged.

## Data

Migration `0035_watches_alerts_hidden.sql`:

- `search_watches`: `id uuid` (UUIDv7), `account_id` → `accounts`,
  `query_key`, `query` (1 to 200), `phrases jsonb` (the phrases at follow
  time: the query and the model's phrases, so a sweep calls no model),
  `category text`, `price_min bigint`, `price_max bigint`,
  `conditions text[]`, `offers_only bool`, `commune_code text` →
  `communes`, `radius_km int` (CHECK: needs `commune_code`), `alert bool`,
  `new_count int` (0 to 99), `last_arrival bigint`, `created_at`.
  `UNIQUE (account_id, query_key)`, index `(account_id, id)`.
- `listing_arrivals`: `seq bigserial` primary key, `listing_id` →
  `listings` (unique), `arrived_at timestamptz DEFAULT now()`. A row per first
  publication. Rows older than 2 days are deleted by the insert that finds
  them, 1,000 at a time.
- `saved_listings` gains `alert_below bigint` (NULL: no level of its own)
  and `alerted_price bigint` (NULL: nothing told since the price was last
  at or above the level).
- `saved_settings`: `account_id` primary key → `accounts`,
  `price_cut_alerts bool`. No row reads as on.
- `hidden_listings`: `id uuid` (UUIDv7), `account_id` → `accounts`,
  `listing_id` → `listings`, `UNIQUE (account_id, listing_id)`, index
  `(account_id, id)`. Hiding upserts the row with a new `id`, and the same
  transaction deletes the account's rows past the 1,000 newest.

Every write of these rows takes a share lock on the caller's `accounts` row
and refuses a tombstone with `session_revoked`, as saves do (see Erasure in
the architecture). The 20-watch cap is counted under
`pg_advisory_xact_lock(hashtext('watches:' || account_id))`.

## Flows

### Arrivals

Discovery's worker subscribes to `listing.published`. On `first: true` it
inserts the listing into `listing_arrivals` (`ON CONFLICT DO NOTHING` on a
unique `listing_id`, so a redelivery adds nothing).

`published_at` is the time the publish flow started, before the photos were
processed, so it can be minutes older than the commit. A sweep that read
listings by `published_at` would miss those; the arrival's `seq` and
`arrived_at` come from the insert after the commit, so they do not.

### The sweep

Restate service `SearchWatchSweep`, handler `Run(watch_id)`.

- A new watch sends `Run` with a delay of 30 minutes
  (`domain.SweepEvery`) and the watch ID as idempotency key, from the
  service method that inserted it, through `restatex.Caller`. Replacing the
  filters of an existing watch sends nothing. The new watch's
  `last_arrival` is the current highest `seq`, so it counts only what
  arrives after it.
- `Run`, top to bottom:
  1. Read the watch. Gone: return, which ends the chain.
  2. Read up to 500 arrivals with `seq > last_arrival` and
     `arrived_at < now() - 1 minute`. The minute lets an insert that took
     a lower `seq` commit first.
  3. Call catalog's `Search` on those listing IDs (`Filters.IDs`), with the
     watch's filters, its phrases with `AllWords` set, and the exclusions: the
     watcher's own listings, the listings they hid, and the sellers on
     either side of a block. Only `active` listings count.
  4. One transaction: add the matches to `new_count` (at most 99), set
     `last_arrival` to the highest `seq` read, and, when the matches are
     more than 0 and `alert` is on, write `search_watch.matched` (subject
     the watch, payload `{count}` = the new `new_count`). Step 2 read a
     fixed `seq` range, so a retried step changes nothing twice: the update
     is guarded by `last_arrival` being the value step 1 read.
  5. When step 2 read 500 arrivals, send `Run` again at once; otherwise
     send it with a delay of 30 minutes. Both sends are journaled.
- Each arrival is weighed once per watch: none missed, none told twice.
  A sweep held up for more than 2 days (Restate down that long) finds the
  older arrivals deleted and skips them; accepted.
- `GET /v1/search?watch=` sets `new_count` to 0 on its first page.

The phrase rule is new in catalog: `Phrase.AllWords` makes every word of the
phrase a `must`, each word matched in title, description or specs. The
sweep sets it; search keeps its ranked match.

### Price alerts

Discovery's worker subscribes to `listing.updated` and `listing.published`.

1. Read the listing's current price and status through catalog's `Summary`.
   An event's order or delay does not change the answer. Not `active`:
   return.
2. One transaction over the listing's saves, where a save's level is
   `alert_below`, else `saved_price` when the saver's switch is on, else
   none:
   - a save whose level is at or below the price gets
     `alerted_price = NULL`;
   - a save whose level is above the price and whose `alerted_price` is
     NULL or above the price gets `alerted_price = price`, and the
     transaction writes `saved.price_dropped` for it (subject the save,
     payload `{price}`).
   A retried step finds `alerted_price` already at the price and writes
   nothing.

`domain.AlertLevel` and `domain.ShouldTell` hold the rule; the SQL repeats
it, and a test runs both over the same sequence.

### Exclusions in search

Discovery reads the caller's hidden listing IDs (at most 1,000) and the
accounts on either side of the caller's blocks (`accountsvc.BlockedEither`),
and passes them to catalog as `Search.ExcludeListings` and
`Search.ExcludeSellers` (`id <> ALL`, `seller_id <> ALL`, in every list of
a hybrid search). The current `ExcludeSeller` (the viewer's own listings in
a `like` search) becomes one more entry of `ExcludeSellers`. A signed-out
search excludes nothing.

## Notifications

Module `notification` subscribes to the two new kinds. Depguard lets it
import `discovery/service`.

- `search_watch.matched`: one step reads `discoverysvc.WatchFacts(id)`
  (owner, query; zero for a watch that is gone, which tells no one). Notice
  type `watch_matched`, group "Tìm kiếm", target kind `search_watch` with
  the watch ID: "Có {count} tin mới cho “{query}”". It collapses on
  `watch:<id>`, so the unread notice shows the latest count, and is pushed.
- `saved.price_dropped`: one step reads `discoverysvc.PriceDropFacts(id)`
  (saver, listing ID, title, saved price; zero for a save that is gone).
  Notice type `price_dropped`, group "Đã lưu", target kind `listing`:
  "{title} giảm còn {price}, lúc lưu {saved price}", with the price from the
  payload and `money()` as the other notices. It collapses on
  `saved:<listing id>` and is pushed.
- Both keep the notice rules in force: an event older than the newest
  notice of its key writes nothing, a redelivered event writes nothing, and
  notices older than 90 days go when a new one comes.
- `platform/events` gains `SearchWatchMatched` and `SavedPriceDropped`;
  the OpenAPI `Notification` schema gains the two types and the target
  kind `search_watch`.

## Erasure

Discovery's `account.deleted` handler also deletes the account's
`search_watches`, `hidden_listings` and `saved_settings`, beside the saves
and the search history it deletes now. A pending sweep then finds no watch
and stops.

## Testing

- Domain: `AlertLevel` and `ShouldTell` over 6 → 4.8 → 4.5 → 5.5 → 4.9
  with level 5 (tells at 4.8, 4.5, 4.9), the switch on and off, and a
  level of its own over the saved price.
- Repository, against Postgres:
  - the 20-watch cap with two writes racing; watching a key again
    replaces the filters and keeps the ID;
  - the 1,000 hidden listings kept, hiding again moving one up;
  - arrivals: the one-minute lag, a redelivered publication adding no row,
    the 2-day cleanup;
  - the sweep's update guarded by `last_arrival`;
  - the price step: a retry writes no second event, a price back above the
    level clears `alerted_price`;
  - `AllWords`: "xe đạp" does not match "xe máy" and matches a title with
    "đạp" and a description with "xe";
  - search leaving out hidden listings and blocked sellers both ways, in
    BM25 and hybrid search.
- Worker, with Restate's test environment: the chain stops on a deleted
  watch; an arrival counted once; a full batch sends the next run at once;
  a muted watch counts and writes no event.
- e2e: each new endpoint, `?watch=` resetting `new_count`, a hidden
  listing missing from search and back after `DELETE`.
- `api/spec_test.go`, `make test` and golangci-lint pass.
