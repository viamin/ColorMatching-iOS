# Generated OpenAPI client — tests-first contract for issue #5

Status: **red phase (tests only)**. This document pins the contract that the
accompanying tests in `iOS/Tests/ColorMatchingLPSAppTests/` encode. The
implementation run must satisfy them by vendoring the published OpenAPI
document, generating a typed client, and wiring it into the package.

Upstream dependency status: viamin/color_matching#110 is complete — PR
viamin/color_matching#113 (merged 2026-10-30) publishes an OpenAPI 3 spec at
`GET /api/v1/openapi.json` built with `open_api_spex` from
`lib/color_matching_web/api_spec.ex` + `api_schemas.ex` + controller specs.

## Acceptance criteria → verification mapping

| AC (from issue #5) | Verification | Locator |
|---|---|---|
| OpenAPI document vendored in the iOS package | Permanent unit test asserting the document exists, is OpenAPI 3, and covers the six app operations | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPISpecCoverageTests.swift` |
| Client generated for all surfaces used today (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results) | Permanent unit tests exercising the generated client against stubbed transports (no live server) | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` |
| Hand-written API models replaced by generated types | Same tests compile only once the `ColorMatchingOpenAPI` target exists and is a dependency of the test target; an explicit red test fails while the module is missing | `GeneratedClientTests.swift` (`GeneratedOpenAPIClientNotWiredTests`) |
| Contract deltas recorded | Delta table below (discovered from the published spec sources); the implementation PR description must reproduce it | this file |
| `swift test --disable-sandbox` green | CI (`swift test` on macOS); this container has no Swift toolchain, so the red suite was not runnable locally — see Infrastructure notes | `.github/workflows/ci.yml` |

## Naming contract for the implementation run

The tests prescribe the following. Deviations require updating the tests in the
same implementation PR with rationale.

- Vendored document: `iOS/OpenAPI/openapi.json` (JSON, OpenAPI 3.x).
- Generated target: `ColorMatchingOpenAPI`, built by the
  `OpenAPIGenerator` plugin from `swift-openapi-generator`, depending on
  `OpenAPIRuntime` from `swift-openapi-runtime` (resolved 1.13.x line).
- `ColorMatchingLPSAppTests` depends on both `ColorMatchingOpenAPI` and
  `OpenAPIRuntime` (needed to stub `ClientTransport`).
- `ColorMatchingLPSAppCore` depends on `ColorMatchingOpenAPI` when the
  hand-written `APIClient` is replaced.

### Pinned operationIds

`open_api_spex` derives operationIds as `ColorMatchingWeb.<Controller>.<action>`,
which sanitize into unusable Swift method names. The vendoring step pins them:

| Path | Method | Upstream operationId | Vendored operationId |
|---|---|---|---|
| `/api/v1/test_sheets/{sheet_id}/manifest` | get | `ColorMatchingWeb.TestSheetController.manifest` | `getTestSheetManifest` |
| `/api/v1/test_sheets/recent` | get | `ColorMatchingWeb.TestSheetController.recent` | `listRecentTestSheets` |
| `/api/v1/test_sheets/{sheet_id}/ranked_results` | get | `ColorMatchingWeb.TestSheetController.ranked_results` | `getRankedResults` |
| `/api/v1/test_sheets/{sheet_id}/captures` | post | `ColorMatchingWeb.CaptureController.create` | `createCapture` |
| `/api/v1/captures/{capture_id}/measurements` | post | `ColorMatchingWeb.CaptureController.upload_measurements` | `uploadMeasurements` |
| `/api/v1/captures/{capture_id}/judgments` | post | `ColorMatchingWeb.CaptureController.upload_judgments` | `uploadJudgments` |

This is a name-only transform; path/method/schema drift still surfaces as a
regeneration diff.

### Pinned component schema names

`TestSheetManifest` (upstream title), `RecentSheetsResponse`, `CaptureRequest`,
`CaptureMetadata`, `WhiteBalanceGains`, `CaptureQuality`,
`CaptureCreatedResponse`, `Rgb`, `MeasurementUpload`, `MeasurementStats`,
`PairScoreUpload`, `MeasurementUploadRequest`, `MeasurementUploadResponse`,
`PairJudgment`, `JudgmentUploadRequest`, `JudgmentUploadResponse`,
`RankedResults`, `RankedPairResult`, `ApiErrorResponse`.

Every property each coverage test lists is declared `required` in the vendored
document (the server always emits them — verified against `TestSheetJSON`),
and properties are declared in the order the coverage tests list them, since
the generated memberwise initializers follow schema declaration order.

## Contract deltas: prose contract vs published spec

Verified against the merged upstream sources (`api_schemas.ex`,
`test_sheet_json.ex`, controllers, router) on 2026-11-02. The implementation
PR description must record these.

1. **Manifest is only loosely typed.** The published `TestSheetManifest`
   schema declares just `schema_version` (enum `lps-sheet-manifest/v1`),
   `sheet_id`, and `capture_profile.scoring_algorithm_version`. The served JSON
   (`TestSheetJSON.manifest/1`) emits far more: `sheet_version`,
   `manifest_url`, `created_at`, `page`, `registration_markers`,
   `printer_profile`, `patches`, `pairs`. The vendored document must type the
   full payload (see `OpenAPISpecCoverageTests.testManifestSchemaMatchesProseContract`)
   or the generated client cannot replace the hand-written `SheetManifest`
   model. **Endpoint gap.**
2. **`printer_profile` keys differ.** Prose contract: `id`, `name`, `paper`,
   `ink`, `settings`. Real API: `printer_make_model`, `paper_type`, `ink_type`,
   `icc_profile`, `print_settings`, `driver_name`, `driver_version`,
   `calibration_date`, `calibration_version`, `notes`.
3. **Patch ids differ from the prose example.** Real patch ids are
   `"<pair_id>#first"` / `"<pair_id>#second"` (e.g. `pair_1#first`), not
   `patch_1`. Not a schema difference, but fixture-relevant.
4. **Measurement upload response is a 200 JSON body, not 204.** Real API
   returns `{"capture_id", "measurement_count", "pair_score_count"}`. The
   hand-written client ignores bodies here; the generated client decodes them.
   Same for judgment upload (`capture_id`, `judgment_count`). The old
   `APIClientTests` stubbed 204 — those tests will be replaced by the
   generated-client tests.
5. **`scoring_algorithm_version` and measurement `stats` are absent from the
   upstream spec.** The app sends both (`sample_count`, `clipping_fraction`,
   `mean`, `standard_deviation`); the server accepts and persists them
   (persistence layer), but the spec does not type them. **Endpoint gap** —
   the vendored document adds them.
6. **`linear_rgb_median` is an `anyOf` (`RgbPayload`)** accepting an RGB array,
   an `{r,g,b}` object, or a string. The app sends `{r,g,b}` objects. The
   vendored document narrows this to the object form (`Rgb` component) for the
   surfaces the app uses; recorded as a local deviation.
7. **`iso` is typed `integer`** while the iOS model carries `Float`. Swift
   encodes `Float(100)` as `100.0`, which strict integer validation
   (`OpenApiSpex.Plug.CastAndValidate`) rejects. The app must send an integer.
   Drift risk discovered by writing these tests.
8. **Capture creation accepts two shapes** (`anyOf` of legacy flat fields —
   note `exposure_duration`, not `exposure_duration_seconds` — or
   `metadata`+`quality`). The app uses the `metadata`+`quality` shape; the
   vendored document keeps only that shape and drops the legacy branch.
   Recorded as a local deviation.
9. **Judgment values and capture rejections are plain strings in the spec.**
   The prose contract documents allowed values (`match`/`near_match`/`no_match`;
   six camelCase rejection reasons) but the published spec does not enum them.
   Kept as plain strings locally to match upstream; listed as an upstream
   improvement opportunity.
10. **Ranked results are essentially untyped upstream** (`schema_version` enum
    `lps-ranked-results/v1` + `sheet_id` only) while the served payload is rich
    (rank, pair, source colors, aggregated score, current judgment, capture
    provenance). **Endpoint gap** — the vendored document types
    `RankedPairResult` per `TestSheetJSON.ranked_results/1`.
11. **`CaptureController` does not plug `CastAndValidate`** (only
    `TestSheetController` does), so request validation for the capture/measurement/
    judgment POSTs is not enforced server-side yet. Does not block the iOS work;
    recorded for upstream follow-up.

## Infrastructure notes

- This container has no Swift toolchain (`swift` not found), so `swift test`
  could not be executed locally in this run. The suite must be run by CI (or
  the implementation run) on macOS. Expected red state at this commit:
  - `OpenAPISpecCoverageTests` — all tests fail: `iOS/OpenAPI/openapi.json`
    does not exist yet.
  - `GeneratedClientTests` — compiles away via `#if canImport(...)` and fails
    via `GeneratedOpenAPIClientNotWiredTests` (the generated module does not
    exist yet). No live server is required at any point: responses are stubbed
    at the `ClientTransport` level.
