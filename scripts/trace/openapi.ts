// Bundles server/api (openapi.yaml and the files it references) into one
// document for the docs site's API playground. A schema, response or
// parameter keeps its name under components; a path file is inlined.

import { basename, dirname, join, relative } from "node:path";

type Node = unknown;
type Obj = Record<string, Node>;

const KINDS = { schemas: "schemas", responses: "responses", parameters: "parameters" } as const;
type Kind = keyof typeof KINDS;

const pascal = (s: string) =>
  s
    .split(/[^a-zA-Z0-9]+/)
    .filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join("");

export async function bundle(apiDir: string): Promise<Obj> {
  const cache = new Map<string, Obj>();
  const load = async (file: string): Promise<Obj> => {
    let doc = cache.get(file);
    if (!doc) {
      doc = Bun.YAML.parse(await Bun.file(file).text()) as Obj;
      cache.set(file, doc);
    }
    return doc;
  };

  // A name used in two files of one kind takes its file's name in front:
  // chat.yaml#/Quote is ChatQuote, shipping.yaml#/Quote ShippingQuote.
  const names = new Map<string, string>();
  for (const kind of Object.keys(KINDS) as Kind[]) {
    const seen = new Map<string, number>();
    const files: string[] = [];
    for await (const f of new Bun.Glob("*.yaml").scan({ cwd: join(apiDir, kind) })) files.push(join(apiDir, kind, f));
    files.sort();
    for (const f of files) for (const name of Object.keys(await load(f))) seen.set(name, (seen.get(name) ?? 0) + 1);
    for (const f of files) {
      for (const name of Object.keys(await load(f))) {
        const stem = pascal(basename(f, ".yaml"));
        names.set(`${f}#${name}`, (seen.get(name) ?? 0) > 1 ? `${stem}${name}` : name);
      }
    }
  }

  const components: Record<Kind, Obj> = { schemas: {}, responses: {}, parameters: {} };
  const kindOf = (file: string): Kind | undefined => {
    const dir = relative(apiDir, dirname(file));
    return dir in KINDS ? (dir as Kind) : undefined;
  };

  const rewrite = async (node: Node, from: string): Promise<Node> => {
    if (Array.isArray(node)) return Promise.all(node.map((n) => rewrite(n, from)));
    if (!node || typeof node !== "object") return node;
    const obj = node as Obj;
    const ref = obj.$ref;
    if (typeof ref === "string" && !ref.startsWith("#/components/")) {
      const [filePart, pointer = ""] = ref.split("#");
      const file = filePart ? join(dirname(from), filePart) : from;
      const name = pointer.replace(/^\//, "");
      const target = (await load(file))[name];
      if (target === undefined) throw new Error(`${relative(apiDir, from)}: ${ref} names nothing`);
      const kind = kindOf(file);
      const rest: Obj = {};
      for (const [k, v] of Object.entries(obj)) if (k !== "$ref") rest[k] = await rewrite(v, from);
      if (!kind) return { ...((await rewrite(target, file)) as Obj), ...rest };
      const compName = names.get(`${file}#${name}`) as string;
      if (!(compName in components[kind])) {
        components[kind][compName] = {}; // taken before the walk, so a cycle ends here
        components[kind][compName] = await rewrite(target, file);
      }
      return { $ref: `#/components/${kind}/${compName}`, ...rest };
    }
    const out: Obj = {};
    for (const [k, v] of Object.entries(obj)) out[k] = await rewrite(v, from);
    return out;
  };

  const rootFile = join(apiDir, "openapi.yaml");
  const root = await load(rootFile);
  const bundled = (await rewrite(root, rootFile)) as Obj;
  const sorted = (o: Obj) => Object.fromEntries(Object.entries(o).sort(([a], [b]) => a.localeCompare(b)));
  bundled.components = {
    ...((bundled.components as Obj) ?? {}),
    schemas: sorted(components.schemas),
    responses: sorted(components.responses),
    parameters: sorted(components.parameters),
  };
  return bundled;
}
