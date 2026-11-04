# Design: no declared marks

Date: 2026-10-27
Status: decided in conversation on 2026-10-27. The mockups in
`app2/.superdesign/` already show every screen without marks, and
`app2/mohinh.md` item 1 says the same. The user approved bringing the Android
app in line, and on 2026-10-27 accepted decisions 4 and 7 as written here. The user
approved the server2 part the same day: a clean removal with no compatibility
layer.

## Goal

Listings have no declared marks, and the model points out no marks. The
user's reasons: people judge wear on used goods differently, so a declared
mark is not a reliable fact, and a mark the model names gives a buyer grounds
for a dispute that drives the seller off the platform. The buyer looks at the
item at the door before paying. The condition scale (Mới, Như mới, Đã dùng),
the facts the seller states (Tin ghi), photos stamped in the app and the
incident record all stay.

## Decisions

1. The contract loses `DeclaredMark`, `Listing.declaredMarks`, `MarkDecision`,
   the model class `AiMark`, `ListingDraft.aiMarks`, `ListingDraft.marks`,
   `PhotoReading.mark`, `RefusalReason.UNDECLARED_MARK` (never used),
   `DealView.declaredMarks`, `PoolListing.marks` and `MoneyKey.DECLARED`. The
   sparkle composable `AiMark()` in `core/designsystem` keeps its name and its
   uses; only the model class goes.
2. Posting waits on no mark. `PostProblem.MARK_PENDING` goes, `canPost` checks
   the title and the price, and the Món đồ step of Đăng tin waits on the title
   only.
3. Đăng tin loses the "Vết đã khai" block (`parts/Marks.kt`), `Block.MARKS`,
   the close-up camera launcher, the `FormEdit` mark edits, `SellEvent.TookMark`
   and `SellEvent.DismissMark`, and the "Đã bỏ qua…" toast. The description the
   model writes from the photos says nothing about marks. The market factor
   "Xước nhẹ ở mặt lưng −100.000 ₫" becomes "Tình trạng Đã dùng −100.000 ₫",
   and the line under the market sheet reads "Tính dung lượng, tình trạng và
   pin."
4. Quay video and Kiểm tra tin (video) lose the mark the model recognised: no
   "Xước nhẹ ở lưng" chip, the finding "Xước nhẹ ở lưng, giây 0:07" becomes
   "Mô tả từ lời bạn nói", and the review has no "Vết đã khai" group. The
   recording tip "Cận chỗ trầy" becomes "Bật màn hình" with the phone symbol,
   and the prompt "Quay cận chỗ trầy" becomes "Bật màn hình lên". What the
   seller says in the video stays in the description, scratches included,
   because those are the seller's own words.
5. Listing detail loses the "Đã khai" rows, the close-ups at the end of the
   photo viewer (with the `photos.size + i` offset and `onOpenMark`), and the
   rule sentence under Tình trạng (`MoneyStep.LISTING_CONDITION` goes).
6. Tin ghi shows claims only. `ClaimsRow` and `ClaimsSheet` lose their
   `marks` parameter, the sheet loses its mark rows and the rule sentence, and
   `RecordSheet` loses "Tin đã khai: …". The check tip "Vết đã khai đúng như
   tin" leaves the fixtures.
7. The model's note on an incident record quotes what the listing states, so
   both sides read the same facts: "Tin ghi: Pin 88% · Máy zin, chưa sửa ·
   Bản VN/A." A listing with no claims gets "Tin không ghi thông tin nào."
   The d-nam fixture note becomes "Tin không nhắc đến loa.", as in the
   mockup.
8. "Quy tắc tiền" in Chat lists only "ShopNexus không giữ tiền và không nhận
   cọc." under "Mọi giao dịch", and the buyer's record on Đơn bán has no rule
   sentence.
9. Chào mừng promises "Ảnh chụp trong app, ghi rõ tình trạng".
10. The copy the user approved on 2026-10-27 comes over in the same pass:
    `money_cancel` "Bạn hủy được đơn khi người bán chưa gửi hàng và không mất
    tiền.", `money_refuse` "Nếu không ưng, bạn từ chối nhận hàng và không mất
    tiền.", `money_after_pay` "Sau khi bạn trả tiền, ShopNexus không đòi lại
    tiền được. Nếu hàng có vấn đề, bạn mở ghi nhận trong chat.", the short
    video message "Video cần dài ít nhất 3 giây", and `sell_waiting_line`
    "Mọi người cũng đang theo dõi món này quanh %1$s".
11. The fixtures drop every mark key (`declaredMarks`, `marks`, `aiMarks`,
    `photoReading.mark`, the video seed's `mark`, `markFrame` and `markNote`),
    so decoding never depends on `ignoreUnknownKeys`.
12. Strings and helpers that only marks used go with them: `sell_marks`
    through `sell_add_mark`, `sell_dismissed`, `review_frame_note`,
    `money_declared`, `open_close_up`, `deal_ui_close_up*`,
    `deal_ui_record_declared`, the discover strings `declared` and
    `close_up_captured`, `DeclaredMarkRow`, and `capturedLabel` once no other
    caller is left. `StringResourcesTest` and lint's UnusedResources catch any
    leftover.

## server2

The API contract still requires `marks` on `Listing` and accepts them on
`ListingDraft`; the `listings` table has a `marks jsonb NOT NULL` column. The
removal is a separate server2 plan, run by the server2 session:

- Drop `marks`, `Mark` and `MarkDraft` from `api/schemas/catalog.yaml`, which
  breaks the contract. The Android app still runs on fakes, so nothing calls
  it yet. Requests are decoded with `DisallowUnknownFields()`
  (`internal/platform/httpx/bind.go`), so a client that still sends `marks`
  gets a 400.
- Add a migration that drops the column, in the same change as the code that
  stops reading and writing it. Migrations apply on every start, so the two
  never run apart.
- Remove marks from the catalog domain, handler, repository and views, so
  uploads, `allPhotos()`, `PendingUploads()` and `Published()` cover the
  listing photos only.
- Update the tests and `server2/ARCHITECTURE.md`.

## Order of work

The app2 plan starts after the sell-wizard session commits its work in
`feature/sell`, `feature/deal`, `core/model/Selling.kt`, `sell.json` and the
Roborazzi removal, because the marks code runs through those files. The line
numbers in `app2/tmp/marks/inventory.md` date from before that commit and get
refreshed at the start of the plan.
