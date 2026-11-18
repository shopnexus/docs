# Account Erasure, Feedback and Search History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give server account deletion (`DELETE /v1/accounts/me`), feedback (`POST /v1/feedback`, `GET /v1/console/feedback`) and a search history (`GET`/`DELETE /v1/search/history`, `DELETE /v1/search/history/{id}`), so three rows of `~/shopnexus/checklist.md` have a server.

**Architecture:** Account deletion leaves a tombstone `accounts` row (`status = 'deleted'`) and writes `account.deleted`; a new module `erasure`, mounted after `deal`, refuses the deletion while an order is open. Catalog, deal, discovery and notification each clear their own rows from a worker on `account.deleted`; deal schedules a Restate call that blanks the buyer's recipient fields 365 days later. Feedback is a new module `support`; console's handler serves the console list through `supportsvc.Service`. Search history lives in `discovery`, written by `Search` itself.

**Tech Stack:** Go (stdlib `uuid`, `net/http` ServeMux), pgx v5, Postgres 18 (ParadeDB image), Restate Go SDK, kin-openapi request validation, `golang.org/x/text` (diacritic folding), `make test` (tests + golangci-lint).

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-10-server-account-erasure-feedback-search-history-design.md`. Its section "Revisions made while planning" wins over the sections after it. Read it and `~/shopnexus/server/ARCHITECTURE.md` (sections Use cases, HTTP handlers, Events, Module layout, Tables and aggregates, Session use cases, Discovery, Testing) before Task 1.

## Global Constraints

- Work in `~/shopnexus/server` on `main` (the user's workflow; no branch was asked for). Commit after each task; do not push.
- No `Co-Authored-By` trailer on any commit (user's rule for the shopnexus repos). Commit messages are conventional (`feat(account): …`), one line, plain facts.
- A use case, Restate handler or HTTP handler reads top to bottom; no helper called from one place (server `CLAUDE.md`). A helper called from several places is fine.
- The OpenAPI spec in `api/` changes first in each task that adds or changes an endpoint. `TestRoutesMatchSpec` (`internal/app/routes_test.go`) and the e2e coverage check (`e2e/main_test.go`, `uncovered`) require every route in the spec and every documented status observed by an e2e call.
- A business rule broken is 422 (`apperr.KindInvalid`); the schema does not constrain what a rule checks (feedback length), so the validator does not turn it into 400.
- Migration: `migrations/0028_erasure_feedback_history.sql`. If `0028_*` exists when you start, take the next free number; if `0027_*` does not exist yet, still use 0028 (the email sign-in plan holds 0027).
- Numbers: re-authentication window 15 minutes (`accountdomain.RecentAuth`); feedback 1 to 1000 characters after `strings.TrimSpace`, 10 per account per 24 hours; history 10 entries per account, query 1 to 200 characters; recipients blanked 365 days after the deletion (`dealdomain.KeepRecipientsFor`).
- Error codes, exactly: `orders_open` (409), `account_deleted` (409), `invalid_feedback` (422), `feedback_limit_reached` (429). Existing: `reauth_required` (428), `account_suspended` (403), `session_revoked` (401), `try_again` (409).
- Event kind `account.deleted` (`events.AccountDeleted`).
- After adding a module or a layer, run `make depguard` and commit the rewritten `.golangci.yml`.
- Scratch output goes in `tmp/`, never `/tmp`.
- `make test` starts the test stack once; afterwards `go test ./internal/<module>/...` and `go test ./e2e/ -run <Name>` run alone. Finish every task with `make test` green.

## Review Focus

1. A COD request that lands between erasure's open-order check and the account's deletion: the order must end cancelled, not stay requested with a deleted seller. Task 3 tests `AccountDeleted` on a deal with a requested order.
2. A deleted person's access token, still valid for up to 15 minutes, used to post a listing, send a message or send feedback: 401 `session_revoked`, not success. Task 2 tests `Status` and the domain refusal; Task 8's e2e calls a write with the token after deletion.
3. A listing still `processing` when its seller is deleted: it must end `deleted`, not publish later. Task 5 tests `SellerLeft` with a processing listing.
4. `account.deleted` delivered twice to each worker: the second delivery changes nothing and fails nothing. Tasks 3, 5 and 6 run each handler twice.
5. Searching the same words with different case, spacing or marks ("Xe Đạp", "xe  dap"): one history entry, moved to the top, and never more than 10. Task 6 tests the fold and the cap.

---

### Task 1: Migration and the account tombstone

**Files:**
- Create: `migrations/0028_erasure_feedback_history.sql`
- Modify: `internal/account/domain/account.go`
- Modify: `internal/account/domain/errors.go`
- Modify: `internal/account/repository/account.go` (interface `Accounts`)
- Modify: `internal/account/repository/account_pg.go`
- Test: `internal/account/domain/account_test.go`, `internal/account/repository/account_pg_test.go`

**Interfaces:**
- Produces (domain): `StatusDeleted Status = "deleted"`; `RecentAuth = 15 * time.Minute`; `(*Account).Delete(now time.Time) (bool, error)`; `(*Account).DeletedAt() *time.Time`; `RestoreAccount(..., lastActiveAt *time.Time, deletedAt *time.Time)` (one parameter more, last); `(*Account).CanWrite(now)` returns `ErrSessionRevoked` for a deleted account; `ErrAccountDeleted` (`account_deleted`, 409); `Status.Refusal() *apperr.Error`.
- Produces (repository): `Erase(ctx context.Context, a *domain.Account, writeID uuid.UUID, evs ...events.Event) error`.
- Produces (schema): `accounts.deleted_at`, tables `feedback` and `search_history` (Tasks 6 and 7 use them).

- [ ] **Step 1: Write the migration**

`migrations/0028_erasure_feedback_history.sql`:

```sql
-- Account erasure: a deleted account keeps its row, without a name, bio or
-- avatar, for the orders, reviews and messages that point to it.
ALTER TABLE accounts DROP CONSTRAINT accounts_status_check;
ALTER TABLE accounts ADD CONSTRAINT accounts_status_check
CHECK (status IN ('active', 'suspended', 'deleted'));
ALTER TABLE accounts ADD COLUMN deleted_at timestamptz;
ALTER TABLE accounts ADD CONSTRAINT accounts_deleted CHECK (
    (status = 'deleted') = (deleted_at IS NOT NULL)
    AND (status <> 'deleted' OR (display_name IS NULL AND bio IS NULL AND avatar_key IS NULL))
);

-- Feedback a person sends from Trợ giúp. request_key is the client's
-- Idempotency-Key, so a repeated tap adds nothing. At most 10 per account
-- in 24 hours.
CREATE TABLE feedback (
    id          uuid PRIMARY KEY,
    account_id  uuid NOT NULL REFERENCES accounts (id),
    body        text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 1000),
    request_key uuid NOT NULL,
    created_at  timestamptz NOT NULL,
    UNIQUE (account_id, request_key)
);
CREATE INDEX feedback_account_created ON feedback (account_id, created_at);

-- A person's last 10 text searches. query_key folds case, spaces and
-- Vietnamese marks, so the same words are one entry; a new search of them
-- takes a new id and moves the entry to the top.
CREATE TABLE search_history (
    id          uuid PRIMARY KEY,
    account_id  uuid NOT NULL REFERENCES accounts (id),
    query_key   text NOT NULL,
    query       text NOT NULL CHECK (char_length(query) BETWEEN 1 AND 200),
    category    text,
    photo_url   text,
    searched_at timestamptz NOT NULL,
    UNIQUE (account_id, query_key)
);
CREATE INDEX search_history_account ON search_history (account_id, id);
```

Run `sqlfluff lint migrations/0028_erasure_feedback_history.sql` if sqlfluff is installed; `make test` runs it otherwise. `category` is not a keyword; `query` is not either in Postgres, but if sqlfluff RF04 flags it, rename the column `query_text` here and in Task 6.

- [ ] **Step 2: Write the failing domain tests**

Append to `internal/account/domain/account_test.go` (create the file with `package domain_test` and imports `errors`, `testing`, `time`, `uuid`, `github.com/shopnexus/server/internal/account/domain` if it does not exist):

```go
func TestDeleteClearsTheProfile(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, 11, 10, 9, 0, 0, 0, time.UTC)
	a, err := domain.New(uuid.NewV7(), "Linh", now)
	if err != nil {
		t.Fatal(err)
	}
	bio := "Bán đồ cũ"
	if err = a.Edit(nil, &bio, now); err != nil {
		t.Fatal(err)
	}
	a.SetAvatar("avatars/a.jpg", now)
	changed, err := a.Delete(now)
	if err != nil || !changed {
		t.Fatalf("delete: %v %v", changed, err)
	}
	if a.Status(now) != domain.StatusDeleted || a.DisplayName() != "" || a.Bio() != "" || a.AvatarKey() != "" ||
		a.DeletedAt() == nil || !a.DeletedAt().Equal(now) {
		t.Fatalf("after delete: %+v", a)
	}
	if changed, err = a.Delete(now.Add(time.Hour)); err != nil || changed {
		t.Fatalf("delete again: %v %v", changed, err)
	}
	if err = a.CanWrite(now); !errors.Is(err, domain.ErrSessionRevoked) {
		t.Fatalf("a deleted account writes: %v", err)
	}
}

func TestDeleteRefusesASuspension(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, 11, 10, 9, 0, 0, 0, time.UTC)
	a, _ := domain.New(uuid.NewV7(), "Linh", now)
	if err := a.Suspend("spam", nil, now); err != nil {
		t.Fatal(err)
	}
	if _, err := a.Delete(now); !errors.Is(err, domain.ErrSuspended) {
		t.Fatalf("delete while suspended: %v", err)
	}
	until := now.Add(time.Hour)
	b, _ := domain.New(uuid.NewV7(), "Lan", now)
	if err := b.Suspend("spam", &until, now); err != nil {
		t.Fatal(err)
	}
	if changed, err := b.Delete(until); err != nil || !changed {
		t.Fatalf("delete after the suspension lapsed: %v %v", changed, err)
	}
}

