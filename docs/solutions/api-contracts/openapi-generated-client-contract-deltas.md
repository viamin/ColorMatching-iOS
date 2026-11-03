---
title: "OpenAPI generated iOS client migration: contract deltas and test plan"
date: "2026-11-03"
category: "api-contracts"
module: "iOS/Package.swift"
problem_type: "contract_migration"
component: "iOS API client"
tags:
  - "openapi"
  - "swift-openapi-generator"
  - "swift"
  - "api-contract"
---

# OpenAPI generated iOS client migration: contract deltas and test plan

## Evidence source

The upstream OpenAPI work is merged in [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113), which closes [#110](https://github.com/viamin/color_matching/issues/110). Its source defines `GET /api/v1/openapi.json`; the deployment URL was not available during this tests-only run, so the implementation must vendor a reviewed JSON response from that endpoint before generation.

## Criterion-level verification plan

| Criterion | Smallest credible verification | Current test/evidence |
| --- | --- | --- |
| Generator and runtime are configured and a reviewed spec is vendored | Focused configuration test | `GeneratedOpenAPIClientConfigurationTests.testPackageVendorsSpecAndConfiguresGeneratedClientDependencies` (red until the package/spec exist) |
| Manifest and recent sheets work through the generated client with no live server | Permanent local-stub client tests | `APIClientTests.testFetchManifestDecodesStubbedResponse`; `APIClientTests.testFetchRecentSheetsDecodesNullableTitleFromStubbedResponse` |
| Capture, measurement, and judgment uploads work through the generated client with no live server | Permanent local-stub client tests | Existing `APIClientTests` write-operation tests; the implementation must retain these tests while replacing the transport/types |
| Ranked results work through the generated client | Permanent local-stub client test | Missing: add once the vendored document exposes the response fields the app needs |
| Prose-contract changes and endpoint gaps are reviewed | Human/external evidence | This document and the implementation PR description, checked against the vendored JSON |

## Deltas found in the published specification source

- The published manifest schema requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the iOS prose contract requires many additional manifest fields needed for sampling (`page`, markers, patches, pairs, and `manifest_url`). A generated client cannot safely replace the existing manifest model until those fields are represented in the emitted document.
- The published ranked-results schema requires only `schema_version` and `sheet_id`. The prose contract calls for source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version. This is an endpoint response-schema gap and prevents a meaningful ranked-results client test.
- The capture request schema accepts either the prose contract's nested `metadata` shape or a legacy flat shape. The generated client should send only the nested form already used by iOS.
- The measurement upload schema does not require `scoring_algorithm_version` or measurement `stats`, even though the prose contract and current iOS client send them. Preserve these fields only after confirming they appear in the downloaded JSON; otherwise record the compatibility decision in the implementation PR.
- The published write-response schemas describe JSON `200` responses for measurements and judgments, whereas the current hand-written client tests accept `204` with no body. The generated-client adapter must follow the vendored document and the local stubs must assert the selected response status/body.

## Implementation decision recorded for the next phase

Vendor the exact downloaded document as `iOS/OpenAPI/color-matching.json`; configure `swift-openapi-generator` and `swift-openapi-runtime` in `iOS/Package.swift`; generate a dedicated API target; then migrate the `APIClient` facade to generated request/response types while keeping measurement-analysis models in `MeasurementCore`.
