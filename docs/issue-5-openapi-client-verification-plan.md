# Issue #5 OpenAPI Client Verification Plan

This test-writing change records the smallest credible verification for each
acceptance criterion before the generated-client implementation begins. The
upstream OpenAPI document from `viamin/color_matching#110` is not present in
this checkout, so its contents and any prose-contract deltas cannot yet be
inspected.

| Criterion | Verification | Current evidence / status |
| --- | --- | --- |
| Add the generator, runtime, and upstream document | Inspect `iOS/Package.swift`, the vendored/fetched specification, and a clean package resolution at the implementation PR head. | Not run — blocked on `viamin/color_matching#110`. |
| Generate the manifest, recent-sheets, capture, measurement, judgment, and ranked-results surfaces | Permanent local-stub Swift tests: each operation must send the specified request and decode the published response type. | Manifest/recent/capture/measurement/judgment stubs are covered in `APIClientTests`; ranked-results has no current client operation or response schema and is blocked on the upstream document. |
| Replace server-owned hand-written models while retaining client-only models | Inspect the implementation diff: generated server transport/schema types replace `APIClient.swift` request/response models, while `MeasurementCore` image-analysis models remain. | Not run — implementation phase. |
| Test the generated client without a live server | Run `swift test --disable-sandbox` and inspect the URLProtocol-backed tests in `APIClientTests`. | Planned permanent unit/service tests; no live service is used. |
| Record prose-contract versus OpenAPI deltas and endpoint gaps in the PR description | Human/external evidence: compare the committed upstream OpenAPI document to `docs/color-matching-api-contract.md`; paste the concrete deltas and gaps in the PR body. | Not run — upstream document unavailable. |

The existing contract names a ranked-results route but intentionally leaves its
response shape unspecified. A typed ranked-results test must therefore be
added only after the upstream OpenAPI schema supplies that response contract.
