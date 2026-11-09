# Design: the `ai` provider and the STT gateway

Date: 2026-11-09.
Status: decided in conversation, question by question.

## Why

The server will turn a seller's video into a prefilled listing (title,
description, price, condition, category). The first step is speech to text on
the video's sound track. The model is self-hosted: Gipformer 1.5
(`g-group-ai-lab/gipformer1.5-68M-rnnt`, MIT), a 68.6M-parameter Zipformer
transducer for Vietnamese that runs on CPU through sherpa-onnx. It was measured
in `~/zaic` (voice ADR 0003): zero-shot WER 16.45 on the LifeMate dev clips,
against 25.73 for PhoWhisper-large.

LiteLLM stays the centre for every AI feature. The server only ever calls
LiteLLM aliases; which provider or model answers an alias is LiteLLM
configuration. A model that has no OpenAI-compatible server of its own is
wrapped by `ai`, our own provider, which LiteLLM sees as one more OpenAI-style
backend.

## Scope

This spec is part 1 of three:

1. **This spec:** the `ai` repo with an OpenAI-compatible
   `POST /v1/audio/transcriptions`, the LiteLLM alias `stt` with its own
   virtual key and budget in audio seconds, the chart and compose wiring.
2. Later: video → prefilled listing in the server (video upload, a call to
   `stt`, an LLM alias that fills the fields). It decides the client-side video
   limits and whether frames go to a vision model.
3. Later: image → search.

The server exposes no speech-to-text endpoint, in this spec or later. STT is an
internal step of part 2.

Out of scope here: the server endpoint and its `STT_*` config, the fine-tuned
model `gipformer-1.5-ft`, TTS, image search, providers other than `ai` behind
`stt`.

## Decisions

| Question | Decision |
|---|---|
| Gateway | Keep LiteLLM. A gateway of our own would redo keys, budgets, routing and provider translation; model serving is needed either way. |
| Where models run | One repo `github.com/shopnexus/ai` for models with no OpenAI-compatible server (STT now, sherpa-onnx TTS later). Models that have one (vLLM, TEI) are LiteLLM entries, not code. One process per repo, not one process for every model. |
| Transport | HTTP. LiteLLM reaches providers over HTTP only; a stdio provider would need a Python handler inside LiteLLM's image. |
| Language | Go, with the official binding `github.com/k2-fsa/sherpa-onnx-go` (v1.13.8 at the time of writing). Same C++ core as the Python wheel used in zaic, so the same config gives the same output. |
| Layout | One binary, `main.go` at the repo root, no `cmd/`. Submodule `ai/` in the umbrella repo. |
| Model | Base Gipformer 1.5 at Hugging Face revision `dd9227dcd8705c13f33bdbe59728d546ab94480f`, fp32 ONNX, baked into the image. The fine-tuned weights stay out: they were trained on Zalo AI Challenge 2026 data, which is licensed to registered teams only. |
| Long audio | Silero VAD splits speech into pieces of at most 20 s at silences; each piece is decoded, and the texts are joined. |
| Input | Any file ffmpeg reads, audio or video. The server never needs ffmpeg. |
| Auth on `ai` | None. Only pods of the same stack reach it (NetworkPolicy `from-stack`), it has no Ingress, and locally it binds to 127.0.0.1. Callers go through LiteLLM and its keys. |
| Budget | A second virtual key `server-stt`, `models: ["stt"]`, a daily budget in audio seconds, plus `rpm_limit` as a backstop. The search key and its budget are untouched. |

## The `ai` service

### Layout

```
ai/
  main.go            read config, load models, serve HTTP
  config.go          environment variables, no defaults
  openai.go          HTTP handlers
  speech/
    decode.go        ffmpeg: any file -> float32 mono 16 kHz
    transcriber.go   Silero VAD -> pieces of at most 20 s -> Gipformer -> text
  Dockerfile
  .github/workflows/build.yml
  README.md
```

