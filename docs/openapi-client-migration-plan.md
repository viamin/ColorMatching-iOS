# OpenAPI Swift Client Migration Plan

This record maps issue #5’s acceptance criteria to the narrowest credible
verification before implementation. It is intentionally committed with the
red tests so the implementation run has an explicit contract target.

## Verification map

| Criterion | Verification | Evidence to produce in implementation PR |
| --- | --- | --- |
| Add `swift-openapi-generator` and `swift-openapi-runtime`; vendor/fetch the provider schema | Human/external evidence plus a reproducible package resolution | `iOS/Package.swift`, vendored `openapi.json` provenance (provider commit `094bd6d3443ddacbda7e63354299867eb5bdfa9f` or later), and a successful `swift package resolve` |
| Generate the manifest, recent sheets, capture, measurement, judgment, and ranked-results surfaces | Focused unit/service tests using a local `URLProtocol` stub | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` has one request/response assertion for every surface, including ranked results |
| Replace hand-written API models while retaining client-only measurement models | Focused unit/service tests that encode generated request bodies and decode generated responses | API tests compile against generated operation input/output types; `MeasurementCore` remains the owner of image-analysis models |
| Generated client tests use no live server | Permanent unit/service tests | `MockURLProtocol` remains the sole transport in API client tests |
| PR records prose-contract deltas and endpoint gaps | Human/external evidence | PR description cites `viamin/color_matching#113` / the published `/api/v1/openapi.json` document and this delta list |

## Provider contract comparison

Source inspected: `viamin/color_matching` main, OpenAPI work merged as
`094bd6d3443ddacbda7e63354299867eb5bdfa9f` (#113, closing #110).

The published OpenAPI contract differs from
`docs/color-matching-api-contract.md` in these material ways:

- `TestSheetManifest` formally requires only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`. The prose contract and iOS
  analyzer additionally require page geometry, registration markers, patches,
  and pairs. This is an endpoint/schema gap: generation from the published
  schema cannot type the data needed to analyze a sheet.
- Capture creation accepts either the legacy flat request or nested
  `metadata`/`quality`; the prose contract documents only the nested form.
- Measurement uploads formally define each measurement’s patch ID and RGB
  medians, and each pair score’s ID, algorithm version, and score/similarity/
  distance. The prose-only top-level `scoring_algorithm_version` and nested
  measurement `stats` payload are not declared by OpenAPI.
- Measurement and judgment uploads return `200` JSON count responses, whereas
  the hand-written client currently treats them as bodyless sends.
- Ranked results are now a documented `GET` operation with the
  `lps-ranked-results/v1` schema version; the hand-written iOS client has no
  operation for it.

## Red-phase tests

- `testUploadMeasurementsUsesThePublishedOpenAPIRequestShape` deliberately
  fails against the hand-written request model: it emits fields the published
  measurement request does not declare.
- `testFetchManifestDecodesThePublishedMinimumSchema` deliberately fails:
  `SheetManifest` requires fields that the published schema does not require.
  This is evidence of the manifest schema gap, not a reason to silently retain
  the hand-written model.

The implementation run must either have the provider expand the manifest
schema, or explicitly record that generated manifest typing cannot safely
replace the analyzer’s contract. No live endpoint is used by these tests.
