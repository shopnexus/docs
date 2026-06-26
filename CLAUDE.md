# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is the **documentation/report repository** for a graduation internship report (báo cáo thực tập tốt nghiệp), subject INT1448 — *Phát triển phần mềm hướng dịch vụ* (Service-Oriented Software Development). The report's subject system is **ShopNexus**, an e-commerce platform built on a service-oriented / microservices architecture. The actual ShopNexus source code lives elsewhere (sibling `shopnexus/` repos); this repo only holds writing, diagrams, and the typeset deliverable.

The content is written in **Vietnamese**. Preserve Vietnamese diacritics in all edits.

## Build

The deliverables are typeset with **Typst** (currently v0.15.0). Build from inside `typst/`:

```bash
cd typst
typst compile main.typ main.pdf      # the report
typst compile slides.typ slides.pdf  # the presentation slides
```

Live preview while editing: `typst watch main.typ main.pdf`.

Required fonts (must be installed system-wide or passed via `--font-path`): **TeX Gyre Termes** (serif body), **TeX Gyre Heros** (sans headings/slides), **DejaVu Sans Mono** (code). Typst packages (`codly`, `fletcher`) are fetched automatically from the Typst preview registry on first compile.

## Repository structure

Two top-level areas with very different roles:

- **`manual/`** — raw source material and authoring inputs, *not* compiled. This is where research, drafts, and references live before they become report prose:
  - `technique/` — numbered methodology guides (`1.1-vision.txt` … `7.5-implementation-plan.txt`) describing the analysis/design steps the report follows. The numbering roughly maps to report sections.
  - `diagram/` — exported diagram images (`.webp`/`.png`/`.svg`) plus per-type `hướng dẫn.txt` guidance notes (usecase, ERD, sequence, class, component, architecture, wireframe, activity, system context).
  - `*.txt` (`total recipe.txt`, `delivarable.txt`, `phần *.txt`) — long-form drafts and the consolidated brief.
  - `teacher_messages.txt` — the original assignment brief / scope from the instructor.

- **`typst/`** — the compiled deliverable. This is the source of truth for the final document:
  - `main.typ` — report entry point. Sets up cover → front matter (Roman numerals) → table of contents → main body (Arabic numerals), then `#include`s the 13 chapter files **in order**. To add/reorder chapters, edit the include list here.
  - `slides.typ` — standalone 16:9 presentation; self-contained (does not import `lib/`), but keeps its color/font palette in sync with the report by convention.
  - `chapters/01-…` … `13-tai-lieu-tham-khao.typ` — one file per chapter, numbered by filename.
  - `lib/theme.typ` — global theme; `lib/cover.typ`, `lib/front.typ` — title page and acknowledgements/work-split tables.
  - `assets/` — images referenced by chapters (ER diagrams `er-*.png`, flows, `PTIT.png` logo).
  - `refs.bib` — bibliography (BibTeX).

## Typst authoring conventions

- **Apply the theme once.** `main.typ` calls `#show: report-theme` (from `lib/theme.typ`). Chapter files assume this is already active and do **not** re-apply it.
- **Every chapter file imports what it needs at the top.** Pattern: `#import "../lib/theme.typ": diag, c-primary, c-soft, c-mid, c-line` and, for diagrams, `#import "@preview/fletcher:0.5.7" as fletcher: diagram, node, edge`. Match the existing import style of neighboring chapters.
- **Diagrams** are drawn inline with **fletcher** and wrapped in the `diag(content, caption:, label:)` helper from `theme.typ`, which produces a `figure` with `kind: "diagram"` and supplement `[Hình]`. Use `diag` (not bare `figure`) so the figure appears in the *Danh mục hình* (list of figures) generated in `main.typ`. Imported diagram images go through `image("assets/…")` instead.
- **Code blocks** use **codly** (configured in `theme.typ` with line numbers, soft-gray fill). Just use fenced ```` ```go ```` blocks; styling is global.
- **Visual style is intentionally grayscale/academic.** The report palette (`c-primary`, `c-accent`, `c-soft`, `c-mid`, `c-line`) is defined in `theme.typ`; reuse these tokens rather than hardcoding colors. Slides add one PTIT-red accent (`#b3122b`).
- **Headings** are auto-numbered (level 1 = `I.`, deeper = `1.1.1.`) and level-1 headings force a page break. Don't hand-number headings.

## Working with this repo

- When writing or revising a chapter, the corresponding `manual/technique/*.txt` guide and `manual/diagram/*/hướng dẫn.txt` notes are the intended source material — consult them for the methodology and intended figures.
- Keep `refs.bib` entries consistent with the existing style; cite with Typst's `@key` syntax.
- This repo contains no application code, tests, or linters — "verification" means the Typst document compiles cleanly and the PDF renders as intended.
