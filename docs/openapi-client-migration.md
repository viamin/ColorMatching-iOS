# OpenAPI Generated Client Migration (#5)

Status: tests written (red phase). This document records the contract deltas
between `docs/color-matching-api-contract.md` (the prose contract) and the
published OpenAPI 3 spec from viamin/color_matching#110, the endpoint gaps
discovered, and the wiring plan the implementation must follow so the tests in
`iOS/Tests/ColorMatchingLPSAppTests/GeneratedAPIClientTests.swift` compile and
pass. The PR description for #5 should be assembled from this file.

## Source of truth

The Phoenix app serves the spec at `GET /api/v1/openapi.json` (issue #110 is
closed and merged). The spec is composed from:

- `lib/color_matching_web/api_spec.ex` — top-level document, `bearerAuth` security scheme.
- `lib/color_matching_web/api_schemas.ex` — component schemas.
- `lib/color_matching_web/controllers/{test_sheet,capture, ...}_controller.ex` — operations via `OpenApiSpex.ControllerSpecs`.

The app vendors the document verbatim (no hand edits), so any server-side drift
shows up as a regeneration diff and/or a compile error in the generated client.

## Generated-name derivation (verbatim operationIds)

`OpenApiSpex.ControllerSpecs` derives `operationId` as `"<Module>.<action>"`.
swift-openapi-generator sanitizes those into Swift method names:

| Surface | HTTP | operationId | Generated Swift method |
|---|---|---|---|
| Sheet manifest | GET `/api/v1/test_sheets/{sheet_id}/manifest` | `ColorMatchingWeb.TestSheetController.manifest` | `getColorMatchingWebTestSheetControllerManifest` |
| Recent sheets | GET `/api/v1/test_sheets/recent` | `ColorMatchingWeb.TestSheetController.recent` | `getColorMatchingWebTestSheetControllerRecent` |
| Ranked results | GET `/api/v1/test_sheets/{sheet_id}/ranked_results` | `ColorMatchingWeb.TestSheetController.ranked_results` | `getColorMatchingWebTestSheetControllerRankedResults` |
| Create capture | POST `/api/v1/test_sheets/{sheet_id}/captures` | `ColorMatchingWeb.CaptureController.create` | `postColorMatchingWebCaptureControllerCreate` |
| Upload measurements | POST `/api/v1/captures/{capture_id}/measurements` | `ColorMatchingWeb.CaptureController.upload_measurements` | `postColorMatchingWebCaptureControllerUploadMeasurements` |
| Upload judgments | POST `/api/v1/captures/{capture_id}/judgments` | `ColorMatchingWeb.CaptureController.upload_judgments` | `postColorMatchingWebCaptureControllerUploadJudgments` |

The names are long but deterministic. If upstream later adds explicit
`operation_id:` values, regeneration renames them and the compile error is the
drift alarm. Do not rename operations in the vendored copy.

Schema component names come from schema `title`s: `TestSheetManifest`,
`RankedResults`, `RecentSheetsResponse`, `CaptureMetadata`, `CaptureRequest`,
`CaptureCreatedResponse`, `RgbPayload`, `PairScoreRequest`,
`MeasurementUploadRequest`, `MeasurementUploadResponse`,
`JudgmentUploadRequest`, `JudgmentUploadResponse`, `ApiErrorResponse`.
Unnamed `anyOf` branches become `case1`/`case2`/`case3` with nested
`CaseNPayload` structs; inline object properties become nested
`<Property>Payload` structs (e.g. `CaptureRequest.QualityPayload`).

## What changed between the prose contract and the published spec

1. **Manifest is only partially typed.** The spec requires and types only
   `schema_version` (enum `lps-sheet-manifest/v1`), `sheet_id`, and
   `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`). The
   prose contract documents `sheet_version`, `manifest_url`, `created_at`,
   `page`, `registration_markers`, `printer_profile`, `patches`, `pairs` —
   all still rendered by the server but **untyped in the spec**. The generated
   client decodes them as unknown keys and ignores them.
2. **`printer_profile` shape differs.** Prose: `{id, name, paper, ink,
   settings}`. Actual renderer: `{printer_make_model, paper_type, ink_type,
   icc_profile, print_settings, driver_name, driver_version,
   calibration_date, calibration_version, notes}` — no `id`, different key
   names. (UnTyped by the spec today; matters when the app surfaces it.)
3. **Patch IDs are composite.** The renderer emits `"pair_1#first"` /
   `"pair_1#second"` rather than the prose example's `"patch_1"`.
4. **Capture creation accepts two shapes.** The spec allows the prose's nested
   `{metadata, quality}` body **or** a flattened body with top-level
   `device_model`/`lens`/... — and the flattened variant names rejections
   `rejection_reasons` while the nested variant keeps `quality.rejections`.
   The app keeps sending the nested form.
5. **`iso` is an integer** in the spec (the hand-written model used `Float`).
6. **Measurement upload lost the top-level `scoring_algorithm_version`.** The
   published `MeasurementUploadRequest` schema has only `measurements` and
   `pair_scores`; the scoring version lives per pair in
   `PairScoreRequest.algorithm_version` (required, alongside exactly one of
   `score`/`similarity`/`distance`).
