# Design: link read, a prefilled listing from the seller's Chợ Tốt listing

Date: 2026-11-11.
Status: decided in conversation, question by question. When the work lands,
the decisions below go into `~/shopnexus/server/ARCHITECTURE.md` (sections
Assist, Media, Catalog, Stream, Erasure, Infrastructure) and
`~/shopnexus/checklist.md` gains a ticked line for "Đăng tin từ link".

## Why

The app's mockups have a third way to post (`app/.superdesign/mockups/sell-link.html`,
`sell-link-review.html`, described under "Đăng tin từ link" in
`app/.superdesign/design-system.md`): a seller who already listed the item
elsewhere pastes the link to their own listing. A card previews it (photo,
title, price, "chotot.com · 5 ảnh"); "Đọc tin" copies the photos, title,
price and description, drops the phone number from the description, and
opens a draft whose copied photos carry a link badge. Buyers see which
photos were taken in the app and which were copied.

The server has nothing for it. The app is not part of this work.

## Scope

In:

- Chợ Tốt listings only (`chotot.com` and its subdomains), read through its
  public JSON gateway.
- `POST /v1/link-previews`, synchronous, nothing stored.
- `POST /v1/link-reads` and `GET /v1/link-reads/{id}`, a durable read like
  the video read, with a `link_read` update on the stream.
- Copied photos become waiting photo uploads of the seller, posted with
  `POST /v1/listings` like any other.
- `Photo.copied` on listings, set from the upload's origin.
- `VideoReadDraft` renamed `ReadDraft` and shared by both reads.

Out:

- The screenshot route for Facebook group posts ("Ảnh chụp màn hình"). It gets
  its own spec; `LinkRead.source.site` leaves room for it.
- Any other site (Facebook Marketplace, Shopee, arbitrary pages).
- Checking that the listing is the seller's (see Decisions).
- A rate limit on previews.
- The app.

## Decisions

1. **Chợ Tốt only, through `gateway.chotot.com`.** The gateway answers
   `GET /v1/public/ad-listing/{list_id}` without a login, with `subject`,
   `body`, `price`, `images` (URLs on `cdn.chotot.com`), `category_name` and
   structured `parameters` (brand, model, capacity, colour, condition). The
   server calls two fixed hosts only, so it never fetches an address a user
   chose. Any other link is `unsupported_source`. The gateway is public but
   undocumented: Chợ Tốt may change it or block the server at any time, so it
   sits behind its own provider with fixture tests.
2. **The seller's word is trusted.** The app says "Chỉ dán tin của bạn"; the
   server does not compare the listing's owner with the account. Because
   nothing is compared, the server never reads the listing's name, phone,
   address or coordinates: the provider drops them while parsing.
3. **The screenshot route is a later spec.**
4. **Copied photos are marked for buyers.** The server knows for certain
   which photos it copied, so uploads record an `origin` and listings show
   `copied: true` on those photos. It cannot tell a camera photo from a
   gallery one, so only the copied side is marked.
5. **Preview synchronous, read durable.** The preview answers in about a
   second and stores nothing. The read follows the video read: 202, Restate
   steps, a row per read, `link_read` updates and `GET` to follow it. The app
   reuses the video read's waiting model; a slow CDN or model never holds a
   request open, and a retry does not download the photos again.
6. **Defaults taken without a question:** at most the first 10 photos, in the
   listing's order (a listing takes 1 to 10); 30 link reads per account in 24
   hours, counted apart from video reads; a hidden or expired Chợ Tốt
   listing is `listing_not_found`.

## API

### `POST /v1/link-previews`

Request `LinkRequest {url}`: a string of at most 2,048 characters. Signed in,
not suspended. POST rather than GET so the seller's link stays out of access
logs.

200 `LinkPreview`:

```yaml
LinkPreview:
  required: [site, url, title, price, cover_url, photo_count]
  properties:
    site: {type: string, enum: [chotot.com]}
    url: {type: string, format: uri, description: The link, normalised to https://www.chotot.com/<list_id>.htm}
    title: {type: string}
    price: {type: [integer, "null"], format: int64, description: Whole đồng; null when the listing has no valid price.}
    cover_url: {type: string, format: uri, description: The listing's first photo on Chợ Tốt's CDN.}
    photo_count: {type: integer, minimum: 1}
```

Errors: 422 `not_a_link` (not a URL, or not http/https); 422
`unsupported_source` (not `chotot.com` or a subdomain, or no listing ID in
the path); 404 `listing_not_found`; 503 `source_unavailable`.

