# Search watches, price alerts and hidden listings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give server search watches with a periodic sweep and a notice, price alerts on saved listings, per-person hidden listings, and leave blocked sellers out of search.

**Architecture:** Everything new lives in module `discovery` (tables, use cases, two Restate services), with small read additions in `catalog` (search filters, nearest commune) and `account` (accounts on either side of a block). Discovery writes two new events; module `notification` hears them and writes notices, as it does for the other modules.

**Tech Stack:** Go (stdlib `uuid`), Postgres 18 / ParadeDB 0.26.3 (`pg_search`), Restate Go SDK v1.1.0, pgx v5, OpenAPI 3 in `api/`.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-11-server-search-watches-price-alerts-hidden-design.md`

All paths below are relative to `~/shopnexus/server` unless they start with `~/`.

## Global Constraints

- Read `ARCHITECTURE.md` and `CLAUDE.md` in `~/shopnexus/server` first; their rules hold for every task.
- A use case, Restate handler or HTTP handler reads top to bottom; a helper is fine only when two or more places call it.
- A handler runs `httpx.Caller`, `httpx.Bind`, one `Service` method, then `httpx.Respond` / `httpx.WriteError`.
- A transaction lives inside one repository method. Every write of an account's rows calls `living(ctx, tx, account)` and refuses a tombstone with `accountdomain.ErrSessionRevoked` (watch writes, hiding, the switch).
- No new configuration variables. Durations and caps are `domain` constants; tests shorten them through `service.Deps` fields, as `ModelTimeout` does.
- Limits, copied from the spec: 20 watches per account; 1,000 hidden listings kept per account; `new_count` 0 to 99; sweep every 30 minutes; arrival lag 1 minute; sweep batch 500; arrivals kept 2 days; `below` 10,000 to 1,000,000,000.
- Error codes: `watch_limit_reached` (409), `watch_not_found` (404), and the existing `invalid_price_range`, `invalid_position`, `position_required`, `search_conflict`, `listing_not_found`, `own_listing`, `listing_unavailable`, `saved_limit_reached`, `try_again`.
- No point of a person reaches a row, a log or the journal: a watch stores a commune code only.
- Every status an operation declares in `api/` must be observed by an e2e test, or `e2e` fails its coverage check.
- Commit in the `server` submodule after each task. No `Co-Authored-By` trailer. Run the commit message through the `humanizing-writing` skill's checker (`python3 ~/.claude/skills/humanizing-writing/ai-tells.py --stats <file>`) before committing; messages follow the repo's style, `feat(discovery): ...`.
- `make test` must pass (it runs every test, then `golangci-lint run`). After one `make test`, `go test ./internal/<module>/...` runs one module against the test stack. Scratch output goes in `tmp/`.

## Review Focus

- A watch made from a GPS point far from any commune (a phone abroad): `invalid_position`, never a watch on a commune 500 km away. Test in Task 7.
- A seller who edits the price twice quickly, both events delivered late or out of order: `PriceMoved` reads the price at handling time, so both deliveries weigh the same price and the second tells nothing. Test in Task 5 (the repository runs 4.8 tr twice and the second tells 0).
- A watch's query whose words are only punctuation or numbers ("13", "-"): `AllWords` drops tokens with no letter or digit; a phrase left with no word matches nothing instead of everything. Test in Task 2.
- Unwatch and watch the same words again within 30 minutes: the old chain finds its watch gone and stops, the new watch has a new ID and its own chain, and nothing is counted twice. Test in Task 7.
- A listing hidden, then the hider unhides it from the undo: it is back in the next search page, and a hide of the 1,001st listing shows the oldest again without an error. Test in Task 4.

---

### Task 1: Migration 0035

**Files:**
- Create: `migrations/0035_watches_alerts_hidden.sql`
- Test: the migrations apply in `pgtest.New` (every repository test uses it)

**Interfaces:**
- Produces: tables `search_watches`, `listing_arrivals`, `saved_settings`, `hidden_listings`; columns `saved_listings.alert_below`, `saved_listings.alerted_price`.

- [ ] **Step 1: Write the migration**

```sql
-- Search watches, price alerts on saves and hidden listings.
--
-- A watch keeps a query, the phrases the model read from it, the person's
-- filters and a commune; no point of the person. listing_arrivals logs each
-- listing's first publication after it committed, which the sweeps read by
-- seq. A save may carry its own alert level and the last price it told.

CREATE TABLE search_watches (
    id           uuid PRIMARY KEY,
    account_id   uuid NOT NULL REFERENCES accounts (id),
    query_key    text NOT NULL,
    query        text NOT NULL CHECK (char_length(query) BETWEEN 1 AND 200),
    phrases      jsonb NOT NULL,
    category     text,
    price_min    bigint CHECK (price_min > 0),
    price_max    bigint CHECK (price_max > 0),
    conditions   text[] NOT NULL,
    offers_only  boolean NOT NULL,
    commune_code text REFERENCES communes (code),
    radius_km    integer CHECK (radius_km BETWEEN 1 AND 200),
    alert        boolean NOT NULL,
    new_count    integer NOT NULL CHECK (new_count BETWEEN 0 AND 99),
    last_arrival bigint NOT NULL,
    created_at   timestamptz NOT NULL,
    UNIQUE (account_id, query_key),
    CHECK (radius_km IS NULL OR commune_code IS NOT NULL)
);

CREATE INDEX search_watches_account ON search_watches (account_id, id);

CREATE TABLE listing_arrivals (
    seq        bigserial PRIMARY KEY,
    listing_id uuid NOT NULL UNIQUE REFERENCES listings (id),
    -- The insert's time, after the publication committed; a sweep reads
    -- arrivals older than a minute, so a lower seq still committing is not
    -- skipped.
    arrived_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX listing_arrivals_at ON listing_arrivals (arrived_at);

ALTER TABLE saved_listings
    ADD COLUMN alert_below   bigint CHECK (alert_below BETWEEN 10000 AND 1000000000),
    ADD COLUMN alerted_price bigint;

CREATE INDEX saved_listings_listing ON saved_listings (listing_id);

CREATE TABLE saved_settings (
    account_id       uuid PRIMARY KEY REFERENCES accounts (id),
    price_cut_alerts boolean NOT NULL
);

CREATE TABLE hidden_listings (
    id         uuid PRIMARY KEY,
    account_id uuid NOT NULL REFERENCES accounts (id),
    listing_id uuid NOT NULL REFERENCES listings (id),
    UNIQUE (account_id, listing_id)
);

CREATE INDEX hidden_listings_account ON hidden_listings (account_id, id);
```

- [ ] **Step 2: Apply it**

Run: `make test` once if the test stack is down (it starts the stack and applies every migration), otherwise `go test ./internal/discovery/repository/...`.
Expected: PASS; a syntax error fails every test at `pgtest.New`.

- [ ] **Step 3: Commit**

```bash
git add migrations/0035_watches_alerts_hidden.sql
git commit -m "feat(discovery): tables for search watches, arrivals, price alerts and hidden listings"
```

---

### Task 2: Catalog search filters and the nearest commune

**Files:**
- Modify: `internal/catalog/domain/search.go` (Filters, Phrase, Search)
- Modify: `internal/catalog/repository/search_pg.go` (must, exclusions, where, hybrid)
- Modify: `internal/catalog/repository/repository.go` (Regions), `internal/catalog/repository/region_pg.go`
- Modify: `internal/catalog/service/service.go` (Service), `internal/catalog/service/listing_get.go`
- Modify: `internal/discovery/service/search.go:178` (`search.ExcludeSeller = *viewer`)
- Test: `internal/catalog/repository/search_pg_test.go`, `internal/catalog/repository/region_pg_test.go`

**Interfaces:**
- Produces:
  - `catalogdomain.Filters.IDs []uuid.UUID` (empty: every listing)
  - `catalogdomain.Phrase.AllWords bool`
  - `catalogdomain.Search.ExcludeListings, ExcludeSellers []uuid.UUID` (replace `ExcludeSeller`)
  - `catalogsvc.Service.NearestCommune(ctx, p catalogdomain.Point) (code string, km float64, err error)`
  - `repository.Regions.Nearest(ctx, p domain.Point) (Place, error)`

- [ ] **Step 1: Write the failing tests**

In `search_pg_test.go`, give `item` a description and add a test:

```go
type item struct {
	title  string
	desc   string
	cat    string
	price  int64
	point  domain.Point
	age    time.Duration
	status domain.Status
}
```

and in `put`, set `Description: it.desc` in the `ListingState`. Then:

```go
// AllWords needs every word of a phrase in the title, description or specs;
// the IDs filter and the exclusions hold in BM25 and in browsing.
func TestSearchAllWordsAndExclusions(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	s := repository.NewSearches(db)
	hn := domain.Point{Lat: 21.03, Lng: 105.85}
	bike := put(t, db, item{title: "Xe đạp Asama", cat: "vehicles.bicycle", price: 1_500_000, point: hn})
	motor := put(t, db, item{title: "Xe máy Wave", cat: "vehicles.bicycle", price: 9_000_000, point: hn})
	split := put(t, db, item{title: "Đạp êm, còn mới", desc: "xe của con gái", cat: "vehicles.bicycle", price: 900_000, point: hn})
	run := func(q domain.Search) []uuid.UUID {
		t.Helper()
		q.Limit = 20
		hits, err := s.Search(ctx, q)
		if err != nil {
			t.Fatal(err)
		}
		out := make([]uuid.UUID, len(hits))
		for i, h := range hits {
			out[i] = h.ID
		}
		slices.SortFunc(out, func(a, b uuid.UUID) int { return strings.Compare(a.String(), b.String()) })
		return out
	}
	want := func(ids ...uuid.UUID) []uuid.UUID {
		slices.SortFunc(ids, func(a, b uuid.UUID) int { return strings.Compare(a.String(), b.String()) })
		return ids
	}
	all := []uuid.UUID{bike, motor, split}
	words := domain.Search{Filters: domain.Filters{IDs: all}, Phrases: []domain.Phrase{{Text: "xe đạp", Weight: 1, AllWords: true}}}
	if got := run(words); !slices.Equal(got, want(bike, split)) {
		t.Fatalf("all words: %v", got)
	}
	ranked := domain.Search{Filters: domain.Filters{IDs: all}, Phrases: []domain.Phrase{{Text: "xe đạp", Weight: 1}}}
	if got := run(ranked); !slices.Contains(got, motor) {
		t.Fatalf("a ranked phrase matches any word: %v", got)
	}
	empty := domain.Search{Filters: domain.Filters{IDs: all}, Phrases: []domain.Phrase{{Text: "- / ...", Weight: 1, AllWords: true}}}
	if got := run(empty); len(got) != 0 {
		t.Fatalf("a phrase of no word matches nothing: %v", got)
	}
	if got := run(domain.Search{Filters: domain.Filters{IDs: []uuid.UUID{bike}}, Sort: domain.SortNewest}); !slices.Equal(got, []uuid.UUID{bike}) {
		t.Fatalf("ids: %v", got)
	}
	ex := domain.Search{Filters: domain.Filters{IDs: all}, Sort: domain.SortNewest, ExcludeListings: []uuid.UUID{bike}}
	if got := run(ex); !slices.Equal(got, want(motor, split)) {
		t.Fatalf("exclude listings: %v", got)
	}
	var seller uuid.UUID
	if err := db.QueryRow(ctx, `SELECT seller_id FROM listings WHERE id = $1`, motor).Scan(&seller); err != nil {
		t.Fatal(err)
	}
	ex = domain.Search{Filters: domain.Filters{IDs: all}, Phrases: []domain.Phrase{{Text: "xe", Weight: 1}}, ExcludeSellers: []uuid.UUID{seller}}
	if got := run(ex); slices.Contains(got, motor) {
		t.Fatalf("exclude sellers: %v", got)
	}
}
```

Add `"strings"` to the imports. In `region_pg_test.go`:

```go
func TestNearestCommune(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	r := repository.NewRegions(db)
	ctx := context.Background()
	places, err := r.Places(ctx, []string{"00004"})
	if err != nil || len(places) != 1 {
		t.Fatalf("%v %v", places, err)
	}
	p, err := r.Nearest(ctx, domain.Point{Lat: places[0].Lat + 0.001, Lng: places[0].Lng})
	if err != nil || p.Code != "00004" || p.Province == "" {
		t.Fatalf("%+v %v", p, err)
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/catalog/repository/ -run 'TestSearchAllWordsAndExclusions|TestNearestCommune'`
Expected: FAIL to compile (`IDs`, `AllWords`, `ExcludeListings`, `Nearest` undefined).

- [ ] **Step 3: Implement the domain fields**

In `internal/catalog/domain/search.go`, add to `Filters` after `RadiusKm`:

```go
	// IDs keeps the search to these listings, empty for every listing: a
	// watch's sweep weighs the listings that arrived since the last one.
	IDs []uuid.UUID
```

Replace `Phrase` with:

```go
// Phrase is text to match in the title, the description and the specs. A
// negative weight demotes what matches. AllWords makes it match only a
// listing holding every word of Text in one of the three, as a watch's
// sweep needs; a ranked phrase matches any of its words.
type Phrase struct {
	Text     string
	Weight   float64
	AllWords bool
}
```

Replace the `ExcludeSeller` field of `Search` with:

```go
	// ExcludeListings and ExcludeSellers leave listings out: the ones the
	// viewer hid, the sellers on either side of the viewer's blocks, and the
	// viewer's own in a similar-listings search or a sweep.
	ExcludeListings, ExcludeSellers []uuid.UUID
```

- [ ] **Step 4: Implement the SQL**

In `search_pg.go`, in `must`, replace the phrase loop body:

```go
		for _, p := range s.Phrases {
			switch {
			case p.Weight > 0 && p.AllWords:
				phrases = append(phrases, q.allWords(p))
			case p.Weight > 0:
				phrases = append(phrases, q.phrase(p)...)
			default:
			}
		}
```

Add after `phrase`:

```go
// allWords matches a listing holding every word of p, each in its title,
// description or specs. A word is a run of letters and digits; a phrase of
// none matches nothing.
func (q *query) allWords(p domain.Phrase) string {
	var words []string
	for _, w := range strings.FieldsFunc(p.Text, func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) }) {
		text := q.arg(w, "text")
		words = append(words, `paradedb.boolean(should => `+array([]string{
			`paradedb.match('title', ` + text + `)`,
			`paradedb.match('description', ` + text + `)`,
			`paradedb.match('specs_text', ` + text + `)`,
		})+`)`)
	}
	if len(words) == 0 {
		return `paradedb.empty()`
	}
	return `paradedb.boolean(must => ` + array(words) + `)`
}
```

Add `"unicode"` to the imports. Replace `exclusions`:

```go
// exclusions are the plain SQL conditions on the listings alias: the
// similar-listings source, the IDs filter and the listings and sellers left
// out.
func (q *query) exclusions(s domain.Search, alias string) []string {
	var out []string
	if s.Like != (uuid.UUID{}) {
		out = append(out, alias+`id <> `+q.arg(s.Like, "uuid"))
	}
	if len(s.Filters.IDs) > 0 {
		out = append(out, alias+`id = ANY(`+q.arg(s.Filters.IDs, "uuid[]")+`)`)
	}
	if len(s.ExcludeListings) > 0 {
		out = append(out, alias+`id <> ALL(`+q.arg(s.ExcludeListings, "uuid[]")+`)`)
	}
	if len(s.ExcludeSellers) > 0 {
		out = append(out, alias+`seller_id <> ALL(`+q.arg(s.ExcludeSellers, "uuid[]")+`)`)
	}
	return out
}
```

Replace `where` so browsing, BM25 search and counts all take the exclusions:

```go
// where is the search's condition with its exclusions; counts leave the
// boosts out, since they change no membership.
func (q *query) where(s domain.Search, boosts bool) string {
	sql := `id @@@ paradedb.boolean(must => ` + array(q.must(s))
	// Building the boosts adds their parameters, which strict named args
	// refuse when the SQL does not use them, so counts never build them.
	if boosts {
		if should := q.should(s); len(should) > 0 {
			sql += `, should => ` + array(should)
		}
	}
	sql += `)`
	if ex := q.exclusions(s, ""); len(ex) > 0 {
		sql += ` AND ` + strings.Join(ex, " AND ")
	}
	return sql
}
```

In `hybrid`, the `bm25` CTE now gets the exclusions from `where`; delete these lines:

```go
		if ex := q.exclusions(s, ""); len(ex) > 0 {
			where += ` AND ` + strings.Join(ex, " AND ")
		}
```

- [ ] **Step 5: Implement the nearest commune**

In `repository.go`, add to `Regions`:

```go
	// Nearest returns the commune whose point is closest to p.
	Nearest(ctx context.Context, p domain.Point) (Place, error)
```

In `region_pg.go`:

```go
func (s pgRegions) Nearest(ctx context.Context, p domain.Point) (Place, error) {
	rows, err := s.db.Query(ctx, `SELECT c.code, c.province_code, c.display_name, c.lat, c.lng, p.display_name
FROM communes c JOIN provinces p ON p.code = c.province_code
ORDER BY power(c.lat - @lat, 2) + power((c.lng - @lng) * cos(radians(@lat)), 2), c.code LIMIT 1`,
		pgx.StrictNamedArgs{"lat": p.Lat, "lng": p.Lng})
	if err != nil {
		return Place{}, fmt.Errorf("select nearest commune: %w", err)
	}
	place, err := pgx.CollectExactlyOneRow(rows, pgx.RowToStructByPos[Place])
	if err != nil {
		return Place{}, fmt.Errorf("read nearest commune: %w", err)
	}
	return place, nil
}
```

In `service.go`, add to `Service` beside `Places`:

```go
	// NearestCommune is the commune whose point is closest to p, and how
	// far that point is in kilometres.
	NearestCommune(ctx context.Context, p domain.Point) (code string, km float64, err error)
```

In `listing_get.go`, after `Places`:

```go
func (c *Catalog) NearestCommune(ctx context.Context, p domain.Point) (string, float64, error) {
	place, err := c.regions.Nearest(ctx, p)
	if err != nil {
		return "", 0, fmt.Errorf("find the commune: %w", err)
	}
	return place.Code, domain.Distance(p, domain.Point{Lat: place.Lat, Lng: place.Lng}), nil
}
```

- [ ] **Step 6: Move the one caller of ExcludeSeller**

In `internal/discovery/service/search.go`, in the `if like` block, replace `search.ExcludeSeller = *viewer` with:

```go
			search.ExcludeSellers = append(search.ExcludeSellers, *viewer)
```

Run: `grep -rn 'ExcludeSeller\b' internal` → no hits.

- [ ] **Step 7: Run the tests**

Run: `go test ./internal/catalog/... ./internal/discovery/...`
Expected: PASS, including the existing `TestSearch` and the hybrid tests.

- [ ] **Step 8: Commit**

```bash
git add internal/catalog internal/discovery/service/search.go
git commit -m "feat(catalog): search by IDs, every word of a phrase, listings and sellers left out, the nearest commune"
```

---

### Task 3: Accounts on either side of a block

**Files:**
- Modify: `internal/account/repository/account.go` (Accounts), `internal/account/repository/account_pg.go`
- Modify: `internal/account/service/service.go`, `internal/account/service/block.go`
- Test: `internal/account/repository/account_pg_test.go`

**Interfaces:**
- Produces: `accountsvc.Service.BlockedWith(ctx, account uuid.UUID) ([]uuid.UUID, error)`

- [ ] **Step 1: Write the failing test**

```go
func TestBlockedWith(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	accounts := repository.NewAccounts(db)
	me, blockedByMe, blocksMe, other := accounttest.New(t, db), accounttest.New(t, db), accounttest.New(t, db), accounttest.New(t, db)
	if err := accounts.Block(ctx, uuid.NewV7(), me, blockedByMe, time.Now()); err != nil {
		t.Fatal(err)
	}
	if err := accounts.Block(ctx, uuid.NewV7(), blocksMe, me, time.Now()); err != nil {
		t.Fatal(err)
	}
	got, err := accounts.BlockedWith(ctx, me)
	slices.SortFunc(got, func(a, b uuid.UUID) int { return strings.Compare(a.String(), b.String()) })
	want := []uuid.UUID{blockedByMe, blocksMe}
	slices.SortFunc(want, func(a, b uuid.UUID) int { return strings.Compare(a.String(), b.String()) })
	if err != nil || !slices.Equal(got, want) || slices.Contains(got, other) {
		t.Fatalf("%v %v", got, err)
	}
}
```

`Accounts.Block` is `Block(ctx, id, blocker, blocked uuid.UUID, at time.Time) error`. Add `"slices"`, `"strings"` and `"time"` to the test file's imports if it lacks them.

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/account/repository/ -run TestBlockedWith`
Expected: FAIL, `BlockedWith` undefined.

- [ ] **Step 3: Implement**

In `account.go`, beside `Blocked`:

```go
	// BlockedWith lists the accounts that block account or that account
	// blocks.
	BlockedWith(ctx context.Context, account uuid.UUID) ([]uuid.UUID, error)
```

In `account_pg.go`:

```go
func (s pgAccounts) BlockedWith(ctx context.Context, account uuid.UUID) ([]uuid.UUID, error) {
	rows, err := s.db.Query(ctx, `SELECT blocked_id FROM account_blocks WHERE blocker_id = @a
UNION SELECT blocker_id FROM account_blocks WHERE blocked_id = @a`, pgx.StrictNamedArgs{"a": account})
	if err != nil {
		return nil, fmt.Errorf("select blocks: %w", err)
	}
	ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return nil, fmt.Errorf("read blocks: %w", err)
	}
	return ids, nil
}
```

In `service.go`, beside `Blocked`:

```go
	// BlockedWith lists the accounts on either side of account's blocks;
	// discovery leaves their listings out of account's searches.
	BlockedWith(ctx context.Context, account uuid.UUID) ([]uuid.UUID, error)
```

In `block.go`:

```go
func (s *Account) BlockedWith(ctx context.Context, account uuid.UUID) ([]uuid.UUID, error) {
	ids, err := s.accounts.BlockedWith(ctx, account)
	if err != nil {
		return nil, fmt.Errorf("read blocks: %w", err)
	}
	return ids, nil
}
```

Any test fake that embeds `accountsvc.Service` compiles unchanged.

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/account/...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/account
git commit -m "feat(account): BlockedWith lists the accounts on either side of a person's blocks"
```

---

### Task 4: Hidden listings, and search without hidden listings and blocked sellers

**Files:**
- Modify: `internal/discovery/domain/errors.go` (MaxHidden)
- Create: `internal/discovery/repository/hidden_pg.go`
- Modify: `internal/discovery/repository/repository.go` (Hidden)
- Create: `internal/discovery/service/hidden.go`
- Modify: `internal/discovery/service/service.go` (Service, Deps, Discovery, New), `internal/discovery/service/search.go`, `internal/discovery/service/history.go` (AccountDeleted)
- Create: `internal/discovery/handler/hidden.go`; Modify: `internal/discovery/handler/handler.go` (Register)
- Modify: `internal/discovery/discovery.go` (Mount takes accounts), `internal/app/app.go:260`
- Modify: `api/openapi.yaml`, `api/paths/discovery.yaml`
- Test: `internal/discovery/repository/hidden_pg_test.go`, `internal/discovery/service/hidden_test.go`, `internal/discovery/service/saved_test.go` (newEnv)

**Interfaces:**
- Consumes: `catalogdomain.Search.ExcludeListings/ExcludeSellers` (Task 2), `accountsvc.Service.BlockedWith` (Task 3)
- Produces:
  - `repository.Hidden` with `Hide(ctx, account, listing uuid.UUID) error`, `Unhide(ctx, account, listing uuid.UUID) error`, `List(ctx, account uuid.UUID) ([]uuid.UUID, error)`, `Clear(ctx, account uuid.UUID) error`; `repository.NewHidden(db)`
  - `service.Service.Hide(ctx, account, listing uuid.UUID) error`, `Unhide(...)`
  - `service.Deps.Hidden repository.Hidden`, `service.Deps.Accounts accountsvc.Service`
  - `(*Discovery).exclusions(ctx, account uuid.UUID) (listings, sellers []uuid.UUID, err error)`, used again by Task 7
  - `discovery.Mount(d, s, catalog, media, accounts)`

- [ ] **Step 1: Write the failing repository test**

`internal/discovery/repository/hidden_pg_test.go`:

```go
package repository_test

import (
	"context"
	"slices"
	"testing"

	"github.com/shopnexus/server/internal/account/accounttest"
	"github.com/shopnexus/server/internal/discovery/domain"
	"github.com/shopnexus/server/internal/discovery/repository"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
)

func TestHidden(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	h := repository.NewHidden(db)
	ctx := context.Background()
	me := accounttest.New(t, db)
	ls := listings(t, db, 3)
	for _, l := range ls {
		if err := h.Hide(ctx, me, l); err != nil {
			t.Fatal(err)
		}
	}
	if err := h.Hide(ctx, me, ls[0]); err != nil { // again: moves to the newest
		t.Fatal(err)
	}
	got, err := h.List(ctx, me)
	if err != nil || len(got) != 3 || got[0] != ls[0] {
		t.Fatalf("%v %v", got, err)
	}
	if err = h.Unhide(ctx, me, ls[1]); err != nil {
		t.Fatal(err)
	}
	if err = h.Unhide(ctx, me, ls[1]); err != nil { // not hidden: fine
		t.Fatal(err)
	}
	if got, _ = h.List(ctx, me); slices.Contains(got, ls[1]) || len(got) != 2 {
		t.Fatalf("unhide: %v", got)
	}
	if err = h.Clear(ctx, me); err != nil {
		t.Fatal(err)
	}
	if got, _ = h.List(ctx, me); len(got) != 0 {
		t.Fatalf("clear: %v", got)
	}
}

// The 1,001st hide shows the oldest again.
func TestHiddenKeepsTheNewest(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	h := repository.NewHidden(db)
	ctx := context.Background()
	me := accounttest.New(t, db)
	ls := listings(t, db, domain.MaxHidden+1)
	for _, l := range ls {
		if err := h.Hide(ctx, me, l); err != nil {
			t.Fatal(err)
		}
	}
	got, err := h.List(ctx, me)
	if err != nil || len(got) != domain.MaxHidden || slices.Contains(got, ls[0]) || got[0] != ls[len(ls)-1] {
		t.Fatalf("%d %v", len(got), err)
	}
}
```

`TestHiddenKeepsTheNewest` makes 1,001 listings through `listings` (51 sellers); it takes a few seconds.

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/discovery/repository/ -run TestHidden`
Expected: FAIL to compile (`NewHidden`, `MaxHidden` undefined).

- [ ] **Step 3: Implement the repository**

In `domain/errors.go`, below `MaxSaved`:

```go
// MaxHidden is how many hidden listings one person keeps; hiding one more
// shows the oldest again.
const MaxHidden = 1000
```

In `repository.go`, after `Saves`:

```go
// Hidden keeps the listings a person hid from their searches.
type Hidden interface {
	// Hide hides listing from account's searches as the newest hide, again
	// too, and drops the hides past domain.MaxHidden, in one transaction.
	Hide(ctx context.Context, account, listing uuid.UUID) error
	// Unhide shows it again; a listing not hidden is fine.
	Unhide(ctx context.Context, account, listing uuid.UUID) error
	// List is the hidden listings, newest hide first.
	List(ctx context.Context, account uuid.UUID) ([]uuid.UUID, error)
	// Clear deletes every hide of the account.
	Clear(ctx context.Context, account uuid.UUID) error
}
```

`hidden_pg.go`:

```go
package repository

import (
	"context"
	"fmt"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	accountdomain "github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/discovery/domain"
)

type pgHidden struct{ db *pgxpool.Pool }

func NewHidden(db *pgxpool.Pool) Hidden { return pgHidden{db} }

// trimHidden keeps an account's newest domain.MaxHidden hides; the IDs are
// UUIDv7s taken at the write, so they order by it.
const trimHidden = `
DELETE FROM hidden_listings WHERE account_id = @account AND id NOT IN (
    SELECT id FROM hidden_listings WHERE account_id = @account ORDER BY id DESC LIMIT @keep)`

func (s pgHidden) Hide(ctx context.Context, account, listing uuid.UUID) error {
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		alive, err := living(ctx, tx, account)
		if err != nil {
			return err
		}
		if !alive {
			return accountdomain.ErrSessionRevoked
		}
		if _, err := tx.Exec(ctx, `INSERT INTO hidden_listings (id, account_id, listing_id) VALUES (@id, @account, @listing)
ON CONFLICT (account_id, listing_id) DO UPDATE SET id = excluded.id`,
			pgx.StrictNamedArgs{"id": uuid.NewV7(), "account": account, "listing": listing}); err != nil {
			return fmt.Errorf("upsert hide: %w", err)
		}
		if _, err := tx.Exec(ctx, trimHidden, pgx.StrictNamedArgs{"account": account, "keep": domain.MaxHidden}); err != nil {
			return fmt.Errorf("trim hides: %w", err)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("hide listing: %w", err)
	}
	return nil
}

func (s pgHidden) Unhide(ctx context.Context, account, listing uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM hidden_listings WHERE account_id = @account AND listing_id = @listing`,
		pgx.StrictNamedArgs{"account": account, "listing": listing}); err != nil {
		return fmt.Errorf("unhide listing: %w", err)
	}
	return nil
}

