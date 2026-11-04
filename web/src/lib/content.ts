import { type CollectionEntry, getCollection } from "astro:content";
import { LANGS, type Lang } from "./i18n";
import { INTERNAL_BUILD, TABS, type Tab } from "./tabs";

export type DocEntry = CollectionEntry<"docs">;

/** One routed docs page. A VI page without a translation renders the EN entry (`fallback`). */
export interface DocPage {
  lang: Lang;
  tab: Tab;
  /** Path inside the tab: "" for the tab landing, "settings/memory" for nested pages. */
  slug: string;
  url: string;
  entry: DocEntry;
  fallback: boolean;
}

export interface NavGroup {
  label: string;
  order: number;
  pages: DocPage[];
}

let cache: DocPage[] | undefined;

/** Every page of this build, both languages, internal pages only in an internal build. */
export async function getPages(): Promise<DocPage[]> {
  if (cache) return cache;
  const entries = await getCollection("docs", (e) => INTERNAL_BUILD || !e.data.internal);
  const byKey = new Map<string, Partial<Record<Lang, DocEntry>>>();
  for (const entry of entries) {
    const [first, ...rest] = entry.id.split("/");
    const lang = LANGS.find((l) => l === first);
    if (!lang) continue;
    const key = rest.join("/");
    byKey.set(key, { ...byKey.get(key), [lang]: entry });
  }
  const pages: DocPage[] = [];
  for (const [key, versions] of byKey) {
    const [tabId, ...slugParts] = key.split("/");
    const tab = TABS.find((t) => t.id === tabId);
    if (!tab) continue;
    for (const lang of LANGS) {
      const entry = versions[lang] ?? versions.en;
      if (!entry) continue;
      pages.push({
        lang,
        tab,
        slug: slugParts.join("/"),
        url: `/${lang}/${key}`,
        entry,
        fallback: !versions[lang],
      });
    }
  }
  cache = pages;
  return pages;
}

export function sortPages(a: DocPage, b: DocPage): number {
  const x = a.entry.data;
  const y = b.entry.data;
  return x.groupOrder - y.groupOrder || x.order - y.order || x.title.localeCompare(y.title);
}

/** Left-nav groups for one tab in one language, in frontmatter order. */
export function navFor(pages: DocPage[], lang: Lang, tabId: string): NavGroup[] {
  const groups = new Map<string, NavGroup>();
  for (const page of pages.filter((p) => p.lang === lang && p.tab.id === tabId).sort(sortPages)) {
    const { group, groupOrder } = page.entry.data;
    const existing = groups.get(group) ?? { label: group, order: groupOrder, pages: [] };
    existing.pages.push(page);
    groups.set(group, existing);
  }
  return [...groups.values()].sort((a, b) => a.order - b.order);
}

/** URL path without the language prefix, used to pair EN and VI pages. */
export function pathKey(url: string): string {
  return url.replace(/^\/(en|vi)(?=\/|$)/, "").replace(/\/$/, "");
}
