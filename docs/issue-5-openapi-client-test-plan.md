# Issue #5 OpenAPI client verification plan

This tests-only change establishes the verification contract before the generated-client implementation begins.

| Criterion | Smallest credible verification | Initial status |
| --- | --- | --- |
| Generated client dependencies and a reproducible API document | `APIClientTests.testOpenAPIClientIsGeneratedFromVendoredSpec` checks `iOS/Package.swift` and the vendored `iOS/OpenAPI/color-matching-api-v1.json` snapshot. | Failing until implementation |
| Manifest and recent-sheet reads | `APIClientTests.testGeneratedClientFetchesManifestAndRecentSheetsFromLocalStubs` exercises both operations through `MockURLProtocol`; no live server is used. | Passing on the legacy client; must remain green through replacement |
| Capture creation, measurement upload, and judgment upload | Existing focused local-stub tests in `APIClientTests` verify endpoint paths and wire payloads. | Passing on the legacy client; must remain green through replacement |
| Ranked results | `APIClientTests.testGeneratedClientSupportsRankedResults` is deliberately red until the generated-client adapter exposes and exercises the endpoint against a local stub. | Failing until implementation |
| Prose-contract deltas | Inspect the vendored snapshot from `viamin/color_matching` and record the comparison in the implementation PR description. This requires the actual published document; the upstream router is only supporting external evidence. | Not yet runnable |

## External evidence gathered for the implementation PR

`viamin/color_matching#110` is closed. Its router exposes the required API operations and serves the generated document at `GET /api/v1/openapi.json`:

- `GET /api/v1/test_sheets/recent`
- `GET /api/v1/test_sheets/:sheet_id/manifest`
- `GET /api/v1/test_sheets/:sheet_id/ranked_results`
- `POST /api/v1/test_sheets/:sheet_id/captures`
- `POST /api/v1/captures/:capture_id/measurements`
- `POST /api/v1/captures/:capture_id/judgments`

The prose contract already lists these routes, but it does not establish the generated schemas, requiredness, enums, or response payload for ranked results. The implementation PR must fetch and pin the document before declaring the contract-delta criterion complete.
