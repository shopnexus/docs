# Inbox search, mark unread, report from a conversation: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Server endpoints behind the app's inbox search, "mark unread" for conversations and notifications, and a report that names the conversation it came from.

**Architecture:** Report gains `conversation_id`, checked by trust through `chatsvc.ConversationWith`. Chat members get a `marked_unread` flag counted as at least one unread message. Notifications get a list-based unread endpoint and `read-all` returns the IDs it changed. Inbox search is a chat query (threads by name/listing title, messages by a ParadeDB BM25 index with ASCII folding), wrapped by a screen endpoint that adds deals.

**Tech Stack:** Go 1.27, pgx v5, Postgres 18 (ParadeDB 0.26.3 `pg_search`), kin-openapi validation, e2e suite with the status-coverage check, golangci-lint.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-10-server-inbox-search-unread-design.md`

## Global Constraints

- Server repo: `/home/beanbocchi/shopnexus/server`. Read its `CLAUDE.md` and `ARCHITECTURE.md` first.
- A feature starts at its OpenAPI spec in `api/`; every route in `api/openapi.yaml` has a handler and vice versa (`internal/app/routes_test.go`), and every documented status is exercised by `e2e/` (the status-coverage check in `e2e/main_test.go`).
- Use cases, Restate handlers and HTTP handlers read top to bottom; no single-use helpers. A helper is fine when several places call it.
- Configuration has no defaults. Scratch files go in `tmp/`, never `/tmp`.
- Migrations: `0027` is taken by the unmerged branch `feat/sign-in-email-google`; this plan uses `0029`, `0030`, `0031`. The runner applies by version set, so a gap is fine.
- The tokenizer is exactly `pdb.simple('ascii_folding=true')` everywhere (index, query tokens, thread matching).
- Commits: no `Co-Authored-By` trailer. Conventional prefix as in `git log` (`feat(chat): …`).
- Prose in code comments and `ARCHITECTURE.md` goes through the `humanizing-writing` skill's checker (`python3 ~/.claude/skills/humanizing-writing/ai-tells.py FILE`).
- Test commands: `make test` once to start the test stack (it also runs lint), then `go test ./internal/<module>/...` and `go test ./e2e/ -run <Name>` while working. Long output goes to `tmp/`.

## Verified ParadeDB behaviour (probed on paradedb 0.26.3-pg18)

- `'Giày Đồ cũ SHIP nhanh, đẹp!'::pdb.simple('ascii_folding=true')::text[]` = `{giay,do,cu,ship,nhanh,dep}`; `'  ,, '` gives `{}`; a bind parameter casts the same way (`$1::pdb.simple('ascii_folding=true')::text[]`).
- `m.body @@@ pdb.regex('ship')` matches the whole term only (`'shi'` matches nothing); `pdb.regex('nh.*')` is a prefix with no expansion cap (`pdb.phrase_prefix` caps at 50 and takes no `max_expansions` argument in SQL).
- `m.body &&& ''` matches nothing, so the query is built from regex clauses, one per token.
- With the index `USING paradedb (id, (body::pdb.simple('ascii_folding=true')), conversation_id, (status::pdb.literal))`, this plan pushes everything into one Tantivy query with `TopK Order By: id desc`: the regex clauses, `m.status = 'sent'`, `m.conversation_id = ANY(ARRAY(SELECT …))` and `m.id < @before`.

## Review Focus

1. A query of only punctuation or spaces (`"!!!"`, `" "`) must be `invalid_query` 422, never a 500 or an empty 200 — Task 4 test `TestSearchRefusesAnEmptyQuery`.
2. A conversation with a deleted person (`display_name` NULL) must not break thread search or match anything by name — Task 4 test `TestSearchThreads` covers it.
3. A message arriving after "mark unread" must count as its real number, and the flag must survive it until a read — Task 2 test `TestMarkUnread`.
4. Marking unread a read notice whose key already has an unread notice, and two read notices of one key in one request, must not hit the unique index — Task 3 test `TestMarkUnreadCollapse`.
5. A report naming a conversation after the reporter blocked the other person must still be accepted (the app blocks first) — Task 1 tests `TestReportFromAConversation` and e2e `TestReportFromAConversation`.

---

### Task 1: A report names the conversation it came from

**Files:**
- Create: `migrations/0029_report_conversation.sql`
- Modify: `internal/trust/domain/report.go`, `internal/trust/domain/report_test.go`
- Modify: `internal/trust/repository/report.go`, `internal/trust/repository/report_pg.go`, `internal/trust/repository/report_pg_test.go`
- Modify: `internal/trust/service/service.go`, `internal/trust/service/report.go`, `internal/trust/service/views.go`, `internal/trust/service/helpers_test.go`, `internal/trust/service/report_test.go`
- Modify: `internal/trust/handler/report.go`, `internal/trust/trust.go`, `internal/app/app.go`
- Modify: `api/schemas/trust.yaml`, `api/paths/trust.yaml` (description of 422)
- Test: `e2e/report_test.go`

**Interfaces:**
- Consumes: `chatsvc.Service.ConversationWith(ctx, account, other uuid.UUID) (uuid.UUID, error)` (exists).
- Produces: `domain.NewReport(id, reporter, account, listing, conversation uuid.UUID, reason Reason, note string, now time.Time) (Report, error)`; `(*Report).ConversationID() uuid.UUID`; `ReportState.ConversationID`; `service.ReportInput.ConversationID`; `service.ReportView.ConversationID` (`json:"conversation_id,omitzero"`); `trust.Mount(d, accounts, catalog, deals, chats chatsvc.Service)`.

- [ ] **Step 1: Migration**

`migrations/0029_report_conversation.sql`:

```sql
-- A report of an account may name the reporter's conversation with it, so
-- the console can read the messages it was made from.
ALTER TABLE reports ADD COLUMN conversation_id uuid REFERENCES conversations (id);
ALTER TABLE reports ADD CONSTRAINT reports_conversation_account
    CHECK (conversation_id IS NULL OR listing_id IS NULL);
```

- [ ] **Step 2: Domain test (RED)**

In `internal/trust/domain/report_test.go`, update every `NewReport` call to pass `uuid.UUID{}` as the new fifth argument (conversation), then add:

```go
func TestNewReportConversation(t *testing.T) {
	t.Parallel()
	at := time.Date(2026, 11, 10, 9, 0, 0, 0, time.UTC)
	reporter, seller, conversation := uuid.NewV7(), uuid.NewV7(), uuid.NewV7()
	r, err := domain.NewReport(uuid.NewV7(), reporter, seller, uuid.UUID{}, conversation, domain.ReasonScam, "", at)
	if err != nil || r.ConversationID() != conversation || r.State().ConversationID != conversation {
		t.Fatalf("%+v %v", r.State(), err)
	}
	_, err = domain.NewReport(uuid.NewV7(), reporter, seller, uuid.NewV7(), conversation, domain.ReasonScam, "", at)
	if e, ok := errors.AsType[*apperr.Error](err); !ok || e.Code != "invalid_report" || e.Fields["conversation_id"] == "" {
		t.Fatalf("with a listing: %v", err)
	}
}
```

Run: `go test ./internal/trust/domain/ -run TestNewReport`
Expected: build failure (too many arguments / `ConversationID` undefined).

- [ ] **Step 3: Domain (GREEN)**

In `internal/trust/domain/report.go`: add `conversationID uuid.UUID` to `Report` and `ConversationID uuid.UUID` to `ReportState` (after `ListingID`), carry it through `RestoreReport` and `State`, add the getter `func (r *Report) ConversationID() uuid.UUID { return r.conversationID }`, and change `NewReport`:

```go
// NewReport checks a report: not of the reporter, a known reason, a note of
// at most 500 characters after trimming, and a conversation only beside an
// account report.
func NewReport(id, reporter, account, listing, conversation uuid.UUID, reason Reason, note string, now time.Time) (Report, error) {
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
	if conversation != (uuid.UUID{}) && listing != (uuid.UUID{}) {
		e = e.WithField("conversation_id", "only with account_id")
	}
	if len(e.Fields) > 0 {
		return Report{}, e
	}
	return Report{
		id: id, reporterID: reporter, accountID: account, listingID: listing, conversationID: conversation,
		reason: reason, note: note, createdAt: now, updatedAt: now,
	}, nil
}
```

Run: `go test ./internal/trust/domain/`
Expected: PASS.

- [ ] **Step 4: Repository test (RED)**

In `internal/trust/repository/report_pg_test.go`, give the `report` helper a conversation parameter and pass `uuid.UUID{}` at the existing call sites (and in `TestReportsAtOnce`). Add:

```go
// An account report keeps its conversation; reporting again replaces it,
// and leaving it out clears it.
func TestReportConversation(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewReports(db)
	reporter, seller := accounttest.New(t, db), accounttest.New(t, db)
	lo, hi := min(reporter.String(), seller.String()), max(reporter.String(), seller.String())
	conversation := uuid.NewV7()
	if _, err := db.Exec(ctx, `INSERT INTO conversations (id, account_a, account_b, created_at) VALUES (@id, @a, @b, now())`,
		pgx.StrictNamedArgs{"id": conversation, "a": lo, "b": hi}); err != nil {
		t.Fatal(err)
	}
	open := func(c uuid.UUID) domain.Report {
		t.Helper()
		r, err := domain.NewReport(uuid.NewV7(), reporter, seller, uuid.UUID{}, c, domain.ReasonScam, "", time.Now())
		if err != nil {
			t.Fatal(err)
		}
		got, _, err := s.Open(ctx, r)
		if err != nil {
			t.Fatal(err)
		}
		return got
	}
	if got := open(conversation); got.ConversationID() != conversation {
		t.Fatalf("open: %+v", got.State())
	}
	if got, _ := s.Get(ctx, open(conversation).ID()); got.ConversationID() != conversation {
		t.Fatalf("get: %+v", got.State())
	}
	if got := open(uuid.UUID{}); got.ConversationID() != (uuid.UUID{}) {
		t.Fatalf("again without one: %+v", got.State())
	}
}
```

(Add `"github.com/jackc/pgx/v5"` to the imports; `account_a < account_b` compares UUIDs, and the string order of canonical UUIDs is the same order.)

Run: `go test ./internal/trust/repository/ -run TestReport`
Expected: FAIL (column not read: `ConversationID()` zero).

- [ ] **Step 5: Repository (GREEN)**

In `internal/trust/repository/report_pg.go`:

```go
const reportColumns = `id, reporter_id, account_id, listing_id, conversation_id, reason, note, created_at, updated_at, withdrawn_at`