### `POST /v1/link-reads`

Request `LinkRequest {url}` and an `Idempotency-Key`. 202 with the
`LinkRead`.

Refused at once, as `POST /v1/video-reads` is: a suspended account
(`account_suspended`), an account without a phone (`phone_required`),
`read_limit_reached` 429 (30 link reads in 24 hours), `not_a_link` and
`unsupported_source` 422. Start only parses the link; it does not fetch it.

### `GET /v1/link-reads/{id}`

The read, to its account, until `expires_at`. Any other read is
`link_read_not_found` 404.

### `LinkRead`

```yaml
LinkRead:
  required: [id, status, source, expires_at]
  properties:
    id: {type: string, format: uuid}
    status: {type: string, enum: [reading, done, failed]}
    failure:
      type: string
      enum: [listing_not_found, no_item, unavailable]
      description: |
        Only when failed. listing_not_found: Chợ Tốt has no such listing, it
        is hidden, or none of its photos could be copied; no_item: the
        listing is not one item for sale (a flat, a job); unavailable: Chợ
        Tốt or the model did not answer in time, try again.
    source:
      required: [site, url]
      properties:
        site: {type: string, enum: [chotot.com]}
        url: {type: string, format: uri}
        photo_count: {type: integer, description: Photos on the old listing; set after the read step.}
    photos:
      type: array
      maxItems: 10
      description: The copied photos, in the old listing's order; set after the copy step.
      items:
        required: [upload_id, url]
        properties:
          upload_id: {type: string, format: uuid, description: A photo upload of the caller's.}
          url: {type: string, format: uri, description: The copy, for one hour after this response.}
    draft: {$ref: "#/ReadDraft", description: Set after the copy step, with photos filled.}
    contact_removed:
      type: boolean
      description: Set with the draft; true when a phone number, Zalo or other contact was taken out of the description.
    estimate:
      description: Only when done; null when neither the market nor the model gave a range.
      anyOf: [{$ref: "#/PriceEstimate"}, {type: "null"}]
    expires_at: {type: string, format: date-time}
```

### `ReadDraft`

`VideoReadDraft` is renamed `ReadDraft`; `VideoRead.draft` and
`LinkRead.draft` both use it. `photos` goes from `maxItems: 6` to
`maxItems: 10`; a video read still keeps at most 6 frames. For a link read,
`price` is the old listing's price and `allow_offers` is true when its text
says the price is negotiable ("có thương lượng", "bớt chút").

### Catalog

`Photo` gains `copied: boolean`, required, read only: true for a photo the
server copied from a link. `POST /v1/listings` and `PATCH` do not take it;
the server reads it from the upload.

### Stream

A new update `link_read {link_read_id}`, sent after each save of a read, as
`video_read` is.

## The server

### Provider `internal/provider/chotot`

```go
type Ad struct {
    ListID       int64
    Subject      string
    Body         string
    Price        int64 // 0 when the listing has none
    CategoryName string
    Params       []Param // label and value, without region, area, ward and address
    Images       []string
}

func (c *Client) Ad(ctx context.Context, listID int64) (Ad, error)
func (c *Client) Image(ctx context.Context, url string) ([]byte, string, error)
```

- `Ad` decodes the gateway's `ad` and `parameters` into `Ad` and nothing
  else: `account_name`, `full_name`, `phone`, `address`, `latitude`,
  `longitude`, `seller_info` and the location parameters are never decoded.
  404 is `ErrNotFound`. 5xx, 403, 429 and timeouts are `ErrUnavailable`. A
  body without `subject` or `images` is `ErrFormat`, which is logged as an
  error so a change on Chợ Tốt's side shows.
- `Image` refuses a URL that is not `https://` on `CHOTOT_CDN_HOST`,
  follows no redirect, reads at most 15 MB and returns the content type from
  the magic bytes (JPEG, PNG or WebP). Anything else is `ErrBadImage`.
- One `http.Client` with `ASSIST_CALL_TIMEOUT` per call and a fixed
  `User-Agent`.

### Link parsing (`assist/domain`)

`ParseLink(s)` → `(site, listID, canonical URL)`:

- Not a URL, or a scheme other than http and https: `ErrNotALink`.
- Host `chotot.com` or ending in `.chotot.com`, compared after lowercasing
  and trimming a trailing dot. Anything else, `chotot.com.evil.io` and
  `nhatot.com` included, is `ErrUnsupportedSource`.
