# Issue #5 OpenAPI Client Verification Plan

## Criterion-to-evidence map

| Criterion | Smallest credible verification | Status in tests-only run |
| --- | --- | --- |
| Generated package dependencies and a tracked API document | `OpenAPIClientConfigurationTests.testPackageTracksGeneratedClientDependenciesAndVendoredSpecification` asserts the package declarations and `iOS/OpenAPI/color-matching-openapi.json`. | Red: implementation must add them. |
| Manifest and recent-sheet discovery | `APIClientTests.testFetchesManifestAndRecentSheetsFromLocalStubbedResponses` uses `URLProtocol` stubs and verifies decoded values and paths. | Implemented; run in the implementation phase. |
| Capture creation, measurement upload, judgment upload | Existing `APIClientTests` use local `URLProtocol` stubs to assert request paths, authentication, and JSON payloads. | Implemented; run in the implementation phase. |
| Ranked results | Add a local-stubbed generated-client test once the published JSON document is vendored, because the current Swift API has no ranked-results operation or generated response type to compile against. | Blocked on generated client implementation. |
| Prose-versus-spec comparison | Inspect the upstream generated `/api/v1/openapi.json` artifact at the commit selected for vendoring and record the deltas below in the PR body. | External evidence required. |

The permanent tests above use local stubbed responses only; no live Phoenix server is needed in CI.

## Upstream contract deltas found before vendoring

The server implementation on `viamin/color_matching` `main` is the available pre-vendoring evidence; the JSON document is produced dynamically by `GET /api/v1/openapi.json` and is not committed to that repository. The eventual PR must cite the exact fetched artifact digest and repeat this comparison against that artifact.

- The prose calls the path parameter `sheet_id`; the server looks it up as a sheet `lookup_code`. The generated parameter name should follow the OpenAPI document while the app continues to send the lookup code.
- The prose leaves measurement and judgment success responses unspecified. The server returns HTTP 200 JSON counters (`capture_id` plus measurement/pair-score or judgment counts), rather than the current client assumption of an empty 204 response.
- The published schema permits two capture request shapes: the prose/current app's nested `metadata` and `quality` shape, plus a legacy flattened form. It also requires fewer nested metadata fields than the client model makes nonoptional.
- The measurement schema accepts RGB arrays, `{r,g,b}` objects, or JSON strings; the current client sends only objects. Pair scores may contain `score`, `similarity`, or `distance`; the current client sends both similarity and distance.
- The prose says judgments are one of three values, but the published request schema currently declares `judgment` as an unconstrained string.
- Ranked results are an actual authenticated `GET /api/v1/test_sheets/:sheet_id/ranked_results` route with `lps-ranked-results/v1`, while the current Swift client has no operation for it and the prose does not define its response shape.

## Endpoint gaps

No extra endpoint is needed for the requested migration. The app consumes five route families: manifest/recent discovery, capture creation, measurement upload, judgment upload, and ranked results. The last is the only one not currently represented in the Swift client.
