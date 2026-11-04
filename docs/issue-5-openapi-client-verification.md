# Issue #5 OpenAPI Client Verification Plan

This test-writing change maps each acceptance criterion to its smallest
credible verification before the generated-client implementation begins.

| Criterion | Verification | Evidence / status |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor or fetch the OpenAPI document | Inspect the package manifest, checked-in OpenAPI source, and generated sources after regeneration | Not run: implementation phase. Upstream issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) is closed, but its default branch's recursive tree had no OpenAPI document on 2026-11-04. The app must fetch the documented `GET /api/v1/openapi.json` endpoint or obtain the missing artifact before generation. |
| Generate the five used API surfaces | Local `URLProtocol` stubs invoke each typed generated operation and assert path, auth, payload, and typed response | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. Manifest and recent-sheet tests pass once Swift is available; existing capture, measurement, and judgment tests cover their current hand-written equivalents. Ranked results is an intentional red test because no operation exists. |
| Replace hand-written API models while retaining client-only models | Compile the app against generated types and review the removed API-only models | Not run: implementation phase. |
| Tests use local stubbed responses, never a live server | Permanent XCTest suite uses `MockURLProtocol` and static JSON fixtures | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; no network is used by its test client. |
| PR records prose-contract deltas and endpoint gaps | Human review of this record against the fetched published spec | Blocked on the missing published artifact. The prose contract specifies all five requested surfaces, but the current app has no ranked-results client operation. The manifest fixture deliberately includes `created_at`, `printer_profile`, and `capture_profile`, which are prose-contract fields not represented by the current `SheetManifest` model and must be reconciled with the published spec. |

## Red-Phase Result

`testRankedResultsOperationIsRequiredForGeneratedClient` deliberately fails
until the generated client exposes a typed operation for
`GET /api/v1/test_sheets/:sheet_id/ranked_results`. It must be replaced with a
real local-stubbed typed-response assertion during the implementation phase.

`swift test --disable-sandbox` could not run in this container because the
Swift toolchain is not installed (`swift: No such file or directory`). This is
an infrastructure limitation, not red-phase evidence.
