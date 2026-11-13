# Design: "Gần bạn" becomes one tab, not the product's promise

Date: 2026-11-14.
Status: decided in conversation, question by question. The reference the
user gave is Chợ Tốt's home: recent-search chips under the search field,
categories, a "<thing> · Vì bạn đã xem gần đây" rail that can be closed,
then feed tabs "Dành cho bạn | Gần bạn | Mới nhất | Video".

## Why

ShopNexus ships COD through the seller's carrier, so a seller sells to
buyers in any province. The app still sells itself as local: Home opens on
"Gần bạn" with a "Bình Thạnh · 10 km" chip, the tagline is "Giá tốt, gần
bạn, chốt nhanh", boosts promise "Lên đầu mục Gần bạn", and screens repeat
"quanh bạn". Distance stays useful as a reference (meet to trade, or ship)
and as one ranking signal, but it is no longer the promise, and the app
stops repeating it.

## Decisions

| Question | Decision |
|---|---|
| Home's feed | Tabs: **Dành cho bạn** (default) · **Gần bạn** · **Mới nhất**. |
| Dành cho bạn | Nationwide, ranked by fit (what the viewer saved, watched, searched, viewed) and freshness. Nearness adds to the score; it never filters. |
| Gần bạn | Listings around the viewer's area, as today's nearby feed. Its first row is the chip "Bình Thạnh · 10 km", which opens the radius sheet. No other tab has the chip. |
| Mới nhất | Nationwide, newest first. |
| Home header | The area chip at the top of Home goes; the bell joins the search row. Under the search field, a row of the viewer's recent searches as chips (✕ removes one). |
| Hero carousel | Only for a viewer who is not signed in. Signed in, Home is search, recent-search chips, categories, the rail and the tabs, as Chợ Tốt's, with no carousel, so the listings come first. |
| Rail | "<category or kind> · Vì bạn đã xem gần đây" sits above the tabs, from the viewer's recently viewed listings; ✕ hides it. It replaces the "Gần bạn" rail. A viewer with no history has no rail. |
| Copy that sells nearness | Removed everywhere it is the pitch (see "Copy"). |
| Search and category | Keep the "Khoảng cách" filter and the "Gần bạn nhất" sort. The default is nationwide. Nearness adds to relevance as today. |
| Card place | Under 10 km: the distance ("4,2 km"). Beyond: the seller's commune when in the viewer's province ("Củ Chi"), otherwise the province ("Đà Nẵng"). |
| Similar listings in Đăng tin's Giá step | The same rule as a card. |
| Boost | "Lên đầu" Dành cho bạn and the search and category results it matches, nationwide, for the days bought. Not tied to Gần bạn. Seller plan perk: "Tin được ưu tiên hiển thị". |
| Waiting buyers (price guide) | Unchanged in substance; the copy never says "gần" or "quanh". |

## Copy

| Where | Before | After |
|---|---|---|
| Home hero, first slide (signed out only) | "Giá tốt, gần bạn, chốt nhanh" · "Xem quanh đây" | "Đồ cũ từ khắp nơi, giao tận cửa" · "Xem tin mới" |
| Home pull to refresh | "2 tin mới quanh bạn" | "Có 2 tin mới" |
| Home radius sheet done | "Gần bạn hiện tin trong N km" | "Tab Gần bạn hiện tin trong N km" |
| Category header | "Phổ biến quanh bạn" | "Phổ biến" |
| Category line | "Quanh X · N km", "· Gần bạn nhất" | removed; the sort chip says "Gần bạn nhất" only when chosen |
| Category empty | "Chưa có tin trong N km quanh bạn." | "Chưa có tin phù hợp." (with the distance filter on: "Chưa có tin trong N km.") |
| Search | "Tất cả tin quanh bạn" | "Tất cả tin" |
| Similar listings empty (core/ui) | "Chưa có tin phù hợp quanh bạn" | "Chưa có tin phù hợp" |
| Inbox and Orders empty | "Khám phá tin quanh bạn" | "Khám phá tin đang bán" |
| Welcome tagline | "Giá tốt, gần bạn, chốt nhanh" | "Đồ cũ giá tốt, xem hàng rồi mới trả" |
| Welcome area line | "Tin gần bạn hiện trước. Người khác chỉ thấy quận, không thấy địa chỉ." | "Dùng để tính khoảng cách và phí ship. Người khác chỉ thấy quận, không thấy địa chỉ." |
| Boost sheet | "Lên đầu mục Gần bạn quanh X" | "Lên đầu Dành cho bạn và kết quả tìm kiếm" |
| Seller plan perk | "Tin được ưu tiên quanh bạn" | "Tin được ưu tiên hiển thị" |
| Đăng tin, Xem lại | the card among "Gần bạn", "Trang chủ của người mua quanh X" | the card among "Dành cho bạn", "Trang chủ của người mua" |

## Designs (Superdesign canvas, project 56eb6c5a)

The agent edits the Python builders in `app/.superdesign/tools/`, rebuilds
`mockups/`, and imports each into its draft (`tools/publish.py`). Drafts
revised:

1. Home · Khám phá (`home`, build_home.py): the signed-in Home with header,
   recent-search chips, categories, rail, tabs, the Gần bạn tab with its
   chip and radius sheet, card places, and no carousel. The signed-out Home
   (carousel first, no chips or rail) is a variant of the same draft.
2. Category · Điện thoại (`category`): header copy, empty states, card
   places.
3. Search · Kết quả (`search`): "Tất cả tin", card places; filter and sort
   kept.
4. Tin của bạn (`listings`): boost sheet copy.
5. Gói người bán (`plans`) and Tôi (`me`): the perk line.
6. Chào mừng (`welcome`): tagline and area line.
7. Đăng tin · Xem lại (`sell-preview`): the card among Dành cho bạn.
8. Đăng tin · Từng bước (`sell-steps`) and Kiểm tra (`sell-review`):
   similar listings' places.
9. Tin nhắn (`inbox`) and Đơn hàng (`orders`): empty-state copy where the
   draft shows it.

`common.py`'s listing pool gets a few far listings (Hà Nội, Đà Nẵng, Cần
Thơ, Huế, Củ Chi) so the rule shows; `km_value` reads a place as far.

## App (after the designs are approved)

- Home: `FeedTab {FOR_YOU, NEARBY, NEWEST}`, the radius chip and sheet only
  under NEARBY, recent-search chips, the "Vì bạn đã xem" rail with hide; the
  hero carousel only when signed out.
- `ListingSummary` carries a place (commune and province names) beside
  `distanceKm`; one formatter picks km under 10 or the place.
- Every copy change in the table.
- Fakes: a for-you order, a newest order, a viewed history.

## Server (its own spec and plan, after the app)

- `GET /v1/screens/home` answers the first page of the for-you feed, not
  nearby; tabs page through `GET /v1/search?sort=for_you|nearby|newest`.
- `sort=for_you`: the nearby query's rings become one boost among fit
  signals (saved, watched, searched, viewed) and freshness, with no radius.
- A viewed-listings history per account (for the rail and for-you), erased
  with the account.
- Search cards carry the listing's commune and province names.
- Boosts, when built, rank in for-you and search nationwide.

## Out

- Video tab (Chợ Tốt's fourth tab).
- Changing how distance scores in search beyond the default scope.
- The price guide's waiting-buyers privacy question (still open from
  2026-11-13).
