# Design: sign-in with email or Google, phone required to trade

Date: 2026-11-10.
Status: decided in conversation, question by question. It reverses part of
`2026-10-28-server2-firebase-sign-in-design.md`, which removed email
identities and the `phone_required` checks because every account had a
phone. When the work lands, the decisions below go into
`server/ARCHITECTURE.md`.

## Goals

1. Less friction: a person gets an account with an email alone, through
   Google or a code sent to the address, and verifies a phone only when they
   trade.
2. Fewer SMS: Firebase SMS costs money and PNV covers no Vietnamese carrier,
   so the cheap paths (Google, an email code) come first.

## Decisions

| Question | Decision |
|---|---|
| Identity kinds | `phone` and `email`. Google is a way to prove an email, not a kind of its own. |
| Identities per account | At least one; at most one of each kind. |
| One value, many accounts | No: a phone or email is the identity of one account (`UNIQUE (kind, identifier)`, as today). |
| Sign-up and sign-in | One flow. A proven identity no account holds creates the account (`is_new`). |
| Email proof | A six-digit code that server2 sends. No magic link: the person stays in the app. |
| Google proof | A Google ID token from Android Credential Manager, checked by server2. Not through Firebase Authentication. |
| Google and an email identity | The same address is the same account: both prove the person holds it. Only `email_verified: true` counts. |
| Email normalisation | `contact.ParseEmail`: trimmed and lower-cased. Gmail dots are kept. |
| What needs a phone | Posting a listing, opening a deal, opening a chat (the first message). Answer `403 phone_required`. |
| What does not | Browsing, saving, blocking, the profile, the address book, replying in a chat someone else opened. `RequestCod` keeps needing an address, as today. |
| Address phones | Unchanged: a Vietnamese mobile number, not verified, shared across accounts freely. Verifying one never makes it an identity. |
| Adding a phone identity | Only on purpose: the phone sheet the trade actions open, or Settings. |
| Phone already another account's identity | Refused with `409 identity_taken`. Accounts are never merged. |
| Changing or removing an identity | Out of scope. Only adding. |
| Email provider | Resend over its HTTP API in production; the log sender in development. |

## Data

Migration: the next free number when the work starts (`0025` is claimed by
the follows-reports and realtime-ws plans).

1. `identities`: the kind check becomes `kind IN ('phone', 'email')`, and
   `UNIQUE (account_id, kind)` keeps one identity of each kind.
2. `otp_challenges` and `otp_quotas` come back as `0002` had them, with
   `kind` limited to `'email'` and `purpose IN ('sign_in', 'add_identity')`.
   An `add_identity` challenge carries `account_id`; a `sign_in` challenge
   does not.
3. No row changes: every account today has a phone identity.

## Domain

`Credentials` keeps its invariants:

- `NewCredentials` starts with one identity, as today.
- `Add(identity)` appends one. An account holding that kind already is
  `ErrIdentityKindTaken` (`409 identity_kind_taken`). A value another
  account holds surfaces from `Save` as `ErrIdentityTaken`
  (`409 identity_taken`), as `SignUp` does today.
- Nothing removes an identity, so an account always keeps at least one.

`Kind` gains `KindEmail`. `NewIdentity` takes a `contact.Address` of either
kind.

`Challenge`, `Quota` and `Codes` return from `17cf6bf3^`
(`internal/auth/domain`) into `internal/account/domain`, email only:

- A code has six digits, derived from the challenge ID with `OTP_KEY`, so a
  retried send step sends the same code and no code is stored.
- `code_hash` is `HMAC(OTP_KEY, email, code)`.
- A challenge lives 5 minutes and takes 5 guesses.

## API

Every endpoint takes an `Idempotency-Key`.

### Proofs

Signing in and adding an identity take the same proof: a body with exactly
one of these fields.

```json
{"phone_token": "eyJ..."}
{"google_token": "eyJ..."}
{"email_code": {"challenge_id": "0193...", "code": "583920"}}
```

### Endpoints

| Endpoint | Auth | Body | Answer |
|---|---|---|---|
| `POST /v1/auth/sign-in` | none | a proof, `device_name` | `SignIn`, unchanged: tokens and `account {id, is_new}` |
| `POST /v1/auth/email-codes` | none | `{email}` | `{challenge_id, expires_at, resend_at}`, purpose `sign_in` |
| `POST /v1/accounts/me/email-codes` | signed in | `{email}` | as above, purpose `add_identity`, bound to the caller |
| `POST /v1/accounts/me/identities` | signed in | a proof | `{identities: [{kind, value}]}` |
| `GET /v1/accounts/me` | signed in | | gains `identities: [{kind, value}]` |

The app that sends `phone_token` today keeps working.

`POST /v1/auth/email-codes` answers the same whether or not an account holds
the address. Limits, as before `0022`: one code per address per 45 seconds,
five per address per hour, twenty per client IP per hour.