func TestStatusRefusal(t *testing.T) {
	t.Parallel()
	if domain.StatusActive.Refusal() != nil {
		t.Fatal("active refuses")
	}
	if !errors.Is(domain.StatusSuspended.Refusal(), domain.ErrSuspended) {
		t.Fatal("suspended")
	}
	if !errors.Is(domain.StatusDeleted.Refusal(), domain.ErrSessionRevoked) {
		t.Fatal("deleted")
	}
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `go test ./internal/account/domain/ -run 'TestDelete|TestStatusRefusal'`
Expected: build failure, `a.Delete undefined`.

- [ ] **Step 4: Implement the domain**

In `internal/account/domain/account.go`:

```go
const (
	StatusActive    Status = "active"
	StatusSuspended Status = "suspended"
	// StatusDeleted is an account its person deleted: the row stays, without
	// a name, bio or avatar, for the orders and messages that point to it.
	StatusDeleted Status = "deleted"
)

// RecentAuth is how long after a sign-in the sensitive actions stay open:
// signing out everywhere and deleting the account.
const RecentAuth = 15 * time.Minute
```

Add `deletedAt *time.Time` to the `Account` struct after `lastActiveAt`, a last parameter `deletedAt *time.Time` to `RestoreAccount` that sets it, and:

```go
func (a *Account) DeletedAt() *time.Time { return a.deletedAt }

// Refusal is the error a write by an account in this status answers: nil
// while active, ErrSuspended while suspended, and ErrSessionRevoked once
// deleted, since a deleted account's sessions are revoked and only an
// access token that has not expired yet can still call.
func (s Status) Refusal() *apperr.Error {
	switch s {
	case StatusSuspended:
		return ErrSuspended
	case StatusDeleted:
		return ErrSessionRevoked
	default:
		return nil
	}
}

// Delete ends the account: its name, bio and avatar go and it writes no
// more. A suspension in force refuses it, so deleting cannot shed one.
// Deleting a deleted account changes nothing and reports false.
func (a *Account) Delete(now time.Time) (bool, error) {
	if a.status == StatusDeleted {
		return false, nil
	}
	if a.Suspended(now) {
		return false, ErrSuspended
	}
	a.status, a.deletedAt, a.updatedAt = StatusDeleted, &now, now
	a.displayName, a.bio, a.avatarKey = "", "", ""
	a.suspendReason, a.suspendedUntil = "", nil
	return true, nil
}
```

Replace `CanWrite`'s body:

```go
func (a *Account) CanWrite(now time.Time) error {
	if r := a.Status(now).Refusal(); r != nil {
		return r
	}
	return nil
}
```

Import `github.com/shopnexus/server/internal/platform/apperr` in `account.go` (the domain may import platform packages; `errors.go` already does). In `Suspend`, refuse a deleted account first: `if a.status == StatusDeleted { return ErrAccountNotFound }` (console suspends through a 404-documented route). In `errors.go`, beside `ErrSuspended`:

```go
	ErrAccountDeleted  = apperr.New(apperr.KindConflict, "account_deleted", "the other account was deleted")
```

In `internal/account/service/session_delete.go`, delete the `recentAuth` constant and use `domain.RecentAuth`.

Update every call of `RestoreAccount` (`grep -rn RestoreAccount internal`) to pass the new last argument; tests pass `nil`.

- [ ] **Step 5: Run the domain tests**

Run: `go test ./internal/account/domain/`
Expected: PASS.

- [ ] **Step 6: Write the failing repository test**

Append to `internal/account/repository/account_pg_test.go` (it has `now`, `newStore`, `seed`; add imports `github.com/jackc/pgx/v5`, `github.com/jackc/pgx/v5/pgxpool`, `github.com/shopnexus/server/internal/platform/events`, `github.com/shopnexus/server/internal/platform/postgres/pgtest` if missing):

```go
// count is how many rows q finds.
func count(t *testing.T, db *pgxpool.Pool, q string, id uuid.UUID) int {
	t.Helper()
	var n int
	if err := db.QueryRow(context.Background(), q, pgx.StrictNamedArgs{"id": id}).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

func TestErase(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewAccounts(db)
	me, other := seed(t, s), seed(t, s)
	for _, q := range []string{
		`INSERT INTO credentials (account_id, write_id) VALUES (@id, @id)`,
		`INSERT INTO identities (id, account_id, kind, identifier) VALUES (uuidv7(), @id, 'phone', '+84990000' || substr(@id::text, 1, 4))`,
		`INSERT INTO addresses (id, account_id, recipient_name, phone, street, commune_code, is_default, request_key, write_id, created_at)
VALUES (uuidv7(), @id, 'Linh', '0912345678', '1 Lê Lợi', (SELECT code FROM communes ORDER BY code LIMIT 1), true, uuidv7(), uuidv7(), now())`,
		`INSERT INTO sessions (id, account_id, refresh_hash, auth_time, created_at, last_used_at, expires_at, write_id)
VALUES (uuidv7(), @id, gen_random_bytes(32), now(), now(), now(), now() + interval '30 days', uuidv7())`,
	} {
		if _, err := db.Exec(ctx, q, pgx.StrictNamedArgs{"id": me}); err != nil {
			t.Fatalf("%s: %v", q, err)
		}
	}
	if err := s.Block(ctx, uuid.NewV7(), other, me, now); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(ctx, `INSERT INTO account_follows (id, follower_id, followed_id, created_at) VALUES (uuidv7(), @id, @other, now())`,
		pgx.StrictNamedArgs{"id": me, "other": other}); err != nil {
		t.Fatal(err)
	}

	a, err := s.Get(ctx, me)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = a.Delete(now); err != nil {
		t.Fatal(err)
	}
	ev := events.Event{ID: uuid.NewV7(), Kind: events.AccountDeleted, SubjectID: me, OccurredAt: now}
	if err = s.Erase(ctx, &a, uuid.NewV7(), ev); err != nil {
		t.Fatal(err)
	}
	got, err := s.Get(ctx, me)
	if err != nil || got.StoredStatus() != domain.StatusDeleted || got.DeletedAt() == nil || got.DisplayName() != "" {
		t.Fatalf("stored: %+v %v", got, err)
	}
	for q, want := range map[string]int{
		`SELECT count(*) FROM credentials WHERE account_id = @id`:                               0,
		`SELECT count(*) FROM identities WHERE account_id = @id`:                                0,
		`SELECT count(*) FROM addresses WHERE account_id = @id`:                                 0,
		`SELECT count(*) FROM account_blocks WHERE blocker_id = @id OR blocked_id = @id`:        0,
		`SELECT count(*) FROM account_follows WHERE follower_id = @id OR followed_id = @id`:     0,
		`SELECT count(*) FROM sessions WHERE account_id = @id AND revoked_at IS NULL`:           0,
		`SELECT count(*) FROM events WHERE subject_id = @id AND kind = 'account.deleted'`:       1,
	} {
		if n := count(t, db, q, me); n != want {
			t.Errorf("%s: %d, want %d", q, n, want)
		}
	}

	stale := got
	stale.Saved(uuid.NewV7())
	if err = s.Erase(ctx, &stale, uuid.NewV7()); !errors.Is(err, repository.ErrConflict) {
		t.Fatalf("a stale erase: %v", err)
	}
}
```

If `gen_random_bytes` is missing (pgcrypto not installed), use `decode(md5(random()::text), 'hex')`. If the events table names its column `event_kind` or similar, read `migrations/0004_events.sql` and use its name.

- [ ] **Step 7: Run it to see it fail**

Run: `go test ./internal/account/repository/ -run TestErase`
Expected: build failure, `s.Erase undefined` (or `events.AccountDeleted undefined`).

- [ ] **Step 8: Implement Erase**

In `internal/platform/events/events.go`, after `AccountUnsuspended`:

```go
	// AccountDeleted is an account its person deleted; each module clears
	// what it keeps of the account.
	AccountDeleted Kind = "account.deleted"
```

In `internal/account/repository/account.go`, add to `Accounts`:

```go
	// Erase saves a deleted account as Save does and, in the same
	// transaction, deletes its credentials with their identities, its
	// addresses, the blocks and follows either way, and revokes its
	// sessions, then writes evs. A stale write is ErrConflict and writes
	// none of it.
	Erase(ctx context.Context, a *domain.Account, writeID uuid.UUID, evs ...events.Event) error
```

In `internal/account/repository/account_pg.go`:

1. `accountColumns` gains `, deleted_at` at the end; `scanAccount` scans it into `deletedAt *time.Time` and passes it to `RestoreAccount`.
2. `saveAccount` sets `deleted_at = @deleted_at` too, and `Save` passes `"deleted_at": a.DeletedAt()`.
3. Add:

```go
// eraseAccount is what Erase deletes beside the row, in order; identities
// go with their credentials (ON DELETE CASCADE).
var eraseAccount = []string{
	`DELETE FROM credentials WHERE account_id = @id`,
	`DELETE FROM addresses WHERE account_id = @id`,
	`DELETE FROM account_blocks WHERE blocker_id = @id OR blocked_id = @id`,
	`DELETE FROM account_follows WHERE follower_id = @id OR followed_id = @id`,
}

func (s pgAccounts) Erase(ctx context.Context, a *domain.Account, writeID uuid.UUID, evs ...events.Event) error {
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, saveAccount, pgx.StrictNamedArgs{
			"id": a.ID(), "read_write_id": a.WriteID(), "write_id": writeID,
			"display_name": a.DisplayName(), "bio": a.Bio(), "avatar_key": a.AvatarKey(), "status": a.StoredStatus(),
			"suspended_until": a.SuspendedUntil(), "suspend_reason": a.SuspendReason(), "updated_at": a.UpdatedAt(),
			"deleted_at": a.DeletedAt(),
		})
		if err != nil {
			return fmt.Errorf("update account: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return ErrConflict
		}
		for _, q := range eraseAccount {
			if _, err = tx.Exec(ctx, q, pgx.StrictNamedArgs{"id": a.ID()}); err != nil {
				return fmt.Errorf("erase: %w", err)
			}
		}
		if _, err = tx.Exec(ctx, `UPDATE sessions SET revoked_at = @now, write_id = uuidv7()
WHERE account_id = @id AND revoked_at IS NULL`, pgx.StrictNamedArgs{"id": a.ID(), "now": a.UpdatedAt()}); err != nil {
			return fmt.Errorf("revoke sessions: %w", err)
		}
		return events.Insert(ctx, tx, evs...)
	})
	if err != nil {
		return fmt.Errorf("erase account: %w", err)
	}
	a.Saved(writeID)
	return nil
}
```

Any test double of `repository.Accounts` (`grep -rn "repository.Accounts" internal --include='*_test.go'`) that does not embed the interface gains an `Erase` method.

- [ ] **Step 9: Run the account tests**

Run: `go test ./internal/account/...`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add migrations/0028_erasure_feedback_history.sql internal/account internal/platform/events/events.go
git commit -m "feat(account): a deleted account keeps a tombstone row; tables for feedback and search history"
```

---

### Task 2: `Status` replaces `Suspended`; the `Erase` use case

**Files:**
- Modify: `internal/account/service/service.go` (interface), `internal/account/service/account_get.go`
- Create: `internal/account/service/account_erase.go`
- Modify: `internal/account/service/follow.go`
- Modify: `internal/catalog/service/listing_post_durable.go`, `internal/catalog/service/listing_edit_durable.go`
- Modify: `internal/deal/service/deal_open.go`, `internal/deal/service/deal_move.go`
- Modify: `internal/chat/service/message_send_durable.go`
- Modify: `internal/trust/service/review.go`, `internal/trust/service/report.go`
- Modify: `internal/app/socket_access.go`
- Modify: `api/schemas/account.yaml` (`Account.status`), `api/schemas/console.yaml` (the console account's `status`), `api/paths/account.yaml` (follow's 409 description)
- Test: `internal/account/service/account_erase_test.go`, `internal/account/service/follow_test.go` (or the file holding the follow tests)

**Interfaces:**
- Consumes: Task 1's `Delete`, `Erase`, `Refusal`, `ErrAccountDeleted`, `events.AccountDeleted`.
- Produces: `accountsvc.Service.Status(ctx context.Context, id uuid.UUID) (domain.Status, error)` (the status in force now; `Suspended` is gone); `accountsvc.Service.Erase(ctx context.Context, id uuid.UUID) error`.

- [ ] **Step 1: Write the failing service tests**

`internal/account/service/account_erase_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"testing"

	"github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/account/repository"
	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
)

func TestErase(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	accounts := repository.NewAccounts(db)
	svc := at(accounts, nil, now)
	id := seed(t, accounts)

	if err := svc.Erase(ctx, id); err != nil {
		t.Fatal(err)
	}
	st, err := svc.Status(ctx, id)
	if err != nil || st != domain.StatusDeleted {
		t.Fatalf("status: %s %v", st, err)
	}
	if err = svc.Erase(ctx, id); err != nil {
		t.Fatalf("erase again: %v", err)
	}
	if kinds := pgtest.EventKinds(t, db, id); len(kinds) != 1 || kinds[0] != "account.deleted" {
		t.Fatalf("events: %v", kinds)
	}
	v, err := svc.Get(ctx, id)
	if err != nil || v.Status != domain.StatusDeleted || v.DisplayName != "" {
		t.Fatalf("view: %+v %v", v, err)
	}
}

func TestEraseRefusesASuspension(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	accounts := repository.NewAccounts(db)
	id := seed(t, accounts)
	suspendAccount(t, db, id)
	if err := at(accounts, nil, now).Erase(context.Background(), id); !errors.Is(err, domain.ErrSuspended) {
		t.Fatalf("erase while suspended: %v", err)
	}
}

// conflictOnce is an account store whose first Erase loses a race.
type conflictOnce struct {
	repository.Accounts

	failed *bool
}

func (c conflictOnce) Erase(ctx context.Context, a *domain.Account, writeID uuid.UUID, evs ...events.Event) error {
	if !*c.failed {
		*c.failed = true
		return repository.ErrConflict
	}
	return c.Accounts.Erase(ctx, a, writeID, evs...)
}

func TestEraseRetriesAConflictOnce(t *testing.T) {
	t.Parallel()
	accounts := repository.NewAccounts(pgtest.New(t))
	id := seed(t, accounts)
	failed := false
	if err := at(conflictOnce{Accounts: accounts, failed: &failed}, nil, now).Erase(context.Background(), id); err != nil {
		t.Fatalf("erase after one conflict: %v", err)
	}
	always := alwaysConflict{Accounts: accounts}
	other := seed(t, accounts)
	if err := at(always, nil, now).Erase(context.Background(), other); !errors.Is(err, apperr.ErrTryAgain) {
		t.Fatalf("erase after two conflicts: %v", err)
	}
}

// alwaysConflict is an account store whose every Erase loses a race.
type alwaysConflict struct{ repository.Accounts }

