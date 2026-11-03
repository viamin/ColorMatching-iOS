# Issue #5 verification plan

This is the tests-only phase. The implementation phase must make the red package-and-contract test pass and preserve the stubbed endpoint tests.

| Criterion | Smallest credible verification | Evidence at this phase |
| --- | --- | --- |
| Add generator/runtime and vendor the document | Focused XCTest checks the package declares both dependencies and that the vendored document exists. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIIntegrationTests.swift` (red until implemented) |
| Generate and wire used surfaces | Local `URLProtocol` stubs cover manifest, recent sheets, capture creation, measurement upload, and judgment upload. Ranked results needs a new generated-client invocation and stub in the implementation phase. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Replace hand-written API models | Inspect the implementation diff: API transport schemas must be generated; MeasurementCore image-analysis models remain client-side. | Human code review after implementation |
| Test generated client without a live server | The permanent XCTest suite uses `MockURLProtocol`; no network service is required. | `iOS/Tests/ColorMatchingLPSAppTests` |
| Record contract deltas and endpoint gaps | Compare the published spec endpoint schemas to `docs/color-matching-api-contract.md`; a reviewer confirms the final PR description. | This document, then PR description |

## Contract deltas found from the published API implementation

- Measurement and judgment uploads return `200` JSON acknowledgment bodies containing `capture_id` and counts. The prose contract specified `204` with no response body.
- Ranked results are an explicitly typed `200` response in the published API. The prose contract only described its contents and did not give a schema; it needs generated types and a response-stub test.
- The published API declares bearer authentication and structured `401`, `404`, and `422` error responses. The prose contract only describes the bearer header.
- The manifest schema has server-owned fields such as `created_at`, printer profile, and capture profile. Current image analysis can continue to use its client-side projection unless UI behavior starts consuming those fields.
