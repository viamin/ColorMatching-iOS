---
module: ios-api-client
tags: [openapi, swift, code-generation, color-matching]
problem_type: migration-plan
---

# Generated OpenAPI client migration: acceptance plan and contract audit

## Scope

Issue #5 replaces the companion app's hand-written `/api/v1` transport models
with types generated from the OpenAPI document merged by
[viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113).
The implementation must snapshot the response from the provider's
`GET /api/v1/openapi.json` endpoint as
`iOS/Sources/ColorMatchingLPSAppCore/openapi.json`, and bind that document to
the `swift-openapi-generator` plugin. The generated target must depend on
`swift-openapi-runtime`.

## Criterion-to-verification plan

| Criterion | Smallest credible verification | Phase status |
| --- | --- | --- |
| Generator/runtime dependencies and a vendored provider spec | `OpenAPIClientConfigurationTests.testPackageTracksThePublishedSpecAndOpenAPIClientDependencies` checks the package configuration and parses the vendored JSON for all six used paths. | Red: dependencies and spec are not present. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | The same configuration test checks all six path templates. Add generated-client stub tests for each operation once generated symbols exist. | Red: no generated target exists. |
| Hand-written API wire models are removed while client-only measurement models remain | Implementation review of `APIClient.swift` and generated target; compile the app core. | Not runnable until generated symbols and the provider schema gaps below are resolved. |
| Local stubbed Swift tests, with no live provider | Existing `APIClientTests` uses `MockURLProtocol`; `testFetchRecentSheetsDecodesLocalStubResponse` covers the discovery endpoint locally. Expand that fixture suite to invoke each generated operation. | Partially green for the legacy client; generated-client coverage is red. |
| Contract deltas and endpoint gaps recorded | This document, based on the merged provider source at `ColorMatchingWeb.ApiSchemas`, `TestSheetJSON`, and `CaptureController`. | Complete external inspection. |

## Published-spec deltas and gaps

The prose contract is richer than the published schema in ways that prevent a
lossless generated replacement today:

- `TestSheetManifest` in the provider spec requires only `schema_version`,
  `sheet_id`, and `capture_profile.scoring_algorithm_version`. The app needs
  page geometry, markers, patches, and pairs to analyze a sheet. The actual
  renderer returns those fields, but they are not described in OpenAPI.
- `RankedResults` in the provider spec requires only `schema_version` and
  `sheet_id`. The renderer additionally returns printer profile, capture
  provenance, score aggregates, source colors, judgments, and result rows.
  The prose contract calls for this richer response but leaves its exact shape
  unspecified. This endpoint cannot receive useful fully typed generated
  results until the provider schema is expanded.
- Capture creation is more permissive than the prose contract: the published
  schema accepts either legacy flat fields or the nested `metadata` form, and
  does not require `quality` or its nested properties. The app sends the nested
  form with quality data; retain that behavior in generated request mapping.
- The prose contract omits successful response bodies for measurement and
  judgment uploads. The server returns `capture_id` plus `measurement_count` /
  `pair_score_count`, or `judgment_count`; generated response handling must
  accept these bodies rather than assume an empty `204` response.
- Recent-sheet `title` is required-but-nullable in the published schema, which
  agrees with the prose contract. Authentication is bearer-token security in
  the provider operations.

## Implementation handoff

Do not weaken the configuration test. First request a provider-spec amendment
for the manifest and ranked-results response schemas (or record an explicit
temporary adapter exception in the PR). Then vendor the exact JSON response,
add the generator/runtime package dependencies and plugin, regenerate, and
replace only wire models. Preserve `MeasurementCore` types that are strictly
client-side image-analysis domain models. Finally, replace legacy-client calls
in `APIClientTests` with generated-operation calls and use `MockURLProtocol`
fixtures for all six paths; no test may contact a live server.
