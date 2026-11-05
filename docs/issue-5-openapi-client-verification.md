---
module: ios-api-client
tags: [openapi, swift, contract-testing]
problem_type: verification-plan
---

# Issue #5: OpenAPI Client Verification Plan

## Criterion mapping

| Criterion | Smallest credible verification | Current red-phase evidence |
| --- | --- | --- |
| The package contains the OpenAPI generator/runtime and a fetched or vendored upstream document. | Inspect `iOS/Package.swift` plus the vendored document and generated-source build input. | Not yet implemented; implementation run must add a compile/build check. |
| Generated operations cover manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results. | Focused Swift tests against `MockURLProtocol`, one local response/request assertion per operation. | `APIClientTests.swift` covers the existing manifest/recent/capture/measurement/judgment facade. Ranked results has no iOS operation yet. |
| App network models are generated rather than hand-written. | Compile the app after removing API transport DTOs; inspect generated client target source. | Not yet implemented. |
| Generated client works with local stubbed responses and no live server. | Permanent Swift unit/service tests using `MockURLProtocol`; no remote URL is contacted by tests. | `testFetchRecentSheetsDecodesPublishedResponseFromLocalStub` passes. `testFetchManifestAcceptsMinimumPublishedOpenAPISchemaFromLocalStub` is intentionally red. |
| The PR records contract deltas and endpoint gaps. | Inspect this document against the upstream source modules and upstream PR #113. | Recorded below from `color_matching` main on 2026-11-05. |

## Published-contract deltas and gaps

Upstream PR [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113) closed dependency [#110](https://github.com/viamin/color_matching/issues/110) and serves its document from `GET /api/v1/openapi.json`.

- The OpenAPI `TestSheetManifest` schema requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The prose contract and the current app require sheet/page geometry, registration markers, patches, pairs, and a manifest URL. The new local-stub test uses the valid minimum OpenAPI payload; it currently fails because `SheetManifest` still requires the prose-only fields. The upstream spec must describe the full payload before a generated client can safely preserve capture behavior.
- The OpenAPI `RankedResults` schema requires only `schema_version` and `sheet_id`; the prose contract requires source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version. The iOS client has no ranked-results operation today, so this is an endpoint/schema gap, not a behavior change to implement speculatively.
- The published measurement schema requires `normalized_linear_rgb_median`, permits RGB arrays, RGB objects, or JSON strings, and omits both the prose contract's `stats` payload and its top-level `scoring_algorithm_version`. Pair scores retain `algorithm_version` and allow `score`, `similarity`, or `distance`. The generated-client adapter needs an agreed canonical shape before replacing the current DTO.
- The published capture request supports both the nested prose shape (`metadata`/`quality`) and a flattened compatibility shape. The current nested request is therefore compatible, subject to generation preserving that branch of the `anyOf` request schema.

## Implementation handoff

Do not make the red manifest test pass by weakening it or by silently retaining hand-written wire DTOs. First obtain an upstream OpenAPI expansion for the app's required manifest and ranked-results fields (or explicit approval to make those fields optional in the app). Then vendor or fetch the exact document, generate the narrow client target, migrate the facade, and add an operation-level stub test for ranked results.
