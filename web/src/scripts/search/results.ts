import type { PagefindData } from "./pagefind";

export interface Hit {
  key: string;
  /** Link in the reader's language (a VI reader opens the VI route, even for EN-only pages). */
  url: string;
  contentLang: string;
  section: string;
  title: string;
  crumb: string;
  excerpt: string;
  subs: { title: string; url: string; excerpt: string }[];
}

const clean = (url: string) => url.replace(/\/(?=#|$)/, "").replace(/\/index\.html$/, "");

/**
 * Turn Pagefind pages into hits: one per page path, the reader's language preferred,
 * then reader-language hits before English fallbacks (relevance order kept within each).
 */
export function toHits(data: PagefindData[], lang: string): Hit[] {
  const byKey = new Map<string, Hit>();
  for (const page of data) {
    const url = clean(page.url);
    const contentLang = page.filters.lang?.[0] ?? url.split("/")[1] ?? "en";
    const key = url.replace(/^\/(en|vi)/, "");
    const local = (u: string) => (contentLang === lang ? u : u.replace(/^\/(en|vi)/, `/${lang}`));
    const hit: Hit = {
      key,
      url: local(url),
      contentLang,
      section: page.filters.section?.[0] ?? "",
      title: page.meta.title ?? url,
      crumb: page.meta.crumb ?? "",
      excerpt: page.excerpt,
      subs: page.sub_results
        .filter((s) => s.url.includes("#") && s.title !== page.meta.title)
        .slice(0, 2)
        .map((s) => ({ title: s.title, url: local(clean(s.url)), excerpt: s.excerpt })),
    };
    const existing = byKey.get(key);
    if (!existing || (existing.contentLang !== lang && contentLang === lang)) byKey.set(key, hit);
  }
  const hits = [...byKey.values()];
  return [...hits.filter((h) => h.contentLang === lang), ...hits.filter((h) => h.contentLang !== lang)];
}

const escapeHtml = (text: string) => text.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

/** Escape `text` and wrap query words in <mark class="hl">. */
export function highlight(text: string, query: string): string {
  const words = query
    .trim()
    .split(/\s+/)
    .filter((w) => w.length > 1)
    .map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
  if (words.length === 0) return escapeHtml(text);
  // split() with a capture group puts the matches at odd indexes.
  return text
    .split(new RegExp(`(${words.join("|")})`, "giu"))
    .map((part, i) => (i % 2 ? `<mark class="hl">${escapeHtml(part)}</mark>` : escapeHtml(part)))
    .join("");
}
