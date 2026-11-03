# Issue #5 generated-client verification plan

This is the test-writing phase for replacing the iOS hand-written API layer with a generated OpenAPI client. The implementation phase must retain these permanent, local-stub tests; no test contacts a live server.

| Criterion | Smallest credible verification | Status in this phase |
| --- | --- | --- |
| Swift OpenAPI generator/runtime dependencies and a vendored spec | `GeneratedClientAdoptionTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` and `testVendoredOpenAPISpecDefinesEveryAppEndpoint` | Red: dependencies and spec are absent |
| Generated types replace hand-written transport/models | `GeneratedClientAdoptionTests.testAPIClientImportsGeneratedRuntimeInsteadOfHandwrittenTransport` | Red: `APIClient` owns JSON encoding/decoding |
| All app API surfaces work without a live server | `APIClientTests` URLProtocol stubs for manifest, recent sheets, capture creation, measurement upload, and judgment upload; the vendored-spec test covers ranked results until its generated operation is wired into the app | Partially red: ranked-results client operation is absent |
| Contract deltas and endpoint gaps are recorded in the PR | Human review of the PR description, based on the upstream issue and generated `/api/v1/openapi.json` | Not automatable |

## Upstream evidence and deltas to record in the implementation PR

The upstream router and issue #110 expose the six iOS endpoints, including `GET /api/v1/test_sheets/:sheet_id/ranked_results`, and serve the specification at `GET /api/v1/openapi.json`.

- The prose contract describes only a nested `metadata`/`quality` capture payload. The published schema accepts that form and a legacy flat form.
- The prose contract leaves upload responses unspecified. The published schema returns `200` JSON acknowledgments containing the capture ID and measurement/pair-score or judgment counts.
- The prose contract says ranked results should include provenance, profile, scores, and labels without defining a response. The published response is versioned `lps-ranked-results/v1` and supplies those fields.
- The published manifest schema currently makes only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` required, even though its renderer returns the fuller manifest consumed by the app. Confirm the generated model preserves the needed fields before deleting client-side manifest models.

The implementation PR description must state whether fetching the upstream JSON at build/regeneration time is sufficiently reproducible or whether a commit-pinned vendored copy is used, and must call out any remaining mismatch found by generation.
