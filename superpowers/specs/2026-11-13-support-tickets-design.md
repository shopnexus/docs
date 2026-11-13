# Design: support tickets

Date: 2026-11-13.
Status: decided in conversation, question by question, with the mockups
on the Superdesign canvas. Part 3 of the order flow
(`2026-11-12-order-flow-sync-design.md`, Scope). When the work lands, the
server decisions go into `server/ARCHITECTURE.md`.

## Scope

A person writes to ShopNexus through a ticket. Three kinds:

- `not_received`: "Báo chưa nhận hàng" on an order, from the buyer.
- `carrier_request`: "Xin thêm hãng", a seller whose carrier ShopNexus
  cannot read yet.
- `other`: "Yêu cầu khác", anything else, which replaces today's feedback
  from Trợ giúp.

Every ticket is its own chat between the person and ShopNexus, and it is
the chat of module chat: the same messages, photos, read markers, realtime
frames and pushes as a chat between two people. People at ShopNexus answer
in the console, as ShopNexus.

The same work adds reply-by-swipe to every chat, since a ticket's chat is
the chat.

The server and the console are built for real. The app stays on fake data,
as in parts 1 and 2.

Out of scope: assigning tickets to members, response-time targets, canned
replies, photos from the console, realtime in the console, email.

## Decisions

