---
module: ios-api-client
tags: [openapi, generated-client, testing]
problem_type: verification-plan
---

# Issue #5 verification plan

This test-writing change deliberately does not modify production code. The implementation run must vendor the upstream document, add `swift-openapi-generator` and `swift-openapi-runtime`, and replace the hand-written wire models.

| Criterion | Smallest credible verification | Status at this head |
| --- | --- | --- |
| Generated dependencies and vendored spec | Inspect `iOS/Package.swift` and the pinned upstream OpenAPI artifact | Not run: implementation not present in the tests-only phase. |
| Manifest and recent-sheet client operations | Permanent `APIClientTests` local `URLProtocol` stubs | Covered by tests added in this PR. |
| Capture creation, measurement upload, judgment upload | Permanent `APIClientTests` local `URLProtocol` stubs | Covered by existing tests. |
| Ranked results generated operation | Local stub that decodes the generated ranked-results type | Not run: the current iOS app has no ranked-results API method; add this in the implementation run. |
| Hand-written wire models removed | Inspect the application-core API boundary and compile generated operation types | Not run: implementation not present in the tests-only phase. |
| No live server in CI | All client tests use `MockURLProtocol` with literal payloads | Covered by `APIClientTests`. |
| Contract deltas in PR | Human inspection of this document and the implementation PR description against upstream spec | External evidence required. |

## Upstream contract evidence and deltas

Evidence was inspected from `viamin/color_matching` at the `main` branch implementation of issue [#110](https://github.com/viamin/color_matching/issues/110): `ColorMatchingWeb.ApiSpec`, `ColorMatchingWeb.ApiSchemas`, `TestSheetJSON`, and `CaptureController`.

- The published spec serves `GET /api/v1/openapi.json` and includes all requested paths.
- `ranked_results` exists upstream but is not currently called by the iOS app; generated support and a stubbed response test are required in the implementation run.
- The prose contract's printer profile fields (`id`, `name`, `paper`, `ink`, `settings`) differ from upstream's rendered fields (`printer_make_model`, `paper_type`, `ink_type`, `icc_profile`, print-driver/calibration fields); the OpenAPI manifest schema currently guarantees only its compatibility version, sheet id, and scoring version.
- The prose says measurement/judgment uploads are empty responses, while the published contract returns acceptance counts and `capture_id` with HTTP 200.
- The prose declares `scoring_algorithm_version` and measurement `stats`; the upstream measurement-request schema does not require either and does require `normalized_linear_rgb_median`.
