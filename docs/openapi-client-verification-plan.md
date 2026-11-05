# OpenAPI Client Verification Plan

This is the criterion-level plan for #5. The implementation run must retain the
permanent Swift tests named below and update this record with their result at the
PR head.

| Criterion | Smallest credible verification | Current state |
| --- | --- | --- |
| Generator/runtime dependencies and a reproducible input document are present | `APIClientTests.testOpenAPIClientDependenciesAreDeclaredInPackageManifest` plus `APIClientTests.testVendoredOpenAPISpecCoversEveryAppEndpoint` | Red: neither dependency nor vendored spec exists yet. |
| Generated client supports manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` stubs exercise each generated operation; the existing capture/upload tests and the new manifest/recent tests establish the fixture style. Add the ranked-results stub when the generated operation is introduced. | Partial/red: ranked results has no app operation; the existing client is handwritten. |
| Server API types replace handwritten transport models while client-only analysis types remain | Compile the app against generated operation input/output types; inspect the diff to ensure `MeasurementCore` types remain only at the adapter boundary. | Not runnable until generated target exists. |
| Prose-contract deltas and endpoint gaps are disclosed in the PR description | Human inspection against the published OpenAPI document fetched from `GET /api/v1/openapi.json`. | Pending implementation PR. |

## Upstream evidence and deltas found before implementation

`viamin/color_matching#110` closed through commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f` and added `GET /api/v1/openapi.json`. Its router includes all six app routes.

The published schema differs from the prose contract in material ways:

- The manifest schema requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose contract claims a fuller manifest body. The app must keep its client-side analysis requirements explicit and report this schema coverage gap.
- Ranked results are specified only with `schema_version` and `sheet_id`, while the prose contract expects colors, scores, labels, capture provenance, printer profile, and algorithm version. This is an endpoint-schema gap to report, not a reason to invent app-side server models.
- Capture creation accepts both the nested `metadata` payload in the prose contract and a legacy flat payload. The spec requires fewer nested metadata fields than the prose contract.
- Measurement upload does not require `scoring_algorithm_version` at the top level, requires normalized RGB values, accepts RGB arrays/objects/JSON strings, and supports score, similarity, or distance variants. The prose contract instead mandates a top-level algorithm version, RGB objects, and stats.
- Measurements and judgments have typed response bodies in the spec; the handwritten client currently discards successful response bodies.

## Implementation handoff

Fetch and vendor the actual resolved JSON response from the provider endpoint, rather than translating the Elixir source by hand. Generate only the six paths above, then adapt generated operation inputs and outputs at the `ColorMatchingLPSAppCore` boundary. Add a local-stub ranked-results test and revise the existing six-operation stubs to instantiate generated types directly.
