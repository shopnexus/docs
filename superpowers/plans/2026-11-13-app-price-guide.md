# app price guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The "Giá" step and Kiểm tra's price step read the market from a `PriceGuide` the app asks for by the draft's content, shaped as `POST /v1/price-guides` answers, in place of the `MarketRead` and `suggestions` the fake read carried.

**Architecture:** `core/model` gets `PriceGuide` and loses `MarketRead`, `SoldBin`, `PriceFactor`, `PhotoShot`; `ListingRead` loses `suggestions` and `market`, `ListingDraft` loses `suggestions`. `core/data` gets `PricingRepository` and its fake. `feature/sell` gets `PriceGuideHolder`, which both view models use to keep a guide for the draft on screen, and pure helpers for days, waiting buyers, the axis and the bins. The leftovers the server will not answer (factors, shots, photo tip, offer gap, similar tip, km on the market) leave the UI.

**Tech Stack:** Kotlin, Jetpack Compose, Hilt, kotlinx.serialization, coroutines/Flow, Robolectric + Roborazzi tests, Truth, Turbine.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-13-price-guide-design.md` (section "App"). The server side is `2026-11-13-server-price-guide.md`; this plan does not wait for it: the app still runs on fakes.

Repo: `~/shopnexus/app`. `export JAVA_HOME=$HOME/.local/opt/jdk-21` before any
`./gradlew` call. Tests: `./gradlew --console=plain -q :<module>:testDebugUnitTest`
(`:core:model:test` for the pure module). Screenshots:
`:<module>:verifyRoborazziDebug`, re-record with
`:<module>:recordRoborazziDebug --tests '<Class>'`. Static:
`./gradlew -q spotlessCheck detekt` and `:feature:sell:lintDebug`. Test only
the modules a task touches. After Gradle work, stop the Gradle and Kotlin
daemons (`./gradlew --stop; pkill -f KotlinCompileDaemon`) and check with
`pgrep -f 'GradleDaemon|KotlinCompileDaemon'` that none is left. Commits carry
no `Co-Authored-By` line.

## Global Constraints

- The UI shows only what the guide (or the read's range) holds; nothing the server will not answer stays on screen, and no screen narrates AI steps.
- Suggestions have `days: Int`; the UI says "~N ngày" under 7 days and "~N tuần" from 7 (`days / 7`).
- Waiting buyers are counted in the app from `watchers`: a row counts when its `priceMin`/`priceMax` hold the price (no price: every row) and, when `offersOnly`, offers are on.
- The guide is asked for again only when the draft's title (trimmed, lowercased), category, condition or cover changes, 600 ms after the last change; a failed ask keeps the last guide. No title, category or condition: no guide.
- "Giá tham khảo" shows the guide's estimate, or the draft's `estimate` (the read's range, kept on the draft) until a guide arrives.
- Copy is Vietnamese and generic to any item: no "máy", "pin" or "dung lượng" in the market's lines.
- The draft body stays readable: old drafts with `suggestions` decode (`ignoreUnknownKeys`).

## Review Focus

- The seller clears the title or the category after a guide arrived: the guide goes (no stale similar listings for another item). Pinned in Task 2.
- The fake guide fails (FailurePolicy rate) while the seller types: the last guide stays and nothing flickers to empty. Pinned in Task 2.
- A price typed far outside every sample price: the strip's axis widens to hold it and the pin stays on the strip. Pinned in Task 2.
- A guide with an estimate but no suggestions (under 3 sales): "Giá tham khảo" and the strip show, the two panels do not, and the verdict line falls back to "~2 tuần" / "hơn 3 tuần". Pinned in Task 3.
- A reopened draft saved by an older build with `"suggestions": [{"days": "~2 ngày"}]`: it opens. Pinned in Task 1.

---

### Task 1: `PriceGuide` in the model, `PricingRepository` and its fake

**Files:**
- Modify: `core/model/src/main/kotlin/vn/shopnexus/core/model/Selling.kt`
- Create: `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/FakePricingRepository.kt`
- Modify: `core/data/src/main/kotlin/vn/shopnexus/core/data/Repositories.kt` (interface)
- Modify: `core/data/src/main/kotlin/vn/shopnexus/core/data/di/DataModule.kt` (binding)
- Modify: `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/Seeds.kt` (`SellSeed.priceGuide`)
- Modify: `core/data/src/main/resources/fixtures/sell.json`
- Test: `core/data/src/test/kotlin/vn/shopnexus/core/data/fake/FakePricingRepositoryTest.kt`, `core/model/src/test/kotlin/vn/shopnexus/core/model/DraftCompatTest.kt`

This task only adds. `MarketRead` and the old fields go in Task 3, when
nothing reads them.

**Interfaces:**
- Produces (in `vn.shopnexus.core.model`):
  - `PriceGuide(estimate: ReadEstimate?, suggestions: List<PriceGuideSuggestion>, similar: List<GuideListing>, soldPrices: List<Vnd>, livePrices: List<Vnd>, watchers: List<Watcher>)`
  - `PriceGuideSuggestion(kind: SuggestionKind, price: Vnd, days: Int)`
  - `GuideListing(id: String, title: String, coverUrl: String, price: Vnd, condition: Condition, sold: Boolean, km: Int, daysToSell: Int? = null)`
  - `Watcher(priceMin: Vnd? = null, priceMax: Vnd? = null, offersOnly: Boolean = false)`
  - `PriceInput(title: String, category: CategoryRef, condition: Condition, specs: List<Spec>, description: String, photos: List<Photo>)`
- Produces (in `vn.shopnexus.core.data`): `interface PricingRepository { suspend fun guide(input: PriceInput): Result<PriceGuide> }`

The new names `PriceGuideSuggestion` and `GuideListing` live beside the old
`PriceSuggestion` and `SimilarListing` until Task 3 deletes those and
renames these two back (`PriceSuggestion`, `SimilarListing`) in one move.

- [ ] **Step 1: Write the fake's test**

`core/data/src/test/kotlin/vn/shopnexus/core/data/fake/FakePricingRepositoryTest.kt`:

```kotlin
package vn.shopnexus.core.data.fake

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import vn.shopnexus.core.model.CategoryRef
import vn.shopnexus.core.model.Condition
import vn.shopnexus.core.model.EstimateSource
import vn.shopnexus.core.model.Photo
import vn.shopnexus.core.model.PhotoSource
import vn.shopnexus.core.model.PriceInput
import vn.shopnexus.core.model.SuggestionKind
import vn.shopnexus.core.model.Vnd

