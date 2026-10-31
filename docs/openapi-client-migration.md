---
module: iOS companion API layer
tags: [openapi, code-generation, api-contract, testing]
problem_type: solution
---

# OpenAPI Generated Client Migration (issue #5)

Status: **red-phase tests committed.** The tests in
`iOS/Tests/ColorMatchingLPSAppTests/OpenAPISpecVendoringTests.swift` and
`iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` define the contract
for the implementation run. They currently fail by design because the generated
client and the vendored spec do not exist yet.

Upstream dependency is resolved: `viamin/color_matching#110` is merged and serves
the machine-readable spec at `GET /api/v1/openapi.json` (open_api_spex, OpenAPI 3).

## Test-defined implementation contract

The implementation run must satisfy:

- Vendor the published document verbatim at `iOS/OpenAPI/color-matching.json`
  (JSON, not YAML — it is a byte-faithful dump of `GET /api/v1/openapi.json`).
  Operation IDs stay exactly as published (`ColorMatchingWeb.TestSheetController.manifest`,
  …). Renaming them would erase the "regeneration diff = server drift" property.
- `iOS/Package.swift` declares dependencies on `swift-openapi-generator` (with the
  `OpenAPIGenerator` plugin), `swift-openapi-runtime`, and `swift-openapi-urlsession`,
  and defines a target/product named `ColorMatchingOpenAPI` generated from the
  vendored document.
- The `ColorMatchingLPSAppTests` test target gains dependencies on
  `ColorMatchingOpenAPI` and `OpenAPIURLSession` so
  `#if canImport(ColorMatchingOpenAPI)` activates `GeneratedClientTests`.
- Generated client method names follow from the sanitized operation IDs
  (`ColorMatchingWeb_TestSheetController_manifest`, …) because
  swift-openapi-generator replaces `.` with `_` in member names.
- Memberwise-init argument order in `GeneratedClientTests` follows the vendored
  document's property order (a Jason dump orders atom keys alphabetically), which
  is the order swift-openapi-generator preserves.

If the verbatim spec fails to generate (see "Gaps" below), the implementation run
may apply the minimal documented transformation to the vendored document and must
record the transformation in the PR description; the operation IDs must remain
untouched.

## Contract deltas: prose contract vs published spec

Recorded against `docs/color-matching-api-contract.md` and upstream `main`
(`lib/color_matching_web/api_schemas.ex`, router, controllers). Each row is pinned
by a test in `OpenAPISpecVendoringTests.swift` so future re-vendoring makes drift
loud.

| Surface | Prose contract | Published spec |
| --- | --- | --- |
| Manifest response | Rich manifest: `page`, `patches`, `pairs`, `registration_markers`, `printer_profile`, `sheet_version`, `manifest_url`, `created_at` | `TestSheetManifest` requires only `schema_version` (enum `lps-sheet-manifest/v1`), `sheet_id`, `capture_profile.scoring_algorithm_version` (enum `lps-distance-v1`). The geometry/patch/pair fields the app needs are **undocumented** |
| Recent sheets | `title` may be `null` | Same, but `title` is required **and** nullable; `sheets` required |
| Capture request | Nested `{metadata, quality}` only | `anyOf`: nested `{metadata, quality}` **or** flat legacy shape. Flat uses `exposure_duration` (prose: `exposure_duration_seconds` inside metadata) and `rejection_reasons` (prose: `quality.rejections`). `CaptureMetadata` required: `device_model`, `lens`, `image_width`, `image_height`, `app_version`, `timestamp` |
| Capture response | `{"capture_id": ...}` (201) | Same: `CaptureCreatedResponse` = `capture_id`, status 201 |
| Measurement upload request | Top-level `scoring_algorithm_version`, per-measurement `stats` (sample_count, clipping_fraction, mean, standard_deviation), optional `normalized_linear_rgb_median`, RGB as `{r,g,b}` object only | No top-level `scoring_algorithm_version`, no per-measurement `stats`; `normalized_linear_rgb_median` is **required** on every item; `RgbPayload` is `anyOf` array/object/string; `PairScoreRequest` requires `pair_id` + `algorithm_version` and `anyOf` score/similarity/distance |
| Measurement upload response | None documented (app tolerated 204) | `MeasurementUploadResponse` `capture_id`/`measurement_count`/`pair_score_count`, status 200 |
| Judgment upload response | None documented (app tolerated 204) | `JudgmentUploadResponse` `capture_id`/`judgment_count`, status 200 |
| Ranked results | "source colors, scores, labels, capture provenance, printer profile, scoring algorithm version" | `RankedResults` documents only `schema_version` (enum `lps-ranked-results/v1` — a version string absent from the prose doc) and `sheet_id`. No scores/labels/provenance fields at all |
| Auth | Bearer token | `bearerAuth` security scheme on all app-facing operations |
| Endpoints | Six app surfaces | Spec also documents `/api/v1/palettes`, `/api/v1/colors`, `/api/v1/printer_profiles(…/colors, …/metamer_pairs)`, `/api/illuminant_measurements(/bulk)`, `/api/multi_image_mapping` — coverage beyond the prose contract |

