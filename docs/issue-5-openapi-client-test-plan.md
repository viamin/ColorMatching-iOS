# Issue #5 OpenAPI client: test plan and implementation handoff

## Acceptance-criterion map

| Criterion | Smallest credible verification | Current test-writing evidence |
| --- | --- | --- |
| Generated package dependencies and a checked-in OpenAPI document | Inspect `iOS/Package.swift`, the vendored spec's source URL/revision, and generated sources in the implementation PR. | Not yet implemented; this requires the implementation change. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent URL-protocol stub tests invoke each production facade method and assert the request route/body plus decoded typed response. | `APIClientTests` now covers manifest and recent sheets; existing tests cover the three write endpoints. Ranked results has no app facade yet, so its test must be added with the generated client. |
| Hand-written transport models are replaced while client-only models remain | Inspect the generated client source and the app facade's imports; compile the application against generated request/response types. | Not yet implemented; this is a compile-time and code-review criterion, not something a broad suite can infer. |
| Generated-client tests never use a live server in CI | Run the focused XCTest target with `MockURLProtocol`; each response is fixed JSON and each request is observed locally. | The permanent tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` use only `MockURLProtocol`. |
| PR description records prose-contract deltas and endpoint gaps | Compare the vendored revision of `GET /api/v1/openapi.json` with `docs/color-matching-api-contract.md`, then record the diff in the implementation PR description. | Blocked until the implementation PR vendors a specific spec revision. The initial gap is confirmed: the current iOS facade has no ranked-results method. |

## Local stub fixtures

The manifest and recent-sheets tests use representative OpenAPI-shaped JSON and a `URLProtocol` test double. Capture creation, measurement upload, and judgment upload already use the same seam. The implementation must preserve this injection point when replacing the transport layer so the generated client is exercised without a live Phoenix service.

## PR-description checklist for the implementation run

- Source URL and immutable revision/hash of the fetched OpenAPI document.
- Generator and runtime package versions, plus the regeneration command.
- Prose-contract versus spec deltas, including changed required/nullable fields, enums, paths, status codes, and date formats.
- Endpoint gaps: confirm whether ranked results is present in the spec and document any required adapter work; list any used endpoint absent from the spec.
- Focused `swift test --disable-sandbox` result and the exact local-stub tests run.
