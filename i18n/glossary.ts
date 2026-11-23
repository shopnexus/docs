#!/usr/bin/env bun
// glossary: keeps the products' words in line with i18n/glossary.yaml.
//
//   bun i18n/glossary.ts check  [root]   problems exit 1
//   bun i18n/glossary.ts render [root]   write manual/thuat-ngu.md from the glossary
//
// check scans the text people see, in every language a product writes: the
// app's res/values*/strings.xml, the website's src/i18n/<lang>, the server's
// <lang>.json catalogs. It fails on an avoided term outside the phrases that
// may hold it, on a shared phrase a product lacks word for word, and on a
// thuat-ngu.md that no longer matches the glossary. TERMS_APP,
// TERMS_WEBSITE and TERMS_SERVER point at another checkout of a repo, such
// as a worktree, relative to root.

import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";

type Lang = string;
type Words = { use: string[]; avoid?: string[] };
type Term = { meaning: string } & Record<Lang, Words | string>;
type Glossary = {
  languages: Lang[];
  intro: string;
  sections: { title: string; terms: Term[] }[];
  ui: Record<Lang, { phrase: string[]; instead_of: string; why: string }[]>;
  phrases: ({ id: string; why: string; in: Product[] } & Record<Lang, string>)[];
};
type Product = "app" | "website" | "server";
type Text = { file: string; where: string | number; text: string };

const [command = "check", rootArg] = process.argv.slice(2);
const root = resolve(rootArg ?? join(import.meta.dir, "../.."));
const glossaryFile = join(root, "docs/i18n/glossary.yaml");
const manualFile = join(root, "docs/manual/thuat-ngu.md");
const checkouts: Record<Product, string> = {
  app: join(root, process.env.TERMS_APP ?? "app"),
  website: join(root, process.env.TERMS_WEBSITE ?? "website"),
  server: join(root, process.env.TERMS_SERVER ?? "server"),
};

const g = Bun.YAML.parse(readFileSync(glossaryFile, "utf8")) as Glossary;
const words = (t: Term, lang: Lang) => t[lang] as Words | undefined;
const unparen = (s: string) => s.replace(/\s*\(.*?\)/g, "").trim();

// ── render ───────────────────────────────────────────────────────────────

const cell = (s: string) => s.replace(/\|/g, "\\|");

function render(): string {
  const out = [
    "# Thuật ngữ thống nhất",
    "",
    "<!-- Sinh từ docs/i18n/glossary.yaml bằng `bun docs/i18n/glossary.ts render`; sửa file yaml, không sửa file này. -->",
    "",
    g.intro.trim(),
    "",
    "`make i18n` (chạy `bun docs/i18n/glossary.ts check`) quét chữ trên giao diện của ứng dụng, website và máy chủ theo bảng này, mục \"Giao diện\" và mục \"Câu dùng chung\".",
  ];
  for (const s of g.sections) {
    out.push("", `## ${s.title}`, "", "| Dùng | Nghĩa | Không dùng | Tiếng Anh |", "|---|---|---|---|");
    for (const t of s.terms) {
      const vi = words(t, "vi");
      const en = words(t, "en");
      const enCell = en ? [en.use.join(", "), en.avoid?.length ? `(không dùng: ${en.avoid.join(", ")})` : ""].filter(Boolean).join(" ") : "";
      out.push(`| ${cell(vi?.use.join(", ") ?? "")} | ${cell(t.meaning)} | ${cell(vi?.avoid?.join(", ") ?? "")} | ${cell(enCell)} |`);
    }
  }
  out.push(
    "",
    "## Giao diện",
    "",
    "Cách gọi được phép trên giao diện dù cột \"Không dùng\" ở trên có liệt kê, vì nghĩa khác hoặc vì là tên riêng.",
    "",
    "| Dùng trên giao diện | Thay cho | Lý do |",
    "|---|---|---|",
    ...(g.ui.vi ?? []).map((u) => `| ${cell(u.phrase.join(", "))} | ${cell(u.instead_of)} | ${cell(u.why)} |`),
    "",
    "## Câu dùng chung",
    "",
    "Câu mà các sản phẩm ở cột \"Có ở\" phải viết y nguyên, trong mọi ngôn ngữ sản phẩm đó có.",
    "",
    "| Câu | Nói về | Có ở |",
    "|---|---|---|",
    ...g.phrases.map((p) => `| ${cell(p.vi)} | ${cell(p.why)} | ${p.in.join(", ")} |`),
  );
  return `${out.join("\n")}\n`;
}

if (command === "render") {
  writeFileSync(manualFile, render());
  console.log(`wrote ${relative(root, manualFile)}`);
  process.exit(0);
}

// ── texts ────────────────────────────────────────────────────────────────

/** The files under dir that keep accepts, skipping hidden, build and scratch
 * directories and never following a symlink. */
