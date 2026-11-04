---
module: ios-api
tags: [openapi, swift, testing, issue-5]
problem_type: test-plan
---

# Issue #5 verification plan and PR notes

This is the red-phase test commit for replacing the hand-written iOS API
models with generated OpenAPI types. The provider dependency,
`viamin/color_matching#110`, is closed. Its router serves the document at
`GET /api/v1/openapi.json` and defines all six paths below. The public app
host was not resolvable from this run, so the published provider source is the
inspectable external evidence.

## Acceptance-criterion map

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Swift OpenAPI generator/runtime and a vendored spec are added | `OpenAPISpecContractTests.testVendoredSpecDeclaresEveryAppOperation` parses the vendored JSON and checks every used operation. | Expected red: the document is not yet vendored. |
| Generated client covers manifest, recent sheets, capture creation, measurement and judgment upload, and ranked results | The same focused contract test requires all six operations; implementation must compile the generated target against it. | Expected red: no document or generated target yet; ranked results has no manual client surface. |
| Existing app calls decode/encode through the generated client | `APIClientTests` uses `MockURLProtocol` local stubs for manifest, recent sheets, capture creation, measurement upload, and judgment upload. The implementation run must retain these as generated-client boundary tests and add a ranked-results stub once its generated operation is wired. | Existing five interactions pass; ranked-results wiring is red/unimplemented. |
| Tests use no live server | The tests install `MockURLProtocol` on an ephemeral `URLSession`; they make no network calls. | Passes for the five existing interactions. |
| PR description records contract deltas and endpoint gaps | This document supplies the PR-body evidence below; a reviewer must compare the downloaded generated document at the implementation head. | External/human verification required. |

## PR description notes

### Contract deltas found

- The prose contract describes successful measurement and judgment uploads as
  bodyless responses. The provider controller returns JSON acknowledgements
  containing `capture_id` plus `measurement_count`/`pair_score_count` or
  `judgment_count`.
- The prose contract leaves ranked-results response fields unspecified. The
  provider now publishes a typed ranked-results operation, but the existing
  iOS `APIClient` has no corresponding method.
- The provider documents typed unauthorized, not-found, and validation-error
  responses for the app-used endpoints; the hand-written client reduces every
  non-2xx response to `APIError.badStatus`.
- The provider uses `sheet_id` as a route parameter name but resolves it as a
  lookup code. The iOS app's `sheetCode` wording remains a client-side concern.

### Endpoint gaps

All five currently-used manual operations exist in the provider router. The
remaining app-required generated surface is
`GET /api/v1/test_sheets/{sheet_id}/ranked_results`; it is present in the
provider contract but is not called by the current manual iOS client. No new
server endpoint is required.

## Provider evidence

- `https://github.com/viamin/color_matching/issues/110`
- `https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex`
- `https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/capture_controller.ex`
- `https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/test_sheet_controller.ex`
