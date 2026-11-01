# Issue #5 OpenAPI migration: test plan and contract evidence

This is the red-phase test plan for replacing the hand-written iOS API transport
with a client generated from `viamin/color_matching` issue
[110](https://github.com/viamin/color_matching/issues/110). The provider issue
closed on 2026-10-30 and publishes its contract at `/api/v1/openapi.json`.

## Criterion verification map

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Package includes `swift-openapi-generator` and `swift-openapi-runtime`; spec is fetched or vendored | Inspect `iOS/Package.swift`, generated-source target, and vendored/fetch script at the implementation commit | not_run — implementation phase |
| Generated client covers manifest, recent sheets, capture creation, measurement/judgment uploads, and ranked results | Permanent local-stub integration tests invoke each generated operation and decode its typed response | not_run — the generated target does not exist yet |
| Server API models are generated rather than hand-written | Inspect generated target and confirm the hand-written transport payload/response models are removed; preserve MeasurementCore analysis models | not_run — implementation phase |
| Stubbed Swift tests cover the generated client without a live server | `APIClientTests` uses `MockURLProtocol`; implementation must route every generated operation through it | partially covered — current façade has permanent stubs for the five operations used by the app |
| PR description records prose-versus-spec deltas and endpoint gaps | Human inspection of the PR description against the provider's served OpenAPI document | not_run — no PR is opened in this run |

The permanent user-flow coverage is local and deterministic: it fetches a test
sheet manifest, discovers a recent sheet, creates a capture, and uploads both
measurements and a judgment. The existing app does not call ranked results;
the implementation phase must still generate that operation and add a local
stub test for it because it is an issue deliverable.

## Published-contract deltas for the eventual PR description

Evidence was inspected from the provider's `main` branch router, controller
OpenAPI declarations, and JSON renderer after issue #110 closed.

- The prose contract only describes ranked results in words. The published
  contract supplies a `lps-ranked-results/v1` payload with aggregate capture
  timestamps/counts, scoring algorithm versions, ranked pair records, source
  colors, score aggregates, and latest judgment provenance.
- The prose manifest example models a printer profile as `id`, `name`,
  `paper`, `ink`, and `settings`. The published response uses
  `printer_make_model`, `paper_type`, `ink_type`, `icc_profile`,
  `print_settings`, driver/calibration fields, and notes; no profile `id` is
  rendered in this payload.
- The prose document leaves upload response bodies unspecified and existing
  tests accepted `204`. The published API declares `200` JSON acknowledgements:
  measurement uploads return `capture_id`, `measurement_count`, and
  `pair_score_count`; judgment uploads return `capture_id` and
  `judgment_count`.
- The provider has no endpoint gap for the requested surfaces: its router
  exposes manifest, recent sheets, ranked results, capture creation,
  measurement upload, and judgment upload under `/api/v1`. The iOS UI does
  not currently call ranked results, so adding a generated operation is
  required by this issue but should not change capture/scoring behavior.