func (alwaysConflict) Erase(context.Context, *domain.Account, uuid.UUID, ...events.Event) error {
	return repository.ErrConflict
}
```

Add imports `uuid` and `github.com/shopnexus/server/internal/platform/events`. If `pgtest.EventKinds` takes other arguments, read `internal/platform/postgres/pgtest` and follow its signature.

In the follow tests (find them with `grep -ln "func TestFollow" internal/account/service`), add:

```go
func TestFollowADeletedAccount(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	accounts := repository.NewAccounts(db)
	svc := service.New(service.Deps{Accounts: accounts, Follows: repository.NewFollows(db), Now: func() time.Time { return now }, Log: discard})
	me, gone := seed(t, accounts), seed(t, accounts)
	if err := svc.Erase(context.Background(), gone); err != nil {
		t.Fatal(err)
	}
	if err := svc.Follow(context.Background(), me, gone); !errors.Is(err, domain.ErrAccountDeleted) {
		t.Fatalf("follow a deleted account: %v", err)
	}
	if err := svc.Follow(context.Background(), gone, me); !errors.Is(err, domain.ErrSessionRevoked) {
		t.Fatalf("a deleted account follows: %v", err)
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/account/service/ -run 'TestErase|TestFollowADeleted'`
Expected: build failure, `svc.Erase undefined`.

- [ ] **Step 3: Implement Status and Erase**

In `internal/account/service/service.go`, replace the `Suspended` entry of `Service` with:

```go
	// Status is the account's status in force now: active, suspended (a
	// suspension that has not lapsed) or deleted. A module that refuses a
	// write answers status.Refusal(); a Restate step returns the status, so
	// the flow can return the refusal as data.
	Status(ctx context.Context, id uuid.UUID) (domain.Status, error)
	// Erase deletes the account: the row stays without a name, bio or
	// avatar, its credentials, addresses, blocks and follows go, its
	// sessions are revoked and account.deleted is written. A suspension in
	// force is domain.ErrSuspended; a deleted account changes nothing.
	Erase(ctx context.Context, id uuid.UUID) error
```

In `internal/account/service/account_get.go`, replace `Suspended` with:

```go
func (s *Account) Status(ctx context.Context, id uuid.UUID) (domain.Status, error) {
	a, err := s.load(ctx, id)
	if err != nil {
		return "", err
	}
	return a.Status(s.now()), nil
}
```

`internal/account/service/account_erase.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"uuid"

	"github.com/shopnexus/server/internal/account/repository"
	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/platform/events"
)

// Erase deletes the account in one transaction with what goes with it,
// reading it again once when another write won the race.
func (s *Account) Erase(ctx context.Context, id uuid.UUID) error {
	for range 2 {
		now := s.now()
		a, err := s.load(ctx, id)
		if err != nil {
			return err
		}
		changed, err := a.Delete(now)
		if err != nil || !changed {
			return err
		}
		err = s.accounts.Erase(ctx, &a, uuid.NewV7(), events.Event{
			ID: uuid.NewV7(), Kind: events.AccountDeleted, SubjectID: id, OccurredAt: now,
		})
		if errors.Is(err, repository.ErrConflict) {
			continue
		}
		if err != nil {
			return fmt.Errorf("erase account: %w", err)
		}
		return nil
	}
	return apperr.ErrTryAgain
}
```

In `internal/account/service/follow.go`, replace the suspension check and the load of `followed`:

```go
	status, err := s.Status(ctx, follower)
	if err != nil {
		return err
	}
	if r := status.Refusal(); r != nil {
		return r
	}
	other, err := s.load(ctx, followed)
	if err != nil {
		return err
	}
	if other.StoredStatus() == domain.StatusDeleted {
		return domain.ErrAccountDeleted
	}
```

- [ ] **Step 4: Move every caller to Status**

Each caller of `Suspended` reads the status and returns its refusal. In a direct use case (`deal_open.go`, `deal_move.go`, `trust/service/review.go`, `trust/service/report.go`), replace

```go
	suspended, err := s.accounts.Suspended(ctx, buyer)
	if err != nil { ... }
	if suspended {
		return ..., accountdomain.ErrSuspended
	}
```

with

```go
	status, err := s.accounts.Status(ctx, buyer)
	if err != nil { ... }
	if r := status.Refusal(); r != nil {
		return ..., r
	}
```

keeping each file's own variable names, error wrapping and zero values. In `deal_move.go` the read sits inside a closure that sets `readErr`; keep that shape and return `r` where it returned `accountdomain.ErrSuspended`.

In the Restate flows (`listing_post_durable.go`, `listing_edit_durable.go`), the step returns the status:

```go
	status, err := restate.Run(ctx, func(rc restate.RunContext) (accountdomain.Status, error) {
		return s.Accounts.Status(rc, in.Seller)
	})
	if err != nil {
		return PostResult{}, fmt.Errorf("read account status: %w", err)
	}
	if r := status.Refusal(); r != nil {
		return PostResult{Refused: r}, nil
	}
```

In `message_send_durable.go`, `facts.Suspended bool` becomes `Status accountdomain.Status \`json:"status"\``, the step sets `out.Status, stepErr = s.Chat.accounts.Status(rc, in.Sender)`, and the first case of the refusal switch becomes `case f.Status.Refusal() != nil: refused = f.Status.Refusal()`. (Task 8 adds the other person's status to the same step.)

In `internal/app/socket_access.go`, `Suspended` keeps its name (it implements `stream.Access`) and becomes:

```go
func (a socketAccess) Suspended(ctx context.Context, account uuid.UUID) (bool, error) {
	status, err := a.accounts.Status(ctx, account)
	if err != nil {
		return false, fmt.Errorf("check status: %w", err)
	}
	return status != accountdomain.StatusActive, nil
}
```

with its doc comment saying that a suspended or deleted account loses the socket. Import `accountdomain "github.com/shopnexus/server/internal/account/domain"`.

Then `grep -rn "Suspended(" internal --include='*.go'` and fix every remaining call or test double of `accountsvc.Service.Suspended` (doubles in `*_test.go` and `accounttest`) to implement `Status` instead. `go build ./... && go vet ./...` must pass.

- [ ] **Step 5: Update the spec**

`api/schemas/account.yaml`, `Account.status`:

```yaml
    status:
      type: string
      enum: [active, suspended, deleted]
      description: deleted is an account its person deleted; its name and bio are empty and it has no avatar.
```

`api/schemas/console.yaml`: the console account schema's `status` enum gains `deleted` the same way. `api/paths/account.yaml`: the follow operation's 409 description (`PUT /v1/follows/{account_id}`, find it by `operationId`) adds `the account was deleted (account_deleted)`.

- [ ] **Step 6: Run the tests**

Run: `go test ./internal/... ./api/... && go test ./e2e/ -run 'TestFollow|TestConsoleAccounts'`, then `make test`
Expected: PASS. Follow's 409 is observed already by its limit test; Task 8 adds the `account_deleted` call.

- [ ] **Step 7: Commit**

```bash
git add internal api
git commit -m "feat(account): Status replaces Suspended, and Erase deletes an account to its tombstone"
```

---

### Task 3: Deal on a deleted account

**Files:**
- Modify: `internal/deal/domain/deal.go`, `internal/deal/domain/errors.go`
- Create: `internal/deal/domain/erasure.go`
- Modify: `internal/deal/repository/repository.go`, `internal/deal/repository/deal_pg.go`
- Create: `internal/deal/service/account_deleted.go`
- Modify: `internal/deal/service/service.go` (interface)
- Create: `internal/deal/worker/account.go`
- Modify: `internal/deal/deal.go`
- Test: `internal/deal/domain/deal_test.go`, `internal/deal/repository/deal_pg_test.go`, `internal/deal/service/account_deleted_test.go`, `internal/deal/worker/account_test.go`

**Interfaces:**
- Consumes: `events.AccountDeleted`.
- Produces (domain): `(*Deal).PartyLeft(now time.Time) bool`; `KeepRecipientsFor = 365 * 24 * time.Hour`; `ErrOrdersOpen` (`orders_open`, 409).
- Produces (repository): `OpenOrders(ctx, account uuid.UUID) (bool, error)`, `ActiveOf(ctx, account uuid.UUID) ([]domain.Deal, error)`, `ScrubRecipients(ctx, buyer uuid.UUID) error`.
- Produces (service): `OpenOrders(ctx context.Context, account uuid.UUID) (bool, error)`, `AccountDeleted(ctx context.Context, account uuid.UUID) error`, `ScrubRecipients(ctx context.Context, buyer uuid.UUID) error`.
- Produces (worker): `worker.AccountWatch{Prefix string; Deals service.Service}` with handlers `Deleted(restate.Context, events.Event) error` and `Scrub(restate.Context, uuid.UUID) error`; service name `<prefix>DealAccountWatch`.

- [ ] **Step 1: Write the failing domain test**

Append to `internal/deal/domain/deal_test.go`, building deals the way the file's existing tests do (read its helpers first; it builds a negotiating deal, an agreed one and one with a requested order). The test names the three cases:

```go
func TestPartyLeft(t *testing.T) {
	t.Parallel()
	at := time.Date(2026, 11, 10, 9, 0, 0, 0, time.UTC)

	requested := requestedDeal(t) // the file's helper for an agreed deal with a requested order
	if !requested.PartyLeft(at) || requested.Order().Status != domain.OrderCancelled ||
		requested.Order().CancelledBy != domain.System || requested.Order().CancelReason != domain.CancelListingClosed ||
		requested.Status() != domain.StatusNegotiating {
		t.Fatalf("requested: %+v", requested.State())
	}

	agreed := agreedDeal(t)
	if !agreed.PartyLeft(at) || agreed.Status() != domain.StatusNegotiating || agreed.AgreedPrice() != 0 {
		t.Fatalf("agreed: %+v", agreed.State())
	}

	offered := offeredDeal(t) // negotiating with an open price
	if !offered.PartyLeft(at) || offered.OpenPrice() != nil {
		t.Fatalf("offered: %+v", offered.State())
	}
	if offered.PartyLeft(at) {
		t.Fatal("a second PartyLeft changed the deal")
	}

	shipped := shippedDeal(t)
	if shipped.PartyLeft(at) {
		t.Fatal("PartyLeft touched a shipped order")
	}
}
```

If the file has no helper of a name above, write it beside the test from the steps its existing tests use (`domain.Open…`, `Offer`, `Accept`, `RequestCod`, `Ship`), each a function taking `t *testing.T` and returning `domain.Deal`.

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/deal/domain/ -run TestPartyLeft`
Expected: build failure, `PartyLeft undefined`.

- [ ] **Step 3: Implement PartyLeft**

`internal/deal/domain/erasure.go`:

```go
package domain

import "time"

// KeepRecipientsFor is how long after an account's deletion its orders
// keep the recipient's name, phone and street.
const KeepRecipientsFor = 365 * 24 * time.Hour

// PartyLeft ends what a deleted account leaves open on the deal, by the
// system: a requested order is cancelled, an agreement dropped, an open
// price taken back. A shipped order stays; erasure refuses a deletion
// while one exists. It reports whether the deal changed.
func (d *Deal) PartyLeft(now time.Time) bool {
	if o := d.openOrder(); o != nil {
		if o.Status != OrderRequested {
			return false
		}
		d.cancelOrder(System, CancelListingClosed, now)
		return true
	}
	switch {
	case d.status == StatusAgreed:
		d.reopen()
	case d.open != nil:
		d.open = nil
	default:
		return false
	}
	d.record(MoveListingClosed, System, 0, now)
	return true
}
```

In `internal/deal/domain/errors.go`:

```go
	ErrOrdersOpen = apperr.New(apperr.KindConflict, "orders_open", "an order of the account is requested or shipped")
```

- [ ] **Step 4: Run the domain tests**

Run: `go test ./internal/deal/domain/`
Expected: PASS.

- [ ] **Step 5: Write the failing repository test**

Append to `internal/deal/repository/deal_pg_test.go`, using the file's own way of putting a deal with a requested order in the database (read it; `deal_pg_test.go` inserts deals with `Insert` and orders with `Save`):

```go
func TestOpenOrdersActiveOfAndScrub(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewDeals(db)
	d := savedRequested(t, db, s) // a deal with a requested order, from the file's helpers

	open, err := s.OpenOrders(ctx, d.BuyerID())
	if err != nil || !open {
		t.Fatalf("buyer's open orders: %v %v", open, err)
	}
	if open, _ = s.OpenOrders(ctx, d.SellerID()); !open {
		t.Fatal("seller's open orders")
	}
	if open, _ = s.OpenOrders(ctx, uuid.NewV7()); open {
		t.Fatal("a stranger has open orders")
	}
	active, err := s.ActiveOf(ctx, d.BuyerID())
	if err != nil || len(active) != 1 || active[0].ID() != d.ID() {
		t.Fatalf("active: %v %v", active, err)
	}
	if err = s.ScrubRecipients(ctx, d.BuyerID()); err != nil {
		t.Fatal(err)
	}
	var name, phone, street, commune string
	if err = db.QueryRow(ctx, `SELECT recipient_name, recipient_phone, recipient_street, recipient_commune FROM orders WHERE deal_id = @id`,
		pgx.StrictNamedArgs{"id": d.ID()}).Scan(&name, &phone, &street, &commune); err != nil {
		t.Fatal(err)
	}
	if name != "" || phone != "" || street != "" || commune == "" {
		t.Fatalf("after scrub: %q %q %q %q", name, phone, street, commune)
	}
}
```

- [ ] **Step 6: Implement the repository methods**

In `internal/deal/repository/repository.go`, add to `Deals`:

```go
	// OpenOrders reports an order of account's, as buyer or seller, that is
	// requested or shipped.
	OpenOrders(ctx context.Context, account uuid.UUID) (bool, error)
	// ActiveOf lists the deals, negotiating or agreed, where account is
	// either side, oldest first.
	ActiveOf(ctx context.Context, account uuid.UUID) ([]domain.Deal, error)
	// ScrubRecipients blanks the recipient's name, phone and street of every
	// order buyer bought; the commune stays.
	ScrubRecipients(ctx context.Context, buyer uuid.UUID) error
```

In `internal/deal/repository/deal_pg.go`:

```go
func (s pgDeals) OpenOrders(ctx context.Context, account uuid.UUID) (bool, error) {
	var open bool
	if err := s.db.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM orders
WHERE (buyer_id = @account OR seller_id = @account) AND status IN ('requested', 'shipped'))`,
		pgx.StrictNamedArgs{"account": account}).Scan(&open); err != nil {
		return false, fmt.Errorf("check open orders: %w", err)
	}
	return open, nil
}

func (s pgDeals) ActiveOf(ctx context.Context, account uuid.UUID) ([]domain.Deal, error) {
	return s.many(ctx, selectDeal+`WHERE (d.buyer_id = @account OR d.seller_id = @account)
AND d.status IN ('negotiating', 'agreed') ORDER BY d.id`, pgx.StrictNamedArgs{"account": account})
}

func (s pgDeals) ScrubRecipients(ctx context.Context, buyer uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `UPDATE orders SET recipient_name = '', recipient_phone = '', recipient_street = ''
WHERE buyer_id = @buyer`, pgx.StrictNamedArgs{"buyer": buyer}); err != nil {
		return fmt.Errorf("scrub recipients: %w", err)
	}
	return nil
}
```

If `selectDeal` ends without a trailing space or newline before `WHERE`, match how `OfListing` joins it.

- [ ] **Step 7: Write the failing service test**

`internal/deal/service/account_deleted_test.go`, built like `listing_changed_test.go` (read it for how it builds the service, a seller, a buyer and a listing):

```go
func TestAccountDeletedEndsTheDeals(t *testing.T) {
	t.Parallel()
	env := newEnv(t) // listing_changed_test.go's setup, under whatever name it has
	d := env.requested(t) // a deal with a requested order

	open, err := env.svc.OpenOrders(context.Background(), d.Buyer)
	if err != nil || !open {
		t.Fatalf("open orders: %v %v", open, err)
	}
	for range 2 {
		if err = env.svc.AccountDeleted(context.Background(), d.Buyer); err != nil {
			t.Fatal(err)
		}
	}
	v, err := env.svc.Get(context.Background(), d.Seller, d.ID)
	if err != nil || v.Status != "negotiating" || v.Order == nil || v.Order.Status != "cancelled" {
		t.Fatalf("after: %+v %v", v, err)
	}
	if open, _ = env.svc.OpenOrders(context.Background(), d.Buyer); open {
		t.Fatal("an order is still open")
	}
}
```

Adapt field names (`d.Buyer`, `v.Order.Status`) to the views the package has; the assertions stay: the order is cancelled, the deal negotiates, a second call changes nothing.

- [ ] **Step 8: Implement the service methods**

In `internal/deal/service/service.go`, add to `Service`:

```go
	// OpenOrders reports an order of account's, as either side, that is
	// requested or shipped; erasure refuses to delete the account then.
	OpenOrders(ctx context.Context, account uuid.UUID) (bool, error)
	// AccountDeleted ends what a deleted account leaves open in its deals;
	// the worker calls it on account.deleted.
	AccountDeleted(ctx context.Context, account uuid.UUID) error
	// ScrubRecipients blanks the recipients of a deleted buyer's orders;
	// the worker calls it domain.KeepRecipientsFor after the deletion.
	ScrubRecipients(ctx context.Context, buyer uuid.UUID) error
```

`internal/deal/service/account_deleted.go`:

```go
package service

import (
	"context"
	"fmt"
	"uuid"
)

func (s *Deals) OpenOrders(ctx context.Context, account uuid.UUID) (bool, error) {
	open, err := s.deals.OpenOrders(ctx, account)
	if err != nil {
		return false, fmt.Errorf("check open orders: %w", err)
	}
	return open, nil
}

// AccountDeleted reads the account's active deals and ends what each holds
// open. A deal another write changed meanwhile fails the call, and the
// worker's retry reads it again; a repeated call finds nothing to change.
func (s *Deals) AccountDeleted(ctx context.Context, account uuid.UUID) error {
	deals, err := s.deals.ActiveOf(ctx, account)
	if err != nil {
		return fmt.Errorf("list deals: %w", err)
	}
	now := s.now()
	for i := range deals {
		if !deals[i].PartyLeft(now) {
			continue
		}
		if err = s.deals.Save(ctx, &deals[i], uuid.NewV7(), moved(deals[i].ID(), now)); err != nil {
			return fmt.Errorf("save deal: %w", err)
		}
	}
	return nil
}

func (s *Deals) ScrubRecipients(ctx context.Context, buyer uuid.UUID) error {
	if err := s.deals.ScrubRecipients(ctx, buyer); err != nil {
		return fmt.Errorf("scrub recipients: %w", err)
	}
	return nil
}
```

A cancelled order releases nothing in catalog: a requested order holds no listing (only a shipped one reserves it).

- [ ] **Step 9: Write the failing worker test**

`internal/deal/worker/account_test.go`, after `listing_test.go`'s recorder:

```go
// accountRecorder is a deal service that records AccountDeleted and
// ScrubRecipients.
type accountRecorder struct {
	service.Service

	mu      *sync.Mutex
	deleted *[]uuid.UUID
	scrubbed *[]uuid.UUID
}

func (r accountRecorder) AccountDeleted(_ context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	*r.deleted = append(*r.deleted, id)
	return nil
}

func (r accountRecorder) ScrubRecipients(_ context.Context, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	*r.scrubbed = append(*r.scrubbed, id)
	return nil
}

func TestAccountWatch(t *testing.T) {
	t.Parallel()
	var deleted, scrubbed []uuid.UUID
	mu := &sync.Mutex{}
	w := worker.AccountWatch{Prefix: restatetest.Prefix(), Deals: accountRecorder{mu: mu, deleted: &deleted, scrubbed: &scrubbed}}
	client := restatetest.Start(t, restate.Reflect(w))
	e := events.Event{ID: uuid.NewV7(), Kind: events.AccountDeleted, SubjectID: uuid.NewV7(), OccurredAt: time.Now()}
	for range 2 {
		if _, err := ingress.Service[events.Event, restate.Void](client, w.ServiceName(), "Deleted").Request(context.Background(), e); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := ingress.Service[uuid.UUID, restate.Void](client, w.ServiceName(), "Scrub").Request(context.Background(), e.SubjectID); err != nil {
		t.Fatal(err)
	}
	mu.Lock()
	defer mu.Unlock()
	if len(deleted) != 2 || deleted[0] != e.SubjectID || len(scrubbed) != 1 || scrubbed[0] != e.SubjectID {
		t.Fatalf("deleted %v, scrubbed %v", deleted, scrubbed)
	}
}
```

The year-long delayed send cannot be observed in a test; `Scrub` is called directly.

- [ ] **Step 10: Implement the worker and mount it**

`internal/deal/worker/account.go`:

```go
package worker

import (
	"fmt"
	"uuid"

	restate "github.com/restatedev/sdk-go"

	"github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/deal/service"
	"github.com/shopnexus/server/internal/platform/events"
)

// AccountWatch ends a deleted account's deals: Mount subscribes Deleted to
// account.deleted. Deleted schedules Scrub domain.KeepRecipientsFor later,
// which blanks the recipients of the account's orders.
type AccountWatch struct {
	Prefix string
	Deals  service.Service
}

func (w AccountWatch) ServiceName() string { return w.Prefix + "DealAccountWatch" }

// Deleted ends the account's deals and schedules Scrub. Restate journals
// the send, so a retried invocation schedules one call; a redelivered event
// schedules a second, which blanks the same rows.
func (w AccountWatch) Deleted(ctx restate.Context, e events.Event) error {
	if err := restate.RunVoid(ctx, func(rc restate.RunContext) error {
		return w.Deals.AccountDeleted(rc, e.SubjectID)
	}); err != nil {
		return fmt.Errorf("account %s deleted: %w", e.SubjectID, err)
	}
	restate.ServiceSend(ctx, w.ServiceName(), "Scrub").Send(e.SubjectID, restate.WithDelay(domain.KeepRecipientsFor))
	return nil
}

// Scrub blanks the recipients of the deleted account's orders.
func (w AccountWatch) Scrub(ctx restate.Context, account uuid.UUID) error {
	if err := restate.RunVoid(ctx, func(rc restate.RunContext) error {
		return w.Deals.ScrubRecipients(rc, account)
	}); err != nil {
		return fmt.Errorf("scrub %s: %w", account, err)
	}
	return nil
}
```

In `internal/deal/deal.go`, after the listing watch:

```go
	accountWatch := worker.AccountWatch{Prefix: d.ServicePrefix, Deals: svc}
	d.Events.Subscribe(events.AccountDeleted, accountWatch.ServiceName(), "Deleted")
	return module.Mounted[service.Service]{
		Services: append(svc.Durable(), restate.Reflect(watch), restate.Reflect(accountWatch)), Service: svc,
	}
```

and update `Mount`'s doc comment to name the account watch.

- [ ] **Step 11: Run the deal tests**

Run: `go test ./internal/deal/... ./internal/app/...`
Expected: PASS (`app.New` refuses to start when a subscription names a handler the process does not serve; `app_test.go` covers it).

- [ ] **Step 12: Commit**

```bash
git add internal/deal
git commit -m "feat(deal): a deleted account's deals end, and its orders lose their recipients a year later"
```

---

### Task 4: Module erasure and `DELETE /v1/accounts/me`

**Files:**
- Modify: `api/paths/account.yaml` (`me.delete`)
- Create: `internal/erasure/erasure.go`, `internal/erasure/service/service.go`, `internal/erasure/service/account_delete.go`, `internal/erasure/handler/handler.go`
- Modify: `internal/app/app.go` (`mountModules`)
- Modify: `cmd/depguardgen/main.go` (the rule for erasure), `.golangci.yml` (regenerated)
- Test: `internal/erasure/service/account_delete_test.go`, `e2e/erasure_test.go`

**Interfaces:**
- Consumes: `accountsvc.Service.Erase`, `dealsvc.Service.OpenOrders`, `accountdomain.RecentAuth`, `accountdomain.ErrReauthRequired`, `dealdomain.ErrOrdersOpen`.
- Produces: `erasure.Mount(d module.Deps, accounts accountsvc.Service, deals dealsvc.Service)`; `service.Service{ DeleteAccount(ctx context.Context, p authn.Principal) error }`.

- [ ] **Step 1: Write the spec**

In `api/paths/account.yaml`, under `me:` after `patch:`:

```yaml
  delete:
    operationId: deleteMyAccount
    summary: Delete the caller's account.
    description: |
      Needs a sign-in within 15 minutes. The account's listings, profile,
      sign-in methods, addresses, saves, search history, blocks and follows
      go; its sessions end. The row stays without a name, bio or avatar for
      the orders, reviews and messages that name it, and other people see
      "deleted" there. A phone or email of the account signs up as a new
      account. The recipients of the orders it bought are blanked a year
      later.
    tags: [account]
    security:
      - bearerAuth: []
    responses:
      "204":
        description: Deleted.
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "403":
        description: "A suspension is in force (account_suspended)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "409":
        description: "An order of the caller is requested or shipped (orders_open), or the account changed twice during the call (try_again)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "428":
        description: "The last sign-in is older than 15 minutes (reauth_required)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

If another 428 in the spec uses a shared response (`grep -n 428 -A3 api/paths/auth.yaml`), reference it instead of the inline one.

- [ ] **Step 2: Write the failing service test**

`internal/erasure/service/account_delete_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"testing"
	"time"
	"uuid"

	accountdomain "github.com/shopnexus/server/internal/account/domain"
	accountsvc "github.com/shopnexus/server/internal/account/service"
	dealdomain "github.com/shopnexus/server/internal/deal/domain"
	dealsvc "github.com/shopnexus/server/internal/deal/service"
	"github.com/shopnexus/server/internal/erasure/service"
	"github.com/shopnexus/server/internal/platform/authn"
)

var now = time.Date(2026, 11, 10, 9, 0, 0, 0, time.UTC)

type accounts struct {
	accountsvc.Service

	erased *[]uuid.UUID
	err    error
}

func (a accounts) Erase(_ context.Context, id uuid.UUID) error {
	*a.erased = append(*a.erased, id)
	return a.err
}

type deals struct {
	dealsvc.Service

	open bool
}

func (d deals) OpenOrders(context.Context, uuid.UUID) (bool, error) { return d.open, nil }

func TestDeleteAccount(t *testing.T) {
	t.Parallel()
	me := uuid.NewV7()
	fresh := authn.Principal{AccountID: me, AuthTime: now.Add(-14 * time.Minute)}
	stale := authn.Principal{AccountID: me, AuthTime: now.Add(-16 * time.Minute)}
	for _, tc := range []struct {
		name   string
		p      authn.Principal
		open   bool
		eraseErr error
		want   error
		erased int
	}{
		{"deleted", fresh, false, nil, nil, 1},
		{"stale sign-in", stale, false, nil, accountdomain.ErrReauthRequired, 0},
		{"open order", fresh, true, nil, dealdomain.ErrOrdersOpen, 0},
		{"suspended", fresh, false, accountdomain.ErrSuspended, accountdomain.ErrSuspended, 1},
	} {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()
			var erased []uuid.UUID
			svc := service.New(service.Deps{
				Accounts: accounts{erased: &erased, err: tc.eraseErr}, Deals: deals{open: tc.open},
				Now: func() time.Time { return now },
			})
			err := svc.DeleteAccount(context.Background(), tc.p)
			if !errors.Is(err, tc.want) || (tc.want == nil && err != nil) || len(erased) != tc.erased {
				t.Fatalf("err %v, erased %v", err, erased)
			}
		})
	}
}
```

If `authn.Principal`'s fields differ (`AccountID`, `AuthTime`), read `internal/platform/authn` and use its names.

- [ ] **Step 3: Run it to see it fail**

Run: `go test ./internal/erasure/...`
Expected: build failure, package `service` missing.

- [ ] **Step 4: Implement the module**

`internal/erasure/service/service.go`:

```go
// Package service holds module erasure's one use case: a person deletes
// their account. It sits above account and deal, since deal imports
// account and account cannot ask deal about open orders.
package service

