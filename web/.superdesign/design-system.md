# ShopNexus Docs design system

The docs site of ShopNexus, a Vietnamese C2C marketplace for used goods (COD
with inspection at the door, the platform holds no money). Astro 5 + MDX,
Tailwind v4, every page in English and Vietnamese, light and dark themes.
Source of truth for values: `src/styles/tokens.css` and `src/styles/global.css`;
`.superdesign/init/theme.md` has the full table.

## Readers and jobs

- App and console developers: find an endpoint, read its contract (request,
  responses, error codes), call it against production, dev on the cluster or a
  local stack, with a bearer token.
- The thesis committee and new teammates: read how the marketplace works
  (Marketplace, Requirements, Architecture tabs).
- Operators: run and deploy the stack (Operations tab).

## Pages

Top-bar tabs: Get started, Marketplace, Requirements, Architecture, AI agent,
API, Operations. API holds API design, Authentication, Errors, Pagination,
Idempotency, Live updates and Playground. Playground is a wide page that embeds
Scalar's API reference over `/openapi.json` (130 paths, 16 tags in 7 groups:
Accounts, Listings and search, Deals, After the sale, App screens, Staff
console, System).

## Layout

- Top bar: 64px (56px below lg), sticky, `bg-nav` at 90% with backdrop blur,
  bottom border `stroke-soft`. Logo mark 28px + "ShopNexus Docs" (Docs in
  `text-soft`), tab links 14px `text-sub` (active: `text-strong`, weight 500,
  2px underline 14px below), search field 260px with ⌘K/Ctrl K, EN/VI segmented
  switch, theme toggle.
- Doc page: 272px left nav (`bg-nav`, right border), article column max 720px
  in a 1096px container, 232px outline on xl. Padding 16/32/48px.
- Wide page (`wide: true`): no left nav, no outline; the page header stays in
  the 1096px container and the body spans the full width under a top border.

## Type

Inter Variable for UI and text, JetBrains Mono Variable for code, IDs,
endpoints and HTTP methods. Page title 36/44 weight 650 tracking -0.025em;
h2 24/32 weight 600; h3 18/28; body 16/28 (`text-body`); UI 14px; meta 13px
(`text-soft`); code 13–14px. Vietnamese text gets slightly taller line height.
Never use a serif or a display face.

## Colour

Neutral warm greys with one teal brand. Light: page #ffffff, nav #fbfbfa,
subtle #f5f5f3, hover #efefec, selected #e8e8e4; strokes #ecece9 / #dcdcd8 /
#c4c4bf; text #1a1a19 / #3a3a37 / #5e5e5a / #8c8c87; brand #066a61, brand soft
#e6f2f0, brand text #005049. Dark: page #111110, nav #141413, text #ededea,
brand #85d5c9. Status: info #2563eb, warning #c2410c, danger #dc2626, feature
#6d4aff, each with a soft background and a line colour. HTTP methods: GET info
blue, POST brand teal, PUT warning orange, PATCH feature violet, DELETE
danger red. No gradients except a faint brand glow on the home hero.

## Illustrations

Section and empty-state illustrations (`public/img/`) are flat 2D vector art: flat fills only, no
shading, gradients, highlights or 3D. Palette teal #066a61, mint #85d5c9, cream #f3ead8, greys
#d9d4c8 / #a8a39a, charcoal #2b2b29; no red, brown or orange. The mascot is a cream shopping bag
with a teal handle, a grey price tag and a charcoal screen face with mint eyes.

## Shape and depth

Radius 6px (chips, kbd), 8–10px (buttons, inputs, nav items), 12px (code
frames, panels), 16px (cards), 999px (pills, status dots). Borders carry most
of the structure; shadows are light (`--shadow-chip` on segmented controls,
`--shadow-card` on popovers and floating panels).

## Components

Chips (audience, page type) are 12px pills with an icon. Callouts are 12px
panels with a coloured left icon. Segmented controls: `bg-subtle` track,
`bg-page` thumb with `shadow-chip`. Buttons: primary `bg-brand` +
`text-on-brand`, secondary bordered `stroke-sub`. Code blocks: 12px frame,
`bg-subtle`, mono 13.5px. Tables: header row `bg-subtle`, 13–14px cells, 1px
`stroke-soft` rules, inside a 12px rounded scroll frame.

## Motion

Content fades up 8px over 450ms with ease-out-expo (`cubic-bezier(0.16, 1,
0.3, 1)`), staggered d1–d3. Hover states change background only. Respect
reduced motion.

## Playground requirements

- Requests go from the browser straight to the chosen server; there is no
  proxy. Servers: Production `https://api.shopnexus.id.vn`, Dev
  `https://api.dev.shopnexus.id.vn`, Local `http://api.shopnexus.localhost:56481`.
- Auth is a bearer access token (15 minutes) from `POST /v1/auth/email-codes`
  then `POST /v1/auth/sign-in`; the token stays in this browser only.
- Ctrl K belongs to the site search; the API search uses Ctrl J.
- The WebSocket `/v1/ws` cannot be called from the playground.
- Labels on the page are English (API terms); the Vietnamese page keeps them.
