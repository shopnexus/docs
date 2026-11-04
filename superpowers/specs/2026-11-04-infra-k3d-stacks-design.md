# Design: infra on k3d, with a dev and a prod stack

Date: 2026-11-04.
Status: decided in conversation, question by question. It replaces the
umbrella's `deploy/` directory, which still describes the old backend
(gateway, NATS, Redis, TimescaleDB). Nothing in `deploy/` carries over,
including its names.

## Scope

One k3d cluster runs two stacks of ShopNexus, dev and prod, each in its own
namespace. The cluster has one server node and three agent nodes; each agent
stands in for a machine. This is a learning project, so k3d stays even though
the agents share one host and one disk. Real machines joining the cluster are
out of scope; the layout keeps manifests free of k3d specifics so a later move
to k3s on real hosts changes only `infra/cluster/`.

Everything needed to stand the cluster up lives in the umbrella repo. Someone
who forks it changes the repo URL and the two domains, runs one script, seals
their secrets and pushes. The only file specific to the author's server is a
Caddy snippet in `linux-server-setup`.

## Decisions

| Question | Decision |
|---|---|
| Orchestrator | k3d: one server node, three agents (`agent-0` `role=stateful`, `agent-1` and `agent-2` `role=app`). |
| Environments | One cluster, namespaces `shopnexus-dev` and `shopnexus-prod`. NetworkPolicy keeps them apart. |
| Domains | prod `shopnexus.id.vn`, dev `dev.shopnexus.id.vn`. Hosts derive from one `domain` value: `<domain>` website, `api.` server, `console.` staff console, `media.` object store, `docs.` docs. |
| Edge | Traefik bundled with k3s. Two modes: `direct` (Traefik holds 80/443, ACME) and `behind-proxy` (an existing proxy terminates TLS and forwards HTTP). |
| TLS | Traefik's ACME resolver, TLS-ALPN-01, `acme.json` on a persistent volume. No cert-manager while there is one Traefik. |
| Manifests | One Helm chart, `infra/stack`, with `values-dev.yaml` and `values-prod.yaml`. |
| GitOps | Argo CD, app-of-apps. Platform charts are referenced upstream and not vendored. |
| Releases | Push to `main` builds `:main`; Image Updater rolls dev by digest. Tag `v*` builds `:X.Y.Z`; Image Updater rolls prod by semver. |
| Secrets | Sealed Secrets. Postgres credentials come from CloudNativePG. |
| Postgres | CloudNativePG with the ParadeDB image. dev 1 instance, prod 2. |
| Restate | `restate-operator`. `RestateCluster` dev 1 node, prod 3. `RestateDeployment` runs `server`. |
| Object store | RustFS, 1 replica in each stack. Any S3 service can replace it by changing `OBJECT_STORE_*`. |
| Language model | LiteLLM in each stack (`litellm:4000`), its own database `litellm` on the stack's CNPG cluster. The server calls the alias `search` (today `claude-haiku-5-5` through cli-proxy-api at `host.k3d.internal:8317`) with a virtual key: `models: [search]`, a daily budget of 200k tokens on dev and 2M on prod, `tpm_limit` 20k and 100k. Budgets count money, so every token is priced at 1e-6 and 1 of budget is 1M tokens. A Sync hook Job (wave 3) updates the key, or creates it with the sealed value. |
| Components | `server`, `website`, `docs` and `console` (the staff console, its own repo and image; `console.enabled`). |
| Out of scope | Real machines, backups, observability, the root `docker-compose.yml`. |

## Repository layout

```
shopnexus/
└── infra/
    ├── cluster/                     # run by hand, once per machine
    │   ├── k3d.yaml                 # nodes, labels, port mappings
    │   ├── edge-direct.yaml         # HelmChartConfig: Traefik on 80/443 with ACME
    │   ├── edge-behind-proxy.yaml   # HelmChartConfig: Traefik on :18080, trusts X-Forwarded-*
    │   ├── up.sh                    # create cluster, apply edge, install Argo, apply root
    │   └── seal.sh                  # seal a stack's secrets: seal.sh dev|prod
    ├── argocd/
    │   └── root.yaml                # app-of-apps: platform, stack-dev, stack-prod
    ├── platform/                    # Applications for CNPG, sealed-secrets,
    │                                # argocd-image-updater, restate-operator
    └── stack/                       # Helm chart for one ShopNexus stack
        ├── Chart.yaml
        ├── values.yaml
        ├── values-dev.yaml
        ├── values-prod.yaml
        ├── secrets/                 # SealedSecrets per stack, and *.example.env templates
        └── templates/
```

Outside the umbrella:

- `server` gains a `Dockerfile`, `.github/workflows/build.yml`, and a way to turn
  off self-registration with Restate (see Restate).
