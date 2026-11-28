// Values the registry's prose quotes from the server, so a limit is written
// once, in code, and the docs never fall behind it.
//
// A placeholder names a Go expression in a module, or a shared env setting:
//
//   {catalog.MaxOnSale}               a constant of internal/catalog
//   {deal.OrderWaits.Seller}          a field of a variable
//   {provider/firebase.freshFor}      a directory under internal/, when the name is in two of its packages
//   {env.BOOST_PACKAGES|packages}     a key of infra/stack/env/server.env
//
// The part after | says how to read the value: MB (bytes), % (a ratio),
// M (millions), s or days (a count of them), packages (BOOST_PACKAGES).
// Without it, a time.Duration reads as a duration and a number as a number.
// Unexported names work: each package gets a test file through
// `go test -overlay`, which reads them and writes nothing into the tree.

import { mkdtemp, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, relative, resolve } from "node:path";
import { $ } from "bun";

import { PLACEHOLDER, type Text } from "./placeholder";

export { fill, PLACEHOLDER, type Text } from "./placeholder";

interface Raw {
  type: string;
  value: unknown;
}

/** Every placeholder the registry's strings hold, by its text between the braces. */
export function placeholders(raw: unknown): Map<string, { dir: string; expr: string; hint?: string }> {
  const out = new Map<string, { dir: string; expr: string; hint?: string }>();
  const walk = (v: unknown) => {
    if (typeof v === "string") for (const m of v.matchAll(PLACEHOLDER)) out.set(m[0].slice(1, -1), { dir: m[1], expr: m[2], hint: m[3] });
    else if (Array.isArray(v)) v.forEach(walk);
    else if (v && typeof v === "object") Object.values(v).forEach(walk);
  };
  walk(raw);
  return out;
}

async function goFiles(dir: string): Promise<string[]> {
  const out: string[] = [];
  for (const e of await readdir(dir, { withFileTypes: true }).catch(() => [])) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...(await goFiles(p)));
    else if (e.name.endsWith(".go") && !e.name.endsWith("_test.go")) out.push(p);
  }
  return out;
}

