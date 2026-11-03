# OpenAPI Client Migration: Test Plan and Contract Evidence

This is the criterion-level plan for issue #5. It uses the upstream contract
published by `viamin/color_matching` issue [#110](https://github.com/viamin/color_matching/issues/110), inspected at its closed state on 2026-11-03.

## Acceptance Map

| Criterion | Smallest credible verification | Status in tests-only run |
| --- | --- | --- |
| Add generator/runtime and vendor or fetch the OpenAPI document | `swift package resolve` plus a committed, pinned spec checksum and generated-source compilation | Not run: implementation phase owns package and generated source changes. |
| Generate all six used surfaces | Local-stub XCTest requests for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results, compiled against generated operation/input/output types | Blocked: the present client has no ranked-results operation; the upstream ranked-results schema is insufficient to generate its real result type. |
| Replace hand-written API models | Compile the app against generated models and inspect that API-wire `Codable` declarations are removed while `MeasurementCore` models remain | Not run: implementation phase. |
| Exercise generated client without a live server | `APIClientTests` injects `MockURLProtocol`; every migrated operation receives a fixture response and verifies request path/body/authentication | Partially covered: existing façade has local stubs for five available operations; ranked results awaits its façade/generated type. |
| PR description records contract deltas and endpoint gaps | Inspectable PR body, based on the evidence below | Prepared below; publication needs the implementation PR. |

The important recurring flow is capture upload. Its permanent unit/service coverage is
`iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; it exercises the create,
measurement, and judgment requests through a URL-protocol stub. Manifest discovery
and recent-sheet discovery are covered in the same permanent test target. No
browser/system test is appropriate: the mobile capture UI and a live Phoenix server
are explicitly outside this isolated test setup.

## Published Spec vs. Prose Contract

The upstream OpenAPI endpoint is served at `/api/v1/openapi.json` by
`ColorMatchingWeb.OpenApiController`. Its source and controller test establish the
following relevant paths:

- `/api/v1/test_sheets/recent`
- `/api/v1/test_sheets/{sheet_id}/manifest`
- `/api/v1/test_sheets/{sheet_id}/ranked_results`
- `/api/v1/test_sheets/{sheet_id}/captures`
- `/api/v1/captures/{capture_id}/measurements`
- `/api/v1/captures/{capture_id}/judgments`

There is no missing upstream endpoint for the iOS flow. The app-side endpoint gap is
ranked results: the hand-written `APIClient` does not expose it.

There are material schema deltas that must be resolved before generated types can
replace the hand-written models:

- The prose manifest specifies page, markers, printer profile, patches, and pairs.
  The published `Manifest` OpenAPI schema requires only `schema_version`,
  `sheet_id`, and `capture_profile.scoring_algorithm_version`. The server renderer
  sends the fuller shape, but a generator can only type the published subset.
- The prose ranked-results description calls for source colors, scores, labels,
  capture provenance, printer profile, and algorithm version. The published
  `RankedResults` schema requires only `schema_version` and `sheet_id`, while the
  renderer sends a much richer payload. This prevents generation of useful ranked
  result models.
- The prose measurement request requires a top-level
  `scoring_algorithm_version` and per-measurement `stats`. The published
  `MeasurementUploadRequest` does not define either field. Its pair-score schema
  instead requires `algorithm_version` plus one of `score`, `similarity`, or
  `distance`. The current hand-written client sends the two undocumented fields;
  `testUploadMeasurementsMatchesPublishedOpenAPISchema` is intentionally red until
  the generated-client migration removes that drift.
- The prose declares `iso` as a floating-point value; published `CaptureMetadata`
  declares it as an integer. The published capture request permits either legacy
  flat fields or nested `metadata`; the current app uses the nested form.
- The published spec correctly documents `201` for capture creation and `200` JSON
  response bodies for measurement/judgment uploads. The current API client discards
  the latter response bodies, so generated response types should be retained even
  if the UI does not yet display their counts.

## Implementation-Run Exit Evidence

The implementation PR should add the pinned OpenAPI document, generated source, and
tests for ranked results, then update `tmp/paid-agent-verification.json` with the
actual test results. It must not claim that a broad green suite proves these criteria.