func (s pgHidden) List(ctx context.Context, account uuid.UUID) ([]uuid.UUID, error) {
	rows, err := s.db.Query(ctx, `SELECT listing_id FROM hidden_listings WHERE account_id = @account ORDER BY id DESC`,
		pgx.StrictNamedArgs{"account": account})
	if err != nil {
		return nil, fmt.Errorf("select hides: %w", err)
	}
	ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return nil, fmt.Errorf("read hides: %w", err)
	}
	return ids, nil
}

func (s pgHidden) Clear(ctx context.Context, account uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM hidden_listings WHERE account_id = @account`,
		pgx.StrictNamedArgs{"account": account}); err != nil {
		return fmt.Errorf("clear hides: %w", err)
	}
	return nil
}
```

Run: `go test ./internal/discovery/repository/ -run TestHidden` → PASS.

- [ ] **Step 4: Write the failing service test**

In `saved_test.go`, extend `newEnv`'s deps with `Hidden: repository.NewHidden(db), Accounts: accounttest.Service(db),` and keep `accounts` in `env`:

```go
type env struct {
	// existing fields...
	accounts *accountservice.Account // accounttest.Service's type; import "github.com/shopnexus/server/internal/account/service" as accountservice
}
```

Build it once: `acc := accounttest.Service(db)`, pass `acc` to `catalogtest.Service` and to `Deps.Accounts`, and set `env.accounts = acc`.

`internal/discovery/service/hidden_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"slices"
	"testing"
	"uuid"

	"github.com/shopnexus/server/internal/account/accounttest"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/discovery/domain"
	"github.com/shopnexus/server/internal/discovery/service"
)

func ids(v service.SearchView) []uuid.UUID {
	out := make([]uuid.UUID, len(v.Items))
	for i, it := range v.Items {
		out[i] = it.ID
	}
	return out
}

// A hidden listing and a blocked seller's listing leave the viewer's
// searches, browsing and the nearby feed; unhiding brings the listing back.
func TestHideAndBlockLeaveSearch(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me := accounttest.New(t, e.db)
	hidden := e.put(t, "Xe đạp Asama", "vehicles.bicycle", baDinh)
	blocked := e.put(t, "Xe đạp Giant", "vehicles.bicycle", baDinh)
	kept := e.put(t, "Xe đạp Thống Nhất", "vehicles.bicycle", baDinh)
	if err := e.discovery.Hide(ctx, me, hidden); err != nil {
		t.Fatal(err)
	}
	seller, _, err := e.catalog.Summary(ctx, blocked)
	if err != nil {
		t.Fatal(err)
	}
	if err = e.accounts.Block(ctx, seller.SellerID, me); err != nil { // the seller blocks me: either way counts
		t.Fatal(err)
	}
	for _, in := range []service.SearchInput{
		{Query: "xe dap"},
		{Category: "vehicles.bicycle"},
		{Sort: service.SortNearby, Near: service.Near{Lat: baDinh.Lat, Lng: baDinh.Lng}},
	} {
		v, err := e.discovery.Search(ctx, &me, in)
		if err != nil {
			t.Fatal(err)
		}
		got := ids(v)
		if slices.Contains(got, hidden) || slices.Contains(got, blocked) || !slices.Contains(got, kept) {
			t.Fatalf("%+v: %v", in, got)
		}
	}
	v, err := e.discovery.Search(ctx, nil, service.SearchInput{Category: "vehicles.bicycle"})
	if err != nil || !slices.Contains(ids(v), hidden) || !slices.Contains(ids(v), blocked) {
		t.Fatalf("signed out sees everything: %v %v", ids(v), err)
	}
	if err = e.discovery.Unhide(ctx, me, hidden); err != nil {
		t.Fatal(err)
	}
	if v, _ = e.discovery.Search(ctx, &me, service.SearchInput{Category: "vehicles.bicycle"}); !slices.Contains(ids(v), hidden) {
		t.Fatalf("unhidden: %v", ids(v))
	}
}

func TestHideRefusals(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me := accounttest.New(t, e.db)
	if err := e.discovery.Hide(ctx, me, uuid.NewV7()); !errors.Is(err, catalogdomain.ErrNotFound) {
		t.Fatalf("unknown: %v", err)
	}
	mine := e.put(t, "Xe đạp Asama", "vehicles.bicycle", baDinh)
	own, _, _ := e.catalog.Summary(ctx, mine)
	if err := e.discovery.Hide(ctx, own.SellerID, mine); !errors.Is(err, domain.ErrOwnListing) {
		t.Fatalf("own: %v", err)
	}
}
```

`accountsvc.Service.Block` is `Block(ctx, blocker, blocked uuid.UUID) error`; `e.put(t, title, category, point)` is in `search_test.go`.

- [ ] **Step 5: Run it to see it fail**

Run: `go test ./internal/discovery/service/ -run 'TestHide'`
Expected: FAIL to compile (`Hide`, `Unhide`, `Deps.Hidden`, `Deps.Accounts` undefined).

- [ ] **Step 6: Implement the service**

In `service.go`: add to `Service`:

```go
	// Hide leaves someone else's listing out of account's searches;
	// hiding it again makes it the newest hide.
	Hide(ctx context.Context, account, listing uuid.UUID) error
	// Unhide shows it again; a listing not hidden is fine.
	Unhide(ctx context.Context, account, listing uuid.UUID) error
```

Add `Hidden repository.Hidden` and `Accounts accountsvc.Service` to `Deps`, `hidden repository.Hidden` and `accounts accountsvc.Service` to `Discovery`, and `hidden: d.Hidden, accounts: d.Accounts,` to `New`. Import `accountsvc "github.com/shopnexus/server/internal/account/service"`. Update `AccountDeleted`'s doc in the interface to "deletes a deleted account's saves, history, watches, hides and settings".

`internal/discovery/service/hidden.go`:

```go
package service

import (
	"context"
	"fmt"
	"uuid"

	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/discovery/domain"
)

func (d *Discovery) Hide(ctx context.Context, account, listing uuid.UUID) error {
	l, ok, err := d.catalog.Summary(ctx, listing)
	if err != nil {
		return fmt.Errorf("read listing: %w", err)
	}
	switch {
	case !ok || l.Status == catalogdomain.StatusDeleted:
		return catalogdomain.ErrNotFound
	case l.SellerID == account:
		return domain.ErrOwnListing
	default:
	}
	if err = d.hidden.Hide(ctx, account, listing); err != nil {
		return fmt.Errorf("hide: %w", err)
	}
	return nil
}

func (d *Discovery) Unhide(ctx context.Context, account, listing uuid.UUID) error {
	if err := d.hidden.Unhide(ctx, account, listing); err != nil {
		return fmt.Errorf("unhide: %w", err)
	}
	return nil
}

// exclusions are the listings account hid and the accounts on either side
// of its blocks, which its searches and its watches' sweeps leave out.
func (d *Discovery) exclusions(ctx context.Context, account uuid.UUID) (listings, sellers []uuid.UUID, err error) {
	if listings, err = d.hidden.List(ctx, account); err != nil {
		return nil, nil, fmt.Errorf("read hides: %w", err)
	}
	if sellers, err = d.accounts.BlockedWith(ctx, account); err != nil {
		return nil, nil, fmt.Errorf("read blocks: %w", err)
	}
	return listings, sellers, nil
}
```

In `search.go`, right after `search := catalogdomain.Search{...}` and the nearby block, add:

```go
	if viewer != nil {
		if search.ExcludeListings, search.ExcludeSellers, err = d.exclusions(ctx, *viewer); err != nil {
			return SearchView{}, err
		}
	}
```

In `history.go`, `AccountDeleted` gains, after the history:

```go
	if err := d.hidden.Clear(ctx, account); err != nil {
		return fmt.Errorf("clear hides: %w", err)
	}
```

- [ ] **Step 7: Wire Mount and app**

In `discovery.go`, `Mount` takes `accounts accountsvc.Service` after `media` and sets `Hidden: repository.NewHidden(d.Pool), Accounts: accounts` in `service.Deps`. In `internal/app/app.go`, pass `accounts` as the last argument of `discovery.Mount` (the variable already holds account's service; `trust.Mount` takes it on the line above).

- [ ] **Step 8: Write the API**

In `api/openapi.yaml`, after `/v1/saved/{listing_id}`:

```yaml
  /v1/hidden/{listing_id}:
    $ref: "paths/discovery.yaml#/hiddenListing"
```

In `api/paths/discovery.yaml`, append:

```yaml
hiddenListing:
  put:
    operationId: hideListing
    summary: Leave someone else's listing out of the caller's searches, Home and the nearby feed; hiding again makes it the newest hide.
    description: The caller keeps the 1,000 newest hides; one more shows the oldest again. Saved listings, the seller page and the listing itself still show it.
    tags: [discovery]
    security:
      - bearerAuth: []
    parameters:
      - name: listing_id
        in: path
        required: true
        schema:
          type: string
          format: uuid
    responses:
      "204":
        description: Hidden.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "No such listing, or it is deleted (listing_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "409":
        description: "The listing is the caller's (own_listing)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
  delete:
    operationId: unhideListing
    summary: Show a hidden listing again; a listing not hidden is fine.
    tags: [discovery]
    security:
      - bearerAuth: []
    parameters:
      - name: listing_id
        in: path
        required: true
        schema:
          type: string
          format: uuid
    responses:
      "204":
        description: Shown again.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
```

In the `search` operation's `description`, replace the last sentence with: "A signed-in caller's first page with q is kept in the search history, and a signed-in caller never sees the listings they hid nor those of an account on either side of their blocks."

- [ ] **Step 9: Write the handler**

`internal/discovery/handler/hidden.go`:

```go
package handler

import (
	"net/http"

	"github.com/shopnexus/server/internal/platform/httpx"
)

// Hide serves PUT /v1/hidden/{listing_id}.
func (h *Handler) Hide(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in listingRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.Hide(r.Context(), p.AccountID, in.ListingID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Unhide serves DELETE /v1/hidden/{listing_id}.
func (h *Handler) Unhide(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in listingRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.Unhide(r.Context(), p.AccountID, in.ListingID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

In `handler.go`'s `Register`:

```go
	r.Handle("PUT /v1/hidden/{listing_id}", protect(http.HandlerFunc(h.Hide)))
	r.Handle("DELETE /v1/hidden/{listing_id}", protect(http.HandlerFunc(h.Unhide)))
```

- [ ] **Step 10: Run the tests**

Run: `go test ./api/... ./internal/discovery/... ./internal/app/... ./internal/screen/...`
Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add api internal/discovery internal/app
git commit -m "feat(discovery): hide a listing from one's searches; searches leave out blocked sellers"
```

---

### Task 5: Price alerts on saves

**Files:**
- Create: `internal/discovery/domain/alert.go`, `internal/discovery/domain/alert_test.go`
- Modify: `internal/platform/events/events.go` (SavedPriceDropped)
- Modify: `internal/discovery/repository/repository.go` (Save, Saves, Settings), `internal/discovery/repository/saved_pg.go`
- Create: `internal/discovery/repository/settings_pg.go`
- Create: `internal/discovery/service/alert.go`; Modify: `service.go`, `saved.go`, `history.go`
- Create: `internal/discovery/handler/alert.go`; Modify: `handler.go`
- Modify: `internal/discovery/discovery.go`, `api/openapi.yaml`, `api/paths/discovery.yaml`, `api/schemas/discovery.yaml`
- Test: `internal/discovery/repository/saved_pg_test.go`, `internal/discovery/service/alert_test.go`

**Interfaces:**
- Produces:
  - `domain.AlertLevel(below *int64, saved int64, switchOn bool) (level int64, ok bool)`
  - `domain.PriceStep(level int64, ok bool, alerted *int64, price int64) (tell, reset bool)`
  - `events.SavedPriceDropped Kind = "saved.price_dropped"` (subject the save, payload `{"price": int64}`)
  - `repository.Save` gains `AlertBelow *int64` and `Account uuid.UUID`
  - `repository.Saves.SetAlert(ctx, account, listing uuid.UUID, below *int64) (bool, error)`, `PriceMoved(ctx, listing uuid.UUID, price int64, at time.Time) (int, error)`, `Get(ctx, id uuid.UUID) (Save, bool, error)`
  - `repository.Settings` with `PriceCutAlerts(ctx, account) (bool, error)`, `SetPriceCutAlerts(ctx, account uuid.UUID, on bool) error`, `Clear(ctx, account) error`; `repository.NewSettings(db)`
  - `service.Service.SetAlert(ctx, account, listing uuid.UUID, below int64) error`, `ClearAlert(ctx, account, listing uuid.UUID) error`, `PriceCutAlerts(ctx, account uuid.UUID) (PriceCutAlertsView, error)` with `service.PriceCutAlertsView{On bool}`, `SetPriceCutAlerts(ctx, account uuid.UUID, on bool) error`, `PriceMoved(ctx, listing uuid.UUID) error`, `PriceDropFacts(ctx, id uuid.UUID) (PriceDropFacts, bool, error)`
  - `service.PriceDropFacts{ID, Account, ListingID uuid.UUID; Title string; SavedPrice int64}`
  - `SavedView.AlertBelow *int64` (`alert_below`)

- [ ] **Step 1: Write the failing domain test**

`internal/discovery/domain/alert_test.go`:

```go
package domain_test

import (
	"testing"

	"github.com/shopnexus/server/internal/discovery/domain"
)

// Level 5 tr over 6 → 4.8 → 4.5 → 5.5 → 4.9 tells at 4.8, 4.5 and 4.9.
func TestPriceStepTellsAtEachNewLow(t *testing.T) {
	t.Parallel()
	level, ok := domain.AlertLevel(new(int64(5_000_000)), 6_000_000, false)
	if !ok || level != 5_000_000 {
		t.Fatalf("%d %v", level, ok)
	}
	var alerted *int64
	var told []int64
	for _, price := range []int64{6_000_000, 4_800_000, 4_500_000, 5_500_000, 4_900_000, 4_900_000} {
		tell, reset := domain.PriceStep(level, ok, alerted, price)
		switch {
		case tell:
			alerted = new(price)
			told = append(told, price)
		case reset:
			alerted = nil
		default:
		}
	}
	if len(told) != 3 || told[0] != 4_800_000 || told[1] != 4_500_000 || told[2] != 4_900_000 {
		t.Fatalf("%v", told)
	}
}

func TestAlertLevel(t *testing.T) {
	t.Parallel()
	if l, ok := domain.AlertLevel(nil, 2_000_000, true); !ok || l != 2_000_000 {
		t.Fatalf("switch on: %d %v", l, ok)
	}
	if _, ok := domain.AlertLevel(nil, 2_000_000, false); ok {
		t.Fatal("switch off and no level: none")
	}
	if l, ok := domain.AlertLevel(new(int64(1_000_000)), 2_000_000, true); !ok || l != 1_000_000 {
		t.Fatalf("own level wins: %d", l)
	}
	if tell, reset := domain.PriceStep(0, false, new(int64(1)), 5); tell || !reset {
		t.Fatal("no level clears what was told")
	}
}
```

The repo already uses `new(expr)` (Go 1.26): `saved.go` writes `new(l.Price)`.

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/discovery/domain/ -run 'TestPriceStep|TestAlertLevel'`
Expected: FAIL, undefined.

- [ ] **Step 3: Implement the domain**

`internal/discovery/domain/alert.go`:

```go
package domain

// AlertLevel is the price below which a save tells: its own level, else the
// saved price while the account's "Báo khi tin đã lưu giảm giá" is on. ok
// is false when the save has none.
func AlertLevel(below *int64, saved int64, switchOn bool) (level int64, ok bool) {
	switch {
	case below != nil:
		return *below, true
	case switchOn:
		return saved, true
	default:
		return 0, false
	}
}

// PriceStep is what a save's alert does at a new price. It tells at each
// new low below the level: below it and below the last price it told. A
// price at or above the level, or no level, resets it, so the next drop
// tells again. Saves.PriceMoved runs the same rule in SQL.
func PriceStep(level int64, ok bool, alerted *int64, price int64) (tell, reset bool) {
	if !ok || price >= level {
		return false, alerted != nil
	}
	return alerted == nil || price < *alerted, false
}
```

Run: `go test ./internal/discovery/domain/` → PASS.

- [ ] **Step 4: Write the failing repository test**

Append to `saved_pg_test.go`:

```go
// PriceMoved runs PriceStep over the same prices: level 5 tr tells at 4.8,
// 4.5 and 4.9, and a repeated price writes no second event.
func TestPriceMoved(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewSaves(db)
	ctx := context.Background()
	me, other := accounttest.New(t, db), accounttest.New(t, db)
	l := listings(t, db, 1)[0]
	if err := s.Save(ctx, uuid.NewV7(), me, l, 6_000_000, now); err != nil {
		t.Fatal(err)
	}
	if err := s.Save(ctx, uuid.NewV7(), other, l, 6_000_000, now); err != nil { // the switch alone, at the saved price
		t.Fatal(err)
	}
	if found, err := s.SetAlert(ctx, me, l, new(int64(5_000_000))); err != nil || !found {
		t.Fatalf("%v %v", found, err)
	}
	var told []int
	for _, price := range []int64{6_000_000, 4_800_000, 4_800_000, 4_500_000, 5_500_000, 4_900_000} {
		n, err := s.PriceMoved(ctx, l, price, now)
		if err != nil {
			t.Fatal(err)
		}
		told = append(told, n)
	}
	// me: -, 4.8, -, 4.5, reset, 4.9; other (level 6 tr): -, 4.8, -, 4.5, -, -.
	if want := []int{0, 2, 0, 2, 0, 1}; !slices.Equal(told, want) {
		t.Fatalf("told %v, want %v", told, want)
	}
	var events int
	if err := db.QueryRow(ctx, `SELECT count(*) FROM events WHERE kind = 'saved.price_dropped'`).Scan(&events); err != nil || events != 5 {
		t.Fatalf("%d events %v", events, err)
	}
	set := repository.NewSettings(db)
	if on, err := set.PriceCutAlerts(ctx, other); err != nil || !on {
		t.Fatalf("on by default: %v %v", on, err)
	}
	if err := set.SetPriceCutAlerts(ctx, other, false); err != nil {
		t.Fatal(err)
	}
	if n, err := s.PriceMoved(ctx, l, 4_000_000, now); err != nil || n != 1 { // me alone now
		t.Fatalf("switch off: %d %v", n, err)
	}
	got, err := s.List(ctx, me, page.Request{})
	if err != nil || got[0].AlertBelow == nil || *got[0].AlertBelow != 5_000_000 || got[0].Account != me {
		t.Fatalf("%+v %v", got, err)
	}
	one, found, err := s.Get(ctx, got[0].ID)
	if err != nil || !found || one.Account != me || one.ListingID != l {
		t.Fatalf("%+v %v %v", one, found, err)
	}
	if found, err = s.SetAlert(ctx, me, l, nil); err != nil || !found {
		t.Fatal(err)
	}
	if found, _ = s.SetAlert(ctx, me, uuid.NewV7(), nil); found {
		t.Fatal("no save: not found")
	}
}
```

Add `"slices"` to the imports.

- [ ] **Step 5: Run it to see it fail**

Run: `go test ./internal/discovery/repository/ -run TestPriceMoved`
Expected: FAIL to compile.

- [ ] **Step 6: Implement the event kind and the repository**

In `internal/platform/events/events.go`, after `ReviewPosted`:

```go
	// SavedPriceDropped is a saved listing's price at a new low below the
	// save's alert level; the payload's price is that price.
	SavedPriceDropped Kind = "saved.price_dropped"
```

In `repository.go`, replace `Save` and add to `Saves`:

```go
// Save is one saved listing with the price it had when saved and its own
// alert level, nil for none.
type Save struct {
	ID         uuid.UUID
	ListingID  uuid.UUID
	Price      int64
	At         time.Time
	AlertBelow *int64
	Account    uuid.UUID
}
```

```go
	// Get reads one save by its ID.
	Get(ctx context.Context, id uuid.UUID) (Save, bool, error)
	// SetAlert sets the level of account's save of listing, nil to clear
	// it, and forgets the price it last told; found is false without the
	// save.
	SetAlert(ctx context.Context, account, listing uuid.UUID, below *int64) (found bool, err error)
	// PriceMoved applies domain.PriceStep to every save of listing at price,
	// and writes events.SavedPriceDropped for each save it tells, in one
	// transaction. It returns how many it told.
	PriceMoved(ctx context.Context, listing uuid.UUID, price int64, at time.Time) (int, error)
```

And a new interface:

```go
// Settings keeps a person's discovery settings: the switch that alerts on
// a drop below the saved price of every save without its own level.
type Settings interface {
	// PriceCutAlerts is the switch; an account that never set it reads on.
	PriceCutAlerts(ctx context.Context, account uuid.UUID) (bool, error)
	SetPriceCutAlerts(ctx context.Context, account uuid.UUID, on bool) error
	Clear(ctx context.Context, account uuid.UUID) error
}
```

In `saved_pg.go`, change `List`'s SELECT to:

```go
	rows, err := s.db.Query(ctx, `SELECT id, listing_id, saved_price, created_at, alert_below, account_id FROM saved_listings
WHERE account_id = @account AND id < @before ORDER BY id DESC LIMIT @limit`,
```

and add:

```go
func (s pgSaves) Get(ctx context.Context, id uuid.UUID) (Save, bool, error) {
	rows, err := s.db.Query(ctx, `SELECT id, listing_id, saved_price, created_at, alert_below, account_id
FROM saved_listings WHERE id = @id`, pgx.StrictNamedArgs{"id": id})
	if err != nil {
		return Save{}, false, fmt.Errorf("select save: %w", err)
	}
	save, err := pgx.CollectExactlyOneRow(rows, pgx.RowToStructByPos[Save])
	if errors.Is(err, pgx.ErrNoRows) {
		return Save{}, false, nil
	}
	if err != nil {
		return Save{}, false, fmt.Errorf("read save: %w", err)
	}
	return save, true, nil
}

func (s pgSaves) SetAlert(ctx context.Context, account, listing uuid.UUID, below *int64) (bool, error) {
	tag, err := s.db.Exec(ctx, `UPDATE saved_listings SET alert_below = @below, alerted_price = NULL
WHERE account_id = @account AND listing_id = @listing`,
		pgx.StrictNamedArgs{"account": account, "listing": listing, "below": below})
	if err != nil {
		return false, fmt.Errorf("set alert: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

// alertLevel is domain.AlertLevel on saved_listings s, NULL for none. It is
// a correlated subquery, not a CTE, so an UPDATE that waited for another
// re-reads it on the row's newest version.
const alertLevel = `COALESCE(s.alert_below, CASE WHEN COALESCE(
    (SELECT st.price_cut_alerts FROM saved_settings st WHERE st.account_id = s.account_id), true) THEN s.saved_price END)`

func (s pgSaves) PriceMoved(ctx context.Context, listing uuid.UUID, price int64, at time.Time) (int, error) {
	var told []uuid.UUID
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		args := pgx.StrictNamedArgs{"listing": listing, "price": price}
		if _, err := tx.Exec(ctx, `UPDATE saved_listings s SET alerted_price = NULL
WHERE s.listing_id = @listing AND s.alerted_price IS NOT NULL
  AND (`+alertLevel+` IS NULL OR `+alertLevel+` <= @price)`, args); err != nil {
			return fmt.Errorf("reset alerts: %w", err)
		}
		rows, err := tx.Query(ctx, `UPDATE saved_listings s SET alerted_price = @price
WHERE s.listing_id = @listing AND `+alertLevel+` > @price
  AND (s.alerted_price IS NULL OR s.alerted_price > @price)
RETURNING s.id`, args)
		if err != nil {
			return fmt.Errorf("tell alerts: %w", err)
		}
		if told, err = pgx.CollectRows(rows, pgx.RowTo[uuid.UUID]); err != nil {
			return fmt.Errorf("read alerts: %w", err)
		}
		evs := make([]events.Event, len(told))
		for i, id := range told {
			evs[i] = events.Event{
				ID: uuid.NewV7(), Kind: events.SavedPriceDropped, SubjectID: id,
				Payload: map[string]any{"price": price}, OccurredAt: at,
			}
		}
		return events.Insert(ctx, tx, evs...)
	})
	if err != nil {
		return 0, fmt.Errorf("price moved: %w", err)
	}
	return len(told), nil
}
```

Import `"errors"` and `"github.com/shopnexus/server/internal/platform/events"`. The event IDs are minted inside the step; a retried step after a commit finds `alerted_price` already at the price and writes none.

`settings_pg.go`:

```go
package repository

import (
	"context"
	"errors"
	"fmt"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	accountdomain "github.com/shopnexus/server/internal/account/domain"
)

type pgSettings struct{ db *pgxpool.Pool }

func NewSettings(db *pgxpool.Pool) Settings { return pgSettings{db} }

func (s pgSettings) PriceCutAlerts(ctx context.Context, account uuid.UUID) (bool, error) {
	var on bool
	err := s.db.QueryRow(ctx, `SELECT price_cut_alerts FROM saved_settings WHERE account_id = @account`,
		pgx.StrictNamedArgs{"account": account}).Scan(&on)
	if errors.Is(err, pgx.ErrNoRows) {
		return true, nil
	}
	if err != nil {
		return false, fmt.Errorf("read settings: %w", err)
	}
	return on, nil
}

func (s pgSettings) SetPriceCutAlerts(ctx context.Context, account uuid.UUID, on bool) error {
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		alive, err := living(ctx, tx, account)
		if err != nil {
			return err
		}
		if !alive {
			return accountdomain.ErrSessionRevoked
		}
		if _, err := tx.Exec(ctx, `INSERT INTO saved_settings (account_id, price_cut_alerts) VALUES (@account, @on)
ON CONFLICT (account_id) DO UPDATE SET price_cut_alerts = excluded.price_cut_alerts`,
			pgx.StrictNamedArgs{"account": account, "on": on}); err != nil {
			return fmt.Errorf("upsert settings: %w", err)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("set price cut alerts: %w", err)
	}
	return nil
}

func (s pgSettings) Clear(ctx context.Context, account uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM saved_settings WHERE account_id = @account`,
		pgx.StrictNamedArgs{"account": account}); err != nil {
		return fmt.Errorf("clear settings: %w", err)
	}
	return nil
}
```

Run: `go test ./internal/discovery/repository/` → PASS.

- [ ] **Step 7: Write the failing service test**

In `newEnv`, add `Settings: repository.NewSettings(db),`. `internal/discovery/service/alert_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"testing"

	"github.com/shopnexus/server/internal/account/accounttest"
	"github.com/shopnexus/server/internal/catalog/catalogtest"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/discovery/domain"
	"github.com/shopnexus/server/internal/platform/page"
)

func TestSetAlertSavesAndTells(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, me := accounttest.New(t, e.db), accounttest.New(t, e.db)
	l := catalogtest.Listing(t, e.db, seller) // 1,500,000 đ
	if err := e.discovery.SetAlert(ctx, me, l, 1_500_000); err != nil {
		t.Fatal(err)
	}
	p, err := e.discovery.Saved(ctx, me, page.Request{})
	if err != nil || len(p.Items) != 1 || p.Items[0].AlertBelow == nil || *p.Items[0].AlertBelow != 1_500_000 {
		t.Fatalf("the alert saves the listing: %+v %v", p, err)
	}
	if _, err = e.db.Exec(ctx, `UPDATE listings SET price = 1400000 WHERE id = $1`, l); err != nil {
		t.Fatal(err)
	}
	if err = e.discovery.PriceMoved(ctx, l); err != nil {
		t.Fatal(err)
	}
	var save string
	if err = e.db.QueryRow(ctx, `SELECT subject_id::text FROM events WHERE kind = 'saved.price_dropped'`).Scan(&save); err != nil {
		t.Fatal(err)
	}
	f, found, err := e.discovery.PriceDropFacts(ctx, p.Items[0].ID)
	if err != nil || !found || f.Account != me || f.ListingID != l || f.Title != "Xe đạp Asama" || f.SavedPrice != 1_500_000 ||
		save != p.Items[0].ID.String() {
		t.Fatalf("%+v %v %v", f, found, err)
	}
	if err = e.discovery.ClearAlert(ctx, me, l); err != nil {
		t.Fatal(err)
	}
	if p, _ = e.discovery.Saved(ctx, me, page.Request{}); len(p.Items) != 1 || p.Items[0].AlertBelow != nil {
		t.Fatalf("cleared, still saved: %+v", p)
	}
	if err = e.discovery.SetAlert(ctx, seller, l, 1_000_000); !errors.Is(err, domain.ErrOwnListing) {
		t.Fatalf("own: %v", err)
	}
	if sw, _ := e.discovery.PriceCutAlerts(ctx, me); !sw.On {
		t.Fatal("on by default")
	}
	if err = e.discovery.SetPriceCutAlerts(ctx, me, false); err != nil {
		t.Fatal(err)
	}
	if sw, _ := e.discovery.PriceCutAlerts(ctx, me); sw.On {
		t.Fatal("off")
	}
}
```

Remove the `catalogdomain` import from this file's import block; nothing in it uses the package.

- [ ] **Step 8: Run it to see it fail**

Run: `go test ./internal/discovery/service/ -run TestSetAlertSavesAndTells`
Expected: FAIL to compile.

- [ ] **Step 9: Implement the service**

In `service.go`, add to `Service`:

```go
	// SetAlert sets the price below which account hears of listing, saving
	// it first when it is not saved, with Save's refusals.
	SetAlert(ctx context.Context, account, listing uuid.UUID, below int64) error
	// ClearAlert removes the save's own level; the save stays.
	ClearAlert(ctx context.Context, account, listing uuid.UUID) error
	// PriceCutAlerts is "Báo khi tin đã lưu giảm giá", on until set off.
	PriceCutAlerts(ctx context.Context, account uuid.UUID) (PriceCutAlertsView, error)
	SetPriceCutAlerts(ctx context.Context, account uuid.UUID, on bool) error
	// PriceMoved weighs every save of listing against its current price;
	// the worker calls it on listing.updated and listing.published.
	PriceMoved(ctx context.Context, listing uuid.UUID) error
	// PriceDropFacts is what notification tells of a save's price drop.
	PriceDropFacts(ctx context.Context, id uuid.UUID) (PriceDropFacts, bool, error)
```

Add `Settings repository.Settings` to `Deps`, `settings repository.Settings` to `Discovery`, `settings: d.Settings` to `New`. In `discovery.go`'s `Mount`, set `Settings: repository.NewSettings(d.Pool)`.

`internal/discovery/service/alert.go`:

```go
package service

import (
	"context"
	"fmt"
	"uuid"

	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/platform/apperr"
)

// PriceDropFacts is a save whose listing fell to a new low.
type PriceDropFacts struct {
	ID         uuid.UUID `json:"id"`
	Account    uuid.UUID `json:"account"`
	ListingID  uuid.UUID `json:"listing_id"`
	Title      string    `json:"title"`
	SavedPrice int64     `json:"saved_price"`
}

// SetAlert saves the listing, a second time changing nothing, then sets
// the level. An unsave between the two is try_again.
func (d *Discovery) SetAlert(ctx context.Context, account, listing uuid.UUID, below int64) error {
	if err := d.Save(ctx, account, listing); err != nil {
		return err
	}
	found, err := d.saves.SetAlert(ctx, account, listing, &below)
	if err != nil {
		return fmt.Errorf("set alert: %w", err)
	}
	if !found {
		return apperr.ErrTryAgain
	}
	return nil
}

func (d *Discovery) ClearAlert(ctx context.Context, account, listing uuid.UUID) error {
	if _, err := d.saves.SetAlert(ctx, account, listing, nil); err != nil {
		return fmt.Errorf("clear alert: %w", err)
	}
	return nil
}

// PriceCutAlertsView is the PriceCutAlerts schema.
type PriceCutAlertsView struct {
	On bool `json:"on"`
}

func (d *Discovery) PriceCutAlerts(ctx context.Context, account uuid.UUID) (PriceCutAlertsView, error) {
	on, err := d.settings.PriceCutAlerts(ctx, account)
	if err != nil {
		return PriceCutAlertsView{}, fmt.Errorf("read settings: %w", err)
	}
	return PriceCutAlertsView{On: on}, nil
}

func (d *Discovery) SetPriceCutAlerts(ctx context.Context, account uuid.UUID, on bool) error {
	if err := d.settings.SetPriceCutAlerts(ctx, account, on); err != nil {
		return fmt.Errorf("set settings: %w", err)
	}
	return nil
}

// PriceMoved reads the listing as it is now, so events out of order or late
// tell at the current price; a listing off sale tells no one.
func (d *Discovery) PriceMoved(ctx context.Context, listing uuid.UUID) error {
	l, ok, err := d.catalog.Summary(ctx, listing)
	if err != nil {
		return fmt.Errorf("read listing: %w", err)
	}
	if !ok || l.Status != catalogdomain.StatusActive {
		return nil
	}
	if _, err = d.saves.PriceMoved(ctx, listing, l.Price, d.now()); err != nil {
		return fmt.Errorf("weigh the saves: %w", err)
	}
	return nil
}

func (d *Discovery) PriceDropFacts(ctx context.Context, id uuid.UUID) (PriceDropFacts, bool, error) {
	s, found, err := d.saves.Get(ctx, id)
	if err != nil || !found {
		return PriceDropFacts{}, false, err
	}
	l, ok, err := d.catalog.Summary(ctx, s.ListingID)
	if err != nil {
		return PriceDropFacts{}, false, fmt.Errorf("read listing: %w", err)
	}
	if !ok {
		return PriceDropFacts{}, false, nil
	}
	return PriceDropFacts{ID: id, Account: s.Account, ListingID: s.ListingID, Title: l.Title, SavedPrice: s.Price}, true, nil
}
```

In `saved.go`, add to `SavedView`:

```go
	// AlertBelow is the save's own alert level, absent for none.
	AlertBelow *int64 `json:"alert_below,omitempty"`
```

and set `AlertBelow: r.AlertBelow` where the view is built. In `history.go`'s `AccountDeleted`, add `d.settings.Clear(ctx, account)` with the same error wrapping as the others.

- [ ] **Step 10: Write the API**

`api/openapi.yaml`, after `/v1/saved/{listing_id}`:

```yaml
  /v1/saved/{listing_id}/alert:
    $ref: "paths/discovery.yaml#/savedAlert"
  /v1/me/price-cut-alerts:
    $ref: "paths/discovery.yaml#/priceCutAlerts"
```

`api/paths/discovery.yaml`, append:

```yaml
savedAlert:
  put:
    operationId: setSavedAlert
    summary: Hear when the listing's price falls below a level; a listing not saved is saved first.
    description: The caller hears at each new low below the level. A price back at or above it starts over, and setting a level forgets the price last told.
    tags: [discovery]
    security:
      - bearerAuth: []
    parameters:
      - name: listing_id
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
            $ref: "../schemas/discovery.yaml#/SavedAlert"
    responses:
      "204":
        description: Set.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "No such listing (listing_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "409":
        description: "The listing is the caller's (own_listing), not on sale (listing_unavailable), the caller has 500 saves (saved_limit_reached), or the save went meanwhile (try_again)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
  delete:
    operationId: clearSavedAlert
    summary: Remove the save's own level; the save stays, and a listing not saved is fine.
    tags: [discovery]
    security:
      - bearerAuth: []
    parameters:
      - name: listing_id
        in: path
        required: true
        schema:
          type: string
          format: uuid
    responses:
      "204":
        description: Removed.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
priceCutAlerts:
  get:
    operationId: getPriceCutAlerts
    summary: Whether a saved listing without its own level alerts below its saved price; on until set off.
    tags: [discovery]
    security:
      - bearerAuth: []
    responses:
      "200":
        description: The switch.
        content:
          application/json:
            schema:
              $ref: "../schemas/discovery.yaml#/PriceCutAlerts"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
  put:
    operationId: setPriceCutAlerts
    summary: Turn the switch on or off.
    tags: [discovery]
    security:
      - bearerAuth: []
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/discovery.yaml#/PriceCutAlerts"
    responses:
      "204":
        description: Set.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
```

`api/schemas/discovery.yaml`: add to `SavedListing.properties`:

```yaml
    alert_below:
      type: integer
      format: int64
      description: The save's own alert level; absent when it has none.
```

and append:

```yaml
SavedAlert:
  type: object
  additionalProperties: false
  required: [below]
  properties:
    below:
      type: integer
      format: int64
      minimum: 10000
      maximum: 1000000000
      description: Tell when the price falls below this.
PriceCutAlerts:
  type: object
  additionalProperties: false
  required: ["on"]
  properties:
    "on":
      type: boolean
```

- [ ] **Step 11: Write the handlers**

`internal/discovery/handler/alert.go`:

```go
package handler

import (
	"net/http"
	"uuid"

	"github.com/shopnexus/server/internal/platform/httpx"
)

type alertRequest struct {
	ListingID uuid.UUID `json:"-" path:"listing_id"`
	Below     int64     `json:"below"`
}

// SetAlert serves PUT /v1/saved/{listing_id}/alert.
func (h *Handler) SetAlert(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in alertRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.SetAlert(r.Context(), p.AccountID, in.ListingID, in.Below); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ClearAlert serves DELETE /v1/saved/{listing_id}/alert.
func (h *Handler) ClearAlert(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in listingRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.ClearAlert(r.Context(), p.AccountID, in.ListingID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// PriceCutAlerts serves GET /v1/me/price-cut-alerts.
func (h *Handler) PriceCutAlerts(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	out, err := h.svc.PriceCutAlerts(r.Context(), p.AccountID)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, out)
}

type priceCutAlertsRequest struct {
	On bool `json:"on"`
}

// SetPriceCutAlerts serves PUT /v1/me/price-cut-alerts.
func (h *Handler) SetPriceCutAlerts(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in priceCutAlertsRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.SetPriceCutAlerts(r.Context(), p.AccountID, in.On); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

In `Register`:

```go
	r.Handle("PUT /v1/saved/{listing_id}/alert", protect(http.HandlerFunc(h.SetAlert)))
	r.Handle("DELETE /v1/saved/{listing_id}/alert", protect(http.HandlerFunc(h.ClearAlert)))
	r.Handle("GET /v1/me/price-cut-alerts", protect(http.HandlerFunc(h.PriceCutAlerts)))
	r.Handle("PUT /v1/me/price-cut-alerts", protect(http.HandlerFunc(h.SetPriceCutAlerts)))
```

- [ ] **Step 12: Run the tests**

Run: `go test ./api/... ./internal/discovery/... ./internal/platform/events/...`
Expected: PASS.

- [ ] **Step 13: Commit**

```bash
git add api internal/discovery internal/platform/events
git commit -m "feat(discovery): a price alert on a save tells at each new low below its level"
```

---

### Task 6: The watches repository and its arrivals

**Files:**
- Modify: `internal/discovery/domain/errors.go` (watch constants and errors)
- Modify: `internal/platform/events/events.go` (SearchWatchMatched)
- Modify: `internal/discovery/repository/repository.go` (Watch, Arrival, Watches)
- Create: `internal/discovery/repository/watch_pg.go`
- Test: `internal/discovery/repository/watch_pg_test.go`

**Interfaces:**
- Produces:
  - `domain.MaxWatches = 20`, `domain.SweepEvery = 30 * time.Minute`, `domain.ArrivalLag = time.Minute`, `domain.SweepBatch = 500`, `domain.MaxNewCount = 99`, `domain.KeepArrivals = 48 * time.Hour`
  - `domain.ErrWatchLimit` (409 `watch_limit_reached`), `domain.ErrWatchNotFound` (404 `watch_not_found`)
  - `events.SearchWatchMatched Kind = "search_watch.matched"` (subject the watch, payload `{"count": int}`)
  - `repository.Watch{ID, Account uuid.UUID; Query string; Phrases []string; Category string; PriceMin, PriceMax int64; Conditions []string; OffersOnly bool; Commune string; RadiusKm int; Alert bool; NewCount int; LastArrival int64; CreatedAt time.Time}`
  - `repository.Arrival{Seq int64; ListingID uuid.UUID}`
  - `repository.Watches`: `Put(ctx, w Watch) (Watch, bool, error)`, `Get(ctx, id) (Watch, bool, error)`, `List(ctx, account) ([]Watch, error)`, `ByKey(ctx, account uuid.UUID, key string) (uuid.UUID, bool, error)`, `SetAlert(ctx, account, id uuid.UUID, on bool) (bool, error)`, `Seen(ctx, account, id uuid.UUID) error`, `Delete(ctx, account, id uuid.UUID) error`, `Clear(ctx, account) error`, `Arrive(ctx, listing uuid.UUID) error`, `Arrivals(ctx, after int64, lag time.Duration, limit int) ([]Arrival, error)`, `Swept(ctx, id uuid.UUID, prev, through int64, n int, at time.Time) (bool, error)`; `repository.NewWatches(db)`

- [ ] **Step 1: Write the failing test**

`internal/discovery/repository/watch_pg_test.go`:

```go
package repository_test

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/shopnexus/server/internal/account/accounttest"
	"github.com/shopnexus/server/internal/discovery/domain"
	"github.com/shopnexus/server/internal/discovery/repository"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
)

func watch(account uuid.UUID, q string) repository.Watch {
	return repository.Watch{
		ID: uuid.NewV7(), Account: account, Query: q, Phrases: []string{q}, Conditions: []string{},
		Alert: true, CreatedAt: now,
	}
}

func TestWatchPutKeepsOnePerKey(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ws := repository.NewWatches(db)
	ctx := context.Background()
	me := accounttest.New(t, db)
	first, created, err := ws.Put(ctx, watch(me, "Xe Đạp"))
	if err != nil || !created {
		t.Fatalf("%v %v", created, err)
	}
	if _, err = db.Exec(ctx, `UPDATE search_watches SET new_count = 4 WHERE id = $1`, first.ID); err != nil {
		t.Fatal(err)
	}
	again := watch(me, "xe dap")
	again.PriceMax, again.Commune, again.RadiusKm = 3_000_000, "00004", 5
	got, created, err := ws.Put(ctx, again)
	if err != nil || created || got.ID != first.ID || got.PriceMax != 3_000_000 || got.RadiusKm != 5 || got.NewCount != 0 || got.Query != "xe dap" {
		t.Fatalf("same key: %+v %v %v", got, created, err)
	}
	id, found, err := ws.ByKey(ctx, me, domain.HistoryKey("XE ĐẠP"))
	if err != nil || !found || id != first.ID {
		t.Fatalf("by key: %v %v %v", id, found, err)
	}
	if found, _ = ws.SetAlert(ctx, me, first.ID, false); !found {
		t.Fatal("mute")
	}
	if found, _ = ws.SetAlert(ctx, accounttest.New(t, db), first.ID, false); found {
		t.Fatal("someone else's watch")
	}
	if l, _ := ws.List(ctx, me); len(l) != 1 || l[0].Alert {
		t.Fatalf("%+v", l)
	}
	if err = ws.Delete(ctx, me, first.ID); err != nil {
		t.Fatal(err)
	}
	if _, found, _ = ws.Get(ctx, first.ID); found {
		t.Fatal("deleted")
	}
}

// Twenty-one watches racing: twenty are stored.
func TestWatchLimit(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ws := repository.NewWatches(db)
	me := accounttest.New(t, db)
	var (
		wg    sync.WaitGroup
		mu    sync.Mutex
		limit int
	)
	for i := range domain.MaxWatches + 1 {
		wg.Go(func() {
			_, _, err := ws.Put(context.Background(), watch(me, "tìm "+string(rune('a'+i))))
			mu.Lock()
			defer mu.Unlock()
			switch {
			case errors.Is(err, domain.ErrWatchLimit):
				limit++
			case err != nil:
				t.Error(err)
			default:
			}
		})
	}
	wg.Wait()
	if l, _ := ws.List(context.Background(), me); len(l) != domain.MaxWatches || limit != 1 {
		t.Fatalf("%d stored, %d refused", len(l), limit)
	}
}

func arrive(t *testing.T, db *pgxpool.Pool, ws repository.Watches, n int) []uuid.UUID {
	t.Helper()
	ls := listings(t, db, n)
	for _, l := range ls {
		for range 2 { // a redelivery adds nothing
			if err := ws.Arrive(context.Background(), l); err != nil {
				t.Fatal(err)
			}
		}
	}
	return ls
}

func TestArrivalsAndSwept(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ws := repository.NewWatches(db)
	ctx := context.Background()
	me := accounttest.New(t, db)
	before := arrive(t, db, ws, 1)
	w, _, err := ws.Put(ctx, watch(me, "xe đạp"))
	if err != nil {
		t.Fatal(err)
	}
	ls := arrive(t, db, ws, 3)
	if a, _ := ws.Arrivals(ctx, w.LastArrival, time.Minute, 10); len(a) != 0 {
		t.Fatalf("younger than the lag: %v", a)
	}
	a, err := ws.Arrivals(ctx, w.LastArrival, 0, 2)
	if err != nil || len(a) != 2 || a[0].ListingID != ls[0] || a[1].ListingID != ls[1] || a[0].ListingID == before[0] {
		t.Fatalf("after the watch, in order, at most 2: %v %v", a, err)
	}
	moved, err := ws.Swept(ctx, w.ID, w.LastArrival, a[1].Seq, 2, now)
	if err != nil || !moved {
		t.Fatal(err)
	}
	if moved, _ = ws.Swept(ctx, w.ID, w.LastArrival, a[1].Seq, 2, now); moved {
		t.Fatal("a replay from the old mark moves nothing")
	}
	got, _, _ := ws.Get(ctx, w.ID)
	if got.NewCount != 2 || got.LastArrival != a[1].Seq {
		t.Fatalf("%+v", got)
	}
	var n int
	if err = db.QueryRow(ctx, `SELECT count(*) FROM events WHERE kind = 'search_watch.matched' AND subject_id = $1
AND (payload->>'count')::int = 2`, w.ID).Scan(&n); err != nil || n != 1 {
		t.Fatalf("%d %v", n, err)
	}
	if _, err = ws.Swept(ctx, w.ID, got.LastArrival, got.LastArrival+1, 200, now); err != nil {
		t.Fatal(err)
	}
	if got, _, _ = ws.Get(ctx, w.ID); got.NewCount != domain.MaxNewCount {
		t.Fatalf("capped: %d", got.NewCount)
	}
	if err = ws.Seen(ctx, me, w.ID); err != nil {
		t.Fatal(err)
	}
	if got, _, _ = ws.Get(ctx, w.ID); got.NewCount != 0 {
		t.Fatalf("seen: %d", got.NewCount)
	}
	if _, err = db.Exec(ctx, `UPDATE listing_arrivals SET arrived_at = now() - interval '3 days' WHERE listing_id = $1`, before[0]); err != nil {
		t.Fatal(err)
	}
	arrive(t, db, ws, 1)
	if err = db.QueryRow(ctx, `SELECT count(*) FROM listing_arrivals WHERE listing_id = $1`, before[0]).Scan(&n); err != nil || n != 0 {
		t.Fatalf("an arrival past two days is deleted: %d %v", n, err)
	}
}
```

A muted watch (`alert` false) moves and writes no event: add to `TestArrivalsAndSwept` after `Seen`:

```go
	if _, err = ws.SetAlert(ctx, me, w.ID, false); err != nil {
		t.Fatal(err)
	}
	got, _, _ = ws.Get(ctx, w.ID)
	if moved, _ = ws.Swept(ctx, w.ID, got.LastArrival, got.LastArrival+1, 1, now); !moved {
		t.Fatal("muted still counts")
	}
	if err = db.QueryRow(ctx, `SELECT count(*) FROM events WHERE kind = 'search_watch.matched' AND subject_id = $1`, w.ID).Scan(&n); err != nil || n != 2 {
		t.Fatalf("muted writes no event: %d %v", n, err)
	}
```

(Two events: the first sweep and the capped one.)

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/discovery/repository/ -run 'TestWatch|TestArrivals'`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the domain and the event kind**

Append to `domain/errors.go`:

```go
// A watch: at most MaxWatches per person, swept every SweepEvery over the
// listings that arrived ArrivalLag ago or earlier, SweepBatch at a time.
// Arrivals are kept KeepArrivals; new_count stops at MaxNewCount, which the
// app shows as "99+".
const (
	MaxWatches   = 20
	SweepEvery   = 30 * time.Minute
	ArrivalLag   = time.Minute
	SweepBatch   = 500
	MaxNewCount  = 99
	KeepArrivals = 48 * time.Hour
)

var (
	ErrWatchLimit    = apperr.New(apperr.KindConflict, "watch_limit_reached", "at most 20 search watches")
	ErrWatchNotFound = apperr.New(apperr.KindNotFound, "watch_not_found", "no such search watch")
)
```

Import `"time"`. In `events.go`, after `SavedPriceDropped`:

```go
	// SearchWatchMatched is a sweep that found new listings for a watch with
	// its alert on; the payload's count is the watch's new_count after it.
	SearchWatchMatched Kind = "search_watch.matched"
```

- [ ] **Step 4: Implement the repository**

Add to `repository.go`:

```go
// Watch is a person's followed search: the query, the phrases the model
// read from it, the filters and a commune. Zero values are no filter.
type Watch struct {
	ID          uuid.UUID
	Account     uuid.UUID
	Query       string
	Phrases     []string
	Category    string
	PriceMin    int64
	PriceMax    int64
	Conditions  []string
	OffersOnly  bool
	Commune     string
	RadiusKm    int
	Alert       bool
	NewCount    int
	LastArrival int64
	CreatedAt   time.Time
}

// Arrival is a listing's first publication, in the order it committed.
type Arrival struct {
	Seq       int64
	ListingID uuid.UUID
}

// Watches persists the search watches and the arrivals they sweep.
type Watches interface {
	// Put stores w under domain.HistoryKey of its query. A new key inserts
	// w with last_arrival at the newest arrival; past domain.MaxWatches it
	// is domain.ErrWatchLimit, counted one at a time per account. A key the
	// account watches takes w's query, phrases and filters, keeps its ID
	// and alert, and sets new_count to 0. It returns the stored watch and
	// whether it is new.
	Put(ctx context.Context, w Watch) (Watch, bool, error)
	Get(ctx context.Context, id uuid.UUID) (Watch, bool, error)
	// List is the account's watches, newest first.
	List(ctx context.Context, account uuid.UUID) ([]Watch, error)
	// ByKey is the ID of account's watch of key.
	ByKey(ctx context.Context, account uuid.UUID, key string) (uuid.UUID, bool, error)
	// SetAlert mutes or unmutes account's watch; found is false for
	// another account's or an unknown one.
	SetAlert(ctx context.Context, account, id uuid.UUID, on bool) (found bool, err error)
	// Seen sets the watch's new_count to 0.
	Seen(ctx context.Context, account, id uuid.UUID) error
	// Delete forgets account's watch; an unknown one is fine.
	Delete(ctx context.Context, account, id uuid.UUID) error
	// Clear deletes every watch of the account.
	Clear(ctx context.Context, account uuid.UUID) error
	// Arrive records listing's first publication, once, and deletes up to
	// 1,000 arrivals older than domain.KeepArrivals.
	Arrive(ctx context.Context, listing uuid.UUID) error
	// Arrivals lists the arrivals after seq after that are older than lag,
	// oldest first, at most limit.
	Arrivals(ctx context.Context, after int64, lag time.Duration, limit int) ([]Arrival, error)
	// Swept moves the watch's last_arrival from prev to through and adds n
	// to new_count, at most domain.MaxNewCount; with n > 0 and the alert on
	// it writes events.SearchWatchMatched, in one transaction. A watch no
	// longer at prev moves nothing, and moved is false.
	Swept(ctx context.Context, id uuid.UUID, prev, through int64, n int, at time.Time) (moved bool, err error)
}
```

`watch_pg.go`:

```go
package repository

import (
	"context"
	"errors"
	"fmt"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	accountdomain "github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/discovery/domain"
	"github.com/shopnexus/server/internal/platform/events"
)

type pgWatches struct{ db *pgxpool.Pool }

func NewWatches(db *pgxpool.Pool) Watches { return pgWatches{db} }

// watchColumns are a Watch's columns in its field order; NULL filters read
// as zero.
const watchColumns = `id, account_id, query, phrases, coalesce(category, ''), coalesce(price_min, 0),
coalesce(price_max, 0), conditions, offers_only, coalesce(commune_code, ''), coalesce(radius_km, 0), alert,
new_count, last_arrival, created_at`

func collectWatches(rows pgx.Rows) ([]Watch, error) {
	ws, err := pgx.CollectRows(rows, pgx.RowToStructByPos[Watch])
	if err != nil {
		return nil, fmt.Errorf("read watches: %w", err)
	}
	return ws, nil
}

func (s pgWatches) Put(ctx context.Context, w Watch) (Watch, bool, error) {
	var (
		out     Watch
		created bool
	)
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		alive, err := living(ctx, tx, w.Account)
		if err != nil {
			return err
		}
		if !alive {
			return accountdomain.ErrSessionRevoked
		}
		if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext('watches:' || @account::text))`,
			pgx.StrictNamedArgs{"account": w.Account}); err != nil {
			return fmt.Errorf("lock account: %w", err)
		}
		args := pgx.StrictNamedArgs{
			"id": w.ID, "account": w.Account, "key": domain.HistoryKey(w.Query), "query": w.Query, "phrases": w.Phrases,
			"category": w.Category, "price_min": w.PriceMin, "price_max": w.PriceMax, "conditions": w.Conditions,
			"offers_only": w.OffersOnly, "commune": w.Commune, "radius": w.RadiusKm, "at": w.CreatedAt,
		}
		rows, err := tx.Query(ctx, `UPDATE search_watches SET query = @query, phrases = @phrases,
    category = NULLIF(@category, ''), price_min = NULLIF(@price_min::bigint, 0), price_max = NULLIF(@price_max::bigint, 0),
    conditions = @conditions, offers_only = @offers_only, commune_code = NULLIF(@commune, ''),
    radius_km = NULLIF(@radius::int, 0), new_count = 0
WHERE account_id = @account AND query_key = @key
RETURNING `+watchColumns, pgx.StrictNamedArgs{
			"account": w.Account, "key": args["key"], "query": w.Query, "phrases": w.Phrases, "category": w.Category,
			"price_min": w.PriceMin, "price_max": w.PriceMax, "conditions": w.Conditions, "offers_only": w.OffersOnly,
			"commune": w.Commune, "radius": w.RadiusKm,
		})
		if err != nil {
			return fmt.Errorf("update watch: %w", err)
		}
		updated, err := collectWatches(rows)
		if err != nil {
			return err
		}
		if len(updated) == 1 {
			out = updated[0]
			return nil
		}
		var n int
		if err = tx.QueryRow(ctx, `SELECT count(*) FROM search_watches WHERE account_id = @account`,
			pgx.StrictNamedArgs{"account": w.Account}).Scan(&n); err != nil {
			return fmt.Errorf("count watches: %w", err)
		}
		if n >= domain.MaxWatches {
			return domain.ErrWatchLimit
		}
		rows, err = tx.Query(ctx, `INSERT INTO search_watches (id, account_id, query_key, query, phrases, category,
    price_min, price_max, conditions, offers_only, commune_code, radius_km, alert, new_count, last_arrival, created_at)
VALUES (@id, @account, @key, @query, @phrases, NULLIF(@category, ''), NULLIF(@price_min::bigint, 0),
    NULLIF(@price_max::bigint, 0), @conditions, @offers_only, NULLIF(@commune, ''), NULLIF(@radius::int, 0), true, 0,
    coalesce((SELECT max(seq) FROM listing_arrivals), 0), @at)
RETURNING `+watchColumns, args)
		if err != nil {
			return fmt.Errorf("insert watch: %w", err)
		}
		inserted, err := collectWatches(rows)
		if err != nil {
			return err
		}
		out, created = inserted[0], true
		return nil
	})
	if err != nil {
		return Watch{}, false, fmt.Errorf("put watch: %w", err)
	}
	return out, created, nil
}

