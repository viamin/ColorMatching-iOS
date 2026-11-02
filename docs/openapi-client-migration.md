# OpenAPI Generated Client Migration — Test Plan and Contract Deltas

Status: **red phase (tests-only)**. This document is the plan of record for
issue #5 ("Replace hand-written API layer with a generated OpenAPI Swift
client"). The tests committed alongside this document specify the behavior the
implementation run must land. They intentionally fail (compile error:
`no such module 'ColorMatchingAPI'`) until the generated client target exists.

## Sources compared

- Prose contract: `docs/color-matching-api-contract.md` (hand-maintained).
- Published spec: viamin/color_matching#110 — `open_api_spex` spec served at
  `GET /api/v1/openapi.json` (source of truth on `main`:
  `lib/color_matching_web/api_spec.ex`, `api_schemas.ex`, controller specs in
  `capture_controller.ex` / `test_sheet_controller.ex`, rendered shapes in
  `test_sheet_json.ex`).

## Contract deltas (prose contract vs published spec + actual rendering)

These must be recorded in the PR description of the implementation PR.

| # | Surface | Prose contract | Published spec / actual | Impact on app |
|---|---------|----------------|-------------------------|---------------|
| D1 | Manifest schema | Full geometry typed: `page`, `registration_markers`, `patches`, `pairs`, `printer_profile`, `sheet_version`, `manifest_url`, `created_at` | Spec declares only `schema_version` (enum `lps-sheet-manifest/v1`), `sheet_id`, `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`). Geometry fields are rendered by the server but **undeclared in the spec** | Generated manifest type alone cannot feed `SheetAnalyzer`; geometry must come from a documented client-side extension of the vendored spec or raw-JSON fallback (endpoint gap G1) |
| D2 | Manifest `printer_profile` | `{id, name, paper, ink, settings}` | `{printer_make_model, paper_type, ink_type, icc_profile, print_settings, driver_name, driver_version, calibration_date, calibration_version, notes}` | No `id`/`name`; prose example is stale |
| D3 | Patch ids | Opaque (`patch_1`) | Rendered as `"<pair_id>#first"` / `"<pair_id>#second"` | Opaque — no app change, but fixtures in tests use the real format |
| D4 | Recent sheets | `{sheets: [{sheet_id, manifest_url, title?}]}` | Same; spec makes `title` required-but-nullable; server always renders `title: null` today | None (app already treats title as optional) |
| D5 | Create capture request | Nested `{metadata, quality}` only | `CaptureRequest` accepts nested `{metadata, quality}` **or** a flat form; flat form renames `exposure_duration_seconds` → `exposure_duration` and `rejections` → `rejection_reasons`; `metadata.iso` is `integer` (app model: `Float`) | Client keeps the nested branch (matches prose). `iso` narrows to integer when mapped to generated types |
| D6 | Measurement upload request | Top-level `scoring_algorithm_version`; measurements carry `stats {sample_count, clipping_fraction, mean, standard_deviation}`; `normalized_linear_rgb_median` optional | No top-level `scoring_algorithm_version`; **no `stats` field at all** (endpoint gap G2); `normalized_linear_rgb_median` **required**; `RgbPayload` is `anyOf: [number[], {r,g,b}, string]` | App's per-patch stats cannot be uploaded through the spec'd shape; scoring version travels per pair score (`algorithm_version`, required) |
| D7 | Measurement upload response | Unspecified (app assumed `204 No Content`; existing hand-written tests stub 204) | **`200 OK` with `{capture_id, measurement_count, pair_score_count}`** | Upload now decodes a body; façade surfaces the counts |
| D8 | Judgment upload response | Unspecified (app assumed 204) | **`200 OK` with `{capture_id, judgment_count}`** | Same as D7 |
| D9 | Ranked results | Vague ("source colors, scores, labels, capture provenance, printer profile, scoring algorithm version") | Spec declares only `schema_version` (new enum `lps-ranked-results/v1`, absent from prose) + `sheet_id`; actual rendering is rich (`capture_count`, `latest/earliest_capture_at`, `scoring_algorithm_versions`, `results[]` with `rank/pair_id/row/col/source_colors/score{average,latest,min,max,capture_count,sample_count,algorithm_versions}/current_judgment/observation_count/latest_observation`) | Server renders far more than the spec declares (endpoint gap G3). App has no client for this surface today |
| D10 | Error responses | Unspecified | `ApiErrorResponse` `{errors: oneOf[object, [{detail, source: {pointer}}]]}`; `CastAndValidate` uses `json_render_error_v2`; documented 401/404/422 per operation | Façade maps non-2xx to `APIError.badStatus(statusCode:)` |
| D11 | Discovery / auth | Bearer token described; no discovery endpoint | `GET /api/v1/openapi.json` (unauthenticated); `bearerAuth` security scheme declared per-operation | Spec is fetched/vendored from the server, drift becomes a regeneration diff |
| D12 | Extra routes | Not in prose | `/api/v1/printer_profiles`, `/printer_profiles/{id}/colors`, `/printer_profiles/{id}/metamer_pairs`, `/palettes`, `/colors`, `/api/illuminant_measurements(+/bulk)`, `/api/multi_image_mapping` | Out of scope for this app; generated client will contain them (harmless) |

