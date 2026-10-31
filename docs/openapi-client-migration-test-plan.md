# OpenAPI generated-client migration — test plan and naming contract

Status: tests-only (red phase) for issue #5. The tests in this PR prescribe
the target behavior for the implementation run; nothing here modifies
`Package.swift` or `Sources/`.

## What is red, and why that is correct

| Suite | File | State at this PR head |
| --- | --- | --- |
| `OpenAPISpecCoverageTests` | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPISpecCoverageTests.swift` | Compiles (Foundation/XCTest only); fails at runtime because `iOS/Sources/ColorMatchingAPI/openapi.json` does not exist yet. |
| `GeneratedClientTests` | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientTests.swift` | Does not compile until the `ColorMatchingAPI` target exists. The missing-module error **is** the compile-time drift signal the migration buys. |
| `OpenAPIStubTransport` | `iOS/Tests/ColorMatchingLPSAppTests/OpenAPIStubTransport.swift` | Support for the above; does not compile until `swift-openapi-runtime` is a test-target dependency. |

No ephemeral (`.ephemeral-tests/`) coverage is used: every check here is a
permanent unit-level rule that should run on all future PRs. No live server is
contacted from tests — all responses are stubbed via `OpenAPIStubTransport`.

## Acceptance criteria → smallest credible verification

| # | Deliverable (issue #5) | Verification |
| --- | --- | --- |
| D1 | `swift-openapi-generator` + `swift-openapi-runtime` in the package; spec fetched/vendored | `OpenAPISpecCoverageTests` asserts the vendored document exists, is OpenAPI 3, serves from `/`, and matches the published operationIds/status codes/security. Package wiring is proven when `GeneratedClientTests` compiles (`import ColorMatchingAPI`). |
| D2 | Generated client for manifest, recent sheets, capture creation, measurement upload, judgment upload, ranked results | One `GeneratedClientTests` test per surface (6 tests), each asserting method, path (with `/api/v1` prefix), operationId, wire JSON, and decoded generated types. |
| D3 | Hand-written API models replaced by generated types | `GeneratedClientTests` constructs request bodies and decodes responses exclusively through `Components.Schemas.*` generated types. Migration of the app target itself lands with the implementation run (which also retires `APIClientTests` against the deleted hand-written client). |
| D4 | Swift tests against local stubbed responses, no live server in CI | `OpenAPIStubTransport` implements `Transport`; zero network in tests. |
| D5 | PR description records contract deltas + endpoint gaps | `docs/color-matching-openapi-contract-deltas.md` (embed its tables in the PR body verbatim). |

Exit criterion "`swift test --disable-sandbox` green" is only reachable after the
implementation run; this environment has no Swift toolchain, so nothing was
executed locally. CI (macos runner, `swift test`) will show the red phase as a
build failure of the test target until the generated target lands.

## Vendoring contract

- Source of truth: `GET /api/v1/openapi.json` as implemented by
  viamin/color_matching#113 (upstream has no static spec file; it is rendered
  from `ColorMatchingWeb.ApiSpec` + router + controller specs). When a live
  deployment is reachable, dump it; until then reconstruct from those modules —
  the semantic facts are pinned by `OpenAPISpecCoverageTests`.
- Vendored location: `iOS/Sources/ColorMatchingAPI/openapi.json`
  (+ `openapi-generator-config.yaml` with `generate: {types: [client]}`).
- Vendoring is verbatim except for four enumerated patches (P1–P4, see the
  deltas doc) that keep app-sent payloads expressible in generated Swift. Every
  patch is visible as a diff against upstream and each is enforced by a
  coverage-test assertion.
- New SPM target `ColorMatchingAPI` depends on `swift-openapi-runtime` and
  applies the `OpenAPIGenerator` plugin from `swift-openapi-generator` (1.x).
  `ColorMatchingLPSAppCore` and the test target then depend on it.

## Generated-name contract (from apple/swift-openapi-generator naming rules)

- OperationIds stay verbatim from the published spec:
  `ColorMatchingWeb.TestSheetController.manifest` → method
  `colorMatchingWeb_TestSheetController_manifest` (periods → `_`;
  `_`-separated segments camelCased). All six method names used by the tests:
  - `colorMatchingWeb_TestSheetController_manifest`
  - `colorMatchingWeb_TestSheetController_recent`
  - `colorMatchingWeb_TestSheetController_rankedResults`
  - `colorMatchingWeb_CaptureController_create`
  - `colorMatchingWeb_CaptureController_uploadMeasurements`
  - `colorMatchingWeb_CaptureController_uploadJudgments`
- Properties camelCase (`sheet_id` → `sheetId`) with CodingKeys mapping back.
- Path-parameter fields: `sheetId`, `captureId`.
- Response cases: 200 `.ok`, 201 `.created`; 401/404/422 also declared.

Permitted mechanical adjustments (pin a generator version first): member-label
casing, anyOf payload factory names, response payload arity — but only where a
pinned version differs from the rules above. Binding assertions (paths, wire
JSON keys/values, `operationId` strings, enum `rawValue`s) may not be weakened.

## Bearer auth

`ColorMatchingLPSAppCore` gains `BearerTokenMiddleware` (a
`ClientMiddleware` adding `Authorization: Bearer <token>`), replacing
`APIClient.authorize`. `GeneratedClientTests.testBearerTokenMiddlewareAppliesAuthorizationHeaderToGeneratedRequests`
verifies the header reaches generated requests via
`Client(serverURL:transport:configuration:)`.

## Green-phase checklist for the implementation run

1. Add dependencies and the `ColorMatchingAPI` plugin target; vendor the spec
   (P1–P4 patches applied) + generator config.
2. Make `ColorMatchingLPSAppTests` depend on `ColorMatchingAPI` and
   `swift-openapi-runtime` (new test files already reference them).
3. Implement `BearerTokenMiddleware`; rework `ColorMatchingLPSAppCore` onto the
   generated `Client` (server URL is scheme+host only — paths already carry
   `/api/v1`); delete the hand-written request/response models that the
   generated types replace (`CaptureMetadata`, `WhiteBalanceGains`,
   `CaptureSessionResponse`, `RecentSheet`, `PairJudgment` wire models) and
   migrate `APIClientTests` accordingly.
4. Run `swift test --disable-sandbox`; all suites green.
5. Copy the delta tables from `docs/color-matching-openapi-contract-deltas.md`
   into the PR description (deliverable D5).
