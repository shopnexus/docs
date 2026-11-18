# server realtime over WebSocket Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `GET /v1/stream` (SSE, hints that are lost on any gap) with `GET /v1/ws`, a WebSocket backed by a per-account update log with a gapless `seq`, plus typing, `GET /v1/updates` and `accounts.last_active_at`.

**Architecture:** `stream.Notify` keeps its signature; in the caller's transaction it appends one row per account to `account_updates` (taking the next `seq` from a counter row that stays locked until commit) and rings a `Bell`. `PGBell` rings with `pg_notify`, so every replica hears every ring; the `Hub` hands rings to the connections of their accounts and marks a connection `behind` when it may have missed one, and the connection then reads the log. The socket handler lives in `internal/platform/stream` and reaches modules account and chat through a small `Access` interface that `internal/app` adapts.

**Tech Stack:** Go 1.27, pgx v5, Postgres (ParadeDB image), `github.com/coder/websocket` (newest release), kin-openapi for the spec.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-10-server-realtime-ws-design.md`. Server repo: `~/shopnexus/server` (module `github.com/shopnexus/server`). Read `server/CLAUDE.md` and `server/ARCHITECTURE.md` (sections Events and Stream) before starting.

## Global Constraints

- All paths below are relative to `~/shopnexus/server` unless they start with `~`.
- Use the newest release of every library: add the WebSocket library with `go get github.com/coder/websocket@latest`.
- Configuration has no defaults; this plan adds no configuration variable.
- A use case or HTTP handler reads top to bottom: no helper called from one place only. A closure used in two or more places inside one handler is fine.
- Scratch files and logs go in `tmp/`, never `/tmp`.
- Tests need the test stack: run `make test` once (it starts `docker-compose.test.yml`); afterwards `go test ./internal/platform/stream/...` and other single packages run against it. Finish every task with `go test -race ./...` and `golangci-lint run ./...` both clean (that is what `make test` runs).
- `golangci-lint fmt` applies gofumpt. Struct literals outside `internal/platform/config` may leave fields out.
- Commit messages follow the repo's style (`feat(stream): …`, `refactor(stream): …`, `test(e2e): …`), with no `Co-Authored-By` line.
- Frame and close-code constants, copied from the spec: frames at most 4 KB; ping every 25 s, pong within 10 s; typing at most once per 3 s per connection and conversation; peer check cached 30 s; `last_active_at` written at connect, close and every 60 s, skipped when less than 30 s old; catch-up pages of 500; updates kept 30 days, pruned 10,000 at a time every hour; hub queue 16 per connection; close codes 1001 (shutdown), 4001 (token expired, bad or another account's), 4003 (suspended), 1008 (malformed frame).
- One deviation from the spec, recorded in `ARCHITECTURE.md` in Task 7: a frame over 4 KB closes with 1009 (`StatusMessageTooBig`), which `coder/websocket` sends itself when the read limit is passed; 1008 stays for a frame that is not JSON text.

## Review Focus

- An app far behind (more than one 500-update page) must get every update in order, then `ready`: pinned by `TestSocketPagesThroughALongBacklog` in Task 6.
- One account on two devices must get each update on both connections: pinned by `TestEventsReachEveryConnectionOfTheAccount` (Task 3) and `TestTwoDevicesBothGetUpdates` (Task 6).
- A frame that is not JSON text (binary, garbage) must close with 1008, not crash or hang: pinned by `TestMalformedFrameCloses1008` in Task 6.
- An account suspended while connected must be closed with 4003 at its next `auth`: pinned by `TestSuspensionClosesAtTheNextAuth` in Task 6.
- A lost `LISTEN` connection (CNPG failover) must make every connection read the log again: pinned by `TestListenResyncsAfterALostConnection` (Task 1) and `TestResyncMarksEveryConnectionBehind` (Task 3).

---

### Task 1: The bell

Moves `pg_notify` behind a `Bell` interface with one implementation, `PGBell`, whose `Listen` reports each (re)start of listening so the hub can resync. `Notify` keeps writing no log yet (every target has `Seq` 0); the SSE handler keeps working.

**Files:**
- Modify: `internal/platform/postgres/listen.go` (new `listening` parameter)
- Modify: `internal/platform/events/bus.go:127` (pass a no-op)
- Create: `internal/platform/stream/bell.go`
- Modify: `internal/platform/stream/stream.go` (Hint.Kind in JSON, Notify rings through PGBell)
- Modify: `internal/platform/stream/hub.go` (takes a Bell)
- Modify: `internal/app/app.go:112` (NewHub arguments)
- Modify: `internal/platform/stream/stream_test.go` (NewHub arguments, `discard` moves)
- Test: `internal/platform/stream/bell_test.go`

**Interfaces:**
- Produces:
  - `postgres.Listen(ctx context.Context, pool *pgxpool.Pool, channel string, log *slog.Logger, listening func(), on func(payload string))`
  - `stream.Target{Account uuid.UUID; Seq int64}` (JSON `account`, `seq,omitempty`)
  - `stream.Bell` interface: `Ring(ctx context.Context, tx pgx.Tx, targets []Target, h Hint) error`; `Listen(ctx context.Context, deliver func([]Target, Hint), resync func())`
  - `stream.PGBell{DB *pgxpool.Pool; Log *slog.Logger}` implementing `Bell`
  - `stream.Hint.Kind` now marshals as `"kind"`
  - `stream.NewHub(bell Bell, log *slog.Logger) *Hub` (replaced again in Task 3)

- [ ] **Step 1: Write the failing test**

Create `internal/platform/stream/bell_test.go`:

```go
package stream_test

import (
	"context"
	"log/slog"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server/internal/platform/stream"
)

var discard = slog.New(slog.DiscardHandler)

// listening runs a PGBell's Listen until the test ends and waits for it to
// listen. It returns the hints it hears and a signal per resync after the
// first.
func listening(t *testing.T, db *pgxpool.Pool) (rings <-chan stream.Hint, resyncs <-chan struct{}) {
	t.Helper()
	got := make(chan stream.Hint, 16)
	again := make(chan struct{}, 16)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		stream.PGBell{DB: db, Log: discard}.Listen(ctx,
			func(_ []stream.Target, h stream.Hint) { got <- h },
			func() { again <- struct{}{} })
		close(done)
	}()
	t.Cleanup(func() {
		cancel()
		<-done
	})
	select {
	case <-again:
	case <-time.After(5 * time.Second):
		t.Fatal("not listening within 5s")
	}
	return got, again
}

func dealRing() stream.Hint {
	id := uuid.NewV7()
	return stream.Hint{Kind: stream.KindDeal, DealID: &id}
}

