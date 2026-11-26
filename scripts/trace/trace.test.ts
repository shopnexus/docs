import { afterEach, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { check } from "./check";
import { bundle } from "./openapi";
import { expandFlows, loadRegistry } from "./registry";
import { rename, renameFromWas } from "./rename";
import { scanAll } from "./scan";

const REGISTRY = `
groups: { DEAL: Giao dịch }
uc:
  - id: UC-DEAL-01
    was: [UC-14]
    status: done
    title: { vi: Thương lượng }
    api: ["POST /v1/deals"]
    main: { 1: Mở, 2: Trả giá }
    alt:
      A1: { at: 1, text: Mở lại }
    exc:
      E1: { at: 1, text: Bị khóa, error: account_suspended }
      E2: { at: 2, text: Sai giá, br: BR-DEAL-01, error: invalid_amount }
  - id: UC-DEAL-02
    status: retired
    title: { vi: Cũ }
br:
  - { id: BR-DEAL-01, was: [BR-06], text: { vi: Bước giá 1.000 } }
`;

const OPENAPI = `
paths:
  /v1/deals:
    $ref: "paths/deal.yaml#/deals"
`;
const DEAL_PATHS = `
deals:
  post:
    operationId: openDeal
    x-uc: [UC-DEAL-01]
`;
const ERRORS = `package domain
var (
	A = apperr.New(apperr.KindForbidden, "account_suspended", "x")
	B = apperr.New(apperr.KindInvalid, "invalid_amount", "x")
)
`;
const SERVICE = `package service

// Open starts a deal.
//
// UC-DEAL-01
func Open() {
	// A1. reopen
	// 1. open; E1 when suspended
	// E2: bad amount
}
`;
const TEST = `package service

// UC-DEAL-01
func TestOpen(t *testing.T) {
	t.Run("E1 suspended", nil)
	t.Run("E2 bad amount", nil)
}
`;

let dir = "";

async function stack(files: Record<string, string>) {
  dir = mkdtempSync(`${tmpdir()}/trace-`);
  const base: Record<string, string> = {
    "docs/registry/requirements.yaml": REGISTRY,
    "server/api/openapi.yaml": OPENAPI,
    "server/api/paths/deal.yaml": DEAL_PATHS,
    "server/internal/deal/domain/errors.go": ERRORS,
    "server/internal/deal/service/open.go": SERVICE,
    "server/internal/deal/service/open_test.go": TEST,
    "docs/typst/ch3.typ": "UC-DEAL-01 · BR-DEAL-01\n",
  };
  for (const [p, text] of Object.entries({ ...base, ...files })) await Bun.write(`${dir}/${p}`, text);
  return { docs: `${dir}/docs`, server: `${dir}/server` };
}

async function run(files: Record<string, string> = {}) {
  const roots = await stack(files);
  const { reg, errors } = await loadRegistry(`${roots.docs}/registry/requirements.yaml`);
  const { refs, problems } = await scanAll(roots, reg);
  const report = await check(roots, reg, refs, problems);
  return { errors: [...errors, ...report.errors.map((e) => e.msg)], warnings: report.warnings.map((w) => w.msg), refs };
}

afterEach(() => {
  if (dir) rmSync(dir, { recursive: true, force: true });
});

describe("check", () => {
  test("a clean stack has no errors or coverage warnings", async () => {
    const { errors, warnings } = await run();
    expect(errors).toEqual([]);
    expect(warnings).toEqual([]);
  });

  test("an unknown id is an error", async () => {
    const { errors } = await run({ "docs/typst/ch3.typ": "UC-DEAL-01 BR-DEAL-01 UC-DEAL-09\n" });
    expect(errors).toContain("UC-DEAL-09 is not in the registry");
  });

  test("an old id is an error that names the current one", async () => {
    const { errors } = await run({ "docs/typst/ch3.typ": "UC-DEAL-01 BR-DEAL-01 UC-14\n" });
    expect(errors.some((e) => e.startsWith("UC-14 is an old id; it is UC-DEAL-01"))).toBe(true);
  });

  test("a retired id is an error", async () => {
    const { errors } = await run({ "docs/web/src/content/docs/en/a.mdx": "UC-DEAL-01 BR-DEAL-01 UC-DEAL-02\n" });
    expect(errors).toContain("UC-DEAL-02 is retired");
  });

  test("a retired id in a Typst report only warns", async () => {
    const { errors, warnings } = await run({ "docs/typst/ch3.typ": "UC-DEAL-01 BR-DEAL-01 UC-DEAL-02\n" });
    expect(errors).not.toContain("UC-DEAL-02 is retired");
    expect(warnings).toContain("UC-DEAL-02 is retired");
  });

  test("a flow the UC lacks is an error", async () => {
    const { errors } = await run({ "docs/typst/ch3.typ": "UC-DEAL-01 E9 BR-DEAL-01\n" });
    expect(errors).toContain("UC-DEAL-01 has no flow E9");
  });

  test("a flow mark outside a tagged function is an error", async () => {
    const { errors } = await run({ "server/internal/x.go": "package x\n\nfunc F() {\n\t// E1\n}\n" });
    expect(errors).toContain("flow or step mark outside a function tagged with a UC");
  });

  test("a flow mark the function's UC lacks is an error", async () => {
    const { errors } = await run({ "server/internal/x.go": "package x\n\n// UC-DEAL-01\nfunc F() {\n\t// E7\n}\n" });
    expect(errors.some((e) => e.startsWith("E7 is not in UC-DEAL-01"))).toBe(true);
  });

  test("a flow's error code the server does not declare is an error", async () => {
    const { errors } = await run({ "server/internal/deal/domain/errors.go": ERRORS.replace("invalid_amount", "bad_amount") });
    expect(errors.some((e) => e.includes("error invalid_amount is not declared"))).toBe(true);
  });

  test("an operation without the UC's x-uc is an error", async () => {
    const { errors } = await run({ "server/api/paths/deal.yaml": DEAL_PATHS.replace("    x-uc: [UC-DEAL-01]\n", "") });
    expect(errors).toContain("POST /v1/deals lacks x-uc UC-DEAL-01");
  });

  test("an x-uc the UC does not list is an error", async () => {
    const { errors } = await run({ "docs/registry/requirements.yaml": REGISTRY.replace(`api: ["POST /v1/deals"]`, "api: []") });
    expect(errors).toContain("POST /v1/deals has x-uc UC-DEAL-01, but UC-DEAL-01 does not list it under api");
  });

  test("a registry entry that names a missing rule is an error", async () => {
    const { errors } = await run({ "docs/registry/requirements.yaml": REGISTRY.replace("br: BR-DEAL-01,", "br: BR-DEAL-07,") });
    expect(errors.some((e) => e.includes("names BR-DEAL-07, which does not exist"))).toBe(true);
  });

  test("an unquoted comma in a title is an error", async () => {
    const { errors } = await run({ "docs/registry/requirements.yaml": REGISTRY.replace("{ vi: Cũ }", "{ vi: Cũ, mới }") });
    expect(errors.some((e) => e.includes('title has key "mới }"') || e.includes('title has key "mới"'))).toBe(true);
  });

  test("a duplicate id is an error", async () => {
    const { errors } = await run({ "docs/registry/requirements.yaml": REGISTRY.replace("id: UC-DEAL-02", "id: UC-DEAL-01") });
    expect(errors.some((e) => e.endsWith("duplicate id"))).toBe(true);
  });

  test("a done UC without code or tests is a warning, and so is an untested E flow", async () => {
    const { warnings } = await run({
      "server/internal/deal/service/open.go": "package service\n",
      "server/internal/deal/service/open_test.go": "package service\n\n// UC-DEAL-01\nfunc TestOpen(t *testing.T) {\n\tt.Run(\"E1 x\", nil)\n}\n",
    });
    expect(warnings).toContain("UC-DEAL-01 is done but no code names it");
    expect(warnings).toContain("UC-DEAL-01 E2 has no test");
    expect(warnings).not.toContain("UC-DEAL-01 E1 has no test");
  });

  test("steps, flow ranges and subtests attach to the function's UC", async () => {
    const { refs } = await run();
    const code = refs.filter((r) => r.kind === "code" && r.id === "UC-DEAL-01");
    expect(code.flatMap((r) => r.flows).sort()).toEqual(["A1", "E1", "E2"]);
    expect(code.flatMap((r) => r.steps)).toEqual([1]);
    expect(refs.filter((r) => r.kind === "test").flatMap((r) => r.flows).sort()).toEqual(["E1", "E2"]);
  });
});

describe("rename", () => {
  test("renames an id everywhere and keeps the old one under was", async () => {
    const roots = await stack({});
    await rename(roots, `${roots.docs}/registry/requirements.yaml`, "BR-DEAL-01", "BR-DEAL-05");
    const reg = await Bun.file(`${roots.docs}/registry/requirements.yaml`).text();
    expect(reg).toContain("{ id: BR-DEAL-05, was: [BR-DEAL-01, BR-06]");
    expect(reg).toContain("br: BR-DEAL-05, error: invalid_amount");
    expect(await Bun.file(`${roots.docs}/typst/ch3.typ`).text()).toBe("UC-DEAL-01 · BR-DEAL-05\n");
  });

  test("adds a was line to a block entry", async () => {
    const roots = await stack({});
    await rename(roots, `${roots.docs}/registry/requirements.yaml`, "UC-DEAL-02", "UC-DEAL-03");
    expect(await Bun.file(`${roots.docs}/registry/requirements.yaml`).text()).toContain(
      "  - id: UC-DEAL-03\n    was: [UC-DEAL-02]\n",
    );
  });

  test("--from-was replaces old ids in docs and code", async () => {
    const roots = await stack({ "docs/typst/ch3.typ": "UC-14, UC-140 và BR-06\n" });
    const { reg } = await loadRegistry(`${roots.docs}/registry/requirements.yaml`);
    await renameFromWas(roots, reg.was);
    expect(await Bun.file(`${roots.docs}/typst/ch3.typ`).text()).toBe("UC-DEAL-01, UC-140 và BR-DEAL-01\n");
  });
});

test("expandFlows", () => {
  expect(expandFlows("E1–E3")).toEqual(["E1", "E2", "E3"]);
  expect(expandFlows("A2")).toEqual(["A2"]);
  expect(expandFlows("E2-4")).toEqual(["E2", "E3", "E4"]);
});

describe("openapi bundle", () => {
  test("keeps component names, prefixes duplicates and inlines path files", async () => {
    dir = mkdtempSync(`${tmpdir()}/trace-`);
    const files: Record<string, string> = {
      "api/openapi.yaml": `openapi: 3.2.0
info: { title: T, version: "1" }
paths:
  /quotes:
    $ref: "paths/q.yaml#/quotes"
components:
  securitySchemes:
    bearer: { type: http, scheme: bearer }
`,
      "api/paths/q.yaml": `quotes:
  get:
    parameters:
      - $ref: "../parameters/common.yaml#/Limit"
    responses:
      "200":
        description: ok
        content:
          application/json:
            schema:
              $ref: "../schemas/chat.yaml#/Quote"
      "400":
        $ref: "../responses/common.yaml#/BadRequest"
`,
      "api/schemas/chat.yaml": `Quote:
  type: object
  properties:
    reply: { $ref: "#/Quote" }
    price: { $ref: "shipping.yaml#/Quote" }
`,
      "api/schemas/shipping.yaml": "Quote: { type: integer }\n",
      "api/responses/common.yaml": `BadRequest:
  description: bad
  content:
    application/json:
      schema: { $ref: "../schemas/shipping.yaml#/Quote" }
`,
      "api/parameters/common.yaml": "Limit: { name: limit, in: query, schema: { type: integer } }\n",
    };
    for (const [p, text] of Object.entries(files)) await Bun.write(`${dir}/${p}`, text);
    const doc = (await bundle(`${dir}/api`)) as any;
    const get = doc.paths["/quotes"].get;
    expect(get.parameters[0]).toEqual({ $ref: "#/components/parameters/Limit" });
    expect(get.responses["200"].content["application/json"].schema).toEqual({ $ref: "#/components/schemas/ChatQuote" });
    expect(get.responses["400"]).toEqual({ $ref: "#/components/responses/BadRequest" });
    expect(doc.components.schemas.ChatQuote.properties).toEqual({
      reply: { $ref: "#/components/schemas/ChatQuote" },
      price: { $ref: "#/components/schemas/ShippingQuote" },
    });
    expect(doc.components.securitySchemes.bearer.scheme).toBe("bearer");
  });
});
