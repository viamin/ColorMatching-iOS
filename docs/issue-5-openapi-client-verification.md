# Issue #5 OpenAPI client verification plan

This is the red-phase verification plan for replacing the iOS hand-written
`/api/v1` client with code generated from the OpenAPI document published by
`viamin/color_matching#110`.

## Acceptance criteria and evidence

| Criterion | Smallest credible verification | Status in this test-writing change |
| --- | --- | --- |
| Generator and runtime are package dependencies | `GeneratedOpenAPIClientAdoptionTests.testPackageDeclaresSwiftOpenAPIGeneratorAndRuntime` checks the package manifest | Red: dependencies are not present yet |
| Manifest and recent sheets use typed client responses | `APIClientTests` uses `URLProtocol` local stubs for each response, including a nullable title | Passing once Swift is available |
| Capture creation, measurement upload, and judgment upload use typed client requests | Existing `APIClientTests` local-stub request tests cover all three POSTs | Passing once Swift is available |
| Ranked results use a typed client response | Add an endpoint-specific local-stub test after the generated operation name is established from the vendored spec | Blocked by the published schema gap below |
| Generated client replaces server-owned hand-written models | Compile the app and the stub tests after generation; inspect the removed API-owned models in the PR diff | Implementation-run evidence required |
| No live server in CI | All API-client tests install `MockURLProtocol`; no test uses a network host | Passing by inspection; implementation run must execute it |

`swift test --disable-sandbox` is the test command for the implementation
run. This environment does not contain a `swift` executable, so this
test-writing run cannot execute it.

## Contract deltas found against `color_matching#110`

The upstream API source was inspected at `main` on 2026-10-31: the router,
controller OpenAPI declarations, and `ColorMatchingWeb.ApiSchemas`. The
served document is generated at `GET /api/v1/openapi.json`; it is not a
checked-in JSON file in that repository.

- The six app routes all exist in the upstream router, including
  `GET /api/v1/test_sheets/:sheet_id/ranked_results`.
- The prose contract describes a rich manifest (page geometry, registration
  markers, patches, pairs, printer profile, and capture profile). The
  published `Manifest` schema currently requires only `schema_version`,
  `sheet_id`, and `capture_profile`; it omits the fields needed by the iOS
  measurement workflow. Generating types from it would make those fields
  unavailable to the app.
- The prose contract describes a detailed ranked-result payload. The
  published `RankedResults` schema currently requires only `schema_version`
  and `sheet_id`, so it does not model the results, source colours, scores,
  labels, or provenance promised in prose.
- The prose capture request is nested under `metadata` and `quality`. The
  published schema accepts that form but also supports a legacy flat form;
  capture metadata fields are more strictly required upstream (notably image
  dimensions).
- The prose capture-rejection and judgment value lists are not encoded as
  enums in the published schemas.
- The prose measurement payload includes request-level
  `scoring_algorithm_version` and measurement `stats`. Neither is modeled in
  the published measurement-upload schema. Conversely, upstream requires a
  normalized median and requires each pair score to include an
  `algorithm_version` plus one of `score`, `similarity`, or `distance`.
- The current iOS client expects empty `204` responses for measurement and
  judgment uploads. The published schema declares `200` JSON responses with
  capture and accepted-item counts.

## Endpoint gaps that must be resolved before the implementation can land

1. Extend the upstream manifest schema to describe all data the iOS app uses.
2. Extend the ranked-results schema to describe the actual results payload.
3. Decide whether the generated client must send the iOS-only measurement
   `stats` and request-level algorithm version, then align the upstream schema
   and server validation accordingly.
4. Update the app's upload handling for the upstream `200` acknowledgement
   bodies (or change the upstream contract to retain `204`).

The implementation PR description should carry these deltas verbatim or link
to this file, and must state the upstream commit or downloaded OpenAPI
artifact used for generation.