import (
	"context"
	"time"

	accountsvc "github.com/shopnexus/server/internal/account/service"
	dealsvc "github.com/shopnexus/server/internal/deal/service"
	"github.com/shopnexus/server/internal/platform/authn"
)

// Service is module erasure's contract.
type Service interface {
	// DeleteAccount deletes the caller's account after a recent sign-in,
	// unless an order of theirs is requested or shipped.
	DeleteAccount(ctx context.Context, p authn.Principal) error
}

// Deps is what New builds Erasure from.
type Deps struct {
	Accounts accountsvc.Service
	Deals    dealsvc.Service
	Now      func() time.Time
}

// Erasure implements Service in this process.
type Erasure struct {
	accounts accountsvc.Service
	deals    dealsvc.Service
	now      func() time.Time
}

var _ Service = (*Erasure)(nil)

func New(d Deps) *Erasure { return &Erasure{accounts: d.Accounts, deals: d.Deals, now: d.Now} }
```

`internal/erasure/service/account_delete.go`:

```go
package service

import (
	"context"
	"fmt"

	accountdomain "github.com/shopnexus/server/internal/account/domain"
	dealdomain "github.com/shopnexus/server/internal/deal/domain"
	"github.com/shopnexus/server/internal/platform/authn"
)

// DeleteAccount checks the sign-in's age and the open orders, then erases
// the account. A COD request that lands between the check and the erase is
// cancelled by deal's worker on account.deleted.
func (s *Erasure) DeleteAccount(ctx context.Context, p authn.Principal) error {
	if s.now().Sub(p.AuthTime) > accountdomain.RecentAuth {
		return accountdomain.ErrReauthRequired
	}
	open, err := s.deals.OpenOrders(ctx, p.AccountID)
	if err != nil {
		return fmt.Errorf("check open orders: %w", err)
	}
	if open {
		return dealdomain.ErrOrdersOpen
	}
	if err = s.accounts.Erase(ctx, p.AccountID); err != nil {
		return fmt.Errorf("erase account: %w", err)
	}
	return nil
}
```

Wrapping with `%w` keeps `apperr` errors reachable for `httpx.WriteError` (check that `WriteError` uses `apperr.From`, which unwraps; if it does not, return `err` unwrapped).

`internal/erasure/handler/handler.go`:

```go
// Package handler serves module erasure's HTTP API.
package handler

import (
	"log/slog"
	"net/http"

	"github.com/shopnexus/server/internal/erasure/service"
	"github.com/shopnexus/server/internal/platform/httpx"
)

type Handler struct {
	svc service.Service
	log *slog.Logger
}

func New(svc service.Service, log *slog.Logger) *Handler { return &Handler{svc: svc, log: log} }

// Register adds DELETE /v1/accounts/me behind protect.
func (h *Handler) Register(r *httpx.Router, protect func(http.Handler) http.Handler) {
	r.Handle("DELETE /v1/accounts/me", protect(http.HandlerFunc(h.DeleteAccount)))
}

