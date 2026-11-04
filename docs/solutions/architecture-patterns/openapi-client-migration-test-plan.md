---
module: iOS API client
tags: [openapi, swift, contract-testing]
problem_type: migration
---

# Generated OpenAPI Client Migration Test Plan

This is the test-first evidence plan for issue #5. The implementation must
vendor the OpenAPI document served by `viamin/color_matching` at
`/api/v1/openapi.json`, generate the `ColorMatchingOpenAPI` Swift target from
it, and route the existing app-facing API calls through that target.

## Criterion coverage

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generator/runtime dependencies and published spec are added | Package resolution plus generated target availability | `GeneratedOpenAPIClientTests.testGeneratedOpenAPIClientModuleIsAvailable` |
| Typed client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` stubs exercise each generated operation; no live server | `APIClientTests` and the generated-client test suite |
| Hand-written transport models are replaced while measurement-domain models stay local | Compile the app target and inspect the generated-target imports | implementation-run review plus `swift test --disable-sandbox` |
| Generated client is tested with local stubs | XCTest responses use `MockURLProtocol` only | `APIClientTests.swift` |
| PR records prose-contract deltas and endpoint gaps | Human review of the PR body against the upstream spec | notes below |

## Upstream evidence and PR-description notes

Source inspected: `viamin/color_matching` commit
`47057afd58f7d46b4d4b740ca7d2d08947774471` (2026-10-31), where
`GET /api/v1/openapi.json` is served by `OpenApiSpex`.

The published spec includes all six surfaces used by the iOS app. There is no
endpoint gap for this migration.

Contract deltas to carry into the PR description:

- Measurement and judgment uploads return `200` JSON acknowledgement payloads
  (`capture_id` plus counts), whereas the prose contract specified `204` with
  no body.
- Ranked results are now concretely defined as
  `lps-ranked-results/v1`, including aggregate scores, capture provenance,
  printer profile, current judgment, and observation history. The prose
  contract only described that response narratively.
- Capture and measurement requests support the prose contract's nested
  metadata/quality and stats payloads, but the server spec also retains legacy
  flattened capture fields and `score` payloads for compatibility.
- The published manifest schema exposes compatibility fields as required but
  is intentionally less exhaustive than the full response renderer; generated
  decoding must therefore preserve the fields the app consumes rather than
  assume every rendered field is required by the upstream schema.

## Red-phase boundary

`GeneratedOpenAPIClientTests` intentionally fails until the implementation
run introduces the `ColorMatchingOpenAPI` generated target. Existing
`APIClientTests` use local stubs for the server response shapes already exposed
by the current public API, so the eventual replacement can retain behavior
while changing the underlying transport layer.
