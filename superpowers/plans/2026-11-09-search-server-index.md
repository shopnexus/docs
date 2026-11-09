# Search by photo, similar listings and hybrid text search: server, index Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `GET /v1/search` gains `photo=<upload_id>` and `like=<listing_id>`, and `q` fuses BM25 with BGE-M3 text vectors and SigLIP 2 photo vectors by weighted RRF; listings get their vectors from a Restate Virtual Object.

**Architecture:** Catalog owns listing vectors (`listing_text_vectors`, `listing_photo_vectors`, pgvector `halfvec` with HNSW) beside its ParadeDB index, keeps them in line through the Virtual Object `ListingEmbed` that `ListingPublish` and `ListingEdit` send to, and runs one hybrid SQL statement (CTEs `bm25`, `txt`, `img`, `boost`, then `fused`). Discovery owns the query side: the understanding gains `rewritten` and `visual`, query vectors and query-photo vectors are cached in Postgres, and media reads the caller's waiting upload into a small JPEG. The server calls the LiteLLM aliases `embed-text` and `embed-image` through `internal/provider/embed`, an OpenAI-style `POST /embeddings` client.

**Tech Stack:** Go (repo's version), pgx v5 with `pgx.StrictNamedArgs`, ParadeDB 0.26.3 (pg_search + pgvector 0.8.x), Restate Go SDK v1.1.0, kin-openapi spec middleware, the test stack of `docker-compose.test.yml`.

**Part 1 of 2.** Tasks keep the numbers of the whole server plan; tasks 1, 9–12, 14 and 15 are in `2026-11-09-search-server-query.md`, which runs after this file. This part ends with every listing getting vectors through `ListingEmbed`; search does not read them yet.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-09-server2-photo-similar-search-design.md`. Plans 1 (`ai`: `POST /v1/embeddings` for SigLIP 2) and 2 (`infra`: LiteLLM aliases, keys, TEI) are separate; this plan runs on fakes and needs them only for `make search-eval` (Task 15).

## Global Constraints

- Every configuration variable is required and has no default, in Go, `.env.example`, Docker Compose, the Makefile and test helpers; a variable whose empty value means something (`EMBED_INDEX_API_KEY`, `EMBED_SEARCH_API_KEY` locally) is still set, to the empty string.
- Every SQL statement passes parameters as `pgx.StrictNamedArgs` with `@name` placeholders. No `$1`.
- A use case, a Restate handler and an HTTP handler read top to bottom; a helper exists only when several places call it.
- A `restate.Run` step only reads or writes a store (an embedding call counts as a read of a remote store, as MediaProcess's processing does); every decision is taken between steps on journaled values. No step returns a vector.
- Dimensions: text 1024 (`BAAI/bge-m3`), photo 1152 (`siglip2-so400m-patch16-384`).
- Aliases: `EMBED_TEXT_MODEL=embed-text`, `EMBED_IMAGE_MODEL=embed-image` in every environment that has LiteLLM.
- Version strings are stored in each vector row's `model` column, e.g. `EMBED_TEXT_VERSION=bge-m3@5617a9f6`, `EMBED_IMAGE_VERSION=siglip2-so400m-patch16-384-int8@29f74e67` (the variant plan 1 picks).
- RRF k = 60; each list takes at most 500 listings; results stop at 500 (`catalogdomain.MaxResults`).
- Starting weights: `q` BM25 1.0, text 1.0, photo 0.5, boosts 0.75; `like` 0.5, 1.0, 1.0, 0.5; `photo` photo 1.0 alone.
- `like`'s price band is ±30 %; its boosts are the source's subcategory and that band.
- Query photo: at most 768 px on its long side, JPEG, upright, no EXIF, sent as `data:image/jpeg;base64,...`.
- `PromptVersion` becomes 2; `visual` is at most about 12 words.
- Scratch files, logs and test output go in `tmp/`, never `/tmp`.
- Every test and subtest calls `t.Parallel()`.
- After adding a package under `internal/`, run `make depguard`; a test fails while the rules are stale.
- Commits: conventional prefix (`feat:`, `test:`, `docs:`, `build:`), no `Co-Authored-By` trailer.
- Run `golangci-lint fmt` before each commit; `make test` must pass at the end of every task.

## Review Focus

1. A `photo` that is someone else's upload, already attached to a listing, expired, or never PUT: 422 `invalid_upload`, and no embedding call is made. Pinned in Task 7 (media) and Task 12 (discovery counts zero model calls).
2. `like` on a listing that has no vectors yet (published a second ago): the page still answers from BM25 and boosts, never 500. Pinned in Task 12.
3. Paging a hybrid search: page 2 continues page 1 with no listing twice and none skipped, under every sort, because every ORDER BY ends with the ID. Pinned in Task 9.
4. A listing hidden, sold or deleted after it got vectors never shows in a vector list. Pinned in Task 9.
5. An embedding endpoint that answers 200 with the wrong number of vectors, the wrong dimension or a NaN: an error the caller degrades on, never a Postgres error or a panic. Pinned in Task 4.

## File Structure

| File | Responsibility |
|---|---|
| `api/paths/discovery.yaml`, `api/parameters/discovery.yaml` | `photo`, `like`, new errors |
| `migrations/0024_search_vectors.sql` | four vector tables, HNSW indexes |
| `internal/platform/pgvec/pgvec.go` | pgvector text form: `Format`, `Parse` |
| `internal/provider/embed/embed.go` | `Model` interface, `OpenAI` client, `ImageInput` |
| `internal/provider/embed/embedtest/embedtest.go` | deterministic counting fake, `Axis`, `Near` |
| `internal/platform/config/config.go` | `EmbedConfig` |
| `internal/catalog/domain/search.go` | `Vectors`, `Weights`, `Like`, `ExcludeSeller`, dims |
| `internal/catalog/domain/embedding.go` | `EmbeddingText`, `TextHash`, `ProcessedPhotos` |
| `internal/catalog/repository/vector_pg.go` | `Vectors` store |
| `internal/catalog/repository/search_pg.go` | hybrid SQL |
| `internal/catalog/service/listing_embed_durable.go` | Virtual Object `ListingEmbed` |
| `internal/media/service/upload_query.go` | `QueryUpload`, `QueryImage`, `ReadPhoto` |
| `internal/discovery/domain/fusion.go` | weights, `LikeTerms` |
| `internal/discovery/repository/vectors_pg.go` | `QueryVectors`, `PhotoVectors` caches |
| `internal/discovery/service/search.go` | the three search kinds and their degradation |
| `cmd/search-reindex/main.go` | backfill and model change |
| `internal/discovery/eval/` | sample set and `make search-eval` |

---

### Task 2: Configuration

**Files:**
- Modify: `internal/platform/config/config.go`
- Modify: `internal/platform/config/config_test.go`
- Modify: `.env.example`
- Modify: `internal/app/app_test.go`, `e2e/main_test.go` (config literals; `exhaustruct` checks config structs)

**Interfaces:**
- Produces: `config.EmbedConfig{TextBaseURL, ImageBaseURL, TextModel, ImageModel, TextVersion, ImageVersion, IndexAPIKey, SearchAPIKey string; Timeout time.Duration; Slots int; TextMinSimilarity, PhotoMinSimilarity float64}` as `Config.Embed`.

- [ ] **Step 1: Write the failing test**

In `config_test.go`, add to the map of the full valid environment (next to `"LLM_MODEL": "a-model",`):

```go
		"EMBED_TEXT_BASE_URL":         "http://tei.example.test/v1",
		"EMBED_IMAGE_BASE_URL":        "http://ai.example.test/v1",
		"EMBED_TEXT_MODEL":            "embed-text",
		"EMBED_IMAGE_MODEL":           "embed-image",
		"EMBED_TEXT_VERSION":          "bge-m3@5617a9f6",
		"EMBED_IMAGE_VERSION":         "siglip2-so400m-patch16-384-int8@29f74e67",
		"EMBED_INDEX_API_KEY":         "",
		"EMBED_SEARCH_API_KEY":        "search-key",
		"EMBED_TIMEOUT":               "10s",
		"EMBED_SLOTS":                 "2",
		"EMBED_TEXT_MIN_SIMILARITY":   "0.45",
		"EMBED_PHOTO_MIN_SIMILARITY":  "0.6",
```

and to the expected `Config` (next to `LLM: LLMConfig{...}`):

```go
		Embed: EmbedConfig{
			TextBaseURL: "http://tei.example.test/v1", ImageBaseURL: "http://ai.example.test/v1",
			TextModel: "embed-text", ImageModel: "embed-image",
			TextVersion: "bge-m3@5617a9f6", ImageVersion: "siglip2-so400m-patch16-384-int8@29f74e67",
			IndexAPIKey: "", SearchAPIKey: "search-key", Timeout: 10 * time.Second, Slots: 2,
			TextMinSimilarity: 0.45, PhotoMinSimilarity: 0.6,
		},
```

Add a table test for the bad values:

```go
func TestEmbedValuesAreChecked(t *testing.T) {
	t.Parallel()
	for name, tc := range map[string]struct{ key, value, want string }{
		"timeout":   {"EMBED_TIMEOUT", "soon", "EMBED_TIMEOUT"},
		"slots":     {"EMBED_SLOTS", "0", "EMBED_SLOTS"},
		"floor":     {"EMBED_TEXT_MIN_SIMILARITY", "1.5", "EMBED_TEXT_MIN_SIMILARITY"},
		"no floor":  {"EMBED_PHOTO_MIN_SIMILARITY", "", "EMBED_PHOTO_MIN_SIMILARITY"},
		"no search": {"EMBED_SEARCH_API_KEY", "\x00unset", "EMBED_SEARCH_API_KEY is not set"},
	} {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			env := validEnv() // the helper that returns the full valid map; name it as the file does
			if tc.value == "\x00unset" {
				delete(env, tc.key)
			} else {
				env[tc.key] = tc.value
			}
			_, err := Load(func(k string) (string, bool) { v, ok := env[k]; return v, ok })
			if err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("err = %v, want it to name %s", err, tc.want)
			}
		})
	}
}
```

(If the file builds the valid map inline, extract it into `validEnv()` first, in this step.)

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/platform/config/ -run 'TestLoad|TestEmbed' -v`
Expected: FAIL, `Embed` undefined.

- [ ] **Step 3: Implement**

In `config.go`, add the type after `LLMConfig`:

```go
// EmbedConfig says where the embedding models are and how search uses them.
// In the cluster both base URLs are the stack's LiteLLM and the models are
// its aliases; locally they are TEI and ai, which take no key.
type EmbedConfig struct {
	TextBaseURL  string // EMBED_TEXT_BASE_URL: POST {base}/embeddings for text
	ImageBaseURL string // EMBED_IMAGE_BASE_URL: the same for photos and visual text
	TextModel    string // EMBED_TEXT_MODEL, the alias embed-text
	ImageModel   string // EMBED_IMAGE_MODEL, the alias embed-image
	// TextVersion and ImageVersion name the model behind each alias. Every
	// vector row stores its version; a new version embeds again.
	TextVersion  string // EMBED_TEXT_VERSION
	ImageVersion string // EMBED_IMAGE_VERSION
	IndexAPIKey  string // EMBED_INDEX_API_KEY: ListingEmbed's key; empty locally
	SearchAPIKey string // EMBED_SEARCH_API_KEY: the search's key; empty locally
	Timeout      time.Duration // EMBED_TIMEOUT: one embedding call
	Slots        int           // EMBED_SLOTS: embeddings ListingEmbed runs at once in this process
	// TextMinSimilarity and PhotoMinSimilarity are the cosine a listing needs
	// to join a vector list.
	TextMinSimilarity  float64 // EMBED_TEXT_MIN_SIMILARITY, in (0, 1)
	PhotoMinSimilarity float64 // EMBED_PHOTO_MIN_SIMILARITY, in (0, 1)
}
```

