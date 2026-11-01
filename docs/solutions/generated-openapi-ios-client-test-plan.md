---
module: ios-api-client
tags: [openapi, swift-openapi-generator, api-contract, testing]
problem_type: implementation-plan
---

# Generated OpenAPI client: test plan and contract audit

This document records the evidence and test boundary for issue #5 before the
implementation replaces the hand-written API transport models.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Location/status |
| --- | --- | --- |
| Package installs the generator/runtime and vendors or fetches the published document | `swift package resolve` and a compile that imports the generated target | Red test: `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testGeneratedOpenAPIClientModuleIsLinked`); implementation must add `ColorMatchingAPI` from `GET /api/v1/openapi.json`. |
| Manifest and recent-sheet operations use generated types | Local `URLProtocol` stubs decode responses at each endpoint and assert URL/authentication/domain values | Permanent unit/service tests in `APIClientTests`; manifest and recent-sheet coverage added in this change. |
| Capture creation, measurement upload, and judgment upload use generated types | Local stub tests assert paths, authorization, request serialization, and successful responses | Permanent unit/service tests in `APIClientTests`; existing tests cover these three operations and must be updated to the generated operation/result types. |
| Ranked results uses a generated operation | A local stub returns the published ranked-results fixture and the app-facing adapter returns its typed result | Missing red-phase test: implementation must expose this operation before it can be covered without an artificial source-inspection test. |
| No live server is required in CI | The tests inject `URLProtocol` in an ephemeral `URLSession`; no test opens a network connection | `APIClientTests` uses `MockURLProtocol`. |
| `swift test --disable-sandbox` is green | Run after dependency generation and adapter implementation | Not runnable in this tests-only/red phase: generated module intentionally does not exist. |
| PR records contract deltas and endpoint gaps | Inspect the upstream API schema source and real response renderer | Deltas below; implementation PR description must carry them forward. |

The recurring capture/upload flow is covered as permanent focused service tests:
it is an external HTTP boundary whose request/response encoding can regress on
every client regeneration. A UI/system test is not credible in this package,
because the camera flow and SwiftUI app are outside the generated transport
boundary. No ephemeral test is needed.

## Published-spec evidence and deltas

Evidence was inspected from `viamin/color_matching` at its default branch,
after upstream issue `viamin/color_matching#110` closed:

- `GET /api/v1/openapi.json` is the published-spec endpoint.
- The API includes all six companion surfaces: manifest, recent sheets,
  capture creation, measurement upload, judgment upload, and ranked results.
- Ranked results was prose-only in this repository; the published API returns
  `lps-ranked-results/v1`, sheet/printer provenance, aggregate capture dates,
  algorithm versions, and ranked result rows. The current iOS transport has no
  method for it.
- The prose says measurement and judgment uploads complete with an empty body.
  The actual controller returns HTTP 200 JSON acknowledgements with
  `capture_id` and the accepted row count(s), so generated result types must be
  consumed or deliberately discarded.
- The prose makes `scoring_algorithm_version` top-level in measurement uploads.
  The published request schema instead specifies `measurements` and
  `pair_scores`; each score requires `algorithm_version` and one of `score`,
  `similarity`, or `distance`.
- The prose describes nested `metadata` and `quality` capture fields. The
  published capture schema accepts that form but also supports a legacy flat
  form. Keep the nested app-facing conversion unless the generated operation
  makes a different representation mandatory.
- The prose treats sheet manifests as fully specified. The current OpenAPI
  `Manifest` schema only requires `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`, even though the renderer emits
  geometry, patches, and pairs used by the app. This is an upstream spec gap:
  generation alone cannot make those app-required fields non-optional until
  the provider tightens the schema.
- Recent-sheet `manifest_url` is typed as a string by the published schema;
  the app currently decodes it as `URL`. The generated adapter needs explicit
  URL validation/conversion at the client boundary.

## Implementation handoff

Vendor the fetched OpenAPI JSON with a source/revision note, add
`swift-openapi-generator` and `swift-openapi-runtime`, generate a target named
`ColorMatchingAPI`, and retain only domain/camera-analysis models in
`MeasurementCore`. Replace the request/response Codable declarations in
`ColorMatchingLPSAppCore/APIClient.swift` with conversions to generated
operation input/output types. Add a ranked-results adapter and its local-stub
test, then update upload tests to assert the 200 acknowledgement payloads.
