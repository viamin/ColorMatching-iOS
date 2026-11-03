# Issue #5 OpenAPI client verification plan

## Criterion map

| Criterion | Smallest credible verification | Status in this test-writing run |
| --- | --- | --- |
| Generator/runtime dependencies and a pinned OpenAPI document | `OpenAPIClientConfigurationTests.testGeneratedClientIsConfiguredFromPinnedAPISpecification` asserts the package dependencies and pinned document's six used paths. | Red: neither the dependencies nor vendored specification exist yet. |
| Manifest and recent-sheet generated operations | `APIClientTests.testFetchManifestDecodesLocalOpenAPIStub` and `APIClientTests.testFetchRecentSheetsDecodesLocalOpenAPIStub` use `URLProtocol` stubs, including fields the current hand-written manifest discards. | Green baseline; implementation must keep these stubs while routing through generated operations. |
| Capture creation, measurement upload, and judgment upload generated operations | Existing `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, and `testUploadJudgmentsEncodesPathAndPayload` use local `URLProtocol` stubs. | Green baseline; implementation must convert their request/response models to generated types. |
| Ranked-results generated operation | The pinned-spec path assertion covers endpoint presence. The implementation run must add a `URLProtocol` response-decoding test when the generated operation's exact Swift type names are available. | Not implemented in red phase because the generated client does not exist. |
| Contract deltas and endpoint gaps in the PR description | Inspectable external evidence: upstream issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110), its published controller/spec source, and the implementation PR description. | Pending implementation PR. |

## Contract deltas discovered from the published API source

- The actual capture and upload success responses are `200 OK` JSON bodies with capture and accepted-row counts; the prose contract says `204` with no body for the upload endpoints.
- The actual manifest's `printer_profile` uses printer metadata fields (`printer_make_model`, `paper_type`, `ink_type`, and related optional fields), not the prose contract's `id`, `name`, `paper`, `ink`, and `settings` shape.
- The actual ranked-results response is defined and versioned as `lps-ranked-results/v1`; the prose contract only describes it narratively and gives no response schema.
- The server currently returns relative `manifest_url` values, while the prose example uses an absolute URL.
- No endpoint gap was found for the six iOS surfaces: manifest, recent sheets, create capture, upload measurements, upload judgments, and ranked results are all declared by the upstream controllers.

The implementation PR must repeat these points in its description and update this record if the fetched `openapi.json` differs from the inspected upstream source.
