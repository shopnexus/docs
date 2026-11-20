// Finds the requirement IDs that code, tests, OpenAPI and docs name.

import { relative } from "node:path";
import { ANY_ID, expandFlows, type Registry } from "./registry";

export type RefKind = "code" | "test" | "api" | "doc" | "registry";

export interface Ref {
  id: string;
  file: string; // relative to the scan root it came from, prefixed by that root's name
  line: number;
  kind: RefKind;
  flows: string[];
  steps: number[];
}

export interface Problem {
  file: string;
  line: number;
  msg: string;
}

export interface Roots {
  server: string;
  docs: string;
}

const FLOW_AFTER = /^((?:\s*[,·]?\s*[AE]\d+(?:[–-][AE]?\d+)?)+)/;
// A comment line that marks a flow or a step of the function's UC.
const FLOW_MARK = /^\s*\/\/\s*([AE]\d+(?:[–-][AE]?\d+)?)\b/;
const STEP_MARK = /^\s*\/\/\s*(\d+)\.\s/;
const FLOW_TOKEN = /(?<![\w-])([AE]\d+(?:[–-][AE]?\d+)?)\b/g;
const SUBTEST = /t\.Run\(\s*"([AE]\d+(?:[–-][AE]?\d+)?)\b/;

export async function files(root: string, pattern: string, skip: RegExp): Promise<string[]> {
  const out: string[] = [];
  for await (const f of new Bun.Glob(pattern).scan({ cwd: root, onlyFiles: true })) {
    if (!skip.test(f)) out.push(f);
  }
  return out.sort();
}

function flowsAfter(rest: string): string[] {
  const m = FLOW_AFTER.exec(rest);
  if (!m) return [];
  return m[1]
    .split(/[\s,·]+/)
    .filter(Boolean)
    .flatMap(expandFlows);
}

// IDs on one line, each with the flows written right after it.
function idsOn(text: string): { id: string; flows: string[] }[] {
  const out: { id: string; flows: string[] }[] = [];
  for (const m of text.matchAll(ANY_ID)) {
    out.push({ id: m[0], flows: flowsAfter(text.slice((m.index ?? 0) + m[0].length)) });
  }
  return out;
}

// Go files. A function's UCs are the UC IDs in the comment block right above
// `func`; a bare flow mark (`// E2`), step mark (`// 1.`) or subtest named
// after a flow inside that function belongs to those UCs.
export function scanGo(name: string, text: string, isTest: boolean, reg: Registry, problems: Problem[]): Ref[] {
  const refs: Ref[] = [];
  const kind: RefKind = isTest ? "test" : "code";
  let doc: string[] = [];
  let ctx: string[] = [];
  let ctxLine = 0;
  const lines = text.split("\n");
  lines.forEach((line, i) => {
    const n = i + 1;
    const comment = /^\s*\/\//.test(line);
    for (const { id, flows } of idsOn(line)) {
      refs.push({ id, file: name, line: n, kind, flows, steps: [] });
      if (comment && id.startsWith("UC-")) doc.push(reg.was.get(id) ?? id);
    }
    if (/^func /.test(line)) {
      ctx = doc;
      ctxLine = n;
    }
    if (!comment) doc = [];
    if (/^}/.test(line)) ctx = [];

    const mark = FLOW_MARK.exec(line) ?? SUBTEST.exec(line);
    const step = STEP_MARK.exec(line);
    if (!mark && !step) return;
    if (ctx.length === 0) {
      problems.push({ file: name, line: n, msg: "flow or step mark outside a function tagged with a UC" });
      return;
    }
    // Every flow the mark line names: "// E1 …, E2 …" or "// 2. …; E5 …".
    const flows = comment
      ? [...line.matchAll(FLOW_TOKEN)].flatMap((m) => expandFlows(m[1]))
      : mark
        ? expandFlows(mark[1])
        : [];
    const steps = step ? [Number(step[1])] : [];
    // The mark belongs to the first of the function's UCs that has it.
    const owner = ctx.find((uc) => {
      const it = reg.items.get(uc);
      if (!it) return false;
      if (flows.length) return flows.every((f) => it.alt?.[f] || it.exc?.[f]);
      return steps.every((s) => it.main?.[String(s)]);
    });
    if (!owner) {
      const what = mark ? mark[1] : `step ${steps[0]}`;
      problems.push({ file: name, line: n, msg: `${what} is not in ${ctx.join(", ")} (function at line ${ctxLine})` });
      return;
    }
    refs.push({ id: owner, file: name, line: n, kind, flows, steps });
  });
  return refs;
}

// Any other text: IDs and the flows after them, no function context.
export function scanText(name: string, text: string, kind: RefKind): Ref[] {
  const refs: Ref[] = [];
  text.split("\n").forEach((line, i) => {
    for (const { id, flows } of idsOn(line)) refs.push({ id, file: name, line: i + 1, kind, flows, steps: [] });
  });
  return refs;
}

// The registry's own prose (steps, flows, rules, notes) names IDs too. The
// id, was and list fields are checked by loadRegistry.
export function scanRegistry(reg: Registry): Ref[] {
  const refs: Ref[] = [];
  const name = `docs/${relative(`${reg.path}/../..`, reg.path)}`;
  const walk = (v: unknown, key: string) => {
    if (["id", "was", "uc", "fr", "br", "nfr", "adr", "api", "ucText"].includes(key)) return;
    if (typeof v === "string") refs.push(...scanText(name, v, "registry").map((r) => ({ ...r, line: 0 })));
    else if (Array.isArray(v)) v.forEach((x) => walk(x, ""));
    else if (v && typeof v === "object") for (const [k, x] of Object.entries(v)) walk(x, k);
  };
  walk(reg.raw, "");
  return refs;
}

export const SKIP_SERVER = /(^|\/)(tmp|vendor|node_modules|\.git)\//;
// Submitted reports (weekly, periodic 1) keep the IDs they were handed in with.
export const SKIP_TYPST = /(^|\/)(tmp|out|bao-cao-tuan|dinh-ky-1)\//;

export interface Scan {
  refs: Ref[];
  problems: Problem[];
}

export async function scanAll(roots: Roots, reg: Registry): Promise<Scan> {
  const refs: Ref[] = [];
  const problems: Problem[] = [];
  for (const f of await files(roots.server, "**/*.go", SKIP_SERVER)) {
    const text = await Bun.file(`${roots.server}/${f}`).text();
    refs.push(...scanGo(`server/${f}`, text, f.endsWith("_test.go"), reg, problems));
  }
  for (const f of await files(roots.server, "api/**/*.yaml", SKIP_SERVER)) {
    refs.push(...scanText(`server/${f}`, await Bun.file(`${roots.server}/${f}`).text(), "api"));
  }
  for (const f of await files(roots.docs, "typst/**/*.typ", SKIP_TYPST)) {
    refs.push(...scanText(`docs/${f}`, await Bun.file(`${roots.docs}/${f}`).text(), "doc"));
  }
  for (const f of await files(roots.docs, "web/src/content/**/*.mdx", SKIP_SERVER)) {
    refs.push(...scanText(`docs/${f}`, await Bun.file(`${roots.docs}/${f}`).text(), "doc"));
  }
  refs.push(...scanRegistry(reg));
  return { refs, problems };
}
