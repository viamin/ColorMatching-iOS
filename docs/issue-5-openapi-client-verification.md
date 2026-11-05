# Issue #5 OpenAPI-client verification plan

This is the test-writing evidence for replacing the iOS hand-written API
models with an OpenAPI-generated client.  The production implementation is
intentionally not part of this red-phase change.

| Acceptance criterion | Smallest credible verification | Evidence at this revision |
| --- | --- | --- |
| The generated client handles the manifest and recent-sheet reads | Permanent local-stub XCTest decodes representative published response shapes and asserts each request path and bearer authorization. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testFetchManifestDecodesPublishedSheetResponse`, `testFetchRecentSheetsDecodesPublishedRecentSheetResponse` |
| The generated client handles capture creation, measurement upload, and judgment upload | Permanent local-stub XCTest asserts request paths and wire payloads for each write. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload` |
| The generated client handles ranked results | Permanent local-stub XCTest for the generated ranked-results operation, including the response body from the fetched OpenAPI document. | Not written: the current app has no ranked-results call or model, and the document is not vendored or available from a deployed base URL in this checkout. |
| `swift-openapi-generator` and `swift-openapi-runtime` are added, and generated types replace server models | Build verification after the package dependency, OpenAPI document, generated source, and adapter have landed. | Not applicable in this tests-only phase. |
| Contract deltas and endpoint gaps are recorded in the PR | Human/external review of the JSON served by the deployed Phoenix application, compared with `docs/color-matching-api-contract.md`. | Upstream issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) is closed; its source router exposes `GET /api/v1/openapi.json` and all six sheet/capture routes. The runtime JSON could not be fetched because no deployed server base URL or vendored document is supplied here. |

## Known gap for the implementation PR

The prose contract defines `GET /api/v1/test_sheets/:sheet_id/ranked_results`,
but `ColorMatchingLPSAppCore.APIClient` and the UI do not currently expose or
call it.  The implementation must decide whether to add the generated
operation to the app-facing adapter or record it as an intentionally unused
server surface; it must not claim local stub coverage until a response schema
is taken from the published OpenAPI document.
