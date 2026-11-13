# Design: listing drafts kept on the server

Date: 2026-11-13.
Status: decided in conversation. A first, larger design (revisions with
conflict copies, held photos, an expiry chain with a warning notice) was
cut down to this one before planning: drafts are one person's notes, and a
rare lost edit is accepted. When the work lands, the server decisions go
into `server/ARCHITECTURE.md` (sections Media, Catalog, Erasure).

Changed while planning (plan `2026-11-13-server2-listing-drafts.md`):

- A repeated ID in `photos` is kept once instead of refused, so a draft's
  content never leaves it unsynced for good.
- `PUT` can also answer 409 `try_again` when media's save of the extension
  collides with another write of the same upload; the app sends the PUT
  again.
- `MediaExpire`, finding `expires_at` still ahead, sends itself again with
  the idempotency key `<upload id>/<expires_at in Unix seconds>`, since the
  upload ID keyed the first run.
- A suspended account still writes its drafts; only a deleted account is
  refused (`session_revoked`).
- Go renames beyond the schema: `domain.Draft` is `domain.ListingInput`,
  the flows' `PostInput.Draft` and `EditInput.Draft` are `.Listing` (JSON
  `listing`), the handler's `draftBody` is `listingBody`.
- Erasure deletes the drafts inside `Catalog.SellerLeft`, which catalog's
  `account.deleted` worker already calls.

## Why

A seller who starts a listing on one phone and opens the app on another
should find the draft there. Today a draft lives only in the app
(`FakeWorld.drafts`): a new phone, a reinstall or cleared data loses it.

The app saves locally first, so typing never waits for the network, and
syncs each draft to the server in the background.

## Scope

- **Server:** the `/v1/listing-drafts` resource, the table, draft photos
  that outlive the 24-hour upload expiry, lazy deletion after 30 days,
  erasure.
- **App:** the model fields sync needs, a fake repository that plays the
  phone and the server, and two labels and one message.
- **Not in scope:** Room or DataStore, an HTTP client, real uploads (the
  app stays on fake data), mockups.

"Sửa tin" never makes a draft (`FakeSellRepository.saveDraft` requires
`editing == null`), so only drafts of new listings sync.

## Decisions

| Question | Decision |
|---|---|
| Local or server | Both: the app writes locally at once and syncs in the background. Another device sees the draft. |
| Concurrent edits | Last write wins. No revision, no conflict answer. Two devices editing one draft at the same moment can lose one side's edit; accepted. |
| How the server stores a draft | Typed where the server needs the field (photos, title, price, times); everything else is `body`, a JSON string the app owns, with `schema_version`. The server does not read the body. Posting rules stay in `POST /v1/listings` only. |
| Who mints the ID | The app, a UUIDv7, so a draft made offline has its ID before it reaches the server. |
| Retention | 30 days after the last edit. No notice: the draft card shows "Còn {n} ngày" from 3 days before. |
| Deleting expired drafts | Lazily: `GET` and `PUT` delete the caller's expired drafts first. No job. |
| Limit | 20 drafts per account, `409 draft_limit_reached`. |
| Draft photos | Each `PUT` extends its photos' upload expiry to now + 30 days; nothing shortens it. No hold or release. A photo dropped from a draft, or of a deleted draft, stays in the private `uploads/` until its own expiry. |
| Photo URLs | A presigned GET of the original upload, valid for an hour (`PresignPhoto`). Unposted photos never go under the public `media/`. The app scales every Sell photo to 2048 px on the long side before upload. |
| Posting | `POST /v1/listings` does not change. After a post succeeds the app deletes the draft with `DELETE`. If that call fails, the draft stays until the person deletes it. |
| Schema name | Today's `ListingDraft` schema (the body of `POST /v1/listings` and `PUT /v1/listings/{id}`) becomes `ListingInput`; `ListingDraft` names the new resource. |
| Spelling | Vietnamese copy writes "Xóa", as the app does everywhere. |

## Server

### API

| Endpoint | What it does |
|---|---|
| `PUT /v1/listing-drafts/{id}` | Creates or replaces a draft. 201 on create, 200 on replace. |
| `GET /v1/listing-drafts` | All the caller's drafts in full, last edited first. No paging: at most 20. |
| `DELETE /v1/listing-drafts/{id}` | 204, also when there is no such draft of the caller. |

`PUT` request:

```yaml
ListingDraftInput:
  schema_version: integer  # >= 1
  title: string            # 0..100 characters, may be empty
  price: integer | null    # VND, >= 0
  photos: [uuid]           # 0..10 upload IDs, in order
  body: string             # JSON the app owns, maxLength 32768
```

`ListingDraft` (PUT and each item of GET):

```yaml
ListingDraft:
  id: uuid
  schema_version: integer
  title: string
  price: integer | null
  photos: [{ upload_id: uuid, url: string }]   # url presigned, 1 hour
  body: string
  updated_at: date-time
  expires_at: date-time
```

Errors:

- `404 draft_not_found`: `PUT` on an ID that is another account's draft.
- `409 draft_limit_reached`: a create when the caller has 20 drafts.
- `422 invalid_upload`: a photo that is not the caller's photo upload,
  waiting, before its expiry and in the store as declared.
