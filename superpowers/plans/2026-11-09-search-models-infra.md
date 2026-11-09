# Search models in the stack (infra) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the two embedding models of photo search behind each stack's LiteLLM (alias `embed-text` → TEI with bge-m3, alias `embed-image` → `ai` with SigLIP 2), with their own virtual keys and budgets, and turn LiteLLM's aliases and keys into chart data.

**Architecture:** The chart `infra/stack` keeps LiteLLM. `litellm.aliases` and `litellm.keys` in `values.yaml` become the only place an alias or key is declared; `templates/litellm.yaml` renders the config and the Deployment from them, and `templates/litellm-keys.yaml` renders the key Job from them. A new `templates/tei.yaml` runs Text Embeddings Inference. Before the chart relies on LiteLLM for images, a probe under `infra/probes/` measures three behaviours of the pinned LiteLLM against a stub upstream.

**Tech Stack:** Helm 3 chart with helm-unittest, kubeconform, yq, hurl, Go 1.27 (the `infra` module), Docker Compose, LiteLLM `ghcr.io/berriai/litellm-database:v1.108.0`, TEI `ghcr.io/huggingface/text-embeddings-inference:cpu-1.9.4`, Astro docs (`docs/web`).

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-09-server2-photo-similar-search-design.md` (sections "Models behind LiteLLM", "Measured first", "Configuration"). This is plan 2 of 3: plan 1 adds `POST /v1/embeddings` to `ai`, plan 3 builds the server side.

## Global Constraints

- Aliases: `search`, `stt`, `embed-text`, `embed-image`. Keys: `server-llm`, `server-stt`, `server-embed-index`, `server-embed-search`, reading `LLM_API_KEY`, `STT_API_KEY`, `EMBED_INDEX_API_KEY`, `EMBED_SEARCH_API_KEY` from `server-secrets`.
- Budgets count money: a token at `0.000001`, a second of audio at `0.000001`; `max_budget = dailyUnits / 1,000,000`; `budget_duration: 1d`.
- `BAAI/bge-m3` at revision `5617a9f61b028005a4858fdac845db406aefb181`.
- SigLIP 2 in `ai`: `AI_EMBED_MODELS=siglip2-so400m-patch16-384=/models/siglip2-so400m-patch16-384`, `AI_EMBED_MAX_INPUTS=16`, `AI_EMBED_MAX_CONCURRENT=2`, `AI_EMBED_MAX_IMAGE_MB=10`.
- Server env in the cluster: `EMBED_TEXT_BASE_URL` and `EMBED_IMAGE_BASE_URL` = `http://litellm:4000/v1`, `EMBED_TEXT_MODEL=embed-text`, `EMBED_IMAGE_MODEL=embed-image`.
- Configuration has no defaults: every chart value the templates read goes through `required`, and compose sets every `EMBED_*` and `AI_EMBED_*` variable. A variable whose empty value means something (the embed keys locally) is set to `""`.
- Newest releases: TEI `cpu-1.9.4` (released 2026-09-15, the newest as of 2026-11-09). LiteLLM stays at the pinned `v1.108.0`, which the spec measures; upgrading it is separate work.
- `store_prompts_in_spend_logs` is `false` in LiteLLM's config.
- The key Job keeps its name `litellm-key` (docs and runbooks name it) and its wave 3.
- TEI and `ai` have no Ingress and no authentication; only `from-stack` admits traffic to them.
- Scratch files and probe output go in the umbrella's `tmp/` (git-ignored), never `/tmp`.
- Commits carry no `Co-Authored-By` trailer.
- Docs prose goes through the `humanizing-writing` skill and its checker before commit.

## Review Focus

1. Renaming the key `server` to `server-llm` on a live stack: the Job's `/key/update` with the same key value must rename the alias and keep the key's spend; a reader expects one key, not a second one. Checked in Task 11, step 3.
2. A sync that renders the embed keys before `server-secrets` holds `EMBED_INDEX_API_KEY` and `EMBED_SEARCH_API_KEY`: the Job pod cannot start and blocks the sync at wave 3. Task 7 and Task 11 push the resealed secrets in the same commit as the keys.
3. A data URL near 1 MB (a large phone photo the server failed to shrink) must still pass LiteLLM unchanged and be priced from usage. Task 2's probe sends one.
4. TEI restarting on `emptyDir` downloads the weights again; the startup probe must allow for the measured download, or the pod restarts forever. Task 5 sets the probe from the measurement.
5. A stack file that overrides one key's budget must leave every other key's values from `values.yaml` in place (Helm deep-merges maps). Task 7 has a unittest that sets one embed key in a test file and checks `server-stt` unchanged.

---

## File Structure

| Path | Change | Responsibility |
|---|---|---|
| `infra/probes/sample/main.go` | create | prints a JPEG as a data URL or writes a silent WAV, for the probe and the model smoke |
| `infra/probes/sample/main_test.go` | create | the samples decode |
| `infra/probes/litellm-embed/compose.yaml` | create | Postgres, the pinned LiteLLM and a stub upstream |
| `infra/probes/litellm-embed/config.yaml` | create | LiteLLM config of the probe |
| `infra/probes/litellm-embed/stub/main.go` | create | OpenAI-style embeddings upstream that records the request |
| `infra/probes/litellm-embed/run.sh` | create | runs the three measurements, exits non-zero on a failure |
| `infra/stack/values.yaml`, `values-dev.yaml`, `values-prod.yaml` | modify | `litellm.aliases`, `litellm.keys`, `tei`, `ai` embed values, `server.embed` |
| `infra/stack/templates/litellm.yaml` | modify | config and Deployment from `litellm.aliases` |
| `infra/stack/templates/litellm-keys.yaml` | create | the key Job from `litellm.keys`, with the checks |
| `infra/stack/templates/_helpers.tpl` | modify | `sn.keyEnv`, `sn.keyBody` |
| `infra/stack/templates/tei.yaml` | create | TEI Deployment, Service, optional PVC |
| `infra/stack/templates/ai.yaml` | modify | `AI_EMBED_*` env, memory from values |
| `infra/stack/templates/_server-env.tpl` | modify | `EMBED_*` |
| `infra/stack/tests/litellm_test.yaml` | rewrite | aliases, keys, refusals |
| `infra/stack/tests/values-*.yaml` (new test files) | create | bad values for the refusal tests |
| `infra/stack/tests/tei_test.yaml` | create | TEI |
| `infra/stack/tests/ai_test.yaml`, `server_env_test.yaml`, `networkpolicy_test.yaml` | modify | new env and policies |
| `infra/cmd/seal/main.go`, `main_test.go` | modify | the two embed keys |
| `docker-compose.yml` | modify | `x-tei`, `tei-dev`, `tei-prod`, `AI_EMBED_*`, server `EMBED_*` |
| `infra/check.sh` | modify | compose TEI image, revision and versions follow the chart |
| `infra/smoke-models.sh`, `infra/smoke-models.hurl` | create | calls every alias of a running stack through a port-forward |
| `docs/web/src/content/docs/{en,vi}/operations/cluster/llm-gateway.mdx` | modify | aliases as data, embed aliases, TEI, keys |
| `docs/web/src/content/docs/{en,vi}/operations/cluster/secrets.mdx`, `index.mdx` | modify | the new keys, the Job's description |

Working directory for every command is the umbrella, `~/shopnexus`, unless a step says otherwise. Infra commits go to the umbrella repo; docs commits go to the `docs` submodule, and the umbrella then records the submodule.

---

### Task 1: Sample files for probes and smoke tests

**Files:**
- Create: `infra/probes/sample/main.go`
- Test: `infra/probes/sample/main_test.go`

**Interfaces:**
- Produces: `go -C infra run ./probes/sample jpeg <px>` prints `data:image/jpeg;base64,<...>` of a `px`×`px` noise JPEG to stdout. `go -C infra run ./probes/sample wav <seconds> <path>` writes a silent 16 kHz mono 16-bit WAV. Tasks 2 and 9 call both.

- [ ] **Step 1: Write the failing test**

```go
package main

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"image/jpeg"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestJPEGIsADataURLOfTheSize(t *testing.T) {
	var out bytes.Buffer
	if err := run([]string{"jpeg", "64"}, &out); err != nil {
		t.Fatal(err)
	}
	s := strings.TrimSpace(out.String())
	b64, ok := strings.CutPrefix(s, "data:image/jpeg;base64,")
	if !ok {
		t.Fatalf("not a JPEG data URL: %.40s", s)
	}
	raw, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		t.Fatal(err)
	}
	img, err := jpeg.Decode(bytes.NewReader(raw))
	if err != nil {
		t.Fatal(err)
	}
	if b := img.Bounds(); b.Dx() != 64 || b.Dy() != 64 {
		t.Errorf("size %v, want 64x64", b)
	}
}

func TestLargeJPEGIsLarge(t *testing.T) {
	var out bytes.Buffer
	if err := run([]string{"jpeg", "1200"}, &out); err != nil {
		t.Fatal(err)
	}
	if n := out.Len(); n < 700_000 {
		t.Errorf("a 1200 px noise JPEG gave %d bytes, want at least 700 kB", n)
	}
}

func TestWAVIsSilentPCM(t *testing.T) {
	path := filepath.Join(t.TempDir(), "s.wav")
	if err := run([]string{"wav", "2", path}, &bytes.Buffer{}); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(b[0:4]) != "RIFF" || string(b[8:12]) != "WAVE" {
		t.Fatalf("no RIFF/WAVE header")
	}
	if rate := binary.LittleEndian.Uint32(b[24:28]); rate != 16000 {
		t.Errorf("rate %d, want 16000", rate)
	}
	if got, want := len(b), 44+2*16000*2; got != want {
		t.Errorf("%d bytes, want %d", got, want)
	}
	for _, x := range b[44:] {
		if x != 0 {
			t.Fatal("the samples are not silent")
		}
	}
}

func TestBadArguments(t *testing.T) {
	for _, args := range [][]string{nil, {"jpeg"}, {"jpeg", "0"}, {"wav", "1"}, {"png", "8"}} {
		if err := run(args, &bytes.Buffer{}); err == nil {
			t.Errorf("run(%q) gave no error", args)
		}
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go -C infra test ./probes/sample/`
Expected: FAIL, `undefined: run`.

- [ ] **Step 3: Write the implementation**

