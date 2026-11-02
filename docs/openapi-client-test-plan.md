# OpenAPI Generated Client — Test Plan and Contract Deltas

Test-first plan for issue #5 ("Replace hand-written API layer with a generated OpenAPI Swift client"). This document is written in the red phase: the tests below are committed before any implementation. It doubles as the source for the PR description's contract-delta record.

## Acceptance criteria → verification map

| ID | Criterion (from issue #5) | Verification | Kind |
|----|---------------------------|--------------|------|
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` in the iOS package; OpenAPI document fetched/vendored from viamin/color_matching#110 | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPISpecCoverageTests.swift` — vendored doc exists at `iOS/OpenAPI/openapi.{json,yaml,yml}`, is OpenAPI 3.x, and `Package.swift` declares both packages plus the `ColorMatchingOpenAPI` target. These structural guards are permanent: if regeneration or an upstream spec revision drops an endpoint or dependency, they fail. | Permanent unit test (structural) |
| AC-2 | Client generated for all six surfaces (manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results) | `OpenAPISpecCoverageTests` covers the six path+method combinations in the vendored spec. `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIClientStubbedResponseTests.swift` exercises one generated client method per surface against stubbed responses. | Permanent unit tests |
| AC-3 | Hand-written API models replaced by generated types; purely client-side models kept | Existing `APIClientTests.swift` and `MeasurementCoreTests.swift` remain green (regression guard for app behavior during the swap). Generated-type decoding is asserted field-by-field in `OpenAPIClientStubbedResponseTests`. | Permanent unit tests |
| AC-4 | Swift tests exercising the generated client against local stubbed responses, no live server in CI | `OpenAPIClientStubbedResponseTests.swift` routes every request through `URLSessionTransport` over an `URLProtocol` stub (`OpenAPIStubURLProtocol`). No network host is contacted; all fixtures are inline strings. | Permanent unit tests |
| AC-5 | PR description records prose-contract → published-spec deltas and endpoint gaps | Section "Contract deltas" below, seeded from repo evidence; final reconciliation against the real spec happens when the spec is vendored (see "Blocked"). | Human/external evidence (this doc + PR body) |
| EXIT-1 | `swift test --disable-sandbox` green with generated types wired in | CI job "Swift and iOS Tests" (`.github/workflows/ci.yml`) runs `swift test` on macOS. | External evidence (CI run at PR head) |
| EXIT-2 | PR description captures contract deltas | PR body copied from "Contract deltas" below. | Human/external evidence |

## Why two test files, one of them compile-gated

This changeset is tests-only (red phase). `Package.swift` cannot depend on `swift-openapi-generator` yet, so `OpenAPIClientStubbedResponseTests` is wrapped in `#if canImport(ColorMatchingOpenAPI) && canImport(OpenAPIRuntime)`: it compiles as an inert file today and automatically activates the moment the generated target exists. The always-compiled `OpenAPISpecCoverageTests` is the visible red signal today: it fails until the spec is vendored and the package dependencies are added.

## Canonical generated-client contract (pinned by the tests)

The implementation run must satisfy all of the following, which the tests hard-code:

- **Vendored spec location**: `iOS/OpenAPI/openapi.json` (preferred; validated structurally) or `openapi.yaml`/`openapi.yml` (lighter textual validation). Source: the spec published by viamin/color_matching#110.
- **Generated target/module name**: `ColorMatchingOpenAPI`, produced by the `OpenAPIGenerator` plugin from `apple/swift-openapi-generator`, depending on `apple/swift-openapi-runtime` (module `OpenAPIRuntime`, 1.x).
- **Operation IDs** (determine generated client method names):

| Operation ID | Method & path | Success response pinned by tests |
|--------------|---------------|----------------------------------|
| `getTestSheetManifest` | GET `/api/v1/test_sheets/{sheet_id}/manifest` | 200 `application/json` |
| `listRecentTestSheets` | GET `/api/v1/test_sheets/recent` | 200 `application/json` |
| `createCapture` | POST `/api/v1/test_sheets/{sheet_id}/captures` | **201** `application/json` `{capture_id}` |
| `uploadMeasurements` | POST `/api/v1/captures/{capture_id}/measurements` | **204** no content |
| `uploadJudgments` | POST `/api/v1/captures/{capture_id}/judgments` | **204** no content |
| `getRankedResults` | GET `/api/v1/test_sheets/{sheet_id}/ranked_results` | 200 `application/json` |

- **Schema decisions** (property names are exactly the snake_case JSON keys from `docs/color-matching-api-contract.md`; swift-openapi-generator keeps raw schema property names in Swift):
  - `title` (recent sheets) and `judgment` (ranked pairs) are nullable → generated optionals; tests assert `nil` decodes.
  - `manifest_url` is a plain string (no `format`), asserted as `String`.
  - Enums: patch `role` (`pair_color`/`reference`), `judgment` (`match`/`near_match`/`no_match`), and capture `rejections` (the six prose values) are schema enums → generated Swift enums (`judgment: .near_match` is asserted).
  - Date-time fields (`timestamp`, `created_at`) use `format: date-time` → Foundation `Date`.
  - `printer_profile` and `capture_profile` on the manifest are required objects.
  - **Ranked results response schema** (the prose contract never defined one — see delta D1). Canonical schema pinned by the tests:

    ```json
    {
      "sheet_id": "…",
      "capture_id": "…",
      "scoring_algorithm_version": "…",
      "printer_profile": {"id": "…", "name": "…"},
      "ranked_pairs": [
        {
          "pair_id": "…",
          "rank": 1,
          "distance": 0.035,
          "similarity": 0.965,
          "source_colors": ["#FF0000", "#00FF00"],
          "judgment": "near_match"
        }
      ]
    }
    ```

    `judgment` is nullable (not yet judged). This covers every category the prose contract demands for ranked results: source colors, scores, labels, capture provenance, printer profile, and scoring algorithm version.
- **Auth**: bearer token applied via a `ClientMiddleware` (`BearerTokenMiddleware` in the test file); asserted on the wire as `Authorization: Bearer <token>`.
- **Package wiring needed by the implementation run** (not permitted in this red-phase changeset): add `swift-openapi-generator`/`swift-openapi-runtime` package deps, the `ColorMatchingOpenAPI` target (plugin + `openapi.yaml`/`openapi.json` document), and list **both** `ColorMatchingOpenAPI` and the `OpenAPIRuntime` product as dependencies of the `ColorMatchingLPSAppTests` test target (SwiftPM requires direct deps for import).

## Contract deltas

Deltas between `docs/color-matching-api-contract.md` (prose) and the real `/api/v1` API discovered so far. D1–D6 are derived from repo evidence (the prose contract, `iOS/Sources/`, existing tests). The final column is completed during implementation when the published spec (viamin/color_matching#110) is vendored; `OpenAPISpecCoverageTests` then automates the check.

| ID | Delta / gap | Evidence | Reconciled against published spec |
|----|-------------|----------|-----------------------------------|
| D1 | **Ranked results has no response schema in the prose contract** — the section is one sentence with no JSON example, so the app could not have implemented it against the contract. | `docs/color-matching-api-contract.md`, "Retrieve Ranked Results" section; no `ranked_results` anywhere in `iOS/Sources/` (grep finds only local scoring UI text) | Pending spec vendoring |
| D2 | **No status codes specified in the prose contract.** The hand-written tests assumed 201 (capture create) and 204 (uploads); the generated tests pin the same. | `APIClientTests.swift` stubs 201/204; prose contract shows no statuses | Pending |
| D3 | **Hand-written `SheetManifest` silently drops manifest fields** the prose contract requires: `created_at`, `printer_profile`, `capture_profile`. This is a live example of the drift this issue exists to eliminate (server adds fields → hand-written model just ignores them). | `MeasurementCore/Models.swift` `SheetManifest` vs prose manifest example | Pending |
| D4 | **Auth is prose-only** ("shared bearer token") with no scheme in any machine-readable artifact; generated client applies it via middleware until/unless the spec declares a `securityScheme`. | Prose contract "Authentication" section | Pending |
| D5 | **Allowed-value lists are prose, not types**: judgments, capture rejections, patch roles, reference roles exist only as bullet lists; the spec should encode them as enums so drift becomes a compile error. | Prose contract bullet lists | Pending |
| D6 | **`title` nullability** is called out in prose; the spec must mark it nullable or `RecentSheet.title` decoding regresses. | Prose "Fetch Recent Sheets": "`title` may be `null`" | Pending |

### Blocked dependency note

The published spec from viamin/color_matching#110 could not be fetched in the authoring environment: the GitHub API proxy is repo-scoped and returns "Repository mismatch" for `viamin/color_matching`. D1–D6 reconciliation and the "what changed between the prose contract and the published spec" narrative for the PR description must be completed in the implementation run, once the spec is vendored. `OpenAPISpecCoverageTests` turns that reconciliation into an automated check (missing path/method/endpoint ⇒ red test).

## Execution notes

- No Swift toolchain exists in the authoring container, so nothing was executed locally. Both files compile under Swift 5.9 tools (matching `iOS/Package.swift`): the coverage file has no external dependencies; the client suite is `canImport`-gated.
- CI (`.github/workflows/ci.yml`, macOS) runs `swift test`. Expected state at this red-phase commit: `OpenAPISpecCoverageTests` fails (3 tests — vendored spec, spec coverage, package deps all missing by design); `OpenAPIClientStubbedResponseTests` compiles inert and contributes zero tests until the generated target exists.
- When implementation lands: coverage tests go green on the vendored spec, the gated suite activates (8 tests across the six surfaces + auth), and `swift test --disable-sandbox` green closes EXIT-1.
