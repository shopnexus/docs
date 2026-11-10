# Scam warning in chat: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The server tells a member of a conversation when the other member's messages look like a scam, as fixed signal codes with Vietnamese text, and lets the member dismiss the warning; the detector is an interface so a trained model can replace the LLM later.

**Architecture:** Module `trust` gains a `worker` that hears `message.sent` and sends the Virtual Object `ScamCheck.Run`, keyed by conversation. `Run` reads the last 20 messages with text through chat's new `Window`, redacts them, asks a `Classifier` (today `LLMClassifier` over `provider/llm`), adds fact signals from `FactSource`s (account age, price against the market through catalog's new `MarketPrice`), and saves a `scam_checks` row and the `scam_warnings` rows in one transaction with a `scam_warning` stream update. Screen adds `scam_warning` to the inbox and chat views; `POST /v1/conversations/{id}/scam-warning/dismiss` dismisses it.

**Tech Stack:** Go (module `github.com/shopnexus/server2`, stdlib `uuid`), Restate Go SDK, pgx v5, Postgres 18, LiteLLM (Helm chart in the umbrella repo).

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-11-server2-scam-warning-design.md`

## Global Constraints

- Repos: `~/shopnexus/server` (tasks 1–8, 10), the umbrella `~/shopnexus` (tasks 5 and 9: `docker-compose.yml`, `Makefile`, `infra/`, `checklist.md`), `~/shopnexus/docs` (spec amendments, already done). Work on branch `feat/scam-warning` in `server` and in the umbrella, cut from `main`. `server` may be on `feat/watches-alerts-hidden` with uncommitted work when you start: do not touch that work; `git stash` nothing; ask the user if `main` cannot be checked out cleanly.
- Read `server/CLAUDE.md` and `server/ARCHITECTURE.md` (sections Durable flows, Events, Module layout, Stream, Chat, Screen, Trust, Assist) before the first server task.
- A use case, a Restate handler or an HTTP handler reads top to bottom; no helper called from one place. A helper is fine when several places call it.
- Configuration has no defaults anywhere: `TRUST_LLM_BASE_URL`, `TRUST_LLM_API_KEY`, `TRUST_LLM_MODEL`, `TRUST_CALL_TIMEOUT` are all required. In the cluster: alias `scam-check`, key `server-trust`.
- Migration: `migrations/0036_scam_warnings.sql`. `0035_watches_alerts_hidden.sql` belongs to the search watches branch. If `0036` is taken when you start, take the next free number and say so in the commit.
- Message text never crosses a `restate.Run` boundary and is never logged. Steps return IDs and codes only.
- Values copied from the spec: window 20 messages with text; at most 50 checks per conversation per 24 hours; classify step `restate.WithMaxRetryDuration(10 * time.Minute)` and `restate.WithMaxRetryAttempts(3)`; `new_account` under 7 days, `days` whole and at least 1; `price_far_below` at least 30% under the median of at least 5 samples, `percent` rounded down; `scam_checks` kept 365 days, at most 1,000 deleted per check; `PromptVersion` 1.
- Codes and texts, exactly:
  - `prepayment_request` "Đòi chuyển tiền hoặc đặt cọc trước"
  - `off_app_contact` "Rủ chuyển sang Zalo, Telegram, Facebook"
  - `suspicious_link` "Gửi link lạ, giả trang thanh toán hoặc giao hàng"
  - `sensitive_info_request` "Xin mã OTP, mật khẩu hoặc thông tin thẻ"
  - `impersonation` "Mạo danh ShopNexus, ngân hàng hoặc hãng vận chuyển"
  - `fake_payment_proof` "Gửi biên lai giả hoặc bảo \"chuyển dư, hoàn lại giúp\""
  - `pressure` "Hối thúc, ép quyết định ngay"
  - `new_account` "Tài khoản mới tạo {days} ngày"
  - `price_far_below` "Giá thấp hơn {percent}% so với tin tương tự"
- Commits: conventional prefix as in `git log` (`feat(trust): …`, `feat(chat): …`, `feat(catalog): …`, `build: …` in the umbrella), no `Co-Authored-By` trailer. Commit messages, code comments, `ARCHITECTURE.md` and `checklist.md` go through the `humanizing-writing` skill's checker: `python3 ~/.claude/skills/humanizing-writing/ai-tells.py FILE` (write a commit message to `tmp/commit.txt` first and use `git commit -F tmp/commit.txt`).
- Test commands (server): `make test` once (starts the test stack, runs lint), then `go test ./internal/<module>/...` and `go test ./e2e/ -run <Name>`. Long output goes to `tmp/`, never `/tmp`. After adding a package under `internal/`, run `make depguard`.

## Review Focus

1. A Vietnamese amount of money ("1.200.000đ", "12000000đ", "500k", "12 000 000 đ") must stay readable to the model, while a phone written with spaces or dots ("0912 345 678", "+84 912.345.678") and a bank number ("1903 6688 2211 01") are replaced. Task 1 `TestRedact`.
2. A dismissal that lands between a check's read and its save must not be lost, and neither may the new signal: the save fails on `write_id`, Restate retries the step, the retry reads the dismissed row and merges into it. Task 4 `TestScamWarningsConflict`, Task 7 `TestScamCheckKeepsADismissal`.
3. A member who blocked the other must still be able to dismiss (Chat hides the banner while blocking, but the inbox sheet still shows "Vẫn mở cuộc trò chuyện"). Task 6 `TestDismissScamWarning` blocks first.
4. When the suspect deletes their account, the victim keeps the warning; only the deleted account's own warnings go. Task 4 `TestScamWarningsDeleteAccount`.
5. A message sent while a check is running must get its own check, and the running check must not read it: classify reads up to the planned last message. Task 7 `TestScamCheckRunsAgainForANewMessage`.

## File map

server (`~/shopnexus/server`):

| File | Responsibility | Task |
|---|---|---|
| `internal/trust/domain/scam.go`, `scam_test.go` | codes, texts, signals, `Redact`, `Warning`, `Check`, `Verdict`, `Window` | 1 |
| `internal/chat/repository/repository.go`, `chat_pg.go`, `chat_pg_test.go` | `Window` query | 2 |
| `internal/chat/service/service.go`, `views.go`, `window.go`, `window_test.go` | `Service.Window` | 2 |
| `internal/catalog/domain/price.go`, `price_test.go` | `MedianPrice` | 3 |
| `internal/catalog/service/service.go`, `views.go`, `market_price.go`, `market_price_test.go` | `Service.MarketPrice` | 3 |
| `migrations/0036_scam_warnings.sql` | the two tables | 4 |
| `internal/platform/stream/stream.go` | `KindScamWarning` | 4 |
| `internal/trust/repository/scam.go`, `scam_pg.go`, `scam_pg_test.go` | `ScamWarnings` | 4 |
| `internal/platform/config/config.go`, `config_test.go`, `.env.example` | `TRUST_*` | 5 |
| `internal/trust/service/scam_llm.go`, `scam_llm_test.go` | `LLMClassifier`, prompt, schema | 5 |
| `internal/trust/service/scam.go`, `scam_facts.go`, `scam_warning.go`, `scam_test.go`, `service.go`, `views.go`, `helpers_test.go` | interfaces, fact sources, read, dismiss, erase | 6 |
| `internal/trust/service/scam_check_durable.go`, `scam_check_test.go` | `ScamCheck` Virtual Object | 7 |
| `internal/trust/worker/scam.go`, `scam_test.go` | `ScamWorker` | 7 |
| `internal/trust/trust.go`, `internal/app/app.go`, `.golangci.yml` | mount and wiring | 7 |
| `api/schemas/trust.yaml`, `api/schemas/screen_inbox.yaml`, `api/schemas/stream.yaml`, `api/paths/trust.yaml`, `api/openapi.yaml` | the contract | 8 |
| `internal/trust/handler/handler.go`, `scam.go` | the dismiss route | 8 |
| `internal/screen/service/inbox.go`, `inbox_search.go`, `chat.go` | `scam_warning` in the views | 8 |
| `e2e/scam_stub_test.go`, `e2e/scam_test.go`, `e2e/main_test.go`, `e2e/screen_inbox_test.go` | end to end | 8 |
| `ARCHITECTURE.md` | the decisions | 10 |

umbrella (`~/shopnexus`):

| File | Responsibility | Task |
|---|---|---|
| `docker-compose.yml`, `Makefile` | `TRUST_*` for dev and prod compose | 5 |
| `infra/stack/values.yaml`, `values-dev.yaml`, `values-prod.yaml`, `templates/_server-env.tpl`, `tests/litellm_test.yaml`, `tests/server_env_test.yaml`, `cmd/seal/main.go`, `cmd/seal/main_test.go`, `secrets/example.env`, `smoke-models.hurl`, `smoke-models.sh`, `check.sh` | alias `scam-check`, key `server-trust`, server env | 9 |
| `checklist.md` | the item ticked | 10 |

## Task order and interfaces

1, 2 and 3 are independent. 4 needs 1. 5 needs 1. 6 needs 2, 3 and 4. 7 needs 5 and 6. 8 needs 7. 9 needs 5. 10 comes last.

Names fixed across tasks:

- `trust/domain`: `Code`, the nine `Code*` constants, `MessageCodes []Code`, `(Code) FromMessages() bool`, `WindowSize = 20`, `ChecksPerDay = 50`, `CheckRetention = 365 * 24 * time.Hour`, `NewAccountAge = 7 * 24 * time.Hour`, `PriceGapMin = 30`, `PriceSampleMin = 5`, `Signal{Code, Params map[string]int, FirstSeenAt time.Time}` with `Text() string`, `NewAccountSignal(created, now time.Time) (Signal, bool)`, `PriceBelowSignal(price, median int64, size int) (Signal, bool)`, `Side` (`SideA = "a"`, `SideB = "b"`), `Line{MessageID uuid.UUID; Side Side; Text string; ListingID *uuid.UUID}`, `Window{Lines []Line}`, `Verdict{A, B []Code}` (JSON `a`, `b`) with `Clean() (Verdict, int)`, `Redact(string) string`, `Warning` with `NewWarning(conversation, account, suspect uuid.UUID) Warning`, `RestoreWarning(WarningState) Warning`, `State()`, `Saved(writeID)`, getters `ConversationID() AccountID() SuspectID() Signals() DismissedAt() UpdatedAt() WriteID()`, `Raise(messages []Code, facts []Signal, at time.Time) bool`, `Dismiss(at time.Time) bool`, `Dismissed() bool`; `Check{ID, ConversationID, FirstMessageID, LastMessageID uuid.UUID; Classifier string; PromptVersion int; A, B []Code; CreatedAt time.Time}`.
- `chatsvc`: `Window{AccountA, AccountB uuid.UUID; Lines []WindowLine}`, `WindowLine{ID, SenderID uuid.UUID; Text string; ListingID *uuid.UUID}`, `Service.Window(ctx, conversation, upTo uuid.UUID, n int) (Window, bool, error)`; repository `Chats.Window(ctx, conversation, upTo uuid.UUID, n int) ([]domain.Message, error)`.
- `catalogsvc`: `MarketPrice{SellerID uuid.UUID; Price, Median int64; SampleSize int}`, `Service.MarketPrice(ctx, listing uuid.UUID, textMin, photoMin float64) (MarketPrice, bool, error)`; `catalogdomain.MedianPrice([]PriceSample) int64`.
- `stream.KindScamWarning = "scam_warning"`.
- trust repository: `ScamWarnings` with `Get`, `Of`, `Record`, `Save`, `Checked`, `DeleteAccount`; `WarningWrite{Warning *domain.Warning; WriteID uuid.UUID}`; `NewScamWarnings(*pgxpool.Pool) ScamWarnings`.
- trust service: `Classifier`, `FactSource`, `ErrRefused`, `LLMClassifier{Model llm.Client; Alias string; Timeout time.Duration; Log *slog.Logger}`, `ScamPromptVersion = 1`, `AccountAge{Accounts}`, `MarketGap{Catalog; TextMin, PhotoMin}`, `ScamWarningView{Signals []ScamSignalView; Dismissed bool}`, `ScamSignalView{Code, Text string}`, `Service.ScamWarnings`, `Service.DismissScamWarning`, `Service.DeleteScamWarnings`, `(*Trust).Durable()`, `ScamCheckName = "ScamCheck"`, `ScamCheck{...}.Run(restate.ObjectContext) error`.
- trust worker: `ScamWorker{Prefix string; Chats chatsvc.Service; Trust service.Service}`, service name `<prefix>TrustScamWorker`, handlers `MessageSent`, `AccountDeleted`.
- root `trust`: `Settings{Classifier service.Classifier; TextMin, PhotoMin float64}`, `LLMClassifier(model llm.Client, alias string, timeout time.Duration, log *slog.Logger) service.Classifier`, `Mount(...) module.Mounted[service.Service]`.
- config: `TrustConfig{LLMBaseURL, LLMAPIKey, LLMModel string; CallTimeout time.Duration}` at `Config.Trust`.

---

### Task 1: Trust domain: codes, signals, redaction, the warning

**Files:**
- Create: `internal/trust/domain/scam.go`
- Test: `internal/trust/domain/scam_test.go`

**Interfaces:**
- Consumes: nothing new.
- Produces: everything listed under `trust/domain` above.

- [ ] **Step 1: Branch**

```bash
cd ~/shopnexus/server && git status --short && git switch main && git pull --ff-only && git switch -c feat/scam-warning
```

If `git switch main` refuses because of uncommitted work on another branch, stop and ask the user.

- [ ] **Step 2: Write the failing tests**

`internal/trust/domain/scam_test.go`:

```go
package domain_test

import (
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/trust/domain"
)