### HTTP contract

`POST /v1/audio/transcriptions`, multipart, following OpenAI's API:

- `file` (required): an audio or video file ffmpeg can read (wav, mp3, m4a,
  mp4, webm, mov, ...).
- `model` (required): a name listed in `AI_STT_MODELS`. Today only
  `gipformer-1.5`. LiteLLM strips the `openai/` prefix of its model string and
  sends this name.
- `language` (optional): empty or `vi`. Anything else is 400.
- `response_format` (optional): `json` (default) or `text`. Anything else is
  400.
- Any other field (`prompt`, `temperature`, `timestamp_granularities`, ...) is
  ignored.

Response for `json`:

```json
{"text": "...", "usage": {"type": "duration", "seconds": 42}}
```

`usage` has the shape OpenAI returns for whisper-1; `seconds` is the decoded
audio length rounded up. For `text` the body is the transcript alone,
`text/plain; charset=utf-8`.

The transcript is lower case (Gipformer writes upper case without
punctuation), pieces joined by single spaces. Audio with no speech gives
`{"text": ""}` with status 200.

`GET /readyz` answers 200 once every model is loaded. `GET /healthz` answers
200 while the process runs. The same split as the server's probes.

### Errors

OpenAI's shape, so LiteLLM passes them through: `{"error": {"message": "...",
"type": "invalid_request_error" | "server_error", "code": "..."}}`.

| Case | HTTP | `code` |
|---|---|---|
| `file` or `model` missing, unsupported `language` or `response_format` | 400 | `invalid_request` |
| `model` not in `AI_STT_MODELS` | 404 | `model_not_found` |
| ffmpeg cannot read the file, or it has no audio track | 400 | `unsupported_media` |
| body over `AI_MAX_UPLOAD_MB` | 413 | `too_large` |
| audio over `AI_MAX_AUDIO_SECONDS` | 413 | `too_long` |
| ffmpeg crash, model failure | 500 | `internal_error` |

### One request

1. **Receive.** The `file` part streams to a temporary file under
   `http.MaxBytesReader` set to `AI_MAX_UPLOAD_MB`. A pipe does not work: phone
   mp4 files often put the `moov` atom at the end, and ffmpeg must seek. The
   file is removed when the request ends.
2. **Decode.** `ffmpeg -nostdin -v error -i <tmp> -map a:0 -vn -ac 1 -ar 16000
   -t <AI_MAX_AUDIO_SECONDS + 1> -f f32le pipe:1`, run under the request's
   context so a client that leaves kills it. More than `AI_MAX_AUDIO_SECONDS`
   of samples gives 413 `too_long`. Memory stays bounded: 300 s of float32 at
   16 kHz is about 19 MB.
3. **VAD.** A new `VoiceActivityDetector` per request with Silero VAD
   (`silero_vad.onnx`, about 2 MB). Constants in code: threshold 0.5, minimum
   silence 0.5 s, minimum speech 0.25 s, maximum speech 20 s (sherpa-onnx
   splits longer speech).
4. **Recognise.** One `OfflineStream` per piece, one `DecodeStreams` call per
   request. The recognizer config matches zaic's
   `voice/lifemate_voice/backends/sherpa_transducer.py`: transducer, fp32,
   `greedy_search`, sample rate 16000, feature dim 80, dither 0.
5. **Join.** Texts in order, lower-cased, whitespace collapsed.

### Concurrency

Each model has one `OfflineRecognizer`, loaded at start-up and shared. A
semaphore of size `AI_MAX_CONCURRENT` bounds the requests decoding at once; a
request waits for a slot until its client gives up.

Whether `OfflineRecognizer` is safe to call from several goroutines at once is
not confirmed. The implementation runs a concurrent test under `-race`. If it
is not safe, each model gets a pool of `AI_MAX_CONCURRENT` recognizers, at
about 270 MB of RAM each.

### Configuration

Every variable is required; a missing one stops the process with its name. The
image sets none of them; the chart and compose set all of them.

| Variable | Meaning | Value in chart and compose |
|---|---|---|
| `AI_ADDR` | listen address | `:8000` |
| `AI_STT_MODELS` | `name=dir` pairs, comma-separated | `gipformer-1.5=/models/gipformer-1.5` |
| `AI_VAD_MODEL` | path of `silero_vad.onnx` | `/models/silero_vad.onnx` |
| `AI_NUM_THREADS` | onnxruntime threads per decode | 4 |
| `AI_MAX_CONCURRENT` | requests decoding at once | 2 |
| `AI_MAX_UPLOAD_MB` | largest accepted file | 100 |
| `AI_MAX_AUDIO_SECONDS` | longest accepted audio | 300 |

### Logs

JSON through `slog`, one line per request: model, bytes, audio seconds, speech
seconds, pieces, decode milliseconds, status. Transcripts are never logged:
they are what a person said.

## Image and CI

`ghcr.io/shopnexus/ai`, amd64 only, a public package.

- **build:** `golang:1.27.3-trixie`, `CGO_ENABLED=1`. The binding needs cgo
  and glibc. The shared libraries shipped in `sherpa-onnx-go-linux`
  (`libsherpa-onnx-c-api.so`, `libonnxruntime.so`) are copied to
  `/usr/local/lib`, then `ldconfig`.
- **models:** `encoder.onnx`, `decoder.onnx`, `joiner.onnx` and `tokens.txt`
  from Hugging Face at the pinned revision, and `silero_vad.onnx` from a pinned
  sherpa-onnx release. Every file has its sha256 written in the Dockerfile; a
  mismatch fails the build.
- **test:** a stage that runs the integration tests against the models (see
  Testing).
- **runtime:** `debian:trixie-slim` with `ffmpeg` (`--no-install-recommends`),
  the binary, the libraries and `/models`, run as a nonroot user. Expected
  size about 500 MB, mostly the model (about 270 MB) and ffmpeg.

`.github/workflows/build.yml` is the server's: a push to `main` builds `:main`
and `:sha-<commit>`; a `vX.Y.Z` tag adds `X.Y.Z` to the digest already built
for that commit. The workflow runs the unit tests before the build.

## Cluster

### Chart (`infra/stack`)

- `values.yaml`: `images.ai: { repository: ghcr.io/shopnexus/ai, tag: main }`
  and `ai: { numThreads: 4, maxConcurrent: 2, maxUploadMB: 100,
  maxAudioSeconds: 300 }`.
- `templates/ai.yaml`: Deployment `ai` (1 replica, sync wave 2, `preferRole
  app`) and Service `ai` on port 8000. An `emptyDir` on `/tmp` for uploads.
  `startupProbe` and `readinessProbe` on `/readyz`, `livenessProbe` on
  `/healthz`. Requests `cpu: 1, memory: 1Gi`, limit `memory: 2Gi`; the
  implementation measures RSS under load and adjusts.
- NetworkPolicy: no change. `from-stack` lets LiteLLM reach `ai`; `ai` gets no
  `from-traefik` entry.

### Image Updater (`infra/argocd/stacks.yaml`)

`ai` joins the `ImageUpdater` like the other four images: `stack-dev` follows
`ghcr.io/shopnexus/ai:main` by digest, `stack-prod` follows semver tags.

### LiteLLM

A second entry in `sn.litellmConfig`:

```yaml
- model_name: stt
  litellm_params:
    model: {{ .Values.litellm.stt.model }}      # openai/gipformer-1.5
    api_base: {{ .Values.litellm.stt.apiBase }} # http://ai:8000/v1
    api_key: none
  model_info:
    mode: audio_transcription
    input_cost_per_second: 0.000001             # 1 of budget is 1M audio seconds
