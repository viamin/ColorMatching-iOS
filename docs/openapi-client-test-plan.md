# OpenAPI Swift Client Verification Plan

This is the test-writing evidence for #5. The planned generated client must
retain the app-facing behavior exercised by `APIClientTests`, while replacing
the hand-written wire models with generated OpenAPI types.

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Generator/runtime and published document are added | Inspect `iOS/Package.swift`, vendored/fetched OpenAPI document, and generated target at the implementation PR head | Blocked: `viamin/color_matching#110`'s artifact is not available to this checkout |
| Manifest and recent sheets use generated types | Permanent local-stub tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Added; must be run after Swift tooling is available |
| Capture creation, measurement upload, and judgment upload use generated types | Existing permanent local-stub tests in `APIClientTests.swift` | Present; must be run after Swift tooling is available |
| Ranked results uses generated types | Permanent local-stub test with an example response from the published spec | Blocked: the prose contract deliberately omits a response schema |
| No hand-written API models remain | Inspect the implementation diff and generated sources | Not applicable in the tests-only phase |
| Contract deltas and endpoint gaps appear in the PR description | Human inspection of PR body against the published OpenAPI document | Blocked: upstream OpenAPI document is unavailable |
| `swift test --disable-sandbox` is green | Run the named command in an environment containing Swift | Not run: `swift` is not installed in this container |

## Fixtures and boundaries

The permanent API tests use `MockURLProtocol` only, so they never need a live
Phoenix server. The manifest fixture intentionally contains the fields this
app consumes; extra server provenance fields remain a generated-client/schema
compatibility concern once the upstream OpenAPI artifact is available.

## Known contract gap before implementation

`docs/color-matching-api-contract.md` names
`GET /api/v1/test_sheets/:sheet_id/ranked_results` but defines neither its
response body nor a Swift-facing result model. A ranked-results client test
cannot be credibly authored until #110 publishes that schema. The
implementation PR must record the actual schema and any deltas from the prose
contract.
