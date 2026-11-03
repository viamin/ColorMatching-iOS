# Generated OpenAPI Client For The iOS Companion

Normative design record for replacing the hand-written API layer in this repo
with a client generated from the machine-readable OpenAPI document published by
`viamin/color_matching`.

This document is the contract that the implementation and the Swift tests in
`iOS/Tests/ColorMatchingLPSAppTests/` are written against.

- Issue: `viamin/ColorMatching-iOS#5`
- Upstream dependency: `viamin/color_matching#110` (issue), landed as
  `viamin/color_matching#113`, merge commit
  `094bd6d3443ddacbda7e63354299867eb5bdfa9f`
- Upstream spec endpoint: `GET /api/v1/openapi.json` (unauthenticated)
- Previous contract of record: `docs/color-matching-api-contract.md`

## Why

The prose contract in `docs/color-matching-api-contract.md` was written by
hand against an API that did not exist yet. It drifted. Once the Phoenix app
publishes an OpenAPI document, this app can generate a typed client from it so
that server-side drift shows up as a regeneration diff (and a compile error)
instead of a runtime surprise at capture time.

## Scope

In scope:

- the five surfaces the app calls today (sheet manifest, recent sheets, capture
  session creation, measurement upload, judgment upload) plus ranked results,
  which the app needs but never implemented;
- replacing the hand-written API models with the generated ones;
- keeping the client-side domain models (`MeasurementCore` geometry, sampling,
  normalization, quality gates, scoring) as they are.

Out of scope:

- new endpoints;
- changes to the app's capture or scoring behaviour.

## Vendoring The Spec

| Path | Purpose |
| --- | --- |
| `iOS/Sources/ColorMatchingOpenAPI/openapi.json` | The single generator input: the upstream OpenAPI document plus the local overlay described below. Committed so that a server-side change shows up as a diff in this file. |
| `iOS/Sources/ColorMatchingOpenAPI/openapi.upstream.json` | The pinned upstream snapshot, used to diff a newer upstream release against the overlay. |
| `iOS/Sources/ColorMatchingOpenAPI/openapi-generator-config.yaml` | Generator configuration (see below). |
| `iOS/Sources/ColorMatchingOpenAPI/Generated/` | The committed generated Swift sources. |
| `iOS/Scripts/regenerate-openapi-client.sh` | Re-fetches the upstream document, re-applies the overlay, and regenerates the Swift sources. |

The upstream document is fetched with:

```bash
curl -fsSL "$COLOR_MATCHING_BASE_URL/api/v1/openapi.json" \
  -o iOS/Sources/ColorMatchingOpenAPI/openapi.upstream.json
```

### Generator configuration

`swift-openapi-generator` (pinned to `1.14.x`) with `swift-openapi-runtime`
as the runtime dependency. The generator configuration must set:

```yaml
namingStrategy: idiomatic
```

`idiomatic` turns `sheet_id` into `sheetId`. To keep the diff against the
existing app code small, the configuration must also pin the acronyms the app
already uses:

```yaml
nameOverrides:
  id: id
  sheet_id: sheetID
  manifest_url: manifestURL
  pair_id: pairID
  patch_id: patchID
  first_patch_id: firstPatchID
  second_patch_id: secondPatchID
  capture_id: captureID
  pair_ids: pairIDs
  safe_inset_mm: safeInsetMM
  linear_rgb_median: linearRGBMedian
  normalized_linear_rgb_median: normalizedLinearRGBMedian
  standard_deviation: standardDeviation
  r: r
  g: g
  b: b
```

With `nameOverrides` in place, the generated property names match the names the
app uses today (`sheetID`, `manifestURL`, `safeInsetMM`, `linearRGBMedian`, …),
so `MeasurementCore` and the SwiftUI shell keep compiling with minimal churn.

## The Local Overlay

