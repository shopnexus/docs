# Sign-in by email code or Google, phone required to trade: server implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A person signs up and signs in to server with a phone token (as today), a Google ID token or a six-digit code mailed to them; an account adds the identity kind it lacks; posting a listing, opening a deal and opening a chat need a phone identity.

**Architecture:** Every proof is checked outside Restate and reaches the `SignIn` and new `AddIdentity` Restate services as a proven address or as a code guess (challenge ID and HMAC), the shape server had before migration `0022`. Email codes come back from `17cf6bf3^` (`internal/auth`) as `EmailCodeSend`, email only. JWKS fetching moves from `provider/firebase` to `provider/jwks`, shared with the new `provider/google`. `phone_required` comes back as `accountsvc.Service.HasPhone`, read by catalog, deal and chat.

**Tech Stack:** Go, Postgres 18 (ParadeDB), Restate Go SDK v1.1.0, `golang-jwt/jwt/v5`, kin-openapi request validation, Resend's HTTP API.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-10-sign-in-email-google-design.md`. Read it and `server/ARCHITECTURE.md` (sections Durable flows, Idempotency-Key, Phone sign-in, Testing, Linting) before Task 1.

## Global Constraints

- Repository: `~/shopnexus/server` (Go module `github.com/shopnexus/server`). Task 10 also edits the umbrella `~/shopnexus` (`docker-compose.yml`, `infra/`).
- Identity kinds: `phone` and `email` only. At least one identity per account, at most one of each kind, a value held by one account.
- Email codes: six digits, 5 minutes, 5 guesses; one send per address per 45 seconds, five per address per hour, twenty per client IP (an IPv6 client by its /64) per hour.
- Google token: RS256, `iss` `accounts.google.com` or `https://accounts.google.com`, `aud` `GOOGLE_CLIENT_ID`, `exp` in the future, `iat` at most 5 minutes old, 30 seconds of skew, `email_verified: true`, `email` through `contact.ParseEmail`.
- New error codes, verbatim: `invalid_google_token` (401), `phone_required` (403), `identity_kind_taken` (409), `identity_taken` (409), `invalid_code` with `details.attempts_left`, `code_expired`, `code_locked` (422), `invalid_email` (422), `otp_too_soon` and `otp_limit` with `details.retry_after` (429).
- Mail subject: `Mã xác minh ShopNexus: <code>`.
- Configuration has no defaults; a missing variable stops the process with its name. New variables: `OTP_KEY`, `EMAIL_SENDER` (`log` or `resend`), `RESEND_API_KEY`, `EMAIL_FROM`, `GOOGLE_CLIENT_ID` (empty turns Google sign-in off), `GOOGLE_JWKS_URL`.
- Tokens and codes never enter Restate's journal or a log line.
- A use case, Restate handler or HTTP handler reads top to bottom; a helper exists only when two or more places call it (`server/CLAUDE.md`).
- Every test and subtest calls `t.Parallel()`. Errors from other packages are wrapped (`fmt.Errorf("...: %w", err)`); inside a step closure the error is `stepErr`.
- Each task ends with `make test` green (it runs every test and golangci-lint). The e2e package fails when a response the OpenAPI spec declares was never observed, so every status a task declares gets an e2e call in the same task.
- Commit messages follow the repo's style (`feat(account): ...`), go through the `humanizing-writing` skill, and carry no `Co-Authored-By` line.
- Scratch files go in `server/tmp/`, never `/tmp`.

## Review Focus

1. A replayed `Idempotency-Key` on `POST /v1/auth/sign-in` with a wrong email code must not return the first run's session. Task 7 Step 1 pins it (`TestSignInByEmailReplayWithAWrongCode`).
2. A Google account whose address is already an email identity reaches that account and creates no second one. Task 7 Step 1 pins it (`TestSignInByGoogleFindsTheEmailAccount`).
3. An `add_identity` challenge must not sign anyone in, and another account's `add_identity` challenge must not add an identity. Task 7 (`TestSignInRefusesAnAddIdentityChallenge`) and Task 8 (`TestAddIdentityRefusesAnotherAccountsChallenge`) pin them.
4. Two `AddIdentity` runs for one account at once must leave one identity of the kind, not an error loop: the second gets `try_again`. Task 8 pins it (`TestAddIdentityLostRaceIsTryAgain`).
5. An email-only account still replies in a chat someone else opened, and its existing deal still reads; only opening is gated. Task 9 pins it (`TestPhoneRequiredOnlyToOpen` in chat).

---

## File map

| File | Task | Responsibility |
|---|---|---|
| `internal/provider/jwks/jwks.go`, `jwks_test.go` | 1 | Fetch and cache one JWKS URL (moved from `firebase/keys.go`). |
| `internal/provider/firebase/verifier.go` | 1 | Uses `jwks.Set`. |
| `migrations/0027_email_identities.sql`, `migrations/email_identities_test.go` | 2 | Kinds, one per kind, OTP tables. |
| `internal/account/domain/credentials.go`, `errors.go` | 2, 4, 9 | `KindEmail`, `Add`, `Has`, JSON; new errors. |
| `internal/provider/email/email.go`, `resend.go`, tests | 3 | `Sender`, `LogSender`, `Resend`. |
| `internal/platform/config/config.go`, `keys.go`, `config_test.go` | 3, 6 | `OTP_KEY`, `EmailConfig`, `GoogleConfig`. |
| `cmd/envgen/main.go`, `main_test.go`, `.env.example` | 3, 6 | `OTP_KEY` generated; new variables. |
| `internal/app/app.go`, `app_test.go` | 3, 5, 6 | Email sender choice, prod guard, wiring. |
| `internal/account/domain/challenge.go`, `codes.go`, `quota.go`, tests | 4 | Restored from `17cf6bf3^`, email only. |
| `internal/account/repository/challenge*.go`, `quota*.go` | 4 | Restored stores. |
| `internal/account/service/email_code_send_durable.go`, `email_code_send.go`, test | 5 | Restate `EmailCodeSend`, `Account.SendEmailCode`. |
| `internal/account/handler/email_code_send.go` | 5 | Two endpoints. |
| `internal/provider/google/verifier.go`, `googletest/googletest.go`, test | 6 | Google ID token checks. |
| `internal/account/service/code_guess.go` | 7 | `judgeGuess`, `verifyToken`, `guessFor`: shared by sign-in and add-identity. |
| `internal/account/service/sign_in.go`, `sign_in_durable.go`, `views.go`, tests | 7 | Three proofs. |
| `internal/account/handler/sign_in.go`, `proof.go` | 7, 8 | The proof body. |
| `internal/account/service/identity_add.go`, `identity_add_durable.go`, test | 8 | Restate `AddIdentity`, `Account.AddIdentity`, `Account.Me`. |
| `internal/account/handler/identity_add.go`, `account_get.go` | 8 | `POST /v1/accounts/me/identities`, `GET /v1/accounts/me`. |
| `internal/account/service/identity.go`, `accounttest/accounttest.go` | 9 | `HasPhone`; the test service gets credentials. |
| `internal/catalog/service/listing_post_durable.go`, `internal/deal/service/deal_open.go`, `internal/chat/service/message_send_durable.go` | 9 | `phone_required`. |
| `api/openapi.yaml`, `api/paths/*.yaml`, `api/schemas/*.yaml` | 5, 7, 8, 9 | The contract. |
| `e2e/*` | 3, 5, 6, 7, 8, 9 | Inbox, Google issuer, endpoint tests. |
| `ARCHITECTURE.md` | 10 | Decisions. |
| `~/shopnexus/docker-compose.yml`, `~/shopnexus/infra/**` | 10 | New variables and secrets. |

---

### Task 1: Move JWKS fetching to `provider/jwks`

**Files:**
- Create (by `git mv`): `internal/provider/jwks/jwks.go`, `internal/provider/jwks/jwks_test.go`
- Modify: `internal/provider/firebase/verifier.go`, `internal/provider/firebase/verifier_test.go`

**Interfaces:**
- Produces: `jwks.New(url string, now func() time.Time, log *slog.Logger) *jwks.Set`; `(*jwks.Set).Key(ctx context.Context, kid string) (crypto.PublicKey, error)`; `jwks.ErrUnavailable` (`*apperr.Error`, code `unavailable`); `jwks.ErrUnknownKey` (plain error).

- [ ] **Step 1: Move the files**

```bash
cd ~/shopnexus/server
mkdir -p internal/provider/jwks
git mv internal/provider/firebase/keys.go internal/provider/jwks/jwks.go
git mv internal/provider/firebase/keys_test.go internal/provider/jwks/jwks_test.go
```

- [ ] **Step 2: Rename and export in `jwks.go`**

Replace the package clause and doc with:

```go
// Package jwks fetches and caches the public keys a JWKS URL publishes, for
// the token checks of provider/firebase and provider/google.
package jwks
```

Then, in the same file:

- `type keySet struct` becomes `type Set struct`, with the doc "Set holds the public keys published at one JWKS URL. Lookups share one mutex, so requests that arrive during a fetch wait for it."
- Add the constructor after the type:

```go
// New is the key set at url; its HTTP client times out after 5 seconds.
func New(url string, now func() time.Time, log *slog.Logger) *Set {
	return &Set{url: url, http: &http.Client{Timeout: fetchTimeout}, now: now, log: log}
}
```

- `func (s *keySet) key(` becomes `func (s *Set) Key(`, and `func (s *keySet) fetch(` becomes `func (s *Set) fetch(`.
- `errUnknownKey` becomes `ErrUnknownKey = errors.New("jwks: no key with this kid")`.
- `ErrUnavailable` becomes:

```go
// ErrUnavailable is a token whose keys could not be fetched yet. The app
// tries again instead of asking for a new code.
var ErrUnavailable = apperr.New(apperr.KindUnavailable, "unavailable", "sign-in tokens cannot be checked right now; try again")
```

- The log line `"fetch phone token keys"` becomes `"fetch sign-in token keys"`.

- [ ] **Step 3: Adapt `jwks_test.go`**

- `package firebase` becomes `package jwks`.
- `newSet` returns `*Set` and builds it with `New`; the test server is plain HTTP, so the default client reaches it:

```go
func newSet(t *testing.T, srv *server, at *time.Time) *Set {
	t.Helper()
	ts := httptest.NewServer(srv)
	t.Cleanup(ts.Close)
	return New(ts.URL, func() time.Time { return *at }, slog.New(slog.DiscardHandler))
}
```

- Every `s.key(` becomes `s.Key(` and every `errUnknownKey` becomes `ErrUnknownKey`.

- [ ] **Step 4: Point the Firebase verifier at `jwks`**

In `internal/provider/firebase/verifier.go`:

- Put the package doc that `keys.go` carried above `package firebase`:

```go
// Package firebase checks the phone tokens Firebase issues: ID tokens of
// Firebase Authentication after an SMS code, and Phone Number Verification
// tokens from the SIM.
package firebase
```

- Import `github.com/shopnexus/server/internal/provider/jwks` and drop `net/http`.
- The struct fields become `auth *jwks.Set` and `pnv *jwks.Set`, and `NewPhoneVerifier` builds them:

```go
func NewPhoneVerifier(cfg config.FirebaseConfig, now func() time.Time, log *slog.Logger) *PhoneVerifier {
	return &PhoneVerifier{
		cfg: cfg, now: now, log: log,
		auth: jwks.New(cfg.AuthJWKSURL, now, log),
		pnv:  jwks.New(cfg.PNVJWKSURL, now, log),
	}
}
```

- In `Verify`: `errors.Is(err, ErrUnavailable)` becomes `errors.Is(err, jwks.ErrUnavailable)` and returns `jwks.ErrUnavailable`; `keyIn := func(set *keySet) jwt.Keyfunc` becomes `func(set *jwks.Set) jwt.Keyfunc` and calls `set.Key(ctx, kid)`.

In `verifier_test.go`, `firebase.ErrUnavailable` becomes `jwks.ErrUnavailable` (add the import).

- [ ] **Step 5: Run the tests**

Run: `go test ./internal/provider/... ./internal/app/...`
Expected: PASS. `grep -rn "firebase.ErrUnavailable\|keySet" --include='*.go' .` prints nothing.

- [ ] **Step 6: Commit**

```bash
git add -A internal/provider
git commit -m "refactor(provider): JWKS fetching moves to provider/jwks for the Google check to share"
```

---

### Task 2: Email identities in the schema and `Credentials`

**Files:**
- Create: `migrations/0027_email_identities.sql`, `migrations/email_identities_test.go`
- Modify: `internal/account/domain/credentials.go`, `internal/account/domain/credentials_test.go`, `internal/account/domain/errors.go`, `internal/account/repository/credentials_pg_test.go`

**Interfaces:**
- Produces: `domain.KindEmail`; `(*Credentials).Add(i Identity) error` (`ErrIdentityKindTaken`); `(*Credentials).Has(k Kind) bool`; `Credentials` and `Identity` marshal to and from JSON; `domain.ErrIdentityKindTaken` (409 `identity_kind_taken`).

The migration number is the one after the highest file in `migrations/`; it was `0027` when this plan was written (`0026_follows_reports.sql` exists, `0025` is claimed by the realtime-ws plan). Use the next free number and keep the name `email_identities`.

- [ ] **Step 1: Write the failing migration test**

`migrations/email_identities_test.go`:

```go
package migrations_test

import (
	"context"
	"errors"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
)

// After 0027 an account holds a phone, an email or both, one of each kind,
// and a code challenge is an email's.
func TestEmailIdentities(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	acc := uuid.NewV7()
	exec := func(q string, args pgx.StrictNamedArgs) error {
		_, err := db.Exec(ctx, q, args)
		return err
	}
	identity := func(kind, value string) error {
		return exec(`INSERT INTO identities (id, account_id, kind, identifier) VALUES (@id, @acc, @kind, @value)`,
			pgx.StrictNamedArgs{"id": uuid.NewV7(), "acc": acc, "kind": kind, "value": value})
	}
	code := func(err error) string {
		var pg *pgconn.PgError
		if errors.As(err, &pg) {
			return pg.Code
		}
		return ""
	}
	for _, q := range []string{
		`INSERT INTO accounts (id, write_id) VALUES (@acc, @acc)`,
		`INSERT INTO credentials (account_id, write_id) VALUES (@acc, @acc)`,
	} {
		if err := exec(q, pgx.StrictNamedArgs{"acc": acc}); err != nil {
			t.Fatal(err)
		}
	}
	if err := identity("phone", "+84901234567"); err != nil {
		t.Fatalf("phone: %v", err)
	}
	if err := identity("email", "linh@example.com"); err != nil {
		t.Fatalf("email beside the phone: %v", err)
	}
	if err := identity("email", "linh2@example.com"); code(err) != "23505" {
		t.Fatalf("a second email: %v", err)
	}
	if err := identity("google", "linh@gmail.com"); code(err) != "23514" {
		t.Fatalf("kind google: %v", err)
	}
	challenge := `INSERT INTO otp_challenges (id, purpose, kind, destination, account_id, code_hash, ip, expires_at, created_at, write_id)
VALUES (@id, @purpose, @kind, 'linh@example.com', @acc, '\x00', '127.0.0.1', @at, @at, @id)`
	at := time.Now()
	for _, c := range []struct {
		name, purpose, kind string
		acc                 *uuid.UUID
		want                string
	}{
		{"sign-in", "sign_in", "email", nil, ""},
		{"add identity", "add_identity", "email", &acc, ""},
		{"add identity without an account", "add_identity", "email", nil, "23514"},
		{"sign-in naming an account", "sign_in", "email", &acc, "23514"},
		{"a phone", "sign_in", "phone", nil, "23514"},
	} {
		id := uuid.NewV7()
		err := exec(challenge, pgx.StrictNamedArgs{"id": id, "purpose": c.purpose, "kind": c.kind, "acc": c.acc, "at": at})
		if code(err) != c.want {
			t.Errorf("%s: %v", c.name, err)
		}
	}
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./migrations/ -run TestEmailIdentities -count=1`
Expected: FAIL at "email beside the phone" with SQLSTATE 23514 (the kind check allows phone only).

- [ ] **Step 3: Write the migration**

`migrations/0027_email_identities.sql`:

```sql
-- Sign-in by email returns: an account holds a phone, an email or both, one
-- of each kind. Google proves an email and is no kind of its own.
ALTER TABLE identities
    DROP CONSTRAINT identities_kind_check,
    ADD CONSTRAINT identities_kind_check CHECK (kind IN ('phone', 'email')),
    ADD CONSTRAINT identities_account_kind UNIQUE (account_id, kind);

-- Codes go to email addresses only; phones go through Firebase. code_hash is
-- HMAC-SHA256(OTP_KEY, ...); the key is not in the database. An add_identity
-- challenge names the account that asked for it, a sign_in one none.
CREATE TABLE otp_challenges (
    id          uuid PRIMARY KEY,
    purpose     text NOT NULL CHECK (purpose IN ('sign_in', 'add_identity')),
    kind        text NOT NULL CHECK (kind = 'email'),
    destination text NOT NULL,
    account_id  uuid REFERENCES accounts,
    code_hash   bytea NOT NULL,
    attempts    int NOT NULL DEFAULT 0,
    ip          inet NOT NULL,
    expires_at  timestamptz NOT NULL,
    created_at  timestamptz NOT NULL,
    consumed_at timestamptz,
    write_id    uuid NOT NULL,
    CHECK ((purpose = 'add_identity') = (account_id IS NOT NULL))
);
CREATE INDEX otp_challenges_destination ON otp_challenges (destination, purpose, created_at);

-- Sends inside the longest window, one row per subject, "dest:..." or "ip:...".
CREATE TABLE otp_quotas (
    subject  text PRIMARY KEY,
    sent_at  timestamptz [] NOT NULL,
    write_id uuid NOT NULL
);
```

Run `sqlfluff lint migrations/0027_email_identities.sql`; fix what it reports the way the other migrations are written.

- [ ] **Step 4: Run the migration test**

Run: `go test ./migrations/ -count=1`
Expected: PASS, `TestPhoneSignInDeletesEmailOnlyAccounts` included.

- [ ] **Step 5: Write the failing domain tests**

Append to `internal/account/domain/credentials_test.go`:

```go
func TestAddIdentity(t *testing.T) {
	t.Parallel()
	phone, _ := contact.ParsePhone("0901234567")
	email, _ := contact.ParseEmail("Linh@Example.com")
	other, _ := contact.ParseEmail("linh2@example.com")
	c := domain.NewCredentials(uuid.NewV7(), domain.NewIdentity(uuid.NewV7(), email, now), now)
	if c.Has(domain.KindPhone) || !c.Has(domain.KindEmail) {
		t.Fatal("Has before Add")
	}
	if err := c.Add(domain.NewIdentity(uuid.NewV7(), phone, now.Add(time.Hour))); err != nil {
		t.Fatal(err)
	}
	if !c.Has(domain.KindPhone) || len(c.Identities()) != 2 || !c.UpdatedAt().Equal(now.Add(time.Hour)) {
		t.Fatalf("%+v", c.Identities())
	}
	if err := c.Add(domain.NewIdentity(uuid.NewV7(), other, now)); !errors.Is(err, domain.ErrIdentityKindTaken) {
		t.Fatalf("a second email: %v", err)
	}
	if len(c.Identities()) != 2 {
		t.Fatal("a refused Add changed the credentials")
	}
}

func TestCredentialsJSON(t *testing.T) {
	t.Parallel()
	email, _ := contact.ParseEmail("linh@example.com")
	c := domain.NewCredentials(uuid.NewV7(), domain.NewIdentity(uuid.NewV7(), email, now), now)
	b, err := json.Marshal(c)
	if err != nil {
		t.Fatal(err)
	}
	var back domain.Credentials
	if err = json.Unmarshal(b, &back); err != nil {
		t.Fatal(err)
	}
	got, want := back.Identities()[0], c.Identities()[0]
	if back.AccountID() != c.AccountID() || back.WriteID() != c.WriteID() || !back.UpdatedAt().Equal(c.UpdatedAt()) ||
		got.ID() != want.ID() || got.Kind() != domain.KindEmail || got.Value() != "linh@example.com" ||
		!got.LastUsedAt().Equal(*want.LastUsedAt()) || !got.CreatedAt().Equal(want.CreatedAt()) {
		t.Fatalf("%s", b)
	}
}
```

Add `"encoding/json"` to the imports.

- [ ] **Step 6: Run them to see them fail**

Run: `go test -short ./internal/account/domain/ -run 'TestAddIdentity|TestCredentialsJSON'`
Expected: FAIL to compile: `c.Has undefined`, `c.Add undefined`, `domain.ErrIdentityKindTaken undefined`.

- [ ] **Step 7: Implement**

In `internal/account/domain/errors.go`, beside `ErrIdentityTaken`:

```go
	ErrIdentityKindTaken = apperr.New(apperr.KindConflict, "identity_kind_taken", "the account has a sign-in method of this kind already")
```

In `internal/account/domain/credentials.go`:

```go
const (
	KindPhone Kind = "phone"
	KindEmail Kind = "email"
)
```

Change the docs of `Identity` and `NewIdentity`:

```go
// Identity is one verified way to sign in: a phone number or an email
// address.

// NewIdentity builds the identity of an address just proven: a phone number
// Firebase verified, an email a code or Google proved. It counts as used at
// now. Its kind is the contact kind of the same name.
```

Change the doc of `Credentials` to "Credentials is the aggregate of an account's sign-in methods: at least one identity, at most one of each kind." Add after `MarkUsed`:

```go
// Has reports whether c holds an identity of kind k.
func (c *Credentials) Has(k Kind) bool {
	return slices.ContainsFunc(c.identities, func(i Identity) bool { return i.kind == k })
}

// Add gives c the identity i, of a kind c lacks; a kind c holds is
// ErrIdentityKindTaken and changes nothing. A value another account holds
// surfaces from the store's Save as ErrIdentityTaken.
func (c *Credentials) Add(i Identity) error {
	if c.Has(i.kind) {
		return ErrIdentityKindTaken
	}
	c.identities = append(slices.Clone(c.identities), i)
	c.updatedAt = i.createdAt
	return nil
}

// identityJSON and credentialsJSON are how a Restate step journals
// credentials it loaded.
type identityJSON struct {
	ID         uuid.UUID  `json:"id"`
	Kind       Kind       `json:"kind"`
	Value      string     `json:"value"`
	LastUsedAt *time.Time `json:"last_used_at,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
}

type credentialsJSON struct {
	AccountID  uuid.UUID      `json:"account_id"`
	Identities []identityJSON `json:"identities"`
	WriteID    uuid.UUID      `json:"write_id"`
	UpdatedAt  time.Time      `json:"updated_at"`
}

func (c Credentials) MarshalJSON() ([]byte, error) {
	j := credentialsJSON{AccountID: c.accountID, WriteID: c.writeID, UpdatedAt: c.updatedAt}
	for _, i := range c.identities {
		j.Identities = append(j.Identities, identityJSON{i.id, i.kind, i.value, i.lastUsedAt, i.createdAt})
	}
	return json.Marshal(j)
}

func (c *Credentials) UnmarshalJSON(b []byte) error {
	var j credentialsJSON
	if err := json.Unmarshal(b, &j); err != nil {
		return err
	}
	ids := make([]Identity, 0, len(j.Identities))
	for _, i := range j.Identities {
		ids = append(ids, RestoreIdentity(i.ID, i.Kind, i.Value, i.LastUsedAt, i.CreatedAt))
	}
	*c = RestoreCredentials(j.AccountID, ids, j.WriteID, j.UpdatedAt)
	return nil
}
```

Add `"encoding/json"` to the imports.

- [ ] **Step 8: Write the failing repository tests**

In `internal/account/repository/credentials_pg_test.go`, inside `TestPGCredentials`, add (`email` and `newCredentials`, `fresh` are the test's own helpers):

```go
	email, _ := contact.ParseEmail("linh@example.com")

	// Save writes an identity Add gave the credentials.
	t.Run("save adds an email", func(t *testing.T) {
		t.Parallel()
		s, _ := newCredentials(t)
		c := fresh(t, s, phone)
		if err := c.Add(domain.NewIdentity(uuid.NewV7(), email, now)); err != nil {
			t.Fatal(err)
		}
		if err := s.Save(ctx, &c, uuid.NewV7()); err != nil {
			t.Fatal(err)
		}
		ref, err := s.FindIdentity(ctx, domain.KindEmail, "linh@example.com")
		if err != nil || ref.AccountID != c.AccountID() {
			t.Fatalf("%+v %v", ref, err)
		}
	})

	// An email another account holds is ErrIdentityTaken and writes nothing.
	t.Run("save an email another account holds", func(t *testing.T) {
		t.Parallel()
		s, _ := newCredentials(t)
		fresh(t, s, email)
		c := fresh(t, s, phone)
		if err := c.Add(domain.NewIdentity(uuid.NewV7(), email, now)); err != nil {
			t.Fatal(err)
		}
		if err := s.Save(ctx, &c, uuid.NewV7()); !errors.Is(err, domain.ErrIdentityTaken) {
			t.Fatalf("%v", err)
		}
		back, err := s.Get(ctx, c.AccountID())
		if err != nil || len(back.Identities()) != 1 {
			t.Fatalf("%+v %v", back.Identities(), err)
		}
	})
```

- [ ] **Step 9: Run the account tests**

Run: `go test ./internal/account/... ./migrations/ -count=1`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add migrations internal/account
git commit -m "feat(account): an account holds a phone, an email or both, one of each"
```

---

### Task 3: Email sender and its configuration

**Files:**
- Create: `internal/provider/email/email.go`, `internal/provider/email/resend.go`, `internal/provider/email/email_test.go`
- Modify: `internal/platform/config/config.go`, `internal/platform/config/keys.go`, `internal/platform/config/config_test.go`, `cmd/envgen/main.go`, `cmd/envgen/main_test.go`, `.env.example`, `internal/app/app.go`, `internal/app/app_test.go`, `internal/account/account.go`, `e2e/main_test.go`
- Create: `e2e/inbox_test.go`

**Interfaces:**
- Produces: `email.Sender` (`Send(ctx context.Context, to, subject, body string) error`); `email.LogSender{Log *slog.Logger}`; `email.NewResend(apiKey, from string) *email.Resend`; `config.AuthConfig.OTPKey []byte`; `config.Config.Email config.EmailConfig{Sender, ResendAPIKey, From string}`; `app.WithEmailSender(email.Sender) app.Option`; `account.Settings.Email email.Sender`; in e2e, `mails *inbox` with `code(t, to, nth) string` and `count(to) int`.

- [ ] **Step 1: Write the failing provider tests**

`internal/provider/email/email_test.go`:

```go
package email_test

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/shopnexus/server/internal/provider/email"
)

func TestLogSenderWritesMessage(t *testing.T) {
	t.Parallel()
	var buf bytes.Buffer
	s := email.LogSender{Log: slog.New(slog.NewTextHandler(&buf, nil))}
	if err := s.Send(context.Background(), "linh@example.com", "Mã xác minh ShopNexus: 583920", "583920"); err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"linh@example.com", "583920"} {
		if !strings.Contains(buf.String(), want) {
			t.Fatalf("log %q lacks %q", buf.String(), want)
		}
	}
}

func TestResendPostsTheMessage(t *testing.T) {
	t.Parallel()
	var got struct {
		From    string   `json:"from"`
		To      []string `json:"to"`
		Subject string   `json:"subject"`
		Text    string   `json:"text"`
	}
	var auth string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		auth = r.Header.Get("Authorization")
		_ = json.NewDecoder(r.Body).Decode(&got)
		_, _ = io.WriteString(w, `{"id":"49a3999c"}`)
	}))
	t.Cleanup(srv.Close)
	s := email.NewResend("re_test", "ShopNexus <no-reply@shopnexus.test>")
	s.URL = srv.URL
	if err := s.Send(context.Background(), "linh@example.com", "Chủ đề", "Nội dung"); err != nil {
		t.Fatal(err)
	}
	if auth != "Bearer re_test" || got.From != "ShopNexus <no-reply@shopnexus.test>" || len(got.To) != 1 ||
		got.To[0] != "linh@example.com" || got.Subject != "Chủ đề" || got.Text != "Nội dung" {
		t.Fatalf("auth %q, body %+v", auth, got)
	}
}

func TestResendReportsARefusal(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, `{"message":"domain not verified"}`, http.StatusForbidden)
	}))
	t.Cleanup(srv.Close)
	s := email.NewResend("re_test", "a@b.test")
	s.URL = srv.URL
	err := s.Send(context.Background(), "linh@example.com", "s", "b")
	if err == nil || !strings.Contains(err.Error(), "403") || !strings.Contains(err.Error(), "domain not verified") {
		t.Fatalf("%v", err)
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test -short ./internal/provider/email/`
Expected: FAIL: no Go files / package not found.

- [ ] **Step 3: Write the provider**

`internal/provider/email/email.go`:

```go
// Package email sends email. Callers write the subject and body.
package email

import (
	"context"
	"log/slog"
)

// Sender delivers one message.
type Sender interface {
	Send(ctx context.Context, to, subject, body string) error
}

// LogSender writes messages to the log instead of sending them; APP_ENV=prod
// refuses it.
type LogSender struct{ Log *slog.Logger }

func (s LogSender) Send(ctx context.Context, to, subject, body string) error {
	s.Log.InfoContext(ctx, "email (log sender)", "to", to, "subject", subject, "body", body)
	return nil
}
```

`internal/provider/email/resend.go`:

```go
package email

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Resend sends through Resend's HTTP API from one address of a domain
// verified there.
type Resend struct {
	// URL is the emails endpoint; tests point it at a server of their own.
	URL    string
	apiKey string
	from   string
	http   *http.Client
}

func NewResend(apiKey, from string) *Resend {
	return &Resend{URL: "https://api.resend.com/emails", apiKey: apiKey, from: from, http: &http.Client{Timeout: 10 * time.Second}}
}

func (s *Resend) Send(ctx context.Context, to, subject, body string) error {
	payload, err := json.Marshal(map[string]any{"from": s.from, "to": []string{to}, "subject": subject, "text": body})
	if err != nil {
		return fmt.Errorf("encode message: %w", err)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.URL, bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", "application/json")
	res, err := s.http.Do(req)
	if err != nil {
		return fmt.Errorf("post to resend: %w", err)
	}
	defer func() { _ = res.Body.Close() }()
	if res.StatusCode/100 != 2 {
		msg, _ := io.ReadAll(io.LimitReader(res.Body, 1024))
		return fmt.Errorf("resend answered %d: %s", res.StatusCode, strings.TrimSpace(string(msg)))
	}
	return nil
}
```

Run: `go test -short ./internal/provider/email/` → PASS.

- [ ] **Step 4: Write the failing configuration tests**

In `internal/platform/config/config_test.go`:

- `required()` gains:

```go
		"OTP_KEY":        b64(testKeys.OTPKey),
		"EMAIL_SENDER":   "resend",
		"RESEND_API_KEY": "re_test",
		"EMAIL_FROM":     "ShopNexus <no-reply@shopnexus.test>",
```

- The expected `Config` in `TestLoadAllSet` gains `OTPKey: testKeys.OTPKey` inside `Auth` and

```go
		Email: EmailConfig{Sender: "resend", ResendAPIKey: "re_test", From: "ShopNexus <no-reply@shopnexus.test>"},
```

- `TestLoadRejectsBadKeys` gains the cases the old file had:

```go
		{"short otp key", map[string]string{"OTP_KEY": b64(make([]byte, 16))}, "OTP_KEY"},
		{"otp key not base64", map[string]string{"OTP_KEY": "%%%"}, "OTP_KEY"},
```

- A new test:

```go
func TestLoadEmailSender(t *testing.T) {
	t.Parallel()
	for name, c := range map[string]struct {
		set     map[string]string
		mention string
	}{
		"unknown sender":         {map[string]string{"EMAIL_SENDER": "smtp"}, "EMAIL_SENDER"},
		"resend without a key":   {map[string]string{"RESEND_API_KEY": ""}, "RESEND_API_KEY"},
		"no from":                {map[string]string{"EMAIL_FROM": ""}, "EMAIL_FROM"},
	} {
		env := required()
		maps.Copy(env, c.set)
		_, err := Load(lookupIn(env))
		if err == nil || !strings.Contains(err.Error(), c.mention) {
			t.Errorf("%s: %v", name, err)
		}
	}
	env := required()
	env["EMAIL_SENDER"], env["RESEND_API_KEY"] = "log", ""
	if cfg, err := Load(lookupIn(env)); err != nil || cfg.Email.Sender != "log" {
		t.Fatalf("log sender without a key: %v", err)
	}
}
```

`lookupIn` is the helper the file's other tests use to turn the map into a lookup function; if it has another name there, use that name (`grep -n "func.*map\[string\]string) func" internal/platform/config/config_test.go`).

- [ ] **Step 5: Run them to see them fail**

Run: `go test -short ./internal/platform/config/`
Expected: FAIL to compile: `OTPKey` and `EmailConfig` undefined.

- [ ] **Step 6: Implement the configuration**

In `config.go`:

- `AuthConfig` gains, first:

```go
	OTPKey       []byte             // OTP_KEY: base64, at least 32 bytes; hashes and derives email codes
```

- After `FirebaseConfig`, add:

```go
// EmailConfig picks how the server mails sign-in codes.
type EmailConfig struct {
	Sender       string // EMAIL_SENDER: log or resend; APP_ENV=prod refuses log
	ResendAPIKey string // RESEND_API_KEY: required with EMAIL_SENDER=resend, may be empty otherwise
	From         string // EMAIL_FROM: the sender, an address of a domain verified at Resend
}
```

- `Config` gains `Email EmailConfig` after `Firebase`.
- In `Load`, `Auth` gains `OTPKey: decodeKey("OTP_KEY", 32, false),`, and the literal gains:

```go
		Email: EmailConfig{
			Sender:       oneOf("EMAIL_SENDER", "log", "resend"),
			ResendAPIKey: set("RESEND_API_KEY"),
			From:         need("EMAIL_FROM"),
		},
```

- After the `RESTATE_IDENTITY_KEY` switch:

```go
	if cfg.Email.Sender == "resend" && cfg.Email.ResendAPIKey == "" {
		errs = append(errs, errors.New("RESEND_API_KEY is required with EMAIL_SENDER=resend"))
	}
```

In `keys.go`, `NewAuthKeys` sets `OTPKey: NewConsoleKey(),` (32 random bytes; rename nothing) and its doc says it makes the OTP key too.

Run: `go test -short ./internal/platform/config/` → PASS.

- [ ] **Step 7: envgen writes `OTP_KEY`**

In `cmd/envgen/main.go`, after the `CONSOLE_KEY` block:

```go
	if get("OTP_KEY") == "" {
		set("OTP_KEY", base64.StdEncoding.EncodeToString(config.NewConsoleKey()))
	}
```

The package doc lists `OTP_KEY` beside `CONSOLE_KEY`. In `main_test.go`, `TestEnsureEnvCreatesEveryKey` checks `OTP_KEY` decodes to 32 bytes the way it checks `CONSOLE_KEY` (copy that assertion and change the name), and `TestEnsureEnvKeepsExistingKeys` writes an `OTP_KEY=` line it then finds unchanged.

In `.env.example`, after the Firebase block:

```
# How sign-in codes are mailed: log (development) or resend. APP_ENV=prod
# refuses log.
EMAIL_SENDER=log
# Resend's API key; required with EMAIL_SENDER=resend.
RESEND_API_KEY=
EMAIL_FROM=ShopNexus <no-reply@shopnexus.id.vn>
```

and the closing comment lists `OTP_KEY` among the keys `make run` appends.

Run: `go test -short ./cmd/envgen/` → PASS.

- [ ] **Step 8: Write the failing app test**

In `internal/app/app_test.go`, `testConfig` gains

```go
		Email: config.EmailConfig{Sender: "log", ResendAPIKey: "", From: "ShopNexus <no-reply@shopnexus.test>"},
```

and a test:

```go
// The log sender writes every code to the log, so production must name a
// real one.
func TestNewRefusesLogEmailInProd(t *testing.T) {
	t.Parallel()
	cfg := testConfig(t)
	cfg.Env = "prod"
	_, err := New(context.Background(), cfg, discard(), WithPushSender(quietPush{}))
	if err == nil || !strings.Contains(err.Error(), "EMAIL_SENDER") {
		t.Fatalf("err %v", err)
	}
}
```

`TestNewRefusesMissingKeys` gains a case with `cfg.Auth.OTPKey = nil` expecting the error that mentions `make run`.

Run: `go test ./internal/app/ -run 'TestNewRefuses' -count=1`
Expected: FAIL: `TestNewRefusesLogEmailInProd` gets nil or another error.

- [ ] **Step 9: Pick the sender in `app.New`**

In `internal/app/app.go`:

- `options` gains `email email.Sender`, and

```go
// WithEmailSender replaces the sender EMAIL_SENDER picks; e2e tests read
// codes from theirs.
func WithEmailSender(s email.Sender) Option { return func(o *options) { o.email = s } }
```

- The key check at the top of `New` becomes `if len(cfg.Auth.JWTKey) != ed25519.PrivateKeySize || len(cfg.Auth.OTPKey) < 32 {`.
- After the `PNV_TEST_NUMBERS` check:

```go
	if o.email == nil {
		o.email = email.LogSender{Log: log}
		if cfg.Email.Sender == "resend" {
			o.email = email.NewResend(cfg.Email.ResendAPIKey, cfg.Email.From)
		}
	}
	if _, logs := o.email.(email.LogSender); cfg.Env == config.EnvProd && logs {
		return nil, errors.New("APP_ENV=prod with EMAIL_SENDER=log; codes would only be logged")
	}
```

- Where `account.Mount` is called, `account.Settings{...}` gains `Email: o.email` (pass `o` or the sender down the way `mountModules` receives its other options).

In `internal/account/account.go`, `Settings` gains

```go
	Email  email.Sender
```

(Task 5 hands it to the service.)

- [ ] **Step 10: e2e mails into an inbox**

`e2e/inbox_test.go`:

```go
package e2e

import (
	"context"
	"regexp"
	"sync"
	"testing"
)

// inbox keeps every mail the server sends. The send step finishes before
// the request answers, so a test reads its code right after the call.
type inbox struct {
	mu   sync.Mutex
	msgs map[string][]string // address → subject and body, oldest first
}

func newInbox() *inbox { return &inbox{msgs: map[string][]string{}} }

func (b *inbox) Send(_ context.Context, to, subject, body string) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.msgs[to] = append(b.msgs[to], subject+"\n"+body)
	return nil
}

func (b *inbox) count(to string) int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return len(b.msgs[to])
}

var codeIn = regexp.MustCompile(`\b\d{6}\b`)

// code returns the code in the nth mail to "to", counting from 1.
func (b *inbox) code(t *testing.T, to string, nth int) string {
	t.Helper()
	b.mu.Lock()
	defer b.mu.Unlock()
	if len(b.msgs[to]) < nth {
		t.Fatalf("%s got %d mails, want at least %d", to, len(b.msgs[to]), nth)
	}
	return codeIn.FindString(b.msgs[to][nth-1])
}
```

In `e2e/main_test.go`: the `var` block gains `mails = newInbox() // every mail the server sends`; the `config.Config` literal gains `Email: config.EmailConfig{Sender: "log", ResendAPIKey: "", From: "ShopNexus <no-reply@e2e.test>"},`; `app.New` gains `app.WithEmailSender(mails),`. `keys` comes from `config.NewAuthKeys()`, which now carries an OTP key.

- [ ] **Step 11: Run everything**

Run: `make test`
Expected: PASS (golangci-lint included; `mails` unused until Task 5 is fine for a package-level variable).

- [ ] **Step 12: Commit**

```bash
git add -A internal/provider/email internal/platform/config cmd/envgen .env.example internal/app internal/account/account.go e2e
git commit -m "feat(provider): mail through Resend, with OTP_KEY and EMAIL_SENDER back in the configuration"
```

---

### Task 4: Email challenges, codes and quotas

**Files:**
- Create (restored and adapted): `internal/account/domain/challenge.go`, `challenge_test.go`, `codes.go`, `codes_test.go`, `exercise_test.go`, `quota.go`, `quota_test.go`; `internal/account/repository/challenge.go`, `challenge_pg.go`, `challenge_pg_test.go`, `quota.go`, `quota_pg.go`, `quota_pg_test.go`
- Modify: `internal/account/domain/errors.go`

**Interfaces:**
- Consumes: the `otp_challenges` and `otp_quotas` tables of Task 2.
- Produces:
  - `domain.Purpose`, `domain.PurposeSignIn` (`"sign_in"`), `domain.PurposeAddIdentity` (`"add_identity"`), `domain.CodeTTL` (5 minutes), `domain.MaxAttempts` (5), `domain.DetailAttemptsLeft` (`"attempts_left"`).
  - `domain.NewChallenge(id uuid.UUID, purpose Purpose, dest contact.Address, accountID *uuid.UUID, ip netip.Addr, codeHash []byte, now time.Time) Challenge`, with `ID`, `Purpose`, `Destination`, `AccountID`, `CodeHash`, `Attempts`, `ExpiresAt`, `CreatedAt`, `ConsumedAt`, `WriteID`, `Saved`, `Open(now) error`, `Verify(codeHash []byte, now) error`, JSON.
  - `domain.NewCodes(key []byte) Codes`, `(Codes).For(challengeID uuid.UUID) string`, `(Codes).Hash(dest contact.Address, code string) []byte`.
  - `domain.Rule{Window time.Duration; Max int}`, `domain.NewQuota(key string) Quota`, `(*Quota).Admit(now time.Time, rules ...Rule) (Rule, time.Duration, bool)`, JSON.
  - `domain.ErrInvalidCode`, `ErrCodeExpired`, `ErrCodeLocked` (422), `ErrOTPTooSoon`, `ErrOTPLimit` (429).
  - `repository.Challenges` (`Create`, `Get`, `Save`, `IsNewest`) via `repository.NewChallenges(db)`; `repository.Quotas` (`Get`, `Save`) via `repository.NewQuotas(db)`.

- [ ] **Step 1: Restore the files**

```bash
cd ~/shopnexus/server
for f in challenge challenge_test codes codes_test exercise_test quota quota_test; do
  git show 17cf6bf3^:internal/auth/domain/$f.go > internal/account/domain/$f.go
done
for f in challenge challenge_pg challenge_pg_test quota quota_pg quota_pg_test; do
  git show 17cf6bf3^:internal/auth/repository/$f.go > internal/account/repository/$f.go
done
sed -i 's#internal/auth/domain#internal/account/domain#; s#internal/auth/repository#internal/account/repository#' \
  internal/account/domain/{challenge,challenge_test,codes,codes_test,exercise_test,quota,quota_test}.go \
  internal/account/repository/{challenge,challenge_pg,challenge_pg_test,quota,quota_pg,quota_pg_test}.go
```

- [ ] **Step 2: Adapt the domain**

In `challenge.go`:

- Drop the restored package doc (the package already has one).
- Replace the purpose block with:

```go
// Purpose says what a code is for: signing in (and signing up), or adding
// an email to the account that asked.
type Purpose string

const (
	PurposeSignIn      Purpose = "sign_in"
	PurposeAddIdentity Purpose = "add_identity"
)
```

- `NewChallenge` takes the account:

```go
// NewChallenge starts a challenge that expires CodeTTL after now. An
// add_identity challenge names the account that asked for it, a sign_in one
// nil. Its first write ID is its id.
func NewChallenge(id uuid.UUID, purpose Purpose, dest contact.Address, accountID *uuid.UUID, ip netip.Addr, codeHash []byte, now time.Time) Challenge {
	return Challenge{
		id: id, purpose: purpose, dest: dest, accountID: accountID, codeHash: codeHash, ip: ip,
		expiresAt: now.Add(CodeTTL), createdAt: now, writeID: id,
	}
}
```

In `errors.go` add, before `ErrIdentityTaken`:

```go
	ErrInvalidCode = apperr.New(apperr.KindInvalid, "invalid_code", "the code does not match")
	ErrCodeExpired = apperr.New(apperr.KindInvalid, "code_expired", "the code has expired or was replaced; request a new one")
	ErrCodeLocked  = apperr.New(apperr.KindInvalid, "code_locked", "too many wrong codes; request a new one")
	ErrOTPTooSoon  = apperr.New(apperr.KindRateLimited, "otp_too_soon", "wait before requesting another code")
	ErrOTPLimit    = apperr.New(apperr.KindRateLimited, "otp_limit", "too many codes requested; try again later")
```

If `apperr.KindRateLimited` has another name now, use the constant that maps to 429 in `internal/platform/apperr/apperr.go`.

In the restored tests (`challenge_test.go`, `codes_test.go`, `exercise_test.go`, `quota_test.go`):

- Every `contact.ParsePhone("0901234567")` destination becomes `contact.ParseEmail("linh@example.com")` (codes go to email only); other numbers become other addresses (`linh2@example.com`).
- `domain.PurposeLogin` becomes `domain.PurposeSignIn`.
- Every `domain.NewChallenge(id, purpose, dest, ip, hash, now)` call gains `nil` after `dest`.
- A `now` or other helper the restored files define and the package's tests already define (`grep -n "^var now\|^func " internal/account/domain/*_test.go`) is deleted from the restored file.

Run: `go test -short ./internal/account/domain/`
Expected: PASS.

- [ ] **Step 3: Adapt the repositories**

- `challenge.go` and `quota.go`: the doc says "email OTP challenges" and "email OTP send quotas".
- `challenge_pg_test.go`, `quota_pg_test.go`: the same destination, purpose and `NewChallenge` changes as Step 2. An add_identity case needs an account row, so the test that saves a challenge gets a second case:

```go
	t.Run("add identity names the account", func(t *testing.T) {
		t.Parallel()
		db := pgtest.New(t)
		s := repository.NewChallenges(db)
		acc := accounttest.New(t, db)
		dest, _ := contact.ParseEmail("linh@example.com")
		c := domain.NewChallenge(uuid.NewV7(), domain.PurposeAddIdentity, dest, &acc, netip.MustParseAddr("127.0.0.1"), []byte{1}, now)
		if err := s.Create(ctx, c); err != nil {
			t.Fatal(err)
		}
		got, err := s.Get(ctx, c.ID())
		if err != nil || got.AccountID() == nil || *got.AccountID() != acc || got.Purpose() != domain.PurposeAddIdentity {
			t.Fatalf("%+v %v", got, err)
		}
	})
```

(Adapt the receiver names, `ctx` and `now` to those the restored file uses.)
- The restored `errors.go` of the old repository package was not restored: `ErrNotFound` and `ErrConflict` live in `repository.go`.

Run: `go test ./internal/account/... -count=1`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add internal/account
git commit -m "feat(account): email code challenges and send quotas, restored from before 0022"
```

---

### Task 5: Sending email codes

**Files:**
- Create: `internal/account/service/email_code_send_durable.go`, `internal/account/service/email_code_send.go`, `internal/account/service/email_code_send_durable_test.go`, `internal/account/handler/email_code_send.go`, `e2e/email_code_test.go`
- Modify: `internal/account/service/service.go`, `internal/account/service/views.go`, `internal/account/service/metrics.go`, `internal/account/account.go`, `internal/account/handler/handler.go`, `api/openapi.yaml`, `api/paths/auth.yaml`, `api/paths/account.yaml`, `api/schemas/auth.yaml`

**Interfaces:**
- Consumes: Task 3 `email.Sender`, `account.Settings.Email`, `config.AuthConfig.OTPKey`; Task 4 domain and repositories.
- Produces:
  - Restate service `EmailCodeSend`, handler `Run`, input `service.EmailCodeInput{Email contact.Address; Purpose domain.Purpose; AccountID *uuid.UUID; IP netip.Addr}`, result `service.EmailCodeResult{ChallengeID uuid.UUID; ExpiresAt, ResendAt time.Time; Refused *apperr.Error}`.
  - `Service.SendEmailCode(ctx context.Context, in SendEmailCodeInput) (EmailCodeView, error)` with `SendEmailCodeInput{IdempotencyKey, Email string; AccountID *uuid.UUID; IP netip.Addr}` and `EmailCodeView{ChallengeID uuid.UUID "challenge_id"; ExpiresAt time.Time "expires_at"; ResendAt time.Time "resend_at"}`.
  - `service.Deps` gains `Challenges repository.Challenges`, `Quotas repository.Quotas`, `Codes domain.Codes`, `Email email.Sender`.
  - `POST /v1/auth/email-codes` (operationId `sendEmailCode`), `POST /v1/accounts/me/email-codes` (operationId `sendMyEmailCode`).

- [ ] **Step 1: Write the OpenAPI contract**

`api/schemas/auth.yaml` gains:

```yaml
EmailCodeRequest:
  type: object
  additionalProperties: false
  required: [email]
  properties:
    email:
      type: string
      minLength: 3
      maxLength: 254
      description: Trimmed and lower-cased by the server.
EmailCode:
  type: object
  additionalProperties: false
  required: [challenge_id, expires_at, resend_at]
  properties:
    challenge_id:
      type: string
      format: uuid
      description: Sent back with the code.
    expires_at:
      type: string
      format: date-time
    resend_at:
      type: string
      format: date-time
      description: The first moment another code to this address is allowed.
```

`api/paths/auth.yaml` gains:

```yaml
emailCodes:
  post:
    operationId: sendEmailCode
    summary: Mail a six-digit code to sign in, or sign up on first use, with an email address.
    description: |
      The reply is the same whether or not an account holds the address.
      The code lasts 5 minutes and takes 5 guesses. Limits: one code per
      address per 45 seconds, five per address per hour, twenty per client
      address per hour.
    tags: [auth]
    parameters:
      - $ref: "../parameters/common.yaml#/IdempotencyKey"
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/auth.yaml#/EmailCodeRequest"
    responses:
      "200":
        description: The code is on its way.
        content:
          application/json:
            schema:
              $ref: "../schemas/auth.yaml#/EmailCode"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "422":
        description: The address is not valid (invalid_email).
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "429":
        description: Too soon after the last code to this address (otp_too_soon), or over a limit (otp_limit); details.retry_after gives seconds.
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

`api/paths/account.yaml` gains:

```yaml
myEmailCodes:
  post:
    operationId: sendMyEmailCode
    summary: Mail a six-digit code that adds this email address to the caller's account.
    description: |
      The code works only for the caller's account, through
      POST /v1/accounts/me/identities. Limits as for sendEmailCode.
    tags: [account]
    security:
      - bearerAuth: []
    parameters:
      - $ref: "../parameters/common.yaml#/IdempotencyKey"
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/auth.yaml#/EmailCodeRequest"
    responses:
      "200":
        description: The code is on its way.
        content:
          application/json:
            schema:
              $ref: "../schemas/auth.yaml#/EmailCode"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "422":
        description: The address is not valid (invalid_email).
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "429":
        description: Too soon after the last code to this address (otp_too_soon), or over a limit (otp_limit); details.retry_after gives seconds.
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

`api/openapi.yaml` gains, after `/v1/auth/sign-in` and after `/v1/accounts/me` respectively:

```yaml
  /v1/auth/email-codes:
    $ref: "paths/auth.yaml#/emailCodes"
```

```yaml
  /v1/accounts/me/email-codes:
    $ref: "paths/account.yaml#/myEmailCodes"
```

Run: `go test -short ./api/` → PASS.

- [ ] **Step 2: Write the failing Restate service tests**

`internal/account/service/email_code_send_durable_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"net/netip"
	"sync"
	"testing"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"
	"github.com/restatedev/sdk-go/ingress"

	"github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/account/repository"
	"github.com/shopnexus/server/internal/account/service"
	"github.com/shopnexus/server/internal/platform/contact"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server/internal/platform/restatex/restatetest"
)

var testCodes = domain.NewCodes(make([]byte, 32))

// sentMail is one message a mailbox got.
type sentMail struct{ to, subject, body string }

// mailbox records mails; failFirst fails the first send once, as a
// provider timing out would.
type mailbox struct {
	mu        sync.Mutex
	sent      []sentMail
	failFirst bool
}

func (m *mailbox) Send(_ context.Context, to, subject, body string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.failFirst {
		m.failFirst = false
		return errors.New("provider timed out")
	}
	m.sent = append(m.sent, sentMail{to, subject, body})
	return nil
}

func (m *mailbox) all() []sentMail {
	m.mu.Lock()
	defer m.mu.Unlock()
	return append([]sentMail(nil), m.sent...)
}

type emailCodeEnv struct {
	run   ingress.Requester[service.EmailCodeInput, service.EmailCodeResult]
	mail  *mailbox
	clock *restatetest.Clock
}

func startEmailCodeSend(t *testing.T, mail *mailbox) *emailCodeEnv {
	t.Helper()
	db := pgtest.New(t)
	clock := restatetest.NewClock(now)
	svc := service.EmailCodeSend{
		Prefix: restatetest.Prefix(), Quotas: repository.NewQuotas(db), Challenges: repository.NewChallenges(db),
		Codes: testCodes, Email: mail, Now: clock.Now,
	}
	client := restatetest.Start(t, restate.Reflect(svc))
	return &emailCodeEnv{run: ingress.Service[service.EmailCodeInput, service.EmailCodeResult](client, svc.ServiceName(), "Run"), mail: mail, clock: clock}
}

func (e *emailCodeEnv) send(t *testing.T, to, ip string) service.EmailCodeResult {
	t.Helper()
	addr, err := contact.ParseEmail(to)
	if err != nil {
		t.Fatal(err)
	}
	res, err := e.run.Request(context.Background(),
		service.EmailCodeInput{Email: addr, Purpose: domain.PurposeSignIn, IP: netip.MustParseAddr(ip)},
		restate.WithIdempotencyKey(uuid.NewV7().String()))
	if err != nil {
		t.Fatal(err)
	}
	return res
}

func TestEmailCodeSendMailsTheCode(t *testing.T) {
	t.Parallel()
	e := startEmailCodeSend(t, &mailbox{})
	res := e.send(t, "linh@example.com", "203.0.113.1")
	code := testCodes.For(res.ChallengeID)
	got := e.mail.all()
	if res.Refused != nil || len(got) != 1 || got[0].to != "linh@example.com" ||
		got[0].subject != "Mã xác minh ShopNexus: "+code || !res.ExpiresAt.Equal(now.Add(5*time.Minute)) ||
		!res.ResendAt.Equal(now.Add(45*time.Second)) {
		t.Fatalf("%+v, mails %+v", res, got)
	}
}

func TestEmailCodeSendLimits(t *testing.T) {
	t.Parallel()
	e := startEmailCodeSend(t, &mailbox{})
	e.send(t, "linh@example.com", "203.0.113.1")
	if res := e.send(t, "linh@example.com", "203.0.113.1"); res.Refused == nil || res.Refused.Code != "otp_too_soon" ||
		res.Refused.Details["retry_after"] != 45 {
		t.Fatalf("resend: %+v", res)
	}
	for range 4 {
		e.clock.Add(46 * time.Second)
		if res := e.send(t, "linh@example.com", "203.0.113.1"); res.Refused != nil {
			t.Fatalf("send within the hour: %+v", res.Refused)
		}
	}
	e.clock.Add(46 * time.Second)
	if res := e.send(t, "linh@example.com", "203.0.113.1"); res.Refused == nil || res.Refused.Code != "otp_limit" {
		t.Fatalf("sixth send in an hour: %+v", res)
	}
}

func TestEmailCodeSendLimitsAnAddress(t *testing.T) {
	t.Parallel()
	e := startEmailCodeSend(t, &mailbox{})
	for n := range 20 {
		if res := e.send(t, "linh"+string(rune('a'+n))+"@example.com", "2001:db8::1"); res.Refused != nil {
			t.Fatalf("send %d: %+v", n, res.Refused)
		}
	}
	// Another host of the same /64 shares the quota.
	if res := e.send(t, "minh@example.com", "2001:db8::2"); res.Refused == nil || res.Refused.Code != "otp_limit" {
		t.Fatalf("twenty-first send: %+v", res)
	}
}

