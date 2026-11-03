# Issue #5 PR Notes: Generated OpenAPI Client

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Generator, runtime, and published document are added | `APIClientTests.testOpenAPIGeneratorConfigurationReplacesHandWrittenTransportModels` checks for generator/runtime declarations; reviewer inspects the vendored document and generator target. | Red: dependencies and document are not present. |
| Generated client covers manifest, recent sheets, capture creation, uploads, and ranked results | One `URLProtocol`-stubbed test per operation, using the generated operation types and representative published responses. | Blocked pending complete manifest and ranked-results schemas. |
| Hand-written transport models are replaced | `APIClientTests.testOpenAPIGeneratorConfigurationReplacesHandWrittenTransportModels` rejects the current transport models and request DTOs. Keep MeasurementCore analysis models. | Red. |
| No-live-server Swift tests exercise the generated client | Existing `APIClientTests` uses `MockURLProtocol`; convert its create-capture, measurement-upload, and judgment-upload assertions to generated operation calls, then add manifest, recent-sheet, and ranked-results response tests. | Partially present for three legacy wrapper calls; generated-client coverage is blocked. |
| PR description records deltas and endpoint gaps | Copy the following sections into the implementation PR description; verify against the vendored OpenAPI document from `GET /api/v1/openapi.json`. | Recorded here for the draft PR. |

## Published-spec comparison

The upstream OpenAPI implementation landed in `viamin/color_matching` commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f` (issue #110). The following differences are relevant to this app:

- The prose contract defines a complete test-sheet manifest. The published `TestSheetManifest` schema declares only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. It does not describe `manifest_url`, page geometry, registration markers, printer profile, patches, or pairs. Those fields are necessary to decode `MeasurementCore.SheetManifest` and run capture analysis.
- The prose contract documents only the nested `metadata`/`quality` capture request. The published `CaptureRequest` accepts that form and a legacy flat request form.
- The prose document presents a measurement upload with a top-level `scoring_algorithm_version` and nested patch statistics. The published schema does not require either of those fields; its pair score supports one of `score`, `similarity`, or `distance` (with `algorithm_version`). The server responds with a `200` response body, whereas the current app tests accept `204`.
- The published spec models successful measurement and judgment uploads as `200` JSON response bodies. The prose contract does not specify response bodies for those calls.
- The prose contract gives only a narrative for ranked results. The published `RankedResults` schema requires only `schema_version` and `sheet_id`, while the server implementation returns capture provenance, printer profile, score aggregates, source colors, rank, and judgments.

## Endpoint gaps that block the generated-client migration

The generated client can expose the operations now, but it cannot supply typed models sufficient for this app's manifest-driven analysis or for meaningful ranked-results consumption until the provider expands the `Manifest` and `RankedResults` schemas. Request an upstream spec update that describes the full currently returned response shapes before wiring generated response types into `MeasurementCore` and the UI.

The implementation PR should vendor a pinned copy of that completed document, identify its upstream commit or checksum, and regenerate the client in CI so a provider-contract change produces a reviewable diff.
