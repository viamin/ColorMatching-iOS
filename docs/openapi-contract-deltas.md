---
title: "Contract deltas between docs/color-matching-api-contract.md and the published OpenAPI spec"
date: "2026-11-01"
category: "api-contract"
module: "iOS/Sources/ColorMatchingLPSAppCore"
problem_type: "contract_drift"
component: "api-client"
tags:
  - "openapi"
  - "swift-openapi-generator"
  - "color-matching-api-contract"
  - "contract-drift"
---

# Contract deltas: prose doc vs. the published `color_matching` OpenAPI spec

Tracking issue: #5 ("Replace hand-written API layer with a generated OpenAPI Swift client").
Upstream dependency: `viamin/color_matching#110`, implemented in `viamin/color_matching#113`
(merged at `094bd6d3443ddacbda7e63354299867eb5bdfa9f`).

`viamin/color_matching` does not commit a static `openapi.yaml`/`openapi.json` file. The
spec is generated at runtime by `ColorMatchingWeb.ApiSpec` (OpenApiSpex) and served from
`GET /api/v1/openapi.json`. There is no running server in this environment, so these
deltas were extracted by reading the generating source directly (schemas, router, and
controllers) at the merge commit above, cross-checked against
`test/color_matching_web/controllers/open_api_controller_test.exs`, which asserts on the
rendered spec's shape. Fetching the spec therefore means calling that endpoint from a
real deployment (or running the Phoenix app locally) once the generated client is wired
up — this doc is the input for that step, not a substitute for it.

## Findings that matter for the generated client

1. **`printer_profile` field names in the sheet manifest are wrong in the prose doc.**
   `docs/color-matching-api-contract.md` documents `id`, `name`, `paper`, `ink`, `settings`.
   The real renderer (`lib/color_matching_web/controllers/test_sheet_json.ex`,
   `render_printer_profile/1`) emits `printer_make_model`, `paper_type`, `ink_type`,
   `icc_profile`, `print_settings`, `driver_name`, `driver_version`, `calibration_date`,
   `calibration_version`, `notes` — no `id` at all. This app's `SheetManifest` model
   (`iOS/Sources/MeasurementCore/Models.swift`) doesn't decode `printer_profile` today, so
   there's no runtime break, but the generated client's `Components.Schemas.PrinterProfile`
   will use the real field names above, not the prose doc's.

