# Issue #5 OpenAPI client verification plan

## Acceptance criteria

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Package includes the OpenAPI generator/runtime and generates the client from the published document | `GeneratedOpenAPIClientAcceptanceTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` inspects the package definition; the implementation PR must also compile it with `swift test --disable-sandbox`. | Red: dependencies/configuration have not landed. |
| The manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results surfaces are generated/wired | `GeneratedOpenAPIClientAcceptanceTests.testClientIncludesEveryCompanionAPISurface` guards all six routes. | Red: ranked results is not wired. |
| Hand-written server contract models are removed while client-only measurement models remain | `GeneratedOpenAPIClientAcceptanceTests.testClientNoLongerDefinesServerContractModelsByHand`. | Red: the hand-written API models remain. |
| Generated client works against local responses, without a live API | `APIClientTests` uses `MockURLProtocol` for manifest, recent sheets, capture creation, measurement upload, and judgment upload. The implementation PR must retain those stubs while routing through generated operations and add a ranked-results stub. | Existing five stubs pass once Swift is available; ranked-results stub is pending implementation. |

## Published-spec deltas and gaps

Evidence inspected: `viamin/color_matching` issue #110 and its merged `ColorMatchingWeb.ApiSpec` / `ColorMatchingWeb.ApiSchemas` implementation, which serves `GET /api/v1/openapi.json`.

- The spec's `Manifest` schema requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose contract requires many more manifest fields that the iOS app consumes. The generated client therefore cannot replace the app's manifest decoding safely until the server spec models those fields.
- The spec's `RankedResults` schema requires only `schema_version` and `sheet_id`; the prose contract promises source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version. This endpoint is an implementation blocker: no typed result model can support the current UI from the published schema.
- Capture creation accepts either the prose-compatible nested `metadata` form or a legacy flattened form. The OpenAPI schema does not require `quality` for the nested form, unlike the iOS workflow.
- Measurement upload differs materially: the spec permits RGB arrays, objects, or encoded strings; makes `normalized_linear_rgb_median` required; does not specify the prose `stats` or top-level `scoring_algorithm_version`; and returns a JSON count summary rather than the existing client's assumed empty `204` response.
- Judgment upload returns a JSON count summary according to the spec; the current client assumes an empty `204` response.

The implementation PR should vendor the exact served document (with a revision/checksum), configure `swift-openapi-generator`, and either obtain the two missing response schemas from `color_matching` or keep the affected flow blocked rather than invent generated types.
