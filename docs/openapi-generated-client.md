# Generated OpenAPI Client

This repo talks to `viamin/color_matching` over `/api/v1`. The server now
publishes that API as an OpenAPI 3 document (`GET /api/v1/openapi.json`), so
the app generates a typed client from it instead of maintaining hand-written
`Codable` models.

The point of the switch is drift detection: when the server changes shape, the
vendored document changes, the regenerated client changes, and the app stops
compiling until somebody looks at the difference. A runtime surprise is no
longer the way this app finds out that the contract moved.

## Package layout

```
iOS/Package.swift                       adds swift-openapi-generator + swift-openapi-runtime
iOS/Sources/ColorMatchingOpenAPI/
    openapi.json                        the vendored OpenAPI document
    openapi-generator-config.yaml       generator configuration
iOS/Sources/ColorMatchingLPSAppCore/    the app-facing facade over the generated client
```

The generated code is produced by the `OpenAPIGenerator` build plugin and
compiled into the `ColorMatchingOpenAPI` target, so `import ColorMatchingOpenAPI`
exposes `Components.Schemas.*` and `Operations.*`.

The generator plugin requires the document and the configuration file to sit in
the target directory under the names `openapi.json` (or `openapi.yaml`) and
`openapi-generator-config.yaml`.

## The facade stays the seam

`ColorMatchingLPSAppCore.APIClient` remains the app-facing API. Its initializer
(`init(token:session:)`) and its method signatures do not change in this
change; only the types behind them do. That keeps the SwiftUI layer in
`ColorMatchingLPSApp` free of generated-type churn.

The facade is expected to:

- build the generated `Client` with the base URL and a bearer-token
  authentication handler;
- send requests through the generated operations rather than through
  hand-written `URLRequest` plumbing;
- return the generated response types for the endpoints the published spec
  describes completely.

## Which models become generated types

| Model | Source | Why |
| --- | --- | --- |
| Capture creation request/response | generated | `CaptureRequest` / `CaptureCreatedResponse` are described by the published spec. |
| Measurement upload request/response | generated | `MeasurementUploadRequest` / `MeasurementUploadResponse` are described by the published spec. |
| Judgment upload request/response | generated | `JudgmentUploadRequest` / `JudgmentUploadResponse` are described by the published spec. |
| Recent sheet entry | generated | `RecentSheetsResponse` is described by the published spec. |
| Sheet manifest payload, patch, pair, page, registration marker | hand-written in `MeasurementCore` | The published spec describes only three manifest fields; the geometry the analyzer samples is a client-side model. See delta #1 in `docs/openapi-contract-deltas.md`. |
| `RGB`, `ChannelStats`, `PatchMeasurement`, `PairScore`, `CaptureQuality`, `SheetAnalysis` | hand-written in `MeasurementCore` | Produced by the capture pipeline, not by the server. |
| Top-level `scoring_algorithm_version` on the measurement upload | dropped | The server ignores it and persists the per-pair `algorithm_version` instead. See delta #4. |

## Local additions to the vendored document

The published document is authoritative for routes but incomplete for payloads
the app needs. The vendored document keeps the published shape and adds the
missing pieces locally. Every local addition is flagged with `x-ios-local:
true` so a regeneration diff shows exactly what this repo owns:

| Addition | Reason |
| --- | --- |
| `stats` on measurement upload items (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`) | The server reads and stores them; the published spec omits them. Delta #3. |
| `quality` on the capture creation request (`detected_marker_count`, `blur_score`, `rejections`) | The published `CaptureRequest` mixes `properties` with a top-level `anyOf`, so a generated type cannot carry the quality block next to `metadata`. Delta #7. |
| The manifest payload fields the analyzer needs (`page`, `registration_markers`, `patches`, `pairs`, `sheet_version`, `manifest_url`, `created_at`) | The published manifest schema declares only `schema_version`, `sheet_id` and `capture_profile.scoring_algorithm_version`. Delta #1. |
| The ranked-results payload fields (`printer_profile`, `capture_count`, capture timestamps, `scoring_algorithm_versions`, `results[]`) | The published `RankedResults` schema declares only `schema_version` and `sheet_id`. Delta #2. |

Rules for the vendored document:

1. It is a copy of the server's `/api/v1/openapi.json` plus the additions
   above. Refreshing it means re-fetching the server document, re-applying the
   additions, and regenerating.
2. A local addition is only acceptable when the server already accepts the
   field. Additions that ask for new server behaviour belong upstream.
3. Every addition is listed in `docs/openapi-contract-deltas.md`.

## Refreshing the document

```bash
curl -s https://<color_matching-host>/api/v1/openapi.json > iOS/Sources/ColorMatchingOpenAPI/openapi.json
```

Then re-apply the local additions, regenerate, and let the compiler point at
what moved. The upstream CI (Schemathesis and `oasdiff`) enforces that the
server keeps matching its own published document, so a silent server change is
no longer possible on their side either.

## Tests

`iOS/Tests/ColorMatchingLPSAppTests/` exercises the API layer against stubbed
server responses; no test needs a running server.

| File | Covers |
| --- | --- |
| `APIClientTests.swift` | The documented endpoints, the payloads that travel over the wire, and the data that must survive the trip. |
| `GeneratedClientWiringTests.swift` | That requests are issued by the generated client and that the API models are the generated schema types. |
| `OpenAPIDocumentTests.swift` | That the repository vendors an OpenAPI document covering the surfaces the app uses, and that the package depends on the generator and the runtime. |

The assertions are written against the JSON that travels over the wire, so they
hold whether a payload is produced by a generated type or by a hand-written
model, and they fail when a payload silently loses data.

## Follow-ups for the server repository

These are the upstream changes that would remove the local additions:

1. Describe the full sheet manifest payload in the published `TestSheetManifest`
   schema.
2. Describe the full ranked-results payload in the published `RankedResults`
   schema.
3. Describe the measurement `stats` object and the capture `quality` object.
4. Replace the `anyOf` in `CaptureRequest` with a plain object, or move
   `quality` into the `metadata` branch, so a generated client can send both.
5. Make `normalized_linear_rgb_median` optional, or require it explicitly in
   the app's upload path.
