# App wiring, Phase 10: account and notifications

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`. Starting points: app main `8c276941`, server main `aca1e9c6`. Phase 9 plan `2026-11-16-app-wire-sell.md` shows the patterns. Live today: Tôi header, Hoàn thiện hồ sơ, Uy tín and Bảo mật read FakeWorld (`LiveProfile`, `FakeBindings.Reputation`, `FakeBindings.Settings`); notifications are emptied in live (`FixtureOrders.kt`); there is no push.

## Goal

Wire the profile (name, bio, avatar, profile tasks), Tôi, Uy tín, Bảo mật (devices, blocked accounts, delete account, sign out other devices), the notification list with read/unread, the Home bell, and push notifications (FCM token, tray, taps) to the server. Live shows no fixture data on these screens.

## Product decisions — 2026-11-17

1. "Đăng xuất các thiết bị khác": one row under the device list in Bảo mật, with a confirm; the current device stays signed in. Mockup first.
2. "Viết giúp" (AI bio) is hidden in live; the demo keeps it.
3. The notification permission (Android 13+) is asked the first time it matters: after the first message, offer or posted listing, through the system dialog. No pre-prompt screen.
4. Presence ("Đang hoạt động") is out of Phase 10.
5. Names: an account without a display name (phone sign-up leaves it empty) is asked "Bạn tên gì?" right after sign-in, one field and Tiếp tục, including older accounts on their next app open; nobody keeps an empty name. Mockup first. Saved with PATCH /v1/accounts/me.
- Defaults (no question): feedback is covered by support tickets of kind `other` (`POST /v1/feedback` was removed; the app has no feedback entry), so only the checklist changes; Tôi order counts, the due-order row and Gói người bán stay hidden in live; the device line drops the city (the server has none) in both flavors; the three ":feature:me" "3/6" tests were already fixed on 14/11.

## Global constraints

- Topic worktrees; keep main's uncommitted `run.sh`/`gradle.properties`; merge locally after checks; no push.
- Server spec-first per `ARCHITECTURE.md`; no authorization relaxation; one read path per view.
- Tokens (session, refresh, FCM) stay in `SessionStore` or memory; never in logs, saved state, journals or committed files.
- Tests: JVM domain/data/VM, a few callback tests, five walks, no visual Robolectric. Live checks via `run_live.py` (memory `live-dev-verification`). Never sign out all or delete the seeded accounts; use a throwaway dev account.

## Backend changes (server branch)

- Refresh of a suspended account: when a session was revoked because its account is suspended, every later refresh still answers `account_suspended`, not `session_revoked` (today the first refresh revokes and a lost answer turns later retries into `session_revoked`).
- Sign out other devices: the bulk sign-out ends every session of the account except the caller's, with the existing recent-auth rule. Adjust `DELETE /v1/auth/sessions` or its spec so the app's row does what its label says.
- Order notices identify the order they are about, so a tap on a notice about an earlier order opens that order and never the deal's newer one.

## App slices

1. Mockup: the "Đăng xuất các thiết bị khác" row and confirm in Bảo mật; the device line without a city. Approval before UI code.
2. `feat/wire-account`: NetProfile (profile-tasks, PATCH /v1/accounts/me with avatar uploads, Tôi from profile-tasks + reputation + saved + my-listings), NetReputation, NetSettings (devices with deferred sign-out and undo, blocked accounts, delete account with reauth and `orders_open`, sign out others), a reauth-only mode of the identity sheet, local reset after delete/sign-out (session store and per-account stores), `account_suspended` at sign-in shows the Welcome card, "Viết giúp" hidden in live.
3. `feat/wire-notifications`: NetNotificationRepository (paged list, unread count, read/unread/read-all with undo ids in chunks, type → route table without fixture ids, reread on notification pushes and reset), Home bell from the same count, remove the live notification blank-out.
4. `feat/wire-push`: firebase-messaging, a messaging service, notification channel, token PUT per session (after sign-in, rotation and reauth), contextual permission request, push extras → route parser, tray cancel on read and sign-out.

## Review focus

- [ ] No live surface shows fixture account data, devices, notifications or ids.
- [ ] Delete and sign-out reset the phone session at once (no "Bạn đã được đăng xuất" card) and forget per-account stores.
- [ ] 428 opens the reauth sheet and retries the pending action once; `orders_open` and `try_again` show their own messages.
- [ ] Notification taps open the right target; order notices open their own order.
- [ ] FCM token is sent once per session and after reauth; never persisted or logged; nothing for guests.
- [ ] Suspended accounts see the suspended card on sign-in, refresh and WebSocket close 4003.

## Verification

Server: touched packages `-p 4`, full e2e with declared-response coverage, lint, coordinated test stack. App: mapper/MockEngine/VM tests, callback tests for the reauth sheet, five walks, lint/detekt/spotless, both APKs. Live: env-gated `LiveAccountTest` (profile edit and restore, sessions, reputation), `LiveNotificationsTest` (an offer produces a notice; read, unread, read-all and undo), and a throwaway-account test for avatar upload, push-token PUT/DELETE, sign out others, delete. FCM delivery and tray taps need Firebase credentials and are reported as unverified unless available.