func heard(t *testing.T, rings <-chan stream.Hint, want stream.Hint) {
	t.Helper()
	select {
	case got := <-rings:
		if got.Kind != want.Kind || *got.DealID != *want.DealID {
			t.Fatalf("heard %+v, want %+v", got, want)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("no ring within 5s")
	}
}

func silent(t *testing.T, rings <-chan stream.Hint) {
	t.Helper()
	select {
	case got := <-rings:
		t.Fatalf("an unexpected ring: %+v", got)
	case <-time.After(500 * time.Millisecond):
	}
}

func TestRingArrivesOnCommitOnly(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	rings, _ := listening(t, db)
	ctx := context.Background()
	bell := stream.PGBell{DB: db, Log: discard}
	targets := []stream.Target{{Account: uuid.NewV7()}}

	rolled := dealRing()
	tx, err := db.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if err = bell.Ring(ctx, tx, targets, rolled); err != nil {
		t.Fatal(err)
	}
	if err = tx.Rollback(ctx); err != nil {
		t.Fatal(err)
	}
	silent(t, rings)

	committed := dealRing()
	if tx, err = db.Begin(ctx); err != nil {
		t.Fatal(err)
	}
	if err = bell.Ring(ctx, tx, targets, committed); err != nil {
		t.Fatal(err)
	}
	silent(t, rings) // not before the commit
	if err = tx.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	heard(t, rings, committed)

	now := dealRing()
	if err = bell.Ring(ctx, nil, targets, now); err != nil {
		t.Fatal(err)
	}
	heard(t, rings, now)
}

func TestListenResyncsAfterALostConnection(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	_, resyncs := listening(t, db)
	if _, err := db.Exec(context.Background(), `
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
WHERE datname = current_database() AND query = 'LISTEN stream'`); err != nil {
		t.Fatal(err)
	}
	select {
	case <-resyncs:
	case <-time.After(5 * time.Second):
		t.Fatal("no resync within 5s of a lost connection")
	}
}
```

Delete the `var discard = …` line from `internal/platform/stream/stream_test.go` (it now lives in `bell_test.go`).

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/platform/stream/ -run 'TestRing|TestListen' -count=1`
Expected: FAIL to compile: `undefined: stream.PGBell`, `undefined: stream.Target`.

- [ ] **Step 3: Give `postgres.Listen` a `listening` callback**

In `internal/platform/postgres/listen.go`, change the doc comment, the signature of `Listen`, and pass the callback to `listenOnce`:

```go
// Listen calls on with the payload of every notification on channel until
// ctx is done, and listening each time it starts to listen, the first time
// included: notifications sent while it was not listening are lost, and the
// caller may want to catch up. It holds a connection of its own, outside
// the pool: a pooled one would hold a slot for good, and Pool.Close would
// wait for it. A lost connection is logged and opened again after a pause.
// channel goes into the SQL unquoted, so it must be a constant of the
// caller.
func Listen(ctx context.Context, pool *pgxpool.Pool, channel string, log *slog.Logger, listening func(), on func(payload string)) {
	for ctx.Err() == nil {
		if err := listenOnce(ctx, pool, channel, listening, on); err != nil && ctx.Err() == nil {
```

and in `listenOnce`:

```go
func listenOnce(ctx context.Context, pool *pgxpool.Pool, channel string, listening func(), on func(payload string)) error {
```

```go
	if _, err = conn.Exec(ctx, "LISTEN "+channel); err != nil {
		return fmt.Errorf("listen: %w", err)
	}
	listening()
	for {
```

In `internal/platform/events/bus.go:127` the bus polls every second anyway, so it passes a no-op:

```go
		postgres.Listen(ctx, b.db, "events", b.log, func() {}, func(string) {
```

- [ ] **Step 4: Create the bell**

Create `internal/platform/stream/bell.go`:

```go
package stream

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/shopnexus/server/internal/platform/postgres"
)

// channel is the Postgres channel rings travel on.
const channel = "stream"

// Target is an account a ring is for, with the seq its update took in the
// account's log; 0 for a typing ring, which has no update.
type Target struct {
	Account uuid.UUID `json:"account"`
	Seq     int64     `json:"seq,omitempty"`
}

// Bell carries rings to every replica. The update log holds the truth; a
// ring only says that something new is there, so a lost ring costs a read
// of the log, never an update.
type Bell interface {
	// Ring sends h to targets. With tx it rings when tx commits and never on
	// rollback; with nil it rings at once.
	Ring(ctx context.Context, tx pgx.Tx, targets []Target, h Hint) error
	// Listen calls deliver for each ring until ctx is done, and resync each
	// time it starts to listen, since rings sent before then are lost.
	Listen(ctx context.Context, deliver func([]Target, Hint), resync func())
}

// PGBell rings on Postgres channel stream with pg_notify: every replica
// hears every ring and hands it to its own connections. Ring with a
// transaction needs neither field.
type PGBell struct {
	DB  *pgxpool.Pool
	Log *slog.Logger
}

var _ Bell = PGBell{}

// ring is a ring as it travels on the channel.
type ring struct {
	Targets []Target `json:"targets"`
	Hint    Hint     `json:"hint"`
}

func (b PGBell) Ring(ctx context.Context, tx pgx.Tx, targets []Target, h Hint) error {
	payload, err := json.Marshal(ring{Targets: targets, Hint: h})
	if err != nil {
		return fmt.Errorf("encode ring: %w", err)
	}
	var db postgres.Execer = b.DB
	if tx != nil {
		db = tx
	}
	if _, err = db.Exec(ctx, `SELECT pg_notify(@channel, @payload)`,
		pgx.StrictNamedArgs{"channel": channel, "payload": string(payload)}); err != nil {
		return fmt.Errorf("ring: %w", err)
	}
	return nil
}

func (b PGBell) Listen(ctx context.Context, deliver func([]Target, Hint), resync func()) {
	postgres.Listen(ctx, b.DB, channel, b.Log, resync, func(payload string) {
		var r ring
		if err := json.Unmarshal([]byte(payload), &r); err != nil {
			b.Log.WarnContext(ctx, "stream: bad ring", "err", err)
			return
		}
		deliver(r.Targets, r.Hint)
	})
}
```

- [ ] **Step 5: Ring from `Notify`, and put `Kind` in the JSON**

In `internal/platform/stream/stream.go`: delete `const channel`, the `notification` type and the body of `Notify`; change the `Kind` tag; ring through `PGBell`:

```go
// Hint names what changed: Kind and the IDs that go with it.
type Hint struct {
	Kind           string     `json:"kind"`
	ConversationID *uuid.UUID `json:"conversation_id,omitempty"`
	MessageID      *uuid.UUID `json:"message_id,omitempty"`
	DealID         *uuid.UUID `json:"deal_id,omitempty"`
	NotificationID *uuid.UUID `json:"notification_id,omitempty"`
}

// Notify sends h to the streams of accounts. Postgres delivers it when tx
// commits and drops it on rollback.
func Notify(ctx context.Context, tx pgx.Tx, accounts []uuid.UUID, h Hint) error {
	targets := make([]Target, 0, len(accounts))
	for _, a := range accounts {
		targets = append(targets, Target{Account: a})
	}
	return PGBell{}.Ring(ctx, tx, targets, h)
}
```

Remove the now unused imports (`encoding/json`, `fmt`) from `stream.go`.

- [ ] **Step 6: Let the hub listen through the bell**

In `internal/platform/stream/hub.go`: replace the `db` field with `bell Bell`, `NewHub`, `Run` and `deliver`; drop the `encoding/json`, `pgxpool` and `postgres` imports:

```go
// Hub hands the hints it hears to the streams of their accounts.
type Hub struct {
	bell   Bell
	log    *slog.Logger
	mu     sync.Mutex
	subs   map[uuid.UUID]map[chan Hint]struct{}
	closed bool
}

func NewHub(bell Bell, log *slog.Logger) *Hub {
	return &Hub{bell: bell, log: log, subs: map[uuid.UUID]map[chan Hint]struct{}{}}
}
```

```go
// Run listens until ctx is done, then returns nil. Hints sent while the
// connection is lost are lost too, and the apps reload on their next hint.
func (h *Hub) Run(ctx context.Context) error {
	h.bell.Listen(ctx, h.deliver, func() {})
	return nil
}

// deliver hands the hint to every stream of its targets without waiting.
func (h *Hub) deliver(targets []Target, hint Hint) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, t := range targets {
		for ch := range h.subs[t.Account] {
			select {
			case ch <- hint:
			default:
			}
		}
	}
}
```

In `internal/app/app.go:112` replace `stream.NewHub(pool, log)` with `stream.NewHub(stream.PGBell{DB: pool, Log: log}, log)`.

In `internal/platform/stream/stream_test.go`, `running` builds the hub the same way:

```go
	h := stream.NewHub(stream.PGBell{DB: db, Log: discard}, discard)
```

- [ ] **Step 7: Run the tests**

Run: `go test -race ./internal/platform/stream/ ./internal/platform/events/ ./internal/platform/postgres/ -count=1`
Expected: PASS, the old SSE tests included.

- [ ] **Step 8: Lint and commit**

Run: `golangci-lint run ./...`
Expected: no issues.

```bash
git add internal/platform/postgres/listen.go internal/platform/events/bus.go internal/platform/stream internal/app/app.go
git commit -m "refactor(stream): rings go through a Bell, and Listen reports each start"
```

---

### Task 2: The update log

Adds the tables, makes `Notify` append to each account's log with a gapless `seq`, and adds `PGLog` to read and prune the log.

**Files:**
- Create: `migrations/0025_account_updates.sql`
- Modify: `internal/platform/stream/stream.go` (Update, KindTyping, Notify appends)
- Create: `internal/platform/stream/log.go`
- Modify: `internal/platform/stream/stream_test.go` (its `notify` and `dealHint` helpers move to `log_test.go`)
- Test: `internal/platform/stream/log_test.go`

**Interfaces:**
- Consumes: `PGBell.Ring`, `Target` (Task 1).
- Produces:
  - `stream.KindTyping = "typing"`
  - `stream.Update{Seq int64; Hint}` (JSON: `seq` plus the Hint fields, flattened)
  - `stream.Page{Updates []Update; Seq int64; Reset bool; HasMore bool}` (JSON `updates`, `seq`, `reset`, `has_more`; `Updates` never nil)
  - `stream.UpdateLog` interface: `Current(ctx, account uuid.UUID) (int64, error)`; `Since(ctx, account uuid.UUID, since int64, limit int) (Page, error)`; `Prune(ctx, before time.Time) (int64, error)`
  - `stream.PGLog{DB *pgxpool.Pool}` implementing `UpdateLog`
  - unexported `keepUpdates = 30 * 24 * time.Hour` (Task 3's hub uses it)

- [ ] **Step 1: Write the migration**

Create `migrations/0025_account_updates.sql`:

```sql
-- Realtime: each account's update log. stream.Notify appends a row per
-- account in the transaction of the change. seq runs 1, 2, 3 per account
-- with no hole: the counter row stays locked until commit and rolls back
-- with the transaction, so seqs also become visible in order. No foreign
-- key, as for events: the log is platform data, pruned after 30 days.
CREATE TABLE account_update_seqs (
    account_id uuid PRIMARY KEY,
    seq        bigint NOT NULL
);

CREATE TABLE account_updates (
    account_id      uuid NOT NULL,
    seq             bigint NOT NULL,
    kind            text NOT NULL,
    conversation_id uuid,
    message_id      uuid,
    deal_id         uuid,
    notification_id uuid,
    created_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (account_id, seq)
);
CREATE INDEX account_updates_created_at ON account_updates (created_at);

-- When the person last had the app open; the WebSocket writes it.
ALTER TABLE accounts ADD COLUMN last_active_at timestamptz;
```

- [ ] **Step 2: Write the failing tests**

In `internal/platform/stream/stream_test.go`, delete the `notify` and `dealHint` functions (they move here). Create `internal/platform/stream/log_test.go`:

```go
package stream_test

import (
	"context"
	"sync"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server/internal/platform/stream"
)

func notify(t *testing.T, db *pgxpool.Pool, accounts []uuid.UUID, h stream.Hint, commit bool) {
	t.Helper()
	ctx := context.Background()
	tx, err := db.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if err = stream.Notify(ctx, tx, accounts, h); err != nil {
		t.Fatal(err)
	}
	if commit {
		err = tx.Commit(ctx)
	} else {
		err = tx.Rollback(ctx)
	}
	if err != nil {
		t.Fatal(err)
	}
}

func dealHint() stream.Hint {
	id := uuid.NewV7()
	return stream.Hint{Kind: stream.KindDeal, DealID: &id}
}

func seqs(p stream.Page) []int64 {
	out := make([]int64, 0, len(p.Updates))
	for _, u := range p.Updates {
		out = append(out, u.Seq)
	}
	return out
}

func since(t *testing.T, db *pgxpool.Pool, account uuid.UUID, after int64, limit int) stream.Page {
	t.Helper()
	p, err := stream.PGLog{DB: db}.Since(context.Background(), account, after, limit)
	if err != nil {
		t.Fatal(err)
	}
	return p
}

func TestSeqRunsWithoutHoles(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	a := uuid.NewV7()
	first := dealHint()
	notify(t, db, []uuid.UUID{a}, first, true)
	notify(t, db, []uuid.UUID{a}, dealHint(), true)
	notify(t, db, []uuid.UUID{a}, dealHint(), false) // rolled back: no seq taken
	notify(t, db, []uuid.UUID{a}, dealHint(), true)
	p := since(t, db, a, 0, 10)
	if got := seqs(p); len(got) != 3 || got[0] != 1 || got[1] != 2 || got[2] != 3 || p.Seq != 3 || p.Reset || p.HasMore {
		t.Fatalf("%v %+v", got, p)
	}
	if u := p.Updates[0]; u.Kind != stream.KindDeal || *u.DealID != *first.DealID {
		t.Fatalf("first update %+v", u)
	}
	cur, err := stream.PGLog{DB: db}.Current(context.Background(), a)
	if err != nil || cur != 3 {
		t.Fatalf("current %d %v", cur, err)
	}
	if cur, err = (stream.PGLog{DB: db}).Current(context.Background(), uuid.NewV7()); err != nil || cur != 0 {
		t.Fatalf("a new account's current %d %v", cur, err)
	}
}

// Two transactions notify the same two accounts in opposite orders, many
// times at once; Notify locks in UUID order, so neither deadlocks.
func TestNotifyDoesNotDeadlock(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	a, b := uuid.NewV7(), uuid.NewV7()
	var wg sync.WaitGroup
	errs := make(chan error, 2)
	for _, pair := range [][]uuid.UUID{{a, b}, {b, a}} {
		wg.Go(func() {
			for range 30 {
				if err := pgx.BeginFunc(ctx, db, func(tx pgx.Tx) error {
					return stream.Notify(ctx, tx, pair, dealHint())
				}); err != nil {
					errs <- err
					return
				}
			}
		})
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		t.Fatal(err)
	}
	for _, acc := range []uuid.UUID{a, b} {
		if p := since(t, db, acc, 0, 100); len(p.Updates) != 60 || p.Seq != 60 {
			t.Fatalf("%s: %d updates, seq %d", acc, len(p.Updates), p.Seq)
		}
	}
}

// A transaction that takes seq 2 waits for the one holding seq 1, so a
// reader never sees 2 while 1 may still commit.
func TestSeqBecomesVisibleInCommitOrder(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	a := uuid.NewV7()
	first := dealHint()
	tx1, err := db.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if err = stream.Notify(ctx, tx1, []uuid.UUID{a}, first); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() {
		done <- pgx.BeginFunc(ctx, db, func(tx2 pgx.Tx) error {
			return stream.Notify(ctx, tx2, []uuid.UUID{a}, dealHint())
		})
	}()
	select {
	case err = <-done:
		t.Fatalf("the second notify finished before the first committed: %v", err)
	case <-time.After(300 * time.Millisecond):
	}
	if err = tx1.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	if err = <-done; err != nil {
		t.Fatal(err)
	}
	p := since(t, db, a, 0, 10)
	if got := seqs(p); len(got) != 2 || *p.Updates[0].DealID != *first.DealID {
		t.Fatalf("%v %+v", got, p.Updates)
	}
}

func TestSincePages(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	a := uuid.NewV7()
	for range 5 {
		notify(t, db, []uuid.UUID{a}, dealHint(), true)
	}
	for _, c := range []struct {
		after int64
		want  []int64
		more  bool
	}{{0, []int64{1, 2}, true}, {2, []int64{3, 4}, true}, {4, []int64{5}, false}, {5, []int64{}, false}} {
		p := since(t, db, a, c.after, 2)
		got := seqs(p)
		if p.Reset || p.HasMore != c.more || p.Seq != 5 || len(got) != len(c.want) || p.Updates == nil {
			t.Fatalf("after %d: %v %+v", c.after, got, p)
		}
		for i := range got {
			if got[i] != c.want[i] {
				t.Fatalf("after %d: %v, want %v", c.after, got, c.want)
			}
		}
	}
}

func TestSinceResets(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	a := uuid.NewV7()
	for range 3 {
		notify(t, db, []uuid.UUID{a}, dealHint(), true)
	}
	if p := since(t, db, a, 9, 10); !p.Reset || p.Seq != 3 || p.Updates == nil || len(p.Updates) != 0 {
		t.Fatalf("ahead: %+v", p)
	}
	if _, err := db.Exec(ctx, `UPDATE account_updates SET created_at = now() - interval '31 days' WHERE account_id = @a AND seq = 1`,
		pgx.StrictNamedArgs{"a": a}); err != nil {
		t.Fatal(err)
	}
	n, err := stream.PGLog{DB: db}.Prune(ctx, time.Now().Add(-30*24*time.Hour))
	if err != nil || n != 1 {
		t.Fatalf("pruned %d %v", n, err)
	}
	if p := since(t, db, a, 0, 10); !p.Reset || p.Seq != 3 {
		t.Fatalf("pruned past since: %+v", p)
	}
	if p := since(t, db, a, 1, 10); p.Reset || len(p.Updates) != 2 {
		t.Fatalf("after the pruned row: %+v", p)
	}
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `go test ./internal/platform/stream/ -run 'TestSeq|TestNotify|TestSince' -count=1`
Expected: FAIL to compile: `undefined: stream.PGLog`, `undefined: stream.Page`.

- [ ] **Step 4: Make `Notify` append to the log**

In `internal/platform/stream/stream.go`, replace the package comment, add `KindTyping` and `Update`, and replace `Notify`:

```go
// Package stream tells open apps what changed for their account. A
// repository calls Notify in the transaction of the change: Notify appends
// the change to each account's update log, where it takes the next seq, and
// rings the bell. The hub hands rings to the WebSocket connections of their
// accounts, and a connection that may have missed one reads the log. An
// update carries IDs only; the app reloads what it shows.
package stream
```

```go
const (
	KindMessage = "message"
	KindRead    = "read"
	KindDeal    = "deal"
	// KindNotification is a new or changed notice of the account's.
	KindNotification = "notification"
	// KindTyping is the other member typing in a conversation. It is rung
	// with no update in the log.
	KindTyping = "typing"
)
```

```go
// Update is a hint in an account's log, at its seq.
type Update struct {
	Seq int64 `json:"seq"`
	Hint
}

// appendUpdate takes the account's next seq and writes its update. The
// counter row stays locked until the transaction ends.
const appendUpdate = `
WITH next AS (
    INSERT INTO account_update_seqs (account_id, seq) VALUES (@account, 1)
    ON CONFLICT (account_id) DO UPDATE SET seq = account_update_seqs.seq + 1
    RETURNING seq)
INSERT INTO account_updates (account_id, seq, kind, conversation_id, message_id, deal_id, notification_id)
SELECT @account, seq, @kind, @conversation, @message, @deal, @notification FROM next
RETURNING seq`

// Notify appends h to the log of each of accounts and rings the bell, in
// tx: Postgres rings on commit and drops it all on rollback. It takes the
// accounts' counters in UUID order, so two transactions that notify the
// same accounts cannot deadlock.
func Notify(ctx context.Context, tx pgx.Tx, accounts []uuid.UUID, h Hint) error {
	ids := slices.Clone(accounts)
	slices.SortFunc(ids, uuid.UUID.Compare)
	ids = slices.Compact(ids)
	targets := make([]Target, 0, len(ids))
	for _, a := range ids {
		var seq int64
		if err := tx.QueryRow(ctx, appendUpdate, pgx.StrictNamedArgs{
			"account": a, "kind": h.Kind, "conversation": h.ConversationID, "message": h.MessageID,
			"deal": h.DealID, "notification": h.NotificationID,
		}).Scan(&seq); err != nil {
			return fmt.Errorf("append update: %w", err)
		}
		targets = append(targets, Target{Account: a, Seq: seq})
	}
	return PGBell{}.Ring(ctx, tx, targets, h)
}
```

Imports of `stream.go`: `context`, `fmt`, `slices`, `uuid`, `github.com/jackc/pgx/v5`.

- [ ] **Step 5: Write the log reader**

Create `internal/platform/stream/log.go`:

```go
package stream

import (
	"context"
	"fmt"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	// keepUpdates is how long the log keeps an update; an app further
	// behind gets reset.
	keepUpdates = 30 * 24 * time.Hour
	pruneBatch  = 10_000
)

// Page is a stretch of an account's log: the UpdatePage schema in
// api/schemas/stream.yaml.
type Page struct {
	Updates []Update `json:"updates"`
	// Seq is the account's current seq.
	Seq int64 `json:"seq"`
	// Reset means the log no longer holds the update after since, or since
	// is ahead of the log: the app reloads everything and keeps Seq.
	Reset   bool `json:"reset"`
	HasMore bool `json:"has_more"`
}

// UpdateLog reads and prunes the accounts' update logs.
type UpdateLog interface {
	// Current returns account's latest seq, 0 before its first update.
	Current(ctx context.Context, account uuid.UUID) (int64, error)
	// Since returns up to limit of account's updates after since, in seq
	// order.
	Since(ctx context.Context, account uuid.UUID, since int64, limit int) (Page, error)
	// Prune deletes the updates written before before, 10,000 at a time,
	// and returns how many it deleted.
	Prune(ctx context.Context, before time.Time) (int64, error)
}

// PGLog is the update log in Postgres.
type PGLog struct {
	DB *pgxpool.Pool
}

var _ UpdateLog = PGLog{}

func (l PGLog) Current(ctx context.Context, account uuid.UUID) (int64, error) {
	var seq int64
	if err := l.DB.QueryRow(ctx, `SELECT coalesce(max(seq), 0) FROM account_update_seqs WHERE account_id = @account`,
		pgx.StrictNamedArgs{"account": account}).Scan(&seq); err != nil {
		return 0, fmt.Errorf("read the current seq: %w", err)
	}
	return seq, nil
}

// Since reads the current seq first and no update past it: every seq up to
// the current one has committed, so a missing since+1 means it was pruned.
func (l PGLog) Since(ctx context.Context, account uuid.UUID, since int64, limit int) (Page, error) {
	current, err := l.Current(ctx, account)
	if err != nil {
		return Page{}, err
	}
	if since > current {
		return Page{Updates: []Update{}, Seq: current, Reset: true}, nil
	}
	if since == current {
		return Page{Updates: []Update{}, Seq: current}, nil
	}
	rows, err := l.DB.Query(ctx, `
SELECT seq, kind, conversation_id, message_id, deal_id, notification_id FROM account_updates
WHERE account_id = @account AND seq > @since AND seq <= @current
ORDER BY seq LIMIT @limit`,
		pgx.StrictNamedArgs{"account": account, "since": since, "current": current, "limit": limit + 1})
	if err != nil {
		return Page{}, fmt.Errorf("read updates: %w", err)
	}
	updates, err := pgx.AppendRows(make([]Update, 0, limit+1), rows, func(row pgx.CollectableRow) (Update, error) {
		var u Update
		if err := row.Scan(&u.Seq, &u.Kind, &u.ConversationID, &u.MessageID, &u.DealID, &u.NotificationID); err != nil {
			return Update{}, fmt.Errorf("scan update: %w", err)
		}
		return u, nil
	})
	if err != nil {
		return Page{}, fmt.Errorf("read updates: %w", err)
	}
	if len(updates) == 0 || updates[0].Seq != since+1 {
		return Page{Updates: []Update{}, Seq: current, Reset: true}, nil
	}
	more := len(updates) > limit
	if more {
		updates = updates[:limit]
	}
	return Page{Updates: updates, Seq: current, HasMore: more}, nil
}

func (l PGLog) Prune(ctx context.Context, before time.Time) (int64, error) {
	var total int64
	for {
		tag, err := l.DB.Exec(ctx, `
DELETE FROM account_updates WHERE (account_id, seq) IN (
    SELECT account_id, seq FROM account_updates WHERE created_at < @before LIMIT @limit)`,
			pgx.StrictNamedArgs{"before": before, "limit": pruneBatch})
		if err != nil {
			return total, fmt.Errorf("prune updates: %w", err)
		}
		total += tag.RowsAffected()
		if tag.RowsAffected() < pruneBatch {
			return total, nil
		}
	}
}
```

- [ ] **Step 6: Run the tests**

Run: `go test -race ./internal/platform/stream/ ./migrations/ -count=1`
Expected: PASS, including the old SSE tests (they ignore the seq) and `TestRollbackSendsNothing`.

Then run the modules that call `Notify`, to confirm the log write fits their transactions:
Run: `go test -race ./internal/chat/... ./internal/deal/... ./internal/notification/... -count=1`
Expected: PASS.

- [ ] **Step 7: Lint and commit**

Run: `golangci-lint run ./...`
Expected: no issues.

```bash
git add migrations/0025_account_updates.sql internal/platform/stream
git commit -m "feat(stream): each account's update log with a gapless seq"
```

---

### Task 3: The hub reads the log; SSE goes

Rewrites the hub around subscriptions that fall `behind` instead of losing updates, adds typing rings and the hourly prune, and removes the SSE handler, its route, its OpenAPI path and its tests. Until Task 7 the server has no realtime endpoint; the chat e2e test loses its stream check here and gets it back in Task 7.

**Files:**
- Modify (rewrite): `internal/platform/stream/hub.go`
- Delete: `internal/platform/stream/handler.go`, `internal/platform/stream/stream_test.go`, `api/paths/stream.yaml`, `e2e/stream_test.go`
- Modify: `api/openapi.yaml:96-97` (drop `/v1/stream`)
- Modify: `internal/app/app.go` (NewHub arguments, drop the route, comments)
- Modify: `e2e/chat_test.go:53,59` (drop `openStream` and `waitEvent`)
- Test: `internal/platform/stream/hub_test.go`

**Interfaces:**
- Consumes: `Bell`, `Target` (Task 1); `UpdateLog`, `keepUpdates` (Task 2).
- Produces:
  - `stream.Event{Seq int64; Hint Hint}` (Seq 0 for typing)
  - `*stream.Sub` with `Events() <-chan Event` and `Behind() <-chan struct{}`
  - `stream.NewHub(bell Bell, updates UpdateLog, now func() time.Time, log *slog.Logger) *Hub`
  - `(*Hub).Subscribe(account uuid.UUID) (sub *Sub, stop func())`
  - `(*Hub).Done() <-chan struct{}`, `(*Hub).Close()`
  - `(*Hub).Typing(ctx context.Context, to, conversation uuid.UUID) error`
  - `(*Hub).Run(ctx context.Context) error`

- [ ] **Step 1: Write the failing tests**

Create `internal/platform/stream/hub_test.go`:

```go
package stream_test

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"

	"github.com/shopnexus/server/internal/platform/stream"
)

// fakeBell hands the test the hub's deliver and resync, and records typing
// rings.
type fakeBell struct {
	mu        sync.Mutex
	deliver   func([]stream.Target, stream.Hint)
	resync    func()
	listening chan struct{}
	rung      []stream.Target
}

func (b *fakeBell) Ring(_ context.Context, _ pgx.Tx, targets []stream.Target, _ stream.Hint) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.rung = append(b.rung, targets...)
	return nil
}

