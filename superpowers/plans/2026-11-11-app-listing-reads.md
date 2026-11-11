# App listing reads: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app's sell flow runs on the server's listing reads (on fakes): the photo path reads the cover only and offers "Điền lại theo ảnh này" when the cover changes; Quay video records an mp4 with sound and captions from the phone's `SpeechRecognizer`, and sends the transcript with the video; Kiểm tra shows the upload share, then the frames as they arrive, then the filled draft, or one pane per failure.

**Architecture:** One model, `ListingRead`, in `:core:model` mirrors the server's `ListingRead` (`api/schemas/assist.yaml`) and replaces `PhotoReading` and `VideoReading`. `SellRepository` gains `readPhoto(cover)` and `readVideo(video, transcript)`, both `Flow<ListingRead>`; the fake plays the server's steps and the failure the debug panel picks for the next read. The camera records through CameraX `VideoCapture`; captions and the recording reach `VideoViewModel` as events from composables, so the platform stays out of the ViewModels. Tasks 1 to 4 add the new path beside the old one, Task 5 removes the old one, Task 6 is the gate.

**Tech Stack:** Kotlin 2.4.21, AGP 9.4.1, Compose (material3 1.5.0-beta01), Navigation 3, Hilt, kotlinx.serialization, CameraX 1.6.2 (adds `camera-video`), `android.speech.SpeechRecognizer`, Robolectric, Turbine, Truth.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-11-listing-reads-design.md` (section "App"); the server contract `~/shopnexus/server/api/schemas/assist.yaml` and `api/paths/assist.yaml` on server `main`; the mockups `app/.superdesign/mockups/sell-steps.html`, `sell-video.html`, `sell-review.html` and their builders' docstrings (`.superdesign/tools/build_sell.py`, `build_sell_video.py`, `build_sell_review.py`) at app `743a85fe`.

**Ruling on this plan's form:** as in the app plans since stage 2 (`2026-10-27-app2-remove-declared-marks.md`), the plan fixes the contract (model, repository, fake, events and state) in code, every rule with its test by name and its assertion, and the copy word for word; screen code is written during execution against the mockup. Cost if wrong: screen code is reviewed only at the final review.

## Global Constraints

- Stage 1 to 5's constraints hold: minSdk 31, compileSdk 37, targetSdk 36, JVM 21; features never depend on features; `:core:model` and `:core:domain` are JVM; colours only through the theme and the type scale; Vietnamese strings in each module's `strings.xml`, one value per name across modules; money as `Vnd`.
- Work on branch `feat/listing-reads` in the worktree `~/shopnexus/app/.worktrees/listing-reads` (already holds the design commit `743a85fe`). The main checkout holds another session's uncommitted work; never commit from it.
- The gate is `./gradlew check` (unit tests, Robolectric UI tests, the raw-colour check, Android Lint, detekt, ktlint). Run it through `~/shopnexus/app/tmp/gate.sh <log> ~/shopnexus/app/.worktrees/listing-reads` wrapped in `timeout 1500`; `gate.sh` uses `--offline`, so the first build after Task 3 adds `camera-video` runs `./gradlew :core:ui:dependencies` online once. Per task, `./gradlew :feature:sell:testDebugUnitTest :core:data:testDebugUnitTest` (or the module's own) while working; the task's last step runs the gate.
- `./gradlew spotlessApply` before each commit; `check` fails on files ktlint would change.
- `ShopNexusJson` keeps `ignoreUnknownKeys = true`: drafts and saved state written by the build before still decode (the old `readPhotos`, `reading` and `VideoReading` keys are ignored).
- Copy, word for word (mockup at `743a85fe`):
  - photo step: "Ảnh bìa đã đổi", "Điền lại theo ảnh này"; description help "Kể thêm: dùng bao lâu, sửa chữa chưa, kèm phụ kiện gì";
  - camera: hint "Nói về món đồ: dùng bao lâu, tình trạng, giá muốn bán";
  - Kiểm tra: "Đang tải video lên", "Giá bạn nói";
  - failures (title / body / actions):
    - `UPLOAD_FAILED` "Chưa tải được video" / "Kiểm tra kết nối mạng rồi thử lại. Video vẫn còn trên máy." / Thử lại
    - `VIDEO_TOO_SHORT` "Video ngắn quá" / "Quay ít nhất 3 giây: xoay quanh món đồ và nói vài câu về nó." / Quay lại
    - `VIDEO_TOO_LONG` "Video dài quá" / "AI đọc video dưới 35 giây. Quay lại ngắn hơn hoặc chọn video khác." / Quay lại
    - `NO_ITEM` "Không thấy món đồ nào" / "Quay rõ một món đồ bạn muốn bán, đủ sáng, cả mặt trước và mặt sau." / Quay lại, Đăng bằng ảnh
    - `UNREADABLE` "Không đọc được video" / "Video bị hỏng hoặc có định dạng lạ. Thử quay lại ngay trong app." / Quay lại
    - `UNAVAILABLE` "Chưa đọc xong video" / "Thử lại sau ít phút, video vẫn còn trên máy." / Thử lại, Đăng bằng ảnh
    - `READ_LIMIT_REACHED` "Hết lượt đọc video hôm nay" / "Mỗi ngày đọc được 30 video. Bạn vẫn đăng bằng ảnh được." / Đăng bằng ảnh
- No copy narrates what the model is doing ("AI đang…", findings lists, "AI sẽ nghe lại"). The strings `sell_reading` and `review_reading` and the findings go.
- Commits: no `Co-Authored-By` trailer; prefixes as in `git log` (`feat(sell): …`, `feat(data): …`, `feat(ui): …`, `design: …`). Code comments and commit messages go through `python3 ~/.claude/skills/humanizing-writing/ai-tells.py FILE`.
- Scratch files and logs under `~/shopnexus/app/tmp/`.

## Review Focus

1. The seller deletes or reorders the cover while its read runs: the read still fills the form (fields the seller typed meanwhile stay), and the strip "Ảnh bìa đã đổi" shows once it lands, since the cover read is no longer first. Task 2 `SellViewModelTest.aCoverChangedDuringTheReadOffersTheReadAgain`.
2. Process death in the middle of either read (READING restored from `SavedStateHandle`): the screen reads again from the start and the draft gets one read's values, not two. Task 2 `SellViewModelTest.aRestoredReadingReadsTheCoverAgain`, Task 4 `ReviewViewModelTest.aRestoredReadingReadsTheVideoAgain`.
3. The microphone refused, or a phone with no recognizer: the take still records and opens Kiểm tra, the caption box keeps the hint all through, and the read gets no transcript (`null`), never an empty or partial-only string. Task 3 `VideoViewModelTest.withoutCaptionsTheTakeSendsNoTranscript`.
4. A partial result that never turns final before the take stops (the seller still talking at 30 s): the transcript keeps the finals and the last partial, in order, once. Task 3 `VideoViewModelTest.theTranscriptKeepsTheLastPartialAtTheStop`.
5. A video longer than 35 s from the library: Kiểm tra shows "Video dài quá" with "Quay lại", and "Quay lại" opens the camera without a "Lưu nháp tin này?" dialog (nothing was read). Task 4 `ReviewViewModelTest.aTooLongVideoFailsAndRecordsAgainWithoutAsking`.

## Deviations from the spec

- `ReadDraft.category` is the app's `CategoryRef`, not the server's `category_code`: the app has no category codes yet; the client that maps one to the other comes with the network layer.
- The form keeps its phone fields. A read's `specs` fill them by label (`Dung lượng` → storage, `Màu` → color, `Pin` → battery, read as a percent); other labels are dropped until the form has a list of specs. `ReadDraft` keeps every spec so nothing is lost on the way.
- `ListingRead` carries three app-only fields the server does not send: `uploadedPercent` (the upload's share, the app's own progress), and `suggestions` and `market` (the price step's data, which has no API yet).
- The fake reads any video, a real recording included, as the sample's eight frames and words; a real recording gets the snackbar "Bản mẫu đọc dữ liệu mẫu, chưa xem video thật", as a library video does today.

## File map

| File | Responsibility | Task |
|---|---|---|
| `core/model/.../Reads.kt` (new) | `ListingRead`, `ReadSource`, `ReadStatus`, `ReadFailure`, `ReadPhoto`, `ReadSpec`, `ReadDraft`, `ReadEstimate`, `RecordedVideo` | 1 |
| `core/model/.../Draft.kt` | `ListingDraft.readCover` replaces `readPhotos` | 2 |
| `core/model/.../Selling.kt` | `PhotoReading`, `VideoReading`, `Finding`, `CueKind.CHIP` go | 5 |
| `core/data/.../Repositories.kt` | `SellRepository.readPhoto`, `readVideo(video, transcript)` | 1, 5 |
| `core/data/.../fake/FakeSellRepository.kt`, `ReadOutcomes.kt` (new), `Seeds.kt`, `resources/fixtures/sell.json` | the server's steps, the next read's failure, the photo read's seed | 1, 5 |
| `core/data/.../fake/DebugControls.kt`, `app/src/debug/.../DebugHost.kt`, `app/src/debug/res/values/strings.xml` | "Lần đọc tới" chips | 1 |
| `core/data/src/test/.../FakeSellRepositoryTest.kt` | the fake's reads | 1, 5 |
| `feature/sell/.../form/SellForm.kt` | `ListingDraft.withRead(ListingRead)` | 2 |
| `feature/sell/.../form/SellViewModel.kt`, `SellScreen.kt`, `parts/PhotoBoard.kt`, `res/values/strings.xml` | cover read, strip, board while reading, description help | 2 |
| `gradle/libs.versions.toml`, `core/ui/build.gradle.kts`, `core/ui/src/main/AndroidManifest.xml` | `camera-video`, `RECORD_AUDIO` | 3 |
| `core/ui/.../camera/VideoCamera.kt`, `Captions.kt` (new), `MicPermission.kt` (new), `VideoFrames.kt` → `VideoLength.kt`; `FrameGrabber.kt` deleted | recording, captions, the mic, a library video's length | 3 |
| `core/data/.../CameraStandIn.kt`, its impl | `video` | 3 |
| `core/navigation/.../Routes.kt` | `SellReviewRoute(video, seconds, fromLibrary, transcript, draftId)` | 3 |
| `feature/sell/.../video/VideoViewModel.kt`, `VideoScreen.kt` | events from the camera and the recognizer, captions, transcript | 3 |
| `feature/sell/.../review/ReviewViewModel.kt`, `ReviewScreen.kt`, `ReviewSheets.kt` | the read's steps, failure panes, no video tile, "Giá bạn nói" | 4 |
| `feature/discover/.../home/HomeViewModel.kt` | routes a video draft with the new `SellReviewRoute` | 3 |
| tests under `feature/sell/src/test/...` | per task | 2–4 |

## Task order and interfaces

1 → 2 → 3 → 4 → 5 → 6, each green on its own. Task 2 needs 1; Task 4 needs 1 and 3 (the route); Task 5 needs 2 and 4.

Names later tasks rely on (Task 1 unless said):

- `ListingRead(id: String, source: ReadSource, status: ReadStatus, failure: ReadFailure? = null, uploadedPercent: Int? = null, photos: List<ReadPhoto>? = null, draft: ReadDraft? = null, estimate: ReadEstimate? = null, suggestions: List<PriceSuggestion> = emptyList(), market: MarketRead? = null)`.
- `ReadFailure.{UNREADABLE, VIDEO_TOO_SHORT, VIDEO_TOO_LONG, LISTING_NOT_FOUND, NO_ITEM, UNAVAILABLE, UPLOAD_FAILED, READ_LIMIT_REACHED}`.
- `RecordedVideo(uri: String, seconds: Int, fromLibrary: Boolean)`.
- `SellRepository.readPhoto(cover: Photo): Flow<ListingRead>`, `readVideo(video: RecordedVideo, transcript: String?): Flow<ListingRead>`.
- `ReadOutcomes.next: ReadFailure?` (one-shot), `DebugControls.nextReadFailure`.
- `ListingDraft.withRead(r: ListingRead): ListingDraft` and `ListingDraft.readCover: String?` (Task 2).
- `VideoEvent.Recorded(uri: String, millis: Long)`, `VideoEvent.Heard(text: String, final: Boolean)`, `VideoEvent.Captions(available: Boolean)`, `VideoEffect.Review(video: RecordedVideo, transcript: String?)` (Task 3).
- `SellReviewRoute(video: String? = null, seconds: Int = 0, fromLibrary: Boolean = false, transcript: String? = null, draftId: String? = null)` (Task 3).
- `ReviewUiState.read: ListingRead?`, `ReviewEvent.PostWithPhotos`, `ReviewEffect`-equivalent `SellEffect.OpenPhotos` (Task 4).

---

### Task 1: `ListingRead` and the fake's reads

**Files:** Create `core/model/src/main/kotlin/vn/shopnexus/core/model/Reads.kt`, `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/ReadOutcomes.kt`. Modify `Repositories.kt`, `FakeSellRepository.kt`, `Seeds.kt`, `fixtures/sell.json`, `DebugControls.kt`, `app/src/debug/.../DebugHost.kt` and its strings. Test `FakeSellRepositoryTest.kt`.

**Interfaces:** Produces the model and repository names above. The old `readPhotos` and `readVideo(VideoTake)` stay until Task 5.

- [ ] **Step 1: Write the failing fake tests**

Add to `FakeSellRepositoryTest` (it builds `FakeSellRepository(world, failures, clock, CounterpartListener { _, _ -> }, Pace())`; the new constructor parameter defaults, so it keeps building):

```kotlin
@Test
fun aPhotoReadReadsTheCoverOnly() = runTest {
    val cover = Photo("https://x/cover.jpg", PhotoSource.APP)
    repo.readPhoto(cover).test {
        assertThat(awaitItem().status).isEqualTo(ReadStatus.READING)
        val done = awaitItem()
        assertThat(done.status).isEqualTo(ReadStatus.DONE)
        assertThat(done.source).isEqualTo(ReadSource.PHOTO)
        assertThat(done.photos!!.map { it.url }).containsExactly(cover.url)
        val d = done.draft!!
        assertThat(d.photos).containsExactly(done.photos!!.single().uploadId)
        assertThat(d.price).isNull()
        assertThat(d.allowOffers).isFalse()
        // What the photo shows, never a mark or what a photo cannot show.
        assertThat(d.description).isEqualTo("iPhone 11 màu trắng, mặt lưng kính, cụm 2 camera sau.")
        assertThat(d.title).isEqualTo("iPhone 11 Trắng")
        awaitComplete()
    }
}

