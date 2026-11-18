# Follows and Reports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give server follows (with a follower count, `viewer.following` and a notice when a followed seller first publishes a listing) and reports of listings and accounts, so the three `checklist.md` items have a server.

**Architecture:** Follows live in module `account` beside blocks, so a block deletes them in its transaction. Reports live in module `trust`, one `reports` table with `account_id` always set and `listing_id` optional. Catalog marks a listing's first publication on `listing.published`; notification's `ListingPublished` pages the seller's followers and sends one `TellFollower` invocation per follower.

**Tech Stack:** Go (stdlib `uuid`, `net/http` ServeMux), pgx v5, Postgres (ParadeDB image), Restate Go SDK, kin-openapi request validation, `make test` (tests + golangci-lint).

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-10-server-follows-reports-design.md`. Read it and `~/shopnexus/server/ARCHITECTURE.md` (sections Blocks, Trust, Notifications, Testing) before Task 1.

## Global Constraints

- Work in `~/shopnexus/server` on `main` (the user's workflow; no branch was asked for). Commit after each task; do not push.
- No `Co-Authored-By` trailer on any commit (user's rule for the shopnexus repos). Commit messages are conventional (`feat(account): …`), one line, plain facts.
- A use case, Restate handler or HTTP handler reads top to bottom; no helper called from one place (server `CLAUDE.md`). A helper called from several places is fine.
- The OpenAPI spec in `api/` comes first in each task that adds an endpoint; `TestRoutesMatchSpec` (`internal/app/routes_test.go`) and the e2e coverage check (`e2e/main_test.go`, `uncovered`) require every route in the spec and every documented status observed by an e2e call.
- A business rule broken is 422 (`apperr.KindInvalid`); the schema does not constrain values a rule checks (enum-like `reason`, `note` length), so the validator does not turn them into 400. See `ReviewDraft` in `api/schemas/trust.yaml`.
- Follow cap: 1,000 per follower (`domain.MaxFollows`). Note: 0 to 500 characters after `strings.TrimSpace` (`domain.MaxNote`). Reasons: `banned`, `fake`, `scam`, `other`.
- Error codes, exactly: `invalid_follow`, `follow_limit_reached`, `blocked`, `account_suspended`, `account_not_found`, `invalid_report`, `self_report`, `listing_not_found`, `report_not_found`.
- Notice type `followed_listing`, text `"{seller name} vừa đăng tin mới: {title}"`, collapse key `seller:<seller id>`, group `listings` (push title "Tin đăng", opens the listing).
- Scratch output goes in `tmp/`, never `/tmp`.
- `make test` starts the test stack once; afterwards `go test ./internal/<module>/...` and `go test ./e2e/ -run <Name>` run alone. Finish every task with `make test` green.

## Review Focus

1. A follow racing a block between the same two accounts: the follow must not survive the block. Task 1 serialises both on a pair lock; its test runs them concurrently.
2. Two reports of the same target at the same moment (double tap): one row, not two. Task 4's test runs two `Open`s concurrently.
3. A listing edited or re-published after a rejection: followers hear nothing the second time. Task 6 tests `Published` after `Rejected` + `Edit`, and Task 7 tests an event without `first`.
4. A seller with more followers than one page: every follower hears once. Task 7 runs the worker with a page of 2 and 5 followers.
5. Following or reporting with a suspended account, and reporting a deleted listing: 403 and 404, not 204/201. Tasks 2 and 5 cover them in service and e2e tests.

---

### Task 1: Follows table, reports table and the follow store

**Files:**
- Create: `migrations/0025_follows_reports.sql` (if `migrations/0025_*` exists when you start, the realtime-ws plan landed first: use `0026`)
- Create: `internal/account/domain/follow.go`
- Modify: `internal/account/domain/errors.go`
- Modify: `internal/account/repository/account.go` (interface `Accounts`, type `Follow`)
- Modify: `internal/account/repository/account_pg.go` (`Block` and the new methods)
- Test: `internal/account/repository/account_pg_test.go`

**Interfaces:**
- Produces (repository): `Follow(ctx, id, follower, followed uuid.UUID, at time.Time) error`, `Unfollow(ctx, follower, followed uuid.UUID) error`, `Following(ctx, follower, followed uuid.UUID) (bool, error)`, `FollowerCount(ctx, followed uuid.UUID) (int, error)`, `ListFollows(ctx, follower uuid.UUID, p page.Request) ([]Follow, error)`, `ListFollowers(ctx, followed uuid.UUID, p page.Request) ([]Follow, error)`; `type Follow struct { ID, AccountID uuid.UUID; At time.Time }`.
- Produces (domain): `MaxFollows = 1000`, `ErrSelfFollow` (`invalid_follow`, 422), `ErrFollowLimit` (`follow_limit_reached`, 409). `ErrBlocked` already exists.
- Produces (schema): tables `account_follows` and `reports` (Task 4 uses `reports`).

- [ ] **Step 1: Write the migration**

`migrations/0025_follows_reports.sql`:

```sql
-- Follows: a person follows an account to hear of its new listings. A
-- block, either way, deletes the follows between the two. At most 1,000
-- per follower.
CREATE TABLE account_follows (
    id          uuid PRIMARY KEY,
    follower_id uuid NOT NULL REFERENCES accounts (id),
    followed_id uuid NOT NULL REFERENCES accounts (id),
    created_at  timestamptz NOT NULL,
    UNIQUE (follower_id, followed_id),
    CHECK (follower_id <> followed_id)
);

CREATE INDEX account_follows_follower ON account_follows (follower_id, id);
CREATE INDEX account_follows_followed ON account_follows (followed_id, id);

-- Reports: a person tells ShopNexus a listing or an account breaks the
-- rules. account_id is the account reported, the seller for a listing. A
-- reporter has one open report per target; a withdrawn one keeps its row.
CREATE TABLE reports (
    id           uuid PRIMARY KEY,
    reporter_id  uuid NOT NULL REFERENCES accounts (id),
    account_id   uuid NOT NULL REFERENCES accounts (id),
    listing_id   uuid REFERENCES listings (id),
    reason       text NOT NULL CHECK (reason IN ('banned', 'fake', 'scam', 'other')),
    note         text NOT NULL CHECK (char_length(note) <= 500),
    created_at   timestamptz NOT NULL,
    updated_at   timestamptz NOT NULL,
    withdrawn_at timestamptz,
    CHECK (reporter_id <> account_id)
);

CREATE UNIQUE INDEX reports_open_listing ON reports (reporter_id, listing_id)
    WHERE withdrawn_at IS NULL AND listing_id IS NOT NULL;
CREATE UNIQUE INDEX reports_open_account ON reports (reporter_id, account_id)
    WHERE withdrawn_at IS NULL AND listing_id IS NULL;
CREATE INDEX reports_account ON reports (account_id, created_at);
```

- [ ] **Step 2: Add the domain names**

`internal/account/domain/follow.go`:

```go
package domain

// MaxFollows caps how many accounts one account follows.
const MaxFollows = 1000
```

In `internal/account/domain/errors.go`, beside `ErrSelfBlock`:

```go
	ErrSelfFollow  = apperr.New(apperr.KindInvalid, "invalid_follow", "an account cannot follow itself")
	ErrFollowLimit = apperr.New(apperr.KindConflict, "follow_limit_reached", "at most 1000 follows")
```

- [ ] **Step 3: Write the failing repository tests**

Append to `internal/account/repository/account_pg_test.go` (it already imports `errors`, `page`, `pgtest`, `uuid`; add `sync` and `github.com/jackc/pgx/v5` if missing):

```go
func TestFollows(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	s := newStore(t)
	a, b, c := seed(t, s), seed(t, s), seed(t, s)
	for _, followed := range []uuid.UUID{b, c, b} {
		if err := s.Follow(ctx, uuid.NewV7(), a, followed, now); err != nil {
			t.Fatalf("follow %s: %v", followed, err)
		}
	}
	if err := s.Follow(ctx, uuid.NewV7(), b, a, now); err != nil {
		t.Fatal(err)
	}
	if n, err := s.FollowerCount(ctx, b); err != nil || n != 1 {
		t.Fatalf("b's followers: %d %v", n, err)
	}
	follows, err := s.ListFollows(ctx, a, page.Request{})
	if err != nil || len(follows) != 2 || follows[0].AccountID != c || follows[1].AccountID != b || follows[0].At.IsZero() {
		t.Fatalf("a's follows: %+v %v", follows, err)
	}
	if first, _ := s.ListFollows(ctx, a, page.Request{Limit: 1}); len(first) != 2 {
		t.Fatalf("a page of 1 reads 2 rows: %+v", first)
	}
	followers, err := s.ListFollowers(ctx, a, page.Request{})
	if err != nil || len(followers) != 1 || followers[0].AccountID != b {
		t.Fatalf("a's followers: %+v %v", followers, err)
	}

	// A block, either way, deletes both follows and refuses a new one.
	if err = s.Block(ctx, uuid.NewV7(), b, a, now); err != nil {
		t.Fatal(err)
	}
	for _, pair := range [][2]uuid.UUID{{a, b}, {b, a}} {
		if following, err := s.Following(ctx, pair[0], pair[1]); err != nil || following {
			t.Fatalf("%v still follows: %v", pair, err)
		}
		if err := s.Follow(ctx, uuid.NewV7(), pair[0], pair[1], now); !errors.Is(err, domain.ErrBlocked) {
			t.Fatalf("%v follows across a block: %v", pair, err)
		}
	}
	if following, _ := s.Following(ctx, a, c); !following {
		t.Fatal("the block deleted a follow of someone else")
	}
	for range 2 {
		if err = s.Unfollow(ctx, a, c); err != nil {
			t.Fatal(err)
		}
	}
	if following, _ := s.Following(ctx, a, c); following {
		t.Fatal("still following after unfollow")
	}
}

// fillFollows makes follower follow n new accounts in one statement.
func fillFollows(t *testing.T, db *pgxpool.Pool, follower uuid.UUID, n int) {
	t.Helper()
	if _, err := db.Exec(context.Background(), `WITH made AS (
    INSERT INTO accounts (id, display_name, status, write_id, created_at, updated_at)
    SELECT gen_random_uuid(), 'Linh', 'active', gen_random_uuid(), now(), now() FROM generate_series(1, @n)
    RETURNING id)
INSERT INTO account_follows (id, follower_id, followed_id, created_at)
SELECT gen_random_uuid(), @follower, id, now() FROM made`, pgx.StrictNamedArgs{"n": n, "follower": follower}); err != nil {
		t.Fatal(err)
	}
}

// Two follows at once with one place left: one lands, the other is the cap.
func TestFollowLimit(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewAccounts(db)
	a, x, y := seed(t, s), seed(t, s), seed(t, s)
	fillFollows(t, db, a, domain.MaxFollows-1)
	errs := make([]error, 2)
	var wg sync.WaitGroup
	for i, followed := range []uuid.UUID{x, y} {
		wg.Go(func() { errs[i] = s.Follow(ctx, uuid.NewV7(), a, followed, now) })
	}
	wg.Wait()
	ok, capped := 0, 0
	for _, err := range errs {
		switch {
		case err == nil:
			ok++
		case errors.Is(err, domain.ErrFollowLimit):
			capped++
		default:
			t.Fatal(err)
		}
	}
	if ok != 1 || capped != 1 {
		t.Fatalf("%d followed, %d capped", ok, capped)
	}
}

// A follow racing a block between the same two never outlives the block.
func TestFollowRacingABlock(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	s := newStore(t)
	for range 20 {
		a, b := seed(t, s), seed(t, s)
		var wg sync.WaitGroup
		wg.Go(func() { _ = s.Follow(ctx, uuid.NewV7(), a, b, now) })
		wg.Go(func() {
			if err := s.Block(ctx, uuid.NewV7(), b, a, now); err != nil {
				t.Error(err)
			}
		})
		wg.Wait()
		if following, err := s.Following(ctx, a, b); err != nil || following {
			t.Fatalf("a follow outlived the block: %v", err)
		}
	}
}
```

`pgtest.New` returns `*pgxpool.Pool`; import `github.com/jackc/pgx/v5/pgxpool`. If `seed`'s `domain.New` needs a name, it already passes "Linh".

- [ ] **Step 4: Run them to see them fail**

Run: `go test ./internal/account/repository/ -run 'TestFollow' -count=1`
Expected: build failure, `s.Follow undefined`.

- [ ] **Step 5: Implement the store**

In `internal/account/repository/account.go`, change the interface comment to "persists accounts, their blocks and their follows", and add to `Accounts`:

```go
	// Follow records that follower follows followed, as id; following again
	// changes nothing. A block between the two, either way, is
	// domain.ErrBlocked, and a follower at domain.MaxFollows is
	// domain.ErrFollowLimit.
	Follow(ctx context.Context, id, follower, followed uuid.UUID, at time.Time) error
	// Unfollow deletes the follow; an absent one is fine.
	Unfollow(ctx context.Context, follower, followed uuid.UUID) error
	// Following reports whether follower follows followed.
	Following(ctx context.Context, follower, followed uuid.UUID) (bool, error)
	// FollowerCount is how many accounts follow followed.
	FollowerCount(ctx context.Context, followed uuid.UUID) (int, error)
	// ListFollows is a query: the accounts follower follows, follow IDs
	// below p.Before(), newest first, at most p.Fetch().
	ListFollows(ctx context.Context, follower uuid.UUID, p page.Request) ([]Follow, error)
	// ListFollowers is a query: the accounts that follow followed, follow
	// IDs below p.Before(), newest first, at most p.Fetch().
	ListFollowers(ctx context.Context, followed uuid.UUID, p page.Request) ([]Follow, error)