func (s pgWatches) Get(ctx context.Context, id uuid.UUID) (Watch, bool, error) {
	rows, err := s.db.Query(ctx, `SELECT `+watchColumns+` FROM search_watches WHERE id = @id`, pgx.StrictNamedArgs{"id": id})
	if err != nil {
		return Watch{}, false, fmt.Errorf("select watch: %w", err)
	}
	ws, err := collectWatches(rows)
	if err != nil || len(ws) == 0 {
		return Watch{}, false, err
	}
	return ws[0], true, nil
}

func (s pgWatches) List(ctx context.Context, account uuid.UUID) ([]Watch, error) {
	rows, err := s.db.Query(ctx, `SELECT `+watchColumns+` FROM search_watches WHERE account_id = @account ORDER BY id DESC`,
		pgx.StrictNamedArgs{"account": account})
	if err != nil {
		return nil, fmt.Errorf("select watches: %w", err)
	}
	return collectWatches(rows)
}

func (s pgWatches) ByKey(ctx context.Context, account uuid.UUID, key string) (uuid.UUID, bool, error) {
	var id uuid.UUID
	err := s.db.QueryRow(ctx, `SELECT id FROM search_watches WHERE account_id = @account AND query_key = @key`,
		pgx.StrictNamedArgs{"account": account, "key": key}).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return uuid.UUID{}, false, nil
	}
	if err != nil {
		return uuid.UUID{}, false, fmt.Errorf("select watch: %w", err)
	}
	return id, true, nil
}

