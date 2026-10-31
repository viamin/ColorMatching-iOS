---
module: ios-api-client
tags: [openapi, generated-client, verification]
problem_type: acceptance-criteria
---

# Issue #5: Generated OpenAPI Client Verification Plan

This is the evidence plan for replacing the iOS hand-written `/api/v1` client with a generated Swift client. It is intentionally committed with the red tests so the implementation run has a concrete, inspectable contract.

| Criterion | Smallest credible verification | Current red-phase evidence |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor or fetch the published document | Focused unit test parses the vendored OpenAPI JSON and asserts every used operation is present. Inspect `Package.swift` and generated target in implementation review. | `APIClientTests.testVendoredOpenAPIDocumentCoversEveryAppSurface` is red until `iOS/OpenAPI/color-matching-api.json` exists. |
| Generate test-sheet manifest/recent, capture creation, measurement/judgment uploads, and ranked results | Permanent stubbed-client tests exercise each generated operation, including request method/path/body and typed response decoding. | Manifest and recent-sheet stubs are added in `APIClientTests`; existing tests cover the three write operations. Ranked-results response tests are blocked until the vendored document supplies its concrete schema. |
| Replace server-owned hand-written models, retaining client-only models | Code review of generated target and app adapter; compile proves generated type names are wired into callers. | Not runnable in this tests-only phase. |
| No live server in CI | The permanent client tests inject `MockURLProtocol`; test code has no network dependency. | `APIClientTests` uses local URL protocol stubs. |
| `swift test --disable-sandbox` green | Run the command in `iOS/` after implementation. | The suite is deliberately red only for the missing vendored OpenAPI artifact. |

## Upstream evidence and contract deltas

On 2026-10-31, `viamin/color_matching#110` was closed. Its router exposes the six app-relevant operations and serves the OpenAPI document dynamically at `GET /api/v1/openapi.json`. Because the upstream repository does not commit a static JSON/YAML artifact, this repository should vendor a retrieved snapshot at `iOS/OpenAPI/color-matching-api.json` and make generation reproducible from it.

Compared with `docs/color-matching-api-contract.md`:

- The prose contract names ranked results but has no response schema. The upstream typed `RankedResults` schema is the authority; its snapshot must be inspected before the implementation writes a ranked-results stub.
- The upstream router's `:sheet_id` path parameter is resolved as a sheet lookup code, rather than necessarily a database ID. The generated client should preserve the wire name while the app continues to pass its sheet code.
- Measurement and judgment uploads return `200` JSON acknowledgement payloads (`capture_id` plus accepted counts); the prose contract omits those response bodies. The generated operations must decode or deliberately discard these typed acknowledgements rather than assume `204`.
- Capture identifiers are serialized as strings by the upstream controller. The prose example's `capture_123` is compatible as a string but does not communicate that production values are stringified integer IDs.
- All six relevant upstream routes require bearer authentication. The prose's development exception is not represented in the production OpenAPI security requirement.

## Endpoint gaps discovered

The current app has no ranked-results call site, even though the issue requires a generated surface for it. The implementation should generate that operation and cover it with a local stub, but must not change capture/scoring UI behavior. The upstream spec also covers unrelated palette and legacy `/api` endpoints; they are outside this issue's generation scope unless the generator requires the document as a whole.
