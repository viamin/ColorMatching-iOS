# Issue #5 OpenAPI client: acceptance and contract evidence

This is the test-writing (red) phase for replacing the iOS hand-written
`/api/v1` client. The implementation phase must preserve the app-facing
behaviour tested here while using `swift-openapi-generator` output for the
wire contract.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Generated package dependencies and a vendored/fetched OpenAPI document | Inspect `iOS/Package.swift`, the pinned document, and generated-source target in the implementation PR | Not implemented in this phase. |
| Generated operations cover manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent `MockURLProtocol` tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; each test validates a request and a local stubbed response | Manifest/recent/capture/measurement/judgment coverage exists. Ranked-results test is deliberately red until a typed operation exists. |
| Hand-written wire models are replaced while client-only measurement models remain | Inspect the generated source and app adapter; compile the app target | Not implemented in this phase. |
| No live server is used by generated-client tests | `MockURLProtocol` remains the injected boundary in the permanent test target | Covered by the existing and added API client tests. |
| `swift test --disable-sandbox` is green after wiring generated types | Run that exact command in `iOS/` | Not yet applicable: the red ranked-results test intentionally fails. |

## Published-spec comparison

External evidence was inspected from `viamin/color_matching` main at
2026-11-01: [the API spec module](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_spec.ex),
[API schemas](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_schemas.ex), and
[test-sheet JSON renderer](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/test_sheet_json.ex).

- The published document is served dynamically at `GET /api/v1/openapi.json`; it
  is not committed as a static JSON/YAML artifact. The implementation should
  fetch a pinned revision of that endpoint or vendor the rendered response.
- The manifest response sent by the server is the rich shape in the prose
  contract, but its OpenAPI schema only requires `schema_version`, `sheet_id`,
  and `capture_profile.scoring_algorithm_version`. Its geometry, patches,
  pairs, page, and printer-profile fields are not machine-described. This is a
  generator-blocking endpoint gap because the iOS analyzer needs those fields.
- The ranked-results server response contains rankings, score aggregates,
  judgments, capture provenance, and printer-profile data, while its OpenAPI
  schema declares only `schema_version` and `sheet_id`. The current iOS client
  has no ranked-results operation, despite the prose contract listing one.
- Capture creation supports both legacy flat fields and the prose contract's
  nested `metadata`/`quality` payload. In the published schema, the flat field
  is named `exposure_duration`, whereas nested metadata uses
  `exposure_duration_seconds`.
- Measurement uploads differ materially: the prose contract requires a
  top-level `scoring_algorithm_version` and nested statistics; the published
  schema describes neither. It instead permits RGB values as arrays, objects,
  or JSON strings and requires each pair score to carry its own algorithm
  version plus `score`, `similarity`, or `distance`.
- The prose contract does not define success bodies for measurement or judgment
  uploads. The server/spec return `200` JSON acknowledgement bodies with the
  capture ID and accepted counts, rather than a `204`-only contract.

## Implementation handoff

Before the implementation PR is opened, resolve the two schema-completeness
gaps with the API owner or document a deliberately maintained adapter. The PR
description must include the deltas above and identify whether the vendor is a
pinned JSON snapshot or a reproducible fetch from the published endpoint.
