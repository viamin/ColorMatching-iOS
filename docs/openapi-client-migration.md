# OpenAPI Client Migration Evidence

This document is the proposed PR description evidence for issue #5. It records
the verification plan and the contract comparison made against the upstream
`viamin/color_matching` `main` branch at commit `47057af` (the branch that
closed upstream issue #110).

## Criterion-to-verification map

| Criterion | Smallest credible verification | Evidence at this PR head |
| --- | --- | --- |
| The package declares `swift-openapi-generator` and `swift-openapi-runtime`. | Focused Swift package test reads the package manifest. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift:testPackageDeclaresGeneratedClientDependencies` (red until implementation) |
| A vendored OpenAPI document covers every app operation. | Focused Swift contract test parses the vendored JSON and asserts each operation. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift:testVendoredOpenAPIDocumentCoversEveryCompanionOperation` (red until implementation) |
| Generated types are used through local stubbed responses. | Permanent `URLProtocol` unit tests for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results. | Existing `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; expand in implementation alongside the generated-client adapter. |
| The PR records contract deltas and endpoint gaps. | Human-inspectable comparison to upstream source and emitted spec. | This document; implementation must replace the source comparison with the vendored document revision/SHA. |

The first two tests intentionally fail in this tests-only run: neither a
vendored OpenAPI JSON document nor the generator/runtime package dependencies
exist yet. They are focused acceptance tests, not evidence that the migration
has passed.

## Prose contract versus upstream published spec

The upstream server now serves the document from `GET /api/v1/openapi.json`.
The following deltas were established from its OpenAPI schema/controller source
and must be rechecked against the vendored emitted JSON during implementation.

- Capture creation accepts either the nested `metadata` shape in the prose
  contract or a legacy flat shape. The prose describes only the nested shape.
- `CaptureMetadata.iso` is an integer in the spec; the current hand-written
  Swift model uses `Float`.
- Measurement upload responses are documented as `200` JSON acknowledgements
  with `capture_id`, `measurement_count`, and `pair_score_count`; the prose
  contract and current client expect an empty `204`.
- Judgment upload likewise returns a `200` JSON acknowledgement with
  `capture_id` and `judgment_count`, rather than the prose contract's empty
  `204`.
- The server's measurement schema requires
  `normalized_linear_rgb_median` and accepts flexible RGB encodings (array,
  object, or JSON string). The prose describes RGB objects and includes an
  additional `stats` object that is not specified by the upstream request
  schema.
- The prose places `scoring_algorithm_version` at measurement-upload top
  level. The upstream request schema instead documents per-pair
  `algorithm_version` and does not require the top-level field.
- Ranked results now have an explicit endpoint and runtime schema version
  `lps-ranked-results/v1`; this endpoint was only aspirational in the prose
  contract.

## Endpoint gaps discovered

- The upstream OpenAPI schemas for `TestSheetManifest` and `RankedResults`
  currently require only their version and sheet identifier, while the runtime
  responses contain materially richer data used by this app (geometry, patches,
  pairs, score summaries, provenance, and judgments). Generated types will not
  be strongly typed for those omitted fields until the provider expands the
  schemas.
- Capture quality's rejection values and white-balance gain fields are not
  constrained as precisely in the OpenAPI schema as in the prose contract.
- The current app has no ranked-results call. The implementation must add that
  generated operation without changing capture or scoring behavior.
