# OpenAPI client migration plan

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Package has the OpenAPI generator/runtime and a fetched or vendored source contract | `APIClientTests.testOpenAPIGenerationInputsCoverEveryUsedOperation` checks the package manifest and vendored `openapi.yaml` | Red: implementation pending |
| Generated client covers manifest, recent sheets, capture creation, measurement and judgment uploads, and ranked results | The same focused test checks each required OpenAPI path in the vendored source contract | Red: implementation pending |
| App transport continues to handle server data correctly without a live server | `APIClientTests` uses `MockURLProtocol` local stubs for manifest, recent sheets, capture creation, measurement upload, and judgment upload | Green now; rerun after generated-client wiring |
| Hand-written server models are replaced while client-side analysis models remain | Human review of `APIClient.swift` and generated source diff | Not automatable in this red phase |
| Contract deltas and endpoint gaps are recorded | This document, based on upstream `viamin/color_matching` main at the dependency closure | Recorded below |
| `swift test --disable-sandbox` is green with generated types | Run the focused suite and full package suite after implementation | Not run: generated inputs are intentionally absent in this phase |

## Required generation layout

The implementation should vendor the document obtained from the upstream runtime endpoint at `GET /api/v1/openapi.json` as `iOS/Sources/ColorMatchingLPSAppCore/openapi.yaml` (JSON is valid YAML). Configure the `OpenAPIGenerator` build-tool plugin on `ColorMatchingLPSAppCore`, with `swift-openapi-runtime` available to that target. The generated source must expose these operations through the app's API seam:

- `GET /api/v1/test_sheets/recent`
- `GET /api/v1/test_sheets/{sheet_id}/manifest`
- `POST /api/v1/test_sheets/{sheet_id}/captures`
- `POST /api/v1/captures/{capture_id}/measurements`
- `POST /api/v1/captures/{capture_id}/judgments`
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results`

## Contract deltas found

The upstream published contract is broader and stricter in several material ways than `docs/color-matching-api-contract.md`:

- The authoritative spec is served at `/api/v1/openapi.json`; no static OpenAPI file is committed upstream.
- Sheet path IDs are lookup codes (for example `SHEET-123`), rather than an implied database-style `sheet_123` identifier.
- Capture metadata requires `device_model`, `lens`, `image_width`, `image_height`, `app_version`, and `timestamp`; the prose contract did not state required fields.
- The capture endpoint accepts both the nested `metadata` shape used by iOS and a legacy flat request shape. The generated client should use the nested form.
- Measurement uploads return a JSON success body (`capture_id`, `measurement_count`, `pair_score_count`) rather than the prose contract's implied empty `204` response. The published request schema also does not declare the existing `scoring_algorithm_version` or `stats` fields, even though the server accepts compatibility payloads; this is a generated-client compatibility gap that needs resolution before removing the adapter.
- Pair scores must contain `pair_id`, `algorithm_version`, and one of `score`, `similarity`, or `distance`; the existing iOS payload's `similarity` is compatible.
- Ranked results are now specified as `lps-ranked-results/v1`, but the current iOS API layer has no ranked-results method or model.
- The manifest and ranked-results schemas describe only a subset of their rendered response fields. Generated response types may therefore omit fields the app's analysis currently needs (`page`, patches, pairs, and registration markers) unless the upstream spec is expanded. This blocks a direct replacement of `SheetManifest` with a generated type.

These endpoint/schema gaps should be resolved with `viamin/color_matching` before the generated types become the app's manifest and measurement models; client-side measurement and image-analysis models remain out of scope for generation.
