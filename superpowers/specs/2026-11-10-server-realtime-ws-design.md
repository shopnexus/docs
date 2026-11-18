# Design: server realtime over WebSocket, with per-account sequence numbers

Date: 2026-11-10.
Status: decided in conversation, question by question and section by
section. When the work lands, the decisions below replace the Stream
section of `~/shopnexus/server/ARCHITECTURE.md`.

## Scope

`GET /v1/stream` (server-sent events, `2026-10-26-server-chat-design.md`)
tells an open app what changed through hints that carry IDs only. Nothing is
stored, so a hint sent while the app is disconnected, while a stream's
buffer is full, or while the hub's `LISTEN` connection is lost (a CNPG
failover) is gone, and the app has to reload everything after every
reconnect and every deploy.

This design replaces the stream with a WebSocket at `GET /v1/ws`, backed by
a per-account update log with a gapless sequence number. The log is the
source of truth and `pg_notify` is only the bell that says something new is
there. It adds typing indicators and `accounts.last_active_at`.

No client reads `/v1/stream` yet: the Android app runs on fake data and the
console and website do not use it. The server is done first. The Android
network layer, FCM, realtime presence and group chat are out of scope.

## Decisions

| Question | Decision |
|---|---|
| Library or own code | Own code. Centrifuge/Centrifugo was weighed: its history is a bounded cache that still ends in a full reload, it needs a shared broker (Valkey) for recovery across replicas, and the architecture keeps no broker. |
| Transport | WebSocket (`github.com/coder/websocket`) at `GET /v1/ws`. No SSE or HTTP-streaming fallback: the client is a native app on TLS 443. `/v1/stream` is removed. |
| Recovery | Table `account_updates` with a gapless per-account `seq`, written in the transaction of the change. The app keeps the last `seq` and reconnects with `?since=`. |
| Fan-out | `pg_notify`, as today: every replica hears every hint and hands it to its own connections. |
| Broker later | The bell sits behind an interface, `Bell`, with one implementation, `pgBell`. A Valkey or NATS bell (with TTL presence) can replace it without touching the log, the protocol or the hub. |
| Typing | Up through the WebSocket, down through the bell, outside any transaction. No `seq`, no table. |
| Online | `accounts.last_active_at`, written by the WebSocket; read in views. No realtime presence. |
| Cold start | `GET /v1/updates?since=` reads the same log over REST. |

## Data

```sql
account_update_seqs (account_id uuid PRIMARY KEY, seq bigint NOT NULL)
account_updates (
  account_id uuid, seq bigint, kind text NOT NULL,
  conversation_id uuid, message_id uuid, deal_id uuid, notification_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, seq)
)
accounts.last_active_at timestamptz NULL
```

### `stream.Notify(ctx, tx, accounts, hint)`

The signature stays, so the chat, deal and notification repositories do not
change. In the caller's transaction it:

1. Sorts `accounts` by UUID, so two transactions that touch A and B lock
   them in the same order and cannot deadlock.
2. For each account, runs `INSERT INTO account_update_seqs … ON CONFLICT
   (account_id) DO UPDATE SET seq = account_update_seqs.seq + 1 RETURNING
   seq`, then inserts the `account_updates` row with that `seq`.
3. Calls `Bell.Ring(ctx, tx, targets, hint)` with each account and its new
   `seq`.

Two properties follow from step 2, and the rest of the design relies on
them:

- **Gapless.** A rolled-back transaction rolls the counter back too, so an
  account's `seq` runs 1, 2, 3 with no holes. A missing `since+1` row can
  only mean the row was pruned.
- **Commit order is `seq` order.** The counter row stays locked until
  commit, so `seq` 43 cannot become visible before 42. A reader of `seq >
  since` never skips an update that is still committing.

The cost is that transactions writing updates for the same account
serialize at commit, which a person receiving a few messages a second does
not notice.

### Pruning

A periodic job, like the one that deletes dispatched `events`, deletes
`account_updates` rows older than 30 days, 10,000 at a time.
`account_update_seqs` is never deleted, so a `seq` never goes back.

## WebSocket protocol

`GET /v1/ws?since=<seq>` with `Authorization: Bearer <access token>`,
through `d.Protect` like every other endpoint. A missing `since` means
"nothing yet, from now on". Frames are JSON text, at most 4 KB.

```
server → app
  {"type":"ready","seq":88}
  {"type":"update","seq":43,"kind":"message","conversation_id":"…","message_id":"…"}
  {"type":"update","seq":44,"kind":"read","conversation_id":"…"}
  {"type":"update","seq":45,"kind":"deal","deal_id":"…"}
  {"type":"update","seq":46,"kind":"notification","notification_id":"…"}
  {"type":"reset","seq":88}
  {"type":"typing","conversation_id":"…"}

app → server
  {"type":"typing","conversation_id":"…"}
  {"type":"auth","token":"<new access token>"}
```

### Connecting and catching up

1. `Hub.Subscribe(account)` first, so hints that arrive during the next
   step wait in the connection's queue.
2. Read `account_updates WHERE account_id = @a AND seq > @since ORDER BY
   seq LIMIT 500`, page after page. When the `since+1` row is missing
   while the current `seq` is past `since`, or `since` is past the current
   `seq`, send `reset` with the current `seq` instead, and the app reloads
   everything.
3. Send `ready` with the current `seq`.
4. Live: a hint whose `seq` is at most `last_sent` was sent in step 2 and is
   skipped.

### The server catches up on its own

