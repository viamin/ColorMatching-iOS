# Issue #5: generated OpenAPI Swift client

## Criterion verification plan

| Criterion | Smallest credible verification | Location |
| --- | --- | --- |
| Package includes `swift-openapi-generator` and `swift-openapi-runtime` | Focused adoption test inspects the package manifest; compilation proves dependencies resolve. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientAdoptionTests.swift` |
| Generated client covers manifest, recent sheets, capture creation, measurements, judgments, and ranked results | Focused adoption test requires the app adapter to import the generated module and expose each surface; stub-response tests exercise manifest/recent and the existing request tests exercise the three write endpoints. Add a ranked-results stub test when the generated adapter exists. | `iOS/Tests/ColorMatchingLPSAppTests/` |
| Hand-written API models are replaced while client-only models remain | Review generated source and adapter diff; the adoption test guards generated-client import rather than imposing model names. | Human review of PR diff |
| No live server in CI | `MockURLProtocol` supplies every exercised response locally. | `APIClientTests.swift` |
| Contract deltas and endpoint gaps are recorded | External evidence: provider issue #110 and merged PR #113. | This document |

## Contract delta observed from provider PR #113

The published provider route and OpenAPI schema modules differ from `docs/color-matching-api-contract.md` in these material ways:

- The prose manifest specifies page geometry, markers, printer/capture profiles, patches, and pairs. The published `Manifest` schema only requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; it does not model the fields needed by `MeasurementCore`.
- The prose capture body is the nested `{metadata, quality}` representation. The published `CaptureRequest` accepts that representation but also a legacy flat shape. `quality` has no required fields in the schema.
- The prose measurement body requires `scoring_algorithm_version`, rich `stats`, and scores with `distance` plus `similarity`. The published `MeasurementUploadRequest` does not declare `scoring_algorithm_version` or `stats`; each pair score instead permits one of `score`, `similarity`, or `distance`.
- The prose says measurement and judgment uploads return no body (`204`). The published API returns `200` JSON count responses for both.
- The prose leaves ranked-results response details open. The published `RankedResults` schema only requires `schema_version` (`lps-ranked-results/v1`) and `sheet_id`, so it is insufficient to generate the app’s expected ranking payload types.
- The provider serves the spec unauthenticated at `GET /api/v1/openapi.json`; all six app-used operational endpoints require bearer authentication.

## Endpoint gap

All six requested paths exist in the provider router. The gap is schema completeness, not routing: manifest, measurement, and ranked-results schemas need the fields above before generated types can replace the existing hand-written boundary without losing data.

Sources inspected on 2026-11-03:

- https://github.com/viamin/color_matching/issues/110
- https://github.com/viamin/color_matching/pull/113
- https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_schemas.ex
- https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex
