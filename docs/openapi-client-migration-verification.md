# OpenAPI client migration verification

This is the red-phase verification plan for issue #5. Implementation must replace the
explicit red test below with generated-client coverage before this document can report a
passing migration.

| Criterion | Smallest credible verification | Current red-phase evidence |
| --- | --- | --- |
| Generated Swift client is added and app API models are replaced | Compile `ColorMatchingLPSAppCore` against the generated client and run local-stub XCTest coverage. | Not run: dependencies and generated source do not exist yet. |
| Manifest and recent-sheet operations use generated types | Permanent local-stub unit tests assert endpoint, bearer auth, and decoded values. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` tests `testFetchManifestDecodesPublishedManifestFromLocalStub` and `testFetchRecentSheetsDecodesPublishedResponseFromLocalStub`. They currently exercise the hand-written client and must be rewired in implementation. |
| Capture creation, measurement upload, and judgment upload use generated types | Permanent local-stub unit tests assert requests and decoded responses. | Existing tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; implementation must retain their assertions while switching the transport/types. |
| Ranked-results operation uses generated types | Permanent local-stub test invokes the generated ranked-results operation and decodes a representative response. | `testRankedResultsRequiresTheGeneratedClientSurface` intentionally fails until that operation exists; it must be replaced with a real stubbed-response test. |
| Prose contract deltas and endpoint gaps are captured in the PR | Inspect the upstream published spec and source controller evidence; this cannot be established by a Swift test. | See “Published-spec comparison” below. |

## Published-spec comparison

Evidence was inspected from `viamin/color_matching` issue #110 and its `main` branch on
2026-11-04. The OpenAPI endpoint is routed at `GET /api/v1/openapi.json`.

The published schema and the prose contract differ in ways that block a faithful generated
client for the iOS flow:

- `TestSheetManifest` requires only `schema_version`, `sheet_id`, and `capture_profile`.
  The app requires page geometry, registration markers, patches, and pairs to analyze a
  sheet. The server renderer emits those fields, but they are absent from the published
  schema, so a generated type cannot safely expose them.
- `RankedResults` requires only `schema_version` and `sheet_id`; its result rows, scores,
  provenance, printer profile, and judgments are not modeled even though the renderer emits
  them.
- The prose contract documents nested `metadata` and `quality` for capture creation. The
  OpenAPI schema accepts both that nested form and a legacy flattened form.
- The prose contract models `pair_scores` with `distance` and `similarity`; the OpenAPI
  schema additionally permits a `score` field and requires `algorithm_version`, but does not
  model the prose `scoring_algorithm_version` or measurement statistics.
- Unlike the prose contract’s empty-success examples, measurement and judgment uploads return
  JSON counts in the published schema.

Implementation is blocked from replacing the hand-written manifest and ranked-results models
without either upstream schema completion or an explicit, reviewed compatibility layer. This
is external evidence, not a passing automated criterion.
