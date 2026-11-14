# App wiring, Phase 2: sign-in and sessions — Implementation Plan

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`. Specs: `specs/2026-11-10-sign-in-email-google-design.md` (app part), `specs/2026-10-27-phone-verification-design.md`. Mockups approved 2026-11-14: Chào mừng v9, Đăng nhập v9, Bảo mật v8, Thêm số điện thoại v2 (`.superdesign/tools/build_{welcome,login,security,phone_gate}.py`).
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** the live flavor signs in for real: Google (Credential Manager), a phone (Firebase PNV, else Firebase SMS) or an email code; keeps and refreshes the server's tokens; signs out; and adds a phone or an email to an account through one shared sheet. The demo flavor keeps working on fakes with the same screens.

**Architecture:**
- `:core:model`: `Identity(kind, value)`.
- `:core:data`: `SessionRepository` loses `sendCode`/`verifyCode`, gains `identities()`, `signIn(Proof)`, `sendEmailCode(email)`, `addIdentity(Proof)`. New ports `PhoneVerifier` and `GoogleAccounts`. Fakes for all three. `net/`: `TokenStore` (DataStore), `NetSessionRepository`, `StoredSessionTokens` (implements the network's `SessionTokens`).
- `:core:network`: `SessionTokens` interface and the `SessionAuth` plugin: adds `Authorization`, refreshes ahead of expiry and once on a 401, one refresh at a time (the server revokes a session whose refresh token is presented twice).
- `:core:firebase` (new Android module, live only): `FirebasePhoneVerifier` (PNV `getVerificationSupportInfo` / `getVerifiedPhoneNumber`; SMS through `PhoneAuthProvider`, ID token, then Firebase sign-out), `CredentialGoogleAccounts`, `CurrentActivity` (the resumed activity both need). Debug builds enable the PNV test session from `local.properties` `fpnv.testToken`.
- `:core:ui`: `IdentitySheet` (phone or email, field then code) and `PhoneGate` (runs an action, or opens the sheet first when the account has no phone).
- Features: Chào mừng (Google, phone), Đăng nhập (email toggle, SIM step, attempts left), Chi tiết tin (Nhắn tin, Trả giá through `PhoneGate`), Đăng tin entry through `PhoneGate`, Bảo mật account rows.

**Tech:** Firebase BoM 35.1.0 (`firebase-auth` 25.0.0, `firebase-pnv` 17.0.0), `androidx.credentials` 1.6.0 (+ `credentials-play-services-auth`), `googleid` 1.2.1, `kotlinx-coroutines-play-services` 1.11.0, DataStore 1.2.1. Web client ID `5362373878-cda1…apps.googleusercontent.com` from `google-services.json` (`default_web_client_id`).

## Global Constraints

Roadmap rules 1–6 (DTOs stay in `:core:network`/`:core:data/net`, mapper and MockEngine tests, fakes updated with every contract change, no TODOs, touched modules only). Branch `feat/wire-sign-in`. Commits without Co-Authored-By; prose through `humanizing-writing`.

## Rulings

- The session is `SIGNED_IN` only after Khu vực (or straight after sign-in when the account is known and the phone has its area). Tokens held before that do not count; a process killed on Khu vực starts signed out.
- After `signIn`, Khu vực shows when the account is new or this phone has no area for it; otherwise sign-in finishes with the known area. This applies to every method (spec: a known Google account goes home).
- The area stays on the phone (DataStore), as decided 2026-11-14; Phase 3 turns districts into communes.
- `account_suspended`, `session_revoked`, `session_expired` and `invalid_refresh_token` from a refresh clear the tokens and sign out.
- Google cancelled by the person is `Cancelled`, which screens ignore.
- `WrongCode(attemptsLeft)` carries the server's `details.attempts_left` for an email code; SMS codes have none.
- Adding a phone or an email needs a sign-in within 15 minutes (server 428 `reauth_required`, kept as decided 2026-11-10; the user confirmed on 2026-11-14 not to relax it for phones). The identity sheet then shows "Xác nhận lại là bạn": Google in one tap or a code to the account's email (or an SMS to its phone), signs in again through `SessionRepository.reauthenticate(proof)`, which must reach the same account, and adds the identity it already holds without asking again.
- Adding an email mails its code through `POST /v1/accounts/me/email-codes`; signing in through `POST /v1/auth/email-codes` (`sendEmailCode(email, CodePurpose)`).

## Review Focus

1. Two concurrent 401s refresh once and both retry with the new token → `SessionAuthTest.concurrentRefusalsRefreshOnce`.
2. A token near expiry is refreshed before the request → `SessionAuthTest.anExpiringTokenIsRefreshedFirst`.
3. A refresh refused with session_revoked signs out and the request goes without a token → `StoredSessionTokensTest`.
4. `signIn` keeps the session signed out until `finishSignIn` → `NetSessionRepositoryTest`.
5. Email code wrong → `WrongCode(attemptsLeft)`; `identity_taken` → `Conflict` → sheet text → `NetSessionRepositoryTest`, `IdentitySheetViewModelTest`.
6. Guest: no Authorization header → `SessionAuthTest.aGuestSendsNoHeader`.
7. Walks and login tests still pass on demo.

## Tasks

1. Contract and fakes: model, ports, `SessionRepository`, fakes (`FakeSessionRepository`, `FakePhoneVerifier`, `FakeGoogleAccounts`), bindings; Login and Welcome view-models moved to the new contract with their tests.
2. `:core:network` `SessionAuth` + tests.
3. `:core:data/net` `TokenStore`, `StoredSessionTokens`, `NetSessionRepository` + tests.
4. `:core:firebase` + PNV test session.
5. UI: Chào mừng, Đăng nhập, `IdentitySheet` + `PhoneGate`, Chi tiết tin and Đăng tin gates, Bảo mật rows; strings; screen tests.
6. Live bindings; gate; emulator: PNV test number, email code (read from the server log), Google; `/code-review`, `/simplify`; merge.
