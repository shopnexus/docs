# Website wiring, Phase 3: account — Implementation Plan

> Roadmap: `~/.claude/plans/website-wire-roadmap.md`. Base branch `feat/web-wire-account` (header badges and the account nav read the server). Server: `/v1/accounts/me` (GET, PATCH, DELETE), `/v1/accounts/me/identities`, `/v1/accounts/me/email-codes`, `/v1/auth/sessions` (+ `/others`, `/{id}`, `/current/reauthenticate`), `/v1/addresses` (+ `/{id}`, `/{id}/default`), `/v1/regions`, `/v1/regions/{province_code}/communes`, `/v1/screens/profile-tasks`, `/v1/screens/reputation`, `/v1/notifications` (+ read, read-all), `/v1/me/notification-settings`, `/v1/saved` (+ alert), `/v1/search/watches` (+ mute, unmute, delete), `/v1/blocks`, `/v1/follows`, `/v1/uploads`.

**Goal:** Tôi, Hoàn thiện hồ sơ, Uy tín, Địa chỉ, Bảo mật, Quyền riêng tư, Thông báo and Đã lưu render the server's data and save to it; their mock goes.

## Global Constraints

Roadmap rules 1–5 and the Phase 1 conventions: `orNull`/`unwrap` from `lib/api/client.ts`; page-script endpoints under `src/pages/api/` through `lib/api/relay.ts`, listed in `API` in `lib/routes.ts`; `toggleRemote` for optimistic toggles; English URLs and query keys, Vietnamese UI copy; forms post and redirect (PRG) where a form fits, so pages work without script; a feature the server lacks hides. Phone identity and reauthentication by phone wait for Phase 2 (Firebase); email works now.

## Work split

1. Tôi (`/me`), Hoàn thiện hồ sơ (`/me/profile-tasks`: name, bio, avatar through the shared uploader), Uy tín (`/me/reputation`).
2. Địa chỉ (`/me/addresses`: list, add, edit, delete, default, province and commune pickers), Bảo mật (`/me/security`: signed-in devices, sign out one or the others, add an email, delete the account behind reauth), Quyền riêng tư (`/me/privacy`: blocked accounts, unblock; what others see).
3. Thông báo (`/notifications`: list with paging, read one, read all, push settings), Đã lưu (`/saved`: saved listings with price alerts, saved searches with mute and delete).

Each part is its own branch off the base, gated, then merged into the base; the base merges into `main` after `/code-review` and `/simplify`.

## Deviations (as built)

- Three agents wrote the parts in parallel worktrees; the base took their merges, then one review round and one cleanup round.
- Form posts load the viewer too (the middleware loaded it for GET only), without the badge counts.
- Reauthentication is by email code only; an account without an email cannot confirm on the web until Phase 2 adds phone.
- Hidden for lack of server data: the reputation score, tiers and history, the ID-check and COD profile steps, recent security activity, notification filters, web push, saved-listing groups and comparisons.
- Follow-ups for the server: one call for both unread counts (the header now reads a page of notifications for its count), `province_code` on `Address` (the edit form matches the province by name), `rating` and `sold` on `/v1/accounts/me` (the account nav reads the whole reputation view).
