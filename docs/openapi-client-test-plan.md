# OpenAPI Swift client: verification plan and PR evidence

This is the criterion-level plan for issue #5's implementation run. The
permanent XCTest suite uses `URLProtocol` stubs; it never contacts a live
Phoenix server.

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generator/runtime dependencies and a reproducible API input are present | Focused XCTest checks the package declarations and vendored spec paths for all six app operations. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testGeneratedClientConfigurationVendorsSpecAndDeclaresRequiredOperations` |
| Manifest and recent-sheet reads use generated types | Permanent local-stub XCTest decodes both provider response shapes. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testFetchManifestAndRecentSheetsDecodeStubbedResponses` |
| Capture creation, measurement upload, and judgment upload use generated request types | Permanent local-stub XCTest verifies request path, authorization, and JSON payloads. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload` |
| Ranked results are generated and available to the app | Vendored spec must include the ranked-results operation; the implementation run must add a local-stub XCTest that exercises the generated operation and response type. | `testGeneratedClientConfigurationVendorsSpecAndDeclaresRequiredOperations` (red until the input exists) |
| The prose contract deltas are recorded | Human-reviewable comparison below, based on `viamin/color_matching` issue #110 and its currently published router/schema source. | This document |

## Published-contract deltas for the PR description

The OpenAPI producer is served dynamically at `GET /api/v1/openapi.json`; the
provider repository does not commit a static OpenAPI document. The iOS package
must therefore vendor a downloaded JSON snapshot at
`iOS/OpenAPI/color_matching.openapi.json` and make regeneration explicit.

- The provider's manifest schema only requires `schema_version`, `sheet_id`,
  and `capture_profile.scoring_algorithm_version`; the prose document describes
  many additional manifest fields. The client must retain only fields required
  by app behavior, while generated types represent the published contract.
- `POST /captures/:capture_id/measurements` and
  `POST /captures/:capture_id/judgments` return 200 JSON acknowledgements
  containing counts and `capture_id`. The hand-written iOS client currently
  treats every 2xx response as bodyless, and its existing tests stub 204.
- Capture creation accepts either the prose document's nested `metadata` form
  or a legacy flat form. The generated client should use the nested form the
  app already sends.
- Measurement RGB payloads may be arrays, `{r,g,b}` objects, or JSON strings;
  pair scores accept `score`, `similarity`, or `distance`. The app's current
  object RGB and distance/similarity payload remains one compatible branch.
- Ranked results are now documented as a response with
  `schema_version: lps-ranked-results/v1`; the prose contract names the
  endpoint but provides no response schema. Its full row shape is currently
  underspecified by the provider's OpenAPI schema, so the generated client can
  expose only the guaranteed envelope until the provider tightens that schema.

## Endpoint gap to carry in the PR

The OpenAPI contract covers all six routes the app needs, but the
`RankedResults` schema currently guarantees only `schema_version` and
`sheet_id`. Before the app consumes ranking rows, viamin/color_matching needs
to publish the row fields (source colours, scores, labels, capture provenance,
printer profile, and algorithm version) described by the prose contract.
