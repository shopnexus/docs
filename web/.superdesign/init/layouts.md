# Layouts

`BaseLayout` is the HTML shell (head, theme bootstrap, `ClientRouter`, top bar, search dialog). `DocLayout` adds the 272px left nav (`LeftNav`), the 720px article with `PageHeader`, the prose body and `PageFooter`, and the 232px right outline (`Toc`) on xl. `wide: true` pages drop the left nav and outline and give the body full width (used by API → Playground).

## `src/layouts/base-layout.astro`

```astro
---
import "@fontsource-variable/inter";
import "@fontsource-variable/jetbrains-mono";
import "../styles/global.css";
import { ClientRouter } from "astro:transitions";
import TopBar from "../components/layout/top-bar.astro";
import SearchModal from "../components/search/search-modal.astro";
import { withBase } from "../lib/base";
import { type Lang, SITE_TITLE, STRINGS } from "../lib/i18n";
import type { PageLink } from "../lib/related";

interface Props {
  title: string;
  description?: string;
  lang: Lang;
  tabId?: string;
  /** Same page in the other language. */
  altUrl: string;
  /** Pages suggested in the empty search state. */
  suggestions?: PageLink[];
}

const { title, description, lang, tabId, altUrl, suggestions = [] } = Astro.props;
const t = STRINGS[lang];
const fullTitle = title === SITE_TITLE ? title : `${title} · ${SITE_TITLE}`;
---

<!doctype html>
<html lang={lang} data-theme="light" transition:animate="none">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{fullTitle}</title>
    {description && <meta name="description" content={description} />}
    <meta name="theme-color" content="#FBFBFA" media="(prefers-color-scheme: light)" />
    <meta name="theme-color" content="#141413" media="(prefers-color-scheme: dark)" />
    <link rel="icon" type="image/svg+xml" href={withBase("/favicon.svg")} />
    <link rel="alternate" hreflang={lang === "en" ? "vi" : "en"} href={withBase(altUrl)} />
    <link rel="apple-touch-icon" href={withBase("/brand/app-icon.png")} />
    <meta property="og:image" content={withBase("/brand/app-icon.png")} />
    <meta property="og:title" content={fullTitle} />
    <script is:inline>
      (() => {
        const apply = (doc) => {
          let pref = "system";
          try {
            pref = localStorage.getItem("docs-theme") || "system";
          } catch {}
          const dark = pref === "dark" || (pref === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
          doc.documentElement.dataset.theme = dark ? "dark" : "light";
          doc.documentElement.dataset.themePref = pref;
        };
        apply(document);
        if (!window.__docsTheme) {
          window.__docsTheme = apply;
          document.addEventListener("astro:before-swap", (e) => apply(e.newDocument));
        }
      })();
    </script>
    <ClientRouter />
  </head>
  <body class="bg-page text-strong">
    <a href="#main" class="sr-only focus:not-sr-only focus:fixed focus:left-3 focus:top-3 focus:z-50 focus:px-3 focus:py-2 focus:rounded-lg focus:bg-raised focus:shadow-popover">{t.skip}</a>
    <TopBar lang={lang} tabId={tabId} altUrl={altUrl} />
    <slot />
    <SearchModal lang={lang} suggestions={suggestions} />
    <div hidden data-page-meta data-lang={lang} data-tab={tabId ?? ""} data-alt-url={withBase(altUrl)}></div>
    <script>
      import "../scripts/main";
    </script>
  </body>
</html>
```

## `src/layouts/doc-layout.astro`

