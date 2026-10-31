---
module: iOS
tags: [openapi, code-generation, api-client, testing]
problem_type: feature_verification
---

# Generated OpenAPI Client — Verification Plan and Contract Deltas

Test-writing (red) phase for issue #5, "Replace hand-written API layer with a
generated OpenAPI Swift client". This document records:

1. The artifact contract the implementation run must satisfy (names and paths
   the new tests assume).
2. The acceptance-criterion → verification mapping.
3. The contract deltas between `docs/color-matching-api-contract.md` (prose),
   the hand-written Swift layer, and what the published OpenAPI document must
   specify. This section is the seed of the final PR description deliverable.

## Artifact contract

The implementation run must land the following artifacts. The always-on tests
below fail until they exist; `GeneratedClientTests` is compiled behind
`#if canImport(ColorMatchingOpenAPI)` and activates once the module exists.

| Artifact | Contract |
| --- | --- |
| OpenAPI document | Vendored at `iOS/openapi.yaml` (YAML, OpenAPI 3.x) from the published spec in viamin/color_matching#110 |
| Generator dependency | `swift-openapi-generator` referenced from `iOS/Package.swift` |
| Runtime dependency | `swift-openapi-runtime` referenced from `iOS/Package.swift` |
| Build plugin | `OpenAPIGeneratorTarget` plugin applied to the generated-code target |
| Generated module | Target/module named `ColorMatchingOpenAPI` |
| App wiring | `iOS/Sources/ColorMatchingLPSAppCore` imports `ColorMatchingOpenAPI`; hand-written Codable request/response models are replaced by generated types (purely client-side models in `MeasurementCore`, e.g. `RGB`, `Rect`, stay as-is) |
| Auth | `bearerAuth` scheme (`type: http`, `scheme: bearer`); the facade applies the bearer token via an OpenAPIRuntime transport middleware |

### Operation IDs the generated client must expose

| Surface | Method + path | operationId |
| --- | --- | --- |
| Sheet manifest | `GET /api/v1/test_sheets/{sheet_id}/manifest` | `getTestSheetManifest` |
| Recent sheets | `GET /api/v1/test_sheets/recent` | `listRecentTestSheets` |
| Capture session creation | `POST /api/v1/test_sheets/{sheet_id}/captures` | `createCapture` |
| Measurement upload | `POST /api/v1/captures/{capture_id}/measurements` | `uploadMeasurements` |
| Judgment upload | `POST /api/v1/captures/{capture_id}/judgments` | `uploadJudgments` |
| Ranked results | `GET /api/v1/test_sheets/{sheet_id}/ranked_results` | `getRankedResults` |

### Status-code and schema decisions the spec must pin down

- `createCapture` responds `201` with `{"capture_id": ...}` (the existing
  `APIClientTests` stub already assumed 201).
- `uploadMeasurements` and `uploadJudgments` respond `204 No Content` with no
  body (existing tests stub 204).
- Ranked-results response body shape (unspecified in the prose contract; the
  gated test uses the minimal shape below):

  ```json
  {
    "scoring_algorithm_version": "lps-distance-v1",
    "results": [
      {
        "pair_id": "pair_1",
        "source_colors": ["#FF0000", "#00FF00"],
        "distance": 0.035,
        "similarity": 0.965,
        "judgment": "near_match",
        "capture_id": "capture_123"
      }
    ]
  }
  ```

- `judgment` values are an enum: `match`, `near_match`, `no_match` (the gated
  test uses the generated `.near_match` case).
- Capture `rejections` values are an enum: `missingRegistrationMarks`,
  `incompleteSheetCoverage`, `clipping`, `excessiveBlur`, `glare`,
  `poorReferencePatch`.

### Naming assumptions in the gated tests

`GeneratedClientTests` is written against schema property names exactly as
they appear in the wire contract (snake_case, e.g. `manifest.sheet_id`,
`body.capture_id`) and path parameters as declared (`sheet_id`, `capture_id`).
If swift-openapi-generator applies Swift naming conversions instead (e.g.
`sheetId`), adjust the vendored spec (via `x-swift-name` where supported) or
update these assertions in the implementation run — the operation IDs, paths,
methods, and status-code handling asserted here must not change.

## Acceptance-criterion → verification mapping

