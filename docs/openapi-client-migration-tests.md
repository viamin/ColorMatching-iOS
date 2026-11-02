# OpenAPI Generated Client Migration — Test Plan (issue #5)

Tests-only change set for replacing the hand-written API layer with a generated
OpenAPI Swift client. This document records the acceptance-criterion-to-verification
mapping, the test inventory, the contract-delta checklist the PR description must
answer, and known gaps. The implementation change set follows after test approval.

Dependency: `viamin/color_matching#110` must publish the machine-readable OpenAPI
spec covering the sheet/capture endpoints.

## Why tests are shaped this way (compile-safe red phase)

In Swift, a test that references a not-yet-existing symbol (e.g. a generated
`Components.Schemas.*` type or a new `fetchRankedResults` method) prevents the
entire test bundle from building — every test in the suite would report as a
build failure, which is infrastructure noise, not red-phase evidence. Therefore
every new test in this change set compiles against the current package and
demonstrates missing behavior through **runtime assertion failures** driven by
repository-artifact checks (vendored spec file, `Package.swift` wiring, removed
hand-written wire types). Behavioral coverage for surfaces that already exist
runs green today and acts as the migration harness that must stay green once
generated types are wired in.

## Acceptance criteria mapping

| AC  | Criterion (from issue #5)                                                                 | Verification kind          | Evidence at this PR head                                                        | Phase now |
|-----|-------------------------------------------------------------------------------------------|----------------------------|---------------------------------------------------------------------------------|-----------|
| AC-1| `swift-openapi-generator` + `swift-openapi-runtime` in the iOS package; OpenAPI document vendored | Unit test (repo artifacts) | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIPackageWiringTests.swift`, `OpenAPISpecArtifactTests.testVendoredOpenAPIDocumentExists` | Red (artifacts absent) |
| AC-2| Generated client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | Unit test (spec coverage + stubbed behavior) | `OpenAPISpecArtifactTests.testVendoredSpecCoversEveryAppAPIOperation`; per-surface stubbed tests below | Red (no spec yet) |
| AC-3| Hand-written API models replaced with generated types; purely client-side models kept       | Unit test (source scan)     | `HandWrittenAPIModelMigrationTests`                                              | Red (wire structs still declared) |
| AC-4| Swift tests exercising the generated client against local stubbed responses (no live server) | Unit test (stubbed URLProtocol) | `APIClientStubbedResponseTests.swift` (new surfaces) + existing `APIClientTests.swift` (capture/measurement/judgment) | Green now; must stay green post-migration |
| AC-5| PR description records prose-contract vs published-spec deltas and endpoint gaps            | Human/external evidence      | Checklist below, to be answered in the PR description when the spec is vendored | Not run (PR authored at implementation time) |

## Test inventory

All new tests live in the existing `ColorMatchingLPSAppTests` SwiftPM target
(picked up automatically by `swift test`; the Xcode project's explicit file
lists are untouched, so the `xcodebuild` CI leg is unaffected).

- `OpenAPISpecArtifactTests` — RED now
  - `testVendoredOpenAPIDocumentExists`: a `*.yaml`/`*.yml`/`*.json` file with
    `openapi` in its name must be vendored in the repository (outside `Tests/`
    and build directories) from `viamin/color_matching#110`.
  - `testVendoredSpecDeclaresOpenAPI3Document`: the document declares `openapi: 3.x`.
  - `testVendoredSpecCoversEveryAppAPIOperation`: the document's `paths` declare
    the six operations the app uses — `GET test_sheets/{id}/manifest`,
    `GET test_sheets/recent`, `POST test_sheets/{id}/captures`,
    `POST captures/{id}/measurements`, `POST captures/{id}/judgments`,
    `GET test_sheets/{id}/ranked_results`. Path comparison tolerates parameter
    naming (`{sheet_id}` vs `{id}` vs `:sheet_id`) and an optional `/api/v1`
    prefix (server-relative specs), because those are cosmetic deltas — but the
    path structure and HTTP method are pinned.
- `OpenAPIPackageWiringTests` — RED now
  - `testPackageDeclaresSwiftOpenAPIGeneratorAndRuntime`: `iOS/Package.swift`
    declares both package names.
  - `testPackageUsesOpenAPIGeneratorBuildPlugin`: the generator is wired as the
    `OpenAPIGenerator` build plugin so the client regenerates on build.
- `HandWrittenAPIModelMigrationTests`
  - `testHandWrittenAPIWireModelsAreRemovedFromAppSources` — RED now: the
    private hand-written wire envelope structs in `APIClient.swift`
    (`CreateCaptureRequest`, `MeasurementUploadRequest`, `MeasurementUpload`,
    `MeasurementStatsUpload`, `JudgmentUploadRequest`, `RecentSheetsResponse`)
    must no longer be declared; requests/responses go through generated types.
  - `testClientSideDomainModelsRemainInMeasurementCore` — GREEN now and after:
    purely client-side models (`RGB`, `Point`, `Rect`, `DetectedMarker`,
    `SampleOverlayRegion`, `SheetAnalysis`, `ChannelStats`) stay in
    `MeasurementCore/Models.swift`. Public domain models such as `SheetManifest`
    are expected to remain as domain models populated from generated types —
    `SheetAnalyzer` and the UI consume them, and behavior change is a non-goal.
- `APIClientStubbedResponseTests` — GREEN now; the migration harness
  - `testFetchManifestByCodeRequestsContractPathAndDecodesDocumentedManifest`:
    stubs the exact manifest JSON from `docs/color-matching-api-contract.md`
    and asserts request path, bearer auth, and full decode (page, markers,
    patches incl. `safe_inset_mm`, pairs).
  - `testFetchRecentSheetsDecodesEntriesAndOptionalTitles`: `title: null` decodes
    to nil; entries stay `Identifiable` by sheet id.
  - `testFetchManifestSurfacesBadStatusErrors`: HTTP 401 maps to `APIError.badStatus`.
- Existing `APIClientTests` (unchanged) already pin capture creation, measurement
  upload (incl. `scoring_algorithm_version` and stats keys), and judgment upload
  payloads against stubbed responses; they are part of the AC-4 harness.

## Contract-delta checklist for the PR description (AC-5)

When the implementation change set vendors the spec, diff it against
`docs/color-matching-api-contract.md` and record answers in the PR body:

1. Authentication: bearer token header confirmed in spec security schemes?
2. Manifest: are `created_at`, `printer_profile`, `capture_profile` (absent from
   the current hand-written `SheetManifest` Codable) present and typed in the
   spec? Which manifest fields are required vs optional?
3. Recent sheets: is `title` nullable in the spec as the prose allows?
4. Capture creation: status code (contract examples imply 201), rejection
   string enum values (`missingRegistrationMarks`, `incompleteSheetCoverage`,
   `clipping`, `excessiveBlur`, `glare`, `poorReferencePatch`) — enum or free
   string in the spec?
5. Measurement upload: stats min/max present or absent in the spec (the
   hand-written upload deliberately sends only sample_count/clipping_fraction/
   mean/standard_deviation)? Response body or 204?
6. Judgments: `match`/`near_match`/`no_match` enum in the spec?
7. Ranked results: response schema defined at all? The prose contract never
   specifies it — if the spec also omits it, that is an endpoint gap to report
   upstream, and the ranked-results surface cannot be generated.
8. Path/style deltas: `/api/v1` prefix on paths vs server URL, `:param` vs
   `{param}`, any trailing formats (`.json`)?

## Known gaps and deferrals

- **Ranked-results behavioral test is deferred to the implementation change
  set.** No client method for `GET /test_sheets/{id}/ranked_results` exists
  today, so a test calling it cannot compile — it would turn the whole suite
  into a build failure rather than assertion-level red evidence. AC-2's
  ranked-results requirement is currently enforced by
  `testVendoredSpecCoversEveryAppAPIOperation` (the spec must declare the
  operation so the client can be generated for it). The implementation run must
  add the stubbed-response test for the new surface alongside the generated
  client.
- **No Swift toolchain exists in the test-writing container**; `swift test`
  runs on the macOS CI runners (`.github/workflows/ci.yml`). Red/green
  expectations above are derived from repository-artifact inspection and the
  existing suite's behavior.
- The prose contract `docs/color-matching-api-contract.md` is intentionally
  left untouched: it is the baseline the PR-description delta checklist
  compares against.

## Red/green evidence recorded at this PR head

No Swift toolchain is available in the test-writing container, so the decision
logic of every new test was replayed against the real repository tree with a
script (same file-walk rules, same substring/parse assertions) to establish
inspectable phase evidence:

- Expected **red** (missing behavior, by design until the implementation lands):
  - `testVendoredOpenAPIDocumentExists`, `testVendoredSpecDeclaresOpenAPI3Document`,
    `testVendoredSpecCoversEveryAppAPIOperation` — no `*openapi*.{yaml,yml,json}`
    file exists anywhere in the repository (search space verified empty).
  - `testPackageDeclaresSwiftOpenAPIGeneratorAndRuntime` — `iOS/Package.swift`
    contains neither `swift-openapi-generator` nor `swift-openapi-runtime`.
  - `testPackageUsesOpenAPIGeneratorBuildPlugin` — no `OpenAPIGenerator` plugin
    reference in `iOS/Package.swift`.
  - `testHandWrittenAPIWireModelsAreRemovedFromAppSources` — all six wire
    envelope structs are still declared in
    `iOS/Sources/ColorMatchingLPSAppCore/APIClient.swift`:
    `CreateCaptureRequest`, `MeasurementUploadRequest`, `MeasurementUpload`,
    `MeasurementStatsUpload`, `JudgmentUploadRequest`, `RecentSheetsResponse`.
- Expected **green** (regression harness and parser sanity):
  - `testClientSideDomainModelsRemainInMeasurementCore` — all seven purely
    client-side types are declared in `MeasurementCore`.
  - `testFetchManifestByCodeRequestsContractPathAndDecodesDocumentedManifest` and
    `testFetchRecentSheetsDecodesEntriesAndOptionalTitles` — the stub fixtures
    contain every required CodingKey of the current Codable models (verified
    key-by-key), so they decode and the assertions pass against today's code.
  - `testFetchManifestSurfacesBadStatusErrors` — mirrors the existing
    `APIError.badStatus` validation path in `APIClient`.
  - The YAML `paths:` extraction and path normalization were replayed against a
    representative OpenAPI 3 spec containing all six operations; all six were
    recovered in normalized form.

Actual `swift test --disable-sandbox` execution happens on the macOS CI runners
and, for the red tests, turns green with the implementation change set.
