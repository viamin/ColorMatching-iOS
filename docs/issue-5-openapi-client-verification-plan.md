---
module: "iOS"
tags:
  - "openapi"
  - "swift"
  - "api-client"
problem_type: "test_plan"
---

# Issue #5 generated OpenAPI client verification plan

This tests-only change establishes the smallest credible verification for each acceptance criterion before the generated-client implementation is added.

| Criterion | Verification | Evidence at this PR head | Status in this phase |
| --- | --- | --- | --- |
| Generator/runtime dependencies and generated target are configured | Focused unit/configuration test reads the Swift package manifest for `swift-openapi-generator`, `swift-openapi-runtime`, `OpenAPIGenerator`, and `OpenAPIRuntime` | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientConfigurationTests.swift` | Expected red: packages and target do not exist yet. |
| Manifest and recent-sheets reads use the generated client | Permanent offline integration tests use `URLProtocol` stubbed API responses | `APIClientTests.testFetchManifestDecodesStubbedResponse`, `APIClientTests.testFetchRecentSheetsDecodesStubbedResponse` | Green against the existing client; the implementation must retain these observable contracts while routing through generated types. |
| Capture creation, measurement upload, and judgment upload use the generated client | Permanent offline integration tests use `URLProtocol` and assert requests and payloads | `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload` | Green against the existing client; the implementation must retain these observable contracts while routing through generated types. |
| Ranked-results surface is generated and wired | Permanent offline stubbed-response test | Not yet possible: no OpenAPI document or ranked-results API method is present in this repository. | Blocked on `viamin/color_matching#110`; add when its response schema is available. |
| Contract deltas and endpoint gaps are recorded in the PR description | Inspect the published OpenAPI document and compare it to `docs/color-matching-api-contract.md` | External/human evidence required. `viamin/color_matching#110` is closed, but neither its repository tree nor this checkout carries a fetchable OpenAPI document or deployment URL. | Not run. |
| Full Swift test suite passes with generated types | `swift test --disable-sandbox` | Run in the implementation phase after package resolution and generated source are present. | Not run. |

The generated-client configuration test is intentionally red in this phase: it prevents the follow-up implementation from replacing behavior while omitting the generator/runtime dependency or a distinct generated client target. The request/response tests use a local protocol stub, never a live Phoenix server.
