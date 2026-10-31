# OpenAPI Generated Client Migration (issue #5)

Status: test-writing phase (red). This document maps acceptance criteria to
verification and records the contract deltas found between
`docs/color-matching-api-contract.md` (prose) and the published OpenAPI 3 spec
from `viamin/color_matching` (issue #110, shipped as PR #113, served at
`GET /api/v1/openapi.json`). The PR description for the implementation change
should carry the delta table below verbatim.

## Acceptance criteria mapping

| AC | Verification | Locator |
| ---- | ---- | ---- |
| Add `swift-openapi-generator` + `swift-openapi-runtime`; vendor the OpenAPI document | Focused unit tests asserting `Package.swift` wiring and the vendored JSON document (red now, green after implementation) | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIPackageWiringTests.swift`, `iOS/Tests/ColorMatchingLPSAppTests/VendoredOpenAPISpecTests.swift` |
| Generate the client for the surfaces the app uses (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results) | Spec-coverage tests pin the six path/method pairs, per-operation success status + JSON body + bearer security, and the payload schema titles and shapes (red now) | `VendoredOpenAPISpecTests.testVendoredSpecCoversEveryAppSurface`, `VendoredOpenAPISpecTests.testEveryAppOperationDeclaresSpecSuccessStatusWithJSONBody`, `VendoredOpenAPISpecTests.testUploadOperationsDeclareJSONRequestBody`, `VendoredOpenAPISpecTests.testEveryAppOperationRequiresBearerAuth`, `VendoredOpenAPISchemaTests` |
| Replace hand-written API models with generated types; keep client-only models | Stubbed-response tests pin the app-facing wire format through `APIClient` so the swap cannot change payloads unnoticed (green now, must stay green). Stub fixtures use the spec's real response shapes — 201 + numeric-string `capture_id` for capture creation, 200 + count bodies for uploads — so they stay valid when the generated client decodes those bodies | `iOS/Tests/ColorMatchingLPSAppTests/APIClientContractTests.swift`, `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Swift tests exercising the generated client against stubbed responses, no live server in CI | `ContractStubURLProtocol` (URLProtocol stub) serves fixtures; no network in tests | `iOS/Tests/ColorMatchingLPSAppTests/TestSupport/ContractStubURLProtocol.swift` |
| PR description records contract deltas and endpoint gaps | Delta table below, re-verified this run against upstream `api_schemas.ex`, `capture_controller.ex`, `test_sheet_controller.ex`, `router.ex` at `viamin/color_matching` main (PR #113) | This document; upstream sources cited per row |

Vendored-document contract enforced by the tests: a JSON OpenAPI 3 document at
`iOS/OpenAPI/color-matching-openapi.json` (or `openapi.json`, either there or
inside a target directory under `iOS/Sources/`), fetched from the upstream
`/api/v1/openapi.json`. JSON is required so regeneration is a reviewable diff.

## Contract deltas: prose contract vs published spec

Verified against `viamin/color_matching` main (PR #113):

1. Manifest schema is under-specified. The spec (`TestSheetManifest`) requires
   only `schema_version` (enum `lps-sheet-manifest/v1`), `sheet_id`, and
   `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`). The
   geometry fields the iOS app decodes — `sheet_version`, `manifest_url`,
   `created_at`, `page`, `registration_markers`, `printer_profile`,
   `capture_profile.expected_illuminant`/`preferred_camera`, `patches`,
   `pairs` — are served at runtime but absent from the machine-readable spec.
   Consequence: generated types cannot cover sheet geometry; the client-side
   `MeasurementCore` manifest models stay hand-maintained until upstream
   expands the schema (upstream follow-up recommended).
2. Ranked results. The prose contract documented no response schema at all.
   The spec adds `RankedResults` with `schema_version` enum
   `lps-ranked-results/v1` + `sheet_id` only. Endpoint gap: the ranked
   pairs/scores/labels/capture provenance the issue text expects are not yet
   machine-visible.
3. Measurement upload request. Spec omits the prose contract's top-level
   `scoring_algorithm_version`; `MeasurementUploadRequest` declares
   `measurements` + `pair_scores` properties with no top-level `required`
   list. Each `pair_scores` item (`PairScoreRequest`) requires `pair_id` +
   `algorithm_version` and one of `score`/`similarity`/`distance`.
   `normalized_linear_rgb_median` is required per measurement (optional in
   prose). The prose `stats` block (`sample_count`, `clipping_fraction`,
   `mean`, `standard_deviation`) is not in the spec; the app currently uploads
   it — undocumented extra field, drift risk to raise upstream.
   `linear_rgb_median` is `RgbPayload` (anyOf: `[r,g,b]` array, `{r,g,b}`
   object, or string), looser than prose's fixed object.
4. Upload responses now have bodies. Prose assumed empty `204` responses.
   The spec declares `200` with
   `MeasurementUploadResponse {capture_id, measurement_count, pair_score_count}`
   and `JudgmentUploadResponse {capture_id, judgment_count}` (all required;
   `capture_controller.ex` renders `Integer.to_string(capture_id)` plus row
   counts). The generated client will decode these bodies; `APIClientTests`
   stubs now serve those 200 bodies.
5. Capture creation. Spec `CaptureRequest` accepts a flat legacy shape or the
   prose's nested `{metadata, quality}` via `anyOf` (a branch requiring only
   `[:metadata]`; the nested `quality` object itself has no required fields).
   Response is `201` `CaptureCreatedResponse {capture_id}` where `capture_id`
   is the numeric record ID as a string (`capture_controller.ex`:
   `Integer.to_string(capture.id)`; prose example showed `capture_123`). The
   subsequent upload paths must use that numeric-string capture id, and the
   controller rejects non-integer capture ids with `404`.
