# Ops dashboards behind the console's sign-in

Date: 2026-11-05. Status: approved.

## Goal

Staff who signed in to the console open the operations dashboards of a stack
without signing in again, each on a host of its own:

| Host | Dashboard | Who |
|---|---|---|
| `grafana.<domain>` | Grafana (traces, metrics, logs of the server) | every staff member |
| `restate.<domain>` | Restate's admin UI | admins |
| `litellm.<domain>` | LiteLLM's UI (keys, spend, budgets) | admins |
| `s3.<domain>` | RustFS's console (buckets, media) | admins |
| `argocd.<prod domain>` | Argo CD (one per cluster) | admins of the prod stack |

Decisions already taken with the user (2026-11-05):

- One sign-in, through a one-time ticket and a cookie per dashboard host. The
  console's `staff_session` cookie keeps its scope (`api.<domain>`,
  `/v1/staff`, `SameSite=Strict`).
- Restate's admin UI is for admins only. It can cancel invocations and
  register deployments.
- Argo CD, LiteLLM and RustFS join Grafana and Restate.
- Local stacks (root `docker-compose.yml`) already serve Grafana, Restate and
  RustFS at `*.localhost` with no sign-in (commit 22b4519). Nothing here
  changes that.

## Flow

```
browser                 Traefik                    server-api              console
   │ GET grafana.<d>/x     │                            │                      │
   ├──────────────────────►│ forwardAuth                │                      │
   │                       ├───────────────────────────►│ GET /v1/staff/       │
   │                       │                            │ dashboard-auth       │
   │                       │  302 console.<d>/dashboards/open?app=grafana&rd=/x│
   │◄──────────────────────┤◄───────────────────────────┤ (no dashboard cookie)│
   │ GET console.<d>/dashboards/open ...                                       │
   ├──────────────────────────────────────────────────────────────────────────►│
   │                                         POST /v1/staff/dashboard-tickets │
   │                                        ◄─────────────────────────────────┤
   │                                         {ticket}  (staff_session, role)  │
   │ 302 grafana.<d>/_dashboard/callback?ticket=…&rd=/x                        │
   │◄──────────────────────────────────────────────────────────────────────────┤
   │ GET grafana.<d>/_dashboard/callback   │ (path routed to server-api,      │
   ├──────────────────────►├───────────────►│  no forwardAuth)                 │
   │  Set-Cookie staff_dashboard (host-only), 302 /x                          │
   │◄──────────────────────┤◄───────────────┤                                  │
   │ GET grafana.<d>/x  (cookie)  forwardAuth → 200 + X-Staff-* → Grafana      │
```

If the console has no session, `/dashboards/open` sends the reader to the
console's sign-in first and back afterwards.

## Server (module staff)

Spec first, in `api/paths/staff.yaml`; the code follows.

### `POST /v1/staff/dashboard-tickets`

Console header and a moderator's session, like the rest of `/v1/staff`.
Body `{ "app": "grafana" | "restate" | "litellm" | "s3" | "argocd" }`.
Refuses with 403 `staff_forbidden` when the member's role is below the app's
floor (moderator for grafana, admin for the rest). Returns
`{ "ticket": "<opaque>", "callback_url": "https://<app host>/_dashboard/callback?ticket=…" }`.

A ticket is 32 random bytes, stored as its SHA-256 with the staff session's
ID, the app and an expiry 60 s ahead, and used once.

### `GET /_dashboard/callback?ticket=…&rd=…`

Served on each dashboard host: the Ingress routes the path `/_dashboard` of
the host to `server-api`, without forwardAuth. The server maps the request's
host to an app, takes the ticket (unused, unexpired, same app) and marks it
used, then sets `staff_dashboard`: a token tied to the staff session and the
app, `Secure`, `HttpOnly`, `SameSite=Lax`, `Path=/`, no `Domain`, so it stays
on that host. It redirects to `rd` when `rd` is a path on the same host, and
to `/` otherwise.

