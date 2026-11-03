# OpenAPI client migration: acceptance evidence plan

This is the red-phase test plan for #5. The implementation run must replace the
hand-written transport models with generated types; this document does not claim
that it has done so.

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Add the generator/runtime and fetch or vendor the OpenAPI document | `OpenAPIContractTests.testVendoredSpecDeclaresEveryCompanionOperation` loads the vendored document and asserts every in-scope operation. Package dependency and plugin configuration require source inspection. | Red: `iOS/OpenAPI/color-matching.openapi.json` is not present. |
| Generate all used surfaces | Local `URLProtocol` stubs in `APIClientTests` cover manifest, recent sheets, capture creation, measurement upload, and judgment upload. Add a ranked-results stub once the generated adapter exposes that operation. | Partial: ranked results has no client surface. |
| Replace hand-written API models | Inspect the app-core target after generation: request/response protocol types must be generated types, while `MeasurementCore` remains client-side. | Not run: implementation has not started. |
| Swift tests use local stubs, not a live server | `APIClientTests` uses `MockURLProtocol` and only `example.test` URLs. The implementation run must retain these tests while routing through the generated client. | Existing tests pass where a Swift toolchain is available; this container has no `swift` executable. |
| PR description records contract deltas and endpoint gaps | Human review of the PR body against the upstream OpenAPI endpoint and this delta list. | Not run: no PR exists in this tests-only phase. |

## Upstream contract deltas to record in the implementation PR

Evidence was read from `viamin/color_matching#110` and its merged sources on
2026-11-03.

- The prose contract calls upload success `204`; the published API describes and
  returns `200` JSON acknowledgements: measurement uploads include `capture_id`,
  `measurement_count`, and `pair_score_count`; judgment uploads include
  `capture_id` and `judgment_count`.
- The prose manifest presents complete page, marker, patch, pair, printer, and
  capture-profile shapes. The current published `Manifest` schema requires only
  `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`.
  The generated client must therefore not assume the richer prose fields are
  guaranteed by the schema.
- The prose document describes ranked results only narratively. The API publishes
  `GET /api/v1/test_sheets/{sheet_id}/ranked_results` with
  `lps-ranked-results/v1`, although its schema currently guarantees only
  `schema_version` and `sheet_id`; the server renderer emits a richer aggregate
  result payload.
- Capture request compatibility is broader than the prose: the API accepts both
  the nested `metadata` form and a legacy flattened form. It also specifies RGB
  upload values as arrays, objects, or JSON-encoded strings, while the prose
  specifies only objects.
- The published OpenAPI schema does not currently expose `stats` or top-level
  `scoring_algorithm_version` in measurement-upload requests, even though the
  prose client sends both. This is an endpoint/schema gap that must be resolved
  upstream or deliberately omitted before generation.
