---
module: iOS API client
tags: [openapi, swift, api-contract]
problem_type: migration-plan
---

# OpenAPI client migration evidence for #5

## Acceptance-criterion plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Swift OpenAPI generator/runtime and a vendored published document | `APIClientTests.testVendoredOpenAPIDocumentDefinesEveryConsumedOperation` inspects the vendored document and its six required paths. | Red: the document is not yet vendored. |
| Typed client supports manifest, recent sheets, capture creation, measurement and judgment uploads, and ranked results | Local `URLProtocol` stubs exercise the app-facing manifest/recent/capture/upload calls; the vendored-document test requires the ranked-results operation too. The implementation change must add a local-stub ranked-results test when it introduces that app-facing call. | Partially red: ranked results and generated types are absent. |
| Hand-written API models are replaced while client-only models remain | Human source review of the generated target and the app/core boundary. | Not run; requires the implementation commit. |
| No live server is needed in CI | `APIClientTests` uses `MockURLProtocol` exclusively. | Ready to run locally/CI. |
| `swift test --disable-sandbox` is green | Run that exact command after the generated client is added. | Not run in the red phase. |
| PR description records contract deltas and endpoint gaps | This document supplies the draft evidence for the implementation PR description. | Recorded below. |

## Published-spec comparison

Evidence was inspected from [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) and its `main` branch on 2026-11-01. The spec is served by the provider at `GET /api/v1/openapi.json`; it is not committed as a static document in that repository.

The published server schema and renderer differ from `docs/color-matching-api-contract.md` as follows:

- Ranked results are now concrete: the response has `schema_version: "lps-ranked-results/v1"`, capture time/count provenance, scoring-algorithm versions, and per-pair aggregate and current-judgment data. The prose contract only described a desired response in prose.
- The manifest renderer’s printer profile uses fields such as `printer_make_model`, `paper_type`, `ink_type`, and `print_settings`; the prose example used `id`, `name`, `paper`, `ink`, and `settings`.
- Capture creation accepts both the nested `metadata` compatibility shape used by this app and a legacy flat shape. The published schema makes nested metadata an alternative rather than requiring the prose contract’s full nested request; `quality` has no required fields in that schema.
- Measurement uploads accept RGB values as an array, an `{r,g,b}` object, or a JSON string; pair scores accept `score`, `similarity`, or `distance`. The prose contract specified only object RGB and the `distance`/`similarity` pair.
- Several published schemas are intentionally incomplete relative to the actual renderer: manifest declares only `schema_version`, `sheet_id`, and `capture_profile` as required, and ranked results declares only `schema_version` and `sheet_id`. Generation will therefore type those guaranteed fields but cannot make omitted rendered fields compile-time requirements.

## Endpoint gap

All six iOS-relevant paths exist in the provider router/spec: manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results. The current iOS app has no ranked-results call or model; adding the generated operation is in scope, but wiring new ranked-results UI is not.

## Implementation handoff

Vendor a snapshot fetched from the provider endpoint as `iOS/openapi/color-matching.json`, configure `swift-openapi-generator` and `swift-openapi-runtime` in `iOS/Package.swift`, and preserve the small app-facing adapter only where MeasurementCore values need conversion. Update the test fixture assertions to use generated response/request types and add the ranked-results local-stub test before declaring the implementation green.
