# `ai` image embeddings (SigLIP 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `ai` serves OpenAI's `POST /v1/embeddings` with SigLIP 2 (`siglip2-so400m-patch16-384`), taking images as `data:image/...;base64,` strings and text for the text tower, so LiteLLM's alias `embed-image` can route to it.

**Architecture:** A new package `embed` loads SigLIP 2's vision and text towers as ONNX through `github.com/yalue/onnxruntime_go`, on the same `libonnxruntime.so` that sherpa-onnx already links, plus the Gemma tokenizer through `github.com/eliben/go-sentencepiece`. `embeddings.go` in the root package parses OpenAI's request, turns data URLs into image bytes and answers OpenAI's shape with `usage`. Reference vectors made once with transformers pin the preprocessing; a measurement picks the int8 or the fp32 ONNX variant.

**Tech Stack:** Go 1.27 (cgo), onnxruntime 1.28.2 (bundled by sherpa-onnx-go v1.13.8), onnxruntime_go v1.32.1, go-sentencepiece v0.7.0, golang.org/x/image v0.47.0; Python + transformers only for the one-off reference script, run with `uv`.

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-09-server-photo-similar-search-design.md` (sections "Models behind LiteLLM → `ai`", "Measured first" item 3, "Testing → `ai`"). This is plan 1 of 3; plan 2 is `2026-11-09-search-models-infra.md`, plan 3 `2026-11-09-search-server.md`.

## Global Constraints

- Model: `google/siglip2-so400m-patch16-384`, reference weights at revision `dd658faac399427308559e2c3ac1e99cbe43845d`; ONNX from `onnx-community/siglip2-so400m-patch16-384-ONNX` at revision `29f74e673c298fd07482d8e20138179282001eb7`. Served name: `siglip2-so400m-patch16-384`.
- Vectors: 1152 dimensions, L2-normalized.
- Image preprocessing (from `preprocessor_config.json`): RGB, resize to 384 × 384 bilinear (no crop, aspect not kept), rescale 1/255, normalize mean 0.5 std 0.5, channels first.
- Text: lowercase, Gemma SentencePiece, `<eos>` appended, at most 64 ids with `<eos>` last, padded with `<pad>` (id from the model) to 64. Input name `input_ids`, int64.
- `usage.prompt_tokens`: 576 per image (24 × 24 patches), the id count before padding per text.
- Bounds: at most `AI_EMBED_MAX_INPUTS` inputs a request; an image at most `AI_EMBED_MAX_IMAGE_MB` after base64 decoding; under 32 px a side refused; more than 40 megapixels refused before decoding; `AI_EMBED_MAX_CONCURRENT` requests embedding at once, others wait.
- An input that starts with `data:image/` is an image (JPEG, PNG or WebP); anything else is text. One request may mix both.
- `encoding_format`: empty or `float` gives float arrays; `base64` gives little-endian float32 bytes in standard base64 (the OpenAI SDK, which LiteLLM uses, may ask for it).
- Errors keep OpenAI's shape and the codes `ai` uses: `invalid_request` (400), `model_not_found` (404), `too_large` (413), `internal_error` (500).
- Every variable is required, the image sets none: `AI_EMBED_MODELS` (`name=dir` pairs), `AI_EMBED_MAX_INPUTS`, `AI_EMBED_MAX_CONCURRENT`, `AI_EMBED_MAX_IMAGE_MB`. `AI_NUM_THREADS` also sets onnxruntime's intra-op threads of each embed session.
- `onnxruntime_go` stays at the release whose `ORT_API_VERSION` equals sherpa-onnx's bundled onnxruntime (v1.32.1 ↔ API 28 ↔ onnxruntime 1.28.2). A newer binding asks for an API the library does not have. This is the one exception to "newest release"; the README says why.
- No input (image or text) is logged. One log line per request: model, image count, text count, tokens, status, ms.
- Rollout order: plan 2 sets the four `AI_EMBED_*` variables on the chart and compose before this image reaches `main`, since `:main` deploys to dev at once and the new image refuses to start without them.
- Commits: no `Co-Authored-By` trailer. Scratch files in `tmp/` (git-ignored).

## Review Focus

1. A PNG with transparency (alpha 0 pixels) → the RGB values are used as stored, the way PIL's `convert("RGB")` does, so a logo on a transparent background embeds like the reference. Test in Task 3.
2. An EXIF-rotated JPEG → embedded as stored, unrotated; the server sends upright photos (media re-encodes them; the query photo is turned upright by the server, plan 3). The README says so. Test in Task 3 pins "orientation is ignored".
3. A request whose client goes away while it waits for a slot → the wait ends, no ONNX run starts, the log says 499. Test in Task 6.
4. A text over 64 tokens → truncated to 63 ids plus `<eos>`, never an error, and `usage` counts 64. Test in Task 2.
5. A data URL whose base64 is valid but whose bytes are not an image, or `data:image/gif` → 400 `invalid_request` naming the input index, not a 500. Test in Task 6.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/siglip-reference.py` (create) | One-off: draws the test images, runs transformers, writes reference ids and vectors. Not run by CI. |
| `embed/testdata/*.png`, `embed/testdata/reference.json` (create) | Inputs and expected outputs for the model tests. |
| `embed/ort.go` (create) | Initializes onnxruntime once, on the library sherpa-onnx already loaded. |
| `embed/text.go` (create) | Lowercase, tokenize, `<eos>`, truncate, pad. |
| `embed/image.go` (create) | Decode with bounds, RGB, resize, normalize to a `[3][384][384]` float slice. |
| `embed/embed.go` (create) | `Embedder`: loads models, batches inputs, runs sessions, normalizes, counts usage, bounds concurrency. |
| `embed/*_test.go` (create) | Unit tests; `//go:build model` tests against the real model and the reference. |
| `embed/measure_model_test.go` (create) | `//go:build measure`: prints cosine and ranking agreement for each variant directory. |
| `embeddings.go`, `embeddings_test.go` (create) | `POST /v1/embeddings`: parse, data URLs, limits, response, errors, log. |
| `openai.go`, `openai_test.go` (modify) | `newHandler` takes the embedder and the limits; the transcription tests pass a stub. |
| `config.go`, `config_test.go` (modify) | The four `AI_EMBED_*` variables. |
| `main.go` (modify) | Builds the embedder beside the transcriber. |
| `main_model_test.go` (create) | `//go:build model`: STT and embeddings in one process, both run. |
| `scripts/fetch-assets.sh`, `scripts/assets.sha256` (modify) | Download SigLIP 2's files at the pinned revision, checked. |
| `Dockerfile` (modify) | Nothing structural; the models stage now holds SigLIP 2, and the test stage runs the embed model tests. |
| `README.md` (modify) | The endpoint, the variables, the image size, the onnxruntime pin. |

---

### Task 1: Reference vectors and the measurement assets

**Files:**
- Create: `scripts/siglip-reference.py`
- Create: `embed/testdata/{red-circle,blue-square,green-triangle,checkerboard,yellow-stripes,orange-dot}.png`, `embed/testdata/reference.json`
- Modify: `scripts/fetch-assets.sh`, `scripts/assets.sha256`

**Interfaces:**
- Produces: `embed/testdata/reference.json` with this shape, read by Tasks 2, 5 and 8:

```json
{
  "model": "google/siglip2-so400m-patch16-384",
  "revision": "dd658faac399427308559e2c3ac1e99cbe43845d",
  "images": [{"file": "red-circle.png", "embedding": [0.01, "... 1152 floats"]}],
  "texts": [{"text": "a red circle", "input_ids": [1, "... 64 ints"], "tokens": 5, "embedding": [0.02, "... 1152 floats"]}]
}
```

- Produces: `scripts/fetch-assets.sh siglip-fp32 <dir>` and `siglip-int8 <dir>`, each filling `<dir>/siglip2-so400m-patch16-384/` with `vision_model.onnx`, `text_model.onnx` (+ `text_model.onnx_data` for fp32) and `tokenizer.model`.

- [ ] **Step 1: Write the reference script**

`scripts/siglip-reference.py`:

```python
# /// script
# requires-python = ">=3.12"
# dependencies = ["torch", "transformers", "pillow", "sentencepiece", "protobuf"]
# [tool.uv.sources]
# torch = { index = "pytorch-cpu" }
# [[tool.uv.index]]
# name = "pytorch-cpu"
# url = "https://download.pytorch.org/whl/cpu"
# explicit = true
# ///
"""Draws the embed test images and writes the reference ids and vectors.

Run once from the repo root, when the model or its revision changes:

    uv run scripts/siglip-reference.py embed/testdata

The images are drawn here, so the repo holds no third-party picture.
"""
import json
import sys
from pathlib import Path

import torch
from PIL import Image, ImageDraw
from transformers import AutoModel, AutoProcessor

MODEL = "google/siglip2-so400m-patch16-384"
REVISION = "dd658faac399427308559e2c3ac1e99cbe43845d"


def draw(out: Path) -> list[str]:
    files = []

    def save(name, img):
        img.save(out / name)
        files.append(name)

    img = Image.new("RGB", (640, 480), "white")
    ImageDraw.Draw(img).ellipse((170, 90, 470, 390), fill="red")
    save("red-circle.png", img)

    img = Image.new("RGB", (500, 500), "white")
    ImageDraw.Draw(img).rectangle((100, 100, 400, 400), fill="blue")
    save("blue-square.png", img)

    img = Image.new("RGB", (800, 600), "white")
    ImageDraw.Draw(img).polygon([(400, 80), (700, 520), (100, 520)], fill="green")
    save("green-triangle.png", img)

    img = Image.new("RGB", (512, 512), "white")
    d = ImageDraw.Draw(img)
    for y in range(8):
        for x in range(8):
            if (x + y) % 2:
                d.rectangle((x * 64, y * 64, x * 64 + 63, y * 64 + 63), fill="black")
    save("checkerboard.png", img)

    img = Image.new("RGB", (600, 400), "white")
    d = ImageDraw.Draw(img)
    for y in range(0, 400, 80):
        d.rectangle((0, y, 600, y + 39), fill="yellow")
    save("yellow-stripes.png", img)

    # RGBA with a transparent corner: PIL's convert("RGB") keeps the stored RGB.
    img = Image.new("RGBA", (300, 300), (128, 0, 128, 255))
    d = ImageDraw.Draw(img)
    d.ellipse((110, 110, 190, 190), fill=(255, 140, 0, 255))
    d.rectangle((0, 0, 60, 60), fill=(0, 255, 0, 0))
    save("orange-dot.png", img)
    return files


TEXTS = [
    "a red circle",
    "a blue square",
    "a green triangle",
    "a black and white checkerboard",
    "yellow horizontal stripes",
    "an orange dot on a purple background",
    "iPhone 13 Pro Max smartphone, blue",
    # Over 64 tokens: the reference shows how truncation ends.
    "a very long description " * 20,
]


def unit(v: torch.Tensor) -> list[float]:
    v = v / v.norm(dim=-1, keepdim=True)
    return [float(x) for x in v]


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    files = draw(out)
    model = AutoModel.from_pretrained(MODEL, revision=REVISION).eval()
    proc = AutoProcessor.from_pretrained(MODEL, revision=REVISION)

    ref = {"model": MODEL, "revision": REVISION, "images": [], "texts": []}
    with torch.no_grad():
        for name in files:
            pixels = proc(images=Image.open(out / name).convert("RGB"), return_tensors="pt")
            feats = model.get_image_features(**pixels)
            feats = feats if torch.is_tensor(feats) else feats.pooler_output
            ref["images"].append({"file": name, "embedding": unit(feats[0])})
        for text in TEXTS:
            lowered = text.lower()
            enc = proc(text=[lowered], padding="max_length", max_length=64, truncation=True, return_tensors="pt")
            feats = model.get_text_features(input_ids=enc["input_ids"])
            feats = feats if torch.is_tensor(feats) else feats.pooler_output
            ids = [int(i) for i in enc["input_ids"][0]]
            # Gemma's pad id appears only as padding, so the ids before it count.
            tokens = sum(1 for i in ids if i != proc.tokenizer.pad_token_id)
            ref["texts"].append({"text": text, "input_ids": ids, "tokens": tokens, "embedding": unit(feats[0])})
    (out / "reference.json").write_text(json.dumps(ref))


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it**

Run: `uv run scripts/siglip-reference.py embed/testdata`
Expected: six PNGs and `reference.json` in `embed/testdata/`; `python3 -c "import json;r=json.load(open('embed/testdata/reference.json'));print(len(r['images']),len(r['texts']),len(r['images'][0]['embedding']),len(r['texts'][0]['input_ids']))"` prints `6 8 1152 64`.

If `uv` is missing: `curl -LsSf https://astral.sh/uv/install.sh | sh` installs it under `~/.local/bin`.

