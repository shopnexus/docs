# Billing, part 1: payments and paid boosts

Date: 2026-11-05. Status: decided in conversation, question by question.
When the work lands, the decisions go into `server/ARCHITECTURE.md`.

## Scope

`app/mohinh.md` item 8: revenue comes from boosts and seller plans. This spec
builds the first of them, a boost paid per purchase, and the payment flow it
needs. ShopNexus starts collecting a service fee; it still holds no one's
goods money.

The app already has the UI on fake data: the Đẩy tin sheet in Tin của bạn
(1 ngày 15.000 ₫, 3 ngày 35.000 ₫, "Lên đầu mục Gần bạn quanh {area}",
MoMo, "Phí dịch vụ trả cho ShopNexus, không hoàn, không liên quan tiền
hàng"), the card line "Đẩy {days} ngày", and Gói người bán.

Out of scope, each for a later spec:

- Seller plans (Plus, Cửa hàng): monthly boosts, renewal, cancel, and the
  rule that a plan's boosts pay first. A linked wallet ("MoMo •• 0912") comes
  with them, since renewal needs it.
- The 20 % boost discount of the Xuất sắc tier, which waits for the
  reputation statistics.
- The real MoMo provider, a merchant contract, e-invoices for the fee, and
  daily reconciliation with MoMo's file.
- A payments screen or manual refund in the staff console.
- Switching a provider off and watching its health, needed once there is
  more than one provider.

## Decisions

| Question | Decision |
|---|---|
| Provider | A `Provider` interface with a fake behind it; MoMo plugs in later without changing the API. |
| Where a boost shows | At the top of Gần bạn for searchers within 15 km of the listing; Search keeps its order. Every card carries `boosted`, and the app labels it "Được đẩy". |
| Payment shape | Asynchronous from the start: a `pending` payment, a way to pay, and a check against the provider that settles it. |
| Durability | One plain Restate service, `BillingSettle`, settles a payment. Its callers are the IPN, the app's check, and two calls scheduled with a delay when the payment starts. Concurrent runs are safe through the payment's `write_id`; there is no workflow, promise or virtual object. |
| Trusting an IPN | A valid signature only wakes `BillingSettle`; the provider's answer to `Query` decides, checked against the payment's ID and amount. |
| Paid but the listing cannot be boosted | Refund automatically. |
| Paid after the payment expired | Boost if the listing is still `active`, else refund. |
| A second purchase while one is pending | The same listing and days reuse the pending payment; the provider is not called again. |
| Boost on a boosted listing | Stack: `boosted_until = max(now, boosted_until) + days`. The card shows days left. |
| Listing leaves `active` during a boost | The clock runs on. A sold or deleted listing loses the rest, without refund. |
| Where boost state lives | Billing owns payments and decides; catalog keeps `listings.boosted_until` in its search index. |
| Fake provider's payment | A page the server serves, reached through `pay.url`, with pay, cancel and late-pay buttons. |
| Ways to pay | `pay {url, deeplink?, qr?}`: the app opens `deeplink` or else `url`, a web client draws `qr`. |

## API

- `GET /v1/boost-offers`, signed in:
  `{offers: [{days: 1, fee: 15000}, {days: 3, fee: 35000}], pay_with: "MoMo"}`.
  The offers are constants in `billing/domain`; a price change is a deploy.
- `POST /v1/listings/{id}/boosts {days}` with an `Idempotency-Key`: 202 with
  the `Payment`. A repeated key returns the payment its first request made.
  A `pending` payment of the caller for the same listing and days, not yet
  expired, is returned as it is.
  - 404 `listing_not_found`: no such listing, or not the caller's.
  - 409 `listing_not_boostable`: the listing is not `active`.
  - 409 `too_many_pending`: the caller has 3 `pending` payments. An advisory
    lock per account guards the count, as with blocks and saves.
  - 422 `invalid_boost`: `days` is not an offer.
  - 409 `boosts_unavailable`: `PAYMENT_PROVIDER=off`.
  - 403 `account_suspended`.
- `GET /v1/payments/{id}`, signed in, the owner only; anyone else gets 404
  `payment_not_found`. It reads and changes nothing.
- `POST /v1/payments/{id}/check`, signed in, the owner only: asks
  `BillingSettle` to check a `pending` payment now and returns the `Payment`
  as it stands. The app calls it when the person comes back through
  `PAYMENT_RETURN_URL` and each time it polls a pending payment. A settled
  payment sends nothing. The send's idempotency key is
  `check:{id}:{unix seconds / 10}`, so a payment is checked at most once
  every 10 seconds however often the app calls.
- `Payment {id, status, amount, purpose: {kind: "boost", listing_id, days},
  pay: {url, deeplink?, qr?}, expires_at, paid_at?, boosted_until?,
  refunded_at?, refund_reason?}`.
  - `status`: `pending`, `paid` (money received and the boost applied),
    `expired`, `refunded`. An `expired` payment paid late becomes `paid` or
    `refunded`.
  - `refund_reason`: `listing_not_boostable`.
  - `pay` is present while `pending`.
- `POST /v1/payments/ipn/{provider}`, public, trusted only through the
  provider's signature. A valid one sends `BillingSettle` and answers 204,
  a repeat or an unknown payment ID included, so the provider stops sending.
  A bad signature is 400 `invalid_signature`, logged, and changes nothing.
  With Restate down it fails with 500, and the provider sends again later,
  as the other durable flows answer.
- `Listing`, as its seller reads it (`GET /v1/me/listings`,
  `GET /v1/listings/{id}` by the seller), gains `boosted_until`, absent when
  the listing is not boosted.
- `SearchItem` (Search, Gần bạn, Home) gains `boosted: true` while
  `boosted_until` is in the future.

## Data

- `payments`: `id` (UUIDv7, also the order ID sent to the provider),
  `account_id`, `provider` (`fake` or `momo`), `provider_ref`, `amount`,
  `listing_id`, `days`, `status`, `pay_url`, `pay_deeplink`, `pay_qr`,
  `expires_at`, `paid_at`, `boosted_until`, `refunded_at`, `refund_reason`,
  `created_at`, `write_id`. `(provider, provider_ref)` is unique. One payment
  buys one boost, so the purpose lives on the row; a plan purchase in part 2
  may split it out.
- Catalog: `listings.boosted_until` (nullable), added to `listings_search`.
  `listing_boosts (payment_id PK, listing_id, until)` makes
  `catalogsvc.Boost` idempotent: a repeat with the same payment returns the
  `until` of the first and adds no days.
- Stacking is one statement, so two purchases at once both count:
  `UPDATE listings SET boosted_until = greatest(now, coalesce(boosted_until,
  now)) + days WHERE id = $1 AND status = 'active'`. No row updated is the
  refusal `listing_not_boostable`.

## Flow

1. `POST /boosts` calls the Restate service `StartBoost` with the
   `Idempotency-Key`:
   1. read the listing through catalog; not the caller's is
      `listing_not_found`, not `active` is `listing_not_boostable`;
   2. return the caller's pending payment for the same listing and days when
      there is one;
   3. under the account's lock, count the pending payments, mint the payment
      ID, insert the row `pending` with `expires_at` 15 minutes on;
   4. step `provider.Create(id, amount, expires_at)` returns `provider_ref`
      and `pay`, saved on the row;
   5. two sends of `BillingSettle.Run`, one with a delay of 15 minutes
      (`trigger: expire`) and one of 24 hours (`trigger: recheck`). They are
      journaled, so a retried `StartBoost` schedules them once; media
      schedules an upload's expiry the same way.
2. `BillingSettle.Run {payment_id, trigger}` reads top to bottom:
   1. read the payment; `paid` or `refunded` ends the run;
   2. step `provider.Query(payment)`; an answer for another order or amount
      counts as unpaid;
   3. unpaid: at or past `expires_at`, save `expired`; before it, end;
   4. paid: step `catalogsvc.Boost(payment_id, listing, days)`.
      - Applied: save `paid` with `paid_at` and `boosted_until`.
      - Refused because the listing is not `active`: step `provider.Refund`,
        save `refunded` with `listing_not_boostable`, and write the event
        `payment.refunded` with the save.
   5. A save that loses to another run (`write_id`) reads again from step 1,
      up to three times, then fails so Restate retries. The boost is
      idempotent by payment ID and the refund by a refund ID derived from it,
      so two runs that both reach step 4 add the days once and refund once.
3. Callers of `BillingSettle.Run`: the IPN handler after the signature check
   (`trigger: ipn`), `POST /payments/{id}/check` (`trigger: check`), and the
   two delayed sends. An IPN that never comes delays a boost to the app's
   next check or to the 15-minute run; money is not lost.
4. `payment.refunded` carries the payment ID as event ID and subject.
   Notification hears it, reads the facts through billing's service, and
   writes "Đã hoàn {amount}: tin {title} không còn đẩy được". A payment that
   ends `paid` or `expired` tells no one: the app shows its own snackbar
   while it polls.

## Fake provider

- `Create` returns `pay.url = {PUBLIC_API_URL}/dev/pay/{payment_id}`,
  `pay.qr` = the same URL, and no `deeplink`. Scanning the QR with a phone
  opens the page there, so the web and desktop path can be tried for real.
- The fake keeps what each order is in its own table, `fake_payments`
  (`payment_id`, `amount`, `paid_at`, `refunded_at`), so `Query` and
  `Refund` answer as a provider would.
- The page is a small HTML page with the amount, the listing's title and
  three buttons:
  - **Trả tiền** marks the order paid, sends an IPN signed with the fake's
    static key into the function the HTTP IPN calls, then redirects to
    `PAYMENT_RETURN_URL`.
  - **Hủy** redirects without paying; the payment expires after 15 minutes.
  - **Trả muộn**, shown once the payment is `expired`, pays and sends the
    IPN, to exercise a late payment.
- Each button posts to `POST /dev/pay/{id}/{pay|cancel|late}`, which tests
  call directly.
- `/dev/pay/*` is mounted only when the provider is `fake`, and with
  `APP_ENV=prod` the server refuses to start on the fake, as it does on the
  log push sender.

## Configuration

New variables, required in every environment and in `.env.example`:

- `PAYMENT_PROVIDER`: `fake`, `off` or `momo` (`momo` is refused until it
  exists). `off` is for prod until MoMo is live: `GET /v1/boost-offers`
  answers `{offers: [], pay_with: ""}`, so the app hides Đẩy tin, a
  purchase is 409 `boosts_unavailable`, the IPN route answers 400
  `invalid_signature`, and `/dev/pay/*` is not mounted.
- `PAYMENT_RETURN_URL`: where the way to pay sends the person back, an app
  link such as `https://shopnexus.vn/pay/return`, or `shopnexus://payments`
  in development.
- `PUBLIC_API_URL`: the server's public base URL, used for the fake's page
  and, later, for MoMo's `ipnUrl`.

## Ranking (catalog)

- Gần bạn adds a constant-score boost of 100 to a listing with
  `boosted_until > now` inside a 15 km box around the searcher's point. A
  normal listing scores about 1 to 7, so boosted listings form a tier above
  every other; inside it the distance rings and freshness order them as
  before.
- Search adds no score for a boost; its items carry `boosted` only.

## Module layout

Module `billing` has the four packages (`domain`, `repository`, `service`,
`handler`). It depends on catalog's service; no module depends on billing
except notification, which reads refund facts. `internal/provider/payment`
holds `Provider` and the fake. The Restate services `StartBoost` and
`BillingSettle` live in `billing/service`.

## Errors

| Code | HTTP | When |
|---|---|---|
| `listing_not_found` | 404 | No such listing, or not the caller's |
| `listing_not_boostable` | 409 | The listing is not `active` at purchase |
| `too_many_pending` | 409 | 3 pending payments already |
| `invalid_boost` | 422 | `days` is not an offer |
| `account_suspended` | 403 | The caller is suspended |
| `payment_not_found` | 404 | No such payment, or someone else's |
| `boosts_unavailable` | 409 | `PAYMENT_PROVIDER=off` |
| `invalid_signature` | 400 | An IPN with a bad signature |

## Tests

- Domain: the offers, an unknown `days`, the allowed status changes of
  `Payment` (an `expired` one may still become `paid` or `refunded`).
- Repository: stacking, two purchases at once included; `listing_boosts`
  adding no days on a repeat; a listing not `active` refused; the cap of 3
  pending; reusing a pending payment; `write_id` on payments; the unique
  `(provider, provider_ref)`.
- Restate (restatetest), one test per branch: paid and boosted; paid with
  the listing no longer `active` and refunded; the 15-minute run finding it
  paid and boosting; the 15-minute run finding it unpaid and expiring it; a
  late payment after expiry boosting, and refunding when the listing is gone;
  two runs at once boosting once; a repeated `Idempotency-Key` returning the
  same payment; a provider answer for another amount counting as unpaid.
- Ranking: a boosted listing within 15 km leads Gần bạn; one at 20 km gets
  no tier; an ended boost loses it; Search's order unchanged with `boosted`
  set.
- e2e: every declared status, and the fake page's pay, cancel and late paths
  through `POST /dev/pay/{id}/…`.

## App (separate task)

The app runs on fake data, so this spec wires no API into it. A small app
change follows: the "Được đẩy" label on buyer cards (Home, Gần bạn,
Search); hide "Gói Plus có 4 lượt đẩy mỗi tháng" until part 2; the payment
row says "MoMo"; "Đẩy {days} ngày" counts days left from `boosted_until`;
the refund notice. `core/model` follows the OpenAPI shapes of `SearchItem`
and `Payment`.

## ARCHITECTURE.md

Add a Billing section. Replace "There is no finance module: ShopNexus holds
no money, so there is no wallet and no payment session" with: ShopNexus
collects service fees through module `billing` and still holds no one's
goods money, so there is no wallet.