```astro
---
import type { MarkdownHeading } from "astro";
import LeftNav from "../components/layout/left-nav.astro";
import MobileDrawer from "../components/layout/mobile-drawer.astro";
import MobileToc from "../components/layout/mobile-toc.astro";
import PageFooter from "../components/layout/page-footer.astro";
import PageHeader from "../components/layout/page-header.astro";
import PageNotices from "../components/layout/page-notices.astro";
import Toc from "../components/layout/toc.astro";
import type { DocPage, NavGroup } from "../lib/content";
import { contentEnter } from "../lib/motion";
import { type PageLink, toLink } from "../lib/related";
import BaseLayout from "./base-layout.astro";

interface Props {
  page: DocPage;
  altUrl: string;
  headings: MarkdownHeading[];
  groups: NavGroup[];
  prev?: DocPage;
  next?: DocPage;
  related: PageLink[];
  suggestions: PageLink[];
  markdown: string;
}

const { page, altUrl, headings, groups, prev, next, related, suggestions, markdown } = Astro.props;
const { lang, tab, entry, fallback } = page;
const tocHeadings = headings.filter((h) => h.depth === 2 || h.depth === 3);
const wide = entry.data.wide;
const showToc = entry.data.toc && !wide;
const { crumb } = toLink(page);
// Fallback pages repeat English content under /vi; only the original is indexed.
const indexed = !fallback;
const markdownJson = JSON.stringify(markdown).replace(/</g, "\\u003c");
---

<BaseLayout
  title={entry.data.title}
  description={entry.data.description}
  lang={lang}
  tabId={tab.id}
  altUrl={altUrl}
  suggestions={suggestions}
>
  <div class="flex">
    {
      !wide && (
        <aside
          class="hidden lg:block w-[272px] shrink-0 sticky top-16 h-[calc(100dvh-64px)] overflow-y-auto no-scrollbar border-r border-line bg-nav"
          transition:persist={`nav-${lang}-${tab.id}`}
          data-nav-scroll
        >
          <LeftNav groups={groups} currentUrl={page.url} />
        </aside>
      )
    }
    <main id="main" class="flex-1 min-w-0" transition:name="docs-content" transition:animate={contentEnter}>
      {showToc && tocHeadings.length > 1 && <MobileToc lang={lang} headings={tocHeadings} />}
      {
        wide ? (
          <>
            <div
              class="px-4 sm:px-8 lg:px-12 pt-6 lg:pt-10 pb-6 max-w-[1096px]"
              data-pagefind-body={indexed ? "" : undefined}
              data-pagefind-filter={indexed ? `lang:${lang}` : undefined}
              data-pagefind-meta={indexed ? `crumb:${crumb}` : undefined}
            >
              {indexed && <span hidden data-pagefind-filter={`section:${tab.id}`} />}
              <PageNotices page={page} />
              <PageHeader page={page} />
            </div>
            <div class="fade-up d3 border-t border-line" lang={fallback ? "en" : lang} data-doc-body>
              <slot />
            </div>
          </>
        ) : (
          <div class="flex gap-12 px-4 sm:px-8 lg:px-12 pt-6 lg:pt-10 pb-24 max-w-[1096px] min-[1680px]:mx-auto">
            <article
              class="w-full max-w-[720px] min-w-0"
              data-pagefind-body={indexed ? "" : undefined}
              data-pagefind-filter={indexed ? `lang:${lang}` : undefined}
              data-pagefind-meta={indexed ? `crumb:${crumb}` : undefined}
            >
              {indexed && <span hidden data-pagefind-filter={`section:${tab.id}`}></span>}
              <PageNotices page={page} />
              <PageHeader page={page} />
              <div class="prose fade-up d3 mt-8" lang={fallback ? "en" : lang} data-doc-body>
                <slot />
              </div>
              <PageFooter lang={lang} prev={prev} next={next} />
            </article>
            {
              showToc && (
                <aside class="hidden xl:block w-[232px] shrink-0 pt-1" aria-label={lang === "vi" ? "Trên trang này" : "On this page"}>
                  <Toc lang={lang} headings={tocHeadings} related={related} />
                </aside>
              )
            }
          </div>
        )
      }
    </main>
  </div>
  <MobileDrawer lang={lang} tabId={tab.id} groups={groups} currentUrl={page.url} altUrl={altUrl} />
  <script type="application/json" data-page-markdown set:html={markdownJson} />
</BaseLayout>
```

## `src/components/layout/top-bar.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { withBase } from "../../lib/base";
import { type Lang, STRINGS } from "../../lib/i18n";
import { INTERNAL_BUILD, TABS } from "../../lib/tabs";
import Brand from "./brand.astro";
import LangSwitch from "./lang-switch.astro";
import ThemeToggle from "./theme-toggle.astro";

interface Props {
  lang: Lang;
  tabId?: string;
  altUrl: string;
}

const { lang, tabId, altUrl } = Astro.props;
const t = STRINGS[lang];
---

<header
  class="sticky top-0 z-40 h-14 lg:h-16 flex items-center gap-1 lg:gap-6 px-2 lg:px-6 border-b border-line bg-nav/90 backdrop-blur-md"
  data-topbar
  transition:persist={`topbar-${lang}`}
