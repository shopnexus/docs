# Billing part 1: payments and paid boosts. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A seller pays a one-off fee (fake provider for now) to put an active listing at the top of Gần bạn for 1 or 3 days; a payment that can no longer buy the boost is refunded.

**Architecture:** New module `billing` (domain, repository, service, handler) owns `payments`. A Restate service `BillingStart` opens a payment and schedules two delayed runs of a plain Restate service `BillingSettle`, which also runs on every IPN and on the app's check. `BillingSettle` asks the provider (`internal/provider/payment`), applies the boost through `catalogsvc.Boost`, or refunds; concurrent runs are safe through the payment's `write_id`. Catalog stores `listings.boosted_until` in its ParadeDB index, and discovery's nearby feed gives boosted listings within 15 km a score tier of 100.

**Tech Stack:** Go 1.27 (stdlib `uuid`), pgx v5, Postgres + ParadeDB, Restate Go SDK v1.1.0, kin-openapi, golangci-lint v2.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-05-billing-boosts-design.md`. Read it before Task 1. Read `~/shopnexus/server/ARCHITECTURE.md` (Durable flows, Events, Module layout, Search) and `~/shopnexus/server/CLAUDE.md` too.

## Global Constraints

- Work in `~/shopnexus/server` unless a task names another repo. Commit in the repo each file belongs to: `server`, `docs` (submodules) or the umbrella `~/shopnexus` (`infra/`, `docker-compose.yml`).
- No `Co-Authored-By` or any Claude attribution in commit messages.
- Configuration has no defaults: `PAYMENT_PROVIDER`, `PAYMENT_RETURN_URL`, `PUBLIC_API_URL` must be set everywhere; a missing one stops the process with its name.
- `PAYMENT_PROVIDER` is `fake`, `off` or `momo`; `momo` is refused until it exists; `APP_ENV=prod` refuses `fake`.
- Offers: `{days: 1, fee: 15000}`, `{days: 3, fee: 35000}`; `pay_with` is `"MoMo"` (empty with `off`).
- Pending for 15 minutes (`expires_at`), delayed settle runs at 15 minutes and 24 hours, at most 3 pending payments per account.
- Gần bạn paid tier: constant score 100 inside a 15 km box, only while `boosted_until > now`.
- Error codes, exactly: `listing_not_found` 404, `listing_not_boostable` 409, `too_many_pending` 409, `boosts_unavailable` 409, `invalid_boost` 422, `account_suspended` 403, `payment_not_found` 404, `invalid_signature` 400.
- `POST /v1/payments/{id}/check` sends with idempotency key `check:{id}:{unix seconds / 10}`.
- A use case or Restate handler reads top to bottom; no helpers called once (server `CLAUDE.md`).
- Scratch output goes to `server/tmp/`, never `/tmp`.
- `make test` (all tests, then `golangci-lint run`) is the gate for every task. After one `make test`, `go test ./internal/<pkg>/` runs one package against the running test stack.
- `exhaustruct` is on: every new struct field is set in every literal of that struct, or tagged `//exhaustruct:optional` when absent means something.
- Before writing prose in `ARCHITECTURE.md`, a README, or a commit message, use the `humanizing-writing` skill and run `python3 ~/.claude/skills/humanizing-writing/ai-tells.py --stats <file>` on the draft.

## Review Focus

1. A purchase while the reused pending payment's `BillingStart` has not stored `pay` yet: the API returns the payment without `pay`, never 500 (Task 7 repository test, Task 9 view test).
2. An IPN body that is empty, not JSON, or signed for an unknown payment: 400 `invalid_signature` for the first two, 204 for the third, never 500 (Task 6 fake test, Task 10 e2e).
3. `POST /payments/{id}/check` on an `expired`, `paid` or `refunded` payment: returns the payment and sends nothing (Task 9 service test).
4. `days` of 0, 2 or -1: 422 `invalid_boost` before Restate is called (Task 5 domain test, Task 10 e2e).
5. Another seller's listing, or another account's payment: 404 with the not-found code, so existence does not leak (Task 10 e2e).

---

### Task 1: Configuration

**Files:**
- Modify: `internal/platform/config/config.go`
- Modify: `internal/platform/config/config_test.go`
- Modify: `.env.example`
- Modify: `e2e/main_test.go:101-113` (the `cfg` literal)
- Modify: `internal/app/app_test.go`, `internal/app/routes_test.go` helpers if they build a `config.Config` (grep `config.Config{`)
- Modify (umbrella repo): `~/shopnexus/docker-compose.yml` (`x-server-env`), `~/shopnexus/infra/stack/templates/_server-env.tpl`, `~/shopnexus/infra/stack/values-dev.yaml`, `~/shopnexus/infra/stack/values-prod.yaml`, `~/shopnexus/infra/stack/values.yaml`, `~/shopnexus/infra/stack/tests/server_env_test.yaml`

**Interfaces:**
- Produces: `config.PaymentConfig{Provider PaymentProvider; ReturnURL string; PublicAPIURL string}`, `config.Config.Payment`, constants `config.PaymentFake`, `config.PaymentOff`, `config.PaymentMoMo` of type `config.PaymentProvider string`.

- [ ] **Step 1: Write the failing test**

In `config_test.go`, add the three variables to `required()`:

```go
		"PAYMENT_PROVIDER":   "off",
		"PAYMENT_RETURN_URL": "https://shopnexus.vn/pay/return",
		"PUBLIC_API_URL":     "https://api.shopnexus.vn",
```

and a test:

```go
func TestLoadPayment(t *testing.T) {
	t.Parallel()
	env := required()
	env["PAYMENT_PROVIDER"] = "fake"
	cfg, err := Load(lookup(env))
	if err != nil {
		t.Fatal(err)
	}
	want := PaymentConfig{Provider: PaymentFake, ReturnURL: "https://shopnexus.vn/pay/return", PublicAPIURL: "https://api.shopnexus.vn"}
	if cfg.Payment != want {
		t.Fatalf("payment: %+v", cfg.Payment)
	}
	for _, bad := range []string{"", "stripe"} {
		env["PAYMENT_PROVIDER"] = bad
		if _, err := Load(lookup(env)); err == nil || !strings.Contains(err.Error(), "PAYMENT_PROVIDER") {
			t.Errorf("PAYMENT_PROVIDER=%q: %v", bad, err)
		}
	}
	env["PAYMENT_PROVIDER"] = "off"
	env["PUBLIC_API_URL"] = ""
	if _, err := Load(lookup(env)); err == nil || !strings.Contains(err.Error(), "PUBLIC_API_URL is empty") {
		t.Errorf("empty PUBLIC_API_URL: %v", err)
	}
}
```

Also extend `TestLoadAllSet`'s expected `Config` with `Payment: PaymentConfig{Provider: PaymentOff, ReturnURL: "https://shopnexus.vn/pay/return", PublicAPIURL: "https://api.shopnexus.vn"}`.

- [ ] **Step 2: Run it and see it fail**

Run: `go test ./internal/platform/config/`
Expected: compile error, `undefined: PaymentConfig`.

- [ ] **Step 3: Implement**

In `config.go`, add to `Config` after `Firebase`:

```go
	Payment        PaymentConfig
```

and the types:

```go
// PaymentProvider is PAYMENT_PROVIDER: who takes the service fees.
type PaymentProvider string

const (
	// PaymentFake is a provider inside this process with a page to pay on;
	// APP_ENV=prod refuses it.
	PaymentFake PaymentProvider = "fake"
	// PaymentOff sells no boosts, for prod until a real provider is live.
	PaymentOff PaymentProvider = "off"
	// PaymentMoMo is MoMo; the server refuses it until it is built.
	PaymentMoMo PaymentProvider = "momo"
)

// PaymentConfig says who takes the service fees and where the payer comes
// back to.
type PaymentConfig struct {
	Provider PaymentProvider
	// ReturnURL (PAYMENT_RETURN_URL) is where a way to pay sends the payer
	// back: an app link.
	ReturnURL string
	// PublicAPIURL (PUBLIC_API_URL) is this server's public base URL, for
	// the fake's page and a provider's notifications.
	PublicAPIURL string
}
```

In `Load`, inside the `cfg := Config{...}` literal:

```go
		Payment: PaymentConfig{
			Provider:     PaymentProvider(oneOf("PAYMENT_PROVIDER", string(PaymentFake), string(PaymentOff), string(PaymentMoMo))),
			ReturnURL:    need("PAYMENT_RETURN_URL"),
			PublicAPIURL: strings.TrimRight(need("PUBLIC_API_URL"), "/"),
		},
```

In `.env.example`, before the closing comment block:

```
# Who takes the service fees: fake (a page on this server to pay on), off
# (no boosts are sold) or momo. APP_ENV=prod refuses fake.
PAYMENT_PROVIDER=fake
# Where a way to pay sends the payer back.
PAYMENT_RETURN_URL=shopnexus://payments
# This server's public base URL, for the fake's page.
PUBLIC_API_URL=http://127.0.0.1:8080
```

In `e2e/main_test.go`, inside `cfg := config.Config{...}` add the line below. The e2e server's URL exists only after `app.New`, so `PublicAPIURL` is a fixed host; only the text of `pay.url` uses it, and the e2e tests call `/dev/pay/...` by path.

```go
		Payment: config.PaymentConfig{Provider: config.PaymentFake, ReturnURL: "shopnexus://payments", PublicAPIURL: "http://api.e2e.test"},
```

Grep `config.Config{` in `internal/app` tests and add the same `Payment` field there.

Umbrella repo:
- `docker-compose.yml`, under `x-server-env: &server-env` after `FCM_CREDENTIALS: ""`:
  ```yaml
    PAYMENT_PROVIDER: fake
    PAYMENT_RETURN_URL: shopnexus://payments
    PUBLIC_API_URL: http://api.shopnexus.localhost
  ```
  (check the host the local stack serves the API on in this file and use it).
- `infra/stack/values.yaml`, under `server:`: `paymentProvider: ""  # fake | off | momo`. `values-dev.yaml` `server.paymentProvider: fake`; `values-prod.yaml` `server.paymentProvider: "off"`.
- `infra/stack/templates/_server-env.tpl`, after `PNV_TEST_NUMBERS`:
  ```
  PAYMENT_PROVIDER: {{ required "server.paymentProvider" .Values.server.paymentProvider | quote }}
  PAYMENT_RETURN_URL: https://{{ include "sn.host" (dict "root" . "sub" "") }}/pay/return
  PUBLIC_API_URL: https://{{ include "sn.host" (dict "root" . "sub" "api") }}
  ```
- `infra/stack/tests/server_env_test.yaml`: in the prod test assert `data.PAYMENT_PROVIDER` equals `"off"` and `data.PUBLIC_API_URL` equals `https://api.shopnexus.id.vn`; in the dev test assert `data.PAYMENT_PROVIDER` equals `fake`; in the `exists` list add the three keys.

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/platform/config/` → PASS.
Run (umbrella): `cd ~/shopnexus/infra && ./check.sh` (or `helm unittest stack` if `check.sh` does not run it) → PASS.

- [ ] **Step 5: Commit**

```bash
cd ~/shopnexus/server && git add internal/platform/config .env.example e2e/main_test.go internal/app && git commit -m "feat(config): PAYMENT_PROVIDER, PAYMENT_RETURN_URL and PUBLIC_API_URL"
cd ~/shopnexus && git add docker-compose.yml infra/stack && git commit -m "infra: payment settings; prod sells no boosts until MoMo"
```

---

### Task 2: Catalog stores boosts

**Files:**
- Create: `migrations/0024_listing_boosts.sql`
- Modify: `internal/catalog/domain/listing.go` (state, field, getter), `internal/catalog/domain/errors.go`
- Modify: `internal/catalog/repository/repository.go`, `internal/catalog/repository/listing_pg.go`
- Test: `internal/catalog/repository/listing_pg_test.go`

**Interfaces:**
- Produces: `domain.ErrNotBoostable` (409 `listing_not_boostable`); `(*domain.Listing).BoostedUntil() *time.Time`; `ListingState.BoostedUntil *time.Time`; `repository.Listings.Boost(ctx context.Context, payment, listing uuid.UUID, days int, now time.Time) (time.Time, error)`.

- [ ] **Step 1: Write the failing test**

Append to `listing_pg_test.go` (reuse the file's helpers that insert an active listing; read the top of the file for their names, e.g. the one `TestReservedRoundTrip` uses):

```go
func TestBoostStacksOncePerPayment(t *testing.T) {
	t.Parallel()
	s, l := activeListingForTest(t) // the store and an active listing, from this file's helpers
	ctx := context.Background()
	now := time.Now().UTC().Truncate(time.Microsecond)
	first, second := uuid.NewV7(), uuid.NewV7()

	until, err := s.Boost(ctx, first, l.ID(), 1, now)
	if err != nil || !until.Equal(now.Add(24*time.Hour)) {
		t.Fatalf("first: %v %v", until, err)
	}
	again, err := s.Boost(ctx, first, l.ID(), 1, now.Add(time.Hour))
	if err != nil || !again.Equal(until) {
		t.Fatalf("repeat adds days: %v %v", again, err)
	}
	stacked, err := s.Boost(ctx, second, l.ID(), 3, now.Add(time.Hour))
	if err != nil || !stacked.Equal(now.Add(4*24*time.Hour)) {
		t.Fatalf("stack: %v %v", stacked, err)
	}
	got, err := s.Get(ctx, l.ID())
	if err != nil || got.BoostedUntil() == nil || !got.BoostedUntil().Equal(stacked) {
		t.Fatalf("read back: %v %v", got.BoostedUntil(), err)
	}
}

func TestBoostConcurrentPurchasesBothCount(t *testing.T) {
	t.Parallel()
	s, l := activeListingForTest(t)
	now := time.Now().UTC().Truncate(time.Microsecond)
	var wg sync.WaitGroup
	for range 2 {
		wg.Go(func() {
			if _, err := s.Boost(context.Background(), uuid.NewV7(), l.ID(), 1, now); err != nil {
				t.Error(err)
			}
		})
	}
	wg.Wait()
	got, _ := s.Get(context.Background(), l.ID())
	if got.BoostedUntil() == nil || !got.BoostedUntil().Equal(now.Add(48*time.Hour)) {
		t.Fatalf("until %v", got.BoostedUntil())
	}
}

