# Deltas Between `docs/color-matching-api-contract.md` And The Published OpenAPI Spec

This is test-phase evidence for [#5 — Replace hand-written API layer with a generated
OpenAPI Swift client](https://github.com/viamin/ColorMatching-iOS/issues/5). It compares the
hand-written prose contract against the API `viamin/color_matching` actually publishes now
that [#110](https://github.com/viamin/color_matching/issues/110) is done
([PR #113](https://github.com/viamin/color_matching/pull/113), merged 2026-10-30, commit
`094bd6d3443ddacbda7e63354299867eb5bdfa9f`). It's meant to be folded into the implementation
PR's description per the issue's exit criteria.

The spec itself isn't a static file in `color_matching` — it's rendered at request time by
`OpenApiSpex.Plug.RenderSpec` at `GET /api/v1/openapi.json` (see
`lib/color_matching_web/controllers/open_api_controller.ex` and
`lib/color_matching_web/router.ex`). Vendoring it for `swift-openapi-generator` means either
running the Phoenix app once and capturing that response, or treating
`lib/color_matching_web/api_spec.ex` + `api_schemas.ex` as the source of truth. Either way,
fetching it is implementation work for the follow-up run, not this test-writing run.

## Confirmed matches (no action needed)

- `POST /api/v1/test_sheets/:sheet_id/captures` nested `{metadata, quality}` body — the real
  `CaptureRequest` schema's `anyOf` explicitly allows this nested shape (the other branch is a
  flat top-level alternative the app doesn't use), and `CaptureMetadata`/`quality` field names
  match the current Swift `CaptureMetadata`/`CaptureQuality` exactly.
- `POST /api/v1/captures/:capture_id/judgments` body (`{judgments: [{pair_id, judgment}]}`) —
  exact match with `JudgmentUploadRequest`.
- `capture_id` in the create-capture response is a string — matches `CaptureSessionResponse`.

## Deltas found

1. **`printer_profile` field names in the manifest are completely different from the prose
   doc**, and the app doesn't model the object at all. Prose doc: `{id, name, paper, ink,
   settings}`. Real (`ColorMatchingWeb.ApiSchemas.PrinterProfile` /
   `TestSheetJSON.render_printer_profile/1`): `{printer_make_model, paper_type, ink_type,
   icc_profile, print_settings, driver_name, driver_version, calibration_date,
   calibration_version, notes}`. `SheetManifest` (`iOS/Sources/MeasurementCore/Models.swift`)
   has no `printerProfile` property, so this is silently dropped on decode today.
   See `ManifestSchemaDriftTests.swift`.

2. **`SheetManifest` is also missing `created_at` and `capture_profile`.** The latter carries
   `scoring_algorithm_version`, which the real `Manifest` OpenAPI schema requires — i.e. the
   server considers it the authoritative compatibility signal, but the app currently hardcodes
   `LPSScorer.algorithmVersion` client-side instead of reading it from the manifest. Flagging
   only; reconciling the two is scoring behavior and out of scope per this issue's non-goals.

3. **The published `Manifest` and `RankedResults` OpenAPI schemas are themselves
   under-specified relative to what the server actually renders.** Formally, `Manifest` only
   requires/types `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`;
   `RankedResults` only requires `schema_version` and `sheet_id`. The real JSON bodies
   (`TestSheetJSON.manifest/1`, `TestSheetJSON.ranked_results/1`) are far richer — e.g.
   `page`, `registration_markers`, `patches`, `pairs` for the manifest, and a full
   `results: [{rank, pair_id, scoring_algorithm_version, row, col, source_colors, score:
   {average, latest, minimum, maximum, capture_count, sample_count, algorithm_versions},
   current_judgment, current_judgment_observed_at, observation_count, latest_observation,
   capture_count, latest_capture_at, earliest_capture_at}]` for ranked results. A generated
   client built strictly from the formal schema would under-type both responses; the extra
   fields will need `anyOf`/loose-object handling or an upstream schema fix
   (`lib/color_matching_web/api_schemas.ex`) before codegen can produce full typed models.

4. **`GET /api/v1/test_sheets/:sheet_id/ranked_results` has no client-side implementation at
   all.** `APIClient.swift` has no `fetchRankedResults` method, even though the issue lists
   "ranked results" as one of the surfaces to cover. This is the main endpoint gap for the
   implementation run to close.

5. **`recent.sheets[].title` is always `null` server-side today** (`render_recent_sheet/1`
   hardcodes `title: nil`), unlike the prose doc's titled example. Not a client bug — the
   feature just isn't implemented upstream yet.

6. **The published `MeasurementUploadRequest` schema has no top-level
   `scoring_algorithm_version` and no per-measurement `stats`**, both of which the current
   client sends (`APIClient.uploadMeasurements`, `MeasurementUploadRequest`/`MeasurementUpload`
   in `APIClient.swift`). The real schema's only declared properties are `measurements` (each
   `{patch_id, linear_rgb_median, normalized_linear_rgb_median}`) and `pair_scores` (each
   `{pair_id, algorithm_version, score?/similarity?/distance?}`). Extra JSON properties aren't
   rejected by default OpenAPI validation, so this isn't failing today, but a generated client
   built from the real schema won't have anywhere to put `stats` or
   `scoring_algorithm_version` — the implementation run needs to decide whether that data is
   dropped or the upstream schema needs to grow those fields first. See
   `APIClientTests.testUploadMeasurementsRequestFieldsMatchPublishedOpenAPISchema`.

7. **Measurement/judgment upload responses carry data the client discards.** The real
   `MeasurementUploadResponse` is `{capture_id, measurement_count, pair_score_count}` and
   `JudgmentUploadResponse` is `{capture_id, judgment_count}`; `APIClient.uploadMeasurements`
   and `uploadJudgments` both call the fire-and-forget `send(_:)` helper and never decode a
   response body.

## Endpoint gaps out of scope for this app

`POST /api/illuminant_measurements` (+ `/bulk`) and `POST /api/multi_image_mapping` are real,
documented endpoints the spec now covers, but this app never calls them (they belong to the
macOS companion's `PaletteAPIClient` per color_matching#110's own description). No action
needed here.

## Why no generated-client code lands in this PR

This run is scoped to test-writing only (TDD boundary): changes are restricted to test paths
and this `docs/` allowlist. Adding `swift-openapi-generator`/`swift-openapi-runtime`, vendoring
the spec, and generating the client all touch `iOS/Package.swift` and `iOS/Sources`, which are
implementation files reserved for the follow-up run once these tests are reviewed. Separately,
this sandbox has no Swift toolchain (`swift` is not on `PATH`), so `swift test` could not be
run here; the two new tests below were written to compile against the *existing* public API
surface so they can still be reasoned about statically, and are expected to be exercised by CI.

## Tests added this run

- `APIClientTests.testUploadMeasurementsRequestFieldsMatchPublishedOpenAPISchema` — red: fails
  today because the client sends `stats` and `scoring_algorithm_version`, which the published
  schema doesn't declare.
- `ManifestSchemaDriftTests.testManifestModelsEveryFieldThePublishedManifestEndpointReturns` —
  red: fails today because `SheetManifest` has no properties for `created_at`,
  `printer_profile`, or `capture_profile`.