// DeleteAccount serves DELETE /v1/accounts/me.
func (h *Handler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	if err := h.svc.DeleteAccount(r.Context(), p); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

`internal/erasure/erasure.go`:

```go
// Package erasure deletes accounts: it checks deal for open orders and
// asks account to erase, and every module clears its own rows on
// account.deleted.
package erasure

import (
	accountsvc "github.com/shopnexus/server/internal/account/service"
	dealsvc "github.com/shopnexus/server/internal/deal/service"
	"github.com/shopnexus/server/internal/erasure/handler"
	"github.com/shopnexus/server/internal/erasure/service"
	"github.com/shopnexus/server/internal/platform/module"
)

// Mount registers DELETE /v1/accounts/me.
func Mount(d module.Deps, accounts accountsvc.Service, deals dealsvc.Service) {
	handler.New(service.New(service.Deps{Accounts: accounts, Deals: deals, Now: d.Now}), d.Log).Register(d.Router, d.Protect)
}
```

In `internal/app/app.go`, after `dealm := deal.Mount(...)`: `erasure.Mount(d, accounts, dealm.Service)`.

In `cmd/depguardgen/main.go`, beside the `"screen"` rule: `"erasure": {desc: "no module calls erasure; it calls account and deal."},`. Run `make depguard`.

In `ARCHITECTURE.md`'s Module layout, the sentence "trust and discovery return their `Service`; console and screen return nothing" gains erasure among those that return nothing (Task 9 writes the rest).

- [ ] **Step 5: Run the service tests**

Run: `go test ./internal/erasure/... ./internal/app/...`
Expected: PASS (`TestRoutesMatchSpec` matches the new route to the spec).

- [ ] **Step 6: Write the e2e test**

`e2e/erasure_test.go`:

```go
package e2e

import (
	"testing"
	"time"

	accountdomain "github.com/shopnexus/server/internal/account/domain"
)

func TestDeleteMyAccount(t *testing.T) {
	t.Parallel()
	me, phone := newAccount(t)

	p, _ := accountdomain.NewVerifier(keys).Verify(me.AccessToken, time.Now())
	s, _ := accountdomain.NewSession(p.SessionID, p.AccountID, "", time.Now().Add(-20*time.Minute), time.Now())
	stale, _, _ := accountdomain.NewSigner(keys).Sign(s, time.Now())
	check(t, "stale sign-in", call(t, "DELETE", "/v1/accounts/me", nil, bearer(stale)), 428, "reauth_required")
	check(t, "signed out", call(t, "DELETE", "/v1/accounts/me", nil), 401, "unauthenticated")

	check(t, "delete", call(t, "DELETE", "/v1/accounts/me", nil, bearer(me.AccessToken)), 204, "")
	check(t, "refresh", refresh(t, me.RefreshToken), 401, "session_revoked")
	again := signInWith(t, phone)
	if again.AccountID == p.AccountID.String() {
		t.Fatal("the phone signed in to the deleted account")
	}
}

func TestDeleteMyAccountRefusals(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	requestedOrder(t, buyer.AccessToken, activeListing(t, seller.AccessToken, nil).ID)
	check(t, "open order", call(t, "DELETE", "/v1/accounts/me", nil, bearer(seller.AccessToken)), 409, "orders_open")

	suspended, _ := newAccount(t)
	suspend(t, suspended.AccountID)
	check(t, "suspended", call(t, "DELETE", "/v1/accounts/me", nil, bearer(suspended.AccessToken)), 403, "account_suspended")
}
```

Adapt the helper names to what `e2e/` has: `refresh` (`auth_session_test.go`), `signInWith` and the `signIn` fields (`auth_helpers_test.go`). If `refresh`'s response on a revoked session has another code, keep the code the auth tests expect. Task 5 adds the check that the listings go.

- [ ] **Step 7: Run the e2e tests**

Run: `go test ./e2e/ -run 'TestDeleteMyAccount'`
Expected: PASS.

- [ ] **Step 8: Run everything and commit**

Run: `make test`
Expected: PASS, golangci-lint clean.

```bash
git add api internal/erasure internal/app/app.go cmd/depguardgen .golangci.yml e2e/erasure_test.go ARCHITECTURE.md
git commit -m "feat(erasure): DELETE /v1/accounts/me after a recent sign-in, refused while an order is open"
```

---

### Task 5: Catalog and notification clear a deleted account

**Files:**
- Create: `internal/catalog/service/seller_left.go`, `internal/catalog/worker/account.go`
- Modify: `internal/catalog/service/service.go` (interface), `internal/catalog/catalog.go`
- Modify: `internal/notification/repository/repository.go`, `internal/notification/repository/notice_pg.go` (the file holding `DeleteToken`), `internal/notification/service/service.go`, the notification service file holding `DeleteToken`, `internal/notification/worker/worker.go`, `internal/notification/notification.go`
- Modify: `.golangci.yml` (regenerated)
- Test: `internal/catalog/service/seller_left_test.go`, `internal/catalog/worker/account_test.go`, `internal/notification/repository/*_test.go`, `internal/notification/worker/worker_test.go`

**Interfaces:**
- Consumes: `events.AccountDeleted`.
- Produces: `catalogsvc.Service.SellerLeft(ctx context.Context, seller uuid.UUID) error`; `catalog/worker.AccountWatch{Prefix string; Listings service.Service}`, service `<prefix>CatalogAccountWatch`, handler `Deleted`; `notificationsvc.Service.Forget(ctx context.Context, account uuid.UUID) error`; notification worker handler `AccountDeleted`.

- [ ] **Step 1: Write the failing catalog test**

`internal/catalog/service/seller_left_test.go`, using `catalogtest.Listing` and the helpers of `listing_test.go` (read them for how a test gets a processing, an active, a hidden and a sold listing of one seller):

```go
func TestSellerLeftDeletesTheListings(t *testing.T) {
	t.Parallel()
	env := newEnv(t) // the package's test setup
	seller := env.seller(t)
	active := env.active(t, seller)
	hidden := env.hidden(t, seller)
	processing := env.processing(t, seller)
	sold := env.sold(t, seller)

	for range 2 {
		if err := env.svc.SellerLeft(context.Background(), seller); err != nil {
			t.Fatal(err)
		}
	}
	for id, want := range map[uuid.UUID]domain.Status{
		active: domain.StatusDeleted, hidden: domain.StatusDeleted, processing: domain.StatusDeleted, sold: domain.StatusSold,
	} {
		l, err := env.listings.Get(context.Background(), id)
		if err != nil || l.Status() != want {
			t.Errorf("%s: %s %v, want %s", id, l.Status(), err, want)
		}
	}
	if n := len(pgtest.EventKinds(t, env.db, active)); n == 0 {
		t.Fatal("no listing.deleted")
	}
}
```

Name the helpers after what the package has; the assertions stay.

- [ ] **Step 2: Implement SellerLeft**

In `internal/catalog/service/service.go`, add to `Service`:

```go
	// SellerLeft deletes every listing of a deleted seller that is not sold
	// or deleted, each with listing.deleted; the worker calls it on
	// account.deleted, and a repeated call finds nothing left.
	SellerLeft(ctx context.Context, seller uuid.UUID) error
```

`internal/catalog/service/seller_left.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"uuid"

	"github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/catalog/repository"
	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/platform/events"
	"github.com/shopnexus/server/internal/platform/page"
)

// leftBehind are the statuses a deleted seller's listings leave: sold ones
// stay for the orders that name them, and none is reserved, since erasure
// refuses a seller with a shipped order.
var leftBehind = []domain.Status{domain.StatusProcessing, domain.StatusActive, domain.StatusHidden, domain.StatusRejected}

// SellerLeft deletes the seller's listings a page at a time; a deleted
// listing leaves the filter, so each round reads the first page again.
func (c *Catalog) SellerLeft(ctx context.Context, seller uuid.UUID) error {
	for {
		ls, err := c.listings.ListBySeller(ctx, seller, leftBehind, page.Request{Limit: 100})
		if err != nil {
			return fmt.Errorf("list listings: %w", err)
		}
		if len(ls) == 0 {
			return nil
		}
		now := c.now()
		for i := range ls {
			if err = ls[i].Delete(now); err != nil {
				return fmt.Errorf("delete listing %s: %w", ls[i].ID(), err)
			}
			err = c.listings.Save(ctx, &ls[i], uuid.NewV7(),
				events.Event{ID: uuid.NewV7(), Kind: events.ListingDeleted, SubjectID: ls[i].ID(), OccurredAt: now})
			if errors.Is(err, repository.ErrConflict) {
				return apperr.ErrTryAgain
			}
			if err != nil {
				return fmt.Errorf("save listing: %w", err)
			}
		}
	}
}
```

Read `page.Request` (`internal/platform/page`) for its field names; if the limit field is not `Limit`, use its name. A processing listing whose post flow is still running: read `listing_publish_durable.go`. If publishing a listing that is now `deleted` would set it `active`, make the publish refuse a deleted listing (the domain's `Publish` should return `ErrStateConflict` for any status but processing; add that check and a domain test if it is missing).

- [ ] **Step 3: Write the catalog worker and its test**

`internal/catalog/worker/account.go`:

```go
// Package worker holds module catalog's Restate handlers for the events it
// reacts to.
package worker

import (
	"fmt"

	restate "github.com/restatedev/sdk-go"

	"github.com/shopnexus/server/internal/catalog/service"
	"github.com/shopnexus/server/internal/platform/events"
)

// AccountWatch deletes a deleted seller's listings: Mount subscribes
// Deleted to account.deleted.
type AccountWatch struct {
	Prefix   string
	Listings service.Service
}

func (w AccountWatch) ServiceName() string { return w.Prefix + "CatalogAccountWatch" }

func (w AccountWatch) Deleted(ctx restate.Context, e events.Event) error {
	if err := restate.RunVoid(ctx, func(rc restate.RunContext) error {
		return w.Listings.SellerLeft(rc, e.SubjectID)
	}); err != nil {
		return fmt.Errorf("seller %s left: %w", e.SubjectID, err)
	}
	return nil
}
```

`internal/catalog/worker/account_test.go`: the recorder pattern of `internal/deal/worker/listing_test.go`, with `SellerLeft` recorded, the handler `Deleted` called twice with one event, and two recorded calls with the subject's ID.

In `internal/catalog/catalog.go`:

```go
	watch := worker.AccountWatch{Prefix: d.ServicePrefix, Listings: svc}
	d.Events.Subscribe(events.AccountDeleted, watch.ServiceName(), "Deleted")
	return module.Mounted[service.Service]{Services: append(svc.Durable(), restate.Reflect(watch)), Service: svc}
```

with imports `restate`, `events` and `internal/catalog/worker`. Run `make depguard` (catalog gains a worker layer).

- [ ] **Step 4: Write the failing notification tests**

In the notification repository tests (the file testing `PutToken`/`Tokens`), add:

```go
func TestForget(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	s := newNotices(t) // the file's setup
	account := seedAccount(t)
	addNotice(t, s, account) // the file's way to add one
	if err := s.PutToken(ctx, uuid.NewV7(), account, "fcm-token", now); err != nil {
		t.Fatal(err)
	}
	if err := s.Forget(ctx, account); err != nil {
		t.Fatal(err)
	}
	if rows, _ := s.List(ctx, account, page.Request{}); len(rows) != 0 {
		t.Fatalf("notices left: %d", len(rows))
	}
	if tokens, _ := s.Tokens(ctx, account); len(tokens) != 0 {
		t.Fatalf("tokens left: %d", len(tokens))
	}
}
```

In `internal/notification/worker/worker_test.go`, add a test in the style of the `AccountSuspended` test: `AccountDeleted` called twice with one `account.deleted` event leaves the account with no notices and no tokens.

- [ ] **Step 5: Implement Forget and the handler**

Repository interface:

```go
	// Forget deletes the account's notices and push tokens.
	Forget(ctx context.Context, account uuid.UUID) error
```

Postgres:

```go
func (s pgNotices) Forget(ctx context.Context, account uuid.UUID) error {
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		for _, q := range []string{
			`DELETE FROM notifications WHERE account_id = @account`,
			`DELETE FROM push_tokens WHERE account_id = @account`,
		} {
			if _, err := tx.Exec(ctx, q, pgx.StrictNamedArgs{"account": account}); err != nil {
				return fmt.Errorf("forget: %w", err)
			}
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("forget account: %w", err)
	}
	return nil
}
```

(Use the receiver type the file declares.) Service interface gains `Forget(ctx context.Context, account uuid.UUID) error`, implemented beside `DeleteToken` as a call to the repository wrapped with `fmt.Errorf("forget: %w", err)`.

In `internal/notification/worker/worker.go`, beside `AccountSuspended`:

```go
// AccountDeleted deletes the deleted account's notices and push tokens.
// A notice of a later event about the account's deals can still be
// written; nobody reads it.
func (w Worker) AccountDeleted(ctx restate.Context, e events.Event) error {
	if err := restate.RunVoid(ctx, func(rc restate.RunContext) error {
		return w.Notices.Forget(rc, e.SubjectID)
	}); err != nil {
		return fmt.Errorf("forget %s: %w", e.SubjectID, err)
	}
	return nil
}
```

In `internal/notification/notification.go`, the subscription map gains `events.AccountDeleted: "AccountDeleted"`.

- [ ] **Step 6: Run the tests and commit**

Add to `e2e/erasure_test.go`:

```go
func TestDeletedSellersListingsGo(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	viewer, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	check(t, "delete", call(t, "DELETE", "/v1/accounts/me", nil, bearer(seller.AccessToken)), 204, "")
	testenv.Eventually(t, 10*time.Second, func() error {
		if res := call(t, "GET", "/v1/screens/listing/"+l.ID, nil, bearer(viewer.AccessToken)); res.Status != http.StatusNotFound {
			return fmt.Errorf("listing page: %d", res.Status)
		}
		return nil
	})
}
```

Read `testenv.Eventually`'s package path and signature (`grep -rn "func Eventually" internal`) and match them; the listing page is 404 once the listing is not public.

Run: `go test ./internal/catalog/... ./internal/notification/... ./internal/app/... && go test ./e2e/ -run TestDelete` then `make test`
Expected: PASS.

```bash
git add internal/catalog internal/notification .golangci.yml e2e/erasure_test.go
git commit -m "feat(catalog, notification): a deleted account's listings, notices and push tokens go"
```

---

### Task 6: Search history

**Files:**
- Modify: `api/paths/discovery.yaml`, `api/schemas/discovery.yaml`, `api/openapi.yaml` (paths)
- Create: `internal/discovery/domain/history.go`
- Create: `internal/discovery/repository/history_pg.go`
- Modify: `internal/discovery/repository/repository.go`, `internal/discovery/repository/saved_pg.go` (`Clear`)
- Create: `internal/discovery/service/history.go`
- Modify: `internal/discovery/service/service.go`, `internal/discovery/service/search.go`
- Modify: `internal/discovery/handler/handler.go` (routes), create `internal/discovery/handler/history.go`
- Create: `internal/discovery/worker/account.go`
- Modify: `internal/discovery/discovery.go`, `internal/app/app.go`, `go.mod`, `.golangci.yml`
- Test: `internal/discovery/domain/history_test.go`, `internal/discovery/repository/history_pg_test.go`, `internal/discovery/service/history_test.go`, `internal/discovery/worker/account_test.go`, `e2e/search_history_test.go`

**Interfaces:**
- Produces (domain): `HistoryKey(q string) string`; `MaxHistory = 10`.
- Produces (repository): `type HistoryEntry struct { ID uuid.UUID; Query, Category, PhotoURL string; SearchedAt time.Time }`; `History` interface: `Remember(ctx, account uuid.UUID, e HistoryEntry) error`, `List(ctx, account uuid.UUID) ([]HistoryEntry, error)`, `Forget(ctx, account, id uuid.UUID) error`, `Clear(ctx, account uuid.UUID) error`; `Saves.Clear(ctx, account uuid.UUID) error`.
- Produces (service): `History(ctx, account uuid.UUID) (HistoryView, error)`, `ForgetSearch(ctx, account, id uuid.UUID) error`, `ClearHistory(ctx, account uuid.UUID) error`, `AccountDeleted(ctx, account uuid.UUID) error`; `HistoryView{Items []HistoryItem}`; `HistoryItem{ID uuid.UUID; Query, Title string; Category, PhotoURL string (omitempty); SearchedAt time.Time}`.
- Produces: `discovery.Mount` returns `module.Mounted[service.Service]`.

- [ ] **Step 1: Write the spec**

`api/schemas/discovery.yaml`:

```yaml
SearchHistory:
  type: object
  additionalProperties: false
  required: [items]
  properties:
    items:
      type: array
      maxItems: 10
      items:
        $ref: "#/SearchHistoryItem"
SearchHistoryItem:
  type: object
  additionalProperties: false
  required: [id, query, title, searched_at]
  description: A text search the caller made, newest first.
  properties:
    id:
      type: string
      format: uuid
    query:
      type: string
      description: The words as the caller typed them.
    title:
      type: string
      description: The query with its first letter upper-cased.
    category:
      type: string
      description: The category the search understood; absent when none.
    photo_url:
      type: string
      format: uri
      description: The first result's photo; absent when the search found nothing.
    searched_at:
      type: string
      format: date-time
```

`api/paths/discovery.yaml`:

```yaml
searchHistory:
  get:
    operationId: getSearchHistory
    summary: The caller's last 10 text searches, newest first.
    tags: [discovery]
    security:
      - bearerAuth: []
    responses:
      "200":
        description: The history.
        content:
          application/json:
            schema:
              $ref: "../schemas/discovery.yaml#/SearchHistory"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
  delete:
    operationId: clearSearchHistory
    summary: Empty the caller's search history.
    tags: [discovery]
    security:
      - bearerAuth: []
    responses:
      "204":
        description: Emptied.
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
searchHistoryItem:
  delete:
    operationId: deleteSearchHistoryItem
    summary: Forget one search; an unknown one is fine.
    tags: [discovery]
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
        description: Forgotten.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
```

`api/openapi.yaml`, after `/v1/search:`:

```yaml
  /v1/search/history:
    $ref: "./paths/discovery.yaml#/searchHistory"
  /v1/search/history/{id}:
    $ref: "./paths/discovery.yaml#/searchHistoryItem"
```

(Match how the file writes its other `$ref`s.) The `GET /v1/search` operation's description gains: "A signed-in caller's first page with `q` is kept in the search history."

- [ ] **Step 2: Write the failing domain test**

`internal/discovery/domain/history_test.go`:

```go
package domain_test

import (
	"testing"

	"github.com/shopnexus/server/internal/discovery/domain"
)

func TestHistoryKey(t *testing.T) {
	t.Parallel()
	for in, want := range map[string]string{
		"Xe Đạp":            "xe dap",
		"  xe   đạp  ":      "xe dap",
		"xe dap":            "xe dap",
		"ĐIỆN THOẠI cũ":     "dien thoai cu",
		"iPhone 13 Pro Max": "iphone 13 pro max",
	} {
		if got := domain.HistoryKey(in); got != want {
			t.Errorf("HistoryKey(%q) = %q, want %q", in, got, want)
		}
	}
}
```

- [ ] **Step 3: Implement HistoryKey**

`internal/discovery/domain/history.go`:

```go
package domain

import (
	"strings"
	"unicode"

	"golang.org/x/text/runes"
	"golang.org/x/text/transform"
	"golang.org/x/text/unicode/norm"
)

// MaxHistory is how many searches a person's history keeps.
const MaxHistory = 10

// foldMarks strips the combining marks NFD splits off a letter.
var foldMarks = transform.Chain(norm.NFD, runes.Remove(runes.In(unicode.Mn)), norm.NFC)

// HistoryKey is a query as the history keys it: QueryKey, then without
// Vietnamese marks, đ as d, so "Xe Đạp" and "xe dap" are one entry.
func HistoryKey(q string) string {
	folded, _, err := transform.String(foldMarks, QueryKey(q))
	if err != nil {
		folded = QueryKey(q)
	}
	return strings.ReplaceAll(folded, "đ", "d")
}
```

Run `go get golang.org/x/text@latest` (the server's rule: newest release) and `go mod tidy`; `golang.org/x/text` moves from indirect to direct.

Run: `go test ./internal/discovery/domain/ -run TestHistoryKey`
Expected: PASS.

- [ ] **Step 4: Write the failing repository test**

`internal/discovery/repository/history_pg_test.go` (read `saved_pg_test.go` for its setup and account seeding):

```go
func TestHistory(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	h := repository.NewHistory(db)
	account := seedAccount(t, db) // saved_pg_test.go's way to make an account
	at := time.Date(2026, 11, 10, 9, 0, 0, 0, time.UTC)

	for i := range 12 {
		if err := h.Remember(ctx, account, repository.HistoryEntry{
			Query: fmt.Sprintf("tìm %d", i), SearchedAt: at.Add(time.Duration(i) * time.Minute),
		}); err != nil {
			t.Fatal(err)
		}
	}
	if err := h.Remember(ctx, account, repository.HistoryEntry{
		Query: "TÌM  5", Category: "Xe đạp", PhotoURL: "https://cdn.example/x.jpg", SearchedAt: at.Add(time.Hour),
	}); err != nil {
		t.Fatal(err)
	}
	list, err := h.List(ctx, account)
	if err != nil || len(list) != domain.MaxHistory {
		t.Fatalf("list: %d %v", len(list), err)
	}
	if list[0].Query != "TÌM  5" || list[0].Category != "Xe đạp" || list[0].PhotoURL == "" {
		t.Fatalf("top: %+v", list[0])
	}
	kept := map[string]bool{}
	for _, e := range list {
		kept[e.Query] = true
	}
	if kept["tìm 0"] || kept["tìm 1"] || kept["tìm 5"] || !kept["tìm 2"] || !kept["tìm 11"] {
		t.Fatalf("kept: %v", kept)
	}
	if err = h.Forget(ctx, account, list[0].ID); err != nil {
		t.Fatal(err)
	}
	if err = h.Forget(ctx, account, uuid.NewV7()); err != nil {
		t.Fatalf("forget an unknown entry: %v", err)
	}
	if list, _ = h.List(ctx, account); len(list) != domain.MaxHistory-1 {
		t.Fatalf("after forget: %d", len(list))
	}
	if err = h.Clear(ctx, account); err != nil {
		t.Fatal(err)
	}
	if list, _ = h.List(ctx, account); len(list) != 0 {
		t.Fatalf("after clear: %d", len(list))
	}
}
```

After twelve searches the list holds "tìm 2" to "tìm 11". "TÌM  5" folds to the key of "tìm 5", so it replaces that row and moves to the top: still 10 rows, "tìm 0" and "tìm 1" gone, "tìm 2" kept.

- [ ] **Step 5: Implement the history repository**

In `internal/discovery/repository/repository.go`:

```go
// HistoryEntry is one search of a person's history.
type HistoryEntry struct {
	ID         uuid.UUID
	Query      string
	Category   string // empty when the search understood none
	PhotoURL   string // empty when the search found nothing
	SearchedAt time.Time
}

// History keeps a person's last domain.MaxHistory text searches.
type History interface {
	// Remember puts e at the top: the same words (domain.HistoryKey) again
	// take a new ID and e's fields, and the entries past
	// domain.MaxHistory go, in one transaction.
	Remember(ctx context.Context, account uuid.UUID, e HistoryEntry) error
	// List is the history, newest first.
	List(ctx context.Context, account uuid.UUID) ([]HistoryEntry, error)
	// Forget deletes one entry of the account's; an unknown one is fine.
	Forget(ctx context.Context, account, id uuid.UUID) error
	// Clear deletes the account's history.
	Clear(ctx context.Context, account uuid.UUID) error
}
```

and add to `Saves`:

```go
	// Clear deletes every save of the account.
	Clear(ctx context.Context, account uuid.UUID) error
```

`internal/discovery/repository/history_pg.go`:

```go
package repository

import (
	"context"
	"fmt"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/shopnexus/server/internal/discovery/domain"
)

type pgHistory struct{ db *pgxpool.Pool }

func NewHistory(db *pgxpool.Pool) History { return pgHistory{db} }

const rememberSearch = `
INSERT INTO search_history (id, account_id, query_key, query, category, photo_url, searched_at)
VALUES (@id, @account, @key, @query, NULLIF(@category, ''), NULLIF(@photo_url, ''), @at)
ON CONFLICT (account_id, query_key) DO UPDATE
SET id = excluded.id, query = excluded.query, category = excluded.category,
    photo_url = excluded.photo_url, searched_at = excluded.searched_at`

func (s pgHistory) Remember(ctx context.Context, account uuid.UUID, e HistoryEntry) error {
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, rememberSearch, pgx.StrictNamedArgs{
			"id": uuid.NewV7(), "account": account, "key": domain.HistoryKey(e.Query), "query": e.Query,
			"category": e.Category, "photo_url": e.PhotoURL, "at": e.SearchedAt,
		}); err != nil {
			return fmt.Errorf("upsert search: %w", err)
		}
		if _, err := tx.Exec(ctx, `DELETE FROM search_history WHERE account_id = @account AND id NOT IN (
    SELECT id FROM search_history WHERE account_id = @account ORDER BY id DESC LIMIT @keep)`,
			pgx.StrictNamedArgs{"account": account, "keep": domain.MaxHistory}); err != nil {
			return fmt.Errorf("trim history: %w", err)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("remember search: %w", err)
	}
	return nil
}

func (s pgHistory) List(ctx context.Context, account uuid.UUID) ([]HistoryEntry, error) {
	rows, err := s.db.Query(ctx, `SELECT id, query, coalesce(category, ''), coalesce(photo_url, ''), searched_at
FROM search_history WHERE account_id = @account ORDER BY id DESC`, pgx.StrictNamedArgs{"account": account})
	if err != nil {
		return nil, fmt.Errorf("select history: %w", err)
	}
	entries, err := pgx.CollectRows(rows, pgx.RowToStructByPos[HistoryEntry])
	if err != nil {
		return nil, fmt.Errorf("read history: %w", err)
	}
	return entries, nil
}

func (s pgHistory) Forget(ctx context.Context, account, id uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM search_history WHERE account_id = @account AND id = @id`,
		pgx.StrictNamedArgs{"account": account, "id": id}); err != nil {
		return fmt.Errorf("forget search: %w", err)
	}
	return nil
}

func (s pgHistory) Clear(ctx context.Context, account uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM search_history WHERE account_id = @account`,
		pgx.StrictNamedArgs{"account": account}); err != nil {
		return fmt.Errorf("clear history: %w", err)
	}
	return nil
}
```

The ID is a UUIDv7 taken at the write, so `ORDER BY id DESC` is newest first. In a Remember with a past `SearchedAt` (tests), order still follows the write; that is what "moved to the top" means.

In `saved_pg.go`:

```go
func (s pgSaves) Clear(ctx context.Context, account uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM saved_listings WHERE account_id = @account`,
		pgx.StrictNamedArgs{"account": account}); err != nil {
		return fmt.Errorf("clear saves: %w", err)
	}
	return nil
}
```

Run: `go test ./internal/discovery/repository/ -run TestHistory`
Expected: PASS.

- [ ] **Step 6: Write the failing service tests**

`internal/discovery/service/history_test.go`, built like `search_test.go` (read its setup: a stub LLM, stub embeddings, `catalogtest`):

```go
func TestSearchRemembersTheFirstPage(t *testing.T) {
	t.Parallel()
	env := newSearchEnv(t) // search_test.go's setup
	viewer := env.account(t)
	ctx := context.Background()

	if _, err := env.svc.Search(ctx, &viewer, service.SearchInput{Query: "xe đạp"}); err != nil {
		t.Fatal(err)
	}
	if _, err := env.svc.Search(ctx, &viewer, service.SearchInput{Query: "xe đạp", Cursor: "20"}); err != nil {
		t.Fatal(err)
	}
	if _, err := env.svc.Search(ctx, nil, service.SearchInput{Query: "tủ lạnh"}); err != nil {
		t.Fatal(err)
	}
	if _, err := env.svc.Search(ctx, &viewer, service.SearchInput{Like: env.listing}); err != nil {
		t.Fatal(err)
	}
	h, err := env.svc.History(ctx, viewer)
	if err != nil || len(h.Items) != 1 || h.Items[0].Query != "xe đạp" || h.Items[0].Title != "Xe đạp" {
		t.Fatalf("history: %+v %v", h, err)
	}
	if err = env.svc.ForgetSearch(ctx, viewer, h.Items[0].ID); err != nil {
		t.Fatal(err)
	}
	if h, _ = env.svc.History(ctx, viewer); len(h.Items) != 0 {
		t.Fatalf("after forget: %+v", h)
	}
}

