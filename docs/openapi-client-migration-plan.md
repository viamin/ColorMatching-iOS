# OpenAPI Generated Client Migration Plan (Issue #5)

Test-first migration record for replacing the hand-written API layer with a
Swift client generated from the OpenAPI 3 spec published by
`viamin/color_matching` (upstream issue #110, merged as upstream PR #113; the
spec is served by the Phoenix app at `GET /api/v1/openapi.json` and is also
reconstructable from `lib/color_matching_web/api_spec.ex` +
`lib/color_matching_web/api_schemas.ex`).

This document is the implementation contract for the follow-up implementation
run: the tests committed alongside it define the required surface.

## Target architecture

```
iOS/
  Package.swift                        # adds swift-openapi-generator + swift-openapi-runtime
  Sources/ColorMatchingOpenAPI/
    openapi.json                       # vendored from GET /api/v1/openapi.json
    openapi-generator-config.yaml      # access: public
    (generated code from the plugin)
  Sources/ColorMatchingLPSAppCore/
    APIClient.swift                    # thin wrapper over the generated Client
  Tests/ColorMatchingLPSAppTests/
    GeneratedAPIClientTests.swift      # committed in this run (red)
  Tests/MeasurementCoreTests/
    VendoredOpenAPISpecTests.swift     # committed in this run (red)
```

