# ai into server: one binary, LiteLLM in the stack

Date: 2026-11-18. Decisions by the user in session.

## Target

- Repo `ai` goes away. Its Go code (embed, frames, speech, config) is copied
  (no history) into server as module `internal/ai`, laid out like the other
  modules (domain / service / handler or worker as fits). No `cmd/ai-models`,
  no service or binary named ai-models or ai-gateway.
- One binary. `internal/ai` is on by config: a process with model paths set
  (`AI_STT_MODELS`, `AI_VAD_MODEL`, `AI_EMBED_MODELS`, the limits of
  `ai/chart/env/models.env`) loads the models and serves Restate services
  `ai.*`; a process without them loads nothing and calls `ai.*` through
  Restate. Cluster: Deployment `server` (API, no models) + Deployment
  `server-ai` (same image, models, 1 replica, the memory ai-models had:
  dev 2–3 GiB without SigLIP, prod 6–8 GiB). Compose dev: one `server-dev`
  with everything on.
- Model files (~5 GB) are not in the image. A job runs `fetch-assets.sh
  models` (sha256-checked) into a volume (compose) / PVC (cluster) mounted
  at `/models`. The image gains only `libonnxruntime.so` and
  `libsherpa-onnx-c-api.so` (cgo; build stage moves from alpine/static to
  debian trixie; runtime from distroless/static to distroless/cc or
  debian-slim).
- LiteLLM is a stack component named `litellm`, like Postgres and Restate:
  templates in `infra/stack/templates/litellm.yaml`, its files in
  `infra/stack/litellm/` (config.yaml, keys.txt, keys.sh), compose services
  `litellm-*`, `litellm-keys-*`, `litellm-db-*`, `litellm-sync-*` mounting
  the same files. Argo app `infra/argocd/ai.yaml` goes; key budgets move to
  `infra/stack/values*.yaml`. Server and agent call `http://litellm:4000/v1`.
- LiteLLM serves only the remote models: `search`, `listing-read`,
  `scam-check`, `console-agent` (LLM upstream, `LLM_UPSTREAM_BASE_URL` +
  `LLM_UPSTREAM_API_KEY`) and `embed-text` (OpenRouter bge-m3). Keys:
  server-llm, server-assist, server-trust, server-embed-index,
  server-embed-search (embed-text only), agent. `server-stt` and the
  embed-image alias go: speech, photo vectors and frames are `internal/ai`.
- Budget of `internal/ai` (speech seconds, photo embeds, frames requests) is
  ours, kept next to LiteLLM's; designed in phase 3.

## Phases

### 1. LiteLLM into infra/stack (from ai/chart)

- Move `ai/chart/gateway/{config.yaml,keys.txt,keys.sh}` to
  `infra/stack/litellm/`, `ai/chart/env/gateway.env` to
  `infra/stack/env/litellm.env`. Drop embed-image, stt aliases and
  server-stt key.
- Port templates gateway.yaml / gateway-keys.yaml and their helpers and
  tests into infra/stack (names `litellm`, `litellm-config`,
  `litellm-keys`). Budgets: `litellm.keys` in values-dev/prod from
  infra/argocd/ai.yaml.