- [ ] **Step 3: Teach fetch-assets the two variants**

In `scripts/fetch-assets.sh`, after the `WAVS=` line add:

```sh
SIGLIP=https://huggingface.co/onnx-community/siglip2-so400m-patch16-384-ONNX/resolve/29f74e673c298fd07482d8e20138179282001eb7
```

and before the `*)` case add:

```sh
siglip-fp32)
	mkdir -p siglip2-so400m-patch16-384
	for f in onnx/vision_model.onnx onnx/text_model.onnx onnx/text_model.onnx_data tokenizer.model; do
		curl -fsSL -o "siglip2-so400m-patch16-384/${f#onnx/}" "$SIGLIP/$f"
	done
	;;
siglip-int8)
	mkdir -p siglip2-so400m-patch16-384
	curl -fsSL -o siglip2-so400m-patch16-384/vision_model.onnx "$SIGLIP/onnx/vision_model_int8.onnx"
	curl -fsSL -o siglip2-so400m-patch16-384/text_model.onnx "$SIGLIP/onnx/text_model_int8.onnx"
	curl -fsSL -o siglip2-so400m-patch16-384/tokenizer.model "$SIGLIP/tokenizer.model"
	;;
```

Change the usage line to `echo "usage: $0 models|testwavs|siglip-fp32|siglip-int8 <dir>" >&2` and the header comment to list the two new kinds.

Append to `scripts/assets.sha256` (oids from the Hugging Face API at the pinned revision):

```
e3f730b2a37c69ac08c2159fe3c7fab97f23fbe3f32319f9953375ba82ecb1e6  siglip-fp32/siglip2-so400m-patch16-384/vision_model.onnx
1be6a35f94aa0d1aa15024569ccb7637c7157809624922e50e22d746d43745a5  siglip-fp32/siglip2-so400m-patch16-384/text_model.onnx
80d50b22c6a56758717e6acdbf03f3e564b3a701d152b6741d8b62181cae7983  siglip-fp32/siglip2-so400m-patch16-384/text_model.onnx_data
61a7b147390c64585d6c3543dd6fc636906c9af3865a5548f27f31aee1d4c8e2  siglip-fp32/siglip2-so400m-patch16-384/tokenizer.model
7b015bfdf140d7d13d74c7fc4b00553b65747620c0a8f11d0f7cbd4cad772cc5  siglip-int8/siglip2-so400m-patch16-384/vision_model.onnx
96bb04c4987f7e0d35ae64c4ef1a3121f833c2d0ad95faaae223c59dbbdd639c  siglip-int8/siglip2-so400m-patch16-384/text_model.onnx
61a7b147390c64585d6c3543dd6fc636906c9af3865a5548f27f31aee1d4c8e2  siglip-int8/siglip2-so400m-patch16-384/tokenizer.model
```

The script's last line already filters the file by `$kind/`, so each kind checks its own lines.

- [ ] **Step 4: Fetch both variants into tmp**

Run: `scripts/fetch-assets.sh siglip-fp32 tmp/measure/fp32 && scripts/fetch-assets.sh siglip-int8 tmp/measure/int8`
Expected: exit 0 (about 5.7 GB downloaded; the checksum line prints nothing on success).

- [ ] **Step 5: Commit**

```bash
git add scripts/siglip-reference.py scripts/fetch-assets.sh scripts/assets.sha256 embed/testdata
git commit -m "test: SigLIP 2 reference vectors and the two ONNX variants"
```

---

### Task 2: Tokenizer

**Files:**
- Create: `embed/text.go`, `embed/text_test.go`, `embed/text_model_test.go`
- Modify: `go.mod`, `go.sum`

**Interfaces:**
- Produces:

```go
// maxTextTokens is the length of the text tower's input.
const maxTextTokens = 64

type tokenizer struct{ /* unexported */ }

func newTokenizer(path string) (*tokenizer, error)
// ids gives the padded input ids and the count before padding.
func (t *tokenizer) ids(text string) (ids []int64, tokens int)
// pack is the pure part of ids, tested without the model.
func pack(raw []int, eos, pad int) ([]int64, int)
```

- [ ] **Step 1: Add the dependency**

Run: `go get github.com/eliben/go-sentencepiece@v0.7.0`
Expected: `go.mod` lists it.

- [ ] **Step 2: Write the failing unit test**

`embed/text_test.go`:

```go
package embed

import (
	"slices"
	"testing"
)

func TestPackAppendsEOSAndPads(t *testing.T) {
	ids, n := pack([]int{10, 11, 12}, 1, 0)
	if n != 4 {
		t.Fatalf("tokens = %d, want 4", n)
	}
	if len(ids) != maxTextTokens {
		t.Fatalf("len = %d, want %d", len(ids), maxTextTokens)
	}
	if !slices.Equal(ids[:5], []int64{10, 11, 12, 1, 0}) || ids[maxTextTokens-1] != 0 {
		t.Errorf("ids = %v", ids[:6])
	}
}

func TestPackTruncatesKeepingEOSLast(t *testing.T) {
	raw := make([]int, 100)
	for i := range raw {
		raw[i] = 100 + i
	}
	ids, n := pack(raw, 1, 0)
	if n != maxTextTokens {
		t.Fatalf("tokens = %d, want %d", n, maxTextTokens)
	}
	if ids[maxTextTokens-1] != 1 || ids[maxTextTokens-2] != int64(100+maxTextTokens-2) {
		t.Errorf("tail = %v", ids[maxTextTokens-3:])
	}
}

func TestPackEmptyTextIsEOSAlone(t *testing.T) {
	ids, n := pack(nil, 1, 0)
	if n != 1 || ids[0] != 1 || ids[1] != 0 {
		t.Errorf("ids = %v, tokens = %d", ids[:3], n)
	}
}
```

- [ ] **Step 3: Run it to see it fail**

Run: `go test ./embed/ -run TestPack`
Expected: FAIL, `undefined: pack`.

- [ ] **Step 4: Implement**

`embed/text.go`:

```go
package embed

import (
	"fmt"
	"strings"

	"github.com/eliben/go-sentencepiece"
)

// maxTextTokens is the length of the text tower's input: SigLIP 2 was
// trained on 64 ids, padded.
const maxTextTokens = 64

// tokenizer turns text into the text tower's input the way transformers'
// SigLIP 2 processor does with padding="max_length", max_length=64 and
// truncation, on text the caller lowercased (the model was trained on
// lowercased text).
type tokenizer struct {
	sp       *sentencepiece.Processor
	eos, pad int
}

func newTokenizer(path string) (*tokenizer, error) {
	sp, err := sentencepiece.NewProcessorFromPath(path)
	if err != nil {
		return nil, fmt.Errorf("load the tokenizer %s: %w", path, err)
	}
	info := sp.ModelInfo()
	return &tokenizer{sp: sp, eos: info.EndOfSentenceID, pad: info.PadID}, nil
}

// ids gives the padded input ids and how many come before the padding.
func (t *tokenizer) ids(text string) ([]int64, int) {
	toks := t.sp.Encode(strings.ToLower(text))
	raw := make([]int, len(toks))
	for i, tok := range toks {
		raw[i] = tok.ID
	}
	return pack(raw, t.eos, t.pad)
}

// pack keeps at most maxTextTokens-1 ids, appends eos and pads to
// maxTextTokens.
func pack(raw []int, eos, pad int) ([]int64, int) {
	if len(raw) > maxTextTokens-1 {
		raw = raw[:maxTextTokens-1]
	}
	ids := make([]int64, maxTextTokens)
	for i, id := range raw {
		ids[i] = int64(id)
	}
	ids[len(raw)] = int64(eos)
	for i := len(raw) + 1; i < maxTextTokens; i++ {
		ids[i] = int64(pad)
	}
	return ids, len(raw) + 1
}
```

- [ ] **Step 5: Run the unit tests**

Run: `go test ./embed/ -run TestPack -v`
Expected: PASS, three tests.

- [ ] **Step 6: Write the model test against the reference ids**

