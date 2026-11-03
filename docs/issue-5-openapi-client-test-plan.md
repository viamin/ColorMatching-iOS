# Issue #5 OpenAPI client verification plan

This is the test-writing-phase plan for replacing the companion app's
hand-written `/api/v1` layer with generated OpenAPI types. All network
verification uses `MockURLProtocol`; it never contacts a live Phoenix server.

| Criterion | Smallest credible verification | Status in this phase |
| --- | --- | --- |
| Generated client handles manifest and recent sheets | Permanent local-stub tests decode both responses and assert request paths. | Added; current hand-written client passes. |
| Generated client handles capture creation, measurement upload, and judgment upload | Permanent local-stub tests assert the path and JSON body for each operation. | Existing tests cover these routes. |
| Generated client handles ranked results | Permanent local-stub test for the published endpoint's response. | Blocked: the current app exposes no ranked-results operation and the upstream OpenAPI document is unavailable in this checkout. |
| Hand-written API types are replaced, while client-side models remain | Compile the app after generation and inspect the generated target plus the deleted request/response models. | Deferred to implementation; requires the upstream specification. |
| Contract deltas and endpoint gaps are recorded in the PR | Compare the vendored upstream OpenAPI document revision to `docs/color-matching-api-contract.md`; attach the resulting delta list to the PR. | Blocked pending `viamin/color_matching#110`. |

The implementation PR must keep the local-stub tests, add a ranked-results
stub test, pin or vendor the OpenAPI document revision, and record the actual
contract comparison. The prose contract currently names all six needed routes,
but it does not define a ranked-results response schema, so that response
cannot be tested credibly until the published specification is available.
