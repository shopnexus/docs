# Profile tasks view Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve the app's Hoàn thiện hồ sơ screen from the server as `GET /v1/screens/profile-tasks`: four steps with `done`, the caller's account and their default address.

**Architecture:** One more view in module `screen` (no table). `screen/service.ProfileTasks` reads `accounts.Me` and `accounts.Addresses` and builds the four steps in one top-to-bottom function; `screen/handler` serves it under `protect`. The OpenAPI spec comes first; e2e tests validate every response against it.

**Tech Stack:** Go (module `github.com/shopnexus/server`), OpenAPI 3.2 in `api/` loaded by kin-openapi, e2e tests in `e2e/` against the test stack (`docker-compose.test.yml`).

**Spec:** `~/shopnexus/docs/superpowers/specs/2026-11-13-profile-tasks-design.md`

## Global Constraints

- Steps, in this order: `address`, `bio`, `phone`, `avatar`. No `identity` (eKYC is dropped), no `cod` (COD setup is not a profile step).
- The view has no `done`, `total`, `next` and no display text per step.
- `address` done: the address book holds at least one address. `bio` done: the bio is not empty. `phone` done: an identity of kind `phone`. `avatar` done: the account has an avatar.
- `address` in the response is the default address, `null` when the book is empty.
- Responses declared: 200 and 401 only. The e2e run fails when a declared status is never observed, so both get a test.
- A use case and an HTTP handler read top to bottom; no helper called from one place (`server/CLAUDE.md`).
- Work in `server/` on branch `feat/profile-tasks` in the worktree `server/.worktrees/profile-tasks` (`.worktrees` is git-ignored). `main` is the default branch; do not commit there.
- Commits carry no `Co-Authored-By` trailer. The commit messages and the ARCHITECTURE.md text below already passed the `humanizing-writing` checker; use them as written.
- Scratch files and test output go in `server/tmp/`, never `/tmp`.
- The test stack is shared with other sessions. Before a run, recreate it whole: `docker compose -f docker-compose.test.yml up -d --wait --force-recreate`, then wait until `curl -sf http://127.0.0.1:56571/health` answers. A "connection refused" on 56491/56571 or a Restate load-shedding timeout is the stack, not the code; recreate and rerun the failed package before calling it real.

## Review Focus

- A person who set a second address as default: `address` must be that default, not the first one added. (Test: `TestProfileTasksDefaultAddress`.)
- A person who deletes their last address: `address` goes back to `null` and the step to not done. (Test: `TestProfileTasksDefaultAddress`.)
- A person who removes their avatar (`avatar_upload_id: null`): the step goes back to not done. (Test: `TestProfileTasksAllDone`.)
- A suspended account keeps read access until its token expires, so the view answers 200. (Test: `TestProfileTasksSuspended`.)
- A deleted account's still-valid access token: 401 `session_revoked`, never a 500 from `Me`. (Test: `TestProfileTasksRefusals`.)

---

## File Structure

- Create `server/api/paths/screen_account.yaml`: the `screenProfileTasks` path item.
- Create `server/api/schemas/screen_account.yaml`: `ProfileTasksScreen`, `ProfileTask`.
- Modify `server/api/openapi.yaml`: route the path to the new file, after `/v1/screens/seller/{id}`.
- Create `server/internal/screen/service/profile_tasks.go`: the view's types and `ProfileTasks`.
- Modify `server/internal/screen/service/service.go`: `ProfileTasks` on `Service`.
- Create `server/internal/screen/handler/profile_tasks.go`: the HTTP handler.
- Modify `server/internal/screen/handler/handler.go`: register the route.
- Create `server/e2e/screen_profile_tasks_test.go`: the e2e tests.
- Modify `server/ARCHITECTURE.md` (section Screen) and `~/shopnexus/checklist.md` (git-ignored, not committed).

---

### Task 1: The view, spec to handler

**Files:**
- Create: `server/api/paths/screen_account.yaml`
- Create: `server/api/schemas/screen_account.yaml`
- Modify: `server/api/openapi.yaml:158-159`
- Create: `server/internal/screen/service/profile_tasks.go`
- Modify: `server/internal/screen/service/service.go:20-36`
- Create: `server/internal/screen/handler/profile_tasks.go`
- Modify: `server/internal/screen/handler/handler.go:21-28`
- Test: `server/e2e/screen_profile_tasks_test.go`

