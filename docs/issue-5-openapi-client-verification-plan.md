---
module: ios-api-client
tags: [openapi, swift, contract-testing]
problem_type: verification-plan
---

# Issue #5 generated OpenAPI client verification plan

This is the test-first plan for replacing the iOS companion's hand-written
`APIClient` transport and API DTOs. The provider authority is the OpenAPI 3
document served by `viamin/color_matching` at `/api/v1/openapi.json` (issue
viamin/color_matching#110), not the older prose contract in this repository.

## Criterion map

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Package declares `swift-openapi-generator` and `swift-openapi-runtime` | Focused package-manifest assertion in `APIClientTests.testPackageDeclaresGeneratedOpenAPIClientDependencies` | Red: dependencies are not yet declared. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local-stub unit tests exercising every generated operation and decoding each typed response | Not yet possible: the generated client and the ranked-results operation do not exist. Manifest/recent/capture/measurement/judgment stubs are established now; ranked-results coverage must be added with the generated operation. |
| Hand-written API DTOs are replaced, while measurement-only models remain | Compile the app after migrating the transport boundary; review the generated source and the retained `MeasurementCore` models | Not run: requires implementation. |
| No live server in CI | `URLProtocol`-backed tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Covered for the five currently callable operations. |
| `swift test --disable-sandbox` is green | Run the package suite after generated client wiring | Intentionally red in this test-writing phase because the dependency assertion precedes implementation. |
| PR records prose/spec deltas and endpoint gaps | This document, based on provider `main` at the time of this change | Covered below; implementation PR description must carry it forward. |

The manifest and recent-sheet tests are permanent focused transport tests: they
exercise user-visible sheet selection and capture setup, have no network
dependency, and must remain after regeneration. Existing capture, measurement,
and judgment tests use the same local stub mechanism and remain permanent.

## Provider-contract deltas found

- The published `Manifest` schema presently requires only `schema_version`,
  `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose
  contract describes the full page, markers, patches, pairs, profile, and URL
  payload that the app needs to analyze a sheet. The generator will therefore
  need either an upstream schema expansion or a deliberately retained
  client-side manifest representation. This is a provider-spec gap, not a
  reason to derive sheet geometry from an underspecified generated DTO.
- `RankedResults` currently declares only `schema_version` and `sheet_id`.
  The prose contract also leaves its response intentionally vague, and the app
  does not call the endpoint today. The provider must describe result rows
  before a useful typed ranked-results operation can be wired into the app.
- Capture creation accepts both the prose contract's nested
  `metadata`/`quality` request and a legacy flat request. In the published
  spec, only the metadata form is required by an `anyOf`; `quality` is not
  required. Image width and height are required by `CaptureMetadata`.
- Measurement upload differs substantially: the prose has a root
  `scoring_algorithm_version` and per-measurement statistics, while the spec
  omits both. The spec requires both median RGB fields, accepts RGB arrays,
  objects, or JSON strings, and requires `algorithm_version` on every pair
  score (with score, similarity, or distance accepted).
- The provider documents typed 200 acknowledgment bodies for measurements and
  judgments. The prose does not specify success responses, and the current iOS
  client discards them.
- The prose enumerates capture rejections and judgment values; the published
  spec models both as unconstrained strings. `manifest_url` is also a bare
  string rather than a URI-formatted string.

## Endpoint gap

No endpoint is missing from the six requested surfaces: all appear in the
provider router and OpenAPI paths. The gap is schema completeness for manifest
and ranked results, which blocks a fully useful generated replacement for
those two decoded response types until the provider expands its document.
