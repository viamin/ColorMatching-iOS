# OpenAPI client migration (#5)

This document is the implementation PR's evidence and handoff note. The
published OpenAPI document is served by `viamin/color_matching` at
`GET /api/v1/openapi.json` (issue [color_matching#110](https://github.com/viamin/color_matching/issues/110)).

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this test-writing PR |
| --- | --- | --- |
| Package has `swift-openapi-generator` and `swift-openapi-runtime`; the upstream document is vendored/fetched | `APIClientTests.testPackageDeclaresOpenAPIGeneratorAndRuntimeDependencies` and `APIClientTests.testVendoredOpenAPISpecDeclaresEveryAppUsedEndpoint` | Red: implementation work required |
| Generated client exposes manifest, recent sheets, capture creation, both uploads, and ranked results | The vendored-spec endpoint test plus local-stub client tests for each operation | Partial red: manifest and ranked-results client tests must be added with generated client integration |
| Hand-written API models are replaced while client-only measurement models remain | Code review of the generated-client adapter and a compile-time Swift test using generated request/response types | Not run: requires implementation |
| Generated client handles local stubbed responses without a live server | Permanent `ColorMatchingLPSAppTests` URL-protocol tests | Existing capture and upload tests pass; recent-sheet test is added in this PR |
| PR description records contract deltas and endpoint gaps | Inspect this section and the final PR body against the published `/api/v1/openapi.json` | Human/external evidence required |
| `swift test --disable-sandbox` is green | Run that command after dependencies and generation are committed | Not run in this red-phase PR |

## Contract deltas found before implementation

The published API's OpenApiSpex source is the current external evidence; the
served JSON should be vendored before generation so its exact revision is
reviewable.

- The prose contract describes a detailed manifest, but the published
  `TestSheetManifest` schema currently requires only `schema_version`,
  `sheet_id`, and `capture_profile.scoring_algorithm_version`. It omits typed
  properties for page geometry, markers, patches, pairs, printer profile, and
  `manifest_url`. A generated client therefore cannot replace the manifest
  model safely until the published schema includes those fields.
- The published capture request supports the prose's nested `metadata` and
  `quality` form, but also exposes legacy flattened fields. Its declared
  required fields are less strict than the prose; in particular the nested
  quality fields are not required.
- The measurement-upload schema requires both RGB medians, but does not model
  the prose contract's `scoring_algorithm_version` or measurement `stats`.
  The pair-score schema permits score, similarity, or distance forms, whereas
  the prose only documents distance and similarity.
- Upload endpoints return typed 200 response bodies containing capture and
  accepted-row counts. The existing client discards those bodies and the prose
  contract does not describe them.
- The ranked-results endpoint is now published, but its schema currently only
  requires `schema_version` and `sheet_id`; pair ranks, source colors, scores,
  labels, capture provenance, and algorithm versions remain an endpoint gap
  for a useful generated client.

The implementation PR should copy this section into its description, update
it against the vendored JSON, and explicitly state whether it generates only
the fully specified operations or blocks on the schema gaps above.
