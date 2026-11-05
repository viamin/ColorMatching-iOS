# OpenAPI client migration evidence for #5

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Evidence at this revision |
| --- | --- | --- |
| OpenAPI dependencies and a vendored/fetched document are added | Inspect `iOS/Package.swift` and the committed OpenAPI input; compile the generated target. | Not run in this test-writing phase. |
| The generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent local-stub tests assert method, path, authorization, payload, and decoded response for every surface. | `APIClientTests` now has local-stub coverage for all six routes. The ranked-results test is intentionally red until the generated adapter exposes that operation; it asserts only the published minimum response fields because the schema gap below remains. |
| Server API models are generated rather than hand-written | Compile the app after deleting/replacing server DTOs; inspect the generated module and the adapter boundary. | Not run in this test-writing phase. |
| Generated-client behavior is tested without a live server | Run `swift test --disable-sandbox`; all API tests use `MockURLProtocol`. | Not run: this environment has no `swift` executable. |
| Contract deltas and endpoint gaps are recorded | Compare the prose contract with the merged upstream OpenAPI source and the served-spec route. | Findings recorded below from upstream [PR #113](https://github.com/viamin/color_matching/pull/113), merged 2026-10-30. |

## Contract comparison for PR description

The upstream API now serves its generated document at `GET /api/v1/openapi.json` (implemented by [OpenApiController](https://github.com/viamin/color_matching/blob/094bd6d3443ddacbda7e63354299867eb5bdfa9f/lib/color_matching_web/controllers/open_api_controller.ex)). Its route list contains all six iOS paths, including ranked results.

The documented manifest schema is not yet sufficient for the iOS analysis flow. It requires only `schema_version`, `sheet_id`, and `capture_profile`, while the app consumes `sheet_version`, `manifest_url`, page geometry, registration markers, patches, and pairs. The local-stub manifest test deliberately retains those analysis fields so a generated-client migration cannot accidentally discard them. This must be resolved upstream by expanding the OpenAPI manifest schema (or by explicitly defining an adapter with a separately versioned analysis manifest); generated types alone cannot safely replace `SheetManifest` until then.

Ranked results has the same issue: its published schema requires only `schema_version` and `sheet_id`. The prose contract describes source colors, scores, labels, capture provenance, printer profile, and scoring-algorithm version but gives no concrete response schema. The endpoint exists, but a useful typed ranked-results client cannot be generated until those fields are specified.

Other deltas found in the published schema:

- Capture creation accepts either the nested `metadata` shape used by iOS or a legacy flat shape. The nested metadata schema requires device model, lens, image dimensions, app version, and timestamp; the prose presents more fields, while `quality` has no required fields in the spec.
- `iso` is an integer in the schema but a `Float?` in the hand-written iOS model.
- Measurement upload requires `normalized_linear_rgb_median`, whereas the iOS model currently makes it optional. The schema does not document the app's `scoring_algorithm_version` field or measurement `stats`; it does allow score, similarity, or distance for every pair score.
- Measurements and judgments return `200` JSON summaries (`capture_id` plus counts), rather than the old tests' `204` empty response assumption. The stub tests use those documented `200` responses.
- Recent-sheet `title` is required-but-nullable in the schema, consistent with the prose's nullable title.

## Follow-up implementation checklist

1. Vendor a reproducible JSON snapshot from `/api/v1/openapi.json` (or generate it from the upstream `ColorMatchingWeb.ApiSpec` at commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f`) and pin its upstream revision.
2. Add `swift-openapi-generator`, `swift-openapi-runtime`, and an HTTP transport; generate only the declared iOS operations.
3. Keep an application-facing adapter around generated operations so `MeasurementCore` remains client-side and the UI call sites stay stable.
4. Implement the ranked-results generated operation so `testFetchRankedResultsUsesAuthenticatedEndpointAndDecodesPublishedMinimumFields` compiles and passes. Extend it with result-item assertions once the server supplies its complete schema, then run `swift test --disable-sandbox` in an environment with Swift installed.
