---
module: iOS
tags: [openapi, api-client, codegen, contract, testing]
problem_type: implementation_plan
---

# Generated OpenAPI Swift client — plan, contract deltas, and test contract

Status: tests-only (red phase) for issue #5. The tests in
`iOS/Tests/ColorMatchingLPSAppTests/GeneratedAPIClientTests.swift` and
`iOS/Tests/ColorMatchingLPSAppTests/RankedResultsFacadeTests.swift` define the contract the
implementation must satisfy. No implementation files exist yet; the tests will not compile
until the generated client target lands.

## Upstream dependency status

`viamin/color_matching#110` is complete: PR `viamin/color_matching#113` (merged 2026-10-30)
publishes an `open_api_spex` OpenAPI 3.0 spec for every `/api` route, serves it at
`GET /api/v1/openapi.json`, and validates requests/responses with
`OpenApiSpex.Plug.CastAndValidate`. The document can be vendored by running:

```
mix openapi.spec.json --spec ColorMatchingWeb.ApiSpec --filename openapi.json
```

in the Phoenix repo, or by fetching `/api/v1/openapi.json` from a running instance.

## Planned package integration (implementation contract)

- Add to `iOS/Package.swift`:
  - `apple/swift-openapi-generator` (provides the `OpenAPIGenerator` build-tool plugin)
  - `apple/swift-openapi-runtime` (product `OpenAPIRuntime`)
  - `apple/swift-openapi-urlsession-components` (product `OpenAPIURLSessionComponents`,
    `URLSessionTransport`) for the app target
- New target `ColorMatchingAPIClient` holding the vendored `openapi.json` and the
  `OpenAPIGenerator` plugin; all generated code is public in that module.
- `ColorMatchingLPSAppCore.APIClient` is rewritten to wrap the generated `Client`
  (server URL + `URLSessionTransport` + bearer `ClientMiddleware`), keeping its
  throwing-on-non-2xx behavior (`APIError.badStatus`).
- `ColorMatchingLPSAppTests` gains dependencies on `ColorMatchingAPIClient`,
  `OpenAPIRuntime`, and `HTTPTypes`; the two new test files import those modules.
- The Xcode project (`ColorMatchingLPS.xcodeproj`) must reference the new files/targets so
  the CI `xcodebuild test` phase compiles them (SwiftPM `swift test` picks them up
  automatically).

## Operation IDs and generated method names

OpenApiSpex derives operation IDs as `Module.Controller.action`. swift-openapi-generator
(SOAR-0013 idiomatic naming) maps `.` → `_` (no capitalization) and `_` → word split:

| Path | Operation ID | Generated client method |
| --- | --- | --- |
| GET `/api/v1/test_sheets/{sheet_id}/manifest` | `ColorMatchingWeb.TestSheetController.manifest` | `colorMatchingWeb_TestSheetController_manifest` |
| GET `/api/v1/test_sheets/recent` | `ColorMatchingWeb.TestSheetController.recent` | `colorMatchingWeb_TestSheetController_recent` |
| GET `/api/v1/test_sheets/{sheet_id}/ranked_results` | `ColorMatchingWeb.TestSheetController.ranked_results` | `colorMatchingWeb_TestSheetController_rankedResults` |
| POST `/api/v1/test_sheets/{sheet_id}/captures` | `ColorMatchingWeb.CaptureController.create` | `colorMatchingWeb_CaptureController_create` |
| POST `/api/v1/captures/{capture_id}/measurements` | `ColorMatchingWeb.CaptureController.upload_measurements` | `colorMatchingWeb_CaptureController_uploadMeasurements` |
| POST `/api/v1/captures/{capture_id}/judgments` | `ColorMatchingWeb.CaptureController.upload_judgments` | `colorMatchingWeb_CaptureController_uploadJudgments` |

Schema names map 1:1 (`Components.Schemas.TestSheetManifest`, `RecentSheetsResponse`,
`CaptureRequest`, `CaptureMetadata`, `CaptureCreatedResponse`, `MeasurementUploadRequest`,
`PairScoreRequest`, `JudgmentUploadRequest`, `JudgmentUploadResponse`,
`MeasurementUploadResponse`, `RankedResults`, `ApiErrorResponse`, `RgbPayload`), with
snake_case properties lowerCamelCased (`sheet_id` → `sheetId`).

## Contract deltas: prose contract vs published spec

Baseline: `docs/color-matching-api-contract.md` vs the spec/implementation published in
`viamin/color_matching#113` (schemas in `ColorMatchingWeb.ApiSchemas`, response shapes in
`ColorMatchingWeb.TestSheetJSON`). These deltas must be recorded in the PR description.

1. **Manifest schema under-documents the payload.** The spec documents only
   `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version` as
   required properties; the actual renderer also returns `sheet_version`, `manifest_url`,
   `created_at`, `page`, `registration_markers`, `printer_profile`, `patches`, and `pairs`
   (matching the prose contract). The generated manifest type therefore only exposes the
   three documented fields and silently ignores the rest — the app must keep its
   `MeasurementCore` manifest decoding (client-side, trusted by fetch-and-decode) until the
   upstream spec expands. The stub test pins that decoding tolerates the full real payload.