>
  <button
    type="button"
    class="lg:hidden w-10 h-10 rounded-[10px] flex items-center justify-center text-body hover:bg-hover"
    aria-label={t.menu}
    data-drawer-open
  >
    <Icon name="ri:menu-2-line" width="20" height="20" aria-hidden="true" />
  </button>
  <Brand href={`/${lang}`} />
  {
    INTERNAL_BUILD && (
      <span class="hidden xl:inline-flex chip chip-outline text-warning! border-warning-line!">
        <Icon name="ri:lock-line" width="12" height="12" aria-hidden="true" />
        Internal
      </span>
    )
  }
  <nav class="hidden lg:flex self-stretch items-center gap-1 text-[14px] min-w-0 overflow-x-auto no-scrollbar" aria-label="Sections">
    {
      TABS.map((tab) => (
        <a
          href={withBase(`/${lang}/${tab.id}`)}
          class="tab-link relative h-9 px-3 rounded-[10px] flex items-center whitespace-nowrap text-sub hover:text-strong hover:bg-hover"
          data-tab-link={tab.id}
          aria-current={tab.id === tabId ? "page" : undefined}
        >
          {tab.label[lang]}
          <span class="tab-underline" aria-hidden="true" />
        </a>
      ))
    }
  </nav>
  <span class="flex-1"></span>
  <button
    type="button"
    class="search-trigger h-10 w-10 lg:h-9 lg:w-9 xl:w-[200px] 2xl:w-[260px] xl:px-3 rounded-[10px] lg:border border-line-sub lg:bg-raised flex items-center justify-center xl:justify-start gap-2 text-[14px] text-faint hover:border-line-strong shrink-0"
    aria-label={t.search}
    data-search-open
  >
    <Icon name="ri:search-line" width="16" height="16" class="text-body lg:text-faint" aria-hidden="true" />
    <span class="hidden xl:block flex-1 text-left truncate">{t.search}</span>
    <span class="hidden xl:flex kbd" data-mod-key>⌘K</span>
  </button>
  <div class="hidden lg:flex">
    <LangSwitch lang={lang} altUrl={altUrl} />
  </div>
  <ThemeToggle lang={lang} />
</header>

<style is:global>
  .tab-link[aria-current="page"] {
    color: var(--text-strong);
    font-weight: 500;
  }
  .tab-link[aria-current="page"]:hover {
    background: transparent;
  }
  .tab-underline {
    position: absolute;
    left: 12px;
    right: 12px;
    bottom: -14px;
    height: 2px;
    border-radius: 999px;
    background: var(--text-strong);
    transform: scaleX(0);
    transition: transform 0.2s var(--ease-out-expo);
  }
  .tab-link[aria-current="page"] .tab-underline {
    transform: none;
  }
</style>
```

## `src/components/layout/brand.astro`

```astro
---
/*
 * The single place the product logo is used. Logo files live in public/brand/
 * (mark.svg for light UI, mark-dark.svg for dark UI) plus public/favicon.svg.
 */
import { withBase } from "../../lib/base";
import { SITE_NAME, SITE_TITLE } from "../../lib/i18n";

interface Props {
  href: string;
  size?: "md" | "sm";
}

const { href, size = "md" } = Astro.props;
const markSize = size === "md" ? "w-6 h-6 lg:w-7 lg:h-7" : "w-6 h-6";
---

<a href={withBase(href)} class="flex items-center gap-2.5 shrink-0" aria-label={SITE_TITLE} data-plain>
  <img src={withBase("/brand/mark.svg")} alt="" width="28" height="28" class:list={["brand-mark-light", markSize]} />
  <img src={withBase("/brand/mark-dark.svg")} alt="" width="28" height="28" class:list={["brand-mark-dark", markSize]} />
  <span class:list={["font-semibold tracking-[-0.01em] text-strong whitespace-nowrap", size === "md" ? "text-[15px]" : "text-[14px]"]}>
    {SITE_NAME} <span class="text-faint font-medium">Docs</span>
  </span>
</a>

<style is:global>
  .brand-mark-dark {
    display: none;
  }
  :root[data-theme="dark"] .brand-mark-light {
    display: none;
  }
  :root[data-theme="dark"] .brand-mark-dark {
    display: block;
  }
</style>
```

## `src/components/layout/lang-switch.astro`

```astro
---
import { withBase } from "../../lib/base";
import type { Lang } from "../../lib/i18n";

interface Props {
  lang: Lang;
  /** Same page in the other language (EN fallback pages exist for every VI path). */
  altUrl: string;
  size?: "md" | "lg";
}

const { lang, altUrl, size = "md" } = Astro.props;
const enHref = lang === "en" ? "" : withBase(altUrl);
const viHref = lang === "vi" ? "" : withBase(altUrl);
---

<div class:list={["segmented", size === "lg" && "segmented-lg"]} role="group" aria-label="Language" data-lang-switch>
  <a
    href={enHref || undefined}
    hreflang="en"
    lang="en"
    aria-current={lang === "en" ? "true" : "false"}
    data-lang-option="en">EN</a
  >
  <a
    href={viHref || undefined}
    hreflang="vi"
    lang="vi"
    aria-current={lang === "vi" ? "true" : "false"}
    data-lang-option="vi">VI</a
  >
</div>

<style is:global>
  .segmented-lg > * {
    height: 32px;
    padding: 0 12px;
  }
</style>
```

## `src/components/layout/theme-toggle.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { type Lang, STRINGS } from "../../lib/i18n";

interface Props {
  lang: Lang;
  /** "button" cycles System → Light → Dark; "segmented" shows all three. */
  variant?: "button" | "segmented";
}

