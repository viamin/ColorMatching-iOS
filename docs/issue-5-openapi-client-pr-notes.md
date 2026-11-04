# OpenAPI Swift client: PR evidence for #5

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Swift OpenAPI generator/runtime dependencies and a vendored upstream document | `APIClientTests.testPackageDeclaresGeneratedClientAndVendoredSpecification` checks the package declarations and intended checked-in locations. | Red: dependencies, document, and generated client are not yet present. |
| Typed generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent `URLProtocol` stub tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; implementation must add the ranked-results stub when it exposes that client operation. | Partial: manifest/recent/capture/measurement/judgment are covered locally; ranked results has no app operation today. |
| Hand-written transport models are replaced while client-only measurement models remain | Code review of `ColorMatchingLPSAppCore` at implementation head, backed by the generated-client test above. | Not run: requires implementation. |
| No live server in CI | All client tests use `MockURLProtocol` and deterministic JSON bodies. | Passed by source inspection. |
| `swift test --disable-sandbox` | Run from `iOS` after implementation. | Not run: the container has no `swift` executable. |
| PR documents contract deltas and endpoint gaps | This document, populated from the upstream source/spec implementation linked below. | Passed as human/external evidence. |

The client tests are permanent because a local response stub protects the recurring mobile-to-server contract boundary. They intentionally do not make network calls.

## Upstream evidence consulted

- Published endpoint required by upstream: `GET /api/v1/openapi.json`, introduced in [viamin/color_matching#113](https://github.com/viamin/color_matching/commit/094bd6d3443ddacbda7e63354299867eb5bdfa9f).
- Upstream operation/schema source inspected at the `main` revision `47057afd58f7d46b4b740ca7d2d08947774471`: [`ApiSchemas`](https://github.com/viamin/color_matching/blob/47057afd58f7d46b4b740ca7d2d08947774471/lib/color_matching_web/api_schemas.ex), [`CaptureController`](https://github.com/viamin/color_matching/blob/47057afd58f7d46b4b740ca7d2d08947774471/lib/color_matching_web/controllers/capture_controller.ex), and [`TestSheetController`](https://github.com/viamin/color_matching/blob/47057afd58f7d46b4b740ca7d2d08947774471/lib/color_matching_web/controllers/test_sheet_controller.ex).

## Prose-contract deltas and endpoint gaps for the PR description

The published API does expose all six app surfaces: manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results. The generated document is not yet expressive enough to replace every hand-written model without an upstream schema expansion:

- `TestSheetManifest` requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The prose contract and current `SheetManifest` additionally rely on `sheet_version`, `manifest_url`, page geometry, markers, patches, and pairs. These fields must become typed schema properties before the generated manifest type can replace the app model.
- `RankedResults` requires only `schema_version` and `sheet_id`; result rows, scores, labels, capture provenance, printer profile, and algorithm version promised by the prose contract remain unspecified. The app also has no ranked-results client operation or caller today.
- Capture creation accepts both a legacy flat request and the nested `metadata`/`quality` shape. In the nested form, `image_width` and `image_height` are required and `iso` is an integer; the current hand-written client treats dimensions as optional and ISO as `Float`.
- Measurement uploads in the prose contract/current client include a root `scoring_algorithm_version` and per-measurement `stats`; the published schema omits both. It requires `normalized_linear_rgb_median`, while the app’s client-side measurement model permits it to be absent.
- The prose client accepts `204 No Content` for the two upload operations. The published API describes `200` JSON acknowledgment bodies containing counts. The generated client should decode/handle those acknowledgments rather than discard them.

## Implementation handoff

Vendor the exact JSON fetched from the published endpoint under `iOS/OpenAPI/color-matching.json`, pin the generator/runtime versions in `iOS/Package.swift`, and commit generated output under `iOS/Sources/ColorMatchingLPSAppCore/Generated/`. Do not use the upstream source files above as the generated-client input; they are only inspectable evidence until the JSON endpoint is fetched during implementation.
