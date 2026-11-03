# Issue #5 OpenAPI client verification plan

This is the test-writing evidence for replacing the handwritten `/api/v1`
client. The implementation phase must retain the permanent tests below and
replace the final red test with direct generated-client stub coverage.

| Criterion | Smallest credible verification | Current evidence/status |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, vendor or fetch the upstream document, and generate the six required surfaces | Focused configuration test checks the package for both dependencies, a checked-in OpenAPI document, and the ranked-results operation. The implementation must additionally compile generated operation calls. | `APIClientTests.testGeneratedClientConfigurationIncludesThePublishedSpecAndRankedResultsSurface` — expected **failed** red-phase test; no generated client exists yet. |
| Replace handwritten API transport models while retaining client-side analysis models | Permanent local-stub tests exercise the app-facing manifest/recent-sheet, capture, measurement, and judgment boundary. The generated client’s concrete types must power these calls in implementation. | Existing upload tests plus `APIClientTests.testFetchManifestAndRecentSheetsDecodeLocalStubResponses` — **passed** against the current handwritten adapter, but not yet evidence that generated types are wired in. |
| Generated-client tests use local stubs, not a live service | `URLProtocol` fixture responses in the permanent `ColorMatchingLPSAppTests` target. Add a ranked-results response and assert generated operation output once that generated operation is available. | **partially covered**: five of six required surfaces are stubbed; ranked results is a current app/API-layer gap. |
| PR description states prose-contract deltas and endpoint gaps | Inspectable external evidence from the merged upstream contract, followed by a PR-body review once implementation is opened. | **not run**: implementation PR does not exist in this tests-only phase. |

## Upstream contract evidence and deltas

The dependency is merged as `viamin/color_matching#113` (closing #110), whose
router publishes `/api/v1/openapi.json` and exposes all six routes relevant to
this issue, including `GET /api/v1/test_sheets/{sheet_id}/ranked_results`.

Compared with `docs/color-matching-api-contract.md`, the generated OpenAPI
source differs materially in these areas:

- The server advertises `RankedResults` with `schema_version`
  `lps-ranked-results/v1`; the prose contract described the endpoint but did
  not define its response schema.
- Capture creation accepts both the nested `metadata`/`quality` request and a
  legacy flat request. The prose contract documented only the nested form.
- The measurement schema permits RGB values as arrays, `{r,g,b}` objects, or
  JSON-encoded strings, and accepts score, similarity, or distance fields.
  The prose contract documented only object RGB and distance plus similarity.
- The upstream manifest schema currently declares only its compatibility
  fields (`schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`) as required in the OpenAPI
  definition. The companion currently needs the richer geometry fields from
  the prose contract to analyze a sheet. The implementation must preserve that
  requirement in the app adapter or get the provider spec tightened.

The endpoint gap in the companion is ranked results: upstream publishes it,
but `APIClient` has no corresponding operation or caller. This implementation
must generate the operation and cover a representative local stub response;
product wiring remains out of scope unless the current capture flow consumes
ranked results.

Source inspected 2026-11-03: upstream issue #110, merged PR #113 at
`094bd6d3443ddacbda7e63354299867eb5bdfa9f`, and its
`ColorMatchingWeb.ApiSchemas` definitions.
