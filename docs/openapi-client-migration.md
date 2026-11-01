# OpenAPI Generated Client Migration (issue #5)

Status: **red-phase tests + plan**. This document records the criterion-level
verification plan for replacing the hand-written API layer with a generated
OpenAPI Swift client, plus the contract deltas found between
`docs/color-matching-api-contract.md` and the published spec from
viamin/color_matching#110 (`GET /api/v1/openapi.json`, built from
`ColorMatchingWeb.ApiSpec` via open_api_spex).

## Target layout

```
iOS/Package.swift                     adds swift-openapi-generator (plugin),
                                      swift-openapi-runtime, swift-openapi-urlsession
iOS/Sources/ColorMatchingAPI/
  openapi.json                        vendored spec (upstream + documented extensions)
  OpenAPIAccess.swift                 optional helpers; Types.swift is generated at build time
iOS/Sources/ColorMatchingLPSAppCore/  APIClient facade rewritten on the generated Client
iOS/Sources/MeasurementCore/          unchanged (purely client-side models stay)
```

The `ColorMatchingAPI` target applies the `OpenAPIGenerator` build plugin to
`openapi.json` and produces `Types.swift`/`Client.swift` at build time. The
generated module is imported as `import ColorMatchingAPI`; schema types live
under `Types.Schemas.*`, the concrete client is `Client`.

## Verification plan (criterion-level)

| AC | Criterion | Verification | Evidence |
|----|-----------|--------------|----------|
| AC-1 | `swift-openapi-generator`/`runtime` added; OpenAPI document vendored | Focused unit tests over the vendored artifact and `Package.swift` | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPISpecCoverageTests.swift` (`testPackageDeclaresOpenAPIGeneratorAndRuntime`, `testVendoredOpenAPIDocumentExistsAndParses`, path/status/auth assertions) |
| AC-2 | Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Stubbed-transport tests calling every generated operation | `GeneratedClientStubbedTransportTests.swift` (one test per surface + typed error cases) |
| AC-3 | Hand-written API models replaced by generated types; client-only models stay | Generated schema coding round-trips + facade behavior tests; existing `MeasurementCoreTests` stay green untouched | `GeneratedTypesCodingTests.swift`, `APIClientGeneratedSurfaceTests.swift`, `MeasurementCoreTests/MeasurementCoreTests.swift` |
| AC-4 | Swift tests exercise the generated client against local stubs, no live server in CI | All new tests use `StubTransport` or `URLProtocol` stubs; no network I/O | same files as AC-2/AC-3; CI runs `swift test` (`.github/workflows/ci.yml`) |
| AC-5 | PR description records contract deltas and endpoint gaps | Human/external evidence: this document, cross-referencing the upstream spec modules | `docs/openapi-client-migration.md` (below) and upstream `api_schemas.ex`/`TestSheetJSON` |

Exit criterion "swift test --disable-sandbox green with generated types wired
in" is satisfied when AC-1..AC-4 all pass; before implementation lands, the
new tests are intentionally red.

## Contract deltas (prose contract vs published spec)

Sources: upstream `lib/color_matching_web/api_schemas.ex`,
`TestSheetController`, `CaptureController`, `TestSheetJSON`, `Router` on
`main` at the time of writing.

1. **Spec discovery**: the spec is served at `GET /api/v1/openapi.json` and is
   not part of the prose contract at all.
2. **Manifest schema is under-declared upstream.** The wire payload (from
   `TestSheetJSON.manifest/1`) carries `sheet_version`, `manifest_url`,
   `created_at`, `page`, `registration_markers`, `printer_profile`,
   `capture_profile`, `patches`, `pairs` — but the upstream
   `TestSheetManifest` component only declares `schema_version`, `sheet_id`,
   and `capture_profile.scoring_algorithm_version`. **Gap**: generated types
   from the raw upstream spec cannot replace the app's manifest model. The
   vendored document extends `TestSheetManifest` with the observed wire
   properties (all optional except the upstream-required three).
3. **`printer_profile` shape differs.** Prose: `{id, name, paper, ink,
   settings}`. Actual wire: `{printer_make_model, paper_type, ink_type,
   icc_profile, print_settings, driver_name, driver_version,
   calibration_date, calibration_version, notes}` (no `id`, no `name`).
4. **`manifest_url` is server-relative** (`/api/v1/test_sheets/<code>/manifest`),
   not an absolute URL as the prose examples show. Applies to recent sheets
   too. The app must resolve it against the base URL when fetching directly.
5. **Patch IDs are server-composed** as `<pair_id>#first` / `<pair_id>#second`
   (prose used opaque `patch_N`). Patch roles are only `pair_color` today;
   `reference`/`reference_role` values are always `null` in practice.
