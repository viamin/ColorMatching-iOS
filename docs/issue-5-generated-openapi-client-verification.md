---
module: ios
tags: [openapi, swift, api-client, verification]
problem_type: implementation-plan
---

# Issue #5 generated OpenAPI client: verification plan

## Criterion map

| Criterion | Smallest credible verification | Status in test-writing phase |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor or fetch the OpenAPI document | `APIClientTests.testPackageDeclaresSwiftOpenAPIRuntimeForGeneratedClient` checks the package declaration; implementation must add a checked-in spec plus generator plugin and make this test pass. | Red: runtime dependency absent. |
| Generate all currently used surfaces | Permanent local-stub tests in `APIClientTests` must exercise manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results through the generated client adapter. | Partial: manifest/recent/capture/measurement/judgment tests exist; ranked-results test is blocked by the current public API and underspecified upstream response schema. |
| Replace hand-written API models while retaining client-side models | Compile the app after removing network DTO declarations and retaining `MeasurementCore` analysis types; inspect the generated source diff and app imports. | Not run: implementation phase. |
| Swift tests use local stubs, not a live server | `MockURLProtocol` responses in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. | Covered for existing manifest/recent/capture/measurement/judgment adapter paths. |
| Record prose-contract deltas and endpoint gaps | This document is the PR-ready evidence record; final PR description must link it and update its status after generation. | Recorded below. |

## Published-spec comparison

Evidence was inspected from upstream `viamin/color_matching` main at issue #110's `/api/v1/openapi.json` implementation, specifically `ColorMatchingWeb.ApiSchemas` and `TestSheetJSON`.

The endpoint paths and bearer authentication agree with the prose contract. The meaningful deltas are:

- Capture requests support both the prose contract's nested `metadata`/`quality` shape and a legacy flat shape. The published schema names the flat duration `exposure_duration`, whereas the nested field is `exposure_duration_seconds`.
- Measurement uploads no longer document `scoring_algorithm_version` at the request top level or the `stats` object. Pair scores accept `score`, `similarity`, or `distance`; the prose contract requires `distance` and `similarity` together.
- The published `RgbPayload` accepts an RGB array, RGB object, or JSON-encoded string; the prose contract only describes RGB objects.
- Successful measurement and judgment uploads return count bodies with `200 OK`; the current hand-written client treats them as bodyless `204` responses.
- Ranked results are implemented and have a `lps-ranked-results/v1` response, but the published OpenAPI schema declares only `schema_version` and `sheet_id`. The actual response additionally contains printer profile, capture times/counts, algorithm versions, and ranked pair results. A generated typed ranked-results client cannot faithfully cover the app's intended surface until those fields are represented in the upstream schema.
- The published manifest schema similarly requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`, despite the endpoint rendering the full manifest consumed by this app. Generation would make omitted fields unavailable as typed properties.

## Implementation handoff

1. Vendor the exact `/api/v1/openapi.json` used for generation and record its source commit or ETag.
2. Add the generator plugin/runtime and generate a dedicated API module.
3. Adapt the existing app-facing client to generated request/response types without changing capture or scoring behavior.
4. Extend the permanent stubs to include a typed ranked-results response after upstream expands that schema; assert `200` response bodies for the two upload endpoints.
5. Replace the red package-dependency assertion with passing generation/compile coverage, run `swift test --disable-sandbox`, and copy the resolved deltas into the PR description.