/** The directories under root whose package declares name at the top level. */
async function declaring(root: string, name: string): Promise<Set<string>> {
  const found = new Set<string>();
  const top = new RegExp(`^(?:const|var|func)\\s+${name}\\b`);
  const inBlock = new RegExp(`^\\s+${name}\\b\\s*(?:[,=]|[\\w.*\\[\\]]+\\s*=)`);
  for (const f of await goFiles(root)) {
    let block = false;
    for (const line of (await Bun.file(f).text()).split("\n")) {
      if (/^(?:const|var)\s*\($/.test(line)) block = true;
      else if (block && line.startsWith(")")) block = false;
      else if (top.test(line) || (block && inBlock.test(line))) found.add(f.slice(0, f.lastIndexOf("/")));
    }
  }
  return found;
}

/** Reads the values the placeholders name: from the server through go test, from server.env for env. */
export async function readValues(
  given: { server: string; infra: string },
  wanted: Map<string, { dir: string; expr: string; hint?: string }>,
): Promise<{ raw: Map<string, Raw>; errors: string[] }> {
  // go reads an overlay's paths as absolute.
  const roots = { server: resolve(given.server), infra: resolve(given.infra) };
  const raw = new Map<string, Raw>();
  const errors: string[] = [];
  const byPkg = new Map<string, string[]>();
  const env = await envOf(`${roots.infra}/stack/env/server.env`);
  for (const [key, { dir, expr }] of wanted) {
    if (dir === "env") {
      if (env.has(expr)) raw.set(key, { type: "env", value: env.get(expr) });
      else errors.push(`{${key}}: ${expr} is not in infra/stack/env/server.env`);
      continue;
    }
    const name = /^[A-Za-z_]\w*/.exec(expr)?.[0] ?? "";
    const pkgs = [...(await declaring(`${roots.server}/internal/${dir}`, name))];
    if (pkgs.length !== 1) {
      const where = pkgs.map((p) => relative(`${roots.server}/internal`, p)).join(", ");
      errors.push(`{${key}}: ${name} is ${pkgs.length ? `in more than one package (${where}); name the directory` : `not declared under server/internal/${dir}`}`);
      continue;
    }
    byPkg.set(pkgs[0], [...(byPkg.get(pkgs[0]) ?? []), key]);
  }
  if (byPkg.size === 0) return { raw, errors };

  const tmp = await mkdtemp(join(tmpdir(), "trace-values-"));
  try {
    const replace: Record<string, string> = {};
    let i = 0;
    for (const [pkg, keys] of byPkg) {
      const first = (await goFiles(pkg)).find((f) => f.slice(0, f.lastIndexOf("/")) === pkg) ?? "";
      const pkgName = /^package\s+(\w+)/m.exec(await Bun.file(first).text())?.[1];
      const entries = keys.map((k) => `\t\t${JSON.stringify(k)}: ${wanted.get(k)?.expr},`).join("\n");
      const src = `package ${pkgName}\n\nimport (\n\t"encoding/json"\n\t"fmt"\n\t"testing"\n)\n\nfunc TestTraceValues(t *testing.T) {\n\tfor k, v := range map[string]any{\n${entries}\n\t} {\n\t\tb, err := json.Marshal(v)\n\t\tif err != nil {\n\t\t\tt.Fatal(err)\n\t\t}\n\t\tfmt.Printf("TRACEVALUE %s %T %s\\n", k, v, b)\n\t}\n}\n`;
      const file = join(tmp, `${i++}.go`);
      await Bun.write(file, src);
      replace[join(pkg, "zz_trace_values_test.go")] = file;
    }
    const overlay = join(tmp, "overlay.json");
    await Bun.write(overlay, JSON.stringify({ Replace: replace }));
    const pkgs = [...byPkg.keys()].map((p) => `./${relative(roots.server, p)}`);
    const out = await $`go test -overlay ${overlay} -count=1 -run ${"^TestTraceValues$"} -v ${pkgs}`.cwd(roots.server).quiet().nothrow();
    for (const line of out.stdout.toString().split("\n")) {
      const m = /^TRACEVALUE (\S+) (\S+) (.*)$/.exec(line);
      if (m) raw.set(m[1], { type: m[2], value: JSON.parse(m[3]) });
    }
    if (out.exitCode !== 0) {
      const why = `${out.stdout}${out.stderr}`.split("\n").filter((l) => /\.go:\d+|cannot|undefined|FAIL/.test(l)).slice(0, 5);
      errors.push(`go test reading the registry's values failed:\n    ${why.join("\n    ")}`);
    } else {
      for (const keys of byPkg.values()) for (const key of keys) if (!raw.has(key)) errors.push(`{${key}}: no value came back`);
    }
  } finally {
    await rm(tmp, { recursive: true, force: true });
  }
  return { raw, errors };
}

async function envOf(path: string): Promise<Map<string, string>> {
  const m = new Map<string, string>();
  const file = Bun.file(path);
  if (!(await file.exists())) return m;
  for (const line of (await file.text()).split("\n")) {
    const kv = /^([A-Z][A-Z0-9_]*)=(.*)$/.exec(line.trim());
    if (kv) m.set(kv[1], kv[2]);
  }
  return m;
}

const number = (n: number, lang: keyof Text) => n.toLocaleString(lang === "vi" ? "vi-VN" : "en-US", { maximumFractionDigits: 2 });

// A unit, the least count it is used from, and its names. 24 hours reads
// as 24 giờ and 60 seconds as 60 giây, as people write them; 3 days as 3 ngày.
const UNITS: [number, number, string, string][] = [
  [86400, 2, "ngày", "day"],
  [3600, 1, "giờ", "hour"],
  [60, 2, "phút", "minute"],
  [1, 1, "giây", "second"],
];

/** A duration in seconds, in the largest unit it is a whole number of. */
export function duration(seconds: number): Text {
  const [size, , vi, en] = UNITS.find(([u, least]) => seconds % u === 0 && seconds >= u * least) ?? UNITS[3];
  const n = seconds / size;
  return { vi: `${number(n, "vi")} ${vi}`, en: `${number(n, "en")} ${en}${n === 1 ? "" : "s"}` };
}

const both = (f: (lang: keyof Text) => string): Text => ({ vi: f("vi"), en: f("en") });

/** How a value reads in the docs. */
export function format(v: Raw, hint?: string): Text | string {
  const x = v.value;
  const seconds = (s: string) => {
    const m = /^(\d+)(h|m|s)$/.exec(s);
    return m ? Number(m[1]) * { h: 3600, m: 60, s: 1 }[m[2] as "h" | "m" | "s"] : Number.NaN;
  };
  if (hint === "packages") {
    if (typeof x !== "string") return "packages wants an env value such as 3:15000,7:29000";
    const ps = x.split(",").map((p) => p.split(":").map(Number));
    if (ps.some((p) => p.length !== 2 || p.some(Number.isNaN))) return `${x} is not days:price pairs`;
    return both((lang) =>
      ps
        .map(([days, price]) => (lang === "vi" ? `${duration(days * 86400).vi} giá ${number(price, "vi")} đ` : `${duration(days * 86400).en} for ${number(price, "en")} đ`))
        .join(lang === "vi" ? " và " : " and "),
    );
  }
  if (v.type === "time.Duration") return duration(Number(x) / 1e9);
  // An env setting is text: a Go duration such as 2h, a number, or anything else as written.
  if (typeof x === "string" && v.type === "env" && !hint && /^\d+[hms]$/.test(x)) return duration(seconds(x));
  const n = Number(x);
  if (typeof x === "string" && (v.type !== "env" || Number.isNaN(n))) return hint ? `${x} is not a number for |${hint}` : { vi: x, en: x };
  switch (hint) {
    case undefined:
      return both((lang) => number(n, lang));
    case "MB":
      return both((lang) => `${number(n / 2 ** 20, lang)} MB`);
    case "%":
      return both((lang) => `${number(n * 100, lang)}%`);
    case "M":
      return both((lang) => number(n / 1e6, lang));
    case "s":
      return duration(n);
    case "days":
      return duration(n * 86400);
    default:
      return `unknown |${hint}`;
  }
}

/** The registry's values, formatted, or why one cannot be. */
export async function values(
  roots: { server: string; infra: string },
  raw: unknown,
): Promise<{ values: Record<string, Text>; errors: string[] }> {
  const wanted = placeholders(raw);
  const { raw: read, errors } = await readValues(roots, wanted);
  const out: Record<string, Text> = {};
  for (const [key, { hint }] of wanted) {
    const v = read.get(key);
    if (!v) continue;
    const f = format(v, hint);
    if (typeof f === "string") errors.push(`{${key}}: ${f}`);
    else out[key] = f;
  }
  return { values: Object.fromEntries(Object.entries(out).sort(([a], [b]) => a.localeCompare(b))), errors };
}
