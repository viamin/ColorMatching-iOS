# Issue #5 verification plan

This is the tests-only phase for issue #5. The implementation phase must wire
these local `URLProtocol` stubs to the generated OpenAPI client; no live Phoenix
service is used by the Swift suite.

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Generated client is present and replaces API transport models | Compile `ColorMatchingLPSAppCore` with generated operation types and run the focused client tests | Not run: the package has no generator/runtime dependency or generated source in this tests-only commit. |
| Manifest and recent-sheets reads work | Permanent `APIClientTests` local-stub response decoding tests | `testFetchManifestDecodesPublishedManifestThroughAuthorizedClient`; `testFetchRecentSheetsDecodesPublishedResponseThroughAuthorizedClient` |
| Capture creation, measurement upload, and judgment upload work | Permanent `APIClientTests` local-stub request/response tests | `testCreateCaptureEncodesMetadataAndQuality`; `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`; `testUploadJudgmentsEncodesPathAndPayload` |
| Ranked results is generated and usable | Add a typed generated-client local-stub test once the app decides where it consumes ranked results | Not run: no ranked-results client method or app consumer exists at this PR head. |
| Prose-contract differences are recorded | Inspect the published OpenAPI endpoint and compare it with the prose contract | External evidence recorded below; final PR description must retain the deltas. |

## Published-contract observations

`viamin/color_matching#110` is closed and the checked-out upstream revision
`47057afd58f7d46b4d4b740ca7d2d08947774471` defines
`GET /api/v1/openapi.json` through `ColorMatchingWeb.OpenApiController`.

Compared with `docs/color-matching-api-contract.md`:

- The published capture upload endpoints return `200` JSON summaries
  (`capture_id` plus counts), not the undocumented `204` assumed by the former
  tests.
- Capture creation supports both the nested `metadata`/`quality` body in the
  prose contract and a legacy flattened body. The generated client should use
  the nested body.
- The spec's manifest schema only requires `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; the actual renderer supplies the
  richer page, marker, patch, pair, printer-profile, and capture-profile data
  described by the prose contract. This is a spec completeness gap to report
  upstream, because a generated client cannot be fully typed from those omitted
  properties.
- Ranked results is now concretely rendered with
  `schema_version: lps-ranked-results/v1`, aggregation metadata, and per-pair
  results, but the published schema declares only `schema_version` and
  `sheet_id`. The iOS app has neither a ranked-results model nor a call site.
- `sheet_id` route parameters are backed by sheet lookup codes, and capture IDs
  are decimal strings. The generated client's path argument names should not be
  mistaken for database IDs.

## Environment limitation

The container does not provide a `swift` executable, so `swift package resolve`
and `swift test --disable-sandbox` cannot run here. The implementation run must
run the focused suite in a Swift-capable environment and record the result.
