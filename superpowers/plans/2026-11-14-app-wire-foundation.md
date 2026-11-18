# App wiring, Phase 1: network foundation and flavors — Implementation Plan

> Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`. Spike: `docs/superpowers/specs/2026-11-14-app-wire-codegen-spike.md`.
> Steps use checkbox (`- [ ]`) syntax.

**Goal:** the app gets a typed HTTP client generated from the server's OpenAPI and two flavors, `demo` (fakes, offline) and `live` (server). No repository calls the network yet; Phase 2 replaces the first fake binding.

**Architecture:** new JVM module `:core:network` holds the Fabrikt output (Ktor client + kotlinx models, generated at build time from the committed `core/network/openapi/codegen.yaml`), one `HttpClient` factory, `ApiFailure` (the server's error envelope) and `idempotent {}`. `:core:data` maps `ApiFailure` to `DataError`. The fake bindings become include-only Hilt modules in `:core:data`; `:app` installs them from `src/demo` and `src/live`, each with its own `Clock`.

**Tech stack:** Fabrikt 28.4.0 (CLI jar through a `JavaExec` task, no third-party Gradle plugin), Ktor 3.6.1 (`client-core`, `client-okhttp`, `client-content-negotiation`, `serialization-kotlinx-json`, `client-mock` for tests), kotlinx.serialization 1.11.0.

## Global Constraints

- Branch `feat/wire-foundation` in `~/shopnexus/app` (no worktree). Commits without a Co-Authored-By trailer; messages and comments through `humanizing-writing`.
- Generated code lives in `core/network/build/generated/fabrikt`, never in `src/`; Spotless, detekt and lint skip it.
- Generated types never leave `:core:network` and `:core:data/net` (roadmap rule 1).
- Gradle: `. ~/.local/share/shopnexus/android-env.sh &&`; test only touched modules; stop daemons when done.
- Version picks are at least two weeks old (supply-chain rule): Fabrikt 28.4.0 (2026-10-30), Ktor 3.6.1 (2026-10-29), Redocly CLI 2.72.1 (2026-10-29).

## Deviations from the roadmap

- Spec sync is `tools/sync-openapi.sh [--check]`, not a Gradle task: bundling needs Node and `../server`, which the app's CI does not have.
- Emulator reaches the dev server through `adb reverse` (8080, 56490), so the live debug base URL is `http://127.0.0.1:8080` and `server/.env` keeps its `127.0.0.1` URLs. `-Pshopnexus.apiUrl=` overrides it (e.g. the deployed dev stack).
- Live unit tests are disabled: the Hilt walks need the fakes, and live code is tested in `:core:network` and `:core:data` with `MockEngine`.

Found while implementing:
- The sync scripts live in `core/network/openapi/` (`sync.sh`, `prepare.py`), because the app's `.gitignore` admits only listed top-level directories.
- `date-time` maps to `java.time.Instant` through `--custom-type-mapping` and `InstantSerializer`: kotlinx has no serializer for the `kotlin.time.Instant` Fabrikt picks by default. `LiveServerTest` (runs with `SHOPNEXUS_API_URL`) caught it; MockEngine tests did not.
- A transport failure maps to `DataError.Network`, not `Offline`: the app cannot tell no network from a server that is down. Any 4xx other than 404 is `Conflict(code)`.
- `GROUP_BY_TAG`: 14 client classes (`AuthClient`, `CatalogClient`, …) instead of one per path.

## Review Focus

1. Request bodies omit absent optional fields (server rejects unknown fields and most `null`s) → `NetworkJsonTest.optionalNullsAreOmitted`.
2. Generated clients resolve paths against the base URL with `DYNAMIC_BASE_URL` → `HttpClientTest.pathsResolveAgainstTheBaseUrl`.
3. `idempotent` reuses one key across retries and retries only transport failures → `IdempotentTest`.
4. Error envelope decoding keeps `code`, `fields`, `details`, `trace_id` → `ApiFailureTest`.
5. `DataError` mapping: transport → `Offline`, 404 → `NotFound`, 409 → `Conflict(code)`, other → `Network` → `ApiFailuresTest`.
6. Both flavors assemble; demo walks still pass on `testDemoDebugUnitTest`.

## File map

