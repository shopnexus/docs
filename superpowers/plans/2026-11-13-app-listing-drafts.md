# App listing drafts: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A draft of a new listing lives on the phone and on the account (on fakes): a save writes the phone at once and puts the draft to the server, last write wins, the account keeps 20 drafts for 30 days after the last edit, the debug panel plays the other phone, a lost network and a draft near its end, Tin của bạn's draft card says "Chưa đồng bộ" and "Còn {n} ngày", and Sell says when the limit kept a draft on the phone.

**Architecture:** `:core:model` gives `ListingDraft` `synced` and `expiresAt`, `Photo` an `uploadId`, `DraftCard` `synced` and `expiresAt`. `:core:domain` holds the numbers (20, 30 days, 3 days) and the card's labels. `:core:data`'s `FakeWorld` keeps two stores, `drafts` (this phone) and `serverDrafts` (the server), and one new file, `DraftServer.kt`, holds every move between them as pure `WorldState` functions: the server's PUT with the limit and lazy expiry, the phone's local write, its put, its pull, deleting, and the other phone. `FakeSellRepository.saveDraft` writes the phone, puts, and answers `SYNCED`, `WAITING` or `LIMIT`; reading Tin của bạn's list or Home's newest draft pulls first. Screens change only by two labels and one message.

