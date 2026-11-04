# OpenAPI Client Migration: Test Plan And Contract Deltas

This test-only PR establishes the behavior that the generated OpenAPI client
must preserve when it replaces `ColorMatchingLPSAppCore.APIClient`. Each test
uses `URLProtocol` stubs; no live Phoenix service is needed in CI.

## Criterion verification plan

| Criterion | Smallest credible verification | Test or evidence |
| --- | --- | --- |
| Generated client handles manifest and recent-sheet reads | Permanent local-stub integration test | `APIClientTests.testFetchManifestDecodesSheetUsedForCapture`; `APIClientTests.testFetchRecentSheetsDecodesPublishedResponse` |
| Generated client handles capture creation and measurement/judgment uploads | Permanent local-stub integration test | `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`; `APIClientTests.testUploadMeasurementsEncodesScoresWithAlgorithmVersion`; `APIClientTests.testUploadJudgmentsEncodesPathAndPayload` |
| Generated types replace server models | Compile the app and these tests after generation | Implementation-run evidence; not verifiable in this tests-only PR |
| Ranked-results surface is generated | Local-stub test once the app exposes its generated operation adapter | Not covered: the current app has no ranked-results caller or API-client method |
| Contract deltas are reviewed | Inspect the published OpenAPI source and this record | External evidence: `viamin/color_matching#110`, closed 2026-10-30 |

## Published-spec deltas

The published endpoint source at `viamin/color_matching#110` exposes all six
expected paths, including ranked results. Its schemas differ from the prose
contract in ways the implementation run must accommodate:

- The manifest schema only requires `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`. The prose contract additionally
  treats page geometry, registration markers, patches, pairs, URLs, and profile
  data as the complete manifest needed by capture analysis. Generated manifest
  fields therefore need an app-side validation/adapter boundary before analysis.
- The ranked-results schema only requires `schema_version` and `sheet_id`; the
  prose contract describes source colors, scores, labels, capture provenance,
  printer profile, and scoring version. This is an endpoint-schema gap, not a
  client behavior change.
- Measurement and judgment uploads return JSON receipts (capture ID and counts)
  with HTTP 200. The prose contract specifies neither response bodies nor their
  fields, and the current client discards them.
- Capture creation accepts either the existing nested `metadata` form or a
  compatibility flat form. The prose contract only documents the nested form.
- The published measurement schema requires both linear and normalized RGB
  values and allows RGB object, array, or JSON-string representations. The
  prose contract specifies only RGB objects.

## Endpoint gaps discovered

The current app calls manifest, recent sheets, capture creation, measurement
upload, and judgment upload. It does not call ranked results, despite the prose
contract naming that endpoint. The implementation PR should generate the
ranked-results operation but must not add UI behavior; add an adapter and local
stub test only if an existing consumer is introduced.