2. **Patch IDs and printer profile fields differ from the prose examples.** Actual patch
   IDs are `"{pair_id}#first"` / `"{pair_id}#second"` (prose example: `patch_1`), and
   `printer_profile` uses `printer_make_model`/`paper_type`/`ink_type`/`icc_profile`/
   `print_settings`/`driver_name`/`driver_version`/`calibration_date`/
   `calibration_version`/`notes` (prose: `id`/`name`/`paper`/`ink`/`settings`).
3. **`CaptureRequest` combines `properties` with `anyOf` siblings.** OpenAPI 3.0 allows
   sibling keywords, and OpenApiSpex emits both, but OpenAPIKit (and therefore
   swift-openapi-generator) reads `anyOf` and drops the sibling `type`/`properties`. The
   generated `CaptureRequest` exposes only empty `value1`/`value2` payload structs — it
   cannot express the nested `metadata`/`quality` body the app (and prose contract) send.
   The capture-create test pins only path/method/response decoding and constructs the
   hollow body. **Endpoint gap:** color_matching should either drop the flat variant or
   express the request with `allOf` so generated clients can send a valid body.
4. **`PairScoreRequest` has the same `anyOf` sibling problem.** The generated type cannot
   express `pair_id`/`algorithm_version`/`distance`; the measurement-upload test therefore
   sends only `measurements` (which are pure object schemas and fully expressible) and
   omits `pair_scores` (optional in the spec). **Endpoint gap**, same fix as above.
5. **Measurement upload payload is thinner than the prose contract.** The spec has no
   top-level `scoring_algorithm_version` and no per-measurement `stats`
   (`sample_count`/`clipping_fraction`/`mean`/`standard_deviation`); the server ignores
   extra keys today, but the generated client cannot send them. Also
   `normalized_linear_rgb_median` is required in the spec (optional in prose), and
   `RgbPayload` accepts an RGB array, `{r,g,b}` object, or string (prose: object only).
   The test exercises all three encodings.
6. **Upload endpoints return `200` with a JSON body, not `204`.** Both measurement and
   judgment uploads respond with `capture_id` plus `measurement_count`/`pair_score_count`
   or `judgment_count`. The tests decode these counts.
7. **Ranked results had no prose schema.** The spec documents only `schema_version`
   (`lps-ranked-results/v1`) and `sheet_id`; the actual payload additionally carries
   printer profile, capture counts/timestamps, algorithm versions, and per-pair
   rank/scores/current judgment/observation provenance. The generated type exposes only
   the two documented fields; the ranked-results tests decode from the full real payload
   and assert the documented subset. Endpoint gap: spec should document the full shape
   before the app UI can consume it via generated types.
8. **Recent sheets match the prose contract**, except `title` is always `null` in the
   current implementation (nullable in the spec, optional in prose).
9. **Judgment strings are unconstrained.** The prose allowed-values
   (`match`/`near_match`/`no_match`) are not an enum in the spec, so drift there stays a
   runtime concern.
10. **Auth is a documented security scheme, not a header parameter.** The generated client
    cannot send `Authorization` from generated inputs; the facade must attach the bearer
    token via a `ClientMiddleware`. The facade test asserts the header at the URL level.
11. **`iso` is an integer in the spec** (prose implies a number); `date-time` fields decode
    as `String` in generated types (no `Foundation.Date` conversion).

## Test plan mapping

- Generated-client surfaces (manifest, recent sheets, capture creation, measurement
  upload, judgment upload, ranked results, documented 404): permanent unit tests in
  `GeneratedAPIClientTests.swift`, driven by a stub `ClientTransport` (no live server; CI
  safe).
- Facade ranked-results behavior (path, bearer token, generated payload, non-2xx error):
  permanent unit tests in `RankedResultsFacadeTests.swift` using `URLProtocol` stubbing,
  consistent with the existing `APIClientTests.swift` style.
- Existing `APIClientTests.swift` remains the facade wire-format contract for
  capture/measurement/judgment and should keep passing once the facade is rebuilt on
  generated types (public behavior preserved: paths, bearer token, snake_case wire JSON,
  throwing on non-2xx).

## Notes for the implementation run

- If regenerated names differ from the ones used in the tests (e.g., a newer generator
  changes `anyOf` construction or plugin naming), update the tests to the actual generated
  API while keeping the assertions (paths, methods, operation IDs, wire JSON keys, decoded
  documented fields) unchanged — those assertions are the contract.
- The JSON fixtures mirror `ColorMatchingWeb.TestSheetJSON` output exactly; keep them
  authoritative when regenerating.
- Exit criterion: `swift test --disable-sandbox` green on macOS CI with generated types
  wired in; the flag is required for build-tool plugins on Linux and harmless on macOS.
