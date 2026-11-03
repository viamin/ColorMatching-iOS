# Issue #5 OpenAPI Client Verification Plan

This test-writing change records the smallest credible verification for each
acceptance criterion before the generated-client implementation begins.

| Criterion | Verification | Status in this phase |
| --- | --- | --- |
| `swift-openapi-generator` and `swift-openapi-runtime` are installed and the upstream OpenAPI document is fetched or vendored | Inspect `iOS/Package.swift`, the checked-in OpenAPI source, and a generated-source regeneration diff. This requires the published document from `viamin/color_matching#110`. | Not run: no upstream OpenAPI document is available in this checkout. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent `APIClientTests` local-stub tests assert every request path, authentication, payload, and response used by the adapter. The implementation must make the adapter invoke generated operations/types. | Capture, measurement, and judgment request coverage existed; manifest and recent-sheet stub-response coverage is added here. Ranked-results coverage is blocked because no public client operation exists yet. |
| Hand-written API models are replaced while client-side models remain | Inspect the generated source and `APIClient.swift`; compile the app and tests. This is a structural review, not evidence a broad test suite can establish. | Not run: implementation is intentionally out of scope for this tests-only phase. |
| Swift tests use local stubbed responses, with no live server in CI | Permanent XCTest coverage in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` uses `MockURLProtocol`; the tests call no host outside `example.test`. | Ready to run. |
| PR description records prose-contract deltas and endpoint gaps | Compare `docs/color-matching-api-contract.md` to the exact vendored upstream OpenAPI revision; record each field, enum, status-code, and endpoint difference in the PR description. | Not run: the dependency issue's published specification is unavailable here, so differences cannot be truthfully inferred. |

The implementation run must add a ranked-results local-stub test at the same
time as the generated operation is introduced. It must also replace the
provisional contract fixture in these tests with one derived from the vendored
upstream OpenAPI document when that document is available.
