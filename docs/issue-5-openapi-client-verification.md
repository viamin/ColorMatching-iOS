# Issue #5 OpenAPI Client Verification Plan

## Acceptance criteria

| Criterion | Smallest credible verification | Evidence at this test-writing head |
| --- | --- | --- |
| The package has generator/runtime dependencies and a reproducible OpenAPI input. | Focused XCTest reads the package manifest and vendored spec, and asserts the six app routes occur in the document. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testPackageConfiguresGeneratedClientFromVendoredOpenAPISpec` (red until implementation). |
| The client supports manifest and recent-sheet reads using generated schemas. | A permanent URLProtocol-backed XCTest decodes local JSON stubs. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testFetchesManifestAndRecentSheetsFromLocalStubbedResponses`. |
| The client supports capture creation, measurement upload, and judgment upload using generated schemas. | Permanent URLProtocol-backed request/response tests, with no network server. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, and `testUploadJudgmentsEncodesPathAndPayload`. |
| The client supports ranked results. | The vendored-spec guard requires the ranked-results route; implementation must add a URLProtocol response test when the generated operation/type names are known. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testPackageConfiguresGeneratedClientFromVendoredOpenAPISpec` (red). |
| The PR describes prose-contract deltas and endpoint gaps. | Human review of this document, updated from the exact vendored `openapi.json`; automated tests cannot establish a contract comparison. | Not yet run: the published JSON is served dynamically by `GET /api/v1/openapi.json` and is not available as a checked-in artifact in the upstream repository. |

## Upstream evidence and deltas to verify during implementation

`viamin/color_matching#110` is closed and its router exposes all six iOS routes, including the prose contract's previously underspecified `GET /api/v1/test_sheets/:sheet_id/ranked_results`. Its OpenAPI endpoint is `GET /api/v1/openapi.json`.

The current prose contract describes ranked results only in narrative form; it has no response schema. The generated client migration must therefore record the published ranked-results response shape as a contract delta. The prose manifest example also contains `created_at`, `printer_profile`, and `capture_profile`, while the current local `SheetManifest` transport model does not decode them. Whether those fields are required, optional, or absent in the published schema must be recorded after vendoring the actual JSON.

No live server is used by the permanent client tests. The committed test suite intercepts requests using `URLProtocol` and returns local response data.
