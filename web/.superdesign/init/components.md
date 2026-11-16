# Components

Astro 5 + MDX, styled with Tailwind v4 utilities and hand-written CSS in `src/styles/` (no component library). Icons are `astro-icon` with the Remix set (`ri:*`). MDX components are global (registered in `src/components/mdx/index.ts`).

Shared primitives: Callout, Cards/Card, Steps/Step, Tabs/Tab, KeyRules, Prereqs, Shot, Term, Kbd, UI label, Accordion. Registry components: Req, ReqTable, UseCases. API: ApiPlayground (Scalar).

## `src/components/mdx/accordion-group.astro`

```astro
<div class="accordion-group"><slot /></div>
```

## `src/components/mdx/accordion.astro`

```astro
---
import { Icon } from "astro-icon/components";

interface Props {
  title: string;
  open?: boolean;
}

const { title, open = false } = Astro.props;
---

<details class="accordion" open={open}>
  <summary class="accordion-summary">
    <span>{title}</span>
    <Icon name="ri:add-line" class="accordion-icon" width="18" height="18" aria-hidden="true" />
  </summary>
  <div class="accordion-body"><slot /></div>
</details>
```

## `src/components/mdx/callout.astro`

```astro
---
import { Icon } from "astro-icon/components";

interface Props {
  type?: "note" | "tip" | "warning" | "danger" | "governance";
  title?: string;
}

const { type = "note", title } = Astro.props;
const ICONS: Record<NonNullable<Props["type"]>, string> = {
  note: "ri:information-line",
  tip: "ri:lightbulb-flash-line",
  warning: "ri:error-warning-line",
  danger: "ri:alarm-warning-line",
  governance: "ri:shield-check-line",
};
---

<aside class:list={["callout", `callout-${type}`]} role="note">
  <Icon name={ICONS[type] ?? ICONS.note} class="callout-icon" width="18" height="18" aria-hidden="true" />
  <div class="callout-body">
    {title && <p class="callout-title">{title}</p>}
    <slot />
  </div>
</aside>
```

## `src/components/mdx/card.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { withBase } from "../../lib/base";

interface Props {
  title: string;
  href: string;
  /** Remix icon, e.g. "ri:team-line". */
  icon?: string;
  /** Illustration under public/, e.g. "/img/guides.png". Wins over `icon`. */
  img?: string;
}

const { title, href, icon, img } = Astro.props;
---

<a href={withBase(href)} class="card group lift">
  {img && <img src={withBase(img)} alt="" class="card-img illus icon-hop" loading="lazy" decoding="async" />}
  {
    !img && icon && (
      <span class="card-icon">
        <Icon name={icon} width="18" height="18" aria-hidden="true" />
      </span>
    )
  }
  <span class="card-text">
    <span class="card-title">
      {title}
      <Icon name="ri:arrow-right-line" class="arrow-nudge card-arrow" width="15" height="15" aria-hidden="true" />
    </span>
    <span class="card-desc"><slot /></span>
  </span>
</a>
```

## `src/components/mdx/cards.astro`

```astro
---
interface Props {
  cols?: 2 | 3;
}

const { cols = 2 } = Astro.props;
---

<div class:list={["cards", cols === 3 ? "cards-3" : "cards-2"]}>
  <slot />
</div>
```

## `src/components/mdx/kbd.astro`

```astro
<kbd class="kbd"><slot /></kbd>
```

## `src/components/mdx/key-rules.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { STRINGS } from "../../lib/i18n";
import { pageLang } from "../../lib/page-lang";

interface Props {
  title?: string;
}

const t = STRINGS[pageLang(Astro)];
const { title = t.keyRules } = Astro.props;
---

<section class="keyrules">
  <p class="keyrules-title">
    <Icon name="ri:key-2-line" width="18" height="18" aria-hidden="true" />
    {title}
  </p>
  <div class="keyrules-body"><slot /></div>
</section>
```

## `src/components/mdx/prereqs.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { STRINGS } from "../../lib/i18n";
import { pageLang } from "../../lib/page-lang";

interface Props {
  time?: string;
  who?: string;
}

const { time, who } = Astro.props;
const t = STRINGS[pageLang(Astro)];
---