**Tech Stack:** Kotlin 2.4.21, AGP 9.4.1, Compose (material3 1.5.0-beta01), Navigation 3, Hilt, kotlinx.serialization, kotlinx-coroutines-test, Robolectric, Turbine, Truth.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-13-listing-drafts-sync-design.md` (the cut-down design: last write wins, no revisions, no notice), section "App" and the app half of "Testing". The server half is planned separately; the app stays on fake data (no Room or DataStore, no HTTP client, no real uploads, no mockups).

**Ruling on this plan's form:** as in the app plans since stage 2 (`2026-11-12-app-order-flow.md`, `2026-11-11-app-listing-reads.md`), the plan fixes the contract in full code: the model, the domain rules, the fake server and phone, the debug controls and the view-model states, each rule with its test by name and assertion, and the copy word for word. Screen code is given as the composables that change, written against today's layouts (`MyListingsScreen.DraftListing`, `DebugHost.DebugPanel`); the spec has no mockup. Cost if wrong: the card line's look is reviewed only at Task 3's gate and the final review.

## Global Constraints

- Stage 1 to 5's constraints hold: minSdk 31, compileSdk 37, targetSdk 36, JVM 21; features never depend on features; `:core:model` and `:core:domain` are JVM; colours only through the theme and the type scale; Vietnamese strings in each module's `strings.xml`, one value per name across modules; money as `Vnd`.
- **Where to work.** The main checkout `~/shopnexus/app` may belong to another session. At plan time (2026-11-13, `main` at `07c92bba`) `git -C ~/shopnexus/app status --short` shows only Superdesign work: modified `.superdesign/resume.json`, `.superdesign/tools/canvas_layout.mjs`, `.superdesign/tools/common.py`; untracked `.superdesign/mockups/density/`, `.superdesign/mockups/masonry-a.html`, `masonry-b.html`, `masonry-c.html`, `.superdesign/tools/build_density.py`, `.superdesign/tools/build_masonry.py`. None of it is in this plan's files. Never commit, stash, switch branches, revert or format in the main checkout. Before Task 1, run `git -C ~/shopnexus/app status --short` again (read-only). If it lists anything under `core/`, `feature/` or `app/`, run `git -C ~/shopnexus/app diff -- <path>` on it, and stop and ask when it touches a file in the File map. Then `git -C ~/shopnexus/app worktree add ~/shopnexus/app/.worktrees/listing-drafts -b feat/listing-drafts HEAD` and `cp ~/shopnexus/app/local.properties ~/shopnexus/app/.worktrees/listing-drafts/`. All work and commits happen in the worktree (`.worktrees/` is ignored by the repo's `/*` rule).
- **Gradle.** No java on PATH: every Gradle command starts with `. ~/.local/share/shopnexus/android-env.sh &&` (it sets `JAVA_HOME=$HOME/.local/opt/jdk-21` and `ANDROID_HOME`). Run from the worktree root. Test only the modules a task touches (`./gradlew :core:model:test`, `:core:domain:test`, `:core:data:testDebugUnitTest`, `:feature:<name>:testDebugUnitTest`, `:app:testDebugUnitTest`), never the whole build; Task 4 runs `check` on the touched modules only. Run long Gradle commands with `run_in_background` and wait for the completion notice; never poll with `pgrep` or `sleep` loops.
- **After Gradle work** (end of every task, and before any long idle): `./gradlew --stop`, then `pgrep -fa '[G]radleDaemon|[K]otlinCompileDaemon'` once; kill any PID it prints with `kill <pid>`; run the `pgrep` once more and expect no output.
- `./gradlew :<module>:spotlessApply` on each touched module before each commit; `check` fails on files ktlint would change.
- `warningsAsErrors = true` in Lint: a string no code reads fails `lintDebug`. Each task that adds strings ends with `python3 tmp/unused_strings.py <module>/src/main/res/values/strings.xml` from the worktree root (Task 1 Step 0 writes it) and deletes what it prints.
- Commits: no `Co-Authored-By` trailer; prefixes as in `git log` (`feat(model): …`, `feat(data): …`, `feat(listings): …`, `feat(sell): …`, `docs: …`). Commit after `git add <paths>`, never `git add -A`. Code comments and commit messages go through `python3 ~/.claude/skills/humanizing-writing/ai-tells.py FILE` (the `humanizing-writing` skill): write the message to `tmp/msg.txt`, check it, then `git commit -F tmp/msg.txt`; check each touched Kotlin file's new comments the same way and fix what it flags.
- **Names shared with the server plan** (keep exactly): `draft_limit_reached`; the limit 20 (`DRAFT_LIMIT`); 30 days after the last edit (`DRAFT_KEEP`); the card's warning from 3 days before (`DRAFT_WARNING`). They appear in KDoc where the fake plays them.
- **The model:** `ListingDraft.synced: Boolean` (false while this phone has edits the server lacks), `ListingDraft.expiresAt: Moment?` (the server's, as last read; null before the first sync); `Photo.uploadId: String?`; `DraftCard.synced: Boolean`, `DraftCard.expiresAt: Moment?`.
- **The fake's rules** (the spec's, as `DraftServer.kt` plays them). Last write wins; no revision, no conflict answer, no 3-way merge.
  - `saveDraft` writes `drafts` at once with `synced = false`, then puts the draft to `serverDrafts`. Accepted: `synced = true`, `expiresAt` taken. `draft_limit_reached` (a create when the server holds 20): the draft stays on the phone, unsynced, and the call answers `LIMIT`.
  - A pull reads `serverDrafts`, after the server deletes drafts past their end. A draft the server has replaces the phone's synced copy. A synced draft the server lacks leaves the phone. An unsynced one is put again.
  - Unsynced drafts are put again, oldest first, on the next save, the next pull, after a delete, and when "Mất mạng" is turned off.
  - `post(draft)` posts, then deletes the draft from both stores.
  - `newestDraft()` reads the merged list.
- **Copy, word for word** (new; Vietnamese, "Xóa" as everywhere in the app):
  - `:feature:listings`: `listings_draft_unsynced` "Chưa đồng bộ", `listings_draft_days_left` "Còn %1$d ngày"; both on one line, joined by " · ". Tin của bạn only, not Tôi's draft row.
  - `:feature:sell`: `sell_draft_limit` "Bạn đã có 20 tin nháp. Xóa bớt nháp cũ để lưu nháp này lên tài khoản."
  - Debug panel (`app/src/debug`): `debug_drafts` "Nháp tin đăng", `debug_other_edits` "Máy khác sửa nháp", `debug_other_deletes` "Máy khác xóa nháp", `debug_offline` "Mất mạng", `debug_near_expiry` "Tua tới sắp hết hạn".
- Screens show results, never narration of what the app is doing: no "Đang đồng bộ…", no spinner text for the sync. A label states how the draft stands.
- Scratch files and logs under `~/shopnexus/app/.worktrees/listing-drafts/tmp/` (ignored by the repo's `/*`).

## Review Focus

1. **Deleting while "Mất mạng" is on.** A draft that reached the server cannot be deleted then: the call fails and nothing changes. A delete on the phone alone would come back at the next pull, since the server still has the draft. A draft that never reached the server deletes on the phone, so "Bỏ" on a new form still works offline. Task 2 `DraftSyncTest.deletingOfflineRefusesASyncedDraftAndDropsALocalOne`.
2. **An edit made offline and a pull that brings the server's copy.** The phone's unsynced version must not be replaced. It is put again and wins, losing the other phone's edit as the spec accepts, rather than the reverse. Task 2 `DraftSyncTest.anUnsyncedEditWinsOverTheServersCopyAtThePull`.
3. **Freeing a slot while Tin của bạn is open.** Deleting an old draft at the limit sends the held draft at once, and its "Chưa đồng bộ" goes on the open screen. A held draft never shows "Còn n ngày", since it has no end yet. Task 2 `DraftSyncTest.deletingADraftSendsTheOneTheLimitHeld`; Task 3 `MyListingsViewModelTest.theUnsyncedLabelGoesOnceADeleteFreesASlot`.
4. **An offline save at 20 drafts.** The server was never asked, so Sell says "Đã lưu nháp", not the limit message, and the card says "Chưa đồng bộ". Task 4 `SellViewModelTest.anOfflineSaveSaysNothingAboutTheLimit`.
5. **Opening a draft that is gone** (deleted on the other phone and pulled, posted, or past its end), for instance from a screen still on the back stack. Đăng tin closes instead of opening an empty form under a dead id. Task 4 `SellViewModelTest.aGoneDraftCloses` (Kiểm tra tin already closes on a missing draft).

## Deviations from the spec

- **`saveDraft` answers `Result<DraftSave>`** (`SYNCED | WAITING | LIMIT`, in `:core:data`), was `Result<DraftId>`. The spec says the call "reports the limit". A draft keeps its id now, so the form needs only the outcome. `WAITING` keeps an offline save apart from the limit (Review Focus 4). The fake puts inside the call when online; a real client would put from a worker.
- **The local write can still fail.** `saveDraft` keeps `FailurePolicy` around the whole call as today, so the forms' "Lưu nháp" failure paths and their tests stay. The put itself never fails at random; only "Mất mạng" makes it wait.
- **`uploadId` only where the app has one.** The fake uploads nothing. Video frames carry the read's upload IDs (`draftOf`); photo-path photos keep `null`. The fake server does not drop photos a listing took or that expired: the spec's server does that, its app section says nothing about it, and the fake has no uploads.
- **Draft ids are not UUIDv7.** The forms keep minting `dr-<millis>`; the real client mints UUIDv7.
- **Đăng tin closes on a missing draft.** The spec changes only labels and a message. This one behaviour is added so a stale route does not open an empty form (Review Focus 5).
- **Deleting while "Mất mạng" is on.** The spec has no queued delete. A draft that has an `expiresAt` (it reached the server) refuses the delete with the fake's network error. One without (it never reached the server) deletes on the phone. A post's delete follows the same rule and stays silent: an offline post keeps a synced draft in both stores, as the spec's "If that call fails, the draft stays" says.
- **When the phone pulls.** The spec says "reading the list pulls". The fake pulls when Tin của bạn's list or Home's newest draft starts reading (so opening Tin của bạn and pull to refresh both pull), when "Mất mạng" goes off, and through the puts a save or a delete makes. The other phone's changes wait for that, as the spec says.

## Rulings on what the spec leaves open

- **The card's line:** under "N ảnh · giá", "Chưa đồng bộ · Còn {n} ngày" with the first label's icon (`CloudOff`, `Schedule`). The verification line stays below it.
- **"Còn {n} ngày":** whole days left, counted up (`ceil`), shown while `0 < left ≤ 3 days`. Nothing once the end has passed: the next pull removes a synced draft, and an unsynced one is put again with a new end.
- **"Mất mạng"** holds only the drafts' calls (put, list, delete). Posting, reads and other commands go on; "Lỗi mạng giả" covers those. The other phone keeps working on the server meanwhile.
- **The other phone acts on the draft edited last on the server.** "Máy khác sửa nháp" takes 100.000 ₫ off its price, or sets 4.500.000 ₫ when it has none, and the edit counts as a new last edit (a new 30-day end). "Máy khác xóa nháp" deletes it. "Tua tới sắp hết hạn" makes its last edit 27 days ago, so its end is 3 days out. With no draft on the server, each does nothing.
- **Sell's limit message:** "Lưu nháp" and "Để sau" show it in place of "Đã lưu nháp", with "Xem" to Tin của bạn's drafts. An autosave shows it once a visit. Closing with "Lưu nháp" shows it over the next screen (`SellEffect.KeptOnPhone`). Verify and COD setup save and move on without it. Kiểm tra tin does the same.
- **Home** needs no code: `HomeViewModel` already reads `newestDraft()`; Task 2 pins it with a test.

## File map

| File | Responsibility | Task |
|---|---|---|
| `core/model/.../Draft.kt`, `Listing.kt`, `MyListings.kt`; `SellingJsonTest.kt` | `synced`, `expiresAt`, `Photo.uploadId`, the card's two fields | 1 |
| `core/domain/.../Drafts.kt` (new), `DraftsTest.kt` (new) | `DRAFT_LIMIT`, `DRAFT_KEEP`, `DRAFT_WARNING`, `DraftLabel`, `draftDaysLeft`, `draftLabels` | 1 |
| `tmp/unused_strings.py` (scratch) | lists strings no code reads | 1 |
| `core/data/.../fake/DraftServer.kt` (new) | the server's PUT, limit and expiry; the phone's write, put, pull and delete; the other phone | 2 |
| `core/data/.../fake/FakeWorld.kt` | `serverDrafts`, `draftsOffline`, the seeded draft on both sides | 2 |
| `core/data/.../Repositories.kt`, `fake/FakeSellRepository.kt`, `fake/FakeMyListingsRepository.kt`, `fake/FakeSettingsRepository.kt` | `DraftSave`, the save, the pull on reading, posting, the card's fields, deleting, erasure | 2 |
| `core/data/.../fake/DebugControls.kt` | "Mất mạng" and the three draft actions | 2 |
| `core/data/src/test/.../fake/DraftSyncTest.kt` (new), `FakeSellRepositoryTest.kt`, `FakeSettingsRepositoryTest.kt`, `DebugControlsTest.kt` | each rule | 2 |
| `app/src/debug/.../DebugHost.kt`, `app/src/debug/res/values/strings.xml`, `app/src/testDebug/.../DebugPanelTest.kt` | the panel's draft rows | 2 |
| `feature/discover/src/test/.../home/HomeViewModelTest.kt` | "Tiếp tục nháp" reads the merged list | 2 |
| `feature/listings/.../mine/MyListingsViewModel.kt`, `MyListingsScreen.kt`, `res/values/strings.xml`, both tests | the card's labels | 3 |
| `feature/sell/.../form/Autosave.kt`, `SellViewModel.kt`, `SellScreen.kt`; `review/ReviewViewModel.kt`, `ReviewScreen.kt`; `res/values/strings.xml`; `SellViewModelTest.kt`, `ReviewViewModelTest.kt` | the limit message, a gone draft, the frames' uploads | 4 |
| `README.md` | the fake drafts | 4 |

## Task order and interfaces

1 → 2 → 3 → 4. Task 2 needs 1; Tasks 3 and 4 need 1 and 2 and touch different modules, so they can run in either order. The app assembles after every task: `:feature:sell` ignores what `saveDraft` answers until Task 4.

Names later tasks rely on:

- Task 1, `vn.shopnexus.core.model`: `ListingDraft(…, synced: Boolean = false, expiresAt: Moment? = null)`; `Photo(url, source, alt = "", uploadId: String? = null)`; `DraftCard(…, needsVerification, synced: Boolean = true, expiresAt: Moment? = null)`. `vn.shopnexus.core.domain`: `const val DRAFT_LIMIT = 20`; `val DRAFT_KEEP: Duration` (30 days); `val DRAFT_WARNING: Duration` (3 days); `sealed interface DraftLabel { Unsynced; DaysLeft(days: Int) }`; `fun draftDaysLeft(expiresAt: Instant, now: Instant): Int?`; `fun draftLabels(card: DraftCard, now: Instant): List<DraftLabel>`.
- Task 2, `vn.shopnexus.core.data`: `enum class DraftSave { SYNCED, WAITING, LIMIT }`; `SellRepository.saveDraft(draft: ListingDraft): Result<DraftSave>`. `vn.shopnexus.core.data.fake`: `WorldState.serverDrafts: Map<DraftId, ListingDraft>`, `WorldState.draftsOffline: Boolean`; internal `WorldState.serverPut(draft, now): Pair<WorldState, Boolean>`, `savedLocally(draft, now)`, `put(id, now): Pair<WorldState, DraftSave>`, `putWaiting(now)`, `pulled(now)`, `draftDeleted(id, now): WorldState?`, `otherPhoneEdited(now)`, `otherPhoneDeleted(now)`, `nearExpiry(now)`; public `fun WorldState.withOtherPhoneDrafts(count: Int, now: Instant): WorldState`; `DebugControls.offline: Boolean` (var), `otherPhoneEdits()`, `otherPhoneDeletes()`, `nearExpiry()`.
- Task 3: `ListingsContent.Ready(listings: MyListings, labels: Map<DraftId, List<DraftLabel>> = emptyMap())`; `MyListingsViewModel(route, mine, clock: Clock, saved)`.
- Task 4, `vn.shopnexus.feature.sell`: `SellEffect.KeptOnPhone`; `ListingDraft.normal()` strips `synced` and `expiresAt`; `Autosave.schedule(keeps, current, onSaved: (sent: ListingDraft, save: DraftSave) -> Unit)`.

---

### Task 1: Model and draft rules

**Files:**
- Modify: `core/model/src/main/kotlin/vn/shopnexus/core/model/Draft.kt` (`ListingDraft`), `Listing.kt:9-11`, `MyListings.kt:58-67`
- Create: `core/domain/src/main/kotlin/vn/shopnexus/core/domain/Drafts.kt`
- Test: `core/model/src/test/kotlin/vn/shopnexus/core/model/SellingJsonTest.kt`, `core/domain/src/test/kotlin/vn/shopnexus/core/domain/DraftsTest.kt` (new)

**Interfaces:**
- Consumes: nothing new.
- Produces: the Task 1 names in "Task order and interfaces".

- [ ] **Step 0: The worktree and the strings check**

Run the "Where to work" steps of the Global Constraints. Expected: `git -C ~/shopnexus/app/.worktrees/listing-drafts branch --show-current` prints `feat/listing-drafts`.

Write `tmp/unused_strings.py` in the worktree:

```python
#!/usr/bin/env python3
"""Prints the names in one strings.xml that no Kotlin or XML source outside the tests reads."""
import os
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
strings = (root / sys.argv[1]).resolve()
names = re.findall(r'<string name="([^"]+)"', strings.read_text(encoding="utf-8"))
SKIP = {"build", "tmp", "test", "testDebug", "androidTest"}
texts = []
for folder, subfolders, files in os.walk(root):
    subfolders[:] = [d for d in subfolders if d not in SKIP and not d.startswith(".")]
    if "/src/" not in folder:
        continue
    for name in files:
        if name.endswith((".kt", ".xml")) and name != "strings.xml":
            texts.append(Path(folder, name).read_text(encoding="utf-8"))
text = "\n".join(texts)
for name in names:
    if not re.search(rf"string\.{re.escape(name)}\b|@string/{re.escape(name)}\b", text):
        print(name)
```

Run: `python3 tmp/unused_strings.py feature/listings/src/main/res/values/strings.xml`. Expected: no output.

- [ ] **Step 1: Write the failing model tests**

In `SellingJsonTest`, add:

```kotlin
    @Test
    fun aDraftKeepsWhetherTheAccountHasItAndItsEnd() {
        val synced = draft().copy(photos = listOf(back.copy(uploadId = "up-1")), synced = true, expiresAt = at)
        roundTrip(ListingDraft.serializer(), synced)
        val text = ShopNexusJson.encodeToString(ListingDraft.serializer(), synced)
        assertThat(text).contains("\"synced\":true")
        assertThat(text).contains("\"uploadId\":\"up-1\"")
    }

    @Test
    fun aDraftReadBeforeItsFirstSyncIsUnsyncedWithNoEnd() {
        val read = ShopNexusJson.decodeFromString(ListingDraft.serializer(), """{"id":"dr-1","origin":"PHOTOS"}""")
        assertThat(read.synced).isFalse()
        assertThat(read.expiresAt).isNull()
        assertThat(ShopNexusJson.decodeFromString(Photo.serializer(), """{"url":"u","source":"APP"}""").uploadId).isNull()
        val card = DraftCard(DraftId("dr-1"), DraftOrigin.PHOTOS, null, "", 0, null, needsVerification = false)
        assertThat(card.synced).isTrue()
        assertThat(card.expiresAt).isNull()
    }
```

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:model:test`
Expected: compilation fails (`synced`, `expiresAt`, `uploadId` undefined).

- [ ] **Step 2: The model**

`Draft.kt`, at the end of `ListingDraft`'s parameters, after `readCover`:

```kotlin
    /** The account has this version: false while this phone has edits the server lacks. */
    val synced: Boolean = false,
    /** When the server deletes the draft, 30 days after its last edit, as this phone last read it; null before its first sync. */
    val expiresAt: Moment? = null,
```

`Listing.kt`:

```kotlin
/**
 * A listing photo and where it came from: taken in the app or picked from the library. [uploadId] is the upload the
 * server knows it by, where the app has one.
 */
