# Design: server2 photo search, similar listings and hybrid text search

Date: 2026-11-09.
Status: decided in conversation, question by question; amended 2026-11-09
when the `ai` repo landed: the models run behind LiteLLM (TEI and `ai`), not
in a Python service of the server's. When the work lands, the decisions
below go into `~/shopnexus/server/ARCHITECTURE.md` (sections Search,
Catalog, Discovery, Infrastructure), `ai/README.md` and the docs page
`operations/cluster/llm-gateway`.

## Scope

The app (`app/`) already has a photo search screen (`PhotoSearchViewModel`,
`SearchRepository.readPhoto`) and a similar-listings sheet
(`ListingRepository.similar`), both on fake data. This design gives them a
server behind the one search endpoint, `GET /v1/search`, and adds two
vector signals to text search:

- `photo=<upload_id>`: search by a photo, image similarity alone.
- `like=<listing_id>`: listings similar to one listing.
- `q`: keyword (BM25, as today), semantic (text vectors) and visual (the
  query's English rewrite against listing photos), fused by weighted RRF.

It extends `2026-10-27-server2-search-design.md`, which left vector search
for later. That spec replaced the old server's twelve ANN legs with one
BM25 query; this one brings vectors back as three bounded lists beside
BM25, not as the main retrieval. It is part 3 ("image → search") of
`2026-11-09-ai-stt-gateway-design.md`, and follows its rule: the server
calls only LiteLLM aliases; a model with an OpenAI-compatible server of
its own (TEI) is a LiteLLM entry, a model without one is wrapped by `ai`.

Out of scope: `photo` combined with `q` (the app has no screen for it
yet), followed searches, price alerts, moving LiteLLM out of
`infra/stack` (the `ai` repo serves models; distribution stays in the
stack).

## Decisions

| Question | Decision |
|---|---|
| Approach | Image and text embeddings in pgvector, not a vision LLM reading the photo into words. |
| Endpoint | One: `GET /v1/search` gains `photo` and `like`. |
| How the photo arrives | An upload from `POST /v1/uploads`, so photo search needs a signed-in caller. |
| `photo` with other inputs | Alone, with filters and sorts. `photo` with `q` or `like` is 400. |
| `like` with other inputs | With `q`, filters and sorts. |
| Signals for `q` | BM25 + BGE-M3 text vectors + SigLIP 2 visual (text tower on the English rewrite). |
| Signals for `like` | BM25 on the source's title + its text vector + its photo vectors. |
| Signals for `photo` | Photo vectors alone. |
| Fusion | Weighted RRF, k = 60, plus a fourth list ranked by the model's boosts alone. |
| Text model | `BAAI/bge-m3`, dense only, 1024 dimensions, served by TEI. |
| Image model | `google/siglip2-so400m-patch16-384`, 1152 dimensions, served by `ai`. |
| Which photos | Every photo of a listing (1 to 10), one vector each; a listing matches by its closest photo. |
| Where the models run | Behind the stack's LiteLLM: alias `embed-text` → TEI, alias `embed-image` → `ai`'s new `POST /v1/embeddings`. |
| Image input | OpenAI's `input` array of strings; an image is a `data:image/jpeg;base64,...` string, LiteLLM's convention for multimodal embeddings. |
| Keys | Two virtual keys: `server-embed-index` for indexing, `server-embed-search` for queries, so a backfill cannot spend the budget searches need. |
| LiteLLM chart | Aliases and keys become data in `values.yaml`; the templates range over them. The key `server` is renamed `server-llm`. |
| Vector compatibility | The server stores `EMBED_TEXT_VERSION` / `EMBED_IMAGE_VERSION` with each vector; changing the model behind an alias means a new version and a reindex. |
| Indexing | A Restate Virtual Object, `ListingEmbed`, keyed by listing ID, sent by `ListingPublish` and `ListingEdit`. No new job queue. |
| Query rewrite | The existing understanding call gains `rewritten` (Vietnamese, typos fixed) and `visual` (short English). |
| Query photo data | Read from the caller's waiting upload, never attached or published; its vector cached until the upload expires. |
| Measuring quality | A sample set of listings and queries with expected results, run by `make search-eval`. |

## API (module discovery)

`GET /v1/search` keeps every parameter it has and its response,
`SearchView`, unchanged. Two parameters join:

- `photo` (UUID): an upload of the caller's that is still `waiting`
  (attached to nothing), of an image type, present in the store.
  Requires `Authorization`; signed out it is 401.
- `like` (UUID): a listing that is `active` or `reserved`. Results leave
  out that listing and the viewer's own listings. Anyone may call it.

Rules:

- `photo` with `q` or `like`: 400 `search_conflict`.
- `sort` defaults to `relevance` with `q`, `photo` or `like`, and to
  `newest` with none. Other sorts reorder the candidate set (see
  Retrieval), never the whole catalog.
- With `photo` the view has no `understood` and no `chips`; with `like`,
  only when `q` is given.
- Results page by the offset cursor and stop at 500, as today.

Errors, beside today's:

| Status | Code | When |
|---|---|---|
| 400 | `search_conflict` | `photo` with `q` or `like`. |
| 400 | `invalid_upload` | The upload is not the caller's, not waiting, expired, or not a valid image. Media's code. |
| 401 | `unauthenticated` | `photo` signed out. |
| 404 | `listing_not_found` | `like` names a listing that is not public. |
| 503 | `search_unavailable` | `photo` and `embed-image` did not answer (down, budget spent, rate limited). |

Degradation: `q` with an embedding alias failing runs without that list,
and with both failing runs BM25 alone, as a failed model does today. `like`
needs no model at search time, since its vectors are stored; a source with
no vectors yet runs on the signals it has.

## Data

Catalog owns listing vectors beside its BM25 index and runs the hybrid
query. Discovery owns the understanding and the query vector caches. The
client lives in `internal/provider/embed`, beside `provider/llm`: an
OpenAI-style `POST /embeddings` with `input` strings.

Migration 0024:

```sql
-- One text vector per listing: title, category name, condition, specs and
-- description (cut at about 2,000 characters).
CREATE TABLE listing_text_vectors (
    listing_id  uuid PRIMARY KEY REFERENCES listings (id) ON DELETE CASCADE,
    model       text NOT NULL,           -- EMBED_TEXT_VERSION, such as 'bge-m3@<revision>'
    text_hash   bytea NOT NULL,          -- sha256 of the version and the text
    embedding   halfvec(1024) NOT NULL,
    embedded_at timestamptz NOT NULL
);

-- One vector per processed photo of a listing.
CREATE TABLE listing_photo_vectors (
    listing_id  uuid NOT NULL REFERENCES listings (id) ON DELETE CASCADE,
    photo_key   text NOT NULL,           -- the processed photo's key under media/
    model       text NOT NULL,           -- EMBED_IMAGE_VERSION
    embedding   halfvec(1152) NOT NULL,
    embedded_at timestamptz NOT NULL,
    PRIMARY KEY (listing_id, photo_key)
);

CREATE INDEX listing_text_vectors_embedding
    ON listing_text_vectors USING hnsw (embedding halfvec_cosine_ops);
CREATE INDEX listing_photo_vectors_embedding
    ON listing_photo_vectors USING hnsw (embedding halfvec_cosine_ops);

-- Discovery: the vector of a query photo, gone when its upload expires.
CREATE TABLE search_photo_vectors (
    upload_id  uuid PRIMARY KEY,
    model      text NOT NULL,
    embedding  halfvec(1152) NOT NULL,
    expires_at timestamptz NOT NULL      -- the upload's expiry, not 24 h from the search
);

-- Discovery: vectors of a normalized text query, 7 days like the understanding.
CREATE TABLE search_query_vectors (
    query_key      text NOT NULL,
    prompt_version integer NOT NULL,
    model          text NOT NULL,
    embedding      halfvec NOT NULL,     -- 1024 for the text model, 1152 for the image model
    created_at     timestamptz NOT NULL,
    PRIMARY KEY (query_key, prompt_version, model)
);
CREATE INDEX search_query_vectors_created ON search_query_vectors (created_at);
```

- The server knows aliases, not models, so the `model` column holds the
  configured version string. A row whose version differs from the
  configured one counts as missing, and `ListingEmbed` embeds it again.
- Vectors stay while a listing is hidden or sold: queries read only active
  listings, and a listing back on sale needs no new embedding. A deleted
  row takes its vectors with it.
- The text and photo vectors are derived data and hold nothing a listing
  does not already show publicly.

## Indexing: `ListingEmbed`

A Restate Virtual Object keyed by listing ID, handler `Refresh`. Restate
runs one `Refresh` per listing at a time, so edits in a burst queue up;
each run reads the listing as it is now. It calls the aliases with
`EMBED_INDEX_API_KEY`.

- Sent as the last, journaled step of `ListingPublish` (the listing just
  went active) and of `ListingEdit` when the edit does not return the
  listing to processing (when it does, `ListingPublish` sends it).
- Steps:
  1. Read the listing's embedding input (text, processed photo keys) and
     the vectors it has (text hash and version, photo keys and version). A
     listing gone or deleted ends the run.
  2. When the text hash or version differs: embed the text, save it.
  3. One step per photo with no vector of the configured version: read
     the processed photo from the store, embed it, save it. A retry after
     the seventh photo does not embed the first six again.
  4. Delete the vectors of photos the listing no longer has.
- No step returns a vector to the journal; each writes its row and returns
  nothing.
- `EMBED_SLOTS` bounds embeds at once in the process, as `processSlots`
  bounds media. LiteLLM's rpm limit on `server-embed-index` and `ai`'s own
  concurrency bound the rest; a 429 or 503 is an error Restate retries
  with backoff.
- A burst of five edits gives five queued runs; the first embeds the newest
  content and the rest find the hashes and keys in line, one read each.
- `go run ./cmd/search-reindex` sends `Refresh` for every listing not
  deleted: the backfill of existing listings and the way to change models.

## Query understanding

`Understanding` gains two fields; `PromptVersion` goes to 2, so cached
answers of version 1 are no longer read.

```go
type Understanding struct {
	Understood string   `json:"understood"`
	Rewritten  string   `json:"rewritten"` // Vietnamese, typos fixed, diacritics, abbreviations spelled out
	Visual     string   `json:"visual"`    // short English description of how the item looks, "" when none
	Boosts     []Signal `json:"boosts"`
	Demotes    []Signal `json:"demotes"`
}
```

- `rewritten` goes to `embed-text`: "ip13 pm xanh" becomes "iPhone 13 Pro
  Max màu xanh".
- `visual` goes to `embed-image` as text, for SigLIP's text tower, at most
  about 12 words since the tower reads 64 tokens: "iPhone 13 Pro Max
  smartphone, blue". A query with no visual meaning ("đồ rẻ dưới 500k")
  leaves it empty and the visual list does not run.
- BM25 is unchanged: the model's phrases, and the raw query at 0.5.
- The model failing or passing 4 seconds: BM25 on the raw words as today,
  the text vector on the raw query (BGE-M3 reads unfixed Vietnamese), no
  visual list.
- Query vectors are cached in `search_query_vectors` by the query key, the
  prompt version and the model version, 7 days; the write of a new row
  deletes the expired ones, as `search_understandings` does. Query-time
  calls use `EMBED_SEARCH_API_KEY`.

## Query photo

- The handler passes the upload ID; the service asks media for the
  caller's waiting upload, reads its object from `uploads/` (private),
  checks the magic bytes against the type and the pixel bounds media uses,
  shrinks it in memory to at most 768 px on its long side, and sends it to
  `embed-image` as a data URL.
- The upload is never attached and never processed into `media/`, so it
  never becomes public, and `MediaExpire` deletes it 24 hours after it was
  created.
- The vector is cached in `search_photo_vectors` until the upload's expiry,
  so later pages do not embed again. Every read checks the upload again, so
  an expired upload is `invalid_upload` even before its cache row is swept.
  The write of a new row deletes expired rows.
- Neither the photo nor its vector reaches a log or the journal. LiteLLM
  must not keep request bodies either: `store_prompts_in_spend_logs` stays
  off, and the plan checks on the pinned version that a spend log row of
  an `embed-image` call holds no input.
  The user accepted on 2026-11-09 that the cache row ties an upload, and
  through it an account, to a vector for at most the upload's life.

## Retrieval and fusion

Each list takes at most 500 listings, and the person's hard filters
(active, category, price, condition, offers, radius) apply to every list.
Vector lists use HNSW with `hnsw.iterative_scan = relaxed_order`, so a
narrow filter still fills the list, bounded by `hnsw.max_scan_tuples`.

| Search | BM25 | Text vectors (BGE-M3) | Photo vectors (SigLIP 2) |
|---|---|---|---|
| `q` | As today: phrases and model boosts | `rewritten` against listing text vectors | `visual` against listing photos, a listing at its closest photo |
| `like` | The source's title as a phrase, boosts for its subcategory and price ±30 %; with `q`, `q`'s phrases and boosts join | The source's text vector | The normalized mean of the source's photo vectors, against listing photos |
| `photo` | none | none | The query photo against listing photos |

- Boost list: the model's boosts (near me, fresh, category, price, place,
  condition, offers) live in BM25's score, so through RRF they would move
  one list of three. A fourth list ranks the union of the other lists'
  candidates by boost points alone, so "xe đạp gần tôi" lifts near
  listings that came from a vector list. No boosts, no list.
