# Two-way reviews with one reply

Date: 2026-11-19. Status: approved in outline (chat), details to review.

## Problem

ShopNexus is a marketplace between people, not shops. A listing is one
thing, sold once, so a review per listing helps nobody; what a buyer needs
is whether the person is worth dealing with. Today only the buyer of a
delivered order rates the seller (`reviews`, stars and up to 500
characters, editable for 7 days). The seller also takes a risk, above all
with COD: a buyer who refuses the parcel, haggles after agreeing, or goes
silent. Nothing records that.

Decided in chat: no photos or videos in reviews (proof of a bad item
belongs in a report or ticket), no public comments on listings (chat
covers questions), reviews stay tied to an order.

## Decision

1. **Both sides review.** After an order is delivered, the buyer reviews
   the seller and the seller reviews the buyer. Same rules: 1 to 5 stars,
   up to 500 characters, an optional text.
2. **One reply.** The person reviewed may reply once, up to 500
   characters. After the reply the review is closed: the reviewer can no
   longer edit or delete it, the reply cannot be edited, and nobody adds
   anything more. Before a reply, the reviewer keeps today's 7-day edit
   window.
3. **Blind until both or 7 days.** A review is hidden from its subject and
   from the public until the other side has reviewed too, or 7 days after
   delivery. So neither side writes in reply to the other's stars. The
   reply is possible only once the review is visible.
4. **Two scores.** A profile shows a rating as a seller and a rating as a
   buyer, each with its count, and the reviews in two tabs, "Khi bán" and
   "Khi mua". Search and the seller head keep using the seller score.

## Server

- `reviews` gains `role` (`seller` when the subject sold, `buyer` when
  the subject bought), `reviewer_id`, `subject_id`, `reply`, `replied_at`
  and `visible_at`. `order_id` stays, unique per role, so one order has at
  most one review in each direction. A migration fills the new columns for
  today's rows (`role = 'seller'`, `visible_at = created_at`).
- Domain: `NewReview(order, role, reviewer, subject, …)`, `Reply(text,
  now)` only by the subject and only once, `CanChange` false once replied.
  `visible_at` is set when the second review lands or by a Restate timer at
  delivery + 7 days.
- API: `POST /v1/orders/{id}/review` takes the role from who calls;
  `POST /v1/reviews/{id}/reply`; `GET /v1/accounts/{id}/reviews?role=seller|buyer`
  (the old `/v1/sellers/{id}/reviews` stays as `role=seller`).
- Notifications: the subject is told when a review becomes visible and
  the reviewer when it gets a reply.
- Rating (`service/rating.go`) is computed per role.

## App and website

- Order detail: after delivery, "Đánh giá người mua" for the seller, as
  "Đánh giá người bán" is for the buyer.
- A review card shows the reply under it; the subject sees "Trả lời" once,
  with a note that a reply closes the review.
- Profile: two scores and the two tabs; a person who never sold shows only
  "Khi mua".

## Seed

The seed pack's `reviews.jsonl` carries both roles and the reply, see
[seed packs](2026-11-19-seed-packs-design.md). Until this ships, the loader
writes only `role = seller` reviews without replies.

## Open

- Should a buyer's score show anywhere before a deal (the seller's view of
  an offer), or only on the profile? Proposed: on the offer card too,
  since that is when the seller decides.
