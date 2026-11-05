---
module: ios-api-client
tags: [openapi, swift, generated-client, contract]
problem_type: implementation-plan
---

# Issue #5: generated OpenAPI client verification plan

## Criterion map

| Criterion | Smallest credible verification | Planned permanent evidence |
| --- | --- | --- |
| Generator/runtime dependencies and vendored upstream document | Focused package/spec presence test | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientAdoptionTests.swift:testGeneratedClientInputsAreTrackedInThePackage` |
| Generated operations for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Focused spec-operation test plus URLProtocol stubs for each generated operation | `OpenAPIClientAdoptionTests.swift:testGeneratedClientSpecificationContainsEveryCompanionOperation`; expanded `APIClientTests.swift` |
| Replace server DTOs with generated types while preserving measurement-domain models | Compile-time use of generated operation input/output types in the app-core target | `swift test --disable-sandbox` after implementation |
| Generated client works without a live server | URLProtocol-backed Swift tests that assert requests and decode stubbed responses | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Contract deltas and endpoint gaps | Human-inspectable comparison of the prose contract, upstream PR #113 source, and its served `GET /api/v1/openapi.json` document | This document, “Observed contract deltas” |

The first two tests are intentionally red in the tests-only phase: neither the vendored document nor generator configuration/dependencies exist yet. They must turn green in the implementation run. The existing URLProtocol tests already cover capture creation and the two uploads; that suite needs manifest, recent-sheets, and ranked-results stubs once the generated facade is implemented.

## Observed contract deltas

Comparison source: the local prose contract and `viamin/color_matching` PR [#113](https://github.com/viamin/color_matching/pull/113), merged 2026-10-30 to close upstream issue #110.

- The authority is now a served document at `GET /api/v1/openapi.json`; it is generated at runtime by OpenApiSpex rather than committed as a static upstream artifact. The iOS package should vendor a reviewed snapshot and document its upstream revision/source URL.
- The published `Manifest` schema requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The prose/app require page geometry, registration markers, patches, pairs, `manifest_url`, and `sheet_version`. A generated type based solely on the published schema cannot replace `SheetManifest` safely.
- The published `RankedResults` schema requires only `schema_version` and `sheet_id`; the endpoint runtime tests demonstrate substantially richer fields including results, rank, source colors, score aggregates, capture provenance, printer profile, and judgments. This prevents a useful typed ranked-results client today.
- The capture endpoint accepts both the prose nested `{metadata, quality}` form and a legacy flat capture body. The generated request type must select and exercise the nested form used by iOS.
- The prose measurement body requires a top-level `scoring_algorithm_version` and embeds measurement `stats`. The published schema omits that top-level field and `stats`, requires `normalized_linear_rgb_median`, and allows RGB values as an array, object, or JSON string. The iOS client currently sends an optional normalized value and stats, so this needs a provider-spec decision before strict generated serialization.
- The published upload endpoints define JSON success response bodies (`capture_id` plus counts), whereas the app’s prose contract/current client discard successful upload response bodies.
- The prose capture metadata permits floating-point ISO; the published schema declares ISO as an integer. The current iOS API DTO uses `Float`.

## Endpoint gaps discovered

All six app-used paths are routed and present in the upstream OpenAPI route inventory. The gaps are schema completeness, not missing routes: manifest and ranked-results response schemas are too incomplete for generated typed models, and the measurement-upload request schema does not represent the full iOS payload. These provider changes are required (or must be explicitly accepted as lossy client-side adapter behavior) before the issue’s “replace hand-written API models” exit criterion can be honestly marked complete.