```go
// Command sample writes the files that infra's probes and model smoke test
// send: a noise JPEG as a data URL, the form the server sends embed-image,
// and a silent WAV for stt.
//
//	go -C infra run ./probes/sample jpeg <px>
//	go -C infra run ./probes/sample wav <seconds> <path>
package main

import (
	"bytes"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"io"
	"math/rand/v2"
	"os"
	"strconv"
)

func main() {
	if err := run(os.Args[1:], os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "sample:", err)
		os.Exit(2)
	}
}

func run(args []string, out io.Writer) error {
	if len(args) == 0 {
		return errors.New("usage: sample jpeg <px> | sample wav <seconds> <path>")
	}
	switch args[0] {
	case "jpeg":
		if len(args) != 2 {
			return errors.New("usage: sample jpeg <px>")
		}
		px, err := strconv.Atoi(args[1])
		if err != nil || px < 1 {
			return fmt.Errorf("px %q is not a positive integer", args[1])
		}
		// Noise does not compress, so the size of the file follows px.
		r := rand.New(rand.NewPCG(1, 2))
		img := image.NewRGBA(image.Rect(0, 0, px, px))
		for y := range px {
			for x := range px {
				img.Set(x, y, color.RGBA{uint8(r.UintN(256)), uint8(r.UintN(256)), uint8(r.UintN(256)), 255})
			}
		}
		var b bytes.Buffer
		if err := jpeg.Encode(&b, img, &jpeg.Options{Quality: 90}); err != nil {
			return err
		}
		_, err = fmt.Fprintf(out, "data:image/jpeg;base64,%s\n", base64.StdEncoding.EncodeToString(b.Bytes()))
		return err
	case "wav":
		if len(args) != 3 {
			return errors.New("usage: sample wav <seconds> <path>")
		}
		sec, err := strconv.Atoi(args[1])
		if err != nil || sec < 1 {
			return fmt.Errorf("seconds %q is not a positive integer", args[1])
		}
		const rate, bytesPerSample = 16000, 2
		data := sec * rate * bytesPerSample
		var b bytes.Buffer
		b.WriteString("RIFF")
		_ = binary.Write(&b, binary.LittleEndian, uint32(36+data))
		b.WriteString("WAVEfmt ")
		for _, v := range []any{uint32(16), uint16(1), uint16(1), uint32(rate), uint32(rate * bytesPerSample), uint16(bytesPerSample), uint16(16)} {
			_ = binary.Write(&b, binary.LittleEndian, v)
		}
		b.WriteString("data")
		_ = binary.Write(&b, binary.LittleEndian, uint32(data))
		b.Write(make([]byte, data))
		return os.WriteFile(args[2], b.Bytes(), 0o644)
	default:
		return fmt.Errorf("unknown sample %q", args[0])
	}
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go -C infra test ./probes/sample/ && go -C infra vet ./...`
Expected: `ok  github.com/shopnexus/shopnexus/infra/probes/sample`. If `TestLargeJPEGIsLarge` reports fewer bytes, raise its `px` in the test and in Task 2's `run.sh` together until the file is above 700 kB.

- [ ] **Step 5: Commit**

```bash
git add infra/probes/sample
git commit -m "build: sample JPEG and WAV files for infra's probes"
```

---

### Task 2: Measure LiteLLM with images (spec "Measured first" 1, 2, 4)

**Files:**
- Create: `infra/probes/litellm-embed/compose.yaml`
- Create: `infra/probes/litellm-embed/config.yaml`
- Create: `infra/probes/litellm-embed/stub/main.go`
- Create: `infra/probes/litellm-embed/run.sh`

**Interfaces:**
- Consumes: `go -C infra run ./probes/sample jpeg <px>` (Task 1).
- Produces: `infra/probes/litellm-embed/run.sh`, exit 0 when the pinned LiteLLM (1) forwards data-URL and text inputs unchanged, (2) prices an embedding from the upstream's `usage`, (4) keeps no input in `LiteLLM_SpendLogs`. It prints what LiteLLM sent upstream besides `input` (for plan 1: whether `encoding_format` arrives and with which value).

- [ ] **Step 1: Write the stub upstream**

`infra/probes/litellm-embed/stub/main.go`:

```go
// Command stub stands in for an OpenAI-style embeddings upstream behind
// LiteLLM. It keeps each request body in $OUT/<n>.json and answers 576
// prompt tokens per input, the count ai gives an image, so the probe can
// tell pricing from the upstream's usage apart from LiteLLM counting the
// input's characters.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sync/atomic"
)

func main() {
	out := os.Getenv("OUT")
	if out == "" {
		log.Fatal("OUT is required")
	}
	var n atomic.Int64
	http.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	http.HandleFunc("POST /v1/embeddings", func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		if err := os.WriteFile(filepath.Join(out, fmt.Sprintf("%d.json", n.Add(1))), body, 0o644); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		var req struct {
			Model string          `json:"model"`
			Input json.RawMessage `json:"input"`
		}
		if err := json.Unmarshal(body, &req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		// OpenAI allows one string or a list of them.
		var inputs []string
		if err := json.Unmarshal(req.Input, &inputs); err != nil {
			var one string
			if err := json.Unmarshal(req.Input, &one); err != nil {
				http.Error(w, "input is neither a string nor a list of strings", http.StatusBadRequest)
				return
			}
			inputs = []string{one}
		}
		data := make([]map[string]any, len(inputs))
		for i := range inputs {
			data[i] = map[string]any{"object": "embedding", "index": i, "embedding": []float32{0.6, 0.8}}
		}
		tokens := 576 * len(inputs)
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"object": "list", "model": req.Model, "data": data,
			"usage": map[string]int{"prompt_tokens": tokens, "total_tokens": tokens},
		})
	})
	log.Fatal(http.ListenAndServe(":8000", nil))
}
```

- [ ] **Step 2: Write the probe's LiteLLM config and compose file**

`infra/probes/litellm-embed/config.yaml`:

```yaml
# The probe's LiteLLM: embed-image priced as the chart prices it, over the
# stub. proxy_batch_write_at only makes spend reach the database sooner.
model_list:
  - model_name: embed-image
    litellm_params:
      model: openai/siglip2-so400m-patch16-384
      api_base: http://stub:8000/v1
      api_key: none
    model_info:
      mode: embedding
      input_cost_per_token: 0.000001
      output_cost_per_token: 0.000001
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
  store_prompts_in_spend_logs: false
  proxy_batch_write_at: 2
litellm_settings:
  drop_params: true
```

`infra/probes/litellm-embed/compose.yaml`:

```yaml
# The pinned LiteLLM over a stub upstream, for run.sh. Images follow
# infra/stack/values.yaml.
name: probe-litellm-embed
services:
  postgres:
    image: paradedb/paradedb:0.26.4-pg18
    environment: { POSTGRES_USER: litellm, POSTGRES_PASSWORD: litellm, POSTGRES_DB: litellm }
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -h 127.0.0.1 -U litellm -d litellm"]
      interval: 2s
      retries: 30
  stub:
    build:
      context: ./stub
      dockerfile_inline: |
        FROM golang:1.27.3 AS build
        WORKDIR /src
        COPY main.go .
        RUN CGO_ENABLED=0 go build -o /stub main.go
        FROM gcr.io/distroless/static-debian12
        COPY --from=build /stub /stub
        ENTRYPOINT ["/stub"]
    environment: { OUT: /out }
    volumes: ["${OUT_DIR:?}:/out"]
  litellm:
    image: ghcr.io/berriai/litellm-database:v1.108.0
    command: [--config, /etc/litellm/config.yaml, --port, "4000"]
    environment:
      LITELLM_MASTER_KEY: sk-probe-master
      DATABASE_URL: postgresql://litellm:litellm@postgres:5432/litellm
    volumes: ["./config.yaml:/etc/litellm/config.yaml:ro"]
    ports: ["127.0.0.1:56599:4000"]
    depends_on:
      postgres: { condition: service_healthy }
      stub: { condition: service_started }
```

- [ ] **Step 3: Write run.sh**

`infra/probes/litellm-embed/run.sh` (mode 755):

```bash
#!/usr/bin/env bash
# Measures, on the pinned LiteLLM, what photo search relies on
# (spec 2026-11-09-server2-photo-similar-search-design.md, "Measured first"):
#   1. a data URL and a text in input reach the upstream unchanged;
#   2. a call is priced from the upstream's usage, not from the input's length;
#   4. no input lands in LiteLLM_SpendLogs.
# It also prints what LiteLLM sends upstream besides input.
#   infra/probes/litellm-embed/run.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
export OUT_DIR="$root/tmp/probe-litellm-embed"
rm -rf "$OUT_DIR" && mkdir -p "$OUT_DIR"
dc() { docker compose -f "$here/compose.yaml" "$@"; }
trap 'dc down -v >/dev/null 2>&1 || true' EXIT
fails=0
fail() { echo "FAIL: $*" >&2; fails=$((fails + 1)); }

dc up -d --build --wait
api=http://127.0.0.1:56599
for _ in $(seq 90); do curl -fsS "$api/health/readiness" >/dev/null 2>&1 && break; sleep 1; done
master="Authorization: Bearer sk-probe-master"

key=$(curl -fsS "$api/key/generate" -H "$master" -H 'Content-Type: application/json' \
  -d '{"key_alias":"probe","models":["embed-image"],"max_budget":10,"budget_duration":"1d"}' | jq -r .key)

embed() { # $1: a file holding the request body
  curl -sS -o "$OUT_DIR/answer.json" -w '%{http_code}' "$api/v1/embeddings" \
    -H "Authorization: Bearer $key" -H 'Content-Type: application/json' --data-binary "@$1"; }

# A photo the size the server sends (768 px), one near 1 MB, and a text.
go -C "$root/infra" run ./probes/sample jpeg 768 | tr -d '\n' >"$OUT_DIR/photo.txt"
go -C "$root/infra" run ./probes/sample jpeg 1200 | tr -d '\n' >"$OUT_DIR/big.txt"
calls=0
for f in photo big; do
  jq -Rn --rawfile u "$OUT_DIR/$f.txt" '{model:"embed-image", input:[$u]}' >"$OUT_DIR/$f.req.json"
  code=$(embed "$OUT_DIR/$f.req.json"); calls=$((calls + 1))
  [[ $code == 200 ]] || fail "$f: HTTP $code: $(head -c 300 "$OUT_DIR/answer.json")"
  sent=$(jq -r '.input[0]' "$OUT_DIR/$calls.json" 2>/dev/null || jq -r '.input' "$OUT_DIR/$calls.json")
  [[ $(sha256sum <<<"$sent") == $(sha256sum <<<"$(cat "$OUT_DIR/$f.txt")") ]] || fail "1: the $f data URL changed on its way upstream"
  echo "$f: $(wc -c <"$OUT_DIR/$f.txt") bytes of data URL"
done
jq -n '{model:"embed-image", input:["a blue bicycle"]}' >"$OUT_DIR/text.req.json"
code=$(embed "$OUT_DIR/text.req.json"); calls=$((calls + 1))
[[ $code == 200 ]] || fail "text: HTTP $code"
[[ $(jq -r '.input[0] // .input' "$OUT_DIR/$calls.json") == "a blue bicycle" ]] || fail "1: the text changed on its way upstream"
echo "what LiteLLM sends upstream besides input: $(jq -c 'del(.input)' "$OUT_DIR/1.json")"

# 2. Three inputs at 576 tokens each: 1728 tokens, 0.001728 of budget. Counting
# the data URLs' characters would give about 400,000 tokens.
want=0.001728
spend=0
for _ in $(seq 60); do
  spend=$(curl -fsS "$api/key/info?key=$key" -H "$master" | jq -r '.info.spend // 0')
  awk -v s="$spend" 'BEGIN { exit !(s > 0) }' && break
  sleep 1
done
awk -v s="$spend" -v w="$want" 'BEGIN { d = s - w; if (d < 0) d = -d; exit !(d < 0.000001) }' \
  || fail "2: spend is $spend, want $want (priced from usage)"
echo "spend after $calls calls: $spend"

# 4. Spend logs exist but hold no input.
rows=$(dc exec -T postgres psql -U litellm -d litellm -Atc 'SELECT count(*) FROM "LiteLLM_SpendLogs"')
leaked=$(dc exec -T postgres psql -U litellm -d litellm -Atc \
  "SELECT count(*) FROM \"LiteLLM_SpendLogs\" s WHERE row_to_json(s)::text LIKE '%;base64,%' OR row_to_json(s)::text LIKE '%a blue bicycle%'")
(( rows >= calls )) || fail "4: $rows spend log rows for $calls calls; the check would prove nothing"
(( leaked == 0 )) || fail "4: $leaked spend log rows hold an input"
echo "spend log rows: $rows, holding an input: $leaked"

(( fails == 0 )) || { echo "$fails measurement(s) failed" >&2; exit 1; }
echo "all measurements passed"
```

