# OpenAPI Generated Client — Test Plan And Contract Deltas

Status: **tests-only run (red phase)** for issue #5, "Replace hand-written API layer with a
generated OpenAPI Swift client". This document records the acceptance-criteria-to-test
mapping, the deltas found between `docs/color-matching-api-contract.md` and the published
spec from viamin/color_matching#110 (landed as viamin/color_matching#113), and the
implementation contract the tests encode. It is the source material for the PR description.

Upstream sources consulted (viamin/color_matching @ `main`, PR #113 merged 2026-10-30):

- `lib/color_matching_web/router.ex` — route table for `/api/v1`
- `lib/color_matching_web/api_spec.ex` + `api_schemas.ex` — the published OpenAPI schemas
- `lib/color_matching_web/controllers/test_sheet_controller.ex`, `capture_controller.ex` —
  documented status codes and request/response bodies
- `lib/color_matching_web/controllers/test_sheet_json.ex` — actual runtime JSON shapes

The spec is **generated at build time by `open_api_spex`** (served at
`GET /api/v1/openapi.json`, or emitted via
`mix openapi.spec.json --spec ColorMatchingWeb.ApiSpec`). There is no static spec file
upstream, so this repo must vendor a rendered copy.

## Acceptance criteria → verification mapping

| AC | Criterion | Verification | Test / evidence |
|----|-----------|--------------|-----------------|
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` in the iOS package; OpenAPI document vendored | Permanent wiring tests (red today, inspectable failure messages) | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientWiringTests.swift`: `testPackageManifestDeclaresOpenAPIToolchain`, `testVendoredOpenAPIDocumentCoversAppSurfaces`, `testVendoredOpenAPIDocumentTypesUploadResponseBodies` |
| AC-2 | Client generated for the six app surfaces (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results) | Permanent wiring test (red today) + gated generated-client tests (activate post-implementation) | `OpenAPIClientWiringTests.testGeneratedClientTargetDirectoryIsConfigured`, `testVendoredOpenAPIDocumentCoversAppSurfaces`; `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` (all seven tests) |
| AC-3 | Hand-written API models replaced with generated types; purely client-side models kept | Verified post-implementation by the whole suite compiling and passing: existing `APIClientTests` (request encoding) and new `APIServerResponseContractTests` (response decoding) pin behavior, not model names | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (existing), `iOS/Tests/ColorMatchingLPSAppTests/APIServerResponseContractTests.swift` (new) |
| AC-4 | Swift tests exercising the generated client against local stubbed responses (no live server) | `GeneratedClientTests.swift` stubs `ClientTransport` directly; no network. Compiled out via `#if canImport(OpenAPIGeneratedClient)` until the implementation run adds the target — the wiring test fails loudly in the meantime so the coverage cannot silently vanish | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` |
| AC-5 | PR description records contract deltas and endpoint gaps | Section "Contract deltas" below, written from the upstream sources listed above | This document |

Why the generated-client tests are `#if canImport`-gated: Swift test targets do not compile
against a module that does not exist yet; without the gate, the entire test target would
fail to build in this red phase and bury the passing baseline. The gate is paired with
`testGeneratedClientTargetDirectoryIsConfigured`/`testPackageManifestDeclaresGeneratedClientTarget`,
which stay red until the module exists, so the gated tests cannot be forgotten.

## Test inventory and expected red-phase state

| File | Tests | State today |
|------|-------|-------------|
| `OpenAPIClientWiringTests.swift` | 5 | **Red** (no deps, no vendored spec, no generated target) |
| `APIServerResponseContractTests.swift` | 6 | Green (pins real published server responses; must stay green after rewiring) |
| `GeneratedClientTests.swift` | 7 | Compiled out (no `OpenAPIGeneratedClient` module yet); activates with the implementation |
| `APIClientTests.swift` (existing) | 3 | Green; `testUploadMeasurementsEncodesScoresWithAlgorithmVersion` pins the prose-contract upload payload — see delta D2 |

## Contract deltas (prose contract vs published spec vs runtime)

PR-description-ready. "Prose" = `docs/color-matching-api-contract.md`; "Spec" = schemas
published by viamin/color_matching#113; "Runtime" = `TestSheetJSON` / controller behavior.

- **D1 — Manifest schema is under-documented in the spec (gap).** Runtime manifests carry
  `sheet_version`, `manifest_url`, `created_at`, `page`, `registration_markers`,
  `printer_profile`, `capture_profile` (3 fields), `patches`, `pairs` — matching the prose
  contract — but the published `TestSheetManifest` schema documents only `schema_version`,
  `sheet_id`, and `capture_profile.scoring_algorithm_version`. A client generated from the
  published spec alone cannot feed the app's geometry/sampling pipeline (no `patches` /
  `pairs` / `page`). The implementation must either extend the vendored manifest schema
  (record the divergence) or keep decoding the manifest with the domain model. Both are
  accepted by the tests here; the decision belongs in the PR description.
