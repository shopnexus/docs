# Support tickets: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A person opens a ticket (Báo chưa nhận hàng, Xin thêm hãng, Yêu cầu khác); each ticket is its own chat with ShopNexus; members answer it from the console's Hỗ trợ; every chat gains reply-by-swipe. The app follows on fake data.

**Architecture:** Module `chat` learns a second kind of conversation, `support`, between a person and the system account ShopNexus, and a quoted reply on any message. Module `support` owns tickets: it opens the chat through chat's service, records who answered, and follows `message.sent` to reopen a ticket. The console handler reaches support's service for `/v1/console/support/*`. `screen` adds the ticket to its chat screen. The app reuses its Chat screen with a ticket key.

**Tech Stack:** Go (server2: net/http, pgx, Restate SDK), Postgres 18; React 19, TanStack Query, react-router 8, Tailwind 4 (console); Kotlin, Compose, Hilt (app2).

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-13-support-tickets-design.md` (part 3 of `2026-11-12-order-flow-sync-design.md`). Mockups: app `app/.superdesign/tools/build_support.py` (drafts `support-list`, `support-chat`, `support-report`, `support-carrier`, `me-support`, `help`, `chat`), console `console/.superdesign/tools/build_support.py` (`support-open`, `support-resolved`), branch `design/support` in both repos.

## Global Constraints

- Decisions from the spec, not to be reopened: kinds `not_received | carrier_request | other`; one chat per ticket; ShopNexus is a system account with a fixed id that nobody signs in to; members answer as ShopNexus and each reply records the member; status `open | resolved`, a person's message reopens a resolved ticket; `not_received` only for the buyer, only while the order is `shipped` or `completed` by the system less than 7 days ago, one per order; `carrier_request` takes a name of 1–50 characters; closing a `carrier_request` sends "Đã ghi nhận hãng <name>."; at most 10 new tickets per account in 24 hours; feedback rows become open `other` tickets, then `feedback`, `POST /v1/feedback` and `GET /v1/console/feedback` go; support chats stay out of Tin nhắn, the inbox count and search; no scam check, archive, block or report on a support chat; reply-by-swipe in every chat.
- Server rules (`server/CLAUDE.md`): `api/` first; no configuration defaults; use cases and handlers read top to bottom; scratch output in `tmp/`; record decisions in `ARCHITECTURE.md`.
- Server test runs: recreate the whole test stack (`docker compose -f docker-compose.test.yml up -d --wait --force-recreate`, then wait for `curl -sf http://127.0.0.1:56571/health`) before each half; `go test -race -p 4 ./e2e/`; recreate; `go test -race -p 4 $(go list ./... | grep -v '/e2e$')`; `golangci-lint run ./...`. Other sessions share the stack: rerun a failed package on a fresh stack before calling a failure real (memory `shared-test-stack`).
- Worktrees off `main`, branch `feat/support`: `server/.worktrees/support`, `console/.worktrees/support-ui` (`.worktrees/support` there holds the design branch), `app/.worktrees/support-ui` (same reason). Merge the design branches `design/support` into `main` first, then branch. A server worktree runs `make env` before the test stack starts. The app's main checkout holds another session's uncommitted `.superdesign` work: never stash, commit or format there.
- App Gradle: every command starts with `. ~/.local/share/shopnexus/android-env.sh &&`; `JAVA_HOME=~/.local/opt/jdk-21`. Spotless is root-only (`./gradlew spotlessApply`). Test only touched modules, at most three modules' `check` at once. After Gradle work `./gradlew --stop` and `pgrep -fa '[G]radleDaemon|[K]otlinCompileDaemon'`. An `@Inject constructor` never has all-default parameters. A task that changes an injected class also runs `:app:hiltJavaCompileDebug`.
- Pre-existing failures on app `main`, not this plan's: 5 `VideoViewModelTest` tests; `verifyFromTheGateWalk` and `photoWalk` (camera `answer()`); `:core:ui` lint `MissingPermission` in `VideoCamera.kt`; detekt `ParameterNaming` in the camera files, `LongMethod` in `SellingJsonTest.kt`. Mockup checker: `sell`, `ship-order`, `area` fail on `main`.
- Console: `bun run lint` and `bun run build`; there is no test runner and this plan adds none (ruling below).
- Copy: Vietnamese with diacritics, the mockups' words. Commits: no `Co-Authored-By` trailer; prose (comments, `ARCHITECTURE.md`, `README.md`, commit messages) through `python3 ~/.claude/skills/humanizing-writing/ai-tells.py FILE`.

## Review Focus

1. A suspended person writes in a support chat or opens a ticket. Support is where a suspended person asks why, so both are allowed while every other send stays refused. Task 3 `TestSuspendedPersonWritesToSupport`, Task 7 `TestSuspendedPersonOpensATicket`.
2. Two taps on "Báo chưa nhận hàng" for one order, with different Idempotency-Keys. The second returns the first ticket (200), not a 409 and not a second chat. Task 6 `TestOneTicketPerOrder`, Task 7 `TestReportTwiceReturnsTheTicket`.
3. A quote of a message in another conversation, of the person's own `processing` photo message, or of a message that does not exist: 422 `invalid_message` with field `reply_to`, and nothing sent. Task 3 `TestReplyToMustBeASentMessageHere`.
4. The ShopNexus account in the console: searchable, but suspending it answers 409 `account_is_system`; account erasure never runs for it. Task 4 `TestShopNexusCannotBeSuspended`.
5. Tin nhắn after a person has tickets: the inbox, its unread count and inbox search show no support chat, and `GET /v1/me/unread` does not count ShopNexus's replies. Task 3 `TestSupportChatsStayOutOfTheInbox`, e2e `TestSupportStaysOutOfTinNhan`.

## Rulings made while planning

