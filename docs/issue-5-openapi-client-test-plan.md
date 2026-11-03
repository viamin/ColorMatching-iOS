# Issue #5 OpenAPI client verification plan

This is the tests-only phase for issue #5. The implementation phase must vendor the
published `viamin/color_matching` OpenAPI document at
`iOS/OpenAPI/color-matching-openapi.json`, configure `swift-openapi-generator` and
`swift-openapi-runtime`, and replace the hand-written server request/response models.

## Acceptance criteria and verification

| Criterion | Smallest credible verification | Test or evidence |
| --- | --- | --- |
| Generated client dependencies and vendored API description exist | Focused source-input contract test | `OpenAPIGenerationContractTests.testGeneratedClientInputsCoverEveryAppUsedOperation` |
| Manifest and recent sheets work through the generated transport | Local `URLProtocol` stub response test | `APIClientTests.testFetchManifestDecodesPublishedContractFixture`; `APIClientTests.testFetchRecentSheetsDecodesPublishedContractFixture` |
| Capture creation, measurement upload, and judgment upload work through the generated transport | Local `URLProtocol` stub request/response tests | Existing `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, and `testUploadJudgmentsEncodesPathAndPayload` (to be retained while swapping the implementation) |
| Ranked-results operation is generated | The generated-input contract test checks its OpenAPI path; implementation must add a local-stub response test when the published schema is sufficiently detailed | `OpenAPIGenerationContractTests.testGeneratedClientInputsCoverEveryAppUsedOperation` |
| `swift test --disable-sandbox` | Run in implementation phase after generation | External command evidence required |
| PR contract-delta description | Human-inspectable PR description | Delta notes below |

## Published-spec delta notes for the PR description

Source examined: `viamin/color_matching` PR #113 (closes #110), merged 2026-10-30.
The runtime endpoint is `/api/v1/openapi.json`.

- The prose manifest is substantially more detailed than the OpenAPI schema. The
  published `TestSheetManifest` only requires `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`; it does not model page geometry,
  registration markers, patches, pairs, or `manifest_url` that the iOS app needs.
- The prose promises rich ranked results. The published `RankedResults` currently
  only requires `schema_version` and `sheet_id`, so a typed client cannot yet model
  the results the app would consume.
- Capture creation accepts both the prose's nested `metadata`/`quality` form and a
  legacy flattened form. Its OpenAPI required fields are looser than the prose.
- Measurement uploads in the spec omit the prose's required top-level scoring
  version and do not model measurement stats. RGB payloads permit arrays, objects,
  or JSON strings; pair scores accept score, similarity, or distance.
- The prose leaves successful measurement/judgment responses unspecified, while
  the published spec defines count-bearing response objects. The current app
  discards these responses.
- Recent sheets is aligned, including nullable `title`.

These gaps must be called out in the implementation PR description and resolved
with either a server-spec follow-up or a deliberately limited generated surface;
they must not be hidden by reintroducing hand-written server DTOs.
