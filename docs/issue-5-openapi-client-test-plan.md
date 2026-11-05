# Issue #5: Generated OpenAPI client verification plan

This is the tests-only (red) phase for #5. The repository currently has no
vendored OpenAPI document and `iOS/Package.swift` has neither
`swift-openapi-generator` nor `swift-openapi-runtime` dependencies. The app
still uses the hand-written `APIClient` and Codable transport models.

## Acceptance criteria and smallest credible verification

| Criterion | Verification | Current result |
| --- | --- | --- |
| Generator/runtime dependencies and vendored spec | `APIClientTests.testPackageDeclaresOpenAPIGeneratedClientInputs` checks the package declarations and `iOS/OpenAPI/color_matching.openapi.yaml`. | Red: neither input exists. |
| Typed client covers manifest, recent sheets, capture creation, measurement upload, judgment upload, and ranked results | Permanent local-stub tests in `APIClientTests` must invoke generated operations for every listed endpoint and assert decoded response/request shape. | Partial red: existing stub tests cover capture/measurement/judgment; this change adds manifest/recent. Ranked results has no current operation or response schema. |
| Hand-written transport models are replaced while client-side domain models remain | Code review plus compilation after the generated client is wired into `APIClient`; assert public app behavior through the same local-stub tests. | Not run in this tests-only phase. |
| No live server in CI | `MockURLProtocol` in `APIClientTests` intercepts every request; no test uses a live listener or server. | Passed for the current manifest/recent/capture/measurement/judgment stubs. |
| `swift test --disable-sandbox` | Run after the OpenAPI dependency and generated types are committed. | Not run: the new dependency/spec assertion is intentionally red. |
| PR description records contract deltas and endpoint gaps | Compare the published `viamin/color_matching#110` document against `docs/color-matching-api-contract.md`, citing the exact source revision. | Blocked: the published document is not present in this checkout. |

## Contract baseline and known gap

The prose contract names six surfaces: manifest, recent sheets, capture
creation, measurement upload, judgment upload, and ranked results. The
current Swift client implements the first five only. The ranked-results prose
description does not define a JSON response schema, so a typed generated
operation cannot be written until the published OpenAPI document supplies it.

The implementation PR must replace this baseline with an evidence-backed
comparison against the published spec, including any changed request fields,
response fields, status codes, authentication declarations, and endpoint gaps.
