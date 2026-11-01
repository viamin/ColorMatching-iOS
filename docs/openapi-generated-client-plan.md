# Generated OpenAPI Swift Client — Test Plan, Wiring Contract, and Contract Deltas

Issue #5 replaces the iOS app's hand-written API layer with a client generated
by [swift-openapi-generator](https://github.com/apple/swift-openapi-generator)
from the OpenAPI spec published by `viamin/color_matching`
(viamin/color_matching#110, served at `GET /api/v1/openapi.json`).

This document is the **implementation contract** for that work:

1. the acceptance-criteria-to-verification map (criterion-level evidence),
2. the exact SwiftPM wiring and vendored-document contract the tests enforce,
3. the **contract deltas** discovered between the prose contract
   (`docs/color-matching-api-contract.md`) and the published spec — this
   section is the source material for the PR description required by the
   issue, and
4. the endpoint gaps discovered.

## 1. Acceptance criteria → verification

| Criterion | Verification | Where |
| --- | --- | --- |
| Generator + runtime added to package; OpenAPI document fetched/vendored | Focused unit tests asserting Package.swift wiring, vendored `openapi.json`, and generator config | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientPackageTests.swift`, `OpenAPISpecContractTests.swift` |
| Client generated for all six surfaces (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results) | Contract tests pinning the six paths, methods, `operationId`s, path parameters, and request/response schema `$ref`s | `OpenAPISpecContractTests.swift`; wire-level decode/encode tests in `OpenAPIClientContractTests.swift` (compiles once `OpenAPIClient` exists) |
| Hand-written API models replaced by generated types; client-side models kept | Wire-behavior regression guards that pass today and must stay green after the swap | `APIClientSurfaceTests.swift` (+ existing `APIClientTests.swift`) |
| Swift tests exercising the generated client against local stubbed responses (no live server) | Generated-client tests driven by a stubbed `ClientTransport` | `OpenAPIClientContractTests.swift` |
| PR description records prose→spec deltas and endpoint gaps | This document (sections 3 and 4) | `docs/openapi-generated-client-plan.md` |

Exit criterion `swift test --disable-sandbox` green with generated types wired
in is satisfied when: the vendored document + wiring land (package/spec tests
turn green) and the `#if canImport`-gated generated-client tests compile and
pass.

## 2. Wiring contract enforced by the tests

### 2.1 Package manifest

* Depend on `https://github.com/apple/swift-openapi-generator` (`from: "1.14.0"`)
  and `https://github.com/apple/swift-openapi-runtime` (`from: "1.13.0"`).
  Note: those releases declare `swift-tools-version 6.2` manifests, so
  `iOS/Package.swift` (currently 5.9) must bump its tools-version; keep the
  existing targets in the Swift 5 language mode (or adopt Swift 6 mode
  deliberately) — the app sources are not yet concurrency-audited.
* New target `OpenAPIClient`:
  * `dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")]`
  * `plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]`
  * depends on nothing else; `ColorMatchingLPSAppCore` (and the
    `ColorMatchingLPSAppTests` test target) depend on `OpenAPIClient`.
* The **test target must declare the dependency** so
  `#if canImport(OpenAPIClient) && canImport(OpenAPIRuntime)` in
  `OpenAPIClientContractTests.swift` becomes true and those tests compile.

### 2.2 Vendored document and generator config

```
iOS/Sources/OpenAPIClient/
├── openapi.json                    <- vendored spec (JSON; plugin accepts openapi.yaml/.yml/.json)
└── openapi-generator-config.yaml   <- accessModifier: public / mode: client
```

```yaml
# openapi-generator-config.yaml
accessModifier: public
mode: client
```

`accessModifier: public` is required so tests can `import OpenAPIClient`
without `@testable`.

### 2.3 Vendored document contents

`docs/openapi-vendored-reference.json` is the complete reference document —
copy it to `iOS/Sources/OpenAPIClient/openapi.json`. It pins:

* the six operations and their `operationId`s (these become the generated
  Swift method names asserted by tests):

  | Method + path | operationId |
  | --- | --- |
  | `GET /api/v1/test_sheets/recent` | `listRecentTestSheets` |
  | `GET /api/v1/test_sheets/{sheet_id}/manifest` | `getTestSheetManifest` |
  | `GET /api/v1/test_sheets/{sheet_id}/ranked_results` | `getTestSheetRankedResults` |
  | `POST /api/v1/test_sheets/{sheet_id}/captures` | `createCaptureSession` |
  | `POST /api/v1/captures/{capture_id}/measurements` | `uploadMeasurements` |
  | `POST /api/v1/captures/{capture_id}/judgments` | `uploadJudgments` |

* `bearerAuth` (HTTP bearer) security on every operation;
* named component schemas so generated type names are deterministic:
  `TestSheetManifest`, `Page`, `Rect`, `RegistrationMarker`, `PrinterProfile`,
  `CaptureProfile`, `Patch`, `PairManifest`, `RecentSheetsResponse`,
  `RecentSheet`, `CaptureRequest`, `CaptureMetadata`, `WhiteBalanceGains`,
  `CaptureQuality`, `CaptureCreatedResponse`, `Rgb`, `MeasurementStats`,
  `PatchMeasurementUpload`, `PairScoreUpload`, `MeasurementUploadRequest`,
  `MeasurementUploadResponse`, `PairJudgmentPayload`, `JudgmentUploadRequest`,
  `JudgmentUploadResponse`, `RankedResults`, `RankedPairResult`,
  `RankedSourceColors`, `RankedScore`, `RankedObservation`;
* required lists matching the payloads the Phoenix app actually renders
  (strict decoding is the point: server-side drift should surface as a decode
  failure or a regeneration diff).

**Property order matters**: the generator preserves the document's property
order (OpenAPIKit ordered dictionaries) in the generated memberwise inits, and
`OpenAPIClientContractTests` constructs payloads with labeled arguments in the
reference document's order. If you regenerate the document from the server,
keep the orders below (all alphabetical unless noted):

* `CaptureMetadata`: `device_model, lens, exposure_duration_seconds, iso,
  focus_lens_position, white_balance_gains, image_width, image_height,
  app_version, timestamp` (server order)
* `CaptureRequest`: `metadata, quality`
* `CaptureQuality`: `detected_marker_count, blur_score, rejections`
* `MeasurementUploadRequest`: `scoring_algorithm_version, measurements,
  pair_scores`
* `PatchMeasurementUpload`: `patch_id, linear_rgb_median,
  normalized_linear_rgb_median, stats`
* `MeasurementStats`: `sample_count, clipping_fraction, mean,
  standard_deviation`
* `PairScoreUpload`: `pair_id, algorithm_version, distance, similarity`
* `WhiteBalanceGains` / `Rgb`: `red/green/blue`, `r/g/b`

### 2.4 Re-fetch procedure (drift workflow)

1. `curl $SERVER/api/v1/openapi.json > served.json`
2. `diff` against `iOS/Sources/OpenAPIClient/openapi.json`.
3. Any server-side change shows up as a diff; reconciled extensions are the
   ones listed in section 3 (manifest geometry, ranked results detail, stats,
   operationIds). Extend/adjust, regenerate, fix compile errors.

## 3. Contract deltas: prose contract vs published spec

Sources: `docs/color-matching-api-contract.md` vs the shipped
`ColorMatchingWeb.ApiSchemas` / `ColorMatchingWeb.ApiSpec` / controllers /
`ColorMatchingWeb.TestSheetJSON` in viamin/color_matching (as of the
`/api/v1/openapi.json` spec shipped in viamin/color_matching#110).

### 3.1 Manifest (`GET /api/v1/test_sheets/{sheet_id}/manifest`)

* **Spec schema under-documents the payload.** The served
  `TestSheetManifest` schema only declares `schema_version`, `sheet_id`,
  `capture_profile` (with `scoring_algorithm_version`). The rendered response
  also carries `sheet_version`, `manifest_url`, `created_at`, `page`,
  `registration_markers`, `printer_profile`, `patches`, `pairs` — all
  undeclared server-side. A naive generated client would drop the geometry the
  app needs. → Vendored doc declares them (this is the main extension).
* **`printer_profile` field names differ from prose.** Prose documents
  `{id, name, paper, ink, settings}`; the server renders
  `{printer_make_model, paper_type, ink_type, icc_profile, print_settings,
  driver_name, driver_version, calibration_date, calibration_version, notes}`.
  The prose shape never existed. The hand-written iOS model never decoded
  `printer_profile` at all, so this was invisible.
* **Patch ids are `<pair_id>#<side>`** (e.g. `pair_1#first`), not `patch_1`
  as the prose example implies.
* **`manifest_url` is path-only** (`/api/v1/test_sheets/<code>/manifest`),
  not an absolute URL as the prose example shows.
* Vendored doc adds explicit `operationId` (the served spec's operationIds are
  controller-derived and not stable Swift method names).

### 3.2 Recent sheets (`GET /api/v1/test_sheets/recent`)

* `title` is declared and rendered but **always `null` today**
  (`render_recent_sheet` hardcodes `title: nil`). Prose says "may be null".

### 3.3 Capture creation (`POST /api/v1/test_sheets/{sheet_id}/captures`)

* **Status is 201** with body `{"capture_id": "<integer-as-string>"}`.
  `capture_id` is the stringified integer capture id.
* The served `CaptureRequest` schema is an `anyOf`: the nested
  `{metadata, quality}` form **or** a flat form whose keys live at top level
  (and which spells exposure as `exposure_duration` — **no `_seconds`
  suffix** — in the flat variant). The app uses the nested form; the vendored
  doc narrows to it.
* `iso` is declared **integer** (min 0, exclusive) while the app's
  `CaptureMetadata.iso` is `Float` — conversion is required at the boundary
  (the hand-written encoder could silently send `100.0`, which the server's
  CastAndValidate would reject as a float where an integer is declared).
* `white_balance_gains` is a bare `type: object` in the served spec; the app
  sends `{red, green, blue}` floats. Vendored doc declares the three fields.
* `quality.rejections` is a free-form string array in the served spec; prose
  and the app's `CaptureRejection` enum know exactly six values. Vendored doc
  adds the enum.

### 3.4 Measurement upload (`POST /api/v1/captures/{capture_id}/measurements`)

* **No top-level `scoring_algorithm_version` in the served schema.** The app
  sends it (and the server tolerates extra properties); vendored doc declares
  it to keep the app's payload typed.
* **`stats` is not in the served schema at all.** The app sends
  `sample_count`, `clipping_fraction`, `mean`, `standard_deviation` today;
  server-side they are accepted-and-ignored (OpenApiSpex allows additional
  properties). Vendored doc declares them. (If the Phoenix app wants to
  persist stats, that is upstream work — see endpoint gaps.)
* **`normalized_linear_rgb_median` is required and non-nullable** in the
  served schema. The app's `PatchMeasurement.normalizedLinearRGBMedian` is
  optional — an upload with `null` would 422 server-side. The app must
  resolve a value (or upload only normalized measurements) at the boundary.
* `measurements` and `pair_scores` are **optional** in the served schema;
  the app always sends both; vendored doc requires both.
* **RGB payloads are `anyOf` (array | `{r,g,b}` object | string)** in the
  served schema (`RgbPayload`). The app uses the object form; vendored doc
  narrows to it.
* **Pair scores**: served schema requires `pair_id` + `algorithm_version` and
  `anyOf` score|similarity|distance; the app sends both `distance` and
  `similarity`; vendored doc requires both.
* **Response is 200 with a JSON body**
  `{capture_id, measurement_count, pair_score_count}` — the prose contract
  implied an empty/204 response, and the hand-written client discards the
  body.

### 3.5 Judgment upload (`POST /api/v1/captures/{capture_id}/judgments`)

* **Response is 200 with a JSON body** `{capture_id, judgment_count}` (again,
  not 204/empty).
* `judgment` is a free-form string in the served schema; prose documents
  `match | near_match | no_match`. Vendored doc keeps it a plain string
  (server-faithful).

### 3.6 Ranked results (`GET /api/v1/test_sheets/{sheet_id}/ranked_results`)

* Exists and renders `lps-ranked-results/v1` with per-pair aggregate scores,
  source colors, current judgment, capture provenance, and printer profile —
  but the **served schema only declares `schema_version` and `sheet_id`**.
  Vendored doc pins the rendered shape (rank, pair_id,
  scoring_algorithm_version, row/col, source_colors{color_a_hex,color_b_hex},
  score{average,latest,minimum,maximum,capture_count,sample_count,
  algorithm_versions}, current_judgment (nullable), observation_count,
  capture_count).
* Error responses (`401/404/422`) are `{"errors": ...}` per the served
  `ErrorResponse` schema — undocumented in prose.

### 3.7 Authentication

* Both agree on `Authorization: Bearer <token>`; the published spec applies
  it to every `/api/v1` route except `/openapi.json`.

## 4. Endpoint gaps discovered

1. **The app never implemented ranked results.** The prose contract describes
   `GET /api/v1/test_sheets/{sheet_id}/ranked_results`, the server implements
   it, and the hand-written `APIClient` has no method for it. The generated
   client now types it; wiring an app-facing consumer of ranked results is
   follow-up product work (out of scope for #5's non-goals).
2. **Two server routes are entirely undocumented in prose**:
   `POST /api/illuminant_measurements` (+ `/bulk`) and
   `POST /api/multi_image_mapping` (PNG-capable). Not consumed by the iOS app
   today; excluded from the vendored document.
3. **Palette/printer-profile discovery routes** (`/printer_profiles`,
   `/palettes`, `/colors`, `/metamer_pairs`) exist in the published spec but
   not in the app's contract and are unused by the app; excluded from the
   vendored document.
4. **Measurement `stats` round-trip**: the app uploads stats the server
   ignores; ranked results expose server-computed aggregates instead. If the
   app's own stats matter upstream, that belongs in viamin/color_matching.

## 5. Test inventory and expected states (red phase)

| Test file | Compiles today | State before implementation | State after |
| --- | --- | --- | --- |
| `APIClientSurfaceTests.swift` | yes | passes (guards current wire behavior) | must still pass (re-backed client preserves wire contract) |
| `OpenAPIClientPackageTests.swift` | yes | fails (no generator/runtime wiring, no vendored doc/config) | passes |
| `OpenAPISpecContractTests.swift` | yes | fails (no vendored `openapi.json`) | passes |
| `OpenAPIClientContractTests.swift` | gated by `#if canImport(OpenAPIClient) && canImport(OpenAPIRuntime)` | does not compile-run (module absent, suite still builds) | compiles and passes against the stubbed transport |

The gated file is intentional: in Swift, tests for a not-yet-existing
generated module cannot compile without breaking the rest of the suite; the
`canImport` gate keeps the suite buildable while the package/spec tests
provide the red-phase failure evidence.
