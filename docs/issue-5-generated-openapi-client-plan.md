---
module: ios-api
tags: [openapi, generated-client, testing]
problem_type: implementation-plan
---

# Issue #5 generated OpenAPI client: acceptance plan

This is the red-phase test plan for replacing the hand-written `/api/v1` client.
It deliberately does not change production code or vendor the server document.

| Criterion | Smallest credible verification | Current evidence / state |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor or fetch the document | A package test fails until `OpenAPIRuntime` is linked; implementation review must inspect the `Package.swift` plugin/dependency and committed/fetched spec location. | `APIClientTests.testOpenAPIRuntimeIsAvailableForTheGeneratedClient`; failing red phase. |
| Generate and wire manifest, recent-sheet, capture, measurements, judgments, and ranked-results surfaces | Local `URLProtocol` stubs assert operation requests and decode responses. Keep these as permanent regression tests; add ranked-results response coverage once its published response schema is available. | Manifest and recent-sheet coverage added; existing tests cover capture, measurements, and judgments. Ranked-results remains blocked by the unavailable published response schema. |
| Replace hand-written API models while retaining client-side models | Inspect the implementation diff: generated OpenAPI types must own wire schemas; `MeasurementCore` analysis-only models remain. Compile validates generated API names. | Not runnable in this tests-only phase. |
| No-live-server Swift tests | Run `swift test --disable-sandbox`; tests use `MockURLProtocol` exclusively. | Not runnable here: the container has no `swift` executable. |
| Record prose-contract deltas and endpoint gaps | Compare `docs/color-matching-api-contract.md` with the fetched `/api/v1/openapi.json`, pin the source revision, and put the results in the PR description. | External evidence is incomplete: GitHub issue #110 is closed, but its repository tree contains no vendored spec and the deployment host is not discoverable from the repository. |

## PR description draft for the implementation run

### What changed

- Replace manual `Codable` request/response wire types in `APIClient` with the generated OpenAPI client.
- Use the published spec from `viamin/color_matching#110`, with its source URL and revision recorded here.
- Preserve `MeasurementCore` domain models used only for camera analysis and scoring.

### Contract deltas and endpoint gaps

To be completed against the fetched document, not inferred from the prose contract. The known gap is that the prose contract names `GET /api/v1/test_sheets/:sheet_id/ranked_results` but gives no response schema, so a typed ranked-results test cannot be authored credibly until the document is retrieved. Record every required/optional field, enum, date format, status code, and endpoint discrepancy found in the published document.

### Verification

- `swift test --disable-sandbox` against `MockURLProtocol` stubs only; no live service.
- Confirm the generated package compiles and that the handwritten transport and wire models are deleted.
