---
module: iOS API client
tags: [openapi, swift, test-plan]
problem_type: acceptance-criteria
---

# Issue #5 verification plan

This is the test-writing phase. The production package and client are intentionally unchanged in this commit.

| Criterion | Smallest credible verification | Initial status |
| --- | --- | --- |
| Generated OpenAPI dependency and vendored/fetched document | Inspect `iOS/Package.swift` and the checked-in OpenAPI source after implementation; resolve the package. | not run — production changes are outside this phase |
| Generated client covers manifest, recent sheets, capture creation, measurements, judgments, and ranked results | Permanent local-stub tests assert the URL, authorization, request body, and decoded response for each surface. The current suite covers writes; this change adds both read surfaces. A ranked-results test must be added with the generated operation once the upstream operation ID and response schema are available. | partial |
| App uses generated API types while preserving client-only models | Compile the app and inspect the replacement of API transport DTOs. `MeasurementCore` analysis types remain client-owned. | not run — human/code inspection after implementation |
| No live server in CI | The `MockURLProtocol` tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` provide deterministic local responses. | covered, pending Swift execution |
| PR records contract deltas and endpoint gaps | Compare `docs/color-matching-api-contract.md` to `GET /api/v1/openapi.json` and record the exact diff in the implementation PR body. | not run — the dynamic upstream document is not vendored in this repository yet |

The upstream issue is [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110). It states that the machine-readable source is served at `GET /api/v1/openapi.json`; it is not committed as a static OpenAPI file in the upstream repository. The implementation should pin or vendor the retrieved document so regeneration is reproducible.
