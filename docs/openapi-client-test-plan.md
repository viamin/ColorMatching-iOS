---
module: iOS
tags: [openapi, api-client, codegen, contract, testing]
problem_type: feature_plan
---

# OpenAPI generated client: test plan and contract-delta record

Tests-only change for "Replace hand-written API layer with a generated OpenAPI Swift client" (#5). This document pins the naming contract the staged tests enforce, maps acceptance criteria to their verifications, and records the deltas between `docs/color-matching-api-contract.md` (prose contract) and the published OpenAPI spec.

Upstream dependency is resolved: viamin/color_matching#110 was closed by PR viamin/color_matching#113 (merged 2026-10-30). The Phoenix app serves the machine-readable spec at `GET /api/v1/openapi.json`, built with `open_api_spex` from `lib/color_matching_web/api_spec.ex`, `lib/color_matching_web/api_schemas.ex`, and per-controller `operation` declarations.

## Pinned naming contract

The staged tests pin these decisions; the implementation run must satisfy them.

| Item | Pinned value |
| --- | --- |
| Vendored spec path | `iOS/OpenAPI/color-matching-openapi.json` |
| Generated module (SwiftPM target) | `ColorMatchingOpenAPI`, sources under `iOS/Sources/ColorMatchingOpenAPI/` with `openapi-generator-config` |
| Packages | `apple/swift-openapi-generator` (build plugin `OpenAPIGenerator`), `apple/swift-openapi-runtime` (product `OpenAPIRuntime`) |
| Test target dependency | `ColorMatchingLPSAppTests` depends on `ColorMatchingOpenAPI` and `OpenAPIRuntime` |
| Facade | `ColorMatchingLPSAppCore.APIClient` keeps its current public method signatures; internals switch to generated types |

Operation IDs (see vendoring rule 1 below) and generated Swift names they produce:

| Endpoint | Operation ID | Generated method / types |
| --- | --- | --- |
| GET `/api/v1/test_sheets/{sheet_id}/manifest` | `getTestSheetManifest` | `Operations.getTestSheetManifest`, `Components.Schemas.TestSheetManifest` |
| GET `/api/v1/test_sheets/recent` | `listRecentTestSheets` | `Components.Schemas.RecentSheetsResponse` |
| POST `/api/v1/test_sheets/{sheet_id}/captures` | `createCapture` | `Components.Schemas.CaptureRequest`, `CaptureMetadata`, `CaptureCreatedResponse` |
| POST `/api/v1/captures/{capture_id}/measurements` | `uploadMeasurements` | `Components.Schemas.MeasurementUploadRequest`, `PairScoreRequest`, `RgbPayload`, `MeasurementUploadResponse` |
| POST `/api/v1/captures/{capture_id}/judgments` | `uploadJudgments` | `Components.Schemas.JudgmentUploadRequest`, `JudgmentUploadResponse` |
| GET `/api/v1/test_sheets/{sheet_id}/ranked_results` | `getRankedResults` | `Components.Schemas.RankedResults` |

### Vendoring normalization rules

The vendored document must stay byte-faithful to the served spec except for two mechanical, reviewable edits, recorded in the PR description:

1. **Operation IDs.** `open_api_spex` derives controller-qualified operation IDs (e.g. `ColorMatchingWeb.TestSheetController.manifest`), which produce unusable Swift identifiers. Normalize the six operation IDs above (rename only; paths, methods, schemas untouched).
2. **Server URL.** The served spec declares `servers: [{"url": "/"}]` (relative), which cannot produce absolute request URLs. Replace with the placeholder absolute `"https://example.test"` (matches the prose contract's example host); the facade supplies the real base URL per call.

Everything else — paths, parameters, schemas, enums, response codes — must be regenerated from `/api/v1/openapi.json` verbatim so server-side drift shows up as a vendoring diff.

## Acceptance criteria to verification map

| # | Criterion | Verification | Reference |
| --- | --- | --- | --- |
| AC-1 | Generator + runtime in package; spec fetched/vendored | Permanent unit tests (red until vendored) | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIPackageWiringTests.swift`, `OpenAPIDocumentTests.swift` |
| AC-2 | Generated client for all six surfaces the app uses | Permanent unit tests: spec coverage of the six paths/methods + guarded stubbed-response tests per endpoint | `OpenAPIDocumentTests.testVendoredSpecCoversEveryEndpointUsedByTheApp`, `GeneratedClientStubbedTransportTests.swift` |
| AC-3 | Hand-written API models replaced; client-side models kept | Permanent unit test asserting `APIClient.swift` imports `ColorMatchingOpenAPI` and drops its private wire DTOs | `OpenAPIPackageWiringTests.testAppCoreUsesGeneratedClientInsteadOfHandWrittenWireModels` |
| AC-4 | Stubbed-response tests, no live server in CI | Permanent unit tests via a stubbed `ClientTransport` (no network, no URLSession mocking) | `GeneratedClientStubbedTransportTests.swift` (activates via `#if canImport(ColorMatchingOpenAPI)`) |
| AC-5 | PR description records contract deltas + endpoint gaps | Human/external evidence: the delta and gap tables below, copied into the PR description | This document, sections below |
| AC-6 | `swift test --disable-sandbox` green with generated types wired | CI (`Swift and iOS Tests` job) after the implementation run lands | `.github/workflows/ci.yml` |

No ephemeral (`.ephemeral-tests/`) coverage is needed: every check is either a permanent repo-structure/unit guard or a stubbed-response unit test that belongs in the suite.

## Contract deltas: prose contract vs published spec

Verified against `api_schemas.ex`, `api_spec.ex`, router, and controller `operation` declarations at viamin/color_matching@main (2026-10-30):

1. **Upload responses gained bodies.** Prose contract (and the current hand-written client) treat measurement and judgment uploads as bodyless successes (existing tests stubbed `204`). The spec types `200` responses: `MeasurementUploadResponse {capture_id, measurement_count, pair_score_count}` and `JudgmentUploadResponse {capture_id, judgment_count}`. Staged fixtures updated accordingly.
2. **Top-level `scoring_algorithm_version` removed from the measurement upload.** The spec keeps the version per pair score (`PairScoreRequest.algorithm_version`, required) and drops the prose contract's top-level request field.
3. **`normalized_linear_rgb_median` is required per measurement** in the spec; the prose contract marks it optional.
4. **Measurement `stats` object is absent from the spec.** Prose documents `stats {sample_count, clipping_fraction, mean, standard_deviation}`; the published spec does not declare it (endpoint gap, below).
5. **`linear_rgb_median` is polymorphic.** `RgbPayload` is `anyOf: [number[], {r,g,b}, string]` — the generated Swift type is an enum; the prose contract only documents the `{r,g,b}` object form.
6. **Capture request accepts two shapes.** `CaptureRequest` is `anyOf` of flat metadata fields or nested `metadata` (+ optional `quality`); the app uses the nested form, which remains valid.
7. **Manifest schema is thin.** The spec types only `schema_version` (enum `lps-sheet-manifest/v1`), `sheet_id`, and `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`). The prose contract's `sheet_version`, `manifest_url`, `created_at`, `page`, `registration_markers`, `printer_profile`, `capture_profile.expected_illuminant`, `capture_profile.preferred_camera`, `patches[]`, `pairs[]` are served at runtime (see `TestSheetJSON.manifest/1`) but undeclared, hence untyped in generated code.
8. **Auth matches.** `bearerAuth` (http/bearer) security scheme, applied to the app-facing routes; `GET /api/v1/openapi.json` is unauthenticated.
9. **Error responses are typed.** `ApiErrorResponse {errors}` covers 401/404/422 on every app-facing operation; the prose contract never documented error bodies.
10. **The spec is broader than the app.** It also covers palettes, colors, printer profiles, metamer pairs, illuminant measurements, and multi-image mapping — out of scope for this app's generation needs (they generate unused client methods; harmless).

## Endpoint gaps discovered

1. **Manifest geometry and patches untyped** (delta 7). The app's `SheetManifest`/`Patch`/`PairManifest` decoding needs fields the spec does not declare. Until upstream enriches `TestSheetManifest`, the facade keeps decoding the manifest body with MeasurementCore's `SheetManifest` (a purely client-side model, kept as-is per the issue) while routing/auth/path handling goes through the generated client. Resolution to raise upstream: declare `page`, `registration_markers`, `patches[]`, `pairs[]`, `sheet_version`, `manifest_url`.
2. **Measurement `stats` not uploadable through generated types.** Generated structs cannot send undeclared fields, so switching to the generated client stops uploading `stats` (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`) — a data regression vs. today's hand-written client, asserted explicitly in the staged tests so the loss is visible. Resolution to raise upstream: add `stats` to `MeasurementUploadRequest.measurements` items.
3. **Ranked results payload effectively untyped.** The spec types only `schema_version` (enum `lps-ranked-results/v1`) and `sheet_id`; the rich runtime payload (rank, scores, judgments, capture provenance, printer profile — all rendered by `TestSheetJSON.ranked_results/1`) is undeclared, so generated code cannot model it yet.
4. **Rejection strings and judgment values are unconstrained.** The prose contract enumerates capture rejection reasons and judgment values; the spec types them as plain strings. Validation stays client-side.
5. **Relative server URL** (vendoring rule 2) and **controller-qualified operation IDs** (vendoring rule 1) require the two documented mechanical edits when vendoring.

## Implementation-run checklist

1. Vendor the spec: dump `GET /api/v1/openapi.json` from a running `color_matching` (or assemble from `ApiSpec` via `OpenApiSpex`), apply vendoring rules 1–2, commit at the pinned path.
2. `iOS/Package.swift`: add both Apple packages; add `ColorMatchingOpenAPI` target with the `OpenAPIGenerator` plugin; depend on `OpenAPIRuntime`; make `ColorMatchingLPSAppCore` depend on `ColorMatchingOpenAPI`; add `ColorMatchingOpenAPI` + `OpenAPIRuntime` to `ColorMatchingLPSAppTests`.
3. Add `iOS/Sources/ColorMatchingOpenAPI/openapi-generator-config` (`generate: [clients]`) and the OpenAPI document reference; generated sources appear at build time — commit a stable regeneration baseline.
4. Rework `APIClient` internals to the generated client (keep public signatures; bearer token via transport/URLSession configuration); delete the four private wire DTOs; keep `CaptureMetadata`/`WhiteBalanceGains`/`PairJudgment` as client-facing value types mapped into generated payloads.
5. The guarded tests in `GeneratedClientStubbedTransportTests.swift` activate automatically once the module exists. Generated nested type names follow swift-openapi-generator's documented naming (`measurementsPayload`, `judgmentsPayload`, `sheetsPayload`, `qualityPayload`, `RgbPayload.case1/.case2/.case3`); if the pinned runtime-API spellings in that file drift from the resolved runtime version, adjust names mechanically without weakening the assertions.

## Run evidence for this tests-only change

- Staged red tests: `OpenAPIDocumentTests` (5 tests) and `OpenAPIPackageWiringTests` (3 tests) compile against the current package and fail by design until AC-1/AC-2/AC-3 artifacts land.
- `APIClientTests.testUploadMeasurementsMatchesPublishedSpecShape` is red by design: today's hand-written client sends the prose shape (top-level `scoring_algorithm_version`, per-measurement `stats`) that the published spec no longer declares — the visible drift this issue exists to catch.
- Guarded: `GeneratedClientStubbedTransportTests` (7 tests) compile out via `#if canImport` until the generated module exists, then become the AC-4 verification.
- Not executed in this container: no Swift toolchain is installed (`swift: command not found`); `swift test --disable-sandbox` must run in CI or on a macOS host.
