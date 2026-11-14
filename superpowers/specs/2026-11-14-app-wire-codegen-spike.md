# App wiring, Phase 0: codegen spike (2026-11-14)

Input for the Phase 1 plan (network foundation). Roadmap: `~/.claude/plans/planning-i-btw-gi-quizzical-hare.md`.

## Result

Fabrikt 28.4.0 (`io.fabrikt:fabrikt`, 2026-10-30) generates a Ktor + kotlinx.serialization client from the
server spec that compiles against Ktor 3.6.1 and Kotlin 2.4.21 with no errors. Output: 116 operations, 158
models, 286 files, ~14.5k lines. Clients return `NetworkResult<T>` (`Success` / `Failure(NetworkError.Http|Network|Serialization|Unknown)`),
take `Idempotency-Key` as a required parameter where the spec requires it, and use `ApiConfiguration.basePath`
at runtime (`DYNAMIC_BASE_URL`).

## Pipeline

1. **Bundle** (`npx @redocly/cli@2.72.1 bundle server/api/openapi.yaml`). Fabrikt cannot follow path-item
   `$ref`s into other files (NPE in `OpenApiPath.getPathString`).
2. **Prepare** (`app/tools/prepare-openapi.py bundled.yaml codegen.yaml`), five rules:
   - drop app-irrelevant paths: `/v1/console/*`, `/v1/dev/*`, `/_dashboard*`, carrier webhooks, `/healthz`, `/readyz`
     (console's `Action.details` is an untyped object kotlinx cannot generate);
   - drop a `oneOf` whose branches are only `required` lists (`SignInRequest`, `AddIdentityRequest`): the fields
     become optional; Fabrikt rejects properties beside a combiner;
   - `oneOf` of `$ref`s without a discriminator: when every branch has a required single-value enum property, add it
     as the discriminator (`ShipmentDraft` by `mode`); otherwise merge the branches into one object with optional
     fields (`ListingReadRequest`, `CarrierLogin`). Without this the client takes `Any`, which kotlinx cannot send;
   - `additionalProperties: true` becomes a multi-type schema so it generates `Map<String, JsonElement?>`
     (`Error.details`);
   - remove components no kept path references.
3. **Generate** with: `--targets HTTP_MODELS --targets CLIENT --http-client-target KTOR --http-client-opts DYNAMIC_BASE_URL
   --serialization-library KOTLINX_SERIALIZATION --validation-library NO_VALIDATION --type-overrides DATETIME_AS_INSTANT
   --type-overrides UUID_AS_STRING --type-overrides URI_AS_STRING --instant-library KOTLIN_TIME_INSTANT
   --http-model-opts FAULT_TOLERANT_ENUMS`.

## Decisions for Phase 1

- Bundling needs Node; keep it out of the Gradle build. `tools/sync-openapi.sh` runs steps 1–2 and writes
  `core/network/openapi/codegen.yaml`, which is committed. Gradle (plugin `ch.acanda.gradle.fabrikt` 2.2.0, or the
  CLI jar through a JavaExec task) generates from that file only. `verifyOpenApiSync` reruns the script into a temp
  file when `../server/api` exists and fails on a diff.
- Module `:core:network` needs `-opt-in=kotlinx.serialization.ExperimentalSerializationApi` (the generated
  `@JsonClassDiscriminator`), and the Ktor `Json` must use `explicitNulls = false` so optional nulls are omitted
  (the server rejects unknown fields and most `null`s).
- Generated time type is `kotlin.time.Instant`; the app's `Moment` is `java.time.Instant`. Mappers convert.
- `GROUP_BY_TAG` would give one client per tag instead of one per path (e.g. `V1SavedAlertClient`); try it in Phase 1.
- The merged request types (`ListingReadRequest`, `CarrierLogin`, `SignInRequest`, `AddIdentityRequest`) lose
  "exactly one of"; the Net repositories build them through small factory functions so callers cannot mix fields.

## Dev environment found

- `server/.env` was missing `CARRIER*`, `GHTK_*`, `GHN_*` (added by `make env`) and had empty `TRUST_LLM_*` (now the
  `LLM_*` values, as `.env.example` suggests). `make run` now serves `:8080`.
- App lint (`:core:ui:lintDebug`) and `detekt` already pass on `main`; checklist part 5's lint/detekt lines are stale.
- Emulator: use `adb reverse tcp:8080 tcp:8080` and `adb reverse tcp:56490 tcp:56490` and keep the `127.0.0.1` URLs in
  `.env`. That way the console in the host browser still loads media, which it could not with `10.0.2.2`.
- The dev database is empty (search returns no items). There is no seed tool, and sign-in by phone needs a real Firebase
  or PNV token, so an API-only seed cannot give accounts phones. A seed has to go through the server's own use cases
  (`server/cmd/devseed`), and needs its own small spec.
