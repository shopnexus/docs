# Module staff becomes module console

Date: 2026-11-08. Status: approved.

## Goal

The server's module `staff` is the back end of the web console, and nothing
else uses it. Its name, and the word "staff" in every identifier around it,
is replaced so that the code, the API, the database, the configuration, the
infrastructure and the docs use one vocabulary:

- **console** names the tool: the module, its routes, cookies, tables,
  configuration, headers and command.
- **member** names a person who signs in to it (a moderator or an admin).
  Inside the module the entity is already `Member`; outside it the caller is
  a `ConsoleMember`.

Behaviour does not change. Only names do.

Decisions taken with the user (2026-11-08):

- The roles keep their names, `moderator` and `admin`.
- Migrations 0003 and 0023 are edited in place instead of adding a renaming
  migration. The migrator's checksums then refuse every existing database,
  so dev and prod drop their whole database once. The user confirmed that
  no database holds data worth keeping.
- The person is "member" everywhere (option A), so `grep -ri staff` over the
  code, the API, the database and the configuration finds nothing.

## Names

| Now | After |
|---|---|
| `internal/staff`, imports `staffdomain`, `staffsvc` | `internal/console`, `consoledomain`, `consolesvc` |
| `staff.Mount`, `staff.NewService`, service type `staffsvc.Staff` | `console.Mount`, `console.NewService`, `consolesvc.Console` |
| `cmd/staff` | `cmd/console`; subcommands unchanged (`create-admin`, `disable`, `enable`, `unlock`, `reset-password`, `reset-totp`) |
| routes `/v1/staff/*` | `/v1/console/*` |
| `api/paths/staff.yaml`, security scheme `staffAuth` | `api/paths/console.yaml`, `consoleAuth` |
| cookie `staff_session`, path `/v1/staff` | `console_session`, path `/v1/console` |
| cookie `staff_dashboard` | `console_dashboard` |
| `authn.Staff{StaffID, ...}`, `authn.WithStaff`, `authn.StaffFrom` | `authn.ConsoleMember{MemberID, ...}`, `authn.WithConsoleMember`, `authn.ConsoleMemberFrom` |
| `audit.ActorStaff` (`"staff"`), `audit.ByStaff`, `Actor.StaffID` | `audit.ActorMember` (`"member"`), `audit.ByMember`, `Actor.MemberID` |
| actions `staff.create`, `staff.disable`, `staff.enable`, `staff.reset_password`, `staff.reset_totp`, `staff.unlock`; Go `audit.StaffCreate`, ... | `member.create`, `member.disable`, `member.enable`, `member.reset_password`, `member.reset_totp`, `member.unlock`; `audit.MemberCreate`, ... |
| target kind `staff`, `audit.TargetStaff`, `audit.Staff(id)` | `member`, `audit.TargetMember`, `audit.Member(id)` |
| JSON `actor.staff_id` in the `Action` schema | `actor.member_id` |
| error code `staff_forbidden`, `ErrStaffForbidden` | `console_forbidden`, `ErrConsoleForbidden` |
| env `STAFF_KEY`, `STAFF_CONSOLE_ORIGIN` | `CONSOLE_KEY`, `CONSOLE_ORIGIN` |
| `config.StaffConfig`, field `Config.Staff`, `config.NewStaffKey` | `config.ConsoleConfig`, `Config.Console`, `config.NewConsoleKey` |
| forwardAuth headers `X-Staff-Email`, `X-Staff-Role` | `X-Console-Email`, `X-Console-Role` |
| tables `staff_members`, `staff_sessions`, `staff_login_locks`, `staff_actions`, `staff_dashboard_tickets`, `staff_dashboard_sessions` | `console_members`, `console_sessions`, `console_login_locks`, `console_actions`, `console_dashboard_tickets`, `console_dashboard_sessions` |
| columns `staff_members.staff_role`, `staff_sessions.staff_id`, `staff_actions.staff_id`, `*.staff_session_id` | `console_members.console_role`, `console_sessions.member_id`, `console_actions.member_id`, `*.session_id` |
| `staff_actions.actor_kind IN ('staff', 'cli')`, `target_kind IN ('account', 'staff')` | `('member', 'cli')`, `('account', 'member')` |
| indexes `staff_*` | `console_*`, column parts renamed with their columns |
| `migrations/0003_staff.sql`, `0023_staff_dashboards.sql` | `0003_console.sql`, `0023_console_dashboards.sql`, edited in place |
| e2e `staff_*_test.go`, `TestStaff*`, `signInStaff`, `staffCall`, `staffSession` | `console_*_test.go`, `TestConsole*`, `signInMember`, `consoleCall`, `consoleSession` |

