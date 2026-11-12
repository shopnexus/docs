# Design: listing drafts kept on the server

Date: 2026-11-13.
Status: decided in conversation, question by question and section by
section. When the work lands, the server decisions go into
`server/ARCHITECTURE.md` (sections Media, Catalog, Notifications, Erasure,
Stream).

## Why

A seller who starts a listing on one phone and opens the app on another
should find the draft there. Today a draft lives only in the app
(`FakeWorld.drafts`): a new phone, a reinstall or cleared data loses it.
Listings take a while to write (photos, title, price, specs, the model's
read), so sellers finish them later, sometimes on another device.

The app saves locally first, so typing never waits for the network, and
syncs each draft to the server in the background.

## Scope

- **Server:** the `/v1/listing-drafts` resource, the table, drafts holding
  their photos, expiry with a warning notice, posting from a draft,
  erasure.
- **App:** the model fields sync needs, a fake repository that plays the
  phone and the server so every branch can be tried on one device, and the
  labels the draft card and Sell show.
- **Not in scope:** Room or DataStore, an HTTP client, real uploads (the
  app stays on fake data, as in the other specs since 2026-10-26), and
  Superdesign mockups for the new labels.

"Sửa tin" never makes a draft (`FakeSellRepository.saveDraft` requires
`editing == null`), so only drafts of new listings sync.

## Decisions

