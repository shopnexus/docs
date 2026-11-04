# Infra on k3d: dev and prod stacks — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the umbrella's `deploy/` with `infra/`: one k3d cluster running a dev and a prod ShopNexus stack, deployed by Argo CD from a Helm chart, with Postgres (CloudNativePG) and Restate (restate-operator) in HA on prod.

**Architecture:** `infra/cluster/up.sh` creates a k3d cluster (1 server, 3 agents), configures k3s's bundled Traefik for one of two edge modes, installs Argo CD and applies an app-of-apps. Argo installs the platform operators and syncs the `infra/stack` chart twice, once per stack namespace. Image Updater rolls dev on every `:main` digest and prod on every semver tag.

**Tech Stack:** k3d / k3s, Traefik (k3s bundled), Helm 3, Argo CD, Argo CD Image Updater v1 (CRD), CloudNativePG, ParadeDB image, restate-operator, Restate 1.8, RustFS, Sealed Secrets, GitHub Actions, GHCR, yq, kubeconform.

**Spec:** `docs/superpowers/specs/2026-11-04-infra-k3d-stacks-design.md` (umbrella path; the file is in the `docs` submodule).

## Global Constraints

- Prod domain `shopnexus.id.vn`, dev domain `dev.shopnexus.id.vn`. Hosts: `<domain>` website, `api.<domain>` server, `ops.<domain>` console, `media.<domain>` RustFS, `docs.<domain>` docs.
- Namespaces `shopnexus-dev` and `shopnexus-prod`; Restate clusters `restate-dev` and `restate-prod` (each its own namespace).
- Replicas: dev everything 1. Prod server 3, website 2, docs 1, postgres 2, restate 3, rustfs 1.
- Nothing from `deploy/` carries over, including names.
- Server rule (`server/CLAUDE.md`): configuration has no defaults; every variable is set, an empty value is set to the empty string. New variables follow it.
- Server rule: use the newest release of every component; look a version up before pinning it.
- Commits carry no `Co-Authored-By` trailer.
- README and `ARCHITECTURE.md` prose goes through the `humanizing-writing` skill; this plan and the spec do not.
- Pushing a branch, merging to `main`, tagging a release and every `sudo` command on the server are outward-facing: confirm with the user before each one.
- Server host: `khoakomlem-internal.ddns.net`. Its Caddy is shared with other projects; only `conf.d/shopnexus.caddy` and the stale `*.toanehihi.io.vn` blocks (the user's own) may change.

## Review Focus

1. A change to the server's ConfigMap must start a new server version; a `RestateDeployment` keyed on the pod template hash otherwise keeps running the old config. Pinned by the `checksum/env` check in Task 9.
2. A server variable missing from both the ConfigMap and the Secret crash-loops the pod with "X is not set". Pinned by the full-variable check in Task 9 and the key-list check in Task 11.
3. Re-running `seal.sh` must keep the JWT, staff and Restate keys; regenerating them signs everyone out and breaks Restate's request signing. Pinned by the idempotence test in Task 11.
4. Image Updater writes Helm parameters into the stack Applications, and the root app's self-heal reverts them. Pinned by `ignoreDifferences` in Task 12 and the check in Task 16 step 9.
5. A presigned upload passes Caddy and Traefik before RustFS; a rewritten Host header breaks its signature. Pinned by the upload drill in Task 17.

---

### Task 1: Tools and branches

**Files:** none in git.

**Interfaces:**
- Produces: `helm`, `kubeconform`, `yq`, `kubeseal`, `kubectl` on PATH locally (`~/.local/bin`) and on the server (`~/.local/bin`); branch `infra-k3d` in the umbrella, `server`, `docs`, `website`.

- [ ] **Step 1: Install the CLIs locally**

Each tool: look up the newest release, download the linux-amd64 binary into `~/.local/bin`.

```bash
mkdir -p ~/.local/bin && cd "$(mktemp -d)"
H=$(gh release view -R helm/helm --json tagName -q .tagName)
curl -fsSL "https://get.helm.sh/helm-$H-linux-amd64.tar.gz" | tar xz && mv linux-amd64/helm ~/.local/bin/
K=$(gh release view -R yannh/kubeconform --json tagName -q .tagName)
curl -fsSL "https://github.com/yannh/kubeconform/releases/download/$K/kubeconform-linux-amd64.tar.gz" | tar xz && mv kubeconform ~/.local/bin/
Y=$(gh release view -R mikefarah/yq --json tagName -q .tagName)
curl -fsSL -o ~/.local/bin/yq "https://github.com/mikefarah/yq/releases/download/$Y/yq_linux_amd64" && chmod +x ~/.local/bin/yq
S=$(gh release view -R bitnami-labs/sealed-secrets --json tagName -q .tagName)
curl -fsSL "https://github.com/bitnami-labs/sealed-secrets/releases/download/$S/kubeseal-${S#v}-linux-amd64.tar.gz" | tar xz kubeseal && mv kubeseal ~/.local/bin/
KC=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
curl -fsSL -o ~/.local/bin/kubectl "https://dl.k8s.io/release/$KC/bin/linux/amd64/kubectl" && chmod +x ~/.local/bin/kubectl
helm version --short; kubeconform -v; yq --version; kubeseal --version; kubectl version --client
```

Expected: five version lines.

- [ ] **Step 2: Install the same CLIs on the server**

The SSH key has a passphrase; load it into an agent first (the user gives the passphrase). Run Step 1's commands over SSH, replacing `gh release view` with the GitHub API since `gh` is not on the server:

```bash
ssh khoakomlem-internal.ddns.net 'bash -s' <<'EOF'
set -e
mkdir -p ~/.local/bin && cd "$(mktemp -d)"
tag() { curl -fsSL "https://api.github.com/repos/$1/releases/latest" | grep -m1 '"tag_name"' | cut -d'"' -f4; }
H=$(tag helm/helm); curl -fsSL "https://get.helm.sh/helm-$H-linux-amd64.tar.gz" | tar xz && mv linux-amd64/helm ~/.local/bin/
S=$(tag bitnami-labs/sealed-secrets); curl -fsSL "https://github.com/bitnami-labs/sealed-secrets/releases/download/$S/kubeseal-${S#v}-linux-amd64.tar.gz" | tar xz kubeseal && mv kubeseal ~/.local/bin/
Y=$(tag mikefarah/yq); curl -fsSL -o ~/.local/bin/yq "https://github.com/mikefarah/yq/releases/download/$Y/yq_linux_amd64" && chmod +x ~/.local/bin/yq
~/.local/bin/helm version --short; ~/.local/bin/kubeseal --version; k3d version
EOF
```

Expected: helm and kubeseal versions, `k3d version v5.8.3` or newer. The server already has `kubectl` and `docker`.

- [ ] **Step 3: Create the branches**

```bash
cd ~/shopnexus && git switch -c infra-k3d
for r in server docs website; do git -C "$r" switch -c infra-k3d; done
```

---

### Task 2: Server: `RESTATE_REGISTER`

**Files:**
- Modify: `server/internal/platform/config/config.go` (RestateConfig, Load)
- Modify: `server/internal/platform/config/config_test.go`
- Modify: `server/internal/app/app.go` (`startRestate`)
- Modify: `server/internal/platform/restatex/restatetest/restatetest.go` (`ConfigForMain`)
- Modify: `server/.env.example`
- Modify: `server/ARCHITECTURE.md`

**Interfaces:**
- Produces: env `RESTATE_REGISTER` = `true` | `false`, required. `false` makes the server serve its Restate endpoint without registering it. The chart (Task 9) sets `false`.

- [ ] **Step 1: Write the failing tests**

In `config_test.go`, add to `required()` after `"RESTATE_IDENTITY_KEY"`:

```go
		"RESTATE_REGISTER":             "true",
```

In `TestLoadAllSet`, add `"RESTATE_REGISTER": "false",` to the `maps.Copy` map, and change the `Restate` literal in `want` to:

```go
		Restate: RestateConfig{
			IngressURL: "http://restate:8080", AdminURL: "http://restate:9070",
			ListenAddr: "127.0.0.1:9999", EndpointURL: "http://host:9999", IdentityKey: "publickeyv1_test",
			Register: false,
		},
```

Add a test at the end of the file:

```go
// RESTATE_REGISTER takes true or false and nothing else.
func TestLoadRestateRegister(t *testing.T) {
	t.Parallel()
	for value, want := range map[string]bool{"true": true, "false": false} {
		env := required()
		env["RESTATE_REGISTER"] = value
		got, err := Load(lookup(env))
		if err != nil {
			t.Fatalf("RESTATE_REGISTER=%s: %v", value, err)
		}
		if got.Restate.Register != want {
			t.Errorf("RESTATE_REGISTER=%s: Register = %v", value, got.Restate.Register)
		}
	}
	env := required()
	env["RESTATE_REGISTER"] = "yes"
	if _, err := Load(lookup(env)); err == nil || !strings.Contains(err.Error(), `RESTATE_REGISTER="yes"`) {
		t.Fatalf("RESTATE_REGISTER=yes: %v", err)
	}
}
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `cd server && go test ./internal/platform/config/`
Expected: FAIL to compile with `unknown field Register in struct literal`.

- [ ] **Step 3: Implement**

In `config.go`, add the field to `RestateConfig` after `IdentityKey`:

```go
	// Register (RESTATE_REGISTER) is true when this process registers its
	// endpoint with the Restate admin API at start, as make run does, and
	// false when something else registers it, as restate-operator does in
	// the cluster.
	Register bool
```

In `Load`, add to the `Restate: RestateConfig{...}` literal after `IdentityKey`:

```go
			Register:      oneOf("RESTATE_REGISTER", "true", "false") == "true",
```

In `restatetest.go`, add `Register: true,` to the literal returned by `ConfigForMain`:

```go
	return config.RestateConfig{
		IngressURL: ingressURL, AdminURL: adminURL, ListenAddr: "127.0.0.1:0", EndpointURL: "",
		ServicePrefix: Prefix(), IdentityKey: key, Register: true,
	}, nil
```

In `app.go`, `startRestate`, insert after the `restatex.Serve` error check:

```go
	if !cfg.Register {
		log.InfoContext(ctx, "restate endpoint served; registration is left to restate-operator", "addr", cfg.ListenAddr)
		return ep, nil
	}
```

In `.env.example`, after `RESTATE_SERVICE_PREFIX=`:

```
# true registers this process's endpoint with Restate at start; the cluster
# sets false because restate-operator registers each version itself.
RESTATE_REGISTER=true
```

- [ ] **Step 4: Run the tests**

Run: `cd server && make test`
Expected: PASS, and golangci-lint reports nothing (exhaustruct sees `Register` set in both literals).

- [ ] **Step 5: Record the decision**

Add to `server/ARCHITECTURE.md`, in the section that describes Restate registration (search for `register`), a paragraph run through the `humanizing-writing` skill with these facts: in the cluster, restate-operator's `RestateDeployment` registers each server version under its own Service and keeps old versions until their invocations finish; the server then runs with `RESTATE_REGISTER=false`; `make run` and the tests keep `true`. Decided 2026-11-04.

- [ ] **Step 6: Commit**

```bash
cd server && git add -A internal .env.example ARCHITECTURE.md
git commit -m "feat: RESTATE_REGISTER=false leaves registration to restate-operator"
```

---

### Task 3: Server image and CI

**Files:**
- Create: `server/Dockerfile`
- Create: `server/.dockerignore`
- Create: `server/.github/workflows/build.yml`

**Interfaces:**
- Produces: image `ghcr.io/shopnexus/server` with binaries `/server` (entrypoint), `/migrate`, `/objectstore-init`, `/keygen`, `/staff`. Tags: `main` and `sha-<sha>` on push to `main`; `X.Y.Z` on tag `vX.Y.Z`. Ports 8080 (HTTP) and 9080 (Restate endpoint, per `RESTATE_LISTEN_ADDR`).

- [ ] **Step 1: Look up base image versions**

`go.mod` says `go 1.27.2`. Check Docker Hub for the newest `golang:1.27.x-alpine` tag and the newest `gcr.io/distroless/static-debian*` (`debian13` if published). Use those tags below.

- [ ] **Step 2: Write the Dockerfile**

```dockerfile
# Every command under cmd/ goes into the image; /server is the default.
FROM golang:1.27.2-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/ ./cmd/...

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/ /
EXPOSE 8080 9080
ENTRYPOINT ["/server"]
```

`.dockerignore`:

```
.env
.restate/
tmp/
bin/
.git/
```

- [ ] **Step 3: Build and check the binaries**

```bash
cd server && docker build -t shopnexus/server:local .
docker run --rm shopnexus/server:local 2>&1 | head -3
docker run --rm --entrypoint /migrate shopnexus/server:local
docker run --rm --entrypoint /keygen shopnexus/server:local
```

Expected: `/server` prints `config:` followed by `APP_ENV is not set` lines (no `.env` error, because a missing `.env` is ignored); `/migrate` prints `DATABASE_URL is required`; `/keygen` prints `JWT_KEY_ID=...` and `JWT_PRIVATE_KEY=...`.

- [ ] **Step 4: Write the workflow**

`server/.github/workflows/build.yml` (the same file goes to `docs` and `website` in Tasks 4 and 5):

```yaml
name: Build image

# Builds and pushes the image to GHCR. Argo CD Image Updater in the umbrella
# repo deploys it: :main to dev by digest, X.Y.Z to prod by semver.
on:
  push:
    branches: [main]
    tags: ["v*"]
  workflow_dispatch:

concurrency:
  group: build-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=raw,value=main,enable=${{ github.ref == 'refs/heads/main' }}
            type=sha,prefix=sha-,format=long,enable=${{ github.ref == 'refs/heads/main' }}
            type=semver,pattern={{version}}
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

Check the newest major of each action (`actions/checkout`, `docker/*`) on GitHub and use it.

- [ ] **Step 5: Commit**

```bash
cd server && git add Dockerfile .dockerignore .github/workflows/build.yml
git commit -m "build: an image with every command, pushed to GHCR on main and on v* tags"
```

---

### Task 4: Docs image and CI

**Files:**
- Create: `docs/Dockerfile`
- Create: `docs/.dockerignore`
- Create: `docs/.github/workflows/build.yml`

**Interfaces:**
- Produces: image `ghcr.io/shopnexus/docs`, nginx serving the Astro build on port 80. Same tags as Task 3.

- [ ] **Step 1: Write the Dockerfile**

Look up the newest `oven/bun` 1.x and `nginx` stable-alpine tags and pin them.

```dockerfile
# The Astro site in web/, built at the root path (DOCS_BASE empty), served by nginx.
FROM oven/bun:1 AS build
WORKDIR /src/web
COPY web/package.json web/bun.lock ./
RUN bun install --frozen-lockfile
COPY web/ ./
ENV DOCS_BASE=/
RUN bun run build

FROM nginx:stable-alpine
COPY --from=build /src/web/dist /usr/share/nginx/html
EXPOSE 80
```

`.dockerignore`:

```
web/node_modules
web/dist
typst/
manual/
superpowers/
```

- [ ] **Step 2: Build and serve**

```bash
cd docs && docker build -t shopnexus/docs:local .
docker run --rm -d -p 127.0.0.1:18090:80 --name docs-check shopnexus/docs:local
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18090/
docker rm -f docs-check
```

Expected: `200`.

- [ ] **Step 3: Add the workflow**

Copy `server/.github/workflows/build.yml` from Task 3 Step 4 unchanged to `docs/.github/workflows/build.yml`. The existing `pages.yml` stays.

- [ ] **Step 4: Commit**

```bash
cd docs && git add Dockerfile .dockerignore .github/workflows/build.yml
git commit -m "build: an nginx image of the docs site, pushed to GHCR"
```

---

### Task 5: Website API rewrite and CI tags

**Files:**
- Modify: `website/Dockerfile` (build stage)
- Modify: `website/.github/workflows/build.yml`

**Interfaces:**
- Produces: image `ghcr.io/shopnexus/website` whose `/api/v1/*` rewrite targets `http://server-api:8080/v1`, the Service in its own namespace. Same tags as Task 3.

- [ ] **Step 1: Add the build argument**

In the `build` stage of `website/Dockerfile`, before `RUN pnpm build`:

```dockerfile
# next.config.ts bakes the /api/v1 rewrite at build time. The in-cluster
# Service name resolves in whichever stack namespace the website runs in.
ARG NEXT_PUBLIC_API_URL=http://server-api:8080/v1
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
```

- [ ] **Step 2: Check the baked rewrite**

```bash
cd website && docker build -t shopnexus/website:local .
docker run --rm --entrypoint cat shopnexus/website:local .next/routes-manifest.json | grep -o 'http://server-api:8080/v1[^"]*'
```

Expected: `http://server-api:8080/v1/:path*`.

- [ ] **Step 3: Replace the workflow**

Replace `website/.github/workflows/build.yml` with the file from Task 3 Step 4.

- [ ] **Step 4: Commit**

```bash
cd website && git add Dockerfile .github/workflows/build.yml
git commit -m "build: rewrite the API to server-api, and tag images on v*"
```

---

### Task 6: Chart skeleton and checks

**Files:**
- Delete: `deploy/` (whole directory)
- Create: `infra/stack/Chart.yaml`, `infra/stack/values.yaml`, `infra/stack/values-dev.yaml`, `infra/stack/values-prod.yaml`, `infra/stack/.helmignore`
- Create: `infra/stack/templates/_helpers.tpl`, `infra/stack/templates/validate.yaml`
- Create: `infra/check.sh`
- Create: `.github/workflows/infra.yml`

**Interfaces:**
- Produces, used by every later chart task:
  - Values keys exactly as in `values.yaml` below.
  - Helpers: `sn.labels` (root), `sn.podLabels` (dict root name), `sn.image` (an `images.*` entry), `sn.host` (dict root sub), `sn.restate` (root) → `restate-<stack>`, `sn.wave` (string), `sn.preferRole` (string), `sn.spread` (app name).
  - `infra/check.sh` with functions `render <stack> [helm args]`, `q <yaml> <yq expr>`, `eq <got> <want> <message>`, `ok <condition-exit-status> <message>`, and variables `$dev`, `$prod`. Later tasks add blocks above the `# ── end of checks ──` line.

- [ ] **Step 1: Remove `deploy/`**

```bash
cd ~/shopnexus && git rm -rq deploy
```

- [ ] **Step 2: Write `check.sh` with the first checks**

`infra/check.sh`:

```bash
#!/usr/bin/env bash
# Renders the stack chart for dev and prod, validates the manifests and
# checks the facts the spec fixes. Run from anywhere: infra/check.sh
set -euo pipefail
cd "$(dirname "$0")"

fails=0
render() { helm template shopnexus stack -f "stack/values-$1.yaml" --namespace "shopnexus-$1" "${@:2}"; }
q() { yq ea "$2" <<<"$1"; }
eq() { [[ "$1" == "$2" ]] || { echo "FAIL: $3: got '$1', want '$2'" >&2; fails=$((fails + 1)); }; }
ok() { (( $1 == 0 )) || { echo "FAIL: $2" >&2; fails=$((fails + 1)); }; }

for s in dev prod; do
  helm lint --quiet stack -f "stack/values-$s.yaml" >/dev/null
  render "$s" | kubeconform -strict -ignore-missing-schemas -summary \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' -
done
dev=$(render dev)
prod=$(render prod)

# ── values ──
if helm template x stack >/dev/null 2>&1; then ok 1 "rendering without a stack values file fails"; fi
if helm template x stack -f stack/values-dev.yaml --set stack=qa >/dev/null 2>&1; then ok 1 "stack must be dev or prod"; fi

# ── end of checks ──
(( fails == 0 )) || { echo "$fails check(s) failed" >&2; exit 1; }
echo "all checks passed"
```

`chmod +x infra/check.sh`. The `if helm template ...` form keeps `set -e` from aborting on the expected failures.

- [ ] **Step 3: Run it to see it fail**

Run: `infra/check.sh`
Expected: FAIL with `Error: Chart.yaml file is missing`.

- [ ] **Step 4: Write the chart skeleton**

`infra/stack/Chart.yaml`:

```yaml
apiVersion: v2
name: shopnexus
description: One ShopNexus stack (dev or prod) in its own namespace.
type: application
version: 0.1.0
```

`infra/stack/.helmignore`:

```
secrets/*.env
secrets/*.pem
secrets/example.env
```

`infra/stack/values.yaml` (pin each image to its newest release after checking; the dev compose file uses the tags shown):

```yaml
# values-dev.yaml and values-prod.yaml set these three; the chart fails without them.
stack: ""     # dev | prod
domain: ""    # dev.shopnexus.id.vn | shopnexus.id.vn
appEnv: ""    # the server's APP_ENV: dev | prod

images:
  server: { repository: ghcr.io/shopnexus/server, tag: main }
  website: { repository: ghcr.io/shopnexus/website, tag: main }
  docs: { repository: ghcr.io/shopnexus/docs, tag: main }
  ops: { repository: "", tag: "" }
  postgres: { repository: paradedb/paradedb, tag: 0.26.3-pg18 }
  restate: { repository: restatedev/restate, tag: 1.8.0 }
  rustfs: { repository: rustfs/rustfs, tag: 1.0.4 }

ops:
  enabled: false
  port: 80

replicas:
  server: 1
  website: 1
  docs: 1
  ops: 1

postgres:
  instances: 1
  storage: 5Gi

restate:
  replicas: 1
  storageBytes: 2147483648 # 2 GiB

rustfs:
  storage: 10Gi

server:
  logLevel: info
  pnvTestNumbers: "true"
  llmBaseURL: ""
  llmModel: ""
  firebaseProjectID: shopnexus-26aca
  firebaseProjectNumber: "5362373878"
```

`infra/stack/values-dev.yaml`:

```yaml
stack: dev
domain: dev.shopnexus.id.vn
appEnv: dev
server:
  logLevel: debug
  pnvTestNumbers: "true"
  llmBaseURL: http://khoakomlem-internal.ddns.net:8317/v1
  llmModel: ""
  firebaseProjectID: shopnexus-26aca
  firebaseProjectNumber: "5362373878"
```

`infra/stack/values-prod.yaml`:

```yaml
stack: prod
domain: shopnexus.id.vn
appEnv: prod
images:
  server: { repository: ghcr.io/shopnexus/server, tag: 0.1.0 }
  website: { repository: ghcr.io/shopnexus/website, tag: 0.1.0 }
  docs: { repository: ghcr.io/shopnexus/docs, tag: 0.1.0 }
replicas:
  server: 3
  website: 2
  docs: 1
  ops: 2
postgres:
  instances: 2
  storage: 10Gi
restate:
  replicas: 3
  storageBytes: 4294967296 # 4 GiB
server:
  logLevel: info
  pnvTestNumbers: "false"
  llmBaseURL: http://khoakomlem-internal.ddns.net:8317/v1
  llmModel: ""
  firebaseProjectID: shopnexus-26aca
  firebaseProjectNumber: "5362373878"
```

`llmModel` is filled in Task 16 Step 4 with the model the user names; the server refuses an empty `LLM_MODEL`.

`infra/stack/templates/_helpers.tpl`:

```
{{/* Labels on every resource. */}}
{{- define "sn.labels" -}}
app.kubernetes.io/part-of: shopnexus
shopnexus.id.vn/stack: {{ .Values.stack }}
{{- end }}

{{/* Pod labels. Call with (dict "root" $ "name" "server"). */}}
{{- define "sn.podLabels" -}}
app.kubernetes.io/name: {{ .name }}
{{ include "sn.labels" .root }}
{{- end }}

{{/* repository:tag of one images.* entry. */}}
{{- define "sn.image" -}}
{{ .repository }}:{{ .tag }}
{{- end }}

{{/* (dict "root" $ "sub" "api") gives api.<domain>; an empty sub gives <domain>. */}}
{{- define "sn.host" -}}
{{- $d := required "domain is required" .root.Values.domain -}}
{{- if .sub }}{{ .sub }}.{{ $d }}{{ else }}{{ $d }}{{ end -}}
{{- end }}

{{/* Name and namespace of the stack's RestateCluster. */}}
{{- define "sn.restate" -}}
restate-{{ required "stack is required" .Values.stack }}
{{- end }}

{{/* Argo CD sync wave annotation. */}}
{{- define "sn.wave" -}}
argocd.argoproj.io/sync-wave: {{ . | quote }}
{{- end }}

{{/* Prefer nodes labelled role=<value>. Goes under affinity. */}}
{{- define "sn.preferRole" -}}
nodeAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
          - { key: role, operator: In, values: [{{ . }}] }
{{- end }}

{{/* Prefer one pod of app <value> per node. Goes under affinity. */}}
{{- define "sn.spread" -}}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels: { app.kubernetes.io/name: {{ . }} }
{{- end }}
```

`infra/stack/templates/validate.yaml`:

```
{{- if not (has .Values.stack (list "dev" "prod")) }}{{ fail "stack must be dev or prod" }}{{ end }}
{{- if not (has .Values.appEnv (list "dev" "prod")) }}{{ fail "appEnv must be dev or prod" }}{{ end }}
{{- $_ := required "domain is required" .Values.domain }}
```

- [ ] **Step 5: Run the checks**

Run: `infra/check.sh`
Expected: `all checks passed`.

- [ ] **Step 6: CI for the umbrella**

`.github/workflows/infra.yml`:

```yaml
name: Infra checks

on:
  pull_request:
    paths: ["infra/**"]
  push:
    branches: [main]
    paths: ["infra/**"]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4
      - name: Install yq and kubeconform
        run: |
          mkdir -p "$HOME/bin"
          curl -fsSL -o "$HOME/bin/yq" https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
          curl -fsSL https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz | tar xz -C "$HOME/bin" kubeconform
          chmod +x "$HOME/bin/yq"
          echo "$HOME/bin" >> "$GITHUB_PATH"
      - run: infra/check.sh
```

- [ ] **Step 7: Commit**

```bash
git add -A deploy infra .github/workflows/infra.yml
git commit -m "infra: remove deploy/, add the stack chart skeleton and its checks"
```

---

### Task 7: Website, docs, ops and the Ingress

**Files:**
- Create: `infra/stack/templates/web.yaml`
- Create: `infra/stack/templates/ingress.yaml`
- Modify: `infra/check.sh`

**Interfaces:**
- Consumes: helpers and values from Task 6.
- Produces: Deployments and Services `website` (3000), `docs` (80), `ops` (`ops.port`, only when `ops.enabled`); Ingress `shopnexus` routing `<domain>`→website, `api.`→`server-api:8080`, `media.`→`rustfs:9000`, `docs.`→docs, `ops.`→ops. Task 9 creates `server-api`; Task 8 creates `rustfs`.

- [ ] **Step 1: Add the checks**

Insert above `# ── end of checks ──`:

```bash
# ── web apps and ingress ──
hosts() { q "$1" 'select(.kind=="Ingress") | .spec.rules[].host' | sort | tr '\n' ' '; }
eq "$(hosts "$prod")" "api.shopnexus.id.vn docs.shopnexus.id.vn media.shopnexus.id.vn shopnexus.id.vn " "prod hosts"
eq "$(hosts "$dev")" "api.dev.shopnexus.id.vn dev.shopnexus.id.vn docs.dev.shopnexus.id.vn media.dev.shopnexus.id.vn " "dev hosts"
withops=$(render prod --set ops.enabled=true --set images.ops.repository=ghcr.io/shopnexus/ops --set images.ops.tag=0.1.0)
eq "$(q "$withops" 'select(.kind=="Ingress") | .spec.rules[] | select(.host=="ops.shopnexus.id.vn") | .http.paths[0].backend.service.name')" ops "ops host when enabled"
eq "$(q "$prod" 'select(.kind=="Ingress") | .spec.rules[] | select(.host=="api.shopnexus.id.vn") | .http.paths[0].backend.service.name')" server-api "api goes to server-api"
eq "$(q "$prod" 'select(.kind=="Deployment" and .metadata.name=="website") | .spec.replicas')" 2 "prod website replicas"
eq "$(q "$dev" 'select(.kind=="Deployment" and .metadata.name=="website") | .spec.replicas')" 1 "dev website replicas"
eq "$(q "$prod" 'select(.kind=="Deployment" and .metadata.name=="docs") | .spec.template.spec.containers[0].image')" ghcr.io/shopnexus/docs:0.1.0 "prod docs image"
eq "$(q "$prod" 'select(.kind=="Ingress") | .spec | has("tls")')" false "ingress leaves TLS to the edge"
```

- [ ] **Step 2: Run to see them fail**

Run: `infra/check.sh`
Expected: FAIL lines for prod hosts, dev hosts, ops, api, replicas, docs image.

- [ ] **Step 3: Write `web.yaml`**

```yaml
{{- /* Stateless HTTP apps: one Deployment and one Service each. */ -}}
{{- $apps := list
  (dict "name" "website" "port" 3000 "image" .Values.images.website "replicas" .Values.replicas.website)
  (dict "name" "docs" "port" 80 "image" .Values.images.docs "replicas" .Values.replicas.docs) }}
{{- if .Values.ops.enabled }}
{{- $apps = append $apps (dict "name" "ops" "port" .Values.ops.port "image" .Values.images.ops "replicas" .Values.replicas.ops) }}
{{- end }}
{{- range $apps }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .name }}
  labels: {{- include "sn.labels" $ | nindent 4 }}
  annotations: {{- include "sn.wave" "2" | nindent 4 }}
spec:
  replicas: {{ .replicas }}
  selector:
    matchLabels: { app.kubernetes.io/name: {{ .name }} }
  template:
    metadata:
      labels: {{- include "sn.podLabels" (dict "root" $ "name" .name) | nindent 8 }}
    spec:
      affinity:
        {{- include "sn.preferRole" "app" | nindent 8 }}
        {{- include "sn.spread" .name | nindent 8 }}
      containers:
        - name: {{ .name }}
          image: {{ include "sn.image" .image }}
          ports:
            - { name: http, containerPort: {{ .port }} }
          readinessProbe:
            tcpSocket: { port: http }
          resources:
            requests: { cpu: 20m, memory: 64Mi }
            limits: { memory: 512Mi }
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .name }}
  labels: {{- include "sn.labels" $ | nindent 4 }}
spec:
  selector: { app.kubernetes.io/name: {{ .name }} }
  ports:
    - { name: http, port: {{ .port }}, targetPort: http }
{{- end }}
```

- [ ] **Step 4: Write `ingress.yaml`**

```yaml
{{- /* Hosts only. TLS belongs to the edge: Traefik's websecure entrypoint
       in direct mode, the outer proxy in behind-proxy mode. */ -}}
{{- $routes := list (list "" "website" 3000) (list "api" "server-api" 8080) (list "media" "rustfs" 9000) (list "docs" "docs" 80) }}
{{- if .Values.ops.enabled }}
{{- $routes = append $routes (list "ops" "ops" (int .Values.ops.port)) }}
{{- end }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shopnexus
  labels: {{- include "sn.labels" . | nindent 4 }}
  annotations: {{- include "sn.wave" "2" | nindent 4 }}
spec:
  ingressClassName: traefik
  rules:
  {{- range $routes }}
    - host: {{ include "sn.host" (dict "root" $ "sub" (index . 0)) }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ index . 1 }}
                port: { number: {{ index . 2 }} }
  {{- end }}
```

- [ ] **Step 5: Run the checks**

Run: `infra/check.sh`
Expected: `all checks passed`.

- [ ] **Step 6: Commit**

```bash
git add infra && git commit -m "infra: website, docs, ops and the ingress"
```

---

### Task 8: Postgres, RustFS and the jobs

**Files:**
- Create: `infra/stack/templates/postgres.yaml`
- Create: `infra/stack/templates/rustfs.yaml`
- Create: `infra/stack/templates/jobs.yaml`
- Create: `infra/stack/templates/_server-env.tpl`
- Modify: `infra/check.sh`

**Interfaces:**
- Consumes: values `postgres.*`, `rustfs.*`, `images.*`; ConfigMap `server-env` and Secret `server-secrets` (Tasks 9 and 11) through the helper below.
- Produces:
  - CNPG `Cluster` `postgres`, database `app`, owner `app`; CNPG creates Secret `postgres-app` (key `uri`) and Service `postgres-rw`.
  - StatefulSet and Service `rustfs` on port 9000, credentials from `server-secrets` keys `OBJECT_STORE_ACCESS_KEY` / `OBJECT_STORE_SECRET_KEY`.
  - Hook Jobs `migrate`, `objectstore-init`, `objectstore-init-snapshots` at wave 1.
  - Helper `sn.serverEnv` (root): the `envFrom` + `env` block every server-image container uses.

- [ ] **Step 1: Add the checks**

```bash
# ── data and jobs ──
eq "$(q "$prod" 'select(.kind=="Cluster") | .spec.instances')" 2 "prod postgres instances"
eq "$(q "$dev" 'select(.kind=="Cluster") | .spec.instances')" 1 "dev postgres instances"
eq "$(q "$prod" 'select(.kind=="Cluster") | .spec.postgresql.shared_preload_libraries[0]')" pg_search "pg_search preloaded"
eq "$(q "$prod" 'select(.kind=="Cluster") | .metadata.annotations["argocd.argoproj.io/sync-wave"]')" 0 "postgres in wave 0"
eq "$(q "$prod" 'select(.kind=="StatefulSet" and .metadata.name=="rustfs") | .spec.replicas')" 1 "one rustfs"
eq "$(q "$prod" 'select(.kind=="Job") | .metadata.name' | sort | tr '\n' ' ')" "migrate objectstore-init objectstore-init-snapshots " "jobs"
eq "$(q "$prod" 'select(.kind=="Job" and .metadata.name=="migrate") | .metadata.annotations["argocd.argoproj.io/sync-wave"]')" 1 "migrate in wave 1"
eq "$(q "$prod" 'select(.kind=="Job" and .metadata.name=="migrate") | .spec.template.spec.containers[0].command[0]')" /migrate "migrate runs /migrate"
eq "$(q "$prod" 'select(.kind=="Job" and .metadata.name=="objectstore-init-snapshots") | .spec.template.spec.containers[0].env[] | select(.name=="OBJECT_STORE_BUCKET") | .value')" restate-snapshots "snapshot bucket"
```

- [ ] **Step 2: Run to see them fail**

Run: `infra/check.sh`
Expected: FAIL lines for each new check.

- [ ] **Step 3: Write the shared env helper**

`infra/stack/templates/_server-env.tpl`:

```
{{/* Environment of every container running the server image. */}}
{{- define "sn.serverEnv" -}}
envFrom:
  - configMapRef: { name: server-env }
  - secretRef: { name: server-secrets }
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef: { name: postgres-app, key: uri }
{{- end }}
```

- [ ] **Step 4: Write `postgres.yaml`**

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres
  labels: {{- include "sn.labels" . | nindent 4 }}
  annotations: {{- include "sn.wave" "0" | nindent 4 }}
spec:
  instances: {{ .Values.postgres.instances }}
  imageName: {{ include "sn.image" .Values.images.postgres }}
  postgresql:
    shared_preload_libraries: [pg_search]
  bootstrap:
    initdb:
      database: app
      owner: app
      # As the superuser, so the migration's CREATE EXTENSION finds it present.
      postInitApplicationSQL:
        - CREATE EXTENSION IF NOT EXISTS pg_search CASCADE
  storage:
    size: {{ .Values.postgres.storage }}
  affinity:
    enablePodAntiAffinity: true
    podAntiAffinityType: preferred
    topologyKey: kubernetes.io/hostname
```

- [ ] **Step 5: Write `rustfs.yaml`**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rustfs
  labels: {{- include "sn.labels" . | nindent 4 }}
  annotations: {{- include "sn.wave" "0" | nindent 4 }}
spec:
  serviceName: rustfs
  replicas: 1
  selector:
    matchLabels: { app.kubernetes.io/name: rustfs }
  template:
    metadata:
      labels: {{- include "sn.podLabels" (dict "root" . "name" "rustfs") | nindent 8 }}
    spec:
      affinity:
        {{- include "sn.preferRole" "stateful" | nindent 8 }}
      containers:
        - name: rustfs
          image: {{ include "sn.image" .Values.images.rustfs }}
          env:
            - name: RUSTFS_ACCESS_KEY
              valueFrom: { secretKeyRef: { name: server-secrets, key: OBJECT_STORE_ACCESS_KEY } }
            - name: RUSTFS_SECRET_KEY
              valueFrom: { secretKeyRef: { name: server-secrets, key: OBJECT_STORE_SECRET_KEY } }
            - { name: RUSTFS_VOLUMES, value: /data }
            - { name: RUSTFS_ADDRESS, value: "0.0.0.0:9000" }
            - { name: RUSTFS_CONSOLE_ENABLE, value: "false" }
          ports:
            - { name: s3, containerPort: 9000 }
          readinessProbe:
            httpGet: { path: /health, port: s3 }
          volumeMounts:
            - { name: data, mountPath: /data }
          resources:
            requests: { cpu: 50m, memory: 128Mi }
            limits: { memory: 1Gi }
  volumeClaimTemplates:
    - metadata: { name: data }
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests: { storage: {{ .Values.rustfs.storage }} }
---
apiVersion: v1
kind: Service
metadata:
  name: rustfs
  labels: {{- include "sn.labels" . | nindent 4 }}
spec:
  selector: { app.kubernetes.io/name: rustfs }
  ports:
    - { name: s3, port: 9000, targetPort: s3 }
```

- [ ] **Step 6: Write `jobs.yaml`**

```yaml
{{- /* Sync hooks in wave 1: after postgres and rustfs (wave 0) are healthy,
       before the server (wave 2). Each sync runs them again; all three are
       idempotent. */ -}}
{{- $jobs := list
  (dict "name" "migrate" "command" "/migrate" "env" (list))
  (dict "name" "objectstore-init" "command" "/objectstore-init" "env" (list))
  (dict "name" "objectstore-init-snapshots" "command" "/objectstore-init" "env" (list (dict "name" "OBJECT_STORE_BUCKET" "value" "restate-snapshots"))) }}
{{- range $jobs }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .name }}
  labels: {{- include "sn.labels" $ | nindent 4 }}
  annotations:
    argocd.argoproj.io/hook: Sync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
    {{- include "sn.wave" "1" | nindent 4 }}
spec:
  backoffLimit: 6
  template:
    metadata:
      labels: {{- include "sn.podLabels" (dict "root" $ "name" .name) | nindent 8 }}
    spec:
      restartPolicy: OnFailure
      containers:
        - name: {{ .name }}
          image: {{ include "sn.image" $.Values.images.server }}
          command: [{{ .command | quote }}]
          {{- include "sn.serverEnv" $ | nindent 10 }}
          {{- range .env }}
            - { name: {{ .name }}, value: {{ .value | quote }} }
          {{- end }}
{{- end }}
```

The `range .env` lines append to the `env:` list that `sn.serverEnv` ends with; check the indentation in `helm template` output in the next step.

- [ ] **Step 7: Run the checks**

Run: `infra/check.sh`
Expected: `all checks passed`. Also run `helm template x infra/stack -f infra/stack/values-prod.yaml -s templates/jobs.yaml` and confirm the snapshot job's `env` list has `DATABASE_URL` then `OBJECT_STORE_BUCKET` at the same indentation.

- [ ] **Step 8: Commit**

```bash
git add infra && git commit -m "infra: postgres on CloudNativePG, rustfs, and the wave 1 jobs"
```

---

### Task 9: Restate and the server

**Files:**
- Create: `infra/stack/templates/restate.yaml`
- Create: `infra/stack/templates/server.yaml`
- Modify: `infra/stack/templates/_server-env.tpl` (adds `sn.serverEnvData`)
- Modify: `infra/check.sh`

**Interfaces:**
- Consumes: `sn.serverEnv` (Task 8), `postgres-app`, `rustfs`; Secret `restate-secrets` in namespace `restate-<stack>` with keys `private.pem`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (Task 11).
- Produces: Namespace `restate-<stack>` (wave -1); `RestateCluster` `restate-<stack>` (wave 1); ConfigMap `server-env`; `RestateDeployment` `server` (wave 2) whose pods carry `app.kubernetes.io/name: server`; Service `server-api` port 8080.

- [ ] **Step 1: Add the checks**

```bash
# ── restate and server ──
rc='select(.kind=="RestateCluster")'
eq "$(q "$prod" "$rc | .metadata.name")" restate-prod "prod restate name"
eq "$(q "$prod" "$rc | .spec.compute.replicas")" 3 "prod restate nodes"
eq "$(q "$dev" "$rc | .spec.compute.replicas")" 1 "dev restate nodes"
ok $(grep -q 'default-replication = 2' <<<"$(q "$prod" "$rc | .spec.config")"; echo $?) "prod replicates the log twice"
ok $(grep -q 'default-replication = 1' <<<"$(q "$dev" "$rc | .spec.config")"; echo $?) "dev keeps one copy"
ok $(grep -q 'destination = "s3://restate-snapshots/prod"' <<<"$(q "$prod" "$rc | .spec.config")"; echo $?) "snapshots in rustfs"
eq "$(q "$prod" "$rc | .spec.security.requestSigningPrivateKey.secret.secretName")" restate-secrets "signing key"
rd='select(.kind=="RestateDeployment")'
eq "$(q "$prod" "$rd | .spec.replicas")" 3 "prod server replicas"
eq "$(q "$prod" "$rd | .spec.restate.register.cluster")" restate-prod "server registers with prod restate"
eq "$(q "$prod" "$rd | .spec.restate.useHttp11")" true "HTTP/1.1 to the endpoint"
eq "$(q "$prod" 'select(.kind=="Service" and .metadata.name=="server-api") | .spec.selector["app.kubernetes.io/name"]')" server "server-api selects every server pod"
cm='select(.kind=="ConfigMap" and .metadata.name=="server-env") | .data'
eq "$(q "$prod" "$cm | .RESTATE_REGISTER")" false "the operator registers"
eq "$(q "$prod" "$cm | .APP_ENV")" prod "prod APP_ENV"
eq "$(q "$prod" "$cm | .PNV_TEST_NUMBERS")" false "prod refuses test numbers"
eq "$(q "$prod" "$cm | .STAFF_CONSOLE_ORIGIN")" https://ops.shopnexus.id.vn "console origin"
eq "$(q "$dev" "$cm | .MEDIA_PUBLIC_URL")" https://media.dev.shopnexus.id.vn/shopnexus "dev media URL"
eq "$(q "$dev" "$cm | .RESTATE_INGRESS_URL")" http://restate.restate-dev:8080 "dev restate ingress"
# Review Focus 1: a config change makes a new server version.
sum() { q "$1" "$rd | .spec.template.metadata.annotations[\"checksum/env\"]"; }
ok $([[ "$(sum "$prod")" != "$(sum "$(render prod --set server.logLevel=debug)")" ]]; echo $?) "config change rolls the server"
# Review Focus 2: every variable config.Load reads is set by the ConfigMap, the Secret or DATABASE_URL.
secret_keys="JWT_KEY_ID JWT_PRIVATE_KEY STAFF_KEY RESTATE_IDENTITY_KEY OBJECT_STORE_ACCESS_KEY OBJECT_STORE_SECRET_KEY LLM_API_KEY FCM_CREDENTIALS"
cm_keys=$(q "$prod" "$cm | keys | .[]")
for v in APP_ENV HTTP_ADDR LOG_LEVEL LOG_FORMAT RESTATE_INGRESS_URL RESTATE_ADMIN_URL RESTATE_LISTEN_ADDR \
  RESTATE_ENDPOINT_URL RESTATE_SERVICE_PREFIX RESTATE_IDENTITY_KEY RESTATE_REGISTER JWT_KEY_ID JWT_PRIVATE_KEY \
  JWT_PREVIOUS_KEY_ID JWT_PREVIOUS_PUBLIC_KEY JWT_ISSUER JWT_AUDIENCE STAFF_KEY STAFF_CONSOLE_ORIGIN \
  OBJECT_STORE_ENDPOINT OBJECT_STORE_PUBLIC_ENDPOINT OBJECT_STORE_REGION OBJECT_STORE_ACCESS_KEY \
  OBJECT_STORE_SECRET_KEY OBJECT_STORE_BUCKET MEDIA_PUBLIC_URL FCM_CREDENTIALS FIREBASE_PROJECT_ID \
  FIREBASE_PROJECT_NUMBER FIREBASE_AUTH_JWKS_URL PNV_JWKS_URL PNV_TEST_NUMBERS LLM_BASE_URL LLM_API_KEY \
  LLM_MODEL OTEL_EXPORTER_OTLP_ENDPOINT SERVICE_NAME TRUSTED_PROXIES; do
  grep -qx "$v" <<<"$cm_keys" || grep -qw "$v" <<<"$secret_keys" || { echo "FAIL: $v is set nowhere" >&2; fails=$((fails + 1)); }
done
```

- [ ] **Step 2: Run to see them fail**

Run: `infra/check.sh`
Expected: FAIL lines for each new check, and one `is set nowhere` per ConfigMap variable.

- [ ] **Step 3: Write `restate.yaml`**

```yaml
{{- $name := include "sn.restate" . }}
{{- $copies := min 2 (int .Values.restate.replicas) }}
# The operator puts the cluster in a namespace named after it. Creating the
# namespace here lets the sealed restate-secrets land before the cluster.
apiVersion: v1
kind: Namespace
metadata:
  name: {{ $name }}
  labels: {{- include "sn.labels" . | nindent 4 }}
  annotations: {{- include "sn.wave" "-1" | nindent 4 }}
---
apiVersion: restate.dev/v1
kind: RestateCluster
metadata:
  name: {{ $name }}
  labels: {{- include "sn.labels" . | nindent 4 }}
  annotations: {{- include "sn.wave" "1" | nindent 4 }}
spec:
  cluster:
    autoProvision: true
  compute:
    replicas: {{ .Values.restate.replicas }}
    image: {{ include "sn.image" .Values.images.restate }}
    env:
      - name: RESTATE_WORKER__SNAPSHOTS__AWS_ACCESS_KEY_ID
        valueFrom: { secretKeyRef: { name: restate-secrets, key: AWS_ACCESS_KEY_ID } }
      - name: RESTATE_WORKER__SNAPSHOTS__AWS_SECRET_ACCESS_KEY
        valueFrom: { secretKeyRef: { name: restate-secrets, key: AWS_SECRET_ACCESS_KEY } }
  storage:
    storageRequestBytes: {{ .Values.restate.storageBytes | int64 }}
  security:
    requestSigningPrivateKey:
      version: v1
      secret:
        secretName: restate-secrets
        key: private.pem
  config: |
    roles = ["worker", "admin", "log-server", "metadata-server", "http-ingress"]
    auto-provision = false
    default-num-partitions = 24
    default-replication = {{ $copies }}

    [metadata-client]
    type = "replicated"
    addresses = ["http://restate-cluster:5122/"]

    [worker.snapshots]
    destination = "s3://restate-snapshots/{{ .Values.stack }}"
    snapshot-interval-num-records = 10000
    aws-region = "us-east-1"
    aws-endpoint-url = "http://rustfs.{{ .Release.Namespace }}:9000"
    aws-allow-http = true
```

- [ ] **Step 4: Write the ConfigMap data helper**

Append to `infra/stack/templates/_server-env.tpl`. The ConfigMap renders it and the server's pod template carries its checksum, so a config change changes the template and the operator starts a new version.

```
{{/* Non-secret server configuration: the data of ConfigMap server-env. */}}
{{- define "sn.serverEnvData" -}}
{{- $restate := include "sn.restate" . -}}
APP_ENV: {{ .Values.appEnv | quote }}
HTTP_ADDR: ":8080"
LOG_LEVEL: {{ .Values.server.logLevel | quote }}
LOG_FORMAT: json
OTEL_EXPORTER_OTLP_ENDPOINT: ""
SERVICE_NAME: server
# k3s's pod network; Traefik's X-Forwarded-For is believed.
TRUSTED_PROXIES: "10.42.0.0/16"
RESTATE_INGRESS_URL: http://restate.{{ $restate }}:8080
RESTATE_ADMIN_URL: http://restate.{{ $restate }}:9070
RESTATE_LISTEN_ADDR: "0.0.0.0:9080"
RESTATE_ENDPOINT_URL: ""
RESTATE_SERVICE_PREFIX: ""
RESTATE_REGISTER: "false"
JWT_ISSUER: shopnexus
JWT_AUDIENCE: shopnexus-app
JWT_PREVIOUS_KEY_ID: ""
JWT_PREVIOUS_PUBLIC_KEY: ""
STAFF_CONSOLE_ORIGIN: https://{{ include "sn.host" (dict "root" . "sub" "ops") }}
OBJECT_STORE_ENDPOINT: http://rustfs:9000
OBJECT_STORE_PUBLIC_ENDPOINT: https://{{ include "sn.host" (dict "root" . "sub" "media") }}
OBJECT_STORE_REGION: us-east-1
OBJECT_STORE_BUCKET: shopnexus
MEDIA_PUBLIC_URL: https://{{ include "sn.host" (dict "root" . "sub" "media") }}/shopnexus
LLM_BASE_URL: {{ .Values.server.llmBaseURL | quote }}
LLM_MODEL: {{ .Values.server.llmModel | quote }}
FIREBASE_PROJECT_ID: {{ .Values.server.firebaseProjectID | quote }}
FIREBASE_PROJECT_NUMBER: {{ .Values.server.firebaseProjectNumber | quote }}
FIREBASE_AUTH_JWKS_URL: https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com
PNV_JWKS_URL: https://fpnv.googleapis.com/v1beta/jwks
PNV_TEST_NUMBERS: {{ .Values.server.pnvTestNumbers | quote }}
{{- end }}
```

- [ ] **Step 5: Write `server.yaml`**

```yaml
{{- $restate := include "sn.restate" . }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: server-env
  labels: {{- include "sn.labels" . | nindent 4 }}
data: {{- include "sn.serverEnvData" . | nindent 2 }}
---
# restate-operator gives every pod template a ReplicaSet and a Service of its
# own, registers it, and keeps an old one until its invocations finish.
apiVersion: restate.dev/v1beta1
kind: RestateDeployment
metadata:
  name: server
  labels: {{- include "sn.labels" . | nindent 4 }}
  annotations: {{- include "sn.wave" "2" | nindent 4 }}
spec:
  replicas: {{ .Values.replicas.server }}
  restate:
    register:
      cluster: {{ $restate }}
    useHttp11: true
  selector:
    matchLabels: { app.kubernetes.io/name: server }
  template:
    metadata:
      labels: {{- include "sn.podLabels" (dict "root" . "name" "server") | nindent 8 }}
      annotations:
        # A config change changes the template, so the operator starts a new version.
        checksum/env: {{ include "sn.serverEnvData" . | sha256sum | trunc 16 }}
    spec:
      affinity:
        {{- include "sn.preferRole" "app" | nindent 8 }}
        {{- include "sn.spread" "server" | nindent 8 }}
      containers:
        - name: server
          image: {{ include "sn.image" .Values.images.server }}
          {{- include "sn.serverEnv" . | nindent 10 }}
          ports:
            - { name: http, containerPort: 8080 }
            - { name: restate, containerPort: 9080 }
          readinessProbe:
            httpGet: { path: /readyz, port: http }
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: http }
            initialDelaySeconds: 10
            periodSeconds: 20
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits: { memory: 512Mi }
---
# API traffic reaches every server pod, of any version.
apiVersion: v1
kind: Service
metadata:
  name: server-api
  labels: {{- include "sn.labels" . | nindent 4 }}
spec:
  selector: { app.kubernetes.io/name: server }
  ports:
    - { name: http, port: 8080, targetPort: http }
```

- [ ] **Step 6: Run the checks**

Run: `infra/check.sh`
Expected: `all checks passed`.

- [ ] **Step 7: Commit**

```bash
git add infra && git commit -m "infra: Restate on restate-operator, and the server as a RestateDeployment"
```

---

### Task 10: Network policies

**Files:**
- Create: `infra/stack/templates/networkpolicy.yaml`
- Modify: `infra/check.sh`

**Interfaces:**
- Consumes: pod labels `app.kubernetes.io/name` from Tasks 7 to 9; Traefik pods in `kube-system` labelled `app.kubernetes.io/name: traefik`; CNPG operator in namespace `cnpg-system`.
- Produces: in `shopnexus-<stack>`, ingress denied except from the same namespace, Traefik (to website, docs, ops, server, rustfs), `cnpg-system` (to postgres), and `restate-<stack>` (to server and rustfs).

- [ ] **Step 1: Add the checks**

```bash
# ── network policies ──
np() { q "$1" 'select(.kind=="NetworkPolicy") | .metadata.name' | sort | tr '\n' ' '; }
eq "$(np "$prod")" "default-deny-ingress from-cnpg from-restate from-stack from-traefik " "policies"
eq "$(q "$prod" 'select(.kind=="NetworkPolicy" and .metadata.name=="from-restate") | .spec.ingress[0].from[0].namespaceSelector.matchLabels["kubernetes.io/metadata.name"]')" restate-prod "restate namespace"
eq "$(q "$prod" 'select(.kind=="NetworkPolicy" and .metadata.name=="from-stack") | .spec.ingress[0].from[0] | has("namespaceSelector")')" false "from-stack is this namespace only"
```

- [ ] **Step 2: Run to see them fail**

Run: `infra/check.sh`
Expected: FAIL for the three checks.

- [ ] **Step 3: Write `networkpolicy.yaml`**

```yaml
{{- $restate := include "sn.restate" . }}
# Ingress is denied unless a policy below admits it. Egress stays open: the
# server calls Firebase, FCM and the language model.
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  labels: {{- include "sn.labels" . | nindent 4 }}
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
# Pods of this stack reach each other: server to postgres and rustfs, website
# to server-api, the jobs, postgres replication.
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: from-stack
  labels: {{- include "sn.labels" . | nindent 4 }}
spec:
  podSelector: {}
  ingress:
    - from:
        - podSelector: {}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: from-traefik
  labels: {{- include "sn.labels" . | nindent 4 }}
spec:
  podSelector:
    matchExpressions:
      - { key: app.kubernetes.io/name, operator: In, values: [website, docs, ops, server, rustfs] }
  ingress:
    - from:
        - namespaceSelector:
            matchLabels: { kubernetes.io/metadata.name: kube-system }
          podSelector:
            matchLabels: { app.kubernetes.io/name: traefik }
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: from-cnpg
  labels: {{- include "sn.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels: { cnpg.io/cluster: postgres }
  ingress:
    - from:
        - namespaceSelector:
            matchLabels: { kubernetes.io/metadata.name: cnpg-system }
---
# Restate invokes the server's endpoint and writes snapshots to rustfs.
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: from-restate
  labels: {{- include "sn.labels" . | nindent 4 }}
spec:
  podSelector:
    matchExpressions:
      - { key: app.kubernetes.io/name, operator: In, values: [server, rustfs] }
  ingress:
    - from:
        - namespaceSelector:
            matchLabels: { kubernetes.io/metadata.name: {{ $restate }} }
```

- [ ] **Step 4: Run the checks**

Run: `infra/check.sh`
Expected: `all checks passed`.

- [ ] **Step 5: Commit**

```bash
git add infra && git commit -m "infra: ingress-only network policies per stack"
```

---

### Task 11: Secrets

**Files:**
- Create: `infra/cluster/seal.sh`
- Create: `infra/stack/secrets/example.env`
- Create: `infra/stack/templates/secrets.yaml`
- Create: `infra/stack/secrets/dev/.gitkeep`, `infra/stack/secrets/prod/.gitkeep`
- Modify: `.gitignore` (umbrella)
- Modify: `infra/check.sh`
- Test: `infra/cluster/seal-test.sh`

**Interfaces:**
- Consumes: image `ghcr.io/shopnexus/server` (`/keygen`, Task 3); controller `sealed-secrets-controller` in `kube-system` (Task 12).
- Produces: `infra/stack/secrets/<stack>/server-secrets.yaml` (SealedSecret `server-secrets` in `shopnexus-<stack>`, keys listed in `secret_keys` in Task 9) and `restate-secrets.yaml` (SealedSecret `restate-secrets` in `restate-<stack>`, keys `private.pem`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`). The chart includes every `secrets/<stack>/*.yaml`.

- [ ] **Step 1: Add the checks**

```bash
# ── secrets ──
for k in $secret_keys; do grep -q "\b$k\b" cluster/seal.sh || { echo "FAIL: seal.sh does not write $k" >&2; fails=$((fails + 1)); }; done
tmpd=$(mktemp -d); cp -r stack "$tmpd/"; mkdir -p "$tmpd/stack/secrets/dev"
printf 'apiVersion: bitnami.com/v1alpha1\nkind: SealedSecret\nmetadata: {name: probe, namespace: shopnexus-dev}\nspec: {encryptedData: {}}\n' > "$tmpd/stack/secrets/dev/probe.yaml"
eq "$(helm template x "$tmpd/stack" -f stack/values-dev.yaml | yq ea 'select(.kind=="SealedSecret") | .metadata.name')" probe "chart includes secrets/<stack>/*.yaml"
rm -rf "$tmpd"
```

- [ ] **Step 2: Run to see them fail**

Run: `infra/check.sh`
Expected: FAIL `seal.sh does not write ...` for every key (the file is missing; `grep` errors count as fails) and the probe check.

- [ ] **Step 3: Write `secrets.yaml`**

```
{{- /* SealedSecrets that seal.sh wrote for this stack. */ -}}
{{- range $path, $_ := .Files.Glob (printf "secrets/%s/*.yaml" .Values.stack) }}
---
{{ $.Files.Get $path }}
{{- end }}
```

- [ ] **Step 4: Write `example.env`**

```
# seal.sh copies this file to <stack>.env (git-ignored) on first use and adds
# the generated keys: JWT_KEY_ID, JWT_PRIVATE_KEY, STAFF_KEY,
# RESTATE_IDENTITY_KEY, OBJECT_STORE_ACCESS_KEY, OBJECT_STORE_SECRET_KEY.
# Fill in the two below. Both are required; an empty value is a setting.

