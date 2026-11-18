# server: scam warning in chat, and dismissing it

Date: 2026-11-11. Server repo: `~/shopnexus/server`. Checklist item in
`~/shopnexus/checklist.md`, section 1 "Chat & giao dịch": "Cảnh báo lừa
đảo trong chat (và tắt cảnh báo)".

## Goal

Give the Android app's existing scam warning a server behind it: the inbox
row's "Nghi lừa đảo" tag and scam sheet (`InboxRow.warning`), Chat's banner
(`ChatSide.warning`), and `InboxRepository.dismissWarning`, which both the
banner's close button and the sheet's "Vẫn mở cuộc trò chuyện" call.

The detector must be replaceable: an LLM reads the messages today, and a
model trained on ShopNexus data may replace it later without changes to
the worker, the tables, the API or the app.

Decisions taken with the user:

1. Signals are a fixed list of codes defined by the server. A detector only
   picks codes, so a trained model is a multi-label classifier over the
   same codes, and stored verdicts serve as its training data.
2. A check runs after every message with text, from either member, over the
   last 20 messages with text.
3. Fact signals (a new account, a price far below the market) exist, but
   only as supporting evidence: a warning needs at least one message
   signal, and fact signals are attached when it does.
4. After a dismissal the banner comes back when a message code appears that
   was not there at the dismissal. The inbox tag stays after a dismissal,
   as the app does today.
5. Messages are redacted before any detector reads them: phone numbers,
   bank and card numbers, email addresses and links become placeholders.
6. The API returns each signal as `{code, text}`: the server writes the
   Vietnamese text, the app picks the icon by code.
7. Architecture A: the `Classifier` and `FactSource` interfaces live in
   `trust`; the first `Classifier` uses `provider/llm`. A trained model
   later is another `Classifier`, most likely an HTTP client of `ai`.

## 1. Signals and rules

`internal/trust/domain/scam.go` holds the list. Each code has a source and
a Vietnamese text, some with parameters.

| Source | Code | Text |
|---|---|---|
| message | `prepayment_request` | Đòi chuyển tiền hoặc đặt cọc trước |
| message | `off_app_contact` | Rủ chuyển sang Zalo, Telegram, Facebook |
| message | `suspicious_link` | Gửi link lạ, giả trang thanh toán hoặc giao hàng |
| message | `sensitive_info_request` | Xin mã OTP, mật khẩu hoặc thông tin thẻ |
| message | `impersonation` | Mạo danh ShopNexus, ngân hàng hoặc hãng vận chuyển |
| message | `fake_payment_proof` | Gửi biên lai giả hoặc bảo "chuyển dư, hoàn lại giúp" |
| message | `pressure` | Hối thúc, ép quyết định ngay |
| fact | `new_account` | Tài khoản mới tạo {days} ngày |
| fact | `price_far_below` | Giá thấp hơn {percent}% so với tin tương tự |

- `new_account` holds when the suspect's account is under 7 days old.
  `days` is whole days, at least 1.
- `price_far_below` holds when the suspect's newest listing named in the
  window is priced at least 30% below the median of its price sample, and
  the sample has at least 5 listings. `percent` is rounded down to a whole
  number.
- The app's seed also shows "chưa xác minh". The server has no such fact:
  both members of a conversation have a phone, so the code is left out.

Rules, pure functions in the domain:

- The classifier reads both members' messages and returns codes for each
  side, since a buyer can scam a seller too (a fake transfer receipt).
  Member X's warning is about the other member's codes.
- A warning is raised only when the other member has at least one message
  code. Fact signals are attached at that point and at later checks that
  add a message code.
- Codes are only added, never removed. A signal keeps the `first_seen_at`
  of the check that first found it; a fact signal's parameters are those of
  that check.
- `dismissed` is true when the warning was dismissed and no message code
  has a `first_seen_at` after `dismissed_at`. A new fact code does not undo
  a dismissal. A code raised by a check whose clock was read before a
  dismissal (the dismissal landed while the model ran) is first seen a
  microsecond after the dismissal.