<section class="prereqs">
  <div class="prereqs-head">
    <p class="prereqs-title">
      <Icon name="ri:checkbox-circle-line" width="18" height="18" aria-hidden="true" />
      {t.beforeStart}
    </p>
    <div class="prereqs-chips">
      {
        time && (
          <span class="chip">
            <Icon name="ri:time-line" width="13" height="13" aria-hidden="true" />
            {t.time}: {time}
          </span>
        )
      }
      {
        who && (
          <span class="chip">
            <Icon name="ri:shield-user-line" width="13" height="13" aria-hidden="true" />
            {t.who}: {who}
          </span>
        )
      }
    </div>
  </div>
  <div class="prereqs-body"><slot /></div>
</section>
```

## `src/components/mdx/shot.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { withBase } from "../../lib/base";
import { STRINGS } from "../../lib/i18n";
import { publicImageSize } from "../../lib/image-size";
import { pageLang } from "../../lib/page-lang";

interface Point {
  n: number;
  x: number;
  y: number;
  label: string;
  /** "action" draws the hotspot dark, for the control you press. */
  tone?: "action";
}

interface Props {
  src: string;
  alt: string;
  /** [x, y, width, height] in source-image pixels. Defaults to the whole image. */
  crop?: [number, number, number, number];
  points?: Point[];
  caption?: string;
}

const { src, alt, crop, points = [], caption } = Astro.props;
const t = STRINGS[pageLang(Astro)];
const url = withBase(src);
const size = await publicImageSize(src);
const [cx, cy, cw, ch] = crop ?? [0, 0, size.width, size.height];
const pct = (value: number) => `${(value * 100).toFixed(4)}%`;

// The frame keeps the crop's aspect ratio; the image is scaled so the crop fills it.
const imgStyle = `width:${pct(size.width / cw)};left:${pct(-cx / cw)};top:${pct(-cy / ch)}`;
const spots = points.map((p) => ({
  ...p,
  style: `left:${pct((p.x - cx) / cw)};top:${pct((p.y - cy) / ch)}`,
}));
const legend = points.map((p) => {
  const split = p.label.indexOf(" — ");
  return split > 0
    ? { ...p, head: p.label.slice(0, split), rest: p.label.slice(split) }
    : { ...p, head: "", rest: p.label };
});
const view = `aspect-ratio:${cw}/${ch};--crop-w:${cw}px;--ratio:${(cw / ch).toFixed(4)}`;
---

<figure class="shot" data-shot>
  <div class="shot-frame" style={view} data-shot-frame data-pagefind-ignore>
    <img class="shot-img" src={url} alt={alt} style={imgStyle} loading="lazy" decoding="async" />
    {
      spots.map((p) => (
        <button
          type="button"
          class:list={["hotspot", p.tone === "action" && "hotspot-action"]}
          style={p.style}
          data-point={p.n}
          aria-label={`${p.n}. ${p.label}`}
        >
          {p.n}
        </button>
      ))
    }
    <button type="button" class="shot-zoom" data-shot-open aria-label={t.zoom}>
      <Icon name="ri:fullscreen-line" width="14" height="14" aria-hidden="true" />
      <span class="shot-zoom-desk">{t.zoom}</span><span class="shot-zoom-touch">{t.tapZoom}</span>
    </button>
  </div>
  {
    legend.length > 0 && (
      <ol class="shot-legend">
        {legend.map((p) => (
          <li data-point={p.n} tabindex="-1">
            <span class:list={["shot-legend-num", p.tone === "action" && "is-action"]}>{p.n}</span>
            <span>
              {p.head && <b>{p.head}</b>}
              {p.rest}
            </span>
          </li>
        ))}
      </ol>
    )
  }
  {caption && <figcaption class="shot-caption">{caption}</figcaption>}
  <dialog class="shot-lightbox" data-shot-dialog data-pagefind-ignore aria-label={alt}>
    <div class="shot-lightbox-bar">
      <span class="shot-lightbox-title">{caption ?? alt}</span>
      <div class="segmented">
        <button type="button" data-shot-fit aria-pressed="true">{t.fit}</button>
        <button type="button" data-shot-actual aria-pressed="false">{t.actualSize}</button>
      </div>
      <button type="button" class="shot-lightbox-close" data-shot-close aria-label={t.close}>
        <Icon name="ri:close-line" width="18" height="18" aria-hidden="true" />
      </button>
    </div>
    <div class="shot-lightbox-scroll" data-shot-scroll>
      <div class="shot-frame shot-frame-large" style={view}>
        <img class="shot-img" src={url} alt="" style={imgStyle} loading="lazy" decoding="async" />
        {
          spots.map((p) => (
            <span class:list={["hotspot", "is-static", p.tone === "action" && "hotspot-action"]} style={p.style}>
              {p.n}
            </span>
          ))
        }
      </div>
    </div>
  </dialog>
