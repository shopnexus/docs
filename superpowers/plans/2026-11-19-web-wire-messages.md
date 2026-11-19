# Web: Tin nhắn and deals on the server

Branch `feat/web-wire-messages` in `website-wt/messages`.

## Goal

`/messages` reads the inbox, search and the open chat from the server, sends
text and photos, replies, makes every deal move (offer, counter, accept,
decline, withdraw, cancel), marks read and unread, archives, dismisses the scam
warning, and reports plus blocks the other person. The entry links
(`?listing=` with `&offer=1` / `&ask=`, `?seller=`, `?deal=`) open the right
chat. Chat nhanh on a listing sends for real. The page updates live over the
server's WebSocket and still works without it (a reload shows everything).

## Rulings

- One render path. The page frontmatter reads everything (`lib/messages.ts`
  `loadMessages`: inbox page, chat screen, search) and marks the open chat read
  up to its newest sent message. The header badge follows the fresh inbox count.
- Writes are `<form method="post">` to `/messages` with PRG; a refusal comes back
  as `?error=<code>` and renders a Notice (`lib/chat-errors.ts`). sendMessage
  carries a hidden Idempotency-Key per rendered composer.
- The script sends the composer and the deal forms in place: it posts the form
  with `Accept: text/html`, follows the 303 and swaps each `data-part` of the
  returned page (inbox, warning, thread, deals, side, alert, header badge). A
  part that holds the focus is left for the next swap. No form is rebuilt in JS.
- Live updates: `sn:update` (message, read, deal, scam_warning) and `sn:reset`
  refetch the page itself and swap the same parts. While the tab is hidden the
  refetch waits for `visibilitychange`. Older messages come from the partial
  `/messages/older` and are dropped when the newest page is swapped.
- Socket: `GET /api/socket` returns `{url, token, expiresAt}` for the signed-in
  buyer; the token is the session's access token, refreshed through
  `refreshAccess` (new in `lib/session.ts`) when under 90 s remain. The URL is
  `ws(s)://api.<host>/v1/ws` (`x-forwarded-proto` first), or `PUBLIC_API_URL`
  (optional server env) for a dev server on localhost.
- `lib/socket.ts` opens `new WebSocket(url, ['bearer', token])` with
  `?since=<seq>` from sessionStorage, renews with an `auth` frame a minute
  before expiry, reconnects with 1 s to 30 s backoff (at once on 1001 and on the
  first 4001), stops on 4003, and reopens after the page cache. A refused
  upgrade (1006) just retries with a fresh ticket.
- Entry links: `?listing=` calls openDeal (the app's start path, which opens or
  reuses the pair's conversation) and redirects to `?chat=&deal=`; `&offer=1`
  opens the amount form, `&ask=` fills the composer (nothing is sent by a GET).
  `?deal=` reads the deal for its conversation. `?seller=` searches the inbox by
  the seller's name for the pair's chat, else lists up to six of their items,
  each a `?listing=` link. `phone_required` shows a notice linking to Bảo mật.
- Chat nhanh posts to `/api/listings/<id>/chat` ({text, key} or {amount}): it
  opens the deal, then sends or offers, and answers `{chat, deal}` or the
  server's status with `{code}`.
- Hidden for want of data or scope: COD request (CodDialog stays in the tree,
  unused, for the orders phase; agreed buyers read "Đặt giao COD trong app
  ShopNexus"), the Landmark place chip, "Thường trả lời trong 10 phút", the
  online dot and the verified tick in Chat nhanh.

## Deviations as built

- No separate partial for live updates: the page itself is the partial, so the
  read mark, the badge and the deal state come from one place.
- The deal chips are links (`?deal=`); the script switches them in place.
- The block bar offers "Bỏ chặn" only when `GET /v1/blocks` shows the viewer's
  own block.
- `src/data/account.ts` is gone; ReportDialog keeps its four reasons.
- Shared files: `lib/session.ts` (`refreshAccess`), `lib/routes.ts` (`API.socket`,
  `API.quickChat`), `components/Notice.astro` (a slot after the text),
  `components/Header.astro` (`data-part` on the messages badge),
  `components/BottomNav.astro` (Tôi was lit on `/messages`), `astro.config.mjs`
  (`PUBLIC_API_URL`), `pages/cod.astro` (redirects to Tin nhắn).

## Review fixes (6f807b9)

- `/api/socket` answers only `Sec-Fetch-Site: same-origin` (or an exact
  `Origin` when the header is absent), always `no-store`, and refreshes only
  after that check. The server has no short-lived socket ticket; the page holds
  the access token by the owner's decision.
- `?listing=` opens the deal only for `Sec-Fetch-Site` same-origin or none;
  otherwise it renders "Nhắn về tin này", a POST form (`do=open`).
- Live updates: this chat's frames refetch the page (debounced 250 ms); other
  chats' frames fetch the partial `/messages/inbox` (list + `MessagesLink`).
  A read update within 2 s of the page's own read mark is skipped. The thread
  is replaced only at its end with no older pages open; otherwise a
  "Có tin mới" pill holds it.
- The composer keeps its key after `unknown` (no answer or 5xx; `errorCode`
  maps those to `unknown`). `idempotencyKey` lives in `lib/key.ts`.
- `mineBlock` pages through `GET /v1/blocks`; the server has no per-account
  block lookup.
