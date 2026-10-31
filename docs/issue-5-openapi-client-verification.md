# Issue #5: generated OpenAPI client verification

## Acceptance-criterion map

| Criterion | Smallest credible verification | Current red-phase evidence |
| --- | --- | --- |
| Add the generator/runtime packages and vendor the upstream document | Focused package/resource test, plus inspect the vendored document's source revision. | `GeneratedOpenAPIClientAdoptionTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` and `testPublishedSpecificationIsVendoredForReproducibleGeneration` intentionally fail until implementation. The upstream document must be fetched from `GET /api/v1/openapi.json` from `viamin/color_matching` at merged PR #113's API revision, then committed as `iOS/OpenAPI/openapi.json`. |
| Generate and use the manifest, recent sheets, capture, measurement, judgment, and ranked-results surfaces | Permanent local-stub system test that calls each adapter method through the generated client. | Existing stubs now cover manifest/recent, capture, measurement, and judgment in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. Add ranked-results coverage while replacing the client; the current hand-written client has no ranked-results method. |
| Replace server models with generated types while preserving client-only models | Compiler verification from app and test targets, followed by focused code review that confirms MeasurementCore analysis types remain client-owned. | Not run in this test-writing phase; depends on generated sources. |
| No live server in CI | Permanent `URLProtocol`-backed tests; every response is supplied by `MockURLProtocol`. | `APIClientTests` uses no network listener or live service. |
| PR records prose-contract versus published-spec deltas and endpoint gaps | Inspectable PR/body evidence, using upstream revision `viamin/color_matching#113` as the external source. | The implementation PR must carry the delta list below. |

## Published-spec deltas found before implementation

The upstream spec is generated at runtime by `ColorMatchingWeb.ApiSpec` and served at `/api/v1/openapi.json`; upstream PR [#113](https://github.com/viamin/color_matching/pull/113) merged it on 2026-10-30.

- The prose manifest describes page geometry, registration markers, printer/capture profiles, patches, and pairs. The published `Manifest` schema guarantees only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. A generated model cannot safely replace the app's complete `SheetManifest` until the server spec declares the remaining fields.
- The prose ranked-results response promises rankings, source colors, scores, labels, capture provenance, printer profile, and scoring version. The published schema guarantees only `schema_version` and `sheet_id`; this is an endpoint-schema gap for typed ranked results.
- Capture creation supports the prose nested `metadata`/`quality` body, but the published schema also permits a legacy flat request. In the nested path, quality fields are not required by the published schema.
- The published measurement schema requires `normalized_linear_rgb_median`, supports multiple RGB encodings, and does not declare the prose `scoring_algorithm_version` or per-measurement `stats` fields. The app currently sends all of these, so generation must preserve the server-accepted payload shape or the upstream spec must be expanded.
- The prose calls successful measurement and judgment uploads `204 No Content`; the published spec defines `200` JSON responses containing capture and count fields. The stub tests use the published `200` bodies.
- The published recent-sheet `title` is required-but-nullable, while the prose merely says it may be null. The current optional Swift representation is compatible.

## Red-phase status

Run `swift test --disable-sandbox` from `iOS/`. The two adoption tests are expected to fail before implementation because `Package.swift` has no OpenAPI dependencies and `iOS/OpenAPI/openapi.json` has not yet been vendored. The local-stub API behavior tests should remain green.
