# OpenAPI Client Migration: Test Plan

This is the test-first plan for #5. The implementation must vendor the OpenAPI
3 document published by `viamin/color_matching#110` under
`iOS/Sources/ColorMatchingAPI/openapi.yaml` and generate a typed client using
the Swift OpenAPI Generator plugin. The configured generated target is expected
to be named `ColorMatchingAPI`.

## Acceptance evidence plan

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generator/runtime dependencies and a vendored spec | Focused unit test checks the package, generator configuration, and each required path in the vendored spec. It starts red until the generated target is configured. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testOpenAPIClientGenerationConfigurationCoversEveryAppAPIEndpoint` |
| Manifest and recent-sheet client surfaces | Permanent local-stub tests verify decoded typed responses and requests without a live Phoenix server. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testFetchManifestDecodesStubbedGeneratedClientSurface`, `...:testFetchRecentSheetsDecodesStubbedGeneratedClientSurface` |
| Capture creation, measurement upload, and judgment upload | Existing permanent local-stub tests assert the request paths and payloads. The implementation must move these tests to invoke the generated-client-backed facade. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testCreateCaptureEncodesMetadataAndQuality`, `...:testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `...:testUploadJudgmentsEncodesPathAndPayload` |
| Ranked-results endpoint | The focused generation guard requires the OpenAPI path. Add a permanent stubbed response test when the generated operation's response model is known from the vendored spec. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testOpenAPIClientGenerationConfigurationCoversEveryAppAPIEndpoint` |
| Contract deltas | Human/external evidence: compare the vendored revision of `/api/v1/openapi.json` with `docs/color-matching-api-contract.md`, and put the exact fields, enums, status codes, and endpoint gaps in the implementation PR description. | Upstream source: `viamin/color_matching#110`, merged as PR #113 |

## Upstream evidence already inspected

`viamin/color_matching#110` is closed and its implementation was merged as
`viamin/color_matching#113`. Its router publishes the document at
`GET /api/v1/openapi.json` and declares all six paths this client needs.

No exact prose-contract delta is recorded here because this tests-only change
does not vendor a pinned OpenAPI artifact. The implementation PR must compare
against that pinned artifact; claiming a delta before that comparison would not
be inspectable evidence.
