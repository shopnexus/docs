# Listing drafts on the server: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A seller's listing drafts live on the server under `/v1/listing-drafts` (PUT to create or replace, the last write winning; GET of every draft in full; DELETE), at most 20 per account, deleted lazily 30 days after their last write, with photos that outlive the 24-hour upload expiry because each PUT extends it to 30 days; an erased account's drafts go.

**Architecture:** Module `catalog` gets the entity `domain.ListingDraft`, the table `listing_drafts`, the repository `Drafts` and three plain use cases; a PUT asks media which photos are gone, extends the rest with `media.Extend`, then writes the row in one catalog transaction under the per-account advisory lock and a share lock on the account's row. Media and catalog share no transaction, and nothing is held or released. Module `media` gets `uploads.expires_at`, `Extend` and `Gone`, and `MediaExpire` sends itself again while `expires_at` is ahead. Today's request schema `ListingDraft` becomes `ListingInput`, and Go's `domain.Draft` becomes `domain.ListingInput`.

**Tech Stack:** Go 1.27, Restate Go SDK v1.1.0 (`MediaExpire` only), pgx v5, Postgres 18, kin-openapi v0.151.0 request validation, minio-go presigned GETs.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-13-listing-drafts-sync-design.md` (sections "Decisions", "Server", and "Testing" for the server). The "App" section is another plan's; this plan only keeps its names.

## Global Constraints

- Repos: `~/shopnexus/server` (Go module `github.com/shopnexus/server2`), the umbrella `~/shopnexus` (`checklist.md`) and `~/shopnexus/docs` (this plan and the spec). Work on branch `feat/listing-drafts` in each repo touched, never on `main`. Other sessions commit to server `main`, so create the server branch in a git worktree (superpowers:using-git-worktrees, under `server/.worktrees/listing-drafts`) and rebase on `main` before the final review.
- Read `server/CLAUDE.md` and `server/ARCHITECTURE.md` (sections Use cases, HTTP handlers, Transactions and concurrency, Tables and aggregates, Media, Catalog, Erasure, Testing, Linting) before the first task.
- Names shared with the app plan, exactly: error codes `draft_not_found`, `draft_limit_reached`, `invalid_upload`; 20 drafts per account; a draft lives 30 days after its last write; JSON fields `schema_version`, `title`, `price`, `photos`, `body` (a string), `updated_at`, `expires_at`, photo `upload_id` and `url`.
- Decisions copied from the spec, not to be reopened: the app mints the draft ID (a UUIDv7); the last write wins, with no revision and no conflict answer; the server reads `title` (0 to 100 characters), `price` (VND, ≥ 0, or null) and `photos` (0 to 10 upload IDs, in order) and keeps `body` (a string of at most 32,768 characters) with `schema_version` (≥ 1) without reading it; expired drafts are deleted lazily by the account's next GET or PUT, with no job and no notice; each PUT extends its photos' upload expiry to now + 30 days and nothing shortens it, so a photo dropped from a draft or of a deleted draft stays in the private `uploads/` until its own expiry; photo URLs are `PresignPhoto`, valid one hour; `POST /v1/listings` does not change (the app deletes the draft after a post); erasure deletes the drafts.
- Vietnamese copy spells "Xóa"/"xóa".
- Shape rules live only in the spec: the request validator (`httpx.ValidateRequests`) answers 400 `invalid_request` for a field past its schema (a title over 100, a body over 32,768 characters), an unknown field, a missing field or a wrong type.
- Every route in `api/openapi.yaml` has a handler and the reverse (`internal/app/routes_test.go`); every documented status of every operation is observed by `e2e/` (`uncovered()` in `e2e/main_test.go`); e2e validates every response against the spec.
- Use cases and HTTP handlers read top to bottom; no single-use helpers. Helpers with several callers: `Catalog.draftView` (`PutDraft`, `ListDrafts`), `Media.checkStored` (`attachAs`, `Extend`), `deleteExpired` in the store (`Put`, `List`).
- Configuration: this plan adds no variable.
- Migrations: the last is `0040_order_flow.sql`. This plan adds `0041_upload_expiry.sql` (Task 2) and `0042_listing_drafts.sql` (Task 3). If a number is taken when the work starts, take the next free one and say so in the commit. Both only add, so the replicas of the release before keep working while they run: `uploads.expires_at` has a default of `now() + 24 hours` for their inserts, which is when their uploads expire anyway.
- Commits: no `Co-Authored-By` trailer in any shopnexus repo. Prefixes as in `git log`: `feat(catalog): …`, `feat(media): …`, `docs: …` in server; `build: …` in the umbrella; `spec(drafts): …` in docs.
- Prose in code comments, `ARCHITECTURE.md`, API descriptions and commit messages goes through the `humanizing-writing` skill's checker: `python3 ~/.claude/skills/humanizing-writing/ai-tells.py FILE` (for a commit message, write it to `tmp/msg.txt` in the worktree first and commit with `git commit -F tmp/msg.txt`).
- Server tests: `make test` once (starts the test stack, runs everything and `golangci-lint run`); then `go test ./internal/<module>/...`, `go test ./migrations/` and `go test ./e2e/ -run <Name>` while working. Long output goes to `tmp/` in the worktree, never `/tmp`. Do not poll processes in loops; after the last `make test`, check `ps` for leftover `go test` processes before saying done.
- The build is red between tasks in one place only: Task 1 adds the draft routes to `api/`, so `internal/app`'s `TestRoutesMatchSpec` and every e2e test (the coverage check in `TestMain`) fail until Task 4. `go build ./...` passes after every task, and `make test` passes again at the end of Task 4.

## Review Focus

1. The seller adds a photo, the phone goes offline for two days, then the draft syncs: the upload is past its `expires_at`, but `MediaExpire` has not run yet, so the row still says `waiting`. `Gone` must count it, and the PUT must drop the photo and sync the rest, not answer 422 `invalid_upload` and leave the draft unsynced for good. Task 4 `TestPutDraftDropsGonePhotos` (the `stale` photo).
2. A seller with 20 drafts edits one of them: a replace must never meet the limit, which only a create counts. Task 3 `TestCheckPut` ("replace at the limit") and `TestTwoCreatesAtNineteen` (its last PUT), Task 4 `TestPutDraftRefusals`.
3. A seller whose 20 drafts all passed their 30 days creates a new one, and the phone sends again a draft the server already let expire: both are accepted as creates (201), because the expired drafts go in the same transaction before the count. Task 3 `TestExpiredDraftsGo`, Task 4 `TestExpiredDraftsFreeTheirPlaces`.
4. A photo two PUTs extended ten days apart: the `MediaExpire` run that the first extension's moment woke must find the later expiry and wait for it, not delete a photo the draft still shows. Task 2 `TestExtendedTwiceWaitsForTheLater`.
5. A listing takes one of a draft's photos after the PUT (the seller posted another listing with it): GET must leave the photo out of its answer and write nothing, so the draft keeps its `updated_at` and `expires_at` and a GET never keeps a draft alive. Task 4 `TestListDraftsLeavesTakenPhotosOut`.

## Deviations from the spec

Task 5 records these in the spec and in `ARCHITECTURE.md`:

- `photos` in a PUT keeps a repeated ID once instead of refusing it: a sync refused for a draft's content would leave the app's draft unsynced for good.
- `PUT` can also answer 409 `try_again`, when media's save of the extension collides with another write of the same upload (a listing attaching it, `MediaExpire`); the app sends the PUT again. The spec lists 409 only for the limit.
- `MediaExpire`, finding `expires_at` still ahead, sends itself again with the idempotency key `<upload id>/<expires_at in Unix seconds>`, since the upload ID keyed the first run; a second wake for the same moment sends nothing more. The spec does not name the key.
- A suspended account may still write its drafts; only the tombstone refuses (`session_revoked`), as for addresses. The spec is silent.
- Renames beyond the schema: Go `domain.Draft` becomes `domain.ListingInput`, the flows' `PostInput.Draft` and `EditInput.Draft` become `.Listing` (JSON `listing`), handler `draftBody` becomes `listingBody` in `listing_input.go`; the new entity is `domain.ListingDraft`. Restate's operator keeps the old version for invocations in flight, so the JSON key may change.
- Erasure deletes the drafts inside `Catalog.SellerLeft`, which catalog's `account.deleted` worker already calls; the worker does not change.

## File map

server (`~/shopnexus/server`):

| File | Responsibility | Task |
|---|---|---|
| `api/openapi.yaml`, `api/paths/catalog.yaml`, `api/schemas/catalog.yaml`, `api/schemas/assist.yaml`, `api/spec_test.go` | the contract | 1 |
| `internal/catalog/domain/listing.go`, `embedding.go`, `price.go`, `internal/catalog/handler/listing_input.go` (was `draft.go`), `listing_post.go`, `listing_update.go`, `internal/catalog/service/*.go`, `internal/catalog/catalogtest/catalogtest.go`, `internal/assist/service/estimate.go`, and the tests that name `Draft` | `ListingInput` | 1 |
| `migrations/0041_upload_expiry.sql`, `migrations/upload_expiry_test.go` | `uploads.expires_at` | 2 |
| `internal/media/domain/upload.go`, `upload_test.go`, `internal/media/repository/upload_pg.go`, `upload_pg_test.go`, `internal/media/service/service.go`, `upload_attach.go`, `upload_extend.go`, `media_expire_durable.go`, `helpers_test.go`, `upload_extend_test.go` | `Extend`, `Gone`, the expiry; the existing expiry tests run on a stopped clock | 2 |
| `migrations/0042_listing_drafts.sql`, `migrations/listing_drafts_test.go` | `listing_drafts` | 3 |
| `internal/catalog/domain/listing_draft.go`, `listing_draft_test.go`, `errors.go`, `internal/catalog/repository/repository.go`, `draft_pg.go`, `draft_pg_test.go` | `ListingDraft`, `Drafts` | 3 |
| `internal/catalog/service/listing_draft.go`, `listing_draft_test.go`, `views.go`, `service.go`, `seller_left.go`, `helpers_test.go`, `internal/catalog/catalog.go`, `internal/catalog/catalogtest/catalogtest.go`, `internal/catalog/worker/account.go` (comment) | the use cases, erasure | 4 |
| `internal/catalog/handler/handler.go`, `listing_draft.go`, `e2e/listing_draft_test.go` | routes, end to end | 4 |
| `ARCHITECTURE.md` | decisions | 5 |

umbrella (`~/shopnexus`) and docs (`~/shopnexus/docs`):

| File | Responsibility | Task |
|---|---|---|
| `checklist.md` | the tick | 5 |
| `docs/superpowers/specs/2026-11-13-listing-drafts-sync-design.md` | the deviations | 5 |

## Task order and interfaces

Tasks 1, 2 and 3 are independent of each other. Task 4 needs all three. Task 5 comes last.

Names later tasks rely on:

- API: operations `listListingDrafts` (`GET /v1/listing-drafts`), `putListingDraft` and `deleteListingDraft` (`/v1/listing-drafts/{id}`); schemas `ListingInput` (was `ListingDraft`), `ListingDraftInput`, `ListingDraftPhoto`, `ListingDraft`, `ListingDraftList`.
- Media: `mediadomain.ExtendFor = 30 * 24 * time.Hour`; `(*Upload) Extend(owner uuid.UUID, now time.Time) error`, `(*Upload) Gone(owner uuid.UUID, now time.Time) bool`, `(*Upload) ExpiresAt()` reads the stored `expires_at`; `mediasvc.Service`: `Extend(ctx, owner uuid.UUID, ids []uuid.UUID) error`, `Gone(ctx, owner uuid.UUID, ids []uuid.UUID) ([]uuid.UUID, error)`.
- Catalog domain: `domain.ListingInput` (was `Draft`); `domain.MaxDrafts = 20`, `domain.DraftLife = 30 * 24 * time.Hour`; `domain.DraftContent{SchemaVersion int; Title string; Price *int64; Photos []uuid.UUID; Body string}`; `domain.ListingDraft` with `NewListingDraft`, `Replace`, `ID`, `AccountID`, `Content`, `Photos`, `CreatedAt`, `UpdatedAt`, `ExpiresAt`, `State`, `RestoreListingDraft`; `domain.CheckPut(stored *ListingDraft, account uuid.UUID, count int) error`; `domain.KeepPhotos(photos, gone []uuid.UUID) []uuid.UUID`; `domain.ErrDraftNotFound`, `domain.ErrDraftLimitReached`.
- Catalog repository: `repository.Drafts` with `Put(ctx, account, id uuid.UUID, c domain.DraftContent, now time.Time) (domain.ListingDraft, bool, error)`, `List(ctx, account uuid.UUID, now time.Time) ([]domain.ListingDraft, error)`, `Delete(ctx, account, id uuid.UUID) error`, `DeleteAll(ctx, account uuid.UUID) error`; `repository.NewDrafts(db *pgxpool.Pool) Drafts`.
- Catalog service: `Deps.Drafts`; `Service.PutDraft(ctx, account, id uuid.UUID, c domain.DraftContent) (DraftView, bool, error)`, `ListDrafts(ctx, account uuid.UUID) ([]DraftView, error)`, `DeleteDraft(ctx, account, id uuid.UUID) error`; `service.DraftView`, `service.DraftPhotoView`.
- Test helpers: media service `env.clock`, `env.runExpire(t, id)`, `env.expire(t, id)` (moves the clock a day first), `env.get(t, id)`; catalog repository `draftContent`; catalog service `env.drafts`, `env.photo`, `env.expiresAt`, `content`, `photoIDs`, `kept`; e2e `listingDraft`, `draftBody(title string, photos ...string)`.

---

### Task 1: The contract, and `ListingInput` in the spec and in Go

The design starts in `api/`. This task writes the draft endpoints into the spec and renames today's listing body, in the spec and in Go, so the new resource can be `ListingDraft`. The routes follow in Task 4, so `TestRoutesMatchSpec` and e2e fail until then.

**Files:**
- Modify: `api/openapi.yaml` (two routes after `/v1/me/listings`), `api/schemas/catalog.yaml`, `api/paths/catalog.yaml`, `api/schemas/assist.yaml:118`
- Test: `api/spec_test.go`
- Modify: `internal/catalog/domain/listing.go:74-91`, `internal/catalog/domain/embedding.go:29`, `internal/catalog/domain/price.go:18`
- Rename: `internal/catalog/handler/draft.go` → `internal/catalog/handler/listing_input.go`; modify `listing_post.go`, `listing_update.go`
- Modify: `internal/catalog/service/listing_post_durable.go:23-25`, `listing_edit_durable.go:24-26`, `listing_post.go`, `listing_edit.go`, `price_sample.go:13`, `service.go`; `internal/catalog/catalogtest/catalogtest.go:45-51`; `internal/assist/service/estimate.go:27`; and every test `gopls` changes

**Interfaces:**
- Consumes: nothing.
- Produces: operations `listListingDrafts` (`GET /v1/listing-drafts`), `putListingDraft` and `deleteListingDraft` (`/v1/listing-drafts/{id}`); schemas `ListingInput` (was `ListingDraft`), `ListingDraftInput`, `ListingDraftPhoto`, `ListingDraft`, `ListingDraftList`; Go `domain.ListingInput` (the fields of `Draft`, unchanged), `service.PostInput.Listing` and `service.EditInput.Listing` (`json:"listing"`), handler type `listingBody` with `input() domain.ListingInput`.

- [ ] **Step 1: Write the failing spec test**

Append to `api/spec_test.go` (add `"strings"` to its imports):

```go
// The listing endpoints take ListingInput; ListingDraft is the draft
// resource, which ListingDraftInput writes.
func TestListingSchemaNames(t *testing.T) {
	t.Parallel()
	doc, err := api.Load()
	if err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct{ path, method, want string }{
		{"/v1/listings", "POST", "#/ListingInput"},
		{"/v1/listings/{id}", "PUT", "#/ListingInput"},
		{"/v1/listing-drafts/{id}", "PUT", "#/ListingDraftInput"},
	} {
		item := doc.Paths.Find(c.path)
		if item == nil || item.GetOperation(c.method) == nil {
			t.Errorf("%s %s is not in the spec", c.method, c.path)
			continue
		}
		ref := item.GetOperation(c.method).RequestBody.Value.Content.Get("application/json").Schema.Ref
		if !strings.HasSuffix(ref, c.want) {
			t.Errorf("%s %s takes %s, want %s", c.method, c.path, ref, c.want)
		}
	}
	got := doc.Paths.Find("/v1/listing-drafts/{id}").Put.Responses.Status(200).Value.Content.Get("application/json").Schema.Ref
	if !strings.HasSuffix(got, "#/ListingDraft") {
		t.Errorf("PUT /v1/listing-drafts/{id} answers %s", got)
	}
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./api/ -run TestListingSchemaNames`
Expected: FAIL, `POST /v1/listings takes ../schemas/catalog.yaml#/ListingDraft, want #/ListingInput` and `PUT /v1/listing-drafts/{id} is not in the spec`.

- [ ] **Step 3: Rename the listing body**

In `api/schemas/catalog.yaml`, line 1 `ListingDraft:` becomes `ListingInput:`. In `api/paths/catalog.yaml`, both `$ref: "../schemas/catalog.yaml#/ListingDraft"` (lines 20 and 108) become `$ref: "../schemas/catalog.yaml#/ListingInput"`. In `api/schemas/assist.yaml:118`, `ListingDraft's fields as the AI filled them.` becomes `ListingInput's fields as the AI filled them.`

- [ ] **Step 4: The draft schemas**

Append to `api/schemas/catalog.yaml`:

```yaml
ListingDraftInput:
  type: object
  additionalProperties: false
  required: [schema_version, title, price, photos, body]
  description: |
    A draft as the app has it. The server reads title, price and photos and
    keeps body as it came, without reading it; the posting rules apply only
    at POST /v1/listings.
  properties:
    schema_version:
      type: integer
      minimum: 1
      description: The layout of body, which the app defines.
    title:
      type: string
      maxLength: 100
      description: May be empty.
    price:
      type: [integer, "null"]
      format: int64
      minimum: 0
      description: Whole đồng, or null while the seller has typed none.
    photos:
      type: array
      maxItems: 10
      items:
        type: string
        format: uuid
      description: |
        Upload IDs of the caller's, in order. A photo a listing took, or one
        that expired, is dropped from the stored draft; an ID given twice is
        kept once. Each photo kept is kept 30 days from this PUT.
    body:
      type: string
      maxLength: 32768
      description: JSON the app owns, as a string.
ListingDraftPhoto:
  type: object
  additionalProperties: false
  required: [upload_id, url]
  properties:
    upload_id:
      type: string
      format: uuid
    url:
      type: string
      description: A presigned GET of the original upload, valid for an hour.
ListingDraft:
  type: object
  additionalProperties: false
  required: [id, schema_version, title, price, photos, body, updated_at, expires_at]
  description: |
    A listing the caller started and has not posted, kept for their other
    devices until expires_at, 30 days after its last PUT. Photos a listing
    took or that expired are left out.
  properties:
    id:
      type: string
      format: uuid
    schema_version:
      type: integer
      minimum: 1
    title:
      type: string
      maxLength: 100
    price:
      type: [integer, "null"]
      format: int64
      minimum: 0
    photos:
      type: array
      maxItems: 10
      items:
        $ref: "#/ListingDraftPhoto"
    body:
      type: string
      maxLength: 32768
    updated_at:
      type: string
      format: date-time
    expires_at:
      type: string
      format: date-time
ListingDraftList:
  type: object
  additionalProperties: false
  required: [items]
  properties:
    items:
      type: array
      maxItems: 20
      items:
        $ref: "#/ListingDraft"
```

- [ ] **Step 5: The draft operations**

Append to `api/paths/catalog.yaml`:

```yaml
listingDrafts:
  get:
    operationId: listListingDrafts
    summary: List the caller's drafts.
    description: |
      Every draft of the caller's, in full, last edited first; at most 20,
      so there are no pages. Drafts past expires_at are deleted first.
    tags: [catalog]
    security:
      - bearerAuth: []
    responses:
      "200":
        description: The drafts.
        content:
          application/json:
            schema:
              $ref: "../schemas/catalog.yaml#/ListingDraftList"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
listingDraft:
  put:
    operationId: putListingDraft
    summary: Create or replace one of the caller's drafts.
    description: |
      The app mints the ID, a UUIDv7, so a draft made offline has its ID
      before it reaches the server. The last PUT wins. Photos a listing took
      or that expired are dropped; each of the others is kept 30 days from
      this PUT, and a later PUT never shortens that. The draft is kept 30
      days from this PUT. Drafts of the caller's past expires_at are deleted
      first, so they free their places.
    tags: [catalog]
    security:
      - bearerAuth: []
    parameters:
      - name: id
        in: path
        required: true
        schema:
          type: string
          format: uuid
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/catalog.yaml#/ListingDraftInput"
    responses:
      "200":
        description: The draft, replaced.
        content:
          application/json:
            schema:
              $ref: "../schemas/catalog.yaml#/ListingDraft"
      "201":
        description: The draft, created.
        content:
          application/json:
            schema:
              $ref: "../schemas/catalog.yaml#/ListingDraft"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "The ID is another account's draft (draft_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "409":
        description: "A create when the caller has 20 drafts (draft_limit_reached), or the photos collided with another write (try_again)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: "A photo is not the caller's photo upload, waiting before its expiry and in the store as declared (invalid_upload)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
  delete:
    operationId: deleteListingDraft
    summary: Delete one of the caller's drafts.
    description: Its photos expire on their own. The app calls it after a post from the draft.
    tags: [catalog]
    security:
      - bearerAuth: []
    parameters:
      - name: id
        in: path
        required: true
        schema:
          type: string
          format: uuid
    responses:
      "204":
        description: Deleted, or there was no such draft of the caller's.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
```

In `api/openapi.yaml`, after

```yaml
  /v1/me/listings:
    $ref: "paths/catalog.yaml#/myListings"
```

add

```yaml
  /v1/listing-drafts:
    $ref: "paths/catalog.yaml#/listingDrafts"
  /v1/listing-drafts/{id}:
    $ref: "paths/catalog.yaml#/listingDraft"
```

- [ ] **Step 6: Run the spec test**

Run: `go test ./api/`
Expected: PASS.

- [ ] **Step 7: Rename the type**

Run, from the worktree root:

```bash
gopls rename -w internal/catalog/domain/listing.go:75:6 ListingInput
grep -rn 'domain\.Draft\b' internal/catalog internal/deal internal/discovery internal/chat e2e cmd | grep -v 'assist' ; grep -rn 'catalogdomain\.Draft\b' internal e2e
```

Expected: both greps print nothing (assist's own `domain.Draft`, a read's draft, stays).

- [ ] **Step 8: Rename the flow fields**

```bash
gopls rename -w internal/catalog/service/listing_post_durable.go:24:2 Listing
gopls rename -w internal/catalog/service/listing_edit_durable.go:25:2 Listing
```

Then change the tags by hand: in `PostInput` and `EditInput`, the field's tag `json:"draft"` becomes `json:"listing"`.

- [ ] **Step 9: The handler body**

```bash
git mv internal/catalog/handler/draft.go internal/catalog/handler/listing_input.go
gopls rename -w internal/catalog/handler/listing_input.go:30:21 input
gopls rename -w internal/catalog/handler/listing_input.go:10:6 listingBody
```

(Line 30 is `func (b *draftBody) draft() domain.ListingInput {`; column 21 is the method's name. Rename the method first, since the type's longer name moves it.)

The doc comment of `listingBody` becomes `// listingBody is the ListingInput schema in api/schemas/catalog.yaml.`

- [ ] **Step 10: The comments**

- `internal/catalog/domain/listing.go:74`: `// ListingInput is a listing as the seller sends it, to post or to edit.`
- `internal/catalog/domain/listing.go:90-91`: `// Refs is what the service found in the category and region tables for a` / `// listing input.`
- `internal/catalog/domain/embedding.go:29`: `... a price sample embeds a listing input with it.`
- `internal/catalog/domain/price.go:18`: `// PriceSample is the price of one listing like a listing input, and whether it sold`
- `internal/catalog/service/price_sample.go:13`: `// PriceQuery is a listing input a price sample is drawn for: ...` (keep the rest)
- `internal/catalog/service/listing_post_durable.go:54`: `... is under the cap, then the listing's fields.`; `:130`: `// lookUpRefs reads the listing's category and commune.`
- `internal/catalog/catalogtest/catalogtest.go:45`: `... Each change edits the listing input or the ...`

Run the writing checker on the changed comments.

- [ ] **Step 11: Build and test**

Run: `go build ./... && go vet ./internal/catalog/... ./internal/assist/... && go test ./api/ ./internal/catalog/... ./internal/assist/... ./internal/deal/... ./internal/discovery/... > tmp/task1.log 2>&1; tail -30 tmp/task1.log`
Expected: PASS.

- [ ] **Step 12: Commit**

Run the writing checker on the new API descriptions and the changed comments (copy them to `tmp/check.txt` first), then:

```bash
git add api/ internal/
git commit -m "feat(catalog): the listing-drafts contract, and ListingInput for the listing a seller sends"
```

### Task 2: Upload expiry in media: `expires_at`, `Extend` and `Gone`

**Files:**
- Create: `migrations/0041_upload_expiry.sql`, `migrations/upload_expiry_test.go`
- Modify: `internal/media/domain/upload.go`, `internal/media/domain/upload_test.go`
- Modify: `internal/media/repository/upload_pg.go`, `internal/media/repository/upload_pg_test.go`
- Create: `internal/media/service/upload_extend.go`, `internal/media/service/upload_extend_test.go`
- Modify: `internal/media/service/service.go`, `upload_attach.go`, `media_expire_durable.go`, `helpers_test.go`

**Interfaces:**
- Consumes: `restatetest.NewClock`; `before` in `migrations/phone_sign_in_test.go`, `pgtest.Empty`, `postgres.Migrate`.
- Produces: column `uploads.expires_at`; `domain.ExtendFor`; `(*Upload) Extend(owner uuid.UUID, now time.Time) error`, `(*Upload) Gone(owner uuid.UUID, now time.Time) bool`; `ExpiresAt()` reads the stored expiry; `UploadState.ExpiresAt`; `Service.Extend(ctx, owner uuid.UUID, ids []uuid.UUID) error`, `Service.Gone(ctx, owner uuid.UUID, ids []uuid.UUID) ([]uuid.UUID, error)`; `MediaExpire` expires only at `expires_at` and sends itself again while it is ahead. `Attach` is unchanged: an extended upload is still waiting.

- [ ] **Step 1: Write the failing migration test**

`migrations/upload_expiry_test.go`:

```go
package migrations_test

import (
	"context"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"

	"github.com/shopnexus/server2/internal/account/accounttest"
	"github.com/shopnexus/server2/internal/platform/postgres"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server2/migrations"
)

// An upload that 0041 finds expires a day after it was created, as before;
// one the release before inserts without expires_at gets a day from now.
func TestUploadExpiry(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.Empty(t)
	if _, err := postgres.Migrate(ctx, db, before(t, "0041_upload_expiry.sql")); err != nil {
		t.Fatal(err)
	}
	acc := accounttest.New(t, db)
	id := uuid.NewV7()
	created := time.Now().Add(-2 * time.Hour).UTC().Truncate(time.Second)
	if _, err := db.Exec(ctx, `INSERT INTO uploads (id, owner_id, content_type, size, status, write_id, created_at, updated_at)
VALUES (@id, @owner, 'image/jpeg', 10, 'waiting', gen_random_uuid(), @created, @created)`,
		pgx.StrictNamedArgs{"id": id, "owner": acc, "created": created}); err != nil {
		t.Fatal(err)
	}
	if _, err := postgres.Migrate(ctx, db, migrations.FS); err != nil {
		t.Fatalf("0041 on a database with uploads: %v", err)
	}
	var expires time.Time
	if err := db.QueryRow(ctx, `SELECT expires_at FROM uploads WHERE id = @id`, pgx.StrictNamedArgs{"id": id}).Scan(&expires); err != nil ||
		!expires.Equal(created.Add(24*time.Hour)) {
		t.Fatalf("an upload 0041 found: expires %v, %v", expires, err)
	}
	var ahead int64
	if err := db.QueryRow(ctx, `INSERT INTO uploads (id, owner_id, content_type, size, status, write_id, created_at, updated_at)
VALUES (gen_random_uuid(), @owner, 'image/jpeg', 10, 'waiting', gen_random_uuid(), now(), now())
RETURNING extract(epoch FROM expires_at - now())::bigint`, pgx.StrictNamedArgs{"owner": acc}).Scan(&ahead); err != nil || ahead != 86400 {
		t.Fatalf("an upload the release before inserts: expires in %d s, %v", ahead, err)
	}
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./migrations/ -run TestUploadExpiry`
Expected: FAIL, `column "expires_at" does not exist`.

- [ ] **Step 3: Write the migration**

`migrations/0041_upload_expiry.sql`:

```sql
-- Module media: when a waiting upload is deleted. It starts a day after
-- the upload, and a listing draft that names the photo moves it to 30 days
-- after its last PUT; nothing moves it back. The default serves the
-- inserts of the release before while this rolls out: their uploads
-- expire a day on, as that release's MediaExpire does.
ALTER TABLE uploads ADD COLUMN expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours');
UPDATE uploads SET expires_at = created_at + interval '24 hours';
```

Run: `go test ./migrations/ && sqlfluff lint migrations/0041_upload_expiry.sql`
Expected: PASS, and no sqlfluff finding (fix layout findings with `sqlfluff fix` on this file only).

- [ ] **Step 4: Write the failing domain tests**

In `internal/media/domain/upload_test.go`, replace `TestExpireOnlyWhileWaiting` with:

```go
// An upload expires once it is past its expiry, and only while it waits.
func TestExpireOnlyWhileWaitingPastItsExpiry(t *testing.T) {
	t.Parallel()
	owner := uuid.NewV7()
	waiting, _ := domain.NewUpload(uuid.NewV7(), owner, "image/jpeg", 10, domain.OriginApp, now)
	if !waiting.ExpiresAt().Equal(now.Add(domain.ExpireAfter)) {
		t.Fatalf("expires %v", waiting.ExpiresAt())
	}
	if waiting.Expire(now.Add(domain.ExpireAfter-time.Second)) || waiting.Status() != domain.StatusWaiting {
		t.Fatalf("before its expiry: %s", waiting.Status())
	}
	if !waiting.Expire(now.Add(domain.ExpireAfter)) || waiting.Status() != domain.StatusExpired {
		t.Fatalf("waiting: %s", waiting.Status())
	}
	attached, _ := domain.NewUpload(uuid.NewV7(), owner, "image/jpeg", 10, domain.OriginApp, now)
	_, _ = attached.Attach(owner, uuid.NewV7(), domain.ShapePhoto, now)
	if attached.Expire(now.Add(domain.ExpireAfter)) || attached.Status() != domain.StatusAttached {
		t.Fatalf("attached: %s", attached.Status())
	}
}
```

and append:

```go
func newPhoto(owner uuid.UUID) domain.Upload {
	u, _ := domain.NewUpload(uuid.NewV7(), owner, "image/jpeg", 10, domain.OriginApp, now)
	return u
}

// Extend keeps a waiting photo 30 days from now and never brings its
// expiry in; the photo stays waiting, so a listing still takes it.
func TestExtend(t *testing.T) {
	t.Parallel()
	owner := uuid.NewV7()
	u := newPhoto(owner)
	later := now.Add(5 * 24 * time.Hour)
	if err := u.Extend(owner, now); err != nil || !u.ExpiresAt().Equal(now.Add(domain.ExtendFor)) || u.Status() != domain.StatusWaiting {
		t.Fatalf("extend: %v, expires %v, %s", err, u.ExpiresAt(), u.Status())
	}
	if err := u.Extend(owner, later); err != nil || !u.ExpiresAt().Equal(later.Add(domain.ExtendFor)) {
		t.Fatalf("extend later: %v, expires %v", err, u.ExpiresAt())
	}
	if err := u.Extend(owner, now.Add(time.Hour)); err != nil || !u.ExpiresAt().Equal(later.Add(domain.ExtendFor)) {
		t.Fatalf("an earlier extension shortened it: %v, expires %v", err, u.ExpiresAt())
	}
	if u.Expire(now.Add(domain.ExtendFor)) {
		t.Fatal("expired before its extended expiry")
	}
	if changed, err := u.Attach(owner, uuid.NewV7(), domain.ShapePhoto, now.Add(20*24*time.Hour)); err != nil || !changed {
		t.Fatalf("a listing took no extended photo: %v %v", changed, err)
	}
}

func TestExtendRefuses(t *testing.T) {
	t.Parallel()
	owner := uuid.NewV7()
	video, _ := domain.NewUpload(uuid.NewV7(), owner, domain.ContentTypeMP4, 10, domain.OriginApp, now)
	attached := newPhoto(owner)
	_, _ = attached.Attach(owner, uuid.NewV7(), domain.ShapePhoto, now)
	for name, c := range map[string]struct {
		u     domain.Upload
		owner uuid.UUID
		at    time.Time
	}{
		"another owner's":         {newPhoto(owner), uuid.NewV7(), now},
		"a video":                 {video, owner, now},
		"a photo past its expiry": {newPhoto(owner), owner, now.Add(domain.ExpireAfter)},
		"an attached photo":       {attached, owner, now},
	} {
		u := c.u
		before := u.ExpiresAt()
		if err := u.Extend(c.owner, c.at); !errors.Is(err, domain.ErrInvalidUpload) || !u.ExpiresAt().Equal(before) {
			t.Errorf("%s: %v, expires %v", name, err, u.ExpiresAt())
		}
	}
}

// Gone is what can no longer be in a draft: taken by a holder, expired, or
// waiting past its expiry. Another owner's upload is not gone; Extend
// refuses it.
func TestGone(t *testing.T) {
	t.Parallel()
	owner := uuid.NewV7()
	extended := newPhoto(owner)
	_ = extended.Extend(owner, now)
	attached := newPhoto(owner)
	_, _ = attached.Attach(owner, uuid.NewV7(), domain.ShapePhoto, now)
	for name, c := range map[string]struct {
		u    domain.Upload
		at   time.Time
		gone bool
	}{
		"waiting":                 {newPhoto(owner), now, false},
		"waiting past its expiry": {newPhoto(owner), now.Add(domain.ExpireAfter), true},
		"extended, 29 days on":    {extended, now.Add(29 * 24 * time.Hour), false},
		"attached":                {attached, now, true},
	} {
		u := c.u
		if u.Gone(owner, c.at) != c.gone {
			t.Errorf("%s: gone %v", name, !c.gone)
		}
	}
	if attached.Gone(uuid.NewV7(), now) {
		t.Fatal("another owner's upload is gone")
	}
}
```

- [ ] **Step 5: Run them to see them fail**

Run: `go test -short ./internal/media/domain/`
Expected: FAIL to build, `u.Extend undefined`.

- [ ] **Step 6: The domain**

In `internal/media/domain/upload.go`:

Add after `ExpireAfter`'s block (keep `ExpireAfter`):

```go
// ExtendFor is how long a draft keeps the photos it names after each PUT:
// catalog's domain.DraftLife.
const ExtendFor = 30 * 24 * time.Hour
```

Add the field to `Upload`, after `failure`:

```go
	expiresAt   time.Time // when a waiting upload is deleted; a draft moves it out
```

In `NewUpload`, the returned literal gains `expiresAt: now.Add(ExpireAfter),`.

Replace `Expire` with:

```go
// Expire ends an upload that is still waiting at its expiry and reports
// whether it did; an upload before its expiry, or attached, processed or
// expired, stays as it is.
func (u *Upload) Expire(now time.Time) bool {
	if u.status != StatusWaiting || now.Before(u.expiresAt) {
		return false
	}
	u.status, u.updatedAt = StatusExpired, now
	return true
}
```

Add after `Consume`:

```go
// Extend keeps a waiting photo of owner's for their drafts: its expiry
// moves to ExtendFor from now, unless it is later already. Nothing brings
// it in. Another owner's upload, a video, or a photo that is not waiting
// before its expiry is refused.
func (u *Upload) Extend(owner uuid.UUID, now time.Time) error {
	if owner != u.ownerID || IsVideo(u.contentType) || u.status != StatusWaiting || !now.Before(u.expiresAt) {
		return ErrInvalidUpload
	}
	if end := now.Add(ExtendFor); u.expiresAt.Before(end) {
		u.expiresAt, u.updatedAt = end, now
	}
	return nil
}

// Gone reports whether an upload of owner's can no longer be in their
// drafts: a holder took it, it expired, or it waits past its expiry.
// Another owner's upload is not gone; Extend refuses it.
func (u *Upload) Gone(owner uuid.UUID, now time.Time) bool {
	if owner != u.ownerID {
		return false
	}
	if u.status == StatusWaiting {
		return !now.Before(u.expiresAt)
	}
	return true // attached, ready, failed, expired, consumed
}
```

Add to `UploadState`, after `Failure`:

```go
	ExpiresAt   time.Time `json:"expires_at"`
```

set it in `RestoreUpload` (`expiresAt: st.ExpiresAt,`) and in `State` (`ExpiresAt: u.expiresAt,`).

Replace `ExpiresAt` with:

```go
// ExpiresAt is when a waiting upload is deleted: a day after it was
// created, or later once a draft extended it.
func (u *Upload) ExpiresAt() time.Time { return u.expiresAt }
```

and the comment of `ExpireAfter` becomes `// ExpireAfter is how long a new upload may wait for an attach or a draft.`

- [ ] **Step 7: Run the domain tests**

Run: `go test -short ./internal/media/domain/`
Expected: PASS (`TestAttachRefusesAnExpiredVideo` and `TestUploadJSONRoundTrip` too: the expiry is in the state).

- [ ] **Step 8: The store**

In `internal/media/repository/upload_pg.go`:

```go
const uploadColumns = `id, owner_id, coalesce(holder_id, '00000000-0000-0000-0000-000000000000'), coalesce(shape, ''), content_type, size, status, coalesce(photo_key, ''), coalesce(thumb_key, ''),
       coalesce(failure, ''), write_id, created_at, updated_at, origin, expires_at`
```

In `scanUpload`, scan `&st.ExpiresAt` after `&st.Origin`. `Create` writes it:

```go
INSERT INTO uploads (id, owner_id, content_type, size, origin, status, write_id, created_at, updated_at, expires_at)
VALUES (@id, @owner_id, @content_type, @size, @origin, @status, @write_id, @created_at, @updated_at, @expires_at)
ON CONFLICT (id) DO NOTHING`
```

with `"expires_at": st.ExpiresAt` in its arguments; in `saveUpload`, after `failure = NULLIF(@failure, ''),` add `expires_at = @expires_at,`, and in `update` add `"expires_at": st.ExpiresAt,` to the arguments.

Append to `internal/media/repository/upload_pg_test.go`:

```go
// An upload stores its expiry, a day on at first and later once extended.
func TestExpiryStored(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewUploads(db)
	ctx := context.Background()
	owner := accounttest.New(t, db)
	u := created(t, s, owner)
	if got, _ := s.Get(ctx, u.ID()); !got.ExpiresAt().Equal(now.Add(domain.ExpireAfter)) {
		t.Fatalf("new: %v", got.ExpiresAt())
	}
	later := now.Add(2 * time.Hour)
	if err := u.Extend(owner, later); err != nil {
		t.Fatal(err)
	}
	if err := s.Save(ctx, &u, uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	if got, _ := s.Get(ctx, u.ID()); got.Status() != domain.StatusWaiting || !got.ExpiresAt().Equal(later.Add(domain.ExtendFor)) {
		t.Fatalf("extended: %+v", got.State())
	}
}
```

Run: `go test ./internal/media/repository/`
Expected: PASS.

- [ ] **Step 9: Write the failing service tests**

In `internal/media/service/helpers_test.go`, the env gets a stopped clock and `expire` moves it. Replace `env`, `newEnv` and `expire` with:

```go
type env struct {
	db      *pgxpool.Pool
	store   *objectstore.Store
	media   *service.Media
	ingress *ingress.Client
	prefix  string
	// clock is media's clock; only expire and the tests of extensions move it.
	clock *restatetest.Clock
}

// newEnv serves module media's Restate services on the test stack, on a
// database and the test bucket, with a stopped clock.
func newEnv(t *testing.T) env {
	t.Helper()
	db := pgtest.New(t)
	store := objectstoretest.New(t)
	in, p := restatetest.Ingress(t), restatetest.Prefix()
	clock := restatetest.NewClock(time.Now())
	m := service.New(service.Deps{Uploads: repository.NewUploads(db), Store: store, Ingress: in, Prefix: p, Now: clock.Now})
	restatetest.Start(t, m.Durable()...)
	return env{db: db, store: store, media: m, ingress: in, prefix: p, clock: clock}
}

// runExpire runs MediaExpire for id at the clock's time.
func (e env) runExpire(t *testing.T, id uuid.UUID) {
	t.Helper()
	if _, err := ingress.Service[uuid.UUID, restate.Void](e.ingress, e.prefix+"MediaExpire", "Run").
		Request(context.Background(), id); err != nil {
		t.Fatal(err)
	}
}

// expire moves the clock a day on and runs MediaExpire for id, as Restate
// does a day after the upload was created.
func (e env) expire(t *testing.T, id uuid.UUID) {
	t.Helper()
	e.clock.Add(domain.ExpireAfter)
	e.runExpire(t, id)
}

// get reads an upload.
func (e env) get(t *testing.T, id uuid.UUID) domain.Upload {
	t.Helper()
	u, err := repository.NewUploads(e.db).Get(context.Background(), id)
	if err != nil {
		t.Fatal(err)
	}
	return u
}
```

(imports: add `"time"`, `"github.com/shopnexus/server2/internal/media/domain"` and `"github.com/shopnexus/server2/internal/media/repository"` where missing; keep `mediatest`, which `upload` still calls.)

Create `internal/media/service/upload_extend_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"slices"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/account/accounttest"
	"github.com/shopnexus/server2/internal/media/domain"
	"github.com/shopnexus/server2/internal/platform/objectstore"
)

// Extend takes all of the owner's photos or none; one that is another
// account's, unknown, never put or a video leaves the rest as they were.
// Extending again moves the expiry out, never in.
func TestExtendAllOrNone(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	owner := accounttest.New(t, e.db)
	mine := e.upload(t, owner, []byte("jpeg bytes"))
	theirs := e.upload(t, accounttest.New(t, e.db), []byte("jpeg bytes"))
	never, err := e.media.CreateUpload(ctx, owner, "image/jpeg", 10)
	if err != nil {
		t.Fatal(err)
	}
	video, err := e.media.CreateUpload(ctx, owner, domain.ContentTypeMP4, 10)
	if err != nil {
		t.Fatal(err)
	}
	first := e.get(t, mine).ExpiresAt()
	for name, ids := range map[string][]uuid.UUID{
		"another account's": {mine, theirs},
		"unknown":           {mine, uuid.NewV7()},
		"never put":         {mine, never.UploadID},
		"a video":           {mine, video.UploadID},
	} {
		if err := e.media.Extend(ctx, owner, ids); !errors.Is(err, domain.ErrInvalidUpload) {
			t.Errorf("%s: %v", name, err)
		}
	}
	if got := e.get(t, mine).ExpiresAt(); !got.Equal(first) {
		t.Fatalf("extended by a refusal: %v", got)
	}
	if err := e.media.Extend(ctx, owner, []uuid.UUID{mine, mine}); err != nil {
		t.Fatal(err)
	}
	if u := e.get(t, mine); u.Status() != domain.StatusWaiting || u.ExpiresAt().Sub(e.clock.Now().Add(domain.ExtendFor)).Abs() > time.Millisecond {
		t.Fatalf("%s, expires %v", u.Status(), u.ExpiresAt())
	}
	if err := e.media.Extend(ctx, owner, nil); err != nil {
		t.Fatalf("nothing to extend: %v", err)
	}
}

// An expired upload is not extended.
func TestExtendRefusesAnExpiredPhoto(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	owner := accounttest.New(t, e.db)
	id := e.upload(t, owner, []byte("jpeg bytes"))
	e.expire(t, id)
	if err := e.media.Extend(ctx, owner, []uuid.UUID{id}); !errors.Is(err, domain.ErrInvalidUpload) {
		t.Fatalf("%v", err)
	}
}

// MediaExpire, waking a day after the upload, finds it extended and sends
// itself again; at the extended expiry it deletes the upload and its
// object.
func TestExtendedPhotoWaitsForItsExpiry(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	owner := accounttest.New(t, e.db)
	id := e.upload(t, owner, []byte("jpeg bytes"))
	if err := e.media.Extend(ctx, owner, []uuid.UUID{id}); err != nil {
		t.Fatal(err)
	}
	e.expire(t, id)
	if s := e.get(t, id).Status(); s != domain.StatusWaiting {
		t.Fatalf("a day after the upload: %s", s)
	}
	if _, _, err := e.store.Stat(ctx, domain.UploadKey(id)); err != nil {
		t.Fatalf("object: %v", err)
	}
	e.clock.Add(domain.ExtendFor - domain.ExpireAfter)
	e.runExpire(t, id)
	if s := e.get(t, id).Status(); s != domain.StatusExpired {
		t.Fatalf("30 days after the extension: %s", s)
	}
	if _, _, err := e.store.Stat(ctx, domain.UploadKey(id)); !errors.Is(err, objectstore.ErrNotFound) {
		t.Fatalf("object: %v", err)
	}
}

// A photo two PUTs extended, ten days apart, lives until the later
// extension's end: the run sent for the first one finds the expiry moved
// and sends itself again.
func TestExtendedTwiceWaitsForTheLater(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	owner := accounttest.New(t, e.db)
	id := e.upload(t, owner, []byte("jpeg bytes"))
	if err := e.media.Extend(ctx, owner, []uuid.UUID{id}); err != nil {
		t.Fatal(err)
	}
	e.clock.Add(10 * 24 * time.Hour)
	if err := e.media.Extend(ctx, owner, []uuid.UUID{id}); err != nil {
		t.Fatal(err)
	}
	e.clock.Add(domain.ExtendFor - 10*24*time.Hour) // the first extension's end
	e.runExpire(t, id)
	if s := e.get(t, id).Status(); s != domain.StatusWaiting {
		t.Fatalf("at the first extension's end: %s", s)
	}
	e.clock.Add(10 * 24 * time.Hour)
	e.runExpire(t, id)
	if s := e.get(t, id).Status(); s != domain.StatusExpired {
		t.Fatalf("at the second's: %s", s)
	}
}

// Gone names the owner's uploads a listing took, those that expired and
// the IDs with no upload; a waiting or extended one, or another account's,
// is not gone.
func TestGoneUploads(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	owner := accounttest.New(t, e.db)
	expired := e.upload(t, owner, []byte("jpeg bytes"))
	e.expire(t, expired)
	waiting := e.upload(t, owner, []byte("jpeg bytes"))
	extended := e.upload(t, owner, []byte("jpeg bytes"))
	attached := e.upload(t, owner, []byte("jpeg bytes"))
	theirs := e.upload(t, accounttest.New(t, e.db), []byte("jpeg bytes"))
	unknown := uuid.NewV7()
	if err := e.media.Extend(ctx, owner, []uuid.UUID{extended}); err != nil {
		t.Fatal(err)
	}
	if err := e.media.Attach(ctx, owner, uuid.NewV7(), []uuid.UUID{attached}); err != nil {
		t.Fatal(err)
	}
	gone, err := e.media.Gone(ctx, owner, []uuid.UUID{waiting, extended, attached, expired, theirs, unknown})
	if err != nil || !slices.Equal(gone, []uuid.UUID{attached, expired, unknown}) {
		t.Fatalf("gone %v %v", gone, err)
	}
}

// A listing takes an extended photo, two days after its first day ended.
func TestAttachAnExtendedPhoto(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	owner := accounttest.New(t, e.db)
	id := e.upload(t, owner, []byte("jpeg bytes"))
	if err := e.media.Extend(ctx, owner, []uuid.UUID{id}); err != nil {
		t.Fatal(err)
	}
	e.clock.Add(3 * domain.ExpireAfter)
	if err := e.media.Attach(ctx, owner, uuid.NewV7(), []uuid.UUID{id}); err != nil {
		t.Fatal(err)
	}
	if s := e.get(t, id).Status(); s != domain.StatusAttached {
		t.Fatalf("status %s", s)
	}
}
```

- [ ] **Step 10: Run them to see them fail**

Run: `go test ./internal/media/service/ -run 'TestExtend|TestGone|TestAttachAnExtended|TestExpire|TestSavedPhotoExpires'`
Expected: FAIL to build, `e.media.Extend undefined`.

- [ ] **Step 11: The use cases**

In `internal/media/service/upload_attach.go`, the store check becomes a helper that `Extend` shares. Replace the loop body after `if !changed { continue }` with:

```go
		if err = m.checkStored(ctx, u); err != nil {
			return err
		}
		ups = append(ups, u)
```

and add at the end of the file:

```go
// checkStored checks that upload u was put to the store with the type and
// size it declared; anything else is domain.ErrInvalidUpload. attachAs and
// Extend call it for each upload they change.
func (m *Media) checkStored(ctx context.Context, u *domain.Upload) error {
	size, contentType, err := m.store.Stat(ctx, u.Key())
	if errors.Is(err, objectstore.ErrNotFound) {
		return domain.ErrInvalidUpload
	}
	if err != nil {
		return fmt.Errorf("stat upload: %w", err)
	}
	if size != u.Size() || contentType != u.ContentType() {
		return domain.ErrInvalidUpload
	}
	return nil
}
```

Create `internal/media/service/upload_extend.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"uuid"

	"github.com/shopnexus/server2/internal/media/domain"
	"github.com/shopnexus/server2/internal/media/repository"
	"github.com/shopnexus/server2/internal/platform/apperr"
)

// Extend keeps owner's photos for their drafts, all or none: each must be
// owner's photo, waiting before its expiry and put to the store with the
// type and size it declared. Each then expires domain.ExtendFor from now,
// or later if it did already.
func (m *Media) Extend(ctx context.Context, owner uuid.UUID, ids []uuid.UUID) error {
	if len(ids) == 0 {
		return nil
	}
	now := m.now()
	ids = slices.Clone(ids)
	slices.SortFunc(ids, uuid.UUID.Compare)
	ids = slices.Compact(ids)
	found, err := m.uploads.GetMany(ctx, ids)
	if err != nil {
		return fmt.Errorf("get uploads: %w", err)
	}
	if len(found) != len(ids) {
		return domain.ErrInvalidUpload
	}
	ups := make([]*domain.Upload, len(found))
	for i := range found {
		u := &found[i]
		if err = u.Extend(owner, now); err != nil {
			return err
		}
		if err = m.checkStored(ctx, u); err != nil {
			return err
		}
		ups[i] = u
	}
	if err = m.uploads.SaveAll(ctx, ups, uuid.NewV7()); err != nil {
		if errors.Is(err, repository.ErrConflict) {
			return apperr.ErrTryAgain
		}
		return fmt.Errorf("save uploads: %w", err)
	}
	return nil
}

// Gone returns those of ids that owner's drafts can no longer name: an
// upload of owner's a holder took, one that expired or waits past its
// expiry, and an ID with no upload, in the order of ids.
func (m *Media) Gone(ctx context.Context, owner uuid.UUID, ids []uuid.UUID) ([]uuid.UUID, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	now := m.now()
	found, err := m.uploads.GetMany(ctx, ids)
	if err != nil {
		return nil, fmt.Errorf("get uploads: %w", err)
	}
	byID := make(map[uuid.UUID]*domain.Upload, len(found))
	for i := range found {
		byID[found[i].ID()] = &found[i]
	}
	var gone []uuid.UUID
	for _, id := range ids {
		if u, ok := byID[id]; !ok || u.Gone(owner, now) {
			gone = append(gone, id)
		}
	}
	return gone, nil
}
```

In `internal/media/service/service.go`, add to `Service` after `Attach`:

```go
	// Extend keeps owner's photos for their drafts, all or none: each is
	// owner's photo, waiting before its expiry and in the store as
	// declared, otherwise domain.ErrInvalidUpload. Each then expires 30
	// days from now; nothing brings an expiry in. The uploads stay
	// waiting, so Attach takes them.
	Extend(ctx context.Context, owner uuid.UUID, ids []uuid.UUID) error
	// Gone returns those of ids that owner's drafts can no longer name: a
	// holder took it, it expired, or no upload has the ID.
	Gone(ctx context.Context, owner uuid.UUID, ids []uuid.UUID) ([]uuid.UUID, error)
```

- [ ] **Step 12: MediaExpire waits for the expiry**

In `internal/media/service/media_expire_durable.go`, the comment of `Run` becomes:

```go
// Run expires the upload when it is still waiting at its expiry and
// deletes its object. A waiting upload whose expiry a draft moved out sends
// this run again for that moment; an attached, processed or unknown upload
// is left as it is.
```

and

```go
	u := l.Upload
	if !l.Found || !u.Expire(at) {
		return nil
	}
```

becomes

```go
	u := l.Upload
	if !l.Found {
		return nil
	}
	if u.Status() == domain.StatusWaiting && at.Before(u.ExpiresAt()) {
		// The upload ID keyed the first run, so the key names the moment: a
		// second wake for the same expiry sends nothing more.
		restate.ServiceSend(ctx, s.ServiceName(), "Run").Send(id, restate.WithDelay(u.ExpiresAt().Sub(at)),
			restate.WithIdempotencyKey(fmt.Sprintf("%s/%d", id, u.ExpiresAt().Unix())))
		return nil
	}
	if !u.Expire(at) {
		return nil
	}
```

(add the `domain` import.)

- [ ] **Step 13: Run the media tests**

Run: `go test ./internal/media/... > tmp/task4.log 2>&1; tail -30 tmp/task4.log`
Expected: PASS, the existing `TestExpireDeletesAWaitingUpload`, `TestExpireLeavesAttachedUploads` and `TestSavedPhotoExpires` included (their `expire` now moves the clock a day first), and the query tests, which read `ExpiresAt` from the row now.

- [ ] **Step 14: Commit**

Run the writing checker on the new comments, then:

```bash
git add migrations/0041_upload_expiry.sql migrations/upload_expiry_test.go internal/media/
git commit -m "feat(media): an expiry on each upload, which a draft extends to 30 days"
```

### Task 3: The drafts: table, entity and store

**Files:**
- Create: `migrations/0042_listing_drafts.sql`, `migrations/listing_drafts_test.go`
- Create: `internal/catalog/domain/listing_draft.go`, `internal/catalog/domain/listing_draft_test.go`; modify `internal/catalog/domain/errors.go`
- Modify: `internal/catalog/repository/repository.go`; create `internal/catalog/repository/draft_pg.go`, `internal/catalog/repository/draft_pg_test.go`

**Interfaces:**
- Consumes: `pgtest.New`, `accounttest.New`; `accountdomain.ErrSessionRevoked`.
- Produces: table `listing_drafts`; `domain.MaxDrafts = 20`, `domain.DraftLife = 30 * 24 * time.Hour`; `domain.DraftContent{SchemaVersion int; Title string; Price *int64; Photos []uuid.UUID; Body string}`; `domain.ListingDraft` with `NewListingDraft(id, account uuid.UUID, c DraftContent, now time.Time) ListingDraft`, `(*ListingDraft) Replace(c DraftContent, now time.Time)`, getters `ID`, `AccountID`, `Content`, `Photos`, `CreatedAt`, `UpdatedAt`, `ExpiresAt`, `ListingDraftState`, `RestoreListingDraft`, `State`; `domain.CheckPut(stored *ListingDraft, account uuid.UUID, count int) error`; `domain.KeepPhotos(photos, gone []uuid.UUID) []uuid.UUID`; `domain.ErrDraftNotFound` (404 `draft_not_found`), `domain.ErrDraftLimitReached` (409 `draft_limit_reached`); `repository.Drafts` with `Put(ctx, account, id uuid.UUID, c domain.DraftContent, now time.Time) (domain.ListingDraft, bool, error)`, `List(ctx, account uuid.UUID, now time.Time) ([]domain.ListingDraft, error)`, `Delete(ctx, account, id uuid.UUID) error`, `DeleteAll(ctx, account uuid.UUID) error`; `repository.NewDrafts(db *pgxpool.Pool) Drafts`.

- [ ] **Step 1: Write the failing domain tests**

`internal/catalog/domain/listing_draft_test.go` (`now` is the package's test time in `listing_test.go`):

```go
package domain_test

import (
	"errors"
	"slices"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/catalog/domain"
)

func content(title string, photos ...uuid.UUID) domain.DraftContent {
	return domain.DraftContent{SchemaVersion: 1, Title: title, Price: new(int64(1_500_000)), Photos: photos, Body: `{"condition":"used"}`}
}

// A draft lives 30 days from its last write; a replace keeps its creation
// and keeps each photo once.
func TestNewAndReplace(t *testing.T) {
	t.Parallel()
	a, b := uuid.NewV7(), uuid.NewV7()
	d := domain.NewListingDraft(uuid.NewV7(), uuid.NewV7(), content("Xe đạp", a, b, a), now)
	if !slices.Equal(d.Photos(), []uuid.UUID{a, b}) || !d.ExpiresAt().Equal(now.Add(domain.DraftLife)) || !d.CreatedAt().Equal(now) {
		t.Fatalf("new: %+v", d.State())
	}
	later := now.Add(20 * 24 * time.Hour)
	d.Replace(content("Xe đạp Asama", b), later)
	if d.Content().Title != "Xe đạp Asama" || !d.UpdatedAt().Equal(later) || !d.ExpiresAt().Equal(later.Add(domain.DraftLife)) ||
		!d.CreatedAt().Equal(now) || !slices.Equal(d.Photos(), []uuid.UUID{b}) {
		t.Fatalf("replaced: %+v", d.State())
	}
}

// Another account's ID answers as no draft would; a create needs a free
// place, a replace does not.
func TestCheckPut(t *testing.T) {
	t.Parallel()
	me := uuid.NewV7()
	mine := domain.NewListingDraft(uuid.NewV7(), me, content(""), now)
	theirs := domain.NewListingDraft(uuid.NewV7(), uuid.NewV7(), content(""), now)
	for name, c := range map[string]struct {
		stored *domain.ListingDraft
		count  int
		want   error
	}{
		"create":                     {nil, domain.MaxDrafts - 1, nil},
		"create at the limit":        {nil, domain.MaxDrafts, domain.ErrDraftLimitReached},
		"replace at the limit":       {&mine, domain.MaxDrafts, nil},
		"another account's draft ID": {&theirs, 0, domain.ErrDraftNotFound},
	} {
		err := domain.CheckPut(c.stored, me, c.count)
		if (c.want == nil) != (err == nil) || (c.want != nil && !errors.Is(err, c.want)) {
			t.Errorf("%s: %v, want %v", name, err, c.want)
		}
	}
}

// A photo a listing took or that expired leaves the draft; the others keep
// their order, each once.
func TestKeepPhotos(t *testing.T) {
	t.Parallel()
	a, b, c, d := uuid.NewV7(), uuid.NewV7(), uuid.NewV7(), uuid.NewV7()
	if got := domain.KeepPhotos([]uuid.UUID{c, a, b, a, d}, []uuid.UUID{b, d}); !slices.Equal(got, []uuid.UUID{c, a}) {
		t.Fatalf("%v", got)
	}
	if got := domain.KeepPhotos(nil, nil); got == nil || len(got) != 0 {
		t.Fatalf("none: %#v", got)
	}
}
```

Run: `go test -short ./internal/catalog/domain/ -run 'TestNewAndReplace|TestCheckPut|TestKeepPhotos'`
Expected: FAIL to build, `undefined: domain.DraftContent`.

- [ ] **Step 2: The entity**

In `internal/catalog/domain/errors.go`, add to the `var` block:

```go
	ErrDraftNotFound     = apperr.New(apperr.KindNotFound, "draft_not_found", "no such draft of the caller's")
	ErrDraftLimitReached = apperr.New(apperr.KindConflict, "draft_limit_reached", "at most 20 drafts")
```

`internal/catalog/domain/listing_draft.go`:

```go
package domain

import (
	"slices"
	"time"
	"uuid"
)

const (
	// MaxDrafts is how many drafts an account keeps on the server.
	MaxDrafts = 20
	// DraftLife is how long a draft lives after its last write.
	DraftLife = 30 * 24 * time.Hour
)

// DraftContent is what the app sends of a draft. The server reads Title,
// Price and Photos; Body is the app's JSON, laid out as SchemaVersion says,
// and the server keeps it without reading it.
type DraftContent struct {
	SchemaVersion int
	Title         string
	Price         *int64
	Photos        []uuid.UUID
	Body          string
}

// ListingDraft is a listing its seller started and has not posted, kept
// for their other devices. The last write wins.
type ListingDraft struct {
	id, accountID                   uuid.UUID
	content                         DraftContent
	createdAt, updatedAt, expiresAt time.Time
}

// NewListingDraft starts account's draft id.
func NewListingDraft(id, account uuid.UUID, c DraftContent, now time.Time) ListingDraft {
	d := ListingDraft{id: id, accountID: account, createdAt: now}
	d.Replace(c, now)
	return d
}

// Replace writes c over the draft, which then lives DraftLife from now.
func (d *ListingDraft) Replace(c DraftContent, now time.Time) {
	c.Photos = KeepPhotos(c.Photos, nil)
	d.content, d.updatedAt, d.expiresAt = c, now, now.Add(DraftLife)
}

func (d *ListingDraft) ID() uuid.UUID        { return d.id }
func (d *ListingDraft) AccountID() uuid.UUID { return d.accountID }
func (d *ListingDraft) Photos() []uuid.UUID  { return slices.Clone(d.content.Photos) }
func (d *ListingDraft) CreatedAt() time.Time { return d.createdAt }
func (d *ListingDraft) UpdatedAt() time.Time { return d.updatedAt }
func (d *ListingDraft) ExpiresAt() time.Time { return d.expiresAt }
func (d *ListingDraft) Content() DraftContent {
	c := d.content
	c.Photos = slices.Clone(c.Photos)
	return c
}

// CheckPut decides whether account may write the draft whose stored row
// is stored, nil when there is none, while holding count drafts. Another
// account's draft answers as none would, so an ID tells nothing; only a
// create needs a free place.
func CheckPut(stored *ListingDraft, account uuid.UUID, count int) error {
	switch {
	case stored != nil && stored.accountID != account:
		return ErrDraftNotFound
	case stored == nil && count >= MaxDrafts:
		return ErrDraftLimitReached
	}
	return nil
}

// KeepPhotos returns photos in order, each once, without those in gone.
func KeepPhotos(photos, gone []uuid.UUID) []uuid.UUID {
	out := make([]uuid.UUID, 0, len(photos))
	for _, p := range photos {
		if !slices.Contains(gone, p) && !slices.Contains(out, p) {
			out = append(out, p)
		}
	}
	return out
}

// ListingDraftState is every stored field of a draft. Stores only.
type ListingDraftState struct {
	ID, AccountID                   uuid.UUID
	Content                         DraftContent
	CreatedAt, UpdatedAt, ExpiresAt time.Time
}

// RestoreListingDraft rebuilds a stored draft. Stores only.
func RestoreListingDraft(st ListingDraftState) ListingDraft {
	return ListingDraft{
		id: st.ID, accountID: st.AccountID, content: st.Content,
		createdAt: st.CreatedAt, updatedAt: st.UpdatedAt, expiresAt: st.ExpiresAt,
	}
}

// State returns every stored field. Stores only.
func (d *ListingDraft) State() ListingDraftState {
	return ListingDraftState{
		ID: d.id, AccountID: d.accountID, Content: d.Content(),
		CreatedAt: d.createdAt, UpdatedAt: d.updatedAt, ExpiresAt: d.expiresAt,
	}
}
```

Run: `go test -short ./internal/catalog/domain/`
Expected: PASS.

- [ ] **Step 3: Write the failing migration and store tests**

`migrations/listing_drafts_test.go`:

```go
package migrations_test

import (
	"context"
	"strings"
	"testing"
	"uuid"

	"github.com/jackc/pgx/v5"

	"github.com/shopnexus/server2/internal/account/accounttest"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
)

// The checks hold a draft to the API's shape.
func TestListingDraftsChecks(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	acc := accounttest.New(t, db)
	insert := func(schemaVersion int, title string, photos int, price int64) error {
		ids := make([]uuid.UUID, photos)
		for i := range ids {
			ids[i] = uuid.NewV7()
		}
		_, err := db.Exec(ctx, `INSERT INTO listing_drafts
    (id, account_id, schema_version, title, price, photos, body, created_at, updated_at, expires_at)
VALUES (@id, @acc, @schema_version, @title, @price, @photos, '{}', now(), now(), now() + interval '30 days')`,
			pgx.StrictNamedArgs{"id": uuid.NewV7(), "acc": acc, "schema_version": schemaVersion, "title": title, "photos": ids, "price": price})
		return err
	}
	if err := insert(1, strings.Repeat("ă", 100), 10, 0); err != nil {
		t.Fatalf("a valid draft: %v", err)
	}
	for name, err := range map[string]error{
		"schema version 0":   insert(0, "", 0, 0),
		"a 101-letter title": insert(1, strings.Repeat("ă", 101), 0, 0),
		"11 photos":          insert(1, "", 11, 0),
		"a negative price":   insert(1, "", 0, -1),
	} {
		if err == nil {
			t.Errorf("%s was stored", name)
		}
	}
}
```

`internal/catalog/repository/draft_pg_test.go`:

```go
package repository_test

import (
	"context"
	"errors"
	"slices"
	"sync"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"

	"github.com/shopnexus/server2/internal/account/accounttest"
	accountdomain "github.com/shopnexus/server2/internal/account/domain"
	"github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/catalog/repository"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
)

func draftContent(title string, photos ...uuid.UUID) domain.DraftContent {
	return domain.DraftContent{SchemaVersion: 1, Title: title, Price: new(int64(1_500_000)), Photos: photos, Body: `{"condition":"used"}`}
}

// A create, then a replace of the same ID; the list reads both fields and
// times back.
func TestDraftPutAndList(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewDrafts(db)
	ctx := context.Background()
	me := accounttest.New(t, db)
	id, photo := uuid.NewV7(), uuid.NewV7()
	d, created, err := s.Put(ctx, me, id, draftContent("Xe đạp", photo), now)
	if err != nil || !created || d.ID() != id || !d.ExpiresAt().Equal(now.Add(domain.DraftLife)) {
		t.Fatalf("create: %+v %v %v", d.State(), created, err)
	}
	later := now.Add(time.Hour)
	noPrice := domain.DraftContent{SchemaVersion: 2, Body: `{}`}
	if d, created, err = s.Put(ctx, me, id, noPrice, later); err != nil || created || !d.CreatedAt().Equal(now) {
		t.Fatalf("replace: %+v %v %v", d.State(), created, err)
	}
	other := uuid.NewV7()
	if _, _, err = s.Put(ctx, me, other, draftContent("Xe máy", photo), now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	list, err := s.List(ctx, me, later)
	if err != nil || len(list) != 2 || list[0].ID() != id || list[1].ID() != other {
		t.Fatalf("list %d %v", len(list), err)
	}
	if c := list[0].Content(); c.Price != nil || c.SchemaVersion != 2 || c.Body != `{}` || len(c.Photos) != 0 ||
		!list[0].UpdatedAt().Equal(later) || !list[0].CreatedAt().Equal(now) {
		t.Fatalf("replaced: %+v", list[0].State())
	}
	if c := list[1].Content(); *c.Price != 1_500_000 || !slices.Equal(c.Photos, []uuid.UUID{photo}) || c.Body != `{"condition":"used"}` {
		t.Fatalf("other: %+v", list[1].State())
	}
}

// Another account's ID is draft_not_found, and its draft stays.
func TestDraftPutOnAnotherAccountsID(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewDrafts(db)
	ctx := context.Background()
	me, them := accounttest.New(t, db), accounttest.New(t, db)
	id := uuid.NewV7()
	if _, _, err := s.Put(ctx, them, id, draftContent("Của họ"), now); err != nil {
		t.Fatal(err)
	}
	if _, _, err := s.Put(ctx, me, id, draftContent("Của tôi"), now); !errors.Is(err, domain.ErrDraftNotFound) {
		t.Fatalf("%v", err)
	}
	if list, _ := s.List(ctx, them, now); len(list) != 1 || list[0].Content().Title != "Của họ" {
		t.Fatalf("their draft: %d", len(list))
	}
}

// Two creates at 19 drafts wait for each other: one lands, the other finds
// the limit. A replace at 20 still lands.
func TestTwoCreatesAtNineteen(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewDrafts(db)
	ctx := context.Background()
	me := accounttest.New(t, db)
	first := uuid.NewV7()
	for i := range domain.MaxDrafts - 1 {
		id := uuid.NewV7()
		if i == 0 {
			id = first
		}
		if _, _, err := s.Put(ctx, me, id, draftContent(""), now.Add(time.Duration(i)*time.Second)); err != nil {
			t.Fatal(err)
		}
	}
	var wg sync.WaitGroup
	errs := make([]error, 2)
	for i := range errs {
		wg.Go(func() { _, _, errs[i] = s.Put(ctx, me, uuid.NewV7(), draftContent(""), now.Add(time.Hour)) })
	}
	wg.Wait()
	landed, limited := 0, 0
	for _, err := range errs {
		switch {
		case err == nil:
			landed++
		case errors.Is(err, domain.ErrDraftLimitReached):
			limited++
		default:
			t.Fatal(err)
		}
	}
	if list, _ := s.List(ctx, me, now.Add(time.Hour)); landed != 1 || limited != 1 || len(list) != domain.MaxDrafts {
		t.Fatalf("%d landed, %d limited, %d drafts", landed, limited, len(list))
	}
	if _, created, err := s.Put(ctx, me, first, draftContent("edited"), now.Add(2*time.Hour)); err != nil || created {
		t.Fatalf("a replace at 20: %v %v", created, err)
	}
}

// Expired drafts go before a list and before a put, so they free their
// places; another account's stay.
func TestExpiredDraftsGo(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewDrafts(db)
	ctx := context.Background()
	me, them := accounttest.New(t, db), accounttest.New(t, db)
	for range domain.MaxDrafts {
		if _, _, err := s.Put(ctx, me, uuid.NewV7(), draftContent(""), now); err != nil {
			t.Fatal(err)
		}
	}
	if _, _, err := s.Put(ctx, them, uuid.NewV7(), draftContent(""), now); err != nil {
		t.Fatal(err)
	}
	end := now.Add(domain.DraftLife)
	if _, _, err := s.Put(ctx, me, uuid.NewV7(), draftContent("21st"), end); err != nil {
		t.Fatalf("a create once the 20 expired: %v", err)
	}
	if list, _ := s.List(ctx, me, end); len(list) != 1 || list[0].Content().Title != "21st" {
		t.Fatalf("%d drafts", len(list))
	}
	var n int
	if err := db.QueryRow(ctx, `SELECT count(*) FROM listing_drafts WHERE account_id = @a`, pgx.StrictNamedArgs{"a": them}).Scan(&n); err != nil || n != 1 {
		t.Fatalf("their draft: %d %v", n, err)
	}
	if list, _ := s.List(ctx, them, end); len(list) != 0 {
		t.Fatal("an expired draft was listed")
	}
	if err := db.QueryRow(ctx, `SELECT count(*) FROM listing_drafts WHERE account_id = @a`, pgx.StrictNamedArgs{"a": them}).Scan(&n); err != nil || n != 0 {
		t.Fatalf("their expired draft after their list: %d %v", n, err)
	}
}

// A draft write that commits after the account's erasure finds the
// tombstone and writes nothing.
func TestDraftPutRefusesATombstone(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewDrafts(db)
	ctx := context.Background()
	gone := accounttest.New(t, db)
	if _, err := db.Exec(ctx, `UPDATE accounts
SET status = 'deleted', deleted_at = now(), display_name = NULL, bio = NULL, avatar_key = NULL WHERE id = @id`,
		pgx.StrictNamedArgs{"id": gone}); err != nil {
		t.Fatal(err)
	}
	if _, _, err := s.Put(ctx, gone, uuid.NewV7(), draftContent(""), now); !errors.Is(err, accountdomain.ErrSessionRevoked) {
		t.Fatalf("put: %v", err)
	}
	if list, _ := s.List(ctx, gone, now); len(list) != 0 {
		t.Fatalf("%d drafts", len(list))
	}
}

// Delete touches only the caller's draft; DeleteAll all of theirs.
func TestDraftDelete(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewDrafts(db)
	ctx := context.Background()
	me, them := accounttest.New(t, db), accounttest.New(t, db)
	mine, theirs := uuid.NewV7(), uuid.NewV7()
	for _, p := range []struct{ account, id uuid.UUID }{{me, mine}, {me, uuid.NewV7()}, {them, theirs}} {
		if _, _, err := s.Put(ctx, p.account, p.id, draftContent(""), now); err != nil {
			t.Fatal(err)
		}
	}
	if err := s.Delete(ctx, me, theirs); err != nil {
		t.Fatal(err)
	}
	for range 2 {
		if err := s.Delete(ctx, me, mine); err != nil {
			t.Fatal(err)
		}
	}
	if list, _ := s.List(ctx, me, now); len(list) != 1 {
		t.Fatalf("mine: %d", len(list))
	}
	if list, _ := s.List(ctx, them, now); len(list) != 1 {
		t.Fatalf("theirs: %d", len(list))
	}
	if err := s.DeleteAll(ctx, me); err != nil {
		t.Fatal(err)
	}
	if list, _ := s.List(ctx, me, now); len(list) != 0 {
		t.Fatalf("after DeleteAll: %d", len(list))
	}
}
```

(`now` is the package's test time in `listing_pg_test.go`.)

Run: `go test ./migrations/ -run TestListingDraftsChecks && go test ./internal/catalog/repository/ -run 'TestDraft|TestTwoCreatesAtNineteen|TestExpiredDraftsGo'`
Expected: FAIL, `relation "listing_drafts" does not exist`, then `undefined: repository.NewDrafts`.

- [ ] **Step 4: The migration**

`migrations/0042_listing_drafts.sql`:

```sql
-- Module catalog: a seller's listing drafts, kept so their other phones
-- find them (decided 2026-11-13). The server reads the typed columns; body
-- is the app's JSON as a string, laid out as schema_version says, and the
-- server never reads it. photos are upload IDs of module media, in order;
-- like other modules' tables, this one references no table of media. The
-- last write wins. A draft past expires_at, 30 days after its last write,
-- is deleted by the account's next list or write.
CREATE TABLE listing_drafts (
    id             uuid PRIMARY KEY,
    account_id     uuid NOT NULL REFERENCES accounts (id),
    schema_version integer NOT NULL CHECK (schema_version >= 1),
    title          text NOT NULL CHECK (char_length(title) <= 100),
    price          bigint CHECK (price >= 0),
    photos         uuid[] NOT NULL CHECK (cardinality(photos) <= 10),
    body           text NOT NULL CHECK (char_length(body) <= 32768),
    created_at     timestamptz NOT NULL,
    updated_at     timestamptz NOT NULL,
    expires_at     timestamptz NOT NULL
);
CREATE INDEX listing_drafts_account_updated ON listing_drafts (account_id, updated_at DESC);
```

Run: `go test ./migrations/ && sqlfluff lint migrations/0042_listing_drafts.sql`
Expected: PASS, no sqlfluff finding.

- [ ] **Step 5: The store**

In `internal/catalog/repository/repository.go`, add after `Listings`:

```go
// Drafts persists listing drafts. Put takes a lock per account, so the
// count a create reads holds until it commits, and a share lock on the
// account's row, so no draft is written after the account's erasure. Put
// and List first delete the account's drafts that expired.
type Drafts interface {
	// Put writes account's draft id with c at now: a create when there is
	// none, domain.ErrDraftLimitReached when the account has
	// domain.MaxDrafts drafts, else a replace. Another account's draft is
	// domain.ErrDraftNotFound; a deleted account is
	// accountdomain.ErrSessionRevoked. It returns the draft as written and
	// whether it was created.
	Put(ctx context.Context, account, id uuid.UUID, c domain.DraftContent, now time.Time) (domain.ListingDraft, bool, error)
	// List is account's drafts that have not expired at now, last written
	// first, at most domain.MaxDrafts.
	List(ctx context.Context, account uuid.UUID, now time.Time) ([]domain.ListingDraft, error)
	// Delete deletes account's draft id; another account's draft, or none,
	// is left as it is.
	Delete(ctx context.Context, account, id uuid.UUID) error
	// DeleteAll deletes account's drafts, for its erasure.
	DeleteAll(ctx context.Context, account uuid.UUID) error
}
```

`internal/catalog/repository/draft_pg.go`:

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

	accountdomain "github.com/shopnexus/server2/internal/account/domain"
	"github.com/shopnexus/server2/internal/catalog/domain"
)

type pgDrafts struct{ db *pgxpool.Pool }

func NewDrafts(db *pgxpool.Pool) Drafts { return pgDrafts{db} }

const draftColumns = `id, account_id, schema_version, title, price, photos, body, created_at, updated_at, expires_at`

func scanDraft(row pgx.CollectableRow) (domain.ListingDraft, error) {
	var st domain.ListingDraftState
	if err := row.Scan(&st.ID, &st.AccountID, &st.Content.SchemaVersion, &st.Content.Title, &st.Content.Price,
		&st.Content.Photos, &st.Content.Body, &st.CreatedAt, &st.UpdatedAt, &st.ExpiresAt); err != nil {
		return domain.ListingDraft{}, fmt.Errorf("scan draft: %w", err)
	}
	return domain.RestoreListingDraft(st), nil
}

// deleteExpired deletes account's drafts that expired by now. Put and List
// run it first.
func deleteExpired(ctx context.Context, tx pgx.Tx, account uuid.UUID, now time.Time) error {
	if _, err := tx.Exec(ctx, `DELETE FROM listing_drafts WHERE account_id = @account AND expires_at <= @now`,
		pgx.StrictNamedArgs{"account": account, "now": now}); err != nil {
		return fmt.Errorf("delete expired drafts: %w", err)
	}
	return nil
}

func (s pgDrafts) Put(ctx context.Context, account, id uuid.UUID, c domain.DraftContent, now time.Time) (domain.ListingDraft, bool, error) {
	var out domain.ListingDraft
	var created bool
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext('drafts:' || @account::text))`,
			pgx.StrictNamedArgs{"account": account}); err != nil {
			return fmt.Errorf("lock drafts: %w", err)
		}
		// A write that commits after Erase waits for it here and then finds
		// the tombstone.
		var deleted bool
		err := tx.QueryRow(ctx, `SELECT status = 'deleted' FROM accounts WHERE id = @account FOR SHARE`,
			pgx.StrictNamedArgs{"account": account}).Scan(&deleted)
		if errors.Is(err, pgx.ErrNoRows) || (err == nil && deleted) {
			return accountdomain.ErrSessionRevoked
		}
		if err != nil {
			return fmt.Errorf("lock account: %w", err)
		}
		if err = deleteExpired(ctx, tx, account, now); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `SELECT `+draftColumns+` FROM listing_drafts WHERE id = @id FOR UPDATE`,
			pgx.StrictNamedArgs{"id": id})
		if err != nil {
			return fmt.Errorf("select draft: %w", err)
		}
		found, err := pgx.CollectRows(rows, scanDraft)
		if err != nil {
			return fmt.Errorf("read draft: %w", err)
		}
		var stored *domain.ListingDraft
		count := 0
		if len(found) == 1 {
			stored = &found[0]
		} else if err = tx.QueryRow(ctx, `SELECT count(*) FROM listing_drafts WHERE account_id = @account`,
			pgx.StrictNamedArgs{"account": account}).Scan(&count); err != nil {
			return fmt.Errorf("count drafts: %w", err)
		}
		if err = domain.CheckPut(stored, account, count); err != nil {
			return err
		}
		if stored == nil {
			out, created = domain.NewListingDraft(id, account, c, now), true
		} else {
			out = *stored
			out.Replace(c, now)
		}
		st := out.State()
		a := pgx.StrictNamedArgs{
			"id": st.ID, "account": st.AccountID, "schema_version": st.Content.SchemaVersion, "title": st.Content.Title,
			"price": st.Content.Price, "photos": st.Content.Photos, "body": st.Content.Body,
			"updated_at": st.UpdatedAt, "expires_at": st.ExpiresAt,
		}
		if created {
			a["created_at"] = st.CreatedAt
			// Another account's create of the same ID is the only race left,
			// since the lock is per account: the loser sees it as theirs.
			tag, err := tx.Exec(ctx, `INSERT INTO listing_drafts (`+draftColumns+`)
VALUES (@id, @account, @schema_version, @title, @price, @photos, @body, @created_at, @updated_at, @expires_at)
ON CONFLICT (id) DO NOTHING`, a)
			if err != nil {
				return fmt.Errorf("insert draft: %w", err)
			}
			if tag.RowsAffected() == 0 {
				return domain.ErrDraftNotFound
			}
			return nil
		}
		if _, err = tx.Exec(ctx, `UPDATE listing_drafts
SET schema_version = @schema_version, title = @title, price = @price, photos = @photos, body = @body,
    updated_at = @updated_at, expires_at = @expires_at
WHERE id = @id AND account_id = @account`, a); err != nil {
			return fmt.Errorf("update draft: %w", err)
		}
		return nil
	})
	if err != nil {
		return domain.ListingDraft{}, false, fmt.Errorf("put draft: %w", err)
	}
	return out, created, nil
}

func (s pgDrafts) List(ctx context.Context, account uuid.UUID, now time.Time) ([]domain.ListingDraft, error) {
	var out []domain.ListingDraft
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if err := deleteExpired(ctx, tx, account, now); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `SELECT `+draftColumns+` FROM listing_drafts WHERE account_id = @account
ORDER BY updated_at DESC, id DESC LIMIT @limit`, pgx.StrictNamedArgs{"account": account, "limit": domain.MaxDrafts})
		if err != nil {
			return fmt.Errorf("select drafts: %w", err)
		}
		if out, err = pgx.CollectRows(rows, scanDraft); err != nil {
			return fmt.Errorf("read drafts: %w", err)
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("list drafts: %w", err)
	}
	return out, nil
}

func (s pgDrafts) Delete(ctx context.Context, account, id uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM listing_drafts WHERE id = @id AND account_id = @account`,
		pgx.StrictNamedArgs{"id": id, "account": account}); err != nil {
		return fmt.Errorf("delete draft: %w", err)
	}
	return nil
}

func (s pgDrafts) DeleteAll(ctx context.Context, account uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM listing_drafts WHERE account_id = @account`,
		pgx.StrictNamedArgs{"account": account}); err != nil {
		return fmt.Errorf("delete drafts: %w", err)
	}
	return nil
}
```

`govet shadow` flags the `tag, err :=` inside `if created`; if it does, declare `var tag pgconn.CommandTag` before it and assign with `=` (import `github.com/jackc/pgx/v5/pgconn`).

- [ ] **Step 6: Run the store tests**

Run: `go test ./internal/catalog/repository/ ./internal/catalog/domain/ > tmp/task3.log 2>&1; tail -30 tmp/task3.log`
Expected: PASS.

- [ ] **Step 7: Lint and commit**

Run: `golangci-lint run ./internal/catalog/...`, the writing checker on the new comments, then:

```bash
git add migrations/0042_listing_drafts.sql migrations/listing_drafts_test.go internal/catalog/domain/ internal/catalog/repository/
git commit -m "feat(catalog): listing drafts, last write wins, 20 per account, gone after 30 days"
```

### Task 4: The use cases, erasure and the endpoints

**Files:**
- Create: `internal/catalog/service/listing_draft.go`, `internal/catalog/service/listing_draft_test.go`
- Modify: `internal/catalog/service/views.go`, `service.go`, `seller_left.go`, `helpers_test.go`
- Modify: `internal/catalog/catalog.go:31-36`, `internal/catalog/catalogtest/catalogtest.go:29-34`
- Create: `internal/catalog/handler/listing_draft.go`; modify `internal/catalog/handler/handler.go`
- Create: `e2e/listing_draft_test.go`

**Interfaces:**
- Consumes: `repository.Drafts`, `domain.DraftContent`, `domain.KeepPhotos` (Task 3); `mediasvc.Service.Extend`, `Gone` (Task 2) and `PresignPhoto`; the contract (Task 1).
- Produces: `service.Deps.Drafts`; `Service.PutDraft(ctx, account, id uuid.UUID, c domain.DraftContent) (DraftView, bool, error)`, `ListDrafts(ctx, account uuid.UUID) ([]DraftView, error)`, `DeleteDraft(ctx, account, id uuid.UUID) error`; `SellerLeft` also deletes the seller's drafts; views `DraftView{ID uuid.UUID; SchemaVersion int; Title string; Price *int64; Photos []DraftPhotoView; Body string; UpdatedAt, ExpiresAt time.Time}` and `DraftPhotoView{UploadID uuid.UUID; URL string}`; routes `GET /v1/listing-drafts`, `PUT|DELETE /v1/listing-drafts/{id}`; handlers `ListDrafts`, `PutDraft`, `DeleteDraft`.

- [ ] **Step 1: Write the failing service tests**

In `internal/catalog/service/helpers_test.go`, add `drafts repository.Drafts` to `env`, set it in `newEnv` (`drafts: repository.NewDrafts(db),`), and append:

```go
// photo uploads a JPEG for owner.
func (e env) photo(t *testing.T, owner uuid.UUID) uuid.UUID {
	t.Helper()
	return e.upload(t, owner, mediatest.JPEG(t, 64, 48))
}

// expiresAt is when media deletes the upload if nothing takes it.
func (e env) expiresAt(t *testing.T, id uuid.UUID) time.Time {
	t.Helper()
	u, err := mediarepo.NewUploads(e.db).Get(context.Background(), id)
	if err != nil {
		t.Fatal(err)
	}
	return u.ExpiresAt()
}

// content is a draft's content with title and photos.
func content(title string, photos ...uuid.UUID) domain.DraftContent {
	return domain.DraftContent{SchemaVersion: 1, Title: title, Price: new(int64(9_500_000)), Photos: photos, Body: `{"condition":"like_new"}`}
}

func photoIDs(v service.DraftView) []uuid.UUID {
	out := make([]uuid.UUID, len(v.Photos))
	for i, p := range v.Photos {
		out[i] = p.UploadID
	}
	return out
}
```

(imports: `mediarepo "github.com/shopnexus/server2/internal/media/repository"`.)

`internal/catalog/service/listing_draft_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"slices"
	"strings"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"

	accountdomain "github.com/shopnexus/server2/internal/account/domain"
	"github.com/shopnexus/server2/internal/catalog/domain"
	mediadomain "github.com/shopnexus/server2/internal/media/domain"
)

// kept reports whether a PUT kept the upload for about 30 days.
func kept(at time.Time) bool { return at.After(time.Now().Add(29 * 24 * time.Hour)) }

// A create keeps its photos 30 days; a replace keeps the new ones and
// leaves a dropped one to its own expiry; the list shows what is stored,
// with a URL per photo.
func TestPutDraftCreatesAndReplaces(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me := e.account(t)
	p, q := e.photo(t, me), e.photo(t, me)
	id := uuid.NewV7()
	v, created, err := e.catalog.PutDraft(ctx, me, id, content("iPhone 13", p, q, p))
	if err != nil || !created || !slices.Equal(photoIDs(v), []uuid.UUID{p, q}) || v.Photos[0].URL == "" || v.Body != `{"condition":"like_new"}` {
		t.Fatalf("create: %+v %v %v", v, created, err)
	}
	if !kept(e.expiresAt(t, p)) || !kept(e.expiresAt(t, q)) {
		t.Fatal("the photos were not kept")
	}
	dropped := e.expiresAt(t, p)
	v, created, err = e.catalog.PutDraft(ctx, me, id, content("iPhone 13 Pro", q))
	if err != nil || created || v.Title != "iPhone 13 Pro" || !slices.Equal(photoIDs(v), []uuid.UUID{q}) {
		t.Fatalf("replace: %+v %v %v", v, created, err)
	}
	if got := e.expiresAt(t, p); !got.Equal(dropped) {
		t.Fatalf("the dropped photo's expiry moved to %v", got)
	}
	list, err := e.catalog.ListDrafts(ctx, me)
	if err != nil || len(list) != 1 || list[0].ID != id || list[0].Title != "iPhone 13 Pro" || len(list[0].Photos) != 1 || list[0].Photos[0].URL == "" {
		t.Fatalf("list: %+v %v", list, err)
	}
}

func TestPutDraftRefusals(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me, other := e.account(t), e.account(t)
	theirID := uuid.NewV7()
	if _, _, err := e.catalog.PutDraft(ctx, other, theirID, content("Của họ")); err != nil {
		t.Fatal(err)
	}
	if _, _, err := e.catalog.PutDraft(ctx, me, theirID, content("")); !errors.Is(err, domain.ErrDraftNotFound) {
		t.Fatalf("another account's ID: %v", err)
	}

	mine, theirs := e.photo(t, me), e.photo(t, other)
	before := e.expiresAt(t, mine)
	if _, _, err := e.catalog.PutDraft(ctx, me, uuid.NewV7(), content("", mine, theirs)); !errors.Is(err, mediadomain.ErrInvalidUpload) {
		t.Fatalf("their photo: %v", err)
	}
	if got := e.expiresAt(t, mine); !got.Equal(before) {
		t.Fatalf("a refused PUT kept a photo until %v", got)
	}
	if list, _ := e.catalog.ListDrafts(ctx, me); len(list) != 0 {
		t.Fatalf("a refused PUT wrote %d drafts", len(list))
	}

	first := uuid.NewV7()
	for i := range domain.MaxDrafts {
		id := uuid.NewV7()
		if i == 0 {
			id = first
		}
		if _, _, err := e.catalog.PutDraft(ctx, me, id, content("")); err != nil {
			t.Fatal(err)
		}
	}
	if _, _, err := e.catalog.PutDraft(ctx, me, uuid.NewV7(), content("21st")); !errors.Is(err, domain.ErrDraftLimitReached) {
		t.Fatalf("the 21st: %v", err)
	}
	if _, created, err := e.catalog.PutDraft(ctx, me, first, content("edited at 20")); err != nil || created {
		t.Fatalf("a replace at the limit: %v %v", created, err)
	}
}

// A seller at 20 drafts, all past their 30 days, creates one: the expired
// ones go first and free their places. The same goes for the draft the
// phone sends again after the server let it expire: it comes back.
func TestExpiredDraftsFreeTheirPlaces(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me := e.account(t)
	old := time.Now().Add(-domain.DraftLife - time.Hour)
	revived := uuid.NewV7()
	for i := range domain.MaxDrafts {
		id := uuid.NewV7()
		if i == 0 {
			id = revived
		}
		if _, _, err := e.drafts.Put(ctx, me, id, content(""), old); err != nil {
			t.Fatal(err)
		}
	}
	if _, created, err := e.catalog.PutDraft(ctx, me, uuid.NewV7(), content("new")); err != nil || !created {
		t.Fatalf("a create at 20 expired drafts: %v %v", created, err)
	}
	if _, created, err := e.catalog.PutDraft(ctx, me, revived, content("back")); err != nil || !created {
		t.Fatalf("an expired draft sent again: %v %v", created, err)
	}
	list, err := e.catalog.ListDrafts(ctx, me)
	if err != nil || len(list) != 2 || list[0].ID != revived {
		t.Fatalf("%d drafts %v", len(list), err)
	}
}

// A photo a listing took, one whose 24 hours ran out while the phone was
// offline (MediaExpire has not run yet), and one with no upload are left
// out of what is stored; the rest syncs.
func TestPutDraftDropsGonePhotos(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me := e.account(t)
	taken, stale, good := e.photo(t, me), e.photo(t, me), e.photo(t, me)
	if err := e.media.Attach(ctx, me, uuid.NewV7(), []uuid.UUID{taken}); err != nil {
		t.Fatal(err)
	}
	if _, err := e.db.Exec(ctx, `UPDATE uploads SET expires_at = now() - interval '1 hour' WHERE id = @id`,
		pgx.StrictNamedArgs{"id": stale}); err != nil {
		t.Fatal(err)
	}
	v, _, err := e.catalog.PutDraft(ctx, me, uuid.NewV7(), content("", taken, stale, good, uuid.NewV7()))
	if err != nil || !slices.Equal(photoIDs(v), []uuid.UUID{good}) {
		t.Fatalf("%+v %v", v, err)
	}
	if list, _ := e.drafts.List(ctx, me, time.Now()); len(list) != 1 || !slices.Equal(list[0].Photos(), []uuid.UUID{good}) {
		t.Fatalf("stored %+v", list)
	}
}

// A photo a listing took after the PUT leaves the list's answer without a
// write to the draft.
func TestListDraftsLeavesTakenPhotosOut(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me := e.account(t)
	taken, left := e.photo(t, me), e.photo(t, me)
	put, _, err := e.catalog.PutDraft(ctx, me, uuid.NewV7(), content("", taken, left))
	if err != nil {
		t.Fatal(err)
	}
	if err = e.media.Attach(ctx, me, uuid.NewV7(), []uuid.UUID{taken}); err != nil {
		t.Fatal(err)
	}
	list, err := e.catalog.ListDrafts(ctx, me)
	if err != nil || len(list) != 1 || !slices.Equal(photoIDs(list[0]), []uuid.UUID{left}) || !strings.Contains(list[0].Photos[0].URL, left.String()) ||
		list[0].UpdatedAt.Sub(put.UpdatedAt).Abs() > time.Millisecond { // no write: the time is the PUT's, to the microsecond
		t.Fatalf("%+v %v", list, err)
	}
}

// Delete is quiet about a draft that is gone or another account's, and
// leaves the photos to their own expiry.
func TestDeleteDraft(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me, other := e.account(t), e.account(t)
	id, p := uuid.NewV7(), e.photo(t, me)
	if _, _, err := e.catalog.PutDraft(ctx, me, id, content("", p)); err != nil {
		t.Fatal(err)
	}
	if err := e.catalog.DeleteDraft(ctx, other, id); err != nil {
		t.Fatal(err)
	}
	if list, _ := e.catalog.ListDrafts(ctx, me); len(list) != 1 {
		t.Fatal("another account deleted it")
	}
	thirty := e.expiresAt(t, p)
	for range 2 {
		if err := e.catalog.DeleteDraft(ctx, me, id); err != nil {
			t.Fatal(err)
		}
	}
	if list, _ := e.catalog.ListDrafts(ctx, me); len(list) != 0 {
		t.Fatal("still there")
	}
	if got := e.expiresAt(t, p); !got.Equal(thirty) {
		t.Fatalf("the photo's expiry moved to %v", got)
	}
}

// A PUT after the account's erasure writes nothing; the erasure's
// SellerLeft deletes the drafts, a second run finding none.
func TestDraftsAndErasure(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me, gone := e.account(t), e.account(t)
	for range 2 {
		if _, _, err := e.catalog.PutDraft(ctx, me, uuid.NewV7(), content("")); err != nil {
			t.Fatal(err)
		}
	}
	for range 2 {
		if err := e.catalog.SellerLeft(ctx, me); err != nil {
			t.Fatal(err)
		}
	}
	if list, _ := e.drafts.List(ctx, me, time.Now()); len(list) != 0 {
		t.Fatalf("%d drafts after erasure", len(list))
	}
	if _, err := e.db.Exec(ctx, `UPDATE accounts
SET status = 'deleted', deleted_at = now(), display_name = NULL, bio = NULL, avatar_key = NULL WHERE id = @id`,
		pgx.StrictNamedArgs{"id": gone}); err != nil {
		t.Fatal(err)
	}
	if _, _, err := e.catalog.PutDraft(ctx, gone, uuid.NewV7(), content("")); !errors.Is(err, accountdomain.ErrSessionRevoked) {
		t.Fatalf("a deleted account's put: %v", err)
	}
}
```

Run: `go test ./internal/catalog/service/ -run 'Draft|ExpiredDrafts'`
Expected: FAIL to build, `e.catalog.PutDraft undefined`.

- [ ] **Step 2: The views and the use cases**

Append to `internal/catalog/service/views.go`:

```go
// DraftView is the ListingDraft schema in api/schemas/catalog.yaml.
type DraftView struct {
	ID            uuid.UUID        `json:"id"`
	SchemaVersion int              `json:"schema_version"`
	Title         string           `json:"title"`
	Price         *int64           `json:"price"`
	Photos        []DraftPhotoView `json:"photos"`
	Body          string           `json:"body"`
	UpdatedAt     time.Time        `json:"updated_at"`
	ExpiresAt     time.Time        `json:"expires_at"`
}

// DraftPhotoView is the ListingDraftPhoto schema: the URL reads the
// original upload for an hour.
type DraftPhotoView struct {
	UploadID uuid.UUID `json:"upload_id"`
	URL      string    `json:"url"`
}
```

`internal/catalog/service/listing_draft.go`:

```go
package service

import (
	"context"
	"fmt"
	"uuid"

	"github.com/shopnexus/server2/internal/catalog/domain"
)

// PutDraft writes the caller's draft id; the last write wins. It drops the
// photos a listing took or that expired, keeps the others 30 days in
// media, then writes the row. Media and catalog share no transaction: an
// extension whose write then fails only keeps a photo longer.
func (c *Catalog) PutDraft(ctx context.Context, account, id uuid.UUID, content domain.DraftContent) (DraftView, bool, error) {
	now := c.now()
	gone, err := c.media.Gone(ctx, account, content.Photos)
	if err != nil {
		return DraftView{}, false, fmt.Errorf("find the photos that are gone: %w", err)
	}
	content.Photos = domain.KeepPhotos(content.Photos, gone)
	if err = c.media.Extend(ctx, account, content.Photos); err != nil {
		return DraftView{}, false, fmt.Errorf("keep the photos: %w", err)
	}
	d, created, err := c.drafts.Put(ctx, account, id, content, now)
	if err != nil {
		return DraftView{}, false, fmt.Errorf("put draft: %w", err)
	}
	v, err := c.draftView(ctx, d, nil)
	return v, created, err
}

// ListDrafts reads the caller's drafts, last written first, once their
// expired drafts are deleted. A photo a listing took or that expired is
// left out of the answer, without a write to the draft.
func (c *Catalog) ListDrafts(ctx context.Context, account uuid.UUID) ([]DraftView, error) {
	ds, err := c.drafts.List(ctx, account, c.now())
	if err != nil {
		return nil, fmt.Errorf("list drafts: %w", err)
	}
	var all []uuid.UUID
	for i := range ds {
		all = append(all, ds[i].Photos()...)
	}
	gone, err := c.media.Gone(ctx, account, all)
	if err != nil {
		return nil, fmt.Errorf("find the photos that are gone: %w", err)
	}
	out := make([]DraftView, len(ds))
	for i := range ds {
		if out[i], err = c.draftView(ctx, ds[i], gone); err != nil {
			return nil, err
		}
	}
	return out, nil
}

// DeleteDraft deletes the caller's draft id; another account's draft, or
// none, changes nothing. Its photos expire on their own.
func (c *Catalog) DeleteDraft(ctx context.Context, account, id uuid.UUID) error {
	if err := c.drafts.Delete(ctx, account, id); err != nil {
		return fmt.Errorf("delete draft: %w", err)
	}
	return nil
}

// draftView is d without the photos in gone, each other photo with a
// presigned URL valid for an hour. PutDraft and ListDrafts call it.
func (c *Catalog) draftView(ctx context.Context, d domain.ListingDraft, gone []uuid.UUID) (DraftView, error) {
	dc := d.Content()
	photos := domain.KeepPhotos(dc.Photos, gone)
	v := DraftView{
		ID: d.ID(), SchemaVersion: dc.SchemaVersion, Title: dc.Title, Price: dc.Price, Body: dc.Body,
		Photos: make([]DraftPhotoView, 0, len(photos)), UpdatedAt: d.UpdatedAt(), ExpiresAt: d.ExpiresAt(),
	}
	for _, id := range photos {
		url, err := c.media.PresignPhoto(ctx, id)
		if err != nil {
			return DraftView{}, fmt.Errorf("presign a photo: %w", err)
		}
		v.Photos = append(v.Photos, DraftPhotoView{UploadID: id, URL: url})
	}
	return v, nil
}
```

In `internal/catalog/service/seller_left.go`, `SellerLeft` deletes the drafts first; its comment and opening become:

```go
// SellerLeft deletes the seller's drafts, then their listings a page at a
// time; a deleted listing leaves the filter, so each round reads the first
// page again. The drafts' photos expire on their own.
func (c *Catalog) SellerLeft(ctx context.Context, seller uuid.UUID) error {
	if err := c.drafts.DeleteAll(ctx, seller); err != nil {
		return fmt.Errorf("delete drafts: %w", err)
	}
	for {
```

In `internal/catalog/service/service.go`, add to `Service` after `Delete`:

```go
	// PutDraft writes the caller's draft id, the last write winning, and
	// returns it as stored and whether it was created.
	PutDraft(ctx context.Context, account, id uuid.UUID, c domain.DraftContent) (DraftView, bool, error)
	// ListDrafts lists the caller's drafts in full, last written first.
	ListDrafts(ctx context.Context, account uuid.UUID) ([]DraftView, error)
	// DeleteDraft deletes one of the caller's drafts; none changes nothing.
	DeleteDraft(ctx context.Context, account, id uuid.UUID) error
```

the `SellerLeft` comment there becomes `// SellerLeft deletes a deleted seller's drafts and every listing of theirs that is not sold or deleted, each with listing.deleted; the worker calls it on account.deleted, and a repeated call finds nothing left.`; add `Drafts repository.Drafts` to `Deps` after `Listings`, `drafts repository.Drafts` to `Catalog`, and `drafts: d.Drafts,` in `New`. In `internal/catalog/catalog.go`'s `service.Deps`, add `Drafts: repository.NewDrafts(d.Pool),`; in `internal/catalog/catalogtest/catalogtest.go`'s `deps`, add `Drafts: repository.NewDrafts(db),`. The comment of `worker.AccountWatch` becomes `// AccountWatch deletes a deleted seller's listings and drafts: Mount subscribes Deleted to account.deleted.`

- [ ] **Step 3: Run the catalog tests**

Run: `go test ./internal/catalog/... > tmp/task4.log 2>&1; tail -40 tmp/task4.log`
Expected: PASS (`TestDeletedCallsSellerLeft` in the worker is unchanged: the worker still calls only `SellerLeft`).

- [ ] **Step 4: Write the failing e2e tests**

`e2e/listing_draft_test.go`:

```go
package e2e

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"

	catalogdomain "github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/platform/testenv"
)

type listingDraft struct {
	ID            string `json:"id"`
	SchemaVersion int    `json:"schema_version"`
	Title         string `json:"title"`
	Price         *int64 `json:"price"`
	Body          string `json:"body"`
	Photos        []struct {
		UploadID string `json:"upload_id"`
		URL      string `json:"url"`
	} `json:"photos"`
	UpdatedAt time.Time `json:"updated_at"`
	ExpiresAt time.Time `json:"expires_at"`
}

// draftBody is a draft's PUT with the given photos.
func draftBody(title string, photos ...string) map[string]any {
	if photos == nil {
		photos = []string{}
	}
	return map[string]any{
		"schema_version": 1, "title": title, "price": 1_500_000, "photos": photos, "body": `{"condition":"used"}`,
	}
}

func TestListingDraftLifecycle(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	auth := bearer(me.AccessToken)
	photo := upload(t, me.AccessToken, photoWithGPS(t))
	path := "/v1/listing-drafts/" + uuid.NewV7().String()

	d := expect[listingDraft](t, call(t, "PUT", path, draftBody("Xe đạp", photo), auth), http.StatusCreated)
	if d.Title != "Xe đạp" || len(d.Photos) != 1 || d.Photos[0].UploadID != photo || d.Body != `{"condition":"used"}` ||
		d.ExpiresAt.Sub(d.UpdatedAt) != catalogdomain.DraftLife {
		t.Fatalf("%+v", d)
	}
	req, err := http.NewRequestWithContext(t.Context(), http.MethodGet, d.Photos[0].URL, http.NoBody)
	if err != nil {
		t.Fatal(err)
	}
	got, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	_ = got.Body.Close()
	if got.StatusCode != http.StatusOK {
		t.Fatalf("the photo's URL: %d", got.StatusCode)
	}

	if d = expect[listingDraft](t, call(t, "PUT", path, draftBody("Xe đạp Asama", photo), auth), http.StatusOK); d.Title != "Xe đạp Asama" {
		t.Fatalf("%+v", d)
	}
	list := expect[struct {
		Items []listingDraft `json:"items"`
	}](t, call(t, "GET", "/v1/listing-drafts", nil, auth), http.StatusOK)
	if len(list.Items) != 1 || list.Items[0].Title != "Xe đạp Asama" || len(list.Items[0].Photos) != 1 {
		t.Fatalf("%+v", list)
	}
	check(t, "delete", call(t, "DELETE", path, nil, auth), http.StatusNoContent, "")
	check(t, "delete again", call(t, "DELETE", path, nil, auth), http.StatusNoContent, "")
	if list = expect[struct {
		Items []listingDraft `json:"items"`
	}](t, call(t, "GET", "/v1/listing-drafts", nil, auth), http.StatusOK); len(list.Items) != 0 {
		t.Fatalf("%+v", list)
	}
}

func TestListingDraftRefusals(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	other, _ := newAccount(t)
	auth := bearer(me.AccessToken)
	fresh := func() string { return "/v1/listing-drafts/" + uuid.NewV7().String() }
	theirs := fresh()
	expectStatus(t, call(t, "PUT", theirs, draftBody("Của họ"), bearer(other.AccessToken)), http.StatusCreated)

	check(t, "put signed out", call(t, "PUT", fresh(), draftBody("")), http.StatusUnauthorized, "unauthenticated")
	check(t, "list signed out", call(t, "GET", "/v1/listing-drafts", nil), http.StatusUnauthorized, "unauthenticated")
	check(t, "delete signed out", call(t, "DELETE", fresh(), nil), http.StatusUnauthorized, "unauthenticated")
	check(t, "put a bad ID", call(t, "PUT", "/v1/listing-drafts/nope", draftBody(""), auth), http.StatusBadRequest, "invalid_request")
	check(t, "delete a bad ID", call(t, "DELETE", "/v1/listing-drafts/nope", nil, auth), http.StatusBadRequest, "invalid_request")
	check(t, "a 101-letter title", call(t, "PUT", fresh(), draftBody(strings.Repeat("a", 101)), auth), http.StatusBadRequest, "invalid_request")
	big := draftBody("")
	big["body"] = strings.Repeat("a", 32769)
	check(t, "a body over 32768 characters", call(t, "PUT", fresh(), big, auth), http.StatusBadRequest, "invalid_request")
	check(t, "another account's ID", call(t, "PUT", theirs, draftBody(""), auth), http.StatusNotFound, "draft_not_found")
	check(t, "their photo", call(t, "PUT", fresh(), draftBody("", upload(t, other.AccessToken, photoWithGPS(t))), auth),
		http.StatusUnprocessableEntity, "invalid_upload")
	check(t, "delete another account's", call(t, "DELETE", theirs, nil, auth), http.StatusNoContent, "")
	expectStatus(t, call(t, "GET", "/v1/listing-drafts", nil, bearer(other.AccessToken)), http.StatusOK)

	for range catalogdomain.MaxDrafts {
		expectStatus(t, call(t, "PUT", fresh(), draftBody(""), auth), http.StatusCreated)
	}
	check(t, "the 21st", call(t, "PUT", fresh(), draftBody(""), auth), http.StatusConflict, "draft_limit_reached")
}

// A deleted account's drafts go.
func TestDeletedAccountsDraftsGo(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	expectStatus(t, call(t, "PUT", "/v1/listing-drafts/"+uuid.NewV7().String(), draftBody(""), bearer(me.AccessToken)), http.StatusCreated)
	check(t, "delete", call(t, "DELETE", "/v1/accounts/me", nil, bearer(me.AccessToken)), http.StatusNoContent, "")
	testenv.Eventually(t, 30*time.Second, func() error {
		var n int
		if err := db.QueryRow(context.Background(), `SELECT count(*) FROM listing_drafts WHERE account_id = @account::uuid`,
			pgx.StrictNamedArgs{"account": me.Account.ID}).Scan(&n); err != nil {
			return err
		}
		if n != 0 {
			return fmt.Errorf("%d drafts", n)
		}
		return nil
	})
}
```

Run: `go test ./e2e/ -run 'ListingDraft|TestDeletedAccountsDraftsGo'`
Expected: FAIL, `PUT /v1/listing-drafts/…: 404` (no route).

- [ ] **Step 5: The handlers**

`internal/catalog/handler/listing_draft.go`:

```go
package handler

import (
	"net/http"
	"uuid"

	"github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/catalog/service"
	"github.com/shopnexus/server2/internal/platform/httpx"
)

// putDraftRequest is the ListingDraftInput schema with the draft's ID.
type putDraftRequest struct {
	ID            uuid.UUID   `json:"-"              path:"id"`
	SchemaVersion int         `json:"schema_version"`
	Title         string      `json:"title"`
	Price         *int64      `json:"price"`
	Photos        []uuid.UUID `json:"photos"`
	Body          string      `json:"body"`
}

// PutDraft serves PUT /v1/listing-drafts/{id}: 201 for a create, 200 for a
// replace.
func (h *Handler) PutDraft(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in putDraftRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	v, created, err := h.svc.PutDraft(r.Context(), p.AccountID, in.ID, domain.DraftContent{
		SchemaVersion: in.SchemaVersion, Title: in.Title, Price: in.Price, Photos: in.Photos, Body: in.Body,
	})
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	status := http.StatusOK
	if created {
		status = http.StatusCreated
	}
	httpx.Respond(w, status, v)
}

// ListDrafts serves GET /v1/listing-drafts.
func (h *Handler) ListDrafts(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	items, err := h.svc.ListDrafts(r.Context(), p.AccountID)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, list[service.DraftView]{Items: items})
}

// DeleteDraft serves DELETE /v1/listing-drafts/{id}.
func (h *Handler) DeleteDraft(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in listingRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.DeleteDraft(r.Context(), p.AccountID, in.ID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

(`listingRequest` is the `{id}` path struct of `listing_state.go`; let `golangci-lint fmt` align the struct tags.)

In `internal/catalog/handler/handler.go`'s `Register`, after `GET /v1/me/listings`:

```go
	r.Handle("GET /v1/listing-drafts", protect(http.HandlerFunc(h.ListDrafts)))
	r.Handle("PUT /v1/listing-drafts/{id}", protect(http.HandlerFunc(h.PutDraft)))
	r.Handle("DELETE /v1/listing-drafts/{id}", protect(http.HandlerFunc(h.DeleteDraft)))
```

- [ ] **Step 6: Run the route test, the e2e tests, then everything**

Run: `go test ./internal/app/ -run TestRoutesMatchSpec && go test ./e2e/ -run 'ListingDraft|TestDeletedAccountsDraftsGo|TestListing|TestPostListing' > tmp/task4-e2e.log 2>&1; tail -40 tmp/task4-e2e.log`
Expected: PASS.

Run: `make test > tmp/make-test.log 2>&1; tail -40 tmp/make-test.log`
Expected: PASS, every documented status observed and `golangci-lint run` clean. `ps aux | grep '[g]o test'` shows nothing left running.

- [ ] **Step 7: Commit**

Run the writing checker on the new comments, then:

```bash
git add internal/catalog/ e2e/listing_draft_test.go
git commit -m "feat(catalog): /v1/listing-drafts, and erasure deletes the drafts"
```

### Task 5: Docs and the definition-of-done run

**Files:**
- Modify: `server/ARCHITECTURE.md` (sections Tables and aggregates, Media, Catalog, Erasure)
- Modify: `~/shopnexus/checklist.md:40`
- Modify: `~/shopnexus/docs/superpowers/specs/2026-11-13-listing-drafts-sync-design.md`

- [ ] **Step 1: `ARCHITECTURE.md`**

- Tables and aggregates: a row `ListingDraft | listing_drafts | module catalog; photos uuid[], body text the app owns; no write_id: the last write wins`.
- Media: in the first paragraph, an upload's wait ends at `uploads.expires_at`, a day after it was created unless a draft extended it; a bullet: `Extend(owner, ids)` all or none (the owner's photo, waiting before `expires_at`, in the store as declared; else `invalid_upload`) sets `expires_at = max(expires_at, now + 30 days)` (`domain.ExtendFor`) and leaves the upload `waiting`, so `Attach` takes it; `Gone(owner, ids)` names the uploads a holder took, those that expired or wait past `expires_at`, and IDs with no row; `MediaExpire` still wakes a day after the upload and, while `expires_at` is ahead, sends itself again keyed `<upload id>/<expires_at Unix seconds>`; `QueryUpload` and every "before its expiry" check read `expires_at`.
- Catalog: the sentence `Drafts stay on the device; the server receives a complete listing.` becomes `A seller's drafts are kept on the server for their other devices (decided 2026-11-13, spec ~/shopnexus/docs/superpowers/specs/2026-11-13-listing-drafts-sync-design.md); the posting rules apply only to the complete listing POST /v1/listings receives.`, and a bullet group: `PUT /v1/listing-drafts/{id}` (201/200, the last write wins, the app mints the ID), `GET /v1/listing-drafts` (every draft in full, no pages) and `DELETE` (204); 20 per account under `pg_advisory_xact_lock(hashtext('drafts:' || account))` and a share lock on the account's row; a draft lives 30 days after its last write and the account's next GET or PUT deletes it, with no job; typed columns and the app's `body` string with `schema_version`, never read; the PUT drops the photos `Gone` names, extends the rest, then writes, sharing no transaction with media; GET leaves gone photos out without writing; photo URLs are `PresignPhoto`; `ListingInput` is the listing body (was `ListingDraft`); a suspended account still writes its drafts.
- Erasure: in the list of what each module clears, `catalog deletes the listings that are not sold (…) and the drafts`; the sentence `Media does nothing: a waiting upload, a video read's frames and a link read's copies among them, expires within a day anyway, …` becomes `Media does nothing: a waiting upload, a video read's frames and a link read's copies among them, expires within a day anyway, and a draft's photo within 30 days of the draft's last write, in the private uploads/ that no URL reaches once the drafts are gone; …` (the rest unchanged).

Run the writing checker on `ARCHITECTURE.md`.

- [ ] **Step 2: The checklist**

In `~/shopnexus/checklist.md`, line 40 becomes `- [x] Lưu nháp tin đăng trên server: `/v1/listing-drafts` (PUT tạo hoặc thay, GET cả danh sách, DELETE), tối đa 20 nháp, xóa sau 30 ngày không sửa, ảnh của nháp giữ 30 ngày (app chưa nối)`. If the app's plan has already changed the line, keep its words for the app and add the server's.

- [ ] **Step 3: The spec**

Add a "Changed while planning (plan `2026-11-13-server2-listing-drafts.md`)" list under the spec's status line with the items of "Deviations from the spec" above, one line each.

- [ ] **Step 4: Definition of done**

Run, in the server worktree after `git rebase main`:

```bash
make test > tmp/done.log 2>&1; tail -20 tmp/done.log
grep -rn '#/ListingDraft"' api/paths/catalog.yaml
```

Expected: `make test` passes; the grep shows only the `putListingDraft` responses, so no listing body names `ListingDraft` any more. `ps aux | grep '[g]o test'` shows nothing.

- [ ] **Step 5: Commit**

```bash
cd ~/shopnexus/server && git add ARCHITECTURE.md && git commit -m "docs: listing drafts in ARCHITECTURE.md"
cd ~/shopnexus && git add checklist.md && git commit -m "build: checklist ticks drafts kept on the server"
cd ~/shopnexus/docs && git add superpowers/specs/2026-11-13-listing-drafts-sync-design.md && git commit -m "spec(drafts): listing drafts as planned"
```

---

## Self-review

- Spec coverage: the API table and both schemas (Task 1, handlers in Task 4); the errors `draft_not_found` for another account's ID, `draft_limit_reached`, `invalid_upload` and `invalid_request` from the schema, the 32,768-character body included (Tasks 1, 3, 4); the table (Task 3); the PUT in the spec's order, Gone, Extend, then one transaction with the lock, the tombstone, the lazy delete, the read, the limit and the write (Tasks 3, 4); GET with the lazy delete, gone photos left out without a write, presigned URLs (Tasks 3, 4); DELETE (Tasks 3, 4); photos in media, `expires_at`, `Extend`, `MediaExpire` sending itself again, `Gone`, `Attach` of an extended upload (Task 2); erasure (Task 4, e2e too); the `ListingInput` rename in the spec and in Go (Task 1); the testing list (use cases in Task 4 with the two concurrent creates at 19 in Task 3's store test; media in Task 2; erasure and HTTP in Task 4). ARCHITECTURE.md, the checklist and the spec in Task 5.
- Types: `Drafts.Put` returns `(domain.ListingDraft, bool, error)` in Tasks 3 and 4; `DraftContent.Body` is a string in the domain, the store, the view and the handler; `draftView(ctx, d, gone)` takes `nil` from `PutDraft` (the photos were just checked) and the batch's gone photos from `ListDrafts`.
- Review Focus items have tests: 1 `TestPutDraftDropsGonePhotos` (4); 2 `TestCheckPut`, `TestTwoCreatesAtNineteen` (3) and `TestPutDraftRefusals` (4); 3 `TestExpiredDraftsGo` (3) and `TestExpiredDraftsFreeTheirPlaces` (4); 4 `TestExtendedTwiceWaitsForTheLater` (2); 5 `TestListDraftsLeavesTakenPhotosOut` (4).
