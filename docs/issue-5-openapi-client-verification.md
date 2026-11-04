# Issue #5 verification plan

This PR is the tests-only, red-phase foundation for replacing the hand-written
`/api/v1` layer with an OpenAPI-generated Swift client.

## Acceptance criteria

| Criterion | Smallest credible verification | Location | Current result |
| --- | --- | --- | --- |
| Generated client dependencies and vendored specification | Focused package/spec gate asserts the generator/runtime dependencies and every consumed operation in the vendored JSON document. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testOpenAPIClientBuildConfigurationVendorsAllConsumedOperations`) | Red: neither dependency nor vendored document exists yet. |
| Manifest and recent sheet calls decode local server responses | Permanent focused client test using `URLProtocol` stubs. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testFetchesManifestAndRecentSheetsFromPublishedContractStubs`) | Expected green before and after migration. |
| Capture creation, measurement upload, and judgment upload work with published response statuses | Permanent focused client test using only local `URLProtocol` stubs. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testCaptureUploadEndpointsAcceptPublishedSuccessAcknowledgements`) | Expected green before and after migration. |
| Ranked results are available through generated types | Inspectable vendored-spec operation gate now; the implementation run must add a typed local-stub response test once generated operation naming is known. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Red until the spec is vendored; not settled by this red-phase run. |
| Prose-vs-published-contract deltas are recorded in the PR | Human/external evidence: compare the vendored `openapi.json` against the upstream `GET /api/v1/openapi.json` contract. | This document and final PR description | Recorded below; implementation must reconfirm against its pinned vendored revision. |

## Published-contract deltas discovered

Source inspected: `viamin/color_matching` issue #110 and its merged `main`
implementation, which serves `GET /api/v1/openapi.json`.

- The actual spec includes `GET /api/v1/test_sheets/{sheet_id}/ranked_results`.
  The prose contract names it but leaves its response unshaped; the published
  API declares the `lps-ranked-results/v1` envelope.
- Measurement and judgment uploads return `200` JSON acknowledgement bodies
  (`capture_id` plus submitted-row counts). The prose contract says `204` with
  no response body.
- Capture creation accepts either the original nested `metadata` payload or a
  legacy flat payload. The prose contract only documents the nested form.
- The published measurement request requires each measurement's patch ID and
  two RGB values. Pair scores require `pair_id`, `algorithm_version`, and one
  of `score`, `similarity`, or `distance`; it does not specify the prose
  contract's top-level `scoring_algorithm_version` or measurement statistics.
- The published manifest schema validates only its compatibility-critical
  envelope fields, while the server currently renders additional page,
  geometry, printer, and capture-profile data used by the app. The generated
  client must preserve those rendered fields rather than narrowing the app's
  usable manifest model.

## Endpoint gap

No consumed endpoint is absent from the upstream published route list. The
app has no ranked-results client call today, so the implementation must add
that typed operation without changing capture or scoring behavior.
