# Generated OpenAPI client — test plan and pinned conventions (issue #5)

Status: **test-writing (red) phase** for "Replace hand-written API layer with a generated
OpenAPI Swift client". This document pins the conventions the implementation run must
follow so the tests in `iOS/Tests/ColorMatchingLPSAppTests/` compile and pass, and
records the contract deltas found between `docs/color-matching-api-contract.md` (the
prose contract) and the published OpenAPI spec from `viamin/color_matching#110`.

## Acceptance criteria → verification map

| ID | Criterion (from issue #5) | Verification | Where |
|----|---------------------------|--------------|-------|
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` added to the iOS package; OpenAPI document vendored | `unit_or_service_test` (repo-structure gates) | `OpenAPISpecVendoringTests` (spec exists, is OpenAPI 3, covers all six surfaces, documents bearer auth, types the fields the app consumes) and `OpenAPIClientWiringTests.testPackageManifestDeclaresOpenAPIGeneratorAndRuntime` / `testPackageManifestDeclaresGeneratedClientTarget` |
| AC-2 | Client generated for: sheet manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | `unit_or_service_test` | `OpenAPISpecVendoringTests.testVendoredSpecCoversEveryAppSurface` (path + method + operationId for each surface) and `GeneratedClientStubbedResponseTests` (guarded by `#if canImport(ColorMatchingOpenAPI)`; activates when the generated target exists) |
| AC-3 | Hand-written API models replaced by generated types; purely client-side models kept | `unit_or_service_test` | `OpenAPIClientWiringTests.testAppCoreImportsGeneratedClient`, `testAppCoreNoLongerHandCodesWirePayloads` (no `CodingKeys`/`JSONEncoder`/`JSONDecoder` left in `Sources/ColorMatchingLPSAppCore`), `testAppCoreExposesRankedResultsSurface`; `APIClientWireContractTests` pins the app-facing wire behavior that must survive the refactor |
| AC-4 | Swift tests exercising the generated client against local stubbed responses (no live server) | `unit_or_service_test` | `GeneratedClientStubbedResponseTests` (stub `ClientTransport`, canned JSON, zero network) plus `APIClientWireContractTests` (stub `URLProtocol` through the app facade) |
| AC-5 | PR description records prose-contract ↔ published-spec deltas and endpoint gaps | `human_or_external_evidence` | Delta table below is the source material; the implementation run must mirror it in the PR description |

Exit criterion `swift test --disable-sandbox` green with generated types wired in: on
Linux, build-tool plugins require `--disable-sandbox`; the repo's CI (macOS) runs plain
`swift test`, where no flag is needed.

## Conventions pinned by the tests (for the implementation run)

1. **Generated target/module name:** `ColorMatchingOpenAPI` (declared in
   `iOS/Package.swift`, hosting the vendored document + generator plugin).
2. **Spec location:** `iOS/Sources/ColorMatchingOpenAPI/openapi.yaml`, fetched from
   `GET /api/v1/openapi.json` on the Phoenix app (runtime-rendered by OpenApiSpex) and
   converted to YAML. Vendor the *published* document, with only the mechanical
   transformations listed below — each one must be called out in the PR description.
3. **operationId rewrites** (published spec uses `ColorMatchingWeb.<Controller>.<action>`):

   | Published operationId | Path | Rewritten to |
   |------------------------|------|--------------|
   | `ColorMatchingWeb.TestSheetController.manifest` | `/api/v1/test_sheets/{sheet_id}/manifest` | `getTestSheetManifest` |
   | `ColorMatchingWeb.TestSheetController.recent` | `/api/v1/test_sheets/recent` | `getRecentSheets` |
   | `ColorMatchingWeb.TestSheetController.ranked_results` | `/api/v1/test_sheets/{sheet_id}/ranked_results` | `getRankedResults` |
   | `ColorMatchingWeb.CaptureController.create` | `/api/v1/test_sheets/{sheet_id}/captures` | `createCapture` |
   | `ColorMatchingWeb.CaptureController.upload_measurements` | `/api/v1/captures/{capture_id}/measurements` | `uploadMeasurements` |
   | `ColorMatchingWeb.CaptureController.upload_judgments` | `/api/v1/captures/{capture_id}/judgments` | `uploadJudgments` |
4. **Generator config:** `access: package` so test and app targets inside the package can
   see the generated types (default `.internal` hides them and breaks the tests).
5. **Spec enrichment (delta vs published spec, forced by
   `testVendoredSpecTypesTheFieldsTheAppConsumes`):** the published schemas under-type
   payloads the app actually consumes (see deltas D1–D4 below). The vendored document
   must add, as **optional unless noted**, the fields
   `MeasurementCore.SheetManifest` needs (`sheet_version`, `manifest_url`, `page`,
   `registration_markers`, `patches` incl. `safe_inset_mm`, `pairs` incl. `grid_row`,
   `first_patch_id`, `second_patch_id`, `source_colors`) and the per-measurement `stats`
   object (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`) plus
   top-level `scoring_algorithm_version` on `MeasurementUploadRequest`.
6. **Facade compatibility:** `APIClient`'s public methods (`fetchManifest`,
   `fetchRecentSheets`, `createCapture`, `uploadMeasurements`, `uploadJudgments`) keep
   their signatures and wire behavior; internally they delegate to the generated client
   (`import ColorMatchingOpenAPI`). Hand-written wire `Codable` types in
   `Sources/ColorMatchingLPSAppCore` are removed (typealiases to generated types are
   fine). `MeasurementCore` domain models are client-side and stay as-is.

## Contract deltas: prose contract vs published spec

Evidence: `viamin/color_matching@main` — `lib/color_matching_web/api_spec.ex`,
`lib/color_matching_web/api_schemas.ex`, `lib/color_matching_web/controllers/test_sheet_controller.ex`,
`lib/color_matching_web/controllers/capture_controller.ex`, `lib/color_matching_web/router.ex`,
`test/color_matching_web/controllers/open_api_controller_test.exs`.

- **D1 — Manifest is drastically under-typed.** Prose contract documents
  `schema_version`, `sheet_version`, `sheet_id`, `manifest_url`, `created_at`, `page`,
  `registration_markers`, `printer_profile`, `capture_profile`, `patches`, `pairs`. The
  published `TestSheetManifest` schema only types `schema_version` (enum
  `lps-sheet-manifest/v1`), `sheet_id`, and
  `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`). The server
  returns the rest untyped; the generated client needs the enrichment in convention 5.
- **D2 — Measurement upload request differs.** Prose documents top-level
  `scoring_algorithm_version`, per-measurement `stats`
  (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`), and optional
  `normalized_linear_rgb_median`. Published `MeasurementUploadRequest` has none of the
  stats/top-level version, marks `normalized_linear_rgb_median` **required**, leaves
  `measurements`/`pair_scores` unset in `required`, types `linear_rgb_median` as
  `RgbPayload` = anyOf(array of numbers / `{r,g,b}` object / string), and moves the
  algorithm version into each `PairScoreRequest` (`pair_id`, `algorithm_version`
  required; anyOf `score`/`similarity`/`distance`).
- **D3 — Uploads now return 200 + JSON bodies.** Prose documented no response payloads
  (the app's current tests stub `204`). Published spec: `MeasurementUploadResponse`
  `{capture_id, measurement_count, pair_score_count}` and `JudgmentUploadResponse`
  `{capture_id, judgment_count}`, both `200`.
- **D4 — Capture create request is a superset.** Published `CaptureRequest` allows a
  flat form (`device_model`, `lens`, `exposure_duration` — note: **not**
  `exposure_duration_seconds` — `detected_marker_count`, `blur_score`,
  `rejection_reasons`) **and** the prose's nested `{metadata, quality}` form via
  `anyOf`. `CaptureMetadata.iso` is `integer` in the spec (the Swift model uses
  `Float`), `white_balance_gains` is an untyped object. Response is `201` with
  `{capture_id}` where `capture_id` is the **stringified integer DB id**.
- **D5 — Ranked results schema version introduced.** Prose describes the payload only
  in words ("source colors, scores, labels, capture provenance, printer profile, and
  scoring algorithm version"). Published `RankedResults` types just `schema_version`
  (new enum `lps-ranked-results/v1`, absent from the prose contract) + `sheet_id`;
  everything the prose promises is untyped. Endpoint gap: none of the ranked-results
  content is machine-checked today.
- **D6 — Auth.** Published spec declares `bearerAuth` (http/bearer) per operation —
  matches the prose contract's bearer-token scheme. Spec served at
  `GET /api/v1/openapi.json` (unauthenticated), servers: `/`.
- **D7 — Endpoints beyond the app's surfaces exist in the spec** (informational; the
  generated client will include them): `/api/v1/printer_profiles`, `/api/v1/printer_profiles/{printer_profile_id}/colors`,
  `/api/v1/printer_profiles/{printer_profile_id}/metamer_pairs`, `/api/v1/palettes`,
  `/api/v1/colors`, plus `/api/illuminant_measurements`, `/api/illuminant_measurements/bulk`,
  `/api/multi_image_mapping` (the latter two are not part of `/api/v1` and were
  previously undocumented anywhere).
- **D8 — Response vocabulary.** Published operations document `401` (`unauthorized`),
  `404` (`not_found`), and `422` (`unprocessable_entity`) error responses typed as
  `ApiErrorResponse`; the prose contract never documented error responses.

## Test-run notes

- Red phase: `OpenAPISpecVendoringTests` and `OpenAPIClientWiringTests` fail by design
  until the spec is vendored, the package is wired, and the hand-written wire models
  are migrated. `APIClientWireContractTests` passes against the current hand-written
  client and must stay green after the migration. `GeneratedClientStubbedResponseTests`
  is compiled out (`#if canImport(ColorMatchingOpenAPI)`) until the generated target
  exists, then runs against stubbed transports — no live server anywhere.
- `format: date-time` maps to `Foundation.Date` in generated types (per the
  generator's Supported-OpenAPI-features doc), so generated `CaptureMetadata.timestamp`
  is a `Date`; the tests construct it from an explicit epoch.
- The Xcode project (`iOS/ColorMatchingLPS.xcodeproj`) lists test sources explicitly,
  so the new test files run today via `swift test` (SPM auto-discovery) but must be
  added to the `ColorMatchingLPSAppTests` target by the implementation run to also run
  under `xcodebuild test`.
- This container has no Swift toolchain; the executor for all Swift tests is the repo's
  macOS CI (`swift test` + `xcodebuild test`).
