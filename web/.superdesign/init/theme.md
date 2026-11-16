# Theme

## Part 1 — Token summary

Fonts: Inter Variable (UI and body), JetBrains Mono Variable (code), both self-hosted via `@fontsource-variable`. Weights in use: 400, 500, 600, 650 (headings).

Type scale: page title 36/44 (28/34 below md) weight 650, tracking -0.025em; prose h2 24/32; h3 18/28; body 16/28; small UI 13–14px; code 14px; kbd 11.5px.

Layout: top bar 64px, sticky. Left nav 272px (`bg-nav`, right border `stroke-soft`). Article max 720px inside a 1096px container with 48px gap; right outline 232px on xl. Side padding 16 / 32 / 48px (base / sm / lg). Wide pages: header in the 1096px container, body full width.

Radius: 6px (chips, kbd), 8px (inputs, small cards), 12px (code frames), 16px (cards, panels), 999px (pills). Shadows: `--shadow-chip`, `--shadow-card`, `--shadow-shot`, `--shadow-pop`.

Theme switches with `:root[data-theme="light"|"dark"]` (system / light / dark toggle in the top bar). Tailwind colour names map to the tokens in `src/styles/global.css` `@theme inline` (`bg-page`, `bg-nav`, `text-strong`, `text-sub`, `text-faint`, `border-line`, `text-brand`, …).

| Token | Light | Dark |
|---|---|---|
| `--bg-page` | `#ffffff` | `#111110` |
| `--bg-nav` | `#fbfbfa` | `#141413` |
| `--bg-subtle` | `#f5f5f3` | `#1b1b19` |
| `--bg-hover` | `#efefec` | `#232321` |
| `--bg-selected` | `#e8e8e4` | `#2a2a27` |
| `--bg-raised` | `#ffffff` | `#1b1b19` |
| `--stroke-soft` | `#ecece9` | `#262624` |
| `--stroke-sub` | `#dcdcd8` | `#33332f` |
| `--stroke-strong` | `#c4c4bf` | `#45453f` |
| `--text-strong` | `#1a1a19` | `#ededea` |
| `--text-body` | `#3a3a37` | `#c9c9c4` |
| `--text-sub` | `#5e5e5a` | `#a3a39e` |
| `--text-soft` | `#8c8c87` | `#75756f` |
| `--brand` | `#066a61` | `#85d5c9` |
| `--brand-soft` | `#e6f2f0` | `rgba(133, 213, 201, 0.14)` |
| `--brand-line` | `#c2e0db` | `#163330` |
| `--brand-text` | `#005049` | `#97e7db` |
| `--on-brand` | `#ffffff` | `#003732` |
| `--link` | `#005049` | `#97e7db` |
| `--link-line` | `rgba(0, 80, 73, 0.3)` | `rgba(151, 231, 219, 0.3)` |
| `--info` | `#2563eb` | `#6ea0ff` |
| `--info-soft` | `#eef4ff` | `rgba(110, 160, 255, 0.12)` |
| `--info-line` | `#d6e4ff` | `#1f2d4d` |
| `--warning` | `#c2410c` | `#f59e5b` |
| `--warning-soft` | `#fff4eb` | `rgba(245, 158, 91, 0.12)` |
| `--warning-line` | `#fcdcc4` | `#4a2f1c` |
| `--danger` | `#dc2626` | `#f87171` |
| `--danger-soft` | `#fef1f1` | `rgba(248, 113, 113, 0.12)` |
| `--danger-line` | `#fbd5d5` | `#4a2222` |
| `--feature` | `#6d4aff` | `#a48bff` |
| `--feature-soft` | `#f3f0ff` | `rgba(164, 139, 255, 0.14)` |
| `--feature-line` | `#e4dcff` | `#3a2f66` |
| `--inverse-bg` | `#1a1a19` | `#ededea` |
| `--inverse-fg` | `#fffffe` | `#111110` |
| `--mark-bg` | `rgba(6, 106, 97, 0.16)` | `rgba(133, 213, 201, 0.2)` |
| `--scrim` | `rgba(26, 26, 25, 0.25)` | `rgba(0, 0, 0, 0.5)` |
| `--shadow-card` | `0 6px 20px -8px rgba(20, 20, 19, 0.18)` | `0 6px 20px -8px rgba(0, 0, 0, 0.6)` |
| `--shadow-shot` | `0 12px 32px -12px rgba(20, 20, 19, 0.18)` | `0 12px 32px -12px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.04)` |
| `--shadow-pop` | `0 24px 64px -16px rgba(20, 20, 19, 0.35), 0 2px 6px rgba(20, 20, 19, 0.06)` | `0 24px 64px -16px rgba(0, 0, 0, 0.7), 0 0 0 1px rgba(255, 255, 255, 0.04)` |
| `--shadow-chip` | `0 1px 2px rgba(20, 20, 19, 0.06)` | `0 1px 2px rgba(0, 0, 0, 0.4)` |
| `--dots` | `#dcdcd8` | `#2a2a27` |
| `--glow` | `rgba(6, 106, 97, 0.1)` | `rgba(133, 213, 201, 0.12)` |
| `--diagram-node` | `#ffffff` | `#1b1b19` |
| `--diagram-store` | `#e6f2f0` | `#16302c` |
| `--diagram-line` | `#8fc4bc` | `#2f6b63` |
| `--diagram-edge` | `#8c8c87` | `#75756f` |
| `--diagram-text` | `#1a1a19` | `#ededea` |

