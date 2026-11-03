---
module: ios-api-client
tags: [openapi, generated-client, swift, testing]
problem_type: acceptance-criterion-verification
---

# Issue #5 verification plan

This is the red-phase test plan for replacing the hand-written `/api/v1` layer.
It intentionally records the smallest credible verification for each criterion
before implementation.

| Criterion | Verification | Evidence at PR head | Red-phase status |
| --- | --- | --- | --- |
| OpenAPI dependencies and document are present | `OpenAPIAdoptionTests.testPackageDeclaresOpenAPIGeneratorAndRuntimeAgainstVendoredSpec` checks both Swift packages and the committed spec input. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIAdoptionTests.swift` | failing until implementation |
| Every app-used API surface delegates to generated operations | `OpenAPIAdoptionTests.testVendoredSpecCoversEveryAppUsedAPIOperation` checks the six required paths in the exact generated-client input. `testAPILayerUsesGeneratedClientInsteadOfHandWrittenWireModels` rejects the old public wire models. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIAdoptionTests.swift` | failing until implementation |
| Generated client behaves against local responses | `APIClientTests` uses `URLProtocol` stubs only—no live Phoenix dependency—to exercise manifest, recent sheets, capture creation, measurement upload, and judgment upload. Add ranked-results response coverage with the implementation. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | manifest/recent pass; generated-client guard fails |
| Contract deltas and endpoint gaps appear in the PR description | Human/external evidence: compare `docs/color-matching-api-contract.md` with the exact vendored response from `GET /api/v1/openapi.json`; retain the comparison in the PR body. | PR description plus vendored OpenAPI document | not automatable / not yet available in this tests-only change |

The permanent local-stub tests protect the recurring capture upload flow. The
source-boundary tests are intentionally narrow red tests: they prevent a future
implementation from satisfying transport assertions while retaining the
hand-written wire layer.
