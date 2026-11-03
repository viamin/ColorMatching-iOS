# Issue #5 OpenAPI client verification plan

This test-writing change records the smallest credible verification for each
acceptance criterion before implementation. The upstream OpenAPI document from
`viamin/color_matching#110` is not present in this repository, so comparison
against the published API remains an external dependency.

| Criterion | Verification | Current status |
| --- | --- | --- |
| Package contains `swift-openapi-generator` and `swift-openapi-runtime` | Permanent XCTest reads `iOS/Package.swift` and asserts both dependency names. | Red: neither dependency is declared. |
| Generated client supports manifest and recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent local-stub XCTest coverage in `APIClientTests`; existing tests cover capture, measurements, and judgments, and the new stub covers manifest and recent sheets. Add ranked-results coverage when its generated operation is available. | Partial: ranked results has no current client operation; generated types do not exist. |
| Generated types replace hand-written API models | Implementation review plus compile-time use of the generated target. | Blocked on the upstream spec and implementation phase. |
| Generated client works with local stubbed responses | `APIClientTests` uses `URLProtocol` stubs only; no live endpoint is contacted. | Manifest/recent test is green once Swift tooling is available. |
| Contract deltas and endpoint gaps are recorded in the PR | Inspect the fetched or vendored OpenAPI document against `docs/color-matching-api-contract.md`; include the resulting diff in the PR description. | Not run: no upstream document is available locally. |
| `swift test --disable-sandbox` passes | Run after generated client implementation. | Not run: this container has no `swift` executable. |

## Known baseline endpoint gap

The prose contract defines `GET /api/v1/test_sheets/:sheet_id/ranked_results`,
but the current hand-written `APIClient` has no corresponding method. The
implementation must include this operation in the generated client and add a
local-stub response test for it.

## PR description checklist

- State the source and pinned revision of the fetched or vendored OpenAPI file.
- List each field, enum, status-code, authentication, and endpoint difference
  found between the document and the prose contract.
- State whether ranked results and every other used surface appears in the
  document; enumerate any missing operations as endpoint gaps.
- Link the final `swift test --disable-sandbox` output and the stub tests.
