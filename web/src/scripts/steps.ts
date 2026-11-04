/** Steps: tick a step (remembered per page in localStorage), progress bar, connector fill on scroll. */
let onScroll: (() => void) | undefined;

const key = (index: number) => `docs-steps:${location.pathname}:${index}`;

function read(index: number): boolean {
  try {
    return localStorage.getItem(key(index)) === "1";
  } catch {
    return false;
  }
}

function write(index: number, done: boolean) {
  try {
    if (done) localStorage.setItem(key(index), "1");
    else localStorage.removeItem(key(index));
  } catch {
    /* storage unavailable: ticks last for this visit only */
  }
}

function render(root: HTMLElement, offset: number) {
  const steps = [...root.querySelectorAll<HTMLElement>("[data-step]")];
  let done = 0;
  let currentSet = false;
  steps.forEach((step, i) => {
    const isDone = read(offset + i);
    if (isDone) done++;
    const isCurrent = !isDone && !currentSet;
    if (isCurrent) currentSet = true;
    step.classList.toggle("is-done", isDone);
    step.classList.toggle("is-current", isCurrent);
    const marker = step.querySelector<HTMLElement>("[data-step-marker]");
    marker?.setAttribute("aria-pressed", String(isDone));
    marker?.setAttribute("aria-label", `${root.dataset.markLabel ?? ""} ${i + 1}`);
  });
  const label = root.querySelector("[data-steps-label]");
  if (label) {
    label.textContent = (root.dataset.label ?? "")
      .replace("{done}", String(done))
      .replace("{total}", String(steps.length));
  }
  root
    .querySelector<HTMLElement>("[data-steps-fill]")
    ?.style.setProperty("--done", `${(done / Math.max(steps.length, 1)) * 100}%`);
}

export function initSteps() {
  if (onScroll) removeEventListener("scroll", onScroll);
  const groups = [...document.querySelectorAll<HTMLElement>("[data-steps]")];
  let offset = 0;
  for (const root of groups) {
    root.dataset.offset = String(offset);
    render(root, offset);
    offset += root.querySelectorAll("[data-step]").length;
  }
  if (groups.length === 0) return;

  // Fill the connector up to the step that has scrolled past the middle of the screen.
  onScroll = () => {
    for (const root of groups) {
      const line = root.querySelector<HTMLElement>("[data-steps-line]");
      const track = line?.parentElement;
      if (!line || !track) continue;
      const rect = track.getBoundingClientRect();
      const fill = Math.min(1, Math.max(0, (innerHeight * 0.55 - rect.top) / Math.max(rect.height, 1)));
      line.style.setProperty("--fill", `${(fill * 100).toFixed(1)}%`);
    }
  };
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();
}

document.addEventListener("click", (event) => {
  const marker = (event.target as Element).closest("[data-step-marker]");
  const root = marker?.closest<HTMLElement>("[data-steps]");
  if (!marker || !root) return;
  const steps = [...root.querySelectorAll("[data-step]")];
  const index = steps.indexOf(marker.closest("[data-step]") as Element);
  const offset = Number(root.dataset.offset ?? 0);
  write(offset + index, !read(offset + index));
  render(root, offset);
});
