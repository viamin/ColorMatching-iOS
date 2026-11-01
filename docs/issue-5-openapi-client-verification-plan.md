# Issue #5 OpenAPI client verification plan

This is the test-writing (red) phase for replacing the hand-written iOS API layer with a generated OpenAPI Swift client. The upstream dependency, `viamin/color_matching#110`, closed in commit [`094bd6d`](https://github.com/viamin/color_matching/commit/094bd6d3443ddacbda7e63354299867eb5bdfa9f) and serves its contract dynamically at `GET /api/v1/openapi.json`.

## Criterion-to-verification map

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Generator/runtime dependency and generated client are wired into the package | Permanent unit test: `OpenAPIAdoptionRequirementsTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` | Red: neither dependency is declared yet. |
| Manifest and recent-sheets reads use the generated surface against no-live-server stubs | Permanent client tests: `APIClientTests.testFetchManifestDecodesStubbedManifest` and `testFetchRecentSheetsDecodesStubbedResponse` | Green against the existing adapter; implementation must retain these assertions while routing through generated operations. |
| Capture creation, measurement upload, and judgment upload use generated operations against stubs | Permanent client tests: `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, and `testUploadJudgmentsEncodesPathAndPayload` | Green against the existing adapter; implementation must retain them with generated request/response types. |
| Ranked results are generated and wired | Human/external evidence plus a generated-client stub test in the implementation phase | Not run: the current app has no ranked-results call or client method, while the upstream schema does not describe a result payload beyond version and sheet ID. |
| `swift test --disable-sandbox` | Focused package test run after dependencies and generated source exist | Not run in this red phase. |
| PR documents prose-to-spec deltas and endpoint gaps | This document, reviewed against the upstream source links below | Recorded below; human review remains required because the server is not reachable in this container. |

The manifest/read tests use a `URLProtocol` stub, so they remain local and do not require a live Phoenix server. They are permanent regression tests: they exercise a recurring app flow rather than a one-off migration.

## Published-contract deltas and gaps

The published schema is built from the Phoenix router and controller operation metadata rather than checked in as a static artifact. The API spec declares all six relevant routes: [router](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex). However, its schemas do not yet permit a complete replacement of the iOS hand-written response models.

- `Manifest` requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The prose contract and the app need page dimensions, registration markers, patches, pairs, sheet version, and manifest URL for sheet analysis. Those fields are absent from the published manifest schema: [schemas](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_schemas.ex).
- `RankedResults` requires only `schema_version` and `sheet_id`. The prose contract promises source colors, scores, labels, capture provenance, printer profile, and scoring-algorithm version, but the response shape is not machine-readable. The iOS app also does not currently call this endpoint.
- The capture request supports both the legacy flat payload and the nested `metadata`/`quality` payload used by the app. In the published metadata schema `iso` is an integer; the app currently models it as `Float`.
- The measurements schema requires normalized RGB values and describes each RGB value as an array, an `{r,g,b}` object, or a JSON string. It does not describe the app's `stats` object or its top-level `scoring_algorithm_version`; it does allow `score`, `similarity`, or `distance` for each pair score. The prose contract specifies stats and the top-level algorithm version instead.
- Measurement and judgment uploads have documented success response objects, whereas the current iOS client treats any successful status as an empty response. Recent sheets matches the prose shape apart from OpenAPI exposing `manifest_url` as a string rather than a URI-formatted string.

These gaps need either upstream schema expansion or deliberately retained, client-side adapter models before generated types can replace the analysis models. The spec endpoint itself is unauthenticated per the [router](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex); the application endpoints require bearer auth.
