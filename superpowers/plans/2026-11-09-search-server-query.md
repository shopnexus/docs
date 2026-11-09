# Search by photo, similar listings and hybrid text search: server, query Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `GET /v1/search` gains `photo=<upload_id>` and `like=<listing_id>`, and `q` fuses BM25 with BGE-M3 text vectors and SigLIP 2 photo vectors by weighted RRF; listings get their vectors from a Restate Virtual Object.

**Architecture:** Catalog owns listing vectors (`listing_text_vectors`, `listing_photo_vectors`, pgvector `halfvec` with HNSW) beside its ParadeDB index, keeps them in line through the Virtual Object `ListingEmbed` that `ListingPublish` and `ListingEdit` send to, and runs one hybrid SQL statement (CTEs `bm25`, `txt`, `img`, `boost`, then `fused`). Discovery owns the query side: the understanding gains `rewritten` and `visual`, query vectors and query-photo vectors are cached in Postgres, and media reads the caller's waiting upload into a small JPEG. The server calls the LiteLLM aliases `embed-text` and `embed-image` through `internal/provider/embed`, an OpenAI-style `POST /embeddings` client.

**Tech Stack:** Go (repo's version), pgx v5 with `pgx.StrictNamedArgs`, ParadeDB 0.26.3 (pg_search + pgvector 0.8.x), Restate Go SDK v1.1.0, kin-openapi spec middleware, the test stack of `docker-compose.test.yml`.

**Part 2 of 2.** Runs after `2026-11-09-search-server-index.md` (tasks 2–8 and 13: config, migration, `pgvec`, `embed`, catalog domain and vector store, media, `ListingEmbed`, `search-reindex`); the names those tasks produce are listed in their Interfaces blocks there.

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

### Task 1: The OpenAPI contract

**Files:**
- Modify: `api/parameters/discovery.yaml`
- Modify: `api/paths/discovery.yaml` (the `search` operation)

**Interfaces:**
- Produces: query parameters `photo` (uuid) and `like` (uuid) on `GET /v1/search`; documented errors `search_conflict` (400), `unauthenticated` (401), `listing_not_found` (404), `invalid_upload` (422), `search_unavailable` (503).

- [ ] **Step 1: Add the parameters**

Append to `api/parameters/discovery.yaml`:

```yaml
SearchPhoto:
  name: photo
  in: query
  description: |
    An upload of the caller's from POST /v1/uploads, still waiting (attached to
    nothing): search by this photo alone. Needs a signed-in caller; goes without
    q and like. The photo is never published and goes when the upload expires.
  schema:
    type: string
    format: uuid
SearchLike:
  name: like
  in: query
  description: |
    A listing on sale or reserved: listings similar to it, leaving out that
    listing and the caller's own. Goes with q and the filters, not with photo.
  schema:
    type: string
    format: uuid
```

- [ ] **Step 2: Wire them into the operation and document the errors**

In `api/paths/discovery.yaml`, `search.get`:

- Replace the description with:

```yaml
    description: |
      Three ways to search, all under the person's filters and sorts. With q a
      model reads the query; BM25 on its words, its Vietnamese rewrite against
      listing text vectors and its English description against listing photos
      are fused by weighted RRF. With photo, the photo against listing photos
      alone. With like, the listing's title, text vector and photos. Without
      any, the call browses, newest first by default, and category alone is the
      category page. A model that fails leaves the lists it feeds out; q then
      searches its raw words, with no understood and no chips.
```

- Add to `parameters`, after `- $ref: "../parameters/discovery.yaml#/NearCommune"`:

```yaml
      - $ref: "../parameters/discovery.yaml#/SearchPhoto"
      - $ref: "../parameters/discovery.yaml#/SearchLike"
```

- Change the `sort` description to `relevance by default with q, photo or like, newest without; other sorts order the listings the search found; nearest needs a position and bounds itself to 50 km without radius_km.`
- Replace the `responses` with:

```yaml
    responses:
      "200":
        description: One page of listings.
        content:
          application/json:
            schema:
              $ref: "../schemas/discovery.yaml#/SearchView"
      "400":
        description: "A malformed parameter, position_required, invalid_position, invalid_cursor, invalid_price_range, or search_conflict: photo with q or like."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "listing_not_found: like names a listing that is not on sale or reserved."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: "invalid_upload: photo is not a waiting upload of the caller's, or not a readable image."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "503":
        description: "search_unavailable: the photo could not be embedded; try again."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

- [ ] **Step 3: Check the spec loads**

Run: `go test ./api/...`
Expected: PASS (`TestSpecValid` resolves every `$ref`).

- [ ] **Step 4: Commit**

```bash
git add api/parameters/discovery.yaml api/paths/discovery.yaml
git commit -m "feat(api): search by photo and similar listings"
```

---

### Task 9: The hybrid search query

**Files:**
- Modify: `internal/catalog/repository/search_pg.go`
- Create: `internal/catalog/repository/hybrid_pg_test.go`
- Modify: `internal/catalog/service/search.go` (resolve `Like`, set versions)

**Interfaces:**
- Consumes: `domain.Search.Vectors/Weights/Like/ExcludeSeller` (Task 5), vector tables (Task 3).
- Produces: `Searches.Search` and `Searches.Counts` run the hybrid query when `s.Hybrid()`; `Catalog.Search` fills `s.Vectors.Text/Photo` from `Like` and the versions from its settings.

- [ ] **Step 1: Write the failing tests**

`internal/catalog/repository/hybrid_pg_test.go`:

```go
package repository_test

import (
	"context"
	"slices"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/shopnexus/server2/internal/account/accounttest"
	"github.com/shopnexus/server2/internal/catalog/catalogtest"
	"github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/catalog/repository"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server2/internal/provider/embed/embedtest"
)

// put lists a listing at price with a text vector and one photo vector.
func put(t *testing.T, db *pgxpool.Pool, seller uuid.UUID, title string, price int64, text, photo []float32) uuid.UUID {
	t.Helper()
	id := catalogtest.Listing(t, db, seller, func(d *domain.Draft, _ *domain.Refs) { d.Title, d.Price = title, price })
	vs := repository.NewVectors(db)
	if text != nil {
		if err := vs.PutText(context.Background(), id, "t", []byte{1}, text, time.Now()); err != nil {
			t.Fatal(err)
		}
	}
	if photo != nil {
		if err := vs.PutPhoto(context.Background(), id, "media/a.jpg", "p", photo, time.Now()); err != nil {
			t.Fatal(err)
		}
	}
	return id
}

func ids(hits []domain.Hit) []uuid.UUID {
	out := make([]uuid.UUID, len(hits))
	for i, h := range hits {
		out[i] = h.ID
	}
	return out
}

func vecs(text, photo []float32) domain.Vectors {
	return domain.Vectors{Text: text, Photo: photo, TextVersion: "t", PhotoVersion: "p", TextMin: 0.5, PhotoMin: 0.5}
}

func TestHybridFusesAndFloors(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	s := accounttest.New(t, db)
	const td, pd = domain.TextDims, domain.PhotoDims
	exact := put(t, db, s, "Xe đạp Asama", 1_500_000, embedtest.Axis(td, 0), embedtest.Axis(pd, 0))
	close := put(t, db, s, "Xe cho bé", 1_200_000, embedtest.Near(td, 0, 1, 0.8), nil)
	far := put(t, db, s, "Nồi cơm", 500_000, embedtest.Axis(td, 1), embedtest.Axis(pd, 1))
	words := put(t, db, s, "Xe đạp cũ", 900_000, nil, nil)

	hits, err := repository.NewSearches(db).Search(ctx, domain.Search{
		Phrases: []domain.Phrase{{Text: "xe đạp", Weight: 1}},
		Vectors: vecs(embedtest.Axis(td, 0), embedtest.Axis(pd, 0)),
		Weights: domain.Weights{BM25: 1, Text: 1, Photo: 0.5}, Sort: domain.SortRelevance, Limit: 10,
	})
	got := ids(hits)
	if err != nil || len(got) != 3 || got[0] != exact || slices.Contains(got, far) ||
		!slices.Contains(got, close) || !slices.Contains(got, words) {
		t.Fatalf("%v %v (exact %v close %v words %v far %v)", got, err, exact, close, words, far)
	}

	hits, _ = repository.NewSearches(db).Search(ctx, domain.Search{
		Phrases: []domain.Phrase{{Text: "xe đạp", Weight: 1}},
		Vectors: vecs(embedtest.Axis(td, 0), nil),
		Weights: domain.Weights{BM25: 1, Text: 1}, Sort: domain.SortPriceAsc, Limit: 10,
	})
	if got = ids(hits); !slices.Equal(got, []uuid.UUID{words, close, exact}) {
		t.Fatalf("price sort orders the candidates only: %v", got)
	}
}

func TestHybridFiltersEveryList(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	s := accounttest.New(t, db)
	const pd = domain.PhotoDims
	cheap := put(t, db, s, "Ghế", 200_000, nil, embedtest.Axis(pd, 0))
	pricey := put(t, db, s, "Ghế gỗ", 5_000_000, nil, embedtest.Near(pd, 0, 1, 0.9))
	hidden := put(t, db, s, "Ghế nhựa", 300_000, nil, embedtest.Axis(pd, 0))
	ls := repository.NewListings(db)
	l, _ := ls.Get(ctx, hidden)
	if err := l.Hide(time.Now()); err != nil {
		t.Fatal(err)
	}
	if err := ls.Save(ctx, &l, uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	hits, err := repository.NewSearches(db).Search(ctx, domain.Search{
		Filters: domain.Filters{PriceMax: 1_000_000},
		Vectors: vecs(nil, embedtest.Axis(pd, 0)), Weights: domain.Weights{Photo: 1}, Sort: domain.SortRelevance, Limit: 10,
	})
	if got := ids(hits); err != nil || !slices.Equal(got, []uuid.UUID{cheap}) {
		t.Fatalf("%v %v (pricey %v hidden %v)", got, err, pricey, hidden)
	}
}

func TestHybridLikeLeavesOutSourceAndSeller(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	me, other := accounttest.New(t, db), accounttest.New(t, db)
	const td = domain.TextDims
	source := put(t, db, other, "Xe đạp Asama", 1_500_000, embedtest.Axis(td, 0), nil)
	mine := put(t, db, me, "Xe đạp Asama 2", 1_500_000, embedtest.Axis(td, 0), nil)
	theirs := put(t, db, other, "Xe đạp Asama 3", 1_400_000, embedtest.Axis(td, 0), nil)
	hits, err := repository.NewSearches(db).Search(ctx, domain.Search{
		Phrases: []domain.Phrase{{Text: "Xe đạp Asama", Weight: 1}},
		Vectors: vecs(embedtest.Axis(td, 0), nil), Like: source, ExcludeSeller: me,
		Weights: domain.Weights{BM25: 0.5, Text: 1}, Sort: domain.SortRelevance, Limit: 10,
	})
	if got := ids(hits); err != nil || !slices.Equal(got, []uuid.UUID{theirs}) {
		t.Fatalf("%v %v (source %v mine %v)", got, err, source, mine)
	}
}

func TestHybridPagesWithoutGapsOrRepeats(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	s := accounttest.New(t, db)
	const pd = domain.PhotoDims
	var all []uuid.UUID
	for i := range 7 {
		all = append(all, put(t, db, s, "Ghế", 100_000, nil, embedtest.Near(pd, 0, 1, 0.95-float64(i%3)*0.1)))
	}
	for _, sort := range []domain.SortOrder{domain.SortRelevance, domain.SortNewest, domain.SortPriceAsc} {
		var seen []uuid.UUID
		for offset := 0; offset < 9; offset += 3 {
			hits, err := repository.NewSearches(db).Search(ctx, domain.Search{
				Vectors: vecs(nil, embedtest.Axis(pd, 0)), Weights: domain.Weights{Photo: 1}, Sort: sort, Offset: offset, Limit: 3,
			})
			if err != nil {
				t.Fatal(err)
			}
			seen = append(seen, ids(hits)...)
		}
		slices.SortFunc(seen, uuid.UUID.Compare)
		want := slices.Clone(all)
		slices.SortFunc(want, uuid.UUID.Compare)
		if !slices.Equal(seen, want) {
			t.Fatalf("%s: %d seen of %d, or a repeat", sort, len(seen), len(want))
		}
	}
}

func TestHybridBoostListAndCounts(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	s := accounttest.New(t, db)
	const td = domain.TextDims
	a := put(t, db, s, "Xe A", 1_000_000, embedtest.Near(td, 0, 1, 0.9), nil)
	b := put(t, db, s, "Xe B", 3_000_000, embedtest.Near(td, 0, 1, 0.8), nil)
	search := domain.Search{
		Vectors: vecs(embedtest.Axis(td, 0), nil),
		Boosts:  []domain.Boost{{Kind: domain.BoostPrice, PriceMin: 2_000_000, PriceMax: 4_000_000, Weight: 1.5}},
		Weights: domain.Weights{Text: 1, Boost: 2}, Sort: domain.SortRelevance, Limit: 10,
	}
	hits, err := repository.NewSearches(db).Search(ctx, search)
	if got := ids(hits); err != nil || !slices.Equal(got, []uuid.UUID{b, a}) {
		t.Fatalf("the boost list lifts b: %v %v", got, err)
	}
	counts, err := repository.NewSearches(db).Counts(ctx, search, domain.CountCode)
	if err != nil || len(counts) != 1 || counts[0].Count != 2 {
		t.Fatalf("%+v %v", counts, err)
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/catalog/repository/ -run TestHybrid`
Expected: FAIL: vectors and weights are ignored, so the first test sees BM25 results alone.

- [ ] **Step 3: Implement the hybrid query**

In `search_pg.go`, add after `distanceSQL`:

```go
// photoScan is how many photo rows the photo list reads before it groups
// them by listing: about four photos a listing.
const photoScan = 4 * domain.MaxResults

// filters is the person's filters and the exclusions as plain SQL on the
// listings alias l, for the vector lists and the boost list. The BM25 list
// gets the same filters through must.
func (q *query) filters(s domain.Search) string {
	f := s.Filters
	out := []string{`l.status = ` + q.arg(string(domain.StatusActive), "text")}
	if f.CategoryRoot != "" {
		out = append(out, `l.category_root = `+q.arg(f.CategoryRoot, "text"))
	}
	if f.CategoryCode != "" {
		out = append(out, `l.category_code = `+q.arg(f.CategoryCode, "text"))
	}
	if f.PriceMin > 0 {
		out = append(out, `l.price >= `+q.arg(f.PriceMin, "bigint"))
	}
	if f.PriceMax > 0 {
		out = append(out, `l.price <= `+q.arg(f.PriceMax, "bigint"))
	}
	if len(f.Conditions) > 0 {
		conds := make([]string, len(f.Conditions))
		for i, c := range f.Conditions {
			conds[i] = string(c)
		}
		out = append(out, `l.condition = ANY(`+q.arg(conds, "text[]")+`)`)
	}
	if f.OffersOnly {
		out = append(out, `l.allow_offers`)
	}
	if f.Origin != nil && f.RadiusKm > 0 {
		out = append(out, distanceSQL+` <= @radius`)
	}
	return strings.Join(append(out, q.exclusions(s, "l.")...), " AND ")
}

// exclusions leave out a similar-listings search's source and one seller.
func (q *query) exclusions(s domain.Search, alias string) []string {
	var out []string
	if s.Like != (uuid.UUID{}) {
		out = append(out, alias+`id <> `+q.arg(s.Like, "uuid"))
	}
	if s.ExcludeSeller != (uuid.UUID{}) {
		out = append(out, alias+`seller_id <> `+q.arg(s.ExcludeSeller, "uuid"))
	}
	return out
}

// points is a listing's boost points as plain SQL on l: each boost's
// weight when it matches.
func (q *query) points(boosts []domain.Boost) string {
	terms := []string{"0"}
	for _, b := range boosts {
		var cond string
		switch b.Kind {
		case domain.BoostCategory:
			cond = `l.category_code = ` + q.arg(b.Code, "text")
		case domain.BoostCategoryRoot:
			cond = `l.category_root = ` + q.arg(b.Code, "text")
		case domain.BoostPrice:
			var c []string
			if b.PriceMin > 0 {
				c = append(c, `l.price >= `+q.arg(b.PriceMin, "bigint"))
			}
			if b.PriceMax > 0 {
				c = append(c, `l.price <= `+q.arg(b.PriceMax, "bigint"))
			}
			if len(c) == 0 {
				continue
			}
			cond = strings.Join(c, " AND ")
		case domain.BoostCondition:
			cond = `l.condition = ` + q.arg(string(b.Condition), "text")
		case domain.BoostOffers:
			cond = `l.allow_offers`
		case domain.BoostNear:
			lo, hi := domain.Box(b.Near, b.RadiusKm)
			cond = `l.lat BETWEEN ` + q.arg(lo.Lat, "float8") + ` AND ` + q.arg(hi.Lat, "float8") +
				` AND l.lng BETWEEN ` + q.arg(lo.Lng, "float8") + ` AND ` + q.arg(hi.Lng, "float8")
		case domain.BoostFresh:
			cond = `l.published_at >= ` + q.arg(b.Since, "timestamptz")
		default:
			continue
		}
		terms = append(terms, `CASE WHEN `+cond+` THEN `+q.arg(b.Weight, "float8")+` ELSE 0 END`)
	}
	return strings.Join(terms, " + ")
}

// hybrid is the WITH clause of a hybrid search: one CTE per list, each at
// most MaxResults listings ranked from 1, and fused, the weighted RRF score
// of every listing a list found.
func (q *query) hybrid(s domain.Search) string {
	q.args["list"] = domain.MaxResults
	if o := s.Filters.Origin; o != nil {
		q.args["olat"], q.args["olng"] = o.Lat, o.Lng
		if s.Filters.RadiusKm > 0 {
			q.args["radius"] = s.Filters.RadiusKm
		}
	}
	var ctes, lists []string
	share := func(name string, w float64) {
		lists = append(lists, name)
		ctes = append(ctes, name+`_share AS (SELECT id, `+q.arg(w, "float8")+` / (`+
			fmt.Sprint(domain.RRFK)+` + rank) AS share FROM `+name+`)`)
	}
	if s.Weights.BM25 > 0 && len(s.Phrases) > 0 {
		where := q.where(s, true)
		if ex := q.exclusions(s, ""); len(ex) > 0 {
			where += ` AND ` + strings.Join(ex, " AND ")
		}
		if s.Filters.Origin != nil && s.Filters.RadiusKm > 0 {
			where += ` AND ` + distanceSQL + ` <= @radius`
		}
		ctes = append(ctes, `bm25 AS (SELECT id, row_number() OVER (ORDER BY score DESC, id) AS rank FROM (
SELECT id, paradedb.score(id) AS score FROM listings WHERE `+where+` ORDER BY score DESC, id LIMIT @list) b)`)
		share("bm25", s.Weights.BM25)
	}
	if s.Weights.Text > 0 && s.Vectors.Text != nil {
		q.args["tq"], q.args["tv"], q.args["tmax"] = pgvec.Format(s.Vectors.Text), s.Vectors.TextVersion, 1-s.Vectors.TextMin
		ctes = append(ctes, `txt AS (SELECT id, row_number() OVER (ORDER BY d, id) AS rank FROM (
SELECT t.listing_id AS id, t.embedding <=> @tq::halfvec(1024) AS d
FROM listing_text_vectors AS t JOIN listings AS l ON l.id = t.listing_id
WHERE t.model = @tv AND `+q.filters(s)+` AND t.embedding <=> @tq::halfvec(1024) <= @tmax
ORDER BY t.embedding <=> @tq::halfvec(1024) LIMIT @list) v)`)
		share("txt", s.Weights.Text)
	}
	if s.Weights.Photo > 0 && s.Vectors.Photo != nil {
		q.args["pq"], q.args["pv"], q.args["pmax"], q.args["scan"] =
			pgvec.Format(s.Vectors.Photo), s.Vectors.PhotoVersion, 1-s.Vectors.PhotoMin, photoScan
		ctes = append(ctes, `img AS (SELECT id, row_number() OVER (ORDER BY d, id) AS rank FROM (
SELECT id, min(d) AS d FROM (
    SELECT p.listing_id AS id, p.embedding <=> @pq::halfvec(1152) AS d
    FROM listing_photo_vectors AS p JOIN listings AS l ON l.id = p.listing_id
    WHERE p.model = @pv AND `+q.filters(s)+` AND p.embedding <=> @pq::halfvec(1152) <= @pmax
    ORDER BY p.embedding <=> @pq::halfvec(1152) LIMIT @scan) x
GROUP BY id ORDER BY d, id LIMIT @list) v)`)
		share("img", s.Weights.Photo)
	}
	if s.Weights.Boost > 0 && len(s.Boosts) > 0 && len(lists) > 0 {
		pool := make([]string, len(lists))
		for i, l := range lists {
			pool[i] = `SELECT id FROM ` + l
		}
		ctes = append(ctes, `boost AS (SELECT id, row_number() OVER (ORDER BY points DESC, id) AS rank FROM (
SELECT l.id, `+q.points(s.Boosts)+` AS points FROM listings AS l JOIN (`+strings.Join(pool, " UNION ")+`) AS c ON c.id = l.id) p
WHERE points > 0)`)
		share("boost", s.Weights.Boost)
	}
	if len(lists) == 0 {
		// Nothing to fuse, such as a photo search whose list was left out:
		// an empty page rather than every listing.
		ctes = append(ctes, `fused AS (SELECT NULL::uuid AS id, 0::float8 AS score WHERE false)`)
		return `WITH ` + strings.Join(ctes, ",\n")
	}
	shares := make([]string, len(lists))
	for i, l := range lists {
		shares[i] = `SELECT id, share FROM ` + l + `_share`
	}
	ctes = append(ctes, `fused AS (SELECT id, sum(share) AS score FROM (`+strings.Join(shares, " UNION ALL ")+`) s GROUP BY id)`)
	return `WITH ` + strings.Join(ctes, ",\n")
}
```

Notes for the implementer:

- `distanceSQL` names `lat` and `lng` unqualified. In `txt` and `img` they resolve to `l`, since the vector tables have no such columns. In `bm25` they resolve to `listings`.
- A list whose share CTE is named in `lists` is only added after its source CTE, so the `boost` pool reads only existing CTEs. `lists` holds the source names (`bm25`, `txt`, `img`) at the time `boost` is built.
- The parameters `tq` and `pq` are named once and referenced three times, so one copy of each vector is sent.

Then make `Search` and `Counts` branch:

```go
func (s pgSearches) Search(ctx context.Context, in domain.Search) ([]domain.Hit, error) {
	if in.Hybrid() {
		return s.hybridSearch(ctx, in)
	}
	... the existing body, unchanged ...
}

func (s pgSearches) hybridSearch(ctx context.Context, in domain.Search) ([]domain.Hit, error) {
	q := query{args: pgx.StrictNamedArgs{"limit": in.Limit, "offset": in.Offset}}
	sql := q.hybrid(in) + `
SELECT l.id, l.lat, l.lng FROM fused AS f JOIN listings AS l ON l.id = f.id`
	switch in.Sort { //nolint:exhaustive // relevance is the default order
	case domain.SortNewest:
		sql += ` ORDER BY l.published_at DESC, l.id DESC`
	case domain.SortPriceAsc:
		sql += ` ORDER BY l.price ASC, l.id`
	case domain.SortPriceDesc:
		sql += ` ORDER BY l.price DESC, l.id`
	case domain.SortNearest:
		sql += ` ORDER BY ` + distanceSQL + `, l.id`
	default:
		sql += ` ORDER BY f.score DESC, l.id`
	}
	var hits []domain.Hit
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		// The vector lists filter after the index; iterative scans keep
		// reading the index until a list is full or max_scan_tuples is read.
		if _, err := tx.Exec(ctx, `SET LOCAL hnsw.iterative_scan = relaxed_order`); err != nil {
			return fmt.Errorf("set iterative scan: %w", err)
		}
		rows, err := tx.Query(ctx, sql+` LIMIT @limit OFFSET @offset`, q.args)
		if err != nil {
			return fmt.Errorf("hybrid search: %w", err)
		}
		hits, err = pgx.CollectRows(rows, func(row pgx.CollectableRow) (domain.Hit, error) {
			var h domain.Hit
			return h, row.Scan(&h.ID, &h.Point.Lat, &h.Point.Lng)
		})
		return err
	})
	if err != nil {
		return nil, fmt.Errorf("search: %w", err)
	}
	return hits, nil
}
```

`SortNearest` needs `olat` and `olng`; `hybrid` sets them whenever there is an origin, and the service refuses nearest without one (`position_required`).

In `Counts`, at the top:

```go
	if in.Hybrid() {
		q := query{args: pgx.StrictNamedArgs{}}
		column := "l.category_code"
		if by == domain.CountRoot {
			column = "l.category_root"
		}
		var counts []domain.CategoryCount
		err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
			if _, err := tx.Exec(ctx, `SET LOCAL hnsw.iterative_scan = relaxed_order`); err != nil {
				return err
			}
			rows, err := tx.Query(ctx, q.hybrid(in)+`
SELECT `+column+`, count(*) FROM fused AS f JOIN listings AS l ON l.id = f.id GROUP BY 1 ORDER BY 2 DESC, 1`, q.args)
			if err != nil {
				return err
			}
			counts, err = pgx.CollectRows(rows, pgx.RowToStructByPos[domain.CategoryCount])
			return err
		})
		if err != nil {
			return nil, fmt.Errorf("count: %w", err)
		}
		return counts, nil
	}