Add `Embed EmbedConfig` to `Config` after `LLM`. In `Load`, after `oneOf`, add the parsers:

```go
	positive := func(key string) int {
		v := need(key)
		n, err := strconv.Atoi(v)
		if v != "" && (err != nil || n < 1) {
			errs = append(errs, fmt.Errorf("%s=%q: want a positive integer", key, v))
		}
		return n
	}
	duration := func(key string) time.Duration {
		v := need(key)
		d, err := time.ParseDuration(v)
		if v != "" && (err != nil || d <= 0) {
			errs = append(errs, fmt.Errorf("%s=%q: want a positive duration such as 10s", key, v))
		}
		return d
	}
	fraction := func(key string) float64 {
		v := need(key)
		f, err := strconv.ParseFloat(v, 64)
		if v != "" && (err != nil || f <= 0 || f >= 1) {
			errs = append(errs, fmt.Errorf("%s=%q: want a number between 0 and 1", key, v))
		}
		return f
	}
```

and in the `cfg := Config{...}` literal, after `LLM:`:

```go
		Embed: EmbedConfig{
			TextBaseURL: need("EMBED_TEXT_BASE_URL"), ImageBaseURL: need("EMBED_IMAGE_BASE_URL"),
			TextModel: need("EMBED_TEXT_MODEL"), ImageModel: need("EMBED_IMAGE_MODEL"),
			TextVersion: need("EMBED_TEXT_VERSION"), ImageVersion: need("EMBED_IMAGE_VERSION"),
			IndexAPIKey: set("EMBED_INDEX_API_KEY"), SearchAPIKey: set("EMBED_SEARCH_API_KEY"),
			Timeout: duration("EMBED_TIMEOUT"), Slots: positive("EMBED_SLOTS"),
			TextMinSimilarity: fraction("EMBED_TEXT_MIN_SIMILARITY"), PhotoMinSimilarity: fraction("EMBED_PHOTO_MIN_SIMILARITY"),
		},
```

In `.env.example`, after the `LLM_MODEL=` line:

```bash
# The embedding models search uses (see ARCHITECTURE.md, Search). Locally the
# server calls TEI (text) and ai (photos) directly, which take no key; in the
# cluster both URLs are LiteLLM and the models its aliases.
EMBED_TEXT_BASE_URL=http://127.0.0.1:56800/v1
EMBED_IMAGE_BASE_URL=http://127.0.0.1:56810/v1
EMBED_TEXT_MODEL=bge-m3
EMBED_IMAGE_MODEL=siglip2-so400m-patch16-384
# The model behind each alias; a new value re-embeds through search-reindex.
EMBED_TEXT_VERSION=bge-m3@5617a9f6
EMBED_IMAGE_VERSION=siglip2-so400m-patch16-384-int8@29f74e67
# Empty: TEI and ai have no keys. In the cluster: server-embed-index's and
# server-embed-search's keys.
EMBED_INDEX_API_KEY=
EMBED_SEARCH_API_KEY=
EMBED_TIMEOUT=10s
EMBED_SLOTS=2
# Starting floors; make search-eval tunes them.
EMBED_TEXT_MIN_SIMILARITY=0.45
EMBED_PHOTO_MIN_SIMILARITY=0.6
```

`make run` starts `docker-compose.yml` of this repo, which has neither TEI nor ai (plan 2 adds them to the umbrella's compose, where the server runs in a container and calls `tei-dev:80`). Add both here under a profile `models`, so `make run` stays light and search degrades to BM25 until they run. Copy the TEI image tag, its `--model-id`/`--revision` arguments and the `AI_*` values from plan 2's Task 8 compose block so the two composes run the same thing:

```yaml
  # The embedding models (see ARCHITECTURE.md, Search). Heavy: about 2 GB of
  # images and 2.5 GB of weights. Start them with
  #   docker compose --profile models up -d tei ai
  # Without them search runs on BM25 alone and ListingEmbed retries.
  tei:
    profiles: [models]
    image: ghcr.io/huggingface/text-embeddings-inference:cpu-1.9.4
    command: ["--model-id", "BAAI/bge-m3", "--revision", "5617a9f61b028005a4858fdac845db406aefb181", "--port", "80"]
    ports:
      - "127.0.0.1:56800:80"
    volumes:
      - tei-data:/data
  ai:
    profiles: [models]
    image: ghcr.io/shopnexus/ai:main
    environment:
      AI_ADDR: ":8000"
      AI_STT_MODELS: gipformer-1.5=/models/gipformer-1.5
      AI_VAD_MODEL: /models/silero_vad.onnx
      AI_NUM_THREADS: "4"
      AI_MAX_CONCURRENT: "2"
      AI_MAX_UPLOAD_MB: "100"
      AI_MAX_AUDIO_SECONDS: "300"
      AI_EMBED_MODELS: siglip2-so400m-patch16-384=/models/siglip2-so400m-patch16-384
      AI_EMBED_MAX_INPUTS: "16"
      AI_EMBED_MAX_CONCURRENT: "2"
      AI_EMBED_MAX_IMAGE_MB: "10"
    ports:
      - "127.0.0.1:56810:8000"
```

and `tei-data:` under the file's top-level `volumes:`. Add one line to the README's command table: `docker compose --profile models up -d tei ai` starts the embedding models for `make run`.

In `internal/app/app_test.go` and `e2e/main_test.go`, add to the config literal:

```go
		Embed: config.EmbedConfig{
			TextBaseURL: "http://127.0.0.1:1", ImageBaseURL: "http://127.0.0.1:1",
			TextModel: "embed-text", ImageModel: "embed-image", TextVersion: "text-test", ImageVersion: "image-test",
			IndexAPIKey: "", SearchAPIKey: "", Timeout: time.Second, Slots: 1,
			TextMinSimilarity: 0.5, PhotoMinSimilarity: 0.5,
		},
```

(Task 8 points e2e at a stub.)

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/platform/config/ ./internal/app/ -v -run 'TestLoad|TestEmbed|TestNew'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/platform/config .env.example internal/app/app_test.go e2e/main_test.go
git commit -m "feat(config): the EMBED_ variables"
```

---

### Task 3: Migration 0024 and the pgvector text form

**Files:**
- Create: `migrations/0024_search_vectors.sql`
- Create: `internal/platform/pgvec/pgvec.go`, `internal/platform/pgvec/pgvec_test.go`

**Interfaces:**
- Produces: tables `listing_text_vectors`, `listing_photo_vectors`, `search_photo_vectors`, `search_query_vectors`; `pgvec.Format(v []float32) string`, `pgvec.Parse(s string) ([]float32, error)`.

- [ ] **Step 1: Write the failing test**

`internal/platform/pgvec/pgvec_test.go`:

```go
package pgvec_test

import (
	"context"
	"slices"
	"testing"

	"github.com/jackc/pgx/v5"

	"github.com/shopnexus/server2/internal/platform/pgvec"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
)

func TestRoundTrip(t *testing.T) {
	t.Parallel()
	v := []float32{0.5, -0.25, 1, 0}
	got, err := pgvec.Parse(pgvec.Format(v))
	if err != nil || !slices.Equal(got, v) {
		t.Fatalf("%v %v", got, err)
	}
}

func TestParseRefuses(t *testing.T) {
	t.Parallel()
	for _, s := range []string{"", "1,2", "[1,x]", "[1,,2]"} {
		if _, err := pgvec.Parse(s); err == nil {
			t.Errorf("Parse(%q) took it", s)
		}
	}
}

// TestHalfvecAcceptsTheForm checks the form against Postgres: a halfvec cast
// from Format prints back what Parse reads.
func TestHalfvecAcceptsTheForm(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	var out string
	err := db.QueryRow(context.Background(), `SELECT (@v::halfvec(3))::text`,
		pgx.StrictNamedArgs{"v": pgvec.Format([]float32{0.5, -0.25, 1})}).Scan(&out)
	if err != nil {
		t.Fatal(err)
	}
	got, err := pgvec.Parse(out)
	if err != nil || !slices.Equal(got, []float32{0.5, -0.25, 1}) {
		t.Fatalf("%q → %v %v", out, got, err)
	}
}

func TestTablesExist(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	for _, table := range []string{"listing_text_vectors", "listing_photo_vectors", "search_photo_vectors", "search_query_vectors"} {
		var n int
		if err := db.QueryRow(context.Background(), `SELECT count(*) FROM `+table).Scan(&n); err != nil {
			t.Errorf("%s: %v", table, err)
		}
	}
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/platform/pgvec/`
Expected: FAIL, package `pgvec` does not exist.

- [ ] **Step 3: Implement the package**

`internal/platform/pgvec/pgvec.go`:

```go
// Package pgvec writes and reads pgvector values in their text form,
// "[0.5,-0.25,1]", which vector and halfvec cast from and print. Queries pass
// a vector as text and cast it in SQL, so no driver type is registered.
package pgvec

import (
	"fmt"
	"strconv"
	"strings"
)

// Format writes v in pgvector's text form. Its values must be finite; the
// embed client refuses anything else before a vector gets here.
func Format(v []float32) string {
	var b strings.Builder
	b.Grow(len(v)*11 + 2)
	b.WriteByte('[')
	for i, x := range v {
		if i > 0 {
			b.WriteByte(',')
		}
		b.WriteString(strconv.FormatFloat(float64(x), 'g', -1, 32))
	}
	b.WriteByte(']')
	return b.String()
}

// Parse reads pgvector's text form.
func Parse(s string) ([]float32, error) {
	s = strings.TrimSpace(s)
	if len(s) < 2 || s[0] != '[' || s[len(s)-1] != ']' {
		return nil, fmt.Errorf("pgvec: not a vector: %.20q", s)
	}
	body := s[1 : len(s)-1]
	if body == "" {
		return []float32{}, nil
	}
	parts := strings.Split(body, ",")
	out := make([]float32, len(parts))
	for i, p := range parts {
		f, err := strconv.ParseFloat(strings.TrimSpace(p), 32)
		if err != nil {
			return nil, fmt.Errorf("pgvec: element %d: %w", i, err)
		}
		out[i] = float32(f)
	}
	return out, nil
}
```

- [ ] **Step 4: Write the migration**

`migrations/0024_search_vectors.sql`:

```sql
-- Search vectors: one text vector and one vector per processed photo of each
-- listing, and the caches of the query side. Vectors are halfvec, half the
-- size of vector; the HNSW indexes use cosine distance. model holds the
-- version string the server is configured with (EMBED_*_VERSION): a row of
-- another version counts as missing and is embedded again.

-- Catalog: title, category name, condition, specs and description.
CREATE TABLE listing_text_vectors (
    listing_id  uuid PRIMARY KEY REFERENCES listings (id) ON DELETE CASCADE,
    model       text NOT NULL,
    text_hash   bytea NOT NULL,
    embedding   halfvec (1024) NOT NULL,
    embedded_at timestamptz NOT NULL
);

-- Catalog: one row per processed photo, keyed by its object key.
CREATE TABLE listing_photo_vectors (
    listing_id  uuid NOT NULL REFERENCES listings (id) ON DELETE CASCADE,
    photo_key   text NOT NULL,
    model       text NOT NULL,
    embedding   halfvec (1152) NOT NULL,
    embedded_at timestamptz NOT NULL,
    PRIMARY KEY (listing_id, photo_key)
);

CREATE INDEX listing_text_vectors_embedding
ON listing_text_vectors USING hnsw (embedding halfvec_cosine_ops);
CREATE INDEX listing_photo_vectors_embedding
ON listing_photo_vectors USING hnsw (embedding halfvec_cosine_ops);

-- Discovery: a query photo's vector, until its upload expires. It holds the
-- upload ID and no account; the upload row ties it to one for that long.
CREATE TABLE search_photo_vectors (
    upload_id  uuid PRIMARY KEY,
    model      text NOT NULL,
    embedding  halfvec (1152) NOT NULL,
    expires_at timestamptz NOT NULL
);
CREATE INDEX search_photo_vectors_expires ON search_photo_vectors (expires_at);

-- Discovery: the vector of a text the search embedded (the rewritten query,
-- or its visual description), 7 days like the understanding.
CREATE TABLE search_query_vectors (
    query_key      text NOT NULL,
    prompt_version integer NOT NULL,
    model          text NOT NULL,
    embedding      halfvec NOT NULL,
    created_at     timestamptz NOT NULL,
    PRIMARY KEY (query_key, prompt_version, model)
);
CREATE INDEX search_query_vectors_created ON search_query_vectors (created_at);
```

- [ ] **Step 5: Run the tests and the SQL linter**

Run: `make depguard && go test ./internal/platform/pgvec/ ./migrations/ && sqlfluff lint migrations/0024_search_vectors.sql`
Expected: PASS; sqlfluff reports nothing (fix spacing it names).

- [ ] **Step 6: Commit**

```bash
git add migrations/0024_search_vectors.sql internal/platform/pgvec .golangci.yml
git commit -m "feat: the search vector tables and pgvector's text form"
```

---

### Task 4: The embed client and its fake

**Files:**
- Create: `internal/provider/embed/embed.go`, `internal/provider/embed/embed_test.go`
- Create: `internal/provider/embed/embedtest/embedtest.go`, `internal/provider/embed/embedtest/embedtest_test.go`

**Interfaces:**
- Produces:
  - `embed.Model` interface: `Embed(ctx context.Context, inputs []string) ([][]float32, error)`.
  - `embed.OpenAI{BaseURL, APIKey, Model string; Dims int; HTTP *http.Client}` implementing `Model`.
  - `embed.ErrRefused`: the endpoint refused the input itself (HTTP 400, 404, 413, 422); retrying will not help.
  - `embed.ImageInput(jpeg []byte) string`.
  - `embedtest.New(dims int) *embedtest.Model` with `Set(input string, v []float32)`, `SetFail(err error)`, `Calls() int`, `Inputs() []string`; `embedtest.Axis(dims, i int) []float32`; `embedtest.Near(dims, i, j int, sim float64) []float32` (cosine `sim` with `Axis(dims, i)`).

- [ ] **Step 1: Write the failing tests**

`internal/provider/embed/embed_test.go`:

```go
package embed_test

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/shopnexus/server2/internal/provider/embed"
)

// server answers every request with reply and keeps the last request body.
func server(t *testing.T, status int, reply string, got *map[string]any, auth *string) string {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/embeddings" || r.Method != http.MethodPost {
			http.NotFound(w, r)
			return
		}
		b, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(b, got)
		*auth = r.Header.Get("Authorization")
		w.WriteHeader(status)
		_, _ = io.WriteString(w, reply)
	}))
	t.Cleanup(srv.Close)
	return srv.URL + "/v1"
}