// A send that fails is retried by Restate and mails the same code: the
// code comes from the challenge ID, not from a fresh draw.
func TestEmailCodeSendRetriesTheSameCode(t *testing.T) {
	t.Parallel()
	e := startEmailCodeSend(t, &mailbox{failFirst: true})
	res := e.send(t, "linh@example.com", "203.0.113.1")
	got := e.mail.all()
	if res.Refused != nil || len(got) != 1 || got[0].subject != "Mã xác minh ShopNexus: "+testCodes.For(res.ChallengeID) {
		t.Fatalf("%+v, mails %+v", res, got)
	}
}
```

(`Details` is the `map[string]any` field of `apperr.Error`; if the retry-after value decodes as `float64` after the journal, compare with `float64(45)`.)

Run: `go test ./internal/account/service/ -run TestEmailCodeSend -count=1`
Expected: FAIL to compile: `service.EmailCodeSend` undefined.

- [ ] **Step 3: Write the Restate service**

`internal/account/service/email_code_send_durable.go` (the `admit`, rules and `addressKey` come from `17cf6bf3^:internal/auth/service/otp_send_durable.go`):

```go
package service

import (
	"fmt"
	"net/netip"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"

	"github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/account/repository"
	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/platform/contact"
	"github.com/shopnexus/server/internal/platform/restatex"
	"github.com/shopnexus/server/internal/provider/email"
)

// EmailCodeInput is an address to mail a code to. AccountID names the
// account an add_identity code is for and is nil for sign_in.
type EmailCodeInput struct {
	Email     contact.Address `json:"email"`
	Purpose   domain.Purpose  `json:"purpose"`
	AccountID *uuid.UUID      `json:"account_id,omitempty"`
	IP        netip.Addr      `json:"ip"`
}

// EmailCodeResult names the challenge the code belongs to. A refusal
// travels as data.
type EmailCodeResult struct {
	ChallengeID uuid.UUID     `json:"challenge_id"`
	ExpiresAt   time.Time     `json:"expires_at"`
	ResendAt    time.Time     `json:"resend_at"`
	Refused     *apperr.Error `json:"refused,omitempty"`
}

func (r EmailCodeResult) Refusal() *apperr.Error { return r.Refused }

// EmailCodeSend mails sign-in and add-identity codes. It knows nothing of
// accounts, so its answer is the same whether or not one holds the address.
type EmailCodeSend struct {
	Prefix     string
	Quotas     repository.Quotas
	Challenges repository.Challenges
	Codes      domain.Codes
	Email      email.Sender
	Now        func() time.Time
}

// emailCodeSendService is the EmailCodeSend service's name without the prefix.
const emailCodeSendService = "EmailCodeSend"

func (s EmailCodeSend) ServiceName() string { return s.Prefix + emailCodeSendService }

func (s EmailCodeSend) Run(ctx restate.Context, in EmailCodeInput) (EmailCodeResult, error) {
	at, err := restatex.Now(ctx, s.Now)
	if err != nil {
		return EmailCodeResult{}, err
	}
	// The client address goes first, so an address over its limit cannot
	// spend the quota of the mailboxes it names. A quota that admitted the
	// send stays spent even when a later step fails.
	if refused, err := admit(ctx, s.Quotas, addressKey(in.IP), at, addressRules); err != nil || refused != nil {
		return EmailCodeResult{Refused: refused}, err
	}
	if refused, err := admit(ctx, s.Quotas, "dest:"+in.Email.Value(), at, destinationRules); err != nil || refused != nil {
		return EmailCodeResult{Refused: refused}, err
	}
	// The code is derived from the challenge ID, so a retried send step
	// mails the same code and the code is never stored or journaled.
	id := restatex.NewID(ctx, at)
	c := domain.NewChallenge(id, in.Purpose, in.Email, in.AccountID, in.IP, s.Codes.Hash(in.Email, s.Codes.For(id)), at)
	if err := restate.RunVoid(ctx, func(rc restate.RunContext) error { return s.Challenges.Create(rc, c) }); err != nil {
		return EmailCodeResult{}, fmt.Errorf("create challenge: %w", err)
	}
	if err := restate.RunVoid(ctx, func(rc restate.RunContext) error {
		code := s.Codes.For(id)
		body := "Mã xác minh ShopNexus của bạn là " + code + ". Mã hết hạn sau 5 phút. Không chia sẻ mã này với ai."
		if stepErr := s.Email.Send(rc, in.Email.Value(), "Mã xác minh ShopNexus: "+code, body); stepErr != nil {
			return fmt.Errorf("mail the code: %w", stepErr)
		}
		codesSent.Add(rc, 1)
		return nil
	}); err != nil {
		return EmailCodeResult{}, fmt.Errorf("send code: %w", err)
	}
	return EmailCodeResult{ChallengeID: id, ExpiresAt: c.ExpiresAt(), ResendAt: at.Add(resend.Window)}, nil
}

// admit spends one send from the quota at key. It reads the quota in one
// step, decides between steps and saves in another, so a retried save does
// not count the send twice. It retries a lost race three times, so parallel
// sends behind one NAT do not get a spurious 429.
func admit(ctx restate.Context, quotas repository.Quotas, key string, at time.Time, rules []domain.Rule) (*apperr.Error, error) {
	for range 3 {
		q, err := restate.Run(ctx, func(rc restate.RunContext) (domain.Quota, error) {
			q, stepErr := quotas.Get(rc, key)
			if stepErr != nil {
				return domain.Quota{}, fmt.Errorf("get quota: %w", stepErr)
			}
			return q, nil
		})
		if err != nil {
			return nil, fmt.Errorf("load quota: %w", err)
		}
		rule, wait, ok := q.Admit(at, rules...)
		if !ok {
			refused := domain.ErrOTPLimit
			if rule == resend {
				refused = domain.ErrOTPTooSoon
			}
			return refused.WithRetryAfter(wait), nil
		}
		w := restatex.NewID(ctx, at)
		lost, err := restate.Run(ctx, func(rc restate.RunContext) (bool, error) {
			q := q // Save sets the write ID on its copy; q outside stays as journaled
			return restatex.Outcome(quotas.Save(rc, &q, w), repository.ErrConflict)
		})
		if err != nil {
			return nil, fmt.Errorf("save quota: %w", err)
		}
		if !lost {
			return nil, nil //nolint:nilnil // A nil refusal means the send was admitted.
		}
	}
	// The racing sends finish within a second.
	return domain.ErrOTPLimit.WithRetryAfter(time.Second), nil
}

var (
	// resend refuses with domain.ErrOTPTooSoon; every other rule with
	// domain.ErrOTPLimit.
	resend           = domain.Rule{Window: 45 * time.Second, Max: 1}
	destinationRules = []domain.Rule{resend, {Window: time.Hour, Max: 5}}
	addressRules     = []domain.Rule{{Window: time.Hour, Max: 20}}
)

// addressKey limits an IPv6 client by its /64, the block one host usually
// holds.
func addressKey(ip netip.Addr) string {
	if ip.Is4() {
		return "ip:" + ip.String()
	}
	p, _ := ip.Prefix(64)
	return "ip:" + p.String()
}
```

`internal/account/service/metrics.go` gains a counter beside the existing ones, built the same way (copy the existing instrument's `telemetry.Must(otel.Meter(...).Int64Counter(...))` shape):

```go
// codesSent counts mailed codes: otp_sent_total.
var codesSent = telemetry.Must(otel.Meter("github.com/shopnexus/server/internal/account").
	Int64Counter("otp_sent_total", metric.WithDescription("Email codes mailed.")))
```

Run: `go test ./internal/account/service/ -run TestEmailCodeSend -count=1` → PASS.

- [ ] **Step 4: The use case**

`views.go` gains:

```go
// SendEmailCodeInput is an address as the person typed it. AccountID is the
// signed-in caller for an add-identity code and nil for a sign-in code.
type SendEmailCodeInput struct {
	IdempotencyKey string
	Email          string
	AccountID      *uuid.UUID
	IP             netip.Addr
}

// EmailCodeView is the EmailCode schema in api/schemas/auth.yaml.
type EmailCodeView struct {
	ChallengeID uuid.UUID `json:"challenge_id"`
	ExpiresAt   time.Time `json:"expires_at"`
	ResendAt    time.Time `json:"resend_at"`
}
```

`internal/account/service/email_code_send.go`:

```go
package service

import (
	"context"

	"github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/platform/contact"
)

// SendEmailCode mails a code to the address through the EmailCodeSend
// service. The invocation key holds the purpose's owner and the address, so
// a key sent again for another address or account runs apart.
func (s *Account) SendEmailCode(ctx context.Context, in SendEmailCodeInput) (EmailCodeView, error) {
	addr, err := contact.ParseEmail(in.Email)
	if err != nil {
		return EmailCodeView{}, err //nolint:wrapcheck // contact.ErrInvalidEmail is the client's answer.
	}
	purpose, owner := domain.PurposeSignIn, "-"
	if in.AccountID != nil {
		purpose, owner = domain.PurposeAddIdentity, in.AccountID.String()
	}
	res, err := s.emailCodeSend.Call(ctx, owner+"/"+addr.Value()+"/"+in.IdempotencyKey,
		EmailCodeInput{Email: addr, Purpose: purpose, AccountID: in.AccountID, IP: in.IP})
	if err != nil {
		return EmailCodeView{}, err
	}
	return EmailCodeView{ChallengeID: res.ChallengeID, ExpiresAt: res.ExpiresAt, ResendAt: res.ResendAt}, nil
}
```

`service.go`:

- `Service` gains:

```go
	// SendEmailCode mails a six-digit code to an address: a sign-in code,
	// or with AccountID one that adds the address to that account.
	SendEmailCode(ctx context.Context, in SendEmailCodeInput) (EmailCodeView, error)
```

- `Deps` gains `Challenges repository.Challenges`, `Quotas repository.Quotas`, `Codes domain.Codes` and `Email email.Sender`; `Account` gains the same as unexported fields and `emailCodeSend restatex.Caller[EmailCodeInput, EmailCodeResult]`; `New` sets them, with

```go
		emailCodeSend: restatex.Caller[EmailCodeInput, EmailCodeResult]{Ingress: d.Ingress, Service: d.Prefix + emailCodeSendService, Handler: "Run"},
```

- `Durable` appends

```go
		restate.Reflect(EmailCodeSend{Prefix: s.prefix, Quotas: s.quotas, Challenges: s.challenges, Codes: s.codes, Email: s.email, Now: s.now}),
```

`account.go` (`Mount`) passes `Challenges: repository.NewChallenges(d.Pool), Quotas: repository.NewQuotas(d.Pool), Codes: domain.NewCodes(s.Keys.OTPKey), Email: s.Email` into `service.Deps`. The package docs of `account` and `service` say sign-in is by a phone number Firebase verified, an email code or a Google account.

- [ ] **Step 5: The handlers**

`internal/account/handler/email_code_send.go`:

```go
package handler

import (
	"net/http"

	"github.com/shopnexus/server/internal/account/service"
	"github.com/shopnexus/server/internal/platform/httpx"
)

type emailCodeRequest struct {
	IdempotencyKey string `header:"Idempotency-Key" json:"-"`
	Email          string `json:"email"`
}

// SendEmailCode serves POST /v1/auth/email-codes.
func (h *Handler) SendEmailCode(w http.ResponseWriter, r *http.Request) {
	var in emailCodeRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	v, err := h.svc.SendEmailCode(r.Context(), service.SendEmailCodeInput{
		IdempotencyKey: in.IdempotencyKey, Email: in.Email, IP: httpx.ClientIP(r),
	})
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, v)
}

// SendMyEmailCode serves POST /v1/accounts/me/email-codes.
func (h *Handler) SendMyEmailCode(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in emailCodeRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	v, err := h.svc.SendEmailCode(r.Context(), service.SendEmailCodeInput{
		IdempotencyKey: in.IdempotencyKey, Email: in.Email, AccountID: &p.AccountID, IP: httpx.ClientIP(r),
	})
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, v)
}
```

`Register` gains, after the sign-in route and after `PATCH /v1/accounts/me`:

```go
	r.Handle("POST /v1/auth/email-codes", http.HandlerFunc(h.SendEmailCode))
```

```go
	r.Handle("POST /v1/accounts/me/email-codes", protect(http.HandlerFunc(h.SendMyEmailCode)))
```

- [ ] **Step 6: The e2e tests**

`e2e/email_code_test.go`:

```go
package e2e

import (
	"fmt"
	"testing"
)

// newEmail returns a fresh address.
func newEmail() string { return fmt.Sprintf("linh%d@e2e.test", seq.Add(1)) }

type emailCode struct {
	ChallengeID string `json:"challenge_id"`
	ExpiresAt   string `json:"expires_at"`
	ResendAt    string `json:"resend_at"`
}

// sendEmailCode mails a sign-in code to addr and returns its challenge and
// the code the inbox got.
func sendEmailCode(t *testing.T, addr string) (challengeID, code string) {
	t.Helper()
	n := mails.count(addr)
	c := expect[emailCode](t, call(t, "POST", "/v1/auth/email-codes", map[string]string{"email": addr}, newKey()), 200)
	return c.ChallengeID, mails.code(t, addr, n+1)
}

func TestSendEmailCode(t *testing.T) {
	t.Parallel()
	addr := newEmail()
	id, code := sendEmailCode(t, addr)
	if id == "" || len(code) != 6 {
		t.Fatalf("challenge %q, code %q", id, code)
	}
	if res := call(t, "POST", "/v1/auth/email-codes", map[string]string{"email": addr}, newKey()); res.Status != 429 ||
		errorOf(t, res).Code != "otp_too_soon" {
		t.Fatalf("resend: %d %s", res.Status, res.Body)
	}
	check(t, "invalid email", call(t, "POST", "/v1/auth/email-codes", map[string]string{"email": "not an address"}, newKey()), 422, "invalid_email")
	check(t, "no key", call(t, "POST", "/v1/auth/email-codes", map[string]string{"email": newEmail()}), 400, "")
}

func TestSendMyEmailCode(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	addr := newEmail()
	expect[emailCode](t, call(t, "POST", "/v1/accounts/me/email-codes", map[string]string{"email": addr}, newKey(), bearer(me.AccessToken)), 200)
	if mails.count(addr) != 1 {
		t.Fatalf("%d mails", mails.count(addr))
	}
	check(t, "resend", call(t, "POST", "/v1/accounts/me/email-codes", map[string]string{"email": addr}, newKey(), bearer(me.AccessToken)), 429, "otp_too_soon")
	check(t, "invalid email", call(t, "POST", "/v1/accounts/me/email-codes", map[string]string{"email": "x@y"}, newKey(), bearer(me.AccessToken)), 422, "invalid_email")
	check(t, "no key", call(t, "POST", "/v1/accounts/me/email-codes", map[string]string{"email": newEmail()}, bearer(me.AccessToken)), 400, "")
	check(t, "signed out", call(t, "POST", "/v1/accounts/me/email-codes", map[string]string{"email": newEmail()}, newKey()), 401, "")
}
```

(`check` with an empty code checks the status only, as `TestSignInRefusals` uses it. Many e2e tests share the client address 127.0.0.1, whose quota is twenty sends an hour: if the run trips `otp_limit`, give each sending test its own `X-Forwarded-For` header, `[2]string{"X-Forwarded-For", fmt.Sprintf("198.51.100.%d", seq.Add(1)%250)}`, which `TrustedProxies` honours.)

- [ ] **Step 7: Run everything**

Run: `make test`
Expected: PASS, with no "declared responses no test observed" lines.

- [ ] **Step 8: Commit**

```bash
git add -A api internal/account e2e
git commit -m "feat(account): mail sign-in and add-email codes, POST /v1/auth/email-codes and /v1/accounts/me/email-codes"
```

---

### Task 6: Google ID token checks

**Files:**
- Create: `internal/provider/google/verifier.go`, `internal/provider/google/verifier_test.go`, `internal/provider/google/googletest/googletest.go`
- Modify: `internal/platform/config/config.go`, `config_test.go`, `.env.example`, `.golangci.yml`, `internal/app/app_test.go`, `e2e/main_test.go`

**Interfaces:**
- Consumes: Task 1 `jwks.New`, `jwks.ErrUnavailable`.
- Produces: `config.GoogleConfig{ClientID, JWKSURL string}`, `config.Config.Google`; `google.NewVerifier(cfg config.GoogleConfig, now func() time.Time, log *slog.Logger) *google.Verifier`; `(*Verifier).Verify(ctx context.Context, token string) (contact.Address, error)`; `google.ErrInvalidToken` (401 `invalid_google_token`); `googletest.New(tb) *googletest.Issuer`, `NewForMain() (*Issuer, func(), error)`, `(*Issuer).Config() config.GoogleConfig`, `(*Issuer).Token(email string, opts ...googletest.Option) string`, options `Claim`, `Drop`, `SignedWith`, `(*Issuer).Now` field.

- [ ] **Step 1: Configuration**

`config.go` gains after `EmailConfig`:

```go
// GoogleConfig names the OAuth client whose Google ID tokens sign in.
type GoogleConfig struct {
	ClientID string // GOOGLE_CLIENT_ID: the Web client ID the app passes to Credential Manager; empty turns Google sign-in off
	JWKSURL  string // GOOGLE_JWKS_URL: the keys of Google's ID tokens
}
```

`Config` gains `Google GoogleConfig`, and `Load`:

```go
		Google: GoogleConfig{ClientID: set("GOOGLE_CLIENT_ID"), JWKSURL: need("GOOGLE_JWKS_URL")},
```

`config_test.go`: `required()` gains `"GOOGLE_CLIENT_ID": "web.apps.googleusercontent.com"` and `"GOOGLE_JWKS_URL": "https://www.googleapis.com/oauth2/v3/certs"`, and the expected config of `TestLoadAllSet` the matching `Google: GoogleConfig{...}`.

`.env.example` gains:

```
# The Web OAuth client of the Firebase project, created when the Google
# provider is turned on; the app passes the same ID as serverClientId.
# Empty turns Google sign-in off.
GOOGLE_CLIENT_ID=
GOOGLE_JWKS_URL=https://www.googleapis.com/oauth2/v3/certs
```

Run: `go test -short ./internal/platform/config/` → PASS.

- [ ] **Step 2: The test issuer**

`internal/provider/google/googletest/googletest.go`:

```go
// Package googletest signs Google ID tokens with a key it serves from an
// httptest JWKS endpoint, for tests of Google sign-in.
package googletest

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"maps"
	"math/big"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/shopnexus/server/internal/platform/config"
)

const (
	clientID = "shopnexus-test.apps.googleusercontent.com"
	kid      = "google-1"
)

// Issuer holds the RSA key Google signs ID tokens with and serves it.
type Issuer struct {
	// Now is the time tokens are issued at; time.Now unless a test sets it.
	Now  func() time.Time
	key  *rsa.PrivateKey
	srv  *httptest.Server
	down atomic.Bool
}