func (b *fakeBell) Listen(ctx context.Context, deliver func([]stream.Target, stream.Hint), resync func()) {
	b.mu.Lock()
	b.deliver, b.resync = deliver, resync
	b.mu.Unlock()
	close(b.listening)
	<-ctx.Done()
}

type fakeLog struct{ pruned atomic.Int32 }

func (*fakeLog) Current(context.Context, uuid.UUID) (int64, error) { return 0, nil }

func (*fakeLog) Since(context.Context, uuid.UUID, int64, int) (stream.Page, error) {
	return stream.Page{Updates: []stream.Update{}}, nil
}

func (l *fakeLog) Prune(context.Context, time.Time) (int64, error) {
	l.pruned.Add(1)
	return 0, nil
}

func runningHub(t *testing.T) (*stream.Hub, *fakeBell, *fakeLog) {
	t.Helper()
	bell, log := &fakeBell{listening: make(chan struct{})}, &fakeLog{}
	h := stream.NewHub(bell, log, time.Now, discard)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		_ = h.Run(ctx)
		close(done)
	}()
	t.Cleanup(func() {
		cancel()
		<-done
	})
	<-bell.listening
	return h, bell, log
}

func gets(t *testing.T, s *stream.Sub, want stream.Event) {
	t.Helper()
	select {
	case got := <-s.Events():
		if got.Seq != want.Seq || got.Hint.Kind != want.Hint.Kind {
			t.Fatalf("got %+v, want %+v", got, want)
		}
	case <-time.After(time.Second):
		t.Fatal("no event within 1s")
	}
}

func noEvent(t *testing.T, s *stream.Sub) {
	t.Helper()
	select {
	case got := <-s.Events():
		t.Fatalf("an unexpected event: %+v", got)
	case <-time.After(200 * time.Millisecond):
	}
}

func behind(t *testing.T, s *stream.Sub, want bool) {
	t.Helper()
	select {
	case <-s.Behind():
		if !want {
			t.Fatal("behind, want not")
		}
	case <-time.After(200 * time.Millisecond):
		if want {
			t.Fatal("not behind, want behind")
		}
	}
}

func TestEventsReachEveryConnectionOfTheAccount(t *testing.T) {
	t.Parallel()
	h, bell, _ := runningHub(t)
	a, b := uuid.NewV7(), uuid.NewV7()
	phone, stopPhone := h.Subscribe(a)
	defer stopPhone()
	tablet, stopTablet := h.Subscribe(a)
	defer stopTablet()
	other, stopOther := h.Subscribe(b)
	defer stopOther()
	hint := dealHint()
	bell.deliver([]stream.Target{{Account: a, Seq: 1}}, hint)
	gets(t, phone, stream.Event{Seq: 1, Hint: hint})
	gets(t, tablet, stream.Event{Seq: 1, Hint: hint})
	noEvent(t, other)
}

func TestStoppedSubscriptionGetsNothing(t *testing.T) {
	t.Parallel()
	h, bell, _ := runningHub(t)
	a := uuid.NewV7()
	s, stop := h.Subscribe(a)
	stop()
	bell.deliver([]stream.Target{{Account: a, Seq: 1}}, dealHint())
	noEvent(t, s)
}

func TestFullQueueFallsBehind(t *testing.T) {
	t.Parallel()
	h, bell, _ := runningHub(t)
	a := uuid.NewV7()
	s, stop := h.Subscribe(a)
	defer stop()
	for seq := range int64(16) {
		bell.deliver([]stream.Target{{Account: a, Seq: seq + 1}}, dealHint())
	}
	behind(t, s, false)
	bell.deliver([]stream.Target{{Account: a, Seq: 17}}, dealHint())
	behind(t, s, true)
}

func TestTypingOverAFullQueueIsDropped(t *testing.T) {
	t.Parallel()
	h, bell, _ := runningHub(t)
	a := uuid.NewV7()
	s, stop := h.Subscribe(a)
	defer stop()
	conv := uuid.NewV7()
	typing := stream.Hint{Kind: stream.KindTyping, ConversationID: &conv}
	for range 17 {
		bell.deliver([]stream.Target{{Account: a}}, typing)
	}
	behind(t, s, false)
	if n := len(s.Events()); n != 16 {
		t.Fatalf("%d queued", n)
	}
}

func TestResyncMarksEveryConnectionBehind(t *testing.T) {
	t.Parallel()
	h, bell, _ := runningHub(t)
	sa, stopA := h.Subscribe(uuid.NewV7())
	defer stopA()
	sb, stopB := h.Subscribe(uuid.NewV7())
	defer stopB()
	bell.resync()
	behind(t, sa, true)
	behind(t, sb, true)
}

