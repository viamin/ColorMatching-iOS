# Issue #5 verification plan

This tests-only change establishes the regression coverage that the generated
OpenAPI client implementation must satisfy. The tests use `URLProtocol` local
stubs and never contact a Phoenix server.

| Criterion | Smallest credible verification | Evidence location | Current state |
| --- | --- | --- | --- |
| Generated client covers manifest and recent sheets | Decode stubbed representative manifest and recent-sheet responses and assert request paths/authentication. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Passing against the current adapter; the implementation run must replace its hand-written wire types with generated types without weakening these tests. |
| Generated client creates a capture session | Assert the locally stubbed `POST` path, bearer token, and encoded metadata/quality. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Passing existing permanent test. |
| Generated client uploads measurements and judgments | Assert locally stubbed payloads and endpoint paths. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Passing existing permanent tests. |
| Generated client covers ranked results | A focused stub test can only be added after the upstream OpenAPI document is available and defines its concrete response schema. | Upstream `viamin/color_matching#110` | Not run: issue dependency/spec was unavailable from this environment (GitHub API returned HTTP 403). The present iOS app also has no ranked-results call site. |
| Prose-contract deltas are recorded in PR description | Inspect the vendored/fetched OpenAPI document beside `docs/color-matching-api-contract.md`; record each field/path/enum difference and endpoint gap in the implementation PR. | Implementation PR body | Not run: the required published document could not be retrieved in this tests-only run. |
| `swift test --disable-sandbox` remains green | Run the package suite. | Command output in this run | Pending |

## Known pre-implementation gap

The prose contract specifies `GET /api/v1/test_sheets/:sheet_id/ranked_results`,
but the present `APIClient` and app call sites only fetch manifests/recent sheets
and create/upload captures. The implementation PR must either add a generated
ranked-results surface when the published specification defines it, or explicitly
record why that endpoint remains outside the app's used surface.