func TestEmbedSendsAndOrders(t *testing.T) {
	t.Parallel()
	var got map[string]any
	var auth string
	base := server(t, 200, `{"object":"list","data":[
{"object":"embedding","index":1,"embedding":[0,1]},
{"object":"embedding","index":0,"embedding":[1,0]}],"usage":{"prompt_tokens":2,"total_tokens":2}}`, &got, &auth)
	m := embed.OpenAI{BaseURL: base, APIKey: "k", Model: "embed-text", Dims: 2, HTTP: &http.Client{}}
	vs, err := m.Embed(context.Background(), []string{"a", "b"})
	if err != nil || len(vs) != 2 || vs[0][0] != 1 || vs[1][1] != 1 {
		t.Fatalf("%v %v", vs, err)
	}
	if got["model"] != "embed-text" || got["encoding_format"] != "float" || auth != "Bearer k" {
		t.Fatalf("request %v, auth %q", got, auth)
	}
}

func TestEmbedWithoutKeySendsNoHeader(t *testing.T) {
	t.Parallel()
	var got map[string]any
	auth := "unset"
	base := server(t, 200, `{"data":[{"index":0,"embedding":[1,0]}]}`, &got, &auth)
	if _, err := (embed.OpenAI{BaseURL: base, Model: "m", Dims: 2, HTTP: &http.Client{}}).Embed(context.Background(), []string{"a"}); err != nil {
		t.Fatal(err)
	}
	if auth != "" {
		t.Fatalf("Authorization %q without a key", auth)
	}
}

func TestEmbedRefusesBadReplies(t *testing.T) {
	t.Parallel()
	for name, tc := range map[string]struct {
		status  int
		reply   string
		refused bool
	}{
		"too few":     {200, `{"data":[{"index":0,"embedding":[1,0]}]}`, false},
		"wrong dims":  {200, `{"data":[{"index":0,"embedding":[1,0,0]},{"index":1,"embedding":[1,0]}]}`, false},
		"index twice": {200, `{"data":[{"index":0,"embedding":[1,0]},{"index":0,"embedding":[1,0]}]}`, false},
		"nan":         {200, `{"data":[{"index":0,"embedding":[1,"NaN"]},{"index":1,"embedding":[1,0]}]}`, false},
		"not json":    {200, `<html>`, false},
		"rate":        {429, `{"error":{"message":"slow down"}}`, false},
		"down":        {503, ``, false},
		"bad input":   {400, `{"error":{"message":"image under 32 px"}}`, true},
	} {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			var got map[string]any
			var auth string
			base := server(t, tc.status, tc.reply, &got, &auth)
			_, err := (embed.OpenAI{BaseURL: base, Model: "m", Dims: 2, HTTP: &http.Client{}}).Embed(context.Background(), []string{"a", "b"})
			if err == nil {
				t.Fatal("took a bad reply")
			}
			if errors.Is(err, embed.ErrRefused) != tc.refused {
				t.Fatalf("ErrRefused = %v for %v", !tc.refused, err)
			}
		})
	}
}

func TestImageInput(t *testing.T) {
	t.Parallel()
	if got := embed.ImageInput([]byte{0xFF, 0xD8}); got != "data:image/jpeg;base64,/9g=" {
		t.Fatal(got)
	}
}
```

`internal/provider/embed/embedtest/embedtest_test.go`:

```go
package embedtest_test

import (
	"context"
	"errors"
	"math"
	"testing"

	"github.com/shopnexus/server2/internal/provider/embed/embedtest"
)

func cos(a, b []float32) float64 {
	var s float64
	for i := range a {
		s += float64(a[i]) * float64(b[i])
	}
	return s
}

func TestFake(t *testing.T) {
	t.Parallel()
	m := embedtest.New(8)
	ctx := context.Background()
	a, _ := m.Embed(ctx, []string{"xe đạp"})
	b, _ := m.Embed(ctx, []string{"xe đạp"})
	if cos(a[0], b[0]) < 0.9999 || math.Abs(cos(a[0], a[0])-1) > 1e-5 || m.Calls() != 2 {
		t.Fatalf("not deterministic or not unit: %v %v %d", a, b, m.Calls())
	}
	m.Set("bike", embedtest.Axis(8, 3))
	v, _ := m.Embed(ctx, []string{"bike"})
	if v[0][3] != 1 {
		t.Fatal(v)
	}
	if s := cos(embedtest.Near(8, 0, 1, 0.7), embedtest.Axis(8, 0)); math.Abs(s-0.7) > 1e-5 {
		t.Fatal(s)
	}
	m.SetFail(errors.New("down"))
	if _, err := m.Embed(ctx, []string{"x"}); err == nil {
		t.Fatal("no failure")
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/provider/embed/...`
Expected: FAIL, packages do not exist.

- [ ] **Step 3: Implement the client**

`internal/provider/embed/embed.go`:

```go
// Package embed turns text and photos into vectors through an
// OpenAI-compatible POST /embeddings: LiteLLM's aliases in the cluster, TEI
// and ai locally. An image goes as a data URL string, the convention LiteLLM
// uses for multimodal embeddings. It knows nothing about what the vectors are
// for.
package embed

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"strings"
)

// Model embeds inputs with one model; the vectors come back in input order.
type Model interface {
	Embed(ctx context.Context, inputs []string) ([][]float32, error)
}

// ErrRefused means the endpoint refused the input itself; sending it again
// will not help. Load, budget and rate refusals (429, 5xx) are other errors.
var ErrRefused = errors.New("embed: the input was refused")

// OpenAI is a Model over an OpenAI-compatible API.
type OpenAI struct {
	BaseURL string // ends in /v1
	APIKey  string // empty sends no Authorization header
	Model   string
	Dims    int // the length every vector must have
	HTTP    *http.Client
}

// maxReply caps how much of a reply is read: 16 inputs of 1152 floats as
// JSON are about 400 KB.
const maxReply = 8 << 20

func (c OpenAI) Embed(ctx context.Context, inputs []string) ([][]float32, error) {
	body, err := json.Marshal(map[string]any{"model": c.Model, "input": inputs, "encoding_format": "float"})
	if err != nil {
		return nil, fmt.Errorf("encode request: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(c.BaseURL, "/")+"/embeddings", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	if c.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.APIKey)
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := c.HTTP.Do(req)
	if err != nil {
		return nil, fmt.Errorf("call %s: %w", c.Model, err)
	}
	defer func() { _ = res.Body.Close() }()
	switch {
	case res.StatusCode == http.StatusOK:
	case res.StatusCode == http.StatusBadRequest, res.StatusCode == http.StatusNotFound,
		res.StatusCode == http.StatusRequestEntityTooLarge, res.StatusCode == http.StatusUnprocessableEntity:
		return nil, fmt.Errorf("%w: %s answered %d", ErrRefused, c.Model, res.StatusCode)
	default:
		return nil, fmt.Errorf("%s answered %d", c.Model, res.StatusCode)
	}
	var reply struct {
		Data []struct {
			Index     int       `json:"index"`
			Embedding []float64 `json:"embedding"`
		} `json:"data"`
	}
	if err = json.NewDecoder(io.LimitReader(res.Body, maxReply)).Decode(&reply); err != nil {
		return nil, fmt.Errorf("decode %s's reply: %w", c.Model, err)
	}
	if len(reply.Data) != len(inputs) {
		return nil, fmt.Errorf("%s gave %d vectors for %d inputs", c.Model, len(reply.Data), len(inputs))
	}
	out := make([][]float32, len(inputs))
	for _, d := range reply.Data {
		if d.Index < 0 || d.Index >= len(out) || out[d.Index] != nil {
			return nil, fmt.Errorf("%s gave index %d twice or out of range", c.Model, d.Index)
		}
		if len(d.Embedding) != c.Dims {
			return nil, fmt.Errorf("%s gave %d dimensions, want %d", c.Model, len(d.Embedding), c.Dims)
		}
		v := make([]float32, c.Dims)
		for i, x := range d.Embedding {
			if math.IsNaN(x) || math.IsInf(x, 0) {
				return nil, fmt.Errorf("%s gave a value that is not finite", c.Model)
			}
			v[i] = float32(x)
		}
		out[d.Index] = v
	}
	return out, nil
}

// ImageInput is a JPEG as an input string.
func ImageInput(jpeg []byte) string {
	return "data:image/jpeg;base64," + base64.StdEncoding.EncodeToString(jpeg)
}
```

Note: `encoding/json` refuses the string `"NaN"` in a `[]float64`, so the "nan" case fails at decode; the finite check covers a provider that writes a bare `NaN` token some other way.

- [ ] **Step 4: Implement the fake**

`internal/provider/embed/embedtest/embedtest.go`:

```go
// Package embedtest is an embed.Model for tests: each input maps to a fixed
// unit vector, from its SHA-256 unless a test set one, so equal inputs give
// equal vectors and unrelated inputs are close to orthogonal.
package embedtest

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"math"
	"math/rand/v2"
	"sync"
)

// Model counts its calls and inputs and fails while a failure is set.
type Model struct {
	dims   int
	mu     sync.Mutex
	fixed  map[string][]float32
	calls  int
	inputs []string
	fail   error
}

func New(dims int) *Model { return &Model{dims: dims, fixed: map[string][]float32{}} }

// Set makes input embed to v, normalized.
func (m *Model) Set(input string, v []float32) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.fixed[input] = unit(v)
}

// SetFail makes every call fail with err; nil ends it.
func (m *Model) SetFail(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.fail = err
}

func (m *Model) Calls() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.calls
}

