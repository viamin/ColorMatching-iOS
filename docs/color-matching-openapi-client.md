# Generated OpenAPI Client For `color_matching` (issue #5)

This document pins the plan for replacing the hand-written API layer
(`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`) with a client generated
by [swift-openapi-generator](https://github.com/apple/swift-openapi-generator)
from the machine-readable OpenAPI spec published by `viamin/color_matching`
(issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110),
landed in `viamin/color_matching#113`, served at `GET /api/v1/openapi.json`).

It also records, for the PR description, every delta found between the prose
contract (`docs/color-matching-api-contract.md`) and the published spec
(verified against upstream's `TestSheetJSON` / `CaptureController` rendering
code on `main` at the time of writing).

## Package wiring (implementation phase)

- `iOS/Package.swift` gains:

  ```swift
  .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.6.0"),
  .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),

  .target(
      name: "OpenAPIGeneratedClient",
      dependencies: [
          .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
      ],
      plugins: [
          .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
      ]
  ),
  ```

- `iOS/Sources/OpenAPIGeneratedClient/openapi-generator-config.yaml`:
  `generate: {interfaces: [client], access: internal}` — the wrapper
  (`ColorMatchingLPSAppCore`) is the only consumer; tests use
  `@testable import`. If the generated target is consumed without
  `@testable`, use `access: public` and plain `import`.
- The OpenAPI document is **vendored** (CI has no server): fetch
  `GET /api/v1/openapi.json` from a running `color_matching`, then apply the
  operation-ID and schema edits below, and commit as
  `iOS/Sources/OpenAPIGeneratedClient/openapi.yaml`. Record the upstream
  commit SHA used in the PR description.
- `ColorMatchingLPSAppCore` depends on `OpenAPIGeneratedClient`;
  `ColorMatchingLPSApp` keeps using the `APIClient` wrapper surface.
- New test target `OpenAPIClientTests` (declared in `Package.swift` during the
  implementation phase) compiles the suite already committed at
  `iOS/Tests/OpenAPIClientTests/`.

## Vendored operation IDs

`Paths.from_routes` derives operation IDs as `"<ControllerModule>.<action>"`
(e.g. `ColorMatchingWeb.TestSheetController.manifest`), which sanitize into
unusable Swift method names. The vendored copy replaces them with stable IDs;
the generated `Client` method names equal these IDs verbatim:

| Route | Upstream operation ID | Vendored operation ID | Tests |
| --- | --- | --- | --- |
| `GET /api/v1/test_sheets/{sheet_id}/manifest` | `ColorMatchingWeb.TestSheetController.manifest` | `getTestSheetManifest` | `GeneratedClientContractTests.testGetTestSheetManifestDecodesFullManifestFixture`, `.testGetTestSheetManifestExposesNotFoundCase` |
| `GET /api/v1/test_sheets/recent` | `ColorMatchingWeb.TestSheetController.recent` | `listRecentTestSheets` | `.testListRecentTestSheetsDecodesSheetsAndNullableTitle` |
| `GET /api/v1/test_sheets/{sheet_id}/ranked_results` | `ColorMatchingWeb.TestSheetController.ranked_results` | `getRankedResults` | `.testGetRankedResultsDecodesAggregateFixture` |
| `POST /api/v1/test_sheets/{sheet_id}/captures` | `ColorMatchingWeb.CaptureController.create` | `createCapture` | `.testCreateCapturePostsNestedMetadataAndQuality` |
| `POST /api/v1/captures/{capture_id}/measurements` | `ColorMatchingWeb.CaptureController.upload_measurements` | `uploadMeasurements` | `.testUploadMeasurementsPostsSpecShapedPayload` |
| `POST /api/v1/captures/{capture_id}/judgments` | `ColorMatchingWeb.CaptureController.upload_judgments` | `uploadJudgments` | `.testUploadJudgmentsPostsPairJudgments` |

## Vendored schema enrichment policy

The published spec under-describes several responses the app depends on (see
deltas). The vendored copy is enriched to describe what the server actually
sends (verified against `ColorMatchingWeb.TestSheetJSON` and
`ColorMatchingWeb.CaptureController` on upstream `main`); each edit is a row in
the delta table below so regeneration diffs stay reviewable. Property order in
the vendored document must match this listing — the tests construct generated
initializers positionally.

Named component schemas in the vendored document (all snake_case JSON keys;
generated Swift properties are camelCase):

- `TestSheetManifest`: `schema_version, sheet_version, sheet_id, manifest_url, created_at?, page, registration_markers[], printer_profile?, capture_profile, patches[], pairs[]` (all required unless `?`).
  - `SheetPage`: `units, width, height`
  - `RectPayload`: `x, y, width, height`
  - `RegistrationMarkerPayload`: `role, shape, rect`
  - `PrinterProfilePayload`: `printer_make_model, paper_type, ink_type, icc_profile?, print_settings?, driver_name?, driver_version?, calibration_date?, calibration_version?, notes?`
  - `CaptureProfilePayload`: `expected_illuminant, preferred_camera, scoring_algorithm_version`
  - `SheetPatch`: `id, role, pair_id?, pair_side?, reference_role?, source_color?, safe_inset_mm, rect`
  - `SheetPair`: `id, first_patch_id, second_patch_id, source_colors, grid_row, grid_col`
