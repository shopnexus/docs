import { navigate } from "astro:transitions/client";
import type { SearchStrings } from "../../components/search/search-strings";
import { copyLink } from "../clipboard";
import { setTheme } from "../theme";
import { loadPagefind, searchPages } from "./pagefind";
import { renderHits, renderRecent, type Scope } from "./render";
import { type Hit, toHits } from "./results";

interface Config {
  lang: string;
  strings: SearchStrings;
  scopes: Scope[];
}

const RECENT_KEY = "docs-search-recent";
let hits: Hit[] = [];
let scope = "";
let token = 0;
let timer: number | undefined;

const $ = <T extends Element = HTMLElement>(sel: string) => document.querySelector<T>(sel);
const config = (): Config => JSON.parse($("[data-search-config]")?.textContent ?? "{}") as Config;

function readRecent(): string[] {
  try {
    return JSON.parse(localStorage.getItem(RECENT_KEY) ?? "[]") as string[];
  } catch {
    return [];
  }
}

function writeRecent(list: string[]) {
  try {
    localStorage.setItem(RECENT_KEY, JSON.stringify(list.slice(0, 5)));
  } catch {
    /* storage unavailable */
  }
}

function show(part: "idle" | "list" | "empty" | "status") {
  for (const name of ["idle", "list", "empty", "status"] as const) {
    const el = $(`[data-search-${name}]`);
    if (el) el.hidden = name !== part;
  }
}

function setActive(option: Element | undefined) {
  for (const el of document.querySelectorAll("[data-search] [aria-selected='true'][data-search-option]")) {
    el.setAttribute("aria-selected", "false");
  }
  option?.setAttribute("aria-selected", "true");
  option?.scrollIntoView({ block: "nearest" });
}

function options(): HTMLElement[] {
  return [...document.querySelectorAll<HTMLElement>("[data-search-results] [data-search-option]")].filter(
    (el) => el.offsetParent !== null,
  );
}

function renderIdle() {
  const { strings } = config();
  const recent = readRecent();
  const wrap = $("[data-search-recent]");
  const list = $("[data-search-recent-list]");
  if (wrap && list) {
    wrap.hidden = recent.length === 0;
    list.innerHTML = renderRecent(recent, strings.clear);
  }
  const themeLabel = $("[data-theme-action-label]");
  if (themeLabel)
    themeLabel.textContent =
      document.documentElement.dataset.theme === "dark" ? strings.toggleThemeLight : strings.toggleTheme;
  const count = $("[data-search-count]");
  if (count) count.textContent = strings.langs;
  for (const el of document.querySelectorAll("[data-scope-count]")) el.textContent = "";
  show("idle");
  setActive(options()[0]);
}

function renderResults(query: string) {
  const { lang, strings, scopes } = config();
  const visible = scope ? hits.filter((h) => h.section === scope) : hits;
  for (const el of document.querySelectorAll<HTMLElement>("[data-scope-count]")) {
    const id = el.dataset.scopeCount ?? "";
    el.textContent = String(id ? hits.filter((h) => h.section === id).length : hits.length);
  }
  const count = $("[data-search-count]");
  if (count) count.textContent = strings.results.replace("{n}", String(visible.length));
  if (visible.length === 0) {
    const title = $("[data-search-empty-title]");
    if (title) title.textContent = strings.noResultsTitle.replace("{q}", query);
    show("empty");
    return;
  }
  const list = $("[data-search-list]");
  if (list) list.innerHTML = renderHits(visible, scopes, query, lang, strings);
  show("list");
  setActive(options()[0]);
}

async function run(query: string) {
  const mine = ++token;
  const { strings, lang } = config();
  if (!query.trim()) return renderIdle();
  const slow = setTimeout(() => {
    const status = $("[data-search-status]");
    if (status && mine === token) {
      status.textContent = strings.loading;
      show("status");
    }
  }, 180);
  const api = await loadPagefind();
  if (!api) {
    clearTimeout(slow);
    const status = $("[data-search-status]");
    if (status) status.textContent = strings.unavailable;
    return show("status");
  }
  const data = await searchPages(api, query);
  clearTimeout(slow);
  if (mine !== token) return;
  hits = toHits(data, lang);
  renderResults(query);
}

function setScope(id: string) {
  scope = id;
  for (const chip of document.querySelectorAll<HTMLElement>("[data-scope]")) {
    chip.setAttribute("aria-selected", String(chip.dataset.scope === id));
  }
  const input = $<HTMLInputElement>("[data-search-input]");
  if (input?.value.trim()) renderResults(input.value);
}

