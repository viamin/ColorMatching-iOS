---
module: iOS companion app
tags: [openapi, api-client, codegen, testing, color_matching]
problem_type: feature_migration
---

# Generated OpenAPI Swift client — test plan and contract analysis (issue #5)

Status: **tests-only red phase.** This document plus the new tests in
`iOS/Tests/ColorMatchingLPSAppTests/` define the contract for replacing the
hand-written API layer with a generated OpenAPI client. No implementation
files were changed in this phase; the tests below fail (red) until the
implementation phase lands the generated client.

## Acceptance criteria → verification mapping

| AC | Deliverable | Verification (smallest credible) | Evidence at this head |
|----|-------------|----------------------------------|-----------------------|
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` in the iOS package; OpenAPI document vendored | Focused unit tests on the vendored document (existence, paths, operation IDs, schemas, security scheme). Package dependency wiring is proven when `swift test` builds (compile-level). | `OpenAPIDocumentTests` (red: document not vendored yet) |
| AC-2 | Generated client for manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Generated-client tests against a stub `ClientTransport`: one test per surface asserting method, path, wire payload, and decoded generated types | `GeneratedClientTests` (red: `ColorMatchingAPI` target not generated yet) |
| AC-3 | Replace hand-written API models with generated types; keep client-side models | Code review of the implementation PR (deletion of `CaptureMetadata`/`WhiteBalanceGains`/`CaptureSessionResponse`/`RecentSheet`/`PairJudgment` hand-written Codable models in `ColorMatchingLPSAppCore`); `MeasurementCore` client-side decoding models (`SheetManifest`, `Patch`, `PairManifest`, …) stay | Deferred to implementation run (human/external evidence) |
| AC-4 | Swift tests exercising the generated client against local stubbed responses (no live server in CI) | The `GeneratedClientTests` suite uses `StubTransport`; no network, no server, deterministic fixtures | `GeneratedClientTests` (written; cannot execute in this container — no Swift toolchain) |
| AC-5 | PR description records contract deltas and endpoint gaps | The delta table below is the source material; the implementation PR description must reproduce it | This document (inspectable artifact) |

## Implementation contract the tests assume

The tests intentionally pin the following so generated Swift names are stable:

1. **Package layout**: a new SPM target `ColorMatchingAPI` that applies the
   `OpenAPIGenerator` build plugin from `swift-openapi-generator` and depends
   on `swift-openapi-runtime` (>= 1.5.0, whose `ClientTransport.send` takes a
   separate `body` parameter and whose HTTP currency types come from
   `swift-http-types`).
2. **Vendored document**: `iOS/ColorMatchingAPI/openapi.json`, fetched from
   `GET /api/v1/openapi.json` (published by viamin/color_matching#110).
3. **Clean operation IDs**: the live Phoenix spec derives controller-qualified
   IDs (`ColorMatchingWeb.TestSheetController.manifest`); vendoring must
   override them, because `swift-openapi-generator` turns those dots into
   unusable Swift identifiers. Required IDs:

   | Operation | ID |
   |-----------|----|
   | `GET /api/v1/test_sheets/{sheet_id}/manifest` | `getTestSheetManifest` |
   | `GET /api/v1/test_sheets/recent` | `listRecentSheets` |
   | `GET /api/v1/test_sheets/{sheet_id}/ranked_results` | `getRankedResults` |
   | `POST /api/v1/test_sheets/{sheet_id}/captures` | `createCapture` |
   | `POST /api/v1/captures/{capture_id}/measurements` | `uploadMeasurements` |
   | `POST /api/v1/captures/{capture_id}/judgments` | `uploadJudgments` |

4. **Default generator naming** (no `openapi-generator.yaml` overrides needed
   beyond `access: public`): Swift members keep their documented JSON names
   (`sheet_id`, `capture_id`, `detected_marker_count`, …), operation type
   namespaces are `Operations.<operationId>`, and component schema types are
   `Components.Schemas.<Title>` (e.g. `Components.Schemas.TestSheetManifest`,
   which is the `title` the Phoenix spec assigns).
5. **Test-target dependencies**: `ColorMatchingLPSAppTests` must gain
   `ColorMatchingAPI` plus the `OpenAPIRuntime` and `HTTPTypes` products (the
   stub transport constructs `HTTPResponse`/`HTTPFields` and conforms to
   `ClientTransport`).
6. **Auth**: bearer token via a `ClientMiddleware` adding `Authorization:
   Bearer <token>`, matching the spec's `bearerAuth` (`http`/`bearer`) scheme.

## Contract deltas: prose contract vs published spec

Source: `docs/color-matching-api-contract.md` vs the `open_api_spex` spec
modules in viamin/color_matching (`lib/color_matching_web/api_schemas.ex`,
`test_sheet_controller.ex`, `capture_controller.ex`). These belong in the
implementation PR description.

1. **Manifest schema is much smaller than the prose contract.** Published
   `TestSheetManifest` only guarantees `schema_version`
   (`lps-sheet-manifest/v1`), `sheet_id`, and
   `capture_profile.scoring_algorithm_version` (`lps-distance-v1`). The prose
   contract's `sheet_version`, `manifest_url`, `created_at`, `page`,
   `registration_markers`, `printer_profile`, extended `capture_profile`
   (illuminant, preferred camera), `patches[]`, and `pairs[]` are absent.
   Endpoint gap: the app's sheet geometry (MeasurementCore `SheetManifest`)
   cannot be driven from generated types until the spec is extended upstream.
2. **Capture request accepts two shapes.** The spec keeps the prose's nested
   `metadata` + `quality` but also allows a flat legacy shape whose exposure
   field is renamed `exposure_duration` (prose: `exposure_duration_seconds`
   inside metadata) and adds `rejection_reasons` (not in prose). `quality`
   has no required fields. `iso` is an **integer** (the app's hand-written
   `CaptureMetadata.iso: Float` could emit fractions that CastAndValidate
   would reject). `white_balance_gains` is a freeform object — prose's
   red/green/blue gains are not schema'd.
3. **Measurement upload lost fields the prose contract promised.** Top-level
   `scoring_algorithm_version` is gone (each `pair_scores[]` item now requires
   `pair_id` + `algorithm_version` plus one of `score`/`similarity`/
   `distance`). Per-measurement `stats` (`sample_count`, `clipping_fraction`,
   `mean`, `standard_deviation`) are not accepted at all — endpoint gap:
   per-measurement statistics are dropped from the API. `linear_rgb_median`
   and `normalized_linear_rgb_median` are both required and are a `RgbPayload`
   union (array | `{r,g,b}` object | string) instead of prose's fixed object.
4. **Uploads now return JSON bodies, not empty 204s.** Measurement upload:
   `200 {capture_id, measurement_count, pair_score_count}`. Judgment upload:
   `200 {capture_id, judgment_count}`. The hand-written client ignored bodies
   and accepted any 2xx; generated types make the counts visible.
5. **Judgments are free strings.** The prose contract enumerates
   `match`/`near_match`/`no_match`; the spec leaves `judgment` unvalidated —
   drift risk a generated client cannot catch.
6. **Ranked results schema is skeletal.** Only `schema_version`
   (`lps-ranked-results/v1`) + `sheet_id`. The prose contract promised source
   colors, scores, labels, capture provenance, printer profile, and scoring
   algorithm version — endpoint gap to file upstream.
7. **`capture_id` is a stringified integer** (e.g. `"123"`), not an opaque ID.
8. **Error shapes are now specified**: `ApiErrorResponse` (object or array
   with `detail` + JSON-pointer `source`) for 401/404/422 on the app surfaces;
   the prose contract documented no error bodies.
9. **Recent sheets `title` is required-but-nullable** — consistent with the
   prose note that it may be `null`.
10. **Auth matches**: `bearerAuth` (http/bearer) on all six operations.
11. **Extra endpoints exist in the spec** (`printer_profiles`, `palettes`,
    `colors`, `metamer_pairs`, `illuminant_measurements`(+bulk),
    `multi_image_mapping`); the app does not use them and the vendored doc
    may keep or filter them (the tests only require the six app surfaces).

## Test inventory

- `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIDocumentTests.swift` — 10
  Foundation-only tests guarding the vendored document (existence, OpenAPI 3
  version, six paths/operation IDs, bearerAuth scheme, component schema
  names, version enums, nested capture request shape, RgbPayload object
  branch, upload count responses, nullable title, ranked-results schema).
- `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` — 8 tests
  driving the generated client through `StubTransport` + bearer middleware:
  manifest decode (typed enum versions), recent sheets with `title: null`,
  capture create (nested metadata/quality wire payload, 201 decode),
  measurement upload (RgbPayload object encoding, per-score algorithm
  version, decoded counts, absence of top-level scoring version), judgment
  upload (payload + counts), ranked results (new surface, previously missing
  from the hand-written client), typed `notFound` output, and bearer header
  application.
- Existing `APIClientTests`/`MeasurementCoreTests` remain untouched; they
  keep the hand-written layer honest until the implementation phase replaces
  it (AC-3), at which point `APIClientTests` is updated or removed together
  with the hand-written models.

## Running

From `iOS/`: `swift test --disable-sandbox` (CI runs plain `swift test` on
macOS plus the Xcode simulator scheme). The tests require no server.
