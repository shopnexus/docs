// Changes an ID everywhere: the registry keeps the old one under `was`.

import { files, type Roots, SKIP_SERVER, SKIP_TYPST } from "./scan";

const KINDS: Record<string, RegExp> = {
  UC: /^UC-[A-Z]+-\d{2}$/,
  FR: /^FR-[A-Z]+-\d{2}$/,
  BR: /^BR-[A-Z]+-\d{2}$/,
  NFR: /^NFR-[A-Z]+-\d{2}$/,
  ADR: /^ADR-\d{4}$/,
};

const escape = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// Files that may name IDs, outside the registry.
async function targets(roots: Roots): Promise<string[]> {
  return [
    ...(await files(roots.server, "**/*.go", SKIP_SERVER)).map((f) => `${roots.server}/${f}`),
    ...(await files(roots.server, "api/**/*.yaml", SKIP_SERVER)).map((f) => `${roots.server}/${f}`),
    ...(await files(roots.docs, "typst/**/*.typ", SKIP_TYPST)).map((f) => `${roots.docs}/${f}`),
    ...(await files(roots.docs, "web/src/content/**/*.mdx", SKIP_SERVER)).map((f) => `${roots.docs}/${f}`),
  ];
}

// Rewrites every file in which map changes something; returns the files changed.
export async function replaceIn(paths: string[], map: Map<string, string>): Promise<string[]> {
  if (map.size === 0) return [];
  const keys = [...map.keys()].sort((a, b) => b.length - a.length);
  const re = new RegExp(`\\b(?:${keys.map(escape).join("|")})\\b`, "g");
  const changed: string[] = [];
  for (const p of paths) {
    const text = await Bun.file(p).text();
    const next = text.replace(re, (m) => map.get(m) ?? m);
    if (next !== text) {
      await Bun.write(p, next);
      changed.push(p);
    }
  }
  return changed;
}

// The registry text with old renamed to next, except inside `was` lists, and
// old added to next's `was`.
export function renameInRegistry(text: string, old: string, next: string): string {
  const re = new RegExp(`\\b${escape(old)}\\b`, "g");
  const lines = text.split("\n").map((line) => {
    // Leave `was: [...]` alone; rename the rest of the line.
    const parts = line.split(/(was: \[[^\]]*\])/);
    return parts.map((p) => (p.startsWith("was: [") ? p : p.replace(re, next))).join("");
  });
  const i = lines.findIndex((l) => new RegExp(`\\bid: ${escape(next)}\\b`).test(l));
  if (i < 0) throw new Error(`no line holds id: ${next}`);
  const line = lines[i];
  if (/was: \[/.test(line)) {
    lines[i] = line.replace(/was: \[/, `was: [${old}, `);
  } else if (/^\s*-?\s*\{/.test(line)) {
    lines[i] = line.replace(`id: ${next}`, `id: ${next}, was: [${old}]`);
  } else if (/^\s*was: \[/.test(lines[i + 1] ?? "")) {
    lines[i + 1] = lines[i + 1].replace(/was: \[/, `was: [${old}, `);
  } else {
    const indent = (/^(\s*)(?:-\s*)?/.exec(line)?.[0] ?? "").replace("-", " ");
    lines.splice(i + 1, 0, `${indent}was: [${old}]`);
  }
  return lines.join("\n");
}

export async function rename(roots: Roots, registryPath: string, old: string, next: string): Promise<string[]> {
  const kind = old.split("-")[0];
  if (!KINDS[kind]?.test(next)) throw new Error(`${next} is not a ${kind} id`);
  if (next.split("-")[0] !== kind) throw new Error(`${old} and ${next} are different kinds`);
  const text = await Bun.file(registryPath).text();
  if (!new RegExp(`\\bid: ${escape(old)}\\b`).test(text)) throw new Error(`${old} is not in the registry`);
  if (new RegExp(`\\bid: ${escape(next)}\\b`).test(text)) throw new Error(`${next} exists already`);
  await Bun.write(registryPath, renameInRegistry(text, old, next));
  return [registryPath, ...(await replaceIn(await targets(roots), new Map([[old, next]])))];
}

// Replaces every old ID the registry lists under `was` by the current one.
export async function renameFromWas(roots: Roots, was: Map<string, string>): Promise<string[]> {
  return replaceIn(await targets(roots), was);
}
