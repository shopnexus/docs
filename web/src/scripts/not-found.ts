import { stripBase, withBase } from "../lib/base";
import { loadPagefind, searchPages } from "./search/pagefind";
import { toHits } from "./search/results";

/**
 * 404: show the reader's language, the broken path, and the three pages whose content
 * best matches the words in that path (e.g. /user-guide/your-usage → "your usage").
 */
export async function guessPages() {
  const route = stripBase(location.pathname);
  const lang = route.startsWith("/vi") ? "vi" : "en";
  for (const block of document.querySelectorAll<HTMLElement>("[data-404]")) {
    block.hidden = block.dataset["404"] !== lang;
  }
  const block = document.querySelector<HTMLElement>(`[data-404="${lang}"]`);
  if (!block) return;
  const path = block.querySelector("[data-404-path]");
  if (path) path.textContent = location.pathname;

  const words = route
    .split("/")
    .filter((part) => part && part !== "en" && part !== "vi" && part !== "404")
    .slice(-2)
    .join(" ")
    .replace(/[-_.]+/g, " ")
    .replace(/\b(html?|mdx|index|user guide|your)\b/gi, " ")
    .trim();
  const list = block.querySelector<HTMLElement>("[data-404-guesses]");
  const template = document.querySelector<HTMLTemplateElement>("template[data-404-guess]");
  if (!words || !list || !template) return;

  const api = await loadPagefind();
  if (!api) return;
  const hits = toHits(await searchPages(api, words, 12), lang).slice(0, 3);
  list.replaceChildren(
    ...hits.map((hit) => {
      const node = template.content.firstElementChild?.cloneNode(true) as HTMLAnchorElement;
      node.href = withBase(hit.url);
      const title = node.querySelector("[data-guess-title]");
      const crumb = node.querySelector("[data-guess-crumb]");
      if (title) title.textContent = hit.title;
      if (crumb) crumb.textContent = hit.crumb;
      return node;
    }),
  );
}