## Part 2 — Raw sources

### `src/styles/tokens.css`

```css
/* Docs design tokens — docs DS §3. `data-theme` on <html> always holds the resolved theme. */
:root,
:root[data-theme="light"] {
  color-scheme: light;
  --bg-page: #ffffff;
  --bg-nav: #fbfbfa;
  --bg-subtle: #f5f5f3;
  --bg-hover: #efefec;
  --bg-selected: #e8e8e4;
  --bg-raised: #ffffff;
  --stroke-soft: #ecece9;
  --stroke-sub: #dcdcd8;
  --stroke-strong: #c4c4bf;
  --text-strong: #1a1a19;
  --text-body: #3a3a37;
  --text-sub: #5e5e5a;
  --text-soft: #8c8c87;
  --brand: #066a61;
  --brand-soft: #e6f2f0;
  --brand-line: #c2e0db;
  --brand-text: #005049;
  --on-brand: #ffffff;
  --link: #005049;
  --link-line: rgba(0, 80, 73, 0.3);
  --info: #2563eb;
  --info-soft: #eef4ff;
  --info-line: #d6e4ff;
  --warning: #c2410c;
  --warning-soft: #fff4eb;
  --warning-line: #fcdcc4;
  --danger: #dc2626;
  --danger-soft: #fef1f1;
  --danger-line: #fbd5d5;
  --feature: #6d4aff;
  --feature-soft: #f3f0ff;
  --feature-line: #e4dcff;
  --inverse-bg: #1a1a19;
  --inverse-fg: #fffffe;
  --mark-bg: rgba(6, 106, 97, 0.16);
  --scrim: rgba(26, 26, 25, 0.25);
  --shadow-card: 0 6px 20px -8px rgba(20, 20, 19, 0.18);
  --shadow-shot: 0 12px 32px -12px rgba(20, 20, 19, 0.18);
  --shadow-pop: 0 24px 64px -16px rgba(20, 20, 19, 0.35), 0 2px 6px rgba(20, 20, 19, 0.06);
  --shadow-chip: 0 1px 2px rgba(20, 20, 19, 0.06);
  --dots: #dcdcd8;
  --glow: rgba(6, 106, 97, 0.1);
  /* Mermaid needs plain hex: it mixes these colours itself (src/scripts/mermaid.ts). */
  --diagram-node: #ffffff;
  --diagram-store: #e6f2f0;
  --diagram-line: #8fc4bc;
  --diagram-edge: #8c8c87;
  --diagram-text: #1a1a19;
}

:root[data-theme="dark"] {
  color-scheme: dark;
  --bg-page: #111110;
  --bg-nav: #141413;
  --bg-subtle: #1b1b19;
  --bg-hover: #232321;
  --bg-selected: #2a2a27;
  --bg-raised: #1b1b19;
  --stroke-soft: #262624;
  --stroke-sub: #33332f;
  --stroke-strong: #45453f;
  --text-strong: #ededea;
  --text-body: #c9c9c4;
  --text-sub: #a3a39e;
  --text-soft: #75756f;
  --brand: #85d5c9;
  --brand-soft: rgba(133, 213, 201, 0.14);
  --brand-line: #163330;
  --brand-text: #97e7db;
  --on-brand: #003732;
  --link: #97e7db;
  --link-line: rgba(151, 231, 219, 0.3);
  --info: #6ea0ff;
  --info-soft: rgba(110, 160, 255, 0.12);
  --info-line: #1f2d4d;
  --warning: #f59e5b;
  --warning-soft: rgba(245, 158, 91, 0.12);
  --warning-line: #4a2f1c;
  --danger: #f87171;
  --danger-soft: rgba(248, 113, 113, 0.12);
  --danger-line: #4a2222;
  --feature: #a48bff;
  --feature-soft: rgba(164, 139, 255, 0.14);
  --feature-line: #3a2f66;
  --inverse-bg: #ededea;
  --inverse-fg: #111110;
  --mark-bg: rgba(133, 213, 201, 0.2);
  --scrim: rgba(0, 0, 0, 0.5);
  --shadow-card: 0 6px 20px -8px rgba(0, 0, 0, 0.6);
  --shadow-shot: 0 12px 32px -12px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.04);
  --shadow-pop: 0 24px 64px -16px rgba(0, 0, 0, 0.7), 0 0 0 1px rgba(255, 255, 255, 0.04);
  --shadow-chip: 0 1px 2px rgba(0, 0, 0, 0.4);
  --dots: #2a2a27;
  --glow: rgba(133, 213, 201, 0.12);
  --diagram-node: #1b1b19;
  --diagram-store: #16302c;
  --diagram-line: #2f6b63;
  --diagram-edge: #75756f;
  --diagram-text: #ededea;
}
```