# The key of the OpenAI-compatible API in LLM_BASE_URL.
LLM_API_KEY=
# A Firebase service account's JSON in base64. Empty logs pushes instead of
# sending them; APP_ENV=prod refuses it empty, so seal.sh prod does too.
FCM_CREDENTIALS=
```

- [ ] **Step 5: Write the idempotence test (Review Focus 3)**

`infra/cluster/seal-test.sh` runs `seal.sh` in `--dry-run` mode (writes plain Secrets to stdout instead of sealing, needs no cluster) twice and compares the keys:

```bash
#!/usr/bin/env bash
# seal.sh keeps the keys it generated: a second run seals the same values.
set -euo pipefail
cd "$(dirname "$0")"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
cp ../stack/secrets/example.env "$dir/dev.env"
sed -i 's/^LLM_API_KEY=$/LLM_API_KEY=test/' "$dir/dev.env"
first=$(SECRETS_DIR=$dir ./seal.sh dev --dry-run)
second=$(SECRETS_DIR=$dir ./seal.sh dev --dry-run)
[[ "$first" == "$second" ]] || { echo "FAIL: a second run changed the secrets" >&2; exit 1; }
grep -q 'JWT_PRIVATE_KEY' <<<"$first" || { echo "FAIL: no JWT key" >&2; exit 1; }
grep -q 'private.pem' <<<"$first" || { echo "FAIL: no Restate key" >&2; exit 1; }
if SECRETS_DIR=$dir ./seal.sh prod --dry-run >/dev/null 2>&1; then echo "FAIL: prod sealed without FCM_CREDENTIALS" >&2; exit 1; fi
echo "seal.sh is idempotent"
```

Run: `chmod +x infra/cluster/seal-test.sh && infra/cluster/seal-test.sh`
Expected: FAIL, `./seal.sh: No such file or directory`.

- [ ] **Step 6: Write `seal.sh`**

```bash
#!/usr/bin/env bash
# seal.sh dev|prod [--dry-run]
#
# Seals <stack>.env into infra/stack/secrets/<stack>/*.yaml. On first use it
# copies example.env, generates every key the stack needs and keeps them in
# the git-ignored <stack>.env, so a later run seals the same keys.
# --dry-run prints the plain Secrets instead of sealing them; it needs no cluster.
set -euo pipefail
stack=${1:?usage: seal.sh dev|prod [--dry-run]}
[[ $stack == dev || $stack == prod ]] || { echo "stack must be dev or prod" >&2; exit 2; }
dry=${2:-}
here=$(cd "$(dirname "$0")" && pwd)
dir=${SECRETS_DIR:-$here/../stack/secrets}
env_file=$dir/$stack.env
pem=$dir/$stack.restate.pem
image=${SERVER_IMAGE:-ghcr.io/shopnexus/server:main}

