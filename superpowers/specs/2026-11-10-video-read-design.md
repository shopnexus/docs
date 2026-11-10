# Design: video read, a prefilled listing from a seller's video

Date: 2026-11-10.
Status: decided in conversation, question by question. When the work lands,
the decisions below go into `~/shopnexus/server/ARCHITECTURE.md` (sections
Media, a new Assist, Stream, Erasure, Infrastructure), `~/shopnexus/ai/README.md`,
and `~/shopnexus/checklist.md` ticks "AI đọc ảnh/video để tự điền tin đăng".

## Why

The app's sell flow starts with a video: the seller films the item, turns it
round, switches its screen on and says the price. The app then shows "AI đang
xem video", findings appearing one by one, and a draft with the fields the AI
filled marked by a sparkle. Today all of it runs on `FakeSellRepository`.

Part 1 (`2026-11-09-ai-stt-gateway-design.md`) built speech to text in `ai`
and the LiteLLM alias `stt`. This spec is its part 2: the server takes the
video and returns everything the draft screen needs.

## Scope

In:

- Video uploads through the existing presigned upload.
- `POST /v1/video-reads` and `GET /v1/video-reads/{id}`, a `video_read`
  update on `/v1/ws`.
- `ai`'s `POST /v1/video/frames`.
- A new server module, `assist`, with the Restate flow `VideoRead`.
- Photos to the LLM in `internal/provider/llm`.
- A price range from similar listings, or from the model when the market has
  too few.
- LiteLLM alias `video-read` and key `server-assist`; compose and chart wiring.

Out:

- The app's "Giá" step: market strip, similar listings, buyers waiting,
  "Bán nhanh" and "Giá thị trường" suggestions with days to sell. A spec of
  its own.
- Reading photos without a video (`SellRepository.readPhotos`).
- Live cues while filming (`takeScript`, captions, "AI nhận ra" chips).
- Wiring the app; it has no API client yet. The app-side changes this design
  implies are listed under "App".
- Server-side drafts (a separate checklist item).

## Decisions

| Question | Decision |
|---|---|
| Price suggestion scope | The draft's spoken price and a reference range (low, median, high). The "Giá" step is out. |
| Delivery | A Restate flow behind a resource. `POST` answers 202 at once; each step saves progress and notifies `/v1/ws` with kind `video_read`; the app reloads with `GET`. Same pattern as chat and deal, and nothing is lost across a reconnect or a closed app. Rejected: one streaming response (lost on a drop, the reason SSE was retired on 2026-11-10); one synchronous call (no progressive findings). |
| Where frames are cut | In `ai`, which already has ffmpeg and the temp-file handling for mp4 files whose index sits at the end. The server still never runs ffmpeg. Rejected: ffmpeg in the server image; frames cut by the app. |
| Transcript retention | Never stored, never logged. STT and the LLM call run in one Restate step, so the transcript stays out of the journal. A failing LLM call redoes STT (about 1 s). |
| Video retention | Deleted from the object store when the read ends, done or failed. A video never read expires after 24 hours like any upload. Buyers never see a video. |
| Read retention | A read and its draft are kept 24 hours, then deleted. |
| Price source | Similar listings on the platform when there are at least 5 (`source: market`), else the model's own range (`source: model`), else none. The app shows the source. |
| Module | `assist`: AI that helps the person using the app do something (this read, later the bio writer, reply suggestions, auto-reply). Spam and scam detection is moderation and belongs to `trust` or a later `moderation` module; it shares `provider/llm`, not the module. |
| LLM alias | `video-read`, its own alias so its model can change without touching `search`; starts on the same model as `search`. |

## API

### Video uploads

`POST /v1/uploads` takes two more content types, `video/mp4` and
`video/quicktime`. A video may be up to 50 MB; a photo stays at 15 MB. The
schema keeps `maximum: 52428800` on `size` and its description gives the
per-type limit; a photo over 15 MB is 400 `invalid_request` from the
handler. The app compresses to 720p before uploading (30 s is about 10 to
15 MB). The PUT URL and the 24-hour expiry work as for photos.

### `POST /v1/video-reads`

