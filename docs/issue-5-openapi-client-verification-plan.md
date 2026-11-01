# Issue #5: Generated OpenAPI Client Verification Plan

This is the test-writing-run evidence for #5. Production changes are deliberately
out of scope for this run; the following permanent tests are in place before the
implementation work begins.

| Acceptance criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Add generator/runtime and fetch or vendor the upstream document | Compile the generated client module imported with `OpenAPIRuntime`. | `APIClientTests.testGeneratedOpenAPIClientModuleIsAvailable` is intentionally red until the package dependency and generated target exist. |
| Generate manifest, recent sheets, capture, measurement, judgment, and ranked-results surfaces | One local `URLProtocol` stub per generated operation, asserting request path, auth, payload, and decoded response. | Existing capture, measurement, and judgment stubs plus new manifest/recent-sheet stubs are permanent. Ranked-results needs its generated operation and a complete upstream schema before its fixture can be authored. |
| Replace handwritten API models while retaining client-only models | Compile the app target against generated request/response types; retain `MeasurementCore` analysis models only. | Implementation-run compile evidence required. |
| Test generated client without a live server | Permanent XCTest stubs using `MockURLProtocol`; no host is contacted. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`. |
| Record prose-contract versus published-spec deltas and endpoint gaps | Inspect the published spec served by the upstream application and compare its operations/schemas with `docs/color-matching-api-contract.md`. | Deltas and gaps below; this is external evidence, not a test result. |

## Upstream evidence

`viamin/color_matching#110` was completed by [PR #113](https://github.com/viamin/color_matching/pull/113)
on 2026-10-30. It serves OpenAPI at `GET /api/v1/openapi.json`. The application
builds that document from its route operation definitions, including the test-sheet
and capture controllers. This repository must vendor a fetched snapshot or pin a
retrieval URL/revision during the implementation run; this test-only run does not
add production assets.

## Contract deltas and endpoint gaps

Comparison source: the prose contract in this repository and the upstream #113
operation/schema definitions at commit `05062f5381a6f76413cc2bdf1cb2cc08a1b70ff7`.

- The prose manifest describes a complete page, markers, printer/capture profiles,
  patches, and pairs. The published `Manifest` schema requires only
  `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`.
  It therefore cannot generate the app's currently required `SheetManifest` model
  safely without an upstream schema expansion.
- The prose capture endpoint documents a nested `metadata`/`quality` body and a
  `201 {"capture_id": ...}` response. The published schema accepts either the
  nested body or a legacy flat body; its operation documents `200` with the same
  capture-id response. The generator integration must use the documented `200`
  response and preserve the nested request form.
- The prose measurement endpoint documents a top-level
  `scoring_algorithm_version`, per-measurement `stats`, and a `204` response. The
  published schema documents a `200` response with capture/measurement/score
  counts, requires normalized RGB data, does not specify top-level algorithm
  version or measurement stats, and supports score, similarity, or distance.
- The prose judgment endpoint documents `204`; the published schema documents
  `200` with capture and judgment counts.
- Recent sheets align in shape, including nullable `title`, but the upstream
  schema marks `title` required even when null.
- Ranked results exists as an operation, but its published schema requires only
  `schema_version` and `sheet_id`. It omits the colors, scores, labels, capture
  provenance, printer profile, and scoring-algorithm fields required by the prose
  contract. This is the blocking endpoint gap for a typed ranked-results fixture.

The implementation PR description must carry these deltas forward and state
whether the upstream schema has been expanded before generation.
