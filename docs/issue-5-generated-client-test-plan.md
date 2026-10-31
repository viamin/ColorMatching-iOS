---
module: ios-api-client
tags: [openapi, swift, api-client, tdd]
problem_type: test-plan
---

# Issue #5 generated OpenAPI client test plan

This is the red-phase test plan for replacing the handwritten iOS API layer.

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| OpenAPI generator/runtime and published document are wired in | `APIClientTests.testGeneratedClientDependenciesAndReplacementAreCheckedIn` asserts the package declares both generator/runtime products and the handwritten request DTOs are removed. The implementation PR must also vendor or fetch `/api/v1/openapi.json`. | Failing until implementation |
| App-used API surfaces use generated types | `APIClientTests` sends manifest and recent-sheet fixtures through a protocol-backed `URLSession`; existing POST fixture tests cover capture creation, measurement upload, and judgment upload. Add ranked-results fixture coverage with the generated operation when that generated type is available. | Read and POST fixtures pass; ranked-results is not implemented |
| No live server in CI | Every `APIClientTests` request uses `MockURLProtocol`; no test opens a network connection. | Passing |
| Contract deltas are recorded | This document records the upstream-spec comparison below; final PR description must carry the same findings and explicitly note any unresolved generated-operation gap. | Human review required |

## Upstream spec comparison (checked 2026-10-31)

The upstream server now serves OpenAPI 3 at `GET /api/v1/openapi.json` (viamin/color_matching#110). Its declared test-sheet and capture paths match the prose contract, including ranked results.

Observed differences from `docs/color-matching-api-contract.md`:

- Measurement and judgment uploads respond with a JSON acknowledgement (`capture_id` plus counts) and HTTP 200. The prose contract specifies requests but not these response bodies.
- The published capture request schema accepts two request variants; RGB and pair-score request schemas accept legacy-compatible variants. The prose contract presents only one payload shape for each.
- The server persists capture and sheet IDs as numeric values serialized as strings. The prose examples use semantic IDs such as `capture_123` and `sheet_123`; generated code must treat them as opaque strings.
- The spec documents bearer authentication and structured 401/404/422 errors for these endpoints. The prose contract documents only the happy paths (apart from a general bearer-token note).

Endpoint gap at this red-phase head: `APIClient` has no ranked-results operation, although it is in the published OpenAPI path set. The implementation must add that generated operation and a local-stub test before marking the criterion passed.
