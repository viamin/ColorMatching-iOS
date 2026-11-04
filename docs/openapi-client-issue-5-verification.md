# Issue #5: generated OpenAPI client verification

## Acceptance-criterion plan

| Criterion | Smallest credible verification | Current red-phase evidence |
| --- | --- | --- |
| Package generator/runtime and a provider specification | A focused Swift test asserts the two dependencies and the vendored specification's six required paths. | `APIClientTests.testOpenAPIArtifactsDescribeEveryRequiredSurface` |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | The same focused test checks each OpenAPI path; the implementation run must regenerate the checked-in client from that document and compile it. | `APIClientTests.testOpenAPIArtifactsDescribeEveryRequiredSurface` |
| Hand-written wire models are removed while client-side measurement models remain | A focused Swift structural test rejects the three private request DTOs and requires delegation to a generated `Client`. | `APIClientTests.testHandWrittenWireModelsAreReplacedByGeneratedTypes` |
| Stubbed Swift client coverage | Permanent local-URL-protocol tests cover manifest/recent discovery and the create-capture → measurements → judgments user flow. They require no live server. | `APIClientTests.testFetchManifestAndRecentSheetsDecodeStubbedResponses`; `APIClientTests.testCaptureUploadFlowUsesStubbedResponses` |
| PR contract-delta record | Human inspection of this document and the eventual PR description against provider PR [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113). | This section |

The flow test is permanent because capture creation followed by measurement and judgment upload is the recurring companion-app workflow. The structural adoption tests are intentionally red until the implementation run adds the package dependencies, vendors the specification, generates the target, and replaces the DTOs.

## Published-spec deltas and endpoint gaps

Source reviewed: provider PR [#113](https://github.com/viamin/color_matching/pull/113), merged from issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110), commit `05062f5381a6f76413cc2bdf1cb2cc08a1b70ff7`.

- The prose contract's manifest is a complete geometry/capture document. The published `TestSheetManifest` schema only requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; it omits page, markers, patches, pairs, `manifest_url`, and other fields the iOS app currently decodes.
- The prose contract calls for `GET /test_sheets/recent`, `GET /test_sheets/:sheet_id/manifest`, and `GET /test_sheets/:sheet_id/ranked_results`. Provider PR #113 lists all three in OpenAPI, but its router routes them to a 405 method-not-allowed controller rather than `TestSheetController`; these are endpoint gaps for the app.
- Capture creation accepts both the prose nested `metadata` payload and a legacy flat payload. Its documented required fields are less strict than the prose contract. Capture identifiers and capture path IDs are strings in the API schema, although the server converts upload path IDs to integers.
- Measurement uploads now return an acknowledged JSON body (`capture_id`, `measurement_count`, `pair_score_count`) with HTTP 200, rather than the prose contract's unspecified/204 response. Pair scores allow `score`, `similarity`, or `distance`; the iOS payload continues to use compatibility `similarity` and `distance`.
- Judgment uploads similarly return an acknowledged JSON body with HTTP 200 rather than the prose contract's 204 response.
- The published ranked-results schema only promises `schema_version` and `sheet_id`; it does not describe the prose contract's source colors, scores, labels, provenance, printer profile, or scoring-algorithm fields.

The implementation PR description must reproduce these deltas and state whether the provider closes the three 405 route gaps before the generated client is enabled for those calls.
