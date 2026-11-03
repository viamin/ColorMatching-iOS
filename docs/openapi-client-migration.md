# OpenAPI client migration — issue #5

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Add the generator/runtime and vendor or fetch the published document | `APIClientTests.testOpenAPIGeneratedClientIsConfiguredForEveryCompanionSurface` checks the package declarations and a vendored OpenAPI document. | Red — implementation pending. |
| Generate and wire manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` stubs exercise the existing manifest/recent/capture/upload boundary; the generated-client configuration test requires the runtime wiring and ranked-results entry point. | Red — generated client and ranked-results wrapper pending. |
| Replace hand-written API models, retaining client-only models | The generated-client configuration test rejects the current private request model and requires runtime wiring. | Red — implementation pending. |
| Swift tests with local stubbed responses | `APIClientTests` uses `MockURLProtocol`; no test contacts a live server. | Partially covered now; generated types remain pending. |
| PR description records prose-contract deltas and endpoint gaps | The next implementation PR must copy the findings below into its body and update them against the exact vendored spec revision. | Human/external evidence required. |

The current app has a recurring API flow (load a sheet, create a capture, upload measurements and judgments), so its stubbed client tests are permanent rather than ephemeral. No one-off `.ephemeral-tests/` scenario is needed.

## Published-spec comparison (observed 2026-11-03)

Source inspected: `viamin/color_matching` `main`, which serves OpenAPI from `GET /api/v1/openapi.json` and documents all six required paths.

Differences from `docs/color-matching-api-contract.md`:

- The published `CaptureRequest` accepts two shapes (`anyOf`): the prose nested `metadata`/`quality` payload and a legacy flat payload. The app should generate against the nested form it already sends.
- `CaptureMetadata.iso` is an integer in the published schema; the hand-written Swift model uses `Float`.
- The published measurement request does not require the prose `scoring_algorithm_version`, and its measurement rows do not document the prose `stats` object. It does require `normalized_linear_rgb_median` when a measurement row is present.
- Pair scores require `pair_id`, `algorithm_version`, and one of `score`, `similarity`, or `distance`; the prose sends both similarity and distance, which is valid but less precise than choosing the canonical generated representation.
- Measurement and judgment uploads return JSON `200` response objects with counts. The prose/client expects no response body and stubs `204`.
- The ranked-results endpoint is published and returns `lps-ranked-results/v1`, but the prose supplies only a narrative response description. The current iOS app has no ranked-results API method and still displays locally calculated scores.
- The published manifest schema is intentionally minimal: only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` are required. The richer fields the app currently decodes are rendered by the server but are not fully captured by the schema, leaving a generation gap for manifest geometry.

## Implementation handoff

Vendor a snapshot of `/api/v1/openapi.json` with its upstream commit SHA, add Apple `swift-openapi-generator` and `swift-openapi-runtime`, and configure a generated target. Keep conversions only at the boundary for `MeasurementCore` values that are genuinely client-side. Update the local stubs to use generated request and response types, add the ranked-results stub, then replace this plan's red status with actual `swift test --disable-sandbox` output.
