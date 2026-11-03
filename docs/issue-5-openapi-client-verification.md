---
module: ios-api-client
tags: [openapi, generated-client, tdd]
problem_type: verification-plan
---

# Issue #5 OpenAPI client verification plan

This is the acceptance-criterion map for the generated OpenAPI client change.

| Criterion | Smallest credible verification | Evidence location | Current red-phase result |
| --- | --- | --- | --- |
| Package contains the OpenAPI generator/runtime and runs generation | Focused package-configuration test checks both dependencies and the `OpenAPIGenerator` build-tool plugin. | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedOpenAPIClientConfigurationTests.swift` | Fails until implementation wires the package/plugin. |
| Generated types replace hand-written API models | Focused source-boundary test rejects the current hand-written transport declarations. Pure measurement and camera models remain outside this check. | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedOpenAPIClientConfigurationTests.swift` | Fails until implementation removes/replaces transport models. |
| Manifest and recent-sheet reads work against local responses | Permanent Swift tests use `MockURLProtocol`; no network server is contacted. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Not run in this container because Swift is unavailable; remains the regression test after generation. |
| Capture creation, measurement upload, and judgment upload work against local responses | Existing permanent Swift tests use `MockURLProtocol` and inspect path, authorization, and encoded payloads. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Not run in this container because Swift is unavailable; remains the regression test after generation. |
| Ranked-results endpoint is wired | A permanent stub-response test will be added in the implementation phase once the provider spec's `RankedResults` response fields are generated and the app-facing result type is defined. | Provider route/spec: `GET /api/v1/test_sheets/:sheet_id/ranked_results` | Blocked in this test-only phase: the prose contract specifies no response schema. |
| Contract deltas and endpoint gaps are recorded in the PR | Human/external evidence: compare the vendored/fetched `GET /api/v1/openapi.json` document to `docs/color-matching-api-contract.md` and put the resulting list in the PR description. | PR description | Not automatable: the published spec is the external authority. |

## Provider evidence inspected on 2026-11-03

`viamin/color_matching#110` is closed. Its router publishes the document at
`GET /api/v1/openapi.json` and includes the six relevant routes: manifest,
recent sheets, capture creation, measurement upload, judgment upload, and
ranked results.

The initial gap already visible from the prose contract is ranked-results:
it names the route and broad data categories but gives no JSON response schema.
The provider's OpenAPI schema, rather than a guessed local model, must decide
the generated type and the stub fixture used by the implementation test.
