# Issue #5 verification plan and PR evidence

## Acceptance-criterion map

| Criterion | Smallest credible verification | Test-phase status |
| --- | --- | --- |
| Package contains `swift-openapi-generator` and `swift-openapi-runtime`; the published OpenAPI document is fetched or vendored | Inspect `iOS/Package.swift`, the checked-in OpenAPI input, and generated target at the PR head | Not yet implementable: neither dependency nor published/spec fixture exists in this repository. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent `URLProtocol` stub tests invoke each generated operation and decode representative responses | Existing permanent stubs cover capture creation, measurement upload, and judgment upload. This change adds manifest and recent-sheet tests. Ranked results has no current app client operation or response contract to exercise. |
| Hand-written API models are replaced while client-side measurement models remain | Compile the app against generated types; inspect the app-facing adapter for only client-side models | Not yet implementable in this tests-only phase. |
| Generated client is exercised with local stubbed responses | `swift test --disable-sandbox` runs the permanent `APIClientTests` without network access | Blocked in this container: the Swift toolchain is unavailable (`swift: No such file or directory`). |
| PR describes contract deltas and endpoint gaps | Inspect this section after comparing the published OpenAPI document with `docs/color-matching-api-contract.md` | Blocked on viamin/color_matching#110: no published OpenAPI document is available in this checkout. |

## Current contract and endpoint gaps

The prose contract describes `GET /api/v1/test_sheets/:sheet_id/ranked_results`, but the app's current `APIClient` has no ranked-results operation and the UI does not fetch it. Its prose response is intentionally unconstrained ("latest or aggregate" with several named concepts), so it cannot be represented reliably in a generated client until the published OpenAPI schema defines the response.

The current manual API layer has app-defined Codable request/response types. The implementation PR must compare the actual OpenAPI operation IDs, requiredness, nullability, status responses, date formats, and enum wire values against the prose document before removing those types. This document must be updated with the observed deltas and the resulting endpoint coverage.

## Tests added in this red-phase PR

`iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` now stubs and verifies the manifest and recent-sheet read operations. Like the existing upload tests, these tests use `MockURLProtocol`; they make no live-server request and should be migrated to the generated client's transport/configuration in the implementation phase.