### `src/styles/global.css`

```css
@import "tailwindcss";
@import "./tokens.css";
@import "./base.css" layer(components);
@import "./prose.css" layer(components);
@import "./code.css" layer(components);
@import "./diagram.css" layer(components);
@import "./components.css" layer(components);
@import "./motion.css" layer(components);

@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *));

@theme inline {
  --font-sans: "Inter Variable", ui-sans-serif, system-ui, sans-serif;
  --font-mono: "JetBrains Mono Variable", ui-monospace, SFMono-Regular, monospace;

  --color-page: var(--bg-page);
  --color-nav: var(--bg-nav);
  --color-subtle: var(--bg-subtle);
  --color-hover: var(--bg-hover);
  --color-selected: var(--bg-selected);
  --color-raised: var(--bg-raised);
  --color-line: var(--stroke-soft);
  --color-line-sub: var(--stroke-sub);
  --color-line-strong: var(--stroke-strong);
  --color-strong: var(--text-strong);
  --color-body: var(--text-body);
  --color-sub: var(--text-sub);
  --color-faint: var(--text-soft);
  --color-brand: var(--brand);
  --color-brand-soft: var(--brand-soft);
  --color-brand-line: var(--brand-line);
  --color-brand-text: var(--brand-text);
  --color-on-brand: var(--on-brand);
  --color-info: var(--info);
  --color-info-soft: var(--info-soft);
  --color-info-line: var(--info-line);
  --color-warning: var(--warning);
  --color-warning-soft: var(--warning-soft);
  --color-warning-line: var(--warning-line);
  --color-danger: var(--danger);
  --color-danger-soft: var(--danger-soft);
  --color-danger-line: var(--danger-line);
  --color-feature: var(--feature);
  --color-feature-soft: var(--feature-soft);
  --color-feature-line: var(--feature-line);
  --color-inverse: var(--inverse-bg);
  --color-on-inverse: var(--inverse-fg);
  --shadow-lift: var(--shadow-card);
  --shadow-frame: var(--shadow-shot);
  --shadow-popover: var(--shadow-pop);
  --shadow-segment: var(--shadow-chip);

  --ease-out-expo: cubic-bezier(0.16, 1, 0.3, 1);
}
```


