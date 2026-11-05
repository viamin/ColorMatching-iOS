# Issue #5 OpenAPI client verification plan

This is the test-phase plan for replacing the hand-written `/api/v1` client. It
maps each acceptance criterion to direct, inspectable evidence; a broad green
suite is not used as a substitute.

| Criterion | Smallest credible verification | Evidence location | Current test-phase status |
| --- | --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime` | Focused package-declaration test | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Red: dependencies are not yet declared. |
| Fetch or vendor the upstream OpenAPI document | Inspect the pinned or vendored document and its source revision in the implementation PR | implementation artifact plus PR description | Blocked: `viamin/color_matching` is not readable from this environment, so #110 cannot be inspected during this run. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent local-stub integration tests, one request/response assertion per operation | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Existing local stubs cover capture/measurement/judgment; this run adds manifest/recent. Ranked-results coverage awaits the published OpenAPI operation and generated API names. |
| Replace hand-written API models while retaining client-only models | Code review of generated client diff and the remaining app model ownership | implementation diff | Not applicable in test-only phase. |
| No live server in CI | Local `URLProtocol` stubs in permanent XCTest coverage | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Covered. |
| Record prose-contract deltas and endpoint gaps | Human inspection of the published upstream OpenAPI document against `docs/color-matching-api-contract.md` | PR description | Not run: requires access to #110's document. |
| `swift test --disable-sandbox` is green | Run the exact command after implementation | CI/run output | Not run locally: the container does not include Swift. |

The tests are intentionally written against local responses so they remain
deterministic and do not require a Phoenix server or database.
