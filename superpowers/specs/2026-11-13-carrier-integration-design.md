# Design: real carriers, GHTK and GHN

Date: 2026-11-13.
Status: decided in conversation, question by question and section by
section. Part 2 of the order flow (`2026-11-12-order-flow-sync-design.md`,
Scope). When the work lands, the server decisions go into
`server/ARCHITECTURE.md`.

## Scope

Part 1 left every shipment to a fake carrier. This part reads and makes
shipments at two real carriers, GHTK and GHN, with each seller's own
account at that carrier:

- A seller links their GHTK account (email and password) and their GHN
  account (token and ShopId). ShopNexus keeps one encrypted token per
  seller per carrier.
- `linked`: ShopNexus makes the shipment on the seller's account.
- `manual`: the seller made the shipment on the carrier's own app and
  types its code; ShopNexus reads it with the seller's token for that
  carrier.
- Status comes from the carriers' webhooks, with a poll of every open
  shipment as the safety net.

The code follows the real APIs. It runs against GHTK's staging and GHN's
dev environment; production keeps `CARRIER=none` until ShopNexus signs a
B2C partner contract with GHTK.

The app stays on fake data and is not wired to the server, as in part 1.

Out of scope: other carriers (SPX, J&T, Viettel Post) until each has an API
a seller's account can use; an aggregator such as AfterShip; mockups (part
4); wiring the app to the server.

## Decisions

| Question | Decision |
|---|---|
| Goal | Real APIs, staging and dev environments. Production stays `CARRIER=none`. |
| Carriers | GHTK and GHN. A carrier the seller has not linked is not offered. |
| Reading a `manual` code | With the seller's own token at that carrier. No aggregator. A code outside the seller's account is "not found" at once, so part 1's preview, the COD warning and the refusal of an unknown code stay as they are. |
| Mode names | `linked` and `manual` stay. |
| Linking GHTK | Email and password, exchanged at once for the shop's token through GHTK's B2C endpoint `POST /services/shops/token` with ShopNexus's partner token. The password is never stored. |
| Linking GHN | The seller's API token and ShopId, checked against GHN before they are stored. |
| Fake linking | The fake carrier links any email and password, or any token and ShopId, at once; the password or token `wrong` is refused. |
| Token storage | AES-GCM with `CARRIER_TOKEN_KEY`, a key of its own, one per environment. Tokens never leave the server: not in responses, logs or console. |
| Accounts per seller | At most one per carrier. |
| Unlinking | Refused while a shipment at that carrier is open (`shipments_open`). |
| Erasure | Deleting an account deletes its carrier tokens. |
| Pickup address of a `linked` shipment | The seller picks from two groups: the carrier's own pickup points (read live from the carrier) and the seller's ShopNexus addresses. An empty group is not shown. The order keeps a copy of what was picked. |
| Payout | GHTK and GHN pay COD to the seller's own account; Thiết lập COD drops its payout step. |
| Status updates | Webhooks for speed, a poll of every open shipment every `CARRIER_POLL_EVERY` (2 h) as the safety net. Both end in part 1's `ShipmentUpdated(code, status)`. |
| GHN webhooks | How GHN registers a callback is not documented in what we found; GHN shipments rely on the poll, and the webhook endpoint is ready for when a callback is set. |
| Architecture | A new module `shipping` owns carrier accounts, tokens, webhooks and the poll; `deal` calls it to make, read and cancel shipments. |

## Server

### Module `shipping`

```
deal ──(make / read / cancel a shipment)──▶ shipping ──▶ provider/carrier
  ▲                                            │            ├─ ghtk  (real)
  └──────── ShipmentUpdated(code, status) ─────┤            ├─ ghn   (real)
                                               │            └─ fake  (dev, test)
                         GHTK and GHN webhooks, the poll
```

`provider/carrier` keeps one client per carrier behind one interface. Part
1's `carrier.Client` (Create, Lookup, Cancel) grows to take the seller's
token and gains `Link` and `Pickups`; `None` answers every call with
`ErrUnavailable` as today.

### Data

```
carrier_accounts
  account_id   uuid  → accounts
  carrier      'ghtk' | 'ghn'
  shop_code    text            -- GHTK's shop code or GHN's ShopId, shown to the seller
  token        bytea           -- AES-GCM ciphertext under CARRIER_TOKEN_KEY
  nonce        bytea
  linked_at    timestamptz
  PRIMARY KEY (account_id, carrier)
```

`orders` gains the pickup of a `linked` shipment: the carrier's pickup
point id, or a copy of the ShopNexus address (name, phone, street,
commune).

### Configuration

No defaults, as everywhere.

| Variable | Meaning |
|---|---|
| `CARRIER` | `fake` (dev, test), `none` (production now), `live` (GHTK and GHN). `APP_ENV=prod` refuses `fake`. |
| `CARRIER_TOKEN_KEY` | 32-byte AES-GCM key, base64; `make env` writes a fresh one. |
| `CARRIER_POLL_EVERY` | The poll's period: `2h`. |
| `GHTK_API_URL`, `GHTK_PARTNER_TOKEN`, `GHTK_CLIENT_SOURCE`, `GHTK_WEBHOOK_SECRET` | Required with `live`; empty with `fake` or `none`. Staging: `https://services-staging.ghtklab.com`. |
| `GHN_API_URL`, `GHN_WEBHOOK_SECRET` | Required with `live`; empty otherwise. Dev: `https://dev-online-gateway.ghn.vn`. |

### API