```
POST /v1/video-reads
Idempotency-Key: <required>
{ "video": "<upload_id>" }
→ 202 VideoRead   (status: reading)
```

| Error | HTTP | When |
|---|---|---|
| `invalid_request` | 400 | missing or malformed body |
| `unauthenticated` | 401 | |
| `account_suspended` | 403 | |
| `invalid_upload` | 422 | not the caller's, not a video, not waiting, past its expiry, or already read |
| `read_limit_reached` | 429 | 30 reads by this account in the last 24 hours |

A repeated `Idempotency-Key` returns the first read. The invocation's key is
`<account id>/<Idempotency-Key>`, as for listings.

### `GET /v1/video-reads/{id}`

Returns the `VideoRead`. Another account's read, or one past `expires_at`, is
404 `video_read_not_found`.

### `VideoRead`

Fields fill in as the steps finish; a field not reached yet is absent.

```yaml
VideoRead:
  required: [id, status, expires_at]
  id: uuid
  status: reading | done | failed
  failure: unreadable_video | video_too_short | video_too_long | no_item | unavailable   # only when failed
  frames:                 # after the frames step; at most 8, in time order
    - upload_id: uuid
      url: uri            # presigned GET, valid 1 hour from this response
      at_seconds: number
  draft:                  # after the fill step
    title: string
    category_code: string # may be empty when no category was resolved
    condition: new | like_new | used
    specs: [Spec]
    description: string   # may be empty
    price: integer | null # the price the seller said; null if none
    allow_offers: boolean # true when the seller said the price is negotiable
    photos: [uuid]        # the kept frames, cover first; a subset of frames
  estimate:               # after the estimate step; null when none
    low: integer
    median: integer
    high: integer
    source: market | model
    sample_size: integer  # listings behind a market range; 0 for model
  expires_at: date-time
```

`draft` uses `ListingDraft`'s field names and rules, so the app adds
`commune_code` (and `gps` if allowed) and posts it to `POST /v1/listings`;
the kept frames are ordinary photo uploads and need no new upload. A field
with a value in `draft` is one the AI filled; the app marks it, with no flag
from the server. The findings' wording ("Chọn 4 khung hình rõ nhất",
"iPhone 11 · 64 GB · Trắng", "Mô tả từ lời bạn nói", "Giá 4,5 tr, có thương
lượng") is the app's, built from the structured fields.

### Stream

`Update.kind` gains `video_read`, with the read's ID. The flow notifies the
reader's account after each step.

## The `ai` service: `POST /v1/video/frames`

Multipart, one field `file`: any video ffmpeg reads. Not an OpenAI route, so
the server calls `ai` directly, not through LiteLLM (the NetworkPolicy
`from-stack` already lets the server reach it).

One request:

1. The file streams to a temporary file under `http.MaxBytesReader`
   (`AI_MAX_UPLOAD_MB`), as for transcriptions.
2. `ffprobe` reads the duration. Under 3 s is 400 `too_short`; over
   `AI_FRAMES_MAX_SECONDS` (35) is 413 `too_long`. No video stream is 400
   `unsupported_media`.
