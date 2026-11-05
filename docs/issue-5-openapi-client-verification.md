---
module: iOS API client
tags:
  - openapi
  - swift
  - api-client
problem_type: verification-plan
---

# Issue #5 OpenAPI Client Verification Plan

This is the criterion-level plan and the contract-delta record for the tests-only phase of issue #5. The implementation phase must retain this test coverage and update the results below with the commit and test output that satisfy each criterion.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Status in this tests-only commit |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor/fetch the document | `OpenAPIGenerationContractTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` plus `testVendoredSpecDeclaresEveryIOSOperation` | Red: neither dependencies nor document exists yet. |
| Generate the six app-used operations | `testVendoredSpecDeclaresEveryIOSOperation` requires each exact OpenAPI path, including ranked results. The implementation must add generated-client stub tests for all six operations. | Red: no vendored document or generated client exists. |
| Replace hand-written API models while preserving client-only models | Human code review of the generated target and `APIClient.swift`; the implementation must prove transport schema types come from generated code while `MeasurementCore` types remain client models. | Not run: requires implementation. |
| Stubbed Swift client tests | `APIClientTests` uses `MockURLProtocol`; its manifest, recent-sheet, capture, measurement, and judgment tests execute no live HTTP. The implementation must add ranked-results decoding to the same fixture style. | Partial: five existing/currently implemented operations are covered; ranked-results is absent. |
| Record prose-contract deltas and endpoint gaps | This document, based on upstream source inspection at the links below; a reviewer must compare the vendored JSON artifact at the PR head to the running `GET /api/v1/openapi.json` before merge. | External verification pending. |
| `swift test --disable-sandbox` is green with generated types | Run exactly `cd iOS && swift test --disable-sandbox` after implementation. | Not run in this red phase; expected assertions fail before implementation. |

## Contract deltas found

The upstream router exposes all six iOS paths, including ranked results, and serves its OpenAPI document at `GET /api/v1/openapi.json`. It also protects the companion endpoints with bearer authentication. [Router source](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex)

The published schema source differs from the prose contract in material ways:

- Capture creation accepts either the nested `metadata`/`quality` payload used by iOS or a legacy flat payload. Its nested metadata requires `image_width` and `image_height`; the prose describes them as examples but the iOS hand-written model makes them optional.
- Measurement uploads require normalized RGB values but do not declare `scoring_algorithm_version` or the `stats` object that the hand-written client uploads. Pair scores accept `score`, `similarity`, or `distance`; the prose assumes both distance and similarity.
- Both upload endpoints declare JSON success response objects (`capture_id` plus counts), while the hand-written client expects and discards a `204 No Content` response.
- The manifest schema currently requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; it does not model page geometry, markers, patches, pairs, or the other manifest fields consumed by `MeasurementCore`.
- Ranked results currently declare only `schema_version` (`lps-ranked-results/v1`) and `sheet_id`. The prose promises source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version, but the schema does not expose their shape.

These are endpoint/schema gaps, not permission to change iOS capture or scoring behavior. The implementation PR should either adapt to the generated schema where it is authoritative or coordinate upstream spec expansion before deleting a required client-side field. [Upstream schema source](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_schemas.ex) and [test-sheet operation declarations](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/test_sheet_controller.ex)

## External-evidence hold

The upstream OpenAPI document is dynamically served rather than committed as a static JSON file. This isolated environment could inspect the authoritative router and schema source but could not resolve the deployment hostname. Before merging the implementation, a reviewer must fetch `GET /api/v1/openapi.json`, pin its revision/checksum in `iOS/OpenAPI/`, and confirm the vendored artifact has the six required paths. That is inspectable external evidence; the local XCTest suite cannot establish it.
