# Contract Deltas: `docs/color-matching-api-contract.md` vs the Published OpenAPI Spec

Tracks differences found between this repo's hand-written prose contract
(`docs/color-matching-api-contract.md`) and the real `/api/v1` API now that
`viamin/color_matching#110` ("Publish OpenAPI 3 spec for the `/api/v1` API
and enforce it in CI") is merged (`viamin/color_matching#113`,
merge commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f`). Written to
feed the PR description for the generated-client migration (issue #5).

The spec itself is **not** vendored as a static file in `color_matching` —
it's rendered at runtime from `ColorMatchingWeb.ApiSpec`/`ApiSchemas` and
served at `GET /api/v1/openapi.json`. Fetching it for codegen requires
either running the Phoenix app and curling that endpoint, or exporting it
from `ColorMatchingWeb.ApiSpec.spec/0` (e.g. via a small mix task that
dumps `OpenApiSpex.OpenApi.to_map/1` to JSON). Findings below come from
reading `lib/color_matching_web/api_schemas.ex`,
`lib/color_matching_web/controllers/{test_sheet,capture}_controller.ex`,
`lib/color_matching_web/controllers/test_sheet_json.ex`,
`lib/color_matching/ranked_results.ex`, and
`lib/color_matching/persistence/capture_upload.ex` at that commit.

## Most significant gap: the spec under-types the two richest endpoints

The published `operation` responses for `manifest` and `ranked_results`
reference `ColorMatchingWeb.ApiSchemas.Manifest` and `.RankedResults`.
Both schemas declare only a handful of `properties`:

- `Manifest`: `schema_version`, `sheet_id`, `capture_profile.scoring_algorithm_version`.
- `RankedResults`: `schema_version`, `sheet_id`.

But the actual JSON rendered by `ColorMatchingWeb.TestSheetJSON` (the view
backing both actions) additionally emits, every time:

- Manifest: `sheet_version`, `manifest_url`, `created_at`, `page`,
  `registration_markers`, `printer_profile`, `patches`, `pairs` — i.e.
  everything the iOS app's `SheetManifest` model actually needs.
- RankedResults: `printer_profile`, `capture_count`, `latest_capture_at`,
  `earliest_capture_at`, `scoring_algorithm_versions`, and the entire
  `results` array (rank, pair id, row/col, source colors, aggregate score,
  current judgment + observed-at, observation count, latest observation,
  capture provenance) — the entire payload that makes the endpoint useful.

**Impact:** `swift-openapi-generator` generates Swift types strictly from
declared `properties`. Run as-is against the spec at `#113`, the generated
`Manifest`/`RankedResults` types would have almost none of the fields the
app needs — a straight swap would silently regress both endpoints. Either
upstream (`color_matching`) needs to flesh out these two schemas before
code generation, or the migration PR must carry a follow-up issue against
`viamin/color_matching` and, in the interim, decode the un-typed remainder
through each operation's `additionalProperties`/raw body rather than the
generated struct. This should be called out explicitly as a blocking gap,
not a silent partial migration.

## Confirmed-safe deltas (no behavior change required)

- `POST .../captures` response (`capture_id`) matches the hand-written
  contract and the current `CaptureSessionResponse` model.
- `RGB` values are sent as `{r, g, b}` objects, one of three shapes
  `ColorMatchingWeb.ApiSchemas.RgbPayload` accepts (`anyOf`: array,
  `{r,g,b}` object, or JSON-encoded string) — compatible as-is.
- `recent sheets` (`sheet_id`, `manifest_url`, `title` nullable) matches.

## Deltas requiring attention during migration

1. **Measurement and judgment uploads return a body; the app discards it.**
   The hand-written contract doesn't mention a response body for
   `POST .../measurements` or `POST .../judgments`, and the current
   `APIClient.uploadMeasurements`/`uploadJudgments` are `-> Void` and never
   decode one. The real controller (`CaptureController.handle_measurement_upload/3`,
   `.handle_judgment_upload/3`) returns `200` with
   `{capture_id, measurement_count, pair_score_count}` and
   `{capture_id, judgment_count}` respectively — useful confirmation data
   (e.g. for detecting partial-row rejection) that a generated client
   should expose instead of discarding.

2. **`normalized_linear_rgb_median` is a required field; the app's model
   makes it optional and omits the key when absent.** The published
   `MeasurementUploadRequest` schema requires
   `[:patch_id, :linear_rgb_median, :normalized_linear_rgb_median]` on
   every measurement, with no `nullable: true`. The app's
   `PatchMeasurement.normalizedLinearRGBMedian` is `RGB?`, and Swift's
   synthesized `Encodable` conformance uses `encodeIfPresent` for Optional
   properties, so when the value is `nil` the key is **omitted entirely**,
   not sent as `null`. See the regression test added in
   `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`
   (`testUploadMeasurementsOmitsRequiredNormalizedMedianKeyWhenNil`), which
   is red today. A generated/strict client would refuse to build this
   request at all until every measurement carries a normalized value —
   capture flow needs to guarantee that before the swap, or the migration
   needs an explicit decision about what to send when normalization
   hasn't run yet.

3. **Top-level `scoring_algorithm_version` on the measurement upload body
   is dead weight.** The app's `MeasurementUploadRequest` sends it
   alongside `measurements`/`pair_scores`, but
   `ColorMatching.Persistence.CaptureUpload.normalize_pair_score_attrs/1`
   never reads it — only each pair score's own `algorithm_version` is
   used — and the published `MeasurementUploadRequest` schema doesn't
   declare the key either. Safe to drop when switching to the generated
   request type.

4. **Per-measurement `stats` (sample_count/clipping_fraction/mean/standard_deviation)
   aren't in the published schema, but the server does read them.**
   `CaptureUpload.normalize_measurement_attrs/2` has an explicit comment —
   *"The iOS contract nests robustness stats under `stats`; older callers
   send them flat. Accept both, with the top-level value preferred."* — so
   the field is real and supported, just undocumented in the OpenAPI
   schema (no `additionalProperties: true` declared on that items schema
   either). A generated request type built strictly from the spec would
   drop this field. Flag upstream so the schema either declares `stats`
   explicitly or sets `additionalProperties: true`.

5. **`CaptureMetadata.iso` is typed `integer` in the spec; the app models
   it as `Float?`.** Not currently a wire-format break (whole-number
   floats encode without a fractional part), but worth tightening to `Int?`
   when the generated type is adopted so the Swift type matches the spec's
   intent rather than relying on encoder formatting.

6. **The judgment enum isn't actually constrained server-side.** The
   prose contract lists `match` / `near_match` / `no_match` as "Allowed
   judgments," but `ColorMatchingWeb.ApiSchemas.JudgmentUploadRequest`
   types `judgment` as a bare `%Schema{type: :string}` with no `enum`.
   The generated type will be `String`, not a closed enum — client-side
   validation of allowed values stays the app's responsibility.

## Endpoint coverage gap in the current hand-written client

`APIClient` (`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`) has no
method for `GET /api/v1/test_sheets/:sheet_id/ranked_results` at all, even
though "ranked results" is one of the five in-scope surfaces listed in
issue #5 and is documented in `docs/color-matching-api-contract.md`. This
is the biggest functional gap the generated-client migration needs to
close — combined with finding 1 above (ranked results' schema being
under-typed), it's the riskiest piece of this migration.

## Out of scope for this app

`/api/v1/printer_profiles`, `/api/v1/palettes`, `/api/v1/colors`,
`/api/illuminant_measurements(/bulk)`, and `/api/multi_image_mapping` are
real, spec-documented endpoints on the same host but belong to the macOS
companion app's surface, not this app's. The generator should be scoped
(e.g. via `swift-openapi-generator`'s `operations: [...]` filter in
`openapi-generator-config.yaml`) to the five endpoints this app actually
calls, per issue #5's non-goals.
