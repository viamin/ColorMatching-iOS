# Published `color_matching` OpenAPI spec vs the prose contract

This document records what changed between `docs/color-matching-api-contract.md`
(the hand-written prose contract) and the machine-readable OpenAPI 3 spec that
`viamin/color_matching` now publishes at `GET /api/v1/openapi.json`, plus the
vendoring/codegen decisions the iOS app makes on top of it. It is the source
material for the PR description of the generated-client migration.

## Provenance

The spec shipped upstream in viamin/color_matching#113 (merged 2026-10-30,
merge commit `094bd6d`):

- Spec definition: `lib/color_matching_web/api_spec.ex` (spec shell: OpenAPI
  3.0.x, bearer auth scheme) + `lib/color_matching_web/api_schemas.ex` (all
  component schemas).
- Operations: declared per-controller with `OpenApiSpex.ControllerSpecs`
  (`TestSheetController`, `CaptureController`, `ColorPaletteController`,
  `IlluminantMeasurementController`, `MultiImageMappingController`) and
  assembled from `ColorMatchingWeb.Router.__routes__/0`.
- Served document: `GET /api/v1/openapi.json` (no auth required for the spec
  endpoint itself).

OpenApiSpex derives `operationId` as `"<controller module>.<action>"`, e.g.
`ColorMatchingWeb.TestSheetController.manifest`. Under
swift-openapi-generator's SOAR-0013 idiomatic naming rules a `.` becomes `_`
inside the word and `_`/`-`/`/` split words, which yields these exact symbols
in the generated `ColorMatchingAPI` module:

| Operation | operationId | Client method / `Operations` namespace |
|---|---|---|
| GET `/api/v1/test_sheets/{sheet_id}/manifest` | `ColorMatchingWeb.TestSheetController.manifest` | `colorMatchingWeb_TestSheetController_manifest` |
| GET `/api/v1/test_sheets/recent` | `ColorMatchingWeb.TestSheetController.recent` | `colorMatchingWeb_TestSheetController_recent` |
| GET `/api/v1/test_sheets/{sheet_id}/ranked_results` | `ColorMatchingWeb.TestSheetController.ranked_results` | `colorMatchingWeb_TestSheetController_rankedResults` |
| POST `/api/v1/test_sheets/{sheet_id}/captures` | `ColorMatchingWeb.CaptureController.create` | `colorMatchingWeb_CaptureController_create` |
| POST `/api/v1/captures/{capture_id}/measurements` | `ColorMatchingWeb.CaptureController.upload_measurements` | `colorMatchingWeb_CaptureController_uploadMeasurements` |
| POST `/api/v1/captures/{capture_id}/judgments` | `ColorMatchingWeb.CaptureController.upload_judgments` | `colorMatchingWeb_CaptureController_uploadJudgments` |

## Contract deltas (prose contract vs published spec vs actual server)

Verified against the Phoenix source at the merge commit above
(`TestSheetJSON`, `CaptureController`, `CaptureUpload`, `CaptureJudgmentUpload`,
`Persistence`).

1. **Manifest response is barely typed in the spec.** `TestSheetManifest`
   declares only `schema_version` (enum `lps-sheet-manifest/v1`), `sheet_id`,
   and `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`).
   The actual response still carries `sheet_version`, `manifest_url`,
   `created_at`, `page`, `registration_markers`, `printer_profile`,
   `capture_profile` (full), `patches`, `pairs` — exactly what the app's
   `SheetAnalyzer` needs. Because the generated manifest type is too thin to
   drive sheet analysis, the app **keeps its purely client-side
   `MeasurementCore.SheetManifest` decode** of the manifest body. Upstream gap:
   the spec should type the geometry fields.
2. **Patch IDs are `"<pair_id>#<side>"`**, not the `"patch_1"` style in the
   prose example (`TestSheetJSON.patch_id/1`). Measurement uploads must echo
   the IDs exactly as the manifest provided them.
3. **Manifest `printer_profile` shape differs from prose**: the server sends
   `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`,
   `print_settings`, `driver_name`, `driver_version`, `calibration_date`,
   `calibration_version`, `notes` — not the prose `{id, name, paper, ink,
   settings}`.
4. **Capture creation accepts two shapes** (`CaptureRequest`): the prose
   `{metadata, quality}` nesting *and* a flattened form; aliases
   `exposure_duration` ↔ `exposure_duration_seconds` and `rejection_reasons`
   ↔ `rejections` are normalized server-side. The app keeps sending the
   nested `{metadata, quality}` form.