func TestTypingRingsTheOtherMember(t *testing.T) {
	t.Parallel()
	h, bell, _ := runningHub(t)
	to := uuid.NewV7()
	if err := h.Typing(context.Background(), to, uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	bell.mu.Lock()
	defer bell.mu.Unlock()
	if len(bell.rung) != 1 || bell.rung[0].Account != to || bell.rung[0].Seq != 0 {
		t.Fatalf("%+v", bell.rung)
	}
}

func TestCloseClosesDone(t *testing.T) {
	t.Parallel()
	h, _, _ := runningHub(t)
	h.Close()
	h.Close()
	select {
	case <-h.Done():
	default:
		t.Fatal("Done open after Close")
	}
}

func TestRunPrunesAtStart(t *testing.T) {
	t.Parallel()
	_, _, log := runningHub(t)
	deadline := time.Now().Add(time.Second)
	for log.pruned.Load() == 0 {
		if time.Now().After(deadline) {
			t.Fatal("no prune within 1s of start")
		}
		time.Sleep(10 * time.Millisecond)
	}
}
```

Delete `internal/platform/stream/stream_test.go` and `internal/platform/stream/handler.go`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./internal/platform/stream/ -run 'TestEvents|TestStopped|TestFull|TestTyping|TestResync|TestClose|TestRun' -count=1`
Expected: FAIL to compile: `undefined: stream.Event`, `too many arguments in call to stream.NewHub`.

- [ ] **Step 3: Rewrite the hub**

Replace `internal/platform/stream/hub.go` with:

```go
package stream

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"
	"uuid"
)

const (
	// queue is how many events wait for a slow connection; past it the
	// connection reads the log instead.
	queue      = 16
	pruneEvery = time.Hour
)

// Event is what the hub hands a connection: an update at Seq, or typing
// with Seq 0.
type Event struct {
	Seq  int64
	Hint Hint
}

// Sub is one connection's subscription to its account's events.
type Sub struct {
	events chan Event
	behind chan struct{}
}

// Events delivers the account's events in the order they were rung.
func (s *Sub) Events() <-chan Event { return s.events }

// Behind signals that an update may have been missed, because the queue was
// full or the bell was not listening; the connection reads the log from its
// last seq.
func (s *Sub) Behind() <-chan struct{} { return s.behind }

func (s *Sub) fallBehind() {
	select {
	case s.behind <- struct{}{}:
	default:
	}
}

// Hub hands the rings it hears to the subscriptions of their accounts, and
// prunes the update log.
type Hub struct {
	bell    Bell
	updates UpdateLog
	now     func() time.Time
	log     *slog.Logger
	done    chan struct{}
	mu      sync.Mutex
	subs    map[uuid.UUID]map[*Sub]struct{}
	closed  bool
}

func NewHub(bell Bell, updates UpdateLog, now func() time.Time, log *slog.Logger) *Hub {
	return &Hub{
		bell: bell, updates: updates, now: now, log: log,
		done: make(chan struct{}), subs: map[uuid.UUID]map[*Sub]struct{}{},
	}
}

// Subscribe returns a subscription to account's events until stop is
// called.
func (h *Hub) Subscribe(account uuid.UUID) (sub *Sub, stop func()) {
	s := &Sub{events: make(chan Event, queue), behind: make(chan struct{}, 1)}
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.subs[account] == nil {
		h.subs[account] = map[*Sub]struct{}{}
	}
	h.subs[account][s] = struct{}{}
	return s, func() {
		h.mu.Lock()
		defer h.mu.Unlock()
		delete(h.subs[account], s)
		if len(h.subs[account]) == 0 {
			delete(h.subs, account)
		}
	}
}

// Done is closed by Close.
func (h *Hub) Done() <-chan struct{} { return h.done }

// Close tells every connection to end with 1001, so a server shutdown does
// not wait for them; the apps reconnect to another replica with their seq.
func (h *Hub) Close() {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.closed {
		return
	}
	h.closed = true
	close(h.done)
}

// Typing rings to, at once, that the other member types in conversation.
func (h *Hub) Typing(ctx context.Context, to, conversation uuid.UUID) error {
	if err := h.bell.Ring(ctx, nil, []Target{{Account: to}}, Hint{Kind: KindTyping, ConversationID: &conversation}); err != nil {
		return fmt.Errorf("ring typing: %w", err)
	}
	return nil
}

// Run listens for rings, and prunes the log at start and every hour, until
// ctx is done; then it returns nil.
func (h *Hub) Run(ctx context.Context) error {
	var listening sync.WaitGroup
	listening.Go(func() { h.bell.Listen(ctx, h.deliver, h.resync) })
	defer listening.Wait()
	tick := time.NewTicker(pruneEvery)
	defer tick.Stop()
	for {
		if _, err := h.updates.Prune(ctx, h.now().Add(-keepUpdates)); err != nil && ctx.Err() == nil {
			h.log.WarnContext(ctx, "stream: prune the update log", "err", err)
		}
		select {
		case <-ctx.Done():
			return nil
		case <-tick.C:
		}
	}
}

// deliver queues the event for every subscription of its targets without
// waiting. An update that does not fit marks the subscription behind; a
// typing event that does not fit is dropped.
func (h *Hub) deliver(targets []Target, hint Hint) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, t := range targets {
		for s := range h.subs[t.Account] {
			select {
			case s.events <- Event{Seq: t.Seq, Hint: hint}:
			default:
				if t.Seq > 0 {
					s.fallBehind()
				}
			}
		}
	}
}

// resync marks every subscription behind: the bell was not listening, and
// rings may have been lost.
func (h *Hub) resync() {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, subs := range h.subs {
		for s := range subs {
			s.fallBehind()
		}
	}
}
```

- [ ] **Step 4: Remove the SSE route, path and tests**

In `internal/app/app.go`:
- line 112: `hub: stream.NewHub(stream.PGBell{DB: pool, Log: log}, stream.PGLog{DB: pool}, time.Now, log)`
- in `mountModules`, delete `router.Handle("GET /v1/stream", d.Protect(hub.Handler(log)))` and the now unused `hub *stream.Hub` parameter, and drop `a.hub` from the call in `New`. Task 7 puts the parameter back.
- the comment above `CloseStreams` becomes:

```go
// CloseStreams ends every open WebSocket with 1001, so a server shutdown
// does not wait for them; the server's RegisterOnShutdown calls it.
```

and the `stop` field's comment becomes `// stop cancels the event bus and the stream hub, which run in bg.` (unchanged wording is fine if it already reads so).

In `api/openapi.yaml`, delete:

```yaml
  /v1/stream:
    $ref: "paths/stream.yaml#/stream"
```

Delete `api/paths/stream.yaml` and `e2e/stream_test.go`. In `e2e/chat_test.go`, delete the line `events := openStream(t, seller.AccessToken)` and the line `waitEvent(t, events, "message", c.ID)` in `TestChat`.

- [ ] **Step 5: Run the tests**

Run: `go test -race ./internal/platform/stream/ ./internal/app/ ./api/ -count=1`
Expected: PASS (`TestRoutesMatchSpec` included: neither the routes nor the spec has `/v1/stream`).

Run: `go test -race ./e2e/ -count=1`
Expected: PASS (the coverage check no longer expects `openStream`).

- [ ] **Step 6: Lint and commit**

Run: `golangci-lint run ./...`
Expected: no issues.

```bash
git add -A internal/platform/stream internal/app/app.go api e2e
git commit -m "refactor(stream): the hub marks a connection behind instead of losing updates; SSE goes"
```

---

### Task 4: `last_active_at` in the views

Account learns `Touch`; the chat views and the seller page show the other person's `last_active_at`.

**Files:**
- Modify: `internal/account/domain/account.go` (field, RestoreAccount, getter)
- Modify: `internal/account/repository/account.go` (interface), `internal/account/repository/account_pg.go` (columns, scan, TouchActive)
- Modify: `internal/account/service/service.go` (interface), `internal/account/service/views.go` (AccountView)
- Create: `internal/account/service/account_touch.go`
- Modify: `internal/chat/service/views.go` (PersonView), `internal/chat/service/conversation_get.go:30,48`
- Modify: `internal/screen/service/seller.go` (SellerProfile)
- Modify: `api/schemas/chat.yaml` (Person), `api/schemas/screen_listing.yaml` (SellerProfile)
- Test: `internal/account/repository/account_pg_test.go`, `internal/account/service/account_touch_test.go`, `internal/chat/service/chat_test.go`

**Interfaces:**
- Consumes: the `accounts.last_active_at` column (Task 2's migration).
- Produces:
  - `domain.RestoreAccount(..., createdAt, updatedAt time.Time, lastActiveAt *time.Time) Account`; `(*Account).LastActiveAt() *time.Time`
  - `repository.Accounts.TouchActive(ctx context.Context, id uuid.UUID, at time.Time) error`
  - `accountsvc.Service.Touch(ctx context.Context, id uuid.UUID) error`
  - `accountsvc.AccountView.LastActiveAt *time.Time` (`json:"-"`)
  - `chatsvc.PersonView.LastActiveAt *time.Time` (`json:"last_active_at,omitempty"`)
  - `screensvc.SellerProfile.LastActiveAt *time.Time` (`json:"last_active_at,omitempty"`)

- [ ] **Step 1: Write the failing tests**

Append to `internal/account/repository/account_pg_test.go` (it already has `newStore`, `seed` and `now`; add `"time"` to its imports if missing):

```go
func TestTouchActive(t *testing.T) {
	t.Parallel()
	s := newStore(t)
	ctx := context.Background()
	id := seed(t, s)
	before, err := s.Get(ctx, id)
	if err != nil || before.LastActiveAt() != nil {
		t.Fatalf("%v %v", before.LastActiveAt(), err)
	}
	at := now.Add(time.Hour)
	for _, c := range []struct {
		touch, want time.Time
	}{
		{at, at},
		{at.Add(10 * time.Second), at},            // under 30 s later: not written
		{at.Add(31 * time.Second), at.Add(31 * time.Second)},
	} {
		if err = s.TouchActive(ctx, id, c.touch); err != nil {
			t.Fatal(err)
		}
		a, getErr := s.Get(ctx, id)
		if getErr != nil || a.LastActiveAt() == nil || !a.LastActiveAt().Equal(c.want) {
			t.Fatalf("touch %s: %v %v", c.touch, a.LastActiveAt(), getErr)
		}
		if a.WriteID() != before.WriteID() {
			t.Fatal("TouchActive changed write_id")
		}
	}
}
```

Create `internal/account/service/account_touch_test.go`:

```go
package service_test

import (
	"context"
	"testing"
)

func TestTouch(t *testing.T) {
	t.Parallel()
	s := newStore(t)
	svc := at(s, nil, now)
	id := seed(t, s)
	if err := svc.Touch(context.Background(), id); err != nil {
		t.Fatal(err)
	}
	v, err := svc.Get(context.Background(), id)
	if err != nil || v.LastActiveAt == nil || !v.LastActiveAt.Equal(now) {
		t.Fatalf("%v %v", v.LastActiveAt, err)
	}
}
```

Append to `internal/chat/service/chat_test.go`:

```go
func TestGetShowsWhenTheOtherWasActive(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	c := e.open(t, buyer, catalogtest.Listing(t, e.db, seller), "Còn không?")
	got, err := e.chat.Get(ctx, seller, c.ID)
	if err != nil || got.Other.LastActiveAt != nil {
		t.Fatalf("before: %+v %v", got.Other, err)
	}
	if err = e.accounts.Touch(ctx, buyer); err != nil {
		t.Fatal(err)
	}
	if got, err = e.chat.Get(ctx, seller, c.ID); err != nil || got.Other.LastActiveAt == nil {
		t.Fatalf("after: %+v %v", got.Other, err)
	}
	inbox, err := e.chat.Inbox(ctx, seller, false, page.Request{})
	if err != nil || len(inbox.Items) != 1 || inbox.Items[0].Other.LastActiveAt == nil {
		t.Fatalf("inbox: %+v %v", inbox, err)
	}
}
```

(`chat_test.go` imports `page` already if `TestArchive` uses it; otherwise add `"github.com/shopnexus/server/internal/platform/page"`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./internal/account/... ./internal/chat/service/ -run 'TestTouch|TestGetShowsWhen' -count=1`
Expected: FAIL to compile: `LastActiveAt undefined`, `TouchActive undefined`, `Touch undefined`.

- [ ] **Step 3: Domain and repository**

In `internal/account/domain/account.go`, add the field after `updatedAt`:

```go
	updatedAt      time.Time
	// lastActiveAt is when the person last had the app open; nil before the
	// first time. Only the WebSocket writes it, outside the aggregate's saves.
	lastActiveAt *time.Time
```

`RestoreAccount` takes it last:

```go
// RestoreAccount rebuilds a stored account. Stores only.
func RestoreAccount(id uuid.UUID, displayName, bio, avatarKey string, status Status, suspendedUntil *time.Time,
	suspendReason string, writeID uuid.UUID, createdAt, updatedAt time.Time, lastActiveAt *time.Time,
) Account {
	return Account{
		id: id, displayName: displayName, bio: bio, avatarKey: avatarKey, status: status,
		suspendedUntil: suspendedUntil, suspendReason: suspendReason, writeID: writeID, createdAt: createdAt, updatedAt: updatedAt,
		lastActiveAt: lastActiveAt,
	}
}
```

and next to the other getters:

```go
func (a *Account) LastActiveAt() *time.Time { return a.lastActiveAt }
```

In `internal/account/repository/account_pg.go`:

```go
// accountColumns are the columns scanAccount reads.
const accountColumns = `id, coalesce(display_name, ''), coalesce(bio, ''), coalesce(avatar_key, ''), status, suspended_until,
       coalesce(suspend_reason, ''), write_id, created_at, updated_at, last_active_at`

// scanAccount reads accountColumns.
func scanAccount(row pgx.CollectableRow) (domain.Account, error) {
	var (
		id, writeID                  uuid.UUID
		name, bio, avatarKey, reason string
		status                       domain.Status
		until, lastActive            *time.Time
		createdAt, updatedAt         time.Time
	)
	if err := row.Scan(&id, &name, &bio, &avatarKey, &status, &until, &reason, &writeID, &createdAt, &updatedAt, &lastActive); err != nil {
		return domain.Account{}, fmt.Errorf("scan account: %w", err)
	}
	return domain.RestoreAccount(id, name, bio, avatarKey, status, until, reason, writeID, createdAt, updatedAt, lastActive), nil
}
```

and add the method (after `Blocked` is a good place):

```go
func (s pgAccounts) TouchActive(ctx context.Context, id uuid.UUID, at time.Time) error {
	if _, err := s.db.Exec(ctx, `
UPDATE accounts SET last_active_at = @at
WHERE id = @id AND (last_active_at IS NULL OR last_active_at < @at::timestamptz - interval '30 seconds')`,
		pgx.StrictNamedArgs{"id": id, "at": at}); err != nil {
		return fmt.Errorf("touch account: %w", err)
	}
	return nil
}
```

In the `Accounts` interface of `internal/account/repository/account.go`:

```go
	// TouchActive sets last_active_at to at unless it is less than 30
	// seconds older, so devices of one account do not pile up writes. It
	// leaves write_id alone: it is no change of the aggregate's.
	TouchActive(ctx context.Context, id uuid.UUID, at time.Time) error
```

- [ ] **Step 4: Service and views**

In the `Service` interface of `internal/account/service/service.go`, after `Suspended`:

```go
	// Touch records that the person has the app open now.
	Touch(ctx context.Context, id uuid.UUID) error
```

Create `internal/account/service/account_touch.go`:

```go
package service

import (
	"context"
	"fmt"
	"uuid"
)

func (s *Account) Touch(ctx context.Context, id uuid.UUID) error {
	if err := s.accounts.TouchActive(ctx, id, s.now()); err != nil {
		return fmt.Errorf("touch: %w", err)
	}
	return nil
}
```

In `internal/account/service/views.go`, `AccountView` gains:

```go
	// LastActiveAt is not in the Account schema; views that show whether a
	// person is around copy it.
	LastActiveAt *time.Time `json:"-"`
```

and `view` sets it: `v := AccountView{ID: a.ID(), DisplayName: a.DisplayName(), Bio: a.Bio(), Status: a.Status(now), CreatedAt: a.CreatedAt(), LastActiveAt: a.LastActiveAt()}`.

In `internal/chat/service/views.go`:

```go
type PersonView struct {
	ID           uuid.UUID  `json:"id"`
	DisplayName  string     `json:"display_name"`
	AvatarURL    string     `json:"avatar_url,omitempty"`
	LastActiveAt *time.Time `json:"last_active_at,omitempty"`
}
```

(add `"time"` to its imports if missing). In `internal/chat/service/conversation_get.go` both `PersonView{…}` literals gain `LastActiveAt: other.LastActiveAt`.

In `internal/screen/service/seller.go`, `SellerProfile` gains `LastActiveAt *time.Time \`json:"last_active_at,omitempty"\`` after `JoinedAt`, and the `SellerProfile{…}` literal in `Seller` sets `LastActiveAt: seller.LastActiveAt`.

- [ ] **Step 5: The schemas**

In `api/schemas/chat.yaml`, `Person.properties` gains:

```yaml
    last_active_at:
      type: string
      format: date-time
      description: |
        When the person last had the app open, to the 30 seconds; absent
        before the first time. The app shows "Đang hoạt động" under 5
        minutes, otherwise how long ago.
```

In `api/schemas/screen_listing.yaml`, `SellerProfile.properties` gains the same property with the same description.

- [ ] **Step 6: Run the tests**

Run: `go test -race ./internal/account/... ./internal/chat/... ./internal/screen/... ./api/ -count=1`
Expected: PASS.

- [ ] **Step 7: Lint and commit**

Run: `golangci-lint run ./...`
Expected: no issues.

```bash
git add internal/account internal/chat internal/screen api/schemas
git commit -m "feat(account): last_active_at, shown in the chat views and on the seller page"
```

---

### Task 5: What the socket needs from the modules

The token's expiry in the principal, a verifier the socket can call, and chat's `Peer` for typing.

**Files:**
- Modify: `internal/platform/authn/authn.go` (Principal.ExpiresAt)
- Modify: `internal/account/domain/token.go:90-130` (Verify fills it)
- Modify: `internal/account/account.go` (TokenVerifier)
- Modify: `internal/chat/service/service.go` (interface), `internal/chat/service/conversation_get.go` (Peer)
- Test: `internal/account/domain/token_test.go`, `internal/chat/service/chat_test.go`

**Interfaces:**
- Produces:
  - `authn.Principal.ExpiresAt time.Time`
  - `account.TokenVerifier(keys config.AuthConfig) func(token string, now time.Time) (authn.Principal, error)`
  - `chatsvc.Service.Peer(ctx context.Context, account, conversation uuid.UUID) (other uuid.UUID, ok bool, err error)`

- [ ] **Step 1: Write the failing tests**

In `internal/account/domain/token_test.go`, `TestSignThenVerify` checks the expiry too; change its last condition to:

```go
	if err != nil || p.AccountID != acc || p.SessionID != sid || !p.AuthTime.Equal(authTime) || !p.ExpiresAt.Equal(exp) {
		t.Fatalf("%+v %v", p, err)
	}
```

Append to `internal/chat/service/chat_test.go`:

```go
func TestPeer(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	seller, buyer := e.person(t), e.person(t)
	c := e.open(t, buyer, catalogtest.Listing(t, e.db, seller), "Còn không?")
	if other, ok, err := e.chat.Peer(ctx, seller, c.ID); err != nil || !ok || other != buyer {
		t.Fatalf("member: %s %v %v", other, ok, err)
	}
	if _, ok, err := e.chat.Peer(ctx, e.person(t), c.ID); err != nil || ok {
		t.Fatalf("stranger: %v %v", ok, err)
	}
	if _, ok, err := e.chat.Peer(ctx, seller, uuid.NewV7()); err != nil || ok {
		t.Fatalf("unknown conversation: %v %v", ok, err)
	}
	if err := e.accounts.Block(ctx, seller, buyer); err != nil {
		t.Fatal(err)
	}
	if _, ok, err := e.chat.Peer(ctx, buyer, c.ID); err != nil || ok {
		t.Fatalf("blocked: %v %v", ok, err)
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./internal/account/domain/ ./internal/chat/service/ -run 'TestSignThenVerify|TestPeer' -count=1`
Expected: FAIL to compile: `p.ExpiresAt undefined`, `e.chat.Peer undefined`.

- [ ] **Step 3: Implement**

In `internal/platform/authn/authn.go`, `Principal` gains:

```go
	// ExpiresAt is when the access token stops being valid; a WebSocket
	// closes then unless the app sends a newer token.
	ExpiresAt time.Time
```

In `internal/account/domain/token.go`, the last line of `Verify` becomes:

```go
	return authn.Principal{
		AccountID: sub, SessionID: sid, AuthTime: time.Unix(c.AuthTime, 0).UTC(), ExpiresAt: c.ExpiresAt.UTC(),
	}, nil
```

(`c.ExpiresAt` is a `*jwt.NumericDate`, non-nil since `jwt.WithExpirationRequired()`; its embedded `time.Time` gives `.UTC()`.)

In `internal/account/account.go`, after `Guards`:

```go
// TokenVerifier checks a customer access token as Protect does. The
// WebSocket checks with it the tokens a connection renews itself with.
func TokenVerifier(keys config.AuthConfig) func(token string, now time.Time) (authn.Principal, error) {
	return domain.NewVerifier(keys).Verify
}
```

(add imports `time` and `github.com/shopnexus/server/internal/platform/authn` if missing).

In the `Service` interface of `internal/chat/service/service.go`, after `ConversationWith`:

```go
	// Peer returns the other member of conversation when account is a
	// member and neither blocks the other; ok is false otherwise, and for an
	// unknown conversation.
	Peer(ctx context.Context, account, conversation uuid.UUID) (other uuid.UUID, ok bool, err error)
```

In `internal/chat/service/conversation_get.go`:

```go
func (c *Chat) Peer(ctx context.Context, account, conversation uuid.UUID) (uuid.UUID, bool, error) {
	conv, err := c.chats.Get(ctx, conversation)
	if errors.Is(err, repository.ErrNotFound) {
		return uuid.UUID{}, false, nil
	}
	if err != nil {
		return uuid.UUID{}, false, fmt.Errorf("get conversation: %w", err)
	}
	if !conv.Has(account) {
		return uuid.UUID{}, false, nil
	}
	other := conv.Other(account)
	blocked, err := c.accounts.Blocked(ctx, account, other)
	if err != nil {
		return uuid.UUID{}, false, fmt.Errorf("check block: %w", err)
	}
	if blocked {
		return uuid.UUID{}, false, nil
	}
	return other, true, nil
}
```

- [ ] **Step 4: Run the tests**

Run: `go test -race ./internal/platform/authn/ ./internal/account/... ./internal/chat/... ./internal/notification/... -count=1`
Expected: PASS (the notification worker's fake embeds `chatsvc.Service`, so the new method needs nothing there).

- [ ] **Step 5: Lint and commit**

Run: `golangci-lint run ./...`
Expected: no issues.

```bash
git add internal/platform/authn internal/account internal/chat
git commit -m "feat: the principal carries its expiry; chat answers who a typing member types to"
```

---

### Task 6: The socket and `/v1/updates`

**Files:**
- Modify: `go.mod`, `go.sum` (`github.com/coder/websocket`)
- Create: `internal/platform/stream/socket.go`
- Modify: `internal/platform/httpx/middleware.go` (statusWriter.Hijack)
- Test: `internal/platform/stream/socket_test.go`, `internal/platform/httpx/middleware_test.go`

**Interfaces:**
- Consumes: `Hub`, `Sub`, `Event` (Task 3); `UpdateLog`, `Page`, `Update`, `PGLog`, `PGBell`, `Notify` (Tasks 1–2); `authn.Principal.ExpiresAt` (Task 5).
- Produces:
  - `stream.Access` interface: `Suspended(ctx, account) (bool, error)`; `Peer(ctx, account, conversation) (uuid.UUID, bool, error)`; `Touch(ctx, account) error`
  - `stream.Socket{Hub *Hub; Updates UpdateLog; Access Access; Verify func(string, time.Time) (authn.Principal, error); Now func() time.Time; Log *slog.Logger}` implementing `http.Handler`
  - `stream.UpdatesHandler(updates UpdateLog, log *slog.Logger) http.Handler`
  - `stream.CloseToken` (4001), `stream.CloseSuspended` (4003), both `websocket.StatusCode`

- [ ] **Step 1: Add the library**

Run: `go get github.com/coder/websocket@latest`
Expected: `go.mod` gains `github.com/coder/websocket vX.Y.Z` (the newest release).

- [ ] **Step 2: Write the failing tests**

Create `internal/platform/stream/socket_test.go`:

```go
package stream_test

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
	"uuid"

	"github.com/coder/websocket"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/shopnexus/server/internal/platform/authn"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server/internal/platform/stream"
)

type fakeAccess struct {
	mu        sync.Mutex
	suspended map[uuid.UUID]bool
	peers     map[uuid.UUID]uuid.UUID // conversation → whom typing there reaches
	touched   map[uuid.UUID]int
}

func (f *fakeAccess) Suspended(_ context.Context, account uuid.UUID) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.suspended[account], nil
}

func (f *fakeAccess) Peer(_ context.Context, _, conversation uuid.UUID) (uuid.UUID, bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	to, ok := f.peers[conversation]
	return to, ok, nil
}

func (f *fakeAccess) Touch(_ context.Context, account uuid.UUID) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.touched[account]++
	return nil
}

func (f *fakeAccess) touches(account uuid.UUID) int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.touched[account]
}

func (f *fakeAccess) suspend(account uuid.UUID) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.suspended[account] = true
}

// socketEnv serves a Socket on a fresh database. A request's bearer token
// names a principal the test registered with token.
type socketEnv struct {
	db     *pgxpool.Pool
	hub    *stream.Hub
	access *fakeAccess
	url    string
	mu     sync.Mutex
	tokens map[string]authn.Principal
}

func newSocketEnv(t *testing.T) *socketEnv {
	t.Helper()
	db := pgtest.New(t)
	e := &socketEnv{
		db: db, tokens: map[string]authn.Principal{},
		access: &fakeAccess{suspended: map[uuid.UUID]bool{}, peers: map[uuid.UUID]uuid.UUID{}, touched: map[uuid.UUID]int{}},
	}
	e.hub = stream.NewHub(stream.PGBell{DB: db, Log: discard}, stream.PGLog{DB: db}, time.Now, discard)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		_ = e.hub.Run(ctx)
		close(done)
	}()
	verify := func(tok string, _ time.Time) (authn.Principal, error) {
		e.mu.Lock()
		defer e.mu.Unlock()
		p, ok := e.tokens[tok]
		if !ok {
			return authn.Principal{}, errors.New("unknown token")
		}
		return p, nil
	}
	socket := stream.Socket{Hub: e.hub, Updates: stream.PGLog{DB: db}, Access: e.access, Verify: verify, Now: time.Now, Log: discard}
	updates := stream.UpdatesHandler(stream.PGLog{DB: db}, discard)
	srv := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p, err := verify(strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer "), time.Now())
		if err != nil {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		r = r.WithContext(authn.With(r.Context(), p))
		if r.URL.Path == "/updates" {
			updates.ServeHTTP(w, r)
			return
		}
		socket.ServeHTTP(w, r)
	}))
	// Shorter than the tests wait, so a socket that kept them would end.
	srv.Config.ReadTimeout, srv.Config.WriteTimeout = time.Second, time.Second
	srv.Start()
	t.Cleanup(func() {
		srv.CloseClientConnections()
		srv.Close()
		cancel()
		<-done
	})
	e.url = srv.URL
	return e
}

// token registers a principal for account valid for ttl and returns its
// token.
func (e *socketEnv) token(account uuid.UUID, ttl time.Duration) string {
	e.mu.Lock()
	defer e.mu.Unlock()
	tok := uuid.NewV7().String()
	e.tokens[tok] = authn.Principal{AccountID: account, ExpiresAt: time.Now().Add(ttl)}
	return tok
}

func (e *socketEnv) notify(t *testing.T, account uuid.UUID, n int) {
	t.Helper()
	err := pgx.BeginFunc(context.Background(), e.db, func(tx pgx.Tx) error {
		for range n {
			if err := stream.Notify(context.Background(), tx, []uuid.UUID{account}, dealHint()); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

type frame struct {
	Type           string     `json:"type"`
	Seq            int64      `json:"seq"`
	Kind           string     `json:"kind"`
	ConversationID *uuid.UUID `json:"conversation_id"`
	DealID         *uuid.UUID `json:"deal_id"`
}

type client struct {
	conn   *websocket.Conn
	frames chan frame
	err    chan error
}

// dial opens the socket as token with query ("" or "?since=N") and reads
// its frames until it closes.
func (e *socketEnv) dial(t *testing.T, token, query string) *client {
	t.Helper()
	c, _, err := websocket.Dial(context.Background(), e.url+"/ws"+query, //nolint:bodyclose // Dial closes the handshake response's body.
		&websocket.DialOptions{HTTPHeader: http.Header{"Authorization": {"Bearer " + token}}})
	if err != nil {
		t.Fatal(err)
	}
	cl := &client{conn: c, frames: make(chan frame, 1024), err: make(chan error, 1)}
	go func() {
		for {
			_, b, readErr := c.Read(context.Background())
			if readErr != nil {
				cl.err <- readErr
				close(cl.frames)
				return
			}
			var f frame
			if jsonErr := json.Unmarshal(b, &f); jsonErr != nil {
				cl.err <- jsonErr
				close(cl.frames)
				return
			}
			cl.frames <- f
		}
	}()
	t.Cleanup(func() { _ = c.CloseNow() })
	return cl
}

func (cl *client) next(t *testing.T) frame {
	t.Helper()
	select {
	case f, ok := <-cl.frames:
		if !ok {
			t.Fatalf("the socket closed: %v", <-cl.err)
		}
		return f
	case <-time.After(5 * time.Second):
		t.Fatal("no frame within 5s")
	}
	return frame{}
}

func (cl *client) quiet(t *testing.T) {
	t.Helper()
	select {
	case f, ok := <-cl.frames:
		if ok {
			t.Fatalf("an unexpected frame: %+v", f)
		}
	case <-time.After(500 * time.Millisecond):
	}
}

// closedWith waits for the socket to close and returns its close code.
func (cl *client) closedWith(t *testing.T) websocket.StatusCode {
	t.Helper()
	deadline := time.After(5 * time.Second)
	for {
		select {
		case _, ok := <-cl.frames:
			if !ok {
				return websocket.CloseStatus(<-cl.err)
			}
		case <-deadline:
			t.Fatal("the socket did not close within 5s")
		}
	}
}

func (cl *client) send(t *testing.T, v any) {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	if err = cl.conn.Write(context.Background(), websocket.MessageText, b); err != nil {
		t.Fatal(err)
	}
}

func expectFrame(t *testing.T, f frame, typ string, seq int64) {
	t.Helper()
	if f.Type != typ || f.Seq != seq {
		t.Fatalf("frame %+v, want %s %d", f, typ, seq)
	}
}

func TestSocketCatchesUpThenGoesLive(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	e.notify(t, a, 3)
	cl := e.dial(t, e.token(a, time.Hour), "?since=1")
	expectFrame(t, cl.next(t), "update", 2)
	if f := cl.next(t); f.Type != "update" || f.Seq != 3 || f.Kind != stream.KindDeal || f.DealID == nil {
		t.Fatalf("%+v", f)
	}
	expectFrame(t, cl.next(t), "ready", 3)
	time.Sleep(1500 * time.Millisecond) // past the server's read and write timeouts
	e.notify(t, a, 1)
	expectFrame(t, cl.next(t), "update", 4)
	if e.access.touches(a) == 0 {
		t.Fatal("no touch at connect")
	}
}

func TestSocketWithoutSinceStartsNow(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	e.notify(t, a, 2)
	cl := e.dial(t, e.token(a, time.Hour), "")
	expectFrame(t, cl.next(t), "ready", 2)
	e.notify(t, a, 1)
	expectFrame(t, cl.next(t), "update", 3)
}

func TestSocketResetsASinceAheadOfTheLog(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	e.notify(t, a, 2)
	cl := e.dial(t, e.token(a, time.Hour), "?since=9")
	expectFrame(t, cl.next(t), "reset", 2)
	expectFrame(t, cl.next(t), "ready", 2)
}

func TestSocketPagesThroughALongBacklog(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	e.notify(t, a, 501)
	cl := e.dial(t, e.token(a, time.Hour), "?since=0")
	for seq := int64(1); seq <= 501; seq++ {
		expectFrame(t, cl.next(t), "update", seq)
	}
	expectFrame(t, cl.next(t), "ready", 501)
}

// Updates rung while the socket catches up reach it once each, in order.
func TestSocketSendsNoDuplicates(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	e.notify(t, a, 50)
	cl := e.dial(t, e.token(a, time.Hour), "?since=0")
	for range 20 {
		e.notify(t, a, 1)
	}
	want := int64(1)
	for want <= 70 {
		f := cl.next(t)
		if f.Type == "ready" {
			continue
		}
		expectFrame(t, f, "update", want)
		want++
	}
	cl.quiet(t)
}

func TestTwoDevicesBothGetUpdates(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	phone := e.dial(t, e.token(a, time.Hour), "")
	tablet := e.dial(t, e.token(a, time.Hour), "")
	expectFrame(t, phone.next(t), "ready", 0)
	expectFrame(t, tablet.next(t), "ready", 0)
	e.notify(t, a, 1)
	expectFrame(t, phone.next(t), "update", 1)
	expectFrame(t, tablet.next(t), "update", 1)
}

func TestTyping(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a, b := uuid.NewV7(), uuid.NewV7()
	conv := uuid.NewV7()
	e.access.mu.Lock()
	e.access.peers[conv] = b
	e.access.mu.Unlock()
	typist := e.dial(t, e.token(a, time.Hour), "")
	reader := e.dial(t, e.token(b, time.Hour), "")
	expectFrame(t, typist.next(t), "ready", 0)
	expectFrame(t, reader.next(t), "ready", 0)
	typist.send(t, map[string]any{"type": "typing", "conversation_id": conv})
	typist.send(t, map[string]any{"type": "typing", "conversation_id": conv}) // within 3 s: dropped
	if f := reader.next(t); f.Type != "typing" || f.ConversationID == nil || *f.ConversationID != conv {
		t.Fatalf("%+v", f)
	}
	reader.quiet(t)
	typist.send(t, map[string]any{"type": "typing", "conversation_id": uuid.NewV7()}) // no peer: dropped
	reader.quiet(t)
	typist.quiet(t)
}

func TestAuthMovesTheExpiry(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	cl := e.dial(t, e.token(a, 2*time.Second), "")
	expectFrame(t, cl.next(t), "ready", 0)
	cl.send(t, map[string]any{"type": "auth", "token": e.token(a, time.Hour)})
	time.Sleep(3 * time.Second)
	e.notify(t, a, 1)
	expectFrame(t, cl.next(t), "update", 1)
	cl.send(t, map[string]any{"type": "auth", "token": e.token(uuid.NewV7(), time.Hour)})
	if code := cl.closedWith(t); code != stream.CloseToken {
		t.Fatalf("another account's token: %d", code)
	}
}

func TestExpiryCloses4001(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	cl := e.dial(t, e.token(a, time.Second), "")
	if code := cl.closedWith(t); code != stream.CloseToken {
		t.Fatalf("%d", code)
	}
	deadline := time.Now().Add(5 * time.Second)
	for e.access.touches(a) < 2 {
		if time.Now().After(deadline) {
			t.Fatal("no touch at close")
		}
		time.Sleep(20 * time.Millisecond)
	}
}

func TestSuspendedAccountCloses4003(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	e.access.suspend(a)
	cl := e.dial(t, e.token(a, time.Hour), "")
	if code := cl.closedWith(t); code != stream.CloseSuspended {
		t.Fatalf("%d", code)
	}
}

func TestSuspensionClosesAtTheNextAuth(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	cl := e.dial(t, e.token(a, time.Hour), "")
	expectFrame(t, cl.next(t), "ready", 0)
	e.access.suspend(a)
	cl.send(t, map[string]any{"type": "auth", "token": e.token(a, time.Hour)})
	if code := cl.closedWith(t); code != stream.CloseSuspended {
		t.Fatalf("%d", code)
	}
}

func TestMalformedFrameCloses1008(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	for _, c := range []struct {
		name string
		typ  websocket.MessageType
		body string
	}{
		{"not json", websocket.MessageText, "hello"},
		{"binary", websocket.MessageBinary, `{"type":"typing"}`},
		{"unknown type", websocket.MessageText, `{"type":"shout"}`},
	} {
		cl := e.dial(t, e.token(a, time.Hour), "")
		expectFrame(t, cl.next(t), "ready", 0)
		if err := cl.conn.Write(context.Background(), c.typ, []byte(c.body)); err != nil {
			t.Fatal(err)
		}
		if code := cl.closedWith(t); code != websocket.StatusPolicyViolation {
			t.Fatalf("%s: %d", c.name, code)
		}
	}
}

func TestOversizeFrameCloses1009(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	cl := e.dial(t, e.token(uuid.NewV7(), time.Hour), "")
	expectFrame(t, cl.next(t), "ready", 0)
	if err := cl.conn.Write(context.Background(), websocket.MessageText, []byte(strings.Repeat("x", 5000))); err != nil {
		t.Fatal(err)
	}
	if code := cl.closedWith(t); code != websocket.StatusMessageTooBig {
		t.Fatalf("%d", code)
	}
}

func TestHubCloseCloses1001(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	cl := e.dial(t, e.token(uuid.NewV7(), time.Hour), "")
	expectFrame(t, cl.next(t), "ready", 0)
	e.hub.Close()
	if code := cl.closedWith(t); code != websocket.StatusGoingAway {
		t.Fatalf("%d", code)
	}
}

func TestUpdatesHandler(t *testing.T) {
	t.Parallel()
	e := newSocketEnv(t)
	a := uuid.NewV7()
	e.notify(t, a, 3)
	req, err := http.NewRequestWithContext(t.Context(), http.MethodGet, e.url+"/updates?since=1", http.NoBody)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Authorization", "Bearer "+e.token(a, time.Hour))
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	var p stream.Page
	if err = json.NewDecoder(res.Body).Decode(&p); err != nil {
		t.Fatal(err)
	}
	if res.StatusCode != http.StatusOK || len(p.Updates) != 2 || p.Updates[0].Seq != 2 || p.Seq != 3 || p.Reset || p.HasMore {
		t.Fatalf("%d %+v", res.StatusCode, p)
	}
}
```

Append to `internal/platform/httpx/middleware_test.go` (adapt the logger variable to the one that file already uses for `Trace`; add imports `bufio`, `net/http/httptest` if missing):

```go
// A WebSocket library asserts http.Hijacker on the writer it gets.
func TestTraceWriterHijacks(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(httpx.Trace(slog.New(slog.DiscardHandler))(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		hj, ok := w.(http.Hijacker)
		if !ok {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		conn, rw, err := hj.Hijack()
		if err != nil {
			return
		}
		defer conn.Close()
		_, _ = rw.WriteString("HTTP/1.1 204 No Content\r\n\r\n")
		_ = rw.Flush()
	})))
	defer srv.Close()
	req, _ := http.NewRequestWithContext(t.Context(), http.MethodGet, srv.URL, http.NoBody)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusNoContent {
		t.Fatalf("%d", res.StatusCode)
	}
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `go test ./internal/platform/stream/ ./internal/platform/httpx/ -run 'TestSocket|TestTwo|TestTyping|TestAuth|TestExpiry|TestSuspen|TestMalformed|TestOversize|TestHubClose|TestUpdatesHandler|TestTraceWriterHijacks' -count=1`
Expected: FAIL to compile: `undefined: stream.Socket`, `undefined: stream.UpdatesHandler`, `undefined: stream.CloseToken`.

- [ ] **Step 4: Let the trace writer hijack**

In `internal/platform/httpx/middleware.go`, after `Unwrap` (add imports `bufio` and `net`):

```go
// Hijack hands the connection to a WebSocket, for a library that asserts
// http.Hijacker instead of going through http.ResponseController.
func (w *statusWriter) Hijack() (net.Conn, *bufio.ReadWriter, error) {
	return http.NewResponseController(w.ResponseWriter).Hijack() //nolint:wrapcheck // A ResponseWriter wrapper returns the hijack error as it is.
}
```

- [ ] **Step 5: Write the socket**

Create `internal/platform/stream/socket.go`:

```go
package stream

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"sync"
	"time"
	"uuid"

	"github.com/coder/websocket"

	"github.com/shopnexus/server/internal/platform/authn"
	"github.com/shopnexus/server/internal/platform/httpx"
)

const (
	// CloseToken ends a connection whose access token expired, is not
	// valid, or is another account's; the app refreshes and reconnects.
	CloseToken websocket.StatusCode = 4001
	// CloseSuspended ends a suspended account's connection; the app does
	// not reconnect.
	CloseSuspended websocket.StatusCode = 4003

	frameLimit  = 4 << 10
	pageSize    = 500
	pingEvery   = 25 * time.Second
	pongWithin  = 10 * time.Second
	touchEvery  = time.Minute
	typingEvery = 3 * time.Second
	peerFor     = 30 * time.Second
)

// Access is what a connection asks the modules; app adapts account and
// chat to it.
type Access interface {
	Suspended(ctx context.Context, account uuid.UUID) (bool, error)
	// Peer returns whom account's typing in conversation reaches: the other
	// member, when account is a member and neither blocks the other.
	Peer(ctx context.Context, account, conversation uuid.UUID) (other uuid.UUID, ok bool, err error)
	// Touch records that account has the app open now.
	Touch(ctx context.Context, account uuid.UUID) error
}

// Socket serves GET /v1/ws behind the auth middleware.
type Socket struct {
	Hub     *Hub
	Updates UpdateLog
	Access  Access
	// Verify checks the tokens a connection renews itself with, as the auth
	// middleware checked the first.
	Verify func(token string, now time.Time) (authn.Principal, error)
	Now    func() time.Time
	Log    *slog.Logger
}

type (
	// seqFrame is ready or reset.
	seqFrame struct {
		Type string `json:"type"`
		Seq  int64  `json:"seq"`
	}
	updateFrame struct {
		Type string `json:"type"`
		Update
	}
	typingFrame struct {
		Type           string     `json:"type"`
		ConversationID *uuid.UUID `json:"conversation_id"`
	}
	// clientFrame is a frame from the app: typing or auth.
	clientFrame struct {
		Type           string     `json:"type"`
		ConversationID *uuid.UUID `json:"conversation_id"`
		Token          string     `json:"token"`
	}
	// peer is an answer of Access.Peer, kept for peerFor.
	peer struct {
		to uuid.UUID
		ok bool
		at time.Time
	}
)

// ServeHTTP upgrades the request and sends the caller's updates after
// since, or none without since, then ready with the seq the app is at, then
// each update and typing frame as it comes, until the app leaves, its token
// expires, or the hub closes.
func (s Socket) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, s.Log)
	if !ok {
		return
	}
	ctx := r.Context()
	since := int64(-1) // the validator allows only 0 and up
	if q := r.URL.Query().Get("since"); q != "" {
		v, err := strconv.ParseInt(q, 10, 64)
		if err != nil {
			httpx.WriteError(w, r, s.Log, fmt.Errorf("parse since: %w", err))
			return
		}
		since = v
	}
	suspended, err := s.Access.Suspended(ctx, p.AccountID)
	if err != nil {
		httpx.WriteError(w, r, s.Log, fmt.Errorf("check suspension: %w", err))
		return
	}
	// The server's read and write timeouts would end the connection.
	rc := http.NewResponseController(w)
	if err = errors.Join(rc.SetReadDeadline(time.Time{}), rc.SetWriteDeadline(time.Time{})); err != nil {
		httpx.WriteError(w, r, s.Log, fmt.Errorf("clear the deadlines: %w", err))
		return
	}
	var workers sync.WaitGroup
	defer workers.Wait()
	c, err := websocket.Accept(w, r, nil)
	if err != nil {
		s.Log.WarnContext(ctx, "stream: accept the websocket", "err", err)
		return
	}
	defer func() { _ = c.CloseNow() }()
	if suspended {
		_ = c.Close(CloseSuspended, "account_suspended")
		return
	}
	c.SetReadLimit(frameLimit)
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	sub, stop := s.Hub.Subscribe(p.AccountID)
	defer stop()

	write := func(v any) bool {
		b, err := json.Marshal(v)
		if err != nil {
			s.Log.ErrorContext(ctx, "stream: encode a frame", "err", err)
			return false
		}
		return c.Write(ctx, websocket.MessageText, b) == nil
	}
	last := since
	// catchUp sends the log after last, page by page, or reset with the
	// current seq when the log no longer holds what follows last.
	catchUp := func() bool {
		for {
			page, err := s.Updates.Since(ctx, p.AccountID, last, pageSize)
			if err != nil {
				if ctx.Err() == nil {
					s.Log.WarnContext(ctx, "stream: read the update log", "err", err)
				}
				return false
			}
			if page.Reset {
				last = page.Seq
				return write(seqFrame{Type: "reset", Seq: page.Seq})
			}
			for _, u := range page.Updates {
				if !write(updateFrame{Type: "update", Update: u}) {
					return false
				}
				last = u.Seq
			}
			if !page.HasMore {
				return true
			}
		}
	}
	if since < 0 {
		if last, err = s.Updates.Current(ctx, p.AccountID); err != nil {
			s.Log.WarnContext(ctx, "stream: read the current seq", "err", err)
			return
		}
	} else if !catchUp() {
		return
	}
	if !write(seqFrame{Type: "ready", Seq: last}) {
		return
	}

	frames := make(chan clientFrame)
	workers.Go(func() {
		defer cancel()
		for {
			typ, b, err := c.Read(ctx)
			if err != nil {
				return
			}
			var f clientFrame
			if typ != websocket.MessageText || json.Unmarshal(b, &f) != nil {
				_ = c.Close(websocket.StatusPolicyViolation, "a frame is a JSON text message")
				return
			}
			select {
			case frames <- f:
			case <-ctx.Done():
				return
			}
		}
	})
	workers.Go(func() {
		tick := time.NewTicker(pingEvery)
		defer tick.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-tick.C:
				pingCtx, done := context.WithTimeout(ctx, pongWithin)
				err := c.Ping(pingCtx)
				done()
				if err != nil {
					cancel()
					return
				}
			}
		}
	})

	if err = s.Access.Touch(ctx, p.AccountID); err != nil {
		s.Log.WarnContext(ctx, "stream: touch", "err", err)
	}
	defer func() {
		touchCtx, done := context.WithTimeout(context.WithoutCancel(ctx), time.Second)
		defer done()
		if err := s.Access.Touch(touchCtx, p.AccountID); err != nil {
			s.Log.WarnContext(touchCtx, "stream: touch", "err", err)
		}
	}()
	expiry := time.NewTimer(p.ExpiresAt.Sub(s.Now()))
	defer expiry.Stop()
	touch := time.NewTicker(touchEvery)
	defer touch.Stop()
	typed := map[uuid.UUID]time.Time{}
	peers := map[uuid.UUID]peer{}
	for {
		select {
		case <-ctx.Done():
			return
		case <-s.Hub.Done():
			_ = c.Close(websocket.StatusGoingAway, "server shutting down")
			return
		case <-expiry.C:
			_ = c.Close(CloseToken, "token_expired")
			return
		case <-touch.C:
			if err = s.Access.Touch(ctx, p.AccountID); err != nil && ctx.Err() == nil {
				s.Log.WarnContext(ctx, "stream: touch", "err", err)
			}
		case <-sub.Behind():
			if !catchUp() {
				return
			}
		case ev := <-sub.Events():
			switch {
			case ev.Seq == 0:
				if !write(typingFrame{Type: KindTyping, ConversationID: ev.Hint.ConversationID}) {
					return
				}
			case ev.Seq <= last:
				// A catch-up sent it already.
			case ev.Seq > last+1:
				// A hole: the log holds the updates between, and this one.
				if !catchUp() {
					return
				}
			default:
				if !write(updateFrame{Type: "update", Update: Update{Seq: ev.Seq, Hint: ev.Hint}}) {
					return
				}
				last = ev.Seq
			}
		case f := <-frames:
			switch f.Type {
			case KindTyping:
				now := s.Now()
				if f.ConversationID == nil || now.Sub(typed[*f.ConversationID]) < typingEvery {
					continue
				}
				conv := *f.ConversationID
				typed[conv] = now
				pr, cached := peers[conv]
				if !cached || now.Sub(pr.at) >= peerFor {
					to, allowed, peerErr := s.Access.Peer(ctx, p.AccountID, conv)
					if peerErr != nil {
						s.Log.WarnContext(ctx, "stream: find whom typing reaches", "err", peerErr)
						continue
					}
					pr = peer{to: to, ok: allowed, at: now}
					peers[conv] = pr
				}
				if pr.ok {
					if err = s.Hub.Typing(ctx, pr.to, conv); err != nil {
						s.Log.WarnContext(ctx, "stream: ring typing", "err", err)
					}
				}
			case "auth":
				next, verifyErr := s.Verify(f.Token, s.Now())
				if verifyErr != nil || next.AccountID != p.AccountID {
					_ = c.Close(CloseToken, "invalid_token")
					return
				}
				if suspended, err = s.Access.Suspended(ctx, p.AccountID); err != nil {
					s.Log.WarnContext(ctx, "stream: check suspension", "err", err)
					return
				}
				if suspended {
					_ = c.Close(CloseSuspended, "account_suspended")
					return
				}
				expiry.Reset(next.ExpiresAt.Sub(s.Now()))
			default:
				_ = c.Close(websocket.StatusPolicyViolation, "unknown frame type")
				return
			}
		}
	}
}