@Serializable
data class Photo(val url: String, val source: PhotoSource, val alt: String = "", val uploadId: String? = null)
```

`MyListings.kt`, `DraftCard` after `needsVerification`:

```kotlin
    /** The account has this version; false shows "Chưa đồng bộ". */
    val synced: Boolean = true,
    /** When the server deletes the draft; null before its first sync. */
    val expiresAt: Moment? = null,
```

Run: `./gradlew :core:model:test`. Expected: PASS.

- [ ] **Step 3: Write the failing domain test**

Create `core/domain/src/test/kotlin/vn/shopnexus/core/domain/DraftsTest.kt`:

```kotlin
package vn.shopnexus.core.domain

import com.google.common.truth.Truth.assertThat
import java.time.Duration
import java.time.Instant
import org.junit.Test
import vn.shopnexus.core.model.DraftCard
import vn.shopnexus.core.model.DraftId
import vn.shopnexus.core.model.DraftOrigin

class DraftsTest {
    private val now = Instant.parse("2026-10-15T08:10:00Z")

    private fun card(synced: Boolean = true, expiresAt: Instant? = null) =
        DraftCard(DraftId("dr-1"), DraftOrigin.PHOTOS, null, "Bàn gỗ", 1, null, needsVerification = false, synced = synced, expiresAt = expiresAt)

    @Test
    fun theDaysLeftCountUpFromThreeDaysOut() {
        assertThat(draftDaysLeft(now.plus(Duration.ofDays(3)).plusSeconds(1), now)).isNull()
        assertThat(draftDaysLeft(now.plus(Duration.ofDays(3)), now)).isEqualTo(3)
        assertThat(draftDaysLeft(now.plus(Duration.ofHours(49)), now)).isEqualTo(3)
        assertThat(draftDaysLeft(now.plus(Duration.ofHours(48)), now)).isEqualTo(2)
        assertThat(draftDaysLeft(now.plusSeconds(60), now)).isEqualTo(1)
        assertThat(draftDaysLeft(now, now)).isNull()
        assertThat(draftDaysLeft(now.minusSeconds(60), now)).isNull()
    }

    @Test
    fun aCardSaysUnsyncedThenTheDaysLeft() {
        assertThat(draftLabels(card(synced = false, expiresAt = now.plus(Duration.ofHours(30))), now))
            .containsExactly(DraftLabel.Unsynced, DraftLabel.DaysLeft(2)).inOrder()
        assertThat(draftLabels(card(synced = false), now)).containsExactly(DraftLabel.Unsynced)
        assertThat(draftLabels(card(expiresAt = now.plus(Duration.ofDays(29))), now)).isEmpty()
    }

    @Test
    fun theNumbersAreTheServers() {
        assertThat(DRAFT_LIMIT).isEqualTo(20)
        assertThat(DRAFT_KEEP).isEqualTo(Duration.ofDays(30))
        assertThat(DRAFT_WARNING).isEqualTo(Duration.ofDays(3))
    }
}
```

Run: `./gradlew :core:domain:test --tests '*DraftsTest*'`. Expected: compilation fails.

- [ ] **Step 4: The draft rules**

Create `core/domain/src/main/kotlin/vn/shopnexus/core/domain/Drafts.kt`:

```kotlin
package vn.shopnexus.core.domain

import java.time.Duration
import java.time.Instant
import vn.shopnexus.core.model.DraftCard

/** The account keeps 20 drafts; the server refuses a 21st with `draft_limit_reached`. */
const val DRAFT_LIMIT = 20

/** The server deletes a draft 30 days after its last edit. */
val DRAFT_KEEP: Duration = Duration.ofDays(30)

/** The card's "Còn n ngày" starts 3 days before the end. */
val DRAFT_WARNING: Duration = Duration.ofDays(3)

private const val DAY_MILLIS = 86_400_000L

/** What a draft card says beside its photos and price, in the order it says them. */
sealed interface DraftLabel {
    /** "Chưa đồng bộ". */
    data object Unsynced : DraftLabel

    /** "Còn {days} ngày". */
    data class DaysLeft(val days: Int) : DraftLabel
}

/** Whole days left until [expiresAt], counted up, from 3 days before it; null earlier, and once it has passed. */
fun draftDaysLeft(expiresAt: Instant, now: Instant): Int? {
    val left = Duration.between(now, expiresAt)
    if (left.isNegative || left.isZero || left > DRAFT_WARNING) return null
    return ((left.toMillis() + DAY_MILLIS - 1) / DAY_MILLIS).toInt()
}

/** A draft the account lacks says so first, then the days left; a synced draft far from its end says nothing. */
fun draftLabels(card: DraftCard, now: Instant): List<DraftLabel> = listOfNotNull(
    DraftLabel.Unsynced.takeIf { !card.synced },
    card.expiresAt?.let { draftDaysLeft(it, now) }?.let(DraftLabel::DaysLeft),
)
```

Run: `./gradlew :core:domain:test --tests '*DraftsTest*'`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
./gradlew :core:model:spotlessApply :core:domain:spotlessApply
git add core/model core/domain
```

`tmp/msg.txt`: `feat(model): a draft says whether the account has it and when the server deletes it`. Check it with the humanizer, then `git commit -F tmp/msg.txt`. Stop the daemons.

### Task 2: The fake server, the phone's sync and the debug panel

**Files:**
- Create: `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/DraftServer.kt`
- Modify: `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/FakeWorld.kt` (`WorldState` after `drafts`, `initial()`), `core/data/src/main/kotlin/vn/shopnexus/core/data/Repositories.kt` (`saveDraft`, new `DraftSave`), `fake/FakeSellRepository.kt` (`newestDraft`, `saveDraft`, `post`), `fake/FakeMyListingsRepository.kt` (`listings`, `panes`, `deleteDraft`), `fake/FakeSettingsRepository.kt:165-167`, `fake/DebugControls.kt`
- Modify: `app/src/debug/kotlin/dev/shopnexus/app/DebugHost.kt`, `app/src/debug/res/values/strings.xml`
- Test: `core/data/src/test/kotlin/vn/shopnexus/core/data/fake/DraftSyncTest.kt` (new), `FakeSellRepositoryTest.kt`, `FakeSettingsRepositoryTest.kt`, `DebugControlsTest.kt`; `app/src/testDebug/kotlin/dev/shopnexus/app/DebugPanelTest.kt`; `feature/discover/src/test/kotlin/vn/shopnexus/feature/discover/home/HomeViewModelTest.kt`

**Interfaces:**
- Consumes: Task 1's model and `DRAFT_LIMIT`, `DRAFT_KEEP`, `DRAFT_WARNING`.
- Produces: the Task 2 names in "Task order and interfaces".

- [ ] **Step 1: Write the failing sync tests**

Create `core/data/src/test/kotlin/vn/shopnexus/core/data/fake/DraftSyncTest.kt`:

```kotlin
package vn.shopnexus.core.data.fake

import com.google.common.truth.Truth.assertThat
import java.time.Clock
import java.time.Instant
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Test
import vn.shopnexus.core.data.DraftSave
import vn.shopnexus.core.domain.DRAFT_KEEP
import vn.shopnexus.core.domain.DRAFT_WARNING
import vn.shopnexus.core.domain.VN_ZONE
import vn.shopnexus.core.model.DraftId
import vn.shopnexus.core.model.DraftOrigin
import vn.shopnexus.core.model.ListingDraft
import vn.shopnexus.core.model.Vnd

/** The phone's drafts against the fake server: saving, Mất mạng, the limit, the other phone, posting and the end. */
class DraftSyncTest {
    private val world = FakeWorld()
    private val failures = FailurePolicy(latencyMillis = 0)
    private val now = Fixtures.NOW
    private val sell = sellAt(now)
    private val mine = FakeMyListingsRepository(world, failures, Clock.fixed(now, VN_ZONE), CounterpartListener { _, _ -> })
    private val seeded = DraftId("dr-iphone11")
    private val new = DraftId("dr-new")

    private fun sellAt(at: Instant) = FakeSellRepository(world, failures, Clock.fixed(at, VN_ZONE), CounterpartListener { _, _ -> }, Pace())

    /** The seeded draft as a form opens it now. */
    private fun opened() = world.value.drafts.getValue(seeded)
    private fun phone(id: DraftId) = world.value.drafts[id]
    private fun server(id: DraftId) = world.value.serverDrafts[id]

    /** "Mất mạng", as the debug panel sets it: off, the phone pulls. */
    private fun offline(on: Boolean) = world.update { it.copy(draftsOffline = on).pulled(now) }
    private fun pull() = world.update { it.pulled(now) }
    private fun ready() = world.update { it.copy(account = it.account!!.copy(verified = true, codSetup = READY_COD)) }
    private fun blank() = ListingDraft(new, DraftOrigin.PHOTOS, title = "Bàn gỗ")

    @Test
    fun theSeededDraftStartsSyncedOnBothSides() {
        val d = opened()
        assertThat(d.synced).isTrue()
        assertThat(d.expiresAt).isEqualTo(d.updatedAt!!.plus(DRAFT_KEEP))
        assertThat(server(seeded)).isEqualTo(d)
    }

    @Test
    fun aSaveOnlineReachesTheServer() = runTest {
        assertThat(sell.saveDraft(opened().copy(title = "iPhone 11 Trắng 64GB")).getOrThrow()).isEqualTo(DraftSave.SYNCED)
        val d = phone(seeded)!!
        assertThat(d.synced).isTrue()
        assertThat(d.updatedAt).isEqualTo(now)
        assertThat(d.expiresAt).isEqualTo(now.plus(DRAFT_KEEP))
        assertThat(server(seeded)).isEqualTo(d)
        assertThat(server(seeded)!!.title).isEqualTo("iPhone 11 Trắng 64GB")
    }

    /** Mất mạng: a save stays on the phone, unsynced; back online, it reaches the server. */
    @Test
    fun anOfflineSaveWaitsAndGoesOutWhenTheNetworkComesBack() = runTest {
        offline(true)
        assertThat(sell.saveDraft(blank()).getOrThrow()).isEqualTo(DraftSave.WAITING)
        assertThat(phone(new)!!.synced).isFalse()
        assertThat(phone(new)!!.expiresAt).isNull()
        assertThat(server(new)).isNull()
        offline(false)
        assertThat(phone(new)!!.synced).isTrue()
        assertThat(server(new)!!.title).isEqualTo("Bàn gỗ")
    }

    @Test
    fun theNextSaveSendsTheDraftsThatWaited() = runTest {
        offline(true)
        sell.saveDraft(blank()).getOrThrow()
        // The network is back, but nothing has pulled yet.
        world.update { it.copy(draftsOffline = false) }
        sell.saveDraft(opened().copy(title = "Sửa")).getOrThrow()
        assertThat(phone(new)!!.synced).isTrue()
        assertThat(server(new)).isNotNull()
    }

    /** `draft_limit_reached`: the account holds 20; a new draft stays on this phone, and an existing one still saves. */
    @Test
    fun aNewDraftPastTheLimitStaysOnThePhone() = runTest {
        world.update { it.withOtherPhoneDrafts(19, now) }
        assertThat(world.value.serverDrafts).hasSize(20)
        assertThat(sell.saveDraft(blank()).getOrThrow()).isEqualTo(DraftSave.LIMIT)
        assertThat(phone(new)!!.synced).isFalse()
        assertThat(phone(new)!!.expiresAt).isNull()
        assertThat(server(new)).isNull()
        assertThat(sell.saveDraft(opened().copy(title = "Sửa")).getOrThrow()).isEqualTo(DraftSave.SYNCED)
    }

    /** Review Focus 3, the data side: the slot a delete frees takes the draft the limit held. */
    @Test
    fun deletingADraftSendsTheOneTheLimitHeld() = runTest {
        world.update { it.withOtherPhoneDrafts(19, now) }
        sell.saveDraft(blank()).getOrThrow()
        mine.deleteDraft(seeded).getOrThrow()
        assertThat(phone(new)!!.synced).isTrue()
        assertThat(server(seeded)).isNull()
        assertThat(world.value.serverDrafts).hasSize(20)
    }

    /** The other phone edits; this phone takes the server's copy at its next pull, here by opening Tin của bạn. */
    @Test
    fun anEditOnTheOtherPhoneReplacesTheSyncedCopyAtTheNextPull() = runTest {
        world.update { it.otherPhoneEdited(now) }
        assertThat(server(seeded)!!.price).isEqualTo(Vnd(4_500_000))
        assertThat(phone(seeded)!!.price).isNull()
        assertThat(mine.listings().first().drafts.single().price).isEqualTo(Vnd(4_500_000))
        assertThat(phone(seeded)!!.synced).isTrue()
    }

    @Test
    fun aDraftDeletedOnTheOtherPhoneLeavesAtTheNextPull() = runTest {
        world.update { it.otherPhoneDeleted(now) }
        assertThat(phone(seeded)).isNotNull()
        assertThat(mine.listings().first().drafts).isEmpty()
        assertThat(phone(seeded)).isNull()
    }

    /** Last write wins: edits the other phone deleted meanwhile go back to the account. */
    @Test
    fun anUnsyncedDraftTheOtherPhoneDeletedIsPutAgain() = runTest {
        offline(true)
        sell.saveDraft(opened().copy(title = "Của tôi")).getOrThrow()
        world.update { it.otherPhoneDeleted(now) }
        offline(false)
        assertThat(server(seeded)!!.title).isEqualTo("Của tôi")
        assertThat(phone(seeded)!!.synced).isTrue()
    }

    /** Review Focus 2: the pull does not replace an unsynced edit; the edit goes out and wins. */
    @Test
    fun anUnsyncedEditWinsOverTheServersCopyAtThePull() = runTest {
        offline(true)
        sell.saveDraft(opened().copy(title = "Của tôi")).getOrThrow()
        world.update { it.otherPhoneEdited(now) }
        offline(false)
        assertThat(phone(seeded)!!.title).isEqualTo("Của tôi")
        assertThat(phone(seeded)!!.synced).isTrue()
        assertThat(server(seeded)!!.title).isEqualTo("Của tôi")
        // The other phone's price is lost, as the spec accepts.
        assertThat(server(seeded)!!.price).isNull()
    }

    @Test
    fun postingDeletesTheDraftFromBoth() = runTest {
        ready()
        sell.post(opened().copy(price = Vnd(4_500_000))).getOrThrow()
        assertThat(phone(seeded)).isNull()
        assertThat(server(seeded)).isNull()
    }

    /** The post goes; its delete cannot reach the server, so the draft stays until the person deletes it. */
    @Test
    fun aPostWhileOfflineKeepsTheDraft() = runTest {
        ready()
        offline(true)
        val listing = sell.post(opened().copy(price = Vnd(4_500_000))).getOrThrow()
        assertThat(world.value.own).containsKey(listing)
        assertThat(phone(seeded)).isNotNull()
        assertThat(server(seeded)).isNotNull()
    }

    /** Review Focus 1. */
    @Test
    fun deletingOfflineRefusesASyncedDraftAndDropsALocalOne() = runTest {
        offline(true)
        assertThat(mine.deleteDraft(seeded).isFailure).isTrue()
        assertThat(phone(seeded)).isNotNull()
        assertThat(server(seeded)).isNotNull()
        sell.saveDraft(blank()).getOrThrow()
        mine.deleteDraft(new).getOrThrow()
        assertThat(phone(new)).isNull()
        offline(false)
        assertThat(phone(new)).isNull()
        assertThat(server(new)).isNull()
        assertThat(phone(seeded)).isNotNull()
    }

    /** The server deletes a draft past its end when it is next asked; the phone's synced copy then goes. */
    @Test
    fun anExpiredDraftGoesAtTheNextPull() {
        val end = opened().expiresAt!!
        world.update { it.pulled(end.minusSeconds(1)) }
        assertThat(phone(seeded)).isNotNull()
        world.update { it.pulled(end) }
        assertThat(server(seeded)).isNull()
        assertThat(phone(seeded)).isNull()
    }

    /** Edits the server never got outlive the end on the phone and go out again, with a new end. */
    @Test
    fun anUnsyncedDraftPastItsEndIsPutAgain() = runTest {
        val end = opened().expiresAt!!
        offline(true)
        sellAt(end).saveDraft(opened().copy(title = "Sửa")).getOrThrow()
        world.update { it.copy(draftsOffline = false).pulled(end) }
        assertThat(server(seeded)!!.title).isEqualTo("Sửa")
        assertThat(server(seeded)!!.expiresAt).isEqualTo(end.plus(DRAFT_KEEP))
        assertThat(phone(seeded)!!.synced).isTrue()
    }

    /** "Tua tới sắp hết hạn" moves the server's end 3 days out; the card has it after the next pull. */
    @Test
    fun nearExpiryBringsTheEndThreeDaysOut() = runTest {
        world.update { it.nearExpiry(now) }
        assertThat(server(seeded)!!.expiresAt).isEqualTo(now.plus(DRAFT_WARNING))
        assertThat(mine.listings().first().drafts.single().expiresAt).isEqualTo(now.plus(DRAFT_WARNING))
    }

    @Test
    fun theNewestDraftReadsTheMergedList() = runTest {
        world.update { it.withOtherPhoneDrafts(1, now) }
        val other = world.value.serverDrafts.keys.single { it != seeded }
        assertThat(phone(other)).isNull()
        assertThat(sell.newestDraft().first()!!.id).isEqualTo(other)
        assertThat(mine.listings().first().drafts.map { it.id }).containsExactly(other, seeded).inOrder()
    }

    @Test
    fun theCardCarriesWhetherTheAccountHasItAndItsEnd() = runTest {
        world.update { it.withOtherPhoneDrafts(19, now) }
        sell.saveDraft(blank()).getOrThrow()
        val cards = mine.listings().first().drafts.associateBy { it.id }
        assertThat(cards.getValue(new).synced).isFalse()
        assertThat(cards.getValue(new).expiresAt).isNull()
        assertThat(cards.getValue(seeded).synced).isTrue()
        assertThat(cards.getValue(seeded).expiresAt).isEqualTo(opened().expiresAt)
    }
}
```

In `FakeSellRepositoryTest`: `savingADraftStampsAndKeepsIt`'s first assertion becomes `assertThat(sell.saveDraft(draft).getOrThrow()).isEqualTo(DraftSave.SYNCED)` (import `vn.shopnexus.core.data.DraftSave`), and `postingMakesALiveListingAndDropsTheDraft` gains, after `assertThat(world.value.drafts).doesNotContainKey(seeded.id)`:

```kotlin
        assertThat(world.value.serverDrafts).doesNotContainKey(seeded.id)
```

In `FakeSettingsRepositoryTest.deletingTheAccountSignsOutAndKeepsNothing`, add:

```kotlin
        assertThat(world.value.drafts).isEmpty()
        assertThat(world.value.serverDrafts).isEmpty()
```

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :core:data:testDebugUnitTest --tests '*DraftSyncTest*'`
Expected: compilation fails (`DraftSave`, `serverDrafts`, `pulled`, `withOtherPhoneDrafts` undefined).

- [ ] **Step 2: The two stores**

`FakeWorld.kt`, `WorldState`: replace the line `val drafts: Map<DraftId, ListingDraft> = emptyMap(),` with

```kotlin
    /** This phone's drafts, its own and the ones it read from the account: what Tin của bạn, Home and Sell read. */
    val drafts: Map<DraftId, ListingDraft> = emptyMap(),
    /** The account's drafts on the server, by id; each is synced and carries its end. */
    val serverDrafts: Map<DraftId, ListingDraft> = emptyMap(),
    /** "Mất mạng" on the debug panel: the drafts' calls cannot reach the server. */
    val draftsOffline: Boolean = false,
```

`initial()`: after `val mine = Fixtures.myListings()` add

```kotlin
            // The seeded draft reached the account once: synced on this phone and on the server.
            val seededDrafts = mine.drafts.map { d -> d.copy(synced = true, expiresAt = checkNotNull(d.updatedAt).plus(DRAFT_KEEP)) }
```

and replace `drafts = mine.drafts.associateBy { it.id },` with

```kotlin
                drafts = seededDrafts.associateBy { it.id },
                serverDrafts = seededDrafts.associateBy { it.id },
```

Import `vn.shopnexus.core.domain.DRAFT_KEEP`.

- [ ] **Step 3: The server and the phone**

Create `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/DraftServer.kt`:

```kotlin
package vn.shopnexus.core.data.fake

import java.time.Instant
import vn.shopnexus.core.data.DraftSave
import vn.shopnexus.core.domain.DRAFT_KEEP
import vn.shopnexus.core.domain.DRAFT_LIMIT
import vn.shopnexus.core.domain.DRAFT_WARNING
import vn.shopnexus.core.model.DraftId
import vn.shopnexus.core.model.DraftOrigin
import vn.shopnexus.core.model.ListingDraft
import vn.shopnexus.core.model.Vnd

/** The price the other phone gives a draft without one, and what it takes off on each edit. */
private val OTHER_PHONE_PRICE = Vnd(4_500_000)
private val OTHER_PHONE_CUT = Vnd(100_000)

/** The server deletes the drafts past their end first, as its `GET` and `PUT` do. */
private fun WorldState.serverExpired(now: Instant): WorldState =
    copy(serverDrafts = serverDrafts.filterValues { now < checkNotNull(it.expiresAt) { "A server draft has its end" } })

/**
 * `PUT /v1/listing-drafts/{id}`, last write wins: a create when the account holds 20 drafts is `draft_limit_reached`
 * (false); otherwise the row is written, edited [now] and deleted 30 days on (true).
 */
internal fun WorldState.serverPut(draft: ListingDraft, now: Instant): Pair<WorldState, Boolean> {
    val s = serverExpired(now)
    if (draft.id !in s.serverDrafts && s.serverDrafts.size >= DRAFT_LIMIT) return s to false
    val row = draft.copy(updatedAt = now, expiresAt = now.plus(DRAFT_KEEP), synced = true)
    return s.copy(serverDrafts = s.serverDrafts + (draft.id to row)) to true
}

