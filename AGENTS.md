# docs

Documentation for ShopNexus, a C2C marketplace for used goods: cash on
delivery with inspection at the door, through the seller's own carrier
account. The platform holds no deal money, so no page mentions escrow, a
wallet or a refund of a deal. The only money it takes is a seller's boost
payment. No refunds: not for deals, not for boosts (ADR-0006). The code lives in the sibling repositories
(`server`, `agent`, `clients`); this repository holds only writing.

## What lives where

| Area | Role |
|---|---|
| `web/` | The docs site (Astro + MDX). **The source of truth for how the system works**: flows, states, rules, limits, what happens on failure. |
| `registry/` | `requirements.yaml`, the only list of UC, FR, BR, NFR and ADR IDs, and `trace.json`, written from the server code by `make trace` in the umbrella. |
| `typst/` | The Vietnamese thesis reports and slides. They follow the site and the registry; they are never the source. |
| `i18n/` | The glossary every product's wording follows (`i18n/README.md`). |
| `superpowers/` | Dated specs, plans and reports. History only: they explain why a past decision was made, and the site wins wherever they disagree. |
| `manual/` | Raw thesis inputs: methodology guides, diagram notes, the instructor's brief. Not compiled. |

## The site is the record

The server keeps no architecture file; the site is the record. A change
to a flow, a state, a rule or a limit updates its page in the same piece of
work: the server commit and the docs commit land together.

- Find the page by tab: `architecture/` (modules and their flows), `api/`
  (what every client sees: auth, errors, paging, idempotency, live updates),
  `agent/` (the console agent), `marketplace/` (the rules as users meet
  them, no internals), `operations/` (stack, cluster, monitoring, tests),
  `requirements/` (generated from the registry).
- English is the source. Edit `web/src/content/docs/en/…`; the Vietnamese
  page under `vi/` is translated later, so leave it unless asked.
- Write for a reader who opens one page to change one part. Tell a flow in
  order: who starts it, the steps, the state that changes, who reacts, what
  happens on failure or a race. A flow with three or more steps or states
  gets a mermaid diagram or a `<Sequence>`.
- Keep pages above the code: modules, states, events, rules, endpoints and
  error codes a client handles. No Go names, file paths, env vars (except
  on operations pages), version pins, decision dates or "X until Y"
  history: the code and git hold those.
- Plain English, short sentences, one idea per paragraph. A page reads in
  under about eight minutes; split it when it grows past that.
- A requirement ID is `<Req id="…" />` and must exist in the registry, or
  the build fails. Run `make trace` in the umbrella after editing the
  registry or prose that names an ID.

`web/README.md` lists the frontmatter, the components and the commands.
Check a change with `bun run check` and `bun run build` in `web/`.

## Typst reports

Write in Vietnamese and keep the diacritics. Build only through the Makefile
in `typst/` (`make` lists the targets); a bare `typst compile` misses the
root and font paths the documents need. PDFs land in `typst/out/`.

- Apply the template once, in each report's `main.typ`. A chapter imports
  only `common/tokens.typ`, plus `common/req.typ` when it prints requirement
  tables.
- Requirement tables and use case specs are generated from the registry;
  edit the YAML, not the table. Team and topic strings come from
  `common/info.typ`, colours and diagram helpers from `common/tokens.typ`;
  never redefine them in a chapter.
- A diagram is fletcher inside `fig(caption, …)`, so it lands in the list of
  figures. The reports print in black and white, so they stay grayscale.
- Verification is `make all` compiling with no warnings.
