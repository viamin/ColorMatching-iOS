---
module: ios-api-client
tags: [openapi, swift, verification, issue-5]
problem_type: verification-plan
---

# Issue #5 OpenAPI client verification plan

This test-writing change maps each acceptance criterion to evidence before the
generated-client implementation begins. The provider's OpenAPI source is the
live `GET /api/v1/openapi.json` endpoint introduced by
[`viamin/color_matching#110`](https://github.com/viamin/color_matching/issues/110).
The provider builds that document from router/controller annotations, so it is
not a static file to copy from its repository.

| Criterion | Smallest credible verification | Phase status |
| --- | --- | --- |
| Generator/runtime are installed and the provider document is vendored | `OpenAPIGenerationContractTests.testPackageUsesGeneratedOpenAPIClientInsteadOfHandWrittenTransportModels`, which requires both packages, the generator plugin, and a vendored document with every used path | Red: dependencies and document are absent |
| Generated types replace server transport models | The same focused contract test rejects the current hand-written capture request/response models; endpoint stubs in `APIClientTests` remain the regression suite after the adapter is rewired | Red: hand-written types remain |
| Manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results use the generated client against local responses | Keep the existing URLProtocol stubs for writes; `testFetchManifestDecodesLocalStubResponse` and `testFetchRecentSheetsDecodesLocalStubResponse` add read stubs. Implementation must add a ranked-results stub that exercises the generated client once the published response schema is available. | Partial: five endpoint flows have local stubs; ranked results has no current app method or prose response schema |
| PR records prose-contract deltas and endpoint gaps | Human/external evidence: compare the vendored `/api/v1/openapi.json` with `docs/color-matching-api-contract.md` and include the resulting list in the PR body. The source router confirms all six app routes exist; the prose contract leaves `ranked_results` response fields unspecified. | Not yet performed: requires vendored published document |
| `swift test --disable-sandbox` is green | Run the focused suite and full package suite after generated code is wired in. The red contract test must first turn green. | Not run in this red phase |

## Known pre-implementation delta

The prose contract names `GET /api/v1/test_sheets/:sheet_id/ranked_results`
but deliberately omits a response schema. The generated client cannot provide
a typed ranked-results surface until the published document supplies that
schema. This is an endpoint-shape gap to record in the implementation PR if it
persists after fetching the provider document.