**Interfaces:**
- Consumes (exist already): `accountsvc.Service.Me(ctx, id uuid.UUID) (accountsvc.MeView, error)`; `accountsvc.Service.Addresses(ctx, owner uuid.UUID) ([]accountsvc.AddressView, error)`, ordered default first (`ORDER BY a.is_default DESC, a.id DESC`); `accountdomain.KindPhone`; `httpx.Caller`, `httpx.WriteError`, `httpx.Respond`. e2e helpers: `newAccount`, `newEmailAccount`, `newAddress`, `setAvatar`, `suspend`, `call`, `expect`, `expectStatus`, `check`, `bearer`, `newKey`, `newPhone`, `issuer.SMSToken`, type `addressView`.
- Produces: `service.Service.ProfileTasks(ctx context.Context, account uuid.UUID) (service.ProfileTasksScreen, error)`; route `GET /v1/screens/profile-tasks`; operation `getProfileTasksScreen`.

- [ ] **Step 0: Make the worktree**

```bash
cd ~/shopnexus/server
git worktree add .worktrees/profile-tasks -b feat/profile-tasks main
cd .worktrees/profile-tasks
cp ../../.env .env 2>/dev/null || make env
```

All later paths are relative to `~/shopnexus/server/.worktrees/profile-tasks`.

- [ ] **Step 1: Write the OpenAPI schemas**

Create `api/schemas/screen_account.yaml`:

```yaml
ProfileTasksScreen:
  type: object
  additionalProperties: false
  required: [tasks, account, address]
  description: Hoàn thiện hồ sơ. The app counts the steps done and takes the first step not done as the next.
  properties:
    tasks:
      type: array
      minItems: 4
      maxItems: 4
      description: Every step, in the order the screen shows them.
      items:
        $ref: "#/ProfileTask"
    account:
      $ref: "account.yaml#/MyAccount"
    address:
      description: The default address of the caller's address book; null when the book is empty.
      anyOf:
        - $ref: "address.yaml#/Address"
        - type: "null"
ProfileTask:
  type: object
  additionalProperties: false
  required: [key, done]
  properties:
    key:
      type: string
      enum: [address, bio, phone, avatar]
      description: |
        address is done when the address book holds an address, bio when the
        bio is not empty, phone when the account has a phone identity,
        avatar when it has an avatar.
    done:
      type: boolean
```

- [ ] **Step 2: Write the OpenAPI path and route it**

Create `api/paths/screen_account.yaml`:

```yaml
screenProfileTasks:
  get:
    operationId: getProfileTasksScreen
    summary: The Hoàn thiện hồ sơ view, the caller's profile steps with the account and the default address.
    description: |
      Writes go through PATCH /v1/accounts/me, /v1/addresses and
      /v1/accounts/me/identities; the app reads this view again after one.
    tags: [screen]
    security:
      - bearerAuth: []
    responses:
      "200":
        description: The view.
        content:
          application/json:
            schema:
              $ref: "../schemas/screen_account.yaml#/ProfileTasksScreen"
      "401":
        $ref: "../responses/common.yaml#/Unauthorized"
```

In `api/openapi.yaml`, after the two lines

```yaml
  /v1/screens/seller/{id}:
    $ref: "paths/screen_listing.yaml#/screenSeller"
```

add

```yaml
  /v1/screens/profile-tasks:
    $ref: "paths/screen_account.yaml#/screenProfileTasks"
```

- [ ] **Step 3: Write the failing e2e tests**

Create `e2e/screen_profile_tasks_test.go`:

```go
package e2e

import (
	"fmt"
	"net/http"
	"strings"
	"testing"
)

type profileTasksScreen struct {
	Tasks []struct {
		Key  string `json:"key"`
		Done bool   `json:"done"`
	} `json:"tasks"`
	Account struct {
		ID  string `json:"id"`
		Bio string `json:"bio"`
	} `json:"account"`
	Address *addressView `json:"address"`
}

// profileTasks reads the view as the account with token.
func profileTasks(t *testing.T, token string) profileTasksScreen {
	t.Helper()
	return expect[profileTasksScreen](t, call(t, "GET", "/v1/screens/profile-tasks", nil, bearer(token)), http.StatusOK)
}

// steps writes the view's steps in order as "key=done", for one comparison.
func (s profileTasksScreen) steps() string {
	out := make([]string, 0, len(s.Tasks))
	for _, task := range s.Tasks {
		out = append(out, fmt.Sprintf("%s=%t", task.Key, task.Done))
	}
	return strings.Join(out, " ")
}

func TestProfileTasksNewPhoneAccount(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	v := profileTasks(t, me.AccessToken)
	if got, want := v.steps(), "address=false bio=false phone=true avatar=false"; got != want {
		t.Fatalf("steps %q, want %q", got, want)
	}
	if v.Address != nil || v.Account.ID != me.Account.ID {
		t.Fatalf("%+v", v)
	}
}

func TestProfileTasksAllDone(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	expectStatus(t, call(t, "PATCH", "/v1/accounts/me", map[string]any{"bio": "Đồ cũ còn tốt"}, bearer(me.AccessToken)), http.StatusOK)
	setAvatar(t, me.AccessToken)
	added := newAddress(t, me.AccessToken)
	v := profileTasks(t, me.AccessToken)
	if got, want := v.steps(), "address=true bio=true phone=true avatar=true"; got != want {
		t.Fatalf("steps %q, want %q", got, want)
	}
	if v.Address == nil || v.Address.ID != added.ID || v.Account.Bio != "Đồ cũ còn tốt" {
		t.Fatalf("%+v", v)
	}

	expectStatus(t, call(t, "PATCH", "/v1/accounts/me", map[string]any{"avatar_upload_id": nil}, bearer(me.AccessToken)), http.StatusOK)
	if got, want := profileTasks(t, me.AccessToken).steps(), "address=true bio=true phone=true avatar=false"; got != want {
		t.Fatalf("after removing the avatar: steps %q, want %q", got, want)
	}
}

func TestProfileTasksEmailAccount(t *testing.T) {
	t.Parallel()
	me, _ := newEmailAccount(t)
	if got, want := profileTasks(t, me.AccessToken).steps(), "address=false bio=false phone=false avatar=false"; got != want {
		t.Fatalf("steps %q, want %q", got, want)
	}
	expectStatus(t, call(t, "POST", "/v1/accounts/me/identities",
		map[string]string{"phone_token": issuer.SMSToken(newPhone())}, newKey(), bearer(me.AccessToken)), http.StatusOK)
	if got, want := profileTasks(t, me.AccessToken).steps(), "address=false bio=false phone=true avatar=false"; got != want {
		t.Fatalf("after adding a phone: steps %q, want %q", got, want)
	}
}

func TestProfileTasksBlankBio(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	expectStatus(t, call(t, "PATCH", "/v1/accounts/me", map[string]any{"bio": "   "}, bearer(me.AccessToken)), http.StatusOK)
	if got, want := profileTasks(t, me.AccessToken).steps(), "address=false bio=false phone=true avatar=false"; got != want {
		t.Fatalf("steps %q, want %q", got, want)
	}
}

func TestProfileTasksDefaultAddress(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	first := newAddress(t, me.AccessToken)
	second := newAddress(t, me.AccessToken)
	expectStatus(t, call(t, "POST", "/v1/addresses/"+second.ID+"/default", nil, bearer(me.AccessToken)), http.StatusNoContent)
	if v := profileTasks(t, me.AccessToken); v.Address == nil || v.Address.ID != second.ID || !v.Address.IsDefault {
		t.Fatalf("address %+v, want the default %s", v.Address, second.ID)
	}

	expectStatus(t, call(t, "DELETE", "/v1/addresses/"+first.ID, nil, bearer(me.AccessToken)), http.StatusNoContent)
	expectStatus(t, call(t, "DELETE", "/v1/addresses/"+second.ID, nil, bearer(me.AccessToken)), http.StatusNoContent)
	v := profileTasks(t, me.AccessToken)
	if v.Address != nil || v.Tasks[0].Key != "address" || v.Tasks[0].Done {
		t.Fatalf("after emptying the book: %+v", v)
	}
}

// A suspended person keeps read access until the access token expires.
func TestProfileTasksSuspended(t *testing.T) {
	t.Parallel()
	me, _ := newAccount(t)
	suspend(t, me.Account.ID)
	profileTasks(t, me.AccessToken)
}

func TestProfileTasksRefusals(t *testing.T) {
	t.Parallel()
	check(t, "signed out", call(t, "GET", "/v1/screens/profile-tasks", nil), http.StatusUnauthorized, "unauthenticated")

	gone, _ := newAccount(t)
	expectStatus(t, call(t, "DELETE", "/v1/accounts/me", nil, bearer(gone.AccessToken)), http.StatusNoContent)
	check(t, "deleted account", call(t, "GET", "/v1/screens/profile-tasks", nil, bearer(gone.AccessToken)), http.StatusUnauthorized, "session_revoked")
}
```

- [ ] **Step 4: Run the tests to see them fail**

Recreate the test stack (Global Constraints), then:

```bash
go test ./e2e -run 'TestProfileTasks' -count=1 -v 2>&1 | tee tmp/profile-tasks-red.txt | grep -E '^(=== RUN|--- |FAIL|ok)' 
```