// New starts the key server; t's cleanup stops it.
func New(tb testing.TB) *Issuer {
	tb.Helper()
	i, stop, err := NewForMain()
	if err != nil {
		tb.Fatal(err)
	}
	tb.Cleanup(stop)
	return i
}

// NewForMain is New for TestMain, which has no t; call stop when done.
func NewForMain() (i *Issuer, stop func(), err error) {
	k, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, nil, fmt.Errorf("rsa key: %w", err)
	}
	enc := base64.RawURLEncoding.EncodeToString
	body, _ := json.Marshal(map[string]any{"keys": []any{map[string]string{ //nolint:errchkjson // a map of strings marshals
		"kty": "RSA", "alg": "RS256", "use": "sig", "kid": kid, "n": enc(k.N.Bytes()), "e": enc(big.NewInt(int64(k.E)).Bytes()),
	}}})
	i = &Issuer{Now: time.Now, key: k}
	i.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		if i.down.Load() {
			http.Error(w, "down", http.StatusServiceUnavailable)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Cache-Control", "public, max-age=3600")
		_, _ = w.Write(body)
	}))
	return i, i.srv.Close, nil
}

// Config points a server at this key.
func (i *Issuer) Config() config.GoogleConfig {
	return config.GoogleConfig{ClientID: clientID, JWKSURL: i.srv.URL}
}

// SetDown makes the key URL answer 503.
func (i *Issuer) SetDown(down bool) { i.down.Store(down) }

type token struct {
	method jwt.SigningMethod
	key    any
	claims jwt.MapClaims
}

type Option func(*token)

func Claim(name string, value any) Option { return func(t *token) { t.claims[name] = value } }
func Drop(name string) Option             { return func(t *token) { delete(t.claims, name) } }

// SignedWith signs with another method and key; the kid stays.
func SignedWith(method jwt.SigningMethod, key any) Option {
	return func(t *token) { t.method, t.key = method, key }
}

// Token is a Google ID token for a verified email, issued now.
func (i *Issuer) Token(email string, opts ...Option) string {
	now := i.Now()
	t := token{method: jwt.SigningMethodRS256, key: i.key, claims: jwt.MapClaims{
		"iss": "https://accounts.google.com", "aud": clientID, "azp": "android-client", "sub": "1" + fmt.Sprint(now.UnixNano()),
		"iat": now.Unix(), "exp": now.Add(time.Hour).Unix(), "email": email, "email_verified": true,
	}}
	for _, o := range opts {
		o(&t)
	}
	tok := jwt.NewWithClaims(t.method, t.claims)
	maps.Copy(tok.Header, map[string]any{"kid": kid})
	s, err := tok.SignedString(t.key)
	if err != nil {
		panic(fmt.Sprintf("googletest: sign: %v", err)) // an option built a token no key signs: a test bug
	}
	return s
}
```

`.golangci.yml`: beside the `firebasetest` deny entry, add

```yaml
            - pkg: github.com/shopnexus/server/internal/provider/google/googletest
              desc: test support; only tests import it.
```

- [ ] **Step 3: Write the failing verifier tests**

`internal/provider/google/verifier_test.go`:

```go
package google_test

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"errors"
	"log/slog"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/shopnexus/server/internal/provider/google"
	"github.com/shopnexus/server/internal/provider/google/googletest"
	"github.com/shopnexus/server/internal/provider/jwks"
)

var at = time.Date(2026, 11, 10, 9, 0, 0, 0, time.UTC)

func issuer(t *testing.T) *googletest.Issuer {
	t.Helper()
	i := googletest.New(t)
	i.Now = func() time.Time { return at }
	return i
}

func verifier(i *googletest.Issuer) *google.Verifier {
	return google.NewVerifier(i.Config(), func() time.Time { return at }, slog.New(slog.DiscardHandler))
}

func TestVerifyGoogleToken(t *testing.T) {
	t.Parallel()
	i := issuer(t)
	for _, iss := range []string{"https://accounts.google.com", "accounts.google.com"} {
		a, err := verifier(i).Verify(context.Background(), i.Token("Linh@Gmail.com", googletest.Claim("iss", iss)))
		if err != nil || a.Value() != "linh@gmail.com" {
			t.Errorf("iss %s: %v %v", iss, a, err)
		}
	}
}

func TestVerifyGoogleTokenRefuses(t *testing.T) {
	t.Parallel()
	i := issuer(t)
	stranger, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	for name, opt := range map[string]googletest.Option{
		"another key":        googletest.SignedWith(jwt.SigningMethodRS256, stranger),
		"hmac":               googletest.SignedWith(jwt.SigningMethodHS256, []byte("secret")),
		"another issuer":     googletest.Claim("iss", "https://evil.example"),
		"another client":     googletest.Claim("aud", "other.apps.googleusercontent.com"),
		"expired":            googletest.Claim("exp", at.Add(-time.Minute).Unix()),
		"no expiry":          googletest.Drop("exp"),
		"issued 6 min ago":   googletest.Claim("iat", at.Add(-6*time.Minute).Unix()),
		"issued in a minute": googletest.Claim("iat", at.Add(time.Minute).Unix()),
		"email not verified": googletest.Claim("email_verified", false),
		"no email":           googletest.Drop("email"),
		"no address":         googletest.Claim("email", "linh"),
	} {
		if _, err := verifier(i).Verify(context.Background(), i.Token("linh@gmail.com", opt)); !errors.Is(err, google.ErrInvalidToken) {
			t.Errorf("%s: %v", name, err)
		}
	}
	if _, err := verifier(i).Verify(context.Background(), "not.a.token"); !errors.Is(err, google.ErrInvalidToken) {
		t.Errorf("malformed: %v", err)
	}
}

// Without GOOGLE_CLIENT_ID every token is refused.
func TestVerifyGoogleTokenWhenOff(t *testing.T) {
	t.Parallel()
	i := issuer(t)
	cfg := i.Config()
	cfg.ClientID = ""
	v := google.NewVerifier(cfg, func() time.Time { return at }, slog.New(slog.DiscardHandler))
	if _, err := v.Verify(context.Background(), i.Token("linh@gmail.com")); !errors.Is(err, google.ErrInvalidToken) {
		t.Fatalf("%v", err)
	}
}

func TestVerifyGoogleTokenWithoutKeys(t *testing.T) {
	t.Parallel()
	i := issuer(t)
	i.SetDown(true)
	if _, err := verifier(i).Verify(context.Background(), i.Token("linh@gmail.com")); !errors.Is(err, jwks.ErrUnavailable) {
		t.Fatalf("%v", err)
	}
}
```

Run: `go test -short ./internal/provider/google/...`
Expected: FAIL to compile: `google.NewVerifier` undefined.

- [ ] **Step 4: The verifier**

`internal/provider/google/verifier.go`:

```go
// Package google checks the ID tokens Google issues to the app through
// Android Credential Manager. A token proves an email address.
package google

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/platform/config"
	"github.com/shopnexus/server/internal/platform/contact"
	"github.com/shopnexus/server/internal/provider/jwks"
)

const (
	// freshFor is how long after issue a token signs in, as for phone tokens.
	freshFor = 5 * time.Minute
	skew     = 30 * time.Second
)

// ErrInvalidToken is a token that failed a check; the log says which.
var ErrInvalidToken = apperr.New(apperr.KindUnauthenticated, "invalid_google_token",
	"the Google token is not valid; sign in with Google again")

// Verifier checks the ID tokens of one OAuth client.
type Verifier struct {
	cfg  config.GoogleConfig
	keys *jwks.Set
	now  func() time.Time
	log  *slog.Logger
}

func NewVerifier(cfg config.GoogleConfig, now func() time.Time, log *slog.Logger) *Verifier {
	return &Verifier{cfg: cfg, keys: jwks.New(cfg.JWKSURL, now, log), now: now, log: log}
}

type claims struct {
	jwt.RegisteredClaims

	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
}

// Verify returns the email address token proves: RS256 with a key of
// Google's, the client ID as audience, Google as issuer, issued less than 5
// minutes ago and the address verified. A failed check is ErrInvalidToken;
// keys that cannot be fetched are jwks.ErrUnavailable.
func (v *Verifier) Verify(ctx context.Context, token string) (contact.Address, error) {
	refuse := func(why string, err error) (contact.Address, error) {
		if errors.Is(err, jwks.ErrUnavailable) {
			return contact.Address{}, jwks.ErrUnavailable
		}
		v.log.InfoContext(ctx, "google token refused", "why", why, "err", err)
		return contact.Address{}, ErrInvalidToken
	}
	if v.cfg.ClientID == "" {
		return refuse("GOOGLE_CLIENT_ID is empty: Google sign-in is off", nil)
	}
	var c claims
	_, err := jwt.NewParser(jwt.WithValidMethods([]string{"RS256"}), jwt.WithAudience(v.cfg.ClientID),
		jwt.WithExpirationRequired(), jwt.WithIssuedAt(), jwt.WithLeeway(skew), jwt.WithTimeFunc(v.now),
	).ParseWithClaims(token, &c, func(t *jwt.Token) (any, error) {
		kid, _ := t.Header["kid"].(string) //nolint:revive // a token without a kid finds no key
		return v.keys.Key(ctx, kid)
	})
	if err != nil {
		return refuse("signature or claims", err)
	}
	switch {
	case c.Issuer != "accounts.google.com" && c.Issuer != "https://accounts.google.com":
		return refuse("issuer", nil)
	case c.IssuedAt == nil || v.now().Sub(c.IssuedAt.Time) > freshFor:
		return refuse("not issued in the last 5 minutes", nil)
	case !c.EmailVerified:
		return refuse("email not verified", nil)
	}
	a, err := contact.ParseEmail(c.Email)
	if err != nil {
		return refuse("email", err)
	}
	return a, nil
}
```

Run: `go test -short ./internal/provider/google/...` → PASS.

- [ ] **Step 5: Test configurations**

`internal/app/app_test.go`'s `testConfig` gains `Google: googletest.New(t).Config(),`. `e2e/main_test.go` gains a package variable `google *googletest.Issuer // signs Google ID tokens; the server's key URL points at it`, set in `setup` from `googletest.NewForMain()` with its stop appended to `closers`, and the config literal gains `Google: google.Config(),`. (`app.New` builds the verifier in Task 7; until then the field is only carried.)

Run: `make test` → PASS.

- [ ] **Step 6: Commit**

```bash
git add -A internal/provider/google internal/platform/config .env.example .golangci.yml internal/app e2e
git commit -m "feat(provider): check Google ID tokens of the app's OAuth client"
```

---

### Task 7: Sign in with any of the three proofs

**Files:**
- Create: `internal/account/service/code_guess.go`, `internal/account/handler/proof.go`, `e2e/auth_email_google_test.go`
- Modify: `internal/account/service/sign_in.go`, `sign_in_durable.go`, `sign_in_durable_test.go`, `views.go`, `service.go`, `internal/account/account.go`, `internal/account/handler/sign_in.go`, `internal/app/app.go`, `api/paths/auth.yaml`, `api/schemas/auth.yaml`, `e2e/auth_helpers_test.go`

**Interfaces:**
- Consumes: Task 4 `Challenges`, `Codes`, `Challenge.Open`, `Challenge.Verify`; Task 6 `google.NewVerifier`.
- Produces:
  - `service.Proof{PhoneToken, GoogleToken string; EmailCode *EmailCode}`, `service.EmailCode{ChallengeID uuid.UUID; Code string}`.
  - `service.SignInInput{IdempotencyKey string; Proof Proof; DeviceName string}`.
  - Restate input `service.ProvenSignIn{Address *contact.Address "address,omitempty"; Guess *CodeGuess "guess,omitempty"}`, `service.CodeGuess{ChallengeID uuid.UUID "challenge_id"; CodeHash []byte "code_hash"}`. `PhoneSignIn` is gone.
  - `service.GoogleVerifier` interface (`Verify(ctx, token) (contact.Address, error)`), `Deps.Google`, `account.Settings.Google`.
  - In `code_guess.go`: `judgeGuess(ctx restate.Context, challenges repository.Challenges, g CodeGuess, purpose domain.Purpose, owner *uuid.UUID, at time.Time) (contact.Address, *apperr.Error, error)`; `(*Account).verifyToken(ctx, p Proof) (contact.Address, error)`; `(*Account).guessFor(ctx, code EmailCode) (CodeGuess, bool, error)` (the bool says the code matches the challenge).
  - In the handler: `proofBody` with `proof() service.Proof`.

- [ ] **Step 1: Write the failing Restate tests**

In `sign_in_durable_test.go`:

- `startSignIn` builds `service.SignIn{..., Challenges: repository.NewChallenges(db), ...}`; `signInEnv` gains `challenges repository.Challenges`; the requester type becomes `ingress.Requester[service.ProvenSignIn, service.SignInResult]`.
- `signIn(t, raw)` sends `service.ProvenSignIn{Address: ptr(phone(t, raw))}`; add `func ptr[T any](v T) *T { return &v }` to `helpers_test.go`, and `email(t, raw)` beside `phone`:

```go
func email(t *testing.T, raw string) contact.Address {
	t.Helper()
	a, err := contact.ParseEmail(raw)
	if err != nil {
		t.Fatal(err)
	}
	return a
}
```

- `TestSignInReplayedKey` builds `service.ProvenSignIn{Address: ptr(phone(t, "0901234567"))}`.

Then add:

```go
// challenge stores a code challenge for to, returning it and its code.
func (e *signInEnv) challenge(t *testing.T, to string, purpose domain.Purpose, owner *uuid.UUID) (domain.Challenge, string) {
	t.Helper()
	id := uuid.NewV7()
	dest := email(t, to)
	code := testCodes.For(id)
	c := domain.NewChallenge(id, purpose, dest, owner, netip.MustParseAddr("127.0.0.1"), testCodes.Hash(dest, code), e.clock.Now())
	if err := e.challenges.Create(context.Background(), c); err != nil {
		t.Fatal(err)
	}
	return c, code
}

func (e *signInEnv) guess(t *testing.T, c domain.Challenge, code string) service.SignInResult {
	t.Helper()
	res, err := e.run.Request(context.Background(),
		service.ProvenSignIn{Guess: &service.CodeGuess{ChallengeID: c.ID(), CodeHash: testCodes.Hash(c.Destination(), code)}},
		restate.WithIdempotencyKey(uuid.NewV7().String()))
	if err != nil {
		t.Fatal(err)
	}
	return res
}

func TestSignInByEmailCode(t *testing.T) {
	t.Parallel()
	e := startSignIn(t)
	c, code := e.challenge(t, "linh@example.com", domain.PurposeSignIn, nil)
	first := e.guess(t, c, code)
	if first.Refused != nil || !first.IsNew {
		t.Fatalf("%+v", first)
	}
	c2, code2 := e.challenge(t, "linh@example.com", domain.PurposeSignIn, nil)
	second := e.guess(t, c2, code2)
	if second.Refused != nil || second.IsNew || second.AccountID != first.AccountID {
		t.Fatalf("second %+v", second)
	}
	var kind string
	e.db.QueryRow(context.Background(), `SELECT kind FROM identities WHERE account_id = @id`,
		pgx.StrictNamedArgs{"id": first.AccountID}).Scan(&kind)
	if kind != "email" {
		t.Fatalf("kind %q", kind)
	}
}

func TestSignInByEmailCodeRefusals(t *testing.T) {
	t.Parallel()
	e := startSignIn(t)
	c, code := e.challenge(t, "linh@example.com", domain.PurposeSignIn, nil)
	wrong := "000000"
	if wrong == code {
		wrong = "111111"
	}
	res := e.guess(t, c, wrong)
	if res.Refused == nil || res.Refused.Code != "invalid_code" {
		t.Fatalf("wrong code: %+v", res)
	}
	for range domain.MaxAttempts - 1 {
		res = e.guess(t, c, wrong)
	}
	refused(t, res, "code_locked")
	refused(t, e.guess(t, c, code), "code_locked")

	c2, code2 := e.challenge(t, "minh@example.com", domain.PurposeSignIn, nil)
	e.clock.Add(domain.CodeTTL)
	refused(t, e.guess(t, c2, code2), "code_expired")

	// A newer code to the same address replaces the older one.
	e.clock.Add(time.Minute)
	old, oldCode := e.challenge(t, "an@example.com", domain.PurposeSignIn, nil)
	e.clock.Add(time.Second)
	e.challenge(t, "an@example.com", domain.PurposeSignIn, nil)
	refused(t, e.guess(t, old, oldCode), "code_expired")
}

func TestSignInRefusesAnAddIdentityChallenge(t *testing.T) {
	t.Parallel()
	e := startSignIn(t)
	owner := e.signIn(t, "0901234567").AccountID
	c, code := e.challenge(t, "linh@example.com", domain.PurposeAddIdentity, &owner)
	refused(t, e.guess(t, c, code), "code_expired")
}

func TestSignInByGoogleFindsTheEmailAccount(t *testing.T) {
	t.Parallel()
	e := startSignIn(t)
	c, code := e.challenge(t, "linh@gmail.com", domain.PurposeSignIn, nil)
	byCode := e.guess(t, c, code)
	res, err := e.run.Request(context.Background(), service.ProvenSignIn{Address: ptr(email(t, "Linh@Gmail.com"))},
		restate.WithIdempotencyKey(uuid.NewV7().String()))
	if err != nil || res.Refused != nil || res.IsNew || res.AccountID != byCode.AccountID || e.count(t, "accounts") != 1 {
		t.Fatalf("%+v %v", res, err)
	}
}
```

`testCodes` is the variable Task 5 put in `email_code_send_durable_test.go`; add `"net/netip"` and the `domain` import as needed.

Run: `go test ./internal/account/service/ -run TestSignIn -count=1`
Expected: FAIL to compile: `service.ProvenSignIn` undefined.

- [ ] **Step 2: The shared guess judge**

