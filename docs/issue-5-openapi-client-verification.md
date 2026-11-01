---
module: ios-api-client
tags: [openapi, generated-client, testing]
problem_type: verification-plan
---

# Issue #5 generated-client verification plan

## Criterion map

| Criterion | Smallest credible verification | Status in tests-only phase |
| --- | --- | --- |
| SwiftPM has `swift-openapi-generator` and `swift-openapi-runtime`; a frozen upstream document is available | Inspect `iOS/Package.swift` and the vendored OpenAPI JSON in review; `OpenAPIContractTests.testVendoredOpenAPISpecFullyTypesEveryAppSurface` validates the vendored document’s paths and required response fields | Red: implementation has not vendored the document or configured generation |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Same permanent contract test asserts all six paths and response schemas; implementation must compile generated operations into the app-core target | Red: upstream schema has the paths but does not fully describe manifest/ranked result payloads |
| Replace hand-written API types while retaining client-side measurement models | Review the generated target and app-core adapter; compile `swift test --disable-sandbox` | Not run: implementation phase |
| No-live-server generated-client tests | `APIClientTests.testFetchesManifestAndRecentSheetsFromStubbedResponses` and the existing capture/measurement/judgment tests use `MockURLProtocol` only | Passing for the current facade; regenerate/retarget during implementation |
| Contract deltas and endpoint gaps recorded | This document and the eventual PR description | Recorded below |

## Published-contract deltas and gaps

Evidence inspected from `viamin/color_matching` main (PR #113, closing #110):

- The manifest endpoint’s OpenAPI `TestSheetManifest` only requires `schema_version`, `sheet_id`, and `capture_profile`. The server’s JSON renderer also emits `sheet_version`, `manifest_url`, page geometry, registration markers, patches, and pairs—the fields this app needs to analyze a capture. A generated model from the published spec therefore cannot replace `MeasurementCore.SheetManifest` yet.
- The ranked-results schema only requires `schema_version` and `sheet_id`. The renderer emits the printer profile, capture counts/timestamps, algorithm versions, and detailed `results`; no typed generated ranked-results client can be useful until these are described.
- The prose contract leaves ranked-results response fields unspecified. The published spec identifies the route, but currently has the same response-shape gap.
- The prose upload examples imply a no-content response. The published schemas declare JSON success responses for measurements (`capture_id`, `measurement_count`, `pair_score_count`) and judgments (`capture_id`, `judgment_count`); the current handwritten client accepts any 2xx and discards these bodies.
- The published capture request preserves both legacy flat and nested forms with `anyOf`; the app’s current nested `metadata`/`quality` payload remains valid.

## Implementation handoff

Do not generate from the current upstream document until the two response schemas above are expanded, or the generated client will encode the contract’s omissions. Once corrected, vendor the exact JSON served by `/api/v1/openapi.json`, generate only the six app-used operations, and update the stub tests to invoke those generated operations (or a thin app adapter) instead of the handwritten transport.
