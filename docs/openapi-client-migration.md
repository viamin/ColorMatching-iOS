# OpenAPI client migration verification plan

This document is the PR evidence record for #5's test-writing phase. It is based on the `main` revision `47057afd58f7d46b4d4b740ca7d2d08947774471` of [`viamin/color_matching`](https://github.com/viamin/color_matching), which serves its OpenAPI document at `GET /api/v1/openapi.json`.

## Criterion map

| Criterion | Smallest credible verification | Current evidence | Status |
| --- | --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`, and vendor or fetch the document | Inspect `iOS/Package.swift` and the committed spec input; `swift package resolve` confirms the pinned dependencies | Not implemented in this tests-only change | Not run |
| Generate client operations for manifest, recent sheets, capture creation, measurements, judgments, and ranked results | Compile an integration test which invokes each generated operation against `MockURLProtocol` responses | Not implemented; ranked-results has no client method today | Not run |
| Replace server-owned handwritten models while preserving client-only models | Compile production targets and assert the client adapter translates `MeasurementCore` values to generated request bodies | Red test at `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Failed (expected red phase) |
| Exercise generated client against local stubs | Permanent `MockURLProtocol` tests covering all generated operations, including their request/response bodies | Existing stubs cover capture creation, measurements, and judgments; generated client wiring is absent | Not run |
| Record prose-contract deltas and endpoint gaps | This inspectable document, checked against the published OpenAPI source and server controllers | Deltas recorded below | Passed |
| `swift test --disable-sandbox` is green | Run it after generated client integration | Swift is unavailable in this container | Not run |

## Contract deltas found

- The prose contract described a capture request as `{ "metadata": ..., "quality": ... }`. The published spec permits that compatibility form, but also permits a flat request body; its nested `metadata` requires device, lens, image dimensions, app version, and timestamp. `quality` is not required by the schema.
- The prose measurement body included `scoring_algorithm_version` and per-patch `stats`. The published `MeasurementUploadRequest` does not define either. It requires `patch_id`, `linear_rgb_median`, and `normalized_linear_rgb_median` for each measurement.
- The published pair score requires `pair_id`, `algorithm_version`, and one of `score`, `similarity`, or `distance`; the app's existing payload supplies both compatibility score fields.
- The prose contract left ranked-results response fields unspecified. The published API now provides a concrete `lps-ranked-results/v1` envelope with aggregate capture metadata and ranked pair records.
- The current API client has no ranked-results method, so that documented surface is an implementation gap rather than merely a contract drift.

## Red test rationale

`testUploadMeasurementsMatchesPublishedOpenAPISchema` uses the existing local `MockURLProtocol`, not a live service. It fails until the handwritten measurement request is replaced with the generated `MeasurementUploadRequest` shape. It deliberately asserts the server-owned boundary while leaving `ChannelStats` and other measurement-analysis types client-owned.