func (s pgWatches) SetAlert(ctx context.Context, account, id uuid.UUID, on bool) (bool, error) {
	tag, err := s.db.Exec(ctx, `UPDATE search_watches SET alert = @on WHERE id = @id AND account_id = @account`,
		pgx.StrictNamedArgs{"id": id, "account": account, "on": on})
	if err != nil {
		return false, fmt.Errorf("set watch alert: %w", err)
	}
	return tag.RowsAffected() > 0, nil
}

func (s pgWatches) Seen(ctx context.Context, account, id uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `UPDATE search_watches SET new_count = 0 WHERE id = @id AND account_id = @account`,
		pgx.StrictNamedArgs{"id": id, "account": account}); err != nil {
		return fmt.Errorf("see watch: %w", err)
	}
	return nil
}

func (s pgWatches) Delete(ctx context.Context, account, id uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM search_watches WHERE id = @id AND account_id = @account`,
		pgx.StrictNamedArgs{"id": id, "account": account}); err != nil {
		return fmt.Errorf("delete watch: %w", err)
	}
	return nil
}

func (s pgWatches) Clear(ctx context.Context, account uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM search_watches WHERE account_id = @account`,
		pgx.StrictNamedArgs{"account": account}); err != nil {
		return fmt.Errorf("clear watches: %w", err)
	}
	return nil
}

