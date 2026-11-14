# App wiring, Phase 4: one uploader for photos and videos — Implementation Plan

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`. Server: `POST /v1/uploads` (`server/api/paths/media.yaml`, `schemas/media.yaml` `UploadRequest`/`UploadTicket`), ARCHITECTURE.md "Media". No new screens, so no mockups.
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** one `MediaUploader` that every later phase calls to send a photo or a video: it prepares the file (HEIC and oversized photos become JPEG), asks the server for a ticket, PUTs the bytes to the object store with the signed headers, reports progress, and returns the `upload_id`. Demo keeps a fake with the same progress.

**Architecture:**
- `:core:model`: `MediaKind { PHOTO, VIDEO }`; `UploadProgress` (sealed): `Sending(percent)`, `Done(uploadId)`, `Failed(error)`.
- `:core:data` contracts: `MediaUploader.upload(source: String, kind: MediaKind): Flow<UploadProgress>` (`source` is a content URI or a file path, as the camera and the photo picker give them). Port `MediaFiles` (Android side): `prepare(source, kind): Result<PreparedMedia>` with the bytes' path, content type and size.
- `:core:data/net`: `NetMediaUploader`: `POST /v1/uploads` (authed client, `idempotent {}`), then `PUT ticket.url` on the plain client with exactly `ticket.headers` and no Authorization, streamed with Ktor's `onUpload` for progress. A PUT that fails on transport retries with the same ticket up to 3 times while the ticket has not expired; after that, a new ticket.
- `:core:data` Android: `AndroidMediaFiles`: photos through `ImageDecoder` (HEIC included on minSdk 31), turned upright, scaled so the long side is at most 2048 px and written as JPEG quality 85 when the source is HEIC, over 15 MB, or longer than 2048 px; JPEG/PNG/WebP within the limits go as they are. Videos go as they are (MP4 or QuickTime), refused over 50 MB. Files go to the cache directory and are deleted after the upload.
- Fake: `FakeMediaUploader`: ten steps of 10 %, `Done("up-<n>")`; failures through `FailurePolicy` like the other fakes.

## Global Constraints

Roadmap rules 1–6. Worktree `~/shopnexus/app-wt/wire-uploads`, branch `feat/wire-uploads`. Commits without Co-Authored-By; prose through `humanizing-writing`. Device work on `ANDROID_SERIAL=emulator-5554` only.

## Rulings

- The uploader does not decide how many files go at once; callers (Đăng tin, chat, support) do.
- Too large after preparing → `DataError.Conflict("media_too_large")`; an unsupported type → `DataError.Conflict("media_unsupported")`.
- EXIF stays on the original; a re-encoded JPEG carries none (the server strips EXIF anyway).
- Nothing in Phase 4 calls the uploader from a screen yet; Phases 6–10 do when their repositories go to the server.

## Review Focus

1. The PUT carries exactly the ticket's headers and no Authorization → `NetMediaUploaderTest` (MockEngine).
2. Progress is monotonic and ends with `Done(uploadId)` → `NetMediaUploaderTest`.
3. A transport failure on PUT retries with the same ticket; an expired ticket asks for a new one → `NetMediaUploaderTest`.
4. HEIC and a 4000 px JPEG come out as JPEG ≤ 2048 px; a small PNG is untouched → `AndroidMediaFilesTest` (Robolectric).
5. A real upload against the dev server and its object store → opt-in `LiveServerTest`.

## Tasks

1. Model and contracts; `FakeMediaUploader`; bindings (`FakeBindings.Media`, `NetMedia`).
2. `NetMediaUploader` + MockEngine tests.
3. `AndroidMediaFiles` + tests.
4. Live test against the dev server; `LiveDataModule` includes `NetMedia`; gate; `/code-review`, `/simplify`; merge.