class FakePricingRepositoryTest {
    private val failures = FailurePolicy(latencyMillis = 0)
    private val pricing = FakePricingRepository(failures)
    private val iphone = PriceInput(
        "iPhone 11 64GB Trắng", CategoryRef("phones", "iPhone"), Condition.USED, emptyList(), "",
        listOf(Photo("https://x/p.jpg", PhotoSource.APP)),
    )

    /** A phone gets the sample market: the range, both suggestions, six listings and the watchers. */
    @Test
    fun aPhoneGetsTheSampleMarket() = runTest {
        val g = pricing.guide(iphone).getOrThrow()
        assertThat(g.estimate!!.source).isEqualTo(EstimateSource.MARKET)
        assertThat(g.estimate!!.median).isEqualTo(Vnd(4_800_000))
        assertThat(g.suggestions.map { it.kind }).containsExactly(SuggestionKind.FAST, SuggestionKind.MARKET).inOrder()
        assertThat(g.suggestions.map { it.days }).containsExactly(2, 7).inOrder()
        assertThat(g.similar).hasSize(6)
        assertThat(g.soldPrices).hasSize(18)
        assertThat(g.livePrices).hasSize(12)
        assertThat(g.watchers).hasSize(23)
    }

    /** Anything else has no similar listings, so no range, and nobody watching. */
    @Test
    fun anythingElseGetsAnEmptyGuide() = runTest {
        val g = pricing.guide(iphone.copy(category = CategoryRef("vehicles", "Xe đạp"))).getOrThrow()
        assertThat(g.estimate).isNull()
        assertThat(g.suggestions).isEmpty()
        assertThat(g.similar).isEmpty()
        assertThat(g.watchers).isEmpty()
    }