func (m *Model) Inputs() []string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]string{}, m.inputs...)
}

func (m *Model) Embed(ctx context.Context, inputs []string) ([][]float32, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.calls++
	m.inputs = append(m.inputs, inputs...)
	if m.fail != nil {
		return nil, m.fail
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	out := make([][]float32, len(inputs))
	for i, in := range inputs {
		if v, ok := m.fixed[in]; ok {
			out[i] = append([]float32{}, v...)
			continue
		}
		sum := sha256.Sum256([]byte(in))
		r := rand.New(rand.NewPCG(binary.LittleEndian.Uint64(sum[:8]), binary.LittleEndian.Uint64(sum[8:16])))
		v := make([]float32, m.dims)
		for j := range v {
			v[j] = float32(r.NormFloat64())
		}
		out[i] = unit(v)
	}
	return out, nil
}

// Axis is the unit vector along axis i.
func Axis(dims, i int) []float32 {
	v := make([]float32, dims)
	v[i] = 1
	return v
}

// Near is the unit vector at cosine sim from Axis(dims, i), leaning toward
// axis j.
func Near(dims, i, j int, sim float64) []float32 {
	v := make([]float32, dims)
	v[i] = float32(sim)
	v[j] = float32(math.Sqrt(1 - sim*sim))
	return v
}

func unit(v []float32) []float32 {
	var s float64
	for _, x := range v {
		s += float64(x) * float64(x)
	}
	n := float32(math.Sqrt(s))
	out := make([]float32, len(v))
	for i, x := range v {
		out[i] = x / n
	}
	return out
}
```

- [ ] **Step 5: Run the tests, regenerate depguard**

Run: `make depguard && go test ./internal/provider/embed/... -v`
Expected: PASS; `.golangci.yml` now lists `embedtest` as test support.

- [ ] **Step 6: Commit**

```bash
git add internal/provider/embed .golangci.yml
git commit -m "feat: the embed client over an OpenAI-style embeddings API"
```

---

### Task 5: Catalog domain: embedding text and hybrid search terms

**Files:**
- Create: `internal/catalog/domain/embedding.go`, `internal/catalog/domain/embedding_test.go`
- Modify: `internal/catalog/domain/search.go`

**Interfaces:**
- Produces:
  - `domain.TextDims = 1024`, `domain.PhotoDims = 1152`, `domain.RRFK = 60`.
  - `(*Listing).EmbeddingText(category string) string`, `domain.EmbeddingTextMax = 2000`.
  - `domain.TextHash(version, text string) []byte`.
  - `(*Listing).ProcessedPhotos() []string` (processed photo keys in order).
  - `domain.Vectors{Text, Photo []float32; TextVersion, PhotoVersion string; TextMin, PhotoMin float64}`.
  - `domain.Weights{BM25, Text, Photo, Boost float64}`.
  - `domain.Search` gains `Vectors Vectors`, `Weights Weights`, `Like uuid.UUID`, `ExcludeSeller uuid.UUID`, and `(Search).Hybrid() bool`.

- [ ] **Step 1: Write the failing test**

`internal/catalog/domain/embedding_test.go`:

```go
package domain_test

import (
	"bytes"
	"strings"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/catalog/domain"
)

func listing(t *testing.T, change func(*domain.Draft)) domain.Listing {
	t.Helper()
	photo := uuid.NewV7()
	d := domain.Draft{
		Title: "iPhone 13 128GB", Price: 9_500_000, Description: "Máy zin, pin 89%", CategoryCode: "phones.iphone",
		Condition: domain.ConditionLikeNew, CommuneCode: "00004", Photos: []uuid.UUID{photo},
		Specs: []domain.Spec{{Label: "Màu", Value: "Xanh"}},
	}
	if change != nil {
		change(&d)
	}
	l, err := domain.NewListing(uuid.NewV7(), uuid.NewV7(), d, domain.Refs{CategoryIsLeaf: true, CommuneExists: true}, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	l.Published(map[uuid.UUID]domain.PhotoKeys{photo: {Photo: "media/p.jpg", Thumb: "media/p_thumb.jpg"}}, time.Now())
	return l
}

func TestEmbeddingText(t *testing.T) {
	t.Parallel()
	l := listing(t, nil)
	got := l.EmbeddingText("iPhone")
	want := "iPhone 13 128GB\niPhone\nNhư mới\nMàu: Xanh\nMáy zin, pin 89%"
	if got != want {
		t.Fatalf("%q", got)
	}
	if n := len([]rune(listing(t, func(d *domain.Draft) {
		d.Description = strings.Repeat("ạ", 1500)
		d.Specs = []domain.Spec{{Label: strings.Repeat("x", 20), Value: strings.Repeat("y", 60)}}
	}).EmbeddingText(strings.Repeat("c", 600)))); n != domain.EmbeddingTextMax {
		t.Fatalf("%d runes", n)
	}
}

func TestTextHash(t *testing.T) {
	t.Parallel()
	a, b := domain.TextHash("v1", "x"), domain.TextHash("v2", "x")
	if bytes.Equal(a, b) || !bytes.Equal(a, domain.TextHash("v1", "x")) || len(a) != 32 {
		t.Fatal("the hash must change with the version and only with it")
	}
}

func TestProcessedPhotos(t *testing.T) {
	t.Parallel()
	l := listing(t, nil)
	if got := l.ProcessedPhotos(); len(got) != 1 || got[0] != "media/p.jpg" {
		t.Fatal(got)
	}
}

func TestHybrid(t *testing.T) {
	t.Parallel()
	if (domain.Search{}).Hybrid() || !(domain.Search{Weights: domain.Weights{Photo: 1}}).Hybrid() {
		t.Fatal("Hybrid follows the weights")
	}
}
```

(The second assertion builds a listing whose title, category, specs and description pass 2,000 runes.)

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/catalog/domain/ -run 'TestEmbedding|TestTextHash|TestProcessed|TestHybrid'`
Expected: FAIL, undefined names.

- [ ] **Step 3: Implement**

`internal/catalog/domain/embedding.go`:

```go
package domain

import (
	"crypto/sha256"
	"strings"
)

const (
	// TextDims and PhotoDims are the lengths of a listing's text and photo
	// vectors: BGE-M3 and SigLIP 2 so400m. Migration 0024 fixes them.
	TextDims  = 1024
	PhotoDims = 1152
	// EmbeddingTextMax is how many characters of a listing's text are
	// embedded; BGE-M3 reads 8,192 tokens, and a listing's sense is in its
	// first lines.
	EmbeddingTextMax = 2000
)

var conditionWords = map[Condition]string{ConditionNew: "Mới", ConditionLikeNew: "Như mới", ConditionUsed: "Đã dùng"}

// EmbeddingText is what the listing's text vector is made from: the title,
// the category's name, the condition, each spec as "label: value" and the
// description, one per line, cut at EmbeddingTextMax characters.
func (l *Listing) EmbeddingText(category string) string {
	var b strings.Builder
	b.WriteString(l.title)
	b.WriteString("\n" + category)
	b.WriteString("\n" + conditionWords[l.condition])
	for _, s := range l.specs {
		b.WriteString("\n" + s.Label + ": " + s.Value)
	}
	if l.description != "" {
		b.WriteString("\n" + l.description)
	}
	text := []rune(b.String())
	if len(text) > EmbeddingTextMax {
		text = text[:EmbeddingTextMax]
	}
	return string(text)
}

// TextHash keys a text vector by the model version and the text, so a change
// of either embeds again.
func TextHash(version, text string) []byte {
	h := sha256.Sum256([]byte(version + "\x00" + text))
	return h[:]
}

// ProcessedPhotos are the object keys of the listing's processed photos, in
// order.
func (l *Listing) ProcessedPhotos() []string {
	var out []string
	for _, p := range l.photos {
		if p.Keys.Photo != "" {
			out = append(out, p.Keys.Photo)
		}
	}
	return out
}
```

In `search.go`, add after `CategoryCount`:

```go
// RRFK is the k of reciprocal rank fusion: a list's share for the listing at
// rank r is its weight / (RRFK + r).
const RRFK = 60

// Vectors are the query vectors of a hybrid search. A nil vector leaves its
// list out. A listing joins the text list at TextMin cosine or more, and the
// photo list when its closest photo is at PhotoMin or more; only vectors of
// the configured versions are read.
type Vectors struct {
	Text, Photo               []float32
	TextVersion, PhotoVersion string
	TextMin, PhotoMin         float64
}

// Weights are each list's weight in the fusion; a zero leaves the list out.
// Boost is the list that ranks the other lists' listings by boost points
// alone, so a boost moves listings a vector list found.
type Weights struct {
	BM25, Text, Photo, Boost float64
}
```

and to `Search`, after `Offset, Limit int`:

```go
	// Vectors and Weights make the search hybrid: each list (BM25 on the
	// phrases, text vectors, photo vectors, boosts) takes at most MaxResults
	// listings under the filters, and RRF fuses them. Sorts other than
	// relevance order the fused listings.
	Vectors Vectors
	Weights Weights
	// Like is the source of a similar-listings search, zero for none: the
	// service reads its vectors into Vectors, and the search leaves it out.
	Like uuid.UUID
	// ExcludeSeller leaves out one seller's listings, zero for none: the
	// viewer's own in a similar-listings search.
	ExcludeSeller uuid.UUID
```

and after the type:

```go
// Hybrid reports whether s fuses lists; otherwise it is one BM25 query.
func (s Search) Hybrid() bool { return s.Weights != Weights{} }
```

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/catalog/domain/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/catalog/domain
git commit -m "feat(catalog): a listing's embedding text and hybrid search terms"
```

---

### Task 6: Catalog repository: the vector store

**Files:**
- Create: `internal/catalog/repository/vector_pg.go`, `internal/catalog/repository/vector_pg_test.go`
- Modify: `internal/catalog/repository/repository.go`

**Interfaces:**
- Consumes: `pgvec.Format/Parse` (Task 3), tables (Task 3).
- Produces:

```go
// Vectors persists listings' search vectors.
type Vectors interface {
	State(ctx context.Context, listing uuid.UUID, textVersion, photoVersion string) (VectorState, error)
	PutText(ctx context.Context, listing uuid.UUID, version string, hash []byte, v []float32, at time.Time) error
	PutPhoto(ctx context.Context, listing uuid.UUID, key, version string, v []float32, at time.Time) error
	DropPhotosExcept(ctx context.Context, listing uuid.UUID, keys []string) error
	Source(ctx context.Context, listing uuid.UUID, textVersion, photoVersion string) (text, photo []float32, err error)
	Embeddable(ctx context.Context) ([]uuid.UUID, error)
}
type VectorState struct {
	TextHash []byte   // nil when the listing has no text vector of the version
	Photos   []string // keys with a vector of the version
}
func NewVectors(db *pgxpool.Pool) Vectors
```

- [ ] **Step 1: Write the failing test**

`internal/catalog/repository/vector_pg_test.go`:

```go
package repository_test

import (
	"bytes"
	"context"
	"math"
	"slices"
	"testing"
	"time"

	"github.com/shopnexus/server2/internal/account/accounttest"
	"github.com/shopnexus/server2/internal/catalog/catalogtest"
	"github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/catalog/repository"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server2/internal/provider/embed/embedtest"
)

func TestVectorState(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	vs := repository.NewVectors(db)
	id := catalogtest.Listing(t, db, accounttest.New(t, db))
	now := time.Now()

	st, err := vs.State(ctx, id, "t1", "p1")
	if err != nil || st.TextHash != nil || len(st.Photos) != 0 {
		t.Fatalf("fresh listing: %+v %v", st, err)
	}
	hash := domain.TextHash("t1", "x")
	if err = vs.PutText(ctx, id, "t1", hash, embedtest.Axis(domain.TextDims, 0), now); err != nil {
		t.Fatal(err)
	}
	if err = vs.PutText(ctx, id, "t1", hash, embedtest.Axis(domain.TextDims, 1), now); err != nil {
		t.Fatalf("a second put replaces: %v", err)
	}
	for _, k := range []string{"media/a.jpg", "media/b.jpg"} {
		if err = vs.PutPhoto(ctx, id, k, "p1", embedtest.Axis(domain.PhotoDims, 0), now); err != nil {
			t.Fatal(err)
		}
	}
	if err = vs.PutPhoto(ctx, id, "media/c.jpg", "p0", embedtest.Axis(domain.PhotoDims, 0), now); err != nil {
		t.Fatal(err)
	}
	st, _ = vs.State(ctx, id, "t1", "p1")
	slices.Sort(st.Photos)
	if !bytes.Equal(st.TextHash, hash) || !slices.Equal(st.Photos, []string{"media/a.jpg", "media/b.jpg"}) {
		t.Fatalf("%+v: another version's photo counts as missing", st)
	}
	if st, _ = vs.State(ctx, id, "t2", "p1"); st.TextHash != nil {
		t.Fatal("another text version counts as missing")
	}
	if err = vs.DropPhotosExcept(ctx, id, []string{"media/b.jpg"}); err != nil {
		t.Fatal(err)
	}
	if st, _ = vs.State(ctx, id, "t1", "p1"); !slices.Equal(st.Photos, []string{"media/b.jpg"}) {
		t.Fatal(st.Photos)
	}
}

func TestVectorSource(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	vs := repository.NewVectors(db)
	id := catalogtest.Listing(t, db, accounttest.New(t, db))
	now := time.Now()
	if text, photo, err := vs.Source(ctx, id, "t1", "p1"); err != nil || text != nil || photo != nil {
		t.Fatalf("no vectors: %v %v %v", text, photo, err)
	}
	_ = vs.PutText(ctx, id, "t1", []byte{1}, embedtest.Axis(domain.TextDims, 2), now)
	_ = vs.PutPhoto(ctx, id, "media/a.jpg", "p1", embedtest.Axis(domain.PhotoDims, 0), now)
	_ = vs.PutPhoto(ctx, id, "media/b.jpg", "p1", embedtest.Axis(domain.PhotoDims, 1), now)
	text, photo, err := vs.Source(ctx, id, "t1", "p1")
	if err != nil || len(text) != domain.TextDims || text[2] != 1 || len(photo) != domain.PhotoDims {
		t.Fatalf("%v %v", len(text), err)
	}
	if math.Abs(float64(photo[0])-math.Sqrt2/2) > 0.01 || math.Abs(float64(photo[1])-math.Sqrt2/2) > 0.01 {
		t.Fatalf("the photo source is the normalized mean: %v %v", photo[0], photo[1])
	}
}

func TestEmbeddable(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	seller := accounttest.New(t, db)
	on := catalogtest.Listing(t, db, seller)
	gone := catalogtest.Listing(t, db, seller)
	ls := repository.NewListings(db)
	l, _ := ls.Get(ctx, gone)
	if err := l.Delete(time.Now()); err != nil {
		t.Fatal(err)
	}
	if err := ls.Save(ctx, &l, l.WriteID()); err != nil { // the same write ID as read is a normal write
		t.Fatal(err)
	}
	ids, err := repository.NewVectors(db).Embeddable(ctx)
	if err != nil || !slices.Contains(ids, on) || slices.Contains(ids, gone) {
		t.Fatalf("%v %v", ids, err)
	}
}
```

(If `Save` with the read write ID does not behave as a normal write in this repo, pass `uuid.NewV7()` as the new write ID, as other repository tests do.)

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/catalog/repository/ -run 'TestVector|TestEmbeddable'`
Expected: FAIL, `NewVectors` undefined.

- [ ] **Step 3: Add the interface**

In `repository.go`, after `Searches`:

```go
// Vectors persists the search vectors of listings: one text vector and one
// vector per processed photo, each under a model version.
type Vectors interface {
	// State is what listing has under the versions: its text hash, nil for
	// none, and the photo keys that have a vector.
	State(ctx context.Context, listing uuid.UUID, textVersion, photoVersion string) (VectorState, error)
	// PutText writes listing's text vector, replacing any.
	PutText(ctx context.Context, listing uuid.UUID, version string, hash []byte, v []float32, at time.Time) error
	// PutPhoto writes the vector of one processed photo, replacing any.
	PutPhoto(ctx context.Context, listing uuid.UUID, key, version string, v []float32, at time.Time) error
	// DropPhotosExcept deletes listing's photo vectors whose key is not in
	// keys, of any version.
	DropPhotosExcept(ctx context.Context, listing uuid.UUID, keys []string) error
	// Source reads a similar-listings search's query vectors: listing's text
	// vector and the normalized mean of its photo vectors; nil for what it
	// does not have.
	Source(ctx context.Context, listing uuid.UUID, textVersion, photoVersion string) (text, photo []float32, err error)
	// Embeddable lists the listings that should have vectors: every one not
	// deleted, processing or rejected.
	Embeddable(ctx context.Context) ([]uuid.UUID, error)
}

// VectorState is what vectors a listing has.
type VectorState struct {
	TextHash []byte
	Photos   []string
}
```

(add `"time"` to the imports).

- [ ] **Step 4: Implement**

`internal/catalog/repository/vector_pg.go`:

```go
package repository

import (
	"context"
	"errors"
	"fmt"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/platform/pgvec"
)

type pgVectors struct{ db *pgxpool.Pool }

func NewVectors(db *pgxpool.Pool) Vectors { return pgVectors{db} }

func (s pgVectors) State(ctx context.Context, listing uuid.UUID, textVersion, photoVersion string) (VectorState, error) {
	var st VectorState
	err := s.db.QueryRow(ctx, `SELECT text_hash FROM listing_text_vectors WHERE listing_id = @id AND model = @version`,
		pgx.StrictNamedArgs{"id": listing, "version": textVersion}).Scan(&st.TextHash)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return VectorState{}, fmt.Errorf("read text hash: %w", err)
	}
	rows, err := s.db.Query(ctx, `SELECT photo_key FROM listing_photo_vectors WHERE listing_id = @id AND model = @version`,
		pgx.StrictNamedArgs{"id": listing, "version": photoVersion})
	if err != nil {
		return VectorState{}, fmt.Errorf("read photo keys: %w", err)
	}
	if st.Photos, err = pgx.CollectRows(rows, pgx.RowTo[string]); err != nil {
		return VectorState{}, fmt.Errorf("read photo keys: %w", err)
	}
	return st, nil
}

func (s pgVectors) PutText(ctx context.Context, listing uuid.UUID, version string, hash []byte, v []float32, at time.Time) error {
	_, err := s.db.Exec(ctx, `INSERT INTO listing_text_vectors (listing_id, model, text_hash, embedding, embedded_at)
VALUES (@id, @version, @hash, @v::halfvec(1024), @at)
ON CONFLICT (listing_id) DO UPDATE SET model = excluded.model, text_hash = excluded.text_hash,
    embedding = excluded.embedding, embedded_at = excluded.embedded_at`,
		pgx.StrictNamedArgs{"id": listing, "version": version, "hash": hash, "v": pgvec.Format(v), "at": at})
	if err != nil {
		return fmt.Errorf("write text vector: %w", err)
	}
	return nil
}

func (s pgVectors) PutPhoto(ctx context.Context, listing uuid.UUID, key, version string, v []float32, at time.Time) error {
	_, err := s.db.Exec(ctx, `INSERT INTO listing_photo_vectors (listing_id, photo_key, model, embedding, embedded_at)
VALUES (@id, @key, @version, @v::halfvec(1152), @at)
ON CONFLICT (listing_id, photo_key) DO UPDATE SET model = excluded.model, embedding = excluded.embedding,
    embedded_at = excluded.embedded_at`,
		pgx.StrictNamedArgs{"id": listing, "key": key, "version": version, "v": pgvec.Format(v), "at": at})
	if err != nil {
		return fmt.Errorf("write photo vector: %w", err)
	}
	return nil
}

func (s pgVectors) DropPhotosExcept(ctx context.Context, listing uuid.UUID, keys []string) error {
	if keys == nil {
		keys = []string{}
	}
	_, err := s.db.Exec(ctx, `DELETE FROM listing_photo_vectors WHERE listing_id = @id AND NOT (photo_key = ANY(@keys))`,
		pgx.StrictNamedArgs{"id": listing, "keys": keys})
	if err != nil {
		return fmt.Errorf("drop photo vectors: %w", err)
	}
	return nil
}

func (s pgVectors) Source(ctx context.Context, listing uuid.UUID, textVersion, photoVersion string) (text, photo []float32, err error) {
	var t, p *string
	err = s.db.QueryRow(ctx, `SELECT
    (SELECT embedding::text FROM listing_text_vectors WHERE listing_id = @id AND model = @tv),
    (SELECT (l2_normalize(avg(embedding::vector)))::halfvec(1152)::text FROM listing_photo_vectors
     WHERE listing_id = @id AND model = @pv)`,
		pgx.StrictNamedArgs{"id": listing, "tv": textVersion, "pv": photoVersion}).Scan(&t, &p)
	if err != nil {
		return nil, nil, fmt.Errorf("read source vectors: %w", err)
	}
	if t != nil {
		if text, err = pgvec.Parse(*t); err != nil {
			return nil, nil, err
		}
	}
	if p != nil {
		if photo, err = pgvec.Parse(*p); err != nil {
			return nil, nil, err
		}
	}
	return text, photo, nil
}

func (s pgVectors) Embeddable(ctx context.Context) ([]uuid.UUID, error) {
	rows, err := s.db.Query(ctx, `SELECT id FROM listings WHERE NOT (status = ANY(@skip)) ORDER BY id`,
		pgx.StrictNamedArgs{"skip": []string{
			string(domain.StatusDeleted), string(domain.StatusProcessing), string(domain.StatusRejected),
		}})
	if err != nil {
		return nil, fmt.Errorf("list listings: %w", err)
	}
	ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return nil, fmt.Errorf("read listing IDs: %w", err)
	}
	return ids, nil
}
```

- [ ] **Step 5: Run the tests**

Run: `go test ./internal/catalog/repository/ -run 'TestVector|TestEmbeddable' -v`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/catalog/repository
git commit -m "feat(catalog): the listing vector store"
```

---

### Task 7: Media: query photos and reading processed photos

**Files:**
- Modify: `internal/media/domain/upload.go` (`ExpireAfter`, `ExpiresAt`, `ShapeQuery`)
- Modify: `internal/media/service/upload_create.go` (use `domain.ExpireAfter`)
- Modify: `internal/media/service/image.go` (`ShapeQuery` in `process`)
- Modify: `internal/media/service/service.go` (interface)
- Create: `internal/media/service/upload_query.go`, `internal/media/service/upload_query_test.go`

**Interfaces:**
- Produces on `mediasvc.Service`:

```go
	// QueryUpload checks that id is a photo owner uploaded to search with:
	// theirs, waiting, before its expiry and in the store as declared.
	// Anything else is domain.ErrInvalidUpload.
	QueryUpload(ctx context.Context, owner, id uuid.UUID) (QueryUpload, error)
	// QueryImage reads such an upload as a JPEG at most 768 px on its long
	// side, upright and without EXIF. Nothing is stored or published.
	QueryImage(ctx context.Context, owner, id uuid.UUID) ([]byte, error)
	// ReadPhoto reads a processed object under media/, such as a listing's
	// photo; an absent one is objectstore.ErrNotFound.
	ReadPhoto(ctx context.Context, key string) ([]byte, error)
```

and `type QueryUpload struct{ ExpiresAt time.Time }`.

- [ ] **Step 1: Write the failing test**

`internal/media/service/upload_query_test.go`:

```go
package service_test

import (
	"bytes"
	"context"
	"errors"
	"image/jpeg"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/account/accounttest"
	"github.com/shopnexus/server2/internal/media/domain"
	"github.com/shopnexus/server2/internal/media/mediatest"
	"github.com/shopnexus/server2/internal/media/repository"
	"github.com/shopnexus/server2/internal/media/service"
	"github.com/shopnexus/server2/internal/platform/objectstore"
	"github.com/shopnexus/server2/internal/platform/objectstore/objectstoretest"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server2/internal/platform/restatex/restatetest"
)

func TestQueryUpload(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	store := objectstoretest.New(t)
	in, p := restatetest.Ingress(t), restatetest.Prefix()
	m := mediatest.Service(db, store, in, p)
	restatetest.Start(t, m.Durable()...)
	ctx := context.Background()
	me, other := accounttest.New(t, db), accounttest.New(t, db)

	mine := mediatest.Upload(t, m, me, "image/jpeg", mediatest.JPEG(t, 2000, 1000))
	q, err := m.QueryUpload(ctx, me, mine)
	if err != nil || q.ExpiresAt.Before(time.Now().Add(23*time.Hour)) {
		t.Fatalf("%+v %v", q, err)
	}
	img, err := m.QueryImage(ctx, me, mine)
	if err != nil {
		t.Fatal(err)
	}
	cfg, err := jpeg.DecodeConfig(bytes.NewReader(img))
	if err != nil || cfg.Width != 768 || cfg.Height != 384 {
		t.Fatalf("%+v %v", cfg, err)
	}

	never, err := m.CreateUpload(ctx, me, "image/jpeg", 1000) // no PUT
	if err != nil {
		t.Fatal(err)
	}
	attached := mediatest.Upload(t, m, me, "image/jpeg", mediatest.JPEG(t, 64, 48))
	if err = m.Attach(ctx, me, uuid.NewV7(), []uuid.UUID{attached}); err != nil {
		t.Fatal(err)
	}
	later := service.New(service.Deps{
		Uploads: repository.NewUploads(db), Store: store, Ingress: in, Prefix: p,
		Now: func() time.Time { return time.Now().Add(domain.ExpireAfter + time.Minute) },
	})
	for name, call := range map[string]func() error{
		"someone else's": func() error { _, e := m.QueryUpload(ctx, other, mine); return e },
		"never put":      func() error { _, e := m.QueryUpload(ctx, me, never.UploadID); return e },
		"attached":       func() error { _, e := m.QueryUpload(ctx, me, attached); return e },
		"expired":        func() error { _, e := later.QueryUpload(ctx, me, mine); return e },
		"unknown":        func() error { _, e := m.QueryUpload(ctx, me, uuid.NewV7()); return e },
		"image of other": func() error { _, e := m.QueryImage(ctx, other, mine); return e },
	} {
		if err := call(); !errors.Is(err, domain.ErrInvalidUpload) {
			t.Errorf("%s: %v", name, err)
		}
	}
}

func TestReadPhoto(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	store := objectstoretest.New(t)
	in, p := restatetest.Ingress(t), restatetest.Prefix()
	m := mediatest.Service(db, store, in, p)
	restatetest.Start(t, m.Durable()...)
	ctx := context.Background()
	me := accounttest.New(t, db)
	id := mediatest.Upload(t, m, me, "image/jpeg", mediatest.JPEG(t, 64, 48))
	key, err := m.Square(ctx, me, uuid.NewV7(), id)
	if err != nil {
		t.Fatal(err)
	}
	b, err := m.ReadPhoto(ctx, key)
	if err != nil || !bytes.HasPrefix(b, []byte{0xFF, 0xD8, 0xFF}) {
		t.Fatalf("%d bytes %v", len(b), err)
	}
	if _, err = m.ReadPhoto(ctx, "media/none.jpg"); !errors.Is(err, objectstore.ErrNotFound) {
		t.Fatal(err)
	}
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/media/service/ -run 'TestQueryUpload|TestReadPhoto'`
Expected: FAIL, `QueryUpload` undefined.

- [ ] **Step 3: Domain**

In `internal/media/domain/upload.go`:

- Add `ShapeQuery Shape = "query"` to the `Shape` constants, with the comment `// ShapeQuery is a search's photo: at most 768 px on its long side, never stored.`
- Add:

```go
// ExpireAfter is how long an upload may wait for an attach.
const ExpireAfter = 24 * time.Hour

// ExpiresAt is when a waiting upload is deleted.
func (u *Upload) ExpiresAt() time.Time { return u.createdAt.Add(ExpireAfter) }

// Queryable reports whether owner may search with u now: it is theirs, still
// waiting and before its expiry.
func (u *Upload) Queryable(owner uuid.UUID, now time.Time) bool {
	return u.ownerID == owner && u.status == StatusWaiting && now.Before(u.ExpiresAt())
}
```

In `upload_create.go` delete the `expireAfter` constant and use `domain.ExpireAfter`.

- [ ] **Step 4: Processing shape**

In `image.go`, add `querySide = 768` to the constants, and in `process`, before the `small := ...` line:

```go
	if shape == domain.ShapeQuery {
		if photo, err = encodeJPEG(orient(shrink(img, querySide), orientation(raw, contentType))); err != nil {
			return nil, nil, err
		}
		return photo, nil, nil
	}
```

and extend the doc comment: `As domain.ShapeQuery it is at most querySide on its long side, with no thumbnail.`

- [ ] **Step 5: Use cases**

`internal/media/service/upload_query.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"io"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/media/domain"
	"github.com/shopnexus/server2/internal/media/repository"
	"github.com/shopnexus/server2/internal/platform/objectstore"
)

// QueryUpload is a photo a person searches with.
type QueryUpload struct {
	ExpiresAt time.Time
}

func (m *Media) QueryUpload(ctx context.Context, owner, id uuid.UUID) (QueryUpload, error) {
	u, err := m.uploads.Get(ctx, id)
	if errors.Is(err, repository.ErrNotFound) {
		return QueryUpload{}, domain.ErrInvalidUpload
	}
	if err != nil {
		return QueryUpload{}, fmt.Errorf("get upload: %w", err)
	}
	if !u.Queryable(owner, m.now()) {
		return QueryUpload{}, domain.ErrInvalidUpload
	}
	size, contentType, err := m.store.Stat(ctx, u.Key())
	if errors.Is(err, objectstore.ErrNotFound) {
		return QueryUpload{}, domain.ErrInvalidUpload
	}
	if err != nil {
		return QueryUpload{}, fmt.Errorf("stat upload: %w", err)
	}
	if size != u.Size() || contentType != u.ContentType() {
		return QueryUpload{}, domain.ErrInvalidUpload
	}
	return QueryUpload{ExpiresAt: u.ExpiresAt()}, nil
}

// QueryImage decodes in one of the process's slots, as MediaProcess does, so
// searches and listings together decode at most processSlots photos.
func (m *Media) QueryImage(ctx context.Context, owner, id uuid.UUID) ([]byte, error) {
	if _, err := m.QueryUpload(ctx, owner, id); err != nil {
		return nil, err
	}
	u, err := m.uploads.Get(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("get upload: %w", err)
	}
	r, err := m.store.Get(ctx, u.Key())
	if err != nil {
		return nil, fmt.Errorf("read upload: %w", err)
	}
	defer func() { _ = r.Close() }()
	select {
	case m.slots <- struct{}{}:
	case <-ctx.Done():
		return nil, ctx.Err()
	}
	defer func() { <-m.slots }()
	photo, _, err := process(r, u.ContentType(), domain.ShapeQuery)
	var refused refusedError
	if errors.As(err, &refused) {
		return nil, domain.ErrInvalidUpload
	}
	if err != nil {
		return nil, fmt.Errorf("shrink the photo: %w", err)
	}
	return photo, nil
}

func (m *Media) ReadPhoto(ctx context.Context, key string) ([]byte, error) {
	r, err := m.store.Get(ctx, key)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", key, err)
	}
	defer func() { _ = r.Close() }()
	b, err := io.ReadAll(io.LimitReader(r, domain.MaxSize))
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", key, err)
	}
	return b, nil
}
```

(Check `objectstore.Store.Get`: if it reports a missing key only on the first read rather than at `Get`, wrap the `io.ReadAll` error the same way so `errors.Is(err, objectstore.ErrNotFound)` holds; the test pins it.)

Add the three methods and `QueryUpload` to the `Service` interface in `service.go` with the doc comments from the Interfaces block.

- [ ] **Step 6: Run the tests**

Run: `go test ./internal/media/...`
Expected: PASS, the existing processing tests included.

- [ ] **Step 7: Commit**

```bash
git add internal/media
git commit -m "feat(media): read a waiting upload as a search photo"
```

---

### Task 8: `ListingEmbed`, the repo's first Virtual Object

**Files:**
- Create: `internal/catalog/service/listing_embed_durable.go`, `internal/catalog/service/listing_embed_test.go`
- Modify: `internal/catalog/service/service.go` (Deps, Catalog fields, Durable)
- Modify: `internal/catalog/service/listing_publish_durable.go`, `listing_edit_durable.go`, `listing_post_durable.go` (`startEmbed`)
- Modify: `internal/catalog/catalog.go` (Settings), `internal/catalog/catalogtest/catalogtest.go`
- Modify: `internal/app/app.go` (catalog settings)
- Create: `e2e/embed_stub_test.go`; Modify: `e2e/main_test.go`

**Interfaces:**
- Consumes: `repository.Vectors` (Task 6), `embed.Model`, `embedtest` (Task 4), `mediasvc.Service.ReadPhoto` (Task 7), `domain.EmbeddingText/TextHash/ProcessedPhotos` (Task 5).
- Produces:
  - Virtual Object `<prefix>ListingEmbed`, key = listing ID, exclusive handler `Refresh` with no input; exported `service.ListingEmbedName = "ListingEmbed"`.
  - `service.Deps` gains `Vectors repository.Vectors`, `Text, Image embed.Model`, `TextVersion, ImageVersion string`, `EmbedSlots int`, `Log *slog.Logger`.
  - `catalog.Settings{Text, Image embed.Model; TextVersion, ImageVersion string; EmbedSlots int}` and `catalog.Mount(d module.Deps, s Settings, accounts, media)`.

- [ ] **Step 1: Write the failing tests**

`internal/catalog/service/listing_embed_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"
	"github.com/restatedev/sdk-go/ingress"

	"github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/catalog/repository"
	"github.com/shopnexus/server2/internal/catalog/service"
	"github.com/shopnexus/server2/internal/media/mediatest"
	"github.com/shopnexus/server2/internal/provider/embed/embedtest"
	"github.com/shopnexus/server2/internal/platform/testenv"
)

// embedEnv is newEnv with counting embedding fakes.
func embedEnv(t *testing.T) (env, *embedtest.Model, *embedtest.Model) {
	t.Helper()
	text, image := embedtest.New(domain.TextDims), embedtest.New(domain.PhotoDims)
	e := newEnv(t, func(d *service.Deps) { d.Text, d.Image = text, image })
	return e, text, image
}

// vectors waits until listing has a text vector and want photo vectors.
func vectors(t *testing.T, e env, id uuid.UUID, want int) repository.VectorState {
	t.Helper()
	vs := repository.NewVectors(e.db)
	var st repository.VectorState
	testenv.Eventually(t, 20*time.Second, func() error {
		var err error
		if st, err = vs.State(context.Background(), id, "text-test", "image-test"); err != nil {
			return err
		}
		if st.TextHash == nil || len(st.Photos) != want {
			return fmt.Errorf("text %v, %d photos", st.TextHash != nil, len(st.Photos))
		}
		return nil
	})
	return st
}

func TestPublishEmbeds(t *testing.T) {
	t.Parallel()
	e, text, image := embedEnv(t)
	v := e.post(t, e.seller(t)) // post waits until the listing is active, as the other flow tests do
	vectors(t, e, v.ID, 1)
	if text.Calls() != 1 || image.Calls() != 1 {
		t.Fatalf("text %d, image %d", text.Calls(), image.Calls())
	}
}

func TestTextEditEmbedsNoPhoto(t *testing.T) {
	t.Parallel()
	e, text, image := embedEnv(t)
	seller := e.seller(t)
	v := e.post(t, seller)
	vectors(t, e, v.ID, 1)
	d := draft(v.Photos[0].UploadID) // the same photo; name the field as ListingView has it
	d.Description = "Máy zin, mới thay pin"
	if _, err := e.catalog.Edit(context.Background(), seller, v.ID, uuid.NewV7().String(), d); err != nil {
		t.Fatal(err)
	}
	testenv.Eventually(t, 20*time.Second, func() error {
		if text.Calls() != 2 {
			return fmt.Errorf("text %d", text.Calls())
		}
		return nil
	})
	if image.Calls() != 1 {
		t.Fatalf("a text edit embedded a photo again: %d", image.Calls())
	}
}

func TestBurstOfEditsEmbedsEachPhotoOnce(t *testing.T) {
	t.Parallel()
	e, _, image := embedEnv(t)
	seller := e.seller(t)
	v := e.post(t, seller)
	for i := range 5 {
		d := draft(v.Photos[0].UploadID)
		d.Description = fmt.Sprintf("lần %d", i)
		if _, err := e.catalog.Edit(context.Background(), seller, v.ID, uuid.NewV7().String(), d); err != nil {
			t.Fatal(err)
		}
	}
	vectors(t, e, v.ID, 1)
	time.Sleep(2 * time.Second) // let the queued runs drain; each finds nothing to do
	if image.Calls() != 1 {
		t.Fatalf("image %d", image.Calls())
	}
}

func TestReplacedPhotoLosesItsVector(t *testing.T) {
	t.Parallel()
	e, _, _ := embedEnv(t)
	seller := e.seller(t)
	v := e.post(t, seller)
	before := vectors(t, e, v.ID, 1)
	fresh := e.upload(t, seller, mediatest.JPEG(t, 80, 60))
	if _, err := e.catalog.Edit(context.Background(), seller, v.ID, uuid.NewV7().String(), draft(fresh)); err != nil {
		t.Fatal(err)
	}
	testenv.Eventually(t, 20*time.Second, func() error {
		st, err := repository.NewVectors(e.db).State(context.Background(), v.ID, "text-test", "image-test")
		if err != nil {
			return err
		}
		if len(st.Photos) != 1 || st.Photos[0] == before.Photos[0] {
			return fmt.Errorf("%v", st.Photos)
		}
		return nil
	})
}

func TestEmbedRetriesUntilTheModelAnswers(t *testing.T) {
	t.Parallel()
	e, _, image := embedEnv(t)
	image.SetFail(errors.New("503"))
	v := e.post(t, e.seller(t))
	testenv.Eventually(t, 20*time.Second, func() error {
		if image.Calls() < 2 {
			return fmt.Errorf("%d calls", image.Calls())
		}
		return nil
	})
	image.SetFail(nil)
	vectors(t, e, v.ID, 1)
}

func TestRefreshReembedsAnotherVersion(t *testing.T) {
	t.Parallel()
	e, _, image := embedEnv(t)
	v := e.post(t, e.seller(t))
	st := vectors(t, e, v.ID, 1)
	if _, err := e.db.Exec(context.Background(), `UPDATE listing_photo_vectors SET model = 'old' WHERE listing_id = @id`,
		map[string]any{"id": v.ID}); err != nil {
		t.Fatal(err)
	}
	if _, err := ingress.ObjectSend[restate.Void](e.ingress, e.prefix+service.ListingEmbedName, v.ID.String(), "Refresh").
		Send(context.Background(), restate.Void{}); err != nil {
		t.Fatal(err)
	}
	vectors(t, e, v.ID, len(st.Photos))
	if image.Calls() != 2 {
		t.Fatalf("image %d", image.Calls())
	}
}
```

`newEnv` must keep the ingress client and prefix: add `ingress *ingress.Client` and `prefix string` fields to `env` in `helpers_test.go` and set them. The `UPDATE` uses `pgx.StrictNamedArgs{"id": v.ID}`, not a plain map.

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/catalog/service/ -run 'Embed|Reembed|LosesItsVector'`
Expected: FAIL to compile: `d.Text` undefined.

- [ ] **Step 3: Service wiring**

In `service.go`:

- `Deps` gains:

```go
	Vectors repository.Vectors
	// Text and Image embed with the index key; TextVersion and ImageVersion
	// name the models behind them and go into every vector row.
	Text, Image               embed.Model
	TextVersion, ImageVersion string
	// EmbedSlots is how many embeddings ListingEmbed runs at once in this
	// process.
	EmbedSlots int
	Log        *slog.Logger
```

- `Catalog` gains the same fields unexported plus `embedSlots chan struct{}`; `New` sets `embedSlots: make(chan struct{}, d.EmbedSlots)`.
- `Durable()` appends:

```go
		restate.Reflect(ListingEmbed{
			Prefix: c.prefix, Listings: c.listings, Categories: c.categories, Vectors: c.vectors, Media: c.media,
			Text: c.text, Image: c.image, TextVersion: c.textVersion, ImageVersion: c.imageVersion,
			Slots: c.embedSlots, Log: c.log, Now: c.now,
		}),
```

- [ ] **Step 4: The Virtual Object**

`internal/catalog/service/listing_embed_durable.go`:

```go
package service

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"

	"github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/catalog/repository"
	mediasvc "github.com/shopnexus/server2/internal/media/service"
	"github.com/shopnexus/server2/internal/platform/objectstore"
	"github.com/shopnexus/server2/internal/platform/restatex"
	"github.com/shopnexus/server2/internal/provider/embed"
)

// ListingEmbedName is the ListingEmbed object's name without the prefix;
// cmd/search-reindex sends to it.
const ListingEmbedName = "ListingEmbed"

// ListingEmbed keeps one listing's search vectors in line with its content.
// It is a Virtual Object keyed by the listing ID: Restate runs one Refresh
// per listing at a time, so a burst of edits queues, the first run embeds
// the newest content and the others find nothing to do.
type ListingEmbed struct {
	Prefix                    string
	Listings                  repository.Listings
	Categories                repository.Categories
	Vectors                   repository.Vectors
	Media                     mediasvc.Service
	Text, Image               embed.Model
	TextVersion, ImageVersion string
	Slots                     chan struct{}
	Log                       *slog.Logger
	Now                       func() time.Time
}

func (s ListingEmbed) ServiceName() string { return s.Prefix + ListingEmbedName }

// embedPlan is what the load step found: the text to embed when its hash
// moved, the processed photos without a vector, and every photo key, to
// drop the vectors of photos the listing no longer has.
type embedPlan struct {
	Found    bool     `json:"found"`
	Text     string   `json:"text,omitempty"`
	TextHash []byte   `json:"text_hash,omitempty"`
	Missing  []string `json:"missing,omitempty"`
	Keys     []string `json:"keys,omitempty"`
}

// Refresh reads the listing as it is now and brings its vectors in line, a
// step for the text and one for each photo, so a retry goes on from the
// photo it reached. A listing that is gone, deleted, processing or rejected
// has nothing to embed: processing ends in ListingPublish, which sends a
// Refresh of its own, and a deleted listing keeps its row and the vectors
// it had, which search's status filter leaves out.
func (s ListingEmbed) Refresh(ctx restate.ObjectContext) error {
	id, err := uuid.Parse(restate.Key(ctx))
	if err != nil {
		return restate.TerminalError(fmt.Errorf("listing key %q: %w", restate.Key(ctx), err))
	}
	at, err := restatex.Now(ctx, s.Now)
	if err != nil {
		return err
	}
	p, err := restate.Run(ctx, func(rc restate.RunContext) (embedPlan, error) {
		l, stepErr := s.Listings.Get(rc, id)
		if errors.Is(stepErr, repository.ErrNotFound) {
			return embedPlan{}, nil
		}
		if stepErr != nil {
			return embedPlan{}, fmt.Errorf("get listing: %w", stepErr)
		}
		switch l.Status() { //nolint:exhaustive // the other statuses are embedded
		case domain.StatusDeleted, domain.StatusProcessing, domain.StatusRejected:
			return embedPlan{}, nil
		}
		tree, stepErr := s.Categories.Tree(rc)
		if stepErr != nil {
			return embedPlan{}, fmt.Errorf("read categories: %w", stepErr)
		}
		name := l.CategoryCode()
		for _, c := range tree {
			if c.Code == l.CategoryCode() {
				name = c.DisplayName
			}
		}
		have, stepErr := s.Vectors.State(rc, id, s.TextVersion, s.ImageVersion)
		if stepErr != nil {
			return embedPlan{}, fmt.Errorf("read vector state: %w", stepErr)
		}
		plan := embedPlan{Found: true, Keys: l.ProcessedPhotos()}
		text := l.EmbeddingText(name)
		if hash := domain.TextHash(s.TextVersion, text); !bytes.Equal(hash, have.TextHash) {
			plan.Text, plan.TextHash = text, hash
		}
		for _, k := range plan.Keys {
			if !slices.Contains(have.Photos, k) {
				plan.Missing = append(plan.Missing, k)
			}
		}
		return plan, nil
	})
	if err != nil {
		return fmt.Errorf("plan the embedding: %w", err)
	}
	if !p.Found {
		return nil
	}
	if p.TextHash != nil {
		if err = restate.RunVoid(ctx, func(rc restate.RunContext) error {
			release, slotErr := s.slot(rc)
			if slotErr != nil {
				return slotErr
			}
			defer release()
			vs, embedErr := s.Text.Embed(rc, []string{p.Text})
			if errors.Is(embedErr, embed.ErrRefused) {
				s.Log.WarnContext(rc, "the text model refused a listing", "listing", id, "err", embedErr)
				return nil
			}
			if embedErr != nil {
				return fmt.Errorf("embed text: %w", embedErr)
			}
			return s.Vectors.PutText(rc, id, s.TextVersion, p.TextHash, vs[0], at)
		}); err != nil {
			return fmt.Errorf("text vector: %w", err)
		}
	}
	for _, key := range p.Missing {
		if err = restate.RunVoid(ctx, func(rc restate.RunContext) error {
			photo, readErr := s.Media.ReadPhoto(rc, key)
			if errors.Is(readErr, objectstore.ErrNotFound) {
				return nil // the photo went with an edit; the drop step clears it
			}
			if readErr != nil {
				return fmt.Errorf("read photo: %w", readErr)
			}
			release, slotErr := s.slot(rc)
			if slotErr != nil {
				return slotErr
			}
			defer release()
			vs, embedErr := s.Image.Embed(rc, []string{embed.ImageInput(photo)})
			if errors.Is(embedErr, embed.ErrRefused) {
				s.Log.WarnContext(rc, "the image model refused a photo", "listing", id, "photo", key, "err", embedErr)
				return nil
			}
			if embedErr != nil {
				return fmt.Errorf("embed photo: %w", embedErr)
			}
			return s.Vectors.PutPhoto(rc, id, key, s.ImageVersion, vs[0], at)
		}); err != nil {
			return fmt.Errorf("photo vector %s: %w", key, err)
		}
	}
	if err = restate.RunVoid(ctx, func(rc restate.RunContext) error {
		return s.Vectors.DropPhotosExcept(rc, id, p.Keys)
	}); err != nil {
		return fmt.Errorf("drop removed photos: %w", err)
	}
	return nil
}

// slot waits for one of the process's embedding slots; both embed steps
// call it.
func (s ListingEmbed) slot(ctx context.Context) (release func(), err error) {
	select {
	case s.Slots <- struct{}{}:
		return func() { <-s.Slots }, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}
```

- [ ] **Step 5: The sends**

In `listing_post_durable.go`, next to `startPublish`:

```go
// startEmbed asks ListingEmbed to bring the listing's vectors in line. A send
// to an object queues behind the listing's run in progress.
func startEmbed(ctx restate.Context, prefix string, id uuid.UUID) {
	restate.ObjectSend(ctx, prefix+ListingEmbedName, id.String(), "Refresh").Send(restate.Void{})
}
```

In `listing_publish_durable.go`, at the end of `Run`, after the save step and before `return nil`:

```go
	if len(reasons) == 0 {
		startEmbed(ctx, s.Prefix, id)
	}
```

In `listing_edit_durable.go`, replace the last `if`:

```go
	if l.Status() == domain.StatusProcessing {
		startPublish(ctx, s.Prefix, in.ID, w)
	} else {
		startEmbed(ctx, s.Prefix, in.ID)
	}
```

- [ ] **Step 6: Mount, test support, app**

`internal/catalog/catalog.go`:

```go
// Settings is what catalog's Mount takes beyond module.Deps: the embedding
// models ListingEmbed calls with the index key.
type Settings struct {
	Text, Image               embed.Model
	TextVersion, ImageVersion string
	EmbedSlots                int
}

func Mount(d module.Deps, s Settings, accounts accountsvc.Service, media mediasvc.Service) module.Mounted[service.Service] {
	svc := service.New(service.Deps{
		Listings: repository.NewListings(d.Pool), Categories: repository.NewCategories(d.Pool),
		Regions: repository.NewRegions(d.Pool), Searches: repository.NewSearches(d.Pool), Vectors: repository.NewVectors(d.Pool),
		Accounts: accounts, Media: media, Text: s.Text, Image: s.Image, TextVersion: s.TextVersion, ImageVersion: s.ImageVersion,
		EmbedSlots: s.EmbedSlots, Log: d.Log, Ingress: d.Ingress, Prefix: d.ServicePrefix, Now: d.Now,
	})
	...
```

`catalogtest.Service` sets `Vectors: repository.NewVectors(db), Text: embedtest.New(domain.TextDims), Image: embedtest.New(domain.PhotoDims), TextVersion: "text-test", ImageVersion: "image-test", EmbedSlots: 2, Log: slog.New(slog.DiscardHandler)` before the `change` loop.

`internal/app/app.go`, replace `catalogm := catalog.Mount(d, accounts, mediam.Service)` with:

```go
	embedder := func(base, model, key string, dims int) embed.OpenAI {
		return embed.OpenAI{BaseURL: base, APIKey: key, Model: model, Dims: dims, HTTP: &http.Client{Timeout: cfg.Embed.Timeout}}
	}
	catalogm := catalog.Mount(d, catalog.Settings{
		Text:        embedder(cfg.Embed.TextBaseURL, cfg.Embed.TextModel, cfg.Embed.IndexAPIKey, catalogdomain.TextDims),
		Image:       embedder(cfg.Embed.ImageBaseURL, cfg.Embed.ImageModel, cfg.Embed.IndexAPIKey, catalogdomain.PhotoDims),
		TextVersion: cfg.Embed.TextVersion, ImageVersion: cfg.Embed.ImageVersion, EmbedSlots: cfg.Embed.Slots,
	}, accounts, mediam.Service)
```

(`embedder` is used again in Task 12, so it stays a local helper.)

`e2e/embed_stub_test.go`, an `httptest` server answering `POST /v1/embeddings` with each input's vector from `embedtest`'s hashing, at the dimension the `model` field names. It answers 503 for a photo that is magenta in its middle, so one test sees `search_unavailable` without turning the alias off for the tests running beside it:

```go
package e2e

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/color"
	"image/jpeg"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	catalogdomain "github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/provider/embed/embedtest"
)

// stubEmbed stands in for the embedding aliases: embed-text answers 1024
// dimensions, embed-image 1152, each input its embedtest vector. Hashed
// vectors are close to orthogonal, so below the e2e floors of 0.5: vector
// lists stay empty unless a test sets a vector, and BM25 answers.
type stubEmbed struct {
	srv         *httptest.Server
	text, image *embedtest.Model
}

func newEmbed() *stubEmbed {
	e := &stubEmbed{text: embedtest.New(catalogdomain.TextDims), image: embedtest.New(catalogdomain.PhotoDims)}
	e.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Model string   `json:"model"`
			Input []string `json:"input"`
		}
		if r.URL.Path != "/v1/embeddings" || json.NewDecoder(r.Body).Decode(&req) != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		m := e.text
		if req.Model == "embed-image" {
			m = e.image
			for _, in := range req.Input {
				if unavailable(in) {
					http.Error(w, "the stub is down for this photo", http.StatusServiceUnavailable)
					return
				}
			}
		}
		vs, _ := m.Embed(context.Background(), req.Input)
		data := make([]map[string]any, len(vs))
		for i, v := range vs {
			data[i] = map[string]any{"object": "embedding", "index": i, "embedding": v}
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{"object": "list", "data": data})
	}))
	return e
}

