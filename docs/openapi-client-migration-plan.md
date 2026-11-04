# OpenAPI client migration: verification plan and contract deltas

Source inspected 2026-11-04: `viamin/color_matching` commit
`47057afd58f7d46b4d4b740ca7d2d08947774471`, whose application serves its
OpenAPI document at `GET /api/v1/openapi.json` (issue
[`viamin/color_matching#110`](https://github.com/viamin/color_matching/issues/110)).

## Criterion-level verification plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Package contains generator/runtime and a vendored or fetched specification | Inspect `iOS/Package.swift` and the pinned specification source in the implementation PR. | Not run: implementation is intentionally out of scope for this test-writing run. |
| Generated client covers manifest, recent sheets, capture creation, measurement and judgment uploads, and ranked results | Permanent local-`URLProtocol` Swift tests exercise every generated operation with published-spec response fixtures. | Partial: manifest and recent-sheet fixtures are added in `APIClientTests`; ranked-results and generated-operation coverage await the generated module. |
| Hand-written transport types are replaced while client-side measurement models remain | Compile the app and inspect the generated-model imports versus `MeasurementCore` ownership. | Not run: requires implementation. |
| Generated client is tested without a live server | Run `swift test --disable-sandbox`; the test target must use local stubbed `URLProtocol` responses only. | Blocked in this environment: the Swift toolchain is unavailable. |
| PR documents contract deltas and endpoint gaps | This file and the implementation PR description cite the upstream spec commit and enumerate deltas/gaps below. | Recorded. |

The permanent regression rule introduced in this change is
`APIClientTests.testUploadMeasurementsRejectsMalformedPublishedAcknowledgement`.
It intentionally fails against the current hand-written client: it accepts a
`200` measurement response that omits the required acknowledgement counts. A
generated `MeasurementUploadResponse` must decode that response and reject it.

## Deltas from `docs/color-matching-api-contract.md`

- The published OpenAPI schemas model only a minimal required subset of the
  rich manifest and ranked-results payloads. The server currently renders more
  fields than the specification requires; a generated client therefore needs
  to tolerate that broader runtime payload while following the spec's required
  fields.
- Ranked results are now a concrete endpoint with the
  `lps-ranked-results/v1` schema version. The prose contract named the route
  but did not define its response schema.
- Capture creation accepts both the prose contract's nested `metadata` plus
  `quality` shape and a legacy flattened form. Its metadata schema requires
  image dimensions, and defines `iso` as an integer rather than the current
  Swift hand-written `Float`.
- Measurement uploads no longer specify the prose-only top-level
  `scoring_algorithm_version` or per-measurement `stats`. They require
  `normalized_linear_rgb_median`; each pair score requires an
  `algorithm_version` plus one of `score`, `similarity`, or `distance`.
- Measurement and judgment uploads return `200` JSON acknowledgements with
  `capture_id` and counts. The prose contract omitted responses, and the
  hand-written client currently discards them.
- Recent sheets still preserve the nullable `title` and manifest URL fields.

## Endpoint gaps to resolve in implementation

- The app has no ranked-results API method or view integration despite the
  published route. Add a generated operation and stubbed response test before
  claiming full surface coverage.
- The upstream OpenAPI document is served dynamically rather than committed as
  a static JSON file. The implementation must pin a fetched copy (with source
  commit/URL and refresh instructions) or use a reproducible fetch step so a
  regeneration diff is reviewable.
