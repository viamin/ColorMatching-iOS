---
module: iOS companion
tags: [openapi, codegen, api-client, testing]
problem_type: migration_plan
---

# OpenAPI generated-client migration plan (issue #5, tests-first run)

This document records the tests-first plan for replacing the hand-written API
layer with a generated OpenAPI Swift client, the acceptance-criterion-to-test
mapping, and the deltas found between `docs/color-matching-api-contract.md`
(the prose contract) and the spec published by viamin/color_matching#110
(landed as viamin/color_matching#113). The PR description should carry the
delta summary; this file is the durable evidence.

## Source of truth for the published spec

The Phoenix app defines the spec with `open_api_spex`
(`lib/color_matching_web/api_spec.ex`, `lib/color_matching_web/api_schemas.ex`)
and serves it at `GET /api/v1/openapi.json`. There is no committed
`openapi.json` in the upstream repo; the iOS side must vendor a rendered copy.

## Pinned implementation decisions (for the follow-up implementation run)

These decisions are pinned by the tests added in this run; the implementation
run should follow them or update the tests alongside the code:

- Vendor the rendered document as `iOS/Sources/ColorMatchingLPSAPI/OpenAPIFiles/openapi.yaml`
  (any `openapi.yaml`/`openapi.yml`/`openapi.json` under `iOS/` is accepted by
  the artifact tests, but keep it out of `.build/`).
- Generate a module named `ColorMatchingLPSAPI` (`swift-openapi-generator`
  build plugin, `generate: [types, client]`), depending on
  `swift-openapi-runtime` (current release line 1.13.x; the
  `ClientTransport.send(_:body:baseURL:operationID:)` signature in the tests
  matches 1.3.0+).
- Rewrite operation IDs in the vendored document to clean names; the tests pin
  `manifest` for `GET /api/v1/test_sheets/{sheet_id}/manifest`. Suggested set:
  `manifest`, `recentSheets`, `rankedResults`, `createCapture`,
  `uploadMeasurements`, `uploadJudgments`.
- Keep the app-facing `ColorMatchingLPSAppCore.APIClient` surface stable
  (same method names/signatures) so `ContentView` is untouched, backed by the
  generated client instead of hand-rolled `URLSession` + `Codable`.
- Add `APIClient.fetchRankedResults(sheetID:baseURL:)` returning an
  app-facing `RankedResults` value with `schemaVersion` and `sheetID`
  properties (codebase convention: `sheetID`, like `SheetManifest.sheetID`),
  mapped from the generated `Components.Schemas.RankedResults`
  (which exposes `sheetId`).
- Purely client-side models (patch sampling geometry, scoring models in
  `MeasurementCore`) stay hand-written. `SheetManifest`/`Patch`/`PairManifest`
  remain the app's decode of manifest fields the published spec does not
  type (see gap G-1) — the "keep purely client-side models as-is" carve-out
  in the issue.

## Acceptance criteria → verification mapping

| AC | Deliverable | Verification (smallest credible) | Where |
|----|-------------|----------------------------------|-------|
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` in the iOS package; OpenAPI document fetched/vendored | Repo-artifact unit tests: `Package.swift` declares both packages; a vendored OpenAPI 3 document exists under `iOS/` | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPISpecArtifactTests.swift` |
| AC-2 | Generated client covering manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Artifact test asserting the vendored spec declares the six app paths + the nine schema titles; generated-type decode tests; one end-to-end generated-client call through a stubbed `ClientTransport` | `OpenAPISpecArtifactTests.swift`, `GeneratedClientStubbedResponseTests.swift` |
| AC-3 | Replace hand-written API models with generated types; keep client-side models | Wire-contract drift guards keep app behavior fixed while the guts swap to generated types; snake_case wire-key roundtrip tests prove generated types own the wire format | `APIClientWireContractTests.swift`, `GeneratedClientStubbedResponseTests.swift` |
| AC-4 | Swift tests exercising the generated client against local stubbed responses (no live server) | All new tests stub `URLProtocol` or `ClientTransport`; no network in CI | `TestSupport.swift`, `GeneratedClientStubbedResponseTests.swift`, `APIClientWireContractTests.swift` |
| AC-5 | PR description records contract deltas + endpoint gaps | Deltas recorded below (G-1..G-4, D-1..D-9); PR description summarizes from this file | this document |
| AC-6 | Exit criterion: `swift test --disable-sandbox` green with generated types wired in | Run on macOS (CI); this container has no Swift toolchain, so the suite cannot execute here. Red-phase state at this commit: artifact tests fail (nothing vendored yet); generated-client + ranked-results tests fail to compile (module/method do not exist yet) | `cd iOS && swift test --disable-sandbox` |

## Contract deltas: prose contract vs published spec

Verified against `api_schemas.ex`, `capture_controller.ex`,
`test_sheet_controller.ex`, and `test_sheet_json.ex` at viamin/color_matching
main (post-#113).

### Endpoint gaps (spec weaker than what the app consumes)

- **G-1 Manifest schema is skeletal.** The published `TestSheetManifest` schema
  only types `schema_version` (enum `lps-sheet-manifest/v1`), `sheet_id`, and
  `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`). The
  prose contract documents `sheet_version`, `manifest_url`, `created_at`,
  `page`, `registration_markers`, `printer_profile`, `patches`, and `pairs` —
  and the runtime actually returns all of them (`TestSheetJSON.manifest/1`),
  but they are invisible to a generated client. The generated manifest type
  cannot feed `SheetAnalyzer` (which needs patch/pair rects). Follow-up
  upstream issue needed; meanwhile the app keeps decoding those fields with
  its own `Codable` types (client-side carve-out).
- **G-2 Ranked results schema is skeletal.** `RankedResults` only types
  `schema_version` (new enum `lps-ranked-results/v1`, not present in the
  prose contract) and `sheet_id`. The runtime returns a full payload
  (`capture_count`, `latest/earliest_capture_at`,
  `scoring_algorithm_versions`, and per-pair `results` with rank, source
  colors, aggregated `score`, judgments, observation counts). Generated types
  cannot see any of it. Follow-up upstream.
- **G-3 Prose contract documents no response for measurement/judgment uploads;
  the old iOS tests assumed 204 No Content.** The real endpoints return
  `200` with JSON bodies: `{capture_id, measurement_count, pair_score_count}`
  and `{capture_id, judgment_count}`. Capture creation returns `201` with
  `{capture_id}` (matches prose). Drift-guard tests now pin the 200+body
  behavior.
- **G-4 The spec covers endpoints the iOS app does not use** (macOS-app
  surfaces): `printer_profiles`, `printer_profiles/{id}/colors`,
  `printer_profiles/{id}/metamer_pairs`, `palettes`, `colors`,
  `/api/illuminant_measurements(+/bulk)`, `/api/multi_image_mapping`, plus
  `/api/v1/openapi.json` itself. The generated client will contain these;
  harmless, noted for scope clarity.

### Field-level deltas (prose vs spec/runtime)

- **D-1 Measurement upload request**: the spec has no per-measurement `stats`
  object (prose requires `sample_count`, `clipping_fraction`, `mean`,
  `standard_deviation`) and no top-level `scoring_algorithm_version` (prose
  requires it). Extra keys are tolerated server-side (schemas don't set
  `additionalProperties: false`), so the app may keep sending them, but
  generated types won't carry them.
- **D-2 `normalized_linear_rgb_median` is required** per measurement in the
  spec (optional in prose). The app uploads normalized measurements already;
  the drift-guard test asserts the key is always present.
- **D-3 `linear_rgb_median`/normalized are `RgbPayload`** — `anyOf` of RGB
  array, `{r,g,b}` object, or string. Prose only documents the object form.
- **D-4 Pair scores**: `PairScoreRequest` = `pair_id` + `algorithm_version`
  plus `anyOf(score, similarity, distance)`. Prose shows `distance` +
  `similarity` + `algorithm_version` as a fixed triple. The app sending both
  similarity and distance satisfies the `anyOf`.
- **D-5 Capture request**: spec allows either the nested
  `{metadata: {...}, quality: {...}}` form (prose) or a flattened form whose
  field names differ: `exposure_duration` (not `exposure_duration_seconds`)
  and `rejection_reasons` (not `rejections`). The app uses the nested form.
- **D-6 `iso` is an integer** in the spec (prose/Swift used a float).
  Generated types will type it as an integer.
- **D-7 `printer_profile` shape differs**: runtime returns
  `{printer_make_model, paper_type, ink_type, icc_profile, print_settings,
  driver_name, driver_version, calibration_date, calibration_version, notes}`
  vs prose's `{id, name, paper, ink, settings}`. (Part of G-1 — untyped in
  the spec anyway.)
