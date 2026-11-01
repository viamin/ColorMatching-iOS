# OpenAPI client migration evidence for #5

This test-writing change deliberately adds no production code. The implementation
change must vendor the document served by
`GET /api/v1/openapi.json` from `viamin/color_matching`, generate the Swift
client with `swift-openapi-generator`, and replace the hand-written transport
models without changing the capture or scoring flow.

## Criterion map

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Generated dependencies and vendored/fetched document | Inspect `iOS/Package.swift`, the vendored spec, and generated sources in the implementation PR | Not run in this tests-only change. |
| Typed client covers manifest, recent sheets, capture creation, measurement and judgment uploads, and ranked results | Local `URLProtocol` stubs invoke each generated operation and assert request/decoded response shape | `APIClientTests` covers the first five existing hand-written operations. `testGeneratedClientMustSupportRankedResults` is intentionally red because that operation is absent. |
| Hand-written API models are replaced, preserving client-only models | Inspect the generated target and app adapters; compile `swift test --disable-sandbox` | Not run in this tests-only change. |
| Generated client tests use no live server | `URLProtocol` stubs in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | The manifest and recent-sheet tests are self-contained local stubs. |
| Contract deltas and endpoint gaps are recorded | This section is copied into the implementation PR description and checked against the vendored spec revision | Evidence collected from `viamin/color_matching` main after #110 closed (2026-10-30). |

## Published-contract deltas and gaps

The upstream controller serves a runtime-generated document at
`/api/v1/openapi.json`; it is not committed as a static JSON file. The
implementation should fetch and pin that response, with its source revision,
rather than guess a raw-file URL.

- `GET /api/v1/test_sheets/{sheet_id}/ranked_results` is implemented and has a
  `lps-ranked-results/v1` response. The prose contract only describes this
  response narratively. The iOS hand-written client has no ranked-results
  operation; the red test records this gap.
- Measurement and judgment uploads return `200` JSON acknowledgement bodies
  (`capture_id` plus counts), whereas the prose contract presents them as
  bodyless `204` responses. Generated responses must be decoded or explicitly
  discarded only after accepting the server's documented `200` status.
- Capture creation accepts both the nested `metadata` format used by iOS and a
  legacy flat format. The generated type should use the nested form; no
  client-side behavior change is intended.
- The published schema's manifest and ranked-results models currently specify
  only their compatibility/version fields, while the rendered API provides the
  richer fields in the prose contract. Generation will surface this as a typed
  coverage limitation; either the upstream schema must be expanded before
  replacing those app-facing models, or an explicitly scoped decoding adapter
  is required.

Sources inspected: `viamin/color_matching` issue #110 (closed 2026-10-30),
`ColorMatchingWeb.ApiSpec`, `ColorMatchingWeb.ApiSchemas`,
`ColorMatchingWeb.TestSheetJSON`, and `ColorMatchingWeb.CaptureController` on
the upstream default branch.