6. Rejection and judgment enums are not machine-visible. Prose enumerates
   capture rejection strings (`missingRegistrationMarks`, ...) and judgments
   (`match`, `near_match`, `no_match`); the spec types both as free-form
   strings.
7. Recent sheets matches prose (`sheets[{sheet_id, manifest_url, title}]`,
   `title` required-but-nullable, limit 20 upstream).
8. Auth matches prose: `bearerAuth` (HTTP bearer) security scheme is declared
   in components and applied per-operation (`security [%{"bearerAuth" => []}]`
   on both controllers), so every generated client call carries it.

## Endpoint gaps discovered (spec contains, prose does not)

- `GET /api/v1/openapi.json` (the spec itself)
- `GET /api/v1/printer_profiles`, `.../colors`, `.../metamer_pairs`
- `GET /api/v1/palettes`, `GET /api/v1/colors`
- `POST /api/illuminant_measurements`, `POST /api/illuminant_measurements/bulk`
- `POST /api/multi_image_mapping` (macOS-client surface)

None of these are consumed by the iOS app today; they are out of scope for the
generated client surfaces but explain spec size.

## Red-phase status (this commit)

- Red (expected failures driving the implementation run): every test in
  `VendoredOpenAPISpecTests` (document presence, OpenAPI 3, six-surface
  coverage, per-operation success status + JSON body, JSON request bodies,
  per-operation bearer security), every test in `VendoredOpenAPISchemaTests`
  (schema titles, compatibility enums, required-field pins, upload response
  bodies, nested capture shape, RgbPayload anyOf, pair-score shape, nullable
  recent-sheets title), and `OpenAPIPackageWiringTests` — the spec is not
  vendored and the package is not wired yet.
- Green and load-bearing: `APIClientContractTests` pins the manifest and
  recent-sheets wire format via stubbed responses with no live server;
  `APIClientTests` pins capture-creation and upload wire format. Its stub
  fixtures were updated this run to the published spec's response shapes
  (201 + numeric-string `capture_id`; 200 + `MeasurementUploadResponse` /
  `JudgmentUploadResponse` count bodies), so the same fixtures exercise the
  generated client once it replaces the hand-written one — no live server at
  any point.
- Not expressible until the generated module exists: a compile-safe client-call
  test for `GET /test_sheets/{sheet_id}/ranked_results` (no method to call).
  Its spec coverage is enforced now; the call test lands with the
  implementation.

## Verification commands

CI (macOS): `swift test --disable-sandbox` from `iOS/`. The current container
has no Swift toolchain, so this must be exercised in CI or the implementation
run; that limitation is recorded in the run evidence JSON.