`POST /v1/accounts/me/identities` accepts a proof of a kind the account
lacks: a phone for an email-only account, Google or an email code for a
phone-only one.

### Errors

| Status | Code | When |
|---|---|---|
| 401 | `invalid_google_token` | A failed check of the Google token. The log says which. |
| 403 | `phone_required` | A trade action by an account without a phone identity. |
| 409 | `identity_kind_taken` | The account holds that kind already. |
| 409 | `identity_taken` | Another account holds that phone or email. |
| 422 | `invalid_code` (`details.attempts_left`), `code_expired`, `code_locked` | As before `0022`. |
| 422 | `invalid_email` | |
| 429 | `otp_too_soon` (`details.resend_at`), `otp_limit` | As before `0022`. |

`identity_taken` tells the caller that the value has an account. Only a
person who just proved they hold the value gets it, so it does not enumerate.

## Flows

Tokens and codes stay out of Restate's journal, which the admin API reads.
The handler or `Account` resolves the proof first:

- `phone_token`: `PhoneVerifier`, as today, to a phone address.
- `google_token`: `GoogleVerifier`, to an email address.
- `email_code`: read the challenge and hash the code; Restate gets
  `{challenge_id, code_hash}`, as `VerifyInput` did before `0022`.

### `SignIn`

Input: a proven address, or a challenge with a code hash.

1. For a challenge: one step judges the code against the challenge it reads,
   the next saves the counted guess or marks it consumed (the logic of
   `17cf6bf3^`). A `sign_in` challenge only.
2. Find the identity by `(kind, value)`; then, as today, refuse a suspended
   account and mark the identity used, or create the account and its
   credentials in one transaction.

The invocation key is `<kind>:<value>/<Idempotency-Key>` for a token, and
`<challenge_id>/<Idempotency-Key>` for a code. For a code the handler
compares the result's challenge and hash with the request before issuing the
session, as before `0022`.

### `AddIdentity`

New Restate service, key `<account_id>/<Idempotency-Key>`.

1. For a challenge: judge and consume it as in `SignIn`; it must be an
   `add_identity` challenge of this account.
2. Read the credentials; `Add` may refuse with `identity_kind_taken`.
3. Save; another account holding the value is `identity_taken`.

Refusals travel as data, as in the other flows.

### `EmailCodeSend`

`OTPSend` from `17cf6bf3^`, email only: admit the IP quota, then the address
quota, create the challenge, then send the mail in a step. Subject:
"Mã xác minh ShopNexus: 583920".

### Google token checks

Package `internal/provider/google`, `GoogleVerifier.Verify(ctx, token)
(contact.Address, error)`:

| Claim | Rule |
|---|---|
| `alg` | RS256 |
| `iss` | `accounts.google.com` or `https://accounts.google.com` |
| `aud` | `GOOGLE_CLIENT_ID`, the web client ID the app passes to Credential Manager |
| `exp` | in the future, 30 seconds of skew |
| `iat` | within 5 minutes, as the phone tokens |
| `email_verified` | `true` |
| `email` | present; through `contact.ParseEmail` |

The key fetching and caching of `provider/firebase` (`keySet`) moves to
`internal/provider/jwks`, shared by both, with its behaviour unchanged.

### `phone_required`

Account's `Service` gains `HasPhone(ctx, id) (bool, error)`. `ListingPost`,
`Deals.Open` and `MessageSend` when `Opening` read it in the step that reads
`Suspended`, and return `phone_required` as data. This is `dd2ed059` undone,
calling module account instead of the old module auth; catalog, deal and
chat depend on account already.

### Email sending

`internal/provider/email`: `Sender`, `LogSender` (development) and
`ResendSender` (`POST https://api.resend.com/emails`).

## Configuration

A missing variable stops the process with its name.

| Variable | Development value | Notes |
|---|---|---|
| `OTP_KEY` | printed by `cmd/keygen` | Returns, with the `make run` check. |
| `EMAIL_SENDER` | `log` | `log` or `resend`; `APP_ENV=prod` with `log` stops the server. |
| `RESEND_API_KEY` | empty | Required when `EMAIL_SENDER=resend`. |
| `EMAIL_FROM` | `ShopNexus <no-reply@...>` | Resend sends only from a domain verified there; the user names the domain before production. Development logs and needs none. |
| `GOOGLE_CLIENT_ID` | the web client ID (`...apps.googleusercontent.com`) | The OAuth client of type Web in project `shopnexus-26aca`, created when the Google provider is turned on; the app passes the same ID as `serverClientId`. |
| `GOOGLE_JWKS_URL` | `https://www.googleapis.com/oauth2/v3/certs` | |

`login_total{method}` gains `google` and `email`.

## App

