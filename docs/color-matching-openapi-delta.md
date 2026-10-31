# `color_matching` published OpenAPI spec vs. prose contract — delta record

This document records the differences between `docs/color-matching-api-contract.md` (the
hand-written prose contract) and the machine-readable OpenAPI 3 spec published by
`viamin/color_matching#110` (built with `open_api_spex`, served at `GET /api/v1/openapi.json`).
It is the source material for issue #5 ("Replace hand-written API layer with a generated
OpenAPI Swift client") and defines the contract the generated client and its tests pin down.

Sources inspected (server side, `viamin/color_matching@main`):

- `lib/color_matching_web/api_spec.ex` — spec entrypoint, `bearerAuth` security scheme
- `lib/color_matching_web/api_schemas.ex` — component schemas (`TestSheetManifest`,
  `RankedResults`, `CaptureMetadata`, `CaptureRequest`, `CaptureCreatedResponse`,
  `RgbPayload`, `PairScoreRequest`, `MeasurementUploadRequest`, `MeasurementUploadResponse`,
  `JudgmentUploadRequest`, `JudgmentUploadResponse`, `RecentSheetsResponse`, …)
- `lib/color_matching_web/controllers/test_sheet_controller.ex`,
  `capture_controller.ex` — operations, parameters, status codes
- `lib/color_matching_web/router.ex` — route list; operationIds default to
  `ColorMatchingWeb.<Controller>.<action>`

## Wire-level deltas (prose contract → published spec)

1. **Sheet manifest response is guaranteed far less than the prose contract promises.**
   The published `TestSheetManifest` only *requires* `schema_version` (enum
   `lps-sheet-manifest/v1`), `sheet_id`, and `capture_profile.scoring_algorithm_version`
   (enum `lps-distance-v1`). The prose contract's `sheet_version`, `manifest_url`,
   `created_at`, `page`, `registration_markers`, `printer_profile`, `patches`, `pairs`, and
   the other `capture_profile` fields are undocumented. The hand-written
   `SheetManifest` Codable model requires most of those fields, so a spec-conforming
   (minimal) manifest fails to decode today. Generated types make them optional; the app
   must tolerate their absence.
2. **`metadata.iso` (and `image_width`/`image_height`) are integers in the spec.** The app
   currently encodes `iso` as a JSON float (`100.0`), which `OpenApiSpex.Plug.CastAndValidate`
   rejects for `type: :integer`. The generated type is an integer type and forces the fix.
3. **Capture request accepts two shapes.** The spec's `CaptureRequest` allows the nested
   form the app sends (`{metadata: {...}, quality: {detected_marker_count, blur_score,
   rejections}}`) *or* a legacy flat form (which uses `exposure_duration`, not
   `exposure_duration_seconds`, and `rejection_reasons`, not `quality.rejections`). Only the
   nested form is exercised by the app. `quality` fields are all optional in the spec, and
   the prose contract's enumerated rejection strings are not machine-enforced.
4. **Measurement upload loses `stats` and the top-level `scoring_algorithm_version`.** The
   published `MeasurementUploadRequest` declares only `measurements` and `pair_scores`;
   per-measurement `stats` (`sample_count`, `clipping_fraction`, `mean`,
   `standard_deviation`) and the top-level algorithm version are undocumented and are
   dropped from the generated request shape. The algorithm version still travels on every
   `pair_scores[]` entry (`pair_id`, `algorithm_version` required, plus one of
   `score`/`similarity`/`distance`).
5. **`normalized_linear_rgb_median` is required per measurement.** The prose example shows
   it, but the hand-written model treated it as optional; the published schema requires the
   key on every uploaded measurement. The client must not emit a measurement without it.
6. **RGB payloads are `RgbPayload` (`anyOf` [number array, `{r,g,b}` object, string]).** The
   app's `{r,g,b}` objects remain valid; generated types accept all three shapes.
7. **Measurement upload and judgment upload return JSON bodies, not 204.** Published:
   `200` `{capture_id, measurement_count, pair_score_count}` and `200`
   `{capture_id, judgment_count}`. The hand-written client treated these as bodyless 2xx
   (its stubs answered 204). Capture creation remains `201` `{capture_id}`.
8. **Ranked results are now concretely versioned.** The published `RankedResults` schema
   requires `schema_version` (enum `lps-ranked-results/v1` — a version string that does not
   appear anywhere in the prose contract) and `sheet_id`. The prose contract only said the
   endpoint "should return the latest or aggregate ranked results". The iOS app does not
   consume this surface yet; the generated client covers it for future use.
9. **Judgment values are free-form strings in the spec.** The prose contract's enumerated
   `match`/`near_match`/`no_match` are not machine-enforced (same for capture rejection
   strings).
10. **Auth matches the prose contract**: `bearerAuth` (HTTP Bearer) declared per operation
    for all app surfaces. (The server tolerates unauthenticated requests in dev.)

## Endpoint gaps discovered

Present in the published spec but absent from the prose contract (out of scope for this iOS
app — they serve the macOS app / web):

- `GET /api/v1/openapi.json` (the spec itself)
- `GET /api/v1/printer_profiles`
- `GET /api/v1/printer_profiles/{printer_profile_id}/colors`
- `GET /api/v1/printer_profiles/{printer_profile_id}/metamer_pairs`
- `GET /api/v1/palettes`, `GET /api/v1/colors`
- `POST /api/illuminant_measurements`, `POST /api/illuminant_measurements/bulk`
- `POST /api/multi_image_mapping`

