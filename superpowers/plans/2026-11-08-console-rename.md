# Module staff becomes module console: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the word "staff" in every identifier of the server, console, infra, docs site and root repo: the tool becomes `console`, the person becomes `member`, with no change in behaviour.

**Architecture:** One ordered rename script (`tmp/console-rename.py` in the root repo, git-ignored) applies exact regex rules to tracked files of each repository; `git mv` moves files and directories; a hand pass rewrites prose and comments that still say "staff". Each repository is committed on its own branch `console-rename`, and the root repo bumps the submodules last.

**Tech Stack:** Go (server, infra `cmd/seal`), Postgres migrations, OpenAPI YAML, React + TypeScript + Bun (console), Helm + helm-unittest (infra), Astro + Starlight-style MDX (docs/web), Docker Compose (root).

**Spec:** `docs/superpowers/specs/2026-11-08-console-rename-design.md`

## Global Constraints

- The tool is `console`, the person is `member`. Roles stay `moderator` and `admin`.
- `X-Requested-With: shopnexus-console` does not change. The console's Vietnamese UI labels do not change.
- Migrations `0003` and `0023` are edited in place and renamed `0003_console.sql`, `0023_console_dashboards.sql`. No new migration.
- Out of scope, never edited: `docs/superpowers/specs/*`, `docs/superpowers/plans/*` (dated records), `docs/manual/*`, `docs/typst/*`.
- Env names: `CONSOLE_KEY`, `CONSOLE_ORIGIN`. Header names: `X-Console-Email`, `X-Console-Role`. Cookies: `console_session` (path `/v1/console`), `console_dashboard`.
- Commit messages, README, ARCHITECTURE.md, docs pages and code comments are prose: draft them, then run `python3 ~/.claude/skills/humanizing-writing/ai-tells.py --stats <file>` and fix every hit (user's global instruction).
- No `Co-Authored-By` trailer on commits in the shopnexus repos (user memory).
- Server rules from `server/CLAUDE.md`: scratch files go in `server/tmp/`, never `/tmp`; configuration has no defaults; record the decision in `server/ARCHITECTURE.md`.
- Never commit changes in a repository that you did not make. Check `git status` before each commit and stage paths explicitly.

## Review Focus

- The server answers forwardAuth with `X-Console-Email`/`X-Console-Role` while Traefik's `authResponseHeaders` or Grafana's `GF_AUTH_PROXY_HEADER_NAME` still names `X-Staff-*`: Grafana would see no user. Task 4 Step 4 checks both sides name the same headers.
- The session cookie's path and the CORS prefix must follow the routes to `/v1/console`; otherwise the browser never sends the cookie and every console call is 401. Task 2's e2e (`console_login_test.go` asserts `Path == "/v1/console"`, `console_cors_test.go` preflights `/v1/console/login`) covers it; Task 2 Step 6 checks those assertions survived the script.
- A console call path left as `'/staff/...'` compiles and builds, then 404s at runtime. Task 3 Step 3 greps for it, and Task 6 signs in by hand.
- A database migrated before the rename fails the next migrate with `ErrChecksumMismatch`. Task 2 Step 1 drops the dev and test databases before the first test run, and Task 6 lists the drop for every stack.
- Links to the old docs pages (`/en/architecture/staff`, `/vi/architecture/staff`) would 404. Task 5 adds redirects and Step 5 checks the built files.

---

## Precondition: the server tree is clean

At planning time (2026-11-08) another session (`shopnexus-be`) had about 70 uncommitted changes in `server/` (module `auth` merging into `account`), several in files this plan renames (`internal/staff/service/*`, `internal/app/app.go`, `e2e/main_test.go`, `cmd/staff/main.go`, `.golangci.yml`, `ARCHITECTURE.md`).

- [ ] **Step 1:** Run `git -C server status --short`. If it lists anything, stop and ask the user whether that work is committed or should be waited for. Do not stash, commit or discard it.
- [ ] **Step 2:** Run the same check for `console`, `infra`, `docs` and the root repo (`git status --short`; the root repo shows submodule pointers as ` M server` etc., which is expected).

---

### Task 1: The rename script

**Files:**
- Create: `tmp/console-rename.py` (root repo; `/tmp` at the top is ignored by `.gitignore`'s whitelist)
- Create: `tmp/no-staff.sh`

**Interfaces:**
- Produces: `python3 -I tmp/console-rename.py <repo-dir> [<path> ...]` rewrites, in place, every git-tracked text file under the given paths of `<repo-dir>` (default: the whole repo) and prints each file it changed. `tmp/no-staff.sh <dir> ...` prints every remaining "staff" hit and exits 1 if there is one.

- [ ] **Step 1: Write the check script**

```bash
#!/usr/bin/env bash
# Usage: tmp/no-staff.sh <dir> [<dir> ...]
# Lists every case-insensitive "staff" in the given dirs, skipping what the
# spec leaves out. Exit 1 if anything is left.
set -u
hits=$(grep -rIin staff "$@" \
  --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.git \
  --exclude-dir=tmp --exclude-dir=.astro --exclude-dir=browser-review-profile \
  --exclude-dir=specs --exclude-dir=plans --exclude-dir=manual --exclude-dir=typst \
  | grep -v '/.superdesign/tmp/' | grep -v '/.superdesign/mockups/browser-review-profile/')
if [ -n "$hits" ]; then echo "$hits"; exit 1; fi
echo "no staff left"
```

Run: `chmod +x tmp/no-staff.sh && tmp/no-staff.sh server console infra docs/web; echo "exit=$?"`
Expected: hundreds of hits, `exit=1`.

- [ ] **Step 2: Write the rename script**

```python
#!/usr/bin/env python3
"""Ordered renames from module staff to module console.

Usage: python3 -I tmp/console-rename.py <repo-dir> [<path> ...]
Rewrites git-tracked text files under <repo-dir> (or only <path>s inside it).
Rules run top to bottom; longer names come before their prefixes.
"""
import pathlib
import re
import subprocess
import sys

# (regex, replacement) applied to every file.
RULES = [
    # paths, packages, routes
    (r"internal/staff\b", "internal/console"),
    (r"cmd/staff\b", "cmd/console"),
    (r"/v1/staff\b", "/v1/console"),
    (r"paths/staff\.yaml", "paths/console.yaml"),
    (r"schemas/staff\.yaml", "schemas/console.yaml"),
    (r"0003_staff\.sql", "0003_console.sql"),
    (r"0023_staff_dashboards\.sql", "0023_console_dashboards.sql"),
    (r"module staff:", "module console:"),
    # env and headers
    (r"STAFF_CONSOLE_ORIGIN", "CONSOLE_ORIGIN"),
    (r"STAFF_KEY", "CONSOLE_KEY"),
    (r"X-Staff-", "X-Console-"),
    # SQL names, cookies, error codes (longest first)
    (r"staff_session_id", "session_id"),
    (r"staff_dashboard_tickets", "console_dashboard_tickets"),
    (r"staff_dashboard_sessions", "console_dashboard_sessions"),
    (r"staff_dashboard", "console_dashboard"),
    (r"staff_members", "console_members"),
    (r"staff_sessions", "console_sessions"),
    (r"staff_login_locks", "console_login_locks"),
    (r"staff_actions", "console_actions"),
    (r"staff_role", "console_role"),
    (r"staff_session", "console_session"),
    (r"staff_id", "member_id"),
    (r"staff_forbidden", "console_forbidden"),
    (r"staff_email_taken", "member_email_taken"),
    (r"invalid_staff_member", "invalid_member"),
    (r"staff_member_not_found", "member_not_found"),
    # audit vocabulary: action kinds, actor and target kinds
    (r"\bstaff\.(create|disable|enable|reset_password|reset_totp|unlock)\b", r"member.\1"),
    (r"enum: \[staff, cli\]", "enum: [member, cli]"),
    (r"enum: \[account, staff\]", "enum: [account, member]"),
    (r"\['staff',", "['console',"),  # TanStack Query keys in the console
    (r"'/staff/", "'/console/"),  # console API paths
    (r"`/staff/", "`/console/"),
    (r"'staff'", "'member'"),  # SQL CHECKs, TS unions
    (r"\bActorStaff(\s+)ActorKind = \"staff\"", r'ActorMember\1ActorKind = "member"'),
    (r"\bTargetStaff(\s+)TargetKind = \"staff\"", r'TargetMember\1TargetKind = "member"'),
    (r"\bActorStaff\b", "ActorMember"),
    (r"\bTargetStaff\b", "TargetMember"),
    (r"\bByStaff\b", "ByMember"),
    (r"\bStaff(Create|Disable|Enable|ResetPassword|ResetTOTP|Unlock)\b", r"Member\1"),
    (r"\baudit\.Staff\(", "audit.Member("),
    (r"\bfunc Staff\(id uuid\.UUID\) Target", "func Member(id uuid.UUID) Target"),
    # authn and httpx
    (r"\bauthn\.Staff\b", "authn.ConsoleMember"),
    (r"\bWithStaff\b", "WithConsoleMember"),
    (r"\bStaffFrom\b", "ConsoleMemberFrom"),
    (r"\bStaffCaller\b", "ConsoleCaller"),
    (r"\bStaffSessionID\b", "SessionID"),
    (r"\bStaffID\b", "MemberID"),
    # config
    (r"\bStaffConfig\b", "ConsoleConfig"),
    (r"\bNewStaffKey\b", "NewConsoleKey"),
    (r"\bErrStaffForbidden\b", "ErrConsoleForbidden"),
    (r"\bStaff:(\s)", r"Console:\1"),
    (r"\.Staff\b", ".Console"),
    # OpenAPI component names
    (r"\bStaffAccount", "ConsoleAccount"),
    (r"\bStaffCSRF\b", "ConsoleCSRF"),
    (r"\bStaffMemberID\b", "ConsoleMemberID"),
    (r"\bStaffForbidden\b", "ConsoleForbidden"),
    (r"\bstaffAuth\b", "consoleAuth"),
    # import aliases and the package
    (r"\bstaffdomain\b", "consoledomain"),
    (r"\bstaffsvc\b", "consolesvc"),
    (r"(?m)^package staff$", "package console"),
    (r"\bstaff\.(Mount|NewService)\b", r"console.\1"),
    # key derivation labels and the TOTP issuer (new keys: every DB is reset)
    (r"shopnexus staff", "shopnexus console"),
    (r"shopnexus-staff", "shopnexus-console"),
    # e2e helpers and locals
    (r"\bsignInStaff\b", "signInMember"),
    (r"\bstaffCall\b", "consoleCall"),
    (r"\bstaffSession\b", "consoleSession"),
    (r"\bstaffLogin\b", "consoleLogin"),
    (r"\bstaffPassword\b", "memberPassword"),
    (r"\bnewStaffEmail\b", "newMemberEmail"),
    (r"\bnewStaff\b", "newMember"),
    (r"\bstaffSvc\b", "consoleSvc"),
    (r"\bstaffKeys\b", "consoleKeys"),
    (r"\btestStaffKey\b", "testConsoleKey"),
    (r"\bstaffKey\b", "consoleMemberKey"),
    (r"\bTestStaff", "TestConsole"),
    (r"\bunlockStaffMember\b", "unlockMember"),
    (r"\bunsuspendStaffAccount\b", "unsuspendAccount"),
    (r"\bstaffAccountList\b", "consoleAccountList"),
    (r"\bstaffAccount\b", "consoleAccount"),
]

# (path regex, [(regex, replacement)]) applied after RULES to matching files.
PER_FILE = [
    # the signed-in caller type
    (r"internal/platform/authn/authn\.go$", [(r"\bStaff\b", "ConsoleMember")]),
    # the service type, its receivers and constructors
    (r"internal/(staff|console)/service/[^/]+\.go$", [(r"\bStaff\b", "Console")]),
]

TEXT = {".go", ".sql", ".yaml", ".yml", ".md", ".mdx", ".ts", ".tsx", ".py",
        ".tpl", ".env", ".example", ".json", ".toml", ""}
SKIP = re.compile(r"(^|/)(docs/)?superpowers/|(^|/)manual/|(^|/)typst/|/\.superdesign/tmp/|browser-review-profile")


def tracked(repo, paths):
    out = subprocess.run(["git", "-C", repo, "ls-files", "-z", "--", *paths],
                         check=True, capture_output=True).stdout
    return [p for p in out.decode().split("\0") if p]


def main():
    repo = sys.argv[1]
    paths = sys.argv[2:]
    rules = [(re.compile(a), b) for a, b in RULES]
    per_file = [(re.compile(p), [(re.compile(a), b) for a, b in rs]) for p, rs in PER_FILE]
    for rel in tracked(repo, paths):
        f = pathlib.Path(repo, rel)
        if SKIP.search(rel) or not f.is_file():
            continue
        name = f.name
        if f.suffix not in TEXT and name not in {"Makefile", "Dockerfile", ".env.example", "example.env"}:
            continue
        try:
            text = f.read_text()
        except UnicodeDecodeError:
            continue
        new = text
        for rx, rep in rules:
            new = rx.sub(rep, new)
        for prx, rs in per_file:
            if prx.search(rel):
                for rx, rep in rs:
                    new = rx.sub(rep, new)
        if new != text:
            f.write_text(new)
            print(rel)


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Dry-check the script on a scratch copy**

Run:
```bash
rm -rf tmp/rename-check && mkdir -p tmp/rename-check && git -C server archive HEAD internal/platform/audit/audit.go internal/platform/authn/authn.go | tar -x -C tmp/rename-check && git -C tmp/rename-check init -q && git -C tmp/rename-check add -A && python3 -I tmp/console-rename.py tmp/rename-check && grep -n "ActorMember\|TargetMember\|func Member\|MemberCreate\|type ConsoleMember\|WithConsoleMember\|ConsoleMemberFrom" tmp/rename-check/internal/platform/*/*.go
```
Expected: `ActorMember ActorKind = "member"`, `TargetMember TargetKind = "member"`, `MemberCreate ActionKind = "member.create"`, `func Member(id uuid.UUID) Target`, `type ConsoleMember struct`, `func WithConsoleMember(`, `func ConsoleMemberFrom(` all present.

- [ ] **Step 4:** Nothing to commit (both files live in the git-ignored root `tmp/`).

---

### Task 2: Server rename

**Files:**
- Move: `server/internal/staff/` → `server/internal/console/`, and `internal/console/staff.go` → `internal/console/console.go`
- Move: `server/cmd/staff/` → `server/cmd/console/`
- Move: `server/migrations/0003_staff.sql` → `0003_console.sql`, `0023_staff_dashboards.sql` → `0023_console_dashboards.sql`
- Move: `server/api/paths/staff.yaml` → `api/paths/console.yaml`, `api/schemas/staff.yaml` → `api/schemas/console.yaml`
- Move: `server/e2e/staff_{accounts,actions,cors,dashboard,helpers,login,members,session}_test.go` → `console_*_test.go`
- Modify (script): every tracked file the script lists, including `internal/platform/{authn,audit,config,httpx}`, `internal/app/app.go`, `internal/account/...`, `cmd/envgen/`, `.golangci.yml`, `api/openapi.yaml`, `api/parameters/common.yaml`, `api/responses/common.yaml`, `.env.example`, `Makefile`
- Modify (by hand): `internal/platform/config/config.go` (`ConsoleConfig.ConsoleOrigin` → `Origin`), every comment still saying "staff"

**Interfaces:**
- Consumes: `tmp/console-rename.py`, `tmp/no-staff.sh` (Task 1)
- Produces, for Tasks 3 and 4: routes `/v1/console/*`; cookies `console_session` (path `/v1/console`) and `console_dashboard`; headers `X-Console-Email`, `X-Console-Role`; env `CONSOLE_KEY`, `CONSOLE_ORIGIN`; `Action` JSON `actor.kind` in `member|cli`, `actor.member_id`, `action` in `account.suspend|account.unsuspend|member.create|member.disable|member.enable|member.reset_password|member.reset_totp|member.unlock`, `target.kind` in `account|member`; error codes `console_forbidden`, `member_email_taken`, `invalid_member`, `member_not_found`; Go `config.ConsoleConfig{Key, Origin, ...}`, `config.NewConsoleKey()`, `authn.ConsoleMember{MemberID, ...}`, `console.NewService`, `console.Mount`, `consolesvc.Console`.

- [ ] **Step 1: Branch, and drop the databases built from the old migrations**

```bash
cd server
git switch -c console-rename
docker compose down -v                              # dev stack: its database volume goes (user confirmed: no data to keep)
docker compose -f docker-compose.test.yml down -v   # test stack
```

- [ ] **Step 2: Failing check**

Run: `cd .. && tmp/no-staff.sh server; echo "exit=$?"`
Expected: hits, `exit=1`.

- [ ] **Step 3: Move files**

```bash
cd server
git mv internal/staff internal/console
git mv internal/console/staff.go internal/console/console.go
git mv cmd/staff cmd/console
git mv migrations/0003_staff.sql migrations/0003_console.sql
git mv migrations/0023_staff_dashboards.sql migrations/0023_console_dashboards.sql
git mv api/paths/staff.yaml api/paths/console.yaml
git mv api/schemas/staff.yaml api/schemas/console.yaml
for f in e2e/staff_*_test.go; do git mv "$f" "e2e/console_${f#e2e/staff_}"; done
```

- [ ] **Step 4: Run the script**

Run: `cd .. && python3 -I tmp/console-rename.py server`
Expected: a list of changed files, including `internal/platform/audit/audit.go`, `internal/platform/authn/authn.go`, `migrations/0003_console.sql`, `api/openapi.yaml`, `e2e/console_login_test.go`.

- [ ] **Step 5: Rename the config field `ConsoleOrigin` → `Origin`**

After the script, `cfg.Console.ConsoleOrigin` repeats itself. Rename only the field of `ConsoleConfig` (the service's `Deps.ConsoleOrigin` keeps its name: inside the service it is the console's origin):

```bash
cd server
line=$(grep -n 'ConsoleOrigin string' internal/platform/config/config.go | cut -d: -f1)
gopls rename -w "internal/platform/config/config.go:${line}:2" Origin
go build ./... && go vet ./...
```
Expected: builds. If `gopls` is missing, install it with `go install golang.org/x/tools/gopls@latest` (it lands in `~/go/bin`).

Then, in `internal/platform/config/config.go`, the struct reads:

```go
// ConsoleConfig holds module console's key, the console's origin and the
// ops dashboards' hosts.
type ConsoleConfig struct {
	Key    []byte // CONSOLE_KEY: base64, at least 32 bytes; the console's subkeys derive from it
	Origin string // CONSOLE_ORIGIN: the web console's origin, the only one CORS allows
	// ... the remaining fields unchanged
}
```

and `internal/app/app.go` reads `cfg.Console.Origin` and `httpx.CORS(cfg.Console.Origin, "/v1/console/")`.

- [ ] **Step 6: Check the contract assertions survived**

Run:
```bash
grep -n 'Path != "/v1/console"' e2e/console_login_test.go
grep -n '/v1/console/login' e2e/console_cors_test.go
grep -n 'X-Console-Email\|X-Console-Role\|console_dashboard' e2e/console_dashboard_test.go
grep -n '"member.create"\|ActorMember ActorKind = "member"\|TargetMember TargetKind = "member"' internal/platform/audit/audit.go
grep -n "actor_kind IN ('member', 'cli')\|target_kind IN ('account', 'member')\|member_id" migrations/0003_console.sql
```
Expected: every grep prints at least one line.

- [ ] **Step 7: Hand pass over the remaining hits**

Run: `cd .. && tmp/no-staff.sh server`

Every remaining hit is prose (comments, `ARCHITECTURE.md`, `README.md`, `CLAUDE.md`, YAML descriptions, error messages, test strings such as `"E2E Staff"` or `staff-%d@example.com`). Rewrite each with this vocabulary:
- the people: "console members", "members", or "moderators and admins";
- the tool and the module: "the console", "module console";
- error messages: `"a console member already has this email"`, `"no console member has this id"`, `"console calls need X-Requested-With: shopnexus-console"`, `"admins are managed with cmd/console"`;
- test data: `"E2E Member"`, `fmt.Sprintf("member-%d@example.com", ...)`, `"a long e2e member password"`.

In `ARCHITECTURE.md`, rename the section "Staff and authorization" to "Console and authorization" and add this decision under it:

```markdown
- Module `console` was module `staff` until 2026-11-08 (spec:
  `~/shopnexus/docs/superpowers/specs/2026-11-08-console-rename-design.md`).
  The tool is "console" and the person signed in to it is a "member", in
  routes, tables, cookies, configuration and audit kinds. Migrations 0003
  and 0023 were edited in place; every database was dropped once.
```

Run the humanizing checker on the changed prose:
```bash
cd server
git diff -U0 -- ARCHITECTURE.md README.md CLAUDE.md | grep '^+' | sed 's/^+//' > tmp/prose-diff.md
python3 ~/.claude/skills/humanizing-writing/ai-tells.py --stats tmp/prose-diff.md
```
Fix every hit by rewriting the sentence.

Run again: `cd .. && tmp/no-staff.sh server; echo "exit=$?"`
Expected: `no staff left`, `exit=0`.

- [ ] **Step 8: Format, build, full test**

The script shifts the column alignment in `0003_console.sql` and `0023_console_dashboards.sql` (`member_id    uuid` where `staff_id` was aligned). Realign each `CREATE TABLE` block's type column by hand, then:

```bash
cd server
sqlfluff lint migrations/          # expect "All Finished!" with no violations; RF04 is why the column is console_role, not role
golangci-lint fmt
make env          # adds CONSOLE_KEY and CONSOLE_ORIGIN to .env from .env.example
grep -c '^CONSOLE_KEY=\|^CONSOLE_ORIGIN=' .env   # expect 2
sed -i '/^STAFF_KEY=/d;/^STAFF_CONSOLE_ORIGIN=/d' .env   # .env is git-ignored; nothing reads these now
make test
```
Expected: `make test` passes (unit, Postgres, e2e, golangci-lint). A failure about a missing variable names it; a `ErrChecksumMismatch` means Step 1's `down -v` was skipped.

- [ ] **Step 9: Commit**

Write the message to `tmp/commit-msg.txt`, run the humanizing checker on it, then:

```bash
git add -A internal cmd migrations api e2e .golangci.yml .env.example Makefile ARCHITECTURE.md CLAUDE.md README.md
git status --short   # only files this task touched
git commit -F tmp/commit-msg.txt
```

Suggested message:
```
refactor!: module staff becomes module console

The console's routes move to /v1/console, its tables to console_*, its
cookies to console_session and console_dashboard, and its env to
CONSOLE_KEY and CONSOLE_ORIGIN. The person signed in is a member: audit
kinds are member.*, actor.member_id, target member. Migrations 0003 and
0023 are edited in place, so every database is dropped once.
```

---

### Task 3: Console rename

**Files:**
- Modify (script): `console/src/lib/api.ts`, `src/lib/session.ts`, `src/lib/members.ts`, `src/lib/navigation.tsx`, `src/components/RequireSession.tsx`, `src/components/Shell.tsx`, `src/routes/{SignIn,DashboardOpen,Home}.tsx`, `.superdesign/tools/build_home.py`, `.superdesign/init/components.md`
- Modify (by hand): `console/README.md`, `console/DESIGN.md`, `.superdesign/design-system.md`, remaining comments

**Interfaces:**
- Consumes: Task 2's routes, cookie name and `Action` JSON.

- [ ] **Step 1: Branch and failing check**

```bash
cd console && git switch -c console-rename && cd ..
tmp/no-staff.sh console; echo "exit=$?"
```
Expected: hits, `exit=1`.

- [ ] **Step 2: Run the script**

Run: `python3 -I tmp/console-rename.py console`

Then `console/src/lib/api.ts` must read:

```ts
export type ActionKind =
  | 'account.suspend'
  | 'account.unsuspend'
  | 'member.create'
  | 'member.disable'
  | 'member.enable'
  | 'member.reset_password'
  | 'member.reset_totp'
  | 'member.unlock'

export interface Action {
  id: string
  at: string
  actor: { kind: 'member' | 'cli'; member_id?: string; display_name?: string }
  action: ActionKind
  target: { kind: 'account' | 'member'; id: string }
  details?: Record<string, unknown>
}
```

and `src/lib/session.ts` `export const meKey = ['console', 'me'] as const`.

- [ ] **Step 3: Check no call still goes to the old paths**

Run: `grep -rn "/staff\|'staff'" console/src console/.superdesign/tools; echo "exit=$?"`
Expected: no output, `exit=1`.

- [ ] **Step 4: Hand pass**

Run `tmp/no-staff.sh console` and rewrite each prose hit. `README.md`'s first paragraph becomes:

```markdown
The web console for ShopNexus moderators and admins. They use it to manage accounts, console members and the audit log through `/v1/console/*` on the Go server. It is a React single-page app built with Vite and served as static files by nginx.
```

and "Sign-in sets the `staff_session` cookie" is already `console_session` from the script. `DESIGN.md` and `.superdesign/design-system.md` say "The console at `console.<domain>`" and "console members" for the people. Run the humanizing checker over the changed prose: `git -C console diff -U0 -- '*.md' | grep '^+' | sed 's/^+//' > tmp/prose-diff.md && python3 ~/.claude/skills/humanizing-writing/ai-tells.py --stats tmp/prose-diff.md` (from `~/shopnexus`; the root `tmp/` is git-ignored). Commit message files for console, infra, docs and the root repo also go in the root `tmp/`.

Run: `cd .. && tmp/no-staff.sh console; echo "exit=$?"`
Expected: `no staff left`, `exit=0`.

- [ ] **Step 5: Lint and build**

```bash
cd console
bun run lint
bun run build
```
Expected: both pass.

- [ ] **Step 6: Commit**

```bash
git add -A src .superdesign/tools .superdesign/init .superdesign/design-system.md README.md DESIGN.md
git status --short
git commit -F <message file checked with the humanizing script>
```

Suggested message:
```
refactor: the console calls /v1/console

Paths, the Action type (member.* kinds, actor.member_id, target member)
and query keys follow the server's rename of module staff to console.
```

---

### Task 4: Infra rename

**Files:**
- Modify (script): `infra/stack/templates/_server-env.tpl`, `stack/templates/dashboards.yaml`, `stack/tests/server_env_test.yaml`, `stack/tests/dashboards_test.yaml`, `cmd/seal/main.go`, `cmd/seal/main_test.go`, `stack/secrets/example.env`
- Modify (by hand): comments in `dashboards.yaml` and `dashboards_test.yaml` that say "staff member"

**Interfaces:**
- Consumes: Task 2's `/v1/console/dashboard-auth`, `X-Console-Email`, `X-Console-Role`, `CONSOLE_KEY`, `CONSOLE_ORIGIN`.

- [ ] **Step 1: Branch and failing check**

```bash
cd infra && git switch -c console-rename && cd ..
tmp/no-staff.sh infra; echo "exit=$?"
```
Expected: hits, `exit=1`.

- [ ] **Step 2: Run the script and the hand pass**

Run: `python3 -I tmp/console-rename.py infra`, then `tmp/no-staff.sh infra` and rewrite the comment hits ("the console member from the headers", "a client cannot claim to be a console member").

- [ ] **Step 3: Tests**

```bash
cd infra
helm unittest stack
go test ./cmd/seal/...
```
Expected: both pass.

- [ ] **Step 4: Cross-check headers and route against the server**

```bash
cd ..
grep -n 'dashboard-auth\|X-Console' infra/stack/templates/dashboards.yaml
grep -rn '"X-Console-Email"\|"X-Console-Role"\|"GET /v1/console/dashboard-auth"' server/internal/console/handler/
```
Expected: the template's forwardAuth address ends in `/v1/console/dashboard-auth`, `authResponseHeaders: [X-Console-Email, X-Console-Role]`, `GF_AUTH_PROXY_HEADER_NAME` is `X-Console-Email` and `GF_AUTH_PROXY_HEADERS` is `Role:X-Console-Role`; the server's handler sets the same two header names and registers the same route.

- [ ] **Step 5: Commit**

```bash
cd infra
git add stack cmd
git status --short
git commit -F <message file checked with the humanizing script>
```

Suggested message:
```
refactor: CONSOLE_KEY, CONSOLE_ORIGIN and X-Console-* for the console

forwardAuth calls /v1/console/dashboard-auth, and Grafana reads the
member from X-Console-Email and X-Console-Role. A stack's sealed secrets
need a new seal run to carry CONSOLE_KEY.
```

---

### Task 5: Docs site rename

**Files:**
- Move: `docs/web/src/content/docs/en/architecture/staff.mdx` → `console.mdx`, same for `vi`
- Modify: `docs/web/astro.config.ts` (redirects)
- Modify (script, then by hand): the 26 pages `tmp/no-staff.sh docs/web` lists

**Interfaces:**
- Consumes: every name from Task 2.

- [ ] **Step 1: Branch and failing check**

```bash
cd docs && git switch -c console-rename && cd ..
tmp/no-staff.sh docs/web; echo "exit=$?"
```
Expected: hits, `exit=1`.

- [ ] **Step 2: Move the pages and run the script**

```bash
cd docs/web/src/content/docs
git mv en/architecture/staff.mdx en/architecture/console.mdx
git mv vi/architecture/staff.mdx vi/architecture/console.mdx
cd ~/shopnexus
python3 -I tmp/console-rename.py docs web
```

Then fix links: `grep -rn 'architecture/staff' docs/web/src` must print nothing; replace each with `architecture/console`.

- [ ] **Step 3: Redirects from the old pages**

In `docs/web/astro.config.ts`, inside `defineConfig({ ... })`, after `trailingSlash: "ignore",`:

```ts
  // The page was architecture/staff until module staff became module console (2026-11-08).
  redirects: {
    "/en/architecture/staff": "/en/architecture/console",
    "/vi/architecture/staff": "/vi/architecture/console",
  },
```

- [ ] **Step 4: Hand pass**

Run `tmp/no-staff.sh docs/web` and rewrite every remaining hit. The `en/architecture/console.mdx` front matter becomes:

```yaml
title: Console
description: Console members of the moderation console, their sign-in, roles, audit trail and the rules that keep them apart from customers.
updated: 2026-11-08
```

(keep the other keys). In `vi`, use "Console" as the title and "thành viên console" or "kiểm duyệt viên và quản trị viên" for the people; keep every Vietnamese diacritic. Run the humanizing checker on each changed page (`python3 ~/.claude/skills/humanizing-writing/ai-tells.py --stats <page>`) and fix every hit in the changed lines.

Run: `tmp/no-staff.sh docs/web; echo "exit=$?"`
Expected: `no staff left`, `exit=0`.

- [ ] **Step 5: Build and check the redirects**

```bash
cd docs/web
bun run lint
bun run build
grep -l 'architecture/console' dist/en/architecture/staff/index.html dist/vi/architecture/staff/index.html
```
Expected: lint and build pass; both redirect files exist and point at `architecture/console`.

- [ ] **Step 6: Commit**

```bash
cd ..
git add web
git status --short
git commit -F <message file checked with the humanizing script>
```

Suggested message:
```
docs: the staff page becomes the console page

Routes, tables, cookies and env names follow the server's rename of
module staff to console. The old architecture/staff paths redirect.
```

---

### Task 6: Root repo, local stacks, final check

**Files:**
- Modify: `docker-compose.yml` (envgen comment, `CONSOLE_ORIGIN` for both local stacks), `README.md` (lines 10 and 109)
- Modify: submodule pointers `server`, `console`, `infra`, `docs`

- [ ] **Step 1: Branch, script, hand pass**

```bash
git switch -c console-rename
python3 -I tmp/console-rename.py . docker-compose.yml README.md
```
In `README.md`, line 10 becomes `| \`console\` | \`shopnexus/console\` | Moderation console (React) |` and line 109 says "`console.` (the moderation console)". Run the humanizing checker on the changed lines.

- [ ] **Step 2: Final check over everything in scope**

Run: `tmp/no-staff.sh server console infra docs/web docker-compose.yml README.md; echo "exit=$?"`
Expected: `no staff left`, `exit=0`.

- [ ] **Step 3: Local stacks from scratch**

The local stacks' databases were built from the old migrations. Look at what `docker compose --profile dev --profile prod --profile test ps -a` and `docker volume ls | grep -i shopnexus` show, then run `docker compose --profile dev --profile prod --profile test down -v` from `~/shopnexus` (it deletes the local stacks' volumes; the user confirmed no database holds data worth keeping). Start `make prod` (images) or `make dev` (live reload) again and confirm the server's migrate step logs no `checksum mismatch`.

- [ ] **Step 4: By hand, end to end**

```bash
cd server
docker compose up -d --wait && go run ./cmd/migrate
go run ./cmd/console create-admin --email admin@example.com --name "Admin"
go run ./cmd/server   # in one terminal
cd ../console && bun run dev   # in another
```
In a browser at `http://localhost:5173`: sign in with the temporary password, set a new one, enrol TOTP, see Home with the account search and the latest actions (the admin's `member.create` from the CLI shows as "Tạo nhân viên"), search an account, then open Grafana from the console if the local stack serves it. Watch the browser's network tab: every call goes to `/v1/console/...`, and the cookie is `console_session`.

- [ ] **Step 5: Commit the root repo**

```bash
cd ~/shopnexus
git add docker-compose.yml README.md server console infra docs
git status --short
git commit -F <message file checked with the humanizing script>
```

Suggested message:
```
chore: submodules at the console rename

Local stacks pass CONSOLE_ORIGIN, and the README calls the console the
moderation console.
```

- [ ] **Step 6: Hand the deploy steps to the user**

Do not run these; they drop the dev and prod databases. Give the user this list:

1. Merge `console-rename` in `server`, `console`, `infra`, `docs` and the root repo, and tag as usual.
2. For each stack (`dev`, `prod`): drop the server's Postgres database, run `seal` for the stack (envgen adds `CONSOLE_KEY`), delete the `STAFF_KEY` line from the stack's local `.env`, commit the new sealed secret.
3. After Argo CD syncs, create the admins again: `cmd/console create-admin --email <email> --name <name>` against each stack.