func TestBoostRefusesAListingNotActive(t *testing.T) {
	t.Parallel()
	s, l := activeListingForTest(t)
	ctx := context.Background()
	now := time.Now()
	if err := l.Hide(now); err != nil {
		t.Fatal(err)
	}
	if err := s.Save(ctx, &l, uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Boost(ctx, uuid.NewV7(), l.ID(), 1, now); !errors.Is(err, domain.ErrNotBoostable) {
		t.Fatalf("hidden: %v", err)
	}
	if _, err := s.Boost(ctx, uuid.NewV7(), uuid.NewV7(), 1, now); !errors.Is(err, domain.ErrNotBoostable) {
		t.Fatalf("unknown: %v", err)
	}
}
```

If the file has no helper returning `(Listings, domain.Listing)` for an active listing, add `activeListingForTest` at the bottom of the test file, built the way `TestReservedRoundTrip` builds its listing (`NewListing`, `Published`, `Insert`).

- [ ] **Step 2: Run and see it fail**

Run: `go test ./internal/catalog/repository/ -run Boost`
Expected: compile error, `s.Boost undefined`.

- [ ] **Step 3: Implement**

`migrations/0024_listing_boosts.sql`:

```sql
-- A paid boost puts an active listing at the top of the nearby feed until
-- boosted_until. listing_boosts records each payment's boost once, so a
-- repeated settle adds no days.
ALTER TABLE listings ADD COLUMN boosted_until timestamptz;

CREATE TABLE listing_boosts (
    payment_id uuid PRIMARY KEY,
    listing_id uuid NOT NULL REFERENCES listings (id),
    until      timestamptz NOT NULL
);

DROP INDEX listings_search;
CREATE INDEX listings_search ON listings USING paradedb (
    id, title, description, specs_text,
    (category_code::pdb.literal), (category_root::pdb.literal), price, (condition::pdb.literal),
    allow_offers, (status::pdb.literal), published_at, lat, lng, boosted_until
);
```

`domain/errors.go`, add:

```go
	ErrNotBoostable = apperr.New(apperr.KindConflict, "listing_not_boostable", "only an active listing can be boosted")
```

`domain/listing.go`:
- field `boostedUntil *time.Time` on `Listing`;
- `BoostedUntil *time.Time \`json:"boosted_until,omitempty"\`` on `ListingState`, tagged `//exhaustruct:optional`;
- `RestoreListing` sets `boostedUntil: st.BoostedUntil`; `State()` sets `BoostedUntil: l.boostedUntil`;
- getter next to `SoldAt`:
  ```go
  // BoostedUntil is when the listing's paid boost ends; nil when it was never
  // boosted. Only the catalog store writes it, through Boost.
  func (l *Listing) BoostedUntil() *time.Time { return l.boostedUntil }
  ```
- `NewListing` leaves it nil (check its literal satisfies exhaustruct; the tag above covers it).

`repository/repository.go`, in `Listings`:

```go
	// Boost stacks days on an active listing once per payment:
	// boosted_until becomes max(now, boosted_until) + days. A repeat with
	// the same payment returns the first one's end and adds nothing. A
	// listing that is unknown or not active is domain.ErrNotBoostable.
	// Saves leave boosted_until as it is.
	Boost(ctx context.Context, payment, listing uuid.UUID, days int, now time.Time) (time.Time, error)
```

`repository/listing_pg.go`:
- add after `listingColumns`:
  ```go
  // selectColumns are listingColumns and boosted_until, which only Boost
  // writes, so inserts and saves never carry it.
  const selectColumns = listingColumns + `, boosted_until`
  ```
- replace every `SELECT ` + `listingColumns` (Get, GetMany, ListBySeller; grep the file) with `selectColumns`;
- `scanListing` scans `&st.BoostedUntil` last;
- the method:

```go
func (s pgListings) Boost(ctx context.Context, payment, listing uuid.UUID, days int, now time.Time) (time.Time, error) {
	var until time.Time
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		// A concurrent settle of the same payment waits here, then finds
		// the committed row below.
		if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext(@payment::text))`,
			pgx.StrictNamedArgs{"payment": payment}); err != nil {
			return fmt.Errorf("lock payment: %w", err)
		}
		err := tx.QueryRow(ctx, `SELECT until FROM listing_boosts WHERE payment_id = @payment`,
			pgx.StrictNamedArgs{"payment": payment}).Scan(&until)
		if err == nil {
			return nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("read boost: %w", err)
		}
		err = tx.QueryRow(ctx, `UPDATE listings
SET boosted_until = greatest(@now, coalesce(boosted_until, @now)) + make_interval(days => @days)
WHERE id = @listing AND status = @active RETURNING boosted_until`,
			pgx.StrictNamedArgs{"now": now, "days": days, "listing": listing, "active": domain.StatusActive}).Scan(&until)
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotBoostable
		}
		if err != nil {
			return fmt.Errorf("boost listing: %w", err)
		}
		if _, err = tx.Exec(ctx, `INSERT INTO listing_boosts (payment_id, listing_id, until) VALUES (@payment, @listing, @until)`,
			pgx.StrictNamedArgs{"payment": payment, "listing": listing, "until": until}); err != nil {
			return fmt.Errorf("record boost: %w", err)
		}
		return nil
	})
	if err != nil {
		return time.Time{}, fmt.Errorf("boost: %w", err)
	}
	return until, nil
}
```

An unknown listing updates no row, so it is `ErrNotBoostable` before the insert, and the foreign key never fires. The `ErrNotBoostable` returned inside `BeginFunc` is wrapped by `fmt.Errorf("boost: %w")`, so `errors.Is` still finds it.

- [ ] **Step 4: Run the tests**

Run: `make test` once (it applies the migration to the test template), then `go test ./internal/catalog/...` → PASS, including the existing search index tests (the index was rebuilt).

- [ ] **Step 5: Commit**

```bash
git add migrations/0024_listing_boosts.sql internal/catalog && git commit -m "feat(catalog): a listing stores its paid boost's end, once per payment"
```

---

### Task 3: Catalog serves boosts: Boost, views and the paid search tier

**Files:**
- Modify: `internal/catalog/service/service.go` (interface), new `internal/catalog/service/listing_boost.go`
- Modify: `internal/catalog/service/views.go` (`ListingView`), `internal/catalog/service/listing_get.go` (`Get`, `ListMine`), `internal/catalog/service/search.go` (`SearchCard`)
- Modify: `internal/catalog/domain/search.go` (`BoostPaid`), `internal/catalog/repository/search_pg.go` (`should`)
- Modify: `api/schemas/catalog.yaml` (`Listing.boosted_until`), `api/schemas/discovery.yaml` (`SearchItem.boosted`)
- Test: `internal/catalog/service/listing_test.go` (or a new `listing_boost_test.go`), `internal/catalog/repository/search_pg_test.go`

**Interfaces:**
- Consumes: `repository.Listings.Boost` (Task 2).
- Produces: `catalogsvc.Service.Boost(ctx context.Context, payment, listing uuid.UUID, days int) (time.Time, error)`; `ListingView.BoostedUntil *time.Time` (seller's reads only); `SearchCard.Boosted bool` (`json:"boosted"`); `domain.BoostPaid` kind using `Near`, `RadiusKm`, `Since`.

- [ ] **Step 1: Write the failing tests**

`internal/catalog/service/listing_boost_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/platform/page"
	"github.com/shopnexus/server2/internal/catalog/service"
)

func TestBoostShowsToTheSellerOnly(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller := e.seller(t)
	v := e.settle(t, seller, e.post(t, seller).ID)
	until, err := e.catalog.Boost(ctx, uuid.NewV7(), v.ID, 1)
	if err != nil || time.Until(until) < 23*time.Hour {
		t.Fatalf("boost: %v %v", until, err)
	}
	mine, err := e.catalog.Get(ctx, &seller, v.ID)
	if err != nil || mine.BoostedUntil == nil || !mine.BoostedUntil.Equal(until) {
		t.Fatalf("seller: %+v %v", mine.BoostedUntil, err)
	}
	list, err := e.catalog.ListMine(ctx, seller, service.PaneOnSale, page.Request{})
	if err != nil || list.Items[0].BoostedUntil == nil {
		t.Fatalf("list mine: %+v %v", list, err)
	}
	other := e.account(t)
	theirs, err := e.catalog.Get(ctx, &other, v.ID)
	if err != nil || theirs.BoostedUntil != nil {
		t.Fatalf("other: %+v %v", theirs.BoostedUntil, err)
	}
	if _, err = e.catalog.Hide(ctx, seller, v.ID); err != nil {
		t.Fatal(err)
	}
	if _, err = e.catalog.Boost(ctx, uuid.NewV7(), v.ID, 1); !errors.Is(err, domain.ErrNotBoostable) {
		t.Fatalf("hidden: %v", err)
	}
}
```

(`page.Request{}` is the zero first page; check `internal/platform/page` for the exact zero value used elsewhere.)

In `internal/catalog/repository/search_pg_test.go`, add a test in the file's style (read its `put` helper and how it calls `Search`):

```go
func TestSearchPaidTier(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s, listings := repository.NewSearches(db), repository.NewListings(db)
	ctx := context.Background()
	now := time.Now()
	origin := domain.Point{Lat: 21.03, Lng: 105.82}
	near := put(t, db, item{title: "Ghế gỗ", cat: "furniture.table", price: 500_000, point: origin, status: domain.StatusActive})
	boosted := put(t, db, item{title: "Bàn gỗ", cat: "furniture.table", price: 500_000,
		point: domain.Point{Lat: 21.12, Lng: 105.82}, status: domain.StatusActive}) // about 10 km north
	far := put(t, db, item{title: "Tủ gỗ", cat: "furniture.table", price: 500_000,
		point: domain.Point{Lat: 21.21, Lng: 105.82}, status: domain.StatusActive}) // about 20 km north
	for _, id := range []uuid.UUID{boosted, far} {
		if _, err := listings.Boost(ctx, uuid.NewV7(), id, 1, now); err != nil {
			t.Fatal(err)
		}
	}
	hits, err := s.Search(ctx, domain.Search{
		Filters: domain.Filters{Origin: &origin, RadiusKm: 50},
		Boosts: []domain.Boost{
			{Kind: domain.BoostNear, Near: origin, RadiusKm: 2, Weight: 1.25},
			{Kind: domain.BoostPaid, Near: origin, RadiusKm: 15, Since: now, Weight: 100},
		},
		Sort: domain.SortRelevance, Limit: 10,
	})
	if err != nil || len(hits) != 3 || hits[0].ID != boosted || hits[1].ID != near || hits[2].ID != far {
		t.Fatalf("order: %+v %v", hits, err)
	}
}
```

Adapt `put`/`item` to the helper's real signature (it returns the listing ID). If `put` does not return the ID, read it back from the `listings` table by title.

- [ ] **Step 2: Run and see them fail**

Run: `go test ./internal/catalog/... -run 'Boost|PaidTier'`
Expected: compile errors (`e.catalog.Boost`, `BoostedUntil`, `domain.BoostPaid` undefined).

- [ ] **Step 3: Implement**

`domain/search.go`, add to the `BoostKind` constants:

```go
	// BoostPaid matches a listing whose paid boost runs past Since, inside
	// RadiusKm of Near.
	BoostPaid BoostKind = "paid"
```

`repository/search_pg.go`, in `should`'s switch:

```go
		case domain.BoostPaid:
			clause = `paradedb.boolean(must => ` + array([]string{
				`paradedb.range('boosted_until', tstzrange(` + q.arg(b.Since, "timestamptz") + `, NULL, '()'))`,
				q.box(b.Near, b.RadiusKm),
			}) + `)`
```

`service/service.go`, in `Service` after `SellTo`:

```go
	// Boost stacks days on an active listing for a payment; a repeat with the
	// same payment returns the first end and adds nothing. A listing that is
	// unknown or not active is domain.ErrNotBoostable.
	Boost(ctx context.Context, payment, listing uuid.UUID, days int) (time.Time, error)
```

`service/listing_boost.go`:

```go
package service

import (
	"context"
	"time"
	"uuid"
)

func (c *Catalog) Boost(ctx context.Context, payment, listing uuid.UUID, days int) (time.Time, error) {
	return c.listings.Boost(ctx, payment, listing, days, c.now())
}
```

`service/views.go`, on `ListingView` after `SoldAt`:

```go
	// BoostedUntil is when the listing's paid boost ends, for its seller
	// only, while it runs.
	BoostedUntil *time.Time `json:"boosted_until,omitempty"` //exhaustruct:optional
```

and a helper used by `Get`, `ListMine` and `Search` (three callers):

```go
// runningBoost is when l's boost ends, or nil when it is not boosted at now.
func runningBoost(l *domain.Listing, now time.Time) *time.Time {
	if u := l.BoostedUntil(); u != nil && u.After(now) {
		return u
	}
	return nil
}
```

`listing_get.go`: in `Get`, replace `return c.view(ctx, l)` with:

```go
	v, err := c.view(ctx, l)
	if err != nil || !owner {
		return v, err
	}
	v.BoostedUntil = runningBoost(&l, c.now())
	return v, nil
```

In `ListMine`, after `items, err := c.views(ctx, rows)` and its error check:

```go
	now := c.now()
	for i := range items {
		items[i].BoostedUntil = runningBoost(&rows[i], now)
	}
```

(`views` keeps the input order; confirm by reading it.)

`service/search.go`: add to `SearchCard` after `DistanceKm`:

```go
	// Boosted is true while the listing's paid boost runs.
	Boosted bool `json:"boosted"`