5. **`white_balance_gains` is an opaque `type: object`** in the spec, so the
   generated Swift type cannot carry the red/green/blue gains. The server
   stores whatever JSON it receives; the app currently loses the gains values
   on the wire until the spec types them. Recorded as an upstream gap.
6. **`iso` is `integer`** in the spec (the old hand-written client used
   `Float`).
7. **Measurement upload**: the spec's `MeasurementUploadRequest` does **not**
   type the prose contract's top-level `scoring_algorithm_version` or the
   per-measurement `stats` block (`sample_count`, `clipping_fraction`, `mean`,
   `standard_deviation`). The server still *reads* them when present, but the
   generated client can only send the three typed keys (`patch_id`,
   `linear_rgb_median`, `normalized_linear_rgb_median`) — the loss is the
   visible drift this migration is supposed to surface. Upstream gap: type the
   stats block.
8. **`normalized_linear_rgb_median` is required** per measurement item in the
   spec (the old client treated it as optional).
9. **RGB values are polymorphic (`RgbPayload`)**: `anyOf` number-array |
   `{r,g,b}` object | JSON string. The server normalizes all three. The
   generated type is a struct with optional `value1`/`value2`/`value3`; the
   app sends the `{r,g,b}` object variant.
10. **Pair scores**: `PairScoreRequest` requires `pair_id` +
    `algorithm_version` plus (per the served `anyOf`) one of `score` /
    `similarity` / `distance`. The server clamps to `[0,1]` and stores
    `distance` as `1 - distance`. The old client sent *both* `distance` and
    `similarity`; the typed client sends exactly one — the app picks
    `similarity` (stored verbatim, no transform).
11. **Measurement and judgment uploads return `200` with a JSON body**
    (`MeasurementUploadResponse` / `JudgmentUploadResponse` with counts), not
    the empty `204` the old client tolerated. The generated client would
    reject an undocumented `204` as undecodable — drift made visible.
12. **`capture_id` is a stringified integer** in every response, while the
    capture path parameter must still cast to an integer server-side.
13. **Ranked results** are spec'd minimally (`schema_version` enum
    `lps-ranked-results/v1`, `sheet_id`) but the actual payload is rich
    (`printer_profile`, `capture_count`, latest/earliest capture timestamps,
    per-pair rank/score aggregates/source colors/judgments). Only the typed
    two fields are decoded by the generated client today.
14. **Timestamps may include fractional seconds** (Phoenix
    `DateTime.to_iso8601/1` only truncates when microseconds are zero), which
    the old hand-rolled `.iso8601` decoder would reject; the OpenAPI runtime's
    date transcoding handles it.
15. **Endpoints in the spec the prose contract never mentioned**:
    `GET /api/v1/printer_profiles`, `GET /api/v1/printer_profiles/{id}/colors`,
    `GET /api/v1/printer_profiles/{id}/metamer_pairs`, `GET /api/v1/palettes`,
    `GET /api/v1/colors`, `POST /api/illuminant_measurements`,
    `POST /api/illuminant_measurements/bulk`,
    `POST /api/multi_image_mapping` (PNG response). The iOS app consumes none
    of these today; they are generated but unused.
16. **Auth** is a global `bearerAuth` HTTP scheme on every API operation. The
    generated Swift client ignores security schemes; the app adds the
    `Authorization: Bearer` header via middleware/transport configuration.

## Codegen normalization (why the vendored document is not byte-identical)

Two served schemas combine sibling `properties` with a top-level `anyOf` of
constraint-only sub-schemas:

- `CaptureRequest`: `anyOf: [{required: [...flat fields]}, {required: [metadata]}]`
- `PairScoreRequest`: `anyOf: [{required: [score]}, {required: [similarity]}, {required: [distance]}]`

The Swift generator's parser (OpenAPIKit) treats composition keywords with
precedence: a schema containing `anyOf` is parsed *as* that composition and the
sibling `type: object` + `properties` are dropped, leaving fragment sub-schemas
that have no representable Swift shape. Those `anyOf` blocks are request
*validation* constraints only — they do not change the wire format, and they
remain enforced server-side by `OpenApiSpex.Plug.CastAndValidate` against the
served spec.

**Rule:** the vendored document must be a semantic copy of the served spec with
exactly two deletions — `components.schemas.CaptureRequest.anyOf` and
`components.schemas.PairScoreRequest.anyOf`. Nothing else may be edited,
renamed, added, or reordered semantically. Any future upstream change (new
fields, removed enum values, new paths) must still flow through as a
regeneration diff.

### Refresh workflow