```

and below `Block`:

```go
// Follow is one follow: its ID, the other account and when it started.
type Follow struct {
	ID        uuid.UUID
	AccountID uuid.UUID
	At        time.Time
}
```

Update the `Block` comment: "Block records that blocker blocks blocked, as id, and deletes the follows between the two, both ways; blocking again changes nothing."

In `internal/account/repository/account_pg.go`, replace `Block` and add:

```go
// lockPair serialises the follows and blocks between a and b, in either
// order, so a follow written beside a block cannot outlive it.
func lockPair(ctx context.Context, tx pgx.Tx, a, b uuid.UUID) error {
	lo, hi := min(a.String(), b.String()), max(a.String(), b.String())
	if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext('pair:' || @pair))`,
		pgx.StrictNamedArgs{"pair": lo + "/" + hi}); err != nil {
		return fmt.Errorf("lock pair: %w", err)
	}
	return nil
}

func (s pgAccounts) Block(ctx context.Context, id, blocker, blocked uuid.UUID, at time.Time) error {
	return pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if err := lockPair(ctx, tx, blocker, blocked); err != nil {
			return err
		}
		args := pgx.StrictNamedArgs{"id": id, "blocker": blocker, "blocked": blocked, "at": at}
		if _, err := tx.Exec(ctx, `INSERT INTO account_blocks (id, blocker_id, blocked_id, created_at)
VALUES (@id, @blocker, @blocked, @at) ON CONFLICT (blocker_id, blocked_id) DO NOTHING`, args); err != nil {
			return fmt.Errorf("insert block: %w", err)
		}
		if _, err := tx.Exec(ctx, `DELETE FROM account_follows
WHERE (follower_id = @blocker AND followed_id = @blocked) OR (follower_id = @blocked AND followed_id = @blocker)`,
			pgx.StrictNamedArgs{"blocker": blocker, "blocked": blocked}); err != nil {
			return fmt.Errorf("delete follows: %w", err)
		}
		return nil
	})
}

func (s pgAccounts) Follow(ctx context.Context, id, follower, followed uuid.UUID, at time.Time) error {
	return pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		// The follower's lock keeps the cap; the pair's keeps out a block.
		if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext('follows:' || @follower::text))`,
			pgx.StrictNamedArgs{"follower": follower}); err != nil {
			return fmt.Errorf("lock follower: %w", err)
		}
		if err := lockPair(ctx, tx, follower, followed); err != nil {
			return err
		}
		var (
			blocked, following bool
			n                  int
		)
		if err := tx.QueryRow(ctx, `SELECT
    EXISTS (SELECT 1 FROM account_blocks
            WHERE (blocker_id = @a AND blocked_id = @b) OR (blocker_id = @b AND blocked_id = @a)),
    EXISTS (SELECT 1 FROM account_follows WHERE follower_id = @a AND followed_id = @b),
    (SELECT count(*) FROM account_follows WHERE follower_id = @a)`,
			pgx.StrictNamedArgs{"a": follower, "b": followed}).Scan(&blocked, &following, &n); err != nil {
			return fmt.Errorf("read the follow's facts: %w", err)
		}
		switch {
		case blocked:
			return domain.ErrBlocked
		case following:
			return nil
		case n >= domain.MaxFollows:
			return domain.ErrFollowLimit
		}
		if _, err := tx.Exec(ctx, `INSERT INTO account_follows (id, follower_id, followed_id, created_at)
VALUES (@id, @follower, @followed, @at)`,
			pgx.StrictNamedArgs{"id": id, "follower": follower, "followed": followed, "at": at}); err != nil {
			return fmt.Errorf("insert follow: %w", err)
		}
		return nil
	})
}

func (s pgAccounts) Unfollow(ctx context.Context, follower, followed uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM account_follows WHERE follower_id = @follower AND followed_id = @followed`,
		pgx.StrictNamedArgs{"follower": follower, "followed": followed}); err != nil {
		return fmt.Errorf("delete follow: %w", err)
	}
	return nil
}

func (s pgAccounts) Following(ctx context.Context, follower, followed uuid.UUID) (bool, error) {
	var following bool
	if err := s.db.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM account_follows
WHERE follower_id = @follower AND followed_id = @followed)`,
		pgx.StrictNamedArgs{"follower": follower, "followed": followed}).Scan(&following); err != nil {
		return false, fmt.Errorf("check follow: %w", err)
	}
	return following, nil
}

func (s pgAccounts) FollowerCount(ctx context.Context, followed uuid.UUID) (int, error) {
	var n int
	if err := s.db.QueryRow(ctx, `SELECT count(*) FROM account_follows WHERE followed_id = @followed`,
		pgx.StrictNamedArgs{"followed": followed}).Scan(&n); err != nil {
		return 0, fmt.Errorf("count followers: %w", err)
	}
	return n, nil
}

func (s pgAccounts) ListFollows(ctx context.Context, follower uuid.UUID, p page.Request) ([]Follow, error) {
	return s.listFollows(ctx, `SELECT id, followed_id, created_at FROM account_follows
WHERE follower_id = @account AND id < @before ORDER BY id DESC LIMIT @limit`, follower, p)
}

func (s pgAccounts) ListFollowers(ctx context.Context, followed uuid.UUID, p page.Request) ([]Follow, error) {
	return s.listFollows(ctx, `SELECT id, follower_id, created_at FROM account_follows
WHERE followed_id = @account AND id < @before ORDER BY id DESC LIMIT @limit`, followed, p)
}

// listFollows runs one of the two follow queries; ListFollows and
// ListFollowers call it.
func (s pgAccounts) listFollows(ctx context.Context, query string, account uuid.UUID, p page.Request) ([]Follow, error) {
	rows, err := s.db.Query(ctx, query, pgx.StrictNamedArgs{"account": account, "before": p.Before(), "limit": p.Fetch()})
	if err != nil {
		return nil, fmt.Errorf("select follows: %w", err)
	}
	follows, err := pgx.CollectRows(rows, pgx.RowToStructByPos[Follow])
	if err != nil {
		return nil, fmt.Errorf("read follows: %w", err)
	}
	return follows, nil
}
```

`fillFollows` writes v4 follow IDs, which sort anywhere; `TestFollowLimit` does not page, so that is fine.

- [ ] **Step 6: Run the tests**

Run: `go test ./internal/account/... -count=1`
Expected: PASS, `TestBlocks` included.

- [ ] **Step 7: Commit**

```bash
git add migrations/0025_follows_reports.sql internal/account/domain internal/account/repository
git commit -m "feat(account): the follows store; a block deletes the follows between the two"
```

---

### Task 2: Follow endpoints

**Files:**
- Modify: `api/openapi.yaml`, `api/paths/account.yaml`, `api/schemas/account.yaml`
- Create: `internal/account/service/follow.go`, `internal/account/handler/follow.go`
- Modify: `internal/account/service/service.go` (interface), `internal/account/service/views.go`, `internal/account/handler/handler.go` (`Register`)
- Test: `internal/account/service/follow_test.go`, `e2e/follow_test.go`

**Interfaces:**
- Consumes: Task 1's repository methods and domain errors.
- Produces (`accountsvc.Service`):
  - `Follow(ctx, follower, followed uuid.UUID) error`
  - `Unfollow(ctx, follower, followed uuid.UUID) error`
  - `Following(ctx, follower, followed uuid.UUID) (bool, error)`
  - `FollowerCount(ctx, followed uuid.UUID) (int, error)`
  - `Follows(ctx, follower uuid.UUID, p page.Request) (page.Page[FollowView], error)`
  - `Followers(ctx, followed uuid.UUID, p page.Request) (page.Page[Follower], error)`
  - `type FollowView struct { ID, AccountID uuid.UUID; DisplayName, AvatarURL string; At time.Time }` (JSON `id, account_id, display_name, avatar_url,omitempty, at`)
  - `type Follower struct { ID uuid.UUID "json:\"id\""; AccountID uuid.UUID "json:\"account_id\"" }`
- Endpoints: `POST /v1/follows` (`followAccount`), `GET /v1/follows` (`listFollows`), `DELETE /v1/follows/{account_id}` (`unfollowAccount`).

- [ ] **Step 1: Write the spec**

In `api/openapi.yaml`, after the `/v1/blocks/{account_id}` entry:

```yaml
  /v1/follows:
    $ref: "paths/account.yaml#/follows"
  /v1/follows/{account_id}:
    $ref: "paths/account.yaml#/follow"
```

Append to `api/paths/account.yaml`:

```yaml
follows:
  post:
    operationId: followAccount
    summary: Follow an account.
    description: |
      The caller hears when the account first publishes a listing.
      Following again changes nothing. A block between the two, either way,
      refuses a follow, and blocking deletes the follows between them.
    tags: [account]
    security:
      - bearerAuth: []
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/account.yaml#/FollowCreate"
    responses:
      "204":
        description: Following.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "403":
        description: "The caller is suspended (account_suspended), or a block stands between the two (blocked)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "404":
        description: "No such account (account_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "409":
        description: "The caller follows 1,000 accounts (follow_limit_reached)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: "The caller named themselves (invalid_follow)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
  get:
    operationId: listFollows
    summary: List the accounts the caller follows, newest follow first.
    tags: [account]
    security:
      - bearerAuth: []
    parameters:
      - $ref: "../parameters/common.yaml#/Cursor"
      - $ref: "../parameters/common.yaml#/Limit"
    responses:
      "200":
        description: One page of follows.
        content:
          application/json:
            schema:
              $ref: "../schemas/account.yaml#/FollowList"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
follow:
  delete:
    operationId: unfollowAccount
    summary: Stop following an account; an absent follow is fine.
    tags: [account]
    security:
      - bearerAuth: []
    parameters:
      - name: account_id
        in: path
        required: true
        schema:
          type: string
          format: uuid
    responses:
      "204":
        description: Not following.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
```

Append to `api/schemas/account.yaml`:

```yaml
FollowCreate:
  type: object
  additionalProperties: false
  required: [account_id]
  properties:
    account_id:
      type: string
      format: uuid
Follow:
  type: object
  additionalProperties: false
  required: [id, account_id, display_name, at]
  description: An account the caller follows.
  properties:
    id:
      type: string
      format: uuid
    account_id:
      type: string
      format: uuid
    display_name:
      type: string
    avatar_url:
      type: string
      format: uri
      description: A public 400 px square; absent without an avatar.
    at:
      type: string
      format: date-time
FollowList:
  type: object
  additionalProperties: false
  required: [items]
  properties:
    items:
      type: array
      items:
        $ref: "#/Follow"
    next_cursor:
      type: string
      format: uuid
      description: Present when more follows follow; pass it as cursor.
```

Run: `go test ./api/ -count=1` → PASS.

- [ ] **Step 2: Write the failing service test**

`internal/account/service/follow_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"testing"
	"uuid"

	"github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/account/repository"
	"github.com/shopnexus/server/internal/platform/page"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
)

func TestFollow(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewAccounts(db)
	svc := at(s, nil, now)
	a, b, c := seed(t, s), seed(t, s), seed(t, s)

	if err := svc.Follow(ctx, a, a); !errors.Is(err, domain.ErrSelfFollow) {
		t.Fatalf("self: %v", err)
	}
	if err := svc.Follow(ctx, a, uuid.NewV7()); !errors.Is(err, domain.ErrAccountNotFound) {
		t.Fatalf("unknown: %v", err)
	}
	for _, followed := range []uuid.UUID{b, c} {
		if err := svc.Follow(ctx, a, followed); err != nil {
			t.Fatal(err)
		}
	}
	if following, err := svc.Following(ctx, a, b); err != nil || !following {
		t.Fatalf("following: %v %v", following, err)
	}
	if n, err := svc.FollowerCount(ctx, b); err != nil || n != 1 {
		t.Fatalf("count: %d %v", n, err)
	}
	p, err := svc.Follows(ctx, a, page.Request{Limit: 1})
	if err != nil || len(p.Items) != 1 || p.Items[0].AccountID != c || p.Items[0].DisplayName != "Linh" ||
		p.Items[0].At.IsZero() || p.NextCursor == nil {
		t.Fatalf("first page: %+v %v", p, err)
	}
	if p, err = svc.Follows(ctx, a, page.Request{Cursor: *p.NextCursor}); err != nil || len(p.Items) != 1 || p.Items[0].AccountID != b {
		t.Fatalf("second page: %+v %v", p, err)
	}
	followers, err := svc.Followers(ctx, b, page.Request{})
	if err != nil || len(followers.Items) != 1 || followers.Items[0].AccountID != a {
		t.Fatalf("followers: %+v %v", followers, err)
	}

	if err = svc.Block(ctx, c, a); err != nil {
		t.Fatal(err)
	}
	if err = svc.Follow(ctx, a, c); !errors.Is(err, domain.ErrBlocked) {
		t.Fatalf("across a block: %v", err)
	}
	if err = svc.Unfollow(ctx, a, b); err != nil {
		t.Fatal(err)
	}
	if following, _ := svc.Following(ctx, a, b); following {
		t.Fatal("still following")
	}

	suspendAccount(t, db, a)
	if err = svc.Follow(ctx, a, b); !errors.Is(err, domain.ErrSuspended) {
		t.Fatalf("suspended: %v", err)
	}
}
```

Run: `go test ./internal/account/service/ -run TestFollow -count=1` → build failure, `svc.Follow undefined`.

- [ ] **Step 3: Implement the use cases**

Add to `internal/account/service/views.go`, after `BlockView`:

```go
// FollowView is the Follow schema in api/schemas/account.yaml.
type FollowView struct {
	ID          uuid.UUID `json:"id"`
	AccountID   uuid.UUID `json:"account_id"`
	DisplayName string    `json:"display_name"`
	AvatarURL   string    `json:"avatar_url,omitempty"`
	At          time.Time `json:"at"`
}

