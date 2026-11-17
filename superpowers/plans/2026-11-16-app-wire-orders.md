# App wiring, Phase 8: orders, shipping and support

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`. Starting points: app `e2e99da7`, server `ddb07d59`. Phase 7 messaging is wired; live order mutations currently return `order_steps_unavailable`. App behavior follows the approved mockups; changed screens need approval before UI implementation.

## Goal

Wire COD checkout, shipment creation/editing, receipt confirmation, existing-carrier linking, support and order reviews. Preserve the selected order across a deal's repeated purchases. Use the existing uploader, account-scoped server state, chat transport and update stream.

## Product decisions — 2026-11-16

- Link existing GHTK/GHN accounts only. Remove the GHTK account-creation choice and its consent/loading promises in both flavors.
- Reviews have stars and optional short text, with edit/delete within seven days of their first submission. Reposting after deletion does not start another window.
- Keep the app simple and concise; change backend contracts to fit it. No extra screens just to expose API operations.
- No trustworthy pre-order shipping estimator exists. The initial checkout response may have no estimate; the mockup must represent that honestly and must not present zero shipping as a final total.
- Real carrier credentials are outside local verification. Use `CARRIER=fake` for tests; production remains configured as before.

## Global constraints

- Work in topic worktrees. Keep main's uncommitted `run.sh` and `gradle.properties` unchanged. Merge locally after checks; do not push.
- Server work is spec-first and follows `ARCHITECTURE.md`. No authorization relaxation, new credential defaults, or buyer-triggered calls using seller carrier credentials before COD.
- DTOs stay in network/net implementations. Update fakes alongside model/contract changes. Do not combine real order IDs with fake setup/support records.
- Testing: JVM domain/data/VM, retained interaction/accessibility tests and the five walks. UI test dependencies are opt-in through `core:testing-ui`. No new visual Robolectric suites.
- Credentials never enter saved state, queued requests, logs or committed files. Shipment/support retry keys, bodies and target IDs do persist where required.

## Backend contracts

### Selected order and own review

`GET /v1/screens/order/{order_id}` composes the current `Deal`, the requested canonical `Order`, the public counterpart `Person`, the buyer's `own_review`, and their order support ticket when present. A seller gets no buyer-private review state or ticket. Unknown/foreign orders return `order_not_found`.

- The requested order may be historical; do not replace it with `deal.order`.
- Reuse current address/pickup redaction. A buyer never receives the pickup; cancelled-order seller reads omit recipient street and phone.
- Expose the stored completion actor consistently on canonical Order when completed; do not infer it from message history.
- `own_review`: state `none|active|deleted`; nullable id and original creation/update/change-until times before the first submission; stars/text only while active; `locked` from the mutation's existing domain rule.
- Keep review PUT/DELETE and validation rules. No duplicate standalone GET-review endpoint is needed.

Cancellation must name the intended order. Add `POST /v1/orders/{order_id}/cancel` using the existing cancellation use case and authorization. Check under the existing optimistic concurrency rules that this is still the current pending order; never let an old order screen cancel a newer purchase. Preserve the separate deal-agreement cancellation endpoint.

### Pickup preference and setup

`PUT /v1/me/shipping-settings` replaces `{pickup: null | {address_id, phone}}`. Shipping owns the preference. Validate that the referenced address belongs to the caller and normalize the contact phone. It is not a verified identity.

`GET /v1/screens/cod-setup` composes MyAccount, its addresses, shipping settings and linked carrier accounts. Reuse existing list/link/unlink/pickup endpoints. Do not invent a verified carrier holder or historical carrier-account provenance.

- Edits follow the referenced book address. Deleting that address clears the pickup preference and its separate contact phone; old shipment snapshots are unchanged.
- Linked `pickup_from` gains an explicit saved-pickup selector, mutually exclusive with the existing address and carrier-point selectors. Quote accepts the same selector.
- The saved selection resolves to the caller's current display name, stored pickup phone and owned address; shipment creation snapshots them.
- An unconfigured saved selection returns `pickup_not_configured`. Omitted selection keeps today's carrier-default behavior.

### Buyer checkout

`GET /v1/screens/cod-checkout/{deal_id}?address_id=...` is buyer-only and returns the deal, public seller, selected/default owned Address or null, COD cap `{used,max}`, and nullable advisory `shipping_estimate {low,high}`.

- An explicitly supplied missing/foreign address returns `address_not_found`; a foreign/nonbuyer deal returns `deal_not_found`.
- No address book means address null, not a fabricated address.
- GET creates/reserves nothing and sends no buyer address to a carrier. Existing POST COD remains authoritative and snapshots price/address.
- Return a null estimate initially; do not copy demo fee bands into live behavior.

### Support invalidation

Reuse existing ticket list, order-ticket lookup and chat Screen to resolve ticket/conversation details. Add stream kind `ticket` carrying `conversation_id`, addressed only to the ticket owner and written inside the ticket transaction for creation/first-message attachment, resolve and reopen, including asynchronous reopen. Message/read updates still cover message contents and unread state.

## App implementation slices

1. **Mockups:** existing-account-only carrier step; review new/edit/locked/delete states; checkout with unknown shipping fee. Approval before UI code.
2. **Server contracts:** selected-order/own-review read and order-scoped cancellation; ticket invalidation; pickup persistence and quote/create integration; setup and checkout Screens. Sync OpenAPI after review/gate.
3. **Setup and support:** shared server reads for setup, carrier links and preferences; support uses NetChat for sending/paging/read and the new ticket invalidation. Replace each fake binding only after its complete flow works.
4. **Order lifecycle:** explicit OrderId in commands/drafts/routes; history from `GET /v1/screens/orders?role=` (each order with its counterpart and the buyer's own review; it replaced `GET /v1/me/orders`, whose only caller was the app); selected address ID in checkout; quote/lookup, shipment create/edit, confirmation, cancellation, reviews and push reconciliation.

Hide or disable fixture-only order links from remaining live fake profile/listing/notification sources at their composition boundary. Do not bring all of Phases 9–10 forward to solve that dependency.

## Review focus

- [ ] Old order routes, reports and retry queues cannot act on a newer order of the same deal.
- [ ] Recipient/pickup snapshots survive later book edits, and redacted fields remain absent.
- [ ] Creating/editing a shipment preserves the selected carrier, service, pickup and weight through a retry; passwords/tokens are never persisted.
- [ ] Lost COD/cancel responses are reconciled before trying again; idempotent operations reuse their original keys and exact payloads.
- [ ] Reviews use original submission time, including deleted/reposted reviews; account and order ownership hold.
- [ ] Support status pushes follow commit and reach only the owner; reopening cannot be lost behind the earlier message push.
- [ ] Fake and live share UI contracts; no live operation targets fixture IDs.

## Verification

Server: touched packages with `-p 4`, full e2e response coverage and lint, on a coordinated shared test stack. App: mapper/MockEngine/VM tests, retained callback tests, five walks, lint/detekt/spotless and both APKs. Local two-account verification uses `CARRIER=fake` for link, quote, create/edit, delivery/confirmation, support and reviews. Real carrier acceptance/fees/webhooks require separate provider credentials and are reported as unverified.
