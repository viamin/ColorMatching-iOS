---
module: ios-api
tags: [openapi, swift, generated-client, tdd]
problem_type: migration-plan
---

# Generated OpenAPI client migration plan

This document is the run evidence and implementation contract for issue #5. The
published provider contract is served dynamically by `color_matching` at
`GET /api/v1/openapi.json` (viamin/color_matching#110), rather than committed
as a static file. The implementation should vendor a fetched snapshot so client
generation is reproducible in CI.

## Criterion-to-verification map

| Criterion | Smallest credible verification | Current test/evidence |
| --- | --- | --- |
| Generator, runtime, and provider document are wired into the package | Focused package/dependency assertion plus generated-source compile | `APIClientTests.testPackageDeclaresGeneratedOpenAPIClientDependencies` (red until implementation); inspect vendored spec and generated source in review |
| App uses generated types for manifest/recent sheets, capture creation, uploads, and ranked results | Stubbed `URLProtocol` responses and requests through the app API adapter | `APIClientTests.testFetchManifestAndRecentSheetsDecodeStubbedOpenAPIResponses`, existing capture/measurement/judgment tests, and a ranked-results stub test added during implementation |
| Hand-written transport models are removed while MeasurementCore models remain | Compile generated adapter and review diff | Generated-source compile plus review; no client-side MeasurementCore types should be removed |
| No live service is needed in CI | Swift unit tests with `MockURLProtocol` | `APIClientTests` |
| Prose-to-provider contract delta is recorded | Inspectable upstream source/spec evidence | “Contract deltas” below |

The manifest/recent-sheets stub test is deliberately permanent: manifest lookup
and sheet discovery are recurring user flows. Capture creation, measurement
upload, and judgment upload already have permanent stub tests. Ranked-results
coverage must be added as a permanent stub test when its generated operation is
wired into the app adapter; the current red test makes the absent operation
visible without introducing a compile-time reference to a type that does not
exist yet.

## Contract deltas

Compared with `docs/color-matching-api-contract.md`, the published provider
contract and its backing source reveal these differences:

- The provider supplies `lps-ranked-results/v1` with aggregate result fields;
  the prose only described ranked results informally and the iOS client exposes
  no ranked-results operation today.
- `POST /captures/:capture_id/measurements` responds `200` with
  `capture_id`, `measurement_count`, and `pair_score_count`; the prose assumes
  an empty successful response. Generated code must decode or deliberately
  discard that response.
- Capture creation accepts either the historical flat capture shape or the
  prose document's nested `metadata` form. The nested `quality` object is
  documented but not required by the provider schema.
- Provider `CaptureMetadata` requires `image_width` and `image_height`; the
  prose presents them as ordinary fields and the present iOS `CaptureMetadata`
  makes them optional. The adapter needs an explicit policy before sending a
  capture without dimensions.
- Provider measurement rows require both `linear_rgb_median` and
  `normalized_linear_rgb_median`; the client-side normalized median is
  optional. The generated adapter needs an explicit validation/error path for
  an absent normalized value.
- The provider permits `score`, `similarity`, or `distance` per pair score;
  the current client sends both compatibility fields. The implementation must
  choose the generated union-compatible representation.
- The spec's manifest schema validates only a compatibility subset, while the
  actual JSON renderer supplies the richer geometry payload currently consumed
  by `MeasurementCore`. A generated model may therefore need a narrow
  generated-to-client-side manifest mapper rather than replacing geometry
  models that are purely client-side.

## Endpoint gap

All five requested API surfaces are present in the provider router/spec:
manifest, recent sheets, capture creation, measurement upload, judgment upload,
and ranked results. The gap is local: ranked results are neither modeled nor
called by `ColorMatchingLPSAppCore.APIClient`.