| Question | Decision |
|---|---|
| Two-way | A conversation: the person and ShopNexus message each other, as in any chat. |
| Chat shape | One chat per ticket. A ticket's chat is a chat of module chat with a `support` kind; nothing is copied. |
| Who answers | A system account "ShopNexus" with a fixed id, made by a migration. Nobody signs in to it. Members send as it; the person sees "ShopNexus"; the member is recorded per reply and in the audit log. |
| Where the person finds tickets | Not in Tin nhắn. Tôi → Trợ giúp → "Yêu cầu hỗ trợ" opens Hỗ trợ, the list of the person's tickets. |
| A new reply | A card at the top of Tôi ("ShopNexus đã trả lời") and a dot on the Tôi tab, both until the reply is read; a push that opens the ticket's chat. Tin nhắn's badge does not count it. |
| Báo chưa nhận hàng | The buyer only. The order is `shipped`, or `completed` by the system less than 7 days ago. One ticket per order; once it exists the order shows "Xem yêu cầu". The order does not change and the seller does not see the ticket. |
| Xin thêm hãng | From "Hãng của bạn chưa có?" on Đơn bán and in Thiết lập COD. The carrier's name (1–50 characters) and an optional note. Closing it sends "Đã ghi nhận hãng <name>." in the chat. Adding a carrier is still code work. |
| Yêu cầu khác | "Yêu cầu mới" on Hỗ trợ opens an empty chat; the first message opens the ticket. |
| Status | `open` and `resolved`. A message from the person in a resolved ticket reopens it. A member reopens one by hand too. |
| Console | Hỗ trợ: the queue (Đang mở, Đã xử lý; filter by kind), the ticket beside it with its chat and the facts (person, order, the carrier and how many sellers asked for it in 30 days, the person's other tickets), "Đã xử lý" and "Mở lại". Moderators and admins. No assignment. |
| Old feedback | Each `feedback` row becomes an open `other` ticket whose first message is the feedback. Then the table, `POST /v1/feedback` and `GET /v1/console/feedback` go. |
| Rate | At most 10 new tickets per account in 24 hours, as feedback had. |
| Reply by swipe | Every chat. A message may quote one earlier sent message of the same conversation. |

## Server

### The ShopNexus account

Migration inserts an `accounts` row with a fixed id
(`support.domain.ShopNexusID`), display name "ShopNexus", status `active`
and no identity, so no sign-in reaches it. The console refuses to suspend it
(`account_is_system`, 409) and lists it like any account. Erasure never
touches it.

### Module chat

- `conversations.kind`: `pair` (today's) or `support`.
  `UNIQUE (account_a, account_b)` becomes a partial unique index
  `WHERE kind = 'pair'`, so a person has any number of support chats with
  ShopNexus.
- `Service.OpenSupport(ctx, account)` makes a new `support` conversation
  between the account and ShopNexus; only module support calls it.
- A `support` conversation:
  - is left out of `Inbox`, `Unread`, `Search` and the inbox realtime
    count. `Unread` gains a sibling, `SupportUnread(account)`;
  - cannot be archived, blocked or reported (`conversation_is_support`,
    409);
  - gets no scam check: trust's `MessageSent` skips it;
  - has no deals; screen's chat screen reads none for it.
- `MessageFacts` carries the conversation's kind, so notification titles a
  support push "ShopNexus", tags it `conversation:<id>`, and the app opens
  the ticket's chat.
- Reply: `messages.reply_to uuid REFERENCES messages (id)`. Send accepts
  `reply_to`, which must be a `sent` message of the same conversation
  (`invalid_message`, field `reply_to`, otherwise). `MessageView.reply_to`
  is `{id, sender_id, text, photos}` with the quoted text cut to 200
  characters, read from the original at read time, so an erased account's
  quote follows what erasure left.
- Send takes an optional `as` account for module support: a member's reply
  goes out with `sender_id` ShopNexus. Only support passes it.

### Module support

Tables (one migration, after the chat changes):

```
tickets
  id                uuid PK
  account_id        uuid → accounts
  conversation_id   uuid → conversations, UNIQUE
  kind              not_received | carrier_request | other
  status            open | resolved
  order_id          uuid → orders      (not_received only; UNIQUE where kind = not_received)
  carrier_name      text 1–50          (carrier_request only)
  carrier_key       text               (folded name, for the 30-day count)
  first_message_id  uuid → messages
  last_message_at   timestamptz
  last_from         person | shopnexus  ("Chờ trả lời" when person)
  opened_at, resolved_at, resolved_by (member, null when the system closed it)
  request_key       uuid, UNIQUE (account_id, request_key)

ticket_events     (ticket_id, kind opened | resolved | reopened, by_member, at)
ticket_replies    (message_id PK → messages, ticket_id, member_id null for an automatic one)
```

`carrier_key` folds case, spaces and Vietnamese marks the way
`search_history.query_key` does.

Flows:

- Open: `POST /v1/support/tickets` with Idempotency-Key and
  `{kind, order_id?, carrier_name?, body?}`.
  - Checks the rate, then for `not_received` reads the order through
    deal (`Service.SupportOrder`: buyer, status, who completed it and when,
    carrier and tracking code, title). The buyer only; `shipped`, or
    `completed` by the system within 7 days (`ticket_not_allowed`, 409); an
    existing ticket for the order returns that ticket (200).
  - `other` needs a body; the others take an optional one. A card message
    may have no text, so chat's message rule becomes "text, photos, or the
    first message of a ticket".
  - Makes the conversation (`chat.OpenSupport`), sends the person's first
    message, writes the ticket and its `opened` event, in one Restate flow
    keyed by the request.
- Message: support subscribes `message.sent` for `support`
  conversations. From the person: `last_from = person`, and a resolved
  ticket reopens (`reopened` event, by nobody). From ShopNexus:
  `last_from = shopnexus`.
- Reply (console): sends as ShopNexus with `reply_to` allowed, writes
  `ticket_replies` and an audit row `ticket.reply`.
- Resolve and reopen (console): status, event, audit row
  (`ticket.resolve`, `ticket.reopen`). Resolving a `carrier_request` sends
  "Đã ghi nhận hãng <name>." as ShopNexus with a `ticket_replies` row and
  no member.
- Erasure: an erased account's open tickets resolve with no member; its
  messages follow chat's erasure.

Errors: `ticket_not_found` 404, `ticket_not_allowed` 409, `too_many_tickets`
429, `invalid_ticket` 422 with fields, `conversation_is_support` 409,
`account_is_system` 409.

### API

The person (`bearerAuth`):

- `POST /v1/support/tickets`: opens one, returns `TicketView`
  `{id, kind, status, conversation_id, order?, carrier_name?, opened_at}`.
- `GET /v1/support/tickets`: the person's tickets, open first then
  resolved, each with its last message and unread count.
- `GET /v1/support/summary`: `{open, unread, latest_unread?}` for Tôi and
  Trợ giúp.
- `GET /v1/support/orders/{order_id}/ticket`: the order's ticket, 404 when
  none, for "Xem yêu cầu".
- The ticket's chat uses the chat endpoints as they are
  (`/v1/conversations/{id}/messages`, `/read`). `ConversationView` gains
  `ticket?: TicketView` with `first_message_id` and `events`, and
  `other.official: true` for ShopNexus.

The console (`consoleAuth`, moderator and admin):

- `GET /v1/console/support/tickets?status=&kind=`: the queue, newest
  activity first, each with the person and `last_from`.
- `GET /v1/console/support/tickets/{id}`: the ticket, the person (status,
  joined, 90-day figures), the order with its carrier events, the
  30-day count of the same carrier, the person's other tickets, and the
  first page of messages with the member under each reply.
- `GET /v1/console/support/tickets/{id}/messages`: older pages.
- `POST /v1/console/support/tickets/{id}/replies`: `{body, reply_to?}`
  with Idempotency-Key.
- `POST /v1/console/support/tickets/{id}/resolve` and `/reopen`.
- `GET /v1/console/support/summary`: the open count for the drawer.

`audit` gains `target_kind = ticket`.

## Console

- The drawer lists Hỗ trợ under Trang chủ with the open count.
- `/support` and `/support/:id`: the queue at 360 px and the ticket beside
  it. The queue moves with `j`/`k`, Enter opens, Escape closes.
- The ticket: header with kind, status chip, who opened it and when, and
  "Đã xử lý" (filled) or "Mở lại" (outlined); the chat in `bodyMedium`, the
  person on the start side, ShopNexus on the end side with "<member> ·
  <time>" under each reply and "Tự gửi khi đóng" under the automatic one;
  the composer "Trả lời <name>" over "Người dùng thấy tên ShopNexus"; the
  272 px fact column.
- Reloads on focus and after each command; no socket.

## App (fake data)

- Chat: `ChatScreen` and `ChatViewModel` take a thread key, a deal or a
  ticket. A ticket's chat is the same screen without the deal console,
  quick replies, scam banner and menu; its app bar shows the kind and
  "ShopNexus · <status>", and its first message draws as the ticket card.
  Every change to the thread, bubbles, photos or composer reaches both.
- Reply by swipe in the shared thread: `ThreadItem` messages gain
  `quote: Quote?`; the composer holds the reply; TalkBack offers "Trả lời".
- `SupportRepository`: tickets, a ticket's thread, open, send, read; the
  fake ShopNexus answers once after a short wait.
- Screens: Hỗ trợ (list, "Yêu cầu mới"); the Tôi card and tab dot; the
  Trợ giúp row with the open count; on Đơn COD "Báo chưa nhận hàng" and its
  sheet, then "Xem yêu cầu"; on Đơn bán and Thiết lập COD "Hãng của bạn
  chưa có?" and its sheet. `sendFeedback` and the feedback sheet go.
- Tin nhắn does not change.

## Mockups

On the canvas, built by `app/.superdesign/tools/build_support.py` and
`console/.superdesign/tools/build_support.py`:

- App: `support-list`, `support-chat` (hashes `#reported`, `#carrier`,
  `#resolved`, `#new`), `support-report` (`#reported` shows "Xem yêu cầu"),
  `support-carrier`, `me-support`, `help`, and `chat` with reply by swipe.
- Console: `support-open`, `support-resolved`, and `home-*` with the
  drawer's Hỗ trợ.

## Order of work

1. Server: chat (kind, reply), the ShopNexus account, module support, the
   console endpoints, the feedback move.
2. Console: Hỗ trợ.
3. App: the shared chat with a ticket key and reply by swipe, then the
   support screens.

Each in its own worktree and branch.

## Testing

- Server:
  - domain: the opening rules per kind and role, the order window, reopen
    on a person's message, the carrier fold;
  - repository: the partial unique index, the one-ticket-per-order index,
    `reply_to` in the same conversation, the feedback migration on seeded
    rows;
  - service: rate, idempotency, scam check skipped, archive and report
    refused, inbox and unread exclude support;
  - e2e: each kind from the person's endpoint to a console reply, resolve,
    a reopening message, the push title, and a quote.
- Console: route and component tests for the queue, the panel, reply,
  resolve and reopen.
- App: `SupportRepository` and the view models; screen tests for Hỗ trợ,
  the ticket chat (no console, card, reopen), the Tôi card and dot, the two
  sheets, and swipe-to-reply in both chats.