// failingHistory is a history store whose Remember fails.
type failingHistory struct{ repository.History }

func (failingHistory) Remember(context.Context, uuid.UUID, repository.HistoryEntry) error {
	return errors.New("db down")
}

func TestSearchSurvivesAFailedRemember(t *testing.T) {
	t.Parallel()
	env := newSearchEnv(t, withHistory(failingHistory{})) // or build service.Deps with History: failingHistory{}
	viewer := env.account(t)
	if _, err := env.svc.Search(context.Background(), &viewer, service.SearchInput{Query: "xe đạp"}); err != nil {
		t.Fatalf("search failed with the history: %v", err)
	}
}
```

Adapt the setup to `search_test.go`; the cases stay: the first page with `q` is kept, a later page, a signed-out search and a `like` search are not, and a failing store leaves the search answering.

- [ ] **Step 7: Implement the service**

`internal/discovery/service/service.go`: `Deps` and `Discovery` gain `History repository.History` / `history repository.History`; `New` copies it. `Service` gains:

```go
	// History is the account's last domain.MaxHistory text searches,
	// newest first.
	History(ctx context.Context, account uuid.UUID) (HistoryView, error)
	// ForgetSearch deletes one entry of the account's history; an unknown
	// one is fine.
	ForgetSearch(ctx context.Context, account, id uuid.UUID) error
	// ClearHistory empties the account's history.
	ClearHistory(ctx context.Context, account uuid.UUID) error
	// AccountDeleted deletes a deleted account's saves and history; the
	// worker calls it on account.deleted.
	AccountDeleted(ctx context.Context, account uuid.UUID) error
```

`internal/discovery/service/history.go`:

```go
package service

import (
	"context"
	"fmt"
	"time"
	"unicode"
	"unicode/utf8"
	"uuid"
)

// HistoryView is the SearchHistory schema.
type HistoryView struct {
	Items []HistoryItem `json:"items"`
}

// HistoryItem is the SearchHistoryItem schema.
type HistoryItem struct {
	ID         uuid.UUID `json:"id"`
	Query      string    `json:"query"`
	Title      string    `json:"title"`
	Category   string    `json:"category,omitempty"`
	PhotoURL   string    `json:"photo_url,omitempty"`
	SearchedAt time.Time `json:"searched_at"`
}

func (d *Discovery) History(ctx context.Context, account uuid.UUID) (HistoryView, error) {
	entries, err := d.history.List(ctx, account)
	if err != nil {
		return HistoryView{}, fmt.Errorf("read history: %w", err)
	}
	out := HistoryView{Items: make([]HistoryItem, 0, len(entries))}
	for _, e := range entries {
		first, size := utf8.DecodeRuneInString(e.Query)
		out.Items = append(out.Items, HistoryItem{
			ID: e.ID, Query: e.Query, Title: string(unicode.ToUpper(first)) + e.Query[size:],
			Category: e.Category, PhotoURL: e.PhotoURL, SearchedAt: e.SearchedAt,
		})
	}
	return out, nil
}

func (d *Discovery) ForgetSearch(ctx context.Context, account, id uuid.UUID) error {
	if err := d.history.Forget(ctx, account, id); err != nil {
		return fmt.Errorf("forget search: %w", err)
	}
	return nil
}

func (d *Discovery) ClearHistory(ctx context.Context, account uuid.UUID) error {
	if err := d.history.Clear(ctx, account); err != nil {
		return fmt.Errorf("clear history: %w", err)
	}
	return nil
}

func (d *Discovery) AccountDeleted(ctx context.Context, account uuid.UUID) error {
	if err := d.saves.Clear(ctx, account); err != nil {
		return fmt.Errorf("clear saves: %w", err)
	}
	if err := d.history.Clear(ctx, account); err != nil {
		return fmt.Errorf("clear history: %w", err)
	}
	return nil
}
```

The history keeps the query as typed after `strings.TrimSpace` (the search's `q`).

In `internal/discovery/service/search.go`, at the end of `Search`, before `return view, nil`:

```go
	if viewer != nil && q != "" && in.Cursor == "" {
		entry := repository.HistoryEntry{Query: q, SearchedAt: d.now()}
		for _, c := range view.Chips {
			if c.Kind == domain.AttrCategory {
				entry.Category = c.Label
				break
			}
		}
		if len(view.Items) > 0 {
			entry.PhotoURL = view.Items[0].CoverThumbURL
		}
		if err = d.history.Remember(ctx, *viewer, entry); err != nil {
			d.log.WarnContext(ctx, "remember the search", "err", err)
		}
	}
```

Import `github.com/shopnexus/server/internal/discovery/repository` in `search.go`. `Search`'s doc comment gains: "A signed-in viewer's first page with q is kept in the history; a failed write is logged and the search still answers."

- [ ] **Step 8: Handlers, worker and mount**

`internal/discovery/handler/handler.go`'s `Register` gains:

```go
	r.Handle("GET /v1/search/history", protect(http.HandlerFunc(h.History)))
	r.Handle("DELETE /v1/search/history", protect(http.HandlerFunc(h.ClearHistory)))
	r.Handle("DELETE /v1/search/history/{id}", protect(http.HandlerFunc(h.ForgetSearch)))
```

`internal/discovery/handler/history.go`:

```go
package handler

import (
	"net/http"
	"uuid"

	"github.com/shopnexus/server/internal/platform/httpx"
)

// History serves GET /v1/search/history.
func (h *Handler) History(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	out, err := h.svc.History(r.Context(), p.AccountID)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, out)
}