@Test
fun aVideoReadFollowsTheServersSteps() = runTest {
    repo.readVideo(RecordedVideo("content://take.mp4", seconds = 12, fromLibrary = false), "Máy dùng 3 năm.").test {
        val shares = mutableListOf<Int>()
        var r = awaitItem()
        while (r.uploadedPercent != null) { shares += r.uploadedPercent!!; r = awaitItem() }
        assertThat(shares.first()).isEqualTo(0)
        assertThat(shares.last()).isEqualTo(100)
        assertThat(r.status).isEqualTo(ReadStatus.READING)
        assertThat(r.photos).isNull()
        r = awaitItem() // the frames step
        assertThat(r.photos).hasSize(8)
        assertThat(r.photos!!.all { it.atSeconds != null }).isTrue()
        r = awaitItem() // the fill step
        assertThat(r.draft!!.photos).hasSize(4)
        assertThat(r.draft!!.price).isEqualTo(Vnd(4_500_000))
        r = awaitItem() // done, with the range
        assertThat(r.status).isEqualTo(ReadStatus.DONE)
        assertThat(r.estimate).isNotNull()
        awaitComplete()
    }
}

@Test
fun aVideoOutsideThreeToThirtyFiveSecondsFails() = runTest {
    for ((seconds, failure) in listOf(2 to ReadFailure.VIDEO_TOO_SHORT, 36 to ReadFailure.VIDEO_TOO_LONG)) {
        val end = repo.readVideo(RecordedVideo("content://v.mp4", seconds, fromLibrary = true), null).toList().last()
        assertThat(end.status).isEqualTo(ReadStatus.FAILED)
        assertThat(end.failure).isEqualTo(failure)
    }
}

