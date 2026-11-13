# Design: price guide, the "Giá" step's market data for any draft

Date: 2026-11-13.
Status: decided in conversation, question by question. When the work lands,
the decisions below go into `~/shopnexus/server/ARCHITECTURE.md` (sections
Assist and Search watches) and `~/shopnexus/checklist.md` ticks the line
`Bước "Giá" khi đăng tin: tin tương tự, người mua đang chờ, gợi ý "Bán nhanh"
và "Giá thị trường"` and adds the lines listed under "Checklist".

## Why

The app's "Giá" step shows similar listings, how many buyers are waiting, and
two suggestions, "Bán nhanh" and "Giá thị trường", each with how long it
usually takes to sell. The server has only the range `estimate` inside a
listing read. The app's fakes put `suggestions` and a large `MarketRead`
into `ListingRead`, which the server never returns.

The price belongs to the item, not to the read: a listing typed by hand, a
"Sửa tin", a "Đăng lại" and a draft whose title or condition changed after
its read have no read, or a stale one. So the market data gets its own
resource, keyed by the draft's content, and the read's estimate and the
guide come from the same code so they agree.

## Scope

In:

- `POST /v1/price-guides`: the range, the two suggestions, similar listings,
  the sold and on-sale prices of the sample, and the buyers' search watches
  the draft would match.
- One helper shared by the listing reads and the guide that turns a draft
  into vectors and a price sample.
- Discovery's reverse match: the watches a draft not yet posted would match.
- The app: `PriceGuide` replaces `MarketRead`; the "Giá" step and Xem lại
  read it through one holder.

Out:

- Price factors, the shots buyers look at, the photo tip, the offer gap,
  the tip under similar listings. The app drops them now (see "App").
- A cap on guides. The general rate limit in the checklist covers it
  (`Giới hạn tần suất chung`); until then the endpoint has none.
- Filtering the sample by distance: the sample stays nationwide, as the
  read's estimate is today.
- The app's real HTTP client for the guide: the app still runs on fakes.

## Decisions

| Question | Decision |
|---|---|
| Resource | One synchronous read: `POST /v1/price-guides`, 200, no `Idempotency-Key`. POST because the body carries the draft. |
| Shape | Inside a read (A) and app-side only (B) were rejected: A misses drafts without a read and goes stale on edit; B has no similar listings, no watchers, no days, and puts the rule in each client. |
| Module | Handler and use case in assist, which already depends on catalog and media; assist calls discovery for watchers. Discovery depends on catalog, so catalog cannot call discovery. |
| Sample | Catalog's `PriceSample` as today (30 nearest by vector, same category and condition, sold within 180 days, on sale within 90), returning also `listing_id`, `days_to_sell` and the point. Nationwide. |
| Estimate | `domain.MarketEstimate` unchanged; the guide and the reads call the same helper, so a read's estimate equals the guide's for the same draft. |
| "Giá thị trường" | `price` = the estimate's median; `days` = the median `days_to_sell` of every sold listing in the sample. |
| "Bán nhanh" | The sold listings whose `days_to_sell` is at most that median form the fast half; `price` = their median price, `days` = their median days. Left out when its price is not below the market price. |
| Too few sold | Under 3 sold listings in the sample: no suggestions, the range still shows. Under `MinMarketSample` (5) listings: no estimate and no suggestions; the similar listings and prices hold what the sample found, and the watchers, which do not depend on the sample, are always read. Still 200. |
| Similar | The first 12 of the sample in vector order, with title, cover, price, condition, sold, km from the draft's commune, days to sell when sold. |
| Watchers | Every live watch the draft would match, muted ones included, without a minimum count. One row per watch: `price_min`, `price_max`, `offers_only`, no ID and nothing about the buyer. The app counts at the price and the offers switch it shows. At most 200 rows. |
| Cap | None in this change (decided: wait for the general rate limit). |
| App leftovers | `factors`, `shots`, `photoTip`, `offerGap`, `similarTip` and `km` on the market are removed from the app with this change. |

## API

### `POST /v1/price-guides`

Requires a session. Body:

```yaml
PriceGuideRequest:
  type: object
  additionalProperties: false
  required: [title, category_code, condition, commune_code]
  properties:
    title:         {type: string, minLength: 1, maxLength: 70}
    category_code: {type: string}
    condition:     {type: string, enum: [new, like_new, used]}
    specs:         {type: array, maxItems: 20, items: {$ref: "#/Spec"}}
    description:   {type: string, maxLength: 1500}
    commune_code:  {type: string}
    photos:
      type: array
      maxItems: 3
      uniqueItems: true
      items: {type: string, format: uuid}
      description: The caller's waiting uploads, the cover first. The app sends the first three it has as uploads.
```

