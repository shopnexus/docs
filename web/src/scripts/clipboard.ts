/** Copy buttons: fenced code blocks and "Copy page" (page Markdown embedded at build). */
async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}

export function copyLink(): Promise<boolean> {
  return copyText(location.href.split("#")[0] ?? location.href);
}

document.addEventListener("click", async (event) => {
  const target = event.target as Element;

  const codeButton = target.closest<HTMLElement>("[data-copy-code]");
  if (codeButton) {
    const code = codeButton.closest(".code-block")?.querySelector("pre code")?.textContent ?? "";
    if (await copyText(code)) {
      codeButton.classList.add("copied");
      setTimeout(() => codeButton.classList.remove("copied"), 1200);
    }
    return;
  }

  const pageButton = target.closest<HTMLElement>("[data-copy-page]");
  if (pageButton) {
    const source = document.querySelector("[data-page-markdown]")?.textContent;
    if (!source) return;
    const label = pageButton.querySelector("[data-copy-page-label]");
    const original = label?.textContent ?? "";
    if ((await copyText(JSON.parse(source) as string)) && label) {
      label.textContent = pageButton.dataset.copiedLabel ?? original;
      setTimeout(() => {
        label.textContent = original;
      }, 1200);
    }
  }
});
