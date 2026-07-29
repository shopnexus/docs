# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is the **documentation/report repository** for a graduation internship (thực tập tốt nghiệp) at PTIT HCM. The subject system is **ShopNexus**, a C2C e-commerce platform built on a service-oriented / durable-microservices architecture. The actual ShopNexus source code lives elsewhere (sibling `shopnexus/` repos); this repo only holds writing, diagrams, and the typeset deliverables.

The internship produces three kinds of report — weekly progress reports, periodic reports, and one final report — all typeset from `typst/`.

The content is written in **Vietnamese**. Preserve Vietnamese diacritics in all edits.

## Build

The deliverables are typeset with **Typst** (v0.15+). Always build through the Makefile from inside `typst/`:

```bash
cd typst
make            # list targets
make all        # everything
make tuan       # 3 weekly reports
make dinh-ky    # 2 periodic reports
make cuoi       # final report
make spec       # project source-of-truth document
make watch SRC=bao-cao-cuoi/main.typ    # live preview
```

PDFs land in `typst/out/` (gitignored). **Do not call `typst compile` bare** — every
document imports from `common/`, so `--root .` is mandatory, and the submission font
lives in `common/fonts`, so `--font-path` is too. The Makefile supplies both.

Required system fonts: **TeX Gyre Termes** (serif body), **TeX Gyre Heros** (sans headings),
**DejaVu Sans Mono** (code). `SVN-Times New Roman` ships in `common/fonts/`.
The `fletcher` package is fetched from the Typst preview registry on first compile.

## Repository structure

Two top-level areas with very different roles:

- **`manual/`** — raw source material and authoring inputs, *not* compiled. This is where research, drafts, and references live before they become report prose:
  - `technique/` — numbered methodology guides (`1.1-vision.txt` … `7.5-implementation-plan.txt`) describing the analysis/design steps the report follows. The numbering roughly maps to report sections.
  - `diagram/` — exported diagram images (`.webp`/`.png`/`.svg`) plus per-type `hướng dẫn.txt` guidance notes (usecase, ERD, sequence, class, component, architecture, wireframe, activity, system context).
  - `*.txt` (`total recipe.txt`, `delivarable.txt`, `phần *.txt`) — long-form drafts and the consolidated brief.
  - `teacher_messages.txt` — the original assignment brief / scope from the instructor.

- **`typst/`** — the compiled deliverables. See `typst/README.md` for the full map. There are
  **three kinds of report**, one directory each:

  | Kind | Directory | Count |
  |---|---|---|
  | Weekly progress report | `bao-cao-tuan/` | 3 |
  | Periodic report (báo cáo định kỳ) | `bao-cao-dinh-ky/lan-1/`, `lan-2/` | 2 |
  | Final report (báo cáo cuối) | `bao-cao-cuoi/` | 1 |

  Plus `spec/source-of-truth.typ` — the project reference document, not a submitted report.

  Shared code lives in `typst/common/` and is the single source for everything:
  - `info.typ` — team, topic, advisor, class, student list. Change it here, every report follows.
  - `tokens.typ` — fonts, grayscale palette, fletcher diagram helpers (`fig`, `nt`, `np`, …), `note`, `wireframe`, `sechead`, `mockup`. Re-exports `fletcher` so chapters need only this one import.
  - `style-quyen.typ` — bound-volume template per QĐ 923/QĐ-HV (periodic + final reports).
  - `style-a4.typ` — lighter A4 template (weekly reports + spec).
  - `refs.bib`, `assets/` (incl. `assets/mockups/`), `fonts/`.

## Typst authoring conventions

- **Apply the template once**, in each report's `main.typ` (`#show: quyen.with(...)` or `#show: a4.with(...)`). Chapter files never re-apply it.
- **One import per chapter file:** `#import "../../common/tokens.typ": *`. Do not import `@preview/fletcher` again — `tokens.typ` re-exports it.
- **Never redefine design tokens in a chapter.** Duplicated palette/helper blocks were consolidated into `common/tokens.typ`; don't reintroduce them.
- **Never hardcode team/topic strings** — read them from `common/info.typ`.
- **Diagrams** are drawn inline with **fletcher** and wrapped in `fig(caption, ...)`, which produces a `figure` with `kind: image` so it lands in the *Danh mục các hình*. Bare `figure` for a diagram is a bug. UI screenshots go through `mockup("name")`.
- **Code blocks**: plain fenced blocks; the templates style raw blocks globally.
- **Visual style is intentionally grayscale/academic** (reports are printed black-and-white). Reuse tokens from `common/tokens.typ` rather than hardcoding colors.
- **Headings are auto-numbered** — `CHƯƠNG n:` / `n.m` / `n.m.k` in volumes, `1.1.` in A4 docs. Numbered level-1 headings force a page break; unnumbered sections use `sechead(...)` and need an explicit `#pagebreak()`.

## Working with this repo

- When writing or revising a chapter, the corresponding `manual/technique/*.txt` guide and `manual/diagram/*/hướng dẫn.txt` notes are the intended source material — consult them for the methodology and intended figures.
- Keep `common/refs.bib` entries consistent with the existing style; cite with Typst's `@key` syntax.
- This repo contains no application code, tests, or linters — "verification" means `make all` compiles cleanly with no warnings and the PDFs render as intended.
- `typst/tmp/` holds retired drafts and unused files; it is gitignored and safe to ignore.
