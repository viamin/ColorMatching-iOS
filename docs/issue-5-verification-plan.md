# Issue #5 verification plan

This plan records criterion-level verification for the generated OpenAPI-client
migration before implementation begins. The permanent Swift tests use
`URLProtocol` stubs only; no live Phoenix server is required in CI.

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Package generation is wired to a vendored or fetched spec | Inspect the package manifest and committed spec path | `GeneratedClientConfigurationTests.testPackageBuildsTheClientFromVendoredOpenAPISpecification` |
| Every companion API surface is generated | Inspect the generated client for each OpenAPI path | `GeneratedClientConfigurationTests.testGeneratedClientCoversEveryCompanionSurface` |
| Manifest and recent-sheet calls handle the published response shapes | Permanent client tests against `URLProtocol` response stubs | `APIClientTests.testFetchManifestDecodesPublishedSpecShapeFromStubbedResponse`; `APIClientTests.testFetchRecentSheetsDecodesPublishedSpecShapeFromStubbedResponse` |
| Capture creation, measurement upload, and judgment upload retain their wire behavior | Existing permanent `URLProtocol` request/response tests | `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`; `APIClientTests.testUploadMeasurementsEncodesScoresWithAlgorithmVersion`; `APIClientTests.testUploadJudgmentsEncodesPathAndPayload` |
| Ranked-results endpoint is covered | Generated client path inspection; add a response-stub behavior test when the app exposes this surface | `GeneratedClientConfigurationTests.testGeneratedClientCoversEveryCompanionSurface` |
| Prose-contract deltas are recorded for PR review | Human inspection of this document against upstream issue #110 and the published endpoint | [Contract deltas](#contract-deltas) |

## Contract deltas

Evidence source: `viamin/color_matching#110` on its default branch, where the
OpenAPI document is served dynamically by `GET /api/v1/openapi.json`.

- The server emits `manifest_url` as a relative URL path, while the prose
  contract illustrates an absolute URL.
- The server's manifest includes `created_at`, `printer_profile`, and
  `capture_profile`; the app's hand-written `SheetManifest` currently ignores
  those fields.
- Upload endpoints return `200` JSON acknowledgement objects containing the
  capture ID and accepted-row counts. The prose contract specifies requests but
  no responses and the current client discards those bodies.
- Ranked results have a concrete `lps-ranked-results/v1` response, including
  score provenance and observation data. The endpoint exists in the upstream
  router but is not exposed by the current iOS API client.
- The published capture schema supports both legacy flat payloads and the
  nested `metadata`/`quality` payload currently sent by iOS.

## Endpoint gap

The upstream API currently defines all six required routes. The iOS gap is
local: ranked-results retrieval has no API-client method or UI integration yet.
