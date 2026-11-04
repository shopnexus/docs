# ShopNexus Docs (docs/web)

Documentation site built with Astro 5, MDX and Tailwind v4. The output is static, search runs on Pagefind, and every page exists in English and Vietnamese.

## Run

```bash
cd docs/web
bun install
bun run build      # astro build + Pagefind index → dist/
bun run preview    # serves dist/ at http://localhost:4321
```

| Command | What it does |
|---|---|
| `bun run dev` | Live-reload dev server. Search needs a built index, so run `bun run build` once first. |
| `bun run build` | Public site: Get started, Architecture, API, Operations. |
| `bun run build:internal` | The public site plus the internal Developers tab (`DOCS_INTERNAL=true`). |
| `bun run preview` | Serves the last build. |
| `bun run lint` | Biome check. |
| `bun run check` | `astro check` (types, MDX, components). |

## Writing pages

- A page lives at `src/content/docs/<en|vi>/<tab>/<slug>.mdx` and is served at `/<lang>/<tab>/<slug>`. `index.mdx` is the landing page of a tab or folder. `src/content.config.ts` validates the frontmatter.
- The left nav is built from the frontmatter fields `group`, `groupOrder` and `order`. `related: [urls]` fills the Related rail, and `toc: false` hides the page outline.
- A Vietnamese page that does not exist yet renders the English one under `/vi/...` with a "not translated yet" banner.
- A page with `internal: true` exists only in `build:internal`.
- MDX components need no import: `Callout`, `Steps`/`Step`, `Shot`, `Tabs`/`Tab`, `Cards`/`Card`, `Prereqs`, `KeyRules`, `Accordion`/`AccordionGroup`, `UI`, `Term`, `Kbd` and `Glossary`. Glossary terms are in `src/data/glossary.ts`.
- A fenced block with the language `mermaid` is drawn as a diagram in the site's colours and redrawn when the theme changes. `title="…"` sets the caption. The renderer is `src/scripts/mermaid.ts` and loads only on pages that have a diagram.
- Tables are wrapped in a scroll frame by `src/lib/markdown/rehype-table-wrap.ts`.
- Tabs are declared in `src/lib/tabs.ts` and the home page copy in `src/components/home/home-strings.ts`.

## Branding

- The product name is `SITE_NAME` in `src/lib/i18n.ts`.
- Colours are tokens in `src/styles/tokens.css`, one block for light and one for dark.
- The logo is `public/brand/mark.svg` and `mark-dark.svg`, and the favicon is `public/favicon.svg`.

## Serving under a path

`DOCS_BASE=/docs bun run build` builds the site for a path prefix. Write every link and image root-relative (`/en/guides`, `/shots/home.png`) as if the site owned `/`. Markdown links and images get the base from `src/lib/markdown/rehype-base-links.ts`, and components wrap theirs in `withBase()` from `src/lib/base.ts`.

## Images

Put screenshots and illustrations under `public/` and reference them by their path there, for example `<Shot src="/shots/home.png" />`. `<Shot>` reads the image's size at build time, so its crop and hotspot coordinates are in source pixels.
