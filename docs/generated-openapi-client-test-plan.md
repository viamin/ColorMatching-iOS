---
module: iOS
tags: [openapi, code-generation, api-client, testing]
problem_type: feature_migration_plan
---

# Generated OpenAPI Client — Test Plan And Contract Deltas (Issue #5)

## Phase status

This document belongs to the **test-writing (red) phase** of issue #5. The
committed tests define the required behavior of the generated OpenAPI client;
the implementation run (after `paid-tests-approved`) vendors the OpenAPI
document, adds `swift-openapi-generator` + `swift-openapi-runtime`, generates
the client, and rewires `ColorMatchingLPSAppCore`. Until then:

- `GeneratedClientTests.swift` compiles behind `#if canImport(GeneratedAPIClient)`
  and its fallback test fails with a clear message (expected red).
- `SheetAPIClientWireContractTests.swift` compiles and passes against the
  current hand-written `APIClient`; it pins wire behavior the migration must
  preserve.

Swift is not installed in the authoring container (Linux); `swift test` runs in
CI on macOS. Local execution was not possible in the test-writing run.

## Acceptance criteria → verification mapping

| ID | Criterion | Verification kind | Locator |
|----|-----------|-------------------|---------|
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` added; OpenAPI document vendored | `unit_or_service_test` (compile-guarded suite flips from red fallback to green generated-client tests) | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` |
| AC-2 | Client generated for all six surfaces (manifest, recent sheets, capture creation, measurements, judgments, ranked results) | `unit_or_service_test` — one stubbed-transport test per operation asserting method/path/operationID/payload | `GeneratedClientTests.swift` (7 tests) |
| AC-3 | Hand-written API models replaced; client-side models kept | `unit_or_service_test` wire-contract pinning (paths, auth header, decode results stay identical through the rewrite) | `SheetAPIClientWireContractTests.swift`, existing `APIClientTests.swift` |
| AC-4 | Tests exercise generated client against stubbed responses, no live server | `unit_or_service_test` using in-process `StubTransport` (`OpenAPIRuntime.ClientTransport`) and `URLProtocol` stubs only | both test files |
| AC-5 | PR description records prose-contract vs published-spec deltas and endpoint gaps | `human_or_external_evidence` — deltas pre-recorded below; implementation run copies them into the PR body and reconciles with viamin/color_matching#110 | this document, "Contract deltas" section |
| EC-1 | `swift test --disable-sandbox` green with generated types wired | CI on macOS (`swift test`); plugin-based codegen may need `--disable-sandbox` on Linux | `.github/workflows/ci.yml` |
| EC-2 | PR description captures contract deltas | same as AC-5 | this document |

## Required generated-client contract

The tests hard-require the following shape; the implementation run must vendor
an OpenAPI 3.1 document that generates exactly this surface.

- **Module/target name:** `GeneratedAPIClient` (OpenAPI document at
  `iOS/Sources/GeneratedAPIClient/openapi.yaml`, generator config alongside).
- **Package changes:** pin `swift-openapi-runtime` **1.x** (verified against
  1.13.3) and add the `swift-openapi-generator` plugin. The tests' transport
  stub implements the 1.x `ClientTransport` protocol, which is based on
  `swift-http-types`: `send(_:body:baseURL:operationID:)` takes an
  **optional** `HTTPBody?` and returns `(HTTPResponse, HTTPBody?)` with
  `HTTPResponse(status:headerFields:)`. 0.1.x runtime has a different,
  incompatible transport shape — do not pin it.
- **Test-target dependencies:** the `ColorMatchingLPSAppTests` target needs
  `GeneratedAPIClient` plus the `OpenAPIRuntime` (and optionally `HTTPTypes`)
  products so the guarded tests compile.
- **Client construction:** `GeneratedAPIClient.Client(serverURL:transport:)`.

### Operations

