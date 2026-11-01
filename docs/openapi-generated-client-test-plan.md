# Generated OpenAPI client — test plan and contract notes (issue #5)

Status: tests-first draft for replacing the hand-written API layer with a
generated OpenAPI Swift client. The tests live in
`iOS/Tests/ColorMatchingLPSAppTests/OpenAPIGeneratedClientTests.swift` and exercise
the generated client against local stubbed responses only — no live server is
contacted, so they are safe in CI.

## Dependency status at authoring time

The upstream OpenAPI document from `viamin/color_matching#110` was **not
reachable** from this environment (GitHub returned 404 for that pull request on
2026-11-01). The tests therefore pin the conventions below, derived from
`docs/color-matching-api-contract.md` plus the stubs the existing hand-written
`APIClientTests` already assume. The implementation run vendors the published
spec, reconciles any naming differences together with these tests, and records
the deltas in the PR description (issue deliverable #5).

## Red-phase gate

- `testGeneratedClientModuleIsWiredIntoPackage` fails while the generated target
  is absent — this is the expected red state demonstrating the missing behavior.
- The six stubbed-response tests are compiled behind
  `#if canImport(OpenAPIGenerated)` and activate, with no test edits, once the
  package exposes the generated module to the `ColorMatchingLPSAppTests` target.
- Until then the rest of the suite (including the existing `APIClientTests`)
  still compiles and runs unchanged.

## Pinned client surface

Tooling and module names:

- Generator target/module: `OpenAPIGenerated` (swift-openapi-generator output).
- Runtime: `swift-openapi-runtime`, using `URLSessionTransport(configuration:)`
  over an ephemeral `URLSession` instrumented with a stub `URLProtocol`.

Operations (operationId → request → pinned success response):

| operationId           | HTTP request                                   | Declared response        |
| --------------------- | ---------------------------------------------- | ------------------------ |
| `fetchTestSheetManifest` | GET `/api/v1/test_sheets/{sheet_id}/manifest` | 200 JSON `SheetManifest` |
| `fetchRecentTestSheets`  | GET `/api/v1/test_sheets/recent`              | 200 JSON `RecentSheetsResponse` |
| `createCaptureSession`   | POST `/api/v1/test_sheets/{sheet_id}/captures` | 201 JSON `CaptureSessionResponse` |
| `uploadMeasurements`     | POST `/api/v1/captures/{capture_id}/measurements` | 204 no content      |
| `uploadJudgments`        | POST `/api/v1/captures/{capture_id}/judgments` | 204 no content           |
| `fetchRankedResults`     | GET `/api/v1/test_sheets/{sheet_id}/ranked_results` | 200 JSON `RankedResultsResponse` |

Component schemas the tests read or construct (JSON keys snake_case per the
prose contract; Swift properties camelCase):

- `SheetManifest` — test reads `schemaVersion`, `sheetId`, `patches`, `pairs`.
- `RecentSheetsResponse.sheets: [RecentSheet]`; `RecentSheet.title` nullable.
- `CreateCaptureSessionRequest { metadata: CaptureMetadata, quality: CaptureQuality }`.
- `CaptureSessionResponse { capture_id }`.
- `MeasurementUploadRequest { scoring_algorithm_version, measurements:
  [MeasurementUpload], pair_scores: [PairScoreUpload] }`; upload `stats` has
  exactly `sample_count`, `clipping_fraction`, `mean`, `standard_deviation`.
- `JudgmentUploadRequest { judgments: [PairJudgment] }`.
- `RankedResultsResponse { sheet_id, scoring_algorithm_version, results: [{
  pair_id, distance, similarity, rank }] }` — minimal iOS-needed shape; see gap G-1.
- `CaptureMetadata.timestamp` is an OpenAPI `format: date-time` decoded from
  ISO 8601 (`2026-07-25T12:00:00Z`).

If the published spec names anything differently, adjust the tests together with
the vendored spec in the same change and record the delta in the PR description —
do not silently diverge.

## Acceptance-criteria → verification mapping

| Criterion (issue #5) | Verification (smallest credible) | Reference |
| --- | --- | --- |
| Generated client exists for the six surfaces the app uses | Permanent unit tests against stubbed responses, plus a wiring sentinel | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIGeneratedClientTests.swift` |
| Test-sheet manifest + recent sheets decode (incl. null title) | `testFetchTestSheetManifestDecodesDocumentedManifest`, `testFetchRecentSheetsDecodesSheetsIncludingNullTitle` | same file |
| Capture session creation (request path, metadata/quality body, capture_id decode) | `testCreateCaptureSessionPostsMetadataQualityAndDecodesCaptureID` | same file |
| Measurement upload payload | `testUploadMeasurementsPostsAlgorithmVersionMeasurementsAndScores` | same file |
| Judgment upload payload | `testUploadJudgmentsPostsDocumentedJudgments` | same file |
| Ranked results decode | `testFetchRankedResultsDecodesScoresAndAlgorithmVersion` | same file |
| Undeclared status surfaces as an error, not a silent decode | `testFetchManifestSurfacesErrorForUndeclaredNotFoundStatus` | same file |
| `swift test --disable-sandbox` green with generated types wired in | CI job `Swift and iOS Tests` (`swift test`) on the PR | `.github/workflows/ci.yml` |
| Hand-written models replaced; purely client-side models kept | Implementation-run change; existing `APIClientTests` keep pinning bearer-token and wire-format behavior through the swap | `iOS/Tests/ColorMatchingLPSAppTests/APIClientTests.swift` |

## Contract deltas and gaps (prose contract vs machine-readable spec)

Discovered while authoring the tests. The implementation PR description must
record the final delta set:

- **G-1 `ranked_results` has no response schema in the prose contract** — the
  contract gives it one sentence and no JSON example. The test pins the minimal
  shape iOS needs (`sheet_id`, `scoring_algorithm_version`, `results[]` with
  `pair_id`, `distance`, `similarity`, `rank`). The published spec must define
  the real schema; reconcile the test when it lands and record the delta.
- **G-2 Success status codes are unspecified in prose.** The tests pin
  200/201/204, matching what the existing `APIClientTests` stubs already assume.
  The spec must declare these responses or the generated client will reject real
  responses as undocumented.
- **G-3 No error response envelope is documented** (4xx/5xx bodies). Until the
  spec defines one, the tests only assert that an undeclared 404 surfaces as a
  thrown error rather than a silent decode.
- **G-4 Auth is out-of-band for codegen.** The bearer token must be attached by
  client-side middleware/configuration when replacing `APIClient`. The existing
  `APIClientTests` pin the `Authorization: Bearer …` header and must keep passing
  (or move with the change) during the swap.
- **G-5 `title` nullability on recent sheets** must be modeled as nullable in
  the spec; the prose contract allows `null` and the test decodes both variants.
- **G-6 Upload `stats` is narrower than client-side `ChannelStats`** — the
  upload payload omits `median`, `min`, and `max`. The test asserts the exact
  key set so server-side drift becomes a test/compile failure, per the issue's
  goal.

## Execution notes

- Repo test command: `cd iOS && swift test --disable-sandbox`.
- The container that authored this change has no Swift toolchain
  (`swift: command not found`), so the authoritative test run is the CI macOS
  job; the gated tests are intentionally inert there until the generated target
  lands, while the sentinel reports the missing wiring.
