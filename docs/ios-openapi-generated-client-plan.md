# Generated OpenAPI Client for the iOS Companion (issue #5)

This document is the test-writing-phase plan for replacing the hand-written API
layer with a client generated from the OpenAPI document published by
`viamin/color_matching` (issue viamin/color_matching#110, landed as PR
viamin/color_matching#113 and served at `GET /api/v1/openapi.json`). It records
the decisions the committed tests enforce, the contract deltas between the
prose contract (`docs/color-matching-api-contract.md`) and the published spec,
and the naming assumptions used by the guarded generated-client tests.

## Decisions enforced by tests

| Decision | Value |
| --- | --- |
| Vendored spec path | `iOS/Sources/ColorMatchingAPI/openapi.json` (JSON, fetched from `GET /api/v1/openapi.json`; `openapi.json` is the default document name expected by the `OpenAPIGenerator` build plugin) |
| Generator config path | `iOS/Sources/ColorMatchingAPI/openapi-generator-config.yaml` |
| Generated target/module | `ColorMatchingAPI` (SwiftPM library target applying `.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")`) |
| Dependencies | `apple/swift-openapi-generator` (build tool plugin), `apple/swift-openapi-runtime` (product `OpenAPIRuntime`, linked by `ColorMatchingAPI`) |
| Consumers | `ColorMatchingLPSAppCore` depends on `ColorMatchingAPI`; the `ColorMatchingLPSAppTests` test target also depends on it |
| Naming | Generator defaults (defensive sanitization). The published operationIds are `ColorMatchingWeb.<Controller>.<action>`, which defensive naming renders as e.g. `ColorMatchingWeb_period_TestSheetController_period_manifest`. Do not enable the idiomatic naming strategy without renaming the call sites in `GeneratedClientStubbedResponseTests`. |
| Checked-in sources | Generated code is produced by the build plugin into `.build/` and is not committed; the committed artifacts are the vendored spec + generator config |

## Contract deltas: prose contract vs published spec

Derived from `docs/color-matching-api-contract.md` compared against
`lib/color_matching_web/api_schemas.ex`, the controllers, and the router of
`viamin/color_matching` at PR #113. These deltas must be summarized in the
implementation PR description (deliverable 5).

1. **Measurement upload returns a JSON body, not an empty response.** The prose
   contract shows no response payload for `POST /captures/:id/measurements`
   (and the app's hand-written client only status-checks). The spec declares
   `200` with `MeasurementUploadResponse` = `{capture_id, measurement_count,
   pair_score_count}` (all required).
2. **Judgment upload likewise returns `200` with a body**: `JudgmentUploadResponse`
   = `{capture_id, judgment_count}` (all required). The hand-written client
   treats any 2xx as opaque.
3. **Capture creation accepts two shapes.** The prose contract documents only
   the nested `{metadata, quality}` request. The spec (`CaptureRequest`) allows
   either the nested shape or a legacy flat shape whose field names differ:
   `exposure_duration` (not `exposure_duration_seconds`) and `rejection_reasons`
   (not `rejections`). The app should keep sending the nested shape.
4. **No top-level `scoring_algorithm_version` on measurement upload.** The prose
   contract has `scoring_algorithm_version` at the root of the measurement
   upload; the spec's `MeasurementUploadRequest` only documents `measurements`
   and `pair_scores`, with the algorithm version carried per pair score
   (`PairScoreRequest.algorithm_version`, required, plus exactly one of
   `score` / `similarity` / `distance` via `anyOf`).
5. **No per-measurement `stats` object in the spec.** The prose contract (and
   today's app payload) includes `stats {sample_count, clipping_fraction, mean,
   standard_deviation}` per measurement. The spec's measurement rows only
   document `patch_id`, `linear_rgb_median`, `normalized_linear_rgb_median`
   (all required).
6. **RGB payloads are a union (`RgbPayload`)**: numeric array, `{r, g, b}`
   object, or string, via `anyOf`. The palette-facing `Rgb` component uses
   integer channels; `RgbPayload` numbers. The app currently sends objects.
7. **Manifest schema is under-documented relative to prose.** The spec's
   `TestSheetManifest` only declares `schema_version` (enum
   `["lps-sheet-manifest/v1"]`), `sheet_id`, and
   `capture_profile.scoring_algorithm_version` (enum `["lps-distance-v1"]`) as
   required; the richer prose fields (`patches`, `pairs`, `page`,
   `registration_markers`, `printer_profile`, `sheet_version`, `manifest_url`,
   `created_at`) are not declared in the spec, so they are outside the typed
   contract. The generated client will type only the declared subset; the app's
   manifest decoding for the undeclared fields stays on `MeasurementCore`'s
   client-side models.
8. **Ranked results are under-documented too.** `RankedResults` declares only
   `schema_version` (enum `["lps-ranked-results/v1"]`) and `sheet_id`; the prose
   promise of "source colors, scores, labels, capture provenance, printer
   profile, and scoring algorithm version" is not machine-visible.
9. **`title` nullability on recent sheets matches prose** (`nullable: true`).
10. **Authentication is `bearerAuth`** (HTTP bearer) on all six app-facing
    operations, matching the prose contract's shared bearer token. The
    generated client does not inject auth headers by itself; the app wires an
    `OpenAPIRuntime.ClientMiddleware` (or equivalent) that sets
    `Authorization: Bearer <token>`.

### Endpoint gaps discovered

The published spec covers strictly more surface than the iOS app uses. Endpoints
in the spec but not used by this app (no action required; listed so the PR
description can record them):

- `GET /api/v1/printer_profiles`, `GET /api/v1/printer_profiles/{id}/colors`,
  `GET /api/v1/printer_profiles/{id}/metamer_pairs`
- `GET /api/v1/palettes`, `GET /api/v1/colors` (composition-client surface)
- `POST /api/illuminant_measurements`, `POST /api/illuminant_measurements/bulk`
- `POST /api/multi_image_mapping` (PNG response body)
- `GET /api/v1/openapi.json` (the spec endpoint itself)

Status codes differ from what the hand-written client assumed: capture creation
is `201`, both uploads are `200` (never `204`), and all operations declare
`401`/`404` (plus `422` on writes) with an `ApiErrorResponse` body.

## Operation IDs and generated names

`open_api_spex` derives operationIds as `<Module>.<action>`:

| Surface | operationId | Generated method (defensive) |
| --- | --- | --- |
| Sheet manifest | `ColorMatchingWeb.TestSheetController.manifest` | `ColorMatchingWeb_period_TestSheetController_period_manifest` |
| Recent sheets | `ColorMatchingWeb.TestSheetController.recent` | `ColorMatchingWeb_period_TestSheetController_period_recent` |
| Ranked results | `ColorMatchingWeb.TestSheetController.ranked_results` | `ColorMatchingWeb_period_TestSheetController_period_ranked_results` |
| Create capture | `ColorMatchingWeb.CaptureController.create` | `ColorMatchingWeb_period_CaptureController_period_create` |
| Upload measurements | `ColorMatchingWeb.CaptureController.upload_measurements` | `ColorMatchingWeb_period_CaptureController_period_upload_measurements` |
| Upload judgments | `ColorMatchingWeb.CaptureController.upload_judgments` | `ColorMatchingWeb_period_CaptureController_period_upload_judgments` |

Enum cases for compatibility strings under defensive sanitization
(`-` → `_hyphen_`, `/` → `_sol_`, `.` → `_period_`):

- `lps-sheet-manifest/v1` → `lps_hyphen_sheet_hyphen_manifest_sol_v1`
- `lps-distance-v1` → `lps_hyphen_distance_sol_v1`
- `lps-ranked-results/v1` → `lps_hyphen_ranked_hyphen_results_sol_v1`

## Criterion-to-test mapping (issue #5)

| Criterion | Permanent verification |
| --- | --- |
| D1: generator + runtime deps, spec vendored | `OpenAPIGeneratorWiringTests` (package manifest, plugin, config, vendored doc) and `OpenAPISpecConformanceTests.testSpecExists…` |
| D2: client generated for all six surfaces | `OpenAPISpecConformanceTests` per-operation tests (paths, methods, operationIds, request/response schemas) |
| D3: hand-written transport models replaced | `OpenAPIGeneratorWiringTests.testHandwrittenTransportDTOsAreRemovedFromAppSources` + `ColorMatchingLPSAppCore` dependency wiring test |
| D4: stubbed-response tests of the generated client, no live server | `GeneratedClientStubbedResponseTests` (in-memory `ClientTransport`; compiles once `ColorMatchingAPI` exists, guarded by `#if canImport(ColorMatchingAPI)`) |
| D5: PR description records contract deltas | This document's delta table is the source material; the implementation PR description links/copies it (human review) |

## Guarded-test assumptions

`GeneratedClientStubbedResponseTests` is guarded by
`#if canImport(ColorMatchingAPI)` so the red-phase suite still compiles before
the generated target exists; the tests activate automatically once it does.
They assume:

- default (defensive) naming, per the table above;
- memberwise inits inferred via `.init(...)` so nested payload struct names
  (`…Payload`) never need to be spelled out;
- `RgbPayload` object variant is `.case2` (array → `.case1`, object → `.case2`,
  string → `.case3`);
- request bodies are read by iterating the `HTTPBody` async sequence (stable
  across runtime versions).

If the implementation resolves a runtime version where any of these differ,
update the test call sites in the same PR; the wire-format assertions (paths,
methods, snake_case JSON keys) are the durable contract and must not change.
