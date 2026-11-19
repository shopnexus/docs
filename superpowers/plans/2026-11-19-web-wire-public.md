# Website wiring, Phase 1: public pages — Implementation Plan

> Roadmap: `~/.claude/plans/website-wire-roadmap.md`. Builds on Phase 0 (`feat/web-wire-foundation`: typed client in `src/lib/api/client.ts`, `Astro.locals.api`, cookie session, email sign-in). Server: `/v1/screens/home`, `/v1/search`, `/v1/screens/listing/{id}`, `/v1/screens/seller/{id}`, `/v1/sellers/{id}/listings`, `/v1/sellers/{id}/reviews`, `/v1/categories`, `/v1/saved/{id}`, `/v1/regions/nearest`, `/v1/uploads`, `/v1/search/history`.

**Goal:** Home, Bảng tin, Chi tiết tin, Người bán, Danh mục, Tìm kiếm and Tìm bằng ảnh render server data; their mock goes.

## Global Constraints

Roadmap rules 1–5. Each sub-step is its own branch off `main` in `website`, gated (`bun run check`, `bun run build`, audit at 1280 clean, compose dev check signed out and in), then merged locally.

## Rulings (decided in the analysis, 2026-11-19)

- The card follows the app's `ListingSummary`: photo, price, title, condition, distance under 10 km or the commune, saved. The seller row and "posted" go, since `SearchItem` carries neither. A card without a cover shows the soft placeholder.
- Place: the site never sends lat/lng except once to `/v1/regions/nearest`. A tap on "Gần bạn" or "Quanh tôi" asks the browser for its position, posts it to `/vi-tri`, which stores the nearest commune code in `sn_area` (1 year, not httpOnly-sensitive but httpOnly anyway); every server call sends `near_commune` from it. Without it, "Gần bạn" shows the ask, and cards show the commune.
- Category URLs keep Vietnamese slugs, derived from `display_name` (`Điện thoại` → `dien-thoai`); icons per root code live in `src/lib/catalog.ts`. `/v1/categories` is read once per 10 minutes per process.
- Bảng tin tabs: Dành cho bạn = `for_you` (one page, up to 20, no "Xem thêm"); Gần bạn = `search?sort=nearby`; Mới nhất = `search?sort=newest`. Paging passes the server's cursor (`/bang-tin?tab=&sau=`).
- Lưu tin: the heart posts to `/luu/{id}` (PUT or DELETE `/v1/saved/{id}`); a guest goes to Đăng nhập. Script toggles in place; without script the form posts and comes back.
- Chi tiết tin: gallery from `photos[].url`, description, specs, condition scale, seller summary (rating, sold, joined), three other listings (`/v1/sellers/{id}/listings?limit=3`), two reviews, five similar (`search?like=`). Sections with no server source hide: reply time, views, saves, the price band, "Người bán ghi". Sold or reserved listings follow the status; `listing_not_found` is the 404.
- Người bán: profile, listings with paging, reviews; tier panel, praise bars and reply time hide.
- Danh mục: roots with counts from `HomeScreen.categories`; a category page is `search?category=` with its subcategory pills (counts from `counts`), condition/price/offers filters and paging. The phone page's model price panel and hot searches hide.
- Tìm kiếm: q, chips (`off=`), filters, sort, cursor paging, `understood`; the header's recent searches come from `/v1/search/history` signed in and stay in the browser signed out.
- Tìm bằng ảnh: signed-in only. A shared uploader (`src/lib/upload.ts` + `/tai-anh` endpoint returning the presigned PUT) that Phase 6 reuses; the browser PUTs the file to the media URL, then opens `/tim-bang-anh?anh=<upload_id>`.

## Sub-steps

1. `feat/web-wire-browse-core`: `lib/listing.ts` (SearchItem → Card, condition labels), `ListingCard` on Card, `lib/catalog.ts`, `lib/area.ts` + `/vi-tri`, `/luu/{id}`.
2. `feat/web-wire-home`: Home, HomeRail/HomeTiles data that exists, `/bang-tin`.
3. `feat/web-wire-listing`: Chi tiết tin, NotFound, QuickChat input (chat itself is Phase 4).
4. `feat/web-wire-seller`: Người bán.
5. `feat/web-wire-search`: Tìm kiếm, Danh mục (index and page), header history.
6. `feat/web-wire-photo-search`: uploader and Tìm bằng ảnh.
7. Remove the mock each step leaves unused in `src/data`.