### `src/styles/base.css`

```css
html {
  background: var(--bg-page);
  color: var(--text-strong);
  font-family: "Inter Variable", ui-sans-serif, system-ui, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
  scroll-padding-top: 88px;
  interpolate-size: allow-keywords;
}

body {
  min-height: 100dvh;
}

::selection {
  background: var(--mark-bg);
}

:focus-visible {
  outline: 2px solid var(--brand);
  outline-offset: 2px;
  border-radius: 6px;
}

.no-scrollbar {
  scrollbar-width: none;
}
.no-scrollbar::-webkit-scrollbar {
  width: 0;
  height: 0;
}
.thin-scrollbar {
  scrollbar-width: thin;
  scrollbar-color: var(--stroke-sub) transparent;
}

/* Product UI label chip — always the English label. */
.uilabel {
  font-weight: 600;
  font-size: 0.875em;
  padding: 1px 7px;
  border-radius: 6px;
  background: var(--bg-subtle);
  border: 1px solid var(--stroke-soft);
  color: var(--text-strong);
  white-space: nowrap;
}

.kbd {
  font-family: "Inter Variable", ui-sans-serif, system-ui, sans-serif;
  font-size: 11.5px;
  font-weight: 500;
  min-width: 20px;
  height: 20px;
  padding: 0 5px;
  border-radius: 6px;
  border: 1px solid var(--stroke-soft);
  background: var(--bg-subtle);
  color: var(--text-sub);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  line-height: 1;
  vertical-align: 1px;
}

.prose-link,
.prose a:not(.heading-anchor):not(.card):not([data-plain]) {
  color: var(--link);
  text-decoration: underline;
  text-decoration-color: var(--link-line);
  text-underline-offset: 3px;
  transition: text-decoration-color 0.15s;
}
.prose-link:hover,
.prose a:not(.heading-anchor):not(.card):not([data-plain]):hover {
  text-decoration-color: var(--link);
}

mark.hl,
.search-excerpt mark {
  background: var(--mark-bg);
  color: var(--brand-text);
  border-radius: 3px;
  padding: 0 1px;
  font-weight: 600;
}

/* Segmented control (language, theme). */
.segmented {
  display: flex;
  align-items: center;
  background: var(--bg-subtle);
  padding: 2px;
  border-radius: 10px;
  font-size: 12.5px;
  font-weight: 500;
}
.segmented > * {
  height: 28px;
  padding: 0 10px;
  border-radius: 8px;
  color: var(--text-sub);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  transition:
    color 0.15s,
    background-color 0.15s;
}
.segmented > *:hover {
  color: var(--text-strong);
}
.segmented > [aria-current="true"],
.segmented > [aria-pressed="true"] {
  background: var(--bg-raised);
  color: var(--text-strong);
  box-shadow: var(--shadow-chip);
}
:root[data-theme="dark"] .segmented > [aria-current="true"],
:root[data-theme="dark"] .segmented > [aria-pressed="true"] {
  background: var(--bg-selected);
}

/* Section illustrations are colourful 3D PNGs; soften them a touch in dark mode. */
:root[data-theme="dark"] img.illus {
  filter: brightness(0.92) saturate(0.95);
}
```


### `src/styles/prose.css`