// ClearHistory serves DELETE /v1/search/history.
func (h *Handler) ClearHistory(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	if err := h.svc.ClearHistory(r.Context(), p.AccountID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type historyItemRequest struct {
	ID uuid.UUID `json:"-" path:"id"`
}

// ForgetSearch serves DELETE /v1/search/history/{id}.
func (h *Handler) ForgetSearch(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in historyItemRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.ForgetSearch(r.Context(), p.AccountID, in.ID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

`internal/discovery/worker/account.go`: the shape of `internal/catalog/worker/account.go` from Task 5, with package doc "module discovery's Restate handlers", service name `<prefix>DiscoveryAccountWatch`, field `Discovery service.Service`, and `Deleted` calling `w.Discovery.AccountDeleted(rc, e.SubjectID)`. Its test: the recorder pattern, two deliveries, two recorded calls.

`internal/discovery/discovery.go`: `Mount` builds `History: repository.NewHistory(d.Pool)`, subscribes the worker, and returns `module.Mounted[service.Service]{Services: []restate.ServiceDefinition{restate.Reflect(watch)}, Service: svc}`; its doc comment says so. In `internal/app/app.go`, `screen.Mount(...)` takes `discoverym.Service` and the final `slices.Concat` gains `discoverym.Services`. Update `ARCHITECTURE.md`'s Module layout sentence "trust and discovery return their `Service`" to "trust returns its `Service`". Run `make depguard`.

- [ ] **Step 9: Write the e2e test**

`e2e/search_history_test.go`:

```go
package e2e

import (
	"net/http"
	"net/url"
	"testing"
)

type historyView struct {
	Items []struct {
		ID       string `json:"id"`
		Query    string `json:"query"`
		Title    string `json:"title"`
		PhotoURL string `json:"photo_url"`
	} `json:"items"`
}

func TestSearchHistory(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	search(t, url.Values{"q": {"xe đạp"}}, bearer(me.AccessToken))
	search(t, url.Values{"q": {"Xe  Dap"}}, bearer(me.AccessToken))
	search(t, url.Values{"q": {"tủ lạnh"}}, bearer(me.AccessToken))

	res := call(t, "GET", "/v1/search/history", nil, bearer(me.AccessToken))
	h := decode[historyView](t, res)
	if res.Status != http.StatusOK || len(h.Items) != 2 || h.Items[0].Query != "tủ lạnh" || h.Items[1].Query != "Xe  Dap" {
		t.Fatalf("history: %d %s", res.Status, res.Body)
	}
	check(t, "forget one", call(t, "DELETE", "/v1/search/history/"+h.Items[0].ID, nil, bearer(me.AccessToken)), 204, "")
	check(t, "forget a bad id", call(t, "DELETE", "/v1/search/history/x", nil, bearer(me.AccessToken)), 400, "")
	check(t, "forget signed out", call(t, "DELETE", "/v1/search/history/"+h.Items[0].ID, nil), 401, "unauthenticated")
	check(t, "clear", call(t, "DELETE", "/v1/search/history", nil, bearer(me.AccessToken)), 204, "")
	check(t, "clear signed out", call(t, "DELETE", "/v1/search/history", nil), 401, "unauthenticated")
	check(t, "read signed out", call(t, "GET", "/v1/search/history", nil), 401, "unauthenticated")
	if h = decode[historyView](t, call(t, "GET", "/v1/search/history", nil, bearer(me.AccessToken))); len(h.Items) != 0 {
		t.Fatalf("after clear: %+v", h)
	}
}
```

The query "Xe  Dap" keeps its spaces as typed (the stored query is `strings.TrimSpace(q)`, which leaves inner spaces); if `search` in `e2e/search_test.go` returns other values, adapt the calls.

- [ ] **Step 10: Run the tests and commit**

Run: `go test ./internal/discovery/... ./internal/app/... && go test ./e2e/ -run 'TestSearchHistory|TestSearch|TestSaved'` then `make test`
Expected: PASS.

```bash
git add api internal/discovery internal/app/app.go go.mod go.sum .golangci.yml e2e/search_history_test.go ARCHITECTURE.md
git commit -m "feat(discovery): search history, kept by the first page of a text search, deleted one or all"
```

---

### Task 7: Feedback

**Files:**
- Create: `api/paths/support.yaml`, `api/schemas/support.yaml`
- Modify: `api/openapi.yaml` (paths), `api/paths/console.yaml`, `api/schemas/console.yaml`
- Create: `internal/support/support.go`, `internal/support/domain/feedback.go`, `internal/support/domain/errors.go`, `internal/support/repository/repository.go`, `internal/support/repository/feedback_pg.go`, `internal/support/service/service.go`, `internal/support/service/feedback_send.go`, `internal/support/service/feedback_list.go`, `internal/support/handler/handler.go`
- Modify: `internal/console/console.go`, `internal/console/handler/handler.go`, create `internal/console/handler/feedback.go`
- Modify: `internal/app/app.go`, `cmd/console` (if it calls `console.Mount` or `handler.New`), `.golangci.yml`
- Test: `internal/support/domain/feedback_test.go`, `internal/support/repository/feedback_pg_test.go`, `internal/support/service/feedback_test.go`, `e2e/feedback_test.go`

**Interfaces:**
- Consumes: `accountsvc.Service.Status`, `accountsvc.Service.GetMany`.
- Produces (domain): `MaxBodyRunes = 1000`, `DailyLimit = 10`, `Body(raw string) (string, error)`, `ErrInvalidFeedback` (`invalid_feedback`, 422), `ErrFeedbackLimit` (`feedback_limit_reached`, 429).
- Produces (repository): `type Row struct { ID, AccountID uuid.UUID; Body string; CreatedAt time.Time }`; `Feedback` interface: `Add(ctx, r Row, key uuid.UUID, since time.Time) (Row, error)`, `List(ctx, p page.Request) ([]Row, error)`.
- Produces (service): `Send(ctx, account, key uuid.UUID, body string) (FeedbackView, error)`, `Feedback(ctx, p page.Request) (page.Page[ConsoleFeedback], error)`; `FeedbackView{ID uuid.UUID; Body string; CreatedAt time.Time}`; `ConsoleFeedback{ID uuid.UUID; Body string; CreatedAt time.Time; Account FeedbackAccount}`; `FeedbackAccount{ID uuid.UUID; DisplayName string; Deleted bool}`.
- Produces: `support.Mount(d module.Deps, accounts accountsvc.Service) service.Service`; `console.Mount(d, s, accounts, feedback supportsvc.Service)`.

- [ ] **Step 1: Write the spec**

`api/schemas/support.yaml`:

```yaml
FeedbackCreate:
  type: object
  additionalProperties: false
  required: [body]
  properties:
    body:
      type: string
      description: 1 to 1000 characters after trimming; a business rule (invalid_feedback).
Feedback:
  type: object
  additionalProperties: false
  required: [id, body, created_at]
  properties:
    id:
      type: string
      format: uuid
    body:
      type: string
    created_at:
      type: string
      format: date-time
```

`api/paths/support.yaml`:

```yaml
feedback:
  post:
    operationId: sendFeedback
    summary: Send feedback to ShopNexus.
    description: |
      At most 10 per account in 24 hours. A repeated Idempotency-Key returns
      the feedback its first request added, also at the limit.
    tags: [support]
    security:
      - bearerAuth: []
    parameters:
      - $ref: "../parameters/common.yaml#/IdempotencyKey"
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/support.yaml#/FeedbackCreate"
    responses:
      "201":
        description: Sent.
        content:
          application/json:
            schema:
              $ref: "../schemas/support.yaml#/Feedback"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "403":
        description: "A suspension is in force (account_suspended)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: "Empty after trimming or over 1000 characters (invalid_feedback)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "429":
        description: "10 feedbacks in the last 24 hours (feedback_limit_reached)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

Use the Idempotency-Key parameter the address create operation uses (`grep -n Idempotency api/paths/address.yaml`); if it is inline, copy it. If the spec lists tags at the top of `openapi.yaml`, add `support`. Add `/v1/feedback` to `openapi.yaml`'s paths.

`api/schemas/console.yaml`:

```yaml
ConsoleFeedback:
  type: object
  additionalProperties: false
  required: [id, body, created_at, account]
  properties:
    id:
      type: string
      format: uuid
    body:
      type: string
    created_at:
      type: string
      format: date-time
    account:
      type: object
      additionalProperties: false
      required: [id, display_name, deleted]
      properties:
        id:
          type: string
          format: uuid
        display_name:
          type: string
        deleted:
          type: boolean
ConsoleFeedbackList:
  type: object
  additionalProperties: false
  required: [items]
  properties:
    items:
      type: array
      items:
        $ref: "#/ConsoleFeedback"
    next_cursor:
      type: string
```

Match the console's other list schemas (`grep -n "next_cursor" -B8 api/schemas/console.yaml`); if they share a page wrapper, use it. `api/paths/console.yaml` gains `feedback:` with `get:` (`operationId: listConsoleFeedback`), the same security, header parameter and responses (200, 400, 401, 403, 404 if the console routes document it) as `GET /v1/console/accounts`, response `ConsoleFeedbackList`, parameters `Cursor` and `Limit`. `openapi.yaml` gains `/v1/console/feedback`.

- [ ] **Step 2: Write the failing domain and repository tests**

`internal/support/domain/feedback_test.go`:

```go
package domain_test

import (
	"errors"
	"strings"
	"testing"

	"github.com/shopnexus/server/internal/support/domain"
)

func TestBody(t *testing.T) {
	t.Parallel()
	if b, err := domain.Body("  Ứng dụng chạy chậm  "); err != nil || b != "Ứng dụng chạy chậm" {
		t.Fatalf("trimmed: %q %v", b, err)
	}
	if _, err := domain.Body(strings.Repeat("ạ", 1000)); err != nil {
		t.Fatalf("1000 characters: %v", err)
	}
	for _, bad := range []string{"", "   ", strings.Repeat("ạ", 1001)} {
		if _, err := domain.Body(bad); !errors.Is(err, domain.ErrInvalidFeedback) {
			t.Errorf("%d characters: %v", len([]rune(bad)), err)
		}
	}
}
```

`internal/support/repository/feedback_pg_test.go`:

```go
package repository_test

import (
	"context"
	"errors"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server/internal/account/accounttest"
	"github.com/shopnexus/server/internal/platform/page"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server/internal/support/domain"
	"github.com/shopnexus/server/internal/support/repository"
)

func TestAdd(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewFeedback(db)
	account := accounttest.New(t, db)
	at := time.Date(2026, 11, 10, 9, 0, 0, 0, time.UTC)

	first := uuid.NewV7()
	r, err := s.Add(ctx, repository.Row{ID: uuid.NewV7(), AccountID: account, Body: "một", CreatedAt: at}, first, at.Add(-24*time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	again, err := s.Add(ctx, repository.Row{ID: uuid.NewV7(), AccountID: account, Body: "khác", CreatedAt: at}, first, at.Add(-24*time.Hour))
	if err != nil || again.ID != r.ID || again.Body != "một" {
		t.Fatalf("repeated key: %+v %v", again, err)
	}
	for i := range domain.DailyLimit - 1 {
		if _, err = s.Add(ctx, repository.Row{ID: uuid.NewV7(), AccountID: account, Body: "x", CreatedAt: at.Add(time.Duration(i) * time.Minute)},
			uuid.NewV7(), at.Add(-24*time.Hour)); err != nil {
			t.Fatalf("feedback %d: %v", i+2, err)
		}
	}
	if _, err = s.Add(ctx, repository.Row{ID: uuid.NewV7(), AccountID: account, Body: "x", CreatedAt: at}, uuid.NewV7(), at.Add(-24*time.Hour)); !errors.Is(err, domain.ErrFeedbackLimit) {
		t.Fatalf("eleventh: %v", err)
	}
	if again, err = s.Add(ctx, repository.Row{ID: uuid.NewV7(), AccountID: account, Body: "x", CreatedAt: at}, first, at.Add(-24*time.Hour)); err != nil || again.ID != r.ID {
		t.Fatalf("repeated key at the limit: %v", err)
	}
	if _, err = s.Add(ctx, repository.Row{ID: uuid.NewV7(), AccountID: account, Body: "x", CreatedAt: at.Add(25 * time.Hour)}, uuid.NewV7(), at.Add(time.Hour)); err != nil {
		t.Fatalf("a day later: %v", err)
	}
	rows, err := s.List(ctx, page.Request{})
	if err != nil || len(rows) == 0 || rows[0].CreatedAt.Before(rows[len(rows)-1].CreatedAt) {
		t.Fatalf("list: %v", err)
	}
}
```

If `accounttest.New`'s signature differs, read `internal/account/accounttest` and follow it. `pgtest.New` gives each test its own database, so `List` sees only this test's rows.

- [ ] **Step 3: Implement domain and repository**

`internal/support/domain/feedback.go`:

```go
// Package domain holds module support's rules: what a feedback may say and
// how many a person sends in a day.
package domain

import (
	"strings"
	"unicode/utf8"
)

const (
	// MaxBodyRunes is the longest feedback, as the app's counter shows.
	MaxBodyRunes = 1000
	// DailyLimit is how many feedbacks an account sends in 24 hours.
	DailyLimit = 10
)

// Body trims raw and checks its length.
func Body(raw string) (string, error) {
	b := strings.TrimSpace(raw)
	if n := utf8.RuneCountInString(b); n < 1 || n > MaxBodyRunes {
		return "", ErrInvalidFeedback.WithField("body", "1 to 1000 characters")
	}
	return b, nil
}
```

`internal/support/domain/errors.go`:

```go
package domain

import "github.com/shopnexus/server/internal/platform/apperr"

var (
	ErrInvalidFeedback = apperr.New(apperr.KindInvalid, "invalid_feedback", "a feedback is 1 to 1000 characters")
	ErrFeedbackLimit   = apperr.New(apperr.KindRateLimited, "feedback_limit_reached", "at most 10 feedbacks in 24 hours")
)
```

`internal/support/repository/repository.go`:

```go
// Package repository stores module support's feedback.
package repository

import (
	"context"
	"time"
	"uuid"

	"github.com/shopnexus/server/internal/platform/page"
)

// Row is one feedback.
type Row struct {
	ID        uuid.UUID
	AccountID uuid.UUID
	Body      string
	CreatedAt time.Time
}

// Feedback stores feedback.
type Feedback interface {
	// Add inserts r under the request's key, unless the account sent
	// domain.DailyLimit feedbacks after since (domain.ErrFeedbackLimit). A
	// key the account used already returns that request's row first, at
	// the limit too. The account is locked for the transaction.
	Add(ctx context.Context, r Row, key uuid.UUID, since time.Time) (Row, error)
	// List is a query: feedback with IDs below p.Before(), newest first, at
	// most p.Fetch().
	List(ctx context.Context, p page.Request) ([]Row, error)
}
```

`internal/support/repository/feedback_pg.go`:

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

	"github.com/shopnexus/server/internal/platform/page"
	"github.com/shopnexus/server/internal/support/domain"
)

type pgFeedback struct{ db *pgxpool.Pool }

func NewFeedback(db *pgxpool.Pool) Feedback { return pgFeedback{db} }

func (s pgFeedback) Add(ctx context.Context, r Row, key uuid.UUID, since time.Time) (Row, error) {
	out := r
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtext('feedback:' || @account::text))`,
			pgx.StrictNamedArgs{"account": r.AccountID}); err != nil {
			return fmt.Errorf("lock account: %w", err)
		}
		err := tx.QueryRow(ctx, `SELECT id, account_id, body, created_at FROM feedback
WHERE account_id = @account AND request_key = @key`, pgx.StrictNamedArgs{"account": r.AccountID, "key": key}).
			Scan(&out.ID, &out.AccountID, &out.Body, &out.CreatedAt)
		if err == nil {
			return nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("find key: %w", err)
		}
		var n int
		if err = tx.QueryRow(ctx, `SELECT count(*) FROM feedback WHERE account_id = @account AND created_at > @since`,
			pgx.StrictNamedArgs{"account": r.AccountID, "since": since}).Scan(&n); err != nil {
			return fmt.Errorf("count feedback: %w", err)
		}
		if n >= domain.DailyLimit {
			return domain.ErrFeedbackLimit
		}
		if _, err = tx.Exec(ctx, `INSERT INTO feedback (id, account_id, body, request_key, created_at)
VALUES (@id, @account, @body, @key, @at)`, pgx.StrictNamedArgs{
			"id": r.ID, "account": r.AccountID, "body": r.Body, "key": key, "at": r.CreatedAt,
		}); err != nil {
			return fmt.Errorf("insert feedback: %w", err)
		}
		return nil
	})
	if err != nil {
		return Row{}, fmt.Errorf("add feedback: %w", err)
	}
	return out, nil
}

func (s pgFeedback) List(ctx context.Context, p page.Request) ([]Row, error) {
	rows, err := s.db.Query(ctx, `SELECT id, account_id, body, created_at FROM feedback
WHERE id < @before ORDER BY id DESC LIMIT @limit`, pgx.StrictNamedArgs{"before": p.Before(), "limit": p.Fetch()})
	if err != nil {
		return nil, fmt.Errorf("select feedback: %w", err)
	}
	out, err := pgx.CollectRows(rows, pgx.RowToStructByPos[Row])
	if err != nil {
		return nil, fmt.Errorf("read feedback: %w", err)
	}
	return out, nil
}
```

The test's "a day later" case passes a `since` after the earlier rows, as the service will (`now - 24h`).

Run: `go test ./internal/support/...`
Expected: PASS for domain and repository.

- [ ] **Step 4: Write the failing service test**

`internal/support/service/feedback_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"testing"
	"time"
	"uuid"

	accountdomain "github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/account/accounttest"
	"github.com/shopnexus/server/internal/platform/page"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server/internal/support/domain"
	"github.com/shopnexus/server/internal/support/repository"
	"github.com/shopnexus/server/internal/support/service"
)

func TestSend(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	accounts := accounttest.Service(t, db)
	now := time.Now()
	svc := service.New(service.Deps{Feedback: repository.NewFeedback(db), Accounts: accounts, Now: func() time.Time { return now }})
	me := accounttest.New(t, db)

	key := uuid.NewV7()
	v, err := svc.Send(ctx, me, key, "  Ứng dụng chạy chậm ")
	if err != nil || v.Body != "Ứng dụng chạy chậm" {
		t.Fatalf("send: %+v %v", v, err)
	}
	if again, _ := svc.Send(ctx, me, key, "khác"); again.ID != v.ID {
		t.Fatalf("repeated key: %+v", again)
	}
	if _, err = svc.Send(ctx, me, uuid.NewV7(), " "); !errors.Is(err, domain.ErrInvalidFeedback) {
		t.Fatalf("blank: %v", err)
	}
	list, err := svc.Feedback(ctx, page.Request{})
	if err != nil || len(list.Items) != 1 || list.Items[0].Account.ID != me || list.Items[0].Account.DisplayName == "" {
		t.Fatalf("list: %+v %v", list, err)
	}

	suspended := accounttest.New(t, db)
	accounttest.Suspend(t, db, suspended)
	if _, err = svc.Send(ctx, suspended, uuid.NewV7(), "x"); !errors.Is(err, accountdomain.ErrSuspended) {
		t.Fatalf("suspended: %v", err)
	}
	if err = accounts.Erase(ctx, me); err != nil {
		t.Fatal(err)
	}
	if _, err = svc.Send(ctx, me, uuid.NewV7(), "x"); !errors.Is(err, accountdomain.ErrSessionRevoked) {
		t.Fatalf("deleted: %v", err)
	}
	if list, _ = svc.Feedback(ctx, page.Request{}); !list.Items[0].Account.Deleted || list.Items[0].Account.DisplayName != "" {
		t.Fatalf("a deleted author: %+v", list.Items[0].Account)
	}
}
```

Read `internal/account/accounttest` for `New`, `Service` and `Suspend`'s signatures and name of the display name it gives; adapt the calls.

- [ ] **Step 5: Implement the service, handler and mount**

`internal/support/service/service.go`:

```go
// Package service holds module support's use cases: a person sends
// feedback, and console members read it.
package service

import (
	"context"
	"time"
	"uuid"

	accountsvc "github.com/shopnexus/server/internal/account/service"
	"github.com/shopnexus/server/internal/platform/page"
	"github.com/shopnexus/server/internal/support/repository"
)

// Service is module support's contract.
type Service interface {
	// Send keeps a feedback of the account's under the request's key; a
	// repeated key returns the first one.
	Send(ctx context.Context, account, key uuid.UUID, body string) (FeedbackView, error)
	// Feedback lists every feedback, newest first, for console members.
	Feedback(ctx context.Context, p page.Request) (page.Page[ConsoleFeedback], error)
}

// FeedbackView is the Feedback schema.
type FeedbackView struct {
	ID        uuid.UUID `json:"id"`
	Body      string    `json:"body"`
	CreatedAt time.Time `json:"created_at"`
}

// ConsoleFeedback is the ConsoleFeedback schema.
type ConsoleFeedback struct {
	ID        uuid.UUID       `json:"id"`
	Body      string          `json:"body"`
	CreatedAt time.Time       `json:"created_at"`
	Account   FeedbackAccount `json:"account"`
}

// FeedbackAccount is who sent a feedback.
type FeedbackAccount struct {
	ID          uuid.UUID `json:"id"`
	DisplayName string    `json:"display_name"`
	Deleted     bool      `json:"deleted"`
}

// Deps is what New builds Support from.
type Deps struct {
	Feedback repository.Feedback
	Accounts accountsvc.Service
	Now      func() time.Time
}

// Support implements Service in this process.
type Support struct {
	feedback repository.Feedback
	accounts accountsvc.Service
	now      func() time.Time
}

var _ Service = (*Support)(nil)

func New(d Deps) *Support { return &Support{feedback: d.Feedback, accounts: d.Accounts, now: d.Now} }
```

`internal/support/service/feedback_send.go`:

```go
package service

import (
	"context"
	"fmt"
	"time"
	"uuid"

	"github.com/shopnexus/server/internal/support/domain"
	"github.com/shopnexus/server/internal/support/repository"
)

func (s *Support) Send(ctx context.Context, account, key uuid.UUID, body string) (FeedbackView, error) {
	status, err := s.accounts.Status(ctx, account)
	if err != nil {
		return FeedbackView{}, fmt.Errorf("read account status: %w", err)
	}
	if r := status.Refusal(); r != nil {
		return FeedbackView{}, r
	}
	b, err := domain.Body(body)
	if err != nil {
		return FeedbackView{}, err
	}
	now := s.now()
	r, err := s.feedback.Add(ctx, repository.Row{ID: uuid.NewV7(), AccountID: account, Body: b, CreatedAt: now}, key, now.Add(-24*time.Hour))
	if err != nil {
		return FeedbackView{}, fmt.Errorf("add feedback: %w", err)
	}
	return FeedbackView{ID: r.ID, Body: r.Body, CreatedAt: r.CreatedAt}, nil
}
```

`internal/support/service/feedback_list.go`:

```go
package service

import (
	"context"
	"fmt"
	"uuid"

	accountdomain "github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/platform/page"
)

func (s *Support) Feedback(ctx context.Context, p page.Request) (page.Page[ConsoleFeedback], error) {
	rows, err := s.feedback.List(ctx, p)
	if err != nil {
		return page.Page[ConsoleFeedback]{}, fmt.Errorf("list feedback: %w", err)
	}
	ids := make([]uuid.UUID, 0, len(rows))
	for _, r := range rows {
		ids = append(ids, r.AccountID)
	}
	people, err := s.accounts.GetMany(ctx, ids)
	if err != nil {
		return page.Page[ConsoleFeedback]{}, fmt.Errorf("read accounts: %w", err)
	}
	items := make([]ConsoleFeedback, 0, len(rows))
	for _, r := range rows {
		a := people[r.AccountID]
		items = append(items, ConsoleFeedback{
			ID: r.ID, Body: r.Body, CreatedAt: r.CreatedAt,
			Account: FeedbackAccount{ID: r.AccountID, DisplayName: a.DisplayName, Deleted: a.Status == accountdomain.StatusDeleted},
		})
	}
	return page.Of(items, p, func(f ConsoleFeedback) uuid.UUID { return f.ID }), nil
}
```

Read `page.Of`'s signature in `internal/platform/page` and match it.

`internal/support/handler/handler.go`:

```go
// Package handler serves module support's HTTP API.
package handler

import (
	"log/slog"
	"net/http"
	"uuid"

	"github.com/shopnexus/server/internal/platform/httpx"
	"github.com/shopnexus/server/internal/support/service"
)

type Handler struct {
	svc service.Service
	log *slog.Logger
}

func New(svc service.Service, log *slog.Logger) *Handler { return &Handler{svc: svc, log: log} }

// Register adds POST /v1/feedback behind protect. Console members read
// feedback through console's handler.
func (h *Handler) Register(r *httpx.Router, protect func(http.Handler) http.Handler) {
	r.Handle("POST /v1/feedback", protect(http.HandlerFunc(h.Send)))
}

type sendRequest struct {
	Key  uuid.UUID `header:"Idempotency-Key" json:"-"`
	Body string    `json:"body"`
}

// Send serves POST /v1/feedback.
func (h *Handler) Send(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in sendRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	out, err := h.svc.Send(r.Context(), p.AccountID, in.Key, in.Body)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusCreated, out)
}
```

`internal/support/support.go`:

```go
// Package support holds what people send to ShopNexus: feedback, read by
// console members through console's API.
package support