- `400 invalid_request`: shape rules, from the schema.

### Table

```
listing_drafts
  id              uuid primary key       -- minted by the app
  account_id      uuid not null references accounts
  schema_version  int not null
  title           text not null
  price           bigint
  photos          uuid[] not null
  body            text not null
  created_at      timestamptz not null
  updated_at      timestamptz not null
  expires_at      timestamptz not null
index (account_id, updated_at desc)
```

### Use cases

`PUT`, in order:

1. Drop from the incoming list the caller's photos that a listing took or
   that expired (`media.Gone(owner, ids)`).
2. `media.Extend(owner, photos)`. A photo that is not usable is
   `invalid_upload` and nothing is written. An extension whose write then
   fails is harmless: the photo only lives longer.
3. One catalog transaction: `pg_advisory_xact_lock` on `'drafts:' ||
   account`, a share lock on the caller's `accounts` row (a tombstone is
   `session_revoked`), delete the caller's expired drafts, read the draft.
   Another account's: `draft_not_found`. Missing: count the caller's
   drafts, 20 or more is `draft_limit_reached`, else insert. Present:
   update. Either way `updated_at = now`, `expires_at = now + 30 days`.

`GET` deletes the caller's expired drafts, reads the rest, and leaves out of
each draft the photos `media.Gone` names, without writing. Each photo gets
a `PresignPhoto` URL.

`DELETE` deletes the caller's draft with that ID. Its photos expire on
their own.

### Photos (module media)

- `uploads` gets `expires_at`, set to created + 24 hours
  (`domain.ExpireAfter`). `QueryUpload` and every other "before its
  expiry" check read it.
- `Extend(owner, ids)`, all or none: each upload is the owner's photo,
  waiting, before its `expires_at` and in the store as declared, otherwise
  `invalid_upload`. It sets `expires_at = max(expires_at, now + 30 days)`.
  The upload stays `waiting`, so `Attach` takes it for a listing as today.
- `MediaExpire` still wakes 24 hours after the upload. When `expires_at` is
  still ahead it sends itself again for that moment; otherwise it expires
  the upload and deletes its object, as today.
- `Gone(owner, ids)` returns those of the owner's uploads that are
  attached to a holder, expired, or have no row.

### Erasure

Catalog's `account.deleted` worker deletes the account's drafts. Their
photos stay in the private `uploads/` until their own expiry, at most 30
days, where ARCHITECTURE.md says a day today; no URL reaches them once the
drafts are gone.

## App

### Model

- `ListingDraft` gets `synced: Boolean` (false while this phone has edits
  the server lacks) and `expiresAt: Moment?` (the server's, as last read;
  null before the first sync).
- A draft's `Photo` carries its `uploadId` where the app has one.
- `DraftCard` gets `synced` and `expiresAt`.

### Fake repository

`FakeWorld` keeps two stores: `drafts` (this phone) and `serverDrafts` (the
server, with the 20-draft limit and the 30-day expiry).

- `saveDraft` writes `drafts` at once with `synced = false`, then puts the
  draft to `serverDrafts`. Accepted: `synced = true`, `expiresAt` taken.
  `draft_limit_reached`: the draft stays on the phone, unsynced, and the
  call reports the limit.
- Reading the list pulls `serverDrafts`: a draft the server has replaces
  the phone's synced copy; a synced draft the server lacks was deleted
  elsewhere and leaves the phone; an unsynced one is put again.
- Unsynced drafts are put again on the next save, the next pull, after a
  delete frees a slot, and when "Mất mạng" is turned off.
- `post(draft)` posts, then deletes the draft from both stores.
- `newestDraft()` reads the merged list.

`DebugControls` gets "Máy khác sửa nháp" (the server's copy changes and the
phone takes it on the next pull), "Máy khác xóa nháp", "Mất mạng" (puts
wait, drafts stay unsynced) and "Tua tới sắp hết hạn".

### UI

- Draft card in Tin của bạn: "Chưa đồng bộ" while unsynced, "Còn {n} ngày"
  from 3 days before expiry, on one line.
- Saving a draft at the limit: Sell shows "Bạn đã có 20 tin nháp. Xóa bớt
  nháp cũ để lưu nháp này lên tài khoản."
- Home's "Tiếp tục nháp": the newest draft of the merged list.

## Testing

Server:

- Use cases: create, replace, another account's ID, the limit at 20 with
  two concurrent creates at 19, expired drafts deleted on `GET` and `PUT`,
  gone photos dropped, the tombstone refusal.
- Media: `Extend` (moves the expiry out, never in; refuses another
  account's or an expired upload), `MediaExpire` sending itself again while
  `expires_at` is ahead, `Attach` of an extended upload, `Gone`.
- Erasure deletes the drafts.
- HTTP: every error above, and `ListingInput` replacing the old schema
  name.

App:

- Fake repository: save online, save offline then back online, the limit
  and the slot a delete frees, a draft edited and one deleted on the other
  device, post deleting the draft, expiry.
- View models: the card labels and the limit message.
