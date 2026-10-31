# Issue #5 OpenAPI client verification plan

This is the test-writing phase for #5. The generated client and its vendored
document do not exist in this revision; the specification-presence test is
therefore intentionally red until the implementation phase vendors the
published `color_matching` document at `iOS/OpenAPI/color-matching-api.json`.

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Package uses `swift-openapi-generator` and `swift-openapi-runtime`; published spec is vendored | Inspect `iOS/Package.swift`, the vendored JSON, and generated source at PR head | Implementation-phase external/inspectable evidence required |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `OpenAPIContractTests.testVendoredSpecificationDefinesEveryCompanionAppOperation` asserts the six consumed route templates in the vendored server spec | Red until the document is vendored |
| Hand-written transport models are replaced while client-only measurement models remain | Inspect generated source and app-facing adapter at PR head; preserve the transport-stub tests below | Implementation-phase inspectable evidence required |
| Generated client works against local responses | `APIClientTests` uses `MockURLProtocol`, never a live server. Existing write tests cover capture, measurements, and judgments; new tests cover manifest and recent sheets. Add ranked-results response coverage when its generated operation is wired into the app facade. | Stub tests are permanent; execution blocked here because `swift` is absent |
| PR records contract deltas and endpoint gaps | This document records the upstream comparison below; copy its findings into the implementation PR description after confirming the vendored revision | Human review of the PR description |

## Published-spec comparison

Source reviewed: the closed upstream issue
[`viamin/color_matching#110`](https://github.com/viamin/color_matching/issues/110)
and the `main` branch controller/schema sources it publishes through
`GET /api/v1/openapi.json` (reviewed 2026-10-31).

The server has every route this companion needs. Its current generated OpenAPI
shapes differ from `docs/color-matching-api-contract.md` in these ways:

- The manifest and ranked-results schemas declare only a small required subset.
  The manifest schema requires `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; ranked results requires only
  `schema_version` and `sheet_id`. The richer fields the app needs are emitted
  by the server renderer but are not modeled in the published schema, so a
  direct generated model would discard or fail to expose them.
- `CaptureRequest` accepts either the prose document's nested `metadata` form
  or a legacy flat form. It does not require `quality`, does not enumerate
  rejection reasons, and makes `iso` an integer rather than the companion's
  current `Float`.
- The measurement schema omits the prose contract's top-level
  `scoring_algorithm_version` and per-measurement `stats`; it accepts RGB
  arrays, RGB objects, or JSON strings. Pair scores allow `score`,
  `similarity`, or `distance`, provided `algorithm_version` is present.
- Measurement and judgment uploads return JSON count summaries in the server
  spec, while the prose contract left their success bodies unspecified and the
  current client discards them.
- The prose contract describes ranked-results content only narratively. The
  server renderer includes aggregate timestamps/counts, printer profile,
  algorithm versions, score statistics, and latest judgments, but the current
  published schema does not model those fields.

The implementation PR must either coordinate schema enrichment upstream or
use an explicitly reviewed adapter for these under-specified response fields;
generation alone cannot provide typed access to fields absent from the OpenAPI
schema.
