# OpenAPI Generated Client — Test Plan & Contract Deltas (Issue #5)

Status: **red-phase test plan**. The tests named below are committed ahead of the
implementation; `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIArtifactTests.swift` fails
until the OpenAPI toolchain and vendored spec land, and
`iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientContractTests.swift` is compiled
out (`#if canImport(OpenAPIGeneratedCore)`) until the generated target exists.

The published spec analyzed here comes from viamin/color_matching#110 (closed):
the spec is served at `GET /api/v1/openapi.json` and assembled from
`ColorMatchingWeb.ApiSpec` + `ColorMatchingWeb.ApiSchemas` + controller
`operation` specs. All "served spec" claims below cite `viamin/color_matching@main`
files.

## Acceptance criteria → verification mapping

| # | Deliverable (from issue #5) | Verification (smallest credible) | Artifact |
|---|---|---|---|
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` in the iOS package; OpenAPI document vendored | Permanent unit tests over `iOS/Package.swift` + the vendored JSON (fail red today; machine-checkable, no server needed) | `OpenAPIArtifactTests.testPackageManifestWiresOpenAPIToolchain`, `testVendoredOpenAPIDocumentExists`, `testVendoredDocumentIsOpenAPI3` |
| AC-2 | Generated client covers the six surfaces the app uses | Permanent unit test pinning paths/methods/operationIds + schema coverage in the vendored spec; permanent stubbed-response tests per operation once generated | `OpenAPIArtifactTests.testVendoredSpecCoversSurfacesAppUses`, `testVendoredSpecDeclaresAppPayloadSchemas`; `GeneratedClientContractTests` (all methods) |
| AC-3 | Hand-written API models replaced with generated types; purely client-side models kept | Package wiring test (`ColorMatchingLPSAppCore` depends on `OpenAPIGeneratedCore`); review shows `MeasurementCore` models (RGB, ChannelStats, PatchMeasurement, PairScore, SheetAnalysis, …) untouched | `OpenAPIArtifactTests.testGeneratedTargetIsWiredIntoCoreAndTests` |
| AC-4 | Swift tests exercising the generated client against local stubbed responses (no live server in CI) | Permanent tests using a test `ClientTransport` stub with canned JSON per operation, incl. bearer-auth and 401 paths | `GeneratedClientContractTests` (transport stub, no network) |
| AC-5 | PR description records prose-contract vs published-spec deltas and endpoint gaps | This document is the evidence base; the implementation PR lifts the delta table below into its description | `docs/openapi-client-test-plan.md` (this file) |
| EXIT | `swift test --disable-sandbox` green with generated types wired in | CI (macOS) run of `swift test` in `iOS/` | `.github/workflows/ci.yml` job `test` |

Why structural (non-network) tests for AC-1/AC-2: for a codegen deliverable the
implementation *is* declarative (package manifest + vendored document). Asserting
on those artifacts makes drift visible as a failing test before any code is
generated, and they run on any host with the file present.

## Pinned implementation contract

The implementation run must satisfy exactly this shape (the structural tests
assert every point):

1. **Vendored document**: `iOS/OpenAPI/color-matching-openapi.json` — JSON
   (the server serves `openapi.json`), OpenAPI 3.x, fetched from a running
   `color_matching` (`GET /api/v1/openapi.json`) or reconstructed from the
   `open_api_spex` modules, with the normalizations in §3 below.
2. **Package**: `swift-openapi-generator` (plugin product `OpenAPIGenerator`) and
   `swift-openapi-runtime` (product `OpenAPIRuntime`, ≥ 1.8 so the HTTPTypes-based
   transport API used by the stubbed tests exists). A target
   `OpenAPIGeneratedCore` generated from the vendored document with
   `.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")`,
   wired as a dependency of `ColorMatchingLPSAppCore` **and**
   `ColorMatchingLPSAppTests` (the gated contract tests activate via
   `canImport(OpenAPIGeneratedCore)`).
3. **Vendoring normalizations** (all wire-compatible; record in the PR):
   - operationIds normalized to client-facing names (see table); the served
     spec derives them as `"<ControllerModule>.<action>"`.
   - `components.schemas.TestSheetManifest` extended to the manifest the server
     actually renders (`lps-sheet-manifest/v1`): all eleven top-level keys
     required (see delta M-1).
   - measurement/judgment array items lifted to named component schemas
     `MeasurementPayload` / `JudgmentPayload` (pure `$ref` extraction; gives the
     generated types stable addresses).

