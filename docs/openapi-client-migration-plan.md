# OpenAPI client migration evidence

This is the criterion-level plan and upstream-contract comparison for #5. It
was prepared before implementation so the generated-client change has focused,
inspectable verification rather than relying on a broad package test run.

## Upstream source

The dependency is complete in
[viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113),
which closed #110. It serves an OpenAPI 3 document at
`GET /api/v1/openapi.json`. The implementation run must vendor a fetched copy
of that document (including its source commit) rather than fabricate a spec
from this repository's prose contract.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Generator/runtime dependencies and vendored upstream document | Inspect `iOS/Package.swift`, the vendored spec, and generation plugin/config in the implementation PR. | Not implemented in this phase. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Compile the generated target and exercise each operation with `MockURLProtocol` responses; preserve the local-stub tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. | Manifest/recent/capture/upload regression coverage is added; ranked-results has no current app call and needs a new generated-client test during implementation. |
| Replace hand-written API models while retaining client-only models | Inspect the diff: API request/response types must come from generated output; `MeasurementCore` analysis/scoring types remain client-side. | Not implemented in this phase. |
| No live server in CI | `MockURLProtocol` local stubs in `APIClientTests`; verify the tests configure `URLSessionConfiguration.protocolClasses`. | Covered by the added local-stub tests. |
| `swift test --disable-sandbox` green | Run the exact command after generated output is wired in. | Not run: this container has no `swift` executable. |
| PR describes contract deltas and endpoint gaps | This document, copied/summarized in the implementation PR description, with the generated-document revision. | Covered below. |

## Contract deltas found

Compared with `docs/color-matching-api-contract.md`, upstream's current OpenAPI
schema deliberately documents only a small subset of several runtime payloads:

- `TestSheetManifest` requires only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`. The prose contract and current
  app require page geometry, registration markers, patches, and pairs to
  analyze a sheet. A generated model from the published schema cannot replace
  the app's manifest model without the server schema being expanded.
- `RankedResults` requires only `schema_version` and `sheet_id`; the prose
  contract requires source colors, scores, labels, capture provenance, printer
  profile, and algorithm version. The app currently calculates and displays
  local rankings and does not call this endpoint, so this is both an endpoint
  gap and unused surface that needs product/API direction before migration.
- The measurement request schema omits `scoring_algorithm_version` and the
  per-measurement `stats` payload that the current client sends. It requires
  `normalized_linear_rgb_median`, while the current client permits it to be
  absent. It also defines RGB as an object, array, or JSON string, which needs
  a deliberate generated-client representation.
- The capture request supports both a legacy flat shape and the current
  `metadata` envelope. The current quality object is accepted, but its fields
  are not required by the schema. `iso` is integer upstream versus `Float` in
  the current client.
- Recent-sheet `title` is explicitly required and nullable upstream, matching
  the prose contract and the added nullable-title fixture.
- Capture, measurement, and judgment uploads specify JSON success response
  bodies upstream (201/200), while the current hand-written client discards
  the latter two responses after status validation.

These are external contract gaps, not grounds to silently invent generated
types. The implementation PR should either pin an upstream revision after the
schemas are expanded or retain only the necessary explicitly client-side
adapters, with each adapter documented.
