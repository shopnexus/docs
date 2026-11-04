/** "On this page": active heading via IntersectionObserver, sliding bar, mobile bar + read progress. */
let observer: IntersectionObserver | undefined;
let onScroll: (() => void) | undefined;

export function initToc() {
  observer?.disconnect();
  if (onScroll) removeEventListener("scroll", onScroll);

  const links = [...document.querySelectorAll<HTMLAnchorElement>("[data-toc-link]")];
  const slugs = [...new Set(links.map((l) => l.dataset.tocLink ?? ""))];
  const headings = slugs.map((slug) => document.getElementById(slug)).filter((h): h is HTMLElement => h !== null);
  if (headings.length === 0) return;

  const bar = document.querySelector<HTMLElement>("[data-toc-bar]");
  const current = document.querySelector<HTMLElement>("[data-mobile-toc-current]");
  const count = document.querySelector<HTMLElement>("[data-mobile-toc-count]");
  const progress = document.querySelector<HTMLElement>("[data-read-progress]");
  const visible = new Set<string>();

  const activate = (slug: string) => {
    const index = slugs.indexOf(slug);
    for (const link of links) link.classList.toggle("is-active", link.dataset.tocLink === slug);
    const desk = document.querySelector<HTMLElement>(`[data-toc] [data-toc-link="${CSS.escape(slug)}"]`);
    if (bar && desk) {
      bar.style.setProperty("--toc-y", `${desk.offsetTop}px`);
      bar.style.setProperty("--toc-h", `${desk.offsetHeight}px`);
      bar.style.setProperty("--toc-o", "1");
    }
    if (current) current.textContent = headings[index]?.textContent?.trim() ?? "";
    if (count) count.textContent = `${index + 1}/${slugs.length}`;
  };

  observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) visible.add(entry.target.id);
        else visible.delete(entry.target.id);
      }
      // Topmost visible heading wins; above all of them, keep the last one passed.
      const first = headings.find((h) => visible.has(h.id));
      const passed = headings.filter((h) => h.getBoundingClientRect().top < 120).at(-1);
      const pick = first ?? passed ?? headings[0];
      if (pick) activate(pick.id);
    },
    { rootMargin: "-88px 0px -55% 0px" },
  );
  for (const heading of headings) observer.observe(heading);

  onScroll = () => {
    if (!progress) return;
    const body = document.querySelector<HTMLElement>("[data-doc-body]");
    if (!body) return;
    const rect = body.getBoundingClientRect();
    const total = rect.height - innerHeight / 2;
    const read = Math.min(1, Math.max(0, (innerHeight / 3 - rect.top) / Math.max(total, 1)));
    progress.style.width = `${(read * 100).toFixed(1)}%`;
  };
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();
  activate(headings[0]?.id ?? "");
}

document.addEventListener("click", (event) => {
  const link = (event.target as Element).closest("[data-mobile-toc] a");
  if (link) link.closest("details")?.removeAttribute("open");
});
