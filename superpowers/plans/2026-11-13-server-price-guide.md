# server price guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `POST /v1/price-guides` answers, for any listing draft, the price range, "Bán nhanh" and "Giá thị trường" with days to sell, similar listings, the sample's prices, and the search watches the draft would match.

**Architecture:** Catalog's price sample gains each listing's ID, days to sell and point. Assist owns the use case: one helper (`draftSample`) turns a draft into vectors and a sample for both the listing reads and the guide, `domain.Suggest` derives the two suggestions, and discovery's new `Watchers` matches the draft against search watches in reverse. The handler is a thin `POST` in assist.

**Tech Stack:** Go (server), Postgres + pgvector + ParadeDB, Restate (reads only), OpenAPI 3.1 in `api/`.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-13-price-guide-design.md`

Repo: `~/shopnexus/server` (module `github.com/shopnexus/server`). Read
`server/CLAUDE.md` and `server/ARCHITECTURE.md` (Assist, Search watches)
first. Tests need the test stack: run `make test` once, then
`go test -p 4 ./internal/<module>/...` runs one module. The stack is shared
across sessions; if a test fails on a connection, recreate the whole stack
and rerun the failures alone. Commits carry no `Co-Authored-By` line.

## Global Constraints

- A use case, Restate handler or HTTP handler reads top to bottom; a helper only when several places call it (`server/CLAUDE.md`).
- The feature starts from the OpenAPI spec; the e2e suite fails when a declared response code is never observed (`e2e/main_test.go` `uncovered`).
- No configuration defaults; this change adds no variable.
- The sample stays nationwide, `domain.PriceSampleSize` (30) nearest, windows 180 days sold / 90 days on sale.
- Under `MinMarketSample` (5) samples: no estimate, no suggestions; similar listings, prices and watchers still answer. Under 3 sold: no suggestions.
- Watchers: every live watch, muted included, no minimum count; one row `{price_min?, price_max?, offers_only}`, at most 200; nothing that names the buyer.
- No cap on guides in this change.
- Guide log lines hold no title, description or specs.
- Scratch output goes in `server/tmp/`, never `/tmp`.

## Review Focus

- A draft whose photos include one that is not a waiting upload of the caller's (another account's, already in a listing): 422 `invalid_upload` before any embedding, never a 500 and never a silently empty guide. Pinned in Task 6.
- The reverse match disagrees with the sweep: a watch the guide counts must be one the sweep would alert, for diacritics, punctuation and digits. Pinned in Task 2 against the real index.
- Embedding models down: the guide still answers 200 with the watchers, and the reads still end `done`. Pinned in Task 6 and by the reads' existing `TestReadEstimateWithoutEmbeddings`.
- A listing in the sample deleted between the sample and the summaries: left out of `similar`, no 500. Pinned in Task 6.
- A watcher who blocked the seller, or whom the seller blocked, or who is suspended: not counted. Pinned in Task 3.

---

### Task 1: The price sample carries the listing, its days to sell and its point

**Files:**
- Modify: `internal/catalog/domain/price.go`
- Modify: `internal/catalog/repository/price_pg.go`
- Modify: `internal/catalog/repository/repository.go:127-129` (comment)
- Modify: `internal/catalog/service/service.go:86-88` (comment)
- Test: `internal/catalog/repository/price_pg_test.go`, `internal/catalog/service/price_sample_test.go`

**Interfaces:**
- Produces: `catalogdomain.PriceSample{ListingID uuid.UUID; Price int64; Sold bool; DaysToSell int; Point Point}` (also `catalogsvc.PriceSample`, an alias). `DaysToSell` is 0 for a listing on sale.

- [ ] **Step 1: Write the failing repository assertions**

In `TestPriceSample`, after the line that backdates `sold` to 10 days ago,
add one that sets its publication 36 hours before its sale, and give the
first on-sale listing a point:

```go
	sold := priced(t, db, seller, 1_400_000, axis, nil)
	exec(t, db, `UPDATE listings SET status = 'sold', sold_at = now() - interval '10 days',
    published_at = now() - interval '10 days' - interval '36 hours' WHERE id = $1`, sold)
```

Replace `priced(t, db, seller, 1_000_000, axis, nil) // the same text` with:

```go
	same := priced(t, db, seller, 1_000_000, axis, nil, func(_ *domain.ListingInput, r *domain.Refs) {
		r.CommunePoint = domain.Point{Lat: 21.0394, Lng: 105.8364}
	}) // the same text
```

After the loop that checks the sold flags, add:

```go
	for _, s := range got {
		switch s.Price {
		case 1_400_000:
			if s.ListingID != sold || s.DaysToSell != 2 {
				t.Fatalf("sold: %+v", s)
			}
		case 1_000_000:
			if s.ListingID != same || s.DaysToSell != 0 || s.Point != (domain.Point{Lat: 21.0394, Lng: 105.8364}) {
				t.Fatalf("on sale: %+v", s)
			}
		}
	}
```

In `internal/catalog/service/price_sample_test.go`, the struct comparison
breaks once the struct grows; compare what the test is about:

```go
	slices.SortFunc(got, func(a, b service.PriceSample) int { return int(a.Price - b.Price) })
	if len(got) != 2 || got[0].Price != 1_000_000 || got[0].Sold || got[1].Price != 1_200_000 || !got[1].Sold {
		t.Fatalf("%+v", got)
	}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test -p 4 ./internal/catalog/repository/ -run TestPriceSample -v`
Expected: compile error, `s.ListingID undefined`.

- [ ] **Step 3: Grow the type and the query**

`internal/catalog/domain/price.go`, replace `PriceSample`:

```go
// PriceSample is one listing like a listing input: its price, whether it
// sold at it, the whole days from its publication to its sale (at least 1;
// 0 on sale), and its point.
type PriceSample struct {
	ListingID  uuid.UUID `json:"listing_id"`
	Price      int64     `json:"price"`
	Sold       bool      `json:"sold"`
	DaysToSell int       `json:"days_to_sell"`
	Point      Point     `json:"point"`
}
```

(add `"uuid"` to the imports.)

`internal/catalog/repository/price_pg.go`: the candidates select more
columns and the rows are scanned by hand, since `RowToStructByPos` cannot
fill the nested `Point`. Replace the query and the collection:

```go
	rows, err := s.db.Query(ctx, `WITH candidates AS (
SELECT id, price, status = @sold AS sold, published_at, sold_at, lat, lng FROM listings
WHERE category_code = @category AND condition = @condition AND seller_id <> @exclude
  AND ((status = @sold AND sold_at >= @sold_since) OR (status = ANY(@on_sale) AND published_at >= @on_sale_since))),
near AS (SELECT id, min(d) AS d FROM (`+strings.Join(lists, "\nUNION ALL\n")+`) v GROUP BY id)
SELECT c.id, c.price, c.sold,
    CASE WHEN c.sold THEN greatest(1, ceil(extract(epoch FROM c.sold_at - c.published_at) / 86400))::int ELSE 0 END,
    c.lat, c.lng
FROM near AS n JOIN candidates AS c ON c.id = n.id
ORDER BY n.d, c.id LIMIT @limit`, args)
	if err != nil {
		return nil, fmt.Errorf("price sample: %w", err)
	}
	samples, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (domain.PriceSample, error) {
		var p domain.PriceSample
		err := row.Scan(&p.ListingID, &p.Price, &p.Sold, &p.DaysToSell, &p.Point.Lat, &p.Point.Lng)
		return p, err
	})
	if err != nil {
		return nil, fmt.Errorf("read price sample: %w", err)
	}
	return samples, nil
```

Update the two interface comments to "returns the listings like f's
vectors with their prices, days to sell and points, most similar first".

- [ ] **Step 4: Run catalog's tests**

Run: `go test -p 4 ./internal/catalog/...`
Expected: PASS (`MarketPrice` and `MedianPrice` only read `Price`).

- [ ] **Step 5: Build everything that uses the type**

Run: `go build ./... && go vet ./internal/assist/... ./internal/trust/...`
Expected: no output. Assist's `estimate.go` builds `domain.Sample` from
`Price` and `Sold` and still compiles.

- [ ] **Step 6: Commit**

```bash
git add internal/catalog
git commit -m "feat(catalog): a price sample names its listings, their days to sell and points"
```

---

### Task 2: `HoldsAllWords`, the index's all-words match in Go

**Files:**
- Create: `internal/catalog/domain/words.go`
- Test: `internal/catalog/domain/words_test.go`
- Test: `internal/catalog/service/words_index_test.go`

**Interfaces:**
- Produces: `catalogdomain.HoldsAllWords(phrase, text string) bool`.

- [ ] **Step 1: Write the table test**

`internal/catalog/domain/words_test.go`:

```go
package domain_test

import (
	"testing"

	"github.com/shopnexus/server/internal/catalog/domain"
)

// AllWordsCases are phrases against listing text, as the sweep's all-words
// query decides them; words_index_test.go runs the same table against the
// index.
var AllWordsCases = []struct {
	Name, Phrase, Text string
	Want               bool
}{
	{"every word", "xe đạp", "Xe đạp Asama đi ít", true},
	{"case", "IPHONE 11", "iphone 11 64GB", true},
	{"order does not matter", "đạp xe", "xe đạp", true},
	{"a missing word", "xe đạp", "xe máy Honda", false},
	{"diacritics are letters", "xe dap", "Xe đạp", false},
	{"punctuation splits", "64 gb", "iPhone 11 (64-GB)", true},
	{"digits are words", "11", "iphone 11", true},
	{"part of a word is not a word", "phone", "iphone 11", false},
	{"an empty phrase matches nothing", " - ", "xe đạp", false},
}

func TestHoldsAllWords(t *testing.T) {
	t.Parallel()
	for _, c := range AllWordsCases {
		if got := domain.HoldsAllWords(c.Phrase, c.Text); got != c.Want {
			t.Errorf("%s: HoldsAllWords(%q, %q) = %v", c.Name, c.Phrase, c.Text, got)
		}
	}
}
```

