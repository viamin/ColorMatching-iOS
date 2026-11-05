# OpenAPI Client Migration: Verification and Contract Deltas

This test-writing change defines the acceptance evidence for #5. The implementation
run must replace the hand-written API transport and API-owned Codable models with a
client generated from the published `GET /api/v1/openapi.json` document. It must keep
measurement and UI-only models in `MeasurementCore` unless the generated contract owns
them.

## Criterion verification map

| Criterion | Smallest credible verification | Status in this tests-only change |
| --- | --- | --- |
| Generated client and vendored/fetched spec | `Package.swift` declares the generator/runtime and a reproducible spec-generation input is committed; `swift test --disable-sandbox` compiles it | Not run: implementation is intentionally deferred to the next phase |
| Manifest and recent sheets | Permanent URLProtocol stub tests decode upstream-shaped responses and assert route/authentication | Covered by `APIClientTests.testFetchManifestDecodesServerFixtureAndAuthorizesRequest` and `APIClientTests.testFetchRecentSheetsDecodesNullableTitleAndAuthorizesRequest` |
| Capture creation, measurement upload, and judgment upload | Permanent URLProtocol stub tests assert requests and typed responses | Existing tests require conversion to generated types in the implementation phase |
| Ranked results | Permanent URLProtocol stub test decodes a fixture from the generated ranked-results operation | Not covered: the current client exposes no ranked-results operation |
| Contract-delta report | Human-reviewable PR description cites the published OpenAPI endpoint and this evidence | Not run: no implementation PR exists in this tests-only phase |

The test stubs deliberately make no live-server call, so they are safe for CI and
remain useful after the generated transport replaces `APIClient`.

## Upstream evidence and deltas

Evidence was inspected on 2026-11-05 from [viamin/color_matching#110](https://github.com/viamin/color_matching/issues/110), its [router](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/router.ex), [capture controller](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/controllers/capture_controller.ex), and [API schemas](https://github.com/viamin/color_matching/blob/main/lib/color_matching_web/api_schemas.ex). The OpenAPI document is rendered dynamically by the service; it is not a static file in that repository.

- The prose contract says measurement and judgment uploads return `204`; the published API operation returns `200` with `capture_id` and count fields. The generated client must model the `200` responses.
- The published capture request accepts the existing nested `metadata`/`quality` shape, but also allows a legacy flattened shape. The app should keep using nested fields.
- The app currently sends `scoring_algorithm_version` and measurement `stats`; the published measurement-request schema does not describe either field. Confirm the rendered document and server acceptance when vendoring the spec, then either model them as supported fields or remove them with an intentional compatibility decision.
- The published manifest schema requires only `schema_version`, `sheet_id`, and `capture_profile.scoring_algorithm_version`; its rich page/marker/patch/pair payload is under-specified compared with the prose contract. Generated types alone cannot yet replace `SheetManifest` without a server-spec expansion.
- The ranked-results schema currently requires only `schema_version` and `sheet_id`; it does not model the scores, labels, provenance, printer profile, or algorithm version promised by the prose contract. The current iOS client also has no ranked-results call. This is an endpoint/spec gap that must be recorded in the implementation PR and escalated upstream rather than guessed.
