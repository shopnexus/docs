# Design: listing reads, one resource for reading a video, a photo or a link into a draft

Date: 2026-11-11.
Status: decided in conversation, question by question. When the work lands,
the decisions below go into `~/shopnexus/server/ARCHITECTURE.md` (sections
Assist, Stream, Erasure, Infrastructure) and `~/shopnexus/checklist.md`
ticks "AI đọc ảnh (không có video) để tự điền tin đăng" and rewrites the
video read's line to name `/v1/listing-reads`.

## Why

The server reads a seller's video (`/v1/video-reads`, spec
`2026-11-10-video-read-design.md`) and their Chợ Tốt listing
(`/v1/link-reads`, spec `2026-11-11-server2-link-read-design.md`) into a
draft. The app also posts from photos alone, and that path still runs on
`FakeSellRepository.readPhotos`. A photo read costs far less than a video
read: one image, no speech to text, no ffmpeg.

Three reads with one life (202, Restate steps, a row, a stream update, `GET`)
behind two resources, and a third on the way, is the overlap
`server/CLAUDE.md` asks to redesign in one change. The app is not wired to
any of them yet, so renaming costs nothing outside the server.

The app's sell screens were redesigned with this (Superdesign drafts
`sell-steps` v15, `sell-video` v9, `sell-review` v23): the photo path reads
the cover only and offers "Điền lại theo ảnh này" when the cover changes;
the camera shows captions from the phone's own speech recognizer; the review
screen shows the upload's share, then a quiet wait, then the filled draft,
and one pane per failure.

## Scope

In:

- `POST /v1/listing-reads` and `GET /v1/listing-reads/{id}`, replacing
  `/v1/video-reads` and `/v1/link-reads`; a `listing_read` stream update
  replacing `video_read` and `link_read`.
- The photo read: Restate service `PhotoRead`, its prompt and cleaning.
- The video read takes an optional transcript from the phone and skips
  speech to text when it has one.
- One table, `listing_reads`, with each source's own columns; a cap per
  source.
- LiteLLM alias `video-read` renamed `listing-read`.

Out:

- `POST /v1/link-previews` stays as it is: a synchronous preview, not a read.
- Live captions or recognition on the server.
- Reading more than the cover of a photo listing.
- The app (its changes are listed under "App"; they are their own plan).
- Keeping a seller's video on the listing (the review screen's video tile is
  an open app question).

## Decisions

| Question | Decision |
|---|---|
| Resource | One: `/v1/listing-reads`, body `{video, transcript?}`, `{photo}` or `{link}`. The response has `source` and each source's own fields. |
| Restate | One service per source: `VideoRead`, `PhotoRead`, `LinkRead`. Each `Start` and `Run` reads top to bottom (`server/CLAUDE.md`), and a new source is a new service plus a new `source` value. They share the table, the entity, the cap, the cleaning helpers and the estimate. |
| Caps | Per source, in 24 hours: 30 video reads, 60 photo reads, 30 link reads. |
| What a photo read reads | The one photo it is given; the app sends the cover. A changed cover is read again only when the seller taps "Điền lại theo ảnh này", which is a new read and counts. |
| Photo description | The model writes a short description of what the photo plainly shows, and never names a mark, scratch, crack, stain or fault. |
| Photo read and the photo | The read does not hold or consume the photo: the listing posts it. |
| Transcript from the phone | The app sends what Android's `SpeechRecognizer` heard. With one, the server runs no speech to text; empty or absent, it runs gipformer on the video's sound as today. The video always keeps its sound. |
| Trust in that transcript | Taken as the seller's words, at most 1,000 characters, read as plain text inside the prompt's fence. The seller could type the same words into the description, so a forged transcript gains nothing. |
| Transcript retention | Held in the database only while the read runs and set to NULL when it ends. Never logged, never returned, never in a Restate journal. |
| Failure codes | One list for every source: `unreadable`, `video_too_short`, `video_too_long`, `listing_not_found`, `no_item`, `unavailable`. `unreadable_video` becomes `unreadable`. |
| Old rows | Reads live 24 hours and the app is not wired: the migration copies the rows of `video_reads` and `link_reads` and drops the tables. A run of the old code still in flight during the deploy fails its save and ends; nobody waits on it. |

