# Contract Deltas: Prose Contract vs. Published OpenAPI Spec

Findings for issue #5 ("Replace hand-written API layer with a generated OpenAPI Swift
client"). `viamin/color_matching#110` (publish a machine-readable OpenAPI spec) closed
on 2026-10-30 via `viamin/color_matching#113`. The spec is generated at runtime by
OpenApiSpex from `lib/color_matching_web/api_schemas.ex` and served at
`GET /api/v1/openapi.json`; it is not checked into the repo as a static file, so there
is nothing to vendor yet — the implementation PR will need to fetch it from a running
instance (or export it via `mix openapi.spec.json` or similar) rather than copy a file
out of git history.

This document compares `docs/color-matching-api-contract.md` (the hand-written prose
contract this app currently codes against) with the real schemas in
`lib/color_matching_web/api_schemas.ex`, the routes in
`lib/color_matching_web/router.ex`, and the actual rendered JSON in
`lib/color_matching_web/controllers/test_sheet_json.ex`, as observed on
`viamin/color_matching@main` after PR #113 merged. Sourced via GitHub's web UI (no
local checkout of `color_matching` is available from this repo), so line numbers are
not cited — field names and nesting are.

Three of the deltas below (measurements, image dimensions) are also captured as
failing tests in `iOS/Tests/ColorMatchingLPSAppTests/APIContractDeltaTests.swift`, run
against the current hand-written `APIClient`.

## Endpoints: no surprises

All five routes the app uses exist exactly as the prose contract describes:

- `GET /api/v1/test_sheets/recent`
- `GET /api/v1/test_sheets/:sheet_id/manifest`
- `GET /api/v1/test_sheets/:sheet_id/ranked_results`
- `POST /api/v1/test_sheets/:sheet_id/captures`
- `POST /api/v1/captures/:capture_id/measurements`
- `POST /api/v1/captures/:capture_id/judgments`

All are behind a `bearerAuth` security requirement, matching the prose contract's
bearer-token assumption.

## Delta 1 — `printer_profile` shape is completely different

Prose contract (`manifest.printer_profile`):

```json
{"id": "printer_profile_1", "name": "Research printer", "paper": "paper name", "ink": "ink set", "settings": {}}
```

Real API (`manifest.printer_profile`, from `test_sheet_json.ex`):

```json
{
  "printer_make_model": "...",
  "paper_type": "...",
  "ink_type": "...",
  "icc_profile": "...",
  "print_settings": "...",
  "driver_name": "...",
  "driver_version": "...",
  "calibration_date": "...",
  "calibration_version": "...",
  "notes": "..."
}
```

No field names survive unchanged (`paper` → `paper_type`, `ink` → `ink_type`,
`settings` → `print_settings`, `name` has no equivalent single field). The app's
current `SheetManifest` model doesn't decode `printer_profile` at all today, so this
is a decode-side gap rather than a regression — the generated client will need a type
for the real shape above.

## Delta 2 — `capture_profile` is ignored by the current model, but required by the real schema

`capture_profile.scoring_algorithm_version` is a *required* field in the real
`Manifest` schema (enum `"lps-distance-v1"`), matching the prose contract. However,
`SheetManifest` (`iOS/Sources/MeasurementCore/Models.swift`) has no `capture_profile`
property, so the app currently hardcodes `LPSScorer.algorithmVersion` instead of
reading the server's declared algorithm version — exactly the kind of silent
server/client drift this migration is meant to surface. Carry `capture_profile`
through in the generated types and compare it against `LPSScorer.algorithmVersion`.

## Delta 3 — `ranked_results` response has a real, rich shape the prose contract never specified

The prose contract only says the endpoint "should return ... ranked results with
source colors, scores, labels, capture provenance, printer profile, and scoring
algorithm version" with no JSON example. The app has **no client method, and no model,
for this endpoint at all** (`APIClient` has no `rankedResults` function).

The real response (`test_sheet_json.ex`, schema `lps-ranked-results/v1`):

```json
{
  "schema_version": "lps-ranked-results/v1",
  "sheet_id": "sheet_123",
  "printer_profile": { "...": "same 10 keys as manifest.printer_profile" },
  "capture_count": 12,
  "latest_capture_at": "2026-10-20T00:00:00Z",
  "earliest_capture_at": "2026-07-25T00:00:00Z",
  "scoring_algorithm_versions": ["lps-distance-v1"],
  "results": [
    {
      "rank": 1,
      "pair_id": "pair_1",
      "scoring_algorithm_version": "lps-distance-v1",
      "row": 0,
      "col": 1,
      "source_colors": { "color_a_hex": "#FF0000", "color_b_hex": "#00FF00" },
      "score": {
        "average": 0.96, "latest": 0.97, "minimum": 0.9, "maximum": 0.98,
        "capture_count": 3, "sample_count": 2700, "algorithm_versions": ["lps-distance-v1"]
      },
      "current_judgment": "near_match",
      "current_judgment_observed_at": "2026-10-20T00:00:00Z",
      "observation_count": 3,
      "latest_observation": {"judgment": "near_match", "observed_at": "2026-10-20T00:00:00Z"},
      "capture_count": 3,
      "latest_capture_at": "2026-10-20T00:00:00Z",
      "earliest_capture_at": "2026-07-25T00:00:00Z"
    }
  ]
}
```