// Follower is one follow of an account: the follow's ID, which pages, and
// the follower. Notification reads them to tell of a new listing.
type Follower struct {
	ID        uuid.UUID `json:"id"`
	AccountID uuid.UUID `json:"account_id"`
}
```

Add to the `Service` interface in `service.go`, after `Blocks`:

```go
	// Follow makes follower follow followed; following again changes
	// nothing. A block either way is domain.ErrBlocked.
	Follow(ctx context.Context, follower, followed uuid.UUID) error
	Unfollow(ctx context.Context, follower, followed uuid.UUID) error
	// Following reports whether follower follows followed.
	Following(ctx context.Context, follower, followed uuid.UUID) (bool, error)
	// FollowerCount is how many accounts follow followed.
	FollowerCount(ctx context.Context, followed uuid.UUID) (int, error)
	// Follows lists the accounts follower follows, newest follow first.
	Follows(ctx context.Context, follower uuid.UUID, p page.Request) (page.Page[FollowView], error)
	// Followers lists the accounts that follow followed, newest follow
	// first.
	Followers(ctx context.Context, followed uuid.UUID, p page.Request) (page.Page[Follower], error)
```

Update the package comment's first sentence to include follows ("accounts, suspensions, blocks, follows and addresses").

`internal/account/service/follow.go`:

```go
package service

import (
	"context"
	"fmt"
	"uuid"

	"github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/platform/page"
)

// Follow checks that the follower may write and the account exists, then
// records the follow; the store refuses it across a block and at the cap.
func (s *Account) Follow(ctx context.Context, follower, followed uuid.UUID) error {
	if follower == followed {
		return domain.ErrSelfFollow
	}
	suspended, err := s.Suspended(ctx, follower)
	if err != nil {
		return err
	}
	if suspended {
		return domain.ErrSuspended
	}
	if _, err = s.load(ctx, followed); err != nil {
		return err
	}
	if err = s.accounts.Follow(ctx, uuid.NewV7(), follower, followed, s.now()); err != nil {
		return fmt.Errorf("follow: %w", err)
	}
	return nil
}

func (s *Account) Unfollow(ctx context.Context, follower, followed uuid.UUID) error {
	if err := s.accounts.Unfollow(ctx, follower, followed); err != nil {
		return fmt.Errorf("unfollow: %w", err)
	}
	return nil
}

func (s *Account) Following(ctx context.Context, follower, followed uuid.UUID) (bool, error) {
	following, err := s.accounts.Following(ctx, follower, followed)
	if err != nil {
		return false, fmt.Errorf("check follow: %w", err)
	}
	return following, nil
}

func (s *Account) FollowerCount(ctx context.Context, followed uuid.UUID) (int, error) {
	n, err := s.accounts.FollowerCount(ctx, followed)
	if err != nil {
		return 0, fmt.Errorf("count followers: %w", err)
	}
	return n, nil
}

// Follows lists the accounts follower follows with their names and avatars,
// read in one query.
func (s *Account) Follows(ctx context.Context, follower uuid.UUID, p page.Request) (page.Page[FollowView], error) {
	rows, err := s.accounts.ListFollows(ctx, follower, p)
	if err != nil {
		return page.Page[FollowView]{}, fmt.Errorf("list follows: %w", err)
	}
	ids := make([]uuid.UUID, 0, len(rows))
	for _, f := range rows {
		ids = append(ids, f.AccountID)
	}
	accounts, err := s.GetMany(ctx, ids)
	if err != nil {
		return page.Page[FollowView]{}, err
	}
	items := make([]FollowView, 0, len(rows))
	for _, f := range rows {
		a := accounts[f.AccountID]
		items = append(items, FollowView{ID: f.ID, AccountID: f.AccountID, DisplayName: a.DisplayName, AvatarURL: a.AvatarURL, At: f.At})
	}
	return page.Of(items, p, func(v FollowView) uuid.UUID { return v.ID }), nil
}

func (s *Account) Followers(ctx context.Context, followed uuid.UUID, p page.Request) (page.Page[Follower], error) {
	rows, err := s.accounts.ListFollowers(ctx, followed, p)
	if err != nil {
		return page.Page[Follower]{}, fmt.Errorf("list followers: %w", err)
	}
	items := make([]Follower, 0, len(rows))
	for _, f := range rows {
		items = append(items, Follower{ID: f.ID, AccountID: f.AccountID})
	}
	return page.Of(items, p, func(v Follower) uuid.UUID { return v.ID }), nil
}
```

Update the `Block` comment in `service.go`: "Block stops blocked and blocker from reaching each other and deletes the follows between them; blocking again changes nothing."

Run: `go test ./internal/account/... -count=1` → PASS. If any other package has a hand-written type asserting `accountsvc.Service` without embedding it, `go build ./...` names it; embed the interface there.

- [ ] **Step 4: Write the handlers**

`internal/account/handler/follow.go`:

```go
package handler

import (
	"net/http"
	"uuid"

	"github.com/shopnexus/server/internal/platform/httpx"
	"github.com/shopnexus/server/internal/platform/page"
)

type followRequest struct {
	AccountID uuid.UUID `json:"account_id"`
}

type unfollowRequest struct {
	AccountID uuid.UUID `json:"-" path:"account_id"`
}

