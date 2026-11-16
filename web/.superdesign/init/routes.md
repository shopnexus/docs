# Routes

Static Astro site, every page in English and Vietnamese. `src/pages/[lang]/[...slug].astro` renders each MDX entry of `src/content/docs/<lang>/<tab>/<slug>.mdx` at `/<lang>/<tab>/<slug>`. `src/pages/[lang]/index.astro` is the home page per language; `src/pages/index.astro` redirects to a language; `404.astro`.

Tabs (top bar): get-started, marketplace, requirements, architecture, api, operations, developers (internal). Key pages: `/en/api/playground` (Scalar API reference, wide), `/en/requirements/use-cases`, `/en/requirements`, `/en/api/errors`.

Content files:

- `src/content/docs/en/api/authentication.mdx`
- `src/content/docs/en/api/errors.mdx`
- `src/content/docs/en/api/idempotency.mdx`
- `src/content/docs/en/api/index.mdx`
- `src/content/docs/en/api/live-updates.mdx`
- `src/content/docs/en/api/pagination.mdx`
- `src/content/docs/en/api/playground.mdx`
- `src/content/docs/en/architecture/catalog.mdx`
- `src/content/docs/en/architecture/chat.mdx`
- `src/content/docs/en/architecture/console.mdx`
- `src/content/docs/en/architecture/data.mdx`
- `src/content/docs/en/architecture/deal.mdx`
- `src/content/docs/en/architecture/durable-flows.mdx`
- `src/content/docs/en/architecture/events.mdx`
- `src/content/docs/en/architecture/index.mdx`
- `src/content/docs/en/architecture/media.mdx`
- `src/content/docs/en/architecture/modules.mdx`
- `src/content/docs/en/architecture/notifications.mdx`
- `src/content/docs/en/architecture/screens.mdx`
- `src/content/docs/en/architecture/search-and-discovery.mdx`
- `src/content/docs/en/architecture/sessions.mdx`
- `src/content/docs/en/architecture/sign-in.mdx`
- `src/content/docs/en/architecture/trust.mdx`
- `src/content/docs/en/developers/index.mdx`
- `src/content/docs/en/get-started/glossary.mdx`
- `src/content/docs/en/get-started/index.mdx`
- `src/content/docs/en/get-started/quick-start.mdx`
- `src/content/docs/en/get-started/troubleshooting.mdx`
- `src/content/docs/en/marketplace/after-delivery.mdx`
- `src/content/docs/en/marketplace/cod-deal.mdx`
- `src/content/docs/en/marketplace/index.mdx`
- `src/content/docs/en/marketplace/listings.mdx`
- `src/content/docs/en/marketplace/moderation.mdx`
- `src/content/docs/en/marketplace/money-and-cancellation.mdx`
- `src/content/docs/en/marketplace/revenue.mdx`
- `src/content/docs/en/marketplace/trust-and-sanctions.mdx`
- `src/content/docs/en/operations/cluster/bootstrap.mdx`
- `src/content/docs/en/operations/cluster/data.mdx`
- `src/content/docs/en/operations/cluster/index.mdx`
- `src/content/docs/en/operations/cluster/llm-gateway.mdx`
- `src/content/docs/en/operations/cluster/networking.mdx`
- `src/content/docs/en/operations/cluster/releases.mdx`
- `src/content/docs/en/operations/cluster/runbook.mdx`
- `src/content/docs/en/operations/cluster/secrets.mdx`
- `src/content/docs/en/operations/configuration.mdx`
- `src/content/docs/en/operations/index.mdx`
- `src/content/docs/en/operations/local-stack.mdx`
- `src/content/docs/en/operations/monitoring.mdx`
- `src/content/docs/en/operations/testing.mdx`
- `src/content/docs/en/requirements/index.mdx`
- `src/content/docs/en/requirements/rules.mdx`
- `src/content/docs/en/requirements/use-cases.mdx`

## `src/pages/[lang]/[...slug].astro`

```ts
---
import { render } from "astro:content";
import type { GetStaticPaths } from "astro";
import { components } from "../../components/mdx";
import DocLayout from "../../layouts/doc-layout.astro";
import { type DocPage, getPages, navFor } from "../../lib/content";
import { relatedLinks, toLink } from "../../lib/related";

export const getStaticPaths = (async () => {
  const pages = await getPages();
  return pages.map((page) => ({
    params: { lang: page.lang, slug: page.url.split("/").slice(2).join("/") },
    props: { page },
  }));
}) satisfies GetStaticPaths;

interface Props {
  page: DocPage;
}

const { page } = Astro.props;
const pages = await getPages();
const groups = navFor(pages, page.lang, page.tab.id);
const flat = groups.flatMap((g) => g.pages);
const index = flat.findIndex((p) => p.url === page.url);
const altUrl = page.url.replace(/^\/(en|vi)/, page.lang === "en" ? "/vi" : "/en");
const related = relatedLinks(pages, page);
const suggestions = related.length
  ? related
  : flat
      .filter((p) => p.entry.data.group === page.entry.data.group && p.url !== page.url)
      .slice(0, 3)
      .map(toLink);
const { Content, headings } = await render(page.entry);
const { title, description } = page.entry.data;
const markdown = `# ${title}\n\n> ${description}\n\n${(page.entry.body ?? "").trim()}\n`;
---

