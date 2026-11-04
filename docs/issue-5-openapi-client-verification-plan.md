---
module: ios
tags: [openapi, api-client, testing]
problem_type: verification-plan
---

# Issue #5 OpenAPI client verification plan

This is the tests-only (red) phase for replacing the hand-written `/api/v1`
client with generated OpenAPI types. The implementation phase must preserve the
public application-facing operations while delegating serialization and response
decoding to generated code.

| Criterion | Smallest credible verification | Status in this phase |
| --- | --- | --- |
| Generator/runtime and vendored or fetched spec are wired into the package | Inspect `iOS/Package.swift`, generated source, and pinned OpenAPI input in the implementation PR | Not run: implementation is disallowed in this phase |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `APIClientTests` uses `MockURLProtocol` local responses for each operation | Manifest/recent and the three existing writes are covered; ranked results is a deliberate red gap |
| Hand-written API models are replaced while client-only models remain | Implementation diff inspection and compilation of app targets | Not run: requires implementation |
| No live server is required in CI | The permanent `MockURLProtocol` tests run with `swift test --disable-sandbox` | Ready to run; ranked-results test intentionally fails until implemented |
| PR records prose-contract deltas and endpoint gaps | Human inspection of the PR description against the pinned server spec | Not run: the running upstream service was not resolvable from this environment, and `OpenApiSpex` renders the document dynamically at `/api/v1/openapi.json` |

## Upstream evidence and initial delta inventory

`viamin/color_matching#110` is closed. Its `main` branch defines
`GET /api/v1/openapi.json` using `OpenApiSpex.Plug.RenderSpec`, and its router
lists all six iOS-relevant routes:

- `GET /test_sheets/recent`
- `GET /test_sheets/:sheet_id/manifest`
- `GET /test_sheets/:sheet_id/ranked_results`
- `POST /test_sheets/:sheet_id/captures`
- `POST /captures/:capture_id/measurements`
- `POST /captures/:capture_id/judgments`

The prose contract already describes those routes, but specifies no concrete
ranked-results response schema. The implementation PR must fetch and pin the
published JSON, regenerate from that exact input, and replace this preliminary
inventory with field-level request/response deltas from the generated schema.
