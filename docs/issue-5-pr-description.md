# PR description: generated OpenAPI Swift client (#5)

## What changed

This PR will replace the hand-written `Codable` transport models in
`ColorMatchingLPSAppCore` with types generated from the vended OpenAPI 3
document published by `viamin/color_matching#110`. The package will use
`swift-openapi-generator` and `swift-openapi-runtime`; its generated client
will cover the manifest, recent sheets, capture creation, measurement upload,
judgment upload, and ranked-results operations.

The client contract tests use `URLProtocol` stubs only. They never contact a
live Phoenix deployment, so they are suitable for CI.

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Generated dependency and vended spec | `APIClientTests.testPackageDeclaresOpenAPIGeneratedClientAndVendedSpecification` inspects the package manifest and the vended document's six required paths. | Expected red until implementation adds them. |
| Manifest and recent sheets | `URLProtocol`-stubbed decode tests in `APIClientTests`. | Green against current client; implementation must retain this behavior through generated types. |
| Capture creation, measurement upload, and judgment upload | Existing `URLProtocol`-stubbed request/response tests in `APIClientTests`. | Green against current client; implementation must retain this behavior through generated types. |
| Ranked results | The vended-spec assertion requires the ranked-results path. A generated-client stub test must be added when the generated operation's Swift name is known. | Blocked on vended spec/client implementation. |
| `swift test --disable-sandbox` | Run from `iOS/` after generated sources and package dependencies are added. | Not run: this red-phase commit deliberately lacks implementation. |

## Prose contract versus published API

The published API authority is `GET /api/v1/openapi.json`, introduced by
`viamin/color_matching#110`. Repository evidence from that completed issue
shows all six iOS routes are registered and specified by
`ColorMatchingWeb.TestSheetController` and `ColorMatchingWeb.CaptureController`.

Confirmed deltas from `docs/color-matching-api-contract.md`:

- The server returns `200` JSON bodies for successful measurement and judgment
  uploads (`capture_id` plus row counts); the prose contract only documents the
  request bodies and the current iOS client accepts an empty `204` response.
- Capture identifiers are decimal strings produced from database IDs. The prose
  contract's `capture_123` sample is not representative.
- The prose says ranked results "should" include source colors, scores, labels,
  capture provenance, printer profile, and algorithm version, but does not give
  a schema. The published schema is authoritative and needs generated-type
  inspection during implementation.
- All `/api/v1` test-sheet and capture routes require bearer authentication in
  the router. The prose's possible development-mode unauthenticated exception
  is not part of the published OpenAPI security contract.

Endpoint gap: there is no known route gap for the requested surfaces. The
implementation PR must vendor the served JSON and rerun this comparison against
that exact artifact, recording any field-level corrections here before merge.