`embed/text_model_test.go` (tagged `model || measure`, since Task 5's measurement reads the same reference helpers):

```go
//go:build model || measure

// Model tests read the shipped SigLIP 2 from $AI_TEST_MODELS, an absolute
// path filled by scripts/fetch-assets.sh models (or siglip-int8 / siglip-fp32
// while measuring):
//
//	AI_TEST_MODELS=$PWD/tmp/models go test -race -tags model ./embed/
package embed

import (
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"testing"
)

const modelName = "siglip2-so400m-patch16-384"

type reference struct {
	Images []struct {
		File      string    `json:"file"`
		Embedding []float32 `json:"embedding"`
	} `json:"images"`
	Texts []struct {
		Text      string    `json:"text"`
		InputIDs  []int64   `json:"input_ids"`
		Tokens    int       `json:"tokens"`
		Embedding []float32 `json:"embedding"`
	} `json:"texts"`
}

func loadReference(t *testing.T) reference {
	t.Helper()
	b, err := os.ReadFile("testdata/reference.json")
	if err != nil {
		t.Fatal(err)
	}
	var r reference
	if err := json.Unmarshal(b, &r); err != nil {
		t.Fatal(err)
	}
	return r
}

func modelDir(t *testing.T) string {
	t.Helper()
	v := os.Getenv("AI_TEST_MODELS")
	if v == "" || !filepath.IsAbs(v) {
		t.Fatalf("set AI_TEST_MODELS to an absolute path (see the comment at the top of this file)")
	}
	return filepath.Join(v, modelName)
}

func TestTokenizerMatchesTransformers(t *testing.T) {
	tok, err := newTokenizer(filepath.Join(modelDir(t), "tokenizer.model"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range loadReference(t).Texts {
		ids, n := tok.ids(want.Text)
		if !slices.Equal(ids, want.InputIDs) {
			t.Errorf("%q: ids = %v\nwant %v", want.Text, ids, want.InputIDs)
		}
		if n != want.Tokens {
			t.Errorf("%q: tokens = %d, want %d", want.Text, n, want.Tokens)
		}
	}
}
```

- [ ] **Step 7: Run it on the measurement copy**

Run: `AI_TEST_MODELS=$PWD/tmp/measure/int8 go test -tags model ./embed/ -run TestTokenizerMatchesTransformers -v`
Expected: PASS. If the ids differ only at the end (where `<eos>` sits) or in padding, fix `pack`; if they differ inside the text, compare `strings.ToLower` against Python's `str.lower` on that input and fix the normalization before going on.

- [ ] **Step 8: Commit**

```bash
git add go.mod go.sum embed/text.go embed/text_test.go embed/text_model_test.go
git commit -m "feat: the Gemma tokenizer for SigLIP 2's text tower"
```

---

### Task 3: Image preprocessing

**Files:**
- Create: `embed/image.go`, `embed/image_test.go`
- Modify: `go.mod`, `go.sum`

**Interfaces:**
- Produces:

```go
// imageSide is the vision tower's input side.
const imageSide = 384

// ErrBadImage marks an input that is not an image the service takes. Its
// message says why; the HTTP layer answers 400 with it.
var ErrBadImage = errors.New("bad image")

// pixels decodes b and returns the vision tower's input for one image:
// 3*imageSide*imageSide floats, channels first, in [-1, 1].
func pixels(b []byte) ([]float32, error)
```

- [ ] **Step 1: Add the dependency**

Run: `go get golang.org/x/image@v0.47.0`

- [ ] **Step 2: Write the failing tests**

`embed/image_test.go`:

```go
package embed

import (
	"bytes"
	"encoding/binary"
	"errors"
	"hash/crc32"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"math"
	"strings"
	"testing"
)

func encodePNG(t *testing.T, img image.Image) []byte {
	t.Helper()
	var b bytes.Buffer
	if err := png.Encode(&b, img); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

func solid(w, h int, c color.NRGBA) *image.NRGBA {
	img := image.NewNRGBA(image.Rect(0, 0, w, h))
	for y := range h {
		for x := range w {
			img.SetNRGBA(x, y, c)
		}
	}
	return img
}

// at is channel c at row y, column x of a pixels() result.
func at(p []float32, c, y, x int) float32 { return p[c*imageSide*imageSide+y*imageSide+x] }

func near(a, b float32) bool { return math.Abs(float64(a-b)) < 1e-3 }

func TestPixelsNormalizesChannelsFirst(t *testing.T) {
	p, err := pixels(encodePNG(t, solid(100, 60, color.NRGBA{255, 0, 0, 255})))
	if err != nil {
		t.Fatal(err)
	}
	if len(p) != 3*imageSide*imageSide {
		t.Fatalf("len = %d", len(p))
	}
	for _, yx := range [][2]int{{0, 0}, {200, 300}, {383, 383}} {
		r, g, b := at(p, 0, yx[0], yx[1]), at(p, 1, yx[0], yx[1]), at(p, 2, yx[0], yx[1])
		if !near(r, 1) || !near(g, -1) || !near(b, -1) {
			t.Errorf("at %v: %v %v %v, want 1 -1 -1", yx, r, g, b)
		}
	}
}

func TestPixelsKeepsRGBUnderTransparency(t *testing.T) {
	// Alpha 0 over blue: PIL's convert("RGB") keeps blue, so must we.
	p, err := pixels(encodePNG(t, solid(64, 64, color.NRGBA{0, 0, 255, 0})))
	if err != nil {
		t.Fatal(err)
	}
	if r, b := at(p, 0, 10, 10), at(p, 2, 10, 10); !near(r, -1) || !near(b, 1) {
		t.Errorf("r, b = %v, %v, want -1, 1", r, b)
	}
}

func TestPixelsReadsJPEG(t *testing.T) {
	var b bytes.Buffer
	if err := jpeg.Encode(&b, solid(80, 80, color.NRGBA{255, 255, 255, 255}), &jpeg.Options{Quality: 95}); err != nil {
		t.Fatal(err)
	}
	p, err := pixels(b.Bytes())
	if err != nil {
		t.Fatal(err)
	}
	if v := at(p, 1, 40, 40); v < 0.98 {
		t.Errorf("white green channel = %v", v)
	}
}

func TestPixelsIgnoresEXIFOrientation(t *testing.T) {
	// A JPEG is embedded as stored; callers send upright photos. A 80x40
	// image stays wide: its left half red, right half blue, after resize.
	img := image.NewNRGBA(image.Rect(0, 0, 80, 40))
	for y := range 40 {
		for x := range 80 {
			c := color.NRGBA{255, 0, 0, 255}
			if x >= 40 {
				c = color.NRGBA{0, 0, 255, 255}
			}
			img.SetNRGBA(x, y, c)
		}
	}
	p, err := pixels(encodePNG(t, img))
	if err != nil {
		t.Fatal(err)
	}
	if at(p, 0, 192, 20) < 0.9 || at(p, 2, 192, 360) < 0.9 {
		t.Errorf("left red %v, right blue %v", at(p, 0, 192, 20), at(p, 2, 192, 360))
	}
}

func TestPixelsRefuses(t *testing.T) {
	tiny := encodePNG(t, solid(31, 200, color.NRGBA{0, 0, 0, 255}))
	gif := []byte("GIF89a\x01\x00\x01\x00\x00\x00\x00;")
	for name, b := range map[string][]byte{"tiny": tiny, "gif": gif, "garbage": []byte("not an image")} {
		if _, err := pixels(b); !errors.Is(err, ErrBadImage) {
			t.Errorf("%s: err = %v, want ErrBadImage", name, err)
		}
	}
}

// pngHeader is a PNG signature and IHDR chunk claiming w x h, with no
// pixel data: enough for DecodeConfig, never decodable.
func pngHeader(w, h uint32) []byte {
	var b bytes.Buffer
	b.WriteString("\x89PNG\r\n\x1a\n")
	chunk := make([]byte, 4+13)
	copy(chunk, "IHDR")
	binary.BigEndian.PutUint32(chunk[4:], w)
	binary.BigEndian.PutUint32(chunk[8:], h)
	chunk[12], chunk[13] = 8, 6 // 8-bit RGBA
	_ = binary.Write(&b, binary.BigEndian, uint32(13))
	b.Write(chunk)
	_ = binary.Write(&b, binary.BigEndian, crc32.ChecksumIEEE(chunk))
	return b.Bytes()
}

func TestPixelsRefusesTooManyPixelsBeforeDecoding(t *testing.T) {
	if _, err := pixels(pngHeader(10000, 5000)); !errors.Is(err, ErrBadImage) || !strings.Contains(err.Error(), "pixels") {
		t.Errorf("err = %v, want ErrBadImage about pixels", err)
	}
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `go test ./embed/ -run TestPixels`
Expected: FAIL, `undefined: pixels`.

- [ ] **Step 4: Implement**

`embed/image.go`:

```go
package embed

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/color"
	_ "image/jpeg" // registers JPEG
	_ "image/png"  // registers PNG

	"golang.org/x/image/draw"
	_ "golang.org/x/image/webp" // registers WebP
)

const (
	// imageSide is the vision tower's input side.
	imageSide = 384
	// minSide refuses images too small to mean anything, and the 1x1
	// inputs that crashed other servers.
	minSide = 32
	// maxPixels bounds the decoded size, checked from the header first.
	maxPixels = 40_000_000
)

// ErrBadImage marks an input that is not an image the service takes.
var ErrBadImage = errors.New("bad image")

// pixels decodes b and returns the vision tower's input for one image, as
// transformers' SiglipImageProcessor builds it: RGB as stored (alpha
// dropped, as PIL's convert("RGB") does), bilinear resize to 384x384
// without keeping the aspect, then (v/255 - 0.5) / 0.5, channels first.
// EXIF orientation is not applied.
func pixels(b []byte) ([]float32, error) {
	cfg, format, err := image.DecodeConfig(bytes.NewReader(b))
	if err != nil {
		return nil, fmt.Errorf("%w: not a JPEG, PNG or WebP", ErrBadImage)
	}
	if format != "jpeg" && format != "png" && format != "webp" {
		return nil, fmt.Errorf("%w: %s is not JPEG, PNG or WebP", ErrBadImage, format)
	}
	if cfg.Width < minSide || cfg.Height < minSide {
		return nil, fmt.Errorf("%w: %dx%d is under %d px a side", ErrBadImage, cfg.Width, cfg.Height, minSide)
	}
	if cfg.Width*cfg.Height > maxPixels {
		return nil, fmt.Errorf("%w: %dx%d is over %d pixels", ErrBadImage, cfg.Width, cfg.Height, maxPixels)
	}
	src, _, err := image.Decode(bytes.NewReader(b))
	if err != nil {
		return nil, fmt.Errorf("%w: %w", ErrBadImage, err)
	}

	// Non-premultiplied, so a transparent pixel keeps its stored RGB.
	rgb := image.NewNRGBA(src.Bounds())
	for y := src.Bounds().Min.Y; y < src.Bounds().Max.Y; y++ {
		for x := src.Bounds().Min.X; x < src.Bounds().Max.X; x++ {
			c := color.NRGBAModel.Convert(src.At(x, y)).(color.NRGBA)
			c.A = 255
			rgb.SetNRGBA(x, y, c)
		}
	}
	dst := image.NewNRGBA(image.Rect(0, 0, imageSide, imageSide))
	draw.BiLinear.Scale(dst, dst.Bounds(), rgb, rgb.Bounds(), draw.Src, nil)

	out := make([]float32, 3*imageSide*imageSide)
	plane := imageSide * imageSide
	for y := range imageSide {
		for x := range imageSide {
			i := dst.PixOffset(x, y)
			for c := range 3 {
				out[c*plane+y*imageSide+x] = float32(dst.Pix[i+c])/127.5 - 1
			}
		}
	}
	return out, nil
}
```

- [ ] **Step 5: Run the tests**

Run: `go test ./embed/ -run TestPixels -v`
Expected: PASS, six tests.

- [ ] **Step 6: Commit**

```bash
git add go.mod go.sum embed/image.go embed/image_test.go
git commit -m "feat: SigLIP 2 image preprocessing with size bounds"
```

---

### Task 4: onnxruntime shared with sherpa-onnx

**Files:**
- Create: `embed/ort.go`, `main_model_test.go`
- Modify: `go.mod`, `go.sum`

**Interfaces:**
- Produces: `func initORT() error` (idempotent), used by `New` in Task 5.
- Produces: `main_model_test.go` with `TestSpeechAndEmbeddingsShareOneProcess`, extended in Task 5 once `embed.New` exists.

- [ ] **Step 1: Add the binding at the matching API**

Run: `go get github.com/yalue/onnxruntime_go@v1.32.1 && grep -h "define ORT_API_VERSION" $(go list -m -f '{{.Dir}}' github.com/yalue/onnxruntime_go)/onnxruntime_c_api.h`
Expected: `#define ORT_API_VERSION 28`.