## Endpoint gaps discovered (for the PR description)

1. **Manifest geometry is unspecified.** The fields driving sampling
   (`page`, `patches`, `pairs`, `registration_markers`) are absent from
   `TestSheetManifest`, so the generated client types cannot see them. The app
   must keep decoding those fields leniently (or upstream must expand the schema)
   until the spec covers them.
2. **`CaptureRequest` anyOf degrades in generated clients.** The schema mixes
   sibling `properties` with `anyOf` branches that are `required`-only fragments.
   swift-openapi-generator keys off `anyOf` and drops sibling properties, and the
   fragment branches produce empty payload structs — the generated type cannot
   carry `metadata`/`quality`. Consequence: `GeneratedClientTests` exercises
   capture creation without a request body (the published `requestBody` is
   optional) and pins the wire path/status/decode only. Upstream should model the
   two shapes as real object branches.
3. **`PairScoreRequest` has the same anyOf degradation** — `pair_id`/`distance`
   cannot be populated through generated types, so measurement-upload tests omit
   `pair_scores` and the app should keep uploading scores via the fields the
   runtime converter accepts until upstream fixes the shape.
4. **Uploads now return JSON bodies (200), not empty 204s.** The hand-written
   `APIClient.send()` ignores bodies; generated types make the counts visible.
5. **`RgbPayload` accepts array/object/string forms.** The prose contract only
   documents the object form; the app may send either (tests pin the array form).
6. **`normalized_linear_rgb_median` is required per measurement** in the spec but
   optional in the app's hand-written model — the app must always populate it
   (normalization already computes it).
7. **Dropped fields:** top-level `scoring_algorithm_version` and per-measurement
   `stats` are not in the published measurement-upload schema. Whether the server
   persists them when present is an upstream question; the PR must call this out.

## Acceptance criteria → verification mapping

| Criterion (issue #5) | Verification | Evidence |
| --- | --- | --- |
| Add generator/runtime to package; vendor the spec | Permanent unit test | `OpenAPISpecVendoringTests.testPackageManifestDeclaresGeneratedClientWiring`, `testVendoredSpecParsesAsOpenAPIDocument` |
| Generate client for the six app surfaces | Permanent unit tests | `testVendoredSpecDocumentsAppSurfacesWithUpstreamOperationIDs`; `GeneratedClientTests` (all seven tests) |
| Replace hand-written API models with generated types | Unit tests + implementation-run compile | `GeneratedClientTests` exercises generated types; model replacement itself lands in the implementation run and is verified by `swift test --disable-sandbox` in CI |
| Swift tests against local stubbed responses | Permanent unit tests | `GeneratedClientTests` stubs `URLProtocol`; no live server needed |
| PR description records contract deltas and endpoint gaps | Human/external evidence | This document's delta table and gap list feed the PR description verbatim |

Exit criterion `swift test --disable-sandbox` green: evaluated in CI (macOS); this
container has no Swift toolchain, so the red suite was not executed locally.
