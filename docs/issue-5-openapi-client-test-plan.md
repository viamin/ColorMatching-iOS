# Issue #5: generated OpenAPI client test plan

This is the red-phase test plan for replacing the iOS hand-written API layer. The server-side dependency is merged as [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113), which closes [#110](https://github.com/viamin/color_matching/issues/110).

## Criterion verification plan

| Criterion | Smallest credible verification | Status in this test-writing change |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor or fetch the OpenAPI document | Inspect `iOS/Package.swift` and the checked-in OpenAPI input; compile the generated target. | Not run — implementation change is outside the test-writing boundary. |
| Generate the manifest, recent-sheet, capture, measurement, judgment, and ranked-results surfaces | Permanent local-stub XCTest exercises each generated operation and decodes a representative response. | Red — the current client has no ranked-results operation; see `APIClientTests.testFetchRankedResultsUsesGeneratedOperationThroughLocalStub`. |
| Replace hand-written API models while retaining client-only models | Compile the app and inspect that generated API types replace API transport models, while `MeasurementCore` analysis types remain. | Not run — implementation change is outside the test-writing boundary. |
| Swift tests use local stubbed responses | Permanent XCTest uses `MockURLProtocol`, so no test requires a live server. | Partial — manifest and recent-sheet discovery have local stub coverage; existing tests cover capture, measurement, and judgment. |
| Record prose-contract versus OpenAPI deltas and endpoint gaps | This document records the external comparison against the server’s published OpenAPI source at the merge of #113. A human should review the final PR description. | Recorded below; final PR description remains human/external evidence. |
| `swift test --disable-sandbox` is green | Run the command after generated-client implementation. | Not run in red phase. |

## Published-contract deltas and gaps

The upstream endpoint is `GET /api/v1/openapi.json`; its source is `ColorMatchingWeb.ApiSpec` and the schemas merged in #113.

- The prose manifest contract describes the full manifest used by `MeasurementCore` (geometry, markers, patches, and pairs). The published `Manifest` schema requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. A generated model from that schema cannot type the fields the app needs to analyze a sheet. The manifest schema needs to be completed before replacing `SheetManifest` transport decoding.
- The prose ranked-results section gives only a narrative response shape. The published `RankedResults` schema similarly guarantees only `schema_version` and `sheet_id`, although the server renderer emits richer result data. The app currently has no ranked-results request, so this is both an endpoint-integration gap and an underspecified generated model.
- The current client posts `scoring_algorithm_version` and measurement `stats`; published `MeasurementUploadRequest` documents only `measurements` and `pair_scores`, and each measurement requires `normalized_linear_rgb_median`. The adapter must either produce the documented shape (including non-nil normalized values) or the upstream spec must be expanded to describe supported fields.
- The current client’s nested `{metadata, quality}` capture form is allowed by the published `CaptureRequest`, but the spec also allows a flattened legacy form through `anyOf`. Confirm the Swift generator’s representation of that union before choosing the generated call interface.
- Published capture upload responses are `200` JSON response objects with counts; the prose contract and current tests model successful measurement and judgment uploads as empty `204` responses. The generated client must decode the actual response bodies.
- `RecentSheetsResponse.title` is required but nullable in the published schema, matching the prose contract. `manifest_url` is only a string in the spec, rather than a URI-formatted field.