function setQuery(value: string) {
  const input = $<HTMLInputElement>("[data-search-input]");
  if (!input) return;
  input.value = value;
  const clear = $("[data-search-clear]");
  if (clear) clear.hidden = value === "";
  clearTimeout(timer);
  timer = window.setTimeout(() => run(value), 120);
}

export function openSearch() {
  const dialog = $<HTMLDialogElement>("[data-search]");
  if (!dialog || dialog.open) return;
  dialog.showModal();
  const input = $<HTMLInputElement>("[data-search-input]");
  input?.focus();
  input?.select();
  if (!input?.value) renderIdle();
  void loadPagefind();
}

function remember() {
  const q = $<HTMLInputElement>("[data-search-input]")?.value.trim();
  if (q) writeRecent([q, ...readRecent().filter((r) => r !== q)]);
}

async function runAction(action: string, el: HTMLElement) {
  const dialog = $<HTMLDialogElement>("[data-search]");
  const meta = $("[data-page-meta]")?.dataset;
  if (action === "lang" && meta?.altUrl) {
    dialog?.close();
    await navigate(meta.altUrl);
  } else if (action === "theme") {
    dialog?.close();
    setTheme(document.documentElement.dataset.theme === "dark" ? "light" : "dark");
  } else if (action === "copy-link" && (await copyLink())) {
    const label = el.querySelector("[data-copy-link-label]");
    if (label) label.textContent = config().strings.linkCopied;
  }
}

document.addEventListener("click", (event) => {
  const target = event.target as HTMLElement;
  if (target.closest("[data-search-open]")) return openSearch();
  const dialog = target.closest<HTMLDialogElement>("[data-search]");
  if (!dialog) return;
  if (target === dialog || target.closest("[data-search-close]")) return dialog.close();
  if (target.closest("[data-search-clear]")) return setQuery("");
  const chip = target.closest<HTMLElement>("[data-scope]");
  if (chip) return setScope(chip.dataset.scope ?? "");
  const remove = target.closest<HTMLElement>("[data-recent-remove]");
  if (remove) {
    writeRecent(readRecent().filter((r) => r !== remove.dataset.recentRemove));
    return renderIdle();
  }
  const recent = target.closest<HTMLElement>("[data-recent]");
  if (recent) return setQuery(recent.dataset.recent ?? "");
  const tryChip = target.closest<HTMLElement>("[data-search-try]");
  if (tryChip) return setQuery(tryChip.dataset.searchTry ?? "");
  const action = target.closest<HTMLElement>("[data-action]");
  if (action) return void runAction(action.dataset.action ?? "", action);
  if (target.closest("a[href]")) {
    remember();
    dialog.close();
  }
});

document.addEventListener("input", (event) => {
  const input = (event.target as Element).closest?.<HTMLInputElement>("[data-search-input]");
  if (input) setQuery(input.value);
});

document.addEventListener("keydown", (event) => {
  const mod = event.metaKey || event.ctrlKey;
  const typing = (event.target as HTMLElement).closest?.("input, textarea, [contenteditable]");
  if ((mod && event.key.toLowerCase() === "k") || (event.key === "/" && !typing)) {
    event.preventDefault();
    const dialog = $<HTMLDialogElement>("[data-search]");
    if (dialog?.open) dialog.close();
    else openSearch();
    return;
  }
  const dialog = $<HTMLDialogElement>("[data-search]");
  if (!dialog?.open) return;
  const list = options();
  const index = list.findIndex((el) => el.getAttribute("aria-selected") === "true");
  if (event.key === "ArrowDown" || event.key === "ArrowUp") {
    event.preventDefault();
    const step = event.key === "ArrowDown" ? 1 : -1;
    setActive(list[(index + step + list.length) % Math.max(list.length, 1)]);
  } else if (event.key === "Enter" && index >= 0 && (event.target as Element).matches("[data-search-input]")) {
    event.preventDefault();
    list[index]?.click();
  } else if (event.key === "Tab") {
    event.preventDefault();
    const ids = ["", ...config().scopes.map((s) => s.id)];
    const next = ids[(ids.indexOf(scope) + (event.shiftKey ? -1 : 1) + ids.length) % ids.length] ?? "";
    setScope(next);
  } else if (mod && event.key === "Backspace") {
    event.preventDefault();
    setQuery("");
  }
});

/** Called on every page load: the modal is re-rendered per page, the scope resets. */
export function initSearch() {
  scope = "";
  hits = [];
}
