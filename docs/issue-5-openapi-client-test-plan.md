---
title: "Issue #5 generated OpenAPI client verification plan"
date: "2026-10-31"
module: "iOS"
problem_type: "test_plan"
tags:
  - "openapi"
  - "swift"
  - "api-client"
  - "issue-5"
---

# Issue #5 generated OpenAPI client verification plan

## Acceptance-criterion map

| Criterion | Smallest credible verification | Evidence at this commit |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor/fetch the specification | Focused package/input test checks the two package dependencies and every required path in the vendored OpenAPI input. | `APIClientTests.testOpenAPIInputsAndGeneratorDependenciesCoverEveryAppSurface` (red until implementation adds `iOS/OpenAPI/color-matching.yaml` and package wiring). |
| Generate the manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked-results surfaces | The same focused input test asserts all six OpenAPI paths. The implementation run must add generated-client local-stub tests for the ranked-results operation once the published response schema is known. | The current prose contract has no ranked-results response schema, so a typed response fixture cannot responsibly be invented in this test-writing run. |
| Replace server API models with generated types while retaining client-only models | Local `URLProtocol` tests exercise the app-facing boundary with stubbed server JSON; the implementation run must retain these while wiring the generated client beneath it. | `APIClientTests.testFetchManifestDecodesLocalStubbedResponse`, `APIClientTests.testFetchRecentSheetsDecodesLocalStubbedResponse`, and the existing capture/measurement/judgment stub tests. |
| Swift tests use local stubs, not a live server | `MockURLProtocol` intercepts `URLSession` requests and supplies all responses in-process. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. |
| PR description records prose-contract versus published-spec deltas and endpoint gaps | Human/external comparison of the published OpenAPI document with `docs/color-matching-api-contract.md`. | Not yet available: `https://api.github.com/repos/viamin/color_matching/pulls/110` returned HTTP 404 on 2026-10-31 in this environment. |

## Known contract gap before the dependency is available

The prose contract names `GET /api/v1/test_sheets/:sheet_id/ranked_results`, but supplies no response JSON or fields. It cannot be represented as a reliable typed fixture until the upstream OpenAPI document is available. This is a real endpoint-schema gap in the prose contract, not evidence that the upstream API lacks the endpoint.

## PR-description checklist for the implementation run

- State the exact upstream OpenAPI revision/file vendored or fetched.
- Compare the published path, parameter, request, response, nullability, date, and enum definitions with the prose contract; list each delta explicitly.
- Call out the ranked-results response schema and any missing app-used endpoint as an endpoint gap.
- Record the `swift test --disable-sandbox` result after generated types replace the handwritten transport models.
