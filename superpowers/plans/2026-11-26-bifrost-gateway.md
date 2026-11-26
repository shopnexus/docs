# Plan: Bifrost replaces LiteLLM

Spec: `../specs/2026-11-26-bifrost-gateway-design.md`.
Approved 2026-11-26. Work in `<repo>/.worktrees/bifrost-gateway`, on branch
`feat/bifrost-gateway`, in each repo; another session commits on `main`.
Merge locally when a phase is green, without pushing.

## Contracts (fixed before the phases start)

### Names

| Thing | Value |
|---|---|
| Service | `bifrost`, port 8080; inference at `http://bifrost:8080/v1` |
| Image | `maximhq/bifrost:v2.6.0` |
| Database / role | `bifrost` in the stack's Postgres |
| Providers (config.json) | `upstream` (custom, base `openai`, `LLM_UPSTREAM_BASE_URL`, key `env.LLM_UPSTREAM_API_KEY`, `allow_private_network`), `openrouter` (built-in, `base_url` `https://openrouter.ai/api`, key `env.OPENROUTER_API_KEY`, `ignore_provider_cost`) |
| Secret `bifrost-secrets` | `BIFROST_ADMIN_PASSWORD`, `BIFROST_ENCRYPTION_KEY`, `LLM_UPSTREAM_API_KEY`, `OPENROUTER_API_KEY` |
| Secret `bifrost-db` | `password` |
| Admin user | `admin` (`BIFROST_ADMIN_USERNAME` in `env/bifrost.env`) |
| Server env | `GATEWAY_URL=http://bifrost:8080` and `GATEWAY_ADMIN_USERNAME=admin` (`env/server.env`); `GATEWAY_ADMIN_PASSWORD` from `bifrost-secrets/BIFROST_ADMIN_PASSWORD` |
| Agent env | `GATEWAY_BASE_URL=http://bifrost:8080/v1` (`env/agent.env`) |
| Dashboard app | `bifrost` (replaces `litellm`) |

Removed env: `LITELLM_URL`, `LITELLM_MASTER_KEY`, `LLM_BASE_URL`,
`LLM_MODEL`, `LLM_API_KEY`, `ASSIST_LLM_BASE_URL`, `ASSIST_LLM_MODEL`,
`ASSIST_LLM_API_KEY`, `TRUST_LLM_BASE_URL`, `TRUST_LLM_MODEL`,
`TRUST_LLM_API_KEY`, `EMBED_TEXT_BASE_URL`, `EMBED_INDEX_API_KEY`,
`EMBED_SEARCH_API_KEY`, `AGENT_LLM_API_KEY`, `LITELLM_BASE_URL`,
`LITELLM_API_KEY`, `LITELLM_UI_*`. `*_REASONING_EFFORT`, timeouts and
`EMBED_TEXT_MODEL` (only as on/off: non-empty means on) stay.

### Seed agents (server migration)

