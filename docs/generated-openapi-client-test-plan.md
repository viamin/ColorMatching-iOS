# Generated OpenAPI Client — Test Plan (tests-only red phase)

Issue: replace the hand-written API layer with a generated OpenAPI Swift client (#5).

This document is the test plan for the tests-only PR. It maps every acceptance
criterion of issue #5 to its smallest credible verification and records the
expected red-phase state of the suite. The companion evidence for the contract
delta deliverable lives in
[`docs/color-matching-openapi-contract-deltas.md`](./color-matching-openapi-contract-deltas.md).

## Generated surface contract

The tests in this PR are the executable contract for the implementation run.
They intentionally reference a module and operation names that do not exist yet,
so the `ColorMatchingLPSAppTests` target does not build until the implementation
lands. That compile failure is the red-phase demonstration of missing behavior;
no assertion in the suite depends on a live server.

The implementation must provide:

- A SwiftPM target named `GeneratedClient` produced by the
  `swift-openapi-generator` build tool plugin (`.plugin(name: "OpenAPIGenerator")`),
  depending on `swift-openapi-runtime` (1.x) and `swift-openapi-urlsession`
  (for `URLSessionTransport`). Generation mode: client + types.
- An OpenAPI document vendored from `GET /api/v1/openapi.json` of
  `viamin/color_matching` (published by viamin/color_matching#113) plus an
  `openapi.yaml` generator config file.
- The test target `ColorMatchingLPSAppTests` gains dependencies on
  `GeneratedClient`, `OpenAPIRuntime`, and `OpenAPIURLSession`.
- Explicit operation IDs in the vendored document, because open_api_spex
  defaults them to `"<ControllerModule>.<action>"` and
  `swift-openapi-generator` sanitizes `.` to `_period_`, producing unusable
  Swift method names. Adding operation IDs is an additive, shape-preserving
  normalization of the vendored copy (reported upstream; see the deltas doc).

Required operation IDs (Swift method names follow them verbatim):

| Operation ID | HTTP surface |
| --- | --- |
| `getTestSheetManifest` | `GET /api/v1/test_sheets/{sheet_id}/manifest` |
| `listRecentTestSheets` | `GET /api/v1/test_sheets/recent` |
| `getRankedResults` | `GET /api/v1/test_sheets/{sheet_id}/ranked_results` |
| `createCapture` | `POST /api/v1/test_sheets/{sheet_id}/captures` |
| `uploadMeasurements` | `POST /api/v1/captures/{capture_id}/measurements` |
| `uploadJudgments` | `POST /api/v1/captures/{capture_id}/judgments` |

Known sensitivities the implementation may need to reconcile (mechanical,
test-only adjustments — they do not change what is being asserted):

- Generated memberwise initializer argument order follows property order in the
  vendored document, which follows the upstream `ApiSchemas` map literal order.
- String-enum cases such as `lps-sheet-manifest/v1` get defensively mangled by
  the generator; the tests assert `.rawValue` instead of case names so they stay
  stable.

## Acceptance criteria → verification mapping

| AC | Criterion | Verification | Kind | Evidence |
| --- | --- | --- | --- | --- |
| AC-1 | `swift-openapi-generator` + `swift-openapi-runtime` in the package; OpenAPI document fetched or vendored | The new tests import `GeneratedClient` and use `URLSessionTransport`, so the target cannot build unless the generator, runtime, and URL session transport packages are wired and the document is vendored | unit_or_service_test (compile-level) | `iOS/Tests/ColorMatchingLPSAppTests/GeneratedClientSupport.swift` |
| AC-2 | Generated client for manifest + recent sheets, capture creation, measurement upload, judgment upload, ranked results | One permanent test per operation exercising the generated `Client` end to end against stubbed responses, asserting wire request (method, path, headers, JSON body) and decoded output | unit_or_service_test | `GeneratedClientManifestTests.swift`, `GeneratedClientRecentSheetsTests.swift`, `GeneratedClientCaptureCreationTests.swift`, `GeneratedClientMeasurementUploadTests.swift`, `GeneratedClientJudgmentUploadTests.swift`, `GeneratedClientRankedResultsTests.swift` |
| AC-3 | Replace hand-written API models with generated types; keep purely client-side models | Covered indirectly: the upload tests construct entire request payloads from generated types alone (no `MeasurementCore`/`APIClient` types), proving the generated types suffice. App rewiring itself lands in the implementation run | unit_or_service_test (indirect) | `GeneratedClientCaptureCreationTests.swift`, `GeneratedClientMeasurementUploadTests.swift`, `GeneratedClientJudgmentUploadTests.swift` |
| AC-4 | Swift tests against local stubbed responses, no live server in CI | All tests stub at the `URLProtocol` layer against `https://example.test`; zero network egress; no `.ephemeral-tests/` entry is warranted because these are recurring contract checks, not a one-off flow | unit_or_service_test | `GeneratedClientSupport.swift` (`GeneratedClientMockURLProtocol`) |
| AC-5 | PR description records prose-contract vs published-spec deltas and endpoint gaps | Delta analysis derived from the published spec sources (upstream commit recorded in the doc), drafted as an inspectable artifact to fold into the implementation PR description verbatim | human_or_external_evidence | `docs/color-matching-openapi-contract-deltas.md` |
| AC-6 | Exit: `swift test --disable-sandbox` green with generated types wired in | Runs on macOS CI (the repo's `test` job). This container has no Swift toolchain (`swift: command not found`), so local execution is blocked; recorded as not run locally | CI job (external) | `.github/workflows/ci.yml` `Swift and iOS Tests` job |

## Red-phase expectation

At this PR head: `swift test` fails during target compilation because
`import GeneratedClient` cannot resolve. This is the expected missing behavior
for the tests-only phase — the suite turns green only when the generated client
exists and satisfies the wire/decode assertions above.

## Local execution note

No Swift toolchain is installed in the authoring container, so `swift test`
could not be executed locally before commit. The suite is verified by
construction against the published generator/runtime API shapes documented
above; macOS CI is the authoritative executor.
