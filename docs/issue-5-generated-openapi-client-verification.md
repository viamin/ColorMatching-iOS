# Issue #5 verification plan

This is the tests-only (red) phase for replacing the iOS hand-written API
layer. The upstream OpenAPI document from `viamin/color_matching#110` is not
available in this checkout, so neither a real-spec comparison nor generated
types can be claimed yet.

| Criterion | Smallest credible verification | Current phase status |
| --- | --- | --- |
| Generator and runtime are package dependencies | `GeneratedOpenAPIIntegrationTests.testPackageUsesOpenAPIGeneratorAndRuntimeForTheAppClient` | Red: dependencies are absent |
| A vendored/fetched document covers all app surfaces | `GeneratedOpenAPIIntegrationTests.testVendoredOpenAPIDocumentDeclaresEveryAppSurface` checks the six required paths | Red: document is absent |
| Generated client handles existing manifest/recent/capture/measurement/judgment flows without a live server | The permanent `APIClientTests` stub each used HTTP surface. The implementation phase must route this façade through generated types; the tests remain local-stub tests. | Manifest and recent coverage added; generator wiring remains red |
| Ranked-results client surface | The vendored document test requires `/api/v1/test_sheets/{sheet_id}/ranked_results`; add a local-stub client test when the published response schema is available. | Blocked by upstream response schema |
| Contract deltas and endpoint gaps | Compare the vendored document byte-for-byte/semantically with `docs/color-matching-api-contract.md`, then record the result in the implementation PR description. | External evidence pending #110 |

## Known pre-implementation gap

The prose contract names ranked results but deliberately gives no response JSON
shape. A typed ranked-results test cannot be honestly specified until the
published OpenAPI document supplies that schema. The other five request
surfaces have local, deterministic stub coverage and do not contact a live
server.