| Slug | Kind | Model | Callers |
|---|---|---|---|
| `console-agent` | console | `upstream/claude-sonnet-5-5` | `console-agent` |
| `scam-check` | app | `upstream/claude-haiku-5-5` | `server-trust` |
| `listing-read` | app | `upstream/claude-haiku-5-5` | `server-assist` |
| `search` | app | `openrouter/google/gemini-2.5-flash` | `server-search` |
| `embed-text` | app | `openrouter/baai/bge-m3` (provider pin DeepInfra, no fallbacks, as today's `extra_body`) | `server-embed-index`, `server-embed-search` |

Prices (USD per token, list prices): claude-sonnet-5-5 2e-6 / 1e-5;
claude-haiku-5-5 1e-6 / 5e-6; google/gemini-2.5-flash 3e-7 / 2.5e-6;
baai/bge-m3 1e-8 / 0. Confirm each against Bifrost's catalog
(`/api/models/details`, provider `anthropic` for the Claude models, `openrouter`
for the others) and use the catalog's numbers when they differ. Cache read and cache write are nullable; null means
the input price. Seeded budgets are monthly: console-agent 100, the others
30. Rate limits per caller are seeded from today's `values.yaml`
`litellm.keys` TPM and RPM.

### Server → agent run request

`agent_config.alias` goes. The request gains:

```json
"gateway": {
  "key": "sk-bf-…",
  "model": "upstream/claude-sonnet-5-5",
  "fallbacks": [],
  "price": { "input": 2e-6, "output": 1e-5, "cache_read": null, "cache_write": null }
}
```

The agent never logs `gateway.key`. A run without `gateway` is refused (400).

### Console API (OpenAPI, `server/api`)

- Kept with changes:
  - `GET /ai/providers`: `{name, kind: upstream|openrouter|…, base_host, status: ok|degraded|down|unknown, error_share_1h, model_count}`, read-only. `providerHealth` is merged into it.
  - `GET /ai/providers/{name}/models`: `{model_id, catalog_price?}`, from Bifrost `/api/models/details`.
  - `GET /ai/models`: the models that agents use or that have a price: `{provider, model_id, tags[], price{input,output,cache_read,cache_write}, agents[]}`.
  - `PUT /ai/models/{provider}/{model_id}/tags`.
  - `PUT /ai/models/{provider}/{model_id}/price`.
  - `GET|POST|PATCH /ai/agents…`: an agent has `slug` (read-only after create), `model {provider, model_id}`, `fallbacks[]`, `monthly_budget_usd`, `callers [{name, requests_per_min?, tokens_per_min?}]`. `alias` and `key_aliases` go. A new console agent gets one caller named after its slug.
  - `GET /ai/spend?from&to`: `{days: [{date, total_usd, by_agent: {slug: usd}}], lag_s: 60}`.
- Removed: provider create, update and delete, provider test, provider model add, `rotation`, `budgets` (role and member).
- Kept as they are: agent versions, usage, tools, guardrails, dashboards (with the app `bifrost`).

## Phases

### A1 Infra (umbrella worktree)
- `infra/stack/bifrost/config.json`: shape as in the spec, with
  `source_of_truth: "config.json"` and no governance section other than
  `auth_config`.
- `templates/bifrost.yaml`; delete `templates/litellm.yaml` and `litellm/`.
- `postgres.yaml`: DB and role.
- Secrets: `bifrost-secrets` and `bifrost-db` replace `litellm-secrets` and
  `litellm-db` (dev SealedSecrets resealed with `infra/cmd/seal`).
  Caller-key entries leave `server-secrets` and `agent-secrets`;
  `example.env` and `compose.env` follow.
- `env/bifrost.env`, `env/server.env`, `env/agent.env`, `_server-env.tpl`,
  `agent.yaml`, `_helpers.tpl` (drop the litellm helpers), `values*.yaml`
  (drop `litellm.keys`, add the bifrost image).
- `networkpolicy.yaml`.
- Grafana `platform.json` and `alerting-cluster/rules.yaml` move to the
  `bifrost_*` metrics.
- `infra/check.sh` rule: `bifrost/config.json` carries no
  `governance.virtual_keys|teams|customers|budgets|rate_limits|pricing_overrides|model_configs`.
- Helm tests.
- `docker-compose.yml`: a bifrost service and a gen step for the two
  bifrost secrets in the keys volume; the litellm and litellm-keys services
  go.
- Delete `infra/probes/litellm-embed`.
- Gate: `infra/check.sh`, `helm unittest`, `docker compose config`.

### A2 Server (server worktree)
- Migration (the next number): the columns and tables from the spec, the
  seed changes above, `console_dashboards` app `bifrost`, drop the
  role and member budget tables.
- `internal/provider/bifrost`: admin client (teams, virtual keys, pricing
  overrides, providers, models details, logs histogram by team, logs stats)
  plus an inference client (OpenAI-compatible, key from the ring).
- Reconciler and key ring (spec, "Reconciler"), under a Postgres advisory
  lock.
- Search, assist, trust and embed call through it; the old env goes from
  `config.go`.
- Settings services and OpenAPI per the contract; codegen.
- The agent run request gains `gateway`.
- Delete `internal/provider/litellm` and `litellm_fake_test.go`.
- Rewrite `e2e/gateway_stub_test.go` for Bifrost's routes.
- `ARCHITECTURE.md` and `.env.example`.
- Gate: `go build ./...`, `go vet ./...`, touched packages' tests, e2e for
  the AI settings and the console dashboards.

### A3 Agent (agent worktree)
- `gateway-fetch.ts` replaces `litellm-fetch.ts`, per the spec, "Agent".
- The run request's `gateway`, and the key redacted.
- `config.ts`; README.
- Tests.
- Gate: `npm test`, `tsc`.

### B Console (after A2's OpenAPI lands)
- Superdesign drafts for the Providers and Agents pages, then the code.
- Remove the Rotation page, the role and member budgets, and the provider
  writes.
- Regenerate the types; update the mocks.
- Gate: the console's tests and build.

### C Docs, website, umbrella, live check
- docs/web gateway pages (vi and en), agent pages, the i18n glossary, the
  typst chapters, superseded specs' status lines; the OpenAPI copy.
- Regenerate the website's `schema.d.ts`.
- Bump the umbrella submodules.
- Live: compose up with the merged branches, then one search, one listing
  read, one console run; compare cost against Bifrost's logs; restart
  Bifrost and check that the keys survived.
