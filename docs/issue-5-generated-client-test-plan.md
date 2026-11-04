# Issue #5 generated-client verification plan

This test-writing change establishes local-stub coverage for the API calls the
iOS UI currently makes. It does not call a live Phoenix instance.

| Acceptance criterion | Smallest credible verification | Status in this phase |
| --- | --- | --- |
| Generated client/runtime and vendored or fetched spec | Inspect `iOS/Package.swift`, generated sources, and committed spec snapshot after implementation | Not run — implementation phase owns package/source changes |
| Typed manifest and recent-sheet retrieval | `APIClientTests.testFetchManifestDecodesPublishedSheetResponse` and `testFetchRecentSheetsDecodesNullableTitles` with `MockURLProtocol` | Not run — the environment has no Swift toolchain; retain while routing through generated operations |
| Typed capture, measurements, and judgments | Existing three `APIClientTests` transport tests with `MockURLProtocol` | Not run — the environment has no Swift toolchain; retain while routing through generated operations |
| Typed ranked results | Local-stub test added with the generated operation after the endpoint response schema is completed | Blocked by an endpoint-schema gap described below |
| No live server in CI | The cited tests install `MockURLProtocol` in an ephemeral `URLSessionConfiguration` | Inspectable by code; execution not run because the environment has no Swift toolchain |
| Contract delta record | This document and the implementation PR description | External evidence recorded; final PR wording remains implementation work |

## Published-spec comparison (checked 2026-11-04)

The upstream dependency is complete: [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110)
is closed and publishes `GET /api/v1/openapi.json`. Its router includes the
manifest, recent-sheet, capture, measurement, judgment, and ranked-result
paths.

The published `Manifest` schema currently requires only `schema_version`,
`sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose contract
and client need `sheet_version`, `manifest_url`, page geometry, markers,
patches, and pairs. `RankedResults` currently requires only `schema_version`
and `sheet_id`, while the prose contract calls for source colors, scores,
labels, capture provenance, printer profile, and scoring-algorithm version.
The implementation PR must either coordinate those schema expansions upstream
or preserve only the generated fields until they exist.

Other deltas to record in the implementation PR:

- The spec permits both legacy flat and nested capture payloads; the app sends
  the nested `metadata`/`quality` form from the prose contract.
- The spec permits RGB arrays, objects, or JSON strings and allows score,
  similarity, or distance. The app sends RGB objects plus distance and
  similarity.
- The spec models successful measurement and judgment upload response bodies;
  the prose contract leaves them unspecified and the current client accepts an
  empty 2xx response.

## Implementation handoff

Regenerate the client from a pinned checked-in OpenAPI snapshot, replace only
server DTOs, and adapt the existing `APIClient` facade so these local-stub
tests continue to exercise the generated operations. Add a ranked-results
fixture test only after the upstream response schema carries the fields the UI
needs.
