# Generated OpenAPI client PR notes

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Package contains the generator and runtime and has a reproducible input spec | `OpenAPIClientPackageTests.testPackageDeclaresGeneratedClientDependencies` and `testVendoredSpecCoversEveryAppAPIOperation` | Red: dependencies and vendored spec have not been added yet. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local `URLProtocol` stubs for each generated operation, asserting a decoded response or request/response exchange | Partially prepared: `APIClientTests` covers manifest, recent sheets, capture creation, measurements, and judgments. The implementation PR must replace the handwritten client use in these tests and add ranked-results coverage. |
| Handwritten server API models are removed while client-only measurement models remain | Compile the app after changing its adapter to generated operation input/output types | Not runnable in this test-writing PR. |
| No live server is needed | The local `MockURLProtocol` used by `APIClientTests` remains the transport for generated-client tests | Prepared. |
| `swift test --disable-sandbox` is green with generated types wired in | Run the command after the implementation PR adds package dependencies and generated sources | Not runnable in this test-writing PR. |
| Contract deltas are recorded | This document's comparison with the published upstream OpenAPI source | Inspected externally; requires PR-description copy on the implementation PR. |

## Published-spec comparison

Source inspected: `viamin/color_matching` [PR #113](https://github.com/viamin/color_matching/pull/113), merged 2026-10-30. The server generates the document at `GET /api/v1/openapi.json`; it is not committed as a static JSON file. The iOS implementation should fetch that endpoint at a pinned revision or vendor its response as `iOS/OpenAPI/openapi.json` so regeneration is deterministic.

Compared with `docs/color-matching-api-contract.md`:

- Measurement uploads are documented as `204 No Content`, but the OpenAPI schema defines a `200` response containing `capture_id`, `measurement_count`, and `pair_score_count`. The spec does not declare the prose contract's top-level `scoring_algorithm_version` or per-measurement `stats` object. Pair scores instead require `algorithm_version` and permit `score`, `similarity`, or `distance`.
- Judgment uploads are documented as `204 No Content`, but the spec defines a `200` response containing `capture_id` and `judgment_count`.
- Capture creation accepts both the prose contract's nested `metadata`/`quality` shape and a legacy flattened shape. The documented `exposure_duration_seconds` is nested metadata only; the flattened shape calls it `exposure_duration`.
- The prose contract calls the sheet path parameter `sheet_id`; the server tests use a sheet lookup code. Generated operation naming must not make the app assume an opaque database identifier.
- Ranked-results is now a real endpoint with schema version `lps-ranked-results/v1`, but its published schema only requires `schema_version` and `sheet_id`. Its richer fields (`results`, scores, observations, printer profile, and capture provenance) are not machine-described enough to create strongly typed result models. This is an upstream endpoint-schema gap to resolve before replacing any ranked-results model.
- The published manifest schema only requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; it does not fully describe the page, markers, patches, pairs, or printer profile fields the iOS app consumes. This is an upstream schema-completeness gap.

## Implementation handoff

Keep `MeasurementCore` value types (`RGB`, `PatchMeasurement`, `PairScore`, and capture-quality analysis) client-side. Replace only transport DTOs with generated OpenAPI types or a small adapter at the transport boundary. Update the local-stub tests to instantiate the generated client and add a ranked-results response fixture once upstream expands that schema.