<DocLayout
  page={page}
  altUrl={altUrl}
  headings={headings}
  groups={groups}
  prev={index > 0 ? flat[index - 1] : undefined}
  next={index >= 0 && index < flat.length - 1 ? flat[index + 1] : undefined}
  related={related}
  suggestions={suggestions}
  markdown={markdown}
>
  <Content components={components} />
</DocLayout>
```

## `src/lib/tabs.ts`

```ts
import { DOCS_INTERNAL } from "astro:env/server";
import type { Lang } from "./i18n";

export type TabId =
  | "get-started"
  | "marketplace"
  | "requirements"
  | "architecture"
  | "api"
  | "operations"
  | "developers";

export interface Tab {
  id: TabId;
  /** Section illustration under public/img/. */
  img: string;
  /** Remix icon used where an illustration is too large (search scopes). */
  icon: string;
  internal: boolean;
  label: Record<Lang, string>;
  blurb: Record<Lang, string>;
}

/** Internal tabs and internal pages exist only in a `DOCS_INTERNAL=true` build. */
export const INTERNAL_BUILD = DOCS_INTERNAL;

const ALL_TABS: Tab[] = [
  {
    id: "get-started",
    img: "/img/sec-start.webp",
    icon: "ri:flag-line",
    internal: false,
    label: { en: "Get started", vi: "Bắt đầu" },
    blurb: {
      en: "What ShopNexus is, how to run it and the words the docs use.",
      vi: "ShopNexus là gì, cách chạy nó và các từ tài liệu hay dùng.",
    },
  },
  {
    id: "marketplace",
    img: "/img/sec-guides.webp",
    icon: "ri:store-2-line",
    internal: false,
    label: { en: "Marketplace", vi: "Mô hình sàn" },
    blurb: {
      en: "How buying and selling work: listings, COD with inspection, trust.",
      vi: "Mua bán diễn ra thế nào: tin đăng, COD đồng kiểm, uy tín.",
    },
  },
  {
    id: "requirements",
    img: "/img/sec-guides.webp",
    icon: "ri:list-check-3",
    internal: false,
    label: { en: "Requirements", vi: "Yêu cầu" },
    blurb: {
      en: "Use cases, rules and quality requirements, with the code and tests behind each.",
      vi: "Ca sử dụng, quy tắc và yêu cầu chất lượng, kèm code và test của từng mục.",
    },
  },
  {
    id: "architecture",
    img: "/img/sec-reference.webp",
    icon: "ri:node-tree",
    internal: false,
    label: { en: "Architecture", vi: "Kiến trúc" },
    blurb: {
      en: "The backend's modules, durable flows and the features built on them.",
      vi: "Các module của backend, luồng bền vững và các tính năng xây trên đó.",
    },
  },
  {
    id: "api",
    img: "/img/sec-developers.webp",
    icon: "ri:braces-line",
    internal: false,
    label: { en: "API", vi: "API" },
    blurb: {
      en: "How clients talk to the server: sign-in, errors, paging, live updates.",
      vi: "Client nói chuyện với server thế nào: đăng nhập, lỗi, phân trang, cập nhật trực tiếp.",
    },
  },
  {
    id: "operations",
    img: "/img/docs-troubleshoot.webp",
    icon: "ri:rocket-2-line",
    internal: false,
    label: { en: "Operations", vi: "Vận hành" },
    blurb: {
      en: "Running, deploying and watching the system.",
      vi: "Chạy, triển khai và theo dõi hệ thống.",
    },
  },
  {
    id: "developers",
    img: "/img/sec-developers.webp",
    icon: "ri:code-s-slash-line",
    internal: true,
    label: { en: "Developers", vi: "Nhà phát triển" },
    blurb: {
      en: "Write and publish pages on this site.",
      vi: "Viết và xuất bản trang trên site này.",
    },
  },
];

export const TABS: Tab[] = ALL_TABS.filter((tab) => INTERNAL_BUILD || !tab.internal);

export function findTab(id: string): Tab | undefined {
  return TABS.find((tab) => tab.id === id);
}
```

## `src/content.config.ts`

```ts
import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

export const AUDIENCES = ["everyone", "users", "admins", "developers"] as const;

export const PAGE_TYPES = ["tutorial", "how-to", "concept", "reference", "overview"] as const;

const docs = defineCollection({
  loader: glob({
    pattern: "**/*.mdx",
    base: "./src/content/docs",
    // Keep the file path as the id ("en/use/knowledge/index" → "en/use/knowledge").
    generateId: ({ entry }) => entry.replace(/\.mdx$/, "").replace(/\/index$/, ""),
  }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    group: z.string(),
    order: z.number(),
    groupOrder: z.number(),
    audience: z.array(z.enum(AUDIENCES)).min(1),
    type: z.enum(PAGE_TYPES),
    readingTime: z.number(),
    updated: z.coerce.date(),
    internal: z.boolean().default(false),
    related: z.array(z.string()).optional(),
    toc: z.boolean().default(true),
    /** Full width, without the left nav or the outline, for an embedded app such as the API playground. */
    wide: z.boolean().default(false),
  }),
});

export const collections = { docs };
```