6. **Capture creation** answers `201 Created` (not 200) and `capture_id` is an
   **integer rendered as a string** (e.g. `"42"`), not the prose's
   `"capture_123"` shape. `CaptureRequest` accepts either a flat top-level
   metadata object or the app's `{metadata: {...}, quality: {...}}` envelope
   (anyOf); the app uses the envelope branch. Top-level flat fields use
   `exposure_duration` while `CaptureMetadata` uses
   `exposure_duration_seconds` (upstream inconsistency, noted).
7. **Measurement upload has a response body.** Prose documented none; the
   spec returns `200` with `{capture_id, measurement_count,
   pair_score_count}`. The old hand-written client tolerated any 2xx and
   ignored bodies; the generated client only accepts the declared `200`, so
   stubs using `204` had to be updated (see `APIClientTests`).
8. **`normalized_linear_rgb_median` is required per measurement** in the
   upstream spec (prose implied optional). The app always uploads normalized
   medians alongside raw ones, so it is conformant, but this is a stricter
   server-side validation than the prose contract.
9. **`stats` and top-level `scoring_algorithm_version` are undeclared
   upstream.** The app uploads `stats {sample_count, clipping_fraction, mean,
   standard_deviation}` and a top-level `scoring_algorithm_version`; upstream
   accepts them (open_api_spex permits additional properties) but does not
   document them. **Gap**: the vendored document declares `stats` so the
   payload is typed; `scoring_algorithm_version` stays undeclared (follow-up
   for viamin/color_matching).
10. **Pair score payloads** are `anyOf(score, similarity, distance)` with
    `pair_id` + `algorithm_version` required; the app sends `similarity` and
    `distance` together. `linear_rgb_median` accepts an RGB object, array, or
    encoded string (`RgbPayload` anyOf); the app sends the object form.
11. **Judgment upload answers `200`** with `{capture_id, judgment_count}`
    (prose documented no response).
12. **Ranked results are versioned `lps-ranked-results/v1`** — a schema
    version string absent from the prose contract — and the upstream
    `RankedResults` component only declares `schema_version` + `sheet_id`
    while the wire payload carries `printer_profile`, `capture_count`,
    capture timestamps, `scoring_algorithm_versions`, and a rich `results[]`
    (rank, pair_id, row/col, `source_colors{color_a_hex,color_b_hex}`,
    `score{average,latest,minimum,maximum,capture_count,sample_count,
    algorithm_versions}`, `current_judgment`, `latest_observation`,
    `observation_count`). **Gap**: vendored document extends the component
    with the observed wire properties (optional except the upstream-required
    two).
13. **Error envelope** `{"errors": ...}` (object map, or array of
    `{detail, source{pointer}}`) with statuses `401`/`404`/`422` is entirely
    undocumented in prose. The generated client surfaces these as typed
    response cases; the facade maps them to `APIError.unauthorized`,
    `.notFound`, `.validationFailed`.
14. **Auth matches prose**: `bearerAuth` (HTTP bearer) on every app surface;
    upstream requires the API key plug on all `/api/v1` app routes.

## Vendoring decisions

- The document is vendored as **JSON** (upstream serves JSON; JSON is
  assertable from tests without extra dependencies).
- **Operation IDs are rewritten** from upstream's Elixir-internal
  `"ColorMatchingWeb.TestSheetController.manifest"` style to client-friendly
  stable IDs: `listRecentTestSheets`, `getTestSheetManifest`,
  `getRankedResults`, `createCapture`, `uploadMeasurements`,
  `uploadJudgments`. Paths, parameters, and statuses stay byte-identical;
  operation IDs are not part of the wire contract.
- Extension properties (manifest/ranked-results full field sets,
  measurement `stats`) are declared **optional** to mirror upstream's
  minimal required sets; only upstream-declared `required` arrays are kept.
- Component names for extensions: the ranked-results items and score shapes
  are declared inline under `RankedResults`; measurement `stats` declares
  `sample_count`, `clipping_fraction`, `mean`, `standard_deviation` with
  `{r,g,b}` number objects.
- Follow-ups for viamin/color_matching (not blockers): declare the full
  manifest and ranked-results components upstream, declare measurement
  `stats` and `scoring_algorithm_version`, unify
  `exposure_duration`/`exposure_duration_seconds`.

## Facade contract after migration

`APIClient` keeps its current call surface (callers in
`ColorMatchingLPSApp`/`ContentView` are unchanged) with these spec-driven
additions the tests pin:

- `uploadMeasurements(...) -> MeasurementUploadReceipt` (`captureID`,
  `measurementCount`, `pairScoreCount`)
- `uploadJudgments(...) -> JudgmentUploadReceipt` (`captureID`,
  `judgmentCount`)
- `fetchRankedResults(sheetID:baseURL:) -> [RankedPairResult]` (`rank`,
  `pairID`, `colorAHex`, `colorBHex`, `averageScore`, `currentJudgment`)
- `APIError` gains `unauthorized`, `notFound`, `validationFailed` (typed
  status mapping instead of the old single `badStatus`)
