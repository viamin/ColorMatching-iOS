# Contract Deltas: Prose Doc vs. Published OpenAPI Spec (Issue #5)

This records what changed between the hand-written prose contract
(`docs/color-matching-api-contract.md`) and the real `/api/v1` API, for the
"Replace hand-written API layer with a generated OpenAPI Swift client" work
(issue #5, depends on `viamin/color_matching#110`).

## Status of the dependency

`viamin/color_matching#110` ("Publish OpenAPI 3 spec for the /api/v1 API and
enforce it in CI") is closed. It was implemented in
[`viamin/color_matching#113`](https://github.com/viamin/color_matching/pull/113),
merged at commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f`. The spec is
**served dynamically** at `GET /api/v1/openapi.json` (built at runtime from
`OpenApiSpex` struct literals in `lib/color_matching_web/api_spec.ex` and
`lib/color_matching_web/api_schemas.ex`) — there is no static spec file
committed to that repo to vendor directly.

**Action needed before codegen**: the implementation run should fetch the
live spec from a running `color_matching` instance (`GET
/api/v1/openapi.json`) and vendor that exact byte-for-byte response, rather
than hand-transcribing it. The findings below come from reading the Elixir
source directly (`api_spec.ex`, `api_schemas.ex`, `router.ex`,
`test_sheet_controller.ex`, `test_sheet_json.ex`, `capture_controller.ex` at
the commit above) and are believed accurate, but a hand-transcription is not
an acceptable substitute for the real generator input.

## Endpoints this app actually uses

Confirmed current in `ColorMatchingWeb.Router` (`scope "/api/v1"`, pipe
`[:api, :api_auth]`):

- `GET /api/v1/test_sheets/:sheet_id/manifest`
- `GET /api/v1/test_sheets/recent`
- `GET /api/v1/test_sheets/:sheet_id/ranked_results`
- `POST /api/v1/test_sheets/:sheet_id/captures`
- `POST /api/v1/captures/:capture_id/measurements`
- `POST /api/v1/captures/:capture_id/judgments`

Two unrelated endpoints exist under `/api` (not `/api/v1`) that this app does
not and should not consume: `POST /api/illuminant_measurements[/bulk]` and
`POST /api/multi_image_mapping`. They are mentioned in `color_matching#110`'s
own description as previously-undocumented endpoints for the *macOS* app's
`PaletteAPIClient`, not this iOS app.

## Findings

### 1. The published schema for the two richest endpoints is much thinner than the real response

`ColorMatchingWeb.ApiSchemas.Manifest` only declares `schema_version`,
`sheet_id`, and `capture_profile.scoring_algorithm_version` as validated
properties. `ColorMatchingWeb.ApiSchemas.RankedResults` only declares
`schema_version` and `sheet_id`. Neither formally describes `patches`,
`pairs`, `page`, `registration_markers`, `printer_profile`, or any of the
`ranked_results` per-pair fields — even though the actual JSON renderer
(`ColorMatchingWeb.TestSheetJSON`) emits all of them. A client generated
naively from the published spec alone would get a nearly untyped manifest
and ranked-results type for exactly the two endpoints this app relies on
most for structured data. **This is the most important gap to flag in the
generator PR** — the generated types for these two operations will likely
need the schemas tightened upstream in `color_matching`, or the
`additionalProperties`/response shape asserted by hand-written fixture tests
(as added in this PR) until that happens.

### 2. `printer_profile` shape has changed completely from the prose doc

Prose doc (`docs/color-matching-api-contract.md`):
```json
"printer_profile": {"id": "printer_profile_1", "name": "...", "paper": "...", "ink": "...", "settings": {}}
```

Real renderer (`TestSheetJSON.render_printer_profile/1`):
```json
"printer_profile": {
  "printer_make_model": "...", "paper_type": "...", "ink_type": "...",
  "icc_profile": null, "print_settings": {}, "driver_name": null,
  "driver_version": null, "calibration_date": null, "calibration_version": null,
  "notes": null
}
```

There is no `id` field at all in the real payload, and every other field was
renamed. `MeasurementCore.SheetManifest` does not currently decode
`printer_profile` (or `capture_profile`) at all, so this renaming has not
broken decoding — the data is simply dropped on the floor today. The
generated client should decide whether to expose `printer_profile` on the
manifest type; if so, the Swift-side consumer needs new field names.

### 3. Ranked results has no client surface at all today

Neither `APIClient` nor `MeasurementCore` has a method or model for `GET
/api/v1/test_sheets/:sheet_id/ranked_results`. The real response is rich:
`schema_version` (`lps-ranked-results/v1` — a new, previously undocumented
schema version string), sheet-level capture/time range summary, and a
per-pair `results[]` array with `rank`, `score` (average/latest/min/max over
captures), `current_judgment`, `latest_observation`, and provenance. This is
a net-new surface for the generated client, not a drift fix. See
`testRankedResultsEndpointHasNoClientSurfaceYet` in
`iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` for a fixture of
the real payload and a failing marker test for this gap.

### 4. `recent` sheets' `title` is always `null` today, not merely nullable

`TestSheetJSON.render_recent_sheet/1` hardcodes `title: nil` unconditionally.
The prose doc's "`title` may be `null`" was accurate but undersold that it
is *currently always* null — there is no code path that populates it yet.

### 5. Measurement/judgment uploads now return typed confirmation bodies the client ignores

`MeasurementUploadResponse` (`{capture_id, measurement_count,
pair_score_count}`) and `JudgmentUploadResponse` (`{capture_id,
judgment_count}`) are real, documented 200-OK response bodies. The
hand-written `APIClient.uploadMeasurements`/`uploadJudgments` only validate
the status code and discard the body entirely. Worth surfacing these counts
once generated types exist, for upload-confirmation UI.

### 6. The measurement-upload request's real schema doesn't model raw `stats` or a top-level `scoring_algorithm_version`

`ColorMatchingWeb.ApiSchemas.MeasurementUploadRequest` only validates
`measurements[].{patch_id, linear_rgb_median, normalized_linear_rgb_median}`
and `pair_scores[].{pair_id, algorithm_version, ...}` — there is no top-level
`scoring_algorithm_version` field, and no `stats` sub-object on each
measurement. The hand-written `APIClient` currently sends both (matching the
prose doc). Because `OpenApiSpex` schemas default to allowing additional
properties, these extra fields aren't rejected, but they also aren't part of
the validated/documented contract — worth confirming server-side
(`ColorMatching.Persistence.upload_capture_measurements/2`) whether `stats`
is actually persisted before dropping it from the generated client's request
type.

### 7. `linear_rgb_median` / `normalized_linear_rgb_median` accept three shapes server-side

The real `RgbPayload` schema is `anyOf [array-of-numbers, {r,g,b} object,
string]`. The app currently sends the `{r,g,b}` object form, which is one of
the three accepted shapes — no change needed, but the generated client type
for this field may come out as a loose `oneOf`/`AnyOf` enum rather than a
plain `{r,g,b}` struct; worth checking the generated Swift type is still
ergonomic to construct from `RGB`.

### 8. `CaptureRequest` accepts two different shapes, with inconsistent field naming between them

The real `CaptureRequest` schema is `anyOf` of (a) a flat top-level set of
fields (`device_model`, `lens`, `exposure_duration` — note: *not*
`exposure_duration_seconds` — `iso`, …) or (b) `{metadata: CaptureMetadata,
quality: {...}}`, where nested `CaptureMetadata.exposure_duration_seconds`
*does* have the `_seconds` suffix. The app sends the nested form today
(satisfies the `anyOf` branch requiring `metadata`), so this does not affect
current behavior, but the naming inconsistency between the two accepted
shapes is worth flagging upstream. Also note `iso` is typed `integer` in the
real schema; the Swift `CaptureMetadata.iso` is `Float?`.

## What this means for the implementation PR

- Vendor the **live** `GET /api/v1/openapi.json` response (not a
  hand-transcription) once a `color_matching` instance is reachable from the
  implementation environment.
- Expect the generated `Manifest`/`RankedResults` types to be thin (finding
  #1); decide whether to tighten the upstream spec first, or ship
  hand-written decode/fixture coverage (like the tests added in this PR)
  alongside the generated types until it is.
- `ranked_results` is a new client surface, not a refactor, for both the
  model and the UI that will consume it.
- `printer_profile` needs new field names if/when the manifest type starts
  exposing it.
