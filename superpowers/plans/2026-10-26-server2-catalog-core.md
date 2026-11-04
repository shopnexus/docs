# server2 catalog core and media: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sellers post, edit, hide, mark sold and delete single-item listings with photos that a Restate flow strips of EXIF and resizes; anyone views an active listing.

**Architecture:** Two modules in the four-layer layout. `media` owns uploads: presigned PUTs to RustFS, the `MediaProcess` and `MediaExpire` Restate services. `catalog` owns listings, categories and regions, and the `ListingPublish` Restate service that turns a listing `active` once its photos are processed. `platform/objectstore` wraps RustFS's S3 API. Events go through the outbox in the change's transaction.

**Tech Stack:** Go 1.27, pgx v5, Restate Go SDK v1.1.0, `github.com/minio/minio-go/v7` v7.4.1, `golang.org/x/image` v0.47.0, RustFS `rustfs/rustfs:1.0.4`.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-10-26-server2-catalog-core-design.md`

## Global Constraints

- Spec first: each endpoint, schema and error is in `api/` before its code; e2e status coverage must observe every declared status.
- Layers per module: `domain`, `repository`, `service`, `handler`; Restate services in `service/*_durable.go`; depguard rules extended to `media` and `catalog`.
- Configuration has no defaults: `OBJECT_STORE_ENDPOINT`, `OBJECT_STORE_REGION`, `OBJECT_STORE_ACCESS_KEY`, `OBJECT_STORE_SECRET_KEY`, `OBJECT_STORE_BUCKET`, `MEDIA_PUBLIC_URL` set in `.env.example`, `.env.test`, Compose and every test helper.
- Listing rules: title 1–70, price ≥ 10,000 đồng, description ≤ 1,500, 1–10 photos, ≤ 10 marks (text 1–200), ≤ 20 specs (label and value 1–50), condition `new|like_new|used`, category level 2, commune from the list.
- Posting checks in order: `account_suspended` 403, `phone_required` 403, `listing_cap_reached` 409 (20 on sale or hidden), `invalid_listing` 422.
- Uploads: `image/jpeg|png|webp`, ≤ 15 MB, presigned for 15 minutes, expired after 24 hours unless attached. Processing: ≤ 40 megapixels, JPEG output 1600 px long side and a 400 px thumbnail, no EXIF.
- Another account's listing is 404 `listing_not_found`, never 403.
- No commits unless the user asks; each task ends on a green `make test`.
- Comments, docs and migrations' comments go through the humanizing-writing checker.

## Review Focus

1. A decompression bomb (small file, huge dimensions): refused before decoding by reading the header's dimensions (Task 4 test `TestProcessRefusesHugeImages`).
2. A JPEG with GPS EXIF: the stored photo and thumbnail carry no EXIF (Task 4 test `TestProcessDropsExif`).
3. Posting with an upload that belongs to another account, was never PUT, or is already attached: 422 `invalid_upload` (Task 7 tests).
4. Two posts racing past the 20-listing cap: at most 20 listings on sale or hidden (Task 6 test `TestCapHoldsUnderRace`, enforced in the repository's insert).
5. An upload attached to a listing and processed: `MediaExpire` 24 hours later leaves it alone (Task 3 test `TestExpireLeavesAttachedUploads`).

---

### Task 1: administrative regions

**Files:**
- Create: `migrations/0005_regions.sql`, `tmp/regions/` (scratch: source files and the generator script, not committed)

- [ ] **Step 1: Find the source.** The 2025 administrative units (34 provinces, about 3,300 communes after the 1 July 2025 merger) with a centroid per commune. Prefer, in order: an official government dataset with coordinates; an official list of codes and names joined to an open boundary dataset (GeoJSON of the new communes) whose centroids you compute; a well-maintained open dataset citing the official decision. Record the source URL, its licence and the decision number it follows in the migration's header comment. If no source gives centroids for at least 99% of communes, stop and ask the user.
- [ ] **Step 2: Generate** `0005_regions.sql` with a script kept in `tmp/regions/`:

  ```sql
  -- Provinces and communes after the 2025 merger, with each commune's
  -- centroid. Source: <url>, <licence>, following <decision>.
  CREATE TABLE provinces (
      code text PRIMARY KEY,
      name text NOT NULL
  );
  CREATE TABLE communes (
      code          text PRIMARY KEY,
      province_code text NOT NULL REFERENCES provinces (code),
      name          text NOT NULL,
      lat           double precision NOT NULL,
      lng           double precision NOT NULL
  );
  CREATE INDEX communes_province ON communes (province_code, name);
  INSERT INTO provinces (code, name) VALUES ...;
  INSERT INTO communes (code, province_code, name, lat, lng) VALUES ...;
  ```

  Coordinates rounded to 4 decimals. Drop a commune without a centroid and list the dropped ones in the comment.
- [ ] **Step 3: Test** in `internal/platform/postgres/migrate_test.go` style, a new `internal/catalog/repository/region_pg_test.go` comes in Task 5; here run `make test` (the template rebuilds with the migration) and check counts with `psql` against a pgtest clone: 34 provinces, communes within 1% of the source's count.

### Task 2: object store and RustFS

**Files:**
- Modify: `docker-compose.yml`, `docker-compose.test.yml`, `.env.example`, `.env.test`, `Makefile` (bucket creation), `internal/platform/config/config.go`, `internal/platform/config/config_test.go`
- Create: `internal/platform/objectstore/objectstore.go`, `internal/platform/objectstore/objectstore_test.go`, `internal/platform/objectstore/objectstoretest/objectstoretest.go`

**Interfaces:**
- Produces:
  ```go
  // config
  type ObjectStoreConfig struct {
      Endpoint, Region, AccessKey, SecretKey, Bucket string
      PublicURL string // MEDIA_PUBLIC_URL: where media/ objects are read
  }
  // Config gains ObjectStore ObjectStoreConfig.

  // objectstore
  type Store struct { /* minio client, bucket */ }
  func New(cfg config.ObjectStoreConfig) (*Store, error)
  // PresignPut returns a URL and the headers a PUT of exactly size bytes of
  // contentType to key must carry, valid for ttl.
  func (s *Store) PresignPut(ctx context.Context, key, contentType string, size int64, ttl time.Duration) (url string, headers map[string]string, err error)
  func (s *Store) Stat(ctx context.Context, key string) (size int64, contentType string, err error) // ErrNotFound
  func (s *Store) Get(ctx context.Context, key string) (io.ReadCloser, error)
  func (s *Store) Put(ctx context.Context, key, contentType string, r io.Reader, size int64) error
  func (s *Store) Delete(ctx context.Context, key string) error // absent is not an error
  func (s *Store) PublicURL(key string) string
  var ErrNotFound = errors.New("object not found")
  ```

- [ ] **Step 1: Compose.** Add service `rustfs` (`rustfs/rustfs:1.0.4`) to both stacks: `RUSTFS_ACCESS_KEY`, `RUSTFS_SECRET_KEY`, `RUSTFS_VOLUMES=/data`, `RUSTFS_ADDRESS=0.0.0.0:9000`, console off, healthcheck `curl -fsS http://127.0.0.1:9000/health`. Dev publishes 9000 on `127.0.0.1:56900` and keeps a volume; test publishes `127.0.0.1:56901` on tmpfs with a `mem_limit`, as the test Postgres does. Values come from the env files; Compose interpolation uses `${VAR:?}`, never a default.
- [ ] **Step 2: Bucket and policy.** A one-shot step in `make run` and `make test` (after `up --wait`) creates the bucket and makes `media/*` public-read: `go run ./cmd/objectstore-init` (new command, reads the config, `MakeBucket` if missing, `SetBucketPolicy` with `s3:GetObject` on `arn:aws:s3:::<bucket>/media/*`).
- [ ] **Step 3: Failing tests.** `config_test.go`: a missing `OBJECT_STORE_*` or `MEDIA_PUBLIC_URL` names itself. `objectstore_test.go` against the test stack (skip under `-short`): presign a PUT, `http.Put` the bytes with the returned headers, `Stat` returns size and type, `Get` returns the bytes, `Delete` twice succeeds, `Stat` after delete is `ErrNotFound`; a PUT with a different `Content-Length` than presigned is refused by RustFS; `PublicURL("media/x")` is readable without credentials and `uploads/x` is not.
- [ ] **Step 4: Run** and see them fail; **implement** with minio-go (`minio.New(endpoint, &minio.Options{Creds: credentials.NewStaticV4(...), Secure: strings.HasPrefix(endpoint,"https"), Region: ...})`, `PresignHeader` for PUT with `Content-Type` and `Content-Length` signed); `objectstoretest.New(t)` returns a `*Store` on the test stack with a fresh key prefix per test.
- [ ] **Step 5:** `make test` passes.

