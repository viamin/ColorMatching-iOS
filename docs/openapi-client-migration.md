---
module: iOS API client
tags: [openapi, swift-openapi-generator, testing]
problem_type: migration
---

# Generated OpenAPI client migration

This is the implementation handoff and PR-description source for #5. The
published provider contract is served by
`viamin/color_matching` at `GET /api/v1/openapi.json` (issue
[`viamin/color_matching#110`](https://github.com/viamin/color_matching/issues/110)).

## Verification plan

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generator, runtime, and provider document are present | Focused XCTest reads the Swift package manifest and vendored specification, then checks all six used paths | `APIClientTests.testOpenAPIGeneratedClientIsConfiguredForEveryUsedOperation` |
| Manifest, recent sheets, capture creation, measurement upload, and judgment upload use typed generated operations | URLProtocol-backed XCTest stubs assert request paths/payloads and decode successful responses without a live server | `APIClientTests` |
| Ranked results use a typed generated operation | Add a URLProtocol-backed XCTest against the generated ranked-results operation when its generated symbol is introduced | `APIClientTests` |
| Handwritten wire models are removed while local measurement models remain | Code review of `ColorMatchingLPSAppCore` and `MeasurementCore`; this is a structural migration not settled by an endpoint test | PR diff |
| Contract deltas and spec gaps are recorded | Human inspection of this document/PR description against the provider's served OpenAPI document | PR description |

The first criterion is intentionally red in the tests-only phase. It directs the
implementation phase to vendor the exact document at
`iOS/Sources/ColorMatchingAPI/openapi.json`, declare a `ColorMatchingAPI` target,
and include `swift-openapi-generator` and `swift-openapi-runtime` in
`iOS/Package.swift`. The implementation phase must replace this test's temporary
wrapper-level coverage with generated-operation tests for all six paths,
including ranked results.

## Published-contract deltas

Compared to `docs/color-matching-api-contract.md`, the provider implementation
and its published OpenAPI metadata establish these changes:

- `GET /api/v1/test_sheets/{sheet_id}/ranked_results` is now concretely
  versioned as `lps-ranked-results/v1` and returns sheet/capture provenance,
  aggregate scores, source-color objects, observation data, and printer-profile
  data. The prose contract named this endpoint but supplied no response schema.
- A printer profile is `printer_make_model`, `paper_type`, `ink_type`, plus
  optional print/calibration metadata. The prose contract instead described
  `id`, `name`, `paper`, `ink`, and `settings`.
- Capture creation accepts the prose contract's nested `metadata`/`quality`
  representation and also a flat compatibility representation. The provider
  declares only the metadata fields needed for a capture as required.
- Measurement uploads no longer require the prose contract's top-level
  `scoring_algorithm_version` or per-measurement statistics. Their successful
  response is a JSON acknowledgement containing capture and accepted-row
  counts, rather than an unspecified empty response.
- Judgment uploads likewise return a JSON acknowledgement with `capture_id` and
  `judgment_count`.

## Provider-spec gaps to preserve in the PR description

The provider's current OpenAPI component schemas are intentionally minimal for
two read surfaces: `TestSheetManifest` documents only `schema_version`,
`sheet_id`, and `capture_profile.scoring_algorithm_version`; `RankedResults`
documents only `schema_version` and `sheet_id`. The generated Swift types will
therefore not model the additional response fields used today until the provider
expands those schemas. Do not silently re-create handwritten Codable response
types to conceal this gap. Record whether the app can consume the minimum
generated response or whether a follow-up provider issue is required before
removing its local manifest/ranking projections.

## PR description text

```md
## Summary

- Vendored the provider's published `/api/v1/openapi.json` and generated the
  typed Swift client for manifest, recent-sheets, capture, measurement,
  judgment, and ranked-results operations.
- Replaced API wire models with generated types; retained measurement and UI
  domain models that never cross the network boundary.
- Added URLProtocol tests using local stubbed responses only.

## Contract deltas and gaps

- Ranked-results is now versioned (`lps-ranked-results/v1`) with a concrete
  server response; the previous prose contract lacked its schema.
- Printer-profile, capture compatibility, and upload-acknowledgement shapes
  differ as recorded in `docs/openapi-client-migration.md`.
- The provider spec currently models only a minimal manifest/ranked-results
  response. [State the resolution or linked provider follow-up here.]

## Verification

- `swift test --disable-sandbox`
```