| operationId | Method & path | Request body | Success | Also declared |
|---|---|---|---|---|
| `getTestSheetManifest` | GET `/api/v1/test_sheets/{sheet_id}/manifest` | — | 200 `SheetManifest` | 401 |
| `listRecentTestSheets` | GET `/api/v1/test_sheets/recent` | — | 200 `RecentSheets` | 401 |
| `createCapture` | POST `/api/v1/test_sheets/{sheet_id}/captures` | `CreateCaptureRequest` | 201 `CaptureSession` | 401 |
| `uploadMeasurements` | POST `/api/v1/captures/{capture_id}/measurements` | `MeasurementUploadRequest` | 204 | 401 |
| `uploadJudgments` | POST `/api/v1/captures/{capture_id}/judgments` | `JudgmentUploadRequest` | 204 | 401 |
| `getRankedResults` | GET `/api/v1/test_sheets/{sheet_id}/ranked_results` | — | 200 `RankedResults` | 401 |

Path parameters keep template names verbatim: `sheet_id`, `capture_id`.

### Schema components (PascalCase component keys → `Components.Schemas.*`)

- `SheetManifest`: `schema_version`, `sheet_version`, `sheet_id`,
  `manifest_url` (string, uri format), `created_at` (date-time), `page`,
  `registration_markers[]`, `printer_profile`, `capture_profile`,
  `patches[]`, `pairs[]`.
- `Patch`: `id`, `role` (`PatchRole` enum: `pair_color`, `reference`),
  `pair_id`?, `pair_side`? (`PairSide`: `first`, `second`), `reference_role`?
  (`ReferenceRole`: `white`, `gray`, `black`, `blank_paper`), `source_color`?,
  `safe_inset_mm`, `rect`.
- `PatchPair`: `id`, `first_patch_id`, `second_patch_id`, `source_colors[]`,
  `grid_row` (integer), `grid_col` (integer).
- `RecentSheets` → `sheets[]` of `RecentSheet`: `sheet_id`, `manifest_url`,
  `title` (nullable string).
- `CreateCaptureRequest`: `metadata` (`CaptureMetadata`), `quality`
  (`CaptureQuality`).
- `CaptureMetadata`: `device_model`, `lens`, `exposure_duration_seconds`?,
  `iso`? (number), `focus_lens_position`? (number), `white_balance_gains`?
  (`WhiteBalanceGains`: `red`, `green`, `blue`), `image_width`? (integer),
  `image_height`? (integer), `app_version`, `timestamp` (date-time).
- `CaptureQuality`: `detected_marker_count` (integer), `blur_score`,
  `rejections[]` (`CaptureRejection` enum: `missingRegistrationMarks`,
  `incompleteSheetCoverage`, `clipping`, `excessiveBlur`, `glare`,
  `poorReferencePatch`).
- `CaptureSession`: `capture_id`.
- `MeasurementUploadRequest`: `scoring_algorithm_version`,
  `measurements[]` (`PatchMeasurementUpload`: `patch_id`, `linear_rgb_median`,
  `normalized_linear_rgb_median`?, `stats`), `pair_scores[]`
  (`PairScoreUpload`: `pair_id`, `distance`, `similarity`,
  `algorithm_version`). `stats` (`MeasurementStatsUpload`): `sample_count`
  (integer), `clipping_fraction`, `mean`, `standard_deviation` (`RgbMedian`:
  `r`, `g`, `b`).
- `JudgmentUploadRequest`: `judgments[]` of `pair_id` + `judgment`
  (`Judgment` enum: `match`, `near_match`, `no_match`).
- `RankedResults`: `sheet_id`, `scoring_algorithm_version`, `results[]`
  (`RankedPairResult`: `pair_id`, `source_colors[]`, `distance`, `similarity`,
  `judgment` (nullable `Judgment`), `capture_id`).

### Naming conventions

- snake_case JSON property names are preserved verbatim as Swift property
  names (`safe_inset_mm`, `capture_id`).
- Enum raw values are the contract strings; tests construct them via
  `init(rawValue:)` so Swift case spelling is not load-bearing.
- Version tokens (`schema_version`, `sheet_version`,
  `scoring_algorithm_version`, `algorithm_version`) stay plain strings — they
  are extensible server-side and must not break decoding on bump.
- `format: uri` stays `String` (no URL type is generated).
- Auth stays at the wrapper/transport level (inject `Authorization: Bearer`
  header when a token is set; omit when nil). Generated-client tests
  deliberately do not assert auth; `SheetAPIClientWireContractTests` and
  `APIClientTests` assert the header reaches the wire through the wrapper.

