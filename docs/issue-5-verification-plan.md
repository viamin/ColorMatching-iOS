# Issue #5 verification plan

This is the tests-only (red) phase. The implementation phase must keep these
tests and make the package-wiring test pass after vendoring the published
OpenAPI document.

| Acceptance criterion | Smallest credible verification | Status in this phase |
| --- | --- | --- |
| Add the generator/runtime and obtain the specification | `APIClientTests.testPackageWiresGeneratedOpenAPIClientAndVendoredSpecification` checks both Swift package dependencies and the vendored document. | Expected failure until implementation |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Compile-time use of generated operations plus URLProtocol stub tests for every listed operation. The existing three write tests cover the current contract; implementation must add the missing generated-operation tests, including ranked results. | Not runnable until generated symbols exist |
| Replace hand-written API models while retaining client-only models | Code review of `APIClient.swift` and a clean compile after removing hand-written wire models. This is structural, not settled by a unit-test name. | Not run |
| Generated client works against local stubbed responses | `APIClientTests.testFetchesManifestAndRecentSheetsFromStubbedPublishedResponses` uses `MockURLProtocol`, never a live server. The implementation phase must route this and the write-operation tests through the generated client. | Passing baseline transport coverage |
| PR records prose-contract deltas and endpoint gaps | Human inspection of the PR description against the vendored published document and `docs/color-matching-api-contract.md`. Record any absent/changed schemas or routes rather than assuming parity. | Pending published document review |

The upstream issue is [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110).
Its repository serves the specification at `/api/v1/openapi.json`; the exact
deployment URL was not supplied here, so the implementation must pin the
document it fetches (or vendor it directly) and identify its revision in the
PR description before claiming contract-delta verification.
