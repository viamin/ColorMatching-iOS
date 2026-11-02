# `color_matching` OpenAPI Contract Deltas

Prose contract (`docs/color-matching-api-contract.md`) versus the published
OpenAPI 3 spec from `viamin/color_matching#110`. This document is the PR-body
source of record for "what changed between the prose contract and the published
spec, and any endpoint gaps discovered".

## Provenance

The Phoenix app now publishes a machine-readable spec built with `open_api_spex`:

- Spec definition: `lib/color_matching_web/api_spec.ex` (paths derived from the
  router; `bearerAuth` security scheme).
- Schemas: `lib/color_matching_web/api_schemas.ex`.
- Served at `GET /api/v1/openapi.json` (unauthenticated) via
  `ColorMatchingWeb.OpenApiController`.
- The exact rendered document can be fetched from a running server; the source
  modules above are the ground truth used for this analysis.

## Endpoint coverage: no gaps for the app's surfaces

All six operations the iOS app uses today exist in the published spec:

| App surface | Published operation |
| --- | --- |
| Test-sheet manifest | `GET /api/v1/test_sheets/{sheet_id}/manifest` |
| Recent sheets | `GET /api/v1/test_sheets/recent` |
| Capture session creation | `POST /api/v1/test_sheets/{sheet_id}/captures` |
| Measurement upload | `POST /api/v1/captures/{capture_id}/measurements` |
| Judgment upload | `POST /api/v1/captures/{capture_id}/judgments` |
| Ranked results | `GET /api/v1/test_sheets/{sheet_id}/ranked_results` |

The spec also documents endpoints the app does not use (printer profiles,
palettes, colors, metamer pairs, illuminant measurements, multi-image mapping).
Authentication matches the prose contract: `bearerAuth` (`http`/`bearer`) on all
`/api/v1` application endpoints.

## Contract deltas found

1. **Manifest schema is under-documented.** The published `TestSheetManifest`
   requires only `schema_version`, `sheet_id`, and
   `capture_profile.scoring_algorithm_version`. The server actually emits the
   full prose manifest (`sheet_version`, `manifest_url`, `created_at`, `page`,
   `registration_markers`, `printer_profile`, `patches`, `pairs` — see
   `ColorMatchingWeb.TestSheetJSON.manifest/1`), but the spec does not document
   those fields. A generated client from the published spec alone cannot see
   `patches`/`pairs`, which the app needs for sampling and scoring.
2. **`printer_profile` shape differs from prose.** Prose: `{id, name, paper,
   ink, settings}`. Actual payload: `{printer_make_model, paper_type, ink_type,
   icc_profile, print_settings, driver_name, driver_version, calibration_date,
   calibration_version, notes}` — no `id` or `name` keys.
3. **No reference patches are emitted.** Prose documents `reference` patches
   (`white`, `gray`, `black`, `blank_paper`) and the app's normalization depends
   on them, but the server renders only `role: "pair_color"` patches with
   `reference_role: null`. Behavioral gap on the Phoenix side.
4. **Patch IDs are structured.** Actual patch IDs are `"{pair_id}#first"` /
   `"{pair_id}#second"` (e.g. `pair_1#first`), not the prose example `patch_1`.
   Opaque strings, so still app-compatible; recorded for fixtures.
5. **Capture request accepts two shapes.** The published `CaptureRequest`
   allows a flat legacy shape (`exposure_duration`, `rejection_reasons` — key
   names differ from prose) or the prose nested `{metadata, quality}` shape.
   The app uses the nested shape, which the spec supports. `CaptureMetadata`
   marks `image_width`/`image_height` as required (prose implied, never
   stated). The nested `quality` object documents no required fields.
6. **Measurement upload drift.**
   - No top-level `scoring_algorithm_version` in the spec; `algorithm_version`
     is required per pair score, with `anyOf` `score`/`similarity`/`distance`.
     The server maps `distance` to a stored score of `1 - distance` and clamps
     to `[0, 1]` (`CaptureUpload.resolve_score/1`).
   - The spec marks `normalized_linear_rgb_median` required per measurement,
     but the server treats it as optional and stores `nil` when absent
     (`CaptureUpload.normalize_measurement_attrs/2`).
   - The spec does not document per-measurement `stats` (`sample_count`,
     `clipping_fraction`, `mean`, `standard_deviation`), but the server parses
     and persists them from either the nested `stats` object or flat keys.
   - RGB values are `RgbPayload` (`anyOf`: number array | `{r,g,b}` object |
     string), where prose documented only the object form.
   - Undocumented rule: an upload must contain at least one measurement or pair
     score.
