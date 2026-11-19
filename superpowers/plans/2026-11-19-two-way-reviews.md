# Two-way reviews with one reply: implementation plan

Spec: `superpowers/specs/2026-11-19-two-way-reviews-design.md`.
Branches: `feat/two-way-reviews` in server (`server-wt/two-way-reviews`),
app (`app-wt/two-way-reviews`) and website (`website-wt/two-way-reviews`).
No push, no merge.

## Decisions taken while planning

- **When a review opens.** Both sides review once the order is closed by
  delivery: `completed` or `failed` (a refused COD parcel is the seller's
  main case). Today's buyer rule (`shipped` too) goes: a review needs a
  delivery date for the blind window. Rows written while `shipped` stay.
- **Blind window without a data timer.** `visible_at` is written at
  insert: `closed_at + 7 days`, or now when the other side's review of the
  order exists already; the second review also pulls the first one's
  `visible_at` down to now, in the same transaction. A review is visible
  when `visible_at <= now`, so no timer has to write anything. The Restate
  timer only tells the subject: the `review.posted` handler sleeps until
  `visible_at` when the review is still hidden.
- **Rating counts visible reviews only**, per role, so a hidden review does
  not leak through the average.
- **Edit window.** As the spec: the reviewer edits or deletes within 7 days
  of the first submission, until a reply closes the review.
- **Write route stays `PUT /v1/orders/{order_id}/review`** (create or edit,
  as today); the role comes from the caller's side of the order. The spec's
  `POST` would only rename it. `DELETE` stays.
- **Old route.** `GET /v1/sellers/{id}/reviews` stays as
  `GET /v1/accounts/{id}/reviews?role=seller`, served by the same handler.
- **Offer card.** The chat view gets `buyer_rating`, the other member's
  rating as a buyer, when the caller sells to them in one of the pair's
  deals. The app shows it on the deal console's head for the seller.

## Phase 1: server

1. Migration `0059_two_way_reviews.sql`: add `role`, `reviewer_id`,
   `subject_id`, `reply`, `replied_at`, `visible_at`; fill today's rows
   (`role = 'seller'`, `reviewer_id = buyer_id`, `subject_id = seller_id`,
   `visible_at = created_at`); set NOT NULL; drop `seller_id`/`buyer_id`
   (subject/reviewer replace them); unique `(order_id, role)` instead of
   `order_id`; index `(subject_id, role, id)`; checks: role in
   (seller, buyer), reply length, reply and replied_at together.
2. Domain `trust/domain/review.go`: `Role` (`RoleSeller`, `RoleBuyer`),
   `NewReview(id, order, role, reviewer, subject, listing, stars, text,
   visibleAt, now)`, `Reply(by, text, now)` (subject only, once, visible
   only, not deleted), `CanChange` = `ErrClosed` after a reply, `Visible(now)`,
   `Reveal(now)`. Errors: `ErrNotSubject`, `ErrReplied`, `ErrHidden`,
   `ErrNotDelivered` (renames `order_not_shipped`). Tests.
3. Repository: columns, `ByOrder(order, role)`, `ByOrders(reviewer,
   orders)`, `OfOrders` for the counterpart reviews, `OfSubject(subject,
   role, now, page)`, `Summary(subject, role, now)`, `Insert` reveals the
   other side's row and writes `review.posted`, `Save` writes the reply and
   `review.replied` when it is new. Tests on the test stack.
4. Service: `PutReview(caller, order, …)` reads the caller's side;
   `DeleteReview`; `ReplyReview(caller, review, text)`;
   `Reviews(subject, role, page)` (replaces `SellerReviews`);
   `Rating(subject, role)`; `OrderReviews(caller, orders)` returning own
   and their review per order (replaces `OwnReviews`); `ReviewFacts` with
   role, subject, reviewer, order, visibility. Views gain `role`,
   `reviewer` (was `buyer`), `reply`.
5. Handler + OpenAPI (`api/paths/trust.yaml`, `api/schemas/trust.yaml`,
   `openapi.yaml`): `POST /v1/reviews/{id}/reply`,
   `GET /v1/accounts/{id}/reviews?role=`, the alias, schema changes.
6. Screen: order view and orders list carry `own_review` for both sides and
   `their_review` (hidden flag until visible); seller view gains
   `buyer_rating` and `buyer_reviews`; reputation adds `buyer_rating`; chat
   view `buyer_rating`; agent records keep the seller rating.
7. Notifications: `review.posted` waits until visible, tells the subject
   (and, when this review revealed the other one, that one's subject);
   new `review.replied` tells the reviewer. Both open the order.
8. ARCHITECTURE.md: the trust, notification and screen sections.
9. Gate: `go build ./...`, `go vet ./...`, tests of trust, screen,
   notification, migrations, api spec test (`-p 2`).

## Phase 2: app

1. `core/network/openapi/sync.sh` to pull the new spec.
2. Model: `Review` gains role, reply, replied-at; `OwnReview` gains reply,
   visible-at, closed; new `TheirReview`; `SellerProfile` gains buyer
   rating and buyer reviews; chat/deal view gains buyer rating.
3. Domain `Reviews.kt`: reply rules (once, 500 chars, only visible),
   closed after reply; tests.
4. Data: net mappers and repositories (`reply`, reviews by role), fakes
   for the demo flavor.
5. UI: order detail "Đánh giá người mua" for the seller as "Đánh giá người
   bán" for the buyer; review card with its reply and a one-time "Trả lời"
   with the note "Trả lời xong là khoá"; Người bán with two scores and the
   tabs "Khi bán" / "Khi mua" (only "Khi mua" for someone who never sold);
   buyer score on the seller's deal head.
6. Tests: domain + ViewModel; one Robolectric tap test for reply.
7. Gate: touched modules' unit tests, then stop the daemons.

## Phase 3: website

1. Branch from the website wiring branch if it owns the seller page,
   otherwise from main; the order page is still mock data.
2. Seller page: two scores and the two tabs; review card with reply.
3. Order page: the counterpart's review with the one reply.
4. Astro audit at desktop and phone, fix hits.