### Task 3: uploads in module media

**Files:**
- Create: `api/paths/media.yaml`, `api/schemas/media.yaml` (refs in `api/openapi.yaml`); `internal/media/{media.go, domain/, repository/, service/, handler/}`; `migrations/0006_media.sql`
- Modify: `internal/app/app.go`, `.golangci.yml` (depguard lists gain `media`)

**Interfaces:**
- Produces:
  ```go
  // media/domain
  type Status string // waiting, attached, ready, failed, expired
  type Upload struct { /* id, ownerID, contentType, size, status, photoKey, thumbKey, failure, writeID, createdAt */ }
  func NewUpload(id, owner uuid.UUID, contentType string, size int64, now time.Time) (Upload, error) // ErrInvalidUpload
  func (u *Upload) Attach(owner uuid.UUID) error          // ErrInvalidUpload unless owner and waiting
  func (u *Upload) Processed(photoKey, thumbKey string)   // ready
  func (u *Upload) Failed(reason string)                  // failed
  func (u *Upload) Expire() bool                          // true and expired when waiting
  func (u Upload) Key() string                            // "uploads/<id>"

  // media/service
  type Service interface {
      CreateUpload(ctx context.Context, owner uuid.UUID, contentType string, size int64) (UploadTicket, error)
      Attach(ctx context.Context, owner uuid.UUID, ids []uuid.UUID) error // all or none
      Photos(ctx context.Context, ids []uuid.UUID) ([]Photo, error)       // status, URLs when ready
  }
  type UploadTicket struct { UploadID uuid.UUID; URL string; Headers map[string]string; ExpiresAt time.Time }
  type Photo struct { UploadID uuid.UUID; Status domain.Status; URL, ThumbURL, Failure string }
  ```
  `POST /v1/uploads` 201 `UploadTicket`; 400; 401; 422 `invalid_upload`.