| # | Deliverable / criterion | Verification | Locator |
| --- | --- | --- | --- |
| AC-1 | swift-openapi-generator + runtime added; OpenAPI document vendored | Permanent unit tests (red now) | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIDocumentTests.swift`, `OpenAPIPackageIntegrationTests.swift` |
| AC-2 | Client generated for manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Spec coverage test + compile-gated stubbed-response tests per surface | `OpenAPIDocumentTests.testSpecCoversEverySurfaceTheAppUses`, `GeneratedClientTests` (6 test methods) |
| AC-3 | Hand-written API models replaced by generated types; client-side models kept | Unit test asserting AppCore routes through the generated module | `OpenAPIPackageIntegrationTests.testAppCoreRoutesThroughGeneratedClient` |
| AC-4 | Swift tests exercising the generated client against local stubbed responses (no live server in CI) | Compile-gated tests using an in-process `StubTransport` (no network) | `GeneratedClientTests.swift` (`StubTransport: ClientTransport`) |
| AC-5 | PR description records prose-contract vs published-spec deltas and endpoint gaps | Human/external evidence — delta analysis recorded in this document, to be lifted into the PR body by the implementation run | `docs/generated-openapi-client-verification.md` § "Contract deltas" |
| EXIT | `swift test --disable-sandbox` green with generated types wired in | CI (`macos-latest`, `.github/workflows/ci.yml`). Not runnable in this container: no Swift toolchain installed; the always-on tests are intentionally red until implementation lands | — |

## Contract deltas (prose contract vs hand-written layer vs required spec)

Findings from comparing `docs/color-matching-api-contract.md`,
`iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`, and
`iOS/Sources/MeasurementCore/Models.swift`. The final PR description should
carry this list forward.

1. **Manifest fields dropped by the hand-written models.** The prose manifest
   example includes `created_at`, `printer_profile` (id, name, paper, ink,
   settings), and `capture_profile` (expected_illuminant, preferred_camera,
   scoring_algorithm_version). `SheetManifest` (`MeasurementCore/Models.swift`)
   decodes none of them — the app silently loses provenance today. The
   published spec must define them, and generated types will make the gap a
   compile-time-visible fact.
2. **Ranked results endpoint is unspecified.** The prose contract describes
   `GET /api/v1/test_sheets/:sheet_id/ranked_results` with one sentence and no
   schema, and the hand-written `APIClient` has no method for it at all — an
   endpoint gap. The spec must define response schema, status codes, and the
   judgment/provenance fields (shape proposed above).
3. **No error contract.** The prose document defines no 4xx/5xx response
   schemas or status codes; `APIClient` collapses every failure into
   `APIError.badStatus`. The spec should model at least 401/404/422 so the
   generated client surfaces typed errors.
4. **Success status codes unpinned.** The prose shows response bodies without
   statuses. The existing tests assume 201 for capture creation and 204 for
   measurement/judgment uploads; the spec must pin these or the generated
   client will reject valid responses.
5. **Enumerations are prose-only.** Patch roles (`pair_color`, `reference`),
   reference roles (`white`, `gray`, `black`, `blank_paper`), capture
   rejections, and judgments (`match`, `near_match`, `no_match`) are listed as
   prose. `CaptureRejection` in the app is a local String enum;
   `PairJudgment.judgment` is an untyped `String`. The spec should encode
   these as enums so server-side drift becomes a regeneration diff.
6. **Nullable `title` on recent sheets.** Prose allows `null`; `RecentSheet`
   models `String?`. The spec must mark `title` nullable (covered by
   `OpenAPIDocumentTests.testSpecMarksRecentSheetTitleNullable`).
7. **Optional capture metadata.** The prose request example shows all
   metadata fields, but the app treats exposure/ISO/focus/WB-gains/dimensions
   as optional (`CaptureMetadata` optionals). The spec must mark these
   properties optional to keep the app's requests valid.
8. **Auth is optional in development.** The prose allows unauthenticated
   requests in development; the generated client should treat `bearerAuth` as
   optional (not a global `security` requirement) so the app can omit the
   token locally.
9. **Route collision risk.** `/api/v1/test_sheets/recent` must be matched
   before `/api/v1/test_sheets/{sheet_id}/...` on the server; the spec should
   keep the literal path distinct (a Phoenix routing concern surfaced by the
   spec review, worth noting in the PR).
10. **`manifest_url` handling.** The app fetches manifests by full URL
    (`fetchManifest(from:)`) or by sheet code. Generated clients need the
    path-parameterized form; the facade keeps direct-URL fetching by deriving
    the sheet id or by continuing to support absolute URLs. The spec pins the
    path-parameter form; facade behavior is an implementation decision to
    record in the PR.

## Upstream spec availability note

viamin/color_matching#110 was not reachable from this environment (the GitHub
API returns 404 for the repository), so the spec could not be fetched or
compared byte-for-byte in this run. The tests therefore define the
machine-checkable contract the vendored `iOS/openapi.yaml` must satisfy; the
implementation run vendors the published spec (adjusting the deltas above
against the real document) and these tests turn green.
