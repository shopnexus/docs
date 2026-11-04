# Design: server2 catalog core and media

Date: 2026-10-26.
Status: decided in conversation, question by question and section by
section. When the work lands, the decisions below go into
`~/shopnexus/server2/ARCHITECTURE.md`.

## Scope

The first part of the catalog: a seller posts, edits, hides, marks sold and
deletes a listing with photos, and anyone views an active listing. The
design follows server2's conventions and what app2 needs
(`app2/core/data/.../Repositories.kt`, `specs/2026-10-16-app2-stage4-sell-design.md`,
`specs/2026-10-17-app2-cod-only-design.md`); the old server's catalog is not
a template. A listing is one item at one price, C2C, cash on delivery.

Later parts, each with a spec of its own: search and filters, saves,
reports, view and save statistics, boosts, similar listings, AI-filled
drafts, the reserved state (with module order), and moderation.

## Decisions

| Question | Decision |
|---|---|
| First part | The listing core: categories, posting, editing, hiding, marking sold, deleting, photos, the seller's panes, the detail view, events. |
| Photo upload | The app asks for a presigned URL and PUTs the photo to object storage; a Restate flow then processes it. |
| Object storage | RustFS, through its S3 API. |
| Categories | A table loaded by a migration: 8 roots, each with subcategories. |
| Drafts | On the device only. The server receives a listing when the seller posts it, complete. |
| Who may post | An account that is not suspended and has a verified phone number, with at most 20 listings on sale or hidden. KYC replaces the phone rule when it exists. |
| Location | A commune from the administrative list (province and commune, after the 2025 merger), stored with the commune's centroid. The seller's real position is never stored. |
| Photo formats | JPEG, PNG and WebP, processed in pure Go. The app converts HEIC to JPEG before uploading. |
| Uploads | A module of their own, `media`, which chat, KYC and avatars will reuse. |
| Bucket | One bucket: `uploads/` private, written through presigned URLs; `media/` public-read, holding processed photos. |

## API

### Uploads (module media)

`POST /v1/uploads` (signed in), body `{content_type, size}`:

- `content_type` is `image/jpeg`, `image/png` or `image/webp`; `size` is at
  most 15 MB.
- 201 `{upload_id, url, headers, expires_at}`. The app PUTs the photo to
  `url` with `headers` before `expires_at` (15 minutes). The presigned
  request fixes the content type and length.
- An upload not attached within 24 hours is deleted.

### Listings (module catalog)

| Endpoint | Purpose |
|---|---|
| `POST /v1/listings` (signed in, `Idempotency-Key`) | Post a listing, complete. 201 with the listing in `processing`. |
| `PATCH /v1/listings/{id}` | Edit title, price, description, condition, category, commune, photos, marks, specs, `allow_offers`. New photos send the listing back through processing. |
| `POST /v1/listings/{id}/hide`, `/unhide` | Hide an active listing, show a hidden one. |
| `POST /v1/listings/{id}/mark-sold`, `/unmark-sold` | Record a sale made off the app, or undo it. |
| `DELETE /v1/listings/{id}` | Delete (soft). |
| `GET /v1/me/listings?pane=on_sale\|sold` | The seller's panes: `on_sale` holds processing, active, hidden and rejected; `sold` holds sold. Cursor pagination. |
| `GET /v1/listings/{id}` | Detail. Anyone sees an active listing; the owner also sees it in any other state but deleted; anyone else gets 404. |
| `GET /v1/categories` | The category tree. |
| `GET /v1/regions` | Provinces. |
| `GET /v1/regions/{province_code}/communes` | Communes of a province. |

Posting checks, in order: account suspended (403 `account_suspended`), no
verified phone (403 `phone_required`), 20 listings on sale or hidden (409
`listing_cap_reached`), then the fields (422 `invalid_listing` with one
entry per field). An action on someone else's listing is 404
`listing_not_found`. An action the state does not allow (hide a sold
listing, mark a processing one sold, edit a deleted one) is 409
`listing_state_conflict`. A hidden listing may be marked sold (decided
2026-10-26). An upload that is not the caller's, not waiting,
or not uploaded yet is 422 `invalid_upload`.

## Data

### Listing

| Field | Rule |
|---|---|
| `id`, `seller_id` | UUIDv7; the seller is an account. |
| `title` | 1–70 characters after trimming. |
| `price` | Whole đồng, at least 10,000. |
| `description` | At most 1,500 characters; may be empty. |
| `category_key` | A level-2 category. |
| `condition` | `new`, `like_new` or `used`. |
| `allow_offers` | Boolean. |
| `commune_code` | A commune of the administrative list. |
| `photos` | 1–10, ordered; the first is the cover. Each holds its upload ID and, once processed, the keys of the photo and its thumbnail. |
| `marks` | Up to 10 declared flaws, each `{text (1–200), photo}` with an optional photo. |
| `specs` | Up to 20 `{label, value}` pairs, each 1–50 characters. |
| `status` | See below. |
| `rejection` | Per photo, why processing failed; only with `rejected`. |
| `write_id`, `created_at`, `updated_at`, `published_at`, `sold_at`, `deleted_at` | |

