---
module: ios-api-client
tags: [openapi, swift, testing]
problem_type: test-plan
---

# Issue #5 OpenAPI Client Verification Plan

This is a tests-first PR. It deliberately does not modify production sources,
`Package.swift`, or generated code. The implementation PR must wire the
published OpenAPI document into `swift-openapi-generator` and replace the
hand-written transport models while preserving the client-side measurement
models that are not API schemas.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Planned evidence |
| --- | --- | --- |
| Generator/runtime are added and the published document is fetched or vendored | Inspect `iOS/Package.swift`, generated source, and the pinned spec origin in the implementation diff | Human/code review; not executable in this tests-only PR |
| All six used surfaces are generated and wired in | Local `URLProtocol` Swift tests exercise manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results through the generated client | `APIClientTests`; manifest/recent tests are added here, write-surface tests already exist, ranked-results test must be added with the generated operation |
| Hand-written API models are replaced, client-only models remain | Compile the app and inspect the adapter boundary | Build/code review; not executable in this tests-only PR |
| Generated client is tested with local stubs | Focused `URLProtocol` tests assert operation path, authorization, payload, and typed response decoding with no live server | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Contract deltas and endpoint gaps are in the PR description | Compare the prose contract with `viamin/color_matching` issue #110's served `GET /api/v1/openapi.json` schema and controllers | External evidence; summarized below |
| `swift test --disable-sandbox` is green | Run it in an environment containing Swift after implementation | Not run here: this container has no `swift` executable |

## Red-phase gap

The app has no ranked-results operation even though the upstream router exposes
`GET /api/v1/test_sheets/:sheet_id/ranked_results`. That operation is therefore
not represented by an executable app-client test in this PR. The implementation
PR must add the generated operation and a local-stub test for its typed response;
the exact response fields must be taken from the fetched OpenAPI document rather
than guessed from the prose contract.

## Observed contract deltas (upstream issue #110)

The upstream OpenAPI source is exposed at `/api/v1/openapi.json` and declares
all six routes. Its schema is more permissive than the prose contract in several
important areas:

- Capture creation accepts both the prose contract's nested `metadata`/`quality`
  payload and a legacy flat payload. The prose contract describes only the
  nested shape.
- Measurement RGB values accept an array, `{r,g,b}` object, or JSON-encoded
  string; prose specifies only the object. Pair scores accept `score`,
  `similarity`, or `distance`; prose supplies `distance` and `similarity`.
- Measurement and judgment uploads return a `200` JSON receipt containing the
  capture id and accepted counts. The prose contract gives no response body and
  the existing tests use `204`.
- Ranked results are now a named `lps-ranked-results/v1` response with required
  `schema_version` and `sheet_id`; the prose contract leaves its response body
  unspecified. Its remaining fields must be generated from the fetched document,
  not invented by the iOS app.

The upstream schema currently defines only a minimal manifest object even though
the server's manifest renderer has more fields. The generated model therefore
needs an adapter only where the app's image-analysis domain needs fields that
the OpenAPI document does not yet model. This is an upstream-spec completeness
gap to record in the implementation PR description.
