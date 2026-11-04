# OpenAPI client migration evidence

This record is the PR-description source for issue #5. It was created during
the tests-only phase; implementation and final verification belong to the
follow-up implementation run.

## Acceptance-criterion plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor or fetch the published document | Inspect `iOS/Package.swift`, generated target configuration, and vendored/fetch script against the upstream published `/api/v1/openapi.json` document | Not implemented |
| Generate the manifest, recent-sheet, capture, measurement, judgment, and ranked-results surfaces | Compile the generated client and exercise every generated operation with `URLProtocol` local responses | Partial: existing tests cover capture, measurement, and judgment; `APIClientTests` now covers manifest and recent sheets. Ranked results has no client call today. |
| Replace hand-written API models without changing client-only models | Compile the app target and inspect that server DTOs originate in generated code while `MeasurementCore` models remain local | Not implemented |
| Generated-client tests use local stubs | Permanent `URLProtocol` tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; no live service or database | Partial: current hand-written client is covered; implementation must redirect these tests to generated operations. |
| Record prose-contract deltas and endpoint gaps | Inspect the fetched published JSON and compare each operation/schema with `docs/color-matching-api-contract.md`; include the resulting table in the implementation PR description | Blocked pending retrieval of a served OpenAPI JSON document |

## Upstream evidence and contract deltas

On 2026-11-04, `viamin/color_matching#110` was closed. Its published source
contains `ColorMatchingWeb.ApiSpec`, which dynamically resolves router
operation schemas through `open_api_spex`; the repository does not contain a
static OpenAPI JSON/YAML artifact. The issue states that the document is served
at `GET /api/v1/openapi.json`, but no deployed base URL is recorded there.
Therefore this tests-only PR intentionally does not vendor an unverified spec.

The current prose contract differs from the upstream issue's stated scope:

- The prose document covers six `/api/v1` surfaces: manifest, recent sheets,
  capture creation, measurement upload, judgment upload, and ranked results.
- The upstream issue says the spec covers every `/api/v1` route plus
  `/api/illuminant_measurements` and `/api/multi_image_mapping`; those two
  non-versioned endpoints are absent from the prose document and are outside
  this iOS issue's generated-client surface.
- The prose document specifies only ranked-results intent, not a response JSON
  schema. A generated operation cannot be integrated until the served spec
  supplies its concrete response type.
- The prose document names capture rejection/judgment strings, while the
  implementation must compare the published enum values (and casing) before
  replacing the local string models.

## Implementation handoff

Fetch the canonical JSON from the deployed Phoenix API (or obtain a stable
upstream artifact URL), pin its provenance, generate the selected operations,
then replace the current hand-written transport DTOs. Keep `MeasurementCore`
types client-side and introduce explicit mapping only where generated request
schemas require it. Update the local-stub tests to instantiate and invoke the
generated client; add a ranked-results stub once the concrete schema is known.
