# server2 events: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An outbox event bus inside server2: a repository writes thin events in the transaction of the change, and a dispatcher hands each to the Restate handlers subscribed to its kind.

**Architecture:** Package `internal/platform/events` holds `Kind`, `Event`, `Insert` and `Bus`. `Insert` writes a row of table `events` and a `pg_notify` in the caller's transaction. `Bus.Run` drains pending rows with `FOR UPDATE SKIP LOCKED` and sends each to every subscription through Restate's ingress with an idempotency key, then marks the rows dispatched. Module account publishes three kinds; app builds the bus, hands it to modules in `module.Deps`, and runs it.

**Tech Stack:** Go 1.27, pgx v5 (`LISTEN`/`NOTIFY`), Restate Go SDK v1.1.0 (`ingress.ServiceSend`), golangci-lint v2.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-10-26-server2-events-design.md`

## Global Constraints

- Event kinds are `aggregate.past_tense` constants of type `events.Kind`: `account.renamed`, `account.suspended`, `account.unsuspended`.
- Events are thin: `Kind`, `SubjectID`, optional `Data`; a subscriber rereads state through the source module's `Service`.
- A change, its audit entry and its events commit in one transaction; a conflicting write leaves no event.
- Idempotency key of a delivery: `<event id>/<service>/<handler>`.
- Batch 100, poll every second, keep dispatched events 7 days: constants in code.
- `Subscribe` after `Run` has started panics.
- No commits unless the user asks; each task ends on a green `make test` instead.
- Code comments and docs go through the humanizing-writing skill and its checker.

## Review Focus

1. Restate is down while events are pending: the API keeps working, the rows stay pending, and they are delivered once Restate is back (Task 2 test `TestDeliversAfterRestateReturns`).
2. An event whose kind has no subscriber: it is marked dispatched, so the pending set does not grow forever (Task 2 test `TestEventWithoutSubscriberIsMarked`).
3. Shutdown during a round: `Run` returns after its context is cancelled, and `App.Close` waits for it (Task 2 test `TestRunStopsWithItsContext`, Task 4 wiring).
4. An event with nil `Data`: it is stored as `{}` and arrives as an empty map, not null (Task 1 test `TestInsertStoresEmptyData`).
5. The `LISTEN` connection fails (Postgres restart): the dispatcher keeps polling every second and listens again (Task 2: `listen` loops with a one-second pause; the poll test `TestDeliversWithoutNotify` proves delivery without a notification).

---

### Task 1: events table and Insert

**Files:**
- Create: `migrations/0004_events.sql`
- Create: `internal/platform/events/events.go`
- Test: `internal/platform/events/events_test.go`

**Interfaces:**
- Produces:
  ```go
  type Kind string
  const (
      AccountRenamed     Kind = "account.renamed"
      AccountSuspended   Kind = "account.suspended"
      AccountUnsuspended Kind = "account.unsuspended"
  )
  type Event struct {
      ID        uuid.UUID      `json:"id"`
      Kind      Kind           `json:"kind"`
      SubjectID uuid.UUID      `json:"subject_id"`
      Data      map[string]any `json:"data"`
      At        time.Time      `json:"at"`
  }
  func Insert(ctx context.Context, tx pgx.Tx, e Event) error
  ```

- [ ] **Step 1: Write the failing tests** (`events_test.go`, package `events_test`):

  ```go
  var at = time.Date(2026, 10, 26, 9, 0, 0, 0, time.UTC)

  func insert(t *testing.T, db *pgxpool.Pool, e events.Event) error {
      t.Helper()
      return pgx.BeginFunc(context.Background(), db, func(tx pgx.Tx) error { return events.Insert(context.Background(), tx, e) })
  }

  func TestInsertCommitsWithItsTransaction(t *testing.T) {
      t.Parallel()
      db := pgtest.New(t)
      ctx := context.Background()
      e := events.Event{ID: uuid.NewV7(), Kind: events.AccountRenamed, SubjectID: uuid.NewV7(), At: at}
      rollback := errors.New("roll back")
      if err := pgx.BeginFunc(ctx, db, func(tx pgx.Tx) error {
          if err := events.Insert(ctx, tx, e); err != nil {
              return err
          }
          return rollback
      }); !errors.Is(err, rollback) {
          t.Fatal(err)
      }
      var n int
      if err := db.QueryRow(ctx, `SELECT count(*) FROM events`).Scan(&n); err != nil || n != 0 {
          t.Fatalf("after rollback: %d %v", n, err)
      }
      conn, err := db.Acquire(ctx)
      if err != nil {
          t.Fatal(err)
      }
      defer conn.Release()
      if _, err = conn.Exec(ctx, "LISTEN events"); err != nil {
          t.Fatal(err)
      }
      if err = insert(t, db, e); err != nil {
          t.Fatal(err)
      }
      wait, cancel := context.WithTimeout(ctx, 5*time.Second)
      defer cancel()
      if _, err = conn.Conn().WaitForNotification(wait); err != nil {
          t.Fatalf("no notification after commit: %v", err)
      }
      var kind string
      if err = db.QueryRow(ctx, `SELECT kind FROM events WHERE id = @id AND dispatched_at IS NULL`, pgx.StrictNamedArgs{"id": e.ID}).Scan(&kind); err != nil || kind != "account.renamed" {
          t.Fatalf("%q %v", kind, err)
      }
  }

  // A nil Data is stored as {} and arrives as an empty map.
  func TestInsertStoresEmptyData(t *testing.T) {
      t.Parallel()
      db := pgtest.New(t)
      e := events.Event{ID: uuid.NewV7(), Kind: events.AccountSuspended, SubjectID: uuid.NewV7(), At: at}
      if err := insert(t, db, e); err != nil {
          t.Fatal(err)
      }
      var data string
      if err := db.QueryRow(context.Background(), `SELECT data::text FROM events`).Scan(&data); err != nil || data != "{}" {
          t.Fatalf("%q %v", data, err)
      }
  }
  ```

- [ ] **Step 2: Run.** `go test ./internal/platform/events/` fails to compile: package `events` does not exist.

- [ ] **Step 3: Migration** `migrations/0004_events.sql`:

  ```sql
  -- events is the outbox: a repository writes a row in the transaction of
  -- the change, and events.Bus hands it to Restate. Rows are thin; a
  -- subscriber rereads the subject's current state.
  CREATE TABLE events (
      id            uuid PRIMARY KEY,
      kind          text NOT NULL,
      subject_id    uuid NOT NULL,
      data          jsonb NOT NULL,
      at            timestamptz NOT NULL,
      dispatched_at timestamptz
  );
  CREATE INDEX events_pending ON events (id) WHERE dispatched_at IS NULL;
  ```

  Check the style of `0003_staff.sql` (comment form, sqlfluff config in `.sqlfluff`) and match it.

- [ ] **Step 4: Package** `internal/platform/events/events.go`:

  ```go
  // Package events is server2's outbox. A repository writes an Event with
  // Insert in the transaction of the change it announces; Bus hands it to
  // the Restate handlers subscribed to its kind.
  package events

  // Kind is what happened, in the form aggregate.past_tense.
  type Kind string

  const (
      AccountRenamed     Kind = "account.renamed"
      AccountSuspended   Kind = "account.suspended"
      AccountUnsuspended Kind = "account.unsuspended"
  )

  // Event is what happened to which aggregate. It is thin: a subscriber
  // reads the subject's current state through its module's Service, so
  // order, delay and duplicates do not change the result. Data carries the
  // few fields a business event's subscribers need; it is usually empty.
  type Event struct { /* as in Interfaces */ }

  const insertEvent = `
  INSERT INTO events (id, kind, subject_id, data, at)
  VALUES (@id, @kind, @subject_id, @data, @at)`

  // Insert writes e in tx and notifies Bus, which Postgres does on commit.
  func Insert(ctx context.Context, tx pgx.Tx, e Event) error {
      data := e.Data
      if data == nil {
          data = map[string]any{}
      }
      if _, err := tx.Exec(ctx, insertEvent, pgx.StrictNamedArgs{
          "id": e.ID, "kind": e.Kind, "subject_id": e.SubjectID, "data": data, "at": e.At,
      }); err != nil {
          return fmt.Errorf("insert event: %w", err)
      }
      if _, err := tx.Exec(ctx, `SELECT pg_notify('events', '')`); err != nil {
          return fmt.Errorf("notify events: %w", err)
      }
      return nil
  }
  ```

- [ ] **Step 5: Run.** `make test` passes (the new migration lands in a fresh pgtest template); lint reports 0 issues.

### Task 2: Bus

**Files:**
- Create: `internal/platform/events/bus.go`, `internal/platform/events/metrics.go`
- Test: `internal/platform/events/bus_test.go` (package `events_test`), `internal/platform/events/bus_internal_test.go` (package `events`, for the crash test only)

**Interfaces:**
- Consumes: `Event`, `Kind`, `Insert` (Task 1).
- Produces:
  ```go
  type Bus struct { /* unexported */ }
  func NewBus(db *pgxpool.Pool, ingress *ingress.Client, now func() time.Time, log *slog.Logger) *Bus
  // Subscribe hands every event of kind to service's handler, a Restate
  // handler func(restate.Context, events.Event) error. service carries the
  // prefix. It panics once Run has started.
  func (b *Bus) Subscribe(kind Kind, service, handler string)
  // Run delivers events until ctx is done and returns nil then.
  func (b *Bus) Run(ctx context.Context) error
  ```

- [ ] **Step 1: Write the failing tests** (`bus_test.go`). A sample Restate service counts deliveries per event:

  ```go
  // inbox is a subscriber that counts the events it handled.
  type inbox struct {
      prefix string
      mu     *sync.Mutex
      got    map[uuid.UUID]int
  }

  func newInbox() inbox {
      return inbox{prefix: restatetest.Prefix(), mu: &sync.Mutex{}, got: map[uuid.UUID]int{}}
  }

  func (i inbox) ServiceName() string { return i.prefix + "Inbox" }

  func (i inbox) Handle(ctx restate.Context, e events.Event) error {
      return restate.RunVoid(ctx, func(restate.RunContext) error {
          i.mu.Lock()
          defer i.mu.Unlock()
          i.got[e.ID]++
          return nil
      })
  }

  func (i inbox) count(id uuid.UUID) int {
      i.mu.Lock()
      defer i.mu.Unlock()
      return i.got[id]
  }

  // eventually fails t unless ok turns true within ten seconds.
  func eventually(t *testing.T, ok func() bool) {
      t.Helper()
      for deadline := time.Now().Add(10 * time.Second); time.Now().Before(deadline); time.Sleep(50 * time.Millisecond) {
          if ok() {
              return
          }
      }
      t.Fatal("not within 10s")
  }

  // run starts b until the test ends.
  func run(t *testing.T, b *events.Bus) {
      t.Helper()
      ctx, cancel := context.WithCancel(context.Background())
      done := make(chan struct{})
      go func() { _ = b.Run(ctx); close(done) }()
      t.Cleanup(func() { cancel(); <-done })
  }

  func publish(t *testing.T, db *pgxpool.Pool, kind events.Kind) events.Event {
      t.Helper()
      e := events.Event{ID: uuid.NewV7(), Kind: kind, SubjectID: uuid.NewV7(), At: time.Now()}
      if err := insert(t, db, e); err != nil {
          t.Fatal(err)
      }
      return e
  }

  func dispatched(t *testing.T, db *pgxpool.Pool, id uuid.UUID) bool {
      t.Helper()
      var at *time.Time
      if err := db.QueryRow(context.Background(), `SELECT dispatched_at FROM events WHERE id = @id`, pgx.StrictNamedArgs{"id": id}).Scan(&at); err != nil {
          t.Fatal(err)
      }
      return at != nil
  }

  func TestEverySubscriberGetsTheEventOnce(t *testing.T) {
      t.Parallel()
      db := pgtest.New(t)
      a, b := newInbox(), newInbox()
      in := restatetest.Start(t, restate.Reflect(a), restate.Reflect(b))
      bus := events.NewBus(db, in, time.Now, discard)
      bus.Subscribe(events.AccountSuspended, a.ServiceName(), "Handle")
      bus.Subscribe(events.AccountSuspended, b.ServiceName(), "Handle")
      run(t, bus)
      e := publish(t, db, events.AccountSuspended)
      eventually(t, func() bool { return a.count(e.ID) == 1 && b.count(e.ID) == 1 && dispatched(t, db, e.ID) })
      time.Sleep(1500 * time.Millisecond) // one more poll round
      if a.count(e.ID) != 1 || b.count(e.ID) != 1 {
          t.Fatalf("delivered %d and %d times", a.count(e.ID), b.count(e.ID))
      }
  }

  func TestTwoBusesDeliverEachEventOnce(t *testing.T) {
      t.Parallel()
      db := pgtest.New(t)
      a := newInbox()
      in := restatetest.Start(t, restate.Reflect(a))
      for range 2 {
          bus := events.NewBus(db, in, time.Now, discard)
          bus.Subscribe(events.AccountRenamed, a.ServiceName(), "Handle")
          run(t, bus)
      }
      var sent []events.Event
      for range 50 {
          sent = append(sent, publish(t, db, events.AccountRenamed))
      }
      eventually(t, func() bool {
          for _, e := range sent {
              if a.count(e.ID) == 0 {
                  return false
              }
          }
          return true
      })
      for _, e := range sent {
          if n := a.count(e.ID); n != 1 {
              t.Fatalf("%s delivered %d times", e.ID, n)
          }
      }
  }

  func TestEventWithoutSubscriberIsMarked(t *testing.T) {
      t.Parallel()
      db := pgtest.New(t)
      bus := events.NewBus(db, restatetest.Start(t), time.Now, discard)
      run(t, bus)
      e := publish(t, db, events.AccountUnsuspended)
      eventually(t, func() bool { return dispatched(t, db, e.ID) })
  }

  // With no notification, the one-second poll still delivers.
  func TestDeliversWithoutNotify(t *testing.T) {
      t.Parallel()
      db := pgtest.New(t)
      a := newInbox()
      in := restatetest.Start(t, restate.Reflect(a))
      bus := events.NewBus(db, in, time.Now, discard)
      bus.Subscribe(events.AccountRenamed, a.ServiceName(), "Handle")
      id := uuid.NewV7()
      if _, err := db.Exec(context.Background(), `INSERT INTO events (id, kind, subject_id, data, at) VALUES (@id, 'account.renamed', @id, '{}', now())`,
          pgx.StrictNamedArgs{"id": id}); err != nil {
          t.Fatal(err)
      }
      run(t, bus)
      eventually(t, func() bool { return a.count(id) == 1 })
  }

  // While Restate cannot be reached, events stay pending; a bus that can
  // reach it delivers them.
  func TestDeliversAfterRestateReturns(t *testing.T) {
      t.Parallel()
      db := pgtest.New(t)
      a := newInbox()
      in := restatetest.Start(t, restate.Reflect(a))
      down := events.NewBus(db, ingress.NewClient("http://127.0.0.1:1"), time.Now, discard)
      down.Subscribe(events.AccountRenamed, a.ServiceName(), "Handle")
      ctx, cancel := context.WithCancel(context.Background())
      done := make(chan struct{})
      go func() { _ = down.Run(ctx); close(done) }()
      e := publish(t, db, events.AccountRenamed)
      time.Sleep(1500 * time.Millisecond)
      cancel()
      <-done
      if dispatched(t, db, e.ID) {
          t.Fatal("marked while Restate was down")
      }
      up := events.NewBus(db, in, time.Now, discard)
      up.Subscribe(events.AccountRenamed, a.ServiceName(), "Handle")
      run(t, up)
      eventually(t, func() bool { return a.count(e.ID) == 1 && dispatched(t, db, e.ID) })
  }

  func TestOldDispatchedEventsAreDeleted(t *testing.T) {
      t.Parallel()
      db := pgtest.New(t)
      now := time.Now()
      old, recent := uuid.NewV7(), uuid.NewV7()
      for id, at := range map[uuid.UUID]time.Time{old: now.Add(-8 * 24 * time.Hour), recent: now.Add(-6 * 24 * time.Hour)} {
          if _, err := db.Exec(context.Background(), `INSERT INTO events (id, kind, subject_id, data, at, dispatched_at) VALUES (@id, 'account.renamed', @id, '{}', @at, @at)`,
              pgx.StrictNamedArgs{"id": id, "at": at}); err != nil {
              t.Fatal(err)
          }
      }
      run(t, events.NewBus(db, restatetest.Start(t), func() time.Time { return now }, discard))
      count := func(id uuid.UUID) int {
          var n int
          _ = db.QueryRow(context.Background(), `SELECT count(*) FROM events WHERE id = @id`, pgx.StrictNamedArgs{"id": id}).Scan(&n)
          return n
      }
      eventually(t, func() bool { return count(old) == 0 })
      if count(recent) != 1 {
          t.Fatal("a recent event was deleted")
      }
  }

  func TestRunStopsWithItsContext(t *testing.T) {
      t.Parallel()
      bus := events.NewBus(pgtest.New(t), restatetest.Start(t), time.Now, discard)
      ctx, cancel := context.WithCancel(context.Background())
      done := make(chan error, 1)
      go func() { done <- bus.Run(ctx) }()
      time.Sleep(100 * time.Millisecond)
      cancel()
      select {
      case err := <-done:
          if err != nil {
              t.Fatal(err)
          }
      case <-time.After(5 * time.Second):
          t.Fatal("Run did not return")
      }
  }

  func TestSubscribeAfterRunPanics(t *testing.T) {
      t.Parallel()
      bus := events.NewBus(pgtest.New(t), restatetest.Start(t), time.Now, discard)
      run(t, bus)
      time.Sleep(100 * time.Millisecond)
      defer func() {
          if recover() == nil {
              t.Fatal("no panic")
          }
      }()
      bus.Subscribe(events.AccountRenamed, "late", "Handle")
  }
  ```

  `bus_internal_test.go` (package `events`) covers a crash between the send and the mark: it sends the event once with the delivery's key, as a round that died before its commit would have, then runs a round:

  ```go
  package events

  // counter is a subscriber that counts how often its handler ran per event.
  type counter struct {
      prefix string
      mu     *sync.Mutex
      runs   map[uuid.UUID]int
  }

  func (c counter) ServiceName() string { return c.prefix + "Counter" }

  func (c counter) Handle(ctx restate.Context, e Event) error {
      return restate.RunVoid(ctx, func(restate.RunContext) error {
          c.mu.Lock()
          defer c.mu.Unlock()
          c.runs[e.ID]++
          return nil
      })
  }

  func (c counter) count(id uuid.UUID) int {
      c.mu.Lock()
      defer c.mu.Unlock()
      return c.runs[id]
  }

  // A round that sent an event and died before marking it sends it again
  // under the same key, and the subscriber still runs once.
  func TestResendAfterACrashDeliversOnce(t *testing.T) {
      t.Parallel()
      ctx := context.Background()
      db := pgtest.New(t)
      c := counter{prefix: restatetest.Prefix(), mu: &sync.Mutex{}, runs: map[uuid.UUID]int{}}
      in := restatetest.Start(t, restate.Reflect(c))
      bus := NewBus(db, in, time.Now, slog.New(slog.DiscardHandler))
      bus.Subscribe(AccountRenamed, c.ServiceName(), "Handle")
      e := Event{ID: uuid.NewV7(), Kind: AccountRenamed, SubjectID: uuid.NewV7(), Data: map[string]any{}, At: time.Now().UTC().Truncate(time.Microsecond)}
      if err := pgx.BeginFunc(ctx, db, func(tx pgx.Tx) error { return Insert(ctx, tx, e) }); err != nil {
          t.Fatal(err)
      }
      sub := bus.subs[AccountRenamed][0]
      if _, err := ingress.ServiceSend[Event](in, sub.Service, sub.Handler).
          Send(ctx, e, restate.WithIdempotencyKey(sub.key(e))); err != nil {
          t.Fatal(err)
      }
      if _, err := bus.dispatch(ctx); err != nil {
          t.Fatal(err)
      }
      for deadline := time.Now().Add(10 * time.Second); c.count(e.ID) == 0 && time.Now().Before(deadline); {
          time.Sleep(50 * time.Millisecond)
      }
      time.Sleep(time.Second) // a second run would land by now
      if n := c.count(e.ID); n != 1 {
          t.Fatalf("handler ran %d times", n)
      }
  }
  ```

- [ ] **Step 2: Run.** `go test ./internal/platform/events/` fails to compile: `events.NewBus` undefined.

- [ ] **Step 3: Implement** `bus.go`:

  ```go
  const (
      batchSize = 100
      pollEvery = time.Second
      keepFor   = 7 * 24 * time.Hour
  )

  // Subscription hands every event of Kind to a Restate handler.
  type Subscription struct {
      Kind    Kind
      Service string // with the service prefix
      Handler string
  }

  // key is the delivery's idempotency key; Restate drops a repeat.
  func (s Subscription) key(e Event) string { return e.ID.String() + "/" + s.Service + "/" + s.Handler }

  // Bus delivers events to the handlers subscribed to their kind. Each
  // event to each subscriber is one Restate invocation, so a failing
  // handler blocks no other event.
  type Bus struct {
      db      *pgxpool.Pool
      ingress *ingress.Client
      now     func() time.Time
      log     *slog.Logger
      mu      sync.Mutex
      subs    map[Kind][]Subscription
      running bool
  }

  func NewBus(db *pgxpool.Pool, in *ingress.Client, now func() time.Time, log *slog.Logger) *Bus {
      return &Bus{db: db, ingress: in, now: now, log: log, subs: map[Kind][]Subscription{}}
  }

  func (b *Bus) Subscribe(kind Kind, service, handler string) {
      b.mu.Lock()
      defer b.mu.Unlock()
      if b.running {
          panic("events: Subscribe after Run")
      }
      b.subs[kind] = append(b.subs[kind], Subscription{Kind: kind, Service: service, Handler: handler})
  }

  // Run delivers pending events, then waits for a notification or the next
  // poll, until ctx is done.
  func (b *Bus) Run(ctx context.Context) error {
      b.mu.Lock()
      b.running = true
      b.mu.Unlock()
      wake := make(chan struct{}, 1)
      go b.listen(ctx, wake)
      tick := time.NewTicker(pollEvery)
      defer tick.Stop()
      for {
          for {
              n, err := b.dispatch(ctx)
              if err != nil {
                  if ctx.Err() == nil {
                      b.log.WarnContext(ctx, "events: dispatch", "err", err)
                  }
                  break
              }
              if n < batchSize {
                  break
              }
          }
          if _, err := b.db.Exec(ctx, `DELETE FROM events WHERE dispatched_at < @before`,
              pgx.StrictNamedArgs{"before": b.now().Add(-keepFor)}); err != nil && ctx.Err() == nil {
              b.log.WarnContext(ctx, "events: delete dispatched", "err", err)
          }
          select {
          case <-ctx.Done():
              return nil
          case <-tick.C:
          case <-wake:
          }
      }
  }

  // listen wakes Run on every notification. A lost connection is listened
  // again after a pause; the poll covers the gap.
  func (b *Bus) listen(ctx context.Context, wake chan<- struct{}) {
      for ctx.Err() == nil {
          if err := b.waitNotifications(ctx, wake); err != nil && ctx.Err() == nil {
              b.log.WarnContext(ctx, "events: listen", "err", err)
              select {
              case <-ctx.Done():
              case <-time.After(pollEvery):
              }
          }
      }
  }

  func (b *Bus) waitNotifications(ctx context.Context, wake chan<- struct{}) error {
      conn, err := b.db.Acquire(ctx)
      if err != nil {
          return fmt.Errorf("acquire: %w", err)
      }
      defer conn.Release()
      if _, err = conn.Exec(ctx, "LISTEN events"); err != nil {
          return fmt.Errorf("listen: %w", err)
      }
      for {
          if _, err = conn.Conn().WaitForNotification(ctx); err != nil {
              return fmt.Errorf("wait: %w", err)
          }
          select {
          case wake <- struct{}{}:
          default:
          }
      }
  }

  const selectPending = `
  SELECT id, kind, subject_id, data, at FROM events
  WHERE dispatched_at IS NULL ORDER BY id LIMIT @limit
  FOR UPDATE SKIP LOCKED`

  // dispatch sends one batch and marks what it sent, in one transaction, so
  // two buses never hold the same event. A failed send ends the batch; the
  // events it did not mark are sent again next round under the same keys.
  func (b *Bus) dispatch(ctx context.Context) (int, error) {
      b.mu.Lock()
      subs := b.subs
      b.mu.Unlock()
      var n int
      var sendErr error
      err := pgx.BeginFunc(ctx, b.db, func(tx pgx.Tx) error {
          rows, err := tx.Query(ctx, selectPending, pgx.StrictNamedArgs{"limit": batchSize})
          if err != nil {
              return fmt.Errorf("select pending events: %w", err)
          }
          pending, err := pgx.CollectRows(rows, pgx.RowToStructByPos[Event])
          if err != nil {
              return fmt.Errorf("read pending events: %w", err)
          }
          n = len(pending)
          sent := make([]uuid.UUID, 0, len(pending))
      events:
          for _, e := range pending {
              for _, s := range subs[e.Kind] {
                  if _, sendErr = ingress.ServiceSend[Event](b.ingress, s.Service, s.Handler).
                      Send(ctx, e, restate.WithIdempotencyKey(s.key(e))); sendErr != nil {
                      break events
                  }
                  dispatched.Add(ctx, 1, metric.WithAttributes(attribute.String("kind", string(e.Kind))))
              }
              sent = append(sent, e.ID)
          }
          if _, err = tx.Exec(ctx, `UPDATE events SET dispatched_at = @at WHERE id = ANY(@ids)`,
              pgx.StrictNamedArgs{"at": b.now(), "ids": sent}); err != nil {
              return fmt.Errorf("mark events dispatched: %w", err)
          }
          return nil
      })
      if err != nil {
          return 0, fmt.Errorf("dispatch events: %w", err)
      }
      if sendErr != nil {
          return n, fmt.Errorf("send event: %w", sendErr)
      }
      return n, nil
  }
  ```

  `RowToStructByPos[Event]` needs the struct's field order to match the SELECT (`ID, Kind, SubjectID, Data, At`); keep `Event` in that order. `metrics.go`:

  ```go
  var dispatched = telemetry.Must(otel.Meter("github.com/shopnexus/server2/internal/platform/events").
      Int64Counter("events_dispatched_total", metric.WithDescription("event deliveries handed to Restate, by kind")))
  ```

- [ ] **Step 4: Run.** `go test ./internal/platform/events/` passes; `golangci-lint run ./internal/platform/events/` reports 0 issues. A lint finding on the labelled `break` or on `subs` read under the lock is fixed in the code, not with a `nolint`.

### Task 3: module account publishes

**Files:**
- Modify: `internal/account/repository/account.go`, `internal/account/repository/account_pg.go`
- Modify: `internal/account/service/account_rename.go`, `internal/account/service/account_suspend.go`
- Test: `internal/account/repository/account_pg_test.go`, `internal/account/service/account_rename_test.go`, `internal/account/service/account_suspend_test.go`

**Interfaces:**
- Consumes: `events.Event`, `events.Insert`, the three kinds (Task 1).
- Produces:
  ```go
  Save(ctx context.Context, a *domain.Account, writeID uuid.UUID, evs ...events.Event) error
  SaveAudited(ctx context.Context, a *domain.Account, writeID uuid.UUID, e audit.Entry, evs ...events.Event) error
  ```

- [ ] **Step 1: Write the failing tests.** In `account_pg_test.go`:

  ```go
  func eventsOf(t *testing.T, db *pgxpool.Pool, subject uuid.UUID) []string {
      t.Helper()
      rows, err := db.Query(context.Background(), `SELECT kind FROM events WHERE subject_id = @id ORDER BY id`, pgx.StrictNamedArgs{"id": subject})
      if err != nil {
          t.Fatal(err)
      }
      kinds, err := pgx.CollectRows(rows, pgx.RowTo[string])
      if err != nil {
          t.Fatal(err)
      }
      return kinds
  }

  // Save and SaveAudited write their events with the change; a stale write
  // writes none.
  func TestSaveWritesItsEvents(t *testing.T) {
      t.Parallel()
      db := pgtest.New(t)
      s := repository.NewAccounts(db)
      ctx := context.Background()
      id := seed(t, s)
      a, _ := s.Get(ctx, id)
      stale := a
      ev := func(k events.Kind) events.Event { return events.Event{ID: uuid.NewV7(), Kind: k, SubjectID: id, At: now} }
      if err := a.SetDisplayName("Minh", now); err != nil {
          t.Fatal(err)
      }
      if err := s.Save(ctx, &a, uuid.NewV7(), ev(events.AccountRenamed)); err != nil {
          t.Fatal(err)
      }
      if err := a.Suspend("spam", nil, now); err != nil {
          t.Fatal(err)
      }
      entry := audit.Entry{Actor: audit.ByCLI("test"), Action: audit.AccountSuspend, Target: audit.Account(id), At: now}
      if err := s.SaveAudited(ctx, &a, uuid.NewV7(), entry, ev(events.AccountSuspended)); err != nil {
          t.Fatal(err)
      }
      if err := s.Save(ctx, &stale, uuid.NewV7(), ev(events.AccountRenamed)); !errors.Is(err, repository.ErrConflict) {
          t.Fatalf("stale save: %v", err)
      }
      if got := eventsOf(t, db, id); !slices.Equal(got, []string{"account.renamed", "account.suspended"}) {
          t.Fatalf("%v", got)
      }
  }
  ```

  In `account_rename_test.go` and `account_suspend_test.go`, add a check after the existing successful `Rename`, `Suspend` and `Reinstate` calls that the events table holds `account.renamed`, `account.suspended` and `account.unsuspended` with the account as `subject_id` (a local `eventsOf` helper in `service/helpers_test.go`, the same query; the tests that need it build their store with `pgtest.New(t)` kept in a variable).

- [ ] **Step 2: Run.** `go test ./internal/account/...` fails to compile: `Save` takes no events.

- [ ] **Step 3: Repository.** In `account.go` add `evs ...events.Event` to `Save` and `SaveAudited` and document it ("writes evs in the same transaction"). In `account_pg.go`:

  ```go
  func (s pgAccounts) Save(ctx context.Context, a *domain.Account, writeID uuid.UUID, evs ...events.Event) error {
      err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
          if err := update(ctx, tx, a, writeID); err != nil {
              return err
          }
          return insertEvents(ctx, tx, evs)
      })
      if err != nil {
          return fmt.Errorf("save account: %w", err)
      }
      a.Saved(writeID)
      return nil
  }

  func (s pgAccounts) SaveAudited(ctx context.Context, a *domain.Account, writeID uuid.UUID, e audit.Entry, evs ...events.Event) error {
      err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
          if err := update(ctx, tx, a, writeID); err != nil {
              return err
          }
          if err := audit.Insert(ctx, tx, e); err != nil {
              return err
          }
          return insertEvents(ctx, tx, evs)
      })
      ...
  }

  // insertEvents writes evs in tx.
  func insertEvents(ctx context.Context, tx pgx.Tx, evs []events.Event) error {
      for _, e := range evs {
          if err := events.Insert(ctx, tx, e); err != nil {
              return err
          }
      }
      return nil
  }
  ```

  `Save` used to run outside a transaction; it now opens one so the events commit with the change. `ErrConflict` must still reach the caller through the wrap (`errors.Is`), and the save-twice test still passes.

- [ ] **Step 4: Service.** `Rename` saves with `events.Event{ID: uuid.NewV7(), Kind: events.AccountRenamed, SubjectID: id, At: now}`; `Suspend` adds `events.AccountSuspended` with `in.ID`; `Reinstate` adds `events.AccountUnsuspended`.

- [ ] **Step 5: Run.** `make test` passes; lint reports 0 issues.

### Task 4: wiring

**Files:**
- Modify: `internal/platform/module/module.go`, `internal/app/app.go`
- Test: `internal/app/app_test.go`

**Interfaces:**
- Consumes: `events.NewBus`, `(*Bus).Subscribe`, `(*Bus).Run` (Task 2).
- Produces: `module.Deps.Events *events.Bus`.

- [ ] **Step 1: Write the failing test** in `app_test.go`: build the app as its existing tests do, then call `Close` and check it returns within five seconds (the bus goroutine stops):

  ```go
  func TestCloseStopsTheEventBus(t *testing.T) {
      // build a as the other tests in this file do
      done := make(chan error, 1)
      go func() { done <- a.Close(context.Background()) }()
      select {
      case err := <-done:
          if err != nil {
              t.Fatal(err)
          }
      case <-time.After(5 * time.Second):
          t.Fatal("Close did not return")
      }
  }
  ```

  Read `app_test.go` first and reuse its setup helper.

- [ ] **Step 2: Run.** The test passes already (nothing runs yet); it pins the behaviour for Step 3. Note this in the ledger.

- [ ] **Step 3: Wire.** `module.Deps` gains `Events *events.Bus` with the comment "Events is the bus a module subscribes its Restate handlers to in Mount." In `app.New`, before `mountModules`, build `bus := events.NewBus(pool, ingress, time.Now, log)` and pass it in `Deps` (move the `ingress.NewClient` call up so `mountModules` and the bus share one client). After `startRestate`:

  ```go
  runCtx, stop := context.WithCancel(context.Background())
  a.stopEvents, a.eventsDone = stop, make(chan struct{})
  go func() {
      if err := bus.Run(runCtx); err != nil {
          log.ErrorContext(runCtx, "event bus stopped", "err", err)
      }
      close(a.eventsDone)
  }()
  ```

  `App.Close` cancels `stopEvents` and waits on `eventsDone` (when set) before closing the endpoint and the pool.

- [ ] **Step 4: Run.** `make test` passes, e2e included; lint reports 0 issues.

### Task 5: docs

**Files:**
- Modify: `ARCHITECTURE.md`

- [ ] **Step 1:** Add "### Events" after "### Durable flows" with the decisions of the spec: outbox table written by repositories in the change's transaction, thin events and their kinds, `Bus.Subscribe` in a subscriber's `Mount`, the dispatcher's round (`SKIP LOCKED`, idempotency key, mark, 7-day delete, `LISTEN` plus one-second poll), and what happens while Restate is down. In "Infrastructure", replace the sentence saying Restate replaced the outbox with one saying Restate replaced the relay, JetStream and NATS, and the outbox is a table the bus drains into Restate.
- [ ] **Step 2:** Run `python3 ~/.claude/skills/humanizing-writing/ai-tells.py --stats ARCHITECTURE.md` and fix every hit.
- [ ] **Step 3:** `make test` passes; lint reports 0 issues.
