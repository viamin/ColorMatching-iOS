# Issue #5 OpenAPI client verification plan

This test-writing change deliberately leaves the migration red: the package has
no OpenAPI dependencies, no vendored specification, and the existing transport
still owns hand-written request and response models.

| Criterion | Smallest credible verification | Initial status |
| --- | --- | --- |
| Generator/runtime dependencies and vendored document | `OpenAPIClientMigrationTests.testPackageDeclaresOpenAPIGeneratorAndRuntime` and `testVendoredSpecDocumentsEveryAppEndpoint` | failing until the package and snapshot are added |
| Generated types replace transport models | `OpenAPIClientMigrationTests.testGeneratedClientReplacesHandWrittenTransportModels` | failing until the wrapper delegates to generated types |
| Manifest, recent sheets, capture, measurement, judgment, and ranked results work with the generated client | Permanent local-`URLProtocol` XCTest coverage in `APIClientTests`; extend it with ranked-results coverage when the generated operation names are available | existing tests cover capture/measurement/judgment; manifest/recent/ranked results need coverage |
| No live server in CI | The above tests inject `URLSessionConfiguration.protocolClasses` and `MockURLProtocol` | covered for the existing three write surfaces |
| Contract deltas and endpoint gaps in the PR | Human review of the published `GET /api/v1/openapi.json` snapshot against `docs/color-matching-api-contract.md` | external evidence required |

## Published-spec comparison (2026-11-03)

The upstream issue is closed and its server source exposes the specification at
`GET /api/v1/openapi.json`. The endpoint paths needed by this app are present:
manifest, recent sheets, capture creation, measurement upload, judgment upload,
and ranked results.

The published schema is not yet sufficient to replace all iOS models without
losing information. In particular, `TestSheetManifest` currently requires only
`schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`;
the prose contract additionally needs page geometry, registration markers,
patches, pairs, `manifest_url`, and sheet metadata. `RankedResults` currently
requires only `schema_version` and `sheet_id`, while the prose contract calls
for source colors, scores, labels, capture provenance, printer profile, and
scoring algorithm version. Measurement uploads also differ: the prose contract
includes `scoring_algorithm_version` and per-measurement statistics, whereas
the published request schema documents only patch IDs and RGB values; it allows
multiple RGB representations and score variants. Capture creation accepts both
the prose nested `metadata`/`quality` shape and a legacy flat shape.

These gaps must be recorded in the implementation PR description and resolved
with the API owner, or preserved in explicit client-side compatibility types,
before deleting the corresponding app models.