// Follow serves POST /v1/follows.
func (h *Handler) Follow(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in followRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.Follow(r.Context(), p.AccountID, in.AccountID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Unfollow serves DELETE /v1/follows/{account_id}.
func (h *Handler) Unfollow(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in unfollowRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.Unfollow(r.Context(), p.AccountID, in.AccountID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Follows serves GET /v1/follows.
func (h *Handler) Follows(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in page.Request
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	out, err := h.svc.Follows(r.Context(), p.AccountID, in)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, out)
}
```

In `Register` (`handler.go`), after the three block routes:

```go
	r.Handle("POST /v1/follows", protect(http.HandlerFunc(h.Follow)))
	r.Handle("GET /v1/follows", protect(http.HandlerFunc(h.Follows)))
	r.Handle("DELETE /v1/follows/{account_id}", protect(http.HandlerFunc(h.Unfollow)))
```

Run: `go test ./internal/app/ -run TestRoutesMatchSpec -count=1` → PASS.

- [ ] **Step 5: Write the e2e test**

`e2e/follow_test.go`:

```go
package e2e

import (
	"context"
	"net/http"
	"testing"
	"uuid"

	"github.com/jackc/pgx/v5"
)

type followedAccount struct {
	AccountID   string `json:"account_id"`
	DisplayName string `json:"display_name"`
	At          string `json:"at"`
}

func TestFollows(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	follow := func(token string, body any) Response {
		t.Helper()
		return call(t, "POST", "/v1/follows", body, bearer(token))
	}
	to := map[string]any{"account_id": seller.Account.ID}

	check(t, "follow", follow(buyer.AccessToken, to), 204, "")
	check(t, "follow again", follow(buyer.AccessToken, to), 204, "")
	check(t, "follow signed out", follow("", to), 401, "unauthenticated")
	check(t, "follow a bad id", follow(buyer.AccessToken, map[string]any{"account_id": "x"}), 400, "")
	check(t, "follow an unknown account", follow(buyer.AccessToken, map[string]any{"account_id": uuid.NewV7().String()}), 404, "account_not_found")
	check(t, "follow oneself", follow(buyer.AccessToken, map[string]any{"account_id": buyer.Account.ID}), 422, "invalid_follow")

	list := expect[page[followedAccount]](t, call(t, "GET", "/v1/follows", nil, bearer(buyer.AccessToken)), http.StatusOK)
	if len(list.Items) != 1 || list.Items[0].AccountID != seller.Account.ID || list.Items[0].At == "" {
		t.Fatalf("list: %+v", list)
	}
	check(t, "list signed out", call(t, "GET", "/v1/follows", nil), 401, "unauthenticated")
	check(t, "list a bad cursor", call(t, "GET", "/v1/follows?cursor=x", nil, bearer(buyer.AccessToken)), 400, "")

	check(t, "unfollow", call(t, "DELETE", "/v1/follows/"+seller.Account.ID, nil, bearer(buyer.AccessToken)), 204, "")
	check(t, "unfollow signed out", call(t, "DELETE", "/v1/follows/"+seller.Account.ID, nil), 401, "unauthenticated")
	check(t, "unfollow a bad id", call(t, "DELETE", "/v1/follows/x", nil, bearer(buyer.AccessToken)), 400, "")
	if list = expect[page[followedAccount]](t, call(t, "GET", "/v1/follows", nil, bearer(buyer.AccessToken)), http.StatusOK); len(list.Items) != 0 {
		t.Fatalf("after unfollow: %+v", list)
	}

	// A block, either way, deletes the follow and refuses a new one.
	check(t, "follow before the block", follow(buyer.AccessToken, to), 204, "")
	expectStatus(t, call(t, "POST", "/v1/blocks", map[string]any{"account_id": buyer.Account.ID}, bearer(seller.AccessToken)), http.StatusNoContent)
	check(t, "follow across a block", follow(buyer.AccessToken, to), 403, "blocked")
	if list = expect[page[followedAccount]](t, call(t, "GET", "/v1/follows", nil, bearer(buyer.AccessToken)), http.StatusOK); len(list.Items) != 0 {
		t.Fatalf("the block left the follow: %+v", list)
	}
}

func TestFollowRefusals(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	full, _ := newAccount(t)
	if _, err := db.Exec(context.Background(), `WITH made AS (
    INSERT INTO accounts (id, display_name, status, write_id, created_at, updated_at)
    SELECT gen_random_uuid(), 'Linh', 'active', gen_random_uuid(), now(), now() FROM generate_series(1, 1000)
    RETURNING id)
INSERT INTO account_follows (id, follower_id, followed_id, created_at)
SELECT gen_random_uuid(), @follower, id, now() FROM made`, pgx.StrictNamedArgs{"follower": full.Account.ID}); err != nil {
		t.Fatal(err)
	}
	to := map[string]any{"account_id": seller.Account.ID}
	check(t, "the 1,001st follow", call(t, "POST", "/v1/follows", to, bearer(full.AccessToken)), 409, "follow_limit_reached")

	suspended, _ := newAccount(t)
	suspend(t, suspended.Account.ID)
	check(t, "a suspended follower", call(t, "POST", "/v1/follows", to, bearer(suspended.AccessToken)), 403, "account_suspended")
}
```

Check the names the e2e package uses: `db` is the pool `suspend` uses (`e2e/auth_helpers_test.go`); `page[T]` and `check` are in `e2e/helpers_test.go`. If the suspended caller is refused earlier by the auth middleware with another code, read `e2e/review_test.go` for how it reaches `account_suspended` and copy that.

Run: `make test` → PASS, the coverage check included.

- [ ] **Step 6: Commit**

```bash
git add api internal/account e2e/follow_test.go
git commit -m "feat(account): POST, GET /v1/follows and DELETE /v1/follows/{account_id}"
```

---

### Task 3: Followers and following on the seller view

**Files:**
- Modify: `api/schemas/screen_listing.yaml` (`SellerProfile`, `SellerViewer`)
- Modify: `internal/screen/service/seller.go`
- Test: `e2e/screen_seller_test.go`

**Interfaces:**
- Consumes: `accountsvc.Service.FollowerCount`, `accountsvc.Service.Following` (Task 2).
- Produces: `SellerProfile.Followers int` (`followers`, required), `SellerViewer.Following bool` (`following`, required).

- [ ] **Step 1: Update the spec**

In `api/schemas/screen_listing.yaml`, `SellerProfile`: add `followers` to `required` and to `properties`:

```yaml
    followers:
      type: integer
      description: How many accounts follow the seller.
```

`SellerViewer`: `required: [blocked, following]` and:

```yaml
    following:
      type: boolean
      description: Whether the reader follows the seller.
```

- [ ] **Step 2: Write the failing e2e checks**

In `e2e/screen_seller_test.go`, add `Followers int `json:"followers"`` to the `Seller` struct and `Following bool `json:"following"`` to `Viewer`. In `TestSellerScreen`, right after the "before chatting" check, add:

```go
	if got.Seller.Followers != 0 || got.Viewer.Following {
		t.Fatalf("before following: %d %+v", got.Seller.Followers, got.Viewer)
	}
	expectStatus(t, call(t, "POST", "/v1/follows", map[string]any{"account_id": seller.Account.ID}, bearer(buyer.AccessToken)), http.StatusNoContent)
	if got = get("following", path, bearer(buyer.AccessToken)); got.Seller.Followers != 1 || got.Viewer == nil || !got.Viewer.Following {
		t.Fatalf("following: %d %+v", got.Seller.Followers, got.Viewer)
	}
	if got = get("signed out, following", path); got.Seller.Followers != 1 {
		t.Fatalf("the count is public: %d", got.Seller.Followers)
	}
```

and after the "blocked by the seller" check:

```go
	if got.Viewer.Following || got.Seller.Followers != 0 {
		t.Fatalf("the block left the follow: %d %+v", got.Seller.Followers, got.Viewer)
	}
```

Run: `go test ./e2e/ -run TestSellerScreen -count=1`
Expected: FAIL (the response validator rejects a missing required `followers`, or the check fails).

- [ ] **Step 3: Implement**

In `internal/screen/service/seller.go`: add `Followers int `json:"followers"`` to `SellerProfile` after `OnSale`, and `Following bool `json:"following"`` to `SellerViewer` after `Blocked`. In `Seller`, after the rating read:

```go
	followers, err := s.accounts.FollowerCount(ctx, id)
	if err != nil {
		return SellerScreen{}, fmt.Errorf("count the followers: %w", err)
	}
```

set `Followers: followers` in the `SellerProfile` literal, and after the blocks read:

```go
	following, err := s.accounts.Following(ctx, *viewer, id)
	if err != nil {
		return SellerScreen{}, fmt.Errorf("read the follow: %w", err)
	}
```

with `out.Viewer = &SellerViewer{Blocked: blocked, Following: following, ConversationID: conversation}`. Update the doc comment of `Seller`: "A viewer who is not the seller also gets whether a block stands between the two, whether they follow the seller, and their conversation."

- [ ] **Step 4: Run**

Run: `go test ./e2e/ -run TestSellerScreen -count=1` → PASS.

- [ ] **Step 5: Commit**

```bash
git add api/schemas/screen_listing.yaml internal/screen e2e/screen_seller_test.go
git commit -m "feat(screen): the seller view counts followers and tells the viewer's follow"
```

---

### Task 4: The report entity and store

**Files:**
- Create: `internal/trust/domain/report.go`, `internal/trust/repository/report_pg.go`
- Modify: `internal/trust/domain/errors.go`, `internal/trust/repository/repository.go`
- Test: `internal/trust/domain/report_test.go`, `internal/trust/repository/report_pg_test.go`

**Interfaces:**
- Consumes: table `reports` (Task 1).
- Produces (domain): `type Reason string` with `ReasonBanned, ReasonFake, ReasonScam, ReasonOther`; `MaxNote = 500`; `NewReport(id, reporter, account, listing uuid.UUID, reason Reason, note string, now time.Time) (Report, error)`; getters `ID() ReporterID() AccountID() ListingID() Reason() Note() CreatedAt() UpdatedAt() WithdrawnAt()`; `ReportState`, `RestoreReport`, `State()`; errors `ErrInvalidReport` (`invalid_report`, 422), `ErrSelfReport` (`self_report`, 422), `ErrReportNotFound` (`report_not_found`, 404).
- Produces (repository): `Reports` with `Open(ctx, domain.Report) (domain.Report, bool, error)`, `Get(ctx, id uuid.UUID) (domain.Report, error)` (`ErrNotFound`), `Withdraw(ctx, id uuid.UUID, at time.Time) error`; `NewReports(*pgxpool.Pool) Reports`.

- [ ] **Step 1: Write the failing domain test**

`internal/trust/domain/report_test.go`:

```go
package domain_test

import (
	"errors"
	"strings"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/trust/domain"
)

func TestNewReport(t *testing.T) {
	t.Parallel()
	at := time.Date(2026, 11, 10, 9, 0, 0, 0, time.UTC)
	reporter, seller, listing := uuid.NewV7(), uuid.NewV7(), uuid.NewV7()
	r, err := domain.NewReport(uuid.NewV7(), reporter, seller, listing, domain.ReasonFake, "  Ảnh lấy trên mạng  ", at)
	if err != nil || r.Note() != "Ảnh lấy trên mạng" || r.AccountID() != seller || r.ListingID() != listing ||
		r.Reason() != domain.ReasonFake || !r.CreatedAt().Equal(at) || !r.UpdatedAt().Equal(at) || r.WithdrawnAt() != nil {
		t.Fatalf("%+v %v", r.State(), err)
	}
	if _, err = domain.NewReport(uuid.NewV7(), reporter, reporter, uuid.UUID{}, domain.ReasonScam, "", at); !errors.Is(err, domain.ErrSelfReport) {
		t.Fatalf("self: %v", err)
	}
	_, err = domain.NewReport(uuid.NewV7(), reporter, seller, uuid.UUID{}, "ugly", strings.Repeat("ạ", domain.MaxNote+1), at)
	if e, ok := errors.AsType[*apperr.Error](err); !ok || e.Code != "invalid_report" || e.Fields["reason"] == "" || e.Fields["note"] == "" {
		t.Fatalf("broken rules: %v", err)
	}
	if _, err = domain.NewReport(uuid.NewV7(), reporter, seller, uuid.UUID{}, domain.ReasonOther, strings.Repeat("ạ", domain.MaxNote), at); err != nil {
		t.Fatalf("500 characters: %v", err)
	}
}
```

Run: `go test ./internal/trust/domain/ -run TestNewReport -count=1` → build failure.

- [ ] **Step 2: Implement the entity**

Add to `internal/trust/domain/errors.go`:

```go
	ErrInvalidReport  = apperr.New(apperr.KindInvalid, "invalid_report", "the report breaks a rule; see fields")
	ErrSelfReport     = apperr.New(apperr.KindInvalid, "self_report", "nobody reports themselves or their own listing")
	ErrReportNotFound = apperr.New(apperr.KindNotFound, "report_not_found", "no such report of the caller's")
```

`internal/trust/domain/report.go`:

```go
package domain

import (
	"slices"
	"strings"
	"time"
	"unicode/utf8"
	"uuid"
)

// Reason is why a listing or an account is reported. Condition and price
// are for buyer and seller to settle, so no reason names them.
type Reason string

const (
	ReasonBanned Reason = "banned"
	ReasonFake   Reason = "fake"
	ReasonScam   Reason = "scam"
	ReasonOther  Reason = "other"
)

var reasons = []Reason{ReasonBanned, ReasonFake, ReasonScam, ReasonOther}

// MaxNote caps a report's note, counted after trimming.
const MaxNote = 500

// Report is a person telling ShopNexus that a listing or an account breaks
// the rules. AccountID is the account reported, the seller for a listing;
// ListingID is zero for an account report.
type Report struct {
	id          uuid.UUID
	reporterID  uuid.UUID
	accountID   uuid.UUID
	listingID   uuid.UUID
	reason      Reason
	note        string
	createdAt   time.Time
	updatedAt   time.Time
	withdrawnAt *time.Time
}

// NewReport checks a report: not of the reporter, a known reason, and a
// note of at most 500 characters after trimming.
func NewReport(id, reporter, account, listing uuid.UUID, reason Reason, note string, now time.Time) (Report, error) {
	if reporter == account {
		return Report{}, ErrSelfReport
	}
	e := ErrInvalidReport
	note = strings.TrimSpace(note)
	if !slices.Contains(reasons, reason) {
		e = e.WithField("reason", "banned, fake, scam or other")
	}
	if utf8.RuneCountInString(note) > MaxNote {
		e = e.WithField("note", "at most 500 characters")
	}
	if len(e.Fields) > 0 {
		return Report{}, e
	}
	return Report{
		id: id, reporterID: reporter, accountID: account, listingID: listing, reason: reason, note: note,
		createdAt: now, updatedAt: now,
	}, nil
}

func (r *Report) ID() uuid.UUID             { return r.id }
func (r *Report) ReporterID() uuid.UUID     { return r.reporterID }
func (r *Report) AccountID() uuid.UUID      { return r.accountID }
func (r *Report) ListingID() uuid.UUID      { return r.listingID }
func (r *Report) Reason() Reason            { return r.reason }
func (r *Report) Note() string              { return r.note }
func (r *Report) CreatedAt() time.Time      { return r.createdAt }
func (r *Report) UpdatedAt() time.Time      { return r.updatedAt }
func (r *Report) WithdrawnAt() *time.Time   { return r.withdrawnAt }

// ReportState is every stored field of a report. Stores only.
type ReportState struct {
	ID          uuid.UUID
	ReporterID  uuid.UUID
	AccountID   uuid.UUID
	ListingID   uuid.UUID
	Reason      Reason
	Note        string
	CreatedAt   time.Time
	UpdatedAt   time.Time
	WithdrawnAt *time.Time
}

// RestoreReport rebuilds a stored report. Stores only.
func RestoreReport(st ReportState) Report {
	return Report{
		id: st.ID, reporterID: st.ReporterID, accountID: st.AccountID, listingID: st.ListingID, reason: st.Reason,
		note: st.Note, createdAt: st.CreatedAt, updatedAt: st.UpdatedAt, withdrawnAt: st.WithdrawnAt,
	}
}

// State returns every stored field. Stores only.
func (r *Report) State() ReportState {
	return ReportState{
		ID: r.id, ReporterID: r.reporterID, AccountID: r.accountID, ListingID: r.listingID, Reason: r.reason,
		Note: r.note, CreatedAt: r.createdAt, UpdatedAt: r.updatedAt, WithdrawnAt: r.withdrawnAt,
	}
}
```

Update the package comment of `internal/trust/domain` ("module trust's entities: the review a buyer gives the seller of a shipped order, and the reports people make of listings and accounts"). Run `golangci-lint fmt` to align the getters. Run the domain test → PASS.

- [ ] **Step 3: Write the failing store test**

`internal/trust/repository/report_pg_test.go`. Read `review_pg_test.go` first for how it makes accounts and a listing (`accounttest.New`, `catalogtest.Listing`) and copy its imports:

```go
package repository_test

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server/internal/account/accounttest"
	"github.com/shopnexus/server/internal/catalog/catalogtest"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server/internal/trust/domain"
	"github.com/shopnexus/server/internal/trust/repository"
)

func TestReports(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewReports(db)
	reporter, seller := accounttest.New(t, db), accounttest.New(t, db)
	listing := catalogtest.Listing(t, db, seller)
	at := time.Now().UTC().Truncate(time.Microsecond)
	report := func(listing uuid.UUID, reason domain.Reason, note string, at time.Time) domain.Report {
		t.Helper()
		r, err := domain.NewReport(uuid.NewV7(), reporter, seller, listing, reason, note, at)
		if err != nil {
			t.Fatal(err)
		}
		return r
	}

	first, added, err := s.Open(ctx, report(listing, domain.ReasonFake, "", at))
	if err != nil || !added || first.ListingID() != listing {
		t.Fatalf("open: %+v %v %v", first.State(), added, err)
	}
	again, added, err := s.Open(ctx, report(listing, domain.ReasonScam, "Đòi chuyển khoản trước", at.Add(time.Minute)))
	if err != nil || added || again.ID() != first.ID() || again.Reason() != domain.ReasonScam ||
		again.Note() != "Đòi chuyển khoản trước" || !again.CreatedAt().Equal(at) || !again.UpdatedAt().Equal(at.Add(time.Minute)) {
		t.Fatalf("again: %+v %v %v", again.State(), added, err)
	}
	// The account report is a target of its own.
	person, added, err := s.Open(ctx, report(uuid.UUID{}, domain.ReasonScam, "", at))
	if err != nil || !added || person.ID() == first.ID() || person.ListingID() != (uuid.UUID{}) {
		t.Fatalf("account: %+v %v %v", person.State(), added, err)
	}

	for range 2 {
		if err = s.Withdraw(ctx, first.ID(), at.Add(2*time.Minute)); err != nil {
			t.Fatal(err)
		}
	}
	got, err := s.Get(ctx, first.ID())
	if err != nil || got.WithdrawnAt() == nil || !got.WithdrawnAt().Equal(at.Add(2*time.Minute)) {
		t.Fatalf("withdrawn: %+v %v", got.State(), err)
	}
	if next, added, err := s.Open(ctx, report(listing, domain.ReasonFake, "", at)); err != nil || !added || next.ID() == first.ID() {
		t.Fatalf("after a withdrawal: %+v %v %v", next.State(), added, err)
	}
	if _, err = s.Get(ctx, uuid.NewV7()); !errors.Is(err, repository.ErrNotFound) {
		t.Fatalf("unknown: %v", err)
	}
}

// Two reports of one listing at once leave one open row.
func TestReportsAtOnce(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewReports(db)
	reporter, seller := accounttest.New(t, db), accounttest.New(t, db)
	listing := catalogtest.Listing(t, db, seller)
	ids := make([]uuid.UUID, 2)
	var wg sync.WaitGroup
	for i := range ids {
		wg.Go(func() {
			r, err := domain.NewReport(uuid.NewV7(), reporter, seller, listing, domain.ReasonFake, "", time.Now())
			if err != nil {
				t.Error(err)
				return
			}
			got, _, err := s.Open(ctx, r)
			if err != nil {
				t.Error(err)
				return
			}
			ids[i] = got.ID()
		})
	}
	wg.Wait()
	if ids[0] != ids[1] {
		t.Fatalf("two rows: %v", ids)
	}
}
```

Run: `go test ./internal/trust/repository/ -run TestReports -count=1` → build failure.

- [ ] **Step 4: Implement the store**

Add to `internal/trust/repository/repository.go` (and change the package comment to "stores module trust's reviews and reports"):

```go
// Reports persists reports. A reporter has at most one open report of a
// listing and one of an account.
type Reports interface {
	// Open adds r or, when its reporter has an open report of the same
	// target, replaces that report's reason and note with r's; it returns
	// the stored report and whether it was added.
	Open(ctx context.Context, r domain.Report) (domain.Report, bool, error)
	// Get returns a report, open or withdrawn, or ErrNotFound.
	Get(ctx context.Context, id uuid.UUID) (domain.Report, error)
	// Withdraw marks an open report withdrawn at at; a withdrawn one keeps
	// its time.
	Withdraw(ctx context.Context, id uuid.UUID, at time.Time) error
}
```

(add `time` to its imports).

`internal/trust/repository/report_pg.go`:

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

	"github.com/shopnexus/server/internal/trust/domain"
)

type pgReports struct{ db *pgxpool.Pool }

func NewReports(db *pgxpool.Pool) Reports { return pgReports{db} }

const reportColumns = `id, reporter_id, account_id, listing_id, reason, note, created_at, updated_at, withdrawn_at`

// scanReport reads reportColumns, then any more destinations.
func scanReport(row pgx.Row, more ...any) (domain.Report, error) {
	var (
		st      domain.ReportState
		listing *uuid.UUID
	)
	dest := append([]any{&st.ID, &st.ReporterID, &st.AccountID, &listing, &st.Reason, &st.Note, &st.CreatedAt,
		&st.UpdatedAt, &st.WithdrawnAt}, more...)
	if err := row.Scan(dest...); err != nil {
		return domain.Report{}, fmt.Errorf("scan report: %w", err)
	}
	if listing != nil {
		st.ListingID = *listing
	}
	return domain.RestoreReport(st), nil
}

func (s pgReports) Open(ctx context.Context, r domain.Report) (domain.Report, bool, error) {
	st := r.State()
	// Each target has its partial index; ON CONFLICT names the one it hits.
	target := `(reporter_id, account_id) WHERE withdrawn_at IS NULL AND listing_id IS NULL`
	var listing *uuid.UUID
	if st.ListingID != (uuid.UUID{}) {
		target, listing = `(reporter_id, listing_id) WHERE withdrawn_at IS NULL AND listing_id IS NOT NULL`, &st.ListingID
	}
	var added bool
	got, err := scanReport(s.db.QueryRow(ctx, `INSERT INTO reports (`+reportColumns+`)
VALUES (@id, @reporter, @account, @listing, @reason, @note, @created_at, @updated_at, NULL)
ON CONFLICT `+target+` DO UPDATE
SET reason = EXCLUDED.reason, note = EXCLUDED.note, updated_at = EXCLUDED.updated_at
RETURNING `+reportColumns+`, xmax = 0`, pgx.StrictNamedArgs{
		"id": st.ID, "reporter": st.ReporterID, "account": st.AccountID, "listing": listing, "reason": st.Reason,
		"note": st.Note, "created_at": st.CreatedAt, "updated_at": st.UpdatedAt,
	}), &added)
	if err != nil {
		return domain.Report{}, false, fmt.Errorf("upsert report: %w", err)
	}
	return got, added, nil
}

func (s pgReports) Get(ctx context.Context, id uuid.UUID) (domain.Report, error) {
	r, err := scanReport(s.db.QueryRow(ctx, `SELECT `+reportColumns+` FROM reports WHERE id = @id`, pgx.StrictNamedArgs{"id": id}))
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Report{}, ErrNotFound
	}
	return r, err
}

func (s pgReports) Withdraw(ctx context.Context, id uuid.UUID, at time.Time) error {
	if _, err := s.db.Exec(ctx, `UPDATE reports SET withdrawn_at = @at, updated_at = @at
WHERE id = @id AND withdrawn_at IS NULL`, pgx.StrictNamedArgs{"id": id, "at": at}); err != nil {
		return fmt.Errorf("withdraw report: %w", err)
	}
	return nil
}
```

`domain.Reason` is a string type; pgx encodes and scans it as text. If pgx refuses the named type, pass `string(st.Reason)` and scan into a `string` first.

- [ ] **Step 5: Run**

Run: `go test ./internal/trust/... -count=1` → PASS.

- [ ] **Step 6: Commit**

```bash
git add internal/trust/domain internal/trust/repository
git commit -m "feat(trust): the report entity and its store, one open report per target"
```

---

### Task 5: Report endpoints

**Files:**
- Modify: `api/openapi.yaml`, `api/paths/trust.yaml`, `api/schemas/trust.yaml`
- Create: `internal/trust/service/report.go`, `internal/trust/handler/report.go`
- Modify: `internal/trust/service/service.go`, `internal/trust/service/views.go`, `internal/trust/handler/handler.go`, `internal/trust/trust.go`, `internal/trust/service/helpers_test.go`
- Test: `internal/trust/service/report_test.go`, `e2e/report_test.go`

**Interfaces:**
- Consumes: Task 4's `domain.NewReport`, `repository.Reports`; `catalogsvc.Service.Summary(ctx, id) (Summary, bool, error)`; `accountsvc.Service.Get`, `accountsvc.Service.Suspended`.
- Produces (`trustsvc.Service`): `Report(ctx, reporter uuid.UUID, in ReportInput) (ReportView, bool, error)` (bool = added) and `WithdrawReport(ctx, reporter, id uuid.UUID) error`; `type ReportInput struct { ListingID, AccountID uuid.UUID; Reason domain.Reason; Note string }`; `type ReportView` (JSON `id, listing_id,omitzero, account_id, reason, note, created_at, updated_at`).
- Endpoints: `POST /v1/reports` (`createReport`), `DELETE /v1/reports/{id}` (`withdrawReport`).

- [ ] **Step 1: Write the spec**

`api/openapi.yaml`, after `/v1/sellers/{id}/reviews`:

```yaml
  /v1/reports:
    $ref: "paths/trust.yaml#/reports"
  /v1/reports/{id}:
    $ref: "paths/trust.yaml#/report"
```

Append to `api/paths/trust.yaml`:

```yaml
reports:
  post:
    operationId: createReport
    summary: Report a listing or an account.
    description: |
      Exactly one of listing_id and account_id. A report of a listing is
      also about its seller, whom account_id names in the answer. The
      caller has one open report per target: reporting it again replaces
      the reason and note and answers 200.
    tags: [trust]
    security:
      - bearerAuth: []
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/trust.yaml#/ReportCreate"
    responses:
      "200":
        description: The open report of the target, with the new reason and note.
        content:
          application/json:
            schema:
              $ref: "../schemas/trust.yaml#/Report"
      "201":
        description: The report, opened.
        content:
          application/json:
            schema:
              $ref: "../schemas/trust.yaml#/Report"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "403":
        $ref: "../responses/common.yaml#/Forbidden"
      "404":
        description: "No such listing, or a deleted one (listing_not_found), or no such account (account_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: "A rule is broken (invalid_report, with fields), or the caller named themselves or their own listing (self_report)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
report:
  delete:
    operationId: withdrawReport
    summary: Withdraw one of the caller's reports; a withdrawn one is fine.
    tags: [trust]
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
        description: Withdrawn.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "No such report of the caller's (report_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

Append to `api/schemas/trust.yaml`:

```yaml
ReportCreate:
  type: object
  additionalProperties: false
  required: [reason]
  properties:
    listing_id:
      type: string
      format: uuid
    account_id:
      type: string
      format: uuid
    reason:
      type: string
      description: banned, fake, scam or other; a business rule, so another value is 422.
    note:
      type: string
      description: At most 500 characters after trimming; may be empty.
Report:
  type: object
  additionalProperties: false
  required: [id, account_id, reason, note, created_at, updated_at]
  properties:
    id:
      type: string
      format: uuid
    listing_id:
      type: string
      format: uuid
      description: The listing reported; absent for a report of an account.
    account_id:
      type: string
      format: uuid
      description: The account reported, the seller for a listing.
    reason:
      type: string
      enum: [banned, fake, scam, other]
    note:
      type: string
    created_at:
      type: string
      format: date-time
    updated_at:
      type: string
      format: date-time
```

Run: `go test ./api/ -count=1` → PASS.

- [ ] **Step 2: Write the failing service test**

In `internal/trust/service/helpers_test.go`, `newEnv`: pass `Reports: repository.NewReports(db)` to `service.New`. Then `internal/trust/service/report_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"testing"
	"uuid"

	"github.com/shopnexus/server/internal/account/accounttest"
	accountdomain "github.com/shopnexus/server/internal/account/domain"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/catalog/catalogtest"
	"github.com/shopnexus/server/internal/trust/domain"
	"github.com/shopnexus/server/internal/trust/service"
)

func TestReport(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	e := newEnv(t)
	reporter, seller := e.person(t), e.person(t)
	listing := catalogtest.Listing(t, e.db, seller)

	v, added, err := e.trust.Report(ctx, reporter, service.ReportInput{ListingID: listing, Reason: domain.ReasonFake})
	if err != nil || !added || v.AccountID != seller || v.ListingID != listing || v.Reason != domain.ReasonFake {
		t.Fatalf("listing: %+v %v %v", v, added, err)
	}
	again, added, err := e.trust.Report(ctx, reporter, service.ReportInput{ListingID: listing, Reason: domain.ReasonScam, Note: "Đòi cọc"})
	if err != nil || added || again.ID != v.ID || again.Note != "Đòi cọc" {
		t.Fatalf("again: %+v %v %v", again, added, err)
	}
	person, added, err := e.trust.Report(ctx, reporter, service.ReportInput{AccountID: seller, Reason: domain.ReasonScam})
	if err != nil || !added || person.ID == v.ID || person.ListingID != (uuid.UUID{}) {
		t.Fatalf("account: %+v %v %v", person, added, err)
	}

	for name, c := range map[string]struct {
		in   service.ReportInput
		want error
	}{
		"both targets":     {service.ReportInput{ListingID: listing, AccountID: seller, Reason: domain.ReasonFake}, domain.ErrInvalidReport},
		"no target":        {service.ReportInput{Reason: domain.ReasonFake}, domain.ErrInvalidReport},
		"unknown listing":  {service.ReportInput{ListingID: uuid.NewV7(), Reason: domain.ReasonFake}, catalogdomain.ErrNotFound},
		"unknown account":  {service.ReportInput{AccountID: uuid.NewV7(), Reason: domain.ReasonFake}, accountdomain.ErrAccountNotFound},
		"oneself":          {service.ReportInput{AccountID: reporter, Reason: domain.ReasonFake}, domain.ErrSelfReport},
		"unknown reason":   {service.ReportInput{AccountID: seller, Reason: "ugly"}, domain.ErrInvalidReport},
	} {
		if _, _, err := e.trust.Report(ctx, reporter, c.in); !errors.Is(err, c.want) {
			t.Errorf("%s: %v", name, err)
		}
	}
	if _, _, err = e.trust.Report(ctx, seller, service.ReportInput{ListingID: listing, Reason: domain.ReasonFake}); !errors.Is(err, domain.ErrSelfReport) {
		t.Fatalf("own listing: %v", err)
	}

	if err = e.trust.WithdrawReport(ctx, seller, v.ID); !errors.Is(err, domain.ErrReportNotFound) {
		t.Fatalf("someone else's: %v", err)
	}
	if err = e.trust.WithdrawReport(ctx, reporter, uuid.NewV7()); !errors.Is(err, domain.ErrReportNotFound) {
		t.Fatalf("unknown: %v", err)
	}
	for range 2 {
		if err = e.trust.WithdrawReport(ctx, reporter, v.ID); err != nil {
			t.Fatal(err)
		}
	}

	accounttest.Suspend(t, e.accounts, reporter)
	if _, _, err = e.trust.Report(ctx, reporter, service.ReportInput{AccountID: seller, Reason: domain.ReasonFake}); !errors.Is(err, accountdomain.ErrSuspended) {
		t.Fatalf("suspended: %v", err)
	}
}

// A deleted listing cannot be reported; a hidden one can.
func TestReportListingStates(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	e := newEnv(t)
	reporter, seller := e.person(t), e.person(t)
	hidden, deleted := catalogtest.Listing(t, e.db, seller), catalogtest.Listing(t, e.db, seller)
	if _, err := e.db.Exec(ctx, `UPDATE listings SET status = CASE WHEN id = $1 THEN 'hidden' ELSE 'deleted' END,
    deleted_at = CASE WHEN id = $2 THEN now() END WHERE id IN ($1, $2)`, hidden, deleted); err != nil {
		t.Fatal(err)
	}
	if _, _, err := e.trust.Report(ctx, reporter, service.ReportInput{ListingID: hidden, Reason: domain.ReasonBanned}); err != nil {
		t.Fatalf("hidden: %v", err)
	}
	if _, _, err := e.trust.Report(ctx, reporter, service.ReportInput{ListingID: deleted, Reason: domain.ReasonBanned}); !errors.Is(err, catalogdomain.ErrNotFound) {
		t.Fatalf("deleted: %v", err)
	}
}
```

If the `listings` table has a check that ties `status` to other columns, set the listing states through `catalogsvc` (`Hide`, `Delete` on the catalog service `e` builds) instead of SQL; read `internal/catalog/service/listing_test.go` for the calls.

Run: `go test ./internal/trust/service/ -run TestReport -count=1` → build failure.

- [ ] **Step 3: Implement the use cases**

`internal/trust/service/service.go`: add to `Service`:

```go
	// Report opens the reporter's report of a listing or an account, or
	// replaces the reason and note of their open report of it; the bool is
	// whether it opened one.
	Report(ctx context.Context, reporter uuid.UUID, in ReportInput) (ReportView, bool, error)
	// WithdrawReport withdraws one of the reporter's reports; a withdrawn
	// one is fine.
	WithdrawReport(ctx context.Context, reporter, id uuid.UUID) error
```

add `Reports repository.Reports` to `Deps` and `reports repository.Reports` to `Trust`, set in `New`. Change the package comment to "module trust's use cases: a buyer reviews the seller of a shipped order, anyone reads a seller's rating and reviews, and people report listings and accounts". In `internal/trust/trust.go`, pass `Reports: repository.NewReports(d.Pool)` and change the package comment to "reviews buyers give sellers, the rating they add up to, and the reports people make of listings and accounts".

Add to `internal/trust/service/views.go`:

```go
// ReportInput is what POST /v1/reports carries: exactly one of ListingID
// and AccountID.
type ReportInput struct {
	ListingID uuid.UUID
	AccountID uuid.UUID
	Reason    domain.Reason
	Note      string
}

// ReportView is the Report schema in api/schemas/trust.yaml. ListingID is
// zero for a report of an account.
type ReportView struct {
	ID        uuid.UUID     `json:"id"`
	ListingID uuid.UUID     `json:"listing_id,omitzero"`
	AccountID uuid.UUID     `json:"account_id"`
	Reason    domain.Reason `json:"reason"`
	Note      string        `json:"note"`
	CreatedAt time.Time     `json:"created_at"`
	UpdatedAt time.Time     `json:"updated_at"`
}
```

`internal/trust/service/report.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"uuid"

	accountdomain "github.com/shopnexus/server/internal/account/domain"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/trust/domain"
	"github.com/shopnexus/server/internal/trust/repository"
)