func scanReport(row pgx.Row, more ...any) (domain.Report, error) {
	var (
		st                    domain.ReportState
		listing, conversation *uuid.UUID
	)
	dest := append([]any{
		&st.ID, &st.ReporterID, &st.AccountID, &listing, &conversation, &st.Reason, &st.Note, &st.CreatedAt, &st.UpdatedAt,
		&st.WithdrawnAt,
	}, more...)
	if err := row.Scan(dest...); err != nil {
		return domain.Report{}, fmt.Errorf("scan report: %w", err)
	}
	if listing != nil {
		st.ListingID = *listing
	}
	if conversation != nil {
		st.ConversationID = *conversation
	}
	return domain.RestoreReport(st), nil
}
```

In `Open`, add `var conversation *uuid.UUID; if st.ConversationID != (uuid.UUID{}) { conversation = &st.ConversationID }`, insert `@conversation` after `@listing` in `VALUES`, pass `"conversation": conversation`, and extend the update: `SET reason = EXCLUDED.reason, note = EXCLUDED.note, conversation_id = EXCLUDED.conversation_id, updated_at = EXCLUDED.updated_at`. Update the `Reports.Open` comment in `report.go`: "replaces that report's reason, note and conversation with r's".

Run: `go test ./internal/trust/repository/`
Expected: PASS.

- [ ] **Step 6: Service test (RED)**

In `internal/trust/service/helpers_test.go`, build a chat service for trust and keep it in `env`:

```go
	media := mediatest.Service(db, objectstoretest.New(t), in, p)
	c := catalogtest.Service(db, accounts, media, in, p)
	// ...deals as before...
	chats := chatsvc.New(chatsvc.Deps{
		Chats: chatrepo.NewChats(db), Accounts: accounts, Catalog: c, Media: media, Ingress: in, Prefix: p, Now: time.Now,
	})
	restatetest.Start(t, slices.Concat(deals.Durable(), media.Durable(), chats.Durable())...)
	trust := service.New(service.Deps{
		Reviews: repository.NewReviews(db), Reports: repository.NewReports(db), Accounts: accounts, Catalog: c, Deals: deals,
		Chats: chats, Now: time.Now,
	})
	return env{db: db, accounts: accounts, deals: deals, chats: chats, trust: trust}
```

with `chats *chatsvc.Chat` in `env` and imports `chatrepo ".../internal/chat/repository"`, `chatsvc ".../internal/chat/service"`, `"slices"`. Add a helper:

```go
// conversation has buyer open a conversation on a listing of seller's.
func (e env) conversation(t *testing.T, buyer, seller uuid.UUID) uuid.UUID {
	t.Helper()
	v, err := e.chats.Open(context.Background(), buyer, uuid.NewV7().String(), chatsvc.OpenInput{
		ListingID: catalogtest.Listing(t, e.db, seller), Text: "Còn không bạn?",
	})
	if err != nil {
		t.Fatal(err)
	}
	return v.ID
}
```

In `report_test.go` add:

```go
// A report of an account may name the pair's conversation, also after the
// reporter blocked the account; another pair's conversation or one beside a
// listing is invalid_report.
func TestReportFromAConversation(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	e := newEnv(t)
	reporter, seller, other := e.person(t), e.person(t), e.person(t)
	c := e.conversation(t, reporter, seller)
	theirs := e.conversation(t, other, seller)
	if err := e.accounts.Block(ctx, reporter, seller); err != nil {
		t.Fatal(err)
	}
	v, added, err := e.trust.Report(ctx, reporter, service.ReportInput{AccountID: seller, ConversationID: c, Reason: domain.ReasonScam})
	if err != nil || !added || v.ConversationID != c {
		t.Fatalf("report: %+v %v %v", v, added, err)
	}
	for name, in := range map[string]service.ReportInput{
		"another pair's":  {AccountID: seller, ConversationID: theirs, Reason: domain.ReasonScam},
		"an unknown one":  {AccountID: seller, ConversationID: uuid.NewV7(), Reason: domain.ReasonScam},
		"beside a listing": {ListingID: catalogtest.Listing(t, e.db, seller), ConversationID: c, Reason: domain.ReasonScam},
	} {
		if _, _, cerr := e.trust.Report(ctx, reporter, in); !errors.Is(cerr, domain.ErrInvalidReport) {
			t.Errorf("%s: %v", name, cerr)
		}
	}
	again, _, err := e.trust.Report(ctx, reporter, service.ReportInput{AccountID: seller, Reason: domain.ReasonScam})
	if err != nil || again.ID != v.ID || again.ConversationID != (uuid.UUID{}) {
		t.Fatalf("again without one: %+v %v", again, err)
	}
}
```

Run: `go test ./internal/trust/service/ -run TestReport`
Expected: build failure (`Chats`, `ConversationID` undefined).

- [ ] **Step 7: Service, handler, mount (GREEN)**

`service.go`: add `Chats chatsvc.Service` to `Deps` with the comment `// Chats tells whether a report's conversation is the reporter's with the account.`, a `chats chatsvc.Service` field, set in `New`. Import `chatsvc "github.com/shopnexus/server/internal/chat/service"`. Update the `Report` doc line in the interface: "or replaces the reason, note and conversation of their open report of it".

`views.go`: `ReportInput` gains `ConversationID uuid.UUID` (doc: "ConversationID, with AccountID only, is the reporter's conversation with the account."), `ReportView` gains `ConversationID uuid.UUID \`json:"conversation_id,omitzero"\`` after `AccountID`.

`report.go`, in `Report`, after the `else if _, err = s.accounts.Get(...)` branch and before `domain.NewReport`:

```go
	if in.ConversationID != (uuid.UUID{}) && in.ListingID == (uuid.UUID{}) {
		pair, cerr := s.chats.ConversationWith(ctx, reporter, account)
		if cerr != nil {
			return ReportView{}, false, fmt.Errorf("find the pair's conversation: %w", cerr)
		}
		if pair != in.ConversationID {
			return ReportView{}, false, domain.ErrInvalidReport.WithField("conversation_id", "the reporter's conversation with the account")
		}
	}
	r, err := domain.NewReport(uuid.NewV7(), reporter, account, in.ListingID, in.ConversationID, in.Reason, in.Note, s.now())
```

and add `ConversationID: r.ConversationID()` to the returned `ReportView`. (A conversation beside a listing reaches `NewReport`, which refuses it.) Update the use-case comment: "…takes a listing's seller as the account reported, checks a named conversation is the pair's, then opens the report or updates the open one."

`handler/report.go`: `reportRequest` gains `ConversationID uuid.UUID \`json:"conversation_id"\``, passed as `ConversationID: in.ConversationID`.

`trust.go`: `Mount(d module.Deps, accounts accountsvc.Service, catalog catalogsvc.Service, deals dealsvc.Service, chats chatsvc.Service)`, passing `Chats: chats`.

`internal/app/app.go` `mountModules`: move `chatm := chat.Mount(d, accounts, catalogm.Service, mediam.Service)` above `trustm`, and call `trust.Mount(d, accounts, catalogm.Service, dealm.Service, chatm.Service)`.

Run: `go build ./... && go test ./internal/trust/...`
Expected: PASS.

- [ ] **Step 8: API**

`api/schemas/trust.yaml`, `ReportCreate.properties`:

```yaml
    conversation_id:
      type: string
      format: uuid
      description: With account_id only, the caller's conversation with that account; another one is 422 invalid_report.
```

`Report.properties`, after `account_id`:

```yaml
    conversation_id:
      type: string
      format: uuid
      description: The caller's conversation with the account the report came from; absent when none was named.
```

In `api/paths/trust.yaml`, the `POST /v1/reports` 422 description gains "or a conversation_id that is not the caller's conversation with account_id, or one beside listing_id" (read the current text and extend it).

- [ ] **Step 9: e2e**

In `e2e/report_test.go` add `ConversationID string \`json:"conversation_id"\`` to `report`, and:

```go
// The app blocks, then reports with the conversation; another pair's
// conversation is refused.
func TestReportFromAConversation(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	reporter, _ := newAccount(t)
	other, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	c := openChat(t, reporter.AccessToken, l.ID, "Chuyển khoản trước nhé?")
	theirs := openChat(t, other.AccessToken, l.ID, "Còn không bạn?")
	expectStatus(t, call(t, "POST", "/v1/blocks", map[string]any{"account_id": seller.Account.ID}, bearer(reporter.AccessToken)), http.StatusNoContent)
	got := expect[report](t, call(t, "POST", "/v1/reports", map[string]any{
		"account_id": seller.Account.ID, "reason": "scam", "conversation_id": c.ID,
	}, bearer(reporter.AccessToken)), http.StatusCreated)
	if got.ConversationID != c.ID {
		t.Fatalf("report: %+v", got)
	}
	check(t, "another pair's conversation", call(t, "POST", "/v1/reports", map[string]any{
		"account_id": seller.Account.ID, "reason": "scam", "conversation_id": theirs.ID,
	}, bearer(reporter.AccessToken)), 422, "invalid_report")
	check(t, "a conversation beside a listing", call(t, "POST", "/v1/reports", map[string]any{
		"listing_id": l.ID, "reason": "scam", "conversation_id": c.ID,
	}, bearer(reporter.AccessToken)), 422, "invalid_report")
}
```

Run: `go test ./e2e/ -run 'TestReport' > tmp/e2e-report.txt 2>&1; tail -20 tmp/e2e-report.txt`
Expected: PASS.

- [ ] **Step 10: Lint and commit**

Run: `golangci-lint run ./... > tmp/lint.txt 2>&1; tail -20 tmp/lint.txt`
Expected: no issues.

```bash
git add migrations/0029_report_conversation.sql internal/trust internal/app/app.go api e2e/report_test.go
git commit -m "feat(trust): a report of an account may name the conversation it came from"
```

---

### Task 2: Mark a conversation unread

**Files:**
- Create: `migrations/0030_conversation_marked_unread.sql`
- Modify: `internal/chat/repository/repository.go`, `internal/chat/repository/chat_pg.go`, `internal/chat/repository/chat_pg_test.go`
- Modify: `internal/chat/service/service.go`, `internal/chat/service/conversation_read.go`, `internal/chat/service/chat_test.go`
- Modify: `internal/chat/handler/handler.go`, `internal/chat/handler/chat.go`
- Modify: `api/paths/chat.yaml`, `api/openapi.yaml`, `api/schemas/screen_inbox.yaml` (unread descriptions)
- Test: `e2e/chat_test.go`

**Interfaces:**
- Consumes: `stream.Notify(ctx, tx, accounts []uuid.UUID, h stream.Hint) error`, `stream.KindRead`.
- Produces: `repository.Chats.MarkUnread(ctx, conversation, account uuid.UUID) error`; `MarkRead` keeps its signature and now also clears the flag; `service.Service.MarkUnread(ctx, account, conversation uuid.UUID) error`; route `POST /v1/conversations/{id}/unread`. `unreadAfter` stays; the per-row count becomes `greatest(unread.n, cm.marked_unread::int)` (Task 4 reuses the expression through a constant `rowUnread`).

- [ ] **Step 1: Migration**

`migrations/0030_conversation_marked_unread.sql`:

