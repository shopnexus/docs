/** <Tabs>: pair panels with labels by order, underline indicator, arrow-key navigation. */
let uid = 0;

function select(root: HTMLElement, index: number, focus = false) {
  const tabs = [...root.querySelectorAll<HTMLElement>(":scope > .tabs-list > [role=tab]")];
  const panels = [...root.querySelectorAll<HTMLElement>(":scope > [data-tabs-panels] > [data-tab-panel]")];
  tabs.forEach((tab, i) => {
    const on = i === index;
    tab.setAttribute("aria-selected", String(on));
    tab.tabIndex = on ? 0 : -1;
    if (on && focus) tab.focus();
  });
  panels.forEach((panel, i) => {
    panel.hidden = i !== index;
  });
  const active = tabs[index];
  const indicator = root.querySelector<HTMLElement>(":scope > .tabs-list > [data-tabs-indicator]");
  if (active && indicator) {
    indicator.style.setProperty("--x", `${active.offsetLeft}px`);
    indicator.style.setProperty("--w", `${active.offsetWidth}px`);
  }
}

export function initTabs() {
  for (const root of document.querySelectorAll<HTMLElement>("[data-tabs]")) {
    const tabs = [...root.querySelectorAll<HTMLElement>(":scope > .tabs-list > [role=tab]")];
    const panels = [...root.querySelectorAll<HTMLElement>(":scope > [data-tabs-panels] > [data-tab-panel]")];
    const id = `tabs-${++uid}`;
    tabs.forEach((tab, i) => {
      tab.id = `${id}-tab-${i}`;
      tab.setAttribute("aria-controls", `${id}-panel-${i}`);
    });
    panels.forEach((panel, i) => {
      panel.id = `${id}-panel-${i}`;
      panel.setAttribute("aria-labelledby", `${id}-tab-${i}`);
    });
    root.classList.add("is-ready");
    select(
      root,
      Math.max(
        0,
        tabs.findIndex((t) => t.getAttribute("aria-selected") === "true"),
      ),
    );
  }
}

document.addEventListener("click", (event) => {
  const tab = (event.target as Element).closest<HTMLElement>("[data-tabs] [role=tab]");
  const root = tab?.closest<HTMLElement>("[data-tabs]");
  if (tab && root) select(root, Number(tab.dataset.tabIndex ?? 0));
});

document.addEventListener("keydown", (event) => {
  const tab = (event.target as Element).closest?.<HTMLElement>("[data-tabs] [role=tab]");
  const root = tab?.closest<HTMLElement>("[data-tabs]");
  if (!tab || !root || (event.key !== "ArrowRight" && event.key !== "ArrowLeft")) return;
  const count = root.querySelectorAll(":scope > .tabs-list > [role=tab]").length;
  const step = event.key === "ArrowRight" ? 1 : -1;
  select(root, (Number(tab.dataset.tabIndex ?? 0) + step + count) % count, true);
  event.preventDefault();
});