```

`litellm.stt.model` is LiteLLM's full model string, provider prefix included,
so another provider is a values change (plus that provider's key, added when
needed). The chart refuses to render when `litellm.stt.model` or
`litellm.stt.apiBase` is empty.

### The `server-stt` key

The Job `litellm-key` manages a second key with the same update-then-generate
flow as `server`:

- key value `STT_API_KEY` from `server-secrets`, `key_alias: server-stt`
- `models: ["stt"]`
- `max_budget: sttDailySeconds / 1e6`, `budget_duration: 1d`
- `rpm_limit: sttRpmLimit`

| Value | dev | prod |
|---|---|---|
| `litellm.sttDailySeconds` | 3600 | 36000 |
| `litellm.sttRpmLimit` | 10 | 60 |

`values.yaml` sets both to 0 and the per-stack files set the real numbers, as
for `dailyTokens`. `go -C infra run ./cmd/seal <stack>` generates
`STT_API_KEY` into `<stack>.env` and seals it into `server-secrets`. The server
does not read it until part 2; `envFrom` makes the extra variable harmless.

### Risk: does LiteLLM count the seconds?

It is not confirmed that LiteLLM computes the cost of a transcription from an
`openai/` model on a self-hosted `api_base`: it may read `usage.seconds`, it
may measure the file, and it may fail to measure an mp4. The cluster check
below calls `stt` once and reads the key's spend. If the spend does not grow
with the audio length, the seconds budget does nothing, `rpm_limit` is the
only cap, and the gateway docs say so.

## Local stacks

`docker-compose.yml` gets a service `ai`, built from `./ai` as
`shopnexus-ai:local`, in the dev and prod profiles. Compose sets every `AI_*`
variable and publishes `127.0.0.1:8000:8000`. The local stacks have no
LiteLLM: in part 2 the server will call `http://ai:8000/v1` directly with model
`gipformer-1.5`. This spec does not change the server's environment.