/** Writes [draft] on this phone at once, unsynced, edited [now]. */
internal fun WorldState.savedLocally(draft: ListingDraft, now: Instant): WorldState =
    copy(drafts = drafts + (draft.id to draft.copy(updatedAt = now, synced = false)))

/**
 * Puts this phone's draft [id] to the server: accepted, the phone takes the server's row; refused for the limit, it
 * stays here unsynced; while the drafts cannot reach the server, it waits.
 */
internal fun WorldState.put(id: DraftId, now: Instant): Pair<WorldState, DraftSave> {
    val local = drafts[id]
    if (local == null || local.synced) return this to DraftSave.SYNCED
    if (draftsOffline) return this to DraftSave.WAITING
    val (after, accepted) = serverPut(local, now)
    if (!accepted) return after to DraftSave.LIMIT
    return after.copy(drafts = after.drafts + (id to after.serverDrafts.getValue(id))) to DraftSave.SYNCED
}

/** Puts every draft the server lacks, oldest first: after a save, a pull, a delete, and when the network is back. */
internal fun WorldState.putWaiting(now: Instant): WorldState =
    drafts.values.filterNot { it.synced }.sortedBy { it.updatedAt ?: Instant.MIN }.fold(this) { s, d -> s.put(d.id, now).first }

/**
 * The phone reads the account's drafts, after the server's expiry at [now]: a draft the server has replaces the
 * phone's synced copy or arrives; a synced draft the server lacks was deleted elsewhere, or ran out, and leaves; an
 * unsynced one is put again. Nothing happens while the drafts cannot reach the server.
 */
internal fun WorldState.pulled(now: Instant): WorldState {
    if (draftsOffline) return this
    val s = serverExpired(now)
    val kept = s.drafts.filterValues { !it.synced || it.id in s.serverDrafts }
    val merged = kept + s.serverDrafts.filterKeys { kept[it]?.synced != false }
    return s.copy(drafts = merged).putWaiting(now)
}

/**
 * `DELETE /v1/listing-drafts/{id}` and this phone's copy, then the puts that waited (a slot may have freed). Null while
 * the drafts cannot reach the server and the server may hold it ([ListingDraft.expiresAt] set): a delete here alone
 * would come back at the next pull.
 */
internal fun WorldState.draftDeleted(id: DraftId, now: Instant): WorldState? {
    if (draftsOffline) return if (drafts[id]?.expiresAt != null) null else copy(drafts = drafts - id)
    return copy(drafts = drafts - id, serverDrafts = serverExpired(now).serverDrafts - id).putWaiting(now)
}

/** The draft the other phone acts on: the one edited last on the server. */
private fun WorldState.othersDraft(): ListingDraft? = serverDrafts.values.maxByOrNull { it.updatedAt ?: Instant.MIN }

/** "Máy khác sửa nháp": the other phone takes 100.000 ₫ off the price, or sets 4.500.000 ₫, and saves it. */
internal fun WorldState.otherPhoneEdited(now: Instant): WorldState {
    val d = othersDraft() ?: return this
    val price = d.price?.let { maxOf(it - OTHER_PHONE_CUT, OTHER_PHONE_CUT) } ?: OTHER_PHONE_PRICE
    return serverPut(d.copy(price = price), now).first
}

/** "Máy khác xóa nháp": the other phone deletes it. */
internal fun WorldState.otherPhoneDeleted(now: Instant): WorldState {
    val d = othersDraft() ?: return this
    return serverExpired(now).let { it.copy(serverDrafts = it.serverDrafts - d.id) }
}

/** "Tua tới sắp hết hạn": that draft was last edited 27 days ago, so the server deletes it in 3 days. */
internal fun WorldState.nearExpiry(now: Instant): WorldState {
    val d = othersDraft() ?: return this
    val aged = d.copy(updatedAt = now.minus(DRAFT_KEEP).plus(DRAFT_WARNING), expiresAt = now.plus(DRAFT_WARNING))
    return copy(serverDrafts = serverDrafts + (d.id to aged))
}

/** [count] drafts the other phone saved to the account at [now], which this phone reads at its next pull: for the limit in tests. */
fun WorldState.withOtherPhoneDrafts(count: Int, now: Instant): WorldState {
    val rows = (0 until count).associate { i ->
        val id = DraftId("dr-other-${serial + i}")
        id to ListingDraft(id, DraftOrigin.PHOTOS, title = "Nháp máy khác ${i + 1}", updatedAt = now, synced = true, expiresAt = now.plus(DRAFT_KEEP))
    }
    return copy(serverDrafts = serverDrafts + rows, serial = serial + count)
}
```

- [ ] **Step 4: The repositories**

`Repositories.kt`, before `interface SellRepository`:

```kotlin
/** How a draft's save ended: on the account, waiting for the network on this phone, or kept here at the 20-draft limit. */
enum class DraftSave { SYNCED, WAITING, LIMIT }
```

and in `SellRepository` replace `suspend fun saveDraft(draft: ListingDraft): Result<DraftId>` with

```kotlin
    /**
     * Keeps [draft] on this phone at once and puts it to the account. [DraftSave.LIMIT]: the account already holds 20
     * drafts, so this one stays on the phone, unsynced.
     */
    suspend fun saveDraft(draft: ListingDraft): Result<DraftSave>
```

`FakeSellRepository`:

```kotlin
    // Home's "Tiếp tục nháp" reads the merged list, so it pulls the account's drafts first.
    override fun newestDraft(): Flow<ListingDraft?> = world.watch(failures) { s -> s.drafts.values.maxByOrNull { it.updatedAt ?: Instant.MIN } }
        .onStart { world.update { it.pulled(clock.instant()) } }
```

```kotlin
    override suspend fun saveDraft(draft: ListingDraft): Result<DraftSave> = failures.run {
        require(draft.editing == null) { "An edit is saved to its listing" }
        val now = clock.instant()
        // The phone first, so the form never waits on the server; then the put, and the others that waited.
        world.update { it.savedLocally(draft, now) }
        world.modify { s -> s.put(draft.id, now).let { (after, save) -> after.putWaiting(now) to save } }
    }
```

and in `post`, the `world.modify` block's last line `s.copy(own = mapOf(id to own) + s.own, drafts = s.drafts - draft.id, serial = s.serial + 1) to id` becomes

```kotlin
                // The listing is posted; then the draft's delete, which keeps it where it cannot reach the server.
                s.copy(own = mapOf(id to own) + s.own, serial = s.serial + 1).let { it.draftDeleted(draft.id, now) ?: it } to id
```

with `val now = clock.instant()` declared before `val listing = …` and `listing` built with `now` in place of `clock.instant()`. Imports: `kotlinx.coroutines.flow.onStart`, `vn.shopnexus.core.data.DraftSave`.

`FakeMyListingsRepository`:

```kotlin
    // Ages and boosts run out with time, so the panes follow the minute as well as the world. Reading the list pulls
    // the account's drafts first, so opening Tin của bạn and a pull to refresh both bring the other phone's changes.
    override fun listings(): Flow<MyListings> = combine(
        world.watch(failures) { it }.onStart { world.update { it.pulled(clock.instant()) } },
        clock.minutes(),
    ) { s, now -> s.panes(now) }.distinctUntilChanged()
```

the `DraftCard(…)` in `panes` gains `synced = d.synced, expiresAt = d.expiresAt` after `needsVerification = …`, and

```kotlin
    override suspend fun deleteDraft(id: DraftId): Result<Unit> = failures.run {
        world.update { s -> s.draftDeleted(id, clock.instant()) ?: throw FakeNetworkException() }
    }
```

(import `kotlinx.coroutines.flow.onStart`). `world.update` retries its lambda on a race, which is safe here: the lambda throws before writing.

`FakeSettingsRepository.deleteAccount`: the copy gains `serverDrafts = emptyMap()` (erasure deletes the account's drafts).

Run: `./gradlew :core:data:testDebugUnitTest` (in the background; wait for the notice).
Expected: PASS, old and new.

- [ ] **Step 5: Write the failing control, panel and Home tests**

`DebugControlsTest`, add (imports `vn.shopnexus.core.model.DraftId`, `vn.shopnexus.core.model.Vnd` if not there):

```kotlin
    /** The draft rows: the other phone changes the server, Mất mạng holds this phone, and turning it off pulls. */
    @Test
    fun theDraftControlsPlayTheOtherPhoneAndTheNetwork() = runTest {
        val world = FakeWorld()
        val clock = SchedulerClock(testScheduler)
        val controls = DebugControls(world, Simulator(world, clock, backgroundScope, VN_ZONE, Pace()), FailurePolicy(), clock, VN_ZONE)
        val seeded = DraftId("dr-iphone11")
        controls.offline = true
        assertThat(controls.offline).isTrue()
        controls.otherPhoneEdits()
        assertThat(world.value.serverDrafts.getValue(seeded).price).isEqualTo(Vnd(4_500_000))
        assertThat(world.value.drafts.getValue(seeded).price).isNull()
        controls.offline = false
        assertThat(world.value.drafts.getValue(seeded).price).isEqualTo(Vnd(4_500_000))
        controls.nearExpiry()
        assertThat(world.value.serverDrafts.getValue(seeded).expiresAt).isEqualTo(Fixtures.NOW.plus(DRAFT_WARNING))
        controls.otherPhoneDeletes()
        assertThat(world.value.serverDrafts).isEmpty()
        controls.otherPhoneDeletes() // nothing left: nothing happens
        controls.reset()
        assertThat(controls.offline).isFalse()
        assertThat(world.value.drafts).containsKey(seeded)
    }
```

(import `vn.shopnexus.core.domain.DRAFT_WARNING`).

`HomeViewModelTest`, add (import `vn.shopnexus.core.data.fake.withOtherPhoneDrafts`):

```kotlin
    /** A draft saved on the other phone is the one to continue: Home pulls before it reads the newest draft. */
    @Test
    fun aDraftFromTheOtherPhoneIsTheOneToContinue() = runTest {
        world.update { it.withOtherPhoneDrafts(1, Instant.parse("2026-10-15T09:00:00Z")) }
        val vm = viewModel()
        backgroundScope.launch { vm.state.collect {} }
        advanceUntilIdle()
        val other = world.value.drafts.keys.single { it != DraftId("dr-iphone11") }
        assertThat(vm.state.value.draft).isEqualTo(SellRoute(draftId = other.value))
    }