2. **The live manifest never emits `role: "reference"` patches.** The prose doc documents
   `reference` as a patch role with `white`/`gray`/`black`/`blank_paper` reference roles,
   and `iOS/Sources/MeasurementCore/Normalization.swift` /
   `iOS/Sources/MeasurementCore/QualityAndScoring.swift` both branch on
   `patch.role == "reference"`. `TestSheetJSON.render_patches/2` only ever calls
   `render_patch(pair, side, color, rect, geometry)` with `role: "pair_color"` for every
   patch on every pair — there is no code path in the real sheet generator that emits a
   reference patch. One practical consequence already reproduced locally without a
   server: `QualityGate.hasPoorReferencePatch` (`QualityAndScoring.swift:59-68`) does
   `guard !references.isEmpty else { return true }`, so with zero reference patches it
   always returns `true`, and `SheetAnalyzer.analyze` (the path `ContentView.swift` calls
   for every real capture) always appends `.poorReferencePatch` to
   `CaptureQuality.rejections`. Against the real API as it stands today, every capture
   would be rejected for a reason that cannot be satisfied. See the new regression test
   `testQualityGateDoesNotRejectRealManifestsWithoutReferencePatches` in
   `iOS/Tests/MeasurementCoreTests/MeasurementCoreTests.swift`, which fails against the
   current `QualityGate` and documents the gap pending a fix decision (treat "no reference
   patches in the manifest" as "skip the poor-reference-patch check" rather than "always
   fail it").

3. **Measurement upload: `scoring_algorithm_version` is accepted but unused; `stats` and
   per-row `algorithm_version` are required but undocumented by the generated schema.**
   `ColorMatchingWeb.ApiSchemas.MeasurementUploadRequest` only documents `measurements`
   (with `patch_id`, `linear_rgb_median`, `normalized_linear_rgb_median`) and
   `pair_scores`, with nothing required. The real persistence code
   (`lib/color_matching/persistence/capture_upload.ex`,
   `normalize_measurement_attrs/2`) reads `stats.sample_count`,
   `stats.clipping_fraction`, `stats.mean`, `stats.standard_deviation` nested exactly as
   this app already sends them (comment in that file: *"The iOS contract nests
   robustness stats under 'stats'... Accept both, with the top-level value preferred."*),
   and `CapturePatchMeasurement.changeset/2` makes all four fields
   `validate_required`. So the generated request type will under-represent what the
   server actually requires unless the generator config or a wrapper adds `stats` back in.
   The top-level `scoring_algorithm_version` this app sends
   (`APIClient.swift`'s `MeasurementUploadRequest`) is not read anywhere server-side —
   only each pair score's own `algorithm_version` is used
   (`normalize_pair_score_attrs/2`). This app's `PairScore` model already sends
   `algorithm_version` per score, so no behavior change is needed there; the top-level
   field is dead weight that the generated client can drop.

4. **`normalized_linear_rgb_median` is required by the server but optional and
   silently omitted by this app's current encoder.**
   `CapturePatchMeasurement.changeset/2` requires `normalized_linear_rgb_median` on every
   measurement row. `PatchMeasurement.normalizedLinearRGBMedian`
   (`MeasurementCore/Models.swift`) is `RGB?`, and the hand-written
   `MeasurementUpload` wrapper (`APIClient.swift`) is a plain `Codable` struct, so Swift's
   synthesized encoder calls `encodeIfPresent` and drops the key entirely when the value
   is `nil` — a pre-normalization upload would get a 422 from the real API. See the new
   test `testUploadMeasurementsAlwaysIncludesNormalizedMedianKey` in
   `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`, which fails against the
   current `APIClient` and documents the gap.

5. **Measurement/judgment upload return `200 OK` with a JSON body, not `204 No Content`.**
   `CaptureController.handle_measurement_upload/3` and `handle_judgment_upload/3` both
   `put_status(:ok)` and render `{capture_id, measurement_count, pair_score_count}` /
   `{capture_id, judgment_count}`. This app's `APIClient.uploadMeasurements` /
   `uploadJudgments` are `Void`-returning and only validate the status code, so nothing
   breaks today, but the generated client should surface these response bodies — they're
   useful confirmation data the hand-written client silently throws away.

6. **Error responses have a real, undocumented shape.** The prose doc never describes
   error bodies. The real `ApiErrorResponse` schema is
   `{"errors": <object> | [{"detail": string, "source": {"pointer": string}}]}` — a
   changeset/plain error map, or a JSON:API-ish array of `{detail, source}` for
   request-validation failures (`OpenApiSpex.Plug.CastAndValidate`,
   `json_render_error_v2: true`, used by `TestSheetController`). `APIClient.APIError` is
   currently just `case badStatus` with no decoded error body; the generated client
   should decode `ApiErrorResponse` for non-2xx responses so failures are inspectable.

7. **The documented API is a strict subset of the real `/api/v1` surface.** The router
   (`lib/color_matching_web/router.ex`) and the spec's path list (asserted in
   `open_api_controller_test.exs`) also include `printer_profiles`,
   `printer_profiles/:id/colors`, `printer_profiles/:id/metamer_pairs`, `palettes`,
   `colors` (all under `/api/v1`), plus `/api/illuminant_measurements`,
   `/api/illuminant_measurements/bulk`, and `/api/multi_image_mapping`. None of these are
   in `docs/color-matching-api-contract.md` and none are capture/judgment/manifest
   surfaces this app uses — out of scope for this change per the issue's non-goals, but
   worth knowing they exist in the same spec document the generator will ingest.

8. **Ranked results has a real, richer shape than the one-line prose description.**
   `TestSheetJSON.ranked_results/1` and `render_ranked_result/1` emit
   `schema_version: "lps-ranked-results/v1"`, `sheet_id`, `printer_profile`,
   `capture_count`, `latest_capture_at`, `earliest_capture_at`,
   `scoring_algorithm_versions` (plural, array), and a `results` array of
   `{rank, pair_id, scoring_algorithm_version, row, col, source_colors: {color_a_hex,
   color_b_hex}, score: {average, latest, minimum, maximum, capture_count, sample_count,
   algorithm_versions}, current_judgment, current_judgment_observed_at,
   observation_count, latest_observation: {judgment, observed_at} | null, capture_count,
   latest_capture_at, earliest_capture_at}`. The generated `ApiSchemas.RankedResults`
   component itself only formally requires `schema_version`/`sheet_id` (OpenApiSpex isn't
   told about the rest), so the generated Swift type may need a hand-maintained
   `additionalProperties`-based decode, or an upstream spec fix, to get the full shape
   typed. This app has no ranked-results model today, so this is net-new rather than a
   behavior change.

9. **`manifest_url` may be host-relative.** `TestSheetJSON.manifest_url/1` builds the URL
   with `url(~p"/api/v1/test_sheets/#{sheet.lookup_code}/manifest")` — a Phoenix verified
   route helper. Whether that resolves to an absolute URL depends on the endpoint's
   configured host at render time. `RecentSheet.manifestURL` and `SheetManifest`'s
   `manifest_url` are both typed `URL` and decoded directly; if a deployment ever renders
   a host-relative path, decoding still succeeds (`URL(string:)` accepts relative strings)
   but the resulting `URL` has no scheme/host and can't be used standalone — it would need
   resolving against the API's base URL. Not reproduced against a live server; flagged
   for whoever generates the client against a real deployment to double check.

## What this means for the generator step

- Points 1, 2, 4, 6, 8 are the ones worth raising upstream or handling deliberately when
  the client is generated: (1) is cosmetic since this app doesn't use the field yet; (2)
  is a functional bug this app should fix regardless of the client generator (treat zero
  reference patches as "nothing to check" rather than "automatic failure"); (4) is a
  genuine encoding bug to fix when switching to generated request types; (6) and (8) are
  places where the generated Swift types will be thinner than what the server actually
  sends/accepts, and the generator step should decide whether to patch the upstream spec,
  accept the thin types, or hand-wrap them.
- Point 3 confirms the nested `stats` shape and per-score `algorithm_version` this app
  already sends are correct and should carry over unchanged to the generated request
  types; only the dead top-level `scoring_algorithm_version` field should be dropped.
- Points 5 and 7 don't require any app behavior change; 5 is an opportunity to use data
  the generated client makes available for free, 7 is explicitly out of scope.

## Evidence

- `viamin/color_matching` PR #113 (merged, `094bd6d3443ddacbda7e63354299867eb5bdfa9f`),
  specifically `lib/color_matching_web/api_schemas.ex`, `lib/color_matching_web/api_spec.ex`,
  `lib/color_matching_web/router.ex`, `lib/color_matching_web/controllers/capture_controller.ex`,
  `lib/color_matching_web/controllers/test_sheet_controller.ex`,
  `lib/color_matching_web/controllers/test_sheet_json.ex`,
  `lib/color_matching/persistence/capture_upload.ex`,
  `lib/color_matching/persistence/capture_patch_measurement.ex`, and
  `test/color_matching_web/controllers/open_api_controller_test.exs`.
- `main` at `viamin/color_matching` was 9 commits ahead of that merge as of 2026-11-01,
  all dependency bumps (`mix.lock` only) — none of the files above changed since the merge.