[[ -f $env_file ]] || cp "$here/../stack/secrets/example.env" "$env_file"
get() { grep -m1 "^$1=" "$env_file" | cut -d= -f2-; }
has() { grep -q "^$1=." "$env_file"; }

has JWT_KEY_ID || docker run --rm --entrypoint /keygen "$image" >> "$env_file"
has STAFF_KEY || docker run --rm --entrypoint /keygen "$image" -staff >> "$env_file"
if ! has RESTATE_IDENTITY_KEY || [[ ! -f $pem ]]; then
  sed -i '/^RESTATE_IDENTITY_KEY=/d' "$env_file"
  docker run --rm --user "$(id -u)" -v "$dir:/out" --entrypoint /keygen "$image" \
    -restate "/out/$(basename "$pem")" >> "$env_file"
fi
has OBJECT_STORE_ACCESS_KEY || echo "OBJECT_STORE_ACCESS_KEY=$(openssl rand -hex 12)" >> "$env_file"
has OBJECT_STORE_SECRET_KEY || echo "OBJECT_STORE_SECRET_KEY=$(openssl rand -hex 24)" >> "$env_file"

has LLM_API_KEY || { echo "$env_file: set LLM_API_KEY" >&2; exit 1; }
if [[ $stack == prod ]] && ! has FCM_CREDENTIALS; then
  echo "$env_file: prod needs FCM_CREDENTIALS (APP_ENV=prod refuses to only log pushes)" >&2; exit 1