```

`DebugPanelTest`, add (import `vn.shopnexus.core.model.DraftId`, `vn.shopnexus.core.model.Vnd`):

```kotlin
    /** "Mất mạng" is a switch; "Máy khác sửa nháp" changes the server's copy while this phone keeps its own. */
    @Test
    fun theDraftRowsHoldTheSyncAndPlayTheOtherPhone() {
        compose.setContent { ShopNexusTheme { DebugHost { Box { Text("Tuấn Kiệt", Modifier.debugTrigger()) } } } }
        compose.onNodeWithText("Tuấn Kiệt").performTouchInput { longClick() }
        compose.onNodeWithText("Mất mạng").performScrollTo().performClick()
        assertThat(controls.offline).isTrue()
        compose.onNodeWithText("Máy khác sửa nháp").performScrollTo().performClick()
        val seeded = DraftId("dr-iphone11")
        assertThat(world.value.serverDrafts.getValue(seeded).price).isEqualTo(Vnd(4_500_000))
        assertThat(world.value.drafts.getValue(seeded).price).isNull()
    }
```

Run: `./gradlew :core:data:testDebugUnitTest --tests '*DebugControlsTest*'`. Expected: compilation fails (`offline`, `otherPhoneEdits` undefined).

- [ ] **Step 6: The controls and the panel**

`DebugControls`, after `slow`:

```kotlin
    /**
     * "Mất mạng": the drafts' calls cannot reach the server, so saves stay unsynced and nothing is pulled. Off, the
     * phone pulls and puts what waited. Posting, reads and other commands are not held; "Lỗi mạng giả" covers those.
     */
    var offline: Boolean
        get() = world.value.draftsOffline
        set(on) {
            world.update { it.copy(draftsOffline = on).pulled(clock.instant()) }
        }

    /** "Máy khác sửa nháp": the other phone edits the draft edited last on the server; this phone takes it at its next pull. */
    fun otherPhoneEdits() = world.update { it.otherPhoneEdited(clock.instant()) }

    /** "Máy khác xóa nháp": the other phone deletes that draft. */
    fun otherPhoneDeletes() = world.update { it.otherPhoneDeleted(clock.instant()) }

    /** "Tua tới sắp hết hạn": that draft is 3 days from its end. */
    fun nearExpiry() = world.update { it.nearExpiry(clock.instant()) }
```

`app/src/debug/res/values/strings.xml` gains:

```xml
    <string name="debug_drafts">Nháp tin đăng</string>
    <string name="debug_other_edits">Máy khác sửa nháp</string>
    <string name="debug_other_deletes">Máy khác xóa nháp</string>
    <string name="debug_offline">Mất mạng</string>
    <string name="debug_near_expiry">Tua tới sắp hết hạn</string>
```

`DebugHost.DebugPanel`: beside the other remembered switches, `var offline by remember { mutableStateOf(controls.offline) }`. In the `GroupedList`, after the `slow` row:

```kotlin
                row("offline") {
                    GroupRow(stringResource(R.string.debug_offline), trailing = { Switch(offline, null) }, onClick = {
                        offline = !offline
                        controls.offline = offline
                    })
                }
```

After the "Lần đọc tới" chips and before the theme title:

```kotlin
            Text(stringResource(R.string.debug_drafts), style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(top = 16.dp))
            // Each acts on the draft edited last on the server and closes the panel, as the jumps do.
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(
                    R.string.debug_other_edits to controls::otherPhoneEdits,
                    R.string.debug_other_deletes to controls::otherPhoneDeletes,
                    R.string.debug_near_expiry to controls::nearExpiry,
                ).forEach { (label, act) ->
                    AssistChip(onClick = {
                        act()
                        onDismiss()
                    }, label = { Text(stringResource(label)) })
                }
            }
```

Run: `python3 tmp/unused_strings.py app/src/debug/res/values/strings.xml`; expected: no output. Run, in the background: `./gradlew :core:data:testDebugUnitTest :feature:discover:testDebugUnitTest --tests '*HomeViewModelTest*' :app:testDebugUnitTest --tests '*DebugPanelTest*'`. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
./gradlew :core:data:spotlessApply :app:spotlessApply :feature:discover:spotlessApply
git add core/data app feature/discover
```

`tmp/msg.txt`: `feat(data): drafts on the phone and on a fake server, last write wins, with the limit, the 30-day end and the debug rows`. Check, commit, stop the daemons.

### Task 3: Tin của bạn's draft labels

**Files:**
- Modify: `feature/listings/src/main/kotlin/vn/shopnexus/feature/listings/mine/MyListingsViewModel.kt` (`ListingsContent.Ready`, constructor, `content`), `MyListingsScreen.kt` (`PageLoad` content, `Panes`, `DraftListing`), `feature/listings/src/main/res/values/strings.xml`
- Test: `feature/listings/src/test/kotlin/vn/shopnexus/feature/listings/mine/MyListingsViewModelTest.kt`, `MyListingsScreenTest.kt`

**Interfaces:**
- Consumes: Task 1's `DraftLabel`, `draftLabels`, `DRAFT_WARNING`; Task 2's `withOtherPhoneDrafts`, `DraftCard.synced/expiresAt`, `WorldState.draftsOffline`.
- Produces: `ListingsContent.Ready(listings, labels: Map<DraftId, List<DraftLabel>> = emptyMap())`; `MyListingsViewModel(route, mine, clock, saved)`.

- [ ] **Step 1: Write the failing tests**

`MyListingsViewModelTest`: the builder passes its clock, `MyListingsViewModel(route, mine, clock, handle)`. Add (imports: `java.time.Duration`, `vn.shopnexus.core.data.fake.FakeSellRepository`, `vn.shopnexus.core.data.fake.Fixtures`, `vn.shopnexus.core.data.fake.Pace`, `vn.shopnexus.core.data.fake.withOtherPhoneDrafts`, `vn.shopnexus.core.domain.DRAFT_WARNING`, `vn.shopnexus.core.domain.DraftLabel`, `vn.shopnexus.core.model.DraftOrigin`, `vn.shopnexus.core.model.ListingDraft`):

```kotlin
    private val seeded = DraftId("dr-iphone11")

    private fun labels(vm: MyListingsViewModel, id: DraftId = seeded) = (vm.state.value.content as ListingsContent.Ready).labels.getValue(id)

    /** Mất mạng on, so the pull Tin của bạn makes leaves the phone's copy as the test set it. */
    private fun changeSeeded(change: (ListingDraft) -> ListingDraft) =
        world.update { s -> s.copy(draftsOffline = true, drafts = s.drafts + (seeded to change(s.drafts.getValue(seeded)))) }

    @Test
    fun aDraftCardSaysUnsyncedAndTheDaysLeft() = runTest {
        val vm = viewModel()
        assertThat(labels(vm)).isEmpty()
        changeSeeded { it.copy(synced = false, expiresAt = Fixtures.NOW.plus(Duration.ofHours(30))) }
        runCurrent()
        assertThat(labels(vm)).containsExactly(DraftLabel.Unsynced, DraftLabel.DaysLeft(2)).inOrder()
    }

    /** "Còn 3 ngày" comes as the minute passes the 3-day mark, with nothing else on the card changing. */
    @Test
    fun theDaysLeftStartThreeDaysOutAsTheClockMoves() = runTest {
        changeSeeded { it.copy(expiresAt = Fixtures.NOW.plus(DRAFT_WARNING).plusSeconds(30)) }
        val vm = viewModel()
        assertThat(labels(vm)).isEmpty()
        advanceTimeBy(60_000)
        runCurrent()
        assertThat(labels(vm)).containsExactly(DraftLabel.DaysLeft(3))
    }

    /** Review Focus 3: deleting a draft at the limit sends the held one, and its "Chưa đồng bộ" goes on the open screen. */
    @Test
    fun theUnsyncedLabelGoesOnceADeleteFreesASlot() = runTest {
        world.update { it.withOtherPhoneDrafts(19, Fixtures.NOW) }
        val sell = FakeSellRepository(world, failures, SchedulerClock(testScheduler), CounterpartListener { _, _ -> }, Pace())
        val held = DraftId("dr-new")
        sell.saveDraft(ListingDraft(held, DraftOrigin.PHOTOS, title = "Bàn gỗ")).getOrThrow()
        val vm = viewModel()
        assertThat(labels(vm, held)).containsExactly(DraftLabel.Unsynced)
        vm.onEvent(MyListingsEvent.AskDelete(DeleteTarget.Draft(seeded)))
        vm.onEvent(MyListingsEvent.ConfirmDelete)
        runCurrent()
        assertThat(labels(vm, held)).isEmpty()
    }
```

`MyListingsScreenTest`, add (import `vn.shopnexus.core.domain.DraftLabel`):

```kotlin
    /** A card's labels share one line, in order, under the photo count and the price. */
    @Test
    fun aDraftCardSaysItsLabelsOnOneLine() {
        val labels = mapOf(DraftId("dr-iphone11") to listOf(DraftLabel.Unsynced, DraftLabel.DaysLeft(2)))
        show(MyListingsUiState(ListingsContent.Ready(listings(), labels), ListingPane.DRAFT))
        compose.onNodeWithText("Chưa đồng bộ · Còn 2 ngày").assertExists()
    }

    @Test
    fun aSyncedDraftCardSaysNoLabel() {
        show(state(ListingPane.DRAFT))
        compose.onNodeWithText("Chưa đồng bộ", substring = true).assertDoesNotExist()
        compose.onNodeWithText("Còn ", substring = true).assertDoesNotExist()
    }
```

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :feature:listings:testDebugUnitTest`
Expected: compilation fails (`labels`, the constructor's `clock`).

- [ ] **Step 2: The view model**

`ListingsContent`:

```kotlin
sealed interface ListingsContent {
    data object Loading : ListingsContent
    data object Failed : ListingsContent

    /** The panes, and what each draft card says beside its photos and price ([draftLabels]). */
    data class Ready(val listings: MyListings, val labels: Map<DraftId, List<DraftLabel>> = emptyMap()) : ListingsContent
}
```

Constructor: `class MyListingsViewModel @AssistedInject constructor(@Assisted route: MyListingsRoute, private val mine: MyListingsRepository, private val clock: Clock, private val saved: SavedStateHandle)`.

`content`: the read becomes

```kotlin
        // The minute moves a draft's "Còn n ngày" on, as the repository's minute moves the listings' ages.
        combine<MyListings, Instant, ListingsContent>(mine.listings(), clock.minutes()) { listings, now -> readyOf(listings, now) }
            .onStart { if (kept == null) emit(ListingsContent.Loading) }
```

and the failed pull's `emit(ListingsContent.Ready(kept))` becomes `emit(readyOf(kept, clock.instant()))`. Add:

```kotlin
    /** The panes as of [now], with what each draft card says. */
    private fun readyOf(listings: MyListings, now: Instant) =
        ListingsContent.Ready(listings, listings.drafts.associate { it.id to draftLabels(it, now) })
```

Imports: `java.time.Clock`, `java.time.Instant`, `vn.shopnexus.core.data.minutes`, `vn.shopnexus.core.domain.DraftLabel`, `vn.shopnexus.core.domain.draftLabels`; drop the `map` import if nothing else uses it.

- [ ] **Step 3: The card**

`strings.xml` gains:

```xml
    <string name="listings_draft_unsynced">Chưa đồng bộ</string>
    <string name="listings_draft_days_left">Còn %1$d ngày</string>
