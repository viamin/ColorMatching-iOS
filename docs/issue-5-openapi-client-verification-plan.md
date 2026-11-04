---
module: ios-api-client
tags: [openapi, generated-client, testing]
problem_type: test-plan
---

# Issue #5 generated OpenAPI client verification plan

This is the criterion-level plan for replacing the hand-written iOS API layer.
It deliberately uses local `URLProtocol` fixtures: no test contacts a Phoenix
server.

| Criterion | Smallest credible verification | Evidence at this head |
| --- | --- | --- |
| Package obtains `swift-openapi-generator` and `swift-openapi-runtime`, and vendors/fetches the upstream document | Package-resolution build plus a checked-in spec provenance/revision | Not yet implemented; implementation run must add this evidence. |
| Generated client covers manifest, recent sheets, capture creation, measurements, judgments, and ranked results | Permanent API-client tests send every operation through a local stub and assert response decoding/request encoding | `APIClientTests` currently covers the first five operations. Ranked-results has no app client surface yet, so it is intentionally red/absent until implementation adds it. |
| Server models are generated and client-only models remain local | Compile the app after removing the manual transport DTOs; focused tests compile against generated operation inputs/outputs | Not yet implemented. |
| No live server is needed in CI | Permanent `URLProtocol` tests, run with `swift test --disable-sandbox` | `APIClientTests` uses `MockURLProtocol`; this environment has no Swift toolchain, so execution is not run here. |
| PR records contract/spec deltas and endpoint gaps | Inspect the upstream OpenAPI source and document the result in the PR description | Deltas below, based on `viamin/color_matching` main at issue #110's closed state (2026-11-04). |

## Contract deltas to include in the implementation PR description

- The published `CaptureRequest` supports legacy flat fields or a nested
  `metadata` object. For nested requests, the schema does not require
  `quality`; the companion currently sends it.
- Published `CaptureMetadata` requires `image_width` and `image_height`, while
  the prose contract and current Swift model allow them to be absent.
- Published measurement uploads require both `linear_rgb_median` and
  `normalized_linear_rgb_median`; the current Swift model makes the normalized
  value optional. The published request schema does not declare the prose
  contract's `scoring_algorithm_version` or per-measurement stats.
- Published pair scores require `pair_id`, `algorithm_version`, and one of
  `score`, `similarity`, or `distance`; the current payload's similarity and
  distance are accepted compatibility forms.
- Published write endpoints return JSON summary objects with HTTP 200; the
  prose contract omitted responses and the previous tests used 204.
- The ranked-results route exists, but its schema guarantees only
  `schema_version` (`lps-ranked-results/v1`) and `sheet_id`. Its result rows,
  labels, provenance, printer profile, and score fields are an endpoint gap
  that needs server-spec expansion before strongly typed app rendering is safe.

## Test fixture provenance

The local fixtures match the routes and response envelopes declared by
`ColorMatchingWeb.TestSheetController`, `ColorMatchingWeb.CaptureController`,
and `ColorMatchingWeb.ApiSchemas` on upstream `main`. They are not a substitute
for vendoring the served `/api/v1/openapi.json` in the implementation change.
