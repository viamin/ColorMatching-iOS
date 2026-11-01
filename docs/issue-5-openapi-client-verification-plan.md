# Issue #5 OpenAPI Client Verification Plan

This is the red-phase test plan for replacing the hand-written iOS API layer.
The source of truth is the OpenAPI 3 document served by
`viamin/color_matching` at `/api/v1/openapi.json` (published by
viamin/color_matching#110 and merged in viamin/color_matching#113).

## Criterion map

| Criterion | Smallest credible verification | Location / current result |
| --- | --- | --- |
| Generated package dependencies and vendored contract cover each app API surface | Focused Swift contract test validates the `swift-openapi-generator` and `swift-openapi-runtime` dependencies plus all six required paths in the vendored OpenAPI document. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testGeneratedOpenAPIClientHasVendoredContractForEveryAppSurface` — intentionally failing until implementation lands. |
| Generated client sends and decodes API requests without a live server | Permanent focused Swift tests use `MockURLProtocol` stubs for capture creation, measurement upload, and judgment upload. The implementation run must migrate these to generated operations and add manifest, recent-sheets, and ranked-results generated-operation stubs. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` — existing handwritten-client coverage; generated-client coverage not yet runnable. |
| Contract-delta record is inspectable | This document records the upstream spec comparison below. | This file — complete as external/spec evidence, pending implementation disposition. |
| `swift test --disable-sandbox` is green | Run the command after package generation and generated-client tests are wired. | Not run as green in this red phase; the new criterion test intentionally fails before implementation. |

## Published-spec deltas

Comparison source: the contract in `docs/color-matching-api-contract.md` and
the server's merged OpenAPI schema modules at commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f`.

- The manifest schema publishes only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version` as required/properties. The
  prose contract and current `SheetManifest` decoder require page geometry,
  registration markers, patches, pairs, `sheet_version`, and `manifest_url`.
  This blocks direct replacement for capture analysis unless the server spec is
  expanded or the app deliberately treats the manifest as a client-side
  extension.
- Ranked-results is now an actual documented GET endpoint, but its published
  response exposes only `schema_version` and `sheet_id`. The prose contract
  promised source colors, scores, labels, capture provenance, printer profile,
  and scoring-algorithm version. The app currently ranks locally and has no
  API method for the endpoint.
- Capture creation accepts either legacy flat fields or the iOS nested
  `metadata`/`quality` shape. `metadata` requires device, lens, dimensions,
  app version, and timestamp; the prose contract did not state these as server
  requirements.
- Measurement upload now documents a `200` JSON acknowledgement containing
  capture and row counts, rather than the prose contract's undocumented empty
  response. Its generated schema requires normalized RGB median values, while
  the current app model permits them to be absent. It also describes RGB as an
  array, object, or JSON string and does not document the current `stats` or
  top-level `scoring_algorithm_version` fields.
- Judgment upload now documents a `200` JSON acknowledgement with capture and
  judgment counts; the prose contract did not specify a response.
- Recent sheets matches the prose response shape, including nullable `title`.

## Implementation handoff

Vendor the fetched document at `iOS/OpenAPI/openapi.json`, generate a target
using `swift-openapi-generator`, and use `swift-openapi-runtime` with a local
stub transport in the permanent tests. Keep measurement/scoring structures in
`MeasurementCore` when they are local analysis models; convert them only at
the generated-client boundary. Resolve the manifest and ranked-results schema
gaps with the server owner before removing the existing rich manifest model.
