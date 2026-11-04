/**
 * Top bar and left nav are persisted across <ClientRouter/> navigations, so their
 * page-dependent state (active tab, language link, active page) is refreshed here.
 */
const isMac = /Mac|iPhone|iPad/.test(navigator.userAgent);

export function syncChrome() {
  const meta = document.querySelector<HTMLElement>("[data-page-meta]")?.dataset ?? {};
  const path = location.pathname.replace(/\/$/, "") || "/";

  for (const link of document.querySelectorAll<HTMLElement>("[data-tab-link]")) {
    if (link.dataset.tabLink === meta.tab) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  }
  for (const option of document.querySelectorAll<HTMLAnchorElement>("[data-lang-option]")) {
    if (option.dataset.langOption !== meta.lang && meta.altUrl) option.href = meta.altUrl;
  }
  for (const link of document.querySelectorAll<HTMLAnchorElement>("[data-nav-link]")) {
    const active = link.pathname.replace(/\/$/, "") === path;
    if (active) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  }
  for (const kbd of document.querySelectorAll("[data-mod-key]")) {
    kbd.textContent = isMac ? "⌘K" : "Ctrl K";
  }
  try {
    if (meta.lang) localStorage.setItem("docs-lang", meta.lang);
  } catch {
    /* storage unavailable */
  }

  // Keep the active page visible in a long left nav (first load or tab change).
  const scroller = document.querySelector<HTMLElement>("[data-nav-scroll]");
  const active = scroller?.querySelector<HTMLElement>('[aria-current="page"]');
  if (scroller && active) {
    const top = active.offsetTop - scroller.scrollTop;
    if (top < 40 || top > scroller.clientHeight - 40) {
      scroller.scrollTop = active.offsetTop - scroller.clientHeight / 3;
    }
  }
}

document.addEventListener("click", (event) => {
  const target = event.target as Element;
  const drawer = document.querySelector<HTMLDialogElement>("[data-drawer]");
  if (!drawer) return;
  if (target.closest("[data-drawer-open]")) drawer.showModal();
  else if (target.closest("[data-drawer-close]") || target === drawer) drawer.close();
  else if (drawer.open && target.closest("[data-drawer] a[href]")) drawer.close();
  else if (drawer.open && target.closest("[data-drawer] [data-search-open]")) drawer.close();
});
