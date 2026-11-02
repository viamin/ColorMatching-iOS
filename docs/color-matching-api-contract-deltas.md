# Contract Deltas: Prose Doc vs. Published `viamin/color_matching` OpenAPI Spec

Research notes for #5 ("Replace hand-written API layer with a generated OpenAPI
Swift client"). `viamin/color_matching#110` ("Publish OpenAPI 3 spec for the
`/api/v1` API and enforce it in CI") is closed, merged via
`viamin/color_matching#113` (merge commit `094bd6d`). This document compares
`docs/color-matching-api-contract.md` against that merged source so the
eventual implementation PR can cite concrete deltas instead of assumptions.

Sources (read directly from a shallow clone of `viamin/color_matching` at
`094bd6d`, not reconstructed from memory):

- `lib/color_matching_web/router.ex`
- `lib/color_matching_web/api_spec.ex`
- `lib/color_matching_web/api_schemas.ex`
- `lib/color_matching_web/controllers/test_sheet_controller.ex`
- `lib/color_matching_web/controllers/test_sheet_json.ex`
- `lib/color_matching/ranked_results.ex`

## No static spec file to vendor

`GET /api/v1/openapi.json` is generated at runtime by `OpenApiSpex` from
`ColorMatchingWeb.ApiSpec`/`ApiSchemas`; nothing is checked into the repo as
`openapi.json`/`.yaml`. Vendoring the document (deliverable 1) requires either
running the real Phoenix app and curling that route, or a `mix` task that
dumps the spec — both out of reach in a sandbox with no database and no
Elixir toolchain. The implementation run will need network/CI access to a
running `color_matching` instance (or a spec artifact published some other
way) before `swift-openapi-generator` has anything to consume.

## Gap 1 (critical): published schemas for the two GET surfaces are far thinner than the real response bodies

- `ColorMatchingWeb.ApiSchemas.Manifest` only declares `schema_version`,
  `sheet_id`, and `capture_profile.scoring_algorithm_version` as
  properties/required. The real `TestSheetJSON.manifest/1` response also
  includes `sheet_version`, `manifest_url`, `created_at`, `page`,
  `registration_markers`, `printer_profile`, `patches`, and `pairs` — none of
  which appear in the schema.
- `ColorMatchingWeb.ApiSchemas.RankedResults` only declares `schema_version`
  and `sheet_id`. The real `TestSheetJSON.ranked_results/1` response also
  includes `printer_profile`, `capture_count`, `latest_capture_at`,
  `earliest_capture_at`, `scoring_algorithm_versions`, and a `results` array
  of per-pair rank/score/judgment/provenance data (see `ColorMatching.RankedResults.Pair`).

**Consequence:** `swift-openapi-generator`, run strictly against the
published document, produces `Components.Schemas.*` types for these two
operations that are missing almost every field this app needs. Either
`color_matching`'s schemas need to be fleshed out (worth raising upstream)
or the generated client's raw response for just these two operations needs a
hand-written decode layer on top, which partly undercuts "replace hand-written
models with generated types" for exactly the two surfaces (manifest, ranked
results) the app relies on most.

## Gap 2 (functional, pre-existing): no `ranked_results` client method at all

`GET /api/v1/test_sheets/:sheet_id/ranked_results` exists
(`TestSheetController.ranked_results/2`) and matches the prose doc's path.
`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift` has no corresponding
method today — this predates the OpenAPI work but is squarely one of the
"surfaces the app uses today" the issue asks to cover.

## Gap 3: upload responses are non-empty and are currently discarded

- `POST .../measurements` returns `MeasurementUploadResponse`:
  `capture_id`, `measurement_count`, `pair_score_count` (all required).
- `POST .../judgments` returns `JudgmentUploadResponse`: `capture_id`,
  `judgment_count` (both required).

The prose doc documents no response body for either endpoint, and
`APIClient.uploadMeasurements`/`uploadJudgments` only check the status code
via `send(request)`, discarding the body. The generated client should decode
and return these.

## Gap 4: current hand-written `SheetManifest` model drops fields the real server (and the prose doc) already sends

`iOS/Sources/MeasurementCore/Models.swift`'s `SheetManifest` has no
`printerProfile` or `captureProfile` property at all, even though both the
prose doc and the real response include them. This is a gap in today's
hand-written model, independent of the OpenAPI migration, and will need to
be closed either way.

## Informational (non-breaking) deltas

- `printer_profile` in the real manifest/ranked-results response is shaped
  as `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`,
  `print_settings`, `driver_name`, `driver_version`, `calibration_date`,
  `calibration_version`, `notes` — not the prose doc's `id`/`name`/`paper`/
  `ink`/`settings`. There is no `id` or `name` field on the real payload.
- `PairScoreRequest` requires `pair_id` + `algorithm_version` plus
  `anyOf: [score], [similarity], [distance]` (at least one, extras
  tolerated) — not a strict pairing of `distance`+`similarity`. Sending both,
  as the current client does, remains valid.
- `CaptureRequest` accepts `anyOf` a flattened top-level set of device/image
  fields **or** a nested `metadata` object; `quality` is not required by
  either branch. The current client's nested `metadata` + `quality` shape
  satisfies the schema; no change required.
- `linear_rgb_median`/`normalized_linear_rgb_median` use `RgbPayload`
  (`anyOf`: number array, `{r,g,b}` object, or string). The client only ever
  sends the object form, which is valid; the generic `Rgb` schema used by
  `/colors`/`/printer_profiles` (integer channels) is a different, unrelated
  schema and should not be conflated with `RgbPayload`.
- Error responses are formalized as `ErrorResponse`: `errors` is either a
  free-form object or an array of `{detail, source.pointer}` items. The
  prose doc doesn't document error shapes at all.
- Auth is a formal `bearerAuth` HTTP-bearer security scheme ("API token"
  format) — matches the prose doc's shared bearer token description.
- The real API exposes several endpoints this app doesn't use and shouldn't
  start using per the issue's non-goals: `/printer_profiles` (+ nested
  `/colors`, `/metamer_pairs`), `/palettes`, `/colors`,
  `/illuminant_measurements` (+ `/bulk`), `/multi_image_mapping`.

## Tests added against these findings

`iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientContractTests.swift` pins
the real field shapes found above (ranked results, measurement/judgment
upload responses, manifest printer/capture profile) against realistic
fixtures. These intentionally reference client methods/types
(`fetchRankedResults`, `RankedResults`, a non-`Void` return from
`uploadMeasurements`/`uploadJudgments`, `SheetManifest.printerProfile`/
`captureProfile`) that do not exist yet — this is the TDD red state for this
test-only phase. The follow-up implementation run (adding
`swift-openapi-generator`/`swift-openapi-runtime` to `Package.swift` and
generating/wiring the client) is expected to make this file compile and pass.