```

In `Search`, the loop needs the domain listing: build `byListing := map[uuid.UUID]*domain.Listing` from `ls` next to `byID`, and set `Boosted: runningBoost(byListing[h.ID], now) != nil` in the card literal, with `now := c.now()` before the loop. Grep for other `SearchCard{` literals (`grep -rn "SearchCard{" internal`) and set `Boosted` there too.

OpenAPI:
- `api/schemas/catalog.yaml`, `Listing.properties`:
  ```yaml
      boosted_until:
        type: string
        format: date-time
        description: When the listing's paid boost ends, for its seller only, while it runs.
  ```
- `api/schemas/discovery.yaml`, `SearchItem`: add `boosted` to `required` and
  ```yaml
      boosted:
        type: boolean
        description: True while the listing's paid boost runs; the app labels it "Được đẩy".
  ```

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/catalog/... ./internal/discovery/... ./internal/screen/... ./api/...` → PASS. Run `make test` before committing; the e2e suite validates `boosted` on every search response.

- [ ] **Step 5: Commit**

```bash
git add internal/catalog api && git commit -m "feat(catalog): Boost, a seller's boosted_until, and boosted on search cards"
```

---

### Task 4: Discovery puts boosted listings on top of Gần bạn

**Files:**
- Modify: `internal/discovery/domain/understanding.go` (`NearbyBoosts`)
- Test: `internal/discovery/service/search_test.go`, `internal/discovery/domain/understanding_test.go`

**Interfaces:**
- Consumes: `catalogdomain.BoostPaid`, `catalogsvc.Service.Boost`.
- Produces: `domain.PaidTierWeight = 100.0`, `domain.PaidRadiusKm = 15.0`.

- [ ] **Step 1: Write the failing test**

In `search_test.go`, after `TestNearby`:

```go
func TestNearbyBoostedFirst(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	closeBy := e.put(t, "Ghế gỗ", "furniture.table", baDinh)
	boosted := e.put(t, "Bàn gỗ", "furniture.table", catalogdomain.Point{Lat: 21.12, Lng: 105.82}) // ~10 km
	tooFar := e.put(t, "Tủ gỗ", "furniture.table", catalogdomain.Point{Lat: 21.21, Lng: 105.82}) // ~20 km
	for _, id := range []uuid.UUID{boosted, tooFar} {
		if _, err := e.catalog.Boost(ctx, uuid.NewV7(), id, 1); err != nil {
			t.Fatal(err)
		}
	}
	v, err := e.discovery.Nearby(ctx, nil, service.Near{Lat: baDinh.Lat, Lng: baDinh.Lng}, "", 0)
	if err != nil || len(v.Items) != 3 {
		t.Fatalf("%+v %v", v, err)
	}
	if v.Items[0].ID != boosted || !v.Items[0].Boosted || v.Items[1].ID != closeBy || v.Items[2].ID != tooFar || !v.Items[2].Boosted {
		t.Fatalf("order: %v %v %v", v.Items[0].ID, v.Items[1].ID, v.Items[2].ID)
	}
}
```

(`SearchItem` embeds `SearchCard`, so `Boosted` is promoted.)

In `understanding_test.go`:

```go
func TestNearbyBoostsHaveThePaidTier(t *testing.T) {
	t.Parallel()
	now := time.Now()
	var paid []catalogdomain.Boost
	for _, b := range domain.NearbyBoosts(catalogdomain.Point{Lat: 21, Lng: 105}, now) {
		if b.Kind == catalogdomain.BoostPaid {
			paid = append(paid, b)
		}
	}
	if len(paid) != 1 || paid[0].Weight != 100 || paid[0].RadiusKm != 15 || !paid[0].Since.Equal(now) {
		t.Fatalf("%+v", paid)
	}
}
```

- [ ] **Step 2: Run and see it fail**

Run: `go test ./internal/discovery/... -run 'Boosted|PaidTier'`
Expected: FAIL (`len(paid) == 0`, and the order test puts `closeBy` first).

- [ ] **Step 3: Implement**

In `understanding.go`:

```go
const (
	// PaidTierWeight is a paid boost's score in the nearby feed. A normal
	// listing scores about 1 to 7, so boosted listings form a tier above all.
	PaidTierWeight = 100.0
	// PaidRadiusKm is how near a searcher must be to see a boost on top.
	PaidRadiusKm = 15.0
)

// NearbyBoosts are the nearby feed's whole score: the paid tier, then the
// distance rings around origin and the freshness boosts.
func NearbyBoosts(origin catalogdomain.Point, now time.Time) []catalogdomain.Boost {
	paid := catalogdomain.Boost{
		Kind: catalogdomain.BoostPaid, Near: origin, RadiusKm: PaidRadiusKm, Since: now, Weight: PaidTierWeight,
	}
	return append(append([]catalogdomain.Boost{paid}, ringsAround(origin, 1)...), freshBoosts(now, 1)...)
}
```

Fill every other `catalogdomain.Boost` field exhaustruct asks for with its zero value, as `ringsAround` does.

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/discovery/... ./internal/screen/...` → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/discovery && git commit -m "feat(discovery): boosted listings within 15 km lead Gần bạn"
```

---

### Task 5: Billing domain

**Files:**
- Create: `internal/billing/domain/payment.go`, `internal/billing/domain/errors.go`
- Test: `internal/billing/domain/payment_test.go`

**Interfaces:**
- Produces:
  - `domain.Offer{Days int; Fee int64}`, `domain.Offers []Offer`, `domain.FeeFor(days int) (int64, error)`.
  - `domain.Status` (`StatusPending`, `StatusPaid`, `StatusExpired`, `StatusRefunded`), `domain.RefundReason` (`RefundNotBoostable = "listing_not_boostable"`).
  - Constants `PendingFor = 15 * time.Minute`, `RecheckAfter = 24 * time.Hour`, `MaxPending = 3`.
  - `domain.Pay{URL, Deeplink, QR string}`.
  - `domain.Payment` with `NewPayment(id, account uuid.UUID, provider string, listing uuid.UUID, days int, now time.Time) (Payment, error)`, getters `ID() AccountID() Provider() ProviderRef() Amount() ListingID() Days() Status() Pay() ExpiresAt() PaidAt() BoostedUntil() RefundedAt() RefundReason() CreatedAt() WriteID()`, and `Created(ref string, pay Pay)`, `Settled() bool`, `Confirms(orderID uuid.UUID, amount int64) bool`, `Expire(now time.Time) bool`, `Paid(until, now time.Time) error`, `Refunded(reason RefundReason, now time.Time) error`, `Saved(writeID uuid.UUID)`, `State() PaymentState`, `RestorePayment(PaymentState) Payment`, `MarshalJSON`/`UnmarshalJSON`.
  - Errors: `ErrInvalidBoost`, `ErrPaymentNotFound`, `ErrTooManyPending`, `ErrBoostsUnavailable`, `ErrInvalidSignature`, `ErrSettled` (internal: a transition from a settled payment).

- [ ] **Step 1: Write the failing test**

```go
package domain_test

import (
	"errors"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/billing/domain"
)

func TestFeeFor(t *testing.T) {
	t.Parallel()
	for days, fee := range map[int]int64{1: 15_000, 3: 35_000} {
		if got, err := domain.FeeFor(days); err != nil || got != fee {
			t.Errorf("%d days: %d %v", days, got, err)
		}
	}
	for _, days := range []int{0, 2, -1, 7} {
		if _, err := domain.FeeFor(days); !errors.Is(err, domain.ErrInvalidBoost) {
			t.Errorf("%d days: %v", days, err)
		}
	}
}

func TestPaymentLifecycle(t *testing.T) {
	t.Parallel()
	now := time.Now()
	id := uuid.NewV7()
	p, err := domain.NewPayment(id, uuid.NewV7(), "fake", uuid.NewV7(), 3, now)
	if err != nil || p.Status() != domain.StatusPending || p.Amount() != 35_000 || !p.ExpiresAt().Equal(now.Add(15*time.Minute)) {
		t.Fatalf("new: %+v %v", p.State(), err)
	}
	if _, err = domain.NewPayment(id, uuid.NewV7(), "fake", uuid.NewV7(), 2, now); !errors.Is(err, domain.ErrInvalidBoost) {
		t.Fatalf("2 days: %v", err)
	}
	p.Created("ref-1", domain.Pay{URL: "https://pay"})
	if p.ProviderRef() != "ref-1" || p.Pay().URL != "https://pay" {
		t.Fatalf("created: %+v", p.State())
	}
	if !p.Confirms(id, 35_000) || p.Confirms(id, 1) || p.Confirms(uuid.NewV7(), 35_000) {
		t.Fatal("confirms")
	}
	if p.Expire(now.Add(14 * time.Minute)) {
		t.Fatal("expired early")
	}
	if !p.Expire(now.Add(15*time.Minute)) || p.Status() != domain.StatusExpired || p.Pay() != (domain.Pay{}) {
		t.Fatalf("expire: %+v", p.State())
	}
	until := now.Add(72 * time.Hour)
	if err = p.Paid(until, now.Add(time.Hour)); err != nil || p.Status() != domain.StatusPaid || !p.Settled() {
		t.Fatalf("late pay: %+v %v", p.State(), err)
	}
	if p.Expire(now.Add(48 * time.Hour)) {
		t.Fatal("a paid payment expired")
	}
	if err = p.Refunded(domain.RefundNotBoostable, now); !errors.Is(err, domain.ErrSettled) {
		t.Fatalf("refund after paid: %v", err)
	}
}

func TestPaymentRefund(t *testing.T) {
	t.Parallel()
	now := time.Now()
	p, _ := domain.NewPayment(uuid.NewV7(), uuid.NewV7(), "fake", uuid.NewV7(), 1, now)
	if err := p.Refunded(domain.RefundNotBoostable, now); err != nil || p.Status() != domain.StatusRefunded ||
		p.RefundReason() != domain.RefundNotBoostable || p.RefundedAt() == nil {
		t.Fatalf("%+v %v", p.State(), err)
	}
	if err := p.Paid(now, now); !errors.Is(err, domain.ErrSettled) {
		t.Fatalf("pay after refund: %v", err)
	}
}

func TestPaymentJSONRoundTrip(t *testing.T) {
	t.Parallel()
	p, _ := domain.NewPayment(uuid.NewV7(), uuid.NewV7(), "fake", uuid.NewV7(), 1, time.Now())
	b, err := p.MarshalJSON()
	if err != nil {
		t.Fatal(err)
	}
	var back domain.Payment
	if err = back.UnmarshalJSON(b); err != nil || back.ID() != p.ID() || back.Amount() != p.Amount() {
		t.Fatalf("%+v %v", back.State(), err)
	}
}
```

- [ ] **Step 2: Run and see it fail**

Run: `go test ./internal/billing/domain/`
Expected: compile error, package does not exist.

- [ ] **Step 3: Implement**

`errors.go`:

```go
package domain

import "github.com/shopnexus/server2/internal/platform/apperr"

var (
	ErrInvalidBoost      = apperr.New(apperr.KindInvalid, "invalid_boost", "days must be one of the offers")
	ErrPaymentNotFound   = apperr.New(apperr.KindNotFound, "payment_not_found", "no such payment")
	ErrTooManyPending    = apperr.New(apperr.KindConflict, "too_many_pending", "at most 3 payments may wait at once")
	ErrBoostsUnavailable = apperr.New(apperr.KindConflict, "boosts_unavailable", "boosts are not on sale")
	ErrInvalidSignature  = apperr.New(apperr.KindBadRequest, "invalid_signature", "the notification's signature does not check")
	// ErrSettled refuses a change to a paid or refunded payment; settle
	// stops before it, so it means a bug.
	ErrSettled = apperr.New(apperr.KindConflict, "payment_settled", "the payment is settled")
)
```

`payment.go`:

```go
// Package domain holds module billing's rules: what a boost costs and how a
// payment moves from pending to paid, expired or refunded.
package domain

import (
	"encoding/json"
	"time"
	"uuid"
)

const (
	// PendingFor is how long a way to pay stays open.
	PendingFor = 15 * time.Minute
	// RecheckAfter is when settle asks the provider a last time.
	RecheckAfter = 24 * time.Hour
	// MaxPending caps an account's pending payments.
	MaxPending = 3
)

// Offer is a boost on sale: days at the top of Gần bạn for a fee in đồng.
type Offer struct {
	Days int   `json:"days"`
	Fee  int64 `json:"fee"`
}

// Offers are the boosts on sale.
var Offers = []Offer{{Days: 1, Fee: 15_000}, {Days: 3, Fee: 35_000}}

// FeeFor is the fee of a boost of days; another number is ErrInvalidBoost.
func FeeFor(days int) (int64, error) {
	for _, o := range Offers {
		if o.Days == days {
			return o.Fee, nil
		}
	}
	return 0, ErrInvalidBoost
}

// Status is where a payment is.
type Status string

const (
	StatusPending  Status = "pending"
	StatusPaid     Status = "paid" // money received and the boost applied
	StatusExpired  Status = "expired"
	StatusRefunded Status = "refunded"
)

// RefundReason is why a payment was refunded.
type RefundReason string

// RefundNotBoostable: the listing was no longer active when the money came.
const RefundNotBoostable RefundReason = "listing_not_boostable"

// Pay is how a payer reaches the provider: a page, an app, or a QR code.
type Pay struct {
	URL      string `json:"url"`
	Deeplink string `json:"deeplink,omitempty"`
	QR       string `json:"qr,omitempty"`
}

// Payment is one purchase of one boost.
type Payment struct {
	id, accountID, listingID uuid.UUID
	provider, providerRef    string
	amount                   int64
	days                     int
	status                   Status
	pay                      Pay
	expiresAt, createdAt     time.Time
	paidAt, boostedUntil     *time.Time
	refundedAt               *time.Time
	refundReason             RefundReason
	writeID                  uuid.UUID
}

// NewPayment starts a pending payment for a boost of days.
func NewPayment(id, account uuid.UUID, provider string, listing uuid.UUID, days int, now time.Time) (Payment, error) {
	fee, err := FeeFor(days)
	if err != nil {
		return Payment{}, err
	}
	return Payment{
		id: id, accountID: account, listingID: listing, provider: provider, amount: fee, days: days,
		status: StatusPending, expiresAt: now.Add(PendingFor), createdAt: now, writeID: id,
	}, nil
}

func (p *Payment) ID() uuid.UUID              { return p.id }
func (p *Payment) AccountID() uuid.UUID       { return p.accountID }
func (p *Payment) ListingID() uuid.UUID       { return p.listingID }
func (p *Payment) Provider() string           { return p.provider }
func (p *Payment) ProviderRef() string        { return p.providerRef }
func (p *Payment) Amount() int64              { return p.amount }
func (p *Payment) Days() int                  { return p.days }
func (p *Payment) Status() Status             { return p.status }
func (p *Payment) Pay() Pay                   { return p.pay }
func (p *Payment) ExpiresAt() time.Time       { return p.expiresAt }
func (p *Payment) CreatedAt() time.Time       { return p.createdAt }
func (p *Payment) PaidAt() *time.Time         { return p.paidAt }
func (p *Payment) BoostedUntil() *time.Time   { return p.boostedUntil }
func (p *Payment) RefundedAt() *time.Time     { return p.refundedAt }
func (p *Payment) RefundReason() RefundReason { return p.refundReason }
func (p *Payment) WriteID() uuid.UUID         { return p.writeID }

// Created records the provider's order and the way to pay it.
func (p *Payment) Created(ref string, pay Pay) { p.providerRef, p.pay = ref, pay }

// Settled reports a payment nothing changes any more.
func (p *Payment) Settled() bool { return p.status == StatusPaid || p.status == StatusRefunded }

// Confirms reports whether a provider's paid order is this payment, in full.
func (p *Payment) Confirms(orderID uuid.UUID, amount int64) bool {
	return orderID == p.id && amount == p.amount
}

// Expire closes a pending payment at or past its expiry; false when it
// changes nothing.
func (p *Payment) Expire(now time.Time) bool {
	if p.status != StatusPending || now.Before(p.expiresAt) {
		return false
	}
	p.status, p.pay = StatusExpired, Pay{}
	return true
}

// Paid records the money and the boost it bought, also for a payment that
// expired before the money came.
func (p *Payment) Paid(until, now time.Time) error {
	if p.Settled() {
		return ErrSettled
	}
	p.status, p.pay, p.paidAt, p.boostedUntil = StatusPaid, Pay{}, &now, &until
	return nil
}

// Refunded records money given back.
func (p *Payment) Refunded(reason RefundReason, now time.Time) error {
	if p.Settled() {
		return ErrSettled
	}
	p.status, p.pay, p.refundedAt, p.refundReason = StatusRefunded, Pay{}, &now, reason
	return nil
}

// Saved sets the write ID a save stored. Stores only.
func (p *Payment) Saved(writeID uuid.UUID) { p.writeID = writeID }
```

Then `PaymentState` (every field exported with snake_case JSON tags, optional ones tagged `//exhaustruct:optional`), `RestorePayment`, `State`, `MarshalJSON` and `UnmarshalJSON`, written exactly like `catalog/domain/listing.go:367-425` does for `ListingState`.

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/billing/domain/` → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/billing/domain && git commit -m "feat(billing): boost offers and the payment's states"
```

---

### Task 6: Payment provider interface, the fake and off

**Files:**
- Create: `internal/provider/payment/payment.go`, `internal/provider/payment/fake.go`, `internal/provider/payment/off.go`
- Create: `migrations/0025_payments.sql` (both `payments` and `fake_payments`; Task 7 tests `payments`)
- Test: `internal/provider/payment/fake_test.go`

**Interfaces:**
- Produces:
  ```go
  type Order struct { ID uuid.UUID; Amount int64; Description string; ExpiresAt time.Time }
  type Created struct { Ref string; Pay domain.Pay }      // billing/domain.Pay
  type Answer struct { Paid bool; OrderID uuid.UUID; Amount int64 }
  type Provider interface {
      Name() string                 // "fake", "off", later "momo"
      Label() string                // what the app shows: "MoMo"; "" for off
      Create(ctx context.Context, o Order) (Created, error)
      Query(ctx context.Context, order uuid.UUID) (Answer, error)
      // Refund gives an order's money back; a repeat refunds nothing more.
      Refund(ctx context.Context, order uuid.UUID, amount int64) error
      // Verify checks a notification and returns its order; a bad one is ErrBadSignature.
      Verify(body []byte, header http.Header) (uuid.UUID, error)
  }
  var ErrBadSignature = errors.New("payment: bad signature")
  var ErrOff = errors.New("payment: provider off")
  func NewFake(db *pgxpool.Pool, publicAPIURL string, now func() time.Time) *Fake
  func (f *Fake) Pay(ctx context.Context, order uuid.UUID) error
  func (f *Fake) Notification(order uuid.UUID) []byte
  type Off struct{}
  ```
- `internal/provider/payment` may import `billing/domain` for `Pay` (a provider package importing a domain package is allowed by depguard: check `.golangci.yml` for `provider` rules; if it is refused, define `Pay` here and have `billing/domain` keep its own copy converted in the service).

- [ ] **Step 1: Write the failing test**

```go
package payment_test

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server2/internal/provider/payment"
)

func TestFake(t *testing.T) {
	t.Parallel()
	f := payment.NewFake(pgtest.New(t), "https://api.test", time.Now)
	ctx := context.Background()
	id := uuid.NewV7()
	c, err := f.Create(ctx, payment.Order{ID: id, Amount: 15_000, Description: "Đẩy tin", ExpiresAt: time.Now().Add(time.Minute)})
	if err != nil || c.Pay.URL != "https://api.test/dev/pay/"+id.String() || c.Pay.QR != c.Pay.URL || c.Ref == "" {
		t.Fatalf("create: %+v %v", c, err)
	}
	if again, err := f.Create(ctx, payment.Order{ID: id, Amount: 15_000}); err != nil || again.Ref != c.Ref {
		t.Fatalf("create again: %+v %v", again, err)
	}
	if a, err := f.Query(ctx, id); err != nil || a.Paid {
		t.Fatalf("unpaid: %+v %v", a, err)
	}
	if err = f.Pay(ctx, id); err != nil {
		t.Fatal(err)
	}
	if a, err := f.Query(ctx, id); err != nil || !a.Paid || a.OrderID != id || a.Amount != 15_000 {
		t.Fatalf("paid: %+v %v", a, err)
	}
	for range 2 {
		if err = f.Refund(ctx, id, 15_000); err != nil {
			t.Fatal(err)
		}
	}
	if a, _ := f.Query(ctx, uuid.NewV7()); a.Paid {
		t.Fatal("unknown order paid")
	}
}

func TestFakeVerify(t *testing.T) {
	t.Parallel()
	f := payment.NewFake(pgtest.New(t), "https://api.test", time.Now)
	id := uuid.NewV7()
	if got, err := f.Verify(f.Notification(id), nil); err != nil || got != id {
		t.Fatalf("good: %v %v", got, err)
	}
	tampered := strings.Replace(string(f.Notification(id)), id.String(), uuid.NewV7().String(), 1)
	for name, body := range map[string][]byte{"empty": nil, "not json": []byte("x"), "tampered": []byte(tampered)} {
		if _, err := f.Verify(body, nil); !errors.Is(err, payment.ErrBadSignature) {
			t.Errorf("%s: %v", name, err)
		}
	}
}

func TestOff(t *testing.T) {
	t.Parallel()
	var p payment.Provider = payment.Off{}
	if p.Label() != "" {
		t.Fatal("label")
	}
	if _, err := p.Create(context.Background(), payment.Order{}); !errors.Is(err, payment.ErrOff) {
		t.Fatalf("create: %v", err)
	}
	if _, err := p.Verify([]byte(`{}`), nil); !errors.Is(err, payment.ErrBadSignature) {
		t.Fatalf("verify: %v", err)
	}
}
```

- [ ] **Step 2: Run and see it fail**

Run: `go test ./internal/provider/payment/`
Expected: compile error, package does not exist.

- [ ] **Step 3: Implement**

`migrations/0025_payments.sql`:

```sql
-- A payment is one purchase of one boost: pending until the provider says
-- it is paid, then paid, expired or refunded.
CREATE TABLE payments (
    id            uuid PRIMARY KEY,
    account_id    uuid NOT NULL REFERENCES accounts (id),
    provider      text NOT NULL,
    provider_ref  text,
    amount        bigint NOT NULL,
    listing_id    uuid NOT NULL REFERENCES listings (id),
    days          integer NOT NULL,
    status        text NOT NULL,
    pay_url       text,
    pay_deeplink  text,
    pay_qr        text,
    expires_at    timestamptz NOT NULL,
    paid_at       timestamptz,
    boosted_until timestamptz,
    refunded_at   timestamptz,
    refund_reason text,
    created_at    timestamptz NOT NULL,
    write_id      uuid NOT NULL,
    UNIQUE (provider, provider_ref)
);
CREATE INDEX payments_pending ON payments (account_id, listing_id) WHERE status = 'pending';

-- The fake provider's own record of its orders, so it answers queries and
-- refunds as a provider would. Only PAYMENT_PROVIDER=fake writes it.
CREATE TABLE fake_payments (
    payment_id  uuid PRIMARY KEY,
    amount      bigint NOT NULL,
    paid_at     timestamptz,
    refunded_at timestamptz
);
```

`payment.go`: the package doc, `Order`, `Created`, `Answer`, `Provider`, `ErrBadSignature`, `ErrOff` exactly as in Interfaces, with a doc comment on each.

`fake.go`:

```go
package payment

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/shopnexus/server2/internal/billing/domain"
)

// fakeKey signs the fake's notifications. It is public on purpose: the fake
// never runs with APP_ENV=prod.
var fakeKey = []byte("shopnexus-fake-payments")

// Fake is a provider inside this process. Its page, /dev/pay/{id}, stands
// in for MoMo's: it marks an order paid and sends the notification.
type Fake struct {
	db   *pgxpool.Pool
	base string
	now  func() time.Time
}

func NewFake(db *pgxpool.Pool, publicAPIURL string, now func() time.Time) *Fake {
	return &Fake{db: db, base: publicAPIURL, now: now}
}

func (f *Fake) Name() string  { return "fake" }
func (f *Fake) Label() string { return "MoMo" } // the app shows the provider the fake stands in for

func (f *Fake) Create(ctx context.Context, o Order) (Created, error) {
	if _, err := f.db.Exec(ctx, `INSERT INTO fake_payments (payment_id, amount) VALUES (@id, @amount)
ON CONFLICT (payment_id) DO NOTHING`, pgx.StrictNamedArgs{"id": o.ID, "amount": o.Amount}); err != nil {
		return Created{}, fmt.Errorf("fake: create: %w", err)
	}
	url := f.base + "/dev/pay/" + o.ID.String()
	return Created{Ref: "fake-" + o.ID.String(), Pay: domain.Pay{URL: url, QR: url}}, nil
}

func (f *Fake) Query(ctx context.Context, order uuid.UUID) (Answer, error) {
	var (
		amount int64
		paidAt *time.Time
	)
	err := f.db.QueryRow(ctx, `SELECT amount, paid_at FROM fake_payments WHERE payment_id = @id`,
		pgx.StrictNamedArgs{"id": order}).Scan(&amount, &paidAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Answer{}, nil
	}
	if err != nil {
		return Answer{}, fmt.Errorf("fake: query: %w", err)
	}
	return Answer{Paid: paidAt != nil, OrderID: order, Amount: amount}, nil
}

func (f *Fake) Refund(ctx context.Context, order uuid.UUID, _ int64) error {
	if _, err := f.db.Exec(ctx, `UPDATE fake_payments SET refunded_at = coalesce(refunded_at, @now) WHERE payment_id = @id`,
		pgx.StrictNamedArgs{"id": order, "now": f.now()}); err != nil {
		return fmt.Errorf("fake: refund: %w", err)
	}
	return nil
}

// Pay marks an order paid, as a payer finishing on the provider's page.
func (f *Fake) Pay(ctx context.Context, order uuid.UUID) error {
	if _, err := f.db.Exec(ctx, `UPDATE fake_payments SET paid_at = coalesce(paid_at, @now) WHERE payment_id = @id`,
		pgx.StrictNamedArgs{"id": order, "now": f.now()}); err != nil {
		return fmt.Errorf("fake: pay: %w", err)
	}
	return nil
}

type notification struct {
	OrderID   string `json:"order_id"`
	Signature string `json:"signature"`
}

func sign(order string) string {
	m := hmac.New(sha256.New, fakeKey)
	m.Write([]byte(order))
	return hex.EncodeToString(m.Sum(nil))
}

// Notification is the body of the fake's notification for an order.
func (f *Fake) Notification(order uuid.UUID) []byte {
	b, _ := json.Marshal(notification{OrderID: order.String(), Signature: sign(order.String())})
	return b
}

func (f *Fake) Verify(body []byte, _ http.Header) (uuid.UUID, error) {
	var n notification
	if err := json.Unmarshal(body, &n); err != nil {
		return uuid.UUID{}, ErrBadSignature
	}
	if !hmac.Equal([]byte(n.Signature), []byte(sign(n.OrderID))) {
		return uuid.UUID{}, ErrBadSignature
	}
	id, err := uuid.Parse(n.OrderID)
	if err != nil {
		return uuid.UUID{}, ErrBadSignature
	}
	return id, nil
}
```

(Check the stdlib `uuid` package's parse function name with `go doc uuid` and adjust `uuid.Parse`.)

`off.go`:

```go
package payment

import (
	"context"
	"net/http"
	"uuid"
)

// Off sells nothing: PAYMENT_PROVIDER=off, for prod until a provider is live.
type Off struct{}

func (Off) Name() string  { return "off" }
func (Off) Label() string { return "" }
func (Off) Create(context.Context, Order) (Created, error)      { return Created{}, ErrOff }
func (Off) Query(context.Context, uuid.UUID) (Answer, error)    { return Answer{}, ErrOff }
func (Off) Refund(context.Context, uuid.UUID, int64) error      { return ErrOff }
func (Off) Verify([]byte, http.Header) (uuid.UUID, error)       { return uuid.UUID{}, ErrBadSignature }
```

- [ ] **Step 4: Run the tests**

Run: `make test` once for the migration, then `go test ./internal/provider/payment/` → PASS.

- [ ] **Step 5: Commit**

```bash
git add migrations/0025_payments.sql internal/provider/payment && git commit -m "feat(payment): the provider interface, a fake with its own records, and off"
```

---

### Task 7: Billing repository

**Files:**
- Create: `internal/billing/repository/repository.go`, `internal/billing/repository/payment_pg.go`
- Test: `internal/billing/repository/payment_pg_test.go`

**Interfaces:**
- Consumes: `domain.Payment`, `domain.PaymentState`, `RestorePayment`, `MaxPending`.
- Produces:
  ```go
  var ErrNotFound, ErrConflict error
  type Payments interface {
      // Open inserts p, or returns the account's pending payment for the
      // same listing and days that has not expired at now (created false).
      // An account with MaxPending pending payments is domain.ErrTooManyPending.
      // A pg_advisory_xact_lock on the account makes Opens wait for each other.
      // Opening the same ID again returns the stored row, created false.
      Open(ctx context.Context, p domain.Payment, now time.Time) (domain.Payment, bool, error)
      Get(ctx context.Context, id uuid.UUID) (domain.Payment, error)
      // Save writes p and evs when its row still has p.WriteID() or already
      // has writeID, then sets the write ID; otherwise ErrConflict.
      Save(ctx context.Context, p *domain.Payment, writeID uuid.UUID, evs ...events.Event) error
  }
  func NewPayments(db *pgxpool.Pool) Payments
  ```

- [ ] **Step 1: Write the failing test**

```go
package repository_test

import (
	"context"
	"errors"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/shopnexus/server2/internal/billing/domain"
	"github.com/shopnexus/server2/internal/billing/repository"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
)

// seed inserts an account and a listing row the foreign keys need, and
// returns their IDs. Write the listing insert with the columns
// migrations/0007_catalog.sql requires; status active.
func seed(t *testing.T, db *pgxpool.Pool) (account, listing uuid.UUID) { /* … */ }

func TestOpenReusesAndCaps(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewPayments(db)
	ctx := context.Background()
	now := time.Now()
	account, listing := seed(t, db)
	newP := func(days int) domain.Payment {
		p, err := domain.NewPayment(uuid.NewV7(), account, "fake", listing, days, now)
		if err != nil {
			t.Fatal(err)
		}
		return p
	}
	first := newP(1)
	got, created, err := s.Open(ctx, first, now)
	if err != nil || !created || got.ID() != first.ID() {
		t.Fatalf("open: %v %v", created, err)
	}
	if got, created, err = s.Open(ctx, newP(1), now.Add(time.Minute)); err != nil || created || got.ID() != first.ID() {
		t.Fatalf("reuse: %v %v %v", got.ID(), created, err)
	}
	if got.Pay() != (domain.Pay{}) {
		t.Fatal("a reused payment before Create has no way to pay yet")
	}
	if _, created, err = s.Open(ctx, newP(3), now); err != nil || !created {
		t.Fatalf("3 days: %v %v", created, err)
	}
	_, other := seed(t, db) // another listing of another seller is fine for the cap
	p3, _ := domain.NewPayment(uuid.NewV7(), account, "fake", other, 1, now)
	if _, _, err = s.Open(ctx, p3, now); err != nil {
		t.Fatal(err)
	}
	p4, _ := domain.NewPayment(uuid.NewV7(), account, "fake", other, 3, now)
	if _, _, err = s.Open(ctx, p4, now); !errors.Is(err, domain.ErrTooManyPending) {
		t.Fatalf("fourth: %v", err)
	}
	if _, created, err = s.Open(ctx, newP(1), now.Add(16*time.Minute)); err != nil && !errors.Is(err, domain.ErrTooManyPending) {
		t.Fatalf("after expiry: %v", err) // an expired pending row is not reused
	} else if created {
		t.Fatal("created past the cap")
	}
}

func TestSaveWriteID(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewPayments(db)
	ctx := context.Background()
	now := time.Now()
	account, listing := seed(t, db)
	p, _ := domain.NewPayment(uuid.NewV7(), account, "fake", listing, 1, now)
	if _, _, err := s.Open(ctx, p, now); err != nil {
		t.Fatal(err)
	}
	stale := p
	p.Created("ref", domain.Pay{URL: "https://pay"})
	w := uuid.NewV7()
	if err := s.Save(ctx, &p, w); err != nil {
		t.Fatal(err)
	}
	if err := s.Save(ctx, &p, w); err != nil { // a retried save of the same write
		t.Fatalf("retry: %v", err)
	}
	stale.Expire(now.Add(time.Hour))
	if err := s.Save(ctx, &stale, uuid.NewV7()); !errors.Is(err, repository.ErrConflict) {
		t.Fatalf("stale: %v", err)
	}
	got, err := s.Get(ctx, p.ID())
	if err != nil || got.ProviderRef() != "ref" || got.Pay().URL != "https://pay" || got.Status() != domain.StatusPending {
		t.Fatalf("get: %+v %v", got.State(), err)
	}
	if _, err = s.Get(ctx, uuid.NewV7()); !errors.Is(err, repository.ErrNotFound) {
		t.Fatalf("unknown: %v", err)
	}
	q, _ := domain.NewPayment(uuid.NewV7(), account, "fake", listing, 3, now)
	if _, _, err = s.Open(ctx, q, now); err != nil {
		t.Fatal(err)
	}
	q.Created("ref", domain.Pay{})
	if err = s.Save(ctx, &q, uuid.NewV7()); err == nil {
		t.Fatal("two payments share a provider reference")
	}
}
```

Write `seed` with plain `INSERT INTO accounts (id, write_id) VALUES (@id, @id)` (as `discovery/service/saved_test.go:65` does) and an `INSERT INTO listings` with the NOT NULL columns of `migrations/0007_catalog.sql` and later migrations.

- [ ] **Step 2: Run and see it fail**

Run: `go test ./internal/billing/repository/`
Expected: compile error.

- [ ] **Step 3: Implement**

`repository.go`: package doc ("stores module billing's payments in Postgres. Each method is its own transaction."), `ErrNotFound = errors.New("billing: not found")`, `ErrConflict = errors.New("billing: changed meanwhile")`, and the interface above.

`payment_pg.go`, following `catalog/repository/listing_pg.go` (columns constant, `scanPayment`, `args` from `PaymentState`, empty strings stored as NULL for `provider_ref`, `pay_*`, `refund_reason`):

```go
func (s pgPayments) Open(ctx context.Context, p domain.Payment, now time.Time) (domain.Payment, bool, error) {
	st := p.State()
	var (
		out     domain.Payment
		created bool
	)
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext(@account::text))`,
			pgx.StrictNamedArgs{"account": st.AccountID}); err != nil {
			return fmt.Errorf("lock account: %w", err)
		}
		found, err := scanPayment(tx.QueryRow(ctx, `SELECT `+paymentColumns+` FROM payments
WHERE id = @id OR (account_id = @account AND listing_id = @listing AND days = @days
                   AND status = 'pending' AND expires_at > @now)
ORDER BY id = @id DESC, created_at DESC LIMIT 1`,
			pgx.StrictNamedArgs{"id": st.ID, "account": st.AccountID, "listing": st.ListingID, "days": st.Days, "now": now}))
		if err == nil {
			out = found
			return nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return err
		}
		var pending int
		if err = tx.QueryRow(ctx, `SELECT count(*) FROM payments WHERE account_id = @account AND status = 'pending'`,
			pgx.StrictNamedArgs{"account": st.AccountID}).Scan(&pending); err != nil {
			return fmt.Errorf("count pending: %w", err)
		}
		if pending >= domain.MaxPending {
			return domain.ErrTooManyPending
		}
		if _, err = tx.Exec(ctx, insertPayment, args(st)); err != nil {
			return fmt.Errorf("insert payment: %w", err)
		}
		out, created = p, true
		return nil
	})
	if err != nil {
		return domain.Payment{}, false, fmt.Errorf("open payment: %w", err)
	}
	return out, created, nil
}
```

Note the cap counts `pending` rows including ones past `expires_at` that settle has not expired yet; that is intended (settle expires them within seconds of the 15-minute run).

`Save` mirrors `pgListings.Save` without the cap: `UPDATE payments SET <every changing column>, write_id = @write_id WHERE id = @id AND (write_id = @read_write_id OR write_id = @write_id)`; no row is `ErrConflict`; then `events.Insert` for each event; then `p.Saved(writeID)`. A unique violation on `(provider, provider_ref)` is returned as a plain error.

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/billing/repository/` → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/billing/repository && git commit -m "feat(billing): payments in Postgres; a pending one is reused, at most 3 wait"
```

---

### Task 8: Billing service: start, settle, read, check, notify

**Files:**
- Create: `internal/billing/service/service.go`, `views.go`, `boost_start_durable.go`, `settle_durable.go`, `payment.go` (Payment, Check, Notify, Offers, RefundFacts)
- Modify: `internal/platform/events/events.go` (`PaymentRefunded`)
- Test: `internal/billing/service/helpers_test.go`, `start_test.go`, `settle_test.go`

**Interfaces:**
- Consumes: `repository.Payments`, `catalogsvc.Service` (`Summaries`, `Boost`), `accountsvc.Service.Status`, `payment.Provider`, `restatex.Caller`, `restatex.Now`, `restatex.NewID`, `restatex.Outcome`.
- Produces:
  ```go
  type Service interface {
      Offers(ctx context.Context) OffersView
      StartBoost(ctx context.Context, caller, listing uuid.UUID, days int, idempotencyKey string) (PaymentView, error)
      Payment(ctx context.Context, caller, id uuid.UUID) (PaymentView, error)
      Check(ctx context.Context, caller, id uuid.UUID) (PaymentView, error)
      // Notify takes a provider's notification: a bad signature, or one for
      // another provider, is domain.ErrInvalidSignature; a good one wakes settle.
      Notify(ctx context.Context, provider string, body []byte, header http.Header) error
      // RefundFacts reads a refunded payment for notification; false when unknown.
      RefundFacts(ctx context.Context, id uuid.UUID) (RefundFacts, bool, error)
      // DevPayment reads a payment and its listing's title for the fake's page.
      DevPayment(ctx context.Context, id uuid.UUID) (PaymentView, string, error)
  }
  type Deps struct { Payments repository.Payments; Accounts accountsvc.Service; Catalog catalogsvc.Service;
      Provider payment.Provider; Ingress *ingress.Client; Prefix string; Now func() time.Time }
  func New(d Deps) *Billing
  func (b *Billing) Durable() []restate.ServiceDefinition // BillingStart, BillingSettle
  type OffersView struct { Offers []domain.Offer `json:"offers"`; PayWith string `json:"pay_with"` }
  type PaymentView struct { … as the spec's Payment … }
  type RefundFacts struct { ID, AccountID, ListingID uuid.UUID; Amount int64; ListingTitle string }
  type SettleInput struct { PaymentID uuid.UUID `json:"payment_id"`; Trigger string `json:"trigger"` } // ipn | check | expire | recheck
  ```
  `events.PaymentRefunded Kind = "payment.refunded"`.

- [ ] **Step 1: Write the failing tests**

`helpers_test.go` builds the env the way `internal/discovery/service/saved_test.go:39-91` does (pgtest DB, accounts, media, catalog), plus:

```go
type clock struct{ offset atomic.Int64 }

func (c *clock) now() time.Time      { return time.Now().Add(time.Duration(c.offset.Load())) }
func (c *clock) add(d time.Duration) { c.offset.Add(int64(d)) }

type env struct {
	db       *pgxpool.Pool
	listings catalogrepo.Listings
	catalog  *catalogsvc.Catalog
	billing  *service.Billing
	fake     *payment.Fake
	clock    *clock
	in       *ingress.Client
	prefix   string
}

func newEnv(t *testing.T) env {
	// … as discovery's newEnv for db, accounts, media, catalog (with Now: clk.now) …
	fake := payment.NewFake(db, "https://api.test", clk.now)
	b := service.New(service.Deps{
		Payments: repository.NewPayments(db), Accounts: accounts, Catalog: c, Provider: fake,
		Ingress: in, Prefix: p, Now: clk.now,
	})
	restatetest.Start(t, append(c.Durable(), b.Durable()...)...)
	return env{…}
}

// settle runs BillingSettle once and waits for it.
func (e env) settle(t *testing.T, id uuid.UUID, trigger string) {
	t.Helper()
	if _, err := ingress.Service[service.SettleInput, restate.Void](e.in, e.prefix+"BillingSettle", "Run").
		Request(t.Context(), service.SettleInput{PaymentID: id, Trigger: trigger}); err != nil {
		t.Fatal(err)
	}
}
```

plus `account(t)` and `listing(t, seller)` copied from `discovery/service/saved_test.go:65-91`.

`start_test.go`:

```go
func TestStartBoost(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller := e.account(t)
	l := e.listing(t, seller, 500_000)
	key := uuid.NewV7().String()
	p, err := e.billing.StartBoost(ctx, seller, l, 3, key)
	if err != nil || p.Status != domain.StatusPending || p.Amount != 35_000 || p.Pay == nil || p.Pay.URL == "" {
		t.Fatalf("start: %+v %v", p, err)
	}
	if again, err := e.billing.StartBoost(ctx, seller, l, 3, key); err != nil || again.ID != p.ID {
		t.Fatalf("same key: %+v %v", again, err)
	}
	if reused, err := e.billing.StartBoost(ctx, seller, l, 3, uuid.NewV7().String()); err != nil || reused.ID != p.ID {
		t.Fatalf("reuse: %+v %v", reused, err)
	}
	if _, err = e.billing.StartBoost(ctx, e.account(t), l, 1, uuid.NewV7().String()); !errors.Is(err, catalogdomain.ErrNotFound) {
		t.Fatalf("another seller: %v", err)
	}
	if _, err = e.billing.StartBoost(ctx, seller, l, 2, uuid.NewV7().String()); !errors.Is(err, domain.ErrInvalidBoost) {
		t.Fatalf("2 days: %v", err)
	}
}
```

`settle_test.go`, one test per branch:

```go
func TestSettlePaidBoosts(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller := e.account(t)
	l := e.listing(t, seller, 500_000)
	p, _ := e.billing.StartBoost(ctx, seller, l, 1, uuid.NewV7().String())
	if err := e.fake.Pay(ctx, p.ID); err != nil {
		t.Fatal(err)
	}
	if err := e.billing.Notify(ctx, "fake", e.fake.Notification(p.ID), nil); err != nil {
		t.Fatal(err)
	}
	got := waitStatus(t, e, seller, p.ID, domain.StatusPaid)
	if got.BoostedUntil == nil || time.Until(*got.BoostedUntil) < 23*time.Hour {
		t.Fatalf("%+v", got)
	}
}

func TestSettleRefundsWhenTheListingIsGone(t *testing.T) { /* StartBoost; catalog.Hide(seller, l); fake.Pay; settle(ipn);
	Payment status refunded, refund_reason listing_not_boostable; fake_payments.refunded_at set;
	one events row of kind payment.refunded with id = payment ID */ }

func TestSettleExpiresUnpaid(t *testing.T) { /* StartBoost; settle(check) leaves pending; clock.add(16m); settle(expire)
	→ expired, pay nil */ }

func TestSettleAtExpiryFindsItPaid(t *testing.T) { /* StartBoost; fake.Pay (no IPN); clock.add(16m); settle(expire) → paid */ }

func TestSettleLatePayment(t *testing.T) { /* expire as above; fake.Pay; settle(ipn) → paid with boosted_until;
	second payment: expire, Hide listing, fake.Pay, settle(recheck) → refunded */ }

func TestSettleTwiceAtOnceBoostsOnce(t *testing.T) { /* StartBoost 1 day; fake.Pay; two goroutines settle(ipn);
	listing's boosted_until within a minute of now+24h (read via catalog.Get as seller), listing_boosts has 1 row */ }

func TestSettleIgnoresAWrongAmount(t *testing.T) { /* StartBoost; fake.Pay; UPDATE fake_payments SET amount = 1;
	settle(ipn) → still pending; clock.add(16m); settle(expire) → expired */ }

func TestCheck(t *testing.T) { /* StartBoost; fake.Pay; Check → returns; waitStatus paid.
	Check on the paid payment returns it and sends nothing (count invocations is not observable;
	assert it returns 200-equivalent and status paid). Check by another account → domain.ErrPaymentNotFound. */ }

func TestNotifyRefusals(t *testing.T) { /* Notify("fake", []byte("x")) → ErrInvalidSignature;
	Notify("momo", good body) → ErrInvalidSignature; Notify for an unknown payment ID → nil */ }

func TestOff(t *testing.T) { /* service.New with Provider: payment.Off{} (no Restate needed):
	Offers → {Offers: [], PayWith: ""}; StartBoost(…, 1, key) → domain.ErrBoostsUnavailable;
	Notify("off", any body) → domain.ErrInvalidSignature */ }
```

Write each `/* … */` body in full, in the style of `TestSettlePaidBoosts`. `waitStatus` polls `e.billing.Payment(ctx, seller, id)` every 100 ms for up to 15 s until the status matches, failing the test with the last view otherwise.

- [ ] **Step 2: Run and see them fail**

Run: `go test ./internal/billing/service/`
Expected: compile error.

- [ ] **Step 3: Implement**

`events.go`, add to the kinds:

```go
	// PaymentRefunded is a payment billing gave back; event ID = payment ID.
	PaymentRefunded Kind = "payment.refunded"
```

`service.go`: package doc, `Service`, `Deps`, `Billing` struct holding the deps plus `start restatex.Caller[BoostStartInput, BoostStartResult]`, `New`, `Durable()` returning `restate.Reflect(BillingStart{Billing: b})` and `restate.Reflect(BillingSettle{Billing: b})`.

`views.go`:

```go
// PaymentView is the Payment schema in api/schemas/billing.yaml.
type PaymentView struct {
	ID           uuid.UUID           `json:"id"`
	Status       domain.Status       `json:"status"`
	Amount       int64               `json:"amount"`
	Purpose      Purpose             `json:"purpose"`
	Pay          *domain.Pay         `json:"pay,omitempty"`           //exhaustruct:optional
	ExpiresAt    time.Time           `json:"expires_at"`
	PaidAt       *time.Time          `json:"paid_at,omitempty"`       //exhaustruct:optional
	BoostedUntil *time.Time          `json:"boosted_until,omitempty"` //exhaustruct:optional
	RefundedAt   *time.Time          `json:"refunded_at,omitempty"`   //exhaustruct:optional
	RefundReason domain.RefundReason `json:"refund_reason,omitempty"` //exhaustruct:optional
}

// Purpose is what a payment buys.
type Purpose struct {
	Kind      string    `json:"kind"` // boost
	ListingID uuid.UUID `json:"listing_id"`
	Days      int       `json:"days"`
}

func view(p *domain.Payment) PaymentView {
	v := PaymentView{
		ID: p.ID(), Status: p.Status(), Amount: p.Amount(),
		Purpose:   Purpose{Kind: "boost", ListingID: p.ListingID(), Days: p.Days()},
		ExpiresAt: p.ExpiresAt(), PaidAt: p.PaidAt(), BoostedUntil: p.BoostedUntil(),
		RefundedAt: p.RefundedAt(), RefundReason: p.RefundReason(),
	}
	if pay := p.Pay(); p.Status() == domain.StatusPending && pay.URL != "" {
		v.Pay = &pay
	}
	return v
}
```

`boost_start_durable.go`:

```go
// billingStart is the BillingStart service's name without the prefix.
const billingStart = "BillingStart"

// BoostStartInput is a seller's purchase of a boost.
type BoostStartInput struct {
	Caller    uuid.UUID `json:"caller"`
	ListingID uuid.UUID `json:"listing_id"`
	Days      int       `json:"days"`
}

// BoostStartResult carries the payment, or the refusal.
type BoostStartResult struct {
	Payment *domain.Payment `json:"payment,omitempty"`
	Refused *apperr.Error   `json:"refused,omitempty"`
}

func (r BoostStartResult) Refusal() *apperr.Error { return r.Refused }

// BillingStart opens a payment for a boost, asks the provider for a way to
// pay it, and schedules settle at its expiry and a day later. A pending
// payment for the same listing and days is returned as it is.
type BillingStart struct{ Billing *Billing }

func (s BillingStart) ServiceName() string { return s.Billing.prefix + billingStart }

func (s BillingStart) Run(ctx restate.Context, in BoostStartInput) (BoostStartResult, error) {
	b := s.Billing
	at, err := restatex.Now(ctx, b.now)
	if err != nil {
		return BoostStartResult{}, err
	}
	checked, err := restate.Run(ctx, func(rc restate.RunContext) (refusalAndTitle, error) {
		st, stepErr := b.accounts.Status(rc, in.Caller)
		if stepErr != nil {
			return refusalAndTitle{}, fmt.Errorf("read account status: %w", stepErr)
		}
		if st == accountdomain.StatusSuspended {
			return refusalAndTitle{Refused: accountdomain.ErrSuspended}, nil
		}
		got, stepErr := b.catalog.Summaries(rc, []uuid.UUID{in.ListingID})
		if stepErr != nil {
			return refusalAndTitle{}, fmt.Errorf("read listing: %w", stepErr)
		}
		l, ok := got[in.ListingID]
		switch {
		case !ok || l.SellerID != in.Caller || l.Status == catalogdomain.StatusDeleted:
			return refusalAndTitle{Refused: catalogdomain.ErrNotFound}, nil
		case l.Status != catalogdomain.StatusActive:
			return refusalAndTitle{Refused: catalogdomain.ErrNotBoostable}, nil
		default:
			return refusalAndTitle{Title: l.Title}, nil
		}
	})
	if err != nil || checked.Refused != nil {
		return BoostStartResult{Refused: checked.Refused}, err
	}
	p, err := domain.NewPayment(restatex.NewID(ctx, at), in.Caller, b.provider.Name(), in.ListingID, in.Days, at)
	if err != nil {
		return BoostStartResult{Refused: apperr.From(err)}, nil
	}
	opened, err := restate.Run(ctx, func(rc restate.RunContext) (openedPayment, error) {
		got, created, stepErr := b.payments.Open(rc, p, at)
		if errors.Is(stepErr, domain.ErrTooManyPending) {
			return openedPayment{Refused: domain.ErrTooManyPending}, nil
		}
		return openedPayment{Payment: got, Created: created}, stepErr
	})
	if err != nil || opened.Refused != nil {
		return BoostStartResult{Refused: opened.Refused}, err
	}
	if !opened.Created {
		return BoostStartResult{Payment: &opened.Payment}, nil
	}
	created, err := restate.Run(ctx, func(rc restate.RunContext) (payment.Created, error) {
		return b.provider.Create(rc, payment.Order{
			ID: p.ID(), Amount: p.Amount(), Description: "Đẩy tin " + checked.Title, ExpiresAt: p.ExpiresAt(),
		})
	})
	if err != nil {
		return BoostStartResult{}, fmt.Errorf("create the provider's order: %w", err)
	}
	p.Created(created.Ref, created.Pay)
	w := restatex.NewID(ctx, at)
	if err = restate.RunVoid(ctx, func(rc restate.RunContext) error {
		p := p // Save sets the write ID on its copy; p outside stays as journaled
		return b.payments.Save(rc, &p, w)
	}); err != nil {
		return BoostStartResult{}, fmt.Errorf("save the way to pay: %w", err)
	}
	p.Saved(w)
	settle := restate.ServiceSend(ctx, b.prefix+billingSettle, "Run")
	settle.Send(SettleInput{PaymentID: p.ID(), Trigger: TriggerExpire}, restate.WithDelay(domain.PendingFor))
	settle.Send(SettleInput{PaymentID: p.ID(), Trigger: TriggerRecheck}, restate.WithDelay(domain.RecheckAfter))
	return BoostStartResult{Payment: &p}, nil
}

// refusalAndTitle is the purchase's check: a refusal, or the listing's title.
type refusalAndTitle struct {
	Title   string        `json:"title"`
	Refused *apperr.Error `json:"refused,omitempty"`
}

// openedPayment is what Open returned, or the cap's refusal.
type openedPayment struct {
	Payment domain.Payment `json:"payment"`
	Created bool           `json:"created"`
	Refused *apperr.Error  `json:"refused,omitempty"`
}
```

`payment.Created` must have JSON tags for the journal; add `json:"ref"`/`json:"pay"` in Task 6's type if missing. A save conflict in the "save the way to pay" step can only come from a settle that ran before the sends, which cannot happen; Restate retries it as a fault.

`settle_durable.go`:

```go
// billingSettle is the BillingSettle service's name without the prefix.
const billingSettle = "BillingSettle"

// The triggers of a settle run.
const (
	TriggerIPN     = "ipn"
	TriggerCheck   = "check"
	TriggerExpire  = "expire"
	TriggerRecheck = "recheck"
)

// SettleInput names the payment to settle and who asked.
type SettleInput struct {
	PaymentID uuid.UUID `json:"payment_id"`
	Trigger   string    `json:"trigger"`
}

// BillingSettle asks the provider about a payment and settles it: a paid
// one boosts its listing, or is refunded when the listing is no longer
// active; an unpaid one past its expiry expires. Runs at once are safe: a
// save that loses to another reads again, and the boost and the refund are
// idempotent by payment ID.
type BillingSettle struct{ Billing *Billing }

func (s BillingSettle) ServiceName() string { return s.Billing.prefix + billingSettle }

// settleAttempts is how often a run reads again after losing a save.
const settleAttempts = 3

func (s BillingSettle) Run(ctx restate.Context, in SettleInput) error {
	b := s.Billing
	for range settleAttempts {
		at, err := restatex.Now(ctx, b.now)
		if err != nil {
			return err
		}
		l, err := restate.Run(ctx, func(rc restate.RunContext) (loadedPayment, error) {
			p, stepErr := b.payments.Get(rc, in.PaymentID)
			if errors.Is(stepErr, repository.ErrNotFound) {
				return loadedPayment{}, nil
			}
			return loadedPayment{Payment: p, Found: stepErr == nil}, stepErr
		})
		if err != nil {
			return fmt.Errorf("load the payment: %w", err)
		}
		p := l.Payment
		if !l.Found || p.Settled() {
			return nil
		}
		answer, err := restate.Run(ctx, func(rc restate.RunContext) (payment.Answer, error) {
			return b.provider.Query(rc, p.ID())
		})
		if err != nil {
			return fmt.Errorf("ask the provider: %w", err)
		}
		var evs []events.Event
		if !answer.Paid || !p.Confirms(answer.OrderID, answer.Amount) {
			if !p.Expire(at) {
				return nil
			}
		} else {
			boost, err := restate.Run(ctx, func(rc restate.RunContext) (appliedBoost, error) {
				until, stepErr := b.catalog.Boost(rc, p.ID(), p.ListingID(), p.Days())
				if errors.Is(stepErr, catalogdomain.ErrNotBoostable) {
					return appliedBoost{Refused: true}, nil
				}
				return appliedBoost{Until: until}, stepErr
			})
			if err != nil {
				return fmt.Errorf("boost the listing: %w", err)
			}
			var moveErr error
			if boost.Refused {
				if err = restate.RunVoid(ctx, func(rc restate.RunContext) error {
					return b.provider.Refund(rc, p.ID(), p.Amount())
				}); err != nil {
					return fmt.Errorf("refund: %w", err)
				}
				moveErr = p.Refunded(domain.RefundNotBoostable, at)
				evs = append(evs, events.Event{ID: p.ID(), Kind: events.PaymentRefunded, SubjectID: p.ID(), OccurredAt: at})
			} else {
				moveErr = p.Paid(boost.Until, at)
			}
			if moveErr != nil {
				return restate.TerminalError(moveErr) // a settled payment slipped past the check above: a bug
			}
		}
		w := restatex.NewID(ctx, at)
		lost, err := restate.Run(ctx, func(rc restate.RunContext) (bool, error) {
			p := p // Save sets the write ID on its copy; p outside stays as journaled
			return restatex.Outcome(b.payments.Save(rc, &p, w, evs...), repository.ErrConflict)
		})
		if err != nil {
			return fmt.Errorf("save the payment: %w", err)
		}
		if !lost {
			return nil
		}
	}
	return fmt.Errorf("payment %s kept changing under settle", in.PaymentID)
}

// loadedPayment is the payment as the load step read it.
type loadedPayment struct {
	Payment domain.Payment `json:"payment"`
	Found   bool           `json:"found"`
}

// appliedBoost is the boost step's end, or that the listing refused it.
type appliedBoost struct {
	Until   time.Time `json:"until"`
	Refused bool      `json:"refused"`
}
```

`payment.Answer` needs JSON tags for the journal (`paid`, `order_id`, `amount`).

`payment.go`:

```go
func (b *Billing) Offers(context.Context) OffersView {
	if b.provider.Name() == "off" {
		return OffersView{Offers: []domain.Offer{}, PayWith: ""}
	}
	return OffersView{Offers: domain.Offers, PayWith: b.provider.Label()}
}

// StartBoost checks the offer, then runs BillingStart once per caller and
// idempotencyKey.
func (b *Billing) StartBoost(ctx context.Context, caller, listing uuid.UUID, days int, idempotencyKey string) (PaymentView, error) {
	if b.provider.Name() == "off" {
		return PaymentView{}, domain.ErrBoostsUnavailable
	}
	if _, err := domain.FeeFor(days); err != nil {
		return PaymentView{}, err
	}
	res, err := b.start.Call(ctx, caller.String()+"/"+idempotencyKey, BoostStartInput{Caller: caller, ListingID: listing, Days: days})
	if err != nil {
		return PaymentView{}, err
	}
	return view(res.Payment), nil
}

// Payment reads the caller's payment; anyone else's is domain.ErrPaymentNotFound.
func (b *Billing) Payment(ctx context.Context, caller, id uuid.UUID) (PaymentView, error) {
	p, err := b.payments.Get(ctx, id)
	if errors.Is(err, repository.ErrNotFound) || (err == nil && p.AccountID() != caller) {
		return PaymentView{}, domain.ErrPaymentNotFound
	}
	if err != nil {
		return PaymentView{}, fmt.Errorf("get payment: %w", err)
	}
	return view(&p), nil
}

// Check asks settle about the caller's pending payment now, at most once
// every 10 seconds, and returns the payment as it stands.
func (b *Billing) Check(ctx context.Context, caller, id uuid.UUID) (PaymentView, error) {
	v, err := b.Payment(ctx, caller, id)
	if err != nil || v.Status != domain.StatusPending {
		return v, err
	}
	key := fmt.Sprintf("check:%s:%d", id, b.now().Unix()/10)
	if _, err = ingress.ServiceSend[SettleInput](b.ingress, b.prefix+billingSettle, "Run").
		Send(ctx, SettleInput{PaymentID: id, Trigger: TriggerCheck}, restate.WithIdempotencyKey(key)); err != nil {
		return PaymentView{}, fmt.Errorf("send the check: %w", err)
	}
	return v, nil
}

func (b *Billing) Notify(ctx context.Context, provider string, body []byte, header http.Header) error {
	if provider != b.provider.Name() {
		return domain.ErrInvalidSignature
	}
	id, err := b.provider.Verify(body, header)
	if errors.Is(err, payment.ErrBadSignature) {
		return domain.ErrInvalidSignature
	}
	if err != nil {
		return fmt.Errorf("verify the notification: %w", err)
	}
	if _, err = ingress.ServiceSend[SettleInput](b.ingress, b.prefix+billingSettle, "Run").
		Send(ctx, SettleInput{PaymentID: id, Trigger: TriggerIPN}); err != nil {
		return fmt.Errorf("send settle: %w", err)
	}
	return nil
}
```

`RefundFacts` reads the payment (`ErrNotFound` → false) and the listing's title through `catalog.Summaries`. `DevPayment` reads the payment without an owner check, plus the title; an unknown one is `domain.ErrPaymentNotFound`.

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/billing/... ./internal/platform/events/` → PASS. Run each settle test with `-count=3` once to catch flakiness: `go test ./internal/billing/service/ -run Settle -count=3`.

- [ ] **Step 5: Commit**

```bash
git add internal/billing/service internal/platform/events && git commit -m "feat(billing): BillingStart and BillingSettle; an IPN only wakes settle"
```

---

### Task 9: Billing HTTP API, the fake's page, and wiring

**Files:**
- Create: `internal/billing/billing.go` (Mount), `internal/billing/handler/handler.go`, `internal/billing/handler/dev_pay.go`
- Create: `api/paths/billing.yaml`, `api/schemas/billing.yaml`
- Modify: `api/openapi.yaml` (paths), `internal/app/app.go` (prod refusal, provider choice, Mount, services), `.golangci.yml` (depguard)
- Test: `internal/billing/handler/dev_pay_test.go`, `internal/app/app_test.go` (prod refuses fake, refuses momo), `internal/app/routes_test.go` (already compares routes and spec)

**Interfaces:**
- Consumes: `service.Service`, `*payment.Fake`, `config.PaymentConfig`.
- Produces: `billing.Mounted{Services []restate.ServiceDefinition; Service service.Service}`, `billing.Mount(d module.Deps, protect func(http.Handler) http.Handler, accounts accountsvc.Service, catalog catalogsvc.Service, provider payment.Provider, returnURL string) Mounted`.

- [ ] **Step 1: Write the failing tests**

`internal/app/app_test.go`, next to the push prod test (read how it builds a prod config; reuse it):

```go
func TestProdRefusesTheFakePaymentProvider(t *testing.T) {
	t.Parallel()
	cfg := prodConfig(t) // the helper the push test uses; name it after what exists
	cfg.Payment.Provider = config.PaymentFake
	if _, err := app.New(context.Background(), cfg, discard); err == nil || !strings.Contains(err.Error(), "PAYMENT_PROVIDER=fake") {
		t.Fatalf("%v", err)
	}
	cfg.Payment.Provider = config.PaymentMoMo
	if _, err := app.New(context.Background(), cfg, discard); err == nil || !strings.Contains(err.Error(), "PAYMENT_PROVIDER=momo") {
		t.Fatalf("%v", err)
	}
}
```

`internal/billing/handler/dev_pay_test.go`: an `httptest` request to the page handler with a stub `service.Service` whose `DevPayment` returns a pending view with amount 15000 and title "Ghế gỗ"; assert 200, `Content-Type` `text/html; charset=utf-8`, the body contains `15.000 ₫`, `Ghế gỗ`, a form posting to `/dev/pay/{id}/pay` and one to `/dev/pay/{id}/cancel`, and no `/late` form; with status `expired`, the body has the `/late` form and no `/pay` form. A `POST /dev/pay/{id}/cancel` answers 303 with `Location: shopnexus://payments?payment_id={id}`.

`TestRoutesMatchSpec` fails as soon as the spec gains the billing paths, and passes once the routes exist.

- [ ] **Step 2: Run and see them fail**

Run: `go test ./internal/app/ ./internal/billing/handler/`
Expected: compile errors / FAIL.

- [ ] **Step 3: Implement**

`api/openapi.yaml`, under `paths` after `/v1/saved/{listing_id}`:

```yaml
  /v1/boost-offers:
    $ref: "paths/billing.yaml#/boostOffers"
  /v1/listings/{id}/boosts:
    $ref: "paths/billing.yaml#/listingBoosts"
  /v1/payments/{id}:
    $ref: "paths/billing.yaml#/payment"
  /v1/payments/{id}/check:
    $ref: "paths/billing.yaml#/paymentCheck"
  /v1/payments/ipn/{provider}:
    $ref: "paths/billing.yaml#/paymentIPN"
  /dev/pay/{id}:
    $ref: "paths/billing.yaml#/devPayPage"
  /dev/pay/{id}/{action}:
    $ref: "paths/billing.yaml#/devPayAction"
```

`api/schemas/billing.yaml`:

```yaml
Offer:
  type: object
  additionalProperties: false
  required: [days, fee]
  properties:
    days:
      type: integer
      enum: [1, 3]
    fee:
      type: integer
      format: int64
      description: In đồng.
BoostOffers:
  type: object
  additionalProperties: false
  required: [offers, pay_with]
  properties:
    offers:
      type: array
      items:
        $ref: "#/Offer"
      description: Empty while boosts are not on sale; the app then hides Đẩy tin.
    pay_with:
      type: string
      description: The provider the app names, such as MoMo; empty while boosts are not on sale.
BoostRequest:
  type: object
  additionalProperties: false
  required: [days]
  properties:
    days:
      type: integer
Pay:
  type: object
  additionalProperties: false
  required: [url]
  properties:
    url:
      type: string
      format: uri
      description: The provider's page. The app opens deeplink when it is present, else this.
    deeplink:
      type: string
      description: Opens the provider's app.
    qr:
      type: string
      description: What a web client draws as a QR code.
Payment:
  type: object
  additionalProperties: false
  required: [id, status, amount, purpose, expires_at]
  properties:
    id:
      type: string
      format: uuid
    status:
      type: string
      enum: [pending, paid, expired, refunded]
      description: paid means the money came and the boost was applied. An expired payment paid late becomes paid or refunded.
    amount:
      type: integer
      format: int64
    purpose:
      type: object
      additionalProperties: false
      required: [kind, listing_id, days]
      properties:
        kind:
          type: string
          enum: [boost]
        listing_id:
          type: string
          format: uuid
        days:
          type: integer
    pay:
      $ref: "#/Pay"
    expires_at:
      type: string
      format: date-time
    paid_at:
      type: string
      format: date-time
    boosted_until:
      type: string
      format: date-time
    refunded_at:
      type: string
      format: date-time
    refund_reason:
      type: string
      enum: [listing_not_boostable]
```

`api/paths/billing.yaml`: write each operation in the style of `api/paths/catalog.yaml`, with tags `[billing]` (and `[dev]` for the two dev paths):
- `boostOffers.get` (`operationId: getBoostOffers`, bearer): 200 `BoostOffers`, 401.
- `listingBoosts.post` (`startBoost`, bearer, `IdempotencyKey`, body `BoostRequest`): 202 `Payment`; 400; 401; 403 `account_suspended`; 404 `listing_not_found`; 409 `listing_not_boostable`, `too_many_pending` or `boosts_unavailable`; 422 `invalid_boost`. Description lists the order of checks: `boosts_unavailable`, `invalid_boost`, `account_suspended`, `listing_not_found`, `listing_not_boostable`, `too_many_pending`, and says a pending payment for the same listing and days is returned as it is.
- `payment.get` (`getPayment`, bearer): 200 `Payment`, 400, 401, 404 `payment_not_found`.
- `paymentCheck.post` (`checkPayment`, bearer): 200 `Payment`, 400, 401, 404 `payment_not_found`; the description gives the 10-second rule.
- `paymentIPN.post` (`paymentNotification`, `security: [{}]`, path `provider` string, `requestBody` `application/json` schema `{type: object}`): 204, 400 `invalid_signature`.
- `devPayPage.get` (`devPayPage`, no security, path `id` uuid): 200 `text/html` schema `{type: string}`, 400, 404 `payment_not_found`. Description: served only with `PAYMENT_PROVIDER=fake`.
- `devPayAction.post` (`devPayAction`, no security, path `id` uuid, path `action` enum `[pay, cancel, late]`): 303 with header `Location`, 400, 404.

`handler/handler.go`:

```go
// Register adds the billing endpoints; the provider's notifications are
// public and trusted only through their signature.
func (h *Handler) Register(r *httpx.Router, protect func(http.Handler) http.Handler) {
	r.Handle("GET /v1/boost-offers", protect(http.HandlerFunc(h.Offers)))
	r.Handle("POST /v1/listings/{id}/boosts", protect(http.HandlerFunc(h.StartBoost)))
	r.Handle("GET /v1/payments/{id}", protect(http.HandlerFunc(h.Payment)))
	r.Handle("POST /v1/payments/{id}/check", protect(http.HandlerFunc(h.Check)))
	r.Handle("POST /v1/payments/ipn/{provider}", http.HandlerFunc(h.Notify))
}
```

Each protected handler follows `trust/handler/handler.go` (`httpx.Caller`, `httpx.Bind` into a request struct with `path:"id"`, `header:"Idempotency-Key"`, JSON `days`; `httpx.WriteError`; `httpx.Respond`). `StartBoost` answers `http.StatusAccepted`. `Notify`:

```go
// Notify serves POST /v1/payments/ipn/{provider}.
func (h *Handler) Notify(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err = h.svc.Notify(r.Context(), r.PathValue("provider"), body, r.Header); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

`handler/dev_pay.go`: `RegisterDev(r *httpx.Router, fake *payment.Fake, returnURL string)` adds `GET /dev/pay/{id}` and `POST /dev/pay/{id}/{action}`. The page is an `html/template` with the amount written as `money` does in `notification/domain/notice.go` (copy that function into the handler; it has one caller there), the title, the status, and forms. Every action first reads `svc.DevPayment(ctx, id)`, so an unknown payment is 404 `payment_not_found`. `pay` and `late` then call `fake.Pay`, then `svc.Notify(ctx, "fake", fake.Notification(id), nil)`, then redirect 303 to `returnURL + "?payment_id=" + id`; `cancel` only redirects. An unknown `action` is 400 (the request validator already refuses it).

`billing.go`:

```go
// Package billing is what sellers pay ShopNexus for: for now a boost of a
// listing, paid through a payment provider.
package billing

// Mounted is what billing's Mount gives app.
type Mounted struct {
	Services []restate.ServiceDefinition
	Service  service.Service
}

// Mount registers the billing endpoints behind protect, and the fake's page
// when provider is the fake.
func Mount(d module.Deps, protect func(http.Handler) http.Handler, accounts accountsvc.Service,
	catalog catalogsvc.Service, provider payment.Provider, returnURL string,
) Mounted {
	svc := service.New(service.Deps{
		Payments: repository.NewPayments(d.Pool), Accounts: accounts, Catalog: catalog, Provider: provider,
		Ingress: d.Ingress, Prefix: d.ServicePrefix, Now: d.Now,
	})
	h := handler.New(svc, d.Log)
	h.Register(d.Router, protect)
	if fake, ok := provider.(*payment.Fake); ok {
		h.RegisterDev(d.Router, fake, returnURL)
	}
	return Mounted{Services: svc.Durable(), Service: svc}
}
```

`internal/app/app.go`:
- next to the push check (line ~97):
  ```go
  	switch {
  	case cfg.Env == config.EnvProd && cfg.Payment.Provider == config.PaymentFake:
  		return nil, errors.New("APP_ENV=prod with PAYMENT_PROVIDER=fake; anyone could boost for free")
  	case cfg.Payment.Provider == config.PaymentMoMo:
  		return nil, errors.New("PAYMENT_PROVIDER=momo is not built yet; use fake or off")
  	}
  ```
- in `mountModules`, after `trustm`:
  ```go
  	var provider payment.Provider = payment.Off{}
  	if cfg.Payment.Provider == config.PaymentFake {
  		provider = payment.NewFake(pool, cfg.Payment.PublicAPIURL, time.Now)
  	}
  	billingm := billing.Mount(d, protect, accounts, catalogm.Service, provider, cfg.Payment.ReturnURL)
  ```
  and add `billingm.Services` to the final `slices.Concat`.

`.golangci.yml` depguard: billing is a module like the others. Write and run this script from `server/` (it edits every module list the same way the existing modules are listed):

```bash
python3 - <<'EOF'
import re
p = '.golangci.yml'
s = open(p).read()
# 1. Wherever discovery's repository, handler or worker is denied, deny billing's too.
for layer in ('repository', 'handler', 'worker'):
    s = re.sub(
        r'(( *)- pkg: github.com/shopnexus/server2/internal/discovery/%s\n\2  desc: ([^\n]*)\n)' % layer,
        lambda m: m.group(1) + '%s- pkg: github.com/shopnexus/server2/internal/billing/%s\n%s  desc: %s\n'
            % (m.group(2), layer, m.group(2), m.group(3)),
        s)
open(p, 'w').write(s)
EOF
```

Then by hand:
- copy the `module discovery:` block to a `module billing:` block (files `**/internal/billing/**`), remove its three `billing/...` entries and add the three `discovery/...` entries with the same `desc`;
- in every `module X:` block except `notification` and `billing`, add `- pkg: github.com/shopnexus/server2/internal/billing/service` with `desc: only notification reads billing; billing calls catalog.`;
- check the `domain layer`, `repository layer` and similar blocks got billing entries from the script (they list every module's upper layers).

Verify: `golangci-lint run ./...` passes, and a throwaway import of `internal/billing/repository` from `internal/catalog/service` is reported by depguard (revert it).

- [ ] **Step 4: Run the tests**

Run: `make test` → PASS (route/spec match, app tests, lint).

- [ ] **Step 5: Commit**

```bash
git add api internal/billing internal/app .golangci.yml && git commit -m "feat(billing): the boost and payment API, the fake's page, and wiring"
```

---

### Task 10: End-to-end tests

**Files:**
- Create: `e2e/billing_test.go`

**Interfaces:**
- Consumes: the API of Task 9; `activeListing`, `activeHidden`, `newAccount`, `bearer`, `newKey`, `call`, `decode`, `errorOf`, `suspend` from the e2e helpers.

- [ ] **Step 1: Write the tests**

```go
package e2e

import (
	"net/http"
	"testing"
	"time"
	"uuid"
)

type paymentBody struct {
	ID     string `json:"id"`
	Status string `json:"status"`
	Amount int64  `json:"amount"`
	Pay    *struct {
		URL string `json:"url"`
	} `json:"pay"`
	BoostedUntil *time.Time `json:"boosted_until"`
	RefundReason string     `json:"refund_reason"`
}

// waitPayment polls GET /v1/payments/{id} until status, for up to 15 s.
func waitPayment(t *testing.T, token, id, status string) paymentBody {
	t.Helper()
	deadline := time.Now().Add(15 * time.Second)
	for {
		res := call(t, server, "GET", "/v1/payments/"+id, nil, bearer(token))
		p := decode[paymentBody](t, res)
		if p.Status == status || time.Now().After(deadline) {
			if p.Status != status {
				t.Fatalf("payment %s: %s", id, res.Body)
			}
			return p
		}
		time.Sleep(100 * time.Millisecond)
	}
}

func TestBoost(t *testing.T) {
	t.Parallel()
	expect := func(name string, res Response, status int, code string) {
		t.Helper()
		if res.Status != status || (code != "" && errorOf(t, res).Code != code) {
			t.Errorf("%s: %d %s", name, res.Status, res.Body)
		}
	}
	seller, _ := newAccount(t)
	other, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken)

	res := call(t, server, "GET", "/v1/boost-offers", nil, bearer(seller.AccessToken))
	expect("offers", res, 200, "")
	expect("offers signed out", call(t, server, "GET", "/v1/boost-offers", nil), 401, "unauthenticated")

	path := "/v1/listings/" + l.ID + "/boosts"
	key := newKey()
	res = call(t, server, "POST", path, map[string]any{"days": 1}, bearer(seller.AccessToken), key)
	p := decode[paymentBody](t, res)
	if res.Status != http.StatusAccepted || p.Status != "pending" || p.Amount != 15_000 || p.Pay == nil {
		t.Fatalf("start: %d %s", res.Status, res.Body)
	}
	if again := decode[paymentBody](t, call(t, server, "POST", path, map[string]any{"days": 1}, bearer(seller.AccessToken), key)); again.ID != p.ID {
		t.Fatalf("same key: %+v", again)
	}
	expect("2 days", call(t, server, "POST", path, map[string]any{"days": 2}, bearer(seller.AccessToken), newKey()), 422, "invalid_boost")
	expect("0 days", call(t, server, "POST", path, map[string]any{"days": 0}, bearer(seller.AccessToken), newKey()), 422, "invalid_boost")
	expect("another's listing", call(t, server, "POST", path, map[string]any{"days": 1}, bearer(other.AccessToken), newKey()), 404, "listing_not_found")
	expect("hidden", call(t, server, "POST", "/v1/listings/"+activeHidden(t, seller.AccessToken)+"/boosts",
		map[string]any{"days": 1}, bearer(seller.AccessToken), newKey()), 409, "listing_not_boostable")
	expect("no key", call(t, server, "POST", path, map[string]any{"days": 1}, bearer(seller.AccessToken)), 400, "")
	expect("start signed out", call(t, server, "POST", path, map[string]any{"days": 1}, newKey()), 401, "unauthenticated")

	expect("another's payment", call(t, server, "GET", "/v1/payments/"+p.ID, nil, bearer(other.AccessToken)), 404, "payment_not_found")
	expect("check another's", call(t, server, "POST", "/v1/payments/"+p.ID+"/check", nil, bearer(other.AccessToken)), 404, "payment_not_found")
	expect("bad id", call(t, server, "GET", "/v1/payments/x", nil, bearer(seller.AccessToken)), 400, "")
	expect("check bad id", call(t, server, "POST", "/v1/payments/x/check", nil, bearer(seller.AccessToken)), 400, "")
	expect("payment signed out", call(t, server, "GET", "/v1/payments/"+p.ID, nil), 401, "unauthenticated")
	expect("check signed out", call(t, server, "POST", "/v1/payments/"+p.ID+"/check", nil), 401, "unauthenticated")

	res = call(t, server, "GET", "/dev/pay/"+p.ID, nil)
	expect("page", res, 200, "")
	expect("page unknown", call(t, server, "GET", "/dev/pay/"+uuid.NewV7().String(), nil), 404, "payment_not_found")
	expect("page bad id", call(t, server, "GET", "/dev/pay/x", nil), 400, "")
	expect("cancel", call(t, server, "POST", "/dev/pay/"+p.ID+"/cancel", nil), 303, "")
	expect("bad action", call(t, server, "POST", "/dev/pay/"+p.ID+"/x", nil), 400, "")
	expect("action unknown", call(t, server, "POST", "/dev/pay/"+uuid.NewV7().String()+"/pay", nil), 404, "")
	expect("pay", call(t, server, "POST", "/dev/pay/"+p.ID+"/pay", nil), 303, "")
	paid := waitPayment(t, seller.AccessToken, p.ID, "paid")
	if paid.BoostedUntil == nil || paid.Pay != nil {
		t.Fatalf("paid: %+v", paid)
	}
	expect("check paid", call(t, server, "POST", "/v1/payments/"+p.ID+"/check", nil, bearer(seller.AccessToken)), 200, "")

	type boostedListing struct {
		BoostedUntil *time.Time `json:"boosted_until"`
	}
	res = call(t, server, "GET", "/v1/listings/"+l.ID, nil, bearer(seller.AccessToken))
	if decode[boostedListing](t, res).BoostedUntil == nil {
		t.Fatalf("seller's listing: %s", res.Body)
	}
	if decode[boostedListing](t, call(t, server, "GET", "/v1/listings/"+l.ID, nil)).BoostedUntil != nil {
		t.Fatal("boosted_until shown to a reader")
	}
}

func TestBoostCapAndSuspension(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	for range 3 {
		l := activeListing(t, seller.AccessToken)
		if res := call(t, server, "POST", "/v1/listings/"+l.ID+"/boosts", map[string]any{"days": 1}, bearer(seller.AccessToken), newKey()); res.Status != 202 {
			t.Fatalf("start: %d %s", res.Status, res.Body)
		}
	}
	l := activeListing(t, seller.AccessToken)
	res := call(t, server, "POST", "/v1/listings/"+l.ID+"/boosts", map[string]any{"days": 1}, bearer(seller.AccessToken), newKey())
	if res.Status != 409 || errorOf(t, res).Code != "too_many_pending" {
		t.Fatalf("fourth: %d %s", res.Status, res.Body)
	}
	suspended, _ := newAccount(t)
	sl := activeListing(t, suspended.AccessToken)
	suspend(t, suspended.Account.ID) // the field naming the account ID in signIn; read auth_helpers_test.go
	res = call(t, server, "POST", "/v1/listings/"+sl.ID+"/boosts", map[string]any{"days": 1}, bearer(suspended.AccessToken), newKey())
	if res.Status != 403 || errorOf(t, res).Code != "account_suspended" {
		t.Fatalf("suspended: %d %s", res.Status, res.Body)
	}
}

func TestPaymentNotification(t *testing.T) {
	t.Parallel()
	for name, body := range map[string]any{"not signed": map[string]any{"order_id": uuid.NewV7().String()}, "empty": map[string]any{}} {
		if res := call(t, server, "POST", "/v1/payments/ipn/fake", body); res.Status != 400 || errorOf(t, res).Code != "invalid_signature" {
			t.Errorf("%s: %d %s", name, res.Status, res.Body)
		}
	}
	if res := call(t, server, "POST", "/v1/payments/ipn/momo", map[string]any{}); res.Status != 400 {
		t.Errorf("another provider: %d", res.Status)
	}
	// A good signature for an unknown payment: 204, so a provider stops sending.
	if res := call(t, server, "POST", "/v1/payments/ipn/fake", fakeNotification(uuid.NewV7())); res.Status != 204 {
		t.Errorf("unknown payment: %d %s", res.Status, res.Body)
	}
}

// fakeNotification is the fake provider's signed body for order.
func fakeNotification(order uuid.UUID) map[string]any {
	var body map[string]any
	_ = json.Unmarshal(payment.NewFake(db, "", time.Now).Notification(order), &body)
	return body
}
```

Add a test that a listing hidden after the purchase is refunded and the seller gets a `boost_refunded` notice (after Task 11; leave it for Task 11's e2e step), and that Search items carry `boosted` (assert on `/v1/feed/nearby` near the listing's commune: the boosted listing is first with `boosted: true`).

The file imports `encoding/json` and `github.com/shopnexus/server2/internal/provider/payment` for `fakeNotification`.

- [ ] **Step 2: Run**

Run: `make test`
Expected: PASS, and the coverage check in `e2e/main_test.go` lists no undeclared billing status. If it names one (for example `devPayAction 404`), add the call that observes it.

- [ ] **Step 3: Commit**

```bash
git add e2e/billing_test.go && git commit -m "test(e2e): boosts, payments, the fake's page and notifications"
```

---

### Task 11: Notification of a refund

**Files:**
- Modify: `internal/notification/domain/notice.go` (type, constructor, text, title, target)
- Modify: `internal/notification/worker/worker.go` (`PaymentRefunded`), `internal/notification/notification.go` (Sources, subscription)
- Modify: `internal/app/app.go` (pass `billingm.Service` in `notification.Sources`)
- Modify: `api/schemas/notification.yaml` (`Notification.type` enum)
- Test: `internal/notification/domain/notice_test.go`, `internal/notification/worker_test.go`, `e2e/billing_test.go`

**Interfaces:**
- Consumes: `billingsvc.Service.RefundFacts`, `events.PaymentRefunded`.
- Produces: `domain.TypeBoostRefunded = "boost_refunded"`, `domain.BoostRefunded(account, payment, listing uuid.UUID, title string, amount int64, at time.Time) Notice`.

- [ ] **Step 1: Write the failing tests**

`notice_test.go`:

```go
func TestBoostRefunded(t *testing.T) {
	t.Parallel()
	listing := uuid.NewV7()
	n := domain.BoostRefunded(uuid.NewV7(), uuid.NewV7(), listing, "Ghế gỗ", 35_000, time.Now())
	if got := domain.Text(n.Type, n.Params); got != "Đã hoàn 35.000 ₫: tin Ghế gỗ không còn đẩy được" {
		t.Fatalf("text: %q", got)
	}
	if domain.Title(n.Type) != "Đẩy tin" || domain.TargetOf(n.Type, n.Params) != (domain.Target{Kind: "listing", ID: listing.String()}) {
		t.Fatal("title or target")
	}
}
```

In `worker_test.go`, follow the existing test for `ReviewPosted`: a stub billing service whose `RefundFacts` returns facts; deliver a `payment.refunded` event; assert one notice of type `boost_refunded` for the account and a push with title "Đẩy tin".

In `e2e/billing_test.go`, add `TestBoostRefund`: start a boost, hide the listing (`POST /v1/listings/{id}/hide`), pay through `/dev/pay/{id}/pay`, wait for `refunded` with `refund_reason: listing_not_boostable`, then poll `GET /v1/notifications` until an item of type `boost_refunded` appears.

- [ ] **Step 2: Run and see them fail**

Run: `go test ./internal/notification/...`
Expected: compile error.

- [ ] **Step 3: Implement**

`notice.go`: add `TypeBoostRefunded Type = "boost_refunded"`;

```go
// BoostRefunded tells a seller their boost's money came back, since the
// listing was no longer on sale when it arrived.
func BoostRefunded(account, payment, listing uuid.UUID, title string, amount int64, at time.Time) Notice {
	return Notice{
		Recipient: account, Type: TypeBoostRefunded, At: at,
		Params: map[string]any{"payment_id": payment.String(), "listing_id": listing.String(), "title": title, "amount": amount},
	}
}
```

text: `TypeBoostRefunded: func(p map[string]any) string { return "Đã hoàn " + money(number(p, "amount")) + ": tin " + str(p, "title") + " không còn đẩy được" }`; `Title` case `TypeBoostRefunded: return "Đẩy tin"`; `TargetOf` case `TypeBoostRefunded: return Target{Kind: "listing", ID: str(p, "listing_id")}`.

`worker.go`: field `Billing billingsvc.Service` on `Worker`;

```go
// PaymentRefunded tells a seller their boost was refunded.
func (w Worker) PaymentRefunded(ctx restate.Context, e events.Event) error {
	f, err := restate.Run(ctx, func(rc restate.RunContext) (billingsvc.RefundFacts, error) {
		facts, _, stepErr := w.Billing.RefundFacts(rc, e.SubjectID)
		if stepErr != nil {
			return billingsvc.RefundFacts{}, fmt.Errorf("read payment: %w", stepErr)
		}
		return facts, nil // an unknown payment gives the zero facts
	})
	if err != nil {
		return fmt.Errorf("read the payment: %w", err)
	}
	if f.ID == (uuid.UUID{}) {
		return nil
	}
	return w.tell(ctx, e, []domain.Notice{domain.BoostRefunded(f.AccountID, f.ID, f.ListingID, f.ListingTitle, f.Amount, e.OccurredAt)})
}
```

(`RefundFacts` needs JSON tags for the journal.) `notification.go`: `Billing billingsvc.Service` in `Sources`, set on the worker, and `events.PaymentRefunded: "PaymentRefunded"` in the subscription map. `app.go`: `Billing: billingm.Service` in `notification.Sources{...}`; move `billing.Mount` above `notification.Mount` if needed. `api/schemas/notification.yaml`: add `boost_refunded` to the `type` enum.

- [ ] **Step 4: Run the tests**

Run: `make test` → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/notification internal/app api e2e && git commit -m "feat(notification): tell a seller their boost was refunded"
```

---

### Task 12: ARCHITECTURE.md and the spec's status

**Files:**
- Modify: `~/shopnexus/server/ARCHITECTURE.md` (Module layout paragraph at lines ~220-232; a new `### Billing` section after `### Discovery`; Search section's ranking bullet)
- Modify: `~/shopnexus/docs/superpowers/specs/2026-11-05-billing-boosts-design.md` (Status line)

- [ ] **Step 1: Load the `humanizing-writing` skill** and keep it open for the prose below.

- [ ] **Step 2: Edit `ARCHITECTURE.md`**

- In Module layout, replace "There is no finance module: ShopNexus holds no money, so there is no wallet and no payment session. Planned next: `billing` (boosts and seller plans);" with a sentence that module `billing` collects service fees (boosts now, seller plans next) and ShopNexus still holds no one's goods money, so there is no wallet. Add billing to the list of modules with the four packages.
- New `### Billing` section with the decisions, one bullet each, from the spec's Decisions table and Flow: offers as constants; `BillingStart` and its two delayed sends (as media schedules an upload's expiry); `BillingSettle` and its four callers; an IPN only wakes settle and `Query` decides, checked against ID and amount; `write_id` instead of a workflow, with the boost idempotent by `listing_boosts` and the refund by payment ID; reuse of a pending payment and the cap of 3; late payment boosts or refunds; `PAYMENT_PROVIDER` `fake`/`off`/`momo` and the prod refusal; the fake's page and `fake_payments`; `payment.refunded` and the notice. Point to the spec path.
- In Search, add the paid tier bullet: `BoostPaid`, weight 100, 15 km box, `boosted_until` in `listings_search` (migration 0024), and that Search only flags `boosted`.

- [ ] **Step 3: Check the prose**

Run: `python3 ~/.claude/skills/humanizing-writing/ai-tells.py --stats ARCHITECTURE.md` and fix every hit in the new text.

- [ ] **Step 4: Commit**

Set the spec's status line to "Status: built (server)." and commit both repos:

```bash
cd ~/shopnexus/server && git add ARCHITECTURE.md && git commit -m "docs: billing, paid boosts and the paid tier of Gần bạn"
cd ~/shopnexus/docs && git add superpowers/specs/2026-11-05-billing-boosts-design.md && git commit -m "spec(billing): built on the server"
```

Run the humanizing checker on each commit message first, as the Global Constraints say.
