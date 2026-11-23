#!/usr/bin/env bun
// check-terms: checks the products' Vietnamese text against
// docs/manual/thuat-ngu.md.
//
//   bun docs/i18n/check-terms.ts [root]   hits exit 1
//
// Reads every "Không dùng" cell of the glossary, the terms to use, and the
// "Giao diện" section's phrases, then scans the text people see: the app's
// strings.xml, the website's src/i18n/vi/*.ts and the server's catalogs.
// TERMS_APP, TERMS_WEBSITE and TERMS_SERVER point at another checkout of a
// repo, such as a worktree, relative to root.

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";

const root = resolve(process.argv[2] ?? join(import.meta.dir, "../.."));
const glossaryFile = join(root, "docs/manual/thuat-ngu.md");
const app = join(root, process.env.TERMS_APP ?? "app");
const website = join(root, process.env.TERMS_WEBSITE ?? "website");
const server = join(root, process.env.TERMS_SERVER ?? "server");

type Glossary = { banned: Map<string, string>; allowed: string[] };

const unparen = (s: string) => s.replace(/\s*\(.*?\)/g, "").trim();
const list = (cell: string) => cell.split(",").map(unparen).filter(Boolean);

/** The banned terms, each with the term to use, and the phrases that may hold one. */
function glossary(): Glossary {
  const banned = new Map<string, string>();
  const allowed: string[] = [];
  let section = "";
  for (const line of readFileSync(glossaryFile, "utf8").split("\n")) {
    if (line.startsWith("## ")) {
      section = line.slice(3).trim();
      continue;
    }
    if (!line.startsWith("|")) continue;
    const cells = line.trim().replace(/^\||\|$/g, "").split("|").map((c) => c.trim());
    if (cells.length < 3 || ["Dùng", "Dùng trên giao diện", ""].includes(cells[0]) || /^-+$/.test(cells[0])) continue;
    // A term to use may hold a banned one ("tạm khóa tài khoản"), and the
    // Giao diện section lists phrases the UI may use ("hàng cấm").
    allowed.push(...list(cells[0]));
    if (section === "Giao diện") continue;
    for (const term of list(cells[2])) banned.set(term, cells[0]);
  }
  return { banned, allowed };
}

type Text = { file: string; where: string | number; text: string };

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

/** Every string people see, with where it is. */
function* texts(): Generator<Text> {
  for (const file of walk(app, (p) => p.endsWith("/src/main/res/values/strings.xml"))) {
    const lines = readFileSync(file, "utf8").split("\n");
    for (const [i, line] of lines.entries()) {
      const m = line.match(/>(.*)<\/(string|item)>/);
      if (m) yield { file, where: i + 1, text: m[1] };
    }
  }
  for (const file of walk(join(website, "src/i18n/vi"), (p) => p.endsWith(".ts"))) {
    const lines = readFileSync(file, "utf8").split("\n");
    for (const [i, line] of lines.entries()) {
      if (line.trimStart().startsWith("//")) continue;
      for (const m of line.matchAll(/'((?:[^'\\]|\\.)*)'|`((?:[^`\\]|\\.)*)`|"((?:[^"\\]|\\.)*)"/g)) {
        yield { file, where: i + 1, text: m[1] ?? m[2] ?? m[3] ?? "" };
      }
    }
  }
  for (const file of walk(join(server, "internal"), (p) => /\/(text|mail|locales)\/vi\.json$/.test(p))) {
    for (const [key, value] of Object.entries(JSON.parse(readFileSync(file, "utf8")) as Record<string, string>)) {
      yield { file, where: key, text: value };
    }
  }
}

/** The words of a string people read: values (${x}, {x}, %1$s, %[1]s) and
 * identifiers such as icon names are not words. */
function visible(text: string): string {
  if (/^[a-z0-9_.:/#-]+$/.test(text)) return "";
  return text.replace(/\$\{[^}]*\}|\{\w+\}|%(\d+\$)?[sd]|%\[\d+\][sd]/g, " ");
}

const escape = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
// A term is a whole word: no letter (Vietnamese ones included) on either side.
const wordOf = (term: string) => new RegExp(`(?<![\\p{L}\\p{N}_])${escape(term)}(?![\\p{L}\\p{N}_])`, "iu");

const { banned, allowed } = glossary();
const patterns = [...banned.keys()].map((term) => ({ term, use: banned.get(term) ?? "", re: wordOf(term) }));
let hits = 0;
for (const { file, where, text: raw } of texts()) {
  const text = visible(raw);
  const lower = text.toLowerCase();
  for (const { term, use, re } of patterns) {
    if (!re.test(text)) continue;
    // Allowed when the hit sits in a phrase the glossary allows.
    if (allowed.some((a) => lower.includes(a.toLowerCase()) && re.test(a))) continue;
    hits++;
    console.log(`${relative(root, file)}:${where}: “${term}” → ${use}: ${raw}`);
  }
}
console.error(`${hits} hits`);
process.exit(hits ? 1 : 0);
