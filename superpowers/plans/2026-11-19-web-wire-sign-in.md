# Web: Google and phone sign-in through Firebase

Branch `feat/web-wire-sign-in` in `website-wt/sign-in`.

## Goal

`/sign-in` signs in with Google and with a phone number, beside the email code.
Bảo mật adds a phone and reauthenticates by phone (accounts without email) or by
Google. Hoàn thiện hồ sơ's phone task links to the add-phone flow. A suspended
account gets a clear notice on sign-in.

## Rulings

- Firebase Auth runs only in the browser (`src/lib/firebase.ts`, `firebase/app` +
  `firebase/auth`, dynamic imports). `initializeAuth` with `inMemoryPersistence`;
  `signOut` after each proof. The server session is the only session.
- Google: `signInWithPopup` → `GoogleAuthProvider.credentialFromResult().idToken`
  (Google ID token) → server `google_token`.
- Phone: invisible `RecaptchaVerifier` (fresh box per send, appended to body) +
  `signInWithPhoneNumber` → `confirm(code)` → `user.getIdToken()` → `phone_token`.
- The token goes to the page as a hidden form post (PRG, server-rendered errors),
  not an `/api` endpoint: `relay` drops the error code, and the page already
  renders sign-in errors.
- The SDK loads as the page opens wherever a Google button shows; the button is
  disabled until then and `googleToken` calls `signInWithPopup` before any await,
  so the popup opens inside the click (Safari). Phone loads it on the first send.
- Without JS: email works; Google/phone posts answer "cần bật JavaScript", plus a
  `<noscript>` line.
- Reauth by phone: `reauth_required` with no email sets cookie `sn_rp` (then-action,
  10 min, path /me/security); the panel texts the account's own phone.
- Add phone proves the owner first: "Thêm" posts `add-phone-start`; if the access
  token's `auth_time` is older than 12 min (server window 15), the mailed code /
  Google runs with `then: 'add-phone'`, then the page opens `?add-phone`, texts the
  number and posts the fresh token at once. No Firebase token is ever stored.
- `loginHref(back, ended?)` now carries the server code: `&ended=session_revoked` or
  `&ended=account_suspended`. Sign-in shows "Tài khoản đang bị khóa" for the
  latter, for `locals.session.ended === 'account_suspended'`, and for a sign-in
  that answers `account_suspended`.

## Deviations as built

- Code boxes moved into `CodeBoxes.astro` + `lib/code-boxes.ts`; Bảo mật keeps its
  single code input for the phone code.
- Shared browser helpers in `lib/proof-form.ts` (alert line, token post, one step
  at a time, resend countdown).
- `Notice.astro` wraps its text in `[data-notice-text]` so scripts can set it.
- Google is offered on Bảo mật only for reauthentication ("Dùng Google" in the
  mailed-code panel); adding an email by Google was not built.

## Review fixes (2026-11-19)

- `localPath` rejects control characters (browsers strip tab/CR/LF, `/\t/host` → `//host`), backslashes and `//`.
- Sign-in: Google and the phone are separate forms, so Enter in the phone field sends the code.
- One shared `lib/phone-flow.ts` for both pages; `<CodeBoxes/>` on Bảo mật too (email and phone codes).
- `stepper` queues a step asked for while another runs (latest only), so a code completed mid-send is not lost.
- Bảo mật error wording: `proof` (what proved the owner) and `adds` (what the action adds) are separate.
- Bảo mật has one alert slot for server and script errors; the done line hides when an error shows.
- Token sign-in drops `sn_ch`.