const { lang, variant = "button" } = Astro.props;
const t = STRINGS[lang];
const OPTIONS = [
  { id: "system", icon: "ri:computer-line" },
  { id: "light", icon: "ri:sun-line" },
  { id: "dark", icon: "ri:moon-line" },
] as const;
const names = JSON.stringify(t.themeNames);
---

{
  variant === "button" ? (
    <button
      type="button"
      class="theme-cycle w-10 h-10 lg:w-9 lg:h-9 rounded-[10px] flex items-center justify-center text-sub hover:bg-hover hover:text-strong shrink-0"
      data-theme-cycle
      data-theme-names={names}
      data-theme-label={t.theme}
      aria-label={`${t.theme}: ${t.themeNames.system}`}
      title={`${t.theme}: ${t.themeNames.system} · ${t.themeNames.light} · ${t.themeNames.dark}`}
    >
      {OPTIONS.map((o) => (
        <Icon name={o.icon} width="18" height="18" class="theme-icon" data-theme-icon={o.id} aria-hidden="true" />
      ))}
    </button>
  ) : (
    <div class="segmented" role="group" aria-label={t.theme}>
      {OPTIONS.map((o) => (
        <button type="button" data-theme-set={o.id} aria-pressed="false" title={t.themeNames[o.id]} aria-label={t.themeNames[o.id]}>
          <Icon name={o.icon} width="14" height="14" aria-hidden="true" />
        </button>
      ))}
    </div>
  )
}

<style is:global>
  .theme-icon {
    display: none;
  }
  :root[data-theme-pref="system"] .theme-icon[data-theme-icon="system"],
  :root[data-theme-pref="light"] .theme-icon[data-theme-icon="light"],
  :root[data-theme-pref="dark"] .theme-icon[data-theme-icon="dark"] {
    display: block;
    animation: panel-in 0.2s var(--ease-out-expo) both;
  }
  :root:not([data-theme-pref]) .theme-icon[data-theme-icon="system"] {
    display: block;
  }
</style>
```

## `src/components/layout/left-nav.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { withBase } from "../../lib/base";
import type { NavGroup } from "../../lib/content";

interface Props {
  groups: NavGroup[];
  currentUrl: string;
}

const { groups, currentUrl } = Astro.props;
---

<nav class="docs-nav" aria-label="Pages" data-docs-nav>
  {
    groups.map((group) => (
      <details class="nav-group" open>
        <summary class="nav-group-label">
          {group.label}
          <Icon name="ri:arrow-down-s-line" width="14" height="14" class="nav-group-chevron" aria-hidden="true" />
        </summary>
        <ul>
          {group.pages.map((page) => (
            <li>
              <a
                href={withBase(page.url)}
                class="nav-link"
                data-nav-link
                aria-current={page.url === currentUrl ? "page" : undefined}
              >
                {page.entry.data.title}
              </a>
            </li>
          ))}
        </ul>
      </details>
    ))
  }
</nav>

<style is:global>
  .docs-nav {
    padding: 20px 12px 32px;
  }
  .nav-group + .nav-group {
    margin-top: 14px;
  }
  .nav-group-label {
    list-style: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 6px 10px;
    font-size: 12px;
    line-height: 16px;
    font-weight: 500;
    color: var(--text-soft);
    border-radius: 6px;
  }
  .nav-group-label::-webkit-details-marker {
    display: none;
  }
  .nav-group-label:hover {
    color: var(--text-sub);
  }
  .nav-group-chevron {
    opacity: 0;
    transition: opacity 0.15s, transform 0.2s var(--ease-out-expo);
  }
  .nav-group-label:hover .nav-group-chevron,
  .nav-group:not([open]) .nav-group-chevron {
    opacity: 1;
  }
  .nav-group:not([open]) .nav-group-chevron {
    transform: rotate(-90deg);
  }
  .nav-link {
    position: relative;
    display: flex;
    align-items: center;
    min-height: 32px;
    padding: 6px 10px;
    border-radius: 8px;
    font-size: 14px;
    line-height: 20px;
    color: var(--text-body);
    transition: background-color 0.15s, color 0.15s;
  }
  .nav-link:hover {
    background: var(--bg-hover);
    color: var(--text-strong);
  }
  .nav-link[aria-current="page"] {
    background: var(--bg-selected);
    color: var(--text-strong);
    font-weight: 500;
  }
  .nav-link[aria-current="page"]::before {
    content: "";
    position: absolute;
    left: 0;
    top: 6px;
    bottom: 6px;
    width: 2px;
    border-radius: 999px;
    background: var(--brand);
  }
</style>
```

## `src/components/layout/page-header.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { withBase } from "../../lib/base";
import type { DocPage } from "../../lib/content";
import { AUDIENCE_ICON, AUDIENCE_LABEL, formatDate, STRINGS, TYPE_ICON, TYPE_LABEL } from "../../lib/i18n";

