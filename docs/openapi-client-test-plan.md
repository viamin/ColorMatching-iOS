# OpenAPI client acceptance plan

This is the implementation-run and PR-description source for issue #5. The
implementation must vendor the published document at
`iOS/OpenAPI/color-matching-api.json`, generate a typed `ColorMatchingAPI`
target from it, and make `ColorMatchingLPSAppCore` use that target for server
types. Measurement and camera-analysis types remain client-side.

## Criterion map

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generated client dependency and vendored document | Unit contract test checks the vendored machine-readable document has every consumed operation. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` |
| Manifest and recent sheets | Permanent local-URLProtocol stub tests decode both responses without a live server. | `APIClientTests.testFetchManifestDecodesLocalStubbedResponse`, `testFetchRecentSheetsDecodesLocalStubbedResponse` |
| Capture creation, measurement upload, and judgment upload | Permanent local-URLProtocol stub tests assert request route and JSON payload. | `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload` |
| Ranked results | Contract test requires the published route; implementation must add a local-stub decoding test when the generated response type is wired into the app. | `OpenAPIContractTests.testVendoredOpenAPIDocumentCoversEveryIOSOperation` |
| No live server in CI | All API behavior tests use `MockURLProtocol`. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |

## Contract deltas found from upstream #110

Evidence was read from upstream `main` on 2026-11-04: its router exposes the
six routes above and `GET /api/v1/openapi.json`; `ApiSchemas` is the source
used to render that document.

- The prose manifest requires layout fields (`sheet_version`, `manifest_url`,
  page, markers, patches, and pairs). The published `Manifest` schema only
  requires `schema_version`, `sheet_id`, and `capture_profile`; it is too weak
  to generate the iOS manifest model safely.
- The prose ranked-results description promises source colors, scores, labels,
  capture provenance, printer profile, and algorithm version. The published
  `RankedResults` schema only declares `schema_version` and `sheet_id`.
- The prose says measurement and judgment uploads return no body. The published
  specification declares structured measurement and judgment upload responses.
- The prose requires `scoring_algorithm_version` at the measurement-upload
  top level and detailed statistics. The published upload schema does not
  require that field or statistics, while pair scores allow `score`,
  `similarity`, or `distance` compatibility forms.
- Capture creation accepts both the prose nested `metadata`/`quality` form and
  a legacy flattened payload. Its published metadata schema makes image size
  required and defines ISO as an integer, unlike the app's current optional
  floating-point value.

These are endpoint/schema gaps, not permission to change capture or scoring
behavior. Resolve them upstream or record an explicit generated-client adapter
before merging the implementation PR.