- [ ] **Step 2: Implement initORT**

`embed/ort.go`:

```go
package embed

import (
	"fmt"
	"sync"

	// Links libonnxruntime.so (with an rpath to it) the way the speech
	// package does, so this package's own test binaries load it too.
	_ "github.com/k2-fsa/sherpa-onnx-go/sherpa_onnx"
	ort "github.com/yalue/onnxruntime_go"
)

// The binary links libonnxruntime.so for sherpa-onnx. dlopen of the bare
// name finds that already loaded object by its soname, so both share one
// library. onnxruntime_go must stay at the release whose ORT_API_VERSION
// matches it (v1.32.1 for onnxruntime 1.28.2): a newer binding asks for an
// API the library does not have.
const ortLibrary = "libonnxruntime.so"

var (
	ortOnce sync.Once
	ortErr  error
)

func initORT() error {
	ortOnce.Do(func() {
		ort.SetSharedLibraryPath(ortLibrary)
		if err := ort.InitializeEnvironment(); err != nil {
			ortErr = fmt.Errorf("start onnxruntime: %w", err)
		}
	})
	return ortErr
}
```

- [ ] **Step 3: Probe the model's inputs and outputs**

Write `tmp/ioinfo/main.go` (scratch, not committed):

```go
package main

import (
	"fmt"
	"os"

	ort "github.com/yalue/onnxruntime_go"
)

func main() {
	ort.SetSharedLibraryPath(os.Args[1])
	if err := ort.InitializeEnvironment(); err != nil {
		panic(err)
	}
	for _, f := range os.Args[2:] {
		in, out, err := ort.GetInputOutputInfo(f)
		if err != nil {
			panic(err)
		}
		fmt.Println(f)
		for _, i := range in {
			fmt.Println("  in ", i.Name, i.DataType, i.Dimensions)
		}
		for _, o := range out {
			fmt.Println("  out", o.Name, o.DataType, o.Dimensions)
		}
	}
}
```

Run: `lib=$(go list -m -f '{{.Dir}}' github.com/k2-fsa/sherpa-onnx-go-linux)/lib/x86_64-unknown-linux-gnu/libonnxruntime.so; d=tmp/measure/int8/siglip2-so400m-patch16-384; go run ./tmp/ioinfo "$lib" $d/vision_model.onnx $d/text_model.onnx`
Expected: vision in `pixel_values` float `[-1 3 384 384]` (batch may print as -1 or a name), outputs including `pooler_output` `[-1 1152]`; text in `input_ids` int64 `[-1 -1]` or `[-1 64]`, outputs including `pooler_output` `[-1 1152]`. If the names differ, use the printed ones in Task 5's constants `visionInput`, `visionOutput`, `textInput`, `textOutput` and note it in the commit message.

- [ ] **Step 4: Write the shared-process test (speech side first)**

`main_model_test.go`:

```go
//go:build model

// Speech and embeddings in one process: sherpa-onnx and onnxruntime_go use
// the same libonnxruntime.so. Run from the repo root with
//
//	AI_TEST_MODELS=$PWD/tmp/models AI_TEST_WAVS=$PWD/tmp/testwavs go test -race -tags model .
package main

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/shopnexus/ai/speech"
)

func TestSpeechAndEmbeddingsShareOneProcess(t *testing.T) {
	models, wavs := os.Getenv("AI_TEST_MODELS"), os.Getenv("AI_TEST_WAVS")
	if !filepath.IsAbs(models) || !filepath.IsAbs(wavs) {
		t.Fatal("set AI_TEST_MODELS and AI_TEST_WAVS to absolute paths")
	}
	tr, err := speech.New(speech.Config{
		Models:   map[string]string{"gipformer-1.5": filepath.Join(models, "gipformer-1.5")},
		VADModel: filepath.Join(models, "silero_vad.onnx"), NumThreads: 2, MaxConcurrent: 1, MaxAudioSeconds: 300,
	})
	if err != nil {
		t.Fatal(err)
	}
	defer tr.Close()
	if _, err := tr.Transcribe(context.Background(), "gipformer-1.5", filepath.Join(wavs, "0.wav")); err != nil {
		t.Fatal(err)
	}
	// Task 5 adds the embedder here, after the transcriber has loaded.
}
```

- [ ] **Step 5: Run it**

Run: `scripts/fetch-assets.sh models tmp/models && scripts/fetch-assets.sh testwavs tmp/testwavs && AI_TEST_MODELS=$PWD/tmp/models AI_TEST_WAVS=$PWD/tmp/testwavs go test -tags model -run TestSpeechAndEmbeddingsShareOneProcess -v .`
Expected: PASS (the speech half; the embed half lands in Task 5).

- [ ] **Step 6: Commit**

```bash
git add go.mod go.sum embed/ort.go main_model_test.go
git commit -m "feat: onnxruntime_go on the library sherpa-onnx links"
```

---

### Task 5: The embedder, and the int8 or fp32 decision

**Files:**
- Create: `embed/embed.go`, `embed/embed_test.go`, `embed/reference_model_test.go`, `embed/embed_model_test.go`, `embed/measure_model_test.go`
- Modify: `main_model_test.go`

**Interfaces:**
- Consumes: `pixels`, `ErrBadImage`, `newTokenizer`, `(*tokenizer).ids`, `initORT`.
- Produces:

```go
type Config struct {
	Models        map[string]string // name → folder with vision_model.onnx, text_model.onnx, tokenizer.model
	NumThreads    int               // onnxruntime intra-op threads per session
	MaxConcurrent int               // requests embedding at once
}

// Input is one thing to embed: Image (encoded JPEG, PNG or WebP bytes) when
// non-nil, else Text.
type Input struct {
	Image []byte
	Text  string
}

type Result struct {
	Vectors [][]float32 // in input order, L2-normalized, 1152 each
	Tokens  int         // 576 per image plus each text's ids before padding
}

var ErrUnknownModel = errors.New("unknown model")

// InputError says which input was refused; it wraps ErrBadImage.
type InputError struct {
	Index int
	Err   error
}

func New(c Config) (*Embedder, error)
func (e *Embedder) HasModel(name string) bool
func (e *Embedder) Models() []string
func (e *Embedder) Embed(ctx context.Context, model string, in []Input) (Result, error)
func (e *Embedder) Close()

// Dimensions of the vectors.
const Dimensions = 1152
// ImageTokens is what one image counts in usage.
const ImageTokens = 576
```

- [ ] **Step 1: Write the failing unit tests (no model)**

`embed/embed_test.go`:

```go
package embed

import (
	"errors"
	"math"
	"testing"
)

func TestNormalize(t *testing.T) {
	v := []float32{3, 4}
	normalize(v)
	if math.Abs(float64(v[0])-0.6) > 1e-6 || math.Abs(float64(v[1])-0.8) > 1e-6 {
		t.Errorf("v = %v", v)
	}
	zero := []float32{0, 0}
	normalize(zero) // must not divide by zero
	if zero[0] != 0 || zero[1] != 0 {
		t.Errorf("zero = %v", zero)
	}
}

func TestInputErrorUnwraps(t *testing.T) {
	err := error(&InputError{Index: 2, Err: ErrBadImage})
	if !errors.Is(err, ErrBadImage) {
		t.Error("InputError does not unwrap to ErrBadImage")
	}
	if got := err.Error(); got != "input 2: bad image" {
		t.Errorf("Error() = %q", got)
	}
}

func TestNewRefusesAMissingFolder(t *testing.T) {
	_, err := New(Config{Models: map[string]string{"x": t.TempDir()}, NumThreads: 1, MaxConcurrent: 1})
	if err == nil {
		t.Fatal("New loaded a folder with no model")
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test ./embed/ -run 'TestNormalize|TestInputError|TestNewRefuses'`
Expected: FAIL, `undefined: normalize`.

- [ ] **Step 3: Implement**

`embed/embed.go`:

```go
// Package embed turns images and text into SigLIP 2 vectors in one space,
// on CPU, through onnxruntime.
package embed

import (
	"context"
	"errors"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"slices"

	ort "github.com/yalue/onnxruntime_go"
)

const (
	// Dimensions of the vectors.
	Dimensions = 1152
	// ImageTokens is what one image counts in usage: its 24x24 patches.
	ImageTokens = 576

	visionInput, visionOutput = "pixel_values", "pooler_output"
	textInput, textOutput     = "input_ids", "pooler_output"
)

// ErrUnknownModel means the request names a model the service does not have.
var ErrUnknownModel = errors.New("unknown model")

// InputError says which input was refused.
type InputError struct {
	Index int
	Err   error
}

func (e *InputError) Error() string { return fmt.Sprintf("input %d: %v", e.Index, e.Err) }
func (e *InputError) Unwrap() error { return e.Err }

// Config of an Embedder.
type Config struct {
	// Models maps a name to a folder holding vision_model.onnx,
	// text_model.onnx (with its .onnx_data when it has one) and
	// tokenizer.model.
	Models        map[string]string
	NumThreads    int
	MaxConcurrent int
}

// Input is one thing to embed: Image when non-nil, else Text.
type Input struct {
	Image []byte
	Text  string
}

// Result of one Embed call.
type Result struct {
	Vectors [][]float32
	Tokens  int
}

type model struct {
	vision, text *ort.DynamicAdvancedSession
	tok          *tokenizer
}

// Embedder is safe for concurrent use: onnxruntime sessions run
// concurrently, and at most MaxConcurrent calls embed at once.
type Embedder struct {
	models map[string]*model
	slots  chan struct{}
}

// New loads every model. It fails when a file is missing or does not load.
func New(c Config) (*Embedder, error) {
	if err := initORT(); err != nil {
		return nil, err
	}
	e := &Embedder{models: map[string]*model{}, slots: make(chan struct{}, c.MaxConcurrent)}
	for name, dir := range c.Models {
		m, err := load(dir, c.NumThreads)
		if err != nil {
			e.Close()
			return nil, fmt.Errorf("model %s: %w", name, err)
		}
		e.models[name] = m
	}
	return e, nil
}

func load(dir string, threads int) (*model, error) {
	for _, f := range []string{"vision_model.onnx", "text_model.onnx", "tokenizer.model"} {
		if _, err := os.Stat(filepath.Join(dir, f)); err != nil {
			return nil, err
		}
	}
	opts, err := ort.NewSessionOptions()
	if err != nil {
		return nil, err
	}
	defer opts.Destroy()
	if err = opts.SetIntraOpNumThreads(threads); err != nil {
		return nil, err
	}
	if err = opts.SetInterOpNumThreads(1); err != nil {
		return nil, err
	}
	m := &model{}
	if m.vision, err = ort.NewDynamicAdvancedSession(filepath.Join(dir, "vision_model.onnx"),
		[]string{visionInput}, []string{visionOutput}, opts); err != nil {
		return nil, err
	}
	if m.text, err = ort.NewDynamicAdvancedSession(filepath.Join(dir, "text_model.onnx"),
		[]string{textInput}, []string{textOutput}, opts); err != nil {
		m.vision.Destroy()
		return nil, err
	}
	if m.tok, err = newTokenizer(filepath.Join(dir, "tokenizer.model")); err != nil {
		m.vision.Destroy()
		m.text.Destroy()
		return nil, err
	}
	return m, nil
}

// HasModel says whether name is loaded.
func (e *Embedder) HasModel(name string) bool { _, ok := e.models[name]; return ok }

// Models lists the loaded names, sorted.
func (e *Embedder) Models() []string {
	names := make([]string, 0, len(e.models))
	for n := range e.models {
		names = append(names, n)
	}
	slices.Sort(names)
	return names
}

// Embed embeds every input of one request: the images in one run of the
// vision tower, the texts in one run of the text tower. A refused image is
// an *InputError wrapping ErrBadImage, before any run.
func (e *Embedder) Embed(ctx context.Context, name string, in []Input) (Result, error) {
	m, ok := e.models[name]
	if !ok {
		return Result{}, ErrUnknownModel
	}
	var (
		imgIdx, txtIdx []int
		pix            []float32
		ids            []int64
		res            = Result{Vectors: make([][]float32, len(in))}
	)
	for i, x := range in {
		if x.Image != nil {
			p, err := pixels(x.Image)
			if err != nil {
				return Result{}, &InputError{Index: i, Err: err}
			}
			pix = append(pix, p...)
			imgIdx = append(imgIdx, i)
			res.Tokens += ImageTokens
			continue
		}
		t, n := m.tok.ids(x.Text)
		ids = append(ids, t...)
		txtIdx = append(txtIdx, i)
		res.Tokens += n
	}

	select {
	case e.slots <- struct{}{}:
	case <-ctx.Done():
		return Result{}, ctx.Err()
	}
	defer func() { <-e.slots }()

	if len(imgIdx) > 0 {
		in, err := ort.NewTensor(ort.NewShape(int64(len(imgIdx)), 3, imageSide, imageSide), pix)
		if err != nil {
			return Result{}, err
		}
		vecs, err := run(m.vision, in, len(imgIdx))
		if err != nil {
			return Result{}, fmt.Errorf("vision tower: %w", err)
		}
		for k, i := range imgIdx {
			res.Vectors[i] = vecs[k]
		}
	}
	if len(txtIdx) > 0 {
		in, err := ort.NewTensor(ort.NewShape(int64(len(txtIdx)), maxTextTokens), ids)
		if err != nil {
			return Result{}, err
		}
		vecs, err := run(m.text, in, len(txtIdx))
		if err != nil {
			return Result{}, fmt.Errorf("text tower: %w", err)
		}
		for k, i := range txtIdx {
			res.Vectors[i] = vecs[k]
		}
	}
	return res, nil
}

// run runs one tower on a batch and returns n normalized vectors. It takes
// ownership of in.
func run[T ort.TensorData](s *ort.DynamicAdvancedSession, in *ort.Tensor[T], n int) ([][]float32, error) {
	defer in.Destroy()
	outs := []ort.Value{nil}
	if err := s.Run([]ort.Value{in}, outs); err != nil {
		return nil, err
	}
	defer outs[0].Destroy()
	out, ok := outs[0].(*ort.Tensor[float32])
	if !ok {
		return nil, fmt.Errorf("output is %T, not float32", outs[0])
	}
	data := out.GetData()
	if len(data) != n*Dimensions {
		return nil, fmt.Errorf("output holds %d floats, want %d", len(data), n*Dimensions)
	}
	vecs := make([][]float32, n)
	for k := range n {
		v := slices.Clone(data[k*Dimensions : (k+1)*Dimensions])
		normalize(v)
		vecs[k] = v
	}
	return vecs, nil
}

func normalize(v []float32) {
	var s float64
	for _, x := range v {
		s += float64(x) * float64(x)
	}
	if s == 0 {
		return
	}
	inv := float32(1 / math.Sqrt(s))
	for i := range v {
		v[i] *= inv
	}
}

// Close releases every session.
func (e *Embedder) Close() {
	for _, m := range e.models {
		m.vision.Destroy()
		m.text.Destroy()
	}
}
```

- [ ] **Step 4: Run the unit tests**

Run: `go test ./embed/ -v`
Expected: PASS (the tokenizer, image and embed unit tests; model tests are tagged out).

- [ ] **Step 5: Write the shared helpers and the measurement test**

`embed/reference_model_test.go`, shared by the `model` and `measure` tags:

```go
//go:build model || measure

package embed

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"testing"
)

// embedReference embeds the reference images and texts with e.
func embedReference(t *testing.T, e *Embedder, ref reference) (imgs, txts [][]float32) {
	t.Helper()
	var in []Input
	for _, im := range ref.Images {
		b, err := os.ReadFile(filepath.Join("testdata", im.File))
		if err != nil {
			t.Fatal(err)
		}
		in = append(in, Input{Image: b})
	}
	for _, tx := range ref.Texts {
		in = append(in, Input{Text: tx.Text})
	}
	res, err := e.Embed(context.Background(), e.Models()[0], in)
	if err != nil {
		t.Fatal(err)
	}
	return res.Vectors[:len(ref.Images)], res.Vectors[len(ref.Images):]
}

func cosine(a, b []float32) float64 {
	var s float64
	for i := range a {
		s += float64(a[i]) * float64(b[i])
	}
	return s // both are unit vectors
}

// sameRankings says whether, for every text, the images rank in the same
// order as with the reference vectors.
func sameRankings(imgs, txts [][]float32, ref reference) bool {
	order := func(q []float32, set [][]float32) []int {
		idx := make([]int, len(set))
		for i := range idx {
			idx[i] = i
		}
		slices.SortFunc(idx, func(a, b int) int {
			ca, cb := cosine(q, set[a]), cosine(q, set[b])
			switch {
			case ca > cb:
				return -1
			case ca < cb:
				return 1
			}
			return 0
		})
		return idx
	}
	refImgs := make([][]float32, len(ref.Images))
	for i := range ref.Images {
		refImgs[i] = ref.Images[i].Embedding
	}
	for i := range txts {
		if !slices.Equal(order(txts[i], imgs), order(ref.Texts[i].Embedding, refImgs)) {
			return false
		}
	}
	return true
}
```

`embed/measure_model_test.go`:

```go
//go:build measure

// Compares each variant folder in $AI_TEST_SIGLIP_DIRS (comma-separated,
// absolute, each holding siglip2-so400m-patch16-384/) with the reference:
//
//	AI_TEST_SIGLIP_DIRS=$PWD/tmp/measure/fp32,$PWD/tmp/measure/int8 go test -tags measure -run TestMeasure -v ./embed/
package embed

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestMeasure(t *testing.T) {
	ref := loadReference(t)
	for dir := range strings.SplitSeq(os.Getenv("AI_TEST_SIGLIP_DIRS"), ",") {
		e, err := New(Config{Models: map[string]string{"m": filepath.Join(dir, "siglip2-so400m-patch16-384")}, NumThreads: 4, MaxConcurrent: 1})
		if err != nil {
			t.Fatal(err)
		}
		start := time.Now()
		imgs, txts := embedReference(t, e, ref)
		perInput := time.Since(start) / time.Duration(len(imgs)+len(txts))
		minCos := 1.0
		for i, v := range imgs {
			minCos = min(minCos, cosine(v, ref.Images[i].Embedding))
		}
		for i, v := range txts {
			minCos = min(minCos, cosine(v, ref.Texts[i].Embedding))
		}
		t.Logf("%s: min cosine %.5f, rankings kept %v, %v per input", dir, minCos, sameRankings(imgs, txts, ref), perInput)
		e.Close()
	}
}
```

- [ ] **Step 6: Measure, decide, record**