`AllWordsCases` lives in a `_test.go` file of package `domain_test`, so the
service test cannot import it; copy the table there instead (Step 4).

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/catalog/domain/ -run TestHoldsAllWords`
Expected: compile error, `undefined: domain.HoldsAllWords`.

- [ ] **Step 3: Write `words.go`**

```go
package domain

import (
	"strings"
	"unicode"
)

// HoldsAllWords reports whether every word of phrase is a word of text, as
// the search index matches a watch's phrase: both split on every rune that
// is not a letter or a digit and lowercased, with no folding of
// diacritics. A phrase without words holds nothing.
func HoldsAllWords(phrase, text string) bool {
	want := words(phrase)
	if len(want) == 0 {
		return false
	}
	have := make(map[string]bool)
	for _, w := range words(text) {
		have[w] = true
	}
	for _, w := range want {
		if !have[w] {
			return false
		}
	}
	return true
}

func words(s string) []string {
	return strings.FieldsFunc(strings.ToLower(s), func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) })
}
```

- [ ] **Step 4: Pin it to the index**

`internal/catalog/service/words_index_test.go`: each case puts a listing
whose title is the case's text and runs the sweep's all-words search on
it. When this test and the table disagree, the tokenizer changed, and
`HoldsAllWords` follows the index.

```go
package service_test

import (
	"context"
	"testing"
	"uuid"

	"github.com/shopnexus/server/internal/catalog/catalogtest"
	"github.com/shopnexus/server/internal/catalog/domain"
)

func TestHoldsAllWordsAgreesWithTheIndex(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller := e.account(t)
	for _, c := range []struct {
		name, phrase, text string
	}{
		{"every word", "xe đạp", "Xe đạp Asama đi ít"},
		{"case", "IPHONE 11", "iphone 11 64GB"},
		{"order does not matter", "đạp xe", "xe đạp"},
		{"a missing word", "xe đạp", "xe máy Honda"},
		{"diacritics are letters", "xe dap", "Xe đạp"},
		{"punctuation splits", "64 gb", "iPhone 11 (64-GB)"},
		{"digits are words", "11", "iphone 11"},
		{"part of a word is not a word", "phone", "iphone 11"},
	} {
		id := catalogtest.Listing(t, e.db, seller, func(d *domain.ListingInput, _ *domain.Refs) { d.Title = c.text })
		cards, err := e.catalog.Search(ctx, domain.Search{
			Phrases: []domain.Phrase{{Text: c.phrase, Weight: 1, AllWords: true}},
			Filters: domain.Filters{IDs: []uuid.UUID{id}}, Sort: domain.SortNewest, Limit: 1,
		})
		if err != nil {
			t.Fatal(err)
		}
		if index, ours := len(cards) == 1, domain.HoldsAllWords(c.phrase, c.text); index != ours {
			t.Errorf("%s: the index says %v, HoldsAllWords %v", c.name, index, ours)
		}
	}
}
```

- [ ] **Step 5: Run both**

Run: `go test -p 4 ./internal/catalog/domain/ ./internal/catalog/service/ -run 'HoldsAllWords'`
Expected: PASS. If the index test fails on a case, the index decides:
change `words` (and the table's `Want`) to match it, and say so in the
commit message.

- [ ] **Step 6: Commit**

```bash
git add internal/catalog/domain/words.go internal/catalog/domain/words_test.go internal/catalog/service/words_index_test.go
git commit -m "feat(catalog): HoldsAllWords, the index's all-words match for a text not yet indexed"
```

---

### Task 3: Discovery's `Watchers`, the watches a draft would match

**Files:**
- Modify: `internal/discovery/domain/` (new constants in `alert.go` or a new `watchers.go`)
- Modify: `internal/discovery/repository/repository.go` (type and method on `Watches`)
- Modify: `internal/discovery/repository/watch_pg.go`
- Create: `internal/discovery/service/watchers.go`
- Modify: `internal/discovery/service/service.go` (the `Service` interface)
- Test: `internal/discovery/repository/watch_pg_test.go`, `internal/discovery/service/watchers_test.go`

**Interfaces:**
- Consumes: `catalogdomain.HoldsAllWords`, `catalogdomain.Box`, `catalogdomain.Point`.
- Produces:
  - `discoverysvc.WatcherQuery{CategoryCode string; Condition catalogdomain.Condition; Point catalogdomain.Point; Text string}`
  - `discoverysvc.Watcher{PriceMin, PriceMax int64; OffersOnly bool}` (0 is no bound)
  - `Service.Watchers(ctx context.Context, seller uuid.UUID, q WatcherQuery) ([]Watcher, error)`
  - `domain.MaxWatchers = 200`, `domain.MaxWatcherCandidates = 5000`

- [ ] **Step 1: Write the repository test**

Append to `internal/discovery/repository/watch_pg_test.go`:

```go
// Candidates are the watches of active accounts whose category and
// conditions admit the listing, with their commune's point, oldest first.
func TestWatchCandidates(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ws := repository.NewWatches(db)
	ctx := context.Background()
	put := func(account uuid.UUID, q string, change func(*repository.Watch)) {
		t.Helper()
		w := watch(account, q)
		change(&w)
		if _, _, err := ws.Put(ctx, w); err != nil {
			t.Fatal(err)
		}
	}
	a, b, c, blocked, me := accounttest.New(t, db), accounttest.New(t, db), accounttest.New(t, db), accounttest.New(t, db), accounttest.New(t, db)
	put(a, "any", func(*repository.Watch) {})
	put(a, "root", func(w *repository.Watch) { w.Category = "vehicles" })
	put(a, "leaf", func(w *repository.Watch) { w.Category, w.Conditions = "vehicles.bicycle", []string{"used", "like_new"} })
	put(b, "near", func(w *repository.Watch) { w.Commune, w.RadiusKm, w.PriceMax = "00004", 5, 2_000_000 })
	put(b, "other leaf", func(w *repository.Watch) { w.Category = "vehicles.motorbike" })
	put(b, "new only", func(w *repository.Watch) { w.Conditions = []string{"new"} })
	put(blocked, "blocked", func(*repository.Watch) {})
	put(me, "mine", func(*repository.Watch) {})
	put(c, "suspended", func(*repository.Watch) {})
	if _, err := db.Exec(ctx, `UPDATE accounts SET status = 'suspended' WHERE id = $1`, c); err != nil {
		t.Fatal(err)
	}

	got, err := ws.Candidates(ctx, repository.CandidateFilter{
		CategoryCode: "vehicles.bicycle", CategoryRoot: "vehicles", Condition: "used",
		Exclude: []uuid.UUID{me, blocked}, Limit: 100,
	})
	if err != nil {
		t.Fatal(err)
	}
	var queries []string
	for _, w := range got {
		queries = append(queries, w.Query)
	}
	if want := []string{"any", "root", "leaf", "near"}; !slices.Equal(queries, want) {
		t.Fatalf("%v, want %v", queries, want)
	}
	if near := got[3]; near.PriceMax != 2_000_000 || near.RadiusKm != 5 || near.Point.Lat != 21.0394 || near.Point.Lng != 105.8364 {
		t.Fatalf("near: %+v", near)
	}
	if got, _ = ws.Candidates(ctx, repository.CandidateFilter{
		CategoryCode: "vehicles.bicycle", CategoryRoot: "vehicles", Condition: "used", Exclude: []uuid.UUID{}, Limit: 2,
	}); len(got) != 2 {
		t.Fatalf("limit: %+v", got)
	}
}
```

(add `"slices"` to the imports.)

- [ ] **Step 2: Run it to see it fail**

Run: `go test -p 4 ./internal/discovery/repository/ -run TestWatchCandidates`
Expected: compile error, `ws.Candidates undefined`.

- [ ] **Step 3: Add the constants, the type and the query**

`internal/discovery/domain/watchers.go`:

```go
package domain

const (
	// MaxWatchers is how many watches a price guide lists at most.
	MaxWatchers = 200
	// MaxWatcherCandidates is how many watches the category and conditions
	// admit that a guide weighs at most, oldest first.
	MaxWatcherCandidates = 5000
)
```

`internal/discovery/repository/repository.go`, beside `Watch`:

```go
// WatchCandidate is a watch whose category and conditions admit a
// listing, with what is left to weigh: its words, its price and offers
// filters, and its area (a zero Point without one).
type WatchCandidate struct {
	Query              string
	Phrases            []string
	PriceMin, PriceMax int64
	OffersOnly         bool
	RadiusKm           int
	Point              catalogdomain.Point
}

// CandidateFilter is a listing's category, its root and its condition, and
// the accounts whose watches stay out.
type CandidateFilter struct {
	CategoryCode, CategoryRoot, Condition string
	Exclude                               []uuid.UUID
	Limit                                 int
}
```

and in the `Watches` interface:

```go
	// Candidates lists the watches of active accounts not in f.Exclude
	// whose category is none, f's code or f's root and whose conditions are
	// none or hold f's, muted ones too, oldest first, at most f.Limit.
	Candidates(ctx context.Context, f CandidateFilter) ([]WatchCandidate, error)
