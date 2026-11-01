# Generated OpenAPI Client Migration (issue #5)

Status: **tests-first phase**. This document pins the contract that issue #5's
implementation must satisfy, records the deltas found between
`docs/color-matching-api-contract.md` (the prose contract) and the OpenAPI spec
published by `viamin/color_matching` (issue viamin/color_matching#110, merged),
and maps each acceptance criterion to its verification.

The tests added in this phase are red on purpose: they fail until the
implementation described below lands. They live in
`iOS/Tests/ColorMatchingLPSAppTests/`:

- `OpenAPIGeneratedClientTests.swift` — compiles only once the generated client
  target exists (`#if canImport(OpenAPIGenerated)`); until then a placeholder
  test fails with a pointer to this document.
- `OpenAPISpecCoverageTests.swift` — runs today and fails because no spec is
  vendored yet; permanently guards the vendored document afterwards.

## Pinned implementation contract

These choices are load-bearing: the tests reference the generated identifiers
that only appear when this contract is followed exactly.

1. **SwiftPM dependencies** (added to `iOS/Package.swift`):
   - `apple/swift-openapi-generator` (provides the `OpenAPIGenerator` build
     plugin; pinned to a 1.x release).
   - `apple/swift-openapi-runtime` (provides the `OpenAPIRuntime` product).
2. **Generated target**: a new target named `OpenAPIGenerated` containing the
   vendored document and generator config, applying the plugin:

   ```swift
   .target(
       name: "OpenAPIGenerated",
       dependencies: [
           .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
       ],
       plugins: [
           .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
       ]
   )
   ```

3. **Vendored document**: `iOS/Sources/OpenAPIGenerated/openapi.json` — a
   byte-for-byte copy of the JSON served by `GET /api/v1/openapi.json` on a
   `color_matching` server built from `viamin/color_matching@main`. The spec is
   generated at runtime by `ColorMatchingWeb.ApiSpec` from
   `ColorMatchingWeb.Router`, so the served document is the only faithful
   artifact; do not hand-edit it. Refreshing it is a regeneration diff by design.
4. **Generator config**: `iOS/Sources/OpenAPIGenerated/openapi-generator-config.yaml`:

   ```yaml
   generate:
     - types
     - client
   access: public
   namingStrategy: idiomatic
   ```

   `namingStrategy: idiomatic` (SOAR-0013) is required — the generator's default
   is `defensive`, which produces different identifiers than the ones the tests
   call.
5. **Test wiring**: `iOS/Tests/ColorMatchingLPSAppTests` gains a target
   dependency on `OpenAPIGenerated` so the `canImport` gates in
   `OpenAPIGeneratedClientTests.swift` turn on. The new test files must also be
   added to the Xcode project's `ColorMatchingLPSAppTests` group (the
   `.xcodeproj` lists sources explicitly; `swift test` picks them up either way).
6. **Exit criterion command**: `swift test --disable-sandbox` run in `iOS/`
   (the `--disable-sandbox` flag is how the generator plugin is allowed to run
   during the build). CI's `swift test` step needs the same flag once the
   plugin-based target exists.

### operationId → generated Swift identifier map

OpenApiSpex derives operationIds as `"<ControllerModule>.<action>"`, and the
generator's idiomatic strategy maps them as follows. The generated client
methods are the exact identifiers used by `OpenAPIGeneratedClientTests.swift`:

| Endpoint | operationId (published) | Client method |
| --- | --- | --- |
| `GET /api/v1/test_sheets/{sheet_id}/manifest` | `ColorMatchingWeb.TestSheetController.manifest` | `colorMatchingWeb_TestSheetController_manifest` |
| `GET /api/v1/test_sheets/recent` | `ColorMatchingWeb.TestSheetController.recent` | `colorMatchingWeb_TestSheetController_recent` |
| `GET /api/v1/test_sheets/{sheet_id}/ranked_results` | `ColorMatchingWeb.TestSheetController.ranked_results` | `colorMatchingWeb_TestSheetController_rankedResults` |
| `POST /api/v1/test_sheets/{sheet_id}/captures` | `ColorMatchingWeb.CaptureController.create` | `colorMatchingWeb_CaptureController_create` |
| `POST /api/v1/captures/{capture_id}/measurements` | `ColorMatchingWeb.CaptureController.upload_measurements` | `colorMatchingWeb_CaptureController_uploadMeasurements` |
| `POST /api/v1/captures/{capture_id}/judgments` | `ColorMatchingWeb.CaptureController.upload_judgments` | `colorMatchingWeb_CaptureController_uploadJudgments` |

Enum cases produced from the spec's version strings:

- `lps-sheet-manifest/v1` → `lpsSheetManifestV1`
- `lps-distance-v1` → `lpsDistanceV1`
- `lps-ranked-results/v1` → `lpsRankedResultsV1`

### Client-side wiring notes for the implementation

- The generated `Client` sends no credentials by default; the shared bearer
  token must be applied with a `ClientMiddleware` that sets
  `request.headerFields[.authorization]` (the scheme is declared but not
  enforced client-side).
- Keep purely client-side models (e.g. `MeasurementCore`'s geometry/scoring
  types) as-is; only the API wire models are replaced by generated types.
- Adapters between generated types and `MeasurementCore` models are expected
  (e.g. generated `TestSheetManifest` only pins three fields — see deltas —
  while the app's sheet-analysis pipeline consumes the richer server payload
  that the prose contract describes).

## Contract deltas: prose contract vs published spec

Sources: `docs/color-matching-api-contract.md` (this repo) vs
`viamin/color_matching@main` — `lib/color_matching_web/api_schemas.ex`,
`lib/color_matching_web/controllers/test_sheet_controller.ex`,
`lib/color_matching_web/controllers/capture_controller.ex`,
`lib/color_matching_web/router.ex`.

