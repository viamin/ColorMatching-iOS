# Generated OpenAPI Client — Test-First Plan (Issue #5)

Plan for replacing the hand-written API layer with a generated OpenAPI Swift
client (`swift-openapi-generator` + `swift-openapi-runtime`). This document is
committed with the red-phase tests so the implementation change set has a
pre-agreed verification plan.

Depends on viamin/color_matching#110 publishing a machine-readable OpenAPI spec
that covers the sheet/capture endpoints.

## Acceptance criteria → verification mapping

| ID | Criterion (from issue #5) | Verification kind | Locator |
|----|---------------------------|-------------------|---------|
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` in the iOS package; OpenAPI document vendored | `unit_or_service_test` (spec presence/coverage) + implementation diff | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPISpecCoverageTests.swift` |
| AC-2 | Generated client for all six surfaces (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results) | `unit_or_service_test` (stubbed transport, per-surface tests) | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientTests.swift` |
| AC-3 | Hand-written API models replaced by generated types; purely client-side models kept | Wire-format assertions in AC-2 tests + PR diff review (human) | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientTests.swift` |
| AC-4 | Swift tests exercising the generated client against local stubbed responses, no live server | `unit_or_service_test` (StubTransport) | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientTests.swift` |
| AC-5 | PR description records contract deltas and endpoint gaps | `human_or_external_evidence` (delta checklist below, filled in PR body) | checklist below |

No live server is used anywhere: `OpenAPIClientTests` drives the generated
client through a test `ClientTransport` that returns canned
`HTTPResponse`/`HTTPBody` values and records outbound requests.
`OpenAPISpecCoverageTests` reads only the vendored JSON document from disk.

## Red-phase mechanism

`OpenAPIClientTests` is gated with `#if canImport(ColorMatchingOpenAPI)`.
Until the generated client target exists, every test method reports a failure
explaining what is missing. `OpenAPISpecCoverageTests` is not gated; it fails
until the vendored document exists at the expected path. Both failure sets are
the expected red phase for this tests-only PR.

## Naming contract the tests encode

The published spec does not exist in this repo yet, so the tests pin the
surface the app needs, derived from `docs/color-matching-api-contract.md`.
If viamin/color_matching#110 names anything differently, adjust the tests and
record the delta in the PR description (AC-5) — the test diff then becomes the
visible regeneration drift the issue asks for.

Implementation contract for the implementation run:

- New SwiftPM target `ColorMatchingOpenAPI` at `iOS/Sources/ColorMatchingOpenAPI/`,
  built with the `OpenAPIGenerator` plugin (`apple/swift-openapi-generator`)
  and depending on `apple/swift-openapi-runtime`.
- Vendored spec is JSON, not YAML, at
  `iOS/Sources/ColorMatchingOpenAPI/openapi.json`, so tests can parse it with
  `JSONSerialization` (no YAML dependency) and drift shows as reviewable diffs.
- Both test targets' dependencies gain `ColorMatchingOpenAPI` and the
  `OpenAPIRuntime` product.
- Operation IDs (method names on the generated `Client`):
  `getTestSheetManifest`, `getRecentTestSheets`, `createCapture`,
  `uploadMeasurements`, `uploadJudgments`, `getRankedResults`.
- Component schema names: `SheetManifest`, `Page`, `RegistrationMarker`,
  `Rect`, `Patch`, `Pair`, `RecentSheet`, `RecentSheetsResponse`,
  `CreateCaptureRequest`, `CaptureMetadata`, `WhiteBalanceGains`,
  `CaptureQuality`, `CaptureSessionResponse`, `MeasurementUploadRequest`,
  `MeasurementUpload`, `RGB`, `MeasurementStats`, `PairScore`,
  `JudgmentUploadRequest`, `PairJudgment`, `RankedResultsResponse`,
  `RankedPair`.
- Generated property/parameter names are camelCase (`sheetId`, `safeInsetMm`);
  wire keys stay snake_case (`sheet_id`, `safe_inset_mm`) — asserted by the
  request-body checks.
- Response status codes: 200 (manifest, recent sheets, ranked results),
  201 (capture creation), 204 (measurement and judgment uploads).
- `timestamp` is `format: date-time` (runtime default transcoder is ISO8601).
- Path parameter structs use camelCase (`sheetId`, `captureId`).
- `manifest_url` decodes as a Swift `String` (the generator does not produce
  `URL` values).
- Bearer auth stays in app code (middleware or explicit header), not in these
  tests; the prose contract allows unauthenticated development requests.

## What the tests assert per surface

For every surface: the generated method name (via recorded `operationID`),
HTTP method, templated path with substituted path parameters, JSON wire keys of
request bodies, and decoding of response payloads (including the optional
`title` on recent sheets and the optional `judgment` on ranked pairs).

## Contract deltas and endpoint gaps (AC-5 evidence)

Gaps already visible when comparing the prose contract with what the app and
tests need — the implementation run must confirm each against the published
spec and record the outcome in the PR description:

1. `GET /api/v1/test_sheets/:sheet_id/ranked_results` has no response schema in
   the prose contract. The tests pin a minimal shape
   (`sheet_id`, `scoring_algorithm_version`, `pairs[]` with `pair_id`,
   `source_colors`, `distance`, `similarity`, optional `judgment`). Endpoint
   gap if the published spec omits this endpoint entirely.
2. Success status codes are unspecified in prose. Tests assume 200/201/204 per
   endpoint.
3. No error response shapes (4xx/5xx schemas) are specified in prose; tests
   currently treat only declared success responses.
4. Prose shows `created_at` on the manifest, but the hand-written
   `SheetManifest` model never decoded it — decide whether the spec keeps it.
5. Prose lists `printer_profile` and `capture_profile` on the manifest; the
   hand-written model dropped both. Decide whether to decode them.
6. Auth is prose-only ("shared bearer token") with no security scheme
   definition; the spec should declare `bearerAuth` for regeneration to type it.
7. Judgment values (`match`/`near_match`/`no_match`) and capture rejection
   strings are enumerated in prose only. Tests assume plain strings; an enum in
   the spec changes the generated types.

## Exit criteria mapping

- `swift test --disable-sandbox` green with generated types wired in: after the
  implementation run, the `#if canImport` gate takes the real branch, the
  `#else` failures disappear, and `OpenAPISpecCoverageTests` passes against the
  vendored document.
- PR description captures contract deltas: fill the checklist above from the
  published spec and copy the results into the PR body.
