# Issue #5 OpenAPI client verification plan

This is the test-writing evidence for the generated-client migration. The implementation run must retain the local-stub tests and make the package-configuration test pass; it must not call a live server in CI.

| Criterion | Smallest credible verification | Current evidence / state |
| --- | --- | --- |
| Package uses `swift-openapi-generator` and `swift-openapi-runtime`, with a vendored or fetched spec | Focused Swift configuration test plus review of the spec source and generated target | `APIClientTests.testPackageDeclaresTheGeneratedOpenAPIClient` is intentionally red until the package and generation target are added. The published source serves the document at `GET /api/v1/openapi.json`. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent Swift local-stub tests exercise each generated operation and its request/response types | Existing tests cover create/upload operations; the implementation run must migrate them to generated types and add ranked-results coverage. `testFetchesManifestAndRecentSheetsFromLocalStubs` supplies manifest/recent coverage. |
| Hand-written API models are replaced, leaving client-only models | Human code review of generated target and app adapter | Not automatable by a broad suite; inspect the PR diff to confirm types from `APIClient.swift` are removed or narrowed to client-only adapters. |
| No live server in CI | Permanent local `URLProtocol` stubs in the Swift tests | `APIClientTests` uses `MockURLProtocol`; no network host is contacted. |
| Prose contract deltas appear in the PR description | Human/external evidence from `viamin/color_matching` PR #113 and its served OpenAPI document | Pending implementation PR description. The server source is inspectable in `ColorMatchingWeb.ApiSpec`, `OpenApiController`, and API schema/controller modules. |

## Contract deltas found before generation

- The published contract explicitly defines `GET /api/v1/test_sheets/:sheet_id/ranked_results` as a `RankedResults` response requiring `schema_version: "lps-ranked-results/v1"` and `sheet_id`; the prose contract only described the result content informally. The app currently has no ranked-results client call, so implementation must add generated coverage without changing capture/scoring behavior.
- Measurement and judgment uploads have documented `200` JSON responses containing `capture_id` and uploaded-row counts. The prose contract did not specify response bodies and the current client discards them.
- The generated contract allows three RGB input representations for measurement uploads (array, `{r,g,b}`, or JSON string) and allows `score`, `similarity`, or `distance` in a pair score. The current app sends the object/similarity-and-distance compatibility form.
- Capture creation allows both the nested `metadata` request used by the app and a legacy flat request shape. The prose contract documents only the nested shape.
- The OpenAPI endpoint itself is unauthenticated, while the six sheet/capture endpoints declare bearer authentication. The prose contract describes development-mode authentication as optional but cannot encode that environment-specific exception.
