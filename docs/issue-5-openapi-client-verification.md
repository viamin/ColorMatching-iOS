# Issue #5 OpenAPI client verification plan

This is the test-writing (red) phase for replacing the hand-written iOS API
layer. The implementation phase must vendor the OpenAPI document served by
`viamin/color_matching` at `GET /api/v1/openapi.json`, configure
`swift-openapi-generator` and `swift-openapi-runtime`, and wire generated
operation types into the app's existing capture flow.

## Criterion mapping

| Criterion | Smallest credible verification | Evidence in this change |
| --- | --- | --- |
| Generator/runtime and published spec are included | Focused Swift package/configuration test checks both dependencies, a vendored spec, and all six used paths | `APIClientTests.testPackageDeclaresGeneratedClientAndVendoredPublishedSpec` (red until implementation) |
| Manifest and recent-sheet operations work without a live server | Permanent local-stub unit test decodes upstream response bodies and checks paths/auth | `APIClientTests.testFetchManifestDecodesPublishedManifestResponse`; `APIClientTests.testFetchRecentSheetsDecodesPublishedResponse` |
| Capture creation, measurement upload, and judgment upload use the published API | Permanent local-stub unit tests check payloads and actual response statuses | `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`; `APIClientTests.testUploadMeasurementsEncodesScoresWithAlgorithmVersion`; `APIClientTests.testUploadJudgmentsEncodesPathAndPayload` |
| Ranked results are represented in the generated surface | Inspectable vendored-spec path assertion; implementation must add a local-stub operation test once generated operation naming is available | Red configuration test above; no client method exists in this phase |
| Contract deltas are captured | Human/external evidence from the upstream router, controllers, and OpenAPI schema modules at `viamin/color_matching` `main` | This document |

## Contract deltas and endpoint gaps

The external evidence was inspected on 2026-11-01 from upstream issue #110's
merged implementation: `ColorMatchingWeb.Router`, `TestSheetController`,
`CaptureController`, `TestSheetJSON`, and `ApiSchemas`.

The prose contract and published API differ in these material ways:

- Measurement and judgment uploads return `200` JSON acknowledgment objects
  (`capture_id` plus counts), rather than the prose contract's implied `204`
  empty responses. The new stubs use the published responses.
- Capture IDs are stringified database IDs in the actual response, not the
  illustrative `capture_123` form used by the prose document.
- The manifest's actual `printer_profile` fields are provenance fields
  (`printer_make_model`, `paper_type`, `ink_type`, and calibration/driver
  fields), rather than the prose document's `id`, `name`, `paper`, and `ink`.
- Ranked results are now a versioned `lps-ranked-results/v1` response with
  aggregate score and observation data. The prose contract only describes it
  narratively, so it cannot support a hand-written typed response model.
- The published capture request accepts both the legacy flat shape and the
  existing nested `metadata`/`quality` shape. The client must retain the
  nested shape unless the generated spec's operation types require an adapter.
- The current OpenAPI schema intentionally gives only a minimal machine schema
  for manifest and ranked-results nested fields. This is an upstream endpoint
  gap: richer nested response constraints are needed before code generation
  can detect all of the prose-contract drift at compile time.

No new endpoint is requested. The six client surfaces are manifest, recent
sheets, capture creation, measurement upload, judgment upload, and ranked
results.
