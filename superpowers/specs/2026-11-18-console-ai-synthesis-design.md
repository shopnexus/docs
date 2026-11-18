# Design: the console as an AI synthesis tool

Date: 2026-11-18.
Status: decided in conversation (brainstorm of 2026-11-18), for review.
Builds on `2026-11-16-console-agent-design.md`, whose phase 1 (buffered
answer, source chips, the Agent page) is live. Mockups: the Superdesign
project "ShopNexus Console", drafts `soft-*` (built by
`console/.superdesign/tools/build_soft_*.py`).
When the work lands, server decisions go into `server/ARCHITECTURE.md`,
agent decisions into `agent/README.md`, console decisions into
`console/DESIGN.md`.

## Scope

Three blocks, one batch of work:

- **A. Runs and the stream.** A turn becomes a run the member watches step
  by step: steps with a one-line summary, tool calls as chips with input,
  result, timing and attempts, provider switches, Stop, Steer, a stop on a
  spent budget, reconnecting after a closed tab, a run that carries on in
  the background.
- **B. Synthesis results.** Answers with numbered citations tied to the
  records they came from, a sources panel, key figures, tables and charts
  inside the answer, documents with versions and export, clarifying
  questions with options, follow-up suggestions, saved skills under `/`.
- **C. AI settings for admins.** Providers (many, rotated by LiteLLM),
  models with tags, agents (each purpose an agent with a readable name and
  required tags; its model picked from the models carrying them), budgets.

Out of scope this batch (decided 2026-11-18): increase requests and
resuming a run after one is approved (block D), sub-agents, slides, DOCX
export, voice.

The console's look and copy (soft look, Be Vietnam Pro, English, one
sidebar, New chat as home) are a console change that needs none of this and
ships first.

## Decisions

| Question | Decision |
|---|---|
| Provider rotation | LiteLLM's router. Providers are LiteLLM credentials; each (provider, model) pair is a LiteLLM deployment; rotation, weights, fallback order, retries and cooldowns are LiteLLM router settings. server drives LiteLLM through its admin API. |
| Run bus | Redis Streams, a new service in compose and the chart. The run itself and its events are kept in the agent's PostgreSQL; Redis carries them live between replicas and carries control messages (stop, steer) to the replica running the turn. |
| Transport to the console | Server-sent events through server, as the 2026-11-16 design decided. Reconnect with `Last-Event-ID`. |
| Where settings live | LiteLLM's database for providers, deployments and budgets (`store_model_in_db`). server's database for what LiteLLM has no place for: tags, agents, skills' sharing. |
| Two kinds of agent | App agents (Search, Scam check, Listing photo reader, Search embeddings) are called by server's code; an admin changes their model, limits and budget, never creates one. Console agents run in the agent service; an admin creates and edits them, and members pick one in the ask box. |
| Readable names | An agent has a name ("Console assistant") shown everywhere and an alias (`console-agent`) used only on the wire to LiteLLM. |
| Tags | Two kinds: type (Chat, Embedding) and capability (Vision, Tool use, Long context, Reasoning, Structured output, Multilingual). Speed and price are not tags; p50 and price show beside a model. |
| Citations | The agent numbers every record a tool returned; the answer's text carries `[n]`; each source keeps the tool call, the record and the quoted line. |
| Steps | The model opens a step with `begin_step(title)` and closes it with `end_step(summary)`; tool calls between belong to the step. A turn without steps shows its tool calls flat. |
| Deadline | Per agent (`limits.deadline_s`), 60 s by default, up to 300 s for synthesis agents. A run past it ends `TIMED_OUT` and keeps what it found. |
| Copy | English on the console. What a customer wrote, replies to customers and the reason a suspended person sees stay Vietnamese. |
| Console agents | Only admins create and edit them. |
| Skills | Always shared with every member; no owner-only skills, no sharing settings. |
| Documents | Kept with their chat and deleted with it (180 days after its last turn). |
| Pause before Stop | Pause replaces Stop as the main control (see Pause, continue and steer). |

## Architecture

```
console ──cookie──▶ server /v1/console/agent/*        ──service token──▶ agent (N replicas)
   ▲  SSE (proxied)        /v1/console/settings/*  ──master key──▶ LiteLLM admin API
   │                                                                     ▲
   └───────────── server ◀──SSE── agent ◀──XREAD── Redis ◀──XADD── agent (runner)
                                     │                                   │
                                     └── agent-db: turns, turn_events ◀──┘
agent ──LiteLLM (alias, user=member)──▶ LiteLLM router ──▶ provider A / B / C
agent ──MCP (read-only tools)──▶ server
```