interface Props {
  page: DocPage;
}

const { page } = Astro.props;
const { lang, tab, entry, fallback } = page;
const data = entry.data;
const t = STRINGS[lang];
const contentLang = fallback ? "en" : lang;
const isLanding = page.slug === "";
---

<header class="page-header">
  <div class="fade-up flex flex-wrap items-center gap-1.5 text-[13px] text-faint" data-pagefind-ignore>
    <a href={withBase(`/${lang}/${tab.id}`)} class="hover:text-strong">{tab.label[lang]}</a>
    {
      !isLanding && (
        <>
          {data.group !== tab.label[lang] && (
            <>
              <Icon name="ri:arrow-right-s-line" width="14" height="14" aria-hidden="true" />
              <span lang={contentLang}>{data.group}</span>
            </>
          )}
          <Icon name="ri:arrow-right-s-line" width="14" height="14" aria-hidden="true" />
          <span class="text-sub" lang={contentLang}>{data.title}</span>
        </>
      )
    }
  </div>
  <div lang={contentLang}>
    <h1 class="fade-up d1 mt-3 text-[28px] leading-[34px] md:text-[36px] md:leading-[44px] font-[650] tracking-[-0.022em] md:tracking-[-0.025em] text-strong" data-pagefind-meta="title">
      {data.title}
    </h1>
    <p class="fade-up d1 mt-2.5 md:mt-3 text-[16px] leading-[26px] md:text-[18px] md:leading-[30px] text-sub">{data.description}</p>
  </div>
  <div class="fade-up d2 mt-4 md:mt-5 flex flex-wrap items-center gap-x-2 gap-y-2 text-[13px]" data-pagefind-ignore>
    {
      data.audience.map((a) => (
        <span class="chip chip-brand">
          <Icon name={AUDIENCE_ICON[a] ?? "ri:user-line"} width="13" height="13" aria-hidden="true" />
          {AUDIENCE_LABEL[a]?.[lang] ?? a}
        </span>
      ))
    }
    <span class:list={["chip", data.type === "tutorial" && "chip-feature"]}>
      <Icon name={TYPE_ICON[data.type] ?? "ri:file-text-line"} width="13" height="13" aria-hidden="true" />
      {TYPE_LABEL[data.type]?.[lang] ?? data.type}
    </span>
    {
      fallback && (
        <span class="chip chip-outline" title="English">
          <Icon name="ri:global-line" width="12" height="12" aria-hidden="true" />
          EN
        </span>
      )
    }
    <span class="text-faint flex items-center gap-1">
      <Icon name="ri:time-line" width="13" height="13" aria-hidden="true" />
      {t.minRead(data.readingTime)}
    </span>
    <span class="text-line-strong hidden sm:inline" aria-hidden="true">·</span>
    <time class="text-faint hidden sm:inline" datetime={data.updated.toISOString().slice(0, 10)}>
      {t.updated(formatDate(data.updated, lang))}
    </time>
    <span class="flex-1"></span>
    <button
      type="button"
      class="hidden sm:flex h-7 px-2.5 rounded-[8px] border border-line text-sub items-center gap-1.5 hover:bg-subtle"
      data-copy-page
      data-copied-label={t.copied}
    >
      <Icon name="ri:file-copy-line" width="14" height="14" aria-hidden="true" />
      <span data-copy-page-label>{t.copyPage}</span>
    </button>
  </div>
</header>
```

## `src/components/layout/page-notices.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { withBase } from "../../lib/base";
import type { DocPage } from "../../lib/content";
import { STRINGS } from "../../lib/i18n";

interface Props {
  page: DocPage;
}

const { page } = Astro.props;
const t = STRINGS[page.lang];
---

{
  page.entry.data.internal && (
    <div class="fade-up mb-6 h-9 px-3 rounded-[10px] border border-warning-line bg-warning-soft text-warning text-[13px] font-semibold flex items-center gap-2" role="note" data-pagefind-ignore>
      <Icon name="ri:lock-line" width="15" height="15" aria-hidden="true" />
      {t.internalRibbon}
    </div>
  )
}
{
  page.fallback && (
    <div class="fade-up mb-7 rounded-xl border border-info-line bg-info-soft p-4 flex gap-3" role="status" data-untranslated data-pagefind-ignore>
      <span class="w-8 h-8 shrink-0 rounded-[9px] bg-raised border border-info-line flex items-center justify-center text-info">
        <Icon name="ri:translate-2" width="17" height="17" aria-hidden="true" />
      </span>
      <div class="flex-1 text-[14.5px] leading-[23px] text-body">
        <div class="font-semibold text-strong">{t.untranslatedTitle}</div>
        <div class="mt-0.5">{t.untranslatedBody}</div>
        <div class="mt-2.5 flex flex-wrap items-center gap-4 text-[13.5px]">
          <a href={withBase(`/${page.lang}/get-started/glossary`)} class="font-medium text-info flex items-center gap-1 hover:underline underline-offset-4">
            <Icon name="ri:book-2-line" width="14" height="14" aria-hidden="true" />
            {t.untranslatedGlossary}
          </a>
          <a href={withBase(page.url.replace(/^\/vi/, "/en"))} class="text-sub flex items-center gap-1 hover:text-strong" hreflang="en">
            <Icon name="ri:global-line" width="14" height="14" aria-hidden="true" />
            English
          </a>
        </div>
      </div>
      <button type="button" class="w-7 h-7 rounded-[8px] flex items-center justify-center text-faint hover:bg-raised" aria-label={t.close} data-untranslated-close>
        <Icon name="ri:close-line" width="16" height="16" aria-hidden="true" />
      </button>
    </div>
  )
}
```

## `src/components/layout/page-footer.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { withBase } from "../../lib/base";
import type { DocPage } from "../../lib/content";
import { type Lang, STRINGS } from "../../lib/i18n";

