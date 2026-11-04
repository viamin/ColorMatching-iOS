# Issue #5 OpenAPI client verification plan

This test-writing run deliberately contains only tests and planning evidence. The
implementation run must replace the hand-written transport/model layer; it must
not change capture or scoring behavior.

| Criterion | Smallest credible verification | Evidence at this PR head |
| --- | --- | --- |
| Add generator/runtime and obtain the spec | Focused configuration test verifies both packages, the generator plugin, and a vendored OpenAPI document | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientAdoptionTests.swift` (red until implementation) |
| Generate every app surface, including ranked results | Focused OpenAPI document test verifies the six required paths | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientAdoptionTests.swift` (red until implementation) |
| Replace hand-written API models | Compile the app against generated types in the implementation run; no separate model-only test can establish this | Inspectable implementation/compile evidence required in the implementation PR |
| Generated client works without a live server | Permanent local-`URLProtocol` unit tests exercise manifest, recent sheets, capture creation, measurement upload, and judgment upload | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Record prose/spec deltas and endpoint gaps | Human/external evidence: compare `docs/color-matching-api-contract.md` to `viamin/color_matching` issue #110's served OpenAPI document | This plan; final PR description must contain the comparison |

## Contract deltas found before implementation

- The published `Manifest` schema requires only `schema_version`, `sheet_id`,
  and `capture_profile`; the prose contract additionally relies on sheet version,
  manifest URL, page geometry, registration markers, patches, and pairs. The
  implementation must retain or replace those fields before changing
  `MeasurementCore`'s manifest input.
- `CaptureRequest` accepts either a legacy flat payload or a nested
  `metadata`/`quality` payload. The prose only specifies the nested shape.
- `CaptureMetadata.iso` is an integer in the spec but a `Float` in the current
  client model. The generated mapping needs an explicit, lossless conversion.
- The spec requires `normalized_linear_rgb_median` for every measurement and
  describes RGB as an array, object, or JSON string. The prose makes the
  normalized value optional and adds `stats` plus a top-level
  `scoring_algorithm_version`, neither of which appears in the published
  measurement schema.
- Measurement and judgment uploads have documented JSON success responses;
  the prose/current client treat success as an empty response. The generated
  client must decode or deliberately discard those typed responses.
- `RankedResults` currently guarantees only `schema_version` and `sheet_id`.
  The prose promises source colors, scores, labels, capture provenance, printer
  profile, and scoring-algorithm version. This is an upstream spec gap that the
  PR description must call out.