| Question | Decision |
|---|---|
| Local or server | Both: the app writes locally at once and syncs in the background. Another device sees the draft. |
| How the server stores a draft | Typed where the server needs the field (photos, title, price, revision, times); everything else is a JSON `body` the app owns, with `schema_version`. The server does not validate the body. Posting rules stay in `POST /v1/listings` only. |
| Who mints the ID | The app, a UUIDv7, so a draft made offline has its ID before it reaches the server and a repeated PUT is harmless. |
| Concurrent edits | Optimistic, by `revision`. A stale PUT is `409 draft_conflict`; the app saves its version as a new draft labelled "Bản trên máy này". No dialog, nothing lost. |
| Draft gone on the server | `404 draft_not_found` (deleted, posted or expired elsewhere, or another account's ID). The app saves its version as a new draft when it has unsynced edits, otherwise drops it. |
| Retention | 30 days after the last edit. A notice 3 days before. Photos go with the draft. |
| Limit | 20 drafts per account, `409 draft_limit_reached`. |
| Photo URLs | A presigned GET of the original upload, valid for an hour (`PresignPhoto`). Unposted photos never go under the public `media/`. The app scales every Sell photo to 2048 px on the long side before upload. |
| Schema name | Today's `ListingDraft` schema (the body of `POST /v1/listings` and `PUT /v1/listings/{id}`) becomes `ListingInput`; `ListingDraft` names the new resource. |

## Server

### API

| Endpoint | What it does |
|---|---|
| `PUT /v1/listing-drafts/{id}` | Creates or replaces a draft. 201 on create, 200 on replace. |
| `GET /v1/listing-drafts` | All the caller's drafts as summaries, last edited first. No paging: at most 20. |
| `GET /v1/listing-drafts/{id}` | One draft in full. |
| `DELETE /v1/listing-drafts/{id}` | 204, also when the draft is already gone. |
| `POST /v1/listings` | Takes an optional `draft_id`. |

`PUT` request:

```yaml
ListingDraftInput:
  base_revision: integer   # 0 to create
  schema_version: integer  # >= 1
  title: string            # 0..100 characters, may be empty
  price: integer | null    # VND
  photos: [uuid]           # 0..10 upload IDs, in order
  body: object             # the app's fields, at most 32 KB serialized
```

`ListingDraft` (PUT, `GET /{id}`, and the 409 body):

```yaml
ListingDraft:
  id: uuid
  revision: integer
  schema_version: integer
  title: string
  price: integer | null
  photos: [{ upload_id: uuid, url: string }]   # url presigned, 1 hour
  body: object
  updated_at: date-time
  expires_at: date-time
```

`ListingDraftSummary` (the list): `id`, `revision`, `title`, `price`,
`cover_url` (presigned, null without photos), `photo_count`, `updated_at`,
`expires_at`. The app compares `revision` with its own copy and fetches only
the drafts that changed.

Errors:

- `409 draft_conflict`: `base_revision` is not the stored revision. The
  body carries the stored `ListingDraft`.
- `404 draft_not_found`: no draft of the caller with this ID, for `PUT`
  with `base_revision > 0` and `GET /{id}`. A `PUT` with `base_revision =
  0` on an ID that is another account's is also `draft_not_found`, so an
  ID reveals nothing.
- `409 draft_limit_reached`: a create when the caller has 20 drafts.
- `422 invalid_upload`: a photo that is not the caller's, or neither
  waiting (before its expiry, in the store as declared) nor held.
- `400 invalid_request`: shape rules, from the schema (body over 32 KB
  included).

`POST /v1/listings` with a `draft_id` of another account, or of no draft,
ignores it: the post goes on.

### Table

```
listing_drafts
  id              uuid primary key       -- minted by the app
  account_id      uuid not null references accounts
  revision        bigint not null
  schema_version  int not null
  title           text not null
  price           bigint
  photos          uuid[] not null
  body            jsonb not null
  created_at      timestamptz not null
  updated_at      timestamptz not null
  expires_at      timestamptz not null
  warned          boolean not null default false
index (account_id, updated_at desc)
```

### Writing a draft

`PUT` runs in one transaction:

1. `pg_advisory_xact_lock` on `'drafts:' || account`, then a share lock
   on the caller's `accounts` row; a tombstone is `session_revoked`.
2. Read the draft. Missing with `base_revision > 0`, or another account's:
   `draft_not_found`. Present with a different revision: `draft_conflict`.
   Missing with `base_revision = 0`: count the caller's drafts, 20 or more
   is `draft_limit_reached`.
3. Drop from the incoming list the caller's photos that a listing took or
   that expired (`media.Gone(owner, ids)`); see Photos. Any other photo
   that is not usable is left for `Hold` to refuse.
4. Write the row: `revision + 1`, `updated_at = now`, `expires_at = now +
   30 days`, `warned = false`.
5. `media.Hold(owner, photos)`. A refusal rolls the transaction back and
   answers `invalid_upload`, so no photo is held for a draft that was not
   written.
6. `stream.Notify` with hint `listing_draft`.

After the commit, photos the PUT removed and no other draft of the caller
uses are released (`media.Release`). A crash between the commit and the
release leaves a photo held and never a draft pointing at a released one.
The released photo expires 24 hours later.

A create also sends `DraftExpire.Run(draft_id)` with a 27-day delay and the
draft ID as idempotency key, before the row is inserted, as an upload's
expiry is.

`DELETE` locks as above, deletes the row, notifies the stream, and releases
the photos no other draft uses.

### Photos (module media)

- New upload status `held`: held for its owner's drafts. A photo can be in
  several drafts of one person (a draft and its conflict copy), so a held
  upload has no holder ID; `listing_drafts.photos` records which drafts use
  it.
- `Hold(owner, ids)`, all or none: each upload is the owner's and either
  waiting, before its expiry and in the store as declared, or held already.
  Waiting becomes held. `MediaExpire` deletes only waiting uploads, so a
  held one stays.
- `Release(owner, ids)`: each held upload of the owner goes back to
  waiting and gets a new `MediaExpire` with a 24-hour delay. Not deleted at
  once: another device may hold a conflict copy that names it and will PUT
  it again within the day. An upload that is not held is skipped.
- `Attach` also takes an upload the owner holds, so a listing takes a
  draft's photos as it takes fresh ones.
- `Gone(owner, ids)` returns those of the owner's uploads that are
  attached to a holder, expired, or have no row.
- A photo a listing took leaves every other draft that named it. `GET`
  leaves such photos out of its answer without writing; `PUT` drops them
  before it writes (step 3 above). The app takes the shorter list either
  way.
- A draft's photo URL is `PresignPhoto(id)`, an hour. Nothing is processed
  before the listing is posted; processing strips EXIF then, as it does for
  every listing photo.

### Expiry

Restate service `DraftExpire.Run(draft_id)`, a chain like
`SearchWatchSweep`'s, one pending invocation per draft:

- The draft is gone: the chain ends.
- `expires_at - 3 days` is still ahead (the draft was edited): send the
  next run for that moment.
- Not yet `warned`: in one step set `warned` and write the event
  `listing_draft.expiring`, then send the next run for `expires_at`.
- `expires_at` reached: delete the draft, notify the stream, release the
  photos no other draft uses.

Every step reads the row again, so an edit between steps moves the chain
on rather than deleting a draft that was just edited.

### Notice

Notification hears `listing_draft.expiring` and writes `draft_expiring`:
"Nháp “{title}” sẽ bị xoá sau 3 ngày", or "Nháp tin đăng của bạn sẽ bị xoá
sau 3 ngày" without a title. It opens the draft and collapses on
`draft:<id>`. The worker reads the draft through catalog and tells no one
when the draft is gone or its `expires_at` moved past 3 days away. It is
pushed.

### Posting from a draft

`ListingPost` takes `draft_id`. After the step that attaches the uploads it
runs one more step: delete the draft of the seller with that ID (nothing
when it is gone), notify the stream, and release the draft's photos the
listing did not take and no other draft uses. A refused post leaves the
draft as it was.

### Erasure

Catalog's `account.deleted` worker deletes the account's drafts and
releases their photos, which expire within a day. No stream hint: the
sessions are revoked.

### Stream

Hint `listing_draft` with the draft ID on each write, delete, post and
expiry. An open app on another device reloads the draft list.

## App

### Model

- `ListingDraft` gets:
  - `revision: Long`, the server's revision this copy is based on, 0 before
    the first sync;
  - `sync: DraftSync`, `SYNCED`, `PENDING` (edits not on the server yet) or
    `LIMIT` (the server refused it for the 20-draft limit);
  - `copyOf: DraftId?`, set on a conflict copy.
- A draft's `Photo` carries its `uploadId`, which is what the server knows.
  The other fields of `ListingDraft` go in `body` as they are.
- `DraftCard` gets `expiresAt`, `isCopy` and `sync`.

### Fake repository

`FakeWorld` splits drafts in two:

- `drafts`: this phone's store.
- `serverDrafts`: the server, with revisions, the `base_revision` check,
  the 20-draft limit and expiry.

`saveDraft` writes `drafts` at once with `sync = PENDING`, then syncs by the
server rules above:

- accepted: take the new revision, `SYNCED`;
- `draft_conflict`: keep the server's draft under its ID and save this
  version as a new draft with `copyOf` set;
- `draft_not_found` with unsynced edits: save this version as a new draft;
  without: drop the local copy;
- `draft_limit_reached`: keep it locally with `sync = LIMIT`.

`post(draft)` sends the draft's ID and removes the draft from both stores.
`newestDraft()` reads the merged list, drafts from the other device
included.

`DebugControls` gets "Máy khác sửa nháp", "Máy khác đăng nháp", "Máy khác
xoá nháp", "Mất mạng" (sync waits, drafts stay `PENDING`) and "Tua tới sắp
hết hạn", so every branch can be shown on one phone.

### UI

Labels and messages only, no new screen:

- Draft card in Tin của bạn: "Bản trên máy này" on a conflict copy,
  "Chưa đồng bộ" while `PENDING` or `LIMIT`, "Còn {n} ngày" from 3 days
  before expiry.
- Saving a draft at the limit: the draft stays on the phone and Sell shows
  "Bạn đã có 20 tin nháp. Xoá bớt nháp cũ để lưu nháp này lên tài khoản."
- Home's "Tiếp tục nháp": the newest draft of the merged list.
- The `draft_expiring` notice in Thông báo opens the draft.

## Testing

Server:

- Domain: revision check, the limit, dropping photos a listing took or
  that expired.
- Repository against Postgres: the advisory lock under two concurrent
  creates at 19 drafts, the stream hint, the tombstone refusal.
- Media: `Hold`, `Release`, `Attach` of a held upload, `MediaExpire`
  leaving a held upload alone.
- Flows: `DraftExpire` (moved on by an edit, warns once, deletes),
  `ListingPost` with `draft_id` (deletes the draft, releases the photos the
  listing did not take, a refused post keeps the draft), erasure.
- HTTP: every error above, and `ListingInput` replacing the old schema
  name.

App:

- Fake repository: each sync branch (accepted, conflict, not found with and
  without edits, limit, offline then online).
- ViewModels: the draft card labels and the limit message.
