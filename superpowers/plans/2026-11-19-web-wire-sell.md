# Web: selling through the server

Branch `feat/web-wire-sell` in `website-wt/sell`.

## Goal

Đăng tin (`/sell`) posts a real listing; `/sell?edit=<id>` edits one; Tin của
bạn (`/me/listings`) lists the seller's listings, drafts and sold items with
their numbers and actions. Cách đăng tin becomes a static guide.

## Rulings

- `/sell` is behind sign-in. One `<form method="post">`: `step=post` (POST
  /v1/listings, or PUT /v1/listings/{id} in edit mode, each with the form's
  Idempotency-Key), `step=draft` (PUT /v1/listing-drafts/{id}, PRG to
  `?draft=<id>&saved`). Errors re-render the form with field errors.
- Photos upload from the browser (`uploadPhoto`), each tile carries a hidden
  `photo` input; order is the post order, the first is the cover.
- Drafts: the web mints a UUIDv7 and writes its own body layout,
  `schema_version` 100 (`lib/sell.ts`); an app draft (version 1) opens with its
  title, price and photos. The script autosaves (debounced) through
  `/api/listing-drafts/<id>` and puts `?draft=` in the address, so a reload
  keeps the form. A failed post saves the draft too, for the photo previews. A
  post from a draft deletes it.
- Listing read: "AI điền giúp" POSTs `/api/listing-reads {photo: cover}`, polls
  `/api/listing-reads/<id>` every 2 s up to 90 s, fills the fields the read has.
- Price guide: `/api/price-guides` once title, category, condition and commune
  are set (debounced); the panel shows the range, the two suggestions, the
  watchers at the typed price and up to 4 similar listings; hidden when the
  guide is empty or fails.
- Category guess (`/api/category-guesses`) when the title changes and no category is chosen.
- Location: province + commune selects, default from the default address; the
  commune script is shared with Địa chỉ (`lib/commune-picker.ts`).
- No phone: a notice linking to `/me/security?add-phone`, the post button off
  (`phone_required` from the server says the same). Caps from
  `/v1/screens/reputation` (`caps.listings`).
- Tin của bạn: `?pane=on_sale|drafts|sold`, PRG form posts for hide, unhide,
  mark sold, unmark sold, delete, delete draft; `?done=` shows the result.
- Cách đăng tin: a static four-step guide with a link to Đăng tin.

## Deviations as built

- Edit is `PUT /v1/listings/{id}` (the brief said PATCH; the server has PUT, the whole listing).
- The row actions sit in a native `<details>` ⋮ menu of form buttons, no script.
- Week tiles: views, askers, saves; the cap shows in the title's meta line.
- Order chip links to `/messages?deal=<deal_id>` (the seller's order screen is still mock).
- "Đăng lại" (photo-copies), video and Chợ Tốt link reads are left out (the web has no UI for them).
- The price panel stays hidden in dev: the guide answers no estimate, suggestions or similar listings.