// Report checks that the reporter may write and names one target that
// exists, takes a listing's seller as the account reported, then opens the
// report or updates the open one.
func (s *Trust) Report(ctx context.Context, reporter uuid.UUID, in ReportInput) (ReportView, bool, error) {
	suspended, err := s.accounts.Suspended(ctx, reporter)
	if err != nil {
		return ReportView{}, false, fmt.Errorf("read account status: %w", err)
	}
	if suspended {
		return ReportView{}, false, accountdomain.ErrSuspended
	}
	if (in.ListingID == uuid.UUID{}) == (in.AccountID == uuid.UUID{}) {
		return ReportView{}, false, domain.ErrInvalidReport.WithField("target", "exactly one of listing_id and account_id")
	}
	account := in.AccountID
	if in.ListingID != (uuid.UUID{}) {
		l, found, err := s.catalog.Summary(ctx, in.ListingID)
		if err != nil {
			return ReportView{}, false, fmt.Errorf("read listing: %w", err)
		}
		if !found || l.Status == catalogdomain.StatusDeleted {
			return ReportView{}, false, catalogdomain.ErrNotFound
		}
		account = l.SellerID
	} else if _, err = s.accounts.Get(ctx, account); err != nil {
		return ReportView{}, false, err
	}
	r, err := domain.NewReport(uuid.NewV7(), reporter, account, in.ListingID, in.Reason, in.Note, s.now())
	if err != nil {
		return ReportView{}, false, err
	}
	r, added, err := s.reports.Open(ctx, r)
	if err != nil {
		return ReportView{}, false, fmt.Errorf("open report: %w", err)
	}
	return ReportView{
		ID: r.ID(), ListingID: r.ListingID(), AccountID: r.AccountID(), Reason: r.Reason(), Note: r.Note(),
		CreatedAt: r.CreatedAt(), UpdatedAt: r.UpdatedAt(),
	}, added, nil
}

