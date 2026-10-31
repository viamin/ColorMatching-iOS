# Issue #5 Verification Plan

This is the red-phase test plan for replacing the hand-written `/api/v1`
client. It deliberately does not introduce an OpenAPI dependency, generated
source, or production adapter; those belong to the implementation run after
the tests-only change is approved.

## Criterion Map

| Criterion | Smallest credible verification | Current status |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor or fetch the published document | Inspect `iOS/Package.swift`, the pinned OpenAPI document/source fetch, and generated-client build output after implementation. The upstream PR is not accessible from this environment (GitHub API returned 404 on 2026-10-31). | Not run — external spec required. |
| Generate the manifest/recent, capture creation, measurement upload, judgment upload, and ranked-results surfaces | Permanent local-stub XCTest coverage for each generated operation. `APIClientTests.testGeneratedClientMustSupportRankedResultsEndpoint` is intentionally red: ranked results is named in the prose contract but has no app-client operation. | Failed (expected red phase). |
| Replace hand-written API models while retaining client-only models | Inspect the production target after implementation and compile it; no source-inspection test is used because the public behavior and generated build are the credible evidence. | Not run. |
| Exercise generated client against local stubbed responses | `APIClientTests` uses `MockURLProtocol`, so it is deterministic and makes no live-server request. Existing capture/measurement/judgment coverage is retained; manifest and recent-sheet responses are added in this change. | Partially passed; generated client is not yet present. |
| PR description records contract deltas and endpoint gaps | Human/external review of the published OpenAPI document against `docs/color-matching-api-contract.md`. The document cannot be compared until `viamin/color_matching#110` is available to this checkout. | Not run — external evidence required. |

## Contract Gap Identified Before Implementation

The prose contract defines `GET /api/v1/test_sheets/:sheet_id/ranked_results`,
but `ColorMatchingLPSAppCore.APIClient` has no corresponding public operation.
The red test records this gap. Exact schema differences are intentionally not
guessed: they must be derived from the published OpenAPI document and included
in the implementation PR description.

## Test Execution Expectations

Run `swift test --disable-sandbox` from `iOS`. In this tests-only phase the
ranked-results test is expected to fail with its explicit migration message.
That is red-phase evidence, not a passing implementation verification. The
implementation run must replace it with assertions against the generated
operation and return the suite to green.