func (e *stubEmbed) url() string { return e.srv.URL + "/v1" }

// unavailable reports a data-URL JPEG whose middle pixel is magenta, the
// photo magentaPhoto makes.
func unavailable(input string) bool {
	b64, ok := strings.CutPrefix(input, "data:image/jpeg;base64,")
	if !ok {
		return false
	}
	raw, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return false
	}
	img, err := jpeg.Decode(bytes.NewReader(raw))
	if err != nil {
		return false
	}
	b := img.Bounds()
	r, g, bl, _ := img.At(b.Min.X+b.Dx()/2, b.Min.Y+b.Dy()/2).RGBA()
	return r>>8 > 200 && g>>8 < 60 && bl>>8 > 200
}

// magentaPhoto is a JPEG the stub's image alias answers 503 for.
func magentaPhoto(t *testing.T) []byte {
	t.Helper()
	m := image.NewRGBA(image.Rect(0, 0, 64, 64))
	for y := range 64 {
		for x := range 64 {
			m.Set(x, y, color.RGBA{255, 0, 255, 255})
		}
	}
	var b bytes.Buffer
	if err := jpeg.Encode(&b, m, nil); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}
```

In `e2e/main_test.go`, add to the `var` block beside `model`:

```go
	embedder   = newEmbed()         // the embedding aliases, embed-text and embed-image