@Test
fun theNextReadFailsAsTheDebugPanelSaysOnce() = runTest {
    outcomes.next = ReadFailure.NO_ITEM
    assertThat(repo.readPhoto(photo).toList().last().failure).isEqualTo(ReadFailure.NO_ITEM)
    assertThat(repo.readPhoto(photo).toList().last().status).isEqualTo(ReadStatus.DONE)
}

@Test
fun aFailingNetworkFailsTheUpload() = runTest {
    failures.rate = 1.0
    val end = repo.readVideo(RecordedVideo("content://v.mp4", 12, false), null).toList().last()
    assertThat(end.failure).isEqualTo(ReadFailure.UPLOAD_FAILED)
}
```

`repo` is built with `outcomes = ReadOutcomes()` held by the test; `photo` is the test file's existing sample photo. Run `./gradlew :core:data:testDebugUnitTest --tests '*FakeSellRepositoryTest*'`. Expected: does not compile (`readPhoto`, `RecordedVideo` undefined).

- [ ] **Step 2: The model**

`core/model/src/main/kotlin/vn/shopnexus/core/model/Reads.kt`:

```kotlin
package vn.shopnexus.core.model

import kotlinx.serialization.Serializable

/** What a read reads into a draft: the seller's video, one photo, or their listing elsewhere. */
@Serializable enum class ReadSource { VIDEO, PHOTO, LINK }

@Serializable enum class ReadStatus { READING, DONE, FAILED }

/**
 * Why a read failed: the server's six codes, then the app's own two (the upload never got through, the server's cap
 * refused the start).
 */
@Serializable
enum class ReadFailure { UNREADABLE, VIDEO_TOO_SHORT, VIDEO_TOO_LONG, LISTING_NOT_FOUND, NO_ITEM, UNAVAILABLE, UPLOAD_FAILED, READ_LIMIT_REACHED }

/** A photo the read holds for the draft: a video's frame with its time, or the photo read. */
@Serializable data class ReadPhoto(val uploadId: String, val url: String, val atSeconds: Double? = null)

@Serializable data class ReadSpec(val label: String, val value: String)

/** The draft the read filled, as the server's ReadDraft; [category] is the app's own until the client maps codes. */
@Serializable
data class ReadDraft(
    val title: String,
    val category: CategoryRef?,
    val condition: Condition?,
    val specs: List<ReadSpec>,
    val description: String,
    val price: Vnd?,
    val allowOffers: Boolean,
    /** Upload IDs of the draft's photos, the cover first. */
    val photos: List<String>,
)

@Serializable enum class EstimateSource { MARKET, MODEL }

@Serializable data class ReadEstimate(val low: Vnd, val median: Vnd, val high: Vnd, val source: EstimateSource, val sampleSize: Int)

/**
 * A read as the server returns it after each step: photos after the frames step, the draft after the fill, the range
 * at the end. [uploadedPercent] is the app's share of the video sent, set only while it uploads; [suggestions] and
 * [market] are the price step's, which has no API yet.
 */
@Serializable
data class ListingRead(
    val id: String,
    val source: ReadSource,
    val status: ReadStatus,
    val failure: ReadFailure? = null,
    val uploadedPercent: Int? = null,
    val photos: List<ReadPhoto>? = null,
    val draft: ReadDraft? = null,
    val estimate: ReadEstimate? = null,
    val suggestions: List<PriceSuggestion> = emptyList(),
    val market: MarketRead? = null,
)

/** A take from Quay video or a video from the library, before it is read. */
@Serializable data class RecordedVideo(val uri: String, val seconds: Int, val fromLibrary: Boolean)

fun ReadEstimate.range(): PriceRange = PriceRange(low, median, high)
```

Check `PriceRange`'s constructor in `Selling.kt`/`Money.kt` and adapt `range()` to it.

- [ ] **Step 3: The repository and the next read's failure**

`Repositories.kt`, in `SellRepository` after `readVideo`:

```kotlin
    /** Reads [cover], the listing's first photo, as the server's photo read: READING, then DONE with the draft or FAILED. */
    fun readPhoto(cover: Photo): Flow<ListingRead>

    /**
     * Uploads [video] with what the phone heard ([transcript], null without a recognizer) and reads it as the server
     * does: the upload's share, READING, the frames, the draft, then DONE with the range, or FAILED.
     */
    fun readVideo(video: RecordedVideo, transcript: String?): Flow<ListingRead>
```

`core/data/src/main/kotlin/vn/shopnexus/core/data/fake/ReadOutcomes.kt`:

```kotlin
package vn.shopnexus.core.data.fake

import javax.inject.Inject
import javax.inject.Singleton
import vn.shopnexus.core.model.ReadFailure

/** The failure the next read ends with, set from the debug panel; a read takes it once. */
@Singleton
class ReadOutcomes @Inject constructor() {
    @Volatile var next: ReadFailure? = null

    fun take(): ReadFailure? = next.also { next = null }
}
```

- [ ] **Step 4: The seed**

`Seeds.kt`: `SellSeed` gains `photoRead: ReadDraft` and `photoEstimate: PriceRange`; `VideoSeed` gains `specs: List<ReadSpec>` (`Dung lượng 64 GB`, `Màu Trắng`, `Pin 81%`). `sell.json` gains:

```json
"photoRead": {
  "title": "iPhone 11 Trắng",
  "category": {"key": "phones", "sub": "iPhone"},
  "condition": "USED",
  "specs": [{"label": "Màu", "value": "Trắng"}],
  "description": "iPhone 11 màu trắng, mặt lưng kính, cụm 2 camera sau.",
  "price": null,
  "allowOffers": false,
  "photos": []
},
"photoEstimate": {"low": 4400000, "median": 4800000, "high": 5100000}
```

and `video.specs` as above. `photoReading` stays until Task 5.

- [ ] **Step 5: The fake's two reads**

In `FakeSellRepository`, inject `private val outcomes: ReadOutcomes = ReadOutcomes()` last in the constructor, and add:

```kotlin
/** The photo read: one step, the server's fill and estimate. */
private const val PHOTO_FILL_MILLIS = 1_800L

/** The video read: the upload in ten shares, the frames step, the fill, the estimate. */
private const val UPLOAD_SHARE_MILLIS = 140L
private const val FRAMES_MILLIS = 800L
private const val FILL_MILLIS = 2_600L
private const val ESTIMATE_MILLIS = 1_300L

