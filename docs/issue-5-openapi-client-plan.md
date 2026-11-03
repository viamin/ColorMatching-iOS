# Issue #5: generated OpenAPI client verification plan

## Criterion map

| Criterion | Smallest credible verification | Current red-phase evidence |
| --- | --- | --- |
| Package includes `swift-openapi-generator` and `swift-openapi-runtime`; a vendored spec covers the six used operations | Focused unit test that reads `Package.swift` and the vendored OpenAPI document | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientAdoptionTests.swift` (intentionally red until the generator, runtime, and document are added) |
| Generated client is used for manifest, recent sheets, capture creation, measurements, judgments, and ranked results | Focused unit/service tests with a URL-protocol stub; no network server | Existing request tests plus `APIClientTests.testFetchesManifestAndRecentSheetsFromStubbedResponses`; implementation must add a ranked-results stub case and migrate the existing write-operation cases to generated types |
| Client-side analysis models remain separate from generated wire models | Compile-time mapping coverage in `ColorMatchingLPSAppCore` | Not runnable in this tests-only phase; implementation must add mapper tests for manifest and capture payloads |
| Swift tests do not call a live service | Local `URLProtocol` stubs assert request paths, headers, and JSON body | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| PR records prose-contract deltas and endpoint gaps | Inspectable external evidence from `viamin/color_matching#110` and the merged upstream source | Contract delta record below |

## Published-spec evidence and contract deltas

The upstream issue is closed: [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110). Its merged implementation serves the document dynamically at `GET /api/v1/openapi.json`; it does not commit a static OpenAPI file. The implementation run should fetch that endpoint from the configured provider environment and vendor its exact response at `iOS/Sources/ColorMatchingLPSAppCore/openapi.yaml`, updating it only through the documented regeneration workflow.

Compared with `docs/color-matching-api-contract.md`, the published upstream schemas have these material deltas:

- `CaptureRequest` allows either a legacy flat payload or `metadata`; nested `quality` is not required. The prose contract requires `metadata` and `quality`. The generated adapter must deliberately retain the existing nested payload, rather than silently choosing the legacy shape.
- The published `CaptureMetadata` requires `image_width` and `image_height`; the prose treats them as optional. The app must supply valid image dimensions before creating a capture.
- The published measurement schema requires each measurement's `normalized_linear_rgb_median`, permits RGB arrays, objects, or JSON strings, and does not define the prose contract's `scoring_algorithm_version` or per-measurement `stats` fields. The generated request mapping must emit only the published wire fields.
- The published measurement and judgment endpoints respond with JSON counts and `capture_id` using HTTP 200, while the current client assumes an empty successful response. Tests must decode those responses.
- The published `RankedResults` schema only requires `schema_version` and `sheet_id`, although the server renderer provides a richer results body. This is an endpoint-schema gap: generated types cannot safely expose rankings until upstream specifies the result item, score, printer-profile, and provenance fields.
- The published manifest schema only requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`, while the app needs geometry, patches, and pairs for analysis. This is an endpoint-schema gap: upstream must make those consumed fields required before the generated type can replace the app's manifest wire model safely.
- Recent-sheet `manifest_url` is a string in the published schema (not explicitly a URI format); the app must continue validating it when converting to `URL`.

## PR description draft

> Replaces the hand-written transport contract with a Swift OpenAPI-generated client sourced from `GET /api/v1/openapi.json`. Local URL-protocol tests cover the app's manifest, recent-sheet, capture, upload, and ranked-result operations without a live Phoenix server.
>
> Contract deltas: the provider accepts legacy flat capture payloads as well as nested metadata; image dimensions are required; the measurement request omits the old stats/scoring-version fields and requires normalized RGB; upload responses are JSON count objects rather than empty success bodies. The provider document currently under-specifies manifest geometry and ranked-result item details, so the generated client maps only the guaranteed contract and keeps analysis models client-side pending upstream schema expansion.
>
> ## Dependencies
>
> Depends on viamin/color_matching#110
