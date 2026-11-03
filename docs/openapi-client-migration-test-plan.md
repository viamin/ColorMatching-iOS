# OpenAPI client migration verification plan

This is the red-phase test and review evidence for issue #5. The implementation
run must preserve these locally stubbed client tests while replacing the
hand-written API transport and models with generated OpenAPI types.

## Criterion map

| Criterion | Smallest credible verification | Evidence at this revision |
| --- | --- | --- |
| Add the generator/runtime and vendor or fetch the API document | Inspect `iOS/Package.swift`, the checked-in spec, and generated sources in the implementation PR. | Not implemented in this test-only revision. |
| Generate every app-used endpoint | Compile generated operation invocations for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results. | The local-stub characterization tests cover the first five; ranked results has no client call yet. |
| Remove server-owned hand-written models | Inspect the app-core module: server request/response types must originate from generated code, while `MeasurementCore` analysis types remain client-side. | Not implemented in this test-only revision. |
| Exercise generated client without a live server | Run the permanent `APIClientTests` target; its `MockURLProtocol` stubs all HTTP responses. | `APIClientTests.swift` includes manifest, recent-sheet, capture, measurement, and judgment stubs. |
| Record contract deltas and endpoint gaps | Human review of this document against the served `/api/v1/openapi.json` response and upstream implementation. | Deltas and gaps below. |
| `swift test --disable-sandbox` is green | Run that command after dependencies and generated sources exist. | Not run: Swift is not installed in this container. |

## Published-contract comparison

The comparison source is the OpenAPI implementation merged by
`viamin/color_matching#113` for `viamin/color_matching#110`, served at
`GET /api/v1/openapi.json`. The upstream source reviewed for this test run is
commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f`.

- The prose manifest describes a full geometry, printer-profile, and capture
  response. The published `TestSheetManifest` schema currently requires only
  `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`.
  The server still renders the additional fields, but the generated model will
  not expose typed fields until the schema is expanded.
- The prose ranked-results endpoint did not define a response body. The server
  renders `lps-ranked-results/v1` data, but the published `RankedResults`
  schema currently requires only `schema_version` and `sheet_id`. This is an
  endpoint gap for the app's ranked-results UI: generated types cannot provide
  typed ranks, scores, provenance, or judgments yet.
- The prose capture request nests camera data in `metadata` and quality data in
  `quality`. The published schema supports that nested shape and also accepts a
  legacy flattened capture shape.
- The prose measurement upload includes `scoring_algorithm_version` and
  per-measurement statistics. The published schema models patch RGB values and
  pair scores, but does not model the top-level algorithm version or statistics.
  It additionally requires `normalized_linear_rgb_median`, whereas the prose
  contract permits it to be omitted.
- The prose says measurement and judgment uploads return no response body. The
  published contract returns JSON summaries: measurement uploads provide
  `capture_id`, `measurement_count`, and `pair_score_count`; judgment uploads
  provide `capture_id` and `judgment_count`.

The implementation PR should either use the generated shapes as published or
coordinate schema additions upstream before claiming complete typed coverage.