- **D-8 Patch IDs**: runtime patch ids are `"{pair_id}#first|second"`
  (e.g. `pair_1#first`); the prose example used `patch_1`-style ids. Opaque
  strings — no behavior change, but tests/fixtures use the real form.
- **D-9 Recent sheets**: `title` is required-but-nullable and currently
  always `null` from the runtime; `manifest_url` is built with VerifiedRoutes.
  Prose matched (`title` may be null).
- **D-10 Errors**: the spec types a shared `ApiErrorResponse`
  (`errors` = object or array of `{detail, source}`); auth uses a documented
  `bearerAuth` security scheme with 401s on every app endpoint. The current
  hand-written client collapses everything to `APIError.badStatus`; the
  generated client surfaces per-operation 401/404/422 cases.

## Test red/green expectations at this commit (tests-only run)

- `OpenAPISpecArtifactTests` — compiles today; all four tests fail (nothing
  vendored, no package deps). Red demonstrating AC-1/AC-2.
- `APIClientWireContractTests` — compiles and passes against the current
  hand-written client; must stay green after the guts swap to generated
  types (AC-3/AC-4 regression guards), and pins the real wire shapes
  (200+JSON bodies, snake_case, real manifest/ranked-results payloads).
- `RankedResultsClientSurfaceTests` — fails to compile until
  `APIClient.fetchRankedResults(sheetID:baseURL:)` + `RankedResults` exist
  (missing surface, AC-2).
- `GeneratedClientStubbedResponseTests` — fails to compile until the
  `ColorMatchingLPSAPI` module (generated) and `swift-openapi-runtime`
  dependency exist (AC-2/AC-4). The stub `ClientTransport` matches
  swift-openapi-runtime 1.3.0+ (`send(_:body:baseURL:operationID:)`).

## How to run

```bash
cd iOS && swift test --disable-sandbox
```

The `swift-openapi-generator` build plugin needs the non-sandboxed run. CI
(GitHub Actions, macOS) runs `swift test` plus the Xcode scheme; note the
Xcode project's `ColorMatchingLPSAppTests` target has an explicit file list
(`APIClientTests.swift` only), so the new SwiftPM test files run via
`swift test`, not via the xcodeproj target, until the project file is updated
in the implementation run.