- `chat` must not import `support`. The ticket a chat belongs to reaches the app through `screen`'s `ChatScreen.ticket` (spec said `ConversationView.ticket`); `Person.official` on the conversation's other side is chat's own, from `accountdomain.ShopNexusID`.
- `ShopNexusID` lives in `internal/account/domain`, the module that owns accounts; chat, support and console import it.
- Support sends as ShopNexus by passing `accountdomain.ShopNexusID` as the sender of chat's `Send`; the spec's `as` parameter is not needed. Chat refuses no send from ShopNexus that it would accept from a person.
- A ticket's first message may have no text: chat's `SendInput.OpensTicket` lets a send carry neither text nor photos. Only support sets it (the HTTP binding has no such field).
- The server keeps no history of carrier reports, only the shipment's status, `shipped_at` and `delivered_at`. The console's order card shows those (the mockup's "GHTK báo" list becomes status and times).
- The console's person card shows name, id, status and joined month; the mockup's 90-day line goes (those figures live in trust's reputation, not worth a new cross-module read here).
- `orders.completed_by` (`buyer | system`) is new, backfilled from `deal_moves`; it decides the 7-day window.
- The open flow is a Restate service `TicketOpen` keyed by account and Idempotency-Key, like chat's `MessageSend`: read facts, open the chat, insert the ticket (rate checked under a lock), send the first message through chat's `MessageSend`, record `first_message_id`. A refusal at insert leaves an empty support chat that no list shows.
- Console has no test runner; adding Vitest is out of this part. Its tasks verify with lint, build and a walk against `make run` with the server's e2e seed.
- Spec testing line "Console: route and component tests" is replaced by the walk above.

---

## File map

Server (`~/shopnexus/server`):

| File | Responsibility | Task |
|---|---|---|
| `api/openapi.yaml`, `api/paths/support.yaml`, `api/schemas/support.yaml`, `api/paths/console.yaml`, `api/schemas/console.yaml`, `api/schemas/chat.yaml`, `api/schemas/screen_inbox.yaml`, `api/spec_test.go` | the contract | 1 |
| `migrations/0044_support_tickets.sql`, `migrations/support_tickets_test.go` | ShopNexus, conversation kind, reply, completed_by, tickets, feedback move | 2 |
| `internal/chat/domain/chat.go`, `internal/chat/repository/{repository,chat_pg,search_pg}.go`, `internal/chat/service/{service,message_send,message_send_durable,views,message_facts,conversation_read,threads}.go`, `internal/chat/handler/chat.go` | kind, reply, support chats | 3 |
| `internal/account/domain/{account,errors}.go`, `internal/account/service/account_suspend.go` | ShopNexusID, refusal | 4 |
| `internal/deal/domain/{order,deal}.go`, `internal/deal/repository/deal_pg.go`, `internal/deal/service/{views,deal_get}.go` | completed_by, OrderFacts | 5 |
| `internal/support/domain/{ticket,errors}.go`, `internal/support/repository/{repository,tickets_pg}.go` (feedback files go) | tickets, events, replies, audit | 6 |
| `internal/support/service/{service,ticket_open,ticket_open_durable,ticket_list,console}.go`, `internal/support/worker/worker.go`, `internal/support/handler/handler.go`, `internal/support/support.go`, `internal/console/handler/support.go`, `internal/console/handler/handler.go`, `internal/console/console.go`, `internal/platform/audit/audit.go` | use cases, flow, worker, HTTP | 7 |
| `internal/trust/worker/scam.go`, `internal/notification/worker/worker.go`, `internal/screen/service/chat.go`, `internal/screen/screen.go` | the other modules | 8 |
| `internal/app/app.go`, `e2e/support_test.go`, `ARCHITECTURE.md` | wiring, e2e, decisions | 9 |

Console (`~/shopnexus/console`): `src/lib/support.ts` (new), `src/routes/Support.tsx` (new), `src/components/Shell.tsx`, `src/lib/navigation.tsx`, `src/App.tsx`, `DESIGN.md` (Task 10).

App (`~/shopnexus/app`): `core/model` (`Support.kt`, `Thread.kt`), `core/data` (`Repositories.kt`, `fake/FakeSupportRepository.kt`, `fake/FakeWorld.kt`, fixtures), `core/navigation/Routes.kt`, `feature/deal/chat/*`, new `feature/support`, `feature/me`, `feature/settings/help`, `feature/orders/{cod,ship}`, `feature/codsetup` (Tasks 11–14).

## Task order and interfaces

Tasks 1–9 are the server and run in order. Task 10 (console) needs Task 9 merged or the server worktree running. Tasks 11–14 (app) are independent of the server and run in order.

Names later tasks rely on:

- `accountdomain.ShopNexusID uuid.UUID`, `accountdomain.ErrSystemAccount` (`account_is_system`, 409).
- `chatdomain.KindPair`, `chatdomain.KindSupport` (`ConversationKind`); `Conversation.Kind`.
- `chatsvc.Service.OpenSupport(ctx, account uuid.UUID, id uuid.UUID) (ConversationView, error)`; `chatsvc.Service.Threads(ctx, account uuid.UUID, conversations []uuid.UUID) (map[uuid.UUID]Thread, error)` with `Thread{Last *MessageView; Unread int}`; `chatsvc.Service.SupportUnread(ctx, account) (int, error)`; `chatsvc.SendInput{Text, Photos, ListingID, ReplyTo *uuid.UUID, OpensTicket bool}`; `chatsvc.MessageSendName = "MessageSend"`; `chatsvc.MessageFacts.Kind`; `chatsvc.MessageView.ReplyTo *QuoteView`.
- `dealsvc.OrderFacts{BuyerID, SellerID, ListingID, Status, Code, Price, Shipment *domain.Shipment, CompletedBy domain.Party, ShippedAt, ClosedAt *time.Time}`.
- `supportsvc.Service` (Task 7), `supportsvc.TicketView`, `supportsvc.ConsoleTicket`, `supportsvc.ConsoleTicketDetail`.
- `audit.TicketReply`, `audit.TicketResolve`, `audit.TicketReopen`, `audit.TargetTicket`, `audit.Ticket(id)`.

---

## Server

### Task 1: The contract

**Files:**
- Modify: `api/openapi.yaml`, `api/paths/support.yaml`, `api/schemas/support.yaml`, `api/paths/console.yaml`, `api/schemas/console.yaml`, `api/schemas/chat.yaml`, `api/schemas/screen_inbox.yaml`
- Test: `api/spec_test.go`

**Interfaces:**
- Produces: the routes and schemas every later task binds to.

- [ ] **Step 1: Write the failing test**

Add to `api/spec_test.go`, next to `TestSpecHasTheCarrierRoutes`:

```go
func TestSpecHasTheSupportRoutes(t *testing.T) {
	doc := load(t)
	for _, p := range []string{
		"/v1/support/tickets", "/v1/support/summary", "/v1/support/orders/{order_id}/ticket",
		"/v1/console/support/tickets", "/v1/console/support/tickets/{id}", "/v1/console/support/tickets/{id}/messages",
		"/v1/console/support/tickets/{id}/replies", "/v1/console/support/tickets/{id}/resolve",
		"/v1/console/support/tickets/{id}/reopen", "/v1/console/support/summary",
	} {
		if doc.Paths.Find(p) == nil {
			t.Errorf("missing %s", p)
		}
	}
	for _, gone := range []string{"/v1/feedback", "/v1/console/feedback"} {
		if doc.Paths.Find(gone) != nil {
			t.Errorf("%s should be gone", gone)
		}
	}
	draft := doc.Components.Schemas["MessageDraft"]
	if draft == nil || draft.Value.Properties["reply_to"] == nil {
		t.Error("MessageDraft needs reply_to")
	}
}
```

(`load` is the helper the existing tests use to read `openapi.yaml`; match its name in the file.)

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./api/ -run TestSpecHasTheSupportRoutes`
Expected: FAIL, "missing /v1/support/tickets".

- [ ] **Step 3: Write the contract**

`api/paths/support.yaml` replaces `feedback` with:

```yaml
tickets:
  get:
    operationId: listMyTickets
    summary: The caller's tickets, open ones first, each newest activity first.
    tags: [support]
    security:
      - bearerAuth: []
    responses:
      "200":
        description: Every ticket of the caller's; a person has few.
        content:
          application/json:
            schema:
              $ref: "../schemas/support.yaml#/TicketList"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
  post:
    operationId: openTicket
    summary: Open a ticket and its chat with ShopNexus.
    description: |
      not_received needs order_id, an order of the caller's as buyer that is
      shipped or was completed by the system less than 7 days ago; an order
      that has its ticket returns that ticket with 200. carrier_request needs
      carrier_name. other needs body. At most 10 new tickets in 24 hours. A
      repeated Idempotency-Key returns the ticket its first request opened.
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
            $ref: "../schemas/support.yaml#/TicketOpen"
    responses:
      "200":
        description: The order's ticket, which already existed.
        content:
          application/json:
            schema:
              $ref: "../schemas/support.yaml#/Ticket"
      "201":
        description: Opened.
        content:
          application/json:
            schema:
              $ref: "../schemas/support.yaml#/Ticket"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "No such order of the caller's as buyer (order_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "409":
        description: "The order is not shipped, or was completed by the buyer or more than 7 days ago (ticket_not_allowed)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "422":
        description: "A field the kind needs is missing or out of range (invalid_ticket, with fields)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
      "429":
        description: "10 tickets in the last 24 hours (too_many_tickets)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
summary:
  get:
    operationId: getSupportSummary
    summary: Open tickets and unread replies, for Tôi and Trợ giúp.
    tags: [support]
    security:
      - bearerAuth: []
    responses:
      "200":
        description: The counts and the newest unread reply.
        content:
          application/json:
            schema:
              $ref: "../schemas/support.yaml#/SupportSummary"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
orderTicket:
  get:
    operationId: getOrderTicket
    summary: The ticket of one of the caller's orders, for "Xem yêu cầu".
    tags: [support]
    security:
      - bearerAuth: []
    parameters:
      - name: order_id
        in: path
        required: true
        schema:
          type: string
          format: uuid
    responses:
      "200":
        description: The ticket.
        content:
          application/json:
            schema:
              $ref: "../schemas/support.yaml#/Ticket"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
      "404":
        description: "The order has no ticket of the caller's (ticket_not_found)."
        content:
          application/json:
            schema:
              $ref: "../schemas/error.yaml#/Error"
```

`api/schemas/support.yaml` replaces the feedback schemas with:

```yaml
TicketKind:
  type: string
  enum: [not_received, carrier_request, other]
TicketStatus:
  type: string
  enum: [open, resolved]
TicketOpen:
  type: object
  additionalProperties: false
  required: [kind]
  properties:
    kind:
      $ref: "#/TicketKind"
    order_id:
      type: string
      format: uuid
      description: not_received only.
    carrier_name:
      type: string
      description: carrier_request only; 1 to 50 characters after trimming.
    body:
      type: string
      description: The first message, 0 to 1000 characters after trimming; other needs 1.
TicketOrder:
  type: object
  additionalProperties: false
  required: [id, title, carrier, tracking_code]
  properties:
    id:
      type: string
      format: uuid
    title:
      type: string
    photo_url:
      type: string
      format: uri
    carrier:
      type: string
    tracking_code:
      type: string
TicketEvent:
  type: object
  additionalProperties: false
  required: [kind, at]
  properties:
    kind:
      type: string
      enum: [opened, resolved, reopened]
    at:
      type: string
      format: date-time
Ticket:
  type: object
  additionalProperties: false
  required: [id, kind, status, conversation_id, opened_at, events]
  properties:
    id:
      type: string
      format: uuid
    kind:
      $ref: "#/TicketKind"
    status:
      $ref: "#/TicketStatus"
    conversation_id:
      type: string
      format: uuid
    first_message_id:
      type: string
      format: uuid
      description: The message the app draws as the ticket's card; absent for a moment while the ticket opens.
    order:
      $ref: "#/TicketOrder"
    carrier_name:
      type: string
    opened_at:
      type: string
      format: date-time
    events:
      type: array
      items:
        $ref: "#/TicketEvent"
TicketListItem:
  type: object
  additionalProperties: false
  required: [ticket, unread]
  properties:
    ticket:
      $ref: "#/Ticket"
    last_message:
      $ref: "chat.yaml#/Message"
    unread:
      type: integer
TicketList:
  type: object
  additionalProperties: false
  required: [items]
  properties:
    items:
      type: array
      items:
        $ref: "#/TicketListItem"
SupportSummary:
  type: object
  additionalProperties: false
  required: [open, unread]
  properties:
    open:
      type: integer
    unread:
      type: integer
    latest_unread:
      $ref: "#/TicketListItem"
```

`api/paths/console.yaml`: drop `feedback`; add `supportTickets` (GET, query `status` `TicketStatus` required, `kind` optional, Cursor, Limit → `ConsoleTicketList`), `supportTicket` (GET → `ConsoleTicketDetail`, 404 `ticket_not_found`), `supportTicketMessages` (GET, Cursor, Limit → `chat.yaml#/MessageList` with each item's `member` from `ConsoleMessage`; use `ConsoleMessageList`), `supportTicketReplies` (POST, Idempotency-Key, body `ConsoleReply {body 1–1000, reply_to?}` → 201 `ConsoleMessage`; 404; 422 `invalid_message`), `supportTicketResolve` and `supportTicketReopen` (POST → 200 `ConsoleTicket`; 404; 409 `ticket_not_allowed` when already in that status), `supportSummary` (GET → `{open: integer}`). Every one carries `ConsoleCSRF` and `consoleAuth`, as `account` does.

`api/schemas/console.yaml`: drop `ConsoleFeedback*`; add:

```yaml
ConsoleTicket:
  type: object
  additionalProperties: false
  required: [ticket, person, last_from, last_message_at]
  properties:
    ticket:
      $ref: "support.yaml#/Ticket"
    person:
      $ref: "chat.yaml#/Person"
    last_text:
      type: string
      description: The last message's text, for the queue row.
    last_from:
      type: string
      enum: [person, shopnexus]
      description: person shows "Chờ trả lời".
    last_message_at:
      type: string
      format: date-time
ConsoleTicketList:
  type: object
  additionalProperties: false
  required: [items]
  properties:
    items:
      type: array
      items:
        $ref: "#/ConsoleTicket"
    next_cursor:
      type: string
ConsoleMessage:
  type: object
  additionalProperties: false
  required: [message]
  properties:
    message:
      $ref: "chat.yaml#/Message"
    member:
      type: string
      description: The member who wrote a ShopNexus reply; absent for the person's messages and for an automatic one.
    automatic:
      type: boolean
ConsoleMessageList:
  type: object
  additionalProperties: false
  required: [items]
  properties:
    items:
      type: array
      items:
        $ref: "#/ConsoleMessage"
    next_cursor:
      type: string
ConsoleTicketOrder:
  type: object
  additionalProperties: false
  required: [id, title, price, status, seller]
  properties:
    id:
      type: string
      format: uuid
    title:
      type: string
    price:
      type: integer
      format: int64
    status:
      type: string
      enum: [pending, shipped, completed, failed, cancelled]
    seller:
      $ref: "chat.yaml#/Person"
    carrier:
      type: string
    tracking_code:
      type: string
    shipment_status:
      type: string
    shipped_at:
      type: string
      format: date-time
    delivered_at:
      type: string
      format: date-time
ConsoleTicketDetail:
  type: object
  additionalProperties: false
  required: [ticket, person_status, joined_at, others, messages]
  properties:
    ticket:
      $ref: "#/ConsoleTicket"
    person_status:
      type: string
      enum: [active, suspended, deleted]
    joined_at:
      type: string
      format: date-time
    order:
      $ref: "#/ConsoleTicketOrder"
    same_carrier_30d:
      type: integer
      description: carrier_request only; tickets naming the same carrier in 30 days, this one included.
    others:
      type: array
      items:
        $ref: "support.yaml#/Ticket"
    messages:
      $ref: "#/ConsoleMessageList"
```

`api/schemas/chat.yaml`: `MessageDraft.reply_to` (uuid, "A sent message of the same conversation the message quotes"); `Message.reply_to` (`$ref: "#/Quote"`); new `Quote {id, sender_id, text (≤200), photos (integer)}`; `Person.official` (boolean, "ShopNexus"). `Conversation` stays.

`api/schemas/screen_inbox.yaml`: `ChatScreen.ticket` (`$ref: "support.yaml#/Ticket"`), "Present for a support chat".

`api/openapi.yaml`: replace the two feedback routes with the ten above (`paths/support.yaml#/tickets`, `#/summary`, `#/orderTicket`; `paths/console.yaml#/supportTickets` …). Errors: add `ticket_not_found`, `ticket_not_allowed`, `too_many_tickets`, `invalid_ticket`, `conversation_is_support`, `account_is_system` wherever the file lists codes; drop `invalid_feedback`, `feedback_limit_reached`. Chat's archive, unarchive, unread and the report endpoints gain a 409 `conversation_is_support`; console's suspend gains 409 `account_is_system`.

- [ ] **Step 4: Run the spec tests**

Run: `go test ./api/`
Expected: PASS, including the existing validation of every example.

- [ ] **Step 5: Commit**

```bash
git add api/
git commit -m "api: support tickets, quoted replies, ShopNexus as a person"
```

### Task 2: The migration

**Files:**
- Create: `migrations/0044_support_tickets.sql`, `migrations/support_tickets_test.go`

**Interfaces:**
- Produces: tables `tickets`, `ticket_events`, `ticket_replies`; columns `conversations.kind`, `messages.reply_to`, `orders.completed_by`; the ShopNexus account row `0193e000-0000-7000-8000-000000000001`.

- [ ] **Step 1: Write the failing test**

`migrations/support_tickets_test.go`, in the style of `carrier_accounts_test.go` (it migrates a fresh database up to the step before, seeds, then migrates the last step):

```go
func TestSupportTicketsMovesFeedback(t *testing.T) {
	db := migrateTo(t, "0043_carrier_accounts.sql")
	ctx := context.Background()
	person := seedAccount(t, db)
	key := uuid.NewV7()
	mustExec(t, db, `INSERT INTO feedback (id, account_id, body, request_key, created_at)
VALUES (uuidv7(), $1, 'Lọc khu vực hay nhảy về Q.1', $2, now() - interval '2 days')`, person, key)
	migrateRest(t, db)

	var kind, status, body string
	var fromPerson bool
	if err := db.QueryRow(ctx, `SELECT t.kind, t.status, m.body, m.sender_id = t.account_id
FROM tickets t JOIN messages m ON m.id = t.first_message_id WHERE t.account_id = $1`, person).
		Scan(&kind, &status, &body, &fromPerson); err != nil {
		t.Fatal(err)
	}
	if kind != "other" || status != "open" || body != "Lọc khu vực hay nhảy về Q.1" || !fromPerson {
		t.Fatalf("got %s %s %q %v", kind, status, body, fromPerson)
	}
	var convKind string
	if err := db.QueryRow(ctx, `SELECT c.kind FROM conversations c JOIN tickets t ON t.conversation_id = c.id
WHERE t.account_id = $1`, person).Scan(&convKind); err != nil || convKind != "support" {
		t.Fatalf("conversation kind %q, %v", convKind, err)
	}
	if exists(t, db, "feedback") {
		t.Fatal("feedback should be gone")
	}
}

func TestSupportChatsAreManyPerPair(t *testing.T) {
	db := migrateTo(t, "")
	person := seedAccount(t, db)
	for range 2 {
		mustExec(t, db, `INSERT INTO conversations (id, account_a, account_b, kind, created_at)
VALUES (uuidv7(), LEAST($1::uuid, $2::uuid), GREATEST($1::uuid, $2::uuid), 'support', now())`, person, shopNexus)
	}
	other := seedAccount(t, db)
	mustExec(t, db, `INSERT INTO conversations (id, account_a, account_b, created_at)
VALUES (uuidv7(), LEAST($1::uuid, $2::uuid), GREATEST($1::uuid, $2::uuid), now())`, person, other)
	if err := execErr(db, `INSERT INTO conversations (id, account_a, account_b, created_at)
VALUES (uuidv7(), LEAST($1::uuid, $2::uuid), GREATEST($1::uuid, $2::uuid), now())`, person, other); err == nil {
		t.Fatal("a second pair conversation should be refused")
	}
}

func TestOrdersCompletedByIsBackfilled(t *testing.T) {
	db := migrateTo(t, "0043_carrier_accounts.sql")
	order := seedCompletedOrder(t, db, "system") // writes a deal_moves 'completed' row by 'system'
	migrateRest(t, db)
	var by string
	if err := db.QueryRow(context.Background(), `SELECT completed_by FROM orders WHERE id = $1`, order).Scan(&by); err != nil || by != "system" {
		t.Fatalf("completed_by %q, %v", by, err)
	}
}
```

Write `seedCompletedOrder`, `execErr`, `exists` and `shopNexus` (the fixed id) beside the helpers the file's neighbours use; reuse theirs where they exist.

- [ ] **Step 2: Run it to see it fail**

Run (after recreating the stack): `go test ./migrations/ -run 'TestSupport|TestOrdersCompletedBy'`
Expected: FAIL, no file `0044`.

- [ ] **Step 3: Write the migration**

`migrations/0044_support_tickets.sql`:

```sql
-- Support tickets (2026-11-13): each ticket is a chat between a person and
-- the system account ShopNexus, which nobody signs in to.
INSERT INTO accounts (id, display_name, status, write_id, created_at, updated_at)
VALUES ('0193e000-0000-7000-8000-000000000001', 'ShopNexus', 'active', uuidv7(), now(), now());

-- A pair conversation is the one chat of two people; a support one is one
-- ticket's chat, and a person has as many as tickets.
ALTER TABLE conversations ADD COLUMN kind text NOT NULL DEFAULT 'pair' CHECK (kind IN ('pair', 'support'));
ALTER TABLE conversations ALTER COLUMN kind DROP DEFAULT;
ALTER TABLE conversations DROP CONSTRAINT conversations_account_a_account_b_key;
CREATE UNIQUE INDEX conversations_pair ON conversations (account_a, account_b) WHERE kind = 'pair';

-- A message may quote an earlier sent message of its conversation.
ALTER TABLE messages ADD COLUMN reply_to uuid REFERENCES messages (id);

-- Who completed an order: the buyer's receipt, or the system after the
-- carrier reported it delivered.
ALTER TABLE orders ADD COLUMN completed_by text CHECK (completed_by IN ('buyer', 'system'));
UPDATE orders o SET completed_by = m.by_party
FROM deal_moves m
WHERE o.status = 'completed' AND m.deal_id = o.deal_id AND m.kind = 'completed';
ALTER TABLE orders ADD CONSTRAINT orders_completed_by CHECK ((status = 'completed') = (completed_by IS NOT NULL));

CREATE TABLE tickets (
    id               uuid PRIMARY KEY,
    account_id       uuid NOT NULL REFERENCES accounts (id),
    conversation_id  uuid NOT NULL UNIQUE REFERENCES conversations (id),
    kind             text NOT NULL CHECK (kind IN ('not_received', 'carrier_request', 'other')),
    status           text NOT NULL CHECK (status IN ('open', 'resolved')),
    order_id         uuid REFERENCES orders (id),
    carrier_name     text CHECK (char_length(carrier_name) BETWEEN 1 AND 50),
    carrier_key      text,
    first_message_id uuid REFERENCES messages (id),
    last_message_at  timestamptz NOT NULL,
    last_from        text NOT NULL CHECK (last_from IN ('person', 'shopnexus')),
    opened_at        timestamptz NOT NULL,
    resolved_at      timestamptz,
    resolved_by      uuid REFERENCES console_members (id),
    request_key      uuid NOT NULL,
    UNIQUE (account_id, request_key),
    CHECK ((kind = 'not_received') = (order_id IS NOT NULL)),
    CHECK ((kind = 'carrier_request') = (carrier_name IS NOT NULL AND carrier_key IS NOT NULL)),
    CHECK ((status = 'resolved') = (resolved_at IS NOT NULL))
);
CREATE UNIQUE INDEX tickets_one_per_order ON tickets (order_id) WHERE kind = 'not_received';
CREATE INDEX tickets_account ON tickets (account_id, opened_at);
CREATE INDEX tickets_queue ON tickets (status, last_message_at DESC);
CREATE INDEX tickets_carrier ON tickets (carrier_key, opened_at) WHERE kind = 'carrier_request';

CREATE TABLE ticket_events (
    id        uuid PRIMARY KEY,
    ticket_id uuid NOT NULL REFERENCES tickets (id),
    kind      text NOT NULL CHECK (kind IN ('opened', 'resolved', 'reopened')),
    member_id uuid REFERENCES console_members (id),
    at        timestamptz NOT NULL
);
CREATE INDEX ticket_events_ticket ON ticket_events (ticket_id, at);

-- Who wrote each ShopNexus message; member_id is null for an automatic one.
CREATE TABLE ticket_replies (
    message_id uuid PRIMARY KEY REFERENCES messages (id),
    ticket_id  uuid NOT NULL REFERENCES tickets (id),
    member_id  uuid REFERENCES console_members (id)
);

ALTER TABLE console_actions DROP CONSTRAINT console_actions_target_kind_check;
ALTER TABLE console_actions ADD CONSTRAINT console_actions_target_kind_check
CHECK (target_kind IN ('account', 'member', 'ticket'));

-- Feedback becomes open tickets of kind other, its text the first message.
WITH moved AS (
    SELECT f.*, uuidv7() AS conversation_id, uuidv7() AS message_id, uuidv7() AS ticket_id
    FROM feedback f
), conv AS (
    INSERT INTO conversations (id, account_a, account_b, kind, last_message_id, last_message_at, created_at)
    SELECT conversation_id,
           LEAST(account_id, '0193e000-0000-7000-8000-000000000001'::uuid),
           GREATEST(account_id, '0193e000-0000-7000-8000-000000000001'::uuid),
           'support', message_id, created_at, created_at
    FROM moved
    RETURNING id
), members AS (
    INSERT INTO conversation_members (conversation_id, account_id)
    SELECT conversation_id, account_id FROM moved
    UNION ALL
    SELECT conversation_id, '0193e000-0000-7000-8000-000000000001'::uuid FROM moved
    RETURNING 1
), msg AS (
    INSERT INTO messages (id, conversation_id, sender_id, body, photos, status, created_at)
    SELECT message_id, conversation_id, account_id, body, '[]', 'sent', created_at FROM moved
    RETURNING 1
), t AS (
    INSERT INTO tickets (id, account_id, conversation_id, kind, status, first_message_id, last_message_at,
                         last_from, opened_at, request_key)
    SELECT ticket_id, account_id, conversation_id, 'other', 'open', message_id, created_at, 'person', created_at, request_key
    FROM moved
    RETURNING 1
)
INSERT INTO ticket_events (id, ticket_id, kind, at)
SELECT uuidv7(), ticket_id, 'opened', created_at FROM moved;

DROP TABLE feedback;
```

Before writing, check two names against `\d conversations` and `\d console_actions` in the test database (`psql` into the test stack): the unique constraint (`conversations_account_a_account_b_key`) and the check (`console_actions_target_kind_check`). Postgres runs every data-modifying CTE even when nothing reads it; the `conv` CTE must run before `members` and `msg` reference its rows, which the foreign keys check only at statement end, so one statement is right.

- [ ] **Step 4: Run the migration tests**

Run: `go test ./migrations/`
Expected: PASS, the existing migration tests too.

- [ ] **Step 5: Commit**

```bash
git add migrations/
git commit -m "migrations: tickets, support chats, quoted replies, completed_by"
```

### Task 3: Chat learns support chats and quoted replies

**Files:**
- Modify: `internal/chat/domain/chat.go`, `internal/chat/domain/errors.go`, `internal/chat/repository/repository.go`, `internal/chat/repository/chat_pg.go`, `internal/chat/repository/search_pg.go`, `internal/chat/service/service.go`, `internal/chat/service/message_send.go`, `internal/chat/service/message_send_durable.go`, `internal/chat/service/views.go`, `internal/chat/service/message_facts.go`, `internal/chat/service/conversation_read.go`, `internal/chat/handler/chat.go`
- Create: `internal/chat/service/threads.go`
- Test: `internal/chat/domain/chat_test.go`, `internal/chat/repository/chat_pg_test.go`, `internal/chat/service/flow_test.go`, `internal/chat/service/support_test.go` (new)

**Interfaces:**
- Consumes: `accountdomain.ShopNexusID` (Task 4 adds it; this task adds the constant first if Task 4 has not run, and Task 4 keeps it).
- Produces: `domain.ConversationKind` (`KindPair`, `KindSupport`), `Conversation.Kind`; `domain.ErrSupportConversation` (`conversation_is_support`, 409); `Message.ReplyTo() *uuid.UUID`; `domain.NewMessage(id, conversation, sender, body, photos, listing, replyTo *uuid.UUID, opensTicket bool, now)`; `repository.Chats.OpenSupport`, `Threads`, `SupportUnread`; `Service.OpenSupport`, `Service.Threads`, `Service.SupportUnread`; `SendInput.ReplyTo`, `SendInput.OpensTicket`; `MessageSendName`; `MessageView.ReplyTo *QuoteView`; `PersonView.Official`; `MessageFacts.Kind`.

- [ ] **Step 1: Write the failing domain tests**

```go
func TestATicketsFirstMessageMayBeEmpty(t *testing.T) {
	if _, err := domain.NewMessage(uuid.NewV7(), uuid.NewV7(), uuid.NewV7(), "  ", nil, nil, nil, true, time.Now()); err != nil {
		t.Fatalf("opensTicket allows no text: %v", err)
	}
	if _, err := domain.NewMessage(uuid.NewV7(), uuid.NewV7(), uuid.NewV7(), "", nil, nil, nil, false, time.Now()); err == nil {
		t.Fatal("an ordinary message needs text or photos")
	}
}

func TestSupportConversationsAreNotPairs(t *testing.T) {
	c := domain.NewSupportConversation(uuid.NewV7(), uuid.NewV7(), time.Now())
	if c.Kind != domain.KindSupport || !c.Has(accountdomain.ShopNexusID) {
		t.Fatalf("got %+v", c)
	}
}
```

Update every existing `NewMessage` call in the module's code and tests to pass `nil, false` for the two new parameters.

- [ ] **Step 2: Implement the domain**

In `chat.go`:

```go
// ConversationKind is a pair's one chat, or a support ticket's chat with
// ShopNexus, of which a person has any number.
type ConversationKind string

const (
	KindPair    ConversationKind = "pair"
	KindSupport ConversationKind = "support"
)
```

`Conversation` gains `Kind ConversationKind \`json:"kind"\``; `NewConversation` sets `KindPair`; add

```go
// NewSupportConversation starts a ticket's chat between account and
// ShopNexus.
func NewSupportConversation(id, account uuid.UUID, now time.Time) Conversation {
	c := NewConversation(id, account, accountdomain.ShopNexusID, now)
	c.Kind = KindSupport
	return c
}
```

`Message` gains `replyTo *uuid.UUID` (and `MessageState.ReplyTo`, `RestoreMessage`, `State`, accessor `ReplyTo()`). `NewMessage` gains `replyTo *uuid.UUID, opensTicket bool`; the text rule becomes `n > MaxText || (n == 0 && len(photos) == 0 && !opensTicket)`. `errors.go` adds `ErrSupportConversation = apperr.New(apperr.KindConflict, "conversation_is_support", "a support chat cannot be archived, marked, blocked or reported")`.

- [ ] **Step 3: Write the failing repository tests**

```go
func TestSupportChatsStayOutOfTheInbox(t *testing.T) {
	s, person := newChats(t), seedAccount(t)
	conv, err := s.OpenSupport(ctx, domain.NewSupportConversation(uuid.NewV7(), person, time.Now()))
	if err != nil {
		t.Fatal(err)
	}
	addSent(t, s, conv.ID, accountdomain.ShopNexusID, "Chào bạn")
	rows, err := s.Inbox(ctx, person, false, page.Request{})
	if err != nil || len(rows) != 0 {
		t.Fatalf("inbox %v, %v", rows, err)
	}
	if n, _ := s.Unread(ctx, person); n != 0 {
		t.Fatalf("unread %d", n)
	}
	if n, _ := s.SupportUnread(ctx, person); n != 1 {
		t.Fatalf("support unread %d", n)
	}
	threads, err := s.Threads(ctx, person, []uuid.UUID{conv.ID})
	if err != nil || threads[conv.ID].Unread != 1 || threads[conv.ID].Last.Body() != "Chào bạn" {
		t.Fatalf("threads %+v, %v", threads, err)
	}
}

func TestOpenSupportMakesANewChatEachTime(t *testing.T) {
	s, person := newChats(t), seedAccount(t)
	a, _ := s.OpenSupport(ctx, domain.NewSupportConversation(uuid.NewV7(), person, time.Now()))
	b, _ := s.OpenSupport(ctx, domain.NewSupportConversation(uuid.NewV7(), person, time.Now()))
	if a.ID == b.ID || a.Kind != domain.KindSupport {
		t.Fatalf("%+v %+v", a, b)
	}
	again, _ := s.OpenSupport(ctx, a) // a retried step with the same id returns it
	if again.ID != a.ID {
		t.Fatal("OpenSupport is idempotent on the id")
	}
}

func TestAQuoteIsStoredAndRead(t *testing.T) {
	s := newChats(t)
	conv, first := seedPairWithMessage(t, s, "Còn máy không?")
	reply, _ := domain.NewMessage(uuid.NewV7(), conv.ID, conv.AccountB, "Còn bạn", nil, nil, new(first.ID()), false, time.Now())
	if err := s.AddMessage(ctx, reply); err != nil {
		t.Fatal(err)
	}
	got, _ := s.GetMessage(ctx, reply.ID())
	if got.ReplyTo() == nil || *got.ReplyTo() != first.ID() {
		t.Fatalf("reply_to %v", got.ReplyTo())
	}
}
```

Search: add `TestSearchSkipsSupportChats` to `search_pg_test.go` (a support chat whose message matches the query is in neither `SearchThreads` nor `SearchMessages`).

- [ ] **Step 4: Implement the repository**

- `messageColumns` and `messageScan` read `m.reply_to`; `AddMessage` and `SaveMessage` write it.
- Every `SELECT … FROM conversations` reads `kind` into `Conversation.Kind`.
- `OpenPair`: `ON CONFLICT (account_a, account_b) WHERE kind = 'pair' DO NOTHING` and inserts `kind = 'pair'`; its select adds `AND kind = 'pair'`. `FindPair` adds `AND kind = 'pair'`.
- `OpenSupport(ctx, c)`: one transaction, `INSERT INTO conversations (id, account_a, account_b, kind, created_at) VALUES (…, 'support', …) ON CONFLICT (id) DO NOTHING`, the two members `ON CONFLICT DO NOTHING`, then `Get(ctx, c.ID)`.
- `listed` adds `AND c.kind = 'pair'`, so `Inbox`, `Unread` and the search queries that use it skip support chats; check `search_pg.go` for queries that do not use `listed` and add the same condition.
- `SupportUnread(ctx, viewer)`: `countUnread` with `c.kind = 'support'` in place of the `listed` filter (`cm.account_id = @viewer AND c.kind = 'support' AND c.last_message_id IS NOT NULL`).
- `Threads(ctx, viewer, ids)`: `SELECT messageColumns, c.id, rowUnread FROM conversation_members cm JOIN conversations c … JOIN messages m ON m.id = c.last_message_id` + `unreadAfter` `WHERE cm.account_id = @viewer AND c.id = ANY(@ids)`; returns `map[uuid.UUID]ThreadRow{Last domain.Message; Unread int}`. A conversation with no message is absent from the map.
- `repository.go`: the three new methods with doc comments; `ThreadRow`.

- [ ] **Step 5: Write the failing service tests**

`internal/chat/service/support_test.go` (Restate test env as `flow_test.go` uses):

```go
func TestReplyToMustBeASentMessageHere(t *testing.T) {
	env := newEnv(t)
	conv := env.pair(t)
	elsewhere := env.pair(t)
	foreign := env.send(t, elsewhere.buyer, elsewhere.id, "khác")
	for name, id := range map[string]uuid.UUID{"another chat": foreign.ID, "unknown": uuid.NewV7()} {
		_, err := env.chat.Send(ctx, conv.buyer, conv.id, uuid.NewString(), service.SendInput{Text: "ok", ReplyTo: &id})
		if code(err) != "invalid_message" || field(err) != "reply_to" {
			t.Errorf("%s: %v", name, err)
		}
	}
	processing := env.sendPhoto(t, conv.buyer, conv.id) // stays processing in the test media
	if _, err := env.chat.Send(ctx, conv.seller, conv.id, uuid.NewString(), service.SendInput{Text: "ok", ReplyTo: new(processing.ID)}); code(err) != "invalid_message" {
		t.Errorf("a processing message: %v", err)
	}
}

func TestSuspendedPersonWritesToSupport(t *testing.T) {
	env := newEnv(t)
	person := env.account(t)
	conv, _ := env.chat.OpenSupport(ctx, person, uuid.NewV7())
	env.suspend(t, person)
	if _, err := env.chat.Send(ctx, person, conv.ID, uuid.NewString(), service.SendInput{Text: "Vì sao tôi bị khoá?"}); err != nil {
		t.Fatalf("support chat: %v", err)
	}
	pair := env.pairWith(t, person)
	if _, err := env.chat.Send(ctx, person, pair.id, uuid.NewString(), service.SendInput{Text: "hi"}); code(err) != "account_suspended" {
		t.Fatalf("pair chat: %v", err)
	}
}

func TestSupportChatsRefuseArchiveAndUnread(t *testing.T) {
	env := newEnv(t)
	person := env.account(t)
	conv, _ := env.chat.OpenSupport(ctx, person, uuid.NewV7())
	for name, err := range map[string]error{
		"archive":   env.chat.Archive(ctx, person, conv.ID),
		"unarchive": env.chat.Unarchive(ctx, person, conv.ID),
		"unread":    env.chat.MarkUnread(ctx, person, conv.ID),
	} {
		if code(err) != "conversation_is_support" {
			t.Errorf("%s: %v", name, err)
		}
	}
}

func TestTheQuoteComesWithTheMessage(t *testing.T) {
	env := newEnv(t)
	conv := env.pair(t)
	first := env.send(t, conv.buyer, conv.id, "Máy còn bảo hành không?")
	m, err := env.chat.Send(ctx, conv.seller, conv.id, uuid.NewString(), service.SendInput{Text: "Còn 3 tháng", ReplyTo: &first.ID})
	if err != nil || m.ReplyTo == nil || m.ReplyTo.Text != "Máy còn bảo hành không?" || m.ReplyTo.SenderID != conv.buyer {
		t.Fatalf("%+v, %v", m.ReplyTo, err)
	}
}
```

Use the helper names `flow_test.go` and `helpers_test.go` already have, and add `pair`, `pairWith`, `suspend`, `sendPhoto` there if missing.

- [ ] **Step 6: Implement the service**

- `service.go`: `Service` gains

```go
	// OpenSupport makes the support chat id between account and ShopNexus,
	// or returns it when a retried step made it already. Module support only.
	OpenSupport(ctx context.Context, account, id uuid.UUID) (ConversationView, error)
	// Threads reads the last message and account's unread count of each of
	// account's conversations among ids; one with no message is absent.
	Threads(ctx context.Context, account uuid.UUID, ids []uuid.UUID) (map[uuid.UUID]Thread, error)
	// SupportUnread counts account's unread messages over its support chats.
	SupportUnread(ctx context.Context, account uuid.UUID) (int, error)
```

  and exports `const MessageSendName = messageSend` for module support's flow.
- `SendInput` gains `ReplyTo *uuid.UUID` and `OpensTicket bool` (the handler's binding struct does not carry `OpensTicket`; `MessageDraft` carries `reply_to`). `SendFlowInput` gains both.
- `message_send.go`: `Send` passes them to `domain.NewMessage` and the flow.
- `message_send_durable.go`, in the read step: when `in.ReplyTo != nil`, read the message; `out.ReplyOK = err == nil && m.ConversationID() == in.ConversationID && m.Status() == domain.StatusSent`. In the decision `switch`, before `case f.Blocked`:

```go
	case in.ReplyTo != nil && !f.ReplyOK:
		refused = domain.ErrInvalidMessage.WithField("reply_to", "a sent message of this conversation")
```

  The status refusal becomes `case f.Status.Refusal() != nil && !(f.Status == accountdomain.StatusSuspended && f.Conversation != nil && f.Conversation.Kind == domain.KindSupport):` (a suspended person still writes to support). `NewMessage` gets `in.ReplyTo, in.OpensTicket`.
- `threads.go`: `Thread{Last *MessageView; Unread int}`; `Threads` maps the repository rows through `messageView`; `SupportUnread` and `OpenSupport` (`chats.OpenSupport(domain.NewSupportConversation(id, account, c.now()))`, then `c.Get(ctx, account, id)`).
- `conversation_read.go`: `Archive`, `Unarchive` and `MarkUnread` return `domain.ErrSupportConversation` when `conv.Kind == domain.KindSupport` (after `member`).
- `views.go`: `QuoteView{ID, SenderID uuid.UUID; Text string; Photos int}`; `MessageView.ReplyTo *QuoteView \`json:"reply_to,omitempty"\``; `messageView` reads the quoted message (`chats.GetMessage`) when `ReplyTo()` is set, cutting `Body()` to 200 runes; a quote whose message is gone is left off. `PersonView.Official bool \`json:"official,omitempty"\`` is true for `accountdomain.ShopNexusID`.
- `message_facts.go`: `MessageFacts.Kind domain.ConversationKind` from the conversation it reads.
- `handler/chat.go`: the send request binds `ReplyTo *uuid.UUID \`json:"reply_to"\``.

Check `Peer`: a person may not block ShopNexus, so trust's block endpoint must refuse; `Peer` keeps returning ShopNexus, and Task 8 makes the report and block paths refuse support chats.

- [ ] **Step 7: Run the module's tests**

Run (fresh stack): `go test ./internal/chat/...`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add internal/chat/
git commit -m "chat: support chats with ShopNexus, and quoted replies"
```

### Task 4: The ShopNexus account

**Files:**
- Modify: `internal/account/domain/account.go` (or the file with `Status`), `internal/account/domain/errors.go`, `internal/account/service/account_suspend.go` (the file with `Suspend`)
- Test: `internal/account/service/account_suspend_test.go` (or the existing suspend test file)

**Interfaces:**
- Produces: `domain.ShopNexusID`, `domain.ErrSystemAccount`.

- [ ] **Step 1: Write the failing test**

```go
func TestShopNexusCannotBeSuspended(t *testing.T) {
	svc := newService(t)
	_, err := svc.Suspend(ctx, service.SuspendInput{ID: domain.ShopNexusID, Reason: "thử", By: audit.ByCLI("test")})
	if code(err) != "account_is_system" {
		t.Fatalf("got %v", err)
	}
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `go test ./internal/account/... -run TestShopNexusCannotBeSuspended`
Expected: FAIL (undefined `ShopNexusID`, or the suspension goes through).

- [ ] **Step 3: Implement**

```go
// ShopNexusID is the system account support chats are with. Migration
// 0044 makes it; it has no identity, so nobody signs in to it.
var ShopNexusID = uuid.MustParse("0193e000-0000-7000-8000-000000000001")
```

(Use the stdlib `uuid` package's parse function; check its name in Go 1.27, `uuid.Parse` returning `(UUID, error)`, and wrap it once at package init with a panic on error if there is no `MustParse`.)

`ErrSystemAccount = apperr.New(apperr.KindConflict, "account_is_system", "the ShopNexus account cannot be changed from the console")`. `Suspend` and `Unsuspend` return it first when `in.ID == domain.ShopNexusID`. Account erasure is started by the person through their own token, which ShopNexus never has; add the same guard at the top of the erase use case anyway, so a bug elsewhere cannot erase it.

- [ ] **Step 4: Run and commit**

Run: `go test ./internal/account/...`
Expected: PASS.

```bash
git add internal/account/
git commit -m "account: the ShopNexus system account cannot be suspended or erased"
```

### Task 5: Deal tells who completed an order

**Files:**
- Modify: `internal/deal/domain/order.go`, `internal/deal/domain/deal.go`, `internal/deal/repository/deal_pg.go`, `internal/deal/service/views.go`, `internal/deal/service/deal_get.go`
- Test: `internal/deal/domain/deal_test.go`, `internal/deal/repository/deal_pg_test.go`, `internal/deal/service/deal_get_test.go`

**Interfaces:**
- Produces: `Order.CompletedBy domain.Party` (`""` until completed); `OrderFacts` as in "Task order and interfaces".

- [ ] **Step 1: Write the failing tests**

```go
func TestAutoCompleteRecordsTheSystem(t *testing.T) {
	d := shippedDeal(t, domain.ShipmentDelivered)
	if err := d.AutoComplete(d.Order().ID, time.Now()); err != nil {
		t.Fatal(err)
	}
	if d.Order().CompletedBy != domain.System {
		t.Fatalf("completed by %q", d.Order().CompletedBy)
	}
}

func TestOrderFactsCarryTheShipment(t *testing.T) {
	svc, order := seedShippedOrder(t) // GHTK, S1.A1.17373471
	f, ok, err := svc.Order(ctx, order)
	if err != nil || !ok || f.Shipment == nil || f.Shipment.TrackingCode != "S1.A1.17373471" || f.Code == "" || f.Price == 0 {
		t.Fatalf("%+v %v %v", f, ok, err)
	}
}
```

Add a buyer-receipt case (`ConfirmReceipt` sets `domain.Buyer`) and a repository round trip of `completed_by`.

- [ ] **Step 2: Implement**

`Order.CompletedBy Party \`json:"completed_by,omitempty"\``; `complete(by, now)` sets it. `deal_pg.go` reads and writes `o.completed_by` (null while not completed). `OrderFacts` gains `Code string; Price int64; Shipment *domain.Shipment; CompletedBy domain.Party; ShippedAt, ClosedAt *time.Time`, filled in `Deals.Order` from `r.Order`.

- [ ] **Step 3: Run and commit**

Run (fresh stack): `go test ./internal/deal/...`
Expected: PASS.

```bash
git add internal/deal/
git commit -m "deal: an order records who completed it; OrderFacts carry the shipment"
```

### Task 6: Support's domain and store

**Files:**
- Create: `internal/support/domain/ticket.go`, `internal/support/domain/ticket_test.go`, `internal/support/repository/tickets_pg.go`, `internal/support/repository/tickets_pg_test.go`
- Modify: `internal/support/domain/errors.go`, `internal/support/repository/repository.go`
- Delete: `internal/support/domain/feedback.go`, `feedback_test.go`, `internal/support/repository/feedback_pg.go`, `feedback_pg_test.go`, `internal/support/service/feedback_*.go`
- Modify: `internal/platform/audit/audit.go`

**Interfaces:**
- Produces:

```go
// domain
type Kind string     // KindNotReceived "not_received", KindCarrierRequest "carrier_request", KindOther "other"
type Status string   // StatusOpen "open", StatusResolved "resolved"
type From string     // FromPerson "person", FromShopNexus "shopnexus"
const DailyLimit = 10
const ReportWindow = 7 * 24 * time.Hour
func NewTicket(kind, carrierName, body string, order *uuid.UUID) (Draft, error) // checks fields per kind
type Draft struct { Kind Kind; OrderID *uuid.UUID; CarrierName, CarrierKey, Body string }
func CarrierKey(name string) string
func MayReport(f OrderCheck, buyer uuid.UUID, now time.Time) error // ErrNotAllowed or ErrOrderNotFound
type OrderCheck struct { BuyerID uuid.UUID; Status string; CompletedBy string; ClosedAt *time.Time }
// errors: ErrInvalidTicket (invalid_ticket 422), ErrNotAllowed (ticket_not_allowed 409),
// ErrTooMany (too_many_tickets 429), ErrNotFound (ticket_not_found 404), ErrOrderNotFound (order_not_found 404)

// repository
type Ticket struct {
	ID, AccountID, ConversationID uuid.UUID
	Kind domain.Kind; Status domain.Status
	OrderID *uuid.UUID; CarrierName string; FirstMessageID *uuid.UUID
	LastMessageAt time.Time; LastFrom domain.From
	OpenedAt time.Time; ResolvedAt *time.Time; ResolvedBy *uuid.UUID
	Events []Event
}
type Event struct { Kind string; MemberID *uuid.UUID; At time.Time }
type Tickets interface {
	Insert(ctx, t Ticket, key uuid.UUID, carrierKey string, since time.Time) (Ticket, bool, error) // bool: existed (key or order)
	SetFirstMessage(ctx, id, message uuid.UUID) error
	Get(ctx, id uuid.UUID) (Ticket, error)
	ByConversation(ctx, conversation uuid.UUID) (Ticket, error)
	ByOrder(ctx, account, order uuid.UUID) (Ticket, error)
	OfAccount(ctx, account uuid.UUID) ([]Ticket, error)
	Queue(ctx, status domain.Status, kind *domain.Kind, p page.Request) ([]Ticket, error)
	CountOpen(ctx) (int, error)
	CountOpenOf(ctx, account uuid.UUID) (int, error)
	SameCarrier(ctx, carrierKey string, since time.Time) (int, error)
	Messaged(ctx, conversation uuid.UUID, from domain.From, at time.Time) (reopened bool, err error)
	Resolve(ctx, id uuid.UUID, by *uuid.UUID, actor *audit.Actor, at time.Time) (Ticket, error)
	Reopen(ctx, id uuid.UUID, by *uuid.UUID, actor *audit.Actor, at time.Time) (Ticket, error)
	RecordReply(ctx, ticket, message uuid.UUID, member *uuid.UUID, actor *audit.Actor) error
	Members(ctx, messages []uuid.UUID) (map[uuid.UUID]Reply, error)
	ResolveAllOf(ctx, account uuid.UUID, at time.Time) error
}
type Reply struct { Member string; Automatic bool }
// audit: TicketReply "ticket.reply", TicketResolve "ticket.resolve", TicketReopen "ticket.reopen",
// TargetTicket "ticket", func Ticket(id) Target
```

- [ ] **Step 1: Write the failing domain tests**

```go
func TestNewTicketChecksEachKind(t *testing.T) {
	order := uuid.NewV7()
	cases := []struct {
		name, kind, carrier, body string
		order                     *uuid.UUID
		field                     string
	}{
		{"report without order", "not_received", "", "", nil, "order_id"},
		{"carrier without name", "carrier_request", "  ", "", nil, "carrier_name"},
		{"carrier name too long", "carrier_request", strings.Repeat("x", 51), "", nil, "carrier_name"},
		{"other without body", "other", "", " ", nil, "body"},
		{"unknown kind", "refund", "", "x", nil, "kind"},
		{"body too long", "other", "", strings.Repeat("ạ", 1001), nil, "body"},
	}
	for _, c := range cases {
		_, err := domain.NewTicket(c.kind, c.carrier, c.body, c.order)
		if fieldOf(err) != c.field {
			t.Errorf("%s: %v", c.name, err)
		}
	}
	if d, err := domain.NewTicket("not_received", "", "", &order); err != nil || d.OrderID == nil {
		t.Fatalf("a report: %+v %v", d, err)
	}
	if d, _ := domain.NewTicket("carrier_request", " Ninja Van ", "", nil); d.CarrierName != "Ninja Van" || d.CarrierKey != "ninja van" {
		t.Fatalf("carrier %+v", d)
	}
}

func TestCarrierKeyFoldsMarksAndCase(t *testing.T) {
	if domain.CarrierKey("  Giao Hàng  Nhanh ") != domain.CarrierKey("giao hang nhanh") {
		t.Fatal("not folded")
	}
	if domain.CarrierKey("Đường") != "duong" {
		t.Fatal("đ")
	}
}

func TestMayReport(t *testing.T) {
	buyer, now := uuid.NewV7(), time.Now()
	recent, old := now.Add(-6*24*time.Hour), now.Add(-8*24*time.Hour)
	cases := []struct {
		name string
		f    domain.OrderCheck
		want string
	}{
		{"shipped", domain.OrderCheck{BuyerID: buyer, Status: "shipped"}, ""},
		{"system completed 6 days ago", domain.OrderCheck{BuyerID: buyer, Status: "completed", CompletedBy: "system", ClosedAt: &recent}, ""},
		{"system completed 8 days ago", domain.OrderCheck{BuyerID: buyer, Status: "completed", CompletedBy: "system", ClosedAt: &old}, "ticket_not_allowed"},
		{"buyer completed", domain.OrderCheck{BuyerID: buyer, Status: "completed", CompletedBy: "buyer", ClosedAt: &recent}, "ticket_not_allowed"},
		{"pending", domain.OrderCheck{BuyerID: buyer, Status: "pending"}, "ticket_not_allowed"},
		{"not the buyer", domain.OrderCheck{BuyerID: uuid.NewV7(), Status: "shipped"}, "order_not_found"},
	}
	for _, c := range cases {
		if got := code(domain.MayReport(c.f, buyer, now)); got != c.want {
			t.Errorf("%s: %q", c.name, got)
		}
	}
}
```

- [ ] **Step 2: Implement the domain**

`ticket.go`: the types above. `NewTicket` trims, checks the kind, then per kind: `not_received` needs `order != nil`; `carrier_request` needs 1–50 runes of name and sets `CarrierKey`; `other` needs 1 rune of body; every body is at most `chatdomain.MaxText` runes. It collects every field into one `ErrInvalidTicket.WithField(...)`, as `chatdomain.NewMessage` does. `CarrierKey` copies `discoverydomain.HistoryKey`'s fold (lowercase, collapse spaces, NFD, drop `unicode.Mn`, NFC, `đ`→`d`), with a comment naming where it came from. `MayReport`: not the buyer → `ErrOrderNotFound`; `shipped` → nil; `completed` by `system` with `ClosedAt` within `ReportWindow` → nil; anything else → `ErrNotAllowed`. `errors.go` keeps only the ticket errors.

- [ ] **Step 3: Write the failing repository tests**

```go
func TestInsertKeepsTheRateAndTheKey(t *testing.T) {
	s, person := newTickets(t), seedAccount(t)
	since := time.Now().Add(-24 * time.Hour)
	key := uuid.NewV7()
	first, existed, err := s.Insert(ctx, newTicket(t, person, "other"), key, "", since)
	if err != nil || existed {
		t.Fatal(err)
	}
	again, existed, _ := s.Insert(ctx, newTicket(t, person, "other"), key, "", since)
	if again.ID != first.ID || !existed {
		t.Fatal("same key returns the first ticket")
	}
	for range 9 {
		if _, _, err = s.Insert(ctx, newTicket(t, person, "other"), uuid.NewV7(), "", since); err != nil {
			t.Fatal(err)
		}
	}
	if _, _, err = s.Insert(ctx, newTicket(t, person, "other"), uuid.NewV7(), "", since); code(err) != "too_many_tickets" {
		t.Fatalf("eleventh: %v", err)
	}
}

func TestOneTicketPerOrder(t *testing.T) {
	s, person := newTickets(t), seedAccount(t)
	order := seedShippedOrderOf(t, person)
	first, _, _ := s.Insert(ctx, reportOf(t, person, order), uuid.NewV7(), "", time.Now().Add(-24*time.Hour))
	second, existed, err := s.Insert(ctx, reportOf(t, person, order), uuid.NewV7(), "", time.Now().Add(-24*time.Hour))
	if err != nil || !existed || second.ID != first.ID {
		t.Fatalf("%v %v %v", second.ID, existed, err)
	}
}

func TestAPersonsMessageReopens(t *testing.T) {
	s, person := newTickets(t), seedAccount(t)
	tk, _, _ := s.Insert(ctx, newTicket(t, person, "other"), uuid.NewV7(), "", time.Now().Add(-24*time.Hour))
	if _, err := s.Resolve(ctx, tk.ID, nil, nil, time.Now()); err != nil {
		t.Fatal(err)
	}
	reopened, err := s.Messaged(ctx, tk.ConversationID, domain.FromPerson, time.Now())
	if err != nil || !reopened {
		t.Fatalf("%v %v", reopened, err)
	}
	got, _ := s.Get(ctx, tk.ID)
	if got.Status != domain.StatusOpen || got.Events[len(got.Events)-1].Kind != "reopened" {
		t.Fatalf("%+v", got)
	}
	if reopened, _ = s.Messaged(ctx, tk.ConversationID, domain.FromShopNexus, time.Now()); reopened {
		t.Fatal("ShopNexus's message does not reopen")
	}
}

func TestResolveWritesTheAudit(t *testing.T) {
	s, person, member := newTickets(t), seedAccount(t), seedMember(t)
	tk, _, _ := s.Insert(ctx, newTicket(t, person, "other"), uuid.NewV7(), "", time.Now().Add(-24*time.Hour))
	actor := audit.Actor{Kind: audit.ActorMember, MemberID: member}
	if _, err := s.Resolve(ctx, tk.ID, &member, &actor, time.Now()); err != nil {
		t.Fatal(err)
	}
	if n := countActions(t, "ticket.resolve", tk.ID); n != 1 {
		t.Fatalf("audit rows %d", n)
	}
	if _, err := s.Resolve(ctx, tk.ID, &member, &actor, time.Now()); code(err) != "ticket_not_allowed" {
		t.Fatalf("resolving twice: %v", err)
	}
}

func TestSameCarrierCountsThirtyDays(t *testing.T) {
	s := newTickets(t)
	for _, name := range []string{"Ninja Van", "ninja  van", "Ahamove"} {
		insertCarrier(t, s, seedAccount(t), name)
	}
	if n, _ := s.SameCarrier(ctx, domain.CarrierKey("NINJA VAN"), time.Now().Add(-30*24*time.Hour)); n != 2 {
		t.Fatalf("got %d", n)
	}
}
```

`newTicket` makes the support chat through SQL (an `INSERT INTO conversations … 'support'` and members), since the repository test does not run chat.

- [ ] **Step 4: Implement the store**

`tickets_pg.go`:

- `Insert`: one transaction; `pg_advisory_xact_lock(hashtext('tickets:' || @account))`; return the row with `(account_id, request_key)` if any (`existed = true`); for `not_received` return the row with `kind = 'not_received' AND order_id = @order` if any (`existed = true`); count `opened_at > @since` and refuse `domain.ErrTooMany` at `domain.DailyLimit`; insert the ticket with `status 'open'`, `last_from 'person'`, `last_message_at = opened_at`, and its `opened` event.
- `Get`, `ByConversation`, `ByOrder` (`account_id = @account AND order_id = @order`), `OfAccount` (open first, then `last_message_at DESC`), `Queue` (`status = @status AND (@kind::text IS NULL OR kind = @kind) AND id < @before ORDER BY last_message_at DESC, id DESC LIMIT @limit`; page on `id` like the other lists), `CountOpen`, `CountOpenOf`, `SameCarrier` (`kind = 'carrier_request' AND carrier_key = @key AND opened_at > @since`). Each read loads the ticket's events in a second query `WHERE ticket_id = ANY(@ids) ORDER BY at`.
- `Messaged`: `UPDATE tickets SET last_message_at = @at, last_from = @from, status = CASE WHEN @from = 'person' THEN 'open' ELSE status END, resolved_at = CASE WHEN @from = 'person' THEN NULL ELSE resolved_at END, resolved_by = … WHERE conversation_id = @conv RETURNING (old status)` — in Postgres 18 `RETURNING old.status` gives the status before the update; when it was `resolved` and `@from = 'person'`, insert the `reopened` event in the same transaction and return true. A conversation with no ticket (a pair chat) updates nothing and returns false.
- `Resolve` and `Reopen`: lock the row `FOR UPDATE`; `ErrNotFound`; a ticket already in the target status is `ErrNotAllowed`; update, insert the event, and when `actor != nil` `audit.Insert(ctx, tx, audit.Entry{Actor: *actor, Action: audit.TicketResolve, Target: audit.Ticket(id)})`.
- `RecordReply`: insert `ticket_replies`, and the `ticket.reply` audit row when `actor != nil`, with `Details: {"message_id": …}`.
- `Members`: `SELECT r.message_id, m.display_name, r.member_id IS NULL FROM ticket_replies r LEFT JOIN console_members m ON m.id = r.member_id WHERE r.message_id = ANY(@ids)`.
- `ResolveAllOf`: resolve every open ticket of the account with no member, each with its event.

`audit.go`: the three action kinds, `TargetTicket`, `func Ticket(id uuid.UUID) Target`.

- [ ] **Step 5: Run and commit**

Run (fresh stack): `go test ./internal/support/... ./internal/platform/audit/...`
Expected: PASS (service tests come in Task 7; delete the feedback service tests now so the package builds).

```bash
git add internal/support/ internal/platform/audit/
git commit -m "support: tickets, their events and replies, in place of feedback"
```

### Task 7: Support's use cases, flow, worker and HTTP

**Files:**
- Modify: `internal/support/service/service.go`, `internal/support/handler/handler.go`, `internal/support/support.go`, `internal/console/handler/handler.go`, `internal/console/console.go`
- Create: `internal/support/service/ticket_open.go`, `ticket_open_durable.go`, `ticket_list.go`, `console.go`, `internal/support/service/support_test.go`, `internal/support/worker/worker.go`, `internal/console/handler/support.go`
- Delete: `internal/console/handler/feedback.go`

**Interfaces:**
- Consumes: Task 3's chat service, Task 5's `OrderFacts`, Task 6's store, `catalogsvc.Service.Summary` for the order's title and photo, `accountsvc.Service` (`Status`, `GetMany`).
- Produces:

```go
type Service interface {
	Open(ctx context.Context, account uuid.UUID, key uuid.UUID, in OpenInput) (TicketView, bool, error) // bool: existed
	Mine(ctx context.Context, account uuid.UUID) ([]TicketListItem, error)
	Summary(ctx context.Context, account uuid.UUID) (SummaryView, error)
	OfOrder(ctx context.Context, account, order uuid.UUID) (TicketView, error)
	OfConversation(ctx context.Context, account, conversation uuid.UUID) (*TicketView, error) // nil for a pair chat
	Queue(ctx context.Context, status domain.Status, kind *domain.Kind, p page.Request) (page.Page[ConsoleTicket], error)
	Detail(ctx context.Context, id uuid.UUID) (ConsoleTicketDetail, error)
	Messages(ctx context.Context, id uuid.UUID, p page.Request) (page.Page[ConsoleMessage], error)
	Reply(ctx context.Context, id uuid.UUID, key string, in ReplyInput, by audit.Actor) (ConsoleMessage, error)
	Resolve(ctx context.Context, id uuid.UUID, by audit.Actor) (ConsoleTicket, error)
	Reopen(ctx context.Context, id uuid.UUID, by audit.Actor) (ConsoleTicket, error)
	OpenCount(ctx context.Context) (int, error)
	Durable() []restate.ServiceDefinition
}
type OpenInput struct { Kind, CarrierName, Body string; OrderID *uuid.UUID }
type ReplyInput struct { Body string; ReplyTo *uuid.UUID }
```

- [ ] **Step 1: Write the failing service tests**

`support_test.go` runs the real chat and deal services against the test stack, as `internal/deal/service` tests run catalog (look at its `helpers_test.go` for the pattern):

```go
func TestOpenOtherMakesAChatWithTheFirstMessage(t *testing.T) {
	env := newEnv(t)
	person := env.account(t)
	tk, existed, err := env.support.Open(ctx, person, uuid.NewV7(), service.OpenInput{Kind: "other", Body: "Lọc khu vực hay nhảy về Q.1"})
	if err != nil || existed || tk.FirstMessageID == nil {
		t.Fatalf("%+v %v %v", tk, existed, err)
	}
	msgs, _ := env.chat.Messages(ctx, person, tk.ConversationID, page.Request{})
	if len(msgs.Items) != 1 || msgs.Items[0].Text != "Lọc khu vực hay nhảy về Q.1" || msgs.Items[0].SenderID != person {
		t.Fatalf("%+v", msgs.Items)
	}
}

func TestReportTwiceReturnsTheTicket(t *testing.T) {
	env := newEnv(t)
	buyer, order := env.shippedOrder(t)
	first, _, _ := env.support.Open(ctx, buyer, uuid.NewV7(), service.OpenInput{Kind: "not_received", OrderID: &order})
	again, existed, err := env.support.Open(ctx, buyer, uuid.NewV7(), service.OpenInput{Kind: "not_received", OrderID: &order})
	if err != nil || !existed || again.ID != first.ID {
		t.Fatalf("%v %v %v", again.ID, existed, err)
	}
}

func TestReportRefusesTheSeller(t *testing.T) {
	env := newEnv(t)
	_, order, seller := env.shippedOrderWithSeller(t)
	if _, _, err := env.support.Open(ctx, seller, uuid.NewV7(), service.OpenInput{Kind: "not_received", OrderID: &order}); code(err) != "order_not_found" {
		t.Fatalf("got %v", err)
	}
}

func TestSuspendedPersonOpensATicket(t *testing.T) {
	env := newEnv(t)
	person := env.account(t)
	env.suspend(t, person)
	if _, _, err := env.support.Open(ctx, person, uuid.NewV7(), service.OpenInput{Kind: "other", Body: "Vì sao?"}); err != nil {
		t.Fatal(err)
	}
}

func TestReplyGoesOutAsShopNexusAndRecordsTheMember(t *testing.T) {
	env := newEnv(t)
	person := env.account(t)
	tk, _, _ := env.support.Open(ctx, person, uuid.NewV7(), service.OpenInput{Kind: "other", Body: "Hỏi"})
	member := env.member(t, "Lan")
	m, err := env.support.Reply(ctx, tk.ID, uuid.NewString(), service.ReplyInput{Body: "Chào bạn"}, audit.Actor{Kind: audit.ActorMember, MemberID: member})
	if err != nil || m.Message.SenderID != accountdomain.ShopNexusID || m.Member != "Lan" {
		t.Fatalf("%+v %v", m, err)
	}
}

func TestResolvingACarrierRequestSendsTheNote(t *testing.T) {
	env := newEnv(t)
	seller := env.account(t)
	tk, _, _ := env.support.Open(ctx, seller, uuid.NewV7(), service.OpenInput{Kind: "carrier_request", CarrierName: "Ninja Van"})
	if _, err := env.support.Resolve(ctx, tk.ID, env.memberActor(t)); err != nil {
		t.Fatal(err)
	}
	page, _ := env.support.Messages(ctx, tk.ID, pagereq())
	last := page.Items[0]
	if last.Message.Text != "Đã ghi nhận hãng Ninja Van." || !last.Automatic {
		t.Fatalf("%+v", last)
	}
}

func TestAPersonsMessageReopensThroughTheWorker(t *testing.T) {
	env := newEnv(t)
	person := env.account(t)
	tk, _, _ := env.support.Open(ctx, person, uuid.NewV7(), service.OpenInput{Kind: "other", Body: "Hỏi"})
	_, _ = env.support.Resolve(ctx, tk.ID, env.memberActor(t))
	_, _ = env.chat.Send(ctx, person, tk.ConversationID, uuid.NewString(), chatsvc.SendInput{Text: "Còn nữa"})
	testenv.Eventually(t, func() bool {
		d, _ := env.support.Detail(ctx, tk.ID)
		return d.Ticket.Ticket.Status == "open" && d.Ticket.LastFrom == "person"
	})
}
```

- [ ] **Step 2: Implement the use cases**

`ticket_open.go`, `Open` (reads top to bottom):

```go
// Open checks the request, then runs TicketOpen once per account and key.
// A not_received ticket for an order that has one returns it with existed.
func (s *Support) Open(ctx context.Context, account, key uuid.UUID, in OpenInput) (TicketView, bool, error) {
	if _, err := domain.NewTicket(in.Kind, in.CarrierName, in.Body, in.OrderID); err != nil {
		return TicketView{}, false, err
	}
	res, err := s.open.Call(ctx, account.String()+"/"+key.String(), OpenFlowInput{Account: account, Key: key, Input: in})
	if err != nil {
		return TicketView{}, false, err
	}
	t, err := s.tickets.Get(ctx, res.TicketID)
	if err != nil {
		return TicketView{}, false, fmt.Errorf("read the ticket: %w", err)
	}
	v, err := s.view(ctx, t)
	return v, res.Existed, err
}
```

`ticket_open_durable.go`, `TicketOpen.Run(ctx restate.Context, in OpenFlowInput) (OpenResult, error)`:

1. `at := restatex.Now`; `ticketID, convID := restatex.NewID(ctx, at)` twice.
2. Step "facts": the account's status (refuse any refusal except `StatusSuspended`); for `not_received`, `s.deals.Order(rc, *in.Input.OrderID)` → not found or `!ok` is `domain.ErrOrderNotFound`, else `domain.MayReport(...)`. A refusal returns `OpenResult{Refused: …}` as data, as chat's flow does.
3. Step "existing": `tickets.ByOrder` for `not_received`; found → return `{TicketID, Existed: true}` without opening a chat.
4. Step "chat": `s.chat.OpenSupport(rc, in.Account, convID)`.
5. Step "insert": `tickets.Insert(rc, repository.Ticket{ID: ticketID, AccountID: in.Account, ConversationID: convID, Kind, OrderID, CarrierName, OpenedAt: at}, in.Key, draft.CarrierKey, at.Add(-24*time.Hour))` → `ErrTooMany` returns as a refusal; `existed` returns that ticket (the request key or a race on the order).
6. Send the first message: `restate.Service[chatsvc.SendResult](ctx, s.prefix+chatsvc.MessageSendName, "Run").Request(chatsvc.SendFlowInput{Sender: in.Account, ConversationID: convID, Text: draft.Body, OpensTicket: true}, restate.WithIdempotencyKey(ticketID.String()))`; a refusal is returned.
7. Step "first": `tickets.SetFirstMessage(rc, ticketID, sent.MessageID)`.
8. Return `{TicketID: ticketID}`.

`ticket_list.go`: `Mine` (tickets of the account, `chat.Threads` for their conversations, `view` each, open first), `Summary` (`CountOpenOf`, `chat.SupportUnread`, `latest_unread` = the newest item of `Mine` with `Unread > 0`), `OfOrder`, `OfConversation` (`ByConversation`; not found → nil; another account's → nil).

`view(ctx, t)` builds `TicketView{ID, Kind, Status, ConversationID, FirstMessageID, Order *TicketOrder, CarrierName, OpenedAt, Events}`; for `not_received` it reads `deals.Order` and `catalog.Summary(listing)` for the title and first photo.

`console.go`: `Queue` (store page, `accounts.GetMany` for the persons, `chat.Threads` read as ShopNexus for each last text), `Detail` (ticket, person status and created_at from `accounts`, order with the seller's `PersonView` from `accounts.GetMany`, `SameCarrier` over 30 days for a carrier request, `OfAccount` minus this ticket, the first page of `Messages`), `Messages` (`chat.Messages(ctx, accountdomain.ShopNexusID, conv, p)`, then `tickets.Members` for the page's ids), `Reply` (`chat.Send(ctx, accountdomain.ShopNexusID, conv, key, chatsvc.SendInput{Text, ReplyTo})`, then `RecordReply(ctx, t.ID, m.ID, &by.MemberID, &by)`), `Resolve` (store `Resolve`; for `carrier_request`, `chat.Send(ShopNexus, conv, "resolve/"+t.ID+"/"+eventCount, {Text: "Đã ghi nhận hãng " + name + "."})` then `RecordReply(ctx, t.ID, m.ID, nil, nil)`), `Reopen`, `OpenCount`.

- [ ] **Step 3: The worker**

`internal/support/worker/worker.go`:

```go
// Worker follows chat and accounts: Mount subscribes MessageSent to
// message.sent and AccountDeleted to account.deleted.
type Worker struct {
	Prefix  string
	Chats   chatsvc.Service
	Tickets repository.Tickets
	Now     func() time.Time
}

func (w Worker) ServiceName() string { return w.Prefix + "SupportWorker" }

// MessageSent moves the ticket of a support chat's message: the person's
// message reopens a resolved ticket and asks for an answer; ShopNexus's
// marks it answered.
func (w Worker) MessageSent(ctx restate.Context, e events.Event) error {
	return restate.RunVoid(ctx, func(rc restate.RunContext) error {
		f, found, err := w.Chats.MessageFacts(rc, e.SubjectID)
		if err != nil || !found || f.Kind != chatdomain.KindSupport {
			return err
		}
		from := domain.FromPerson
		if f.RecipientID != accountdomain.ShopNexusID {
			from = domain.FromShopNexus
		}
		_, err = w.Tickets.Messaged(rc, f.ConversationID, from, e.OccurredAt)
		return err
	})
}

// AccountDeleted resolves the account's open tickets.
func (w Worker) AccountDeleted(ctx restate.Context, e events.Event) error {
	return restate.RunVoid(ctx, func(rc restate.RunContext) error {
		return w.Tickets.ResolveAllOf(rc, e.SubjectID, e.OccurredAt)
	})
}
```

Wrap errors with `fmt.Errorf` as the linter's wrapcheck wants.

- [ ] **Step 4: HTTP**

`internal/support/handler/handler.go` registers `GET /v1/support/tickets`, `POST /v1/support/tickets` (201, or 200 when `existed`), `GET /v1/support/summary`, `GET /v1/support/orders/{order_id}/ticket`, each behind `protect`, each a handler that reads top to bottom like today's `Send`.

`internal/console/handler/support.go`: `ListTickets`, `GetTicket`, `ListTicketMessages`, `ReplyTicket` (Idempotency-Key header), `ResolveTicket`, `ReopenTicket`, `SupportSummary`, each with `httpx.ConsoleCaller` for the actor where it writes. `handler.go` registers them behind `mod(...)`, drops `/v1/console/feedback`, and its `feedback supportsvc.Service` field becomes `support supportsvc.Service`. `console.Mount` takes the support service under the same name.

`support.go`'s `Mount(d module.Deps, accounts accountsvc.Service, chats chatsvc.Service, deals dealsvc.Service, catalog catalogsvc.Service) module.Mounted[service.Service]`: builds the service, registers the handler, subscribes the worker (`d.Events.Subscribe(events.MessageSent, w.ServiceName(), "MessageSent")` and `AccountDeleted`), and returns `Services: append(svc.Durable(), restate.Reflect(w))`.

- [ ] **Step 5: Run and commit**

Run (fresh stack): `go test ./internal/support/... ./internal/console/...`
Expected: PASS.

```bash
git add internal/support/ internal/console/
git commit -m "support: open, list, reply, resolve and reopen tickets"
```

### Task 8: Trust, notification and screen

**Files:**
- Modify: `internal/trust/worker/scam.go`, the trust report and block use cases (`internal/trust/service/report*.go`, and the block use case wherever `accounts.Block` is reached from an endpoint), `internal/notification/worker/worker.go`, `internal/screen/service/chat.go`, `internal/screen/service/service.go`, `internal/screen/screen.go`
- Test: `internal/trust/worker/scam_test.go` (or the nearest test file), `internal/notification/worker/worker_test.go`, `internal/screen/service/chat_test.go`

- [ ] **Step 1: Write the failing tests**

- Trust: `TestNoScamCheckInASupportChat` (a support message sends no `ScamCheck.Run`; with the existing fake Restate context, assert no send). `TestReportingASupportChatIsRefused` (`conversation_is_support`). `TestBlockingShopNexusIsRefused` (`conversation_is_support` when the person blocks `ShopNexusID`).
- Notification: `TestASupportReplyIsTitledShopNexus` (`MessageFacts.Kind == support` gives `Title "ShopNexus"`, `Data["type"] == "support_message"`, `Data["target_id"]` the conversation).
- Screen: `TestTheChatScreenCarriesTheTicket` (the screen of a support chat has `Ticket` with the ticket's kind; a pair chat has none).

- [ ] **Step 2: Implement**

- `scam.go`: return `uuid.UUID{}` from the step when `f.Kind == chatdomain.KindSupport`.
- Reports and blocks: refuse `chatdomain.ErrSupportConversation` when the reported conversation is a support chat or the blocked account is `ShopNexusID`.
- `worker.go`: `Title: "ShopNexus"` and `"type": "support_message"` when `f.Kind == chatdomain.KindSupport`; the body is `f.Text` (or `domain.ChatBody("", …)` for photos).
- `screen`: `ChatScreen.Ticket *supportsvc.TicketView \`json:"ticket,omitempty"\``; `Chat` calls `s.support.OfConversation(ctx, account, conversation)`; deals and the scam warning stay as they are (both empty for a support chat). `screen.Mount` takes the support service.

- [ ] **Step 3: Run and commit**

Run (fresh stack): `go test ./internal/trust/... ./internal/notification/... ./internal/screen/...`
Expected: PASS.

```bash
git add internal/trust/ internal/notification/ internal/screen/
git commit -m "trust, notification, screen: support chats have no scam check and push as ShopNexus"
```

### Task 9: Wiring, e2e and the architecture notes

**Files:**
- Modify: `internal/app/app.go`, `ARCHITECTURE.md`, `e2e/client_test.go` (if a helper is needed)
- Create: `e2e/support_test.go`
- Delete: any e2e test of `/v1/feedback`

- [ ] **Step 1: Write the failing e2e tests**

```go
func TestSupportFromReportToReply(t *testing.T) {
	s := newStack(t)
	buyer, seller := s.person(t), s.seller(t)
	order := s.shippedOrder(t, buyer, seller) // linked through the fake carrier
	var tk struct{ ID, ConversationID string `json:"conversation_id"` }
	s.post(t, buyer, "/v1/support/tickets", map[string]any{"kind": "not_received", "order_id": order}, 201, &tk)
	s.post(t, buyer, "/v1/support/tickets", map[string]any{"kind": "not_received", "order_id": order}, 200, nil)

	member := s.consoleModerator(t)
	var queue struct{ Items []struct{ Ticket struct{ ID string } `json:"ticket"`; LastFrom string `json:"last_from"` } }
	member.get(t, "/v1/console/support/tickets?status=open", 200, &queue)
	if len(queue.Items) == 0 || queue.Items[0].Ticket.ID != tk.ID || queue.Items[0].LastFrom != "person" {
		t.Fatalf("queue %+v", queue)
	}
	member.post(t, "/v1/console/support/tickets/"+tk.ID+"/replies", map[string]any{"body": "Chào bạn"}, 201, nil)

	var msgs struct{ Items []struct{ SenderID string `json:"sender_id"`; Text string } }
	s.get(t, buyer, "/v1/conversations/"+tk.ConversationID+"/messages", 200, &msgs)
	if msgs.Items[0].Text != "Chào bạn" || msgs.Items[0].SenderID != shopNexusID {
		t.Fatalf("%+v", msgs.Items[0])
	}
	s.waitPush(t, buyer, "ShopNexus") // the fake push sender records titles
	member.post(t, "/v1/console/support/tickets/"+tk.ID+"/resolve", nil, 200, nil)
	s.post(t, buyer, "/v1/conversations/"+tk.ConversationID+"/messages", map[string]any{"text": "Vẫn chưa nhận"}, 201, nil)
	s.eventually(t, func() bool {
		var d struct{ Ticket struct{ Ticket struct{ Status string } `json:"ticket"` } `json:"ticket"` }
		member.get(t, "/v1/console/support/tickets/"+tk.ID, 200, &d)
		return d.Ticket.Ticket.Status == "open"
	})
}

func TestSupportStaysOutOfTinNhan(t *testing.T) {
	s := newStack(t)
	person := s.person(t)
	s.post(t, person, "/v1/support/tickets", map[string]any{"kind": "other", "body": "Hỏi"}, 201, nil)
	var inbox struct{ Items []any }
	s.get(t, person, "/v1/me/inbox", 200, &inbox) // the inbox path the app reads; check its name in openapi.yaml
	if len(inbox.Items) != 0 {
		t.Fatalf("inbox %+v", inbox.Items)
	}
}

func TestReplyBySwipeQuotes(t *testing.T) {
	s := newStack(t)
	buyer, seller := s.person(t), s.seller(t)
	conv, first := s.openChat(t, buyer, seller, "Còn bảo hành không?")
	var m struct{ ReplyTo struct{ Text string } `json:"reply_to"` }
	s.post(t, seller, "/v1/conversations/"+conv+"/messages", map[string]any{"text": "Còn 3 tháng", "reply_to": first}, 201, &m)
	if m.ReplyTo.Text != "Còn bảo hành không?" {
		t.Fatalf("%+v", m)
	}
}
```

Use the helper names `client_test.go` has; add `consoleModerator`, `waitPush` and `shippedOrder` there if they are missing (the order-flow and carriers e2e files have the order steps).

- [ ] **Step 2: Wire**

In `app.go`: drop the early `support.Mount`; after `chat.Mount` and `deal.Mount` (and before `screen.Mount` and `console.Mount`), `supportm := support.Mount(d, accounts, chatm.Service, dealm.Service, catalogm.Service)`; bind `supportm.Services`; pass `supportm.Service` to `console.Mount` and `screen.Mount`. Move `console.Mount` below it.

- [ ] **Step 3: Run the whole suite**

Run the two halves and the linter as Global Constraints say.
Expected: e2e PASS, unit PASS, `golangci-lint` 0 issues. Run `make depguard` if the linter reports a new import between modules (support → chat, deal, catalog services are allowed; repositories are not).

- [ ] **Step 4: ARCHITECTURE.md**

Add a "Support" section: the ShopNexus account and its id; `pair` and `support` conversations; why support chats stay out of the inbox; the ticket's life (open flow, worker, reopen); members answer as ShopNexus with `ticket_replies`; the 7-day window and `completed_by`; quoted replies. Run the prose checker on the section.

- [ ] **Step 5: Commit**

```bash
git add internal/app/ e2e/ ARCHITECTURE.md
git commit -m "app: mount support after chat and deal; e2e for tickets and quotes"
```

## Console

### Task 10: Hỗ trợ

**Files:**
- Create: `src/lib/support.ts`, `src/routes/Support.tsx`
- Modify: `src/App.tsx`, `src/lib/navigation.tsx`, `src/components/Shell.tsx`, `DESIGN.md`

Follow the mockups `support-open` and `support-resolved` (open them from `console/.superdesign/mockups/` in a browser) and `console/.superdesign/design-system.md` § Hỗ trợ.

- [ ] **Step 1: The API layer**

`src/lib/support.ts`: types copied from `api/schemas/console.yaml` and `support.yaml` (`TicketKind`, `TicketStatus`, `Ticket`, `ConsoleTicket`, `ConsoleTicketDetail`, `ConsoleMessage`); hooks with TanStack Query:

```ts
export const kindLabel: Record<TicketKind, string> = {
  not_received: 'Báo chưa nhận hàng',
  carrier_request: 'Xin thêm hãng',
  other: 'Yêu cầu khác',
}

export function useQueue(status: TicketStatus, kind: TicketKind | null) {
  const q = new URLSearchParams({ status, limit: '50', ...(kind ? { kind } : {}) })
  return useQuery({ queryKey: ['support', 'queue', status, kind], queryFn: () => api<Page<ConsoleTicket>>(`/console/support/tickets?${q}`), refetchOnWindowFocus: true })
}

export function useTicket(id: string | undefined) {
  return useQuery({ queryKey: ['support', 'ticket', id], enabled: !!id, queryFn: () => api<ConsoleTicketDetail>(`/console/support/tickets/${id}`), refetchOnWindowFocus: true })
}

export function useOpenCount() {
  return useQuery({ queryKey: ['support', 'summary'], queryFn: () => api<{ open: number }>('/console/support/summary'), refetchOnWindowFocus: true })
}

export function useTicketCommands(id: string) {
  const client = useQueryClient()
  const done = () => client.invalidateQueries({ queryKey: ['support'] })
  return {
    reply: useMutation({ mutationFn: (body: string) => api<ConsoleMessage>(`/console/support/tickets/${id}/replies`, { method: 'POST', body: JSON.stringify({ body }), headers: { 'idempotency-key': crypto.randomUUID() } }), onSuccess: done }),
    resolve: useMutation({ mutationFn: () => post<ConsoleTicket>(`/console/support/tickets/${id}/resolve`), onSuccess: done }),
    reopen: useMutation({ mutationFn: () => post<ConsoleTicket>(`/console/support/tickets/${id}/reopen`), onSuccess: done }),
  }
}
```

(`Page` is the type `Home.tsx` imports; move it to `api.ts` if it lives in `Home.tsx`.)

- [ ] **Step 2: The route**

`src/routes/Support.tsx` exports `Support`: `Shell title="Hỗ trợ"`, then a 360 px queue panel (segmented Đang mở · n / Đã xử lý, kind chips Tất cả / Chưa nhận hàng / Xin thêm hãng / Khác, rows as in the mockup with "Chờ trả lời" when `last_from === 'person'`, footer `j` `k`), and the ticket panel for `useParams().id`: header (kind icon in a 40 px circle, title, status chip, "<name> · Mở <time>" or "Đã xử lý <time> · <member>", "Đã xử lý" filled or "Mở lại" outlined, close `Esc`), the thread (day labels, the first message as the ticket card, the person's bubbles on the start side, ShopNexus's on the end side with "<member> · <time>" or "Tự gửi khi đóng · <time>", event lines from `ticket.events`), the composer (textarea "Trả lời <name>", send on the button or Ctrl+Enter, "Người dùng thấy tên ShopNexus" under it), and the 272 px fact column (Người gửi, Đơn liên quan or Yêu cầu with "Cùng xin hãng này", Ticket khác). Facts put the label over the value. Keyboard: `j`/`k` move the selection in the queue and navigate to it, Enter is the same, Escape goes to `/support`. Only the tokens in `src/styles/tokens.css`.

`App.tsx`: `{ path: '/support', element: <Support /> }` and `{ path: '/support/:id', element: <Support /> }`. `navigation.tsx`: `{ to: '/support', label: 'Hỗ trợ', icon: <IconSupport …/> }` second, using `~icons/material-symbols/support-agent-rounded`. `Shell.tsx` shows `useOpenCount().data?.open` as a plain label at the end of that item.

- [ ] **Step 3: Check**

Run: `bun run lint && bun run build`
Expected: no lint errors; build writes `dist/`.

Walk: the server worktree with `make run`, a moderator from `go run ./cmd/console create-admin` (an admin sees Hỗ trợ too), a ticket opened with `curl` as a test person (the e2e helpers show how to get a token in dev); `bun run dev`; open `/support`, reply, resolve, reopen, and check the drawer count. Screenshot `/support/<id>` at 1440 × 900 into `tmp/` and compare it with `support-open`.

- [ ] **Step 4: DESIGN.md and commit**

`DESIGN.md`: the drawer lists Hỗ trợ; the duties line adds support tickets. Prose checker, then:

```bash
git add src/ DESIGN.md
git commit -m "feat: Hỗ trợ, the ticket queue and a ticket beside it"
```

## App

### Task 11: Model and fake data

**Files:**
- Create: `core/model/src/main/kotlin/vn/shopnexus/core/model/Support.kt`, `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/FakeSupportRepository.kt`, its test
- Modify: `core/model/.../Thread.kt`, `core/data/.../Repositories.kt`, `core/data/.../fake/FakeWorld.kt`, the Hilt data module, fixtures under `core/data/src/main/assets` (or wherever `account.json` lives)

- [ ] **Step 1: Write the failing tests**

`FakeSupportRepositoryTest`: `openOther` adds a ticket whose thread starts with the card; `report` twice for one order returns one ticket; `report` on an order completed by the buyer fails with `DataError.Conflict("ticket_not_allowed")`; a message in a resolved ticket reopens it and adds the "Đã mở lại" event; ShopNexus answers once 1.5 s after the person's first message (virtual time); `summary()` counts open tickets and unread replies; reading a ticket clears its unread.

- [ ] **Step 2: Implement**

`Support.kt`:

```kotlin
@Serializable enum class TicketKind { NOT_RECEIVED, CARRIER_REQUEST, OTHER }
@Serializable enum class TicketStatus { OPEN, RESOLVED }
@Serializable data class TicketId(val value: String)
@Serializable data class TicketAbout(val orderTitle: String? = null, val photo: String? = null, val carrier: String? = null, val trackingCode: String? = null, val carrierName: String? = null)
@Serializable data class Ticket(val id: TicketId, val kind: TicketKind, val status: TicketStatus, val about: TicketAbout, val openedAt: Moment, val orderId: DealId? = null)
@Serializable data class TicketRow(val ticket: Ticket, val last: LastMessage?, val unread: Int)
@Serializable data class SupportSummary(val open: Int, val unread: Int, val latestUnread: TicketRow?)
```

`Thread.kt`: `ThreadItem.Text` and `ThreadItem.Photos` gain `quote: Quote? = null`; `@Serializable data class Quote(val by: Party?, val text: String)` where `by == null` is ShopNexus; new `ThreadItem.TicketCard(val ticket: Ticket, val text: String?, override val at: Moment)`.

`Repositories.kt`: `interface SupportRepository { fun tickets(): Flow<List<TicketRow>>; fun ticket(id: TicketId): Flow<Ticket?>; fun thread(id: TicketId): Flow<List<ThreadItem>>; fun summary(): Flow<SupportSummary>; fun ticketOfOrder(order: DealId): Flow<TicketId?>; suspend fun open(kind: TicketKind, order: DealId? = null, carrierName: String? = null, text: String? = null): Result<TicketId>; suspend fun send(id: TicketId, text: String, quote: Quote? = null): Result<Unit>; suspend fun read(id: TicketId) }`. `SettingsRepository.sendFeedback` goes.

`FakeSupportRepository` keeps tickets in `FakeWorld`, seeded with the mockup's three: Báo chưa nhận hàng for iPhone X (open, answered, 1 unread), Xin thêm hãng Ninja Van (open), Yêu cầu khác about the area filter (resolved). Bind it in the Hilt module.

- [ ] **Step 3: Run and commit**

Run: `./gradlew :core:model:check :core:data:check`
Expected: PASS.

```bash
git commit -am "feat(app): tickets and quotes in the model, a fake ShopNexus"
```

### Task 12: One chat for deals and tickets, and reply by swipe

**Files:**
- Modify: `core/navigation/.../Routes.kt`, `feature/deal/.../chat/ChatScreen.kt`, `ChatUiState.kt`, `ChatViewModel.kt`, `Thread.kt`, `Composer.kt`, `DealInstaller.kt`
- Create: `feature/deal/.../chat/TicketChatViewModel.kt`
- Test: `feature/deal/src/test/.../chat/ChatScreenTest.kt`, `TicketChatViewModelTest.kt`, `SwipeReplyTest.kt`

The mockups: `chat` (swipe) and `support-chat` (`#reported`, `#resolved`, `#new`), and `app/.superdesign/design-system.md` § Chat thread and § Hỗ trợ.

- [ ] **Step 1: Write the failing tests**

- `ChatScreenTest`: with `ChatUiState.header = ChatHeader.Ticket(kind, status)` the screen has no deal console, no quick replies, no scam banner and no menu, shows "Báo chưa nhận hàng" and "ShopNexus · Đang xử lý", and draws the first item as the ticket card.
- `SwipeReplyTest` (Robolectric, both headers): dragging a bubble 80 dp right shows the strip "Trả lời Tuấn Kiệt" (or "Trả lời ShopNexus"); 40 dp does not; a vertical drag scrolls and shows no strip; sending puts the quote on the new bubble; the close button drops the strip; TalkBack's "Trả lời" custom action on a bubble does the same as the swipe.
- `TicketChatViewModelTest`: a message in a resolved ticket makes the status "Đang xử lý"; `#new` (a route with no ticket id and kind OTHER) has an empty thread and the first send opens a ticket.

- [ ] **Step 2: Implement**

- `Routes.kt`: `@Serializable data class TicketChatRoute(val ticketId: String? = null, val newKind: String? = null) : NavKey`; deep link `"ticket" -> TicketChatRoute(id)`.
- `ChatUiState` gains `header: ChatHeader` (`sealed interface ChatHeader { data class Deal(...today's listing header fields...) ; data class Ticket(val kind: TicketKind, val status: TicketStatus) }`) and `replying: Quote? = null`. `ChatScreen` draws the app bar from `header`, and skips the console, quick replies, scam banner and menu for `ChatHeader.Ticket`. Nothing else forks: thread, bubbles, photos, read marks, typing dots, day labels and the composer are the same composables.
- `ChatEvent.ReplyTo(itemKey)` and `ChatEvent.DropReply`; `ChatViewModel` and `TicketChatViewModel` both handle them and pass the quote to their repository's send.
- `Thread.kt`: `Modifier.swipeToReply(enabled, onReply)` on bubbles, photos and the card: horizontal drag with `draggable`, the offset follows up to 72 dp with resistance after, a 32 dp reply icon behind it fading in to 56 dp, `HapticFeedbackType.LongPress`-strength tick (use `TextHandleMove` if that is the gentler one on the test device) when crossing 56 dp, spring back on release (`spring(dampingRatio = 0.8f)`), reply when released past 56 dp; `semantics { customActions = listOf(CustomAccessibilityAction("Trả lời") { onReply(); true }) }`. The quote draws at the top of a bubble on `surfaceContainerLowest` with a 3 dp `primary` bar, the name in `labelMedium` `primary` ("Bạn", the other person's name, or "ShopNexus") and at most 2 lines; tapping it scrolls the list to the quoted item and outlines it for 1.2 s.
- `Composer.kt`: the strip above the field when `replying != null`.
- `TicketChatViewModel` (`@HiltViewModel`, assisted with the route) reads `SupportRepository.ticket`, `thread`, marks read on open, sends through `send`, and for a new request calls `open(OTHER, text = …)` on the first send and switches to that ticket.
- `DealInstaller.kt`: `entry<TicketChatRoute> { route -> TicketChatEntry(route, navigator) }` that builds `ChatScreen` with the ticket view model.

- [ ] **Step 3: Run and commit**

Run: `./gradlew :feature:deal:check :core:navigation:check :app:hiltJavaCompileDebug`
Expected: PASS apart from the pre-existing failures.

```bash
git commit -am "feat(app): a ticket's chat is Chat; reply by swiping a message"
```

### Task 13: The support screens

**Files:**
- Create: `feature/support/` (module: `SupportInstaller.kt`, `list/SupportListScreen.kt`, `list/SupportListViewModel.kt`, `sheets/ReportSheet.kt`, `sheets/CarrierRequestSheet.kt`, tests), registered in `settings.gradle.kts` and `app`
- Modify: `feature/me/.../MeScreen.kt` and its view model, the navigation bar's badges (`core/ui` or `app`, wherever `NavigationBar` items read badges), `feature/settings/.../help/HelpScreen.kt`, `HelpViewModel.kt`, `feature/orders/.../cod/CodOrderScreen.kt`, `CodOrderViewModel.kt`, `feature/orders/.../ship/ShipOrderScreen.kt`, `feature/codsetup/...` (the carrier step)

The mockups: `support-list`, `me-support`, `help`, `support-report` (and `#reported`), `support-carrier`.

- [ ] **Step 1: Write the failing tests**

- `SupportListScreenTest`: "Đang xử lý" lists the two open tickets with the unread badge on the first, "Đã xử lý" the resolved one; a row opens `TicketChatRoute(id)`; "Yêu cầu mới" opens `TicketChatRoute(newKind = "OTHER")`.
- `MeScreenTest`: with an unread reply the card "ShopNexus đã trả lời" sits above the order block and opens the ticket; the Tôi tab has the dot; with none, neither; "Trợ giúp và an toàn" reads "2 yêu cầu đang xử lý".
- `HelpScreenTest`: "Yêu cầu hỗ trợ" with "2 đang xử lý" opens the list; no "Gửi góp ý".
- `CodOrderScreenTest`: a shipped order shows "Báo chưa nhận hàng"; the sheet sends and lands in the ticket's chat; after that the order shows "Xem yêu cầu"; an order completed by the buyer shows neither.
- `ShipOrderScreenTest` and the Thiết lập COD carrier step: "Hãng của bạn chưa có?" opens the sheet; "Gửi yêu cầu" is disabled while the name is blank; a chip fills the name.

- [ ] **Step 2: Implement**

Build each screen from its mockup with the design system's tokens. The report sheet: order row, the carrier's delivered line when the fake carrier reported it, "Chuyện gì đã xảy ra (không bắt buộc)", "<seller> không thấy báo cáo này. Đơn giữ nguyên.", "Gửi cho ShopNexus". The carrier sheet: "Tên hãng", chips Ninja Van, BEST Express, Ahamove, Lalamove, "Ghi chú (không bắt buộc)", "ShopNexus trả lời trong chat Hỗ trợ.", "Gửi yêu cầu". The Tôi tab dot is a 6 dp `error` dot while `summary.unread > 0`; Tin nhắn's badge stays as it is.

- [ ] **Step 3: Run and commit**

Run: `./gradlew :feature:support:check :feature:me:check :feature:settings:check`, then `./gradlew :feature:orders:check :feature:codsetup:check :app:hiltJavaCompileDebug`.
Expected: PASS apart from the pre-existing failures.

```bash
git commit -am "feat(app): Hỗ trợ, the reply card on Tôi, and the two ticket sheets"
```

### Task 14: The gate

- [ ] **Step 1:** `./gradlew spotlessApply` (read its `BUILD` line), then `./gradlew :app:assembleDebug` and the app walk tests (`:app:testDebugUnitTest`), in at most three-module groups for `check`.
- [ ] **Step 2:** README: one sentence that tickets run against a fake ShopNexus. Prose checker.
- [ ] **Step 3:** `./gradlew --stop`; `pgrep -fa '[G]radleDaemon|[K]otlinCompileDaemon'` prints nothing.
- [ ] **Step 4:** Commit `docs(app): tickets run on a fake ShopNexus`.

## Self-review

- Spec coverage: kinds and rules (Tasks 6, 7), one chat per ticket and the kind (2, 3), ShopNexus account (2, 4), where the person finds tickets and the Tôi card (13), Báo chưa nhận hàng window and one per order (5, 6, 7, 13), Xin thêm hãng and the closing note (6, 7, 13), Yêu cầu khác from "Yêu cầu mới" (12), status and reopen (6, 7), console (7, 10), feedback move (2, 6), rate (6), reply by swipe (3, 12), no scam check, archive, block or report (3, 8), push title (8), inbox exclusion (3, 9).
- The spec's `ConversationView.ticket` and the `as` parameter changed by ruling; the console's 90-day line and carrier history changed by ruling.
- Names: `OpenSupport`, `Threads`, `SupportUnread`, `MessageSendName`, `OpensTicket`, `ReplyTo`, `ShopNexusID`, `ErrSystemAccount`, `ErrSupportConversation`, `MayReport`, `CarrierKey` match between the interface block and the tasks.
