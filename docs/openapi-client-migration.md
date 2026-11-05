# OpenAPI client migration verification plan

This document records the criterion-level test plan for issue #5. It is deliberately
committed with the red-phase tests so the implementation can make each assertion pass
without changing the acceptance target.

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| The package uses `swift-openapi-generator` and `swift-openapi-runtime` and vendors the provider contract | Focused unit test reads `Package.swift` and the vendored OpenAPI JSON | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` |
| The generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Focused unit test asserts each required method/path in the vendored OpenAPI document | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` |
| Generated calls decode and encode local stubbed responses | Permanent service tests using `URLProtocol`; extend `APIClientTests` as the generated adapter lands | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| The prose contract is reconciled with the published contract | Human review of this comparison against the vendored provider document at the PR head | This document and the PR description |

## Provider-contract observations

Evidence was taken from `viamin/color_matching` issue #110's merged source on 2026-11-05:
the provider serves the machine-readable contract at `GET /api/v1/openapi.json`.

Compared with `docs/color-matching-api-contract.md`, the provider's OpenAPI
conformance tests document these deltas that the generated client must preserve:

- `CaptureRequest` has two allowed variants (`anyOf`) rather than only the single,
  fully populated request shape illustrated in the prose contract.
- `PairScoreRequest` requires only `algorithm_version` and `pair_id`, and supports
  three variants; the prose contract presents `distance` and `similarity` as always
  present.
- `RgbPayload` supports three variants; the prose contract specifies only an object
  with `r`, `g`, and `b` fields.
- The OpenAPI document covers ranked results, but the current iOS `APIClient` has no
  ranked-results method or test. This is an app-side gap to close in implementation.

The provider's test lists all six companion paths used by this app, so no server
endpoint gap was found for this issue's requested surfaces.
