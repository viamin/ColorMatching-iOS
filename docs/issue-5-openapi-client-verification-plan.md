# Issue #5 OpenAPI Client Verification Plan

## Acceptance-criterion map

| Criterion | Smallest credible verification | Status in tests-only phase |
| --- | --- | --- |
| Add generator/runtime dependencies and a vendored or fetched OpenAPI document | `APIClientTests.testPackageConfiguresGeneratedOpenAPIClientForAllCompanionOperations` inspects the SwiftPM manifest for both packages and generator/runtime targets; implementation must add the spec and generator configuration named by that assertion. | Failing as intended: the hand-written client remains. |
| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Local URLProtocol stubs permanently exercise the existing public manifest/recent/capture/measurement/judgment boundary. `Fixtures/ranked-results.json` preserves an actual ranked-results response for the generated-client test added in the implementation phase; no ranked-results API exists in the app today. | Partial; endpoint implementation is absent. |
| Replace server-owned hand-written models with generated types | Compile the app against generated operations and retain these local-stub tests. This cannot be proven until the generated target exists. | Not run. |
| Swift tests use local stubs, not a live server | `APIClientTests` uses `MockURLProtocol` with bundled JSON fixtures. | Passing by inspection; Swift is unavailable in this Linux container. |
| PR records prose-contract deltas and endpoint gaps | This document’s next section records a source-backed comparison. | Complete for the tests-only draft. |

## Published-spec comparison and endpoint gaps

External evidence was inspected from the closed dependency issue [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110) and its current source: [`ApiSchemas`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_schemas.ex), [`TestSheetJSON`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/test_sheet_json.ex), and [`CaptureController`](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/capture_controller.ex).

- The published OpenAPI endpoint exists at `GET /api/v1/openapi.json` and declares all six companion routes.
- The manifest schema declares only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`, while the actual manifest includes page geometry, markers, printer/capture profiles, patches, and pairs required by the iOS analyzer. A generated manifest type from the current document cannot replace `SheetManifest` without expanding the upstream schema.
- The ranked-results schema declares only `schema_version` and `sheet_id`, while the actual response contains printer profile, aggregate counts/timestamps, algorithm versions, and per-pair ranking/score/judgment data. The app has no ranked-results method today; the fixture records the actual response shape for the follow-up generated-client test.
- The capture schema permits a legacy flat payload or nested `metadata`; it omits required `quality` properties. `iso` is declared as an integer whereas the app’s client model is `Float`.
- The measurements schema omits the top-level `scoring_algorithm_version` and each measurement’s `stats`, both sent by the prose contract/current client. It requires normalized RGB, whereas the existing client model permits it to be absent.
- Measurement and judgment uploads now document JSON success bodies with capture and count fields; the prose contract/current client treats success as bodyless. The generated client should decode or consciously discard these typed responses.
- Recent sheets matches the prose shape, except `manifest_url` is a plain string rather than an OpenAPI `uri`-formatted string.

The implementation PR description should carry this section forward and either link an upstream schema-expansion issue or state the chosen compatibility strategy for the incomplete manifest and ranked-results schemas.