Present in the prose contract but undocumented in the spec (the drift the generated client
makes visible as compile errors / regeneration diffs): manifest detail fields
(`page`, `registration_markers`, `patches`, `pairs`, `printer_profile`, …), measurement
`stats`, top-level `scoring_algorithm_version`, and the rejection/judgment enums.

## Implementation contract for the generated client (pinned by the tests)

The tests in `iOS/Tests/ColorMatchingLPSAppTests/` define this contract for the
implementation run:

- **Package wiring**: `iOS/Package.swift` depends on `apple/swift-openapi-generator` (build
  plugin `OpenAPIGenerator`) and `apple/swift-openapi-runtime` (product `OpenAPIRuntime`),
  applied to a generated-client target. Verified by `OpenAPIPackageWiringTests`.
- **Vendored document**: a JSON OpenAPI document under `iOS/` (suggested
  `iOS/Sources/ColorMatchingOpenAPI/openapi.json`) covering the six app paths
  (`/api/v1/test_sheets/recent`, `/api/v1/test_sheets/{sheet_id}/manifest`,
  `/api/v1/test_sheets/{sheet_id}/ranked_results`, `/api/v1/test_sheets/{sheet_id}/captures`,
  `/api/v1/captures/{capture_id}/measurements`, `/api/v1/captures/{capture_id}/judgments`),
  the schema titles `TestSheetManifest`, `RecentSheetsResponse`, `CaptureMetadata`,
  `CaptureRequest`, `MeasurementUploadRequest`, `JudgmentUploadRequest`, `RankedResults`,
  the `bearerAuth` scheme, and the `lps-sheet-manifest/v1`, `lps-distance-v1`,
  `lps-ranked-results/v1` enum values. Verified by `OpenAPIPackageWiringTests`.
- **Generated module name**: `ColorMatchingOpenAPI`. The guarded tests in
  `GeneratedClientContractTests` compile only once the module exists (`#if
  canImport(ColorMatchingOpenAPI)`); until then they fail with a directive to wire the
  module in.
- **OperationIds** (vendor-side naming only; the server ignores them): `getTestSheetManifest`,
  `listRecentSheets`, `getRankedResults`, `createCapture`, `uploadMeasurements`,
  `uploadJudgments`. Set these when vendoring the document so the generated methods are
  readable.
- **Default (defensive) naming strategy** (no generator config file): snake_case property
  names from the spec are preserved (`sheet_id`, `schema_version`, `capture_id`,
  `measurement_count`, …). The guarded tests rely on this.
- **Facade preserved**: `APIClient` keeps its current method signatures
  (`fetchManifest(from:)`, `fetchManifest(baseURL:sheetCode:)`, `fetchRecentSheets(baseURL:)`,
  `createCapture(sheetID:baseURL:metadata:quality:)`,
  `uploadMeasurements(captureID:baseURL:measurements:scores:)`,
  `uploadJudgments(captureID:baseURL:judgments:)`) and its `URLSession` injection, but is
  backed by the generated client. Client-side domain models stay hand-written
  (`CaptureMetadata`, `WhiteBalanceGains`, `CaptureQuality`, `PatchMeasurement`,
  `ChannelStats`, `PairScore`, `PairJudgment`, `RGB`, …); response models are replaced by
  generated types. `APIClientPublishedSpecContractTests` asserts the wire behavior through
  the facade without binding response types, so it compiles before and after the swap.

## Acceptance criteria → verification map

| AC (issue #5) | Verification | Where |
| --- | --- | --- |
| Add generator + runtime; fetch/vendor the OpenAPI document | Unit tests on `Package.swift` + vendored document contents | `OpenAPIPackageWiringTests` (red until implemented) |
| Generate client for manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Vendored-document path/schema assertions + guarded tests exercising the generated client against a stubbed `ClientTransport` | `OpenAPIPackageWiringTests`, `GeneratedClientContractTests` |
| Replace hand-written API models with generated types; keep client-side models | Facade wire-contract tests against stubbed HTTP responses (minimal manifest, integer ISO, no `stats`/top-level algorithm version, required normalized median, JSON 200 upload bodies) | `APIClientPublishedSpecContractTests` (red on the drifted shapes until implemented) |
| Swift tests, stubbed responses, no live server in CI | All new tests use `URLProtocol` stubs or an in-memory `ClientTransport` | All three test files |
| PR description records contract deltas and endpoint gaps | This document (`docs/color-matching-openapi-delta.md`) is the delta record to carry into the PR description | This file |

## Red-phase expectations at this commit

These tests are the red phase of the test-writing run; the implementation run turns them
green. Expected failures at this head:

- `OpenAPIPackageWiringTests` (both tests): no generator dependency, no vendored document.
- `GeneratedClientContractTests` (all tests): `ColorMatchingOpenAPI` module absent.
- `APIClientPublishedSpecContractTests.testFetchManifestDecodesManifestsWithOnlyPublishedRequiredFields`:
  hand-written `SheetManifest` requires prose-only fields.
- `APIClientPublishedSpecContractTests.testCreateCaptureEncodesIntegerISOAndNestedSpecShape`:
  `iso` encodes as `100.0` (spec says integer).
- `APIClientPublishedSpecContractTests.testUploadMeasurementsSendsPublishedSpecBodyShape`:
  emits `stats` and top-level `scoring_algorithm_version`, and omits
  `normalized_linear_rgb_median` when the app model's value is nil.

The remaining facade tests (full-manifest decode, nullable titles, 404 surfacing, judgment
shape) pass today and lock behavior through the migration.
