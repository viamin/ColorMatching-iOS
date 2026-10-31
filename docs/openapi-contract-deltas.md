# Contract Deltas: `docs/color-matching-api-contract.md` vs. the published OpenAPI spec

Research notes for #5 ("Replace hand-written API layer with a generated OpenAPI Swift
client"). `viamin/color_matching#110` ("Publish OpenAPI 3 spec for the `/api/v1` API and
enforce it in CI") closed as completed via `viamin/color_matching#113`, merged
2026-10-30. The spec is served at `GET /api/v1/openapi.json` (`OpenApiController#show`,
`open_api_spex`); this repo has no network path to fetch that JSON directly, so the
deltas below were derived from the merged source (router, `TestSheetJSON`,
`CaptureController`, `api_schemas.ex`) rather than the generated document itself. They
should be re-checked against the live `openapi.json` once `swift-openapi-generator` can
reach it.

## Endpoints the app uses all exist server-side

`TestSheetController` (`recent`, `manifest`, `ranked_results`) and `CaptureController`
(`create`, `upload_measurements`, `upload_judgments`) are present, each behind the
`api` + `api_auth` pipelines, matching the prose contract's bearer-token assumption.

## Deltas found

1. **`printer_profile` shape is unrecognizable from the prose contract.** The prose
   contract documents `{id, name, paper, ink, settings}`. The real manifest's
   `printer_profile` is `{id, printer_make_model, paper_type, ink_type, icc_profile,
   print_settings, driver_name, driver_version, calibration_date, calibration_version,
   notes}` — no field name survives unchanged. `MeasurementCore.SheetManifest` has no
   `printerProfile` property at all today, so this data is silently dropped on decode.
   See `ContractDeltaTests.testManifestRoundTripPreservesPrinterProfile`.

2. **`capture_profile` is also missing from `SheetManifest`**, even though its field
   names (`expected_illuminant`, `preferred_camera`, `scoring_algorithm_version`) match
   the prose contract exactly. Pure omission, not a naming drift. See
   `ContractDeltaTests.testManifestRoundTripPreservesCaptureProfile`.

3. **Patch `id` is server-generated as `"<pair_id>#first"` / `"<pair_id>#second"`**, not
   an opaque id like the prose contract's example (`"patch_1"`). Client code that treats
   patch ids as opaque is fine; code that parses or constructs them would not be.

4. **`MeasurementUploadRequest` has no top-level `scoring_algorithm_version`.** The
   prose contract shows one; `api_schemas.ex` only defines `measurements` and
   `pair_scores` (each `pair_scores[]` entry carries its own `algorithm_version`). The
   hand-written client (`APIClient.uploadMeasurements`) sends a top-level
   `scoring_algorithm_version` anyway. PR #113's review thread notes new request-validation
   plugs were added for this endpoint, so an undocumented extra field is a real risk,
   not just noise. See
   `ContractDeltaTests.testUploadMeasurementsOmitsUndocumentedTopLevelScoringAlgorithmVersion`.

5. **`normalized_linear_rgb_median` is required per measurement in the real schema**,
   but `PatchMeasurement.normalizedLinearRGBMedian` is optional client-side. Swift's
   synthesized `Encodable` omits the JSON key entirely when the value is `nil`, so an
   un-normalized measurement upload would be missing a field the real API requires. See
   `ContractDeltaTests.testUploadMeasurementsIncludesRequiredNormalizedMedianWhenNotComputed`.

6. **`PairScoreRequest` has a `score` field** (`anyOf` with `similarity`/`distance`)
   that has no counterpart in `MeasurementCore.PairScore`. Not yet covered by a test;
   worth confirming against the live spec whether the generated client needs to populate
   it.

7. **Measurement/judgment upload responses carry data the client discards.**
   `upload_measurements` returns `{capture_id, measurement_count, pair_score_count}`;
   `upload_judgments` returns `{capture_id, judgment_count}`. The prose contract shows no
   response body for either. `APIClient.uploadMeasurements`/`uploadJudgments` both return
   `Void` today. See `ContractDeltaTests.testUploadResponsesDiscardServerReportedCounts`
   (`XCTSkip`, not yet implemented).

8. **`ranked_results` has a full concrete schema** (`schema_version:
   "lps-ranked-results/v1"`, `printer_profile`, `capture_count`,
   `latest_capture_at`/`earliest_capture_at`, `scoring_algorithm_versions`, and a
   `results[]` array with rank/score/judgment/provenance detail) that the prose contract
   only gestures at ("the Phoenix app should return..."). `APIClient` has no method for
   this endpoint at all — the biggest gap, since it's one of the five surfaces #5 calls
   out explicitly. See `ContractDeltaTests.testFetchRankedResultsIsNotYetImplemented`
   (`XCTSkip`, not yet implemented).

9. **Rejection reason casing is unconfirmed.** The prose contract's allowed values
   (`missingRegistrationMarks`, `incompleteSheetCoverage`, ...) match
   `MeasurementCore.CaptureRejection`'s raw values exactly (camelCase), but the real
   schema only types `rejection_reasons`/`rejections` as `array of strings` with no
   visible enum constraint in the source inspected. Needs confirming against the live
   `openapi.json`, not just the Elixir source.

## Endpoints in the real API the app doesn't use (non-goals per #5)

`printer_profiles`, `palettes`, `colors`, `metamer_pairs`, `illuminant_measurements`
(+ `bulk`), and `multi_image_mapping` are all real `/api/v1`/`/api` surfaces with their
own schemas. None are in scope for #5.

## Tests

`iOS/Tests/ColorMatchingLPSAppTests/ContractDeltaTests.swift` pins deltas 1, 2, 4, 5, 7,
and 8 above as failing/skipped tests against the current hand-written `APIClient`. They
are written to be deleted or rewritten against the generated client during the
implementation phase, not kept as a permanent parallel suite to `APIClientTests`.
