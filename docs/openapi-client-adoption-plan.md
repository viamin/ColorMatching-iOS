# OpenAPI Swift Client Adoption: Verification Plan

This is the PR/run evidence plan for issue #5. It is intentionally checked in
with the red tests so that the implementation must demonstrate each criterion
rather than treating a broad green suite as sufficient evidence.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Evidence at implementation time |
| --- | --- | --- |
| Generator/runtime dependencies and a vendored or fetched API description are present | Focused unit test reads `iOS/Package.swift` and the vendored JSON document. | `OpenAPIContractTests.testVendoredSpecDefinesEveryAppOperationAndGeneratedClientDependencies` |
| Generated client exposes manifest, recent sheets, capture creation, measurement/judgment upload, and ranked results | The same focused contract test requires all six paths. A generated-client stub test invokes every operation using `MockURLProtocol`. | `OpenAPIContractTests` plus `APIClientTests` |
| Transport models are generated rather than hand-written | Compile the app after replacing transport DTOs with generated models; preserve only the local measurement/scoring types. | `swift test --disable-sandbox` and review of `APIClient.swift` |
| No-live-server client coverage | Permanent XCTest unit/service tests provide request/response stubs through `MockURLProtocol`. | `APIClientTests` |
| Prose-versus-published-contract deltas are recorded | Inspect the upstream OpenAPI document and cite the comparison below in the PR description. This is human/external evidence, not a test assertion. | This document, “Observed contract deltas” |

## Observed contract deltas

Evidence source: `viamin/color_matching` issue #110 and its merged PR #113,
inspected at upstream commit `47057afd58f7d46b4d4b740ca7d2d08947774471`.

- The published API is served at `GET /api/v1/openapi.json`; the app must fetch
  or vendor that JSON rather than derive a schema from this repository's prose.
- All six required routes exist upstream, including
  `GET /api/v1/test_sheets/{sheet_id}/ranked_results`. The current iOS UI does
  not call ranked results, so wiring that generated operation is an endpoint
  gap in this app.
- The published `TestSheetManifest` schema presently requires only
  `schema_version`, `sheet_id`, and `capture_profile`; the prose contract and
  iOS analyzer require page geometry, registration markers, patches, and pairs.
  The generated client cannot replace `SheetManifest` until those fields are
  represented in the upstream schema.
- The published `RankedResults` schema presently requires only
  `schema_version` and `sheet_id`; its result entries/provenance described by
  the prose contract are not machine-readable yet.
- The published measurement schema does not include the prose contract's
  top-level `scoring_algorithm_version`. The red contract test makes this
  mismatch explicit before client generation.

## Red-phase status

`OpenAPIContractTests` is expected to fail until the implementation run adds
the Swift OpenAPI dependencies and vendors the upstream JSON. The second test
will continue to fail against the current upstream document until its missing
schemas are expanded, or the product decision explicitly narrows the iOS
surface. The `APIClientTests` stubs are permanent coverage for the app's
existing manifest, recent-sheets, capture, measurement, and judgment flows;
they use no live server.