Note `results[].source_colors` is a **named object** (`color_a_hex`/`color_b_hex`),
unlike `manifest.pairs[].source_colors`, which is a 2-element array of hex strings in
both the prose contract and the real manifest schema — these two `source_colors`
shapes are not interchangeable despite the shared name. This is the single biggest
endpoint gap: the generated client is the first time this app will have any ranked
results support.

## Delta 4 — `MeasurementUploadRequest` has no `scoring_algorithm_version` or per-measurement `stats`

Prose contract wraps the whole upload in a top-level `scoring_algorithm_version` and
gives each measurement a `stats` object (`sample_count`, `clipping_fraction`, `mean`,
`standard_deviation`). The real `MeasurementUploadRequest` schema
(`api_schemas.ex`) only defines:

- top level: `measurements`, `pair_scores` — no `scoring_algorithm_version`
- `measurements[]`: `patch_id`, `linear_rgb_median`, `normalized_linear_rgb_median`
  (all three **required**) — no `stats`
- `pair_scores[]` (`PairScoreRequest`): `pair_id` and `algorithm_version` required,
  plus an `anyOf` requiring at least one of `score`, `similarity`, `distance`

So per-upload algorithm version now lives per pair score (`pair_scores[].algorithm_version`,
which the app already sends), not at the request top level, and raw per-channel
statistics the app currently uploads (`stats`) aren't part of the contract at all.
Covered by `testUploadMeasurementsBodyIncludesFieldsAbsentFromRealSchema` in
`APIContractDeltaTests.swift`.

`normalized_linear_rgb_median` being required (not optional, unlike the prose
contract's implication) is covered by
`testUploadMeasurementsOmitsNormalizedMedianWhenNilButRealContractRequiresIt`.

## Delta 5 — `CaptureMetadata.image_width` / `image_height` are required, not optional

The real `CaptureMetadata` schema requires `device_model`, `lens`, `image_width`,
`image_height`, `app_version`, `timestamp`. The app's hand-written `CaptureMetadata`
(`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`) types `imageWidth`/`imageHeight`
as `Int?`, so a capture built without known dimensions silently omits required fields
instead of failing fast. Covered by `testCreateCaptureOmitsRequiredImageDimensionsWhenNil`.

Also note: the real API additionally accepts a *flat* `CaptureRequest` shape (fields
at the top level instead of nested under `metadata`/`quality`), as an alternative to
the nested shape the prose contract documents and the app already sends. The flat
variant's field names differ further still (`rejection_reasons` instead of
`quality.rejections`, `exposure_duration` instead of `metadata.exposure_duration_seconds`).
The app should keep using the nested shape; the generated client will likely expose
both as a union type, which the app can ignore.

## Delta 6 — error response shape was undocumented

The prose contract says nothing about error bodies. The real API has a consistent
`ErrorResponse` (`title: "ApiErrorResponse"`) with a single `errors` key that is either
a free-form object (404s: `{"errors": {"detail": "..."}}`) or an array of
`{"detail": ..., "source": {"pointer": ...}}` items (422s). The app's `APIError` enum
currently only distinguishes "status not in 200..300" (`.badStatus`) and never reads
the body — fine for now, but the generated client's error types will carry this detail
and the app should decide whether to surface it (e.g. distinguishing "sheet not found"
from "invalid capture attributes").

## No-delta confirmations

These prose-contract shapes matched the real schemas/rendering exactly, so no action
needed beyond using the generated types:

- `GET /recent` → `{"sheets": [{"sheet_id", "manifest_url", "title"}]}`
- `manifest.page`, `manifest.registration_markers[]`, `manifest.patches[]`,
  `manifest.pairs[]` — every field name matches
- `manifest.capture_profile.expected_illuminant` / `.preferred_camera`
- `POST /captures/:id/judgments` request (`judgments[].pair_id`, `.judgment`) and
  nested `CaptureRequest.quality.rejections`
- `CaptureCreatedResponse` (`{"capture_id": "<string>"}`) — note the ID is an integer
  rendered as a string server-side, matching the app's `String` typing

## Not yet verified (needs the real spec document, not just source reading)

This document was built by reading `color_matching` controller/schema/router source on
GitHub, not by fetching `GET /api/v1/openapi.json` from a running instance (none is
available from this environment, and the spec isn't checked into the repo as a static
file). The implementation PR should diff the actual served spec against this document
before generating the client, in case the rendered OpenApiSpex schema differs from what
the Elixir source implies (e.g. nullable/required flags, enum completeness for
`current_judgment`/`judgment` values, and whether `errors` array items always include
`source.pointer`).