```

(import `catalogdomain "github.com/shopnexus/server/internal/catalog/domain"`
if the file does not yet.)

`internal/discovery/repository/watch_pg.go`:

```go
func (s pgWatches) Candidates(ctx context.Context, f CandidateFilter) ([]WatchCandidate, error) {
	rows, err := s.db.Query(ctx, `SELECT w.query, w.phrases, coalesce(w.price_min, 0), coalesce(w.price_max, 0),
    w.offers_only, coalesce(w.radius_km, 0), coalesce(c.lat, 0), coalesce(c.lng, 0)
FROM search_watches AS w
JOIN accounts AS a ON a.id = w.account_id AND a.status = 'active'
LEFT JOIN communes AS c ON c.code = w.commune_code
WHERE (w.category IS NULL OR w.category = @code OR w.category = @root)
  AND (cardinality(w.conditions) = 0 OR @condition = ANY(w.conditions))
  AND w.account_id <> ALL(@exclude)
ORDER BY w.created_at, w.id
LIMIT @limit`, pgx.StrictNamedArgs{
		"code": f.CategoryCode, "root": f.CategoryRoot, "condition": f.Condition, "exclude": f.Exclude, "limit": f.Limit,
	})
	if err != nil {
		return nil, fmt.Errorf("watch candidates: %w", err)
	}
	out, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (WatchCandidate, error) {
		var w WatchCandidate
		err := row.Scan(&w.Query, &w.Phrases, &w.PriceMin, &w.PriceMax, &w.OffersOnly, &w.RadiusKm, &w.Point.Lat, &w.Point.Lng)
		return w, err
	})
	if err != nil {
		return nil, fmt.Errorf("read watch candidates: %w", err)
	}
	return out, nil
}
```

`Exclude` must be a non-nil slice: `<> ALL(NULL)` is NULL and drops every
row. The service always passes one.

- [ ] **Step 4: Run the repository test**

Run: `go test -p 4 ./internal/discovery/repository/ -run TestWatchCandidates -v`
Expected: PASS.

- [ ] **Step 5: Write the service test**

`internal/discovery/service/watchers_test.go`:

```go
package service_test

import (
	"context"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server/internal/account/accounttest"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/discovery/repository"
	"github.com/shopnexus/server/internal/discovery/service"
)

// baDinh is commune 00004's point; ngocHa (00008) is 2 km west of it,
// thuDauMot (25747) far south.
var (
	baDinh    = catalogdomain.Point{Lat: 21.0394, Lng: 105.8364}
	thuDauMot = catalogdomain.Point{Lat: 10.9682, Lng: 106.6643}
)

func TestWatchers(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	ws := repository.NewWatches(e.db)
	put := func(account uuid.UUID, q string, change func(*repository.Watch)) {
		t.Helper()
		w := repository.Watch{
			ID: uuid.NewV7(), Account: account, Query: q, Phrases: []string{q}, Conditions: []string{}, Alert: true,
			CreatedAt: time.Now(),
		}
		change(&w)
		if _, _, err := ws.Put(ctx, w); err != nil {
			t.Fatal(err)
		}
	}
	seller := accounttest.New(t, e.db)
	buyer, muted, far, blocker, blockedBy := accounttest.New(t, e.db), accounttest.New(t, e.db), accounttest.New(t, e.db),
		accounttest.New(t, e.db), accounttest.New(t, e.db)
	put(buyer, "xe đạp", func(w *repository.Watch) { w.PriceMax = 2_000_000 })
	put(buyer, "xe máy", func(*repository.Watch) {})                                        // a missing word
	put(buyer, "asama", func(w *repository.Watch) { w.Commune, w.RadiusKm = "00008", 5 })    // within 5 km
	put(far, "xe đạp", func(w *repository.Watch) { w.Commune, w.RadiusKm = "25747", 30 })   // too far
	put(muted, "xe đạp asama", func(w *repository.Watch) { w.Alert, w.OffersOnly = false, true }) // muted counts
	put(muted, "raw words", func(w *repository.Watch) { w.Query, w.Phrases = "Asama", []string{} })
	put(seller, "xe đạp", func(*repository.Watch) {})
	put(blocker, "xe đạp", func(*repository.Watch) {})
	put(blockedBy, "xe đạp", func(*repository.Watch) {})
	if err := e.accounts.Block(ctx, blocker, seller); err != nil {
		t.Fatal(err)
	}
	if err := e.accounts.Block(ctx, seller, blockedBy); err != nil {
		t.Fatal(err)
	}

	q := service.WatcherQuery{
		CategoryCode: "vehicles.bicycle", Condition: catalogdomain.ConditionUsed, Point: baDinh,
		Text: "Xe đạp Asama\nĐi ít\nKhung: nhôm",
	}
	got, err := e.discovery.Watchers(ctx, seller, q)
	if err != nil {
		t.Fatal(err)
	}
	want := []service.Watcher{{PriceMax: 2_000_000}, {}, {OffersOnly: true}, {}}
	if len(got) != len(want) {
		t.Fatalf("%+v, want %+v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("row %d: %+v, want %+v", i, got[i], want[i])
		}
	}
	q.Point = thuDauMot
	if got, _ = e.discovery.Watchers(ctx, seller, q); len(got) != 4 {
		t.Fatalf("from Thủ Dầu Một the Ngọc Hà watch drops out and the Thủ Dầu Một one comes in: %+v", got)
	}
}
```

- [ ] **Step 6: Run it to see it fail**

Run: `go test -p 4 ./internal/discovery/service/ -run TestWatchers`
Expected: compile error, `e.discovery.Watchers undefined`.

- [ ] **Step 7: Write the use case**

Add to the `Service` interface in `service.go`:

```go
	// Watchers lists the live watches a listing of seller's matching q
	// would match, muted ones too, oldest first, at most
	// domain.MaxWatchers: by category, condition, area and words, with
	// the price and offers filters left for the caller to weigh.
	Watchers(ctx context.Context, seller uuid.UUID, q WatcherQuery) ([]Watcher, error)
```

`internal/discovery/service/watchers.go`:

```go
package service

import (
	"context"
	"fmt"
	"strings"
	"uuid"

	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/discovery/domain"
	"github.com/shopnexus/server/internal/discovery/repository"
)

// WatcherQuery is a listing not yet posted: its category, condition,
// point, and the text its words are matched in (title, description,
// specs).
type WatcherQuery struct {
	CategoryCode string
	Condition    catalogdomain.Condition
	Point        catalogdomain.Point
	Text         string
}

// Watcher is a matching watch's price and offers filters; 0 is no bound.
// Nothing in it names the watcher.
type Watcher struct {
	PriceMin   int64 `json:"price_min,omitempty"`
	PriceMax   int64 `json:"price_max,omitempty"`
	OffersOnly bool  `json:"offers_only"`
}

func (d *Discovery) Watchers(ctx context.Context, seller uuid.UUID, q WatcherQuery) ([]Watcher, error) {
	blocks, err := d.accounts.BlockedWith(ctx, seller)
	if err != nil {
		return nil, fmt.Errorf("read blocks: %w", err)
	}
	root, _, _ := strings.Cut(q.CategoryCode, ".")
	candidates, err := d.watches.Candidates(ctx, repository.CandidateFilter{
		CategoryCode: q.CategoryCode, CategoryRoot: root, Condition: string(q.Condition),
		Exclude: append([]uuid.UUID{seller}, blocks...), Limit: domain.MaxWatcherCandidates,
	})
	if err != nil {
		return nil, err
	}
	out := []Watcher{}
	for _, w := range candidates {
		if len(out) == domain.MaxWatchers {
			break
		}
		// The sweep measures a watch's area as a box around its commune.
		if w.RadiusKm > 0 {
			lo, hi := catalogdomain.Box(w.Point, float64(w.RadiusKm))
			if q.Point.Lat < lo.Lat || q.Point.Lat > hi.Lat || q.Point.Lng < lo.Lng || q.Point.Lng > hi.Lng {
				continue
			}
		}
		phrases := w.Phrases
		if len(phrases) == 0 {
			phrases = []string{w.Query}
		}
		for _, p := range phrases {
			if catalogdomain.HoldsAllWords(p, q.Text) {
				out = append(out, Watcher{PriceMin: w.PriceMin, PriceMax: w.PriceMax, OffersOnly: w.OffersOnly})
				break
			}
		}
	}
	return out, nil
}
```

Check the field names `d.accounts` and `d.watches` against the
`Discovery` struct in `service.go` and use what it has.

- [ ] **Step 8: Run discovery's tests**

Run: `go test -p 4 ./internal/discovery/...`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add internal/discovery
git commit -m "feat(discovery): Watchers, the search watches a listing not yet posted would match"
```

---

### Task 4: `Suggest`, "Bán nhanh" and "Giá thị trường" from the sold listings

**Files:**
- Modify: `internal/assist/domain/fill.go` (`Sample` gains `DaysToSell`)
- Create: `internal/assist/domain/suggest.go`
- Test: `internal/assist/domain/suggest_test.go`

