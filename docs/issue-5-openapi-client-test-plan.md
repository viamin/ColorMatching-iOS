# Issue #5: generated OpenAPI client verification plan

This document is the run evidence and acceptance-criterion map for the
test-writing phase of #5. It is intentionally limited to the public behavior
the generated client adapter must preserve; generated type spelling is owned by
the checked-in OpenAPI generation configuration.

## Verification map

| Criterion | Smallest credible verification | Planned evidence |
| --- | --- | --- |
| Add the generator, runtime, and published OpenAPI document | Inspect the package manifest, generation target, and vendored/fetched spec. This is a source/configuration criterion, not settled by an HTTP stub. | Human/source review at implementation PR head. |
| Generate the manifest, recent sheets, capture, measurement, judgment, and ranked-results surfaces | Stub each app-used operation through the public adapter. Assert method/path/authentication and require response decoding for read operations. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` tests. |
| Replace hand-written API models while retaining client-only models | Inspect imports and generated-type usage; verify measurement/scoring behavior stays in `MeasurementCore`. | Human/source review at implementation PR head. |
| Generated client works without a live server | Run the focused XCTest target using `MockURLProtocol`; every response is supplied in-process. | `APIClientTests`; implementation run must execute `swift test --disable-sandbox`. |
| Record contract deltas and endpoint gaps | Compare the prose contract with the published spec and renderer at a pinned upstream revision. | Contract delta record below and implementation PR description. |

The permanent focused tests are preferable to an ephemeral integration test:
the app will keep using these API operations, and their wire compatibility is a
recurring regression risk.

## Contract comparison evidence

Compared on 2026-11-04 against `viamin/color_matching` `main`
(`47057afd58f7d46b4d4b740ca7d2d08947774471`), issue
[viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110),
and the served-spec route in `ColorMatchingWeb.Router`.

- The published API adds `GET /api/v1/test_sheets/:sheet_id/ranked_results`.
  The prose contract already reserved this endpoint but did not specify its
  response schema. The server response uses `lps-ranked-results/v1`, aggregate
  scores, capture provenance, and optional judgment observations.
- The published manifest schema requires only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; the response renderer currently
  emits the richer page, markers, printer profile, patches, and pairs used by
  the iOS app. The implementation must preserve decoding of that richer
  response and should treat the spec's underspecification as a server contract
  gap to report in the PR description.
- The published `CaptureMetadata` marks `image_width` and `image_height` as
  required (in addition to device, lens, app version, and timestamp). The
  prose contract presents the camera metadata fields but does not mark their
  requiredness. The generated request construction must always provide the
  required dimensions.
- The server's `CaptureRequest` accepts both a legacy flat representation and
  the nested `metadata`/`quality` representation used by this app. The prose
  contract documents only the nested representation; the iOS client must keep
  emitting it.
- The spec's declared `RankedResults` and `Manifest` schemas are materially
  less detailed than the server's emitted JSON. No endpoint used by the iOS app
  is absent, but these response-schema omissions prevent fully typed access to
  all rendered fields until the server specification is expanded.

## Red-phase status

`testFetchesRankedResultsFromStubbedOpenAPIResponse` deliberately references
the missing `APIClient.fetchRankedResults` adapter. It exposes the endpoint
coverage gap before the implementation phase. The other tests establish the
stubbed local-response contract that the generated client integration must
continue to satisfy.