- `docs` gains a `Dockerfile` for the Astro site and the same workflow.
- `website` already has a `Dockerfile`; its workflow tags `:X.Y.Z` on `v*` too.
- `linux-server-setup` gains `conf.d/shopnexus.caddy` and the firewall changes.

## Network

### Edge

```
 direct (a fresh machine)                    behind-proxy (the author's server)
 ────────────────────────                    ──────────────────────────────────
  Internet :80/:443                           Internet :80/:443
        │                                           │
        │                                    Caddy, shared with other projects
        │                                      other sites           → unchanged
        │                                      conf.d/shopnexus.caddy → TLS here,
        │                                      HTTP to 127.0.0.1:18080
        ▼                                           ▼
  k3d port map → Traefik websecure + ACME     k3d port map :18080 → Traefik web
        └──────────────── same Ingress rules, routed by Host ──────────────┘
```

The chart's Ingress resources name hosts and services and say nothing about
TLS. The resolver is set on the `websecure` entrypoint in
`edge-direct.yaml`, so the chart is identical in both modes. In
`behind-proxy`, Traefik trusts `X-Forwarded-*` only from the k3d network's
gateway address.

`up.sh --edge direct|behind-proxy` picks the HelmChartConfig and the port
mapping.

In `direct`, k3d's serverlb (an nginx stream proxy) hides the client address,
so `up.sh` maps 80/443 straight onto `server-0` (`@server:0:direct`), where
Traefik runs, and Traefik's Service uses `externalTrafficPolicy: Local`. A
request from the same host still shows a Docker gateway address, because
Docker's userland proxy handles it; the client address of a request from
another machine is checked on the first `direct` deployment.

k3s v1.37.1 bundles Traefik chart 41.4.0. Its schema refuses unknown keys
(`ports.web.redirections`, `ports.websecure.tls`, `logs`), and k3s then runs
Traefik with its defaults, so `infra/check.sh` renders both edge configs
against that chart.

### Inside the cluster

```
 Traefik ─ Host ─┬─ <domain>        → website
                 ├─ api.<domain>    → server-api :8080
                 ├─ console.<domain> → console
                 ├─ media.<domain>  → rustfs :9000
                 └─ docs.<domain>   → docs

 server pods ── DATABASE_URL ──────────► postgres-rw ──► primary ──► replica
             ── RESTATE_INGRESS_URL ───► restate (namespace restate-<stack>)
             ── OBJECT_STORE_ENDPOINT ─► rustfs
 restate ───── invokes ────────────────► per-version server Service :9080
```

Every arrow is a Kubernetes Service, which spreads connections over the pods
behind it on any node. Restate registers the endpoint as HTTP/1.1
(`use_http_11: true`), so each invocation is its own request and the spread
is even.

NetworkPolicy denies all ingress in each stack namespace and opens the
arrows above. Egress stays open, because the server calls Firebase, FCM and
the language model on the internet. `RestateCluster` creates its own namespace, so the policies name it.
No policy opens a path between `shopnexus-dev` and `shopnexus-prod`.

### Nodes

`agent-0` carries `role=stateful` and is preferred for RustFS. `agent-1` and
`agent-2` carry `role=app` for `server` and `website`. Postgres and Restate
pods use preferred anti-affinity, so the three Restate pods spread over the
three agents and still schedule when one agent is stopped.

## Workloads

### Restate

`RestateCluster` per stack, created by `restate-operator`:

- prod: `spec.compute.replicas: 3`, `[metadata-client] type = "replicated"`,
  `default-replication = 2`, `[worker.snapshots] destination` in the RustFS
  bucket `restate-snapshots`. The operator's README advises against a
  distributed cluster without snapshots because they speed up failover.
- dev: 1 replica.
- `spec.security.requestSigningPrivateKey` reads a SealedSecret. The server
  holds the public key in `RESTATE_IDENTITY_KEY`.

`RestateDeployment` runs `server`. It creates a ReplicaSet and a Service for
each version, registers the version with `register.cluster` and
`useHttp11: true`, and keeps an old version until its invocations finish,
then scales it to zero. An invocation that started on one version never
replays on another.

Today every server pod registers itself at start with `force: true`
(`internal/platform/restatex/restatex.go`). Under the operator that would
overwrite the operator's registration, so the server needs a switch, such as
`RESTATE_REGISTER=false`, that skips `register` in `internal/app/app.go`.

HTTP traffic goes through a separate Service, `server-api` on port 8080. It
selects every server pod, of any version. A selector on the newest version
would leave the Service without endpoints until the new pods are ready, and
an image tag tracked by digest (`main@sha256:...`) is not a valid label
value. An old version therefore serves API requests until the operator
scales it to zero, as a rolling update would.

### Postgres

