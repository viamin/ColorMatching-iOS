# Issue #5 OpenAPI client verification plan

This tests-only change records the smallest credible verification for each acceptance criterion before the generated-client implementation begins. All HTTP fixtures are served by `MockURLProtocol`; CI must never need a live Phoenix service.

| Criterion | Verification | Evidence at implementation PR head |
| --- | --- | --- |
| Generated dependencies and vendored/fetched document | Package-resolution/build check plus a checked-in spec source and generator configuration | `iOS/Package.swift`, generator configuration, generated source diff |
| Manifest and recent-sheet surfaces use generated types | Permanent stubbed unit tests decode representative responses and assert required published fields are retained | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Create capture, upload measurements, and upload judgments use generated types | Permanent stubbed unit tests assert operation paths, bearer authentication, generated request shape, and typed success acknowledgements | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Ranked-results surface uses generated types | Permanent stubbed unit test decodes the `lps-ranked-results/v1` response, including its result rows | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |
| Handwritten API models are replaced while client-only models remain | Inspectable implementation diff and compilation; no test can establish authorship of types | Human code review plus `swift test --disable-sandbox` |
| Contract deltas and endpoint gaps are recorded | Inspectable PR description based on the upstream OpenAPI document and this section | Human/external evidence in the PR description |

## Contract deltas found before implementation

The published server contract is exposed at `GET /api/v1/openapi.json` by `viamin/color_matching#110`. Its current implementation establishes these deltas from `docs/color-matching-api-contract.md`:

- `GET /api/v1/test_sheets/:sheet_id/ranked_results` now has a concrete `lps-ranked-results/v1` response. The prose contract only says what it “should” contain, and the iOS client has no operation for it.
- The server’s manifest includes `printer_profile` fields such as `printer_make_model`, `paper_type`, and `ink_type`, plus a `capture_profile`. The handwritten `SheetManifest` silently ignores both. The prose example instead described printer `id`, `name`, `paper`, `ink`, and `settings`.
- Measurement and judgment uploads return `200` JSON acknowledgements (`capture_id` plus counts), rather than the prose contract’s implied empty response. The existing client accepts the status but drops the response body.
- Capture creation accepts both a legacy flat request and the nested `metadata`/`quality` request used by iOS. This app should generate against and use the nested form; it must not reintroduce a second handwritten compatibility branch.
- The machine-readable schemas intentionally allow compatibility forms for RGB values and pair scores (`score`, `similarity`, or `distance`). The app’s generated request must continue to send its present object RGB values and `distance`/`similarity` values.

## Endpoint gaps

No used endpoint is absent from the upstream route/spec surface: manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results are all published. The gap is entirely in the current iOS handwritten layer: ranked results is not represented, and the manifest profiles/upload acknowledgements are discarded.
