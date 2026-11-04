# Design: server2 in three layers

Date: 2026-10-25.
Status: decided in conversation, question by question and section by section.
When the work lands, the layout below replaces "Module layout" in
`~/shopnexus/server2/ARCHITECTURE.md`.

## Problem

The user found the modules hard to follow. Each module places its parts its
own way:

- `account` keeps its entity in the module's root package.
- `auth` keeps its aggregates in `otp/`, `session/` and `credentials/`, and its
  use cases, handlers and Restate services in the root.
- `staff` keeps the member in `member/`, and its session and lock stores,
  use cases and handlers in the root.

Every use case file holds the use case and its HTTP handler
(`account_rename.go` holds `Rename` and `RenameHandler`).

## Layers

Every module has the same four packages and one root file:

| Package | Holds | Imports |
|---|---|---|
| `domain` | entities, their rules, the module's business errors | stdlib, `platform` |
| `repository` | one interface per aggregate and its Postgres implementation | `domain`, `platform` |
| `service` | the module's `Service` interface, its implementation, views and inputs; Restate services for the few use cases that must survive a crash | `repository`, `domain`, other modules' `service`, `platform`, `provider` |
| `handler` | HTTP handlers, request structs, middleware, cookies | `service`, `domain`, `platform` |
| root file (`account.go`, `auth.go`, `staff.go`) | `Mount` | all four |

Imports run one way, `handler` → `service` → `repository` → `domain`, and
no package imports a layer above it. `platform` and `provider` keep their
current shape.

## Repository

`repository/<aggregate>.go` declares the interface; `repository/<aggregate>_pg.go`
implements it with hand-written SQL, as today; `repository/<aggregate>_pg_test.go`
tests it against Postgres. The constructor returns the interface:

```go
type Accounts interface {
	Create(ctx context.Context, a domain.Account) error
	Get(ctx context.Context, id uuid.UUID) (domain.Account, error)
	Save(ctx context.Context, a *domain.Account, writeID uuid.UUID) error
	Delete(ctx context.Context, id uuid.UUID) error
}

func NewAccounts(db *pgxpool.Pool) Accounts { return pgAccounts{db: db} }
```

`ErrNotFound` and `ErrConflict` live in `repository` as plain errors. An
error a client sees lives in `domain`: the service maps
`repository.ErrNotFound` to `domain.ErrAccountNotFound`, so another module
checks the domain error and never imports the repository. Tests wrap an
interface to inject faults, as `restatetest.CommitThenFail` does today.

## Service

`service/service.go` declares the module's contract and its implementation:

```go
type Service interface {
	Get(ctx context.Context, id uuid.UUID) (AccountView, error)
	Rename(ctx context.Context, id uuid.UUID, name string) (AccountView, error)
	// ...
}

type Account struct {
	accounts repository.Accounts
	now      func() time.Time
}

var _ Service = (*Account)(nil)

func New(accounts repository.Accounts, now func() time.Time) *Account
```

The implementations are `service.Account`, `service.Auth` and
`service.Staff`. Each use case is one method in its own file, named as today
(`account_rename.go`, `member_create.go`), and reads top to bottom under the
rule in CLAUDE.md. A method takes `context.Context`, reads the clock once
through `now`, and calls its repositories directly.

`service/views.go` holds the response types in the shape of the OpenAPI
schemas (`AccountView`, `Record`, `Me`, `MemberView`) and the inputs of
methods with more than three arguments. The handler encodes a view as it
comes back.

## Handler

`handler.Handler` holds `service.Service` and the logger, and has one method
per endpoint. `Register` adds its routes to the router:

```go
func (h *Handler) Register(r *httpx.Router, protect func(http.Handler) http.Handler) {
	r.Handle("GET /v1/accounts/me", protect(http.HandlerFunc(h.GetMe)))
	r.Handle("PATCH /v1/accounts/me", protect(http.HandlerFunc(h.Rename)))
}
```

A handler method binds the request, calls one service method and writes the
view or the error. Request structs (`renameRequest`) are unexported and live
in the handler file. Errors that only HTTP produces, such as staff's
`ErrNotFromConsole`, live in `handler`.

## Entities across packages

An entity keeps its fields unexported, so a repository in another package
rebuilds a stored one through `Restore<Entity>(...)`, as `otp.Restore` did,
and records a write with `Saved(writeID)` in place of setting the field. A
member, with fourteen stored fields, is rebuilt from `domain.MemberState`.
Only repositories call either. Each repository test saves an entity twice
in a row with new write IDs, which fails when a `Saved` call is missing.

## Mount

```go
func Mount(d module.Deps, protect func(http.Handler) http.Handler) service.Service {
	svc := service.New(repository.NewAccounts(d.Pool), d.Now)
	handler.New(svc, d.Log).Register(d.Router, protect)
	return svc
}
```

`Mount` returns the module's `service.Service`, which other modules take.
`auth.Mount` also returns its Restate service definitions.

## Calls between modules

A module calls another through that module's `service.Service`:
`auth/service` takes `accountsvc.Service`, and `staff/service` takes
`accountsvc.Service` and `authsvc.Service`. The adapters and ports that
exist only to cross modules are removed: `account.Client`, `auth.Client`,
`auth.AccountPort`, `staff.AccountPort` and `staff.IdentityPort`. Their
methods become `Service` methods: account gains `Create`, `Delete`,
`Status`, `Record`, `Records`, `Suspend` and `Reinstate`; auth gains
`FindAccount` and `Identities`.

`app.mountModules` mounts in dependency order:

```go
accounts := account.Mount(d, protect)
authSvc := auth.Mount(d, authSettings, accounts)
staff.Mount(d, staffKeys, accounts, authSvc)
```

## Restate