- Weighted RRF: `score = Σ wᵢ / (60 + rankᵢ)`. Starting weights are
  constants in `domain`, as the BM25 weights are:

  | | BM25 | Text | Photo | Boosts |
  |---|---|---|---|---|
  | `q` | 1.0 | 1.0 | 0.5 | 0.75 |
  | `like` | 0.5 | 1.0 | 1.0 | 0.5 |
  | `photo` | none | none | 1.0 | none |

- Similarity floors: a listing joins a vector list only at or above
  `EMBED_TEXT_MIN_SIMILARITY` (text) or `EMBED_PHOTO_MIN_SIMILARITY`
  (photo), cosine. Without them a nonsense query fills the vector lists,
  and `sort=price_asc` would lead with cheap unrelated listings. The eval
  set sets their values.
- Sorts: `relevance` orders by RRF score; `newest`, `price_asc`,
  `price_desc` and `nearest` order the candidate set, the union of the
  lists above their floors. `counts` count the same set.
- One SQL statement: the lists are CTEs (`bm25`, `txt`, `img`, `boost`),
  fused and joined to the cards in one round trip, after ParadeDB's hybrid
  search pattern. Each page runs it again; the result is deterministic, so
  the offset cursor holds.

## Models behind LiteLLM

```
server ──► litellm:4000 ──► alias embed-text  ──► tei:80   (BAAI/bge-m3)
                        └─► alias embed-image ──► ai:8000  (SigLIP 2, POST /v1/embeddings)
```