```

`MyListingsScreen`: the Ready branch calls `Panes(content.listings, content.labels, state.pane, onEvent, onNavigate)`; `Panes` takes `labels: Map<DraftId, List<DraftLabel>>` after `listings`, and the draft pane's items become `items(listings.drafts, key = { it.id.value }) { DraftListing(it, labels[it.id].orEmpty(), onEvent, onNavigate, settling(animate)) }`. `DraftListing`:

```kotlin
@Composable
private fun DraftListing(
    card: DraftCard,
    labels: List<DraftLabel>,
    onEvent: (MyListingsEvent) -> Unit,
    onNavigate: (NavKey) -> Unit,
    modifier: Modifier = Modifier,
) {
    val open = { onNavigate(if (card.origin == DraftOrigin.VIDEO) SellReviewRoute(draftId = card.id.value) else SellRoute(draftId = card.id.value)) }
    val menu = listOf(
        stringResource(R.string.listings_menu_edit) to open,
        stringResource(R.string.listings_menu_delete_draft) to { onEvent(MyListingsEvent.AskDelete(DeleteTarget.Draft(card.id))) },
    )
    Card(card.photoUrl, card.title.ifBlank { stringResource(R.string.listings_no_title) }, onOpen = open, menu = menu, modifier = modifier) {
        Line(Symbol.PhotoLibrary, stringResource(R.string.listings_draft_line, card.photos, card.price?.full() ?: stringResource(R.string.listings_no_price)))
        // Both labels on one line, in draftLabels' order, under the first one's icon.
        if (labels.isNotEmpty()) Line(labels.first().icon(), labels.map { it.text() }.joinToString(" · "))
        if (card.needsVerification) Line(Symbol.VerifiedUser, stringResource(R.string.listings_needs_verification))
        FilledTonalButton(onClick = open, modifier = Modifier.padding(top = 8.dp).heightIn(min = 40.dp)) { Text(stringResource(R.string.listings_continue)) }
    }
}

private fun DraftLabel.icon(): Symbol = when (this) {
    DraftLabel.Unsynced -> Symbol.CloudOff
    is DraftLabel.DaysLeft -> Symbol.Schedule
}

@Composable
private fun DraftLabel.text(): String = when (this) {
    DraftLabel.Unsynced -> stringResource(R.string.listings_draft_unsynced)
    is DraftLabel.DaysLeft -> stringResource(R.string.listings_draft_days_left, days)
}
```

(the old `val c = MaterialTheme.colorScheme` in `DraftListing` goes if nothing reads it; imports `vn.shopnexus.core.domain.DraftLabel`, `vn.shopnexus.core.model.DraftId`). Tôi's draft row (`feature/me`) is not touched.

- [ ] **Step 4: Run the module's tests**

Run: `./gradlew :feature:listings:testDebugUnitTest` (in the background). Expected: PASS, old and new. Run `python3 tmp/unused_strings.py feature/listings/src/main/res/values/strings.xml`; expected: no output.

- [ ] **Step 5: Commit**

```bash
./gradlew :feature:listings:spotlessApply
git add feature/listings
```

`tmp/msg.txt`: `feat(listings): a draft card says when the account lacks it and how many days it has left`. Check, commit, stop the daemons.

### Task 4: Sell says the limit, README and the gate

**Files:**
- Modify: `feature/sell/src/main/kotlin/vn/shopnexus/feature/sell/form/Autosave.kt`, `form/SellViewModel.kt` (`SellEffect`, `normal`, `load`, `onEvent`, `saveDraft`, `close`, `closeKept`, `scheduleAutosave`), `form/SellScreen.kt:201`, `review/ReviewViewModel.kt` (`onEvent`, `confirm`, `exit`, `leave`, `saveDraft`, `scheduleAutosave`, `draftOf`), `review/ReviewScreen.kt:187`, `feature/sell/src/main/res/values/strings.xml`, `README.md`
- Test: `feature/sell/src/test/kotlin/vn/shopnexus/feature/sell/form/SellViewModelTest.kt`, `review/ReviewViewModelTest.kt`

**Interfaces:**
- Consumes: Task 2's `DraftSave`, `saveDraft(): Result<DraftSave>`, `withOtherPhoneDrafts`, `WorldState.draftsOffline`.
- Produces: `SellEffect.KeptOnPhone`; `Autosave.schedule(keeps, current, onSaved: (sent, save) -> Unit)`; `normal()` without `synced` and `expiresAt`.

- [ ] **Step 1: Write the failing tests**

`SellViewModelTest`, add (imports: `vn.shopnexus.core.data.fake.Fixtures`, `vn.shopnexus.core.data.fake.withOtherPhoneDrafts`):

```kotlin
    /** At the account's 20 drafts, "Lưu nháp" keeps the draft on the phone and says so instead of "Đã lưu nháp". */
    @Test
    fun savingAtTheLimitKeepsTheDraftOnThePhoneAndSaysSo() = runTest {
        world.update { it.withOtherPhoneDrafts(19, Fixtures.NOW) }
        val vm = viewModel()
        filled(vm)
        vm.onEvent(SellEvent.SaveDraft)
        runCurrent()
        val id = vm.state.value.draft.id
        assertThat(world.value.drafts.getValue(id).synced).isFalse()
        assertThat(world.value.serverDrafts).doesNotContainKey(id)
        val said = effects.filterIsInstance<SellEffect.Message>().last().message
        assertThat(said.text).isEqualTo(R.string.sell_draft_limit)
        assertThat(said.action).isEqualTo(R.string.sell_view)
        assertThat(messages()).doesNotContain(R.string.sell_saved)
    }

    /** An autosave at the limit says so once a visit; the next one keeps quiet. */
    @Test
    fun anAutosaveAtTheLimitSaysSoOnce() = runTest {
        world.update { it.withOtherPhoneDrafts(19, Fixtures.NOW) }
        val vm = viewModel()
        filled(vm)
        advanceTimeBy(AUTOSAVE_MILLIS + 1)
        runCurrent()
        assertThat(messages().count { it == R.string.sell_draft_limit }).isEqualTo(1)
        vm.onEvent(SellEvent.Edit(FormEdit.Title("iPhone 11 trắng")))
        advanceTimeBy(AUTOSAVE_MILLIS + 1)
        runCurrent()
        assertThat(world.value.drafts.getValue(vm.state.value.draft.id).title).isEqualTo("iPhone 11 trắng")
        assertThat(messages().count { it == R.string.sell_draft_limit }).isEqualTo(1)
    }

    @Test
    fun closingWithASaveAtTheLimitSaysSoOverTheNextScreen() = runTest {
        world.update { it.withOtherPhoneDrafts(19, Fixtures.NOW) }
        val vm = viewModel()
        filled(vm)
        vm.onEvent(SellEvent.Close)
        vm.onEvent(SellEvent.ConfirmClose(save = true))
        runCurrent()
        assertThat(effects.takeLast(2)).containsExactly(SellEffect.KeptOnPhone, SellEffect.Close).inOrder()
    }

    /** Review Focus 4: offline, the server was not asked, so the save is "Đã lưu nháp" whatever the account holds. */
    @Test
    fun anOfflineSaveSaysNothingAboutTheLimit() = runTest {
        world.update { it.withOtherPhoneDrafts(19, Fixtures.NOW).copy(draftsOffline = true) }
        val vm = viewModel()
        filled(vm)
        vm.onEvent(SellEvent.SaveDraft)
        runCurrent()
        assertThat(messages().last()).isEqualTo(R.string.sell_saved)
        assertThat(messages()).doesNotContain(R.string.sell_draft_limit)
        assertThat(world.value.drafts.getValue(vm.state.value.draft.id).synced).isFalse()
    }

    /** Review Focus 5: a draft gone from the phone (deleted on the other phone and pulled, posted, past its end) closes Đăng tin. */
    @Test
    fun aGoneDraftCloses() = runTest {
        viewModel(SellRoute(draftId = "dr-gone"))
        runCurrent()
        assertThat(effects.last()).isEqualTo(SellEffect.Close)
    }
```

`ReviewViewModelTest`, add (imports: `vn.shopnexus.core.data.fake.Fixtures` if missing, `vn.shopnexus.core.data.fake.withOtherPhoneDrafts`, `vn.shopnexus.feature.sell.R` if missing):

```kotlin
    @Test
    fun savingAtTheLimitSaysSo() = runTest {
        world.update { it.withOtherPhoneDrafts(19, Fixtures.NOW) }
        val vm = viewModel()
        read()
        vm.onEvent(ReviewEvent.SaveDraft)
        runCurrent()
        assertThat(world.value.drafts.getValue(vm.state.value.draft.id).synced).isFalse()
        assertThat(effects.filterIsInstance<SellEffect.Message>().last().message.text).isEqualTo(R.string.sell_draft_limit)
    }

    /** The frames come from the server's read with their uploads, so the draft's photos name what the server holds. */
    @Test
    fun aReadVideoDraftsPhotosCarryTheirUploads() = runTest {
        val vm = viewModel()
        read()
        val d = vm.state.value.draft
        assertThat(d.photos.map { it.uploadId }).doesNotContain(null)
        assertThat(d.video!!.frames.map { it.uploadId }).doesNotContain(null)
    }
```

Run: `. ~/.local/share/shopnexus/android-env.sh && ./gradlew :feature:sell:testDebugUnitTest`
Expected: compilation fails (`sell_draft_limit`, `SellEffect.KeptOnPhone`).

- [ ] **Step 2: The save's answer reaches the forms**

`SellViewModel.kt`, `normal()`:

```kotlin
/** What the seller wrote: without when it was saved, whether the account has it, or its end. */
internal fun ListingDraft.normal() = copy(updatedAt = null, synced = false, expiresAt = null)
```

`Autosave.schedule`:

```kotlin
    /**
     * Starts the wait again. When [keeps], [current] is saved once it ends, unless it gives null by then (a save of
     * the seller's own is running), and [onSaved] hears the draft sent and how its save ended.
     */
    fun schedule(keeps: Boolean, current: () -> ListingDraft?, onSaved: (sent: ListingDraft, save: DraftSave) -> Unit) {
        job?.cancel()
        job = null
        if (!keeps) return
        job = scope.launch {
            delay(AUTOSAVE_MILLIS)
            val draft = current() ?: return@launch
            sell.saveDraft(draft).onSuccess { save -> onSaved(draft, save) }
        }
    }
```

(import `vn.shopnexus.core.data.DraftSave`). `RestoreKept` keeps `.map { }`.

- [ ] **Step 3: Đăng tin**

`strings.xml` gains `<string name="sell_draft_limit">Bạn đã có 20 tin nháp. Xóa bớt nháp cũ để lưu nháp này lên tài khoản.</string>`.

`SellEffect`, after `Kept`:

```kotlin
    /** "Bạn đã có 20 tin nháp…" as the form closes: the seller's draft stayed on the phone for the limit. */
    data object KeptOnPhone : SellEffect