Expected: every `TestProfileTasks*` fails with `GET /v1/screens/profile-tasks: 404, want 200` (or the unauthenticated check reporting a 404). The run also prints "declared responses no test observed" for other operations; a filtered run always does, ignore it here.

- [ ] **Step 5: Write the service**

Create `internal/screen/service/profile_tasks.go`:

```go
package service

import (
	"context"
	"fmt"
	"slices"
	"uuid"

	accountdomain "github.com/shopnexus/server/internal/account/domain"
	accountsvc "github.com/shopnexus/server/internal/account/service"
)

// ProfileTasksScreen is the ProfileTasksScreen schema in
// api/schemas/screen_account.yaml.
type ProfileTasksScreen struct {
	Tasks   []ProfileTask           `json:"tasks"`
	Account accountsvc.MeView       `json:"account"`
	Address *accountsvc.AddressView `json:"address"`
}

// ProfileTask is one step of the view and whether it is done.
type ProfileTask struct {
	Key  TaskKey `json:"key"`
	Done bool    `json:"done"`
}

// TaskKey names a step of Hoàn thiện hồ sơ.
type TaskKey string

const (
	TaskAddress TaskKey = "address"
	TaskBio     TaskKey = "bio"
	TaskPhone   TaskKey = "phone"
	TaskAvatar  TaskKey = "avatar"
)

// ProfileTasks reads the Hoàn thiện hồ sơ view: the four steps, the account
// and the default address, nil when the book is empty. A deleted account is
// accountdomain.ErrSessionRevoked, from Me.
func (s *Screen) ProfileTasks(ctx context.Context, account uuid.UUID) (ProfileTasksScreen, error) {
	me, err := s.accounts.Me(ctx, account)
	if err != nil {
		return ProfileTasksScreen{}, fmt.Errorf("read the account: %w", err)
	}
	book, err := s.accounts.Addresses(ctx, account)
	if err != nil {
		return ProfileTasksScreen{}, fmt.Errorf("read the address book: %w", err)
	}
	// Addresses lists the default first.
	var address *accountsvc.AddressView
	if len(book) > 0 {
		address = &book[0]
	}
	hasPhone := slices.ContainsFunc(me.Identities, func(i accountsvc.Identity) bool { return i.Kind == accountdomain.KindPhone })
	return ProfileTasksScreen{
		Tasks: []ProfileTask{
			{Key: TaskAddress, Done: address != nil},
			{Key: TaskBio, Done: me.Bio != ""},
			{Key: TaskPhone, Done: hasPhone},
			{Key: TaskAvatar, Done: me.AvatarURL != ""},
		},
		Account: me,
		Address: address,
	}, nil
}
```

In `internal/screen/service/service.go`, add to the `Service` interface after `Chat`:

```go
	// ProfileTasks reads account's Hoàn thiện hồ sơ view.
	ProfileTasks(ctx context.Context, account uuid.UUID) (ProfileTasksScreen, error)
```

- [ ] **Step 6: Write the handler and register it**

Create `internal/screen/handler/profile_tasks.go`:

```go
package handler

import (
	"net/http"

	"github.com/shopnexus/server/internal/platform/httpx"
)

// ProfileTasks serves GET /v1/screens/profile-tasks.
func (h *Handler) ProfileTasks(w http.ResponseWriter, r *http.Request) {
	p, ok := httpx.Caller(w, r, h.log)
	if !ok {
		return
	}
	out, err := h.svc.ProfileTasks(r.Context(), p.AccountID)
	if err != nil {
		httpx.WriteError(w, r, h.log, err)
		return
	}
	httpx.Respond(w, http.StatusOK, out)
}
```

In `internal/screen/handler/handler.go`, add after the `/v1/screens/chat/{conversation_id}` line:

```go
	r.Handle("GET /v1/screens/profile-tasks", protect(http.HandlerFunc(h.ProfileTasks)))
```

- [ ] **Step 7: Run the tests to see them pass**

```bash
go build ./... && go test ./internal/app -run TestRoutesMatchSpec -count=1
go test ./e2e -run 'TestProfileTasks' -count=1 -v 2>&1 | tee tmp/profile-tasks-green.txt | grep -E '^(--- |FAIL|ok)'
```

