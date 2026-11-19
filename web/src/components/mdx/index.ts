import RunPreview from "../agent/run-preview.astro";
import ApiPlayground from "../api/api-playground.astro";
import GlossaryList from "../glossary/glossary-list.astro";
import Req from "../requirements/req.astro";
import ReqTable from "../requirements/req-table.astro";
import UseCases from "../requirements/use-cases.astro";
import Accordion from "./accordion.astro";
import AccordionGroup from "./accordion-group.astro";
import Callout from "./callout.astro";
import Card from "./card.astro";
import Cards from "./cards.astro";
import DoDont from "./do-dont.astro";
import Kbd from "./kbd.astro";
import KeyRules from "./key-rules.astro";
import Prereqs from "./prereqs.astro";
import Sequence from "./sequence.astro";
import Shot from "./shot.astro";
import Statuses from "./statuses.astro";
import Step from "./step.astro";
import Steps from "./steps.astro";
import Tab from "./tab.astro";
import Tabs from "./tabs.astro";
import Term from "./term.astro";
import UI from "./ui-label.astro";

/** Global MDX components — content files use these without imports. */
export const components = {
  Accordion,
  ApiPlayground,
  AccordionGroup,
  Callout,
  Card,
  Cards,
  DoDont,
  Glossary: GlossaryList,
  Kbd,
  KeyRules,
  Prereqs,
  Req,
  ReqTable,
  RunPreview,
  Sequence,
  Shot,
  Statuses,
  Step,
  Steps,
  Tab,
  Tabs,
  Term,
  UI,
  UseCases,
};
