# Contract Deltas: Prose Contract vs Published OpenAPI Spec

This is the evidence record for issue #5's deliverable: "what changed between
the prose contract and the published spec, and any endpoint gaps discovered".
The implementation PR description should fold this in verbatim.

- Prose contract: `docs/color-matching-api-contract.md` (this repo)
- Published spec: `GET /api/v1/openapi.json` served by `viamin/color_matching`,
  built with `open_api_spex` from `ColorMatchingWeb.ApiSpec`/`ApiSchemas`
- Upstream source of truth audited: `viamin/color_matching@47057afd58f7d46b4d4b740ca7d2d08947774471`
  (spec landed in viamin/color_matching#113, closing viamin/color_matching#110):
  - `lib/color_matching_web/api_spec.ex`
  - `lib/color_matching_web/api_schemas.ex`
  - `lib/color_matching_web/controllers/test_sheet_controller.ex`
  - `lib/color_matching_web/controllers/capture_controller.ex`
  - `lib/color_matching_web/router.ex`

All six surfaces the app uses today are present in the published spec with
bearer security declared per operation. The deltas below are what the generated
client will surface as compile-time or regeneration-diff changes.

## Deltas

1. **Manifest schema is thinned vs the prose contract.** The spec declares only
   `schema_version` (enum `lps-sheet-manifest/v1`), `sheet_id`, and
   `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`). The
   prose contract documents `sheet_version`, `manifest_url`, `created_at`,
   `page`, `registration_markers`, `printer_profile`, the remaining
   `capture_profile` fields (`expected_illuminant`, `preferred_camera`), and
   full `patches[]`/`pairs[]` grids. Endpoint gap: the patch/pair grid — the
   data the app actually samples against — is not machine-visible in the spec,
   so generated types cannot carry it. Decode tolerates the extra fields
   (OpenAPI 3.0 default), but they remain untyped; the app keeps its
   client-side manifest models for those fields until upstream widens the
   schema.

2. **Measurement upload loses fields.** The spec's
   `MeasurementUploadRequest` items declare only `patch_id`,
   `linear_rgb_median`, `normalized_linear_rgb_median` (the last one
   **required**, whereas the app's contract treats it as optional and its
   `PatchMeasurement.normalizedLinearRGBMedian` is `RGB?`). Per-measurement
   `stats` (`sample_count`, `clipping_fraction`, `mean`,
   `standard_deviation`) and the top-level `scoring_algorithm_version` from the
   prose contract are absent from the spec, so a spec-conformant generated
   client cannot send them. Gap to report upstream: quality/statistics
   provenance is silently dropped by the typed client.

3. **RGB payloads are polymorphic.** The spec's `RgbPayload` is
   `anyOf: [number[], {r,g,b}, string]`; the prose contract fixes the object
   form `{r,g,b}`. The generated client represents this as optional `value1`
   (array), `value2` (object), `value3` (string); the app sends the object
   form. `Rgb`-typed `integer` components elsewhere in the spec
   (`Components.Schemas.Rgb` for profile colors) are a different,
   display-oriented schema (0–255 integers), not the linear-RGB payload.

4. **Capture creation accepts two shapes.** The spec's `CaptureRequest` is
   `anyOf`: a flattened body (whose `exposure_duration` lacks the `_seconds`
   suffix and whose rejections field is `rejection_reasons`) or the prose
   contract's nested `metadata` + `quality` form. The app uses the nested form,
   which the spec declares as optional object properties. `iso` is an
   `integer` in the spec but `Float` in the app's `CaptureMetadata` — the
   adapter must convert.

5. **Upload responses carry bodies.** The published API returns `200` with
   `MeasurementUploadResponse` (`capture_id`, `measurement_count`,
   `pair_score_count`) and `JudgmentUploadResponse` (`capture_id`,
   `judgment_count`). The prose contract never documented a response payload
   and the app's existing tests stubbed `204 No Content`; any-2xx acceptance
   hid this. The generated client makes the counts visible.

6. **Ranked results schema is a stub.** The spec declares only
   `schema_version` (enum `lps-ranked-results/v1`) and `sheet_id`. The prose
   contract promises source colors, scores, labels, capture provenance,
   printer profile, and scoring algorithm version. Endpoint gap: ranked-result
   details are untyped for the generated client until upstream widens the
   schema.

7. **Operation IDs are absent upstream.** open_api_spex defaults them to
   `ColorMatchingWeb.TestSheetController.manifest`-style values, which the
   Swift generator sanitizes to
   `ColorMatchingWeb_period_TestSheetController_period_manifest`. The vendored
   document must declare explicit operation IDs
   (`getTestSheetManifest`, `listRecentTestSheets`, `getRankedResults`,
   `createCapture`, `uploadMeasurements`, `uploadJudgments`) — an additive,
   shape-preserving normalization. Follow-up: upstream the explicit operation
   IDs so regeneration needs no local edit.

8. **Declared but unused-by-iOS endpoints.** The spec also covers
   `GET /printer_profiles`, `GET /printer_profiles/{id}/colors`,
   `GET /printer_profiles/{id}/metamer_pairs`, `GET /palettes`, `GET /colors`,
   `POST /api/illuminant_measurements` (+ `/bulk`), and
   `POST /api/multi_image_mapping` — none documented in the prose contract.
   The last two were previously documented nowhere. Out of scope for this
   issue; noted because codegen pulls their types into the module regardless.

## What matches

- Routes, path parameter names (`sheet_id`, `capture_id`), bearer auth
  (`bearerAuth` on every app-facing operation), 201 for capture creation, 401 /
  404 / 422 error shapes, recent-sheets payload (`sheet_id`, `manifest_url`,
  nullable `title`), and judgment upload shape (`judgments[]` of
  `{pair_id, judgment}`) all match the prose contract.