override fun readPhoto(cover: Photo): Flow<ListingRead> = flow {
    val id = world.next { "rd-$it" }
    val reading = ListingRead(id, ReadSource.PHOTO, ReadStatus.READING)
    emit(reading)
    delay(pace.of(PHOTO_FILL_MILLIS))
    val failure = outcomes.take() ?: failures.run {}.exceptionOrNull()?.let { ReadFailure.UNAVAILABLE }
    if (failure != null) {
        emit(reading.copy(status = ReadStatus.FAILED, failure = failure))
        return@flow
    }
    val photo = ReadPhoto(uploadId = "up-$id", url = cover.url)
    emit(
        reading.copy(
            status = ReadStatus.DONE, photos = listOf(photo), draft = seed.photoRead.copy(photos = listOf(photo.uploadId)),
            estimate = seed.photoEstimate.let { ReadEstimate(it.low, it.median, it.high, EstimateSource.MODEL, 0) },
            suggestions = seed.photoReading.suggestions, market = seed.photoReading.market,
        ),
    )
}

override fun readVideo(video: RecordedVideo, transcript: String?): Flow<ListingRead> = flow {
    val id = world.next { "rd-$it" }
    val base = ListingRead(id, ReadSource.VIDEO, ReadStatus.READING)
    for (p in 0..100 step 10) {
        emit(base.copy(uploadedPercent = p))
        delay(pace.of(UPLOAD_SHARE_MILLIS))
    }
    if (failures.run {}.isFailure) {
        emit(base.copy(status = ReadStatus.FAILED, failure = ReadFailure.UPLOAD_FAILED))
        return@flow
    }
    val planned = outcomes.take()
    if (planned == ReadFailure.READ_LIMIT_REACHED || planned == ReadFailure.UPLOAD_FAILED) {
        emit(base.copy(status = ReadStatus.FAILED, failure = planned))
        return@flow
    }
    emit(base)
    val tooShortOrLong = when {
        video.seconds < MIN_VIDEO_SECONDS -> ReadFailure.VIDEO_TOO_SHORT
        video.seconds > MAX_VIDEO_SECONDS -> ReadFailure.VIDEO_TOO_LONG
        else -> null
    }
    delay(pace.of(FRAMES_MILLIS))
    (tooShortOrLong ?: planned?.takeIf { it == ReadFailure.UNREADABLE })?.let {
        emit(base.copy(status = ReadStatus.FAILED, failure = it))
        return@flow
    }
    val frames = seed.frames.mapIndexed { i, url -> ReadPhoto("fr-$id-$i", url, atSeconds = i * 1.5) }
    val withFrames = base.copy(photos = frames)
    emit(withFrames)
    delay(pace.of(FILL_MILLIS))
    planned?.let {
        emit(withFrames.copy(status = ReadStatus.FAILED, failure = it))
        return@flow
    }
    val v = seed.video
    val draft = ReadDraft(
        title = v.title, category = v.category, condition = v.condition, specs = v.specs, description = v.description,
        price = v.price, allowOffers = true, photos = v.kept.filter { it < frames.size }.map { frames[it].uploadId },
    )
    val filled = withFrames.copy(draft = draft, suggestions = seed.photoReading.suggestions, market = seed.photoReading.market)
    emit(filled)
    delay(pace.of(ESTIMATE_MILLIS))
    emit(filled.copy(status = ReadStatus.DONE, estimate = v.estimate.let { ReadEstimate(it.low, it.median, it.high, EstimateSource.MODEL, 0) }))
}
```

with `private const val MIN_VIDEO_SECONDS = 3` and `MAX_VIDEO_SECONDS = 35`. `transcript` is not read by the fake: the sample's words stand for either source (see Deviations).

- [ ] **Step 6: The debug panel**

`DebugControls` gains:

```kotlin
    /** The failure the next listing read ends with; null reads normally. */
    var nextReadFailure: ReadFailure?
        get() = outcomes.next
        set(value) {
            outcomes.next = value
        }
```

(constructor gains `private val outcomes: ReadOutcomes`). `DebugHost` adds, under the switches, a title "Lần đọc tới" (`debug_next_read`) and a `FlowRow` of `FilterChip`s: "Bình thường" (`debug_read_normal`, null) and one per `ReadFailure` labelled with its enum name (developer labels, as `ORDER_JUMPS` are). Selecting one sets `controls.nextReadFailure`.

- [ ] **Step 7: Run the fake tests**

Run `./gradlew :core:data:testDebugUnitTest --tests '*FakeSellRepositoryTest*'`. Expected: PASS, old and new.

- [ ] **Step 8: Gate and commit**

Run the gate. `git commit -m "feat(data): ListingRead, and the fake's photo and video reads as the server runs them"`.

### Task 2: The photo path reads the cover

**Files:** Modify `core/model/.../Draft.kt`, `feature/sell/.../form/SellForm.kt`, `SellViewModel.kt`, `SellScreen.kt`, `parts/PhotoBoard.kt`, `feature/sell/src/main/res/values/strings.xml`. Tests `SellFormTest.kt`, `SellViewModelTest.kt`, `SellScreenTest.kt`, `PhotoBoardTest.kt`.

**Interfaces:** Consumes Task 1. Produces `ListingDraft.readCover`, `ListingDraft.withRead`, `SellUiState.read: ListingRead?`, `SellUiState.coverChanged: Boolean`, `SellEvent.ReadCoverAgain`.

- [ ] **Step 1: Write the failing tests**

`SellFormTest`:

```kotlin
@Test
fun aReadFillsTheFormsFieldsFromItsSpecs() {
    val d = blank.withRead(read(specs = listOf(ReadSpec("Màu", "Trắng"), ReadSpec("Dung lượng", "64 GB"), ReadSpec("Pin", "81%"), ReadSpec("Hãng", "Apple"))))
    assertThat(d.color).isEqualTo("Trắng")
    assertThat(d.storage).isEqualTo("64 GB")
    assertThat(d.battery).isEqualTo(81)
    assertThat(d.aiFields).containsAtLeast(DraftField.TITLE, DraftField.COLOR, DraftField.DESCRIPTION)
    assertThat(d.readCover).isEqualTo(COVER.url)
}

@Test
fun readingAgainKeepsWhatTheSellerTyped() {
    val typed = blank.withRead(read()).copy(title = "Của tôi", aiFields = setOf(DraftField.COLOR, DraftField.DESCRIPTION))
    val again = typed.withRead(read(title = "iPhone 11 Đen", color = "Đen"))
    assertThat(again.title).isEqualTo("Của tôi")
    assertThat(again.color).isEqualTo("Đen")
}
```

(`read(...)` builds a DONE photo `ListingRead` whose one photo is `COVER`; a helper in the test file.)

`SellViewModelTest`:

```kotlin
@Test
fun theFirstPhotosReadOnlyTheCover() = runTest {
    val vm = viewModel()
    vm.onEvent(SellEvent.AddPhotos(listOf(photo, photo2, photo3)))
    assertThat(vm.state.value.phase).isEqualTo(FormPhase.READING)
    advanceTimeBy(1_800); runCurrent()
    assertThat(vm.state.value.phase).isEqualTo(FormPhase.FILLED)
    assertThat(vm.state.value.draft.readCover).isEqualTo(photo.url)
    assertThat(vm.state.value.draft.description).isEqualTo("iPhone 11 màu trắng, mặt lưng kính, cụm 2 camera sau.")
    vm.onEvent(SellEvent.AddPhotos(listOf(photo4)))
    assertThat(vm.state.value.phase).isEqualTo(FormPhase.FILLED) // a later photo is not read
}

@Test
fun aChangedCoverOffersTheReadAgainThatKeepsTypedFields() = runTest {
    val vm = viewModel()
    vm.onEvent(SellEvent.AddPhotos(listOf(photo, photo2))); advanceTimeBy(1_800); runCurrent()
    vm.onEvent(SellEvent.Edit(FormEdit.Title("Của tôi")))
    assertThat(vm.state.value.coverChanged).isFalse()
    vm.onEvent(SellEvent.Edit(FormEdit.Cover(1)))
    assertThat(vm.state.value.coverChanged).isTrue()
    vm.onEvent(SellEvent.ReadCoverAgain)
    assertThat(vm.state.value.phase).isEqualTo(FormPhase.READING)
    advanceTimeBy(1_800); runCurrent()
    assertThat(vm.state.value.draft.readCover).isEqualTo(photo2.url)
    assertThat(vm.state.value.draft.title).isEqualTo("Của tôi")
    assertThat(vm.state.value.coverChanged).isFalse()
}

