# `color_matching` Published OpenAPI Spec vs. The Hand-Written Contract

This records what was found comparing `docs/color-matching-api-contract.md` against the
real OpenAPI 3 document published by `viamin/color_matching` (viamin/color_matching#110,
merged in [PR #113](https://github.com/viamin/color_matching/pull/113), commit
`094bd6d3443ddacbda7e63354299867eb5bdfa9f`). No live Phoenix server is available in this
environment (no database, no Elixir toolchain), so the spec's shape was derived by reading
the merged source directly: `lib/color_matching_web/api_spec.ex`,
`lib/color_matching_web/api_schemas.ex`, and `lib/color_matching_web/router.ex`.

The spec is served at **`GET /api/v1/openapi.json`**, unauthenticated (it sits in the `:api`
pipeline, not `:api_auth`). That's the URL the implementation phase should fetch/vendor from
a running `color_matching` instance.

## Field-level drift in surfaces the iOS app already calls

- **`POST /captures/:capture_id/measurements`** — the published `MeasurementUploadRequest`
  schema's top level only has `measurements` and `pair_scores`; there is no top-level
  `scoring_algorithm_version`. The hand-written client
  (`APIClient.uploadMeasurements`/`MeasurementUploadRequest` in
  `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`) sends one anyway.
- Each measurement item in that same schema requires `patch_id`, `linear_rgb_median`, **and**
  `normalized_linear_rgb_median` (all three required) and has no `stats` property at all. The
  hand-written client makes `normalizedLinearRGBMedian` optional (omitted on the wire when
  `nil`, since it's Swift's `encodeIfPresent`) and always sends a `stats` object the schema
  doesn't define.
  - `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift::testUploadMeasurementsPayloadDriftsFromPublishedOpenAPISchema`
    pins both of these as failing today.
- **`POST /test_sheets/:sheet_id/captures`** — field names in the nested `metadata` object match
  exactly (`device_model`, `lens`, `exposure_duration_seconds`, `iso`, `focus_lens_position`,
  `white_balance_gains`, `image_width`, `image_height`, `app_version`, `timestamp`), but the
  published schema types `iso` as `integer` while the app models it as `Float?`. Camera-reported
  ISO values are whole numbers in practice, so this hasn't bitten yet, but a generated client
  would reject a fractional value the hand-written one would happily send.
- Response bodies the app currently ignores (`MeasurementUploadResponse`:
  `capture_id`/`measurement_count`/`pair_score_count`, `JudgmentUploadResponse`:
  `capture_id`/`judgment_count`) are typed in the spec; nothing to change, just note the app
  doesn't need them today.

## Coverage gap: manifest and ranked results aren't fully specified

The published `TestSheetManifest` schema only requires `schema_version`, `sheet_id`, and
`capture_profile.scoring_algorithm_version`. It does not type `sheet_version`, `manifest_url`,
`created_at`, `page`, `registration_markers`, `printer_profile`, `patches`, or `pairs` — the
fields `SheetManifest` (`iOS/Sources/MeasurementCore/Models.swift`) actually requires to render
a sheet. `RankedResults` is similarly minimal: only `schema_version` and `sheet_id` are typed.

`iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift::testManifestDecodeFailsWithOnlyPublishedSchemaFields`
pins this: decoding a payload containing only the officially-required manifest fields fails
against today's hand-written model. A `swift-openapi-generator` client built strictly from the
published schema would generate `TestSheetManifest`/`RankedResults` types that don't expose
`patches`/`pairs`/`page`/etc. as typed fields, so **the manifest and ranked-results surfaces
cannot be fully migrated to generated types until `color_matching` tightens those two schemas**.
Recommend keeping the hand-written `SheetManifest`/`Patch`/`PairManifest` models for those two
endpoints as a scoped exception, or filing a follow-up against `color_matching` to flesh out the
schemas, before treating this deliverable as fully done for those surfaces.

## Endpoints discovered that the iOS app doesn't use

The router also exposes `GET /printer_profiles`, `GET /printer_profiles/:id/colors`,
`GET /printer_profiles/:id/metamer_pairs`, `GET /palettes`, `GET /colors` (used by the macOS
app's `PaletteAPIClient`, not this app), plus `POST /api/illuminant_measurements` (+ `/bulk`)
and `POST /api/multi_image_mapping`. None of these are called by the iOS companion app today;
out of scope for this client-generation effort per the issue's non-goals (no new endpoints).

The sheet/capture routes also gained explicit 405 (`MethodNotAllowedController`) handling for
wrong-verb requests, which doesn't change anything the app sends today.
