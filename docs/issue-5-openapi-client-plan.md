# Issue #5: generated OpenAPI client verification plan

This is the test-plan and contract-delta evidence for the implementation PR.
It is based on upstream issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) and its merged implementation on `main`, inspected 2026-10-31.

| Criterion | Smallest credible verification | Current evidence/status |
| --- | --- | --- |
| Generator, runtime, and vendored spec are configured | Focused package/spec test | `APIClientTests.testPackageConfiguresOpenAPIGeneratorAndRuntime` and `APIClientTests.testVendoredOpenAPISpecIncludesEveryCompanionEndpoint` are red until the implementation adds them. |
| Manifest and recent-sheet reads use the generated boundary | Permanent local-stub client tests | `APIClientTests.testFetchManifestDecodesLocalStubResponse` and `APIClientTests.testFetchRecentSheetsDecodesLocalStubResponse`. |
| Capture creation and both uploads use the generated boundary | Permanent local-stub client tests | Existing `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, and `testUploadJudgmentsEncodesPathAndPayload`. |
| Ranked-results operation is generated | Vendored-spec endpoint test plus a permanent local-stub client test once the app-facing generated adapter exposes the operation | Not yet implemented: the current app does not call this endpoint and has no response model. |
| Hand-written wire models are replaced while client-only measurement models remain | Human code review of the generated diff and the app/core boundary | Not automatable from tests alone; inspect the PR diff. |
| No live server in CI | Permanent tests use `MockURLProtocol` exclusively | Inspect `APIClientTests.swift`; no network host is contacted. |

## Contract deltas found

The published OpenAPI implementation differs materially from the prose contract at `docs/color-matching-api-contract.md`:

- `POST /captures/{capture_id}/measurements` and `POST /captures/{capture_id}/judgments` return `200` JSON acknowledgment objects with `capture_id` and counts. The prose specifies no success response and the current client discards response bodies.
- Capture IDs accepted by the upload controllers are decimal integer strings. The prose example uses `capture_123`, which the server rejects as not found.
- The capture request supports both legacy flat fields and the nested `metadata` form; `quality` is optional in the published schema, though the prose makes it part of the required request example.
- Measurement uploads require `normalized_linear_rgb_median` in the published schema; the current client-side `PatchMeasurement` permits it to be absent. The schema also does not model the current client's `stats` or top-level `scoring_algorithm_version` fields.
- RGB upload values are intentionally permissive in the published schema (array, `{r,g,b}` object, or JSON string), whereas the prose specifies only objects.
- The published ranked-results schema currently guarantees only `schema_version` (`lps-ranked-results/v1`) and `sheet_id`. It does not model the source colors, scores, labels, capture provenance, printer profile, or algorithm version promised by the prose. A strongly typed ranked-results UI cannot safely be generated until that schema is expanded.
- The generated manifest schema declares only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; it does not describe the geometry, patches, pairs, page, or manifest URL needed by the iOS analyzer. Replacing `SheetManifest` with a generated type would lose required static guarantees until upstream expands this schema.
- Authentication is required by the published API routes, while the prose mentions unauthenticated development access. `GET /api/v1/openapi.json` itself is public and is not mentioned by the prose contract.

## Implementation handoff

Vendor the response of `/api/v1/openapi.json` at `iOS/OpenAPI/openapi.json`, pin its source commit/version in the generation workflow, and configure `swift-openapi-generator` plus `swift-openapi-runtime` in `iOS/Package.swift`. Keep a small app-facing adapter only for translating purely client-side measurement/scoring models into generated request types. Add a local-stub test for ranked results after its generated response schema is complete upstream; until then, record the schema gap in the PR description rather than inventing an untyped response model.
