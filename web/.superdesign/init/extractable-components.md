# Extractable components

## Layout

## TopBar
- Source: `src/components/layout/top-bar.astro` (with `brand.astro`, `lang-switch.astro`, `theme-toggle.astro`)
- Category: layout
- Description: 64px sticky bar: logo mark + "ShopNexus Docs", tab links (active tab underlined), search field with Ctrl K, EN/VI switch, theme toggle.
- Extractable props: activeTab (string, default: "api"), lang (string, default: "en")
- Hardcoded: logo, tab labels, icons, all CSS

## PageHeader
- Source: `src/components/layout/page-header.astro`
- Category: layout
- Description: breadcrumb (tab › group › title), H1, description, chips (audience, page type), reading time, updated date, Copy page button.
- Extractable props: title (string), description (string)
- Hardcoded: chip styles, icons

## LeftNav
- Source: `src/components/layout/left-nav.astro`
- Category: layout
- Description: 272px nav of the tab's groups and pages; active page has a brand bar on the left and `bg-selected`.
- Extractable props: activeItem (string)
- Hardcoded: group labels and page titles of the tab

## Basic

## Callout
- Source: `src/components/mdx/callout.astro`
- Category: basic
- Description: note / tip / warning box with an icon.
- Extractable props: type (string, default: "note")