</figure>
```

## `src/components/mdx/step.astro`

```astro
---
import { Icon } from "astro-icon/components";

interface Props {
  title: string;
}

const { title } = Astro.props;
---

<li class="step" data-step>
  <button type="button" class="step-marker" data-step-marker aria-pressed="false">
    <span class="step-num" aria-hidden="true"></span>
    <Icon name="ri:check-line" class="step-check" width="14" height="14" aria-hidden="true" />
  </button>
  <div class="step-body">
    <p class="step-title">{title}</p>
    <div class="step-content"><slot /></div>
  </div>
</li>
```

## `src/components/mdx/steps.astro`

```astro
---
import { STRINGS } from "../../lib/i18n";
import { pageLang } from "../../lib/page-lang";

interface Props {
  /** Show the "x of n steps" bar; ticks are remembered in this browser. */
  progress?: boolean;
}

const { progress = false } = Astro.props;
const t = STRINGS[pageLang(Astro)];
---

<div class="steps" data-steps data-label={t.stepsProgress("{done}", "{total}")} data-mark-label={t.markDone}>
  {
    progress && (
      <div class="steps-progress" aria-live="polite">
        <span class="steps-progress-label" data-steps-label />
        <span class="steps-progress-track">
          <span class="steps-progress-fill" data-steps-fill />
        </span>
      </div>
    )
  }
  <div class="steps-track">
    <span class="steps-line" aria-hidden="true"><span class="steps-line-fill" data-steps-line></span></span>
    <ol class="steps-list">
      <slot />
    </ol>
  </div>
</div>
```

## `src/components/mdx/tab.astro`

```astro
---
/* Panels are paired with Tabs labels by order; src/scripts/tabs.ts wires ids and visibility. */
---

<div class="tabs-panel" role="tabpanel" data-tab-panel>
  <slot />
</div>
```

## `src/components/mdx/tabs.astro`

```astro
---
interface Props {
  labels: string[];
}

const { labels } = Astro.props;
---

<div class="tabs" data-tabs>
  <div class="tabs-list" role="tablist">
    {
      labels.map((label, i) => (
        <button
          type="button"
          role="tab"
          class="tabs-tab"
          aria-selected={i === 0 ? "true" : "false"}
          tabindex={i === 0 ? 0 : -1}
          data-tab-index={i}
        >
          {label}
        </button>
      ))
    }
    <span class="tabs-indicator" aria-hidden="true" data-tabs-indicator></span>
  </div>
  <div class="tabs-panels" data-tabs-panels>
    <slot />
  </div>
</div>
```

## `src/components/mdx/term.astro`

```astro
---
import { Icon } from "astro-icon/components";
import { glossary } from "../../data/glossary";
import { withBase } from "../../lib/base";
import { STRINGS } from "../../lib/i18n";
import { pageLang } from "../../lib/page-lang";

interface Props {
  id: string;
}

const { id } = Astro.props;
const lang = pageLang(Astro);
const t = STRINGS[lang];
const entry = glossary.find((g) => g.id === id);
if (!entry) throw new Error(`<Term id="${id}">: no glossary entry with that id (src/data/glossary.ts).`);
const main = entry[lang];
const other = entry[lang === "en" ? "vi" : "en"];
---

<span class="term" tabindex="0" data-term
  ><slot /><span class="term-card" role="tooltip" data-pagefind-ignore
    ><span class="term-card-head"
      ><span class="term-card-term">{main.term}</span><span
        class="term-card-alt"
        lang={lang === "en" ? "vi" : "en"}>{other.term}</span
      ></span
    ><span class="term-card-def">{main.definition}</span><a
      class="term-card-link"
      href={withBase(`/${lang}/get-started/glossary#t-${entry.id}`)}
      data-plain>{t.openGlossary}<Icon name="ri:arrow-right-line" width="13" height="13" aria-hidden="true" /></a
    ></span
  ></span
