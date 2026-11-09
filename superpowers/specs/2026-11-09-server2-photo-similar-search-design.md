# Design: server2 photo search, similar listings and hybrid text search

Date: 2026-11-09.
Status: decided in conversation, question by question. When the work
lands, the decisions below go into `~/shopnexus/server/ARCHITECTURE.md`
(sections Search, Catalog, Discovery, Infrastructure).

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
BM25, not as the main retrieval.

Out of scope: `photo` combined with `q` (the app has no screen for it
yet), text-only "describe a photo" reading, followed searches, price
alerts, a k3d manifest for the embedder (follow-up in `infra/`).

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
| Text model | `BAAI/bge-m3`, dense only, 1024 dimensions. |
| Image model | `google/siglip2-so400m-patch16-384`, 1152 dimensions. |
| Which photos | Every photo of a listing (1 to 10), one vector each; a listing matches by its closest photo. |
| Where the models run | A Python service in the server repo, `server/embedder/`, OpenAI-style `/v1/embeddings` that takes text or images. |
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
| 503 | `search_unavailable` | `photo` and the embedder did not answer. |

Degradation: `q` with the embedder down runs BM25 alone, as a failed model
does today. `like` needs no model at search time, since its vectors are
stored; a source with no vectors yet runs on the signals it has.

## Data

Catalog owns listing vectors beside its BM25 index and runs the hybrid
query. Discovery owns the understanding and the query vector caches. The
model client lives in `internal/provider/embed`, beside `provider/llm`.

Migration 0024:

