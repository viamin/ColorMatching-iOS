# Issue #5: generated OpenAPI client verification plan

This is the PR-description source for replacing the iOS hand-written `/api/v1` client. It records the acceptance-criterion evidence plan and the contract comparison made against `viamin/color_matching#110` at its closed `main` state.

## Criterion verification map

| Criterion | Smallest credible verification | Evidence at implementation completion |
| --- | --- | --- |
| The package includes `swift-openapi-generator` and `swift-openapi-runtime`, and vendors the upstream document | Focused package/spec guard | `iOS/Package.swift` dependency declarations plus `APIClientTests.testVendoredOpenAPISpecDeclaresEveryAppOperation` |
| The generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local-stub client tests, one response fixture per operation | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; no live-server dependency |
| Hand-written API transport models are replaced while measurement-only models remain client-side | Human code review of the generated target and app adapter | PR diff inspection; this cannot be established by a broad test-suite result |
| Generated requests and responses work without a live service | Permanent focused integration tests using `MockURLProtocol` | `APIClientTests` passing under `swift test --disable-sandbox` |
| The PR records contract deltas and endpoint gaps | Inspectable human/external evidence | This document and the PR description |

The tests must be written against a URL-protocol stub, not a real server. `testFetchManifestAcceptsThePublishedOpenAPIMinimumResponse` is intentionally red until the generated manifest type is wired into the app adapter; it uses the minimum response declared by the upstream OpenAPI schema.

## Published-spec comparison

Source inspected: `viamin/color_matching` `main`, `lib/color_matching_web/api_schemas.ex`, `lib/color_matching_web/controllers/test_sheet_controller.ex`, and `lib/color_matching_web/controllers/capture_controller.ex` (issue [#110](https://github.com/viamin/color_matching/issues/110)). The served document is `GET /api/v1/openapi.json`.

| Surface | Prose contract | Published OpenAPI behavior | Implementation consequence |
| --- | --- | --- | --- |
| Manifest | Describes page geometry, markers, profiles, patches, and pairs | Requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` | The published spec is too sparse to generate the app’s currently required sheet-analysis manifest shape. Preserve/define an adapter only after upstream expands the schema. |
| Recent sheets | `title` nullable | `title` required but nullable | Generated type must accept `null`; the local stub covers it. |
| Capture creation | Nested `{metadata, quality}` payload; response is `201 {capture_id}` | Allows either legacy flat fields or nested `metadata`; `quality` is not required; response matches `201 {capture_id}` | Use the generated nested request form and retain client-side capture analysis as input conversion. |
| Measurement upload | Top-level `scoring_algorithm_version`, per-row stats, `204` empty response | No top-level scoring version or stats requirement; normalized RGB is required; score can be `score`, `similarity`, or `distance`; returns `200` JSON counts | Change the adapter to consume the generated acknowledgement response and resolve whether the server accepts/prohibits the extra prose-only fields. |
| Judgment upload | `204` empty response | `200 {capture_id, judgment_count}` | Decode the generated acknowledgement response rather than discarding it. |
| Ranked results | Requires source colors, scores, labels, capture provenance, printer profile, and algorithm version | The operation exists, but its schema requires only `schema_version` and `sheet_id` | Endpoint gap: upstream must specify the actual ranked-result payload before a useful typed client can replace a hand-written model. |

## Current red-phase status

- The manifest minimum-response test fails against the current hand-written `SheetManifest`, which requires prose-only fields such as `sheet_version`, `manifest_url`, `page`, `registration_markers`, `patches`, and `pairs`.
- The spec-operation guard fails because this repository does not yet vendor `OpenAPI/color-matching-api.json`.
- Capture, measurement, and judgment request-stub tests already exist and must be updated to assert generated request/response types once the generator is introduced.
