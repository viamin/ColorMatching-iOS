# OpenAPI Contract Deltas (#5)

Tracks differences found between `docs/color-matching-api-contract.md` (the
hand-written prose contract this app was built against) and the real
`/api/v1` API, now that `viamin/color_matching#110` is closed via the merged
`viamin/color_matching#113` ("Publish OpenAPI 3 spec for the `/api/v1` API
and enforce it in CI"). The spec is generated at runtime by OpenApiSpex from
`lib/color_matching_web/api_schemas.ex` and served at `GET /api/v1/openapi.json`;
it is not a file checked into that repo, and no running `color_matching`
instance or clone of that repo was reachable from this environment. The
findings below come from reading `api_schemas.ex` and
`capture_controller.ex` on GitHub, so **re-verify every item against the
live `/api/v1/openapi.json` document before relying on it to drive codegen**.

## Confirmed-from-source deltas

- **Capture creation accepts two request shapes.** `CaptureRequest` is an
  `anyOf` of a flat top-level shape (`device_model`, `lens`, `image_width`,
  `image_height`, `app_version`, `timestamp`, ... plus `rejection_reasons`)
  and a nested shape (`metadata` + `quality`). This app already sends the
  nested shape, which matches the `required: [:metadata]` branch, so current
  behavior is compatible — but the prose contract only ever documented the
  nested shape and never mentioned the flat alternative exists.
- **Field naming is inconsistent between the two capture shapes.** The flat
  shape uses `exposure_duration` and `rejection_reasons`; the nested
  `CaptureMetadata`/`quality` shapes this app uses are named
  `exposure_duration_seconds` and `rejections` respectively. The prose
  contract documents only the nested names, which is what the app sends, so
  no client change is implied — just a naming gap in the prose doc.
- **`pair_scores[]` accepts `score`, `similarity`, or `distance`** (exactly
  one required via `anyOf`), plus required `pair_id` and `algorithm_version`.
  The prose contract only documents `distance`/`similarity` and never
  mentions the `score` alternative or the "exactly one" constraint. The app
  sends both `distance` and `similarity`, which satisfies the real schema.
- **`linear_rgb_median` / `normalized_linear_rgb_median` accept three
  encodings**: an `{r, g, b}` object (what this app sends and what the prose
  contract documents), an array of numbers, or a JSON-encoded string. The
  object form is fine to keep sending.
- **No `stats` property appears on the published `measurements[]` schema**
  (only `patch_id`, `linear_rgb_median`, `normalized_linear_rgb_median`), and
  no top-level `scoring_algorithm_version` appears on
  `MeasurementUploadRequest` (only `measurements` and `pair_scores`, with
  `algorithm_version` living per-`pair_scores[]` item instead). This app's
  `uploadMeasurements` currently sends both `stats` per measurement and a
  top-level `scoring_algorithm_version`. Because OpenApiSpex schemas here
  don't set `additionalProperties: false`, extra fields are not necessarily
  rejected — but they are undocumented in the published contract. **Needs
  confirmation against the live spec** before deciding whether to drop them,
  keep them as app-only extras, or ask `color_matching` to document them;
  this app's capture/scoring behavior is a non-goal to change for #5, so any
  fix should be to the wire payload shape only, not to what gets measured.
- **A structured error response exists**: `ApiErrorResponse.errors` is a
  `oneOf` of a free-form object or an array of `{detail, source: {pointer}}`
  entries. The prose contract never documented an error shape, and this
  app's `APIClient.validate` only inspects the HTTP status code and discards
  the response body (see `APIError.badStatus` in
  `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`). Tracked as a
  pending test in `GeneratedClientMigrationTests`.
- **`RecentSheetsResponse` items require `title`** (nullable) rather than
  making it optional/absent. This app's `RecentSheet.title: String?` already
  decodes a present-but-null key correctly, so no change needed.
- **`judgment` has no server-side enum** in `JudgmentUploadRequest`, unlike
  the prose contract's closed set (`match` / `near_match` / `no_match`).
  Client-side validation of allowed judgments still belongs in this app.

## Endpoint gaps (new endpoints/surfaces not in the prose contract)

These are out of scope to implement against (non-goal: no new endpoints),
but are worth recording since the issue asks for "any endpoint gaps
discovered":

- `GET /api/v1/test_sheets/:sheet_id/ranked_results` — the prose contract
  describes this loosely ("latest or aggregate ranked results...") and the
  real `RankedResults` schema pins `schema_version` (enum
  `lps-ranked-results/v1`) and `sheet_id` as the only clearly-required
  fields visible from the GitHub read; **this app has no client method for
  this endpoint at all today** (see the pending test in
  `GeneratedClientMigrationTests`), so it's a genuine coverage gap
  independent of the OpenAPI migration.
- `POST /api/illuminant_measurements` (single + bulk variants) — not under
  `/api/v1`, not in the prose contract, not used by this app.
- `POST /api/multi_image_mapping` — not under `/api/v1`, not in the prose
  contract, not used by this app.
- Printer profile, color palette, and metamer-pair endpoints referenced by
  `ApiSchemas` (`PrinterProfile`, palette listing/response schemas,
  `MetamerPairs`-style classification) — none of these are in the prose
  contract or used by this app today.

## What this means for the implementation run

- `SheetManifest` (in `MeasurementCore/Models.swift`) does not decode
  `created_at`, `printer_profile`, or `capture_profile`, all of which the
  prose contract's example response includes. Extra keys are silently
  ignored by `Codable` today; generated types will pick these fields up
  automatically, so the implementation run should decide whether any
  consuming code needs them.
- Fetching the real spec (`GET /api/v1/openapi.json` from a running
  `color_matching` instance) is required before `swift-openapi-generator`
  can run; this environment has no network path to that service and no
  clone of `viamin/color_matching`, so vendoring the spec and generating
  client code could not be done in this test-writing run.
