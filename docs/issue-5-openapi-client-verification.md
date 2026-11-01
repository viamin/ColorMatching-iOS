# Issue #5: generated OpenAPI client verification plan

This document is the run evidence and proposed PR-description content for the
tests-only phase of issue #5. It turns each acceptance criterion into an
inspectable check before the implementation run changes the package or app.

## Criterion map

| Criterion | Smallest credible verification | Evidence location | Phase status |
| --- | --- | --- | --- |
| Generator/runtime dependencies and a vendored API document | Unit test reads `iOS/Package.swift`, parses the vendored OpenAPI document, and asserts all six paths | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedOpenAPIClientAdoptionTests.swift` | Red: package and document are not present yet |
| Generated client covers manifest, recent sheets, capture create, measurement upload, judgment upload, and ranked results | Permanent local-URLProtocol tests exercise each generated operation through the app API boundary | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` plus the implementation-run additions | Not run: ranked-results operation has no current app API boundary |
| Hand-written transport models are replaced while client-only measurement models remain | Compile-time use of generated operation/request/response types in the API boundary; review generated source and the remaining `MeasurementCore` types | implementation PR diff and `APIClientTests` | Not run: this is an implementation-phase criterion |
| Contract deltas and endpoint gaps are recorded | External inspection of upstream issue #110 / merged PR #113 and its OpenAPI modules, compared with `docs/color-matching-api-contract.md` | `## Contract deltas` below | Recorded; must be copied into the implementation PR description |
| `swift test --disable-sandbox` is green | Run the command in `iOS/` after generation and local-stub tests are wired | CI/run log | Not run: the current environment has no `swift` executable |

## Local-stub test design

The permanent test boundary is `APIClient` with an injected `URLSession` and
`MockURLProtocol`; it makes no live network calls. Existing tests already
exercise capture creation, measurements, and judgments. The implementation run
must preserve that injection boundary while adding fixtures for manifest,
recent sheets, and ranked results. Each fixture must assert the request path,
method, bearer authorization, JSON request shape where applicable, and the
generated response decoding result.

`GeneratedOpenAPIClientAdoptionTests` is intentionally red in this phase. It
requires the implementation run to use the stable, checked-in locations
`iOS/OpenAPI/color-matching.json` and
`iOS/OpenAPI/openapi-generator-config.yaml`, and to make package dependencies
visible in `Package.swift`. It also guards all six paths used by the app:

- manifest and recent-sheet discovery;
- capture-session creation;
- measurement and judgment uploads; and
- ranked results.

## Contract deltas

Upstream issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110)
was completed by [PR #113](https://github.com/viamin/color_matching/pull/113).
The provider serves the generated document at `GET /api/v1/openapi.json`.

Compared with this repository's prose contract, the published spec/provider
has these material differences:

- Ranked results are now an actual `GET /api/v1/test_sheets/{sheet_id}/ranked_results`
  operation. The prose named that route but intentionally left its response
  shape unspecified.
- The capture request supports both the prose's nested `metadata`/`quality`
  form and a legacy flat form. `iso` is an integer in the published schema,
  while the current Swift hand-written model uses `Float`.
- Measurement uploads in the published schema require each measurement's
  `patch_id`, `linear_rgb_median`, and `normalized_linear_rgb_median`; they do
  not model the prose contract's `scoring_algorithm_version` or nested
  statistics. Pair scores require an algorithm version and one of `score`,
  `similarity`, or `distance`.
- Measurement and judgment uploads return JSON receipt/count objects with
  HTTP 200. The prose did not specify receipt bodies, and the current Swift
  client treats any 2xx response as bodyless.
- The provider's OpenAPI schemas for manifests and ranked results declare only
  their compatibility/version fields plus a small required subset. The live
  renderers provide many additional fields used by the app. This is an
  endpoint-schema gap: generation can expose only what the provider documents,
  so adapter types or a provider-spec follow-up may be needed before replacing
  the app's manifest and ranking models.

No endpoint is absent: the provider routes all six app surfaces. The schema
coverage gaps above are the blocking contract questions for the implementation
PR description, not a reason to invent new endpoints.