Every other identifier that contains `staff` or `Staff` follows the same
rule: the tool becomes `console`, the person becomes `member`. Local
variables included (`staffKeys` → `consoleKeys`, `staffSvc` → `consoleSvc`).

Unchanged: the roles `moderator` and `admin`; the header
`X-Requested-With: shopnexus-console`; the console's Vietnamese labels
("Nhân viên", "Tạo nhân viên", ...).

## Scope per repository

**server**: the module, `cmd/console`, `internal/platform/{authn,audit,config}`,
`internal/app`, the OpenAPI spec, migrations 0003 and 0023, the e2e tests,
envgen, `.env.example`, `ARCHITECTURE.md`, `CLAUDE.md`, `README.md`. Comments
and prose say "console member(s)" or "moderators and admins" where they said
"staff".

**console**: the API paths in `src/` (`/staff/...` → `/console/...`), the
`Action` type (actor kind, `member_id`, target kind, `member.*` actions),
the action labels in `routes/Home.tsx`, TanStack Query keys
(`['staff', ...]` → `['console', ...]`), `README.md`, `DESIGN.md`,
`.superdesign/tools/` and `.superdesign/init/`.

**infra**: `stack/templates/_server-env.tpl`, `stack/templates/dashboards.yaml`
(forwardAuth address `/v1/console/dashboard-auth`, `authResponseHeaders`,
Grafana's `GF_AUTH_PROXY_HEADER_NAME` and `GF_AUTH_PROXY_HEADERS`), the helm
unit tests, `cmd/seal` (the key list and its test), `stack/secrets/example.env`.

**docs**: `docs/web` pages in both locales. `architecture/staff.mdx` becomes
`architecture/console.mdx` in `en` and `vi`, with an Astro `redirects` entry
from each old path, and every link and mention is updated.

**root**: `docker-compose.yml` (`CONSOLE_ORIGIN` for both local stacks, the
envgen comment) and `README.md`.

Out of scope: the dated specs and plans in `docs/superpowers/` (they record
what was decided at the time, under the names of the time) and
`docs/manual/` (report text).

## Deploying

The change ships as one release across the submodules.

1. Drop the database of every stack (dev, prod, local, test). The next
   migrate run builds the schema from 0001.
2. Run `seal` for each stack. envgen fills in the missing `CONSOLE_KEY`;
   delete the `STAFF_KEY` line from the stack's local `.env` file, since
   nothing reads it.
3. Create the admins again with `cmd/console create-admin`.

Every console session and dashboard cookie from before ends with the
rename; members sign in again.

## Checks

- `grep -rIi staff` over `server`, `console`, `infra`, `docs/web`, the root
  `docker-compose.yml` and `README.md` (excluding `node_modules`, `dist` and
  Superdesign's browser profiles) finds nothing.
- server: `make test` (unit, Postgres, e2e, golangci-lint) passes.
- console: `bun run lint` and `bun run build` pass.
- infra: `helm unittest stack` and `go test ./cmd/seal/...` pass.
- docs: the site builds, and the old `architecture/staff` paths redirect.
- By hand: `make run` with the console's dev server; sign in, enrol TOTP,
  search an account, open Grafana from the console.
