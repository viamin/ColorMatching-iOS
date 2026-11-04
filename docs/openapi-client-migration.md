# Generated OpenAPI client migration evidence

This document is the PR-description source for issue #5. It records the test
plan and the upstream contract observations made before the generated-client
implementation begins.

## Acceptance-criterion plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor/fetch the OpenAPI document | Inspect `iOS/Package.swift`, the checked-in spec, generator configuration, and generated-source diff | Not implemented; requires the implementation run |
| Generate the manifest, recent sheets, capture, measurements, judgments, and ranked-results surfaces | Compile the generated target and execute the focused client tests against `MockURLProtocol` | Tests cover the first five request/response surfaces; ranked results is an app endpoint gap below |
| Replace hand-written API models while retaining client-side models | Review the generated target and verify `MeasurementCore` remains the owner of analysis-only types | Not implemented; requires the implementation run |
| Exercise the generated client without a live server | Permanent XCTest client-contract tests with local `MockURLProtocol` responses: `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Added/expanded in this change; they become generated-client coverage when the adapter is wired to generated operations |
| Record prose-contract deltas and endpoint gaps | This inspectable document plus review of upstream issue #110 and its published-spec source | Recorded below; production deployment URL still needs confirmation when vendoring the document |

The client-contract tests are permanent because capturing, uploading, and
reviewing a test sheet is a recurring app flow. They do not contact a live
server: `MockURLProtocol` supplies each HTTP response and captures each request.

## Contract deltas and endpoint gaps

The upstream issue is closed and specifies that the authoritative OpenAPI 3
document is served from `GET /api/v1/openapi.json`. Its source is
[`ColorMatchingWeb.ApiSpec`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_spec.ex),
which intentionally resolves the router into the served specification.

- The prose contract gives no concrete schema for `ranked_results`. The app has
  no `APIClient` operation for `GET /api/v1/test_sheets/:sheet_id/ranked_results`.
  This is the endpoint gap to close before claiming all requested surfaces are
  generated and tested.
- `SheetManifest` in `MeasurementCore` intentionally discards server fields
  such as `created_at`, `printer_profile`, and `capture_profile`. The prose
  contract includes them, so the generated API model must not be substituted
  blindly for the client-side analysis model; an explicit mapping is required.
- Upstream's OpenAPI controller tests document flexible request shapes: capture
  payloads have two accepted forms, and RGB and pair-score request schemas use
  alternatives. The prose contract depicts only one object shape. Generation
  must preserve the server's published alternatives rather than freezing the
  prose example into another hand-written `Codable` type.
- The published-spec source declares a relative server URL (`/`). The
  implementation must choose and document the deployment base URL used to fetch
  the JSON, then pin the fetched revision/checksum or deliberately vendor the
  document so regeneration is reproducible.

## Implementation handoff

1. Fetch and check in the served OpenAPI JSON from a confirmed deployment (or
   vendor the exact upstream artifact), recording its source commit and checksum.
2. Add `swift-openapi-generator` and `swift-openapi-runtime`; generate only the
   six endpoint operations in scope.
3. Replace transport request/response `Codable` structs with generated types
   and map only at the boundary to `MeasurementCore` analysis types.
4. Add ranked-results stub coverage beside the existing tests, then run
   `swift test --disable-sandbox` on a host with Swift installed.