func TestRedact(t *testing.T) {
	t.Parallel()
	for in, want := range map[string]string{
		"Gọi mình 0912 345 678 nhé":                       "Gọi mình <PHONE> nhé",
		"sdt +84 912.345.678":                             "sdt <PHONE>",
		"zalo 0912345678":                                 "zalo <PHONE>",
		"STK 1903 6688 2211 01 Techcombank":               "STK <BANK_NUMBER> Techcombank",
		"thẻ 4111-1111-1111-1111":                         "thẻ <BANK_NUMBER>",
		"mail mình là an.nguyen@gmail.com":                "mail mình là <EMAIL>",
		"vào https://www.ghn-check.top/pay?id=9 để nhận":  "vào <URL:ghn-check.top> để nhận",
		"link bit.ly/3xYz nhé":                            "link <URL:bit.ly> nhé",
		"Giá 1.200.000đ, cọc 500k":                        "Giá 1.200.000đ, cọc 500k",
		"chốt 12000000đ":                                  "chốt 12000000đ",
		"chốt 12 000 000 đ":                               "chốt 12 000 000 đ",
		"Xe còn không bạn?":                               "Xe còn không bạn?",
	} {
		if got := domain.Redact(in); got != want {
			t.Errorf("Redact(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestSignalText(t *testing.T) {
	t.Parallel()
	for _, c := range []struct {
		s    domain.Signal
		want string
	}{
		{domain.Signal{Code: domain.CodePrepayment}, "Đòi chuyển tiền hoặc đặt cọc trước"},
		{domain.Signal{Code: domain.CodeFakeProof}, `Gửi biên lai giả hoặc bảo "chuyển dư, hoàn lại giúp"`},
		{domain.Signal{Code: domain.CodeNewAccount, Params: map[string]int{"days": 2}}, "Tài khoản mới tạo 2 ngày"},
		{domain.Signal{Code: domain.CodePriceBelow, Params: map[string]int{"percent": 40}}, "Giá thấp hơn 40% so với tin tương tự"},
		{domain.Signal{Code: "unknown"}, ""},
	} {
		if got := c.s.Text(); got != c.want {
			t.Errorf("%s: %q, want %q", c.s.Code, got, c.want)
		}
	}
	for _, code := range domain.MessageCodes {
		if (domain.Signal{Code: code}).Text() == "" || !code.FromMessages() {
			t.Errorf("message code %s has no text or is not a message code", code)
		}
	}
	if domain.CodeNewAccount.FromMessages() || domain.CodePriceBelow.FromMessages() {
		t.Error("a fact code counts as a message code")
	}
}

func TestFactSignals(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, 11, 11, 12, 0, 0, 0, time.UTC)
	if s, ok := domain.NewAccountSignal(now.Add(-3*time.Hour), now); !ok || s.Params["days"] != 1 {
		t.Fatalf("3 hours: %+v %v", s, ok)
	}
	if s, ok := domain.NewAccountSignal(now.Add(-50*time.Hour), now); !ok || s.Params["days"] != 2 {
		t.Fatalf("50 hours: %+v %v", s, ok)
	}
	if _, ok := domain.NewAccountSignal(now.Add(-7*24*time.Hour), now); ok {
		t.Fatal("7 days is not new")
	}
	if s, ok := domain.PriceBelowSignal(6_000_000, 10_000_000, 5); !ok || s.Params["percent"] != 40 {
		t.Fatalf("40%%: %+v %v", s, ok)
	}
	if s, ok := domain.PriceBelowSignal(6_999_999, 10_000_000, 5); !ok || s.Params["percent"] != 30 {
		t.Fatalf("30%% rounded down: %+v %v", s, ok)
	}
	for name, c := range map[string]struct {
		price, median int64
		size          int
	}{
		"29%":          {7_100_000, 10_000_000, 5},
		"4 samples":    {1_000_000, 10_000_000, 4},
		"no median":    {1_000_000, 0, 5},
		"above median": {12_000_000, 10_000_000, 9},
	} {
		if _, ok := domain.PriceBelowSignal(c.price, c.median, c.size); ok {
			t.Errorf("%s holds", name)
		}
	}
}

func TestVerdictClean(t *testing.T) {
	t.Parallel()
	v, dropped := domain.Verdict{
		A: []domain.Code{domain.CodePrepayment, "bribery", domain.CodePrepayment, domain.CodeNewAccount},
		B: nil,
	}.Clean()
	if dropped != 3 || len(v.A) != 1 || v.A[0] != domain.CodePrepayment || v.B == nil || len(v.B) != 0 {
		t.Fatalf("%+v %d", v, dropped)
	}
}

func TestWarning(t *testing.T) {
	t.Parallel()
	conversation, victim, suspect := uuid.NewV7(), uuid.NewV7(), uuid.NewV7()
	t0 := time.Date(2026, 11, 11, 12, 0, 0, 0, time.UTC)
	newAccount, _ := domain.NewAccountSignal(t0.Add(-time.Hour), t0)
	w := domain.NewWarning(conversation, victim, suspect)

	// Facts alone raise nothing.
	if w.Raise(nil, []domain.Signal{newAccount}, t0) || len(w.Signals()) != 0 {
		t.Fatalf("facts alone: %+v", w.Signals())
	}
	// A message code raises the warning and attaches the fact.
	if !w.Raise([]domain.Code{domain.CodeOffApp, domain.CodePrepayment}, []domain.Signal{newAccount}, t0) {
		t.Fatal("first raise changed nothing")
	}
	got := w.Signals()
	if len(got) != 3 || got[0].Code != domain.CodePrepayment || got[1].Code != domain.CodeOffApp ||
		got[2].Code != domain.CodeNewAccount || !got[2].FirstSeenAt.Equal(t0) || w.Dismissed() {
		t.Fatalf("after the first raise: %+v", got)
	}
	// The same codes again change nothing; codes are never removed.
	if w.Raise([]domain.Code{domain.CodePrepayment}, nil, t0.Add(time.Minute)) || len(w.Signals()) != 3 {
		t.Fatalf("again: %+v", w.Signals())
	}
	// Dismissing once works, twice changes nothing.
	if !w.Dismiss(t0.Add(2*time.Minute)) || !w.Dismissed() || w.Dismiss(t0.Add(3*time.Minute)) {
		t.Fatal("dismiss")
	}
	// A new fact code does not undo the dismissal.
	price, _ := domain.PriceBelowSignal(5_000_000, 10_000_000, 6)
	if !w.Raise([]domain.Code{domain.CodePrepayment}, []domain.Signal{price}, t0.Add(4*time.Minute)) || !w.Dismissed() {
		t.Fatalf("a new fact: dismissed %v, %+v", w.Dismissed(), w.Signals())
	}
	// A new message code does.
	if !w.Raise([]domain.Code{domain.CodeSensitive}, nil, t0.Add(5*time.Minute)) || w.Dismissed() {
		t.Fatalf("a new message code: dismissed %v", w.Dismissed())
	}
	last := w.Signals()[len(w.Signals())-1]
	if last.Code != domain.CodeSensitive || !last.FirstSeenAt.Equal(t0.Add(5*time.Minute)) || !w.UpdatedAt().Equal(last.FirstSeenAt) {
		t.Fatalf("last: %+v, updated %v", last, w.UpdatedAt())
	}
	// State and Restore round-trip.
	back := domain.RestoreWarning(w.State())
	if len(back.Signals()) != len(w.Signals()) || back.Dismissed() != w.Dismissed() || back.SuspectID() != suspect {
		t.Fatalf("restore: %+v", back.State())
	}
	// An empty warning cannot be dismissed.
	empty := domain.NewWarning(conversation, suspect, victim)
	if empty.Dismiss(t0) {
		t.Fatal("dismissed an empty warning")
	}
}
```

- [ ] **Step 3: Run the tests to see them fail**

Run: `go test ./internal/trust/domain/ -run 'TestRedact|TestSignalText|TestFactSignals|TestVerdictClean|TestWarning'`
Expected: build failure, `undefined: domain.Redact` and the other new names.

- [ ] **Step 4: Write `internal/trust/domain/scam.go`**

```go
package domain

import (
	"fmt"
	"regexp"
	"slices"
	"strings"
	"time"
	"uuid"
)

// Code names one sign of a scam. A classifier reads the message codes from
// the messages; a fact code is computed from data and joins a warning only
// beside a message code.
type Code string

const (
	CodePrepayment    Code = "prepayment_request"
	CodeOffApp        Code = "off_app_contact"
	CodeLink          Code = "suspicious_link"
	CodeSensitive     Code = "sensitive_info_request"
	CodeImpersonation Code = "impersonation"
	CodeFakeProof     Code = "fake_payment_proof"
	CodePressure      Code = "pressure"
	CodeNewAccount    Code = "new_account"
	CodePriceBelow    Code = "price_far_below"
)

// MessageCodes are the codes a classifier may answer, in the order a
// warning lists the ones found at the same check.
var MessageCodes = []Code{
	CodePrepayment, CodeOffApp, CodeLink, CodeSensitive, CodeImpersonation, CodeFakeProof, CodePressure,
}

// FromMessages reports whether c is one of MessageCodes.
func (c Code) FromMessages() bool { return slices.Contains(MessageCodes, c) }

const (
	// WindowSize is how many of the newest messages with text a check reads.
	WindowSize = 20
	// ChecksPerDay caps the checks of one conversation in 24 hours.
	ChecksPerDay = 50
	// CheckRetention is how long a check is kept.
	CheckRetention = 365 * 24 * time.Hour
	// NewAccountAge is the age under which an account is new.
	NewAccountAge = 7 * 24 * time.Hour
	// PriceGapMin is the percentage under the median from which a price is
	// far below the market, over at least PriceSampleMin listings.
	PriceGapMin    = 30
	PriceSampleMin = 5
)

// texts are the Vietnamese texts of the codes; params names the one
// parameter of a code whose text has one.
var (
	texts = map[Code]string{
		CodePrepayment:    "Đòi chuyển tiền hoặc đặt cọc trước",
		CodeOffApp:        "Rủ chuyển sang Zalo, Telegram, Facebook",
		CodeLink:          "Gửi link lạ, giả trang thanh toán hoặc giao hàng",
		CodeSensitive:     "Xin mã OTP, mật khẩu hoặc thông tin thẻ",
		CodeImpersonation: "Mạo danh ShopNexus, ngân hàng hoặc hãng vận chuyển",
		CodeFakeProof:     `Gửi biên lai giả hoặc bảo "chuyển dư, hoàn lại giúp"`,
		CodePressure:      "Hối thúc, ép quyết định ngay",
		CodeNewAccount:    "Tài khoản mới tạo %d ngày",
		CodePriceBelow:    "Giá thấp hơn %d%% so với tin tương tự",
	}
	params = map[Code]string{CodeNewAccount: "days", CodePriceBelow: "percent"}
)

// Signal is one code of a warning, with the parameters of its text and
// when a check first found it.
type Signal struct {
	Code        Code           `json:"code"`
	Params      map[string]int `json:"params,omitempty"`
	FirstSeenAt time.Time      `json:"first_seen_at"`
}

// Text is the signal's Vietnamese text; empty for an unknown code.
func (s Signal) Text() string {
	t := texts[s.Code]
	if p, ok := params[s.Code]; ok {
		return fmt.Sprintf(t, s.Params[p])
	}
	return t
}

// NewAccountSignal is new_account for an account created at created, when
// it is under NewAccountAge old at now; days is whole days, at least 1.
func NewAccountSignal(created, now time.Time) (Signal, bool) {
	age := now.Sub(created)
	if age < 0 || age >= NewAccountAge {
		return Signal{}, false
	}
	return Signal{Code: CodeNewAccount, Params: map[string]int{"days": max(1, int(age/(24*time.Hour)))}}, true
}

// PriceBelowSignal is price_far_below for a price at least PriceGapMin
// percent under median, over a sample of at least PriceSampleMin listings;
// percent is rounded down.
func PriceBelowSignal(price, median int64, size int) (Signal, bool) {
	if size < PriceSampleMin || median <= 0 || price >= median {
		return Signal{}, false
	}
	percent := int((median - price) * 100 / median)
	if percent < PriceGapMin {
		return Signal{}, false
	}
	return Signal{Code: CodePriceBelow, Params: map[string]int{"percent": percent}}, true
}

// Side is a member's place in a conversation: a for account_a, b for
// account_b.
type Side string

const (
	SideA Side = "a"
	SideB Side = "b"
)

// Line is one message of a window: who sent it, its text after Redact and
// the listing it names.
type Line struct {
	MessageID uuid.UUID
	Side      Side
	Text      string
	ListingID *uuid.UUID
}

// Window is what a classifier reads: a conversation's newest messages with
// text, oldest first.
type Window struct {
	Lines []Line
}

// Verdict is a classifier's answer: the message codes of each side's own
// messages.
type Verdict struct {
	A []Code `json:"a"`
	B []Code `json:"b"`
}

// Clean keeps the message codes of each side once, in the order given, and
// counts what it dropped: unknown codes, fact codes and repeats.
func (v Verdict) Clean() (Verdict, int) {
	dropped := 0
	keep := func(codes []Code) []Code {
		out := []Code{}
		for _, c := range codes {
			if !c.FromMessages() || slices.Contains(out, c) {
				dropped++
				continue
			}
			out = append(out, c)
		}
		return out
	}
	return Verdict{A: keep(v.A), B: keep(v.B)}, dropped
}

var (
	emailPattern = regexp.MustCompile(`[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}`)
	// urlPattern is a link with a scheme and any host (group 1), or a bare
	// host under a common top-level domain (group 2), in one pass so a
	// placeholder is never matched again.
	urlPattern = regexp.MustCompile(`(?i)\bhttps?://([^\s/?#]+)\S*|` +
		`\b((?:[a-z0-9-]+\.)+(?:com|net|org|info|vn|me|ly|io|co|xyz|top|site|online|shop|link|app|cc|tk))\b(?:[/?#]\S*)?`)
	phonePattern  = regexp.MustCompile(`(?:\+84|\b84|\b0)(?:[\s.-]?\d){9,10}\b`)
	numberPattern = regexp.MustCompile(`\b\d(?:[\s-]?\d){7,18}\b(\s?(?i:vnđ|vnd|đ|k|tr))?`)
)

// Redact replaces email addresses, links, phone numbers and runs of 8 to 19
// digits (bank accounts, cards) with <EMAIL>, <URL:domain>, <PHONE> and
// <BANK_NUMBER>, in that order. An amount followed by đ, vnd, vnđ, k or tr
// stays, since a classifier needs it.
func Redact(text string) string {
	text = emailPattern.ReplaceAllString(text, "<EMAIL>")
	text = urlPattern.ReplaceAllStringFunc(text, func(m string) string {
		g := urlPattern.FindStringSubmatch(m)
		host := g[1]
		if host == "" {
			host = g[2]
		}
		return "<URL:" + strings.TrimPrefix(strings.ToLower(host), "www.") + ">"
	})
	text = phonePattern.ReplaceAllString(text, "<PHONE>")
	return numberPattern.ReplaceAllStringFunc(text, func(m string) string {
		if numberPattern.FindStringSubmatch(m)[1] != "" {
			return m
		}
		return "<BANK_NUMBER>"
	})
}

// Warning is what one member of a conversation is told about the other
// member, the suspect: the signals found, in the order found, and when the
// member last dismissed it.
type Warning struct {
	conversationID uuid.UUID
	accountID      uuid.UUID
	suspectID      uuid.UUID
	signals        []Signal
	dismissedAt    *time.Time
	updatedAt      time.Time
	writeID        uuid.UUID
}

// WarningState is a Warning's fields, for repositories.
type WarningState struct {
	ConversationID uuid.UUID
	AccountID      uuid.UUID
	SuspectID      uuid.UUID
	Signals        []Signal
	DismissedAt    *time.Time
	UpdatedAt      time.Time
	WriteID        uuid.UUID
}

// NewWarning starts account's warning about suspect in conversation, with
// no signal and no write ID.
func NewWarning(conversation, account, suspect uuid.UUID) Warning {
	return Warning{conversationID: conversation, accountID: account, suspectID: suspect}
}

// RestoreWarning rebuilds a stored warning; only repositories call it.
func RestoreWarning(st WarningState) Warning {
	return Warning{
		conversationID: st.ConversationID, accountID: st.AccountID, suspectID: st.SuspectID,
		signals: slices.Clone(st.Signals), dismissedAt: st.DismissedAt, updatedAt: st.UpdatedAt, writeID: st.WriteID,
	}
}

func (w *Warning) State() WarningState {
	return WarningState{
		ConversationID: w.conversationID, AccountID: w.accountID, SuspectID: w.suspectID,
		Signals: slices.Clone(w.signals), DismissedAt: w.dismissedAt, UpdatedAt: w.updatedAt, WriteID: w.writeID,
	}
}

// Saved records that the warning was written under writeID; only
// repositories call it.
func (w *Warning) Saved(writeID uuid.UUID) { w.writeID = writeID }

func (w *Warning) ConversationID() uuid.UUID { return w.conversationID }
func (w *Warning) AccountID() uuid.UUID      { return w.accountID }
func (w *Warning) SuspectID() uuid.UUID      { return w.suspectID }
func (w *Warning) Signals() []Signal         { return slices.Clone(w.signals) }
func (w *Warning) DismissedAt() *time.Time   { return w.dismissedAt }
func (w *Warning) UpdatedAt() time.Time      { return w.updatedAt }
func (w *Warning) WriteID() uuid.UUID        { return w.writeID }

// has reports whether the warning holds code c.
func (w *Warning) has(c Code) bool {
	return slices.ContainsFunc(w.signals, func(s Signal) bool { return s.Code == c })
}

// Raise adds the message codes of messages the warning lacks, in the order
// of MessageCodes, then the fact signals of facts it lacks, each first seen
// at at. Without a message code in messages it adds nothing. It reports
// whether the warning changed.
func (w *Warning) Raise(messages []Code, facts []Signal, at time.Time) bool {
	if !slices.ContainsFunc(messages, Code.FromMessages) {
		return false
	}
	changed := false
	for _, c := range MessageCodes {
		if slices.Contains(messages, c) && !w.has(c) {
			w.signals = append(w.signals, Signal{Code: c, FirstSeenAt: at})
			changed = true
		}
	}
	for _, f := range facts {
		if !f.Code.FromMessages() && !w.has(f.Code) {
			f.FirstSeenAt = at
			w.signals = append(w.signals, f)
			changed = true
		}
	}
	if changed {
		w.updatedAt = at
	}
	return changed
}

// Dismissed holds after a dismissal that no message code has been found
// since.
func (w *Warning) Dismissed() bool {
	if w.dismissedAt == nil {
		return false
	}
	return !slices.ContainsFunc(w.signals, func(s Signal) bool {
		return s.Code.FromMessages() && s.FirstSeenAt.After(*w.dismissedAt)
	})
}

// Dismiss records a dismissal at at. A warning without signals, or one
// dismissed already, does not change; Dismiss reports whether it changed.
func (w *Warning) Dismiss(at time.Time) bool {
	if len(w.signals) == 0 || w.Dismissed() {
		return false
	}
	w.dismissedAt, w.updatedAt = &at, at
	return true
}

// Check is one classifier run over a window of a conversation: the
// window's first and last message, which classifier and prompt read it, and
// the codes of each side after Clean. It holds no message text.
type Check struct {
	ID             uuid.UUID
	ConversationID uuid.UUID
	FirstMessageID uuid.UUID
	LastMessageID  uuid.UUID
	Classifier     string
	PromptVersion  int
	A, B           []Code
	CreatedAt      time.Time
}
```

- [ ] **Step 5: Run the tests**

Run: `go test ./internal/trust/domain/`
Expected: PASS. If `TestRedact` fails on one case, fix the pattern, not the case: each case is a requirement from the spec or Review Focus 1.

- [ ] **Step 6: Lint and commit**

```bash
golangci-lint run ./internal/trust/...
python3 ~/.claude/skills/humanizing-writing/ai-tells.py internal/trust/domain/scam.go
git add internal/trust/domain/scam.go internal/trust/domain/scam_test.go
git commit -F tmp/commit.txt
```

Commit message (run the checker on `tmp/commit.txt` first):

```
feat(trust): scam codes, their texts, redaction and the warning

Nine codes, seven read from messages and two computed from data. A warning
needs a message code; a dismissal holds until a message code appears that
was not there.
```

---

### Task 2: Chat: the window of a conversation

**Files:**
- Modify: `internal/chat/repository/repository.go` (interface `Chats`), `internal/chat/repository/chat_pg.go`
- Modify: `internal/chat/service/service.go` (interface `Service`), `internal/chat/service/views.go`
- Create: `internal/chat/service/window.go`
- Test: `internal/chat/repository/chat_pg_test.go`, `internal/chat/service/window_test.go`

**Interfaces:**
- Consumes: `repository.Chats.Get`, `domain.Message` getters.
- Produces: `Chats.Window(ctx, conversation, upTo uuid.UUID, n int) ([]domain.Message, error)`, `chatsvc.Window`, `chatsvc.WindowLine`, `Service.Window(ctx, conversation, upTo uuid.UUID, n int) (Window, bool, error)`.

- [ ] **Step 1: Write the failing repository test**

Append to `internal/chat/repository/chat_pg_test.go` (it already has the helpers `pair` and `send`):

```go
// Window lists sent messages with text up to a message, newest first;
// photo-only and unsent messages stay out.
func TestWindow(t *testing.T) {
	t.Parallel()
	db := pgtest.New(t)
	s := repository.NewChats(db)
	ctx := context.Background()
	c, a, b := pair(t, db, s)
	first := send(t, s, c, a, "Còn không bạn?")
	second := send(t, s, c, b, "Còn bạn")
	photo, err := domain.NewMessage(uuid.NewV7(), c.ID, b, "", []uuid.UUID{uuid.NewV7()}, nil, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if err = s.AddMessage(ctx, photo); err != nil {
		t.Fatal(err)
	}
	third := send(t, s, c, a, "Cọc trước được không?")

	got, err := s.Window(ctx, c.ID, uuid.UUID{}, 20)
	if err != nil || len(got) != 3 || got[0].ID() != third.ID() || got[2].ID() != first.ID() {
		t.Fatalf("newest: %d %v", len(got), err)
	}
	if got, err = s.Window(ctx, c.ID, second.ID(), 20); err != nil || len(got) != 2 || got[0].ID() != second.ID() {
		t.Fatalf("up to the second: %d %v", len(got), err)
	}
	if got, err = s.Window(ctx, c.ID, uuid.UUID{}, 1); err != nil || len(got) != 1 || got[0].ID() != third.ID() {
		t.Fatalf("one: %d %v", len(got), err)
	}
}
```

Check `domain.NewMessage` for a photo message: if it requires the photos to exist as uploads or sets status `processing`, the photo message is not `sent` and stays out for that reason; the assertion holds either way.

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/chat/repository/ -run TestWindow`
Expected: build failure, `s.Window undefined`.

- [ ] **Step 3: Add the repository method**

In `internal/chat/repository/repository.go`, inside `type Chats interface`, after `Messages`:

```go
	// Window lists conversation's sent messages with text whose IDs are at
	// most upTo, or every one for the zero upTo, newest first, at most n.
	Window(ctx context.Context, conversation, upTo uuid.UUID, n int) ([]domain.Message, error)
```

In `internal/chat/repository/chat_pg.go`, after `Messages`:

```go
func (s pgChats) Window(ctx context.Context, conversation, upTo uuid.UUID, n int) ([]domain.Message, error) {
	if upTo == (uuid.UUID{}) {
		upTo = uuid.Max()
	}
	rows, err := s.db.Query(ctx, `SELECT `+messageColumns+` FROM messages m
WHERE m.conversation_id = @conversation AND m.status = 'sent' AND m.body <> '' AND m.id <= @up_to
ORDER BY m.id DESC LIMIT @limit`, pgx.StrictNamedArgs{"conversation": conversation, "up_to": upTo, "limit": n})
	if err != nil {
		return nil, fmt.Errorf("select window: %w", err)
	}
	out, err := pgx.CollectRows(rows, scanMessage)
	if err != nil {
		return nil, fmt.Errorf("read window: %w", err)
	}
	return out, nil
}
```

- [ ] **Step 4: Run the repository test**

Run: `go test ./internal/chat/repository/ -run TestWindow`
Expected: PASS.

- [ ] **Step 5: Write the failing service test**

`internal/chat/service/window_test.go`. Read `internal/chat/service/` test helpers first (a `newEnv` or similar in `*_test.go`); if there is one that builds `*service.Chat` on a database, use it. Otherwise build it as below:

```go
package service_test

import (
	"context"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/account/accounttest"
	"github.com/shopnexus/server2/internal/chat/domain"
	"github.com/shopnexus/server2/internal/chat/repository"
	"github.com/shopnexus/server2/internal/chat/service"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
)

// Window gives the members and the lines oldest first; an unknown
// conversation is false.
func TestWindowOfAConversation(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	chats := repository.NewChats(db)
	svc := service.New(service.Deps{Chats: chats, Now: time.Now})
	a, b := accounttest.New(t, db), accounttest.New(t, db)
	c, err := chats.OpenPair(ctx, domain.NewConversation(uuid.NewV7(), a, b, time.Now()))
	if err != nil {
		t.Fatal(err)
	}
	var ids []uuid.UUID
	for i, text := range []string{"Còn không bạn?", "Còn bạn", "Cọc trước nhé"} {
		sender := []uuid.UUID{a, b, b}[i]
		m, mErr := domain.NewMessage(uuid.NewV7(), c.ID, sender, text, nil, nil, time.Now())
		if mErr != nil {
			t.Fatal(mErr)
		}
		if mErr = chats.AddMessage(ctx, m); mErr != nil {
			t.Fatal(mErr)
		}
		ids = append(ids, m.ID())
	}
	w, found, err := svc.Window(ctx, c.ID, uuid.UUID{}, 20)
	if err != nil || !found || w.AccountA != c.AccountA || w.AccountB != c.AccountB || len(w.Lines) != 3 ||
		w.Lines[0].ID != ids[0] || w.Lines[2].Text != "Cọc trước nhé" || w.Lines[2].SenderID != b {
		t.Fatalf("%+v %v %v", w, found, err)
	}
	if w, _, err = svc.Window(ctx, c.ID, ids[1], 20); err != nil || len(w.Lines) != 2 || w.Lines[1].ID != ids[1] {
		t.Fatalf("up to the second: %+v %v", w, err)
	}
	if _, found, err = svc.Window(ctx, uuid.NewV7(), uuid.UUID{}, 20); err != nil || found {
		t.Fatalf("unknown: %v %v", found, err)
	}
}
```

- [ ] **Step 6: Add the service method**

In `internal/chat/service/views.go`, at the end:

```go
// Window is a conversation's newest sent messages with text, oldest first,
// with its two members, for module trust's scam check.
type Window struct {
	AccountA, AccountB uuid.UUID
	Lines              []WindowLine
}

// WindowLine is one message of a Window.
type WindowLine struct {
	ID, SenderID uuid.UUID
	Text         string
	ListingID    *uuid.UUID
}
```

In `internal/chat/service/service.go`, inside `type Service interface`, after `MessageFacts`:

```go
	// Window reads conversation's last n sent messages with text up to
	// message upTo, or the newest for the zero upTo, oldest first; false for
	// an unknown conversation.
	Window(ctx context.Context, conversation, upTo uuid.UUID, n int) (Window, bool, error)
```

`internal/chat/service/window.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"uuid"

	"github.com/shopnexus/server2/internal/chat/repository"
)

func (c *Chat) Window(ctx context.Context, conversation, upTo uuid.UUID, n int) (Window, bool, error) {
	conv, err := c.chats.Get(ctx, conversation)
	if errors.Is(err, repository.ErrNotFound) {
		return Window{}, false, nil
	}
	if err != nil {
		return Window{}, false, fmt.Errorf("get conversation: %w", err)
	}
	ms, err := c.chats.Window(ctx, conversation, upTo, n)
	if err != nil {
		return Window{}, false, fmt.Errorf("read window: %w", err)
	}
	w := Window{AccountA: conv.AccountA, AccountB: conv.AccountB, Lines: make([]WindowLine, 0, len(ms))}
	for i := len(ms) - 1; i >= 0; i-- {
		w.Lines = append(w.Lines, WindowLine{ID: ms[i].ID(), SenderID: ms[i].SenderID(), Text: ms[i].Body(), ListingID: ms[i].ListingID()})
	}
	return w, true, nil
}
```

- [ ] **Step 7: Run the chat tests**

Run: `go test ./internal/chat/... > tmp/chat-test.txt 2>&1; tail -20 tmp/chat-test.txt`
Expected: PASS. Any other implementation of `chatsvc.Service` (a fake in another module's tests) fails to build; give it the method by embedding the interface, as fakes there already do.

- [ ] **Step 8: Lint and commit**

```bash
golangci-lint run ./internal/chat/...
git add internal/chat
git commit -F tmp/commit.txt
```

```
feat(chat): the window of a conversation, its newest messages with text

Window reads up to 20 sent messages with text, up to a given message, with
the two members. Module trust's scam check reads it.
```

---

### Task 3: Catalog: a listing's price against the market

**Files:**
- Modify: `internal/catalog/domain/price.go`, `internal/catalog/service/service.go`, `internal/catalog/service/views.go`
- Create: `internal/catalog/service/market_price.go`
- Test: `internal/catalog/domain/price_test.go` (create or append), `internal/catalog/service/market_price_test.go`

**Interfaces:**
- Consumes: `repository.Listings.Get`, `repository.Vectors.Source`, `(*Catalog).PriceSample`.
- Produces: `domain.MedianPrice(samples []PriceSample) int64`, `service.MarketPrice`, `Service.MarketPrice(ctx, listing uuid.UUID, textMin, photoMin float64) (MarketPrice, bool, error)`.

- [ ] **Step 1: Write the failing tests**

`internal/catalog/domain/price_test.go` (append to the file if it exists, keeping its package clause):

```go
package domain_test

import (
	"testing"

	"github.com/shopnexus/server2/internal/catalog/domain"
)

func TestMedianPrice(t *testing.T) {
	t.Parallel()
	s := func(prices ...int64) []domain.PriceSample {
		out := make([]domain.PriceSample, len(prices))
		for i, p := range prices {
			out[i] = domain.PriceSample{Price: p}
		}
		return out
	}
	for _, c := range []struct {
		in   []domain.PriceSample
		want int64
	}{
		{nil, 0},
		{s(5), 5},
		{s(9, 1, 5), 5},
		{s(4, 1, 3, 2), 2},
	} {
		if got := domain.MedianPrice(c.in); got != c.want {
			t.Errorf("%v: %d, want %d", c.in, got, c.want)
		}
	}
}
```

The median of an even count is the mean of the two middle prices, rounded down: (2+3)/2 = 2.

`internal/catalog/service/market_price_test.go`, modelled on `price_sample_test.go`:

```go
package service_test

import (
	"context"
	"testing"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/catalog/catalogtest"
	"github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/catalog/repository"
	"github.com/shopnexus/server2/internal/provider/embed/embedtest"
)

// MarketPrice compares a listing with the listings like it, its seller's
// own left out.
func TestMarketPrice(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	ctx := context.Background()
	me, other := e.account(t), e.account(t)
	vs := repository.NewVectors(e.db)
	text := embedtest.Axis(domain.TextDims, 0)
	listing := func(seller uuid.UUID, price int64) uuid.UUID {
		id := catalogtest.Listing(t, e.db, seller, func(d *domain.Draft, _ *domain.Refs) { d.Price = price })
		if err := vs.PutText(ctx, id, "text-test", []byte{1}, text, time.Now()); err != nil {
			t.Fatal(err)
		}
		return id
	}
	for _, p := range []int64{9_000_000, 10_000_000, 10_000_000, 11_000_000, 12_000_000} {
		listing(other, p)
	}
	listing(me, 1_000) // the seller's own listing stays out of the sample
	mine := listing(me, 6_000_000)

	got, ok, err := e.catalog.MarketPrice(ctx, mine, 0.45, 0.6)
	if err != nil || !ok || got.SellerID != me || got.Price != 6_000_000 || got.Median != 10_000_000 || got.SampleSize != 5 {
		t.Fatalf("%+v %v %v", got, ok, err)
	}
	if _, ok, err = e.catalog.MarketPrice(ctx, uuid.NewV7(), 0.45, 0.6); err != nil || ok {
		t.Fatalf("unknown: %v %v", ok, err)
	}
}
```

If `newEnv` builds the catalog service with a text version other than `"text-test"`, use that version in `PutText`, as `price_sample_test.go` does.

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/catalog/domain/ ./internal/catalog/service/ -run 'TestMedianPrice|TestMarketPrice'`
Expected: build failure, `undefined: domain.MedianPrice`, `e.catalog.MarketPrice undefined`.

- [ ] **Step 3: Implement**

At the end of `internal/catalog/domain/price.go` (add `"slices"` to its imports):

```go
// MedianPrice is the median of the samples' prices, the mean of the two
// middle ones rounded down for an even count; 0 without samples.
func MedianPrice(samples []PriceSample) int64 {
	if len(samples) == 0 {
		return 0
	}
	prices := make([]int64, len(samples))
	for i, s := range samples {
		prices[i] = s.Price
	}
	slices.Sort(prices)
	mid := len(prices) / 2
	if len(prices)%2 == 1 {
		return prices[mid]
	}
	return (prices[mid-1] + prices[mid]) / 2
}
```

At the end of `internal/catalog/service/views.go`:

```go
// MarketPrice is a listing's seller and price beside the median price of the
// listings like it and how many there were.
type MarketPrice struct {
	SellerID   uuid.UUID
	Price      int64
	Median     int64
	SampleSize int
}
```

In `internal/catalog/service/service.go`, inside `type Service interface`, after `PriceSample`:

```go
	// MarketPrice compares a listing's price with a price sample drawn with
	// its own vectors at the cosine floors given, its seller's listings left
	// out; false for an unknown listing.
	MarketPrice(ctx context.Context, listing uuid.UUID, textMin, photoMin float64) (MarketPrice, bool, error)
```

`internal/catalog/service/market_price.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"uuid"

	"github.com/shopnexus/server2/internal/catalog/domain"
	"github.com/shopnexus/server2/internal/catalog/repository"
)

func (c *Catalog) MarketPrice(ctx context.Context, listing uuid.UUID, textMin, photoMin float64) (MarketPrice, bool, error) {
	l, err := c.listings.Get(ctx, listing)
	if errors.Is(err, repository.ErrNotFound) {
		return MarketPrice{}, false, nil
	}
	if err != nil {
		return MarketPrice{}, false, fmt.Errorf("get listing: %w", err)
	}
	text, photo, err := c.vectors.Source(ctx, listing, c.textVersion, c.imageVersion)
	if err != nil {
		return MarketPrice{}, false, fmt.Errorf("read the listing's vectors: %w", err)
	}
	samples, err := c.PriceSample(ctx, PriceQuery{
		Exclude: l.SellerID(), CategoryCode: l.CategoryCode(), Condition: l.Condition(),
		Text: text, Photo: photo, TextMin: textMin, PhotoMin: photoMin, Now: c.now(),
	})
	if err != nil {
		return MarketPrice{}, false, err
	}
	return MarketPrice{SellerID: l.SellerID(), Price: l.Price(), Median: domain.MedianPrice(samples), SampleSize: len(samples)}, true, nil
}
```

Check the field names of `*Catalog` (`listings`, `vectors`, `textVersion`, `imageVersion`, `now`) in `service.go` and use the ones there.

- [ ] **Step 4: Run the catalog tests**

Run: `go test ./internal/catalog/... > tmp/catalog-test.txt 2>&1; tail -20 tmp/catalog-test.txt`
Expected: PASS. Fakes of `catalogsvc.Service` in other modules' tests that do not embed the interface fail to build; embed it.

- [ ] **Step 5: Lint and commit**

```bash
golangci-lint run ./internal/catalog/...
git add internal/catalog
git commit -F tmp/commit.txt
```

```
feat(catalog): a listing's price beside the median of listings like it

MarketPrice draws the price sample with the listing's stored vectors and
leaves its seller's listings out. Trust's scam check reads it for
price_far_below.
```

---

### Task 4: Tables, the stream kind and trust's repository

**Files:**
- Create: `migrations/0036_scam_warnings.sql`
- Modify: `internal/platform/stream/stream.go`
- Create: `internal/trust/repository/scam.go`, `internal/trust/repository/scam_pg.go`
- Test: `internal/trust/repository/scam_pg_test.go`

**Interfaces:**
- Consumes: Task 1's `domain.Warning`, `domain.Check`, `domain.Code`.
- Produces: `stream.KindScamWarning`; `repository.ScamWarnings`, `repository.WarningWrite`, `repository.NewScamWarnings`.

- [ ] **Step 1: Write the migration**

`migrations/0036_scam_warnings.sql`:

```sql
-- Module trust: scam warnings in chat. A warning is what one member of a
-- conversation is told about the other, the suspect; signals is
-- [{code, params, first_seen_at}] in the order found. A check is one
-- classifier run over a window of a conversation and holds no message text:
-- the window is first_message_id to last_message_id in messages.
CREATE TABLE scam_warnings (
    conversation_id uuid NOT NULL REFERENCES conversations (id),
    account_id      uuid NOT NULL REFERENCES accounts (id),
    suspect_id      uuid NOT NULL REFERENCES accounts (id),
    signals         jsonb NOT NULL,
    dismissed_at    timestamptz,
    updated_at      timestamptz NOT NULL,
    write_id        uuid NOT NULL,
    PRIMARY KEY (conversation_id, account_id),
    CHECK (account_id <> suspect_id)
);

CREATE TABLE scam_checks (
    id               uuid PRIMARY KEY,
    conversation_id  uuid NOT NULL REFERENCES conversations (id),
    first_message_id uuid NOT NULL,
    last_message_id  uuid NOT NULL,
    classifier       text NOT NULL,
    prompt_version   int NOT NULL,
    codes_a          text[] NOT NULL,
    codes_b          text[] NOT NULL,
    created_at       timestamptz NOT NULL
);
-- The plan step reads a conversation's newest check and counts its last day.
CREATE INDEX scam_checks_conversation_created ON scam_checks (conversation_id, created_at DESC);
-- The save step deletes checks past retention, oldest first.
CREATE INDEX scam_checks_created ON scam_checks (created_at);
```

If `0036` is taken on `main` by now, use the next number (Global Constraints).

- [ ] **Step 2: Add the stream kind**

In `internal/platform/stream/stream.go`, in the `const` block after `KindVideoRead`:

```go
	// KindScamWarning is a scam warning of the account's raised, grown or
	// dismissed, with its conversation.
	KindScamWarning = "scam_warning"
```

- [ ] **Step 3: Write the failing repository tests**

`internal/trust/repository/scam_pg_test.go`:

```go
package repository_test

import (
	"context"
	"errors"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/shopnexus/server2/internal/account/accounttest"
	chatdomain "github.com/shopnexus/server2/internal/chat/domain"
	chatrepo "github.com/shopnexus/server2/internal/chat/repository"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server2/internal/trust/domain"
	"github.com/shopnexus/server2/internal/trust/repository"
)

// conversation opens the conversation of two new accounts.
func conversation(t *testing.T, db *pgxpool.Pool) (c chatdomain.Conversation) {
	t.Helper()
	c, err := chatrepo.NewChats(db).OpenPair(context.Background(),
		chatdomain.NewConversation(uuid.NewV7(), accounttest.New(t, db), accounttest.New(t, db), time.Now()))
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func check(c chatdomain.Conversation, at time.Time, a []domain.Code) domain.Check {
	return domain.Check{
		ID: uuid.NewV7(), ConversationID: c.ID, FirstMessageID: uuid.NewV7(), LastMessageID: uuid.NewV7(),
		Classifier: "test", PromptVersion: 1, A: a, B: []domain.Code{}, CreatedAt: at,
	}
}

func updates(t *testing.T, db *pgxpool.Pool, account uuid.UUID) int {
	t.Helper()
	var n int
	if err := db.QueryRow(context.Background(), `SELECT count(*) FROM account_updates WHERE account_id = @a AND kind = 'scam_warning'`,
		pgx.StrictNamedArgs{"a": account}).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

func TestScamWarnings(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewScamWarnings(db)
	c := conversation(t, db)
	at := time.Now().UTC().Truncate(time.Microsecond)

	if last, n, err := s.Checked(ctx, c.ID, at.Add(-24*time.Hour)); err != nil || last != (uuid.UUID{}) || n != 0 {
		t.Fatalf("no checks: %v %d %v", last, n, err)
	}
	w := domain.NewWarning(c.ID, c.AccountB, c.AccountA)
	w.Raise([]domain.Code{domain.CodePrepayment}, nil, at)
	ck := check(c, at, []domain.Code{domain.CodePrepayment})
	writeID := uuid.NewV7()
	for range 2 { // a retried step writes the check once and finds the warning saved
		if err := s.Record(ctx, ck, []repository.WarningWrite{{Warning: &w, WriteID: writeID}}, at.Add(-domain.CheckRetention)); err != nil &&
			!errors.Is(err, repository.ErrConflict) {
			t.Fatal(err)
		}
	}
	if w.WriteID() != writeID {
		t.Fatalf("write id %v", w.WriteID())
	}
	last, n, err := s.Checked(ctx, c.ID, at.Add(-24*time.Hour))
	if err != nil || last != ck.LastMessageID || n != 1 {
		t.Fatalf("checked: %v %d %v", last, n, err)
	}
	got, err := s.Get(ctx, c.ID, c.AccountB)
	if err != nil || got.SuspectID() != c.AccountA || len(got.Signals()) != 1 || got.Signals()[0].Code != domain.CodePrepayment ||
		!got.Signals()[0].FirstSeenAt.Equal(at) || got.WriteID() != writeID {
		t.Fatalf("get: %+v %v", got.State(), err)
	}
	if updates(t, db, c.AccountB) != 1 || updates(t, db, c.AccountA) != 0 {
		t.Fatal("only the warned member hears of it")
	}
	if _, err = s.Get(ctx, c.ID, c.AccountA); !errors.Is(err, repository.ErrNotFound) {
		t.Fatalf("the suspect has none: %v", err)
	}
	many, err := s.Of(ctx, c.AccountB, []uuid.UUID{c.ID, uuid.NewV7()})
	if err != nil || len(many) != 1 || many[c.ID].AccountID() != c.AccountB {
		t.Fatalf("of: %v %v", many, err)
	}

	got.Dismiss(at.Add(time.Minute))
	if err = s.Save(ctx, &got, uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	if again, _ := s.Get(ctx, c.ID, c.AccountB); !again.Dismissed() || updates(t, db, c.AccountB) != 2 {
		t.Fatalf("dismissed: %+v", again.State())
	}
}

// A write over a stale write ID is ErrConflict and changes nothing.
func TestScamWarningsConflict(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewScamWarnings(db)
	c := conversation(t, db)
	at := time.Now().UTC().Truncate(time.Microsecond)
	w := domain.NewWarning(c.ID, c.AccountB, c.AccountA)
	w.Raise([]domain.Code{domain.CodePrepayment}, nil, at)
	if err := s.Record(ctx, check(c, at, []domain.Code{domain.CodePrepayment}), []repository.WarningWrite{{Warning: &w, WriteID: uuid.NewV7()}},
		at.Add(-domain.CheckRetention)); err != nil {
		t.Fatal(err)
	}
	stale, _ := s.Get(ctx, c.ID, c.AccountB)
	fresh, _ := s.Get(ctx, c.ID, c.AccountB)
	fresh.Dismiss(at.Add(time.Minute))
	if err := s.Save(ctx, &fresh, uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	stale.Raise([]domain.Code{domain.CodeSensitive}, nil, at.Add(2*time.Minute))
	err := s.Record(ctx, check(c, at.Add(2*time.Minute), []domain.Code{domain.CodeSensitive}),
		[]repository.WarningWrite{{Warning: &stale, WriteID: uuid.NewV7()}}, at.Add(-domain.CheckRetention))
	if !errors.Is(err, repository.ErrConflict) {
		t.Fatalf("stale record: %v", err)
	}
	if _, n, _ := s.Checked(ctx, c.ID, at.Add(-time.Hour)); n != 1 {
		t.Fatalf("the conflict wrote a check: %d", n)
	}
	// A new warning where a row exists is a conflict too.
	dup := domain.NewWarning(c.ID, c.AccountB, c.AccountA)
	dup.Raise([]domain.Code{domain.CodePressure}, nil, at)
	if err = s.Save(ctx, &dup, uuid.NewV7()); !errors.Is(err, repository.ErrConflict) {
		t.Fatalf("duplicate insert: %v", err)
	}
}

// Deleting an account deletes its own warnings; those about it stay.
func TestScamWarningsDeleteAccount(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewScamWarnings(db)
	c := conversation(t, db)
	at := time.Now().UTC().Truncate(time.Microsecond)
	toB, toA := domain.NewWarning(c.ID, c.AccountB, c.AccountA), domain.NewWarning(c.ID, c.AccountA, c.AccountB)
	toB.Raise([]domain.Code{domain.CodePrepayment}, nil, at)
	toA.Raise([]domain.Code{domain.CodeFakeProof}, nil, at)
	if err := s.Record(ctx, check(c, at, []domain.Code{domain.CodePrepayment}),
		[]repository.WarningWrite{{Warning: &toB, WriteID: uuid.NewV7()}, {Warning: &toA, WriteID: uuid.NewV7()}},
		at.Add(-domain.CheckRetention)); err != nil {
		t.Fatal(err)
	}
	for range 2 {
		if err := s.DeleteAccount(ctx, c.AccountA); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := s.Get(ctx, c.ID, c.AccountA); !errors.Is(err, repository.ErrNotFound) {
		t.Fatalf("A's own warning: %v", err)
	}
	if _, err := s.Get(ctx, c.ID, c.AccountB); err != nil {
		t.Fatalf("B's warning about A: %v", err)
	}
}

// Recording a check deletes checks past retention.
func TestScamChecksPruned(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	db := pgtest.New(t)
	s := repository.NewScamWarnings(db)
	c := conversation(t, db)
	now := time.Now().UTC()
	old := now.Add(-domain.CheckRetention - time.Hour)
	if err := s.Record(ctx, check(c, old, []domain.Code{}), nil, old.Add(-domain.CheckRetention)); err != nil {
		t.Fatal(err)
	}
	if err := s.Record(ctx, check(c, now, []domain.Code{}), nil, now.Add(-domain.CheckRetention)); err != nil {
		t.Fatal(err)
	}
	if _, n, _ := s.Checked(ctx, c.ID, old.Add(-time.Hour)); n != 1 {
		t.Fatalf("checks left: %d", n)
	}
}
```

- [ ] **Step 4: Run them to see them fail**

Run: `go test ./internal/trust/repository/ -run 'TestScam'`
Expected: build failure, `undefined: repository.NewScamWarnings`.

- [ ] **Step 5: Write the interface**

`internal/trust/repository/scam.go`:

```go
package repository

import (
	"context"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/trust/domain"
)

// ScamWarnings persists scam warnings, one per member of a conversation,
// and the checks that raise them.
type ScamWarnings interface {
	// Get returns account's warning in conversation, or ErrNotFound.
	Get(ctx context.Context, conversation, account uuid.UUID) (domain.Warning, error)
	// Of returns account's warnings in the conversations given, keyed by
	// conversation; a conversation without one is left out.
	Of(ctx context.Context, account uuid.UUID, conversations []uuid.UUID) (map[uuid.UUID]domain.Warning, error)
	// Record writes check c once by its ID, each warning of ws under its
	// WriteID, and deletes up to 1,000 checks created before pruneBefore,
	// in one transaction. A warning whose row has another write ID than
	// its own, or a new one whose row exists, is ErrConflict and nothing is
	// written. Each warning written notifies its account.
	Record(ctx context.Context, c domain.Check, ws []WarningWrite, pruneBefore time.Time) error
	// Save writes w under writeID when its row still has w.WriteID(), and
	// notifies its account; otherwise ErrConflict.
	Save(ctx context.Context, w *domain.Warning, writeID uuid.UUID) error
	// Checked returns the last message of conversation's newest check, the
	// zero ID without one, and how many checks it had since since.
	Checked(ctx context.Context, conversation uuid.UUID, since time.Time) (last uuid.UUID, count int, err error)
	// DeleteAccount deletes account's own warnings; the warnings about it
	// stay.
	DeleteAccount(ctx context.Context, account uuid.UUID) error
}

// WarningWrite is a warning to write and the write ID it gets.
type WarningWrite struct {
	Warning *domain.Warning
	WriteID uuid.UUID
}
```

Update the package comment in `repository.go` from "stores module trust's reviews" to "stores module trust's reviews, reports and scam warnings".

- [ ] **Step 6: Write the Postgres version**

`internal/trust/repository/scam_pg.go`:

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

	"github.com/shopnexus/server2/internal/platform/stream"
	"github.com/shopnexus/server2/internal/trust/domain"
)

type pgScamWarnings struct{ db *pgxpool.Pool }

func NewScamWarnings(db *pgxpool.Pool) ScamWarnings { return pgScamWarnings{db} }

const warningColumns = `conversation_id, account_id, suspect_id, signals, dismissed_at, updated_at, write_id`

// pruneBatch caps the checks one Record deletes.
const pruneBatch = 1000

func scanWarning(row pgx.Row) (domain.Warning, error) {
	var st domain.WarningState
	if err := row.Scan(&st.ConversationID, &st.AccountID, &st.SuspectID, &st.Signals, &st.DismissedAt, &st.UpdatedAt,
		&st.WriteID); err != nil {
		return domain.Warning{}, fmt.Errorf("scan scam warning: %w", err)
	}
	return domain.RestoreWarning(st), nil
}

func (s pgScamWarnings) Get(ctx context.Context, conversation, account uuid.UUID) (domain.Warning, error) {
	w, err := scanWarning(s.db.QueryRow(ctx, `SELECT `+warningColumns+` FROM scam_warnings
WHERE conversation_id = @conversation AND account_id = @account`, pgx.StrictNamedArgs{"conversation": conversation, "account": account}))
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Warning{}, ErrNotFound
	}
	return w, err
}

func (s pgScamWarnings) Of(ctx context.Context, account uuid.UUID, conversations []uuid.UUID) (map[uuid.UUID]domain.Warning, error) {
	rows, err := s.db.Query(ctx, `SELECT `+warningColumns+` FROM scam_warnings
WHERE account_id = @account AND conversation_id = ANY(@conversations)`, pgx.StrictNamedArgs{"account": account, "conversations": conversations})
	if err != nil {
		return nil, fmt.Errorf("select scam warnings: %w", err)
	}
	ws, err := pgx.CollectRows(rows, func(r pgx.CollectableRow) (domain.Warning, error) { return scanWarning(r) })
	if err != nil {
		return nil, fmt.Errorf("read scam warnings: %w", err)
	}
	out := make(map[uuid.UUID]domain.Warning, len(ws))
	for _, w := range ws {
		out[w.ConversationID()] = w
	}
	return out, nil
}

// putWarning writes w under writeID when its row has w.WriteID(), or adds
// it when it has none and no row exists, then notifies its account.
func putWarning(ctx context.Context, tx pgx.Tx, w *domain.Warning, writeID uuid.UUID) error {
	st := w.State()
	tag, err := tx.Exec(ctx, `INSERT INTO scam_warnings (`+warningColumns+`)
VALUES (@conversation, @account, @suspect, @signals::jsonb, @dismissed_at, @updated_at, @write_id)
ON CONFLICT (conversation_id, account_id) DO UPDATE
SET signals = EXCLUDED.signals, dismissed_at = EXCLUDED.dismissed_at, updated_at = EXCLUDED.updated_at,
    write_id = EXCLUDED.write_id
WHERE scam_warnings.write_id = @old`, pgx.StrictNamedArgs{
		"conversation": st.ConversationID, "account": st.AccountID, "suspect": st.SuspectID, "signals": st.Signals,
		"dismissed_at": st.DismissedAt, "updated_at": st.UpdatedAt, "write_id": writeID, "old": st.WriteID,
	})
	if err != nil {
		return fmt.Errorf("upsert scam warning: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrConflict
	}
	conversation := st.ConversationID
	if err = stream.Notify(ctx, tx, []uuid.UUID{st.AccountID},
		stream.Hint{Kind: stream.KindScamWarning, ConversationID: &conversation}); err != nil {
		return fmt.Errorf("notify the scam warning: %w", err)
	}
	return nil
}

// codeStrings turns codes into the text[] of a check.
func codeStrings(codes []domain.Code) []string {
	out := make([]string, len(codes))
	for i, c := range codes {
		out[i] = string(c)
	}
	return out
}

func (s pgScamWarnings) Record(ctx context.Context, c domain.Check, ws []WarningWrite, pruneBefore time.Time) error {
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `INSERT INTO scam_checks (id, conversation_id, first_message_id, last_message_id, classifier,
    prompt_version, codes_a, codes_b, created_at)
VALUES (@id, @conversation, @first, @last, @classifier, @prompt_version, @codes_a, @codes_b, @created_at)
ON CONFLICT (id) DO NOTHING`, pgx.StrictNamedArgs{
			"id": c.ID, "conversation": c.ConversationID, "first": c.FirstMessageID, "last": c.LastMessageID,
			"classifier": c.Classifier, "prompt_version": c.PromptVersion, "codes_a": codeStrings(c.A), "codes_b": codeStrings(c.B),
			"created_at": c.CreatedAt,
		}); err != nil {
			return fmt.Errorf("insert scam check: %w", err)
		}
		for _, w := range ws {
			if err := putWarning(ctx, tx, w.Warning, w.WriteID); err != nil {
				return err
			}
		}
		if _, err := tx.Exec(ctx, `DELETE FROM scam_checks WHERE id IN (
    SELECT id FROM scam_checks WHERE created_at < @before ORDER BY created_at LIMIT @limit)`,
			pgx.StrictNamedArgs{"before": pruneBefore, "limit": pruneBatch}); err != nil {
			return fmt.Errorf("prune scam checks: %w", err)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("record scam check: %w", err)
	}
	for _, w := range ws {
		w.Warning.Saved(w.WriteID)
	}
	return nil
}

func (s pgScamWarnings) Save(ctx context.Context, w *domain.Warning, writeID uuid.UUID) error {
	if err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error { return putWarning(ctx, tx, w, writeID) }); err != nil {
		return fmt.Errorf("save scam warning: %w", err)
	}
	w.Saved(writeID)
	return nil
}

func (s pgScamWarnings) Checked(ctx context.Context, conversation uuid.UUID, since time.Time) (uuid.UUID, int, error) {
	var (
		last  *uuid.UUID
		count int
	)
	if err := s.db.QueryRow(ctx, `SELECT
    (SELECT last_message_id FROM scam_checks WHERE conversation_id = @conversation ORDER BY created_at DESC, id DESC LIMIT 1),
    (SELECT count(*) FROM scam_checks WHERE conversation_id = @conversation AND created_at >= @since)`,
		pgx.StrictNamedArgs{"conversation": conversation, "since": since}).Scan(&last, &count); err != nil {
		return uuid.UUID{}, 0, fmt.Errorf("read scam checks: %w", err)
	}
	if last == nil {
		return uuid.UUID{}, count, nil
	}
	return *last, count, nil
}

func (s pgScamWarnings) DeleteAccount(ctx context.Context, account uuid.UUID) error {
	if _, err := s.db.Exec(ctx, `DELETE FROM scam_warnings WHERE account_id = @account`, pgx.StrictNamedArgs{"account": account}); err != nil {
		return fmt.Errorf("delete scam warnings: %w", err)
	}
	return nil
}
```

`errors.Is(err, ErrConflict)` still holds through the `fmt.Errorf` wrapping.

- [ ] **Step 7: Run the repository tests**

Run: `go test ./internal/trust/repository/ > tmp/trust-repo.txt 2>&1; tail -20 tmp/trust-repo.txt`
Expected: PASS. If pgx refuses `[]domain.Signal` for `@signals::jsonb`, marshal it with `json.Marshal` and pass the bytes; scanning `jsonb` into `[]domain.Signal` works as is.

- [ ] **Step 8: Lint and commit**

```bash
golangci-lint run ./internal/trust/... ./internal/platform/stream/...
git add migrations/0036_scam_warnings.sql internal/platform/stream/stream.go internal/trust/repository
git commit -F tmp/commit.txt
```

```
feat(trust): scam_warnings and scam_checks, with the update scam_warning

A check and the warnings it raises are written in one transaction, each
warning under the write_id rule, and the warned member's stream hears of
it. Each check deletes up to 1,000 checks older than 365 days.
```

---

### Task 5: Configuration and the LLM classifier

**Files:**
- Modify: `internal/platform/config/config.go`, `internal/platform/config/config_test.go`, `.env.example`
- Modify (umbrella): `~/shopnexus/docker-compose.yml`, `~/shopnexus/Makefile`
- Create: `internal/trust/service/scam.go` (the interfaces only, so the classifier compiles), `internal/trust/service/scam_llm.go`
- Test: `internal/trust/service/scam_llm_test.go`

**Interfaces:**
- Consumes: `llm.Client`, `llm.Request`, `llm.ErrRefused`; Task 1's `domain.Window`, `domain.Verdict`, `domain.MessageCodes`.
- Produces: `config.TrustConfig`, `Config.Trust`; `service.Classifier`, `service.FactSource`, `service.ErrRefused`, `service.LLMClassifier`, `service.ScamPromptVersion`.

- [ ] **Step 1: Configuration**

In `internal/platform/config/config.go`:
- Add `Trust TrustConfig` to `Config` after `Assist AssistConfig`.
- After `AssistConfig`, add:

```go
// TrustConfig says where module trust's scam classifier is: an
// OpenAI-compatible API, LiteLLM's alias scam-check in the cluster. The key
// is never logged.
type TrustConfig struct {
	LLMBaseURL  string        // TRUST_LLM_BASE_URL
	LLMAPIKey   string        // TRUST_LLM_API_KEY: server-trust's key
	LLMModel    string        // TRUST_LLM_MODEL: the alias scam-check
	CallTimeout time.Duration // TRUST_CALL_TIMEOUT: one call to the model
}
```

- In the loader, after the `Assist:` block:

```go
		Trust: TrustConfig{
			LLMBaseURL: need("TRUST_LLM_BASE_URL"), LLMAPIKey: need("TRUST_LLM_API_KEY"), LLMModel: need("TRUST_LLM_MODEL"),
			CallTimeout: duration("TRUST_CALL_TIMEOUT"),
		},
```

In `internal/platform/config/config_test.go`, next to the `ASSIST_*` entries of the full environment map:

```go
		"TRUST_LLM_BASE_URL":           "http://litellm.example.test/v1",
		"TRUST_LLM_API_KEY":            "trust-key",
		"TRUST_LLM_MODEL":              "scam-check",
		"TRUST_CALL_TIMEOUT":           "20s",
```

If the test compares a whole expected `Config`, add `Trust: config.TrustConfig{LLMBaseURL: "http://litellm.example.test/v1", LLMAPIKey: "trust-key", LLMModel: "scam-check", CallTimeout: 20 * time.Second}`. If it has a case per required variable, the loop covers the new ones.

In `.env.example`, after `ASSIST_CALL_TIMEOUT=30s`:

```
# The model that reads chats for scam warnings (module trust; see
# ARCHITECTURE.md, Trust). Every one is required; make run stops and names
# the one left empty. The values of LLM_* work here.
TRUST_LLM_BASE_URL=
TRUST_LLM_API_KEY=
TRUST_LLM_MODEL=
TRUST_CALL_TIMEOUT=20s
```

In `~/shopnexus/docker-compose.yml`, in `x-server-env` after `ASSIST_CALL_TIMEOUT: 30s`:

```yaml
  # Scam warnings (module trust): the LLM in server/.env.
  TRUST_LLM_BASE_URL: ${TRUST_LLM_BASE_URL:-}
  TRUST_LLM_API_KEY: ${TRUST_LLM_API_KEY:-}
  TRUST_LLM_MODEL: ${TRUST_LLM_MODEL:-}
  TRUST_CALL_TIMEOUT: 20s
```

and in the comment near line 45 that lists the variables read from `server/.env`, add `TRUST_LLM_BASE_URL, TRUST_LLM_API_KEY, TRUST_LLM_MODEL`. In `~/shopnexus/Makefile`, change the comment above `COMPOSE_LLM` to name "the three ASSIST_LLM_ and the three TRUST_LLM_ variables" and "those nine are the only ones it names".

If the server's own `docker-compose.test.yml` or `Makefile` sets the `ASSIST_*` variables anywhere, set the `TRUST_*` ones beside them (`grep -rn ASSIST_ Makefile docker-compose*.yml`).

Run: `go test ./internal/platform/config/`
Expected: PASS.

- [ ] **Step 2: The interfaces**

`internal/trust/service/scam.go`:

```go
package service

import (
	"context"
	"errors"
	"time"
	"uuid"

	"github.com/shopnexus/server2/internal/trust/domain"
)

// Classifier reads a redacted window of a conversation and picks the
// message codes of each side's own messages. The LLM is the first; a model
// trained on scam_checks can replace it with no other change.
type Classifier interface {
	// Name is stored in scam_checks.classifier, as "llm:scam-check".
	Name() string
	// PromptVersion is stored in scam_checks.prompt_version; 0 for a
	// classifier without a prompt.
	PromptVersion() int
	// Classify returns an error wrapping ErrRefused when the same window
	// would be refused again.
	Classify(ctx context.Context, w domain.Window) (domain.Verdict, error)
}

// FactSource tells which fact signals hold at now for the suspect of a
// window.
type FactSource interface {
	Signals(ctx context.Context, suspect uuid.UUID, w domain.Window, now time.Time) ([]domain.Signal, error)
}

// ErrRefused is wrapped by a classifier's error when the same window would
// be refused again; the check is skipped without a retry.
var ErrRefused = errors.New("trust: the classifier refused the window")
```

- [ ] **Step 3: Write the failing classifier test**

`internal/trust/service/scam_llm_test.go`:

```go
package service_test

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/shopnexus/server2/internal/provider/llm"
	"github.com/shopnexus/server2/internal/trust/domain"
	"github.com/shopnexus/server2/internal/trust/service"
)

// The classifier sends one line per message, marked with its side, under a
// strict schema whose enum is the message codes, and decodes the answer.
func TestLLMClassifier(t *testing.T) {
	t.Parallel()
	var user string
	var enum []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Messages []struct {
				Content string `json:"content"`
			} `json:"messages"`
			ResponseFormat struct {
				JSONSchema struct {
					Schema struct {
						Properties struct {
							A struct {
								Items struct {
									Enum []string `json:"enum"`
								} `json:"items"`
							} `json:"a"`
						} `json:"properties"`
					} `json:"schema"`
				} `json:"json_schema"`
			} `json:"response_format"`
		}
		if json.NewDecoder(r.Body).Decode(&body) != nil || len(body.Messages) != 2 {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		user, enum = body.Messages[1].Content, body.ResponseFormat.JSONSchema.Schema.Properties.A.Items.Enum
		_, _ = w.Write([]byte(`{"choices":[{"message":{"content":"{\"a\":[],\"b\":[\"prepayment_request\"]}"}}]}`))
	}))
	defer srv.Close()
	c := service.LLMClassifier{
		Model: llm.OpenAI{BaseURL: srv.URL, APIKey: "k", Model: "scam-check", HTTP: srv.Client()},
		Alias: "scam-check", Timeout: time.Second, Log: slog.New(slog.DiscardHandler),
	}
	v, err := c.Classify(context.Background(), domain.Window{Lines: []domain.Line{
		{Side: domain.SideA, Text: "Còn không bạn?"},
		{Side: domain.SideB, Text: "Còn, chuyển cọc\ntrước nhé"},
	}})
	if err != nil || len(v.A) != 0 || len(v.B) != 1 || v.B[0] != domain.CodePrepayment {
		t.Fatalf("%+v %v", v, err)
	}
	if user != "A: Còn không bạn?\nB: Còn, chuyển cọc trước nhé\n" {
		t.Fatalf("user %q", user)
	}
	want := make([]string, len(domain.MessageCodes))
	for i, code := range domain.MessageCodes {
		want[i] = string(code)
	}
	if !slices.Equal(enum, want) {
		t.Fatalf("enum %v, want %v", enum, want)
	}
	if c.Name() != "llm:scam-check" || c.PromptVersion() != service.ScamPromptVersion {
		t.Fatalf("%s %d", c.Name(), c.PromptVersion())
	}
	if !strings.Contains(service.ScamSystemPrompt, "prepayment_request") {
		t.Fatal("the prompt does not explain the codes")
	}
}

func TestLLMClassifierRefused(t *testing.T) {
	t.Parallel()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "content policy", http.StatusBadRequest)
	}))
	defer srv.Close()
	c := service.LLMClassifier{
		Model: llm.OpenAI{BaseURL: srv.URL, APIKey: "k", Model: "m", HTTP: srv.Client()},
		Alias: "m", Timeout: time.Second, Log: slog.New(slog.DiscardHandler),
	}
	if _, err := c.Classify(context.Background(), domain.Window{}); !errors.Is(err, service.ErrRefused) {
		t.Fatalf("%v", err)
	}
}
```

- [ ] **Step 4: Run it to see it fail**

Run: `go test ./internal/trust/service/ -run TestLLMClassifier`
Expected: build failure, `undefined: service.LLMClassifier`.

- [ ] **Step 5: Write the classifier**

`internal/trust/service/scam_llm.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/shopnexus/server2/internal/provider/llm"
	"github.com/shopnexus/server2/internal/trust/domain"
)

// ScamPromptVersion is stored with each check the LLM makes; raise it with
// every change of ScamSystemPrompt or scamSchema.
const ScamPromptVersion = 1

// ScamSystemPrompt tells the model what each message code means.
const ScamSystemPrompt = `You read a chat between two people, A and B, on ShopNexus, a Vietnamese marketplace for used goods. Buyers pay cash on delivery through the seller's own carrier account, or meet the seller in person. ShopNexus holds no money and never asks anyone to pay through a chat. Phone numbers, bank and card numbers, email addresses and links were replaced with <PHONE>, <BANK_NUMBER>, <EMAIL> and <URL:domain>.

For each of A and B, list the codes that person's own messages show. Judge a person only by what they wrote. List nothing for an ordinary chat about an item, its price, a meeting or a delivery: haggling, asking for photos, asking where to meet and giving a phone number to call at the meeting are ordinary.

Codes:
- prepayment_request: asks the other to transfer money or a deposit before receiving the item ("chuyển cọc trước", "ck trước 50%").
- off_app_contact: pushes the chat to Zalo, Telegram, Facebook or another app ("kết bạn zalo", "ib tele").
- suspicious_link: sends a link to pay, to track a parcel, to claim money or to log in.
- sensitive_info_request: asks for an OTP, a password, a card number, a CVV or a banking login.
- impersonation: claims to be ShopNexus staff, a bank, a carrier or an authority.
- fake_payment_proof: shows or mentions a transfer receipt to make the other ship first, or says they paid too much and asks for the difference back.
- pressure: pushes for a decision now with a deadline, scarcity or a threat ("chốt trong 10 phút", "nhiều người hỏi lắm").`

// scamSchema allows only the message codes, in the order of
// domain.MessageCodes; TestLLMClassifier holds the two together.
var scamSchema = []byte(`{"type":"object","additionalProperties":false,"required":["a","b"],"properties":{` +
	`"a":{"type":"array","items":{"type":"string","enum":["prepayment_request","off_app_contact","suspicious_link",` +
	`"sensitive_info_request","impersonation","fake_payment_proof","pressure"]}},` +
	`"b":{"type":"array","items":{"type":"string","enum":["prepayment_request","off_app_contact","suspicious_link",` +
	`"sensitive_info_request","impersonation","fake_payment_proof","pressure"]}}}}`)

// LLMClassifier asks a language model through provider/llm. Alias is the
// model's name at the gateway, scam-check in the cluster.
type LLMClassifier struct {
	Model   llm.Client
	Alias   string
	Timeout time.Duration
	Log     *slog.Logger
}

func (c LLMClassifier) Name() string       { return "llm:" + c.Alias }
func (c LLMClassifier) PromptVersion() int { return ScamPromptVersion }

// Classify sends one line per message, "A: text" or "B: text", with the
// line breaks of a message turned into spaces. The log line holds no text.
func (c LLMClassifier) Classify(ctx context.Context, w domain.Window) (domain.Verdict, error) {
	var b strings.Builder
	for _, l := range w.Lines {
		b.WriteString(strings.ToUpper(string(l.Side)))
		b.WriteString(": ")
		b.WriteString(strings.Join(strings.Fields(l.Text), " "))
		b.WriteString("\n")
	}
	started := time.Now()
	callCtx, cancel := context.WithTimeout(ctx, c.Timeout)
	defer cancel()
	var v domain.Verdict
	err := c.Model.Complete(callCtx, llm.Request{
		System: ScamSystemPrompt, User: b.String(), SchemaName: "scam_check", Schema: scamSchema,
	}, &v)
	if errors.Is(err, llm.ErrRefused) {
		return domain.Verdict{}, fmt.Errorf("%w: %w", ErrRefused, err)
	}
	if err != nil {
		return domain.Verdict{}, fmt.Errorf("ask the model: %w", err)
	}
	c.Log.InfoContext(ctx, "scam check classified", "prompt_version", ScamPromptVersion, "lines", len(w.Lines),
		"chars", utf8.RuneCountInString(b.String()), "a", v.A, "b", v.B, "ms", time.Since(started).Milliseconds())
	return v, nil
}
```

`strings.Fields` also squeezes runs of spaces; the test's expected user text has single spaces, which holds.

- [ ] **Step 6: Run the tests**

Run: `go test ./internal/trust/service/ -run TestLLMClassifier`
Expected: PASS. The other tests of the package still build: nothing references the new types yet.

- [ ] **Step 7: Lint and commit (server, then umbrella)**

```bash
golangci-lint run ./internal/trust/... ./internal/platform/config/...
python3 ~/.claude/skills/humanizing-writing/ai-tells.py internal/trust/service/scam.go
git add internal/platform/config .env.example internal/trust/service/scam.go internal/trust/service/scam_llm.go internal/trust/service/scam_llm_test.go
git commit -F tmp/commit.txt
```

```
feat(trust): the Classifier interface and its LLM, with TRUST_* settings

LLMClassifier sends one line per message under a strict schema of the
seven message codes and logs no text. TRUST_LLM_BASE_URL, TRUST_LLM_API_KEY,
TRUST_LLM_MODEL and TRUST_CALL_TIMEOUT are required.
```

Then in the umbrella (`cd ~/shopnexus && git switch -c feat/scam-warning` if not yet on it):

```bash
git add docker-compose.yml Makefile
git commit -F server/tmp/commit.txt
```

```
build: TRUST_* in compose for the server's scam classifier

Compose reads TRUST_LLM_BASE_URL, TRUST_LLM_API_KEY and TRUST_LLM_MODEL
from server/.env and sets TRUST_CALL_TIMEOUT to 20s.
```

---

### Task 6: Trust service: fact sources, the views, dismissing, erasing

**Files:**
- Modify: `internal/trust/service/service.go`, `internal/trust/service/views.go`, `internal/trust/service/helpers_test.go`
- Create: `internal/trust/service/scam_facts.go`, `internal/trust/service/scam_warning.go`
- Test: `internal/trust/service/scam_test.go`

**Interfaces:**
- Consumes: Task 2 `chatsvc.Service.Get` (membership), Task 3 `catalogsvc.Service.MarketPrice`, Task 4 `repository.ScamWarnings`, Task 5 interfaces.
- Produces: `AccountAge`, `MarketGap`, `ScamWarningView`, `ScamSignalView`, `Service.ScamWarnings`, `Service.DismissScamWarning`, `Service.DeleteScamWarnings`; `Deps` gains `Scams`, `Classifier`, `Facts`, `Log`, `Prefix`; `Trust` gains the matching fields.

- [ ] **Step 1: Write the failing tests**

First extend `internal/trust/service/helpers_test.go`: add `scams repository.ScamWarnings` to `env`, and in `newEnv` build `scams := repository.NewScamWarnings(db)` and pass `Scams: scams, Log: slog.New(slog.DiscardHandler)` in `service.Deps` (add `"log/slog"` to the imports). Set `scams: scams` in the returned `env`.

`internal/trust/service/scam_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"testing"
	"time"
	"uuid"

	catalogsvc "github.com/shopnexus/server2/internal/catalog/service"
	chatdomain "github.com/shopnexus/server2/internal/chat/domain"
	chatrepo "github.com/shopnexus/server2/internal/chat/repository"
	"github.com/shopnexus/server2/internal/trust/domain"
	"github.com/shopnexus/server2/internal/trust/repository"
	"github.com/shopnexus/server2/internal/trust/service"
)

// raise writes a warning to victim about suspect in conversation c, as a
// check would.
func raise(t *testing.T, e env, c chatdomain.Conversation, victim, suspect uuid.UUID, codes []domain.Code, at time.Time) {
	t.Helper()
	w, err := e.scams.Get(context.Background(), c.ID, victim)
	if errors.Is(err, repository.ErrNotFound) {
		w, err = domain.NewWarning(c.ID, victim, suspect), nil
	}
	if err != nil {
		t.Fatal(err)
	}
	w.Raise(codes, nil, at)
	ck := domain.Check{ID: uuid.NewV7(), ConversationID: c.ID, FirstMessageID: uuid.NewV7(), LastMessageID: uuid.NewV7(),
		Classifier: "test", A: codes, B: []domain.Code{}, CreatedAt: at}
	if err = e.scams.Record(context.Background(), ck, []repository.WarningWrite{{Warning: &w, WriteID: uuid.NewV7()}},
		at.Add(-domain.CheckRetention)); err != nil {
		t.Fatal(err)
	}
}

func pairOf(t *testing.T, e env) chatdomain.Conversation {
	t.Helper()
	c, err := chatrepo.NewChats(e.db).OpenPair(context.Background(), chatdomain.NewConversation(uuid.NewV7(), e.person(t), e.person(t), time.Now()))
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func TestScamWarningsView(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	e := newEnv(t)
	c := pairOf(t, e)
	raise(t, e, c, c.AccountB, c.AccountA, []domain.Code{domain.CodeOffApp, domain.CodePrepayment}, time.Now())
	got, err := e.trust.ScamWarnings(ctx, c.AccountB, []uuid.UUID{c.ID, uuid.NewV7()})
	if err != nil || len(got) != 1 {
		t.Fatalf("%v %v", got, err)
	}
	v := got[c.ID]
	if v.Dismissed || len(v.Signals) != 2 || v.Signals[0].Code != "prepayment_request" ||
		v.Signals[0].Text != "Đòi chuyển tiền hoặc đặt cọc trước" {
		t.Fatalf("%+v", v)
	}
	if mine, _ := e.trust.ScamWarnings(ctx, c.AccountA, []uuid.UUID{c.ID}); len(mine) != 0 {
		t.Fatalf("the suspect sees %+v", mine)
	}
	if none, err := e.trust.ScamWarnings(ctx, c.AccountB, nil); err != nil || len(none) != 0 {
		t.Fatalf("no conversations: %v %v", none, err)
	}
}

func TestDismissScamWarning(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	e := newEnv(t)
	c := pairOf(t, e)
	raise(t, e, c, c.AccountB, c.AccountA, []domain.Code{domain.CodePrepayment}, time.Now().Add(-time.Minute))
	// The warned member blocks the suspect and can still dismiss.
	if err := e.accounts.Block(ctx, c.AccountB, c.AccountA); err != nil {
		t.Fatal(err)
	}
	for range 2 {
		if err := e.trust.DismissScamWarning(ctx, c.AccountB, c.ID); err != nil {
			t.Fatal(err)
		}
	}
	if got, _ := e.trust.ScamWarnings(ctx, c.AccountB, []uuid.UUID{c.ID}); !got[c.ID].Dismissed {
		t.Fatalf("%+v", got)
	}
	// A new message code brings it back.
	raise(t, e, c, c.AccountB, c.AccountA, []domain.Code{domain.CodeSensitive}, time.Now().Add(time.Minute))
	if got, _ := e.trust.ScamWarnings(ctx, c.AccountB, []uuid.UUID{c.ID}); got[c.ID].Dismissed {
		t.Fatalf("after a new code: %+v", got)
	}
	// The suspect has no warning to dismiss; that is fine.
	if err := e.trust.DismissScamWarning(ctx, c.AccountA, c.ID); err != nil {
		t.Fatalf("without a warning: %v", err)
	}
	// Someone else gets conversation_not_found.
	if err := e.trust.DismissScamWarning(ctx, e.person(t), c.ID); !errors.Is(err, chatdomain.ErrNotFound) {
		t.Fatalf("a stranger: %v", err)
	}
}

func TestDeleteScamWarnings(t *testing.T) {
	t.Parallel()
	ctx := context.Background()
	e := newEnv(t)
	c := pairOf(t, e)
	raise(t, e, c, c.AccountB, c.AccountA, []domain.Code{domain.CodePrepayment}, time.Now())
	if err := e.trust.DeleteScamWarnings(ctx, c.AccountB); err != nil {
		t.Fatal(err)
	}
	if got, _ := e.trust.ScamWarnings(ctx, c.AccountB, []uuid.UUID{c.ID}); len(got) != 0 {
		t.Fatalf("%+v", got)
	}
}

func TestAccountAge(t *testing.T) {
	t.Parallel()
	e := newEnv(t)
	young := e.person(t)
	got, err := service.AccountAge{Accounts: e.accounts}.Signals(context.Background(), young, domain.Window{}, time.Now())
	if err != nil || len(got) != 1 || got[0].Code != domain.CodeNewAccount || got[0].Params["days"] != 1 {
		t.Fatalf("young: %+v %v", got, err)
	}
	got, err = service.AccountAge{Accounts: e.accounts}.Signals(context.Background(), young, domain.Window{}, time.Now().Add(8*24*time.Hour))
	if err != nil || len(got) != 0 {
		t.Fatalf("a week later: %+v %v", got, err)
	}
}

// marketStub answers MarketPrice from a map.
type marketStub struct {
	catalogsvc.Service

	prices map[uuid.UUID]catalogsvc.MarketPrice
	asked  []uuid.UUID
}

func (m *marketStub) MarketPrice(_ context.Context, id uuid.UUID, _, _ float64) (catalogsvc.MarketPrice, bool, error) {
	m.asked = append(m.asked, id)
	p, ok := m.prices[id]
	return p, ok, nil
}

// MarketGap reads the newest listing of the suspect's that the window
// names, once each, and skips the other member's.
func TestMarketGap(t *testing.T) {
	t.Parallel()
	suspect, other := uuid.NewV7(), uuid.NewV7()
	theirs, mine, unknown := uuid.NewV7(), uuid.NewV7(), uuid.NewV7()
	m := &marketStub{prices: map[uuid.UUID]catalogsvc.MarketPrice{
		theirs: {SellerID: suspect, Price: 5_000_000, Median: 10_000_000, SampleSize: 8},
		mine:   {SellerID: other, Price: 1, Median: 10_000_000, SampleSize: 8},
	}}
	w := domain.Window{Lines: []domain.Line{
		{ListingID: &theirs}, {ListingID: &mine}, {ListingID: &unknown}, {ListingID: &unknown},
	}}
	got, err := service.MarketGap{Catalog: m, TextMin: 0.45, PhotoMin: 0.6}.Signals(context.Background(), suspect, w, time.Now())
	if err != nil || len(got) != 1 || got[0].Code != domain.CodePriceBelow || got[0].Params["percent"] != 50 {
		t.Fatalf("%+v %v", got, err)
	}
	if len(m.asked) != 3 || m.asked[0] != unknown || m.asked[2] != theirs {
		t.Fatalf("asked %v", m.asked)
	}
}
```

Check `e.accounts.Block` exists on `accountsvc.Service` with `(ctx, blocker, blocked)` (it does, see ARCHITECTURE Blocks) and that `e.person` gives an account with a phone; `pairOf` needs nothing more.

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/trust/service/ -run 'TestScamWarningsView|TestDismissScamWarning|TestDeleteScamWarnings|TestAccountAge|TestMarketGap'`
Expected: build failure on the new names.

- [ ] **Step 3: Grow Deps, Trust and Service**

In `internal/trust/service/service.go`:

Add to `type Service interface`, after `WithdrawReport`:

```go
	// ScamWarnings reads account's scam warnings in the conversations
	// given, keyed by conversation; one without a warning is left out.
	ScamWarnings(ctx context.Context, account uuid.UUID, conversations []uuid.UUID) (map[uuid.UUID]ScamWarningView, error)
	// DismissScamWarning dismisses account's warning in a conversation of
	// account's; without a warning, or dismissed already, it changes
	// nothing. Anyone but a member gets chat's conversation_not_found.
	DismissScamWarning(ctx context.Context, account, conversation uuid.UUID) error
	// DeleteScamWarnings deletes a deleted account's own warnings.
	DeleteScamWarnings(ctx context.Context, account uuid.UUID) error
```

Add to `Deps`:

```go
	Scams repository.ScamWarnings
	// Classifier reads a check's window; Facts add fact signals beside a
	// message code.
	Classifier Classifier
	Facts      []FactSource
	Log        *slog.Logger
	// Prefix names this process's Restate services.
	Prefix string
```

Add the matching unexported fields to `Trust` (`scams`, `classifier`, `facts`, `log`, `prefix`) and set them in `New`. Update the package comment: "…and people report listings and accounts, and are warned of scams in chat."

- [ ] **Step 4: The views**

At the end of `internal/trust/service/views.go`:

```go
// ScamWarningView is the ScamWarning schema in api/schemas/trust.yaml.
type ScamWarningView struct {
	Signals   []ScamSignalView `json:"signals"`
	Dismissed bool             `json:"dismissed"`
}

// ScamSignalView is the ScamSignal schema.
type ScamSignalView struct {
	Code string `json:"code"`
	Text string `json:"text"`
}
```

- [ ] **Step 5: The use cases**

`internal/trust/service/scam_warning.go`:

```go
package service

import (
	"context"
	"errors"
	"fmt"
	"uuid"

	"github.com/shopnexus/server2/internal/platform/apperr"
	"github.com/shopnexus/server2/internal/trust/repository"
)

func (t *Trust) ScamWarnings(ctx context.Context, account uuid.UUID, conversations []uuid.UUID) (map[uuid.UUID]ScamWarningView, error) {
	if len(conversations) == 0 {
		return map[uuid.UUID]ScamWarningView{}, nil
	}
	ws, err := t.scams.Of(ctx, account, conversations)
	if err != nil {
		return nil, fmt.Errorf("read scam warnings: %w", err)
	}
	out := make(map[uuid.UUID]ScamWarningView, len(ws))
	for id, w := range ws {
		v := ScamWarningView{Signals: []ScamSignalView{}, Dismissed: w.Dismissed()}
		for _, s := range w.Signals() {
			v.Signals = append(v.Signals, ScamSignalView{Code: string(s.Code), Text: s.Text()})
		}
		out[id] = v
	}
	return out, nil
}

// DismissScamWarning reads the warning again once when a check saved it
// meanwhile, then answers try_again.
func (t *Trust) DismissScamWarning(ctx context.Context, account, conversation uuid.UUID) error {
	if _, err := t.chats.Get(ctx, account, conversation); err != nil {
		return fmt.Errorf("read conversation: %w", err)
	}
	for range 2 {
		w, err := t.scams.Get(ctx, conversation, account)
		if errors.Is(err, repository.ErrNotFound) {
			return nil
		}
		if err != nil {
			return fmt.Errorf("read scam warning: %w", err)
		}
		if !w.Dismiss(t.now()) {
			return nil
		}
		err = t.scams.Save(ctx, &w, uuid.NewV7())
		if !errors.Is(err, repository.ErrConflict) {
			return err
		}
	}
	return apperr.ErrTryAgain
}

func (t *Trust) DeleteScamWarnings(ctx context.Context, account uuid.UUID) error {
	if err := t.scams.DeleteAccount(ctx, account); err != nil {
		return fmt.Errorf("delete scam warnings: %w", err)
	}
	return nil
}
```

`t.chats.Get` returns chat's `domain.ErrNotFound` (an `*apperr.Error`, `conversation_not_found`) for a non-member, wrapped; `errors.Is` and the HTTP layer see through `%w`. `Save` returns nil or a wrapped error, so `return err` passes nil through.

- [ ] **Step 6: The fact sources**

`internal/trust/service/scam_facts.go`:

```go
package service

import (
	"context"
	"fmt"
	"time"
	"uuid"

	accountsvc "github.com/shopnexus/server2/internal/account/service"
	catalogsvc "github.com/shopnexus/server2/internal/catalog/service"
	"github.com/shopnexus/server2/internal/trust/domain"
)

// AccountAge tells new_account for a suspect whose account is under a week
// old.
type AccountAge struct {
	Accounts accountsvc.Service
}

func (f AccountAge) Signals(ctx context.Context, suspect uuid.UUID, _ domain.Window, now time.Time) ([]domain.Signal, error) {
	a, err := f.Accounts.Get(ctx, suspect)
	if err != nil {
		return nil, fmt.Errorf("read the suspect's account: %w", err)
	}
	if s, ok := domain.NewAccountSignal(a.CreatedAt, now); ok {
		return []domain.Signal{s}, nil
	}
	return nil, nil
}

// MarketGap tells price_far_below when the newest listing of the suspect's
// that the window names is priced far below listings like it. TextMin and
// PhotoMin are search's cosine floors.
type MarketGap struct {
	Catalog           catalogsvc.Service
	TextMin, PhotoMin float64
}

func (f MarketGap) Signals(ctx context.Context, suspect uuid.UUID, w domain.Window, _ time.Time) ([]domain.Signal, error) {
	asked := map[uuid.UUID]bool{}
	for i := len(w.Lines) - 1; i >= 0; i-- {
		id := w.Lines[i].ListingID
		if id == nil || asked[*id] {
			continue
		}
		asked[*id] = true
		m, ok, err := f.Catalog.MarketPrice(ctx, *id, f.TextMin, f.PhotoMin)
		if err != nil {
			return nil, fmt.Errorf("read the market price: %w", err)
		}
		if !ok || m.SellerID != suspect {
			continue
		}
		if s, holds := domain.PriceBelowSignal(m.Price, m.Median, m.SampleSize); holds {
			return []domain.Signal{s}, nil
		}
		return nil, nil
	}
	return nil, nil
}
```

- [ ] **Step 7: Run the trust tests**

Run: `go test ./internal/trust/... > tmp/trust.txt 2>&1; tail -30 tmp/trust.txt`
Expected: PASS, the old review and report tests included.

- [ ] **Step 8: Lint and commit**

```bash
golangci-lint run ./internal/trust/...
git add internal/trust
git commit -F tmp/commit.txt
```

```
feat(trust): scam warnings read, dismissed and erased, and two fact sources

A dismissal checks membership through chat's Get, so a member who blocks
the other can still dismiss. AccountAge tells new_account; MarketGap tells
price_far_below from the newest listing of the suspect's in the window.
```

---

### Task 7: The check, the worker and the mount

**Files:**
- Create: `internal/trust/service/scam_check_durable.go`, `internal/trust/worker/scam.go`
- Modify: `internal/trust/service/service.go` (`Durable`), `internal/trust/trust.go`, `internal/app/app.go`, `.golangci.yml` (through `make depguard`)
- Test: `internal/trust/service/scam_check_test.go`, `internal/trust/worker/scam_test.go`

**Interfaces:**
- Consumes: everything above; `restatex.Now`, `restatex.NewID`, `restate.Run`, `restate.RunVoid`, `restate.ObjectSend`, `ingress.Object`, `ingress.Service`.
- Produces: `ScamCheckName`, `ScamCheck`, `(*Trust).Durable()`, `worker.ScamWorker`, `trust.Settings`, `trust.LLMClassifier`, the new `trust.Mount` signature.

- [ ] **Step 1: Write the failing check tests**

`internal/trust/service/scam_check_test.go`:

```go
package service_test

import (
	"context"
	"errors"
	"log/slog"
	"strings"
	"sync"
	"testing"
	"time"
	"uuid"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	restate "github.com/restatedev/sdk-go"
	"github.com/restatedev/sdk-go/ingress"

	"github.com/shopnexus/server2/internal/account/accounttest"
	chatdomain "github.com/shopnexus/server2/internal/chat/domain"
	chatrepo "github.com/shopnexus/server2/internal/chat/repository"
	chatsvc "github.com/shopnexus/server2/internal/chat/service"
	"github.com/shopnexus/server2/internal/platform/postgres/pgtest"
	"github.com/shopnexus/server2/internal/platform/restatex/restatetest"
	"github.com/shopnexus/server2/internal/trust/domain"
	"github.com/shopnexus/server2/internal/trust/repository"
	"github.com/shopnexus/server2/internal/trust/service"
)

// fakeClassifier gives a side prepayment_request when one of its lines
// says "cọc" and sensitive_info_request for "otp", and records what it read.
type fakeClassifier struct {
	mu      sync.Mutex
	windows []domain.Window
	err     error
}

func (f *fakeClassifier) Name() string       { return "fake" }
func (f *fakeClassifier) PromptVersion() int { return 0 }

func (f *fakeClassifier) Classify(_ context.Context, w domain.Window) (domain.Verdict, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.windows = append(f.windows, w)
	if f.err != nil {
		return domain.Verdict{}, f.err
	}
	v := domain.Verdict{A: []domain.Code{}, B: []domain.Code{}}
	for _, l := range w.Lines {
		codes := &v.A
		if l.Side == domain.SideB {
			codes = &v.B
		}
		if strings.Contains(strings.ToLower(l.Text), "cọc") {
			*codes = append(*codes, domain.CodePrepayment)
		}
		if strings.Contains(strings.ToLower(l.Text), "otp") {
			*codes = append(*codes, domain.CodeSensitive, "made_up")
		}
	}
	return v, nil
}

func (f *fakeClassifier) seen() []domain.Window {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]domain.Window{}, f.windows...)
}

// fakeFacts tells new_account for every suspect, or fails.
type fakeFacts struct{ err error }

func (f fakeFacts) Signals(_ context.Context, _ uuid.UUID, _ domain.Window, now time.Time) ([]domain.Signal, error) {
	if f.err != nil {
		return nil, f.err
	}
	s, _ := domain.NewAccountSignal(now.Add(-time.Hour), now)
	return []domain.Signal{s}, nil
}

type checkEnv struct {
	db     *pgxpool.Pool
	chats  chatrepo.Chats
	scams  repository.ScamWarnings
	model  *fakeClassifier
	client *ingress.Client
	prefix string
	c      chatdomain.Conversation
}

func newCheckEnv(t *testing.T, facts service.FactSource) checkEnv {
	t.Helper()
	db := pgtest.New(t)
	chats := chatrepo.NewChats(db)
	model := &fakeClassifier{}
	prefix := restatetest.Prefix()
	trust := service.New(service.Deps{
		Scams: repository.NewScamWarnings(db), Chats: chatsvc.New(chatsvc.Deps{Chats: chats, Now: time.Now}),
		Classifier: model, Facts: []service.FactSource{facts}, Log: slog.New(slog.DiscardHandler), Prefix: prefix, Now: time.Now,
	})
	client := restatetest.Start(t, trust.Durable()...)
	c, err := chats.OpenPair(context.Background(), chatdomain.NewConversation(uuid.NewV7(), accounttest.New(t, db), accounttest.New(t, db), time.Now()))
	if err != nil {
		t.Fatal(err)
	}
	return checkEnv{db: db, chats: chats, scams: repository.NewScamWarnings(db), model: model, client: client, prefix: prefix, c: c}
}

func (e checkEnv) say(t *testing.T, sender uuid.UUID, text string) chatdomain.Message {
	t.Helper()
	m, err := chatdomain.NewMessage(uuid.NewV7(), e.c.ID, sender, text, nil, nil, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if err = e.chats.AddMessage(context.Background(), m); err != nil {
		t.Fatal(err)
	}
	return m
}

func (e checkEnv) run(t *testing.T) {
	t.Helper()
	if _, err := ingress.Object[restate.Void, restate.Void](e.client, e.prefix+service.ScamCheckName, e.c.ID.String(), "Run").
		Request(context.Background(), restate.Void{}); err != nil {
		t.Fatal(err)
	}
}

func (e checkEnv) checks(t *testing.T) int {
	t.Helper()
	var n int
	if err := e.db.QueryRow(context.Background(), `SELECT count(*) FROM scam_checks WHERE conversation_id = @c`,
		pgx.StrictNamedArgs{"c": e.c.ID}).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

// The suspect's codes warn the other member, with the facts and redacted
// lines; a run with nothing new reads nothing.
func TestScamCheckWarnsTheOtherMember(t *testing.T) {
	t.Parallel()
	e := newCheckEnv(t, fakeFacts{})
	e.say(t, e.c.AccountB, "Còn không bạn?")
	e.say(t, e.c.AccountA, "Còn, chuyển cọc vào 0912 345 678 nhé")
	e.run(t)
	w, err := e.scams.Get(context.Background(), e.c.ID, e.c.AccountB)
	if err != nil || w.SuspectID() != e.c.AccountA || len(w.Signals()) != 2 ||
		w.Signals()[0].Code != domain.CodePrepayment || w.Signals()[1].Code != domain.CodeNewAccount {
		t.Fatalf("%+v %v", w.State(), err)
	}
	if _, err = e.scams.Get(context.Background(), e.c.ID, e.c.AccountA); !errors.Is(err, repository.ErrNotFound) {
		t.Fatalf("the suspect is warned: %v", err)
	}
	seen := e.model.seen()
	if len(seen) != 1 || len(seen[0].Lines) != 2 || seen[0].Lines[1].Text != "Còn, chuyển cọc vào <PHONE> nhé" ||
		seen[0].Lines[1].Side != domain.SideA {
		t.Fatalf("read %+v", seen)
	}
	e.run(t)
	if len(e.model.seen()) != 1 || e.checks(t) != 1 {
		t.Fatalf("a second run read again: %d checks", e.checks(t))
	}
}

// Without a message code nothing is raised, but the check is recorded.
func TestScamCheckFactsAloneRaiseNothing(t *testing.T) {
	t.Parallel()
	e := newCheckEnv(t, fakeFacts{})
	e.say(t, e.c.AccountA, "Xe còn bạn ơi")
	e.run(t)
	if _, err := e.scams.Get(context.Background(), e.c.ID, e.c.AccountB); !errors.Is(err, repository.ErrNotFound) {
		t.Fatalf("raised: %v", err)
	}
	if e.checks(t) != 1 {
		t.Fatalf("%d checks", e.checks(t))
	}
}

func TestScamCheckRunsAgainForANewMessage(t *testing.T) {
	t.Parallel()
	e := newCheckEnv(t, fakeFacts{})
	e.say(t, e.c.AccountA, "Chuyển cọc trước nhé")
	e.run(t)
	e.say(t, e.c.AccountA, "Gửi mình mã OTP")
	e.run(t)
	w, _ := e.scams.Get(context.Background(), e.c.ID, e.c.AccountB)
	if seen := e.model.seen(); len(seen) != 2 || len(seen[1].Lines) != 2 || len(w.Signals()) != 3 ||
		w.Signals()[2].Code != domain.CodeSensitive {
		t.Fatalf("read %d windows, signals %+v", len(seen), w.Signals())
	}
}

// A dismissal made between two checks survives the second, and the new
// code undoes it.
func TestScamCheckKeepsADismissal(t *testing.T) {
	t.Parallel()
	e := newCheckEnv(t, fakeFacts{})
	e.say(t, e.c.AccountA, "Chuyển cọc trước nhé")
	e.run(t)
	w, _ := e.scams.Get(context.Background(), e.c.ID, e.c.AccountB)
	w.Dismiss(time.Now())
	if err := e.scams.Save(context.Background(), &w, uuid.NewV7()); err != nil {
		t.Fatal(err)
	}
	e.say(t, e.c.AccountA, "Cọc đi bạn")
	e.run(t)
	if got, _ := e.scams.Get(context.Background(), e.c.ID, e.c.AccountB); !got.Dismissed() || got.DismissedAt() == nil {
		t.Fatalf("the same code undid the dismissal: %+v", got.State())
	}
	e.say(t, e.c.AccountA, "Gửi mình mã OTP")
	e.run(t)
	if got, _ := e.scams.Get(context.Background(), e.c.ID, e.c.AccountB); got.Dismissed() {
		t.Fatalf("a new code kept it dismissed: %+v", got.State())
	}
}

func TestScamCheckCap(t *testing.T) {
	t.Parallel()
	e := newCheckEnv(t, fakeFacts{})
	for range domain.ChecksPerDay {
		if _, err := e.db.Exec(context.Background(), `INSERT INTO scam_checks (id, conversation_id, first_message_id, last_message_id,
    classifier, prompt_version, codes_a, codes_b, created_at) VALUES (@id, @c, @id, @id, 'fake', 0, '{}', '{}', now())`,
			pgx.StrictNamedArgs{"id": uuid.NewV7(), "c": e.c.ID}); err != nil {
			t.Fatal(err)
		}
	}
	e.say(t, e.c.AccountA, "Chuyển cọc trước nhé")
	e.run(t)
	if len(e.model.seen()) != 0 {
		t.Fatal("the capped conversation was read")
	}
}

func TestScamCheckRefused(t *testing.T) {
	t.Parallel()
	e := newCheckEnv(t, fakeFacts{})
	e.model.err = service.ErrRefused
	e.say(t, e.c.AccountA, "Chuyển cọc trước nhé")
	e.run(t)
	if len(e.model.seen()) != 1 || e.checks(t) != 0 {
		t.Fatalf("read %d times, %d checks", len(e.model.seen()), e.checks(t))
	}
}

func TestScamCheckFactSourceFails(t *testing.T) {
	t.Parallel()
	e := newCheckEnv(t, fakeFacts{err: errors.New("catalog down")})
	e.say(t, e.c.AccountA, "Chuyển cọc trước nhé")
	e.run(t)
	if w, err := e.scams.Get(context.Background(), e.c.ID, e.c.AccountB); err != nil || len(w.Signals()) != 1 {
		t.Fatalf("%+v %v", w.State(), err)
	}
}
```

`TestScamCheckRunsAgainForANewMessage` also covers `Verdict.Clean`: the fake answers `made_up` beside `sensitive_info_request`, and only three signals land. Set `e.model.err` before any run: the fake reads it under its lock, and the test sets it before the Restate handler can run.

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./internal/trust/service/ -run TestScamCheck`
Expected: build failure, `trust.Durable undefined`, `undefined: service.ScamCheckName`.

- [ ] **Step 3: Write the Virtual Object**

`internal/trust/service/scam_check_durable.go`:

```go
package service

import (
	"errors"
	"fmt"
	"log/slog"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"

	chatsvc "github.com/shopnexus/server2/internal/chat/service"
	"github.com/shopnexus/server2/internal/platform/restatex"
	"github.com/shopnexus/server2/internal/trust/domain"
	"github.com/shopnexus/server2/internal/trust/repository"
)

// ScamCheckName is the ScamCheck object's name without the prefix; trust's
// worker sends to it.
const ScamCheckName = "ScamCheck"

const (
	// classifyRetry and classifyAttempts bound the classify step; past
	// them the check is skipped.
	classifyRetry    = 10 * time.Minute
	classifyAttempts = 3
)

// ScamCheck reads a conversation's newest messages for scams. It is a
// Virtual Object keyed by the conversation ID: Restate runs one Run per
// conversation at a time, so a burst of messages queues and a later run
// finds its window checked already.
type ScamCheck struct {
	Prefix     string
	Chats      chatsvc.Service
	Scams      repository.ScamWarnings
	Classifier Classifier
	Facts      []FactSource
	Log        *slog.Logger
	Now        func() time.Time
}

func (s ScamCheck) ServiceName() string { return s.Prefix + ScamCheckName }

// checkPlan is what the plan step found: whether to run, the members, and
// the window's first and last message.
type checkPlan struct {
	Run      bool      `json:"run"`
	AccountA uuid.UUID `json:"account_a"`
	AccountB uuid.UUID `json:"account_b"`
	First    uuid.UUID `json:"first"`
	Last     uuid.UUID `json:"last"`
}

// checkVerdict is the classify step's answer, codes only.
type checkVerdict struct {
	Refused bool           `json:"refused"`
	Verdict domain.Verdict `json:"verdict"`
}

// checkFacts are the fact signals of each side that has a message code.
type checkFacts struct {
	A []domain.Signal `json:"a"`
	B []domain.Signal `json:"b"`
}

// window reads conversation's window up to last and redacts it, marking
// each line with its sender's side.
func (s ScamCheck) window(rc restate.RunContext, conversation, last uuid.UUID) (domain.Window, error) {
	w, _, err := s.Chats.Window(rc, conversation, last, domain.WindowSize)
	if err != nil {
		return domain.Window{}, fmt.Errorf("read the window: %w", err)
	}
	out := domain.Window{Lines: make([]domain.Line, 0, len(w.Lines))}
	for _, l := range w.Lines {
		side := domain.SideA
		if l.SenderID == w.AccountB {
			side = domain.SideB
		}
		out.Lines = append(out.Lines, domain.Line{MessageID: l.ID, Side: side, Text: domain.Redact(l.Text), ListingID: l.ListingID})
	}
	return out, nil
}

// Run plans, classifies, gathers facts and saves, each in a step. No step
// returns message text. A refusal, or a classify step that runs out of
// retries, skips the check; nothing here fails a message.
func (s ScamCheck) Run(ctx restate.ObjectContext) error {
	conversation, err := uuid.Parse(restate.Key(ctx))
	if err != nil {
		//nolint:wrapcheck // Restate must receive the terminal error itself
		return restate.TerminalErrorf("conversation key %q: %v", restate.Key(ctx), err)
	}
	at, err := restatex.Now(ctx, s.Now)
	if err != nil {
		return err
	}
	plan, err := restate.Run(ctx, func(rc restate.RunContext) (checkPlan, error) {
		w, found, stepErr := s.Chats.Window(rc, conversation, uuid.UUID{}, domain.WindowSize)
		if stepErr != nil {
			return checkPlan{}, fmt.Errorf("read the window: %w", stepErr)
		}
		if !found || len(w.Lines) == 0 {
			return checkPlan{}, nil
		}
		newest := w.Lines[len(w.Lines)-1].ID
		last, count, stepErr := s.Scams.Checked(rc, conversation, at.Add(-24*time.Hour))
		if stepErr != nil {
			return checkPlan{}, fmt.Errorf("read the checks: %w", stepErr)
		}
		if last == newest {
			return checkPlan{}, nil
		}
		if count >= domain.ChecksPerDay {
			s.Log.InfoContext(rc, "scam checks capped for the day", "conversation", conversation, "checks", count)
			return checkPlan{}, nil
		}
		return checkPlan{Run: true, AccountA: w.AccountA, AccountB: w.AccountB, First: w.Lines[0].ID, Last: newest}, nil
	})
	if err != nil {
		return fmt.Errorf("plan the check: %w", err)
	}
	if !plan.Run {
		return nil
	}

	verdict, err := restate.Run(ctx, func(rc restate.RunContext) (checkVerdict, error) {
		w, stepErr := s.window(rc, conversation, plan.Last)
		if stepErr != nil {
			return checkVerdict{}, stepErr
		}
		v, stepErr := s.Classifier.Classify(rc, w)
		if errors.Is(stepErr, ErrRefused) {
			s.Log.ErrorContext(rc, "the classifier refused a scam check", "conversation", conversation, "err", stepErr)
			return checkVerdict{Refused: true}, nil
		}
		if stepErr != nil {
			return checkVerdict{}, fmt.Errorf("classify: %w", stepErr)
		}
		v, dropped := v.Clean()
		if dropped > 0 {
			s.Log.WarnContext(rc, "the classifier gave codes outside the list", "conversation", conversation, "dropped", dropped)
		}
		return checkVerdict{Verdict: v}, nil
	}, restate.WithMaxRetryDuration(classifyRetry), restate.WithMaxRetryAttempts(classifyAttempts))
	if err != nil {
		s.Log.ErrorContext(ctx, "a scam check gave up", "conversation", conversation, "err", err)
		return nil
	}
	if verdict.Refused {
		return nil
	}

	v := verdict.Verdict
	facts, err := restate.Run(ctx, func(rc restate.RunContext) (checkFacts, error) {
		var out checkFacts
		if len(v.A) == 0 && len(v.B) == 0 {
			return out, nil
		}
		w, stepErr := s.window(rc, conversation, plan.Last)
		if stepErr != nil {
			return checkFacts{}, stepErr
		}
		for _, side := range []struct {
			codes   []domain.Code
			suspect uuid.UUID
			into    *[]domain.Signal
		}{{v.A, plan.AccountA, &out.A}, {v.B, plan.AccountB, &out.B}} {
			if len(side.codes) == 0 {
				continue
			}
			for _, f := range s.Facts {
				signals, factErr := f.Signals(rc, side.suspect, w, at)
				if factErr != nil {
					s.Log.WarnContext(rc, "a fact source failed; its signals are left out", "conversation", conversation, "err", factErr)
					continue
				}
				*side.into = append(*side.into, signals...)
			}
		}
		return out, nil
	})
	if err != nil {
		return fmt.Errorf("gather facts: %w", err)
	}

	checkID, writeA, writeB := restatex.NewID(ctx, at), restatex.NewID(ctx, at), restatex.NewID(ctx, at)
	if err = restate.RunVoid(ctx, func(rc restate.RunContext) error {
		var writes []repository.WarningWrite
		for _, side := range []struct {
			codes            []domain.Code
			facts            []domain.Signal
			suspect, warned  uuid.UUID
			writeID          uuid.UUID
		}{
			{v.A, facts.A, plan.AccountA, plan.AccountB, writeA},
			{v.B, facts.B, plan.AccountB, plan.AccountA, writeB},
		} {
			if len(side.codes) == 0 {
				continue
			}
			w, getErr := s.Scams.Get(rc, conversation, side.warned)
			if errors.Is(getErr, repository.ErrNotFound) {
				w, getErr = domain.NewWarning(conversation, side.warned, side.suspect), nil
			}
			if getErr != nil {
				return fmt.Errorf("read the warning: %w", getErr)
			}
			if w.Raise(side.codes, side.facts, at) {
				writes = append(writes, repository.WarningWrite{Warning: &w, WriteID: side.writeID})
			}
		}
		return s.Scams.Record(rc, domain.Check{
			ID: checkID, ConversationID: conversation, FirstMessageID: plan.First, LastMessageID: plan.Last,
			Classifier: s.Classifier.Name(), PromptVersion: s.Classifier.PromptVersion(), A: v.A, B: v.B, CreatedAt: at,
		}, writes, at.Add(-domain.CheckRetention))
	}); err != nil {
		return fmt.Errorf("save the check: %w", err)
	}
	return nil
}
```

`window` is called by two steps, so it may be a helper. The loop variable `w` inside the save step is a new value each iteration, so `&w` points to a distinct warning per write.

In `internal/trust/service/service.go`, add (and `restate "github.com/restatedev/sdk-go"` to the imports):

```go
// Durable returns module trust's Restate services, for Mount to bind.
func (t *Trust) Durable() []restate.ServiceDefinition {
	return []restate.ServiceDefinition{restate.Reflect(ScamCheck{
		Prefix: t.prefix, Chats: t.chats, Scams: t.scams, Classifier: t.classifier, Facts: t.facts, Log: t.log, Now: t.now,
	})}
}
```

- [ ] **Step 4: Run the check tests**

Run: `go test ./internal/trust/service/ -run TestScamCheck > tmp/scam-check.txt 2>&1; tail -30 tmp/scam-check.txt`
Expected: PASS.

- [ ] **Step 5: Write the failing worker test**

`internal/trust/worker/scam_test.go`:

```go
package worker_test

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"
	"uuid"

	restate "github.com/restatedev/sdk-go"
	"github.com/restatedev/sdk-go/ingress"

	chatsvc "github.com/shopnexus/server2/internal/chat/service"
	"github.com/shopnexus/server2/internal/platform/events"
	"github.com/shopnexus/server2/internal/platform/restatex/restatetest"
	"github.com/shopnexus/server2/internal/platform/testenv"
	"github.com/shopnexus/server2/internal/trust/service"
	"github.com/shopnexus/server2/internal/trust/worker"
)

// facts answers MessageFacts from a map.
type facts struct {
	chatsvc.Service

	by map[uuid.UUID]chatsvc.MessageFacts
}

func (f facts) MessageFacts(_ context.Context, id uuid.UUID) (chatsvc.MessageFacts, bool, error) {
	m, ok := f.by[id]
	return m, ok, nil
}

// checks stands in for ScamCheck and records the conversations it runs.
type checks struct {
	prefix string
	mu     *sync.Mutex
	keys   *[]string
}

func (c checks) ServiceName() string { return c.prefix + service.ScamCheckName }

func (c checks) Run(ctx restate.ObjectContext) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	*c.keys = append(*c.keys, restate.Key(ctx))
	return nil
}

// eraser records DeleteScamWarnings.
type eraser struct {
	service.Service

	mu      *sync.Mutex
	deleted *[]uuid.UUID
}

func (e eraser) DeleteScamWarnings(_ context.Context, id uuid.UUID) error {
	e.mu.Lock()
	defer e.mu.Unlock()
	*e.deleted = append(*e.deleted, id)
	return nil
}

func TestScamWorker(t *testing.T) {
	t.Parallel()
	prefix := restatetest.Prefix()
	mu := &sync.Mutex{}
	var keys []string
	var deleted []uuid.UUID
	text, photo, conversation := uuid.NewV7(), uuid.NewV7(), uuid.NewV7()
	w := worker.ScamWorker{
		Prefix: prefix,
		Chats: facts{by: map[uuid.UUID]chatsvc.MessageFacts{
			text:  {ID: text, ConversationID: conversation, Text: "Còn không bạn?"},
			photo: {ID: photo, ConversationID: conversation, Photos: 2},
		}},
		Trust: eraser{mu: mu, deleted: &deleted},
	}
	client := restatetest.Start(t, restate.Reflect(w), restate.Reflect(checks{prefix: prefix, mu: mu, keys: &keys}))
	send := func(handler string, e events.Event) {
		t.Helper()
		if _, err := ingress.Service[events.Event, restate.Void](client, w.ServiceName(), handler).Request(context.Background(), e); err != nil {
			t.Fatal(err)
		}
	}
	for _, id := range []uuid.UUID{photo, uuid.NewV7(), text} {
		send("MessageSent", events.Event{ID: uuid.NewV7(), Kind: events.MessageSent, SubjectID: id, OccurredAt: time.Now()})
	}
	gone := uuid.NewV7()
	send("AccountDeleted", events.Event{ID: uuid.NewV7(), Kind: events.AccountDeleted, SubjectID: gone, OccurredAt: time.Now()})
	testenv.Eventually(t, 10*time.Second, func() error {
		mu.Lock()
		defer mu.Unlock()
		if len(keys) != 1 || keys[0] != conversation.String() {
			return fmt.Errorf("checks ran for %v", keys)
		}
		return nil
	})
	mu.Lock()
	defer mu.Unlock()
	if len(deleted) != 1 || deleted[0] != gone {
		t.Fatalf("deleted %v", deleted)
	}
}
```

Only the text message sends a check: the photo-only message and the unknown one do not.

- [ ] **Step 6: Write the worker**

`internal/trust/worker/scam.go`:

```go
// Package worker holds module trust's Restate handlers for the events it
// reacts to.
package worker

import (
	"fmt"
	"strings"
	"uuid"

	restate "github.com/restatedev/sdk-go"

	chatsvc "github.com/shopnexus/server2/internal/chat/service"
	"github.com/shopnexus/server2/internal/platform/events"
	"github.com/shopnexus/server2/internal/trust/service"
)

// ScamWorker starts a scam check after each message with text and deletes
// a deleted account's warnings. Mount subscribes MessageSent to
// message.sent and AccountDeleted to account.deleted.
type ScamWorker struct {
	Prefix string
	Chats  chatsvc.Service
	Trust  service.Service
}

func (w ScamWorker) ServiceName() string { return w.Prefix + "TrustScamWorker" }

// MessageSent sends ScamCheck.Run for the message's conversation. The step
// returns the conversation ID only, never the text.
func (w ScamWorker) MessageSent(ctx restate.Context, e events.Event) error {
	conversation, err := restate.Run(ctx, func(rc restate.RunContext) (uuid.UUID, error) {
		f, found, stepErr := w.Chats.MessageFacts(rc, e.SubjectID)
		if stepErr != nil {
			return uuid.UUID{}, fmt.Errorf("read message: %w", stepErr)
		}
		if !found || strings.TrimSpace(f.Text) == "" {
			return uuid.UUID{}, nil
		}
		return f.ConversationID, nil
	})
	if err != nil {
		return fmt.Errorf("read the message: %w", err)
	}
	if conversation == (uuid.UUID{}) {
		return nil
	}
	restate.ObjectSend(ctx, w.Prefix+service.ScamCheckName, conversation.String(), "Run").Send(restate.Void{})
	return nil
}

// AccountDeleted deletes the warnings of the account e names.
func (w ScamWorker) AccountDeleted(ctx restate.Context, e events.Event) error {
	if err := restate.RunVoid(ctx, func(rc restate.RunContext) error {
		return w.Trust.DeleteScamWarnings(rc, e.SubjectID)
	}); err != nil {
		return fmt.Errorf("account %s left: %w", e.SubjectID, err)
	}
	return nil
}
```

If the stdlib `uuid.UUID` does not survive the journal as a step result (the test fails with a decoding error), return a `struct{ Conversation uuid.UUID `json:"conversation"` }` instead.

- [ ] **Step 7: Mount and wire**

Replace `internal/trust/trust.go` with:

```go
// Package trust is what people can rely on about each other: the reviews
// buyers give sellers, the rating they add up to, the reports people make
// of listings and accounts, and the scam warnings of chat.
package trust

import (
	"log/slog"
	"time"

	restate "github.com/restatedev/sdk-go"

	accountsvc "github.com/shopnexus/server2/internal/account/service"
	catalogsvc "github.com/shopnexus/server2/internal/catalog/service"
	chatsvc "github.com/shopnexus/server2/internal/chat/service"
	dealsvc "github.com/shopnexus/server2/internal/deal/service"
	"github.com/shopnexus/server2/internal/platform/events"
	"github.com/shopnexus/server2/internal/platform/module"
	"github.com/shopnexus/server2/internal/provider/llm"
	"github.com/shopnexus/server2/internal/trust/handler"
	"github.com/shopnexus/server2/internal/trust/repository"
	"github.com/shopnexus/server2/internal/trust/service"
	"github.com/shopnexus/server2/internal/trust/worker"
)

// Settings is what trust's Mount takes beyond module.Deps: the scam
// classifier, and search's cosine floors for the price signal.
type Settings struct {
	Classifier        service.Classifier
	TextMin, PhotoMin float64
}

// LLMClassifier is the scam classifier that asks model under alias, each
// call within timeout. A trained model gets a constructor of its own here,
// and app passes it instead.
func LLMClassifier(model llm.Client, alias string, timeout time.Duration, log *slog.Logger) service.Classifier {
	return service.LLMClassifier{Model: model, Alias: alias, Timeout: timeout, Log: log}
}

// Mount registers the trust endpoints, subscribes the scam worker to
// message.sent and account.deleted, and returns trust's Restate services and
// the Service screen reads ratings, reviews and warnings through.
func Mount(d module.Deps, s Settings, accounts accountsvc.Service, catalog catalogsvc.Service, deals dealsvc.Service,
	chats chatsvc.Service,
) module.Mounted[service.Service] {
	svc := service.New(service.Deps{
		Reviews: repository.NewReviews(d.Pool), Reports: repository.NewReports(d.Pool), Scams: repository.NewScamWarnings(d.Pool),
		Accounts: accounts, Catalog: catalog, Deals: deals, Chats: chats, Classifier: s.Classifier,
		Facts: []service.FactSource{
			service.AccountAge{Accounts: accounts},
			service.MarketGap{Catalog: catalog, TextMin: s.TextMin, PhotoMin: s.PhotoMin},
		},
		Log: d.Log, Prefix: d.ServicePrefix, Now: d.Now,
	})
	handler.New(svc, d.Log).Register(d.Router, d.Protect)
	w := worker.ScamWorker{Prefix: d.ServicePrefix, Chats: chats, Trust: svc}
	d.Events.Subscribe(events.MessageSent, w.ServiceName(), "MessageSent")
	d.Events.Subscribe(events.AccountDeleted, w.ServiceName(), "AccountDeleted")
	return module.Mounted[service.Service]{Services: append(svc.Durable(), restate.Reflect(w)), Service: svc}
}
```

In `internal/app/app.go`:

```go
	trustm := trust.Mount(d, trust.Settings{
		Classifier: trust.LLMClassifier(
			llm.OpenAI{BaseURL: cfg.Trust.LLMBaseURL, APIKey: cfg.Trust.LLMAPIKey, Model: cfg.Trust.LLMModel, HTTP: &http.Client{}},
			cfg.Trust.LLMModel, cfg.Trust.CallTimeout, log),
		TextMin: cfg.Embed.TextMinSimilarity, PhotoMin: cfg.Embed.PhotoMinSimilarity,
	}, accounts, catalogm.Service, dealm.Service, chatm.Service)
```

Use the logger variable `app.go` already passes to `stream.Socket` (`log`). Then change `trustm` to `trustm.Service` in the `notification.Mount` and `screen.Mount` calls, and add `trustm.Services` to the final `slices.Concat`.

Run `make depguard` so `.golangci.yml` lists `internal/trust/worker`.

- [ ] **Step 8: Run the tests and lint**

```bash
go test ./internal/trust/... ./internal/app/... > tmp/trust.txt 2>&1; tail -30 tmp/trust.txt
golangci-lint run ./... > tmp/lint.txt 2>&1; tail -30 tmp/lint.txt
```

Expected: PASS and no lint findings. `internal/app` tests that build the app from a config need `Trust` set; give them `config.TrustConfig{LLMBaseURL: "http://127.0.0.1:1", LLMAPIKey: "x", LLMModel: "x", CallTimeout: time.Second}` where they set `Assist`.

- [ ] **Step 9: Commit**

```bash
git add internal/trust internal/app .golangci.yml
git commit -F tmp/commit.txt
```

```
feat(trust): ScamCheck after every message with text, mounted

The worker hears message.sent and sends ScamCheck.Run, a Virtual Object
keyed by conversation. Run plans, classifies, gathers facts and saves in
four steps that return no text; a refusal or a classify step out of
retries skips the check. account.deleted deletes the account's own
warnings.
```

---

### Task 8: API, the dismiss route, the views and end to end

**Files:**
- Modify: `api/schemas/trust.yaml`, `api/schemas/screen_inbox.yaml`, `api/schemas/stream.yaml`, `api/paths/trust.yaml`, `api/openapi.yaml`
- Modify: `internal/trust/handler/handler.go`; Create: `internal/trust/handler/scam.go`
- Modify: `internal/screen/service/inbox.go`, `internal/screen/service/inbox_search.go`, `internal/screen/service/chat.go`
- Create: `e2e/scam_stub_test.go`, `e2e/scam_test.go`; Modify: `e2e/main_test.go`, `e2e/screen_inbox_test.go`

**Interfaces:**
- Consumes: `trustsvc.Service.ScamWarnings`, `DismissScamWarning`; `config.TrustConfig`.
- Produces: `POST /v1/conversations/{id}/scam-warning/dismiss` (operationId `dismissScamWarning`), `scam_warning` on `InboxItem` and `ChatScreen`, stream kind `scam_warning`.

- [ ] **Step 1: The contract**

`api/schemas/trust.yaml`, at the end:

```yaml
ScamWarning:
  type: object
  additionalProperties: false
  required: [signals, dismissed]
  description: What the caller is told about the other member of a conversation; that member never sees it.
  properties:
    signals:
      type: array
      description: Oldest first; at least one is a message code.
      items:
        $ref: "#/ScamSignal"
    dismissed:
      type: boolean
      description: |
        True while no message code has appeared since the caller last
        dismissed the warning. The inbox shows the warning either way; Chat
        shows its banner only when this is false.
ScamSignal:
  type: object
  additionalProperties: false
  required: [code, text]
  properties:
    code:
      type: string
      description: |
        prepayment_request, off_app_contact, suspicious_link,
        sensitive_info_request, impersonation, fake_payment_proof, pressure,
        new_account or price_far_below. More may come; the app shows an
        unknown code with the Info icon.
    text:
      type: string
      description: Vietnamese, written by the server, as "Tài khoản mới tạo 2 ngày".
```

`api/schemas/screen_inbox.yaml`: in `InboxItem.properties`, after `other_active_deals`, and in `ChatScreen.properties`, after `messages`:

```yaml
    scam_warning:
      $ref: "trust.yaml#/ScamWarning"
```

Add one sentence to `InboxItem.description`: "scam_warning is absent when the caller has no warning in the conversation."

`api/schemas/stream.yaml`: `enum: [message, read, deal, notification, video_read, scam_warning]`.

`api/paths/trust.yaml`, at the end:

```yaml
scamWarningDismiss:
  post:
    operationId: dismissScamWarning
    summary: Dismiss the caller's scam warning in a conversation.
    description: |
      The warning stays in the inbox with dismissed true, and Chat hides its
      banner, until a check finds a message code it did not have. Without a
      warning, or dismissed already, nothing changes. A member who blocks
      the other may dismiss.
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
        description: Dismissed, or nothing to dismiss.
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

`api/openapi.yaml`, after `/v1/conversations/{id}/unarchive`:

```yaml
  /v1/conversations/{id}/scam-warning/dismiss:
    $ref: "paths/trust.yaml#/scamWarningDismiss"
```

Check that `try_again` (409) does not need declaring: the dismiss answers it only after two lost races in a row, which no test can make happen on demand, and the status-coverage check in `e2e/main_test.go` would then fail on it. Leave 409 out of the spec, as `markConversationUnread` does.

Run: `go test ./api/`
Expected: PASS.

- [ ] **Step 2: The route**

In `internal/trust/handler/handler.go` `Register`, after the reports:

```go
	r.Handle("POST /v1/conversations/{id}/scam-warning/dismiss", protect(http.HandlerFunc(h.DismissScamWarning)))
```

and update its comment to "a seller's reviews are public; reports and scam warnings need a signed-in caller."

`internal/trust/handler/scam.go`:

```go
package handler

import (
	"net/http"
	"uuid"

	"github.com/shopnexus/server2/internal/platform/httpx"
)

type conversationRequest struct {
	ID uuid.UUID `json:"-" path:"id"`
}

// DismissScamWarning serves POST /v1/conversations/{id}/scam-warning/dismiss.
func (h *Handler) DismissScamWarning(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	var in conversationRequest
	if err := httpx.Bind(r, &in); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	if err := h.svc.DismissScamWarning(r.Context(), p.AccountID, in.ID); err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
```

Run: `go test ./internal/app/ -run TestRoutesMatchSpec`
Expected: PASS.

- [ ] **Step 3: The views**

`internal/screen/service/inbox.go`: add the field to `InboxItem` (import `trustsvc "github.com/shopnexus/server2/internal/trust/service"`):

```go
	ScamWarning      *trustsvc.ScamWarningView `json:"scam_warning,omitempty"`
```

In `Inbox`, after reading `deals`, read the warnings and set them in the loop:

```go
	ids := make([]uuid.UUID, 0, len(conversations.Items))
	for i := range conversations.Items {
		ids = append(ids, conversations.Items[i].ID)
	}
	warnings, err := s.trust.ScamWarnings(ctx, account, ids)
	if err != nil {
		return InboxScreen{}, fmt.Errorf("read scam warnings: %w", err)
	}
```

and inside the loop that builds `items`:

```go
		if w, ok := warnings[item.ID]; ok {
			item.ScamWarning = &w
		}
```

Collect `ids` in the same loop that collects `others` rather than in a second loop. Do the same in `inbox_search.go` for `found.Threads`. Update the `Inbox` comment to "…the deals of their pairs, the caller's scam warnings and unread count, one call each."

`internal/screen/service/chat.go`: add to `ChatScreen`

```go
	ScamWarning *trustsvc.ScamWarningView `json:"scam_warning,omitempty"`
```

and in `Chat`, after the messages:

```go
	warnings, err := s.trust.ScamWarnings(ctx, account, []uuid.UUID{conversation})
	if err != nil {
		return ChatScreen{}, fmt.Errorf("read the scam warning: %w", err)
	}
	out := ChatScreen{ConversationView: conv, Deals: deals, Messages: messages}
	if w, ok := warnings[conversation]; ok {
		out.ScamWarning = &w
	}
	return out, nil
```

- [ ] **Step 4: The e2e stub and wiring**

`e2e/scam_stub_test.go`:

```go
package e2e

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
)

// scamWords are the words the scam-check stub answers a code for.
var scamWords = map[string]string{"cọc": "prepayment_request", "zalo": "off_app_contact", "otp": "sensitive_info_request"}

// stubScam stands in for the scam-check model: each side's codes come from
// the words in its lines, "A: text" or "B: text".
type stubScam struct{ srv *httptest.Server }

func newScam() *stubScam {
	s := &stubScam{}
	s.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req struct {
			Messages []struct {
				Content string `json:"content"`
			} `json:"messages"`
		}
		if r.URL.Path != "/chat/completions" || json.NewDecoder(r.Body).Decode(&req) != nil || len(req.Messages) != 2 {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		codes := map[string][]string{"a": {}, "b": {}}
		for _, line := range strings.Split(req.Messages[1].Content, "\n") {
			side, text, ok := strings.Cut(line, ": ")
			if !ok {
				continue
			}
			side = strings.ToLower(side)
			for word, code := range scamWords {
				if strings.Contains(strings.ToLower(text), word) && !slices.Contains(codes[side], code) {
					codes[side] = append(codes[side], code)
				}
			}
		}
		answer, _ := json.Marshal(codes)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"choices": []map[string]any{{"message": map[string]string{"content": string(answer)}}},
		})
	}))
	return s
}

func (s *stubScam) url() string { return s.srv.URL }
```

In `e2e/main_test.go`: in the `var` block beside `assistStub = newAssist()`, add `scamStub = newScam() // the scam-check model`; in `cfg`, after `Assist:`, add

```go
		Trust: config.TrustConfig{LLMBaseURL: scamStub.url(), LLMAPIKey: "e2e", LLMModel: "e2e", CallTimeout: 5 * time.Second},
```

The other stubs are not closed; this one is not either.

In `e2e/screen_inbox_test.go`, add to both `inboxRow` and `chatScreen`:

```go
	ScamWarning *scamWarning `json:"scam_warning"`
```

and the type:

```go
type scamWarning struct {
	Signals []struct {
		Code string `json:"code"`
		Text string `json:"text"`
	} `json:"signals"`
	Dismissed bool `json:"dismissed"`
}

// codes lists a warning's codes.
func (w *scamWarning) codes() []string {
	out := []string{}
	for _, s := range w.Signals {
		out = append(out, s.Code)
	}
	return out
}
```

- [ ] **Step 5: Write the e2e test**

`e2e/scam_test.go`:

```go
package e2e

import (
	"errors"
	"fmt"
	"net/http"
	"slices"
	"testing"
	"time"

	"github.com/shopnexus/server2/internal/platform/testenv"
)

func TestScamWarning(t *testing.T) {
	t.Parallel()
	seller, _ := newAccount(t)
	buyer, _ := newAccount(t)
	c := openChat(t, buyer.AccessToken, activeListing(t, seller.AccessToken, nil).ID, "Xe còn không bạn?")
	sendChat(t, seller.AccessToken, c.ID, map[string]any{"text": "Còn bạn, chuyển cọc qua Zalo mình giữ xe nhé"})

	var row inboxRow
	testenv.Eventually(t, 30*time.Second, func() error {
		if row = inboxRows(t, buyer.AccessToken)[seller.Account.ID]; row.ScamWarning == nil {
			return errors.New("no warning yet")
		}
		return nil
	})
	got := row.ScamWarning.codes()
	for _, want := range []string{"prepayment_request", "off_app_contact", "new_account"} {
		if !slices.Contains(got, want) {
			t.Fatalf("codes %v lack %s", got, want)
		}
	}
	if row.ScamWarning.Dismissed || row.ScamWarning.Signals[0].Text == "" {
		t.Fatalf("%+v", row.ScamWarning)
	}
	chatPath := "/v1/screens/chat/" + c.ID
	if v := expect[chatScreen](t, call(t, "GET", chatPath, nil, bearer(buyer.AccessToken)), http.StatusOK); v.ScamWarning == nil ||
		v.ScamWarning.Dismissed {
		t.Fatalf("chat: %+v", v.ScamWarning)
	}
	if theirs := inboxRows(t, seller.AccessToken)[buyer.Account.ID]; theirs.ScamWarning != nil {
		t.Fatalf("the suspect sees %+v", theirs.ScamWarning)
	}

	path := "/v1/conversations/" + c.ID + "/scam-warning/dismiss"
	check(t, "dismiss", call(t, "POST", path, nil, bearer(buyer.AccessToken)), 204, "")
	check(t, "dismiss again", call(t, "POST", path, nil, bearer(buyer.AccessToken)), 204, "")
	if v := expect[chatScreen](t, call(t, "GET", chatPath, nil, bearer(buyer.AccessToken)), http.StatusOK); !v.ScamWarning.Dismissed {
		t.Fatalf("after the dismissal: %+v", v.ScamWarning)
	}
	if r := inboxRows(t, buyer.AccessToken)[seller.Account.ID]; r.ScamWarning == nil || !r.ScamWarning.Dismissed {
		t.Fatalf("the inbox keeps the warning, dismissed: %+v", r.ScamWarning)
	}

	sendChat(t, seller.AccessToken, c.ID, map[string]any{"text": "Gửi mình mã OTP để xác nhận đơn"})
	testenv.Eventually(t, 30*time.Second, func() error {
		v := expect[chatScreen](t, call(t, "GET", chatPath, nil, bearer(buyer.AccessToken)), http.StatusOK)
		if v.ScamWarning.Dismissed || !slices.Contains(v.ScamWarning.codes(), "sensitive_info_request") {
			return fmt.Errorf("still %+v", v.ScamWarning)
		}
		return nil
	})

	check(t, "dismiss without a warning", call(t, "POST", path, nil, bearer(seller.AccessToken)), 204, "")
	check(t, "dismiss signed out", call(t, "POST", path, nil), 401, "unauthenticated")
	check(t, "dismiss a bad id", call(t, "POST", "/v1/conversations/x/scam-warning/dismiss", nil, bearer(buyer.AccessToken)), 400, "")
	stranger, _ := newAccount(t)
	check(t, "dismiss someone else's", call(t, "POST", path, nil, bearer(stranger.AccessToken)), 404, "conversation_not_found")
}
```

Check the field names of `signIn` (`AccessToken`, `Account.ID`) and of `inboxRows`' key (the other member's ID) in `e2e/auth_helpers_test.go` and `e2e/screen_inbox_test.go`; they are used this way in `chat_test.go`.

- [ ] **Step 6: Run the e2e tests**

```bash
go test ./e2e/ -run 'TestScamWarning|TestChat|TestScreenInbox|TestMarkConversationUnread' > tmp/e2e-scam.txt 2>&1; tail -30 tmp/e2e-scam.txt
make test > tmp/make-test.txt 2>&1; tail -40 tmp/make-test.txt
```

Expected: PASS, including the status-coverage check (`dismissScamWarning` 204, 400, 401, 404 observed) and lint.

- [ ] **Step 7: Commit**

```bash
git add api internal/trust/handler internal/screen e2e
git commit -F tmp/commit.txt
```

```
feat(trust): scam_warning in the inbox and chat views, and its dismissal

POST /v1/conversations/{id}/scam-warning/dismiss answers 204 for a member,
also one who blocks the other, and conversation_not_found for anyone else.
The e2e test runs the whole path against a stub of the scam-check model.
```

---

### Task 9: Infra: the alias scam-check and the key server-trust

**Files (umbrella `~/shopnexus`, branch `feat/scam-warning`):**
- Modify: `infra/stack/values.yaml`, `infra/stack/values-dev.yaml`, `infra/stack/values-prod.yaml`, `infra/stack/templates/_server-env.tpl`, `infra/stack/tests/litellm_test.yaml`, `infra/stack/tests/server_env_test.yaml`, `infra/cmd/seal/main.go`, `infra/cmd/seal/main_test.go`, `infra/stack/secrets/example.env`, `infra/smoke-models.hurl`, `infra/smoke-models.sh`, `infra/check.sh`

**Interfaces:**
- Consumes: Task 5's variable names.
- Produces: LiteLLM alias `scam-check`, key `server-trust` (secret `TRUST_LLM_API_KEY`), the server's `TRUST_*` in the cluster.

Commit `25c4662` made the same change for `video-read` and `server-assist`; `git show 25c4662 -- infra` shows every file and the shape of each edit.

- [ ] **Step 1: Values**

`infra/stack/values.yaml`, under `litellm.aliases` after `video-read`:

```yaml
    scam-check:
      model: openai/claude-haiku-5-5
      apiBase: http://host.k3d.internal:8317/v1   # cli-proxy-api on the host, as search
      apiKeySecret: LLM_UPSTREAM_API_KEY
      price: token
```

under `litellm.keys` after `server-assist`:

```yaml
    server-trust: { secret: TRUST_LLM_API_KEY, models: [scam-check], dailyUnits: 0, tpmLimit: 0 }   # set per stack
```

and under `server:` add, beside `assist:`:

```yaml
  trust:
    callTimeout: 20s
```

`infra/stack/values-dev.yaml`, under `litellm.keys`:

```yaml
    # About 1,300 tokens a check (the prompt and 20 short messages): 460
    # checks a day, 23 a minute.
    server-trust: { dailyUnits: 600000, tpmLimit: 30000 }
```

`infra/stack/values-prod.yaml`, under `litellm.keys`:

```yaml
    server-trust: { dailyUnits: 6000000, tpmLimit: 150000 }   # 4,600 checks a day, 115 a minute
```

- [ ] **Step 2: The server's environment**

`infra/stack/templates/_server-env.tpl`, after `ASSIST_CALL_TIMEOUT`:

```
TRUST_LLM_BASE_URL: http://litellm:4000/v1
TRUST_LLM_MODEL: scam-check
TRUST_CALL_TIMEOUT: {{ required "server.trust.callTimeout is required" .Values.server.trust.callTimeout | quote }}
```

`TRUST_LLM_API_KEY` reaches the server from `server-secrets`, as `ASSIST_LLM_API_KEY` does.

`infra/cmd/seal/main.go`: add `{"TRUST_LLM_API_KEY", "sk-", 24},   // the server's scam-check key in LiteLLM (server-trust)` after the `ASSIST_LLM_API_KEY` line, and `"TRUST_LLM_API_KEY"` after `"ASSIST_LLM_API_KEY"` in the `server-secrets` pick list. `infra/cmd/seal/main_test.go`: add `"TRUST_LLM_API_KEY"` after `"ASSIST_LLM_API_KEY"` in the list of keys it checks. `infra/stack/secrets/example.env`: add `TRUST_LLM_API_KEY (server-trust)` after `ASSIST_LLM_API_KEY (server-assist)` in the comment.

- [ ] **Step 3: Chart tests**

`infra/stack/tests/litellm_test.yaml`, after the `video-read` alias test:

```yaml
  # A scam check sends a chat window to the same upstream model, under an
  # alias of its own.
  - it: maps the alias scam-check to the upstream model at 1e-6 a token
    template: litellm.yaml
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - matchRegex: { path: 'data["config.yaml"]', pattern: "model_name: scam-check\\n    litellm_params:\\n      model: openai/claude-haiku-5-5\\n      api_base: http://host.k3d.internal:8317/v1\\n      api_key: os.environ/LLM_UPSTREAM_API_KEY" }
```

Rename the test "passes the upstream key to LiteLLM once for search and video-read" to "…for search, video-read and scam-check"; its count of 4 stays. After the `server-assist` key tests:

```yaml
  - it: gives prod's server-trust key 6M tokens a day at 150k a minute
    template: litellm-keys.yaml
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - contains:
          path: spec.template.spec.containers[0].env
          content:
            name: KEY_SERVER_TRUST
            valueFrom: { secretKeyRef: { name: server-secrets, key: TRUST_LLM_API_KEY } }
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: 'upsert server-trust "\$KEY_SERVER_TRUST"' }
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-trust","max_budget":6,"models":\["scam-check"\],"tpm_limit":150000' }
  - it: gives dev's server-trust key 600k tokens a day at 30k a minute
    template: litellm-keys.yaml
    documentIndex: 0
    values: [../values-dev.yaml, values-test.yaml]
    asserts:
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-trust","max_budget":0.6,"models":\["scam-check"\],"tpm_limit":30000' }
```

`infra/stack/tests/server_env_test.yaml`: add `exists` asserts for `data.TRUST_LLM_BASE_URL`, `data.TRUST_LLM_MODEL`, `data.TRUST_CALL_TIMEOUT` beside the `ASSIST_*` ones, and a test:

```yaml
  # A scam check calls the model through LiteLLM's alias scam-check.
  - it: sets the scam check settings
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - equal: { path: data.TRUST_LLM_BASE_URL, value: http://litellm:4000/v1 }
      - equal: { path: data.TRUST_LLM_MODEL, value: scam-check }
      - equal: { path: data.TRUST_CALL_TIMEOUT, value: 20s }
```

The `checksum/env` value in the two roll tests changes with the ConfigMap: run the chart tests once, read the new checksum from the failure, and put it in both tests.

- [ ] **Step 4: Smoke and consistency checks**

`infra/smoke-models.hurl`, after the `video-read` call:

```
# scam-check: the model answers a chat window.
POST {{litellm}}/v1/chat/completions
Authorization: Bearer {{trust_key}}
{"model": "scam-check", "messages": [{"role": "user", "content": "Reply with the word ok."}], "max_tokens": 5}
HTTP 200
```

and at the end:

```
# server-trust reaches scam-check only.
POST {{litellm}}/v1/chat/completions
Authorization: Bearer {{trust_key}}
{"model": "search", "messages": [{"role": "user", "content": "x"}], "max_tokens": 1}
HTTP 403
```

`infra/smoke-models.sh`: add `--secret trust_key="$(key TRUST_LLM_API_KEY)" \` after the `assist_key` line. `infra/check.sh`: after the `ASSIST_CALL_TIMEOUT` line,

```bash
eq "$(yq '.x-server-env.TRUST_CALL_TIMEOUT' ../docker-compose.yml)" "$(yq '.server.trust.callTimeout' stack/values.yaml)" "compose TRUST_CALL_TIMEOUT"
```

- [ ] **Step 5: Run the infra checks**

Find how the chart tests and Go tests run (`grep -n "unittest\|go test" infra/Makefile infra/check.sh`; the umbrella `Makefile` may have a target). Run the chart unit tests, `go test ./...` in `infra/`, and `infra/check.sh`. Expected: all pass after the checksum update. Do not run `smoke-models.sh`: it needs a running stack and sealed keys.

- [ ] **Step 6: Commit**

```bash
git add infra
git commit -F server/tmp/commit.txt
```

```
build: the alias scam-check and the key server-trust

LiteLLM sends scam-check to the upstream model behind search. The key
server-trust reaches it alone, 600k tokens a day in dev and 6M in prod.
seal generates TRUST_LLM_API_KEY; the stacks have to be sealed again with
it before this is pushed.
```

---

### Task 10: ARCHITECTURE.md and the checklist

**Files:**
- Modify: `~/shopnexus/server/ARCHITECTURE.md`, `~/shopnexus/checklist.md`

- [ ] **Step 1: ARCHITECTURE.md**

In the Trust section, after the reports bullets, add:

```markdown
Scam warnings are trust's too (decided 2026-11-11, spec:
`~/shopnexus/docs/superpowers/specs/2026-11-11-server2-scam-warning-design.md`).

- A signal is a fixed code: seven read from messages (`prepayment_request`,
  `off_app_contact`, `suspicious_link`, `sensitive_info_request`,
  `impersonation`, `fake_payment_proof`, `pressure`) and two computed
  from data (`new_account` under 7 days, `price_far_below` at least 30%
  under the median of 5 or more similar listings). The server writes each
  code's Vietnamese text; the API returns `{code, text}`.
- A `Classifier` picks the message codes of each side from a window of the
  last 20 messages with text, after `domain.Redact` replaced phones, bank
  and card numbers, emails and links. `LLMClassifier` asks LiteLLM's alias
  `scam-check` with the key `server-trust` under a strict schema of the
  seven codes. A trained model is another `Classifier`, built in the root
  package `trust` and passed by app as `trust.Settings.Classifier`.
- The worker hears `message.sent` and sends `ScamCheck.Run`, a Virtual
  Object keyed by conversation, for a message with text. Run's four steps
  plan, classify, gather facts and save, and return IDs and codes only.
  A window already checked, or a conversation with 50 checks in 24 hours,
  stops the run; a refusal or a classify step past 3 attempts and 10
  minutes skips it.
- `scam_warnings` holds one row per warned member, `scam_checks` one row
  per run with the window's first and last message, the classifier and the
  codes, and no text; joined with `messages`, dismissals and `scam`
  reports it is the training set. Each save deletes up to 1,000 checks
  older than 365 days.
- A warning needs a message code; fact signals join it then. Codes are
  only added. `dismissed` holds until a message code appears after the
  dismissal. `POST /v1/conversations/{id}/scam-warning/dismiss` checks
  membership through `chatsvc.Get`, so a member who blocks the other can
  dismiss. The suspect never reads a warning about themselves.
- Screen reads `trustsvc.ScamWarnings` once per page for the inbox, the
  inbox search and Chat; the stream update `scam_warning` names the
  conversation. `account.deleted` deletes the account's own warnings;
  those about it stay.
```

In the Stream section, add `scam_warning` to the list of update kinds and "trust's repository notifies the warned member at each save of a warning" after the sentence about assist.

Run `python3 ~/.claude/skills/humanizing-writing/ai-tells.py ARCHITECTURE.md` and fix every hit in the new text.

- [ ] **Step 2: The checklist**

In `~/shopnexus/checklist.md`, replace `- [ ] Cảnh báo lừa đảo trong chat (và tắt cảnh báo)` with:

```markdown
- [x] Cảnh báo lừa đảo trong chat (và tắt cảnh báo): `scam_warning {signals [{code, text}], dismissed}` trong `GET /v1/screens/inbox` và `GET /v1/screens/chat/{id}`, ẩn bằng `POST /v1/conversations/{id}/scam-warning/dismiss`; LLM đọc 20 tin gần nhất sau mỗi tin có chữ, chỉ trả mã cố định (app chưa nối; app đổi `icon` thành `code`)
```

and update the date line ("Cập nhật 11/11/2026."). Run the checker on `checklist.md`.

- [ ] **Step 3: Commit**

```bash
cd ~/shopnexus/server && git add ARCHITECTURE.md && git commit -F tmp/commit.txt
```

```
docs: scam warnings in ARCHITECTURE.md
```

```bash
cd ~/shopnexus && git add checklist.md && git commit -F server/tmp/commit.txt
```

```
docs: the scam warning item done on the server
```

Do not push either repo and do not bump the submodule pointer in the umbrella; the user decides when to merge.
