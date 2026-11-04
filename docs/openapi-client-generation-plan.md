# Generated OpenAPI client plan

This test-only change maps issue #5's acceptance criteria to the smallest
credible verification. The implementation run must vendor or fetch the
published `GET /api/v1/openapi.json` document and generate the client from that
exact input; local stub tests must continue to use the generated-client-backed
facade, never a live Phoenix server.

| Criterion | Verification | Evidence at this PR head |
| --- | --- | --- |
| Generated client exposes manifest and recent-sheet discovery | Permanent focused client test using `MockURLProtocol` | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testFetchManifestDecodesLocalStubResponse`, `testFetchRecentSheetsDecodesLocalStubResponse` |
| Generated client creates captures and uploads measurements and judgments | Permanent focused client test using `MockURLProtocol` | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload` |
| Generated client exposes ranked results | Permanent focused client test using `MockURLProtocol` | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testFetchRankedResultsDecodesLocalStubResponse` (red: endpoint and type do not exist) |
| `swift-openapi-generator` and runtime are wired into SwiftPM; generated types replace remote models | Build and the focused client test suite | Not runnable in this container: Swift is not installed. |
| Published-spec / prose-contract deltas are recorded | Inspectable external evidence, compared against `viamin/color_matching` main at issue #110 / PR #113 | Deltas below |

## Published-spec deltas and endpoint gaps

The upstream OpenAPI document is served dynamically by
`ColorMatchingWeb.OpenApiController` at `/api/v1/openapi.json`; it is not a
static repository artifact. The source contract reviewed here is the merged
upstream PR [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113),
which closed #110.

- The manifest schema declares only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`. The actual manifest response and
  the iOS analyzer require `sheet_version`, `manifest_url`, page geometry,
  registration markers, patches, and pairs. Generating directly from the
  published schema therefore cannot replace the app's manifest decoding until
  upstream models those fields.
- The ranked-results schema declares only `schema_version` and `sheet_id`.
  The endpoint response additionally contains profile, capture provenance,
  algorithm versions, ordered pair results, source colors, scores, and
  judgments. The new red test intentionally covers only the two fields the
  published schema can presently generate.
- The prose contract requires `scoring_algorithm_version` and measurement
  `stats`. The published measurement-upload schema does not describe either,
  although it does describe `measurements` and compatibility score fields.
  Sending the current scoring payload via generated types would discard or
  require hand-written extensions for those fields.
- The prose contract treated successful measurement and judgment uploads as
  bodyless. The published spec documents `200` JSON responses with capture and
  row counts. The app can continue to ignore these responses without changing
  capture/scoring behavior, but generated operation output must accept them.
- The published capture request supports the prose contract's nested
  `metadata` / `quality` payload, while also documenting a legacy flat shape.
  Its `iso` is an integer, versus the current iOS `Float`; conversion is needed
  if the generated request type is used directly.

## Implementation handoff

The implementation must add `swift-openapi-generator` and
`swift-openapi-runtime`, pin the fetched/vendored document, generate only the
six operations covered above, and make `APIClient` delegate to the generated
client. `MeasurementCore` analysis models remain client-side; remote request
and response shapes must come from generated types. The upstream schema gaps
above require either upstream schema expansion or explicitly scoped adapter
types documented in the implementation PR description.
