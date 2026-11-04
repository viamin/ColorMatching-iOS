---
module: ios-api-client
tags: [openapi, generated-client, color-matching]
problem_type: implementation-plan
---

# Issue #5: Generated OpenAPI client PR notes

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Evidence at implementation PR head |
| --- | --- | --- |
| `swift-openapi-generator` and `swift-openapi-runtime` are configured and the OpenAPI document is vendored | Focused package/spec contract test | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientContractTests.swift` verifies both package dependencies and all six required paths in the vendored JSON. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local-stub integration tests | Extend `APIClientTests` to invoke generated operations through a `URLSession`/`URLProtocol` stub, asserting request method/path/body and typed response decoding for each surface. |
| Handwritten API models are removed while client-side measurement models remain | Compile-time evidence plus source review | Generated-client target compiles; review confirms `MeasurementCore` domain models remain and server-wire Codable request/response declarations are removed. |
| Generated client works without a live server | Permanent local-stub tests | `APIClientTests` uses `MockURLProtocol`; no network service is needed. |
| PR records contract differences and endpoint gaps | Human/external evidence | Compare the pinned vendored `openapi.json` against `docs/color-matching-api-contract.md` and link the exact upstream spec commit or retrieval timestamp in the PR body. |

## Upstream evidence and contract deltas found before implementation

On 2026-11-04, `viamin/color_matching#110` was closed and its router exposed the required six `/api/v1` sheet/capture routes plus `GET /api/v1/openapi.json`. The document is rendered at runtime by `ColorMatchingWeb.OpenApiController`; it is not committed as a static repository file. The implementation must fetch that endpoint and commit a pinned copy so builds and tests do not depend on a live Phoenix deployment.

The upstream controller conformance tests establish these deltas from the prose contract:

- The prose contract omits the machine-readable `GET /api/v1/openapi.json` endpoint.
- The prose gives one rigid capture request shape, while the upstream spec declares two accepted `CaptureRequest` variants.
- The prose treats all pair-score fields as required; the upstream spec requires only `pair_id` and `algorithm_version` and declares three accepted variants.
- The prose fixes RGB payloads to `r`, `g`, and `b`; the upstream spec declares three accepted RGB payload variants.
- The prose intentionally leaves ranked-results response fields unspecified; the vendored OpenAPI response schema is the authority that must be used by the generated client.

No endpoint gap was found in route coverage: manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results are all present upstream. Exact field-level deltas must be refreshed from the pinned JSON immediately before implementation, because a live deployment was not available in this test-writing run.