The token is stored like a ticket (hash, staff session ID, app). It lives as
long as the staff session: signing out of the console, a disabled member or
an expired session ends every dashboard session.

### `GET /v1/staff/dashboard-auth`

The forwardAuth target, called by Traefik with the original request's
`Cookie`, `X-Forwarded-Host`, `X-Forwarded-Uri` and `X-Forwarded-Method`.
No console header. It maps `X-Forwarded-Host` to an app and checks the
`staff_dashboard` cookie: token known, for that app, staff session live,
role at the app's floor.

- Pass: 200 with `X-Staff-Email` and `X-Staff-Role`; for Grafana the role is
  Grafana's (`Admin` for admins, `Viewer` for moderators).
- No or bad cookie, GET: 302 to
  `https://console.<domain>/dashboards/open?app=<app>&rd=<uri>`.
- No or bad cookie, other methods: 401.
- Role below the floor: 403.

### Configuration

`STAFF_CONSOLE_ORIGIN` already gives the console's origin. A new
`DASHBOARD_HOSTS` maps hosts to apps, e.g.
`grafana=grafana.dev.shopnexus.id.vn,restate=restate.dev.shopnexus.id.vn,…`;
an app missing from it is refused. Empty in compose, where nothing asks for a
sign-in.

### Data

A migration adds `staff_dashboard_ticket` and `staff_dashboard_session`, each
with the token's hash, the staff session ID (foreign key, cascade on delete),
the app and timestamps. A sign-out deletes the staff session and so its
dashboard sessions.

## Console

- `/dashboards/open?app&rd`: signs in first when needed, asks for a ticket,
  then navigates to `callback_url` with `rd`. A 403 shows that the member's
  role cannot open that dashboard.
- A "Công cụ" area in the navigation with the five links, the admin-only ones
  hidden from moderators.
- Depends on the console's sign-in screen, which does not exist yet. It goes
  through the Superdesign workflow before code, as every console screen does.

## Chart (`infra/stack`)

- `grafana/otel-lgtm` per stack (Deployment and PVC, wave 1). The server's
  `OTEL_EXPORTER_OTLP_ENDPOINT` becomes `http://lgtm:4318`. Grafana runs with
  `GF_AUTH_PROXY_ENABLED=true`, header `X-Staff-Email`, `Role:X-Staff-Role`,
  auto sign-up, and the login form off.
- A Traefik `Middleware` of kind forwardAuth per stack, address
  `http://server-api.<ns>:8080/v1/staff/dashboard-auth`,
  `authResponseHeaders: [X-Staff-Email, X-Staff-Role]`, so a client cannot
  set those headers itself.
- Ingress hosts `grafana.`, `restate.`, `litellm.` and `s3.` with the
  middleware, and the path `/_dashboard` on each to `server-api` without it.
- Restate: the Ingress and its middleware live in `restate-<stack>`, next to
  the admin Service. `networkPeers.admin` adds Traefik.
- LiteLLM serves its UI at `/ui`; it keeps its own sign-in (the master key)
  behind the gate. RustFS turns its console on (port 9001); it keeps its own
  sign-in (the object store keys).
- `from-traefik` admits `lgtm` and `litellm`, and RustFS's port 9001.
- `check.sh` and the helm-unittest suites cover the hosts, the middleware,
  the response headers and the peers.

## Argo CD

One per cluster, at `argocd.<prod domain>`, gated by the prod stack's
server. Its values (`infra/cluster/argocd.yaml`) turn on anonymous access with
`policy.default: role:admin`; the gate allows admins only. A running cluster
gets this by applying the HelmChart again by hand; the docs say how.

## Out of scope

- Single sign-on inside LiteLLM and RustFS: both keep their own sign-in.
- Alerting and dashboards in Grafana beyond what otel-lgtm ships.

## Settled after review (2026-11-05)

1. Argo CD's gate uses the prod stack's staff only.
2. LiteLLM and RustFS keep their own sign-in behind the gate.
