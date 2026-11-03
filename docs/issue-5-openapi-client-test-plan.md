---
module: ios-api-client
tags: [openapi, swift, tdd]
problem_type: acceptance-criteria-plan
---

# Issue #5 OpenAPI client verification plan

This red-phase change intentionally adds tests before the generated client exists.

| Criterion | Smallest credible verification | Evidence location | Current result |
| --- | --- | --- | --- |
| Generator/runtime dependencies and vendored upstream document | Focused package/spec contract test reads `Package.swift` and the vendored document, asserting all six app paths exist | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientAdoptionTests.swift` | Red: dependencies, target, and document are absent |
| Generated types wired into the app | Focused test requires the generated `ColorMatchingAPI` module | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testGeneratedOpenAPIClientIsAvailable` | Red: module is absent |
| Manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results work without a live server | Permanent local-stub integration test using `MockURLProtocol`; it compiles only when the generated module is added, so it cannot accidentally exercise only the legacy implementation | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testGeneratedClientHandlesEveryCompanionSurfaceAgainstStubbedResponses` | Not compiled until generated module exists |
| Prose-contract deltas and endpoint gaps recorded in PR description | Inspect upstream OpenAPI-producing source at `viamin/color_matching` commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f` and copy the findings below into the implementation PR description | This document | Complete external inspection; PR body still requires update during implementation |

## Contract deltas and gaps found

- The published manifest schema guarantees only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose contract additionally relies on the full page, marker, patch, pair, and profile shape. The iOS app cannot safely replace its client-side sheet-analysis model from this schema alone.
- The published ranked-results schema guarantees only `schema_version` and `sheet_id`, while the prose contract asks for source colors, scores, labels, capture provenance, printer profile, and scoring-algorithm version. This endpoint remains under-specified for a typed result model.
- Capture creation accepts both the prose nested `metadata`/`quality` request and a legacy flat request. Its metadata requirements omit several fields that the prose calls optional or expected.
- The prose specifies empty `204` responses for measurement and judgment uploads; the published spec defines `200` JSON responses with capture and count fields.
- The prose requires a top-level `scoring_algorithm_version`, measurement statistics, and optional normalized RGB values. The published measurement schema omits the top-level version and stats, makes normalized RGB required, and accepts RGB arrays, objects, or JSON strings. Pair scores support `score`, `similarity`, or `distance`.

Implementation must retain purely client-side analysis models and document any adaptation required by these gaps rather than pretending the narrower server schema describes them.
