# OpenAPI client verification plan — issue #5

This is the criterion-level plan and PR-description source for replacing the
hand-written iOS API layer. It is deliberately committed with the red tests so
the implementation run has inspectable acceptance evidence before it changes
production code.

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Package uses the OpenAPI generator and runtime | Focused package-configuration test | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testPackageConfiguresOpenAPIGenerationAndRuntime` |
| Generated client preserves manifest and recent-sheet reads | Permanent local-stub tests that assert request path/authentication and decoded values | `APIClientTests.testFetchManifestDecodesStubbedServerResponse`, `APIClientTests.testFetchRecentSheetsDecodesNullableTitlesFromStubbedServerResponse` |
| Generated client preserves capture creation and the two uploads | Permanent local-stub request/response tests | `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload` |
| Ranked-results operation is generated and exercised | Permanent local-stub test added when the generated operation name is known from the vendored document | Must be added in implementation run; absent from the current hand-written client |
| The OpenAPI document is authoritative and generation is reproducible | Inspect the vendored/fetched document plus generated output in the implementation PR | Human/external review; the server publishes it at `/api/v1/openapi.json` |
| `swift test --disable-sandbox` is green with generated types wired in | Run that exact command after generation | Implementation-run command result |

## Published-contract deltas

Compared with `docs/color-matching-api-contract.md`, the upstream OpenAPI
implementation merged in [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113)
(which closes #110) is materially more permissive in several app-facing areas:

- The manifest schema formally requires only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`. The prose contract treats page
  geometry, markers, patches, pairs, and a manifest URL as available. The
  generated client must tolerate the published optionality while the adapter
  continues to require the client-side fields needed for analysis.
- Capture creation accepts either the legacy flat payload or nested `metadata`.
  The prose describes only nested metadata plus quality. The generator should
  use the published union rather than preserve a bespoke Codable request.
- Measurement uploads no longer require a top-level scoring algorithm version
  or stats; their RGB values can be arrays, `{r,g,b}` objects, or JSON strings.
  Pair scores require `algorithm_version` and one of `score`, `similarity`, or
  `distance`. The prose instead requires stats and sends both distance and
  similarity.
- The published write endpoints define success response bodies for measurement
  and judgment uploads, while the current app expects `204 No Content`.
  The generated integration needs to support the documented response status
  and confirm whether 204 remains server-compatible.
- The ranked-results schema guarantees only `schema_version` and `sheet_id`.
  This is an endpoint gap against the prose promise of source colors, scores,
  labels, capture provenance, printer profile, and scoring algorithm version;
  no rich ranked-results app model should be invented until upstream tightens
  the schema.

The implementation PR description should repeat these findings and state which
published response statuses were observed from the local stubs.
