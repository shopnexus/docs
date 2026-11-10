# Design: account erasure, feedback and search history

Status: decided in conversation on 2026-11-10, question by question. Covers
three rows of `checklist.md` (Tài khoản: "Xoá tài khoản", "Gửi góp ý"; Mua &
tìm kiếm: "Lịch sử tìm kiếm"), server2 only. The app keeps `FakeWorld`; its
contract (`SettingsRepository.deleteAccount`, `sendFeedback`,
`SearchRepository.remember`, `clearHistory`) is what the API serves. Search
history has no restore: `restoreHistory` stays app-side only. When the work
lands, the decisions go into `server/ARCHITECTURE.md` (sections Erasure,
Support, and Search history under Discovery) and the three checklist rows are
ticked, the history row reading "(lưu, xoá)".

## Revisions made while planning

Reading the code for the plan changed these points. Where a later section
disagrees, this list wins.

1. A deleted caller whose access token has not expired gets
   `401 session_revoked` from every write, the answer its revoked session
   already gives at refresh. `409 account_deleted` is only about the other
   person: replying in a conversation with a deleted account, and following
   one. Every write endpoint already documents 401, so no endpoint gains a
   status for the caller's own deletion.
2. `accountsvc.Service.Suspended` becomes `Status(ctx, id) (domain.Status,
   error)`, the status in force now: `active`, `suspended` or `deleted`.
   `domain.Status` gains `StatusDeleted`. There is no separate `Standing`
   type.
3. Opening a deal and requesting COD from a deleted seller need no new
   check: the seller's listings are deleted, and catalog and deal already
   answer for a deleted listing. A buyer's deletion reaches deal through
   the worker.
4. Media does nothing on `account.deleted`: a waiting upload expires within
   a day by `MediaExpire` already.
5. The avatar object stays in the store; removing an avatar today does not
   delete the object either.
