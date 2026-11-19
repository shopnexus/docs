# App: streamed listing reads, category specs, no price guessing (2026-11-19)

Server branches: `server-wt/category-specs` (feat/category-specs), `server-wt/read-stream`
(feat/read-stream, on top). App worktree: `app-wt/read-stream` (feat/read-stream).

## Decisions (user, 2026-11-19)
- Model writes title + description only, streamed. Condition defaults to used, no specs,
  no price (link keeps Chợ Tốt price), allow_offers left to the app default.
- Specs: each subcategory has `spec_labels`; every label is required; the seller fills them.
- Price: hide all guessing in the app (read estimate and the price guide: Bán nhanh,
  Giá thị trường, similar, demand). Keep the code behind one flag so it can come back.
- Streaming UI: text runs straight into the Tên / Mô tả fields, with the console's
  reveal (eased speed, min 40 cps, ~0.6 s lag; new words fade in; breathing caret).
  No "AI đang viết…" copy.

## Steps
1. Codegen: sync `core/network/openapi/codegen.yaml` from `server-wt/read-stream/api`;
   `prepare.py` drops the SSE operation `streamListingRead` (hand-written client).
2. Network: Ktor `SSE` plugin; `ReadEvents` reads `/v1/listing-reads/{id}/events`
   on the authed client with no request timeout; yields read / text events.
3. Data: `NetSellRepository.follow` follows the SSE stream (reconnects on a network
   error; the first event is always the read), keeps the 180 s give-up. `ListingRead`
   loses `estimate`, gains transient `text: ReadText?`. Fakes stream text too.
4. Specs: `Category.specLabels`; SellContext exposes labels per subcategory;
   `ListingDraft` keeps `specs` keyed by label (drop storage/color/battery fields);
   one `SpecFields` for any category's labels; `PostProblem.SPEC_MISSING`;
   map server `fields.specs` to it.
5. Read fill: aiFields = TITLE, DESCRIPTION (+ CATEGORY from the guess); condition
   USED without sparkle; offers untouched; price only from a link.
6. Price: `PRICE_GUESSING = false` hides PriceGuideHolder calls, market strips,
   suggestion panels, similar/demand, verdict lines, "Giá tham khảo".
7. UI: shared `rememberSmoothReveal` + `StreamingText` in designsystem; photo form
   shows Tên/Mô tả streaming (read-only) while READING; review Reading pane shows
   them under the frames.
8. Tests: JVM/VM tests updated; SellWalkTest without "Bán nhanh". Gate: touched
   modules' tests, then `/code-review`, `/simplify`; merge server + app locally.