// UpdatesHandler serves GET /v1/updates: the caller's log after since, as
// the socket sends it on connect, for an app with no socket open.
func UpdatesHandler(updates UpdateLog, log *slog.Logger) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		p, ok := httpx.Caller(w, r, log)
		if !ok {
			return
		}
		var since int64
		if q := r.URL.Query().Get("since"); q != "" {
			v, err := strconv.ParseInt(q, 10, 64)
			if err != nil {
				httpx.WriteError(w, r, log, fmt.Errorf("parse since: %w", err))
				return
			}
			since = v
		}
		page, err := updates.Since(r.Context(), p.AccountID, since, pageSize)
		if err != nil {
			httpx.WriteError(w, r, log, fmt.Errorf("read the update log: %w", err))
			return
		}
		httpx.Respond(w, http.StatusOK, page)
	})
}
```

Notes for the implementer:
- `defer workers.Wait()` is registered before `defer c.CloseNow()` and `defer cancel()`, so on return the order is: cancel, close, wait. The reader and the pinger both end once the connection is closed.
- `coder/websocket` allows `Close` from one goroutine while another reads; the reader's `Read` then returns the close error.
- When the read limit (4 KB) is passed, `coder/websocket` closes with 1009 itself; the reader sees an error and returns.
- If `golangci-lint` reports this handler for length or complexity, keep it top to bottom (the repo's rule) and add a `//nolint:<linter> // A handler reads top to bottom; see CLAUDE.md.` on the `func` line instead of splitting it.

