# OpenAPI Generated Client Migration (issue #5)

Plan and evidence map for replacing the hand-written API layer
(`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`) with a client generated
by `swift-openapi-generator` from the OpenAPI spec published by
`viamin/color_matching`.

## Upstream dependency status

- `viamin/color_matching#110` (publish OpenAPI 3 spec for `/api/v1` + enforce
  in CI with Schemathesis/oasdiff) is **closed, delivered by upstream PR #113**.
- The spec is generated at runtime by OpenApiSpex and served at
  `GET /api/v1/openapi.json`; there is **no static spec file upstream**.
  Sources of truth: `lib/color_matching_web/api_spec.ex`,
  `lib/color_matching_web/api_schemas.ex`,
  `lib/color_matching_web/controllers/{test_sheet,capture}_controller.ex`, and
  `lib/color_matching_web/controllers/test_sheet_json.ex` (actual rendered
  payloads).
- Vendoring therefore means checking in a YAML document at
  `iOS/Sources/ColorMatchingOpenAPI/openapi.yaml` that mirrors the served spec,
  with the refinements listed below recorded as deltas.

## Target architecture (contract for the implementation run)

- Package deps: `apple/swift-openapi-generator` (1.x, provides the
  `OpenAPIGenerator` plugin) and `apple/swift-openapi-runtime` (1.x, product
  `OpenAPIRuntime`).
- New target `ColorMatchingOpenAPI` holding `openapi.yaml` and the
  `OpenAPIGenerator` plugin; no hand-written Swift in it.
- `ColorMatchingLPSAppCore` keeps its public `APIClient` surface (so
  `ContentView` and the wire-contract tests are unchanged) but delegates to the
  generated `Client` via `URLSessionTransport`, adding bearer auth through a
  `ClientMiddleware`.
- Generated method names are pinned by these operationIds (upstream OpenApiSpex
  defaults are controller-qualified, e.g.
  `ColorMatchingWeb.TestSheetController.manifest`, which sanitize into unstable
  Swift method names — the vendored copy overrides them):

  | operationId          | path                                            | method |
  | -------------------- | ----------------------------------------------- | ------ |
  | `fetchSheetManifest` | `/api/v1/test_sheets/{sheet_id}/manifest`       | GET    |
  | `fetchRecentSheets`  | `/api/v1/test_sheets/recent`                    | GET    |
  | `createCapture`      | `/api/v1/test_sheets/{sheet_id}/captures`       | POST   |
  | `uploadMeasurements` | `/api/v1/captures/{capture_id}/measurements`    | POST   |
  | `uploadJudgments`    | `/api/v1/captures/{capture_id}/judgments`       | POST   |
  | `fetchRankedResults` | `/api/v1/test_sheets/{sheet_id}/ranked_results` | GET    |

- Component titles kept from upstream: `TestSheetManifest`,
  `RecentSheetsResponse`, `CaptureRequest`, `CaptureMetadata`,
  `CaptureCreatedResponse`, `MeasurementUploadRequest`,
  `MeasurementUploadResponse`, `JudgmentUploadRequest`,
  `JudgmentUploadResponse`, `RankedResults`, `RgbPayload`, `PairScoreRequest`.
- The vendored copy trims to the six surfaces the app uses (upstream
  printer-profile/palette/color/illuminant/multi-image endpoints stay out of
  scope for the app client).

## Contract deltas: prose contract vs published spec

