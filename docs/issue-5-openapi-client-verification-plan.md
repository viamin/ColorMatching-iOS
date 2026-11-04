# Issue #5 OpenAPI Client Verification Plan

This is the test-first plan for replacing the iOS hand-written API layer with
the OpenAPI-generated client. The provider dependency,
[viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110),
is closed. Its specification is served dynamically from
`GET /api/v1/openapi.json`; it is not committed as a standalone JSON document.

## Criterion coverage

| Criterion | Smallest credible verification | Evidence at this revision |
| --- | --- | --- |
| Add the generator/runtime and vendor or fetch the provider document | Package resolution plus a reviewed, pinned OpenAPI artifact and generator configuration | Implementation-phase check; no implementation is permitted in this test-writing run. |
| Generate each app API surface | Local `URLProtocol` stub tests through the app-facing generated-client adapter: manifest, recent sheets, create capture, measurement upload, judgment upload, and ranked results | Existing capture/upload tests and the manifest/recent tests in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; ranked-results adapter test must be added with the generated client because the current facade has no ranked-results operation. |
| Remove server DTOs while retaining client-side models | Compile the app plus source review that `MeasurementCore` remains client-only and server request/response DTOs come from the generated target | Implementation-phase source/compile check. |
| Stubbed Swift client tests | Permanent XCTest tests using `MockURLProtocol`; no live server or database | `APIClientTests.swift` stubs the server responses and requests. |
| PR records contract deltas and endpoint gaps | Inspectable comparison against provider route, controller, renderer, and OpenAPI schema sources | Contract delta record below. |

The manifest and recent-sheets tests were added before the generated-client
implementation so the adapter must preserve the app behavior while changing
its transport/types. Capture, measurement, and judgment tests already exercise
the remaining current upload calls. Ranked results is intentionally called out
as a missing public client operation rather than silently treating a broad test
suite as coverage.

## Prose contract versus provider specification

Provider sources reviewed at `main`:

- [`router.ex`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex)
- [`api_schemas.ex`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_schemas.ex)
- [`test_sheet_controller.ex`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/test_sheet_controller.ex)
- [`test_sheet_json.ex`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/test_sheet_json.ex)
- [`capture_controller.ex`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/capture_controller.ex)

| Surface | Delta / gap | Implementation consequence |
| --- | --- | --- |
| OpenAPI retrieval | `/api/v1/openapi.json` is in the unauthenticated API pipeline; the prose contract describes bearer authentication generally. The provider builds the document at runtime rather than committing it. | Fetch and pin/vendor the response during generation; do not require an API token to retrieve it. |
| Manifest | The prose sample includes a rich printer profile, `created_at`, complete geometry, and patches. The OpenAPI `Manifest` schema only requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; the renderer’s printer-profile shape also differs from the prose sample. | Preserve the app’s client-side geometry model, but do not assume the generated schema exposes every rendered manifest field until the provider strengthens the schema. |
| Recent sheets | The response shape matches the prose contract. The spec explicitly makes `title` required and nullable. | Verify a `null` title, as the local stub does. |
| Create capture | The provider accepts both the nested `metadata`/`quality` form in the prose contract and a legacy flattened form. Its metadata schema requires image dimensions and uses an integer ISO, while the hand-written Swift model permits optional dimensions and uses `Float`. | An adapter must validate/convert client capture data before constructing generated request types. |
| Measurement upload | The prose request includes `scoring_algorithm_version` and nested statistics. The provider OpenAPI schema omits both, requires `normalized_linear_rgb_median`, and accepts RGB arrays, objects, or encoded strings. The endpoint returns `200` with capture and count fields; the prose contract gives no response body. | Keep scoring/statistics client-side unless the provider schema is expanded; consume the generated success response rather than assuming an empty `204`. |
| Judgment upload | Request shape agrees. The provider returns `200` with `capture_id` and `judgment_count`, which the prose contract omits. | Model the generated success response even if the UI does not display it yet. |
| Ranked results | The prose only promises a qualitative response. The provider renderer emits `lps-ranked-results/v1` plus ranks, score aggregates, judgment/capture provenance, and printer profile. But the published OpenAPI schema only requires `schema_version` and `sheet_id`. The current iOS `APIClient` exposes no ranked-results method. | This is the material endpoint gap: add a generated-client adapter and a permanent local-stub test, and ask the provider to describe the full response schema before relying on generated fields beyond its two required properties. |

## Test status for this run

`swift package resolve` and `swift test --disable-sandbox` cannot run in this
container because the Swift executable is absent. This is an environment
limitation, not passing evidence; implementation and CI must run the permanent
XCTest target before merge.