- Rename every `ai-gateway` reference: server.env, agent.env,
  NetworkPolicy, dashboards (console's litellm dashboard), docs comments,
  compose.
- Seal: STT_API_KEY no longer a LiteLLM key (keep or drop with phase 2).
- Gate: `infra/check.sh`, helm unittest, compose config, dev stack up, the
  probe calls of each alias and key.

### 2. internal/ai in server

- Copy ai's packages under `internal/ai/...`, imports to
  `github.com/shopnexus/server/internal/ai/...`, deps (sherpa-onnx-go,
  onnxruntime_go, go-sentencepiece, x/image) into server's go.mod.
- Service API (Restate): `ai.Transcribe`, `ai.EmbedImages`, `ai.Frames`.
  Video and audio are not sent in a request: the caller passes the object
  store key of the video already uploaded (assist reads it from there
  today) and ai opens it. Photo inputs for embeddings are small JPEGs; pass
  bytes up to a cap, or object keys.
- Callers: replace provider/stt, provider/frames and the image half of
  provider/embed with clients of `ai.*`. Config: drop STT_BASE_URL,
  STT_API_KEY, STT_MODEL, AI_FRAMES_BASE_URL, EMBED_IMAGE_BASE_URL; add the
  AI_* model settings (shared ones to infra/stack/env/server.env).
- Build: Dockerfile cgo + libs; server-dev image needs the libs too;
  model tests behind a build tag or skipped without /models.
- Chart: Deployment server-ai, PVC + fetch job; compose: models volume +
  fetch service, server-dev mounts it.
- Remove submodule `ai` from the umbrella and `infra/argocd/ai.yaml`;
  archive repo ai (user's call).

### 3. Budget of internal/ai

- Per day caps for speech seconds, photo embeds and frames requests, kept
  in Postgres, checked in the ai service; design with the user.

## Phase 2 contract (fixed 2026-11-18)

Both halves (server code, umbrella infra) build to this.

### Roles

`SERVER_ROLE` (server config, `oneOf`, default when unset: `all`):

- `all`: compose (dev, prod). Every module, HTTP API, every Restate
  service, and module ai with its models.
- `api`: cluster Deployment `server`. Everything except module ai: no
  models loaded, Restate service `ai` not bound.
- `ai`: cluster RestateDeployment `server-ai`. Only module ai: binds only
  Restate service `ai`, no public HTTP API (health on :8080 only), no
  other modules' workers.

Callers always reach module ai through Restate's ingress
(`RESTATE_INGRESS_URL`, `POST /ai/<Handler>`), in every role, so compose
and the cluster run the same path.

### Restate service `ai`

- `Transcribe` `{"key": "<object store key of a video/audio>"}` →
  `{"text": "..."}`. ai opens the object itself.
- `Frames` `{"key": "..."}` → `{"duration": s, "frames": [{"at_seconds",
  "sharpness", "jpeg" (base64)}]}` (at most 8 frames).
- `EmbedImages` `{"inputs": ["data:image/jpeg;base64,...", ...]}` (at
  most AI_EMBED_MAX_INPUTS) → `{"vectors": [[...], ...]}` with the model
  of AI_EMBED_MODELS (one model).
- Terminal errors for unreadable / too short / too long media, so callers
  map them as today (frames.ErrUnreadable etc.).

The ai client in server implements what callers use today: an
`embed.Model` for photos (so catalog, discovery, assist estimate keep
their code), and key-based Transcribe/Frames for assist's video read
(which already has the video's object key).

### Config

- Kept from ai's config, read by server's config (shared values in
  infra/stack/env/server.env, moved from ai/chart/env/models.env):
  AI_STT_MODELS, AI_VAD_MODEL, AI_NUM_THREADS, AI_MAX_CONCURRENT,
  AI_MAX_AUDIO_SECONDS, AI_EMBED_MAX_INPUTS, AI_EMBED_MAX_CONCURRENT,
  AI_EMBED_MAX_IMAGE_MB, AI_FRAMES_MAX_CONCURRENT, AI_FRAMES_MAX_SECONDS,
  AI_FRAMES_MIN_SHARPNESS. Per stack: AI_EMBED_MODELS (empty: no photo
  vectors; replaces EMBED_IMAGE_MODEL/EMBED_IMAGE_BASE_URL — photo vectors
  are on exactly when AI_EMBED_MODELS is set). Model dirs live under
  /models.
- Dropped: AI_ADDR, AI_MAX_UPLOAD_MB, STT_BASE_URL, STT_API_KEY,
  STT_MODEL, AI_FRAMES_BASE_URL, EMBED_IMAGE_BASE_URL, EMBED_IMAGE_MODEL.
  EMBED_IMAGE_VERSION stays (the stored vectors' model).
- LiteLLM loses aliases stt and embed-image and key server-stt;
  server-embed-index/search call embed-text only.

### Image

- server Dockerfile: build on golang:1.27.3-trixie with CGO_ENABLED=1
  (all of ./cmd/...), copy libsherpa-onnx-c-api.so and libonnxruntime.so
  to /usr/local/lib; runtime debian:trixie-slim with ffmpeg and
  ca-certificates, ldconfig, user 65532, same entrypoint /server and the
  other binaries at /.
- scripts/fetch-models.sh (ai's fetch-assets.sh + assets.sha256) in
  server, shipped in the image at /fetch-models.sh, so compose and the
  chart run the image to fill /models.
- Model tests: skip when /models (or AI_TEST_MODELS) is missing.