| Endpoint | By | Result | Errors |
|---|---|---|---|
| `GET /v1/carrier-accounts` | the seller | linked carriers with `shop_code` and `linked_at` | |
| `PUT /v1/carrier-accounts/{carrier}` | the seller | GHTK `{email, password}`, GHN `{token, shop_id}`; links or relinks | 422 `carrier_login_failed`, `invalid_carrier`; 503 `carrier_unavailable` |
| `DELETE /v1/carrier-accounts/{carrier}` | the seller | unlinks | 404; 409 `shipments_open` |
| `GET /v1/carrier-accounts/{carrier}/pickups` | the seller | the carrier's pickup points | 404 not linked; 503 |
| `GET /v1/shipments/quote?carrier&service&weight_grams&pickup_from…` | the seller | the carrier's fee | 409 `carrier_not_linked`; 422; 503 |
| `POST /v1/orders/{order_id}/shipment` | the seller | part 1's body; `linked` gains `carrier` and `pickup_from` (`{carrier_pickup_id}` or `{address_id}`) | part 1's, plus 409 `carrier_not_linked` |
| `PUT /v1/orders/{order_id}/shipment` | the seller | part 1's; reads the new code with the seller's token | part 1's, plus 409 `carrier_not_linked` |
| `GET /v1/shipments/lookup?carrier&code` | the seller | part 1's preview, read with the seller's token | part 1's, plus 409 `carrier_not_linked` |
| `POST /v1/carriers/ghtk/webhook/{secret}` | GHTK | 200 always once the secret matches | 404 on a wrong secret |
| `POST /v1/carriers/ghn/webhook/{secret}` | GHN | as above | 404 on a wrong secret |

Part 1's dev endpoint stays on `fake`.

### Flows

- **Linking GHTK**: `POST /services/shops/token` with `Token: GHTK_PARTNER_TOKEN`, `X-Client-Source: GHTK_CLIENT_SOURCE` and the seller's email and password; store `data.token` encrypted and `data.code` as `shop_code`. The password is dropped as the call returns.
- **Linking GHN**: call GHN's shop list with the seller's token; the ShopId must be among the shops; store the token encrypted.
- **Making a `linked` shipment**: the seller's token, the pickup picked, `partner_id` (GHTK) or `client_order_code` (GHN) set to the ShopNexus order code, COD set to the order's price. The carrier's code and fee become the shipment's.
- **Reading a `manual` code**: GHTK's order status by label, GHN's order detail by `order_code`, both with the seller's token.
- **Webhooks**: the secret in the path is the only check (GHTK signs nothing). The body may be form-encoded or JSON. The update goes to `ShipmentUpdated`.
- **The poll**: when a shipment is made, a Restate send with `WithDelay(CARRIER_POLL_EVERY)` reads it; each read calls `ShipmentUpdated` and schedules the next while the shipment is open. A webhook that came first leaves the read with nothing to change.
- **Cancelling at the carrier**: part 1's pickup timeout calls the carrier's cancel with the seller's token.

### Status mapping

| GHTK `status_id` | ShopNexus |
|---|---|
| `3` picked up | `in_transit` |
| `4` out for delivery | `in_transit` |
| `5` delivered, `6` reconciled | `delivered` |
| `9` not delivered, `20` returning, `21` returned | `failed` |
| `-1` cancelled, `1`, `2`, `7`, `8`, `10`, `12` and the rest | no change |
| shipper notices `123`, `127`, `128`, `45`, `49`, `410` | ignored |

GHN's statuses map the same way: `picked`, `storing`, `transporting`, `sorting`, `delivering`, `money_collect_delivering` → `in_transit`; `delivered` → `delivered`; `delivery_fail`, `waiting_to_return`, `return`, `return_transporting`, `return_sorting`, `returning`, `returned` → `failed`; the rest change nothing. This list comes from GHN's status names as known, not from a page read during design; the plan checks it against GHN's order-detail documentation before the map is written.

## App

The app stays on fake data; its fake carrier follows the server's
conventions.

- **Thiết lập COD** (`feature/codsetup`): the payout step goes. Linking GHTK takes email and password, linking GHN token and ShopId; the fake links at once and refuses `wrong`. The page lists the linked carriers with their shop codes; unlinking is refused while a shipment at that carrier is open.
- **Tạo đơn** (part 1's interim Đơn bán): the carrier chips show only linked carriers; with none linked, a line leads to Thiết lập COD. `linked` gains the pickup choice in two groups, "Kho trên GHTK/GHN" and "Địa chỉ của bạn", an empty group hidden. `manual` keeps part 1's preview, read through the linked account.
- `ShipCarrier` keeps its five values to match the server; only GHTK and GHN can be linked.

## Testing

- Server: unit tests for both status maps, ignored codes included; for the token cipher (a wrong key does not decrypt; no response or log carries a token). Service tests for linking, unlinking with an open shipment, a shipment or lookup at an unlinked carrier, and the poll (stops once the shipment closes; does nothing after a webhook). HTTP tests of the GHTK and GHN clients with `httptest` and the documentation's sample responses. e2e on `CARRIER=fake`: linking, a `linked` and a `manual` shipment, a webhook with a wrong secret answering 404.
- App: rules and view-model tests for linking, the carrier chips and the pickup choice; Thiết lập COD's tests ported.
- Staging (by hand, when a GHTK staging account and a GHN dev account exist): `CARRIER=live` against `services-staging.ghtklab.com` and `dev-online-gateway.ghn.vn`; link, make a `linked` shipment at each, read a `manual` code, and see a status arrive.
