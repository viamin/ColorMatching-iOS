# OpenAPI client verification plan

This test-writing PR maps issue #5's criteria to the smallest durable verification. The implementation PR should report the resulting test output against these references.

| Criterion | Verification | Reference |
| --- | --- | --- |
| The package uses `swift-openapi-generator` and `swift-openapi-runtime`. | Focused unit test reads the package manifest and requires the generator plugin and runtime product. | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedOpenAPIClientContractTests.swift` |
| The vendored OpenAPI document covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results. | Focused contract-artifact test parses the vendored JSON and asserts all six paths. | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedOpenAPIClientContractTests.swift` |
| The client can use generated types with no live server in CI for the existing manifest, recent-sheet, capture, measurement, and judgment flows. | Permanent local-URLProtocol system-style tests assert paths, authorization, request bodies, and stubbed response decoding. The implementation must retain or replace these tests with direct generated-client calls. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Contract differences are inspectable in the PR. | Human/external evidence: compare the fetched upstream `GET /api/v1/openapi.json` artifact against `docs/color-matching-api-contract.md` in the implementation PR description. | PR description |

## Upstream contract deltas discovered before implementation

- The upstream spec is dynamically served at `GET /api/v1/openapi.json`; this repository must vendor a fetched snapshot for deterministic generation.
- The published manifest schema only guarantees `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose contract describes many additional manifest fields that are not yet machine-validated.
- Capture creation accepts either the current nested `metadata` payload or a flattened compatibility payload. The prose contract documents only the nested form.
- Measurement upload does not require `scoring_algorithm_version` or measurement statistics in the published schema. It requires normalized RGB values and accepts RGB arrays, RGB objects, or JSON-encoded RGB strings. The prose contract requires the algorithm version and detailed statistics.
- Measurement and judgment uploads return JSON success summaries (`capture_id` plus counts) with HTTP 200, whereas the prose contract does not document a response body and the current client tests use HTTP 204.
- Ranked results are now a typed endpoint in the upstream spec, but its schema guarantees only `schema_version` and `sheet_id`; the prose contract promises richer ranking, provenance, printer-profile, and scoring fields.
