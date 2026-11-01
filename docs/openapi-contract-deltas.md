# OpenAPI Contract Deltas (#5 research)

This records what changed between this repo's hand-maintained prose contract
(`docs/color-matching-api-contract.md`) and the real `color_matching` API, as
input for the generated-client PR described in #5. It is written during the
test-writing phase of that work, before the generator/package changes land,
so the implementation PR can carry these findings into its description
instead of re-deriving them.

## How this was verified

`viamin/color_matching#110` ("document the `/api/v1` API with
`open_api_spex`") closed via `viamin/color_matching#113`. The published
machine-readable document lives at the app's own `GET /api/v1/openapi.json`
(see `lib/color_matching_web/router.ex`), which needs a running Phoenix
server to fetch — not available in this sandbox. Instead, these findings
come from reading the source that builds that document directly from
`viamin/color_matching@main` (fetched 2026-11-01):

- `lib/color_matching_web/router.ex` — confirms the actual routes.
- `lib/color_matching_web/api_spec.ex` — confirms the spec is built from
  `Paths.from_routes/1` over every `/api/*` route (bearer-auth security
  scheme, no surprises there).
- `lib/color_matching_web/api_schemas.ex` — the `OpenApiSpex.schema/1`
  modules that define request/response shapes.

**Action for the implementation PR:** re-fetch and diff against the actual
generated `/api/v1/openapi.json` once a server is reachable — schema
modules can under- or over-declare what a controller actually renders, so
this source-reading pass should be treated as a strong approximation, not
a substitute for generating from the real document.

## Route coverage

Every surface this app uses today exists under `/api/v1`, pipelined through
`:api` + `:api_auth` (bearer token, matching this repo's assumption):

| App usage | Real route |
|---|---|
| fetch manifest | `GET /api/v1/test_sheets/:sheet_id/manifest` |
| recent sheets | `GET /api/v1/test_sheets/recent` |
| create capture | `POST /api/v1/test_sheets/:sheet_id/captures` |
| upload measurements | `POST /api/v1/captures/:capture_id/measurements` |
| upload judgments | `POST /api/v1/captures/:capture_id/judgments` |
| ranked results | `GET /api/v1/test_sheets/:sheet_id/ranked_results` |

**Gap found:** `ranked_results` is documented in
`docs/color-matching-api-contract.md` and implemented server-side, but
`ColorMatchingLPSAppCore.APIClient` has no method for it at all — the app
only ever shows locally-computed `LPSScorer` output
(`iOS/Sources/ColorMatchingLPSApp/ContentView.swift`). This is a pre-existing
gap in the hand-written client, not something the prose contract hid; the
generated client should add this surface since #5 explicitly lists it.

The real router also exposes `GET /api/v1/openapi.json` itself (public, no
`:api_auth`) — that's the fetch target for vendoring the spec.

## Schema-level deltas

1. **`normalized_linear_rgb_median` is required, not optional.**
   `ColorMatchingWeb.ApiSchemas.MeasurementUploadRequest` marks every
   measurement item's `normalized_linear_rgb_median` as required. This
   repo's `PatchMeasurement.normalizedLinearRGBMedian` is `RGB?`, and
   Swift's synthesized `Codable` conformance omits the JSON key entirely
   for a `nil` optional — so a `PatchMeasurement` built before the
   normalization pass runs would encode a request the real server should
   reject. The app's only call site
   (`ContentView.swift:245`) always uploads `analysis.normalizedMeasurements`,
   which `Normalizer.normalize` always populates, so this isn't hit in
   practice today — but the client API itself doesn't guarantee it.
   Covered by a new failing test:
   `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`,
   `testUploadMeasurementsAlwaysSendsNormalizedMedianKeyPerRealServerContract`.

2. **No top-level `scoring_algorithm_version` on measurement upload.**
   The real `MeasurementUploadRequest` schema only declares `measurements`
   and `pair_scores`; there is no top-level version field. Version info
   lives per pair score instead: `PairScoreRequest` requires `pair_id` and
   `algorithm_version` on every item. This repo's hand-written
   `MeasurementUploadRequest` (private type in `APIClient.swift`) sends
   both: a top-level `scoring_algorithm_version` (undocumented by the real
   schema, likely tolerated as an extra field) *and* a correctly-shaped
   per-score `algorithm_version` via `PairScore`. Worth dropping the
   top-level field when the generated types land, since it has no
   documented home.

3. **`CaptureRequest` is more permissive than this app assumes.**
   The real schema accepts either this app's nested
   `{"metadata": {...}, "quality": {...}}` shape, or a flat body with the
   metadata/quality fields at the top level (`anyOf`, satisfied by either).
   This app's nested shape is one of the two valid branches, so no change
   needed — but the flat branch uses `rejection_reasons` where the nested
   branch's `quality.rejections` differs only in that nesting, not naming.
   No action needed for this app; noted so a future reader doesn't assume
   the flat shape is unsupported.

4. **`linear_rgb_median` / `normalized_linear_rgb_median` payload is a
   3-way union.** The real `RgbPayload` schema is
   `anyOf[number array, {r,g,b} object, string]`. This app always sends
   the `{r,g,b}` object form, which is one of the three valid branches, so
   today's encoding is compatible. The generated Swift type for this union
   will likely be a generator-specific enum wrapper rather than a plain
   `Rgb` object — expect call-site changes when wiring the generated
   client in, even though no behavior changes.

5. **Manifest and ranked-results schemas are thinly specified.**
   `ColorMatchingWeb.ApiSchemas.Manifest` only formally declares
   `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`
   as required; `RankedResults` only declares `schema_version` and
   `sheet_id`. Neither schema module declares `page`, `registration_markers`,
   `patches`, `pairs`, `manifest_url`, `printer_profile`, or any ranked-pair
   fields — all fields this repo's `SheetManifest` (and the prose contract)
   already model and the app actually renders.
   This is the most important risk for the generated-client work: a client
   generated naively from `/api/v1/openapi.json` may produce
   weakly/loosely-typed manifest and ranked-results models (open objects
   with few or no typed properties), losing the strong typing this app has
   today by hand. The implementation PR should check the real generated
   types before replacing `SheetManifest`/ranked-results models, and either
   push for the color_matching spec to be enriched or keep a thin
   hand-written decoding layer on top of the generated response type for
   just those two endpoints.

6. **Upload response bodies are defined but currently discarded.**
   `MeasurementUploadResponse` (`capture_id`, `measurement_count`,
   `pair_score_count`) and `JudgmentUploadResponse` (`capture_id`,
   `judgment_count`) are real, documented response shapes. This app's
   `APIClient.uploadMeasurements` / `uploadJudgments` only validate the
   HTTP status and return `Void`, discarding these bodies entirely. Not a
   bug today (nothing needs those counts yet), but the generated client
   will decode them, so callers gain the option to surface upload
   confirmation data if useful.

7. **Error response shape exists but isn't decoded.** `ErrorResponse`
   documents `{"errors": ...}` (either a flat object or an array of
   `{detail, source: {pointer}}`) on failure. `APIClient.validate` only
   checks the status code and throws `APIError.badStatus`, discarding the
   body. Worth decoding this once the generated error types exist, so
   failures surface a real message instead of a bare status code — left
   as a follow-up rather than a test in this pass, since it requires an
   `APIError` signature change (implementation, not test-writing).

## Non-findings (checked, no delta)

- Bearer-token auth matches (`security: bearerAuth`, HTTP bearer scheme).
- `RecentSheet` (`sheet_id`, `manifest_url`, `title` nullable) matches
  `RecentSheetsResponse` exactly.
- `CaptureCreatedResponse` (`capture_id` only) matches
  `CaptureSessionResponse` exactly.
- `PairScoreRequest`'s `anyOf[score, similarity, distance]` is satisfied by
  this app always sending both `distance` and `similarity` together.
