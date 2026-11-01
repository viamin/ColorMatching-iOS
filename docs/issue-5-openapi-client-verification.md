# Issue #5 OpenAPI client verification plan

This test-writing change records the smallest verification for each acceptance
criterion. The generated-client behavior remains red until the dependency
issue (`viamin/color_matching#110`) supplies a machine-readable specification.

| Criterion | Verification | Evidence at implementation time |
| --- | --- | --- |
| Generator/runtime and vendored OpenAPI document | Focused package/spec test | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientGenerationTests.swift` |
| All six app API surfaces are described | Focused spec coverage test | `OpenAPIClientGenerationTests.testVendoredSpecificationCoversEveryCompanionAPISurface` |
| Hand-written transport models are replaced | Focused architecture regression test | `OpenAPIClientGenerationTests.testHandWrittenTransportModelsAreRemovedAfterGeneration` |
| Generated client handles local stub responses | Permanent Swift unit tests using `MockURLProtocol` | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Contract deltas and endpoint gaps | Human/external evidence: compare the committed upstream OpenAPI source with `docs/color-matching-api-contract.md` and include the result in the PR body | PR description |

## Current external-evidence status

On 2026-11-01, GitHub's public API returned HTTP 404 for
`viamin/color_matching` pull request 110 from this environment. The actual
published document is therefore unavailable for comparison in this test phase.
The implementation PR must record its source URL/commit and the resulting
contract deltas; this cannot be inferred from the prose contract.
