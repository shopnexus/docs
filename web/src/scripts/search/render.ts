import type { SearchStrings } from "../../components/search/search-strings";
import { withBase } from "../../lib/base";
import { type Hit, highlight } from "./results";

export interface Scope {
  id: string;
  label: string;
}

const icon = (name: string) =>
  document.querySelector<HTMLTemplateElement>(`template[data-search-icon="${name}"]`)?.innerHTML ?? "";

const escapeAttr = (text: string) => text.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

function item(opts: {
  url: string;
  iconName: string;
  title: string;
  crumb: string;
  excerpt: string;
  badge?: string;
  query: string;
  i: number;
}): string {
  const badge = opts.badge ? `<span class="chip chip-outline h-5! px-1.5! text-[10.5px]!">${opts.badge}</span>` : "";
  return `<a href="${escapeAttr(withBase(opts.url))}" class="search-item" role="option" data-search-option data-search-result style="--i:${opts.i}">
    <span class="search-item-icon">${icon(opts.iconName)}</span>
    <span class="flex-1 min-w-0">
      <span class="search-item-title"><span>${highlight(opts.title, opts.query)}</span>${badge}</span>
      ${opts.crumb ? `<span class="search-item-crumb">${highlight(opts.crumb, opts.query)}</span>` : ""}
      ${opts.excerpt ? `<span class="search-item-excerpt search-excerpt">${opts.excerpt}</span>` : ""}
    </span>
    <span class="search-item-go">${icon("ri:arrow-right-s-line")}</span>
  </a>`;
}

/** Results grouped by section (tab order), each page followed by up to two matching headings. */
export function renderHits(hits: Hit[], scopes: Scope[], query: string, lang: string, s: SearchStrings): string {
  let i = 0;
  // Sections appear in the order of their best-ranked hit.
  const rank = (id: string) => hits.findIndex((h) => h.section === id);
  return scopes
    .filter((scope) => rank(scope.id) >= 0)
    .sort((a, b) => rank(a.id) - rank(b.id))
    .map((scope) => {
      const group = hits.filter((h) => h.section === scope.id);
      if (group.length === 0) return "";
      const rows = group.flatMap((hit) => {
        const glossary = hit.url.includes("/glossary");
        const badge = hit.contentLang !== lang ? s.englishBadge : undefined;
        const page = item({
          url: hit.url,
          iconName: glossary ? "ri:book-2-line" : "ri:file-text-line",
          title: hit.title,
          crumb: hit.crumb,
          excerpt: hit.excerpt,
          badge,
          query,
          i: i++,
        });
        const subs = hit.subs.map((sub) =>
          item({
            url: sub.url,
            iconName: glossary ? "ri:book-2-line" : "ri:hashtag",
            title: sub.title,
            crumb: hit.title,
            excerpt: sub.excerpt,
            badge,
            query,
            i: i++,
          }),
        );
        return [page, ...subs];
      });
      return `<p class="search-group">${scope.label}</p><div class="stagger">${rows.join("")}</div>`;
    })
    .join("");
}

export function renderRecent(recent: string[], removeLabel: string): string {
  return recent
    .map(
      (
        q,
        i,
      ) => `<button type="button" class="search-item search-item-compact group" role="option" data-search-option data-recent="${escapeAttr(q)}" style="--i:${i}">
      <span class="text-faint">${icon("ri:history-line")}</span>
      <span class="flex-1 text-left text-[14.5px] text-body truncate">${escapeAttr(q)}</span>
      <span class="search-item-remove" role="button" aria-label="${escapeAttr(removeLabel)}" data-recent-remove="${escapeAttr(q)}">${icon("ri:close-line")}</span>
    </button>`,
    )
    .join("");
}