**Interfaces:**
- Produces:
  - `domain.Sample{Price int64; Sold bool; DaysToSell int}`
  - `domain.SuggestionKind` with `SuggestFast = "fast"`, `SuggestMarket = "market"`
  - `domain.Suggestion{Kind SuggestionKind; Price int64; Days int}` (json `kind`, `price`, `days`)
  - `domain.Suggest(samples []Sample, est Estimate) []Suggestion` (never nil; fast first)
  - `domain.MinSoldForSuggestions = 3`

- [ ] **Step 1: Write the table test**

`internal/assist/domain/suggest_test.go`:

```go
package domain_test

import (
	"slices"
	"testing"

	"github.com/shopnexus/server/internal/assist/domain"
)

func sold(price int64, days int) domain.Sample { return domain.Sample{Price: price, Sold: true, DaysToSell: days} }
func live(price int64) domain.Sample          { return domain.Sample{Price: price} }

func TestSuggest(t *testing.T) {
	t.Parallel()
	est := func(median int64) domain.Estimate { return domain.Estimate{Median: median, Source: domain.SourceMarket} }
	cases := []struct {
		name    string
		samples []domain.Sample
		est     domain.Estimate
		want    []domain.Suggestion
	}{
		{"under 3 sold is none", []domain.Sample{sold(1_000_000, 2), sold(1_100_000, 6), live(900_000), live(950_000)},
			est(1_000_000), []domain.Suggestion{}},
		// days 2 6 10, median 6; the fast half is 1.0 (2) and 1.1 (6): price 1.05, days 4.
		{"the quicker half", []domain.Sample{
			sold(1_000_000, 2), sold(1_100_000, 6), sold(1_200_000, 10), live(1_300_000), live(1_400_000), live(1_500_000),
		}, est(1_200_000), []domain.Suggestion{
			{Kind: domain.SuggestFast, Price: 1_050_000, Days: 4},
			{Kind: domain.SuggestMarket, Price: 1_200_000, Days: 6},
		}},
		// days 1 5 9, median 5; the fast half is 1.5 (1) and 1.0 (5): 1.25 is not below 1.2.
		{"a fast half priced above the market is left out", []domain.Sample{
			sold(1_500_000, 1), sold(1_000_000, 5), sold(1_100_000, 9),
		}, est(1_200_000), []domain.Suggestion{{Kind: domain.SuggestMarket, Price: 1_200_000, Days: 5}}},
		{"every sale took as long", []domain.Sample{sold(1_000_000, 3), sold(1_200_000, 3), sold(1_400_000, 3)},
			est(1_300_000), []domain.Suggestion{
				{Kind: domain.SuggestFast, Price: 1_200_000, Days: 3},
				{Kind: domain.SuggestMarket, Price: 1_300_000, Days: 3},
			}},
		// fast half 1,234,567 and 1,250,000: mean 1,242,283, rounded to 1,240,000.
		{"rounded to 10,000", []domain.Sample{sold(1_234_567, 1), sold(1_250_000, 2), sold(2_000_000, 9)},
			est(1_500_000), []domain.Suggestion{
				{Kind: domain.SuggestFast, Price: 1_240_000, Days: 1},
				{Kind: domain.SuggestMarket, Price: 1_500_000, Days: 2},
			}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			t.Parallel()
			if got := domain.Suggest(c.samples, c.est); !slices.Equal(got, c.want) {
				t.Fatalf("%+v, want %+v", got, c.want)
			}
		})
	}
}
```

In the last case the fast half is the sales of at most the median days
(2): 1 and 2 days. Its median days is (1+2)/2 = 1 with the floor.

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/assist/domain/ -run TestSuggest`
Expected: compile error, `undefined: domain.Suggest`.

- [ ] **Step 3: Grow `Sample` and write `suggest.go`**

In `fill.go`, replace `Sample`:

```go
// Sample is the price of a similar listing, whether it sold, and the whole
// days its sale took (0 on sale).
type Sample struct {
	Price      int64
	Sold       bool
	DaysToSell int
}
```

`internal/assist/domain/suggest.go`:

```go
package domain

import "slices"

// MinSoldForSuggestions is how many sold listings a sample needs before a
// guide says what to price at and how long it takes to sell.
const MinSoldForSuggestions = 3

type SuggestionKind string

const (
	SuggestFast   SuggestionKind = "fast"
	SuggestMarket SuggestionKind = "market"
)

// Suggestion is a price to sell at and the days a sale at it usually took.
type Suggestion struct {
	Kind  SuggestionKind `json:"kind"`
	Price int64          `json:"price"`
	Days  int            `json:"days"`
}

// Suggest is "Bán nhanh" and "Giá thị trường" from the samples' sold
// listings, none under MinSoldForSuggestions. The market price is est's
// median, at the median days of every sale. The fast price and days are
// the medians of the sales that took at most that long, left out unless
// the price is below the market's.
func Suggest(samples []Sample, est Estimate) []Suggestion {
	var sold []Sample
	for _, s := range samples {
		if s.Sold {
			sold = append(sold, s)
		}
	}
	if len(sold) < MinSoldForSuggestions {
		return []Suggestion{}
	}
	days := make([]int64, len(sold))
	for i, s := range sold {
		days[i] = int64(s.DaysToSell)
	}
	marketDays := median(days)
	var fastPrices, fastDays []int64
	for _, s := range sold {
		if int64(s.DaysToSell) <= marketDays {
			fastPrices = append(fastPrices, s.Price)
			fastDays = append(fastDays, int64(s.DaysToSell))
		}
	}
	out := []Suggestion{}
	if fast := roundPrice(median(fastPrices)); fast < est.Median {
		out = append(out, Suggestion{Kind: SuggestFast, Price: fast, Days: int(median(fastDays))})
	}
	return append(out, Suggestion{Kind: SuggestMarket, Price: est.Median, Days: int(marketDays)})
}

// median is the middle of xs, the mean of the two middle ones rounded down
// for an even count. xs is not empty.
func median(xs []int64) int64 {
	s := slices.Clone(xs)
	slices.Sort(s)
	m := len(s) / 2
	if len(s)%2 == 1 {
		return s[m]
	}
	return (s[m-1] + s[m]) / 2
}
```

`fastPrices` is never empty: the quickest sale took at most the median.

- [ ] **Step 4: Run assist's domain tests**

Run: `go test ./internal/assist/domain/`
Expected: PASS, `TestMarketEstimate` included.

- [ ] **Step 5: Commit**

```bash
git add internal/assist/domain
git commit -m "feat(assist): Suggest, Bán nhanh and Giá thị trường from a sample's sales"
```

---

### Task 5: One helper turns a draft into a price sample for the reads and the guide

**Files:**
- Modify: `internal/assist/service/estimate.go`

**Interfaces:**
- Consumes: `catalogsvc.PriceSample` (Task 1), `domain.Sample` (Task 4).
- Produces (package-private, used by Task 6):
  - `func (d Deps) draftSample(ctx context.Context, log *slog.Logger, account uuid.UUID, in catalogdomain.ListingInput, at time.Time) ([]catalogsvc.PriceSample, error)`
  - `func samplesOf(ss []catalogsvc.PriceSample) []domain.Sample`

- [ ] **Step 1: Run the reads' estimate tests as the baseline**

Run: `go test -p 4 ./internal/assist/service/ -run 'Estimate'`
Expected: PASS (`TestReadMarketEstimate`, `TestReadEstimateWithoutEmbeddings`).

- [ ] **Step 2: Split `marketEstimate`**

Replace the body of `estimate.go` below the imports with:

```go
// marketEstimate is the price range of the listings most like draft, or
// nil: without a category, past the deadline, under
// domain.MinMarketSample similar listings, or when the step fails. The
// reads call it after their draft is saved; draft's photos are waiting
// uploads of account's.
func (d Deps) marketEstimate(ctx restate.Context, read, account uuid.UUID, draft domain.Draft, at, deadline time.Time) *domain.Estimate {
	if !at.Before(deadline) || draft.CategoryCode == "" {
		return nil
	}
	in := catalogdomain.ListingInput{
		Title: draft.Title, CategoryCode: draft.CategoryCode, Condition: draft.Condition, Specs: draft.Specs,
		Description: draft.Description, Photos: draft.Photos,
	}
	m, err := restate.Run(ctx, func(rc restate.RunContext) (*domain.Estimate, error) {
		samples, err := d.draftSample(rc, d.Log.With("read", read), account, in, at)
		if err != nil {
			return nil, err
		}
		return domain.MarketEstimate(samplesOf(samples)), nil
	}, restate.WithMaxRetryDuration(deadline.Sub(at)), restate.WithMaxRetryAttempts(modelAttempts))
	if err != nil {
		return nil
	}
	return m
}

