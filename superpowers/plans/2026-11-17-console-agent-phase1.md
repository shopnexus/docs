# Console agent, Phase 1: MCP, the member's assistant, the Agent page

> Spec: `docs/superpowers/specs/2026-11-16-console-agent-design.md`.
> Requirements: UC-MOD-08, FR-MOD-03, BR-MOD-03, NFR-PERF-02, NFR-PRIV-02,
> ADR-0003. Mockups: Superdesign project "ShopNexus Console", drafts
> "Agent · Cuộc trò chuyện", "Agent · Đang trả lời", "Agent · Quá thời
> gian", "Agent · Cuộc mới, gắn báo cáo"; look in
> `console/.superdesign/design-system.md` ("Tokens", "Shell", "The agent").

## Goal

A console member opens Agent, starts a chat (alone or attached to a ticket
or an account), asks, and gets an answer in plain text with the sources the
agent read as chips. The agent reads only through server2's MCP. Nothing in
this phase writes, streams or runs in the background: blocks, versions and
SSE are Phase 2, report cases Phase 3, links and the graph Phase 4.

## Global constraints

- One branch per repo: server `feat/console-agent-mcp`, agent
  `feat/console-member`, console `feat/agent-page`, infra
  `feat/agent-service`. Merge locally after checks; no push.
- server2 rules (`server/CLAUDE.md`): OpenAPI first, no config defaults,
  use cases read top to bottom, newest library releases looked up before
  pinning, scratch output in `tmp/`.
- Secrets (`AGENT_SERVICE_TOKEN`, `AGENT_MCP_TOKEN`, LiteLLM keys) never in
  logs, journals or committed files; `.env.example` lists them empty.
- No tool, endpoint or prompt in this phase changes business data.

## 1. server2 (`feat/console-agent-mcp`)

1. Module `agent` in `internal/agent`: `handler` (the console agent
   endpoints), `mcp` (the MCP server and its tools), `service` (the client
   to the agent service and the read record), `repository` (`console_agent_reads`).
   `Mount` takes `module.Deps`, `Settings`, and the services of console,
   support, account, catalog, deal and shipping that the tools adapt.
2. Config, all required: `AGENT_BASE_URL`, `AGENT_SERVICE_TOKEN`,
   `AGENT_MCP_ADDR`, `AGENT_MCP_TOKEN`. In `.env.example`, `cmd/envgen`,
   both compose stacks and `infra/stack/templates/_server-env.tpl`.
3. Migration `00xx_console_agent_reads.sql`: id, member_id, tool, subject
   kind and ids (`uuid[]`), at; index on (at) for the 90-day sweep, which
   runs hourly beside the events cleanup.
4. MCP server: newest `github.com/modelcontextprotocol/go-sdk`, Streamable
   HTTP at `/mcp` on `AGENT_MCP_ADDR`, started and stopped with the app.
   Middleware: bearer `AGENT_MCP_TOKEN` (constant-time compare), then
   `X-Console-Member` loaded through `console.Service` (active member, else
   an MCP error); the member and role go in the context.