- The listing ID is the run of digits that makes up the last path segment,
  with or without `.htm`; query and fragment are ignored. None is
  `ErrUnsupportedSource`.

### Media

- `uploads.origin text NOT NULL CHECK (origin IN ('app', 'frame', 'link'))`.
  The migration marks every existing row `app`; from then on `CreateUpload`
  writes `app`, the video read's frames `frame` and copied photos `link`.
  A frame left unmarked by the migration is at most a day old and expires
  without being posted or is posted as `app`, which is what it already
  showed.
- `SaveFrame(owner, id, jpeg)` becomes `SavePhoto(owner, id, bytes,
  contentType, origin)`: the same rules (the caller mints the ID, a retry
  writes the same object, a photo already taken by a listing is left alone)
  for a frame and for a copied photo. The content type is JPEG, PNG or WebP.
- `MediaProcess`'s result gains `Copied`, true when `origin = link`.
  `ProcessAll` returns it with the keys.

### Catalog

`domain.Photo` gains `Copied bool` (`json:"copied"`), stored in the listing's
`photos` jsonb. Listing processing sets it from `ProcessAll`'s result; an
edit keeps it for photos the listing already has. Existing listings read as
`false`.

### Migration `0037_link_reads.sql`

```sql
CREATE TABLE link_reads (
    id              uuid PRIMARY KEY,
    account_id      uuid NOT NULL REFERENCES accounts (id),
    site            text NOT NULL CHECK (site IN ('chotot.com')),
    url             text NOT NULL,
    list_id         bigint NOT NULL,
    status          text NOT NULL CHECK (status IN ('reading', 'done', 'failed')),
    failure         text CHECK (failure IN ('listing_not_found', 'no_item', 'unavailable')),
    photo_count     integer,
    photos          jsonb,
    draft           jsonb,
    contact_removed boolean,
    estimate        jsonb,
    created_at      timestamptz NOT NULL,
    expires_at      timestamptz NOT NULL,
    write_id        uuid NOT NULL,
    CHECK ((status = 'failed') = (failure IS NOT NULL))
);
CREATE INDEX link_reads_account_created ON link_reads (account_id, created_at);
ALTER TABLE account_updates ADD COLUMN link_read_id uuid;
```

Plus the `uploads.origin` column above. Neither the listing's description as
Chợ Tốt has it nor anything about its seller is stored.

### `LinkRead.Start`

As `VideoRead.Start`, key `<account id>/<Idempotency-Key>`: refuse a
suspended account and one without a phone; insert the row in a transaction
that takes a share lock on the caller's `accounts` row (a tombstone is
`session_revoked`) and `pg_advisory_xact_lock` on the account, and counts
the account's link reads of the last 24 hours (30 is `read_limit_reached`);
send `Expire` with a 24-hour delay and `Run` one way, both keyed by the
read's ID. There is no upload to hold.

### The flow `LinkRead.Run`

A 2-minute deadline from `created_at`. Each step saves the row and notifies
the account with `link_read`. Each step that calls out runs with
`restate.WithMaxRetryDuration` set to the time left and at most 3 attempts.

1. **Read.** One step fetches the ad and calls the LLM, so the listing's
   own description never enters the journal: the step returns the cleaned
   draft (without photos), `contact_removed`, `is_item` and the image URLs
   (the first 10). `ErrNotFound` saves `failed` with `listing_not_found`;
   `is_item = false` or an empty title saves `no_item`; the LLM refusing
   (`llm.ErrRefused`, any 4xx but 429) saves `unavailable` at once; running
   out of time saves `unavailable`.
2. **Copy.** The upload IDs are minted before the step. The step downloads
   each image with `Image` and saves it with `SavePhoto(origin = link)`. An
   image that fails is skipped and logged; none copied saves `failed` with
   `listing_not_found`. The draft's `photos` are the copies in order.
3. **Estimate.** Catalog's `PriceSample` with the draft's text vector and
   the mean of the copies' image vectors, exactly as the video read does,
   through the same helper. It never fails a read: past the deadline or after
   a failure the read ends `done` with the model's range.

### LLM

`ASSIST_LLM_*`, the alias the video read uses. Text only: the prompt gets the
subject, the body, the `parameters` as `label: value` lines, Chợ Tốt's
category name, the subcategory list and the condition scale with its
meanings. A strict schema answers `is_item`, `title`, `category_code`,
`condition`, `specs`, `description`, `allow_offers`, `contact_removed`. The
prompt says:

- The title is the item, not the ad ("iPhone 11 64GB Trắng, pin 81%", not
  "Cần bán gấp…").