The app runs on fakes and is not wired to server2 over HTTP yet. This work
covers the screens, the ports and the fakes; the Firebase SMS and Credential
Manager implementations come with the HTTP wiring.

### Mockups first

`welcome.html` and `login.html` change, `phone-gate.html` and
`security.html` are new, written by the builders in `.superdesign/tools/`
and imported as drafts. The app follows the approved drafts.

### Chào mừng

"Bắt đầu với số điện thoại" becomes two buttons: "Tiếp tục với Google"
(primary) and "Tiếp tục với số điện thoại". "Xem trước, đăng nhập sau"
stays.

### Đăng nhập

- The first step is the phone field as today, with "Dùng email" under it.
  It turns the field into an email field (`KeyboardType.Email`) and itself
  into "Dùng số điện thoại". One shared field would cost phone users the
  number pad, the +84 prefix and the grouping.
- The steps: Số điện thoại or Email, Mã xác nhận, Khu vực. The email code
  step reads "Gửi tới a@gmail.com · Đổi email" and shows `attempts_left` on
  a wrong code.
- Google opens the Credential Manager sheet. A new account goes on to
  Khu vực; a known one goes home.

### Phone sheet

A shared component in `core:ui`.

- It opens when the person taps Đăng tin, Hỏi mua or Nhắn tin and the
  session's identities hold no phone, and on a `phone_required` answer.
- The title names the action: "Thêm số điện thoại để đăng tin". The phone
  field, then the SMS code. On success the sheet closes and the action runs.
- `identity_taken` reads "Số này đang dùng để đăng nhập một tài khoản khác."
- Posting still asks for the CCCD check after the phone.

### Cài đặt › Bảo mật › Tài khoản

- Số điện thoại: the number with a tick, or "Chưa thêm · cần để đăng tin,
  mua hàng", which opens the phone sheet.
- Email: the address, or "Chưa thêm", which offers "Dùng Google" or "Nhập
  email" (a code).
- "Đã xác minh qua SIM" stops claiming SIM for every number.

### Ports in `core:data`

- `SessionRepository` loses `sendCode` and `verifyCode`, gains
  `signIn(proof)`, `sendEmailCode(email)` and `addIdentity(proof)`; the
  session carries `identities`.
- New ports `PhoneVerifier` (send and confirm an SMS code) and
  `GoogleAccounts` (get an ID token).
- The fakes keep today's behaviour (000000 is wrong, any other code passes)
  and hold a few numbers and addresses that belong to another account, so
  tests and walks reach `identity_taken`.

## Tests

### Server

- Domain: `Credentials.Add` and its kinds; the restored `Challenge`,
  `Quota` and `Codes` tests.
- `jwks`: the moved `keySet` tests.
- `google`: `googletest.New(t)` serves a JWKS from `httptest` and signs
  tokens, as `firebasetest` does. Each claim in the table refuses a token
  with it wrong.
- `SignIn`: a new and a known email; Google with an address that is an email
  identity reaches that account; a wrong, expired and locked code; an
  `add_identity` challenge does not sign in; the `identity_taken` race.
- `AddIdentity`: a phone for an email account; an email by code and by
  Google for a phone account; `identity_kind_taken`; `identity_taken`;
  another account's challenge.
- `EmailCodeSend`: the same answer for a known and an unknown address; the
  three limits; a retried step sends the same code.
- `phone_required`: an email-only account is refused in `ListingPost`,
  `Deals.Open` and the first message, and replies in a chat another opened.
  `RequestCod` is unchanged.
- Migration: as `phone_sign_in_test.go`, the kind check, `UNIQUE
  (account_id, kind)`, and the phone rows kept.
- e2e: the inbox stub returns to read codes from `LogSender`. Sign up by
  email, then Google with the same address reaches the same account; an
  email account posting gets 403 `phone_required`, adds a phone, posts and
  gets 201; adding another account's number gets 409; `APP_ENV=prod` with
  `EMAIL_SENDER=log` stops `New`.

### App

- ViewModels: Login (phone and email modes, the email code, Google new and
  known), the phone sheet (the action runs after success, `identity_taken`),
  Security (the phone and email rows in each state).
- Compose screen tests for the same screens, as the existing ones.

## Order of work

1. Mockups: welcome, login (phone and email), the phone sheet, security.
   The user approves them on the canvas.
2. Server, one commit per step with the tests green:
   1. `jwks` out of `firebase`.
   2. The migration and `Credentials`.
   3. Email codes: sender, challenges, quotas, `EmailCodeSend`.
   4. `GoogleVerifier`.
   5. `SignIn` with the three proofs.
   6. `AddIdentity` and `identities` in `/me`.
   7. `phone_required`.
   8. OpenAPI, e2e, `ARCHITECTURE.md`.
3. App: ports and fakes, Login, the phone sheet, Security.

Steps 2 and 3 can run side by side once the mockups are approved; the app
uses fakes only.
