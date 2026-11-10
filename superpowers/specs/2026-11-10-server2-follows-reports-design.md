# Design: server2 follows and reports

Date: 2026-11-10.
Status: decided in conversation, question by question. When the work lands,
the decisions below go into `~/shopnexus/server/ARCHITECTURE.md` (sections
Blocks, a new Follows beside it, Trust, Notifications and the event list),
and `~/shopnexus/checklist.md` ticks the three items.

## Scope

Three items of `checklist.md`, section 1 ("App có, server chưa có"):

- Báo cáo tin đăng (report a listing)
- Theo dõi người bán (follow a seller)
- Báo cáo người bán (report a seller)

The app already has all three on fake data:

- `ListingRepository.report(id, reason)` and `SellerRepository.report(id,
  reason)`, with `ReportReason { BANNED, FAKE, SCAM, OTHER }` and no text.
  A person is reported from the seller page and from chat, buyers too, so
  "report a seller" is reporting an account.
- `InboxRepository.blockAndReport` returns the report's ID so "Hoàn tác"
  can take it back.
- `SellerRepository.setFollowing(id, on)` and `SellerProfile.following`.
  Nothing else in the app reads a follow yet.

This design gives them a server. It does not wire the app (the app has no
API client yet), and leaves out the console's report queue, automatic
hiding on many reports and "Chặn + báo cáo từ cuộc trò chuyện", each an
item of its own. That last item needs nothing more than this design's
endpoints and `POST /v1/blocks`.

## Decisions

| Question | Decision |
|---|---|
| What following gives | The tie, a list of whom one follows, `viewer.following` on the seller view, a public follower count, and a notice when a followed seller first publishes a listing. |
| Follows and blocks | A block, either way, deletes both follows in its transaction; following is 403 `blocked` while a block stands; unblocking restores nothing. |
| A second report of the same target | One open report per (reporter, target): reporting again returns it with the new reason and note. |
| Note | Optional, 0 to 500 characters. |
| Who reports | A signed-in account that is not suspended. Sign-in is by phone alone (migration 0022), so every account has a verified phone. Nobody reports themselves or their own listing. |
| How a follower hears | A listed notice and a push, collapsing per seller: a newer listing replaces the follower's unread notice of that seller. |
| Where follows live | Module `account`, beside blocks, so a block deletes follows in one transaction. |
| Where reports live | Module `trust`, one table `reports` for listings and accounts. |
| Report endpoint | One: `POST /v1/reports` with `listing_id` or `account_id`. |

## API

### Follows (module `account`)

- `POST /v1/follows {account_id}` → 204. Following again changes nothing.
  - 404 `account_not_found`: no such account.
  - 422 `invalid_follow`: the caller named themselves.
  - 403 `blocked`: either of the two blocks the other.
  - 403 `account_suspended`: the caller is suspended.
  - 409 `follow_limit_reached`: the caller follows 1,000 accounts.
- `DELETE /v1/follows/{account_id}` → 204; an absent follow is fine.
- `GET /v1/follows?cursor=&limit=` → `FollowList`, newest follow first.
  A `Follow` is `{id, account_id, display_name, avatar_url, at}`, named as
  `Block` is; `id` is the follow's UUIDv7, which the cursor pages by.
- `POST /v1/blocks` deletes the follows between the two, both ways.
- `GET /v1/screens/seller/{id}`: `SellerViewer` gains `following`
  (boolean, required); `SellerProfile` gains `followers` (integer,
  required, public).

Any account can be followed, with or without listings: a person who
bought once may sell later.

### Reports (module `trust`)

- `POST /v1/reports`, body `ReportCreate`:
  - exactly one of `listing_id` and `account_id`;
  - `reason`: `banned`, `fake`, `scam` or `other`;
  - `note`: optional, 0 to 500 characters after trimming, as a review's
    text is.

  It answers 201 with a `Report` when it opens one, and 200 with the open
  one when the caller already has an open report of the same target, with
  `reason` and `note` replaced (a missing `note` empties it). A `Report` is
  `{id, listing_id?, account_id, reason, note, created_at, updated_at}`.
  For a listing, the server sets `account_id` to its seller. No
  `Idempotency-Key`: a repeated request lands on the same open report.
  - 422 `invalid_report`: a broken rule, with a field per rule (both or
    neither target, an unknown reason, a note too long).
  - 422 `self_report`: the caller named themselves or their own listing.
  - 404 `listing_not_found`: no such listing, or a deleted one. A hidden,
    reserved, sold or rejected listing can be reported.
  - 404 `account_not_found`.
  - 403 `account_suspended`.
- `DELETE /v1/reports/{id}` → 204: the caller withdraws their report. The
  row stays with `withdrawn_at` set, so a later queue can see who reports
  and takes it back. A report already withdrawn answers 204. Someone
  else's report, or an unknown ID, is 404 `report_not_found`.

