# Issue #5 — generated OpenAPI client PR plan

## Criterion-to-verification map

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Add generator/runtime and obtain the server document | `OpenAPIGenerationContractTests.testPackageWiresAppleOpenAPIGeneratorAndRuntime` and `testVendoredSpecificationCoversEveryAppAPIEndpoint` | Red: the dependency wiring and vendored document do not exist yet. |
| Generate the six app-used endpoint surfaces | The endpoint inventory assertion against the vendored OpenAPI document, followed by compile-time use of the generated operations in the implementation PR | Red: document unavailable pending `viamin/color_matching#110`. |
| Replace hand-written server models while retaining client-only models | Implementation PR compile plus focused local-stub client tests | Not yet implemented. |
| Stubbed Swift tests, no live server | `APIClientTests` uses `MockURLProtocol`; manifest and recent-sheet tests were added here, and the existing capture/measurement/judgment tests cover the remaining current flows | Passing for the existing hand-written adapter; implementation must retain this no-network seam while using generated types. |
| PR description records contract deltas and endpoint gaps | Inspect the published upstream OpenAPI document and record the comparison in the implementation PR description | Blocked on `viamin/color_matching#110`; not automatable from this repository. |

## Required implementation evidence

The implementation PR must run `swift test --disable-sandbox` and cite the result. It must additionally include compile-time tests that instantiate and decode the generated operation input/output types for all six routes above; the tests in this PR intentionally avoid importing a not-yet-generated module so that this red-phase commit remains buildable.

## Contract comparison baseline

The local prose contract currently defines all six routes. The app uses the first five for capture/upload workflow; ranked results is specified but has no client method or caller today. The upstream OpenAPI document is the authority once `viamin/color_matching#110` is available. Do not claim a field-level delta until that document is vendored and compared.

Known gap to resolve in the implementation PR: determine whether ranked-results should be generated but intentionally unused (the issue asks for its client surface) or wired into a visible app flow. The issue's non-goals prohibit changing scoring behavior, so the expected initial treatment is generated-but-unused unless the published API requires otherwise.
