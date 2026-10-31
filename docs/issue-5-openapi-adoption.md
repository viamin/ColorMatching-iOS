# OpenAPI client adoption: verification plan and contract audit

This is the PR/run evidence for issue #5. It is intentionally kept with the
consumer code so the implementation PR can update the evidence beside the
tests.

## Source inspected

- Provider repository: `viamin/color_matching`, commit
  `14320c33f93258a331cf17af7323ce9035c8a44d` (2026-10-30).
- Published-spec route: `GET /api/v1/openapi.json`.
- Provider route and OpenAPI tests confirm all six consumer routes are present.

## Acceptance-criterion plan

| Criterion | Smallest credible verification | Evidence at this test PR head |
| --- | --- | --- |
| Generated client is wired for the manifest and recent-sheets reads | Permanent URLProtocol tests decode provider-shaped local fixtures and assert request paths/authentication. The implementation PR must make these tests exercise generated operation types. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testFetchManifestDecodesPublishedManifestFixture`, `testFetchRecentSheetsDecodesPublishedResponseFixture`) |
| Generated client is wired for capture creation, measurement upload, and judgment upload | Permanent URLProtocol tests assert the client sends provider-shaped payloads and paths. The implementation PR must retain these tests while replacing hand-written request/response types. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` (`testCreateCaptureEncodesMetadataAndQuality`, `testUploadMeasurementsEncodesScoresWithAlgorithmVersion`, `testUploadJudgmentsEncodesPathAndPayload`) |
| Generated client is wired for ranked results | Permanent URLProtocol test to be added with the generated ranked-results output type once the provider supplies a complete ranked-results schema. | Not run: current provider schema describes only `schema_version` and `sheet_id`, while the app needs result rows, scores, provenance, and printer data. |
| No live server is required in CI | The permanent client tests use `MockURLProtocol`; no endpoint, token, or database is used. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| `swift test --disable-sandbox` is green after generated types are wired | Run exactly that command after the generated target and adapter are implemented. | Not run in this tests-only phase. |

## Contract deltas and endpoint gaps

The provider has all six requested routes, including the ranked-results route
that the current iOS `APIClient` does **not** expose. The adapter needs a new
ranked-results operation; this is an iOS-client gap, not a missing provider
endpoint.

The prose contract and the provider differ in these observable ways:

- `printer_profile` changed from `{id, name, paper, ink, settings}` to
  `{printer_make_model, paper_type, ink_type, icc_profile, print_settings,
  driver_name, driver_version, calibration_date, calibration_version, notes}`.
- The provider's capture request accepts both the old flat shape and the prose
  contract's nested `metadata`/`quality` shape. It calls the flat duration
  field `exposure_duration`, while the nested metadata field remains
  `exposure_duration_seconds`.
- Measurement uploads are less restrictive in the provider: RGB channels can
  be arrays, objects, or JSON strings; pair scores may use `score`,
  `similarity`, or `distance`. The prose contract requires object RGB values
  and sends similarity plus distance.
- The prose contract says both uploads have no response body. The provider
  OpenAPI schema specifies `200` JSON responses with capture and accepted-row
  counts.
- The prose contract describes capture rejection strings and judgment values;
  the provider OpenAPI schemas currently model them as unconstrained strings.

The current published OpenAPI schema is not yet sufficient to replace all
hand-written app models: `Manifest` declares only `schema_version`, `sheet_id`,
and a partial `capture_profile`; `RankedResults` declares only
`schema_version` and `sheet_id`; and the measurement item schema omits the
`stats` object that the app uploads. Before the implementation PR can honestly
claim generated types cover the app's full manifest, upload, and ranked-result
surfaces, the provider needs to publish those fields in its OpenAPI schemas.