- Signals are listed in order of `first_seen_at`, then in the table's
  order.

## 2. Data

Migration `0036_scam_warnings.sql` (`0035` is the search watches'):

```sql
CREATE TABLE scam_warnings (
    conversation_id uuid NOT NULL REFERENCES conversations (id),
    account_id      uuid NOT NULL REFERENCES accounts (id), -- the member warned
    suspect_id      uuid NOT NULL REFERENCES accounts (id),
    signals         jsonb NOT NULL,  -- [{code, params, first_seen_at}]
    dismissed_at    timestamptz,
    updated_at      timestamptz NOT NULL,
    write_id        uuid NOT NULL,
    PRIMARY KEY (conversation_id, account_id)
);

CREATE TABLE scam_checks (
    id               uuid PRIMARY KEY,           -- UUIDv7
    conversation_id  uuid NOT NULL REFERENCES conversations (id),
    message_ids      uuid[] NOT NULL,            -- the window, oldest first
    classifier       text NOT NULL,              -- e.g. 'llm:scam-check'
    prompt_version   int NOT NULL,
    codes_a          text[] NOT NULL,            -- conversation's account_a
    codes_b          text[] NOT NULL,
    created_at       timestamptz NOT NULL
);
CREATE INDEX ON scam_checks (conversation_id, created_at DESC);
CREATE INDEX ON scam_checks (created_at);
```

- `scam_warnings` is what the app reads. Writes follow the `write_id` rule.
- `scam_checks` records every verdict and holds no message text. Joined with
  `messages` by `message_ids` it gives exactly the input the classifier
  read; joined with
  `dismissed_at` and with `reports` (`reason = 'scam'`, `conversation_id`)
  it gives labels. A future model can run in shadow and write rows with its
  own `classifier` for comparison; that is not built now.
- `scam_checks` rows older than 365 days are deleted by the save step of
  each check, at most 1,000 a run, oldest first. Checks run after every
  message with text, so the table never needs a job of its own.

## 3. Interfaces

`internal/trust/service/scam.go`:

```go
// Classifier reads a redacted window of a conversation and picks the
// message codes of each side.
type Classifier interface {
    // Name is stored in scam_checks.classifier, e.g. "llm:scam-check".
    Name() string
    // PromptVersion is stored in scam_checks.prompt_version; 0 for a
    // classifier without a prompt.
    PromptVersion() int
    Classify(ctx context.Context, w domain.Window) (domain.Verdict, error)
}

// FactSource tells which fact signals hold at now for the suspect.
type FactSource interface {
    Signals(ctx context.Context, suspect uuid.UUID, w domain.Window, now time.Time) ([]domain.Signal, error)
}

// ErrRefused is wrapped by a classifier's error when the same window would
// be refused again; the check is skipped without a retry.
var ErrRefused = errors.New("trust: the classifier refused the window")
```

- `domain.Window` is the redacted lines, oldest first; each line says
  whether side a or b sent it and the listing it names, if any.
- `domain.Verdict` is `{A, B []Code}`. Codes outside the message codes are
  dropped by the service, whatever the classifier returns, and the count
  dropped is logged at WARN.
- `domain.Redact` runs before every classifier, so a trained model gets the
  same input the LLM gets today. It replaces phone numbers (with spaces,
  dots, dashes, `+84`), runs of 8 to 19 digits (bank accounts and cards),
  email addresses and URLs with `<PHONE>`, `<BANK_NUMBER>`, `<EMAIL>` and
  `<URL:domain>`. Amounts of money ("500k", "1.200.000đ") stay, since the
  model needs them.
- Two fact sources: `accountAge` (`accountsvc.Get`, `created_at`) and
  `marketGap` (a new `catalogsvc.Service.MarketPrice(ctx, listing,
  textMin, photoMin)` that runs `PriceSample` with the listing's stored
  vectors and returns the listing's seller and price, the sample's median
  and its size; the floors are search's, `EMBED_*_MIN_SIMILARITY`).
- The first classifier, `LLMClassifier` in
  `internal/trust/service/scam_llm.go`, uses `provider/llm`. Its prompt
  explains each message code; the schema is strict,
  `{a: [enum of message codes], b: [same]}`. `PromptVersion` is 1. The log
  line holds the prompt version, the line count, the text length in
  characters, the codes and the time taken, never the text.

Replacing the LLM is a new type with `Name`, `PromptVersion` and
`Classify`. `app` imports no package inside a module, so the root package
`trust` builds each classifier (`trust.LLMClassifier(...)` today) and app
passes the result as `trust.Settings.Classifier`.

## 4. Detection flow

- `trust` gets a `worker` package. `ScamWorker.MessageSent` subscribes to
  `message.sent`, reads `chatsvc.MessageFacts` in one step, and stops when
  the message has no text. Otherwise it sends `ScamCheck.Run` one way,
  keyed by the conversation ID.
- `ScamCheck` is a Virtual Object keyed by conversation, like
  `ListingEmbed`: one `Run` per conversation at a time, so a burst of
  messages queues and later runs find nothing new. `Run` reads top to
  bottom:
  1. Step plan: `chatsvc.Service.Window(ctx, conversation, upTo, 20)` (new)
     reads the last 20 `sent` messages with text up to message `upTo` (the
     newest for the zero ID), oldest first, with sender and listing. The step
     stops when the window's message IDs equal the `message_ids` of the
     conversation's newest check, so a photo message that becomes `sent`
     after a newer message still gets a check. It also stops when the conversation had 50 checks in the
     last 24 hours. It returns IDs only to the journal.
  2. Step classify: reads exactly the planned messages, so a message sent
     or published meanwhile waits for its own run, redacts them and calls
     the classifier. It returns codes only, so message text never reaches the
     journal (as assist's fill step does with the transcript). It runs with
     `restate.WithMaxRetryDuration` of 10 minutes and at most 3 attempts.
  3. Step facts, only for a side with message codes: each fact source in
     turn. A source that fails is logged and its signals left out.
  4. Step save, one transaction: insert the `scam_checks` row; for each
     side with message codes merge into the other member's `scam_warnings`
     row by the rules of section 1; `stream.Notify` the warned member with
     `scam_warning {conversation_id}`. IDs are minted before the step with
     `restatex.NewID`; inserts use `ON CONFLICT DO NOTHING`, so a retry
     writes once.
- A check runs on a blocked pair too, since the verdict is still training
  data; the app hides the banner while it blocks.
- Sending a message is never slowed or refused by a check.

## 5. API

`api/schemas/trust.yaml`:

```yaml
ScamWarning:
  type: object
  additionalProperties: false
  required: [signals, dismissed]
  properties:
    signals:
      type: array
      description: Oldest first; at least one is a message code.
      items:
        $ref: "#/ScamSignal"
    dismissed:
      type: boolean
      description: True while no message code has appeared since the caller last dismissed the warning.
ScamSignal:
  type: object
  additionalProperties: false
  required: [code, text]
  properties:
    code:
      type: string
      description: |
        prepayment_request, off_app_contact, suspicious_link,
        sensitive_info_request, impersonation, fake_payment_proof,
        pressure, new_account or price_far_below. More may come; the app
        shows an unknown code with the Info icon.
    text:
      type: string
      description: Vietnamese, written by the server, e.g. "Tài khoản mới tạo 2 ngày".
```

`code` is a plain string, not a closed `enum`, so a new code does not break
an older app.

- `InboxItem.scam_warning` and `ChatScreen.scam_warning`, the same schema,
  absent without a warning. The inbox shows the tag and the sheet even when
  `dismissed`; Chat shows the banner only when not `dismissed`.
  `InboxSearch.threads` gets it through `InboxItem`.
- Screen reads it once per page through
  `trustsvc.Service.ScamWarnings(ctx, account, conversations []uuid.UUID)
  (map[uuid.UUID]ScamWarningView, error)`.
- `POST /v1/conversations/{id}/scam-warning/dismiss` (`api/paths/trust.yaml`,
  served by trust's handler) answers 204. It sets `dismissed_at` to now.
  Dismissing again, or a conversation without a warning, changes nothing
  and answers 204. The dismissal reads and writes the row under its lock,
  so it never answers `try_again`. Anyone but a member gets 404 `conversation_not_found`,
  checked through `chatsvc.Service.Get`, which answers that for a
  non-member and, unlike `Peer`, still answers a member who blocks or is
  blocked. A suspended account may dismiss, since it changes
  nothing anyone else sees. No `Idempotency-Key`: the call is idempotent.
  It notifies the caller's own stream with `scam_warning`, for their other
  devices.
- The suspect never sees a warning about themselves; no read returns a row
  by `suspect_id`.
- Stream: `stream.KindScamWarning = "scam_warning"`, with
  `conversation_id`. `account_updates` needs no new column.

## 6. Erasure and mounting

- `ScamWorker.AccountDeleted` on `account.deleted` deletes the
  `scam_warnings` rows whose `account_id` is the deleted account. Rows where
  it is the suspect stay, since the other member still reads the
  conversation. `scam_checks` stays: it holds no text and no name. A second
  delivery finds nothing to delete.
- `trust.Mount` takes `Settings{Classifier}` and now returns
  `module.Mounted[service.Service]` with `ScamWorker` and `ScamCheck`. App
  builds `LLMClassifier` from configuration.
- Configuration, all required: `TRUST_LLM_BASE_URL`, `TRUST_LLM_API_KEY`,
  `TRUST_LLM_MODEL`, `TRUST_CALL_TIMEOUT`. In the cluster the LiteLLM alias
  is `scam-check` and the key `server-trust`.

## 7. Errors

| Case | Result |
|---|---|
| LLM 4xx (`llm.ErrRefused`) | logged at ERROR, the check is skipped, no `scam_checks` row |
| LLM 5xx, 429, timeout | retried up to 3 times within 10 minutes, then logged and skipped |
| A code outside the message codes | dropped, count logged at WARN |
| A fact source fails | its signals left out, the warning is still saved |
| The window is empty | the run stops |
| 50 checks in 24 hours | the run stops, logged at INFO |
| A `write_id` conflict on save | the step fails and Restate retries; the retry reads again and merges |

## 8. Testing

- Domain: `Redact` (phone formats, `+84`, 8 to 19 digits, cards, email,
  URLs with their domain, amounts kept); merging (fact codes alone raise
  nothing, codes only add, `first_seen_at` kept); `dismissed` with a new
  message code and with a new fact code only; each code's text with its
  parameters.
- `LLMClassifier` against `httptest`: the schema sent holds the enum, the
  user text is redacted, `ErrRefused` comes back.
- Repository (`pgtest`): warning upsert and merge, `ON CONFLICT`, the read of
  many conversations at once, deletion by account, the stream update.
- Worker and Virtual Object (`restatetest`) with a fake classifier: a burst
  of 5 messages ends in one result; a photo-only message runs nothing; the
  50-a-day cap; a failing fact source still saves the warning;
  `account.deleted` deletes the right side only.
- E2E with the fake classifier: the seller sends "chuyển cọc qua Zalo nhé";
  the buyer sees `scam_warning` in the inbox and in Chat, the seller does
  not; dismissing gives `dismissed: true`; a new message code gives
  `dismissed: false`; a non-member's dismiss is 404.
- `api/spec_test.go` covers the new schemas and route.
- No test calls a real LLM. The prompt is tried by hand once on a few sample
  chats, scams and ordinary ones, before `PromptVersion` 1 is settled.

## Out of scope

- The app's switch to the real API: its `WarningSignal` changes from
  `{icon, text}` to `{code, text}` then, with the icon chosen by code.
- A console queue of warnings and reports.
- The trained model and shadow runs; the tables and interfaces leave room
  for both.
