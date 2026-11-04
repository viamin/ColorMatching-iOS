# Issue #5: Generated OpenAPI Swift Client

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only PR |
| --- | --- | --- |
| Generator/runtime dependencies and a fetched or vendored document | `OpenAPIMigrationTests.testGeneratedClientPackageAndPluginAreConfigured` and `testVendoredSpecificationCoversEveryCompanionSurface` | Red: implementation pending |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Vendored-spec endpoint assertions; implementation run will compile generated operations and invoke each against `MockURLProtocol` stubs | Red: implementation pending |
| Hand-written transport models are replaced, client-only models retained | `testAPIClientDelegatesToGeneratedClientInsteadOfDeclaringTransportModels` plus code review of `MeasurementCore` models | Red: implementation pending |
| Stubbed Swift client tests | `APIClientTests` uses local `MockURLProtocol`; manifest and recent-sheet decode paths are added here, while existing capture/measurement/judgment tests cover write paths. The implementation must route this facade through the generated client and add the ranked-results stub. | Partial: current facade tests run once Swift is available; generated delegation is red |
| `swift test --disable-sandbox` | Run from `iOS/` in the implementation PR | Not run: the container does not include a Swift toolchain |

These are permanent focused service tests: the API boundary is a recurring user flow and provider-contract drift must be caught on every PR. No live server is used.

## Published-spec comparison for PR description

Inspected 2026-11-04 against `viamin/color_matching` main: [router](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex), [OpenAPI schemas](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_schemas.ex), and [issue #110](https://github.com/viamin/color_matching/issues/110).

The provider now serves `/api/v1/openapi.json` and routes all six companion endpoints. The published schema currently has gaps that prevent a complete lossless generated client:

- `Manifest` declares only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the prose contract and existing app need page geometry, markers, printer/capture profiles, patches, and pairs.
- `RankedResults` declares only `schema_version` and `sheet_id`; it does not describe ranked rows, source colors, scores, labels, or capture/printer provenance promised by the prose contract.
- Measurement rows in the spec require `normalized_linear_rgb_median`, which the current client models as optional, and omit the current `stats` object and top-level `scoring_algorithm_version`.
- The spec describes successful measurement and judgment uploads as `200` JSON count responses, while the prose contract did not specify success response bodies and the current tests stub `204`.
- The capture schema accepts the current nested `metadata`/`quality` shape but also supports a legacy flat payload; its `metadata` required set omits quality fields and the prose contract's optional camera fields.

The implementation PR should vendor the exact response from `/api/v1/openapi.json`, generate only after the provider resolves the missing manifest/ranked-result schemas (or commit an explicitly reviewed compatibility adapter), and update this section with the pinned source revision and final regeneration command.

## Dependencies

Depends on viamin/color_matching#110 (closed 2026-10-30). The provider endpoint exists, but schema completeness for the app's manifest and ranked-result surfaces remains an external compatibility gap.
