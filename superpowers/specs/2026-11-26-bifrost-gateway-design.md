# Design: Bifrost replaces LiteLLM, the server owns AI policy

Date: 2026-11-26.
Status: proposed.
Supersedes, where they differ: `2026-11-17-ai-hub-design.md` (the gateway
rows), `2026-11-18-console-ai-synthesis-design.md` and
`2026-11-16-console-agent-design.md` (LiteLLM keys, end-user budgets,
rotation). Their other decisions stand.

## Why

LiteLLM takes up to 1 GiB, needs about 45 s to get ready, and comes from
the Python and PyPI supply chain. Bifrost is one Go binary: in the spike on
2026-11-26 (v2.6.0) it used 260–440 MiB and started in 1–2 s (20 s on an
empty database while it ran its migrations).

Today LiteLLM's database is where the AI settings live. The server's
console pages call 20 admin endpoints (`internal/provider/litellm`) to
write credentials, deployments, router settings, keys, end-user budgets
and to read spend. The stack seeds it twice, from `litellm/models/*.json`
and `keys.txt` through `keys.sh`, and the console then edits the same rows.
Swapping the gateway one-for-one would carry that two-writer setup over.
This design changes who owns what instead.

## Ownership

| What | Owner | Where |
|---|---|---|
| Providers: base URL, upstream API key, retries, timeouts | infra | `infra/stack/bifrost/config.json`, the keys as `env.*` from Secret `bifrost-secrets` |
| Agents: purpose, model (provider + model), fallbacks, price per model, monthly budget, callers and their rate limits | server | its database, seeded by a migration and edited in the console |
| Teams, virtual keys, budgets, rate limits, pricing overrides in Bifrost | server | written by the server's reconciler; nobody else writes them |
| Measured spend, logs, metrics | Bifrost | its logs store, read by the server; `/metrics` scraped by Prometheus |

`config.json` sets `source_of_truth: "config.json"` and holds only
`client`, `governance.auth_config`, the stores, `encryption_key` and
`providers`. The spike confirmed that this is per section: Bifrost resets
providers to the file on every start and keeps the virtual keys, teams,
budgets and pricing overrides that the API created. `governance.*` sections
other than `auth_config` must never appear in the file, because a present
section wipes what the API made (seen in the spike). `infra/check.sh`
fails on one.

## Shape

```
                 VK per caller (sk-bf-…)          ┌─► upstream   (claude-*, OpenAI-compatible, private IP)
server ─────────────────────────────────────┐     │
agent  ── VK from the server, per run ──────┼──► bifrost:8080 ──► openrouter (gemini, bge-m3)
                                            │     │
server reconciler ── admin API (Basic) ─────┘     └─► Postgres db bifrost (config + logs)
```

- Callers send a concrete model, `provider/model` (such as
  `upstream/claude-haiku-5-5`). A bare name is ambiguous once two
  providers list it (seen in the spike), and Bifrost aliases are not
  used: the server already knows each agent's model.
- One team per agent, carrying the agent's monthly budget. One virtual key
  per caller, under its agent's team, carrying the caller's rate limit and
  `allowed_models` = the agent's model and fallbacks. A leaked key can call
  nothing else.
- Bifrost generates the key values. The reconciler reads them back through
  the admin API and the server keeps them only in memory. No caller key is
  stored in git, in a Secret or in the server's database. The agent gets
  its run's key in the run request.

## Server

### Data

A new migration (`0103_bifrost.sql`) (the applied ones stay as they are):

- `ai_agents.model_provider text NOT NULL`, seeded `upstream` for the
  Claude agents and `openrouter` for `search` and `embed-text`. The
  existing `model_id` becomes the provider's model name
  (`google/gemini-2.5-flash` for search, `baai/bge-m3` for embed-text).
- `ai_agents.fallbacks text[] NOT NULL DEFAULT '{}'`, each entry
  `provider/model`.
- `ai_agents.key_aliases` is renamed `callers`: the virtual key names.
- `ai_agents.model_alias` stays as the agent's stable slug (the team's
  name in Bifrost); it is no longer sent on the wire.