- [ ] **Step 4: Run the probe**

Run: `infra/probes/litellm-embed/run.sh 2>&1 | tee tmp/probe-litellm-embed.log`
Expected: `all measurements passed`, the two data URL sizes (the big one above 700 kB), `spend after 3 calls: 0.001728`, and one line of what LiteLLM sends upstream besides `input`.

Record that line in the plan 1 hand-off (the reply of this task): if it holds `"encoding_format":"base64"`, `ai`'s `/v1/embeddings` must accept `encoding_format` and either answer base64 or answer floats that LiteLLM accepts (the stub answers floats, so a pass here shows floats are accepted).

What to do when a measurement fails, as the spec says:
- 1 or 2 fails: stop and report to the user with the log. The spec's fallback is a pass-through LiteLLM entry priced per request (`input_cost_per_request`), or a return to the spec; do not pick one alone.
- 4 fails: add `disable_spend_logs: true` under `general_settings` in `config.yaml`, run again, and carry the same setting into the chart in Task 3 (the key's spend still counts; the per-request log rows go). Tell the user, since the admin UI loses its request list.

- [ ] **Step 5: Commit**

```bash
git add infra/probes/litellm-embed
git commit -m "build: a probe of LiteLLM with image inputs, priced from usage"
```

---

### Task 3: LiteLLM aliases and keys as data; the key `server` becomes `server-llm`

The measure of this task: `search` and `stt` render exactly the config they render today, apart from the key's alias and the explicit `store_prompts_in_spend_logs: false`.

**Files:**
- Modify: `infra/stack/values.yaml` (the `litellm:` block)
- Modify: `infra/stack/values-dev.yaml`, `infra/stack/values-prod.yaml` (the `litellm:` blocks)
- Modify: `infra/stack/templates/litellm.yaml`
- Create: `infra/stack/templates/litellm-keys.yaml`
- Modify: `infra/stack/templates/_helpers.tpl` (append two defines)
- Rewrite: `infra/stack/tests/litellm_test.yaml`
- Create: `infra/stack/tests/values-bad-alias.yaml`, `values-mixed-units.yaml`, `values-no-model.yaml`, `values-no-limit.yaml`

**Interfaces:**
- Produces: values shape `litellm.aliases.<name>.{model, apiBase, apiKeySecret?, mode?, price: token|second}` and `litellm.keys.<alias>.{secret, models, dailyUnits, tpmLimit? | rpmLimit?}`; helpers `sn.keyEnv` (`server-llm` → `KEY_SERVER_LLM`) and `sn.keyBody`. Task 7 adds entries to both maps; the docs (Task 10) describe them.

- [ ] **Step 1: Write the failing tests**

Replace `infra/stack/tests/litellm_test.yaml` with:

```yaml
suite: litellm
templates: [litellm.yaml, litellm-keys.yaml, postgres.yaml]
release: { namespace: shopnexus-prod }
tests:
  # The server asks for the alias search; LiteLLM sends it to one model of
  # cli-proxy-api on the host. Budgets count money; at 1e-6 per token, 1 of
  # budget is 1M tokens.
  - it: maps the alias search to the upstream model at 1e-6 a token
    template: litellm.yaml
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - equal: { path: metadata.name, value: litellm-config }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "model_name: search\\n" }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "model: openai/claude-haiku-5-5\\n" }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "api_base: http://host.k3d.internal:8317/v1\\n" }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "api_key: os.environ/LLM_UPSTREAM_API_KEY\\n" }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "input_cost_per_token: 0.000001\\n" }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "output_cost_per_token: 0.000001\\n" }
  # The alias stt sends speech to the stack's ai service. At 1e-6 per second,
  # 1 of budget is 1M seconds of audio.
  - it: maps the alias stt to the ai service at 1e-6 a second
    template: litellm.yaml
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - matchRegex: { path: 'data["config.yaml"]', pattern: "model_name: stt\\n" }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "model: openai/gipformer-1.5\\n" }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "api_base: http://ai:8000/v1\\n      api_key: none" }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "mode: audio_transcription\\n" }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "input_cost_per_second: 0.000001\\n" }
  # A search photo passes through LiteLLM; its spend logs keep no body.
  - it: keeps request bodies out of the spend logs
    template: litellm.yaml
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - matchRegex: { path: 'data["config.yaml"]', pattern: "store_prompts_in_spend_logs: false\\n" }
  - it: runs the pinned image with the upstream key and rolls on a config change
    template: litellm.yaml
    documentIndex: 1
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - isKind: { of: Deployment }
      - equal: { path: spec.template.spec.containers[0].image, value: ghcr.io/berriai/litellm-database:v1.108.0 }
      - exists: { path: 'spec.template.metadata.annotations["checksum/config"]' }
      - contains:
          path: spec.template.spec.containers[0].env
          content:
            name: LLM_UPSTREAM_API_KEY
            valueFrom: { secretKeyRef: { name: litellm-secrets, key: LLM_UPSTREAM_API_KEY } }
  - it: gives prod's server-llm key 2M tokens a day at 100k a minute, after LiteLLM is up
    template: litellm-keys.yaml
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - equal: { path: metadata.name, value: litellm-key }
      - equal: { path: 'metadata.annotations["argocd.argoproj.io/sync-wave"]', value: "3" }
      - contains:
          path: spec.template.spec.containers[0].env
          content:
            name: KEY_SERVER_LLM
            valueFrom: { secretKeyRef: { name: server-secrets, key: LLM_API_KEY } }
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: 'upsert server-llm "\$KEY_SERVER_LLM"' }
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-llm","max_budget":2,"models":\["search"\],"tpm_limit":100000' }
  - it: gives dev's server-llm key 200k tokens a day at 20k a minute
    template: litellm-keys.yaml
    documentIndex: 0
    values: [../values-dev.yaml, values-test.yaml]
    asserts:
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-llm","max_budget":0.2,"models":\["search"\],"tpm_limit":20000' }
  - it: gives prod's server-stt key 10 hours of audio a day at 60 a minute
    template: litellm-keys.yaml
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - contains:
          path: spec.template.spec.containers[0].env
          content:
            name: KEY_SERVER_STT
            valueFrom: { secretKeyRef: { name: server-secrets, key: STT_API_KEY } }
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-stt","max_budget":0.036,"models":\["stt"\],"rpm_limit":60' }
  - it: gives dev's server-stt key 1 hour of audio a day at 10 a minute
    template: litellm-keys.yaml
    documentIndex: 0
    values: [../values-dev.yaml, values-test.yaml]
    asserts:
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-stt","max_budget":0.0036,"models":\["stt"\],"rpm_limit":10' }
  - it: refuses a key that names an alias LiteLLM does not have
    template: litellm-keys.yaml
    values: [../values-prod.yaml, values-test.yaml, values-bad-alias.yaml]
    asserts:
      - failedTemplate: { errorPattern: "litellm.keys.server-stt names the alias nope" }
  - it: refuses a key over aliases priced in different units
    template: litellm-keys.yaml
    values: [../values-prod.yaml, values-test.yaml, values-mixed-units.yaml]
    asserts:
      - failedTemplate: { errorPattern: "litellm.keys.server-stt mixes aliases priced by token and by second" }
  - it: refuses a key with neither tpmLimit nor rpmLimit
    template: litellm-keys.yaml
    values: [../values-prod.yaml, values-test.yaml, values-no-limit.yaml]
    asserts:
      - failedTemplate: { errorPattern: "litellm.keys.server-llm needs tpmLimit or rpmLimit" }
  - it: refuses an alias without a model
    template: litellm.yaml
    values: [../values-prod.yaml, values-test.yaml, values-no-model.yaml]
    asserts:
      - failedTemplate: { errorPattern: "litellm.aliases.search.model is required" }
  - it: gives LiteLLM its own database and a sealed role password
    template: postgres.yaml
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - equal: { path: spec.owner, value: litellm }
        documentIndex: 2
      - equal: { path: 'spec.managed.roles[0].passwordSecret.name', value: litellm-db }
        documentIndex: 1
```

Create the four test value files in `infra/stack/tests/`:

`values-bad-alias.yaml`:
```yaml
litellm:
  keys:
    server-stt: { models: [stt, nope] }
```

`values-mixed-units.yaml`:
```yaml
litellm:
  keys:
    server-stt: { models: [stt, search] }
```

`values-no-limit.yaml`:
```yaml
# null removes the key from the merged values.
litellm:
  keys:
    server-llm: { tpmLimit: null }
```

`values-no-model.yaml`:
```yaml
litellm:
  aliases:
    search: { model: "" }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `helm unittest -f 'tests/litellm_test.yaml' infra/stack`
Expected: FAIL; `litellm-keys.yaml` does not exist and `KEY_SERVER_LLM` is missing.

- [ ] **Step 3: Change the values**

In `infra/stack/values.yaml`, replace the whole `litellm:` block (the comment above it included) with:

```yaml
# The stack's LiteLLM. The server calls it only under the aliases below; the
# model and backend behind each alias are set here, and a new alias or key is
# an edit of this block. Budgets count money: a token and a second of audio
# are each priced at 1e-6, so 1 of budget is 1M tokens or 1M seconds. A key's
# dailyUnits is in the unit of its aliases' price; the chart divides it by 1M
# for max_budget. A key has tpmLimit or rpmLimit.
litellm:
  aliases:
    search:
      model: openai/claude-haiku-5-5
      apiBase: http://host.k3d.internal:8317/v1   # cli-proxy-api on the host
      apiKeySecret: LLM_UPSTREAM_API_KEY          # a key of litellm-secrets
      price: token
    stt:
      model: openai/gipformer-1.5   # LiteLLM's model string, provider prefix included
      apiBase: http://ai:8000/v1
      mode: audio_transcription
      price: second
  keys:
    server-llm: { secret: LLM_API_KEY, models: [search], dailyUnits: 0, tpmLimit: 0 }   # set per stack
    server-stt: { secret: STT_API_KEY, models: [stt], dailyUnits: 0, rpmLimit: 0 }      # set per stack
```

In `infra/stack/values-dev.yaml`, replace the `litellm:` block with:

```yaml
litellm:
  keys:
    server-llm: { dailyUnits: 200000, tpmLimit: 20000 }
    server-stt: { dailyUnits: 3600, rpmLimit: 10 }
```

In `infra/stack/values-prod.yaml`, replace the `litellm:` block with:

```yaml
litellm:
  keys:
    server-llm: { dailyUnits: 2000000, tpmLimit: 100000 }
    server-stt: { dailyUnits: 36000, rpmLimit: 60 }
```

- [ ] **Step 4: Add the helpers**

Append to `infra/stack/templates/_helpers.tpl`:

```yaml
{{/* The env var of the key Job that holds one key's value: server-llm gives
     KEY_SERVER_LLM. */}}
{{- define "sn.keyEnv" -}}
KEY_{{ . | upper | replace "-" "_" }}
{{- end }}

{{/* The JSON body of /key/update and /key/generate for one key, without the
     key's value, which the Job adds at run time. Call with
     (dict "alias" "server-llm" "k" .Values.litellm.keys.server-llm). */}}
{{- define "sn.keyBody" -}}
{{- $k := .k -}}
{{- $units := required (printf "litellm.keys.%s.dailyUnits is required" .alias) $k.dailyUnits -}}
{{- $b := dict "key_alias" .alias "models" $k.models "budget_duration" "1d" "max_budget" (divf $units 1000000) -}}
{{- if hasKey $k "tpmLimit" }}{{ $_ := set $b "tpm_limit" (int $k.tpmLimit) }}{{ end -}}
{{- if hasKey $k "rpmLimit" }}{{ $_ := set $b "rpm_limit" (int $k.rpmLimit) }}{{ end -}}
{{- if not (or (hasKey $k "tpmLimit") (hasKey $k "rpmLimit")) }}{{ fail (printf "litellm.keys.%s needs tpmLimit or rpmLimit" .alias) }}{{ end -}}
{{- toJson $b -}}
{{- end }}
```

- [ ] **Step 5: Rewrite litellm.yaml's config and env, and drop its Job**

In `infra/stack/templates/litellm.yaml`, replace everything from the top through the end of `{{- define "sn.litellmConfig" -}} … {{- end }}` with:

```yaml
{{- /* The stack's LiteLLM: one model_list entry per litellm.aliases, priced so
       budgets count tokens or seconds. Its virtual keys are the Job in
       litellm-keys.yaml. */ -}}
{{- define "sn.litellmConfig" -}}
model_list:
{{- range $name, $a := .Values.litellm.aliases }}
  - model_name: {{ $name }}
    litellm_params:
      model: {{ required (printf "litellm.aliases.%s.model is required" $name) $a.model }}
      api_base: {{ required (printf "litellm.aliases.%s.apiBase is required" $name) $a.apiBase }}
      {{- if $a.apiKeySecret }}
      api_key: os.environ/{{ $a.apiKeySecret }}
      {{- else }}
      api_key: none   # a backend of the stack, which has no authentication
      {{- end }}
    model_info:
      {{- with $a.mode }}
      mode: {{ . }}
      {{- end }}
      {{- if eq $a.price "token" }}
      input_cost_per_token: 0.000001
      output_cost_per_token: 0.000001
      {{- else if eq $a.price "second" }}
      input_cost_per_second: 0.000001
      {{- else }}
      {{- fail (printf "litellm.aliases.%s.price must be token or second" $name) }}
      {{- end }}
{{- end }}
general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
  # A search photo passes through here; the spend logs keep no bodies.
  store_prompts_in_spend_logs: false
litellm_settings:
  drop_params: true
{{- end }}
```

If Task 2 step 4 added `disable_spend_logs: true`, put it under `general_settings` here as well, with the comment `# LiteLLM v1.108.0 kept inputs in the spend logs (infra/probes/litellm-embed).`

In the Deployment's container `env:`, replace the `LLM_UPSTREAM_API_KEY` entry with a loop over the aliases' upstream keys, so the block reads:

```yaml
          env:
            - name: LITELLM_MASTER_KEY
              valueFrom: { secretKeyRef: { name: litellm-secrets, key: LITELLM_MASTER_KEY } }
            {{- $seen := dict }}
            {{- range $name, $a := .Values.litellm.aliases }}
            {{- if and $a.apiKeySecret (not (hasKey $seen $a.apiKeySecret)) }}
            {{- $_ := set $seen $a.apiKeySecret true }}
            - name: {{ $a.apiKeySecret }}
              valueFrom: { secretKeyRef: { name: litellm-secrets, key: {{ $a.apiKeySecret }} } }
            {{- end }}
            {{- end }}
            - name: DB_PASSWORD
              valueFrom: { secretKeyRef: { name: litellm-db, key: password } }
            - name: DATABASE_URL
              value: postgresql://litellm:$(DB_PASSWORD)@postgres-rw:5432/litellm
```

Delete the last document of the file: the comment `# Makes the server's two virtual keys exist …` and the whole `kind: Job` that follows it.

- [ ] **Step 6: Write litellm-keys.yaml**

`infra/stack/templates/litellm-keys.yaml`:

```yaml
{{- /* Makes each key of litellm.keys exist with this stack's budget: updates it
       when it exists, creates it with the sealed value when it does not. A key
       names only aliases of litellm.aliases, all priced in one unit. */ -}}
{{- $aliases := .Values.litellm.aliases }}
{{- range $name, $k := .Values.litellm.keys }}
{{- $prices := dict }}
{{- range $m := (required (printf "litellm.keys.%s.models is required" $name) $k.models) }}
{{- if not (hasKey $aliases $m) }}{{ fail (printf "litellm.keys.%s names the alias %s, which litellm.aliases does not have" $name $m) }}{{ end }}
{{- $_ := set $prices (get (get $aliases $m) "price") true }}
{{- end }}
{{- if gt (len $prices) 1 }}{{ fail (printf "litellm.keys.%s mixes aliases priced by token and by second" $name) }}{{ end }}
{{- end }}
apiVersion: batch/v1
kind: Job
metadata:
  name: litellm-key
  labels: {{- include "sn.labels" . | nindent 4 }}
  annotations:
    argocd.argoproj.io/hook: Sync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
    {{- include "sn.wave" "3" | nindent 4 }}
spec:
  backoffLimit: 10
  template:
    metadata:
      labels: {{- include "sn.podLabels" (dict "root" . "name" "litellm-key") | nindent 8 }}
    spec:
      restartPolicy: OnFailure
      containers:
        - name: litellm-key
          image: {{ include "sn.image" .Values.images.curl }}
          env:
            - name: MASTER_KEY
              valueFrom: { secretKeyRef: { name: litellm-secrets, key: LITELLM_MASTER_KEY } }
            {{- range $name, $k := .Values.litellm.keys }}
            - name: {{ include "sn.keyEnv" $name }}
              valueFrom: { secretKeyRef: { name: server-secrets, key: {{ required (printf "litellm.keys.%s.secret is required" $name) $k.secret }} } }
            {{- end }}
          command: [sh, -ec]
          args:
            - |
              call() { curl -s -o /tmp/out -w '%{http_code}' -X POST "http://litellm:4000/key/$1" \
                -H "Authorization: Bearer $MASTER_KEY" -H 'Content-Type: application/json' -d "$body"; }
              # $1 the key's alias, $2 its value, $3 the body without the value.
              upsert() {
                body="{\"key\":\"$2\",${3#?}"
                code=$(call update)
                if [ "$code" != 200 ]; then code=$(call generate); fi
                # The response holds the key, so only its status is logged.
                echo "litellm key $1: HTTP $code"
                [ "$code" = 200 ] || { grep -o '"message":"[^"]*"' /tmp/out; exit 1; }
              }
              {{- range $name, $k := .Values.litellm.keys }}
              upsert {{ $name }} "${{ include "sn.keyEnv" $name }}" {{ include "sn.keyBody" (dict "alias" $name "k" $k) | squote }}
              {{- end }}
```

- [ ] **Step 7: Run the tests and the whole check**

Run: `helm unittest -f 'tests/litellm_test.yaml' infra/stack && infra/check.sh`
Expected: every litellm test passes, then `all checks passed`.

Then compare the rendered config with the one before this task, to prove `search` and `stt` did not change:

```bash
mkdir -p tmp/litellm-refactor
git stash -- infra/stack
helm template shopnexus infra/stack -f infra/stack/values-prod.yaml --set secretsDir=tests/secrets -s templates/litellm.yaml \
  | yq 'select(.kind=="ConfigMap") | .data["config.yaml"]' >tmp/litellm-refactor/before.yaml
git stash pop
helm template shopnexus infra/stack -f infra/stack/values-prod.yaml --set secretsDir=tests/secrets -s templates/litellm.yaml \
  | yq 'select(.kind=="ConfigMap") | .data["config.yaml"]' >tmp/litellm-refactor/after.yaml
diff <(yq -P 'sort_keys(..)' tmp/litellm-refactor/before.yaml) <(yq -P 'sort_keys(..)' tmp/litellm-refactor/after.yaml)
```

Expected: the only difference is the added `store_prompts_in_spend_logs: false` line (and `disable_spend_logs` if Task 2 needed it).

- [ ] **Step 8: Commit**

```bash
git add infra/stack
git commit -m "refactor: LiteLLM's aliases and keys are chart data; the key server is server-llm"
```

---

### Task 4: The seal command makes the two embed keys

**Files:**
- Modify: `infra/cmd/seal/main.go` (the generated-keys list and the `server-secrets` pick)
- Test: `infra/cmd/seal/main_test.go` (`TestSealKeepsItsKeys`)

**Interfaces:**
- Produces: `server-secrets` holds `EMBED_INDEX_API_KEY` and `EMBED_SEARCH_API_KEY` (`sk-` and 24 random bytes, hex). Task 7's key Job and plan 3's server read them.

- [ ] **Step 1: Write the failing test**

In `TestSealKeepsItsKeys`, change the key list to:

```go
	for _, k := range []string{"JWT_PRIVATE_KEY", "CONSOLE_KEY", "RESTATE_IDENTITY_KEY", "LLM_API_KEY", "STT_API_KEY",
		"EMBED_INDEX_API_KEY", "EMBED_SEARCH_API_KEY", "private.pem", "LITELLM_MASTER_KEY"} {
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go -C infra test ./cmd/seal/ -run TestSealKeepsItsKeys -v`
Expected: FAIL, `no EMBED_INDEX_API_KEY in`. (The test needs Docker and the server image; it skips without Docker. If it skips, run it on a machine with Docker before committing.)

- [ ] **Step 3: Implement**

In `seal`, extend the generated keys:

```go
		{"LLM_API_KEY", "sk-", 24},          // the server's search key in LiteLLM (server-llm)
		{"STT_API_KEY", "sk-", 24},          // the server's speech-to-text key in LiteLLM (server-stt)
		{"EMBED_INDEX_API_KEY", "sk-", 24},  // the server's key for indexing listings (server-embed-index)
		{"EMBED_SEARCH_API_KEY", "sk-", 24}, // the server's key for query embeddings (server-embed-search)
```

and the `server-secrets` pick:

```go
		{name: "server-secrets", namespace: ns, data: env.pick(
			"JWT_KEY_ID", "JWT_PRIVATE_KEY", "CONSOLE_KEY", "RESTATE_IDENTITY_KEY",
			"OBJECT_STORE_ACCESS_KEY", "OBJECT_STORE_SECRET_KEY", "LLM_API_KEY", "STT_API_KEY",
			"EMBED_INDEX_API_KEY", "EMBED_SEARCH_API_KEY", "FCM_CREDENTIALS")},
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `go -C infra test ./cmd/seal/ -v`
Expected: PASS for every test.

- [ ] **Step 5: Commit**

```bash
git add infra/cmd/seal
git commit -m "build: seal makes the server's two embedding keys"
```

Resealing the stacks happens in Task 11, right before the push that needs the keys.

---

### Task 5: TEI serves bge-m3 in the stack

**Files:**
- Create: `infra/stack/templates/tei.yaml`
- Modify: `infra/stack/values.yaml` (`images.tei`, new `tei:` block)
- Test: `infra/stack/tests/tei_test.yaml`
- Modify: `infra/stack/tests/networkpolicy_test.yaml`

**Interfaces:**
- Produces: Service `tei` on port 80 serving `POST /v1/embeddings` (OpenAI's shape, 1024 dimensions, L2-normalized, `usage.prompt_tokens`). Values `tei.revision` (also the source of `EMBED_TEXT_VERSION` in Task 7), `tei.storage` (`""` = emptyDir, else a PVC of that size), `tei.startupSeconds`, `tei.maxClientBatchSize`, `tei.memoryRequest`, `tei.memoryLimit`.

- [ ] **Step 1: Measure TEI with bge-m3 at the pinned revision**

The revision holds `pytorch_model.bin` and `onnx/model.onnx` but no `model.safetensors`, so first check which backend TEI loads and what a cold start costs.

```bash
mkdir -p tmp/tei-measure
docker run --rm -d --name tei-measure -p 127.0.0.1:56592:80 -v "$PWD/tmp/tei-measure:/data" \
  ghcr.io/huggingface/text-embeddings-inference:cpu-1.9.4 \
  --model-id BAAI/bge-m3 --revision 5617a9f61b028005a4858fdac845db406aefb181 --port 80 --auto-truncate --max-client-batch-size 16
start=$(date +%s); until curl -fsS 127.0.0.1:56592/health >/dev/null 2>&1; do sleep 2; done; echo "cold start: $(( $(date +%s) - start )) s"
du -sh tmp/tei-measure
docker logs tei-measure 2>&1 | grep -iE "backend|onnx|safetensors|candle|ort" | head
curl -s 127.0.0.1:56592/v1/embeddings -H 'Content-Type: application/json' \
  -d '{"model":"bge-m3","input":["xe đạp trẻ em","xe cho bé 4 tuổi"]}' \
  | jq '{dims: (.data[0].embedding | length), usage}'
docker stats --no-stream --format '{{.MemUsage}}' tei-measure
docker restart tei-measure; start=$(date +%s); until curl -fsS 127.0.0.1:56592/health >/dev/null 2>&1; do sleep 2; done; echo "warm start: $(( $(date +%s) - start )) s"
docker rm -f tei-measure
```

Expected: `dims: 1024`, a `usage.prompt_tokens` above 0, a cold start, a warm start, the size on disk and the memory in use. If TEI cannot load the revision, stop and report to the user with the log: the spec pins this revision, and a revision with `model.safetensors` (or TEI's ONNX backend) is a decision for them.

Decide, and write the numbers into `tmp/tei-measure/decision.txt`:
- `tei.storage`: `""` (emptyDir) when the cold start is under 120 s, else `5Gi`.
- `tei.startupSeconds`: twice the cold start, rounded up to a multiple of 10 (emptyDir pays the download on every new pod).
- `tei.memoryRequest`: the measured memory rounded up to the next 512 Mi; `tei.memoryLimit`: twice that.

- [ ] **Step 2: Write the failing tests**

`infra/stack/tests/tei_test.yaml`:

```yaml
suite: tei
templates: [tei.yaml]
release: { namespace: shopnexus-prod }
tests:
  - it: serves the pinned bge-m3 on CPU after the data services
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - isKind: { of: Deployment }
      - equal: { path: metadata.name, value: tei }
      - equal: { path: 'metadata.annotations["argocd.argoproj.io/sync-wave"]', value: "2" }
      - equal: { path: spec.strategy.type, value: Recreate }
      - equal: { path: 'spec.template.spec.containers[0].image', value: ghcr.io/huggingface/text-embeddings-inference:cpu-1.9.4 }
      - equal:
          path: spec.template.spec.containers[0].args
          value: [--model-id, BAAI/bge-m3, --revision, 5617a9f61b028005a4858fdac845db406aefb181, --port, "80", --auto-truncate, --max-client-batch-size, "16"]
      - contains:
          path: spec.template.spec.containers[0].env
          content: { name: HUGGINGFACE_HUB_CACHE, value: /data }
      - equal: { path: 'spec.template.spec.containers[0].startupProbe.httpGet.path', value: /health }
      - equal: { path: 'spec.template.spec.containers[0].readinessProbe.httpGet.path', value: /health }
      - equal: { path: 'spec.template.spec.containers[0].livenessProbe.httpGet.path', value: /health }
  - it: is reachable in the stack as tei:80
    documentIndex: 1
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - isKind: { of: Service }
      - equal: { path: metadata.name, value: tei }
      - equal: { path: 'spec.ports[0].port', value: 80 }
  - it: keeps the weights on a claim when tei.storage is set
    values: [../values-prod.yaml, values-test.yaml]
    set: { tei.storage: 5Gi }
    asserts:
      - hasDocuments: { count: 3 }
      - equal: { path: 'spec.template.spec.volumes[0].persistentVolumeClaim.claimName', value: tei-data }
        documentIndex: 0
      - equal: { path: 'spec.resources.requests.storage', value: 5Gi }
        documentIndex: 2
  - it: downloads the weights into an emptyDir when tei.storage is empty
    values: [../values-prod.yaml, values-test.yaml]
    set: { tei.storage: "" }
    asserts:
      - hasDocuments: { count: 2 }
      - exists: { path: 'spec.template.spec.volumes[0].emptyDir' }
        documentIndex: 0
```

Append to `infra/stack/tests/networkpolicy_test.yaml`'s `tests:`:

```yaml
  # TEI is reached through LiteLLM only: from-stack admits it, Traefik does not.
  - it: keeps Traefik away from tei and ai
    documentIndex: 2
    asserts:
      - notContains: { path: 'spec.podSelector.matchExpressions[0].values', content: tei }
      - notContains: { path: 'spec.podSelector.matchExpressions[0].values', content: ai }
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `helm unittest -f 'tests/tei_test.yaml' -f 'tests/networkpolicy_test.yaml' infra/stack`
Expected: tei tests FAIL (no `tei.yaml`); the network policy test passes already, which is right: it guards a property that holds.

- [ ] **Step 4: Add the values**

In `infra/stack/values.yaml`, add under `images:` after `litellm:`:

```yaml
  tei: { repository: ghcr.io/huggingface/text-embeddings-inference, tag: cpu-1.9.4 }
```

and a block after `ai:` (numbers from step 1's `decision.txt`; the ones shown are the shape, replace each with the measured value):

```yaml
# Text embeddings for LiteLLM's alias embed-text: Hugging Face's Text
# Embeddings Inference on CPU, serving BAAI/bge-m3 at a pinned revision. The
# server stores bge-m3@<revision> with every vector, so a new revision means
# a reindex. storage "" downloads the weights into an emptyDir on every new
# pod; a size keeps them on a claim. Numbers measured on 2026-11-09 (plan
# 2026-11-09-search-models-infra, task 5).
tei:
  revision: 5617a9f61b028005a4858fdac845db406aefb181
  maxClientBatchSize: 16
  storage: ""          # from the measurement
  startupSeconds: 240  # from the measurement
  memoryRequest: 3Gi   # from the measurement
  memoryLimit: 6Gi     # from the measurement
```

- [ ] **Step 5: Write tei.yaml**

`infra/stack/templates/tei.yaml`:

```yaml
{{- /* Text embeddings for LiteLLM's alias embed-text: Text Embeddings Inference
       on CPU, serving BAAI/bge-m3 at a pinned revision. from-stack lets
       LiteLLM in; it has no Ingress. */ -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tei
  labels: {{- include "sn.labels" . | nindent 4 }}
  annotations: {{- include "sn.wave" "2" | nindent 4 }}
spec:
  replicas: 1
  # A claim mounts on one node at a time.
  strategy: { type: Recreate }
  selector:
    matchLabels: { app.kubernetes.io/name: tei }
  template:
    metadata:
      labels: {{- include "sn.podLabels" (dict "root" . "name" "tei") | nindent 8 }}
    spec:
      affinity:
        {{- include "sn.preferRole" "app" | nindent 8 }}
      containers:
        - name: tei
          image: {{ include "sn.image" .Values.images.tei }}
          args:
            - --model-id
            - BAAI/bge-m3
            - --revision
            - {{ required "tei.revision is required" .Values.tei.revision }}
            - --port
            - "80"
            - --auto-truncate
            - --max-client-batch-size
            - {{ required "tei.maxClientBatchSize is required" .Values.tei.maxClientBatchSize | toString | quote }}
          env:
            - { name: HUGGINGFACE_HUB_CACHE, value: /data }
          ports:
            - { name: http, containerPort: 80 }
          # The first start downloads the weights.
          startupProbe:
            httpGet: { path: /health, port: http }
            periodSeconds: 10
            failureThreshold: {{ div (required "tei.startupSeconds is required" .Values.tei.startupSeconds) 10 }}
          readinessProbe:
            httpGet: { path: /health, port: http }
            periodSeconds: 10
          livenessProbe:
            httpGet: { path: /health, port: http }
            periodSeconds: 30
          volumeMounts:
            - { name: data, mountPath: /data }
          resources:
            requests: { cpu: "1", memory: {{ required "tei.memoryRequest is required" .Values.tei.memoryRequest }} }
            limits: { memory: {{ required "tei.memoryLimit is required" .Values.tei.memoryLimit }} }
      volumes:
        - name: data
          {{- if .Values.tei.storage }}
          persistentVolumeClaim: { claimName: tei-data }
          {{- else }}
          emptyDir: {}
          {{- end }}
---
apiVersion: v1
kind: Service
metadata:
  name: tei
  labels: {{- include "sn.labels" . | nindent 4 }}
spec:
  selector: { app.kubernetes.io/name: tei }
  ports:
    - { name: http, port: 80, targetPort: http }
{{- if .Values.tei.storage }}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tei-data
  labels: {{- include "sn.labels" . | nindent 4 }}
  annotations: {{- include "sn.wave" "0" | nindent 4 }}
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests: { storage: {{ .Values.tei.storage }} }
{{- end }}
```

- [ ] **Step 6: Run tests and the check**

Run: `helm unittest -f 'tests/tei_test.yaml' infra/stack && infra/check.sh`
Expected: PASS, then `all checks passed`.

- [ ] **Step 7: Commit**

```bash
git add infra/stack
git commit -m "build: TEI serves bge-m3 in each stack"
```

---

### Task 6: `ai` gets its embedding settings and memory for SigLIP 2

**Files:**
- Modify: `infra/stack/templates/ai.yaml`
- Modify: `infra/stack/values.yaml` (the `ai:` block)
- Test: `infra/stack/tests/ai_test.yaml`

**Interfaces:**
- Consumes: plan 1's `AI_EMBED_*` variables and the model directory `/models/siglip2-so400m-patch16-384` baked into the `ai` image; plan 1's measurement picks int8 (~1.15 GB on disk) or fp32 (~4.5 GB).
- Produces: values `ai.embedMaxInputs`, `ai.embedMaxConcurrent`, `ai.embedMaxImageMB`, `ai.memoryRequest`, `ai.memoryLimit`, `ai.startupSeconds`, `ai.embedVersion` (read by Task 7).

- [ ] **Step 1: Write the failing tests**

In `infra/stack/tests/ai_test.yaml`, add to the first test's `asserts:`:

```yaml
      - contains:
          path: spec.template.spec.containers[0].env
          content: { name: AI_EMBED_MODELS, value: siglip2-so400m-patch16-384=/models/siglip2-so400m-patch16-384 }
      - contains:
          path: spec.template.spec.containers[0].env
          content: { name: AI_EMBED_MAX_INPUTS, value: "16" }
      - contains:
          path: spec.template.spec.containers[0].env
          content: { name: AI_EMBED_MAX_CONCURRENT, value: "2" }
      - contains:
          path: spec.template.spec.containers[0].env
          content: { name: AI_EMBED_MAX_IMAGE_MB, value: "10" }
      - equal: { path: 'spec.template.spec.containers[0].resources.requests.memory', value: 2Gi }
      - equal: { path: 'spec.template.spec.containers[0].resources.limits.memory', value: 4Gi }
      - equal: { path: 'spec.template.spec.containers[0].startupProbe.failureThreshold', value: 90 }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `helm unittest -f 'tests/ai_test.yaml' infra/stack`
Expected: FAIL on `AI_EMBED_MODELS`.

- [ ] **Step 3: Implement**

Replace the `ai:` block of `infra/stack/values.yaml` with:

```yaml
# The stack's provider of self-hosted models (repo shopnexus/ai). LiteLLM's
# aliases stt and embed-image call it; nothing outside the stack reaches it.
# Memory: Gipformer and the idle process take about 1 GiB; SigLIP 2 adds about
# 1.15 GB in int8 or 4.5 GB in fp32 (plan 1 measures which runs). For fp32 set
# memoryRequest 6Gi and memoryLimit 8Gi. embedVersion names the SigLIP 2 the
# image carries; the server stores it with every photo vector, so a new one
# means a reindex.
ai:
  numThreads: 4
  maxConcurrent: 2
  maxUploadMB: 100
  maxAudioSeconds: 300
  embedMaxInputs: 16
  embedMaxConcurrent: 2
  embedMaxImageMB: 10
  embedVersion: siglip2-so400m-patch16-384@29f74e673c298fd07482d8e20138179282001eb7-int8
  memoryRequest: 2Gi
  memoryLimit: 4Gi
  startupSeconds: 180
```

If plan 1 chose fp32, set `embedVersion` to end in `-fp32`, `memoryRequest: 6Gi`, `memoryLimit: 8Gi`.

In `infra/stack/templates/ai.yaml`, add after the `AI_MAX_AUDIO_SECONDS` entry:

```yaml
            - { name: AI_EMBED_MODELS, value: siglip2-so400m-patch16-384=/models/siglip2-so400m-patch16-384 }
            - { name: AI_EMBED_MAX_INPUTS, value: {{ required "ai.embedMaxInputs is required" .Values.ai.embedMaxInputs | toString | quote }} }
            - { name: AI_EMBED_MAX_CONCURRENT, value: {{ required "ai.embedMaxConcurrent is required" .Values.ai.embedMaxConcurrent | toString | quote }} }
            - { name: AI_EMBED_MAX_IMAGE_MB, value: {{ required "ai.embedMaxImageMB is required" .Values.ai.embedMaxImageMB | toString | quote }} }
```

Change the startup probe's comment and threshold to:

```yaml
          # Loading the models takes seconds to a minute, and the server listens after it.
          startupProbe:
            httpGet: { path: /readyz, port: http }
            periodSeconds: 2
            failureThreshold: {{ div (required "ai.startupSeconds is required" .Values.ai.startupSeconds) 2 }}
```

and the resources to:

```yaml
          resources:
            requests: { cpu: "1", memory: {{ required "ai.memoryRequest is required" .Values.ai.memoryRequest }} }
            limits: { memory: {{ required "ai.memoryLimit is required" .Values.ai.memoryLimit }} }
```

Update the file's top comment to: `The stack's provider of self-hosted models (repo shopnexus/ai). LiteLLM's aliases stt and embed-image call it; from-stack lets LiteLLM in, and it has no Ingress.`

- [ ] **Step 4: Run tests and the check**

Run: `helm unittest -f 'tests/ai_test.yaml' infra/stack && infra/check.sh`
Expected: PASS, then `all checks passed`.

- [ ] **Step 5: Commit**

```bash
git add infra/stack
git commit -m "build: ai embeds photos with SigLIP 2 and gets the memory for it"
```

---

### Task 7: The embed aliases, their keys and the server's EMBED_* settings

**Files:**
- Modify: `infra/stack/values.yaml` (`litellm.aliases`, `litellm.keys`, `server.embed`)
- Modify: `infra/stack/values-dev.yaml`, `infra/stack/values-prod.yaml` (`litellm.keys`)
- Modify: `infra/stack/templates/_server-env.tpl`
- Modify: `infra/stack/tests/litellm_test.yaml`, `infra/stack/tests/server_env_test.yaml`
- Create: `infra/stack/tests/values-one-key.yaml`

**Interfaces:**
- Consumes: Task 3's maps and helpers, Task 4's secrets, Task 5's `tei.revision`, Task 6's `ai.embedVersion`.
- Produces for plan 3 (server config), as strings in `server-env`: `EMBED_TEXT_BASE_URL`, `EMBED_IMAGE_BASE_URL` (URLs ending in `/v1`), `EMBED_TEXT_MODEL`, `EMBED_IMAGE_MODEL`, `EMBED_TEXT_VERSION` (`bge-m3@<revision>`), `EMBED_IMAGE_VERSION`, `EMBED_TIMEOUT` (a Go duration such as `15s`), `EMBED_SLOTS` (a positive integer), `EMBED_TEXT_MIN_SIMILARITY` and `EMBED_PHOTO_MIN_SIMILARITY` (decimal cosines such as `0.45`); `EMBED_INDEX_API_KEY` and `EMBED_SEARCH_API_KEY` from `server-secrets`.

- [ ] **Step 1: Write the failing tests**

Append to `infra/stack/tests/litellm_test.yaml`'s `tests:`:

```yaml
  # embed-text goes to the stack's TEI, embed-image to ai; both priced per
  # token, ai counting 576 tokens an image.
  - it: maps embed-text to TEI and embed-image to ai at 1e-6 a token
    template: litellm.yaml
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - matchRegex: { path: 'data["config.yaml"]', pattern: "model_name: embed-text\\n    litellm_params:\\n      model: openai/bge-m3\\n      api_base: http://tei:80/v1\\n      api_key: none" }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "model_name: embed-image\\n    litellm_params:\\n      model: openai/siglip2-so400m-patch16-384\\n      api_base: http://ai:8000/v1\\n      api_key: none" }
      - matchRegex: { path: 'data["config.yaml"]', pattern: "mode: embedding\\n      input_cost_per_token: 0.000001" }
  - it: gives prod's embed keys their budgets, index apart from search
    template: litellm-keys.yaml
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - contains:
          path: spec.template.spec.containers[0].env
          content:
            name: KEY_SERVER_EMBED_INDEX
            valueFrom: { secretKeyRef: { name: server-secrets, key: EMBED_INDEX_API_KEY } }
      - contains:
          path: spec.template.spec.containers[0].env
          content:
            name: KEY_SERVER_EMBED_SEARCH
            valueFrom: { secretKeyRef: { name: server-secrets, key: EMBED_SEARCH_API_KEY } }
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-embed-index","max_budget":50,"models":\["embed-text","embed-image"\],"rpm_limit":600' }
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-embed-search","max_budget":10,"models":\["embed-text","embed-image"\],"rpm_limit":600' }
  - it: gives dev's embed keys their budgets
    template: litellm-keys.yaml
    documentIndex: 0
    values: [../values-dev.yaml, values-test.yaml]
    asserts:
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-embed-index","max_budget":10,"models":\["embed-text","embed-image"\],"rpm_limit":120' }
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-embed-search","max_budget":1,"models":\["embed-text","embed-image"\],"rpm_limit":60' }
  # Helm merges a stack file into values.yaml key by key.
  - it: leaves the other keys alone when a stack file sets one
    template: litellm-keys.yaml
    documentIndex: 0
    values: [../values-dev.yaml, values-test.yaml, values-one-key.yaml]
    asserts:
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-embed-index","max_budget":0.5,' }
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-stt","max_budget":0.0036,"models":\["stt"\],"rpm_limit":10' }
      - matchRegex: { path: 'spec.template.spec.containers[0].args[0]', pattern: '"key_alias":"server-llm","max_budget":0.2,"models":\["search"\],"tpm_limit":20000' }
```

`infra/stack/tests/values-one-key.yaml`:

```yaml
litellm:
  keys:
    server-embed-index: { dailyUnits: 500000 }
```

Append to `infra/stack/tests/server_env_test.yaml`'s `tests:`:

```yaml
  # The server reaches the embedding models only through LiteLLM, under two
  # aliases, and stores each model's version with its vectors.
  - it: sets the embedding settings
    documentIndex: 0
    values: [../values-prod.yaml, values-test.yaml]
    asserts:
      - equal: { path: data.EMBED_TEXT_BASE_URL, value: http://litellm:4000/v1 }
      - equal: { path: data.EMBED_IMAGE_BASE_URL, value: http://litellm:4000/v1 }
      - equal: { path: data.EMBED_TEXT_MODEL, value: embed-text }
      - equal: { path: data.EMBED_IMAGE_MODEL, value: embed-image }
      - equal: { path: data.EMBED_TEXT_VERSION, value: bge-m3@5617a9f61b028005a4858fdac845db406aefb181 }
      - equal: { path: data.EMBED_IMAGE_VERSION, value: siglip2-so400m-patch16-384@29f74e673c298fd07482d8e20138179282001eb7-int8 }
      - equal: { path: data.EMBED_TIMEOUT, value: 15s }
      - equal: { path: data.EMBED_SLOTS, value: "2" }
      - equal: { path: data.EMBED_TEXT_MIN_SIMILARITY, value: "0.45" }
      - equal: { path: data.EMBED_PHOTO_MIN_SIMILARITY, value: "0.6" }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `helm unittest -f 'tests/litellm_test.yaml' -f 'tests/server_env_test.yaml' infra/stack`
Expected: FAIL; no `embed-text` alias, no `EMBED_*` data.

- [ ] **Step 3: Implement the values**

In `infra/stack/values.yaml`, add to `litellm.aliases` after `stt`:

```yaml
    embed-text:
      model: openai/bge-m3   # TEI serves one model and ignores the name
      apiBase: http://tei:80/v1
      mode: embedding
      price: token
    embed-image:
      model: openai/siglip2-so400m-patch16-384
      apiBase: http://ai:8000/v1
      mode: embedding
      price: token   # ai counts 576 tokens an image, a text its tokens
```

and to `litellm.keys` (two keys, so a backfill cannot spend what searches need):

```yaml
    server-embed-index: { secret: EMBED_INDEX_API_KEY, models: [embed-text, embed-image], dailyUnits: 0, rpmLimit: 0 }    # set per stack
    server-embed-search: { secret: EMBED_SEARCH_API_KEY, models: [embed-text, embed-image], dailyUnits: 0, rpmLimit: 0 }  # set per stack
```

Add under `server:` in `values.yaml` (the floors and timeout are starting values; the server's `make search-eval` tunes the floors):

```yaml
  # The server's embedding settings; the aliases and the versions come from
  # litellm, tei and ai. The similarity floors are starting values that the
  # server's search eval tunes.
  embed:
    timeout: 15s
    slots: 2
    textMinSimilarity: "0.45"
    photoMinSimilarity: "0.6"
```

In `values-dev.yaml`, extend `litellm.keys` with:

```yaml
    # 10M tokens: about 1,700 listings of 10 photos a day at 576 tokens a photo.
    server-embed-index: { dailyUnits: 10000000, rpmLimit: 120 }
    server-embed-search: { dailyUnits: 1000000, rpmLimit: 60 }
```

In `values-prod.yaml`:

```yaml
    server-embed-index: { dailyUnits: 50000000, rpmLimit: 600 }
    server-embed-search: { dailyUnits: 10000000, rpmLimit: 600 }
```

- [ ] **Step 4: Implement the server env**

In `infra/stack/templates/_server-env.tpl`, add after `LLM_MODEL: search`:

```yaml
EMBED_TEXT_BASE_URL: http://litellm:4000/v1
EMBED_IMAGE_BASE_URL: http://litellm:4000/v1
EMBED_TEXT_MODEL: embed-text
EMBED_IMAGE_MODEL: embed-image
EMBED_TEXT_VERSION: {{ printf "bge-m3@%s" (required "tei.revision is required" .Values.tei.revision) | quote }}
EMBED_IMAGE_VERSION: {{ required "ai.embedVersion is required" .Values.ai.embedVersion | quote }}
EMBED_TIMEOUT: {{ required "server.embed.timeout is required" .Values.server.embed.timeout | quote }}
EMBED_SLOTS: {{ required "server.embed.slots is required" .Values.server.embed.slots | toString | quote }}
EMBED_TEXT_MIN_SIMILARITY: {{ required "server.embed.textMinSimilarity is required" .Values.server.embed.textMinSimilarity | quote }}
EMBED_PHOTO_MIN_SIMILARITY: {{ required "server.embed.photoMinSimilarity is required" .Values.server.embed.photoMinSimilarity | quote }}
```

`values-dev.yaml` and `values-prod.yaml` each define their own `server:` block; Helm merges it with `values.yaml`, so `server.embed` from `values.yaml` stays. The test `sets the embedding settings` proves it for prod.

- [ ] **Step 5: Run tests and the check**

Run: `helm unittest infra/stack && infra/check.sh`
Expected: every suite passes, then `all checks passed`.

- [ ] **Step 6: Commit**

```bash
git add infra/stack
git commit -m "build: LiteLLM's embed-text and embed-image with an index key and a search key"
```

Do not push yet: the key Job needs the resealed secrets (Task 11).

---

### Task 8: Local stacks run TEI and pass the embedding settings

**Files:**
- Modify: `docker-compose.yml` (header comment, `x-ai`, new `x-tei`, `x-server-env`, `x-server-env-dev`, `x-server-env-prod`, services `tei-dev`, `tei-prod`, volumes)
- Modify: `infra/check.sh` (the local compose section)

**Interfaces:**
- Consumes: the chart's `images.tei`, `tei.revision`, `ai.embedVersion`.
- Produces for plan 3's local runs: in the dev stack the server calls `http://tei-dev:80/v1` with model `bge-m3` and `http://ai-dev:8000/v1` with model `siglip2-so400m-patch16-384`, keys `""`; the prod stack the same with `-prod`. TEI is on `127.0.0.1:56493` (dev) and `127.0.0.1:56492` (prod) for manual calls.

- [ ] **Step 1: Write the failing checks**

In `infra/check.sh`, extend the `── local compose ──` section after the existing loop:

```bash
# TEI and the embedding versions the local server stores follow the chart.
eq "$(yq '.x-tei.image' ../docker-compose.yml)" "$(yq '.images.tei.repository + ":" + .images.tei.tag' stack/values.yaml)" "compose tei image"
eq "$(yq '.x-tei.command[3]' ../docker-compose.yml)" "$(yq '.tei.revision' stack/values.yaml)" "compose tei revision"
eq "$(yq '.x-server-env.EMBED_TEXT_VERSION' ../docker-compose.yml)" "bge-m3@$(yq '.tei.revision' stack/values.yaml)" "compose EMBED_TEXT_VERSION"
eq "$(yq '.x-server-env.EMBED_IMAGE_VERSION' ../docker-compose.yml)" "$(yq '.ai.embedVersion' stack/values.yaml)" "compose EMBED_IMAGE_VERSION"
for k in EMBED_MAX_INPUTS:embedMaxInputs EMBED_MAX_CONCURRENT:embedMaxConcurrent EMBED_MAX_IMAGE_MB:embedMaxImageMB; do
  eq "$(yq ".x-ai.environment.AI_${k%%:*}" ../docker-compose.yml)" "$(yq ".ai.${k#*:}" stack/values.yaml)" "compose AI_${k%%:*}"
done
```

- [ ] **Step 2: Run the check to verify it fails**

Run: `infra/check.sh`
Expected: FAIL lines for `compose tei image`, `compose tei revision`, `compose EMBED_TEXT_VERSION`, `compose EMBED_IMAGE_VERSION` and the three `AI_EMBED_*`.

- [ ] **Step 3: Change docker-compose.yml**

In the header's host table, add the line after `ai`:

```
#   tei        http://127.0.0.1:56493                     http://127.0.0.1:56492
```

and replace the paragraph `The server needs an OpenAI-compatible API for search …` with:

```
# The server needs an OpenAI-compatible API for search in dev and prod:
# LLM_BASE_URL, LLM_API_KEY and LLM_MODEL, read from server/.env (the Makefile
# passes --env-file server/.env). It calls the stack's TEI and ai directly for
# embeddings, as it calls the upstream LLM; in the cluster both sit behind
# LiteLLM.
```

Add to `x-ai.environment` after `AI_MAX_AUDIO_SECONDS`:

```yaml
    AI_EMBED_MODELS: siglip2-so400m-patch16-384=/models/siglip2-so400m-patch16-384
    AI_EMBED_MAX_INPUTS: "16"
    AI_EMBED_MAX_CONCURRENT: "2"
    AI_EMBED_MAX_IMAGE_MB: "10"
```

Add a block after `x-ai`:

```yaml
# Text embeddings (bge-m3) for the server, as the alias embed-text gives the
# cluster. The weights download into the stack's tei volume on first start.
x-tei: &tei
  image: ghcr.io/huggingface/text-embeddings-inference:cpu-1.9.4
  command: [--model-id, BAAI/bge-m3, --revision, 5617a9f61b028005a4858fdac845db406aefb181, --port, "80", --auto-truncate, --max-client-batch-size, "16"]
  environment:
    HUGGINGFACE_HUB_CACHE: /data
  restart: unless-stopped
```

Add to `x-server-env` after `LLM_MODEL`:

```yaml
  EMBED_TEXT_VERSION: bge-m3@5617a9f61b028005a4858fdac845db406aefb181
  EMBED_IMAGE_VERSION: siglip2-so400m-patch16-384@29f74e673c298fd07482d8e20138179282001eb7-int8
  # TEI serves one model and ignores the name; ai checks it.
  EMBED_TEXT_MODEL: bge-m3
  EMBED_IMAGE_MODEL: siglip2-so400m-patch16-384
  # TEI and ai have no keys locally.
  EMBED_INDEX_API_KEY: ""
  EMBED_SEARCH_API_KEY: ""
  EMBED_TIMEOUT: 15s
  EMBED_SLOTS: "2"
  EMBED_TEXT_MIN_SIMILARITY: "0.45"
  EMBED_PHOTO_MIN_SIMILARITY: "0.6"
```

Add to `x-server-env-dev`:

```yaml
  EMBED_TEXT_BASE_URL: http://tei-dev:80/v1
  EMBED_IMAGE_BASE_URL: http://ai-dev:8000/v1
```

and to `x-server-env-prod`:

```yaml
  EMBED_TEXT_BASE_URL: http://tei-prod:80/v1
  EMBED_IMAGE_BASE_URL: http://ai-prod:8000/v1
```

Add services next to `ai-dev` and `ai-prod`:

```yaml
  tei-dev:
    <<: [*dev, *tei]
    ports: ["127.0.0.1:56493:80"]
    volumes: [tei-dev:/data]
```

```yaml
  tei-prod:
    <<: [*prod, *tei]
    ports: ["127.0.0.1:56492:80"]
    volumes: [tei-prod:/data]
```

and `tei-dev:` and `tei-prod:` to the top-level `volumes:` list, next to the other per-stack volumes. If plan 1 chose fp32, `EMBED_IMAGE_VERSION` ends in `-fp32` here as in the chart (the check enforces it).

- [ ] **Step 4: Run the check and a local call**

Run: `infra/check.sh && docker compose config --profile dev >/dev/null && docker compose --profile dev up -d tei-dev && until curl -fsS 127.0.0.1:56493/health >/dev/null 2>&1; do sleep 2; done && curl -s 127.0.0.1:56493/v1/embeddings -H 'Content-Type: application/json' -d '{"model":"bge-m3","input":["xe đạp"]}' | jq '.data[0].embedding | length'`
Expected: `all checks passed`, then `1024`. Stop it with `docker compose --profile dev stop tei-dev`.

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml infra/check.sh
git commit -m "build: the local stacks run TEI and give the server its embedding settings"
```

---

### Task 9: A smoke test of every alias of a running stack

LiteLLM has no Ingress, so `infra/smoke.hurl`, which requests public hosts only, cannot reach it. A second file runs through a port-forward with the server's own keys.

**Files:**
- Create: `infra/smoke-models.hurl`
- Create: `infra/smoke-models.sh`

**Interfaces:**
- Consumes: Task 1's `sample`; the keys in `server-secrets`.
- Produces: `infra/smoke-models.sh dev|prod`, exit 0 when `search`, `stt`, `embed-text` and `embed-image` answer with their keys and a key is refused another key's alias.

- [ ] **Step 1: Write smoke-models.hurl**

```hurl
# Calls every LiteLLM alias of one stack with the server's keys. Run it
# through infra/smoke-models.sh, which port-forwards LiteLLM and reads the keys.

# search: the model reads a query.
POST {{litellm}}/v1/chat/completions
Authorization: Bearer {{llm_key}}
{"model": "search", "messages": [{"role": "user", "content": "Reply with the word ok."}], "max_tokens": 5}
HTTP 200

# stt: a silent clip gives empty text.
POST {{litellm}}/v1/audio/transcriptions
Authorization: Bearer {{stt_key}}
[MultipartFormData]
model: stt
file: file,silence.wav; audio/wav
HTTP 200
[Asserts]
jsonpath "$.text" == ""

# embed-text with the search key: bge-m3, 1024 dimensions.
POST {{litellm}}/v1/embeddings
Authorization: Bearer {{embed_search_key}}
{"model": "embed-text", "input": ["xe đạp trẻ em"]}
HTTP 200
[Asserts]
jsonpath "$.data[0].embedding" count == 1024

# embed-image with the search key, a photo: SigLIP 2, 1152 dimensions.
POST {{litellm}}/v1/embeddings
Authorization: Bearer {{embed_search_key}}
{"model": "embed-image", "input": ["{{photo}}"]}
HTTP 200
[Asserts]
jsonpath "$.data[0].embedding" count == 1152

# embed-image with the index key, a text for the text tower.
POST {{litellm}}/v1/embeddings
Authorization: Bearer {{embed_index_key}}
{"model": "embed-image", "input": ["a blue bicycle"]}
HTTP 200
[Asserts]
jsonpath "$.data[0].embedding" count == 1152

# A key reaches only its own aliases.
POST {{litellm}}/v1/embeddings
Authorization: Bearer {{llm_key}}
{"model": "embed-text", "input": ["x"]}
HTTP 403
```

- [ ] **Step 2: Write smoke-models.sh** (mode 755)

```bash
#!/usr/bin/env bash
# Calls every LiteLLM alias of one stack through a port-forward, with the
# server's keys from server-secrets:
#
#   infra/smoke-models.sh dev|prod
set -euo pipefail
stack=${1:?dev or prod}
here=$(cd "$(dirname "$0")" && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
ns=shopnexus-$stack
work="$root/tmp/smoke-models-$stack"
mkdir -p "$work"

kubectl -n "$ns" port-forward svc/litellm 56598:4000 >"$work/port-forward.log" 2>&1 &
pf=$!
trap 'kill $pf 2>/dev/null || true' EXIT
for _ in $(seq 30); do curl -fsS 127.0.0.1:56598/health/readiness >/dev/null 2>&1 && break; sleep 1; done

key() { kubectl -n "$ns" get secret server-secrets -o jsonpath="{.data.$1}" | base64 -d; }
go -C "$root/infra" run ./probes/sample wav 1 "$work/silence.wav"
hurl --test --file-root "$work" \
  --variable litellm=http://127.0.0.1:56598 \
  --secret llm_key="$(key LLM_API_KEY)" \
  --secret stt_key="$(key STT_API_KEY)" \
  --secret embed_index_key="$(key EMBED_INDEX_API_KEY)" \
  --secret embed_search_key="$(key EMBED_SEARCH_API_KEY)" \
  --variable photo="$(go -C "$root/infra" run ./probes/sample jpeg 256 | tr -d '\n')" \
  "$here/smoke-models.hurl"
```

`--secret` keeps the keys out of hurl's output. If the installed hurl is older than the release that added `--secret`, use `--variable` and say so in the commit message.

- [ ] **Step 3: Check the files parse**

Run: `bash -n infra/smoke-models.sh && hurl --version && hurl --test --variable litellm=http://127.0.0.1:9 --variable llm_key=x --variable stt_key=x --variable embed_index_key=x --variable embed_search_key=x --variable photo=x --file-root tmp infra/smoke-models.hurl 2>&1 | head -5`
Expected: no syntax error from bash; hurl fails on the connection (port 9), not on parsing. The real run is Task 11.

- [ ] **Step 4: Commit**

```bash
git add infra/smoke-models.hurl infra/smoke-models.sh
git commit -m "build: a smoke test of every LiteLLM alias of a stack"
```

---

### Task 10: Docs for the aliases as data, the embed aliases, TEI and the keys

**Files:**
- Modify: `docs/web/src/content/docs/en/operations/cluster/llm-gateway.mdx`
- Modify: `docs/web/src/content/docs/vi/operations/cluster/llm-gateway.mdx`
- Modify: `docs/web/src/content/docs/en/operations/cluster/secrets.mdx`, `docs/web/src/content/docs/vi/operations/cluster/secrets.mdx`
- Modify: `docs/web/src/content/docs/en/operations/cluster/index.mdx`, `docs/web/src/content/docs/vi/operations/cluster/index.mdx`

**Interfaces:**
- Consumes: the facts of Tasks 2 to 9 and the numbers measured in Tasks 2 and 5.

- [ ] **Step 1: Update llm-gateway.mdx (en)**

Make these changes, keeping the page's structure and voice:
- `description` and the opening: the server knows four names, `search`, `stt`, `embed-text` and `embed-image`.
- "Request path": add a mermaid flowchart titled `Embeddings, from the server to TEI and ai`: `server` → `litellm:4000` (alias `embed-text` / `embed-image`, key `server-embed-index` or `server-embed-search`) → `tei:80` (bge-m3) and `ai:8000` (SigLIP 2). Add the `EMBED_*` lines of `server-env`.
- Replace the config listing with the `litellm.aliases` and `litellm.keys` blocks of `values.yaml` as Task 7 leaves them, and say that `templates/litellm.yaml` renders `model_list` from `litellm.aliases`, and that `store_prompts_in_spend_logs: false` keeps request bodies out of the spend logs (with the measurement of Task 2: `infra/probes/litellm-embed/run.sh`).
- "Budget model": the table lists all four keys with dev and prod `dailyUnits` and limits; explain why indexing and search have separate keys (a backfill cannot spend what searches need) and that an image costs 576 tokens.
- "The key hook": the Job loops over `litellm.keys`; the key `server` was renamed `server-llm` on 2026-11-09 with the same value, so `/key/update` renamed it; the log lines are `litellm key server-llm: HTTP 200` and so on for the four keys.
- Replace "Add another model alias" with: add an entry to `litellm.aliases`, add its name to a key's `models` (or a new entry to `litellm.keys` and its secret to the seal command), run `infra/check.sh`. The chart refuses a key that names a missing alias or mixes token- and second-priced aliases.
- "Change the model or the provider": set `litellm.aliases.search.model` (provider prefix included) and `apiBase`.
- New section "Embeddings: TEI and ai": TEI's image, bge-m3's revision, `tei.storage` and the measured cold start, memory; `ai`'s `/v1/embeddings`, `ai.embedVersion`; why a new revision or model needs a new version and a reindex (`cmd/search-reindex` in the server); `infra/smoke-models.sh <stack>`.
- `KeyRules`: replace `The server calls only the alias search` with `The server calls only aliases of litellm.aliases`; keep the others, with `server-llm` for the key.
- `updated: 2026-11-09` (or the day of the change).

- [ ] **Step 2: Mirror the changes in the vi page**

`docs/web/src/content/docs/vi/operations/cluster/llm-gateway.mdx` gets the same sections in Vietnamese, with diacritics, code and commands identical to the en page.

- [ ] **Step 3: Update secrets.mdx and index.mdx (en and vi)**

- `secrets.mdx`: add rows for `EMBED_INDEX_API_KEY` and `EMBED_SEARCH_API_KEY` (`sk-` and 24 random bytes, hex; `server-secrets`; the server, and the `litellm-key` Job registers them as `server-embed-index` and `server-embed-search`), and change the `LLM_API_KEY` row's "the server's virtual key" to "the server's key `server-llm`".
- `index.mdx`: the `litellm-key` row reads `creates or updates the server's LiteLLM virtual keys, one per entry of litellm.keys`.

- [ ] **Step 4: Run the humanizing-writing skill**

Invoke the `humanizing-writing` skill on the changed prose of the six files and run its checker on each en page; fix what it reports. Apply the same fixes to the vi pages.

- [ ] **Step 5: Build the docs**

Run: `cd docs/web && bun install --frozen-lockfile && bun run check && bun run build`
Expected: both finish without errors.

- [ ] **Step 6: Commit (docs submodule, then the umbrella)**

```bash
git -C docs add web/src/content/docs
git -C docs commit -m "docs: LiteLLM's aliases as data, the embedding aliases, TEI and the keys"
git add docs
git commit -m "chore: docs at the embedding aliases"
```

---

### Task 11: Roll out to dev and check the live stack

Pushing to `main` deploys through Argo CD, so ask the user before the push in step 2. Plan 1's `ai` image with `/v1/embeddings` must already be on `:main`; without it `embed-image` answers 404 and step 4 fails on those calls only.

**Files:**
- Modify: `infra/stack/secrets/dev/*.yaml`, `infra/stack/secrets/prod/*.yaml` (resealed)

- [ ] **Step 1: Reseal both stacks**

Run: `go -C infra run ./cmd/seal dev && go -C infra run ./cmd/seal prod`
Expected: `sealed into …/stack/secrets/dev; commit and push`, and the same for prod. `git diff --stat infra/stack/secrets` shows `server-secrets.yaml` changed in each stack.

```bash
git add infra/stack/secrets
git commit -m "build: the stacks' secrets hold the embedding keys"
```

- [ ] **Step 2: Push, after the user says yes**

Ask the user to confirm the push of Tasks 1 to 11 to `main`. Then push over HTTPS with gh's credential helper (SSH push fails in these sessions):

```bash
git -C docs push https://github.com/shopnexus/docs.git HEAD:main
git -c credential.helper='!gh auth git-credential' push https://github.com/shopnexus/shopnexus.git HEAD:main
```

- [ ] **Step 3: Check the sync, the keys and the rename**

```bash
kubectl -n shopnexus-dev get deploy tei ai litellm
kubectl -n shopnexus-dev logs job/litellm-key
master=$(kubectl -n shopnexus-dev get secret litellm-secrets -o jsonpath='{.data.LITELLM_MASTER_KEY}' | base64 -d)
key=$(kubectl -n shopnexus-dev get secret server-secrets -o jsonpath='{.data.LLM_API_KEY}' | base64 -d)
kubectl -n shopnexus-dev port-forward svc/litellm 56598:4000 & pf=$!; sleep 3
curl -s "http://127.0.0.1:56598/key/info?key=$key" -H "Authorization: Bearer $master" | jq '.info | {key_alias, spend, max_budget}'
curl -s "http://127.0.0.1:56598/key/list?return_full_object=true" -H "Authorization: Bearer $master" | jq '[.keys[].key_alias] | sort'
kill $pf
```

Expected: the three Deployments available; four log lines `litellm key server-embed-index: HTTP 200`, `… server-embed-search …`, `… server-llm …`, `… server-stt …`; `key_alias: "server-llm"` with the spend it had before (not reset to 0 unless the day rolled over); the key list `["server-embed-index","server-embed-search","server-llm","server-stt"]` and no `server`. If a `server` key is left besides `server-llm`, stop and report to the user: the rename made a second key.

- [ ] **Step 4: Run both smoke tests**

Run: `infra/smoke-models.sh dev && hurl --test --continue-on-error --variable domain=dev.shopnexus.id.vn infra/smoke.hurl`
Expected: every request passes in both files.

- [ ] **Step 5: Record the outcome**

Write the measured numbers (Task 2's spend and the upstream fields line, Task 5's cold start, memory and storage choice) into the reply that closes this plan, for the spec's amendment and plan 3.

---

## Self-review notes

- Spec coverage: aliases and keys as data (Tasks 3, 7), rename `server-llm` (Tasks 3, 11), two embed keys (Tasks 4, 7, 11), TEI (Tasks 5, 8), `ai` env and memory (Task 6), server `EMBED_*` (Tasks 7, 8), measured items 1, 2, 4 (Task 2), `store_prompts_in_spend_logs` (Tasks 2, 3), `check.sh` and smoke (Tasks 3 to 9, 11), docs (Task 10). Measured item 3 (SigLIP in Go) belongs to plan 1.
- The spec says `smoke.hurl` gains one call per embed alias; LiteLLM has no Ingress, so the calls live in `infra/smoke-models.hurl` behind a port-forward (Task 9).
- Names used across tasks: `KEY_SERVER_LLM`, `KEY_SERVER_STT`, `KEY_SERVER_EMBED_INDEX`, `KEY_SERVER_EMBED_SEARCH`; `sn.keyEnv`, `sn.keyBody`; values `tei.revision`, `tei.storage`, `tei.startupSeconds`, `ai.embedVersion`, `server.embed.*`.