```

`hybrid` sets `list` (and the vectors) in `q.args`; every name it sets is used by the SQL it returns, which strict named args require. Check that `radius` is set only when a filter uses it, and `olat`/`olng` only when `distanceSQL` appears; if the strict check refuses an origin without radius or nearest, set them only in those two cases.

- [ ] **Step 4: The service resolves `Like`**

In `internal/catalog/service/search.go`, at the top of `Search`:

```go
	if s.Hybrid() {
		s.Vectors.TextVersion, s.Vectors.PhotoVersion = c.textVersion, c.imageVersion
	}
	if s.Like != (uuid.UUID{}) {
		text, photo, err := c.vectors.Source(ctx, s.Like, c.textVersion, c.imageVersion)
		if err != nil {
			return nil, fmt.Errorf("read the source's vectors: %w", err)
		}
		s.Vectors.Text, s.Vectors.Photo = text, photo
	}
```

Do the same at the top of `Counts`. (The source may have no vectors yet; its lists are then left out and BM25 and boosts answer.)

- [ ] **Step 5: Run the tests**

Run: `go test ./internal/catalog/... -run 'Hybrid|Search' -v`
Expected: PASS, the existing search tests included.

- [ ] **Step 6: Commit**

```bash
git add internal/catalog
git commit -m "feat(catalog): hybrid search fuses BM25, text and photo vectors by RRF"
```

---

### Task 10: Discovery domain: rewrite, visual, fusion terms, errors

**Files:**
- Modify: `internal/discovery/domain/understanding.go`, `understanding_test.go`
- Create: `internal/discovery/domain/fusion.go`, `fusion_test.go`
- Modify: `internal/discovery/domain/errors.go`

**Interfaces:**
- Produces:
  - `Understanding` gains `Rewritten string \`json:"rewritten"\`` and `Visual string \`json:"visual"\``; `PromptVersion = 2`.
  - `domain.FuseQuery`, `domain.FuseLike`, `domain.FusePhoto` (`catalogdomain.Weights`).
  - `domain.LikePriceBand = 0.3`; `domain.LikeTerms(title, category string, price int64) ([]catalogdomain.Phrase, []catalogdomain.Boost)`.
  - `domain.ErrSearchConflict` (400 `search_conflict`), `domain.ErrSearchUnavailable` (503 `search_unavailable`).