### Manifest (`GET /api/v1/test_sheets/{sheet_id}/manifest`)

- The published `TestSheetManifest` schema pins only `schema_version`
  (enum `lps-sheet-manifest/v1`), `sheet_id`, and
  `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`).
- The prose contract additionally documents `sheet_version`, `manifest_url`,
  `created_at`, `page`, `registration_markers`, `printer_profile`, `patches`,
  and `pairs`. These are **absent from the published schema**; the server may
  still send them (extra fields are ignored by the generated decoder), but the
  spec does not yet make the geometry payload a compatibility promise.
- Gap: the iOS capture pipeline depends on `page`, `registration_markers`,
  `patches`, and `pairs`; until the spec pins them, drift there stays invisible
  to client regeneration. Worth an upstream follow-up.

### Ranked results (`GET /api/v1/test_sheets/{sheet_id}/ranked_results`)

- New versioned response schema `RankedResults` pinning
  `schema_version` enum `lps-ranked-results/v1` and `sheet_id`. The prose
  contract described the payload only in general terms (no schema, no version
  string) — this version string did not exist in the prose contract.
- Like the manifest, only the envelope is pinned; the ranked pairs themselves
  are not described in the schema yet.

### Capture creation (`POST /api/v1/test_sheets/{sheet_id}/captures`)

- The published `CaptureRequest` accepts **two shapes** via `anyOf`: the
  nested `metadata` + `quality` form the app sends today (still valid), and a
  flat form with the capture fields at the top level
  (`device_model`, `lens`, `exposure_duration`, `iso`, `focus_lens_position`,
  `white_balance_gains`, `image_width`, `image_height`, `app_version`,
  `timestamp`, `detected_marker_count`, `blur_score`, `rejection_reasons`).
- Name mismatch between the two shapes: flat `exposure_duration` vs nested
  `exposure_duration_seconds`.
- The prose contract's enumerated rejection strings
  (`missingRegistrationMarks`, `clipping`, …) are not constrained in the spec
  (free-form string array).
- `CaptureMetadata.iso` is an integer in the spec; the prose contract showed a
  bare number (the app's `Float` ISO values would fail spec validation when
  fractional).
- `capture_id` in the `201` response is the stringified numeric capture id
  (Phoenix renders `Integer.to_string(capture.id)`), consistent with the prose
  shape.

### Measurement upload (`POST /api/v1/captures/{capture_id}/measurements`)

- The top-level `scoring_algorithm_version` field from the prose contract is
  **gone**; each `pair_scores` entry instead carries a required
  `algorithm_version` plus anyOf `score`/`similarity`/`distance` (the prose
  contract required both `distance` and `similarity`).
- The per-measurement `stats` block (`sample_count`, `clipping_fraction`,
  `mean`, `standard_deviation`) is **not in the published schema**.
- `linear_rgb_median`/`normalized_linear_rgb_median` are a `RgbPayload`
  accepting three wire forms: `[r, g, b]` array, `{r, g, b}` object, or a
  JSON-encoded string. `normalized_linear_rgb_median` is **required** per
  measurement item in the spec (the current hand-written model treats it as
  optional).
- The upload now returns a JSON body `MeasurementUploadResponse`
  (`capture_id`, `measurement_count`, `pair_score_count`). The prose contract
  (and the current hand-written client tests) assumed an empty/204 response.

### Judgment upload (`POST /api/v1/captures/{capture_id}/judgments`)

- Returns a JSON body `JudgmentUploadResponse` (`capture_id`,
  `judgment_count`) — no response body was specified in the prose contract.
- The allowed judgments (`match`, `near_match`, `no_match`) are not enum-
  constrained in the spec.

### Authentication

- The published spec declares an `http`/`bearer` security scheme
  (`bearerAuth`) on all six companion endpoints — matches the prose contract's
  shared bearer token. The prose note about unauthenticated local development
  is a server-side concern, not represented in the spec.

## Endpoint coverage

No gaps for the surfaces this app uses today — all six operations exist with
the exact paths from the prose contract. The published spec additionally
covers endpoints the app does not use (they generate unused client methods,
harmlessly): `printer_profiles` (+ `colors`, `metamer_pairs`), `palettes`,
`colors`, `illuminant_measurements` (+ `bulk`), `multi_image_mapping`, and the
spec endpoint itself.

## Acceptance criterion → verification map

| AC | Verification | Evidence |
| --- | --- | --- |
| `swift-openapi-generator` + `swift-openapi-runtime` added; OpenAPI document fetched/vendored | Permanent unit test: vendored document exists at the pinned path, covers all six endpoints with the published operationIds, pins the compatibility version strings, and declares bearer auth | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPISpecCoverageTests.swift` |
| Client generated for manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Permanent unit tests: generated client exercised per surface against stubbed transports, asserting method/path/operationId/content type, request wire shape, and decoded responses | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIGeneratedClientTests.swift` |
| Hand-written API models replaced with generated types; client-only models kept | Implementation-phase criterion; once the replacement lands, the existing `APIClientTests` are updated/removed in the same change and the generated-client tests above carry the regression load | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (current) |
| Swift tests against local stubbed responses (no live server) | Same tests as above; all stubbing is in-process (`RecordingStubTransport`, canned JSON) — no network or server in CI | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIGeneratedClientTests.swift` |
| PR description records contract deltas and endpoint gaps | Delta analysis and coverage/gap findings recorded in this document; carry them into the PR description verbatim | `docs/color-matching-openapi-client.md` (this file) |
| `swift test --disable-sandbox` green with generated types wired in | Implementation-phase exit criterion; blocked until the pinned contract above is implemented | CI `swift test` step in `.github/workflows/ci.yml` |
