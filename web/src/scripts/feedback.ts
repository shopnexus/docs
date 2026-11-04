/** "Was this page helpful?" — stored in this browser only; no data leaves the page. */
const key = () => `docs-feedback:${location.pathname.replace(/\/$/, "")}`;

function show(vote: string | null) {
  const root = document.querySelector<HTMLElement>("[data-feedback]");
  if (!root) return;
  for (const button of root.querySelectorAll<HTMLElement>("[data-feedback-vote]")) {
    button.setAttribute("aria-pressed", String(button.dataset.feedbackVote === vote));
  }
  root.querySelector<HTMLElement>("[data-feedback-question]")?.classList.toggle("hidden", vote !== null);
  root.querySelector<HTMLElement>("[data-feedback-thanks]")?.classList.toggle("hidden", vote === null);
  root.querySelector<HTMLElement>("[data-feedback-thanks]")?.classList.toggle("flex", vote !== null);
}

export function initFeedback() {
  let vote: string | null = null;
  try {
    vote = localStorage.getItem(key());
  } catch {
    /* storage unavailable */
  }
  show(vote);
  // The "not translated yet" banner stays dismissed for the browser session.
  try {
    if (sessionStorage.getItem("docs-untranslated-dismissed") === "1") {
      document.querySelector("[data-untranslated]")?.remove();
    }
  } catch {
    /* storage unavailable */
  }
}

document.addEventListener("click", (event) => {
  const target = event.target as Element;
  const button = target.closest<HTMLElement>("[data-feedback-vote]");
  if (button) {
    const vote = button.getAttribute("aria-pressed") === "true" ? null : (button.dataset.feedbackVote ?? null);
    try {
      if (vote) localStorage.setItem(key(), vote);
      else localStorage.removeItem(key());
    } catch {
      /* storage unavailable */
    }
    show(vote);
    return;
  }
  if (target.closest("[data-untranslated-close]")) {
    document.querySelector("[data-untranslated]")?.remove();
    try {
      sessionStorage.setItem("docs-untranslated-dismissed", "1");
    } catch {
      /* storage unavailable */
    }
  }
});