```bash
# 1. Fetch the served document from any environment running color_matching
curl -s "$BASE_URL/api/v1/openapi.json" -o /tmp/served.json

# 2. Normalize for codegen (the only permitted edits)
jq 'del(.components.schemas.CaptureRequest.anyOf, .components.schemas.PairScoreRequest.anyOf)' \
  /tmp/served.json > iOS/Sources/ColorMatchingAPI/openapi.json

# 3. Review the diff — this is the drift surface
git diff iOS/Sources/ColorMatchingAPI/openapi.json

# 4. Regenerate + build (the build plugin re-runs the generator)
swift build --package-path iOS
```

## Package layout contract

- New SPM package dependencies: `apple/swift-openapi-generator` (build plugin
  `OpenAPIGeneratorPlugin`), `apple/swift-openapi-runtime` (`OpenAPIRuntime`),
  and `apple/swift-openapi-urlsession` (`URLSessionTransport`) for the app
  target.
- New target `ColorMatchingAPI` holding `openapi.json` +
  `openapi-generator.config.yaml` (`generate: [client]`, `access: public`);
  the generated `Client`, `APIProtocol`, `Components`, and `Operations` types
  live there.
- `ColorMatchingLPSAppCore` depends on `ColorMatchingAPI` and keeps its public
  `APIClient` surface (callers in `ContentView` are unchanged in behavior):

| Method | Before (hand-written) | After (generated types) |
|---|---|---|
| `fetchManifest(from:)` / `fetchManifest(baseURL:sheetCode:)` | `SheetManifest` | `SheetManifest` (unchanged; purely client-side model — the spec'd manifest type is too thin, see delta 1) |
| `fetchRecentSheets(baseURL:)` | `[RecentSheet]` (hand-written) | generated recent-sheets sheet payloads |
| `createCapture(sheetID:baseURL:metadata:quality:)` | hand-written `CaptureMetadata` → `CaptureSessionResponse` | generated `Components.Schemas.CaptureMetadata` → `Components.Schemas.CaptureCreatedResponse` |
| `uploadMeasurements(captureID:baseURL:measurements:scores:)` | `Void` (expected 204) | `Components.Schemas.MeasurementUploadResponse` (200 + counts) |
| `uploadJudgments(captureID:baseURL:judgments:)` | `Void` (expected 204) | `Components.Schemas.JudgmentUploadResponse` (200 + counts) |

Hand-written request/response models that are purely client-side
(`MeasurementCore` types, `CaptureQuality`, `RGB`, `ChannelStats`,
`PatchMeasurement`, `PairScore`) stay as-is. Hand-written *API* models
(`CaptureMetadata`, `WhiteBalanceGains`, `CaptureSessionResponse`,
`RecentSheet`, `PairJudgment`, and the private request wrappers) are replaced
by generated types.

## Verification plan (criterion → test)

| Criterion | Verification |
|---|---|
| Generated client exercised against local stubs, no live server | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` — stub `ClientTransport` per operation |
| Manifest + recent sheets surfaces | `GeneratedClientTests.testManifestOperationBuildsSpecRequestAndDecodesTypedManifest`, `...RecentSheetsOperationDecodesNullableTitle` |
| Capture session creation | `GeneratedClientTests.testCreateCaptureSendsMetadataAndQualityAndDecodesCaptureID`; wrapper: `APIClientTests.testCreateCaptureSendsGeneratedMetadataAndQualityAndReturnsCaptureID` |
| Measurement upload | `GeneratedClientTests.testUploadMeasurementsEncodesSpecTypedFieldsAndDecodesCounts`; wrapper: `APIClientTests.testUploadMeasurementsSendsSpecTypedPayloadAndReturnsCounts` (also pins the stats/scoring_algorithm_version drift) |
| Judgment upload | `GeneratedClientTests.testUploadJudgmentsEncodesWirePayloadAndDecodesCount`; wrapper: `APIClientTests.testUploadJudgmentsReturnsGeneratedCount` |
| Ranked results | `GeneratedClientTests.testRankedResultsOperationDecodesSchemaVersionAndIgnoresUntypedFields` |
| Hand-written models replaced, client-side models kept | `APIClientTests` (full-manifest decode via `MeasurementCore.SheetManifest`; generated payload types on every other surface) |
| Typed error paths | `GeneratedClientTests.testUnauthorizedResponseDecodesAsUnauthorizedOutputCase`, `APIClientTests.testUnauthorizedResponsesSurfaceAsAPIErrors` |

These tests are committed ahead of the implementation (red phase): they cannot
compile until `ColorMatchingAPI` exists and `APIClient` routes through it.