### TEI (`embed-text`)

- Hugging Face Text Embeddings Inference, its CPU image, serving
  `BAAI/bge-m3` at a pinned revision; the image tag and the revision are
  looked up when the work starts. TEI serves OpenAI's `POST /v1/embeddings`,
  so this is a LiteLLM entry and a Deployment, no code.
- `templates/tei.yaml` in `infra/stack`: a Deployment and a Service on port
  80, no Ingress, NetworkPolicy `from-stack`, as `ai.yaml`. Weights download
  to an emptyDir or a PVC on first start; the choice (start time against a
  volume) is made in the plan after measuring the download.
- Locally `docker-compose.yml` runs it on a 127.0.0.1 port, and the server
  calls it directly, as it calls the upstream LLM.

### `ai` (`embed-image`)

`ai` gains `POST /v1/embeddings` beside `/v1/audio/transcriptions`, in
OpenAI's shape:

```json
{"model": "siglip2-so400m-patch16-384", "input": ["data:image/jpeg;base64,..."]}
{"model": "siglip2-so400m-patch16-384", "input": ["iPhone 13 Pro Max smartphone, blue"]}
```

answers `{"object": "list", "model": "...", "data": [{"object":
"embedding", "index": 0, "embedding": [...]}], "usage": {"prompt_tokens":
n, "total_tokens": n}}`, each vector L2-normalized.