- [ ] **Step 6: Run the tests**

Run: `go test -race ./internal/platform/stream/ ./internal/platform/httpx/ -count=1`
Expected: PASS.

- [ ] **Step 7: Lint and commit**

Run: `go mod tidy && golangci-lint run ./...`
Expected: no issues.

```bash
git add go.mod go.sum internal/platform/stream internal/platform/httpx
git commit -m "feat(stream): the WebSocket, with catch-up from the log, typing and token renewal; GET /v1/updates"
```

---

### Task 7: Wiring, the API, e2e and ARCHITECTURE.md

**Files:**
- Create: `internal/app/socket_access.go`
- Modify: `internal/app/app.go` (`mountModules`: the two routes)
- Create: `api/paths/stream.yaml`, `api/schemas/stream.yaml`
- Modify: `api/openapi.yaml` (two paths)
- Create: `e2e/socket_test.go`
- Modify: `e2e/chat_test.go` (`TestChat` reads the socket again)
- Modify: `ARCHITECTURE.md` (section Stream, and the mention of streams under App)

**Interfaces:**
- Consumes: `stream.Socket`, `stream.UpdatesHandler`, `stream.PGLog`, `stream.CloseToken` (Task 6); `account.TokenVerifier`, `accountsvc.Service.Touch`, `chatsvc.Service.Peer` (Tasks 4–5).
- Produces: routes `GET /v1/ws` (operationId `openSocket`) and `GET /v1/updates` (operationId `listUpdates`).

