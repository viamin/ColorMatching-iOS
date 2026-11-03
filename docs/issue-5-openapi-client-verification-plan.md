# Issue #5 OpenAPI client verification plan

This is the test-writing (red) plan for replacing the iOS hand-written API
layer. The server authority inspected for this plan is
`viamin/color_matching` issue #110, whose `main` branch serves the generated
spec at `GET /api/v1/openapi.json`.

## Criterion map

| ID | Acceptance criterion | Smallest credible verification | Status in this test-writing PR |
| --- | --- | --- | --- |
| AC-1 | Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor or fetch the published document. | `OpenAPIClientGenerationTests.testOpenAPIClientGenerationIsConfiguredForEveryUsedSheetAndCaptureOperation` checks package dependencies and the vendored document. | Red: dependencies and document do not yet exist. |
| AC-2 | Generate the manifest, recent sheets, create capture, measurement upload, judgment upload, and ranked-results operations. | The same permanent test asserts all six OpenAPI paths are present in the vendored source spec. | Red: no source spec is vendored. |
| AC-3 | Replace hand-written API models while retaining client-only models. | `OpenAPIClientGenerationTests.testHandWrittenWireModelsAreReplacedByTheGeneratedClient` rejects the current hand-written wire-model declarations. | Red: declarations are still in `APIClient.swift`. |
| AC-4 | Exercise generated client against local stubs, without a live server. | Permanent `APIClientTests` will be converted to call generated operations through its existing `MockURLProtocol`; add a ranked-results fixture and assert every response body. | Not yet runnable: generated operation/type names must be taken from the vendored server document. |
| AC-5 | PR description records prose-contract deltas and endpoint gaps. | Human review of the PR description against the delta list below. | Requires implementation PR evidence. |
| AC-6 | `swift test --disable-sandbox` is green with generated types wired in. | Run that exact command in `iOS/` after the generated target and stub tests land. | Not run: this container has no `swift` executable. |

The client-stub coverage is permanent rather than ephemeral: these are the
recurring APIs used by the capture workflow, and a generated-client regression
must be caught on every PR.

## Published-spec deltas to record in the implementation PR

Compared with `docs/color-matching-api-contract.md`, the server's published
spec currently has these important differences:

- The manifest schema only requires `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; the prose document specifies a
  much richer manifest. Generated types therefore make most manifest fields
  optional unless the provider tightens its schema.
- `ranked_results` is now a specified response with required
  `schema_version: lps-ranked-results/v1` and `sheet_id`; the prose document
  left its response shape unspecified. The real response fixture must be
  captured from the published document before implementing this client method.
- Recent-sheet `manifest_url` is a string in the published schema, rather than
  explicitly a URI; `title` is required-but-nullable in both intent and server
  schema.
- Capture creation permits either the nested `metadata` form from the prose
  contract or a legacy flat body. The server schema requires only
  `device_model`, `lens`, `image_width`, `image_height`, `app_version`, and
  `timestamp` within nested metadata; several fields treated as client fields
  today are optional.
- Measurement upload does not specify `scoring_algorithm_version` or the
  client-only measurement statistics. It requires normalized median RGB and
  accepts RGB arrays, objects, or JSON strings. Pair scores require
  `pair_id`, `algorithm_version`, and one of `score`, `similarity`, or
  `distance`.
- Measurement and judgment uploads return JSON `200` acknowledgement bodies
  (`capture_id` plus count), while the prose contract and current tests assume
  an empty `204` response. The generated client and stubs must assert those
  acknowledgement bodies.
- The published judgment schema accepts any string; the prose contract's three
  allowed values are not represented as an enum. This is a provider-spec gap
  to call out in the implementation PR.

## Endpoint gaps

All six issue-scoped paths exist in the provider router and generated OpenAPI
document. The gaps are schema precision, not missing routes: the published
manifest and ranked-results schemas do not fully describe the rich response
shapes relied on by the iOS app, and the judgment enum is absent.