One turn:

1. Console `POST /v1/console/agent/conversations/{id}/turns {text, agent_id, attachments?, skill_id?}`.
   server checks the session, adds the member and the agent's config (see
   Agents), forwards; the agent stores the turn `RUNNING`, answers
   `202 {turn_id}` and runs it on a worker.
2. Console opens `GET /v1/console/agent/turns/{turn_id}/events`
   (`text/event-stream`); server proxies the agent's stream.
3. The runner appends each event to `turn_events` (its `seq`) and `XADD`s it
   to `turn:{id}` (`MAXLEN ~ 2000`, key expires 1 h after the turn ends).
   A reader replays from PostgreSQL up to the newest `seq`, then follows the
   Redis stream; `Last-Event-ID` is the `seq`.
4. Pause, Stop now and Steer: `POST …/turns/{id}/pause`, `…/stop`,
   `…/steer {text}` `XADD` to `turn:{id}:control`; the runner reads it
   before each model call (see Pause, continue and steer).
5. Closing the tab ends the stream, not the run.

## Events (agent → console)

Every event is `{seq, type, at, …}`. Types:

| Type | Body |
|---|---|
| `turn.started` | `agent {id, name}`, `model`, `deadline_s` |
| `step.started` | `step_id`, `title` |
| `step.finished` | `step_id`, `summary`, `duration_ms` |
| `tool.started` | `call_id`, `step_id?`, `tool`, `label`, `input` |
| `tool.retry` | `call_id`, `attempt`, `error`, `next_in_ms`, `timeout_ms` |
| `tool.finished` | `call_id`, `status` (`success`, `failed`, `skipped`), `duration_ms`, `timing {queued, server, db, return}`, `result_summary`, `source_ids[]` |
| `model.switched` | `from_provider`, `to_provider`, `reason` (from LiteLLM's attempted fallbacks) |
| `thinking` | `summary`, `duration_ms` |
| `text.delta` | `delta` (the draft) |
| `block` | a block (see Answer) |
| `clarify` | `questions[]` (see Clarifying questions); the turn waits |
| `usage` | `input_tokens`, `output_tokens`, `cost_usd`, `provider` |
| `steer.read` | `steer_id`, `step_id` (the update was read before this step) |
| `turn.pausing` / `turn.paused` | `steps_done`, `reason` (`member`, `stop_now`) |
| `turn.resumed` | `by` (`continue`, `steer`) |
| `rate.waiting` | `until` (a per-minute ceiling; the run calls again by itself) |
| `turn.finished` | `status` (`SUCCEEDED`, `FAILED`, `CANCELLED`, `TIMED_OUT`, `BUDGET`), `outcome` (`stopped`, `out_of_room`, `broken`, `unavailable`, `blocked`), `failure?`, `resets_at?`, `continuable` |

Tool input and result bodies are stored in `tool_calls` (as now) and served
by `GET …/tool-calls/{id}` for the tool panel (Result, Input, Raw JSON,
Timing); events carry summaries only.

## Answer (B)

The final answer comes through an output tool `answer(blocks)` whose
arguments are checked by schema; free text the model writes outside it is
kept as one `text` block.

- `text {markdown}` with `[n]` markers; a marker without a source is
  dropped.
- `figures {items: [{value, label, change?, tone?}]}` (2 to 4).
- `table {columns, rows}` (≤ 20 rows; more go in a document).
- `chart {kind: bar|stacked_bar|line, series, labels}`.
- `document_ref {document_id, version}`.
- `follow_ups {items: [text]}` (≤ 3).
- The 2026-11-16 blocks (`evidence`, `proposal`, `reply`, `graph`, …) stay.

Sources: `sources(turn)` lists `{n, kind (report|account|ticket|order|listing|data|log), record_id, label, quote, call_id}`.
The agent assigns `n` in the order tool results arrive and tells the model
the numbers in each tool result's header.

Documents: an output tool `write_document {title, sections[markdown|table|chart]}`
creates or updates `documents` and `document_versions` (agent DB). Console
shows them in the document panel; export is Markdown copy and print to PDF
in the browser this batch.

Clarifying questions: an output tool `ask_user {questions: [{id, label, kind: single|multi, options: [{id, label, hint?}], default?}]}`
ends the model call; the turn goes `AWAITING_INPUT` (the enum exists); the
console answers `POST …/turns/{id}/input {answers}` and the run goes on.

Skills: `skills (id, created_by, name, slug, description, prompt, variables[], updated_at)`
in the agent DB, `GET/POST/PATCH/DELETE …/skills`. Every skill is shared
with every member; `/` in the ask box lists them all; "Make a skill from
this chat" saves the turn's question with its variables.

Turn details: `usage` events summed on the turn (`input_tokens`,
`output_tokens`, `cost_usd`, `first_token_ms`, `provider`).

## Pause, continue and steer (A)

Taken from AI Portal's `2026-10-29-turn-pause-continue-design.md`, adapted
to one agent service and Redis.

- **Pause** is the run's main control. It takes effect before the next
  model call: the call in flight and the tools it asked for finish, so no
  tool is cut halfway and every call keeps its result. The button then reads
  **Stop now**, which ends the run at once as Stop did.
- A paused run is durable: the runner saves the Strands message state on
  the turn (`turns.state jsonb`) and frees its worker; nothing waits in
  memory, so any replica can continue it. `PAUSED` is a new, non-terminal
  turn status.
- A paused run shows **Continue** and **End** above the ask box and writes
  nothing into the transcript. Continue resumes the same turn (same id,
  counters carried on), with no user message.
- A message sent while the run is paused continues it and is read as
  steering. A message sent while it runs is steering too: it waits in
  `turn:{id}:control` and the runner adds it before its next model call.
- **Steering receipts**: each update shows Waiting, then "Read before step
  3" (`steer.read`); an update the run finished without reading offers
  "Send as a new message". An update that carries an attachment, a skill or
  another agent waits in the ask box for the next turn.
- A run that failed partway, timed out or was stopped with Stop now can be
  continued the same way when it is the conversation's latest turn and
  wrote something; a spent budget or a guardrail block cannot.
- States: `RUNNING → PAUSED` (Pause, Stop now), `PAUSED → RUNNING` (Continue,
  a message), `PAUSED → CANCELLED` (End), `FAILED | TIMED_OUT → RUNNING`
  (Continue, as above).

## More from AI Portal (A, B)

- **Waiting out a rate limit**: on LiteLLM's per-minute ceiling the runner
  waits for the window and calls again (`rate.waiting`, a countdown in the
  run card) instead of failing.
- **Turn outcomes in four groups**, each with its own help: stopped
  (Continue), out of room (Continue, or a shorter question), broken on the
  way (Continue), unavailable (another agent or later); budget and
  guardrail blocks say why and offer nothing that cannot work.
- **Try again ▾**: the same question with the same agent, or with another
  agent the member may pick. It adds a sibling turn; the turn shows "‹ 2 of
  2 ›" to move between answers (`turns.parent_turn_id`).
- **Edit a question**: the same sibling mechanism from the member's bubble.
- **Context meter and compaction**: the ask box shows how full the agent's
  context is; past 80 % the run summarises older turns before its next call
  and the thread shows a divider that opens to the summary.
- **Vision guard**: attaching a picture to an agent whose model lacks the
  Vision tag says so and offers the agents that have it (from the tags).
- **Task list**: an output tool `update_tasks(items)` lets the model keep a
  checklist for long syntheses; the run card shows it above the steps.
- **Feedback with a reason**: thumbs down asks why (wrong facts, missing
  source, too long, other); Settings › Feedback lists them with the turn.
- **Guardrail notices** inline in the run (masked a phone number, refused
  off-topic), the same events Settings › Guardrails counts.

## Agents and LiteLLM (C)

server tables (migration, so compose and the cluster seed alike):

- `ai_tags (name, kind type|capability, sort)`, seeded with the eight tags.
- `ai_model_tags (model, tag)`, seeded for the models the stack has.
- `ai_agents (id, kind app|console, name, alias, icon, purpose, required_tags[], model, instructions, instructions_version, tools[], limits jsonb, monthly_budget_usd, enabled, updated_by, updated_at)`,
  seeded with Console assistant (`console-agent`), Scam check (`scam-check`),
  Listing photo reader (`listing-read`), Search (`search`), Search
  embeddings (`embed-text`).
- `ai_agent_versions` keeps each instructions version (who, when).

LiteLLM mapping:

- A provider is a LiteLLM credential (`/credentials`): kind, base URL, key.
  Provider-level weight and fallback order are written onto each of its
  deployments (`litellm_params.weight`, `order`).
- A provider's models: "Pick models" keeps the deployments the admin added;
  "All, kept in sync" makes server list the provider's models every 6 hours
  and add the new ones (tags empty until an admin sets them).
- An agent's model: server rewrites the alias's deployments: one per
  provider that has the model, with that provider's weight and order. App
  code keeps calling the alias, so changing a model needs no deploy.
- Rotation settings (`routing_strategy` simple-shuffle with weights or
  order-based fallback, `num_retries`, `allowed_fails`, `cooldown_time`,
  `timeout`) are LiteLLM router settings set through `/config/update`.
- Keys: a console agent's alias joins the `agent` key's allowed models when
  the agent is created (`/key/update`).
- Budgets: an agent's monthly budget is its key's budget (app agents) or a
  LiteLLM budget on the alias (console agents); a member's daily budget is a
  LiteLLM end-user budget, the agent passing `user=<member id>`. The
  Overview and Budgets figures read LiteLLM's spend endpoints.
- `config.yaml` keeps `general_settings`, gains `store_model_in_db: true`,
  and loses `model_list`; a one-off seed (litellm-sync, both stacks) writes
  today's five aliases as deployments.

server endpoints, admin only, each change written to `console_actions`:

- `GET/POST/PATCH/DELETE /v1/console/settings/providers`, `…/providers/{id}/models` (add, remove, mode), `POST …/providers/{id}/test`.
- `GET /v1/console/settings/models`, `PUT …/models/{model}/tags`.
- `GET/POST/PATCH /v1/console/settings/agents`, `GET …/agents/{id}/versions`.
- `GET/PATCH /v1/console/settings/rotation`.
- `GET/PATCH /v1/console/settings/budgets`, `GET …/spend?range=`.
- `GET /v1/console/agents` for every member: the console agents they may
  pick (name, icon, purpose).

The agent service gets a console agent's instructions, tools allowlist,
limits and alias from server in the forwarded turn request
(`agent_config`), so server stays the only source and the agent keeps no
copy.

## Console

- Shell, look and copy first (no backend).
- Agent page: run card, step timeline, tool chips and the tool panel,
  retry and provider notes, Steer and Stop, the budget stop; answers with
  citations, figures, tables, charts, follow-ups, turn details; sources
  panel; document panel with versions; clarifying cards; `/` skills and the
  agent picker; reconnect on load for a running turn.
- Settings (admin): Overview, Members (exists in the API today), Agents,
  Models, Providers, Budgets, Tools, Guardrails, Audit log.

## Infrastructure

- Redis: service `redis` in compose (dev and prod) and templates in
  `infra/stack` (StatefulSet, Service, NetworkPolicy to agent only),
  `REDIS_URL` in `infra/stack/env/agent.env` (same host in both).
- LiteLLM: `store_model_in_db: true` in the shared `config.yaml`; the seed
  in litellm-sync; server gains `LITELLM_URL` (shared env) and
  `LITELLM_MASTER_KEY` (compose's secrets env and a SealedSecret: a secret
  is the one thing written on each side).

## Testing

- server: settings handlers against a fake LiteLLM admin API; migrations;
  the SSE proxy (headers, `Last-Event-ID`, a closed client).
- agent: the run with a scripted model (steps, tool retry, cancel, steer,
  `ask_user`, `answer` validation, citations numbering, budget stop),
  replay then follow across PostgreSQL and Redis, two replicas
  (runner on one, reader on the other) with a Redis in testcontainers.
- console: event reducer for a run (unit), citations and blocks rendering
  logic; no visual tests.

## Work split

Spec first, then one sub-agent per repo, each in its own worktree, merged
locally in order:

1. **infra**: Redis in compose and the chart; LiteLLM `store_model_in_db`
   and the seed; env keys. `infra/check.sh` passes.
2. **agent**: runs, events, Redis, control, output tools (`begin_step`,
   `end_step`, `answer`, `write_document`, `ask_user`), sources numbering,
   documents, skills, `agent_config`, `user=` for budgets.
3. **server**: forward turns as 202, proxy the stream, cancel, steer,
   input, tool calls, documents and skills paths; settings endpoints over
   LiteLLM; `ai_*` tables and seeds; OpenAPI.
4. **console**: shell, look and copy (starts at once), then the Agent page
   and Settings against the OpenAPI from step 3, with a mock event stream
   until the server lands.

## Open questions

None open; the answers of 2026-11-18 are in Decisions.