- Create `tools/sync-openapi.sh`, keep `tools/prepare-openapi.py` (from Phase 0).
- Create `core/network/` (`build.gradle.kts`, `openapi/codegen.yaml`, `src/main/kotlin/vn/shopnexus/core/network/{NetworkJson,ShopNexusHttpClient,ApiFailure,Idempotent}.kt`, tests).
- Modify `settings.gradle.kts`, `gradle/libs.versions.toml`, `core/data/build.gradle.kts`.
- Create `core/data/src/main/kotlin/vn/shopnexus/core/data/net/ApiFailures.kt` + test.
- Modify `core/data/.../di/DataModule.kt` → `FakeBindings.kt` (include-only modules + shared provides).
- Modify `app/build.gradle.kts` (flavor dimension `data`: `live` default, `demo`; `buildConfig`; live unit tests off).
- Create `app/src/demo/kotlin/vn/shopnexus/android/di/DemoDataModule.kt`, `app/src/live/kotlin/vn/shopnexus/android/di/LiveDataModule.kt`, `app/src/debug/res/xml/network_security_config.xml` + debug manifest attribute.
- Modify `run.sh` (flavor argument, `adb reverse` for live), `README.md`, `.github/workflows/check.yml` if it names `installDebug`/`testDebugUnitTest`.

## Tasks

### Task 1: Spec sync script and committed codegen input
- [ ] `tools/sync-openapi.sh`: `npx -y @redocly/cli@2.72.1 bundle ../server/api/openapi.yaml` into a temp dir, then `python3 -I tools/prepare-openapi.py bundled codegen`, then copy to `core/network/openapi/codegen.yaml`; `--check` diffs instead of copying and exits 1 on drift.
- [ ] Run it; commit `codegen.yaml`, the script and `prepare-openapi.py` (`build: the server's OpenAPI, prepared for codegen`).

### Task 2: `:core:network` with generated client
- [ ] Catalog entries for Ktor and Fabrikt; module applies `shopnexus.jvm.library`, a `fabrikt` configuration and `generateApi` (`JavaExec`, inputs: `codegen.yaml`, outputs: `build/generated/fabrikt`), wired into `compileKotlin` and the main source set; `-opt-in=kotlinx.serialization.ExperimentalSerializationApi`.
- [ ] `NetworkJson` (`ignoreUnknownKeys`, `explicitNulls = false`, `encodeDefaults = false`), `shopNexusHttpClient(baseUrl, engine)` (ContentNegotiation, `defaultRequest` base URL, `HttpTimeout`, `expectSuccess = false`), `ApiFailure.from(NetworkError)`, `idempotent(attempts) { key -> }`.
- [ ] Tests (MockEngine): Review Focus 1–4. Commit `feat(network): a client generated from the server's OpenAPI`.

### Task 3: `DataError` from `ApiFailure`
- [ ] `:core:data` depends on `:core:network` (`api`); `ApiFailure.toDataError()` + `ApiFailuresTest` (Review Focus 5). Commit.

### Task 4: Flavors and bindings
- [ ] `DataModule.kt` → `FakeBindings.kt`: `FakeDataBindings`, `FakeAccountBindings` (`@DisableInstallInCheck`), `DataModule` keeps only the shared provides (failures, zone, scope).
- [ ] `DemoDataModule`: includes both, `fixtureClock()`. `LiveDataModule`: includes both, `Clock.system(VN_ZONE)`, provides `HttpClient` from `BuildConfig.API_BASE_URL`.
- [ ] `app/build.gradle.kts`: dimension `data`, `live` (default) and `demo`; `API_BASE_URL` per build type (debug `http://127.0.0.1:8080` or `-Pshopnexus.apiUrl`, release `https://api.shopnexus.id.vn`); disable unit tests for `live`.
- [ ] Debug network security config allowing cleartext to `127.0.0.1`, `localhost`, `10.0.2.2`.
- [ ] `run.sh`: `DATA=live|demo` (default live), `installLiveDebug`/`installDemoDebug`, `adb reverse` for live. README commands. Commit `build(app): live and demo flavors`.

### Task 5: Gate
- [ ] `:core:network:check :core:data:check :app:assembleLiveDebug :app:assembleDemoDebug :app:testDemoDebugUnitTest --tests '*SliceTest' --tests '*DealsWalkTest' --tests '*SellWalkTest'`, then `:app:lintLiveDebug`.
- [ ] Install live debug on the emulator with the dev server and devseed data; the app still shows fakes (expected), and `adb logcat` shows no crash.
- [ ] `/code-review`, `/simplify`, merge into `main`, tick the roadmap.
