# Issue #5 OpenAPI Client: Test Plan and Contract Review

This is the criterion-level plan for replacing the handwritten iOS API layer.
It is intentionally a red-phase artifact: the generator dependencies and
generated client are not in this commit.

## Verification map

| Criterion | Smallest credible verification | Evidence at implementation head |
| --- | --- | --- |
| Add generator/runtime and obtain the upstream OpenAPI document | Focused package configuration test verifies the generator, runtime, URLSession transport, and plugin are declared. A review verifies that the vendored/fetched document originates at the upstream `/api/v1/openapi.json` endpoint. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientConfigurationTests.swift` |
| Generate the manifest, recent sheets, capture, measurement, judgment, and ranked-results surfaces | A focused generated-client integration test uses `URLProtocol` stubs for one success response per operation, asserting decoded generated output and request operation/path. The implementation must add ranked-results coverage; no facade exists today. | Permanent XCTest to be added with the generated target |
| Replace hand-written API transport models while retaining client-only models | Compile the app core against generated types; inspect the removed hand-written API payload models and retained `MeasurementCore` domain types. | Compiler result plus source review |
| Exercise generated client without a live server | Permanent local `URLProtocol` XCTest coverage. Existing request tests cover create/upload routes; this commit adds manifest and recent-sheet response stubs. The implementation must move these stubs to the generated transport/client seam and add ranked results. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Record prose-contract deltas and endpoint gaps in the PR description | External/human evidence: compare this review with the merged upstream OpenAPI endpoint and include the findings in the PR body. | PR description |

## Upstream source and deltas

The dependency is complete: `viamin/color_matching#110` landed as
`viamin/color_matching#113`. The authoritative document is served at
`GET /api/v1/openapi.json` by `ColorMatchingWeb.OpenApiController`.

- The upstream contract has `200` JSON responses for measurement and judgment
  uploads, containing `capture_id` and count fields. The prose contract only
  specified requests and the current iOS client accepts any 2xx response while
  discarding the body.
- Ranked results are specified as `lps-ranked-results/v1`, including result
  rankings, aggregate score data, capture provenance, printer profile, and
  current/latest judgment information. The prose contract described that shape
  only informally, and the current iOS client has no ranked-results operation.
- The real recent-sheet response currently renders `title: null`; the prose
  contract permits null and therefore remains compatible.
- The upstream manifest printer profile contains printer provenance fields
  rather than the prose example's `id`, `name`, `paper`, `ink`, and `settings`
  shape. Generated models must follow the published schema rather than retain
  the illustrative prose model.

## Endpoint gaps

No route gap was found for the iOS workflow: upstream routes include manifest,
recent sheets, capture creation, measurement upload, judgment upload, and
ranked results. The iOS client gap is ranked-results retrieval.