@Test
fun aCoverChangedDuringTheReadOffersTheReadAgain() = runTest {
    val vm = viewModel()
    vm.onEvent(SellEvent.AddPhotos(listOf(photo, photo2)))
    vm.onEvent(SellEvent.Edit(FormEdit.RemovePhoto(0)))
    advanceTimeBy(1_800); runCurrent()
    assertThat(vm.state.value.phase).isEqualTo(FormPhase.FILLED)
    assertThat(vm.state.value.draft.title).isNotEmpty()
    assertThat(vm.state.value.coverChanged).isTrue()
}

@Test
fun aRestoredReadingReadsTheCoverAgain() = runTest {
    val handle = SavedStateHandle()
    val first = viewModel(handle = handle)
    first.onEvent(SellEvent.AddPhotos(listOf(photo)))
    val second = viewModel(handle = handle.copy())
    advanceTimeBy(1_800); runCurrent()
    assertThat(second.state.value.phase).isEqualTo(FormPhase.FILLED)
    assertThat(second.state.value.draft.readCover).isEqualTo(photo.url)
}

@Test
fun aFailedCoverReadCanBeRetried() = runTest {
    outcomes.next = ReadFailure.UNAVAILABLE
    val vm = viewModel()
    vm.onEvent(SellEvent.AddPhotos(listOf(photo))); advanceTimeBy(1_800); runCurrent()
    assertThat(vm.state.value.phase).isEqualTo(FormPhase.READ_FAILED)
    vm.onEvent(SellEvent.RetryRead); advanceTimeBy(1_800); runCurrent()
    assertThat(vm.state.value.phase).isEqualTo(FormPhase.FILLED)
}
```

(the test builds the fake with a held `outcomes = ReadOutcomes()`; `photo2`…`photo4` are more sample photos.)

`SellScreenTest`:

- `theBoardStaysWhileTheCoverIsRead`: state in READING with three photos shows the node tagged `board-cover` and `cover-reading` (the scan overlay), and no text `Đang đọc ảnh…`.
- `theCoverStripReadsAgain`: state FILLED with `coverChanged = true` shows "Ảnh bìa đã đổi"; clicking "Điền lại theo ảnh này" sends `SellEvent.ReadCoverAgain`.
- `theDescriptionAsksForWhatOnlyTheSellerKnows`: the description field shows "Kể thêm: dùng bao lâu, sửa chữa chưa, kèm phụ kiện gì".

Run `./gradlew :feature:sell:testDebugUnitTest`. Expected: does not compile.

- [ ] **Step 2: The draft and `withRead`**

`Draft.kt`: replace `readPhotos: Int = 0` with

```kotlin
    /** The cover the model read; null before any read. A cover that differs offers "Điền lại theo ảnh này". */
    val readCover: String? = null,
```

and fix its readers (`SellViewModel.load`'s `unread`: `draft.readCover == null`). `SellForm.kt`: `withRead` replaces `withReading`, with the same rule (a field the seller left blank, or one still carrying the sparkle, takes the read; one they typed keeps its value):

```kotlin
fun ListingDraft.withRead(r: ListingRead): ListingDraft {
    val d = checkNotNull(r.draft) { "A read without a draft fills nothing" }
    val ai = mutableSetOf<DraftField>()
    fun <T> take(field: DraftField?, mine: T, blank: Boolean, read: T): T {
        val fill = blank || (field != null && field in aiFields)
        if (fill && field != null) ai += field
        return if (fill) read else mine
    }
    fun spec(label: String) = d.specs.firstOrNull { it.label == label }?.value
    return copy(
        title = take(DraftField.TITLE, title, title.isBlank(), d.title),
        category = take(DraftField.CATEGORY, category, category == null, d.category),
        condition = take(DraftField.CONDITION, condition, condition == null, d.condition),
        storage = take(null, storage, storage.isNullOrBlank(), spec("Dung lượng") ?: storage),
        color = take(DraftField.COLOR, color, color.isBlank(), spec("Màu") ?: color),
        battery = take(null, battery, battery == null, spec("Pin")?.removeSuffix("%")?.trim()?.toIntOrNull() ?: battery),
        description = take(DraftField.DESCRIPTION, description, description.isBlank(), d.description),
        aiFields = aiFields - FILLED_BY_READ + ai,
        estimate = r.estimate?.range(), suggestions = r.suggestions,
        readCover = r.photos?.firstOrNull()?.url,
    )
}
```

- [ ] **Step 3: The ViewModel**

- `SellUiState` / `SellLocal`: `reading: PhotoReading?` becomes `read: ListingRead?`; saved under `READING` with `ListingRead.serializer()`. `SellUiState.coverChanged` is derived: `phase == FILLED && mode != EDIT && draft.readCover != null && draft.photos.firstOrNull()?.url != draft.readCover`.
- `startRead()` collects `sell.readPhoto(draft.photos.first())` into a job (the previous one cancelled): on `DONE` set `phase = FILLED, read = r, draft = draft.withRead(r)`; on `FAILED` set `phase = READ_FAILED`; a thrown error is `READ_FAILED` too.
- `SellEvent.ReadCoverAgain` runs `startRead()` when `coverChanged`.
- `addPhotos` keeps its rule (the first photos of a new listing start a read).
- Every `state.reading?.market` in the screen and the VM becomes `state.read?.market`.

- [ ] **Step 4: The screen**

- The Ảnh step shows `PhotoBoard` in READING and FILLED (READ_FAILED keeps `PhotoRow` and `ReadFailed`). `PhotoBoard` gains `reading: Boolean`: the cover carries the scan line and `LoadingIndicator` at its bottom right (tag `cover-reading`), the shots wait (`shots` empty while reading), and the grid still adds and removes photos.
- Under the cover, when `state.coverChanged`, a strip: sparkle, "Ảnh bìa đã đổi" (`sell_cover_changed`), and a text button "Điền lại theo ảnh này" (`sell_read_again`) sending `SellEvent.ReadCoverAgain`.
- `Reading()` and the string `sell_reading` go.
- The description field's supporting text is "Kể thêm: dùng bao lâu, sửa chữa chưa, kèm phụ kiện gì" (`sell_description_help`) until an error replaces it.

- [ ] **Step 5: Run the module's tests**

Run `./gradlew :feature:sell:testDebugUnitTest`. Expected: PASS (fix the old tests that called `withReading` or asserted the reading panel; `aReadFillsThePhotoValuesAfterTheDelay`-style VM tests now assert the cover read's values).

- [ ] **Step 6: Gate and commit**

Gate. `git commit -m "feat(sell): the photo path reads the cover, and offers a read of a new one"`.

### Task 3: Quay video records an mp4 and the phone's captions

**Files:** Modify `gradle/libs.versions.toml`, `core/ui/build.gradle.kts`, `core/ui/src/main/AndroidManifest.xml`, `core/ui/.../camera/VideoCamera.kt`; create `core/ui/.../camera/Captions.kt`, `MicPermission.kt`; rename `VideoFrames.kt` to `VideoLength.kt`; delete `FrameGrabber.kt` and its test if any; modify `core/data/.../CameraStandIn.kt` and its simulated impl, `core/navigation/.../Routes.kt`, `feature/sell/.../video/VideoViewModel.kt`, `VideoScreen.kt`, `feature/discover/.../home/HomeViewModel.kt`, `feature/sell/.../review/ReviewViewModel.kt` (only the route's new fields, read in Task 4), strings. Tests `VideoViewModelTest.kt`, `VideoScreenTest.kt`.

**Interfaces:** Produces the `VideoEvent`/`VideoEffect` names and `SellReviewRoute` above.

- [ ] **Step 1: Write the failing ViewModel tests**

In `VideoViewModelTest` (it builds `VideoViewModel(sell, SimulatedCamera())`):

```kotlin
@Test
fun aCameraTakeOpensReviewWithTheRecordingAndWhatWasHeard() = runTest {
    val vm = viewModel()
    vm.onEvent(VideoEvent.Captions(available = true))
    vm.onEvent(VideoEvent.Record(simulated = false))
    vm.onEvent(VideoEvent.Heard("Máy dùng ba năm", final = false))
    assertThat(vm.state.value.caption).isEqualTo(Caption("Máy dùng ba năm", final = false))
    vm.onEvent(VideoEvent.Heard("Máy dùng ba năm, chưa sửa.", final = true))
    advanceTimeBy(5_000)
    vm.onEvent(VideoEvent.Record(simulated = false)) // stop: the camera finalizes, then says so
    assertThat(effects).isEmpty()
    vm.onEvent(VideoEvent.Recorded("content://take.mp4", millis = 5_100))
    assertThat(effects.single()).isEqualTo(
        VideoEffect.Review(RecordedVideo("content://take.mp4", seconds = 5, fromLibrary = false), "Máy dùng ba năm, chưa sửa."),
    )
}

