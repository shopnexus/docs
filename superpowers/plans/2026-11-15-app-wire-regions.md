# App wiring, Phase 3: communes, the person's area and the address book — Implementation Plan

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`. Mockups approved 2026-11-15 (commit `b646e209` on `feat/wire-regions`): Địa chỉ của tôi v8, Đăng nhập, Chào mừng, Thiết lập COD › Địa chỉ lấy hàng, Khám phá (Gần bạn without location), Tìm kiếm (`.superdesign/tools/build_{area,login,welcome,cod_setup,home,search}.py`, `region_kit.py`). Server: `/v1/regions`, `/v1/regions/{province_code}/communes`, `/v1/regions/nearest`, `/v1/addresses` with `kind` (merged into server main 94f77a22).
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** the person's area is a commune (2025 merger), read from GPS or picked by hand; sign-in no longer asks for it; Địa chỉ của tôi is the server's address book with Nhà / Công ty / Khác; one commune picker serves every screen that needs a place. Demo keeps working offline.

**Architecture:**
- `:core:model`: `Place(communeCode, commune, province)` with `label` ("Phường Bình Thạnh, Hồ Chí Minh"; the province loses "Thành phố "/"Tỉnh "); `Province(code, name)`, `Commune(code, provinceCode, name)`; `Area(place, located: Boolean)`; `SavedAddress(id, kind, name, phone, street, place, isDefault)`; `AddressBook(addresses, checkoutId)`; `SearchReach(area: Area?, radiusKm, radii)`.
- `:core:data` contracts:
  - `RegionRepository`: `provinces()`, `communes(provinceCode)`, `nearest(lat, lng)`. `NetRegionRepository` (CatalogClient) and `FakeRegionRepository` (fixture dumped from the dev server: every province, the communes of 79, 01 and 48 with their points; nearest by distance over them).
  - `DeviceLocation` port: `permitted()`, `current(): Result<LatLng>` (`DataError.NotFound("location")` when off or timed out). `SystemDeviceLocation` with the platform `LocationManager.getCurrentLocation` (minSdk 31, coarse, 10 s), no Play Services dependency. `FakeDeviceLocation` returns a point in Phường Bình Thạnh.
  - `AreaRepository` (one implementation for both flavors, `PhoneAreaRepository`): `reach(): Flow<SearchReach>`, `locate(): Result<Area>` (GPS → nearest, stored as `located`), `pick(place)` (stored as picked), `setRadius(km)`. DataStore on the phone, not per account: it is where the phone is.
  - `AddressRepository`, split out of `SettingsRepository`: `addresses()`, `save(address, makeDefault)`, `delete(id)`, `restore(address)`, `pickForCheckout(id)`, `setDefault(id)`. `NetAddressRepository` (AccountClient) and the fake moved out of `FakeSettingsRepository`. `SettingsRepository` keeps security, devices and account deletion (Phase 10).
  - `SessionRepository` loses `locate`, `finishSignIn`, `knownArea`, `awaitingArea`, `cancelSignIn`; `signIn` returns `Result<Unit>`. `SessionStore` loses `area` and `signedIn`; a session with a refresh token is signed in.
- `:core:ui`: `RegionPicker` sheet ("Dùng vị trí hiện tại", provinces, communes, search without diacritics) with `RegionPickerViewModel`; `AddressSheet` (kind chips with the hint, name, phone, street, commune tile, default switch) used by Địa chỉ của tôi, Hoàn thiện hồ sơ and Thiết lập COD.
- Features: Đăng nhập and Chào mừng without Khu vực; Địa chỉ của tôi on `AddressRepository`; Khám phá's area chip, radius sheet ("Đổi" opens the picker) and Gần bạn without location; Tôi's area row; Đăng tin's area row from `AreaRepository`.

**Tech:** no new libraries. `ACCESS_COARSE_LOCATION` moves from `feature/auth`'s manifest to `:core:data`'s (the module that reads the location). `codegen.yaml` re-synced from server main for `kind`.

## Global Constraints

Roadmap rules 1–6. Worktree `~/shopnexus/app-wt/wire-regions`, branch `feat/wire-regions`. Commits without Co-Authored-By; prose through `humanizing-writing`. Device work on `ANDROID_SERIAL=emulator-5554` only.

## Rulings

- The area follows the last source the person chose: GPS when they allow location and have not picked, or after "Dùng vị trí hiện tại"; a picked commune ("Bạn chọn") until they use the location again. Without permission and without a pick there is no area: Gần bạn shows "Bật vị trí để xem tin gần bạn" with "Bật vị trí" and "Chọn xã, phường" (decided 2026-11-15).
- A located area is refreshed when Khám phá opens and the stored one is over 30 minutes old; a failed refresh keeps the stored area.
- The area is not the default address. The address book is only where parcels go; the old "the default address sets the area" rule, `areaFromDefault`, `KnownArea` and the area cards in Địa chỉ của tôi go.
- Address kinds: Nhà (deliver all day, evenings too), Công ty (office hours), Khác. `label` and the pickup tag go: the server has neither. Thiết lập COD keeps the pickup it chose in its own seed (Phase 8 wires it).
- The book holds 10 addresses (server `address_limit_reached` → `DataError.Conflict`); "Thêm địa chỉ" hides at 10.
- Undoing a delete creates the address again (new id), and makes it the default again when it was.
- `checkoutId` stays in memory: Giao COD's pick for the next request, as now.
- Listing and seller place labels (`ListingFacts.district`, `Listing.district`, `SellerProfile.district`, `Parcel.district`, `CategoryPage.district`, `DealView.counterpartArea`, `PriceInsight.area`, `SavedSearch.area`) stay until Phase 5/7/8 maps them from the server's `commune`. Own-area fields go now: `MeSummary.district/area`, `SellContext.area/district`, `HomeFeed.district`, `BoostSheet.district`, `SearchEntry.district`; screens read `AreaRepository`.
- The demo fixture's account lives in Phường Bình Thạnh, Hồ Chí Minh; texts that said "Bình Thạnh, TP.HCM" now say "Phường Bình Thạnh, Hồ Chí Minh".

## Review Focus

1. `PhoneAreaRepository`: GPS → nearest → stored as located; a pick holds over GPS until `locate()`; no permission and no pick → `reach().area == null` → `PhoneAreaRepositoryTest`.
2. Sign-in signs in at once; a stored session from before the change (`signedIn=false` with tokens) counts as signed in → `NetSessionRepositoryTest`, `SessionStoreTest`.
3. `NetAddressRepository` sends `kind`, maps `address_limit_reached`, re-creates on restore → `NetAddressRepositoryTest` (MockEngine).
4. `RegionPicker` search ignores diacritics ("ben thanh" → "Phường Bến Thành") → `RegionPickerViewModelTest`.
5. Gần bạn without area shows the two actions; with one shows the chip "Phường Bình Thạnh · 10 km" → `HomeScreenTest`.
6. Walks still pass on demo; AccountWalk signs in without Khu vực.

## Tasks

1. Model and contracts: `Place`, `Province`, `Commune`, `Area`, new `SavedAddress`/`AddressBook`/`SearchReach`; `RegionRepository`, `DeviceLocation`, `AreaRepository`, `AddressRepository`; `SessionRepository` slimmed. Fakes: `FakeRegionRepository` + fixture, `FakeDeviceLocation`, `FakeAddressRepository`; `PhoneAreaRepository` with tests; bindings in `FakeBindings`/`DataModule`.
2. Sign-in without Khu vực: `SessionStore`, `NetSessionRepository`, `FakeSessionRepository`, Login (step dots, AREA step, `areaBack`, `cancelSignIn`) and Welcome (`PickArea`) with their tests and strings.
3. Net: `NetRegionRepository`, `NetAddressRepository`, `SystemDeviceLocation`; codegen re-sync; MockEngine tests.
4. `:core:ui` `RegionPicker` and `AddressSheet` with view-model and screen tests.
5. Địa chỉ của tôi (book rows with kind, menu, `AddressSheet`, 10 limit), Hoàn thiện hồ sơ's address task, Thiết lập COD's book rows and new address, Giao COD's pick, all on `AddressRepository`.
6. Own area: Khám phá (chip, radius sheet with "Đổi", Gần bạn without area, location permission), Tôi's row, Đăng tin's area row and preview place; model fields removed; fakes read `AreaRepository`.
7. Live bindings; gate (touched modules' `check`, walks on demo, `assembleLiveDebug`); emulator against the local server with `adb emu geo fix 106.7049 10.8117`; `/code-review`, `/simplify`; merge into local main; checklist.