    @Test
    fun aFailureIsAFailure() = runTest {
        failures.rate = 1.0
        assertThat(pricing.guide(iphone).isFailure).isTrue()
    }
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `./gradlew --console=plain -q :core:data:testDebugUnitTest --tests '*FakePricingRepositoryTest'`
Expected: compile error, `Unresolved reference: FakePricingRepository`.

- [ ] **Step 3: Add the model types**

Append to `core/model/src/main/kotlin/vn/shopnexus/core/model/Selling.kt`:

```kotlin
/** "Bán nhanh" or "Giá thị trường": a price and the median whole days a sale at it took. */
@Serializable data class PriceGuideSuggestion(val kind: SuggestionKind, val price: Vnd, val days: Int)

/** A listing like the seller's: on sale or sold, [km] from the seller's commune, and for a sold one the days its sale took. */
@Serializable
data class GuideListing(
    val id: String,
    val title: String,
    val coverUrl: String,
    val price: Vnd,
    val condition: Condition,
    val sold: Boolean,
    val km: Int,
    val daysToSell: Int? = null,
)

/** A buyer's search watch a listing of the draft would match: its price bounds and whether it wants offers. Nothing names the buyer. */
@Serializable data class Watcher(val priceMin: Vnd? = null, val priceMax: Vnd? = null, val offersOnly: Boolean = false)

/**
 * The market for a draft, as `POST /v1/price-guides` answers: the range (null under 5 similar listings), the two
 * suggestions (none under 3 sales), the most similar listings, the sample's sold and on-sale prices ascending, and the
 * watches it would match.
 */
@Serializable
data class PriceGuide(
    val estimate: ReadEstimate?,
    val suggestions: List<PriceGuideSuggestion>,
    val similar: List<GuideListing>,
    val soldPrices: List<Vnd>,
    val livePrices: List<Vnd>,
    val watchers: List<Watcher>,
)

/** What a guide prices: the draft's fields that price an item, and its first three photos, the cover first. */
@Serializable
data class PriceInput(
    val title: String,
    val category: CategoryRef,
    val condition: Condition,
    val specs: List<Spec>,
    val description: String,
    val photos: List<Photo>,
)
```

- [ ] **Step 4: Add the repository and its fake**

In `Repositories.kt`, beside `SellRepository`:

```kotlin
/** The "Giá" step's market for a draft, as `POST /v1/price-guides`; the server finds the seller's commune itself. */
interface PricingRepository {
    suspend fun guide(input: PriceInput): Result<PriceGuide>
}
```

`core/data/src/main/kotlin/vn/shopnexus/core/data/fake/FakePricingRepository.kt`:

```kotlin
package vn.shopnexus.core.data.fake

import javax.inject.Inject
import vn.shopnexus.core.data.PricingRepository
import vn.shopnexus.core.model.PriceGuide
import vn.shopnexus.core.model.PriceInput

/** The fixture market for a phone, the sample item; any other category has no similar listings and nobody watching. */
class FakePricingRepository @Inject constructor(private val failures: FailurePolicy) : PricingRepository {
    private val seed = Fixtures.sell().priceGuide

    override suspend fun guide(input: PriceInput): Result<PriceGuide> = failures.run {
        if (input.category.key == PHONES) seed else EMPTY
    }

    private companion object {
        const val PHONES = "phones"
        val EMPTY = PriceGuide(null, emptyList(), emptyList(), emptyList(), emptyList(), emptyList())
    }
}
```

`DataModule.kt`, beside `sell`:

```kotlin
    @Binds abstract fun pricing(impl: FakePricingRepository): PricingRepository
```

`Seeds.kt`, in `SellSeed`, add the field (keep `photoSuggestions` and
`photoMarket` until Task 3):

```kotlin
    /** The guide a phone draft gets: the market the sample iPhone sells in. */
    val priceGuide: PriceGuide,
```

- [ ] **Step 5: Add the fixture**

Run from the repo root (a scratch script in `tmp/`, not committed):

```bash
mkdir -p tmp && cat > tmp/guide_fixture.py <<'EOF'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
m = d["photoMarket"]
def km(where):
    return round(float(where.replace(" km", "").replace(",", ".")))
similar = []
for i, s in enumerate(m["similar"]):
    x = {"id": s["id"], "title": s["title"], "coverUrl": s["photoUrl"], "price": s["price"],
         "condition": s["condition"], "sold": s["sold"]}
    if s["sold"]:
        x["km"] = 2 + i
        x["daysToSell"] = int(s["where"].split()[0])
    else:
        x["km"] = km(s["where"])
    similar.append(x)
sold = []
for b in m["bins"]:
    sold += [b["from"] + 100_000] * b["count"]
watchers = [{"offersOnly": i < 3} for i in range(12)]
watchers += [{"priceMax": 5_000_000} for _ in range(6)]
watchers += [{"priceMax": 4_500_000} for _ in range(5)]
d["priceGuide"] = {
    "estimate": {"low": 4_400_000, "median": 4_800_000, "high": 5_100_000, "source": "MARKET", "sampleSize": 30},
    "suggestions": [{"kind": "FAST", "price": 4_500_000, "days": 2}, {"kind": "MARKET", "price": 4_800_000, "days": 7}],
    "similar": similar,
    "soldPrices": sorted(sold),
    "livePrices": sorted(m["livePrices"]),
    "watchers": watchers,
}
json.dump(d, open(path, "w"), ensure_ascii=False, indent=2)
open(path, "a").write("\n")
EOF
python3 -I tmp/guide_fixture.py core/data/src/main/resources/fixtures/sell.json
git diff --stat core/data/src/main/resources/fixtures/sell.json
```

Check the diff adds `priceGuide` and reformats nothing else; if the file
used another indent, rerun with that `indent`. Twelve watchers have no
bound (three of them offers only), six stop at 5.000.000 and five at
4.500.000: at 4.650.000 with offers on, 18 count.

- [ ] **Step 6: Pin old drafts**

`core/model/src/test/kotlin/vn/shopnexus/core/model/DraftCompatTest.kt`:

```kotlin
package vn.shopnexus.core.model

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class DraftCompatTest {
    /** A draft body an older build wrote, with its suggestions' days as words, still opens. */
    @Test
    fun anOldDraftStillDecodes() {
        val body = """{"id":"dr-1","origin":"PHOTOS","title":"iPhone 11",
            "suggestions":[{"kind":"FAST","price":4500000,"days":"~2 ngày"}]}"""
        val d = ShopNexusJson.decodeFromString(ListingDraft.serializer(), body)
        assertThat(d.title).isEqualTo("iPhone 11")
    }
}
```

`ShopNexusJson` is in this package (`Time.kt`). The test passes today,
when `days` is a `String`, and stays here so Task 3, which removes the
field, has to keep it green.

- [ ] **Step 7: Run the tests**

Run: `./gradlew --console=plain -q :core:model:test :core:data:testDebugUnitTest`
Expected: PASS, the fixture tests (`FixturesTest`, `Stage4FixturesTest`) included.

- [ ] **Step 8: Commit**

```bash
git add core/model core/data
git commit -m "feat(data): PriceGuide and a fake PricingRepository, shaped as POST /v1/price-guides"
```

---

### Task 2: `PriceGuideHolder` and the pure helpers of the market

**Files:**
- Create: `feature/sell/src/main/kotlin/vn/shopnexus/feature/sell/form/PriceGuideHolder.kt`
- Create: `feature/sell/src/main/kotlin/vn/shopnexus/feature/sell/parts/Guide.kt` (pure functions)
- Test: `feature/sell/src/test/kotlin/vn/shopnexus/feature/sell/form/PriceGuideHolderTest.kt`, `feature/sell/src/test/kotlin/vn/shopnexus/feature/sell/parts/GuideTest.kt`

**Interfaces:**
- Consumes: Task 1's types and `PricingRepository`.
- Produces:
  - `fun ListingDraft.priceInput(): PriceInput?` (null without title, category or condition)
  - `fun daysLabel(days: Int): String`
  - `fun waitingAt(price: Vnd?, offers: Boolean, watchers: List<Watcher>): Int`
  - `fun guideAxis(range: PriceRange, guide: PriceGuide?, price: Vnd?): Pair<Vnd, Vnd>`
  - `fun soldBins(prices: List<Vnd>, low: Vnd, high: Vnd, count: Int = 8): List<Int>`
  - `class PriceGuideHolder(scope: CoroutineScope, drafts: Flow<ListingDraft>, pricing: PricingRepository) { val guide: StateFlow<PriceGuide?> }`

- [ ] **Step 1: Write the helpers' tests**

`feature/sell/src/test/kotlin/vn/shopnexus/feature/sell/parts/GuideTest.kt`:

```kotlin
package vn.shopnexus.feature.sell.parts

import com.google.common.truth.Truth.assertThat
import org.junit.Test
import vn.shopnexus.core.model.CategoryRef
import vn.shopnexus.core.model.Condition
import vn.shopnexus.core.model.DraftId
import vn.shopnexus.core.model.DraftOrigin
import vn.shopnexus.core.model.ListingDraft
import vn.shopnexus.core.model.Photo
import vn.shopnexus.core.model.PhotoSource
import vn.shopnexus.core.model.PriceGuide
import vn.shopnexus.core.model.PriceRange
import vn.shopnexus.core.model.Spec
import vn.shopnexus.core.model.Vnd
import vn.shopnexus.core.model.Watcher

class GuideTest {
    @Test
    fun daysSayDaysThenWeeks() {
        assertThat(listOf(1, 2, 6, 7, 13, 14, 30).map(::daysLabel))
            .containsExactly("~1 ngày", "~2 ngày", "~6 ngày", "~1 tuần", "~1 tuần", "~2 tuần", "~4 tuần").inOrder()
    }

    @Test
    fun watchersCountAtThePriceAndTheOffersSwitch() {
        val w = listOf(
            Watcher(),
            Watcher(offersOnly = true),
            Watcher(priceMax = Vnd(5_000_000)),
            Watcher(priceMin = Vnd(4_700_000)),
            Watcher(priceMax = Vnd(4_500_000)),
        )
        assertThat(waitingAt(Vnd(4_650_000), offers = true, w)).isEqualTo(3)
        assertThat(waitingAt(Vnd(4_650_000), offers = false, w)).isEqualTo(2)
        assertThat(waitingAt(Vnd(4_800_000), offers = true, w)).isEqualTo(4)
        assertThat(waitingAt(null, offers = true, w)).isEqualTo(5)
        assertThat(waitingAt(Vnd(4_650_000), offers = true, emptyList())).isEqualTo(0)
    }

    private val range = PriceRange(Vnd(4_400_000), Vnd(4_800_000), Vnd(5_100_000))
    private val guide = PriceGuide(
        null, emptyList(), emptyList(), soldPrices = listOf(Vnd(4_100_000), Vnd(5_300_000)),
        livePrices = listOf(Vnd(4_400_000), Vnd(5_500_000)), watchers = emptyList(),
    )

    /** The axis holds every sample price and the range, on whole 100.000 ₫; a price beyond it widens it. */
    @Test
    fun theAxisHoldsTheSampleAndThePrice() {
        assertThat(guideAxis(range, guide, null)).isEqualTo(Vnd(4_100_000) to Vnd(5_500_000))
        assertThat(guideAxis(range, guide, Vnd(7_000_000)).second).isAtLeast(Vnd(7_000_000))
        assertThat(guideAxis(range, null, null)).isEqualTo(vn.shopnexus.core.designsystem.component.priceAxis(range, null))
    }

    @Test
    fun soldPricesFallIntoBins() {
        val prices = listOf(4_000_000L, 4_050_000, 4_250_000, 5_599_999, 5_600_000).map(::Vnd)
        assertThat(soldBins(prices, Vnd(4_000_000), Vnd(5_600_000), count = 8)).containsExactly(2, 1, 0, 0, 0, 0, 0, 2).inOrder()
    }

    private val photo = Photo("https://x/0.jpg", PhotoSource.APP)
    private val draft = ListingDraft(
        DraftId("dr-1"), DraftOrigin.PHOTOS, photos = List(4) { photo.copy(url = "https://x/$it.jpg") },
        title = " iPhone 11 ", category = CategoryRef("phones", "iPhone"), condition = Condition.USED,
        storage = "64 GB", color = "Trắng", battery = 89, description = "Máy zin",
    )

    @Test
    fun aDraftPricesWithItsSpecsAndThreePhotos() {
        val input = draft.priceInput()!!
        assertThat(input.title).isEqualTo("iPhone 11")
        assertThat(input.specs).containsExactly(Spec("Dung lượng", "64 GB"), Spec("Màu", "Trắng"), Spec("Pin", "89%")).inOrder()
        assertThat(input.photos.map { it.url }).containsExactly("https://x/0.jpg", "https://x/1.jpg", "https://x/2.jpg").inOrder()
    }

    @Test
    fun aDraftWithoutTitleCategoryOrConditionPricesNothing() {
        assertThat(draft.copy(title = " ").priceInput()).isNull()
        assertThat(draft.copy(category = null).priceInput()).isNull()
        assertThat(draft.copy(condition = null).priceInput()).isNull()
    }
}
```

- [ ] **Step 2: Write the holder's test**

`feature/sell/src/test/kotlin/vn/shopnexus/feature/sell/form/PriceGuideHolderTest.kt`:

```kotlin
package vn.shopnexus.feature.sell.form

import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Test
import vn.shopnexus.core.data.PricingRepository
import vn.shopnexus.core.model.CategoryRef
import vn.shopnexus.core.model.Condition
import vn.shopnexus.core.model.DraftId
import vn.shopnexus.core.model.DraftOrigin
import vn.shopnexus.core.model.ListingDraft
import vn.shopnexus.core.model.PriceGuide
import vn.shopnexus.core.model.PriceInput
import vn.shopnexus.core.model.Vnd

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class PriceGuideHolderTest {
    private class Pricing : PricingRepository {
        val asked = mutableListOf<PriceInput>()
        var fail = false

        override suspend fun guide(input: PriceInput): Result<PriceGuide> {
            asked += input
            return if (fail) Result.failure(RuntimeException("down")) else Result.success(guideFor(input.title))
        }
    }

    private companion object {
        fun guideFor(title: String) = PriceGuide(null, emptyList(), emptyList(), listOf(Vnd(title.length * 100_000L)), emptyList(), emptyList())
    }

    private val start = ListingDraft(
        DraftId("dr-1"), DraftOrigin.PHOTOS, title = "iPhone 11", category = CategoryRef("phones", "iPhone"), condition = Condition.USED,
    )

    @Test
    fun asksOncePerChangeAfterTheTypingStops() = runTest {
        val drafts = MutableStateFlow(start)
        val pricing = Pricing()
        val holder = PriceGuideHolder(backgroundScope, drafts, pricing)
        runCurrent()
        advanceTimeBy(599)
        runCurrent()
        assertThat(pricing.asked).isEmpty()
        advanceTimeBy(1)
        runCurrent()
        assertThat(pricing.asked).hasSize(1)
        assertThat(holder.guide.value).isEqualTo(guideFor("iPhone 11"))

        // The description and the price do not price the item: no new ask.
        drafts.value = start.copy(description = "Máy zin", price = Vnd(4_500_000))
        advanceTimeBy(1_000)
        runCurrent()
        assertThat(pricing.asked).hasSize(1)

        // Typing the title asks once, after the last key.
        drafts.value = start.copy(title = "iPhone 11 6")
        advanceTimeBy(300)
        drafts.value = start.copy(title = "iPhone 11 64GB")
        advanceTimeBy(600)
        runCurrent()
        assertThat(pricing.asked.map { it.title }).containsExactly("iPhone 11", "iPhone 11 64GB").inOrder()
    }

    @Test
    fun aFailureKeepsTheLastGuide() = runTest {
        val drafts = MutableStateFlow(start)
        val pricing = Pricing()
        val holder = PriceGuideHolder(backgroundScope, drafts, pricing)
        advanceTimeBy(600)
        runCurrent()
        pricing.fail = true
        drafts.value = start.copy(title = "iPhone 12")
        advanceTimeBy(600)
        runCurrent()
        assertThat(holder.guide.value).isEqualTo(guideFor("iPhone 11"))
    }

    @Test
    fun noTitleNoGuide() = runTest {
        val drafts = MutableStateFlow(start)
        val holder = PriceGuideHolder(backgroundScope, drafts, Pricing())
        advanceTimeBy(600)
        runCurrent()
        assertThat(holder.guide.value).isNotNull()
        drafts.value = start.copy(title = "")
        advanceTimeBy(600)
        runCurrent()
        assertThat(holder.guide.value).isNull()
    }
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `./gradlew --console=plain -q :feature:sell:testDebugUnitTest --tests '*GuideTest' --tests '*PriceGuideHolderTest'`
Expected: compile errors on `daysLabel`, `PriceGuideHolder`.

- [ ] **Step 4: Write the helpers**

`feature/sell/src/main/kotlin/vn/shopnexus/feature/sell/parts/Guide.kt`:

```kotlin
package vn.shopnexus.feature.sell.parts

import vn.shopnexus.core.designsystem.component.priceAxis
import vn.shopnexus.core.model.ListingDraft
import vn.shopnexus.core.model.PriceGuide
import vn.shopnexus.core.model.PriceInput
import vn.shopnexus.core.model.PriceRange
import vn.shopnexus.core.model.Spec
import vn.shopnexus.core.model.Vnd
import vn.shopnexus.core.model.Watcher

private const val WEEK = 7
private const val AXIS_STEP = 100_000L
private const val GUIDE_PHOTOS = 3

/** How long a sale took, as the panels and the verdict say it: "~2 ngày", then "~1 tuần" from seven days. */
fun daysLabel(days: Int): String = if (days < WEEK) "~$days ngày" else "~${days / WEEK} tuần"

/** The watchers whose price bounds hold [price] (every one without a price) and whose offers wish [offers] meets. */
fun waitingAt(price: Vnd?, offers: Boolean, watchers: List<Watcher>): Int = watchers.count { w ->
    (offers || !w.offersOnly) &&
        (price == null || ((w.priceMin == null || price >= w.priceMin) && (w.priceMax == null || price <= w.priceMax)))
}

/**
 * The strip's ends: every sample price and the range, widened to [price], on whole 100.000 ₫. Without sample prices,
 * the range padded as the strip pads it.
 */
fun guideAxis(range: PriceRange, guide: PriceGuide?, price: Vnd?): Pair<Vnd, Vnd> {
    val prices = guide?.let { it.soldPrices + it.livePrices }.orEmpty()
    if (prices.isEmpty()) return priceAxis(range, price)
    val all = prices + listOfNotNull(range.low, range.high, price)
    val low = all.minOf { it.amount } / AXIS_STEP * AXIS_STEP
    val high = (all.maxOf { it.amount } + AXIS_STEP - 1) / AXIS_STEP * AXIS_STEP
    return Vnd(low) to Vnd(high)
}

/** How many of [prices] fall in each of [count] equal bins from [low] to [high]; the top end falls in the last bin. */
fun soldBins(prices: List<Vnd>, low: Vnd, high: Vnd, count: Int = 8): List<Int> {
    val bins = IntArray(count)
    val width = (high.amount - low.amount).coerceAtLeast(1)
    prices.forEach { p ->
        val i = ((p.amount - low.amount) * count / width).toInt().coerceIn(0, count - 1)
        bins[i]++
    }
    return bins.toList()
}

/** What a guide prices from this draft; null until it has a title, a category and a condition. */
fun ListingDraft.priceInput(): PriceInput? {
    val category = category ?: return null
    val condition = condition ?: return null
    val title = title.trim().takeIf { it.isNotEmpty() } ?: return null
    val specs = listOfNotNull(
        storage?.takeIf { it.isNotBlank() }?.let { Spec("Dung lượng", it) },
        color.takeIf { it.isNotBlank() }?.let { Spec("Màu", it) },
        battery?.let { Spec("Pin", "$it%") },
    )
    return PriceInput(title, category, condition, specs, description.trim(), photos.take(GUIDE_PHOTOS))
}
```

Check `Vnd` compares with `>=` (it is `Comparable<Vnd>`), and that
`ListingDraft.color` is a non-null `String` and `battery` an `Int?` as in
`Draft.kt`; adjust the null checks to the real types.

- [ ] **Step 5: Write the holder**

`feature/sell/src/main/kotlin/vn/shopnexus/feature/sell/form/PriceGuideHolder.kt`:

```kotlin
package vn.shopnexus.feature.sell.form

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.transformLatest
import vn.shopnexus.core.data.PricingRepository
import vn.shopnexus.core.model.ListingDraft
import vn.shopnexus.core.model.PriceGuide
import vn.shopnexus.feature.sell.parts.priceInput

/** How long the draft must stay still before its guide is asked for. */
private const val GUIDE_DEBOUNCE_MILLIS = 600L

/**
 * The market for the draft on screen. It asks [pricing] again when what prices the item changes (the title as typed,
 * the category, the condition, the cover), once the draft has been still for 600 ms. A failed ask keeps the guide it
 * had; a draft that cannot be priced has none.
 */
@OptIn(FlowPreview::class, ExperimentalCoroutinesApi::class)
class PriceGuideHolder(scope: CoroutineScope, drafts: Flow<ListingDraft>, private val pricing: PricingRepository) {
    val guide: StateFlow<PriceGuide?> = drafts
        .distinctUntilChangedBy { it.priceKey() }
        .debounce(GUIDE_DEBOUNCE_MILLIS)
        .transformLatest { draft ->
            val input = draft.priceInput()
            if (input == null) emit(null) else pricing.guide(input).getOrNull()?.let { emit(it) }
        }
        .stateIn(scope, SharingStarted.Eagerly, null)
}

/** What prices the item: a change here asks again. */
private fun ListingDraft.priceKey() = listOf(title.trim().lowercase(), category, condition, photos.firstOrNull()?.url)
```

- [ ] **Step 6: Run the tests**

Run: `./gradlew --console=plain -q :feature:sell:testDebugUnitTest --tests '*GuideTest' --tests '*PriceGuideHolderTest'`
Expected: PASS. If `asksOncePerChangeAfterTheTypingStops` sees an ask at
599 ms, the first value is being debounced from subscription; that is the
intended behaviour, so only the timing in the test may change, not the
debounce.

- [ ] **Step 7: Commit**

```bash
git add feature/sell
git commit -m "feat(sell): PriceGuideHolder and the market's days, waiting buyers, axis and bins"
```

---

### Task 3: The screens read the guide; the old market leaves

**Files:**
- Modify: `core/model/src/main/kotlin/vn/shopnexus/core/model/Selling.kt`, `Reads.kt`, `Draft.kt`
- Modify: `core/data/src/main/kotlin/vn/shopnexus/core/data/fake/Seeds.kt`, `FakeSellRepository.kt`
- Modify: `core/data/src/main/resources/fixtures/sell.json`, `my-listings.json`
- Modify: `feature/sell/src/main/kotlin/vn/shopnexus/feature/sell/form/SellViewModel.kt`, `SellForm.kt`, `SellScreen.kt`
- Modify: `feature/sell/src/main/kotlin/vn/shopnexus/feature/sell/review/ReviewViewModel.kt`, `ReviewScreen.kt`
- Modify: `feature/sell/src/main/kotlin/vn/shopnexus/feature/sell/parts/Market.kt`, `PriceBlock.kt`, `PhotoBoard.kt`, `ListingPreview.kt`
- Modify: `feature/sell/src/main/res/values/strings.xml`
- Test: `SellScreenTest`, `ReviewScreenTest`, `SellViewModelTest`, `SellPartsTest`, `SellFormTest`, `PhotoBoardTest`, `FakeSellRepositoryTest`, `Stage4FixturesTest`, `app/.../SellWalkTest.kt`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: `SellUiState.guide: PriceGuide?`, `ReviewUiState.guide: PriceGuide?`; `sellUiState(mode, local, context, guide: PriceGuide? = null)`, `reviewUiState(local, context, guide: PriceGuide? = null)`. `PriceSuggestion` and `SimilarListing` are the guide's types again (renamed from Task 1's names).

- [ ] **Step 1: Change the tests first**

Make each test say what the screens will show. In each file, read the test
named, then:

- `SellScreenTest`: replace the `read` val with a guide:
  ```kotlin
  private val guide = Fixtures.sell().priceGuide
  ```
  pass `guide = guide` wherever the test builds a state that had `read`
  (its `state(...)` helper gains `guide: PriceGuide? = this.guide` and calls
  `sellUiState(mode, local, context, guide)`).
  `thePriceStepShowsTheMarket` becomes:
  ```kotlin
  @Test
  fun thePriceStepShowsTheMarket() {
      show(state(draft = seeded.copy(price = Vnd(4_650_000))), step = SellStep.PRICE)
      compose.onNodeWithText("Giá tham khảo 4,4 – 5,1 tr ₫").assertExists()
      compose.onNodeWithText("Rẻ hơn 10/12 tin đang bán · bán trong ~1 tuần").performScrollTo().assertExists()
      compose.onNodeWithText("Tin giống bạn").performScrollTo().assertExists()
      compose.onNodeWithText("18 người đang tìm món như của bạn").performScrollTo().assertExists()
      compose.onNodeWithText("Tin giống bạn được bán", substring = true).assertDoesNotExist()
  }
  ```
  `withoutTheMarketReadThePriceStepStillDrawsTheStrip` builds its state
  with `guide = null` and checks `"tin đã bán"` (substring) does not exist.
  `aSimilarListingLendsItsPrice` is unchanged (the fixture keeps
  "iPhone 11 64GB Trắng" at 4.900.000).
  Add:
  ```kotlin
  /** Under three sales the guide has a range and no suggestions: no panels, and the verdict waits by the range. */
  @Test
  fun aGuideWithoutSuggestionsShowsNoPanels() {
      val bare = guide.copy(suggestions = emptyList())
      show(state(draft = seeded.copy(price = Vnd(4_650_000)), guide = bare), step = SellStep.PRICE)
      compose.onNodeWithText("Bán nhanh").assertDoesNotExist()
      compose.onNodeWithText("Rẻ hơn 10/12 tin đang bán · bán trong ~2 tuần").performScrollTo().assertExists()
  }
  ```
- `ReviewScreenTest.thePriceStepShowsTheMarketAndPosts`: its `filled()`
  state carries `guide = Fixtures.sell().priceGuide`; the assertions stay.
- `SellViewModelTest`: `theFirstPhotosStartTheRead` drops
  `s.read!!.suggestions` and checks the guide after the debounce:
  ```kotlin
  advanceTimeBy(600)
  runCurrent()
  assertThat(vm.state.value.guide!!.suggestions).hasSize(2)
  ```
  `aDraftOpensWithItsValues` drops the `suggestions` line. The view model
  factory in the test passes `FakePricingRepository(FailurePolicy(latencyMillis = 0))`.
- `SellPartsTest`: its `suggestions` val uses `days = 2` / `days = 7`; the
  panels' text "~2 ngày" / "~1 tuần" stays. The `ListingPreview(...,
  waiting = 23)` test expects "23 người đang tìm món như của bạn".
- `SellFormTest`: the `ListingDraft(... suggestions = ...)` goes; the test
  that checked `withRead` copies suggestions now checks `estimate` only.
- `PhotoBoardTest`: delete the test of the shots (the board no longer has
  them); keep the cover and grid tests, without the `shots` argument.
- `FakeSellRepositoryTest`, `Stage4FixturesTest`: drop assertions on
  `market`, `suggestions`, `photoMarket`, `photoSuggestions`.
- `app/src/test/kotlin/vn/shopnexus/android/SellWalkTest.kt`: where it waits
  for the price step's market, advance 600 ms more for the guide.

Run: `./gradlew --console=plain -q :core:data:testDebugUnitTest :feature:sell:testDebugUnitTest`
Expected: compile errors in the tests (`guide` unknown on the states).

- [ ] **Step 2: Remove the old model and rename**

In `Selling.kt`: delete `PriceSuggestion` (the old one, `days: String`),
`SoldBin`, `PriceFactor`, `SimilarListing` (the old one), `MarketRead`,
`PhotoShot`. Rename `PriceGuideSuggestion` to `PriceSuggestion` and
`GuideListing` to `SimilarListing` everywhere (IDE rename or
`sed -i 's/\bPriceGuideSuggestion\b/PriceSuggestion/g; s/\bGuideListing\b/SimilarListing/g'`
over `core` and `feature`).

In `Reads.kt`: `ListingRead` loses `suggestions` and `market`; its KDoc
drops "[suggestions] and [market] are the price step's, which has no API
yet".

In `Draft.kt`: `ListingDraft` loses `suggestions`; `estimate`'s KDoc says
"The read's range, kept so a reopened draft shows "Giá tham khảo" before
its guide arrives."

In `Seeds.kt`: `SellSeed` loses `photoSuggestions` and `photoMarket`.

In `FakeSellRepository.kt`: `readPhoto` and `readVideo` stop setting
`suggestions` and `market`; delete `coverShots` and the `MarketRead`
import.

Fixtures, from the repo root:

```bash
python3 -I - <<'EOF'
import json
p = "core/data/src/main/resources/fixtures/sell.json"
d = json.load(open(p))
del d["photoMarket"], d["photoSuggestions"]
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2); open(p, "a").write("\n")
p = "core/data/src/main/resources/fixtures/my-listings.json"
d = json.load(open(p))
for dr in d["drafts"]:
    dr.pop("suggestions", None)
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2); open(p, "a").write("\n")
EOF
git diff --stat core/data/src/main/resources/fixtures
```

(match the files' indent as in Task 1.)

- [ ] **Step 3: Put the guide in the states**

`SellViewModel`: inject `private val pricing: PricingRepository`; after
`local`:

```kotlin
    private val guide = PriceGuideHolder(viewModelScope, local.map { it.draft }, pricing)
