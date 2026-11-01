# Issue #5: generated OpenAPI client

## Criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Package contains `swift-openapi-generator` and `swift-openapi-runtime`, and vendors or fetches the published document | Inspect `iOS/Package.swift`, generator configuration, and the pinned OpenAPI artifact in the implementation PR. | Not run: implementation is prohibited during this test-writing phase. |
| Generated client covers manifest/recent, capture creation, measurement upload, judgment upload, and ranked results | Compile the app against generated operations; retain the local-stub tests for all supported operations. | Blocked: the current app has no ranked-results client operation or UI call. |
| Hand-written API models are replaced while client-only measurement models remain | Inspect the removal of API request/response declarations in `APIClient.swift` and build the app. | Not run: implementation is prohibited during this test-writing phase. |
| Generated client works with local stubbed responses | Permanent unit tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; execute `swift test --disable-sandbox`. | Not run locally: this container has no `swift` executable. |
| PR description records contract deltas and endpoint gaps | Inspect this document (or its copied PR description) against the published spec and server response renderers. | Recorded below. |

## Published-contract comparison

Evidence was inspected from `viamin/color_matching` main at issue #110's close:

- The document is served at `GET /api/v1/openapi.json`; it is public while the app endpoints use bearer authentication.
- The generated `Manifest` schema only requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The server's renderer, and the prose contract, provide the full geometry needed by `MeasurementCore` (`page`, markers, patches, and pairs). A generated client cannot safely replace the app's manifest model until that schema is expanded.
- `CaptureRequest` accepts both a legacy flat shape and the nested `metadata` shape. The prose contract only describes the nested shape. The app's nested request conforms; the spec should make that canonical form explicit and define `quality` requirements.
- The published `CaptureMetadata.iso` is an integer, whereas the app's hand-written client models it as `Float`.
- `MeasurementUploadRequest` requires `normalized_linear_rgb_median`, but the app's client model makes it optional. It also omits the prose-only `scoring_algorithm_version` and measurement `stats` fields. The spec currently permits additional properties, so the app's existing payload may pass validation while generated request types will not include those fields.
- Measurement and judgment uploads return `200` JSON count bodies in the published spec/server; the prose contract does not specify responses and the existing tests previously used `204` empty bodies. The stubs now exercise the published `200` responses.
- Ranked results exist at `GET /api/v1/test_sheets/:sheet_id/ranked_results`, but the iOS app neither calls it nor defines a response model. Its published schema requires only `schema_version` and `sheet_id`, even though the server renderer returns ranking, scores, colors, captures, and judgments. This is the endpoint gap that must be resolved before a useful generated ranked-results type can be wired in.

## Implementation handoff

Pin a fetched copy of `/api/v1/openapi.json` and generate only the five app-facing operations. Keep `MeasurementCore`'s geometry and scoring types client-owned. Update the fixtures/tests in `APIClientTests` to call generated operations directly or through a deliberately thin adapter, then run `swift test --disable-sandbox` in an environment with Swift installed.
