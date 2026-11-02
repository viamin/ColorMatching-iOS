---
module: iOS companion
tags: [openapi, api-client, codegen, contract-drift]
problem_type: verification-plan
---

# Generated OpenAPI Client — Criterion Verification Plan & Contract Deltas

Red-phase test plan for issue #5 ("Replace hand-written API layer with a
generated OpenAPI Swift client"). This documents how each acceptance
criterion is verified, and records the deltas between
`docs/color-matching-api-contract.md` (prose contract) and the published
machine-readable spec, for reuse in the PR description.

## Upstream provenance

- The issue cites `viamin/color_matching#110`; that PR does not exist. The
  spec actually shipped in **viamin/color_matching#113** — "feat: Publish
  OpenAPI 3 spec for the `/api/v1` API and enforce it in CI (Schemathesis +
  oasdiff)" (merged, head commit `05062f5381a6f76413cc2bdf1cb2cc08a1b70ff7`).
- The document is generated at runtime by OpenApiSpex and served at
  `GET /api/v1/openapi.json` (OpenAPI 3.0, `servers: [{url: "/"}]`,
  `info: {title: "Color Matching API", version: "v1"}`).
- Implementation contract for this repo: the vendored copy must live at
  `iOS/OpenAPI/color-matching-openapi.json` (asserted by
  `OpenAPISpecCoverageTests`).

## Criterion → verification map

| AC | Verification | Locator |
| ---- | ---- | ---- |
| Add `swift-openapi-generator` + `swift-openapi-runtime`; fetch/vendor the OpenAPI document | `unit_or_service_test` — vendored document exists at the contract location, is OpenAPI 3.x, declares `bearerAuth`, covers the six operations, declares the ten component schemas, and wires request/response schemas needed for codegen | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPISpecCoverageTests.swift` |
| Generate client for surfaces used today (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results) | `unit_or_service_test` — spec-side: coverage + schema-wiring tests above; wire-side: stubbed-response tests below (path, method, auth header, payload shape per published spec) | `OpenAPISpecCoverageTests.swift`, `OpenAPIWireConformanceTests.swift` |
| Replace hand-written API models with generated types; keep client-side models | `unit_or_service_test` — `testUploadMeasurementsIncludesSpecRequiredNormalizedMedianForEachPatch` fails against the hand-written model today (spec requires `normalized_linear_rgb_median` on every measurement; the hand-written `PatchMeasurement` treats it as optional and omits it). The generated types must satisfy it | `OpenAPIWireConformanceTests.swift` |
| Swift tests exercising the client against local stubbed responses (no live server) | `unit_or_service_test` — all `OpenAPIWireConformanceTests` cases run against `SpecStubURLProtocol`; no network | `OpenAPIWireConformanceTests.swift` |
| PR description records contract deltas and endpoint gaps | `human_or_external_evidence` — deltas section below is the source material to carry into the PR description | this document |
| `swift test --disable-sandbox` green with generated types wired in | Execution gate for the implementation run; no Swift toolchain exists in this container, so tests could not be executed locally (see "Environment limitations") | — |

### Ranked-results client-behavior test (follow-up at implementation time)

The current hand-written `APIClient` has no ranked-results method, and
referencing a not-yet-generated client API would break compilation of the
whole test target during the red phase. The spec-side gate is covered by
`testVendoredSpecCoversEverySurfaceUsedByTheApp` and
`testRankedResultsOperationReturnsRankedResultsSchema`. The implementation
run must add the behavioral stubbed-response test for ranked results
(fetch → decode `RankedResults`) alongside the generated client.

## Contract deltas: prose contract vs published spec

Verified against the OpenApiSpex sources in viamin/color_matching#113
(`lib/color_matching_web/api_spec.ex`, `api_schemas.ex`,
`test_sheet_controller.ex`, `capture_controller.ex`, `router.ex`):

1. **Manifest response is weaker than the prose contract.** The published
   `TestSheetManifest` only guarantees `schema_version`
   (`lps-sheet-manifest/v1`), `sheet_id`, and
   `capture_profile.scoring_algorithm_version`. The prose fields
   `sheet_version`, `manifest_url`, `created_at`, `page`,
   `registration_markers`, `printer_profile`, `capture_profile`
   (illuminant/camera), `patches[]`, `pairs[]` are runtime extras, not part
   of the machine contract — a generated client cannot strongly type them.
   Endpoint gap: ask upstream to promote them into the schema.
2. **Capture creation accepts two shapes.** `CaptureRequest` is an `anyOf`:
   flat top-level attributes (where exposure is `exposure_duration`) or the
   nested `metadata` object the app sends today (`exposure_duration_seconds`).
   `quality.rejections` is a free-form string array — the prose contract's
   enumerated rejection strings are not enforced in the schema.
3. **Measurement upload lost guarantees.** The published
   `MeasurementUploadRequest` has no top-level `scoring_algorithm_version`
   and no per-measurement `stats` object; `RgbPayload` is an `anyOf` of
   array/object/string. `normalized_linear_rgb_median` is **required** per
   measurement item (the hand-written client treats it as optional and
   omits it when nil — red test covers this).
4. **Upload responses carry bodies, not 204.** Measurement and judgment
   uploads return `200` with `{"capture_id", "measurement_count",
   "pair_score_count"}` and `{"capture_id", "judgment_count"}`. The
   hand-written client/tests assumed an empty `204`.
5. **Pair scores.** `PairScoreRequest` requires per-score
   `algorithm_version` plus anyOf `score`/`similarity`/`distance` — matching
   today's upload shape.
6. **Ranked results are skeletal.** `RankedResults` guarantees only
   `schema_version` (`lps-ranked-results/v1`) and `sheet_id`; the prose
   contract's "source colors, scores, labels, capture provenance…" are not
   in the schema yet. Endpoint gap for upstream.
7. **Capture ids are stringified integers** in responses
   (`{"capture_id": "123"}`).
8. **Auth.** All app-facing operations declare the `bearerAuth`
   (`http`/`bearer`) security scheme; the spec itself is published
   unauthenticated at `/api/v1/openapi.json`.
9. **Extra endpoints in the spec unused by the app**: `/printer_profiles*`,
   `/palettes`, `/colors`, `/metamer_pairs`,
   `/api/illuminant_measurements(/bulk)`, `/api/multi_image_mapping`.

## Environment limitations

- This container has no Swift toolchain (`swift` not found), so
  `swift test --disable-sandbox` could not be executed here. Test logic was
  validated by (a) JSON-parsing every embedded fixture and (b) replaying the
  coverage assertions against a faithful reconstruction of the served
  document derived from the upstream OpenApiSpex sources.
- No database services; none needed (pure Swift package, stubbed HTTP).
- Lint: no lint command configured for this repo.
