# Issue #5 OpenAPI client verification plan

This test-writing change establishes the smallest credible verification for
replacing the iOS hand-written API layer with the published OpenAPI client.
The implementation phase must vendor or fetch the upstream document from
`GET /api/v1/openapi.json`, generate the Swift client, and run these tests
without contacting a live service.

| Criterion | Verification | Evidence at PR head |
| --- | --- | --- |
| Generator and runtime are package dependencies | Focused unit test scans `iOS/Package.swift` for both packages. It is intentionally red until the implementation adds them. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientIntegrationTests.swift:testPackageDeclaresOpenAPIGeneratorAndRuntime` |
| Manifest and recent-sheet operations decode local published-contract stubs | Permanent client integration tests using `MockURLProtocol`. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testFetchManifestDecodesPublishedManifestStub`; `testFetchRecentSheetsDecodesPublishedRecentSheetsStub` |
| Capture creation, measurement upload, and judgment upload use local stubs | Permanent client integration tests using `MockURLProtocol`; upload stubs use the published `200` JSON acknowledgements. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testCreateCaptureEncodesMetadataAndQuality`; `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`; `testUploadJudgmentsEncodesPathAndPayload` |
| Ranked-result response is represented | Focused stub-shape test. The implementation phase must replace this boundary fixture with a generated-client invocation. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientIntegrationTests.swift:testRankedResultsStubContainsPublishedResponseShape` |
| Contract deltas are recorded in the PR | Inspectable external evidence: compare `docs/color-matching-api-contract.md` with `viamin/color_matching` issue #110's served `/api/v1/openapi.json`. | PR description before merge |

## Published-contract deltas found

- `GET /api/v1/test_sheets/:sheet_id/ranked_results` is now specified with
  the `lps-ranked-results/v1` response, whereas the prose contract supplied
  no schema.
- Manifest printer profiles use `printer_make_model`, `paper_type`, and
  `ink_type`; the prose example instead described `id`, `name`, `paper`,
  `ink`, and `settings`.
- Measurement and judgment uploads return `200` JSON acknowledgement bodies
  (`capture_id` plus accepted counts), rather than the prose contract's
  unspecified empty response.
- Capture creation accepts the nested `metadata`/`quality` shape used by the
  iOS app and also a legacy flat request shape. The iOS client should generate
  against the documented schema and retain the nested shape.

## Endpoint gap

No endpoint gap was found for the six iOS surfaces in this issue. The
implementation still needs to check generated operation names and response
types against the exact vendored OpenAPI artifact, because the upstream spec
is served dynamically rather than committed as a standalone JSON file.