- [ ] **Step 1: Write the failing tests**

`internal/discovery/domain/fusion_test.go`:

```go
package domain_test

import (
	"testing"

	catalogdomain "github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/discovery/domain"
)

func TestLikeTerms(t *testing.T) {
	t.Parallel()
	phrases, boosts := domain.LikeTerms("Xe đạp Asama", "vehicles.bicycle", 1_000_000)
	if len(phrases) != 1 || phrases[0].Text != "Xe đạp Asama" || phrases[0].Weight != 1 {
		t.Fatalf("%+v", phrases)
	}
	if len(boosts) != 2 || boosts[0].Kind != catalogdomain.BoostCategory || boosts[0].Code != "vehicles.bicycle" ||
		boosts[1].Kind != catalogdomain.BoostPrice || boosts[1].PriceMin != 700_000 || boosts[1].PriceMax != 1_300_000 {
		t.Fatalf("%+v", boosts)
	}
}

func TestWeights(t *testing.T) {
	t.Parallel()
	if domain.FuseQuery != (catalogdomain.Weights{BM25: 1, Text: 1, Photo: 0.5, Boost: 0.75}) ||
		domain.FuseLike != (catalogdomain.Weights{BM25: 0.5, Text: 1, Photo: 1, Boost: 0.5}) ||
		domain.FusePhoto != (catalogdomain.Weights{Photo: 1}) {
		t.Fatal("weights drifted from the spec")
	}
}
```

In `understanding_test.go` add:

```go
func TestSchemaAsksForRewriteAndVisual(t *testing.T) {
	t.Parallel()
	var s struct {
		Required   []string                   `json:"required"`
		Properties map[string]json.RawMessage `json:"properties"`
	}
	if err := json.Unmarshal(domain.Schema(), &s); err != nil {
		t.Fatal(err)
	}
	if !slices.Contains(s.Required, "rewritten") || !slices.Contains(s.Required, "visual") ||
		s.Properties["visual"] == nil || domain.PromptVersion != 2 {
		t.Fatalf("%+v v%d", s.Required, domain.PromptVersion)
	}
	if p := domain.SystemPrompt(nil, time.Now()); !strings.Contains(p, "rewritten") || !strings.Contains(p, "visual") {
		t.Fatal("the prompt does not explain the new fields")
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/discovery/domain/`
Expected: FAIL.

- [ ] **Step 3: Implement**

`fusion.go`:

```go
package domain

import catalogdomain "github.com/shopnexus/server2/internal/catalog/domain"

// The weights of each list in a hybrid search's RRF, starting values that
// make search-eval tunes (see ARCHITECTURE.md, Search).
var (
	FuseQuery = catalogdomain.Weights{BM25: 1, Text: 1, Photo: 0.5, Boost: 0.75}
	FuseLike  = catalogdomain.Weights{BM25: 0.5, Text: 1, Photo: 1, Boost: 0.5}
	FusePhoto = catalogdomain.Weights{Photo: 1}
)

// LikePriceBand is the share of the source's price either side of it that a
// similar listing's price is boosted within.
const LikePriceBand = 0.3

// LikeTerms are the BM25 terms of a similar-listings search: the source's
// title as a phrase, and boosts for its subcategory and for prices within
// LikePriceBand of its own, at the model's category and price weights.
func LikeTerms(title, category string, price int64) ([]catalogdomain.Phrase, []catalogdomain.Boost) {
	band := int64(float64(price) * LikePriceBand)
	return []catalogdomain.Phrase{{Text: title, Weight: weight[AttrPhrase]}},
		[]catalogdomain.Boost{
			{Kind: catalogdomain.BoostCategory, Code: category, Weight: weight[AttrCategory]},
			{Kind: catalogdomain.BoostPrice, PriceMin: price - band, PriceMax: price + band, Weight: weight[AttrPrice]},
		}
}
```

In `understanding.go`:

- `PromptVersion = 2`, with the comment line `// 2 added rewritten and visual (2026-11-09).`
- `Understanding`:

```go
type Understanding struct {
	Understood string `json:"understood"`
	// Rewritten is the query in correct Vietnamese, for the text vectors.
	Rewritten string `json:"rewritten"`
	// Visual is how the item looks, in short English, for the photo
	// vectors; empty when the query says nothing about looks.
	Visual  string   `json:"visual"`
	Boosts  []Signal `json:"boosts"`
	Demotes []Signal `json:"demotes"`
}
```

- In `Schema()`, `"required":["understood","rewritten","visual","boosts","demotes"]` and the properties `"rewritten":{"type":"string"},"visual":{"type":"string"},` after `"understood"`.
- In `SystemPrompt`, replace the last sentence before `Categories:` with:

```
round. Never write a weight or a score. understood is one short Vietnamese sentence of what will be searched.
rewritten is the whole query in correct Vietnamese with diacritics, typos fixed and abbreviations spelled out
("ip13 pm xanh" is "iPhone 13 Pro Max màu xanh"). visual describes in English, in at most 12 words, how the item
the person wants looks ("iPhone 13 Pro Max smartphone, blue"); leave it empty when the query only names a price, a
place, a condition or a time.
```

In `errors.go`:

```go
	ErrSearchConflict = apperr.New(apperr.KindBadRequest, "search_conflict", "photo goes alone, without q or like")
	ErrSearchUnavailable = apperr.New(apperr.KindUnavailable, "search_unavailable",
		"the photo could not be read for search; try again")
```

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/discovery/domain/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/discovery/domain
git commit -m "feat(discovery): the query rewrite, its visual description and the fusion terms"
```

---

### Task 11: Discovery repository: the query vector caches

**Files:**
- Modify: `internal/discovery/repository/repository.go`
- Create: `internal/discovery/repository/vectors_pg.go`, `vectors_pg_test.go`

**Interfaces:**
- Produces:

```go
// QueryVectors caches the vectors of texts a search embedded. It records no account.
type QueryVectors interface {
	Get(ctx context.Context, key string, promptVersion int, model string, since time.Time) ([]float32, bool, error)
	Put(ctx context.Context, key string, promptVersion int, model string, v []float32, at, expired time.Time) error
}
// PhotoVectors caches the vector of a search photo until its upload expires.
type PhotoVectors interface {
	Get(ctx context.Context, upload uuid.UUID, model string, now time.Time) ([]float32, bool, error)
	Put(ctx context.Context, upload uuid.UUID, model string, v []float32, expires, now time.Time) error
}
func NewQueryVectors(db *pgxpool.Pool) QueryVectors
func NewPhotoVectors(db *pgxpool.Pool) PhotoVectors
```

- [ ] **Step 1: Write the failing test**

`vectors_pg_test.go`:

```go
package repository_test

import (
	"context"
	"slices"
	"testing"
	"time"
	"uuid"

	catalogdomain "github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/discovery/repository"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server2/internal/provider/embed/embedtest"
)

