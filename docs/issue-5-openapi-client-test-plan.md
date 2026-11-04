# Issue #5 OpenAPI Client Test Plan

## Criterion mapping

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Generated client covers manifest and recent sheets | Permanent local `URLProtocol` stub tests decode the full manifest consumed by capture and the recent-sheet selector. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testFetchManifestDecodesSheetUsedByCaptureFlow`, `testFetchRecentSheetsDecodesSheetSelectionResponse`) |
| Generated client covers capture creation, measurements, and judgments | Permanent local `URLProtocol` stub tests assert paths, bearer auth, and request JSON. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload`) |
| Generated client covers ranked results | Permanent red test. It becomes executable once the provider publishes a complete ranked-results schema and the generated client exposes the endpoint. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testGeneratedClientSupportsRankedResultsResponse`) |
| Prose-contract deltas are recorded | Human/external evidence: upstream issue #110's merged source was inspected at `color_matching` `main` (2026-11-04). | This document, “Published-spec deltas” |

The local stubs are permanent regression tests: they do not contact a live Phoenix server and they cover the recurring sheet-selection and capture-upload flow.

## Published-spec deltas

Compared with `docs/color-matching-api-contract.md`, the published OpenAPI source in `viamin/color_matching` has these material differences and gaps:

- `TestSheetManifest` specifies only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The app requires page geometry, registration markers, patches, pairs, and `manifest_url` to analyze a capture.
- `RankedResults` specifies only `schema_version` and `sheet_id`. It does not define rankings, source colors, scores, labels, capture provenance, printer profile, or algorithm version promised by the prose contract.
- `MeasurementUploadRequest` requires normalized RGB values but does not describe the `stats` object or top-level `scoring_algorithm_version` sent by the current app. RGB is also broadened to array/object/string values.
- Measurement and judgment uploads now specify `200` JSON count responses instead of the prose contract's unspecified/empty `204` response.
- The published capture schema allows both the current nested `metadata`/`quality` form and a legacy flat form. Its metadata `iso` is an integer, whereas the current client models it as `Float`.
- The published recent-sheet schema matches the prose contract, including a nullable `title`; capture creation still returns `capture_id` as expected.

These gaps prevent a generated Swift client from replacing the handwritten manifest and ranked-results models without either expanding the provider spec or retaining those handwritten shapes. The next implementation run should vendor the spec, generate the client, route the existing app-facing adapter through generated operations, and turn the red ranked-results test into a decoding assertion using a provider-approved fixture.
