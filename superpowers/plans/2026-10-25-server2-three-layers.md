# server2 three layers: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split modules account, auth and staff of server2 into `domain`, `repository`, `service` and `handler` packages, with no change to the API, the migrations or the behaviour.

**Architecture:** Each module gets four packages and a root file with `Mount`. Imports run `handler` → `service` → `repository` → `domain`. A module's `service.Service` interface is what its handlers and other modules call; `*service.Account`, `*service.Auth` and `*service.Staff` implement it in process. Only OTP sending and OTP sign-in stay on Restate, behind `restatex.Caller`.

**Tech Stack:** Go 1.27, pgx v5, Restate Go SDK, golangci-lint v2 (depguard).

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-10-25-server2-three-layers-design.md`

## Global Constraints

- The OpenAPI spec in `api/`, the migrations and every HTTP status, error code and body stay as they are.
- e2e test bodies do not change; only their helpers' imports and constructors do.
- A use case is one method that reads top to bottom; a helper exists only when several places call it (CLAUDE.md).
- Configuration has no defaults; nothing in this plan adds a variable.
- Scratch output goes in `tmp/`.
- Code comments and docs go through the humanizing-writing skill and its checker.
- No commits unless the user asks; each task ends on a green `make test` instead.
- Restate service names stay `OTP` and `SignIn`, with the prefix.

## Review Focus

1. A handler, domain or repository file that imports a layer above it: `golangci-lint` must refuse it (Task 8 adds depguard rules).
2. A repository `Save` that writes the row but leaves the entity's old write ID: the next `Save` of the same entity must succeed (each repository task adds a save-twice test).
3. A replayed `POST /v1/auth/otp/verify` with another challenge or code: it must get `code_expired`, as today (the check moves into `Auth.SignIn`; `e2e/auth_otp_test.go` covers it).
4. A refusal from a Restate service: the handler must get its `code` and `details`, `retry_after` included (Task 1 tests `Caller`).
5. `go run ./cmd/staff ...` with the server stopped: it must still work (Task 7 keeps `cmd/staff` in process; `cmd/staff/main_test.go` covers it).

## Entities across packages

Today a store reads an entity's unexported fields because both live in one
package. After the split the repository is another package, so every entity
gets:

- `Restore<Entity>(...)`, which rebuilds a stored entity ("Stores only."), as
  `otp.Restore` and `otp.RestoreQuota` already do;
- a getter for every stored field it lacks (for an account, `StoredStatus()`,
  the status as stored, which `Status(now)` may read as active);
- `Saved(writeID uuid.UUID)`, which a repository calls after a successful
  write ("Stores only."), in place of `a.writeID = writeID`.

---

### Task 1: restatex.Caller and Result

**Files:**
- Create: `internal/platform/restatex/caller.go`
- Test: `internal/platform/restatex/caller_test.go`

**Interfaces:**
- Produces:
  ```go
  // Result is what a Restate service returns: a refusal travels as data,
  // because Restate retries an error and its ingress keeps only the message
  // of a terminal one.
  type Result[O any] struct {
      Value   O             `json:"value"`
      Refused *apperr.Error `json:"refused,omitempty"`
  }

  type Caller[I, O any] struct {
      Ingress *ingress.Client
      Service string // with the prefix
      Handler string
  }

  func (c Caller[I, O]) Call(ctx context.Context, idempotencyKey string, in I) (O, error)
  ```

- [ ] **Step 1: Branch.** `git switch -c three-layers` from main.

- [ ] **Step 2: Write the failing test** in `caller_test.go` (package `restatex_test`). Register a test service whose handler returns `Result[string]{Value: "ok"}` for input `"ok"` and `Result[string]{Refused: apperr.New(apperr.KindRateLimited, "otp_limit", "x").WithDetail("retry_after", 7)}` otherwise; start it with `restatetest.Start`.

  ```go
  type echo struct{ prefix string }

  func (e echo) ServiceName() string { return e.prefix + "Echo" }

  func (echo) Run(_ restate.Context, in string) (restatex.Result[string], error) {
      if in == "ok" {
          return restatex.Result[string]{Value: "ok"}, nil
      }
      return restatex.Result[string]{Refused: apperr.New(apperr.KindRateLimited, "otp_limit", "x").WithDetail("retry_after", 7)}, nil
  }

  func TestCallerReturnsTheRefusal(t *testing.T) {
      t.Parallel()
      p := restatetest.Prefix()
      in := restatetest.Start(t, restate.Reflect(echo{prefix: p}))
      c := restatex.Caller[string, string]{Ingress: in, Service: p + "Echo", Handler: "Run"}
      if v, err := c.Call(t.Context(), uuid.NewV7().String(), "ok"); err != nil || v != "ok" {
          t.Fatalf("ok: %q %v", v, err)
      }
      _, err := c.Call(t.Context(), uuid.NewV7().String(), "no")
      e, ok := errors.AsType[*apperr.Error](err)
      if !ok || e.Code != "otp_limit" || e.Details["retry_after"] != float64(7) {
          t.Fatalf("refusal: %#v", err)
      }
  }
  ```

  Check `apperr.Error`'s field names in `internal/platform/apperr/apperr.go` and how a decoded `details` number arrives (JSON gives `float64`) before fixing the assertion.

- [ ] **Step 3: Run it.** `go test ./internal/platform/restatex/ -run TestCallerReturnsTheRefusal` fails: `restatex.Caller` undefined.

- [ ] **Step 4: Implement** `caller.go`:

  ```go
  func (c Caller[I, O]) Call(ctx context.Context, idempotencyKey string, in I) (O, error) {
      ctx, cancel := context.WithTimeout(ctx, CallTimeout)
      defer cancel()
      res, err := ingress.Service[I, Result[O]](c.Ingress, c.Service, c.Handler).
          Request(ctx, in, restate.WithIdempotencyKey(idempotencyKey))
      if err != nil {
          var zero O
          return zero, fmt.Errorf("call %s/%s: %w", c.Service, c.Handler, err)
      }
      if res.Refused != nil {
          return res.Value, res.Refused
      }
      return res.Value, nil
  }
  ```

- [ ] **Step 5: Run it.** The test passes; `golangci-lint run ./internal/platform/restatex/` reports nothing.

### Task 2: module account

**Files:**
- Create: `internal/account/domain/account.go`, `domain/errors.go`, `domain/account_test.go`
- Create: `internal/account/repository/account.go`, `repository/errors.go`, `repository/account_pg.go`, `repository/account_pg_test.go`
- Create: `internal/account/service/service.go`, `service/views.go`, `service/account_create.go`, `service/account_delete.go`, `service/account_get.go`, `service/account_record.go`, `service/account_rename.go`, `service/account_suspend.go`, and their tests
- Create: `internal/account/handler/handler.go`, `handler/account_get.go`, `handler/account_rename.go`
- Rename: `internal/account/mount.go` → `internal/account/account.go`
- Delete: `internal/account/client.go`, `client_test.go`, `errors.go`, `account_store*.go`, every use case file at the root
- Modify: `internal/auth/accounts.go`, `internal/auth/sign_in_service.go`, `internal/auth/session_refresh.go`, `internal/staff/ports.go`, `internal/staff/account_*.go`, `internal/app/app.go`, their tests

**Interfaces:**
- Produces, package `github.com/shopnexus/server2/internal/account/domain`:
  `Status`, `StatusActive`, `StatusSuspended`, `Account`, `New(id, displayName, now) (Account, error)`,
  `RestoreAccount(id uuid.UUID, displayName string, status Status, suspendedUntil *time.Time, suspendReason string, writeID uuid.UUID, createdAt, updatedAt time.Time) Account`,
  the getters of today plus `StoredStatus() Status`, `Saved(writeID uuid.UUID)`,
  `ErrSuspended`, `ErrInvalidName`, `ErrSuspendReason`, `ErrSuspendUntil`.
- Produces, package `.../account/repository`:
  ```go
  var (
      ErrNotFound = apperr.New(apperr.KindNotFound, "account_not_found", "account not found")
      ErrConflict = errors.New("account: changed meanwhile")
  )
  type Accounts interface { // the methods and comments of today's account.Store
      Create(ctx context.Context, a domain.Account) error
      Get(ctx context.Context, id uuid.UUID) (domain.Account, error)
      Save(ctx context.Context, a *domain.Account, writeID uuid.UUID) error
      SaveAudited(ctx context.Context, a *domain.Account, writeID uuid.UUID, e audit.Entry) error
      List(ctx context.Context, p page.Request) ([]domain.Account, error)
      Delete(ctx context.Context, id uuid.UUID) error
  }
  func NewAccounts(db *pgxpool.Pool) Accounts
  ```
- Produces, package `.../account/service`:
  ```go
  type Service interface {
      Get(ctx context.Context, id uuid.UUID) (AccountView, error)
      Rename(ctx context.Context, id uuid.UUID, name string) (AccountView, error)
      Create(ctx context.Context, id uuid.UUID, displayName string) error
      Delete(ctx context.Context, id uuid.UUID) error
      Status(ctx context.Context, id uuid.UUID) (domain.Status, error)
      Record(ctx context.Context, id uuid.UUID) (Record, error)
      Records(ctx context.Context, p page.Request) ([]Record, error)
      Suspend(ctx context.Context, in SuspendInput) (Record, error)
      Reinstate(ctx context.Context, id uuid.UUID, by audit.Actor) (Record, error)
  }
  type Account struct{ accounts repository.Accounts; now func() time.Time }
  func New(accounts repository.Accounts, now func() time.Time) *Account
  type AccountView struct { /* today's account.View */ }
  type Record struct { /* today's account.Record */ }
  type SuspendInput struct {
      ID     uuid.UUID
      Reason string
      Until  *time.Time
      By     audit.Actor
  }
  ```
- Produces, package `.../account/handler`: `type Handler`, `New(svc service.Service, log *slog.Logger) *Handler`, `(*Handler).Register(r *httpx.Router, protect func(http.Handler) http.Handler)`, methods `GetMe` and `Rename`.
- Produces, package `account`: `Mount(d module.Deps, protect func(http.Handler) http.Handler) service.Service`.

- [ ] **Step 1: Move the tests first.** `git mv` each test to its new package and change its package clause: `account_test.go` → `domain/account_test.go` (package `domain_test`), `account_store_pg_test.go` → `repository/account_pg_test.go` (package `repository_test`), `account_create_test.go`, `account_get_test.go`, `account_rename_test.go`, `account_suspend_test.go` → `service/` (package `service_test`). Fold `client_test.go` into `service/account_get_test.go` and `service/account_record_test.go`: what it tests through `account.Client` it now tests through `*service.Account`. Rewrite each call site: `account.Rename(ctx, st, id, name, now)` becomes `service.New(repository.NewAccounts(db), func() time.Time { return now }).Rename(ctx, id, name)`; one `newService(t)` helper per test package builds it.

- [ ] **Step 2: Add the save-twice test** to `repository/account_pg_test.go`:

  ```go
  // Save leaves the account carrying the write ID it wrote, so saving it again
  // succeeds.
  func TestSaveTwice(t *testing.T) {
      t.Parallel()
      st := repository.NewAccounts(pgtest.New(t))
      ctx := context.Background()
      a, _ := domain.New(uuid.NewV7(), "Bean", now)
      if err := st.Create(ctx, a); err != nil {
          t.Fatal(err)
      }
      for _, name := range []string{"One", "Two"} {
          if err := a.SetDisplayName(name, now); err != nil {
              t.Fatal(err)
          }
          if err := st.Save(ctx, &a, uuid.NewV7()); err != nil {
              t.Fatalf("save %s: %v", name, err)
          }
      }
  }
  ```

- [ ] **Step 3: Run.** `go test ./internal/account/...` fails to compile: packages `domain`, `repository`, `service` do not exist.

- [ ] **Step 4: Domain.** `git mv internal/account/account.go internal/account/domain/account.go`; package `domain`; package comment "Package domain holds the account entity and its rules."; add `RestoreAccount`, `StoredStatus` and `Saved` as in "Entities across packages". Move `ErrSuspended`, `ErrInvalidName`, `ErrSuspendReason`, `ErrSuspendUntil` to `domain/errors.go`.

- [ ] **Step 5: Repository.** `git mv account_store.go repository/account.go`, `account_store_pg.go repository/account_pg.go`; package `repository`; `Store` → `Accounts`, `pgStore` → `pgAccounts`, `NewPGStore` → `NewAccounts`; `ErrNotFound` and `ErrConflict` to `repository/errors.go`. Every read of `a.id`, `a.displayName`, ... becomes a getter (`a.StoredStatus()` for the status); every scan goes into locals and ends in `domain.RestoreAccount(...)`; `a.writeID = writeID` becomes `a.Saved(writeID)`.

- [ ] **Step 6: Service.** Write `service/service.go` with `Service`, `Account`, `New` and `var _ Service = (*Account)(nil)`. Move `View` (renamed `AccountView`), `viewOf`, `Record`, `recordOf` and `SuspendInput` to `service/views.go`. Turn each use case into a method on `*Account` in the file of the same name, body unchanged except: `accounts` → `s.accounts`, the `now` parameter → `now := s.now()` on the first line, `account.X` → `domain.X` or `repository.X`. `account_get.go` holds `Get` and `Status` (today's `StatusOf`); `account_record.go` holds `Record` (today's `GetRecord`) and `Records`; `account_delete.go` holds `Delete` (today's `Client.Delete`). `Suspend` takes `SuspendInput`.

- [ ] **Step 7: Handler.** `handler/handler.go`:

  ```go
  // Package handler serves module account's HTTP API.
  package handler

  type Handler struct {
      svc service.Service
      log *slog.Logger
  }

  func New(svc service.Service, log *slog.Logger) *Handler { return &Handler{svc: svc, log: log} }

  func (h *Handler) Register(r *httpx.Router, protect func(http.Handler) http.Handler) {
      r.Handle("GET /v1/accounts/me", protect(http.HandlerFunc(h.GetMe)))
      r.Handle("PATCH /v1/accounts/me", protect(http.HandlerFunc(h.Rename)))
  }
  ```

  `handler/account_get.go` holds `GetMe`, `handler/account_rename.go` holds `renameRequest` and `Rename`, each the body of today's `GetHandler` and `RenameHandler` with `Get(...)`/`Rename(...)` replaced by `h.svc.Get(r.Context(), p.AccountID)` and `h.svc.Rename(r.Context(), p.AccountID, in.DisplayName)`.

- [ ] **Step 8: Mount.** `git mv mount.go account.go`:

  ```go
  // Package account owns who a person is: display name, status and
  // suspension. It knows nothing about signing in; package auth does.
  package account

  // Mount registers the account endpoints behind protect, which requires a
  // signed-in caller, and returns the Service other modules call.
  func Mount(d module.Deps, protect func(http.Handler) http.Handler) service.Service {
      svc := service.New(repository.NewAccounts(d.Pool), d.Now)
      handler.New(svc, d.Log).Register(d.Router, protect)
      return svc
  }
  ```

  Delete `client.go`.

- [ ] **Step 9: Callers.** In `internal/auth/accounts.go` `account.Status` → `accountdomain.Status`. In `sign_in_service.go` and `session_refresh.go` `account.StatusSuspended`, `account.ErrSuspended` → `accountdomain.…`. In `internal/staff/ports.go` `account.Record` → `accountsvc.Record`, and `Suspend` takes `accountsvc.SuspendInput`; update `staff/account_suspend.go` and `staff/account_list.go`, `staff/account_get.go` to match. Import aliases: `accountdomain`, `accountsvc`.

- [ ] **Step 10: Run.** `make test` passes; lint reports 0 issues.

### Task 3: auth domain and repository

**Files:**
- Create: `internal/auth/domain/` from `otp/challenge.go`, `otp/quota.go`, `otp/codes.go`, `credentials/credentials.go`, `session/session.go`, `session/token.go`, plus `domain/errors.go`; their tests (`challenge_test.go`, `quota_test.go`, `codes_test.go`, `exercise_test.go`, `credentials_test.go`, `session_test.go`, `token_test.go`)
- Create: `internal/auth/repository/` from the three packages' `*_store.go` and `*_store_pg.go` as `challenge.go`, `challenge_pg.go`, `quota.go`, `quota_pg.go`, `credentials.go`, `credentials_pg.go`, `session.go`, `session_pg.go`, plus `errors.go`; their `_pg_test.go`
- Delete: `internal/auth/otp/`, `internal/auth/credentials/`, `internal/auth/session/`
- Modify: every file in `internal/auth/` that imports them, `e2e/accounts_test.go`, `e2e/auth_session_test.go`

**Interfaces:**
- Produces, package `.../auth/domain`. Names that collide once the three packages merge are renamed:

  | Today | After |
  |---|---|
  | `otp.New`, `otp.Restore` | `NewChallenge`, `RestoreChallenge` |
  | `otp.NewQuota`, `otp.RestoreQuota`, `otp.Rule` | unchanged names |
  | `otp.Purpose`, `otp.PurposeLogin`, `otp.CodeTTL`, `otp.MaxAttempts`, `otp.Codes`, `otp.NewCodes` | unchanged names |
  | `credentials.New` | `NewCredentials` |
  | `credentials.Kind`, `KindOf`, `Identity`, `IdentityRef`, `NewIdentity`, `ErrTaken` | unchanged names |
  | `session.New`, `session.Session`, `Tokens`, `Signer`, `NewSigner`, `Verifier`, `NewVerifier`, `NewRefreshToken`, `HashRefresh` | `NewSession`, the rest unchanged |
  | `otp.ErrInvalidCode`, `ErrCodeExpired`, `ErrCodeLocked`, `session.ErrInvalidRefresh`, `ErrRevoked`, `ErrExpired`, `ErrInvalidToken` | unchanged names, in `domain/errors.go` |

  New: `RestoreCredentials(accountID uuid.UUID, identities []Identity, writeID uuid.UUID, updatedAt time.Time) Credentials`, `RestoreIdentity(id uuid.UUID, kind Kind, value string, lastUsedAt *time.Time, createdAt time.Time) Identity`, `RestoreSession(...)` with every stored field in the order of the `sessions` columns, and `Saved(writeID uuid.UUID)` on `Challenge`, `Quota`, `Credentials` and `Session`. Read each store's scan to fix the exact parameter lists.
- Produces, package `.../auth/repository`:
  ```go
  var (
      ErrNotFound = errors.New("auth: not found")
      ErrConflict = errors.New("auth: changed meanwhile")
  )
  type Challenges interface { /* otp.ChallengeStore's methods */ }
  type Quotas interface { /* otp.QuotaStore's methods */ }
  type Credentials interface { /* credentials.Store's methods */ }
  type Sessions interface { /* session.Store's methods */ }
  func NewChallenges(db *pgxpool.Pool) Challenges
  func NewQuotas(db *pgxpool.Pool) Quotas
  func NewCredentials(db *pgxpool.Pool) Credentials
  func NewSessions(db *pgxpool.Pool) Sessions
  ```
  `ErrTaken` stays in `domain`; `Credentials.Create` returns it.

- [ ] **Step 1: Move the tests first**, as in Task 2: entity tests to `domain/` (package `domain_test`), store tests to `repository/` (package `repository_test`), with the renamed constructors.

- [ ] **Step 2: Add a save-twice test** to each of `repository/challenge_pg_test.go`, `quota_pg_test.go`, `credentials_pg_test.go`, `session_pg_test.go`, shaped like Task 2's: change the entity with one of its methods (`Verify` with a wrong code, `Admit`, `MarkUsed`, `Rotate`), save, change it again, save again; both saves succeed.

- [ ] **Step 3: Run.** `go test ./internal/auth/...` fails to compile.

- [ ] **Step 4: Domain.** `git mv` the six entity files into `domain/`; package `domain`; apply the renames; add the `Restore…` functions, the missing getters and `Saved`; move the errors to `domain/errors.go`. Drop `otp.ErrNotFound`, `otp.ErrConflict`, `credentials.ErrNotFound`, `credentials.ErrConflict`, `session.ErrNotFound`, `session.ErrConflict`; they become `repository.ErrNotFound` and `repository.ErrConflict`.

- [ ] **Step 5: Repository.** `git mv` the store files into `repository/`; package `repository`; rename the interfaces and constructors as above; reads through getters, scans through `Restore…`, `x.writeID = w` through `x.Saved(w)`.

- [ ] **Step 6: Callers.** Update every import in `internal/auth/*.go` (`otp.`, `credentials.`, `session.` → `domain.` or `repository.`) and in `e2e/accounts_test.go` and `e2e/auth_session_test.go` (`session.New` → `authdomain.NewSession`, `session.NewSigner` → `authdomain.NewSigner`, `session.NewVerifier` → `authdomain.NewVerifier`). `restatex.Outcome(err, otp.ErrConflict)` becomes `restatex.Outcome(err, repository.ErrConflict)`.

- [ ] **Step 7: Run.** `make test` passes; lint reports 0 issues.

### Task 4: auth service and handler layers

**Files:**
- Create: `internal/auth/service/service.go`, `service/views.go`, `service/metrics.go`, `service/otp_send.go`, `service/otp_send_durable.go`, `service/sign_in.go`, `service/sign_in_durable.go`, `service/session_issue.go`, `service/session_list.go`, `service/session_logout.go`, `service/session_refresh.go`, `service/identity.go`, and their tests
- Create: `internal/auth/handler/handler.go`, `handler/middleware.go`, `handler/metrics.go`, `handler/otp_send.go`, `handler/sign_in.go`, `handler/session_list.go`, `handler/session_logout.go`, `handler/session_refresh.go`
- Rename: `internal/auth/mount.go` → `internal/auth/auth.go`
- Delete: every other file at `internal/auth/` root: `accounts.go`, `client.go`, `client_test.go`, `restate.go`, `middleware.go`, `metrics.go`, `otp_*.go`, `sign_in*.go`, `session_*.go`, `helpers_test.go`
- Modify: `internal/staff/ports.go`, `internal/staff/account_get.go`, `internal/app/app.go`

**Interfaces:**
- Consumes: `accountsvc.Service` (Task 2), `restatex.Caller`, `restatex.Result` (Task 1), `domain` and `repository` of Task 3.
- Produces, package `.../auth/service`:
  ```go
  type Service interface {
      SendOTP(ctx context.Context, in SendOTPInput) (OTPSent, error)
      SignIn(ctx context.Context, in SignInInput) (SignedIn, error)
      Refresh(ctx context.Context, refreshToken string) (domain.Tokens, error)
      Logout(ctx context.Context, p authn.Principal) error
      LogoutAll(ctx context.Context, p authn.Principal) error
      RemoveSession(ctx context.Context, p authn.Principal, id uuid.UUID) error
      ListSessions(ctx context.Context, p authn.Principal, req page.Request) (page.Page[SessionItem], error)
      FindAccount(ctx context.Context, q string) (uuid.UUID, bool, error)
      Identities(ctx context.Context, accountID uuid.UUID) ([]Identity, error)
  }

  type Deps struct {
      Challenges  repository.Challenges
      Quotas      repository.Quotas
      Credentials repository.Credentials
      Sessions    repository.Sessions
      Codes       domain.Codes
      Signer      domain.Signer
      Accounts    accountsvc.Service
      SMS         sms.Sender
      Email       email.Sender
      Ingress     *ingress.Client
      Prefix      string
      Now         func() time.Time
      Log         *slog.Logger
  }

  type Auth struct { /* Deps' fields, unexported, plus: */
      otp    restatex.Caller[otpSendInput, otpSent]
      signIn restatex.Caller[signInInput, signInResult]
  }

  func New(d Deps) *Auth
  // Durable returns the Restate services Auth calls, for Mount to bind.
  func (a *Auth) Durable() []restate.ServiceDefinition

  type SendOTPInput struct {
      IdempotencyKey string
      Destination    contact.Address
      Purpose        domain.Purpose
      IP             netip.Addr
  }
  type OTPSent struct {
      ChallengeID uuid.UUID `json:"challenge_id"`
      ResendAfter int       `json:"resend_after"`
  }
  type SignInInput struct {
      IdempotencyKey string
      ChallengeID    uuid.UUID
      Code           string
      DeviceName     string
  }
  type SignedIn struct { // today's SignInResponse
      domain.Tokens
      Account SignedInAccount `json:"account"`
  }
  type SignedInAccount struct { /* today's */ }
  type SessionItem struct { /* today's */ }
  type Identity struct { /* today's auth.Identity */ }
  ```
  The Restate services keep their names: `OTP` (handler `Send`) in `otp_send_durable.go` and `SignIn` (handler `Run`) in `sign_in_durable.go`. Their inputs become unexported `otpSendInput` and `signInInput`; they return `restatex.Result[otpSent]` and `restatex.Result[signInResult]`, where `otpSent{ChallengeID}` and `signInResult{ChallengeID, AccountID, IsNew, SessionID}` are today's results without `Refused`. `SignIn` takes `accountsvc.Service` for `Accounts`.
- Produces, package `.../auth/handler`: `Handler`, `New(svc service.Service, log *slog.Logger) *Handler`, `(*Handler).Register(r *httpx.Router, protect func(http.Handler) http.Handler)`, and `Protect(v domain.Verifier, now func() time.Time, log *slog.Logger) func(http.Handler) http.Handler` (today's `RequireAuth`).
- Produces, package `auth`:
  ```go
  type Settings struct { Keys config.AuthConfig; SMS sms.Sender; Email email.Sender }
  func Protect(d module.Deps, keys config.AuthConfig) func(http.Handler) http.Handler
  type Mounted struct {
      Services []restate.ServiceDefinition
      Service  service.Service
  }
  func Mount(d module.Deps, s Settings, accounts accountsvc.Service) Mounted
  ```

- [ ] **Step 1: Move the tests first.** `otp_service_test.go` → `service/otp_send_durable_test.go`, `sign_in_service_test.go` → `service/sign_in_durable_test.go`, `session_issue_test.go`, `session_list_test.go`, `session_logout_test.go`, `session_refresh_test.go`, `session_refresh_pg_test.go` → `service/`, `client_test.go` → `service/identity_test.go`, `middleware_test.go` → `handler/middleware_test.go`, `helpers_test.go` → `service/helpers_test.go`; all package `service_test` (the middleware test `handler_test`). Calls to a use case function become calls on an `*Auth` that a `newAuth(t)` helper builds with `service.New(service.Deps{...})`; tests of the durable services keep calling them through Restate, now through `Auth.SendOTP`/`Auth.SignIn` or a `restatex.Caller`.

- [ ] **Step 2: Run.** `go test ./internal/auth/...` fails to compile.

- [ ] **Step 3: Durable services.** `git mv otp_service.go service/otp_send_durable.go`, `sign_in_service.go service/sign_in_durable.go`. Bodies unchanged except the result types (`return restatex.Result[otpSent]{Refused: refused}, err`) and the moved names. `destinationKey`, `addressKey`, the quota rules, `NewChallenge` (now `newChallenge`, since `domain.NewChallenge` exists) and `SendCode` (now `sendCode`) move from `otp_send.go` into `otp_send_durable.go`, the file that calls them. `ErrOTPTooSoon` and `ErrOTPLimit` go to `domain/errors.go`.

- [ ] **Step 4: Auth.** Write `service/service.go` with `Service`, `Deps`, `Auth`, `New` and `Durable`:

  ```go
  func New(d Deps) *Auth {
      return &Auth{
          challenges: d.Challenges, quotas: d.Quotas, credentials: d.Credentials, sessions: d.Sessions,
          codes: d.Codes, signer: d.Signer, accounts: d.Accounts, sms: d.SMS, email: d.Email,
          prefix: d.Prefix, now: d.Now, log: d.Log,
          otp:    restatex.Caller[otpSendInput, otpSent]{Ingress: d.Ingress, Service: d.Prefix + otpService, Handler: "Send"},
          signIn: restatex.Caller[signInInput, signInResult]{Ingress: d.Ingress, Service: d.Prefix + signInService, Handler: "Run"},
      }
  }

  func (a *Auth) Durable() []restate.ServiceDefinition {
      return []restate.ServiceDefinition{
          restate.Reflect(OTP{Prefix: a.prefix, Quotas: a.quotas, Challenges: a.challenges, Codes: a.codes, SMS: a.sms, Email: a.email, Now: a.now}),
          restate.Reflect(SignIn{Prefix: a.prefix, Challenges: a.challenges, Credentials: a.credentials, Accounts: a.accounts, Now: a.now}),
      }
  }
  ```

- [ ] **Step 5: Use cases.** `service/otp_send.go`:

  ```go
  // SendOTP sends a code. Restate runs it, so a crash between the quota and
  // the message neither loses the code nor sends it twice.
  func (a *Auth) SendOTP(ctx context.Context, in SendOTPInput) (OTPSent, error) {
      res, err := a.otp.Call(ctx, in.IdempotencyKey, otpSendInput{
          Kind: in.Destination.Kind(), Destination: in.Destination.Value(), Purpose: in.Purpose, IP: in.IP,
      })
      if err != nil {
          return OTPSent{}, err
      }
      return OTPSent{ChallengeID: res.ChallengeID, ResendAfter: int(resend.Window.Seconds())}, nil
  }
  ```

  `service/sign_in.go` holds `SignIn`, the body of today's `signIn` after `httpx.Bind`: load the challenge, hash the code, `a.signIn.Call`, the replay check against `in.ChallengeID` and the code hash, then `a.issueSession(...)`. `service/session_issue.go` holds `issueSession` (today's `IssueSession`, a method now; `SignIn` and its tests call it). `session_refresh.go`, `session_logout.go`, `session_list.go` become methods with today's bodies; `reused` and `revoke` stay helpers in `session_refresh.go`, since `Refresh` calls them from several places. `identity.go` holds `FindAccount` and `Identities` from `client.go`. `refreshReuse` and `otpSent` go to `service/metrics.go`.

- [ ] **Step 6: Handler.** `handler/handler.go` with `Handler`, `New`, `Register`:

  ```go
  func (h *Handler) Register(r *httpx.Router, protect func(http.Handler) http.Handler) {
      r.Handle("POST /v1/auth/otp", http.HandlerFunc(h.SendOTP))
      r.Handle("POST /v1/auth/otp/verify", http.HandlerFunc(h.SignIn))
      r.Handle("POST /v1/auth/refresh", http.HandlerFunc(h.Refresh))
      r.Handle("POST /v1/auth/logout", protect(http.HandlerFunc(h.Logout)))
      r.Handle("POST /v1/auth/logout-all", protect(http.HandlerFunc(h.LogoutAll)))
      r.Handle("GET /v1/auth/sessions", protect(http.HandlerFunc(h.ListSessions)))
      r.Handle("DELETE /v1/auth/sessions/{id}", protect(http.HandlerFunc(h.RemoveSession)))
  }
  ```

  Each method binds today's request struct (unexported now: `otpSendRequest`, `signInRequest`, `refreshRequest`, `removeSessionRequest`, `listSessionsRequest`), parses the destination with `contact.Parse` and reads `httpx.ClientIP(r)` where today's handler does, calls the service, and writes the result. `handler/sign_in.go` keeps the `logins` counter around `h.svc.SignIn`, as today; `logins` goes to `handler/metrics.go`. `handler/middleware.go` holds `Protect`, today's `RequireAuth`.

- [ ] **Step 7: Mount.** `git mv mount.go auth.go`:

  ```go
  func Protect(d module.Deps, keys config.AuthConfig) func(http.Handler) http.Handler {
      return handler.Protect(domain.NewVerifier(keys), d.Now, d.Log)
  }

  func Mount(d module.Deps, s Settings, accounts accountsvc.Service) Mounted {
      svc := service.New(service.Deps{
          Challenges: repository.NewChallenges(d.Pool), Quotas: repository.NewQuotas(d.Pool),
          Credentials: repository.NewCredentials(d.Pool), Sessions: repository.NewSessions(d.Pool),
          Codes: domain.NewCodes(s.Keys.OTPKey), Signer: domain.NewSigner(s.Keys), Accounts: accounts,
          SMS: s.SMS, Email: s.Email, Ingress: d.Ingress, Prefix: d.ServicePrefix, Now: d.Now, Log: d.Log,
      })
      handler.New(svc, d.Log).Register(d.Router, Protect(d, s.Keys))
      return Mounted{Services: svc.Durable(), Service: svc}
  }
  ```

  Package comment: "Package auth proves who a person is: OTP sign-in, sessions and tokens."

- [ ] **Step 8: Callers.** `internal/app/app.go`: `staff.Mount(d, staffKeys, accounts, authm.Service)`. `internal/staff/ports.go`: `IdentityPort.Identities` returns `[]authsvc.Identity`; `staff/account_get.go` follows.

- [ ] **Step 9: Run.** `make test` passes, `e2e/auth_otp_test.go` included; lint reports 0 issues.

### Task 5: staff domain and repository

**Files:**
- Create: `internal/staff/domain/` from `member/member.go`, `member/password.go`, `member/totp.go`, `member/errors.go`, `staff/errors.go` (all but `ErrNotFromConsole`), and `Session`, `Grant`, `SessionTTL` from `session_store.go` into `domain/session.go`; `MaxFailures` and `LockFor` from `lock_store.go` into `domain/lock.go`; their tests (`member_test.go`, `password_test.go`, `totp_test.go`, `argon_internal_test.go`)
- Create: `internal/staff/repository/member.go`, `member_pg.go`, `session.go`, `session_pg.go`, `lock.go`, `lock_pg.go`, `errors.go`, and their `_pg_test.go`
- Delete: `internal/staff/member/`, `internal/staff/session_store*.go`, `internal/staff/lock_store*.go`
- Modify: every staff root file, `cmd/staff/main.go`, `internal/app/app.go`, `e2e/main_test.go`, `e2e/staff_helpers_test.go`, `e2e/staff_*_test.go` (imports only)

**Interfaces:**
- Produces, package `.../staff/domain`: today's `member` names unchanged (`Role`, `RoleAdmin`, `RoleModerator`, `Status`, `Step`, `Member`, `Hasher`, `Production`, `Fast`, `VerifyPassword`, `CheckPolicy`, `TemporaryPassword`, `NewTOTPSecret`, `EncodeSecret`, `TOTPURI`, `Code`, the errors) except `member.New` → `NewMember`; new `RestoreMember(...)` with every stored field and the opened TOTP secrets, `Saved(writeID uuid.UUID)` on `Member`; `Session`, `Grant`, `SessionTTL`, `MaxFailures`, `LockFor`; `ErrLoginLocked`, `ErrPasswordChangeRequired`, `ErrTOTPEnrollmentRequired`, `ErrTOTPRequired`, `ErrTOTPEnrolled`, `ErrStaffForbidden`, `ErrMemberNotFound`, `Locked(wait time.Duration) error` (today's `locked`; exported because service and repository both call it).
- Produces, package `.../staff/repository`:
  ```go
  var (
      ErrNotFound = errors.New("staff: not found")
      ErrConflict = errors.New("staff: changed meanwhile")
  )
  type Members interface { /* member.Store's methods */ }
  type Sessions interface { /* SessionStore's methods */ }
  type Locks interface { /* LockStore's methods */ }
  func NewMembers(db *pgxpool.Pool, seal cipher.AEAD) Members
  func NewSessions(db *pgxpool.Pool) Sessions
  func NewLocks(db *pgxpool.Pool) Locks
  func LockKey(mac []byte, email string) []byte // today's lockKey; service calls it
  ```

- [ ] **Step 1: Move the tests first**, as in Task 2. `argon_internal_test.go` stays an internal test, package `domain`.

- [ ] **Step 2: Add a save-twice test** to `repository/member_pg_test.go`: create a member, `Disable`, save, `Enable`, save; both succeed.

- [ ] **Step 3: Run.** `go test ./internal/staff/...` fails to compile.

- [ ] **Step 4: Domain and repository.** `git mv` and rename as listed; reads through getters, scans through `RestoreMember`, `m.writeID = w` through `m.Saved(w)`. The member repository keeps sealing and opening TOTP secrets.

- [ ] **Step 5: Callers.** Update imports in the staff root files (`member.` → `domain.`, `LockStore` → `repository.Locks`, `NewPGLockStore` → `repository.NewLocks`, …), in `stores.go`, `cmd/staff/main.go`, `internal/app/app.go` (`member.Hasher`, `member.Production` → `staffdomain.…`) and in the e2e tests (`member.` → `staffdomain.`).

- [ ] **Step 6: Run.** `make test` passes; lint reports 0 issues.

### Task 6: staff service and handler

**Files:**
- Create: `internal/staff/service/service.go`, `service/keys.go`, `service/views.go`, `service/login.go`, `service/login_totp_enrollment.go`, `service/authenticate.go`, `service/me.go`, `service/member_create.go`, `service/member_disable.go`, `service/member_list.go`, `service/member_reset.go`, `service/member_unlock.go`, `service/member_find.go`, `service/account_get.go`, `service/account_list.go`, `service/account_suspend.go`, `service/action_list.go`, and their tests
- Create: `internal/staff/handler/handler.go`, `handler/require.go`, `handler/cookie.go`, `handler/errors.go`, and one file per use case file above (without `authenticate.go` and `member_find.go`)
- Rename: `internal/staff/mount.go` → `internal/staff/staff.go`
- Delete: `internal/staff/ports.go`, `stores.go`, `keys.go`, `views.go`, `errors.go`, every use case and handler file at the root

**Interfaces:**
- Consumes: `accountsvc.Service`, `accountsvc.Record`, `accountsvc.SuspendInput` (Task 2), `authsvc.Service`, `authsvc.Identity` (Task 4), `domain` and `repository` of Task 5.
- Produces, package `.../staff/service`:
  ```go
  type Service interface {
      Login(ctx context.Context, in LoginInput) (SignedIn, error)
      EnrollTOTP(ctx context.Context, email, password string) (Enrollment, error)
      Authenticate(ctx context.Context, token string) (domain.Grant, error)
      GetMe(ctx context.Context, caller authn.Staff) (Me, error)
      ChangePassword(ctx context.Context, caller authn.Staff, current, next string) error
      Logout(ctx context.Context, caller authn.Staff) error
      ListMembers(ctx context.Context, p page.Request) (page.Page[MemberView], error)
      FindMember(ctx context.Context, email string) (MemberView, error)
      CreateMember(ctx context.Context, in CreateMemberInput) (MemberView, string, error)
      DisableMember(ctx context.Context, id uuid.UUID, by audit.Actor) (MemberView, error)
      EnableMember(ctx context.Context, id uuid.UUID, by audit.Actor) (MemberView, error)
      UnlockMember(ctx context.Context, id uuid.UUID, by audit.Actor) (MemberView, error)
      ResetMemberPassword(ctx context.Context, id uuid.UUID, by audit.Actor) (string, error)
      ResetMemberTOTP(ctx context.Context, id uuid.UUID, by audit.Actor) (MemberView, error)
      ListAccounts(ctx context.Context, q string, p page.Request) (page.Page[accountsvc.Record], error)
      GetAccount(ctx context.Context, id uuid.UUID) (AccountDetail, error)
      SuspendAccount(ctx context.Context, in accountsvc.SuspendInput) (accountsvc.Record, error)
      UnsuspendAccount(ctx context.Context, id uuid.UUID, by audit.Actor) (accountsvc.Record, error)
      ListActions(ctx context.Context, f audit.Filter, p page.Request) (page.Page[audit.Action], error)
  }

  type Deps struct {
      Members  repository.Members
      Locks    repository.Locks
      Sessions repository.Sessions
      Actions  audit.Store
      Keys     Keys
      Accounts accountsvc.Service // nil in cmd/staff
      Auth     authsvc.Service    // nil in cmd/staff
      Now      func() time.Time
  }
  type Staff struct { /* Deps' fields, unexported */ }
  func New(d Deps) *Staff

  type Keys struct { /* today's staff.Keys */ }
  func NewKeys(cfg config.StaffConfig, h domain.Hasher) (Keys, error)

  type LoginInput struct {
      Email, Password, NewPassword, Code, UserAgent string
      IP netip.Addr
  }
  type SignedIn struct { Me Me; Token string; ExpiresAt time.Time }
  type CreateMemberInput struct {
      Email, DisplayName string
      Role               domain.Role
      By                 audit.Actor
  }
  // Me, MemberView, Enrollment, AccountDetail: today's types, in views.go.
  ```
  `Authenticate` hashes the cookie's token with `token.Hash` and returns `s.sessions.Live(ctx, hash, s.now())`; an unknown or dead session gives `authn.ErrUnauthenticated`. `FindMember` normalises the email with `contact.NormalizeEmail` and gives `domain.ErrMemberNotFound` for an unknown one.
- Produces, package `.../staff/handler`: `Handler`, `New(svc service.Service, log *slog.Logger) *Handler`, `(*Handler).Register(r *httpx.Router)`, `FromConsole(log *slog.Logger) func(http.Handler) http.Handler`, `Require(svc service.Service, log *slog.Logger, floor domain.Role) func(http.Handler) http.Handler`, `ErrNotFromConsole`.
- Produces, package `staff`:
  ```go
  // NewService builds Staff on db; Mount, cmd/staff and the e2e tests share it.
  func NewService(db *pgxpool.Pool, k service.Keys, accounts accountsvc.Service, auth authsvc.Service, now func() time.Time) *service.Staff
  func Mount(d module.Deps, k service.Keys, accounts accountsvc.Service, auth authsvc.Service)
  ```

- [ ] **Step 1: Move the tests first.** The staff unit tests (`helpers_test.go`, `login_test.go`, `me_test.go`, `member_test.go`, `require_test.go`) go to `service/` (package `service_test`), `require_test.go` to `handler/` (package `handler_test`). A `newEnv(t)` helper builds `*service.Staff` with `staff.NewService` on `pgtest.New(t)` and a fixed clock.

- [ ] **Step 2: Run.** `go test ./internal/staff/...` fails to compile.

- [ ] **Step 3: Service.** Write `service/service.go` (`Service`, `Deps`, `Staff`, `New`, `var _ Service = (*Staff)(nil)`); `git mv keys.go service/keys.go`, `views.go service/views.go`. Turn each use case into a `*Staff` method in the file of the same name, body unchanged except stores → `s.members`, `s.locks`, `s.sessions`, `s.actions`, `k` → `s.keys`, `now` → `now := s.now()` on the first line, `AccountPort`/`IdentityPort` → `s.accounts`/`s.auth`. `checkPassword`, `refund`, `saveFailed`, `loadManaged` and `saveManaged` stay helpers, each called from several use cases. `logRefusal` stays in the handler.

- [ ] **Step 4: Handler.** `handler/handler.go`:

  ```go
  func (h *Handler) Register(r *httpx.Router) {
      console := FromConsole(h.log)
      handle := func(pattern string, hh http.Handler) { r.Handle(pattern, console(hh)) }
      mod := Require(h.svc, h.log, domain.RoleModerator)
      admin := Require(h.svc, h.log, domain.RoleAdmin)

      handle("POST /v1/staff/login", http.HandlerFunc(h.Login))
      handle("POST /v1/staff/login/totp-enrollment", http.HandlerFunc(h.EnrollTOTP))
      handle("POST /v1/staff/logout", mod(http.HandlerFunc(h.Logout)))
      // ... every route of today's Mount, in the same order
  }
  ```

  `require.go` holds `FromConsole` and `Require`; `Require` reads the cookie, calls `svc.Authenticate`, checks `grant.Role.AtLeast(floor)` and puts `authn.Staff{StaffID, SessionID, IP: httpx.ClientIP(r)}` in the context, as today. `cookie.go` moves unchanged. Each use case handler binds today's request struct (unexported now) and calls `h.svc`.

- [ ] **Step 5: Mount.** `git mv mount.go staff.go`; `NewService` builds the repositories (`repository.NewMembers(db, k.Secrets)`, `NewLocks`, `NewSessions`, `audit.NewPGStore`) and `service.New`; `Mount` calls `NewService(d.Pool, k, accounts, auth, d.Now)` and `handler.New(svc, d.Log).Register(d.Router)`. Delete `ports.go` and `stores.go`.

- [ ] **Step 6: Run.** `go test ./internal/staff/...` passes.

### Task 7: callers of the staff service

**Files:**
- Modify: `cmd/staff/main.go`, `internal/app/app.go`, `e2e/main_test.go`, `e2e/staff_helpers_test.go`

**Interfaces:**
- Consumes: `staff.NewService`, `staffsvc.NewKeys`, `staffsvc.CreateMemberInput`, `(*Staff).FindMember` (Task 6).

- [ ] **Step 1: cmd/staff.** Replace `staff.NewStores` and the use case calls:

  ```go
  keys, err := staffsvc.NewKeys(cfg.Staff, staffdomain.Production)
  // ...
  svc := staff.NewService(pool, keys, nil, nil, time.Now)
  by := audit.ByCLI(osUser.Username)

  if cmd == createAdmin {
      v, temp, createErr := svc.CreateMember(ctx, staffsvc.CreateMemberInput{Email: *email, DisplayName: *name, Role: staffdomain.RoleAdmin, By: by})
      // ... as today
  }
  m, err := svc.FindMember(ctx, *email)
  if errors.Is(err, staffdomain.ErrMemberNotFound) {
      return fmt.Errorf("no staff member has the email %s", *email)
  }
  // switch: svc.DisableMember(ctx, m.ID, by), svc.EnableMember, svc.UnlockMember,
  // svc.ResetMemberPassword, svc.ResetMemberTOTP
  ```

  The last line prints `m.Email` (a field of `MemberView` now).

- [ ] **Step 2: app.** `staffKeys, err := staffsvc.NewKeys(cfg.Staff, o.hasher)`; `staff.Mount(d, staffKeys, accounts, authm.Service)`.

- [ ] **Step 3: e2e.** `e2e/main_test.go`: `staffKeys staffsvc.Keys`, and `staffSvc *staffsvc.Staff` built with `staff.NewService(pool, staffKeys, nil, nil, time.Now)` in place of `staffStores`. `e2e/staff_helpers_test.go`: `newStaff` calls `staffSvc.CreateMember(context.Background(), staffsvc.CreateMemberInput{Email: email, DisplayName: "E2E Staff", Role: role, By: audit.ByCLI("e2e")})`. Test bodies stay as they are.

- [ ] **Step 4: Run.** `make test` passes, `cmd/staff/main_test.go` and every e2e test included; lint reports 0 issues.

### Task 8: layering rules and docs

**Files:**
- Modify: `.golangci.yml`, `ARCHITECTURE.md`, `CLAUDE.md`, `~/shopnexus/docs/superpowers/specs/2026-10-25-server2-three-layers-design.md`

- [ ] **Step 1: depguard.** Add to `linters.settings.depguard.rules`:

  ```yaml
        domain layer:
          files:
            - "**/internal/*/domain/**"
          deny:
            - pkg: github.com/shopnexus/server2/internal/account/repository
              desc: domain imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/account/service
              desc: domain imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/account/handler
              desc: domain imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/auth/repository
              desc: domain imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/auth/service
              desc: domain imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/auth/handler
              desc: domain imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/staff/repository
              desc: domain imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/staff/service
              desc: domain imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/staff/handler
              desc: domain imports no layer above it.
        repository layer:
          files:
            - "**/internal/*/repository/**"
          deny:
            - pkg: github.com/shopnexus/server2/internal/account/service
              desc: repository imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/account/handler
              desc: repository imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/auth/service
              desc: repository imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/auth/handler
              desc: repository imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/staff/service
              desc: repository imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/staff/handler
              desc: repository imports no layer above it.
        service layer:
          files:
            - "**/internal/*/service/**"
          deny:
            - pkg: github.com/shopnexus/server2/internal/account/handler
              desc: service imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/auth/handler
              desc: service imports no layer above it.
            - pkg: github.com/shopnexus/server2/internal/staff/handler
              desc: service imports no layer above it.
        handler layer:
          files:
            - "**/internal/*/handler/**"
          deny:
            - pkg: github.com/shopnexus/server2/internal/account/repository
              desc: handler reaches data through service.
            - pkg: github.com/shopnexus/server2/internal/auth/repository
              desc: handler reaches data through service.
            - pkg: github.com/shopnexus/server2/internal/staff/repository
              desc: handler reaches data through service.
  ```

  depguard matches package prefixes and has no wildcard for the module name, so each module is listed.

- [ ] **Step 2: Check the rules bite.** Add `import _ "github.com/shopnexus/server2/internal/account/repository"` to `internal/account/handler/handler.go`; `golangci-lint run ./internal/account/...` must report depguard. Remove the import.

- [ ] **Step 3: ARCHITECTURE.md.** Rewrite "Module layout" with the tree of the spec, the import direction and the depguard rules; replace the `*_service.go` rule in the Restate section with: the two durable services live in `auth/service/*_durable.go`, and `Auth` reaches them through `restatex.Caller`; rewrite the staff paragraph (sessions, locks and members are repositories of `staff/repository`). Search the file for `account.Client`, `auth.Client`, `AccountPort`, `IdentityPort`, `staff/member`, `auth/otp`, `auth/session`, `auth/credentials` and fix each mention.

- [ ] **Step 4: CLAUDE.md.** "A use case, Restate handler or HTTP handler stays one function that reads top to bottom" becomes "A use case (a method of a module's service), a Restate handler or an HTTP handler reads top to bottom"; the `cmd/staff` line is unchanged.

- [ ] **Step 5: Spec.** Add the "Entities across packages" paragraph of this plan, and change "e2e tests stay as they are" to "e2e test bodies stay as they are; their helpers build `staff.NewService`".

- [ ] **Step 6: Prose check.** Run `python3 ~/.claude/skills/humanizing-writing/ai-tells.py --stats ARCHITECTURE.md CLAUDE.md ~/shopnexus/docs/superpowers/specs/2026-10-25-server2-three-layers-design.md` and fix every hit.

- [ ] **Step 7: Final run.** `make test` passes; lint reports 0 issues; `git grep -n 'NewPGStore\|staff/member"\|auth/otp"\|auth/session"\|auth/credentials"'` finds nothing outside `audit`.
