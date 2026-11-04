# Issue #5 verification plan

This is the red-phase test plan for replacing the hand-written iOS API layer
with a generated OpenAPI client. It records the smallest credible check for
each acceptance criterion before implementation begins.

| Criterion | Verification | Initial status |
| --- | --- | --- |
| Swift OpenAPI Generator and Runtime are package dependencies | `APIClientTests.testPackageDeclaresGeneratedOpenAPIClientDependencies` reads `iOS/Package.swift`. | Failing: neither dependency is declared. |
| The published document is vendored and includes every app surface | `APIClientTests.testVendoredOpenAPISpecDefinesEveryCompanionSurface` parses `iOS/OpenAPI/color-matching-openapi.json` and requires manifest, recent-sheets, capture creation, measurement upload, judgment upload, and ranked-results paths. | Failing: the vendor file is absent. |
| Manifest and recent sheet responses work through local stubs | `APIClientTests.testFetchRecentSheetsDecodesPublishedResponseFromLocalStub`; the existing capture, measurements, and judgment URL-protocol tests remain the focused local-stub coverage. | Passing on the current hand-written client; implementation must retain this behavior through generated types. |
| Ranked results are generated and wired into the app | Focused unit/service test to be added with the generated client implementation, using the ranked-results local stub. | Not yet runnable: the public API exposes no ranked-results client method. |
| The prose contract deltas and endpoint gaps are recorded in the PR | Human/external evidence: compare `docs/color-matching-api-contract.md` with `viamin/color_matching` issue #110 and its published OpenAPI source before opening the PR. | Recorded below; final PR author must include it in its description. |
| `swift test --disable-sandbox` is green | Run after implementation; this red-phase run permits expected assertion failures only. | Not run green in this phase. |

## Published-contract deltas observed

The server source for issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110)
publishes its document at `GET /api/v1/openapi.json`.

- Ranked results are no longer merely descriptive: the server publishes a
  `lps-ranked-results/v1` response with `sheet_id`, provenance, algorithm
  versions, aggregate score data, observations, and per-pair ranking fields.
- The capture request accepts both the prose contract's nested
  `metadata`/`quality` shape and a compatibility flat shape. The generated
  client should use the nested shape currently emitted by the iOS app.
- Measurement RGB fields accept an RGB object, an array, or a JSON-encoded
  string. The iOS client should preserve its current typed RGB-object payload.
- Measurement and judgment uploads return acknowledgement bodies (capture ID
  and counts), rather than relying on the prose document's implicit empty
  success response.
- No app-used endpoint is missing from the published API paths. The two
  additional `/api` endpoints in #110 (`illuminant_measurements` and
  `multi_image_mapping`) are out of this app's scope.