Run: `AI_TEST_SIGLIP_DIRS=$PWD/tmp/measure/fp32,$PWD/tmp/measure/int8 go test -tags measure -run TestMeasure -v ./embed/ 2>&1 | tee tmp/measure.log`
Expected: two log lines. fp32 must show min cosine ≥ 0.999; below that the preprocessing differs from transformers. Then stop and fix `pixels` or the tokenizer (likely suspects: the bilinear kernel against PIL's, alpha handling) before deciding anything.

Decision rule from the spec conversation (2026-11-09): **int8** when its min cosine ≥ 0.98 and rankings are kept; otherwise **fp32**. Write the result, the two lines from `tmp/measure.log` and the time per input into the commit message of Step 9 and into the README in Task 8.

- [ ] **Step 7: Write the permanent model test for the chosen variant**

`embed/embed_model_test.go` (set `minCosine` to `0.98` for int8 or `0.999` for fp32, per Step 6):

```go
//go:build model

package embed

import (
	"context"
	"sync"
	"testing"
)

// minCosine is the floor against transformers for the shipped variant,
// chosen by the measurement of 2026-11-09 (see README).
const minCosine = 0.98

func newEmbedder(t *testing.T, concurrent int) *Embedder {
	t.Helper()
	e, err := New(Config{Models: map[string]string{modelName: modelDir(t)}, NumThreads: 2, MaxConcurrent: concurrent})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(e.Close)
	return e
}

func TestEmbedMatchesTransformers(t *testing.T) {
	ref := loadReference(t)
	imgs, txts := embedReference(t, newEmbedder(t, 1), ref)
	for i, v := range imgs {
		if len(v) != Dimensions {
			t.Fatalf("image %d has %d dimensions", i, len(v))
		}
		if c := cosine(v, ref.Images[i].Embedding); c < minCosine {
			t.Errorf("%s: cosine %.5f < %v", ref.Images[i].File, c, minCosine)
		}
		if n := cosine(v, v); n < 0.9999 || n > 1.0001 {
			t.Errorf("%s: norm² %.6f", ref.Images[i].File, n)
		}
	}
	for i, v := range txts {
		if c := cosine(v, ref.Texts[i].Embedding); c < minCosine {
			t.Errorf("%q: cosine %.5f < %v", ref.Texts[i].Text, c, minCosine)
		}
	}
	if !sameRankings(imgs, txts, ref) {
		t.Error("a text ranks the images in another order than transformers")
	}
}

func TestEmbedCountsUsage(t *testing.T) {
	ref := loadReference(t)
	e := newEmbedder(t, 1)
	res, err := e.Embed(context.Background(), modelName, []Input{{Text: ref.Texts[0].Text}, {Text: ref.Texts[7].Text}})
	if err != nil {
		t.Fatal(err)
	}
	if want := ref.Texts[0].Tokens + ref.Texts[7].Tokens; res.Tokens != want {
		t.Errorf("tokens = %d, want %d", res.Tokens, want)
	}
	if ref.Texts[7].Tokens != maxTextTokens {
		t.Errorf("the long text counts %d, want %d", ref.Texts[7].Tokens, maxTextTokens)
	}
}

func TestEmbedConcurrently(t *testing.T) {
	ref := loadReference(t)
	e := newEmbedder(t, 2)
	var wg sync.WaitGroup
	for range 4 {
		wg.Go(func() { embedReference(t, e, ref) })
	}
	wg.Wait()
}
```

- [ ] **Step 8: Finish the shared-process test**

In `main_model_test.go`, add `"github.com/shopnexus/ai/embed"` to the imports and replace the Task 5 comment with:

```go
	e, err := embed.New(embed.Config{
		Models:     map[string]string{"siglip2-so400m-patch16-384": filepath.Join(models, "siglip2-so400m-patch16-384")},
		NumThreads: 2, MaxConcurrent: 1,
	})
	if err != nil {
		t.Fatal(err)
	}
	defer e.Close()
	res, err := e.Embed(context.Background(), "siglip2-so400m-patch16-384", []embed.Input{{Text: "a red circle"}})
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Vectors[0]) != embed.Dimensions {
		t.Errorf("dimensions = %d", len(res.Vectors[0]))
	}
	// Speech still works after the embedder loaded.
	if _, err := tr.Transcribe(context.Background(), "gipformer-1.5", filepath.Join(wavs, "1.wav")); err != nil {
		t.Fatal(err)
	}
```

Make `tmp/models` hold the chosen variant: `scripts/fetch-assets.sh siglip-<chosen> tmp/models` (Task 8 folds this into `models`).

Run: `AI_TEST_MODELS=$PWD/tmp/models AI_TEST_WAVS=$PWD/tmp/testwavs go test -race -tags model ./...`
Expected: PASS, every model test, the shared-process one included. A crash or `ORT_API_VERSION` error here is the spec's "Measured first" item 3 failing: stop and report; the fallback is a Python service behind the same alias, which goes back to the spec.

- [ ] **Step 9: Commit**

```bash
git add embed main_model_test.go
git commit -m "feat: SigLIP 2 embedder; ships <int8|fp32> (min cosine <x>, rankings kept)"
```

---

### Task 6: `POST /v1/embeddings`

**Files:**
- Create: `embeddings.go`, `embeddings_test.go`
- Modify: `openai.go:24-39` (`handler`, `newHandler`), `openai_test.go` (the `call` helper)

**Interfaces:**
- Consumes: `embed.Input`, `embed.Result`, `embed.ErrUnknownModel`, `embed.ErrBadImage`, `embed.InputError`, `embed.ImageTokens`.
- Produces:

```go
type embedder interface {
	HasModel(name string) bool
	Embed(ctx context.Context, model string, in []embed.Input) (embed.Result, error)
}

type limits struct {
	maxUpload     int64 // transcription body, bytes
	maxInputs     int   // embeddings inputs per request
	maxImageBytes int   // one decoded image
}

func newHandler(t transcriber, e embedder, l limits, log *slog.Logger) http.Handler
```

- [ ] **Step 1: Change newHandler and keep the transcription tests green**

In `openai.go` replace the `handler` struct and `newHandler`:

```go
type handler struct {
	t   transcriber
	e   embedder
	lim limits
	log *slog.Logger
}

// limits bounds the request bodies.
type limits struct {
	maxUpload     int64 // transcription file, bytes
	maxInputs     int   // embeddings inputs per request
	maxImageBytes int   // one image after base64 decoding
}

// newHandler serves OpenAI's POST /v1/audio/transcriptions and
// POST /v1/embeddings, and the probes.
func newHandler(t transcriber, e embedder, l limits, log *slog.Logger) http.Handler {
	h := &handler{t: t, e: e, lim: l, log: log}
	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/audio/transcriptions", h.transcriptions)
	mux.HandleFunc("POST /v1/embeddings", h.embeddings)
	ok := func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) }
	mux.HandleFunc("GET /healthz", ok) // the process runs
	mux.HandleFunc("GET /readyz", ok)  // the server listens only after every model has loaded
	return mux
}
```

In `transcriptions`, replace `h.maxUpload` with `h.lim.maxUpload` (two places: the `MaxBytesReader` and the `too_large` message).

In `openai_test.go`, the `call` helper builds the handler; change that line to:

```go
	newHandler(f, stubEmbedder{}, limits{maxUpload: limit, maxInputs: 16, maxImageBytes: 10 << 20}, slog.New(slog.DiscardHandler)).ServeHTTP(rec, req)
```

(`stubEmbedder` is defined in `embeddings_test.go`, Step 2.) Search `openai_test.go` for any other `newHandler(` call and change it the same way.

- [ ] **Step 2: Write the failing handler tests**

`embeddings_test.go`:

```go
package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/shopnexus/ai/embed"
)

// stubEmbedder answers vector [i, 0, 0, ...] for input i, or err.
type stubEmbedder struct {
	err   error
	got   *[]embed.Input
	block chan struct{} // when set, Embed waits on it or on ctx
}

func (s stubEmbedder) HasModel(name string) bool { return name == "siglip2-so400m-patch16-384" }

func (s stubEmbedder) Embed(ctx context.Context, _ string, in []embed.Input) (embed.Result, error) {
	if s.got != nil {
		*s.got = in
	}
	if s.block != nil {
		select {
		case <-s.block:
		case <-ctx.Done():
			return embed.Result{}, ctx.Err()
		}
	}
	if s.err != nil {
		return embed.Result{}, s.err
	}
	res := embed.Result{Vectors: make([][]float32, len(in))}
	for i := range in {
		res.Vectors[i] = []float32{float32(i), 0, 0}
		if in[i].Image != nil {
			res.Tokens += embed.ImageTokens
		} else {
			res.Tokens += 3
		}
	}
	return res, nil
}

func postEmbeddings(t *testing.T, e embedder, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/v1/embeddings", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	newHandler(&fake{}, e, limits{maxUpload: 1 << 20, maxInputs: 3, maxImageBytes: 1 << 10}, slog.New(slog.DiscardHandler)).ServeHTTP(rec, req)
	return rec
}

func errCode(t *testing.T, rec *httptest.ResponseRecorder) string {
	t.Helper()
	var r struct {
		Error struct{ Code, Message string } `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &r); err != nil {
		t.Fatalf("body %q: %v", rec.Body, err)
	}
	return r.Error.Code
}

const pngURL = "data:image/png;base64,iVBORw0KGgo="

func TestEmbeddingsMixesTextAndImages(t *testing.T) {
	var got []embed.Input
	rec := postEmbeddings(t, stubEmbedder{got: &got},
		`{"model":"siglip2-so400m-patch16-384","input":["a blue bicycle","`+pngURL+`"]}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d: %s", rec.Code, rec.Body)
	}
	if got[0].Text != "a blue bicycle" || got[0].Image != nil {
		t.Errorf("input 0 = %+v", got[0])
	}
	if !bytes.Equal(got[1].Image, []byte("\x89PNG\r\n\x1a\n")) {
		t.Errorf("input 1 image = %q", got[1].Image)
	}
	var r struct {
		Object string `json:"object"`
		Model  string `json:"model"`
		Data   []struct {
			Object    string    `json:"object"`
			Index     int       `json:"index"`
			Embedding []float32 `json:"embedding"`
		} `json:"data"`
		Usage struct {
			PromptTokens int `json:"prompt_tokens"`
			TotalTokens  int `json:"total_tokens"`
		} `json:"usage"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &r); err != nil {
		t.Fatal(err)
	}
	if r.Object != "list" || r.Model != "siglip2-so400m-patch16-384" || len(r.Data) != 2 {
		t.Fatalf("reply = %+v", r)
	}
	if r.Data[1].Index != 1 || r.Data[1].Object != "embedding" || r.Data[1].Embedding[0] != 1 {
		t.Errorf("data[1] = %+v", r.Data[1])
	}
	if r.Usage.PromptTokens != 3+embed.ImageTokens || r.Usage.TotalTokens != r.Usage.PromptTokens {
		t.Errorf("usage = %+v", r.Usage)
	}
}