```

`SellScreen`'s effects: `SellEffect.KeptOnPhone -> navigator.say(R.string.sell_draft_limit)` after the `Kept` line. `ReviewScreen`'s effects: the same line after its `Kept` line.

`SellViewModel.load()`: after `}.getOrNull()`:

```kotlin
        if (mode == SellMode.DRAFT && loaded == null) {
            // Gone from the phone: deleted on the other phone and pulled, posted, or past its end.
            outbox.send(SellEffect.Close)
            return@launch
        }
```

`onEvent`:

```kotlin
            SellEvent.SaveDraft -> saveDraft { save ->
                if (!toldLimit(save)) {
                    tell(UiMessage(R.string.sell_saved, action = R.string.sell_view, onAction = { outbox.trySend(SellEffect.ViewDrafts) }))
                }
            }
```

`SellEvent.Later`'s save: `saveDraft { save -> if (!toldLimit(save)) tell(UiMessage(R.string.sell_saved)) }`. `ConfirmClose`'s save: `event.save -> saveDraft(failed = ::askKeep, then = { closeKept(it) })`. `close()`'s TELL: `Leave.TELL -> discard(then = { closeKept(DraftSave.SYNCED) })`. `Verify` and `SetUpCod` keep their lambdas (they ignore the answer).

`saveDraft`, the limit line and `closeKept`:

```kotlin
    /**
     * Keeps the draft in Tin của bạn as the seller's own version, then [then] with how the save ended; a failure says so
     * and runs [failed]. Nothing is saved while a post runs: the post removes the draft, and a save landing after it
     * would put it back.
     */
    private fun saveDraft(failed: () -> Unit = {}, then: (DraftSave) -> Unit) {
        if (local.value.saving || local.value.phase == FormPhase.POSTING) return
        val draft = local.value.draft
        set { it.copy(saving = true) }
        viewModelScope.launch {
            sell.saveDraft(draft)
                .onSuccess { save ->
                    set { it.copy(saving = false, saved = draft, wrote = true, kept = draft) }
                    then(save)
                }
                .onFailure {
                    set { it.copy(saving = false) }
                    tell(UiMessage(DesignR.string.save_failed))
                    failed()
                }
        }
    }

    /** Whether this visit said "Bạn đã có 20 tin nháp…"; an autosave says it once. */
    private var limitTold = false

    /** Says the draft stayed on the phone for the limit, with "Xem" to Tin của bạn's drafts; false when it did not. */
    private fun toldLimit(save: DraftSave): Boolean {
        if (save != DraftSave.LIMIT) return false
        limitTold = true
        tell(UiMessage(R.string.sell_draft_limit, action = R.string.sell_view, onAction = { outbox.trySend(SellEffect.ViewDrafts) }))
        return true
    }

    /** "Đã lưu nháp" as the form closes, or the limit's line when the draft stayed on the phone. */
    private fun closeKept(save: DraftSave) {
        outbox.trySend(if (save == DraftSave.LIMIT) SellEffect.KeptOnPhone else SellEffect.Kept)
        closeNow()
    }
```

`scheduleAutosave`'s call:

```kotlin
        autosave.schedule(keeps, { local.value.takeUnless { it.saving }?.draft }) { sent, save ->
            if (!limitTold) toldLimit(save)
            set { it.copy(saved = sent, wrote = true) }
        }
```

Import `vn.shopnexus.core.data.DraftSave`.

- [ ] **Step 4: Kiểm tra tin**

`ReviewViewModel`: `SaveDraft` and `Later` as in Step 3 (with `ReviewEvent`). `exit`'s TELL `discard { leave(next, kept = true) }` becomes `discard { leave(next, kept = DraftSave.SYNCED) }`. `confirm`'s save becomes `saveDraft(failed = { ask(dialog ?: SellDialog.KEEP_DRAFT) }) { save -> leave(next, kept = save) }`. `leave`:

```kotlin
    /** Goes on with [effect]; after the seller's own save ([kept]) it says "Đã lưu nháp", or the limit's line. */
    private fun leave(effect: SellEffect, kept: DraftSave? = null) {
        autosave.cancel()
        kept?.let { outbox.trySend(if (it == DraftSave.LIMIT) SellEffect.KeptOnPhone else SellEffect.Kept) }
        outbox.trySend(effect)
    }
```

`saveDraft`, `limitTold` and `toldLimit` as in Step 3 (on `ReviewLocal`, whose `saveDraft` sets the same `saving`, `saved`, `wrote`, `kept`). `scheduleAutosave`'s call as in Step 3. `draftOf`: `val asPhotos = frames.map { Photo(it.url, source, uploadId = it.uploadId) }`. Import `vn.shopnexus.core.data.DraftSave`.

Run: `./gradlew :feature:sell:testDebugUnitTest` (in the background). Expected: PASS, old and new. Existing tests that compare a stored draft with the form through `normal()` still pass, since `normal()` now drops `synced` and `expiresAt`. Run `python3 tmp/unused_strings.py feature/sell/src/main/res/values/strings.xml`; expected: no output.

- [ ] **Step 5: README**

In "Fake data", after the paragraph on the listing reads, add:

> Drafts live on the phone and on a fake server, and the last save wins. A save writes the phone at once and then reaches the server. Past 20 drafts on the account a new one stays on the phone, and its card says "Chưa đồng bộ". Tin của bạn and Home's "Tiếp tục nháp" read the server's drafts each time they open, and a pull to refresh reads them again.

and in the debug-panel paragraph, after "each seeded order to pending, shipped, delivered, completed, failed or cancelled", add ", edits or deletes the draft edited last on the server as another phone would, holds the drafts' sync with "Mất mạng", and brings a draft to 3 days before its end". Run `python3 ~/.claude/skills/humanizing-writing/ai-tells.py README.md` and fix what it flags in the new sentences.

- [ ] **Step 6: The gate**

Run, in the background, and wait for the notice:

```bash
. ~/.local/share/shopnexus/android-env.sh && timeout 2400 ./gradlew :app:assembleDebug \
  :core:model:check :core:domain:check :core:data:check :feature:listings:check :feature:sell:check \
  :feature:discover:check :app:check > tmp/gate-listing-drafts.log 2>&1; tail -5 tmp/gate-listing-drafts.log
```

Expected: `BUILD SUCCESSFUL`. A failure in a module this plan did not touch is not this plan's to fix; say so and stop. `SellWalkTest` and `SliceTest` run inside `:app:check`; they save and post drafts through the fake and must stay green.

If a phone or emulator is attached (`adb devices`), `./run.sh` and walk: Tôi → Tin của bạn → Nháp (the seeded card, no label). In the debug panel turn "Mất mạng" on, open the draft, edit the title and go back: the card says "Chưa đồng bộ". Tap "Máy khác sửa nháp", turn "Mất mạng" off and pull to refresh: the label goes and your title stays. Tap "Tua tới sắp hết hạn" and pull to refresh: "Còn 3 ngày". Tap "Máy khác xóa nháp" and pull to refresh: the card goes. Screenshots to `tmp/listing-drafts/`. With no device, say the walk is left for the user.

- [ ] **Step 7: Commit**

```bash
./gradlew :feature:sell:spotlessApply
git add feature/sell README.md
```

`tmp/msg.txt`: `feat(sell): say when the 20-draft limit kept a draft on the phone, and close on a draft that is gone`. Check, commit. Stop the daemons and check `ps` for leftover shells from this session before reporting. Then follow superpowers:finishing-a-development-branch.

---

## Self-review

- **Spec coverage ("App").**
  - Model: `synced`, `expiresAt`, `Photo.uploadId`, `DraftCard.synced/expiresAt` (Task 1).
  - Fake, two stores with the 20-draft limit and the 30-day expiry: Task 2 (`FakeWorld`, `serverPut`, `serverExpired`).
  - `saveDraft` writes unsynced at once, then puts: accepted is synced with the end, the limit stays unsynced and is reported (Task 2 `aSaveOnlineReachesTheServer`, `aNewDraftPastTheLimitStaysOnThePhone`).
  - The pull's three rules: Task 2 `anEditOnTheOtherPhoneReplacesTheSyncedCopyAtTheNextPull`, `aDraftDeletedOnTheOtherPhoneLeavesAtTheNextPull`, `anUnsyncedDraftTheOtherPhoneDeletedIsPutAgain`.
  - Retries on the next save, the next pull, after a delete, and when "Mất mạng" goes off: Task 2 `theNextSaveSendsTheDraftsThatWaited`, `anUnsyncedEditWinsOverTheServersCopyAtThePull`, `deletingADraftSendsTheOneTheLimitHeld`, `anOfflineSaveWaitsAndGoesOutWhenTheNetworkComesBack`.
  - `post` deletes from both stores (`postingDeletesTheDraftFromBoth`); `newestDraft()` reads the merged list (`theNewestDraftReadsTheMergedList`, Home test).
  - DebugControls' four rows: Task 2. Expiry: `anExpiredDraftGoesAtTheNextPull`, `anUnsyncedDraftPastItsEndIsPutAgain`, `nearExpiryBringsTheEndThreeDaysOut`.
  - UI: both labels on one line in Tin của bạn only (Task 3), the limit message (Task 4), Home (Task 2).
  - Testing, app half: every bullet of the spec's "Fake repository" and "View models" maps to the tests named above.
- **What the cut removed** is absent: no revision, no conflict copy or "Bản trên máy này", no `DraftMove`, no notice or `NotificationTarget.Draft`, no "Máy khác đăng nháp". `:feature:notifications` is not touched.
- **Placeholders.** No "TBD" or "similar to Task N". Task 4 Step 4 points at Step 3's code within the same task and names the one type that differs (`ReviewLocal`).
- **Type consistency.**
  - `saveDraft(): Result<DraftSave>` in Tasks 2, 3, 4.
  - `withOtherPhoneDrafts(count, now)` adds to the server only, in Tasks 2, 3, 4.
  - `pulled(now)` puts what waited, in `DraftServer.kt`, `DebugControls.offline` and both repositories.
  - `draftDeleted(id, now): WorldState?` in `deleteDraft` and `post`.
  - `ListingsContent.Ready(listings, labels)` in Task 3's view model, screen and tests.
  - `DraftLabel.Unsynced/DaysLeft(days)` in Tasks 1, 3.
  - `closeKept(save: DraftSave)` and `leave(effect, kept: DraftSave?)` in Task 4.
- **Review Focus.** Each line has its test in the owning task:
  1. Task 2 `deletingOfflineRefusesASyncedDraftAndDropsALocalOne`.
  2. Task 2 `anUnsyncedEditWinsOverTheServersCopyAtThePull`.
  3. Task 2 `deletingADraftSendsTheOneTheLimitHeld` and Task 3 `theUnsyncedLabelGoesOnceADeleteFreesASlot`.
  4. Task 4 `anOfflineSaveSaysNothingAboutTheLimit`.
  5. Task 4 `aGoneDraftCloses`.

## Execution handoff

Recommended: subagent-driven, one fresh implementer and reviewer per task. Task 2 carries the rules every later task compiles against and tests through, so a mistake there is cheapest caught at its own gate; Tasks 3 and 4 are small and independent after it.
