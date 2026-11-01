---
module: ColorMatchingLPSAppCore
tags: [api-contract, openapi, color_matching]
problem_type: contract-drift
---

# `color_matching` prose contract vs. published OpenAPI spec

Source for this comparison: `viamin/color_matching` PR
[#113](https://github.com/viamin/color_matching/pull/113) (closes
[#110](https://github.com/viamin/color_matching/issues/110)), commit
`05062f5381a6f76413cc2bdf1cb2cc08a1b70ff7`. The spec is generated at
runtime by `ColorMatchingWeb.ApiSpec` from `ColorMatchingWeb.ApiSchemas`
and the `OpenApiSpex.ControllerSpecs` annotations on each controller —
there is no committed static `openapi.json` in that repo, so this
comparison was done by reading those sources directly rather than
fetching a live `/api/v1/openapi.json`.

This is a findings record for issue #5 ("Replace hand-written API layer
with a generated OpenAPI Swift client"). It captures what differs between
`docs/color-matching-api-contract.md` (this repo's hand-written prose
contract) and the real, published contract, plus gaps that affect how
much a generated client actually buys us. **No implementation changes
are part of this run** — this run only adds tests/docs under the TDD
test-writing boundary; a follow-up implementation run wires up
`swift-openapi-generator` against this contract.

## Deltas that matter for the generated client

1. **Measurement upload request shape has drifted.** The real
   `MeasurementUploadRequest` schema
   (`lib/color_matching_web/api_schemas.ex`) only allows
   `measurements[].{patch_id, linear_rgb_median, normalized_linear_rgb_median}`
   and `pair_scores[]` (`PairScoreRequest`: `pair_id`, `algorithm_version`,
   plus one of `score` / `similarity` / `distance`). It has **no
   top-level `scoring_algorithm_version`** and **no per-measurement
   `stats`** object at all. This app's `APIClient.uploadMeasurements`
   (`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift:33-41`) sends
   both: a top-level `scoring_algorithm_version` and a full `stats`
   (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`)
   object per measurement. Neither field is part of the documented
   contract. `iOS/Tests/ColorMatchingLPSAppTests/APIContractDeltaTests.swift::testUploadMeasurementsBodyMatchesPublishedMeasurementUploadRequestSchema`
   is red today, demonstrating this.
2. **Capture creation accepts two request shapes, not one.** The
   prose contract only documents the nested `{metadata, quality}` shape.
   The real `CaptureRequest` schema is `anyOf` the nested shape **or** a
   flat shape with top-level `device_model`, `lens`, `exposure_duration`
   (not `exposure_duration_seconds`), `iso`, `focus_lens_position`,
   `white_balance_gains`, `image_width`, `image_height`, `app_version`,
   `timestamp`, `detected_marker_count`, `blur_score`,
   `rejection_reasons`. This app already sends the nested shape, so no
   change is required, but a generated client built against the full
   schema would expose the flat variant too and a naive implementation
   could pick the wrong field names (`exposure_duration` vs
   `exposure_duration_seconds`, `rejection_reasons` vs `rejections`) if it
   isn't told which branch this app uses.
3. **Write endpoints return bodies this app discards.** The real API
   now returns `{capture_id, measurement_count, pair_score_count}` from
   `POST .../measurements` and `{capture_id, judgment_count}` from
   `POST .../judgments`. Neither is documented in
   `docs/color-matching-api-contract.md`, and
   `APIClient.uploadMeasurements` / `uploadJudgments` both return `Void`
   today, ignoring the body entirely. The generated client will
   naturally decode these; worth deciding in the implementation run
   whether to surface them (e.g. for confirming counts match what was
   sent) or keep ignoring them.
4. **Error responses are a documented `oneOf`, decoded nowhere today.**
   `ApiErrorResponse.errors` is `oneOf` a loosely-typed object or a
   JSON:API-style array of `{detail, source: {pointer}}`. This app's
   `APIError` (`APIClient.swift:247-249`) is a single `badStatus` case
   with no body parsing. A generated client gives us typed error
   decoding essentially for free; worth using it instead of the current
   status-code-only check.
5. **Two response schemas are stubs relative to what they actually
   return**, which caps how much typed value the generated client gets
   for those two surfaces without an upstream widening PR:
   - `Manifest` (`TestSheetManifest`) only declares
     `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`
     as properties/required. The real JSON
     (`ColorMatchingWeb.TestSheetJSON.manifest/2`) also includes
     `sheet_version`, `manifest_url`, `created_at`, `page`,
     `registration_markers`, a much richer `printer_profile`
     (`printer_make_model`, `paper_type`, `ink_type`, `icc_profile`,
     `print_settings`, `driver_name`, `driver_version`,
     `calibration_date`, `calibration_version`, `notes` — note: *not*
     the `{id, name, paper, ink, settings}` shape shown in
     `docs/color-matching-api-contract.md`'s example), `patches`, and
     `pairs`. None of those are in the OpenAPI schema's declared
     properties.
   - `RankedResults` only declares `schema_version` and `sheet_id`. The
     real JSON also includes `printer_profile`, `capture_count`,
     `latest_capture_at`, `earliest_capture_at`,
     `scoring_algorithm_versions`, and `results[]` (`rank`, `pair_id`,
     `scoring_algorithm_version`, `row`, `col`, `source_colors`,
     `score`, `current_judgment`, `current_judgment_observed_at`,
     `observation_count`, `latest_observation`, `capture_count`,
     `latest_capture_at`, `earliest_capture_at`).

   Because neither schema sets `additionalProperties: false`, these
   fields aren't *forbidden* — they're just untyped as far as the spec
   is concerned, so `swift-openapi-generator` will model them as an open
   dictionary rather than named properties unless `color_matching`
   widens the schemas first. Filing this back upstream (the generated
   client's whole point is making this kind of drift visible) is worth
   doing before or alongside the implementation run.
6. **Validation is asymmetric across controllers.**
   `TestSheetController` wires `OpenApiSpex.Plug.CastAndValidate`
   (`lib/color_matching_web/controllers/test_sheet_controller.ex:9`), but
   `CaptureController` does not. The three write endpoints this app
   calls (`create`, `upload_measurements`, `upload_judgments`) are
   *documented* via `OpenApiSpex.ControllerSpecs` but not *enforced* at
   request time — so today the OpenAPI schema for those endpoints is
   aspirational, not verified server-side. The generated client's
   compile-time typing is doing real work here that the server itself
   isn't doing yet.
7. **Minor type deltas** (low risk, flagged for completeness): the
   real `CaptureMetadata` schema types `iso` as `integer` (this app's
   `CaptureMetadata.iso` is `Float?`) and requires `image_width` /
   `image_height` (this app's `CaptureMetadata.imageWidth` /
   `imageHeight` are `Int?`). Not currently causing failures since
   `CaptureController` doesn't validate, but worth tightening when the
   generated types land.

## Endpoint gaps discovered

- **Ranked results are documented but never called.** The app has no
  `fetchRankedResults` (or equivalent) anywhere in
  `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`, despite
  `GET /api/v1/test_sheets/:sheet_id/ranked_results` existing in both
  the prose contract and the real spec, and despite the issue's
  deliverable list naming "ranked results" as one of the five surfaces
  this app uses today. It currently does not. The implementation run
  should either add this call when it wires up the generated client, or
  the issue's scope should be corrected.
- `/api/illuminant_measurements`, `/api/illuminant_measurements/bulk`,
  and `/api/multi_image_mapping` exist in the real spec (serving the
  macOS companion app) but are out of scope for this app — consistent
  with the issue's non-goals ("new endpoints").
- `GET /api/v1/printer_profiles`, `/palettes`, `/colors`, and
  `/printer_profiles/:id/metamer_pairs` likewise exist but aren't used
  by this app.

## What this means for the implementation run

- `swift-openapi-generator` + `swift-openapi-runtime` need to be added
  to `iOS/Package.swift`, plus a fetched/vendored copy of the spec and
  generator config — none of that is in scope for this test-writing
  run (TDD boundary restricts this run to `iOS/Tests/` and `docs/`).
- The measurement-upload request body needs to drop `stats` and the
  top-level `scoring_algorithm_version` to match the real schema (delta
  #1), not just swap Codable models for generated ones.
- Decide whether to add `fetchRankedResults` (closing the gap above) as
  part of this migration or file it separately.
- Consider filing an upstream PR against `viamin/color_matching` to
  widen the `Manifest` and `RankedResults` schemas (delta #5) before
  relying on generated types for those two surfaces, otherwise the
  "generated client" for sheet/ranked-results data is mostly an open
  dictionary and the stated goal ("server-side drift becomes visible as
  a regeneration diff") doesn't hold for those fields.