`internal/account/service/code_guess.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"

	"github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/account/repository"
	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/platform/contact"
	"github.com/shopnexus/server/internal/platform/restatex"
)

// CodeGuess is a guess at an email code as Restate sees it: the challenge
// and the code's HMAC, never the code, because Restate keeps inputs in its
// journal.
type CodeGuess struct {
	ChallengeID uuid.UUID `json:"challenge_id"`
	CodeHash    []byte    `json:"code_hash"`
}

// loadedChallenge is the challenge as the judging step read it.
type loadedChallenge struct {
	Challenge domain.Challenge `json:"challenge"`
	Found     bool             `json:"found"`
	Newest    bool             `json:"newest"`
}

// judgeGuess judges g on the challenge as one step read it and saves the
// counted guess in the next: a refused guess changes nothing and is not
// saved, and a guess that loses a race gets try_again, right or wrong, and
// is not counted. A challenge that is unknown, replaced by a newer one to
// its address, of another purpose or of another account than owner is
// code_expired. SignIn and AddIdentity call it; it returns the address the
// right code proves.
func judgeGuess(ctx restate.Context, challenges repository.Challenges, g CodeGuess, purpose domain.Purpose,
	owner *uuid.UUID, at time.Time,
) (contact.Address, *apperr.Error, error) {
	l, err := restate.Run(ctx, func(rc restate.RunContext) (loadedChallenge, error) {
		c, stepErr := challenges.Get(rc, g.ChallengeID)
		if errors.Is(stepErr, repository.ErrNotFound) {
			return loadedChallenge{}, nil
		}
		if stepErr != nil {
			return loadedChallenge{}, fmt.Errorf("get challenge: %w", stepErr)
		}
		newest, stepErr := challenges.IsNewest(rc, c)
		if stepErr != nil {
			return loadedChallenge{}, fmt.Errorf("check newest challenge: %w", stepErr)
		}
		return loadedChallenge{Challenge: c, Found: true, Newest: newest}, nil
	})
	if err != nil {
		return contact.Address{}, nil, fmt.Errorf("load challenge: %w", err)
	}
	c := l.Challenge
	sameOwner := (owner == nil && c.AccountID() == nil) || (owner != nil && c.AccountID() != nil && *owner == *c.AccountID())
	if !l.Found || !l.Newest || c.Purpose() != purpose || !sameOwner {
		return contact.Address{}, domain.ErrCodeExpired, nil
	}
	if err = c.Open(at); err != nil {
		return contact.Address{}, apperr.From(err), nil
	}
	verdict := c.Verify(g.CodeHash, at)
	w := restatex.NewID(ctx, at)
	lost, err := restate.Run(ctx, func(rc restate.RunContext) (bool, error) {
		c := c // Save sets the write ID on its copy; c outside stays as journaled
		return restatex.Outcome(challenges.Save(rc, &c, w), repository.ErrConflict)
	})
	if err != nil {
		return contact.Address{}, nil, fmt.Errorf("save guess: %w", err)
	}
	if lost {
		return contact.Address{}, apperr.ErrTryAgain, nil
	}
	if verdict != nil {
		return contact.Address{}, apperr.From(verdict), nil
	}
	return c.Destination(), nil, nil
}

// verifyToken checks a phone or Google token outside Restate and returns the
// address it proves. Account.SignIn and Account.AddIdentity call it for a
// proof without an email code.
func (s *Account) verifyToken(ctx context.Context, p Proof) (contact.Address, error) {
	if p.GoogleToken != "" {
		a, err := s.google.Verify(ctx, p.GoogleToken)
		if err != nil {
			return contact.Address{}, fmt.Errorf("verify google token: %w", err)
		}
		return a, nil
	}
	a, err := s.phones.Verify(ctx, p.PhoneToken)
	if err != nil {
		return contact.Address{}, fmt.Errorf("verify phone token: %w", err)
	}
	return a, nil
}

// guessFor hashes code against its challenge outside Restate. It also
// reports whether the code matches the challenge, which a caller checks on
// the answer to a repeated Idempotency-Key: Restate returns the first run's
// result whatever this request carries. An unknown challenge is
// code_expired.
func (s *Account) guessFor(ctx context.Context, code EmailCode) (CodeGuess, bool, error) {
	c, err := s.challenges.Get(ctx, code.ChallengeID)
	if errors.Is(err, repository.ErrNotFound) {
		return CodeGuess{}, false, domain.ErrCodeExpired
	}
	if err != nil {
		return CodeGuess{}, false, fmt.Errorf("get challenge: %w", err)
	}
	hash := s.codes.Hash(c.Destination(), code.Code)
	return CodeGuess{ChallengeID: c.ID(), CodeHash: hash}, hmac.Equal(hash, c.CodeHash()), nil
}
```

(Add `"crypto/hmac"` to the imports.)

- [ ] **Step 3: The Restate service takes a proven sign-in**

In `sign_in_durable.go`:

- Replace `PhoneSignIn` with:

```go
// ProvenSignIn is an address a token proved outside Restate, or a guess at
// an email code for the flow to judge. Neither the token nor the code
// enters Restate, whose journal the admin API can read.
type ProvenSignIn struct {
	Address *contact.Address `json:"address,omitempty"`
	Guess   *CodeGuess       `json:"guess,omitempty"`
}
```

- `SignIn` gains `Challenges repository.Challenges`; its doc says it finds or creates the account of a proven phone number or email address.
- `Run(ctx restate.Context, in ProvenSignIn)` starts:

```go
	at, err := restatex.Now(ctx, s.Now)
	if err != nil {
		return SignInResult{}, err
	}
	var addr contact.Address
	if in.Guess != nil {
		proved, refused, err := judgeGuess(ctx, s.Challenges, *in.Guess, domain.PurposeSignIn, nil, at)
		if err != nil || refused != nil {
			return SignInResult{Refused: refused}, err
		}
		addr = proved
	} else {
		addr = *in.Address
	}
	kind := domain.Kind(addr.Kind())
```

- The `FindIdentity` step uses `s.Credentials.FindIdentity(rc, kind, addr.Value())`, and the new identity is `domain.NewIdentity(identityID, addr, at)`. Nothing else in the run changes.

In `service.go`: `Durable` passes `Challenges: s.challenges` to `SignIn`; the caller becomes `restatex.Caller[ProvenSignIn, SignInResult]`; `Deps` gains `Google GoogleVerifier` and `Account` the field `google GoogleVerifier`, set in `New`; beside `PhoneVerifier`:

```go
// GoogleVerifier checks a Google ID token and returns the email address it
// proves: provider/google in the app.
type GoogleVerifier interface {
	Verify(ctx context.Context, token string) (contact.Address, error)
}
```

The `Sessions.SignIn` doc becomes "SignIn checks a proof, finds or creates the account and starts a session."

Run: `go test ./internal/account/service/ -run TestSignIn -count=1`
Expected: PASS (the `Account.SignIn` method does not compile yet only if it still names `PhoneSignIn`; Step 4 fixes it, so run after Step 4 if the package fails to build).

- [ ] **Step 4: The use case resolves the proof**

`views.go`: `SignInInput` becomes

```go
// Proof is what a person shows to sign in or add an identity: exactly one
// of a phone token, a Google ID token and an email code. The spec's oneOf
// holds that rule.
type Proof struct {
	PhoneToken  string
	GoogleToken string
	EmailCode   *EmailCode
}

// EmailCode is the code a person typed and the challenge it was mailed with.
type EmailCode struct {
	ChallengeID uuid.UUID
	Code        string
}

// SignInInput is a proof. A repeated IdempotencyKey with a proof of the same
// address gets the first request's account and session.
type SignInInput struct {
	IdempotencyKey string
	Proof          Proof
	DeviceName     string
}
```

`sign_in.go`:

```go
package service

import (
	"context"

	"github.com/shopnexus/server/internal/account/domain"
)

// SignIn checks the proof, has the SignIn service find or create the
// account, then starts the session it named. The invocation key holds the
// proven address, or the challenge of an email code, so a key sent again
// with another person's proof runs apart.
func (s *Account) SignIn(ctx context.Context, in SignInInput) (SignedIn, error) {
	var (
		run       ProvenSignIn
		key       string
		codeMatch = true
	)
	if in.Proof.EmailCode != nil {
		g, match, err := s.guessFor(ctx, *in.Proof.EmailCode)
		if err != nil {
			return SignedIn{}, err
		}
		run.Guess, key, codeMatch = &g, g.ChallengeID.String()+"/"+in.IdempotencyKey, match
	} else {
		addr, err := s.verifyToken(ctx, in.Proof)
		if err != nil {
			return SignedIn{}, err
		}
		run.Address, key = &addr, string(addr.Kind())+":"+addr.Value()+"/"+in.IdempotencyKey
	}
	res, err := s.signIn.Call(ctx, key, run)
	if err != nil {
		return SignedIn{}, err
	}
	// A repeated key returns the first run's result; only the right code
	// gets its session.
	if !codeMatch {
		return SignedIn{}, domain.ErrCodeExpired
	}
	tokens, err := s.issueSession(ctx, res.SessionID, res.AccountID, in.DeviceName)
	if err != nil {
		return SignedIn{}, err
	}
	return SignedIn{Tokens: tokens, Account: SignedInAccount{ID: res.AccountID, IsNew: res.IsNew}}, nil
}
```

`account.go`: `Settings` gains `Google service.GoogleVerifier`, passed into `Deps`. `internal/app/app.go` passes `Google: google.NewVerifier(cfg.Google, time.Now, log)` (import `internal/provider/google`).

- [ ] **Step 5: The contract**

`api/schemas/auth.yaml`, `SignInRequest` becomes:

```yaml
SignInRequest:
  type: object
  additionalProperties: false
  description: Exactly one proof, phone_token, google_token or email_code, and the device's name.
  oneOf:
    - required: [phone_token]
    - required: [google_token]
    - required: [email_code]
  properties:
    phone_token:
      type: string
      minLength: 1
      maxLength: 8192
      description: The token Firebase returned for the verified number.
    google_token:
      type: string
      minLength: 1
      maxLength: 8192
      description: The ID token Credential Manager returned for the Google account; it proves the account's email.
    email_code:
      $ref: "#/EmailCodeProof"
    device_name:
      type: string
      maxLength: 100
      description: Shown in the list of signed-in devices.
EmailCodeProof:
  type: object
  additionalProperties: false
  required: [challenge_id, code]
  properties:
    challenge_id:
      type: string
      format: uuid
    code:
      type: string
      pattern: "^[0-9]{6}$"
```

`api/paths/auth.yaml`, `signIn`:

- summary: "Sign in, or sign up on first use, with a phone number Firebase verified, a Google account or an email code."
- description:

```yaml
    description: |
      phone_token is what Firebase returned for the number: the ID token of
      Firebase Authentication after an SMS code, or the Phone Number
      Verification token of the SIM. google_token is the Google ID token
      Credential Manager returned; it proves the account's email, and an
      email identity with that address is the same account. email_code is
      the code sendEmailCode mailed. A token must be at most 5 minutes old.
      A repeated Idempotency-Key with a proof of the same address returns
      the first sign-in's session with a new refresh token.
```

- 401: "A token failed a check (invalid_phone_token, invalid_google_token), or a repeated Idempotency-Key's session was signed out since (session_revoked, session_expired)."
- 422: "The verified number is not a Vietnamese mobile number (invalid_phone), or the code is wrong (invalid_code, details.attempts_left), expired or replaced (code_expired) or out of guesses (code_locked)."
- 503: "The keys that sign phone or Google tokens could not be fetched yet (unavailable); try again."

- [ ] **Step 6: The handler**

`internal/account/handler/proof.go`:

```go
package handler

import (
	"uuid"

	"github.com/shopnexus/server/internal/account/service"
)

// proofBody is the proof fields of a sign-in or add-identity body. The spec
// validator has checked that exactly one is set.
type proofBody struct {
	PhoneToken  string         `json:"phone_token"`
	GoogleToken string         `json:"google_token"`
	EmailCode   *emailCodeBody `json:"email_code"`
}

type emailCodeBody struct {
	ChallengeID uuid.UUID `json:"challenge_id"`
	Code        string    `json:"code"`
}

func (b proofBody) proof() service.Proof {
	p := service.Proof{PhoneToken: b.PhoneToken, GoogleToken: b.GoogleToken}
	if b.EmailCode != nil {
		p.EmailCode = &service.EmailCode{ChallengeID: b.EmailCode.ChallengeID, Code: b.EmailCode.Code}
	}
	return p
}

// method names the proof for login_total.
func (b proofBody) method() string {
	switch {
	case b.EmailCode != nil:
		return "email"
	case b.GoogleToken != "":
		return "google"
	default:
		return "phone"
	}
}
```

`sign_in.go` (handler):

```go
type signInRequest struct {
	proofBody

	IdempotencyKey string `header:"Idempotency-Key" json:"-"`
	DeviceName     string `json:"device_name"`
}

// SignIn serves POST /v1/auth/sign-in. Every request counts in login_total
// under its proof's method, a malformed one as a phone failure.
func (h *Handler) SignIn(w http.ResponseWriter, r *http.Request) {
	result := "failure"
	var in signInRequest
	defer func() {
		logins.Add(r.Context(), 1, metric.WithAttributes(attribute.String("method", in.method()), attribute.String("result", result)))
	}()
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	res, err := h.svc.SignIn(r.Context(), service.SignInInput{
		IdempotencyKey: in.IdempotencyKey, Proof: in.proof(), DeviceName: in.DeviceName,
	})
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	result = "success"
	httpx.Respond(w, http.StatusOK, res)
}
```

`httpx.Bind` must fill an embedded struct's JSON fields; it decodes the body with `encoding/json`, which does. If its tag plan skips embedded fields, give `signInRequest` the three fields directly and build a `proofBody` from them.

- [ ] **Step 7: The e2e tests**

`e2e/auth_helpers_test.go` gains:

```go
// signInByEmail mails a code to addr and signs in with it.
func signInByEmail(t *testing.T, addr string) signIn {
	t.Helper()
	id, code := sendEmailCode(t, addr)
	return expect[signIn](t, call(t, "POST", "/v1/auth/sign-in",
		map[string]any{"email_code": map[string]string{"challenge_id": id, "code": code}, "device_name": "e2e"}, newKey()), 200)
}

// newEmailAccount signs up with a fresh address and no phone.
func newEmailAccount(t *testing.T) (account signIn, addr string) {
	t.Helper()
	addr = newEmail()
	return signInByEmail(t, addr), addr
}
```

`signInStatus` and `signInCall` stay as they are.

`e2e/auth_email_google_test.go`:

```go
package e2e

import (
	"testing"
	"time"

	"github.com/shopnexus/server/internal/provider/google/googletest"
)

func TestSignUpByEmailThenGoogle(t *testing.T) {
	t.Parallel()
	first, addr := newEmailAccount(t)
	if !first.Account.IsNew {
		t.Fatalf("%+v", first.Account)
	}
	second := signInByEmail(t, addr)
	byGoogle := expect[signIn](t, call(t, "POST", "/v1/auth/sign-in", map[string]string{"google_token": google.Token(addr)}, newKey()), 200)
	if second.Account.ID != first.Account.ID || second.Account.IsNew || byGoogle.Account.ID != first.Account.ID || byGoogle.Account.IsNew {
		t.Fatalf("second %+v, google %+v", second.Account, byGoogle.Account)
	}
}

func TestSignUpByGoogle(t *testing.T) {
	t.Parallel()
	res := expect[signIn](t, call(t, "POST", "/v1/auth/sign-in", map[string]string{"google_token": google.Token(newEmail())}, newKey()), 200)
	if !res.Account.IsNew {
		t.Fatalf("%+v", res.Account)
	}
}

// A key replayed with a wrong code gets no session, though Restate answers
// it with the first run's result.
func TestSignInByEmailReplayWithAWrongCode(t *testing.T) {
	t.Parallel()
	addr := newEmail()
	id, code := sendEmailCode(t, addr)
	key := newKey()
	expectStatus(t, call(t, "POST", "/v1/auth/sign-in", map[string]any{"email_code": map[string]string{"challenge_id": id, "code": code}}, key), 200)
	wrong := "000000"
	if wrong == code {
		wrong = "111111"
	}
	check(t, "replay", call(t, "POST", "/v1/auth/sign-in", map[string]any{"email_code": map[string]string{"challenge_id": id, "code": wrong}}, key), 422, "code_expired")
}

func TestSignInByEmailRefusals(t *testing.T) {
	t.Parallel()
	addr := newEmail()
	id, code := sendEmailCode(t, addr)
	wrong := "000000"
	if wrong == code {
		wrong = "111111"
	}
	res := call(t, "POST", "/v1/auth/sign-in", map[string]any{"email_code": map[string]string{"challenge_id": id, "code": wrong}}, newKey())
	if res.Status != 422 || errorOf(t, res).Code != "invalid_code" {
		t.Fatalf("%d %s", res.Status, res.Body)
	}
	check(t, "two proofs", call(t, "POST", "/v1/auth/sign-in",
		map[string]any{"google_token": google.Token(addr), "email_code": map[string]string{"challenge_id": id, "code": code}}, newKey()), 400, "invalid_request")
	check(t, "no proof", call(t, "POST", "/v1/auth/sign-in", map[string]any{"device_name": "e2e"}, newKey()), 400, "invalid_request")
	check(t, "stale google token", call(t, "POST", "/v1/auth/sign-in",
		map[string]string{"google_token": google.Token(addr, googletest.Claim("iat", time.Now().Add(-6*time.Minute).Unix()))}, newKey()), 401, "invalid_google_token")
	check(t, "unverified google email", call(t, "POST", "/v1/auth/sign-in",
		map[string]string{"google_token": google.Token(addr, googletest.Claim("email_verified", false))}, newKey()), 401, "invalid_google_token")
}
```

(If `call` takes `map[string]string` bodies only, widen its body parameter to `any`; it marshals the body with `encoding/json`.)

- [ ] **Step 8: Run everything**

Run: `make test`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add -A api internal/account internal/app e2e
git commit -m "feat(account): sign in with a phone token, a Google ID token or an email code"
```

---

### Task 8: Adding the missing identity, and identities in `/me`

**Files:**
- Create: `internal/account/service/identity_add_durable.go`, `internal/account/service/identity_add.go`, `internal/account/service/identity_add_durable_test.go`, `internal/account/handler/identity_add.go`, `e2e/identity_test.go`
- Modify: `internal/account/service/service.go`, `views.go`, `account_get.go`, `internal/account/handler/account_get.go`, `handler.go`, `api/openapi.yaml`, `api/paths/account.yaml`, `api/schemas/account.yaml`

**Interfaces:**
- Consumes: Task 2 `Credentials.Add`, JSON; Task 7 `judgeGuess`, `verifyToken`, `guessFor`, `Proof`, `CodeGuess`, `proofBody`.
- Produces:
  - Restate service `AddIdentity`, handler `Run`, input `service.AddIdentityRun{AccountID uuid.UUID "account_id"; Address *contact.Address "address,omitempty"; Guess *CodeGuess "guess,omitempty"}`, result `service.AddIdentityResult{Identities []Identity "identities"; Refused *apperr.Error}`.
  - `Service.AddIdentity(ctx context.Context, in AddIdentityInput) ([]Identity, error)` with `AddIdentityInput{IdempotencyKey string; AccountID uuid.UUID; Proof Proof}`.
  - `Service.Me(ctx context.Context, id uuid.UUID) (MeView, error)`; `MeView{AccountView; Identities []Identity "identities"}`.
  - `POST /v1/accounts/me/identities` (operationId `addMyIdentity`); `GET /v1/accounts/me` answers `MyAccount`.

- [ ] **Step 1: Write the failing Restate tests**

`internal/account/service/identity_add_durable_test.go`:

```go
package service_test