```css
/* Reading styles for MDX bodies — docs DS §4. */
.prose {
  font-size: 16px;
  line-height: 28px;
  color: var(--text-body);
}
.prose > :first-child {
  margin-top: 0;
}
.prose :where(p) {
  margin-top: 12px;
}
.prose :where(h2) {
  margin-top: 48px;
  font-size: 24px;
  line-height: 32px;
  font-weight: 600;
  letter-spacing: -0.015em;
  color: var(--text-strong);
}
.prose :where(h3) {
  margin-top: 32px;
  font-size: 18px;
  line-height: 28px;
  font-weight: 600;
  color: var(--text-strong);
}
.prose :where(h4) {
  margin-top: 24px;
  font-size: 16px;
  line-height: 24px;
  font-weight: 600;
  color: var(--text-strong);
}
.prose :where(h2, h3) + :where(p, ul, ol) {
  margin-top: 12px;
}
.prose .heading {
  position: relative;
  scroll-margin-top: 88px;
}
.prose .heading-anchor {
  display: inline-flex;
  margin-left: 8px;
  vertical-align: middle;
  color: var(--text-soft);
  opacity: 0;
  transition:
    opacity 0.15s,
    color 0.15s;
}
.prose .heading:hover .heading-anchor,
.prose .heading-anchor:focus-visible {
  opacity: 1;
}
.prose .heading-anchor:hover {
  color: var(--text-strong);
}
.prose :where(strong) {
  font-weight: 600;
  color: var(--text-strong);
}
.prose :where(ul, ol) {
  margin-top: 12px;
  padding-left: 22px;
}
.prose :where(ul) {
  list-style: disc;
}
.prose :where(ol) {
  list-style: decimal;
}
.prose :where(li) {
  margin-top: 6px;
  padding-left: 2px;
}
.prose :where(li)::marker {
  color: var(--text-soft);
}
.prose :where(ul ul, ol ol, ul ol, ol ul) {
  margin-top: 6px;
}
.prose :where(hr) {
  margin: 40px 0;
  border-color: var(--stroke-soft);
}
.prose :where(blockquote) {
  margin-top: 16px;
  padding-left: 16px;
  border-left: 2px solid var(--stroke-sub);
  color: var(--text-sub);
}
.prose :where(:not(pre) > code) {
  font-family: "JetBrains Mono Variable", ui-monospace, monospace;
  font-size: 14px;
  padding: 1px 5px;
  border-radius: 6px;
  background: var(--bg-subtle);
  border: 1px solid var(--stroke-soft);
  color: var(--text-strong);
  overflow-wrap: anywhere;
}
.prose :where(img:not(.shot-img):not(.illus)) {
  margin-top: 20px;
  border-radius: 12px;
  border: 1px solid var(--stroke-soft);
  box-shadow: var(--shadow-shot);
}

/* Tables: quiet header, horizontal rules only, scroll on narrow screens. */
.prose :where(.table-wrap) {
  margin-top: 20px;
  overflow-x: auto;
  border: 1px solid var(--stroke-soft);
  border-radius: 12px;
  scrollbar-width: thin;
}
.prose :where(table) {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  font-size: 14.5px;
  line-height: 23px;
}
.prose :where(tbody td:first-child) {
  color: var(--text-strong);
  font-weight: 500;
}
.prose :where(thead th) {
  background: var(--bg-subtle);
  color: var(--text-strong);
  font-weight: 600;
  text-align: left;
  font-size: 13px;
}
.prose :where(th, td) {
  padding: 10px 14px;
  vertical-align: top;
  border-bottom: 1px solid var(--stroke-soft);
}
.prose :where(tbody tr:last-child td) {
  border-bottom: 0;
}
.prose :where(td) {
  min-width: 120px;
}

/* Vietnamese diacritics stack: a little more line-height, never tighter tracking. */
:root[lang="vi"] .prose {
  line-height: 29.5px;
}
:root[lang="vi"] :where(h1, h2, h3) {
  letter-spacing: -0.015em !important;
}

@media (max-width: 640px) {
  .prose {
    font-size: 15.5px;
    line-height: 26px;
  }
  .prose :where(h2) {
    margin-top: 36px;
    font-size: 21px;
    line-height: 28px;
  }
}
```
