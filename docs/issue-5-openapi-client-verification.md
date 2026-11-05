# Issue #5 OpenAPI client verification plan

## Criterion coverage

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Package contains `swift-openapi-generator` and `swift-openapi-runtime`, and a fetched/vendored document covers every app operation | Focused package/document contract test | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedOpenAPIContractTests.swift` (red until the implementation adds both dependencies and `iOS/OpenAPI/openapi.json`) |
| Generated client handles manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results with no live server | Permanent stubbed HTTP client tests | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; manifest and recent-sheet stub coverage is added here. The implementation must add the ranked-results stub once its generated operation name is known. |
| Hand-written transport models are replaced; client-only measurement and camera models remain | Source review plus compile-time use of generated types | Human review of the implementation diff and a green `swift test --disable-sandbox`; this cannot be proved by the pre-implementation tests alone. |
| Contract delta and endpoint gaps are recorded in the PR | Inspectable PR description | This document is the PR-description draft; final wording must be copied to the PR body by the implementation/PR run. |

## Upstream contract inspection (2026-11-05)

`viamin/color_matching#110` is closed. Its router exposes all six required routes, including `GET /api/v1/test_sheets/:sheet_id/ranked_results`; the current iOS client does not call that endpoint. The published document is served dynamically at `/api/v1/openapi.json`, so the implementation should fetch and vendor that response as `iOS/OpenAPI/openapi.json` before code generation.

The prose contract differs from the upstream implementation in material response details:

- Ranked results are now explicitly versioned as `lps-ranked-results/v1` and include aggregate/capture timing, score statistics, current judgment, and printer-profile provenance. The prose contract only described that endpoint narratively.
- The real recent-sheets renderer currently always returns `title: null`; the prose contract permits a nullable title, which remains compatible.
- The real printer-profile response uses printer make/model, paper type, ink type, ICC profile, print settings, driver information, calibration, and notes. It is not the prose example's `{id, name, paper, ink, settings}` shape.
- The current iOS app locally ranks pairs and uploads those scores, but has no hand-written ranked-results retrieval method. This is the endpoint gap the generated client must close.

## Red-phase status

`GeneratedOpenAPIContractTests` is intentionally red until the implementation phase vendors the document and configures the two Swift OpenAPI packages. The existing transport tests use `URLProtocol` stubs and do not contact a live server.
