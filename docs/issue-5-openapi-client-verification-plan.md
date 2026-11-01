# Issue #5 OpenAPI Swift client verification plan

This tests-only change defines the verification boundary for replacing the iOS
API transport. The implementation run must vendor a snapshot fetched from the
upstream `GET /api/v1/openapi.json` endpoint and generate the Swift client from
that snapshot; the upstream repository generates the document dynamically, so
there is no static source document to consume directly.

| Criterion | Smallest credible verification | Status in this red phase |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; fetch or vendor the document | Inspect `iOS/Package.swift` and the committed OpenAPI snapshot; run `swift package resolve` | Not run: implementation is prohibited in this phase and `swift` is unavailable in the container. |
| Generate all app-used surfaces | Permanent `APIClientTests` local-stub coverage for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Red: `testGeneratedOpenAPIClientCoversEveryAppEndpoint` deliberately fails until generated types replace the hand-written layer. |
| Replace API models while retaining client-only models | Compile the app and inspect the API boundary: generated schemas own wire types; image-analysis types remain in `MeasurementCore` | Not run: requires implementation. |
| Generated-client tests use no live server | Run `swift test --disable-sandbox`; `MockURLProtocol` supplies every response | Not run: `swift` is unavailable in this container. |
| PR describes prose-contract deltas and endpoint gaps | Human review of this record and the PR description against the upstream served OpenAPI document | Partial external evidence recorded below; final schema-level comparison awaits a vendored snapshot. |

## Upstream contract evidence and deltas

Evidence was inspected from `viamin/color_matching` main at commit
`47057afd58f7d46b4d4b740ca7d2d08947774471` on 2026-11-01. Issue
`viamin/color_matching#110` is closed. Its spec is served at
`GET /api/v1/openapi.json` by `OpenApiSpex.Plug.RenderSpec`.

- The prose contract says measurement and judgment uploads have no response
  body and existing iOS tests model them as `204`. The upstream controllers
  specify and return `200` JSON acknowledgement bodies containing the capture
  ID plus measurement/pair-score or judgment counts.
- The prose calls the capture identifier `capture_123`; the server returns an
  integer database ID serialized as a string.
- The prose lists camelCase capture-rejection values, while the generated
  schema snapshot must be treated as authoritative for their exact wire enum.
- Ranked results are named in the prose but not represented in the current iOS
  API client or tests. The upstream route exists at
  `GET /api/v1/test_sheets/:sheet_id/ranked_results` and must be included.
- The upstream OpenAPI document declares bearer authentication on these
  endpoints; generated requests must continue to carry the configured bearer
  token.

The implementation PR description should copy these deltas, then replace the
provisional enum note with a precise schema comparison from the vendored
snapshot.