Status:

```
processing ──photos ready──► active ◄──unhide── hidden
     │                         │ ──hide──────────►  │
     └─a photo failed─► rejected     │               │
                          │       mark-sold      mark-sold
                       edit          ▼               ▼
                          └──► processing        sold ──unmark-sold──► active
any state but deleted ──delete──► deleted
```

Only `active` listings are public. An edit of `active` or `hidden` that
changes no photo keeps the status; an edit that adds photos moves the
listing to `processing`, and it returns to `active` (or `rejected`) when
they are done. An edit of `rejected` goes to `processing`. `sold` and
`deleted` cannot be edited.

### Tables

- `listings` with the fields above; photos, marks and specs as `jsonb`
  columns in the listing row, since they are always read and written with
  it.
- `categories (key PK, parent_key, name, position)`, loaded by the
  migration with app2's 8 roots (phones, laptop, fashion, furniture, home,
  vehicles, sports, baby) and their subcategories, each root ending with
  "Khác", plus a root "Khác".
- `provinces (code PK, name)` and `communes (code PK, province_code, name,
  lat, lng)`, loaded by a migration from an official source of the 2025
  administrative units with centroids. Finding that source is a task of
  the plan; a commune without a centroid is not loaded.
- `uploads` (module media): `id, owner_id, content_type, size, status
  (waiting, attached, ready, failed, expired), key, photo_key, thumb_key,
  failure, write_id, created_at`.

## Processing

1. `POST /v1/uploads` creates an `Upload` in `waiting` and sends
   `Media.Expire(upload_id)` to Restate with a 24-hour delay.
2. The app PUTs the photo to `uploads/<id>`.
3. `POST /v1/listings` checks the fields, calls `media.Attach(owner,
   upload_ids)` (owned by the caller, `waiting`, object present) for the
   listing's photos and its marks' photos, saves the listing in
   `processing`, and sends `ListingPublish.Run(listing_id)` to Restate. No
   event yet: a listing in processing is not public.
4. `MediaProcess.Run(upload_id)`, one Restate invocation per photo, each a
   step of `restate.Run`: read the object; check its magic bytes against
   the content type and its size against 40 megapixels before decoding;
   decode; encode a JPEG at most 1600 px on the long side and a 400 px
   thumbnail, which drops every EXIF field, GPS included; write both under
   `media/`; delete the original; mark the upload `ready` or `failed` with
   the reason.
5. `ListingPublish.Run` calls `MediaProcess` for each photo, marks'
   photos included, and waits for all of them. All ready: the listing moves to `active`, records the
   photo keys and publishes `listing.published`. One failed: it moves to
   `rejected` with the reasons.
6. `Media.Expire` deletes an upload still `waiting`, and its object;
   anything else it leaves.

## Events

`listing.published`, `listing.updated`, `listing.hidden`,
`listing.unhidden`, `listing.sold`, `listing.unsold`, `listing.deleted`,
written in the transaction of the change. No module subscribes yet; search
and recommendations will.

## Modules

```
internal/platform/objectstore/  S3 client for RustFS: presign PUT, get, put, delete
internal/media/
  domain/  repository/  service/ (Media; media_process_durable.go, media_expire_durable.go)
  handler/ (POST /v1/uploads)
internal/catalog/
  domain/  repository/  service/ (Catalog; listing_publish_durable.go)
  handler/
```

`catalog/service` takes `accountsvc.Service` (suspended), `authsvc.Service`
(a new `HasPhone(account_id)`) and `mediasvc.Service`. Configuration adds
`OBJECT_STORE_ENDPOINT`, `OBJECT_STORE_REGION`, `OBJECT_STORE_ACCESS_KEY`,
`OBJECT_STORE_SECRET_KEY`, `OBJECT_STORE_BUCKET` and `MEDIA_PUBLIC_URL`,
none with a default. RustFS joins the development and test stacks at its
newest release.

## Tests

- Repositories on Postgres, including save-twice.
- Services on Postgres and the test stack's RustFS.
- `MediaProcess` and `ListingPublish` with `restatetest`: a valid JPEG, a
  PNG and a WebP; a file whose bytes are not its content type; a photo
  over 40 megapixels; a JPEG with GPS EXIF, whose output has no EXIF; a
  listing with one failed photo ends `rejected`.
- e2e: upload, post, the listing turns `active`, a buyer sees it; the
  posting refusals; hide, unhide, mark sold, unmark, delete; someone
  else's listing is 404.
