# Web: orders and COD on the server

Branch `feat/web-wire-orders` in `website-wt/orders`. Roadmap Phase 5.

## Goal

The buyer asks for COD on an agreed deal from Tin nhắn, follows the order on
Đơn mua and the order page, confirms receipt, cancels a pending order, reports
"chưa nhận" and reviews the seller. The seller sees Đơn bán, creates the
shipment through a linked carrier (GHTK, GHN) or types a code made on a
carrier's own app, corrects a manual code, cancels a pending order and reviews
the buyer. Thiết lập giao COD saves the pickup address and phone and links or
unlinks carrier accounts. Hỗ trợ lists the tickets, shows one ticket's chat,
sends a message in it and opens a new ticket. Home's two signed-in tiles come
back from real data.

## Rulings

- One render path per page: the frontmatter reads the screen
  (`/v1/screens/orders`, `/v1/screens/order/{id}`, `/v1/screens/cod-checkout/{deal}`,
  `/v1/screens/cod-setup`, `/v1/support/tickets` + `/v1/screens/chat/{id}`).
  Words and mappings live in `src/lib/orders.ts`.
- Every write is a `<form method="post">` to its own page with PRG. A refusal
  comes back as `?error=<code>` and renders a `Notice`. Writes that take an
  Idempotency-Key (createShipment, confirmReceipt, openTicket, sendMessage)
  carry a hidden key per rendered form.
- `/orders` lists the buyer's orders, `/sales` the seller's; both open
  `/orders/{id}`, which shows either side.
- COD from a deal: DealConsole's "Đặt giao COD" opens `?cod=1` on the chat;
  Tin nhắn then reads the checkout screen and the address book and renders
  `CodDialog` open (the script makes it modal). Its form posts `do=cod`.
  `/cod?deal={id}` redirects there.
- The support chat reuses Thread and Composer (Composer takes an `action`);
  no socket on Hỗ trợ, a reload shows new replies.
- No money is held: copy speaks of paying the shipper at the door and the
  carrier paying the seller, never of escrow, a wallet or a refund.

## Deviations as built

- The seller's shipment form lives on `/orders/{id}` (as the app's seller
  order screen does), not on `/sales`; `?edit=1` there corrects a manual code.
  Its fields are query keys; the script re-reads the page on change and swaps
  the fees and the code preview (`data-fee`, `data-part`). No `/api` relay.
- Confirmations (cancel, receipt, unlink, delete review, report) are native
  popovers (`ConfirmPop`), so they work without script.
- `/cod?deal=` redirects to the chat with `?cod=1`; `R.cod` became a function.
- The buyer's open-order cap on Đơn mua comes from Uy tín's `caps.cod_orders`
  (already read by the account nav). The nav shows support's unread count from
  `/v1/support/summary`.
- Not wired: the reply to the other side's review (shown, not answerable
  here), "Mua lại" after a failed delivery (the chat is one click away),
  carrier events (the server has only statuses and dates), the support socket.
- Mock removed: the orders, sale, COD setup and support parts of
  `data/orders.ts` (Tin của bạn's part stays for Phase 6) and `ADDRESS_BOOK`,
  `PROFILE_TASKS`, `TASKS_DONE` from `data/common.ts`. PhaseTrack, PhaseBar,
  PhaseDot and Stepper stay in use.
