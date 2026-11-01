# Issue #5 generated OpenAPI client: verification plan

This is the test-first plan for replacing the hand-written `/api/v1` Codable
layer. It is based on the published provider implementation for
[`viamin/color_matching#110`](https://github.com/viamin/color_matching/issues/110),
whose OpenAPI document is served at `GET /api/v1/openapi.json`.

| Criterion | Smallest credible verification | Status in this test-writing change |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor/fetch the document | Package resolution plus a checked-in generated source/spec provenance diff | Not run: implementation phase owns package and generated artifacts. |
| Generate every app-used surface | Compile calls for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Not run: ranked-results adapter and generated module do not exist yet. |
| Replace hand-written API models | Compile-time use of generated request/response types; retain only MeasurementCore client-side models | Not run: implementation phase. |
| Local-stub client tests | Permanent `APIClientTests` send representative manifest, recent-sheet, capture, measurement, and judgment responses through `MockURLProtocol`; implementation must route these calls through the generated client. Add ranked-results stub when its adapter lands. | Partially covered by the tests in this change; not executable here because Swift is unavailable. |
| Record actual contract deltas and endpoint gaps in the PR | Inspectable PR description, reviewed against the provider's current `ApiSchemas`, controller operation declarations, and rendered `openapi.json` | Human/external evidence required at PR creation. |

The stub tests are permanent regression coverage: the app repeatedly loads a
sheet and uploads its capture results, and these calls must remain compatible
without needing a live Phoenix server in CI.

## Contract deltas found from the provider source

- The prose manifest includes page geometry, marker, patch, pair, printer, and
  capture-profile fields. The published `Manifest` schema currently promises
  only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`.
  The generated client cannot safely replace the app's full manifest model until
  the provider schema describes those fields.
- The provider accepts both the prose nested `metadata`/`quality` capture body
  and a legacy flat capture body. Its nested metadata requires image dimensions;
  the iOS hand-written model currently makes them optional. The provider declares
  `iso` as an integer, while the iOS model uses `Float`.
- The prose measurement body contains `scoring_algorithm_version` and `stats`.
  Neither is represented by the provider's `MeasurementUploadRequest`; the
  provider instead requires `normalized_linear_rgb_median` for each measurement.
  Pair scores allow `score`, `similarity`, or `distance`, whereas the prose
  client always sends the latter two.
- The prose treats measurement and judgment uploads as `204 No Content`. The
  provider documents and returns `200 OK` JSON count responses. The updated
  stubs model those actual successful responses.
- Ranked results is routed and has a schema, but the schema promises only
  `schema_version` and `sheet_id`. It does not expose the prose contract's
  source colors, scores, labels, capture provenance, printer profile, or
  scoring algorithm version. This is an endpoint/schema gap that needs provider
  resolution before a useful typed ranked-results UI adapter can be completed.
