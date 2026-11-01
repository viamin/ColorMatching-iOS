# Contract Deltas: Prose Doc vs. Published OpenAPI Spec

Tracking doc for [#5 "Replace hand-written API layer with a generated OpenAPI
Swift client"](https://github.com/viamin/ColorMatching-iOS/issues/5). Compares
`docs/color-matching-api-contract.md` (hand-written prose, this repo) against
the OpenAPI 3 spec published by `viamin/color_matching` in resolution of
[viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110)
(merged via [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113),
commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f`).

This run only adds characterization/contract-delta tests (see
`iOS/Tests/ColorMatchingLPSAppTests/APIContractDeltaTests.swift`) and this
doc; it does not add the `swift-openapi-generator` dependency or generated
client, which the test-writing phase's TDD boundary defers to the
implementation run.

## How the spec is published (important for vendoring)

`color_matching` does not commit a static spec file. The spec is generated at
runtime by `OpenApiSpex` from `lib/color_matching_web/api_spec.ex` +
`api_schemas.ex` and served at `GET /api/v1/openapi.json`
(`lib/color_matching_web/controllers/open_api_controller.ex`). **The
implementation run will need to either run a `color_matching` instance (or
`mix run` a small script) to fetch `openapi.json` and vendor it into this
repo, or ask upstream to commit a static copy** — there is nothing to curl
from a public URL today.

## Deltas found

1. **`manifest` and `ranked_results` response schemas are far thinner than
   the actual JSON they render.** The declared schemas
   (`ColorMatchingWeb.ApiSchemas.Manifest`, `.RankedResults`) only require:
   - `Manifest`: `schema_version`, `sheet_id`, `capture_profile.scoring_algorithm_version`
   - `RankedResults`: `schema_version`, `sheet_id`

   But the actual renderer
   (`lib/color_matching_web/controllers/test_sheet_json.ex`) emits the full
   rich payload the prose doc describes — `page`, `registration_markers`,
   `printer_profile`, `patches`, `pairs` for manifest; `rank`, `pair_id`,
   `row`/`col`, `source_colors`, `score` (with `average`/`latest`/`minimum`/
   `maximum`/`capture_count`/`sample_count`/`algorithm_versions`),
   `current_judgment`, `observation_count`, `latest_observation`, capture
   timestamps, etc. for ranked_results. **Generating Swift types straight
   from the published schema for these two endpoints will produce types
   that are missing most of the fields this app needs.** The implementation
   run should flag this upstream (the spec under-documents its own
   controllers) and likely keep a hand-written decode path for these two
   response bodies until the schema is enriched, rather than trying to force
   `swift-openapi-generator` to cover them.

2. **`printer_profile` shape in the real API doesn't match the prose doc.**
   Prose doc: `{id, name, paper, ink, settings}`. Real renderer:
   `{printer_make_model, paper_type, ink_type, icc_profile, print_settings,
   driver_name, driver_version, calibration_date, calibration_version,
   notes}`. Today's `SheetManifest` (`iOS/Sources/MeasurementCore/Models.swift`)
   has no `printerProfile` property at all, so this delta is currently
   invisible (the field is silently dropped by `Decodable`). A generated
   client would surface it for the first time.

3. **`MeasurementUploadRequest` has no top-level `scoring_algorithm_version`.**
   The published schema (`ColorMatchingWeb.ApiSchemas.MeasurementUploadRequest`)
   only declares `measurements` and `pair_scores`. Today's
   `APIClient.uploadMeasurements` (`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`)
   sends an extra top-level `scoring_algorithm_version` key that has no home
   in the real schema — see `scoring_algorithm_version` is carried per-pair
   instead, as `pair_scores[].algorithm_version` (required by
   `PairScoreRequest`). A generated request body type will have no slot for
   the top-level field; the implementation run should drop it rather than
   try to preserve it.
   - Covered by `APIContractDeltaTests.testUploadMeasurementsRequestBodyMatchesPublishedSchemaKeys`
     (fails today, by design — see test file for rationale).

4. **`normalized_linear_rgb_median` is required per-measurement, but the
   client type allows `nil`.** `MeasurementUploadRequest.measurements[]`
   requires `patch_id`, `linear_rgb_median`, **and**
   `normalized_linear_rgb_median`. `PatchMeasurement.normalizedLinearRGBMedian`
   (`iOS/Sources/MeasurementCore/Models.swift`) is `RGB?`, and Swift's
   synthesized `Encodable` omits the JSON key entirely when the value is
   `nil`. A capture session that only has raw (non-normalized) measurements
   today would silently produce a request body the published schema
   disallows.
   - Covered by `APIContractDeltaTests.testMeasurementUploadKeepsRequiredNormalizedKeyWhenNil`
     (fails today, by design).

5. **`CaptureRequest` supports two shapes; this app already uses the
   compatible one.** The schema's `anyOf` allows either a flat
   top-level body (`device_model`, `lens`, ... at the top level, plus
   `rejection_reasons`) or a nested `{metadata, quality}` body — the shape
   this app already sends. No change needed here, but note the schema
   doesn't constrain `quality.rejections`/`rejection_reasons` to an enum, so
   the allowed rejection strings (`missingRegistrationMarks`,
   `incompleteSheetCoverage`, `clipping`, `excessiveBlur`, `glare`,
   `poorReferencePatch` — `iOS/Sources/MeasurementCore/QualityAndScoring.swift`)
   remain documented only in the prose doc and server-side validation, not
   in the spec itself.

6. **Response bodies this app currently discards now have declared shapes.**
   `MeasurementUploadResponse` (`capture_id`, `measurement_count`,
   `pair_score_count`) and `JudgmentUploadResponse` (`capture_id`,
   `judgment_count`) are typed in the spec, but
   `APIClient.uploadMeasurements`/`uploadJudgments` only validate the status
   code and never decode the body. Not a bug, but the generated client will
   make these values available for free.

## Endpoint gaps discovered

- **`ranked_results` has no Swift model today at all** — no struct in
  `MeasurementCore` or `ColorMatchingLPSAppCore`, nothing in `ContentView`.
  Wiring the generated client to this endpoint is net-new work, not a
  replacement of an existing hand-written type.
- `/api/illuminant_measurements` and `/api/multi_image_mapping` (and the
  `/api/v1/printer_profiles`, `/api/v1/palettes`, `/api/v1/colors` family)
  exist in `color_matching` but are outside this app's contract/non-goals —
  no action needed here.
