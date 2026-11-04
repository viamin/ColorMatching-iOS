# OpenAPI client migration verification plan

This record is the test-plan and PR-description source for issue #5. It is
intentionally committed with the tests so the implementation run has an
inspectable definition of done.

| Criterion | Smallest credible verification | Evidence at this head |
| --- | --- | --- |
| Generated client replaces app API models for manifest, sheets, capture, measurements, judgments, and results | Compile the app against generated operation and component types; use protocol-stubbed Swift tests for every used operation. | Not yet runnable: no generated package or provider OpenAPI document is in this repository. |
| Manifest and recent-sheet operations preserve the app flow | Permanent unit/service tests with local `URLProtocol` responses prove request paths, auth, and decoding. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testFetchManifestDecodesStubbedSheet`, `testFetchRecentSheetsDecodesStubbedSheets`). |
| Capture creation, measurement upload, and judgment upload preserve the app flow | Permanent unit/service tests with local `URLProtocol` responses prove the request body and response handling. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload`). |
| Ranked results is available through the generated client | Permanent unit/service test that sends a local stubbed ranked-results response through the generated operation and asserts its decoded fields. | Deliberate red test: `testFetchRankedResultsIsSupportedByTheGeneratedClient`. |
| Contract deltas and endpoint gaps are in the PR description | Human/external evidence: compare the vendored/fetched OpenAPI document revision to `docs/color-matching-api-contract.md`; link that revision and list deltas in the PR body. | Blocked pending a retrievable provider OpenAPI document. |

## Provider evidence checked on 2026-11-04

`viamin/color_matching#110` is closed and states that the API specification is
served from `GET /api/v1/openapi.json`. Its public repository tree contains no
OpenAPI or Swagger document, and the likely public host was not resolvable from
this run. The implementation run must fetch the live document or vendor an
immutable provider revision before adding `swift-openapi-generator`.

## Known contract gaps to record in the PR

- The prose contract specifies `GET /api/v1/test_sheets/:sheet_id/ranked_results`
  but gives no response schema. A generated operation cannot provide a useful
  typed response until the provider spec supplies its response component.
- The prose says the ranked response includes source colors, scores, labels,
  capture provenance, printer profile, and algorithm version, but does not
  identify required fields, nullable fields, list nesting, or status codes.
- The provider issue says its OpenAPI surface covers every `/api/v1` route and
  two additional `/api` POST routes. This client only needs the listed
  test-sheet/capture operations; the implementation PR must state whether the
  published document's operation IDs and schemas match those paths.

## Implementation handoff

Replace the red ranked-results test with a `URLProtocol` stub response test as
soon as the provider response schema is available. Keep these tests permanent:
they cover the companion's recurring sheet selection and capture upload flow,
and must be rewritten to instantiate generated types rather than the current
hand-written API models.
