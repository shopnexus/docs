# app2 declared-marks removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove declared marks and the model's mark suggestions from the Android app, and bring over the copy the user approved on 2026-10-27.

**Architecture:** Screen by screen, then the contract. Tasks 2 to 4 stop every screen, rule and fake from using marks while the model types still compile; Task 5 deletes the types, fields, fixture keys, strings and components in one pass; Task 6 walks the app on the emulator. Every task leaves `./gradlew check` green.

**Tech Stack:** unchanged (Kotlin 2.4.21, AGP 9.4.1, Compose with material3 1.5.0-beta01, Navigation 3, Hilt, Robolectric, Turbine, Truth). Roborazzi is gone since `c32eea5`.

**Spec:** `/home/beanbocchi/shopnexus/docs/superpowers/specs/2026-10-27-remove-declared-marks-design.md`. Mockups (already without marks): `app2/.superdesign/tools/build_{sell,sell_review,sell_video,detail,chat,cod_order,ship_order,welcome}.py` and `common.py` in the working tree of 2026-10-27. Inventory with line numbers from before `94611c6`: `app2/tmp/marks/inventory.md`.

**Ruling on this plan's form:** as in stages 2 to 5 and the COD-only plan, the plan fixes the contract changes, the rules with their test cases, the UI state and events, and every test by name; code is written during execution. Cost if wrong: screen code is reviewed only at the final review.

## Global Constraints

- Everything in stage 1 to 5's Global Constraints holds (minSdk 31, compileSdk 37, targetSdk 36, JVM 21, features never depend on features, `:core:model` and `:core:domain` are JVM, colours only through the theme, the type scale, Vietnamese strings in `strings.xml` with one value per name across modules, money as `Vnd`).
- Base: branch `remove-marks` from `feature/cod-setup` at `c32eea5` or later, in a worktree under `app2/tmp/worktrees/remove-marks`. The main working tree holds uncommitted Firebase and mockup work; never commit from it.
- A task that changes behaviour fixes every test it breaks in the same task, the app walks included.
- Copy comes word for word from the spec's decisions 3, 4, 7, 9 and 10.
- `./gradlew check` passes at the end of every task (`app2/tmp/gate.sh <log>`, wrapped in `timeout 1500`; Task 1 drops `verifyRoborazziDebug` from the script).
- `ShopNexusJson` keeps `ignoreUnknownKeys = true`, so state saved by an older build with mark keys still decodes.
- Scratch files and logs go under `app2/tmp/`. Commit messages and code comments go through the humanizing-writing checker; commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A draft that an older build saved with a pending AI mark (Tiếp tục nháp, process death in Đăng tin): it opens and posts, and nothing waits on the mark. Pinned in Task 2 (`SellViewModelTest.aRestoredDraftWithAnOldPendingMarkPosts`).
2. The Món đồ step: an empty title still blocks "Tiếp" with the error under its field, and a title alone lets it through whatever the photo reading returned. Pinned in Task 2 (`SellScreenTest.theItemStepWaitsOnlyOnTheTitle`).
3. Listing detail's photo viewer once the close-ups are gone: the last photo opens at "4/4" and swiping past it does nothing. Pinned in Task 3 (`ListingDetailScreenTest.theViewerHoldsOnlyTheListingsPhotos`).
4. An incident record on a listing without claims: the model's note reads "Tin không ghi thông tin nào." and never names a mark. Pinned in Task 4 (`DealRulesTest.aRecordNoteOnAListingWithoutClaims`).
5. A video whose speech names a scratch: the description keeps the seller's words, and no chip, finding or review row presents a mark. Pinned in Task 2 (`FakeSellRepositoryTest.aSpokenScratchStaysInTheDescriptionOnly`).

---

### Task 1: Workspace setup and approved copy

**Files:** Modify `app2/tmp/gate.sh` (ignored scratch); `core/designsystem/src/main/res/values/strings.xml` (`money_cancel`, `money_refuse`, `money_after_pay`); `feature/sell/src/main/res/values/strings.xml` (`sell_waiting_line`, the too-short video message); `feature/auth/src/main/res/values/strings.xml` (`auth_promise_photos`). Tests: `core/designsystem/src/test/.../DealComponentsTest.kt` (`moneyNoteUsesTheSharedWords`), `feature/sell` tests that read the waiting line or the short-take message, `feature/auth/src/test/.../WelcomeScreenTest.kt`.

