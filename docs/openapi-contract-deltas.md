# Contract Deltas: Prose Contract vs. Published OpenAPI Spec

Tracks drift discovered while working issue #5 ("Replace hand-written API
layer with a generated OpenAPI Swift client") between
[`docs/color-matching-api-contract.md`](color-matching-api-contract.md) (this
repo's hand-written prose contract) and the machine-readable OpenAPI spec
`color_matching` now publishes, per `viamin/color_matching#110`.

## Dependency status

`viamin/color_matching#110` ("Publish OpenAPI 3 spec for the `/api/v1` API
and enforce it in CI (Schemathesis + oasdiff)") is **closed**, completed via
`viamin/color_matching#113`, merged 2026-10-30. The spec is built with
`open_api_spex` spec modules (`lib/color_matching_web/api_spec.ex`,
`lib/color_matching_web/api_schemas.ex`) and served dynamically at
`GET /api/v1/openapi.json` — it is **not** a static file checked into the
`color_matching` repo, so it cannot be vendored directly from source
control. Fetching it requires a running `color_matching` instance.

This sandbox has neither network access to a running `color_matching`
instance nor a Swift toolchain (Linux container; the project's own CI runs
Swift tests on `macos-latest`). Adding `swift-openapi-generator` +
`swift-openapi-runtime`, fetching/vendoring the live spec, running codegen,
and swapping the hand-written models for generated types are therefore
**implementation work for a follow-up run**, not something this test-only
pass could complete or verify by executing `swift test`. The deltas below
were instead read directly from `color_matching`'s schema source
(`lib/color_matching_web/api_schemas.ex`) and router
(`lib/color_matching_web/router.ex`) on `main`, and verified by hand-tracing
Swift's synthesized `Codable` semantics against the existing hand-written
models and tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`.

## Confirmed deltas (iOS-relevant endpoints)

1. **`MeasurementUploadRequest` has no `scoring_algorithm_version` or
   per-measurement `stats` field.** The real schema's top level only has
   `measurements` and `pair_scores`; each measurement only has `patch_id`,
   `linear_rgb_median`, `normalized_linear_rgb_median`. The prose contract
   and the hand-written `APIClient.uploadMeasurements` both send a top-level
   `scoring_algorithm_version` and a per-measurement `stats` object
   (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`) that
   the published schema does not define.
   Covered by `testUploadMeasurementsBodyMatchesPublishedOpenAPISchema`.

2. **`normalized_linear_rgb_median` is required** on every measurement item
   in the published schema, but `PatchMeasurement`'s synthesized `Encodable`
   conformance (`normalizedLinearRGBMedian: RGB?`) omits the key entirely
   when the value is `nil`. A measurement uploaded without a normalized
   color would fail the server's `OpenApiSpex.Plug.CastAndValidate` check.
   Covered by `testPatchMeasurementEncodingOmitsRequiredNormalizedRGBWhenNil`.

3. **Structured error responses are discarded.** The published schema
   defines `ApiErrorResponse` (`errors`: either an arbitrary object, or an
   array of `{detail, source: {pointer}}`) for non-2xx responses. The
   hand-written client's `APIError.badStatus` has no associated data, so
   today every failed request loses the server's error detail and pointer.

4. **Write-endpoint response bodies are decodable but ignored.**
   `POST .../measurements` returns `MeasurementUploadResponse{capture_id,
   measurement_count, pair_score_count}` and `POST .../judgments` returns
   `JudgmentUploadResponse{capture_id, judgment_count}`. The hand-written
   `uploadMeasurements`/`uploadJudgments` both call a `send(_:)` helper that
   discards the response body entirely.

5. **`PairScoreRequest` allows a `score` field** in addition to
   `similarity`/`distance` (the schema requires at least one of the three).
   The hand-written `PairScore` model only has `distance`/`similarity`; this
   is compatible (not a break) but worth carrying into the generated types.

6. **`CaptureRequest` accepts two shapes**: flat top-level capture/quality
   fields, or the nested `metadata` + `quality` objects the hand-written
   client already sends. No gap for the nested shape the app uses; noting
   it so the generated client doesn't need to support the flat variant.

## Confirmed non-deltas (no action needed)

- Route paths for every iOS-relevant endpoint match the prose contract
  exactly: `GET /api/v1/test_sheets/:sheet_id/manifest`,
  `GET /api/v1/test_sheets/recent`,
  `GET /api/v1/test_sheets/:sheet_id/ranked_results`,
  `POST /api/v1/test_sheets/:sheet_id/captures`,
  `POST /api/v1/captures/:capture_id/measurements`,
  `POST /api/v1/captures/:capture_id/judgments`.
- `CaptureMetadata` field names and required set
  (`device_model`, `lens`, `image_width`, `image_height`, `app_version`,
  `timestamp`) match the hand-written `CaptureMetadata` model.
- `CaptureCreatedResponse{capture_id}` matches the hand-written
  `CaptureSessionResponse`.

## Endpoint gaps / out of scope

`color_matching` also exposes, under `/api` and `/api/v1`, several endpoints
this issue's companion app does not use today: `POST /api/illuminant_measurements`,
`POST /api/illuminant_measurements/bulk`, `POST /api/multi_image_mapping`,
and the palette/printer-profile `GET` routes (`/printer_profiles`,
`/printer_profiles/:id/colors`, `/printer_profiles/:id/metamer_pairs`,
`/palettes`, `/colors`). These back the macOS companion app's
`PaletteAPIClient`, not this iOS app, and are out of scope per the issue's
"surfaces the app uses today" and non-goals.

The `RankedResults` schema was not fully resolved beyond its required
fields (`schema_version`, `sheet_id`); the prose contract also never pinned
a concrete JSON shape for ranked results. Whoever runs codegen against the
live-fetched spec should treat the generated `RankedResults` type as
authoritative and update this doc if its shape differs further.

## Tests added this pass

Both tests live in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`
and exercise the **current hand-written** `APIClient`/`MeasurementCore`
models (the generated client doesn't exist yet — adding it is out of scope
for this test-only pass):

- `testUploadMeasurementsBodyMatchesPublishedOpenAPISchema` — red: asserts
  the request body `uploadMeasurements` sends contains only the keys the
  published `MeasurementUploadRequest` schema defines. Fails today because
  the hand-written client sends extra `scoring_algorithm_version` and
  `stats` fields (delta 1 above).
- `testPatchMeasurementEncodingOmitsRequiredNormalizedRGBWhenNil` — red:
  asserts the encoded JSON for a `PatchMeasurement` with a nil normalized
  color still includes `normalized_linear_rgb_median`. Fails today because
  Swift's synthesized `Encodable` drops nil optionals (delta 2 above).

These could not be executed with `swift test --disable-sandbox` in this
sandbox (no Swift toolchain on this Linux container). Their failure mode
was verified by hand-tracing against the real schema definitions in
`color_matching`'s `lib/color_matching_web/api_schemas.ex` and against
Swift's documented synthesized-`Codable` behavior (`encodeIfPresent` for
`Optional` properties), not by running the suite.