@Test
fun theTranscriptKeepsTheLastPartialAtTheStop() = runTest {
    val vm = viewModel()
    vm.onEvent(VideoEvent.Captions(available = true))
    vm.onEvent(VideoEvent.Record(simulated = false))
    vm.onEvent(VideoEvent.Heard("Máy dùng ba năm.", final = true))
    vm.onEvent(VideoEvent.Heard("Mình bán bốn", final = false))
    vm.onEvent(VideoEvent.Heard("Mình bán bốn triệu rưỡi", final = false))
    advanceTimeBy(4_000)
    vm.onEvent(VideoEvent.Record(simulated = false))
    vm.onEvent(VideoEvent.Recorded("content://t.mp4", 4_000))
    assertThat((effects.single() as VideoEffect.Review).transcript).isEqualTo("Máy dùng ba năm. Mình bán bốn triệu rưỡi")
}

@Test
fun withoutCaptionsTheTakeSendsNoTranscript() = runTest {
    val vm = viewModel()
    vm.onEvent(VideoEvent.Captions(available = false))
    vm.onEvent(VideoEvent.Record(simulated = false))
    assertThat(vm.state.value.caption).isNull()
    assertThat(vm.state.value.captions).isFalse()
    advanceTimeBy(4_000)
    vm.onEvent(VideoEvent.Record(simulated = false))
    vm.onEvent(VideoEvent.Recorded("content://t.mp4", 4_000))
    assertThat((effects.single() as VideoEffect.Review).transcript).isNull()
}

@Test
fun theSimulatedTakeReplaysTheSamplesWords() = runTest {
    val vm = viewModel()
    vm.onEvent(VideoEvent.Record(simulated = true))
    advanceTimeBy(1_000)
    assertThat(vm.state.value.caption?.text).isEqualTo("Đây là iPhone 11 bản 64 GB màu trắng.")
    advanceTimeBy(11_000)
    vm.onEvent(VideoEvent.Record(simulated = true))
    val review = effects.single() as VideoEffect.Review
    assertThat(review.video.uri).isEqualTo(SimulatedCamera().video)
    assertThat(review.transcript).startsWith("Đây là iPhone 11")
}

@Test
fun aPickedVideoOpensReviewWithItsLength() = runTest {
    val vm = viewModel()
    vm.onEvent(VideoEvent.Library("content://v.mp4", seconds = 42))
    assertThat(effects.single()).isEqualTo(VideoEffect.Review(RecordedVideo("content://v.mp4", 42, fromLibrary = true), null))
    vm.onEvent(VideoEvent.Library(null, 0))
    assertThat(effects.last()).isEqualTo(VideoEffect.Unreadable)
}
```

`aShortTakeIsDropped`, `thirtySecondsStopsTheTake`, `closingPausesAndStayResumesWithTheTimeKept`, `leaveCloses`, `closingBeforeATakeCloses`, `flippingTheCameraTurnsTheTorchOff` stay; `cuesFollowTheTake` checks prompts only; `aLongTakeOpensReviewWithTheSimulatedFrames`, `theCamerasFramesAreSpreadOverTheTake` and `aCameraTakeWithoutFramesSaysSoInsteadOfReviewing` go (frames are the server's now). A short take stops the recorder without opening Kiểm tra: `aShortTakeIsDropped` also sends `Recorded` after the stop and expects only `TooShort`.

Run `./gradlew :feature:sell:testDebugUnitTest --tests '*VideoViewModelTest*'`. Expected: does not compile.

- [ ] **Step 2: The ViewModel**

```kotlin
/** A sentence the recognizer heard: grey while [final] is false, white once it is. */
data class Caption(val text: String, val final: Boolean)

data class VideoUiState(
    val recording: Boolean = false,
    val elapsedMillis: Long = 0,
    val prompt: String? = null,
    /** The latest sentence heard; null before the first word and on a phone without a recognizer. */
    val caption: Caption? = null,
    /** The phone hears the take; false shows only the hint all through it. */
    val captions: Boolean = true,
    val leaving: Boolean = false,
    val torch: Boolean = false,
    val front: Boolean = false,
    val camera: CameraState? = null,
    val shots: List<String> = emptyList(),
)

sealed interface VideoEvent {
    data class Record(val simulated: Boolean) : VideoEvent
    data object Close : VideoEvent
    data object Stay : VideoEvent
    data object Leave : VideoEvent
    data object Torch : VideoEvent
    data object Flip : VideoEvent
    data class Camera(val state: CameraState) : VideoEvent
    /** The camera finished writing the take. */
    data class Recorded(val uri: String, val millis: Long) : VideoEvent
    /** What the recognizer heard; a final result ends a sentence. */
    data class Heard(val text: String, val final: Boolean) : VideoEvent
    /** Whether the phone can hear the take: a recognizer and the microphone allowed. */
    data class Captions(val available: Boolean) : VideoEvent
    /** A video from the library and its length; null when it cannot be read. */
    data class Library(val uri: String?, val seconds: Int) : VideoEvent
}

