# Issue #5 OpenAPI Client Verification Plan

## Criterion mapping

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Add the generator/runtime and vendor the document | `testOpenAPIDocumentIsVendoredForGeneratedClient` permanently asserts the documented vendor location; package resolution verifies dependencies. | Red: the document and dependencies are not present. |
| Generate the used API surfaces | Permanent `MockURLProtocol` tests exercise manifest, recent sheets, capture creation, measurement upload, and judgment upload. Add the ranked-results generated operation and a stubbed response test during implementation. | Partial: ranked results have no app client call today. |
| Replace hand-written API models | Inspect the generated target and compile the app after removing server-owned declarations from `APIClient.swift`; retain `MeasurementCore` models that are client-side analysis models. | Not run in this tests-only phase. |
| Generated client local-stub tests | `APIClientTests` uses `MockURLProtocol`; no test contacts a live server. | Existing five flows covered; ranked-results test is implementation work. |
| PR contract-delta record | Use the deltas below in the implementation PR description, checked against the vendored JSON document revision. | External evidence required. |
| `swift test --disable-sandbox` | Run after generation and dependency resolution. | Not run: Swift is unavailable in this container. |

## PR description evidence: upstream contract deltas

The upstream dependency, [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110), is closed. Its router exposes `GET /api/v1/openapi.json` and declares the six sheet/capture routes used by this app. The implementation PR must vendor that served JSON, record its commit/digest, and regenerate from that exact artifact.

The source behind the published specification reveals these changes from `docs/color-matching-api-contract.md` that must be checked against the vendored document:

- Measurement and judgment uploads return `200` JSON acknowledgement bodies containing the capture ID and accepted-row count; the prose contract says `204` with no response body.
- Ranked results are now a concrete `lps-ranked-results/v1` payload including ranked pair data, capture provenance, printer profile, scoring versions, and labels. The prose contract only describes the endpoint in prose and provides no response schema.
- The manifest printer profile is now represented by printer make/model, paper type, ink type, ICC profile, print settings, driver/calibration fields, and notes. The prose model instead uses `id`, `name`, `paper`, `ink`, and `settings`.
- Recent-sheet titles are currently rendered as `null`; the client must keep the field nullable.
- Capture IDs are persistence IDs rendered as strings, rather than the illustrative `capture_123` prose value.

No endpoint gap was found for manifest, recent sheets, capture creation, measurement upload, judgment upload, or ranked results: all are in the upstream router. The current iOS app does not call ranked results, so generation should include it but must not change capture/scoring behavior to add a new UI flow.

## Sources inspected

- [Upstream router](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex)
- [Capture controller](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/capture_controller.ex)
- [Test-sheet controller](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/test_sheet_controller.ex)
- [Test-sheet renderer](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/test_sheet_json.ex)
