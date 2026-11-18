# App wiring, Phase 6: the update stream — Implementation Plan

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`. Gap analysis 2026-11-16. Server: `GET /v1/ws` (`internal/platform/stream/socket.go`), `/v1/updates`, spec `docs/superpowers/specs/2026-11-10-server-realtime-ws-design.md`. The plan is built on the server-state layer (`2026-11-15-app-server-state.md`).
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** the live flavor keeps one WebSocket per signed-in account while the app is in the foreground. It stores the last `seq` per account, catches up with `since` after a reconnect, renews the token with `auth` frames, and hands pushes to the repositories as typed `Pushed` events. No screen changes in this phase: the kinds on the stream (message, read, deal, notification, scam_warning, listing_read) belong to Phases 7–10.

## Rulings (product owner, 2026-11-16)

- Phase 6 ships on its own as infrastructure, checked by tests, a live test and the emulator.
- Hearts, follows, blocks and addresses are not pushed. A screen reads again when it shows. Saves already reach the server through REST, so recommendations can use them without a push.
- The server adds a dev-only `POST /v1/dev/updates` that logs an update for the caller, so the live test can check delivery.
- A suspended account goes back to Chào mừng with a one-time reason. The session stores why it ended: suspended, revoked or signed out. This needs a mockup first.

## Decisions (analysis)

- **Socket conditions:** signed-in only, foreground only (`ProcessLifecycleOwner`), and live flavor only. A guest has no socket.
- **Seq storage:** in its own `updates` DataStore, per account. It is written after the push is handed on: on `ready`, at most every 2 s, and on close. It is removed on sign-out.
- **Backlog:**
  - Frames before `ready` are buffered, de-duplicated and handed on once.
  - The first connect without a seq is treated as a `Reset`.
  - A gap closes the socket and reconnects with `since`. A seq that was already seen is skipped.
- **Backoff:** 1 s doubling to 30 s with full jitter, reset on `ready`. After 1001, reconnect within a random 0–3 s. A network change reconnects at once. The client pings every 20 s.
- **Tokens:**
  - The socket's own client sends the header from `tokens.access()`.
  - A timer at `expiresAt − 50 s` renews the token and sends an `auth` frame, and so does any token change for the same account.
  - On 4001 or a 401 handshake: `tokens.refreshed(sent)`, then reconnect.
  - On 4003: refresh, which ends the session as suspended.
- **Pushes:** `UpdateStream.pushes: SharedFlow<Pushed>`, tagged by account. Unknown kinds are dropped but their seq still counts. There are no new `ServerChanges` topics until a phase reads them.
- **Cold start:** no `/v1/updates` call, since the socket's `since` catch-up returns the same log.

## Sub-steps

1. Server: `POST /v1/dev/updates`, the `/v1/ws` description listing every kind, and an e2e test.
2. App `feat/wire-realtime`:
   - `:core:network`: `ktor-client-websockets`, `UpdateSource`/`KtorUpdateSource`, frame DTOs, and `prepare.py` dropping `openSocket`.
   - `:core:data/net`: `UpdateStream`, `Pushed`, `UpdateSeqs`, `AppForeground`, `NetworkChanges`, and the `NetUpdates` module bound as `AppStartup` in live.
   - Tests: `FakeUpdateSource` (virtual time), `KtorUpdateSource` against `mockwebserver3`, and an opt-in `LiveUpdateStreamTest`.
3. Session end reason: `SessionStore` keeps why the session ended. Chào mừng shows "Tài khoản đã bị khoá" once. The mockup is approved before the code.

Each step: gate, `/code-review`, `/simplify`, merge.
