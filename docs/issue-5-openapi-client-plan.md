---
title: "Issue #5 OpenAPI client verification plan"
module: "iOS"
tags:
  - "openapi"
  - "swift"
  - "api-client"
problem_type: "implementation_plan"
---

# Issue #5 OpenAPI client verification plan

This tests-only change establishes the red-phase contract for replacing the
hand-written iOS API layer. The implementation change must vendor the upstream
OpenAPI document at `iOS/Specs/color_matching.openapi.json`, generate the typed
client, and make `APIClient` delegate its network operations to that client.

| Criterion | Smallest credible verification | Current red-phase evidence |
| --- | --- | --- |
| Package includes generator/runtime and a vendored upstream spec | Unit test loads the vendored OpenAPI JSON and asserts every iOS operation path | `OpenAPIContractTests.testVendoredSpecDefinesEveryCompanionAppOperation` (fails until the spec is vendored) |
| Generated types cover manifest and recent sheets | Local `URLProtocol` stubs decode generated-client responses through the app adapter | `APIClientTests.testFetchManifestDecodesLocalStubResponse`; `APIClientTests.testFetchRecentSheetsDecodesLocalStubResponse` |
| Generated types cover capture creation, measurement upload, and judgment upload | Local `URLProtocol` stubs verify operation paths, authorization, request bodies, and typed responses | Existing `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, and `testUploadJudgmentsEncodesPathAndPayload` must be retained and switched to generated-client assertions during implementation |
| Generated types cover ranked results | Local `URLProtocol` stub decodes a ranked-results response through the generated client | Not yet implementable: the app has no ranked-results operation or client-side result model. Add this permanent test with the generated client implementation. |
| Prose-contract deltas and endpoint gaps are recorded for review | Inspect the published upstream OpenAPI document and include the comparison in the implementation PR description | External evidence: `viamin/color_matching@47057afd58f7d46b4d4b740ca7d2d08947774471`, served by `GET /api/v1/openapi.json` |

## Published-spec deltas to include in the implementation PR

- `POST /captures/{capture_id}/measurements` accepts `measurements` and
  `pair_scores`; it does **not** define the prose contract's
  `scoring_algorithm_version`, measurement `stats`, or a required score shape
  beyond `pair_id`, `algorithm_version`, and one of `score`, `similarity`, or
  `distance`.
- Measurement and judgment uploads return `200` JSON summaries with capture and
  count fields, whereas the prose contract leaves their response body unstated.
- Capture creation accepts either legacy flat attributes or the iOS nested
  `metadata` shape. Its response is compatible (`capture_id`).
- The published `Manifest` schema declares only `schema_version`, `sheet_id`,
  and `capture_profile`; the app requires page geometry, markers, patches,
  pairs, and a manifest URL. The server renderer supplies those fields, but the
  OpenAPI schema does not yet make them typed/required.
- The published `RankedResults` schema declares only `schema_version` and
  `sheet_id`, while the renderer supplies profiles, aggregate statistics, and
  ranked pairs. This is an endpoint-schema gap that prevents a useful fully
  typed ranked-results model until upstream expands the schema.
