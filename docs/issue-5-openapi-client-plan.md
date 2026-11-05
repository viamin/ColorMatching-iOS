# Issue #5: generated OpenAPI client plan and contract deltas

This record is the proposed PR-description evidence for replacing the iOS
hand-written API layer. The upstream authority was inspected at
`viamin/color_matching` issue #110 and its `main` branch on 2026-11-05.

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generator/runtime and vendored contract are installed | Focused unit test checks the SwiftPM manifest and vendored upstream document exist. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientIntegrationTests.swift` |
| All app-used surfaces are generated | Permanent local-stub tests exercise manifest, recent sheets, create capture, measurements, judgments, and ranked results through the generated wrapper. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| API models are generated rather than manually maintained | Compile the app and tests after removing the hand-written transport Codable models; generated source is compiled by SwiftPM. | `swift test --disable-sandbox` |
| Generated client handles responses without a live service | `URLProtocol` local stubs assert request paths/auth/payloads and decode representative documented responses. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| PR contains contract deltas | Human review of this section against the upstream served OpenAPI document. | This document and PR description |

The manifest and recent-sheet tests are added in this test-writing change. The
existing capture/measurement/judgment stub tests become generated-client tests
when the wrapper is switched. The implementation change must add the ranked
results stub test because no ranked-results public API exists yet.

## Published-contract deltas

- The published capture schema supports the prose contract's nested
  `metadata`/`quality` payload, but also accepts a legacy flattened capture
  representation. The iOS client should continue emitting the nested form.
- Capture creation returns `201`, while measurement and judgment uploads return
  `200` JSON receipts (`capture_id` plus accepted-item counts). The prose
  contract documented only the capture response and treated both uploads as
  response-less.
- The published measurement schema requires both `linear_rgb_median` and
  `normalized_linear_rgb_median`; the prose contract made the normalized value
  optional. It does not describe the current client-only `stats` object or the
  top-level `scoring_algorithm_version` field, although additional fields are
  accepted by the server.
- RGB upload values may be an RGB object, an array, or a JSON-encoded string;
  the prose contract documented only the object form. The iOS client should
  retain object encoding.
- Ranked results are now defined as `lps-ranked-results/v1`, including
  provenance, aggregate score, source colors, observations, and printer
  profile. The prose contract previously gave only a narrative response
  description.
- The published printer-profile fields are `id` (integer),
  `printer_make_model`, `paper_type`, `ink_type`, and optional calibration and
  driver metadata. The prose contract instead described string `id`, `name`,
  `paper`, `ink`, and `settings`.

## Endpoint gap discovered

There is no endpoint gap for the six iOS surfaces: manifest, recent sheets,
capture creation, measurement upload, judgment upload, and ranked results are
all present in the upstream router/spec. The current iOS public `APIClient`
does not yet expose ranked results; implementation must add that wrapper method
over the generated operation.