5. Tools, read-only, with input and output schemas, `readOnlyHint`, ids in
   every result: `ticket_get`, `tickets_of_account`, `account_get`,
   `order_get` (with the carrier's events and proof), `listing_get`,
   `price_guide`, `account_actions`. Each records its personal-data reads in
   `console_agent_reads`. Report tools wait for Phase 3.
6. `api/paths/console_agent.yaml` with `x-uc: [UC-MOD-08]`:
   `GET/POST /v1/console/agent/conversations`,
   `GET /v1/console/agent/conversations/{id}`,
   `POST /v1/console/agent/conversations/{id}/turns` (buffered JSON this
   phase). Behind `FromConsole` and `Require(…, moderator)`. The handler
   forwards with `AGENT_SERVICE_TOKEN`, `X-Console-Member`,
   `X-Console-Role`, and maps the agent's errors to `apperr` codes
   (`agent_unavailable` 503, `agent_timeout` 504, `agent_budget` 429).
7. Tests: each tool against the test stack (inactive member refused, record
   written, schema holds); the endpoints against a fake agent (`httptest`);
   the trace tags (`// UC-MOD-08 …`) on the service methods.
8. `ARCHITECTURE.md`: a section "Console agent" with the module, the MCP
   listener, the trust rules and the read record.

## 2. agent (`feat/console-member`)

1. Actor: `X-Console-Member` and `X-Console-Role`; a guard that refuses
   requests without `AGENT_SERVICE_TOKEN` (constant-time). `X-User-ID` and
   the gateway actor go.
2. Shopper parts go: `search_products` and the mock MCP, cart and listing
   page context, the buyer scope classifier and support policy as gate,
   memory tools for members. Tests that only covered them go with them.
3. MCP per turn: build the `McpClient` for each turn with headers
   `Authorization: Bearer AGENT_MCP_TOKEN` and `X-Console-Member`, so every
   tool call carries the member. Check that the Strands SDK's client takes
   transport headers; if not, wrap its transport.
4. Schema (new migration, fresh-install rule of the README kept):
   `conversations.subject_kind`, `subject_id`, unique per subject when set;
   `turns.member_id` (who asked). A subject's conversation is shared; one
   without a subject belongs to its creator.
5. System prompt for members: role, subject, the moderation and support
   rules (COD đồng kiểm, no money held, no adjudication, BR-MOD-01), user
   content as quoted data. Model alias `console-agent`.
6. Response: `{conversationId, turnId, answer, sources: [{tool, label, ids}]}`
   built from the turn's finished tool calls.
7. Stuck turns: a start-up and periodic sweep closes `RUNNING` turns past
   the deadline as `FAILED`.
8. Budget: LiteLLM's budget error maps to `agent_budget`.
9. Tests offline with a scripted model: guard, shared conversation by
   subject, member on turns, sources, sweep, budget mapping.

## 3. console (`feat/agent-page`)

1. Geist foundation: `tokens.css` (Geist and Geist Mono, hairline, `lift`,
   radii, sizes), `DESIGN.md` rewritten from the design system, the shell
   (232 px nav with Báo cáo greyed until Phase 3, Agent, the work card).
   Existing pages take the new tokens without layout work.
2. Route `/agent` and `/agent/:id`: thread list grouped by day, chat
   column, ask box with the attached record chip and + menu (tickets and
   accounts this phase), Cuộc mới (`N`). Answers render text and source
   chips; a quiet loader while the buffered call runs; timeout and budget
   errors as the mockups' notice.
3. API client in `src/lib/agent.ts` over the new endpoints.
4. Tests: the agent client's error mapping and the send flow; no visual
   tests.

## 4. infra (`feat/agent-service`)

1. Compose: an `agent` service in each stack (image built from `agent/`),
   its database in the stack's Postgres (`agent` database, pgvector), the
   two tokens shared with the server; `make dev` and `make prod` start it.
2. Helm: a Deployment and Service for the agent, no ingress; a
   NetworkPolicy so only the server reaches the agent and only the agent
   reaches the server's MCP port; secrets sealed as the others.
3. LiteLLM: alias `console-agent` on `claude-sonnet-5-5` with a 20 USD daily
   budget, in the template and its tests.

## Order

server 1–5 → agent 1–4 → server 6 → agent 5–9 → infra → console. Each repo
merges after its own checks; the umbrella bumps submodules at the end and
runs `make trace`.

## Review focus

- [ ] No MCP tool or agent path writes business data.
- [ ] Every MCP call carries a member, refused when the member is inactive.
- [ ] The agent is unreachable from outside the cluster and from anything
      but the server.
- [ ] Personal-data reads land in `console_agent_reads`.
- [ ] No secret in logs, journals or committed files.
