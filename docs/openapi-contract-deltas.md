---
module: ColorMatchingLPSAppCore
tags: [api, openapi, contract]
problem_type: spec-drift
---

# Contract deltas: `docs/color-matching-api-contract.md` vs. the published OpenAPI spec

This records what [#5](https://github.com/viamin/ColorMatching-iOS/issues/5) asks for: the
differences found between the hand-written prose contract in
`docs/color-matching-api-contract.md` and the real `/api/v1` API, now that
`viamin/color_matching#110` ("Publish OpenAPI 3 spec for the `/api/v1` API and enforce it in CI")
is closed via `viamin/color_matching#113`.

The upstream spec is served dynamically from `GET /api/v1/openapi.json`
(`ColorMatchingWeb.OpenApiController`/`ApiSpec`) rather than checked into the repo as a static
file, and this environment has no Phoenix/Postgres runtime to render it. The vendored document at
`docs/api/color-matching-openapi.v1.json` was reconstructed instead, straight from upstream source
at commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f`:
`lib/color_matching_web/api_schemas.ex`, `api_spec.ex`, `controllers/test_sheet_json.ex`,
`controllers/capture_controller.ex`, `persistence/capture_upload.ex`, and the controller test files
for test sheets, captures, and ranked results. It only covers the six operations this app calls
today (manifest, recent sheets, ranked results, create capture, upload measurements, upload
judgments) per the issue's non-goal of not adding new endpoints.

## Deltas found

1. **`printer_profile` field names are completely different.** The prose contract documented
   `{id, name, paper, ink, settings}`. The real renderer
   (`TestSheetJSON.render_printer_profile/1`) emits
   `{printer_make_model, paper_type, ink_type, icc_profile, print_settings, driver_name,
   driver_version, calibration_date, calibration_version, notes}` and never emits an `id` at all.
   This appears in both the manifest and ranked-results responses.

2. **`ranked_results` had no concrete schema at all.** The prose contract only says the endpoint
   "should return ... ranked results with source colors, scores, labels, capture provenance,
   printer profile, and scoring algorithm version" — no field names, types, or nesting. The real
   response (`TestSheetJSON.ranked_results/1`) is a fully specified, deeply nested shape:
   `schema_version`, `sheet_id`, `printer_profile`, `capture_count`, `latest_capture_at`,
   `earliest_capture_at`, `scoring_algorithm_versions[]`, and `results[]` where each result has
   `rank`, `pair_id`, `scoring_algorithm_version`, `row`, `col`, `source_colors`, a nested `score`
   object (`average`/`latest`/`minimum`/`maximum`/`capture_count`/`sample_count`/
   `algorithm_versions`), `current_judgment`, `current_judgment_observed_at`, `observation_count`,
   `latest_observation`, and capture provenance timestamps. A single pair can appear more than once
   in `results` — once per scoring algorithm version it has been scored under — so results are
   keyed by `(pair_id, algorithm_version)`, not by `pair_id` alone.

3. **Measurement upload has no top-level `scoring_algorithm_version` and no `stats` requirement.**
   The prose contract's request body has a shared top-level `scoring_algorithm_version` and nests
   `sample_count`/`clipping_fraction`/`mean`/`standard_deviation` under a per-measurement `stats`
   object. The real schema (`ApiSchemas.MeasurementUploadRequest`/`PairScoreRequest`) has no
   top-level `scoring_algorithm_version` field; each `pair_scores[]` entry instead carries its own
   `algorithm_version`. `CaptureUpload.normalize_measurement_attrs/2` does accept a nested `stats`
   object for backward compatibility with this app's exact contract (explicitly commented "The iOS
   contract nests robustness stats under 'stats'"), but also accepts those four fields flattened at
   the top level, preferring the flat value when both are present. `CaptureController` does not run
   `OpenApiSpex.Plug.CastAndValidate`, so an extraneous top-level `scoring_algorithm_version` the
   app still sends is silently ignored rather than rejected.

4. **`linear_rgb_median`/`normalized_linear_rgb_median`/`mean`/`standard_deviation` accept three
   shapes, not just `{r,g,b}`.** `ApiSchemas.RgbPayload` is `anyOf [number array, {r,g,b} object,
   JSON-encoded string]`. The app only ever sends the `{r,g,b}` object form, which remains valid.

5. **Pair scores accept `score`, `similarity`, or `distance` interchangeably, and the server
   clamps them.** The prose contract's example shows both `distance` and `similarity` on the same
   payload; the real resolution order in `CaptureUpload.resolve_score/1` is
   `score > similarity > (1.0 - distance)`, and every branch clamps into `[0,1]` — an
   out-of-range `score`/`similarity`/`distance` is accepted and silently clamped rather than
   rejected with a 422.

6. **Measurement and judgment uploads return a JSON body; the prose contract showed none.** The
   real responses are `{capture_id, measurement_count, pair_score_count}` (200) and
   `{capture_id, judgment_count}` (200) respectively. The current hand-written `APIClient.
   uploadMeasurements`/`uploadJudgments` (`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift:33-47`)
   only validates the status code and discards the body — not wrong, but the generated client
   should expose these counts since the server now guarantees them.

7. **`recent sheets`' `title` is always `null` today, not merely nullable.**
   `TestSheetJSON.render_recent_sheet/1` hardcodes `title: nil` unconditionally — the server has no
   sheet-title field yet. The prose contract's "`title` may be `null`" is technically true but
   undersells that it is *currently always* null.

8. **Capture creation also accepts a flattened body shape the app doesn't use.**
   `ApiSchemas.CaptureRequest` is `anyOf [{the metadata fields flattened at top level}, {metadata
   required}]`. The app's nested `{metadata, quality}` body (per the prose contract) satisfies the
   `required: [metadata]` branch and keeps working unchanged; this is a widening, not a breaking
   change.

9. **Validation error shapes vary by endpoint and are richer than the prose contract's `{"errors":
   {...}}` example.** Capture creation returns flat field-error maps
   (`{"detected_marker_count": [...], "image_width": [...]}`); measurement/judgment row-level
   failures return `{"errors": {"measurements": [{"index", "patch_id"|"pair_id", "errors"}], ...}}`.
   Both are covered by the published `ApiErrorResponse` schema's `oneOf` (object | json:api array),
   but the prose contract only showed the plain-object case.

## Endpoint gaps / out of scope

`viamin/color_matching#110`'s own description calls out two endpoints documented nowhere before
this spec: `/api/illuminant_measurements` and `/api/multi_image_mapping`. Neither is used by this
app's current capture/scoring flow (manifest → capture → measurements → judgments → ranked
results), so they are intentionally excluded from `docs/api/color-matching-openapi.v1.json` per
this issue's non-goal of not adding new endpoints. The same is true of `/api/v1/printer_profiles`,
`/api/v1/palettes`, and `/api/v1/colors`, which exist upstream (serving the macOS companion app's
`PaletteAPIClient`) but have no caller in this repository today.

