/** System / Light / Dark theme with a circular View Transition reveal from the control. */
type Pref = "system" | "light" | "dark";

const KEY = "docs-theme";
const ORDER: Pref[] = ["system", "light", "dark"];
const media = matchMedia("(prefers-color-scheme: dark)");
const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");

export function currentPref(): Pref {
  const value = document.documentElement.dataset.themePref;
  return value === "light" || value === "dark" ? value : "system";
}

function resolve(pref: Pref): "light" | "dark" {
  return pref === "dark" || (pref === "system" && media.matches) ? "dark" : "light";
}

function apply(pref: Pref) {
  const root = document.documentElement;
  root.dataset.theme = resolve(pref);
  root.dataset.themePref = pref;
  try {
    localStorage.setItem(KEY, pref);
  } catch {
    /* private mode: the choice lasts for this page only */
  }
  syncControls();
}

/** Switch theme, revealing the new one as a circle growing from (x, y). */
export function setTheme(pref: Pref, origin?: { x: number; y: number }) {
  const root = document.documentElement;
  const changes = resolve(pref) !== root.dataset.theme;
  if (!changes || reducedMotion.matches) return apply(pref);
  if (!document.startViewTransition) {
    root.classList.add("theme-fade");
    apply(pref);
    setTimeout(() => root.classList.remove("theme-fade"), 220);
    return;
  }
  const x = origin?.x ?? innerWidth - 40;
  const y = origin?.y ?? 32;
  const radius = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
  root.classList.add("theme-vt");
  const transition = document.startViewTransition(() => apply(pref));
  transition.ready
    .then(() =>
      root.animate(
        { clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${radius}px at ${x}px ${y}px)`] },
        { duration: 280, easing: "cubic-bezier(.16,1,.3,1)", pseudoElement: "::view-transition-new(root)" },
      ),
    )
    .catch(() => undefined);
  transition.finished.finally(() => root.classList.remove("theme-vt"));
}

export function syncControls() {
  const pref = currentPref();
  for (const button of document.querySelectorAll<HTMLElement>("[data-theme-set]")) {
    button.setAttribute("aria-pressed", String(button.dataset.themeSet === pref));
  }
  for (const button of document.querySelectorAll<HTMLElement>("[data-theme-cycle]")) {
    const names = JSON.parse(button.dataset.themeNames ?? "{}") as Record<Pref, string>;
    button.setAttribute("aria-label", `${button.dataset.themeLabel}: ${names[pref] ?? pref}`);
  }
}

function originOf(el: Element) {
  const rect = el.getBoundingClientRect();
  return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
}

document.addEventListener("click", (event) => {
  const target = event.target as Element;
  const cycle = target.closest("[data-theme-cycle]");
  if (cycle) {
    const next = ORDER[(ORDER.indexOf(currentPref()) + 1) % ORDER.length] ?? "system";
    setTheme(next, originOf(cycle));
    return;
  }
  const set = target.closest<HTMLElement>("[data-theme-set]");
  if (set) setTheme(set.dataset.themeSet as Pref, originOf(set));
});

media.addEventListener("change", () => {
  if (currentPref() === "system") apply("system");
});