import (
	accountsvc "github.com/shopnexus/server/internal/account/service"
	"github.com/shopnexus/server/internal/platform/module"
	"github.com/shopnexus/server/internal/support/handler"
	"github.com/shopnexus/server/internal/support/repository"
	"github.com/shopnexus/server/internal/support/service"
)

// Mount registers POST /v1/feedback and returns the Service console reads
// feedback through.
func Mount(d module.Deps, accounts accountsvc.Service) service.Service {
	svc := service.New(service.Deps{Feedback: repository.NewFeedback(d.Pool), Accounts: accounts, Now: d.Now})
	handler.New(svc, d.Log).Register(d.Router, d.Protect)
	return svc
}
```

Console: `console.Mount(d module.Deps, s Settings, accounts accountsvc.Service, feedback supportsvc.Service)`; `handler.New` gains a `feedback supportsvc.Service` argument kept on `Handler`; `Register` adds `handle("GET /v1/console/feedback", mod(http.HandlerFunc(h.ListFeedback)))` beside the accounts routes. `internal/console/handler/feedback.go`:

```go
package handler

import (
	"net/http"

	"github.com/shopnexus/server/internal/platform/httpx"
	"github.com/shopnexus/server/internal/platform/page"
)

// ListFeedback serves GET /v1/console/feedback.
func (h *Handler) ListFeedback(w http.ResponseWriter, r *http.Request) {
	var in page.Request
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	out, err := h.feedback.Feedback(r.Context(), in)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, out)
}
```

Every caller of `handler.New` and `console.Mount` (`grep -rn "handler.New(\|console.Mount(" internal cmd e2e`) passes the support service, or `nil` where it serves no feedback (`cmd/console`). In `internal/app/app.go`: `feedback := support.Mount(d, accounts)` after `accounts := accountm.Service`, then `console.Mount(d, ..., accounts, feedback)`. Run `make depguard` (new module support).

- [ ] **Step 6: Write the e2e test**

`e2e/feedback_test.go`:

```go
package e2e

import (
	"strings"
	"testing"

	consoledomain "github.com/shopnexus/server/internal/console/domain"
)

func TestFeedback(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	key := newKey()
	res := call(t, "POST", "/v1/feedback", map[string]any{"body": "Ứng dụng chạy chậm"}, bearer(me.AccessToken), key)
	if res.Status != 201 {
		t.Fatalf("send: %d %s", res.Status, res.Body)
	}
	check(t, "repeat", call(t, "POST", "/v1/feedback", map[string]any{"body": "khác"}, bearer(me.AccessToken), key), 201, "")
	check(t, "blank", call(t, "POST", "/v1/feedback", map[string]any{"body": "  "}, bearer(me.AccessToken), newKey()), 422, "invalid_feedback")
	check(t, "too long", call(t, "POST", "/v1/feedback", map[string]any{"body": strings.Repeat("a", 1001)}, bearer(me.AccessToken), newKey()), 422, "invalid_feedback")
	check(t, "no key", call(t, "POST", "/v1/feedback", map[string]any{"body": "x"}, bearer(me.AccessToken)), 400, "")
	check(t, "signed out", call(t, "POST", "/v1/feedback", map[string]any{"body": "x"}, newKey()), 401, "unauthenticated")
	for range 9 {
		expectStatus(t, call(t, "POST", "/v1/feedback", map[string]any{"body": "x"}, bearer(me.AccessToken), newKey()), 201)
	}
	check(t, "limit", call(t, "POST", "/v1/feedback", map[string]any{"body": "x"}, bearer(me.AccessToken), newKey()), 429, "feedback_limit_reached")

	suspended, _ := newAccount(t)
	suspend(t, suspended.AccountID)
	check(t, "suspended", call(t, "POST", "/v1/feedback", map[string]any{"body": "x"}, bearer(suspended.AccessToken), newKey()), 403, "account_suspended")

	mod := signInMember(t, consoledomain.RoleModerator)
	if res = consoleCall(t, mod, "GET", "/v1/console/feedback", nil); res.Status != 200 || !strings.Contains(res.Body, "Ứng dụng chạy chậm") {
		t.Fatalf("console list: %d %s", res.Status, res.Body)
	}
	check(t, "console bad cursor", consoleCall(t, mod, "GET", "/v1/console/feedback?cursor=x", nil), 400, "")
	check(t, "console signed out", call(t, "GET", "/v1/console/feedback", nil, [2]string{"X-Requested-With", "shopnexus-console"}), 401, "unauthenticated")
}
```

Read `console_accounts_test.go` for how it observes the console route's 403 (no header, or a member below the floor) and add the same calls for `/v1/console/feedback`; the coverage check needs every status `listConsoleFeedback` documents. Use the role constant name `consoledomain` defines. If `res.Body` is `[]byte`, wrap with `string(...)`.

- [ ] **Step 7: Run the tests and commit**

Run: `go test ./internal/support/... ./internal/console/... ./internal/app/... && go test ./e2e/ -run 'TestFeedback|TestConsole'` then `make test`
Expected: PASS.

```bash
git add api internal/support internal/console internal/app/app.go cmd e2e/feedback_test.go .golangci.yml
git commit -m "feat(support): POST /v1/feedback, ten a day per account, and GET /v1/console/feedback"
```

---

### Task 8: Deleted people in other answers

**Files:**
- Modify: `internal/chat/service/message_send_durable.go`, `internal/chat/service/views.go`, `internal/chat/service/conversation_get.go`
- Modify: `internal/trust/service/views.go`
- Modify: `api/schemas/chat.yaml` (`Person`), `api/schemas/trust.yaml` (review `buyer`), `api/paths/chat.yaml` (send message 409)
- Test: `internal/chat/service/*_test.go`, `e2e/erasure_test.go`

**Interfaces:**
- Consumes: `accountsvc.Service.Status`, `accountdomain.StatusDeleted`, `accountdomain.ErrAccountDeleted`.
- Produces: chat `PersonView.Deleted bool` (`json:"deleted"`); trust `Person.Deleted bool` (`json:"deleted"`).

- [ ] **Step 1: Write the spec**

`api/schemas/chat.yaml`, `Person`: `required: [id, display_name, deleted]` and

```yaml
    deleted:
      type: boolean
      description: The person deleted their account; display_name is empty and there is no avatar.
```

`api/schemas/trust.yaml`, the review's `buyer`: the same property, added to `required`. `api/paths/chat.yaml`: the operation that sends a message in a conversation (`POST /v1/conversations/{id}/messages`) documents in its 409 description `the other person deleted their account (account_deleted)`; if it has no 409, add one with the `Error` schema.

- [ ] **Step 2: Write the failing chat test**

In the chat service tests (find the reply test with `grep -n "func Test.*Send\|func Test.*Reply" internal/chat/service/*_test.go`), add one in its style: two accounts with a conversation, the other erased (`accounts.Erase`), then a reply answers `accountdomain.ErrAccountDeleted`, and the conversation's view has `Other.Deleted == true` and `Other.DisplayName == ""`.

- [ ] **Step 3: Implement**

`message_send_durable.go`: `facts` gains `OtherDeleted bool \`json:"other_deleted"\``. In the step, after the block check for `other`:

```go
			otherStatus, statusErr := s.Chat.accounts.Status(rc, other)
			if statusErr != nil {
				return facts{}, fmt.Errorf("read the other's status: %w", statusErr)
			}
			out.OtherDeleted = otherStatus == accountdomain.StatusDeleted
```

and in the refusal switch, after the caller's own status case and before the listing cases:

```go
	case f.OtherDeleted:
		refused = accountdomain.ErrAccountDeleted
```

`views.go`: `PersonView` gains `Deleted bool \`json:"deleted"\``. `conversation_get.go` (both places building `PersonView`) sets `Deleted: other.Status == accountdomain.StatusDeleted`. Grep for any other `PersonView{` in chat and set it there too.

`internal/trust/service/views.go`: `Person` gains `Deleted bool \`json:"deleted"\``, set at line 85's construction from `buyer.Status == accountdomain.StatusDeleted`.

- [ ] **Step 4: Extend the e2e test**

In `e2e/erasure_test.go`, add:

```go
func TestDeletedAccountInOthersViews(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	conv := openChat(t, buyer.AccessToken, l.ID, "Còn hàng không?")

	check(t, "delete", call(t, "DELETE", "/v1/accounts/me", nil, bearer(seller.AccessToken)), 204, "")
	check(t, "reply to a deleted account",
		call(t, "POST", "/v1/conversations/"+conv.ID+"/messages", map[string]any{"text": "Alo?"}, bearer(buyer.AccessToken), newKey()),
		409, "account_deleted")
	check(t, "follow a deleted account", call(t, "PUT", "/v1/follows/"+seller.AccountID, nil, bearer(buyer.AccessToken)), 409, "account_deleted")
	check(t, "the deleted seller's page", call(t, "GET", "/v1/screens/seller/"+seller.AccountID, nil), 404, "")
	check(t, "a write with the deleted account's token",
		call(t, "POST", "/v1/feedback", map[string]any{"body": "x"}, bearer(seller.AccessToken), newKey()), 401, "session_revoked")
	rows := inboxRows(t, buyer.AccessToken)
	if row, ok := rows[conv.ID]; !ok || !row.Other.Deleted {
		t.Fatalf("inbox row: %+v", row)
	}
}
```

Adapt to the helpers' real fields (`conv.ID`, the message body key, `inboxRow`'s person field) and add `Deleted bool \`json:"deleted"\`` to the e2e struct that decodes a `Person`. `GET /v1/screens/seller/{id}` answers 404 because the seller's profile reads the account and screen's seller view refuses a deleted one: if it does not yet, make `screen/service/seller.go` answer `accountdomain.ErrAccountNotFound` when `seller.Status == accountdomain.StatusDeleted`, and the same in `GET /v1/sellers/{id}/listings` if that handler reads the account (spec: both 404). Add a service test for the screen case beside `seller_test.go`'s.

- [ ] **Step 5: Run the tests and commit**

Run: `go test ./internal/chat/... ./internal/trust/... ./internal/screen/... && go test ./e2e/ -run 'TestDeleted|TestChat|TestReview|TestScreenSeller|TestInbox'` then `make test`
Expected: PASS, and `uncovered()` empty.

```bash
git add api internal/chat internal/trust internal/screen e2e
git commit -m "feat(chat, trust): a deleted person shows as deleted, and a reply to one is account_deleted"
```

---

### Task 9: Architecture, checklist and the umbrella

**Files:**
- Modify: `~/shopnexus/server/ARCHITECTURE.md`
- Modify: `~/shopnexus/checklist.md`
- Modify: `~/shopnexus` (submodule pointers of `server` and `docs`)

- [ ] **Step 1: Record the decisions in ARCHITECTURE.md**

Load the `humanizing-writing` skill first (ARCHITECTURE.md is documentation) and run its checker on the new text. Add, in the Decided part:

- A section `### Erasure`: the decisions table of the spec in prose (open orders, suspension, re-authentication, the tombstone, what each module clears on `account.deleted`, the 365-day recipient blanking by `DealAccountWatch.Scrub`, the accepted COD race, a deleted caller's token answering `session_revoked`, `account_deleted` for replies and follows), with the spec's path.
- In `### Aggregates in account`: `Erase` is the second transaction over more than one aggregate, beside sign-up, and why.
- In `### Tables and aggregates`: rows for `feedback` (module support) and `search_history` (module discovery).
- A section `### Support`: feedback, its cap and key, the console route living in console.
- In `### Discovery`: the search history (who writes it, the fold, the cap, the three endpoints, a failed write logged).
- In `### Module layout`: modules erasure and support, which return what, catalog and discovery gaining `worker`.

- [ ] **Step 2: Tick the checklist**

In `~/shopnexus/checklist.md`:

```markdown
- [x] Lịch sử tìm kiếm (lưu, xoá)
```

```markdown
- [x] Xoá tài khoản
- [x] Gửi góp ý
```

and change the date line to the day the work lands.

- [ ] **Step 3: Commit**

```bash
cd ~/shopnexus/server
git add ARCHITECTURE.md
git commit -m "docs: erasure, support and search history in the architecture"
cd ~/shopnexus
git add checklist.md server docs
git commit -m "chore: account deletion, feedback and search history land; submodules follow"
```

Before the umbrella commit, check `git -C ~/shopnexus status` and `git -C ~/shopnexus diff --submodule` so it records only the `server` and `docs` pointers and the checklist; `website` showed changes at the start that are not this work and stay out of the commit.
