# OpenAPI client migration evidence for #5

## Acceptance-criterion plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Add generator/runtime dependencies and vendor the OpenAPI document | `APIClientTests.testGeneratedOpenAPIClientArtifactsCoverEveryAppEndpoint` checks the package declarations, vendored document, and six required paths. | Red: implementation pending. |
| Generate the six app API surfaces | The same test checks manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results in the vendored source of truth. | Red: implementation pending. |
| Replace hand-written API models | Compile the app against generated types in the implementation change; inspect the removal of server-owned models. | Not runnable in this tests-only change. |
| Exercise local stubbed responses | `APIClientTests` uses `MockURLProtocol` only; its manifest/recent tests add the two missing read surfaces and existing tests cover the three write surfaces. The implementation change must convert these calls to generated operations and add ranked-results coverage. | Existing tests are locally stubbed; generated-client conversion is pending. |
| Record contract deltas and endpoint gaps | This document records the external evidence below; the implementation PR description should copy it. | Recorded. |

## Published-spec evidence and PR-description material

The dependency is merged as [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113), closing [#110](https://github.com/viamin/color_matching/issues/110). It serves the document at `GET /api/v1/openapi.json`; the iOS change should fetch that endpoint and vendor the exact JSON at `iOS/OpenAPI/color-matching.json`.

Contract deltas found from the upstream OpenAPI source:

- Ranked results now has a machine-readable `RankedResults` response with required `schema_version` (`lps-ranked-results/v1`) and `sheet_id`. The prose contract names the endpoint but leaves its response shape unspecified.
- The manifest schema declares only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` as required. The prose contract presents many more fields as though they were universally present; generated optionality must follow the published document.
- Capture creation accepts either the legacy flat request or the app's nested `metadata` request. The prose contract documents only the nested form.
- Measurement uploads no longer require the prose-only top-level `scoring_algorithm_version` or per-measurement `stats`; normalized RGB is required by the published schema. Pair scores require `algorithm_version` plus one of `score`, `similarity`, or `distance`.
- Measurement and judgment uploads return typed `200` count responses upstream, while the current hand-written client discards the response and treats all 2xx statuses as success.

Endpoint gap: the published `RankedResults` schema currently exposes only its version and sheet ID, not the source colors, labels, scores, capture provenance, printer profile, and scoring algorithm metadata promised by the prose contract. The generated client must expose the published shape and the missing ranking-detail fields should be raised with the API owner rather than invented by this app.
