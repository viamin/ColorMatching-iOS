# Generated OpenAPI Client

`color_matching` now publishes a machine-readable OpenAPI 3 contract
(`viamin/color_matching#110`, landed as PR #113). This document records how the
iOS companion app consumes it, and — most importantly — where the published
contract and the hand-written prose contract
(`docs/color-matching-api-contract.md`) disagree.

## Package Layout

The Swift package in `iOS/` gains one generated target:

```
iOS/
  Package.swift                      # + swift-openapi-generator, swift-openapi-runtime
  Sources/
    ColorMatchingOpenAPI/
      openapi.json                   # vendored OpenAPI document (the generator's input)
      openapi-generator-config.yaml  # generator configuration
```

`swift-openapi-generator` is consumed as a SwiftPM build-tool plugin. The plugin
looks for `openapi.json` (or `.yaml`/`.yml`) and `openapi-generator-config.yaml`
inside the target's sources, so the vendored document has to live next to the
target it feeds.

Expected `Package.swift` wiring:

```swift
.package(url: "https://github.com/apple/swift-openapi-generator", from: "1.10.3"),
.package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.8.0"),
```

```swift
.target(
    name: "ColorMatchingOpenAPI",
    dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
    ]
),
```

The generator config must request `public` access so `ColorMatchingLPSAppCore`
can re-export the generated types:

```yaml
generate:
  - types
  - client
access: public
```

`ColorMatchingLPSAppCore` and `ColorMatchingLPSAppTests` depend on
`ColorMatchingOpenAPI`.

## Refreshing The Vendored Document

The upstream app serves the document at `GET /api/v1/openapi.json`. It can also
be generated without booting the server:

```bash
# in viamin/color_matching
MIX_ENV=test mix openapi.spec.json \
  --spec ColorMatchingWeb.ApiSpec --start-app=false --filename openapi.json
```

Copy the result to `iOS/Sources/ColorMatchingOpenAPI/openapi.json` and commit
it. The iOS repo never talks to a live `color_matching` at build or test time:
the vendored document is the single source of truth for code generation.

## Local Overlay

The published document is **not** usable as-is (see "Contract Deltas" below).
Two classes of change are applied to the vendored copy, and both must stay
traceable:

1. **Upstream verbatim.** Every path, operation, component name and property
   name that upstream publishes is kept as-is, so a future upstream fix shows up
   as a small diff instead of a silent divergence.
2. **Documented local additions.** Where upstream omits a field the server
   really sends (or really requires), the field is added to the vendored copy
   with the server's real JSON key, and the addition is listed in
   "Contract Deltas" below.

The local additions are not guesses: each one is backed by the upstream
controller that renders the payload (`ColorMatchingWeb.TestSheetJSON`,
`ColorMatchingWeb.CaptureController`) or by the upstream persistence layer that
rejects the request without it (`ColorMatching.Persistence.*`).

## API Layer Contract

`ColorMatchingLPSAppCore.APIClient` stays as the app-facing entry point, but it
is now a thin adapter over the generated `ColorMatchingOpenAPI.Client`:

- no hand-written `URLRequest` building, no hand-written `Codable` request or
  response models;
- request and response payloads are the generated
  `ColorMatchingOpenAPI.Components.Schemas.*` types;
- non-2xx responses are surfaced as thrown errors, so callers do not have to
  switch on a generated `Output` enum.

```swift
public struct APIClient {
    public var token: String?
    public var session: URLSession

    public init(token: String? = nil, session: URLSession = .shared)

    public func fetchManifest(from url: URL) async throws -> Components.Schemas.TestSheetManifest
    public func fetchManifest(baseURL: URL, sheetCode: String) async throws -> Components.Schemas.TestSheetManifest
    public func fetchRecentSheets(baseURL: URL) async throws -> Components.Schemas.RecentSheetsResponse
    public func createCapture(sheetID: String, baseURL: URL, request: Components.Schemas.CaptureRequest) async throws -> Components.Schemas.CaptureCreatedResponse
    public func uploadMeasurements(captureID: String, baseURL: URL, request: Components.Schemas.MeasurementUploadRequest) async throws -> Components.Schemas.MeasurementUploadResponse
    public func uploadJudgments(captureID: String, baseURL: URL, request: Components.Schemas.JudgmentUploadRequest) async throws -> Components.Schemas.JudgmentUploadResponse
    public func fetchRankedResults(sheetID: String, baseURL: URL) async throws -> Components.Schemas.RankedResults
}
```

The bearer token is applied by wrapping the transport, so it is sent on every
request exactly like the hand-written client used to send it.

Models that are purely client-side stay where they are: `RGB`, `Point`, `Rect`,
`PatchMeasurement`, `ChannelStats`, `PairScore`, `CaptureQuality`,
`SheetAnalysis` and friends stay in `MeasurementCore`.

## Contract Deltas

`docs/color-matching-api-contract.md` is the hand-written prose contract this
app was built against. The table below compares it with the published OpenAPI
document and with the behaviour of the upstream Phoenix app. "Impact" is what
the iOS app has to do about it.

| # | Area | Prose contract | Published OpenAPI document | Upstream behaviour | Impact |
| --- | --- | --- | --- | --- | --- |
| D1 | Manifest payload | 12 documented fields | `TestSheetManifest` declares only `schema_version`, `sheet_id`, `capture_profile.scoring_algorithm_version` | returns every prose field | the generated manifest type is missing `page`, `registration_markers`, `printer_profile`, `patches`, `pairs` — the app cannot sample patches without them, so the vendored copy must declare them |
| D2 | Manifest `printer_profile` | `{id, name, paper, ink, settings}` | not declared | `{printer_make_model, paper_type, ink_type, icc_profile, print_settings, driver_name, driver_version, calibration_date, calibration_version, notes}` | different shape; use the upstream keys |
| D3 | Manifest `capture_profile` | `{expected_illuminant, preferred_camera, scoring_algorithm_version}` | only `scoring_algorithm_version` | returns all three | illuminant/camera hints are missing from the published schema |
| D4 | Patch and pair identifiers | opaque (`patch_1`) | not declared | patch id is `"<pair_id>#<side>"`, pair id is the sheet pair id | ids are derived, not sequential |
| D5 | Recent sheets | `{sheets:[{sheet_id, manifest_url, title?}]}` | matches, `title` is required **and** nullable | `title` is always `null` | title cannot be relied on yet |
| D6 | Capture creation body | `{metadata:{…}, quality:{…}}` | `CaptureRequest` allows flat fields **or** `metadata`, plus `quality` | accepts both | `anyOf` next to `properties` is dropped by OpenAPIKit, so the published schema cannot be generated from — see "Generator Blockers" |
| D7 | Capture metadata | `iso`, `focus_lens_position`, `white_balance_gains`, `exposure_duration_seconds` optional | `device_model`, `lens`, `image_width`, `image_height`, `app_version`, `timestamp` required; `white_balance_gains` is a free-form object | same | no typed shape for the white-balance gains |
| D8 | Capture response | `{"capture_id": "…"}` | `CaptureCreatedResponse` | `capture_id` is the numeric capture id rendered as a string | matches |
| D9 | Measurement upload body | root `scoring_algorithm_version` plus a per-measurement `stats` object | `MeasurementUploadRequest` has only `measurements` and `pair_scores`; measurement items carry `patch_id`, `linear_rgb_median`, `normalized_linear_rgb_median` and **no** `stats`; there is no root algorithm version | `CapturePatchMeasurement` **requires** `sample_count`, `clipping_fraction`, `mean` and `standard_deviation`, nested under `stats` or sent flat | the published request type would silently drop the stats the server requires; the vendored copy must add them |
| D10 | `normalized_linear_rgb_median` | optional | required | required | the app must always upload normalized values |
| D11 | Pair scores | `{pair_id, distance, similarity, algorithm_version}` | `PairScoreRequest` requires `pair_id` and `algorithm_version`, plus anyOf `score`/`similarity`/`distance` | stores a single `score` in 0..1 | shape matches, but the `anyOf` blocks generation |
| D12 | RGB payloads | `{r,g,b}` objects | `RgbPayload` = anyOf array / object / string | accepts `[r,g,b]`, `{r,g,b}` or a JSON string; stores a JSON array | the app should send `{r,g,b}`; the published `anyOf` blocks generation |
| D13 | Judgment upload | `{judgments:[{pair_id, judgment}]}` with `match` / `near_match` / `no_match` | structurally identical, but `judgment` is a free-form string | accepts any string | the allowed values are not machine-checkable |
| D14 | Judgment response | not documented | `JudgmentUploadResponse` = `{capture_id, judgment_count}` | returns it | new surface, nothing to migrate |
| D15 | Ranked results | "source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version" | `RankedResults` declares only `schema_version` and `sheet_id` | returns a rich payload: per-pair rank, `source_colors`, score aggregates, current judgment, observation and capture counts, capture timestamps, printer profile, algorithm versions | **biggest endpoint gap**: the published schema is unusable for the ranked-pair UI |
| D16 | Authentication | bearer token | `bearerAuth` (http/bearer) on the `/api/v1` scope | `ApiAuth` plug, `LPSM_API_TOKEN` | matches |
| D17 | Error bodies | not documented | `ApiErrorResponse` (`errors` object, or array of `{detail, source}`) | returns `%{errors: %{detail: "…"}}` | the generated error type is usable |
| D18 | Capture rejections | 6 documented strings | free-form strings in `quality.rejections` | not validated | not machine-checkable |
| D19 | Endpoints outside the prose contract | — | the document also covers `/api/v1/printer_profiles`, `/api/v1/printer_profiles/{printer_profile_id}/colors`, `/api/v1/printer_profiles/{printer_profile_id}/metamer_pairs`, `/api/v1/palettes`, `/api/v1/colors`, `/api/v1/openapi.json`, `/api/illuminant_measurements`, `/api/illuminant_measurements/bulk`, `/api/multi_image_mapping` | same | the iOS app does not use them; the macOS `PaletteAPIClient` does |

## Generator Blockers

Three published schemas cannot be turned into Swift types by
`swift-openapi-generator` as they stand, because OpenAPIKit drops the sibling
`properties` of a schema that also carries `anyOf`:

- `CaptureRequest` (D6)
- `PairScoreRequest` (D11)
- `RgbPayload` (D12)

The vendored copy replaces those `anyOf` branches with the concrete shape the
server accepts, so the generated types describe the payloads the app actually
sends. The upstream `anyOf` intent (accept several shapes) is preserved as a
comment in the vendored document and recorded above.

## Endpoint Gaps

The published document does not describe two payloads the app depends on:

1. **Sheet manifest** — only three of twelve fields are declared (D1-D3).
2. **Ranked results** — only two of the payload's fields are declared (D15).

Both gaps are upstream documentation gaps, not server bugs: the Phoenix app
renders the full payloads. They are tracked for
`viamin/color_matching`; until they are published, the iOS repo keeps the
documented local additions so the generated client stays usable.

## Testing

`iOS/Tests/ColorMatchingLPSAppTests/` exercises the generated client against
stubbed HTTP responses — no live `color_matching` in CI:

- `APIClientTests.swift` drives every surface the app uses (manifest, recent
  sheets, capture creation, measurement upload, judgment upload, ranked
  results) through `StubURLProtocol` and asserts the request path, headers and
  JSON body, plus the decoded response.
- `OpenAPIContractTests.swift` asserts that the vendored OpenAPI document
  exists, declares the surfaces and component schemas the app uses, and that
  the package depends on `swift-openapi-generator` and `swift-openapi-runtime`.
