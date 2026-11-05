# Issue #5 OpenAPI Client Test Plan

## Scope and source snapshot

This test plan covers `viamin/color_matching#110` at upstream commit
`47057afd58f7d46b4d4b740ca7d2d08947774471` (retrieved 2026-11-05). The
published document is served by the Phoenix application at
`GET /api/v1/openapi.json`; this repository must vendor a pinned copy so
generation and tests do not depend on a live service.

## Criterion-to-verification map

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Add `swift-openapi-generator`, `swift-openapi-runtime`, and a vendored document | Focused unit test inspects the package manifest and vendored JSON, then verifies all six in-scope paths | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientMigrationTests.swift` (`testPackageUsesSwiftOpenAPIToolchain`, `testVendoredOpenAPISpecCoversEveryCompanionEndpoint`) |
| Replace server DTOs with generated types | Focused unit test prevents the known hand-written transport DTO declarations from remaining in `APIClient.swift`; the normal Swift build then type-checks generated bindings | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientMigrationTests.swift` (`testHandWrittenTransportDTOsAreRemoved`) |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results against local responses | Permanent local-stub API-client tests. Existing write tests cover creation and uploads; this run adds stubbed manifest and recent-sheets reads. The implementation run must add ranked-results coverage once its generated operation is available. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| `swift test --disable-sandbox` green | Run the package suite after the implementation changes. This tests-only run deliberately leaves the migration tests red. | CI / implementation-run evidence |
| PR records contract deltas and endpoint gaps | Inspect upstream source/spec and this record; a reviewer verifies the eventual PR description. | “Published contract deltas” below |

The local-stub tests are permanent because capture submission and sheet retrieval
are recurring companion-app flows. No live server is used in CI.

## Published contract deltas

Compared with `docs/color-matching-api-contract.md`, the current published
schema has these material differences:

- The manifest schema only guarantees `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`. The prose contract and the iOS
  analyzer require page geometry, markers, patches, and pairs. This is an
  endpoint/schema gap: the generated manifest type cannot replace
  `MeasurementCore.SheetManifest` until the server spec describes those fields.
- Ranked results is present, but only guarantees `schema_version` and
  `sheet_id`; the prose contract calls for colors, scores, labels, capture
  provenance, printer profile, and algorithm version. This is an endpoint/schema
  gap that blocks a useful typed ranked-results UI model.
- Capture creation accepts both the prose contract’s nested `metadata` shape and
  a compatibility flat shape. `quality` is not required by the published schema.
  The published nested metadata requires image dimensions; the existing iOS
  DTO makes them optional. It also models `iso` as an integer instead of the
  client DTO’s `Float`.
- Measurement upload no longer specifies top-level
  `scoring_algorithm_version` or measurement statistics. It requires normalized
  RGB values, permits RGB as an object, array, or JSON string, and responds with
  a `200` JSON count payload rather than the prose contract’s empty `204`.
- Judgment upload likewise responds with a `200` JSON count payload rather than
  an empty `204`.
- The published spec documents bearer authentication and structured error
  responses; the prose contract only gives an informal authentication note and
  does not define errors.

These gaps must be resolved upstream or explicitly adapted at the app boundary
before generated models can replace the corresponding client-side types without
changing capture/scoring behavior.
