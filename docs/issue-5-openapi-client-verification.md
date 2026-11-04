# Issue #5 verification plan

This tests-only change establishes the acceptance tests for replacing the
hand-written `/api/v1` client. The implementation run must make these tests
green without contacting a live server.

| Criterion | Smallest credible verification | Evidence location |
| --- | --- | --- |
| Generator and runtime are installed, and the published document is vendored | Assert the Swift package declares `swift-openapi-generator`, `swift-openapi-runtime`, and the generator plugin; parse the vendored OpenAPI 3 document | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIIntegrationContractTests.swift` |
| All app API surfaces are generated | Assert the vendored document contains manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked-results paths | `OpenAPIIntegrationContractTests.testPublishedSpecIsVendoredAndCoversEveryAppOperation` |
| Wire models are generated rather than maintained in the app | Assert the API boundary imports the generated module and no longer declares the hand-written transport models | `OpenAPIIntegrationContractTests.testAPIBoundaryUsesGeneratedTypesInsteadOfHandWrittenWireModels` |
| Client request/response handling uses local stubs | Exercise the sheet manifest and recent-sheets reads using `MockURLProtocol`; the pre-existing local-stub tests cover capture creation, measurement upload, and judgment upload | `OpenAPIIntegrationContractTests.testSheetReadOperationsDecodeStubbedResponses`; `APIClientTests.swift` |
| Contract deltas and endpoint gaps are recorded | Human review of this document's delta notes against the vendored server document | [Contract deltas](#contract-deltas-found-against-the-published-spec) |

## Contract deltas found against the published spec

Evidence was read from `viamin/color_matching` issue #110's merged API-spec
work, specifically its OpenAPI controller tests and router at `main` on
2026-11-04. The server publishes its machine-readable document at
`GET /api/v1/openapi.json`; it is not currently a checked-in static artifact.

- The prose contract does not describe the OpenAPI document endpoint or the
  generator-compatible source of truth. The implementation must vendor a
  pinned fetched document at `iOS/OpenAPI/color-matching-api.json`.
- The published spec represents capture input as two compatible request shapes
  (`CaptureRequest.anyOf`), whereas the prose specifies only the
  `metadata`/`quality` envelope.
- The published spec permits three compatible pair-score shapes and only
  requires `pair_id` and `algorithm_version`. The prose fixes one richer shape
  with distance and similarity.
- The published spec permits three RGB payload shapes; the prose assumes the
  `{r, g, b}` shape only.
- The prose leaves ranked-results response fields undefined. The published API
  has the route, but its generated response type must be inspected when the
  pinned document is fetched; this is the remaining endpoint-schema review
  item for the implementation PR.

The API routes themselves are not a gap: the server router exposes all six
surfaces used by this app. The implementation should preserve the app's local
scoring behavior and adapt generated wire values at the API boundary only.
