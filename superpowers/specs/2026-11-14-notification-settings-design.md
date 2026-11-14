# Design: Cài đặt thông báo served by the server

Date: 2026-11-14.
Status: decided in conversation. When the work lands, the server decisions
go into `server/ARCHITECTURE.md` (section Notifications).

## Why

The app's Cài đặt thông báo screen (`app/feature/notifications/settings/`)
has a switch per kind of notice and quiet hours, all on `FakeWorld`. The
server has one switch, `GET/PUT /v1/me/price-cut-alerts`, owned by module
`discovery`, which stops price-drop notices entirely and also hides the
drop since saving in Đã lưu. Two places and two meanings for "a switch"
confuse the reader and the user.

## Decisions

- One resource, `GET/PUT /v1/me/notification-settings`, owned by module
  `notification`. It replaces `/v1/me/price-cut-alerts`, which is removed
  together with `discovery`'s `saved_settings` table (or its
  `price_cut_alerts` column) and every read of it.
- Every switch means the same thing: **off stops the push only**. The
  notice is still written to the list (chat messages are never listed, so
  for `messages` off means nothing reaches the phone). Đã lưu always shows
  the drop since saving; discovery always emits `saved.price_dropped` when
  its rules say so, without consulting any switch.
- Switches and the notice types they cover:

  | field        | app label                    | notice types                                                                            |
  |--------------|------------------------------|-----------------------------------------------------------------------------------------|
  | `messages`   | Tin nhắn                     | chat message pushes                                                                     |
  | `offers`     | Trả giá                      | `offer`, `counter`, `agreed`, `declined`, `agreement_cancelled`, `offer_voided`        |
  | `orders`     | Đơn hàng                     | `cod_requested`, `shipped`, `completed`, `failed`, `order_cancelled`                   |
  | `price_cuts` | Giảm giá ở tin đã lưu        | `price_dropped`                                                                         |
  | `followed`   | Người bán bạn theo dõi       | `followed_listing`                                                                      |
  | `reviews`    | Đánh giá mới                 | `review`                                                                                |

  `watch_matched` keeps its per-watch bell (`/mute`, `/unmute`) and has no
  global switch. `listing_live`, `listing_rejected`, `suspended` and
  `unsuspended` always push. Any notice type added later must be placed in
  this table (a test enumerates `domain.Type` values and fails on one that
  is in neither a switch nor the always-push set).
- Quiet hours: `quiet: {on, from, to}`, `from` and `to` as `"HH:MM"`
  (24-hour, minutes 00–59), in Vietnam time (`Asia/Ho_Chi_Minh`; the
  product is Vietnam only). The window may cross midnight (22:00 → 07:00).
  `from == to` is invalid. While quiet hours are on and the current
  Vietnam time is inside `[from, to)`, no push of any kind is sent;
  notices are still listed. A push skipped by quiet hours is dropped, not
  delayed.
- An account that never saved settings reads the defaults: every switch on,
  quiet hours on from 22:00 to 07:00. No row is written on read.
- `PUT` replaces the whole document (every field required); it returns the
  saved settings. Invalid input is 400 with a specific error code.
- The migration copies `price_cut_alerts = false` rows into the new table
  as `price_cuts = false` with the other fields at their defaults, then
  drops the old storage.
- The worker reads the recipient's settings once per push decision, in a
  journaled step, after writing the notice and before sending to tokens.
- Account erasure deletes the settings row (follow how module `erasure`
  handles notification's other tables).

## API

`GET /v1/me/notification-settings` and `PUT /v1/me/notification-settings`,
bearer auth, tag `notification`, operations `getNotificationSettings` and
`putNotificationSettings`. Schema `NotificationSettings`:

```yaml
NotificationSettings:
  type: object
  additionalProperties: false
  required: [messages, offers, orders, price_cuts, followed, reviews, quiet]
  properties:
    messages:   { type: boolean }
    offers:     { type: boolean }
    orders:     { type: boolean }
    price_cuts: { type: boolean }
    followed:   { type: boolean }
    reviews:    { type: boolean }
    quiet:
      type: object
      additionalProperties: false
      required: [on, from, to]
      properties:
        on:   { type: boolean }
        from: { type: string, pattern: "^([01][0-9]|2[0-3]):[0-5][0-9]$" }
        to:   { type: string, pattern: "^([01][0-9]|2[0-3]):[0-5][0-9]$" }
```

## Tests

- Domain: which switch a type belongs to; quiet window inside/outside,
  crossing midnight, boundaries (`from` inclusive, `to` exclusive).
- Repository: defaults when no row; put then get.
- Worker: a switched-off kind writes the notice and sends no push; quiet
  hours send no push; always-push types ignore switches but not quiet hours.
- e2e: GET defaults, PUT then GET, 400 on bad time and `from == to`, 401
  without token, `/v1/me/price-cut-alerts` is gone (404), a price drop
  with `price_cuts` off still lists the notice.

## App follow-up

The screen's model becomes the six switches and quiet hours above:
`sellTips` is removed, `reputation` becomes `reviews`, `followed` is added.
Đã lưu's switch is the same `price_cuts` field.