function walk(dir: string, keep: (path: string) => boolean): string[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const path = join(dir, e.name);
    if (e.name.startsWith(".") || ["build", "node_modules", "tmp"].includes(e.name)) return [];
    if (e.isDirectory()) return walk(path, keep);
    return e.isFile() && keep(path) ? [path] : [];
  });
}

const unescape = (s: string) =>
  s.replace(/\\(['"`\\])/g, "$1").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"');

/** Every string people see in product p, language lang. */
function texts(p: Product, lang: Lang): Text[] {
  const out: Text[] = [];
  const dir = checkouts[p];
  if (p === "app") {
    const folder = lang === g.languages[0] ? "values" : `values-${lang}`;
    for (const file of walk(dir, (f) => f.endsWith(`/src/main/res/${folder}/strings.xml`))) {
      for (const [i, line] of readFileSync(file, "utf8").split("\n").entries()) {
        const m = line.match(/>(.*)<\/(string|item)>/);
        if (m) out.push({ file, where: i + 1, text: unescape(m[1]) });
      }
    }
  } else if (p === "website") {
    const base = join(dir, "src/i18n");
    const files = [...walk(join(base, lang), (f) => f.endsWith(".ts")), ...(existsSync(join(base, `${lang}.ts`)) ? [join(base, `${lang}.ts`)] : [])];
    for (const file of files) {
      for (const [i, line] of readFileSync(file, "utf8").split("\n").entries()) {
        if (line.trimStart().startsWith("//")) continue;
        for (const m of line.matchAll(/'((?:[^'\\]|\\.)*)'|`((?:[^`\\]|\\.)*)`|"((?:[^"\\]|\\.)*)"/g)) {
          out.push({ file, where: i + 1, text: unescape(m[1] ?? m[2] ?? m[3] ?? "") });
        }
      }
    }
  } else {
    for (const file of walk(join(dir, "internal"), (f) => new RegExp(`/(text|mail|locales)/${lang}\\.json$`).test(f))) {
      for (const [key, value] of Object.entries(JSON.parse(readFileSync(file, "utf8")) as Record<string, string>)) {
        out.push({ file, where: key, text: value });
      }
    }
  }
  return out;
}

/** The words of a string people read: values (${x}, {x}, %1$s, %[1]s) and
 * identifiers such as icon names are not words. */
function visible(text: string): string {
  if (/^[a-z0-9_.:/#-]+$/.test(text)) return "";
  return text.replace(/\$\{[^}]*\}|\{\w+\}|%(\d+\$)?[sd]|%\[\d+\][sd]/g, " ");
}

const escapeRe = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
// A term is a whole word: no letter (Vietnamese ones included) on either side.
const wordOf = (term: string) => new RegExp(`(?<![\\p{L}\\p{N}_])${escapeRe(term)}(?![\\p{L}\\p{N}_])`, "iu");

// ── check ────────────────────────────────────────────────────────────────

const problems: string[] = [];
const products: Product[] = ["app", "website", "server"];

for (const lang of g.languages) {
  const terms = g.sections.flatMap((s) => s.terms).map((t) => words(t, lang)).filter((w): w is Words => !!w);
  // A term to use may hold an avoided one ("tạm khóa tài khoản"), and the ui
  // list names phrases the UI may use ("hàng cấm").
  const allowed = [...terms.flatMap((w) => w.use.map(unparen)), ...(g.ui[lang] ?? []).flatMap((u) => u.phrase)];
  const avoided = terms.flatMap((w) => (w.avoid ?? []).map((a) => ({ term: unparen(a), use: w.use.join(", "), re: wordOf(unparen(a)) })));
  for (const p of products) {
    const all = texts(p, lang);
    if (!all.length) continue;
    for (const { file, where, text: raw } of all) {
      const text = visible(raw);
      const lower = text.toLowerCase();
      for (const { term, use, re } of avoided) {
        if (!re.test(text) || allowed.some((a) => lower.includes(a.toLowerCase()) && re.test(a))) continue;
        problems.push(`${relative(root, file)}:${where}: [${lang}] “${term}” → ${use}: ${raw}`);
      }
    }
    const corpus = all.map((t) => t.text).join("\n");
    for (const ph of g.phrases.filter((ph) => ph.in.includes(p))) {
      if (!ph[lang]) problems.push(`phrase ${ph.id}: ${p} writes ${lang} but the glossary has no ${lang} text`);
      else if (!corpus.includes(ph[lang])) problems.push(`phrase ${ph.id}: ${p} [${lang}] lacks “${ph[lang]}”`);
    }
  }
}

if (readFileSync(manualFile, "utf8") !== render()) {
  problems.push(`${relative(root, manualFile)} differs from the glossary: run bun docs/i18n/glossary.ts render`);
}

for (const p of problems) console.log(p);
console.error(`${problems.length} problems`);
process.exit(problems.length ? 1 : 0);
