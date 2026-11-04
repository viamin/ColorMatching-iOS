# OpenAPI client migration: acceptance evidence plan

This file is the tests-only PR evidence for #5. The implementation PR must
replace the hand-written transport Codable types with types generated from the
published document at `GET /api/v1/openapi.json` in
`viamin/color_matching#110` (merged as `viamin/color_matching#113`).

| Criterion | Smallest credible verification | Planned evidence |
| --- | --- | --- |
| Add the generator/runtime and vendor or fetch the document | Inspect the package manifest, generator configuration, and checked-in/fetched OpenAPI document. | Human/external evidence: dependency and regeneration diff reviewed in implementation PR. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent local-stub integration tests issue each generated operation and decode its documented response. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; add ranked-results coverage in the implementation PR when the generated operation exists. |
| Remove hand-written API models while preserving client-only models | Inspect symbols/imports and compile the app after regeneration. | Human/external evidence plus `swift test --disable-sandbox` in the implementation PR. |
| Generated client works without a live server | Permanent local-stub integration tests. | `APIClientTests` uses `MockURLProtocol`; no network server or database is involved. |
| PR describes contract deltas and endpoint gaps | Inspectable PR description based on the published OpenAPI operation/schema metadata. | The deltas below; implementation PR must copy them into its description and amend if the generated document differs. |

## Published-spec deltas from the prose contract

- Measurement and judgment uploads return `200` JSON acknowledgement bodies
  (`capture_id` plus counts), not the prose contract's `204` empty response.
- Capture creation accepts either the newer nested `metadata`/`quality` request
  or a legacy flat capture shape. The app should generate and use the nested
  shape.
- Pair scores allow `score`, `similarity`, or `distance`; each requires
  `pair_id` and `algorithm_version`. The app's current `distance` and
  `similarity` payload remains compatible.
- RGB measurement fields accept arrays, `{r,g,b}` objects, or JSON-encoded
  strings. The app uses the typed object representation.
- Ranked results are now a documented endpoint and declare
  `schema_version: lps-ranked-results/v1`, but the published schema currently
  only requires `schema_version` and `sheet_id`. It does not machine-describe
  the result rows promised by the prose contract (source colors, scores,
  labels, capture provenance, printer profile, and scoring algorithm version).

## Endpoint gap

The app currently has no ranked-results request. The implementation PR must
wire the generated ranked-results operation into the app-facing API adapter and
add a local-stub response test once the generated Swift type name is known.