// draftSample draws the price sample of the listings most like in, as of
// at, without account's own: in's embedding text and the normalized mean
// of its photos, which must be waiting uploads of account's. A model that
// fails leaves its list out and logs to log; with neither, the sample is
// nil. The reads and the price guide call it, so both price a draft alike.
func (d Deps) draftSample(ctx context.Context, log *slog.Logger, account uuid.UUID, in catalogdomain.ListingInput, at time.Time,
) ([]catalogsvc.PriceSample, error) {
	text, err := d.Catalog.EmbeddingText(ctx, in)
	if err != nil {
		return nil, fmt.Errorf("build the embedding text: %w", err)
	}
	inputs := make([]string, len(in.Photos))
	for i, p := range in.Photos {
		img, imgErr := d.Media.QueryImage(ctx, account, p)
		if imgErr != nil {
			return nil, fmt.Errorf("read photo %s: %w", p, imgErr)
		}
		inputs[i] = embed.ImageInput(img)
	}
	q := catalogsvc.PriceQuery{
		Exclude: account, CategoryCode: in.CategoryCode, Condition: in.Condition,
		TextMin: d.TextMin, PhotoMin: d.PhotoMin, Now: at,
	}
	embedCtx, cancel := context.WithTimeout(ctx, d.CallTimeout)
	defer cancel()
	if vs, embedErr := d.Text.Embed(embedCtx, []string{text}); embedErr != nil {
		log.WarnContext(ctx, "the price sample goes without the text vector", "err", embedErr)
	} else {
		q.Text = vs[0]
	}
	if len(inputs) > 0 {
		if vs, embedErr := d.Image.Embed(embedCtx, inputs); embedErr != nil || len(vs) == 0 {
			log.WarnContext(ctx, "the price sample goes without the photo vector", "err", embedErr)
		} else {
			q.Photo = meanVector(vs)
		}
	}
	samples, err := d.Catalog.PriceSample(ctx, q)
	if err != nil {
		return nil, fmt.Errorf("price sample: %w", err)
	}
	return samples, nil
}

// meanVector is the normalized mean of vs, as like does with a listing's
// photos; nil when it is the zero vector.
func meanVector(vs [][]float32) []float32 {
	mean := make([]float32, len(vs[0]))
	for _, v := range vs {
		for j, x := range v {
			mean[j] += x
		}
	}
	var norm float64
	for _, x := range mean {
		norm += float64(x) * float64(x)
	}
	if norm == 0 {
		return nil
	}
	scale := float32(1 / math.Sqrt(norm))
	for j := range mean {
		mean[j] *= scale
	}
	return mean
}

// samplesOf is catalog's sample as the domain weighs it.
func samplesOf(ss []catalogsvc.PriceSample) []domain.Sample {
	out := make([]domain.Sample, len(ss))
	for i, s := range ss {
		out[i] = domain.Sample{Price: s.Price, Sold: s.Sold, DaysToSell: s.DaysToSell}
	}
	return out
}
```

Add `"log/slog"` to the imports. `restate.RunContext` is a
`context.Context`, so `draftSample(rc, ...)` compiles. A draft with no
photo skips the image call: the reads always had photos, the guide may
not.

- [ ] **Step 3: Run assist's service tests**

Run: `go test -p 4 ./internal/assist/service/`
Expected: PASS, the same tests as Step 1 and every read test.

- [ ] **Step 4: Commit**

```bash
git add internal/assist/service/estimate.go
git commit -m "refactor(assist): draftSample, one way from a draft to a price sample"
```

---

### Task 6: `POST /v1/price-guides`

**Files:**
- Modify: `api/schemas/assist.yaml` (five schemas)
- Modify: `api/paths/assist.yaml` (`priceGuides`)
- Modify: `api/openapi.yaml` (the path)
- Create: `internal/assist/service/price_guide.go`
- Modify: `internal/assist/service/service.go` (`Service.PriceGuide`, `Deps.Discovery`)
- Modify: `internal/assist/service/views.go` (`PriceGuideView`, `SimilarView`)
- Create: `internal/assist/handler/price_guide.go`
- Modify: `internal/assist/handler/handler.go` (route)
- Modify: `internal/assist/assist.go` (Mount takes discovery)
- Modify: `internal/app/app.go:329-341` (pass `discoverym.Service`)
- Test: `internal/assist/service/helpers_test.go` (default fake discovery), `internal/assist/service/price_guide_test.go`

**Interfaces:**
- Consumes: Tasks 1, 3, 4, 5.
- Produces: `Service.PriceGuide(ctx context.Context, account uuid.UUID, in PriceGuideInput) (PriceGuideView, error)`; `PriceGuideInput{Title, CategoryCode, Description, CommuneCode string; Condition catalogdomain.Condition; Specs []catalogdomain.Spec; Photos []uuid.UUID}`.

- [ ] **Step 1: Write the OpenAPI**

`api/schemas/assist.yaml`, after `PriceEstimate`:

```yaml
PriceGuideRequest:
  type: object
  additionalProperties: false
  required: [title, category_code, condition, commune_code]
  description: The draft as it stands in the Giá step; ListingInput's fields that price an item.
  properties:
    title:
      type: string
      minLength: 1
      maxLength: 70
    category_code:
      type: string
      description: A subcategory code.
    condition:
      $ref: "catalog.yaml#/Condition"
    specs:
      type: array
      maxItems: 20
      items:
        $ref: "catalog.yaml#/Spec"
    description:
      type: string
      maxLength: 1500
    commune_code:
      type: string
      description: The listing's commune; distances and watch areas are measured from its point.
    photos:
      type: array
      maxItems: 3
      uniqueItems: true
      description: The caller's waiting photo uploads, the cover first. Without photos the text alone is compared.
      items:
        type: string
        format: uuid
PriceGuide:
  type: object
  additionalProperties: false
  required: [estimate, suggestions, similar, sold_prices, live_prices, watchers]
  properties:
    estimate:
      description: The range of the listings most like the draft; null under 5 of them or when the comparison failed.
      anyOf:
        - $ref: "#/PriceEstimate"
        - type: "null"
    suggestions:
      type: array
      maxItems: 2
      description: fast before market; empty under 3 sold listings. fast is left out unless it is below market.
      items:
        $ref: "#/PriceSuggestion"
    similar:
      type: array
      maxItems: 12
      description: The most similar listings first, sold within 180 days or on sale and published within 90.
      items:
        $ref: "#/SimilarListing"
    sold_prices:
      type: array
      description: The prices of the compared listings that sold, ascending.
      items:
        type: integer
        format: int64
    live_prices:
      type: array
      description: The prices of the compared listings on sale, ascending.
      items:
        type: integer
        format: int64
    watchers:
      type: array
      maxItems: 200
      description: |
        One row per search watch, muted ones too, that a listing of this
        draft would match by category, condition, area and words. The app
        counts the rows whose price range holds its price and whose
        offers_only its offers switch allows.
      items:
        $ref: "#/Watcher"
PriceSuggestion:
  type: object
  additionalProperties: false
  required: [kind, price, days]
  properties:
    kind:
      type: string
      enum: [fast, market]
    price:
      type: integer
      format: int64
    days:
      type: integer
      minimum: 1
      description: The median whole days from publication to sale at this price.
SimilarListing:
  type: object
  additionalProperties: false
  required: [listing_id, title, cover_url, price, condition, sold, km]
  properties:
    listing_id:
      type: string
      format: uuid
    title:
      type: string
    cover_url:
      type: string
    price:
      type: integer
      format: int64
    condition:
      $ref: "catalog.yaml#/Condition"
    sold:
      type: boolean
    km:
      type: integer
      minimum: 0
      description: Whole kilometres from the draft's commune.
    days_to_sell:
      type: integer
      minimum: 1
      description: Sold listings only.
Watcher:
  type: object
  additionalProperties: false
  required: [offers_only]
  properties:
    price_min:
      type: integer
      format: int64
    price_max:
      type: integer
      format: int64
    offers_only:
      type: boolean
```

`api/paths/assist.yaml`, append:

```yaml
priceGuides:
  post:
    operationId: createPriceGuide
    summary: Price a listing draft against similar listings and the buyers watching for it.
    description: |
      Compares the draft with the listings most like it, by text and by
      photo, and answers the range, the two suggestions, the similar
      listings, their prices, and the search watches a listing of the draft
      would match. Stores nothing. POST because the body carries the draft.
    tags: [assist]
    security:
      - bearerAuth: []
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/assist.yaml#/PriceGuideRequest"
    responses:
      "200":
        description: The guide; empty lists when nothing is similar.
        content:
          application/json:
            schema:
              $ref: "../schemas/assist.yaml#/PriceGuide"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "403":
        description: "The account is suspended (account_suspended)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: |
          The category is not a subcategory or the commune is not on the list
          (invalid_listing, with fields); a photo is not the caller's, not a
          photo, already in a listing or expired (invalid_upload).
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

`api/openapi.yaml`, after `/v1/link-previews`:

```yaml
  /v1/price-guides:
    $ref: "paths/assist.yaml#/priceGuides"
```

Run: `go test ./api/...` (or the repo's spec lint, `make lint-api` if the
Makefile has it). Expected: PASS.

- [ ] **Step 2: Give the test env a discovery**

In `helpers_test.go`, add a fake and set it in `newEnv`'s `e.deps`:

```go
// watchersOf is discovery whose Watchers answers rows and keeps the query.
type watchersOf struct {
	discoverysvc.Service

	mu    sync.Mutex
	rows  []discoverysvc.Watcher
	asked discoverysvc.WatcherQuery
	who   uuid.UUID
}

func (w *watchersOf) Watchers(_ context.Context, seller uuid.UUID, q discoverysvc.WatcherQuery) ([]discoverysvc.Watcher, error) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.asked, w.who = q, seller
	return w.rows, nil
}
```

with `discoverysvc "github.com/shopnexus/server/internal/discovery/service"`,
an `e.watchers *watchersOf` field on `env`, and in `newEnv` before the
options: `e.watchers = &watchersOf{rows: []discoverysvc.Watcher{}}` and
`Discovery: e.watchers` in `e.deps`.

- [ ] **Step 3: Write the service test**