func TestEmbeddingsTakesOneString(t *testing.T) {
	rec := postEmbeddings(t, stubEmbedder{}, `{"model":"siglip2-so400m-patch16-384","input":"a cat"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d: %s", rec.Code, rec.Body)
	}
}

func TestEmbeddingsBase64Encoding(t *testing.T) {
	rec := postEmbeddings(t, stubEmbedder{}, `{"model":"siglip2-so400m-patch16-384","input":["a","b"],"encoding_format":"base64"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d: %s", rec.Code, rec.Body)
	}
	var r struct {
		Data []struct {
			Embedding string `json:"embedding"`
		} `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &r); err != nil {
		t.Fatal(err)
	}
	raw, err := base64.StdEncoding.DecodeString(r.Data[1].Embedding)
	if err != nil || len(raw) != 12 {
		t.Fatalf("raw = %v, %v", raw, err)
	}
	if v := math.Float32frombits(binary.LittleEndian.Uint32(raw)); v != 1 {
		t.Errorf("first float = %v, want 1", v)
	}
}

func TestEmbeddingsRefuses(t *testing.T) {
	big := "data:image/png;base64," + base64.StdEncoding.EncodeToString(make([]byte, 2<<10))
	cases := []struct {
		name, body string
		status     int
		code       string
	}{
		{"no model", `{"input":["a"]}`, 400, "invalid_request"},
		{"unknown model", `{"model":"x","input":["a"]}`, 404, "model_not_found"},
		{"no input", `{"model":"siglip2-so400m-patch16-384","input":[]}`, 400, "invalid_request"},
		{"input not strings", `{"model":"siglip2-so400m-patch16-384","input":[[1,2]]}`, 400, "invalid_request"},
		{"too many", `{"model":"siglip2-so400m-patch16-384","input":["a","b","c","d"]}`, 400, "invalid_request"},
		{"bad base64", `{"model":"siglip2-so400m-patch16-384","input":["data:image/png;base64,***"]}`, 400, "invalid_request"},
		{"gif", `{"model":"siglip2-so400m-patch16-384","input":["data:image/gif;base64,R0lG"]}`, 400, "invalid_request"},
		{"image too large", `{"model":"siglip2-so400m-patch16-384","input":["` + big + `"]}`, 413, "too_large"},
		{"bad format", `{"model":"siglip2-so400m-patch16-384","input":["a"],"encoding_format":"int8"}`, 400, "invalid_request"},
		{"not json", `{`, 400, "invalid_request"},
	}
	for _, c := range cases {
		rec := postEmbeddings(t, stubEmbedder{}, c.body)
		if rec.Code != c.status || errCode(t, rec) != c.code {
			t.Errorf("%s: %d %s, want %d %s (%s)", c.name, rec.Code, errCode(t, rec), c.status, c.code, rec.Body)
		}
	}
}

func TestEmbeddingsBadImageNamesTheInput(t *testing.T) {
	rec := postEmbeddings(t, stubEmbedder{err: &embed.InputError{Index: 1, Err: fmt.Errorf("%w: not a JPEG, PNG or WebP", embed.ErrBadImage)}},
		`{"model":"siglip2-so400m-patch16-384","input":["a","`+pngURL+`"]}`)
	if rec.Code != 400 || errCode(t, rec) != "invalid_request" || !strings.Contains(rec.Body.String(), "input 1") {
		t.Errorf("%d %s", rec.Code, rec.Body)
	}
}

func TestEmbeddingsModelFailureIs500(t *testing.T) {
	rec := postEmbeddings(t, stubEmbedder{err: fmt.Errorf("vision tower: boom")}, `{"model":"siglip2-so400m-patch16-384","input":["a"]}`)
	if rec.Code != 500 || errCode(t, rec) != "internal_error" || strings.Contains(rec.Body.String(), "boom") {
		t.Errorf("%d %s", rec.Code, rec.Body)
	}
}

func TestEmbeddingsClientGoneWhileWaiting(t *testing.T) {
	block := make(chan struct{})
	defer close(block)
	ctx, cancel := context.WithCancel(context.Background())
	req := httptest.NewRequest(http.MethodPost, "/v1/embeddings",
		strings.NewReader(`{"model":"siglip2-so400m-patch16-384","input":["a"]}`)).WithContext(ctx)
	var logs bytes.Buffer
	h := newHandler(&fake{}, stubEmbedder{block: block}, limits{maxUpload: 1 << 20, maxInputs: 3, maxImageBytes: 1 << 10},
		slog.New(slog.NewJSONHandler(&logs, nil)))
	done := make(chan struct{})
	go func() { h.ServeHTTP(httptest.NewRecorder(), req); close(done) }()
	time.Sleep(20 * time.Millisecond)
	cancel()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("the handler kept waiting after the client left")
	}
	if !strings.Contains(logs.String(), `"status":499`) {
		t.Errorf("log = %s", logs.String())
	}
}

func TestEmbeddingsLogHoldsNoInput(t *testing.T) {
	var logs bytes.Buffer
	req := httptest.NewRequest(http.MethodPost, "/v1/embeddings",
		strings.NewReader(`{"model":"siglip2-so400m-patch16-384","input":["secret words","`+pngURL+`"]}`))
	newHandler(&fake{}, stubEmbedder{}, limits{maxUpload: 1 << 20, maxInputs: 3, maxImageBytes: 1 << 10},
		slog.New(slog.NewJSONHandler(&logs, nil))).ServeHTTP(httptest.NewRecorder(), req)
	if strings.Contains(logs.String(), "secret") || strings.Contains(logs.String(), "iVBOR") {
		t.Errorf("log holds input: %s", logs.String())
	}
	for _, want := range []string{`"images":1`, `"texts":1`, `"status":200`} {
		if !strings.Contains(logs.String(), want) {
			t.Errorf("log lacks %s: %s", want, logs.String())
		}
	}
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `go test -run TestEmbeddings .`
Expected: FAIL, `h.embeddings undefined`.

- [ ] **Step 4: Implement**

`embeddings.go`:

```go
package main

import (
	"context"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/shopnexus/ai/embed"
)

type embedder interface {
	HasModel(name string) bool
	Embed(ctx context.Context, model string, in []embed.Input) (embed.Result, error)
}

// imageTypes are the data URL prefixes the service takes.
var imageTypes = []string{"data:image/jpeg;base64,", "data:image/png;base64,", "data:image/webp;base64,"}

type embeddingsRequest struct {
	Model          string          `json:"model"`
	Input          json.RawMessage `json:"input"`
	EncodingFormat string          `json:"encoding_format"`
}

// embeddings serves OpenAI's POST /v1/embeddings. An input that starts with
// data:image/ is an image; anything else is text for the text tower.
func (h *handler) embeddings(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	var images, texts int
	var req embeddingsRequest
	attrs := func() []any { return []any{"model", req.Model, "images", images, "texts", texts} }
	fail := func(e apiError, cause error) {
		writeError(w, e)
		level := slog.LevelInfo
		if e.status >= 500 {
			level = slog.LevelError
		}
		h.log.Log(r.Context(), level, "embedding", append(attrs(),
			"status", e.status, "code", e.code, "err", errString(cause), "ms", time.Since(start).Milliseconds())...)
	}

	// A base64 image is 4/3 of its bytes; 64 KiB covers the JSON around them.
	r.Body = http.MaxBytesReader(w, r.Body, int64(h.lim.maxInputs)*int64(h.lim.maxImageBytes)*4/3+64<<10)
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			fail(apiError{http.StatusRequestEntityTooLarge, "too_large", "the body is too large"}, err)
			return
		}
		fail(apiError{http.StatusBadRequest, "invalid_request", "the body must be a JSON object"}, err)
		return
	}
	var inputs []string
	var one string
	if json.Unmarshal(req.Input, &one) == nil {
		inputs = []string{one}
	} else if err := json.Unmarshal(req.Input, &inputs); err != nil {
		fail(apiError{http.StatusBadRequest, "invalid_request", "input must be a string or an array of strings"}, err)
		return
	}
	switch {
	case req.Model == "":
		fail(apiError{http.StatusBadRequest, "invalid_request", "model is required"}, nil)
		return
	case len(inputs) == 0:
		fail(apiError{http.StatusBadRequest, "invalid_request", "input is required"}, nil)
		return
	case len(inputs) > h.lim.maxInputs:
		fail(apiError{http.StatusBadRequest, "invalid_request", fmt.Sprintf("send at most %d inputs", h.lim.maxInputs)}, nil)
		return
	case req.EncodingFormat != "" && req.EncodingFormat != "float" && req.EncodingFormat != "base64":
		fail(apiError{http.StatusBadRequest, "invalid_request", "encoding_format must be float or base64"}, nil)
		return
	case !h.e.HasModel(req.Model):
		fail(apiError{http.StatusNotFound, "model_not_found", fmt.Sprintf("the model %q does not exist", req.Model)}, nil)
		return
	}

	in := make([]embed.Input, len(inputs))
	for i, s := range inputs {
		if !strings.HasPrefix(s, "data:image/") {
			in[i] = embed.Input{Text: s}
			texts++
			continue
		}
		images++
		payload, ok := "", false
		for _, p := range imageTypes {
			if rest, found := strings.CutPrefix(s, p); found {
				payload, ok = rest, true
				break
			}
		}
		if !ok {
			fail(apiError{http.StatusBadRequest, "invalid_request", fmt.Sprintf("input %d: images must be JPEG, PNG or WebP data URLs in base64", i)}, nil)
			return
		}
		if base64.StdEncoding.DecodedLen(len(payload)) > h.lim.maxImageBytes+2 {
			fail(apiError{http.StatusRequestEntityTooLarge, "too_large", fmt.Sprintf("input %d: the image is larger than %d MB", i, h.lim.maxImageBytes>>20)}, nil)
			return
		}
		b, err := base64.StdEncoding.DecodeString(payload)
		if err != nil {
			fail(apiError{http.StatusBadRequest, "invalid_request", fmt.Sprintf("input %d: the base64 does not decode", i)}, err)
			return
		}
		if len(b) > h.lim.maxImageBytes {
			fail(apiError{http.StatusRequestEntityTooLarge, "too_large", fmt.Sprintf("input %d: the image is larger than %d MB", i, h.lim.maxImageBytes>>20)}, nil)
			return
		}
		in[i] = embed.Input{Image: b}
	}

	res, err := h.e.Embed(r.Context(), req.Model, in)
	if err != nil {
		var bad *embed.InputError
		switch {
		case r.Context().Err() != nil:
			h.log.Info("embedding", append(attrs(), "status", 499, "code", "client_gone", "ms", time.Since(start).Milliseconds())...)
		case errors.As(err, &bad) && errors.Is(err, embed.ErrBadImage):
			fail(apiError{http.StatusBadRequest, "invalid_request", bad.Error()}, err)
		case errors.Is(err, embed.ErrUnknownModel):
			fail(apiError{http.StatusNotFound, "model_not_found", fmt.Sprintf("the model %q does not exist", req.Model)}, err)
		default:
			fail(apiError{http.StatusInternalServerError, "internal_error", "embedding failed"}, err)
		}
		return
	}

	data := make([]map[string]any, len(res.Vectors))
	for i, v := range res.Vectors {
		var emb any = v
		if req.EncodingFormat == "base64" {
			raw := make([]byte, 4*len(v))
			for k, x := range v {
				binary.LittleEndian.PutUint32(raw[4*k:], math.Float32bits(x))
			}
			emb = base64.StdEncoding.EncodeToString(raw)
		}
		data[i] = map[string]any{"object": "embedding", "index": i, "embedding": emb}
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"object": "list", "model": req.Model, "data": data,
		// LiteLLM prices the call from usage, not from the base64 length.
		"usage": map[string]int{"prompt_tokens": res.Tokens, "total_tokens": res.Tokens},
	})
	// The inputs stay out of the log: a photo or a query is the person's.
	h.log.Info("embedding", append(attrs(), "tokens", res.Tokens, "status", http.StatusOK,
		"ms", time.Since(start).Milliseconds())...)
}
```

- [ ] **Step 5: Run every unit test**

Run: `go vet ./... && go test -race ./...`
Expected: PASS, the transcription tests included.

- [ ] **Step 6: Commit**

```bash
git add embeddings.go embeddings_test.go openai.go openai_test.go
git commit -m "feat: OpenAI's POST /v1/embeddings with images as data URLs"
```

---

### Task 7: Configuration and wiring

**Files:**
- Modify: `config.go`, `config_test.go`, `main.go`

**Interfaces:**
- Consumes: `parseModels`, `embed.New`, `embed.Config`, `newHandler(t, e, limits, log)`.
- Produces: `Config.EmbedModels map[string]string`, `Config.EmbedMaxInputs`, `Config.EmbedMaxConcurrent`, `Config.EmbedMaxImageMB int`.

- [ ] **Step 1: Write the failing config tests**

In `config_test.go`, add to the `base` map of `env`:

```go
		"AI_EMBED_MODELS":         "siglip2-so400m-patch16-384=/models/siglip2-so400m-patch16-384",
		"AI_EMBED_MAX_INPUTS":     "16",
		"AI_EMBED_MAX_CONCURRENT": "2",
		"AI_EMBED_MAX_IMAGE_MB":   "10",
```

and add:

```go
func TestLoadConfigEmbed(t *testing.T) {
	c, err := loadConfig(env(nil))
	if err != nil {
		t.Fatal(err)
	}
	if want := map[string]string{"siglip2-so400m-patch16-384": "/models/siglip2-so400m-patch16-384"}; !maps.Equal(c.EmbedModels, want) {
		t.Errorf("EmbedModels = %v", c.EmbedModels)
	}
	if c.EmbedMaxInputs != 16 || c.EmbedMaxConcurrent != 2 || c.EmbedMaxImageMB != 10 {
		t.Errorf("embed numbers = %d %d %d", c.EmbedMaxInputs, c.EmbedMaxConcurrent, c.EmbedMaxImageMB)
	}
}

func TestLoadConfigNamesMissingEmbedVariables(t *testing.T) {
	_, err := loadConfig(env(map[string]string{"AI_EMBED_MODELS": "", "AI_EMBED_MAX_IMAGE_MB": ""}))
	if err == nil || !strings.Contains(err.Error(), "AI_EMBED_MODELS") || !strings.Contains(err.Error(), "AI_EMBED_MAX_IMAGE_MB") {
		t.Errorf("err = %v", err)
	}
}

func TestLoadConfigRefusesBadEmbedModels(t *testing.T) {
	_, err := loadConfig(env(map[string]string{"AI_EMBED_MODELS": "siglip"}))
	if err == nil || !strings.Contains(err.Error(), "AI_EMBED_MODELS") {
		t.Errorf("err = %v", err)
	}
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `go test -run TestLoadConfig .`
Expected: FAIL, `c.EmbedModels undefined`.

- [ ] **Step 3: Implement**

In `config.go`, add to `Config`:

```go
	EmbedModels        map[string]string // AI_EMBED_MODELS: name=dir pairs, comma-separated
	EmbedMaxInputs     int               // AI_EMBED_MAX_INPUTS: inputs per request
	EmbedMaxConcurrent int               // AI_EMBED_MAX_CONCURRENT: requests embedding at once
	EmbedMaxImageMB    int               // AI_EMBED_MAX_IMAGE_MB: one image after base64 decoding
```

and in `loadConfig`, after `c.MaxAudioSeconds = ...`:

```go
	if v := str("AI_EMBED_MODELS"); v != "" {
		m, err := parseModels(v)
		if err != nil {
			bad = append(bad, "AI_EMBED_MODELS: "+err.Error())
		}
		c.EmbedModels = m
	}
	c.EmbedMaxInputs = positive("AI_EMBED_MAX_INPUTS")
	c.EmbedMaxConcurrent = positive("AI_EMBED_MAX_CONCURRENT")
	c.EmbedMaxImageMB = positive("AI_EMBED_MAX_IMAGE_MB")
```

In `main.go`, add `"github.com/shopnexus/ai/embed"` to the imports; after `defer t.Close()` add:

```go
	e, err := embed.New(embed.Config{
		Models:        cfg.EmbedModels,
		NumThreads:    cfg.NumThreads,
		MaxConcurrent: cfg.EmbedMaxConcurrent,
	})
	if err != nil {
		return err
	}
	defer e.Close()
```

and replace the `Handler:` line with:

```go
		Handler: newHandler(t, e, limits{
			maxUpload:     int64(cfg.MaxUploadMB) << 20,
			maxInputs:     cfg.EmbedMaxInputs,
			maxImageBytes: cfg.EmbedMaxImageMB << 20,
		}, log),
```

and the `listening` log line with:

```go
	log.Info("listening", "addr", cfg.Addr, "stt_models", t.Models(), "embed_models", e.Models())
```

- [ ] **Step 4: Run every test, then the binary**

Run: `go vet ./... && go test -race ./...`
Expected: PASS.

Run, with the chosen variant in `tmp/models`:

```bash
AI_ADDR=127.0.0.1:18000 AI_STT_MODELS=gipformer-1.5=$PWD/tmp/models/gipformer-1.5 AI_VAD_MODEL=$PWD/tmp/models/silero_vad.onnx \
AI_NUM_THREADS=4 AI_MAX_CONCURRENT=2 AI_MAX_UPLOAD_MB=100 AI_MAX_AUDIO_SECONDS=300 \
AI_EMBED_MODELS=siglip2-so400m-patch16-384=$PWD/tmp/models/siglip2-so400m-patch16-384 \
AI_EMBED_MAX_INPUTS=16 AI_EMBED_MAX_CONCURRENT=2 AI_EMBED_MAX_IMAGE_MB=10 go run . > tmp/run.log 2>&1 &
sleep 60
img=$(base64 -w0 embed/testdata/red-circle.png)
curl -s localhost:18000/v1/embeddings -H 'Content-Type: application/json' \
  -d "{\"model\":\"siglip2-so400m-patch16-384\",\"input\":[\"a red circle\",\"data:image/png;base64,$img\"]}" \
  | python3 -c "import sys,json;r=json.load(sys.stdin);print(len(r['data']),len(r['data'][0]['embedding']),r['usage'])"
kill %1
```

Expected: `2 1152 {'prompt_tokens': 581, 'total_tokens': 581}` (5 tokens for the text, per the reference, plus 576); `tmp/run.log` has one `embedding` line without the text.

- [ ] **Step 5: Commit**

```bash
git add config.go config_test.go main.go
git commit -m "feat: the AI_EMBED_ variables, all required"
```

---

### Task 8: The image, the CI tests and the README

**Files:**
- Modify: `scripts/fetch-assets.sh`, `scripts/assets.sha256`, `Dockerfile`, `README.md`

**Interfaces:**
- Produces: `ghcr.io/shopnexus/ai:main` holding `/models/siglip2-so400m-patch16-384/` of the chosen variant; plan 2 points `AI_EMBED_MODELS` at it.

- [ ] **Step 1: Fold the chosen variant into `models`**

In `scripts/fetch-assets.sh`, inside the `models)` case after the Silero line, add the three (int8) or four (fp32) `curl` lines of the chosen `siglip-*` case, with the same target paths. In `scripts/assets.sha256`, add the chosen variant's lines again with the prefix `models/` instead of `siglip-int8/` or `siglip-fp32/`. Keep the `siglip-fp32` and `siglip-int8` kinds for the next measurement.

Run: `rm -rf tmp/models && scripts/fetch-assets.sh models tmp/models && ls tmp/models/siglip2-so400m-patch16-384`
Expected: the variant's files, checksums pass.

- [ ] **Step 2: Build the image; its test stage runs every model test**

The test stage already runs `AI_TEST_MODELS=/models ... go test -race -tags model ./...` and `COPY . .` brings `embed/testdata`, so the embed model tests run with no Dockerfile change. Check `.dockerignore` does not drop `embed/testdata` (it holds `.git`, `tmp`, `ai`).

Run: `docker build -t shopnexus-ai:local . 2>&1 | tail -20 && docker image inspect shopnexus-ai:local --format '{{.Size}}'`
Expected: the build passes (the test stage ran the embed tests); the size is about 2 GB for int8 or 5.4 GB for fp32.

Run the container and check memory once loaded:

```bash
docker run -d --name ai-probe -p 127.0.0.1:18000:8000 \
  -e AI_ADDR=:8000 -e AI_STT_MODELS=gipformer-1.5=/models/gipformer-1.5 -e AI_VAD_MODEL=/models/silero_vad.onnx \
  -e AI_NUM_THREADS=4 -e AI_MAX_CONCURRENT=2 -e AI_MAX_UPLOAD_MB=100 -e AI_MAX_AUDIO_SECONDS=300 \
  -e AI_EMBED_MODELS=siglip2-so400m-patch16-384=/models/siglip2-so400m-patch16-384 \
  -e AI_EMBED_MAX_INPUTS=16 -e AI_EMBED_MAX_CONCURRENT=2 -e AI_EMBED_MAX_IMAGE_MB=10 shopnexus-ai:local
sleep 90; docker stats --no-stream ai-probe; docker rm -f ai-probe
```

Expected: memory in the stats line. Write it into the README (Step 3) and pass it to plan 2, which sets the pod's memory limit from it.

- [ ] **Step 3: README**

Edit `README.md`:
- First paragraph: `ai` also embeds images and text with SigLIP 2 (`google/siglip2-so400m-patch16-384`, Apache 2.0), ONNX from `onnx-community/siglip2-so400m-patch16-384-ONNX` at the pinned revision, `<variant>`.
- Under API, a section `POST /v1/embeddings`, JSON: the fields (`model` from `AI_EMBED_MODELS`, `input` a string or up to `AI_EMBED_MAX_INPUTS` strings, `encoding_format` `float` or `base64`), the data URL rule, the reply with `usage` (576 per image), that EXIF orientation is not applied (callers send upright photos), and the errors table rows `invalid_request` (bad image, bad base64, too many inputs), `too_large` (an image over `AI_EMBED_MAX_IMAGE_MB`), `model_not_found`, `internal_error`.
- Request handling: images in one vision run, texts in one text run; `AI_EMBED_MAX_CONCURRENT` requests embed at once; one log line per request without inputs.
- Configuration table: the four `AI_EMBED_*` rows with chart and compose values `siglip2-so400m-patch16-384=/models/siglip2-so400m-patch16-384`, `16`, `2`, `10`; `AI_NUM_THREADS` now also "onnxruntime threads per embed session".
- Image: the new size and the idle memory from Step 2; why `onnxruntime_go` stays at v1.32.1.
- Development: `uv run scripts/siglip-reference.py embed/testdata` regenerates the reference; the measurement command from Task 5 Step 6 and its last result.

Per the user's CLAUDE.md, run the `humanizing-writing` skill and its checker on the README changes before committing.

- [ ] **Step 4: Commit**

```bash
git add scripts/fetch-assets.sh scripts/assets.sha256 Dockerfile README.md
git commit -m "build: the image ships SigLIP 2, and its README"
```

Push only after plan 2's chart and compose carry the `AI_EMBED_*` variables (Global Constraints, rollout order).
