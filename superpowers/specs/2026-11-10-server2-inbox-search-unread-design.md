# server2: inbox search, mark unread, report from a conversation

Date: 2026-11-10. Server repo: `~/shopnexus/server`. Checklist items in
`~/shopnexus/checklist.md`, section 1 "Chat & giao dịch": "Tìm trong hộp
thư", "Chặn + báo cáo từ cuộc trò chuyện", "Đánh dấu chưa đọc (chat và
thông báo)".

## Goal

Give the Android app's existing `InboxRepository.search`,
`InboxRepository.setRead(id, false)`, `InboxRepository.blockAndReport` /
`restore`, `NotificationRepository.markAllRead` (returns the IDs it changed)
and `NotificationRepository.markUnread(ids)` a server behind them.

Decisions taken with the user:

1. Block + report reuses `POST /v1/blocks` and `POST /v1/reports`; the
   report gains an optional `conversation_id`. No combined endpoint.
2. A conversation's "unread" mark is a flag of its own,
   `conversation_members.marked_unread`. The read marker and the other
   side's "Đã xem" never move back.
3. Notifications: `read-all` returns the IDs it changed, and one endpoint,
   `POST /v1/notifications/unread {ids}`, serves both a single notice and
   the undo of read-all.
4. Inbox search runs on a ParadeDB BM25 index over message bodies with
   ASCII folding. Words match whole, the last word as a prefix.

## 1. Report from a conversation

API (`api/paths/trust.yaml`, `api/schemas/trust.yaml`):

- `ReportCreate` gains `conversation_id` (uuid, optional).
- It is allowed only with `account_id`; with `listing_id` it is
  `invalid_report` (422).
- The conversation must be the reporter's conversation with that account:
  `chatsvc.Service.ConversationWith(reporter, account_id)` must return the
  same ID. Otherwise `invalid_report` (422). A blocked pair still has its
  conversation, so the app may block first and report second.
- `Report` (response) gains `conversation_id` when set.
- Reporting the same account again replaces reason, note and
  `conversation_id` (an absent one clears it), as reason and note are
  replaced today.

Data: migration adds `reports.conversation_id uuid REFERENCES
conversations (id)`, null by default, with `CHECK (conversation_id IS NULL
OR listing_id IS NULL)`.

Code: `trust` gets `chatsvc.Service` in its deps (depguard allows service
imports). The check runs in the report use case before the insert.

App flow, for the record: block (`POST /v1/blocks`), then report
(`POST /v1/reports {account_id, reason: "scam", conversation_id}`).
"Hoàn tác": `DELETE /v1/reports/{id}`, then `DELETE /v1/blocks/{account_id}`.

## 2. Mark a conversation unread

API (`api/paths/chat.yaml`, `api/openapi.yaml`):

- `POST /v1/conversations/{id}/unread`: 204. Not a member:
  `conversation_not_found` (404). Marking again changes nothing.
- `POST /v1/conversations/{id}/read` clears the flag on every call by a
  member with a valid message, also when the marker does not move (the app
  opens the chat at the message the marker already holds).

Data: migration adds `conversation_members.marked_unread boolean NOT NULL
DEFAULT false`.

Counting:

- An inbox row's `unread` is `greatest(n, 1)` when the flag is set, `n`
  otherwise, where `n` is the count after the marker as today.
- `GET /v1/me/unread` and `InboxScreen.unread` sum the same per-row value,
  so a flagged conversation with nothing new counts 1.
- A conversation the caller blocks stays out, as today.

Stream: setting the flag, and a read that clears it, call `stream.Notify`
for the caller's own account with kind `read` and the conversation ID, so
the caller's other devices refresh their badge. A read that moves the
marker still notifies the other member as today. One read can therefore
notify both, in one `Notify` call with both accounts.

Repository: `MarkUnread(ctx, conversation, account)` sets the flag and
notifies only when it changed (`WHERE NOT marked_unread`). `MarkRead` gains
the flag clear in its transaction: one `UPDATE` sets
`marked_unread = false` and moves the marker when newer, returning whether
each changed, and the notify targets follow from that.

## 3. Notifications unread

API (`api/paths/notification.yaml`, `api/schemas/notification.yaml`):

- `POST /v1/notifications/read-all`: 200 `{ "ids": [uuid…] }`, the notices
  this call marked read (was 204). The 90-day retention bounds the list.
