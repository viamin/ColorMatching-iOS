# OpenAPI client migration verification plan

This is the PR-description evidence for issue #5. It is intentionally kept with the code so regeneration work can revisit the same contract decisions.

## Acceptance criteria and verification

| Criterion | Smallest credible verification | Location |
| --- | --- | --- |
| The package generates a typed client from the published document | A focused test verifies the generator/runtime dependencies, vendored OpenAPI 3 document, and every required path. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testPackageConfiguresGeneratedClientFromVendoredOpenAPIDocument` |
| Manifest and recent-sheet responses remain usable through the client | Permanent local `URLProtocol` stubs decode published response shapes. | `APIClientTests.swift:testFetchManifestDecodesPublishedManifestResponse`, `testFetchRecentSheetsDecodesPublishedRecentSheetsResponse` |
| Capture creation and both uploads remain usable through the client | Permanent local `URLProtocol` stubs assert request content and published `200` acknowledgement responses. | `APIClientTests.swift:testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsUsesPublishedRequestShape`, `testUploadJudgmentsEncodesPathAndPayload` |
| Ranked-results path is included in generated coverage | The vendored-document test asserts the path is present. The app does not presently call this endpoint, so a response adapter test is deferred until it has a consumer. | `APIClientTests.swift:testPackageConfiguresGeneratedClientFromVendoredOpenAPIDocument` |

No live Phoenix server is involved: `MockURLProtocol` supplies each response.

## Contract deltas found against the published spec

The source compared was `viamin/color_matching` main after #110, whose server exposes `GET /api/v1/openapi.json`.

- Measurement and judgment uploads return `200` JSON acknowledgement bodies (`capture_id` plus counts). The prose contract omitted response bodies, and the old tests modeled them as `204`.
- The published measurement request has `measurements` and `pair_scores`; it does not declare the prose contract's top-level `scoring_algorithm_version` or per-measurement `stats`. A pair score requires `pair_id`, `algorithm_version`, and one of `score`, `similarity`, or `distance`.
- Capture creation accepts the nested prose shape, but the published spec also accepts a legacy flat payload. Its nested metadata requires image dimensions, whereas the prose described them as optional. The spec does not require a quality object.
- The published spec permits arbitrary judgment strings; the prose limits them to `match`, `near_match`, and `no_match`.
- The published manifest schema currently declares only `schema_version`, `sheet_id`, and `capture_profile` as required. The server renderer and iOS app rely on a fuller manifest payload.
- Ranked-results is now represented by a path and response schema (`lps-ranked-results/v1`), but that schema only requires `schema_version` and `sheet_id`; the renderer returns substantially richer ranking data. The iOS app currently ranks locally and has no caller for the endpoint.

## Endpoint gaps

All six issue-required paths are present in the published API. There is no app consumer for ranked results today, so generation can cover it while the UI remains unchanged. The under-specified manifest and ranked-results response schemas should be tightened upstream before relying on generated required-field guarantees for those fields.