**Interfaces:** Produces nothing new; later tasks rely on the gate running `./gradlew check --offline` only.

- [ ] **Step 1:** `git -C ~/shopnexus/app2 worktree add tmp/worktrees/remove-marks -b remove-marks feature/cod-setup`. Copy `app2/local.properties` into the worktree (it is ignored; Gradle needs `sdk.dir`). Start the ledger `tmp/worktrees/remove-marks/.superpowers/sdd/2026-10-27-remove-marks/progress.md`.
- [ ] **Step 2:** Refresh the inventory against the new HEAD: `git grep -n` for the symbols listed in `app2/tmp/marks/inventory.md`, plus the JSON fixtures (`declaredMarks`, `"marks"`, `aiMarks`, `"mark"`, `markFrame`, `markNote`, `Vết đã khai`, `Xước nhẹ`). Write the refreshed list into the ledger.
- [ ] **Step 3:** In `tmp/gate.sh` replace `./gradlew check verifyRoborazziDebug --offline` with `./gradlew check --offline` and fix its usage comment.
- [ ] **Step 4: Failing tests.** Update the expected strings first:
  - `DealComponentsTest.moneyNoteUsesTheSharedWords`: CANCEL "Bạn hủy được đơn khi người bán chưa gửi hàng và không mất tiền.", REFUSE "Nếu không ưng, bạn từ chối nhận hàng và không mất tiền.", AFTER_PAY "Sau khi bạn trả tiền, ShopNexus không đòi lại tiền được. Nếu hàng có vấn đề, bạn mở ghi nhận trong chat."
  - The sell test that reads the waiting line expects "23 người đang chờ iPhone 11" over "Mọi người cũng đang theo dõi món này quanh Bình Thạnh".
  - The video test for a take under 3 seconds expects "Video cần dài ít nhất 3 giây".
  - `WelcomeScreenTest` expects "Ảnh chụp trong app, ghi rõ tình trạng".
- [ ] **Step 5:** Run the four modules' tests, expect FAIL on the new words.
- [ ] **Step 6:** Change the strings (`sell_waiting_line` becomes `Mọi người cũng đang theo dõi món này quanh %1$s`). Gate.
- [ ] **Step 7: Commit** `feat: plainer copy for the money rules, the waiting buyers and the welcome`.

### Task 2: Posting rules and sell screens

**Files:** Modify `core/domain/.../Posting.kt` (`canPost` and the post problems no longer look at marks; `PostProblem.MARK_PENDING` stays declared until Task 5 but is never produced); `core/data/.../fake/FakeSellRepository.kt`, `fake/Selling.kt`, `fake/Seeds.kt` (no AI mark from photos or video; `toListing()` writes no marks); `core/data/src/main/resources/fixtures/sell.json` (no `photoReading.mark`; the video seed's `mark`, `markFrame`, `markNote` go; the finding "Xước nhẹ ở lưng, giây 0:07" becomes "Mô tả từ lời bạn nói"; the cue PROMPT "Quay cận chỗ trầy" becomes "Bật màn hình lên"; the CHIP "Xước nhẹ ở lưng" goes; the market factor "Xước nhẹ ở mặt lưng" becomes "Tình trạng Đã dùng" at −100.000 ₫; the AI description drops the sentence about scratches); `feature/sell/.../form/SellForm.kt` (the six mark `FormEdit`s, `answerMark()`, the mark lines in `fromReading` and `forPosting`), `form/SellViewModel.kt` (`MARK_PENDING` out of `FORM_PROBLEMS`, `SellEvent.TookMark` and `DismissMark` and their handlers, the `sell_dismissed` toast), `form/SellScreen.kt` (`Block.MARKS`, `ITEM_BLOCKS`, the item step's gate, the mark camera launcher and its plumbing, `FormBlock(Block.MARKS)`), `review/ReviewScreen.kt` (`MarksBlock` in the review, `markCaption()`), `review/ReviewViewModel.kt` (`MARK_PENDING`, `ReviewEvent.TookMark` and `RemoveAiMark`), `video/VideoScreen.kt` and `res/values/strings.xml` (`video_tip_closeup` becomes "Bật màn hình" with the phone symbol; `sell_market_how` ends "Tính dung lượng, tình trạng và pin."). Tests: `PostingTest`, `PostingAndMoneyTest`, `FakeSellRepositoryTest`, `SimulatorStage4Test`, `Stage4FixturesTest`, `SellFormTest`, `SellViewModelTest`, `ReviewViewModelTest`, `SellPartsTest`, `SellScreenTest`, `app/.../SellWalkTest.kt`.

