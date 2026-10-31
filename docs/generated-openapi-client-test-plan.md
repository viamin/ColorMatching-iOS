---
module: "iOS/ColorMatchingLPSAppCore"
tags:
  - openapi
  - swift
  - api-client
problem_type: "test_plan"
---

# Generated OpenAPI Client: Acceptance-Test Plan

This is the test-writing-phase evidence for #5. The implementation phase must
keep these tests as URLProtocol-backed unit/service tests: they never contact a
live Phoenix server and the responses are local deterministic stubs.

## Criterion map

| Criterion | Smallest credible verification | Location / status |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor or fetch the published document | Inspect `iOS/Package.swift`, the checked-in OpenAPI input or reproducible fetch command, and generated source at PR head | Human/code review; not implemented in this test-writing phase |
| Generate the manifest, recent-sheet, capture, measurement, judgment, and ranked-result operations | Build `ColorMatchingLPSAppCore` after regeneration, then run one local-stub request/response test per operation | Existing local stubs cover five current operations in `APIClientTests`; ranked results must be added with the generated operation |
| Replace hand-written API models but retain client-side measurement models | Compile the app and review that transport DTOs come from generated code while `MeasurementCore` remains app-owned | Human/code review; not implemented in this phase |
| Exercise the generated client with local stubs | `swift test --disable-sandbox` runs request/response fixtures without a network service | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; blocked locally because Swift is not installed in this container |
| PR records prose-contract deltas and endpoint gaps | Compare `docs/color-matching-api-contract.md` with the fetched `/api/v1/openapi.json`; record evidence in the PR description | External/spec evidence required during implementation |

## Current contract evidence

The upstream dependency is closed: `viamin/color_matching#110` publishes the
spec at `GET /api/v1/openapi.json`. Its router contains all requested paths:

- `GET /api/v1/test_sheets/recent`
- `GET /api/v1/test_sheets/:sheet_id/manifest`
- `GET /api/v1/test_sheets/:sheet_id/ranked_results`
- `POST /api/v1/test_sheets/:sheet_id/captures`
- `POST /api/v1/captures/:capture_id/measurements`
- `POST /api/v1/captures/:capture_id/judgments`

The present hand-written iOS client has no ranked-results operation. That is a
known implementation gap, not a behavior to preserve. Its prose contract also
leaves the ranked-results response only narratively specified, so the final PR
must describe the generated schema selected from the published document rather
than inventing a local Codable model.

## Local-stub fixture rules

The implementation should replace the current transport calls in
`APIClientTests` with generated-operation invocations while preserving the
request assertions (method, path, bearer token, and JSON body) and decoded
response assertions. Add a ranked-results fixture using the exact generated
schema. Do not make these tests call a deployed server.
