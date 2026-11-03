# Issue #5: Generated OpenAPI client — PR evidence

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Current test-phase result |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor/fetch the OpenAPI document | Inspect `iOS/Package.swift`, the vendored spec, and generated sources in the implementation PR | Not run: tests-only phase cannot change package or source files. |
| Generate all app-used API surfaces | Local-stub tests for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Red: `APIClientTests.testOpenAPIRuntimeIsLinkedForGeneratedClient` requires the runtime before generated-client tests can compile. Existing and new stub tests cover the five currently implemented transport paths; ranked results has no app call site yet. |
| Replace hand-written API models with generated types | Human code review of the generated target plus adapters; compile the app target | Not run: this requires implementation-file changes. |
| Exercise generated client with local stubs | `swift test --disable-sandbox`, with `MockURLProtocol` responses and request assertions | Not run: the Swift toolchain is unavailable in this execution environment. |
| PR description records prose-contract deltas and endpoint gaps | Compare the published OpenAPI document to `docs/color-matching-api-contract.md`; link the immutable spec revision | Blocked: the public GitHub API returned 404 for `viamin/color_matching` PR #110 and no spec is vendored in this repository. |

## Draft PR description

### What changed

_To be completed by the implementation run after the dependency publishes an inspectable OpenAPI document._

### Contract deltas and endpoint gaps

No authoritative spec revision was available during this tests-only run. The prose contract lists six endpoints:

- `GET /api/v1/test_sheets/{sheet_id}/manifest`
- `GET /api/v1/test_sheets/recent`
- `POST /api/v1/test_sheets/{sheet_id}/captures`
- `POST /api/v1/captures/{capture_id}/measurements`
- `POST /api/v1/captures/{capture_id}/judgments`
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results`

The current iOS client has the first five surfaces, but not ranked results. The implementation run must add ranked-results generated-client coverage using a local stub; it is not currently exercised by an app call site. Once the published OpenAPI document is available, replace this section with a field-by-field comparison and the source revision/URL.