## Testing

In the `ai` repo:

1. **Unit tests, no model.**
   - Config: each missing variable is reported by name; a malformed
     `AI_STT_MODELS` is an error.
   - Handlers against a fake transcriber: every row of the error table, both
     response formats, `usage.seconds`, OpenAI's error shape.
   - Decode against real ffmpeg, on fixtures ffmpeg generates at test time:
     wav, m4a, mp4 with picture and sound, mp4 without sound, a garbage file,
     audio over the limit.
2. **Integration tests, real model** (build tag `model`, model paths from the
   environment, run in the image's test stage).
   - Speech fixtures: a few Vietnamese clips from Common Voice (CC0),
     committed with their source noted. No zaic or competition data.
   - The test joins the clips with silences into one file longer than 20 s, so
     VAD must split it, and also wraps it in an mp4.
   - Assertions check expected keywords, not exact text.
   - A concurrent test under `-race` for the shared recognizer.

On the local k3d cluster (the definition of done):

- `infra/check.sh` renders the chart.
- Through a port-forward to LiteLLM, with the `server-stt` key, a wav and an
  mp4 each return their text.
- The key's spend grows by the audio seconds (the risk above).
- The `server` key gets 403 on `stt`; the `server-stt` key gets 403 on
  `search`.

## Docs

- `ai/README.md`: what the service does, the contract, the variables, how to
  run the tests.
- `docs/web/src/content/docs/{en,vi}/operations/cluster/llm-gateway.mdx`: the
  `stt` alias, the `server-stt` key, the seconds budget, the `ai` service, and
  how to point `stt` at another provider.

## Rollout

1. Create `github.com/shopnexus/ai` (ask before `gh repo create`), push, wait
   for CI to publish `:main`, make the package public.
2. In the umbrella repo: add the submodule, the compose service, the chart
   changes and the `ImageUpdater` entries; run the seal command for dev and
   prod; push. Argo CD syncs.
3. Run the cluster checks above.
