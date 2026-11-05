---
module: iOS API client
tags: [openapi, swift-openapi-generator, contract, test-plan]
problem_type: migration-evidence
---

# Generated OpenAPI client migration evidence

This issue is in the test-writing phase. The implementation phase must add
`swift-openapi-generator` and `swift-openapi-runtime`, vendor or fetch the
OpenAPI document from `viamin/color_matching#110`, and replace API-wire models
with generated types. Client-only measurement and camera models remain owned by
the app.

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Current evidence |
| --- | --- | --- |
| Generated client covers manifest and recent sheets | Permanent URLProtocol-backed Swift test decodes OpenAPI-shaped stub responses and checks both routes | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` `testFetchesManifestAndRecentSheetsFromOpenAPISurface` |
| Generated client covers capture creation, measurement upload, and judgment upload | Permanent URLProtocol-backed Swift tests check request body, route, auth, and successful OpenAPI response status/body | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` `testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload` |
| Generated client covers ranked results | Permanent URLProtocol-backed Swift test to be added with the generated operation in the implementation phase | Not runnable in this tests-only phase: no ranked-results client operation exists yet |
| Dependencies and generated types are wired into the Swift package | `swift test --disable-sandbox` after regeneration, plus review of `Package.swift`, generator config, vendored/fetched spec, and generated sources | Not runnable in this tests-only phase |
| PR records prose/spec deltas and endpoint gaps | Human review of this record and the PR description, against the spec served by `GET /api/v1/openapi.json` | Upstream source inspected at `viamin/color_matching` PR #113 / issue #110 |

## Contract deltas found

The upstream spec is served by `GET /api/v1/openapi.json`. The code behind
`viamin/color_matching#110` establishes these changes relative to
`docs/color-matching-api-contract.md`:

- Ranked results are now a defined endpoint with a concrete
  `lps-ranked-results/v1` response root (`schema_version`, `sheet_id`); the
  prose contract previously left its response unspecified.
- Measurement and judgment uploads return `200` JSON acknowledgement bodies
  (`capture_id` plus counts), rather than the undocumented/assumed empty `204`
  responses used by the existing tests.
- Capture request validation accepts either legacy top-level capture attributes
  or the nested `metadata` shape used by the iOS app. The nested shape is the
  migration target.
- The published schemas currently describe only selected manifest and ranked
  result fields. The app consumes additional manifest geometry fields and must
  retain them in the generated document/type configuration before removing the
  hand-written model.
- The prose printer-profile object (`id`, `name`, `paper`, `ink`, `settings`)
  differs from the server renderer, which exposes printer make/model, paper and
  ink type, ICC/profile settings, driver, calibration, and notes. The current
  app does not consume this object.
- The OpenAPI document does not constrain rejection or judgment strings to the
  prose lists; generated types may therefore expose them as strings unless the
  server schema is tightened.

## Endpoint gaps

All six iOS surfaces have routes in the upstream router. The current iOS client
does not expose ranked results, so the implementation must add that generated
operation and its stubbed response test. There is no new app behavior required
for it; this is client-surface parity with the published API.
