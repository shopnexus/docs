# Design: phone verification with Firebase

Date: 2026-10-27
Status: the user chose on 2026-10-27: Firebase Phone Number Verification
(PNV) with SMS through Firebase Authentication as the fallback, covering the
mockup, app2 and server2. The Đăng nhập mockup is done (draft `login` v4).
The server2 decisions below are proposals for the server2 session to settle
with the user step by step.

## Facts this rests on

- PNV verifies the number on the SIM through the carrier, after the person
  agrees in Android's Credential Manager sheet. It reached general
  availability in May 2026. In September 2026 it covered carriers in
  Finland, France, Germany, Greece, Indonesia, Ireland, Malaysia, the
  Netherlands, Pakistan, Romania, Spain and the United Kingdom, and no
  Vietnamese carrier. Google adds carriers on its side, and an installed app
  uses them without an update.
- `getVerificationSupportInfo()` says per SIM whether PNV works and needs no
  consent. `getVerifiedPhoneNumber(activity)` needs an `Activity` and returns
  the number for display and a signed token.
- Test mode uses a token generated under Security › Phone Verification ›
  Testing. It lasts 7 days, must stay out of source control, and is enabled
  with `enableTestSession(token)` once per process, from the `Application`.
  In test mode the support check always says yes and the number is the
  country code followed by zeros; the phone-number token carries
  `"test_number": true`.
- The PNV token is an ES256 JWT with `typ` `JWT`, keys at
  `https://fpnv.googleapis.com/v1beta/jwks`, `iss`
  `https://fpnv.googleapis.com/projects/5362373878`, an `aud` list holding
  the project-number URL and `https://fpnv.googleapis.com/projects/shopnexus-26aca`,
  and the number in `sub`.
- A Firebase Authentication ID token is an RS256 JWT with `iss`
  `https://securetoken.google.com/shopnexus-26aca`, `aud` `shopnexus-26aca`,
  the number in `phone_number` and `firebase.sign_in_provider` `phone`. Both
  tokens are checked with public keys, so server2 needs the project ID and
  number and no service account.
- The Firebase project is `shopnexus-26aca` (number 5362373878). The app2
  client `vn.shopnexus.app2` has the debug key's SHA-256 registered; the
  SHA-1 was handed to the user to add too.

## Decisions: app2

1. Done on 2026-10-27: `app/google-services.json`, the google-services
   plugin 4.5.0 and Firebase BoM 35.1.0. `:app:assembleDebug` builds.
2. Đăng nhập follows the mockup: the app checks PNV support on opening. A
   supported SIM opens the SIM step ("Xác minh số điện thoại", "Tiếp tục",
   "Dùng số khác"), then Android's consent sheet, then the district, in two
   steps. "Dùng số khác" and an unsupported phone take the SMS path in three
   steps, as today.
3. When PNV fails or the person declines in the sheet, the SIM step stays
   and the snackbar says "Chưa xác minh được qua SIM. Bạn có thể nhập số để
   nhận mã SMS." with "Dùng số khác" as its action.
4. A new port `PhoneVerifier` in `core:data` covers the support check, the
   SIM verification and the SMS send and confirm, each taking the `Activity`
   it needs from the screen, never holding it. It returns a
   `PhoneProof(kind: SIM or SMS, token)`. `SessionRepository` gains
   `signIn(proof)` and loses `sendCode` and `verifyCode`. The fake verifier
   keeps today's behaviour (000000 is wrong, any other code passes, no SIM
   support) for tests and the walks.
5. A new Android library `:core:firebase` holds `FirebasePhoneVerifier` with
   `firebase-pnv` and `firebase-auth` from the BoM. `:app` binds it with
   Hilt; tests bind the fake.
6. Debug builds read `fpnv.testToken` from `local.properties` into a
   `BuildConfig` field and call `enableTestSession` in the `Application` when
   it is not empty. Release builds get an empty string. For the SMS path
   during development the Firebase console holds test numbers with fixed
   codes, so no real SMS is sent.
7. The 45-second resend countdown stays. "Gửi lại mã" resends with the
   `forceResendingToken` Firebase returned.
8. Until server2 has the endpoint below, `FakeSessionRepository.signIn`
   accepts any proof. Wiring the app to server2 over HTTP is a later step,
   the same as for every other repository.

## Decisions: server2 (proposals)

1. One endpoint, `POST /v1/auth/phone {token}` with an `Idempotency-Key`,
   answers like today's OTP verify: `is_new` and the session's tokens.
2. The handler tells the two tokens apart by `iss` and checks the
   signature, `typ`, `iss`, `aud`, `exp` and `iat` against the keys of that
   issuer, cached by their HTTP cache headers. The number comes from `sub`
   (PNV) or `phone_number` (Firebase Authentication) and is stored in the
   +84 form.
3. A token with `test_number: true` is accepted only when the server runs
   with a development flag.
4. Server2 stops sending SMS codes: the SMS sender, the phone quotas and the
   phone challenges go. Whether the email OTP stays is for the server2
   session to settle with the user.
5. A person who signs in by SMS gets a user record in Firebase
   Authentication that holds their phone number. A person who signs in by
   PNV does not.

## Order of work

- Mockup: done.
- server2: the server2 session designs and builds the endpoint with the
  user, from the proposals above.
- app2: a plan after the sell-wizard session commits, since `feature/auth`
  tests and the Gradle files carry its uncommitted work.
- Notifications: another session is adding Firebase Cloud Messaging. It
  adds `firebase-messaging` to the BoM already in `libs.versions.toml` and
  reuses the plugin and `google-services.json`.
