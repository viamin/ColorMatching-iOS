# Generated OpenAPI Swift Client for the iOS Companion

Implementation plan and drift findings for replacing the hand-written API layer
(`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`) with a client generated
from the machine-readable OpenAPI spec published by `viamin/color_matching`
(viamin/color_matching#110, served at `GET /api/v1/openapi.json`).

This document is the source of truth for the test-first PR (#5): the tests in
`iOS/Tests/` encode the conventions below, and the implementation run must
follow them so the tests compile and pass.

## Target architecture

- Vendor the published document at `iOS/OpenAPI/color-matching-openapi.json`
  (fetched from `GET /api/v1/openapi.json` on the color_matching server;
  regeneration is a `curl` + PR diff, which is exactly the drift signal we want).
  Vendor as-is: do **not** rewrite operation IDs or schemas locally.
- Add package dependencies:
  - `apple/swift-openapi-generator` (build tool plugin `OpenAPIGenerator`)
  - `apple/swift-openapi-runtime`
  - `apple/swift-openapi-urlsession` (`URLSessionTransport`)
- Add target `ColorMatchingOpenAPI` (library) with
  `openapi-generator.config.yaml` (`accessModifier: public`) and the vendored
  document. The generated module name equals the target name.
- Add test target `ColorMatchingOpenAPITests` depending on
  `ColorMatchingOpenAPI` and `OpenAPIURLSession`; it contains
  `iOS/Tests/ColorMatchingOpenAPITests/OpenAPIClientTests.swift` (committed in
  the tests-first PR; it is inert until `Package.swift` declares the target).
- Keep `APIClient` as a thin facade with today's ergonomics, but back it with
  the generated `Client` and generated payload types instead of hand-written
  `Codable` models. Purely client-side models (`PatchMeasurement`,
  `ChannelStats`, local sheet-analysis types) stay as-is.
- Bearer auth flows through `URLSessionConfiguration.httpAdditionalHeaders`
  (`Authorization: Bearer <token>`), which `URLSessionTransport` inherits.

## Generated naming (why the tests use these identifiers)

The published spec derives operation IDs as `"<ControllerModule>.<action>"`
(open_api_spex `OperationBuilder.build_operation_id/3`), e.g.
`ColorMatchingWeb.TestSheetController.manifest`. swift-openapi-generator's
SOAR-0013 idiomatic sanitizer maps `.` to `_` (word separator chars `_ - space
/ +` capitalize the next word), producing:

| Operation | operationId | Generated method |
|---|---|---|
| GET /api/v1/test_sheets/recent | `ColorMatchingWeb.TestSheetController.recent` | `colorMatchingWeb_TestSheetController_recent` |
| GET /api/v1/test_sheets/{sheet_id}/manifest | `ColorMatchingWeb.TestSheetController.manifest` | `colorMatchingWeb_TestSheetController_manifest` |
| GET /api/v1/test_sheets/{sheet_id}/ranked_results | `ColorMatchingWeb.TestSheetController.ranked_results` | `colorMatchingWeb_TestSheetController_ranked_results` |
| POST /api/v1/test_sheets/{sheet_id}/captures | `ColorMatchingWeb.CaptureController.create` | `colorMatchingWeb_CaptureController_create` |
| POST /api/v1/captures/{capture_id}/measurements | `ColorMatchingWeb.CaptureController.upload_measurements` | `colorMatchingWeb_CaptureController_upload_measurements` |
| POST /api/v1/captures/{capture_id}/judgments | `ColorMatchingWeb.CaptureController.upload_judgments` | `colorMatchingWeb_CaptureController_upload_judgments` |

Other derived names used by the tests:

- Component schemas use the open_api_spex `title` strings:
  `TestSheetManifest`, `RankedResults`, `RecentSheetsResponse`,
  `CaptureMetadata`, `CaptureRequest`, `CaptureCreatedResponse`,
  `RgbPayload`, `PairScoreRequest`, `MeasurementUploadRequest`,
  `MeasurementUploadResponse`, `JudgmentUploadRequest`,
  `JudgmentUploadResponse`, `ApiErrorResponse`.
- snake_case properties become lowerCamelCase (`sheet_id` → `sheetId`,
  `manifest_url` → `manifestUrl`, `capture_id` → `captureId`).
- Inline schemas nest with a `Payload` suffix:
  `TestSheetManifest.CaptureProfilePayload`,
  `CaptureRequest.QualityPayload`,
  `RecentSheetsResponse.SheetsPayloadPayload` (array items double the suffix,
  as in upstream generator reference output `FeedsPayloadPayload`).
- String-enum properties generate nested `RawRepresentable` enums named
  `<Property>Payload` with case `swiftMemberName(rawValue)`:
  `SchemaVersionPayload.lpsSheetManifestV1 == "lps-sheet-manifest/v1"`,
  `.lpsDistanceV1 == "lps-distance-v1"`,
  `.lpsRankedResultsV1 == "lps-ranked-results/v1"`.
- `RgbPayload` is an anyOf (array | r/g/b object | string) → struct with
  optional `value1: [Double]?`, `value2: RgbPayload.Value2Payload?`,
  `value3: String?`.
- Response cases: `.ok`, `.created`, `.unauthorized`, `.notFound`,
  `.unprocessableContent`, plus `.undocumented(statusCode:_:)`.

## Contract deltas: prose contract vs published spec

Comparing `docs/color-matching-api-contract.md` against the published spec
sources (`lib/color_matching_web/api_schemas.ex`, `api_spec.ex`,
`test_sheet_controller.ex`, `capture_controller.ex` on color_matching `main`
as of 2026-11-02):

1. **Manifest schema is mostly undocumented.** The published
   `TestSheetManifest` only declares `schema_version`, `sheet_id`, and
   `capture_profile.scoring_algorithm_version`. The prose contract (and the
   app's `SheetManifest`) also use `sheet_version`, `manifest_url`,
   `created_at`, `page`, `registration_markers`, `printer_profile`,
   `patches`, `pairs` — none are in the spec. The generated client therefore
   **cannot** replace the hand-written manifest/sheet models yet; the app
   keeps decoding those fields locally until upstream documents them
   (follow-up to file against viamin/color_matching). Tests only assert the
   documented surface.
2. **Measurement upload response changed shape.** Prose contract implies an
   empty 204 (the app's tests stub 204). The spec declares **200 OK** with
   `MeasurementUploadResponse` (`capture_id`, `measurement_count`,
   `pair_score_count`). Same for judgments: 200 with `capture_id`,
   `judgment_count`. The hand-written client accepts any 2xx, so this was
   invisible until now.
3. **`stats` are not uploadable.** The prose contract's measurement payload
   includes `stats` (`sample_count`, `clipping_fraction`, `mean`,
   `standard_deviation`); the published `MeasurementUploadRequest` has no
   `stats` object. The generated client drops them. Follow-up: ask upstream
   to document `stats`, or the app loses per-patch statistics.
4. **`scoring_algorithm_version` is gone.** The prose contract sends a
   top-level `scoring_algorithm_version`; the published request schema omits
   it. Per-pair `algorithm_version` in `PairScoreRequest` remains (required,
   plus anyOf `score`/`similarity`/`distance`).
5. **`normalized_linear_rgb_median` is required** in the published schema;
   the app treats it as optional (`PatchMeasurement.normalizedLinearRGBMedian
   is RGB?`). The app must always compute and send it.
6. **Capture create accepts a second, flat shape.** The spec's `CaptureRequest`
   is anyOf: the documented nested `{metadata, quality}` object *or* a flat
   object whose keys differ from the prose contract: `exposure_duration`
   (not `exposure_duration_seconds`) and `rejection_reasons` (not
   `quality.rejections`). The app keeps sending the nested shape.
7. **`white_balance_gains` is opaque.** Published as a bare object; the
   generated type is an empty struct and cannot express the app's
   `red`/`green`/`blue` gains. Follow-up for upstream; until then the facade
   sends gains via the opaque object or omits them (open question for the
   implementation run; tests in this PR do not enshrine either choice).
8. **Ranked results now have a schema string.** `schema_version` enum
   `"lps-ranked-results/v1"` plus `sheet_id`; the prose contract described the
   endpoint but never specified a response schema. Detail fields (scores,
   labels, provenance, printer profile) are not yet documented — same gap
   class as the manifest.
9. **RGB channels are loose on the wire.** Measurement medians use
   `RgbPayload` anyOf; the app's `{r,g,b}` object remains valid. (The
   palette/metamer endpoints' separate `Rgb` schema uses 0–255 integers, but
   the app doesn't consume those endpoints.)

## Drift detection story

- `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIDocumentContractTests.swift`
  guards the vendored document: the six surfaces the app depends on must exist
  with the exact operation IDs and response schemas above. A server-side
  rename/removal shows up as a regeneration diff *and* a test failure.
- `iOS/Tests/ColorMatchingOpenAPITests/OpenAPIClientTests.swift` exercises the
  generated client against stubbed `URLProtocol` responses (no live server in
  CI), pinning request formation (method, path, auth, content type) and
  response decoding, including the 200-not-204 upload responses and the
  `.undocumented(statusCode:)` fallback.
