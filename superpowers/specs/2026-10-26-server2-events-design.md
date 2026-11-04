# Design: server2 events

Date: 2026-10-26.
Status: decided in conversation, question by question and section by
section. When the work lands, the decisions below go into
`~/shopnexus/server2/ARCHITECTURE.md` under a new "Events" heading.

## Revision of 2026-10-26: fan-out in Restate and the worker layer

Decided after the first version shipped; where it disagrees with the
sections below, this section wins.

- The dispatcher sends each event once, to `Events.Deliver`, a Restate
  service the `events` package registers, with the event ID as idempotency
  key. `Deliver` sends the event to every subscriber with
  `restate.ServiceSend`; each send is journaled, and each subscriber runs
  as an invocation of its own that Restate retries alone. An event whose
  kind has no subscriber is marked without a send.
- A spike on Restate 1.8.0 showed that a send to a service or handler
  Restate does not know fails the sending invocation with RT0018, which
  Restate retries with growing backoff (4 s, 8 s, 17 s, about 1 min) and
  completes once the service is registered; sends already journaled are
  not repeated. During a rolling deploy a new subscriber gets its events
  once its deployment is registered.
- When the ingress refuses the send to `Events.Deliver` itself (4xx), the
  event backs off: `attempts` grows and `next_attempt_at` moves 1 s, 2 s,
  4 s and so on, up to 1 hour, and the dispatcher skips it until then.
  Any other failure ends the round.
- Each module that reacts to events has a `worker` package next to
  `handler`: its Restate service with one handler per event kind, calling
  the module's `Service`. `Mount` registers the worker with Restate and
  subscribes it. depguard keeps `worker` to `service` and `domain`, as
  `handler`.

## Problem

Search indexing, loyalty points and recommendations will react to changes
in other modules. A module that changes data must not list who reacts: the
list grows with every feature, and the publisher would import modules it
has no business knowing.

## Decisions

| Question | Decision |
|---|---|
| Where subscribers run | Modules inside server2. No external broker. |
| Replay | None. A subscriber rebuilds its data from the current tables with a job of its own; events only carry changes from then on. Delivered events are deleted after 7 days. |
| Publishing | An outbox: the repository writes the event in the transaction of the change, and a dispatcher hands it to Restate. |
| Event content | Thin: the kind and the ID of the aggregate that changed. A subscriber reads the current state through the source module's `Service`, so order, delay and duplicates do not change the result. A business event may carry the few fields its subscribers need. |
| Scope | The bus now, with three events from module account and a sample subscriber in tests. |

Rejected:

- Kafka, Redpanda or NATS. Every subscriber is a module of the same
  binary, and nothing reads the event history.
- Publishing only from Restate handlers. Every use case that publishes
  would be rewritten around `restate.Run`.
- Calling Restate after the commit. A crash between the commit and the
  call loses the event.
- Fat events with a snapshot. They need per-aggregate ordering and turn the
  event schema into a contract to keep compatible.

## Package events

`internal/platform/events`, next to `audit` and used the same way:

```go
// Kind is what happened. Each kind is a constant.
type Kind string

const (
	AccountRenamed     Kind = "account.renamed"
	AccountSuspended   Kind = "account.suspended"
	AccountUnsuspended Kind = "account.unsuspended"
)

// Event is what happened to which aggregate.
type Event struct {
	ID        uuid.UUID      `json:"id"`         // UUIDv7
	Kind      Kind           `json:"kind"`
	SubjectID uuid.UUID      `json:"subject_id"` // the aggregate that changed
	Data      map[string]any `json:"data"`       // mostly empty
	At        time.Time      `json:"at"`
}

// Insert writes e in tx, the transaction of the change, and notifies the
// dispatcher when tx commits.
func Insert(ctx context.Context, tx pgx.Tx, e Event) error
```

`Insert` runs `INSERT INTO events` and `SELECT pg_notify('events', '')`; Postgres
delivers the notification on commit and drops it on rollback.

## Table

Migration `0004_events.sql`:

```sql
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

## Publishing

A repository method that writes a change takes the events of that change
and writes them in its transaction, as it writes an audit entry:

```go
Save(ctx context.Context, a *domain.Account, writeID uuid.UUID, evs ...events.Event) error
SaveAudited(ctx context.Context, a *domain.Account, writeID uuid.UUID, e audit.Entry, evs ...events.Event) error
```

The change, its audit entry and its events commit together or not at all;
a write that conflicts leaves no event. A use case stays plain Go:

```go
err := s.accounts.Save(ctx, &a, uuid.NewV7(), events.Event{
	ID: uuid.NewV7(), Kind: events.AccountRenamed, SubjectID: id, At: now,
})
```

Module account publishes `account.renamed` from `Rename`, and
`account.suspended` and `account.unsuspended` from `Suspend` and
`Reinstate`.

## Subscribing

`module.Deps` gains `Events *events.Bus`. A subscriber module's `Mount`
subscribes a handler of one of its Restate services to a kind:

```go
d.Events.Subscribe(events.AccountSuspended, d.ServicePrefix+"SearchIndex", "OnAccountChanged")
```

The handler has the signature `func(ctx restate.Context, e events.Event)
error` and is bound with the module's other Restate services. It reads the
current state through the source module's `Service` inside `restate.Run`.
Restate retries a failing handler until it succeeds; each event to each
subscriber is its own invocation, so one failing event blocks no other.
`Subscribe` after `Run` has started panics.

## Dispatcher

`(*events.Bus).Run(ctx)` runs in a goroutine that `app.New` starts after
the Restate endpoint is registered; `App.Close` cancels it and waits for
it. Each round:

1. In one transaction, `SELECT ... FROM events WHERE dispatched_at IS NULL
   ORDER BY id LIMIT 100 FOR UPDATE SKIP LOCKED`. Two server instances
   never hold the same event.
2. For each event and each subscription of its kind,
   `ingress.ServiceSend[events.Event](...).Send` with the idempotency key
   `<event id>/<service>/<handler>`.
3. Set `dispatched_at` on the events sent and commit. A failed `Send`
   (Restate down) ends the round; the events not marked are sent again in
   the next round, and Restate drops a repeated key within its 24-hour
   idempotency retention.
4. Delete events dispatched more than 7 days ago.

The dispatcher `LISTEN`s on channel `events` on a connection of its own and
also runs a round every second, in case it missed a notification. The
interval and the batch size are constants in code. Counter
`events_dispatched_total` counts sends by kind; a failed send is logged.
While Restate is down, events wait in the table and the API keeps working.

## Tests

- `events`, against the test stack's Postgres and Restate, with a sample
  Restate service that records what it receives:
  - an event reaches its subscriber once;
  - a round that sent but did not mark (a crash before the commit) sends
    again, and the subscriber still runs once;
  - two dispatchers at once deliver each event once;
  - every subscriber of a kind receives it;
  - dispatched events older than 7 days are deleted.
- `account/repository`: `Save` and `SaveAudited` write their events in the
  transaction; a conflict writes none.
- `account/service`: `Rename`, `Suspend` and `Reinstate` publish their kind
  with the account as subject.

## Documentation

ARCHITECTURE.md gains "Events" with the decisions above, and "Durable
flows" notes that the outbox is back, as a table Restate drains rather than
a relay to NATS.
