---
module: ios-api-client
tags: [openapi, swift, generated-client, testing]
problem_type: verification-plan
---

# Issue #5 generated OpenAPI client verification plan

This is the criterion-level plan for the tests-first change. It is intentionally
committed with the red tests so the implementation PR has an inspectable target.

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Generator, runtime, and published specification are committed | `APIClientTests.testOpenAPIClientInputsDeclareEveryConsumedOperation` checks package dependencies, the vendored document, and required OpenAPI operations. | Red: no dependencies or vendored spec exist. |
| Every consumed HTTP surface is represented | The same test checks manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results paths and methods. | Red: no vendored spec exists. |
| Generated client handles local server responses | `APIClientTests` uses `MockURLProtocol` to exercise manifest, recent sheets, capture creation, measurement upload, and judgment upload without a live server. The implementation must route these tests through the generated client. | Existing tests pass against the handwritten client; convert their imports/types as part of implementation. |
| Handwritten API transport models are removed while client-only models remain | Human code review of `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift` and the generated source at the PR head. | Not automatable from behavior alone; record the reviewed result in the PR description. |
| Contract differences and endpoint gaps are recorded | Human/external evidence: compare `docs/color-matching-api-contract.md` with the exact vendored upstream `/api/v1/openapi.json` revision and include the findings in the PR description. | Not run: this requires the exact downloaded specification. |

The tests are permanent focused unit/service tests because HTTP serialization and
response decoding are a recurring integration boundary. They use in-process URL
protocol stubs; no live Phoenix server or database is needed.