## Migration invariants (must hold after replacing the hand-written layer)

1. Paths/methods/bodies pinned by `SheetAPIClientWireContractTests` and the
   existing `APIClientTests` remain byte-identical: `/api/v1/test_sheets/{id}/manifest`,
   `/api/v1/test_sheets/recent`, `/api/v1/test_sheets/{id}/captures` (POST),
   `/api/v1/captures/{id}/measurements` (POST), `/api/v1/captures/{id}/judgments` (POST).
2. `fetchManifest(from:)` still accepts an arbitrary absolute manifest URL
   (any origin), not just a configured base URL.
3. Absent/empty token ⇒ no `Authorization` header (unauthenticated dev mode
   per the prose contract).
4. `MeasurementCore` models (`SheetManifest`, `PatchMeasurement`,
   `PairScore`, `CaptureQuality`, …) are client-side analysis models and stay
   hand-written; the wrapper maps generated manifest types into
   `MeasurementCore.SheetManifest` for `SheetAnalyzer`.
5. Purely hand-written *API* models in `ColorMatchingLPSAppCore`
   (`CaptureMetadata`, `WhiteBalanceGains`, `CaptureSessionResponse`,
   `RecentSheet`, `PairJudgment`, request wrappers) are deleted, replaced by
   generated types.

## Contract deltas: prose contract vs machine-readable spec

Recorded for the PR description (AC-5). The prose contract at
`docs/color-matching-api-contract.md` leaves the following unspecified; a
generated client forces a decision. Reconcile each against the published spec
from viamin/color_matching#110 when it lands.

1. **Ranked results response schema is entirely undefined in prose.** The
   contract only says "source colors, scores, labels, capture provenance,
   printer profile, and scoring algorithm version". The vendored spec must
   define it; this plan proposes `RankedResults`/`RankedPairResult` above.
   **Endpoint gap.**
2. **Status codes are unspecified in prose.** The app currently accepts any
   2xx. The spec pins: 200 (fetches), 201 (capture creation), 204 (uploads),
   401 (all operations). If the real server returns e.g. 200 for capture
   creation, the generated `.created` case won't match — regeneration diff
   will surface it.
3. **Nullability is informal in prose.** `title` "may be null" (prose
   sentence), `reference_role: null`, `pair_id`/`pair_side` absent for
   reference patches, optional capture metadata fields — all must become
   explicit `nullable`/`required` declarations.
4. **Type pinning:** `iso`, `focus_lens_position`, `white_balance_gains.*`
   → `number` (Double); `sample_count`, `detected_marker_count`,
   `grid_row`, `grid_col`, `image_width`, `image_height` → `integer`;
   timestamps → `date-time`.
5. **Closed sets become enums:** judgment values, capture rejection strings,
   patch roles, reference roles, pair sides. New server values become decode
   errors/compile errors instead of silent pass-through — the drift-detection
   the issue wants. Marker `role`/`shape` stay open strings (servers may add
   corner variants).
6. **`printer_profile.settings` is a free-form object** (`{}` in the example)
   — untyped `additionalProperties`. Kept opaque; app ignores it.
7. **No error payload shapes documented.** 401 is declared with an
   undocumented body; unexpected statuses land in `.undocumented`.
8. **Auth scheme undeclared in prose** beyond a header example; spec must
   declare bearer auth, and the client must tolerate tokenless dev mode.

## Endpoint gaps discovered

- The app uses five of the six contract endpoints today; `ranked_results` has
  no app integration yet. The generated client must still cover it (per the
  issue); wiring UI to it is future work (non-goal here).
- No contract endpoint exists for auth token exchange (out of scope, MVP
  shared bearer token).

## Notes for the implementation run

- Run `swift test --disable-sandbox` (plugin-based codegen) locally on macOS;
  CI's plain `swift test` should also succeed since it runs outside the
  sandbox.
- The fallback `GeneratedClientMigrationTests.testGeneratedClientModuleIsAvailable`
  (and the whole `#else` branch) disappears automatically once the module
  exists.
- After rewiring, `SheetAPIClientWireContractTests` and `APIClientTests` must
  stay green without editing their path/header/body assertions; response-type
  assertions may need updating only where hand-written API models are deleted.
