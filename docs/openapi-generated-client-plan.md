# OpenAPI Generated Client — Test Plan And Vendoring Contract

Tracks issue #5 ("Replace hand-written API layer with a generated OpenAPI Swift
client"). This document is the implementation contract for the tests added in
this PR and the evidence base for the contract deltas the PR description must
record. The published spec landed upstream via viamin/color_matching#113
(implementing viamin/color_matching#110): every `/api/v1` route is covered and
served at `GET /api/v1/openapi.json`.

## 1. Acceptance criteria → verification map

| AC | Verification | Where |
| ---- | ---- | ---- |
| Add `swift-openapi-generator` + `swift-openapi-runtime`; fetch or vendor the OpenAPI document | `unit_or_service_test` — vendored document must exist, be OpenAPI 3, declare `bearerAuth` | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIDocumentCoverageTests.swift` (all tests) |
| Generate the client for the six app surfaces (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results) | `unit_or_service_test` — document pins path + verb + stable `operationId` + typed request/response schemas for all six | `OpenAPIDocumentCoverageTests`; `GeneratedClientTests` |
| Replace hand-written API models with generated types | `unit_or_service_test` — stubbed-transport tests drive the generated `Client` and generated `Components.Schemas.*` payloads end to end | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` |
| Swift tests against local stubbed responses, no live server in CI | `unit_or_service_test` — `StubTransport` (a `ClientTransport`) returns canned JSON; zero network | `GeneratedClientTests.swift` |
| PR description records prose-contract vs published-spec deltas and endpoint gaps | `human_or_external_evidence` — delta table in §5 of this doc, written from the upstream sources cited there | this document |

### Red-phase status at this PR head

- `OpenAPIDocumentCoverageTests` compiles today (pure Foundation) and **fails**:
  `iOS/Sources/OpenAPIGenerated/openapi.json` does not exist yet. That is the
  expected red signal that the generation pipeline is missing.
- `GeneratedClientTests` is wrapped in
  `#if canImport(OpenAPIGenerated) && canImport(OpenAPIRuntime) && canImport(HTTPTypes)`
  so it compiles to nothing until the generated target exists; it is the
  green-phase contract for the implementation run. Ungating requires the test
  target to depend on those modules (see §2).
- Both files were validated off-tree with swift-openapi-generator 1.9.0,
  swift-openapi-runtime 1.9.0, and swift-http-types 1.8.0: all 19 tests pass
  when the generated client is built from
  `docs/openapi-vendored-reference.json`, and the coverage tests fail with a
  clear vendoring message when the document is absent.
- `APIClientTests` (hand-written client) stays green until the implementation
  run rewires `ColorMatchingLPSAppCore`; it must then be updated to cover the
  façade over the generated client rather than deleted silently.

## 2. Generation pipeline contract (for the implementation run)

1. `iOS/Package.swift` additions:
   - dependencies: `apple/swift-openapi-generator` (1.x) and
     `apple/swift-openapi-runtime` (1.x).
   - new target `OpenAPIGenerated` with
     `.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")`;
     its sources directory contains only the vendored document.
   - `ColorMatchingLPSAppCore` depends on `OpenAPIGenerated` +
     `OpenAPIRuntime`; `ColorMatchingLPSAppTests` depends on
     `OpenAPIGenerated` + `OpenAPIRuntime` so the `canImport` gates activate.
2. Vendored document: `iOS/Sources/OpenAPIGenerated/openapi.json` (JSON, not
   YAML: it is served as JSON upstream and parsed by the coverage tests with
   `JSONSerialization`, no YAML dependency needed).
3. Generation options (required, set in `openapi-generator-config.yaml` next
   to the document):
   - `accessModifier: public` — the default is `internal`, which makes the
     generated module unusable from the app and test targets.
   - `namingStrategy: idiomatic` — the default (`defensive`) preserves
     documented names verbatim, producing `schema_version` members and enum
     cases like `lps_hyphen_sheet_hyphen_manifest_sol_v1`; `idiomatic`
     produces `schemaVersion` / `.lpsSheetManifestV1`, which is what
     `GeneratedClientTests` asserts against.
4. Vendoring procedure ("fetch, then overlay"):
   1. `curl http://localhost:4000/api/v1/openapi.json` from a running
      `color_matching` (dev allows unauthenticated access to this route).
   2. Apply the overlay in §3 (rewrite `operationId`s, extend the under-
      documented schemas). Record the upstream commit hash fetched from in a
      top-level `x-upstream-commit` extension so drift reviews have a base.
   3. `swift build` regenerates the client; the regeneration diff is the
      drift signal.
5. Bearer auth: add a small `ClientMiddleware` in `ColorMatchingLPSAppCore`
   that sets `Authorization: Bearer <token>`; the generated client does not
   implement security schemes itself. The published spec declares
   `components.securitySchemes.bearerAuth` (type `http`, scheme `bearer`).
6. App wiring: `ColorMatchingLPSAppCore` keeps a thin façade over the
   generated `Client` so SwiftUI code and `MeasurementCore` stay unchanged;
   hand-written API models in `APIClient.swift` are deleted in favor of
   generated types plus mapping into `MeasurementCore.SheetManifest` (a
   purely client-side domain model that stays hand-written). `MeasurementCore`
   geometry types (`RGB`, `Rect`, …) are client-side and stay as-is.

A complete, validated reference copy of the vendored document lives at
`docs/openapi-vendored-reference.json`. It was authored exactly per §3 and
verified in this test-writing run: swift-openapi-generator 1.9.0 (with
`--access-modifier public --naming-strategy idiomatic`) accepts it, and all
tests in this PR compile and pass against its generated client plus
swift-openapi-runtime 1.9.0 / swift-http-types 1.8.0 (Linux aarch64). The
implementation run can start from that copy and re-fetch from upstream when
regenerating.

## 3. Vendored document pins (what the coverage tests enforce)

### 3.1 Operations and operationIds

`swift-openapi-generator` derives the Swift method name from `operationId`
(sanitized, camelCased). Upstream's `open_api_spex` defaults operationIds to
`"ColorMatchingWeb.TestSheetController.manifest"` style, which produces
unusable Swift names, so the overlay rewrites them:

| Path | Verb | operationId | Generated method |
| ---- | ---- | ---- | ---- |
| `/api/v1/test_sheets/{sheet_id}/manifest` | get | `getTestSheetManifest` | `client.getTestSheetManifest(...)` |
| `/api/v1/test_sheets/recent` | get | `listRecentTestSheets` | `client.listRecentTestSheets()` |
| `/api/v1/test_sheets/{sheet_id}/ranked_results` | get | `getRankedResults` | `client.getRankedResults(...)` |
| `/api/v1/test_sheets/{sheet_id}/captures` | post | `createCapture` | `client.createCapture(...)` |
| `/api/v1/captures/{capture_id}/measurements` | post | `uploadMeasurements` | `client.uploadMeasurements(...)` |
| `/api/v1/captures/{capture_id}/judgments` | post | `uploadJudgments` | `client.uploadJudgments(...)` |

Path parameters `sheet_id` / `capture_id` stay snake_case in the document
(they generate `sheetId` / `captureId` in Swift). Other upstream operations
(printer_profiles, palettes, colors, metamer_pairs, illuminant_measurements,
multi_image_mapping, openapi.json) may remain in the document untouched.

### 3.2 Component schemas (property order matters — it drives generated memberwise-init parameter order)

- `TestSheetManifest` (required: `schema_version`, `sheet_id`,
  `sheet_version`, `manifest_url`, `page`, `registration_markers`,
  `printer_profile`, `capture_profile`, `patches`, `pairs`; optional:
  `created_at`):
  - `schema_version`: string enum containing `lps-sheet-manifest/v1`
    (generates `schemaVersion` enum case `.lpsSheetManifestV1`).
  - `capture_profile.scoring_algorithm_version`: string enum containing
    `lps-distance-v1` (case `.lpsDistanceV1`).
  - `page`: required `units`, `width`, `height`.
  - `registration_markers[]`: `role`, `shape`, `rect` required.
  - `patches[]`: `id`, `role`, `safe_inset_mm`, `rect` required;
    `pair_id`, `pair_side`, `reference_role`, `source_color` optional and
    nullable (generates optionals).
  - `rect`: `x`, `y`, `width`, `height` required, numbers.
  - `pairs[]`: `id`, `first_patch_id`, `second_patch_id`, `source_colors`,
    `grid_row`, `grid_col` all required.
  - `printer_profile` (runtime shape, not the stale prose shape):
    `printer_make_model`, `paper_type`, `ink_type` required; `icc_profile`,
    `print_settings`, `driver_name`, `driver_version`, `calibration_date`,
    `calibration_version`, `notes` optional/nullable.
- `CaptureRequest`: object with required `metadata` (`$ref` to
  `CaptureMetadata`) then `quality` (`detected_marker_count`,
  `blur_score`, `rejections[]` of plain strings). The upstream `anyOf`
  (flat form | nested form) is narrowed to the nested form the app sends.
- `CaptureMetadata`: required `device_model`, `lens`, `image_width`,
  `image_height`, `app_version`, `timestamp`; optional
  `exposure_duration_seconds` (number), `iso` (integer), 
  `focus_lens_position` (number), `white_balance_gains`
  ({`r`,`g`,`b`} numbers). `timestamp` is `format: date-time` (generates
  `Date`, RFC 3339 encoded).
- `CaptureCreatedResponse` (201): required `capture_id`.
- `MeasurementUploadRequest`: property order `scoring_algorithm_version`,
  `measurements`, `pair_scores`; measurement items: `patch_id`,
  `linear_rgb_median`, `normalized_linear_rgb_median` (all required; RGB as
  plain `{r, g, b}` number objects — the upstream `RgbPayload`
  anyOf(array|object|string) is narrowed to the object form the app sends),
  `stats` (required: `sample_count`, `clipping_fraction`, `mean`,
  `standard_deviation`); pair_scores items: `pair_id`, `distance`,
  `similarity`, `algorithm_version` all required (upstream anyOf
  score|similarity|distance narrowed to distance+similarity).
- `MeasurementUploadResponse` (200): required `capture_id`,
  `measurement_count`, `pair_score_count`.
- `JudgmentUploadRequest`: required `judgments` array of
  {`pair_id`, `judgment`} plain strings.
- `JudgmentUploadResponse` (200): required `capture_id`, `judgment_count`.
- `RecentSheetsResponse`: `sheets[]` items required `sheet_id`,
  `manifest_url`, `title` with `title` marked `nullable: true` (present but
  null when unnamed).
- `RankedResults`: required `schema_version` (enum containing
  `lps-ranked-results/v1`), `sheet_id`, `results`; `results[]` items
  required `rank`, `pair_id`, `source_colors` (`color_a_hex`,
  `color_b_hex`), `score` (`average`, `latest`, `minimum`, `maximum`,
  `capture_count`, `sample_count`, `algorithm_versions`); optional
  `current_judgment`, `latest_observation`, `observation_count`, `row`,
  `col`, `scoring_algorithm_version`, `capture_count`, printer_profile and
  capture timestamps; other wrapper fields optional.
- `ApiErrorResponse`: keep upstream shape (`errors`), used for 401/404/422
  cases the generated client surfaces as `.unauthorized` / `.notFound` /
  `.unprocessableContent`.

Status codes: capture creation documents 201 (plus 401/404/422); measurement
and judgment uploads document 200 with JSON bodies (no 204); reads document
200 (plus 401, and 404 where applicable).

## 4. What the generated tests exercise

`GeneratedClientTests` (activates with the generated target):

- `getTestSheetManifest` decodes a full stubbed manifest (schema enums, patch
  and pair arrays, capture profile scoring enum, printer profile) and asserts
  the outgoing request path/method; a 404 stub surfaces as `.notFound`.
- `listRecentTestSheets` decodes `title: null` as nil and a real title.
- `createCapture` posts nested `{metadata, quality}` JSON with snake_case
  keys, integer `iso`, RFC 3339 `timestamp`, and decodes 201 `capture_id`.
- `uploadMeasurements` encodes stats + scores and decodes the 200 acceptance
  body (`measurement_count`, `pair_score_count`).
- `uploadJudgments` encodes labels and decodes the 200 acceptance body.
- `getRankedResults` decodes the ranked results array including
  `current_judgment` and score aggregates.

All responses come from `StubTransport`, a `ClientTransport` implementation —
no live server, matching the "no live server in CI" requirement.

## 5. Contract deltas: prose contract vs published spec vs runtime

Written from `docs/color-matching-api-contract.md` (prose),
`viamin/color_matching` `lib/color_matching_web/api_schemas.ex` (published
spec schemas), `lib/color_matching_web/controllers/*.ex` (status codes), and
`lib/color_matching_web/controllers/test_sheet_json.ex` (actual response
bodies). This table is the PR-description evidence for the "what changed /
endpoint gaps" deliverable.

1. **Upload responses are typed 200 JSON bodies, not 204.** Prose contract
   (and the current hand-written `APIClient`) assume empty 204 responses for
   measurements/judgments. The real API returns 200 with
   `{capture_id, measurement_count, pair_score_count}` and
   `{capture_id, judgment_count}`. With the generated client this becomes a
   compile-time-visible difference (the old stubs' 204s no longer type-check).
2. **Manifest spec under-documents the manifest.** The published
   `TestSheetManifest` schema only requires `schema_version`, `sheet_id`,
   `capture_profile.scoring_algorithm_version`. The runtime renderer emits the
   full prose shape (page, registration_markers, printer_profile, patches,
   pairs, sheet_version, manifest_url, created_at). The vendored overlay
   documents the runtime shape; upstream should adopt it (follow-up issue).
3. **`printer_profile` differs in all three sources.** Prose: `{id, name,
   paper, ink, settings}`. Published component `PrinterProfile`: `{id:
   integer, printer_make_model, paper_type, ink_type}` (and it is not even
   referenced by the manifest schema). Runtime manifest payload:
   `{printer_make_model, paper_type, ink_type, icc_profile, print_settings,
   driver_name, driver_version, calibration_date, calibration_version,
   notes}` — no `id` at all. The overlay pins the runtime shape.
4. **No reference patches exist at runtime.** Prose contract documents patch
   role `reference` with reference roles white/gray/black/blank_paper, and
   `MeasurementCore.Normalizer` depends on reference patches. The runtime
   manifest renderer emits only `pair_color` patches (two per pair). Endpoint
   gap: until the Phoenix app renders reference patches, normalization has no
   server-side reference input. The overlay keeps the fields optional so the
   client is ready.
5. **Patch IDs use `pair_id#side`.** Runtime `patch_id` is
   `"#{pair_id}#first"` / `"#{pair_id}#second"`, not the prose example's
   `patch_1`. Opaque strings; tests use the runtime form.
6. **`manifest_url` is relative.** Runtime renders `/api/v1/test_sheets/…`
   via Phoenix VerifiedRoutes — not the absolute URL shown in prose. The
   generated model types it as a plain string; the app must resolve it
   against its base URL instead of `URL(string:)`-decoding it as absolute.
7. **Recent sheets: `title` always null today** (renderer hardcodes `nil`),
   but the schema requires the key and marks it nullable. Prose is correct
   that `title` may be null; the delta is only that it is currently *always*
   null.
8. **Measurement upload schema drift.** Published spec has no top-level
   `scoring_algorithm_version`, no `stats` block, and *requires*
   `normalized_linear_rgb_median` per measurement (the app's hand-written
   model treats it as optional and may omit it). The server tolerates extra
   keys (stats, scoring_algorithm_version) — the overlay documents them as
   required-for-the-client. The app must always upload normalized medians
   (fall back to the raw median when normalization is unavailable).
9. **RGB payload polymorphism.** Published `RgbPayload` is
   anyOf(array-of-number | {r,g,b} object | string). The app sends only the
   object form; the overlay narrows the client schema to `{r, g, b}` numbers.
10. **Pair score shape.** Published `PairScoreRequest` requires
    `pair_id` + `algorithm_version` plus anyOf(`score` | `similarity` |
    `distance`). Prose/app send `pair_id`, `distance`, `similarity`,
    `algorithm_version`. Overlay pins that exact form.
11. **Capture request accepts two shapes.** Published `CaptureRequest` is
    anyOf(flat metadata at top level | nested `{metadata, quality}`). The app
    sends the nested form; overlay pins nested-only for the client. Capture
    metadata required set is documented server-side (`device_model`, `lens`,
    `image_width`, `image_height`, `app_version`, `timestamp`) — prose did
    not state requiredness.
12. **`iso` is an integer in the spec.** The hand-written `CaptureMetadata`
    uses `Float` for `iso`; the spec says integer. The app should send `Int`.
13. **Ranked results spec under-documents the payload.** Published
    `RankedResults` schema documents only `schema_version` (enum
    `lps-ranked-results/v1`) + `sheet_id`; the runtime response includes the
    full ranked pairs array with scores, judgments, observation counts, and
    capture provenance. Overlay documents `results` (the app's surface).
14. **OperationIds.** Upstream defaults to `ColorMatchingWeb.*` style;
    overlay rewrites to stable client-friendly ids (§3.1).
15. **Auth matches prose.** `bearerAuth` (http/bearer) is declared and the
    app routes sit behind `ApiAuth`; `/api/v1/openapi.json` itself is
    unauthenticated. No delta.
16. **Endpoints in the spec the app does not use** (printer_profiles,
    palettes, colors, metamer_pairs, `/api/illuminant_measurements(+/bulk)`,
    `/api/multi_image_mapping`): retained in the vendored document; no client
    coverage needed this PR. Noted as future surfaces.

## 6. Follow-ups (out of scope for #5)

- Push the §5 deltas upstream: manifest/ranked-results full schemas,
  reference patches in rendered manifests, friendly operationIds
  (`operation_id:` in `operation` macros) so the overlay can shrink to none.
- Revisit Pact only if drift keeps biting after generated clients exist
  (issue non-goal).