`docs/color-matching-api-contract.md` (prose) vs the spec/payloads actually
published by `viamin/color_matching` (PR #113). This table is the seed for the
PR description required by issue #5; the implementation PR must confirm each
row against the final vendored document.

| # | Area | Prose contract | Published spec / actual behavior | Impact |
| - | ---- | -------------- | -------------------------------- | ------ |
| 1 | Measurement upload response | Not specified | `200 OK` + JSON body `{capture_id, measurement_count, pair_score_count}` (`MeasurementUploadResponse`) | App assumed bodyless success (tests stubbed 204). Wire tests now pin 200+body tolerance. |
| 2 | Judgment upload response | Not specified | `200 OK` + JSON body `{capture_id, judgment_count}` (`JudgmentUploadResponse`) | Same as above. |
| 3 | Capture creation response | `{"capture_id": ...}` | `201 Created` + `CaptureCreatedResponse {capture_id}` — matches prose | None. |
| 4 | Error responses | Not specified | `ApiErrorResponse {errors: detail-object or [{detail, source.pointer}]}` on 401/404/422 | Generated client gains typed error payloads the hand-written layer never modeled. |
| 5 | Manifest schema | Full object (page, markers, printer_profile, capture_profile, patches, pairs) documented | Spec only **requires** `schema_version`, `sheet_id`, `capture_profile.scoring_algorithm_version`; the rest of the rendered payload is undocumented in the spec (though rendered — see `test_sheet_json.ex`) | Spec gap: the app decodes `page`, `registration_markers`, `patches`, `pairs` on every fetch. Vendored copy documents the full rendered manifest. |
| 6 | Ranked results schema | "source colors, scores, labels, capture provenance, printer profile, scoring algorithm version" (prose bullet, no schema) | Spec only requires `schema_version`, `sheet_id`. Actual payload adds `printer_profile`, `capture_count`, `latest/earliest_capture_at`, `scoring_algorithm_versions`, and rich `results[]` (rank, pair_id, source_colors{color_a_hex,color_b_hex}, score{average,latest,min,max,...}, current_judgment, latest_observation, observation_count) | Endpoint gap: vendored copy documents the rendered aggregate; prose bullet under-specifies labels/capture provenance. |
| 7 | Manifest patch IDs | `patch_1` style | Rendered as `{pair_id}#first` / `{pair_id}#second` | Cosmetic; client treats IDs as opaque strings. |
| 8 | Printer profile shape | `{id, name, paper, ink, settings}` | Rendered `{printer_make_model, paper_type, ink_type, icc_profile, print_settings, driver_name, driver_version, calibration_date, calibration_version, notes}` — no `id`, no `name` | Prose wrong; vendored copy follows the rendered shape. |
| 9 | Recent sheets | `title` may be null | Spec: `title` required-but-nullable; current server always renders `title: null`; fixed limit 20 | Client keeps nullable title; limit undocumented in prose. |
| 10 | Measurement stats | `stats {sample_count, clipping_fraction, mean, standard_deviation}` documented | Not in spec at all (tolerated as additional properties) | Vendored copy documents `stats` (optional) so the generated client can keep sending it. |
| 11 | `normalized_linear_rgb_median` | Not explicitly required | Spec requires it on every measurement (not nullable); the client model treats it as optional (JSON `null` when normalization is unavailable) | **Real drift risk**: sending `null` can yield 422. Vendored copy marks it nullable; app should omit instead of sending `null` (see gaps below). |
| 12 | Top-level `scoring_algorithm_version` on measurement upload | Documented | Not in spec (tolerated) | Vendored copy documents it as optional. |
| 13 | `RgbPayload` shape | `{r, g, b}` object | Spec allows anyOf: `[r,g,b]` array, `{r,g,b}` object, or string | Generated Swift for anyOf is a case enum; vendored copy pins the object form the app uses. |
| 14 | `PairScoreRequest` | `{pair_id, distance, similarity, algorithm_version}` | Spec: `pair_id`+`algorithm_version` required, anyOf(`score`/`similarity`/`distance`), no `distance`+`similarity` pairing guarantee | Vendored copy flattens to optional `score`/`similarity`/`distance`. |
| 15 | Capture request envelope | `{metadata: {...}, quality: {...}}` | Spec accepts either flat capture attributes or nested `metadata` (+ optional `quality`) via schema-level anyOf | Vendored copy pins the nested form the app sends. |
| 16 | Judgments enum | `match`, `near_match`, `no_match` allowed values | Spec: free-form string | Vendored copy documents the three values (kept as plain string to avoid unstable generated enum case names). |
| 17 | Auth | Shared bearer token, optional in dev | `bearerAuth` (http/bearer) declared on every app-used operation; `ApiAuth` plug enforces it | Matches prose; generated client applies it via middleware. |
| 18 | operationIds | Not specified | OpenApiSpex defaults `ColorMatchingWeb.<Controller>.<action>` | Vendored copy overrides with the stable ids in the table above. |

## Gaps discovered (must appear in the PR description)

1. Upstream spec under-documents `TestSheetManifest` (delta 5) and
   `RankedResults` (delta 6) relative to what the endpoints actually render and
   what the app consumes. Consider upstream follow-ups so the served
   `/api/v1/openapi.json` matches reality; until then the vendored copy carries
   the fuller schemas and the diff is visible in this repo.
2. `normalized_linear_rgb_median` nullability mismatch (delta 11): today's
   hand-written encoder emits JSON `null` when normalization is unavailable,
   which the published (non-nullable, required) constraint would reject with
   422. The migration must omit the key instead of sending `null`, or upstream
   must mark it nullable.
3. Prose contract never specified success status codes or error payload shape
   (deltas 1, 2, 4); the app silently accepted any 2xx. The generated client
   now pins 200/201 (+401/404/422 errors) per operation.

## Vendoring refinements (documented deviations in the vendored copy)

- Full manifest + ranked-results schemas matching the rendered payloads
  (deltas 5, 6, 7, 8).
- `RgbPayload` pinned to the `{r, g, b}` object (delta 13);
  `PairScoreRequest` flattened (delta 14); `CaptureRequest` pinned to the
  nested `metadata`/`quality` envelope (delta 15).
- `normalized_linear_rgb_median` nullable; `stats` and top-level
  `scoring_algorithm_version` documented as optional (deltas 10–12).
- String enums (`schema_version`, `judgment`) kept as plain strings to avoid
  unstable generated case names (deltas 6, 16); the wire-contract tests still
  pin the exact values.
- Stable operationIds (delta 18).

## Acceptance criteria → verification map

| AC (issue #5) | Smallest credible verification | Locator |
| ------------- | ------------------------------ | ------- |
| Add generator + runtime; vendor the OpenAPI document | Permanent unit tests on `Package.swift` + vendored file existence (red until implementation lands) | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIMigrationArtifactsTests.swift` (`testPackageDeclaresOpenAPIGeneratorPluginAndRuntime`, `testOpenAPIDocumentIsVendoredForGeneration`) |
| Generate client for all six surfaces | Spec-coverage tripwires (paths + operationIds + bearer scheme) and stubbed-response tests per operation | `OpenAPIMigrationArtifactsTests.swift` (`testSpecCoversEverySurfaceTheAppUses`, `testSpecDefinesStableOperationIDsForGeneratedClientMethods`, `testSpecDeclaresBearerAuth`); `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientTests.swift` (all six tests) |
| Replace hand-written API models, keep client-side models | Wire-contract regression net that must stay green across the swap (public `APIClient` behavior unchanged); model removal itself is PR-diff review (human evidence) | `iOS/Tests/ColorMatchingLPSAppTests/APIClientWireContractTests.swift` (all six tests) + PR diff |
| Swift tests against stubbed responses, no live server | All generated-client tests run against `URLProtocol` stubs; `swift test --disable-sandbox` needs no server | `OpenAPIClientTests.swift` (activated via `#if canImport(ColorMatchingOpenAPI)`) |
| PR description records contract deltas + gaps | Human/external evidence at PR time; delta analysis drafted here as the source | This document, tables above |

## Test status in this (tests-only) run

- `APIClientWireContractTests` — compiles and passes against the current
  hand-written layer (regression net; verifies the published 200-with-body
  success responses and real manifest/ranked fixtures are handled).
- `OpenAPIMigrationArtifactsTests` — **red by design**: they fail until the
  toolchain, vendored spec, and coverage exist (expected assertion failures
  demonstrating missing behavior).
- `OpenAPIClientTests` — dormant behind `#if canImport(ColorMatchingOpenAPI)`;
  activates automatically once the generated target exists and then guards the
  generated surface against drift.
- `swift test --disable-sandbox` cannot run in this Linux container (no Swift
  toolchain; the app target requires macOS/iOS SDKs). The suite runs on the
  macOS GitHub Actions runner (`.github/workflows/ci.yml`).
