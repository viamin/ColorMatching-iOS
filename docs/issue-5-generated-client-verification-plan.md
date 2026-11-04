# Issue #5 generated OpenAPI client: verification plan

This is the red-phase test plan for replacing the hand-written iOS API layer.
It was prepared from the published server implementation for
[`viamin/color_matching#110`](https://github.com/viamin/color_matching/pull/113),
whose `GET /api/v1/openapi.json` endpoint is defined by the merged router and
OpenApiSpex annotations. The public deployment URL was not available from this
environment, so the published source is the inspectable external evidence for
this phase.

| Criterion | Smallest credible verification | Status in this phase |
| --- | --- | --- |
| Package contains `swift-openapi-generator` and `swift-openapi-runtime`; spec is fetched or vendored | Focused XCTest reads the Swift package manifest and asserts both dependencies plus the generated client artifact | Red: dependencies and artifact have not been added |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent `APIClientTests` with local `URLProtocol` stubs asserts each request path, authorization, generated request encoding, and generated response decoding | Existing coverage is retained for captures/uploads; ranked-results coverage is blocked until the generated API is introduced |
| Hand-written server DTOs are replaced, while client-only MeasurementCore models remain | Code review of generated client inputs/outputs and a compile of the application target | Not runnable in this tests-only phase |
| No live service is needed for Swift tests | `URLProtocol` stubs in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Passing before the generated-client configuration assertion |
| `swift test --disable-sandbox` is green after wiring generated types | Run that command after the implementation phase | Not run: intentional red test documents the absent generated configuration |

## Contract deltas to carry into the implementation PR

The prose contract and the server's OpenAPI declarations differ in ways the
generated client must preserve:

- Capture creation accepts both the prose nested `metadata`/`quality` payload
  and a legacy flat payload. The spec only requires `metadata` for the nested
  variant, while the prose contract presents all nested metadata and quality
  fields as a fixed shape.
- The published capture metadata requires `image_width` and `image_height`;
  the prose contract describes them as fields but the current hand-written
  Swift model makes them optional.
- Measurement upload accepts the measurements and pair scores without the
  prose-level top-level `scoring_algorithm_version`. Each pair score does
  require `algorithm_version` and one of `score`, `similarity`, or `distance`.
  `linear_rgb_median` and `normalized_linear_rgb_median` accept arrays,
  `{r,g,b}` objects, or encoded strings; the prose contract only describes
  objects and additionally describes `stats`, which is not in the schema.
- Measurement and judgment uploads return `200` JSON acknowledgement objects
  (`capture_id` plus counts), not the prose contract's empty `204` responses.
- The server spec currently defines only `schema_version` and `sheet_id` as
  required ranked-results fields. The prose contract similarly omits its full
  response shape, so richer ranked-result fields cannot safely be represented
  in the generated client until the provider tightens the schema.
- The manifest schema currently requires only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; the much richer page, marker,
  patch, pair, and printer-profile data in the prose example is not described
  structurally. This is an endpoint schema gap to record in the implementation
  PR rather than paper over with hand-written server DTOs.
