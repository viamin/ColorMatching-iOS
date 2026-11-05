# Issue #5 PR notes: generated OpenAPI client

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Package includes `swift-openapi-generator` and `swift-openapi-runtime`; the upstream contract is vendored | `OpenAPIGenerationConfigurationTests.testPackagePinsGeneratorRuntimeAndPublishedSpec` | Red until implementation adds the dependencies and `iOS/OpenAPI/color_matching.openapi.json` |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `OpenAPIGenerationConfigurationTests.testVendoredSpecDocumentsEveryCompanionSurface`; generated-client wrapper tests added during implementation | Red until the spec is vendored and the ranked-results wrapper exists |
| App-facing operations work against local stubbed responses | `APIClientTests` uses `MockURLProtocol`; manifest and recent-sheet coverage added here, while existing tests cover writes | Passing for the existing facade; rerun after it delegates to generated types |
| Hand-written API models are replaced while client-side measurement models remain | Human review of the generated target and `APIClient.swift` diff | Not automatable from a transport test; inspect the implementation diff |
| PR records prose/spec deltas and gaps | This document, copied into the implementation PR description | Complete below |

The stub tests are permanent unit/service tests because these six network boundaries are a recurring app behavior. They do not contact a live Phoenix server.

## Contract deltas found against `docs/color-matching-api-contract.md`

- The published OpenAPI document is served unauthenticated at `GET /api/v1/openapi.json`; the six companion operations require `bearerAuth`.
- `GET /api/v1/test_sheets/:sheet_id/ranked_results` is now concrete: it returns `schema_version: "lps-ranked-results/v1"`, a sheet ID, profile, capture timestamps/counts, algorithm versions, and ranked pair observations. The prose contract listed only a narrative response expectation.
- The actual capture endpoint accepts either the prose-style nested `metadata` payload or a legacy flat payload. The iOS client should keep using the nested form.
- `CaptureMetadata.image_width` and `image_height` are required by the published spec, and the positive numeric bounds for exposure, ISO, and dimensions are explicit.
- Measurement upload requires each measurement to include both `linear_rgb_median` and `normalized_linear_rgb_median`; the prose showed the latter but did not identify it as required. Its `stats` object is not in the published request schema.
- Measurement and judgment uploads return `200` JSON acknowledgement bodies with capture ID and accepted counts. The prose did not specify response bodies; the existing stubs had assumed `204`.
- Pair scores accept any of `score`, `similarity`, or `distance`, with `pair_id` and `algorithm_version` required. The iOS payload continues to use `distance` and `similarity`.
- The published schemas leave several manifest fields structurally under-described (only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` are required), even though the server renderer emits the fuller geometry needed by the app. This is an upstream endpoint/schema precision gap to track before relying on generated manifest geometry types.
- The published ranked-results schema is similarly minimal (only schema version and sheet ID), while the server emits the detailed ranked result body. This is an upstream endpoint/schema precision gap; generation can expose only the declared fields until the provider expands the schema.

## Implementation handoff

Vendor the response from `https://github.com/viamin/color_matching`'s `/api/v1/openapi.json` as `iOS/OpenAPI/color_matching.openapi.json`, add the generator and runtime to `iOS/Package.swift`, generate a dedicated API target, and make the app-facing client delegate to it. Preserve `MeasurementCore` models that only describe camera analysis; adapters are appropriate at the generated-client boundary.