7. **Upload responses now have bodies.** Measurement upload returns `200`
   `{capture_id, measurement_count, pair_score_count}`; judgment upload returns
   `200` `{capture_id, judgment_count}`. Prose documented no response bodies
   (and the current hand-written client treats empty-body `204` as success; it
   only checks 2xx, so it never noticed).
8. **Judgment values are spec-free strings.** Prose documents
   `match`/`near_match`/`no_match`; the published spec allows any string, while
   the server actually validates inclusion in exactly those three values
   (`PairFindingObservation` changeset).
9. **Ranked results schema is a stub.** Published `RankedResults` requires only
   `schema_version` (`lps-ranked-results/v1`) and `sheet_id`. The server emits
   a rich payload (`capture_count`, capture time windows,
   `scoring_algorithm_versions`, `printer_profile`, and a `results` array with
   `rank`, `pair_id`, `row`/`col`, `source_colors`, aggregate `score`
   (`average`/`latest`/`minimum`/`maximum`/`sample_count`),
   `current_judgment`, `observation_count`, `latest_observation`) — none of it
   documented in the spec.
10. **Error responses are documented.** `401`/`404`/`422` on the app-facing
    operations return `ApiErrorResponse` (`errors` as an object or an array of
    `{detail, source{pointer}}`). Prose did not document error shapes.

## Required vendored-spec extensions

The vendored copy at `iOS/OpenAPI/color-matching-api-v1.json` starts from the
published spec and extends the under-documented schemas to match the payloads
the server actually emits or accepts (each extension is a recorded delta above,
with an upstream follow-up for `viamin/color_matching` to catch up):

- `TestSheetManifest`: require the full manifest shape (`sheet_version`,
  `manifest_url`, `created_at`, `page`, `registration_markers`,
  `printer_profile`, `capture_profile`, `patches`, `pairs`); document patch,
  pair, rect, page, and actual `printer_profile` field shapes.
- `MeasurementUploadRequest`: document `stats` per measurement; make
  `normalized_linear_rgb_median` optional (matches server behavior).
- `JudgmentUploadRequest`: constrain `judgment` to the
  `match`/`near_match`/`no_match` enum the server enforces.
- `RankedResults`: require and document the `results` array and aggregate
  envelope.

## Expected iOS implementation surface

The contract encoded by the tests in
`iOS/Tests/ColorMatchingLPSAppTests/`:

- SwiftPM: `swift-openapi-generator` (plugin), `swift-openapi-runtime`, and
  `swift-openapi-urlsession-compatibility` added to `iOS/Package.swift`; the
  vendored document lives at `iOS/OpenAPI/color-matching-api-v1.json`; the
  generated module is named `ColorMatchingOpenAPIClient`.
- `ColorMatchingLPSAppCore` gains a `ColorMatchingService` wrapper over the
  generated `Client` that keeps using the app's existing client-side models
  (`CaptureMetadata`, `CaptureQuality`, `PatchMeasurement`, `PairScore`,
  `PairJudgment`) as inputs and returns generated types
  (`Components.Schemas.TestSheetManifest`, `RecentSheetsResponse`,
  `CaptureCreatedResponse`, `MeasurementUploadResponse`,
  `JudgmentUploadResponse`, `RankedResults`).
- Wrapper errors: `ColorMatchingServiceError` with `sheetNotFound` (documented
  404 on manifest/ranked results), `unauthorized` (401), `validationFailed`
  (422), `unexpectedStatusCode(Int)` (anything else, including undocumented
  statuses surfaced by the generated client).
- Hand-written wire models in `APIClient.swift` are deleted once the wrapper
  replaces them; `MeasurementCore` domain models stay.

## Acceptance criteria to verification map

| Criterion | Verification |
| --- | --- |
| `swift-openapi-generator` + runtime in package; spec vendored | `OpenAPISpecCoverageTests` (unit test over the vendored JSON; red until vendored) |
| Generated client for all six surfaces | `GeneratedClientServiceTests` stubbed-response tests per operation |
| Hand-written wire models replaced; client-side models kept | `GeneratedClientServiceTests` (wrapper over generated types, app models as inputs) + implementation diff review |
| Swift tests against local stubbed responses, no live server | `GeneratedClientServiceTests` uses a stubbed `URLProtocol`; no network in CI |
| PR records contract deltas and endpoint gaps | This document (see "Contract deltas found" and "Endpoint coverage") |
| `swift test --disable-sandbox` green with generated types | CI on `macos-latest` (`.github/workflows/ci.yml`); not runnable in this Linux container (no Swift toolchain) |