interface Props {
  lang: Lang;
  prev?: DocPage;
  next?: DocPage;
}

const { lang, prev, next } = Astro.props;
const t = STRINGS[lang];
---

<footer class="mt-12" data-pagefind-ignore>
  <div class="rounded-xl bg-nav border border-line px-4 min-h-14 py-2.5 flex flex-wrap items-center justify-between gap-3" data-feedback>
    <span class="text-[14px] text-sub" data-feedback-question>{t.helpful}</span>
    <span class="text-[14px] text-brand-text hidden items-center gap-1.5" data-feedback-thanks>
      <Icon name="ri:checkbox-circle-line" width="16" height="16" aria-hidden="true" />
      {t.thanks}
    </span>
    <div class="flex gap-2" data-feedback-buttons>
      <button type="button" class="feedback-btn" data-feedback-vote="up" aria-pressed="false">
        <Icon name="ri:thumb-up-line" width="15" height="15" aria-hidden="true" />
        {t.yes}
      </button>
      <button type="button" class="feedback-btn" data-feedback-vote="down" aria-pressed="false">
        <Icon name="ri:thumb-down-line" width="15" height="15" aria-hidden="true" />
        {t.no}
      </button>
    </div>
  </div>
  {
    (prev || next) && (
      <div class="mt-6 grid grid-cols-1 sm:grid-cols-2 gap-4">
        {prev ? (
          <a href={withBase(prev.url)} class="lift rounded-xl border border-line p-4 block">
            <span class="text-[12.5px] text-faint flex items-center gap-1">
              <Icon name="ri:arrow-left-line" width="14" height="14" aria-hidden="true" />
              {t.prev}
            </span>
            <span class="mt-1 block text-[15px] font-medium text-strong">{prev.entry.data.title}</span>
          </a>
        ) : (
          <span class="hidden sm:block" />
        )}
        {next && (
          <a href={withBase(next.url)} class="lift rounded-xl border border-line p-4 block text-right">
            <span class="text-[12.5px] text-faint flex items-center justify-end gap-1">
              {t.next}
              <Icon name="ri:arrow-right-line" width="14" height="14" aria-hidden="true" />
            </span>
            <span class="mt-1 block text-[15px] font-medium text-strong">{next.entry.data.title}</span>
          </a>
        )}
      </div>
    )
  }
</footer>

<style is:global>
  .feedback-btn {
    height: 32px;
    padding: 0 12px;
    border-radius: 8px;
    border: 1px solid var(--stroke-sub);
    background: var(--bg-raised);
    font-size: 13.5px;
    color: var(--text-strong);
    display: flex;
    align-items: center;
    gap: 6px;
    transition: background-color 0.15s, border-color 0.15s, color 0.15s;
  }
  .feedback-btn:hover {
    background: var(--bg-subtle);
  }
  .feedback-btn[aria-pressed="true"] {
    border-color: var(--brand);
    background: var(--brand-soft);
    color: var(--brand-text);
  }
</style>
```

## `src/components/layout/toc.astro`

```astro
---
import type { MarkdownHeading } from "astro";
import { Icon } from "astro-icon/components";
import { withBase } from "../../lib/base";
import { type Lang, STRINGS } from "../../lib/i18n";

interface RelatedLink {
  url: string;
  title: string;
  icon: string;
}

interface Props {
  lang: Lang;
  headings: MarkdownHeading[];
  related: RelatedLink[];
}

const { lang, headings, related } = Astro.props;
const t = STRINGS[lang];
---

