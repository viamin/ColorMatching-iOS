---
module: ios-api-client
tags: [openapi, swift, generated-client, issue-5]
problem_type: test-plan
---

# Issue #5: generated OpenAPI client verification plan

This is the tests-first plan for replacing the iOS hand-written `/api/v1` layer. It deliberately uses only local `URLProtocol` stubs; no live Phoenix server is a CI dependency.

| Criterion | Smallest credible verification | Evidence at this revision |
| --- | --- | --- |
| Add the generator/runtime and vendor the upstream document | A permanent XCTest parses `iOS/OpenAPI/color_matching.openapi.json` and requires each app-used operation plus stable `operationId` values. | `OpenAPISpecContractTests.testVendoredOpenAPIDocumentDescribesEveryIOSClientOperation` (red until the document is vendored) |
| Generate the six app-used surfaces | The same contract test checks manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results paths/methods. | `OpenAPISpecContractTests.swift` |
| Wire generated types through the client | Permanent local-stub client tests exercise decoded reads and encoded writes through the app-facing client adapter. The implementation must retain these tests while replacing the hand-written transport models. | `APIClientTests.swift` |
| Local generated-client tests | `URLProtocol` stubs provide deterministic HTTP responses and inspect request method/path/body without a server. | `APIClientTests.swift` |
| Record prose-contract deltas and endpoint gaps | Human/external inspection of upstream #110's served document and source remains required; document the result in the implementation PR description. | Not automated in this tests-only revision |

## Upstream inspection as of 2026-11-04

`viamin/color_matching#110` is closed. Its router exposes all six iOS paths, and the test-sheet controller declares OpenAPI operations for manifest, recent sheets, and ranked results. However, the upstream `main` repository tree did not contain a checked-in OpenAPI JSON artifact when inspected, so the future implementation must fetch the served `/api/v1/openapi.json` document or obtain its exact source revision before vendoring it.

The prose contract is incomplete for ranked results: it names only the endpoint and describes the response informally. The upstream renderer returns `lps-ranked-results/v1` with capture counts/timestamps, printer profile, algorithm versions, and per-pair aggregate scores plus judgment provenance. The prose contract's printer-profile fields also differ from the upstream renderer's `printer_make_model`, `paper_type`, `ink_type`, and related calibration fields. These are PR-description deltas requiring human review against the vendored served document, not assumptions for the generated client.
