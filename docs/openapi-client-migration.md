# OpenAPI client migration plan (issue #5)

This document is the PR evidence plan for replacing the iOS hand-written API
layer. It is intentionally written before implementation so that every
acceptance criterion has a narrowly scoped verification.

## Criterion verification map

| Criterion | Verification | Evidence location |
| --- | --- | --- |
| Generator/runtime dependencies and a vendored OpenAPI document are added | Focused adoption test inspects the package declaration and vendored document. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientAdoptionTests.swift` |
| The generated document covers manifest, recent sheets, capture creation, measurements, judgments, and ranked results | Focused adoption test checks all six OpenAPI paths. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientAdoptionTests.swift` |
| The adapter sends and decodes manifest/recent/capture/measurement/judgment requests through local responses | Permanent stubbed-client tests; no live server is contacted. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Hand-written request/response transport models are removed in favor of generated types | Focused adoption test guards the removal of legacy request envelopes and requires generated-client use. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientAdoptionTests.swift` |
| `swift test --disable-sandbox` is green | Run from `iOS/` in the implementation PR after dependencies and generated sources are present. | CI/test command output |
| Prose-contract deltas and endpoint gaps are captured | Human/external comparison against `viamin/color_matching#110`'s published specification. | PR description, below |

## Intended implementation boundary

Vendor the upstream document at `iOS/openapi/color-matching.yaml`. Configure
`swift-openapi-generator` to generate a dedicated client target, and retain
only an app-facing adapter for converting client-side measurement-domain values
to generated request types. `MeasurementCore` remains client-side domain code.

## Prose contract comparison (published upstream #110)

The upstream application now serves its generated document at
`GET /api/v1/openapi.json`; that route is intentionally outside the authenticated
API scope. The six companion paths are present in its router and controller
operation declarations. The implementation PR must vendor the response from
that endpoint, rather than reconstructing a specification from these notes.

Known deltas from `docs/color-matching-api-contract.md`:

- Capture identifiers are decimal strings (for example, `"123"`), not the
  illustrative `"capture_123"` convention in the prose examples.
- Measurement and judgment uploads return `200 OK` acknowledgement JSON
  (`capture_id` plus accepted-row counts), rather than the prose contract's
  implied empty `204` response.
- The published operations include typed `401`, `404`, and `422` error
  responses; the prose contract did not specify those response schemas.
- Ranked results now have a declared OpenAPI response schema. The prose
  contract named the endpoint but left its response as prose, so the vendored
  document is the authority for its generated result type and stub fixture.

No endpoint gap was found for the six companion surfaces. The upstream API also
documents routes outside this app's scope; they are not generated for this
client.
