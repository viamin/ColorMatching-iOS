# Issue #5 verification plan

This test-writing PR intentionally establishes the checks before the generated
client implementation lands. The production implementation must preserve the
app's current API behavior while changing its transport types to the generated
OpenAPI client.

| Criterion | Smallest credible verification | Current evidence / expected state |
| --- | --- | --- |
| Add `swift-openapi-generator`, `swift-openapi-runtime`, and a vendored or fetched specification | `OpenAPIClientReadinessTests.testGeneratedClientDependenciesAndVendoredContractAreConfigured` | Red until `Package.swift` configures both packages and `iOS/OpenAPI/color-matching.json` is committed. |
| Generate the manifest, recent-sheets, capture, measurement, judgment, and ranked-results surfaces | `OpenAPIClientReadinessTests.testVendoredContractDeclaresEveryCompanionSurface` plus `APIClientTests` URLProtocol stubs | Red until the vendored document declares all six paths. The stubs are permanent regression coverage and do not call a live server. |
| Replace transport-owned handwritten models while retaining client-only analysis models | Inspect the generated target and the app-core adapter in the implementation PR | Human/code-review evidence required: this is an architecture constraint, not behavior a broad test can establish. |
| Exercise generated client behavior against local responses | `APIClientTests` uses `MockURLProtocol` for manifest, recent sheets, capture creation, measurement upload, and judgment upload | Permanent local-stub coverage. Add ranked-results stub coverage when that generated operation is wired into the app facade. |
| Record prose-contract deltas and endpoint gaps in the PR description | Compare `docs/color-matching-api-contract.md` to the retrieved `GET /api/v1/openapi.json` document at the pinned source revision | External evidence required. The implementation PR description must name the source revision/URL and list every delta or state that none were found. |

## PR description checklist for implementation

- State the source URL and commit or content hash used for the vendored OpenAPI
  document.
- List deltas from `docs/color-matching-api-contract.md`, including schema
  optionality, enum values, request/response field names, and endpoint paths.
- List endpoint gaps, especially whether `ranked_results` is available in the
  published spec. Do not infer this from the prose contract.
- State that all generated-client tests use local `URLProtocol` stubs and no
  live server is used by CI.
