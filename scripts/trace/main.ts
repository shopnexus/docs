#!/usr/bin/env bun
// trace: keeps code, tests, OpenAPI and docs in line with docs/registry.
//
//   bun main.ts check  [--server DIR] [--docs DIR]   errors exit 1
//   bun main.ts build  [--server DIR] [--docs DIR]   check, then write registry/trace.json
//   bun main.ts rename OLD NEW                       rename an ID everywhere
//   bun main.ts rename --from-was                    replace every old ID by its current one
//   bun main.ts openapi [--server DIR] [--docs DIR]  bundle server/api into web/public/openapi.json

import { resolve } from "node:path";
import { $ } from "bun";
import { buildTrace, check } from "./check";
import { bundle } from "./openapi";
import { loadRegistry } from "./registry";
import { rename, renameFromWas } from "./rename";
import { type Problem, scanAll } from "./scan";

const args = process.argv.slice(2);
const opt = (name: string, def: string) => {
  const i = args.indexOf(name);
  return i >= 0 ? args.splice(i, 2)[1] : def;
};
const here = import.meta.dir;
const roots = {
  docs: resolve(opt("--docs", `${here}/../..`)),
  server: resolve(opt("--server", `${here}/../../../server`)),
};
const registryPath = `${roots.docs}/registry/requirements.yaml`;
const [cmd, ...rest] = args;

const show = (p: Problem) => `  ${p.file.replace(`${roots.docs}/`, "docs/")}${p.line ? `:${p.line}` : ""}  ${p.msg}`;

async function githubOf(dir: string): Promise<{ repo: string; commit: string }> {
  const url = (await $`git -C ${dir} remote get-url origin`.quiet().nothrow().text()).trim();
  const m = /github\.com[:/](.+?)(?:\.git)?$/.exec(url);
  const commit = (await $`git -C ${dir} rev-parse HEAD`.quiet().nothrow().text()).trim();
  return { repo: m ? `https://github.com/${m[1]}` : "", commit };
}

async function runCheck(write: boolean): Promise<number> {
  const { reg, errors: regErrors } = await loadRegistry(registryPath);
  const { refs, problems } = await scanAll(roots, reg);
  const report = await check(roots, reg, refs, problems);
  const errors = [...regErrors.map((msg) => ({ file: registryPath, line: 0, msg })), ...report.errors];
  if (report.warnings.length) {
    console.log(`warnings (${report.warnings.length}):`);
    for (const w of report.warnings) console.log(show(w));
  }
  if (errors.length) {
    console.log(`errors (${errors.length}):`);
    for (const e of errors) console.log(show(e));
    return 1;
  }
  const ucs = [...reg.items.values()].filter((i) => i.kind === "uc");
  console.log(`ok: ${reg.items.size} ids, ${ucs.length} use cases, ${refs.length} references`);
  if (write) {
    const { repo, commit } = await githubOf(roots.server);
    const trace = buildTrace(reg, refs, repo, commit);
    await Bun.write(`${roots.docs}/registry/trace.json`, `${JSON.stringify(trace, null, 2)}\n`);
    console.log(`wrote registry/trace.json at server ${commit.slice(0, 8)}`);
  }
  return 0;
}

async function runRename(): Promise<number> {
  if (rest[0] === "--from-was") {
    const { reg, errors } = await loadRegistry(registryPath);
    if (errors.length) {
      for (const e of errors) console.log(`  ${e}`);
      return 1;
    }
    const changed = await renameFromWas(roots, reg.was);
    console.log(`replaced old ids in ${changed.length} files`);
    for (const f of changed) console.log(`  ${f}`);
    return 0;
  }
  const [old, next] = rest;
  if (!old || !next) {
    console.log("usage: rename OLD NEW | rename --from-was");
    return 2;
  }
  const changed = await rename(roots, registryPath, old, next);
  console.log(`${old} → ${next} in ${changed.length} files`);
  for (const f of changed) console.log(`  ${f}`);
  return 0;
}

async function runOpenapi(): Promise<number> {
  const doc = await bundle(`${roots.server}/api`);
  const out = `${roots.docs}/web/public/openapi.json`;
  await Bun.write(out, `${JSON.stringify(doc, null, 2)}\n`);
  const paths = Object.keys((doc.paths as object) ?? {}).length;
  const schemas = Object.keys(((doc.components as Record<string, object>)?.schemas as object) ?? {}).length;
  console.log(`wrote web/public/openapi.json: ${paths} paths, ${schemas} schemas`);
  return 0;
}

switch (cmd) {
  case "check":
    process.exit(await runCheck(false));
    break;
  case "build":
    process.exit(await runCheck(true));
    break;
  case "openapi":
    process.exit(await runOpenapi());
    break;
  case "rename":
    process.exit(await runRename());
    break;
  default:
    console.log("usage: main.ts check | build | openapi | rename OLD NEW | rename --from-was");
    process.exit(2);
}
