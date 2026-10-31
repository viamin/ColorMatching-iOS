# Issue #5: generated OpenAPI client verification plan

This is the red-phase test plan for replacing the iOS hand-written API layer. It is deliberately checked in with the tests so the implementation PR has a concrete acceptance target.

## Criterion coverage

| Criterion | Smallest credible verification | Current red-phase evidence |
| --- | --- | --- |
| Add the generator/runtime and vendor the OpenAPI document | Permanent unit test reads the vendored document and requires each app operation path. Package dependency and generated-source presence are reviewed as implementation artifacts. | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift:testVendoredOpenAPIDocumentDefinesEveryAppOperation` fails until `iOS/OpenAPI/color-matching-api.json` is vendored. |
| Generate and wire the six used surfaces | Permanent local-stub client tests assert manifest/recent decoding plus capture, measurement, and judgment request/response behavior. The implementation run must add a local-stub ranked-results test against the generated operation; it cannot be written against a type that does not yet exist. | Existing `APIClientTests` cover capture, measurements, and judgments; `testFetchesManifestAndRecentSheetsFromLocalStubs` covers manifest/recent. |
| Replace hand-written API models while retaining client-side models | Compile the app and Swift tests after substituting generated types. Human code review checks that measurement/analysis domain types stay in `MeasurementCore`. | Not runnable during tests-only phase. |
| No live server in CI | Local `URLProtocol` stubs remain the permanent test seam. | `APIClientTests` uses `MockURLProtocol` only. |
| `swift test --disable-sandbox` green | Run after implementation and record its command output in the PR. | Expected red failure now: OpenAPI document has not been vendored. |

## Published-spec comparison (upstream issue #110 / merged PR #113)

The upstream spec is served at `GET /api/v1/openapi.json`; PR #113's `ApiSchemas` and controller operations are the inspectable published source used for this comparison.

- The prose contract describes a complete sheet manifest. The published `Manifest` schema currently requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. Generated manifest types therefore cannot safely replace `MeasurementCore.SheetManifest` until the upstream schema describes `page`, markers, patches, pairs, and the other fields the analyzer consumes.
- The prose contract leaves ranked-results response shape prose-only. The published `RankedResults` schema requires only `schema_version` and `sheet_id`; it does not yet specify the scores, labels, provenance, printer profile, or algorithm-version detail requested by the prose contract.
- The published capture schema accepts both the prose's nested `metadata` request and a legacy flat request. It requires `image_width` and `image_height` in each alternative, while the current hand-written `CaptureMetadata` makes both optional. Its nested `quality` object does not declare required fields.
- The published measurement schema omits the prose top-level `scoring_algorithm_version` and measurement `stats`; it requires `normalized_linear_rgb_median` where the current client allows it to be absent. It also returns a JSON acceptance summary with HTTP 200, whereas the hand-written client only validates a successful status and currently tests 204.
- The published judgments schema returns a JSON acceptance summary with HTTP 200, whereas the prose and current client only require success with no body.

These are endpoint/schema gaps, not a reason to hand-maintain a shadow contract. The implementation PR should vendor the exact published document, generate only operations whose schemas are sufficient, and report the two manifest/ranked-results gaps upstream before replacing the `MeasurementCore` boundary types.

## Implementation handoff

1. Vendor the exact `/api/v1/openapi.json` response at `iOS/OpenAPI/color-matching-api.json`, then make the red document test pass.
2. Add `swift-openapi-generator` and `swift-openapi-runtime`, generate the available client operations, and adapt the existing `APIClient` boundary without changing capture/scoring behavior.
3. Add an explicit local-stub test for the generated ranked-results operation once its generated response type exists, or leave it excluded and cite the upstream schema gap in the PR description.
4. Run `swift test --disable-sandbox`, then update the criterion evidence from red-phase status to the actual results.