`internal/assist/service/price_guide_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"slices"
	"testing"
	"uuid"

	"github.com/shopnexus/server/internal/account/accounttest"
	"github.com/shopnexus/server/internal/assist/domain"
	"github.com/shopnexus/server/internal/assist/service"
	"github.com/shopnexus/server/internal/catalog/catalogtest"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	catalogsvc "github.com/shopnexus/server/internal/catalog/service"
	discoverysvc "github.com/shopnexus/server/internal/discovery/service"
	mediadomain "github.com/shopnexus/server/internal/media/domain"
	"github.com/shopnexus/server/internal/media/mediatest"
	"github.com/shopnexus/server/internal/platform/apperr"
)

// bike is a guide's draft: a used bicycle in commune 00004.
func bike() service.PriceGuideInput {
	return service.PriceGuideInput{
		Title: "Xe đạp Asama", CategoryCode: "vehicles.bicycle", Condition: catalogdomain.ConditionUsed,
		Specs: []catalogdomain.Spec{{Label: "Khung", Value: "nhôm"}}, Description: "Đi ít", CommuneCode: "00004",
	}
}

func TestPriceGuide(t *testing.T) {
	t.Parallel()
	var cat *sampleOf
	e := newEnv(t, func(x *env) {
		cat = &sampleOf{Service: x.deps.Catalog}
		x.deps.Catalog = cat
	})
	ctx := context.Background()
	seller, me := accounttest.New(t, e.db), accounttest.New(t, e.db)
	far := catalogdomain.Point{Lat: 21.0394, Lng: 105.9364} // about 10 km east of 00004
	listing := func(price int64, p catalogdomain.Point) uuid.UUID {
		return catalogtest.Listing(t, e.db, seller, func(d *catalogdomain.ListingInput, r *catalogdomain.Refs) {
			d.Price, r.CommunePoint = price, p
		})
	}
	var samples []catalogsvc.PriceSample
	for _, s := range []struct {
		price int64
		days  int
	}{{1_000_000, 2}, {1_100_000, 6}, {1_200_000, 10}, {1_300_000, 0}, {1_400_000, 0}, {1_500_000, 0}} {
		id := listing(s.price, far)
		samples = append(samples, catalogsvc.PriceSample{
			ListingID: id, Price: s.price, Sold: s.days > 0, DaysToSell: s.days, Point: far,
		})
	}
	gone := uuid.NewV7() // in the sample, deleted before the summaries
	samples = append(samples, catalogsvc.PriceSample{ListingID: gone, Price: 1_600_000})
	cat.samples = samples
	e.watchers.rows = []discoverysvc.Watcher{{PriceMax: 1_250_000}, {OffersOnly: true}}
	photo := mediatest.Upload(t, e.media, me, "image/jpeg", mediatest.JPEG(t, 96, 64))
	in := bike()
	in.Photos = []uuid.UUID{photo}

	v, err := e.assist.PriceGuide(ctx, me, in)
	if err != nil {
		t.Fatal(err)
	}
	// Weights 2 2 2 1 1 1 1 sum to 10; the running weight reaches 5 at 1.2.
	if v.Estimate == nil || v.Estimate.Median != 1_200_000 || v.Estimate.SampleSize != 7 {
		t.Fatalf("estimate %+v", v.Estimate)
	}
	if want := []domain.Suggestion{
		{Kind: domain.SuggestFast, Price: 1_050_000, Days: 4}, {Kind: domain.SuggestMarket, Price: 1_200_000, Days: 6},
	}; !slices.Equal(v.Suggestions, want) {
		t.Fatalf("suggestions %+v", v.Suggestions)
	}
	if len(v.Similar) != 6 || v.Similar[0].Price != 1_000_000 || !v.Similar[0].Sold || v.Similar[0].DaysToSell == nil ||
		*v.Similar[0].DaysToSell != 2 || v.Similar[3].DaysToSell != nil || v.Similar[0].Km < 9 || v.Similar[0].Km > 11 ||
		v.Similar[0].Title != "Xe đạp Asama" || v.Similar[0].CoverURL == "" {
		t.Fatalf("similar %+v", v.Similar)
	}
	if !slices.Equal(v.SoldPrices, []int64{1_000_000, 1_100_000, 1_200_000}) ||
		!slices.Equal(v.LivePrices, []int64{1_300_000, 1_400_000, 1_500_000, 1_600_000}) {
		t.Fatalf("prices %v %v", v.SoldPrices, v.LivePrices)
	}
	if len(v.Watchers) != 2 || v.Watchers[0].PriceMax != 1_250_000 || !v.Watchers[1].OffersOnly {
		t.Fatalf("watchers %+v", v.Watchers)
	}
	e.watchers.mu.Lock()
	asked, who := e.watchers.asked, e.watchers.who
	e.watchers.mu.Unlock()
	if who != me || asked.CategoryCode != "vehicles.bicycle" || asked.Point.Lat != 21.0394 ||
		asked.Text != "Xe đạp Asama\nĐi ít\nKhung: nhôm" {
		t.Fatalf("watchers asked %v %+v", who, asked)
	}
	cat.mu.Lock()
	q := cat.asked
	cat.mu.Unlock()
	if q.Exclude != me || len(q.Text) != catalogdomain.TextDims || len(q.Photo) != catalogdomain.PhotoDims {
		t.Fatalf("sample asked %+v", q)
	}
}

// Under 5 similar listings there is no range and no suggestion; the
// listings found and the watchers still answer.
func TestPriceGuideFewListings(t *testing.T) {
	t.Parallel()
	var cat *sampleOf
	e := newEnv(t, func(x *env) {
		cat = &sampleOf{Service: x.deps.Catalog}
		x.deps.Catalog = cat
	})
	seller, me := accounttest.New(t, e.db), accounttest.New(t, e.db)
	id := catalogtest.Listing(t, e.db, seller)
	cat.samples = []catalogsvc.PriceSample{{ListingID: id, Price: 1_500_000, Sold: true, DaysToSell: 3}}
	e.watchers.rows = []discoverysvc.Watcher{{}}
	v, err := e.assist.PriceGuide(context.Background(), me, bike())
	if err != nil {
		t.Fatal(err)
	}
	if v.Estimate != nil || len(v.Suggestions) != 0 || len(v.Similar) != 1 || len(v.Watchers) != 1 ||
		!slices.Equal(v.SoldPrices, []int64{1_500_000}) || v.LivePrices == nil {
		t.Fatalf("%+v", v)
	}
}

// Embedding models that are down give a guide without a comparison; the
// watchers still answer.
func TestPriceGuideWithoutEmbeddings(t *testing.T) {
	t.Parallel()
	e := newEnv(t, func(x *env) { x.deps.Text, x.deps.Image = failingEmbed{}, failingEmbed{} })
	e.watchers.rows = []discoverysvc.Watcher{{}}
	v, err := e.assist.PriceGuide(context.Background(), accounttest.New(t, e.db), bike())
	if err != nil || v.Estimate != nil || len(v.Similar) != 0 || len(v.Watchers) != 1 {
		t.Fatalf("%+v %v", v, err)
	}
}

func TestPriceGuideRefusals(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me, other := accounttest.New(t, e.db), accounttest.New(t, e.db)

	in := bike()
	in.CategoryCode = "vehicles"
	_, err := e.assist.PriceGuide(ctx, me, in)
	if a, ok := errors.AsType[*apperr.Error](err); !ok || a.Code != "invalid_listing" || a.Fields["category_code"] == "" {
		t.Fatalf("a root category: %v", err)
	}
	in = bike()
	in.CommuneCode = "99999"
	_, err = e.assist.PriceGuide(ctx, me, in)
	if a, ok := errors.AsType[*apperr.Error](err); !ok || a.Fields["commune_code"] == "" {
		t.Fatalf("an unknown commune: %v", err)
	}
	in = bike()
	in.Photos = []uuid.UUID{mediatest.Upload(t, e.media, other, "image/jpeg", mediatest.JPEG(t, 96, 64))}
	if _, err = e.assist.PriceGuide(ctx, me, in); !errors.Is(err, mediadomain.ErrInvalidUpload) {
		t.Fatalf("someone else's photo: %v", err)
	}
	suspended := accounttest.New(t, e.db)
	accounttest.Suspend(t, e.accounts, suspended)
	if _, err = e.assist.PriceGuide(ctx, suspended, bike()); err == nil {
		t.Fatal("a suspended account")
	}
}
```

`accounttest.Suspend(t, accounts, id)` and `apperr.Error{Code, Fields}`
are as used here.

- [ ] **Step 4: Run it to see it fail**

Run: `go test -p 4 ./internal/assist/service/ -run PriceGuide`
Expected: compile error, `e.assist.PriceGuide undefined`.

- [ ] **Step 5: Write the views, the dependency and the use case**

`service.go`: add to `Service`:

```go
	// PriceGuide prices a draft against the listings most like it and the
	// search watches it would match, and stores nothing.
	PriceGuide(ctx context.Context, account uuid.UUID, in PriceGuideInput) (PriceGuideView, error)
```

and to `Deps`, after `Catalog`:

```go
	// Discovery gives the search watches a draft would match.
	Discovery discoverysvc.Service
```

`views.go`, append:

```go
// PriceGuideView is the PriceGuide schema.
type PriceGuideView struct {
	Estimate    *domain.Estimate        `json:"estimate"`
	Suggestions []domain.Suggestion     `json:"suggestions"`
	Similar     []SimilarView           `json:"similar"`
	SoldPrices  []int64                 `json:"sold_prices"`
	LivePrices  []int64                 `json:"live_prices"`
	Watchers    []discoverysvc.Watcher  `json:"watchers"`
}

// SimilarView is the SimilarListing schema; DaysToSell only when sold.
type SimilarView struct {
	ListingID  uuid.UUID               `json:"listing_id"`
	Title      string                  `json:"title"`
	CoverURL   string                  `json:"cover_url"`
	Price      int64                   `json:"price"`
	Condition  catalogdomain.Condition `json:"condition"`
	Sold       bool                    `json:"sold"`
	Km         int                     `json:"km"`
	DaysToSell *int                    `json:"days_to_sell,omitempty"`
}
```

`internal/assist/service/price_guide.go`:

```go
package service

import (
	"context"
	"fmt"
	"slices"
	"strings"
	"uuid"

	"github.com/shopnexus/server/internal/assist/domain"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	discoverysvc "github.com/shopnexus/server/internal/discovery/service"
)

// maxSimilar is how many of the sample a guide shows.
const maxSimilar = 12

// PriceGuideInput is the draft a guide prices: PriceGuideRequest.
type PriceGuideInput struct {
	Title, CategoryCode, Description, CommuneCode string
	Condition                                     catalogdomain.Condition
	Specs                                         []catalogdomain.Spec
	Photos                                        []uuid.UUID
}

// PriceGuide checks the account, the category, the commune and the
// photos, draws the sample as the reads do, and answers the range, the
// suggestions, the first similar listings with their distance, the
// sample's prices and the matching watches. A sample that fails gives a
// guide without a comparison; the watchers still answer.
func (a *Assist) PriceGuide(ctx context.Context, account uuid.UUID, in PriceGuideInput) (PriceGuideView, error) {
	started := a.d.Now()
	status, err := a.d.Accounts.Status(ctx, account)
	if err != nil {
		return PriceGuideView{}, fmt.Errorf("read account status: %w", err)
	}
	if r := status.Refusal(); r != nil {
		return PriceGuideView{}, r
	}
	cats, err := a.d.Catalog.Categories(ctx)
	if err != nil {
		return PriceGuideView{}, fmt.Errorf("read categories: %w", err)
	}
	places, err := a.d.Catalog.Places(ctx, []string{in.CommuneCode})
	if err != nil {
		return PriceGuideView{}, fmt.Errorf("read the commune: %w", err)
	}
	place, communeOK := places[in.CommuneCode]
	leaf := slices.ContainsFunc(cats, func(c catalogdomain.Category) bool { return c.Code == in.CategoryCode && c.ParentCode != "" })
	if !leaf || !communeOK {
		e := catalogdomain.ErrInvalidListing
		if !leaf {
			e = e.WithField("category_code", "a subcategory")
		}
		if !communeOK {
			e = e.WithField("commune_code", "a commune of the administrative list")
		}
		return PriceGuideView{}, e
	}
	// The photos are checked before any model runs, so a wrong one is
	// invalid_upload and never a guide without a comparison.
	for _, p := range in.Photos {
		if _, err = a.d.Media.QueryUpload(ctx, account, p); err != nil {
			return PriceGuideView{}, err
		}
	}
	origin := catalogdomain.Point{Lat: place.Lat, Lng: place.Lng}

	v := PriceGuideView{
		Suggestions: []domain.Suggestion{}, Similar: []SimilarView{}, SoldPrices: []int64{}, LivePrices: []int64{},
	}
	samples, err := a.d.draftSample(ctx, a.d.Log, account, catalogdomain.ListingInput{
		Title: in.Title, CategoryCode: in.CategoryCode, Condition: in.Condition, Specs: in.Specs,
		Description: in.Description, Photos: in.Photos,
	}, started)
	if err != nil {
		a.d.Log.WarnContext(ctx, "the price guide goes without a sample", "err", err)
		samples = nil
	}
	ss := samplesOf(samples)
	v.Estimate = domain.MarketEstimate(ss)
	if v.Estimate != nil {
		v.Suggestions = domain.Suggest(ss, *v.Estimate)
	}
	for _, s := range samples {
		if s.Sold {
			v.SoldPrices = append(v.SoldPrices, s.Price)
		} else {
			v.LivePrices = append(v.LivePrices, s.Price)
		}
	}
	slices.Sort(v.SoldPrices)
	slices.Sort(v.LivePrices)
	first := samples[:min(len(samples), maxSimilar)]
	ids := make([]uuid.UUID, len(first))
	for i, s := range first {
		ids[i] = s.ListingID
	}
	summaries, err := a.d.Catalog.Summaries(ctx, ids)
	if err != nil {
		return PriceGuideView{}, fmt.Errorf("read similar listings: %w", err)
	}
	for _, s := range first {
		sum, ok := summaries[s.ListingID]
		if !ok { // deleted since the sample
			continue
		}
		sv := SimilarView{
			ListingID: s.ListingID, Title: sum.Title, CoverURL: sum.CoverThumbURL, Price: sum.Price,
			Condition: sum.Condition, Sold: s.Sold, Km: int(catalogdomain.Distance(origin, s.Point)),
		}
		if s.Sold {
			sv.DaysToSell = new(s.DaysToSell)
		}
		v.Similar = append(v.Similar, sv)
	}

	var text strings.Builder
	text.WriteString(in.Title + "\n" + in.Description)
	for _, s := range in.Specs {
		text.WriteString("\n" + s.Label + ": " + s.Value)
	}
	if v.Watchers, err = a.d.Discovery.Watchers(ctx, account, discoverysvc.WatcherQuery{
		CategoryCode: in.CategoryCode, Condition: in.Condition, Point: origin, Text: text.String(),
	}); err != nil {
		return PriceGuideView{}, fmt.Errorf("read watchers: %w", err)
	}

	source := "none"
	if v.Estimate != nil {
		source = string(v.Estimate.Source)
	}
	a.d.Log.InfoContext(ctx, "price guide", "category", in.CategoryCode, "condition", in.Condition,
		"photos", len(in.Photos), "sample", len(samples), "sold", len(v.SoldPrices), "estimate", source,
		"suggestions", len(v.Suggestions), "watchers", len(v.Watchers), "took", a.d.Now().Sub(started))
	return v, nil
}
```

If `Catalog.Summaries` does not return sold listings, check
`listings.GetMany` and use a read that does; the test's sold listings
would show it as `len(v.Similar) != 6`.

- [ ] **Step 6: Run the service tests**

Run: `go test -p 4 ./internal/assist/service/`
Expected: PASS, every read test too.

- [ ] **Step 7: Add the handler and wire discovery in**

`internal/assist/handler/price_guide.go`:

```go
package handler

import (
	"net/http"
	"uuid"

	"github.com/shopnexus/server/internal/assist/service"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/platform/httpx"
)

// priceGuideRequest is PriceGuideRequest; the request validator holds the
// shape rules.
type priceGuideRequest struct {
	Title        string                  `json:"title"`
	CategoryCode string                  `json:"category_code"`
	Condition    catalogdomain.Condition `json:"condition"`
	Specs        []catalogdomain.Spec    `json:"specs"`
	Description  string                  `json:"description"`
	CommuneCode  string                  `json:"commune_code"`
	Photos       []uuid.UUID             `json:"photos"`
}

// PriceGuide serves POST /v1/price-guides.
func (h *Handler) PriceGuide(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in priceGuideRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	v, err := h.svc.PriceGuide(r.Context(), p.AccountID, service.PriceGuideInput{
		Title: in.Title, CategoryCode: in.CategoryCode, Condition: in.Condition, Specs: in.Specs,
		Description: in.Description, CommuneCode: in.CommuneCode, Photos: in.Photos,
	})
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, v)
}
```

`handler.go`, in `Register`:

```go
	r.Handle("POST /v1/price-guides", protect(http.HandlerFunc(h.PriceGuide)))
```

`assist.go`: `Mount` takes `discovery discoverysvc.Service` after
`catalog` and sets `Discovery: discovery` in `service.Deps`; update the
package comment to "reads a seller's video, photo or Chợ Tốt listing into
a listing draft and prices a draft".

`internal/app/app.go`: `assist.Mount(d, assist.Settings{...}, accounts,
mediam.Service, catalogm.Service, discoverym.Service)`. Discovery is
mounted just above assist, so no move is needed.

Run: `go build ./... && golangci-lint run ./internal/assist/... ./internal/discovery/... ./internal/catalog/...`
Expected: no output.

- [ ] **Step 8: Commit**

```bash
git add api internal/assist internal/app/app.go
git commit -m "feat(assist): POST /v1/price-guides, the Giá step's market for any draft"
```

---

### Task 7: e2e, a guide from posted listings and a buyer's watch

**Files:**
- Create: `e2e/price_guide_test.go`

**Interfaces:**
- Consumes: `newAccount`, `activeListing`, `upload`, `photoWithGPS`, `call`, `expect`, `check`, `bearer`, `suspend`, `db` (e2e helpers).

- [ ] **Step 1: Write the test**