>
```

## `src/components/mdx/ui-label.astro`

```astro
<span class="uilabel"><slot /></span>
```

## `src/components/mdx/index.ts`

```astro
import ApiPlayground from "../api/api-playground.astro";
import GlossaryList from "../glossary/glossary-list.astro";
import Req from "../requirements/req.astro";
import ReqTable from "../requirements/req-table.astro";
import UseCases from "../requirements/use-cases.astro";
import Accordion from "./accordion.astro";
import AccordionGroup from "./accordion-group.astro";
import Callout from "./callout.astro";
import Card from "./card.astro";
import Cards from "./cards.astro";
import Kbd from "./kbd.astro";
import KeyRules from "./key-rules.astro";
import Prereqs from "./prereqs.astro";
import Shot from "./shot.astro";
import Step from "./step.astro";
import Steps from "./steps.astro";
import Tab from "./tab.astro";
import Tabs from "./tabs.astro";
import Term from "./term.astro";
import UI from "./ui-label.astro";

/** Global MDX components — content files use these without imports. */
export const components = {
  Accordion,
  ApiPlayground,
  AccordionGroup,
  Callout,
  Card,
  Cards,
  Glossary: GlossaryList,
  Kbd,
  KeyRules,
  Prereqs,
  Req,
  ReqTable,
  Shot,
  Step,
  Steps,
  Tab,
  Tabs,
  Term,
  UI,
  UseCases,
};
```

## `src/components/requirements/req.astro`

```astro
---
import { withBase } from "../../lib/base";
import { pageLang } from "../../lib/page-lang";
import { hrefOf, label } from "../../lib/registry";

/** An inline link to one requirement: <Req id="BR-ACC-01" />. An unknown ID fails the build. */
interface Props {
  id: string;
}

const { id } = Astro.props;
const lang = pageLang(Astro);
const title = label(id, lang);
---

<a class="req-link" href={withBase(hrefOf(id, lang))} title={title}><code>{id}</code></a>
```

## `src/components/api/api-playground.astro`

```astro
---
import { withBase } from "../../lib/base";

/**
 * The API playground: Scalar's API reference over /openapi.json, which
 * `make trace` bundles from server/api. Requests go straight from the
 * browser to the server picked in it, so the server lists this site in
 * DOCS_ORIGINS; Scalar's proxy, telemetry and AI features are off.
 */
---

<div class="api-playground" data-api-playground data-spec={withBase("/openapi.json")}>
  <p class="api-playground-loading">Loading the API reference…</p>
  <noscript><a href={withBase("/openapi.json")}>openapi.json</a></noscript>
</div>

<script>
  import { createApiReference } from "@scalar/api-reference";
  import "@scalar/api-reference/style.css";
  import theme from "./scalar-theme.css?raw";

  type Instance = ReturnType<typeof createApiReference>;
  let current: Instance | undefined;
  let watcher: MutationObserver | undefined;

  const isDark = () => document.documentElement.dataset.theme === "dark";

  function mount() {
    const el = document.querySelector<HTMLElement>("[data-api-playground]");
    if (!el || el.dataset.mounted) return;
    el.dataset.mounted = "true";
    el.querySelector(".api-playground-loading")?.remove();
    const configuration = {
      url: el.dataset.spec,
      theme: "none",
      customCss: theme,
      withDefaultFonts: false,
      darkMode: isDark(),
      forceDarkModeState: isDark() ? "dark" : "light",
      hideDarkModeToggle: true,
      // Requests go to the chosen server, never through proxy.scalar.com.
      proxyUrl: "",
      telemetry: false,
      agent: { disabled: true },
      mcp: { disabled: true },
      showDeveloperTools: "never",
      // The token pasted under Authentication stays in this browser.
      persistAuth: true,
      authentication: { preferredSecurityScheme: "bearerAuth" },
      documentDownloadType: "json",
      defaultHttpClient: { targetKey: "shell", clientKey: "curl" },
      // Ctrl+K is the site's search.
      searchHotKey: "j",
    } as Parameters<typeof createApiReference>[1];
    current = createApiReference(el, configuration);
    watcher = new MutationObserver(() => {
      if (!current) return;
      current.updateConfiguration({
        ...current.getConfiguration(),
        darkMode: isDark(),
        forceDarkModeState: isDark() ? "dark" : "light",
      } as Parameters<Instance["updateConfiguration"]>[0]);
    });
    watcher.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
  }

  function unmount() {
    watcher?.disconnect();
    current?.destroy();
    current = undefined;
    watcher = undefined;
  }

  mount();
  document.addEventListener("astro:page-load", mount);
  document.addEventListener("astro:before-swap", unmount);