### Endpoint gaps discovered (spec does not cover something the app sends/needs)

- **G1**: manifest geometry (`sheet_version`, `manifest_url`, `created_at`,
  `page`, `registration_markers`, `printer_profile`, `capture_profile` beyond
  `scoring_algorithm_version`, `patches`, `pairs`) is undeclared — the iOS app
  cannot switch to generated-only types for the manifest without either a
  client-side spec extension (documented in the vendored copy) or a raw-JSON
  fallback. The implementation must pick one and note it in the PR.
- **G2**: measurement `stats` (sample count, clipping fraction, mean, std dev)
  is not accepted by the published request schema — the app currently uploads
  it as an undeclared field. The façade stops sending `stats` (the spec'd
  shape wins) and the gap is reported upstream.
- **G3**: ranked-results detail fields are undeclared (spec declares only the
  envelope). The façade exposes the declared envelope
  (`schemaVersion`, `sheetID`) and the richer fields stay available for a
  follow-up once the server declares them.

## Target architecture (for the implementation run)

The tests in `iOS/Tests/ColorMatchingLPSAppTests/` pin the following contract.
Module and type names are load-bearing (tests compile against them).

1. **New SPM target `ColorMatchingAPI`** (in `iOS/Package.swift`):
   - Dependencies: `swift-openapi-runtime` (`OpenAPIRuntime`),
     `swift-openapi-urlsession` (`OpenAPIURLSession`).
   - Build plugin: `swift-openapi-generator` (`OpenAPIGenerator` plugin).
   - Inputs: `Sources/ColorMatchingAPI/openapi.json` vendored from the
     Phoenix app's `GET /api/v1/openapi.json` (verbatim, server operationIds
     preserved so a regeneration diff equals server drift) plus
     `openapi-generator-config.yaml` with `generate: [types, client]` and
     `accessModifier: public`. If G1 is solved by extending the manifest
     schema locally, the extension must be called out in the vendored file's
     description and in the PR description.
   - Generated entry point: `Client(serverURL:transport:)` (documented
     convenience initializer).
2. **`ColorMatchingLPSAppCore.APIClient` becomes a façade** over the
   generated client. Hand-written Codable API DTOs
   (`CaptureSessionResponse`, `RecentSheetsResponse`, request wrappers) are
   deleted; `CaptureMetadata`, `WhiteBalanceGains`, `RecentSheet`,
   `PairJudgment` remain as purely client-side models (built by the app,
   mapped to generated wire types inside the façade); `MeasurementCore`
   models are untouched.

```swift
public struct APIClient: Sendable {
    /// - Parameters:
    ///   - baseURL: server root (e.g. https://example.test); the spec's
    ///     paths are absolute (/api/v1/...).
    ///   - token: bearer token; nil or empty sends unauthenticated requests.
    ///   - transport: injectable ClientTransport — tests stub here.
    public init(baseURL: URL, token: String?, transport: any ClientTransport)
}

public func fetchManifest(sheetID: String) async throws -> SheetManifest
public func fetchRecentSheets() async throws -> [RecentSheet]
public func fetchRankedResults(sheetID: String) async throws -> RankedResultsSummary
public func createCapture(sheetID: String, metadata: CaptureMetadata,
                          quality: CaptureQuality) async throws -> String  // capture_id
public func uploadMeasurements(captureID: String, measurements: [PatchMeasurement],
                               scores: [PairScore]) async throws -> UploadSummary
public func uploadJudgments(captureID: String, judgments: [PairJudgment]) async throws -> JudgmentSummary

public struct UploadSummary: Equatable, Sendable {
    public var captureID: String
    public var measurementCount: Int
    public var pairScoreCount: Int
}
public struct JudgmentSummary: Equatable, Sendable {
    public var captureID: String
    public var judgmentCount: Int
}
public struct RankedResultsSummary: Equatable, Sendable {
    public var schemaVersion: String  // "lps-ranked-results/v1"
    public var sheetID: String
}

public enum APIError: Error, Equatable {
    case badStatus(statusCode: Int)  // all documented (401/404/422) and undocumented non-2xx
}
```

