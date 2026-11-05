# Issue #5: generated OpenAPI Swift client — implementation notes

This tests-only change records the acceptance-criterion plan for the follow-up
implementation PR. The implementation must vendor a pinned copy of the OpenAPI
document served by `color_matching` at `/api/v1/openapi.json`, add
`swift-openapi-generator` and `swift-openapi-runtime`, and use generated
operations for every endpoint below. No live server is required by these tests.

## Criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Generated package and vendored OpenAPI document | Inspect `Package.swift`, the pinned spec, and the generated source diff; compile with `swift test --disable-sandbox` | Not run — implementation work |
| Manifest and recent sheets | Permanent URLProtocol tests using local JSON responses | Covered by `APIClientTests` |
| Capture creation, measurement upload, judgment upload | Permanent URLProtocol tests asserting method, path, authorization, and payload | Covered by `APIClientTests` |
| Ranked results | Permanent URLProtocol test decoding a local ranked-results response once the generated operation is wired into the app core | Not run — no app operation exists today |
| Replace hand-written API models | Inspectable source review: generated API models replace the API transport DTOs, while `MeasurementCore` analysis models remain client-side | Not run — implementation work |
| Published contract deltas and endpoint gaps | Inspect upstream controller/spec source and retain this record in the implementation PR description | Recorded below |

The permanent stub tests are deliberately API-boundary tests: `MockURLProtocol`
intercepts every request, so they need neither a running Phoenix instance nor
network access in CI.

## Published-contract deltas (inspected 2026-11-05)

Source inspected: `viamin/color_matching#110`, including
`ColorMatchingWeb.ApiSchemas`, `TestSheetController`, `CaptureController`, and
`TestSheetJSON` on the upstream `main` branch.

- The server publishes the document at `GET /api/v1/openapi.json`; the original
  prose contract does not mention that retrieval endpoint.
- All six requested paths exist in the published route set. The current iOS app
  invokes five; `GET /api/v1/test_sheets/{sheet_id}/ranked_results` has no
  client method or UI consumer yet.
- The generated `Manifest` schema currently requires only `schema_version`,
  `sheet_id`, and `capture_profile.scoring_algorithm_version`. The actual
  manifest renderer, and the iOS analyzer, additionally rely on page geometry,
  registration markers, patches, pairs, `sheet_version`, and `manifest_url`.
  The upstream schema must be expanded before a generated manifest type can
  replace the app model without an adapter or loss of type safety.
- The generated `RankedResults` schema currently requires only
  `schema_version` and `sheet_id`, while the renderer returns printer profile,
  capture timestamps/counts, scoring versions, and ranked pair details.
- The server accepts two capture request shapes (`metadata`/`quality` nesting or
  legacy flat fields). The prose contract documents only the nested shape; the
  app should use that generated branch.
- The prose contract declares a top-level `scoring_algorithm_version` for
  measurement upload and a nested `stats` payload. The published
  `MeasurementUploadRequest` schema documents neither; it requires normalized
  RGB data and lets `pair_scores` carry `algorithm_version` plus one of score,
  similarity, or distance. This is a blocking schema gap for directly generated
  request types.
- The prose contract says measurement and judgment uploads return `204`; the
  published API specifies `200` JSON responses containing capture and accepted
  item counts.
- The prose contract's printer profile uses `id`, `name`, `paper`, `ink`, and
  `settings`; the actual renderer exposes printer make/model, paper/ink types,
  ICC/driver/calibration fields, and no `id` or `name`.

## Endpoint gap to resolve before implementation

There is no endpoint gap in the upstream route set. There is an application gap:
ranked results are specified by the server but are not consumed by the iOS app.
The implementation should generate the operation and add its local-stub test;
product/UI usage remains out of scope unless separately requested.