// WithdrawReport withdraws the reporter's report; anyone else's, or an
// unknown ID, is domain.ErrReportNotFound.
func (s *Trust) WithdrawReport(ctx context.Context, reporter, id uuid.UUID) error {
	r, err := s.reports.Get(ctx, id)
	if errors.Is(err, repository.ErrNotFound) || (err == nil && r.ReporterID() != reporter) {
		return domain.ErrReportNotFound
	}
	if err != nil {
		return fmt.Errorf("get report: %w", err)
	}
	if err = s.reports.Withdraw(ctx, id, s.now()); err != nil {
		return fmt.Errorf("withdraw report: %w", err)
	}
	return nil
}
```

Run: `go test ./internal/trust/... -count=1` → PASS.

- [ ] **Step 4: Write the handlers**

`internal/trust/handler/report.go`:

```go
package handler

import (
	"net/http"
	"uuid"

	"github.com/shopnexus/server/internal/platform/httpx"
	"github.com/shopnexus/server/internal/trust/domain"
	"github.com/shopnexus/server/internal/trust/service"
)

type reportRequest struct {
	ListingID uuid.UUID `json:"listing_id"`
	AccountID uuid.UUID `json:"account_id"`
	Reason    string    `json:"reason"`
	Note      string    `json:"note"`
}

type reportIDRequest struct {
	ID uuid.UUID `json:"-" path:"id"`
}

// Report serves POST /v1/reports: 201 for a new report, 200 for the open
// one updated.
func (h *Handler) Report(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in reportRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	v, added, err := h.svc.Report(r.Context(), p.AccountID, service.ReportInput{
		ListingID: in.ListingID, AccountID: in.AccountID, Reason: domain.Reason(in.Reason), Note: in.Note,
	})
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	status := http.StatusOK
	if added {
		status = http.StatusCreated
	}
	httpx.Respond(w, status, v)
}