- `ai_model_prices (provider, model_id, input_usd_per_token,
  output_usd_per_token)`: the price of every model an agent uses. Seeded
  with real list prices, so budgets are dollars. The old
  1e-6-per-token convention ends here.
- `console_dashboards.app` allows `bifrost`; the `litellm` rows become
  `bifrost`.
- The per-role and per-member budget settings and their tables go.

### Reconciler

`internal/provider/bifrost` is the admin client.
`agent/service/settings_sync.go` becomes the reconciler: it runs at
startup and after every AI settings write, under a Postgres advisory lock
so that two replicas never create the same key twice.

1. List what the server owns: the teams, by the agents' slugs (a team is
   never deleted, so its spend stays readable); the virtual keys that carry
   `metadata.owner = "server"`; the pricing overrides named `server:…`.
2. For each agent: upsert its team and monthly budget. For each caller,
   upsert its virtual key with `team_id`, `provider_configs` (one per
   provider among the model and fallbacks, `allowed_models` exact), its
   rate limit and `metadata {owner: server, agent: <slug>}`.
3. For each row of `ai_model_prices`: upsert a pricing override (scope
   provider, exact match, `chat_completion` and `embedding`).
4. Delete server-owned objects that no agent or price names any more, and
   disable the keys of disabled agents.
5. Read every server-owned key's value into the in-memory key ring.

The key ring hands the server's own callers their key. On a 401 it reloads
from Bifrost once before failing. The `openrouter` provider in
`config.json` sets `ignore_provider_cost`, so the logged cost is always the
server's price × tokens, OpenRouter included.

### Calls

Each module that calls a model (search, assist, trust, embed) gets one
`gateway.Client`: base URL, key ring, and the agent's current model and
fallbacks (cached, dropped on a settings write). The env settings
`LLM_*`, `ASSIST_LLM_*`, `TRUST_LLM_*`, `EMBED_TEXT_BASE_URL`,
`EMBED_*_API_KEY`, `LITELLM_URL` and `LITELLM_MASTER_KEY` go. What stays is
`GATEWAY_URL` (shared, `server.env`) and `GATEWAY_ADMIN_USER` /
`GATEWAY_ADMIN_PASSWORD` (Secret). `EMBED_TEXT_MODEL` stays only as the
on/off switch, whose meaning moves to the embed agent's `enabled`.

### Spend and status for the console

- Spend per agent per day: `GET /api/logs/histogram/cost/by-dimension?dimension=team_id`.
  The aggregate trails real time by up to a minute, which the spend pages
  say.
- A console run's cost: the agent counts it live (below). The server keeps
  that count with the run.
- Provider status: `/api/providers` plus the share of errors in the last
  hour from `/api/logs/stats`. The model picker uses
  `/api/models/details?provider=`, which also gives the catalog price that
  prefills `ai_model_prices`.

### API and console

| Today | After |
|---|---|
| Providers: add, edit and delete a credential, paste a key, test a connection | Read-only list: provider, models, status. A new provider or key is an infra change. |
| Models: deployments per alias, weights, order | Gone. An agent names one model and its fallbacks. |
| Agents: alias, model, budget, key aliases | Model picker (provider + model), fallbacks, monthly budget, callers' rate limits |
| Models: tags | Tags and the model's price (one price per model, shared by the agents that use it) |
| Rotation: strategy, retries, allowed fails, cooldown, timeout | Gone. Retries and timeouts are per provider in `config.json`. |
| Budgets: per role, per member, per key, per model | One monthly budget per agent (on its page) |
| Spend: by model, by member | By agent, by day |
| Dashboard link `litellm` | `bifrost` (Bifrost's UI for logs; its governance pages show the server's objects, and edits there are overwritten) |

The OpenAPI spec loses the removed paths. The console and website types are
regenerated. The Providers and Agents pages get Superdesign drafts first,
as every UI change does.

## Agent

