# Generated OpenAPI client migration: PR notes

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Package includes `swift-openapi-generator` and `swift-openapi-runtime`; the published spec is pinned or vendored | `APIClientTests.testPackageConfiguresGeneratedClientAndPinnedOpenAPISpecification` asserts the SPM manifest declares the generator/runtime and a committed spec exists. | Failing until the implementation run adds these artifacts. |
| Typed client covers manifest/recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent local-stub API integration tests make each operation against success stubs and assert request paths/payloads plus decoded output. | Manifest/recent and three write operations are covered; ranked-results test is blocked on the generated operation type. |
| Hand-written transport models are replaced while client-only models remain | Code review of the generated target and `APIClient` adapter; compilation verifies generated type usage. | Not run: this requires implementation. |
| Generated client works without a live server | `APIClientTests.testCaptureUploadFlowUsesOnlyLocalStubbedAPIResponses` runs the recurring capture/upload flow against `MockURLProtocol`; the same test suite runs with `swift test --disable-sandbox`. | Not run in red phase; tests intentionally expose absent package/spec wiring. |
| PR records prose-contract deltas and endpoint gaps | Inspect the live server's published OpenAPI JSON at the pinned revision and compare with `docs/color-matching-api-contract.md`; reviewer verifies the PR description. | External evidence required after the spec is vendored. |

## Server dependency and scope

`viamin/color_matching#110` is closed via `viamin/color_matching#113` (merge commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f`). The server router exposes the document at `/api/v1/openapi.json` and includes all required routes:

- `GET /test_sheets/recent`
- `GET /test_sheets/:sheet_id/manifest`
- `GET /test_sheets/:sheet_id/ranked_results`
- `POST /test_sheets/:sheet_id/captures`
- `POST /captures/:capture_id/measurements`
- `POST /captures/:capture_id/judgments`

The current iOS hand-written client has no ranked-results operation. That is the known endpoint gap to close in the implementation run.

## Contract delta notes for the implementation PR description

The prose contract already describes the five current client operations plus ranked results, but its ranked-results response is intentionally unspecified. The real OpenAPI document must be fetched and pinned before claiming any field-level deltas. At implementation time, record:

1. the source URL and immutable server revision of the vendored/fetched document;
2. each request/response field, nullability, enum, and status-code difference from the prose contract;
3. the concrete ranked-results schema and whether it changes current UI behavior; and
4. any `/api/v1` operations present in the server spec but intentionally out of scope for iOS.

This avoids presenting assumptions from the prose contract as evidence about the generated server contract.