```

and set `TextBaseURL: embedder.url(), ImageBaseURL: embedder.url()` in the `Embed` config (the stub, like `model`'s, lives as long as the test binary).

- [ ] **Step 7: Run the tests**

Run: `go test ./internal/catalog/... ./internal/app/... && go test ./e2e/ -run 'Catalog|Listing' -count=1`
Expected: PASS. The Restate admin shows `<prefix>ListingEmbed` as a virtual object.

- [ ] **Step 8: Commit**

```bash
git add internal/catalog internal/app e2e
git commit -m "feat(catalog): ListingEmbed keeps a listing's vectors in line"
```

---

### Task 13: `cmd/search-reindex`

**Files:**
- Create: `cmd/search-reindex/main.go`

**Interfaces:**
- Consumes: `repository.Vectors.Embeddable` (Task 6), `service.ListingEmbedName` (Task 8).

- [ ] **Step 1: Write the command**

```go
// Command search-reindex asks ListingEmbed to refresh every listing that
// should have vectors: the backfill of listings posted before search had
// vectors, and the way to move every listing to a new EMBED_*_VERSION. Each
// send queues behind a listing's run in progress, and a listing already in
// line finds nothing to do, so running it twice is harmless.
package main

import (
	"context"
	"fmt"
	"os"

	restate "github.com/restatedev/sdk-go"
	"github.com/restatedev/sdk-go/ingress"

	"github.com/shopnexus/server2/internal/catalog/repository"
	"github.com/shopnexus/server2/internal/catalog/service"
	"github.com/shopnexus/server2/internal/platform/config"
	"github.com/shopnexus/server2/internal/platform/postgres"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.FromDotEnv(".env")
	if err != nil {
		return err
	}
	ctx := context.Background()
	pool, err := postgres.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("connect to postgres: %w", err)
	}
	defer pool.Close()
	ids, err := repository.NewVectors(pool).Embeddable(ctx)
	if err != nil {
		return err
	}
	client := ingress.NewClient(cfg.Restate.IngressURL)
	name := cfg.Restate.ServicePrefix + service.ListingEmbedName
	for i, id := range ids {
		if _, err = ingress.ObjectSend[restate.Void](client, name, id.String(), "Refresh").Send(ctx, restate.Void{}); err != nil {
			return fmt.Errorf("send %s after %d of %d: %w", id, i, len(ids), err)
		}
	}
	fmt.Printf("sent %d listings to %s\n", len(ids), name)
	return nil
}
```

(Check `ingress.ObjectSend`'s `Send` signature in the module cache, `send_requester.go`; it takes the context first.)

- [ ] **Step 2: Try it on the dev stack**

Run: `make run` in one terminal; in another, `go run ./cmd/search-reindex`.
Expected: `sent N listings to ListingEmbed`. With the models down, the Restate UI shows the invocations retrying; `docker compose --profile models up -d tei ai` starts them, and the invocations finish once both answer.

- [ ] **Step 3: Commit**

```bash
git add cmd/search-reindex
git commit -m "feat: search-reindex sends every listing to ListingEmbed"
```


## Self-Review

**Spec coverage.** API (Task 1, 12), migration (3), versions in `model` (6, 8), `ListingEmbed` steps, slots, sends, reindex (8, 13), understanding fields and prompt version (10), query photo path and cache (7, 11, 12), retrieval lists, boost list, weights, floors, sorts, single statement (9), degradation (12), configuration (2), testing as the spec lists (4, 6–12), eval (15), ARCHITECTURE (14). The embedder service itself, TEI, aliases and keys are plans 1 and 2.

**Placeholder scan.** None left in this part; the e2e tests (Task 12) and the eval harness (Task 15) are written out in the query part.

**Type consistency.** `embed.Model.Embed(ctx, []string) ([][]float32, error)` throughout; `repository.Vectors` methods as Task 6 defines them; `ListingEmbedName` in Tasks 8 and 13; `domain.Weights`/`Vectors` field names in Tasks 5, 9 and 12; versions `"text-test"` and `"image-test"` in every test.

**Review Focus.** Each line has its test: 1 in Tasks 7 and 12 (`TestQueryUpload`, `TestSearchByPhotoRefuses`), 2 in `TestSearchLike`, 3 in `TestHybridPagesWithoutGapsOrRepeats`, 4 in `TestHybridFiltersEveryList`, 5 in `TestEmbedRefusesBadReplies`.
