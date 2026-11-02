# `color_matching` OpenAPI spec deltas vs the prose contract

This file records the differences between the hand-written prose contract
(`docs/color-matching-api-contract.md`) and the machine-readable OpenAPI 3 spec
published by `viamin/color_matching` at `GET /api/v1/openapi.json`
(viamin/color_matching#110). It is the source material for the PR description of
the generated-client migration (#5) and should be refreshed whenever the
vendored spec in `iOS/Sources/ColorMatchingOpenAPI/openapi.json` is regenerated.

The spec's six app-relevant operations (operation IDs are
`ColorMatchingWeb.<Controller>.<action>`, derived by `open_api_spex`):

| Surface | Operation | Method + path |
| --- | --- | --- |
| Sheet manifest | `ColorMatchingWeb.TestSheetController.manifest` | `GET /api/v1/test_sheets/{sheet_id}/manifest` |
| Recent sheets | `ColorMatchingWeb.TestSheetController.recent` | `GET /api/v1/test_sheets/recent` |
| Ranked results | `ColorMatchingWeb.TestSheetController.ranked_results` | `GET /api/v1/test_sheets/{sheet_id}/ranked_results` |
| Create capture | `ColorMatchingWeb.CaptureController.create` | `POST /api/v1/test_sheets/{sheet_id}/captures` |
| Upload measurements | `ColorMatchingWeb.CaptureController.upload_measurements` | `POST /api/v1/captures/{capture_id}/measurements` |
| Upload judgments | `ColorMatchingWeb.CaptureController.upload_judgments` | `POST /api/v1/captures/{capture_id}/judgments` |

Note the path parameter is `sheet_id`: the app's "sheet code" lookup key maps to
that parameter unchanged.

## What changed between the prose contract and the published spec

1. **Manifest response is documented as a compatibility envelope only.** The
   spec's `TestSheetManifest` documents `schema_version` (enum
   `lps-sheet-manifest/v1`), `sheet_id`, and
   `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`) — all
   required. The prose contract (and the live payload) additionally carry
   `sheet_version`, `manifest_url`, `created_at`, `page`,
   `registration_markers`, `printer_profile`, the remaining `capture_profile`
   fields (`expected_illuminant`, `preferred_camera`), `patches[]`, and
   `pairs[]`. The generated client decodes the documented subset and ignores the
   rest; the undocumented geometry still has to be consumed by
   `MeasurementCore`'s hand-written `SheetManifest` (a purely client-side model
   that stays hand-written per #5's non-goals). See gap G-1.
2. **Capture creation accepts two shapes.** `CaptureRequest` allows either a
   flat payload (`device_model`, `lens`, `exposure_duration`, `iso`, …,
   `detected_marker_count`, `blur_score`, `rejection_reasons`) or the nested
   `metadata` + `quality` shape the app sends (`anyOf`). In the flat shape the
   exposure field is named `exposure_duration` and rejections are
   `rejection_reasons`; in the nested shape they are
   `exposure_duration_seconds` and `rejections`. The nested shape the app uses
   remains valid.
3. **Measurement upload response is now a typed payload.** The spec returns
   `200` with `{capture_id, measurement_count, pair_score_count}`. The prose
   contract showed no response body (the app accepted any 2xx, including 204).
   The generated client surfaces the counters.
4. **`Rgb` values are polymorphic.** `linear_rgb_median` /
   `normalized_linear_rgb_median` accept an array of numbers, an `{r,g,b}`
   object, or a JSON-encoded string (`RgbPayload` anyOf). The app sends the
   `{r,g,b}` object, which matches.
5. **`normalized_linear_rgb_median` is required** in the spec's measurement
   rows. The prose contract marked it optional; the app always uploads it, so
   behavior is unchanged, but a future app change that skips it will now fail
   server-side validation.
6. **Judgment upload response is now a typed payload.** `200` with
   `{capture_id, judgment_count}` instead of an unspecified 2xx.
7. **`pair_scores` are validated.** Each score requires `pair_id` +
   `algorithm_version` plus at least one of `score` / `similarity` /
   `distance`. The app sends `similarity` and `distance` (satisfies the
   requirement; both are accepted).
8. **Authentication is declared but not generated.** The spec declares the
   `bearerAuth` security scheme on all six operations. `swift-openapi-generator`
   does not generate auth plumbing from security schemes, so the bearer token
   stays an app-side concern (`BearerTokenMiddleware` in
   `ColorMatchingLPSAppCore`).
9. **Ranked results gained a schema version.** `lps-ranked-results/v1` did not
   exist in the prose contract.

## Endpoint gaps discovered (spec vs what the app uses)

- **G-1 — manifest geometry is undocumented.** `page`, `registration_markers`,
  `patches[]`, `pairs[]`, `printer_profile`, `manifest_url`, `sheet_version`,
  `created_at` are returned by the server but absent from the published
  `TestSheetManifest` schema. Until they are added upstream, the generated
  client cannot type them and the app keeps `MeasurementCore.SheetManifest`
  hand-written.
- **G-2 — measurement upload loses fields.** The prose contract's top-level
  `scoring_algorithm_version` and per-measurement `stats`
  (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`) are not in
  `MeasurementUploadRequest`. The server still tolerates extra keys today
  (`additionalProperties` is unconstrained), but the generated client cannot
  send them, so a regenerated client silently stops uploading them. Needs an
  upstream spec addition before the app can restore them.
- **G-3 — enums are not machine-checked.** Judgment strings
  (`match`/`near_match`/`no_match`) and capture rejection strings
  (`missingRegistrationMarks`, `incompleteSheetCoverage`, `clipping`,
  `excessiveBlur`, `glare`, `poorReferencePatch`) are free-form strings in the
  spec; only the prose contract enumerates them.
- **G-4 — ranked results are an envelope.** Only `schema_version` + `sheet_id`
  are documented; the prose contract's promised content (source colors, scores,
  labels, capture provenance, printer profile, scoring algorithm version) is
  undocumented on both sides.
- **G-5 — endpoints in the spec the app does not use.** `GET
  /api/v1/openapi.json`, `printer_profiles*`, `palettes`, `colors`,
  `metamer_pairs`, `POST /api/illuminant_measurements(/bulk)`, and `POST
  /api/multi_image_mapping`. Not consumed by this app; kept out of the
  generated-client surface the tests pin.