Package manifest changes required by the tests:

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0")
],
targets: [
    .target(
        name: "ColorMatchingOpenAPI",
        dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")],
        plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
    ),
    // ColorMatchingLPSAppCore and ColorMatchingLPSAppTests gain a dependency
    // on ColorMatchingOpenAPI.
]
```

The spec is served at runtime without DB access
(`OpenApiSpex.Plug.PutApiSpec` builds it from the router), so it can be
vendored with:

```bash
(iex -S mix phx.server in color_matching, then)
curl http://localhost:4000/api/v1/openapi.json > iOS/Sources/ColorMatchingOpenAPI/openapi.json
```

## Wrapper surface contract (what the committed tests demand)

`ColorMatchingLPSAppCore.APIClient` keeps its construction seam
(`init(token:session:)`) so tests can stub via `URLProtocol`, and its method
names, but the API layer types become generated types:

| Method | Returns |
| --- | --- |
| `fetchManifest(from:)` / `fetchManifest(baseURL:sheetCode:)` | client-side `SheetManifest` composite whose spec-guaranteed fields (including the new `scoringAlgorithmVersion`) are sourced from generated `Components.Schemas.TestSheetManifest` |
| `fetchRecentSheets(baseURL:)` | `Components.Schemas.RecentSheetsResponse` |
| `createCapture(sheetID:baseURL:metadata:quality:)` | `Components.Schemas.CaptureCreatedResponse` |
| `uploadMeasurements(captureID:baseURL:measurements:scores:)` | `Components.Schemas.MeasurementUploadResponse` |
| `uploadJudgments(captureID:baseURL:judgments:)` | `Components.Schemas.JudgmentUploadResponse` |
| `fetchRankedResults(sheetID:baseURL:)` (new) | `Components.Schemas.RankedResults` |

Input models that are purely camera/measurement concerns (`CaptureMetadata`
payload value, `CaptureQuality`, `PatchMeasurement`, `PairScore`,
`PairJudgment` — see `MeasurementCore`) stay as-is; the wrapper maps them into
generated request types. Non-2xx documented statuses must surface as thrown
errors (the generated client returns them as outputs; the wrapper converts).

The vendored spec must live at
`iOS/Sources/ColorMatchingOpenAPI/openapi.json` with an
`openapi-generator-config.yaml` using public access; the module must be named
`ColorMatchingOpenAPI` (tests import it).

## Contract deltas: prose contract vs published spec

Comparing `docs/color-matching-api-contract.md` against the published spec
(schema titles from `ColorMatchingWeb.ApiSchemas`):

| Area | Prose contract | Published spec | Delta |
| --- | --- | --- | --- |
| Manifest | rich manifest: `sheet_version`, `manifest_url`, `created_at`, `page`, `registration_markers`, `printer_profile`, `capture_profile{expected_illuminant, preferred_camera, scoring_algorithm_version}`, `patches`, `pairs` | `TestSheetManifest` guarantees only `schema_version` (enum `lps-sheet-manifest/v1`), `sheet_id`, `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`) | everything the app analyzes (patches/pairs/page/markers) is beyond-spec; allowed as extra properties but not typed by the generated client |
| Recent sheets | `sheets[]{sheet_id, manifest_url, title?}` | identical shape; `title` is required-but-nullable | none |
| Capture request | single nested `{metadata{...}, quality{...}}` | `CaptureRequest` accepts `anyOf` nested form **or** flat legacy form | flat form renames `exposure_duration_seconds`→`exposure_duration` and `rejections`→`rejection_reasons`; nested `quality` fields are all optional; `iso` is `integer` (app encodes `Float`, must stay integral); `white_balance_gains` is a free-form object |
| Capture response | `{"capture_id": "..."}` | `CaptureCreatedResponse` same, status 201 documented, plus 401/404/422 `ApiErrorResponse` | none (errors newly typed) |
| Measurement upload | top-level `scoring_algorithm_version`; items carry optional `normalized_linear_rgb_median` and a `stats` block; no response documented | top-level `scoring_algorithm_version` **removed**; `pair_scores[].algorithm_version` required (+ anyOf score/similarity/distance); `normalized_linear_rgb_median` **required**; `stats` absent; `RgbPayload` is anyOf number-array / `{r,g,b}` / string; response 200 `MeasurementUploadResponse{capture_id, measurement_count, pair_score_count}` | uploads return JSON bodies — the hand-written client (and its tests) assumed empty-body 2xx/204; top-level algorithm version must no longer be sent |
| Judgment upload | no response documented; judgment values enumerated (`match`, `near_match`, `no_match`) | response 200 `JudgmentUploadResponse{capture_id, judgment_count}`; `judgment` is a free string (enum not enforced) | response body newly typed; prose enum unenforced server-side |
| Ranked results | "source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version" (no schema) | `RankedResults` only guarantees `schema_version` (new enum `lps-ranked-results/v1`, absent from prose) and `sheet_id` | all prose-promised payload fields are beyond-spec |
| Auth | bearer token | `bearerAuth` security scheme; 401/404/422 documented with `ApiErrorResponse` (errors is oneOf object or array of `{detail, source{pointer}}`) | error shapes newly documented |

## Endpoint gaps discovered

1. The manifest endpoint does not guarantee any capture-analysis data
   (patches, pairs, page geometry, registration markers). The app must keep
   client-side decoding for those fields until upstream grows the schema.
2. `stats` (sample_count/clipping_fraction/mean/standard_deviation) are not
   in the spec. Sending them is tolerated (no `additionalProperties: false`)
   but the generated request type drops them. If the server persists them,
   upstream must add them to the spec; otherwise they are dead payload.
3. `ranked_results` carries none of the content the prose contract promised;
   the generated client exposes only `schema_version`/`sheet_id`. The iOS app
   does not consume this endpoint today — wrapper support is generated-only.
4. Upload endpoints return JSON bodies; anything assuming empty 2xx (the
   hand-written client and its existing tests, which stub 204) is drift.
5. The spec includes endpoints the app does not use (printer_profiles,
   palettes, colors, metamer_pairs, illuminant_measurements(+bulk),
   multi_image_mapping, openapi.json itself). The generated client will
   include them; the app ignores them.

## Acceptance criteria → verification mapping

| Criterion | Verification | Locator |
| --- | --- | --- |
| AC-1 generator+runtime added; spec vendored | unit test: vendored `openapi.json` exists, is OpenAPI 3, covers the six app surfaces and required schemas; generator config uses public access | `iOS/Tests/MeasurementCoreTests/VendoredOpenAPISpecTests.swift` |
| AC-2 client generated for manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | unit tests per surface: stubbed 200/201 responses decode into generated types; request paths match the spec | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedAPIClientTests.swift` |
| AC-3 hand-written API models replaced with generated types | compile-level: tests annotate results as `Components.Schemas.*` and import `ColorMatchingOpenAPI`; `SheetManifest.scoringAlgorithmVersion` sourced from the generated manifest type | same file |
| AC-4 stubbed-response tests, no live server | all generated-client tests stub via `URLProtocol`; no network in CI | same file |
| AC-5 PR description records contract deltas and gaps | human/external: delta table + gap list above, to be carried into the PR description | `docs/openapi-client-migration-plan.md` |

## Red-phase expectations (this run)

- `VendoredOpenAPISpecTests` compiles and **fails assertions** (spec not yet
  vendored).
- `GeneratedAPIClientTests` imports `ColorMatchingOpenAPI`, which does not
  exist yet, so `swift test` cannot build the `ColorMatchingLPSAppTests`
  target until the implementation run adds the generated module. That build
  failure is the intended red evidence for AC-2/AC-3.
- Existing `APIClientTests` (which stub 204 empty uploads) pass today and must
  be updated in the implementation run to the spec's 200+JSON responses; they
  are intentionally left untouched here.
