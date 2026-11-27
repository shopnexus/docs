import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { parse } from "yaml";
import type { Lang } from "./i18n";

/**
 * The requirement registry (docs/registry/requirements.yaml) and the trace
 * `make trace` writes next to it. Both are read at build time; the build
 * runs in docs/web, so the registry is one directory up.
 */

type Text = { vi: string; en?: string };

export interface Flow {
  at?: number;
  text: string;
  br?: string;
  nfr?: string;
  error?: string;
}

export interface UseCase {
  id: string;
  status: string;
  title: Text;
  actors: string[];
  secondary?: string[];
  fr?: string[];
  br?: string[];
  nfr?: string[];
  adr?: string[];
  api?: string[];
  pre?: string;
  post?: string;
  main?: Record<string, string>;
  alt?: Record<string, Flow>;
  exc?: Record<string, Flow>;
  notes?: string;
  gaps?: string[];
}

export interface Entry {
  id: string;
  status?: string;
  title?: Text;
  text: Text;
  attr?: string;
  module?: string;
  uc?: string[];
}

interface Raw {
  groups: Record<string, Text>;
  actors: Record<string, Text>;
  uc: UseCase[];
  fr: Entry[];
  br: Entry[];
  nfr: Entry[];
  adr: Entry[];
}

export interface TraceRef {
  file: string;
  line: number;
  kind: "code" | "test" | "api";
  flows: string[];
}

interface Trace {
  server: { repo: string; commit: string };
  refs: Record<string, TraceRef[]>;
  coverage: Record<string, { code: number; tests: number; flows: Record<string, boolean> }>;
}

const dir = resolve(process.cwd(), "../registry");
export const registry = parse(readFileSync(`${dir}/requirements.yaml`, "utf8")) as Raw;
export const trace = JSON.parse(readFileSync(`${dir}/trace.json`, "utf8")) as Trace;

export const tr = (t: Text | undefined, lang: Lang) => (t ? (lang === "en" && t.en) || t.vi : "");

export const groupOf = (id: string) => id.split("-")[1];

export function useCases(group?: string): UseCase[] {
  return registry.uc.filter((u) => u.status !== "retired" && (!group || groupOf(u.id) === group));
}

const all = new Map<string, UseCase | Entry>(
  [...registry.uc, ...registry.fr, ...registry.br, ...registry.nfr, ...registry.adr].map((x) => [x.id, x]),
);

export function find(id: string): UseCase | Entry {
  const it = all.get(id);
  if (!it) throw new Error(`${id} is not in registry/requirements.yaml`);
  return it;
}

export function label(id: string, lang: Lang): string {
  const it = find(id);
  return tr("title" in it && it.title ? it.title : (it as Entry).text, lang);
}

/** Where on the site an ID is described. */
export function hrefOf(id: string, lang: Lang): string {
  const page = id.startsWith("UC-") ? "use-cases" : "rules";
  return `/${lang}/requirements/${page}#${id.toLowerCase()}`;
}

/** A GitHub link to the line, at the commit the trace was built from. */
export function sourceUrl(ref: TraceRef): string {
  const { repo, commit } = trace.server;
  const path = ref.file.replace(/^server\//, "");
  return `${repo}/blob/${commit}/${path}${ref.line ? `#L${ref.line}` : ""}`;
}

export function refsOf(id: string): TraceRef[] {
  return trace.refs[id] ?? [];
}

/** Error code → the exception flows that end on it, with their rules. */
export function errorCodes(): Map<string, { uc: string; flow: string; br?: string }[]> {
  const out = new Map<string, { uc: string; flow: string; br?: string }[]>();
  for (const u of useCases()) {
    for (const [flow, f] of Object.entries(u.exc ?? {})) {
      if (!f.error) continue;
      out.set(f.error, [...(out.get(f.error) ?? []), { uc: u.id, flow, br: f.br }]);
    }
  }
  return new Map([...out].sort(([a], [b]) => a.localeCompare(b)));
}

export const REQ_STRINGS = {
  en: {
    status: { untraced: "Not traced", planned: "Planned", doing: "In progress", done: "Done", retired: "Retired" },
    statusLabel: "Status",
    actors: "Actors",
    secondary: "Supporting",
    pre: "Precondition",
    post: "Postcondition",
    main: "Main flow",
    alt: "Alternate flows",
    exc: "Exception flows",
    step: "Step",
    flow: "Flow",
    text: "What happens",
    error: "Error code",
    tested: "Tested",
    rules: "Related",
    api: "Endpoints",
    code: "Implemented in",
    tests: "Tested by",
    gaps: "Where the code differs",
    noSpec: "Not specified yet.",
    useCase: "Use case",
    title: "Title",
    id: "ID",
    refs: "Code / tests",
    flowsTested: "E flows tested",
    attr: "Quality",
    module: "Module",
    ucs: "Use cases",
  },
  vi: {
    status: { untraced: "Chưa truy vết", planned: "Dự kiến", doing: "Đang làm", done: "Đã xong", retired: "Đã bỏ" },
    statusLabel: "Trạng thái",
    actors: "Tác nhân",
    secondary: "Tác nhân phụ",
    pre: "Tiền điều kiện",
    post: "Hậu điều kiện",
    main: "Luồng chính",
    alt: "Luồng thay thế",
    exc: "Luồng ngoại lệ",
    step: "Bước",
    flow: "Luồng",
    text: "Diễn biến",
    error: "Mã lỗi",
    tested: "Có test",
    rules: "Liên quan",
    api: "Endpoint",
    code: "Code",
    tests: "Test",
    gaps: "Chỗ code khác đặc tả",
    noSpec: "Chưa đặc tả.",
    useCase: "Ca sử dụng",
    title: "Tên",
    id: "Mã",
    refs: "Code / test",
    flowsTested: "Luồng E có test",
    attr: "Thuộc tính",
    module: "Module",
    ucs: "Ca sử dụng",
  },
} as const;
