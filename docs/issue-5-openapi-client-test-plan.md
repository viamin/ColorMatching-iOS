---
module: ios-api
tags: [openapi, swift, testing]
problem_type: test-plan
---

# Issue #5: generated OpenAPI client test plan

This is the acceptance-criterion map for the implementation PR. It is based
on `viamin/color_matching` at `47057afd58f7d46b4d4b740ca7d2d08947774471`
(2026-10-31), which publishes the contract at `GET /api/v1/openapi.json`.
The test-writing PR does not alter production code, dependencies, or the
generated client.

| Criterion | Smallest credible verification | Test-writing status |
| --- | --- | --- |
| Generated package dependencies and vendored/fetched OpenAPI document | Inspect `iOS/Package.swift`, generation configuration, and the committed spec source/revision. | Not runnable until implementation adds them. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent `APIClientTests` URLProtocol stubs assert method, path, authorization, request encoding, and decoding/acknowledgements for all six operations. | Manifest/recent/create/measurement/judgment tests are added now. Ranked results is blocked: the current public adapter has no ranked-results operation to exercise without introducing a compile error in this tests-only run. |
| Hand-written transport models are replaced while client-only models remain | Inspect source: generated OpenAPI types must be used for API request/response shapes, while `MeasurementCore` analysis types remain local. | Human/code-review evidence after implementation. |
| Generated client is exercised without a live server | Run `swift test --disable-sandbox` and inspect the URLProtocol stub tests. | Runnable now; implementation must keep these stubs and add ranked-results coverage. |
| PR records prose-contract versus published-spec deltas and endpoint gaps | Inspect the PR description against the deltas below. | Human/external evidence after the implementation PR is opened. |

## Contract deltas to include in the implementation PR description

- The published spec permits either the existing nested `metadata` capture
  object or a flat capture payload. The prose contract documents only nested
  metadata.
- Capture metadata `iso` is an integer in the published spec; the current
  hand-written Swift model uses `Float`.
- The published measurement schema requires
  `normalized_linear_rgb_median`, but does not describe the prose contract's
  top-level `scoring_algorithm_version` or per-measurement `stats` object.
  It requires each pair score to include `algorithm_version` plus one of
  `score`, `similarity`, or `distance`.
- Measurement and judgment uploads return typed 200 acknowledgement objects
  (`capture_id` and count fields); the prose contract leaves those responses
  unspecified and the current client discards them.
- Ranked results is now a documented endpoint with a
  `lps-ranked-results/v1` schema; it is absent from the current Swift adapter.
- The prose manifest describes a printer-profile object with `id`, `name`,
  `paper`, `ink`, and `settings`. The real renderer supplies
  `printer_make_model`, `paper_type`, `ink_type`, and further print metadata,
  while the published `Manifest` schema formally requires only
  `schema_version`, `sheet_id`, and `capture_profile`. The spec needs a more
  complete manifest response schema for fully typed generation.
- The prose limits rejection and judgment strings, but the published schemas
  currently define them as unrestricted strings. The implementation must not
  invent enums that the source contract does not publish.
