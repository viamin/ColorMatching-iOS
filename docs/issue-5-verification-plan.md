# Issue #5 verification plan

This is the tests-only phase. The implementation run must retain the tests below
while replacing the hand-written transport models with generated OpenAPI types.

| Criterion | Smallest credible evidence | Status in this phase |
| --- | --- | --- |
| Generator, runtime, and published document are included | `OpenAPIContractTests.testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies` plus `testVendoredOpenAPISpecDeclaresEveryCompanionSurface` | Red: dependencies and vendored JSON do not exist yet. |
| Manifest and recent sheets use the typed client | Local `URLProtocol` tests in `APIClientTests`, with representative server responses | Covered by permanent tests; the implementation must route the facade through generated operations. |
| Capture, measurements, and judgments use the typed client | Existing local `URLProtocol` tests in `APIClientTests` | Covered by permanent tests; the implementation must route the facade through generated operations. |
| Ranked results are generated and usable | A local stubbed response test added with the generated-operation integration | Not covered: the app currently has no ranked-results API call, despite the prose contract listing it. |
| Prose-contract deltas and endpoint gaps are in the PR description | Inspect the fetched `GET /api/v1/openapi.json` artifact against `docs/color-matching-api-contract.md` and attach the comparison to the PR | External/manual evidence required after the real document is vendored. |

The vendor location is intentionally fixed at
`iOS/OpenAPI/color-matching-openapi.json`: the upstream issue specifies that the
published endpoint is JSON (`GET /api/v1/openapi.json`), so a JSON artifact makes
the generator input and the contract-surface test directly inspectable.

Known gap to resolve or explicitly record: the prose contract names
`GET /api/v1/test_sheets/:sheet_id/ranked_results`, but the iOS app currently
neither calls it nor has a hand-written response model. The generated-client PR
must either wire it into the existing ranking display without altering behavior,
or record why it remains outside the app's used surface.
