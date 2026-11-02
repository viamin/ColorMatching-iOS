# iOS Generated OpenAPI Client — Plan, Contract Deltas, and Verification Map

Status: tests-first (red phase) for issue #5
("Replace hand-written API layer with a generated OpenAPI Swift client").

This document records (1) the pinned implementation decisions the new tests
encode, (2) the deltas found between `docs/color-matching-api-contract.md`
(the prose contract) and the real API as published by viamin/color_matching#110,
and (3) the acceptance-criterion → verification mapping. The implementation
PR's description should carry §2 forward as its contract-delta record.

Upstream evidence inspected (viamin/color_matching @ `main`, 2026-11-02):

- `lib/color_matching_web/router.ex` — routes and the spec endpoint
- `lib/color_matching_web/api_spec.ex` — OpenAPI document assembly
- `lib/color_matching_web/api_schemas.ex` — declared schemas
- `lib/color_matching_web/controllers/test_sheet_controller.ex`,
  `capture_controller.ex`, `test_sheet_json.ex` — operations and rendered payloads

## 1. Pinned decisions (encoded by the new tests)

| Decision | Value | Enforced by |
| --- | --- | --- |
| Spec source | `GET /api/v1/openapi.json` on the Phoenix app (upstream serves JSON; OpenAPI `3.0.0` per OpenApiSpex defaults, which is the version `swift-openapi-generator` supports) | `OpenAPIContractTests.testVendoredOpenAPIDocumentExistsAndIsOpenAPI30` |
| Vendored spec path | `iOS/Sources/ColorMatchingOpenAPI/OpenAPI/openapi.json` (canonical `apple/swift-openapi-generator` target layout; JSON keeps the document test-parseable with Foundation alone) | same test |
| Generated target name | `ColorMatchingOpenAPI` (plugin `OpenAPIGenerator` from `swift-openapi-generator`, runtime product `OpenAPIRuntime` from `swift-openapi-runtime`), consumed by `ColorMatchingLPSAppCore` | `OpenAPIContractTests.testPackageManifestWiresGeneratedOpenAPIClient` |
| Generated surfaces | manifest, recent sheets, ranked results, capture creation, measurement upload, judgment upload (paths + methods + success statuses below) | `testVendoredSpecCoversEverySurfaceTheAppUses` |
| Auth | `http`/`bearer` security scheme required on every generated surface | `testVendoredSpecRequiresBearerAuthOnEveryAppSurface` |
| Wire parity | The `APIClient` facade keeps today's method, path, auth header, and decoded client-side models (`SheetManifest`, `RecentSheet`, …) so the swap changes transport, not behavior | `APIClientSurfaceTests` + existing `APIClientTests` |

Paths and success statuses the app relies on:

- `GET /api/v1/test_sheets/{sheet_id}/manifest` → 200
- `GET /api/v1/test_sheets/recent` → 200
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results` → 200
- `POST /api/v1/test_sheets/{sheet_id}/captures` → 201
- `POST /api/v1/captures/{capture_id}/measurements` → 200
- `POST /api/v1/captures/{capture_id}/judgments` → 200

## 2. Contract deltas: prose contract vs published spec

The published spec (OpenApiSpex, derived from the router + controller specs)
declares correct paths and auth, but **under-declares several payloads the app
depends on**, and the runtime renders richer JSON than the spec describes.
Concretely:

1. **Manifest response schema is under-declared.** The spec's
   `TestSheetManifest` declares only `schema_version`, `sheet_id`, and
   `capture_profile.scoring_algorithm_version` (required). The prose contract —
   and the actual runtime rendering (`TestSheetJSON.manifest/1`) — carry
   `sheet_version`, `manifest_url`, `created_at`, `page`,
   `registration_markers`, `printer_profile`, `capture_profile` (three keys),
   `patches[]`, and `pairs[]`. Generated types from the unpatched spec would
   model almost none of what the iOS app decodes.
2. **Ranked results response schema is under-declared.** The spec declares only
   `schema_version` and `sheet_id`; the runtime emits per-pair `rank`,
   `pair_id`, `source_colors`, `score` (average/latest/min/max/capture_count/
   sample_count/algorithm_versions), `current_judgment`, observation counts,
   capture provenance, `printer_profile`, and `scoring_algorithm_versions`.
3. **Measurement upload request omits fields the app sends.** The spec's
   `MeasurementUploadRequest` has no top-level `scoring_algorithm_version` and
   no per-measurement `stats` (`sample_count`, `clipping_fraction`, `mean`,
   `standard_deviation`); the prose contract documents both and the app sends
   both today. The spec also makes `normalized_linear_rgb_median` required on
   every row while the prose/app treat it as optional, and types
   `linear_rgb_median` as `RgbPayload` (anyOf: `[r,g,b]` array | `{r,g,b}`
   object | string) whereas the prose fixes the object form.
   `CaptureController` runs no `CastAndValidate`, so extra fields are tolerated
   server-side; keeping wire parity is therefore safe.
4. **Uploads now return JSON bodies.** Measurement upload responds
   `200 {"capture_id","measurement_count","pair_score_count"}` and judgment
   upload `200 {"capture_id","judgment_count"}`; the prose contract specified
   no response payloads. The app currently treats any 2xx as success and can
   adopt the counts later.
5. **Capture creation**: responds `201` with `capture_id` as the **string of an
   integer DB id** (prose example showed an opaque id); the request accepts
   either the app's nested `{metadata, quality}` shape or a flattened variant
   (`exposure_duration` — not `exposure_duration_seconds` — plus
   `rejection_reasons` instead of `quality.rejections` in the flat form).
   `iso` and image dimensions are typed `integer` (the app's `Float` metadata
   must encode integrally); `white_balance_gains` is free-form.
6. **Recent sheets**: matches the prose contract, including nullable `title`
   (runtime currently always renders `title: null`).
7. **Patch IDs are structured.** Runtime manifest patch ids are
   `"<pair_id>#first"` / `"<pair_id>#second"`, not the prose example's
   `patch_1`; the iOS `SheetAnalyzer` already consumes them opaquely.
8. **The spec covers more than the app uses**: `printer_profiles`, `palettes`,
   `colors`, `metamer_pairs` (GET), `illuminant_measurements` (+ `/bulk`),
   `multi_image_mapping`, and `openapi.json` itself. The generated client will
   include them; the app only consumes the six surfaces above.

### Local vendoring patches required

To generate a usable typed client without changing app behavior, the vendored
document must be patched (and the patches recorded in the PR description so a
future upstream regeneration reconciles them):

- Declare the full manifest response properties (`sheet_version`,
  `manifest_url`, `page`, `registration_markers`, `patches[]`, `pairs[]`, …)
  with `pair_1#first`-style ids left as plain strings.
- Declare the ranked-results `results[]` items (`rank`, `pair_id`,
  `source_colors`, `score`, …).
- Declare the app's measurement-upload payload fields (top-level
  `scoring_algorithm_version`; per-measurement `stats`) so wire parity holds.
- Optionally shorten the derived operationIds
  (`ColorMatchingWeb.TestSheetController.manifest`, …) to stable names; the
  tests only require non-empty ids.

## 3. Acceptance-criteria → verification map

| Deliverable | Verification (smallest credible) | Where |
| --- | --- | --- |
| swift-openapi-generator + runtime added; spec vendored | Permanent unit tests on the package manifest and the vendored document (RED until implementation) | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` (`testPackageManifestWiresGeneratedOpenAPIClient`, `testVendoredOpenAPIDocumentExistsAndIsOpenAPI30`) |
| Client generated for manifest/recent/captures/measurements/judgments/ranked results | Permanent unit tests asserting the vendored spec declares each path, method, success response, operationId, and schema shape | same file (surface, auth, and per-schema tests) |
| Hand-written API models replaced; client-side models kept | Wire-format keepers that pass today against the hand-written transport and must stay green after the swap (transport swap must not change method/path/auth/decoded models) | `iOS/Tests/ColorMatchingLPSAppTests/APIClientSurfaceTests.swift` + existing `APIClientTests.swift`; DTO removal is diff-reviewed |
| Swift tests against stubbed responses (no live server) | Permanent unit tests stubbing `URLProtocol` — no network in CI | `APIClientSurfaceTests.swift`, `APIClientTests.swift` |
| PR description records contract deltas + endpoint gaps | Pre-materialized in §2 above; the implementation PR carries it into its description (human/external evidence) | this document |

Exit criteria: `swift test --disable-sandbox` green on CI (macOS runner; no
Linux toolchain exists in the authoring container, and the `ColorMatchingLPSApp`
executable target imports iOS-only frameworks, so local Linux execution is not
possible) with the generated types wired in, and the PR description capturing
the §2 deltas.
