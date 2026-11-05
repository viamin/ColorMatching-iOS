# Issue #5 OpenAPI Swift Client: Criterion Verification Plan

This test-writing PR establishes the verification boundary for replacing the
hand-written iOS API layer. The implementation PR must preserve these tests,
replace their test target's hand-written transport implementation with the
generated client, and make the configuration test pass.

| Criterion | Smallest credible verification | Evidence at implementation PR head |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor the published document | Focused configuration test checks both dependencies, generator plugin, runtime product, and vendored spec/config files. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientConfigurationTests.swift` |
| Generate types for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Compile the generated target and exercise every generated operation against `MockURLProtocol` fixtures. The ranked-results fixture must be added during implementation because no public app API exists for it today. | Permanent Swift test(s) in `iOS/Tests/ColorMatchingLPSAppTests/` |
| Replace hand-written API models while preserving client-side models | Compile the app target after removing API request/response models from `APIClient.swift`; tests use generated operation inputs/outputs at the adapter boundary. | `swift test --disable-sandbox` |
| Generated client behavior uses no live server | Local `MockURLProtocol` tests assert request path, authorization, encoding, and response decoding. | `APIClientTests.swift` |
| Record prose-contract differences and endpoint gaps in PR description | Human review of the implementation PR description against the upstream OpenAPI document. | PR body (external evidence) |

## Upstream-spec reconnaissance (2026-11-05)

The published-spec implementation is served by
`GET /api/v1/openapi.json`, per [upstream issue #110](https://github.com/viamin/color_matching/issues/110).
The checked upstream controller lists all required routes:

- `/api/v1/test_sheets/recent`
- `/api/v1/test_sheets/{sheet_id}/manifest`
- `/api/v1/test_sheets/{sheet_id}/ranked_results`
- `/api/v1/test_sheets/{sheet_id}/captures`
- `/api/v1/captures/{capture_id}/measurements`
- `/api/v1/captures/{capture_id}/judgments`

The live endpoint was not reachable from this isolated test-writing environment,
so the implementation PR must vendor its response exactly and record the source
commit or retrieval date.

## Deltas to record in the implementation PR description

- The prose contract leaves ranked-results response fields unspecified. The
  published server schema returns `lps-ranked-results/v1`, provenance dates,
  aggregate score data, current/latest judgments, observation counts, printer
  profile data, and algorithm versions.
- The prose says the measurement and judgment uploads return no payload. The
  published API returns `200` JSON payloads including the capture ID and
  accepted measurement/pair-score or judgment counts (instead of the prose
  contract's implied `204`).
- The prose manifest's printer profile (`id`, `name`, `paper`, `ink`,
  `settings`) differs from the server renderer's printer fields
  (`printer_make_model`, `paper_type`, `ink_type`, plus ICC/driver/calibration
  data). The vendored OpenAPI schema is authoritative for the generated type.
- No gaps were found among the six endpoints used by this app. Authentication
  failures and validation/not-found error responses are machine-described by
  the upstream spec but absent from the prose examples.