Only OTP sending and OTP sign-in run on Restate, as today. Every other
method is plain Go.

- `auth/service/otp_send_durable.go` holds Restate service `OTP` and
  `auth/service/sign_in_durable.go` holds Restate service `SignIn`, under the
  rules in `restatex` (journaled clock and IDs, every store call in
  `restate.Run`, decisions between steps, `write_id`).
- `Auth.SendOTP` and `Auth.SignIn` call them through `restatex.Caller`,
  which replaces `auth.Restate`. A handler calls `h.svc.SendOTP(...)` and does
  not know Restate runs it.
- `Auth.SignIn` calls the `SignIn` service, then issues the session, as the
  handler does today.
- A Restate service still returns a refusal as data, in a result type of
  its own with a `Refused` field and a `Refusal()` method. `Caller` returns
  that refusal as the error, so the handler gets the same `*apperr.Error` it
  gets from a plain method. Restate derives a JSON schema ID from the result
  type's name and refuses a generic type, so there is no shared
  `Result[O]`.

```go
type Caller[I any, O Refusable] struct {
	Ingress *ingress.Client
	Service string
	Handler string
}

func (c Caller[I, O]) Call(ctx context.Context, idempotencyKey string, in I) (O, error)
```

`Call` applies `restatex.CallTimeout` and the idempotency key.

## Middleware and CLI

`auth/handler.Protect` checks the JWT locally, as `auth.Protect` does today.
`staff/handler.Require` reads the cookie and calls `Staff.Authenticate(ctx,
token)` in process; the role check stays in `Require`.

`cmd/staff` builds `service.Staff` on a Postgres pool, as it builds the
stores today, and needs no running server.

## Files

### account

| Today | After |
|---|---|
| `account.go`, `errors.go` | `domain/account.go`, `domain/errors.go` |
| `account_store.go`, `account_store_pg.go` | `repository/account.go`, `repository/account_pg.go` |
| `account_create.go`, `account_get.go`, `account_record.go`, `account_rename.go`, `account_suspend.go` | the use case in `service/` under the same name, the handler in `handler/` |
| `client.go` | removed; its methods join `Service` |
| `mount.go` | `account.go` |

### auth

| Today | After |
|---|---|
| `otp/challenge.go`, `otp/quota.go`, `otp/codes.go` | `domain/` |
| `credentials/credentials.go` | `domain/credentials.go` |
| `session/session.go`, `session/token.go` | `domain/session.go`, `domain/token.go` |
| `otp/*_store*.go`, `credentials/*_store*.go`, `session/*_store*.go` | `repository/challenge*.go`, `quota*.go`, `credentials*.go`, `session*.go` |
| `otp_service.go`, `sign_in_service.go` | `service/otp_send_durable.go`, `service/sign_in_durable.go` |
| `otp_send.go`, `sign_in.go`, `session_issue.go`, `session_list.go`, `session_logout.go`, `session_refresh.go` | the use case in `service/`, the handler in `handler/` |
| `middleware.go`, `metrics.go` | `handler/` |
| `restate.go` | removed; `restatex.Caller` |
| `client.go`, `accounts.go` | removed; `FindAccount`, `Identities` join `Service` |
| `mount.go` | `auth.go` |

### staff

| Today | After |
|---|---|
| `member/member.go`, `member/password.go`, `member/totp.go`, `member/errors.go`, `errors.go` | `domain/` |
| `Session` and `Grant` in `session_store.go` | `domain/session.go` |
| `member/member_store*.go`, `session_store*.go`, `lock_store*.go` | `repository/member*.go`, `session*.go`, `lock*.go` |
| `login.go`, `login_totp_enrollment.go`, `me.go`, `member_*.go`, `account_*.go`, `action_list.go` | the use case in `service/`, the handler in `handler/` |
| `keys.go`, `views.go` | `service/` |
| `require.go`, `cookie.go` | `handler/`; the session lookup becomes `Staff.Authenticate` |
| `stores.go`, `ports.go` | removed; `Staff` holds its repositories and the other modules' `Service` |
| `mount.go` | `staff.go` |

## Tests

- Repository tests move to `repository/` and run against Postgres through
  `pgtest`, unchanged.
- Service tests move to `service/` and call `*Account`, `*Auth` and `*Staff`
  with real repositories. Tests of the two durable services use
  `restatetest.Start`, as `otp_service_test.go` does today.
- e2e test bodies stay as they are; their helpers build the staff service
  with `staff.NewService`. The API, the migrations and the behaviour do not
  change, so every e2e test passes unchanged.

## Documentation

ARCHITECTURE.md: "Module layout" describes the four packages and the import
direction; "Restate" names the two durable services and `restatex.Caller`;
the staff paragraph under "Module layout" and the `*_service.go` rule are
rewritten. CLAUDE.md: the use-case rule names methods of a service instead
of functions.

## Splitting a module out

To run account as its own process, an `accountsvc.Client` implements
`Service` over HTTP, gRPC or Restate, and `app` passes it where it passes
`account.Mount`'s result. Handlers and the modules auth and staff do not
change. The data split, account's tables out of the shared database, is
separate work.

## Rejected: every service method on Restate

The user first proposed the shape of the `microservice-ready` branch of
`server`: every service method a Restate handler, and a generated client
that reaches it through the ingress. Rejected in conversation for these
reasons:

- Every method would follow the replay rules, about 30 use cases rewritten
  around `restate.Run`.
- Every request would add a call to Restate, which journals reads such as
  `GET /v1/accounts/me` and the staff session check on every console request.
- Restate would hold passwords, TOTP codes and secrets, session cookies and
  refresh tokens in its journal in plain text, unless each were encrypted.
- An outage of Restate would stop the whole API.
- The three modules share one Postgres database, so a split needs the data
  split first.
