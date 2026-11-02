# Generated OpenAPI Client Plan (issue #5)

Status: **tests-first red phase**. This document records the test plan for replacing the
hand-written API layer with a generated OpenAPI Swift client, the exact contract the new
tests pin, and the contract deltas discovered between `docs/color-matching-api-contract.md`
and what the app actually does today.

The upstream dependency is the machine-readable OpenAPI document from
`viamin/color_matching#110`. That spec could not be fetched from this environment (the
GitHub API proxy in this container only allows this repository), so this plan defines the
spec surface the tests require; the implementation run must vendor the real document from
`viamin/color_matching#110`, reconcile it against the tables below, and record the
remaining deltas in the PR description.

## Acceptance criteria and verification

| AC | Verification | Evidence |
|----|--------------|----------|
| `swift-openapi-generator` + `swift-openapi-runtime` added; OpenAPI document fetched/vendored | Package wiring is implementation-phase work (blocked in a tests-only run); verified by the generated-client tests compiling and passing in CI | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` (red until the module exists) |
| Client generated for: manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | One focused test per surface against a stubbed `ClientTransport`; asserts operation ID, method, path, headers, snake_case wire body, and decoded generated types | `GeneratedClientTests.swift` — six tests listed below |
| Hand-written API models replaced with generated types; purely client-side models kept | Wire-contract tests through the `APIClient` facade pin today's behavior; they must stay green after the model swap | `APIClientContractTests.swift` (green today) + existing `APIClientTests.swift` |
| Tests use stubbed responses, no live server in CI | Tests stub `ClientTransport` / `URLProtocol` only; no network I/O | Same files; no `URLSession.shared` usage in tests |
| PR description records contract deltas and endpoint gaps | Deltas captured in "Contract deltas" below; final PR description must carry them plus any deltas found when the real spec is vendored | This document |

## Tests

Permanent suites at `iOS/Tests/ColorMatchingLPSAppTests/`:

- `GeneratedClientTests.swift` — exercises the generated `ColorMatchingOpenAPI.Client`
  against `RecordingTransport` (a `ClientTransport` stub). One test per operation:
  `testGetTestSheetManifestSendsGETAndDecodesManifest`,
  `testGetRecentTestSheetsDecodesSheetsIncludingNullTitle`,
  `testCreateCaptureEncodesMetadataQualityAndDecodesCaptureID`,
  `testUploadMeasurementsEncodesSnakeCasePayloadAndAcceptsNoContent`,
  `testUploadJudgmentsEncodesJudgmentWireValue`,
  `testGetRankedResultsDecodesRankedPairs`.
- `APIClientContractTests.swift` — pins the current facade wire contract (manifest
  decode + GET/Authorization/path, recent sheets with `title: null`) so the migration to
  generated types cannot regress observable behavior.

Expected red-phase failure mode: `GeneratedClientTests.swift` and
`GeneratedClientTestSupport.swift` cannot compile until the implementation adds the
`OpenAPIRuntime` dependency and the `ColorMatchingOpenAPI` target — the missing module IS
the missing-behavior signal. `swift test --disable-sandbox` must be green once the
implementation run lands.

## Required package layout (implementation run)

- Vendor the spec at `iOS/OpenAPI/color-matching.yaml` (from `viamin/color_matching#110`,
  reconciled with the tables below).
- New target `ColorMatchingOpenAPI`: library, dependency
  `OpenAPIRuntime` (from `apple/swift-openapi-runtime`), plugin `OpenAPIGenerator`
  (from `apple/swift-openapi-generator`), with `openapi-generator.yml` setting
  `access: public`.
- `ColorMatchingLPSAppTests` test target gains dependencies on `ColorMatchingOpenAPI`
  and `OpenAPIRuntime`.

If the pinned `OpenAPIRuntime` version differs in a helper API used by
`GeneratedClientTestSupport.swift` (e.g. `HTTPBody.collect(upTo:)` / `HTTPBody.data`),
adjust that single helper; the assertions in the tests must remain unchanged.

## Operation contract the tests pin

`serverURL` passed to the client is `https://example.test/api/v1`; spec paths are
relative to `/api/v1`.

| operationID | Method & path | Request body | Success response |
|-------------|---------------|--------------|------------------|
| `getTestSheetManifest` | GET `/test_sheets/{sheet_id}/manifest` | — | `200` `SheetManifest` |
| `getRecentTestSheets` | GET `/test_sheets/recent` | — | `200` `RecentSheetsResponse` |
| `createCapture` | POST `/test_sheets/{sheet_id}/captures` | `CreateCaptureRequest` | `201` `CaptureSessionResponse` |
| `uploadMeasurements` | POST `/captures/{capture_id}/measurements` | `MeasurementUploadRequest` | `204` no content |
| `uploadJudgments` | POST `/captures/{capture_id}/judgments` | `JudgmentUploadRequest` | `204` no content |
| `getRankedResults` | GET `/test_sheets/{sheet_id}/ranked_results` | — | `200` `RankedResultsResponse` |

Path parameters: `sheet_id`, `capture_id` (Swift: `sheetID`, `captureID`).

## Schema components (`Components.Schemas.*`)

Property order below is the memberwise-init order the tests use.

