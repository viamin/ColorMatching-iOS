# Issue #5 Generated OpenAPI Client: Verification Plan

This is the red-phase test plan for replacing the hand-written `/api/v1` layer.
It deliberately commits only tests and implementation guidance; a subsequent
implementation change must make every listed test green.

## Criterion coverage

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Add `swift-openapi-generator`, `swift-openapi-runtime`, a vendored/fetched OpenAPI document, and generated-client build wiring | `APIClientTests.testPackageConfiguresGeneratedOpenAPIClientAndVendoredContract` checks the package configuration and a local OpenAPI document. | Red: dependencies, plugin wiring, and document are absent. |
| Generated client supports test-sheet manifest and recent sheets | `APIClientTests.testFetchManifestDecodesStubbedManifestAndAuthorizesRequest` and `testFetchRecentSheetsDecodesStubbedResponse` use `URLProtocol` stubs. The implementation must route these calls through generated operations while retaining equivalent observable behavior. | Not executed locally: no Swift toolchain is installed. These pass against the current hand-written behavior when compiled. |
| Generated client supports capture creation, measurement upload, and judgment upload | Existing `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, and `testUploadJudgmentsEncodesPathAndPayload` use `URLProtocol` stubs. The implementation must retain them while replacing their hand-written request/response models. | Not executed locally: no Swift toolchain is installed. |
| Generated client supports ranked results | Add a typed generated-operation stub test when the published schema’s ranked-results response shape is vendored. The prose contract does not define its response schema, so an exact client assertion would be invented rather than contract coverage. | Not run: endpoint response schema must be taken from the published document. |
| Replace server-owned hand-written API models, preserving client-only models | Implementation review: remove server DTO declarations from `APIClient.swift`; preserve MeasurementCore’s analysis/capture models where they remain local. The configuration test prevents a dependency-only change from being called complete. | Not run: requires implementation diff. |
| Record prose-contract deltas and endpoint gaps in PR description | Human/external evidence: compare the vendored OpenAPI document with `docs/color-matching-api-contract.md` and cite the exact operations/schemas in the PR body. | Not run: upstream source confirms `GET /api/v1/openapi.json` is the serving route, but a serialized document was not available in this checkout. |

## External evidence captured before implementation

`viamin/color_matching#110` is closed. Its `ColorMatchingWeb.ApiSpec` source
constructs the OpenAPI spec from all `/api/` routes and its issue explicitly
states the spec is served at `GET /api/v1/openapi.json`. The document should be
fetched from that endpoint (or committed verbatim from it), rather than
reconstructing it from this repository’s prose contract.

The known prose-contract gap is ranked results: it specifies only a qualitative
response description, not a JSON response shape. Any further delta statement
must be based on the fetched JSON document and recorded in the implementation
PR description.
