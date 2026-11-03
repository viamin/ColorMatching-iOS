---
title: "Issue #5 generated OpenAPI Swift client: PR evidence"
date: "2026-11-03"
module: "iOS API client"
problem_type: "integration"
tags:
  - openapi
  - swift
  - generated-client
  - test-plan
---

# Issue #5 generated OpenAPI Swift client: PR evidence

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in tests-only phase |
| --- | --- | --- |
| Generator/runtime dependencies and vendored or fetched upstream document | `OpenAPIClientAdoptionTests.testPackageDeclaresOpenAPIGeneratorAndRuntime`; implementation review confirms the checked-in spec source and generator plugin target | Red: package dependencies are absent. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `APIClientTests` local `URLProtocol` stubs cover the first five request/response paths; implementation adds the ranked-results adapter test once generated operation/type names exist. | Partial: ranked-results has no current app-facing method. |
| Hand-written API models replaced while client-only models remain | Compile the app target after deleting the legacy transport models; inspect the generated output and adapter boundary. | Not run: implementation-only evidence. |
| Generated client exercised against local stubs | Permanent `APIClientTests` uses `MockURLProtocol`, never a live server. | Partial: discovery, capture, measurements, and judgments are covered; ranked results awaits its adapter. |
| Swift suite green | `swift test --disable-sandbox` from `iOS/`. | Not run: Swift is unavailable in this container. |

## Published-spec evidence and contract deltas

Upstream issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) is closed. Its server exposes the contract at `GET /api/v1/openapi.json`; the checked upstream controller declarations list these operations:

- `GET /api/v1/test_sheets/{sheet_id}/manifest`
- `GET /api/v1/test_sheets/recent`
- `POST /api/v1/test_sheets/{sheet_id}/captures`
- `POST /api/v1/captures/{capture_id}/measurements`
- `POST /api/v1/captures/{capture_id}/judgments`
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results`

Compared with `docs/color-matching-api-contract.md`, the published implementation establishes these material deltas:

- Measurement and judgment uploads return 200 JSON acknowledgments (`capture_id` plus counts), while the prose contract did not specify a response body. The stub tests use those actual 200 response shapes.
- Ranked results are now specified as `lps-ranked-results/v1`, with score aggregates, judgment/capture provenance, printer profile, and scoring-algorithm versions. The prose contract only described this endpoint narratively, without a response schema.
- The manifest's `schema_version` is an enum containing `lps-sheet-manifest/v1`; the published schema requires `schema_version`, `sheet_id`, and `capture_profile`, rather than requiring every field illustrated in the prose example.
- Capture creation accepts two compatible request shapes (nested `metadata`/`quality` and a legacy flat shape). The iOS client should generate from the published schema and use the nested shape currently emitted by the app.
- The published measurement schema accepts compatible RGB and pair-score representations; the app should keep its MeasurementCore-to-generated-request mapping explicit rather than duplicating server API models.

## Endpoint gap

The current `APIClient` has no ranked-results method and the SwiftUI flow ranks locally. The generated-client implementation must expose the published ranked-results operation (with a local-stub regression test), even if the present UI does not invoke it yet.
