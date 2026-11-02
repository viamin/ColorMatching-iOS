# Contract deltas: prose contract vs published OpenAPI spec

Comparison of `docs/color-matching-api-contract.md` (prose contract) against the
published OpenAPI 3 spec from viamin/color_matching#110 (spec assembled by
`ColorMatchingWeb.ApiSpec` from `OpenApiSpex.ControllerSpecs` declarations and
served at `GET /api/v1/openapi.json`).

Evidence cited from `viamin/color_matching@main`:

- `lib/color_matching_web/api_spec.ex` — spec assembly, bearerAuth security scheme
- `lib/color_matching_web/api_schemas.ex` — component schemas
- `lib/color_matching_web/controllers/test_sheet_controller.ex`,
  `lib/color_matching_web/controllers/capture_controller.ex` — operations,
  parameters, status codes
- `lib/color_matching_web/controllers/test_sheet_json.ex` — actual rendered
  payloads
- `lib/color_matching_web/router.ex` — routes

This document is the source material for the PR description of the
generated-client migration (issue #5) and for the vendoring decisions recorded
in `docs/openapi-client-test-plan.md`.

## Schema deltas

### 1. Manifest schema under-documents the real payload (headline gap)

The published `TestSheetManifest` schema guarantees only
`schema_version`, `sheet_id`, and `capture_profile`. The actual renderer
(`TestSheetJSON.manifest/1`) — and the prose contract — emit
`sheet_version`, `manifest_url`, `created_at`, `page`,
`registration_markers`, `printer_profile`, `patches`, and `pairs` as well.
Because OpenAPI defaults `additionalProperties` to allowed, the extra fields
pass response validation but are invisible to codegen: a client generated
from the published spec cannot see the sheet geometry the iOS app depends on.

Vendoring decision: the vendored copy of the spec widens the Manifest schema
to the rendered shape (geometry fields optional, upstream-required trio kept
required) so generated types cover the app's needs. Upstream should document
these fields (tracked as a gap to report back to viamin/color_matching).

### 2. `printer_profile` has three different shapes

- Prose contract manifest: `{id, name, paper, ink, settings}`
- Actual manifest renderer: `{printer_make_model, paper_type, ink_type,
  icc_profile, print_settings, driver_name, driver_version, calibration_date,
  calibration_version, notes}`
- Published `PrinterProfile` schema (used by palette endpoints):
  `{id: integer, printer_make_model, paper_type, ink_type}`

The prose contract shape matches none of the current implementations. The
manifest's rendered shape is the one vendored for the manifest schema.

### 3. Patch ids use the `pair_id#side` convention

Prose example shows `"patch_1"`; the renderer emits `"pair_1#first"` /
`"pair_1#second"` (`patch_id/2` in `TestSheetJSON`). Client-side models treat
ids as opaque strings, so no behavior change — but fixtures and any
identifier-splitting logic must use `#` as the separator, not `_`.

### 4. Measurement upload now has a documented response

Prose contract documents no response body. Published spec (and controller):
`200` with `{capture_id, measurement_count, pair_score_count}`. The
hand-written client discarded this; the generated client surfaces the counts.

### 5. Judgment upload now has a documented response

`200` with `{capture_id, judgment_count}`. Same treatment as above.

### 6. `normalized_linear_rgb_median` is required upstream

Published `MeasurementUploadRequest` marks `patch_id`,
`linear_rgb_median`, and `normalized_linear_rgb_median` as required per
measurement row. The iOS app treats the normalized median as optional
(`PatchMeasurement.normalizedLinearRGBMedian: RGB?`). Omitting it would now be
a spec violation — the facade always sends it (falling back to the
unnormalized median would be wrong; today's flow uploads both whenever
normalization ran). Flagged as an app-side hardening item.

### 7. Measurement rows carry undocumented `stats`, and the top-level
`scoring_algorithm_version` is undocumented

The app uploads per-patch `stats` (`sample_count`, `clipping_fraction`,
`mean`, `standard_deviation`) and a top-level `scoring_algorithm_version`.
Neither appears in the published `MeasurementUploadRequest` schema; the
server tolerates them as additional properties. The facade preserves them on
the wire (behavior preservation), and the delta is recorded here — upstream
should either document or reject them deliberately.

### 8. `RgbPayload` is a union

`linear_rgb_median` / `normalized_linear_rgb_median` accept an RGB array, an
`{r, g, b}` object, or a string. The prose contract only documents the object
form; the app sends object form. Generated types carry the union.

### 9. Pair scores accept score/similarity/distance (anyOf one required)

Published `PairScoreRequest` requires `pair_id` + `algorithm_version` and at
least one of `score` / `similarity` / `distance`. The app sends `distance`,
`similarity`, and `algorithm_version` — compatible.

### 10. Enum constraints from the prose contract are not published

The prose contract enumerates six capture rejection strings
(`missingRegistrationMarks`, `incompleteSheetCoverage`, `clipping`,
`excessiveBlur`, `glare`, `poorReferencePatch`) and three judgment values
(`match`, `near_match`, `no_match`). The published spec types both as free-form
string arrays / strings. The enums remain client-side knowledge
(`CaptureRejection` in MeasurementCore).

### 11. Error responses are now documented

`401` / `404` / `422` with `ApiErrorResponse` `{errors: object | [{detail,
source}]}`. The prose contract documents no error shape and the hand-written
client collapsed every non-2xx into `.badStatus`. The facade now maps
documented statuses to typed `APIError` cases carrying `errors.detail` when
present.

### 12. Recent sheets `title` is always null today

Schema: `title` nullable. Renderer: always `null` (no display name stored).
Prose says "may be null" — correct but stronger: currently always null.

### 13. Capture ids are stringified integer database ids

Prose example shows `"capture_123"`; the controller renders
`Integer.to_string(capture.id)` (e.g. `"421"`). Path parameters
(`/api/v1/captures/{capture_id}/...`) must therefore be integer-castable.
Also `POST .../captures` returns `201 Created`, matching the published spec.

### 14. RankedResults schema under-documents the real payload

Published schema guarantees only `schema_version` (`lps-ranked-results/v1`)
and `sheet_id`. The renderer emits printer profile, capture counts/timestamps,
and per-pair ranked results with scores, judgments, and observations — the
"source colors, scores, labels, capture provenance" the prose contract
promised. The vendored copy keeps the published (thin) ranked-results schema
for now since the app does not yet consume the details; widening follows when
the app adds a results screen.

### 15. Capture request accepts two shapes

Published `CaptureRequest` accepts either a flat metadata object or the
nested `{metadata, quality}` the app sends (`anyOf`). `quality` has no
required fields. `iso` is typed `integer` upstream while the app models it as
`Float` — fractional ISO values would be a `422` (app-side hardening item:
send integral ISO only).

## Endpoint gaps

All six surfaces the app uses exist upstream and are published in the spec:

| App surface | Route | Published operation |
| --- | --- | --- |
| Sheet manifest | `GET /api/v1/test_sheets/{sheet_id}/manifest` | `ColorMatchingWeb.TestSheetController.manifest` |
| Recent sheets | `GET /api/v1/test_sheets/recent` | `ColorMatchingWeb.TestSheetController.recent` |
| Ranked results | `GET /api/v1/test_sheets/{sheet_id}/ranked_results` | `ColorMatchingWeb.TestSheetController.ranked_results` |
| Capture creation | `POST /api/v1/test_sheets/{sheet_id}/captures` | `ColorMatchingWeb.CaptureController.create` |
| Measurement upload | `POST /api/v1/captures/{capture_id}/measurements` | `ColorMatchingWeb.CaptureController.upload_measurements` |
| Judgment upload | `POST /api/v1/captures/{capture_id}/judgments` | `ColorMatchingWeb.CaptureController.upload_judgments` |

Published-but-unused-by-the-app (out of scope for the generated client's
app-facing facade): `printer_profiles`, `printer_profiles/{id}/colors`,
`printer_profiles/{id}/metamer_pairs`, `palettes`, `colors`,
`/api/illuminant_measurements` (+ `/bulk`), `/api/multi_image_mapping`, and
`/api/v1/openapi.json` itself.

OperationIds derived by OpenApiSpex (`"#{inspect(mod)}.#{action}"`) are
controller-qualified (e.g. `ColorMatchingWeb.TestSheetController.manifest`),
which would generate unwieldy Swift method names; the vendored copy renames
them (see `docs/openapi-client-test-plan.md`).

## Security

The spec declares `bearerAuth` (HTTP bearer) on all app operations; the prose
contract additionally allows unauthenticated requests in development. That
toggle is server-side; the client always attaches the token when present.
