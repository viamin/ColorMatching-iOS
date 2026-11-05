# Issue #5 OpenAPI Client Verification Plan

This is the red-phase test plan for replacing the hand-written iOS API layer. The implementation run must update this record with actual test results and the pull-request description must reproduce the contract-delta section below.

| Criterion | Smallest credible verification | Status in this test-only change |
| --- | --- | --- |
| OpenAPI generator/runtime are package dependencies and the published document is vendored | `APIClientTests.testOpenAPIClientPackageAndVendoredSpecCoverUsedEndpoints` checks `Package.swift`, reads `iOS/OpenAPI/openapi.json`, and asserts that it includes all six app-used paths. | Failing until implementation |
| Manifest and recent-sheets calls use the client against local responses | `APIClientTests.testFetchesManifestAndRecentSheetsFromLocalStubs` drives both calls through `MockURLProtocol`. | Passing against the current behavior; implementation must preserve it through generated types |
| Capture creation, measurement upload, and judgment upload use the generated client | Existing local-stub tests `testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, and `testUploadJudgmentsEncodesPathAndPayload`. | Passing against the current behavior; implementation must preserve them through generated types |
| Ranked results surface is generated and available | The vendored-spec path assertion includes `/api/v1/test_sheets/{sheet_id}/ranked_results`; implementation must add a local-stub generated-client result test once the published response schema is known. | Blocked on endpoint response shape |
| Contract deltas are recorded in the PR description | Human review of PR description against `docs/color-matching-api-contract.md` and the vendored published spec. | Not automatable |

## External-spec evidence

`viamin/color_matching#110` is closed and says the specification is served from `GET /api/v1/openapi.json`. On 2026-11-05, the repository's default branch did not contain a checked-in OpenAPI document (its recursively listed filenames contained no `openapi`, `open_api`, or `swagger` match), and this isolated environment could not resolve the presumed deployment hostname. This test change deliberately does not invent or vendor a speculative specification.

## Contract-delta checklist for the implementation PR

Compare the vendored document to `docs/color-matching-api-contract.md` and record, at minimum:

- exact operation IDs, parameter names, request/response status codes, and authentication scheme;
- JSON property names, requiredness/nullability, enum values, formats, and additional properties for all six app-used paths;
- the concrete ranked-results response schema, which the prose contract intentionally leaves unspecified;
- any omitted app-used endpoint or server-required field that blocks direct client generation;
- any compatibility adapter retained for client-only `MeasurementCore` types.
