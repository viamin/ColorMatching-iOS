---
module: ios-api-client
tags: [openapi, swift, generated-client, contract-testing]
problem_type: test-plan
---

# Generated OpenAPI Client: Red-Phase Plan

## Acceptance-criterion verification map

| Criterion | Smallest credible verification | Red-phase location | Expected implementation evidence |
| --- | --- | --- | --- |
| The package uses `swift-openapi-generator` and `swift-openapi-runtime` and vendors the provider document. | Focused unit test reads `iOS/Package.swift` and the vendored JSON document. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` | The test passes after the package dependencies, generator build plugin, and `iOS/OpenAPI/color_matching.openapi.json` are added. |
| Every companion surface is generated from the provider contract. | Focused unit test reads the vendored document and requires the six operation/path pairs. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` | The test passes with the provider document and fails if a required operation disappears. |
| Manifest/recent-sheet reads preserve the user-visible app flow. | Permanent local-stub client tests assert request path, bearer authorization, and decoded response values. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Tests remain green while the adapter switches from hand-written Codable requests to generated operations. |
| Capture creation, measurement upload, and judgment upload preserve requests. | Permanent local-stub client tests assert request path and JSON payloads. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Tests remain green while generated request bodies replace hand-written request types. |
| Ranked-results support is present. | Focused contract test requires the ranked-results operation in the vendored document. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` | Add a local-stub adapter test once the app actually consumes ranked results; it is not called by the current UI. |
| Real API compatibility and whether the provider spec is sufficiently typed. | Inspect the served provider contract and provider source; this cannot be settled by an iOS stub. | Provider issue `viamin/color_matching#110`, inspected at commit `47057afd58f7d46b4d4b740ca7d2d08947774471`. | Human/provider confirmation or a provider-spec update before treating typed replacement as complete. |

## Provider contract deltas found

The prose contract is not the provider authority. The current provider serves the document dynamically from `GET /api/v1/openapi.json`; this repository does not yet vendor a fetched snapshot.

- `Manifest` declares only `schema_version`, `sheet_id`, and a `capture_profile` containing `scoring_algorithm_version` as required. The prose contract and the provider renderer contain page geometry, markers, printer profile, patches, pairs, and additional manifest metadata. A generator will not produce fully typed models for those omitted fields.
- `RankedResults` declares only `schema_version` and `sheet_id`. The actual response includes ranked pair rows, source colors, aggregate scores, capture provenance, printer profile, and scoring-algorithm versions described in the prose contract.
- `MeasurementUploadRequest` does not declare `scoring_algorithm_version` or measurement `stats`, although the prose client sends both. It also makes `normalized_linear_rgb_median` required, while the current client-side model permits it to be absent.
- `CaptureRequest.quality` has no required fields or rejection enum. The prose contract defines marker count, blur score, and the allowed rejection values.
- `JudgmentUploadRequest.judgment` is an unrestricted string; the prose contract restricts it to `match`, `near_match`, or `no_match`.
- The server returns JSON receipt bodies for measurement and judgment uploads (`capture_id` plus counts); the prose contract did not specify responses and the current iOS client discards them.
- The prose printer-profile example uses `id`, `name`, `paper`, `ink`, and `settings`; the provider renderer uses `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`, and related fields. The provider `PrinterProfile` schema also declares an integer ID, not the prose example's string ID.

These deltas mean the implementation should vendor the served JSON, generate only operations supported by it, and retain client-side adapters for app-domain models. It should not claim that generation has replaced the full hand-written manifest/ranked-results models until the provider schemas become complete.

## Test status for this red phase

`OpenAPIContractTests` is intentionally red until the implementation run adds the package configuration and vendors the provider document. The local-stub API tests are permanent regression coverage and do not contact a live server.
