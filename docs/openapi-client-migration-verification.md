---
module: ios-companion
tags: [openapi, api-client, verification]
problem_type: implementation-plan
---

# OpenAPI client migration verification plan

This plan accompanies issue #5's tests-only phase. The published server source
was inspected at `viamin/color_matching` issue #110 on 2026-11-01. Its OpenAPI
document is served by `GET /api/v1/openapi.json`; this repository must vendor a
snapshot before code generation so CI does not depend on a live service.

## Acceptance criteria and evidence

| Criterion | Smallest credible verification | Evidence status |
| --- | --- | --- |
| Generator/runtime and vendored document are included | Focused unit test reads `iOS/Package.swift` and verifies the vendored document path. | Red: `APIClientTests.testPackageDeclaresGeneratedClientDependenciesAndVendoredSpec` |
| Manifest and recent-sheet generated operations handle server responses | Permanent local `URLProtocol` stubs exercise the discovery and manifest response shapes. | `APIClientTests.testFetchesRecentSheetsFromPublishedContractStub`; `APIClientTests.testFetchesManifestFromPublishedContractStub` |
| Capture, measurement, and judgment generated operations serialize requests | Permanent local `URLProtocol` stubs assert routes and JSON payloads. | `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`; `APIClientTests.testUploadMeasurementsEncodesScoresWithAlgorithmVersion`; `APIClientTests.testUploadJudgmentsEncodesPathAndPayload` |
| Ranked-results generated operation is available | Focused local-stub test of the generated operation and its typed response. | Not yet written: no application operation exists to exercise in this tests-only phase. |
| Prose/spec deltas are recorded in the PR | Human review of this document and the final PR description against the vendored OpenAPI snapshot. | External evidence required. |

## Contract deltas found before implementation

- The prose contract describes successful measurement and judgment uploads as
  `204` with no body. The published server returns `200` receipt bodies with
  `capture_id` and row counts.
- The published measurement schema requires both `linear_rgb_median` and
  `normalized_linear_rgb_median`; the hand-written model permits the latter to
  be absent. It also does not specify the prose-only top-level
  `scoring_algorithm_version` or measurement statistics.
- `GET /ranked_results` is fully present in the published API and has schema
  version `lps-ranked-results/v1`; the app has no corresponding client method.
- The manifest printer profile changed from the prose `id`/`name`/`paper`/`ink`
  shape to detailed printer metadata (`printer_make_model`, `paper_type`,
  `ink_type`, driver and calibration fields).
- The OpenAPI schema currently declares only a minimal manifest shape
  (`schema_version`, `sheet_id`, and capture-profile algorithm version), while
  the server renderer returns the full geometry. Generation should retain the
  server snapshot's declared type and adapters should preserve the app's
  client-only measurement and analysis models.