Wire behavior pinned by the tests (all handled by the generated client):

- `GET /api/v1/test_sheets/{sheet_id}/manifest` → 200; decodes the full
  rendered manifest (D1/D2/D3 shapes in fixtures).
- `GET /api/v1/test_sheets/recent` → 200 `{sheets: [...]}` with `title: null`.
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results` → 200 envelope (D9).
- `POST /api/v1/test_sheets/{sheet_id}/captures` → 201 `{capture_id}`; request
  uses the nested `metadata`/`quality` branch (D5) with
  `metadata.exposure_duration_seconds` and `quality.rejections`.
- `POST /api/v1/captures/{capture_id}/measurements` → **200 with JSON body**
  (D7); request: `measurements[].{patch_id, linear_rgb_median{r,g,b},
  normalized_linear_rgb_median}` (required, D6) and
  `pair_scores[].{pair_id, algorithm_version, distance}`; **no top-level
  `scoring_algorithm_version`, no `stats`** (G2).
- `POST /api/v1/captures/{capture_id}/judgments` → **200 with JSON body**
  (D8); request `judgments[].{pair_id, judgment}`.
- `Authorization: Bearer <token>` on every operation when a token is set;
  omitted when nil/empty.
- Documented 401/404/422 responses (and undocumented non-2xx) surface as
  `APIError.badStatus(statusCode:)`.

## Acceptance criteria → verification map

| AC | Criterion (from issue #5) | Verification | Where |
|----|---------------------------|--------------|-------|
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` in package; OpenAPI document fetched/vendored from viamin/color_matching#110 | Permanent unit test: `GeneratedClientTests.testGeneratedClientModuleIsAvailableAndConstructible` (import + documented `Client(serverURL:transport:)` init only compiles when the target and deps exist); code inspection of `iOS/Package.swift` + vendored `openapi.json` at implementation PR head | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` |
| AC-2 | Client generated for: manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Permanent unit tests exercising each surface through the façade over the generated client, against stubbed responses (wire assertions on path/method/headers/body + decoded outputs) | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (manifest/recent/capture/measurements/judgments/ranked tests) |
| AC-3 | Hand-written API models replaced by generated types; client-side models kept | `APIClientTests` pin façade outputs (`UploadSummary`, `JudgmentSummary`, `RankedResultsSummary`, retained `CaptureMetadata`/`RecentSheet`); measurement-request test pins the generated wire shape (no `stats`, no top-level scoring version) — proving the hand-written DTO encoders are gone; `MeasurementCoreTests` continue green, unchanged (client-side models untouched) | `APIClientTests.swift`, `MeasurementCoreTests` |
| AC-4 | Swift tests against local stubbed responses, no live server | All stubbing is `MockURLProtocol` at the URLSession layer under `URLSessionTransport`; zero network egress; asserted by test construction (no host beyond `https://example.test` which never resolves — protocolClasses intercept) | `TestSupport.swift` + all tests |
| AC-5 | PR description records contract deltas + endpoint gaps | This document (delta table D1–D12, gaps G1–G3) is the source; PR body must carry the summary | `docs/openapi-client-migration.md` |
| AC-6 | `swift test --disable-sandbox` green with generated types wired in | CI (macOS) `swift test`; this environment has no Swift toolchain, so local run is impossible — recorded as `not_run` here with CI as the evidence at implementation PR head | `.github/workflows/ci.yml` |

## Red-phase expectations (this commit)

- `GeneratedClientTests.swift` fails to compile: `no such module
  'ColorMatchingAPI'` — the generated target does not exist yet.
- `APIClientTests.swift` fails to compile against the façade contract above
  (`APIClient.init(baseURL:token:transport:)`, summary return types) — the
  façade still has the hand-written signatures.
- After the implementation run lands the target + façade, the suite is
  expected green on `swift test --disable-sandbox` with no test edits.