// WithdrawReport serves DELETE /v1/reports/{id}.
func (h *Handler) WithdrawReport(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in reportIDRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.WithdrawReport(r.Context(), p.AccountID, in.ID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

In `Register` (`internal/trust/handler/handler.go`), add and update its comment ("a seller's reviews are public; reports need a signed-in caller"):

```go
	r.Handle("POST /v1/reports", protect(http.HandlerFunc(h.Report)))
	r.Handle("DELETE /v1/reports/{id}", protect(http.HandlerFunc(h.WithdrawReport)))
```

Run: `go test ./internal/app/ -run TestRoutesMatchSpec -count=1` → PASS.

- [ ] **Step 5: Write the e2e test**

`e2e/report_test.go`:

```go
package e2e

import (
	"net/http"
	"strings"
	"testing"
	"uuid"
)

type report struct {
	ID        string `json:"id"`
	ListingID string `json:"listing_id"`
	AccountID string `json:"account_id"`
	Reason    string `json:"reason"`
	Note      string `json:"note"`
}

func TestReports(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	reporter, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	send := func(token string, body any) Response {
		t.Helper()
		return call(t, "POST", "/v1/reports", body, bearer(token))
	}

	first := expect[report](t, send(reporter.AccessToken, map[string]any{"listing_id": l.ID, "reason": "fake"}), http.StatusCreated)
	if first.AccountID != seller.Account.ID || first.ListingID != l.ID || first.Reason != "fake" {
		t.Fatalf("first: %+v", first)
	}
	again := expect[report](t, send(reporter.AccessToken, map[string]any{"listing_id": l.ID, "reason": "scam", "note": " Đòi cọc "}), http.StatusOK)
	if again.ID != first.ID || again.Reason != "scam" || again.Note != "Đòi cọc" {
		t.Fatalf("again: %+v", again)
	}
	person := expect[report](t, send(reporter.AccessToken, map[string]any{"account_id": seller.Account.ID, "reason": "scam"}), http.StatusCreated)
	if person.ListingID != "" || person.AccountID != seller.Account.ID {
		t.Fatalf("account: %+v", person)
	}

	check(t, "signed out", send("", map[string]any{"account_id": seller.Account.ID, "reason": "scam"}), 401, "unauthenticated")
	check(t, "a bad id", send(reporter.AccessToken, map[string]any{"account_id": "x", "reason": "scam"}), 400, "")
	check(t, "no reason", send(reporter.AccessToken, map[string]any{"account_id": seller.Account.ID}), 400, "")
	check(t, "both targets", send(reporter.AccessToken, map[string]any{"listing_id": l.ID, "account_id": seller.Account.ID, "reason": "scam"}), 422, "invalid_report")
	check(t, "an unknown reason", send(reporter.AccessToken, map[string]any{"account_id": seller.Account.ID, "reason": "ugly"}), 422, "invalid_report")
	check(t, "a long note", send(reporter.AccessToken, map[string]any{"account_id": seller.Account.ID, "reason": "other", "note": strings.Repeat("ạ", 501)}), 422, "invalid_report")
	check(t, "oneself", send(reporter.AccessToken, map[string]any{"account_id": reporter.Account.ID, "reason": "scam"}), 422, "self_report")
	check(t, "one's own listing", send(seller.AccessToken, map[string]any{"listing_id": l.ID, "reason": "scam"}), 422, "self_report")
	check(t, "an unknown listing", send(reporter.AccessToken, map[string]any{"listing_id": uuid.NewV7().String(), "reason": "scam"}), 404, "listing_not_found")
	check(t, "an unknown account", send(reporter.AccessToken, map[string]any{"account_id": uuid.NewV7().String(), "reason": "scam"}), 404, "account_not_found")

	gone := activeListing(t, seller.AccessToken, nil)
	expectStatus(t, call(t, "DELETE", "/v1/listings/"+gone.ID, nil, bearer(seller.AccessToken)), http.StatusNoContent)
	check(t, "a deleted listing", send(reporter.AccessToken, map[string]any{"listing_id": gone.ID, "reason": "scam"}), 404, "listing_not_found")

	check(t, "withdraw someone else's", call(t, "DELETE", "/v1/reports/"+first.ID, nil, bearer(seller.AccessToken)), 404, "report_not_found")
	check(t, "withdraw", call(t, "DELETE", "/v1/reports/"+first.ID, nil, bearer(reporter.AccessToken)), 204, "")
	check(t, "withdraw again", call(t, "DELETE", "/v1/reports/"+first.ID, nil, bearer(reporter.AccessToken)), 204, "")
	check(t, "withdraw signed out", call(t, "DELETE", "/v1/reports/"+first.ID, nil), 401, "unauthenticated")
	check(t, "withdraw a bad id", call(t, "DELETE", "/v1/reports/x", nil, bearer(reporter.AccessToken)), 400, "")
	next := expect[report](t, send(reporter.AccessToken, map[string]any{"listing_id": l.ID, "reason": "fake"}), http.StatusCreated)
	if next.ID == first.ID {
		t.Fatal("a report after a withdrawal reused the withdrawn one")
	}

	suspended, _ := newAccount(t)
	suspend(t, suspended.Account.ID)
	check(t, "a suspended reporter", send(suspended.AccessToken, map[string]any{"account_id": seller.Account.ID, "reason": "scam"}), 403, "account_suspended")
}
```

If `DELETE /v1/listings/{id}` answers another status than 204, use the one `api/paths/catalog.yaml` declares.

Run: `make test` → PASS, the coverage check included.

- [ ] **Step 6: Commit**

```bash
git add api internal/trust e2e/report_test.go
git commit -m "feat(trust): POST /v1/reports and DELETE /v1/reports/{id}"
```

---

### Task 6: listing.published marks the first publication

**Files:**
- Modify: `internal/catalog/domain/listing.go` (`Published`)
- Modify: `internal/catalog/service/listing_publish_durable.go`
- Test: `internal/catalog/domain/listing_test.go`, `internal/catalog/service/listing_test.go`

**Interfaces:**
- Produces: `func (l *Listing) Published(keys map[uuid.UUID]PhotoKeys, now time.Time) (first bool)`; event `listing.published` with `Payload{"first": true}` on the first publication only (no payload otherwise).

- [ ] **Step 1: Write the failing domain test**

Append to `internal/catalog/domain/listing_test.go`:

```go
// Only the first publication is first: not one after a rejection, nor one
// after an edit that added a photo.
func TestPublishedTellsTheFirst(t *testing.T) {
	t.Parallel()
	l := newListing(t)
	keys := func() map[uuid.UUID]domain.PhotoKeys {
		k := map[uuid.UUID]domain.PhotoKeys{}
		for _, id := range l.PendingUploads() {
			k[id] = domain.PhotoKeys{Photo: "media/" + id.String() + ".jpg", Thumb: "media/" + id.String() + "_thumb.jpg"}
		}
		return k
	}
	if !l.Published(keys(), now) {
		t.Fatal("the first publication is not first")
	}
	d := draft()
	d.Photos = append(l.Uploads(), uuid.NewV7())
	if err := l.Edit(d, known, now.Add(time.Hour)); err != nil || l.Status() != domain.StatusProcessing {
		t.Fatalf("edit: %v %s", err, l.Status())
	}
	l.Rejected(map[uuid.UUID]string{d.Photos[len(d.Photos)-1]: "nsfw"}, now.Add(time.Hour))
	if err := l.Edit(d, known, now.Add(2*time.Hour)); err != nil {
		t.Fatal(err)
	}
	if l.Published(keys(), now.Add(2*time.Hour)) {
		t.Fatal("a publication after a rejection is first")
	}
	if !l.PublishedAt().Equal(now) {
		t.Fatalf("published_at moved: %v", l.PublishedAt())
	}
}
```

Run: `go test ./internal/catalog/domain/ -run TestPublishedTellsTheFirst -count=1` → build failure (`l.Published` used as value).

- [ ] **Step 2: Implement**

In `internal/catalog/domain/listing.go`:

```go
// Published records the keys of the processed uploads and puts the listing
// on sale. It reports whether this is the listing's first publication.
func (l *Listing) Published(keys map[uuid.UUID]PhotoKeys, now time.Time) (first bool) {
	for i := range l.photos {
		if k, ok := keys[l.photos[i].UploadID]; ok {
			l.photos[i].Keys = k
		}
	}
	l.status, l.rejection, l.updatedAt = StatusActive, nil, now
	if l.publishedAt == nil {
		l.publishedAt = &now
		return true
	}
	return false
}
```

In `internal/catalog/service/listing_publish_durable.go`, the `else` branch:

```go
	} else {
		ev := events.Event{ID: restatex.NewID(ctx, at), Kind: events.ListingPublished, SubjectID: id, OccurredAt: at}
		// Followers hear of a listing once, when it first goes on sale.
		if l.Published(keys, at) {
			ev.Payload = map[string]any{"first": true}
		}
		evs = append(evs, ev)
	}
```

`restatex.NewID` is journaled, so taking it before `Published` changes no ID a replay sees; keep the call order the same on every run. Update the comment on `events.ListingPublished` in `internal/platform/events/events.go` if it has one: "payload `first: true` on the listing's first publication".

- [ ] **Step 3: Pin the payload in the service test**

In `internal/catalog/service/listing_test.go`, in the edit test that checks `want := []string{"listing.published", "listing.updated", "listing.updated", "listing.published"}`, add after that check:

```go
	rows, err := e.db.Query(ctx, `SELECT coalesce((payload->>'first')::bool, false) FROM events
WHERE subject_id = @id AND kind = 'listing.published' ORDER BY id`, pgx.StrictNamedArgs{"id": v.ID})
	if err != nil {
		t.Fatal(err)
	}
	firsts, err := pgx.CollectRows(rows, pgx.RowTo[bool])
	if err != nil || !slices.Equal(firsts, []bool{true, false}) {
		t.Fatalf("first flags %v %v, want [true false]", firsts, err)
	}
```

(import `github.com/jackc/pgx/v5` if the file lacks it; `ctx` and `e.db` are already in scope there).

- [ ] **Step 4: Run**

Run: `go test ./internal/catalog/... -count=1` → PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/catalog internal/platform/events
git commit -m "feat(catalog): listing.published carries first on a listing's first publication"
```

---

### Task 7: Followers hear of a new listing

**Files:**
- Modify: `internal/notification/domain/notice.go`, `internal/notification/worker/worker.go`, `internal/notification/notification.go`, `api/schemas/notification.yaml`
- Test: `internal/notification/domain/notice_test.go`, `internal/notification/worker/worker_test.go`, `e2e/follow_test.go`

**Interfaces:**
- Consumes: `accountsvc.Service.Get`, `accountsvc.Service.Followers` (Task 2); `catalogsvc.Service.Summary`; the `first` payload (Task 6).
- Produces: `domain.TypeFollowedListing = "followed_listing"`; `domain.FollowedListing(follower, seller uuid.UUID, sellerName string, listing uuid.UUID, title string, at time.Time) Notice`; `worker.FollowerNotice{EventID, Follower, ListingID uuid.UUID; SellerName string; At time.Time}`; handler `NotificationWorker.TellFollower`; field `Worker.FollowerPage int`; `tell(ctx, event uuid.UUID, notices)` now takes the event ID.

- [ ] **Step 1: Write the failing domain test**

In `internal/notification/domain/notice_test.go`, add to the map in `TestText`:

```go
		"Hoàng Nam vừa đăng tin mới: Xe đạp Asama": domain.FollowedListing(buyer, seller, "Hoàng Nam", uuid.NewV7(), "Xe đạp Asama", at),
```

and a test:

```go
func TestFollowedListing(t *testing.T) {
	t.Parallel()
	listing := uuid.NewV7()
	n := domain.FollowedListing(buyer, seller, "Hoàng Nam", listing, "Xe đạp Asama", at)
	if n.Recipient != buyer || n.Type != domain.TypeFollowedListing || n.CollapseKey != "seller:"+seller.String() {
		t.Fatalf("%+v", n)
	}
	if got := domain.TargetOf(n.Type, n.Params); got.Kind != "listing" || got.ID != listing.String() {
		t.Fatalf("target %+v", got)
	}
	if domain.Title(n.Type) != "Tin đăng" {
		t.Fatalf("title %q", domain.Title(n.Type))
	}
}
```

Run: `go test ./internal/notification/domain/ -count=1` → build failure.

- [ ] **Step 2: Implement the notice**

In `internal/notification/domain/notice.go`: add `TypeFollowedListing Type = "followed_listing"` after `TypeListingRejected`; add

```go
// FollowedListing tells a follower that a seller they follow put a new
// listing on sale. It collapses per seller, so a run of listings leaves one
// unread notice, of the newest.
func FollowedListing(follower, seller uuid.UUID, sellerName string, listing uuid.UUID, title string, at time.Time) Notice {
	return Notice{
		Recipient: follower, Type: TypeFollowedListing, CollapseKey: "seller:" + seller.String(), At: at,
		Params: Params{ListingID: listing, SellerID: seller, Seller: sellerName, Title: title},
	}
}
```

and to `types`:

```go
	TypeFollowedListing: {listings, func(p Params) string { return p.Seller + " vừa đăng tin mới: " + p.Title }},
```

In `api/schemas/notification.yaml`, add `followed_listing` to the `type` enum after `listing_rejected`. Update the package comment of `internal/notification/notification.go` ("…listings, reviews and account, and of new listings by the sellers they follow…").

Run: `go test ./internal/notification/domain/ ./api/ -count=1` → PASS.

- [ ] **Step 3: Write the failing worker tests**

In `internal/notification/worker/worker_test.go`:

Replace the `catalog` fake with one that answers `Summary`:

```go
type catalog struct {
	catalogsvc.Service

	listings map[uuid.UUID]catalogsvc.Summary
}

func (c catalog) Summary(_ context.Context, id uuid.UUID) (catalogsvc.Summary, bool, error) {
	s, ok := c.listings[id]
	return s, ok, nil
}
```

Give the `accounts` fake a name and followers:

```go
// accounts answers that every session but the revoked ones is active, names
// every account Hoàng Nam, and pages followers, the newest follow first.
type accounts struct {
	accountsvc.Service

	revoked   map[uuid.UUID]bool
	followers []accountsvc.Follower // oldest follow first
}

func (a accounts) Get(_ context.Context, id uuid.UUID) (accountsvc.AccountView, error) {
	return accountsvc.AccountView{ID: id, DisplayName: "Hoàng Nam"}, nil
}

func (a accounts) Followers(_ context.Context, _ uuid.UUID, p page.Request) (page.Page[accountsvc.Follower], error) {
	var rows []accountsvc.Follower
	for i := len(a.followers) - 1; i >= 0 && len(rows) < p.Fetch(); i-- {
		if f := a.followers[i]; f.ID.String() < p.Before().String() {
			rows = append(rows, f)
		}
	}
	return page.Of(rows, p, func(f accountsvc.Follower) uuid.UUID { return f.ID }), nil
}
```

(`uuid.NewV7` IDs made in order compare in order as strings; `uuid.Max()` is above all.) In `newEnv`, set `Catalog: catalog{}` stays valid; add `FollowerPage: 2` to the `worker.Worker` literal.

Add the tests:

```go
// followed makes n follower accounts of a seller and a listing of the
// seller's in the fakes, and returns them.
func (e *env) followed(t *testing.T, n int, status catalogdomain.Status) (seller, listing uuid.UUID, followers []uuid.UUID) {
	t.Helper()
	seller, listing = accounttest.New(t, e.db), uuid.NewV7()
	var fs []accountsvc.Follower
	for range n {
		f := accounttest.New(t, e.db)
		followers = append(followers, f)
		fs = append(fs, accountsvc.Follower{ID: uuid.NewV7(), AccountID: f})
	}
	e.worker.Accounts = accounts{followers: fs}
	e.worker.Catalog = catalog{listings: map[uuid.UUID]catalogsvc.Summary{
		listing: {ID: listing, SellerID: seller, Title: "Xe đạp Asama", Status: status},
	}}
	return seller, listing, followers
}

// noticesOf polls account's list until it holds n notices.
func (e *env) noticesOf(t *testing.T, account uuid.UUID, n int) []service.NoticeView {
	t.Helper()
	var items []service.NoticeView
	testenv.Eventually(t, 30*time.Second, func() error {
		l, err := e.notices.List(context.Background(), account, page.Request{})
		if err != nil {
			return err
		}
		if items = l.Items; len(items) != n {
			return fmt.Errorf("%d notices, want %d", len(items), n)
		}
		return nil
	})
	return items
}

// A first publication tells the seller and every follower, across pages of
// two, once even when the event comes again.
func TestListingPublishedTellsFollowers(t *testing.T) {
	t.Parallel()
	e := newEnv(t, nil, nil)
	seller, listing, followers := e.followed(t, 5, catalogdomain.StatusActive)
	e.start(t)
	if err := e.notices.PutToken(context.Background(), uuid.NewV7(), followers[0], "follower-phone"); err != nil {
		t.Fatal(err)
	}
	ev := events.Event{
		ID: uuid.NewV7(), Kind: events.ListingPublished, SubjectID: listing, OccurredAt: time.Now(),
		Payload: map[string]any{"first": true},
	}
	e.deliver(t, "ListingPublished", ev)
	e.deliver(t, "ListingPublished", ev)
	for _, f := range followers {
		items := e.noticesOf(t, f, 1)
		if items[0].Type != "followed_listing" || items[0].Text != "Hoàng Nam vừa đăng tin mới: Xe đạp Asama" {
			t.Fatalf("follower %s: %+v", f, items[0])
		}
	}
	if items := e.noticesOf(t, seller, 1); items[0].Type != "listing_live" {
		t.Fatalf("seller: %+v", items[0])
	}
	testenv.Eventually(t, 30*time.Second, func() error {
		if n := e.push.count("follower-phone"); n != 1 {
			return fmt.Errorf("%d pushes", n)
		}
		return nil
	})
}

// A publication that is not the first tells the seller only.
func TestRepublishTellsNoFollower(t *testing.T) {
	t.Parallel()
	e := newEnv(t, nil, nil)
	seller, listing, followers := e.followed(t, 1, catalogdomain.StatusActive)
	e.start(t)
	e.deliver(t, "ListingPublished", events.Event{ID: uuid.NewV7(), Kind: events.ListingPublished, SubjectID: listing, OccurredAt: time.Now()})
	e.noticesOf(t, seller, 1)
	// ListingPublished sent nothing when the request returned, so nothing can
	// arrive later.
	if l, _ := e.notices.List(context.Background(), followers[0], page.Request{}); len(l.Items) != 0 {
		t.Fatalf("a republish told a follower: %+v", l)
	}
}

// TellFollower tells no one of a listing gone off sale, and two listings of
// one seller leave one unread notice, of the newer.
func TestTellFollower(t *testing.T) {
	t.Parallel()
	e := newEnv(t, nil, nil)
	seller, hidden, followers := e.followed(t, 1, catalogdomain.StatusHidden)
	newer := uuid.NewV7()
	e.worker.Catalog.(catalog).listings[newer] = catalogsvc.Summary{ID: newer, SellerID: seller, Title: "Đàn guitar Yamaha", Status: catalogdomain.StatusActive}
	older := uuid.NewV7()
	e.worker.Catalog.(catalog).listings[older] = catalogsvc.Summary{ID: older, SellerID: seller, Title: "Xe đạp Asama", Status: catalogdomain.StatusActive}
	e.start(t)
	tell := func(listing uuid.UUID, at time.Time) {
		t.Helper()
		in := worker.FollowerNotice{EventID: uuid.NewV7(), Follower: followers[0], ListingID: listing, SellerName: "Hoàng Nam", At: at}
		if _, err := ingress.Service[worker.FollowerNotice, restate.Void](e.client, e.worker.ServiceName(), "TellFollower").
			Request(context.Background(), in, restate.WithIdempotencyKey(in.EventID.String())); err != nil {
			t.Fatal(err)
		}
	}
	at := time.Now()
	tell(hidden, at)
	if l, _ := e.notices.List(context.Background(), followers[0], page.Request{}); len(l.Items) != 0 {
		t.Fatalf("a hidden listing told: %+v", l)
	}
	tell(older, at.Add(time.Second))
	tell(newer, at.Add(2*time.Second))
	l, err := e.notices.List(context.Background(), followers[0], page.Request{})
	if err != nil || len(l.Items) != 1 || l.Unread != 1 || l.Items[0].Text != "Hoàng Nam vừa đăng tin mới: Đàn guitar Yamaha" {
		t.Fatalf("collapse: %+v %v", l, err)
	}
}
```

`e.worker.Catalog` is a `catalogsvc.Service`; the type assertion works because `followed` stored a `catalog` value whose map is shared. If the list item type is not `service.NoticeView`, use the type `e.notices.List` returns (read `internal/notification/service/views.go`). Add the imports: `fmt`, `catalogdomain "github.com/shopnexus/server/internal/catalog/domain"`, `github.com/shopnexus/server/internal/platform/testenv`.

Run: `go test ./internal/notification/worker/ -count=1` → build failure (`worker.FollowerNotice`, `FollowerPage`).

- [ ] **Step 4: Implement the worker**

In `internal/notification/worker/worker.go`:

1. Add `FollowerPage int` to `Worker` with the comment "FollowerPage is how many followers one step reads when a listing first goes on sale." Update the type comment: "…A first publication sends each of the seller's followers to TellFollower, one invocation per follower, so each journal stays short."

2. Change `tell` to take the event ID, and its callers to pass `e.ID`:

```go
func (w Worker) tell(ctx restate.Context, event uuid.UUID, notices []domain.Notice) error {
	for i := range notices {
		n := &notices[i]
		rec, err := restate.Run(ctx, func(rc restate.RunContext) (service.Recorded, error) {
			return w.Notices.Record(rc, event, *n)
		})
		// … the rest unchanged
```

3. Make `listing` return the summary it read, and rewrite `ListingPublished` and `ListingRejected`:

```go
// FollowerNotice is what TellFollower needs: the event the listing went on
// sale in, the follower to tell and the seller's name.
type FollowerNotice struct {
	EventID    uuid.UUID `json:"event_id"`
	Follower   uuid.UUID `json:"follower"`
	ListingID  uuid.UUID `json:"listing_id"`
	SellerName string    `json:"seller_name"`
	At         time.Time `json:"at"`
}

// ListingPublished tells the seller the listing is on sale. On its first
// publication it also sends each of the seller's followers, a page per
// step, to TellFollower; the idempotency key names the event and the
// follower, so a replay sends nobody a second invocation.
func (w Worker) ListingPublished(ctx restate.Context, e events.Event) error {
	l, err := w.listing(ctx, e, true)
	if err != nil {
		return err
	}
	first, _ := e.Payload["first"].(bool) //nolint:revive // an event without the flag is not a first publication
	if l.ID == (uuid.UUID{}) || !first {
		return nil
	}
	name, err := restate.Run(ctx, func(rc restate.RunContext) (string, error) {
		a, stepErr := w.Accounts.Get(rc, l.SellerID)
		if errors.Is(stepErr, accountdomain.ErrAccountNotFound) {
			return "", nil
		}
		if stepErr != nil {
			return "", fmt.Errorf("read seller: %w", stepErr)
		}
		return a.DisplayName, nil
	})
	if err != nil {
		return fmt.Errorf("read the seller: %w", err)
	}
	var cursor uuid.UUID
	for {
		p, err := restate.Run(ctx, func(rc restate.RunContext) (page.Page[accountsvc.Follower], error) {
			return w.Accounts.Followers(rc, l.SellerID, page.Request{Cursor: cursor, Limit: w.FollowerPage})
		})
		if err != nil {
			return fmt.Errorf("read the followers: %w", err)
		}
		for _, f := range p.Items {
			restate.ServiceSend(ctx, w.ServiceName(), "TellFollower").Send(
				FollowerNotice{EventID: e.ID, Follower: f.AccountID, ListingID: l.ID, SellerName: name, At: e.OccurredAt},
				restate.WithIdempotencyKey(e.ID.String()+"/"+f.AccountID.String()))
		}
		if p.NextCursor == nil {
			return nil
		}
		cursor = *p.NextCursor
	}
}

// ListingRejected tells the seller processing refused a photo.
func (w Worker) ListingRejected(ctx restate.Context, e events.Event) error {
	_, err := w.listing(ctx, e, false)
	return err
}

// listing tells the seller of the event's listing and returns the listing
// it read, zero for an unknown one; ListingPublished and ListingRejected
// call it.
func (w Worker) listing(ctx restate.Context, e events.Event, live bool) (catalogsvc.Summary, error) {
	f, err := restate.Run(ctx, func(rc restate.RunContext) (catalogsvc.Summary, error) {
		l, _, stepErr := w.Catalog.Summary(rc, e.SubjectID)
		if stepErr != nil {
			return catalogsvc.Summary{}, fmt.Errorf("read listing: %w", stepErr)
		}
		return l, nil // zero for an unknown listing
	})
	if err != nil {
		return catalogsvc.Summary{}, fmt.Errorf("read the listing: %w", err)
	}
	if f.ID == (uuid.UUID{}) {
		return f, nil
	}
	return f, w.tell(ctx, e.ID, []domain.Notice{domain.ListingNotice(f.SellerID, f.ID, f.Title, live, e.OccurredAt)})
}

// TellFollower tells one follower of a listing that first went on sale,
// unless it is no longer on sale when this runs.
func (w Worker) TellFollower(ctx restate.Context, in FollowerNotice) error {
	l, err := restate.Run(ctx, func(rc restate.RunContext) (catalogsvc.Summary, error) {
		s, _, stepErr := w.Catalog.Summary(rc, in.ListingID)
		if stepErr != nil {
			return catalogsvc.Summary{}, fmt.Errorf("read listing: %w", stepErr)
		}
		return s, nil
	})
	if err != nil {
		return fmt.Errorf("read the listing: %w", err)
	}
	if l.Status != catalogdomain.StatusActive {
		return nil
	}
	return w.tell(ctx, in.EventID, []domain.Notice{
		domain.FollowedListing(in.Follower, l.SellerID, in.SellerName, l.ID, l.Title, in.At),
	})
}
```

Imports to add: `accountdomain "github.com/shopnexus/server/internal/account/domain"`, `catalogdomain "github.com/shopnexus/server/internal/catalog/domain"`, `github.com/shopnexus/server/internal/platform/page`. If the `//nolint:revive` comment is not needed, golangci-lint's `nolintlint` will say so; drop it then.

4. In `internal/notification/notification.go`, set the page size:

```go
// followerPage is how many followers one step of ListingPublished reads.
const followerPage = 500
```

and `FollowerPage: followerPage` in the `worker.Worker` literal. `TellFollower` is not subscribed to an event: `restate.Reflect(w)` registers it, and `ListingPublished` calls it.

Run: `go test ./internal/notification/... -count=1` → PASS.

- [ ] **Step 5: Add the e2e check**

Append to `e2e/follow_test.go`:

```go
// A follower hears when the seller first puts a listing on sale.
func TestFollowerHearsOfANewListing(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	follower, _ := newAccount(t)
	expectStatus(t, call(t, "POST", "/v1/follows", map[string]any{"account_id": seller.Account.ID}, bearer(follower.AccessToken)), http.StatusNoContent)
	l := activeListing(t, seller.AccessToken, nil)
	got := notices(t, follower.AccessToken, 1)
	if n := got.Items[0]; n.Type != "followed_listing" || n.Target.Kind != "listing" || n.Target.ID != l.ID || !n.Unread {
		t.Fatalf("%+v", n)
	}
}
```

Run: `make test` → PASS.

- [ ] **Step 6: Commit**

```bash
git add api/schemas/notification.yaml internal/notification e2e/follow_test.go
git commit -m "feat(notification): followers hear when a seller first puts a listing on sale"
```

---

### Task 8: Architecture notes and the checklist

**Files:**
- Modify: `~/shopnexus/server/ARCHITECTURE.md`
- Modify: `~/shopnexus/checklist.md` (umbrella repo)

Both are prose in files: use the `humanizing-writing` skill and run `python3 ~/.claude/skills/humanizing-writing/ai-tells.py --stats <file>` on each changed section and on each commit message (user's global rule).

- [ ] **Step 1: ARCHITECTURE.md**

- Rename `### Blocks` to `### Blocks and follows` and add, after its paragraph: follows live in `account` beside blocks; `POST /v1/follows`, `GET /v1/follows` (pages by the follow's UUIDv7, rows named as `Block`'s), `DELETE /v1/follows/{account_id}`; at most 1,000 per follower under `pg_advisory_xact_lock` on `'follows:' || follower`; a block deletes both follows in its transaction, and a follow and a block of the same two take one pair lock (`'pair:' || lo/hi`), so a follow written beside a block cannot outlive it; following is 403 `blocked` while a block stands, and unblocking restores nothing. Add the decision date 2026-11-10 and the spec path.
- In `### Screen`, the seller view bullet: `seller.followers` (public) and `viewer {blocked, following, conversation_id}`.
- In `### Trust`, add a reports bullet list: one `reports` table, `account_id` always set (the seller for a listing), `listing_id` optional; one open report per reporter and target through two partial unique indexes and `INSERT … ON CONFLICT`; a report again replaces reason and note and answers 200; a withdrawal keeps the row with `withdrawn_at`; a suspended account cannot report; a deleted listing is `listing_not_found`, a hidden, reserved, sold or rejected one can be reported; the console queue is not built yet.
- In `### Catalog` (the event bullet near line 744) and `### Notifications`: `listing.published` carries `first: true` on a listing's first publication; `ListingPublished` reads the seller's followers 500 per step and sends `TellFollower` per follower with the key `<event id>/<follower id>`; `TellFollower` re-reads the listing, tells no one when it is no longer active, and writes `followed_listing` collapsing on `seller:<id>`.
- Change "Reports, incident records and reputation will join `trust`" (module layout) to say reports are there now.

- [ ] **Step 2: Commit the server**

```bash
cd ~/shopnexus/server
git add ARCHITECTURE.md
git commit -m "docs: follows, reports and the notice of a followed seller's new listing"
```

- [ ] **Step 3: The checklist**

In `~/shopnexus/checklist.md`, section 1 "Mua & tìm kiếm", tick the three items and name the endpoints, as the search items do:

```markdown
- [x] Báo cáo tin đăng: `POST /v1/reports {listing_id, reason, note}`, rút lại bằng `DELETE /v1/reports/{id}` (app chưa nối)
- [x] Theo dõi người bán: `POST/GET /v1/follows`, `DELETE /v1/follows/{account_id}`, số người theo dõi và `viewer.following` trên trang người bán, báo khi người bán đăng tin mới (app chưa nối)
- [x] Báo cáo người bán: `POST /v1/reports {account_id, reason, note}` (app chưa nối)
```

Update "Cập nhật 10/11/2026" if the date changed.

- [ ] **Step 4: Commit the umbrella**

```bash
cd ~/shopnexus
git add checklist.md server docs
git commit -m "chore: submodules at follows and reports; the checklist ticks them"
```

Do not push any repo.

---

## Self-review notes

- Spec coverage: follows API (Task 2), block deletes follows (Task 1), seller view fields (Task 3), reports API and data (Tasks 4–5), `first` flag (Task 6), fan-out, collapse and push (Task 7), docs and checklist (Task 8).
- The spec's `Follow` uses `at`, matching `Block`; the note is trimmed, matching a review's text.
- Names used across tasks: `accountsvc.Follower`, `accountsvc.FollowView`, `Worker.FollowerPage`, `worker.FollowerNotice`, `domain.FollowedListing`, `trustsvc.ReportInput`, `trustsvc.ReportView`.