func (s pgWatches) Arrive(ctx context.Context, listing uuid.UUID) error {
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `INSERT INTO listing_arrivals (listing_id) VALUES (@listing) ON CONFLICT (listing_id) DO NOTHING`,
			pgx.StrictNamedArgs{"listing": listing}); err != nil {
			return fmt.Errorf("insert arrival: %w", err)
		}
		if _, err := tx.Exec(ctx, `DELETE FROM listing_arrivals WHERE seq IN (
    SELECT seq FROM listing_arrivals WHERE arrived_at < now() - make_interval(secs => @keep) ORDER BY seq LIMIT 1000)`,
			pgx.StrictNamedArgs{"keep": domain.KeepArrivals.Seconds()}); err != nil {
			return fmt.Errorf("delete old arrivals: %w", err)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("arrive: %w", err)
	}
	return nil
}

func (s pgWatches) Arrivals(ctx context.Context, after int64, lag time.Duration, limit int) ([]Arrival, error) {
	rows, err := s.db.Query(ctx, `SELECT seq, listing_id FROM listing_arrivals
WHERE seq > @after AND arrived_at <= now() - make_interval(secs => @lag) ORDER BY seq LIMIT @limit`,
		pgx.StrictNamedArgs{"after": after, "lag": lag.Seconds(), "limit": limit})
	if err != nil {
		return nil, fmt.Errorf("select arrivals: %w", err)
	}
	as, err := pgx.CollectRows(rows, pgx.RowToStructByPos[Arrival])
	if err != nil {
		return nil, fmt.Errorf("read arrivals: %w", err)
	}
	return as, nil
}

func (s pgWatches) Swept(ctx context.Context, id uuid.UUID, prev, through int64, n int, at time.Time) (bool, error) {
	moved := false
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		var (
			count int
			alert bool
		)
		err := tx.QueryRow(ctx, `UPDATE search_watches SET last_arrival = @through, new_count = least(@max, new_count + @n)
WHERE id = @id AND last_arrival = @prev RETURNING new_count, alert`,
			pgx.StrictNamedArgs{"id": id, "prev": prev, "through": through, "n": n, "max": domain.MaxNewCount}).Scan(&count, &alert)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("update watch: %w", err)
		}
		moved = true
		if n == 0 || !alert {
			return nil
		}
		return events.Insert(ctx, tx, events.Event{
			ID: uuid.NewV7(), Kind: events.SearchWatchMatched, SubjectID: id, Payload: map[string]any{"count": count}, OccurredAt: at,
		})
	})
	if err != nil {
		return false, fmt.Errorf("sweep watch: %w", err)
	}
	return moved, nil
}
```

The `Put` update passes its own argument map because `StrictNamedArgs` refuses names the SQL does not use (`id`, `at`).

- [ ] **Step 5: Run the tests**

Run: `go test ./internal/discovery/repository/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/discovery internal/platform/events
git commit -m "feat(discovery): search watches and listing arrivals in Postgres"
```

---

### Task 7: Watch use cases, `GET /v1/search?watch=` and the API

**Files:**
- Create: `internal/discovery/service/watch.go`, `internal/discovery/service/sweeper.go`
- Modify: `internal/discovery/service/service.go`, `internal/discovery/service/search.go`, `internal/discovery/service/history.go`
- Create: `internal/discovery/handler/watch.go`; Modify: `handler.go`, `search.go` (handler)
- Modify: `internal/discovery/discovery.go`
- Modify: `api/openapi.yaml`, `api/paths/discovery.yaml`, `api/schemas/discovery.yaml`, `api/parameters/discovery.yaml`
- Test: `internal/discovery/service/watch_test.go`, `saved_test.go` (newEnv)

**Interfaces:**
- Consumes: `repository.Watches` (Task 6), `catalogsvc.Service.NearestCommune` and `Filters.IDs`/`Phrase.AllWords` (Task 2), `(*Discovery).exclusions` (Task 4)
- Produces:
  - `service.SweepService = "SearchWatchSweep"`; `service.Sweeper` interface `Schedule(ctx context.Context, watch uuid.UUID) error`; `service.NewSweeper(in *ingress.Client, prefix string) Sweeper`
  - `service.WatchInput{Query, Category string; PriceMin, PriceMax int64; Conditions []catalogdomain.Condition; OffersOnly bool; Near Near; RadiusKm int}`
  - `service.WatchView`, `WatchFilters`, `WatchArea`, `WatchList`
  - `service.Service`: `Watch(ctx, account uuid.UUID, in WatchInput) (WatchView, bool, error)`, `Watches(ctx, account) (WatchList, error)`, `SetWatchAlert(ctx, account, id uuid.UUID, on bool) error`, `Unwatch(ctx, account, id uuid.UUID) error`, `Sweep(ctx, id uuid.UUID) (Swept, error)`, `ListingArrived(ctx, listing uuid.UUID) error`, `WatchFacts(ctx, id uuid.UUID) (WatchFacts, bool, error)`
  - `service.Swept{Found, Full bool}`; `service.WatchFacts{ID, Account uuid.UUID; Query string}`
  - `service.Deps.Watches`, `Sweeps Sweeper`, `ArrivalLag time.Duration`, `SweepBatch int`
  - `SearchInput.Watch uuid.UUID`; `SearchView.WatchID *uuid.UUID` (`watch_id`)

- [ ] **Step 1: Write the failing tests**

In `newEnv`, add to deps: `Watches: repository.NewWatches(db), Sweeps: &sweeps{}, ArrivalLag: 0, SweepBatch: domain.SweepBatch,` and keep the fake in `env.sweeps`. Define in `watch_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"slices"
	"sync"
	"testing"
	"uuid"

	"github.com/shopnexus/server/internal/account/accounttest"
	"github.com/shopnexus/server/internal/catalog/catalogtest"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/discovery/domain"
	"github.com/shopnexus/server/internal/discovery/repository"
	"github.com/shopnexus/server/internal/discovery/service"
)

// sweeps records the watches Schedule was called with.
type sweeps struct {
	mu  sync.Mutex
	ids []uuid.UUID
}

func (s *sweeps) Schedule(_ context.Context, id uuid.UUID) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.ids = append(s.ids, id)
	return nil
}

