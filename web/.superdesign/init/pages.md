# Pages

## /en/api/playground (API → Playground, wide)
Entry: src/content/docs/en/api/playground.mdx (frontmatter `wide: true`, body `<ApiPlayground />`)
Dependencies:
- src/pages/[lang]/[...slug].astro
  - src/layouts/doc-layout.astro
    - src/layouts/base-layout.astro
      - src/components/layout/top-bar.astro
        - src/components/layout/brand.astro
        - src/components/layout/lang-switch.astro
        - src/components/layout/theme-toggle.astro
    - src/components/layout/page-notices.astro
    - src/components/layout/page-header.astro
    - src/components/layout/mobile-drawer.astro
  - src/components/api/api-playground.astro (Scalar 1.76.4, client-side)
    - src/components/api/scalar-theme.css
- web/public/openapi.json (bundled spec: info.description markdown, 3 servers, 16 tags in 7 x-tagGroups)
- src/styles/tokens.css, src/styles/global.css

## /en/requirements/use-cases
Entry: src/content/docs/en/requirements/use-cases.mdx (`<UseCases />`)
Dependencies:
- src/layouts/doc-layout.astro (as above, plus left-nav.astro, page-footer.astro)
- src/components/requirements/use-cases.astro
  - src/components/requirements/req.astro
  - src/lib/registry.ts (reads ../registry/requirements.yaml and trace.json)
- src/styles/components.css (req-* rules at the end)

## /en/api/errors
Entry: src/content/docs/en/api/errors.mdx
Dependencies:
- src/layouts/doc-layout.astro (+ left-nav, toc, page-footer)
- src/components/requirements/req-table.astro (kind="errors")
- src/styles/prose.css, src/styles/code.css

## /en (home)
Entry: src/pages/[lang]/index.astro
Dependencies:
- src/layouts/base-layout.astro (+ top-bar)
- src/components/home/*.astro, src/components/home/home-strings.ts
- src/styles/home.css
