# Generated OpenAPI Client Migration Evidence

This is the draft PR description and acceptance-criterion evidence for issue #5.
It is intentionally checked in during the test-writing phase so the implementation
PR has an auditable contract baseline.

## Verification Plan

| Criterion | Smallest credible verification | Evidence at this commit |
| --- | --- | --- |
| Swift OpenAPI dependencies and a pinned OpenAPI input are configured | Focused XCTest inspects the package declaration for the generator, runtime, plugin, and spec input | `APIClientTests.testPackageDeclaresGeneratedOpenAPIClientAndPinnedSpecInput` (red until implementation) |
| Manifest and recent-sheet reads use typed generated operations | Permanent local-stub XCTest asserts the route, bearer authentication, and decoded response | `APIClientTests.testFetchManifestDecodesPublishedManifestShapeFromStub`; `APIClientTests.testFetchRecentSheetsDecodesNullableTitleFromStub` |
| Capture creation, measurement upload, and judgment upload use generated operations | Permanent local-stub XCTest asserts the request route/payload and success response | `APIClientTests.testCreateCaptureEncodesMetadataAndQuality`; `APIClientTests.testUploadMeasurementsEncodesScoresWithAlgorithmVersion`; `APIClientTests.testUploadJudgmentsEncodesPathAndPayload` |
| Ranked-results operation is generated and wired into the app | Permanent local-stub XCTest must call the generated ranked-results operation and decode a real-result fixture | Not yet representable without the generated target; implementation must add this test before marking the criterion passed |
| Prose-contract deltas are recorded | Inspectable comparison of the current upstream OpenAPI source and this repository's prose contract | This document, “Contract Deltas” below |
| `swift test --disable-sandbox` passes | Execute the exact command after Swift is available | Not run: this container has no `swift` executable |

## Upstream Spec Evidence

The source service publishes OpenAPI dynamically at
`GET /api/v1/openapi.json`. The comparison below used
[`ColorMatchingWeb.ApiSpec`](https://github.com/viamin/color_matching/blob/47057afd58f7d46b4b740ca7d2d08947774471/lib/color_matching_web/api_spec.ex),
[`ApiSchemas`](https://github.com/viamin/color_matching/blob/47057afd58f7d46b4b740ca7d2d08947774471/lib/color_matching_web/api_schemas.ex),
and the
[`Router`](https://github.com/viamin/color_matching/blob/47057afd58f7d46b4b740ca7d2d08947774471/lib/color_matching_web/router.ex)
at upstream commit `47057afd58f7d46b4b740ca7d2d08947774471`.

The implementation must vendor the fetched JSON response, with that commit or a
newer reviewed revision recorded beside it. It must not generate from this
repository's prose contract.

## Contract Deltas And Endpoint Gaps

- The published API adds `GET /api/v1/openapi.json`; all six companion routes
  from the prose contract are present and protected by bearer authentication.
- Capture creation accepts both the prose contract's nested `metadata`/`quality`
  payload and a legacy flat payload. Its published schema only requires metadata
  fields `device_model`, `lens`, `image_width`, `image_height`, `app_version`,
  and `timestamp`; the prose contract presents more fields as mandatory-looking.
  The published schema uses an integer `iso`, while the hand-written Swift model
  currently uses `Float`.
- The capture, measurement, and judgment endpoints publish JSON `201`/`200`
  success responses. The hand-written client currently treats the two upload
  responses as empty `204` responses, so the generated client must decode or
  explicitly discard their documented JSON bodies.
- The published measurement request declares per-pair `algorithm_version` and
  accepts `score`, `similarity`, or `distance`; the prose contract additionally
  sends a top-level `scoring_algorithm_version` and nested measurement `stats`.
  Upstream controller coverage confirms those compatibility fields are accepted,
  but the OpenAPI schema does not describe them. This is a generator-blocking
  schema gap if the app must keep uploading those fields.
- The published manifest schema describes only `schema_version`, `sheet_id`, and
  `capture_profile.scoring_algorithm_version`. The iOS app needs page geometry,
  markers, patches, and pairs; the prose contract describes those fields, but
  the OpenAPI schema omits them. A generated manifest type therefore cannot
  replace `SheetManifest` without an upstream schema expansion.
- The published ranked-results schema similarly declares only `schema_version`
  and `sheet_id`. The running endpoint returns rankings, scores, source colors,
  printer profile, provenance, and judgments, as demonstrated by upstream
  `ranked_results_controller_test.exs`; these fields are missing from the
  published schema. This is a second generator-blocking endpoint gap.

## Merge Gate

Do not mark this issue complete until the two schema gaps are resolved upstream
or the PR explicitly documents a reviewed, typed compatibility layer that does
not reintroduce hand-written API models. The implementation PR must update this
record with the vendored spec SHA, add the ranked-results stub test, and replace
the red package-configuration assertion with green generated-client coverage.
