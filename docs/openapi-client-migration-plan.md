# OpenAPI client migration plan

This document is the criterion-level plan and contract-delta record for #5.

## Verification plan

| Criterion | Smallest credible verification | Current status |
| --- | --- | --- |
| Add the generator/runtime and vendor the upstream document | `OpenAPIAdoptionTests.testPackageAndVendoredSpecCoverTheAppAPI` asserts both dependencies and the six required paths in `iOS/OpenAPI/color-matching.json`. | Red: neither dependencies nor document exist. |
| Generate the six application surfaces | Local-stub API tests cover manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results through the generated transport. | Red: ranked-results access and generated transport do not exist. |
| Remove server-owned hand-written models without changing client-only models | Compilation of the application against generated operation/model types, plus the local-stub tests above. | Red: `APIClient.swift` still owns server payload models. |
| No live server in CI | The local `URLProtocol` stubs in `APIClientTests` provide all request/response data. | Partially covered today; the generated client and ranked-results case remain red. |
| Capture contract deltas in the PR | Inspectable comparison below, based on `viamin/color_matching` main after #110/#113; a reviewer must confirm the final PR description carries it. | External evidence required at PR creation. |

The important recurring flow is capture upload: create capture, upload measurements, upload judgments, and read ranked results. It needs permanent local-stub coverage because this app must remain independent of a live Phoenix deployment in CI. The manifest and recent-sheet read tests added in this change use the same local-stub boundary.

## Published-spec comparison

Upstream #110 was merged as `viamin/color_matching#113`. Its router publishes the document at `GET /api/v1/openapi.json` and includes all six paths required here.

- The prose contract says the capture request has nested `metadata` and `quality` objects. The published server schema accepts two capture payload variants (`CaptureRequest.anyOf`); generated request construction must follow the selected generated variant rather than preserve a local Codable shape.
- The prose contract leaves upload success bodies unspecified. The published API returns JSON summaries for measurement and judgment uploads (`capture_id` plus accepted counts), so generated calls must handle their response bodies even when the app does not presently display them.
- The prose contract gives only a narrative for ranked results. The published schema supplies a concrete `lps-ranked-results/v1` response with capture count/timestamps, printer profile, algorithm versions, ordered results, score aggregates, and judgment observation fields.
- The published API documents authentication and 401/404/422 responses. The current client collapses all non-2xx responses into `APIError.badStatus`; generated error typing will make those distinct server cases visible.

## Endpoint gap

There is no endpoint gap: `GET /api/v1/test_sheets/{sheet_id}/ranked_results` is present upstream but absent from the current iOS `APIClient`. The implementation must add it without changing capture or scoring behavior.
