// The rules `trace check` applies, and the trace.json `trace build` writes.

import { flowsOf, type Item, type Registry } from "./registry";
import { files, type Problem, type Ref, type Roots, SKIP_SERVER } from "./scan";

export interface Report {
  errors: Problem[];
  warnings: Problem[];
}

const METHODS = ["get", "post", "put", "patch", "delete"];

// Error codes the server declares with apperr.New, inside apperr too.
export async function errorCodes(server: string): Promise<Set<string>> {
  const codes = new Set<string>();
  for (const f of await files(server, "internal/**/*.go", SKIP_SERVER)) {
    const text = await Bun.file(`${server}/${f}`).text();
    for (const m of text.matchAll(/(?:apperr\.)?\bNew\(\s*(?:apperr\.)?Kind\w+,\s*"([a-z0-9_]+)"/g)) codes.add(m[1]);
  }
  return codes;
}

// "METHOD /path" → the UCs its x-uc names, with the file that holds it.
export async function apiOperations(server: string): Promise<Map<string, { ucs: string[]; file: string }>> {
  const ops = new Map<string, { ucs: string[]; file: string }>();
  const specPath = `${server}/api/openapi.yaml`;
  if (!(await Bun.file(specPath).exists())) return ops;
  const spec = Bun.YAML.parse(await Bun.file(specPath).text()) as { paths?: Record<string, Record<string, unknown>> };
  const cache = new Map<string, Record<string, unknown>>();
  for (const [path, entry] of Object.entries(spec.paths ?? {})) {
    let item = entry;
    let file = "server/api/openapi.yaml";
    const ref = entry.$ref as string | undefined;
    if (ref) {
      const [rel, pointer] = ref.split("#/");
      if (!cache.has(rel)) cache.set(rel, Bun.YAML.parse(await Bun.file(`${server}/api/${rel}`).text()) as Record<string, unknown>);
      item = (cache.get(rel)?.[pointer] ?? {}) as Record<string, unknown>;
      file = `server/api/${rel}`;
    }
    for (const m of METHODS) {
      const op = item[m] as Record<string, unknown> | undefined;
      if (op) ops.set(`${m.toUpperCase()} ${path}`, { ucs: (op["x-uc"] as string[] | undefined) ?? [], file });
    }
  }
  return ops;
}

export async function check(roots: Roots, reg: Registry, refs: Ref[], scanProblems: Problem[]): Promise<Report> {
  const errors: Problem[] = [...scanProblems];
  const warnings: Problem[] = [];
  const at = (file: string, line: number, msg: string) => ({ file, line, msg });

  // References: unknown, old, retired, missing flows.
  for (const r of refs) {
    const current = reg.was.get(r.id);
    if (current) {
      errors.push(at(r.file, r.line, `${r.id} is an old id; it is ${current} now (make trace-rename FROM_WAS=1)`));
      continue;
    }
    const it = reg.items.get(r.id);
    if (!it) {
      errors.push(at(r.file, r.line, `${r.id} is not in the registry`));
      continue;
    }
    // The Typst reports follow the site and lag behind it, so a retired id there only warns.
    const stale = r.file.startsWith("docs/typst/") ? warnings : errors;
    if (it.status === "retired" || it.status === "superseded") {
      stale.push(at(r.file, r.line, `${r.id} is ${it.status}`));
    }
    const flows = flowsOf(it);
    for (const f of r.flows) {
      if (!flows.has(f)) errors.push(at(r.file, r.line, `${r.id} has no flow ${f}`));
      else if (flows.get(f)?.status === "retired") stale.push(at(r.file, r.line, `${r.id} ${f} is retired`));
    }
  }

  // Error codes the flows end on must exist in the server.
  const codes = await errorCodes(roots.server);
  for (const it of reg.items.values()) {
    for (const [fid, f] of flowsOf(it)) {
      if (f.error && !codes.has(f.error)) {
        errors.push(at(reg.path, 0, `${it.id} ${fid}: error ${f.error} is not declared in the server (apperr.New)`));
      }
    }
  }

  // OpenAPI x-uc and the UCs' api lists must agree.
  const ops = await apiOperations(roots.server);
  for (const [op, { ucs, file }] of ops) {
    for (const uc of ucs) {
      const it = reg.items.get(uc);
      if (it && !(it.api ?? []).includes(op)) errors.push(at(file, 0, `${op} has x-uc ${uc}, but ${uc} does not list it under api`));
    }
  }
  for (const it of reg.items.values()) {
    for (const op of it.api ?? []) {
      const found = ops.get(op);
      if (!found) errors.push(at(reg.path, 0, `${it.id} lists ${op}, which is not in openapi.yaml`));
      else if (!found.ucs.includes(it.id)) errors.push(at(found.file, 0, `${op} lacks x-uc ${it.id}`));
    }
  }

  // Coverage of what the registry says is done.
  const byId = group(refs);
  for (const it of reg.items.values()) {
    if (it.kind !== "uc") continue;
    const mine = byId.get(it.id) ?? [];
    const code = mine.filter((r) => r.kind === "code");
    const tests = mine.filter((r) => r.kind === "test");
    if (it.status === "done") {
      if (code.length === 0) warnings.push(at(reg.path, 0, `${it.id} is done but no code names it`));
      if (tests.length === 0) warnings.push(at(reg.path, 0, `${it.id} is done but no test names it`));
      const tested = new Set(tests.flatMap((r) => r.flows));
      for (const [fid, f] of Object.entries(it.exc ?? {})) {
        if ((f as { status?: string })?.status === "retired") continue;
        if (!tested.has(fid)) warnings.push(at(reg.path, 0, `${it.id} ${fid} has no test`));
      }
    } else if ((it.status === "planned" || it.status === "untraced") && code.length > 0) {
      warnings.push(at(code[0].file, code[0].line, `${it.id} is ${it.status} but code names it`));
    }
    for (const g of it.gaps ?? []) warnings.push(at(reg.path, 0, `${it.id} gap: ${g}`));
  }

  // Rules, NFRs and ADRs nothing names.
  const named = new Set(refs.map((r) => r.id));
  for (const it of reg.items.values()) {
    for (const k of ["br", "nfr", "adr"] as const) for (const id of (it[k] as string[] | undefined) ?? []) named.add(id);
    for (const f of flowsOf(it).values()) {
      if (f.br) named.add(f.br);
      if (f.nfr) named.add(f.nfr);
    }
  }
  for (const it of reg.items.values()) {
    if (["br", "nfr", "adr"].includes(it.kind) && it.status !== "retired" && !named.has(it.id)) warnings.push(at(reg.path, 0, `${it.id} is named nowhere`));
  }

  return { errors: dedupe(errors), warnings: dedupe(warnings) };
}

function group(refs: Ref[]): Map<string, Ref[]> {
  const m = new Map<string, Ref[]>();
  for (const r of refs) m.set(r.id, [...(m.get(r.id) ?? []), r]);
  return m;
}

function dedupe(ps: Problem[]): Problem[] {
  const seen = new Set<string>();
  return ps.filter((p) => {
    const k = `${p.file}:${p.line}:${p.msg}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}

export interface Trace {
  server: { repo: string; commit: string };
  // ID → where server code, tests and the API name it.
  refs: Record<string, { file: string; line: number; kind: string; flows: string[] }[]>;
  // UC → flow → whether a test names it.
  coverage: Record<string, { code: number; tests: number; flows: Record<string, boolean> }>;
}

export function buildTrace(reg: Registry, refs: Ref[], repo: string, commit: string): Trace {
  const keep = refs.filter((r) => r.kind === "code" || r.kind === "test" || r.kind === "api");
  const out: Trace = { server: { repo, commit }, refs: {}, coverage: {} };
  for (const r of keep) {
    const id = reg.was.get(r.id) ?? r.id;
    (out.refs[id] ??= []).push({ file: r.file, line: r.line, kind: r.kind, flows: r.flows });
  }
  for (const it of reg.items.values() as IterableIterator<Item>) {
    if (it.kind !== "uc") continue;
    const mine = out.refs[it.id] ?? [];
    const tested = new Set(mine.filter((r) => r.kind === "test").flatMap((r) => r.flows));
    const flows: Record<string, boolean> = {};
    for (const fid of flowsOf(it).keys()) flows[fid] = tested.has(fid);
    out.coverage[it.id] = {
      code: mine.filter((r) => r.kind === "code").length,
      tests: mine.filter((r) => r.kind === "test").length,
      flows,
    };
  }
  return out;
}