3. ffmpeg decodes 2 frames a second, rotated upright by the stream's display
   matrix (ffmpeg's default autorotate), scaled to at most 1600 px on the
   long side, as raw RGB to a pipe.
4. Each frame gets a sharpness score (variance of the Laplacian on a
   grey 512 px copy) and a 64-bit dHash.
5. Frames below a sharpness floor are dropped, then near-duplicates (dHash
   Hamming distance at most 6) keep the sharper one. Of what is left, at most
   8 are kept, spread over the video: the video is cut into 8 equal spans and
   each span gives its sharpest frame; empty spans give nothing.
6. The kept frames are encoded as JPEG quality 90.

Answer:

```json
{"duration": 27.4, "frames": [{"at_seconds": 1.5, "sharpness": 412.3, "jpeg": "<base64>"}]}
```

Errors keep OpenAI's shape and the STT table's codes: `invalid_request`,
`unsupported_media`, `too_large`, `too_long`, a new `too_short`, and
`internal_error`. A video whose frames are all dropped answers 200 with
`frames: []`; the server then fails the read with `unreadable_video`.

New variables, required like the others: `AI_FRAMES_MAX_CONCURRENT` (2),
`AI_FRAMES_MAX_SECONDS` (35), `AI_FRAMES_MIN_SHARPNESS` (a starting value the
tests on real phone videos set). One log line per request: bytes, duration,
frames decoded, dropped as blurred, dropped as duplicates, kept,
milliseconds, status.

## The server

### Media

- Shape `video`, recorded when a video upload is held by a read.
- `SaveFrame(owner, jpeg) (uuid, error)` writes the bytes to `uploads/<id>`
  and inserts a waiting upload of the owner, type `image/jpeg`, its real size,
  with the usual 24-hour `MediaExpire`. `Attach` and `MediaProcess` treat it
  as an upload the app PUT.
- `HoldVideo(owner, holder, id)` is `Attach` for one video upload: the
  caller's, waiting, present with the declared type and size. It records the
  holder, so a second read of the same video is `invalid_upload`.
- `OpenVideo(id) (io.ReadCloser, size, error)` reads a held video from the
  store for the flow.
- `PresignFrame(id) (url, error)` signs a GET of `uploads/<id>` valid 1 hour,
  for `GET /v1/video-reads/{id}`.
- `Consume(id)` deletes a held video's object and marks the row consumed.
  A second call changes nothing.

### Module `assist`

Layout follows the other modules: `domain`, `repository`, `service`,
`handler`, `assist.go`.

Table `video_reads` (migration `0033_video_reads.sql`, or the next free
number when the work lands):

```sql
CREATE TABLE video_reads (
    id          uuid PRIMARY KEY,
    account_id  uuid NOT NULL REFERENCES accounts(id),
    video_id    uuid NOT NULL REFERENCES uploads(id),
    status      text NOT NULL CHECK (status IN ('reading', 'done', 'failed')),
    failure     text CHECK (failure IN ('unreadable_video', 'video_too_short',
                    'video_too_long', 'no_item', 'unavailable')),
    frames      jsonb,
    draft       jsonb,
    estimate    jsonb,
    created_at  timestamptz NOT NULL,
    expires_at  timestamptz NOT NULL,
    write_id    uuid NOT NULL,
    CHECK ((status = 'failed') = (failure IS NOT NULL))
);
CREATE INDEX video_reads_account_created ON video_reads (account_id, created_at);
```

The same migration widens `uploads.content_type` with `video/mp4` and
`video/quicktime`, and `uploads.shape` with `video`.

`Service.StartRead(account, key, video)` calls the Restate service
`VideoRead.Start` through `restatex.Caller` with key
`<account id>/<Idempotency-Key>` and returns its `VideoRead`, so the handler
answers 202 within a few hundred milliseconds.

### `VideoRead.Start`

Reads top to bottom. Every step is idempotent; IDs come from
`restatex.NewID`; refusals leave as data, as in Durable flows.

1. A step returns `accountsvc.Service.Suspended`; suspended refuses with
   `account_suspended`.
2. A step inserts the row (`reading`, `expires_at = now + 24h`) in a
   transaction that takes `pg_advisory_xact_lock(hashtext(account_id))` and
   counts the account's reads of the last 24 hours first, so two posts at
   once cannot pass the cap. 30 or more returns the outcome
   `read_limit_reached` and inserts nothing.
3. A step holds the video (`HoldVideo`, `restatex.AsRefusal`). A refusal
   deletes the row again and refuses with `invalid_upload`.
4. Send `VideoRead.Expire(id)` with a 24-hour delay and `VideoRead.Run(id)`
   one way, both keyed by the read's ID. `Notify`, return the row.

### The flow `VideoRead.Run`

1. **Frames.** Open the video, POST it to `ai` frames. A 4xx from `ai` is a
   failure: `unsupported_media` → `unreadable_video`, `too_short` →
   `video_too_short`, `too_long` → `video_too_long`; empty `frames` →
   `unreadable_video`. Otherwise `SaveFrame` each frame (IDs minted before the
   step, so a retry overwrites the same objects) and return the IDs and times
   only, never the bytes. Save `frames`, `Notify`.
2. **Fill.** One step, so the transcript never reaches the journal:
   - Open the video again and call `stt` (`response_format: json`, language
     `vi`). `unsupported_media` (no audio track) gives an empty transcript.
   - Read the frames in `ShapeQuery` (768 px, upright).
   - Call the LLM (see LLM).
   - Clean the answer (see Cleaning) and return the draft and the model's
     range. `is_item = false` returns `no_item`.
   Save `draft`, `Notify`.
3. **Estimate.** See Price estimate. Save `estimate`, `status = done`,
   `Notify`.
4. **Consume** the video. Runs after a failure too: every path that saves
   `failed` goes through it.

Timeouts: each call to `ai`, STT or the LLM has its own timeout
(`ASSIST_CALL_TIMEOUT`); Restate retries faults with backoff. The run as a
whole has a 2-minute deadline from the row's `created_at`. Before each step
the flow reads the journaled clock; past the deadline it saves `failed` with
`unavailable` and consumes the video. Each of the three model steps runs with
`restate.WithMaxRetryDuration` set to the time left before the deadline, so a
step that keeps failing returns a terminal error, which the flow turns into
`unavailable` the same way.

`VideoRead.Expire(id)` deletes the row. The frames not posted in a listing
expire with their uploads.

### LLM

`provider/llm.Request` gains `Images [][]byte` (JPEG). `OpenAI.Complete` sends
a user message whose content is a list: the text part, then one `image_url`
part per image as a `data:image/jpeg;base64,` URL. A request without images
sends the plain string as today, so search is unchanged.

The prompt is `assist`'s, with a `PromptVersion` (1) written in its log line.

Input:

- The frames, numbered from 0 in time order.
- The transcript, labelled as lower case, without punctuation and possibly
  misheard.
- The subcategories, one per line as `code — Root › Sub`. The list changes
  only with a migration, so the system prompt is built once at start-up.

Output schema (strict):

```json
{
  "is_item": true,
  "title": "iPhone 11 64GB Trắng, pin 81%",
  "category_code": "phones.iphone",
  "condition": "used",
  "specs": [{"label": "Dung lượng", "value": "64 GB"}],
  "description": "Máy dùng 3 năm, chưa sửa chữa gì, pin còn 81%. Có thương lượng.",
  "spoken_price": 4500000,
  "negotiable": true,
  "kept": [2, 0, 3, 4],
  "estimate": {"low": 4400000, "median": 4800000, "high": 5100000}
}
```

`spoken_price` and `estimate` are nullable.

Rules in the prompt, from `app/mohinh.md` section 1:

- The description only restates what the seller said: punctuation, STT
  mistakes fixed, tightened. Nothing seen in the frames is added, and the
  model never names a mark, scratch or fault on its own. No speech, empty
  description.
- Title and specs draw on both the frames and the speech; the speech wins
  where they disagree (the seller saying "pin 81%").
- Condition is the model's judgement unless the seller says it.
- `kept`: 1 to 6 frames that show the item clearly and differently, the best
  cover first.
- `is_item` is false when the video shows no single item for sale.

### Cleaning

Every value is checked against real rules or dropped, as search does:

- `category_code` not a subcategory: its root's `<root>.other` when the root
  exists, else empty.
- `title` trimmed and cut at 70 characters; empty title fails the read with
  `no_item`.
- `description` cut at 1,500 characters.
- `specs`: at most 20, label and value trimmed and non-empty.
- `spoken_price` outside 10,000 to 1,000,000,000: null. `allow_offers` is
  `negotiable`.
- `kept`: indices outside the frames or repeated are dropped; none left, the
  sharpest frame.
- `estimate`: kept only when low ≤ median ≤ high and all are inside the price
  range, each rounded to 10,000.

One log line per read: model, prompt version, frame count, transcript
length in characters, fields filled, category asked for and kept, the
numbers, milliseconds. Never the transcript, title or description: they are
the seller's words.

### Price estimate

1. Embed the draft: its text as `Listing.EmbeddingText` builds it, through
   `embed-text`; the kept frames through `embed-image`, normalized mean. Same
   query shape as `like`.
2. Candidates: listings in the same `category_code` and `condition`, at or
   above `EMBED_TEXT_MIN_SIMILARITY` or `EMBED_PHOTO_MIN_SIMILARITY`, either
   sold with `sold_at` in the last 180 days, or active or reserved with
   `published_at` in the last 90. The caller's own listings are left out.
3. The 30 most similar; sold ones weigh 2, the others 1. Weighted p25,
   median and p75 of their prices, rounded to 10,000, with `sample_size`.
4. Fewer than 5: the model's range from the fill step with `source: model` and
   `sample_size: 0`. No model range either: `estimate` is null.
5. An embedding failure is logged and falls back to the model's range; the
   read still succeeds.

The query lives in catalog (`Service.PriceSample(query) ([]Sample, error)`,
the prices and sold flags of the candidates), so `assist` reads no catalog
table.

### Erasure

Deleting an account deletes its `video_reads` (assist's worker on
`account.deleted`). Media does nothing, as for any upload: a frame not
posted is a waiting upload and expires within a day, and a video is
consumed when its read ends.

### Configuration

Required, no defaults, in `.env.example`, compose and the chart:

| Variable | Meaning |
|---|---|
| `AI_FRAMES_BASE_URL` | `ai`'s base URL ending in `/v1`; the client posts to `<base>/video/frames` |
| `STT_BASE_URL`, `STT_API_KEY`, `STT_MODEL` | `stt` through LiteLLM; locally `ai` directly with `gipformer-1.5` |
| `ASSIST_LLM_BASE_URL`, `ASSIST_LLM_API_KEY`, `ASSIST_LLM_MODEL` | `video-read` through LiteLLM; locally the LLM in `.env` |
| `ASSIST_CALL_TIMEOUT` | timeout of one call to `ai`, STT or the LLM |

The estimate reuses the `EMBED_*` settings and the `EMBED_SEARCH_API_KEY`.

## Cluster

- `litellm.aliases.video-read`: `model: openai/claude-haiku-5-5`, the same
  `apiBase` and upstream key as `search`, `price: token`.
- `litellm.keys.server-assist`: `{secret: ASSIST_LLM_API_KEY, models:
  [video-read], dailyUnits, tpmLimit}`, set per stack. A read is about 8
  images and a prompt; the per-stack numbers come from measuring one read.
- `ai`'s Deployment gets the `AI_FRAMES_*` variables. The memory limit is
  measured again with two frame requests and two transcriptions at once.
- The server's Deployment gets the variables above; `seal` generates
  `ASSIST_LLM_API_KEY` for each stack.

## App

Not part of this work, listed so the API fits:

- `SellRepository.readVideo` uploads the video, posts the read, then follows
  `video_read` updates and `GET`s, mapping each to a `VideoReading`.
- `ListingDraft`'s `storage`, `battery` and `color` give way to `specs`.
- `CategoryRef` becomes the server's `category_code`.
- The 8 frames come from the server, so the app's own frame grab is only for
  the preview while filming.
- The estimate label reads by `source`: "Giá tham khảo trên sàn" for
  `market`, "AI ước lượng" for `model`.

## Testing

`ai`:

- Unit tests on fixtures ffmpeg makes at test time: a portrait video with a
  rotation matrix, one with blurred stretches, one still image held 10 s
  (duplicates), audio only, a garbage file, 2 s and 40 s videos. Every row of
  the error table.

Server:

- `assist` flow against fake `ai`, STT and LLM: the happy path through all
  steps; a failure at each step; an LLM answer with bad values cleaned; `no_item`;
  no audio track; the video consumed on every path; a `Notify` after each
  step; the 2-minute deadline.
- Handlers: the 30-read cap with two posts at once, `Idempotency-Key`,
  another account's read is 404, an expired read is 404.
- Price estimate on seeded listings: 5 or more gives `market`, fewer gives
  `model`, neither gives null, own listings left out.
- Media: a `SaveFrame` upload posted with `POST /v1/listings` becomes a
  listing photo; a second hold of a video is `invalid_upload`.
- `provider/llm`: a request with images has the content-list shape; one
  without is unchanged.
- The OpenAPI spec test covers the new paths.

By hand, the definition of done: a real 30 s Vietnamese video from a phone
through a local stack (`ai`, the LLM in `.env`), read to a draft that posts as
a listing.
