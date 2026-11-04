---
module: ios-api
tags: [openapi, swift, testing]
problem_type: test-plan
---

# Issue #5 generated OpenAPI client verification plan

This document records criterion-level verification planned before implementation. It is intentionally a red-phase artifact: the assertions describe the published provider contract and fail until the generated client replaces the hand-written wire models.

| Criterion | Smallest credible verification | Status in this test-writing change |
| --- | --- | --- |
| Package uses `swift-openapi-generator` and `swift-openapi-runtime`; published document is fetched or vendored | `GeneratedOpenAPIClientAcceptanceTests.testVendoredOpenAPISpecDefinesEveryAppOperation` verifies the vendored document and every app-consumed operation. Package dependency/plugin wiring is implementation review evidence. | Red: document is not yet vendored. |
| Generated client handles manifest and recent sheets without a live server | `GeneratedOpenAPIClientAcceptanceTests.testManifestAndRecentSheetsDecodeLocalPublishedResponses` uses `URLProtocol` stubs. | Green against the existing public API façade; it must remain green once the façade delegates to generated types. |
| Generated client handles capture creation and measurement upload | `APIClientTests.testCreateCaptureEncodesPublishedFlatCapturePayload` and `APIClientTests.testUploadMeasurementsEncodesPublishedFlatMeasurementPayload` use local stubs and assert provider payloads. | Red: the hand-written client emits the retired nested payloads. |
| Generated client handles judgment upload and ranked results | Existing `APIClientTests.testUploadJudgmentsEncodesPathAndPayload` covers judgments via a local stub. The vendored-spec test requires the ranked-results operation, which has no app-facing method yet. Add a typed ranked-results stub test with the generated operation in the implementation run. | Ranked typed-client test not yet possible without introducing a compile-failing reference to a non-existent generated operation. |
| Prose-to-published-spec deltas and gaps are recorded in the PR | Inspectable external evidence: upstream `viamin/color_matching` issue #110 and the provider controller tests are compared below; final PR description must carry these deltas. | Not automatable. |

## Published-spec deltas found

Source inspected: `viamin/color_matching` `main`, issue #110's published endpoint (`GET /api/v1/openapi.json`) and provider controller tests on 2026-11-04.

- Capture creation is flattened (`device_model`, `detected_marker_count`, `rejection_reasons`, and related fields); the prose contract specifies nested `metadata` and `quality` objects. The provider names exposure `exposure_duration`, not `exposure_duration_seconds`.
- Measurement upload has flat measurement statistics and uses `score` for pair scores. The prose contract nests stats, sends `distance` and `similarity`, and adds a top-level `scoring_algorithm_version`.
- Measurement and judgment endpoints return `200` response summaries; the prose contract implies no-content responses for uploads.
- The published ranked-results operation has a concrete `lps-ranked-results/v1` response with results, aggregate score data, capture provenance, printer profile, and algorithm versions. The prose contract only describes this response narratively.
- The published manifest includes `created_at` and `printer_profile` fields. The current client-side `SheetManifest` ignores both. The prose's printer-profile field names do not match the provider's (`printer_make_model`, `paper_type`, `ink_type`).

## Endpoint gap

The iOS app currently has no ranked-results call or UI consumer even though the issue requires a generated surface for it. The implementation must expose the generated typed operation without changing capture/scoring behavior.