- [ ] **Step 1: Write the failing e2e tests**

Create `e2e/socket_test.go`:

```go
package e2e

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"testing"
	"time"

	"github.com/coder/websocket"

	"github.com/shopnexus/server/internal/platform/testenv"
)

type socketFrame struct {
	Type           string `json:"type"`
	Seq            int64  `json:"seq"`
	Kind           string `json:"kind"`
	ConversationID string `json:"conversation_id"`
	MessageID      string `json:"message_id"`
	DealID         string `json:"deal_id"`
}

type updatePage struct {
	Updates []socketFrame `json:"updates"`
	Seq     int64         `json:"seq"`
	Reset   bool          `json:"reset"`
	HasMore bool          `json:"has_more"`
}

type socket struct {
	conn   *websocket.Conn
	frames chan socketFrame
}

// openSocket opens /v1/ws as token with query, records the status for the
// coverage check, and reads frames until the test ends.
func openSocket(t *testing.T, token, query string) *socket {
	t.Helper()
	conn, res, err := websocket.Dial(t.Context(), server+"/v1/ws"+query, //nolint:bodyclose // Dial closes the handshake response's body.
		&websocket.DialOptions{HTTPHeader: http.Header{"Authorization": {"Bearer " + token}}})
	if err != nil {
		t.Fatal(err)
	}
	record("openSocket", res.StatusCode)
	s := &socket{conn: conn, frames: make(chan socketFrame, 256)}
	go func() {
		defer close(s.frames)
		for {
			_, b, readErr := conn.Read(t.Context())
			if readErr != nil {
				return
			}
			var f socketFrame
			if json.Unmarshal(b, &f) == nil {
				s.frames <- f
			}
		}
	}()
	t.Cleanup(func() { _ = conn.CloseNow() })
	return s
}

func (s *socket) next(t *testing.T) socketFrame {
	t.Helper()
	select {
	case f, ok := <-s.frames:
		if !ok {
			t.Fatal("the socket closed")
		}
		return f
	case <-time.After(5 * time.Second):
		t.Fatal("no frame within 5s")
	}
	return socketFrame{}
}

// ready reads frames up to ready and returns them, ready last.
func (s *socket) ready(t *testing.T) []socketFrame {
	t.Helper()
	var out []socketFrame
	for {
		f := s.next(t)
		out = append(out, f)
		if f.Type == "ready" {
			return out
		}
	}
}

// waitFrame reads frames for up to 5 s until one of typ and kind naming id.
func (s *socket) waitFrame(t *testing.T, typ, kind, id string) socketFrame {
	t.Helper()
	var got socketFrame
	testenv.Eventually(t, 5*time.Second, func() error {
		got = s.next(t)
		if got.Type != typ || got.Kind != kind || (got.ConversationID != id && got.DealID != id && got.MessageID != id) {
			return fmt.Errorf("frame %+v, want %s %s for %s", got, typ, kind, id)
		}
		return nil
	})
	return got
}

func TestSocketGetsADealUpdate(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	s := openSocket(t, seller.AccessToken, "")
	s.ready(t)
	d := openDeal(t, buyer.AccessToken, l.ID, http.StatusCreated)
	moved(t, buyer.AccessToken, d.ID, "offer", map[string]any{"amount": 1_000_000})
	s.waitFrame(t, "update", "deal", d.ID)
	expectStatus(t, call(t, "GET", "/v1/ws", nil), http.StatusUnauthorized)
}

// The seller misses three messages while offline and gets exactly them,
// in seq order, when the socket comes back with since.
func TestSocketCatchesUpAfterAReconnect(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	first := openSocket(t, seller.AccessToken, "")
	at := first.ready(t)[0].Seq
	_ = first.conn.Close(websocket.StatusNormalClosure, "")

	c := openChat(t, buyer.AccessToken, l.ID, "Còn không bạn?")
	sent := map[string]bool{chatMessages(t, buyer.AccessToken, c.ID)[0].ID: true}
	sent[sendChat(t, buyer.AccessToken, c.ID, map[string]any{"text": "Giá bao nhiêu?"}).ID] = true
	sent[sendChat(t, buyer.AccessToken, c.ID, map[string]any{"text": "Mình lấy nhé"}).ID] = true

	frames := openSocket(t, seller.AccessToken, "?since="+strconv.FormatInt(at, 10)).ready(t)
	got := map[string]bool{}
	want := at + 1
	for _, f := range frames[:len(frames)-1] {
		if f.Type != "update" || f.Seq != want {
			t.Fatalf("frame %+v, want update %d", f, want)
		}
		want++
		if f.Kind == "message" && f.ConversationID == c.ID {
			got[f.MessageID] = true
		}
	}
	if ready := frames[len(frames)-1]; ready.Seq != want-1 {
		t.Fatalf("ready %+v after %d", ready, want-1)
	}
	if len(got) != 3 {
		t.Fatalf("message updates %v, sent %v", got, sent)
	}
	for id := range sent {
		if !got[id] {
			t.Fatalf("message %s missing from %v", id, got)
		}
	}
}

func TestSocketTypingAndActivity(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	c := openChat(t, buyer.AccessToken, l.ID, "Còn không bạn?")
	reader := openSocket(t, buyer.AccessToken, "")
	reader.ready(t)
	typist := openSocket(t, seller.AccessToken, "")
	typist.ready(t)
	b, _ := json.Marshal(map[string]any{"type": "typing", "conversation_id": c.ID})
	if err := typist.conn.Write(t.Context(), websocket.MessageText, b); err != nil {
		t.Fatal(err)
	}
	testenv.Eventually(t, 5*time.Second, func() error {
		if f := reader.next(t); f.Type != "typing" || f.ConversationID != c.ID {
			return fmt.Errorf("frame %+v", f)
		}
		return nil
	})
	testenv.Eventually(t, 5*time.Second, func() error {
		var conv struct {
			Other struct {
				LastActiveAt string `json:"last_active_at"`
			} `json:"other"`
		}
		res := call(t, "GET", "/v1/conversations/"+c.ID, nil, bearer(buyer.AccessToken))
		if err := json.Unmarshal(res.Body, &conv); err != nil || conv.Other.LastActiveAt == "" {
			return fmt.Errorf("conversation %s: %v", res.Body, err)
		}
		var screen struct {
			Seller struct {
				LastActiveAt string `json:"last_active_at"`
			} `json:"seller"`
		}
		res = call(t, "GET", "/v1/screens/seller/"+seller.Account.ID, nil, bearer(buyer.AccessToken))
		if err := json.Unmarshal(res.Body, &screen); err != nil || screen.Seller.LastActiveAt == "" {
			return fmt.Errorf("seller screen %s: %v", res.Body, err)
		}
		return nil
	})
}

func TestUpdates(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	c := openChat(t, buyer.AccessToken, l.ID, "Còn không bạn?")
	testenv.Eventually(t, 5*time.Second, func() error {
		p := expect[updatePage](t, call(t, "GET", "/v1/updates?since=0", nil, bearer(seller.AccessToken)), http.StatusOK)
		for _, u := range p.Updates {
			if u.Kind == "message" && u.ConversationID == c.ID {
				return nil
			}
		}
		return fmt.Errorf("no message update in %+v", p)
	})
	expectStatus(t, call(t, "GET", "/v1/updates", nil), http.StatusUnauthorized)
}
```

