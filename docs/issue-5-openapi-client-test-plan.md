---
module: ios-api-client
tags: [openapi, swift, generated-client, testing]
problem_type: test-plan
---

# Issue #5 OpenAPI client verification plan

This is the test-first handoff for replacing the hand-written `/api/v1` client.
The implementation should vendor the upstream `GET /api/v1/openapi.json` response
as `iOS/OpenAPI/color-matching-api.json` and configure Swift OpenAPI Generator to
generate only the operations listed below. The committed document makes an upstream
contract revision reviewable as a normal regeneration diff.

## Criterion map

| Criterion | Smallest credible verification | Location | Current status |
| --- | --- | --- | --- |
| Generator/runtime dependencies and vendored API document | Focused package/spec test | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientGenerationTests.swift` | Red: dependencies and document are not present. |
| Manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results operations | Focused generated-client tests using `MockURLProtocol` and fixture responses | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` plus generated-client tests to be added during implementation | Partial: manifest/recent/capture/uploads have local stubs; ranked results has no client surface. |
| Replace hand-written API models while preserving client-only measurement models | Compile generated client and its adapter against app targets | `swift test --disable-sandbox` | Not run until implementation. |
| No live server required in CI | The URL-protocol stubs in the API-client test target | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Covered for current surfaces. |
| PR records prose/spec deltas and endpoint gaps | Human review of this section against the vendored upstream document | This document and PR description | Pending implementation PR. |

## Upstream contract deltas found

Evidence reviewed from `viamin/color_matching` main branch after #110 closed:

- The prose contract leaves ranked-results response fields unspecified. The real API
  declares `lps-ranked-results/v1` and returns sheet-level provenance plus ranked
  records, score aggregates, algorithm versions, and optional observations.
- The prose treats measurement and judgment uploads as empty successful responses.
  The API returns `200` JSON with `capture_id` and accepted row counts.
- The prose printer profile uses `id`, `name`, `paper`, `ink`, and `settings`; the
  published API exposes printer make/model, paper type, ink type, ICC/driver and
  calibration metadata, print settings, and notes.
- The current upstream API documents all six app paths. No path-level gap was found;
  the only consumer gap is that the iOS client has not implemented ranked-results.

## Implementation notes

Keep `MeasurementCore` models (`RGB`, sampled measurements, and locally calculated
scores) client-side. Convert them at the boundary to generated request models. The
implementation must replace the package/spec red tests with direct generated-client
calls for all six operations; each call must be exercised through a local
`MockURLProtocol` response and must not contact a live server.
