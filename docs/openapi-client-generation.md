# OpenAPI Client Generation Plan

## Scope and source

The iOS package will vendor the OpenAPI document served by
`GET /api/v1/openapi.json` from `viamin/color_matching`. The source was
examined at upstream commit `47057afd58f7d46b4d4b740ca7d2d08947774471`
(the repository HEAD on 2026-11-04). The implementation run should save that
document as `iOS/OpenAPI/color-matching-api-v1.json`, wire
`swift-openapi-generator` and `swift-openapi-runtime` into `iOS/Package.swift`,
and generate only the operations consumed by the app:

- `GET /api/v1/test_sheets/{sheet_id}/manifest`
- `GET /api/v1/test_sheets/recent`
- `POST /api/v1/test_sheets/{sheet_id}/captures`
- `POST /api/v1/captures/{capture_id}/measurements`
- `POST /api/v1/captures/{capture_id}/judgments`
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results`

The generated transport should continue using injected `URLSession`/URLProtocol
fixtures in Swift tests; CI must not contact the Phoenix service.

## Criterion-to-verification map

| Criterion | Smallest credible verification | Red-phase location |
| --- | --- | --- |
| Generator/runtime dependencies and reproducible spec input | XCTest checks the vendored input and package configuration | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testOpenAPIClientInputsAreVendoredAndConfiguredForGeneration` |
| Generated typed operations cover each app surface | Local URLProtocol responses decode manifest, recent sheets, capture receipt, measurement receipt, judgment receipt, and ranked results through generated operations | Permanent Swift test to add in the implementation run |
| Hand-written transport models are replaced | Compile the app target using generated operation input/output types; retain only measurement/camera domain models | `swift test --disable-sandbox` in implementation run |
| No live server in CI | URLProtocol handlers assert paths, authorization, typed request payloads, and typed stubbed responses | Existing `APIClientTests`; expand in implementation run |
| Contract-delta record | Inspectable comparison below, based on upstream `ApiSchemas`, controllers, and JSON renderer | This document and PR description |

The first XCTest is intentionally red until implementation vendors the document
and declares the generator dependencies. It is a configuration regression test,
not a substitute for the generated-client response tests listed above.

## Prose-contract deltas and endpoint gaps

- The published spec is served dynamically; it is not committed as a static
  JSON file upstream. Vendoring it in this repository is required for a stable
  regeneration diff.
- The manifest's published OpenAPI schema requires only `schema_version`,
  `sheet_id`, and `capture_profile.scoring_algorithm_version`. The actual
  renderer returns the richer geometry, printer, patch, and pair fields that
  the iOS analyzer needs. This is a spec gap: generated manifest types cannot
  replace the current full manifest model until those fields are described.
- The prose describes only nested `metadata` and `quality` for capture creation.
  The published spec additionally supports a legacy flat capture payload. The
  nested payload remains compatible, but generated input selection must use it.
- The prose has measurement `stats` and a top-level
  `scoring_algorithm_version`; the published schema declares only patch RGB
  medians and pair-score algorithm versions. The server response is a `200`
  receipt with `capture_id`, `measurement_count`, and `pair_score_count`, not
  the current iOS test's `204` empty response. The omitted fields are a spec
  gap if the app must continue sending them.
- The judgment endpoint likewise returns a `200` receipt with `capture_id` and
  `judgment_count`; the prose leaves its response unspecified.
- The prose leaves ranked-result shape open-ended. The published schema
  requires only `schema_version` and `sheet_id`, although the actual renderer
  returns rankings, score aggregates, judgment provenance, capture counts, and
  printer data. This is a second spec gap blocking a complete generated typed
  ranked-results UI model.