No `GET /v1/reports` and no `viewer.reported`: the app reads neither.

## Data

One migration, numbered with the next free number when it is written
(`0025` is planned by `2026-11-10-server2-realtime-ws.md`).

```sql
CREATE TABLE account_follows (
    id          uuid PRIMARY KEY,
    follower_id uuid NOT NULL REFERENCES accounts (id),
    followed_id uuid NOT NULL REFERENCES accounts (id),
    created_at  timestamptz NOT NULL,
    UNIQUE (follower_id, followed_id),
    CHECK (follower_id <> followed_id)
);
CREATE INDEX account_follows_follower ON account_follows (follower_id, id);
CREATE INDEX account_follows_followed ON account_follows (followed_id, id);

CREATE TABLE reports (
    id           uuid PRIMARY KEY,
    reporter_id  uuid NOT NULL REFERENCES accounts (id),
    account_id   uuid NOT NULL REFERENCES accounts (id),
    listing_id   uuid REFERENCES listings (id),
    reason       text NOT NULL CHECK (reason IN ('banned', 'fake', 'scam', 'other')),
    note         text NOT NULL CHECK (char_length(note) <= 500),
    created_at   timestamptz NOT NULL,
    updated_at   timestamptz NOT NULL,
    withdrawn_at timestamptz,
    CHECK (reporter_id <> account_id)
);
CREATE UNIQUE INDEX reports_open_listing ON reports (reporter_id, listing_id)
    WHERE withdrawn_at IS NULL AND listing_id IS NOT NULL;
CREATE UNIQUE INDEX reports_open_account ON reports (reporter_id, account_id)
    WHERE withdrawn_at IS NULL AND listing_id IS NULL;
CREATE INDEX reports_account ON reports (account_id, created_at);
```

- A follow runs under `pg_advisory_xact_lock` on the follower, which keeps
  the 1,000 cap, as the address book keeps its 10.
- The follower count is `COUNT(*)` over `account_follows_followed`; no
  counter column yet.
- A report writes with `INSERT … ON CONFLICT … DO UPDATE` on the partial
  index of its kind, so two reports at once make one row. When the
  console later resolves reports, `resolved_at IS NULL` joins both index
  predicates.
- `reports_account` lets the queue gather every report about a person,
  through their listings too.
- The block statement and the follow deletes run in one transaction in
  `repository.Accounts`.

## A followed seller's new listing

1. **catalog.** `Listing.Published` tells whether this is the listing's
   first publication (`publishedAt` was nil). On the first, the
   `listing.published` event carries the payload `first: true`. A
   listing that goes back through processing after an edit or a rejection
   publishes without it. The seller's own notice stays as it is.
2. **`NotificationWorker.ListingPublished`** tells the seller as today.
   With `first`, it reads the seller's followers through a new
   `accountsvc.Followers(seller, page)`, 500 per step, and for each sends
   the one-way call `NotificationWorker.TellFollower` with the idempotency
   key `<event id>/<follower id>`, so a replay sends nobody a second call
   and each invocation's journal stays short.
3. **`TellFollower`** reads `catalog.Summary` in one step. A listing that
   is no longer `active` (hidden, reserved, sold, deleted) tells no one.
   Otherwise it writes one notice through `tell`:
   - type `followed_listing`, params `seller_name`, `title`, `listing_id`;
   - text "**{seller_name}** vừa đăng tin mới: {title}", opening the
     listing;
   - collapse key `seller:<seller id>`: a newer listing replaces the
     follower's unread notice of that seller and moves it up, a read one
     stays, and the existing guards on late and repeated events hold;
   - a push with that tag, by the push rules of Notifications.
4. No block check at send time: a block has deleted the follows.

## Testing

TDD, every test through `make test`.

- **domain**: report rules (one target, reason, note length, self);
  `Listing.Published` marks only the first publication, not one after a
  rejection or an edit with new photos; `followed_listing`'s text and
  target.
- **repository (pgtest)**:
  - follows: following twice, the cap under concurrent follows, a block
    deleting both directions, the count, paging;
  - reports: the upsert on each partial index, two concurrent reports
    making one row, a new row after a withdrawal.
- **service**: each error of the API above; a listing report taking its
  seller as `account_id`; withdrawing someone else's report.
- **worker (restatetest)**:
  - a first publication tells every follower across more than one page;
  - an edit tells no one;
  - a listing hidden before `TellFollower` runs tells no one;
  - a redelivered event adds no notice;
  - two listings in a row leave one unread notice.
- **screen**: `viewer.following` and `seller.followers` on the seller view.
- **e2e**: `follow_test.go` and `report_test.go` over HTTP;
  `api/spec_test.go` covers the new spec.
