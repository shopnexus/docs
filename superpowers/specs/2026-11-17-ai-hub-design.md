# Design: `ai` as the AI hub (gateway + self-hosted models)

Date: 2026-11-17.
Status: decided in conversation, question by question. Superseded in part on 2026-11-26 by `2026-11-26-bifrost-gateway-design.md`: Bifrost replaces the LiteLLM gateway, and the server owns the agents, keys and budgets.
Supersedes, where they differ: `2026-11-09-ai-stt-gateway-design.md`
("Where models run", LiteLLM in `infra/stack`), and the model sections of
`2026-11-09-server-photo-similar-search-design.md` ("Models behind
LiteLLM", TEI, "Configuration"). Those specs get a status line pointing
here; their other decisions stand.

## Why

AI calls are spread over three places today. LiteLLM's aliases, keys and
budgets are chart data in `infra/stack`; the self-hosted models are the
`ai` repo; the text embedder is a third Deployment, TEI. In the dev cluster
on 2026-11-17, TEI (5.5 GiB) and `ai` (4.1 GiB) filled the 19 GiB machine
together with the other projects on it, and both were scaled to zero.

Two clients use LiteLLM now, the server and the console agent
(`2026-11-16-console-agent-design.md`, alias `console-agent`, 20 USD a
day), and the console's documents will need text embeddings too. One place
should own which model answers each purpose, who may call it, and what it
may spend.

## Decisions

| Question | Decision |
|---|---|
| Who owns AI | The `ai` repo is the AI hub: the gateway (which model serves each purpose, the keys, the budgets, the spend) and the models ShopNexus hosts itself. Clients name a purpose (an alias) and hold a key; they never name a provider. |
| Gateway | LiteLLM stays. Its configuration (aliases, keys, budgets) moves from `infra/stack` into the `ai` repo. |
| One process or two | Two Deployments from one repo: `ai-gateway` (the official LiteLLM image, configuration from `ai`) and `ai-models` (the Go service built from `ai`). A budget change does not rebuild the 5 GB model image. |
| Who deploys it | The `ai` repo holds a Helm chart. `infra` deploys it per stack (an Argo CD Application `ai-<stack>`) with the stack's values and sealed secrets. Image Updater keeps rolling `ai-models` as today. |
| Gateway database | The stack's Postgres (CNPG), its own database `litellm` and role `litellm`, as today. A separate Postgres only when one gateway serves several stacks or projects. Spend logs keep 30 days (`maximum_spend_logs_retention_period`). |
| Upstream for LLMs | OpenRouter, one key per stack (`OPENROUTER_API_KEY`) with an OpenRouter daily credit limit as the last stop. LiteLLM's per-key budgets stay the working limits. `cli-proxy-api` on the host is dropped. |
| Text embeddings | `baai/bge-m3` through OpenRouter, alias `embed-text`, 1024 dimensions. The same model will embed the console's documents. TEI is removed. |
| Image embeddings | Self-hosted: SigLIP 2 (`siglip2-so400m-patch16-384`, fp32 ONNX) in `ai-models`, alias `embed-image`, as today. |
| Speech to text | Self-hosted: Gipformer 1.5 in `ai-models`, alias `stt`, as today (68.6M parameters, 258 MB of files, about 1 GiB for two long requests). |
| Video frames | `ai-models`' `POST /v1/video/frames`, called by the server directly (not an OpenAI route), as today. |
| Embeddings optional | Each embedder can be off. The server with an empty `EMBED_TEXT_MODEL` or `EMBED_IMAGE_MODEL` writes and queries no vectors of that kind; `ai-models` with an empty `AI_EMBED_MODELS` does not load SigLIP 2. Search then runs on what is left, BM25 at the least. |

## Shape

```
server ─────┐   key per purpose          ┌─► OpenRouter   search, listing-read, scam-check,
console     ├──► ai-gateway:4000 ────────┤                console-agent, embed-text (baai/bge-m3)
agent ──────┘   (LiteLLM, DB litellm)    └─► ai-models:8000   stt (Gipformer), embed-image (SigLIP 2)

server ─────────────────────────────────────► ai-models:8000   POST /v1/video/frames
```

### Aliases

| Alias | Upstream | Model | Priced by |
|---|---|---|---|
| `search` | OpenRouter | chosen per stack in values, today's Claude Haiku 5.5 | tokens |
| `listing-read` | OpenRouter | as `search` | tokens |
| `scam-check` | OpenRouter | as `search` | tokens |
| `console-agent` | OpenRouter | Claude Sonnet 5.5 | tokens |
| `embed-text` | OpenRouter | `baai/bge-m3` | tokens |
| `embed-image` | `ai-models` | `siglip2-so400m-patch16-384` | `ai`'s usage: 576 tokens a photo |
| `stt` | `ai-models` | `gipformer-1.5` | seconds |

Keys keep today's split: `server-llm`, `server-assist`, `server-trust`,
`server-stt`, `server-embed-index`, `server-embed-search`, and the agent's
key for `console-agent`. Budgets and limits are values of the `ai` chart,
set per stack in `infra`.

### `ai` repo layout

```
ai/
  main.go, embed/, speech/, frames/ ...   ai-models (Go), unchanged except as below
  gateway/                                LiteLLM: the config template, the key Job script
  chart/                                  Helm chart: ai-gateway, ai-models, the key Job,
                                          Services, NetworkPolicies, the litellm Database
  Dockerfile                              ai-models image
```

The chart takes the aliases, keys and budgets as values and renders
LiteLLM's `config.yaml`, as `infra/stack/templates/litellm.yaml` and
`litellm-keys.yaml` do now. Their helm-unittest tests move with them.

### What `infra` keeps

- Postgres (CNPG) and the `litellm` role and database, since Postgres
  belongs to the stack. `ai-<stack>` syncs after the stack's wave that
  makes the database.
- The sealed secrets: `litellm-secrets` (`LITELLM_MASTER_KEY`,
  `OPENROUTER_API_KEY`), `litellm-db`, and the clients' keys in
  `server-secrets` and the agent's secret. `infra/cmd/seal` generates
  them as today; `LLM_UPSTREAM_API_KEY` becomes `OPENROUTER_API_KEY`.
- The values per stack: models behind the aliases, budgets, `ai-models`
  memory and which embedders it loads.
- `_server-env.tpl` points the server at `http://ai-gateway:4000/v1` and
  `http://ai-models:8000/v1`.

### Service names

`litellm` becomes `ai-gateway` and `ai` becomes `ai-models`, so a reader of
any client's configuration sees that both belong to the hub. The server's
env, the agent's env, the NetworkPolicies and the docs change with them.

## Server

- Configuration keeps its shape: each purpose has its base URL, model and
  key (`LLM_*`, `ASSIST_LLM_*`, `TRUST_LLM_*`, `STT_*`, `EMBED_*`). In the
  cluster every base URL is `ai-gateway`; locally they point at OpenRouter
  and `ai-models` directly, since the local composes run no gateway.
- `EMBED_TEXT_MODEL` and `EMBED_IMAGE_MODEL` may be empty; every other
  variable stays required. Empty means the kind is off:
  - `ListingEmbed` writes no vectors of that kind and does not retry;
  - `q` leaves out the text list (text off) or the visual list (image off);
  - `like` uses what is on, BM25 on the title at the least;
  - `photo=` with the image embedder off answers 503
    `photo_search_unavailable`, and the app shows a short message.
- With a kind off, its `*_BASE_URL`, `*_VERSION` and the floor may be
  empty too.

## Vectors

- Text vectors keep `EMBED_TEXT_VERSION` = `bge-m3@5617a9f6…` when
  OpenRouter's `baai/bge-m3` gives TEI's vectors: cosine ≥ 0.9999 on the
  texts of `ai/embed/testdata/bge-m3-reference.json` under 2048 tokens.
  TEI cut inputs at 2048 tokens and OpenRouter takes 8,194, so a listing
  text over 2048 tokens gets a different vector; the version still holds
  when the server cuts listing text to 2048 tokens' worth before embedding
  (by characters, measured on the reference texts), else the version
  changes and the text vectors are embedded again.
- Photo vectors are unchanged (same SigLIP 2, same files).

## Local composes

- The umbrella's and the server's composes run `ai-models` (STT, frames,
  SigLIP 2) and no gateway and no TEI. The server calls OpenRouter for the
  LLMs and `embed-text` with the developer's key from `server/.env`, and
  `ai-models` for the rest, with empty keys.
- A developer without an OpenRouter key leaves `EMBED_TEXT_MODEL` empty and
  search runs without text vectors.

## Measured first

1. OpenRouter's `baai/bge-m3` against TEI's reference vectors, as above.
2. LiteLLM's `openai/` provider (or its `openrouter/` provider) passes
   OpenRouter's `usage` through, so budgets count real tokens; and an
   OpenRouter 402 (credit limit) reaches the client as a budget error the
   server and the agent already handle.
3. OpenRouter's provider for `baai/bge-m3` returns the full 1024
   dimensions and accepts 16 inputs a request (`ai.embedMaxInputs`).

If 1 fails, the text version changes and text vectors are embedded again.
If 2 fails, the plan comes back to this spec.

## Memory

- Gone: TEI, 3584Mi requested, 5.5 GiB held in dev.
- `ai-models` with SigLIP 2: 6Gi requested, as today (4.0 GiB idle,
  5.3 GiB on 16 photos). With `AI_EMBED_MODELS` empty: about 1 to 2.5 GiB
  (frames and speech at once peaked at 2.42 GiB on 2026-11-10); the plan
  measures it and sets a smaller request for that case.
- `ai-gateway`: LiteLLM as today, about 0.6 GiB.
- Dev on the author's server runs `ai-models` without SigLIP 2 until the
  machine has room.

## Out of scope

- The console's document embeddings (a later spec; it reuses `embed-text`
  with its own key).
- Spotting photos that do not match their listing (SigLIP's text tower
  needs English listing text, one more LLM call; later).
- One gateway for several stacks or projects.
- The bge-m3 self-hosting work of 2026-11-17 (`ai` branch `feat/bge-m3`,
  umbrella branch `feat/tei-into-ai`, server branch `feat/embed-base-url`):
  not merged. The Go Unigram tokenizer stays on its branch for reference.

## Testing

- `ai`: the chart's helm-unittest tests (moved from `infra/stack`, plus the
  two Deployments, the key Job, the embedders-off case); the Go tests as
  today.
- `infra`: `check.sh`, the stack chart's tests without LiteLLM and TEI,
  the Argo CD Application `ai-<stack>`.
- server: config tests for the empty models; discovery tests for each
  embedder off (no vectors written, the lists left out, `photo=` 503);
  `make search-eval` with text through OpenRouter, compared with the
  2026-11-10 baseline.
- Cluster: `infra/smoke-models.sh <stack>` through `ai-gateway`, every
  alias with its key, and a key refused another key's alias.