- An input that starts with `data:image/` is an image (JPEG, PNG or WebP),
  anything else is text for the text tower. One request may mix both.
- SigLIP 2 runs as ONNX on CPU, in Go: the vision and text towers, image
  preprocessing (decode, resize to 384, normalize) and the Gemma tokenizer
  for the text tower. The model is baked into the image at a pinned
  revision with checksums, as Gipformer is (`scripts/fetch-assets.sh`).
- `usage`: an image counts 576 tokens (its 24 × 24 patches), a text its
  token count, so LiteLLM prices calls from usage instead of the length of
  a base64 string.
- Bounds: at most `AI_EMBED_MAX_INPUTS` inputs a request, a decoded pixel
  limit, images under 32 px a side refused, `AI_EMBED_MAX_CONCURRENT`
  requests embedding at once, others wait. Errors keep OpenAI's shape and
  the codes `ai` already uses (`invalid_request`, `model_not_found`,
  `too_large`, `internal_error`).
- One log line per request: the model, the input count by kind, the time
  taken and the status. No input is logged.
- Configuration, all required: `AI_EMBED_MODELS` (`name=dir` pairs),
  `AI_EMBED_MAX_INPUTS`, `AI_EMBED_MAX_CONCURRENT`, `AI_EMBED_MAX_IMAGE_MB`.

