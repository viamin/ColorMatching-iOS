---
title: "Issue #5 generated OpenAPI client verification plan"
date: "2026-11-03"
module: "iOS"
problem_type: "test_plan"
tags:
  - "openapi"
  - "swift-openapi-generator"
  - "api-client"
  - "issue-5"
---

# Issue #5 generated OpenAPI client verification plan

## Acceptance-criterion map

| Criterion | Smallest credible verification | Current status |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor or fetch the OpenAPI document | Inspect `iOS/Package.swift`, the checked-in spec/fetch script, and generated target after `swift package resolve`; compile with `swift test --disable-sandbox`. | Blocked: the upstream spec endpoint is not publicly fetchable in this environment. |
| Generate manifest/recent-sheet, capture, measurement, judgment, and ranked-results surfaces | Compile calls to each generated operation. Keep a local-stub test per operation. | Blocked for the generated names and schemas; ranked-results has no current app facade or documented response schema. |
| Replace hand-written API models while retaining client-only models | Inspect the replacement diff: generated types own HTTP request/response payloads; `MeasurementCore` analysis models remain. Compile catches stale hand-written API references. | Not started in this test-only run. |
| Generated client works against local stubs | Permanent Swift unit/service tests use `MockURLProtocol`, never a live server. | Existing request/response coverage expanded for manifest and recent sheets; capture, measurements, and judgments were already stubbed. |
| PR records prose-contract deltas and endpoint gaps | Human/external evidence: compare the vendored published spec with `docs/color-matching-api-contract.md` at implementation time, then put the resulting delta table in the PR body. | Not run: no published document was obtained. |

## Evidence gathered before implementation

`viamin/color_matching#110` is closed and says the spec is served from `GET /api/v1/openapi.json`. A direct fetch of the presumed deployment-independent raw file (`priv/static/openapi.json`) returned HTTP 404 on 2026-11-03. The upstream source contains an `OpenApiController` that renders the spec dynamically, so there is no static repository artifact to vendor from `main`.

This prevents a reliable comparison with the prose contract. It also prevents selecting generated Swift operation/type names without guessing. In particular, the prose contract specifies no ranked-results response schema, while the task requires that generated surface and the current app has no ranked-results API method or UI call.

## Permanent regression tests

`iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` now exercises the locally stubbed manifest and recent-sheets GET responses, including the required bearer authorization and response decoding. The same test file already covers local-stub capture creation, measurement upload, and judgment upload.

When the OpenAPI document is vendored or fetched, replace these facade-level tests with generated-operation tests (or preserve the facade and inject the generated client) and add a ranked-results fixture from the published schema. Do not make these tests contact the Phoenix server.

## PR-body checklist for the implementation run

- State the immutable source URL and revision/digest of the vendored OpenAPI document.
- List every difference found between that document and `docs/color-matching-api-contract.md`, with affected generated type/operation and compatibility impact.
- Call out the ranked-results schema and any endpoint absent from the specification.
- Include the exact `swift test --disable-sandbox` result and the local-stub test references.
