import type { AstroGlobal } from "astro";
import { stripBase } from "./base";
import type { Lang } from "./i18n";

/** Language of the page being rendered: Astro's i18n locale, else the first URL segment. */
export function pageLang(astro: Pick<AstroGlobal, "currentLocale" | "url">): Lang {
  const pick = astro.currentLocale ?? stripBase(astro.url.pathname).split("/")[1];
  return pick === "vi" ? "vi" : "en";
}