```sql
-- One text vector per listing: title, category name, condition, specs and
-- description (cut at about 2,000 characters).
CREATE TABLE listing_text_vectors (
    listing_id  uuid PRIMARY KEY REFERENCES listings (id) ON DELETE CASCADE,
    model       text NOT NULL,
    text_hash   bytea NOT NULL,          -- sha256 of the model and the text
    embedding   halfvec(1024) NOT NULL,
    embedded_at timestamptz NOT NULL
);

-- One vector per processed photo of a listing.
CREATE TABLE listing_photo_vectors (
    listing_id  uuid NOT NULL REFERENCES listings (id) ON DELETE CASCADE,
    photo_key   text NOT NULL,           -- the processed photo's key under media/
    model       text NOT NULL,
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

- A row whose `model` differs from the configured model counts as missing,
  so a model change re-embeds through `ListingEmbed`.
- Vectors stay while a listing is hidden or sold: queries read only active
  listings, and a listing back on sale needs no new embedding. A deleted
  row takes its vectors with it.
- The text and photo vectors are derived data and hold nothing a listing
  does not already show publicly.

## Indexing: `ListingEmbed`

A Restate Virtual Object keyed by listing ID, handler `Refresh`. Restate
runs one `Refresh` per listing at a time, so edits in a burst queue up;
each run reads the listing as it is now.

- Sent as the last, journaled step of `ListingPublish` (the listing just
  went active) and of `ListingEdit` when the edit does not return the
  listing to processing (when it does, `ListingPublish` sends it).
- Steps:
  1. Read the listing's embedding input (text, processed photo keys) and
     the vectors it has (text hash and model, photo keys and model). A
     listing gone or deleted ends the run.
  2. When the text hash or model differs: embed the text, save it.
  3. One step per photo with no vector of the configured model: read the
     processed photo from the store, embed it, save it. A retry after the
     seventh photo does not embed the first six again.
  4. Delete the vectors of photos the listing no longer has.
- No step returns a vector to the journal; each writes its row and returns
  nothing.
- `EMBED_SLOTS` bounds embeds at once in the process, as `processSlots`
  bounds media. The embedder bounds its own queue and answers 503 when
  full; Restate retries with backoff.
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

- `rewritten` feeds BGE-M3: "ip13 pm xanh" becomes "iPhone 13 Pro Max màu
  xanh".
- `visual` feeds SigLIP's text tower, at most about 12 words since the
  tower reads 64 tokens: "iPhone 13 Pro Max smartphone, blue". A query
  with no visual meaning ("đồ rẻ dưới 500k") leaves it empty and the
  visual list does not run.
- BM25 is unchanged: the model's phrases, and the raw query at 0.5.
- The model failing or passing 4 seconds: BM25 on the raw words as today,
  the text vector on the raw query (BGE-M3 reads unfixed Vietnamese), no
  visual list.
- Query vectors are cached in `search_query_vectors` by the query key, the
  prompt version and the model, 7 days; the write of a new row deletes the
  expired ones, as `search_understandings` does.

## Query photo

- The handler passes the upload ID; the service asks media for the
  caller's waiting upload, reads its object from `uploads/` (private),
  checks the magic bytes against the type and the pixel bounds media uses,
  shrinks it in memory and sends the bytes to the embedder.
- The upload is never attached and never processed into `media/`, so it
  never becomes public, and `MediaExpire` deletes it 24 hours after it was
  created.
- The vector is cached in `search_photo_vectors` until the upload's expiry,
  so later pages do not embed again. Every read checks the upload again, so
  an expired upload is `invalid_upload` even before its cache row is swept.
  The write of a new row deletes expired rows.
- Neither the photo nor its vector reaches a log or the journal. The user
  accepted on 2026-11-09 that the cache row ties an upload, and through it
  an account, to a vector for at most the upload's life.

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

## Embedder (`server/embedder/`)

- Python with FastAPI, uvicorn, transformers and CPU torch, locked with
  `uv`; versions are looked up when the work starts, per the newest-release
  rule.
- `POST /v1/embeddings`:

  ```json
  {"model": "BAAI/bge-m3", "input": [{"text": "..."}]}
  {"model": "google/siglip2-so400m-patch16-384", "input": [{"image": "<base64 JPEG>"}]}
  {"model": "google/siglip2-so400m-patch16-384", "input": [{"text": "a blue bicycle"}]}
  ```

  answers `{"model": "...", "data": [{"embedding": [...]}]}`, each vector
  L2-normalized.
- The server sends image bytes; the embedder never reads the store, holds
  no credentials and needs no URL to a private photo.
- Load: at most `EMBEDDER_CONCURRENCY` model runs at once and
  `EMBEDDER_QUEUE` waiting; beyond that, 503.
- Input bounds: a body size limit, a decoded pixel limit, images under 32
  px a side refused (the 1x1 crash Infinity had), at most 16 inputs a
  request.
- Weights download to a volume (`HF_HOME`) on first start, pinned by
  `EMBEDDER_TEXT_REVISION` and `EMBEDDER_IMAGE_REVISION` (Hugging Face
  commit hashes), so stored vectors always match the model that made them.
- `/healthz` says the process lives; `/readyz` says both models loaded.
- The server's `/readyz` does not depend on the embedder: search degrades
  instead, with a metric and a log line.
- It runs in `docker-compose.yml` on its own 127.0.0.1 port in
  development. Server tests use a fake embed client (see Testing), so the
  test stack does not start it.

## Configuration

Every variable is set; none has a default.

Server: `EMBED_BASE_URL`, `EMBED_TEXT_MODEL`, `EMBED_IMAGE_MODEL`,
`EMBED_TIMEOUT`, `EMBED_SLOTS`, `EMBED_TEXT_MIN_SIMILARITY`,
`EMBED_PHOTO_MIN_SIMILARITY`.

Embedder: `EMBEDDER_TEXT_MODEL`, `EMBEDDER_TEXT_REVISION`,
`EMBEDDER_IMAGE_MODEL`, `EMBEDDER_IMAGE_REVISION`,
`EMBEDDER_CONCURRENCY`, `EMBEDDER_QUEUE`, `HF_HOME`.

## Testing

Go, in `make test`:

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
  photo once; a 503 from the client retries, then succeeds.
- Service: `photo` requires the caller's waiting upload; page 2 of a photo
  search calls no model; the embedder down leaves `q` on BM25 and gives
  `photo` a 503; the model down sends the raw query to the text vector.
- `api/spec_test.go` catches drift between the OpenAPI spec and the routes.

Python, pytest in `server/embedder/`:

- Input checks against a stub model: body too large, image under 32 px,
  more than 16 inputs, a full queue answers 503.
- One smoke test marked `slow` loads the real models and checks the
  dimensions (1024, 1152) and L2 norms. It is not part of `make test`,
  since it downloads several GB.

Eval, `make search-eval`, against the real embedder:

- About 40 sample listings with real photos and 40 to 50 queries, each
  with the listings it must return: typos ("ip13 pm"), synonyms ("xe cho
  bé" against "xe đạp trẻ em"), looks ("áo khoác xanh rêu"), photo queries
  (another shot of the same item) and `like`.
- It prints recall@10 and nDCG@10 per search kind and per query; those
  numbers tune the RRF weights and the two floors.
- Photos: the app's fixture photos where their licenses allow, otherwise
  generated with gpt-image-2.5 through the proxy.

## Follow-ups

- The embedder's manifest in the k3d cluster (`infra/`).
- `photo` with `q`, once the app has a screen for it.
- The app's `readPhoto` and `similar` move from fakes to this endpoint.
