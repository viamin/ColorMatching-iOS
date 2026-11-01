# OpenAPI Client Migration Notes

Scoping notes for #5 (Replace hand-written API layer with a generated OpenAPI Swift client),
captured while comparing `docs/color-matching-api-contract.md` against the real, now-published
spec from `viamin/color_matching#110` (merged as `viamin/color_matching#113`, commit
`094bd6d3443ddacbda7e63354299867eb5bdfa9f`). The spec itself is generated at runtime from
`ColorMatchingWeb.ApiSpec` / `ColorMatchingWeb.ApiSchemas` and served at `GET /api/v1/openapi.json`
— there is no static file to vendor; fetching it requires a running `color_matching` instance (or
exporting it from that repo's test suite) before codegen can run.

This repo has not fetched or vendored the spec yet, and no generated client exists yet. These
notes exist so the implementation run (after `paid-tests-approved`) does not have to redo this
comparison. The Swift tests added alongside this document exercise the *current* hand-written
`APIClient` against fixtures shaped like the real API, so they also serve as a regression baseline
the generated client's behavior can be checked against.

## Contract deltas found

- **`printer_profile` is a different, larger shape than documented.** The contract doc shows
  `{id, name, paper, ink, settings}`. The real response
  (`ColorMatchingWeb.TestSheetJSON.render_printer_profile/1`) has no `id` at all and uses
  `{printer_make_model, paper_type, ink_type, icc_profile, print_settings, driver_name,
  driver_version, calibration_date, calibration_version, notes}`. None of the field names match.
  `SheetManifest` (iOS/Sources/MeasurementCore/Models.swift) does not model `printer_profile` or
  `capture_profile` at all today, so this has been silently dropped rather than wrong — but the
  generated client should expose it, since `docs/companion-ios-mvp-plan.md` describes uploading
  "printer profile" provenance.
- **`recent` sheets always return `title: null`.** `render_recent_sheet/1` hardcodes
  `title: nil`; there is no server-side logic yet to populate a display title. The contract doc's
  `"title": "July LPS comparison sheet"` example does not reflect any real response.
- **Measurement/judgment uploads respond `200` with a JSON body, not `204` with an empty body.**
  `POST /api/v1/captures/:id/measurements` returns
  `{capture_id, measurement_count, pair_score_count}`; `POST .../judgments` returns
  `{capture_id, judgment_count}`. The contract doc doesn't show a response at all for either. The
  hand-written `APIClient.uploadMeasurements`/`uploadJudgments` discard the response body
  entirely, so this is currently harmless, but a generated client will decode these bodies and
  callers may want the counts for upload confirmation UI.
- **`MeasurementUploadRequest`'s published schema has no `scoring_algorithm_version` and no
  per-measurement `stats`.** The hand-written client sends both (matching the contract doc), and
  `CaptureController` has no `CastAndValidate` plug, so the server currently tolerates and
  ignores both. If the generated client is built strictly from the spec's request type, these
  fields would be dropped silently unless intentionally re-added — worth a deliberate decision,
  not an accidental loss, when the generated types land.
- **Capture creation accepts two different shapes.** `CaptureRequest`'s schema is `anyOf` a flat
  top-level shape (`device_model`, `lens`, ... `detected_marker_count`, `blur_score`,
  `rejection_reasons`) or a nested `{metadata, quality}` shape. The hand-written client already
  sends the nested shape, which is one of the two valid branches — no change needed here, just
  confirming it isn't a mismatch.
- **Validation error bodies are structured (`ErrorResponse`) and discarded.** 422s return
  `{"errors": ...}` (either an object or an array of `{detail, source: {pointer}}`). `APIClient`
  only checks the status code and throws an untyped `APIError.badStatus`, losing that detail. A
  generated client typically gives typed error payloads for documented error responses — surfacing
  them would be a real behavior improvement, not just a mechanical swap.
- **`GET /api/v1/test_sheets/:sheet_id/ranked_results` exists but has no client method today.**
  There is no `fetchRankedResults` (or equivalent) anywhere in `ColorMatchingLPSAppCore`. The
  real response shape is richer than the contract doc's prose description: it includes
  `schema_version`, `sheet_id`, `printer_profile`, `capture_count`, `latest_capture_at`,
  `earliest_capture_at`, `scoring_algorithm_versions`, and a `results` array with
  `rank`, `pair_id`, `scoring_algorithm_version`, `row`, `col`, `source_colors`, `score`
  (`average`/`latest`/`minimum`/`maximum`/`capture_count`/`sample_count`/`algorithm_versions`),
  `current_judgment`, `current_judgment_observed_at`, `observation_count`, and
  `latest_observation` (`judgment`/`observed_at`). This is a real endpoint gap: the deliverable
  list in #5 includes "ranked results" as a surface the generated client should cover, and the
  app currently has no code path to it at all.

## Endpoint gaps noted but out of scope for this app

`viamin/color_matching#110`'s own description calls out `/api/illuminant_measurements` and
`/api/multi_image_mapping` as previously-undocumented endpoints. Neither is used by this app's
MVP workflow (sheet manifest / capture / measurement / judgment / ranked results), so they are not
covered by the generated-client surface this issue asks for.

## What's still needed before codegen can run

1. Fetch/export `GET /api/v1/openapi.json` from a running (or test-mode) `color_matching`
   instance and vendor it into this repo (e.g. `iOS/openapi.yaml` or `.json`), since there is no
   static spec file in that repo to pull directly.
2. Add `swift-openapi-generator` + `swift-openapi-runtime` to `iOS/Package.swift` and configure
   generation for: manifest, recent sheets, capture creation, measurement upload, judgment
   upload, and ranked results.
3. Replace the hand-written request/response Codable types in
   `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift` with the generated `Operations`/
   `Components.Schemas` types, keeping `MeasurementCore`'s purely client-side domain types
   (`RGB`, `ChannelStats`, scoring, geometry, etc.) as-is per the issue's non-goals.

None of this is implemented in this change — this is a test-and-documentation-only pass per the
current TDD phase. The characterization tests added to `APIClientTests.swift` fix today's
hand-written-client behavior against the real wire shapes above so the follow-up implementation
run has a concrete regression baseline.