## API

### `POST /v1/listing-reads`

Requires an `Idempotency-Key`. The body is one of:

```yaml
ListingReadRequest:
  oneOf:
    - $ref: "#/VideoReadRequest"   # {video: uuid, transcript?: string}
    - $ref: "#/PhotoReadRequest"   # {photo: uuid}
    - $ref: "#/LinkReadRequest"    # {link: string}: LinkRequest's url, renamed in the read's body
```

- `video`: a video upload of the caller's, uploaded and not read yet.
  `transcript`: at most 1,000 characters after trimming; longer is
  `invalid_transcript` 422. Empty means none.
- `photo`: a photo upload of the caller's in status `waiting`: uploaded, not
  attached to a listing yet, not expired. Any other is `invalid_upload`.
- `link`: what `/v1/link-reads` took as `url`, at most 2,048 characters.
  `POST /v1/link-previews` keeps `LinkRequest {url}`.

It answers 202 with the `ListingRead`, status `reading`. A body with none
or more than one of `video`, `photo`, `link` is `invalid_request` 400.
Checks, in order: for a link first `not_a_link` and `unsupported_source`
(as today); then `account_suspended` 403, `phone_required` 403,
`read_limit_reached` 429 (the source's cap); then `invalid_upload` 422 for a
video or a photo.

### `GET /v1/listing-reads/{id}`

The read as it is now, to its account until `expires_at`; otherwise
`listing_read_not_found` 404.

### `ListingRead`

```yaml
ListingRead:
  required: [id, source, status, expires_at]
  properties:
    id: uuid
    source: {enum: [video, photo, link]}
    status: {enum: [reading, done, failed]}
    failure: {enum: [unreadable, video_too_short, video_too_long, listing_not_found, no_item, unavailable]}
    link: LinkSource          # link only: site, url, photo_count
    photos: [ReadPhoto]       # video: the frames the server took (up to 8);
                              # link: the copies (up to 10);
                              # photo: the photo read. Absent until the step that makes them.
    draft: ReadDraft          # as today; a photo read's draft has photos = [photo], price null, allow_offers false
    contact_removed: boolean  # link only
    estimate: PriceEstimate | null
    expires_at: date-time
```

`ReadPhoto` is `{upload_id, url, at_seconds?}`: `VideoReadFrame` and
`LinkReadPhoto` merged, `at_seconds` only for a video's frames. Which
failures a source can end with: video `unreadable`, `video_too_short`,
`video_too_long`, `no_item`, `unavailable`; photo `unreadable`, `no_item`,
`unavailable`; link `listing_not_found`, `no_item`, `unavailable`.

The schemas `VideoRead`, `VideoReadFrame`, `LinkRead` and `LinkReadPhoto` go;
`ReadDraft`, `LinkSource` and `PriceEstimate` stay.

### Stream

`Update.kind` gains `listing_read` with `listing_read_id`, and loses
`video_read` and `link_read` with their ID fields.

## The server

### Domain

`domain.ListingRead` replaces `VideoRead` and `LinkRead`: the common fields
(ID, account, status, failure, photos, draft, estimate, times, write ID) and
a `Source`. Constructors `NewVideoRead(id, account, video, now)`,
`NewPhotoRead(id, account, photo, now)` and `NewLinkRead(id, account, link,
now)` set the source's part: `media` for video and photo, `link` and
`photoCount` for link, `contactRemoved` once a link's draft is set.
`Fail(at, failure)` refuses a failure its source cannot end with.

`domain.Caps` holds the three caps; `ErrReadLimit` keeps its code
`read_limit_reached` and says "at most N reads of this kind in 24 hours".

### Migration `0039_listing_reads.sql`

```sql
CREATE TABLE listing_reads (
    id              uuid PRIMARY KEY,
    account_id      uuid NOT NULL REFERENCES accounts (id),
    source          text NOT NULL CHECK (source IN ('video', 'photo', 'link')),
    media_id        uuid,                 -- video and photo: the upload read
    link_site       text CHECK (link_site IN ('chotot.com')),
    link_list_id    bigint CHECK (link_list_id > 0),
    link_url        text,
    link_photos     integer CHECK (link_photos > 0),
    transcript      text,                 -- video only, only while reading
    status          text NOT NULL CHECK (status IN ('reading', 'done', 'failed')),
    failure         text CHECK (failure IN ('unreadable', 'video_too_short', 'video_too_long',
                                            'listing_not_found', 'no_item', 'unavailable')),
    photos          jsonb,
    draft           jsonb,
    contact_removed boolean,
    estimate        jsonb,
    created_at      timestamptz NOT NULL,
    expires_at      timestamptz NOT NULL,
    write_id        uuid NOT NULL,
    CHECK ((status = 'failed') = (failure IS NOT NULL)),
    CHECK ((media_id IS NOT NULL) = (source IN ('video', 'photo'))),
    CHECK ((link_site IS NOT NULL AND link_list_id IS NOT NULL AND link_url IS NOT NULL) = (source = 'link')),
    CHECK (transcript IS NULL OR (source = 'video' AND status = 'reading')),
    CHECK ((contact_removed IS NOT NULL) = (source = 'link' AND draft IS NOT NULL))
);
CREATE INDEX listing_reads_account_source_created ON listing_reads (account_id, source, created_at);
```

It then copies `video_reads` (failure `unreadable_video` as `unreadable`,
`frames` into `photos`) and `link_reads` (the draft's photos into `photos`),
drops both tables, renames `account_updates.video_read_id` to
`listing_read_id`, moves `link_read_id` into it, sets `kind` to
`listing_read` on those updates and drops `link_read_id`.

The transcript's waiting room:

```sql
-- The phone's transcript between the request and the read's insert, so it
-- never enters a Restate journal. The insert moves it into listing_reads
-- and deletes it; a row older than 10 minutes is deleted by the next insert.
CREATE TABLE listing_read_transcripts (
    account_id  uuid NOT NULL REFERENCES accounts (id),
    request_key text NOT NULL,
    text        text NOT NULL CHECK (length(text) BETWEEN 1 AND 1000),
    created_at  timestamptz NOT NULL,
    PRIMARY KEY (account_id, request_key)
);
```

### Repository

`ListingReads` replaces the two repositories: `Insert` (through
`insertCapped`, now counting `WHERE account_id = @account AND source =
@source`), `Get`, `Save` (with the write ID, as today), `Delete`, and
`DeleteAccount` for erasure. `Insert` of a video read moves the waiting
transcript of `(account, request_key)` in the same transaction and deletes
waiting rows older than 10 minutes. `Save` of an ended read writes
`transcript = NULL`. `Transcript(ctx, id)` reads it for the fill step.
Every save notifies the account with `listing_read`.

### Handler and service

`POST /v1/listing-reads` decodes the body, refuses a body with none or more
than one of `video`, `photo`, `link`, and calls
`StartVideoRead`, `StartPhotoRead` or `StartLinkRead`. For a video with a
transcript, `StartVideoRead` first upserts it into
`listing_read_transcripts` under the caller and the `Idempotency-Key`, then
calls `VideoRead.Start` with only the IDs. `GET` reads the row and builds one
view for every source.

### `VideoRead`

As today, with these changes:

- `Start` passes the request key to `Insert`, which takes the transcript in.
- The fill step reads the transcript with `Transcript`. With one, it skips
  `STT.Transcribe`. Empty, it transcribes as today.
- The user prompt says where the transcript came from. The phone's
  recognizer writes capitals and some punctuation; gipformer writes lower
  case without punctuation. Both may mishear brands, models and numbers.
  `PromptVersion` becomes 2.
- The fill's log line adds `transcript_from` (`phone`, `server` or `none`).

### `PhotoRead`

`Start` (key `<account>/<Idempotency-Key>`) refuses a suspended account and
one without a phone, as the video read does; checks the photo with media
(the caller's, a photo, `waiting`; else `invalid_upload`); inserts the row under the photo cap; sends `Expire`
with a 24-hour delay and `Run` one way. It holds nothing.

`Run`, with the video read's 2-minute deadline and step bounds:

1. Fill: `Media.QueryImage(account, photo)` at 768 px (not found is
   `unreadable`), the categories, then the LLM with the photo prompt and
   `domain.PhotoAnswerSchema`. `domain.CleanPhoto` cleans the answer like
   `Clean` does, without kept frames or a price: the draft's photos are
   `[photo]`, `price` null, `allow_offers` false. `is_item = false` or an
   empty title is `no_item`. Saves the draft and `photos`.
2. Estimate: the shared helper in `estimate.go`, with the draft's text and
   the photo's vector. Never fails the read; the read ends `done`.

`Expire` deletes the row after 24 hours.

The photo prompt (`photo_read_prompt.go`, `PhotoPromptVersion` 1) asks for
`is_item`, `title`, `category_code`, `condition` (judged from the photo),
`specs` (only what the photo shows clearly), `description` and `estimate`.
The description is at most 300 characters, in Vietnamese, of what the photo
plainly shows (the item, its colour, what comes with it in the frame), and
never names a mark, scratch, dent, crack, stain or fault, nor anything the
photo cannot show (age, use, repairs, battery health). The fill's log line
holds the prompt version, the category asked for and kept, the condition,
the count of specs, the description's length, the range and the time taken.

### `LinkRead`

Unchanged in what it does; it writes to `listing_reads` with source `link`
and its photos into `photos`.

### Erasure

The worker on `account.deleted` deletes the account's `listing_reads` and
`listing_read_transcripts`.

### Configuration

No new variable. The photo read uses `ASSIST_LLM_*` and
`ASSIST_CALL_TIMEOUT`.

## Cluster

The LiteLLM alias `video-read` becomes `listing-read`: `infra/stack/values.yaml`,
`_server-env.tpl`, the chart tests, `infra/smoke-models.hurl`,
`infra/cmd/seal`, and the LLM gateway pages of `docs/web` (en and vi).

## App

Its own plan, after this lands; the app still runs on fakes.

- `camera-video`: record an mp4 with sound (`Recorder`, `withAudioEnabled`);
  `FrameGrabber` and the app's own frame cutting go.
- `SpeechRecognizer` beside the recording for the captions and the
  transcript; a phone without one records only.
- One `ListingRead` model following the API, replacing `PhotoReading` and
  `VideoReading`; `storage` and `color` give way to `specs`.
- The photo path reads the cover on the first photos of a new listing, and
  "Điền lại theo ảnh này" when the cover differs from the one read.
- The fakes play the server's steps and failures.

## Testing

- Domain: `NewPhotoRead` and `Fail`'s per-source failures; `CleanPhoto`
  (no kept frames, no price, the description's cap, `no_item`).
- Repository: the cap counts each source apart; a video insert takes its
  waiting transcript in and deletes it, and prunes rows past 10 minutes; an
  ended save leaves `transcript` NULL; the CHECKs refuse a photo row with a
  transcript or a link row without its link.
- Migration: rows of both old tables arrive whole, with `unreadable_video`
  as `unreadable`, and their updates read `listing_read`.
- Service: a video read with a transcript calls no speech to text and gives
  the model the transcript; one without calls it; a photo read fills from
  one image and ends `done`; another account's photo, a video upload and an
  attached photo are `invalid_upload`; the 61st photo read
  in 24 hours is `read_limit_reached` while a video read still starts.
- Handler: a body with two sources or none is 400; a transcript of 1,001
  characters is 422.
- e2e: `listing_read_test.go` replaces `video_read_test.go` and the link
  read's e2e, and adds a photo read from upload to done.
- The transcript never appears in a log line, a response or a journaled
  step result (checked in review, as the link read's body is).