### LiteLLM chart in `infra/stack`

Aliases and keys become data; the templates range over them, so a new
alias or key is a values edit.

```yaml
litellm:
  aliases:
    search:
      model: openai/claude-haiku-5-5
      apiBase: http://host.k3d.internal:8317/v1
      apiKeySecret: LLM_UPSTREAM_API_KEY   # a key of litellm-secrets; absent means "none"
      price: token
    stt:
      model: openai/gipformer-1.5
      apiBase: http://ai:8000/v1
      mode: audio_transcription
      price: second
    embed-text:
      model: openai/bge-m3
      apiBase: http://tei:80/v1
      mode: embedding
      price: token
    embed-image:
      model: openai/siglip2-so400m-patch16-384
      apiBase: http://ai:8000/v1
      mode: embedding
      price: token
  keys:   # budgets and limits set per stack
    server-llm:          { secret: LLM_API_KEY,          models: [search],                  dailyUnits: 0, tpmLimit: 0 }
    server-stt:          { secret: STT_API_KEY,          models: [stt],                     dailyUnits: 0, rpmLimit: 0 }
    server-embed-index:  { secret: EMBED_INDEX_API_KEY,  models: [embed-text, embed-image], dailyUnits: 0, rpmLimit: 0 }
    server-embed-search: { secret: EMBED_SEARCH_API_KEY, models: [embed-text, embed-image], dailyUnits: 0, rpmLimit: 0 }
```

- `dailyUnits` is tokens for token-priced aliases and seconds for `stt`;
  the chart divides by 1,000,000 for `max_budget`, as today.
- The chart refuses to render when a key names an alias that does not
  exist, or a required field is empty.
- The key `server` becomes `server-llm`: same value (`LLM_API_KEY`), so
  `/key/update` renames the alias and the server needs no change.
- The key Job moves to `templates/litellm-keys.yaml` and loops over
  `litellm.keys`, one env var and one upsert per key.
- The seal command generates `EMBED_INDEX_API_KEY` and
  `EMBED_SEARCH_API_KEY` into `server-secrets`.
- `infra/check.sh` and `smoke.hurl` pass for `search` and `stt` as before;
  that is the measure of the refactor. `smoke.hurl` gains one call to each
  embed alias.

### Measured first

