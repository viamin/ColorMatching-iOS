# Issue #5 generated OpenAPI client: test plan and contract deltas

This is the tests-only preparation for the generated-client implementation.
The upstream authority is `viamin/color_matching#113`, which closed
`viamin/color_matching#110` and serves its OpenAPI 3 document at
`GET /api/v1/openapi.json`.

## Criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Generated client and runtime are package dependencies; document is vendored or fetched reproducibly | Review `iOS/Package.swift` and the checked-in OpenAPI document after implementation; compile `swift test --disable-sandbox` | Not implemented in this phase |
| Generated types cover manifest/recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local-stub XCTest exercises each generated operation and decodes its typed result | Manifest/recent/capture/measurement/judgment fixtures exist in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; ranked results is blocked by the upstream schema gap below |
| Hand-written API models are replaced while client-only models remain | Compile plus a source review of the generated target boundary | Not implemented in this phase |
| No-live-server client tests | Permanent XCTest using `MockURLProtocol` | Existing and expanded tests are runnable locally; generated-client wiring awaits implementation |
| PR describes contract deltas and endpoint gaps | This document, copied/summarized into the implementation PR description | Recorded below |

## Published-spec deltas from the prose contract

- The published `CaptureRequest` accepts both the prose contract's nested
  `metadata` form and a legacy flattened form. Its schema requires only one
  of those alternatives; the nested `quality` object's fields are not marked
  required.
- `MeasurementUploadRequest` no longer documents
  `scoring_algorithm_version` or measurement `stats`. It accepts RGB as an
  array, channel object, or JSON string, and requires each pair score to use
  `score`, `similarity`, or `distance` alongside `pair_id` and
  `algorithm_version`.
- Measurement and judgment uploads specify JSON `200` responses containing
  counts; the prose contract expected empty `204` responses.
- The manifest schema makes only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version` required. The application still
  needs the richer layout fields described by the prose contract.

## Endpoint gap

`GET /api/v1/test_sheets/{sheet_id}/ranked_results` exists in the published
paths, but its `RankedResults` response specifies only `schema_version` and
`sheet_id`. It omits the source colors, scores, labels, capture provenance,
printer profile, and scoring-algorithm version promised by the prose
contract. Do not add a concrete ranked-results generated-client test until
the upstream spec defines those fields; record this in the implementation PR
description as an upstream contract gap.