sealed interface VideoEffect {
    data object TooShort : VideoEffect
    data class Review(val video: RecordedVideo, val transcript: String?) : VideoEffect
    data object Close : VideoEffect
    data object Unreadable : VideoEffect
}
```

Rules:
- `heard` holds the finals of this take; `partial` the latest partial. `Heard(final = true)` appends to `heard` and clears `partial`; `Heard(final = false)` replaces `partial`. Both set `caption`. Only while `recording`.
- `stop()`: under `MIN_TAKE_MILLIS` → `TooShort`, nothing reviewed (a `Recorded` that follows is dropped). Otherwise `recording = false` and the VM waits for `Recorded`; simulated, it reviews at once with `simulatedCamera.video`.
- The transcript is `(heard + partial).joinToString(" ").trim()`, or null when `captions` is false or it is blank.
- Simulated takes replay the fixture's CAPTION cues as `Heard(final = true)` at their times (they stand in for the recognizer); camera takes ignore CAPTION cues. CHIP cues are ignored everywhere (Task 5 drops them from the fixture).
- `CameraStandIn` gains `val video: String` (the simulated impl returns `"sample:take"`).

- [ ] **Step 3: The camera, the microphone and the recognizer**

- `libs.versions.toml`: `androidx-camera-video = { group = "androidx.camera", name = "camera-video", version.ref = "camerax" }`; `core/ui/build.gradle.kts`: `implementation(libs.androidx.camera.video)`. `core/ui/src/main/AndroidManifest.xml`: `<uses-permission android:name="android.permission.RECORD_AUDIO" />`.
- `VideoCamera(mode, recording, torch, front, shots, audio: Boolean, onState, onRecorded: (String, Long) -> Unit, modifier)`: `onFrame` goes. The camera binds `Preview` and `VideoCapture<Recorder>` (`Recorder.Builder().setQualitySelector(QualitySelector.from(Quality.HD)).build()`). `recording` true starts `recorder.prepareRecording(context, FileOutputOptions.Builder(File(cacheDir, "sell/take-<ms>.mp4")).build())`, `.withAudioEnabled()` when `audio`, `.start(main) { e -> if (e is VideoRecordEvent.Finalize && !e.hasError()) onRecorded(uri, e.recordingStats.recordedDurationNanos / 1_000_000) }`; false stops it. A finalize with an error sends nothing (the take is dropped; the VM's TooShort path or a retake covers it). Simulated, it cross-fades as today.
- `MicPermission(onAnswer: (Boolean) -> Unit)`: asks `RECORD_AUDIO` once when Quay video opens (as `CameraPermission` asks for the camera) and reports the answer; refused, the take records without sound.
- `Captions(listening: Boolean, onHeard: (String, Boolean) -> Unit, onAvailable: (Boolean) -> Unit)`: a composable effect. `SpeechRecognizer.isRecognitionAvailable(context)` and the mic answer give `onAvailable`. While `listening`, it runs `SpeechRecognizer.createSpeechRecognizer(context)` with `RecognizerIntent.ACTION_RECOGNIZE_SPEECH`, `EXTRA_LANGUAGE = "vi-VN"`, `EXTRA_PARTIAL_RESULTS = true`; `onPartialResults` sends `(text, false)`, `onResults` sends `(text, true)` and starts listening again, `onError` with `ERROR_NO_MATCH` or `ERROR_SPEECH_TIMEOUT` starts again, any other error stops for the take. `listening` false or disposal calls `destroy()`.
- `VideoLength.kt`: `suspend fun videoLength(context, uri): Int?` (seconds, `MediaMetadataRetriever.METADATA_KEY_DURATION`), replacing `videoFrames`. `FrameGrabber.kt` and `FramePace` go.

- [ ] **Step 4: The screen and the route**

- `SellReviewRoute(video: String? = null, seconds: Int = 0, fromLibrary: Boolean = false, transcript: String? = null, draftId: String? = null)`. `VideoEntry` turns `VideoEffect.Review` into `navigator.replace(SellReviewRoute(e.video.uri, e.video.seconds, e.video.fromLibrary, e.transcript))`. `HomeViewModel`'s video-draft route keeps `SellReviewRoute(draftId = …)`. `ReviewViewModel` reads `route.video` in Task 4; until then it builds its take from `route.video` as one frame so it compiles (Task 4 replaces it).
- `VideoScreen`: `Chips` goes; the caption box shows a mic icon with a dot, then `state.caption` (grey `onSurfaceVariant`-on-scrim while not final, white once final) or the hint "Nói về món đồ: dùng bao lâu, tình trạng, giá muốn bán" (`video_hint`) before the first word and all through a take without captions.

`VideoScreenTest`: `theCaptionTurnsWhiteWhenFinal` (a partial then a final caption render with the two text colours, by semantics on the caption node's `testTag("caption-final")`), `withoutCaptionsTheHintStays`, `noChipShowsDuringATake`.

- [ ] **Step 5: Run the tests**

Run `./gradlew :feature:sell:testDebugUnitTest :core:ui:testDebugUnitTest`. Expected: PASS.

- [ ] **Step 6: Gate and commit**

Gate (run `./gradlew :core:ui:dependencies` online first for `camera-video`). `git commit -m "feat(sell): Quay video records an mp4 with sound and the phone's captions"`.

### Task 4: Kiểm tra follows the read

**Files:** Modify `feature/sell/.../review/ReviewViewModel.kt`, `ReviewScreen.kt`, `ReviewSheets.kt`, strings. Tests `ReviewViewModelTest.kt`, `ReviewScreenTest.kt`.

**Interfaces:** Consumes Tasks 1 and 3. Produces `ReviewUiState.read: ListingRead?`, `ReviewEvent.PostWithPhotos`, `SellEffect.OpenPhotos` (navigates to `SellRoute()` with the empty form).

- [ ] **Step 1: Write the failing tests**

`ReviewViewModelTest`:

```kotlin
@Test
fun theReadShowsTheUploadThenFillsTheDraft() = runTest {
    val vm = viewModel(SellReviewRoute(video = "content://t.mp4", seconds = 12, transcript = "Máy dùng 3 năm."))
    assertThat(vm.state.value.read?.uploadedPercent).isEqualTo(0)
    advanceTimeBy(1_600); runCurrent()
    assertThat(vm.state.value.read?.uploadedPercent).isNull()
    advanceTimeBy(800); runCurrent()
    assertThat(vm.state.value.read?.photos).hasSize(8)
    advanceTimeBy(4_000); runCurrent()
    val s = vm.state.value
    assertThat(s.phase).isEqualTo(FormPhase.FILLED)
    assertThat(s.draft.photos).hasSize(4)
    assertThat(s.draft.video!!.frames).hasSize(8)
    assertThat(s.draft.video!!.picked).containsExactly(0, 2, 3, 4).inOrder()
    assertThat(s.draft.priceSource).isEqualTo(PriceSource.SPOKEN)
}

@Test
fun eachFailureEndsTheRead() = runTest {
    for (f in listOf(ReadFailure.UNREADABLE, ReadFailure.NO_ITEM, ReadFailure.UNAVAILABLE, ReadFailure.READ_LIMIT_REACHED)) {
        outcomes.next = f
        val vm = viewModel(SellReviewRoute(video = "content://t.mp4", seconds = 12))
        advanceUntilIdle()
        assertThat(vm.state.value.phase).isEqualTo(FormPhase.READ_FAILED)
        assertThat(vm.state.value.read?.failure).isEqualTo(f)
    }
}

@Test
fun aTooLongVideoFailsAndRecordsAgainWithoutAsking() = runTest {
    val vm = viewModel(SellReviewRoute(video = "content://v.mp4", seconds = 42, fromLibrary = true))
    advanceUntilIdle()
    assertThat(vm.state.value.read?.failure).isEqualTo(ReadFailure.VIDEO_TOO_LONG)
    vm.onEvent(ReviewEvent.RecordAgain)
    assertThat(vm.state.value.dialog).isNull()
    assertThat(effects.last()).isEqualTo(SellEffect.RecordAgain)
}

@Test
fun anUnavailableReadIsRetriedAndANoItemOneGoesToPhotos() = runTest {
    outcomes.next = ReadFailure.UNAVAILABLE
    val vm = viewModel(SellReviewRoute(video = "content://t.mp4", seconds = 12))
    advanceUntilIdle()
    vm.onEvent(ReviewEvent.RetryRead); advanceUntilIdle()
    assertThat(vm.state.value.phase).isEqualTo(FormPhase.FILLED)
    outcomes.next = ReadFailure.NO_ITEM
    val other = viewModel(SellReviewRoute(video = "content://t.mp4", seconds = 12))
    advanceUntilIdle()
    other.onEvent(ReviewEvent.PostWithPhotos)
    assertThat(effects.last()).isEqualTo(SellEffect.OpenPhotos)
}

