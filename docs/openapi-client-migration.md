# OpenAPI client migration evidence for #5

## Criterion-to-verification plan

| Criterion | Smallest credible verification | Current result |
| --- | --- | --- |
| Package dependencies and vendored/fetched API document | `OpenAPIClientMigrationTests.testPackageAndVendoredContractSupportAllConsumerOperations` checks the package manifest and every required path in the vendored document. | Red until the implementation adds the dependencies and `iOS/OpenAPI/color-matching.openapi.json`. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | The same contract test requires each operation; `APIClientTests` exercises the app-facing read operations through `URLProtocol` stubs. The implementation run must replace the existing transport calls with generated operations and extend the stubs to generated request/response types. | Partially covered; generated operations do not exist yet. |
| Hand-written API models are replaced while client-side measurement models remain | Implementation review plus a successful package compile after the generated target replaces API transport DTOs. | Not run in the tests-only phase. |
| Generated client is tested without a live server | `APIClientTests` uses `MockURLProtocol`; its manifest and recent-sheet tests were added for this migration. Existing capture, measurement, and judgment tests use the same local stub mechanism. | Written but not run: this container has no Swift executable. Generated-client wiring is red-phase work. |
| PR records contract deltas and endpoint gaps | This document supplies the factual PR-description input from the upstream spec at `viamin/color_matching` commit `a0975b041ff08a71e04b9e133ee955dda121b751` (PR #113). | Ready for the implementation PR description. |

## Published-spec deltas from the prose contract

- The upstream contract is served dynamically at `GET /api/v1/openapi.json`; it is not a checked-in JSON artifact. The iOS package must fetch and pin a snapshot (or vendor it) for reproducible generation.
- `TestSheetManifest` documents only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The prose contract and server renderer include `sheet_version`, `manifest_url`, page geometry, registration markers, printer profile, patches, and pairs. The spec therefore cannot generate a complete typed manifest DTO today.
- `RankedResults` documents only `schema_version` and `sheet_id`. The renderer returns rank, pair, source color, score, judgment, capture-provenance, and printer-profile fields described in the prose contract. This is an endpoint/schema gap that blocks a fully typed ranked-results client.
- Capture creation permits both the nested `metadata`/`quality` shape from the prose contract and a legacy flattened payload. In the flattened form it calls the exposure field `exposure_duration`, not `exposure_duration_seconds`; the nested form remains compatible with the app. The published schema does not require `quality`.
- The measurement-upload schema requires `normalized_linear_rgb_median` for every measurement, while the current client-side model permits it to be absent. It does not describe the app's `stats` object or root `scoring_algorithm_version`, and allows RGB arrays or JSON strings as compatibility forms in addition to channel objects.
- Pair scores may provide `score`, `similarity`, or `distance`; the prose contract documents only similarity and distance. Successful measurement and judgment uploads are documented as `200` JSON responses with counts, whereas the prose contract does not define a response and the existing client tests use `204`.
- The routes required by this app are present in the published spec. The gap is schema completeness for manifest and ranked-results payloads, not route absence.