- `RecentSheetsResponse`: `sheets: [RecentSheet]`; `RecentSheet`: `sheet_id, manifest_url, title?`
- `RankedResults`: `schema_version, sheet_id, printer_profile?, capture_count, latest_capture_at?, earliest_capture_at?, scoring_algorithm_versions, results[]`
  - `RankedResult`: `rank, pair_id, scoring_algorithm_version, row, col, source_colors, score, current_judgment?, current_judgment_observed_at?, observation_count, latest_observation?, capture_count, latest_capture_at?, earliest_capture_at?`
  - `RankedResultSourceColors`: `color_a_hex, color_b_hex`
  - `RankedResultScore`: `average, latest, minimum, maximum, capture_count, sample_count, algorithm_versions`
  - `RankedResultObservation`: `judgment, observed_at`
- `CaptureRequest` (pinned to the nested branch of upstream's `anyOf`): `metadata, quality`
  - `CaptureMetadata`: `device_model, lens, exposure_duration_seconds?, iso?, focus_lens_position?, white_balance_gains?, image_width?, image_height?, app_version, timestamp` (`device_model, lens, app_version, timestamp` required)
  - `WhiteBalanceGains`: `red, green, blue` (declared; upstream leaves free-form)
  - `CaptureQualityPayload`: `detected_marker_count, blur_score, rejections`
  - `CaptureCreatedResponse`: `capture_id`
- `MeasurementUploadRequest`: `measurements[], pair_scores[]`
  - measurement item: `patch_id, linear_rgb_median, normalized_linear_rgb_median` (object form `{r, g, b}` — upstream `RgbPayload` is `anyOf [array|object|string]`; vendored copy pins the object branch the app uses)
  - `PairScoreRequest`: `pair_id, algorithm_version, similarity, distance` (the unused `score` variant is dropped from the vendored copy)
  - `MeasurementUploadResponse`: `capture_id, measurement_count, pair_score_count`
- `JudgmentUploadRequest`: `judgments[]` of `{pair_id, judgment}`
- `JudgmentUploadResponse`: `capture_id, judgment_count`
- `ApiErrorResponse`: `errors` (kept as published)

## Contract deltas: prose contract vs published spec vs actual server

Record these in the PR description verbatim. "Actual" = upstream `main`
controller/JSON-view behavior, which is the ground truth the app must survive.

| # | Area | Prose contract (`docs/color-matching-api-contract.md`) | Published spec (upstream #113) | Actual server behavior / consequence for iOS |
| --- | --- | --- | --- | --- |
| 1 | Manifest response | Full manifest documented (`sheet_version`, `manifest_url`, `created_at`, `page`, `registration_markers`, `printer_profile`, `capture_profile`, `patches`, `pairs`) | `TestSheetManifest` declares only `schema_version`, `sheet_id`, `capture_profile.scoring_algorithm_version` | Server renders the full manifest. A client generated from the published schema alone would **silently drop** patches/pairs/page. Vendored copy enriched to the actual shape. Upstream should expand the schema. |
| 2 | Patch IDs | Example uses `patch_1` / `patch_2` | Not specified | Server renders `<pair_id>#first` / `<pair_id>#second` (e.g. `pair_1#first`); `pairs[].first_patch_id`/`second_patch_id` use the same format. Tests pin this. |
| 3 | `printer_profile` | `{id, name, paper, ink, settings}` | `PrinterProfile` requires `id, printer_make_model, paper_type, ink_type` | Server never sends `id` and sends `icc_profile, print_settings, driver_name, driver_version, calibration_date, calibration_version, notes`. The published schema both mismatches prose and mis-declares `id` as required/sent. Vendored copy uses `PrinterProfilePayload` matching the actual payload. |
| 4 | Capture request | Nested `{metadata: {...}, quality: {...}}` | `CaptureRequest` is `anyOf[flat legacy shape, {metadata, quality}]`; flat branch names it `exposure_duration`, nested branch `exposure_duration_seconds` | Server accepts both. Vendored copy pins the nested branch (the app's shape). Upstream naming inconsistency (`exposure_duration` vs `exposure_duration_seconds`) noted. |
| 5 | `iso` | Number (float allowed) | Integer | Upstream casts integer. App must send integral ISO. Vendored copy declares integer. |
| 6 | `white_balance_gains` | `{red, green, blue}` | Free-form object (no properties declared) | Vendored copy declares `red, green, blue` so gains survive the typed client. |
| 7 | Capture response | `{"capture_id": "capture_123"}` (opaque) | `CaptureCreatedResponse.capture_id: string`, HTTP 201 | Server sends the DB integer id stringified (e.g. `"42"`). Clients must treat it as opaque. |
| 8 | Measurement upload request | Top-level `scoring_algorithm_version`; per-measurement `stats {sample_count, clipping_fraction, mean, standard_deviation}`; `normalized_linear_rgb_median` optional | No top-level `scoring_algorithm_version`; **no `stats` at all**; `normalized_linear_rgb_median` **required**; `algorithm_version` required per pair score; score is `anyOf score/similarity/distance`; `RgbPayload` is `anyOf array/object/string` | **Endpoint gap**: the published spec cannot represent per-measurement stats or a top-level scoring version — the app's generated payload drops them. Needs an upstream schema addition if stats should be persisted; until then the data is lost. Tests pin the spec-shaped payload (and assert the old top-level key is absent). |
| 9 | Measurement upload response | Not documented (app treated as fire-and-forget, any 2xx) | HTTP 200 with `{capture_id, measurement_count, pair_score_count}` | Not 204. The generated client expects a JSON body; tests pin the 200 shape. |
| 10 | Judgment upload response | Not documented | HTTP 200 with `{capture_id, judgment_count}` | Not 204. Tests pin the 200 shape. |
| 11 | Ranked results | Prose describes contents ("source colors, scores, labels, capture provenance, printer profile, scoring algorithm version") with **no schema** | `RankedResults` declares only `schema_version ("lps-ranked-results/v1"), sheet_id` | Server renders rich aggregate results (`results[]` with `rank`, per-pair score aggregates, `current_judgment`, `observation_count`, `latest_observation`, capture windows, `scoring_algorithm_versions`). Vendored copy enriched to the actual shape. Upstream should expand the schema. |
| 12 | Judgment values | Enum: `match`, `near_match`, `no_match` | Free-form string | Not machine-enforced upstream. App continues to send only the three documented values; enum enforcement now lives in the app-side wrapper. |
| 13 | Capture rejection strings | Enum of six values (`missingRegistrationMarks` …) | Free-form string array | Not machine-enforced upstream; app-side `CaptureRejection` remains the authority. |
| 14 | Auth | "May allow unauthenticated in development" | `bearerAuth` security scheme on every sheet/capture operation | Router pipes `:api_auth` ahead of all `/api/v1` sheet/capture routes — auth is enforced; there is no code-level dev bypass. The wrapper must always send `Authorization: Bearer <token>`. |
| 15 | Unused surfaces | — | Spec also covers `/api/v1/printer_profiles*`, `/palettes`, `/colors`, `/api/illuminant_measurements*`, `/api/multi_image_mapping` | Generated but unused by the app; out of scope for #5. |

**Endpoint gaps found:** no missing endpoints — all six surfaces the app uses
are present in the published spec. The gaps are schema-level: manifest and
ranked-results responses under-described (#1, #11), measurement `stats` and
top-level scoring version unrepresentable (#8), `PrinterProfile.id` declared
but never sent (#3).

## Model split after the swap

- Deleted (hand-written API models in `APIClient.swift`):
  `CaptureMetadata`, `WhiteBalanceGains`, `CaptureSessionResponse`,
  `RecentSheet`, `PairJudgment`, private request/response wrappers, and the
  snake-case JSON coder extensions — replaced by
  `OpenAPIGeneratedClient` types.
- Kept as-is (purely client-side, `MeasurementCore`): `SheetManifest`,
  `Patch`, `PairManifest`, `Page`, `RegistrationMarker`, `Rect`, `RGB`,
  `ChannelStats`, `PatchMeasurement`, `PairScore`, `CaptureQuality`. The
  wrapper maps generated payloads onto these domain models; e.g.
  `APIClient.fetchManifest(from:)` still returns `SheetManifest`.
- `APIError.badStatus` maps to the generated client's typed response cases
  (`.unauthorized`, `.notFound`, `.unprocessableEntity`, `.undocumented`).

## Acceptance-criterion verification map

| Criterion | Smallest credible verification | Where |
| --- | --- | --- |
| swift-openapi-generator + runtime added; OpenAPI document vendored | Generated target must exist for the suite to build (import surface is the check); wiring diff is human-inspectable | `iOS/Tests/OpenAPIClientTests/` + PR diff |
| Client generated for manifest/recent/capture/measurement/judgment/ranked surfaces | One stubbed-response test per operation | `GeneratedClientContractTests` (7 tests) |
| Hand-written API models replaced; client-side models kept | Wrapper regression net stays green through the swap (manifest + recent sheets already green pre-swap) | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Swift tests against stubbed responses, no live server | Suite uses `StubURLProtocol` only | `iOS/Tests/OpenAPIClientTests/Support/StubbedTransport.swift` |
| PR description records deltas + gaps | Delta table above copied into the PR body | `docs/color-matching-openapi-client.md` |

Exit criterion "`swift test --disable-sandbox` green with generated types wired
in" is exercised once the implementation phase declares the
`OpenAPIGeneratedClient` and `OpenAPIClientTests` targets; until then the new
suite is intentionally inert (SwiftPM ignores undeclared test directories), so
the tests-only PR keeps the existing suite green.
