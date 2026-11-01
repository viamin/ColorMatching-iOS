# Issue #5 verification plan

This test-writing change maps each acceptance criterion to the smallest credible evidence. It deliberately remains red until the implementation run adds the generated client and published OpenAPI document.

| Criterion | Verification | Evidence at implementation completion |
| --- | --- | --- |
| SwiftPM includes `swift-openapi-generator` and `swift-openapi-runtime`, with the published document vendored or fetched | Focused unit/service test | `APIClientTests.testOpenAPIGenerationInputsCoverEveryAppSurface` reads `Package.swift` and `OpenAPI/color_matching.yaml`; it asserts both dependencies, generator use, and every required operation path. |
| Generated client serves manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local-stub client tests | `APIClientTests` supplies `URLProtocol` responses/requests for the five existing client paths. The red generation-input test asserts the ranked-results operation is in the spec; implementation must add its response stub once the published schema is known. |
| Hand-written transport models are replaced while client-only models stay local | Human/source review plus focused test | Inspect the generated client integration and confirm `MeasurementCore` analysis models remain application-owned. This is not settled by a broad suite. |
| No live server is needed | Permanent unit/service test | `MockURLProtocol` intercepts all API requests in `APIClientTests`. |
| Contract deltas and endpoint gaps are recorded in the PR | Human/external evidence | Compare the pinned OpenAPI document from `viamin/color_matching#110` with `docs/color-matching-api-contract.md` in the implementation PR description. |
| `swift test --disable-sandbox` is green | Command result | Run the exact command in `iOS/` after implementation. |

## Current red-phase result

`testOpenAPIGenerationInputsCoverEveryAppSurface` is intentionally red: the repository does not yet contain `iOS/OpenAPI/color_matching.yaml` or SwiftPM OpenAPI dependencies. The remaining endpoint tests use local `URLProtocol` stubs and must remain hermetic when the generated transport replaces the hand-written client.