## Gap in the published spec itself

The OpenApiSpex schemas upstream registers for `Manifest` and `RankedResults`
(`ApiSchemas.Manifest`/`ApiSchemas.RankedResults`) are intentionally minimal — just enough for
`OpenApiSpex.Plug.CastAndValidate`-style response typing, not full documentation. They only assert
`{schema_version, sheet_id, capture_profile.scoring_algorithm_version}` and `{schema_version,
sheet_id}` respectively. A generator pointed directly at the real `openapi.json` would produce
`Components.Schemas.TestSheetManifest`/`RankedResults` types missing nearly every field the actual
JSON views render (page, registration_markers, printer_profile, patches, pairs, results, scores,
...). `docs/api/color-matching-openapi.v1.json` reconstructs the full shape from the view code and
controller tests instead of generating directly off the published document for these two
operations. Worth a follow-up issue upstream to make `ApiSchemas.Manifest`/`RankedResults`
describe their real response bodies.

## Assumptions for the generated-client implementation phase

This test-writing phase pins `operationId`s in the vendored spec
(`getTestSheetManifest`, `listRecentTestSheets`, `getRankedResults`, `createCapture`,
`uploadMeasurements`, `uploadJudgments`) and writes
`iOS/Tests/ColorMatchingLPSAppTests/GeneratedAPIClientTests.swift` against the standard
swift-openapi-generator 1.x conventions: a vendored client package target named `ColorMatchingAPI`
generating `Operations.<operationId>.{Input,Output}`, `Components.Schemas.<Name>`, and a `Client`
type constructed as `Client(serverURL:transport:)` against an injected
`OpenAPIRuntime.ClientTransport`. The implementation phase must either match these names or update
the tests to match whatever the generator actually emits; this file has no Swift toolchain
available to compile-check that assumption (see run notes), only the upstream Elixir/JSON sources.