6. `search_history` keeps `category` (the chip's label) and `photo_url`
   (the first card's `cover_thumb_url`) as text. The search use case has
   both at hand and neither needs a join at read.
7. `discovery.Service.Search` writes the history itself, so the handler
   still calls one Service method.
8. `GET /v1/console/feedback` is a console route: console's handler calls
   `supportsvc.Service.Feedback`, since `Require` lives in console. Support
   mounts after account and before console.
9. `GET /v1/accounts/me` of a deleted account returns the tombstone with
   `status: deleted` while the token lives (at most 15 minutes).
10. A deleted person shows as `deleted: true` on chat's `Person` and on a
   review's `buyer`; `Account.status` and the console account's `status`
   gain `deleted`. The other summaries name people only on pages a deleted
   account no longer reaches (seller page, listing page, blocks, follows).
11. `account.Erase` writes the account, its credentials, addresses, blocks,
   follows and sessions in one transaction: the second exception to "one
   aggregate per transaction", beside sign-up.

## Decisions

| Question | Decision |
|---|---|
| Open orders when deleting | Refused while the caller has an order `requested` or `shipped`, as buyer or seller: `409 orders_open`. Deals `negotiating` or `agreed` are closed by the deletion. |
| Phone or email after deletion | Free at once: the identities are deleted, so signing in with them makes a new, empty account. |
| Suspended account | Cannot delete itself: `403 account_suspended`, so deleting cannot shed a suspension. |
| Re-authentication | Needs a sign-in within 15 minutes (`428 reauth_required`), as `DELETE /v1/auth/sessions`. |
| What stays | A tombstone `accounts` row (`status = 'deleted'`, no name, bio or avatar), which `orders`, `reviews`, `messages`, `conversations` and `reports` keep pointing to. |
| What others see | Conversations and messages stay with the other person, read-only. Reviews the person wrote stay and count toward the seller's rating, shown anonymous. Completed orders stay for both sides. The seller page is 404. |
| The 12 months the app promises | 12 months after `deleted_at`, the recipient name, phone and street of every order the person bought are blanked. Every order of a deleted account is closed by then, so each closed at least 12 months before. |
| Who reads feedback | Console members (moderator and up) through `GET /v1/console/feedback`. The console page is later work. |
| When history is written | By the server: the first page (no `cursor`) of `GET /v1/search` with `q`, for a signed-in caller. `photo` and `like` searches are not kept. |
| History delete | All at once and one at a time. No restore. |

## Modules

- **`erasure`** (new): one use case, `DeleteAccount`, and the route
  `DELETE /v1/accounts/me`. It sits above `account` and `deal` because
  `deal` imports `account`, so `account` cannot ask `deal` about open
  orders. Mounted after `deal`. No repository, no domain, no worker: it
  calls `dealsvc.Service` and `accountsvc.Service`, as `screen` reads them.
  depguard forbids other modules to import it.
- **`support`** (new): the `feedback` table, `POST /v1/feedback` and
  `GET /v1/console/feedback`. Mounted after `account` and `console`; it
  uses `accountsvc.Service` for `Suspended` and the account summary, and
  console's `handler.Require` for the console route.
- **`discovery`**: search history beside saved listings and search.

Reaction to `account.deleted` lives in each module's worker. The package
`worker` is added to catalog, discovery, media and notification where they
lack one.

## API

### `DELETE /v1/accounts/me` (erasure)

Bearer token. No `Idempotency-Key`: a second call finds the token's session
revoked.

| Status | Code | When |
|---|---|---|
| 204 | | Deleted, or deleted already by an earlier call that raced this one. |
| 401 | `unauthenticated` / `session_revoked` | As every signed-in route. |
| 403 | `account_suspended` | A suspension is in force. |
| 409 | `orders_open` | An order of the caller is `requested` or `shipped`. |
| 409 | `try_again` | The account changed twice during the call. |
| 428 | `reauth_required` | `auth_time` older than 15 minutes. |

### Deleted accounts in other answers

- `Account` and every person summary that embeds it (chat members, review
  author, deal counterpart, console account) gain `deleted: boolean`,
  always present. A deleted one has `display_name: ""` and no
  `avatar_url`, `bio` absent; the client writes "Tài khoản đã xoá".
- `GET /v1/screens/seller/{id}` and `GET /v1/sellers/{id}/listings` answer
  404 `account_not_found` for a deleted account. Its reviews page keeps
  answering, since the reviews are other people's words about orders.
- Sending a message to, opening a deal with, requesting COD from, and
  following a deleted account answer `409 account_deleted`.
- A still-valid access token of a deleted account reaches handlers, since
  the middleware reads no database. Every write already asks
  `accountsvc.Service.Suspended(ctx, id) (bool, error)`; it is replaced by
  `Standing(ctx, id) (accountdomain.Standing, error)`, which answers
  `StandingActive`, `StandingSuspended` or `StandingDeleted` at now. Each
  of its eight callers (and `app.socketAccess`) refuses the last two,
  `account_suspended` and `account_deleted`; a Restate step returns the
  value, as it returns the bool today. Asked about the other person (a
  deal's seller, a message's recipient), `StandingDeleted` is
  `account_deleted` too.
- `GET /v1/accounts/me` of a deleted account is 404 `account_not_found`.

### `POST /v1/feedback` (support)

Bearer token, `Idempotency-Key` (UUID, required). Body `{body: string}`,
1 to 1000 characters after trimming.

| Status | Code | When |
|---|---|---|
| 201 | | `Feedback {id, body, created_at}`; a repeated key returns the first one. |
| 403 | `account_suspended` | A suspension is in force. |
| 409 | `account_deleted` | The account is deleted. |
| 422 | `invalid_feedback` | Empty after trimming, or over 1000 characters. |
| 429 | `feedback_limit_reached` | 10 feedbacks in the last 24 hours. A repeated key is checked first, so a retry of the tenth succeeds. |

### `GET /v1/console/feedback` (support)

Console session, `X-Requested-With: shopnexus-console`, moderator or admin.
`cursor`, `limit` as every list. Newest first. Each item:
`{id, body, created_at, account: {id, display_name, deleted}}`.

### Search history (discovery)

| Endpoint | Answer |
|---|---|
| `GET /v1/search/history` | `200 {items: [SearchHistoryItem]}`, at most 10, newest first, no paging. |
| `DELETE /v1/search/history` | `204`; empties the history. |
| `DELETE /v1/search/history/{id}` | `204`; an unknown or someone else's ID is also 204, as `DELETE /v1/saved/{listing_id}`. |

`SearchHistoryItem`: `{id, query, title, category?, photo_url?, searched_at}`.
`title` is `query` with its first letter upper-cased. `category` is the
display name of the first category the understanding resolved, absent when
none. `photo_url` is the photo of the first result, absent when the search
found nothing.

`GET /v1/search` gains a sentence in its description: a signed-in caller's
first page with `q` is kept in the history. Its schema does not change.

## Data

One migration, `0028_erasure_feedback_history.sql` (0027 is the email sign-in plan's; whichever lands second takes the next free number).

### `accounts`

```sql
ALTER TABLE accounts DROP CONSTRAINT accounts_status_check;
ALTER TABLE accounts ADD CONSTRAINT accounts_status_check
CHECK (status IN ('active', 'suspended', 'deleted'));
ALTER TABLE accounts ADD COLUMN deleted_at timestamptz;
ALTER TABLE accounts ADD CONSTRAINT accounts_deleted
CHECK ((status = 'deleted') = (deleted_at IS NOT NULL)
       AND (status <> 'deleted' OR (display_name IS NULL AND bio IS NULL AND avatar_key IS NULL)));
```

`domain.Account.Delete(now)`: `ErrSuspended` while a suspension is in force
at `now`; on a deleted account nothing changes and it reports so; otherwise
status `deleted`, `deleted_at = now`, name, bio and avatar cleared. A deleted
account refuses `Update`, `Suspend` and `Unsuspend` (`ErrDeleted`). The old
avatar object is removed from the store as a removed avatar is today.

### `feedback`

```sql
CREATE TABLE feedback (
    id          uuid PRIMARY KEY,
    account_id  uuid NOT NULL REFERENCES accounts (id),
    body        text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 1000),
    request_key uuid NOT NULL,
    created_at  timestamptz NOT NULL,
    UNIQUE (account_id, request_key)
);
CREATE INDEX feedback_account_created ON feedback (account_id, created_at);
```

The insert runs under `pg_advisory_xact_lock` on the account: look up the
key, else count the last 24 hours, else insert. Feedback stays when its
account is deleted; the tombstone ties it to no name or number.

### `search_history`

```sql
CREATE TABLE search_history (
    id            uuid PRIMARY KEY,
    account_id    uuid NOT NULL REFERENCES accounts (id),
    query_key     text NOT NULL,
    query         text NOT NULL CHECK (char_length(query) BETWEEN 1 AND 200),
    category_code text REFERENCES categories (code),
    photo_key     text,
    searched_at   timestamptz NOT NULL,
    UNIQUE (account_id, query_key)
);
CREATE INDEX search_history_account ON search_history (account_id, id);
```

`query_key` is the query trimmed, inner spaces collapsed, lower-cased and
stripped of Vietnamese marks (đ to d), the folding the app's `foldVi` does.
One write is one statement: an upsert on `(account_id, query_key)` that sets
a new UUIDv7 `id`, the new `query`, `category_code`, `photo_key` and
`searched_at`, followed in the same transaction by a delete of the rows past
the 10 newest. The query length cap follows `q`'s cap in the search spec.

### Orders

No column changes. The 12-month blanking writes `''` into
`recipient_name`, `recipient_phone` and `recipient_street`, which are
`NOT NULL`; `recipient_commune` stays, a commune code naming no one.

## Flows

### `erasure.DeleteAccount(ctx, caller, authTime)`

1. `authTime` older than 15 minutes: `reauth_required`.
2. `deal.OpenOrders(ctx, caller)` true: `orders_open`.
3. `account.Delete(ctx, caller)`: read, `a.Delete(now)`, `Save` in one
   transaction with: the deletion of `credentials` and its `identities`,
   `addresses`, `account_blocks` either way, `account_follows` either way,
   the revocation of every unrevoked session, and the event
   `account.deleted`. `ErrConflict` reads and tries once more, then
   `try_again`. Deleting the whole `Credentials` aggregate is not the
   identity removal the email sign-in spec rules out: that spec keeps a
   living account's last identity; here the account itself ends.

Accepted race: a buyer requests COD between steps 2 and 3. Deal's worker
cancels it on `account.deleted` (`cancelled_by = system`,
`cancel_reason = listing_closed`) and the buyer is told as for any
cancellation. A `shipped` order cannot appear in the window: only the seller
ships, and a seller who is deleting has no way to call after step 3, while
a ship before step 2 is caught by step 2.

### Reactions to `account.deleted`

Each handler reads nothing it needs from the payload, works on the
account ID alone, and does nothing the second time.

| Module | Handler does |
|---|---|
| catalog | every listing of the seller not `sold` or `deleted` becomes `deleted`, with `listing.deleted` events as a seller's delete writes them |
| deal | deals `negotiating` or `agreed` of the account are closed as a withdrawn deal is; orders `requested` are cancelled as above; then `ScrubRecipients(account)` is sent with `restate.WithDelay(365 days)` and the account ID as idempotency key |
| discovery | deletes the account's `saved_listings` and `search_history` |
| notification | deletes the account's notifications and push tokens |
| media | expires the account's `waiting` uploads |

`deal.ScrubRecipients` is a Restate handler: one `restate.Run` step with
`UPDATE orders SET recipient_name = '', recipient_phone = '',
recipient_street = '' WHERE buyer_id = @account_id`.

### `discovery.Remember`

Called by the search handler after `Search` returned, with the viewer, the
raw `q`, the first resolved category code and the first result's photo key.
A failure is logged at WARN and the search still answers 200. Skipped
signed out, with `cursor`, and with `photo` or `like`.

### `support.SendFeedback`

`Standing` (refuse suspended and deleted), validate, then the repository's
one transaction described under Data.

## Testing

- Repository tests on Postgres (`pgtest`): `Accounts.Delete` with every
  table it touches; `feedback` insert, repeated key, the cap; history
  upsert, move to top, trim to 10, delete one and all, the fold.
- Service tests: `DeleteAccount` for `reauth_required`, `orders_open`,
  `account_suspended`, success, a second call; `pgtest.EventKinds` holds
  one `account.deleted`. `SendFeedback` for the cap and a repeated key.
  `Remember` for the skipped cases.
- Worker tests with `restatetest`: each module's handler run twice on one
  event leaves the same rows.
- e2e: a seller with listings, a deal and a conversation deletes the
  account; the buyer still reads the conversation, a new message is
  `account_deleted`, the seller page is 404, and the phone signs up as a
  new account.
- `make test` (with golangci-lint) and `api/spec_test.go` pass.