func (e env) matched(t *testing.T, watch uuid.UUID) int {
	t.Helper()
	var n int
	if err := e.db.QueryRow(context.Background(), `SELECT count(*) FROM events WHERE kind = 'search_watch.matched' AND subject_id = $1`, watch).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

func TestWatchAndSweep(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me := accounttest.New(t, e.db)
	e.model.answers["xe đạp"] = `{"understood":"Xe đạp","boosts":[{"attr":"phrase","values":["xe đạp"]}],"demotes":[]}`
	v, created, err := e.discovery.Watch(ctx, me, service.WatchInput{Query: " xe đạp ", PriceMax: 3_000_000, Near: service.Near{Commune: "00004"}})
	if err != nil || !created || v.Query != "xe đạp" || v.Area == nil || v.Area.CommuneCode != "00004" || v.Area.Name == "" || !v.Alert {
		t.Fatalf("%+v %v %v", v, created, err)
	}
	if len(e.sweeps.ids) != 1 || e.sweeps.ids[0] != v.ID {
		t.Fatalf("a new watch schedules its sweep: %v", e.sweeps.ids)
	}
	bike := catalogtest.Listing(t, e.db, accounttest.New(t, e.db))                                                              // "Xe đạp Asama", 1.5 tr, commune 00004
	motor := catalogtest.Listing(t, e.db, accounttest.New(t, e.db), func(d *catalogdomain.Draft, _ *catalogdomain.Refs) { d.Title = "Xe máy Wave" })
	dear := catalogtest.Listing(t, e.db, accounttest.New(t, e.db), func(d *catalogdomain.Draft, _ *catalogdomain.Refs) { d.Price = 5_000_000 })
	hidden := catalogtest.Listing(t, e.db, accounttest.New(t, e.db))
	if err = e.discovery.Hide(ctx, me, hidden); err != nil {
		t.Fatal(err)
	}
	for _, l := range []uuid.UUID{bike, motor, dear, hidden} {
		if err = e.discovery.ListingArrived(ctx, l); err != nil {
			t.Fatal(err)
		}
	}
	r, err := e.discovery.Sweep(ctx, v.ID)
	if err != nil || !r.Found || r.Full {
		t.Fatalf("%+v %v", r, err)
	}
	r, err = e.discovery.Sweep(ctx, v.ID) // nothing new arrived
	if err != nil || !r.Found {
		t.Fatal(err)
	}
	l, err := e.discovery.Watches(ctx, me)
	if err != nil || len(l.Items) != 1 || l.Items[0].NewCount != 1 || e.matched(t, v.ID) != 1 {
		t.Fatalf("the bicycle alone, once: %+v %v %d", l, err, e.matched(t, v.ID))
	}
	sv, err := e.discovery.Search(ctx, &me, service.SearchInput{Watch: v.ID})
	if err != nil || !slices.Contains(ids(sv), bike) || slices.Contains(ids(sv), dear) || sv.WatchID == nil || *sv.WatchID != v.ID {
		t.Fatalf("?watch=: %v %+v %v", ids(sv), sv.WatchID, err)
	}
	if l, _ = e.discovery.Watches(ctx, me); l.Items[0].NewCount != 0 {
		t.Fatalf("the first page sees the watch: %+v", l)
	}
	if err = e.discovery.SetWatchAlert(ctx, me, v.ID, false); err != nil {
		t.Fatal(err)
	}
	if err = e.discovery.ListingArrived(ctx, catalogtest.Listing(t, e.db, accounttest.New(t, e.db))); err != nil {
		t.Fatal(err)
	}
	if _, err = e.discovery.Sweep(ctx, v.ID); err != nil {
		t.Fatal(err)
	}
	if l, _ = e.discovery.Watches(ctx, me); l.Items[0].NewCount != 1 || e.matched(t, v.ID) != 1 {
		t.Fatalf("muted counts and tells nothing: %+v", l)
	}
	f, found, err := e.discovery.WatchFacts(ctx, v.ID)
	if err != nil || !found || f.Account != me || f.Query != "xe đạp" {
		t.Fatalf("%+v %v %v", f, found, err)
	}
	if err = e.discovery.Unwatch(ctx, me, v.ID); err != nil {
		t.Fatal(err)
	}
	if r, _ = e.discovery.Sweep(ctx, v.ID); r.Found {
		t.Fatal("a deleted watch ends its chain")
	}
	again, created, err := e.discovery.Watch(ctx, me, service.WatchInput{Query: "xe đạp"})
	if err != nil || !created || again.ID == v.ID {
		t.Fatalf("watching again after unwatch is a new watch: %+v %v %v", again, created, err)
	}
}

func TestSweepFullBatch(t *testing.T) {
	t.Parallel()
	e := newEnv(t, func(d *service.Deps) { d.SweepBatch = 2 })
	ctx := context.Background()
	me := accounttest.New(t, e.db)
	v, _, err := e.discovery.Watch(ctx, me, service.WatchInput{Query: "xe đạp"})
	if err != nil {
		t.Fatal(err)
	}
	for range 3 {
		if err = e.discovery.ListingArrived(ctx, catalogtest.Listing(t, e.db, accounttest.New(t, e.db))); err != nil {
			t.Fatal(err)
		}
	}
	if r, _ := e.discovery.Sweep(ctx, v.ID); !r.Full {
		t.Fatal("two of three: full")
	}
	if r, _ := e.discovery.Sweep(ctx, v.ID); r.Full {
		t.Fatal("the last one: not full")
	}
	if l, _ := e.discovery.Watches(ctx, me); l.Items[0].NewCount != 3 {
		t.Fatalf("%+v", l)
	}
}

func TestWatchRefusals(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me := accounttest.New(t, e.db)
	for name, c := range map[string]struct {
		in   service.WatchInput
		want error
	}{
		"price range":        {service.WatchInput{Query: "a", PriceMin: 2, PriceMax: 1}, domain.ErrInvalidPriceRange},
		"radius, no place":   {service.WatchInput{Query: "a", RadiusKm: 5}, domain.ErrPositionRequired},
		"unknown commune":    {service.WatchInput{Query: "a", Near: service.Near{Commune: "99999"}}, domain.ErrInvalidPosition},
		"abroad":             {service.WatchInput{Query: "a", Near: service.Near{Lat: 48.85, Lng: 2.35}}, domain.ErrInvalidPosition},
		"lat without lng":    {service.WatchInput{Query: "a", Near: service.Near{Lat: 21.03}}, domain.ErrInvalidPosition},
	} {
		if _, _, err := e.discovery.Watch(ctx, me, c.in); !errors.Is(err, c.want) {
			t.Errorf("%s: %v", name, err)
		}
	}
	v, _, err := e.discovery.Watch(ctx, me, service.WatchInput{Query: "xe", Near: service.Near{Lat: baDinh.Lat, Lng: baDinh.Lng}})
	if err != nil || v.Area == nil {
		t.Fatalf("a GPS point becomes its commune: %+v %v", v, err)
	}
	var stored string
	if err = e.db.QueryRow(ctx, `SELECT coalesce(commune_code, '') FROM search_watches WHERE id = $1`, v.ID).Scan(&stored); err != nil || stored != v.Area.CommuneCode {
		t.Fatalf("%q %v", stored, err)
	}
	other := accounttest.New(t, e.db)
	if err = e.discovery.SetWatchAlert(ctx, other, v.ID, false); !errors.Is(err, domain.ErrWatchNotFound) {
		t.Fatalf("someone else's: %v", err)
	}
	if _, err = e.discovery.Search(ctx, &other, service.SearchInput{Watch: v.ID}); !errors.Is(err, domain.ErrWatchNotFound) {
		t.Fatalf("?watch= of someone else's: %v", err)
	}
	if _, err = e.discovery.Search(ctx, &me, service.SearchInput{Watch: v.ID, Query: "x"}); !errors.Is(err, domain.ErrSearchConflict) {
		t.Fatalf("?watch= with q: %v", err)
	}
	_ = repository.Watch{}
}
```

Remove the last line and the `repository` import; nothing else in the file uses the package. The first test's watch names commune 00004 without a radius, so the sweep filters by price and words only: `catalogtest.Listing` leaves `Refs.CommunePoint` zero, and a radius would measure from a listing point at 0,0. The repository test of Task 6 covers a stored radius.

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/discovery/service/ -run 'TestWatch|TestSweep'`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the sweeper**

`internal/discovery/service/sweeper.go`:

```go
package service

import (
	"context"
	"fmt"
	"uuid"

	restate "github.com/restatedev/sdk-go"
	"github.com/restatedev/sdk-go/ingress"

	"github.com/shopnexus/server/internal/discovery/domain"
)

// SweepService is the Restate service that sweeps one watch, without the
// prefix; worker.SearchWatchSweep serves it.
const SweepService = "SearchWatchSweep"

// Sweeper starts a new watch's chain of sweeps.
type Sweeper interface {
	Schedule(ctx context.Context, watch uuid.UUID) error
}

type restateSweeper struct {
	ingress *ingress.Client
	name    string
}

func NewSweeper(in *ingress.Client, prefix string) Sweeper {
	return restateSweeper{ingress: in, name: prefix + SweepService}
}

// Schedule sends the watch's first sweep, domain.SweepEvery from now, keyed
// by the watch, so a retried POST starts one chain.
func (s restateSweeper) Schedule(ctx context.Context, watch uuid.UUID) error {
	if _, err := ingress.ServiceSend[uuid.UUID](s.ingress, s.name, "Run").
		Send(ctx, watch, restate.WithDelay(domain.SweepEvery), restate.WithIdempotencyKey(watch.String())); err != nil {
		return fmt.Errorf("schedule the sweep: %w", err)
	}
	return nil
}
```

The first sweep is sent before the row exists, as media schedules an upload's expiry: no watch is left without a chain, and a sweep that finds no row (a re-watch of an existing key kept the old ID) ends at once.

- [ ] **Step 4: Implement the use cases**

In `service.go`, add to `Service`:

```go
	// Watch follows a text search with its filters from a commune: a new
	// key is a new watch and starts its sweeps; a key the account watches
	// takes the new filters. created reports a new watch.
	Watch(ctx context.Context, account uuid.UUID, in WatchInput) (v WatchView, created bool, err error)
	// Watches lists the account's watches, newest first.
	Watches(ctx context.Context, account uuid.UUID) (WatchList, error)
	// SetWatchAlert mutes or unmutes a watch of the account's.
	SetWatchAlert(ctx context.Context, account, id uuid.UUID, on bool) error
	// Unwatch forgets a watch; an unknown one is fine.
	Unwatch(ctx context.Context, account, id uuid.UUID) error
	// Sweep weighs the listings that arrived since the watch's last sweep;
	// the worker calls it.
	Sweep(ctx context.Context, id uuid.UUID) (Swept, error)
	// ListingArrived records a listing's first publication for the sweeps.
	ListingArrived(ctx context.Context, listing uuid.UUID) error
	// WatchFacts is what notification tells of a watch's new listings.
	WatchFacts(ctx context.Context, id uuid.UUID) (WatchFacts, bool, error)
```

Add to `Deps`:

```go
	Watches repository.Watches
	// Sweeps starts a new watch's sweeps.
	Sweeps Sweeper
	// ArrivalLag and SweepBatch are domain.ArrivalLag and domain.SweepBatch
	// in production; tests shorten them.
	ArrivalLag time.Duration
	SweepBatch int
```

and the matching unexported fields and `New` assignments (`watches`, `sweeps`, `arrivalLag`, `sweepBatch`).

Extract the model read from `Search` into a helper that `Search` and `Watch` both call. In `search.go`, replace the block from `var u domain.Understanding` to the end of `if !understood {...}` with `u, understood := d.understand(ctx, q, categories, now)` and add:

```go
// understand is the model's reading of q, from the cache when the same query
// was read within domain.CacheTTL, and whether the model answered. A model
// that errs or takes longer than the timeout gives the zero reading.
func (d *Discovery) understand(ctx context.Context, q string, categories []catalogdomain.Category, now time.Time) (domain.Understanding, bool) {
	var u domain.Understanding
	key := domain.QueryKey(q)
	cached, found, err := d.understandings.Get(ctx, key, domain.PromptVersion, now.Add(-domain.CacheTTL))
	switch {
	case err != nil:
		d.log.WarnContext(ctx, "read the cached understanding", "err", err)
	case found && json.Unmarshal(cached, &u) == nil:
		return u, true
	default:
	}
	u = domain.Understanding{}
	mctx, cancel := context.WithTimeout(ctx, d.modelTimeout)
	err = d.llm.Complete(mctx, llm.Request{
		System: domain.SystemPrompt(categories, now), User: q, SchemaName: "search_understanding", Schema: domain.Schema(),
	}, &u)
	cancel()
	if err != nil {
		d.log.WarnContext(ctx, "the model did not read the query", "err", err)
		return domain.Understanding{}, false
	}
	answer, err := json.Marshal(u)
	if err == nil {
		err = d.understandings.Put(ctx, key, domain.PromptVersion, answer, now, now.Add(-domain.CacheTTL))
	}
	if err != nil {
		d.log.WarnContext(ctx, "cache the understanding", "err", err)
	}
	return u, true
}
```

Import `"time"` in `search.go`. Also extract the category split, which `Search` and `Sweep` both need:

```go
// category sets f's root or subcategory from a code: a subcategory has a
// dot.
func category(f *catalogdomain.Filters, code string) {
	if strings.Contains(code, ".") {
		f.CategoryCode = code
	} else {
		f.CategoryRoot = code
	}
}
```

and replace the `if strings.Contains(in.Category, ".") {...}` in `Search` with `category(&filters, in.Category)`.

In `Search`, at the top, before `q := strings.TrimSpace(in.Query)`:

```go
	if in.Watch != uuid.Nil() {
		if in.Query != "" || in.Category != "" || in.PriceMin != 0 || in.PriceMax != 0 || len(in.Conditions) > 0 ||
			in.RadiusKm != 0 || in.OffersOnly || in.Near != (Near{}) || in.Photo != uuid.Nil() || in.Like != uuid.Nil() {
			return SearchView{}, domain.ErrSearchConflict
		}
		if viewer == nil {
			return SearchView{}, authn.ErrUnauthenticated
		}
		w, found, err := d.watches.Get(ctx, in.Watch)
		if err != nil {
			return SearchView{}, fmt.Errorf("read the watch: %w", err)
		}
		if !found || w.Account != *viewer {
			return SearchView{}, domain.ErrWatchNotFound
		}
		in.Query, in.Category, in.PriceMin, in.PriceMax = w.Query, w.Category, w.PriceMin, w.PriceMax
		in.OffersOnly, in.RadiusKm, in.Near = w.OffersOnly, w.RadiusKm, Near{Commune: w.Commune}
		in.Conditions = make([]catalogdomain.Condition, len(w.Conditions))
		for i, c := range w.Conditions {
			in.Conditions[i] = catalogdomain.Condition(c)
		}
	}
```

At the end of `Search`, before `return view, nil`:

```go
	if viewer != nil && q != "" {
		id, found, err := d.watches.ByKey(ctx, *viewer, domain.HistoryKey(q))
		switch {
		case err != nil:
			d.log.WarnContext(ctx, "read the watch of the query", "err", err)
		case found:
			view.WatchID = &id
		default:
		}
	}
	if in.Watch != uuid.Nil() && in.Cursor == "" {
		if err = d.watches.Seen(ctx, *viewer, in.Watch); err != nil {
			d.log.WarnContext(ctx, "see the watch", "err", err)
		}
	}
```

Add to `SearchInput`: `Watch uuid.UUID // zero for none: a watch of the viewer's, which brings its query and filters`. Add to `SearchView`: `WatchID *uuid.UUID `json:"watch_id,omitempty"``.

`internal/discovery/service/watch.go`:

```go
package service

import (
	"context"
	"fmt"
	"strings"
	"time"
	"uuid"

	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/discovery/domain"
	"github.com/shopnexus/server/internal/discovery/repository"
)

// WatchInput is a search the person follows, as POST /v1/search/watches
// gives it. Near is turned into a commune and not kept.
type WatchInput struct {
	Query              string
	Category           string
	PriceMin, PriceMax int64
	Conditions         []catalogdomain.Condition
	OffersOnly         bool
	Near               Near
	RadiusKm           int
}

// WatchView is the SearchWatch schema.
type WatchView struct {
	ID        uuid.UUID    `json:"id"`
	Query     string       `json:"query"`
	Filters   WatchFilters `json:"filters"`
	Area      *WatchArea   `json:"area,omitempty"`
	RadiusKm  int          `json:"radius_km,omitempty"`
	NewCount  int          `json:"new_count"`
	Alert     bool         `json:"alert"`
	CreatedAt time.Time    `json:"created_at"`
}

// WatchFilters are the filters a watch keeps; each is absent when unset.
type WatchFilters struct {
	Category   string                    `json:"category,omitempty"`
	PriceMin   int64                     `json:"price_min,omitempty"`
	PriceMax   int64                     `json:"price_max,omitempty"`
	Conditions []catalogdomain.Condition `json:"conditions,omitempty"`
	OffersOnly bool                      `json:"offers_only,omitempty"`
}

// WatchArea is the commune a watch searches from.
type WatchArea struct {
	CommuneCode string `json:"commune_code"`
	Name        string `json:"name"`
}

// WatchList is the SearchWatchList schema.
type WatchList struct {
	Items []WatchView `json:"items"`
}

// Swept is what one sweep did: Found is false for a watch gone, which ends
// its chain, and Full when it read a whole batch, so more may wait.
type Swept struct {
	Found bool `json:"found"`
	Full  bool `json:"full"`
}

// WatchFacts is what a notice of a watch's new listings needs.
type WatchFacts struct {
	ID      uuid.UUID `json:"id"`
	Account uuid.UUID `json:"account"`
	Query   string    `json:"query"`
}

// Watch resolves the place to a commune, reads the query's phrases through
// the model, schedules the sweep of a new ID and stores the watch.
func (d *Discovery) Watch(ctx context.Context, account uuid.UUID, in WatchInput) (WatchView, bool, error) {
	q := strings.TrimSpace(in.Query)
	if in.PriceMin > 0 && in.PriceMax > 0 && in.PriceMin > in.PriceMax {
		return WatchView{}, false, domain.ErrInvalidPriceRange
	}
	commune := in.Near.Commune
	switch {
	case in.Near.Lat != 0 || in.Near.Lng != 0:
		if in.Near.Lat == 0 || in.Near.Lng == 0 || in.Near.Lat < -90 || in.Near.Lat > 90 || in.Near.Lng < -180 || in.Near.Lng > 180 {
			return WatchView{}, false, domain.ErrInvalidPosition
		}
		code, km, err := d.catalog.NearestCommune(ctx, catalogdomain.Point{Lat: in.Near.Lat, Lng: in.Near.Lng})
		if err != nil {
			return WatchView{}, false, fmt.Errorf("find the commune: %w", err)
		}
		if km > catalogdomain.MaxGPSKm {
			return WatchView{}, false, domain.ErrInvalidPosition
		}
		commune = code
	case commune != "":
		places, err := d.catalog.Places(ctx, []string{commune})
		if err != nil {
			return WatchView{}, false, fmt.Errorf("read the commune: %w", err)
		}
		if _, ok := places[commune]; !ok {
			return WatchView{}, false, domain.ErrInvalidPosition
		}
	default:
	}
	if in.RadiusKm > 0 && commune == "" {
		return WatchView{}, false, domain.ErrPositionRequired
	}
	now := d.now()
	categories, err := d.catalog.Categories(ctx)
	if err != nil {
		return WatchView{}, false, fmt.Errorf("read categories: %w", err)
	}
	u, _ := d.understand(ctx, q, categories, now)
	names := make(map[string]string, len(categories))
	for _, c := range categories {
		names[c.Code] = c.DisplayName
	}
	var phrases []string
	for _, p := range domain.Compile(u, q, domain.Vocabulary{Categories: names}, nil, now, nil).Phrases {
		if p.Weight > 0 && !slices.Contains(phrases, p.Text) {
			phrases = append(phrases, p.Text)
		}
	}
	conditions := make([]string, len(in.Conditions))
	for i, c := range in.Conditions {
		conditions[i] = string(c)
	}
	id := uuid.NewV7()
	if err = d.sweeps.Schedule(ctx, id); err != nil {
		return WatchView{}, false, err
	}
	w, created, err := d.watches.Put(ctx, repository.Watch{
		ID: id, Account: account, Query: q, Phrases: phrases, Category: in.Category, PriceMin: in.PriceMin,
		PriceMax: in.PriceMax, Conditions: conditions, OffersOnly: in.OffersOnly, Commune: commune,
		RadiusKm: in.RadiusKm, Alert: true, CreatedAt: now,
	})
	if err != nil {
		return WatchView{}, false, fmt.Errorf("store the watch: %w", err)
	}
	views, err := d.watchViews(ctx, []repository.Watch{w})
	if err != nil {
		return WatchView{}, false, err
	}
	return views[0], created, nil
}

func (d *Discovery) Watches(ctx context.Context, account uuid.UUID) (WatchList, error) {
	ws, err := d.watches.List(ctx, account)
	if err != nil {
		return WatchList{}, fmt.Errorf("list watches: %w", err)
	}
	views, err := d.watchViews(ctx, ws)
	if err != nil {
		return WatchList{}, err
	}
	return WatchList{Items: views}, nil
}

func (d *Discovery) SetWatchAlert(ctx context.Context, account, id uuid.UUID, on bool) error {
	found, err := d.watches.SetAlert(ctx, account, id, on)
	if err != nil {
		return fmt.Errorf("set watch alert: %w", err)
	}
	if !found {
		return domain.ErrWatchNotFound
	}
	return nil
}

func (d *Discovery) Unwatch(ctx context.Context, account, id uuid.UUID) error {
	if err := d.watches.Delete(ctx, account, id); err != nil {
		return fmt.Errorf("unwatch: %w", err)
	}
	return nil
}

func (d *Discovery) ListingArrived(ctx context.Context, listing uuid.UUID) error {
	if err := d.watches.Arrive(ctx, listing); err != nil {
		return fmt.Errorf("record the arrival: %w", err)
	}
	return nil
}

func (d *Discovery) WatchFacts(ctx context.Context, id uuid.UUID) (WatchFacts, bool, error) {
	w, found, err := d.watches.Get(ctx, id)
	if err != nil || !found {
		return WatchFacts{}, false, err
	}
	return WatchFacts{ID: w.ID, Account: w.Account, Query: w.Query}, true, nil
}

// Sweep reads the arrivals after the watch's mark, keeps those that match
// its filters and every word of one of its phrases, less the watcher's own,
// hidden and blocked listings, and moves the mark. A retried sweep after
// the move reads the next arrivals; one before it finds the mark where it
// was. A sweep counts the matches and tells through the event Swept writes.
func (d *Discovery) Sweep(ctx context.Context, id uuid.UUID) (Swept, error) {
	w, found, err := d.watches.Get(ctx, id)
	if err != nil {
		return Swept{}, fmt.Errorf("read the watch: %w", err)
	}
	if !found {
		return Swept{}, nil
	}
	arrivals, err := d.watches.Arrivals(ctx, w.LastArrival, d.arrivalLag, d.sweepBatch)
	if err != nil {
		return Swept{}, fmt.Errorf("read arrivals: %w", err)
	}
	if len(arrivals) == 0 {
		return Swept{Found: true}, nil
	}
	ids := make([]uuid.UUID, len(arrivals))
	for i, a := range arrivals {
		ids[i] = a.ListingID
	}
	hidden, sellers, err := d.exclusions(ctx, w.Account)
	if err != nil {
		return Swept{}, err
	}
	search := catalogdomain.Search{
		Filters: catalogdomain.Filters{PriceMin: w.PriceMin, PriceMax: w.PriceMax, OffersOnly: w.OffersOnly, IDs: ids},
		Sort:    catalogdomain.SortNewest, Limit: len(ids),
		ExcludeListings: hidden, ExcludeSellers: append(sellers, w.Account),
	}
	category(&search.Filters, w.Category)
	for _, c := range w.Conditions {
		search.Filters.Conditions = append(search.Filters.Conditions, catalogdomain.Condition(c))
	}
	if w.Commune != "" && w.RadiusKm > 0 {
		places, placeErr := d.catalog.Places(ctx, []string{w.Commune})
		if placeErr != nil {
			return Swept{}, fmt.Errorf("read the commune: %w", placeErr)
		}
		if loc, ok := places[w.Commune]; ok {
			search.Filters.Origin, search.Filters.RadiusKm = &catalogdomain.Point{Lat: loc.Lat, Lng: loc.Lng}, w.RadiusKm
		}
	}
	for _, p := range w.Phrases {
		search.Phrases = append(search.Phrases, catalogdomain.Phrase{Text: p, Weight: 1, AllWords: true})
	}
	if len(search.Phrases) == 0 {
		search.Phrases = []catalogdomain.Phrase{{Text: w.Query, Weight: 1, AllWords: true}}
	}
	cards, err := d.catalog.Search(ctx, search)
	if err != nil {
		return Swept{}, fmt.Errorf("match the arrivals: %w", err)
	}
	if _, err = d.watches.Swept(ctx, id, w.LastArrival, arrivals[len(arrivals)-1].Seq, len(cards), d.now()); err != nil {
		return Swept{}, fmt.Errorf("move the watch: %w", err)
	}
	return Swept{Found: true, Full: len(arrivals) == d.sweepBatch}, nil
}

// watchViews names the watches' communes in one read; Watch and Watches
// call it.
func (d *Discovery) watchViews(ctx context.Context, ws []repository.Watch) ([]WatchView, error) {
	var codes []string
	for _, w := range ws {
		if w.Commune != "" {
			codes = append(codes, w.Commune)
		}
	}
	places, err := d.catalog.Places(ctx, codes)
	if err != nil {
		return nil, fmt.Errorf("read communes: %w", err)
	}
	out := make([]WatchView, len(ws))
	for i, w := range ws {
		v := WatchView{
			ID: w.ID, Query: w.Query, RadiusKm: w.RadiusKm, NewCount: w.NewCount, Alert: w.Alert, CreatedAt: w.CreatedAt,
			Filters: WatchFilters{Category: w.Category, PriceMin: w.PriceMin, PriceMax: w.PriceMax, OffersOnly: w.OffersOnly},
		}
		for _, c := range w.Conditions {
			v.Filters.Conditions = append(v.Filters.Conditions, catalogdomain.Condition(c))
		}
		if loc, ok := places[w.Commune]; ok {
			v.Area = &WatchArea{CommuneCode: w.Commune, Name: loc.Commune.DisplayName}
		}
		out[i] = v
	}
	return out, nil
}
```

Import `"slices"`. In `history.go`'s `AccountDeleted`, add `d.watches.Clear(ctx, account)` with the same wrapping.

In `discovery.go`'s `Mount`, set `Watches: repository.NewWatches(d.Pool), Sweeps: service.NewSweeper(d.Ingress, d.ServicePrefix), ArrivalLag: domain.ArrivalLag, SweepBatch: domain.SweepBatch`.

Run: `go test ./internal/discovery/service/` → PASS, the existing search tests included.

- [ ] **Step 5: Write the API**

`api/openapi.yaml`, after `/v1/search/history/{id}`:

```yaml
  /v1/search/watches:
    $ref: "paths/discovery.yaml#/searchWatches"
  /v1/search/watches/{id}:
    $ref: "paths/discovery.yaml#/searchWatch"
  /v1/search/watches/{id}/mute:
    $ref: "paths/discovery.yaml#/searchWatchMute"
  /v1/search/watches/{id}/unmute:
    $ref: "paths/discovery.yaml#/searchWatchUnmute"
```

`api/parameters/discovery.yaml`, append:

```yaml
SearchWatch:
  name: watch
  in: query
  description: |
    A search watch of the caller's: search its query and filters from its
    commune. Goes with cursor, limit, sort and off only, and needs a
    signed-in caller. The first page sets the watch's new_count to 0.
  schema:
    type: string
    format: uuid
WatchID:
  name: id
  in: path
  required: true
  schema:
    type: string
    format: uuid
```

In the `search` operation: add `- $ref: "../parameters/discovery.yaml#/SearchWatch"` to `parameters`; extend the 400 description with "or watch with any parameter but cursor, limit, sort and off"; extend 401 to the shared one (it is already `$ref` Unauthorized, used for `photo`; add "photo or watch signed out" to the operation description); change the 404 description to `"listing_not_found: like names a listing that is not on sale or reserved; watch_not_found: watch is not a watch of the caller's."`.

`api/paths/discovery.yaml`, append:

```yaml
searchWatches:
  post:
    operationId: createSearchWatch
    summary: Follow a text search with its filters; the same words again replace the filters.
    description: |
      One watch per query, folded as the search history folds it. A GPS
      point is turned into its nearest commune and not kept. A sweep every 30
      minutes counts the new listings holding every word of the query or of a
      phrase the model read from it, under the filters, and tells the caller
      while the watch is not muted.
    tags: [discovery]
    security:
      - bearerAuth: []
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/discovery.yaml#/SearchWatchInput"
    responses:
      "200":
        description: The watch of the same query, with the new filters.
        content:
          application/json:
            schema:
              $ref: "../schemas/discovery.yaml#/SearchWatch"
      "201":
        description: A new watch.
        content:
          application/json:
            schema:
              $ref: "../schemas/discovery.yaml#/SearchWatch"
      "400":
        description: "A malformed body, invalid_price_range, invalid_position (no commune within 30 km of the point, or an unknown commune), or position_required (radius_km without a place)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "409":
        description: "The caller has 20 watches (watch_limit_reached)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
  get:
    operationId: listSearchWatches
    summary: The caller's watches, newest first.
    tags: [discovery]
    security:
      - bearerAuth: []
    responses:
      "200":
        description: The watches.
        content:
          application/json:
            schema:
              $ref: "../schemas/discovery.yaml#/SearchWatchList"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
searchWatch:
  delete:
    operationId: deleteSearchWatch
    summary: Stop following a search; an unknown watch is fine.
    tags: [discovery]
    security:
      - bearerAuth: []
    parameters:
      - $ref: "../parameters/discovery.yaml#/WatchID"
    responses:
      "204":
        description: Forgotten.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
searchWatchMute:
  post:
    operationId: muteSearchWatch
    summary: Keep counting the watch's new listings without telling the caller.
    tags: [discovery]
    security:
      - bearerAuth: []
    parameters:
      - $ref: "../parameters/discovery.yaml#/WatchID"
    responses:
      "204":
        description: Muted.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "Not a watch of the caller's (watch_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
searchWatchUnmute:
  post:
    operationId: unmuteSearchWatch
    summary: Tell the caller of the watch's new listings again.
    tags: [discovery]
    security:
      - bearerAuth: []
    parameters:
      - $ref: "../parameters/discovery.yaml#/WatchID"
    responses:
      "204":
        description: Unmuted.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "Not a watch of the caller's (watch_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

`api/schemas/discovery.yaml`: add to `SearchView.properties`:

```yaml
    watch_id:
      type: string
      format: uuid
      description: The caller's watch of this query; absent signed out or when there is none.
```

and append:

```yaml
SearchWatchInput:
  type: object
  additionalProperties: false
  required: [q]
  properties:
    q:
      type: string
      minLength: 1
      maxLength: 200
      pattern: '\S'
    category:
      type: string
      description: A root or subcategory code from GET /v1/categories.
    price_min:
      type: integer
      format: int64
      minimum: 0
    price_max:
      type: integer
      format: int64
      minimum: 0
    condition:
      type: array
      items:
        $ref: "catalog.yaml#/Condition"
    offers_only:
      type: boolean
    near_commune:
      type: string
    near_lat:
      type: number
      minimum: -90
      maximum: 90
      description: With near_lng; turned into its nearest commune and not kept.
    near_lng:
      type: number
      minimum: -180
      maximum: 180
    radius_km:
      type: integer
      minimum: 1
      maximum: 200
      description: Needs a place.
SearchWatchFilters:
  type: object
  additionalProperties: false
  properties:
    category:
      type: string
    price_min:
      type: integer
      format: int64
    price_max:
      type: integer
      format: int64
    conditions:
      type: array
      items:
        $ref: "catalog.yaml#/Condition"
    offers_only:
      type: boolean
SearchWatch:
  type: object
  additionalProperties: false
  required: [id, query, filters, new_count, alert, created_at]
  properties:
    id:
      type: string
      format: uuid
    query:
      type: string
      description: The words as the caller typed them, trimmed.
    filters:
      $ref: "#/SearchWatchFilters"
    area:
      type: object
      additionalProperties: false
      required: [commune_code, name]
      description: The commune the watch searches from; absent without a place.
      properties:
        commune_code:
          type: string
        name:
          type: string
    radius_km:
      type: integer
    new_count:
      type: integer
      minimum: 0
      maximum: 99
      description: New listings since the caller last opened the watch; 99 means 99 or more.
    alert:
      type: boolean
      description: False when muted.
    created_at:
      type: string
      format: date-time
SearchWatchList:
  type: object
  additionalProperties: false
  required: [items]
  properties:
    items:
      type: array
      maxItems: 20
      items:
        $ref: "#/SearchWatch"
```

The input's field is `condition`, as on `GET /v1/search`; the view's is `conditions`, as the service's `WatchFilters` writes it.

- [ ] **Step 6: Write the handlers**

`internal/discovery/handler/watch.go`:

```go
package handler

import (
	"net/http"
	"uuid"

	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/discovery/service"
	"github.com/shopnexus/server/internal/platform/httpx"
)

// watchRequest is a search to follow. The position reaches the service and
// no log.
type watchRequest struct {
	Query       string                    `json:"q"`
	Category    string                    `json:"category"`
	PriceMin    int64                     `json:"price_min"`
	PriceMax    int64                     `json:"price_max"`
	Conditions  []catalogdomain.Condition `json:"condition"`
	OffersOnly  bool                      `json:"offers_only"`
	NearCommune string                    `json:"near_commune"`
	NearLat     float64                   `json:"near_lat"`
	NearLng     float64                   `json:"near_lng"`
	RadiusKm    int                       `json:"radius_km"`
}

// Watch serves POST /v1/search/watches: 201 for a new watch, 200 for one
// that took new filters.
func (h *Handler) Watch(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in watchRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	out, created, err := h.svc.Watch(r.Context(), p.AccountID, service.WatchInput{
		Query: in.Query, Category: in.Category, PriceMin: in.PriceMin, PriceMax: in.PriceMax, Conditions: in.Conditions,
		OffersOnly: in.OffersOnly, Near: service.Near{Lat: in.NearLat, Lng: in.NearLng, Commune: in.NearCommune}, RadiusKm: in.RadiusKm,
	})
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	status := http.StatusOK
	if created {
		status = http.StatusCreated
	}
	httpx.Respond(w, status, out)
}

// Watches serves GET /v1/search/watches.
func (h *Handler) Watches(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	out, err := h.svc.Watches(r.Context(), p.AccountID)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, out)
}