```sql
-- A member marks a conversation unread; it counts as one unread message
-- until the member reads it. The read marker does not move back.
ALTER TABLE conversation_members ADD COLUMN marked_unread boolean NOT NULL DEFAULT false;
```

- [ ] **Step 2: Repository test (RED)**

In `internal/chat/repository/chat_pg_test.go` add a helper and a test:

```go
// updates lists the kinds of account's stream updates about conversation c.
func updates(t *testing.T, db *pgxpool.Pool, account, c uuid.UUID) []string {
	t.Helper()
	rows, err := db.Query(context.Background(), `SELECT kind FROM account_updates
WHERE account_id = @account AND conversation_id = @c ORDER BY seq`, pgx.StrictNamedArgs{"account": account, "c": c})
	if err != nil {
		t.Fatal(err)
	}
	kinds, err := pgx.CollectRows(rows, pgx.RowTo[string])
	if err != nil {
		t.Fatal(err)
	}
	return kinds
}

// A conversation marked unread counts 1 with nothing new and n with n new;
// a read clears the flag without moving the marker, and each change tells
// the member's own stream.
func TestMarkUnread(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewChats(db)
	ctx := context.Background()
	c, a, b := pair(t, db, s)
	last := send(t, s, c, b, "Còn không?")
	if err := s.MarkRead(ctx, c.ID, a, last.ID(), b); err != nil {
		t.Fatal(err)
	}
	before := len(updates(t, db, a, c.ID))
	for range 2 {
		if err := s.MarkUnread(ctx, c.ID, a); err != nil {
			t.Fatal(err)
		}
	}
	if got := updates(t, db, a, c.ID); len(got) != before+1 || got[len(got)-1] != "read" {
		t.Fatalf("one update for the mark: %v", got)
	}
	if n, _ := s.Unread(ctx, a); n != 1 || inbox(t, s, a, false)[0].Unread != 1 {
		t.Fatalf("marked, nothing new: %d", n)
	}
	send(t, s, c, b, "Alo?")
	send(t, s, c, b, "Bạn ơi?")
	if n, _ := s.Unread(ctx, a); n != 2 || inbox(t, s, a, false)[0].Unread != 2 {
		t.Fatalf("marked, two new: %d", n)
	}
	toA, toB := len(updates(t, db, a, c.ID)), len(updates(t, db, b, c.ID))
	if err := s.MarkRead(ctx, c.ID, a, last.ID(), b); err != nil {
		t.Fatal(err)
	}
	if marker(t, db, c.ID, a) != last.ID() {
		t.Fatal("the marker moved")
	}
	if n, _ := s.Unread(ctx, a); n != 2 {
		t.Fatalf("the flag is cleared, two remain: %d", n)
	}
	if got := updates(t, db, b, c.ID); len(got) != toB {
		t.Fatalf("a read that moves no marker tells the other nothing: %v", got)
	}
	if got := updates(t, db, a, c.ID); len(got) != toA+1 || got[len(got)-1] != "read" {
		t.Fatalf("clearing the flag tells the member: %v", got)
	}
	if err := s.MarkRead(ctx, c.ID, a, last.ID(), b); err != nil {
		t.Fatal(err)
	}
	if got := updates(t, db, a, c.ID); len(got) != toA+1 {
		t.Fatalf("a read that changes nothing tells nobody: %v", got)
	}
}
```

Run: `go test ./internal/chat/repository/ -run TestMarkUnread`
Expected: build failure (`MarkUnread` undefined).

- [ ] **Step 3: Repository (GREEN)**

`repository.go`, in `Chats`:

```go
	// MarkRead moves account's marker to message when message is newer than
	// the marker and clears account's unread mark, in one update; a move
	// notifies other, a cleared mark notifies account.
	MarkRead(ctx context.Context, conversation, account, message, other uuid.UUID) error
	// MarkUnread sets account's unread mark; setting it notifies account.
	MarkUnread(ctx context.Context, conversation, account uuid.UUID) error
```

`chat_pg.go`:

```go
func (s pgChats) MarkRead(ctx context.Context, conversation, account, message, other uuid.UUID) error {
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		var moved, cleared bool
		err := tx.QueryRow(ctx, `UPDATE conversation_members
SET last_read_message_id = CASE
        WHEN last_read_message_id IS NULL OR last_read_message_id < @message THEN @message
        ELSE last_read_message_id END,
    marked_unread = false
WHERE conversation_id = @conversation AND account_id = @account
RETURNING old.last_read_message_id IS DISTINCT FROM new.last_read_message_id, old.marked_unread`,
			pgx.StrictNamedArgs{"message": message, "conversation": conversation, "account": account}).Scan(&moved, &cleared)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("update marker: %w", err)
		}
		var to []uuid.UUID
		if moved {
			to = append(to, other)
		}
		if cleared {
			to = append(to, account)
		}
		if len(to) == 0 {
			return nil
		}
		return stream.Notify(ctx, tx, to, stream.Hint{Kind: stream.KindRead, ConversationID: &conversation})
	})
	if err != nil {
		return fmt.Errorf("mark read: %w", err)
	}
	return nil
}

func (s pgChats) MarkUnread(ctx context.Context, conversation, account uuid.UUID) error {
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `UPDATE conversation_members SET marked_unread = true
WHERE conversation_id = @conversation AND account_id = @account AND NOT marked_unread`,
			pgx.StrictNamedArgs{"conversation": conversation, "account": account})
		if err != nil {
			return fmt.Errorf("set the mark: %w", err)
		}
		if tag.RowsAffected() == 0 {
			return nil
		}
		return stream.Notify(ctx, tx, []uuid.UUID{account}, stream.Hint{Kind: stream.KindRead, ConversationID: &conversation})
	})
	if err != nil {
		return fmt.Errorf("mark unread: %w", err)
	}
	return nil
}
```

(`RETURNING old.… new.…` is Postgres 18 syntax.)

The counts: add a constant beside `unreadAfter`, and use it in `selectInbox` and `countUnread`:

```go
// rowUnread is a row's unread count: the messages after the marker, and at
// least 1 while the member's unread mark is set. It reads marked from the
// query's member row.
const rowUnread = `greatest(unread.n, marked::int)`
```

`selectInbox`: the inner page selects `cm.marked_unread AS marked` beside `last_read`, and the outer select returns `` `+rowUnread+` `` instead of `unread.n`. `countUnread`: `SELECT coalesce(sum(` + rowUnread + `), 0)` and the lateral becomes `CROSS JOIN LATERAL (SELECT cm.last_read_message_id, cm.marked_unread) marker (last_read, marked)`. Update the `Unread` comment in `repository.go`: "counts viewer's unread messages over unarchived conversations the inbox lists, a conversation marked unread counting at least 1".

Run: `go test ./internal/chat/repository/`
Expected: PASS (existing `TestMarkReadNeverGoesBack` and `TestReadKeepsTheArchive` still pass).

- [ ] **Step 4: Service test (RED)**

In `internal/chat/service/chat_test.go`:

```go
func TestMarkUnread(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	e := newEnv(t)
	seller, buyer, stranger := e.person(t), e.person(t), e.person(t)
	c := e.open(t, buyer, catalogtest.Listing(t, e.db, seller), "Còn không bạn?")
	if err := e.chat.MarkUnread(ctx, buyer, c.ID); err != nil {
		t.Fatal(err)
	}
	if n, _ := e.chat.Unread(ctx, buyer); n != 1 {
		t.Fatalf("buyer's unread: %d", n)
	}
	if err := e.chat.MarkUnread(ctx, stranger, c.ID); !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("a stranger: %v", err)
	}
	if err := e.chat.MarkUnread(ctx, buyer, uuid.NewV7()); !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("unknown: %v", err)
	}
}
```

Run: `go test ./internal/chat/service/ -run TestMarkUnread`
Expected: build failure.

- [ ] **Step 5: Service and handler (GREEN)**

`service.go`, in `Service` after `Read`:

```go
	// MarkUnread marks a conversation of account's unread until account
	// reads it; the read marker stays.
	MarkUnread(ctx context.Context, account, conversation uuid.UUID) error
```

and change the `Read` doc: "Read moves account's read marker to message when message is newer, and clears account's unread mark."

`conversation_read.go`:

```go
func (c *Chat) MarkUnread(ctx context.Context, account, conversation uuid.UUID) error {
	if _, _, err := c.member(ctx, account, conversation); err != nil {
		return err
	}
	if err := c.chats.MarkUnread(ctx, conversation, account); err != nil {
		return fmt.Errorf("mark unread: %w", err)
	}
	return nil
}
```

`handler.go`: `r.Handle("POST /v1/conversations/{id}/unread", protect(http.HandlerFunc(h.MarkUnread)))` after the read route. `chat.go`:

```go
// MarkUnread serves POST /v1/conversations/{id}/unread.
func (h *Handler) MarkUnread(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in conversationRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.MarkUnread(r.Context(), p.AccountID, in.ID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

Check other implementers of `chatsvc.Service` (fakes in tests): `grep -rn "chatsvc.Service\|chat/service\"" internal --include='*_test.go'` and add `MarkUnread` where a fake implements the interface.

Run: `go build ./... && go test ./internal/chat/...`
Expected: PASS.

- [ ] **Step 6: API**

`api/paths/chat.yaml`, after `conversationRead`:

```yaml
conversationUnread:
  post:
    operationId: markConversationUnread
    summary: Mark a conversation unread until the caller reads it.
    description: |
      The conversation counts at least 1 in the inbox row's unread and in
      GET /v1/me/unread. POST /v1/conversations/{id}/read clears the mark.
      The read marker, and what the other member sees as read, stay.
    tags: [chat]
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
        description: Marked.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "No such conversation of the caller's (conversation_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

`api/openapi.yaml`, after the read path:

```yaml
  /v1/conversations/{id}/unread:
    $ref: "paths/chat.yaml#/conversationUnread"
```

In `conversationRead`'s description (add one if absent) say that the read also clears the caller's unread mark. In `api/schemas/screen_inbox.yaml` `InboxItem.unread` gets `description: The other member's sent messages after the caller's read marker; at least 1 while the caller's unread mark is set.`

- [ ] **Step 7: e2e**

In `e2e/chat_test.go`:

```go
func TestMarkConversationUnread(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	c := openChat(t, buyer.AccessToken, activeListing(t, seller.AccessToken, nil).ID, "Còn không bạn?")
	path := "/v1/conversations/" + c.ID + "/unread"
	check(t, "mark", call(t, "POST", path, nil, bearer(buyer.AccessToken)), 204, "")
	if got := expect[map[string]int](t, call(t, "GET", "/v1/me/unread", nil, bearer(buyer.AccessToken)), http.StatusOK); got["unread"] != 1 {
		t.Fatalf("unread after the mark: %v", got)
	}
	last := chatMessages(t, buyer.AccessToken, c.ID)[0]
	expectStatus(t, call(t, "POST", "/v1/conversations/"+c.ID+"/read", map[string]any{"message_id": last.ID}, bearer(buyer.AccessToken)), http.StatusNoContent)
	if got := expect[map[string]int](t, call(t, "GET", "/v1/me/unread", nil, bearer(buyer.AccessToken)), http.StatusOK); got["unread"] != 0 {
		t.Fatalf("unread after reading: %v", got)
	}
	check(t, "mark signed out", call(t, "POST", path, nil), 401, "unauthenticated")
	check(t, "mark a bad id", call(t, "POST", "/v1/conversations/x/unread", nil, bearer(buyer.AccessToken)), 400, "")
	stranger, _ := newAccount(t)
	check(t, "mark someone else's", call(t, "POST", path, nil, bearer(stranger.AccessToken)), 404, "conversation_not_found")
}
```

Run: `go test ./e2e/ -run 'TestMarkConversationUnread|TestChat' > tmp/e2e-unread.txt 2>&1; tail -20 tmp/e2e-unread.txt`
Expected: PASS.

- [ ] **Step 8: Lint and commit**

Run: `golangci-lint run ./... > tmp/lint.txt 2>&1; tail -20 tmp/lint.txt`
Expected: no issues.

```bash
git add migrations/0030_conversation_marked_unread.sql internal/chat api e2e/chat_test.go
git commit -m "feat(chat): mark a conversation unread until the next read"
```

---

### Task 3: Notifications unread, and read-all returns its IDs

**Files:**
- Modify: `internal/notification/repository/repository.go`, `internal/notification/repository/notice_pg.go`, `internal/notification/repository/notice_pg_test.go`
- Modify: `internal/notification/service/service.go`, `internal/notification/service/notices.go`, `internal/notification/service/notices_test.go` (only if it calls `ReadAll`)
- Modify: `internal/notification/handler/handler.go`
- Modify: `api/paths/notification.yaml`, `api/schemas/notification.yaml`, `api/openapi.yaml`
- Test: `e2e/notification_test.go`

**Interfaces:**
- Produces: `repository.Notices.ReadAll(ctx, account uuid.UUID, at time.Time) ([]uuid.UUID, error)`; `repository.Notices.MarkUnread(ctx, account uuid.UUID, ids []uuid.UUID) error`; `service.Service.ReadAll(ctx, account) ([]uuid.UUID, error)`; `service.Service.MarkUnread(ctx, account uuid.UUID, ids []uuid.UUID) error`; routes `POST /v1/notifications/read-all` (200 `{ids}`) and `POST /v1/notifications/unread`.

- [ ] **Step 1: Repository test (RED)**

In `internal/notification/repository/notice_pg_test.go` change the existing `s.ReadAll(ctx, me, now)` calls to `_, err = s.ReadAll(...)` (keep the checks), and add:

```go
// ReadAll returns exactly the notices it marked read.
func TestReadAllReturnsItsIDs(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	s := repository.NewNotices(db)
	me := accounttest.New(t, db)
	expired := now.Add(-domain.Retention)
	read, _, err := s.Add(ctx, uuid.NewV7(), notice(me, "deal:1", 100, now), expired)
	if err != nil {
		t.Fatal(err)
	}
	if err = s.Read(ctx, me, read, now); err != nil {
		t.Fatal(err)
	}
	unread, _, err := s.Add(ctx, uuid.NewV7(), notice(me, "deal:2", 100, now), expired)
	if err != nil {
		t.Fatal(err)
	}
	ids, err := s.ReadAll(ctx, me, now)
	if err != nil || len(ids) != 1 || ids[0] != unread {
		t.Fatalf("read all: %v %v", ids, err)
	}
	if ids, err = s.ReadAll(ctx, me, now); err != nil || len(ids) != 0 || ids == nil {
		t.Fatalf("again: %#v %v", ids, err)
	}
}

// MarkUnread makes the caller's read notices unread, one per collapse key:
// the newest, and none for a key that has an unread notice.
func TestMarkUnreadCollapse(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	ctx := context.Background()
	s := repository.NewNotices(db)
	me, other := accounttest.New(t, db), accounttest.New(t, db)
	expired := now.Add(-domain.Retention)
	add := func(to uuid.UUID, key string, at time.Time) uuid.UUID {
		t.Helper()
		id, _, err := s.Add(ctx, uuid.NewV7(), notice(to, key, 100, at), expired)
		if err != nil {
			t.Fatal(err)
		}
		if err = s.Read(ctx, to, id, at); err != nil {
			t.Fatal(err)
		}
		return id
	}
	older, newer := add(me, "deal:1", now), add(me, "deal:1", now.Add(time.Minute))
	keyless := add(me, "", now)
	covered := add(me, "deal:2", now)
	if _, _, err := s.Add(ctx, uuid.NewV7(), notice(me, "deal:2", 200, now.Add(time.Minute)), expired); err != nil {
		t.Fatal(err)
	}
	theirs := add(other, "", now)
	if err := s.MarkUnread(ctx, me, []uuid.UUID{older, newer, keyless, covered, theirs, uuid.NewV7()}); err != nil {
		t.Fatal(err)
	}
	unread := func(account uuid.UUID) map[uuid.UUID]bool {
		t.Helper()
		rows, err := s.List(ctx, account, page.Request{})
		if err != nil {
			t.Fatal(err)
		}
		out := map[uuid.UUID]bool{}
		for _, r := range rows {
			out[r.ID] = !r.Read
		}
		return out
	}
	got := unread(me)
	if got[older] || !got[newer] || !got[keyless] || got[covered] {
		t.Fatalf("me: %v", got)
	}
	if unread(other)[theirs] {
		t.Fatal("someone else's notice changed")
	}
	if err := s.MarkUnread(ctx, me, []uuid.UUID{newer}); err != nil {
		t.Fatalf("an unread notice again: %v", err)
	}
}
```

Run: `go test ./internal/notification/repository/ -run 'TestReadAll|TestMarkUnread'`
Expected: build failure.

- [ ] **Step 2: Repository (GREEN)**

`repository.go`:

```go
	// ReadAll marks the account's unread notices read and returns their IDs,
	// an empty slice when there were none.
	ReadAll(ctx context.Context, account uuid.UUID, at time.Time) ([]uuid.UUID, error)
	// MarkUnread makes the account's read notices among ids unread: per
	// collapse key only the newest, and none for a key with an unread
	// notice. Other IDs are skipped.
	MarkUnread(ctx context.Context, account uuid.UUID, ids []uuid.UUID) error
```

`notice_pg.go`:

```go
func (s pgNotices) ReadAll(ctx context.Context, account uuid.UUID, at time.Time) ([]uuid.UUID, error) {
	rows, err := s.db.Query(ctx, `UPDATE notifications SET read_at = @at
WHERE account_id = @account AND read_at IS NULL RETURNING id`, pgx.StrictNamedArgs{"account": account, "at": at})
	if err != nil {
		return nil, fmt.Errorf("read all: %w", err)
	}
	ids, err := pgx.CollectRows(rows, pgx.RowTo[uuid.UUID])
	if err != nil {
		return nil, fmt.Errorf("read all: %w", err)
	}
	if ids == nil {
		ids = []uuid.UUID{}
	}
	return ids, nil
}

// markUnread picks, per collapse key, the newest of the account's read
// notices among the IDs, and clears its read_at unless the key has an
// unread notice; notices without a key are each their own group.
const markUnread = `
WITH picked AS (
    SELECT DISTINCT ON (coalesce(collapse_key, id::text)) id, collapse_key
    FROM notifications
    WHERE account_id = @account AND id = ANY(@ids) AND read_at IS NOT NULL
    ORDER BY coalesce(collapse_key, id::text), bumped_at DESC, id DESC
)
UPDATE notifications n SET read_at = NULL
FROM picked p
WHERE n.id = p.id
  AND (p.collapse_key IS NULL OR NOT EXISTS (
      SELECT 1 FROM notifications u
      WHERE u.account_id = @account AND u.collapse_key = p.collapse_key AND u.read_at IS NULL))`

func (s pgNotices) MarkUnread(ctx context.Context, account uuid.UUID, ids []uuid.UUID) error {
	args := pgx.StrictNamedArgs{"account": account, "ids": ids}
	_, err := s.db.Exec(ctx, markUnread, args)
	if pgErr, ok := errors.AsType[*pgconn.PgError](err); ok && pgErr.Code == "23505" {
		// A notice of a picked key became unread between the check and the
		// write; the second run sees it and leaves the key alone.
		_, err = s.db.Exec(ctx, markUnread, args)
	}
	if err != nil {
		return fmt.Errorf("mark unread: %w", err)
	}
	return nil
}
```

The repo has no unique-violation helper yet; import `github.com/jackc/pgx/v5/pgconn` and compare the code `"23505"` (unique_violation) as above.

Run: `go test ./internal/notification/repository/`
Expected: PASS.

- [ ] **Step 3: Service and handler**

`service.go`:

```go
	// ReadAll marks every unread notice of the account's read and returns
	// their IDs, for an undo through MarkUnread.
	ReadAll(ctx context.Context, account uuid.UUID) ([]uuid.UUID, error)
	// MarkUnread makes the account's notices among ids unread; see
	// repository.Notices.MarkUnread.
	MarkUnread(ctx context.Context, account uuid.UUID, ids []uuid.UUID) error
```

`notices.go`:

```go
func (s *Notification) ReadAll(ctx context.Context, account uuid.UUID) ([]uuid.UUID, error) {
	ids, err := s.notices.ReadAll(ctx, account, s.now())
	if err != nil {
		return nil, fmt.Errorf("read all: %w", err)
	}
	return ids, nil
}

func (s *Notification) MarkUnread(ctx context.Context, account uuid.UUID, ids []uuid.UUID) error {
	if err := s.notices.MarkUnread(ctx, account, ids); err != nil {
		return fmt.Errorf("mark unread: %w", err)
	}
	return nil
}
```

`handler.go`: register `r.Handle("POST /v1/notifications/unread", protect(http.HandlerFunc(h.MarkUnread)))` after read-all, and:

```go
type readAllResponse struct {
	IDs []uuid.UUID `json:"ids"`
}

// ReadAll serves POST /v1/notifications/read-all.
func (h *Handler) ReadAll(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	ids, err := h.svc.ReadAll(r.Context(), p.AccountID)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, readAllResponse{IDs: ids})
}

type unreadRequest struct {
	IDs []uuid.UUID `json:"ids"`
}

// MarkUnread serves POST /v1/notifications/unread.
func (h *Handler) MarkUnread(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in unreadRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.MarkUnread(r.Context(), p.AccountID, in.IDs); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

Find other callers and fakes of `ReadAll` / the notification `Service` interface (`grep -rn "ReadAll(\|notificationsvc.Service" internal e2e`) and update them.

Run: `go build ./... && go test ./internal/notification/...`
Expected: PASS.

- [ ] **Step 4: API**

`api/schemas/notification.yaml`:

```yaml
NotificationIDs:
  type: object
  additionalProperties: false
  required: [ids]
  properties:
    ids:
      type: array
      minItems: 1
      maxItems: 500
      uniqueItems: true
      items:
        type: string
        format: uuid
ReadAllResult:
  type: object
  additionalProperties: false
  required: [ids]
  properties:
    ids:
      type: array
      description: The notices this call marked read; pass them to POST /v1/notifications/unread to undo it.
      items:
        type: string
        format: uuid
```

`api/paths/notification.yaml`: `readAll` 204 becomes

```yaml
      "200":
        description: Read; the IDs it changed.
        content:
          application/json:
            schema:
              $ref: "../schemas/notification.yaml#/ReadAllResult"
```

and a new entry:

```yaml
unread:
  post:
    operationId: markNotificationsUnread
    summary: Mark some of the caller's notices unread.
    description: |
      Serves one notice and the undo of read-all. IDs that are unknown or
      someone else's are skipped. Of the read notices that share a collapse
      key only the newest becomes unread, and none when the key already has
      an unread notice: that notice stands for the key.
    tags: [notification]
    security:
      - bearerAuth: []
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "../schemas/notification.yaml#/NotificationIDs"
    responses:
      "204":
        description: Done.
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
```

`api/openapi.yaml`, after read-all: `  /v1/notifications/unread:` / `    $ref: "paths/notification.yaml#/unread"`.

- [ ] **Step 5: e2e**

In `e2e/notification_test.go`, the two `read-all` calls in `TestNotifications` become `expect[struct{ IDs []string \`json:"ids"\` }](…, http.StatusOK)`. Add to the end of `TestNotifications`, after the "after reading" check (the seller has two read notices then):

```go
	all := notices(t, seller.AccessToken, 2)
	expectStatus(t, call(t, "POST", "/v1/notifications/unread", map[string]any{"ids": []string{all.Items[0].ID}}, bearer(seller.AccessToken)), http.StatusNoContent)
	if got = notices(t, seller.AccessToken, 2); got.Unread != 1 || !got.Items[0].Unread {
		t.Fatalf("after marking one unread: %+v", got)
	}
	undo := expect[struct {
		IDs []string `json:"ids"`
	}](t, call(t, "POST", "/v1/notifications/read-all", nil, bearer(seller.AccessToken)), http.StatusOK)
	if len(undo.IDs) != 1 || undo.IDs[0] != all.Items[0].ID {
		t.Fatalf("read-all's IDs: %+v", undo)
	}
	expectStatus(t, call(t, "POST", "/v1/notifications/unread", map[string]any{"ids": undo.IDs}, bearer(seller.AccessToken)), http.StatusNoContent)
	if got = notices(t, seller.AccessToken, 2); got.Unread != 1 {
		t.Fatalf("after the undo: %+v", got)
	}
```

(Place it before the chat-push part only if the later assertions there depend on the unread count; read the test and put it where the counts stay consistent.)

In `TestNotificationRefusals` add rows for `"unread signed out": {"POST", "/v1/notifications/unread", map[string]any{"ids": []string{uuid.NewV7().String()}}, "", 401}`, and checks for 400: an empty list, 501 IDs, a bad ID (follow that test's table shape; read it first).

Run: `go test ./e2e/ -run 'TestNotification' > tmp/e2e-notice.txt 2>&1; tail -20 tmp/e2e-notice.txt`
Expected: PASS.

- [ ] **Step 6: Lint and commit**

Run: `golangci-lint run ./... > tmp/lint.txt 2>&1; tail -20 tmp/lint.txt`
Expected: no issues.

```bash
git add internal/notification api e2e/notification_test.go
git commit -m "feat(notification): mark notices unread, and read-all returns the IDs it read"
```

---

### Task 4: Chat search (repository and use case)

**Files:**
- Create: `migrations/0031_messages_search.sql`
- Create: `internal/chat/repository/search_pg.go`, `internal/chat/repository/search_pg_test.go`
- Create: `internal/chat/service/search.go`, `internal/chat/service/search_test.go`
- Modify: `internal/chat/repository/repository.go`, `internal/chat/repository/chat_pg.go` (`InboxRow.Archived`, `notBlocked`)
- Modify: `internal/chat/domain/errors.go`, `internal/chat/domain/chat.go` (`MaxQuery`)
- Modify: `internal/chat/service/service.go`, `internal/chat/service/views.go`, `internal/chat/service/conversation_get.go`

**Interfaces:**
- Consumes: `rowUnread`, `unreadAfter` (Task 2), `accountsvc.Service.GetMany`.
- Produces:
  - `domain.ErrInvalidQuery` (`invalid_query`, KindInvalid), `domain.MaxQuery = 100`.
  - `repository.Terms{Whole []string; Prefix string}`.
  - `repository.Chats.Tokens(ctx, q string) ([]string, error)`.
  - `repository.Chats.SearchThreads(ctx, viewer uuid.UUID, t Terms, limit int) ([]InboxRow, error)`.
  - `repository.Chats.SearchMessages(ctx, viewer uuid.UUID, t Terms, p page.Request) ([]MessageHitRow, error)`; `MessageHitRow{Message domain.Message; Other uuid.UUID}`.
  - `InboxRow.Archived bool`.
  - `service.Service.Search(ctx, account uuid.UUID, q string, p page.Request) (SearchResult, error)`; `SearchResult{Threads []InboxItem; Messages page.Page[MessageHit]}`; `MessageHit{ConversationID uuid.UUID; Other PersonView; Message MessageView}` with JSON `conversation_id`, `other`, `message`; `service.SearchThreads = 20`.

- [ ] **Step 1: Migration**

`migrations/0031_messages_search.sql`:

```sql
-- Inbox search: ParadeDB's BM25 index over message bodies, folded to
-- lowercase ASCII, with the conversation and status to filter inside the
-- index and the ID to page by.
CREATE INDEX messages_search ON messages USING paradedb (
    id, (body::pdb.simple('ascii_folding=true')), conversation_id, (status::pdb.literal)
);
```

- [ ] **Step 2: Repository test (RED)**

`internal/chat/repository/search_pg_test.go` (uses `pair`, `send`, `inbox` from `chat_pg_test.go`; `catalogtest.Listing` with a change func sets the title):

```go
package repository_test

import (
	"context"
	"slices"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"

	"github.com/shopnexus/server/internal/catalog/catalogtest"
	catalogdomain "github.com/shopnexus/server/internal/catalog/domain"
	"github.com/shopnexus/server/internal/chat/domain"
	"github.com/shopnexus/server/internal/chat/repository"
	"github.com/shopnexus/server/internal/platform/page"
	"github.com/shopnexus/server/internal/platform/postgres/pgtest"
)

func terms(t *testing.T, s repository.Chats, q string) repository.Terms {
	t.Helper()
	toks, err := s.Tokens(context.Background(), q)
	if err != nil || len(toks) == 0 {
		t.Fatalf("tokens of %q: %v %v", q, toks, err)
	}
	return repository.Terms{Whole: toks[:len(toks)-1], Prefix: toks[len(toks)-1]}
}

func TestTokens(t *testing.T) {
	t.Parallel()
	s := repository.NewChats(pgtest.New(t))
	for q, want := range map[string][]string{
		"Giày ĐỒ cũ, SHIP!": {"giay", "do", "cu", "ship"},
		"  !!! ,, ":         {},
		"a.b+c":             {"a", "b", "c"},
	} {
		got, err := s.Tokens(context.Background(), q)
		if err != nil || !slices.Equal(got, want) {
			t.Errorf("%q: %v %v", q, got, err)
		}
	}
}

func messageIDs(rows []repository.MessageHitRow) []uuid.UUID {
	out := make([]uuid.UUID, len(rows))
	for i, r := range rows {
		out[i] = r.Message.ID()
	}
	return out
}

// Words fold case and accents, every word but the last matches whole, the
// last as a prefix; only sent messages of the viewer's listed
// conversations, archived ones too, newest first, paged by cursor.
func TestSearchMessages(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewChats(db)
	c, a, b := pair(t, db, s)
	first := send(t, s, c, b, "Giày SHIP nhanh không bạn")
	second := send(t, s, c, a, "ship nhé, đồ còn mới")
	send(t, s, c, b, "nhanh lên")
	photo := send(t, s, c, b, "ship nhanh", uuid.NewV7()) // processing: only its sender sees it
	other, x, _ := pair(t, db, s)
	send(t, s, other, x, "ship nhanh")
	if err := s.SetArchived(ctx, c.ID, a, new(time.Now())); err != nil {
		t.Fatal(err)
	}

	got, err := s.SearchMessages(ctx, a, terms(t, s, "ship NH"), page.Request{})
	if err != nil || !slices.Equal(messageIDs(got), []uuid.UUID{second.ID(), first.ID()}) || got[0].Other != b {
		t.Fatalf("ship nh: %v %v", messageIDs(got), err)
	}
	if got, _ = s.SearchMessages(ctx, a, terms(t, s, "giay"), page.Request{}); !slices.Equal(messageIDs(got), []uuid.UUID{first.ID()}) {
		t.Fatalf("giay: %v", messageIDs(got))
	}
	if got, _ = s.SearchMessages(ctx, a, terms(t, s, "Đồ"), page.Request{}); !slices.Equal(messageIDs(got), []uuid.UUID{second.ID()}) {
		t.Fatalf("đồ: %v", messageIDs(got))
	}
	if got, _ = s.SearchMessages(ctx, a, terms(t, s, "shi nhanh"), page.Request{}); len(got) != 0 {
		t.Fatalf("a middle word matches whole: %v", messageIDs(got))
	}
	if got, _ = s.SearchMessages(ctx, a, terms(t, s, "ship"), page.Request{Limit: 1}); len(got) != 2 ||
		got[0].Message.ID() != second.ID() {
		t.Fatalf("first page reads one more: %v", messageIDs(got))
	}
	if got, _ = s.SearchMessages(ctx, a, terms(t, s, "ship"), page.Request{Cursor: second.ID()}); !slices.Equal(messageIDs(got), []uuid.UUID{first.ID()}) {
		t.Fatalf("next page: %v", messageIDs(got))
	}
	if slices.Contains(messageIDs(got), photo.ID()) {
		t.Fatal("a processing message matched")
	}
	if _, err = db.Exec(ctx, `INSERT INTO account_blocks (id, blocker_id, blocked_id, created_at) VALUES (@id, @a, @b, now())`,
		pgx.StrictNamedArgs{"id": uuid.NewV7(), "a": a, "b": b}); err != nil {
		t.Fatal(err)
	}
	if got, _ = s.SearchMessages(ctx, a, terms(t, s, "ship"), page.Request{}); len(got) != 0 {
		t.Fatalf("a blocked pair: %v", messageIDs(got))
	}
}

// A thread matches by the other member's name or by the title of a listing
// a message names; a deleted person's empty name matches nothing.
func TestSearchThreads(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewChats(db)
	viewer := accounttest.New(t, db)
	byName, hanh := pairWith(t, db, s, viewer)
	byTitle, seller := pairWith(t, db, s, viewer)
	deleted, gone := pairWith(t, db, s, viewer)
	for id, name := range map[uuid.UUID]string{hanh: "Ngọc Hân", seller: "Shop Đồ Cũ", gone: "Hân Hân"} {
		if _, err := db.Exec(ctx, `UPDATE accounts SET display_name = @n WHERE id = @id`, pgx.StrictNamedArgs{"n": name, "id": id}); err != nil {
			t.Fatal(err)
		}
	}
	send(t, s, byName, hanh, "Chào")
	listing := catalogtest.Listing(t, db, seller, func(d *catalogdomain.Draft, _ *catalogdomain.Refs) { d.Title = "Giày Nike Air cũ" })
	m, err := domain.NewMessage(uuid.NewV7(), byTitle.ID, viewer, "Còn không?", nil, &listing, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if err = s.AddMessage(ctx, m); err != nil {
		t.Fatal(err)
	}
	send(t, s, deleted, gone, "Alo")
	if _, err = db.Exec(ctx, `UPDATE accounts SET status = 'deleted', deleted_at = now(), display_name = NULL WHERE id = @id`,
		pgx.StrictNamedArgs{"id": gone}); err != nil {
		t.Fatal(err)
	}
	ids := func(rows []repository.InboxRow) []uuid.UUID {
		out := make([]uuid.UUID, len(rows))
		for i, r := range rows {
			out[i] = r.Conversation.ID
		}
		return out
	}
	for q, want := range map[string][]uuid.UUID{
		"ngoc ha":   {byName.ID},
		"HAN":       {byName.ID},
		"giay nik":  {byTitle.ID},
		"do cu":     {byTitle.ID},
		"nike shop": {},
	} {
		got, err := s.SearchThreads(ctx, viewer, terms(t, s, q), 20)
		if err != nil || !slices.Equal(ids(got), want) {
			t.Errorf("%q: %v %v", q, ids(got), err)
		}
	}
	if err = s.SetArchived(ctx, byName.ID, viewer, new(time.Now())); err != nil {
		t.Fatal(err)
	}
	got, err := s.SearchThreads(ctx, viewer, terms(t, s, "han"), 20)
	if err != nil || len(got) != 1 || !got[0].Archived || got[0].Other != hanh || got[0].Unread != 1 {
		t.Fatalf("archived thread: %+v %v", got, err)
	}
}
```

Notes on `TestSearchThreads`:

- "HAN" matches "Ngọc Hân" because "han" is a prefix of the token "han".
- "Hân Hân" was the deleted account's name; erasure sets `display_name` to NULL, so the name matches nothing.
- "nike shop" has words from two fields (title and name) and matches nothing.
- "do cu" matches the seller's name "Shop Đồ Cũ" and the title "Giày Nike Air cũ" for the same conversation, which is listed once.
- The account update must satisfy the `accounts_deleted` check of migration 0028 (`bio` and `avatar_key` NULL as well); read the constraint and null the other columns if `accounttest.New` sets them.

Add `pairWith` to `chat_pg_test.go` beside `pair`, since this test needs one viewer in several conversations:

```go
// pairWith opens the conversation of viewer and a new account.
func pairWith(t *testing.T, db *pgxpool.Pool, s repository.Chats, viewer uuid.UUID) (domain.Conversation, uuid.UUID) {
	t.Helper()
	other := accounttest.New(t, db)
	c, err := s.OpenPair(context.Background(), domain.NewConversation(uuid.NewV7(), viewer, other, time.Now()))
	if err != nil {
		t.Fatal(err)
	}
	return c, other
}
```

The test file's imports: `context`, `slices`, `testing`, `time`, `uuid`, `github.com/jackc/pgx/v5`, `accounttest`, `catalogtest`, `catalogdomain`, chat `domain`, `repository`, `page`, `pgtest`.

Run: `go test ./internal/chat/repository/ -run 'TestTokens|TestSearch'`
Expected: build failure (`Tokens`, `Terms`, `SearchMessages`, `SearchThreads` undefined).

- [ ] **Step 3: Repository (GREEN)**

`repository.go`: add `Archived bool` to `InboxRow` (doc: "Archived is whether viewer archived it."), and to `Chats`:

```go
	// Tokens splits q with the search index's tokenizer: lowercase, accents
	// folded, split on anything but letters and digits.
	Tokens(ctx context.Context, q string) ([]string, error)
	// SearchThreads lists viewer's conversations with a sent message,
	// archived or not, without those whose other member viewer blocks,
	// where t matches the other member's name or the title of a listing a
	// message names; newest last message first, at most limit.
	SearchThreads(ctx context.Context, viewer uuid.UUID, t Terms, limit int) ([]InboxRow, error)
	// SearchMessages lists the sent messages matching t in the
	// conversations SearchThreads would consider, IDs below p.Before(),
	// newest first, at most p.Fetch().
	SearchMessages(ctx context.Context, viewer uuid.UUID, t Terms, p page.Request) ([]MessageHitRow, error)
```

and the types:

```go
// Terms is a search's tokens: each of Whole matches a whole word, Prefix
// the start of one.
type Terms struct {
	Whole  []string
	Prefix string
}

// MessageHitRow is a message a search found and the other member of its
// conversation.
type MessageHitRow struct {
	Message domain.Message
	Other   uuid.UUID
}
```

`chat_pg.go`: split the block condition out of `listed` so search reuses it, and read the archive into `InboxRow` in `Inbox`:

```go
// notBlocked holds for a conversation c of the viewer's when the viewer
// does not block its other member.
const notBlocked = `NOT EXISTS (
      SELECT 1 FROM account_blocks b
      WHERE b.blocker_id = @viewer
        AND b.blocked_id = CASE WHEN c.account_a = @viewer THEN c.account_b ELSE c.account_a END
  )`

const listed = `
cm.account_id = @viewer AND c.last_message_id IS NOT NULL
  AND @archived = (cm.archived_at IS NOT NULL)
  AND ` + notBlocked
```

In `Inbox`, set `r.Archived = archived` after the scan.

`search_pg.go`:

```go
package repository

import (
	"context"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"uuid"

	"github.com/jackc/pgx/v5"

	"github.com/shopnexus/server/internal/chat/domain"
	"github.com/shopnexus/server/internal/platform/page"
)

// tokenizer is the messages_search index's tokenizer (migration 0031);
// queries and names are split with the same one.
const tokenizer = `pdb.simple('ascii_folding=true')`

func (s pgChats) Tokens(ctx context.Context, q string) ([]string, error) {
	var out []string
	if err := s.db.QueryRow(ctx, `SELECT @q::`+tokenizer+`::text[]`, pgx.StrictNamedArgs{"q": q}).Scan(&out); err != nil {
		return nil, fmt.Errorf("split query: %w", err)
	}
	return out, nil
}

// matches holds when the tokens of the text expression hold every whole
// term and a word starting with the prefix.
func matches(expr string) string {
	toks := `(` + expr + `)::` + tokenizer + `::text[]`
	return `(` + toks + ` @> @whole AND EXISTS (SELECT 1 FROM unnest(` + toks + `) w WHERE starts_with(w, @prefix)))`
}

// searchThreads reads the matching conversations with their last message
// and unread count, as selectInbox does.
var searchThreads = `
SELECT ` + messageColumns + `, c.id, c.account_a, c.account_b, c.created_at, ` + rowUnread + `, page.archived
FROM (
    SELECT c.id, cm.last_read_message_id AS last_read, cm.marked_unread AS marked, cm.archived_at IS NOT NULL AS archived
    FROM conversation_members cm JOIN conversations c ON c.id = cm.conversation_id
    JOIN accounts o ON o.id = CASE WHEN c.account_a = @viewer THEN c.account_b ELSE c.account_a END
    WHERE cm.account_id = @viewer AND c.last_message_id IS NOT NULL AND ` + notBlocked + `
      AND (` + matches(`coalesce(o.display_name, '')`) + ` OR EXISTS (
          SELECT 1 FROM messages lm JOIN listings l ON l.id = lm.listing_id
          WHERE lm.conversation_id = c.id AND ` + matches(`l.title`) + `))
    ORDER BY c.last_message_id DESC LIMIT @limit
) page
JOIN conversations c ON c.id = page.id
JOIN messages m ON m.id = c.last_message_id` + unreadAfter + `
ORDER BY c.last_message_id DESC`

func (s pgChats) SearchThreads(ctx context.Context, viewer uuid.UUID, t Terms, limit int) ([]InboxRow, error) {
	rows, err := s.db.Query(ctx, searchThreads, pgx.StrictNamedArgs{
		"viewer": viewer, "whole": t.Whole, "prefix": t.Prefix, "limit": limit,
	})
	if err != nil {
		return nil, fmt.Errorf("search threads: %w", err)
	}
	out, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (InboxRow, error) {
		var (
			r InboxRow
			m messageScan
		)
		if scanErr := row.Scan(append(m.dest(), &r.Conversation.ID, &r.Conversation.AccountA, &r.Conversation.AccountB,
			&r.Conversation.CreatedAt, &r.Unread, &r.Archived)...); scanErr != nil {
			return InboxRow{}, fmt.Errorf("scan thread: %w", scanErr)
		}
		r.Other = r.Conversation.Other(viewer)
		last, msgErr := m.message()
		r.Last = last
		return r, msgErr
	})
	if err != nil {
		return nil, fmt.Errorf("read threads: %w", err)
	}
	return out, nil
}

func (s pgChats) SearchMessages(ctx context.Context, viewer uuid.UUID, t Terms, p page.Request) ([]MessageHitRow, error) {
	// One regex clause per token keeps the whole query inside the index:
	// a regex matches a whole term, and the prefix's ".*" expands without
	// phrase_prefix's cap of 50 terms.
	args := pgx.StrictNamedArgs{"viewer": viewer, "before": p.Before(), "limit": p.Fetch(), "prefix": regexp.QuoteMeta(t.Prefix) + ".*"}
	clauses := []string{`m.body @@@ pdb.regex(@prefix)`}
	for i, w := range t.Whole {
		name := "w" + strconv.Itoa(i)
		args[name] = regexp.QuoteMeta(w)
		clauses = append(clauses, `m.body @@@ pdb.regex(@`+name+`)`)
	}
	rows, err := s.db.Query(ctx, `SELECT `+messageColumns+` FROM messages m
WHERE `+strings.Join(clauses, " AND ")+`
  AND m.status = 'sent'
  AND m.conversation_id = ANY(ARRAY(
      SELECT c.id FROM conversation_members cm JOIN conversations c ON c.id = cm.conversation_id
      WHERE cm.account_id = @viewer AND c.last_message_id IS NOT NULL AND `+notBlocked+`))
  AND m.id < @before
ORDER BY m.id DESC LIMIT @limit`, args)
	if err != nil {
		return nil, fmt.Errorf("search messages: %w", err)
	}
	msgs, err := pgx.CollectRows(rows, scanMessage)
	if err != nil {
		return nil, fmt.Errorf("read messages: %w", err)
	}
	ids := make([]uuid.UUID, 0, len(msgs))
	for i := range msgs {
		ids = append(ids, msgs[i].ConversationID())
	}
	convs, err := s.db.Query(ctx, `SELECT id, account_a, account_b, created_at FROM conversations WHERE id = ANY(@ids)`,
		pgx.StrictNamedArgs{"ids": ids})
	if err != nil {
		return nil, fmt.Errorf("read conversations: %w", err)
	}
	pairs, err := pgx.CollectRows(convs, func(row pgx.CollectableRow) (domain.Conversation, error) {
		var c domain.Conversation
		return c, row.Scan(&c.ID, &c.AccountA, &c.AccountB, &c.CreatedAt)
	})
	if err != nil {
		return nil, fmt.Errorf("read conversations: %w", err)
	}
	byID := make(map[uuid.UUID]domain.Conversation, len(pairs))
	for _, c := range pairs {
		byID[c.ID] = c
	}
	out := make([]MessageHitRow, len(msgs))
	for i := range msgs {
		out[i] = MessageHitRow{Message: msgs[i], Other: byID[msgs[i].ConversationID()].Other(viewer)}
	}
	return out, nil
}
```

`searchThreads` is a `var` because it calls `matches`; if the linter objects (gochecknoglobals is not enabled; check `.golangci.yml`), build the string inside `SearchThreads` instead. Before writing, check that `regexp.QuoteMeta` output is valid Tantivy regex for alphanumeric tokens (it returns them unchanged), and run `EXPLAIN` once on the test database with a real viewer to confirm the plan shows `Custom Scan (ParadeDB Base Scan)` with `TopK Order By: id desc`; put the EXPLAIN output in `tmp/`, not in the repo.

Run: `go test ./internal/chat/repository/`
Expected: PASS.

- [ ] **Step 4: Service test (RED)**

`internal/chat/service/search_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/shopnexus/server/internal/catalog/catalogtest"
	"github.com/shopnexus/server/internal/chat/domain"
	"github.com/shopnexus/server/internal/platform/page"
)

func TestSearch(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	e := newEnv(t)
	seller, buyer := e.person(t), e.person(t)
	c := e.open(t, buyer, catalogtest.Listing(t, e.db, seller), "Giày còn ship nhanh không?")
	got, err := e.chat.Search(ctx, seller, "  GIÀY  ", page.Request{})
	if err != nil || len(got.Messages.Items) != 1 || got.Messages.Items[0].ConversationID != c.ID ||
		got.Messages.Items[0].Other.ID != buyer || got.Messages.Items[0].Message.Text != "Giày còn ship nhanh không?" {
		t.Fatalf("messages: %+v %v", got, err)
	}
	if got.Threads == nil {
		t.Fatal("threads is null on the first page")
	}
	later, err := e.chat.Search(ctx, seller, "giay", page.Request{Cursor: got.Messages.Items[0].Message.ID})
	if err != nil || later.Threads == nil || len(later.Threads) != 0 || len(later.Messages.Items) != 0 {
		t.Fatalf("a later page: %+v %v", later, err)
	}
}

func TestSearchRefusesAnEmptyQuery(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	for _, q := range []string{"", "   ", "!!! ,,", strings.Repeat("a", domain.MaxQuery+1)} {
		if _, err := e.chat.Search(context.Background(), e.person(t), q, page.Request{}); !errors.Is(err, domain.ErrInvalidQuery) {
			t.Errorf("%q: %v", q, err)
		}
	}
}
```

Run: `go test ./internal/chat/service/ -run TestSearch`
Expected: build failure.

- [ ] **Step 5: Service (GREEN)**

`domain/errors.go`: `ErrInvalidQuery = apperr.New(apperr.KindInvalid, "invalid_query", "a search needs 1 to 100 characters with a letter or a digit")`. `domain/chat.go`: `// MaxQuery caps an inbox search, counted after trimming.` / `const MaxQuery = 100` (place it beside the other limits).

`views.go`: add

```go
// MessageHit is a message an inbox search found, with its conversation's
// other member.
type MessageHit struct {
	ConversationID uuid.UUID   `json:"conversation_id"`
	Other          PersonView  `json:"other"`
	Message        MessageView `json:"message"`
}

// SearchResult is an inbox search: the matching conversations, on the first
// page only, and a page of matching messages.
type SearchResult struct {
	Threads  []InboxItem
	Messages page.Page[MessageHit]
}

// personView shows account a as the other member id.
func personView(id uuid.UUID, a accountsvc.AccountView) PersonView {
	return PersonView{
		ID: id, DisplayName: a.DisplayName, AvatarURL: a.AvatarURL, LastActiveAt: a.LastActiveAt,
		Deleted: a.Status == accountdomain.StatusDeleted,
	}
}
```

and use `personView` in `Inbox` and `Get` in `conversation_get.go` (replacing the two literal `PersonView{…}` blocks), and in `Inbox` set `Archived: rows[i].Archived`. Check the exact type name `GetMany` and `Get` return (`accountsvc.AccountView` or similar) and use it.

`service.go`, in `Service`:

```go
	// Search finds account's conversations by the other member's name or a
	// listing's title, on the first page only, and a page of their messages
	// by text; archived conversations are searched too.
	Search(ctx context.Context, account uuid.UUID, q string, p page.Request) (SearchResult, error)
```

`search.go`:

```go
package service

import (
	"context"
	"fmt"
	"strings"
	"unicode/utf8"
	"uuid"

	"github.com/shopnexus/server/internal/chat/domain"
	"github.com/shopnexus/server/internal/chat/repository"
	"github.com/shopnexus/server/internal/platform/page"
)

// SearchThreads caps the conversations an inbox search lists.
const SearchThreads = 20

// Search splits q with the index's tokenizer, the last word matching as a
// prefix, reads the threads on the first page and a page of messages, and
// shows each with its other member.
func (c *Chat) Search(ctx context.Context, account uuid.UUID, q string, p page.Request) (SearchResult, error) {
	q = strings.TrimSpace(q)
	if n := utf8.RuneCountInString(q); n == 0 || n > domain.MaxQuery {
		return SearchResult{}, domain.ErrInvalidQuery
	}
	toks, err := c.chats.Tokens(ctx, q)
	if err != nil {
		return SearchResult{}, fmt.Errorf("split query: %w", err)
	}
	if len(toks) == 0 {
		return SearchResult{}, domain.ErrInvalidQuery
	}
	t := repository.Terms{Whole: toks[:len(toks)-1], Prefix: toks[len(toks)-1]}
	var threads []repository.InboxRow
	if p.Cursor == (uuid.UUID{}) {
		if threads, err = c.chats.SearchThreads(ctx, account, t, SearchThreads); err != nil {
			return SearchResult{}, fmt.Errorf("search threads: %w", err)
		}
	}
	hits, err := c.chats.SearchMessages(ctx, account, t, p)
	if err != nil {
		return SearchResult{}, fmt.Errorf("search messages: %w", err)
	}
	ids := make([]uuid.UUID, 0, len(threads)+len(hits))
	for i := range threads {
		ids = append(ids, threads[i].Other)
	}
	for i := range hits {
		ids = append(ids, hits[i].Other)
	}
	others, err := c.accounts.GetMany(ctx, ids)
	if err != nil {
		return SearchResult{}, fmt.Errorf("read the other members: %w", err)
	}
	items := make([]InboxItem, 0, len(threads))
	for i := range threads {
		r := &threads[i]
		items = append(items, InboxItem{
			ID: r.Conversation.ID, Other: personView(r.Other, others[r.Other]), LastMessage: c.messageView(r.Last),
			Unread: r.Unread, Archived: r.Archived,
		})
	}
	found := make([]MessageHit, 0, len(hits))
	for i := range hits {
		h := &hits[i]
		found = append(found, MessageHit{
			ConversationID: h.Message.ConversationID(), Other: personView(h.Other, others[h.Other]), Message: c.messageView(h.Message),
		})
	}
	return SearchResult{
		Threads: items, Messages: page.Of(found, p, func(h MessageHit) uuid.UUID { return h.Message.ID }),
	}, nil
}
```

Add `Search` to any fake implementing `chatsvc.Service` in tests.

Run: `go build ./... && go test ./internal/chat/...`
Expected: PASS.

- [ ] **Step 6: Lint and commit**

Run: `golangci-lint run ./... > tmp/lint.txt 2>&1; tail -20 tmp/lint.txt`
Expected: no issues.

```bash
git add migrations/0031_messages_search.sql internal/chat
git commit -m "feat(chat): search the inbox by name, listing title and message text"
```

---

### Task 5: The inbox search view

**Files:**
- Create: `internal/screen/service/inbox_search.go`
- Modify: `internal/screen/service/service.go`, `internal/screen/handler/inbox.go`, `internal/screen/handler/handler.go`
- Modify: `api/paths/screen_inbox.yaml`, `api/schemas/screen_inbox.yaml`, `api/schemas/chat.yaml` (only if `MessageHit` lives there; this plan puts it in `screen_inbox.yaml`), `api/openapi.yaml`
- Test: `e2e/screen_inbox_test.go`

**Interfaces:**
- Consumes: `chatsvc.Service.Search` → `chatsvc.SearchResult{Threads []chatsvc.InboxItem; Messages page.Page[chatsvc.MessageHit]}`; `dealsvc.Service.PairSummaries(ctx, account, others []uuid.UUID)` (as `Inbox` uses it); `chatdomain.ErrInvalidQuery`.
- Produces: `service.Service.InboxSearch(ctx, account uuid.UUID, q string, p page.Request) (InboxSearchScreen, error)`; route `GET /v1/screens/inbox/search`.

- [ ] **Step 1: e2e (RED)**

In `e2e/screen_inbox_test.go`:

```go
type inboxSearch struct {
	Threads  []inboxRow `json:"threads"`
	Messages []struct {
		ConversationID string `json:"conversation_id"`
		Other          struct {
			ID string `json:"id"`
		} `json:"other"`
		Message messageBody `json:"message"`
	} `json:"messages"`
	NextCursor string `json:"next_cursor"`
}

func TestInboxSearch(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	l := activeListing(t, seller.AccessToken, nil)
	c := openChat(t, buyer.AccessToken, l.ID, "Giày còn SHIP nhanh không bạn?")
	openDeal(t, buyer.AccessToken, l.ID, http.StatusCreated)
	sendChat(t, seller.AccessToken, c.ID, map[string]any{"text": "Ship được nhé"})
	search := func(token, query string) Response {
		t.Helper()
		return call(t, "GET", "/v1/screens/inbox/search?"+query, nil, bearer(token))
	}

	first := expect[inboxSearch](t, search(seller.AccessToken, "q=ship&limit=1"), http.StatusOK)
	if len(first.Messages) != 1 || first.Messages[0].Message.Text != "Ship được nhé" || first.Messages[0].ConversationID != c.ID ||
		first.Messages[0].Other.ID != buyer.Account.ID || first.NextCursor == "" {
		t.Fatalf("first page: %+v", first)
	}
	rest := expect[inboxSearch](t, search(seller.AccessToken, "q=ship&limit=1&cursor="+first.NextCursor), http.StatusOK)
	if len(rest.Messages) != 1 || rest.Messages[0].Message.Text != "Giày còn SHIP nhanh không bạn?" || rest.NextCursor != "" ||
		rest.Threads == nil || len(rest.Threads) != 0 {
		t.Fatalf("second page: %+v", rest)
	}
	// The listing's title names the thread; it comes with the pair's deal.
	title := strings.Fields(l.Title)[0]
	byTitle := expect[inboxSearch](t, search(buyer.AccessToken, "q="+url.QueryEscape(title)), http.StatusOK)
	if len(byTitle.Threads) != 1 || byTitle.Threads[0].ID != c.ID || byTitle.Threads[0].Deal == nil {
		t.Fatalf("by title %q: %+v", title, byTitle)
	}

	check(t, "signed out", call(t, "GET", "/v1/screens/inbox/search?q=ship", nil), 401, "unauthenticated")
	check(t, "no query", search(seller.AccessToken, ""), 400, "")
	check(t, "a bad cursor", search(seller.AccessToken, "q=ship&cursor=x"), 400, "")
	check(t, "only punctuation", search(seller.AccessToken, "q="+url.QueryEscape("!!!")), 422, "invalid_query")
}
```

(Check the field holding the listing title in the e2e listing type returned by `activeListing`; add `Title` to it if absent. Add `"net/url"` and `"strings"` imports.)

Run: `go test ./e2e/ -run TestInboxSearch > tmp/e2e-search.txt 2>&1; tail -20 tmp/e2e-search.txt`
Expected: FAIL (404 / route missing; `TestRoutesMatchSpec` unaffected yet).

- [ ] **Step 2: Screen service and handler (GREEN)**

`internal/screen/service/inbox_search.go`:

```go
package service

import (
	"context"
	"fmt"
	"uuid"

	chatsvc "github.com/shopnexus/server/internal/chat/service"
	"github.com/shopnexus/server/internal/platform/page"
)

// InboxSearchScreen is the InboxSearch schema in
// api/schemas/screen_inbox.yaml.
type InboxSearchScreen struct {
	Threads    []InboxItem          `json:"threads"`
	Messages   []chatsvc.MessageHit `json:"messages"`
	NextCursor *uuid.UUID           `json:"next_cursor,omitempty"`
}

// InboxSearch reads chat's search and the deals of the threads' pairs.
func (s *Screen) InboxSearch(ctx context.Context, account uuid.UUID, q string, p page.Request) (InboxSearchScreen, error) {
	found, err := s.chats.Search(ctx, account, q, p)
	if err != nil {
		return InboxSearchScreen{}, fmt.Errorf("search the inbox: %w", err)
	}
	others := make([]uuid.UUID, 0, len(found.Threads))
	for i := range found.Threads {
		others = append(others, found.Threads[i].Other.ID)
	}
	deals, err := s.deals.PairSummaries(ctx, account, others)
	if err != nil {
		return InboxSearchScreen{}, fmt.Errorf("read deals: %w", err)
	}
	threads := make([]InboxItem, 0, len(found.Threads))
	for i := range found.Threads {
		item := InboxItem{InboxItem: found.Threads[i]}
		if d, ok := deals[item.Other.ID]; ok {
			item.Deal, item.OtherActiveDeals = &d.Deal, d.OtherActive
		}
		threads = append(threads, item)
	}
	return InboxSearchScreen{Threads: threads, Messages: found.Messages.Items, NextCursor: found.Messages.NextCursor}, nil
}
```

`fmt.Errorf("…: %w", err)` keeps `ErrInvalidQuery` matchable by `httpx.WriteError` (it uses `errors.As`; confirm by reading `httpx.WriteError`). `service.go`: add to `Service`:

```go
	// InboxSearch reads the inbox search view: the conversations matching q
	// with their pairs' deals, on the first page only, and a page of
	// matching messages.
	InboxSearch(ctx context.Context, account uuid.UUID, q string, p page.Request) (InboxSearchScreen, error)
```

`handler/inbox.go`:

```go
type inboxSearchRequest struct {
	page.Request

	Q string `json:"-" query:"q"`
}

// InboxSearch serves GET /v1/screens/inbox/search.
func (h *Handler) InboxSearch(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in inboxSearchRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	out, err := h.svc.InboxSearch(r.Context(), p.AccountID, in.Q, in.Request)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, out)
}
```

`handler.go`: `r.Handle("GET /v1/screens/inbox/search", protect(http.HandlerFunc(h.InboxSearch)))` after the inbox route.

- [ ] **Step 3: API**

`api/paths/screen_inbox.yaml`:

```yaml
screenInboxSearch:
  get:
    operationId: searchInbox
    summary: Search the caller's conversations and messages.
    description: |
      q is split into words, lowercase with accents folded (đ as d); every
      word but the last matches a whole word, the last the start of one.
      threads are the conversations whose other member's name, or the title
      of a listing a message names, holds every word: up to 20, newest
      message first, on the first page only (an empty array on later
      pages). messages are the sent messages whose text holds every word,
      newest first; cursor and next_cursor page them. Archived
      conversations are searched; conversations with someone the caller
      blocks are not.
    tags: [screen]
    security:
      - bearerAuth: []
    parameters:
      - name: q
        in: query
        required: true
        schema:
          type: string
      - $ref: "../parameters/common.yaml#/Cursor"
      - $ref: "../parameters/common.yaml#/Limit"
    responses:
      "200":
        description: The matches.
        content:
          application/json:
            schema:
              $ref: "../schemas/screen_inbox.yaml#/InboxSearch"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "422":
        description: "q holds no letter or digit, or more than 100 characters after trimming (invalid_query)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

`api/schemas/screen_inbox.yaml`:

```yaml
InboxSearch:
  type: object
  additionalProperties: false
  required: [threads, messages]
  properties:
    threads:
      type: array
      items:
        $ref: "#/InboxItem"
    messages:
      type: array
      items:
        $ref: "#/MessageHit"
    next_cursor:
      type: string
      format: uuid
      description: Present when more messages follow; pass it as cursor.
MessageHit:
  type: object
  additionalProperties: false
  required: [conversation_id, other, message]
  properties:
    conversation_id:
      type: string
      format: uuid
    other:
      $ref: "chat.yaml#/Person"
    message:
      $ref: "chat.yaml#/Message"
```

`api/openapi.yaml`, after `/v1/screens/inbox`:

```yaml
  /v1/screens/inbox/search:
    $ref: "paths/screen_inbox.yaml#/screenInboxSearch"
```

Run: `go test ./internal/app/ -run TestRoutesMatchSpec && go test ./e2e/ -run 'TestInbox' > tmp/e2e-search.txt 2>&1; tail -20 tmp/e2e-search.txt`
Expected: PASS.

- [ ] **Step 4: Lint and commit**

Run: `golangci-lint run ./... > tmp/lint.txt 2>&1; tail -20 tmp/lint.txt`
Expected: no issues.

```bash
git add internal/screen api e2e/screen_inbox_test.go
git commit -m "feat(screen): the inbox search view"
```

---

### Task 6: Architecture, checklist, full suite

**Files:**
- Modify: `ARCHITECTURE.md` (Chat, Trust, Notifications, Search sections)
- Modify: `~/shopnexus/checklist.md` (superproject, not committed unless the user asks)

- [ ] **Step 1: ARCHITECTURE.md**

Add, under the matching sections (decided 2026-11-10, spec `~/shopnexus/docs/superpowers/specs/2026-11-10-server-inbox-search-unread-design.md`):

- Chat: a member's `marked_unread` flag (`POST /v1/conversations/{id}/unread`) counts the conversation as at least 1 unread message in the inbox row and `/v1/me/unread` until the next read; the read marker and the other side's "Đã xem" stay. A read clears the flag in the same update (`RETURNING old/new`). Setting or clearing it notifies the member's own stream with kind `read`; a marker move notifies the other member as before.
- Chat: inbox search (`GET /v1/screens/inbox/search`) splits `q` with `pdb.simple('ascii_folding=true')`; each word but the last matches whole and the last as a prefix. Threads match the other member's name or a listing title a message names, in SQL over the viewer's conversations without an index (at most 20, first page only). Messages use the BM25 index `messages_search` (migration 0031), one `pdb.regex` clause per word because `&&&` with an empty string matches nothing and `pdb.phrase_prefix` caps its expansion at 50 terms; status, conversation filter, cursor and `ORDER BY id DESC` all run inside the index (TopK). Archived conversations are searched, blocked ones are not.
- Trust: `POST /v1/reports` takes `conversation_id` beside `account_id`; it must be the reporter's conversation with that account (`chatsvc.ConversationWith`), and a block does not change that. Stored in `reports.conversation_id`; reporting again replaces or clears it. Trust now takes chat's service, so `app.go` mounts chat before trust.
- Notifications: `read-all` returns `{ids}`; `POST /v1/notifications/unread {ids}` (1 to 500) makes read notices unread, the newest per collapse key and none for a key with an unread notice; a unique violation from a concurrent notice reruns the statement once.
- Search section: a line that a second BM25 index, `messages_search`, belongs to chat.

Run: `python3 ~/.claude/skills/humanizing-writing/ai-tells.py ARCHITECTURE.md` and fix hits on the new lines.

- [ ] **Step 2: Full suite**

Run: `make test > tmp/make-test.txt 2>&1; tail -40 tmp/make-test.txt`
Expected: every package ok, the e2e status coverage passes, golangci-lint reports 0 issues. If the Restate test container's tmpfs is full ("No space left on device"), `make test` recreates the stack; run it again.

- [ ] **Step 3: Commit**

```bash
git add ARCHITECTURE.md
git commit -m "docs: inbox search, unread marks and reports from a conversation in the architecture"
```

- [ ] **Step 4: Checklist**

In `~/shopnexus/checklist.md`, section 1 "Chat & giao dịch", mark done with the endpoints and "(app chưa nối)":
- "Tìm trong hộp thư" → `GET /v1/screens/inbox/search?q=` (tên người, tên tin đăng, nội dung tin nhắn; bỏ dấu; từ cuối khớp tiền tố)
- "Chặn + báo cáo từ cuộc trò chuyện" → `POST /v1/blocks` rồi `POST /v1/reports {account_id, reason, conversation_id}`; hoàn tác bằng hai lệnh `DELETE`
- "Đánh dấu chưa đọc (chat và thông báo)" → `POST /v1/conversations/{id}/unread`; `POST /v1/notifications/unread {ids}`, `read-all` trả `{ids}` để hoàn tác

Run the humanizing-writing checker on the changed lines. Do not commit the superproject.
