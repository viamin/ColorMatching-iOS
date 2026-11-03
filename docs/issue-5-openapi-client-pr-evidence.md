# Issue #5 OpenAPI client PR evidence

## Criterion verification plan

| Criterion | Smallest credible verification | Current red-phase evidence |
| --- | --- | --- |
| Generated client dependencies and vendored API document | Focused Swift contract test reads `Package.swift` and the vendored OpenAPI paths. | `OpenAPIClientContractTests` |
| Manifest and recent-sheet generated response handling | Permanent local-`URLProtocol` Swift tests decode representative published responses. | `APIClientTests.testFetchManifestDecodesPublishedManifestFromLocalStub`, `APIClientTests.testFetchRecentSheetsDecodesPublishedResponseFromLocalStub` |
| Capture, measurement, and judgment generated request handling | Permanent local-`URLProtocol` Swift tests assert outgoing paths and payloads. | Existing `APIClientTests` upload tests |
| Ranked results generated response handling | Permanent local-stub test to be added with the generated client implementation, because the current facade has no ranked-results operation. | Not yet implemented |

## Contract deltas from `docs/color-matching-api-contract.md`

- The published server contract defines `GET /api/v1/test_sheets/:sheet_id/ranked_results` as `lps-ranked-results/v1`, including aggregate capture timing/counts, score summaries, observation data, and printer-profile data. The prose contract only described this response in words; the current iOS client has no operation for it.
- Capture creation accepts the current nested `metadata`/`quality` request but also documents a legacy flat request shape. The generated client should use the nested iOS shape and surface validation failures rather than carrying its own parallel schema.
- Measurement and judgment upload successes are `200` acknowledgement bodies containing the capture ID and row counts. The prose contract and current iOS client use empty `204` success responses.
- The published OpenAPI schema currently makes the manifest deliberately minimal (`schema_version`, `sheet_id`, and `capture_profile`) even though the server serializes the full geometry/profile payload. Generated types therefore cannot safely replace the app's client-side analysis manifest model until the server spec describes those fields.

## Endpoint gaps discovered

- No route gap: the server router and OpenAPI controller cover manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results.
- Schema completeness gap: the manifest and ranked-results OpenAPI schemas omit most fields emitted by the server renderer. This needs to be corrected upstream before those rich responses can be fully typed by a generated client.
