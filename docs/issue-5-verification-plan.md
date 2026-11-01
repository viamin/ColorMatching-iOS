---
module: ColorMatchingLPSAppCore
tags: [api, openapi, verification]
problem_type: test-plan
---

# Issue #5 verification plan

This is the criterion-level plan for replacing the hand-written `/api/v1`
layer with a `swift-openapi-generator` client. The permanent tests use an
in-process `OpenAPIRuntime.ClientTransport`, so they exercise generated
serialization and typed response decoding without reaching a live Phoenix
server.

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generated client covers the manifest and recent-sheet reads | Permanent generated-client stub tests assert operation IDs, routes, typed manifest fields, nullable recent-sheet title, and a typed 404 output. | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedAPIClientTests.swift` — `testGetTestSheetManifestDecodesFullSchema`, `testGetTestSheetManifestSurfacesNotFound`, and `testListRecentTestSheetsDecodesAlwaysNullTitle` |
| Generated client covers capture creation and measurement/judgment uploads | Permanent generated-client stub tests assert the routes, request JSON, and typed JSON responses for all three writes. Measurement coverage specifically rejects the obsolete top-level `scoring_algorithm_version`. | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedAPIClientTests.swift` — `testCreateCaptureEncodesNestedMetadataAndQuality`, `testUploadMeasurementsDecodesCountsResponse`, and `testUploadJudgmentsDecodesCountResponse` |
| Generated client covers ranked results | A permanent generated-client stub test decodes the real nested response shape and proves rows are distinct by `(pair_id, scoring_algorithm_version)`. | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedAPIClientTests.swift` — `testGetRankedResultsDecodesPerAlgorithmVersionRows` |
| Specification is available to generation | The vendored OpenAPI document contains exactly the six app-used `/api/v1` operations and is valid JSON. The implementation run must configure the generator target to use it and run the same tests. | `docs/api/color-matching-openapi.v1.json` |
| Contract deltas and endpoint gaps are recorded for review | Inspectable documentation compares the prose contract with upstream source/spec evidence and records the limited-spec caveat and endpoints intentionally out of scope. This requires reviewer judgment; no automated test can verify that upstream evidence remains accurate. | `docs/openapi-contract-deltas.md` |
| Full package test command is green with generated types wired in | Run `swift test --disable-sandbox` after adding the generator/runtime dependencies and generated target. It cannot pass in this tests-only run because neither dependency nor generated target is permitted to be added. | Implementation-run evidence (not yet available) |

The first four rows are permanent regression coverage: all are part of the
normal `ColorMatchingLPSAppTests` target once the generated client target is
wired into `iOS/Package.swift`. No browser or live-server coverage is needed
because the network contract boundary is deliberately stubbed at the generated
runtime transport.