**Interfaces:**
- Consumes: Task 1's gate.
- Produces: `canPost(draft: ListingDraft): Boolean` checks title and price only; `FormEdit` and `SellEvent`/`ReviewEvent` without mark cases; `SellScreen`'s item step gate reads the title problem only. Task 5 relies on no screen referencing `MarksBlock`, `AiMark` (model), `MarkDecision` or `PostProblem.MARK_PENDING`.

- [ ] **Step 1: Failing tests.**
  - `PostingTest.aListingPostsWithATitleAndAPrice`: a draft with a title, a price and a pending AI mark (built with today's types) can post; `postProblems` is empty.
  - `SellScreenTest.theItemStepWaitsOnlyOnTheTitle`: with an empty title "Tiếp" stays on Món đồ and the title error shows under its field; with a title it moves to Giá. The screen has no node with the text "Vết đã khai".
  - `SellViewModelTest.aRestoredDraftWithAnOldPendingMarkPosts`: a `SavedStateHandle` holding a draft JSON with `aiMarks` (one PENDING) restores and posts.
  - `FakeSellRepositoryTest.aSpokenScratchStaysInTheDescriptionOnly`: the video draft's description contains "vài vết xước nhẹ" (the seller's speech) and the draft has no AI marks and no declared marks; the findings are the four in the spec.
  - `FakeSellRepositoryTest.thePhotoReadingSuggestsNoMark`: the photo reading's description has no "vết" and the reading carries no mark.
  - Replace or delete the mark tests listed in the inventory for these modules (`aMarkTheModelSawMustBeAnswered`, `theModelsMarkIsDeclaredOrDismissed…`, `theSellersOwnMarksTakeAText…`, `dismissingTheMarkWarns`, `removingTheSpokenMarkDismissesItWithTheWarning`, `theModelsMarkWaitsForAnAnswer`, `declaredMarksAreRowsWithTheirCloseUpAndRemove`, `theMarkErrorShowsOnTheItemStep`, the "Vết đã khai" heading checks in `SellPartsTest`, `SellWalkTest`'s mark steps).
- [ ] **Step 2:** Run `:core:domain:test :core:data:test :feature:sell:testDebugUnitTest :app:testDebugUnitTest`, expect the new tests to FAIL.
- [ ] **Step 3: Implement** the file changes above. `parts/Marks.kt` stays in the tree, unused, until Task 5. The sell-wizard session has an uncommitted change in `review/ReviewScreen.kt` (`MarksAndDelivery` drops its duplicate offers `SwitchRow`); if it lands on `feature/cod-setup` first, rebase and keep both.
- [ ] **Step 4:** Gate. **Step 5: Commit** `feat(sell): post without declared marks`.

### Task 3: Listing detail's condition section

**Files:** Modify `feature/discover/.../detail/DetailSections.kt` (`ConditionSection` loses the "Đã khai" rows, `onOpenMark` and the `moneyNotes(LISTING_CONDITION)` line; it keeps the scale, its meaning and the photo-source line), `detail/ListingDetailScreen.kt` (the photo viewer holds the listing's photos only; no `photos.size + i` offset), `core/domain/.../MoneyNotes.kt` (`MoneyStep.LISTING_CONDITION` goes), `core/data/.../fake/GeneratedDetails.kt` and `fixtures/listing-p-iphone13.json`, `pool.json` (no marks on details). Tests: `ListingDetailScreenTest`, `PostingAndMoneyTest` (the `LISTING_CONDITION` assert goes), `Stage2FakesTest`.

**Interfaces:**
- Consumes: nothing from Task 2.
- Produces: `ConditionSection(detail)` without `onOpenMark`; `MoneyStep` without `LISTING_CONDITION`.

- [ ] **Step 1: Failing tests.**
  - `ListingDetailScreenTest.theConditionSectionHasNoDeclaredMarks`: no node with "Đã khai" or the declared-mark rule sentence; the scale shows Như mới with its meaning and "Cả 4 ảnh chụp trong app, có dấu thời gian".
  - `ListingDetailScreenTest.theViewerHoldsOnlyTheListingsPhotos`: opening the last photo shows "4/4"; a further swipe keeps "4/4".
  - `Stage2FakesTest`: the iPhone 13 Pro detail has no marks (drop the old expectation).
- [ ] **Step 2:** Run, expect FAIL. **Step 3: Implement.** **Step 4:** Gate. **Step 5: Commit** `feat(discover): the listing's condition without declared marks`.

### Task 4: Tin ghi and incident records

**Files:** Modify `core/ui/.../deal/Claims.kt` (`ClaimsRow(claims, …)` and `ClaimsSheet(person, claims, tips, …)` without `marks`; the sheet loses its mark rows, close-up viewer state and `MoneyNote(DECLARED)`), `deal/RecordSheet.kt` (no `marks` parameter, no "Tin đã khai: …"), `core/domain/.../MoneyNotes.kt` (`EVERY_DEAL` = `[NO_HOLD]`), `core/domain/.../DealRules.kt` (`recordNote(view)`), `core/data/.../fake/OrderJumps.kt` (d-nam note), `fake/SimulatorSteps.kt` (the refund line without "vết"), `fixtures/deals.json`, `fixtures/account.json` (CheckTip g1 "Vết đã khai đúng như tin" goes), `feature/deal/.../chat/ChatScreen.kt` and `chat/Sheets.kt`, `feature/orders/.../cod/CodOrderScreen.kt`, `orders/SellerParts.kt` (`BuyerRecord` without the rule sentence). Tests: `ClaimsTest`, `DealPiecesTest`, `MoneyRulesTest`, `FakeDealEngineStage3Test`, `CodOrderScreenTest`, `ShipOrderScreenTest`, `DealsWalkTest`, `SliceTest`, `AccountWalkTest`.

**Interfaces:**
- Consumes: nothing from Tasks 2 and 3.
- Produces: `ClaimsRow(claims: List<Claim>, …)`, `ClaimsSheet(person: String, claims: List<Claim>, tips: List<CheckTip>, …)`, `RecordSheet(person: String, …)` without marks; `recordNote(view: DealView): String`.

- [ ] **Step 1: Failing tests.**
  - `ClaimsTest.theRowJoinsTheClaims`: d-nam's line reads "Pin 86% · Bản quốc tế, đã mở mạng".
  - `ClaimsTest.theSheetHoldsClaimsAndTips`: 2 claim rows, 0 mark rows, 3 tips, no gavel sentence, "Gợi ý chung, không phải điều Hoàng Nam cam kết".
  - `DealRulesTest.aRecordNoteQuotesTheClaims`: for d-kiet the note is "Tin ghi: Pin 88% · Máy zin, chưa sửa · Bản VN/A."
  - `DealRulesTest.aRecordNoteOnAListingWithoutClaims`: "Tin không ghi thông tin nào."
  - `MoneyRulesTest.everyDealHoldsOnlyTheNoHoldSentence`: `EVERY_DEAL == listOf(MoneyKey.NO_HOLD)`.
  - `CodOrderScreenTest`, `SliceTest`, `DealsWalkTest`: the Tin ghi lines without mark text ("Pin 88% · Máy zin, chưa sửa · Bản VN/A" for d-kiet).
  - `CodOrderScreenTest`: d-nam's record sheet shows the AI note "Tin không nhắc đến loa." and no "Tin đã khai".
  - `ShipOrderScreenTest`: the buyer's record on Đơn bán shows no rule sentence.
  - Delete `FakeDealEngineStage3Test.aRecordNoteNamesTheMarksInLowerCaseOrSaysThereWereNone` and `ClaimsTest.aMarkInTheSheetIsAPlainRow`.
- [ ] **Step 2:** Run, expect FAIL. **Step 3: Implement.** **Step 4:** Gate. **Step 5: Commit** `feat(deal): Tin ghi and records speak of claims only`.

### Task 5: Delete the marks contract

**Files:** Modify `core/model/.../Listing.kt` (`DeclaredMark`, `Listing.declaredMarks`), `Draft.kt` (`MarkDecision`, the model `AiMark`, `ListingDraft.aiMarks`, `ListingDraft.marks`), `Selling.kt` (`PhotoReading.mark`), `Deal.kt` (`RefusalReason.UNDECLARED_MARK`, `DealView.declaredMarks`), `Discovery.kt` (`PoolListing.marks`), `MoneyKey.kt` (`DECLARED`); `core/domain/.../Posting.kt` (`PostProblem.MARK_PENDING`); `core/designsystem/.../component/Condition.kt` (`DeclaredMarkRow`), `Previews.kt`, `MoneyNote.kt` (the `DECLARED` branch), `PhotoViewer.kt` (KDoc); every fixture key the refreshed inventory lists (`declaredMarks`, `marks`, `aiMarks`); strings `money_declared`, `open_close_up`, `deal_ui_close_up`, `deal_ui_close_up_of`, `deal_ui_close_up_day`, `deal_ui_record_declared`, the discover `declared` and `close_up_captured`, `sell_marks` through `sell_add_mark`, `sell_dismissed`, `review_frame_note`; delete `feature/sell/.../parts/Marks.kt`; delete `capturedLabel` in `parts/Sheets.kt` when `git grep capturedLabel` finds no other caller. Keep the sparkle composable `core/designsystem/.../component/Fields.kt` `AiMark()` and its uses. Tests: `SellingJsonTest`, `DealJsonTest`, `OrderFixtures`, `DealComponentsTest` (drop the unused mark import and val), every test that built a type removed here.

**Interfaces:**
- Consumes: Tasks 2 to 4 left no caller of the removed types.
- Produces: the final contract without marks.

- [ ] **Step 1: Failing test.** `SellingJsonTest.aReadingWithAnOldMarkKeyStillDecodes`: a `PhotoReading` JSON with a `mark` object decodes through `ShopNexusJson`, and the decoded value has no mark field to read (the test pins that the key is ignored, not an error).
- [ ] **Step 2:** Delete the code, fixture keys and strings above. Run `git grep -n -i -E "DeclaredMark|declaredMarks|MarkDecision|aiMarks|MARK_PENDING|MoneyKey.DECLARED|money_declared|Vết đã khai|Đã khai|vết được khai"` in the worktree; the only hits allowed are the condition-scale meanings and this plan's ledger.
- [ ] **Step 3:** Gate, including `StringResourcesTest.everyStringIsUsed` and lint's UnusedResources. **Step 4: Commit** `refactor: drop the declared-marks contract`.

### Task 6: The walk on a device and the hand-off

**Files:** none in the source tree unless the walk finds a bug; `app2/tmp/` for the APK and notes.

- [ ] **Step 1:** Build `:app:assembleDebug`; copy the APK to `app2/tmp/shopnexus-nomarks-<sha>-debug.apk`. Install on the emulator (`app2-api36`) and on the Pixel if it is reachable over adb.
- [ ] **Step 2:** Walk Đăng tin (photos → Món đồ with no marks block → Giá → Xem lại → post), Quay video → Kiểm tra tin, Listing detail of the iPhone 13 Pro (Tình trạng, the photo viewer to 4/4), Chat with Tuấn Kiệt (Quy tắc tiền), Đơn COD of d-nam (Tin ghi, the record sheet), Đơn bán of Đức Huy, Chào mừng. Note each screen against its mockup in the ledger.
- [ ] **Step 3:** A whole-branch review by a fresh reviewer, then one fix pass; gate after it.
- [ ] **Step 4:** Report the branch, the commits, the APK path and the review's outcome to the user. Merging into `feature/cod-setup` or `main` waits for the user.