- [ ] **Step 1: Spec.** Write the path and schemas; route-versus-spec test fails until the handler exists.
- [ ] **Step 2: Failing tests:** domain (`NewUpload` limits, `Attach` rules, `Expire` only from waiting), repository (save-twice, `Get`, `GetMany`), service (`CreateUpload` presigns `uploads/<id>`; `Attach` refuses another owner's upload, a missing object (`Stat` not found), an attached one; all or none), `TestExpireLeavesAttachedUploads` and expire deleting a waiting upload's object.
- [ ] **Step 3: Implement.** `CreateUpload` saves the upload then sends `MediaExpire.Run(upload_id)` through `restatex` ingress send with `restate.WithDelay(24 * time.Hour)` and the upload ID as idempotency key. `MediaExpire` (`service/media_expire_durable.go`) loads, `Expire()`, saves and deletes the object in steps. `Attach` checks every upload (owner, waiting, `Stat` finds the object with the declared size and type) before saving any, all in one repository transaction (`AttachAll`).
- [ ] **Step 4:** handler and `media.Mount(d, store) (service.Service, []restate.ServiceDefinition)`; app wiring builds `objectstore.New(cfg.ObjectStore)`.
- [ ] **Step 5:** `make test` passes.

### Task 4: MediaProcess

**Files:**
- Create: `internal/media/service/media_process_durable.go`, `internal/media/service/image.go`, tests, `internal/media/service/testdata/` (a JPEG with GPS EXIF, a PNG, a WebP, a 10000×10000 PNG header-only bomb, a text file named .jpg)

**Interfaces:**
- Produces: Restate service `MediaProcess` handler `Run(ctx restate.Context, uploadID uuid.UUID) (ProcessResult, error)`; `type ProcessResult struct { Status domain.Status; Failure string }` with `Refusal()` returning nil (failures are data, not refusals).

- [ ] **Step 1: Failing tests:** `TestProcessJPEGPNGWebP` (ready, photo ≤ 1600 px, thumb ≤ 400 px, both JPEG, original deleted); `TestProcessDropsExif` (no `Exif` APP1 marker in either output: scan the bytes for `0xFFE1` followed by `Exif\x00\x00`); `TestProcessRefusesHugeImages` (failed, "too large", decoder never called: `image.DecodeConfig` first); `TestProcessRefusesWrongContent` (failed, "not an image of its type"); `TestProcessIsIdempotent` (run twice with `restatetest.CommitThenFail` on the save: one photo object, upload ready).
- [ ] **Step 2: Implement** `image.go`: `process(r io.Reader, contentType string) (photo, thumb []byte, err error)` reading at most 15 MB, sniffing magic bytes (`\xFF\xD8\xFF`, `\x89PNG`, `RIFF....WEBP`), `image.DecodeConfig` and refusing width×height > 40,000,000, decoding with `image/jpeg`, `image/png`, `golang.org/x/image/webp`, scaling with `golang.org/x/image/draw.CatmullRom`, encoding `jpeg.Encode` quality 85. The durable handler: step 1 load upload; step 2 read the object and process (the bytes never enter the journal: the step writes `media/<id>.jpg` and `media/<id>_thumb.jpg` itself and returns their keys); step 3 save `Processed` or `Failed`; step 4 delete the original.
- [ ] **Step 3:** `make test` passes.

### Task 5: catalog data

**Files:**
- Create: `migrations/0007_catalog.sql` (categories with app2's tree; listings); `internal/catalog/domain/{listing.go, category.go, errors.go}`, `internal/catalog/repository/{listing.go, listing_pg.go, category.go, category_pg.go, region.go, region_pg.go}` and tests

**Interfaces:**
- Produces:
  ```go
  // catalog/domain
  type Status string // processing, active, hidden, rejected, sold, deleted
  type Condition string // new, like_new, used
  type Mark struct { Text string; Photo *uuid.UUID }
  type Spec struct { Label, Value string }
  type Draft struct { Title string; Price int64; Description, CategoryKey string; Condition Condition; AllowOffers bool; CommuneCode string; Photos []uuid.UUID; Marks []Mark; Specs []Spec }
  type Listing struct { /* unexported fields, write_id */ }
  func NewListing(id, seller uuid.UUID, d Draft, now time.Time) (Listing, error) // *apperr.Error invalid_listing with field details
  func (l *Listing) Edit(d Draft, now time.Time) (photosChanged bool, err error)
  func (l *Listing) Hide(now) error; Unhide(now) error; MarkSold(now) error; UnmarkSold(now) error; Delete(now) error // listing_state_conflict
  func (l *Listing) Published(photoKeys map[uuid.UUID]Processed, now) ; Rejected(reasons map[uuid.UUID]string, now)
  // plus RestoreListing(ListingState), State(), Saved(writeID) as staff's Member

  // catalog/repository
  type Listings interface {
      Insert(ctx, l domain.Listing, cap int) error // ErrCapReached when the seller already has cap on sale or hidden; one statement
      Get(ctx, id uuid.UUID) (domain.Listing, error)
      Save(ctx, l *domain.Listing, writeID uuid.UUID, evs ...events.Event) error
      ListBySeller(ctx, seller uuid.UUID, statuses []domain.Status, p page.Request) ([]domain.Listing, error)
  }
  type Categories interface { Tree(ctx) ([]domain.Category, error); IsLeaf(ctx, key string) (bool, error) }
  type Regions interface { Provinces(ctx) ([]domain.Province, error); Communes(ctx, province string) ([]domain.Commune, error); CommuneExists(ctx, code string) (bool, error) }
  ```

- [ ] **Step 1: Failing tests:** domain table tests for every field rule and every transition in the spec's diagram; repository save-twice, `ListBySeller` paging, and `TestCapHoldsUnderRace` (30 goroutines insert for one seller; exactly 20 succeed).
- [ ] **Step 2: Implement.** `Insert` is `INSERT ... SELECT ... WHERE (SELECT count(*) FROM listings WHERE seller_id = @seller AND status IN ('processing','active','hidden','rejected')) < @cap` inside a transaction that first takes `pg_advisory_xact_lock(hashtext(seller_id::text))`, so concurrent inserts for one seller serialise. Category tree from app2's `fixtures/catalog.json`: copy keys and Vietnamese names into the migration, roots ordered as app2.
- [ ] **Step 3:** `make test` passes.

### Task 6: catalog service and ListingPublish

**Files:**
- Create: `internal/catalog/service/{service.go, views.go, listing_post.go, listing_edit.go, listing_state.go, listing_get.go, listing_publish_durable.go, category_list.go, region_list.go}` and tests
- Modify: `internal/auth/service/service.go` and a new `identity.go` method `HasPhone`; its test

**Interfaces:**
- Consumes: `accountsvc.Service.Status`, `authsvc.Service.HasPhone(ctx, accountID) (bool, error)` (new), `mediasvc.Service.Attach`, `Photos`, Restate `MediaProcess.Run`.
- Produces: `catalogsvc.Service` with `Post(ctx, seller uuid.UUID, idempotencyKey string, d domain.Draft) (ListingView, error)`, `Edit`, `Hide`, `Unhide`, `MarkSold`, `UnmarkSold`, `Delete` (each `(ctx, seller, id)`), `Get(ctx, viewer *uuid.UUID, id)`, `ListMine(ctx, seller, pane, p)`, `Categories(ctx)`, `Provinces(ctx)`, `Communes(ctx, province)`; Restate service `ListingPublish` handler `Run(ctx restate.Context, listingID uuid.UUID) error`.

- [ ] **Step 1: Failing tests:** the posting checks in order; cap; each transition with its event kind in the events table; another seller's listing is `listing_not_found`; `ListingPublish` with all photos ready ends `active` with `listing.published`, with one failed ends `rejected` with the reason; an edit adding a photo returns to processing and ends active again; `Get` hides non-active listings from others.
- [ ] **Step 2: Implement.** `Post`: account status, `HasPhone`, field checks through `NewListing`, `media.Attach(seller, photos + mark photos)`, `listings.Insert(…, 20)`, then `ingress.ServiceSend(ListingPublish.Run)` with idempotency key `<listing id>/<write id>`. `ListingPublish.Run`: load the listing in a step; call `MediaProcess.Run` for every photo with `restate.Service(...).RequestFuture` and wait for all; save `Published` or `Rejected` with its event in one step; a listing whose write ID moved meanwhile (an edit) is left alone, since the edit started a run of its own.
- [ ] **Step 3:** `make test` passes.

### Task 7: the HTTP API and e2e

**Files:**
- Create: `api/paths/catalog.yaml`, `api/schemas/catalog.yaml`; `internal/catalog/handler/*`; `internal/catalog/catalog.go`; `e2e/catalog_test.go`, `e2e/media_test.go`
- Modify: `api/openapi.yaml`, `internal/app/app.go`, `.golangci.yml`, `e2e/main_test.go` (object store config)

- [ ] **Step 1: Spec** every endpoint of the spec's table with its statuses: 200/201/204, 400, 401, 403 (`account_suspended`, `phone_required`), 404, 409 (`listing_cap_reached`, `listing_state_conflict`), 422 (`invalid_listing`, `invalid_upload`).
- [ ] **Step 2: Failing e2e:** upload a JPEG with GPS, post, poll `GET /v1/listings/{id}` until `active`, fetch the photo URL without credentials and check no EXIF; a buyer sees it; every refusal of Review Focus 3; hide/unhide/mark-sold/unmark-sold/delete; another account's listing 404; `GET /v1/me/listings?pane=on_sale|sold`; categories and regions. The status-coverage check lists what is still missing.
- [ ] **Step 3: Implement** handlers and `catalog.Mount(d, accounts, auth, media) []restate.ServiceDefinition`; app mounts media then catalog and adds their Restate services.
- [ ] **Step 4:** `make test` passes, status coverage included.

### Task 8: docs

- [ ] ARCHITECTURE.md: modules media and catalog (layout, Restate services, object store, regions source), configuration list, the decisions of the spec; run the humanizing checker; `make test`.
