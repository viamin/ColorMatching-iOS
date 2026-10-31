# OpenAPI Client Migration Verification

This test-writing PR covers issue #5. It deliberately does not add the
generated client or vendored specification: those implementation changes are
outside this red-phase run.

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Generator/runtime dependencies and a tracked OpenAPI document | `APIClientTests.testGeneratedOpenAPIClientConfigurationTracksEveryAppSurface` asserts the package declarations and all six required paths in `iOS/OpenAPI/openapi.json`. | Red: neither dependency nor document exists. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | The same test asserts each endpoint path in the vendored document. The implementation PR must add typed request/response calls and stubs for those operations. | Red: document is absent; ranked results has no current client method. |
| Generated client works with local stubs | Existing `APIClientTests` use `MockURLProtocol`; the implementation should migrate these tests to generated types and preserve stub-only execution. | Partially covered; existing handwritten-client tests are green when Swift is available. |
| Contract delta record | This file records the upstream-source comparison below, based on `viamin/color_matching` issue #110 and its current `TestSheetJSON`, `CaptureController`, and `ApiSchemas` sources. | Human/external evidence recorded. |

## Published-contract deltas

- The published API includes `GET /api/v1/test_sheets/:sheet_id/ranked_results`; it is absent from the prose contract's response schema and from the current Swift client.
- Measurement and judgment uploads return JSON `200` summaries (`capture_id` plus counts), while the prose contract supplies no response body and the current client expects only a successful status.
- Capture metadata is required as either a nested `metadata` object or a legacy flat shape. The prose contract only specifies the nested shape.
- The live OpenAPI schemas currently define only a subset of manifest and ranked-result fields. Generated types therefore need to preserve the app's locally owned analysis models while adapting server payloads at the boundary; upstream schema enrichment may be needed before those response types can wholly replace `SheetManifest`.

## Endpoint gaps to resolve in implementation

- Add a typed ranked-results operation and decide where its response is presented; current capture/scoring behavior must remain unchanged.
- Decode and expose measurement/judgment upload summaries if the app needs them, or explicitly discard generated responses at the boundary.
- Vendor a pinned copy of the upstream `/api/v1/openapi.json` document and regenerate in a reproducible package build step.