- **D2 — Measurement upload payload shrinks in the spec (gap).** Prose sends per-measurement
  `stats` (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`) and a top-level
  `scoring_algorithm_version`; the published `MeasurementUploadRequest` documents neither, so
  generated types would silently drop them. Also `normalized_linear_rgb_median` is
  **required** in the spec (optional in the prose contract and in `PatchMeasurement`), and
  `linear_rgb_median` is a polymorphic `RgbPayload` (number array OR `{r,g,b}` OR string —
  prose documents only `{r,g,b}`). Existing
  `APIClientTests.testUploadMeasurementsEncodesScoresWithAlgorithmVersion` pins the richer
  prose shape and will go red on a naive swap; reconcile consciously (extend vendored spec
  or accept the data loss) and record it.
- **D3 — Upload responses are `200` with JSON bodies, not `204`.** Published + runtime:
  measurements → `{"capture_id","measurement_count","pair_score_count"}`, judgments →
  `{"capture_id","judgment_count"}`. The prose contract documented no response body and the
  existing tests stub `204`. `APIServerResponseContractTests` pins the real `200`-with-body
  shape so the rewired client must accept it.
- **D4 — Capture creation accepts two shapes.** The published `CaptureRequest` supports the
  prose `{metadata, quality}` nested shape **and** a flat legacy shape whose field names
  differ: `exposure_duration` (not `exposure_duration_seconds`) and `rejection_reasons`
  (not `rejections`). The app should keep sending the nested shape.
- **D5 — Ranked results schema under-documented (gap).** Runtime returns a rich payload
  (`printer_profile`, `capture_count`, `latest/earliest_capture_at`,
  `scoring_algorithm_versions`, per-pair `results[]` with scores/judgments/provenance);
  the published `RankedResults` schema documents only `schema_version`
  (`lps-ranked-results/v1`) and `sheet_id`. Generated types cover the versioned envelope
  only; the PR should note the enrichment needed upstream.
- **D6 — Typed error envelope is new.** Published `ApiErrorResponse`
  (`errors` as object or array of `{detail, source{pointer}}`) on `401`/`404`/`422` is absent
  from the prose contract. Generated output enums surface `.unauthorized`, `.not_found`,
  `.unprocessable_entity`; `GeneratedClientTests.testManifestOperationSurfacesTypedNotFoundResponse`
  pins one case.
- **D7 — `printer_profile` field names differ.** Prose manifest: `{id, name, paper, ink,
  settings}`. Runtime/spec: `{printer_make_model, paper_type, ink_type, icc_profile,
  print_settings, driver_name, driver_version, calibration_date, calibration_version,
  notes}`. Any client-side model of printer provenance must use the runtime names.
- **D8 — Patch IDs are composite.** Runtime patch ids are `"<pair_id>#first|second"`
  (e.g. `pair_1#first`), not free-form like the prose example `patch_1`. Fixtures here use
  the composite form.
- **D9 — No reference patches at runtime.** The prose contract documents `reference` patch
  roles (`white`, `gray`, `black`, `blank_paper`); the runtime sheet renderer emits only
  `pair_color` patches with `reference_role: null`, which starves the app's
  reference-normalization step. Gap to raise upstream.
- **D10 — `iso` is an integer in the spec** (`minimum: 0, exclusiveMinimum: true`) while the
  app's `CaptureMetadata.iso` is `Float`; `100.5` would be rejected by upstream
  `CastAndValidate`. Map to `Int` in generated payloads.
- **D11 — Recent sheets always render `title: null` today**; spec marks it required-but-
  nullable, which matches the prose contract's allowance. Covered by fixtures on both the
  hand-written and generated paths.
- **D12 — Endpoints upstream that the prose contract does not mention:** `GET
  /api/v1/printer_profiles`, `GET /api/v1/printer_profiles/{id}/colors`,
  `GET /api/v1/printer_profiles/{id}/metamer_pairs`, `GET /api/v1/palettes`,
  `GET /api/v1/colors`, `POST /api/illuminant_measurements`,
  `POST /api/illuminant_measurements/bulk`, `POST /api/multi_image_mapping`. Out of scope
  for this app; listed for PR completeness.
- **D13 — Pair scores: `similarity` is optional in the spec.** Published
  `PairScoreRequest` requires `pair_id` + `algorithm_version` plus any one of
  `score`/`similarity`/`distance`; the prose contract always sent both `distance` and
  `similarity`. The app's payload remains valid.

## Implementation contract encoded by the tests

The implementation run must satisfy the following so the tests here turn green:

1. **Package wiring.** `iOS/Package.swift` declares `.package(url: …swift-openapi-generator…)`
   and `…swift-openapi-runtime…` dependencies, plus a target named exactly
   `OpenAPIGeneratedClient` (expected at `iOS/Sources/OpenAPIGeneratedClient/`). The
   `ColorMatchingLPSAppTests` test target must declare `OpenAPIGeneratedClient` in its
   dependencies so `#if canImport(OpenAPIGeneratedClient)` becomes true and the gated tests
   actually compile in.
2. **Vendored document.** A file whose name contains `openapi` with a `.json`/`.yaml`/`.yml`
   extension under `iOS/` (outside `.build`), rendered from upstream. It must contain the
   six app-surface paths verbatim (with `{sheet_id}` / `{capture_id}` placeholders),
   `bearerAuth`, and the upload response count fields.
3. **Operation names.** Upstream operationIds are
   `ColorMatchingWeb.TestSheetController.manifest|recent|ranked_results` and
   `ColorMatchingWeb.CaptureController.create|upload_measurements|upload_judgments`. The
   generator's default (`defensive`) naming turns `.` into `_period_`, producing unusable
   Swift identifiers. Configure `nameOverrides` in `openapi-generator-config.yaml` so the
   generated methods are:

   | operationId | Swift method |
   |---|---|
   | `ColorMatchingWeb.TestSheetController.manifest` | `getTestSheetManifest` |
   | `ColorMatchingWeb.TestSheetController.recent` | `getRecentTestSheets` |
   | `ColorMatchingWeb.TestSheetController.ranked_results` | `getRankedResults` |
   | `ColorMatchingWeb.CaptureController.create` | `createCapture` |
   | `ColorMatchingWeb.CaptureController.upload_measurements` | `uploadCaptureMeasurements` |
   | `ColorMatchingWeb.CaptureController.upload_judgments` | `uploadCaptureJudgments` |

4. **Generated type names.** Schema titles map to
   `Components.Schemas.{TestSheetManifest, RecentSheetsResponse, CaptureRequest,
   CaptureMetadata, CaptureCreatedResponse, MeasurementUploadRequest, PairScoreRequest,
   JudgmentUploadRequest, JudgmentUploadResponse, RankedResults, ApiErrorResponse}`.
   Inline object payloads nest as `<property>Payload` (e.g.
   `CaptureRequest.qualityPayload`, `MeasurementUploadRequest.measurementsPayload`,
   `JudgmentUploadRequest.judgmentsPayload`); `RgbPayload`'s `anyOf` becomes
   `case1`/`case2`/`case3`. If the resolved generator version differs on a nested name,
   prefer adjusting the test fixture construction mechanically — do not weaken assertions.
5. **Stub transport.** `GeneratedClientTests` implements `ClientTransport` directly, so no
   URL session or live server is involved. If the pinned `swift-openapi-runtime` major
   version changed `HTTPResponse`'s body type from `Data?` to `HTTPBody?`, wrap the fixture
   body accordingly in `GeneratedClientStubTransport`.
6. **App surface preserved.** `APIClient`'s public methods used by `ContentView`
   (`fetchManifest`, `fetchRecentSheets`, `createCapture`, `uploadMeasurements`,
   `uploadJudgments`) keep their signatures so `APIServerResponseContractTests` stays green;
   internally they move onto the generated `Client`. Purely client-side models
   (`PatchMeasurement`, `ChannelStats`, `PairScore`, geometry types) stay in
   `MeasurementCore`.
7. **Exit criterion.** `swift test --disable-sandbox` green with generated types wired in;
   CI (`.github/workflows/ci.yml`) runs it on macOS. This environment has no Swift
   toolchain, so local execution was not possible — CI is the executor of record.

## Verification evidence file

Criterion-level status is recorded in `tmp/paid-agent-verification.json` at the head of
this tests-only PR: wiring criteria are demonstrably red, generated-client execution is
`not_run` pending the implementation target and a Swift toolchain, and the contract-delta
criterion is evidenced by this document.
