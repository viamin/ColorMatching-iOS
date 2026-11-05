# Issue #5: generated OpenAPI Swift client

## Criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Add the generator/runtime and vendor the API document | `OpenAPIAdoptionTests` reads `Package.swift` and the vendored document, then verifies all six paths | Red: dependencies and document are not present yet |
| Generate all app-used surfaces | Local `URLProtocol` stubs exercise manifest, recent sheets, capture creation, measurement upload, and judgment upload; `OpenAPIAdoptionTests` requires the ranked-results wrapper | Capture/upload stubs pass; ranked-results wrapper is red |
| Replace hand-written API models | Compile the app against generated component types during the implementation PR | Not runnable until the generated target exists |
| No-live-server generated-client tests | Permanent `APIClientTests` uses only `MockURLProtocol` fixtures | Passing for the existing wrapper; implementation must retain this property |
| `swift test --disable-sandbox` | Run after implementation | Not expected to be green in this red-phase PR |

The capture/upload sequence is an important recurring user flow, so its local-stub tests are permanent rather than ephemeral. No browser or live-server evidence can establish the external OpenAPI publication; the upstream issue and source are the inspectable external evidence.

## Published-spec delta and endpoint gaps

Evidence inspected: `viamin/color_matching#113`, which closed `viamin/color_matching#110`, and its current `ColorMatchingWeb.ApiSchemas` / controller definitions. The server exposes its document at `GET /api/v1/openapi.json`.

- The prose manifest contract describes page geometry, registration markers, printer/capture profiles, patches, and pairs. The published `Manifest` schema specifies only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. A generated model from the published schema cannot replace the app's `SheetManifest` without this schema being expanded.
- The prose ranked-results endpoint has no response example. The published `RankedResults` schema likewise specifies only `schema_version` and `sheet_id`; it does not define the ranked items, source colors, scores, labels, capture provenance, or printer/scoring metadata promised by the prose contract. This is the blocking endpoint gap recorded by the red test.
- Capture creation accepts the prose nested `metadata`/`quality` form, but the published schema also accepts an undocumented legacy flattened form. The legacy spelling is `exposure_duration`, while nested metadata uses the prose spelling `exposure_duration_seconds`.
- The prose measurement payload includes `scoring_algorithm_version` and per-measurement `stats`. The published schema does not model either; it requires normalized RGB, supports RGB arrays, objects, or JSON strings, and allows score/similarity/distance alternatives. The current app therefore sends fields that generated request types would not represent.
- The prose says measurement and judgment uploads return no body. The published schema and controller return counts plus `capture_id` with HTTP 200. The implementation should decode and intentionally ignore or surface these generated responses.

## Implementation handoff

Fetch the live document into `iOS/OpenAPI/color_matching.json`, configure the Swift OpenAPI generator plugin and runtime, generate the client into a dedicated target, and adapt only at the boundary between generated DTOs and the existing client-side measurement/domain models. Expand the upstream manifest, ranked-results, and measurement schemas before claiming full replacement of hand-written API models.
