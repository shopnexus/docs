import GlossaryList from "../glossary/glossary-list.astro";
import Accordion from "./accordion.astro";
import AccordionGroup from "./accordion-group.astro";
import Callout from "./callout.astro";
import Card from "./card.astro";
import Cards from "./cards.astro";
import Kbd from "./kbd.astro";
import KeyRules from "./key-rules.astro";
import Prereqs from "./prereqs.astro";
import Shot from "./shot.astro";
import Step from "./step.astro";
import Steps from "./steps.astro";
import Tab from "./tab.astro";
import Tabs from "./tabs.astro";
import Term from "./term.astro";
import UI from "./ui-label.astro";

/** Global MDX components — content files use these without imports. */
export const components = {
  Accordion,
  AccordionGroup,
  Callout,
  Card,
  Cards,
  Glossary: GlossaryList,
  Kbd,
  KeyRules,
  Prereqs,
  Shot,
  Step,
  Steps,
  Tab,
  Tabs,
  Term,
  UI,
};
