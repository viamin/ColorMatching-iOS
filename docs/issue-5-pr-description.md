# PR: Replace hand-written API layer with a generated OpenAPI Swift client

## Summary

This PR will vendor the upstream OpenAPI 3 document published by
`viamin/color_matching#110`, add `swift-openapi-generator` and
`swift-openapi-runtime`, and generate the typed client used by the iOS app.
The app-facing adapter will use generated request and response types for the
sheet manifest and recent sheets, capture creation, measurement and judgment
uploads, and ranked results. Measurement and image-analysis domain models that
never cross the HTTP boundary remain client-side models.

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Dependencies and vendored OpenAPI document | Focused Swift contract test asserts the package declares the generator/runtime and the document has every in-use operation. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` |
| Generated types wired to all current API surfaces | Focused Swift tests use a `URLProtocol` stub for one complete manifest-to-ranked-results flow, asserting generated request/response types and paths. | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedAPIClientTests.swift` (implementation phase) |
| No live server in CI | The same tests inject a `URLSession` configured with `MockURLProtocol`; no external endpoint is contacted. | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedAPIClientTests.swift` (implementation phase) |
| Prose-contract deltas | Human-inspectable comparison against the upstream controller/spec source at the pinned revision. | This PR description, “Contract deltas” below |
| `swift test --disable-sandbox` | Execute after generation and record the command result in PR evidence. | CI / run evidence |

The API flow is important but is not an end-to-end UI flow; a permanent focused
Swift test with local HTTP stubs is the smallest reliable regression test. No
ephemeral test is needed.

## Contract deltas found

Compared with `docs/color-matching-api-contract.md`, the upstream implementation
behind #110 differs in these material ways. This comparison was made against
the upstream router and controllers at
[`47057afd58f7d46b4d4b740ca7d2d08947774471`](https://github.com/viamin/color_matching/tree/47057afd58f7d46b4d4b740ca7d2d08947774471):

- Sheet and capture routes are protected by `bearerAuth` in the published API;
  the old prose’s development-mode unauthenticated allowance is not represented
  in the OpenAPI contract.
- `POST /captures/{capture_id}/measurements` and
  `POST /captures/{capture_id}/judgments` return `200` JSON acknowledgement
  bodies (capture ID plus accepted row counts), rather than the prose contract’s
  `204` empty response.
- The manifest and ranked-results schemas are now explicit. Ranked results use
  `lps-ranked-results/v1` and include aggregate score, judgment, capture, and
  printer-profile provenance; the prose contract left this response unspecified.
- Printer-profile fields are server metadata (`printer_make_model`, `paper_type`,
  `ink_type`, ICC/driver/calibration fields) rather than the prose’s
  `id`/`name`/`paper`/`ink`/`settings` shape.
- Capture IDs are serialized database IDs. The old example’s `capture_123`
  should not be treated as an ID-format guarantee.

The implementation must pin the exact upstream document revision used for
generation and recheck these deltas against that document, because the live
endpoint was not resolvable from this test environment.

## Endpoint gaps

No required sheet/capture route is absent from the upstream router: it exposes
manifest, recent sheets, capture creation, measurement upload, judgment upload,
and ranked results. The current iOS hand-written client has no ranked-results
method, so the implementation must add that generated-client call without
changing capture or scoring behavior.

## Dependencies

Depends on viamin/color_matching#110
