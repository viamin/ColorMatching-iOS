# Issue #5: generated OpenAPI Swift client

## Acceptance-criterion verification plan

| Criterion | Smallest credible verification | Status in this tests-only run |
| --- | --- | --- |
| Add and generate `swift-openapi-generator`/runtime client from the published spec | Inspect `Package.swift`, the vendored/fetched spec revision, and generated source in the implementation PR; compile with `swift test --disable-sandbox` | Not run: implementation files are prohibited in this run. |
| Preserve the app's manifest, recent sheets, capture creation, measurement upload, and judgment upload behavior | Permanent local-stub XCTest coverage in `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift`; the production facade will delegate to generated operations in the implementation run. | Covered by tests; currently exercised through the hand-written facade. |
| Ranked-results surface | Add a generated operation test only if the app is wired to consume it, or document the decision to leave it outside the app facade. | Not run: no ranked-results API call exists in the current app. |
| Record prose-contract versus published-spec deltas | Human review of this document against the upstream source revision and the generated source diff. | Recorded below; final implementation PR must retain/update this section. |

## Upstream evidence

- Upstream issue: `viamin/color_matching#110`, closed 2026-10-30.
- Published endpoint: `GET /api/v1/openapi.json`.
- Source inspected at `viamin/color_matching` commit `47057afd58f7d46b4d4b740ca7d2d08947774471` (main at review time), particularly `lib/color_matching_web/api_schemas.ex` and `lib/color_matching_web/controllers/test_sheet_controller.ex`.

## Contract deltas found

- The manifest schema only requires `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`. The prose contract and current client require a much fuller manifest shape (`sheet_version`, URL, page, markers, patches, and pairs). Generation must preserve the client-side geometry model or introduce an explicit adapter; generated manifest types alone are not sufficient for analysis.
- The real capture schema accepts either a legacy flat payload or the prose contract's nested `metadata` payload. Nested metadata requires image width and height; the current client-side model makes both optional, so the generated request adapter must reject/avoid an invalid upload before the server does.
- The spec describes measurement uploads without the prose contract's top-level `scoring_algorithm_version` or per-measurement `stats`, requires `normalized_linear_rgb_median`, and allows multiple RGB wire representations. The current client may omit normalized RGB and sends additional fields. This needs an adapter decision validated against generated types.
- Measurement and judgment uploads specify JSON success bodies with counts, while the hand-written client treats any 2xx response (including 204) as success and discards bodies.
- Ranked results is now a published endpoint with a `lps-ranked-results/v1` schema, but the iOS app has no ranked-results client method or caller. Do not add UI behavior merely to consume it; document whether the generated operation is retained for future use.
- The spec's `RecentSheetsResponse` requires the `title` key but permits a null value, matching the prose contract's nullable title.

## Endpoint gap to carry into the implementation PR

The issue requests a generated ranked-results operation even though no current iOS caller exists. Generate that operation if the generator permits operation filtering, but do not add a new app behavior. Add a direct local-stub test for it only when a small non-UI wrapper is introduced; otherwise identify it as generated-but-not-yet-consumed in the PR description.
