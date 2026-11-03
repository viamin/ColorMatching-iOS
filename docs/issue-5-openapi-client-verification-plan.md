# Issue #5 OpenAPI client verification plan

This is the red-phase verification plan for replacing the iOS hand-written
`/api/v1` client. The provider contract is
`viamin/color_matching#110`, whose published endpoint is
`GET /api/v1/openapi.json`.

## Criterion map

| Criterion | Smallest credible verification | Planned inspectable evidence |
| --- | --- | --- |
| Generator, runtime, and vendored spec are added | Focused package/spec contract test | `GeneratedOpenAPIContractTests.testVendoredOpenAPIDocumentAndPackageDeclareEveryAppSurface` |
| Generated client covers manifest, recent sheets, capture, measurement, judgment, and ranked results | Focused vendored-spec path assertions | `GeneratedOpenAPIContractTests.testVendoredOpenAPIDocumentAndPackageDeclareEveryAppSurface` |
| Generated types are wired through the app’s transport boundary | Local `URLProtocol` stub tests for each generated operation | Extend `APIClientTests`; no live-server dependency |
| Generated client works with local stubbed responses | Permanent unit/service tests using `MockURLProtocol` | `APIClientTests` |
| Contract differences and endpoint gaps are recorded for review | Human inspection of this document and final PR description | PR description, with this document as source evidence |

## Provider-spec deltas found before implementation

- The real API includes `GET /api/v1/test_sheets/:sheet_id/ranked_results`;
  the current iOS client has no corresponding call.
- The current client treats measurement and judgment uploads as empty
  success responses. The published schemas specify typed `200` JSON responses
  with `capture_id` and uploaded-item counts.
- The capture schema accepts both the nested `metadata` form used by iOS and a
  legacy flattened form. The generated client should use the nested form.
- The manifest schema currently declares only the required compatibility
  fields (`schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`) even though the rendered
  manifest carries the richer fields consumed by the app. This is a provider
  schema precision gap to preserve in the PR description and resolve with the
  provider before relying on generated manifest models.
- The ranked-results schema currently specifies only `schema_version` and
  `sheet_id`; ranking rows, scores, labels, and provenance remain unspecified.
  This is an endpoint-schema gap, not permission to invent client models.

## Red-phase status

The new package/spec test intentionally fails until the implementation run
vendors `iOS/OpenAPI/openapi.json` and declares the generator/runtime
dependencies. The manifest and recent-sheet stubs are permanent, passing
local-response coverage that the generated transport must retain.