| Path | Method | operationId (pinned) | Generated method |
|---|---|---|---|
| `/api/v1/test_sheets/recent` | GET | `getRecentSheets` | `client.getRecentSheets` |
| `/api/v1/test_sheets/{sheet_id}/manifest` | GET | `getManifest` | `client.getManifest` |
| `/api/v1/test_sheets/{sheet_id}/ranked_results` | GET | `getRankedResults` | `client.getRankedResults` |
| `/api/v1/test_sheets/{sheet_id}/captures` | POST | `createCapture` | `client.createCapture` |
| `/api/v1/captures/{capture_id}/measurements` | POST | `uploadMeasurements` | `client.uploadMeasurements` |
| `/api/v1/captures/{capture_id}/judgments` | POST | `uploadJudgments` | `client.uploadJudgments` |

swift-openapi-generator uses the operationId verbatim as the method name
(e.g. `getGreeting` → `client.getGreeting(...)`), preserves JSON property names
verbatim (`schema_version` stays `schema_version`), and nests inline object
properties as `<Parent>.<Property>Payload` (e.g.
`Components.Schemas.CaptureRequest.QualityPayload`). The gated tests rely on
those conventions; if a generated name differs, fix the test alongside the
implementation in the same PR (the behavior being asserted is the contract, not
the spelling).

## Contract deltas: prose contract vs published spec

`docs/color-matching-api-contract.md` (prose) vs `viamin/color_matching@main`
open_api_spex modules. The implementation PR description must reproduce this
table (plus anything new discovered during vendoring).

### Response-shape drift the hand-written client gets wrong today

- **R-1 Uploads return counted JSON bodies, not empty 204s.**
  `CaptureController.upload_measurements` → `200`
  `{"capture_id", "measurement_count", "pair_score_count"}`
  (`MeasurementUploadResponse`, required all three) and
  `upload_judgments` → `200` `{"capture_id", "judgment_count"}`
  (`JudgmentUploadResponse`, required both). The prose contract documents no
  response body, and `APIClient.send` (iOS) treats any 2xx as success — the
  hand-written tests stub `204` with an empty body. The generated client makes
  the real response shape a compile-time fact
  (`GeneratedClientContractTests.test_uploadMeasurements_sendsSpecPayloadAndDecodesCountedResponse`).
- **R-2 Capture creation returns `201` with `{"capture_id": "<string>"}`** —
  matches prose; pinned by test. Note the id is a **string** (server renders
  `Integer.to_string(capture.id)`), and `/api/v1/captures/{capture_id}` expects
  the same string (server casts back to integer).

### Request-shape drift

- **Q-1 `CaptureRequest` accepts flat OR nested metadata** (`anyOf`: flat
  `{device_model, lens, …, rejection_reasons}` or `{metadata: …}`); the prose
  contract documents only the nested `{metadata, quality}` form. The generated
  client should keep sending the nested form (what the app sends today).
- **Q-2 `iso` is an integer in the spec** (`CaptureMetadata.iso`, `type:
  integer`, `exclusiveMinimum: 0`). The app's hand-written `CaptureMetadata.iso`
  is `Float?`. The generated type is `Int?`; the app-side wrapper must round or
  truncate when mapping.
- **Q-3 `RgbPayload` is `anyOf` [array `[r,g,b]` | object `{r,g,b}` | string]**;
  prose documents only the object form. The app sends the object form
  (`.value2`).
- **Q-4 `PairScoreRequest` requires `pair_id` + `algorithm_version` plus any one
  of `score`/`similarity`/`distance`.** Prose (and the app) send
  `similarity` + `distance` + `algorithm_version` — conforms.
- **Q-5 Top-level `scoring_algorithm_version` and per-measurement `stats`
  (`sample_count`, `clipping_fraction`, `mean`, `standard_deviation`) are NOT
  declared** in the spec's `MeasurementUploadRequest`, although the prose
  contract documents both and the app sends both today. The spec-typed client
  cannot send undeclared fields. Upstream decision needed (extend spec or accept
  the drop); until then the app's stats stay client-side (`MeasurementCore.ChannelStats`).
  Endpoint gap G-2.