```

and the state:

```kotlin
    val state: StateFlow<SellUiState> = combine(local, context, guide.guide) { l, c, g -> sellUiState(mode, l, c, g) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), SellUiState(mode = mode))
```

`SellUiState` gains `val guide: PriceGuide? = null` (KDoc: "The market for
the draft as it stands; null until it has a title, a category and a
condition, and while the first guide is on its way."), and the `read`
field's KDoc becomes "The cover's read, once it is done: its draft and
range." `sellUiState(mode, local, context, guide: PriceGuide? = null)`
sets it.

`SellForm.kt` `withRead`: the last lines become
`estimate = r.estimate?.range(), readCover = r.photos?.firstOrNull()?.url,`.

`ReviewViewModel`: the same injection and holder over
`local.map { it.draft }`; `ReviewUiState` and `reviewUiState` gain
`guide` the same way. Its own `estimate` stays the read's range.

Both view models' Hilt factories get the new constructor parameter by
injection; the tests construct them with `FakePricingRepository`.

- [ ] **Step 4: Rewire the parts**

`parts/Market.kt`:
- `waitAt(price, range, suggestions)` uses `daysLabel(fast.days)` and
  `daysLabel(market.days)`; the rest stays.
- Delete `MarketRead.at`; add
  `private fun at(amount: Vnd, low: Vnd, high: Vnd): Float = ((amount.amount - low.amount).toFloat() / (high.amount - low.amount)).coerceIn(0f, 1f)`.
- `MarketStrip(range: PriceRange, guide: PriceGuide?, price: Vnd?, onOpen, onPrice, modifier)`:
  `open` is clickable when `guide != null && (guide.soldPrices + guide.livePrices).isNotEmpty()`;
  the axis is `guideAxis(range, guide, price)`; the source line, shown with
  the same condition, is
  `stringResource(R.string.sell_market_source, guide.soldPrices.size, guide.livePrices.size)`.
- `PriceVerdictLine(price, range, guide: PriceGuide, modifier)`: calls
  `priceVerdict(price, range, guide.livePrices, guide.suggestions)`.
- `SimilarBlock(similar: List<SimilarListing>, onPick, modifier)`: the
  subtitle is `stringResource(R.string.sell_similar_line)`; the
  `similarTip` line goes.
- `SimilarCard`: `AsyncImage(x.coverUrl, ...)`; the second line is
  `conditionLabel(x.condition)`; the third is
  `if (x.sold) stringResource(R.string.sell_similar_sold_after, x.daysToSell ?: 1) else stringResource(R.string.sell_similar_near, x.km)`.
- `DemandCard(waiting: Int, modifier)`: title
  `stringResource(R.string.sell_waiting, waiting)`, line
  `stringResource(R.string.sell_waiting_line)`. Shown only when
  `waiting > 0` (the caller checks).
- Delete `PhotoTip`.
- `MarketSheet(range, guide: PriceGuide, price, onDismiss, modifier)`:
  `val (low, high) = guideAxis(range, guide, null)`;
  `val bins = soldBins(guide.soldPrices, low, high)`; the header is
  `stringResource(R.string.sell_market_sold, guide.soldPrices.size)`; the
  bars text names the start of the fullest bin,
  `Vnd(low.amount + (high.amount - low.amount) * bins.indexOf(bins.max()) / bins.size).brief()`;
  the price line uses `at(price, low, high)`; the axis labels are
  `low`, the middle and `high`; the factors section goes; the closing line
  is `stringResource(R.string.sell_market_how, guide.soldPrices.size, guide.livePrices.size)`.
  With no sold price, the bars and their heading do not show.
- `CompareSheet`: the photo is `x.coverUrl`; the rows are price,
  condition, and where:
  `Line(stringResource(R.string.sell_compare_where), if (x.sold) stringResource(R.string.sell_compare_sold_after, x.daysToSell ?: 1) else stringResource(R.string.sell_similar_near, x.km), district)`;
  the storage and battery rows go; the note is
  `sell_compare_note_sold (x.price.brief(), x.daysToSell ?: 1)` /
  `sell_compare_note_live (x.price.brief(), x.km)` without a price, else
  `sell_compare_same`, or `sell_compare_higher` / `sell_compare_lower`
  with the gap only.

`parts/PriceBlock.kt`: the panel's day line is `daysLabel(suggestion.days)`;
the `offerHint` parameter and its text go.

`parts/PhotoBoard.kt`: the `shots` and `item` parameters and the "Người
mua hay xem" section go. Delete what only that section used.

`parts/ListingPreview.kt`: `CardView`'s neighbour card uses
`n.coverUrl` and `meta = "${conditionLabel(n.condition)} · ${n.km} km"`.

- [ ] **Step 5: Rewire the screens**

`SellScreen.kt`:
- Replace `val market = state.read?.market` (both places) with
  `val guide = state.guide`.
- PHOTOS: `PhotoBoard(state.draft.photos, onRemove = ..., ...)` without
  `shots` and `item`; delete the `tip` / `PhotoTip` lines.
- PRICE, after the price `Form`:
  ```kotlin
  if (guide != null && guide.similar.isNotEmpty()) {
      SimilarBlock(guide.similar, onPick = { comparing = it.id }, Modifier.padding(top = 16.dp))
  }
  val waiting = guide?.let { waitingAt(state.draft.price, state.draft.allowOffers, it.watchers) } ?: 0
  if (waiting > 0) DemandCard(waiting)
  ```
- REVIEW and the PREVIEW sheet: `neighbour = guide?.similar?.firstOrNull { !it.sold }`.
- DONE: `waiting = state.guide?.let { waitingAt(state.draft.price, state.draft.allowOffers, it.watchers) }`.
- The MARKET sheet: `val estimate = state.guide?.estimate?.range() ?: state.draft.estimate`;
  shown when `guide != null && estimate != null`, as
  `MarketSheet(estimate, guide, state.draft.price, ...)`.
- The compare sheet: `state.guide?.similar?.firstOrNull { it.id == comparing }`.
- In `Form`'s price block:
  ```kotlin
  val guide = state.guide
  val estimate = guide?.estimate?.range() ?: draft.estimate
  val suggestions = guide?.suggestions.orEmpty()
  PriceBlock(
      estimate?.let(::estimateLabel), suggestions, draft.price?.amount?.toString().orEmpty(),
      onPriceText = { edit(FormEdit.PriceText(it)) },
      onSuggest = { kind -> suggestions.firstOrNull { it.kind == kind }?.let { edit(FormEdit.Suggest(it.price)) } },
      offers = draft.allowOffers, onOffers = { edit(FormEdit.Offers(it)) }, error = error, focus = focuses.price,
      market = estimate?.let { e -> { MarketStrip(e, guide, draft.price, onMarket, onPrice = { edit(FormEdit.PriceText(it.amount.toString())) }) } },
      verdict = guide?.let { g -> estimate?.let { e -> { draft.price?.let { PriceVerdictLine(it, e, g) } } } },
      onSubmit = onPriceSubmit,
  )
  ```

`ReviewScreen.kt`, the same at each place `state.read?.market` appears
(lines near 353, 380, 407-415, 498-526, 765-768): the guide from
`state.guide`, `estimate = state.guide?.estimate?.range() ?: state.estimate`,
`guideAxis(e, state.guide, draft.price)` for the strip at line 768, no
`offerHint`, `SimilarBlock(guide.similar, ...)`, `DemandCard(waiting)`
under the same `waiting > 0` rule.

- [ ] **Step 6: The strings**

`feature/sell/src/main/res/values/strings.xml`:

```xml
    <string name="sell_market_source">Từ %1$d tin đã bán và %2$d tin đang bán giống món này</string>
    <string name="sell_market_sold">Đã bán trong 6 tháng · %1$d tin</string>
    <string name="sell_market_bars">Số tin đã bán theo giá, nhiều nhất quanh %1$s</string>
    <string name="sell_market_how">Từ %1$d tin đã bán trong 6 tháng và %2$d tin đang bán đăng trong 3 tháng, cùng danh mục và tình trạng.</string>
    <string name="sell_similar_line">Cùng danh mục và tình trạng, đang bán hoặc đã bán gần đây</string>
    <string name="sell_similar_near">Cách %1$d km</string>
    <string name="sell_similar_sold_after">Bán sau %1$d ngày</string>
    <string name="sell_waiting">%1$d người đang tìm món như của bạn</string>
    <string name="sell_waiting_line">Họ đang theo dõi một tìm kiếm khớp với tin này ở giá bạn đặt</string>
    <string name="sell_compare_sold_after">Bán sau %1$d ngày</string>
    <string name="sell_compare_note_live">Đang bán %1$s, cách %2$d km.</string>
    <string name="sell_compare_note_sold">Đã bán %1$s sau %2$d ngày.</string>
    <string name="sell_compare_higher">Cao hơn giá bạn %1$s.</string>
    <string name="sell_compare_lower">Thấp hơn giá bạn %1$s.</string>
    <string name="preview_told_waiting">%1$d người đang tìm món như của bạn</string>