Like the STT spec, three behaviours are measured on the pinned LiteLLM
before the server relies on them; each becomes a test of the plan:

1. LiteLLM's `openai/` provider forwards a data-URL string in `input` to
   the upstream unchanged.
2. LiteLLM prices an embedding call from the upstream's `usage`, not by
   counting tokens of the input strings.
3. SigLIP 2's ONNX towers run in `ai` beside sherpa-onnx without an
   onnxruntime conflict, and their vectors match the reference
   (transformers) within a cosine of 0.999 on a few sample inputs.

If 1 or 2 fails, `ai` and TEI are called with a pass-through LiteLLM entry
priced per request, or the plan comes back to this spec. If 3 fails, the
fallback is a Python service for SigLIP 2 behind the same alias.

## Configuration

Every variable is set; none has a default.

Server: `EMBED_TEXT_BASE_URL`, `EMBED_IMAGE_BASE_URL` (both LiteLLM in the
cluster; TEI and `ai` locally), `EMBED_TEXT_MODEL` (`embed-text`),
`EMBED_IMAGE_MODEL` (`embed-image`), `EMBED_TEXT_VERSION`,
`EMBED_IMAGE_VERSION`, `EMBED_INDEX_API_KEY`, `EMBED_SEARCH_API_KEY` (empty
locally, where TEI and `ai` have no keys), `EMBED_TIMEOUT`, `EMBED_SLOTS`,
`EMBED_TEXT_MIN_SIMILARITY`, `EMBED_PHOTO_MIN_SIMILARITY`.

`ai`: `AI_EMBED_MODELS`, `AI_EMBED_MAX_INPUTS`, `AI_EMBED_MAX_CONCURRENT`,
`AI_EMBED_MAX_IMAGE_MB`.

## Testing

Server, Go, in `make test`:

- Domain, pure functions: weighted RRF, similarity floors, the boost list,
  `like`'s signals, parameter rules (`search_conflict`, `photo` signed
  out).
- Repository, real Postgres: the hybrid SQL with deterministic fake
  vectors (from a hash of the text, or set by hand in fixtures). Filters
  hold on every list, floors drop far listings, other sorts order only
  the candidates, `counts` match, `like` leaves out the source and the
  viewer's listings.
- `ListingEmbed` with `restatetest` and a counting fake embed client:
  vectors after publish (`testenv.Eventually`); a text-only edit embeds no
  photo; a removed photo loses its vector; five edits in a row embed each
  photo once; a 503 from the client retries, then succeeds; a new version
  re-embeds.
- Service: `photo` requires the caller's waiting upload; page 2 of a photo
  search calls no model; `embed-image` down leaves `q` without its visual
  list and gives `photo` a 503; the model down sends the raw query to the
  text vector; index and search calls carry their own keys.
- `api/spec_test.go` catches drift between the OpenAPI spec and the routes.

`ai`, Go:

- `go test ./...`: request parsing (data URL or text, mixed inputs, too
  many inputs, image under 32 px, bad base64, unknown model) against a stub
  embedder.
- `-tags model`: loads SigLIP 2, checks 1152 dimensions, L2 norms, and the
  cosine against reference vectors from transformers, stored in the repo.

`infra`: `check.sh` renders every stack and fails on a key naming a missing
alias; `smoke.hurl` calls all four aliases on a running stack.

Eval, `make search-eval` in the server, against the real models:

- About 40 sample listings with real photos and 40 to 50 queries, each
  with the listings it must return: typos ("ip13 pm"), synonyms ("xe cho
  bé" against "xe đạp trẻ em"), looks ("áo khoác xanh rêu"), photo queries
  (another shot of the same item) and `like`.
- It prints recall@10 and nDCG@10 per search kind and per query; those
  numbers tune the RRF weights and the two floors.
- Photos: the app's fixture photos where their licenses allow, otherwise
  generated with gpt-image-2.5 through the proxy.

## Follow-ups

- `photo` with `q`, once the app has a screen for it.
- The app's `readPhoto` and `similar` move from fakes to this endpoint.
