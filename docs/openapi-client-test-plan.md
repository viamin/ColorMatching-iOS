# OpenAPI Swift client: acceptance evidence and PR notes

This is the red-phase plan for #5. It records the smallest credible proof for
each criterion before the generated client is implemented. The permanent test
added with this plan intentionally fails until the OpenAPI document is vendored
and is sufficiently complete.

| Criterion | Verification | Initial result |
| --- | --- | --- |
| OpenAPI generator/runtime and vendored document | `OpenAPIDocumentContractTests.testVendoredDocumentCoversEveryAppOperation` reads `iOS/OpenAPI/openapi.json` and requires all six app operations. | Failed: no vendored document exists. |
| Generated types replace server API models | Compile `ColorMatchingLPSAppCore` after generation; retain `MeasurementCore` capture-analysis models. | Not run: implementation phase. |
| Manifest, recent sheets, capture, measurement, judgment, and ranked-results surfaces | `OpenAPIDocumentContractTests.testVendoredDocumentDescribesFieldsNeededByGeneratedClient` requires the response models’ client-consumed fields. | Failed: no vendored document exists. Upstream’s current `ApiSchemas` source also leaves manifest and ranked-results schemas materially incomplete. |
| Local-stub Swift client tests | Add permanent URLProtocol-based tests that execute each generated operation against fixture responses; assert request method/path/auth/body and decoded response. | Not run: generated operation/type names are not available in this tests-only phase. |
| `swift test --disable-sandbox` | Run in implementation phase. | Not run: the environment has no `swift` executable. |

## Contract deltas for the PR description

Evidence was inspected from `viamin/color_matching` main at issue #110’s closed
state (2026-11-04), specifically `ColorMatchingWeb.ApiSchemas`,
`CaptureController`, and `TestSheetJSON`.

- The prose says measurement and judgment uploads return no body (the iOS client
  currently accepts any 2xx response). The published contract declares 200 JSON
  responses containing `capture_id` plus `measurement_count`/`pair_score_count`
  or `judgment_count`; the generated client must decode those responses.
- The prose’s measurement payload requires a top-level
  `scoring_algorithm_version` and nested `stats`. The published
  `MeasurementUploadRequest` does not describe either and instead requires
  `normalized_linear_rgb_median`; it also permits multiple RGB representations.
  This must be reconciled with the provider before generated models replace the
  current payload.
- The prose describes full manifest and ranked-result payloads. The published
  schemas currently require only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version` for a manifest, and only
  `schema_version` and `sheet_id` for ranked results. They omit fields the iOS
  app consumes (manifest geometry, patches, pairs; ranked `results`). This is a
  provider-spec gap, not a client-side assumption.
- Capture creation remains compatible through the documented nested
  `metadata`/`quality` alternative, but the provider also documents a flat,
  legacy shape and marks fewer metadata fields as required than the prose.
- The actual provider’s `recent` endpoint limits output to 20 sheets; the prose
  does not state this limit. Its response shape is otherwise aligned.

## Endpoint gaps discovered

The source router exposes all six required endpoints, so there is no route gap.
There is a contract-completeness gap for generated clients: the provider must
expand `TestSheetManifest` and `RankedResults` schemas and reconcile the
measurement request schema before generated models can faithfully replace the
hand-written API layer. The implementation PR should either consume an updated
provider document or record this dependency as blocking rather than weakening
the permanent tests.
