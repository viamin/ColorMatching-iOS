# Generated OpenAPI client for the iOS companion (issue #5)

Status: **tests-only draft (red phase)**. This document pins the conventions
the tests in `iOS/Tests/ColorMatchingLPSAppTests/` rely on, records the
acceptance-criteria verification plan, and captures the contract deltas found
between `docs/color-matching-api-contract.md` and the published OpenAPI spec.
The implementation run must follow the pinned conventions so the tests compile
and pass unchanged.

## Acceptance criteria → verification plan

| ID | Criterion (from issue #5) | Verification | Where |
| --- | --- | --- | --- |
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` in the package; OpenAPI document vendored | Permanent test over the vendored artifact | `OpenAPISpecCoverageTests` (`testVendoredSpecFileExists`, `testVendoredSpecIsValidOpenAPI3`); package wiring reviewed in PR |
| AC-2 | Generated client for manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Spec coverage pins operationIds/schemas; stubbed-response tests exercise all six operations | `OpenAPISpecCoverageTests.testSpecCoversEverySurfaceTheAppUses` + `GeneratedClientStubbedResponseTests` (all tests) |
| AC-3 | Hand-written API models replaced by generated types; client-side models kept | Compile-time (generated types wired into `APIClient`); PR diff review; existing app behavior tests stay green | `APIClientTests`, `MeasurementCoreTests` (must stay green after wiring) |
| AC-4 | Swift tests exercising the generated client against local stubbed responses | Permanent unit tests with an in-memory `ClientTransport` stub (no live server, no URLSession mock infrastructure) | `GeneratedClientStubbedResponseTests` |
| AC-5 | PR description records prose-contract vs published-spec deltas and endpoint gaps | This document (source for the PR description); reviewed by humans | `docs/openapi-generated-client.md` §Contract deltas |

Exit criterion `swift test --disable-sandbox` green is satisfied once the
implementation run lands; the red tests below are the red-phase evidence.

## Pinned conventions (implementation contract)

1. **Vendored document**: `iOS/OpenAPI/color-matching-openapi.json` — a JSON
   copy of `GET /api/v1/openapi.json` from viamin/color_matching (published by
   issue #110, shipped in PR #113, merged 2026-10-30), with only the
   normalizations in the next section applied. Re-vendoring must be
   reproducible (script or documented steps) so regeneration diffs stay
   meaningful.
2. **Packages**: `apple/swift-openapi-generator` (build plugin, 1.x),
   `apple/swift-openapi-runtime` (1.x), `apple/swift-openapi-urlsession` (1.x,
   only if the app transport uses `URLSessionTransport`). The tests use only
   `OpenAPIRuntime` interfaces (`ClientTransport`, `ClientMiddleware`,
   `HTTPBody`) plus `public import HTTPTypes` types re-exported by the
   runtime.
3. **Generated target**: name it `ColorMatchingOpenAPI`
   (`Sources/ColorMatchingOpenAPI/` with `openapi-generator-config.yaml`:
   `generate: [client]` plus access modifier `public`). The stubbed-response
   tests are gated on `#if canImport(ColorMatchingOpenAPI)` and activate as
   soon as the target exists.
4. **Package wiring**: add `ColorMatchingOpenAPI` as a dependency of
   `ColorMatchingLPSAppCore` (the app's `APIClient` adopts the generated
   `Client`) **and of the `ColorMatchingLPSAppTests` test target** so the
   gated tests link. Also add the new test files to
   `iOS/ColorMatchingLPS.xcodeproj` (explicit PBXBuildFile references,
   objectVersion 60) so `xcodebuild test` in CI picks them up; `swift test`
   picks them up automatically.
5. **OperationIds** (vendoring normalization; required — the generated method
   names and the tests' `operationID` assertions depend on them):

   | Operation | Pinned operationId |
   | --- | --- |
   | `GET /api/v1/test_sheets/{sheet_id}/manifest` | `fetchSheetManifest` |
   | `GET /api/v1/test_sheets/recent` | `listRecentSheets` |
   | `GET /api/v1/test_sheets/{sheet_id}/ranked_results` | `fetchRankedResults` |
   | `POST /api/v1/test_sheets/{sheet_id}/captures` | `createCapture` |
   | `POST /api/v1/captures/{capture_id}/measurements` | `uploadMeasurements` |
   | `POST /api/v1/captures/{capture_id}/judgments` | `uploadJudgments` |

6. **Schema declarations the tests assert against** (all snake_case JSON
   properties below are declared, in the listed declaration order, with the
   listed `required` lists — the generated memberwise initializers are called
   with these argument orders in the tests):
   - `TestSheetManifest`: `schema_version` (string enum
     `["lps-sheet-manifest/v1"]`), `sheet_id`, `sheet_version`,
     `manifest_url`, `created_at` (`date-time`), `page` (`units`, `width`,
     `height`), `registration_markers[]` (`role`, `shape`, `rect`),
     `printer_profile` (`printer_make_model`, `paper_type`, `ink_type`
     required; `icc_profile`, `print_settings`, `driver_name`,
     `driver_version`, `calibration_date`, `calibration_version`, `notes`
     nullable/optional), `capture_profile` (`expected_illuminant`,
     `preferred_camera`, `scoring_algorithm_version` enum
     `["lps-distance-v1"]`), `patches[]` (`id`, `role`, `pair_id`,
     `pair_side`, `reference_role` nullable, `source_color`, `safe_inset_mm`,
     `rect` {`x`,`y`,`width`,`height`}), `pairs[]` (`id`, `first_patch_id`,
     `second_patch_id`, `source_colors`, `grid_row`, `grid_col`). All top-level
     properties required.
   - `RecentSheetsResponse`: `sheets[]` items with `sheet_id`,
     `manifest_url`, `title` (required but nullable — the server always sends
     `null` today).
   - `CaptureMetadata`: required `device_model`, `lens`, `app_version`,
     `timestamp`; optional `exposure_duration_seconds`, `iso` (integer),
     `focus_lens_position`, `white_balance_gains` (`{red, green, blue}`
     numbers), `image_width`, `image_height`. Declaration order as listed.
   - `CaptureRequest`: plain object `{metadata: CaptureMetadata, quality:
     {detected_marker_count, blur_score, rejections[]}}`, both required.
   - `CaptureCreatedResponse`: `{capture_id}` required; success status 201.
   - `MeasurementUploadRequest`: `scoring_algorithm_version` (plain string),
     `measurements[]` (`patch_id`, `linear_rgb_median: RgbPayload`,
     `normalized_linear_rgb_median: RgbPayload`, `stats` {`sample_count`,
     `clipping_fraction`, `mean: RgbPayload`, `standard_deviation:
     RgbPayload`}), `pair_scores[]` (`pair_id`, `algorithm_version` required;
     `score`, `similarity`, `distance` optional numbers). Success 200 with
     `MeasurementUploadResponse` `{capture_id, measurement_count,
     pair_score_count}`.
   - `RgbPayload`: kept as published (`anyOf` array | `{r,g,b}` object |
     string); the app sends the object branch (generated `value2`).
   - `JudgmentUploadRequest`: `{judgments[]: {pair_id, judgment}}`; success
     200 with `JudgmentUploadResponse` `{capture_id, judgment_count}`.
   - `RankedResults`: `schema_version` (enum `["lps-ranked-results/v1"]`),
     `sheet_id`, `printer_profile` (same shape as the manifest's),
     `capture_count`, `latest_capture_at`/`earliest_capture_at` (nullable
     `date-time`), `scoring_algorithm_versions[]`, `results[]` (`rank`,
     `pair_id`, `scoring_algorithm_version`, `row`, `col`, `source_colors`
     {`color_a_hex`, `color_b_hex`}, `score` {`average`, `latest`, `minimum`,
     `maximum`, `capture_count`, `sample_count`, `algorithm_versions[]`},
     `current_judgment` nullable, `current_judgment_observed_at` nullable,
     `observation_count`, `latest_observation` nullable).
7. **Auth**: the app keeps sending `Authorization: Bearer <token>` via a
   client middleware (shape tested in `testBearerMiddlewareAppliesAuthorizationHeader`).
8. **App integration**: `APIClient` keeps its public surface but swaps
   hand-written `Codable` models for `Components.Schemas.*` types, mapping to
   the `MeasurementCore` domain models (`SheetManifest`, `PatchMeasurement`,
   `ChannelStats`, `PairScore` stay — they are client-side analysis models).
   `PairJudgment`, `CaptureMetadata`, `WhiteBalanceGains`, `RecentSheet`,
   `CaptureSessionResponse` (hand-written API models in
   `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`) are deleted in favor
   of generated types.

## Normalizations applied when vendoring (and why)

The served spec is the source of truth; the vendored copy applies only these
documented changes. Each one is also a candidate follow-up for
viamin/color_matching so future re-vendoring needs no normalization:

1. **Friendly operationIds** (default open_api_spex ids are
   `"ColorMatchingWeb.TestSheetController.manifest"`-style, unusable as Swift
   method names).
2. **Expand `TestSheetManifest` and `RankedResults`** to describe the full
   response bodies the Phoenix app actually renders
   (`ColorMatchingWeb.TestSheetJSON`). The published schemas only require
   `schema_version`/`sheet_id`(+`capture_profile`) — generated types from the
   served schemas alone cannot carry the sheet geometry the app consumes.
3. **Flatten `CaptureRequest` and `PairScoreRequest` root `anyOf`s** into
   plain object schemas. The served `CaptureRequest` mixes root-level
   `properties` with a root `anyOf` (flat attributes vs nested `metadata`);
   `swift-openapi-generator` translates `anyOf` to a `value1`/`value2`
   optional-property struct and **ignores sibling properties**, which would
   make the nested `quality` block untypeable. The nested `{metadata, quality}`
   shape is one of the documented `anyOf` branches, so wire compatibility is
   preserved.
4. **Add `scoring_algorithm_version` and per-measurement `stats`** to
   `MeasurementUploadRequest`. The prose contract sends both today, and the
   Phoenix app accepts and ignores them (no `additionalProperties: false`).
   Dropped silently by the published schema.

## Contract deltas: prose contract vs published spec

Source: `docs/color-matching-api-contract.md` vs the spec served by
viamin/color_matching PR #113 (`ApiSchemas` + controller specs +
`TestSheetJSON` renderers). These go in the PR description (deliverable 5).

| Area | Prose contract | Published spec / real API | Impact |
| --- | --- | --- | --- |
| Manifest `printer_profile` | `{id, name, paper, ink, settings}` | `{printer_make_model, paper_type, ink_type, icc_profile, print_settings, driver_name, driver_version, calibration_date, calibration_version, notes}` — no `id`, different key names | App model rename; `id`/`name` do not exist |
| Manifest patch `id` | example `patch_1` | `"{pair_id}##{side}"` (e.g. `pair_1#first`) | Cosmetic; app must treat ids as opaque |
| Manifest schema completeness | Full document described | `TestSheetManifest` requires only `schema_version`, `sheet_id`, `capture_profile.scoring_algorithm_version`; geometry (page/patches/pairs/markers) undocumented | **Gap (upstream)**: generated types need the vendored expansion; feed back to color_matching |
| Capture request | Nested `{metadata, quality}` | Root `anyOf`: flat attributes (note: `exposure_duration`, not `exposure_duration_seconds`) or nested `metadata`; nested `quality` declared but not required by the `anyOf` | App's nested shape accepted; flat field naming differs |
| Measurement upload | `stats` per measurement; `normalized_linear_rgb_median` optional; `scoring_algorithm_version` top-level | `stats` absent; `normalized_linear_rgb_median` **required**; `scoring_algorithm_version` absent; `RgbPayload` accepts array/object/string | Vendored spec re-adds what the app sends; `RgbPayload` anyOf is awkward for codegen (normalization candidate upstream) |
| Measurement upload response | Implied 204/empty (app's `APIClient` treats 204 as success) | **200 with JSON body** `{capture_id, measurement_count, pair_score_count}` | Generated client decodes a typed body; `APIClient` must accept 200 |
| Judgment upload response | Implied 204/empty | **200 with JSON body** `{capture_id, judgment_count}` | Same as above |
| `iso` type | Number (app sends `Float`) | `integer` (minimum 0, exclusive) | App maps to `Int` |
| Recent sheets `title` | "may be null" | Declared required-but-nullable; renderer currently always emits `null` | No change needed |
| Ranked results | Vague prose ("latest or aggregate…") | `schema_version: lps-ranked-results/v1`, rich aggregate payload (rank, score stats, current judgment, observation counts) | **Endpoint gap (app)**: the iOS app has never consumed `ranked_results` (no `APIClient` method) — the generated client adds `fetchRankedResults`, wiring it into the UI is follow-up work |
| Auth | Bearer token, optional in dev | `bearerAuth` (http/bearer) security scheme on all six operations | Middleware required (no client credential support in generated code) |
| Undocumented-in-prose endpoints | — | `/api/illuminant_measurements`, `/api/illuminant_measurements/bulk`, `/api/multi_image_mapping`, plus palette/printer-profile read endpoints exist in the spec | Not used by the app; out of scope |

Endpoint gaps summary:

- **Upstream (color_matching)**: manifest/ranked-results response schemas
  under-document the payloads; `CaptureRequest`/`PairScoreRequest` root
  `anyOf` + sibling properties is hostile to code generation; measurement
  upload schema omits `stats`/`scoring_algorithm_version` that the contract
  sends.
- **App (this repo)**: `ranked_results` was never wired into `APIClient`
  despite being in the prose contract; the new `fetchRankedResults` client
  method closes the client-side gap (UI consumption still optional).

## Tests

- `iOS/Tests/ColorMatchingLPSAppTests/OpenAPISpecCoverageTests.swift` — runs
  today (no generated target needed); fails while the vendored document is
  missing (red phase). Verifies document existence, OpenAPI 3 validity, the
  six operations with pinned operationIds, JSON request/response bodies,
  bearerAuth security, required schema components, enum visibility of the
  versioned schema strings, and the geometry/nullable-title details above.
- `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientStubbedResponseTests.swift`
  — gated on `canImport(ColorMatchingOpenAPI)`; exercises all six operations
  through the generated `Client` against an in-memory `ClientTransport` stub,
  asserting decoded types, wire paths/methods/headers, snake_case payload
  shapes, 201/200 handling, and bearer-auth middleware. Fixtures mirror the
  real Phoenix renderer output (`pair_1#first` patch ids, nullable `title`,
  measurement/judgment count bodies).