In `e2e/chat_test.go`, `TestChat` reads the socket again: after `l := activeListing(…)` add

```go
	sock := openSocket(t, seller.AccessToken, "")
	sock.ready(t)
```

and after the `if c.Other.ID != seller.Account.ID { … }` block add

```go
	sock.waitFrame(t, "update", "message", c.ID)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `go test ./e2e/ -run 'TestSocket|TestUpdates|TestChat' -count=1`
Expected: FAIL: `GET /v1/ws is not in the spec` (from `callAt`), and the dial fails with 404.

- [ ] **Step 3: The API**

Create `api/paths/stream.yaml`:

```yaml
ws:
  get:
    operationId: openSocket
    summary: The WebSocket that tells the open app what changed for the caller.
    description: |
      Frames are JSON text messages of at most 4 KB. On connect the server
      sends the caller's updates after `since` (none without it), or
      `{"type":"reset","seq":N}` when the log no longer holds them, then
      `{"type":"ready","seq":N}`. After that it sends each update as
      `{"type":"update","seq":N,"kind":…,…ids}` (kinds message, read, deal,
      notification, with the IDs of the Update schema) in seq order, with
      no duplicate and no hole, and `{"type":"typing","conversation_id":…}`
      when the other member types. The app keeps the last seq and passes it
      as `since` on its next connect; after `reset` it reloads everything.

      The app sends `{"type":"typing","conversation_id":…}` (at most one in
      3 seconds per conversation reaches the other member) and, before its
      access token expires, `{"type":"auth","token":…}` with the new one.

      Close codes: 1001 server shutting down (reconnect at once); 4001 token
      expired, invalid or another account's (refresh, then reconnect); 4003
      account suspended (do not reconnect); 1008 a frame that is not JSON
      text or has an unknown type; 1009 a frame over 4 KB. The server pings
      every 25 seconds.
    tags: [stream]
    security:
      - bearerAuth: []
    parameters:
      - name: since
        in: query
        required: false
        description: The last seq the app holds. Absent means from now on.
        schema:
          type: integer
          format: int64
          minimum: 0
    responses:
      "101":
        description: Switched to the WebSocket protocol.
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
updates:
  get:
    operationId: listUpdates
    summary: The caller's updates after a seq, for an app with no socket open.
    description: |
      At most 500 updates after `since` in seq order. `reset` means the log
      no longer holds what follows `since`, or `since` is ahead of it: the
      app reloads everything and keeps `seq`.
    tags: [stream]
    security:
      - bearerAuth: []
    parameters:
      - name: since
        in: query
        required: false
        description: The last seq the app holds; absent means 0.
        schema:
          type: integer
          format: int64
          minimum: 0
    responses:
      "200":
        description: The updates.
        content:
          application/json:
            schema:
              $ref: "../schemas/stream.yaml#/UpdatePage"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
```

Create `api/schemas/stream.yaml`:

```yaml
Update:
  type: object
  additionalProperties: false
  required: [seq, kind]
  description: A change for the caller, in their update log; IDs only.
  properties:
    seq:
      type: integer
      format: int64
      minimum: 1
    kind:
      type: string
      enum: [message, read, deal, notification]
    conversation_id:
      type: string
      format: uuid
    message_id:
      type: string
      format: uuid
    deal_id:
      type: string
      format: uuid
    notification_id:
      type: string
      format: uuid
UpdatePage:
  type: object
  additionalProperties: false
  required: [updates, seq, reset, has_more]
  properties:
    updates:
      type: array
      maxItems: 500
      items:
        $ref: "#/Update"
    seq:
      type: integer
      format: int64
      minimum: 0
      description: The caller's current seq.
    reset:
      type: boolean
    has_more:
      type: boolean
      description: More updates follow the last one; ask again from its seq.
```

In `api/openapi.yaml`, where `/v1/stream` was:

```yaml
  /v1/ws:
    $ref: "paths/stream.yaml#/ws"
  /v1/updates:
    $ref: "paths/stream.yaml#/updates"
```

- [ ] **Step 4: Wire the routes**

Create `internal/app/socket_access.go`:

```go
package app

import (
	"context"
	"fmt"
	"uuid"

	accountsvc "github.com/shopnexus/server/internal/account/service"
	chatsvc "github.com/shopnexus/server/internal/chat/service"
	"github.com/shopnexus/server/internal/platform/stream"
)

// socketAccess answers the WebSocket's questions from modules account and
// chat.
type socketAccess struct {
	accounts accountsvc.Service
	chats    chatsvc.Service
}

var _ stream.Access = socketAccess{}

func (a socketAccess) Suspended(ctx context.Context, account uuid.UUID) (bool, error) {
	suspended, err := a.accounts.Suspended(ctx, account)
	if err != nil {
		return false, fmt.Errorf("check suspension: %w", err)
	}
	return suspended, nil
}

func (a socketAccess) Peer(ctx context.Context, account, conversation uuid.UUID) (uuid.UUID, bool, error) {
	other, ok, err := a.chats.Peer(ctx, account, conversation)
	if err != nil {
		return uuid.UUID{}, false, fmt.Errorf("find the peer: %w", err)
	}
	return other, ok, nil
}

func (a socketAccess) Touch(ctx context.Context, account uuid.UUID) error {
	if err := a.accounts.Touch(ctx, account); err != nil {
		return fmt.Errorf("touch: %w", err)
	}
	return nil
}
```

In `internal/app/app.go`, give `mountModules` back a `hub *stream.Hub` parameter after `bus *events.Bus`, and pass `a.hub` in the call in `New`. In `mountModules`, after `chatm := chat.Mount(...)`:

```go
	updates := stream.PGLog{DB: pool}
	router.Handle("GET /v1/ws", d.Protect(stream.Socket{
		Hub: hub, Updates: updates, Access: socketAccess{accounts: accounts, chats: chatm.Service},
		Verify: account.TokenVerifier(cfg.Auth), Now: time.Now, Log: log,
	}))
	router.Handle("GET /v1/updates", d.Protect(stream.UpdatesHandler(updates, log)))
```

- [ ] **Step 5: Run the tests**

Run: `go test -race ./internal/app/ ./api/ ./e2e/ -count=1`
Expected: PASS, the coverage check included (`openSocket 101`, `openSocket 401`, `listUpdates 200`, `listUpdates 401` observed).

- [ ] **Step 6: Record the decisions**

In `ARCHITECTURE.md`, replace the whole `### Stream` section with:

```markdown
### Stream

`GET /v1/ws` tells an open app what changed for the caller, over a
WebSocket (decided 2026-11-10; it replaced the server-sent events of
2026-10-26, which lost every hint sent across a gap and made the app reload
everything after each reconnect and deploy).

- Each account has an update log, `account_updates`, with a `seq` that
  runs 1, 2, 3 with no hole. A repository calls `stream.Notify(ctx, tx,
  accounts, hint)` in the transaction of the change: for each account, in
  UUID order so two transactions cannot deadlock, it bumps the counter in
  `account_update_seqs` and inserts the update. The counter row stays
  locked until commit and rolls back with the transaction, so a rollback
  leaves no hole and seqs become visible in order: a reader of `seq >
  since` never skips one that is still committing. The deal repository
  notifies the buyer and the seller on each save; the chat repository the
  members a message is visible to, and the other member on a read; the
  notification repository the recipient.
- An update carries IDs only (`message`, `read`, `deal`, `notification`);
  the app reloads what it shows.
- `Notify` then rings a `Bell`. `PGBell` runs `pg_notify('stream', …)` in
  the same transaction, which Postgres delivers on commit to every
  instance. The log is the truth and the ring only says something new is
  there, so a Valkey or NATS bell can replace `PGBell` without touching the
  log, the protocol or the hub.
- `stream.Hub` listens through the bell on a connection of its own and
  queues each ring for the connections of its accounts, 16 at most. A full
  queue, or a `LISTEN` connection opened again after a loss, marks a
  connection behind, and the connection reads the log from the last seq it
  sent. The hub prunes updates older than 30 days every hour, 10,000 at a
  time; `account_update_seqs` is never pruned.
- On connect, `GET /v1/ws?since=` sends the log after `since` in pages of
  500, or `reset` with the current seq when the log no longer holds what
  follows `since` or `since` is ahead of it, then `ready`. Without `since`
  it starts at the current seq. `GET /v1/updates?since=` reads the same log
  over REST for an app with no socket open.
- Typing comes up the socket, at most once per 3 seconds per connection and
  conversation. The connection asks chat's `Peer` (member, no block,
  cached 30 seconds) and rings the other member through the bell outside
  any transaction, with no update in the log. A refused frame is dropped
  in silence, so typing does not reveal a block.
- The access token lives 15 minutes. The connection closes with 4001 at
  the token's expiry unless the app sends `{"type":"auth","token":…}` with
  a newer one of the same account; a suspended account closes with 4003 at
  connect and at each `auth`. A frame that is not JSON text closes with
  1008; one over 4 KB with 1009, which the WebSocket library sends itself.
  The server pings every 25 seconds and closes when a pong takes 10.
- The handler clears its request's read and write deadlines through
  `http.ResponseController` before the upgrade, since the server's
  timeouts would end the connection.
- `http.Server.Shutdown` waits for every request, and a socket never ends
  on its own, so the server registers `App.CloseStreams` with
  `RegisterOnShutdown`. `Hub.Close` makes every connection close with 1001,
  and the apps reconnect to another instance with their seq and lose
  nothing.
- `accounts.last_active_at` is written by the socket at connect, at close
  and every minute, and not when it is under 30 seconds old; it leaves
  `write_id` alone. The chat views and the seller page show it.
- `platform/stream` reaches the modules through `stream.Access`, which
  `app` adapts from account and chat.
```

Also in `ARCHITECTURE.md`, the paragraph near the top that says "after a stream hint it reloads the view it shows in one call" stays true; change only "stream hint" to "socket update" there.

- [ ] **Step 7: Full check and commit**

Run: `make test`
Expected: every test passes and `golangci-lint` reports nothing.

```bash
git add internal/app api e2e ARCHITECTURE.md
git commit -m "feat(api): GET /v1/ws and GET /v1/updates, with the e2e checks and the architecture notes"
```