```

Delete `sell_market_factors`, `sell_similar_where`, `sell_offer_gap`,
`sell_tip_shoot`, `sell_board_shots`, `sell_board_shots_any`,
`sell_compare_storage`, `sell_compare_battery`, and `sell_photo_count` if
`grep -rn sell_photo_count feature/sell/src/main` finds no other use.

- [ ] **Step 7: Build, test, re-record**

Run: `./gradlew --console=plain -q :core:model:test :core:data:testDebugUnitTest :feature:sell:testDebugUnitTest :app:testDebugUnitTest`
Expected: PASS.

Run: `./gradlew --console=plain -q :feature:sell:verifyRoborazziDebug`
Expected: the price step, Kiểm tra, the market and compare sheets, the
photo board and the preview differ. Look at each new image (the
`_compare.png` files Roborazzi writes); when each shows the guide's copy
and nothing missing, re-record:
`./gradlew --console=plain -q :feature:sell:recordRoborazziDebug`.

Run: `./gradlew -q spotlessCheck detekt :feature:sell:lintDebug`
Expected: no findings (an unused string is a lint finding; delete it).

Stop the daemons and check none is left (see the header).

- [ ] **Step 8: Commit**

```bash
git add core feature app
git commit -m "feat(sell): the Giá step reads a price guide; shots, factors and the offer gap leave"
```

---

### Task 4: Record it

**Files:**
- Modify: the app's design notes that name `MarketRead` (find them: `grep -rn "MarketRead\|photoMarket" docs README.md mohinh.md .superdesign/*.md`)

- [ ] **Step 1: Update what names the old market**

For each hit outside `docs/superpowers/` (plans and specs are history),
replace the description with the guide: the price step asks for a guide
by the draft's content; similar listings, waiting buyers counted at the
price, "Bán nhanh" and "Giá thị trường" with days; no factors, shots or
offer gap until the server has them. Run the humanizing-writing checker on
the changed prose (`~/.claude/CLAUDE.md`).

- [ ] **Step 2: Commit**

```bash
git add -A docs README.md mohinh.md .superdesign
git commit -m "docs(app): the price step reads a guide"
```

Skip the commit when Step 1 found nothing.
