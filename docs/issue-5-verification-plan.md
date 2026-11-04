# Issue #5 verification plan

This test-writing PR establishes the checks the implementation PR must satisfy.

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| OpenAPI generator and runtime are wired into the package | `APIClientTests.testPackageDeclaresGeneratedClientAndExposesRankedResults` asserts the package dependencies and the ranked-results client surface. | Red: neither dependency nor surface exists. |
| All app-used API surfaces use typed generated requests/responses | Permanent local-stub integration tests in `APIClientTests` exercise manifest, recent sheets, capture creation, measurement upload, and judgment upload. The implementation extends the same suite with ranked-results decoding. | Existing five surfaces covered; ranked results is red. |
| No live server is required | `MockURLProtocol` supplies every response in the API-client test suite. | Green. |
| `swift test --disable-sandbox` succeeds after wiring | Run the package suite in the implementation PR after the red generated-client guard is satisfied. | Not run in this tests-only PR because the guard intentionally fails. |
| PR records prose/spec deltas and endpoint gaps | Inspect the upstream OpenAPI source served by `viamin/color_matching#110` and its controller/rendering code. | See deltas below. |

## Published API deltas found

- `POST /captures/{capture_id}/measurements` returns `200` with `capture_id`, `measurement_count`, and `pair_score_count`; the prose contract says `204` with no body.
- `POST /captures/{capture_id}/judgments` returns `200` with `capture_id` and `judgment_count`; the prose contract says `204` with no body.
- `GET /test_sheets/{sheet_id}/ranked_results` is published with the `lps-ranked-results/v1` response, but the iOS client has no method for it.
- The published OpenAPI schema currently describes only the required manifest compatibility fields, whereas the renderer returns the richer geometry and profile shape used by the app. Generation must preserve access to those response fields or the server spec needs to become more complete.

Sources inspected 2026-11-04: [upstream issue #110](https://github.com/viamin/color_matching/issues/110), `ColorMatchingWeb.ApiSchemas`, `TestSheetController`, `CaptureController`, and `TestSheetJSON` on upstream `main`.
