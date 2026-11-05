# Issue #5: generated OpenAPI client verification plan

This is the test-writing evidence for replacing the iOS hand-written API layer.
It is intentionally limited to tests and documentation; the generator, runtime,
vendored specification, and production migration are implementation-phase work.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Status in this test-writing change |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor/fetch the published document | Inspect `iOS/Package.swift`, the checked-in OpenAPI document, and the generated-source regeneration diff in PR review. This is external/build configuration evidence, not a unit test. | Not run — implementation artifact does not exist yet. |
| Generate the six used surfaces | Permanent `ColorMatchingLPSAppTests` URLProtocol tests call the generated-client adapter against local responses for manifest, recent sheets, create capture, measurement upload, judgment upload, and ranked results. | Partially covered: manifest, recent sheets, create capture, measurement upload, and judgment upload stubs exist. Ranked-results adapter does not exist yet. |
| Replace hand-written API models with generated types | Compile the app and inspect that API-wire models are generated types while MeasurementCore-only analysis models remain local. | Not run — implementation artifact does not exist yet. |
| Swift tests against local stubs, with no live server | Run `swift test --disable-sandbox --filter APIClientTests`; the suite uses `MockURLProtocol` and `example.test`, so it cannot contact a live server. | Not run — this container has no Swift toolchain. |
| PR description records contract deltas and endpoint gaps | Human review of this file, copied into the PR description during implementation. | Recorded below; final comparison must be repeated from the vendored JSON. |

The permanent test boundary is the client adapter, not generated implementation
details. That keeps the tests stable across generator output changes while
proving request and response compatibility with stubbed published shapes.

## Published-contract deltas found before implementation

Evidence source: `viamin/color_matching` main at issue #110's published route
and schema modules, inspected 2026-11-05. The document is served by
`GET /api/v1/openapi.json`.

* The prose document describes ranked results only narratively. The server
  publishes `lps-ranked-results/v1`, aggregate timing/count fields, printer
  profile, per-pair rank/row/column/source colours, score statistics,
  observations, and per-result capture provenance. The iOS `APIClient` has no
  ranked-results method today: this is the endpoint gap to close.
* Manifest and recent-sheet responses have server-owned fields beyond the
  currently decoded local models. The generated model must preserve the
  published response shape rather than discard it silently.
* Capture creation supports both the prose's nested `metadata`/`quality`
  payload and a legacy flat payload. The generated adapter should send the
  nested form used by the iOS app.
* Measurement upload's published request requires normalized RGB and accepts
  score, similarity, or distance in a pair score. The prose also includes
  `scoring_algorithm_version` and detailed measurement statistics; the
  implementation must compare the vendored JSON rather than assume those
  fields survive generator validation unchanged.
* The server returns JSON acknowledgement bodies for successful measurement
  and judgment uploads (`capture_id` plus counts); the current prose says
  nothing about their responses, and the hand-written client discards them.
* The server spec intentionally includes API routes outside the iOS scope
  (printer profiles, palettes, colours, illuminant measurements, and image
  mapping). They are not required client surfaces for this issue.

## Implementation handoff

When the OpenAPI document is vendored, add the ranked-results stub test to
`APIClientTests` before implementing its adapter, then run the focused test
suite. Record the exact spec revision/URL and any deltas from this preliminary
server-source comparison in the PR description.
