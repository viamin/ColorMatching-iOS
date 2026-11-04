# Replace hand-written API layer with a generated OpenAPI Swift client

## Criterion verification plan

| Criterion | Smallest credible verification | Current test/evidence |
| --- | --- | --- |
| Generator/runtime dependency and vendored API description | Compile the package with the generator plugin and assert the checked-in spec exists. | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientMigrationTests.swift` (red until the package and spec are added) |
| Typed operations for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | `URLProtocol` tests call generated operations against deterministic JSON stubs for every operation. | Existing `APIClientTests` covers the three writes; `testFetchManifestAndRecentSheetsDecodeStubbedResponses` adds both discovery reads. Add ranked-results coverage when that operation is wired. |
| Hand-written transport models are removed while client-only models remain | Compile the app after replacing the transport types at their call sites; inspect the generated source diff in the PR. | Build verification in the implementation run; not automatable in this tests-only run. |
| No live server in CI | Every client integration test supplies a `URLSession` with `MockURLProtocol`; no test uses a deployed URL. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Contract deltas and endpoint gaps are visible to reviewers | Inspect upstream spec/controller evidence and this record before opening the PR. | This document, with upstream references below. |

## Published-contract deltas and endpoint gaps

Upstream issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) is closed and serves the OpenAPI description from `GET /api/v1/openapi.json` (implemented by [OpenApiController](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/open_api_controller.ex)).

- The prose contract says a capture ID resembles `capture_123`; the published controller returns the database ID as a decimal string. Generated call sites must treat it as an opaque `String`, not preserve the prose prefix.
- The prose contract leaves successful measurement and judgment upload responses unspecified. The published API returns `200` JSON bodies with `capture_id` plus accepted row counts, rather than the current client’s implicit empty `204` assumption.
- Ranked results now exist at `GET /api/v1/test_sheets/{sheet_id}/ranked_results`, but the iOS app does not call it. The published response contains aggregate/capture provenance and result fields (see [TestSheetJSON](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/test_sheet_json.ex)); wiring this read is required before claiming ranked-results coverage.
- The currently published OpenAPI schema modules only require a minimal subset of manifest and ranked-result fields (`schema_version`/`sheet_id` and manifest capture-profile version). The runtime renderers expose substantially more fields. This is an upstream spec completeness gap: generated models cannot safely promise fields absent from the OpenAPI schema.
- The prose contract uses `printer_profile.id`, `name`, `paper`, `ink`, and `settings`; the current renderer instead exposes printer make/model, paper type, ink type, ICC/driver/calibration metadata, and print settings. Do not preserve the obsolete prose shape in client-only models.

## Implementation-run handoff

1. Vendor the exact OpenAPI JSON fetched from `/api/v1/openapi.json`, recording its source URL and revision/checksum.
2. Add `swift-openapi-generator` and `swift-openapi-runtime`, configure generation, and replace only server-owned Codable types.
3. Replace the existing `APIClientTests` calls with generated-operation calls while retaining `MockURLProtocol` stubs; add a ranked-results stub using fields the spec actually defines.
4. Run `swift test --disable-sandbox` in an environment with Swift installed, then copy the delta section above into the PR description and update it with the vendored-spec revision.
