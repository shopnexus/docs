/** Keep glossary hovercards inside the viewport horizontally. */
function place(term: HTMLElement) {
  const card = term.querySelector<HTMLElement>(".term-card");
  if (!card) return;
  // A term can wrap; the card's containing block starts at the first line fragment.
  const rect = term.getClientRects()[0] ?? term.getBoundingClientRect();
  const width = card.offsetWidth;
  const left = Math.min(0, innerWidth - 12 - (rect.left + width));
  card.style.setProperty("--term-x", `${Math.max(left, 12 - rect.left)}px`);
}

for (const type of ["pointerover", "focusin"] as const) {
  document.addEventListener(type, (event) => {
    const term = (event.target as Element).closest?.<HTMLElement>("[data-term]");
    if (term) place(term);
  });
}

// Hidden cards still take layout space, so an unplaced card near the right edge widens the page
// (horizontal scroll on phones). Place every card up front, and again when the width changes.
const placeAll = () => {
  for (const term of document.querySelectorAll<HTMLElement>("[data-term]")) place(term);
};
document.addEventListener("astro:page-load", placeAll);
addEventListener("resize", placeAll, { passive: true });