Each connection remembers `last_sent`. Two things can drop hints on their
way to it: its queue (16) is full, or the bell's `LISTEN` connection was
opened again after a loss. In both cases the hub marks the connection
`behind` instead of dropping in silence, and the connection reads the log
again from `last_sent`. Updates reach the app in `seq` order, with no
duplicates and no holes; the app only stores its last `seq` for the next
connect.

### Typing

1. Throttle: one typing frame per connection and conversation every 3
   seconds; more are dropped in silence.
2. Check that the sender is a member and that neither member blocks the
   other, through the chat and account services. The connection caches the
   answer for 30 seconds. A failed check drops the frame in silence, so
   typing does not reveal a block.
3. `Bell.Ring(ctx, nil, [the other member], typing)`.

The app turns "đang nhập…" off after 5 seconds without a new typing frame,
or when an `update message` from that person arrives.

### Token expiry

The access token lives 15 minutes (`AccessTTL`).

- The connection holds a deadline, the `exp` of the token it opened with.
- The app refreshes as usual and sends `auth` with the new token. The
  server checks signature, expiry and that the account is the same, then
  moves the deadline. A bad token, or another account's, closes with 4001.
- Past the deadline without a new token, the server closes with 4001
  `token_expired`; the app refreshes and reconnects with `since`, losing
  nothing.
- A suspended account is refused at connect and at each `auth` with 4003.

### Keep-alive and close codes

The server pings every 25 seconds and closes when a pong takes more than 10.
The handler clears its write deadline through `http.ResponseController`, as
the SSE handler does, since the server's `WriteTimeout` would end the
connection.

| Code | When | App |
|---|---|---|
| 1001 | Server shutdown or deploy | Reconnects at once with `since` |
| 4001 | Token expired, bad, or another account's | Refreshes, then reconnects |
| 4003 | Account suspended | Does not reconnect |
| 1008 | Malformed frame or one over 4 KB | Reconnects with backoff |

### `GET /v1/updates?since=<seq>`

The REST form of catching up, for a cold start or, later, an FCM wake-up,
before the WebSocket is open: at most 500 updates, `has_more`, and `reset`
with the current `seq` under the same rule as step 2.

## Bell and hub

```go
// platform/stream
type Target struct {
    Account uuid.UUID
    Seq     int64 // 0 for typing
}

type Bell interface {
    // Ring sends h to targets: on commit of tx, or at once when tx is nil.
    Ring(ctx context.Context, tx pgx.Tx, targets []Target, h Hint) error
    // Listen calls deliver for every ring and resync each time it may have
    // missed some, until ctx is done.
    Listen(ctx context.Context, deliver func([]Target, Hint), resync func())
}
```

- `pgBell.Ring` runs `pg_notify('stream', …)` on `tx`, or on the pool when
  `tx` is nil. `pgBell.Listen` wraps `postgres.Listen` and calls `resync`
  each time the `LISTEN` connection opens again.
- `Hub` no longer knows Postgres; it takes `deliver` and `resync` from the
  bell. Each connection has a queue of 16 and a `behind` flag. A full queue
  or a `resync` sets `behind`, and the connection reads the log from
  `last_sent`. Typing carries no `seq`: when the queue is full it is
  dropped.
- Connections read the log through a small `UpdateReader` (`Since(account,
  seq, limit)`, `Current(account)`), so hub tests need no Postgres.

## `last_active_at`

- Written when a WebSocket connects, when it closes, and every 60 seconds
  while it is open: `UPDATE accounts SET last_active_at = now() WHERE id =
  @id AND (last_active_at IS NULL OR last_active_at < now() - interval '30
  seconds')`, so several devices of one account do not pile up writes. It
  does not change `write_id`, so it does not race the account aggregate's
  optimistic lock.
- Returned for the other person in `GET /v1/conversations`, `GET
  /v1/conversations/{id}`, and for the seller in the seller page's view
  (`internal/screen/service/seller.go`). The app
  decides the wording: under 5 minutes is "Đang hoạt động", otherwise
  "Hoạt động X phút trước".

## Shutdown and deploy

`RegisterOnShutdown(a.CloseStreams)` keeps its meaning: `Hub.Close` closes
every connection with 1001, the handlers return, and `Shutdown` does not
wait for them. The app reconnects to another replica with `since` and loses
nothing, where the SSE stream made it reload everything.

## Removed

- `GET /v1/stream`, `internal/platform/stream/handler.go`,
  `api/paths/stream.yaml`, `e2e/stream_test.go` (replaced by WebSocket
  tests).
- OpenAPI describes `/v1/ws` as a `GET` answering `101`, with the frames in
  its `description`, and adds `/v1/updates`.

## Tests

| Level | What |
|---|---|
| Repository | `seq` is gapless; a rollback leaves no hole; two transactions locking A and B in either order do not deadlock; `Since` reports `reset` when `since+1` is missing or `since` is ahead; pruning deletes only rows older than 30 days. |
| Hub (no database) | A hint reaches only its accounts; a full queue sets `behind`; `resync` makes every connection read again; typing over a full queue is dropped; `Close` closes everything. |
| WebSocket handler | Catch-up then `ready`; no duplicate between backlog and live; `reset`; `auth` extends the deadline, another account's `auth` closes 4001; expiry closes 4001; typing throttle; typing across a block does not arrive. |
| e2e | B, connected, gets an `update` with the right `seq` after A sends; B disconnects, A sends three messages, B reconnects with `since` and gets exactly those three; typing reaches B; `/v1/updates`; 401 without a token. |

## Out of scope

The Android network layer and WebSocket client, FCM push to a closed app,
realtime presence with TTL (waits for a Valkey bell), group chat.