import (
	"context"
	"net/netip"
	"testing"
	"uuid"

	restate "github.com/restatedev/sdk-go"
	"github.com/restatedev/sdk-go/ingress"

	"github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/account/repository"
	"github.com/shopnexus/server/internal/account/service"
	"github.com/shopnexus/server/internal/platform/contact"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server/internal/platform/restatex/restatetest"
)

type addEnv struct {
	add        ingress.Requester[service.AddIdentityRun, service.AddIdentityResult]
	credentials repository.Credentials
	challenges repository.Challenges
	clock      *restatetest.Clock
}

func startAddIdentity(t *testing.T, changes ...func(*service.AddIdentity)) *addEnv {
	t.Helper()
	db := pgtest.New(t)
	clock := restatetest.NewClock(now)
	svc := service.AddIdentity{
		Prefix: restatetest.Prefix(), Credentials: repository.NewCredentials(db), Challenges: repository.NewChallenges(db), Now: clock.Now,
	}
	for _, change := range changes {
		change(&svc)
	}
	client := restatetest.Start(t, restate.Reflect(svc))
	return &addEnv{
		add: ingress.Service[service.AddIdentityRun, service.AddIdentityResult](client, svc.ServiceName(), "Run"),
		credentials: repository.NewCredentials(db), challenges: repository.NewChallenges(db), clock: clock,
	}
}

// account signs up with addr through the store.
func (e *addEnv) account(t *testing.T, addr contact.Address) uuid.UUID {
	t.Helper()
	a, err := domain.New(uuid.NewV7(), "", now)
	if err != nil {
		t.Fatal(err)
	}
	if err = e.credentials.SignUp(context.Background(), a, domain.NewCredentials(a.ID(), domain.NewIdentity(uuid.NewV7(), addr, now), now)); err != nil {
		t.Fatal(err)
	}
	return a.ID()
}

func (e *addEnv) run(t *testing.T, in service.AddIdentityRun) service.AddIdentityResult {
	t.Helper()
	res, err := e.add.Request(context.Background(), in, restate.WithIdempotencyKey(uuid.NewV7().String()))
	if err != nil {
		t.Fatal(err)
	}
	return res
}

func TestAddIdentityAddsAPhone(t *testing.T) {
	t.Parallel()
	e := startAddIdentity(t)
	acc := e.account(t, email(t, "linh@example.com"))
	res := e.run(t, service.AddIdentityRun{AccountID: acc, Address: ptr(phone(t, "0901234567"))})
	if res.Refused != nil || len(res.Identities) != 2 {
		t.Fatalf("%+v", res)
	}
	ref, err := e.credentials.FindIdentity(context.Background(), domain.KindPhone, "+84901234567")
	if err != nil || ref.AccountID != acc {
		t.Fatalf("%+v %v", ref, err)
	}
}

func TestAddIdentityByEmailCode(t *testing.T) {
	t.Parallel()
	e := startAddIdentity(t)
	acc := e.account(t, phone(t, "0901234567"))
	id := uuid.NewV7()
	dest := email(t, "linh@example.com")
	code := testCodes.For(id)
	c := domain.NewChallenge(id, domain.PurposeAddIdentity, dest, &acc, netip.MustParseAddr("127.0.0.1"), testCodes.Hash(dest, code), now)
	if err := e.challenges.Create(context.Background(), c); err != nil {
		t.Fatal(err)
	}
	res := e.run(t, service.AddIdentityRun{AccountID: acc, Guess: &service.CodeGuess{ChallengeID: id, CodeHash: testCodes.Hash(dest, code)}})
	if res.Refused != nil || len(res.Identities) != 2 {
		t.Fatalf("%+v", res)
	}
}

func TestAddIdentityRefusesAnotherAccountsChallenge(t *testing.T) {
	t.Parallel()
	e := startAddIdentity(t)
	owner := e.account(t, phone(t, "0901234567"))
	thief := e.account(t, phone(t, "0912345678"))
	id := uuid.NewV7()
	dest := email(t, "linh@example.com")
	code := testCodes.For(id)
	c := domain.NewChallenge(id, domain.PurposeAddIdentity, dest, &owner, netip.MustParseAddr("127.0.0.1"), testCodes.Hash(dest, code), now)
	if err := e.challenges.Create(context.Background(), c); err != nil {
		t.Fatal(err)
	}
	res := e.run(t, service.AddIdentityRun{AccountID: thief, Guess: &service.CodeGuess{ChallengeID: id, CodeHash: testCodes.Hash(dest, code)}})
	if res.Refused == nil || res.Refused.Code != "code_expired" {
		t.Fatalf("%+v", res)
	}
}

func TestAddIdentityRefusals(t *testing.T) {
	t.Parallel()
	e := startAddIdentity(t)
	acc := e.account(t, phone(t, "0901234567"))
	e.account(t, email(t, "taken@example.com"))
	if res := e.run(t, service.AddIdentityRun{AccountID: acc, Address: ptr(phone(t, "0912345678"))}); res.Refused == nil ||
		res.Refused.Code != "identity_kind_taken" {
		t.Fatalf("second phone: %+v", res)
	}
	if res := e.run(t, service.AddIdentityRun{AccountID: acc, Address: ptr(email(t, "taken@example.com"))}); res.Refused == nil ||
		res.Refused.Code != "identity_taken" {
		t.Fatalf("taken email: %+v", res)
	}
}

// staleCredentials makes the first Save lose a race, as a second
// AddIdentity of the same account would.
type staleCredentials struct {
	repository.Credentials
	lost bool
}

func (s *staleCredentials) Save(ctx context.Context, c *domain.Credentials, writeID uuid.UUID) error {
	if !s.lost {
		s.lost = true
		return repository.ErrConflict
	}
	return s.Credentials.Save(ctx, c, writeID)
}

func TestAddIdentityLostRaceIsTryAgain(t *testing.T) {
	t.Parallel()
	e := startAddIdentity(t, func(s *service.AddIdentity) { s.Credentials = &staleCredentials{Credentials: s.Credentials} })
	acc := e.account(t, email(t, "linh@example.com"))
	if res := e.run(t, service.AddIdentityRun{AccountID: acc, Address: ptr(phone(t, "0901234567"))}); res.Refused == nil ||
		res.Refused.Code != "try_again" {
		t.Fatalf("%+v", res)
	}
}
```

Run: `go test ./internal/account/service/ -run TestAddIdentity -count=1`
Expected: FAIL to compile: `service.AddIdentity` undefined.

- [ ] **Step 2: The Restate service**

`internal/account/service/identity_add_durable.go`:

```go
package service

import (
	"errors"
	"fmt"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"

	"github.com/shopnexus/server/internal/account/domain"
	"github.com/shopnexus/server/internal/account/repository"
	"github.com/shopnexus/server/internal/platform/apperr"
	"github.com/shopnexus/server/internal/platform/contact"
	"github.com/shopnexus/server/internal/platform/restatex"
)

// AddIdentityRun is a proven address, or a guess at an add_identity code,
// for the account AccountID.
type AddIdentityRun struct {
	AccountID uuid.UUID        `json:"account_id"`
	Address   *contact.Address `json:"address,omitempty"`
	Guess     *CodeGuess       `json:"guess,omitempty"`
}

// AddIdentityResult lists the account's identities after the add. A refusal
// travels as data.
type AddIdentityResult struct {
	Identities []Identity    `json:"identities"`
	Refused    *apperr.Error `json:"refused,omitempty"`
}

func (r AddIdentityResult) Refusal() *apperr.Error { return r.Refused }

// AddIdentity gives an account the identity kind it lacks.
type AddIdentity struct {
	Prefix      string
	Challenges  repository.Challenges
	Credentials repository.Credentials
	Now         func() time.Time
}

// addIdentityService is the AddIdentity service's name without the prefix.
const addIdentityService = "AddIdentity"

func (s AddIdentity) ServiceName() string { return s.Prefix + addIdentityService }

// loadedCredentials is what the read step found.
type loadedCredentials struct {
	Credentials domain.Credentials `json:"credentials"`
	Found       bool               `json:"found"`
}

// saveOutcome is how the save step ended, for the flow to decide on.
type saveOutcome string

const (
	saved     saveOutcome = "saved"
	lostRace  saveOutcome = "lost_race"
	valueTaken saveOutcome = "taken"
)

func (s AddIdentity) Run(ctx restate.Context, in AddIdentityRun) (AddIdentityResult, error) {
	at, err := restatex.Now(ctx, s.Now)
	if err != nil {
		return AddIdentityResult{}, err
	}
	var addr contact.Address
	if in.Guess != nil {
		proved, refused, err := judgeGuess(ctx, s.Challenges, *in.Guess, domain.PurposeAddIdentity, &in.AccountID, at)
		if err != nil || refused != nil {
			return AddIdentityResult{Refused: refused}, err
		}
		addr = proved
	} else {
		addr = *in.Address
	}
	l, err := restate.Run(ctx, func(rc restate.RunContext) (loadedCredentials, error) {
		c, stepErr := s.Credentials.Get(rc, in.AccountID)
		if errors.Is(stepErr, repository.ErrNotFound) {
			return loadedCredentials{}, nil
		}
		if stepErr != nil {
			return loadedCredentials{}, fmt.Errorf("get credentials: %w", stepErr)
		}
		return loadedCredentials{Credentials: c, Found: true}, nil
	})
	if err != nil {
		return AddIdentityResult{}, fmt.Errorf("load credentials: %w", err)
	}
	if !l.Found {
		return AddIdentityResult{Refused: domain.ErrAccountNotFound}, nil
	}
	c := l.Credentials
	if err = c.Add(domain.NewIdentity(restatex.NewID(ctx, at), addr, at)); err != nil {
		return AddIdentityResult{Refused: apperr.From(err)}, nil
	}
	w := restatex.NewID(ctx, at)
	outcome, err := restate.Run(ctx, func(rc restate.RunContext) (saveOutcome, error) {
		c := c // Save sets the write ID on its copy; c outside stays as journaled
		stepErr := s.Credentials.Save(rc, &c, w)
		switch {
		case errors.Is(stepErr, repository.ErrConflict):
			return lostRace, nil
		case errors.Is(stepErr, domain.ErrIdentityTaken):
			return valueTaken, nil
		case stepErr != nil:
			return "", fmt.Errorf("save credentials: %w", stepErr)
		default:
			return saved, nil
		}
	})
	if err != nil {
		return AddIdentityResult{}, fmt.Errorf("save the identity: %w", err)
	}
	switch outcome {
	case lostRace:
		return AddIdentityResult{Refused: apperr.ErrTryAgain}, nil
	case valueTaken:
		return AddIdentityResult{Refused: domain.ErrIdentityTaken}, nil
	default:
	}
	ids := c.Identities()
	out := make([]Identity, 0, len(ids))
	for _, i := range ids {
		out = append(out, Identity{Kind: i.Kind(), Value: i.Value()})
	}
	return AddIdentityResult{Identities: out}, nil
}
```

`service.go`: `Durable` appends `restate.Reflect(AddIdentity{Prefix: s.prefix, Challenges: s.challenges, Credentials: s.credentials, Now: s.now})`; `Account` gains `addIdentity restatex.Caller[AddIdentityRun, AddIdentityResult]`, set in `New` with `Service: d.Prefix + addIdentityService, Handler: "Run"`. `Identity` in `views.go` gets the doc "Identity is the Identity schema in api/schemas/account.yaml."

Run: `go test ./internal/account/service/ -run TestAddIdentity -count=1` → PASS.

- [ ] **Step 3: The use cases**

`views.go` gains:

```go
// AddIdentityInput is a proof of the kind the account lacks.
type AddIdentityInput struct {
	IdempotencyKey string
	AccountID      uuid.UUID
	Proof          Proof
}

// MeView is the MyAccount schema: the account and its sign-in methods,
// which only its owner reads.
type MeView struct {
	AccountView

	Identities []Identity `json:"identities"`
}
```

`internal/account/service/identity_add.go`:

```go
package service

import "context"

// AddIdentity checks the proof and has the AddIdentity service add the
// address to the caller's account. The key holds the account, so another
// account's key runs apart.
func (s *Account) AddIdentity(ctx context.Context, in AddIdentityInput) ([]Identity, error) {
	run := AddIdentityRun{AccountID: in.AccountID}
	if in.Proof.EmailCode != nil {
		g, _, err := s.guessFor(ctx, *in.Proof.EmailCode)
		if err != nil {
			return nil, err
		}
		run.Guess = &g
	} else {
		addr, err := s.verifyToken(ctx, in.Proof)
		if err != nil {
			return nil, err
		}
		run.Address = &addr
	}
	res, err := s.addIdentity.Call(ctx, in.AccountID.String()+"/"+in.IdempotencyKey, run)
	if err != nil {
		return nil, err
	}
	return res.Identities, nil
}
```

(A repeated key answers the owner with their own identities, so the code-match check of `SignIn` is not needed here.)

`account_get.go` gains:

```go
// Me reads the caller's account and its sign-in methods.
func (s *Account) Me(ctx context.Context, id uuid.UUID) (MeView, error) {
	a, err := s.load(ctx, id)
	if err != nil {
		return MeView{}, err
	}
	ids, err := s.Identities(ctx, id)
	if err != nil {
		return MeView{}, err
	}
	return MeView{AccountView: s.view(a, s.now()), Identities: ids}, nil
}
```

`Service` gains:

```go
	// Me reads the caller's own account with its identities.
	Me(ctx context.Context, id uuid.UUID) (MeView, error)
	// AddIdentity adds the identity kind an account lacks, from a proof.
	AddIdentity(ctx context.Context, in AddIdentityInput) ([]Identity, error)
```

- [ ] **Step 4: The contract**

`api/schemas/account.yaml` gains:

```yaml
Identity:
  type: object
  additionalProperties: false
  required: [kind, value]
  properties:
    kind:
      type: string
      enum: [phone, email]
    value:
      type: string
      description: The number in the +84 form, or the address lower-cased.
MyAccount:
  type: object
  additionalProperties: false
  required: [id, display_name, bio, status, created_at, identities]
  properties:
    # every property of Account, copied, then:
    identities:
      type: array
      minItems: 1
      maxItems: 2
      items:
        $ref: "#/Identity"
      description: How the account signs in. Posting, opening a deal and opening a chat need a phone.
AddIdentityRequest:
  type: object
  additionalProperties: false
  description: Exactly one proof of the kind the account lacks.
  oneOf:
    - required: [phone_token]
    - required: [google_token]
    - required: [email_code]
  properties:
    phone_token:
      type: string
      minLength: 1
      maxLength: 8192
    google_token:
      type: string
      minLength: 1
      maxLength: 8192
    email_code:
      $ref: "auth.yaml#/EmailCodeProof"
Identities:
  type: object
  additionalProperties: false
  required: [identities]
  properties:
    identities:
      type: array
      items:
        $ref: "#/Identity"
```

In `MyAccount`, write out every property `Account` has (its `properties` block, verbatim) before `identities`. If `api/schemas/console.yaml` or another file already defines an `Identity` schema (the console's account view lists identities), reuse that one and do not define a second.

`api/paths/account.yaml`: `me.get` answers `$ref: "../schemas/account.yaml#/MyAccount"`, and the file gains:

```yaml
myIdentities:
  post:
    operationId: addMyIdentity
    summary: Add the phone or email the caller's account lacks.
    description: |
      A phone_token adds a phone to an account that has only an email;
      google_token or email_code (from sendMyEmailCode) adds an email to an
      account that has only a phone.
    tags: [account]
    security:
      - bearerAuth: []
    parameters:
      - $ref: "../parameters/common.yaml#/IdempotencyKey"
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/account.yaml#/AddIdentityRequest"
    responses:
      "200":
        description: The account's identities after the add.
        content:
          application/json:
            schema:
              $ref: "../schemas/account.yaml#/Identities"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        description: Not signed in, or a token failed a check (invalid_phone_token, invalid_google_token).
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "409":
        description: The account has this kind already (identity_kind_taken), another account signs in with this value (identity_taken), or a race (try_again).
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: invalid_phone, invalid_code (details.attempts_left), code_expired or code_locked.
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

`api/openapi.yaml` gains `/v1/accounts/me/identities: $ref: "paths/account.yaml#/myIdentities"`.

- [ ] **Step 5: The handlers**

`internal/account/handler/identity_add.go`:

```go
package handler

import (
	"net/http"

	"github.com/shopnexus/server/internal/account/service"
	"github.com/shopnexus/server/internal/platform/httpx"
)

type addIdentityRequest struct {
	proofBody

	IdempotencyKey string `header:"Idempotency-Key" json:"-"`
}

// identitiesView is the Identities schema.
type identitiesView struct {
	Identities []service.Identity `json:"identities"`
}

// AddIdentity serves POST /v1/accounts/me/identities.
func (h *Handler) AddIdentity(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in addIdentityRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	ids, err := h.svc.AddIdentity(r.Context(), service.AddIdentityInput{
		IdempotencyKey: in.IdempotencyKey, AccountID: p.AccountID, Proof: in.proof(),
	})
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, identitiesView{Identities: ids})
}
```

The handler rules say the response is the view the service returns; if review prefers that, make `Service.AddIdentity` return `IdentitiesView` from `views.go` instead of the slice and drop `identitiesView` here.

`account_get.go` (handler): `h.svc.Get(...)` becomes `h.svc.Me(...)`. `Register` gains `r.Handle("POST /v1/accounts/me/identities", protect(http.HandlerFunc(h.AddIdentity)))`.

- [ ] **Step 6: The e2e tests**

`e2e/identity_test.go`:

```go
package e2e

import (
	"testing"

	"github.com/shopnexus/server/internal/provider/firebase/firebasetest"
)

type myAccount struct {
	ID         string `json:"id"`
	Identities []struct {
		Kind  string `json:"kind"`
		Value string `json:"value"`
	} `json:"identities"`
}

func TestAddAPhoneToAnEmailAccount(t *testing.T) {
	t.Parallel()
	me, addr := newEmailAccount(t)
	before := expect[myAccount](t, call(t, "GET", "/v1/accounts/me", nil, bearer(me.AccessToken)), 200)
	if len(before.Identities) != 1 || before.Identities[0].Kind != "email" || before.Identities[0].Value != addr {
		t.Fatalf("%+v", before)
	}
	phone := newPhone()
	expectStatus(t, call(t, "POST", "/v1/accounts/me/identities", map[string]string{"phone_token": issuer.SMSToken(phone)}, newKey(), bearer(me.AccessToken)), 200)
	after := expect[myAccount](t, call(t, "GET", "/v1/accounts/me", nil, bearer(me.AccessToken)), 200)
	if len(after.Identities) != 2 {
		t.Fatalf("%+v", after)
	}
	if byPhone := signInWith(t, phone); byPhone.Account.ID != me.Account.ID {
		t.Fatalf("the phone signs in to %s", byPhone.Account.ID)
	}
}

func TestAddAnEmailToAPhoneAccount(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	addr := newEmail()
	c := expect[emailCode](t, call(t, "POST", "/v1/accounts/me/email-codes", map[string]string{"email": addr}, newKey(), bearer(me.AccessToken)), 200)
	expectStatus(t, call(t, "POST", "/v1/accounts/me/identities",
		map[string]any{"email_code": map[string]string{"challenge_id": c.ChallengeID, "code": mails.code(t, addr, 1)}}, newKey(), bearer(me.AccessToken)), 200)
	byGoogle := expect[signIn](t, call(t, "POST", "/v1/auth/sign-in", map[string]string{"google_token": google.Token(addr)}, newKey()), 200)
	if byGoogle.Account.ID != me.Account.ID {
		t.Fatalf("google signs in to %s", byGoogle.Account.ID)
	}
}

func TestAddIdentityRefusals(t *testing.T) {
	t.Parallel()
	me, _ := newEmailAccount(t)
	_, takenPhone := newAccount(t)
	check(t, "taken phone", call(t, "POST", "/v1/accounts/me/identities", map[string]string{"phone_token": issuer.SMSToken(takenPhone)}, newKey(), bearer(me.AccessToken)), 409, "identity_taken")
	check(t, "a second email", call(t, "POST", "/v1/accounts/me/identities", map[string]string{"google_token": google.Token(newEmail())}, newKey(), bearer(me.AccessToken)), 409, "identity_kind_taken")
	check(t, "foreign number", call(t, "POST", "/v1/accounts/me/identities", map[string]string{"phone_token": issuer.SMSToken("+14155550100")}, newKey(), bearer(me.AccessToken)), 422, "invalid_phone")
	check(t, "forged token", call(t, "POST", "/v1/accounts/me/identities", map[string]string{"phone_token": issuer.SMSToken(newPhone(), firebasetest.Claim("aud", "other"))}, newKey(), bearer(me.AccessToken)), 401, "invalid_phone_token")
	check(t, "no key", call(t, "POST", "/v1/accounts/me/identities", map[string]string{"phone_token": issuer.SMSToken(newPhone())}, bearer(me.AccessToken)), 400, "")
	check(t, "signed out", call(t, "POST", "/v1/accounts/me/identities", map[string]string{"phone_token": issuer.SMSToken(newPhone())}, newKey()), 401, "")
}
```

Existing e2e tests that decode `GET /v1/accounts/me` into a struct keep working: the answer only gains a field.

- [ ] **Step 7: Run everything**

Run: `make test`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add -A api internal/account e2e
git commit -m "feat(account): POST /v1/accounts/me/identities adds the phone or email an account lacks"
```

---

### Task 9: `phone_required` on posting, opening a deal and opening a chat

**Files:**
- Modify: `internal/account/domain/errors.go`, `internal/account/service/service.go`, `internal/account/service/identity.go`, `internal/account/service/identity_test.go`, `internal/account/accounttest/accounttest.go`, `internal/catalog/service/listing_post_durable.go`, `internal/catalog/service/listing_test.go`, `internal/deal/service/deal_open.go`, `internal/deal/service/deal_test.go`, `internal/chat/service/message_send_durable.go`, `internal/chat/service/chat_test.go`, `api/paths/catalog.yaml`, `api/paths/deal.yaml`, `api/paths/chat.yaml`, `e2e/phone_required_test.go`

**Interfaces:**
- Consumes: Task 2 `Credentials.Has`.
- Produces: `accountdomain.ErrPhoneRequired` (403 `phone_required`); `accountsvc.Service.HasPhone(ctx context.Context, id uuid.UUID) (bool, error)`; `accounttest.Service` builds with credentials.

- [ ] **Step 1: Write the failing tests**

`internal/account/service/identity_test.go` gains (use the file's existing helpers for a database and an account; `accounttest` cannot be imported by `account/service` tests if it imports `service` — it does, so build the store directly):

```go
func TestHasPhone(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	creds := repository.NewCredentials(db)
	svc := service.New(service.Deps{Accounts: repository.NewAccounts(db), Credentials: creds, Now: func() time.Time { return now }, Log: discard})
	signUp := func(addr contact.Address) uuid.UUID {
		a, err := domain.New(uuid.NewV7(), "", now)
		if err != nil {
			t.Fatal(err)
		}
		if err = creds.SignUp(context.Background(), a, domain.NewCredentials(a.ID(), domain.NewIdentity(uuid.NewV7(), addr, now), now)); err != nil {
			t.Fatal(err)
		}
		return a.ID()
	}
	for name, c := range map[string]struct {
		id   uuid.UUID
		want bool
	}{
		"phone":          {signUp(phone(t, "0901234567")), true},
		"email only":     {signUp(email(t, "linh@example.com")), false},
		"no credentials": {seed(t, repository.NewAccounts(db)), false},
	} {
		if got, err := svc.HasPhone(context.Background(), c.id); err != nil || got != c.want {
			t.Errorf("%s: %v %v", name, got, err)
		}
	}
}
```

`internal/catalog/service/listing_test.go`, in `TestPostChecksInOrder`, the phoneless post now refuses:

```go
	if _, err := e.catalog.Post(ctx, e.account(t), uuid.NewV7().String(), bad); !errors.Is(err, accountdomain.ErrPhoneRequired) {
		t.Fatalf("an account without a phone: %v", err)
	}
	if _, err := e.catalog.Post(ctx, e.seller(t), uuid.NewV7().String(), bad); !errors.Is(err, domain.ErrInvalidListing) {
		t.Fatalf("a seller with a phone reaches the draft's checks: %v", err)
	}
```

The test's doc and `Run`'s doc list the phone check after the suspension.

`internal/deal/service/deal_test.go`, the phoneless open:

```go
	if _, _, err := e.deals.Open(ctx, accounttest.New(t, e.db), listing); !errors.Is(err, accountdomain.ErrPhoneRequired) {
		t.Fatalf("an account without a phone opens a deal: %v", err)
	}
```

`internal/chat/service/chat_test.go`, the phoneless open, and a new test:

```go
	if _, err := e.chat.Open(ctx, accounttest.New(t, e.db), key(), service.OpenInput{ListingID: listing, Text: "Còn không?"}); !errors.Is(err, accountdomain.ErrPhoneRequired) {
		t.Fatalf("an account without a phone opens a chat: %v", err)
	}
```

```go
// Only opening needs a phone: an account without one replies in a chat a
// seller with a phone opened with it.
func TestPhoneRequiredOnlyToOpen(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	phoneless := accounttest.New(t, e.db)
	listing := e.listingOf(t, phoneless)
	conv := e.open(t, e.person(t), listing, "Còn không?")
	if _, err := e.chat.Send(ctx, phoneless, key(), service.SendInput{ConversationID: conv.ID, Text: "Còn bạn"}); err != nil {
		t.Fatalf("a reply without a phone: %v", err)
	}
}
```

`e.listingOf`, `e.chat.Send` and `service.SendInput` stand for the chat tests' own helpers for a listing owned by an account and for sending into an existing conversation; read `internal/chat/service/helpers_test.go` and `chat_test.go` and use theirs (a listing put in the database through `catalogtest.Listing` with that seller, and the send method the reply tests call). A listing of a phoneless seller is inserted through the store, which checks no phone.

Run: `go test ./internal/account/... ./internal/catalog/... ./internal/deal/... ./internal/chat/... -count=1`
Expected: FAIL to compile: `ErrPhoneRequired` and `HasPhone` undefined.

- [ ] **Step 2: Implement**

`internal/account/domain/errors.go`, beside `ErrSuspended`:

```go
	// ErrPhoneRequired answers posting, opening a deal and opening a chat
	// by an account without a phone identity; catalog, deal and chat
	// return it.
	ErrPhoneRequired = apperr.New(apperr.KindForbidden, "phone_required", "add a phone number to do this")
```

`internal/account/service/identity.go`:

```go
// HasPhone reports whether the account signs in with a phone number, which
// posting, opening a deal and opening a chat need. An account without
// credentials has none.
func (s *Account) HasPhone(ctx context.Context, id uuid.UUID) (bool, error) {
	cr, err := s.credentials.Get(ctx, id)
	if errors.Is(err, repository.ErrNotFound) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("get credentials: %w", err)
	}
	return cr.Has(domain.KindPhone), nil
}
```

`Service` gains:

```go
	// HasPhone reports whether the account has a phone identity. Another
	// module that requires one answers domain.ErrPhoneRequired when it has
	// not; a Restate step returns the bool, so the flow refuses as data.
	HasPhone(ctx context.Context, id uuid.UUID) (bool, error)
```

`accounttest.Service` gains `Credentials: repository.NewCredentials(db),` in its `Deps`.

`internal/catalog/service/listing_post_durable.go`, right after the `if suspended {...}` block:

```go
	hasPhone, err := restate.Run(ctx, func(rc restate.RunContext) (bool, error) {
		return s.Accounts.HasPhone(rc, in.Seller)
	})
	if err != nil {
		return PostResult{}, fmt.Errorf("read the seller's phone: %w", err)
	}
	if !hasPhone {
		return PostResult{Refused: accountdomain.ErrPhoneRequired}, nil
	}
```

and `Run`'s doc: "Run checks, in order, that the seller is not suspended, has a phone and is under the cap, then the draft."

`internal/deal/service/deal_open.go`, right after the `if suspended {...}` block:

```go
	hasPhone, err := s.accounts.HasPhone(ctx, buyer)
	if err != nil {
		return DealView{}, false, fmt.Errorf("read the buyer's phone: %w", err)
	}
	if !hasPhone {
		return DealView{}, false, accountdomain.ErrPhoneRequired
	}
```

and the doc: "Starting needs an account that is not suspended and has a phone, ..."

`internal/chat/service/message_send_durable.go`: `facts` gains `HasPhone bool \`json:"has_phone"\``; inside the read step, after the `Suspended` read:

```go
		if in.Opening {
			if out.HasPhone, stepErr = s.Chat.accounts.HasPhone(rc, in.Sender); stepErr != nil {
				return facts{}, fmt.Errorf("read the sender's phone: %w", stepErr)
			}
		}
```

and the decision switch gains, right after `case f.Suspended:`:

```go
	case in.Opening && !f.HasPhone:
		refused = accountdomain.ErrPhoneRequired
```

Update the `MessageSend` doc and `ARCHITECTURE.md`'s chat section in Task 10 ("status, phone when opening, listing, ...").

Run the Step 1 command again. Expected: PASS. Any other test in these modules that posts, opens a deal or opens a chat as `accounttest.New` fails now; switch that actor to the helper that gives a phone (`e.seller`, `e.person`, `accounttest.WithPhone`).

- [ ] **Step 3: The contract**

The 403 of the operations behind `POST /v1/listings`, the deal open and the chat open (`grep -n "operationId" api/paths/catalog.yaml api/paths/deal.yaml api/paths/chat.yaml` to find `postListing`, the deal open and the conversation open) becomes:

```yaml
      "403":
        description: The account is suspended (account_suspended), has no phone to sign in with (phone_required), or a block stands between the two (blocked).
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

(Keep each operation's existing reasons; add `phone_required` to its list.) `api/responses/common.yaml` is unchanged.

- [ ] **Step 4: The e2e test**

`e2e/phone_required_test.go`:

```go
package e2e

import "testing"

// An account that signed up by email adds a phone before it trades.
func TestPhoneRequiredToTrade(t *testing.T) {
	t.Parallel()
	me, _ := newEmailAccount(t)
	listing := newListing(t) // someone else's active listing
	check(t, "post", postListingAs(t, me.AccessToken), 403, "phone_required")
	check(t, "open a deal", openDealAs(t, me.AccessToken, listing), 403, "phone_required")
	check(t, "open a chat", openChatAs(t, me.AccessToken, listing), 403, "phone_required")
	expectStatus(t, call(t, "POST", "/v1/accounts/me/identities", map[string]string{"phone_token": issuer.SMSToken(newPhone())}, newKey(), bearer(me.AccessToken)), 200)
	expectStatus(t, postListingAs(t, me.AccessToken), 201)
	expectStatus(t, openDealAs(t, me.AccessToken, listing), 201)
}
```

`newListing`, `postListingAs`, `openDealAs` and `openChatAs` stand for the helpers `catalog_test.go`, `deal_test.go` and `chat_test.go` already use to put a listing on sale and to call those endpoints with a token; use theirs and their status codes (`grep -n "^func " e2e/catalog_test.go e2e/deal_test.go e2e/chat_test.go`). A listing must pass processing before a deal opens on it; the existing deal tests show how they wait for it.

- [ ] **Step 5: Run everything**

Run: `make test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A api internal e2e
git commit -m "feat: posting, opening a deal and opening a chat need a phone identity again"
```

---

### Task 10: Architecture notes and deployment configuration

**Files:**
- Modify: `server/ARCHITECTURE.md`
- Modify (umbrella `~/shopnexus`): `docker-compose.yml`, `infra/stack/templates/_server-env.tpl`, `infra/stack/values.yaml`, `infra/stack/values-dev.yaml`, `infra/stack/values-prod.yaml`, `infra/stack/tests/server_env_test.yaml`, `infra/stack/secrets/example.env`, `infra/cmd/seal/main.go`, `infra/cmd/seal/main_test.go`

- [ ] **Step 1: `ARCHITECTURE.md`**

- Rename the section "Phone sign-in" to "Sign-in" and rewrite its opening and numbered flow from the spec's Decisions, API and Flows sections: three proofs, checked outside Restate; `SignIn` takes `ProvenSignIn`; keys `<kind>:<value>/<Idempotency-Key>` and `<challenge_id>/<Idempotency-Key>`; the code-match check on a repeated key; Google checks; `jwks` shared; `GOOGLE_CLIENT_ID` empty turns Google off. Keep the Firebase token bullets. Replace "Server2 sends no codes: email sign-in, OTP challenges and their quotas are gone, and every account has a phone number" with the email-code rules (six digits, 5 minutes, 5 guesses, limits, the code derived from the challenge ID, `EMAIL_SENDER`, prod refuses `log`). Say it was decided 2026-11-10 with the spec's path.
- A new section "Adding an identity": `AddIdentity`, kinds, `identity_kind_taken`, `identity_taken`, never a merge, nothing changes or removes an identity.
- "Aggregates in account": `Credentials` holds "every phone and email identity of one account: at least one, at most one of each kind".
- "Module layout": the sentence "There is no `kyc` module: an account's verified phone number is enough" stays, with "a seller's verified phone number"; `accounttest.Service` builds credentials too.
- "Chat": "with a verified phone and no block" stays true; the read step reads "status, phone when opening, listing, conversation, block".
- "Testing": e2e signs Google tokens with `googletest` and reads mails from an inbox sender.
- "Durable flows": the bullet naming `SignIn` names `EmailCodeSend` and `AddIdentity` too.

- [ ] **Step 2: Docker Compose**

`~/shopnexus/docker-compose.yml`, in the shared server environment after `FCM_CREDENTIALS`:

```yaml
  EMAIL_SENDER: log
  RESEND_API_KEY: ""
  EMAIL_FROM: ShopNexus <no-reply@shopnexus.id.vn>
  GOOGLE_CLIENT_ID: ""
  GOOGLE_JWKS_URL: https://www.googleapis.com/oauth2/v3/certs
```

`OTP_KEY` comes from envgen, as `CONSOLE_KEY` does; check the compose file's envgen step passes its output on the same way.

- [ ] **Step 3: The k3d chart**

`infra/stack/templates/_server-env.tpl`, after `PNV_TEST_NUMBERS`:

```
EMAIL_SENDER: {{ .Values.server.emailSender | quote }}
EMAIL_FROM: {{ .Values.server.emailFrom | quote }}
GOOGLE_CLIENT_ID: {{ .Values.server.googleClientID | quote }}
GOOGLE_JWKS_URL: https://www.googleapis.com/oauth2/v3/certs
```

`values.yaml` (`server:`): `emailSender: log`, `emailFrom: "ShopNexus <no-reply@shopnexus.id.vn>"`, `googleClientID: ""`, each with a one-line comment. `values-dev.yaml`: `emailSender: log`. `values-prod.yaml`: `emailSender: resend`.

`tests/server_env_test.yaml`: the prod test asserts `data.EMAIL_SENDER` equals `resend`; the existence list gains `EMAIL_FROM`, `GOOGLE_CLIENT_ID`, `GOOGLE_JWKS_URL`.

`infra/stack/secrets/example.env` gains, with the comment style of the file:

```
# Resend's API key for mailing sign-in codes. Required in prod
# (EMAIL_SENDER=resend); seal prod refuses it empty.
RESEND_API_KEY=
```

and the header lists `OTP_KEY` among the keys envgen adds.

`infra/cmd/seal/main.go`: `server-secrets` picks `"OTP_KEY"` and `"RESEND_API_KEY"` too; after the `FCM_CREDENTIALS` check:

```go
	if stack == "prod" && env.get("RESEND_API_KEY") == "" {
		return fmt.Errorf("%s: prod needs RESEND_API_KEY (EMAIL_SENDER=resend)", envFile)
	}
```

`main_test.go`: the key list of the dry-run test gains `"OTP_KEY"`, and a test like the existing FCM one checks that prod without `RESEND_API_KEY` fails with a message naming it.

Run (in `~/shopnexus/infra`): `go test ./cmd/seal/` and `./check.sh` (helm unittest and render). Expected: PASS. The umbrella's `make` or CI target that runs these, if any, passes too.

- [ ] **Step 4: Commit both repositories**

```bash
cd ~/shopnexus/server
git add ARCHITECTURE.md
git commit -m "docs: sign-in by phone, Google or email code, adding an identity, phone_required"
cd ~/shopnexus
git add docker-compose.yml infra
git commit -m "build: the server's email and Google settings, OTP_KEY and RESEND_API_KEY sealed"
```

The umbrella's submodule pointer for `server` moves in a later "chore: submodules" commit, as the repo does.

---

## Self-review notes

- Spec coverage: identity kinds and limits (Task 2); email proof (Tasks 3 to 5, 7); Google proof (Tasks 6, 7); same account for Google and email (Task 7 tests); `phone_required` and its scope (Task 9); address phones unchanged (no task touches addresses); adding identities and `identity_taken` without merging (Task 8); no change or removal (nothing adds one); Resend and the log sender (Task 3); `identities` in `/me` (Task 8, as `MyAccount`, since `Account` is also the public view other modules return); configuration (Tasks 3, 6, 10); metrics (`login_total{method}` in Task 7, `otp_sent_total` in Task 5).
- The spec says `phone_required` is read "in the step that reads `Suspended`". Catalog reads it in its own step right after, since that step returns one bool; chat reads it inside its facts step; deal is a plain method. The refusal and its order are what the spec asks.
- App work (screens, ports, fakes) and the mockups are separate plans.
