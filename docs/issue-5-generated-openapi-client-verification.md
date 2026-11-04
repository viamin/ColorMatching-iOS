# Issue #5 verification plan

## Acceptance criteria

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Add the OpenAPI generator/runtime and vendor the published document | Inspect `Package.swift`, generated sources, and vendored spec after implementation. | Blocked: `viamin/color_matching#110` is not publicly accessible from this environment (GitHub API returned HTTP 404 on 2026-11-04). |
| Generate the manifest, recent sheets, capture, measurement, judgment, and ranked-results surfaces | Compile the generated client and run local-stub tests for every operation. | The first five existing transport surfaces have permanent local-stub coverage. Ranked results is an endpoint gap: the app has no call or response model today and the prose contract specifies no response schema. |
| Replace hand-written API models while retaining client-only models | Review the implementation diff and compile the app. | Deferred to implementation run; this tests-only run cannot modify source files. |
| Exercise generated client with local responses | `APIClientTests` uses `MockURLProtocol`; no live server is used. | Ready for the generated-client adapter to satisfy. |
| Record contract deltas in the PR | Compare the vendored published spec to `docs/color-matching-api-contract.md`; attach the diff to the PR description. | Blocked pending access to the published spec. |

## Known contract gaps to resolve when the spec is available

- The app does not request `GET /api/v1/test_sheets/:sheet_id/ranked_results`; its ranked pairs are calculated locally before measurement upload.
- The prose contract deliberately omits a concrete ranked-results response schema, so no typed response can be generated or tested from it.
- The manifest uses `sheet_id` in prose while the endpoint path variable is described as `:sheet_id`; the implementation currently calls the path argument `sheetCode`. Confirm the published parameter name and identifier semantics.

## Test inventory

- `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` exercises manifest, recent sheets, capture creation, measurement upload, and judgment upload through `URLProtocol` stubs.
- The implementation run must change this suite to construct and invoke the generated client (or a thin adapter around it) without using a live Phoenix server, and add ranked-results coverage once the published response schema exists.
