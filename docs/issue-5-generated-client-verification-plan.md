# Issue #5 generated-client verification plan

This document is the run evidence and PR-description seed for the test-writing
phase of issue #5. It maps each acceptance criterion to the smallest credible
verification before implementation begins.

## Acceptance criteria

| ID | Criterion | Verification | Current evidence/status |
| --- | --- | --- | --- |
| AC-1 | Add `swift-openapi-generator` and `swift-openapi-runtime`, and fetch or vendor the upstream document. | Inspect `iOS/Package.swift`, the vendored/fetched OpenAPI document, and generated-source regeneration diff. | `not_run`: implementation-phase work. The upstream issue is closed, but its document is served at runtime and is not checked into this repository. |
| AC-2 | Generate the manifest, recent-sheet, capture, measurement, judgment, and ranked-results client surfaces. | Compile the generated target and exercise every operation using a local `URLProtocol` stub. | `not_run`: the current handwritten client has no ranked-results operation, so a complete generated-surface test cannot compile until the implementation phase. |
| AC-3 | Replace handwritten API models while retaining client-side models. | Inspect the dependency boundary plus compile the app target; regression tests verify wire payloads at that boundary. | `not_run`: implementation-phase work. |
| AC-4 | Exercise the generated client against local stubbed responses, with no live server in CI. | Permanent local-stub test suite at `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. | `passed` for the existing manifest, recent-sheet, capture, measurement, and judgment behaviors; ranked results remains blocked by AC-2. |
| AC-5 | PR description records contract deltas and endpoint gaps. | Inspect this document and compare the vendored spec with `docs/color-matching-api-contract.md` during implementation. | `not_run`: a concrete delta analysis requires the published document to be fetched from the running upstream API. |
| AC-6 | `swift test --disable-sandbox` is green after generated types are wired in. | Run the exact command after generation. | `not_run`: generated types are not wired in during the tests-only phase. |

## Permanent local-stub coverage

`APIClientTests` injects an ephemeral `URLSession` configured with
`MockURLProtocol`; it never contacts a live server. The focused tests cover:

- manifest and recent-sheet GET decoding and bearer authentication;
- capture-session request encoding and response decoding;
- measurement upload payload encoding, including the scoring version;
- judgment upload path and payload encoding.

The capture submission flow is recurring behavior, so this is a permanent
regression suite, not an ephemeral PR test. The implementation phase must
update these tests to instantiate the generated operation types and add the
ranked-results response fixture before marking AC-2 or AC-4 complete.

## Upstream contract evidence and PR-description seed

On 2026-11-03, `viamin/color_matching#110` was closed and specifies that the
machine-readable document is served at `GET /api/v1/openapi.json`. The
repository tree does not contain a vendorable OpenAPI file. This run could not
retrieve a deployed host, so it makes no claim about field-level contract
deltas.

Known endpoint gap in the iOS client: the prose contract describes
`GET /api/v1/test_sheets/:sheet_id/ranked_results`, while the current
`APIClient` has no corresponding operation. The implementation PR description
must replace this preliminary note with a field-by-field comparison of the
vendored OpenAPI document and `docs/color-matching-api-contract.md`, including
any request/response/status-code or enum differences.
