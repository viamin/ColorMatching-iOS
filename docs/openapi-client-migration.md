# OpenAPI client migration evidence

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Evidence at implementation PR head |
| --- | --- | --- |
| Add and vendor the generated client dependencies and API document | Permanent unit test parses the vendored OpenAPI document and checks every iOS route used by the app. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIContractTests.swift` |
| Generate and wire the six API surfaces | URLProtocol-backed Swift tests call the generated-client adapter for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (extend for manifest, recent, and ranked results during implementation) |
| Replace hand-written transport models | Compile the app and adapter against generated `Client`/`Components` types; retain only domain/UI models. | `swift test --disable-sandbox` result and removal of API Codable declarations |
| No live server in CI | The test target injects `MockURLProtocol`; no test uses a network base URL. | `APIClientTests.swift` |
| Record contract deltas | Human-inspectable comparison below, checked against `viamin/color_matching` main at `2026-11-04`. | This document and PR description |

## Published-spec deltas

The upstream OpenAPI service is `GET /api/v1/openapi.json` (viamin/color_matching#110). It includes every required companion route, including ranked results, so there is no endpoint gap blocking this migration.

The published contract differs from `docs/color-matching-api-contract.md` in material ways:

- The prose manifest example describes printer fields `id`, `name`, `paper`, `ink`, and `settings`; the server renders printer make/model, paper type, ink type, ICC and driver/calibration fields instead. The current OpenAPI `TestSheetManifest` schema only requires `schema_version`, `sheet_id`, and `capture_profile`, so the client must not treat the prose's extra manifest fields as generated guarantees.
- Capture creation accepts either the legacy flattened capture attributes or the nested `metadata` form. The prose documents only the nested form. The generated adapter should retain the nested app payload unless product behavior changes.
- The prose calls the metadata duration `exposure_duration_seconds`; the flattened compatible request uses `exposure_duration`. This is another reason to construct the generated nested request deliberately.
- Measurement uploads in the prose include `scoring_algorithm_version` and per-measurement `stats`; the published `MeasurementUploadRequest` only describes measurements and pair scores. Its RGB field accepts array, `{r,g,b}`, or JSON-string compatibility forms, and a pair score may use `score`, `similarity`, or `distance`.
- Measurement and judgment uploads return `200` JSON bodies (`capture_id` plus accepted counts). The existing client discards those bodies after accepting any 2xx response.
- Ranked results now have the concrete `lps-ranked-results/v1` response schema; the prose only gave a narrative response requirement. The app currently has no request for this documented endpoint.

## Red-phase status

`OpenAPIContractTests` intentionally fails until the implementation vendors the upstream JSON document at `iOS/OpenAPI/color-matching-v1.json`. It is a permanent regression test for the document and endpoint coverage, not an ephemeral test. The implementation run must expand `APIClientTests` to invoke the generated client for the three read paths as well as the existing write paths.