- **Q-6 Judgment/rejection strings are unbounded** in the spec (plain
  `type: string`); the prose contract enumerates them
  (`match`/`near_match`/`no_match`; `missingRegistrationMarks`/…). No enum in
  spec → no generated Swift enums. Gap G-3.

### Manifest deltas

- **M-1 Spec manifest schema is far narrower than the rendered manifest.**
  `ApiSchemas.Manifest` only requires `schema_version`, `sheet_id`,
  `capture_profile` (with `scoring_algorithm_version` enum `["lps-distance-v1"]`),
  while `TestSheetJSON.manifest/1` always renders eleven top-level keys
  (adds `sheet_version`, `manifest_url`, `created_at`, `page`,
  `registration_markers`, `printer_profile`, `patches`, `pairs`). The app cannot
  function without the rendered fields (sheet analysis needs `patches`/`pairs`/
  `page`), so the vendored copy extends the schema to the rendered shape —
  flagged as upstream gap G-1.
- **M-2 Patch ids are composite `"{pair_id}#first|second"`**
  (`TestSheetJSON.patch_id/2`), not the prose example's `"patch_1"`. Treat ids
  as opaque strings.
- **M-3 `manifest_url` is server-relative** (`~p"/api/v1/test_sheets/…"` →
  `/api/v1/test_sheets/<code>/manifest`), not the absolute URL the prose example
  shows. The hand-written `RecentSheet.manifestURL: URL` / `SheetManifest.manifestURL: URL`
  decode a relative string into `URL` silently; the generated type is `String`
  and the app must resolve it against its base URL.
- **M-4 Recent sheets `title` is always `null` today**
  (`render_recent_sheet` hardcodes `title: nil`); spec marks it
  required-but-nullable. Matches prose's "title may be null".

### Ranked results deltas

- **K-1 Ranked-results schema is minimal**: spec requires only `schema_version`
  (enum `["lps-ranked-results/v1"]`) + `sheet_id`, while the renderer emits the
  full aggregate (`printer_profile`, `capture_count`,
  `latest/earliest_capture_at`, `scoring_algorithm_versions`, `results[]` with
  rank/score summaries/source colors/current judgment). The prose contract
  hand-waves this shape entirely. The app does not call this endpoint yet, so no
  local schema extension — recorded as gap G-2 instead.

### Spec metadata deltas

- **S-1 operationIds are Phoenix-internal** (`ColorMatchingWeb.TestSheetController.manifest`
  via `OperationBuilder.build_operation_id/3` default) — unusable as generated
  Swift method names. Normalized in the vendored copy; upstream follow-up:
  pass explicit `operation_id` in the controller specs.
- **S-2 Auth is `bearerAuth`** (`http`/`bearer`) on every app endpoint — matches
  the prose contract's bearer token.
- **S-3 The spec covers more than the app uses**: printer profiles, palettes,
  colors, metamer pairs, `/api/illuminant_measurements(+bulk)`,
  `/api/multi_image_mapping`. No iOS action needed (generation includes them;
  unused methods are inert).

## Endpoint gaps discovered (for the PR description)

- **G-1** Manifest schema under-specifies the rendered `lps-sheet-manifest/v1`
  payload (M-1) — vendored copy extends it; upstream should publish the full
  schema so the local patch can be dropped.
- **G-2** `MeasurementUploadRequest` omits `stats` and top-level
  `scoring_algorithm_version` (Q-5); `RankedResults` omits the aggregate fields
  (K-1) — upstream decisions needed.
- **G-3** No enums for judgment/rejection strings (Q-6) — validation is
  server-side only.

## Red-phase expectations

- `OpenAPIArtifactTests` (10 tests): **fail** until AC-1/AC-2/AC-3 artifacts
  exist. Expected failures demonstrating missing behavior — not infrastructure
  failures.
- `GeneratedClientContractTests` (8 tests): compiled out until
  `OpenAPIGeneratedCore` exists, then must pass against stubbed responses.
- Existing `APIClientTests`: still pass while the hand-written client remains;
  the implementation PR replaces them together with `APIClient.swift`.
- No Swift toolchain exists in the test-authoring container (Linux); execution
  happens on macOS CI via `swift test` (issue exit criteria:
  `swift test --disable-sandbox`).