- `POST /v1/notifications/unread` with body `{ "ids": [uuid…] }`, 1 to 500
  unique IDs (schema `minItems: 1`, `maxItems: 500`, `uniqueItems: true`):
  204. It sets `read_at = NULL` on the caller's notices among the IDs.
  - An ID that is unknown or someone else's is skipped.
  - An unread notice stays unread.
  - A read notice whose `collapse_key` already has an unread notice of the
    caller's stays read: the newer unread notice stands for the key, and the
    unique index `notifications_unread_key` forbids two. When two IDs of
    the request share a key and neither is unread, the newest by
    `bumped_at` becomes unread.
- Home's unread count and the list read the same column, so nothing else
  changes.

Repository: `Unread(ctx, account, ids)` is one statement: pick the
caller's read notices among the IDs, keep per collapse key only the newest
and only when the key has no unread notice, and update those. Notices
without a collapse key are all updated.

## 4. Inbox search

API (`api/paths/screen_inbox.yaml`, `api/schemas/screen_inbox.yaml`):

`GET /v1/screens/inbox/search?q=&cursor=&limit=` (bearer auth):

- `q` is required. After trimming it holds 1 to 100 characters, and it
  must yield at least one token; otherwise `invalid_query` (422).
- 200 `InboxSearch`:
  - `threads`: up to 20 `InboxItem`s, the same schema as the inbox view,
    deal included, on the first page only (absent `cursor`); an empty
    array on later pages. Newest last message first.
  - `messages`: one page of `MessageHit {conversation_id, other: Person,
    message: Message}`, newest first.
  - `next_cursor`: present when more messages follow; it pages the
    messages only.

Scope: the caller's conversations with a sent message, archived or not,
leaving out a conversation with someone the caller blocks (the inbox rule
without the archive filter). `InboxItem.archived` comes from the row.

Tokens: `q` is split by `pdb.simple('ascii_folding=true')`, the same
tokenizer as the index, so case and accents (đ included) fold the same
way on both sides. Every token but the last must match whole; the last
matches as a prefix.

Threads: a conversation matches when every token of `q` (the last as a
prefix) appears in the tokens of the other member's display name, or in
the tokens of the title of a listing that a message of the conversation
names (`messages.listing_id`). It is computed in SQL over the caller's
conversations, without an index: a person has hundreds of conversations,
not millions.

Messages: migration adds

```sql
CREATE INDEX messages_search ON messages USING paradedb (
    id, (body::pdb.simple('ascii_folding=true')), conversation_id, (status::pdb.literal)
);
```

The query is a `paradedb.boolean` with `must`: a term per whole token, a
prefix on the last token (`pdb.phrase_prefix(ARRAY[last])`), status
`sent`, and `conversation_id` among the caller's conversations in scope;
`ORDER BY id DESC`, keyset on `id < cursor`, `LIMIT`. A photo message with
an empty body has no tokens and never matches.

Modules: chat owns the queries (`Service.Search(ctx, account, q, p)
(SearchResult, error)`, returning thread `InboxItem`s and message hits with
`Person`); screen adds the deal summary to the threads through
`dealsvc.PairSummaries` as the inbox view does. `invalid_query` is chat's
error.

## Testing

- trust: report with a matching `conversation_id` stores it; another
  pair's conversation, an unknown one, or one with `listing_id` is
  `invalid_report`; reporting again replaces or clears it.
- chat repository: the flag counts as 1 with nothing new, as n with n new,
  in `Unread` and the inbox; read clears it without moving the marker;
  stream notifies the right accounts (own, other, both).
- notification repository: unread of read notices; the collapse-key rule
  (one unread already, two read of one key, no key); another account's IDs
  are skipped; read-all returns exactly the changed IDs.
- search: accents and case fold (`"giay"` finds `"Giày"`, `"do"` finds
  `"đồ"`), the last word as a prefix (`"ship nh"` finds `"ship nhanh"`), a
  middle word must match whole, blocked pairs and other people's
  conversations are absent, archived ones are present, a processing or
  failed message is absent, the cursor pages, threads match by name and by
  listing title.
- e2e: each new endpoint and status code (the status-coverage check
  requires it).

## Docs

`ARCHITECTURE.md`: Chat (marked unread, search), Trust (report's
`conversation_id`), Notifications (unread and read-all's IDs), Search (the
second BM25 index). The checklist marks the three items done on the server.