type watchIDRequest struct {
	ID uuid.UUID `json:"-" path:"id"`
}

// Unwatch serves DELETE /v1/search/watches/{id}.
func (h *Handler) Unwatch(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in watchIDRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.Unwatch(r.Context(), p.AccountID, in.ID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Mute serves POST /v1/search/watches/{id}/mute.
func (h *Handler) Mute(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in watchIDRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.SetWatchAlert(r.Context(), p.AccountID, in.ID, false); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Unmute serves POST /v1/search/watches/{id}/unmute.
func (h *Handler) Unmute(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in watchIDRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.SetWatchAlert(r.Context(), p.AccountID, in.ID, true); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

In `Register`, before the history routes:

```go
	r.Handle("POST /v1/search/watches", protect(http.HandlerFunc(h.Watch)))
	r.Handle("GET /v1/search/watches", protect(http.HandlerFunc(h.Watches)))
	r.Handle("DELETE /v1/search/watches/{id}", protect(http.HandlerFunc(h.Unwatch)))
	r.Handle("POST /v1/search/watches/{id}/mute", protect(http.HandlerFunc(h.Mute)))
	r.Handle("POST /v1/search/watches/{id}/unmute", protect(http.HandlerFunc(h.Unmute)))
```

In `handler/search.go`, add `Watch uuid.UUID `json:"-" query:"watch"`` to `searchRequest` and `Watch: in.Watch` to the `SearchInput`.

- [ ] **Step 7: Run the tests**

Run: `go test ./api/... ./internal/discovery/... ./internal/screen/...`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add api internal/discovery
git commit -m "feat(discovery): search watches, their sweep use case and GET /v1/search?watch="
```

---

### Task 8: Discovery's Restate services: listing events and the sweep chain

**Files:**
- Create: `internal/discovery/worker/listing.go`, `internal/discovery/worker/sweep.go`
- Modify: `internal/discovery/discovery.go`
- Test: `internal/discovery/worker/listing_test.go`, `internal/discovery/worker/sweep_test.go`

**Interfaces:**
- Consumes: `service.Service.PriceMoved`, `ListingArrived`, `Sweep`, `service.SweepService`
- Produces: Restate services `<prefix>DiscoveryListingWatch` (handlers `Published`, `Updated`) and `<prefix>SearchWatchSweep` (handler `Run(uuid.UUID)`); `worker.SearchWatchSweep{Prefix string; Discovery service.Service; Every time.Duration}`

- [ ] **Step 1: Write the failing tests**

`internal/discovery/worker/listing_test.go`:

```go
package worker_test

import (
	"context"
	"sync"
	"testing"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"
	"github.com/restatedev/sdk-go/ingress"

	"github.com/shopnexus/server/internal/discovery/service"
	"github.com/shopnexus/server/internal/discovery/worker"
	"github.com/shopnexus/server/internal/platform/events"
	"github.com/shopnexus/server/internal/platform/restatex/restatetest"
)

// calls is a discovery service that records the listing calls.
type calls struct {
	service.Service

	mu      *sync.Mutex
	arrived *[]uuid.UUID
	moved   *[]uuid.UUID
}

func (c calls) ListingArrived(_ context.Context, id uuid.UUID) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	*c.arrived = append(*c.arrived, id)
	return nil
}

func (c calls) PriceMoved(_ context.Context, id uuid.UUID) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	*c.moved = append(*c.moved, id)
	return nil
}

func TestListingWatch(t *testing.T) {
	t.Parallel()
	var arrived, moved []uuid.UUID
	mu := &sync.Mutex{}
	w := worker.ListingWatch{Prefix: restatetest.Prefix(), Discovery: calls{mu: mu, arrived: &arrived, moved: &moved}}
	client := restatetest.Start(t, restate.Reflect(w))
	first, again := uuid.NewV7(), uuid.NewV7()
	for handler, e := range map[string]events.Event{
		"Published": {ID: uuid.NewV7(), Kind: events.ListingPublished, SubjectID: first, Payload: map[string]any{"first": true}, OccurredAt: time.Now()},
		"Updated":   {ID: uuid.NewV7(), Kind: events.ListingUpdated, SubjectID: again, OccurredAt: time.Now()},
	} {
		if _, err := ingress.Service[events.Event, restate.Void](client, w.ServiceName(), handler).Request(context.Background(), e); err != nil {
			t.Fatal(err)
		}
	}
	republished := events.Event{ID: uuid.NewV7(), Kind: events.ListingPublished, SubjectID: again, OccurredAt: time.Now()}
	if _, err := ingress.Service[events.Event, restate.Void](client, w.ServiceName(), "Published").Request(context.Background(), republished); err != nil {
		t.Fatal(err)
	}
	mu.Lock()
	defer mu.Unlock()
	if len(arrived) != 1 || arrived[0] != first || len(moved) != 3 {
		t.Fatalf("arrived %v, moved %v", arrived, moved)
	}
}
```

`internal/discovery/worker/sweep_test.go`:

```go
package worker_test

import (
	"context"
	"sync"
	"testing"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"
	"github.com/restatedev/sdk-go/ingress"

	"github.com/shopnexus/server/internal/discovery/service"
	"github.com/shopnexus/server/internal/discovery/worker"
	"github.com/shopnexus/server/internal/platform/restatex/restatetest"
	"github.com/shopnexus/server/internal/platform/testenv"
)

// sweeps answers Full twice, then Found, then not Found, counting the runs.
type sweeps struct {
	service.Service

	mu   *sync.Mutex
	runs *int
}

func (s sweeps) Sweep(context.Context, uuid.UUID) (service.Swept, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	*s.runs++
	switch *s.runs {
	case 1, 2:
		return service.Swept{Found: true, Full: true}, nil
	case 3:
		return service.Swept{Found: true}, nil
	default:
		return service.Swept{}, nil
	}
}

// A full batch sweeps again at once, a partial one after Every, and a watch
// gone ends the chain.
func TestSweepChain(t *testing.T) {
	t.Parallel()
	runs, mu := 0, &sync.Mutex{}
	w := worker.SearchWatchSweep{Prefix: restatetest.Prefix(), Discovery: sweeps{mu: mu, runs: &runs}, Every: 2 * time.Second}
	client := restatetest.Start(t, restate.Reflect(w))
	start := time.Now()
	if _, err := ingress.Service[uuid.UUID, restate.Void](client, w.ServiceName(), "Run").Request(context.Background(), uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	testenv.Eventually(t, 20*time.Second, func() error {
		mu.Lock()
		defer mu.Unlock()
		if runs < 4 {
			return fmt.Errorf("%d runs", runs)
		}
		return nil
	})
	if time.Since(start) < 2*time.Second {
		t.Fatal("the partial batch waited Every")
	}
	time.Sleep(3 * time.Second)
	mu.Lock()
	defer mu.Unlock()
	if runs != 4 {
		t.Fatalf("the chain ended: %d runs", runs)
	}
}
```

Add `"fmt"` to the imports.

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/discovery/worker/`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

`internal/discovery/worker/listing.go`:

```go
package worker

import (
	"fmt"

	restate "github.com/restatedev/sdk-go"

	"github.com/shopnexus/server/internal/discovery/service"
	"github.com/shopnexus/server/internal/platform/events"
)

// ListingWatch records first publications for the search watches and
// weighs the saves of a listing whose price may have moved: Mount
// subscribes Published to listing.published and Updated to listing.updated.
type ListingWatch struct {
	Prefix    string
	Discovery service.Service
}

func (w ListingWatch) ServiceName() string { return w.Prefix + "DiscoveryListingWatch" }

// Published records a first publication, then weighs the saves: a listing
// back from processing after an edit may carry a new price.
func (w ListingWatch) Published(ctx restate.Context, e events.Event) error {
	if first, _ := e.Payload["first"].(bool); first { //nolint:revive // an event without the flag is not a first publication
		if err := restate.RunVoid(ctx, func(rc restate.RunContext) error {
			return w.Discovery.ListingArrived(rc, e.SubjectID)
		}); err != nil {
			return fmt.Errorf("listing %s arrived: %w", e.SubjectID, err)
		}
	}
	if err := restate.RunVoid(ctx, func(rc restate.RunContext) error {
		return w.Discovery.PriceMoved(rc, e.SubjectID)
	}); err != nil {
		return fmt.Errorf("listing %s published: %w", e.SubjectID, err)
	}
	return nil
}

// Updated weighs the saves of an edited listing at its current price.
func (w ListingWatch) Updated(ctx restate.Context, e events.Event) error {
	if err := restate.RunVoid(ctx, func(rc restate.RunContext) error {
		return w.Discovery.PriceMoved(rc, e.SubjectID)
	}); err != nil {
		return fmt.Errorf("listing %s updated: %w", e.SubjectID, err)
	}
	return nil
}
```

`internal/discovery/worker/sweep.go`:

```go
package worker

import (
	"fmt"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"

	"github.com/shopnexus/server/internal/discovery/service"
)

// SearchWatchSweep sweeps one watch per invocation and sends the next: at
// once after a full batch, Every later otherwise. A watch gone ends the
// chain. Each invocation journals one step and one send.
type SearchWatchSweep struct {
	Prefix    string
	Discovery service.Service
	// Every is domain.SweepEvery in production.
	Every time.Duration
}

func (w SearchWatchSweep) ServiceName() string { return w.Prefix + service.SweepService }

func (w SearchWatchSweep) Run(ctx restate.Context, watch uuid.UUID) error {
	r, err := restate.Run(ctx, func(rc restate.RunContext) (service.Swept, error) {
		return w.Discovery.Sweep(rc, watch)
	})
	if err != nil {
		return fmt.Errorf("sweep %s: %w", watch, err)
	}
	if !r.Found {
		return nil
	}
	next := restate.ServiceSend(ctx, w.ServiceName(), "Run")
	if r.Full {
		next.Send(watch)
	} else {
		next.Send(watch, restate.WithDelay(w.Every))
	}
	return nil
}
```

In `discovery.go`'s `Mount`, after the account watch:

```go
	listings := worker.ListingWatch{Prefix: d.ServicePrefix, Discovery: svc}
	d.Events.Subscribe(events.ListingPublished, listings.ServiceName(), "Published")
	d.Events.Subscribe(events.ListingUpdated, listings.ServiceName(), "Updated")
	sweep := worker.SearchWatchSweep{Prefix: d.ServicePrefix, Discovery: svc, Every: domain.SweepEvery}
```

and return `Services: []restate.ServiceDefinition{restate.Reflect(watch), restate.Reflect(listings), restate.Reflect(sweep)}`. Update `Mount`'s doc comment.

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/discovery/... ./internal/app/...`
Expected: PASS. `app.New` refuses to start when a subscription names a service it does not serve, so `internal/app` tests catch a missing `Reflect`.

- [ ] **Step 5: Commit**

```bash
git add internal/discovery
git commit -m "feat(discovery): the listing watch and the sweep chain as Restate services"
```

---

### Task 9: Notices of watches and price drops

**Files:**
- Modify: `internal/notification/domain/notice.go`
- Modify: `internal/notification/worker/worker.go`
- Modify: `internal/notification/notification.go`, `internal/app/app.go:285`
- Modify: `api/schemas/notification.yaml`
- Test: `internal/notification/domain/notice_test.go`, `internal/notification/worker/worker_test.go`

**Interfaces:**
- Consumes: `discoverysvc.Service.WatchFacts`, `PriceDropFacts` (Tasks 5, 7); `events.SearchWatchMatched`, `events.SavedPriceDropped`
- Produces: `domain.TypeWatchMatched`, `domain.TypePriceDropped`; `domain.WatchMatched(recipient, watch uuid.UUID, query string, count int, at time.Time) Notice`; `domain.PriceDropped(recipient, listing uuid.UUID, title string, price, saved int64, at time.Time) Notice`; worker handlers `SearchWatchMatched`, `SavedPriceDropped`; `notification.Mount(..., discovery discoverysvc.Service)`

- [ ] **Step 1: Write the failing domain test**

Append to `internal/notification/domain/notice_test.go`:

```go
func TestWatchAndPriceTexts(t *testing.T) {
	t.Parallel()
	watch, listing := uuid.NewV7(), uuid.NewV7()
	w := domain.WatchMatched(uuid.NewV7(), watch, "xe đạp", 3, time.Now())
	if got := domain.Text(w.Type, w.Params); got != "Có 3 tin mới cho “xe đạp”" {
		t.Fatal(got)
	}
	if w.CollapseKey != "watch:"+watch.String() || domain.TargetOf(w.Type, w.Params) != (domain.Target{Kind: "search_watch", ID: watch.String()}) {
		t.Fatalf("%+v", w)
	}
	if m := domain.WatchMatched(uuid.NewV7(), watch, "xe đạp", 99, time.Now()); domain.Text(m.Type, m.Params) != "Có 99+ tin mới cho “xe đạp”" {
		t.Fatal(domain.Text(m.Type, m.Params))
	}
	p := domain.PriceDropped(uuid.NewV7(), listing, "Xe đạp Asama", 1_400_000, 1_500_000, time.Now())
	if got := domain.Text(p.Type, p.Params); got != "Xe đạp Asama giảm còn 1,4 tr, lúc lưu 1,5 tr" {
		t.Fatal(got)
	}
	if p.CollapseKey != "saved:"+listing.String() || domain.TargetOf(p.Type, p.Params).Kind != "listing" || domain.Title(p.Type) != "Đã lưu" {
		t.Fatalf("%+v", p)
	}
}
```

`domain.Target` is `{Kind, ID string}`, so `!=` compares it. The file exists; add the test and its imports (`time`, `uuid`).

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/notification/domain/ -run TestWatchAndPriceTexts`
Expected: FAIL, undefined.

- [ ] **Step 3: Implement the domain**

In `notice.go`, add to the `Type` constants:

```go
	TypeWatchMatched       Type = "watch_matched"
	TypePriceDropped       Type = "price_dropped"
```

Add to `Params`:

```go
	WatchID uuid.UUID `json:"watch_id,omitzero"`
	Query   string    `json:"query,omitempty"`
	Count   int       `json:"count,omitempty"`
	// SavedPrice is the listing's price when the recipient saved it.
	SavedPrice int64 `json:"saved_price,omitempty"`
```

Add the constructors after `FollowedListing`:

```go
// WatchMatched tells a watcher how many new listings their watch has; a
// newer count replaces the unread notice of the watch.
func WatchMatched(recipient, watch uuid.UUID, query string, count int, at time.Time) Notice {
	return Notice{
		Recipient: recipient, Type: TypeWatchMatched, CollapseKey: "watch:" + watch.String(), At: at,
		Params: Params{WatchID: watch, Query: query, Count: count},
	}
}

// PriceDropped tells a saver of a new low of a saved listing.
func PriceDropped(recipient, listing uuid.UUID, title string, price, saved int64, at time.Time) Notice {
	return Notice{
		Recipient: recipient, Type: TypePriceDropped, CollapseKey: "saved:" + listing.String(), At: at,
		Params: Params{ListingID: listing, Title: title, Amount: price, SavedPrice: saved},
	}
}
```

Add the groups:

```go
	searches = group{"Tìm kiếm", "search_watch", func(p Params) uuid.UUID { return p.WatchID }}
	saved    = group{"Đã lưu", "listing", func(p Params) uuid.UUID { return p.ListingID }}
```

and the texts in `types`:

```go
	TypeWatchMatched: {searches, func(p Params) string {
		n := strconv.Itoa(p.Count)
		if p.Count >= 99 {
			n = "99+"
		}
		return "Có " + n + " tin mới cho “" + p.Query + "”"
	}},
	TypePriceDropped: {saved, func(p Params) string {
		return p.Title + " giảm còn " + money(p.Amount) + ", lúc lưu " + money(p.SavedPrice)
	}},
```

Run: `go test ./internal/notification/domain/` → PASS.

- [ ] **Step 4: Write the failing worker test**

In `worker_test.go`, add a fake and use it in `newEnv` (`Discovery: discovery{}` in the `worker.Worker` literal):

```go
type discovery struct {
	discoverysvc.Service

	watches map[uuid.UUID]discoverysvc.WatchFacts
	drops   map[uuid.UUID]discoverysvc.PriceDropFacts
}

func (d discovery) WatchFacts(_ context.Context, id uuid.UUID) (discoverysvc.WatchFacts, bool, error) {
	f, ok := d.watches[id]
	return f, ok, nil
}

func (d discovery) PriceDropFacts(_ context.Context, id uuid.UUID) (discoverysvc.PriceDropFacts, bool, error) {
	f, ok := d.drops[id]
	return f, ok, nil
}
```

Import `discoverysvc "github.com/shopnexus/server/internal/discovery/service"`. Then:

```go
// A watch's sweeps leave one unread notice with the latest count, and a
// price drop tells the saver; facts gone tell no one.
func TestWatchAndPriceNotices(t *testing.T) {
	t.Parallel()
	e := newEnv(t, nil, nil)
	me := accounttest.New(t, e.db)
	watch, save, listing := uuid.NewV7(), uuid.NewV7(), uuid.NewV7()
	e.worker.Discovery = discovery{
		watches: map[uuid.UUID]discoverysvc.WatchFacts{watch: {ID: watch, Account: me, Query: "xe đạp"}},
		drops: map[uuid.UUID]discoverysvc.PriceDropFacts{
			save: {ID: save, Account: me, ListingID: listing, Title: "Xe đạp Asama", SavedPrice: 1_500_000},
		},
	}
	e.start(t)
	at := time.Now()
	e.deliver(t, "SearchWatchMatched", events.Event{ID: uuid.NewV7(), Kind: events.SearchWatchMatched, SubjectID: watch,
		Payload: map[string]any{"count": 2}, OccurredAt: at})
	e.deliver(t, "SearchWatchMatched", events.Event{ID: uuid.NewV7(), Kind: events.SearchWatchMatched, SubjectID: watch,
		Payload: map[string]any{"count": 5}, OccurredAt: at.Add(time.Minute)})
	e.deliver(t, "SearchWatchMatched", events.Event{ID: uuid.NewV7(), Kind: events.SearchWatchMatched, SubjectID: uuid.NewV7(),
		Payload: map[string]any{"count": 1}, OccurredAt: at})
	e.deliver(t, "SavedPriceDropped", events.Event{ID: uuid.NewV7(), Kind: events.SavedPriceDropped, SubjectID: save,
		Payload: map[string]any{"price": 1_400_000}, OccurredAt: at.Add(2 * time.Minute)})
	items := e.noticesOf(t, me, 2)
	if items[0].Type != domain.TypePriceDropped || items[0].Text != "Xe đạp Asama giảm còn 1,4 tr, lúc lưu 1,5 tr" {
		t.Fatalf("%+v", items[0])
	}
	if items[1].Type != domain.TypeWatchMatched || items[1].Text != "Có 5 tin mới cho “xe đạp”" || items[1].Target.Kind != "search_watch" {
		t.Fatalf("%+v", items[1])
	}
}
```

`service.Item` (`internal/notification/service/service.go`) has `Type`, `Text` and `Target`; `List` orders newest first, so the drop is `items[0]`.

- [ ] **Step 5: Run it to see it fail**

Run: `go test ./internal/notification/worker/ -run TestWatchAndPriceNotices`
Expected: FAIL to compile (`Worker.Discovery` undefined).

- [ ] **Step 6: Implement the worker and Mount**

In `worker.go`, add `Discovery discoverysvc.Service` to `Worker` and the import. Add after `ReviewPosted`:

```go
// SearchWatchMatched tells a watcher of the new listings a sweep found.
func (w Worker) SearchWatchMatched(ctx restate.Context, e events.Event) error {
	count, _ := e.Payload["count"].(float64) //nolint:revive // a payload without the count tells 0, which no sweep writes
	f, err := restate.Run(ctx, func(rc restate.RunContext) (discoverysvc.WatchFacts, error) {
		facts, found, stepErr := w.Discovery.WatchFacts(rc, e.SubjectID)
		if stepErr != nil {
			return discoverysvc.WatchFacts{}, fmt.Errorf("read watch: %w", stepErr)
		}
		if !found {
			return discoverysvc.WatchFacts{}, nil
		}
		return facts, nil
	})
	if err != nil {
		return fmt.Errorf("read the watch: %w", err)
	}
	if f.ID == (uuid.UUID{}) {
		return nil
	}
	return w.tell(ctx, e.ID, []domain.Notice{domain.WatchMatched(f.Account, f.ID, f.Query, int(count), e.OccurredAt)})
}

// SavedPriceDropped tells a saver their saved listing fell to a new low.
func (w Worker) SavedPriceDropped(ctx restate.Context, e events.Event) error {
	price, _ := e.Payload["price"].(float64) //nolint:revive // every drop carries its price
	f, err := restate.Run(ctx, func(rc restate.RunContext) (discoverysvc.PriceDropFacts, error) {
		facts, found, stepErr := w.Discovery.PriceDropFacts(rc, e.SubjectID)
		if stepErr != nil {
			return discoverysvc.PriceDropFacts{}, fmt.Errorf("read save: %w", stepErr)
		}
		if !found {
			return discoverysvc.PriceDropFacts{}, nil
		}
		return facts, nil
	})
	if err != nil {
		return fmt.Errorf("read the save: %w", err)
	}
	if f.ID == (uuid.UUID{}) {
		return nil
	}
	return w.tell(ctx, e.ID, []domain.Notice{
		domain.PriceDropped(f.Account, f.ListingID, f.Title, int64(price), f.SavedPrice, e.OccurredAt),
	})
}
```

The event reaches the handler as JSON, so a payload number is a `float64`.

In `notification.go`, `Mount` takes `discovery discoverysvc.Service` last, sets `Discovery: discovery` in the worker, and adds to the subscription map:

```go
		events.SearchWatchMatched: "SearchWatchMatched", events.SavedPriceDropped: "SavedPriceDropped",
```

Update the package comment: "...and of new listings by the sellers they follow, of their search watches and of price drops on their saves...". In `internal/app/app.go`, pass `discoverym.Service` last to `notification.Mount`.

In `api/schemas/notification.yaml`: add `search_watch` to `Target.kind`'s enum and "the deal, listing, seller or search watch" to its `id` description; add `watch_matched, price_dropped` to `Notification.type`'s enum.

- [ ] **Step 7: Run the tests**

Run: `go test ./api/... ./internal/notification/... ./internal/app/...`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add api internal/notification internal/app
git commit -m "feat(notification): notices of a watch's new listings and of a saved listing's price drop"
```

---

### Task 10: End to end, the architecture and the checklist

**Files:**
- Create: `e2e/watch_test.go`, `e2e/hidden_test.go`, `e2e/price_alert_test.go`
- Modify: `ARCHITECTURE.md` (Search, Discovery, Notifications, Erasure, Events)
- Modify: `~/shopnexus/checklist.md`

**Interfaces:**
- Consumes: every endpoint above, through the e2e helpers (`call`, `check`, `expect`, `expectStatus`, `bearer`, `newAccount`, `activeListing`, `draftWith`, `notices`).

- [ ] **Step 1: Write the e2e tests**

`e2e/hidden_test.go`:

```go
package e2e

import (
	"net/http"
	"net/url"
	"slices"
	"testing"
	"uuid"
)

func searchIDs(t *testing.T, token, query string) []string {
	t.Helper()
	res := call(t, "GET", "/v1/search?"+query, nil, bearer(token))
	got := expect[struct {
		Items []struct {
			ID string `json:"id"`
		} `json:"items"`
	}](t, res, http.StatusOK)
	out := make([]string, len(got.Items))
	for i, it := range got.Items {
		out[i] = it.ID
	}
	return out
}

func TestHiddenListing(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	me, _ := newAccount(t)
	word := "hidden" + uuid.NewV7().String()[:8]
	l := activeListing(t, seller.AccessToken, map[string]any{"title": "Ghế gỗ " + word})
	q := "q=" + url.QueryEscape(word)
	if !slices.Contains(searchIDs(t, me.AccessToken, q), l.ID) {
		t.Fatal("found before hiding")
	}
	path := "/v1/hidden/" + l.ID
	check(t, "hide", call(t, "PUT", path, nil, bearer(me.AccessToken)), 204, "")
	check(t, "hide again", call(t, "PUT", path, nil, bearer(me.AccessToken)), 204, "")
	if slices.Contains(searchIDs(t, me.AccessToken, q), l.ID) {
		t.Fatal("hidden")
	}
	check(t, "unhide", call(t, "DELETE", path, nil, bearer(me.AccessToken)), 204, "")
	if !slices.Contains(searchIDs(t, me.AccessToken, q), l.ID) {
		t.Fatal("back after unhide")
	}
	check(t, "hide own", call(t, "PUT", path, nil, bearer(seller.AccessToken)), 409, "own_listing")
	check(t, "hide unknown", call(t, "PUT", "/v1/hidden/"+uuid.NewV7().String(), nil, bearer(me.AccessToken)), 404, "listing_not_found")
	check(t, "hide a bad id", call(t, "PUT", "/v1/hidden/x", nil, bearer(me.AccessToken)), 400, "")
	check(t, "hide signed out", call(t, "PUT", path, nil), 401, "unauthenticated")
	check(t, "unhide a bad id", call(t, "DELETE", "/v1/hidden/x", nil, bearer(me.AccessToken)), 400, "")
	check(t, "unhide signed out", call(t, "DELETE", path, nil), 401, "unauthenticated")

	expectStatus(t, call(t, "POST", "/v1/blocks", map[string]any{"account_id": seller.Account.ID}, bearer(me.AccessToken)), http.StatusNoContent)
	if slices.Contains(searchIDs(t, me.AccessToken, q), l.ID) {
		t.Fatal("a blocked seller's listing")
	}
}
```

`activeListing`'s `fields` are copied over `draftWith`'s body, so `title` overrides it; `POST /v1/blocks` answers 204.

`e2e/price_alert_test.go`:

```go
package e2e

import (
	"net/http"
	"testing"
	"uuid"
)

func TestPriceAlert(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	me, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	path := "/v1/saved/" + l.ID + "/alert"
	check(t, "set", call(t, "PUT", path, map[string]any{"below": l.Price}, bearer(me.AccessToken)), 204, "")
	res := call(t, "GET", "/v1/saved", nil, bearer(me.AccessToken))
	saved := expect[page[struct {
		ListingID  string `json:"listing_id"`
		AlertBelow *int64 `json:"alert_below"`
	}]](t, res, http.StatusOK)
	if len(saved.Items) != 1 || saved.Items[0].AlertBelow == nil || *saved.Items[0].AlertBelow != l.Price {
		t.Fatalf("saved with its level: %s", res.Body)
	}
	body := draftWith(l.Photos[0].UploadID)
	body["price"] = l.Price - 100_000
	expectStatus(t, call(t, "PUT", "/v1/listings/"+l.ID, body, bearer(seller.AccessToken), newKey()), http.StatusOK)
	got := notices(t, me.AccessToken, 1)
	if n := got.Items[0]; n.Type != "price_dropped" || n.Target.Kind != "listing" || n.Target.ID != l.ID {
		t.Fatalf("%+v", n)
	}

	check(t, "set a bad body", call(t, "PUT", path, map[string]any{"below": 5}, bearer(me.AccessToken)), 400, "")
	check(t, "set on own", call(t, "PUT", path, map[string]any{"below": 100_000}, bearer(seller.AccessToken)), 409, "own_listing")
	check(t, "set on unknown", call(t, "PUT", "/v1/saved/"+uuid.NewV7().String()+"/alert", map[string]any{"below": 100_000}, bearer(me.AccessToken)), 404, "listing_not_found")
	check(t, "set signed out", call(t, "PUT", path, map[string]any{"below": 100_000}), 401, "unauthenticated")
	check(t, "clear", call(t, "DELETE", path, nil, bearer(me.AccessToken)), 204, "")
	check(t, "clear a bad id", call(t, "DELETE", "/v1/saved/x/alert", nil, bearer(me.AccessToken)), 400, "")
	check(t, "clear signed out", call(t, "DELETE", path, nil), 401, "unauthenticated")

	res = call(t, "GET", "/v1/me/price-cut-alerts", nil, bearer(me.AccessToken))
	if sw := expect[struct {
		On bool `json:"on"`
	}](t, res, http.StatusOK); !sw.On {
		t.Fatalf("on by default: %s", res.Body)
	}
	check(t, "switch off", call(t, "PUT", "/v1/me/price-cut-alerts", map[string]any{"on": false}, bearer(me.AccessToken)), 204, "")
	check(t, "switch a bad body", call(t, "PUT", "/v1/me/price-cut-alerts", map[string]any{"on": "no"}, bearer(me.AccessToken)), 400, "")
	check(t, "switch signed out", call(t, "PUT", "/v1/me/price-cut-alerts", map[string]any{"on": true}), 401, "unauthenticated")
	check(t, "read switch signed out", call(t, "GET", "/v1/me/price-cut-alerts", nil), 401, "unauthenticated")
}
```

`listing` in `e2e/catalog_test.go` has no `Price`; add `Price int64 `json:"price"`` after `Status`.

`e2e/watch_test.go`:

```go
package e2e

import (
	"fmt"
	"net/http"
	"testing"
	"uuid"
)

type searchWatch struct {
	ID       string `json:"id"`
	Query    string `json:"query"`
	NewCount int    `json:"new_count"`
	Alert    bool   `json:"alert"`
	Area     *struct {
		CommuneCode string `json:"commune_code"`
		Name        string `json:"name"`
	} `json:"area"`
}

func TestSearchWatches(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	in := map[string]any{"q": "xe đạp", "price_max": 3_000_000, "near_commune": "00004", "radius_km": 5}
	created := expect[searchWatch](t, call(t, "POST", "/v1/search/watches", in, bearer(me.AccessToken)), http.StatusCreated)
	if created.Area == nil || created.Area.CommuneCode != "00004" || !created.Alert {
		t.Fatalf("%+v", created)
	}
	again := expect[searchWatch](t, call(t, "POST", "/v1/search/watches", map[string]any{"q": "Xe Dap"}, bearer(me.AccessToken)), http.StatusOK)
	if again.ID != created.ID || again.Area != nil {
		t.Fatalf("the same words take the new filters: %+v", again)
	}
	list := expect[struct {
		Items []searchWatch `json:"items"`
	}](t, call(t, "GET", "/v1/search/watches", nil, bearer(me.AccessToken)), http.StatusOK)
	if len(list.Items) != 1 {
		t.Fatalf("%+v", list)
	}
	res := call(t, "GET", "/v1/search?q=xe+dap", nil, bearer(me.AccessToken))
	if v := expect[struct {
		WatchID string `json:"watch_id"`
	}](t, res, http.StatusOK); v.WatchID != created.ID {
		t.Fatalf("watch_id: %s", res.Body)
	}
	expectStatus(t, call(t, "GET", "/v1/search?watch="+created.ID, nil, bearer(me.AccessToken)), http.StatusOK)
	base := "/v1/search/watches/" + created.ID
	check(t, "mute", call(t, "POST", base+"/mute", nil, bearer(me.AccessToken)), 204, "")
	check(t, "unmute", call(t, "POST", base+"/unmute", nil, bearer(me.AccessToken)), 204, "")
	other, _ := newAccount(t)
	check(t, "mute someone else's", call(t, "POST", base+"/mute", nil, bearer(other.AccessToken)), 404, "watch_not_found")
	check(t, "unmute someone else's", call(t, "POST", base+"/unmute", nil, bearer(other.AccessToken)), 404, "watch_not_found")
	check(t, "search someone else's", call(t, "GET", "/v1/search?watch="+created.ID, nil, bearer(other.AccessToken)), 404, "watch_not_found")
	check(t, "search a watch with q", call(t, "GET", "/v1/search?q=x&watch="+created.ID, nil, bearer(me.AccessToken)), 400, "search_conflict")
	check(t, "mute a bad id", call(t, "POST", "/v1/search/watches/x/mute", nil, bearer(me.AccessToken)), 400, "")
	check(t, "unmute a bad id", call(t, "POST", "/v1/search/watches/x/unmute", nil, bearer(me.AccessToken)), 400, "")
	check(t, "mute signed out", call(t, "POST", base+"/mute", nil), 401, "unauthenticated")
	check(t, "unmute signed out", call(t, "POST", base+"/unmute", nil), 401, "unauthenticated")
	check(t, "delete", call(t, "DELETE", base, nil, bearer(me.AccessToken)), 204, "")
	check(t, "delete again", call(t, "DELETE", base, nil, bearer(me.AccessToken)), 204, "")
	check(t, "delete a bad id", call(t, "DELETE", "/v1/search/watches/x", nil, bearer(me.AccessToken)), 400, "")
	check(t, "delete signed out", call(t, "DELETE", base, nil), 401, "unauthenticated")

	check(t, "no q", call(t, "POST", "/v1/search/watches", map[string]any{"q": "  "}, bearer(me.AccessToken)), 400, "")
	check(t, "price range", call(t, "POST", "/v1/search/watches", map[string]any{"q": "a", "price_min": 5, "price_max": 1}, bearer(me.AccessToken)), 400, "invalid_price_range")
	check(t, "abroad", call(t, "POST", "/v1/search/watches", map[string]any{"q": "a", "near_lat": 48.85, "near_lng": 2.35}, bearer(me.AccessToken)), 400, "invalid_position")
	check(t, "radius, no place", call(t, "POST", "/v1/search/watches", map[string]any{"q": "a", "radius_km": 5}, bearer(me.AccessToken)), 400, "position_required")
	check(t, "create signed out", call(t, "POST", "/v1/search/watches", map[string]any{"q": "a"}), 401, "unauthenticated")
	check(t, "list signed out", call(t, "GET", "/v1/search/watches", nil), 401, "unauthenticated")
	for i := range 20 {
		expectStatus(t, call(t, "POST", "/v1/search/watches", map[string]any{"q": fmt.Sprintf("tìm %d %s", i, uuid.NewV7())}, bearer(me.AccessToken)), http.StatusCreated)
	}
	check(t, "the 21st", call(t, "POST", "/v1/search/watches", map[string]any{"q": "một nữa"}, bearer(me.AccessToken)), 409, "watch_limit_reached")
}
```

The sweep runs 30 minutes after a watch is made, so e2e does not wait for a `watch_matched` notice; `TestWatchAndSweep` (Task 7) and `TestWatchAndPriceNotices` (Task 9) cover it.

- [ ] **Step 2: Run the whole suite**

Run: `make test`
Expected: PASS, the e2e coverage check included (every declared status of the new operations is observed). If the coverage check lists a status, add the call that answers it.

- [ ] **Step 3: Record the decisions in ARCHITECTURE.md**

Following the file's style (short decided bullets, dates, the spec path):

- In **Search**: the exclusions (hidden listings and the accounts on either side of a block, signed-in only, every form of search); `?watch=`; `watch_id`; `Phrase.AllWords`; `Filters.IDs`; `ExcludeSeller` became `ExcludeSellers`.
- In **Discovery**: a "Search watches (decided 2026-11-11, spec: `~/shopnexus/docs/superpowers/specs/2026-11-11-server-search-watches-price-alerts-hidden-design.md`)" block: one watch per `HistoryKey`, 20 per account, a commune only (GPS to the nearest commune within 30 km), the phrases stored at follow time, `listing_arrivals` and why (`published_at` is the publish flow's start), the sweep chain (`SearchWatchSweep`, 30 minutes, 500 per batch, at once after a full batch, the first send before the row as media does), `new_count` to 99, `Seen` on `?watch=`'s first page; a "Price alerts" block: the level on the save, the switch in `saved_settings`, the new-low rule and its correlated SQL, `ListingWatch` on `listing.updated` and `listing.published`; a "Hidden listings" block: 1,000 newest, upsert with a new ID, no list endpoint.
- In **Notifications**: the two kinds, their texts, collapse keys `watch:<id>` and `saved:<listing id>`, target kind `search_watch`, and that notification reads discovery's `WatchFacts` and `PriceDropFacts`.
- In **Erasure**: discovery also deletes the watches, hides and settings.
- In **Events**: the list of kinds names `search_watch.matched` and `saved.price_dropped`.

Run the `humanizing-writing` checker on the changed sections (`ARCHITECTURE.md` is documentation): copy them to `tmp/arch.md` and run `python3 ~/.claude/skills/humanizing-writing/ai-tells.py --stats tmp/arch.md`; fix every hit.

- [ ] **Step 4: Commit the server**

```bash
git add e2e ARCHITECTURE.md
git commit -m "test(e2e): watches, price alerts and hidden listings; docs in the architecture"
```

- [ ] **Step 5: Tick the checklist**

In `~/shopnexus/checklist.md`, section 1 "Mua & tìm kiếm", replace the three lines with:

```markdown
- [x] Theo dõi từ khoá tìm kiếm + báo khi có tin mới: `POST/GET /v1/search/watches`, `DELETE /v1/search/watches/{id}`, `/mute` và `/unmute`, mở bằng `GET /v1/search?watch=<id>`; quét mỗi 30 phút, báo "Có N tin mới cho “…”" (app chưa nối)
- [x] Báo giảm giá cho tin đã lưu (đặt mức giá báo): `PUT/DELETE /v1/saved/{listing_id}/alert {below}`, công tắc chung `GET/PUT /v1/me/price-cut-alerts`; báo mỗi lần giá thấp kỷ lục mới dưới mức báo (app chưa nối)
- [x] Ẩn một tin khỏi feed của mình: `PUT/DELETE /v1/hidden/{listing_id}`, giữ 1.000 tin ẩn mới nhất (app chưa nối)
- [x] Tìm kiếm, Gần bạn và Trang chủ bỏ tin của người bán có chặn với mình, cả hai chiều
```

Run the checker on the changed lines as in Step 3.

- [ ] **Step 6: Commit the top repository**

```bash
cd ~/shopnexus
git add checklist.md server docs
git commit -m "build: server at search watches, price alerts and hidden listings"
```

The top repository's recent commits (`build: ...`, `chore: submodules at ...`) bump the submodules together with the checklist; follow that style.
