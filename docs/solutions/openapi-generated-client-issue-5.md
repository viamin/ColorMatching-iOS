---
title: "Generated OpenAPI client issue #5 test plan"
date: "2026-11-05"
category: "testing"
module: "iOS"
problem_type: "test_plan"
tags:
  - "openapi"
  - "api-client"
  - "testing"
---

# Generated OpenAPI client: issue #5 test plan

## Criterion-to-verification map

| Criterion | Smallest credible verification | Location/status in this tests-only PR |
| --- | --- | --- |
| Generated client serves manifest and recent-sheet reads | Permanent local-stub service tests assert HTTP method, path, auth, and decoded response | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testFetchManifest…`, `testFetchRecentSheets…`); runnable now |
| Generated client serves capture creation and uploads | Permanent local-stub service tests assert request JSON and published `200` response envelopes | `APIClientTests.swift` (`testCreateCapture…`, `testUploadMeasurements…`, `testUploadJudgments…`); runnable now |
| Generated client serves ranked results | Permanent local-stub service test once the generated operation/type names exist | Not runnable in this tests-only commit: the current handwritten `APIClient` exposes no ranked-results method. The implementation PR must add this before claiming the criterion passed. |
| Handwritten transport models are replaced | Inspectable implementation review: generated target and checked-in/fetched OpenAPI source; compile against generated request/response types | Not runnable in this tests-only commit |
| Contract deltas and endpoint gaps are recorded | Inspectable PR description, backed by the upstream published spec/controller source | See findings below; human/external evidence required |

## Published-contract findings for the implementation PR description

- The upstream spec is served from `GET /api/v1/openapi.json` and has routes for all six app surfaces, including `GET /api/v1/test_sheets/:sheet_id/ranked_results`.
- The prose contract incorrectly documents measurement and judgment uploads as `204` with no response. The published API returns `200` JSON envelopes with `capture_id` and row counts.
- Capture IDs are documented by the API as strings, though the server currently serializes its numeric IDs to strings.
- The prose contract describes ranked results as carrying source colors, scores, labels, capture provenance, printer profile, and algorithm version. The published OpenAPI `RankedResults` schema currently guarantees only `schema_version` (`lps-ranked-results/v1`) and `sheet_id`. Treat the richer ranked-result fields as an endpoint contract gap until the server spec is expanded.

## Scope notes

The tests deliberately use `URLProtocol` stubs; they make no live-server calls and are permanent regression coverage for the app's API boundary. They test behavior rather than generated implementation details, so the implementation can replace the transport layer without changing app behavior.