- `SheetManifest`: `schemaVersion`, `sheetVersion`, `sheetID`, `manifestURL`, `createdAt`
  (date-time), `page`, `registrationMarkers`, `printerProfile`, `captureProfile`,
  `patches`, `pairs`.
- `PageSize`: `units`, `width`, `height`.
- `RegistrationMarker`: `role`, `shape`, `rect`.
- `Rect`: `x`, `y`, `width`, `height`.
- `PrinterProfile`: `id`, `name`, `paper`, `ink`, `settings` (free-form object).
- `CaptureProfile`: `expectedIlluminant`, `preferredCamera`, `scoringAlgorithmVersion`.
- `Patch`: `id`, `role` (`PatchRole`: `pair_color`, `reference`), `pairID?`, `pairSide?`
  (`PairSide`: `first`, `second`), `referenceRole?` (`ReferenceRole`: `white`, `gray`,
  `black`, `blank_paper`), `sourceColor?`, `safeInsetMM`, `rect`.
- `PairManifest`: `id`, `firstPatchID`, `secondPatchID`, `sourceColors`, `gridRow`, `gridCol`.
- `RecentSheetsResponse`: `sheets` (`[RecentSheetSummary]`).
- `RecentSheetSummary`: `sheetID`, `manifestURL`, `title` (nullable string).
- `CreateCaptureRequest`: `metadata`, `quality`.
- `CaptureMetadata`: `deviceModel`, `lens`, `exposureDurationSeconds?`, `iso?`,
  `focusLensPosition?`, `whiteBalanceGains?`, `imageWidth?`, `imageHeight?`,
  `appVersion`, `timestamp` (date-time).
- `WhiteBalanceGains`: `red`, `green`, `blue`.
- `CaptureQuality`: `detectedMarkerCount`, `blurScore`,
  `rejections` (`[CaptureRejection]`: `missingRegistrationMarks`,
  `incompleteSheetCoverage`, `clipping`, `excessiveBlur`, `glare`, `poorReferencePatch`).
- `CaptureSessionResponse`: `captureID`.
- `MeasurementUploadRequest`: `scoringAlgorithmVersion`, `measurements`, `pairScores`.
- `PatchMeasurementUpload`: `patchID`, `linearRgbMedian`, `normalizedLinearRgbMedian?`, `stats`.
- `RgbValues`: `r`, `g`, `b`.
- `MeasurementStats`: `sampleCount`, `clippingFraction`, `mean`, `standardDeviation`.
- `PairScoreUpload`: `pairID`, `distance`, `similarity`, `algorithmVersion`.
- `JudgmentUploadRequest`: `judgments` (`[PairJudgment]`).
- `PairJudgment`: `pairID`, `judgment` (`Judgment`: `match`, `near_match`, `no_match`).
- `RankedResultsResponse` (provisional — see delta R1): `schemaVersion`, `sheetID`,
  `scoringAlgorithmVersion`, `results` (`[RankedPairResult]`).
- `RankedPairResult` (provisional): `pairID`, `rank`, `sourceColors`, `distance`,
  `similarity`, `judgment?`, `captureID?`.

Wire casing is snake_case throughout (e.g. `sheet_id`, `linear_rgb_median`,
`scoring_algorithm_version`); enums carry the contract's raw values.

## Contract deltas found (feed into the PR description)

Deltas between the prose contract (`docs/color-matching-api-contract.md`), the app's
hand-written client, and the surface the generated client needs:

- **R1 — ranked results has no schema and no client.** The prose contract describes
  `GET /api/v1/test_sheets/:sheet_id/ranked_results` in prose only (no response JSON),
  and the hand-written `APIClient` never implemented it. The generated client must cover
  it; the `RankedResultsResponse`/`RankedPairResult` shapes above are provisional until
  reconciled with the published spec from `viamin/color_matching#110`.
- **R2 — success status codes are unspecified in the prose.** The prose contract shows
  request/response bodies but no status codes. The app's tests assume `201` for capture
  creation and `204` for uploads; the spec must pin these or the generated client's
  response switching will not compile.
- **R3 — hand-written `SheetManifest` silently drops server fields.** `MeasurementCore`'s
  `SheetManifest` decodes none of `created_at`, `printer_profile`, or `capture_profile`
  even though the prose contract includes them. The generated types surface this drift
  directly; the generated-client tests assert all three fields.
- **R4 — `title` nullability.** `RecentSheet.title` must be nullable per the prose
  ("`title` may be `null`"); the spec must model `type: [string, null]`.
- **R5 — auth is optional in development.** The prose allows unauthenticated requests in
  dev. The spec should document `401` so the client can classify auth failures; today the
  hand-written client collapses every non-2xx into `APIError.badStatus`.
- **R6 — upload trims client-side stats.** `ChannelStats` in `MeasurementCore` carries
  `median`, `min`, and `max`, but the contract's upload payload intentionally sends only
  `sample_count`, `clipping_fraction`, `mean`, `standard_deviation` (plus the medians at
  the measurement level). Keep the trim; it is not drift.
- **R7 — spec availability.** `viamin/color_matching#110`'s document was not reachable
  from this container (GitHub API proxy is restricted to this repo), so the final
  prose-vs-spec delta list must be produced in the implementation run when the document
  is vendored, and recorded in the PR description.

## Out of scope (per issue #5)

No new endpoints, no changes to capture/scoring behavior, no Pact (`pact-swift`).
