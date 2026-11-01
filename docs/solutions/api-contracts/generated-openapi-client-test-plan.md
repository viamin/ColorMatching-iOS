---
title: "Generated OpenAPI client test plan and contract gaps"
date: "2026-11-01"
category: "api-contracts"
module: "iOS"
problem_type: "contract_drift"
component: "API client"
tags:
  - "openapi"
  - "swift"
  - "api-client"
  - "contract-testing"
---

# Generated OpenAPI client test plan and contract gaps

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Phase status |
| --- | --- | --- |
| Generated Swift client dependencies and vendored/fetched spec | `Package.swift` resolves `swift-openapi-generator` and `swift-openapi-runtime`; generation runs from the checked-in OpenAPI document. | Not implemented in this tests-only run. |
| Generated types replace server-owned handwritten models | Compile the app and tests after removing server-owned duplicate Codable declarations; preserve only measurement-domain models. | Not implemented in this tests-only run. |
| Manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent XCTest coverage through `URLProtocol` local stubs, asserting route/method/request shape and typed response decoding for each operation. Existing stubs cover the three writes; this run adds read stubs for manifest and recent sheets. Ranked results awaits the generated operation/type surface. | Partial red-phase coverage. |
| No live server in CI | Each client test configures `URLSessionConfiguration.protocolClasses` with `MockURLProtocol`; no test uses a network URL session. | Covered by `APIClientTests`. |
| Prose-contract deltas and endpoint gaps recorded in PR | Compare the vendored spec against `docs/color-matching-api-contract.md`, then include the result in the implementation PR description with the upstream revision. | External evidence gathered; implementation PR still required. |

## Upstream evidence and contract deltas

The upstream dependency `viamin/color_matching#110` is closed. Its issue states that the OpenAPI document is served at `GET /api/v1/openapi.json`. The checked upstream `main` revision used for this review was `47057afd58f7d46b4d4b740ca7d2d08947774471` on 2026-11-01.

All six iOS routes exist in the upstream router/spec surface:

- `GET /api/v1/test_sheets/recent`
- `GET /api/v1/test_sheets/{sheet_id}/manifest`
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results`
- `POST /api/v1/test_sheets/{sheet_id}/captures`
- `POST /api/v1/captures/{capture_id}/measurements`
- `POST /api/v1/captures/{capture_id}/judgments`

The published schema does not yet describe all fields that the iOS app consumes from the prose contract. In particular, `Manifest` requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; it omits required declarations for geometry, markers, patches, pairs, sheet version, and manifest URL. `RankedResults` requires only `schema_version` and `sheet_id`, despite the server rendering ranking, source colors, score aggregates, capture provenance, printer profile, and judgments. A generated client can therefore expose these responses only as underspecified types until upstream expands these schemas.

There are also request-shape differences to resolve before replacing models:

- The prose capture payload nests camera fields in `metadata` and quality fields in `quality`; upstream allows that form but also permits a legacy flat form.
- The prose measurement upload requires a top-level `scoring_algorithm_version` and per-measurement statistics. Upstream's `MeasurementUploadRequest` does not declare either; it instead requires per-score `algorithm_version` and allows RGB in several compatibility formats.
- The prose contract lists bounded judgment and capture-rejection values. Upstream currently models them as unconstrained strings.

The implementation PR must vendor a revision-pinned document, generate against it, and state whether upstream schema expansion is landed before claiming the app no longer depends on the prose-only fields.

## Prevention

Keep the local-stub tests permanent: they give fast, deterministic verification of the generated transport and generated typed decoding without a Phoenix service in CI. Regenerate the checked-in client whenever the pinned spec changes and review the resulting diff alongside these operation-level tests.