</script>

<style>
  .api-playground {
    min-height: 60vh;
  }
  .api-playground-loading {
    padding: 48px 24px;
    color: var(--text-soft);
  }
</style>
```

## `src/components/api/scalar-theme.css`

```css
/*
 * Scalar's colours and type, taken from the site's tokens (styles/tokens.css).
 * The tokens switch with :root[data-theme], so one block serves both modes;
 * api-playground.astro keeps Scalar's own light/dark class in step for its
 * code highlighting.
 */
.light-mode,
.dark-mode,
.light-mode .dark-mode {
  --scalar-font: "Inter Variable", ui-sans-serif, system-ui, sans-serif;
  --scalar-font-code: "JetBrains Mono Variable", ui-monospace, SFMono-Regular, monospace;

  --scalar-background-1: var(--bg-page);
  --scalar-background-2: var(--bg-subtle);
  --scalar-background-3: var(--bg-hover);
  --scalar-background-card: var(--bg-raised);
  --scalar-background-accent: var(--brand-soft);

  --scalar-color-1: var(--text-strong);
  --scalar-color-2: var(--text-sub);
  --scalar-color-3: var(--text-soft);
  --scalar-color-accent: var(--brand);
  --scalar-link-color: var(--link);
  --scalar-link-color-hover: var(--brand-text);

  --scalar-border-color: var(--stroke-soft);
  --scalar-focus-color: var(--brand);
  --scalar-scrollbar-color: var(--stroke-sub);
  --scalar-scrollbar-color-active: var(--stroke-strong);

  --scalar-color-green: var(--brand);
  --scalar-color-blue: var(--info);
  --scalar-color-orange: var(--warning);
  --scalar-color-yellow: var(--warning);
  --scalar-color-red: var(--danger);
  --scalar-color-purple: var(--feature);
  --scalar-color-query: var(--info);
  --scalar-color-danger: var(--danger);
  --scalar-background-danger: var(--danger-soft);
  --scalar-color-alert: var(--warning);
  --scalar-background-alert: var(--warning-soft);

  --scalar-button-1: var(--brand);
  --scalar-button-1-hover: var(--brand-text);
  --scalar-button-1-color: var(--on-brand);

  --scalar-tooltip-background: var(--inverse-bg);
  --scalar-tooltip-color: var(--inverse-fg);

  --scalar-shadow-1: var(--shadow-chip);
  --scalar-shadow-2: var(--shadow-card);

  --scalar-radius: 8px;
  --scalar-radius-lg: 12px;
  --scalar-radius-xl: 16px;

  /* The site's top bar is 64px and stays on screen. */
  --scalar-custom-header-height: 64px;

  --scalar-sidebar-background-1: var(--bg-nav);
  --scalar-sidebar-color-1: var(--text-strong);
  --scalar-sidebar-color-2: var(--text-sub);
  --scalar-sidebar-border-color: var(--stroke-soft);
  --scalar-sidebar-item-hover-background: var(--bg-hover);
  --scalar-sidebar-item-hover-color: var(--text-strong);
  --scalar-sidebar-item-active-background: var(--bg-selected);
  --scalar-sidebar-color-active: var(--text-strong);
  --scalar-sidebar-search-background: var(--bg-page);
  --scalar-sidebar-search-color: var(--text-soft);
  --scalar-sidebar-search-border-color: var(--stroke-sub);
}

/* Method colours in the sidebar stay readable on the nav background. */
.t-doc__sidebar {
  --scalar-color-green: var(--brand-text);
}
```
