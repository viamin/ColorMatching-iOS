# `color_matching` OpenAPI Spec vs. The Hand-Written Contract

Source of truth for this note: `viamin/color_matching#110` (closed by `viamin/color_matching#113`,
merged 2026-10-30, commit `05062f5381a6f76413cc2bdf1cb2cc08a1b70ff7`). This repo has no network
access to a running `color_matching` instance, so the deltas below come from reading
`lib/color_matching_web/{router,api_spec,api_schemas}.ex`,
`lib/color_matching_web/controllers/{test_sheet_controller,test_sheet_json,capture_controller}.ex`
at that commit, not from fetching `GET /api/v1/openapi.json` directly.

All five routes this app depends on exist at the paths `docs/color-matching-api-contract.md`
already assumes:

```
GET  /api/v1/test_sheets/:sheet_id/manifest
GET  /api/v1/test_sheets/recent
GET  /api/v1/test_sheets/:sheet_id/ranked_results
POST /api/v1/test_sheets/:sheet_id/captures
POST /api/v1/captures/:capture_id/measurements
POST /api/v1/captures/:capture_id/judgments
```

## Deltas found

1. **Manifest and ranked-results OpenAPI *schemas* are much thinner than the real JSON.**
   `ApiSchemas.Manifest` only declares `schema_version`, `sheet_id`, and
   `capture_profile.scoring_algorithm_version` as typed/required. `ApiSchemas.RankedResults`
   only declares `schema_version` and `sheet_id`. The actual JSON rendered by
   `TestSheetJSON.manifest/1` and `TestSheetJSON.ranked_results/1` is the full shape
   `docs/color-matching-api-contract.md` describes (patches, pairs, page, registration
   markers, printer profile, ranked results with scores/judgments/provenance) — it's just not
   captured in the validation/doc schema. **Impact:** `swift-openapi-generator` generates
   Swift types straight from the schema, so the generated response types for these two
   endpoints will only carry the 2–3 compatibility fields unless the Phoenix spec is tightened
   first. Either track this as a follow-up in `color_matching`, or keep a thin hand-written
   decode step layered on top of the generated client for these two responses until the schema
   catches up.

2. **`MeasurementUploadRequest` shape has drifted from what this app sends.** The published
   schema is `{measurements: [{patch_id, linear_rgb_median, normalized_linear_rgb_median}],
   pair_scores: [{pair_id, algorithm_version, score|similarity|distance}]}`. There is **no
   top-level `scoring_algorithm_version`** and **no per-measurement `stats`** object. This
   app's hand-written `MeasurementUploadRequest`/`MeasurementUpload` (`APIClient.swift`) sends
   both. `linear_rgb_median`/`normalized_linear_rgb_median` accept an array, an `{r,g,b}`
   object, or a string (`RgbPayload`); the `{r,g,b}` object this app already sends is one of
   the accepted shapes.

3. **`normalized_linear_rgb_median` is required, not optional, on each measurement row.**
   `PatchMeasurement.normalizedLinearRGBMedian` is `RGB?` in this app, and Swift's synthesized
   `Encodable` calls `encodeIfPresent` for `Optional` properties — so a measurement captured
   before normalization drops the key entirely instead of sending `null`. Against the real
   schema that's a request the server's `OpenApiSpex.Plug.CastAndValidate` would reject.
   `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift::testUploadMeasurementsIncludesRequiredNormalizedMedianKeyEvenWhenAbsent`
   pins this down; it fails against today's `APIClient`.

4. **Measurement/judgment upload responses are non-empty and currently discarded.**
   `POST .../measurements` returns `{capture_id, measurement_count, pair_score_count}`;
   `POST .../judgments` returns `{capture_id, judgment_count}`. `APIClient.uploadMeasurements`
   and `APIClient.uploadJudgments` both return `Void` today and never read the body. Worth
   surfacing `measurement_count`/`pair_score_count`/`judgment_count` once the generated client
   makes the response type available, so a short upload (e.g. dropped rows) is visible to the
   app instead of only showing up as a 200 with fewer rows persisted server-side.

5. **`printer_profile` field names in the real manifest don't match the prose doc at all**,
   and this app's `SheetManifest` model doesn't decode `printer_profile` or `capture_profile`
   today (both are silently dropped by `JSONDecoder` since they're absent from
   `SheetManifest.CodingKeys`). Real shape (`TestSheetJSON.render_printer_profile/1`):
   `{printer_make_model, paper_type, ink_type, icc_profile, print_settings, driver_name,
   driver_version, calibration_date, calibration_version, notes}` — no `id` or `name`, unlike
   the doc's `{id, name, paper, ink, settings}`.

6. **`CaptureMetadata.iso` is typed `integer` in the published schema**; the doc and this app's
   `CaptureMetadata.iso` use a float. Minor, but worth matching in the generated types rather
   than coercing.

7. **Ranked results has no client-side implementation in this app at all** — no `APIClient`
   method, no Codable model — despite being one of the five surfaces this issue scopes in.
   The real response (`TestSheetJSON.ranked_results/1` / `render_ranked_result/1`) is: top-level
   `{schema_version, sheet_id, printer_profile, capture_count, latest_capture_at,
   earliest_capture_at, scoring_algorithm_versions, results: [...]}`, each result
   `{rank, pair_id, scoring_algorithm_version, row, col, source_colors: {color_a_hex,
   color_b_hex}, score: {average, latest, minimum, maximum, capture_count, sample_count,
   algorithm_versions}, current_judgment, current_judgment_observed_at, observation_count,
   latest_observation: {judgment, observed_at} | null, capture_count, latest_capture_at,
   earliest_capture_at}`. As noted in (1), the OpenAPI schema for this endpoint doesn't capture
   any of that yet, so generating a useful typed client for it depends on the spec being
   tightened server-side.

8. **Endpoints/resources in the published spec that this app doesn't use** (confirmed
   out of scope per this issue's non-goals): `POST /api/illuminant_measurements` (+ `/bulk`),
   `POST /api/multi_image_mapping`, and the `printer_profiles` / `palettes` / `colors` /
   `metamer_pairs` GETs under `/api/v1`.

## What's not done here

This is a test-writing-only pass: no `Package.swift` dependency on `swift-openapi-generator`/
`swift-openapi-runtime`, no vendored `openapi.json`, no generated client, and no `APIClient`
changes landed in this change set. `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`
gained:

- Characterization coverage for `fetchManifest`/`fetchRecentSheets` (previously untested)
  against the real server response shape, as a regression safety net for the upcoming swap.
- Two tests that currently fail against `APIClient`, each tied to a delta above: the
  required-but-omitted `normalized_linear_rgb_median` key (#3), and the undocumented
  `scoring_algorithm_version`/`stats` fields (#2).

The literal `openapi.json` document itself still needs to be fetched from a running
`color_matching` instance (there's no Elixir/Phoenix runtime in this sandbox to produce it) —
hand-reconstructing `OpenApiSpex`'s exact JSON serialization here would risk baking in
inaccuracies. That fetch, the `swift-openapi-generator`/`swift-openapi-runtime` package
dependency, the generated client, and the `APIClient` replacement belong in the follow-up
implementation run.
