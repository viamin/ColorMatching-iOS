# OpenAPI Swift Client: Verification Plan and Contract Notes

This is the implementation PR evidence for issue #5. The test suite stays local: `MockURLProtocol` supplies the HTTP responses, so no Phoenix server is required in CI.

## Acceptance criteria and smallest credible verification

| Criterion | Verification | Evidence at this head |
| --- | --- | --- |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Focused contract-surface test over the upstream OpenAPI fixture. It prevents a regeneration configuration from silently omitting an operation. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testPublishedOpenAPISpecCoversEveryGeneratedClientSurface` |
| Read responses remain usable in the companion flow | Permanent local-stub tests decode the published manifest and recent-sheets response shapes. | `APIClientTests.swift:testFetchManifestDecodesPublishedSpecResponse`, `APIClientTests.swift:testFetchRecentSheetsDecodesPublishedSpecResponse` |
| Write requests remain compatible | Existing permanent local-stub tests assert capture, measurement, and judgment paths and JSON payloads. The implementation phase must update their response statuses/bodies to the published spec. | `APIClientTests.swift:testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload` |
| Dependencies and generated source are wired into the package | Human/code-review evidence: inspect `iOS/Package.swift`, the vendored/fetched source spec, and generated target after implementation. | Not present in this tests-only phase |
| Hand-written transport models are replaced, while client-side measurement models remain | Human/code-review evidence: inspect the generated target and `ColorMatchingLPSAppCore` after implementation. | Not present in this tests-only phase |

## Published-spec deltas from the prose contract

Source inspected: `viamin/color_matching` PR [#113](https://github.com/viamin/color_matching/pull/113), merged from commit `05062f5381a6f76413cc2bdf1cb2cc08a1b70ff7`.

- `POST /api/v1/captures/{capture_id}/measurements` returns a 200 JSON object (`capture_id`, `measurement_count`, `pair_score_count`), not the prose contract's undocumented/assumed 204 response. `POST .../judgments` likewise returns a 200 JSON object (`capture_id`, `judgment_count`).
- The published measurement schema requires only `patch_id`, `linear_rgb_median`, and `normalized_linear_rgb_median`; it does not describe the prose contract's `scoring_algorithm_version` or per-measurement `stats`. The generated client must send only supported fields unless the server spec is expanded.
- Pair scores require `pair_id`, `algorithm_version`, and one of `score`, `similarity`, or `distance`. This is compatible with the current payload, but the resulting generated one-of representation needs an adapter at the client/measurement boundary.
- Capture creation accepts both the prose's nested `metadata`/`quality` body and a legacy flat body. The nested form remains the app's intended shape. Most nested metadata fields are optional in the published schema, whereas the prose presents them as a complete payload.
- The manifest schema only declares `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; fields the app needs for image analysis (`page`, markers, patches, pairs, rectangles) are emitted by the endpoint but absent from the machine-readable schema.
- Ranked results exists in the published spec, but its response guarantees only `schema_version` and `sheet_id`. The prose's required detail (source colors, scores, labels, provenance, printer profile, algorithm version) is an endpoint/spec gap and cannot be safely modeled as generated types yet.

## Implementation follow-up

The implementation PR must vendor or fetch the complete `/api/v1/openapi.json`, add `swift-openapi-generator` and `swift-openapi-runtime`, generate the six operations above, and revise the write stubs to assert the published 200 response objects. Before considering the generated-client criterion passed, add direct generated-client local-stub tests for each operation; this tests-only commit deliberately does not fabricate generated type names ahead of the generator output.
