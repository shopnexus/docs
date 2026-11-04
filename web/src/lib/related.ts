import { type DocPage, pathKey } from "./content";

export interface PageLink {
  url: string;
  title: string;
  icon: string;
  crumb: string;
  description: string;
}

export function toLink(page: DocPage): PageLink {
  const { title, description, group } = page.entry.data;
  const tabLabel = page.tab.label[page.lang];
  const crumb = page.slug && group !== tabLabel ? `${tabLabel} › ${group}` : tabLabel;
  return { url: page.url, title, icon: page.tab.icon, crumb, description };
}

/** Pages listed in the frontmatter `related` field, resolved in the page's language. */
export function relatedLinks(pages: DocPage[], page: DocPage): PageLink[] {
  const byKey = new Map(pages.filter((p) => p.lang === page.lang).map((p) => [pathKey(p.url), p]));
  return (page.entry.data.related ?? []).flatMap((url) => {
    const target = byKey.get(pathKey(url.split("#")[0] ?? url));
    if (!target) console.warn(`[related] ${page.url}: no page for "${url}"`);
    return target && target.url !== page.url ? [toLink(target)] : [];
  });
}
