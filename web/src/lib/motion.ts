import type { TransitionDirectionalAnimations } from "astro";

/** Page enter for <ClientRouter/>: old content fades out, new content fades up 8px (DS §6). */
const swap = {
  old: { name: "fade-out", duration: "120ms", easing: "ease-in", fillMode: "both" },
  new: {
    name: "fade-up",
    duration: "220ms",
    easing: "cubic-bezier(.16,1,.3,1)",
    fillMode: "both",
  },
};

export const contentEnter: TransitionDirectionalAnimations = { forwards: swap, backwards: swap };