<div class="sticky top-[104px] max-h-[calc(100dvh-128px)] overflow-y-auto no-scrollbar pb-6" data-pagefind-ignore>
  {
    headings.length > 0 && (
      <>
        <p class="text-[12px] font-medium text-faint mb-3">{t.onThisPage}</p>
        <div class="toc relative pl-3 border-l border-line" data-toc>
          <span class="toc-bar" aria-hidden="true" data-toc-bar />
          <ul class="space-y-2.5 text-[13.5px] leading-5">
            {headings.map((h) => (
              <li class:list={[h.depth === 3 && "pl-3"]}>
                <a href={`#${h.slug}`} class="toc-link" data-toc-link={h.slug}>
                  {h.text}
                </a>
              </li>
            ))}
          </ul>
        </div>
      </>
    )
  }
  {
    related.length > 0 && (
      <>
        <p class:list={["text-[12px] font-medium text-faint mb-3", headings.length > 0 && "mt-8"]}>{t.related}</p>
        <ul class="space-y-2 text-[13.5px]">
          {related.map((r) => (
            <li>
              <a href={withBase(r.url)} class="flex items-start gap-2 text-body hover:text-strong leading-5">
                <Icon name={r.icon} width="15" height="15" class="text-faint mt-0.5 shrink-0" aria-hidden="true" />
                {r.title}
              </a>
            </li>
          ))}
        </ul>
      </>
    )
  }
</div>

<style is:global>
  .toc-bar {
    position: absolute;
    left: -1px;
    top: 0;
    width: 2px;
    height: var(--toc-h, 20px);
    border-radius: 999px;
    background: var(--brand);
    transform: translateY(var(--toc-y, 0));
    opacity: var(--toc-o, 0);
    transition: transform 0.2s var(--ease-out-expo), height 0.2s var(--ease-out-expo), opacity 0.2s;
  }
  .toc-link {
    display: block;
    color: var(--text-soft);
    transition: color 0.15s;
  }
  .toc-link:hover {
    color: var(--text-strong);
  }
  .toc-link.is-active {
    color: var(--text-strong);
    font-weight: 500;
  }
</style>
```

## `src/components/layout/mobile-drawer.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { withBase } from "../../lib/base";
import type { NavGroup } from "../../lib/content";
import { type Lang, STRINGS } from "../../lib/i18n";
import { TABS } from "../../lib/tabs";
import Brand from "./brand.astro";
import LangSwitch from "./lang-switch.astro";
import LeftNav from "./left-nav.astro";
import ThemeToggle from "./theme-toggle.astro";

interface Props {
  lang: Lang;
  tabId?: string;
  groups: NavGroup[];
  currentUrl: string;
  altUrl: string;
}

const { lang, tabId, groups, currentUrl, altUrl } = Astro.props;
const t = STRINGS[lang];
---

<dialog class="drawer" data-drawer aria-label={t.menu}>
  <div class="h-14 shrink-0 px-3 flex items-center gap-2 border-b border-line">
    <Brand href={`/${lang}`} size="sm" />
    <span class="flex-1"></span>
    <button type="button" class="w-10 h-10 rounded-[10px] flex items-center justify-center text-body hover:bg-hover" aria-label={t.close} data-drawer-close>
      <Icon name="ri:close-line" width="20" height="20" aria-hidden="true" />
    </button>
  </div>
  <div class="px-3 pt-3">
    <button type="button" class="w-full h-10 px-3 rounded-[10px] border border-line-sub bg-raised flex items-center gap-2 text-[14px] text-faint" data-search-open>
      <Icon name="ri:search-line" width="16" height="16" aria-hidden="true" />
      <span class="flex-1 text-left">{t.search}</span>
    </button>
  </div>
  <nav class="flex-1 min-h-0 overflow-y-auto no-scrollbar px-3 py-3" aria-label="Sections">
    {
      TABS.map((tab) => (
        <div>
          <a
            href={withBase(`/${lang}/${tab.id}`)}
            class:list={[
              "h-11 px-2.5 rounded-xl flex items-center gap-2.5 text-[15px] hover:bg-hover",
              tab.id === tabId ? "text-strong font-medium bg-selected" : "text-body",
            ]}
          >
            <img src={withBase(tab.img)} alt="" class="illus w-7 h-7 object-contain" loading="lazy" />
            {tab.label[lang]}
            <span class="flex-1" />
            <Icon
              name={tab.id === tabId ? "ri:arrow-down-s-line" : "ri:arrow-right-s-line"}
              width="16"
              height="16"
              class="text-faint"
              aria-hidden="true"
            />
          </a>
          {tab.id === tabId && groups.length > 0 && (
            <div class="drawer-nav -mx-3 mb-2">
              <LeftNav groups={groups} currentUrl={currentUrl} />
            </div>
          )}
        </div>
      ))
    }
  </nav>
  <div class="shrink-0 px-3 py-3 border-t border-line flex items-center gap-2">
    <LangSwitch lang={lang} altUrl={altUrl} size="lg" />
    <span class="flex-1"></span>
    <ThemeToggle lang={lang} variant="segmented" />
  </div>
