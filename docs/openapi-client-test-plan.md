---
module: ios
tags: [openapi, swift, api-client, testing]
problem_type: test-plan
---

# Generated OpenAPI client: acceptance evidence plan

This is the test-writing evidence for #5. The generated client implementation is deliberately not included in this phase.

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Generator/runtime dependencies and a vendored published spec | `OpenAPIClientAdoptionTests.testPackagePinsOpenAPIGeneratorAndRuntimeAndVendorsTheServerSpec` asserts both package dependencies and all six required paths in `iOS/OpenAPI/color_matching.openapi.json`. | Red: neither dependencies nor spec are present. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | The same adoption guard verifies the six spec paths. The implementation phase must replace the file-content checks with generated-type compilation checks once the generated module name is known. | Red: spec is absent; ranked-results has no app client method today. |
| Generated client operates against local stubs | `APIClientTests` uses `MockURLProtocol` (no live service) for manifest, recent sheets, capture creation, measurement upload, and judgment upload. Add ranked-results coverage when the generated operation is wired in. | Existing five-surface tests are runnable only where Swift is installed. |
| Contract deltas and endpoint gaps in the PR description | Human review of this document's delta record against the vendored `/api/v1/openapi.json` snapshot. | Pending implementation/spec snapshot. |

## Observed contract deltas from `viamin/color_matching` #113

The server-side OpenAPI work landed in [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113), which closes #110. Its machine-readable document is served at `GET /api/v1/openapi.json`; the implementation phase must vendor that rendered document rather than reconstruct it from server source.

- Capture metadata accepts nested `metadata`/`quality` (as the prose contract describes), but the published schema also retains a flat compatibility request shape and names the flat exposure property `exposure_duration`, not `exposure_duration_seconds`.
- Measurement uploads do not require the prose contract's top-level `scoring_algorithm_version`; their RGB fields accept an array, `{r,g,b}` object, or JSON-encoded string. The server response is a structured count response rather than the prose contract's undocumented `204` assumption.
- Pair scores permit `score`, `similarity`, or `distance`, provided with `pair_id` and `algorithm_version`.
- The server's manifest OpenAPI schema guarantees only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the app currently relies on additional geometry fields. Confirm the rendered spec includes the full controller response shape before generated model replacement.
- Ranked results are now represented by `lps-ranked-results/v1`, but the present iOS client never calls the documented ranked-results endpoint. This is an endpoint gap that must be resolved (wire it in or explicitly remove it from the requested scope) during implementation.
