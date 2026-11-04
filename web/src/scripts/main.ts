/**
 * Client entry. Modules register delegated listeners once (they survive <ClientRouter/>
 * navigations); per-page setup runs on every `astro:page-load`.
 */
import { syncChrome } from "./chrome";
import { initFeedback } from "./feedback";
import { initDiagrams } from "./mermaid";
import { initSearch } from "./search";
import { initSteps } from "./steps";
import { initTabs } from "./tabs";
import { syncControls } from "./theme";
import { initToc } from "./toc";
import "./clipboard";
import "./shot";
import "./term";

document.addEventListener("astro:page-load", () => {
  syncChrome();
  syncControls();
  initTabs();
  initSteps();
  initToc();
  initDiagrams();
  initFeedback();
  initSearch();
});