The published upstream document under-declares the payloads this app depends
on. The overlay is the documented, reviewable set of local amendments applied
to the upstream document before generation. Every entry below corresponds to a
row in [Contract deltas](#contract-deltas-between-the-prose-contract-and-the-published-spec).

| # | Upstream | Overlay | Why |
| --- | --- | --- | --- |
| O1 | `TestSheetManifest` declares only `schema_version`, `sheet_id`, `capture_profile.scoring_algorithm_version` | Add `sheet_version`, `manifest_url`, `created_at`, `page`, `registration_markers`, `printer_profile`, `patches`, `pairs`; add `capture_profile.expected_illuminant` and `capture_profile.preferred_camera` | Without them the generated manifest type cannot describe a sheet, and `SheetAnalyzer` has nothing to sample. The `printer_profile` object declares `printer_make_model`, `paper_type` and `ink_type` as required strings, and the remaining upstream fields (`icc_profile`, `print_settings`, `driver_name`, `driver_version`, `calibration_date`, `calibration_version`, `notes`) as optional, because the server sends `null` for them. |
| O2 | `CaptureRequest` is `anyOf` [flat attributes, `{metadata}`] and declares `quality` inline | Replace with `{metadata: CaptureMetadata, quality: CaptureQuality}`, both required | The `anyOf` makes the generated request type an enum with two cases and lets the client send a shape the app never wants. The server accepts the nested shape (`flatten_capture_groups/1` in `color_matching`), so pinning it is safe. |
| O3 | `CaptureMetadata.white_balance_gains` is a free-form object | Declare `{red: number, green: number, blue: number}`, all required | A free-form object generates as an untyped JSON blob, which loses the white-balance contract the camera controller produces. |
| O4 | `MeasurementUploadRequest.measurements[]` has no `stats` | Add a required `stats` object: `sample_count`, `clipping_fraction`, `mean`, `standard_deviation` | `CapturePatchMeasurement.changeset/2` in `color_matching` requires all four columns, and the server reads them from `stats` or from flat keys. A generated client only serializes the properties the document declares, so without `stats` the client would send none of them and every upload would be rejected with `422`. |
| O5 | `RgbPayload` is `anyOf` [array, `{r,g,b}` object, JSON string] | Replace with `{r: number, g: number, b: number}`, all required | The app only ever sends the object form; the `anyOf` generates an enum with three cases for no benefit. |
| O6 | `PairScoreRequest` is `anyOf` [`score`, `similarity`, `distance`] | Replace with optional `score`, `similarity`, `distance` numbers, keeping `pair_id` and `algorithm_version` required | The app sends `similarity` and `distance` together (see the prose contract). The `anyOf` generates an enum that can only carry one of them. |
| O7 | `RankedResults` declares only `schema_version` and `sheet_id` | Add `printer_profile`, `capture_count`, `latest_capture_at`, `earliest_capture_at`, `scoring_algorithm_versions`, and `results[]` with `rank`, `pair_id`, `scoring_algorithm_version`, `row`, `col`, `source_colors`, `score`, `current_judgment`, `current_judgment_observed_at`, `observation_count`, `latest_observation`, `capture_count`, `latest_capture_at`, `earliest_capture_at` | The endpoint the prose contract asked for exists and returns data; the document simply does not describe it. |
| O8 | `judgment` is a free-form string | Declare the enum `["match", "near_match", "no_match"]` | `PairFindingObservation.changeset/2` validates exactly these three values; the document should say so. |
| O9 | Operations carry router-derived `operationId`s | Pin `getTestSheetManifest`, `getRecentTestSheets`, `getRankedResults`, `createCapture`, `uploadCaptureMeasurements`, `uploadCaptureJudgments` | Stable generated method names; without them the generated names depend on the router internals of the upstream app. |

The overlay narrows nothing the server rejects: every shape it produces is
accepted by the running `color_matching` app.

## Generated Surface

| Surface | HTTP | `operationId` | Response schema |
| --- | --- | --- | --- |
| Test-sheet manifest | `GET /api/v1/test_sheets/{sheet_id}/manifest` | `getTestSheetManifest` | `TestSheetManifest` |
| Recent sheets | `GET /api/v1/test_sheets/recent` | `getRecentTestSheets` | `RecentSheetsResponse` |
| Ranked results | `GET /api/v1/test_sheets/{sheet_id}/ranked_results` | `getRankedResults` | `RankedResults` |
| Capture session | `POST /api/v1/test_sheets/{sheet_id}/captures` | `createCapture` | `CaptureCreatedResponse` |
| Measurement upload | `POST /api/v1/captures/{capture_id}/measurements` | `uploadCaptureMeasurements` | `MeasurementUploadResponse` |
| Judgment upload | `POST /api/v1/captures/{capture_id}/judgments` | `uploadCaptureJudgments` | `JudgmentUploadResponse` |

## App-Facing Client

`ColorMatchingLPSAppCore.APIClient` stays the single entry point the app uses.
It is now a thin façade over the generated client; the generated types replace
the hand-written API models.

```swift
public struct APIClient {
    public init(token: String? = nil, session: URLSession = .shared)

    public func fetchManifest(from url: URL) async throws -> SheetManifest
    public func fetchManifest(baseURL: URL, sheetCode: String) async throws -> SheetManifest
    public func fetchRecentSheets(baseURL: URL) async throws -> [RecentSheet]
    public func createCapture(
        sheetID: String,
        baseURL: URL,
        metadata: CaptureMetadata,
        quality: CaptureQuality
    ) async throws -> CaptureSessionResponse
    public func uploadMeasurements(
        captureID: String,
        baseURL: URL,
        measurements: [PatchMeasurement],
        scores: [PairScore]
    ) async throws
    public func uploadJudgments(
        captureID: String,
        baseURL: URL,
        judgments: [PairJudgment]
    ) async throws
    public func fetchRankedResults(baseURL: URL, sheetCode: String) async throws -> RankedResults
}
```

Rules:

- `session:` stays injectable so tests can stub the transport; the façade
  builds the generated client's `URLSessionTransport` from it.
- When `token` is non-empty the request carries
  `Authorization: Bearer <token>`.
- A response whose status code is not `2xx` is surfaced as an error; the
  façade never reports a failed request as a successful fetch.
- The generated wire types are re-exported under the names the app already
  uses, so the app code and the existing tests barely change:

  | App name | Generated schema |
  | --- | --- |
  | `SheetManifest` | `TestSheetManifest` |
  | `Page` | manifest `page` object |
  | `RegistrationMarker` | manifest `registration_markers` item |
  | `Patch` | manifest `patches` item |
  | `PairManifest` | manifest `pairs` item |
  | `RecentSheet` | recent-sheets item |
  | `CaptureMetadata` | `CaptureMetadata` |
  | `WhiteBalanceGains` | `CaptureMetadata.white_balance_gains` |
  | `CaptureSessionResponse` | `CaptureCreatedResponse` |
  | `PairJudgment` | judgment-upload item |
  | `RankedResults` | `RankedResults` |

- `CaptureQuality`, `CaptureRejection`, `PatchMeasurement`, `ChannelStats`,
  `PairScore`, `RGB` and the geometry types stay hand-written: they are
  client-side models (they carry typed rejections, min/max statistics and
  geometric helpers that the API never sends). The façade maps them onto the
  generated request types.
- The upload endpoints answer with counts (`measurement_count`,
  `judgment_count`). The façade discards them for now, because the app only
  reports success or failure; the generated `MeasurementUploadResponse` and
  `JudgmentUploadResponse` types stay available for a follow-up.
- `fetchManifest(from:)` keeps working for the pasted-manifest-URL flow by
  parsing the sheet code out of the URL and delegating to
  `fetchManifest(baseURL:sheetCode:)`.

### Naming is pinned by the existing tests

`iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` already refers to
`captureID`, `sheetID`, `manifestURL`, `safeInsetMM`, `linearRGBMedian`,
`normalizedLinearRGBMedian`, `pairID` and `patchID`. The `nameOverrides`
table above is what keeps those names valid once the types are generated, so
it is not optional.

## Contract Deltas Between The Prose Contract And The Published Spec

Read `docs/color-matching-api-contract.md` against
`viamin/color_matching#113`. Every row below was checked against the upstream
source, not against the prose document.

| # | Surface | Prose contract | Published spec / server | Impact |
| --- | --- | --- | --- | --- |
| D1 | Manifest | 11 top-level fields | `TestSheetManifest` declares 3 | Manifest unusable from the generated type without overlay O1 |
| D2 | Manifest | `printer_profile` has `id`, `name`, `paper`, `ink`, `settings` | Server sends `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`, `print_settings`, `driver_name`, `driver_version`, `calibration_date`, `calibration_version`, `notes`; no `id`, no `name`, no `settings` | Prose contract's printer profile shape does not exist |
| D3 | Manifest | `capture_profile` has `expected_illuminant`, `preferred_camera`, `scoring_algorithm_version` | Only `scoring_algorithm_version` is declared | Partly under-declared |
| D4 | Manifest | Documents `role: "reference"` patches with reference roles `white`, `gray`, `black`, `blank_paper` | The server only ever renders `role: "pair_color"` with `reference_role: null` | **The server emits no reference patches at all**, so `MeasurementCore`'s reference normalization cannot run against real data. Needs a `color_matching` change, not an iOS change. |
| D5 | Recent sheets | `{sheets: [{sheet_id, manifest_url, title}]}`, `title` nullable | Identical | No delta |
| D6 | Capture request | `{metadata: {…, exposure_duration_seconds}, quality: {…, rejections}}` | `anyOf` [flat attributes using `exposure_duration`, `{metadata}`]; `quality` inline; `rejection_reasons` at the top level | Nested shape is accepted by the server but not the only shape the document allows; `exposure_duration` vs `exposure_duration_seconds` |
| D7 | Capture metadata | `iso` shown as `100`, type unstated | `iso` is an integer with `exclusiveMinimum: 0` | The app models `iso` as `Float`; the document says integer |
| D8 | Capture metadata | `white_balance_gains` is `{red, green, blue}` | Free-form object | Typed contract lost without overlay O3 |
| D9 | Capture response | `{"capture_id": "capture_123"}` | Identical | No delta; the value is the numeric database id rendered as a string |
| D10 | Measurement upload | Top-level `scoring_algorithm_version` | Not declared; the server reads the per-score `algorithm_version` | The prose contract's top-level field is ignored by the server |
| D11 | Measurement upload | `measurements[].stats` with 4 fields | Not declared at all | **The server requires `sample_count`, `clipping_fraction`, `mean`, `standard_deviation`, but a generated client only serializes the properties the document declares, so an undeclared `stats` object means every upload is rejected.** Overlay O4 is mandatory. |
| D12 | Measurement upload | `normalized_linear_rgb_median` optional | Required | The server's changeset requires the column too |
| D13 | Pair score | `{pair_id, distance, similarity, algorithm_version}` | `pair_id` and `algorithm_version` required, plus exactly one of `score`, `similarity`, `distance` | The app sends two of them at once; overlay O6 |
| D14 | Measurement upload response | Not specified | `200` with `{capture_id, measurement_count, pair_score_count}` | New response body; the app used to expect an empty body |
| D15 | Judgment upload | `{judgments: [{pair_id, judgment}]}` with `match`/`near_match`/`no_match` | Identical shape, but `judgment` is a free-form string | The server validates the three values; the document does not say so (overlay O8) |
| D16 | Judgment upload response | Not specified | `200` with `{capture_id, judgment_count}` | New response body |
| D17 | Ranked results | Prose only: "source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version" | `RankedResults` declares `schema_version` (`lps-ranked-results/v1`) and `sheet_id` only | The endpoint exists and returns rich data; the document does not describe it (overlay O7) |
| D18 | Errors | Not specified | `ApiErrorResponse` with `errors` as an object or a list of `{detail, source{pointer}}` | New |
| D19 | Auth | `Authorization: Bearer <token>` | `bearerAuth`, `http`/`bearer` | No delta |

## Endpoint Gaps

Endpoints the published document covers that the prose contract never mentions
(the app does not need them, but they show the prose contract was not the
authority):

- `GET /api/v1/printer_profiles`
- `GET /api/v1/printer_profiles/{printer_profile_id}/colors`
- `GET /api/v1/printer_profiles/{printer_profile_id}/metamer_pairs`
- `GET /api/v1/palettes`
- `GET /api/v1/colors`
- `GET /api/v1/openapi.json` (the document itself, unauthenticated)
- `POST /api/illuminant_measurements`
- `POST /api/illuminant_measurements/bulk`
- `POST /api/multi_image_mapping`

Endpoints the app needs that the prose contract describes but the published
document under-declares: none missing outright; the manifest, ranked results,
measurement `stats`, and the typed `white_balance_gains` are declared too
narrowly (D1, D8, D11, D17).

Gaps that need a change in `viamin/color_matching`, not here:

- reference patches are never emitted (D4), so the app cannot normalize
  against a real sheet;
- `iso` should accept a fractional value if the app is to keep sending one (D7).

## Stubbed Response Shapes

The tests stub the server with the payloads the upstream Phoenix app actually
produces (`ColorMatchingWeb.TestSheetJSON`). A generated client that cannot
decode these shapes is not usable against the real server, so the vendored
document has to describe them:

| Response | Payload |
| --- | --- |
| `GET .../manifest` | `schema_version`, `sheet_version`, `sheet_id`, `manifest_url`, `created_at`, `page{units,width,height}`, four `registration_markers[{role,shape,rect}]`, `printer_profile{printer_make_model,paper_type,ink_type}`, `capture_profile{expected_illuminant,preferred_camera,scoring_algorithm_version}`, two `patches[{id,role,pair_id,pair_side,reference_role,source_color,safe_inset_mm,rect}]`, one `pairs[{id,first_patch_id,second_patch_id,source_colors,grid_row,grid_col}]` |
| `GET /api/v1/test_sheets/recent` | `sheets[{sheet_id,manifest_url,title}]`, `title` nullable |
| `GET .../ranked_results` | `schema_version`, `sheet_id`, `printer_profile`, `capture_count`, `latest_capture_at`, `earliest_capture_at`, `scoring_algorithm_versions`, `results[{rank,pair_id,scoring_algorithm_version,row,col,source_colors{color_a_hex,color_b_hex},score{average,latest,minimum,maximum,capture_count,sample_count,algorithm_versions},current_judgment,current_judgment_observed_at,observation_count,latest_observation{judgment,observed_at},capture_count,latest_capture_at,earliest_capture_at}]` |
| `POST .../captures` | `201` with `{"capture_id": "cap_1"}` |
| `POST .../measurements` | `200` with `{"capture_id", "measurement_count", "pair_score_count"}` |
| `POST .../judgments` | `200` with `{"capture_id", "judgment_count"}` |

## Xcode Project Wiring

`iOS/ColorMatchingLPS.xcodeproj/project.pbxproj` lists its sources
explicitly, so both the new SwiftPM target and the new test files have to be
registered by hand.

Add to the project:

| Item | Where |
| --- | --- |
| `ColorMatchingOpenAPI` target (generated sources under `Sources/ColorMatchingOpenAPI/Generated`) | new target, linked by `ColorMatchingLPSAppCore` and `ColorMatchingLPSApp` |
| `swift-openapi-runtime` framework | linked by the same targets |
| `GeneratedAPIClientTests.swift` | `ColorMatchingLPSAppTests` group and its `PBXSourcesBuildPhase` |
| `OpenAPISpecDriftTests.swift` | `ColorMatchingLPSAppTests` group and its `PBXSourcesBuildPhase` |

CI runs both `swift test` and `xcodebuild test`, so a test file that is only
wired into `Package.swift` would silently skip the Xcode run.

## CI

`.github/workflows/ci.yml` gains a job that regenerates the client from the
vendored document and fails when the committed sources differ:

```bash
iOS/Scripts/regenerate-openapi-client.sh --check
```

That is what turns a server-side change into a visible diff instead of a
runtime surprise. The job needs no `color_matching` instance, because the
document is vendored.

## Testing Plan

| Test | Kind | Covers |
| --- | --- | --- |
| `APIClientTests.testCreateCaptureEncodesMetadataAndQuality` | unit/service | capture request path, bearer header, `metadata`/`quality` body shape |
| `APIClientTests.testUploadMeasurementsEncodesScoresWithAlgorithmVersion` | unit/service | measurement body shape, per-pair `algorithm_version` |
| `APIClientTests.testUploadJudgmentsEncodesPathAndPayload` | unit/service | judgment request path and body shape |
| `GeneratedAPIClientTests.testFetchManifestUsesSpecPathAndDecodesManifest` | unit/service | manifest endpoint path, bearer header, manifest decode |
| `GeneratedAPIClientTests.testFetchRecentSheetsUsesSpecPathAndDecodesSheets` | unit/service | recent-sheets endpoint path, decode, nullable title |
| `GeneratedAPIClientTests.testCreateCapturePostsSpecPayload` | unit/service | capture endpoint path, `metadata`/`quality` body shape, response decode |
| `GeneratedAPIClientTests.testUploadMeasurementsPostsSpecPayloadWithStats` | unit/service | measurement endpoint path, `stats` and `algorithm_version` body shape |
| `GeneratedAPIClientTests.testUploadJudgmentsPostsSpecPayload` | unit/service | judgment endpoint path, body shape |
| `GeneratedAPIClientTests.testFetchRankedResultsUsesSpecPathAndDecodesResults` | unit/service | ranked-results endpoint path, decode |
| `GeneratedAPIClientTests.testServerErrorIsSurfacedToTheCaller` | unit/service | a `500` does not silently succeed |
| `GeneratedAPIClientTests.testNotFoundIsSurfacedToTheCaller` | unit/service | a `404` does not silently succeed |
| `OpenAPISpecDriftTests.testVendoredDocumentDeclaresEveryEndpointTheAppCalls` | unit/service | the vendored document still describes the six operations the app calls |
| `OpenAPISpecDriftTests.testVendoredDocumentDeclaresManifestPayload` | unit/service | overlay O1 stays in place |
| `OpenAPISpecDriftTests.testVendoredDocumentDeclaresRankedResultsPayload` | unit/service | overlay O7 stays in place |
| `OpenAPISpecDriftTests.testVendoredDocumentDeclaresMeasurementUploadStats` | unit/service | overlay O4 stays in place |
| `OpenAPISpecDriftTests.testVendoredDocumentDeclaresNestedCaptureRequest` | unit/service | overlay O2 stays in place |
| `OpenAPISpecDriftTests.testVendoredDocumentDeclaresTypedWhiteBalanceGains` | unit/service | overlay O3 stays in place |
| `OpenAPISpecDriftTests.testVendoredDocumentPinsOperationIdentifiers` | unit/service | overlay O9 stays in place, generated method names stay stable |

Every HTTP test runs against a stubbed `URLProtocol`; no live server is
contacted, so the suite runs in CI unchanged. The stubs advertise
`Content-Type: application/json` and return the response bodies the published
document declares, because a generated client refuses to decode a body that
does not match the document.

## PR Description Draft

> **Replace the hand-written API layer with a generated OpenAPI Swift client**
>
> **Summary**
>
> - Adds `swift-openapi-generator` and `swift-openapi-runtime` to the iOS
>   package, vendors the OpenAPI document published by `color_matching`
>   (`viamin/color_matching#110`, landed in `#113`), and commits the generated
>   client.
> - Replaces the hand-written API models with the generated ones for the five
>   surfaces the app uses (sheet manifest, recent sheets, capture session
>   creation, measurement upload, judgment upload) and adds the ranked-results
>   surface the app never implemented.
> - Keeps the client-side domain models (geometry, sampling, normalization,
>   quality gates, scoring) unchanged.
> - Adds Swift tests that drive the generated client against stubbed HTTP
>   responses, plus a drift guard that fails when the vendored document stops
>   describing the endpoints the app calls.
>
> **Contract deltas found between `docs/color-matching-api-contract.md` and the
> published spec**
>
> D1–D19 in `docs/openapi-generated-client.md`, summarised:
>
> - The published manifest schema declares only `schema_version`, `sheet_id`
>   and `capture_profile.scoring_algorithm_version`; the eight other fields the
>   app needs (page, registration markers, patches, pairs, printer profile,
>   manifest URL, sheet version, created at) are not in the document.
> - The published printer-profile shape does not match the prose contract
>   (`printer_make_model`/`paper_type`/`ink_type` instead of
>   `id`/`name`/`paper`/`ink`/`settings`).
> - The measurement-upload document omits the `stats` object entirely, while the
>   server requires `sample_count`, `clipping_fraction`, `mean` and
>   `standard_deviation`. A generated client only serializes the properties the
>   document declares, so without `stats` every upload is rejected.
> - The prose contract's top-level `scoring_algorithm_version` is not in the
>   document and is ignored by the server, which reads the per-score
>   `algorithm_version`.
> - `normalized_linear_rgb_median` is required by both the document and the
>   server, but optional in the prose contract.
> - The upload endpoints return a body (`measurement_count`, `judgment_count`)
>   that the prose contract does not mention.
> - The ranked-results endpoint exists and returns ranked pairs with source
>   colours, scores, judgments and capture provenance, but the document
>   declares only `schema_version` and `sheet_id`.
> - `judgment` is a free-form string in the document; the server accepts only
>   `match`, `near_match` and `no_match`.
> - `iso` is an integer in the document; the app models it as a float.
>
> **Endpoint gaps**
>
> - The document also covers `printer_profiles`, `printer_profiles/:id/colors`,
>   `printer_profiles/:id/metamer_pairs`, `palettes`, `colors`, `openapi.json`,
>   `illuminant_measurements`, `illuminant_measurements/bulk` and
>   `multi_image_mapping`, none of which the prose contract mentions.
> - The server never emits reference patches (`role: "reference"`, roles
>   `white`/`gray`/`black`/`blank_paper`), so the app's reference
>   normalization cannot run against real sheets. This needs a
>   `color_matching` change.
>
> **How to regenerate**
>
> ```bash
> iOS/Scripts/regenerate-openapi-client.sh
> ```
