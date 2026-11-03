# Issue #5: Generated OpenAPI client verification plan

This is the red-phase verification plan for replacing the hand-written API
layer. Tests use `MockURLProtocol`, so they exercise typed client requests and
responses without a live Phoenix server.

| Criterion | Smallest credible verification | Current evidence / next implementation step |
| --- | --- | --- |
| Add the generator/runtime and obtain the OpenAPI document | Inspect `iOS/Package.swift`, the vendored or fetched spec, and the generated target after implementation. | Not runnable in this tests-only change; the implementation must pin or vendor the document served by `GET /api/v1/openapi.json`. |
| Generate the app-used operations | Permanent local-stub client tests for manifest, recent sheets, capture creation, measurement upload, and judgment upload; add a ranked-results stub only once its published response is complete enough to generate a usable model. | `APIClientTests` exercises the five callable operations. Ranked results is an upstream schema gap described below. |
| Replace hand-written API models | Inspect the app target after implementation; client-only measurement/scoring models remain in `MeasurementCore`. | Not runnable until the generated target is wired in. |
| Test generated client without live server | Run `swift test --disable-sandbox` and inspect the local `MockURLProtocol` stubs. | The permanent test fixture is ready; this container has no `swift` executable. |
| Record prose-to-spec deltas and endpoint gaps | Inspect the upstream OpenAPI document and this record in the PR description. | Findings below are based on `viamin/color_matching` main at issue #110 completion. |

## Published-spec findings for the implementation PR

- The upstream spec is served at `GET /api/v1/openapi.json`; its server URL is
  relative (`/`), so the iOS client must continue to supply the selected base
  URL.
- The prose manifest documents page geometry, registration markers, patches,
  pairs, and manifest metadata. The published `TestSheetManifest` schema
  declares only `schema_version`, `sheet_id`, and `capture_profile`. A direct
  generated model cannot supply the geometry required by `MeasurementCore`.
- The prose ranked-results endpoint does not define a response payload. The
  published `RankedResults` schema likewise declares only `schema_version` and
  `sheet_id`; it omits the stated rankings, scores, labels, provenance, printer
  profile, and algorithm version. This endpoint cannot yet provide typed ranked
  results to the iOS app.
- The prose capture body is nested under `metadata` and `quality`; the spec
  permits that representation but also supports a legacy flattened body.
- The prose measurement body includes a top-level
  `scoring_algorithm_version` and per-measurement statistics. The published
  schema does not declare either, requires normalized RGB data, and permits
  score/similarity/distance variants for pair scores.
- The prose treats title as nullable; the published recent-sheets schema also
  requires the `title` key while allowing its value to be null.

Implementation must either obtain a completed upstream schema before replacing
the manifest/ranked-results models, or preserve a deliberately separate,
documented compatibility decoder for the fields absent from that schema.