Expected: `TestRoutesMatchSpec` ok; every `--- PASS: TestProfileTasks…` line passes. The trailing "declared responses no test observed" list must not name `getProfileTasksScreen` (the rest of the list is the filter's doing).

If `TestProfileTasksRefusals` "deleted account" gets a code other than `session_revoked`, read what the protect middleware answers for a deleted account (`erasure_test.go` expects `session_revoked` after `DELETE /v1/accounts/me`) and match the test to the real 401 code; do not add a new status to the spec.

- [ ] **Step 8: Format and lint**

```bash
golangci-lint fmt ./internal/screen/... ./e2e/...
golangci-lint run ./internal/screen/... ./e2e/...
```

Expected: no findings.

- [ ] **Step 9: Commit**

```bash
git add api/paths/screen_account.yaml api/schemas/screen_account.yaml api/openapi.yaml \
  internal/screen/service/profile_tasks.go internal/screen/service/service.go \
  internal/screen/handler/profile_tasks.go internal/screen/handler/handler.go \
  e2e/screen_profile_tasks_test.go
git commit -m "feat(screen): the profile tasks view, GET /v1/screens/profile-tasks"
```

---

### Task 2: ARCHITECTURE.md, the checklist and the full run

**Files:**
- Modify: `server/ARCHITECTURE.md` (section Screen, after the `GET /v1/screens/chat/{conversation_id}` bullet)
- Modify: `~/shopnexus/checklist.md` (git-ignored)

**Interfaces:**
- Consumes: the route and schema names from Task 1.
- Produces: nothing code depends on.

- [ ] **Step 1: Record the decision in ARCHITECTURE.md**

In `ARCHITECTURE.md`, section `### Screen`, after the bullet that starts `` - `GET /v1/screens/chat/{conversation_id}` `` and ends `` `conversation_not_found`. ``, add:

```markdown
- `GET /v1/screens/profile-tasks` (decided 2026-11-13, spec
  `2026-11-13-profile-tasks-design.md`): the Hoàn thiện hồ sơ view.
  `tasks` holds four steps in a fixed order, `address`, `bio`, `phone` and
  `avatar`, each with `done`. `account` is the caller's `MyAccount` and
  `address` the default of their address book, null when the book is
  empty. A step is done when the book holds an address, the bio is not
  empty, the account has a phone identity, or it has an avatar. The app
  counts the steps and takes the first one not done as the next. eKYC and
  COD setup are not steps: COD needs only a phone, and someone who only
  buys never sets COD up.
```

- [ ] **Step 2: Update the checklist**

In `~/shopnexus/checklist.md`, section `### Tài khoản`, replace the line

```markdown
- [ ] Danh sách việc cần làm của hồ sơ
```

with

```markdown
- [x] Danh sách việc cần làm của hồ sơ (Hoàn thiện hồ sơ): `GET /v1/screens/profile-tasks` trả 4 việc `address`, `bio`, `phone`, `avatar` kèm `done`, tài khoản và địa chỉ mặc định; không còn eKYC và COD (app chưa nối)
- [ ] App: bỏ `TaskKey.IDENTITY` và `TaskKey.COD` khỏi Hoàn thiện hồ sơ, gỡ `IdentityCheck`, các màn eKYC và thông báo "Đã xác minh danh tính"
- [ ] App: sheet địa chỉ của Hoàn thiện hồ sơ lưu một dòng "đường, xã"; server dùng sổ địa chỉ (tên người nhận, số điện thoại, đường, xã), nên sheet chuyển sang `/v1/addresses`
```

In the same section, the eKYC line (`- [ ] Xác minh danh tính (eKYC): …`) becomes:

```markdown
- [x] Xác minh danh tính (eKYC): bỏ khỏi sản phẩm ngày 13/11/2026, COD chỉ cần số điện thoại đã xác minh. App còn code eKYC cần gỡ (dòng trên)
```

- [ ] **Step 3: Run the whole suite**

Recreate the test stack (Global Constraints), then:

```bash
go test -race -p 4 ./... > tmp/profile-tasks-full.txt 2>&1; echo "exit $?"
grep -E '^(FAIL|--- FAIL)|declared responses no test observed' -A3 tmp/profile-tasks-full.txt
golangci-lint run ./...
```

Expected: exit 0 (no `FAIL` lines; the e2e coverage check passes, so `getProfileTasksScreen 200` and `401` were both observed) and no lint findings. A failure in a package this plan did not touch: recreate the stack and rerun that package alone before treating it as real.

- [ ] **Step 4: Commit**

```bash
git add ARCHITECTURE.md
git commit -m "docs: the profile tasks view in ARCHITECTURE.md"
```

- [ ] **Step 5: Free the machine**

Stop leftover test processes: `ps aux | grep -E 'go test|e2e.test' | grep -v grep` must print nothing; kill any that remain. The test stack stays up (other sessions share it).