</dialog>

<style is:global>
  .drawer {
    position: fixed;
    inset: 0 auto 0 0;
    margin: 0;
    width: min(328px, 88vw);
    max-width: none;
    height: 100dvh;
    max-height: none;
    padding: 0;
    border: 0;
    border-right: 1px solid var(--stroke-soft);
    background: var(--bg-nav);
    color: var(--text-strong);
    box-shadow: 12px 0 40px -12px rgba(20, 20, 19, 0.25);
  }
  .drawer[open] {
    display: flex;
    flex-direction: column;
    animation: drawer-in 0.24s var(--ease-out-expo) both;
  }
  .drawer::backdrop {
    background: rgba(26, 26, 25, 0.3);
    animation: fade-in 0.15s ease-out both;
  }
  .drawer-nav .docs-nav {
    padding: 4px 12px 8px 24px;
  }
</style>
```

## `src/components/layout/mobile-toc.astro`

```astro
---
import type { MarkdownHeading } from "astro";
import { Icon } from "astro-icon/components";
import { type Lang, STRINGS } from "../../lib/i18n";

interface Props {
  lang: Lang;
  headings: MarkdownHeading[];
}

const { lang, headings } = Astro.props;
const t = STRINGS[lang];
---

<details class="mobile-toc xl:hidden" data-mobile-toc data-pagefind-ignore>
  <summary class="h-11 px-4 lg:px-12 flex items-center gap-2 text-[13.5px] cursor-pointer">
    <Icon name="ri:list-unordered" width="16" height="16" class="text-faint" aria-hidden="true" />
    <span class="text-faint whitespace-nowrap">{t.onThisPage}</span>
    <Icon name="ri:arrow-right-s-line" width="14" height="14" class="text-line-strong" aria-hidden="true" />
    <span class="flex-1 min-w-0 text-left font-medium truncate" data-mobile-toc-current>{headings[0]?.text}</span>
    <span class="text-[12px] text-faint" data-mobile-toc-count>1/{headings.length}</span>
    <Icon name="ri:arrow-down-s-line" width="18" height="18" class="mobile-toc-chevron text-sub" aria-hidden="true" />
  </summary>
  <ul class="px-4 lg:px-12 pb-3 space-y-1 text-[14px]">
    {
      headings.map((h) => (
        <li class:list={[h.depth === 3 && "pl-3"]}>
          <a href={`#${h.slug}`} class="toc-link py-1.5" data-toc-link={h.slug}>
            {h.text}
          </a>
        </li>
      ))
    }
  </ul>
  <div class="h-[2px] bg-line"><div class="h-full bg-brand w-(--read,0%) transition-[width] duration-150" data-read-progress></div></div>
</details>

<style is:global>
  .mobile-toc {
    position: sticky;
    top: 56px;
    z-index: 20;
    background: color-mix(in srgb, var(--bg-page) 90%, transparent);
    backdrop-filter: blur(12px);
    border-block: 1px solid var(--stroke-soft);
  }
  @media (min-width: 1024px) {
    .mobile-toc {
      top: 64px;
    }
  }
  .mobile-toc summary {
    list-style: none;
  }
  .mobile-toc summary::-webkit-details-marker {
    display: none;
  }
  .mobile-toc[open] .mobile-toc-chevron {
    transform: rotate(180deg);
  }
  .mobile-toc-chevron {
    transition: transform 0.2s var(--ease-out-expo);
  }
</style>
```

## `src/components/layout/site-footer.astro`

```astro
---
import { withBase } from "../../lib/base";
import { type Lang, STRINGS } from "../../lib/i18n";
import Brand from "./brand.astro";
import LangSwitch from "./lang-switch.astro";
import ThemeToggle from "./theme-toggle.astro";

interface Props {
  lang: Lang;
  altUrl: string;
  links: { url: string; label: string }[];
}

const { lang, altUrl, links } = Astro.props;
const t = STRINGS[lang];
---

<footer class="border-t border-line bg-nav" data-pagefind-ignore>
  <div class="max-w-[1120px] mx-auto px-4 sm:px-8 xl:px-0 py-8 flex flex-wrap items-center gap-x-8 gap-y-4">
    <Brand href={`/${lang}`} size="sm" />
    <nav class="flex flex-wrap items-center gap-5 text-[13.5px] text-sub">
      {links.map((l) => <a href={withBase(l.url)} class="hover:text-strong">{l.label}</a>)}
    </nav>
    <div class="flex-1"></div>
    <LangSwitch lang={lang} altUrl={altUrl} />
    <ThemeToggle lang={lang} variant="segmented" />
  </div>
  <div class="max-w-[1120px] mx-auto px-4 sm:px-8 xl:px-0 pb-8 text-[12.5px] text-faint">{t.footerCopy}</div>
</footer>
```
