# Replace hand-written API layer with a generated OpenAPI Swift client

## Criterion verification plan

| Criterion | Smallest credible verification | Current test/evidence |
| --- | --- | --- |
| Generator/runtime and a reproducible OpenAPI input are wired into the package | Focused unit/configuration test inspects `Package.swift` and the vendored document | `APIClientTests.testPackageDeclaresTheOpenAPIGeneratorAndRuntime` and `APIClientTests.testVendoredOpenAPIDocumentContainsEveryAppOperation` |
| The app operations use generated request/response types | Local `URLProtocol` stubs exercise each generated operation and assert decoded responses/request shape | Existing capture/measurement/judgment stubs plus `testFetchManifestDecodesTheSheetUsedByTheAnalyzer` and `testFetchRecentSheetsDecodesGeneratedSurfaceResponse`; implementation must add the ranked-results stub when the schema is complete |
| No live server is used in CI | Tests inject an ephemeral `URLSession` with `MockURLProtocol` | `APIClientTests` |
| Contract deltas and endpoint gaps are visible to reviewers | Inspect the upstream OpenAPI source and compare it with the prose contract | Findings below, derived from `viamin/color_matching` `main` at issue #110 close (2026-10-30) |

The first two configuration tests are intentionally red until the implementation run vendors the document and adds the Swift OpenAPI packages. They keep the dependency and all six app paths from being silently omitted during migration.

## Contract deltas found

The producer's OpenAPI document is served dynamically at `GET /api/v1/openapi.json`; it is not currently committed as a static JSON/YAML artifact. The iOS package should vendor the fetched JSON (including a source URL and revision/checksum), so generation is reproducible and reviewable.

The published schemas do not yet describe enough of several iOS-used payloads to replace the hand-written models safely:

- `TestSheetManifest` requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. It omits the page, registration markers, patches, pairs, printer profile, and most capture profile fields that the app's sheet analyzer needs.
- `RankedResults` requires only `schema_version` and `sheet_id`. It omits the result rows, source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version promised by the prose contract.
- The capture schema accepts either a legacy flat body or a nested `metadata` object. The nested `quality` shape has no required fields, whereas the prose contract makes the nested metadata-and-quality request the app contract and enumerates rejection values.
- `MeasurementUploadRequest` omits the prose contract's top-level `scoring_algorithm_version` and per-measurement `stats`; it requires `normalized_linear_rgb_median`, while the current client model permits that value to be absent. The response has count fields that the current client discards.
- `JudgmentUploadRequest` accepts an arbitrary string for `judgment`; it does not encode the prose contract's `match`, `near_match`, and `no_match` enum.
- The published spec additionally defines success bodies for measurement and judgment uploads, which the prose contract leaves unspecified.

## Endpoint gap and merge gate

All six requested routes exist in the producer router, but the manifest and ranked-results schemas are incomplete for generated-client migration. Do not replace `SheetManifest` or introduce a ranked-results generated surface until `viamin/color_matching` expands those response schemas (including required fields and nested objects) and the vendored document is refreshed. This is an upstream contract gap, not an iOS behavior change.

Once the upstream schema is complete, the implementation PR must replace the focused configuration tests' red failures with passing generated-client stubs for manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results. It must retain `MockURLProtocol` injection; no test may contact the live Phoenix server.
