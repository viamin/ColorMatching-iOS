# Issue #5: Generated OpenAPI Swift Client Plan

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Planned evidence |
| --- | --- | --- |
| Generator/runtime are package dependencies and the API document is reproducible | Focused package-input test | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testPackageDeclaresGeneratedClientAndVendoredOpenAPISpec` |
| Manifest and recent-sheet surfaces use the generated client | Permanent local-stub integration test | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testFetchesManifestAndRecentSheetsFromStubbedPublishedEndpoints` |
| Capture creation, measurement upload, and judgment upload use generated request types | Permanent local-stub integration tests | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsConformsToPublishedSchema`, and `testUploadJudgmentsEncodesPathAndPayload` |
| Ranked results use the generated client | Red-phase focused test for the missing public operation; promote to a local-stub integration test with the generated facade | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testAPIClientExposesRankedResultsOperation` |
| Contract deltas and endpoint gaps are disclosed in the PR | Inspectable human/external evidence | This document, based on `viamin/color_matching` main at `47057afd58f7d46b4b740ca7d2d08947774471` and its `/api/v1/openapi.json` source |

The tests use `URLProtocol` stubs, so they neither require nor contact a live Phoenix server.

## Published-spec deltas from `docs/color-matching-api-contract.md`

- The published spec exposes all seven expected routes, including ranked results, and declares bearer authentication. Its server URL is relative (`/`), so the iOS configuration must continue to supply an absolute base URL.
- The prose document describes a full manifest and ranked-results response. The OpenAPI schemas currently require only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` for a manifest, and only `schema_version` and `sheet_id` for ranked results. The remaining fields are rendered by Phoenix but are not typed by the document.
- The prose measurement payload includes `scoring_algorithm_version` and per-measurement `stats`; the published `MeasurementUploadRequest` schema declares neither. It requires `normalized_linear_rgb_median`, while the app currently models it as optional. The red assertions in `testUploadMeasurementsConformsToPublishedSchema` pin this mismatch.
- The prose says measurement and judgment uploads return `204`; the published spec defines `200` JSON responses with `capture_id` and count fields.
- The published capture request accepts either the prose-style nested `metadata` body or a legacy flat shape. The nested `quality` object is not required by the published schema. It also specifies `iso` as an integer, whereas the app currently uses `Float`.
- The prose example uses an opaque `capture_123`; Phoenix returns the database identifier serialized as a string.

## Endpoint gaps to resolve before the implementation PR is mergeable

1. Expand the server OpenAPI schemas for manifest and ranked-results to their actual rendered payloads, or explicitly scope the generated client to the documented subset and retain client-side adapters for the missing fields.
2. Decide whether measurement statistics and `scoring_algorithm_version` remain supported request fields. If so, add them to the OpenAPI schema; otherwise the generated client migration would silently stop submitting them.
3. Add a documented ranked-results client operation and its local-stub test. The app has no hand-written ranked-results method today despite the issue’s required surface.
