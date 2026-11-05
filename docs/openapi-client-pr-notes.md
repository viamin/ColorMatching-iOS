---
module: ios-api-client
tags: [openapi, swift, testing]
problem_type: migration-plan
---

# Generated OpenAPI client migration notes

## Criterion verification plan

| Criterion | Smallest credible verification | Status in tests-only phase |
| --- | --- | --- |
| Generated package dependencies and vendored/fetched spec | `swift package resolve`, then compile the generated target | Not run: implementation phase owns package changes. |
| Manifest and recent-sheet reads use generated types | Local `URLProtocol` response tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` | Covered by `testFetchManifestDecodesLocalStubResponse` and `testFetchRecentSheetsDecodesNullableTitleFromLocalStubResponse`; migrate their calls to the generated client. |
| Capture, measurement, and judgment writes use generated types | Existing local `URLProtocol` request/response tests in `APIClientTests.swift` | Covered by the three existing upload/create tests; update response expectations to the published spec. |
| Ranked-results surface is generated and callable | Add a focused local `URLProtocol` test when the app exposes its adapter method | Not run: no ranked-results call exists in the current app client. |
| Prose-contract deltas and endpoint gaps are visible to reviewers | Human inspection of upstream PR [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113) and the generated `/api/v1/openapi.json` | Recorded below; implementation PR must copy this section into its description and update it against the vendored artifact. |

The local-stub tests are permanent focused unit/service tests: they cover the companion app's recurring API boundary without requiring a live Phoenix server.

## Published-spec deltas and gaps

The dependency landed in [viamin/color_matching#113](https://github.com/viamin/color_matching/pull/113), which serves the document at `GET /api/v1/openapi.json`.

- The published `TestSheetManifest` schema specifies only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The prose contract and app require `sheet_version`, `manifest_url`, page geometry, registration markers, patches, and pairs. Those fields must be added to the server spec before the generated response can replace `MeasurementCore.SheetManifest` directly.
- The ranked-results schema specifies only `schema_version` and `sheet_id`; the prose contract expects ranked scores, labels, capture provenance, printer profile, and scoring algorithm version. The iOS app currently has no ranked-results call, so this is both a spec and app-surface gap.
- Capture creation accepts both the prose contract's nested `metadata`/`quality` payload and a compatibility flat payload. The OpenAPI schema does not enumerate the prose contract's allowed rejection strings.
- Measurement upload omits the prose contract's top-level `scoring_algorithm_version` and each measurement's `stats`. The generated endpoint response is a `200` JSON count response, while the hand-written client tests presently use `204` and discard the response.
- Judgment upload likewise has a `200` JSON count response in the published spec, while the hand-written client tests presently use `204` and discard the response.

These are upstream contract gaps, not authorization to change capture or scoring behavior in the iOS implementation. The implementation PR should vendor the exact OpenAPI JSON it generated from, record its source commit/checksum, and either block on the missing schemas or retain explicit client-side adapters only where the generated types cannot represent the existing app flow.
