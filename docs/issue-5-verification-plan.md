# Issue #5 Verification Plan

This is the tests-only phase for replacing the hand-written iOS API layer with
a generated OpenAPI Swift client. The implementation run must keep these tests
green and replace the temporary red artifact check with real generated-client
imports if the generator's emitted module makes that possible.

| Criterion | Smallest credible verification | Status in this phase |
| --- | --- | --- |
| Package has `swift-openapi-generator` and `swift-openapi-runtime`; a generated client is checked in | `APIClientTests.testGeneratedClientArtifactsCoverEveryUsedOperation` inspects the package declaration and generated source for every app operation | Red: dependencies and generated source are absent |
| Generated client can decode/use manifest and recent-sheet APIs without a live server | `APIClientTests.testFetchesManifestAndRecentSheetsFromStubbedResponses` uses `MockURLProtocol` and representative JSON | Green against the current wrapper; implementation must route it through generated types |
| Capture creation, measurement upload, and judgment upload remain compatible | Existing `APIClientTests` request/response stub tests | Green against the current wrapper; implementation must route them through generated types |
| Ranked-results operation is generated | The generated-artifact operation check requires `ranked_results` | Red: no current API method or generated operation |
| Contract deltas versus the published spec are recorded in the PR | Human/external comparison against the vendored, revision-pinned OpenAPI document | Not run: issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) is closed, but its public repository tree did not expose a retrievable OpenAPI document at planning time. The implementation PR must cite the exact spec URL and revision before declaring this criterion passed. |

The stubbed tests are permanent regression coverage: they isolate HTTP request
construction and decoding while ensuring CI does not depend on a live Phoenix
server. They intentionally cover every endpoint the app currently invokes.

## Initial contract-gap inventory

The prose contract names a `GET /api/v1/test_sheets/:sheet_id/ranked_results`
endpoint but supplies no response schema. The app currently ranks locally and
does not issue that request. The published spec must determine whether this is
an app endpoint gap, a prose-only future endpoint, or an endpoint whose models
need to be adopted during implementation.
