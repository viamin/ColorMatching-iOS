# PR plan: generated OpenAPI Swift client (#5)

## Criterion-to-verification map

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Add the generator/runtime and vendor the published document | `OpenAPIClientGenerationTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` and `testVendoredOpenAPIDocumentCoversEveryAppSurface` inspect the package manifest and pinned document | Red: neither artifact exists yet |
| Generate only the six used API surfaces | `testVendoredOpenAPIDocumentCoversEveryAppSurface` asserts each required published path; the implementation PR must compile generated code from that document | Red: document is not yet vendored |
| Replace hand-written server API models | Implementation review plus compiler evidence: remove transport-owned `Codable` models while retaining `MeasurementCore` domain models | Not run: requires implementation |
| Test generated client without a live server | Permanent `APIClientTests` uses `MockURLProtocol`; manifest and recent-sheet response tests were added here, and existing create/upload tests cover capture, measurement, and judgment calls. The implementation PR must add ranked-results coverage against the same stub mechanism. | Partial: ranked-results API does not exist in the app yet |
| Document contract differences and endpoint gaps | Inspect upstream `color_matching` commit `47057afd58f7d46b4d4b740ca7d2d08947774471`, which serves `/api/v1/openapi.json`, against `docs/color-matching-api-contract.md` | Recorded below |

## Published-spec deltas discovered

The upstream source at the inspected commit publishes the desired paths, including ranked results, through `ColorMatchingWeb.OpenApiController` at `/api/v1/openapi.json`.

- `Manifest` declares only `schema_version`, `sheet_id`, and `capture_profile` (and only `scoring_algorithm_version` inside that profile) as required. The prose contract and iOS `SheetManifest` consume full geometry, patches, pairs, `manifest_url`, and `sheet_version`. The generated model will therefore expose many fields as optional unless the server schema is tightened.
- The ranked-results schema declares only `schema_version` and `sheet_id`; the rendered response also contains printer profile, capture dates/counts, algorithm versions, and the ranked result records. Those fields need specification before the iOS client can safely use typed ranked results.
- Capture creation allows both the old flat shape and the nested `metadata` shape. The nested `quality` fields are not required, while the prose contract requires the nested metadata and quality payload. The app currently emits the nested form.
- Capture metadata declares `iso` as an integer, while the app's hand-written model uses `Float`.
- Measurement upload no longer documents `scoring_algorithm_version` or the client-sent `stats` object. It requires `normalized_linear_rgb_median`, whereas the prose contract makes it look like measurement data may be sufficient without an explicit required list.
- Measurement and judgment uploads return `200` JSON count responses in the published API; the prose contract leaves their response bodies unspecified and the current app accepts any successful response.
- The prose contract's capture-rejection and judgment value sets are not represented as enums in the published schemas, so generated types cannot protect those values from drift.

## Endpoint gap

The published OpenAPI path for `GET /api/v1/test_sheets/{sheet_id}/ranked_results` exists, but the current iOS `APIClient` has no corresponding method or result model. The implementation must wire that generated operation into the app-facing client and add a local-stub response test.

## Implementation handoff

Pin the response body from `/api/v1/openapi.json` in `iOS/OpenAPI/color_matching.openapi.json`, add the generator plugin and runtime dependencies, generate only the listed paths/types, and then update the local-stub tests to call the generated operation APIs directly. Coordinate the schema gaps above with `viamin/color_matching` before replacing any client behavior that relies on fields not promised by its published document.