A CloudNativePG `Cluster` named `postgres`, image `paradedb/paradedb` on
Postgres 18, `shared_preload_libraries: [pg_search]`. dev runs 1 instance,
prod 2. `DATABASE_URL` is the `uri` key of the `postgres-app` Secret that
CNPG creates; it points at `postgres-rw`, which follows the primary through a
failover.

### RustFS

A StatefulSet with one replica and a PVC. Buckets: `shopnexus`, the
server's `OBJECT_STORE_BUCKET`, whose `media/` keys are public-read, and
`restate-snapshots`. `objectstore-init` creates both: a second run sets
`OBJECT_STORE_BUCKET=restate-snapshots`. That run also opens the bucket's
`media/` prefix for reading, which holds nothing. The app uploads with presigned
URLs signed for `OBJECT_STORE_PUBLIC_ENDPOINT=https://media.<domain>`, so the
store is public through Traefik.

### Jobs and order

Argo sync waves:

| Wave | Resources |
|---|---|
| 0 | `postgres`, `rustfs`, `RestateCluster` |
| 1 | `migrate` (`cmd/migrate`) and `objectstore-init` (`cmd/objectstore-init`), as Sync hooks |
| 2 | `server` (`RestateDeployment`), `server-api`, `website`, `docs`, `console` |

The server refuses to start while migrations are pending
(`internal/app/app.go`), so `migrate` finishes before wave 2.

### Replicas

| | dev | prod |
|---|---|---|
| server | 1 | 3 |
| website | 1 | 2 |
| docs | 1 | 1 |
| postgres | 1 | 2 |
| restate | 1 | 3 |
| rustfs | 1 | 1 |

### Configuration

Non-secret values in `values-<stack>.yaml`: `domain`, replica counts, image
tags, `STAFF_CONSOLE_ORIGIN=https://console.<domain>`,
`MEDIA_PUBLIC_URL`, `OBJECT_STORE_PUBLIC_ENDPOINT`, `TRUSTED_PROXIES` set to
the pod CIDR. Secret values in a SealedSecret per stack: JWT keys, Firebase
settings, RustFS keys, the language model key, the Restate signing key.
`cmd/keygen` generates the JWT and Restate keys; the plan confirms its output.

## Bootstrap

```
0. Fork. Set repoURL in infra/argocd/root.yaml and domain in values-dev.yaml
   and values-prod.yaml.
1. DNS: A records for <domain>, *.<domain> and *.dev.<domain>.
2. infra/cluster/up.sh --edge direct        (or --edge behind-proxy)
   creates the cluster, applies the edge config, installs Argo CD and applies
   root.yaml. Argo installs the platform charts.
3. Fill infra/stack/secrets/<stack>.example.env, run seal.sh dev and
   seal.sh prod, commit, push.
4. Argo syncs stack-dev and stack-prod in waves 0, 1, 2.
```

Sealing comes after step 2 because `kubeseal` needs the controller's
certificate. The controller's key is the one thing to back up; without it the
committed SealedSecrets cannot be decrypted on a new cluster.

On the author's server, `behind-proxy` also needs `conf.d/shopnexus.caddy`,
which lists the ten hosts and proxies them to `127.0.0.1:18080`.

## Testing

- The umbrella's CI runs `helm lint` and `helm template | kubeconform` with
  each values file.
- A smoke script requests every host of both stacks and checks the
  certificate and an `api.` response.
- Failover drills, each with an expected result:
  1. Delete the Postgres primary pod. CNPG promotes the replica; the server
     keeps writing.
  2. `docker stop` an agent. `server` pods reschedule; Restate keeps
     accepting invocations.
  3. Release a server version while a long Restate invocation runs. The
     invocation finishes on the old version, which then scales to zero.
  4. From a pod in `shopnexus-dev`, connect to `postgres-rw.shopnexus-prod`.
     The connection is refused.

## Risks

- Memory. The author's server uses 17 of 19 GB before this work, and the two
  stacks are estimated at 6 to 8 GB. The plan measures it. Fallbacks: scale
  dev to zero when unused, or drop to two agents.
- ACME rate limits. The first deploy uses the Let's Encrypt staging
  endpoint.
- Firewall. `linux-server-setup/firewall` allows only TCP 22, yet Caddy
  answers on 443; the plan finds the rule that admits it before changing
  anything. The k3d network is a `br-*` bridge, which the `gate` chain
  already trusts.
- The website's `next.config.ts` bakes the API rewrite at build time from
  `NEXT_PUBLIC_API_URL`, so one image cannot carry two public API URLs. The
  image is built with `http://server-api:8080/v1`, the in-cluster Service
  name, which resolves inside whichever stack namespace the website runs in.
- The website was last changed on 2026-10-14 and still has screens from the
  escrow model. Deploying it is in scope; making it match server2 is the
  website's own work.
