# Issue #5 OpenAPI client verification plan

This is the criterion-level plan for replacing the iOS app's hand-written
`/api/v1` transport models with a generated Swift OpenAPI client.

## Acceptance-criterion mapping

| Criterion | Smallest credible verification | Current red-phase evidence |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and obtain the upstream OpenAPI document | Focused package-manifest assertion, then inspect the committed/fetched OpenAPI input and generated-source diff. | `APIClientTests.testPackageDeclaresGeneratedOpenAPIClientDependencies` intentionally fails until the two package dependencies are declared. |
| Generate types for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent local-stub API-client tests, one per operation, compiled against generated operation/types. | Existing capture/measurement/judgment tests cover the current wire behavior; new manifest/recent tests cover local stubs. Ranked-results coverage cannot be written against a missing generated operation and is a required implementation follow-up. |
| Replace hand-written API models while retaining client-side measurement models | Code review of the generated source and API adapter, plus compilation of all call sites. | Not run: implementation is intentionally forbidden in this test-writing phase. |
| No-live-server generated-client tests | Execute `swift test --disable-sandbox` and inspect `MockURLProtocol` stubs. | The added manifest/recent tests and existing write-operation tests use `MockURLProtocol`; the generated client is not yet wired in. |
| PR description records prose-contract deltas and endpoint gaps | Inspect the upstream published OpenAPI document and compare it with `docs/color-matching-api-contract.md`; record findings in the implementation PR description. | External evidence obtained: upstream issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) is closed and its controller test lists all seven required sheet/capture paths. The deployed spec endpoint was not resolvable from this environment, so exact schema deltas are not yet verified. |

## Known comparison scope

The prose contract lists the six implemented calls and describes ranked results
without a response schema. The upstream OpenAPI controller test confirms that
the published API has the corresponding seven paths, including
`/api/v1/test_sheets/{sheet_id}/ranked_results`. The implementation PR must
compare field requirements, nullability, enums, errors, and ranked-results
response fields against the served document before claiming the deltas are
complete.

## Test-phase boundary

The package assertion is deliberately red: `iOS/Package.swift` has neither
OpenAPI dependency. This test phase may not alter production source or package
configuration. The implementation run must make it green and extend stubbed
tests to use the generated operations, including ranked results.
