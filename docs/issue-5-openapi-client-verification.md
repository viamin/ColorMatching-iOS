# Issue #5 OpenAPI client verification plan

This is the tests-only phase. The generated client, Swift package dependencies, and vendored OpenAPI document are intentionally absent until the implementation phase.

## Criterion map

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Vendored OpenAPI document covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `OpenAPIContractTests.testVendoredSpecificationCoversEveryAppSurface` parses the vendored JSON and asserts each exact path, method, and success status | Red: `iOS/openapi/color_matching.openapi.json` has not been vendored |
| App request/response wiring works without a live Phoenix server | `APIClientTests` uses `MockURLProtocol` to stub manifest, recent sheets, capture, measurement, and judgment traffic | Existing coverage plus manifest/recent additions; run once Swift toolchain is available |
| Generated client replaces hand-written models and dependencies resolve | Inspect the implementation diff and package manifest; compile with `swift test --disable-sandbox` | Not runnable in this test-only phase |
| Contract deltas and endpoint gaps are recorded for the PR | This document's `Contract deltas` section, verified against upstream route/controller/spec source | Completed external-source review; final PR body must carry this section |

## Contract deltas

Source reviewed on 2026-11-01: upstream [issue #110](https://github.com/viamin/color_matching/issues/110), the [`/api/v1/openapi.json` route](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex), and the [capture controller](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/capture_controller.ex).

- The real API publishes the OpenAPI document dynamically at `GET /api/v1/openapi.json`; it is not a checked-in JSON file. The implementation should fetch and vendor that response as `iOS/openapi/color_matching.openapi.json` so regeneration is reproducible.
- Authentication is required for all six app surfaces in the upstream router. The prose contract's development-only unauthenticated allowance is not part of the published contract.
- Both upload endpoints return `200` JSON acknowledgement objects (`capture_id` plus measurement/pair-score or judgment counts). The prose contract describes request bodies but no success response, and existing tests use `204` empty responses.
- Ranked results are fully specified upstream and use the `lps-ranked-results/v1` response schema. The prose contract names the endpoint but leaves its response shape unspecified.
- The manifest includes `created_at`, `printer_profile`, and `capture_profile`; the app's current `SheetManifest` consumes only geometry and pair data. Generated types will expose the full server schema while client-side analysis models remain local.

## Endpoint gaps

No gap was found for the six iOS surfaces. Upstream additionally exposes printer-profile/palette endpoints and two non-`/api/v1` POST APIs; they are outside this issue's scope.

## Implementation handoff

1. Vendor the response from the deployed `GET /api/v1/openapi.json` endpoint and add the Swift OpenAPI generator/runtime package dependencies.
2. Generate only the six asserted operations and replace the wire models in `APIClient`; retain `MeasurementCore` analysis types.
3. Update upload stubs to their published `200` acknowledgement responses and add a ranked-results generated-client stub test.
4. Run `swift test --disable-sandbox`; copy the Contract deltas and Endpoint gaps sections into the PR description.
