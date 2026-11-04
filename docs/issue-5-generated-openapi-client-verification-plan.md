# Issue #5: Generated OpenAPI Client Verification Plan

This test-writing change defines the verification required before replacing the hand-written iOS API layer. The upstream OpenAPI document is a dependency of the implementation: the public GitHub API currently returns `404` for `viamin/color_matching` pull request 110, so its operation identifiers and response schemas cannot yet be asserted without inventing a contract.

| Criterion | Smallest credible verification | Evidence at implementation time |
| --- | --- | --- |
| Generated client and runtime are included, with a vendored/fetched spec | Package resolution plus a source-control assertion that the generated module is imported by the app adapter | `iOS/Package.swift`, vendored spec, generated source/module import |
| Manifest and recent-sheet operations use generated types | Permanent local-stub test decoding both responses through the app adapter | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testFetchesManifestAndRecentSheetsFromLocalStubs` |
| Capture creation, measurement upload, and judgment upload use generated types | Permanent local-stub tests asserting typed request payloads and successful responses | `APIClientTests.swift:testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, and `testUploadJudgmentsEncodesPathAndPayload` |
| Ranked-results operation uses generated types | Permanent local-stub test asserting the generated operation reaches the documented route | `APIClientTests.swift:testFetchesRankedResultsFromALocalStub` |
| Prose-contract deltas and endpoint gaps are recorded in the PR | Human inspection of the published OpenAPI document against `docs/color-matching-api-contract.md` | PR description with an explicit delta/gap table; cannot be established by a unit test |
| `swift test --disable-sandbox` is green | Run the exact command after generated source and adapter are present | Captured command result in the implementation run |

The tests use `MockURLProtocol`, so they exercise local stubbed HTTP responses and do not require a live Phoenix server. The ranked-results test is expected to remain red until the generated-client adapter exposes that operation.

## Contract-delta baseline

The prose contract specifies paths and payload examples for all six required surfaces, but it leaves the `ranked_results` response deliberately unspecified. Do not infer generated Swift names, required fields, or a result schema from that prose. Compare those details with the published OpenAPI document during implementation and record each difference in the PR description.
