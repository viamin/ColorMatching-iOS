# OpenAPI Client Migration Evidence

## Acceptance-criterion plan

| Criterion | Smallest credible verification | Status in test-writing phase |
| --- | --- | --- |
| Generator/runtime are package dependencies and the OpenAPI document is vendored | `OpenAPIClientMigrationTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` and `testVendoredSpecificationDeclaresEveryCompanionOperation` | Red: dependencies and document are not yet present. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `OpenAPIClientMigrationTests.testVendoredSpecificationDeclaresEveryCompanionOperation`; implementation must add a permanent URLProtocol-based system test for generated operations. | Red: the vendor artifact is not present. |
| Hand-written API DTOs are replaced while client-only models remain | Review the implementation diff plus a focused source-level test of the generated runtime import. | Red: `APIClient.swift` still declares request/response DTOs. |
| Generated client is exercised against local stubs | Permanent `ColorMatchingLPSAppTests` URLProtocol tests cover current capture and upload behavior. The implementation phase must migrate those stubs to generated operations and add manifest, recent-sheet, and ranked-result stubs. | Not runnable here: Swift is unavailable. |
| Prose/spec deltas and endpoint gaps are recorded | This document and the PR description, verified by human review. | Recorded below. |

## Published-spec deltas

The upstream OpenAPI implementation was published by `viamin/color_matching` in commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f` (issue #110's work landed as PR #113). It serves the document from `GET /api/v1/openapi.json`.

- `TestSheetManifest` only declares `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The prose contract and iOS sheet analysis require page geometry, markers, patches, pairs, printer profile, and the remaining capture-profile data. Those fields are an endpoint/schema gap for a generated client.
- `RankedResults` only declares `schema_version` and `sheet_id`. The prose contract calls for source colors, scores, labels, capture provenance, printer profile, and scoring-algorithm version. This is an endpoint/schema gap; the generated client cannot type the promised result details yet.
- Capture creation accepts either a legacy flat payload or the nested `metadata` payload. `quality` is optional in the published schema, whereas the prose contract makes it part of the request. The published schema also requires only six metadata properties, not all prose fields.
- Measurement upload no longer specifies the prose contract's top-level `scoring_algorithm_version` or each measurement's `stats`. It requires normalized RGB where the prose contract presented it as a data field, and it models RGB as an array, channel object, or JSON string. Pair scores require per-score `algorithm_version` and one of `score`, `similarity`, or `distance`.
- Measurement and judgment uploads return typed 200 response bodies in the spec, rather than the hand-written client’s bodyless-success handling.
- Recent-sheet `manifest_url` is only a string in the spec (not a URI-formatted URL), and `title` is required-but-nullable.

## Implementation handoff

Do not silently narrow app behavior to fit the minimal manifest or ranked-results schemas. Either the upstream spec must expand to describe the response fields the app consumes, or the app must retain explicitly documented client-side decoding for those unsupported fields. The implementation PR should state which resolution was chosen and add URLProtocol stubs whose JSON validates the chosen generated operation types.
