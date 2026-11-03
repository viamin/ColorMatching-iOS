# OpenAPI Client Migration: #5

This is the tests-only plan for replacing the iOS app's hand-written `/api/v1`
client. It is deliberately limited to the surfaces the app already uses; it
does not alter capture or scoring behavior.

## Criterion-level verification plan

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and obtain the published OpenAPI document | Inspect `iOS/Package.swift`, the vendored/fetched spec, and generator-plugin output in the implementation PR | Blocked: viamin/color_matching#110 is closed and specifies `GET /api/v1/openapi.json`, but this checkout contains neither the artifact nor a deployment base URL from which to fetch it. |
| Generate the manifest/recent/capture/measurement/judgment/ranked-results operations | Compile the generated client and use each typed operation from the app adapter | Red test planned at `APIClientTests.testGeneratedClientWillDecodeRankedResultsFromLocalStub`; all other operation payload fixtures are in the same file. |
| Replace hand-written API models while retaining client-only models | Compile-time use of generated schemas in `ColorMatchingLPSAppCore`; inspect the removed duplicate wire models | Not runnable in this tests-only phase. |
| Exercise generated client against local stubbed responses | Permanent `URLProtocol` tests: no live server dependency | `APIClientTests` contains local stubs for manifest, recent sheets, capture, measurements, and judgments. Ranked results remains red until the generated endpoint exists. |
| Record prose-contract versus published-spec deltas and endpoint gaps | Human/external comparison against the exact OpenAPI artifact committed by color_matching#110; include a PR-body table with source links | Not run: the authoritative OpenAPI artifact is unavailable locally. Do not infer deltas from the prose contract. |

## Required implementation-PR description section

Copy the following table into the implementation PR and replace each `TBD`
with an exact observed delta, or `None` with a spec reference. This is an
external evidence requirement and cannot be satisfied by the Swift suite.

| Surface | Prose contract | Published OpenAPI | Delta / endpoint gap |
| --- | --- | --- | --- |
| Manifest and recent sheets | `GET /test_sheets/:id/manifest`, `GET /test_sheets/recent` | TBD | TBD |
| Create capture | `POST /test_sheets/:id/captures` | TBD | TBD |
| Measurements | `POST /captures/:id/measurements` | TBD | TBD |
| Judgments | `POST /captures/:id/judgments` | TBD | TBD |
| Ranked results | `GET /test_sheets/:id/ranked_results`; response intentionally unspecified | TBD | TBD |
