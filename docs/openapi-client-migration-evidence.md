---
module: "iOS"
tags:
  - "openapi"
  - "swift"
  - "api-client"
problem_type: "test_plan"
---

# OpenAPI Client Migration Evidence

## Acceptance-Criterion Plan

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Package contains `swift-openapi-generator` and `swift-openapi-runtime`, with the server document vendored or fetched | Inspect `iOS/Package.swift`, the checked-in OpenAPI input, and generated-target build | Deferred to implementation: package and OpenAPI input do not yet exist. |
| Generated operations cover manifest, recent sheets, capture creation, measurement and judgment upload, and ranked results | Local `URLProtocol` stubs invoke each generated operation and assert request path, authorization, body, and typed response | `APIClientTests` now covers the manifest and recent-sheet reads and all three write request shapes. Ranked results has no iOS operation yet, so it remains an implementation blocker. |
| Handwritten API models are replaced while client-only models remain | `swift test --disable-sandbox` plus compilation after handwritten transport models are removed | Deferred to implementation. |
| Generated client runs against local stubbed server responses | Permanent `URLProtocol` tests; no live server or credentials | `APIClientTests` use only `MockURLProtocol`. The implementation must route these tests through generated operations. |
| PR records prose-contract deltas and endpoint gaps | Inspect this evidence and the PR body against the published OpenAPI schema | This document supplies the PR-body facts below; human review verifies the final PR body. |

## Published-Spec Comparison (2026-11-04)

Source inspected: `viamin/color_matching` issue #110 and its current `ColorMatchingWeb.ApiSchemas` and API controllers.

- The published API includes `GET /api/v1/test_sheets/:sheet_id/ranked_results`, with `lps-ranked-results/v1`; the prose contract described it but did not provide a response object. The iOS client has no ranked-results operation.
- Measurement and judgment uploads return typed JSON acknowledgements with `capture_id` and count fields at `200 OK`. The prose contract omitted responses and the old tests assumed `204 No Content`.
- The published measurement schema requires both `linear_rgb_median` and `normalized_linear_rgb_median`, and requires a per-pair `algorithm_version`; the prose contract additionally described a top-level `scoring_algorithm_version` and measurement `stats`, neither required by the published schema.
- The published capture schema accepts the old nested `metadata`/`quality` compatibility shape but also exposes a flat capture request form. Generated request construction must select the published schema form deliberately rather than preserving the handwritten encoding by accident.
- The manifest schema makes `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` machine-visible requirements. The existing client-only `SheetManifest` lacks `capture_profile`; retain client-only analysis types behind an explicit mapping from generated transport types.

## PR Description Draft

Replace the handwritten `/api/v1` transport layer with a Swift OpenAPI-generated client, vendored from the server's published OpenAPI document. Map generated manifest and capture transport types to the existing client-only measurement/analysis models.

Contract deltas: ranked results is now a typed `lps-ranked-results/v1` response (previously only prose, and absent from the iOS client); measurement and judgment uploads return `200` JSON acknowledgements; the published measurement schema requires normalized RGB and per-pair algorithm versions; and capture requests expose both legacy nested and flat shapes. The implementation must decide the generated request shape and surface validation for measurements lacking normalized RGB.

Endpoint gap: add the generated ranked-results operation to the app integration. It is specified by the server but unused by the current iOS `APIClient`.
