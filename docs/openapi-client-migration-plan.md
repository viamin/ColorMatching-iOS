# OpenAPI Client Migration Plan

## Criterion verification plan

| Criterion | Smallest credible verification | Evidence target |
| --- | --- | --- |
| Generator/runtime and published document are integrated | Focused package/spec integration test | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testGeneratedOpenAPIInputsDeclareEveryUsedSurface` |
| Manifest and recent-sheet reads use typed client decoding | Permanent local-stub unit tests | `APIClientTests.testFetchManifestDecodesLocalStubResponse`, `APIClientTests.testFetchRecentSheetsDecodesLocalStubResponse` |
| Capture, measurement, and judgment writes use typed client encoding | Permanent local-stub unit tests | `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `APIClientTests.testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `APIClientTests.testUploadJudgmentsEncodesPathAndPayload` |
| Ranked-results surface is generated | Focused package/spec integration test asserting the published operation exists | `APIClientTests.testGeneratedOpenAPIInputsDeclareEveryUsedSurface` |
| Prose-contract deltas and endpoint gaps are reported | Inspectable comparison of the published document with `docs/color-matching-api-contract.md` | PR description, after the dependent repository's published spec is available |

## External dependency status

As of this test-writing run, `viamin/color_matching#110` could not be inspected: the unauthenticated GitHub API returned a rate-limit response. No server schema has been copied or reconstructed from the prose contract. The implementation run must obtain the published OpenAPI document and record its immutable source (commit URL and SHA) before adding it at `iOS/OpenAPI/color-matching.yaml`.

## Required implementation outcome

The implementation must add `swift-openapi-generator` and `swift-openapi-runtime`, configure generated types/client code from the vendored document, and migrate the API boundary away from hand-written transport models. The red test intentionally requires those package inputs and all six app-used API paths; it currently fails before any production implementation is changed.

The stubbed tests remain permanent because the app's request/response mapping is a recurring user flow. They use `URLProtocol` and no live Phoenix server.