fi

server_keys=(JWT_KEY_ID JWT_PRIVATE_KEY STAFF_KEY RESTATE_IDENTITY_KEY OBJECT_STORE_ACCESS_KEY OBJECT_STORE_SECRET_KEY LLM_API_KEY FCM_CREDENTIALS)
args=(); for k in "${server_keys[@]}"; do args+=(--from-literal="$k=$(get "$k")"); done

out() { if [[ $dry == --dry-run ]]; then cat; else kubeseal --format yaml > "$1"; fi; }
mkdir -p "$here/../stack/secrets/$stack"
kubectl create secret generic server-secrets -n "shopnexus-$stack" "${args[@]}" --dry-run=client -o yaml \
  | out "$here/../stack/secrets/$stack/server-secrets.yaml"
kubectl create secret generic restate-secrets -n "restate-$stack" \
  --from-file=private.pem="$pem" \
  --from-literal=AWS_ACCESS_KEY_ID="$(get OBJECT_STORE_ACCESS_KEY)" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$(get OBJECT_STORE_SECRET_KEY)" \
  --dry-run=client -o yaml \
  | out "$here/../stack/secrets/$stack/restate-secrets.yaml"
[[ $dry == --dry-run ]] || echo "sealed into infra/stack/secrets/$stack/; commit and push"
```

`chmod +x infra/cluster/seal.sh`. Build the image locally first (`docker build -t ghcr.io/shopnexus/server:main server`) if GHCR has none yet.

- [ ] **Step 7: Ignore the plain files**

Append to the umbrella `.gitignore`:

```
infra/stack/secrets/*.env
!infra/stack/secrets/example.env
infra/stack/secrets/*.pem
```

- [ ] **Step 8: Run both tests**

Run: `infra/cluster/seal-test.sh && infra/check.sh`
Expected: `seal.sh is idempotent`, then `all checks passed`.

- [ ] **Step 9: Commit**

```bash
git add .gitignore infra && git commit -m "infra: seal.sh generates the keys once and seals them per stack"
```

---

### Task 12: Argo CD, platform and Image Updater

**Files:**
- Create: `infra/argocd/root.yaml`
- Create: `infra/argocd/stacks.yaml`
- Create: `infra/platform/cnpg.yaml`, `infra/platform/sealed-secrets.yaml`, `infra/platform/image-updater.yaml`, `infra/platform/restate-operator.yaml`
- Modify: `infra/check.sh`

**Interfaces:**
- Consumes: chart `infra/stack` and values files.
- Produces: Applications `root`, `stack-dev` (namespace `shopnexus-dev`), `stack-prod` (`shopnexus-prod`), `cnpg`, `sealed-secrets`, `image-updater`, `restate-operator`; an `ImageUpdater` resource `shopnexus`. Helm parameters written by Image Updater: `images.server.tag`, `images.website.tag`, `images.docs.tag`.

- [ ] **Step 1: Look up the chart versions**

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm search repo cnpg/cloudnative-pg sealed-secrets/sealed-secrets argo/argocd-image-updater argo/argo-cd
helm show chart oci://ghcr.io/restatedev/restate-operator-helm | grep '^version'
```

Use each printed chart version as `targetRevision` below and in `up.sh` (Task 13). Image Updater must be v1 or newer (CRD configuration).

- [ ] **Step 2: Add the checks**

```bash
# ── argo ──
apps=$(cat argocd/*.yaml platform/*.yaml)
eq "$(q "$apps" 'select(.kind=="Application") | .metadata.name' | sort | tr '\n' ' ')" "cnpg image-updater restate-operator root sealed-secrets stack-dev stack-prod " "applications"
eq "$(q "$apps" 'select(.kind=="Application" and .metadata.name=="stack-prod") | .spec.source.helm.valueFiles[0]')" values-prod.yaml "prod values"
eq "$(q "$apps" 'select(.kind=="Application" and .metadata.name=="stack-prod") | .spec.destination.namespace')" shopnexus-prod "prod namespace"
eq "$(q "$apps" 'select(.kind=="Application") | .spec.source.repoURL // .spec.sources[].repoURL' | grep github.com | sort -u | wc -l | tr -d ' ')" 1 "one repo URL for the umbrella"
eq "$(q "$apps" 'select(.kind=="Application" and .metadata.name=="root") | .spec.ignoreDifferences[0].jsonPointers[0]')" /spec/source/helm/parameters "root keeps Image Updater's parameters"
eq "$(q "$apps" 'select(.kind=="ImageUpdater") | .spec.applicationRefs[] | select(.namePattern=="stack-prod") | .images[0].commonUpdateSettings.updateStrategy')" semver "prod by semver"
eq "$(q "$apps" 'select(.kind=="ImageUpdater") | .spec.applicationRefs[] | select(.namePattern=="stack-dev") | .images[0].commonUpdateSettings.updateStrategy')" digest "dev by digest"
```

Run: `infra/check.sh` — Expected: FAIL for these checks.

- [ ] **Step 3: Write `root.yaml`**

```yaml
# The app-of-apps. up.sh applies it once; from then on Argo CD manages
# everything under infra/platform and infra/argocd/stacks.yaml, this file included.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  sources:
    - repoURL: https://github.com/shopnexus/shopnexus.git
      targetRevision: main
      path: infra/platform
    - repoURL: https://github.com/shopnexus/shopnexus.git
      targetRevision: main
      path: infra/argocd
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  # Image Updater writes image tags as Helm parameters on the stack
  # Applications; without this, self-heal would put them back.
  ignoreDifferences:
    - group: argoproj.io
      kind: Application
      jsonPointers: [/spec/source/helm/parameters]
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [RespectIgnoreDifferences=true]
```

- [ ] **Step 4: Write `stacks.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: stack-dev
  namespace: argocd
  annotations: { argocd.argoproj.io/sync-wave: "1" }
spec:
  project: default
  source:
    repoURL: https://github.com/shopnexus/shopnexus.git
    targetRevision: main
    path: infra/stack
    helm: { valueFiles: [values-dev.yaml] }
  destination: { server: https://kubernetes.default.svc, namespace: shopnexus-dev }
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true, ServerSideApply=true]
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: stack-prod
  namespace: argocd
  annotations: { argocd.argoproj.io/sync-wave: "1" }
spec:
  project: default
  source:
    repoURL: https://github.com/shopnexus/shopnexus.git
    targetRevision: main
    path: infra/stack
    helm: { valueFiles: [values-prod.yaml] }
  destination: { server: https://kubernetes.default.svc, namespace: shopnexus-prod }
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true, ServerSideApply=true]
---
# dev follows :main by digest; prod follows the newest X.Y.Z tag.
apiVersion: argocd-image-updater.argoproj.io/v1alpha1
kind: ImageUpdater
metadata:
  name: shopnexus
  namespace: argocd
  annotations: { argocd.argoproj.io/sync-wave: "2" }
spec:
  applicationRefs:
    - namePattern: stack-dev
      images:
        - { alias: server, imageName: "ghcr.io/shopnexus/server:main", commonUpdateSettings: { updateStrategy: digest }, manifestTargets: { helm: { name: images.server.repository, tag: images.server.tag } } }
        - { alias: website, imageName: "ghcr.io/shopnexus/website:main", commonUpdateSettings: { updateStrategy: digest }, manifestTargets: { helm: { name: images.website.repository, tag: images.website.tag } } }
        - { alias: docs, imageName: "ghcr.io/shopnexus/docs:main", commonUpdateSettings: { updateStrategy: digest }, manifestTargets: { helm: { name: images.docs.repository, tag: images.docs.tag } } }
    - namePattern: stack-prod
      images:
        - { alias: server, imageName: ghcr.io/shopnexus/server, commonUpdateSettings: { updateStrategy: semver }, manifestTargets: { helm: { name: images.server.repository, tag: images.server.tag } } }
        - { alias: website, imageName: ghcr.io/shopnexus/website, commonUpdateSettings: { updateStrategy: semver }, manifestTargets: { helm: { name: images.website.repository, tag: images.website.tag } } }
        - { alias: docs, imageName: ghcr.io/shopnexus/docs, commonUpdateSettings: { updateStrategy: semver }, manifestTargets: { helm: { name: images.docs.repository, tag: images.docs.tag } } }
```

The `ImageUpdater` field names come from the v1 docs and are checked against the installed CRD in Task 16 Step 7.

- [ ] **Step 5: Write the platform Applications**

Each file is one Application in namespace `argocd`, `project: default`, `syncPolicy: { automated: { prune: true, selfHeal: true }, syncOptions: [CreateNamespace=true, ServerSideApply=true] }`, wave `"0"`. Sources:

`infra/platform/cnpg.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cnpg
  namespace: argocd
  annotations: { argocd.argoproj.io/sync-wave: "0" }
spec:
  project: default
  source:
    repoURL: https://cloudnative-pg.github.io/charts
    chart: cloudnative-pg
    targetRevision: <cnpg/cloudnative-pg version from Step 1>
  destination: { server: https://kubernetes.default.svc, namespace: cnpg-system }
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true, ServerSideApply=true]
```

`infra/platform/sealed-secrets.yaml`: same shape, `repoURL: https://bitnami-labs.github.io/sealed-secrets`, `chart: sealed-secrets`, namespace `kube-system`, plus

```yaml
    helm:
      valuesObject:
        fullnameOverride: sealed-secrets-controller   # the name kubeseal looks for
```

`infra/platform/image-updater.yaml`: same shape, `repoURL: https://argoproj.github.io/argo-helm`, `chart: argocd-image-updater`, namespace `argocd`.

`infra/platform/restate-operator.yaml`: same shape, `repoURL: ghcr.io/restatedev`, `chart: restate-operator-helm`, namespace `restate-operator`. Argo CD needs the OCI registry declared; add a second document to the file:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: repo-restatedev-oci
  namespace: argocd
  labels: { argocd.argoproj.io/secret-type: repository }
stringData:
  type: helm
  name: restatedev
  url: ghcr.io/restatedev
  enableOCI: "true"
```

Replace every `<... version from Step 1>` with the version Step 1 printed. The check in the next step fails while any such marker is left in `infra/platform` or `infra/cluster`.

- [ ] **Step 6: Add the placeholder check and run**

```bash
ok $(! grep -rq 'from Step 1\|from Task 12' platform cluster; echo $?) "chart versions pinned"
```

Run: `infra/check.sh`
Expected: `all checks passed`.

- [ ] **Step 7: Commit**

```bash
git add infra && git commit -m "infra: app-of-apps, platform operators and Image Updater"
```

---

### Task 13: Cluster, edge and smoke script

**Files:**
- Create: `infra/cluster/k3d.yaml`
- Create: `infra/cluster/edge-direct.yaml`
- Create: `infra/cluster/edge-behind-proxy.yaml`
- Create: `infra/cluster/up.sh`
- Create: `infra/smoke.sh`

**Interfaces:**
- Consumes: `infra/argocd/root.yaml`.
- Produces: `up.sh direct|behind-proxy` (env `ACME_EMAIL` required for direct, `ACME_SERVER` defaults to Let's Encrypt staging); cluster `shopnexus` with nodes `k3d-shopnexus-server-0`, `k3d-shopnexus-agent-{0,1,2}`; behind-proxy listens on `127.0.0.1:18080`. `smoke.sh <domain> [-k]`.

- [ ] **Step 1: Look up the k3s image**

```bash
gh release view -R k3s-io/k3s --json tagName -q .tagName   # e.g. v1.34.2+k3s1 → image tag v1.34.2-k3s1
```

- [ ] **Step 2: Write `k3d.yaml`**

```yaml
# One server node and three agents. Each agent stands in for a machine:
# agent-0 prefers the stateful workloads, agent-1 and agent-2 the apps.
apiVersion: k3d.io/v1alpha5
kind: Simple
metadata:
  name: shopnexus
servers: 1
agents: 3
image: rancher/k3s:v1.34.2-k3s1   # the tag from Step 1
options:
  k3s:
    nodeLabels:
      - label: role=stateful
        nodeFilters: [agent:0]
      - label: role=app
        nodeFilters: [agent:1, agent:2]
```

- [ ] **Step 3: Write the edge configs**

`edge-direct.yaml`:

```yaml
# Traefik holds 80/443 and gets certificates from Let's Encrypt with the
# TLS-ALPN-01 challenge. up.sh fills ${ACME_EMAIL} and ${ACME_SERVER}.
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    deployment:
      replicas: 1
    updateStrategy:
      type: Recreate
    nodeSelector:
      node-role.kubernetes.io/control-plane: "true"
    tolerations:
      - { key: node-role.kubernetes.io/control-plane, operator: Exists, effect: NoSchedule }
    logs:
      access:
        enabled: true
    persistence:
      enabled: true
      size: 128Mi
      path: /data
    podSecurityContext:
      fsGroup: 65532
    certificatesResolvers:
      le:
        acme:
          email: ${ACME_EMAIL}
          storage: /data/acme.json
          caServer: ${ACME_SERVER}
          tlsChallenge: {}
    ports:
      web:
        redirections:
          entryPoint: { to: websecure, scheme: https, permanent: true }
      websecure:
        tls:
          enabled: true
          certResolver: le
```

`edge-behind-proxy.yaml`:

```yaml
# Another proxy on the host terminates TLS and sends HTTP to 127.0.0.1:18080,
# which k3d maps to Traefik's web entrypoint. Traefik believes the
# X-Forwarded-* headers coming through the k3d network.
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    deployment:
      replicas: 1
    nodeSelector:
      node-role.kubernetes.io/control-plane: "true"
    tolerations:
      - { key: node-role.kubernetes.io/control-plane, operator: Exists, effect: NoSchedule }
    ports:
      web:
        forwardedHeaders:
          trustedIPs: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
```

- [ ] **Step 4: Write `up.sh`**

```bash
#!/usr/bin/env bash
# up.sh direct|behind-proxy
#
# Creates the k3d cluster, configures Traefik for the edge mode, installs
# Argo CD and applies the root Application. Argo CD does the rest.
#   direct        Traefik takes host ports 80 and 443; needs ACME_EMAIL.
#                 ACME_SERVER defaults to Let's Encrypt staging.
#   behind-proxy  Traefik listens on 127.0.0.1:18080 for a proxy on the host.
set -euo pipefail
edge=${1:?usage: up.sh direct|behind-proxy}
cd "$(dirname "$0")"
ARGOCD_CHART=<argo/argo-cd version from Task 12 Step 1>

case $edge in
  direct)
    : "${ACME_EMAIL:?direct needs ACME_EMAIL}"
    ACME_SERVER=${ACME_SERVER:-https://acme-staging-v02.api.letsencrypt.org/directory}
    ports=(--port 80:80@loadbalancer --port 443:443@loadbalancer) ;;
  behind-proxy)
    ports=(--port 127.0.0.1:18080:80@loadbalancer) ;;
  *) echo "edge must be direct or behind-proxy" >&2; exit 2 ;;
esac

k3d cluster create --config k3d.yaml "${ports[@]}"
sed -e "s|\${ACME_EMAIL}|${ACME_EMAIL:-}|" -e "s|\${ACME_SERVER}|${ACME_SERVER:-}|" "edge-$edge.yaml" | kubectl apply -f -

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd --version "$ARGOCD_CHART" \
  --namespace argocd --create-namespace --wait
kubectl apply -f ../argocd/root.yaml

echo "Argo CD is syncing. Watch it with: kubectl -n argocd get applications -w"
echo "Then seal the secrets: infra/cluster/seal.sh dev && infra/cluster/seal.sh prod"
```

Fill `ARGOCD_CHART` with the version from Task 12 Step 1. `chmod +x infra/cluster/up.sh`.

- [ ] **Step 5: Write `smoke.sh`**

```bash
#!/usr/bin/env bash
# smoke.sh <domain> [-k]: requests every host of one stack. -k accepts a
# staging certificate.
set -euo pipefail
d=${1:?usage: smoke.sh <domain> [-k]}
k=${2:-}
fails=0
check() {
  code=$(curl -s $k -o /dev/null -w '%{http_code}' --max-time 10 "$1") || code=000
  if [[ $code == "$2" ]]; then echo "ok   $1 $code"; else echo "FAIL $1 got $code want $2"; fails=$((fails + 1)); fi
}
check "https://$d/" 200
check "https://api.$d/healthz" 200
check "https://api.$d/readyz" 200
check "https://docs.$d/" 200
check "https://media.$d/health" 200
check "http://api.$d/healthz" 308   # plain HTTP is redirected: by Caddy behind a proxy, by Traefik in direct mode
(( fails == 0 ))
```

`chmod +x infra/smoke.sh`.

- [ ] **Step 6: Try the cluster locally**

On the laptop (Docker running, nothing on port 18080):

```bash
infra/cluster/up.sh behind-proxy
kubectl get nodes -L role
kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik -o wide
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: nothing.example' http://127.0.0.1:18080/
k3d cluster delete shopnexus
```

Expected: four nodes, `role` shows `stateful` on agent-0 and `app` on agent-1 and agent-2; Traefik runs on `k3d-shopnexus-server-0`; curl prints `404` (Traefik answered). Argo will fail to sync because the branch is not on `main` yet; that is expected here.

- [ ] **Step 7: Check the client address in direct mode**

On the laptop, with ports 80 and 443 free:

```bash
ACME_EMAIL=test@example.com infra/cluster/up.sh direct
sleep 30
curl -sk -o /dev/null -H 'Host: nothing.example' https://$(ip -4 route get 1.1.1.1 | awk '{print $7; exit}')/
kubectl -n kube-system logs -l app.kubernetes.io/name=traefik --tail=5
k3d cluster delete shopnexus
```

Expected: the access log line starts with the laptop's LAN address. If it shows a `172.x` or `10.42.x` address instead, k3d's serverlb hides the client: change the `direct` ports in `up.sh` to `--port 80:80@server:0 --port 443:443@server:0`, add `service: { spec: { externalTrafficPolicy: Local } }` to `edge-direct.yaml`, repeat the check, and record the result in the spec's Edge section.

- [ ] **Step 8: Commit**

```bash
git add infra && git commit -m "infra: k3d cluster, two edge modes, up.sh and smoke.sh"
```

---

### Task 14: Umbrella README

**Files:**
- Modify: `README.md` (umbrella)

- [ ] **Step 1: Rewrite the Deployment section**

Replace the "Deployment (CI/CD)" section, and the line in "Development" that says production is in `./deploy`, through the `humanizing-writing` skill, with these facts: images build in each component repo (`:main` on push, `X.Y.Z` on `v*`); `infra/` holds the cluster; dev at `dev.shopnexus.id.vn` follows `main`, prod at `shopnexus.id.vn` follows tags; bootstrap is the five steps of the spec's Bootstrap section (fork and set `repoURL` in `infra/argocd/root.yaml` and `infra/argocd/stacks.yaml` and `domain` in the two values files; DNS for `<domain>`, `*.<domain>`, `*.dev.<domain>`; `infra/cluster/up.sh direct` or `behind-proxy`; `infra/cluster/seal.sh dev|prod`, commit, push; Argo syncs); the sealed-secrets controller key is the one thing to back up (`kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml`); `infra/check.sh` validates the chart. Run the skill's checker on the section.

- [ ] **Step 2: Commit**

```bash
git add README.md && git commit -m "docs: deployment through infra/"
```

---

### Task 15: Caddy snippet for the author's server

**Files:**
- Create (server repo `~/linux-server-setup` on `khoakomlem-internal.ddns.net`): `caddy/shopnexus.caddy`

- [ ] **Step 1: Write the snippet**

```bash
ssh khoakomlem-internal.ddns.net 'mkdir -p ~/linux-server-setup/caddy && cat > ~/linux-server-setup/caddy/shopnexus.caddy' <<'EOF'
# ShopNexus dev and prod stacks on k3d (shopnexus/infra, edge mode
# behind-proxy). Caddy holds TLS; Traefik in the cluster routes by Host.
# Install: sudo cp caddy/shopnexus.caddy /etc/caddy/conf.d/ && sudo systemctl reload caddy
shopnexus.id.vn, api.shopnexus.id.vn, ops.shopnexus.id.vn, media.shopnexus.id.vn, docs.shopnexus.id.vn,
dev.shopnexus.id.vn, api.dev.shopnexus.id.vn, ops.dev.shopnexus.id.vn, media.dev.shopnexus.id.vn, docs.dev.shopnexus.id.vn {
	request_body {
		max_size 50MB
	}
	reverse_proxy 127.0.0.1:18080
}
EOF
ssh khoakomlem-internal.ddns.net 'caddy validate --adapter caddyfile --config ~/linux-server-setup/caddy/shopnexus.caddy'
```

Expected: `Valid configuration`.

- [ ] **Step 2: Confirm the firewall needs no change**

Behind-proxy traffic goes Caddy → `lo` → k3d's port map → a `br-*` bridge. The `gate` chain accepts `lo` (via `trusted_ifaces`) and `iifname "br-*"`. Ask the user to run `! ssh khoakomlem-internal.ddns.net sudo nft list ruleset | grep -nE 'dport (80|443)|tcp dport'` and record which rule admits 443 today; no rule changes.

- [ ] **Step 3: Commit in that repo**

```bash
ssh khoakomlem-internal.ddns.net 'cd ~/linux-server-setup && git add caddy/shopnexus.caddy && git commit -m "caddy: shopnexus dev and prod behind the k3d cluster"'
```

---

### Task 16: Bring-up on the server

**Files:** none new; secrets under `infra/stack/secrets/{dev,prod}/` are committed in Step 6.

- [ ] **Step 1: Merge and release (confirm each with the user)**

Push `infra-k3d` in `server`, `docs`, `website` and the umbrella; open and merge the PRs into `main`. After CI has built `:main`, tag `v0.1.0` in `server`, `website` and `docs` and wait for the `0.1.0` images on GHCR. Make the three GHCR packages public (GitHub → Packages → Package settings → Change visibility), or the cluster cannot pull them anonymously.

- [ ] **Step 2: DNS (the user)**

A records to the server's public IP (the one `khoakomlem-internal.ddns.net` resolves to): `shopnexus.id.vn`, `*.shopnexus.id.vn`, `*.dev.shopnexus.id.vn`. Check: `dig +short api.dev.shopnexus.id.vn` prints that IP.

- [ ] **Step 3: Remove the stale cluster network and check memory**

```bash
ssh khoakomlem-internal.ddns.net 'k3d cluster list; docker network rm k3d-main; free -g | sed -n 2p'
```

Expected: no clusters listed; the network removed; record "available" memory. If it is under 6 GB, stop and ask the user whether to run dev scaled to zero (`replicas.*: 0`, `postgres.instances: 1`, `restate.replicas: 1`) before going on.

- [ ] **Step 4: Language model**

LiteLLM in each stack calls `litellm.model` (`claude-haiku-5-5`) at `litellm.apiBase` (`http://host.k3d.internal:8317/v1`, cli-proxy-api, which listens on `*:8317`). Nothing to change in values; Step 6 puts one of cli-proxy-api's `access.api-keys` into `LLM_UPSTREAM_API_KEY` of both `.env` files.

- [ ] **Step 5: Create the cluster**

```bash
ssh khoakomlem-internal.ddns.net 'cd ~ && (test -d shopnexus || git clone --recurse-submodules https://github.com/shopnexus/shopnexus.git) && cd shopnexus && git pull && PATH=$HOME/.local/bin:$PATH infra/cluster/up.sh behind-proxy'
ssh khoakomlem-internal.ddns.net 'kubectl -n argocd get applications'
```

Expected after a few minutes: `cnpg`, `sealed-secrets`, `image-updater`, `restate-operator` Synced and Healthy; `stack-dev` and `stack-prod` Unknown with a ComparisonError that says `run infra/cluster/seal.sh <stack>` (the chart refuses to render without sealed secrets, and both Applications retry); `root` Synced once wave 1 is applied.

- [ ] **Step 6: Seal and push the secrets**

Run on the server, where `kubectl` already points at the cluster and Docker can run `/keygen`:

```bash
ssh -t khoakomlem-internal.ddns.net 'cd ~/shopnexus && PATH=$HOME/.local/bin:$PATH infra/cluster/seal.sh dev'
```

The first run copies `example.env` to `dev.env` and stops at `set LLM_API_KEY`. Have the user fill `dev.env` and `prod.env` (`FCM_CREDENTIALS` for prod) on the server, run `seal.sh dev` and `seal.sh prod`, then commit `infra/stack/secrets/{dev,prod}/*.yaml` and push (confirm). Back up the controller key and both `*.env` and `*.restate.pem` files to the user's password manager.

- [ ] **Step 7: Verify the operator assumptions**

```bash
ssh khoakomlem-internal.ddns.net bash -s <<'EOF'
kubectl explain restatecluster.spec.compute.env >/dev/null && echo "compute.env ok"
kubectl -n restate-dev get svc
kubectl -n restate-dev get networkpolicy -o yaml | grep -A6 -E 'podSelector|namespaceSelector' | head -40
kubectl explain imageupdater.spec.applicationRefs.images.manifestTargets.helm
EOF
```

Check four facts and fix the chart where one differs, then commit, push and let Argo sync:
1. `compute.env` exists. If not, move the snapshot credentials into `spec.config` through the operator's documented way of passing secrets and record it in the spec.
2. `restate-dev` has a Service `restate` with ports 8080 and 9070, and a headless `restate-cluster` with 5122. If names differ, update `RESTATE_*_URL` in `server.yaml` and `[metadata-client] addresses` in `restate.yaml`.
3. The operator's NetworkPolicies admit the server pods. If they require a label such as `allow.restate.dev/<cluster>`, add it to the server pod template labels.
4. `manifestTargets.helm` has `name` and `tag`. If the fields differ, update `stacks.yaml`.

- [ ] **Step 8: Watch the stacks come up**

```bash
ssh khoakomlem-internal.ddns.net 'kubectl -n argocd get applications; kubectl -n shopnexus-dev get pods -o wide; kubectl -n shopnexus-prod get pods -o wide; kubectl get pods -A -l app.kubernetes.io/name=restate -o wide'
```

Expected: both stacks Synced and Healthy; prod has 3 server pods on agent-1/agent-2, 2 postgres pods on different nodes, 3 restate pods on three different nodes. If postgres pods fail with an error about the image (CNPG cannot manage `paradedb/paradedb`), switch `postgres.yaml` to ParadeDB's extension-image path from https://www.paradedb.com/docs/deploy/self-hosted/kubernetes (base `ghcr.io/cloudnative-pg/postgresql:18-minimal-trixie`, extensions `vector` and `pg_search`), which needs Kubernetes image volumes (k3s 1.33+). If rustfs fails with a permission error on `/data`, read its uid with `docker run --rm --entrypoint id rustfs/rustfs:1.0.4` and set `securityContext.fsGroup` to it.

- [ ] **Step 9: Check Image Updater survives the root app (Review Focus 4)**

Push an empty commit to `server` `main`, wait for CI, then:

```bash
ssh khoakomlem-internal.ddns.net 'sleep 180; kubectl -n argocd get application stack-dev -o jsonpath="{.spec.source.helm.parameters}"; echo; kubectl -n argocd get application root -o jsonpath="{.status.sync.status}"'
```

Expected: a parameter `images.server.tag` with a `@sha256:` digest, and `root` `Synced`. A new server version appears in `kubectl -n shopnexus-dev get rs`.

- [ ] **Step 10: Install the Caddy snippet (the user, sudo)**

`! ssh -t khoakomlem-internal.ddns.net 'sudo cp ~/linux-server-setup/caddy/shopnexus.caddy /etc/caddy/conf.d/ && sudo systemctl reload caddy'`

- [ ] **Step 11: Smoke test both stacks**

```bash
infra/smoke.sh dev.shopnexus.id.vn
infra/smoke.sh shopnexus.id.vn
```

Expected: every line `ok`.

- [ ] **Step 12: Remove the stale Caddy blocks (confirm with the user)**

The `docs.`, `grafana.`, `argocd.` and `shop.toanehihi.io.vn` blocks in `/etc/caddy/Caddyfile` point at the deleted k3d cluster. With the user's yes, they delete those blocks with `sudo`, run `caddy validate --config /etc/caddy/Caddyfile`, and reload.

---

### Task 17: Failover drills

**Files:**
- Create: `infra/drills.md` — the record of each run: date, command, observed result.

- [ ] **Step 1: Postgres primary**

```bash
ssh khoakomlem-internal.ddns.net bash -s <<'EOF'
p=$(kubectl -n shopnexus-prod get cluster postgres -o jsonpath='{.status.currentPrimary}')
kubectl -n shopnexus-prod delete pod "$p"
for i in $(seq 30); do kubectl -n shopnexus-prod get cluster postgres -o jsonpath='{.status.currentPrimary} {.status.phase}{"\n"}'; sleep 2; done
EOF
infra/smoke.sh shopnexus.id.vn
```

Expected: `currentPrimary` changes to the other instance within a minute; smoke passes.

- [ ] **Step 2: An agent stops**

```bash
ssh khoakomlem-internal.ddns.net 'docker stop k3d-shopnexus-agent-1; sleep 90; kubectl -n shopnexus-prod get pods -o wide; kubectl -n restate-prod get pods -o wide'
infra/smoke.sh shopnexus.id.vn
ssh khoakomlem-internal.ddns.net 'docker start k3d-shopnexus-agent-1'
```

Expected: server pods from agent-1 run elsewhere after the node's eviction timeout; two restate pods stay Running and Restate keeps serving (`/readyz` 200); smoke passes.

- [ ] **Step 3: A release during a running invocation**

Start a durable flow that takes a while (posting a listing with photos from the app on dev), then push a commit to `server` `main` within the same minute. Then:

```bash
ssh khoakomlem-internal.ddns.net 'kubectl -n shopnexus-dev get rs; kubectl -n restate-dev exec restate-dev-0 -- restate deployments list'
```

Expected: two server ReplicaSets and two deployments while the flow runs; the flow completes; afterwards the old ReplicaSet scales to 0.

- [ ] **Step 4: Dev cannot reach prod**

```bash
ssh khoakomlem-internal.ddns.net 'kubectl -n shopnexus-dev run probe --rm -i --restart=Never --image=busybox:stable -- sh -c "nc -zv -w 3 postgres-rw.shopnexus-prod 5432; nc -zv -w 3 postgres-rw.shopnexus-dev 5432"'
```

Expected: the prod connection times out; the dev connection succeeds.

- [ ] **Step 5: A presigned upload through both proxies (Review Focus 5)**

```bash
ssh khoakomlem-internal.ddns.net 'cd ~/shopnexus && grep -E "^OBJECT_STORE_(ACCESS|SECRET)_KEY=" infra/stack/secrets/dev.env' > tmp/s3.env
echo smoke > tmp/smoke.txt
docker run --rm --env-file <(sed -e 's/^OBJECT_STORE_ACCESS_KEY=/AWS_ACCESS_KEY_ID=/' -e 's/^OBJECT_STORE_SECRET_KEY=/AWS_SECRET_ACCESS_KEY=/' tmp/s3.env) \
  -e AWS_REGION=us-east-1 -v "$PWD/tmp:/w" amazon/aws-cli \
  s3 cp /w/smoke.txt s3://shopnexus/media/smoke.txt --endpoint-url https://media.dev.shopnexus.id.vn
curl -fsS https://media.dev.shopnexus.id.vn/shopnexus/media/smoke.txt
rm tmp/s3.env
```

Expected: the upload succeeds (the signature over `media.dev.shopnexus.id.vn` survives Caddy and Traefik), and curl prints `smoke` (the `media/` prefix is public).

- [ ] **Step 6: Memory**

```bash
ssh khoakomlem-internal.ddns.net 'free -g | sed -n 2p; docker stats --no-stream --format "{{.Name}} {{.MemUsage}}" | grep k3d-shopnexus'
```

Record the figures in `infra/drills.md`, and the spec's memory risk with the measured total.

- [ ] **Step 7: Commit**

```bash
git add infra/drills.md && git commit -m "infra: record of the first failover drills"
```
