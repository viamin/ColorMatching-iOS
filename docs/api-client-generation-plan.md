---
title: "OpenAPI client generation plan and contract delta record"
date: "2026-11-04"
module: "iOS/ColorMatchingLPSAppCore"
problem_type: "integration_contract"
tags:
  - openapi
  - swift
  - api-client
  - color-matching
---

# OpenAPI Client Generation Plan

This records the test-first plan for issue #5. The implementation run must vendor the upstream OpenAPI document at the upstream main revision `47057afd58f7d46b4d4b740ca7d2d08947774471`, add `swift-openapi-generator` and `swift-openapi-runtime`, generate only the operations below, and replace server-owned hand-written models with the generated types. `MeasurementCore` domain models and camera-only state remain client-owned.

## Criterion-to-verification map

| Criterion | Smallest credible verification | Location/status in this test phase |
| --- | --- | --- |
| Generated package and vendored document | Inspect `Package.swift`, vendored spec, and generated source after regeneration | Not run: implementation-owned files are prohibited in this phase. |
| Manifest and recent sheets | Permanent local `URLProtocol` stubs exercise authenticated GET request and typed decoding | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testFetchManifestDecodesPublishedManifestFromLocalStub`, `testFetchRecentSheetsDecodesPublishedResponseFromLocalStub`) — passing once the existing suite can run. |
| Capture creation, measurement upload, judgment upload | Permanent local stubs assert path, authorization, and JSON payload | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload`) — passing once the existing suite can run. |
| Ranked results | Permanent local stub must assert the generated operation’s typed ranked-results response | `testFetchRankedResultsFromLocalStub` is deliberately red until the generated operation is exposed through `APIClient`. |
| Contract deltas and endpoint gaps | Inspect upstream OpenAPI-producing source at the pinned revision and this record; human review of the vendored generated document remains required | Recorded below. |

The local stubs are permanent because these operations are the recurring app-to-server boundary. No live server is used.

## Upstream source inspected

`viamin/color_matching#110` is closed. At the pinned upstream revision, `GET /api/v1/openapi.json` is served by `ColorMatchingWeb.OpenApiController`; relevant route declarations are in `lib/color_matching_web/router.ex`, operation schemas in `lib/color_matching_web/api_schemas.ex`, and response rendering in `lib/color_matching_web/controllers/test_sheet_json.ex`.

## Contract deltas and endpoint gaps

- The prose contract describes a rich manifest and ranked-results payload. The published OpenAPI schema currently constrains only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` for manifests, and only `schema_version` and `sheet_id` for ranked results. The rendered responses contain many additional fields. Generated models therefore cannot be strongly typed for all fields until the upstream schema is completed; this is an endpoint/schema gap, not a client inference opportunity.
- Capture creation accepts both legacy flattened attributes and the prose contract’s nested `metadata`/`quality` form. The nested metadata schema requires `image_width` and `image_height`; the current hand-written Swift model makes both optional. `iso` is an integer upstream while the Swift model uses `Float`.
- Measurement upload upstream requires `normalized_linear_rgb_median`, permits RGB arrays, RGB objects, or JSON-encoded strings, and returns a JSON acknowledgement with capture and row counts. The prose contract additionally specifies measurement statistics and top-level `scoring_algorithm_version`; neither appears in the published measurement-upload schema. The current client accepts a `204` and discards the documented response.
- Judgment upload likewise returns a JSON acknowledgement with `capture_id` and `judgment_count`, while the current client only checks a successful status.
- The upstream generated spec includes several unrelated palette and legacy `/api` endpoints. They are deliberately outside this issue’s generated surface.

## Implementation handoff

Replace the ranked-results sentinel test with a local `URLProtocol` response that includes the fields guaranteed by the vendored spec. Extend it as upstream makes its ranked-results schema complete. Update the other local stubs to instantiate generated request/response types rather than the hand-written API-layer models. Do not use these tests as proof of the human inspection criterion; the vendored spec and generation diff must be inspected separately.
