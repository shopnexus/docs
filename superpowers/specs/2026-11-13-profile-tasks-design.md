# Design: Hoàn thiện hồ sơ served by the server

Date: 2026-11-13.
Status: decided in conversation. When the work lands, the server decisions
go into `server/ARCHITECTURE.md` (section Screen).

## Why

The app's Hoàn thiện hồ sơ screen (`app/feature/me/tasks/`) lists the
steps a person has left on their profile. Today it runs on `FakeWorld`, and
the rule for when a step is done lives in the app
(`AccountFakes.profileTasks()`). The server already holds every fact the
rule reads. Keeping the rule on the server gives it one home that every
client reads, and follows the decision of 2026-10-27 that module `screen`
serves one `GET` per view of the app.

## Scope

- **Server:** `GET /v1/screens/profile-tasks`, its schemas, the use case in
  module `screen`, e2e tests, and the Screen section of
  `ARCHITECTURE.md`.
- **Not in scope:** `GET /v1/screens/me` (Tôi needs reputation, tier and
  plan, which the server does not have yet). Until then the Tôi card reads
  this view. No app change ships with this work; the app's follow-ups are
  listed at the end and go into `checklist.md`.

## Decisions

- Four steps, in this order: `address`, `bio`, `phone`, `avatar`.
- eKYC is dropped from the product: COD needs only a verified phone. There
  is no `identity` step.
- COD setup is not a profile step: someone who only buys never needs it.
  It stays reachable from the selling flows.
- The view carries no `done`, `total` or `next`. The app counts them from
  `tasks`, and the next step is the first one not done.
- The view carries no display text per step (ward name, phone, "Đã thêm").
  The app reads those from `account` and `address`, which the view returns.

## API

`GET /v1/screens/profile-tasks`, bearer auth, operation
`getProfileTasksScreen`, tag `screen`. Path in
`api/paths/screen_account.yaml`, schemas in
`api/schemas/screen_account.yaml`.

```yaml
ProfileTasksScreen:
  type: object
  additionalProperties: false
  required: [tasks, account, address]
  properties:
    tasks:
      type: array
      minItems: 4
      maxItems: 4
      description: Every step, in the order the screen shows them.
      items: { $ref: "#/ProfileTask" }
    account:
      $ref: "account.yaml#/MyAccount"
    address:
      description: The default address of the caller's address book; null when the book is empty.
      oneOf:
        - $ref: "address.yaml#/Address"
        - type: "null"

ProfileTask:
  type: object
  additionalProperties: false
  required: [key, done]
  properties:
    key:
      type: string
      enum: [address, bio, phone, avatar]
    done:
      type: boolean
```

Responses: 200 with `ProfileTasksScreen`, 401 `Unauthorized`. There is no
404: the caller is the account.

A step is done when:

| key       | done when                                              |
|-----------|--------------------------------------------------------|
| `address` | the address book holds at least one address            |
| `bio`     | the bio is not empty (account trims it when it saves)  |
| `phone`   | the account has an identity of kind `phone`            |
| `avatar`  | the account has an avatar                              |

Writes go through the endpoints that exist: `PATCH /v1/accounts/me` (name,
bio, avatar), `/v1/addresses` (address book), `/v1/accounts/me/identities`
(phone). After a write the app reads this view again.

## Server

- `screen/service`: `ProfileTasks(ctx, account uuid.UUID)
  (ProfileTasksScreen, error)` on `Service`. It reads `accounts.Me` and
  `accounts.Addresses`, takes the default address (the list puts it first)
  and builds the four steps top to bottom, in one function.
- `screen/handler`: the `GET` route under bearer auth, as the inbox view's.
- Errors are the ones `Me` and `Addresses` already return; the handler maps
  them as the other views do.

## Tests

e2e (`e2e/screen_profile_tasks_test.go`):

- A new account signed in by phone: `phone` done, the other three not,
  `address` null.
- After `PATCH /v1/accounts/me` with a bio and an avatar and a
  `POST /v1/addresses`: all four done, `address` is the default one.
- An account signed in by email has `phone` not done until it adds a phone
  identity.
- A blank bio sent as spaces leaves `bio` not done.
- No token: 401.

## App follow-ups (checklist)

- Drop `TaskKey.IDENTITY` and `TaskKey.COD`, and remove `IdentityCheck`
  with the eKYC screens and the "Đã xác minh danh tính" notification.
- The address sheet saves one line "street, ward" on the account. The
  server keeps an address book (recipient name, phone, street, commune),
  so the sheet moves to `/v1/addresses`.
- Read the view from `GET /v1/screens/profile-tasks` instead of
  `FakeWorld`; the Tôi card counts from the same response.