@Test
fun aRestoredReadingReadsTheVideoAgain() = runTest {
    val handle = SavedStateHandle()
    viewModel(SellReviewRoute(video = "content://t.mp4", seconds = 12), handle)
    advanceTimeBy(1_000)
    val second = viewModel(SellReviewRoute(video = "content://t.mp4", seconds = 12), handle.copy())
    advanceUntilIdle()
    assertThat(second.state.value.phase).isEqualTo(FormPhase.FILLED)
    assertThat(second.state.value.draft.photos).hasSize(4)
}
```

Keep the existing tests that do not concern the read (sheets, sparkle, frames picker, gates, close and save); `aFailedReadCanBeRetried` and `theReadingFillsTheDraft` become the two first tests above. `PlayVideo` and `playing` go with their tests.

`ReviewScreenTest`: `theUploadShowsItsShare` ("Đang tải video lên" and "40%"), `framesFillTheStripWithoutWords` (no "AI" text, eight frame nodes, the kept ones tagged `frame-kept`), `eachFailureHasItsPane` (every `ReadFailure` but `LISTING_NOT_FOUND` renders its title and buttons from the Global Constraints), `theSpokenPriceIsLabelled` ("Giá bạn nói" above a SPOKEN price, absent on TYPED), `noVideoTile` (no node with content description "Phát video").

Run `./gradlew :feature:sell:testDebugUnitTest --tests '*Review*'`. Expected: FAIL.

- [ ] **Step 2: The ViewModel**

- `ReviewUiState.reading: VideoReading?` becomes `read: ListingRead?`; `ReviewLocal` likewise, saved with `ListingRead.serializer()`; `take: VideoTake?` becomes `video: RecordedVideo?` (from the route) and `transcript: String?`.
- `startRead()` collects `sell.readVideo(video, transcript)`: every emission sets `read`; `DONE` sets `phase = FILLED` and `draft = draftOf(read)`; `FAILED` sets `phase = READ_FAILED`.

```kotlin
/** The draft a done video read opens: its kept frames as photos, every frame for "Khung hình", the spoken price. */
private fun draftOf(r: ListingRead, id: DraftId, video: RecordedVideo): ListingDraft {
    val d = checkNotNull(r.draft)
    val frames = r.photos.orEmpty()
    val kept = d.photos.mapNotNull { up -> frames.indexOfFirst { it.uploadId == up }.takeIf { it >= 0 } }
    val source = if (video.fromLibrary) PhotoSource.LIBRARY else PhotoSource.APP
    val asPhotos = frames.map { Photo(it.url, source) }
    return ListingDraft(id, DraftOrigin.VIDEO, photos = kept.map { asPhotos[it] },
        video = VideoTake(asPhotos, kept, video.seconds, video.fromLibrary),
        aiFields = setOf(DraftField.TITLE, DraftField.CATEGORY, DraftField.CONDITION, DraftField.SPECS, DraftField.DESCRIPTION, DraftField.OFFERS),
    ).withRead(r).copy(price = d.price, priceSource = if (d.price != null) PriceSource.SPOKEN else PriceSource.TYPED, allowOffers = d.allowOffers, readCover = null)
}
```

- `RecordAgain` in READ_FAILED, or while READING, goes to the camera without asking (nothing to keep). `RetryRead` reads the same video again. `PostWithPhotos` sends `SellEffect.OpenPhotos`; `ReviewEntry` maps it to `navigator.replace(SellRoute())`.

- [ ] **Step 3: The screen**

- Reading: the stage (the frame shown under the scan line, or the first sample shot until frames arrive) with the `LoadingIndicator`; under it, while `read.uploadedPercent != null`, a row with the upload icon, "Đang tải video lên" (`review_uploading`), the share in percent and a `LinearProgressIndicator`; then the strip of `read.photos` (up to 8), the frames in `draft.photos`' order ringed once the draft lands. The findings list, `review_reading` and the "AI chọn …" text on the stage go.
- READ_FAILED: one `ReadFailedPane(failure)` with the art, title, body and buttons from the Global Constraints, primary first (`Thử lại` → `RetryRead`, `Quay lại` → `RecordAgain`, `Đăng bằng ảnh` → `PostWithPhotos`). Arts: `art_offline` for UPLOAD_FAILED, `art_ai_camera` for the two lengths, `art_not_found` for NO_ITEM and UNREADABLE, `art_ai_reading` for UNAVAILABLE and READ_LIMIT_REACHED (the `Art` names the app has; check `core/designsystem`).
- Filled: the photo row loses `VideoTile`; "Giá bạn nói" (`review_spoken_price`, with the mic symbol) sits over the price when `draft.priceSource == SPOKEN`.

- [ ] **Step 4: Run, gate and commit**

`./gradlew :feature:sell:testDebugUnitTest`, then the gate. `git commit -m "feat(sell): Kiểm tra shows the upload, the frames and one pane per failure"`.

### Task 5: The old reads go

**Files:** `core/model/.../Selling.kt` (`PhotoReading`, `VideoReading`, `Finding`, `CueKind.CHIP` and `CAPTION`'s doc), `Repositories.kt` (`readPhotos`, `readVideo(VideoTake)`), `FakeSellRepository.kt`, `Seeds.kt` (`photoReading` becomes `photoSuggestions` and `photoMarket`; `video.findings` goes), `fixtures/sell.json` (the same keys; `cues` loses its CHIP entries), `FakeSellRepositoryTest.kt`, and every remaining reference (`grep -rn "PhotoReading\|VideoReading\|readPhotos\|Finding\b\|CueKind.CHIP" --include=*.kt .`).

- [ ] **Step 1: Delete, then fix what stops compiling**

The fake's `readPhoto` and `readVideo` read `seed.photoSuggestions` and `seed.photoMarket`. Tests that named the old reads are deleted or moved to the new ones (`theVideoReadFollowsTheTimeline` and `aShortTakeKeepsTheFramesItHas` go; `thePhotoReadingSuggestsNoMark` and `aSpokenScratchStaysInTheDescriptionOnly` assert on `readPhoto` and `readVideo`).

- [ ] **Step 2: Gate and commit**

`grep` prints nothing; gate. `git commit -m "feat(sell): PhotoReading and VideoReading give way to ListingRead"`.

### Task 6: The walk and the gate

- [ ] **Step 1:** On the emulator (`./run.sh`), walk: Đăng tin with three photos (the cover reads, change the cover, "Điền lại theo ảnh này"); Quay video simulated (captions appear, Kiểm tra uploads, frames, draft); with the debug panel's "Lần đọc tới" set to each failure, its pane and buttons. Screenshots to `~/shopnexus/app/tmp/listing-reads/`.
- [ ] **Step 2:** Gate on the worktree; `README.md`'s Fake data paragraph gains one sentence: "Kiểm tra and the photo read play the server's steps; the debug panel's "Lần đọc tới" makes the next read fail with any code." Commit `docs: the fake listing reads in README.md`.

---

## Self-review

- Spec "App" section: mp4 with sound (Task 3), `SpeechRecognizer` and transcript (Task 3), one `ListingRead` (Tasks 1, 5), the cover read and "Điền lại" (Task 2), fakes playing the server's steps and failures (Task 1). All covered.
- Decisions from the conversation: no live AI chips (Task 3), hint without captions and no "AI sẽ nghe lại" (Task 3), photo description of what the photo shows (Task 1 seed), no video tile (Task 4), no narration (Tasks 2–4), failure panes per code (Task 4).
- Names: `withRead`, `readCover`, `ReadOutcomes.next`, `VideoEvent.Recorded/Heard/Captions`, `VideoEffect.Review(video, transcript)`, `SellReviewRoute(video, seconds, fromLibrary, transcript, draftId)` are used with the same shapes in every task that consumes them.
- Review Focus: each line has its test in the task that owns the code.
