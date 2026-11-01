---
module: iOS
tags:
  - openapi
  - swift
  - api-client
problem_type: test-plan
---

# Issue #5 OpenAPI Client: Acceptance Evidence and Contract Delta

This is the tests-only preparation for issue #5. The implementation run must
vendor a snapshot fetched from `GET /api/v1/openapi.json`, generate the Swift
client from that exact snapshot, and replace the hand-written API transport
models. It must not contact a live server in CI.

## Criterion-level verification plan

| Criterion | Smallest credible verification | Status in this run |
| --- | --- | --- |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent `URLProtocol`-backed tests exercise each generated operation with a local response/request fixture. Inspect generated source and `Package.swift` to confirm the generator/runtime and vendored spec are tracked. | Partial: the existing permanent tests cover three writes; `APIClientTests.testFetchRecentSheetsDecodesNullableTitleFromStubbedResponse` adds recent sheets. Manifest/ranked-results generated operations remain implementation work. |
| Replace hand-written API models while retaining client-only models | Compile the app and inspect `ColorMatchingLPSAppCore` for generated API types at its boundary; run the focused tests. | Not run: production edits are prohibited in this test-writing run. |
| No live server in CI | Each API test uses `MockURLProtocol`; inspect test configuration and CI command. | Partial: all tests in `APIClientTests` are local stubs. |
| `swift test --disable-sandbox` green with generated types | Run the command after implementation on a Swift-capable CI/macOS environment. | Not run: this container has no `swift` executable. |
| PR records contract deltas and endpoint gaps | This document is copied/summarized in the implementation PR description, with links to the vendored spec revision. | Recorded below; human review of the actual PR description remains required. |

## Published-spec comparison (checked 2026-11-01)

Source inspected: `viamin/color_matching` issue #110 and its current runtime
OpenAPI publisher at `/api/v1/openapi.json` (the provider repository does not
track a static JSON document).

The published route set includes all required iOS paths:

- `GET /api/v1/test_sheets/{sheet_id}/manifest`
- `GET /api/v1/test_sheets/recent`
- `POST /api/v1/test_sheets/{sheet_id}/captures`
- `POST /api/v1/captures/{capture_id}/measurements`
- `POST /api/v1/captures/{capture_id}/judgments`
- `GET /api/v1/test_sheets/{sheet_id}/ranked_results`

Differences/gaps that the implementation PR must call out:

- The `Manifest` schema only requires `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`, while the actual response and
  current iOS analysis require page geometry, registration markers, patches,
  pairs, and a manifest URL. The new red test
  `APIClientTests.testFetchManifestAcceptsPublishedOpenAPIMinimumResponse`
  demonstrates that the hand-written decoder cannot consume a response valid
  under the published schema. Either expand the provider schema before relying
  on generated manifest types, or explicitly preserve a client-side manifest
  projection with a documented compatibility boundary.
- The `RankedResults` schema only requires `schema_version` and `sheet_id`,
  although the actual renderer returns profile, aggregate counts, score data,
  provenance, and judgments. Generation from the current document will not
  produce typed ranked-result fields for the data described in the prose
  contract.
- `CaptureRequest` permits both the nested `metadata`/`quality` shape in the
  prose contract and a legacy flattened shape. Its metadata requirements make
  image dimensions mandatory, whereas the current Swift `CaptureMetadata`
  treats them as optional.
- The published measurement request does not require
  `scoring_algorithm_version` at the top level and does not model client-side
  measurement statistics; pair scores require an algorithm version and accept
  `score`, `similarity`, or `distance`.
- The published write responses are typed JSON count/identifier objects for
  measurements and judgments; the hand-written client currently discards them
  and accepts any 2xx response.

## Red-phase test note

`testFetchManifestAcceptsPublishedOpenAPIMinimumResponse` is intentionally
red until the generated-client boundary is implemented and the manifest schema
gap is resolved. It uses only a local `URLProtocol` stub and has no live-server
dependency.
