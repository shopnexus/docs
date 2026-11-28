// Loads docs/registry/requirements.yaml and indexes its IDs.

export type Kind = "uc" | "fr" | "br" | "nfr" | "adr";
export type Status = "untraced" | "planned" | "doing" | "done" | "retired" | "accepted" | "superseded";

export interface Flow {
  at?: number;
  text: string;
  br?: string;
  nfr?: string;
  error?: string;
  status?: Status;
}

export interface Item {
  id: string;
  kind: Kind;
  was?: string[];
  status?: Status;
  // A UC's lists; an FR lists its UCs in `uc`.
  uc?: string[];
  fr?: string[];
  br?: string[];
  nfr?: string[];
  adr?: string[];
  main?: Record<string, string>;
  alt?: Record<string, Flow>;
  exc?: Record<string, Flow>;
  gaps?: string[];
  [key: string]: unknown;
}

export interface Registry {
  path: string;
  raw: Record<string, unknown>;
  items: Map<string, Item>;
  // Old ID → current ID.
  was: Map<string, string>;
  groups: Set<string>;
}

// A current ID. Flows follow a UC as a separate token: "UC-DEAL-02 E3".
export const ID = /\b(?:(?:UC|FR|BR)-[A-Z]+-\d{2}|NFR-[A-Z]+-\d{2}|ADR-\d{4})\b/g;
// Anything shaped like a requirement ID, old formats included, so a typo or
// an ID from before the registry is caught too.
export const ANY_ID = /\b(?:(?:UC|FR|BR|NFR)-[A-Z]+-\d+|ADR-\d+|(?:UC|FR|BR|NFR|REQ)-S?\d+)\b/g;
export const FLOW = /^[AE]\d+$/;

const SECTIONS: Kind[] = ["uc", "fr", "br", "nfr", "adr"];
const PREFIX: Record<Kind, RegExp> = {
  uc: /^UC-([A-Z]+)-\d{2}$/,
  fr: /^FR-([A-Z]+)-\d{2}$/,
  br: /^BR-([A-Z]+)-\d{2}$/,
  nfr: /^NFR-[A-Z]+-\d{2}$/,
  adr: /^ADR-\d{4}$/,
};
const STATUSES: Record<Kind, Status[]> = {
  uc: ["untraced", "planned", "doing", "done", "retired"],
  fr: ["untraced", "planned", "doing", "done", "retired"],
  br: ["untraced", "planned", "doing", "done", "retired"],
  nfr: ["untraced", "planned", "doing", "done", "retired"],
  adr: ["accepted", "superseded", "retired"],
};

export async function loadRegistry(path: string): Promise<{ reg: Registry; errors: string[] }> {
  const raw = Bun.YAML.parse(await Bun.file(path).text()) as Record<string, unknown>;
  const errors: string[] = [];
  const items = new Map<string, Item>();
  const was = new Map<string, string>();
  const groups = new Set(Object.keys((raw.groups as object) ?? {}));

  for (const kind of SECTIONS) {
    for (const entry of (raw[kind] as Item[] | undefined) ?? []) {
      const item = { ...entry, kind } as Item;
      const where = `${path}: ${item.id ?? "(no id)"}`;
      if (typeof item.id !== "string" || !PREFIX[kind].test(item.id)) {
        errors.push(`${where}: bad ${kind} id`);
        continue;
      }
      const group = PREFIX[kind].exec(item.id)?.[1];
      if (group && !groups.has(group)) errors.push(`${where}: group ${group} is not in groups`);
      if (items.has(item.id)) errors.push(`${where}: duplicate id`);
      if (item.status && !STATUSES[kind].includes(item.status)) errors.push(`${where}: bad status ${item.status}`);
      errors.push(...shape(where, item));
      items.set(item.id, item);
      for (const old of item.was ?? []) {
        if (was.has(old)) errors.push(`${where}: old id ${old} is also on ${was.get(old)}`);
        was.set(old, item.id);
      }
    }
  }
  for (const old of was.keys()) {
    if (items.has(old)) errors.push(`${path}: ${old} is both a current and an old id`);
  }

  const reg: Registry = { path, raw, items, was, groups };
  errors.push(...crossRefs(reg));
  return { reg, errors };
}

const FLOW_KEYS = new Set(["at", "text", "br", "nfr", "error", "status"]);

// An unquoted comma inside `{ vi: … }` splits the text into extra keys, so
// text maps may hold only vi and en strings, and flows only known keys.
function shape(where: string, it: Item): string[] {
  const errors: string[] = [];
  for (const k of ["title", "short", "text"]) {
    const v = it[k];
    if (v === undefined) continue;
    if (!v || typeof v !== "object") {
      errors.push(`${where}: ${k} must be { vi: …, en: … }`);
      continue;
    }
    for (const [lang, s] of Object.entries(v)) {
      if (!["vi", "en"].includes(lang) || typeof s !== "string") {
        errors.push(`${where}: ${k} has key "${lang}"; quote a text that holds a comma`);
      }
    }
  }
  for (const [fid, f] of flowsOf(it)) {
    for (const k of Object.keys(f ?? {})) {
      if (!FLOW_KEYS.has(k)) errors.push(`${where} ${fid}: unknown key "${k}"; quote a text that holds a comma`);
    }
  }
  return errors;
}

// Every ID a registry entry names must exist and be current.
function crossRefs(reg: Registry): string[] {
  const errors: string[] = [];
  const need = (from: string, id: string | undefined, kind?: Kind) => {
    if (!id) return;
    const it = reg.items.get(id);
    if (!it) errors.push(`${reg.path}: ${from} names ${id}, which does not exist`);
    else if (kind && it.kind !== kind) errors.push(`${reg.path}: ${from} names ${id} as ${kind}`);
  };
  for (const it of reg.items.values()) {
    for (const k of ["uc", "fr", "br", "nfr", "adr"] as Kind[]) {
      for (const id of (it[k] as string[] | undefined) ?? []) need(it.id, id, k);
    }
    for (const [name, flows] of [["alt", it.alt], ["exc", it.exc]] as const) {
      for (const [fid, f] of Object.entries(flows ?? {})) {
        if (!FLOW.test(fid) || fid[0] !== (name === "alt" ? "A" : "E")) {
          errors.push(`${reg.path}: ${it.id} ${fid} is not an ${name === "alt" ? "A" : "E"} flow id`);
        }
        if (f.at !== undefined && !it.main?.[String(f.at)]) errors.push(`${reg.path}: ${it.id} ${fid} branches at missing step ${f.at}`);
        need(`${it.id} ${fid}`, f.br, "br");
        need(`${it.id} ${fid}`, f.nfr, "nfr");
      }
    }
  }
  return errors;
}

// The flows of a UC, A and E together.
export function flowsOf(it: Item): Map<string, Flow> {
  return new Map([...Object.entries(it.alt ?? {}), ...Object.entries(it.exc ?? {})]);
}

// Expands "E1–E5", "E1-E5" or "A2" to the single flow IDs.
export function expandFlows(spec: string): string[] {
  const m = /^([AE])(\d+)(?:[–-]\1?(\d+))?$/.exec(spec);
  if (!m) return [];
  const from = Number(m[2]);
  const to = m[3] ? Number(m[3]) : from;
  const out: string[] = [];
  for (let n = from; n <= to; n++) out.push(`${m[1]}${n}`);
  return out;
}
