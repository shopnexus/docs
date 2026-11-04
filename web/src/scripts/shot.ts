/** Annotated screenshots: hotspot ↔ legend linking, pulse stops after first interaction, lightbox. */
function highlight(shot: Element, n: string | undefined) {
  for (const el of shot.querySelectorAll<HTMLElement>("[data-point]")) {
    el.classList.toggle("is-active", n !== undefined && el.dataset.point === n);
  }
}

function setActual(dialog: HTMLDialogElement, actual: boolean) {
  dialog.classList.toggle("is-actual", actual);
  dialog.querySelector("[data-shot-fit]")?.setAttribute("aria-pressed", String(!actual));
  dialog.querySelector("[data-shot-actual]")?.setAttribute("aria-pressed", String(actual));
}

document.addEventListener("pointerover", (event) => {
  const point = (event.target as Element).closest<HTMLElement>("[data-shot] [data-point]");
  const shot = point?.closest("[data-shot]");
  if (!point || !shot) return;
  shot.classList.add("touched");
  highlight(shot, point.dataset.point);
});

document.addEventListener("pointerout", (event) => {
  const point = (event.target as Element).closest("[data-shot] [data-point]");
  const shot = point?.closest("[data-shot]");
  if (shot && !point?.contains(event.relatedTarget as Node)) highlight(shot, undefined);
});

document.addEventListener("focusin", (event) => {
  const point = (event.target as Element).closest<HTMLElement>("[data-shot] [data-point]");
  const shot = point?.closest("[data-shot]");
  if (point && shot) highlight(shot, point.dataset.point);
});

document.addEventListener("click", (event) => {
  const target = event.target as Element;
  const shot = target.closest("[data-shot]");
  if (!shot) return;
  shot.classList.add("touched");
  const dialog = shot.querySelector<HTMLDialogElement>("[data-shot-dialog]");
  if (!dialog) return;

  if (dialog.contains(target)) {
    if (target === dialog || target.closest("[data-shot-close]")) dialog.close();
    else if (target.closest("[data-shot-fit]")) setActual(dialog, false);
    else if (target.closest("[data-shot-actual]")) setActual(dialog, true);
    else if (target.closest(".shot-frame-large")) setActual(dialog, !dialog.classList.contains("is-actual"));
    return;
  }
  const hotspot = target.closest<HTMLElement>(".shot-frame [data-point]");
  if (hotspot) {
    // A hotspot click points at its legend line instead of opening the lightbox.
    const item = shot.querySelector<HTMLElement>(`.shot-legend [data-point="${hotspot.dataset.point}"]`);
    item?.scrollIntoView({ block: "nearest", behavior: "smooth" });
    highlight(shot, hotspot.dataset.point);
    return;
  }
  if (target.closest("[data-shot-frame]")) {
    setActual(dialog, false);
    dialog.showModal();
  }
});
