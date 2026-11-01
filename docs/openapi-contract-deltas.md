# Contract Deltas: Prose Contract vs. Published OpenAPI Spec

This records what changed between the hand-written prose contract
(`docs/color-matching-api-contract.md`) and the real, machine-readable
OpenAPI 3 document now published by `viamin/color_matching`
(viamin/color_matching#113, closing viamin/color_matching#110, merged
2026-10-30 as commit `05062f5381a6f76413cc2bdf1cb2cc08a1b70ff7`), as input to
the `swift-openapi-generator` migration tracked by issue #5.

The spec is served live and unauthenticated at `GET /api/v1/openapi.json`
(router pipeline `:api`, no `:api_auth`). It is generated from
`OpenApiSpex` route/schema annotations in `lib/color_matching_web/` —
`api_spec.ex`, `api_schemas.ex`, and the five `operation` blocks in
`test_sheet_controller.ex` / `capture_controller.ex`. Fetch/vendor it from
that path when implementing, rather than guessing at shapes.

## Surfaces confirmed unchanged

- `GET /api/v1/test_sheets/recent` — `{sheets: [{sheet_id, manifest_url,
  title}]}`, `title` nullable (and currently always `null` server-side).
- Manifest `patches`/`pairs`/`registration_markers`/`capture_profile` field
  names and shapes match `docs/color-matching-api-contract.md` exactly.
- `POST /api/v1/test_sheets/:sheet_id/captures` — the app's current nested
  `{"metadata": {...}, "quality": {...}}` body satisfies one branch of the
  real schema's `anyOf` (`CaptureRequest` requires either the flat top-level
  fields or `metadata`). No change needed here.
- `POST /api/v1/captures/:capture_id/judgments` — `{"judgments": [{pair_id,
  judgment}]}` matches exactly.

## Deltas found

1. **`printer_profile` fields are completely different from the docs.**
   The prose contract describes `{id, name, paper, ink, settings}`. The real
   renderer (`TestSheetJSON.render_printer_profile/1`) emits
   `{printer_make_model, paper_type, ink_type, icc_profile, print_settings,
   driver_name, driver_version, calibration_date, calibration_version,
   notes}` — no `id` or `name` at all. `MeasurementCore.SheetManifest`
   doesn't decode `printer_profile` today, so this drift is currently
   invisible; a generated type will surface it.

2. **The published response schemas for `Manifest` and `RankedResults` are
   far thinner than what the controllers actually render.**
   `ColorMatchingWeb.ApiSchemas.Manifest` only declares `schema_version`,
   `sheet_id`, and `capture_profile.scoring_algorithm_version` — it omits
   `sheet_version`, `manifest_url`, `created_at`, `page`,
   `registration_markers`, `printer_profile`, `patches`, and `pairs`, all of
   which `TestSheetJSON.manifest/1` actually renders and the iOS app needs.
   Likewise `ColorMatchingWeb.ApiSchemas.RankedResults` only declares
   `schema_version` and `sheet_id`, while `TestSheetJSON.ranked_results/1`
   actually renders `printer_profile`, `capture_count`,
   `latest_capture_at`/`earliest_capture_at`, `scoring_algorithm_versions`,
   and a full `results` array (`rank`, `pair_id`, `scoring_algorithm_version`,
   `row`/`col`, `source_colors`, `score` object, `current_judgment` +
   observed-at, `observation_count`, `latest_observation`, capture
   provenance). **Generating a client straight from the published spec for
   these two endpoints would produce impoverished Swift types missing most
   of the fields the app needs.** This should be raised upstream against
   `viamin/color_matching` to tighten those two schemas; until then the
   generated types for `manifest` and `ranked_results` need a documented
   workaround (e.g. hand-widened schema overrides fed to the generator)
   rather than being trusted as-is.

3. **`MeasurementUploadRequest` has no `scoring_algorithm_version` and no
   per-measurement `stats`.** The real schema's request body is only
   `{measurements: [{patch_id, linear_rgb_median,
   normalized_linear_rgb_median}], pair_scores: [...]}`. The current
   hand-written `APIClient.uploadMeasurements` sends a top-level
   `scoring_algorithm_version` and a per-measurement `stats` object
   (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`) that
   have no field to land in on the real schema. `CaptureController` has no
   `CastAndValidate` plug, so the server silently ignores the extra keys
   today — but a client generated strictly from the schema has no field to
   set them on, so this telemetry would be silently dropped by the
   migration unless the upstream schema is extended first. Flagged for a
   decision before implementation; see the red test in
   `iOS/Tests/ColorMatchingLPSAppTests/APIContractDriftTests.swift`.

4. **`ranked_results` has no Swift model or `APIClient` method at all
   today**, despite being one of the five surfaces issue #5 lists
   (test-sheet manifest + recent sheets, capture session creation,
   measurement upload, judgment upload, ranked results). This is a gap in
   the *current app*, not just the docs — it needs a generated-client method
   added as part of the implementation, not merely a replacement of an
   existing one.

5. **Error responses are now documented**: `ApiErrorResponse` is
   `{errors: <object> | [{detail, source: {pointer}}]}`. The prose contract
   never described an error shape.

6. **Enumerated string values in the prose contract aren't enforced
   server-side.** Capture `rejections` and judgment `judgment` are plain
   `string`/`array of string` in the real schema, not an `enum`. The lists
   in `docs/color-matching-api-contract.md` (`missingRegistrationMarks`,
   `match`/`near_match`/`no_match`, etc.) are a client-side convention only.

7. **`capture_id` is a stringified integer** (e.g. `"1"`), not a prefixed
   token like the doc's example `"capture_123"`.

## Endpoints out of scope for this app

The real API also exposes `/api/v1/printer_profiles`,
`/api/v1/printer_profiles/:id/colors`, `/api/v1/printer_profiles/:id/metamer_pairs`,
`/api/v1/palettes`, `/api/v1/colors`, `/api/illuminant_measurements[/bulk]`,
and `/api/multi_image_mapping`. These belong to the macOS companion app's
migration (`viamin/ColorMatching-macOS#39`), not this app's surfaces, and
should be excluded from the generated-client surface here per issue #5's
non-goals.
