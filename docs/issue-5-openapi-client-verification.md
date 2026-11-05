# Issue #5 OpenAPI Client Verification Plan

This is the test-first verification record for replacing the iOS hand-written
API layer with the client generated from `viamin/color_matching` issue #110.

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Generator/runtime and vendored document | `OpenAPIClientGenerationTests.testPackageWiresTheOpenAPIGeneratorAndRuntime` and `testVendoredUpstreamSpecDefinesEveryCompanionOperation` | Red: package wiring and vendored document are absent. |
| Generated types replace API models | `OpenAPIClientGenerationTests.testHandWrittenTransportModelsAreRemovedAfterGeneration` | Red: transport models are still declared in `APIClient.swift`. |
| Stubbed generated-client behavior | `APIClientTests` uses `MockURLProtocol`, including manifest/recent GET fixtures and capture/measurement/judgment POST fixtures. The implementation phase must migrate these calls to generated operations and add the ranked-results fixture. | Partially green for the existing hand-written transport; red for generated wiring and ranked results. |
| Contract deltas and endpoint gaps | Inspect the upstream OpenAPI source and generated `openapi.json`; record the comparison in the implementation PR description. | Human/external evidence required. |

## Upstream comparison to include in the implementation PR

The upstream spec is served dynamically at
`GET /api/v1/openapi.json` by `ColorMatchingWeb.OpenApiController`. At the
upstream `main` revision inspected for this test plan, the published schema
differs from this repository's prose contract in material ways:

- The prose manifest is rich (page, markers, printer profile, patches, and
  pairs), while the upstream `Manifest` schema currently requires only
  `schema_version`, `sheet_id`, and `capture_profile`.
- Capture creation allows both the prose nested `metadata`/`quality` form and
  a flat compatibility form. Its `iso` is an integer upstream, not the
  prose `Float`.
- Measurement upload does not require `scoring_algorithm_version`, patch
  `stats`, or `pair_scores`; pair scores accept `score`, `similarity`, or
  `distance` compatibility shapes. The prose client sends the richer shape.
- The upstream spec declares a `RankedResults` envelope with only required
  `schema_version` and `sheet_id`; the prose contract intentionally leaves
  its result fields unspecified. The app has no ranked-results API call yet.
- Recent-sheet `title` is explicitly required-but-nullable upstream, matching
  the prose response; the manifest URL is typed as a string upstream.

These are publish-time observations, not a replacement for checking the
vendored JSON revision that lands with the generated client.