- `LITELLM_BASE_URL` and `LITELLM_API_KEY` give way to `GATEWAY_BASE_URL`.
  The run request carries `gateway: {key, model, fallbacks, price}`, and
  the key is never logged (`error-details.ts` redacts it).
- `litellm-fetch.ts` becomes `gateway-fetch.ts`:
  - The provider comes from `x-bifrost-routing-info-provider` and the
    model from `x-bifrost-resolved-model` (`client.extra_fields_placement:
    "headers"`). A fallback shows as a resolved model other than the one
    requested.
  - Cost = usage × the run's price, cache reads and writes included as
    today. Bifrost never returns a cost.
  - A 402 (`X-Bifrost-Error-Type: policy_budget_exceeded`) is a spent
    budget and ends the run.
  - A 429 with `policy_rate_limited` is waited out. Bifrost sends no
    Retry-After, so the wait is the window in the message ("resets every
    1m"), or 60 s.
  - In a stream, usage arrives in the `finish_reason` chunk, which the
    reader already handles.
- The `user` field (end-user budgets) goes.

## Infra and compose

- `infra/stack/templates/bifrost.yaml`: ConfigMap from `bifrost/config.json`,
  a Deployment (image `maximhq/bifrost:v2.6.0`, `/health` probes, requests
  64Mi, limit 512Mi) and a Service on 8080. The Job `litellm-keys` and its
  ConfigMaps go with `litellm/`.
- Postgres: database and role `bifrost` replace `litellm`
  (`templates/postgres.yaml`, Secret `bifrost-db`). LiteLLM's spend
  history is not carried over.
- Secrets: `bifrost-secrets` holds `BIFROST_ADMIN_PASSWORD`,
  `BIFROST_ENCRYPTION_KEY`, `LLM_UPSTREAM_API_KEY` and
  `OPENROUTER_API_KEY`. The server gets the admin password. The caller-key
  entries in `server-secrets` and `agent-secrets` go. `infra/cmd/seal` and
  `secrets/example.env` / `compose.env` follow.
- `env/bifrost.env` replaces `env/litellm.env` (`LLM_UPSTREAM_BASE_URL`).
  Compose reads it with `env_file` and the chart with `.Files.Get`, as
  before.
- `config.json`:
  - `allow_private_network: true` on `upstream`.
  - OpenRouter's `base_url` is `https://openrouter.ai/api`.
  - `client.enforce_auth_on_inference: true`.
  - `client.whitelisted_routes: ["/metrics"]`.
  - `logs_store` keeps no bodies (a search photo passes through) and
    keeps 30 days.
- NetworkPolicy:
  - Ingress to bifrost from the server, the agent and Prometheus.
  - Egress to the upstream host, `openrouter.ai` and `getbifrost.ai`.
    Bifrost loads its price sheet at startup and starts without it if
    unreachable; the server's overrides price every model in use anyway.
- Grafana and alerts: the LiteLLM panels and rules move to
  `bifrost_success_requests_total`, `bifrost_error_requests_total`,
  `bifrost_upstream_latency_seconds`, `bifrost_cost_total` and
  `bifrost_provider_key_up`, by `team_name` (agent).
- `infra/probes/litellm-embed` is deleted.

## Testing

- Server: unit tests for the reconciler against a fake admin API (replacing
  `litellm_fake_test.go`), e2e `gateway_stub_test.go` rewritten for
  Bifrost's routes, `go vet ./...`.
- Agent: `gateway-fetch` tests for headers, 402, 429 wait, and cost from
  price.
- Infra: helm unit tests (`bifrost_test.yaml` replacing `litellm_test.yaml`;
  networkpolicy, secrets, server env), plus `infra/check.sh` with the new
  rule against `governance.*` in the file.
- Live: compose up, then one search, one listing read, one console run;
  check the cost in Bifrost's logs against the run's count; restart Bifrost
  and check that the keys and budgets survived.

## Not doing

- Budgets per console member or per role.
- Bifrost aliases, routing rules, semantic cache, MCP gateway.
- Carrying LiteLLM's spend history over.
- A provider key typed into the console.
