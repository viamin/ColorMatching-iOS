# Generated OpenAPI Client Migration: Verification Plan

Issue: #5 — Replace the handwritten iOS API layer with a generated OpenAPI Swift client.

This is the red-test phase. No implementation or package-manifest changes are included in this commit.

## Criterion-to-verification map

| Criterion | Smallest credible verification | Test / evidence | Initial state |
| --- | --- | --- | --- |
| Package uses `swift-openapi-generator` and `swift-openapi-runtime`; an upstream OpenAPI document is vendored | Focused configuration test | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedOpenAPIClientConfigurationTests.swift` | Failing until the package and `iOS/OpenAPI/color-matching-api.yaml` are added |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Focused contract-surface test against the vendored document | `GeneratedOpenAPIClientConfigurationTests.testPackageAndVendoredSpecConfigureGeneratedClientForEveryUsedEndpoint` | Failing until the published spec contains all six paths |
| App client preserves manifest and recent-sheet behavior using local responses | Permanent unit/service tests with `URLProtocol` stubs | `APIClientTests.testFetchManifestDecodesTheStubbedManifest`; `APIClientTests.testFetchRecentSheetsDecodesTheStubbedResponse` | Passing against the current wrapper; implementation must retain these observable behaviors while delegating wire types to generated code |
| Generated client is exercised without a live server for capture creation, measurement upload, and judgment upload | Permanent unit/service tests with `URLProtocol` stubs | Existing `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, and `testUploadJudgmentsEncodesPathAndPayload` | Passing against the current wrapper; implementation must route them through generated operations |
| Prose-contract deltas and endpoint gaps are recorded in the PR | Inspectable external evidence from the final published upstream spec | PR description, based on the pinned/vendored source revision | Not runnable in this phase: viamin/color_matching#110 is the source of truth and no published spec is present in this repository |

## Required implementation evidence

The implementation PR must pin the upstream spec revision (or record its source URL and checksum), regenerate in a reproducible command, and update the PR description with a concise delta table:

| Area | Prose contract | Published spec | Resolution |
| --- | --- | --- | --- |
| Manifest | Pending comparison | Pending comparison | Pending comparison |
| Recent sheets | Pending comparison | Pending comparison | Pending comparison |
| Capture creation | Pending comparison | Pending comparison | Pending comparison |
| Measurements and scores | Pending comparison | Pending comparison | Pending comparison |
| Judgments | Pending comparison | Pending comparison | Pending comparison |
| Ranked results | Prose endpoint has no response schema | Pending comparison | Confirm response schema and app-use gap |

`ranked_results` is a known current app gap: the app ranks local capture data and does not currently invoke the prose-contract endpoint. The generated client must still include the operation required by the issue; adding UI behavior is out of scope.
