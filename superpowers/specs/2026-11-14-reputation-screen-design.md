# Design: Uy tín as figures, served by the server

Date: 2026-11-14.
Status: decided in conversation. When the work lands, the server decisions
go into `server/ARCHITECTURE.md` (section Screen).

## Why

The app's Điểm uy tín (`app/feature/me/rep/`) runs a points system: a score
out of 1000, four tiers (NEW, TRUSTED, REPUTABLE, TOP), perks that raise the
caps on open COD orders (2/5/10/20) and listings on sale (5/20), a badge,
priority, and a history of points won and lost. The server has none of it:
every account has the same caps (20 listings on sale, 3 open COD orders),
and a failed delivery is counted only in a 90-day figure, never punished.

## Decisions

- **Drop points, tiers and tier perks** from the product. The screen
  becomes "Uy tín của bạn": figures the server holds, and the caps in use.
- The view: `GET /v1/screens/reputation`, bearer auth, tag `screen`,
  operation `getReputationScreen`, built in module `screen` from the other
  modules' services (one function, top to bottom, like the other views).
- It carries:
  - `rating`: the average stars received and the review count (as the
    seller page shows them; null average when no review).
  - `sold`: listings sold, and `joined_at`, and `followers`.
  - `reply`: the reply rate over the last 90 days, or null when fewer than
    5 conversations count. A conversation counts when another person
    started it about one of the caller's listings and its first message is
    in the last 90 days and either more than 24 hours old or already
    answered. It is answered in time when the caller's first message in it
    came within 24 hours of the other person's first message. The rate is
    an integer percent (rounded down) plus the count of conversations it
    is from. Computed on read from chat's tables (through chat's service),
    no new storage.
  - `figures_90d`: as a buyer over the last 90 days, COD orders placed and
    of those the deliveries that failed (the numbers the app already
    shows: "x / y giao không thành").
  - `caps`: listings on sale `{used, max}` with max 20, open COD orders as
    a buyer `{used, max}` with max 3 (read the constants from the owning
    modules' domain packages, never duplicate the numbers).
- No history, no score, no tier, no perks, no identity row.

## Tests

- Service unit tests for the reply-rate rule: under 5 counted → null;
  conversations younger than 24 h and unanswered are left out; answered
  after 24 h counts as not in time; conversations the caller started
  (as buyer) are left out; older than 90 days left out.
- e2e: a new account (no reviews, rate null, caps used 0); after a sale
  and a review the numbers move; 401 without token.

## App follow-up

Remove `Tier`, score, perks and points history from the app (Tôi card,
Điểm uy tín, seller pages, notifications that award points). The screen
shows the figures above under the title "Uy tín của bạn".
