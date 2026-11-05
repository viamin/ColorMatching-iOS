# Issue #5 verification plan

This is the red-phase verification plan for replacing the hand-written iOS API
layer with a generated OpenAPI client. The published OpenAPI document from
`viamin/color_matching#110` was unavailable to this run: GitHub returned 404
for the pull-request API URL on 2026-11-05. Its exact endpoint schemas and
contract deltas therefore require external inspection before implementation.

| Criterion | Smallest credible verification | Evidence status |
| --- | --- | --- |
| Generator/runtime dependencies and vendored specification | Inspect `iOS/Package.swift`, the vendored OpenAPI document, and generated source in the implementation PR. Regenerate in CI or a checked-in generation check. | Blocked on upstream spec / implementation |
| Generated types cover manifest and recent sheets | Permanent local `URLProtocol` stub test decodes each published response through the generated client. | `APIClientTests.testFetchManifestDecodesStubbedManifest` and `APIClientTests.testFetchRecentSheetsDecodesStubbedResponse` cover the current behavior; rewire them to generated operations in implementation. |
| Generated types cover capture creation, measurement upload, and judgment upload | Permanent local `URLProtocol` stub tests assert request path, authentication, body shape, and response decoding through generated operations. | Existing `APIClientTests` methods cover current behavior; rewire them to generated operations in implementation. |
| Generated types cover ranked results | Add a permanent local-stub test once the upstream response schema is available. The app has no ranked-results client method today, so a meaningful compile-safe test cannot be written until the generated operation/type names are known. | Blocked on upstream spec / implementation |
| Hand-written API models replaced; client-only models retained | Inspect the implementation diff: generated API request/response models replace `APIClient.swift` transport models, while `MeasurementCore` analysis models remain. A focused compile/test run prevents stale mappings. | Not yet implemented |
| Contract deltas and endpoint gaps recorded in the PR | Human/external inspection of the published OpenAPI document compared line-by-line with `docs/color-matching-api-contract.md`; record deltas in the PR body. | Blocked on upstream spec |
| `swift test --disable-sandbox` | Run the package suite after generated code is wired. | Run for current red-phase tests; rerun after implementation |

The local stubs are permanent regression tests because they cover the recurring
sheet-selection and capture-upload API flow. They intentionally do not call a
live Phoenix server, keeping CI deterministic.