- The description restates the seller's text, without phone numbers, Zalo,
  Facebook or other contact, and without names of other platforms. It names
  no mark the text does not name (`app/mohinh.md`, section 1).
- Specs come from the parameters first, then the text.
- `PromptVersion` starts at 1, separate from the video read's.

### Cleaning

The video read's cleaning, shared: an unknown subcategory becomes its root's
`.other`, or nothing when the root is unknown; title cut at 70 characters,
description at 1,500, specs at 20. The price is the ad's `price`, kept when
it is between 10,000 and 1,000,000,000 đồng, else null. After the model, a
regex takes out what still looks like a Vietnamese phone number (`0` or
`+84` then 9 digits, spaces, dots and dashes allowed between them) and sets
`contact_removed`.

### `GET` and `Expire`

`GET` returns the read to its account until `expires_at`; photo URLs are
presigned GETs valid for an hour (`PresignFrame` becomes `PresignPhoto`). A
copied photo posted in a listing loses its original when the listing's photos
are processed, so its URL stops working. `Expire` deletes the row after 24
hours; copies not posted expire with their uploads.

### Preview

`Service.PreviewLink(account, url)`: not a Restate handler. Checks the
account is signed in and not suspended, parses the link, calls `Ad` with
`ASSIST_CALL_TIMEOUT`, and answers from the ad. `ErrUnavailable` and
`ErrFormat` are `source_unavailable` 503. Nothing is stored or published.

### Logging

The read step's line holds the prompt version, the list ID, the photo count,
Chợ Tốt's category name, the category asked for and the one kept, the
condition, the counts of specs and copies, `contact_removed`, the price and
the range, and the time taken. No subject, body or full URL is logged.

### Erasure

Assist deletes an erased account's link reads with its video reads. Copies
not posted expire with their uploads.

### Configuration

New, both required: `CHOTOT_GATEWAY_URL` (`https://gateway.chotot.com`) and
`CHOTOT_CDN_HOST` (`cdn.chotot.com`). In `.env.example`, Compose, the test
helpers and the stack's server Deployment. Egress is already open in the
cluster.

## App

Not part of this work, listed so the API fits:

- The paste field calls `POST /v1/link-previews` once a link is in it;
  `not_a_link` is "Đây không phải link", `unsupported_source` shows the
  sources that work and the screenshot route.
- "Đọc tin" posts the read and follows `link_read` like the video read.
- The draft's photo badges read `copied`, and the listing page shows it to
  buyers.
- The error state for `listing_not_found` is not in the mockup yet.

## Risks

- Chợ Tốt may change the gateway's format or block the server's address.
  The provider's fixture tests catch format drift in CI only against the
  fixture; production drift shows as `ErrFormat` errors in the logs.
- Previews have no limit, so one account can make the server call Chợ Tốt
  as often as it likes. Revisit when the server has a general rate limiter.
- Trusting the seller means a listing of someone else can be copied. The app
  says "Chỉ dán tin của bạn"; a report on the copied listing goes to trust as
  any other.

## Testing

- **Domain:** `ParseLink` (`www.`, `m.`, `xe.chotot.com`, with and without
  `.htm`, query and fragment, upper case, a trailing dot; `nhatot.com`,
  `chotot.com.evil.io`, `ftp://`, no digits refused); cleaning; the phone
  regex (`0976 42x xxx`, `+84 976…`, `zalo 0976…`, a price like
  `4.500.000` left alone).
- **Provider:** `httptest` with a fixture made from a real gateway answer,
  its name, phone, address and coordinates replaced by fake ones before
  commit. 404, 5xx, 429, a body without `subject`; `Image` on another host,
  on `http://`, through a redirect, over 15 MB, with wrong magic bytes.
- **Repository:** `link_reads` against Postgres: the 30-read cap with two
  inserts at once, a `write_id` conflict, an erased account.
- **Service:** against fake Chợ Tốt, LLM and media, as the video read's
  `helpers_test.go` does: the happy path; each failure; a skipped image; no
  image copied; the deadline; a `Notify` after each save; the listing's body
  absent from every step's journaled result.
- **Handlers:** `Idempotency-Key`, another account's read is 404, an expired
  read is 404, the preview's errors.
- **Media and catalog:** `SavePhoto` with each origin; a copy posted with
  `POST /v1/listings` shows `copied: true` and keeps it through an edit; an
  app upload shows `false`.
- `api/spec_test.go` covers the new paths and schemas.