7. **Measurement rows lost `stats`.** The prose contract (and current app)
   send `stats: {sample_count, clipping_fraction, mean, standard_deviation}`;
   the spec's measurement item requires only `patch_id`,
   `linear_rgb_median`, `normalized_linear_rgb_median` and does not type a
   stats block. The generated client cannot express `stats` — sending it
   requires an upstream schema addition (tracked as a gap below).
8. **`normalized_linear_rgb_median` is required** in the spec (the app treats
   it as optional).
9. **`linear_rgb_median` is polymorphic** (`RgbPayload` anyOf: number array,
   `{r,g,b}` object, or string). The app sends the object form (`.case2`).
10. **Upload responses now have bodies.** Prose/tests assumed 204 No Content.
    The spec defines `200` with `{capture_id, measurement_count,
    pair_score_count}` for measurements and `{capture_id, judgment_count}` for
    judgments. Capture creation returns `201` with `{capture_id}`.
11. **Ranked results are versioned but minimal.** `schema_version` enum
    `lps-ranked-results/v1` (a string absent from the prose contract) plus
    `sheet_id`. The renderer's full payload (rank, per-pair score stats,
    source colors, current judgment, capture provenance, printer profile,
    scoring algorithm versions) is untyped today.
12. **`capture_id` is a stringified numeric DB id** (uploads cast it back to
    integer), while `sheet_id` is the sheet's lookup code (e.g. `sheet_123`).
13. **Security.** All `/api/v1` routes (except `openapi.json` itself) declare
    `bearerAuth`; the generated client is constructed with a bearer-token
    `ClientMiddleware` (documented OpenAPIRuntime pattern).

## Endpoint gaps discovered

- **App surfaces are all covered**: manifest, recent sheets, capture creation,
  measurement upload, judgment upload, ranked results — no missing routes.
- **Spec-only endpoints the app does not use** (will appear in the generated
  client but stay unexercised): `printer_profiles`, printer profile `colors`
  and `metamer_pairs`, `palettes`, `colors`, `POST /api/illuminant_measurements`
  (+`/bulk`), `POST /api/multi_image_mapping`.
- **`GET /api/v1/openapi.json` is not described by the spec** (its controller
  disables the operation), so it does not exist in the generated client.
- **Underspecified for the app's needs** (upstream follow-ups): manifest
  geometry (`page`, `registration_markers`, `patches`, `pairs`), measurement
  `stats`, `white_balance_gains` structure (a bare object), and the ranked
  results payload. Until typed, those fields cannot round-trip through the
  generated client.

## Implementation wiring (for the follow-up implementation run)

1. `iOS/Package.swift`:
   - dependencies: `apple/swift-openapi-generator` (from 1.x),
     `apple/swift-openapi-runtime` (1.x).
   - new target `ColorMatchingOpenAPI`:
     dependencies `.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")`,
     plugins `.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")`,
     resources `openapi.json` + `openapi-generator-config.yaml`.
   - `ColorMatchingLPSAppCore`, `ColorMatchingLPSApp`, and the
     `ColorMatchingLPSAppTests` test target depend on `ColorMatchingOpenAPI`
     (tests also need products `OpenAPIRuntime` and `HTTPTypes`).
2. Vendor the spec verbatim: `curl $SERVER/api/v1/openapi.json -o
   iOS/Sources/ColorMatchingOpenAPI/openapi.json` (JSON is accepted as-is;
   no YAML conversion needed).
3. `openapi-generator-config.yaml`: `generate: [types, client]`,
   `access: public`.
4. Rewrite `ColorMatchingLPSAppCore/APIClient.swift` as a thin facade over
   `ColorMatchingOpenAPI.Client` (server URL + bearer middleware), keeping the
   app-facing methods. Delete the hand-written wire Codable types
   (`CaptureMetadata`, `WhiteBalanceGains`, `CaptureSessionResponse`,
   `RecentSheet`, `PairJudgment`, and the private request wrappers) in favor
   of `Components.Schemas.*`. Keep purely client-side models (`RGB`,
   `ChannelStats`, `PatchMeasurement`, `PairScore`, `LPSScorer`) in
   `MeasurementCore`.
5. Update `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` to the
   facade-backed behavior (upload stubs must return the new 200 bodies, not
   204).

## Acceptance criteria mapping

| Deliverable | Verification | Where |
|---|---|---|
| Generator + runtime wired; spec vendored | Compile-time: tests import `ColorMatchingOpenAPI`; wiring steps above | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedAPIClientTests.swift` (imports), this doc |
| Client generated for all app surfaces | Permanent unit tests per surface, stubbed responses | `GeneratedAPIClientTests.swift` — manifest, recent, create capture, measurements, judgments, ranked results |
| Hand-written models replaced by generated types | Tests build/read only `Components.Schemas.*` wire types | same file |
| Local stubbed responses, no live server | `StubbedResponseTransport` (OpenAPIRuntime `ClientTransport`) | `GeneratedClientTestSupport.swift` |
| Drift visible | Required-field loss and undocumented status throw; upload-body schema pinned | `testManifestMissingRequiredFieldFailsDecoding`, `testUndocumentedHTTPStatusFailsInsteadOfPassingThrough`, `testUploadMeasurementsEncodesGeneratedTypesAndDecodesCounts` |
| PR description records deltas + gaps | Human/external: this document is the PR-description source | `docs/openapi-client-migration.md` |

No `.ephemeral-tests/` entry is needed: nothing here is a one-off E2E flow,
and CI has no live server; the stubbed-transport unit tests are the permanent
coverage.