func TestQueryVectors(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	c := repository.NewQueryVectors(db)
	now := time.Now()
	v := []float32{0.5, 0.5}
	if err := c.Put(ctx, "xe dap", 2, "m1", v, now, now.Add(-time.Hour)); err != nil {
		t.Fatal(err)
	}
	got, ok, err := c.Get(ctx, "xe dap", 2, "m1", now.Add(-time.Minute))
	if err != nil || !ok || !slices.Equal(got, v) {
		t.Fatalf("%v %v %v", got, ok, err)
	}
	for name, args := range map[string]struct {
		model string
		ver   int
		since time.Time
	}{"model": {"m2", 2, now.Add(-time.Minute)}, "version": {"m1", 1, now.Add(-time.Minute)}, "stale": {"m1", 2, now.Add(time.Minute)}} {
		if _, ok, _ := c.Get(ctx, "xe dap", args.ver, args.model, args.since); ok {
			t.Errorf("%s: found", name)
		}
	}
	if err = c.Put(ctx, "noi com", 2, "m1", v, now.Add(time.Hour), now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if _, ok, _ = c.Get(ctx, "xe dap", 2, "m1", time.Time{}); ok {
		t.Fatal("the write of a new row deletes the expired ones")
	}
}

func TestPhotoVectors(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	c := repository.NewPhotoVectors(db)
	now := time.Now()
	up := uuid.NewV7()
	axis := embedtest.Axis(catalogdomain.PhotoDims, 0)
	if err := c.Put(ctx, up, "p1", axis, now.Add(time.Hour), now); err != nil {
		t.Fatal(err)
	}
	if got, ok, err := c.Get(ctx, up, "p1", now); err != nil || !ok || got[0] != 1 {
		t.Fatalf("%v %v %v", got, ok, err)
	}
	if _, ok, _ := c.Get(ctx, up, "p2", now); ok {
		t.Fatal("another model")
	}
	if _, ok, _ := c.Get(ctx, up, "p1", now.Add(2*time.Hour)); ok {
		t.Fatal("past its expiry")
	}
	if err := c.Put(ctx, uuid.NewV7(), "p1", axis, now.Add(3*time.Hour), now.Add(2*time.Hour)); err != nil {
		t.Fatal(err)
	}
	var n int
	_ = db.QueryRow(ctx, `SELECT count(*) FROM search_photo_vectors`).Scan(&n)
	if n != 1 {
		t.Fatalf("the expired row stays: %d rows", n)
	}
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/discovery/repository/ -run 'Vectors'`
Expected: FAIL.

- [ ] **Step 3: Implement**

Add the interfaces to `repository.go` with the doc comments from the Interfaces block (and update the package comment: `... the caches of what the model understood of a query and of the vectors a search embedded ...`).

`vectors_pg.go`:

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

	"github.com/shopnexus/server2/internal/platform/pgvec"
)

type pgQueryVectors struct{ db *pgxpool.Pool }

func NewQueryVectors(db *pgxpool.Pool) QueryVectors { return pgQueryVectors{db} }

func (s pgQueryVectors) Get(ctx context.Context, key string, promptVersion int, model string, since time.Time) ([]float32, bool, error) {
	var text string
	err := s.db.QueryRow(ctx, `SELECT embedding::text FROM search_query_vectors
WHERE query_key = @key AND prompt_version = @version AND model = @model AND created_at >= @since`,
		pgx.StrictNamedArgs{"key": key, "version": promptVersion, "model": model, "since": since}).Scan(&text)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("read query vector: %w", err)
	}
	v, err := pgvec.Parse(text)
	return v, err == nil, err
}

func (s pgQueryVectors) Put(ctx context.Context, key string, promptVersion int, model string, v []float32, at, expired time.Time) error {
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `DELETE FROM search_query_vectors WHERE created_at < @expired`,
			pgx.StrictNamedArgs{"expired": expired}); err != nil {
			return fmt.Errorf("delete expired: %w", err)
		}
		_, err := tx.Exec(ctx, `INSERT INTO search_query_vectors (query_key, prompt_version, model, embedding, created_at)
VALUES (@key, @version, @model, @v::halfvec, @at)
ON CONFLICT (query_key, prompt_version, model) DO UPDATE SET embedding = excluded.embedding, created_at = excluded.created_at`,
			pgx.StrictNamedArgs{"key": key, "version": promptVersion, "model": model, "v": pgvec.Format(v), "at": at})
		return err
	})
	if err != nil {
		return fmt.Errorf("store query vector: %w", err)
	}
	return nil
}

type pgPhotoVectors struct{ db *pgxpool.Pool }

func NewPhotoVectors(db *pgxpool.Pool) PhotoVectors { return pgPhotoVectors{db} }

func (s pgPhotoVectors) Get(ctx context.Context, upload uuid.UUID, model string, now time.Time) ([]float32, bool, error) {
	var text string
	err := s.db.QueryRow(ctx, `SELECT embedding::text FROM search_photo_vectors
WHERE upload_id = @id AND model = @model AND expires_at > @now`,
		pgx.StrictNamedArgs{"id": upload, "model": model, "now": now}).Scan(&text)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("read photo vector: %w", err)
	}
	v, err := pgvec.Parse(text)
	return v, err == nil, err
}

func (s pgPhotoVectors) Put(ctx context.Context, upload uuid.UUID, model string, v []float32, expires, now time.Time) error {
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `DELETE FROM search_photo_vectors WHERE expires_at <= @now`,
			pgx.StrictNamedArgs{"now": now}); err != nil {
			return fmt.Errorf("delete expired: %w", err)
		}
		_, err := tx.Exec(ctx, `INSERT INTO search_photo_vectors (upload_id, model, embedding, expires_at)
VALUES (@id, @model, @v::halfvec(1152), @expires)
ON CONFLICT (upload_id) DO UPDATE SET model = excluded.model, embedding = excluded.embedding, expires_at = excluded.expires_at`,
			pgx.StrictNamedArgs{"id": upload, "model": model, "v": pgvec.Format(v), "expires": expires})
		return err
	})
	if err != nil {
		return fmt.Errorf("store photo vector: %w", err)
	}
	return nil
}
```

- [ ] **Step 4: Run the tests**

Run: `go test ./internal/discovery/repository/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/discovery/repository
git commit -m "feat(discovery): cache the vectors a search embeds"
```

---

### Task 12: Discovery service: photo, like and the vector lists of q

**Files:**
- Modify: `internal/discovery/service/service.go` (Deps)
- Modify: `internal/discovery/service/search.go`
- Modify: `internal/discovery/handler/search.go`
- Modify: `internal/discovery/discovery.go` (Settings, Mount)
- Modify: `internal/catalog/service/views.go` and the code that builds `Summary` (add `CategoryCode`, `Condition`)
- Modify: `internal/app/app.go`
- Modify: `internal/discovery/service/saved_test.go` (newEnv), `search_test.go`
- Create: `e2e/search_vector_test.go`

**Interfaces:**
- Consumes: everything above.
- Produces: `SearchInput` gains `Photo, Like uuid.UUID`; `service.Deps` gains `Media mediasvc.Service`, `QueryVectors repository.QueryVectors`, `PhotoVectors repository.PhotoVectors`, `Text, Image embed.Model` (search key), `TextVersion, ImageVersion string`, `TextMin, PhotoMin float64`; `discovery.Settings` gains the same model fields; `discovery.Mount(d, s, catalog, media)`.

- [ ] **Step 1: Extend the test env**

In `saved_test.go`'s `newEnv`: build the media service once and keep it, add the fakes and caches:

```go
	m := mediatest.Service(db, objectstoretest.New(t), in, p)
	restatetest.Start(t, m.Durable()...)
	c := catalogtest.Service(db, accounttest.Service(db), m, in, p)
	text, image := embedtest.New(catalogdomain.TextDims), embedtest.New(catalogdomain.PhotoDims)
	d := service.New(service.Deps{
		Saves: repository.NewSaves(db), Understandings: repository.NewUnderstandings(db),
		QueryVectors: repository.NewQueryVectors(db), PhotoVectors: repository.NewPhotoVectors(db),
		Catalog: c, Media: m, LLM: model, Text: text, Image: image, TextVersion: "text-test", ImageVersion: "image-test",
		TextMin: 0.5, PhotoMin: 0.5,
		ModelTimeout: 200 * time.Millisecond, Log: slog.New(slog.DiscardHandler), Now: time.Now,
	})
	return env{db: db, catalog: c, media: m, discovery: d, model: model, text: text, image: image}
```

and add `media *mediasvc.Media; text, image *embedtest.Model` to `env`.

- [ ] **Step 2: Write the failing tests**

Add to `search_test.go`:

```go
// vec gives listing a text vector and a photo vector, as ListingEmbed would.
func (e env) vec(t *testing.T, id uuid.UUID, text, photo []float32) {
	t.Helper()
	vs := catalogrepo.NewVectors(e.db)
	if text != nil {
		if err := vs.PutText(context.Background(), id, "text-test", []byte{1}, text, time.Now()); err != nil {
			t.Fatal(err)
		}
	}
	if photo != nil {
		if err := vs.PutPhoto(context.Background(), id, "media/a.jpg", "image-test", photo, time.Now()); err != nil {
			t.Fatal(err)
		}
	}
}

func TestSearchFindsByMeaning(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	kid := e.put(t, "Xe cho bé 4 tuổi", "vehicles.bicycle", baDinh)
	pot := e.put(t, "Nồi cơm điện", "home.kitchen", baDinh)
	e.vec(t, kid, embedtest.Axis(catalogdomain.TextDims, 0), nil)
	e.vec(t, pot, embedtest.Axis(catalogdomain.TextDims, 1), nil)
	e.model.answers["xe dap tre em"] = `{"understood":"Xe đạp trẻ em","rewritten":"xe đạp trẻ em","visual":"",` +
		`"boosts":[{"attr":"phrase","values":["xe đạp trẻ em"]}],"demotes":[]}`
	e.text.Set("xe đạp trẻ em", embedtest.Axis(catalogdomain.TextDims, 0))
	v, err := e.discovery.Search(ctx, nil, service.SearchInput{Query: "xe dap tre em"})
	if err != nil || len(v.Items) != 1 || v.Items[0].ID != kid {
		t.Fatalf("no shared word, found by its text vector: %+v %v", v, err)
	}
	if e.image.Calls() != 0 {
		t.Fatal("an empty visual embeds nothing")
	}
	if _, err = e.discovery.Search(ctx, nil, service.SearchInput{Query: "xe dap tre em", Cursor: "1"}); err != nil || e.text.Calls() != 1 {
		t.Fatalf("page 2 embeds again: %d %v", e.text.Calls(), err)
	}
}

func TestSearchWithoutEmbeddingsFallsBackToWords(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	bike := e.put(t, "Xe đạp Asama", "vehicles.bicycle", baDinh)
	e.text.SetFail(errors.New("down"))
	e.image.SetFail(errors.New("down"))
	e.model.answers["xe dap"] = `{"understood":"Xe đạp","rewritten":"xe đạp","visual":"a bicycle",` +
		`"boosts":[{"attr":"phrase","values":["xe đạp"]}],"demotes":[]}`
	v, err := e.discovery.Search(context.Background(), nil, service.SearchInput{Query: "xe dap"})
	if err != nil || len(v.Items) != 1 || v.Items[0].ID != bike {
		t.Fatalf("%+v %v", v, err)
	}
}

func TestSearchModelDownEmbedsTheRawQuery(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	e.model.fail = true
	if _, err := e.discovery.Search(context.Background(), nil, service.SearchInput{Query: "ip13 pm"}); err != nil {
		t.Fatal(err)
	}
	if in := e.text.Inputs(); len(in) != 1 || in[0] != "ip13 pm" || e.image.Calls() != 0 {
		t.Fatalf("text %v, image %d", in, e.image.Calls())
	}
}

func TestSearchByPhoto(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me := accounttest.New(t, e.db)
	chair := e.put(t, "Ghế gỗ", "furniture.other", baDinh)
	e.vec(t, chair, nil, embedtest.Axis(catalogdomain.PhotoDims, 0))
	photo := mediatest.Upload(t, e.media, me, "image/jpeg", mediatest.JPEG(t, 1200, 900))
	e.image.SetFail(nil)
	// The fake hashes the data URL; make that input land on axis 0.
	img, err := e.media.QueryImage(ctx, me, photo)
	if err != nil {
		t.Fatal(err)
	}
	e.image.Set(embed.ImageInput(img), embedtest.Axis(catalogdomain.PhotoDims, 0))

	v, err := e.discovery.Search(ctx, &me, service.SearchInput{Photo: photo})
	if err != nil || len(v.Items) != 1 || v.Items[0].ID != chair || v.Understood != "" || len(v.Chips) != 0 {
		t.Fatalf("%+v %v", v, err)
	}
	if _, err = e.discovery.Search(ctx, &me, service.SearchInput{Photo: photo, Cursor: "1"}); err != nil || e.image.Calls() != 1 {
		t.Fatalf("page 2 embeds the photo again: %d %v", e.image.Calls(), err)
	}
}

func TestSearchByPhotoRefuses(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me, other := accounttest.New(t, e.db), accounttest.New(t, e.db)
	photo := mediatest.Upload(t, e.media, me, "image/jpeg", mediatest.JPEG(t, 64, 48))
	for name, tc := range map[string]struct {
		viewer *uuid.UUID
		in     service.SearchInput
		want   error
	}{
		"with q":         {&me, service.SearchInput{Photo: photo, Query: "ghế"}, domain.ErrSearchConflict},
		"with like":      {&me, service.SearchInput{Photo: photo, Like: uuid.NewV7()}, domain.ErrSearchConflict},
		"signed out":     {nil, service.SearchInput{Photo: photo}, authn.ErrUnauthenticated},
		"someone else's": {&other, service.SearchInput{Photo: photo}, mediadomain.ErrInvalidUpload},
	} {
		if _, err := e.discovery.Search(ctx, tc.viewer, tc.in); !errors.Is(err, tc.want) {
			t.Errorf("%s: %v", name, err)
		}
	}
	if e.image.Calls() != 0 {
		t.Fatalf("a refused photo was embedded: %d", e.image.Calls())
	}
	e.image.SetFail(errors.New("down"))
	if _, err := e.discovery.Search(ctx, &me, service.SearchInput{Photo: photo}); !errors.Is(err, domain.ErrSearchUnavailable) {
		t.Fatal(err)
	}
}

func TestSearchLike(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me := accounttest.New(t, e.db)
	source := e.put(t, "Xe đạp Asama", "vehicles.bicycle", baDinh)
	twin := e.put(t, "Xe đạp Asama 26 inch", "vehicles.bicycle", baDinh)
	mine := catalogtest.Listing(t, e.db, me) // also "Xe đạp Asama"
	v, err := e.discovery.Search(ctx, &me, service.SearchInput{Like: source})
	if err != nil || len(v.Items) != 1 || v.Items[0].ID != twin {
		t.Fatalf("no vectors yet, BM25 and boosts answer; the source and mine stay out: %+v %v (mine %v)", v, err, mine)
	}
	e.vec(t, source, embedtest.Axis(catalogdomain.TextDims, 0), embedtest.Axis(catalogdomain.PhotoDims, 0))
	look := e.put(t, "Xe trẻ em", "vehicles.bicycle", baDinh)
	e.vec(t, look, nil, embedtest.Axis(catalogdomain.PhotoDims, 0))
	if v, err = e.discovery.Search(ctx, nil, service.SearchInput{Like: source}); err != nil || len(v.Items) != 3 {
		t.Fatalf("signed out: the twin, mine and the look-alike: %+v %v", v, err)
	}
	if e.text.Calls() != 0 || e.image.Calls() != 0 {
		t.Fatal("like embeds nothing at search time")
	}
	if _, err = e.discovery.Search(ctx, nil, service.SearchInput{Like: uuid.NewV7()}); !errors.Is(err, catalogdomain.ErrNotFound) {
		t.Fatal(err)
	}
}
```

(`catalogrepo` is `github.com/shopnexus/server2/internal/catalog/repository`; add the imports `embed`, `embedtest`, `mediatest`, `authn`, `mediadomain`, `time`.)

- [ ] **Step 3: Run them to see them fail**

Run: `go test ./internal/discovery/service/ -run 'TestSearch'`
Expected: FAIL to compile, then FAIL.

- [ ] **Step 4: Catalog's Summary**

Add `CategoryCode string \`json:"category_code"\`` and `Condition domain.Condition \`json:"condition"\`` to `catalogsvc.Summary`, and set them where summaries are built (`grep -n "Summary{" internal/catalog/service`).

- [ ] **Step 5: The service**

`service.go`: add the fields to `Deps` and `Discovery` (unexported), with these comments:

```go
	// Media reads a search photo; Text and Image embed with the search key,
	// under TextVersion and ImageVersion. TextMin and PhotoMin are the
	// floors of the vector lists.
```

`search.go`: add `Photo, Like uuid.UUID // zero for none` to `SearchInput`, then rewrite `Search`. The order below keeps it top to bottom; the only new helper is `queryVector`, which two places call.

```go
func (d *Discovery) Search(ctx context.Context, viewer *uuid.UUID, in SearchInput) (SearchView, error) {
	q := strings.TrimSpace(in.Query)
	photo, like := in.Photo != uuid.Nil(), in.Like != uuid.Nil()
	if photo && (q != "" || like) {
		return SearchView{}, domain.ErrSearchConflict
	}
	if photo && viewer == nil {
		return SearchView{}, authn.ErrUnauthenticated
	}
	origin, err := d.origin(ctx, in.Near)
	if err != nil {
		return SearchView{}, err
	}
	offset, limit, err := window(in.Cursor, in.Limit)
	if err != nil {
		return SearchView{}, err
	}
	if in.PriceMin > 0 && in.PriceMax > 0 && in.PriceMin > in.PriceMax {
		return SearchView{}, domain.ErrInvalidPriceRange
	}
	sort := in.Sort
	if sort == "" {
		sort = catalogdomain.SortNewest
		if q != "" || photo || like {
			sort = catalogdomain.SortRelevance
		}
	}
	... radius and filters as today ...
	search := catalogdomain.Search{Filters: filters, Sort: sort, Offset: offset, Limit: limit + 1}
	search.Vectors.TextMin, search.Vectors.PhotoMin = d.textMin, d.photoMin
	var view SearchView

	if photo {
		now := d.now()
		up, upErr := d.media.QueryUpload(ctx, *viewer, in.Photo)
		if upErr != nil {
			return SearchView{}, upErr
		}
		vec, found, cacheErr := d.photoVectors.Get(ctx, in.Photo, d.imageVersion, now)
		if cacheErr != nil {
			d.log.WarnContext(ctx, "read the cached photo vector", "err", cacheErr)
		}
		if !found {
			img, imgErr := d.media.QueryImage(ctx, *viewer, in.Photo)
			if imgErr != nil {
				return SearchView{}, imgErr
			}
			vs, embedErr := d.image.Embed(ctx, []string{embed.ImageInput(img)})
			if embedErr != nil {
				d.log.WarnContext(ctx, "embed the search photo", "err", embedErr)
				return SearchView{}, domain.ErrSearchUnavailable
			}
			vec = vs[0]
			if putErr := d.photoVectors.Put(ctx, in.Photo, d.imageVersion, vec, up.ExpiresAt, now); putErr != nil {
				d.log.WarnContext(ctx, "cache the photo vector", "err", putErr)
			}
		}
		search.Vectors.Photo, search.Weights = vec, domain.FusePhoto
	}

	if like {
		src, ok, srcErr := d.catalog.Summary(ctx, in.Like)
		if srcErr != nil {
			return SearchView{}, fmt.Errorf("read the source listing: %w", srcErr)
		}
		if !ok || !slices.Contains(catalogdomain.Public, src.Status) {
			return SearchView{}, catalogdomain.ErrNotFound
		}
		search.Phrases, search.Boosts = domain.LikeTerms(src.Title, src.CategoryCode, src.Price)
		search.Like, search.Weights = in.Like, domain.FuseLike
		if viewer != nil {
			search.ExcludeSeller = *viewer
		}
	}

	if q != "" {
		... the understanding block as today, up to and including Compile ...
		search.Phrases = append(search.Phrases, c.Phrases...)
		search.Boosts = append(search.Boosts, c.Boosts...)
		view.Chips = c.Chips
		if understood {
			view.Understood = u.Understood
		}
		if !like {
			// The text vector reads the rewrite, or the raw words when the
			// model did not answer; the photo list needs the English
			// description, which only the model gives.
			text := q
			if understood && strings.TrimSpace(u.Rewritten) != "" {
				text = u.Rewritten
			}
			search.Vectors.Text = d.queryVector(ctx, d.text, d.textVersion, text)
			if understood && strings.TrimSpace(u.Visual) != "" {
				search.Vectors.Photo = d.queryVector(ctx, d.image, d.imageVersion, u.Visual)
			}
			if search.Vectors.Text != nil || search.Vectors.Photo != nil {
				search.Weights = domain.FuseQuery
			}
		}
	}

	cards, err := d.catalog.Search(ctx, search)
	... the rest as today ...
}

// queryVector embeds a search text with m, from the cache when the same text
// was embedded under version within domain.CacheTTL. A model that fails
// gives nil, and the search runs without that list.
func (d *Discovery) queryVector(ctx context.Context, m embed.Model, version, text string) []float32 {
	now := d.now()
	key := domain.QueryKey(text)
	v, found, err := d.queryVectors.Get(ctx, key, domain.PromptVersion, version, now.Add(-domain.CacheTTL))
	if err != nil {
		d.log.WarnContext(ctx, "read the cached query vector", "err", err)
	}
	if found {
		return v
	}
	vs, err := m.Embed(ctx, []string{text})
	if err != nil {
		d.log.WarnContext(ctx, "embed the query", "version", version, "err", err)
		return nil
	}
	if err = d.queryVectors.Put(ctx, key, domain.PromptVersion, version, vs[0], now, now.Add(-domain.CacheTTL)); err != nil {
		d.log.WarnContext(ctx, "cache the query vector", "err", err)
	}
	return vs[0]
}
```

Keep the existing log line `"search terms"` and add `"lists", search.Weights` to it.

`handler/search.go`: add to `searchRequest`:

```go
	Photo uuid.UUID `json:"-" query:"photo"`
	Like  uuid.UUID `json:"-" query:"like"`
```

and pass `Photo: in.Photo, Like: in.Like` to `SearchInput`.

`discovery.go`:

```go
type Settings struct {
	// Model reads search queries.
	Model llm.Client
	// Text and Image embed with the search key, under the versions; the
	// floors are the cosine a listing needs to join a vector list.
	Text, Image               embed.Model
	TextVersion, ImageVersion string
	TextMin, PhotoMin         float64
}

func Mount(d module.Deps, s Settings, catalog catalogsvc.Service, media mediasvc.Service) service.Service {
	svc := service.New(service.Deps{
		Saves: repository.NewSaves(d.Pool), Understandings: repository.NewUnderstandings(d.Pool),
		QueryVectors: repository.NewQueryVectors(d.Pool), PhotoVectors: repository.NewPhotoVectors(d.Pool),
		Catalog: catalog, Media: media, LLM: s.Model, Text: s.Text, Image: s.Image,
		TextVersion: s.TextVersion, ImageVersion: s.ImageVersion, TextMin: s.TextMin, PhotoMin: s.PhotoMin,
		ModelTimeout: domain.ModelTimeout, Log: d.Log, Now: d.Now,
	})
	...
```

`app.go`:

```go
	discoverym := discovery.Mount(d, discovery.Settings{
		Model: model,
		Text:  embedder(cfg.Embed.TextBaseURL, cfg.Embed.TextModel, cfg.Embed.SearchAPIKey, catalogdomain.TextDims),
		Image: embedder(cfg.Embed.ImageBaseURL, cfg.Embed.ImageModel, cfg.Embed.SearchAPIKey, catalogdomain.PhotoDims),
		TextVersion: cfg.Embed.TextVersion, ImageVersion: cfg.Embed.ImageVersion,
		TextMin: cfg.Embed.TextMinSimilarity, PhotoMin: cfg.Embed.PhotoMinSimilarity,
	}, catalogm.Service, mediam.Service)
```

- [ ] **Step 6: e2e**

`e2e/search_vector_test.go` uses the helpers the package has: `newAccount` (`auth_helpers_test.go`), `upload` (`media_test.go`), `activeListing` (`catalog_test.go`), `search` and `band` (`search_test.go`), `check`, `bearer` (`helpers_test.go`), and `magentaPhoto` from `embed_stub_test.go` (index plan, Task 8). Together they observe every response Task 1 declares, which the run's coverage check requires:

```go
package e2e

import (
	"net/http"
	"net/url"
	"strconv"
	"testing"
	"uuid"
)

func TestSearchByPhoto(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	other, _ := newAccount(t)
	mine := upload(t, me.AccessToken, photoWithGPS(t))
	theirs := upload(t, other.AccessToken, photoWithGPS(t))

	res, _ := search(t, url.Values{"photo": {mine}})
	check(t, "signed out", res, http.StatusUnauthorized, "unauthenticated")
	res, _ = search(t, url.Values{"photo": {mine}, "q": {"ghế"}}, bearer(me.AccessToken))
	check(t, "with q", res, http.StatusBadRequest, "search_conflict")
	res, _ = search(t, url.Values{"photo": {mine}, "like": {uuid.NewV7().String()}}, bearer(me.AccessToken))
	check(t, "with like", res, http.StatusBadRequest, "search_conflict")
	res, _ = search(t, url.Values{"photo": {theirs}}, bearer(me.AccessToken))
	check(t, "someone else's", res, http.StatusUnprocessableEntity, "invalid_upload")

	res, v := search(t, url.Values{"photo": {mine}}, bearer(me.AccessToken))
	if res.Status != http.StatusOK || v.Understood != "" || len(v.Chips) != 0 {
		t.Fatalf("a photo search: %d %s", res.Status, res.Body)
	}
	if res, _ = search(t, url.Values{"photo": {mine}, "cursor": {"20"}}, bearer(me.AccessToken)); res.Status != http.StatusOK {
		t.Fatalf("a later page reuses the cached vector: %d %s", res.Status, res.Body)
	}
}

func TestSearchByPhotoUnavailable(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	down := upload(t, me.AccessToken, magentaPhoto(t))
	res, _ := search(t, url.Values{"photo": {down}}, bearer(me.AccessToken))
	check(t, "the image alias answers 503", res, http.StatusServiceUnavailable, "search_unavailable")
}

func TestSearchLike(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	viewer, _ := newAccount(t)
	lo, hi := band()
	fields := func(title string, price int64) map[string]any {
		return map[string]any{"title": title, "category_code": "furniture.other", "price": price}
	}
	source := activeListing(t, seller.AccessToken, fields("Ghế gỗ sồi tự nhiên", lo))
	twin := activeListing(t, seller.AccessToken, fields("Ghế gỗ sồi tự nhiên cùng mẫu", hi))
	like := url.Values{
		"like": {source.ID}, "price_min": {strconv.FormatInt(lo, 10)}, "price_max": {strconv.FormatInt(hi, 10)},
	}

	res, v := search(t, like, bearer(viewer.AccessToken))
	if res.Status != http.StatusOK || len(v.Items) != 1 || v.Items[0].ID != twin.ID {
		t.Fatalf("the twin and not the source: %d %s", res.Status, res.Body)
	}
	if res, v = search(t, like); res.Status != http.StatusOK || len(v.Items) != 1 {
		t.Fatalf("signed out: %d %s", res.Status, res.Body)
	}
	if res, v = search(t, like, bearer(seller.AccessToken)); res.Status != http.StatusOK || len(v.Items) != 0 {
		t.Fatalf("the seller's own listings stay out: %d %s", res.Status, res.Body)
	}
	withQ := url.Values{"like": {source.ID}, "q": {"ghế gỗ"}, "price_min": like["price_min"], "price_max": like["price_max"]}
	if res, v = search(t, withQ); res.Status != http.StatusOK || len(v.Items) != 1 || v.Items[0].ID != twin.ID {
		t.Fatalf("like with q: %d %s", res.Status, res.Body)
	}
	res, _ = search(t, url.Values{"like": {uuid.NewV7().String()}})
	check(t, "an unknown listing", res, http.StatusNotFound, "listing_not_found")
	hidden := activeHidden(t, seller.AccessToken)
	res, _ = search(t, url.Values{"like": {hidden}})
	check(t, "a hidden listing", res, http.StatusNotFound, "listing_not_found")
}
```

The embed stub's hashed vectors are far below the e2e floors (0.5), so the vector lists stay empty here and `like` is found through BM25 on the source's title and its boosts; the service tests (Step 2) cover the vector lists.

- [ ] **Step 7: Run everything**

Run: `make test`
Expected: PASS, lint included.

- [ ] **Step 8: Commit**

```bash
git add internal/discovery internal/catalog/service internal/app e2e
git commit -m "feat(discovery): search by photo, similar listings and vector lists for q"
```

---

### Task 14: ARCHITECTURE.md

**Files:**
- Modify: `ARCHITECTURE.md`

- [ ] **Step 1: Record the decisions**

- **Infrastructure:** the embedding models run behind the stack's LiteLLM (aliases `embed-text` → TEI with `BAAI/bge-m3`, `embed-image` → `ai`'s SigLIP 2), reached at `EMBED_TEXT_BASE_URL` and `EMBED_IMAGE_BASE_URL`. Locally the server calls TEI and ai directly, on 127.0.0.1:56800 and 56810, from this repo's `docker-compose.yml` under profile `models` (`docker compose --profile models up -d tei ai`); `make run` does not start them, and search runs on BM25 alone until they answer. `/readyz` does not check them.
- **Durable flows:** `ListingEmbed` is the repo's first Virtual Object, keyed by listing ID, exclusive handler `Refresh`. A send queues behind the key's run in progress; that is what coalesces a burst of edits. Each run reads the listing as it is now and embeds what its hashes and keys show missing, a step per photo.
- **Catalog:** vectors in `listing_text_vectors` and `listing_photo_vectors` (migration 0024), the embedding text (`EmbeddingText`), the versions in the `model` column, which statuses are embedded, vectors kept while hidden or sold, and kept when the listing is deleted, since deletion is a status and the row stays (the search's status filter leaves them out), `search-reindex`.
- **Search:** the hybrid query: lists, weights, RRF k 60, floors, the boost list, sorts over the candidate set, `hnsw.iterative_scan = relaxed_order` in the query's transaction, `photo` and `like` rules and errors (`search_conflict` 400, `invalid_upload` 422 as media returns it, `listing_not_found` 404, `search_unavailable` 503), degradation, `rewritten` and `visual` with `PromptVersion` 2.
- **Discovery:** the caches `search_query_vectors` (7 days, keyed by the normalized text that was embedded: the rewrite, the raw query when the model failed, or the visual description) and `search_photo_vectors` (until the upload expires, swept on write), and that no photo or vector reaches a log or the journal.
- **Media:** `QueryUpload`, `QueryImage` (`ShapeQuery`, 768 px, never stored), `ReadPhoto`.
- **Module layout:** catalog and discovery take Settings now; `Mount` signatures.

- [ ] **Step 2: Commit**

```bash
git add ARCHITECTURE.md
git commit -m "docs: hybrid search, ListingEmbed and the vector caches"
```

---

### Task 15: The sample set and `make search-eval`

**Files:**
- Create: `internal/discovery/eval/fixtures.go`, `internal/discovery/eval/metrics.go`
- Create: `internal/discovery/eval/fixtures_test.go`, `internal/discovery/eval/metrics_test.go` (run in `make test`)
- Create: `internal/discovery/eval/eval_test.go` (build tag `eval`)
- Create: `internal/discovery/eval/testdata/listings.json`, `testdata/queries.json`, `testdata/photos/*.jpg`
- Create: `internal/discovery/eval/tools/gen_photos.py`
- Modify: `Makefile`

**Interfaces:**
- Consumes: the real `embed.OpenAI` against TEI and ai from `docker compose --profile models up -d tei ai` (`docker-compose.yml` of this repo, index plan Task 2), the real LLM in `.env`; `catalogtest.Service`, `mediatest`, `accounttest`, `restatetest`, discovery's `service.New` with the Deps of Task 12.
- Produces: `eval.Listing`, `eval.Query`, `eval.Load(dir string) ([]Listing, []Query, error)`, `eval.RecallAt(got, want []string, k int) float64`, `eval.NDCGAt(got, want []string, k int) float64`.

- [ ] **Step 1: Write the failing tests**

`internal/discovery/eval/metrics_test.go`:

```go
package eval_test

import (
	"math"
	"testing"

	"github.com/shopnexus/server2/internal/discovery/eval"
)

func TestRecallAt(t *testing.T) {
	t.Parallel()
	got := []string{"a", "x", "b"}
	for _, tc := range []struct {
		want []string
		k    int
		r    float64
	}{{[]string{"a", "b"}, 10, 1}, {[]string{"a", "b"}, 1, 0.5}, {[]string{"c"}, 10, 0}, {nil, 10, 0}} {
		if r := eval.RecallAt(got, tc.want, tc.k); r != tc.r {
			t.Errorf("RecallAt(%v, %d) = %v, want %v", tc.want, tc.k, r, tc.r)
		}
	}
}

func TestNDCGAt(t *testing.T) {
	t.Parallel()
	// a at rank 1 and b at rank 3: (1 + 1/log2(4)) / (1 + 1/log2(3)).
	want := (1 + 0.5) / (1 + 1/math.Log2(3))
	if n := eval.NDCGAt([]string{"a", "x", "b"}, []string{"a", "b"}, 10); math.Abs(n-want) > 1e-9 {
		t.Fatalf("%v, want %v", n, want)
	}
	if n := eval.NDCGAt([]string{"a", "b"}, []string{"a", "b"}, 10); n != 1 {
		t.Fatalf("perfect order: %v", n)
	}
	if n := eval.NDCGAt(nil, []string{"a"}, 10); n != 0 {
		t.Fatalf("nothing found: %v", n)
	}
}
```

`internal/discovery/eval/fixtures_test.go`:

```go
package eval_test

import (
	"testing"

	"github.com/shopnexus/server2/internal/discovery/eval"
)

// TestSampleSetAgrees keeps the sample set whole: Load checks every key,
// kind and photo file.
func TestSampleSetAgrees(t *testing.T) {
	t.Parallel()
	listings, queries, err := eval.Load("testdata")
	if err != nil {
		t.Fatal(err)
	}
	if len(listings) < 40 || len(queries) < 40 {
		t.Fatalf("%d listings, %d queries; the spec asks about 40 and 40 to 50", len(listings), len(queries))
	}
	kinds := map[string]int{}
	for _, q := range queries {
		kinds[q.Kind]++
	}
	if kinds["q"] == 0 || kinds["photo"] == 0 || kinds["like"] == 0 {
		t.Fatalf("every kind needs queries: %v", kinds)
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/discovery/eval/`
Expected: FAIL, package `eval` has no non-test files.

- [ ] **Step 3: Metrics and fixtures**

`internal/discovery/eval/metrics.go`:

```go
// Package eval measures search on a sample set of listings and queries:
// fixtures.go reads the set, metrics.go scores a page, and eval_test.go,
// under the build tag eval, runs the set against the real models through
// make search-eval. Only the tagged test talks to a model.
package eval

import (
	"math"
	"slices"
)

// RecallAt is the share of want among the first k of got.
func RecallAt(got, want []string, k int) float64 {
	if len(want) == 0 {
		return 0
	}
	top := got[:min(k, len(got))]
	n := 0
	for _, w := range want {
		if slices.Contains(top, w) {
			n++
		}
	}
	return float64(n) / float64(len(want))
}

// NDCGAt is the normalized discounted cumulative gain of the first k of
// got, where a listing of want counts 1 and any other 0.
func NDCGAt(got, want []string, k int) float64 {
	var dcg, ideal float64
	for i, g := range got[:min(k, len(got))] {
		if slices.Contains(want, g) {
			dcg += 1 / math.Log2(float64(i)+2)
		}
	}
	for i := range min(k, len(want)) {
		ideal += 1 / math.Log2(float64(i)+2)
	}
	if ideal == 0 {
		return 0
	}
	return dcg / ideal
}
```

`internal/discovery/eval/fixtures.go`:

```go
package eval

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"slices"

	catalogdomain "github.com/shopnexus/server2/internal/catalog/domain"
)

// Listing is a sample listing; its photo is photos/<Key>.jpg.
type Listing struct {
	Key         string               `json:"key"`
	Title       string               `json:"title"`
	Category    string               `json:"category"`
	Price       int64                `json:"price"`
	Condition   string               `json:"condition"`
	Description string               `json:"description"`
	Specs       []catalogdomain.Spec `json:"specs"`
	// PhotoPrompt is what tools/gen_photos.py asked the image model for.
	PhotoPrompt string `json:"photo_prompt"`
}

// Query is one search of the set and the listings it must find.
type Query struct {
	Name string `json:"name"`
	Kind string `json:"kind"` // q, photo or like
	Q    string `json:"q,omitempty"`
	// Photo is a file under photos/, another shot of the listing Of.
	Photo string `json:"photo,omitempty"`
	Of    string `json:"of,omitempty"`
	// Like is the key of the source listing.
	Like   string   `json:"like,omitempty"`
	Expect []string `json:"expect"`
}

// Load reads dir/listings.json and dir/queries.json and checks that they
// agree: unique keys, a field for each kind, expected and source keys that
// name listings, and every photo file present.
func Load(dir string) ([]Listing, []Query, error) {
	var listings []Listing
	var queries []Query
	for name, out := range map[string]any{"listings.json": &listings, "queries.json": &queries} {
		b, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			return nil, nil, err
		}
		if err = json.Unmarshal(b, out); err != nil {
			return nil, nil, fmt.Errorf("%s: %w", name, err)
		}
	}
	keys := map[string]bool{}
	var errs []error
	photo := func(file string) {
		if _, err := os.Stat(filepath.Join(dir, "photos", file)); err != nil {
			errs = append(errs, fmt.Errorf("photo %s: %w", file, err))
		}
	}
	for _, l := range listings {
		if keys[l.Key] {
			errs = append(errs, fmt.Errorf("listing %q twice", l.Key))
		}
		keys[l.Key] = true
		photo(l.Key + ".jpg")
	}
	names := map[string]bool{}
	for _, q := range queries {
		if names[q.Name] {
			errs = append(errs, fmt.Errorf("query %q twice", q.Name))
		}
		names[q.Name] = true
		switch q.Kind {
		case "q":
			if q.Q == "" {
				errs = append(errs, fmt.Errorf("%s: no q", q.Name))
			}
		case "photo":
			if !keys[q.Of] {
				errs = append(errs, fmt.Errorf("%s: of %q is no listing", q.Name, q.Of))
			}
			photo(q.Photo)
		case "like":
			if !keys[q.Like] {
				errs = append(errs, fmt.Errorf("%s: like %q is no listing", q.Name, q.Like))
			}
			if slices.Contains(q.Expect, q.Like) {
				errs = append(errs, fmt.Errorf("%s: like leaves its source out, so it cannot be expected", q.Name))
			}
		default:
			errs = append(errs, fmt.Errorf("%s: kind %q", q.Name, q.Kind))
		}
		if len(q.Expect) == 0 {
			errs = append(errs, fmt.Errorf("%s: expects nothing", q.Name))
		}
		for _, k := range q.Expect {
			if !keys[k] {
				errs = append(errs, fmt.Errorf("%s: expects %q, no listing", q.Name, k))
			}
		}
	}
	return listings, queries, errors.Join(errs...)
}
```

- [ ] **Step 4: The sample set**

`testdata/listings.json` (42 listings in every root; every listing in commune 00004, taking offers). The near-duplicates are on purpose: two iPhone 13s, two oak and walnut chairs of one model, a children's bicycle that never says "xe đạp", a jacket whose colour is only in its description:

```json
[
{"key":"iphone13","title":"iPhone 13 128GB xanh dương","category":"phones.iphone","price":9500000,"condition":"like_new","description":"Máy zin, pin 89%, không trầy","specs":[{"label":"Màu","value":"Xanh dương"}],"photo_prompt":"a blue iPhone 13 smartphone, back side with two cameras"},
{"key":"iphone13pm","title":"iPhone 13 Pro Max 256GB","category":"phones.iphone","price":15500000,"condition":"used","description":"Màu vàng, pin 85%, viền có vài vết xước nhẹ","specs":[{"label":"Dung lượng","value":"256GB"}],"photo_prompt":"a gold iPhone 13 Pro Max smartphone, back side with three cameras"},
{"key":"iphone11","title":"iPhone 11 64GB trắng","category":"phones.iphone","price":5200000,"condition":"used","description":"Màn zin, Face ID ok","specs":[],"photo_prompt":"a white iPhone 11 smartphone"},
{"key":"galaxy-s22","title":"Samsung Galaxy S22 Ultra đen","category":"phones.android","price":11000000,"condition":"like_new","description":"Kèm bút S Pen, sạc nhanh 45W","specs":[],"photo_prompt":"a black Samsung Galaxy S22 Ultra phone with its S Pen stylus"},
{"key":"ipad-air","title":"iPad Air 5 WiFi 64GB tím","category":"phones.tablet","price":10500000,"condition":"like_new","description":"Mua tháng 3, còn bảo hành","specs":[],"photo_prompt":"a purple iPad Air tablet"},
{"key":"airpods-pro","title":"AirPods Pro 2 hộp sạc USB-C","category":"phones.headphones","price":3900000,"condition":"like_new","description":"Chống ồn tốt, pin còn 100%","specs":[],"photo_prompt":"white AirPods Pro earbuds in their open charging case"},
{"key":"sony-xm4","title":"Sony WH-1000XM4 đen","category":"phones.headphones","price":4200000,"condition":"used","description":"Tai nghe chụp tai chống ồn, đệm tai còn đẹp","specs":[],"photo_prompt":"black Sony over-ear noise cancelling headphones"},
{"key":"apple-watch","title":"Apple Watch Series 8 41mm","category":"phones.watch","price":6000000,"condition":"used","description":"Dây cao su đen, pin 92%","specs":[],"photo_prompt":"an Apple Watch with a black sport band"},
{"key":"case-iphone13","title":"Ốp lưng iPhone 13 trong suốt","category":"phones.accessories","price":80000,"condition":"new","description":"Ốp silicon chống ố vàng","specs":[],"photo_prompt":"a clear transparent silicone phone case"},
{"key":"macbook-air-m1","title":"MacBook Air M1 8GB 256GB","category":"laptop.macbook","price":14500000,"condition":"used","description":"Màu xám, pin 300 lần sạc","specs":[{"label":"RAM","value":"8GB"}],"photo_prompt":"a space grey MacBook Air laptop, open"},
{"key":"macbook-pro-14","title":"MacBook Pro 14 M2 Pro","category":"laptop.macbook","price":32000000,"condition":"like_new","description":"Màn Liquid Retina XDR, sạc 70 lần","specs":[{"label":"RAM","value":"16GB"}],"photo_prompt":"a silver MacBook Pro 14 inch laptop, open"},
{"key":"rog-laptop","title":"Asus ROG Strix G15 RTX 3060","category":"laptop.gaming","price":19000000,"condition":"used","description":"Ryzen 7, màn 144Hz, bàn phím đèn RGB","specs":[],"photo_prompt":"a black gaming laptop with an RGB backlit keyboard"},
{"key":"dell-monitor","title":"Màn hình Dell 27 inch 2K","category":"laptop.monitor","price":4500000,"condition":"used","description":"Tấm nền IPS, chân xoay dọc được","specs":[],"photo_prompt":"a 27 inch Dell computer monitor on a stand"},
{"key":"thinkpad","title":"ThinkPad X1 Carbon Gen 9","category":"laptop.office","price":13000000,"condition":"used","description":"i7, 16GB, máy văn phòng nhẹ 1,1kg","specs":[],"photo_prompt":"a black Lenovo ThinkPad laptop, open"},
{"key":"jacket-green","title":"Áo khoác nam size L","category":"fashion.men","price":450000,"condition":"like_new","description":"Màu xanh rêu, vải kaki, mặc 2 lần","specs":[],"photo_prompt":"a moss-green men's khaki jacket laid flat"},
{"key":"jacket-black","title":"Áo khoác da nam đen size M","category":"fashion.men","price":900000,"condition":"used","description":"Da PU, khoá kéo YKK","specs":[],"photo_prompt":"a black leather men's jacket on a hanger"},
{"key":"dress-red","title":"Đầm dự tiệc size S","category":"fashion.women","price":600000,"condition":"like_new","description":"Màu đỏ, dáng suông, mặc một lần","specs":[],"photo_prompt":"a red cocktail dress on a hanger"},
{"key":"af1","title":"Nike Air Force 1 size 42","category":"fashion.shoes","price":1500000,"condition":"used","description":"Màu trắng, đế còn tốt","specs":[],"photo_prompt":"a pair of white Nike Air Force 1 sneakers"},
{"key":"ultraboost","title":"Adidas Ultraboost đen size 41","category":"fashion.shoes","price":1300000,"condition":"used","description":"Chạy bộ êm chân","specs":[],"photo_prompt":"a pair of black Adidas Ultraboost running shoes"},
{"key":"bag-brown","title":"Túi xách nữ da","category":"fashion.bags","price":700000,"condition":"used","description":"Màu nâu bò, quai đeo vai","specs":[],"photo_prompt":"a brown leather women's handbag"},
{"key":"vision","title":"Honda Vision 2021","category":"vehicles.motorbike","price":26000000,"condition":"used","description":"Màu đỏ, chạy 12.000 km, biển Hà Nội","specs":[],"photo_prompt":"a red Honda Vision scooter, side view"},
{"key":"exciter","title":"Yamaha Exciter 155 xanh GP","category":"vehicles.motorbike","price":38000000,"condition":"used","description":"Xe côn tay, máy êm","specs":[],"photo_prompt":"a blue Yamaha Exciter sport motorbike, side view"},
{"key":"bike-asama","title":"Xe đạp Asama đi làm","category":"vehicles.bicycle","price":1800000,"condition":"used","description":"Khung nhôm, có giỏ trước","specs":[],"photo_prompt":"a city bicycle with a front basket"},
{"key":"bike-kid","title":"Xe cho bé 4 tuổi","category":"vehicles.bicycle","price":900000,"condition":"like_new","description":"Bánh 16 inch có bánh phụ, màu hồng","specs":[],"photo_prompt":"a small pink children's bicycle with training wheels"},
{"key":"bike-road","title":"Giant TCR khung carbon","category":"vehicles.bicycle","price":12000000,"condition":"used","description":"Xe đạp đua, group Shimano 105","specs":[],"photo_prompt":"a carbon road racing bicycle with drop handlebars"},
{"key":"helmet","title":"Mũ bảo hiểm 3/4 Royal đen","category":"vehicles.parts","price":350000,"condition":"like_new","description":"Size L, kính chắn gió","specs":[],"photo_prompt":"a black open-face motorcycle helmet with a visor"},
{"key":"sofa-grey","title":"Sofa băng 3 chỗ","category":"furniture.sofa","price":3500000,"condition":"used","description":"Bọc nỉ màu xám, khung gỗ","specs":[],"photo_prompt":"a grey fabric three-seat sofa"},
{"key":"desk-oak","title":"Bàn làm việc gỗ sồi 1m2","category":"furniture.table","price":1600000,"condition":"used","description":"Chân sắt sơn tĩnh điện","specs":[],"photo_prompt":"an oak wood desk with black metal legs"},
{"key":"chair-oak","title":"Ghế gỗ sồi tự nhiên","category":"furniture.other","price":450000,"condition":"used","description":"Ghế tựa lưng nan dọc, màu gỗ sáng","specs":[],"photo_prompt":"a light oak wooden dining chair with vertical back slats"},
{"key":"chair-walnut","title":"Ghế gỗ óc chó lưng nan","category":"furniture.other","price":500000,"condition":"used","description":"Cùng mẫu ghế tựa nan dọc, màu gỗ tối","specs":[],"photo_prompt":"a dark walnut wooden dining chair with vertical back slats"},
{"key":"lamp-desk","title":"Đèn bàn học LED","category":"furniture.lighting","price":250000,"condition":"like_new","description":"3 chế độ sáng, cổ gập","specs":[],"photo_prompt":"a white LED desk lamp with a folding neck"},
{"key":"shelf","title":"Kệ sách 5 tầng","category":"furniture.storage","price":700000,"condition":"used","description":"Gỗ MDF màu trắng","specs":[],"photo_prompt":"a white five-tier bookshelf"},
{"key":"rice-cooker","title":"Nồi cơm điện Toshiba 1.8L","category":"home.kitchen","price":600000,"condition":"used","description":"Lòng nồi chống dính còn tốt","specs":[],"photo_prompt":"a white Toshiba electric rice cooker"},
{"key":"air-fryer","title":"Nồi chiên không dầu Philips","category":"home.kitchen","price":1200000,"condition":"like_new","description":"Dung tích 4,1L, dùng 3 tháng","specs":[],"photo_prompt":"a black Philips air fryer"},
{"key":"washer","title":"Máy giặt LG 9kg cửa trước","category":"home.washer","price":4500000,"condition":"used","description":"Inverter, chạy êm","specs":[],"photo_prompt":"a white front-loading washing machine"},
{"key":"fan","title":"Quạt đứng Panasonic","category":"home.fan","price":500000,"condition":"used","description":"5 cánh, có điều khiển","specs":[],"photo_prompt":"a white standing electric fan"},
{"key":"stroller","title":"Xe đẩy em bé Joie gấp gọn","category":"baby.stroller","price":1500000,"condition":"used","description":"Ngả 3 tư thế, có mái che","specs":[],"photo_prompt":"a grey foldable baby stroller with a canopy"},
{"key":"lego","title":"Lego City cảnh sát 60316","category":"baby.toys","price":650000,"condition":"like_new","description":"Đủ mảnh, còn hộp","specs":[],"photo_prompt":"a Lego City police station set built, with its box"},
{"key":"highchair","title":"Ghế ăn dặm cho bé","category":"baby.highchair","price":400000,"condition":"used","description":"Có khay tháo rời, gấp gọn","specs":[],"photo_prompt":"a white baby high chair with a tray"},
{"key":"racket","title":"Vợt Yonex Astrox 88D","category":"sports.racket","price":1800000,"condition":"used","description":"Vợt cầu lông 4U, căng 11kg","specs":[],"photo_prompt":"a badminton racket"},
{"key":"dumbbell","title":"Tạ tay 10kg (cặp)","category":"sports.gym","price":500000,"condition":"used","description":"Tạ bọc cao su","specs":[],"photo_prompt":"a pair of black rubber hex dumbbells"},
{"key":"tent","title":"Lều cắm trại 4 người","category":"sports.camping","price":900000,"condition":"like_new","description":"Chống mưa, dựng trong 5 phút","specs":[],"photo_prompt":"a green dome camping tent pitched on grass"}
]
```

`testdata/queries.json` (46 queries: 30 `q`, 10 `photo`, 6 `like`):

```json
[
{"name":"typo ip13 pm","kind":"q","q":"ip13 pm","expect":["iphone13pm"]},
{"name":"short ip 13","kind":"q","q":"ip 13","expect":["iphone13","iphone13pm"]},
{"name":"typo mac air m1","kind":"q","q":"mac air m1","expect":["macbook-air-m1"]},
{"name":"typo samsum s22","kind":"q","q":"samsum s22","expect":["galaxy-s22"]},
{"name":"no diacritics sony","kind":"q","q":"tai nghe chong on sony","expect":["sony-xm4"]},
{"name":"synonym kid bicycle","kind":"q","q":"xe đạp trẻ em","expect":["bike-kid"]},
{"name":"synonym for a child","kind":"q","q":"xe cho bé","expect":["bike-kid"]},
{"name":"synonym air fryer","kind":"q","q":"noi chien","expect":["air-fryer"]},
{"name":"synonym gaming laptop","kind":"q","q":"may tinh xach tay choi game","expect":["rog-laptop"]},
{"name":"synonym smart watch","kind":"q","q":"dong ho thong minh","expect":["apple-watch"]},
{"name":"synonym building toy","kind":"q","q":"do choi xep hinh","expect":["lego"]},
{"name":"synonym feeding chair","kind":"q","q":"ghe cho be an","expect":["highchair"]},
{"name":"synonym road bike","kind":"q","q":"xe đạp đua","expect":["bike-road"]},
{"name":"looks moss green jacket","kind":"q","q":"áo khoác xanh rêu","expect":["jacket-green"]},
{"name":"looks white shoes","kind":"q","q":"giày trắng","expect":["af1"]},
{"name":"looks red dress","kind":"q","q":"đầm đỏ","expect":["dress-red"]},
{"name":"looks grey sofa","kind":"q","q":"sofa màu xám","expect":["sofa-grey"]},
{"name":"looks red scooter","kind":"q","q":"xe máy màu đỏ","expect":["vision"]},
{"name":"looks brown bag","kind":"q","q":"túi da nâu","expect":["bag-brown"]},
{"name":"looks gold iphone","kind":"q","q":"iphone màu vàng","expect":["iphone13pm"]},
{"name":"looks pink bike","kind":"q","q":"xe đạp hồng","expect":["bike-kid"]},
{"name":"plain washer","kind":"q","q":"may giat","expect":["washer"]},
{"name":"plain tent","kind":"q","q":"lều","expect":["tent"]},
{"name":"plain fan","kind":"q","q":"quạt","expect":["fan"]},
{"name":"plain bookshelf","kind":"q","q":"kệ sách","expect":["shelf"]},
{"name":"plain badminton","kind":"q","q":"vợt cầu lông","expect":["racket"]},
{"name":"plain monitor","kind":"q","q":"màn hình 2k","expect":["dell-monitor"]},
{"name":"plain helmet","kind":"q","q":"mu bao hiem","expect":["helmet"]},
{"name":"plain rice cooker","kind":"q","q":"noi com","expect":["rice-cooker"]},
{"name":"plain wooden table","kind":"q","q":"ban go","expect":["desk-oak"]},
{"name":"photo gold iphone","kind":"photo","photo":"q-iphone13pm.jpg","of":"iphone13pm","expect":["iphone13pm"]},
{"name":"photo green jacket","kind":"photo","photo":"q-jacket-green.jpg","of":"jacket-green","expect":["jacket-green"]},
{"name":"photo white sneakers","kind":"photo","photo":"q-af1.jpg","of":"af1","expect":["af1"]},
{"name":"photo oak chair","kind":"photo","photo":"q-chair-oak.jpg","of":"chair-oak","expect":["chair-oak","chair-walnut"]},
{"name":"photo grey sofa","kind":"photo","photo":"q-sofa-grey.jpg","of":"sofa-grey","expect":["sofa-grey"]},
{"name":"photo kid bike","kind":"photo","photo":"q-bike-kid.jpg","of":"bike-kid","expect":["bike-kid"]},
{"name":"photo red scooter","kind":"photo","photo":"q-vision.jpg","of":"vision","expect":["vision"]},
{"name":"photo lego","kind":"photo","photo":"q-lego.jpg","of":"lego","expect":["lego"]},
{"name":"photo air fryer","kind":"photo","photo":"q-air-fryer.jpg","of":"air-fryer","expect":["air-fryer"]},
{"name":"photo headphones","kind":"photo","photo":"q-sony-xm4.jpg","of":"sony-xm4","expect":["sony-xm4"]},
{"name":"like iphone 13","kind":"like","like":"iphone13","expect":["iphone13pm","iphone11"]},
{"name":"like oak chair","kind":"like","like":"chair-oak","expect":["chair-walnut"]},
{"name":"like white sneakers","kind":"like","like":"af1","expect":["ultraboost"]},
{"name":"like macbook air","kind":"like","like":"macbook-air-m1","expect":["macbook-pro-14"]},
{"name":"like scooter","kind":"like","like":"vision","expect":["exciter"]},
{"name":"like green jacket","kind":"like","like":"jacket-green","expect":["jacket-black"]}
]
```

- [ ] **Step 5: Generate the photos**

The app's fixture photos come from Unsplash, whose licence does not allow compiling its photos into a dataset for a similar service, so the set is generated. `internal/discovery/eval/tools/gen_photos.py` (needs Pillow; reads the key from `~/.config/cliproxyapi-remote.key` and never prints it):

```python
"""Generates the eval photos with gpt-image-2.5 on the proxy: photos/<key>.jpg
for each listing from its photo_prompt, and for each photo query its file, a
second shot of the listing it names made with /v1/images/edits. A file that
exists is kept. Run from the server repo:
    python3 internal/discovery/eval/tools/gen_photos.py
"""
import base64
import io
import json
import pathlib
import urllib.request
import uuid

from PIL import Image

DATA = pathlib.Path(__file__).resolve().parent.parent / "testdata"
API = "http://khoakomlem-internal.ddns.net:8317/v1/images"
KEY = (pathlib.Path.home() / ".config/cliproxyapi-remote.key").read_text().strip()
STYLE = ", a phone photo for a second-hand listing, the whole item in view, plain background, no text, no people"
AGAIN = "the same item photographed again by its owner, from another angle, in other light, on another background"


def save(b64, path):
    img = Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGB")
    img.thumbnail((768, 768))
    img.save(path, "JPEG", quality=85)


def post(path, body, content_type):
    req = urllib.request.Request(API + path, body, {"Authorization": "Bearer " + KEY, "Content-Type": content_type})
    with urllib.request.urlopen(req, timeout=600) as res:
        return json.load(res)["data"][0]["b64_json"]


def generate(prompt):
    body = json.dumps({"model": "gpt-image-2.5", "prompt": prompt + STYLE, "size": "1024x1024", "n": 1}).encode()
    return post("/generations", body, "application/json")


def edit(photo, prompt):
    boundary = uuid.uuid4().hex
    parts = []
    for name, value in (("model", "gpt-image-2.5"), ("prompt", prompt), ("size", "1024x1024"), ("n", "1")):
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    parts.append(
        f'--{boundary}\r\nContent-Disposition: form-data; name="image[]"; filename="{photo.name}"\r\n'
        "Content-Type: image/jpeg\r\n\r\n".encode() + photo.read_bytes() + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode())
    return post("/edits", b"".join(parts), "multipart/form-data; boundary=" + boundary)


def main():
    photos = DATA / "photos"
    photos.mkdir(exist_ok=True)
    for listing in json.loads((DATA / "listings.json").read_text()):
        out = photos / (listing["key"] + ".jpg")
        if not out.exists():
            save(generate(listing["photo_prompt"]), out)
            print("made", out.name)
    for query in json.loads((DATA / "queries.json").read_text()):
        if query["kind"] != "photo":
            continue
        out = photos / query["photo"]
        if not out.exists():
            save(edit(photos / (query["of"] + ".jpg"), AGAIN), out)
            print("made", out.name)


if __name__ == "__main__":
    main()
```

Run it, look at every photo (a generated photo that shows the wrong item spoils its queries; delete it and run again), then:

Run: `go test ./internal/discovery/eval/ -v`
Expected: PASS, `TestSampleSetAgrees`, `TestRecallAt`, `TestNDCGAt`.

- [ ] **Step 6: The harness**

`internal/discovery/eval/eval_test.go`:

```go
//go:build eval

package eval_test

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"text/tabwriter"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/account/accounttest"
	"github.com/shopnexus/server2/internal/catalog/catalogtest"
	catalogdomain "github.com/shopnexus/server2/internal/catalog/domain"
	catalogrepo "github.com/shopnexus/server2/internal/catalog/repository"
	catalogsvc "github.com/shopnexus/server2/internal/catalog/service"
	discoverydomain "github.com/shopnexus/server2/internal/discovery/domain"
	"github.com/shopnexus/server2/internal/discovery/eval"
	"github.com/shopnexus/server2/internal/discovery/repository"
	"github.com/shopnexus/server2/internal/discovery/service"
	"github.com/shopnexus/server2/internal/media/mediatest"
	"github.com/shopnexus/server2/internal/platform/config"
	"github.com/shopnexus/server2/internal/platform/objectstore/objectstoretest"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server2/internal/platform/restatex/restatetest"
	"github.com/shopnexus/server2/internal/platform/testenv"
	"github.com/shopnexus/server2/internal/provider/embed"
	"github.com/shopnexus/server2/internal/provider/llm"
)

// k is the depth the set is scored at.
const k = 10

type result struct {
	q            eval.Query
	got          []string
	recall, ndcg float64
}

// TestSearchEval posts the sample listings through catalog with the real
// models, waits until ListingEmbed has given each its vectors, runs every
// query through discovery and prints recall@10 and nDCG@10. It fails on
// errors, never on scores: the scores are for tuning the RRF weights and the
// floors.
func TestSearchEval(t *testing.T) { //nolint:paralleltest // one run, against shared real models
	cfg, err := config.FromDotEnv("../../../.env")
	if err != nil {
		t.Fatalf("the developer's .env, with LLM_* and EMBED_* for real models: %v", err)
	}
	listings, queries, err := eval.Load("testdata")
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	db := pgtest.New(t)
	in, p := restatetest.Ingress(t), restatetest.Prefix()
	m := mediatest.Service(db, objectstoretest.New(t), in, p)
	model := func(base, name, key string, dims int) embed.OpenAI {
		return embed.OpenAI{BaseURL: base, APIKey: key, Model: name, Dims: dims, HTTP: &http.Client{Timeout: cfg.Embed.Timeout}}
	}
	log := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelWarn}))
	c := catalogtest.Service(db, accounttest.Service(db), m, in, p, func(d *catalogsvc.Deps) {
		d.Text = model(cfg.Embed.TextBaseURL, cfg.Embed.TextModel, cfg.Embed.IndexAPIKey, catalogdomain.TextDims)
		d.Image = model(cfg.Embed.ImageBaseURL, cfg.Embed.ImageModel, cfg.Embed.IndexAPIKey, catalogdomain.PhotoDims)
		d.TextVersion, d.ImageVersion, d.EmbedSlots, d.Log = cfg.Embed.TextVersion, cfg.Embed.ImageVersion, cfg.Embed.Slots, log
	})
	restatetest.Start(t, append(m.Durable(), c.Durable()...)...)
	d := service.New(service.Deps{
		Saves: repository.NewSaves(db), Understandings: repository.NewUnderstandings(db),
		QueryVectors: repository.NewQueryVectors(db), PhotoVectors: repository.NewPhotoVectors(db),
		Catalog: c, Media: m,
		LLM:  llm.OpenAI{BaseURL: cfg.LLM.BaseURL, APIKey: cfg.LLM.APIKey, Model: cfg.LLM.Model, HTTP: &http.Client{}},
		Text: model(cfg.Embed.TextBaseURL, cfg.Embed.TextModel, cfg.Embed.SearchAPIKey, catalogdomain.TextDims),
		Image: model(cfg.Embed.ImageBaseURL, cfg.Embed.ImageModel, cfg.Embed.SearchAPIKey, catalogdomain.PhotoDims),
		TextVersion: cfg.Embed.TextVersion, ImageVersion: cfg.Embed.ImageVersion,
		TextMin: cfg.Embed.TextMinSimilarity, PhotoMin: cfg.Embed.PhotoMinSimilarity,
		ModelTimeout: discoverydomain.ModelTimeout, Log: log, Now: time.Now,
	})

	ids := map[string]uuid.UUID{}
	keys := map[uuid.UUID]string{}
	for _, l := range listings {
		seller := accounttest.WithPhone(t, db)
		photo := mediatest.Upload(t, m, seller, "image/jpeg", read(t, l.Key+".jpg"))
		v, postErr := c.Post(ctx, seller, uuid.NewV7().String(), catalogdomain.Draft{
			Title: l.Title, Price: l.Price, Description: l.Description, CategoryCode: l.Category,
			Condition: catalogdomain.Condition(l.Condition), AllowOffers: true, CommuneCode: "00004",
			Photos: []uuid.UUID{photo}, Specs: l.Specs,
		})
		if postErr != nil {
			t.Fatalf("post %s: %v", l.Key, postErr)
		}
		ids[l.Key], keys[v.ID] = v.ID, l.Key
	}
	vectors := catalogrepo.NewVectors(db)
	started := time.Now()
	testenv.Eventually(t, 20*time.Minute, func() error {
		for key, id := range ids {
			st, stateErr := vectors.State(ctx, id, cfg.Embed.TextVersion, cfg.Embed.ImageVersion)
			if stateErr != nil {
				return stateErr
			}
			if st.TextHash == nil || len(st.Photos) == 0 {
				return fmt.Errorf("%s has no vectors yet; are tei and ai up?", key)
			}
		}
		return nil
	})
	t.Logf("%d listings embedded in %s", len(ids), time.Since(started).Round(time.Second))

	viewer := accounttest.WithPhone(t, db)
	results := make([]result, 0, len(queries))
	for _, q := range queries {
		input := service.SearchInput{Limit: k}
		var who *uuid.UUID
		switch q.Kind {
		case "q":
			input.Query = q.Q
		case "photo":
			input.Photo, who = mediatest.Upload(t, m, viewer, "image/jpeg", read(t, q.Photo)), &viewer
		case "like":
			input.Like = ids[q.Like]
		}
		v, searchErr := d.Search(ctx, who, input)
		if searchErr != nil {
			t.Fatalf("%s: %v", q.Name, searchErr)
		}
		got := make([]string, len(v.Items))
		for i, it := range v.Items {
			got[i] = keys[it.ID]
		}
		results = append(results, result{q: q, got: got, recall: eval.RecallAt(got, q.Expect, k), ndcg: eval.NDCGAt(got, q.Expect, k)})
	}

	report := table(results)
	t.Log("\n" + report)
	out := filepath.Join("..", "..", "..", "tmp", "search-eval-"+time.Now().UTC().Format("20060102T150405Z")+".txt")
	if err = os.MkdirAll(filepath.Dir(out), 0o755); err == nil {
		err = os.WriteFile(out, []byte(report), 0o644)
	}
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("written to %s", out)
}

// table is one line per query, then the mean recall and nDCG of each kind
// and of all queries.
func table(rs []result) string {
	var b strings.Builder
	w := tabwriter.NewWriter(&b, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "kind\tquery\trecall@10\tnDCG@10\texpected\tfound")
	type sum struct {
		n            int
		recall, ndcg float64
	}
	sums := map[string]*sum{"all": {}}
	for _, r := range rs {
		fmt.Fprintf(w, "%s\t%s\t%.2f\t%.2f\t%s\t%s\n", r.q.Kind, r.q.Name, r.recall, r.ndcg,
			strings.Join(r.q.Expect, " "), strings.Join(r.got, " "))
		if sums[r.q.Kind] == nil {
			sums[r.q.Kind] = &sum{}
		}
		for _, s := range []*sum{sums[r.q.Kind], sums["all"]} {
			s.n++
			s.recall += r.recall
			s.ndcg += r.ndcg
		}
	}
	fmt.Fprintln(w, "\t\t\t\t\t")
	for _, kind := range []string{"q", "photo", "like", "all"} {
		if s := sums[kind]; s != nil && s.n > 0 {
			fmt.Fprintf(w, "%s\tmean of %d\t%.3f\t%.3f\t\t\n", kind, s.n, s.recall/float64(s.n), s.ndcg/float64(s.n))
		}
	}
	_ = w.Flush()
	return b.String()
}

func read(t *testing.T, file string) []byte {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("testdata", "photos", file))
	if err != nil {
		t.Fatal(err)
	}
	return b
}
```

(`catalog.Post` returns once the listing is inserted; `ListingPublish` processes the photo and `ListingEmbed` follows, which the wait covers. If `catalogtest.Service` sets `Log` before the change functions run, the line setting `d.Log` may be dropped.)

- [ ] **Step 7: The make target**

In the `Makefile`, add `search-eval` to `.PHONY` and:

```make
# Runs the search sample set (internal/discovery/eval) against the real
# models: TEI and ai from this repo's docker-compose.yml, profile models, and
# the LLM in .env. Not part of make test. It prints recall@10 and nDCG@10 per
# query and per kind, and writes them to tmp/.
search-eval: env
	docker compose --profile models up -d tei ai
	@until curl -sf http://127.0.0.1:56800/health >/dev/null && curl -sf http://127.0.0.1:56810/readyz >/dev/null; do sleep 2; done
	$(TEST_STACK) up -d --wait
	$(TEST_STACK) up -d --wait --force-recreate restate
	@until curl -sf http://127.0.0.1:56571/health >/dev/null; do sleep 0.5; done
	go test -tags eval -run TestSearchEval -count=1 -v -timeout 60m ./internal/discovery/eval/
```

Run `make depguard` too: the package `eval` is new under `internal/discovery`. If the generator takes it for a layer and writes rules that refuse its imports, give it the rules of a test-support package (it is imported only by its own tests).

- [ ] **Step 8: Run it once and record the baseline**

Run: `make search-eval`
Expected: the table, and its file under `tmp/`. Copy the mean lines into ARCHITECTURE.md's Search section as the baseline the starting weights and floors gave, with the date and the two `EMBED_*_VERSION` values.

- [ ] **Step 9: Commit**

```bash
git add internal/discovery/eval Makefile ARCHITECTURE.md .golangci.yml
git commit -m "test: the search sample set and make search-eval"
```

## Self-Review

**Spec coverage.** API (Task 1, 12), migration (3), versions in `model` (6, 8), `ListingEmbed` steps, slots, sends, reindex (8, 13), understanding fields and prompt version (10), query photo path and cache (7, 11, 12), retrieval lists, boost list, weights, floors, sorts, single statement (9), degradation (12), configuration (2), testing as the spec lists (4, 6–12), eval (15), ARCHITECTURE (14). The embedder service itself, TEI, aliases and keys are plans 1 and 2.

**Placeholder scan.** None left: Task 12 Step 6 holds the e2e tests on the package's own helpers, and Task 15 the fixtures, the metrics with their tests, the harness, the photo generator and the make target.

**Type consistency.** `embed.Model.Embed(ctx, []string) ([][]float32, error)` throughout; `repository.Vectors` methods as Task 6 defines them; `ListingEmbedName` in Tasks 8 and 13; `domain.Weights`/`Vectors` field names in Tasks 5, 9 and 12; versions `"text-test"` and `"image-test"` in every test.

**Review Focus.** Each line has its test: 1 in Tasks 7 and 12 (`TestQueryUpload`, `TestSearchByPhotoRefuses`), 2 in `TestSearchLike`, 3 in `TestHybridPagesWithoutGapsOrRepeats`, 4 in `TestHybridFiltersEveryList`, 5 in `TestEmbedRefusesBadReplies`.
