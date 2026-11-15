# App wiring, Phase 7: inbox, chat and deals — Implementation Plan

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`. Gap analysis 2026-11-15. Server: `ARCHITECTURE.md` (Chat, Deal, Screen), `api/` (conversations, messages, deals, inbox and chat screens, scam warnings), `e2e/chat_test.go`, `deal_test.go`. Built on the server-state layer and the update stream (Phase 6).
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** in the live flavor, Tin nhắn, Chat and the deal console read and write the server. Pushes refresh what is on screen, and sent messages show at once. Demo keeps `Simulator` and `DealEngine`.

## Rulings (product owner, 2026-11-15)

- **App first.** The app stays simple, with few words. The server changes to fit the app, and the app gets no new buttons just because the server has an endpoint.
- **Deal moves in chat.** Every move a person makes on a deal (offer, counter, accept, withdraw) and every order step writes a deal message into the pair's conversation. The server opens the conversation if needed, so the order, unread count, push and preview work. The app draws these messages with its existing thread items (PriceMove, Event, Milestone). The look of the thread does not change.
- **Several deals per pair.** A chip row in the Chat header ("+2 món khác") switches the focused deal and its console. Inbox rows show "+N". This needs a mockup.
- **No new commands.** No "Từ chối" and no "Huỷ thoả thuận" in the app. The server's decline and cancel endpoints stay unused.

## Decisions (analysis)

- **Routes:** `ChatRoute(conversationId, dealId? = null, focusMessageId? = null)`. Without a `dealId`, the server's choice is used (your turn, then active, then newest). The deep link `shopnexus://deal/{id}` resolves through `GET /v1/deals/{id}`.
- **Server additions, spec first:**
  - S1: opening a deal opens the pair's conversation, and `Deal` and `DealSummary` carry `conversation_id`.
  - S2: `ChatScreen` gains `blocked` and the other member's read marker (`other_read_message_id`).
  - S3: deal messages (`Message.deal {deal_id, move}`) for moves and order steps.
- **Model:**
  - New `ConversationId`. Inbox rows key by conversation and carry an optional deal and `otherActiveDeals`.
  - `WarningSignal.icon` becomes `code`, and the design system maps codes to icons.
  - A new `ChatRepository` (`chat`, `older`, `send`, `open`, `typing`, `read`). Text and photo sends move there from `DealCommand`.
  - `ThreadItem` gains an id and a status (sending, processing, failed).
- **Reads:** `ServerState` keys for the inbox (paged), the badge, each chat (paged older messages) and each deal. A `ChatPushes` singleton routes `UpdateStream.pushes`:
  - message: re-read the chat's first page and merge by id; the person's own echo replaces the bubble.
  - read: refresh the badge, the inbox and the "Đã xem" marker.
  - deal: get the deal, put it, and patch the chats and the listing detail.
  - scam_warning: re-read the chat.
  - typing: show it for 5 s.
  - reset: refresh everything watched.
- **Sends:**
  - The bubble shows at once, with an `Idempotency-Key` that is stored with the unsent message.
  - Photos go through `MediaUploader`, and their upload ids are kept for retries.
  - A failed bubble is tapped to send again.
  - Typing frames go out through `UpdateStream`, at most once per 3 s.
  - Drafts and unsent messages live in a per-account DataStore that both flavors use.
- **Hidden in live (no server data):**
  - Hidden: price insight, counter expiry, check tips, claims, counterpart area, and the place on text messages.
  - Report signals are dropped; the report carries `conversation_id`.
  - Inbox chips BUY, SELL and UNREAD filter the loaded pages.
  - An offer's note is sent as a chat message right after the offer.

## Sub-steps

0. Server `feat/deal-conversation`: S1–S3 (spec, OpenAPI, e2e, ARCHITECTURE), then re-sync `codegen.yaml`.
1. Mockups: the Chat deal chips and the inbox "+N", plus a photo bubble while processing and after failing. The product owner approves them before any UI code.
2. App `feat/wire-chat-contract`: models, routes and deep links, the `ChatRepository` split, and fakes (one conversation per demo deal). Demo walks stay green; no network code.
3. App `feat/wire-inbox`: `NetInboxRepository`, `ChatLocalStore`, the badge, and `ChatPushes` for the inbox.
4. App `feat/wire-chat`: `NetChatRepository` (view, older, open, send with key and photos, read, typing) and `UpdateStream.typing`.
5. App `feat/wire-deals`: `NetDealRepository` (start, deal, offer, accept, withdraw; `orders()` read-only) and `ChatPushes` for deals. Listing detail and the seller page map `conversation_id`. Live drops the deal and inbox fakes. COD and shipping on real deals stay broken until Phase 8.

Each step: gate, `/code-review`, `/simplify`, merge. Steps 3–5 also need an emulator walk against the local server with two accounts.
