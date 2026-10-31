# OpenAPI Client Migration Verification Plan

This is the criterion-level test plan for #5. It is deliberately based on
local `URLProtocol` stubs: CI must never need a live Phoenix service.

| Criterion | Smallest credible verification | Current test/evidence |
| --- | --- | --- |
| Package includes `swift-openapi-generator` and `swift-openapi-runtime`, and vendors or fetches the published document | Inspect `iOS/Package.swift`, the checked-in OpenAPI document, and a clean dependency resolution after viamin/color_matching#110 is accessible. | Not runnable in this test-writing change; the upstream pull request API is unavailable from this environment. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Stub each generated operation and assert its route, authentication, request serialization, and typed response decoding. | Existing `APIClientTests` cover creation and the two uploads; the added tests cover manifest and recent sheets. Ranked-results has no response schema in the prose contract and is not implemented yet. |
| Hand-written API transport models are replaced while client-only measurement models remain | Compile the app after generated types are wired in, then inspect the replacement boundary in `ColorMatchingLPSAppCore`. | Implementation-phase compile and source review. |
| Generated client works without a live server | Permanent XCTest target using `MockURLProtocol` with representative 2xx responses for all generated operations. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. |
| PR records contract deltas and endpoint gaps | Compare the checked-in published OpenAPI document against `docs/color-matching-api-contract.md`; attach the concrete delta list to the PR body. | External evidence is blocked until viamin/color_matching#110 can be fetched. |

## Known pre-implementation gaps

The prose contract declares `GET /api/v1/test_sheets/:sheet_id/ranked_results`
but specifies no response schema, and the current iOS client exposes no ranked
results request. The published OpenAPI document must define that response before
a typed local-stub test can be written.

The prose contract also permits `printer_profile`, `capture_profile`, and
`created_at` in a manifest response, while the current `SheetManifest` model
does not represent them. The migration must compare their requiredness and
shape with the published schema rather than assuming the prose is authoritative.