```go
package e2e

import (
	"context"
	"fmt"
	"net/http"
	"slices"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"

	"github.com/shopnexus/server/internal/platform/testenv"
)

type priceGuide struct {
	Estimate *struct {
		Low, Median, High int64
		Source            string `json:"source"`
		SampleSize        int    `json:"sample_size"`
	} `json:"estimate"`
	Suggestions []struct {
		Kind  string `json:"kind"`
		Price int64  `json:"price"`
		Days  int    `json:"days"`
	} `json:"suggestions"`
	Similar []struct {
		ListingID  string `json:"listing_id"`
		Sold       bool   `json:"sold"`
		Km         int    `json:"km"`
		DaysToSell *int   `json:"days_to_sell"`
	} `json:"similar"`
	SoldPrices []int64 `json:"sold_prices"`
	LivePrices []int64 `json:"live_prices"`
	Watchers   []struct {
		PriceMax   int64 `json:"price_max"`
		OffersOnly bool  `json:"offers_only"`
	} `json:"watchers"`
}

// Six listings with the guide's own text, three sold after 2, 6 and 10
// days; a buyer's watch for its words; a third account prices the draft.
func TestPriceGuide(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	me, _ := newAccount(t)
	word := "guide" + uuid.NewV7().String()[:8] // a word no other test's listing holds
	title := "Ghế xếp " + word
	fields := func(price int64) map[string]any {
		return map[string]any{"title": title, "category_code": "furniture.other", "price": price}
	}
	var ids []string
	for _, price := range []int64{1_000_000, 1_100_000, 1_200_000, 1_300_000, 1_400_000, 1_500_000} {
		ids = append(ids, activeListing(t, seller.AccessToken, fields(price)).ID)
	}
	for i, days := range []int{2, 6, 10} {
		expectStatus(t, call(t, "POST", "/v1/listings/"+ids[i]+"/mark-sold", nil, bearer(seller.AccessToken)), http.StatusOK)
		if _, err := db.Exec(context.Background(), `UPDATE listings SET published_at = sold_at - make_interval(days => @days)
WHERE id = @id`, pgx.StrictNamedArgs{"id": ids[i], "days": days}); err != nil {
			t.Fatal(err)
		}
	}
	testenv.Eventually(t, 30*time.Second, func() error {
		var n int
		if err := db.QueryRow(context.Background(), `SELECT count(*) FROM listing_text_vectors WHERE listing_id = ANY(@ids::uuid[])`,
			pgx.StrictNamedArgs{"ids": ids}).Scan(&n); err != nil {
			t.Fatal(err)
		}
		if n < len(ids) {
			return fmt.Errorf("%d of %d text vectors", n, len(ids))
		}
		return nil
	})
	w := expect[searchWatch](t, call(t, "POST", "/v1/search/watches",
		map[string]any{"q": "ghế " + word, "price_max": 1_250_000}, bearer(buyer.AccessToken)), http.StatusCreated)
	// The model's phrases for an unknown word are not this test's subject.
	if _, err := db.Exec(context.Background(), `UPDATE search_watches SET phrases = jsonb_build_array(@word::text) WHERE id = @id`,
		pgx.StrictNamedArgs{"word": word, "id": w.ID}); err != nil {
		t.Fatal(err)
	}

	draft := map[string]any{
		"title": title, "category_code": "furniture.other", "condition": "used", "description": "Đi ít",
		"commune_code": "00004",
	}
	g := expect[priceGuide](t, call(t, "POST", "/v1/price-guides", draft, bearer(me.AccessToken)), http.StatusOK)
	if g.Estimate == nil || g.Estimate.Source != "market" || g.Estimate.Median != 1_200_000 || g.Estimate.SampleSize != 6 {
		t.Fatalf("estimate %+v", g.Estimate)
	}
	if len(g.Suggestions) != 2 || g.Suggestions[0].Kind != "fast" || g.Suggestions[0].Price != 1_050_000 ||
		g.Suggestions[0].Days != 4 || g.Suggestions[1].Price != 1_200_000 || g.Suggestions[1].Days != 6 {
		t.Fatalf("suggestions %+v", g.Suggestions)
	}
	if len(g.Similar) != 6 || len(g.SoldPrices) != 3 || len(g.LivePrices) != 3 {
		t.Fatalf("similar %+v, sold %v, live %v", g.Similar, g.SoldPrices, g.LivePrices)
	}
	// Other tests' watches share the database; ours is the one at 1,250,000.
	if !slices.ContainsFunc(g.Watchers, func(w struct {
		PriceMax   int64 `json:"price_max"`
		OffersOnly bool  `json:"offers_only"`
	}) bool {
		return w.PriceMax == 1_250_000
	}) {
		t.Fatalf("watchers %+v", g.Watchers)
	}
}

func TestPriceGuideRefusals(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	other, _ := newAccount(t)
	draft := func(change map[string]any) map[string]any {
		d := map[string]any{"title": "Xe đạp Asama", "category_code": "vehicles.bicycle", "condition": "used", "commune_code": "00004"}
		for k, v := range change {
			d[k] = v
		}
		return d
	}
	post := func(token string, body map[string]any) Response {
		return call(t, "POST", "/v1/price-guides", body, bearer(token))
	}
	check(t, "signed out", call(t, "POST", "/v1/price-guides", draft(nil)), 401, "unauthenticated")
	check(t, "no title", post(me.AccessToken, draft(map[string]any{"title": ""})), 400, "invalid_request")
	check(t, "a root category", post(me.AccessToken, draft(map[string]any{"category_code": "vehicles"})), 422, "invalid_listing")
	check(t, "someone else's photo", post(me.AccessToken,
		draft(map[string]any{"photos": []string{upload(t, other.AccessToken, photoWithGPS(t))}})), 422, "invalid_upload")
	suspended, _ := newAccount(t)
	suspend(t, suspended.Account.ID)
	check(t, "suspended", post(suspended.AccessToken, draft(nil)), 403, "account_suspended")
	expectStatus(t, post(me.AccessToken, draft(nil)), http.StatusOK)
}
```

The listings' description is `draftWith`'s "Đi ít", so the guide's draft
has the same embedding text and the text vectors meet at cosine 1. The
listings' photos have no counterpart in the draft, which sends none.

- [ ] **Step 2: Run the e2e suite**

Run: `make test` (it runs e2e with the rest; or `go test -p 4 ./e2e/ -run 'PriceGuide|WatchCandidates'` once the stack is up, then the full `make test` so `uncovered` sees every `createPriceGuide` code).
Expected: PASS, and no "declared responses no test observed".

- [ ] **Step 3: Commit**

```bash
git add e2e/price_guide_test.go
git commit -m "e2e: a price guide from sold and live listings and a buyer's watch"
```

---

### Task 8: Record the decisions

**Files:**
- Modify: `server/ARCHITECTURE.md` (Assist; Search watches)
- Modify: `~/shopnexus/checklist.md`
- Modify: `~/shopnexus/docs/superpowers/specs/2026-11-13-price-guide-design.md` (one line)

- [ ] **Step 1: ARCHITECTURE.md, Assist**

After the listing reads' bullets, add a "The price guide" block (decided
2026-11-13, spec path). One bullet each: `POST /v1/price-guides` is a
synchronous read that stores nothing and has no cap until the general
rate limit; it refuses a suspended account (`account_suspended`), an
unknown subcategory or commune (`invalid_listing`), and a photo that is not
a waiting upload of the caller's (`invalid_upload`), checked before any
model; `draftSample` is the one path from a draft to a sample for the
reads and the guide; the sample now carries listing, days to sell and
point; `Suggest`'s two rules and the 3-sales floor; the first 12 of the
sample, a listing gone since the sample left out, `km` from the draft's
commune; a failing sample gives a guide without a comparison and the
watchers still answer; the log line's fields.

- [ ] **Step 2: ARCHITECTURE.md, Search watches**

Add a bullet: `Watchers` matches a listing not yet posted in reverse:
SQL takes the watches of active accounts by category, root and condition
(muted ones too, the seller's own and blocked pairs left out, oldest
first, at most 5,000), Go keeps those whose box holds the draft's point
and one of whose phrases (or raw query) `catalogdomain.HoldsAllWords` in
the title, description and specs; at most 200 rows, price and offers left
to the app. `HoldsAllWords` is pinned to the index by
`TestHoldsAllWordsAgreesWithTheIndex`.

- [ ] **Step 3: checklist.md**

Replace the unticked "Giá" line with:

```markdown
- [x] Bước "Giá" khi đăng tin: tin tương tự, người mua đang chờ, gợi ý "Bán nhanh" và "Giá thị trường" kèm số ngày bán: `POST /v1/price-guides` cho bất kỳ bản nháp nào, cùng dải giá với `/v1/listing-reads` (app chưa nối)
```

and add below it, unticked:

```markdown
- [ ] Yếu tố làm giá lệch khỏi giá giữa (pin, dung lượng, hộp…) ở sheet giá
- [ ] Ảnh người mua hay xem cho từng loại hàng ở bước Ảnh
- [ ] Người mua thường trả thấp hơn bao nhiêu phần trăm
```

Under the general rate limit line, add "tạo bảng giá (`/v1/price-guides`)"
to what it must cover.

- [ ] **Step 4: The spec's errors**

In the spec's API errors list, add `account_suspended` 403, as
`/v1/link-previews` does; it was decided while planning.

- [ ] **Step 5: Commit each repo**

```bash
cd ~/shopnexus/server && git add ARCHITECTURE.md && git commit -m "docs: the price guide and the reverse watch match in ARCHITECTURE.md"
cd ~/shopnexus/docs && git add superpowers/specs/2026-11-13-price-guide-design.md && git commit -m "spec: the price guide refuses a suspended account"
cd ~/shopnexus && git add checklist.md && git commit -m "checklist: the price guide"
```

Run the humanizing-writing checker on the ARCHITECTURE.md block and the
commit messages before committing (`~/.claude/CLAUDE.md`).