Answers 200 with `PriceGuide`. Errors:

- `invalid_request` 400: the shape (the validator).
- `invalid_listing` 422 with `fields`: `category_code` not a subcategory,
  `commune_code` not a commune of the list (catalog's rule and messages).
- `invalid_upload` 422: a photo that is not the caller's waiting,
  unexpired photo upload (media's `QueryUpload`).

```yaml
PriceGuide:
  type: object
  additionalProperties: false
  required: [estimate, suggestions, similar, sold_prices, live_prices, watchers]
  properties:
    estimate:
      oneOf: [{$ref: "#/PriceEstimate"}, {type: "null"}]
    suggestions:
      type: array
      maxItems: 2
      items: {$ref: "#/PriceSuggestion"}
    similar:
      type: array
      maxItems: 12
      items: {$ref: "#/SimilarListing"}
    sold_prices:
      type: array
      items: {type: integer, format: int64}
      description: The prices of the sample's sold listings, ascending.
    live_prices:
      type: array
      items: {type: integer, format: int64}
      description: The prices of the sample's listings on sale, ascending.
    watchers:
      type: array
      maxItems: 200
      items: {$ref: "#/Watcher"}

PriceSuggestion:
  required: [kind, price, days]
  properties:
    kind:  {type: string, enum: [fast, market]}
    price: {type: integer, format: int64}
    days:  {type: integer, minimum: 1}

SimilarListing:
  required: [listing_id, title, cover_url, price, condition, sold, km]
  properties:
    listing_id:   {type: string, format: uuid}
    title:        {type: string}
    cover_url:    {type: string}
    price:        {type: integer, format: int64}
    condition:    {type: string, enum: [new, like_new, used]}
    sold:         {type: boolean}
    km:           {type: integer, minimum: 0, description: "From the draft's commune to the listing's point, rounded."}
    days_to_sell: {type: integer, minimum: 1, description: "Sold only."}

Watcher:
  required: [offers_only]
  properties:
    price_min:   {type: integer, format: int64}
    price_max:   {type: integer, format: int64}
    offers_only: {type: boolean}
```

`PriceEstimate` stays as it is. The schemas go in `api/schemas/assist.yaml`,
the path in `api/paths/assist.yaml` beside `/v1/listing-reads`, and
`api/openapi.yaml` refers to it.

## The server

### Catalog

- `PriceSample` returns `domain.PriceSample{ListingID, Price, Sold,
  DaysToSell, Point}`. `DaysToSell` is `ceil((sold_at − published_at) / 24 h)`,
  at least 1, zero for a listing on sale. The SQL changes only its select
  list.
- `HoldsAllWords(phrase, text string) bool` in `catalog/domain`: splits both
  on what is not a letter or a digit and lowercases, as the index's default
  tokenizer does, and is true when every word of the phrase is a word of the
  text. Its test table holds the cases the sweep's `allWords` query decides,
  so a change of tokenizer shows up there.

### Discovery

`Watchers(ctx, seller uuid.UUID, q WatcherQuery) ([]Watcher, error)` with
`WatcherQuery{CategoryCode, Condition, Commune string, Point, Text}`:

1. SQL picks candidates: `category` null, equal to the draft's category, or
   equal to its root (as the sweep's `category()` maps a watch's category);
   `conditions` empty or holding the draft's; no `commune_code`, or the
   draft's commune point inside the watch's radius box (the sweep's box);
   not the seller's own; the watcher not suspended or deleted; no block
   between watcher and seller either way. `alert` is not looked at.
2. Go keeps the watches with a phrase that `HoldsAllWords` in `Text`, or the
   raw `query` when the watch has no phrases, as the sweep does.
3. At most 200 rows, oldest watch first.

`Text` is the title, the description and the specs as `label: value` lines,
the fields the index matches on.

### Assist

- `draftSample(ctx, account, input, photos)` in `estimate.go`: today's body of
  `marketEstimate` without the Restate step: the embedding text from
  catalog, the photos through `Media.QueryImage`, the two embeddings (a model
  that fails leaves its list out), the normalized mean of the photo vectors,
  `Catalog.PriceSample`. Both callers use it: `marketEstimate` wraps it in
  `restate.Run` as now; the guide calls it with the request's context and
  `CallTimeout`.
- `domain.Suggest(samples) []Suggestion` beside `MarketEstimate` in
  `assist/domain`: the two rules above, prices rounded with `roundPrice`.
  `domain.Sample` gains `DaysToSell`.
- `PriceGuide(ctx, account, in)` reads top to bottom: check the category and
  commune through catalog (`invalid_listing`), take the commune's point,
  `draftSample`, `MarketEstimate`, `Suggest`, the first 12 through
  `Catalog.Summaries` (a listing gone since the sample is skipped), `km` from
  the commune's point, the sold and live prices, `Discovery.Watchers`. A
  failing embedding or sample is logged and gives a guide without estimate,
  suggestions, similar listings or prices, as the read's estimate does; a failing watcher read is an error (500).
- Log line per guide: category, condition, photo count, sample size, sold
  count, estimate source, suggestion count, watcher count, time taken. No
  title, description or specs.

## App

### Model (`core/model`)

- `PriceGuide(estimate: ReadEstimate?, suggestions: List<PriceSuggestion>,
  similar: List<SimilarListing>, soldPrices: List<Vnd>, livePrices: List<Vnd>,
  watchers: List<Watcher>)`.
- `PriceSuggestion(kind, price, days: Int)`: `days` becomes a number, the UI
  formats "~2 ngày".
- `SimilarListing(id, title, coverUrl, price, condition, sold, km,
  daysToSell: Int?)`; `photoUrl`, `storage`, `battery` and `where` go.
- `Watcher(priceMin: Vnd?, priceMax: Vnd?, offersOnly: Boolean)`.
- `MarketRead`, `SoldBin`, `PriceFactor`, `PhotoShot` go. `ListingRead`
  loses `suggestions` and `market`. `ListingDraft` loses `suggestions`;
  `estimate` stays, so a reopened draft shows "Giá tham khảo" before the
  guide arrives. Draft bodies are decoded with `ignoreUnknownKeys`, so old
  bodies still read.

### Data (`core/data`)

- `PricingRepository.guide(input: PriceInput): Result<PriceGuide>`;
  `PriceInput(title, category, condition, specs, description, commune,
  photos)`.
- `FakePricingRepository` builds the guide from the seeds that now feed
  `MarketRead` and plays the empty guide for an unknown item.

### Feature sell

- `PriceGuideHolder` (in `feature/sell`), used by `SellViewModel` and
  `ReviewViewModel`: from the draft it takes a fingerprint (normalized title,
  category, condition, commune, cover), waits 600 ms after the last change,
  asks for the guide, keeps the last good one on failure, and exposes
  `StateFlow<PriceGuide?>`. The screens read the guide from there, never
  from `state.read`.
- `parts/Market.kt`: `waitAt` and `priceVerdict` keep their signatures with
  the guide's lists; `waitingAt(price, allowOffers, watchers): Int` counts
  the watchers whose range holds the price and whose `offersOnly` the switch
  allows. The bins of the sheet are built from `soldPrices` in the app.
- Removed with the leftovers: the photo board's shots and tip, the sheet's
  factors, the offer gap hint, the tip under similar listings, the "trong X
  km" line (the similar block names the item without a radius).

## Checklist

Ticked: the "Giá" step line, rewritten to name `POST /v1/price-guides`
"(app chưa nối)". Added, unticked:

- Yếu tố làm giá lệch khỏi giá giữa (pin, dung lượng, hộp…) ở sheet giá.
- Ảnh người mua hay xem cho từng loại hàng ở bước Ảnh.
- Người mua thường trả thấp hơn bao nhiêu phần trăm.

## Testing

- Assist domain: `Suggest` by table (no sold listings, two, three, the fast
  half priced above the market so fast is left out, ties in days, rounding).
- Catalog domain: `HoldsAllWords` by table against the sweep's cases
  (diacritics kept, punctuation, digits, "xe đạp" against "xe máy").
- Catalog repository: `PriceSample` returns the listing, days to sell
  (rounded up, at least 1) and the point.
- Discovery repository and service: `Watchers` keeps a watch without a
  category, with the root, with the draft's commune inside the radius, a
  muted one; drops the seller's own, a blocked pair either way, a suspended
  watcher, a wrong condition, a commune outside the radius, a phrase with a
  missing word; stops at 200.
- Assist service: a guide with enough samples has the estimate, both
  suggestions, 12 similar ones with km and the watchers; a guide under 5
  samples has no estimate or suggestions, keeps its similar listings and
  watchers, and is 200; another account's photo is `invalid_upload`; an
  unknown commune is `invalid_listing`; a read's estimate equals the guide's
  for the same draft (both through `draftSample`).
- e2e: `price_guide_test.go`: post sold and live listings, a watch from a
  second account, then a guide for a third account's draft.
- App: `waitingAt` and the reworked `waitAt`/`priceVerdict` as unit tests;
  `PriceGuideHolder` asks once per fingerprint after the debounce and keeps
  the last guide on failure; the sell walk test runs the "Giá" step on the
  fake guide.
